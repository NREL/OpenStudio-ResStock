# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'csv'
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
require File.join(resources_path, 'weather')

# in addition to the above requires, this measure is expected to run in an
# environment with resstock/resources/buildstock.rb loaded

# start the measure
class BuildExistingModel < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Build Existing Model'
  end

  # human readable description
  def description
    return 'Builds the OpenStudio Model for an existing building.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Builds the OpenStudio Model using the sampling csv file, which contains the specified parameters for each existing building. Based on the supplied building number, those parameters are used to run the OpenStudio measures with appropriate arguments and build up the OpenStudio model.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    building_id = OpenStudio::Ruleset::OSArgument.makeIntegerArgument('building_id', true)
    building_id.setDisplayName('Building ID')
    building_id.setDescription('The building number (between 1 and the number of samples).')
    args << building_id

    workflow_json = OpenStudio::Ruleset::OSArgument.makeStringArgument('workflow_json', false)
    workflow_json.setDisplayName('Workflow JSON')
    workflow_json.setDescription('The name of the JSON file (in the resources dir) that dictates the order in which measures are to be run. If not provided, the order specified in resources/options_lookup.tsv will be used.')
    args << workflow_json

    number_of_buildings_represented = OpenStudio::Ruleset::OSArgument.makeIntegerArgument('number_of_buildings_represented', false)
    number_of_buildings_represented.setDisplayName('Number of Buildings Represented')
    number_of_buildings_represented.setDescription('The total number of buildings represented by the existing building models.')
    args << number_of_buildings_represented

    sample_weight = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('sample_weight', false)
    sample_weight.setDisplayName('Sample Weight of Simulation')
    sample_weight.setDescription('Number of buildings this simulation represents.')
    args << sample_weight

    downselect_logic = OpenStudio::Ruleset::OSArgument.makeStringArgument('downselect_logic', false)
    downselect_logic.setDisplayName('Downselect Logic')
    downselect_logic.setDescription("Logic that specifies the subset of the building stock to be considered in the analysis. Specify one or more parameter|option as found in resources\\options_lookup.tsv. When multiple are included, they must be separated by '||' for OR and '&&' for AND, and using parentheses as appropriate. Prefix an option with '!' for not.")
    args << downselect_logic

    measures_to_ignore = OpenStudio::Ruleset::OSArgument.makeStringArgument('measures_to_ignore', false)
    measures_to_ignore.setDisplayName('Measures to Ignore')
    measures_to_ignore.setDescription("Measures to exclude from the OpenStudio Workflow specified by listing one or more measure directories separated by '|'. Core ResStock measures cannot be ignored (this measure will fail). INTENDED FOR ADVANCED USERS/WORKFLOW DEVELOPERS.")
    args << measures_to_ignore

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    building_id = runner.getIntegerArgumentValue('building_id', user_arguments)
    workflow_json = runner.getOptionalStringArgumentValue('workflow_json', user_arguments)
    number_of_buildings_represented = runner.getOptionalIntegerArgumentValue('number_of_buildings_represented', user_arguments)
    sample_weight = runner.getOptionalDoubleArgumentValue('sample_weight', user_arguments)
    downselect_logic = runner.getOptionalStringArgumentValue('downselect_logic', user_arguments)
    measures_to_ignore = runner.getOptionalStringArgumentValue('measures_to_ignore', user_arguments)

    # Save the building id
    model.getBuilding.additionalProperties.setFeature('Building ID', building_id)

    # Get file/dir paths
    resources_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'resources')) # Should have been uploaded per 'Additional Analysis Files' in PAT
    characteristics_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'housing_characteristics')) # Should have been uploaded per 'Additional Analysis Files' in PAT
    buildstock_file = File.join(resources_dir, 'buildstock.rb')
    measures_dir = File.join(resources_dir, 'measures')
    lookup_file = File.join(resources_dir, 'options_lookup.tsv')
    buildstock_csv = File.absolute_path(File.join(characteristics_dir, 'buildstock.csv')) # Should have been generated by the Worker Initialization Script (run_sampling.rb) or provided by the project
    if workflow_json.is_initialized
      workflow_json = File.join(resources_dir, workflow_json.get)
    else
      workflow_json = nil
    end

    # Load buildstock_file
    require File.join(File.dirname(buildstock_file), File.basename(buildstock_file, File.extname(buildstock_file)))

    # Check file/dir paths exist
    check_dir_exists(measures_dir, runner)
    check_file_exists(lookup_file, runner)
    check_file_exists(buildstock_csv, runner)

    lookup_csv_data = CSV.open(lookup_file, col_sep: "\t").each.to_a
    buildstock_csv_data = CSV.open(buildstock_csv, headers: true).map(&:to_hash)

    # Retrieve all data associated with sample number
    bldg_data = get_data_for_sample(buildstock_csv_data, building_id, runner)

    # Retrieve order of parameters to run
    parameters_ordered = get_parameters_ordered_from_options_lookup_tsv(lookup_csv_data, characteristics_dir)

    # Retrieve options that have been selected for this building_id
    parameters_ordered.each do |parameter_name|
      # Register the option chosen for parameter_name with the runner
      option_name = bldg_data[parameter_name]
      register_value(runner, parameter_name, option_name)
    end

    # Determine whether this building_id has been downselected based on the
    # {parameter_name: option_name} pairs
    if downselect_logic.is_initialized

      downselect_logic = downselect_logic.get
      downselect_logic = downselect_logic.strip
      downselected = evaluate_logic(downselect_logic, runner, past_results = false)

      if downselected.nil?
        # unable to evaluate logic
        return false
      end

      unless downselected
        # Not in downselection; don't run existing home simulation
        runner.registerInfo('Sample is not in downselected parameters; will be registered as invalid.')
        runner.haltWorkflow('Invalid')
        return false
      end

    end

    # Obtain measures and arguments to be called
    measures = {}
    parameters_ordered.each do |parameter_name|
      option_name = bldg_data[parameter_name]
      print_option_assignment(parameter_name, option_name, runner)
      options_measure_args = get_measure_args_from_option_names(lookup_csv_data, [option_name], parameter_name, lookup_file, runner)
      options_measure_args[option_name].each do |measure_subdir, args_hash|
        update_args_hash(measures, measure_subdir, args_hash, add_new = false)
      end
    end

    # FIXME: Hack to run the correct ResStock geometry measure
    if ['Single-Family Detached', 'Mobile Home'].include? bldg_data['Geometry Building Type RECS']
      measures.delete('ResidentialGeometryCreateSingleFamilyAttached')
      measures.delete('ResidentialGeometryCreateMultifamily')
    elsif ['Single-Family Attached'].include? bldg_data['Geometry Building Type RECS']
      measures.delete('ResidentialGeometryCreateSingleFamilyDetached')
      measures.delete('ResidentialGeometryCreateMultifamily')
    elsif ['Multi-Family with 2 - 4 Units', 'Multi-Family with 5+ Units'].include? bldg_data['Geometry Building Type RECS']
      measures.delete('ResidentialGeometryCreateSingleFamilyDetached')
      measures.delete('ResidentialGeometryCreateSingleFamilyAttached')
    end

    # FIXME: Hack to run the correct ResStock foundation construction measure
    if ['Ambient'].include? bldg_data['Geometry Foundation Type']
      measures.delete('ResidentialConstructionsSlab')
      measures.delete('ResidentialConstructionsCrawlspace')
      measures.delete('ResidentialConstructionsUnfinishedBasement')
      measures.delete('ResidentialConstructionsFinishedBasement')
    elsif ['Unheated Basement'].include? bldg_data['Geometry Foundation Type']
      measures.delete('ResidentialConstructionsPierBeam')
      measures.delete('ResidentialConstructionsSlab')
      measures.delete('ResidentialConstructionsCrawlspace')
      measures.delete('ResidentialConstructionsFinishedBasement')
    elsif ['Heated Basement'].include? bldg_data['Geometry Foundation Type']
      measures.delete('ResidentialConstructionsPierBeam')
      measures.delete('ResidentialConstructionsSlab')
      measures.delete('ResidentialConstructionsCrawlspace')
      measures.delete('ResidentialConstructionsUnfinishedBasement')
    elsif ['Vented Crawlspace', 'Unvented Crawlspace'].include? bldg_data['Geometry Foundation Type']
      measures.delete('ResidentialConstructionsPierBeam')
      measures.delete('ResidentialConstructionsSlab')
      measures.delete('ResidentialConstructionsUnfinishedBasement')
      measures.delete('ResidentialConstructionsFinishedBasement')
    elsif ['Slab'].include? bldg_data['Geometry Foundation Type']
      measures.delete('ResidentialConstructionsPierBeam')
      measures.delete('ResidentialConstructionsCrawlspace')
      measures.delete('ResidentialConstructionsUnfinishedBasement')
      measures.delete('ResidentialConstructionsFinishedBasement')
    end

    # Remove any measures_to_ignore from the list of measures to run
    if measures_to_ignore.is_initialized
      measures_to_ignore = measures_to_ignore.get
      # core ResStock measures are those specified in the default workflow json
      # those should not be ignored ...
      core_measures = get_measures(File.join(resources_dir, 'measure-info.json'))
      measures_to_ignore.split('|').each do |measure_dir|
        if core_measures.include? measure_dir
          # fail if core ResStock measure is ignored
          msg = "Core ResStock measure #{measure_dir} cannot be ignored"
          runner.registerError(msg)
          fail msg
        end
        runner.registerInfo("Ignoring/not running measure #{measure_dir}")
        measures.delete(measure_dir)
      end
    end

    if not apply_measures(measures_dir, measures, runner, model, workflow_json, 'measures.osw', true)
      return false
    end

    # Report some additional location and model characteristics
    weather = WeatherProcess.new(model, runner)
    if !weather.error?
      register_value(runner, 'location_city', weather.header.City)
      register_value(runner, 'location_latitude', "#{weather.header.Latitude}")
      register_value(runner, 'location_longitude', "#{weather.header.Longitude}")
      climate_zone_ba = Location.get_climate_zone_ba(weather.header.Station)
      climate_zone_iecc = Location.get_climate_zone_iecc(weather.header.Station)
      unless climate_zone_ba.nil?
        register_value(runner, 'climate_zone_ba', climate_zone_ba)
      end
      unless climate_zone_iecc.nil?
        register_value(runner, 'climate_zone_iecc', climate_zone_iecc)
      end
      if climate_zone_ba.nil? && climate_zone_iecc.nil?
        runner.registerInfo('The weather station WMO has not been set appropriately in the EPW weather file header.')
      end
    end

    # Determine weight
    if number_of_buildings_represented.is_initialized
      total_samples = nil
      runner.analysis[:analysis][:problem][:workflow].each do |wf|
        next if wf[:name] != 'build_existing_model'

        wf[:variables].each do |v|
          next if v[:argument][:name] != 'building_id'

          total_samples = v[:maximum].to_f
        end
      end
      if total_samples.nil?
        runner.registerError('Could not retrieve value for number_of_buildings_represented.')
        return false
      end
      weight = number_of_buildings_represented.get / total_samples
      register_value(runner, 'weight', weight.to_s)
    end

    if sample_weight.is_initialized
      register_value(runner, 'weight', sample_weight.get.to_s)
    end

    return true
  end
end

# register the measure to be used by the application
BuildExistingModel.new.registerWithApplication
