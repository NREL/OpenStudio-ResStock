# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# Adapted from Measure Picker measure
# https://github.com/NREL/OpenStudio-measures/blob/develop/NREL%20working%20measures/measure_picker/measure.rb

require 'csv'
require 'openstudio'

require 'openstudio'
if File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock on AWS
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock unit tests locally
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources')
else
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
end
require File.join(resources_path, 'constants')

# start the measure
class ApplyUpgrade < OpenStudio::Ruleset::ModelUserScript
  # human readable name
  def name
    return 'Apply Upgrade'
  end

  # human readable description
  def description
    return 'Measure that applies an upgrade (one or more child measures) to a building model based on the specified logic.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Determines if the upgrade should apply to a given building model. If so, calls one or more child measures with the appropriate arguments.'
  end

  def num_options
    return Constants.NumApplyUpgradeOptions # Synced with SimulationOutputReport measure
  end

  def num_costs_per_option
    return Constants.NumApplyUpgradesCostsPerOption # Synced with SimulationOutputReport measure
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make string arg for upgrade name
    upgrade_name = OpenStudio::Ruleset::OSArgument::makeStringArgument('upgrade_name', true)
    upgrade_name.setDisplayName('Upgrade Name')
    upgrade_name.setDescription('User-specificed name that describes the upgrade.')
    upgrade_name.setDefaultValue('My Upgrade')
    args << upgrade_name

    for option_num in 1..num_options

      # Option name argument
      option = OpenStudio::Ruleset::OSArgument.makeStringArgument("option_#{option_num}", (option_num == 1))
      option.setDisplayName("Option #{option_num}")
      option.setDescription('Specify the parameter|option as found in resources\\options_lookup.tsv.')
      args << option

      # Option Apply Logic argument
      option_apply_logic = OpenStudio::Ruleset::OSArgument.makeStringArgument("option_#{option_num}_apply_logic", false)
      option_apply_logic.setDisplayName("Option #{option_num} Apply Logic")
      option_apply_logic.setDescription("Logic that specifies if the Option #{option_num} upgrade will apply based on the existing building's options. Specify one or more parameter|option as found in resources\\options_lookup.tsv. When multiple are included, they must be separated by '||' for OR and '&&' for AND, and using parentheses as appropriate. Prefix an option with '!' for not.")
      args << option_apply_logic

      for cost_num in 1..num_costs_per_option

        # Option Cost Value argument
        cost_value = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("option_#{option_num}_cost_#{cost_num}_value", false)
        cost_value.setDisplayName("Option #{option_num} Cost #{cost_num} Value")
        cost_value.setDescription("Total option #{option_num} cost is the sum of all: (Cost N Value) x (Cost N Multiplier).")
        cost_value.setUnits('$')
        args << cost_value

        # Option Cost Multiplier argument
        choices = [
          '',
          'Fixed (1)',
          'Wall Area, Above-Grade, Conditioned (ft^2)',
          'Wall Area, Above-Grade, Exterior (ft^2)',
          'Wall Area, Below-Grade (ft^2)',
          'Floor Area, Conditioned (ft^2)',
          'Floor Area, Attic (ft^2)',
          'Floor Area, Lighting (ft^2)',
          'Roof Area (ft^2)',
          'Window Area (ft^2)',
          'Door Area (ft^2)',
          'Duct Unconditioned Surface Area (ft^2)',
          'Size, Heating System (kBtu/h)',
          'Size, Cooling System (kBtu/h)',
          'Size, Water Heater (gal)',
        ]
        cost_multiplier = OpenStudio::Ruleset::OSArgument.makeChoiceArgument("option_#{option_num}_cost_#{cost_num}_multiplier", choices, false)
        cost_multiplier.setDisplayName("Option #{option_num} Cost #{cost_num} Multiplier")
        cost_multiplier.setDescription("Total option #{option_num} cost is the sum of all: (Cost N Value) x (Cost N Multiplier).")
        cost_multiplier.setDefaultValue(choices[0])
        args << cost_multiplier

      end

      # Option Lifetime argument
      option_lifetime = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("option_#{option_num}_lifetime", false)
      option_lifetime.setDisplayName("Option #{option_num} Lifetime")
      option_lifetime.setDescription('The option lifetime.')
      option_lifetime.setUnits('years')
      args << option_lifetime

    end

    # Package Apply Logic argument
    package_apply_logic = OpenStudio::Ruleset::OSArgument.makeStringArgument('package_apply_logic', false)
    package_apply_logic.setDisplayName('Package Apply Logic')
    package_apply_logic.setDescription("Logic that specifies if the entire package upgrade (all options) will apply based on the existing building's options. Specify one or more parameter|option as found in resources\\options_lookup.tsv. When multiple are included, they must be separated by '||' for OR and '&&' for AND, and using parentheses as appropriate. Prefix an option with '!' for not.")
    args << package_apply_logic

    # Make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument('run_measure', true)
    run_measure.setDisplayName('Run Measure')
    run_measure.setDescription('integer argument to run measure [1 is run, 0 is no run]')
    run_measure.setDefaultValue(1)
    args << run_measure

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue('run_measure', user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true
    end

    upgrade_name = runner.getStringArgumentValue('upgrade_name', user_arguments)

    # Retrieve Option X argument values
    options = {}
    for option_num in 1..num_options
      if option_num == 1
        arg = runner.getStringArgumentValue("option_#{option_num}", user_arguments)
      else
        arg = runner.getOptionalStringArgumentValue("option_#{option_num}", user_arguments)
        next if not arg.is_initialized

        arg = arg.get
      end
      next if arg.strip.size == 0

      if not arg.include?('|')
        runner.registerError("Option #{option_num} is missing the '|' delimiter.")
        return false
      end
      options[option_num] = arg.strip
    end

    # Retrieve Option X Apply Logic argument values
    options_apply_logic = {}
    for option_num in 1..num_options
      arg = runner.getOptionalStringArgumentValue("option_#{option_num}_apply_logic", user_arguments)
      next if not arg.is_initialized

      arg = arg.get
      next if arg.strip.size == 0

      if not arg.include?('|')
        runner.registerError("Option #{option_num} Apply Logic is missing the '|' delimiter.")
        return false
      end
      if not options.keys.include?(option_num)
        runner.registerError("Option #{option_num} Apply Logic was provided, but a corresponding Option #{option_num} was not provided.")
        return false
      end
      options_apply_logic[option_num] = arg.strip
    end

    # Retrieve Package Apply Logic argument value
    arg = runner.getOptionalStringArgumentValue('package_apply_logic', user_arguments)
    if not arg.is_initialized
      package_apply_logic = nil
    else
      arg = arg.get
      if arg.strip.size == 0
        package_apply_logic = nil
      else
        if not arg.include?('|')
          runner.registerError("Package Apply Logic is missing the '|' delimiter.")
          return false
        end
        package_apply_logic = arg.strip
      end
    end

    # Get file/dir paths
    resources_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'resources')) # Should have been uploaded per 'Additional Analysis Files' in PAT
    check_dir_exists(resources_dir, runner)
    characteristics_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'housing_characteristics')) # Should have been uploaded per 'Additional Analysis Files' in PAT
    check_dir_exists(characteristics_dir, runner)
    buildstock_file = File.join(resources_dir, 'buildstock.rb')
    measures_dir = File.join(resources_dir, 'measures')
    lookup_file = File.join(resources_dir, 'options_lookup.tsv')

    # Check file/dir paths exist
    check_file_exists(lookup_file, runner)

    lookup_csv_data = CSV.open(lookup_file, col_sep: "\t").each.to_a

    # Load buildstock_file
    require File.join(File.dirname(buildstock_file), File.basename(buildstock_file, File.extname(buildstock_file)))

    # Retrieve workflow_json from BuildExistingModel measure if provided
    workflow_json = get_value_from_runner_past_results(runner, 'workflow_json', 'build_existing_model', false)
    if not workflow_json.nil?
      workflow_json = File.join(resources_dir, workflow_json)
    end

    # Process package apply logic if provided
    apply_package_upgrade = true
    if not package_apply_logic.nil?
      # Apply this package?
      apply_package_upgrade = evaluate_logic(package_apply_logic, runner)
      if apply_package_upgrade.nil?
        return false
      end
    end

    measures = {}
    if apply_package_upgrade

      # Obtain measures and arguments to be called
      # Process options apply logic if provided
      options.each do |option_num, option|
        parameter_name, option_name = option.split('|')

        # Apply this option?
        apply_option_upgrade = true
        if options_apply_logic.include?(option_num)
          apply_option_upgrade = evaluate_logic(options_apply_logic[option_num], runner)
          if apply_option_upgrade.nil?
            return false
          end
        end

        if not apply_option_upgrade
          runner.registerInfo("Parameter #{parameter_name}, Option #{option_name} will not be applied.")
          next
        end

        # Print this option assignment
        print_option_assignment(parameter_name, option_name, runner)

        # Register cost values/multipliers/lifetime for applied options; used by the SimulationOutputReport measure
        for cost_num in 1..num_costs_per_option
          cost_value = runner.getOptionalDoubleArgumentValue("option_#{option_num}_cost_#{cost_num}_value", user_arguments)
          if cost_value.nil?
            cost_value = 0.0
          end
          cost_mult = runner.getStringArgumentValue("option_#{option_num}_cost_#{cost_num}_multiplier", user_arguments)
          register_value(runner, "option_%02d_cost_#{cost_num}_value_to_apply" % option_num, cost_value.to_s)
          register_value(runner, "option_%02d_cost_#{cost_num}_multiplier_to_apply" % option_num, cost_mult)
        end
        lifetime = runner.getOptionalDoubleArgumentValue("option_#{option_num}_lifetime", user_arguments)
        if lifetime.nil?
          lifetime = 0.0
        end
        register_value(runner, 'option_%02d_lifetime_to_apply' % option_num, lifetime.to_s)

        # Get measure name and arguments associated with the option
        options_measure_args = get_measure_args_from_option_names(lookup_csv_data, [option_name], parameter_name, lookup_file, runner)
        options_measure_args[option_name].each do |measure_subdir, args_hash|
          update_args_hash(measures, measure_subdir, args_hash, add_new = false)
        end
      end

      # Add measure arguments from existing building if needed
      parameters = get_parameters_ordered_from_options_lookup_tsv(lookup_csv_data, characteristics_dir)
      measures.keys.each do |measure_subdir|
        parameters.each do |parameter_name|
          existing_option_name = get_value_from_runner_past_results(runner, parameter_name, 'build_existing_model')

          options_measure_args = get_measure_args_from_option_names(lookup_csv_data, [existing_option_name], parameter_name, lookup_file, runner)
          options_measure_args[existing_option_name].each do |measure_subdir2, args_hash|
            next if measure_subdir != measure_subdir2

            # Append any new arguments
            new_args_hash = {}
            args_hash.each do |k, v|
              next if measures[measure_subdir][0].has_key?(k)

              new_args_hash[k] = v
            end
            update_args_hash(measures, measure_subdir, new_args_hash, add_new = false)
          end
        end
      end

      if not apply_measures(measures_dir, measures, runner, model, workflow_json, 'measures-upgrade.osw', true)
        return false
      end

    end # apply_package_upgrade

    # Register the upgrade name
    register_value(runner, 'upgrade_name', upgrade_name)

    if measures.size == 0
      # Upgrade not applied; don't re-run existing home simulation
      runner.haltWorkflow('Invalid')
      return false
    end

    return true
  end
end

# register the measure to be used by the application
ApplyUpgrade.new.registerWithApplication
