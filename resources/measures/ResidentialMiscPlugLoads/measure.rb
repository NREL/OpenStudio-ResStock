# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'misc_loads')

# start the measure
class ResidentialMiscElectricLoads < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Plug Loads'
  end

  def description
    return "Adds (or replaces) residential plug loads with the specified efficiency and schedule in all finished spaces. For multifamily buildings, the plug loads can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Since there is no Plug Loads object in OpenStudio/EnergyPlus, we look for an ElectricEquipment object with the name that denotes it is residential plug loads. If one is found, it is replaced with the specified properties. Otherwise, a new such object is added to the model. Note: This measure requires the number of bedrooms/bathrooms to have already been assigned.'
  end

  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # TODO: New argument for demand response for mels (alternate schedules if automatic DR control is specified)

    # make a choice argument for option type
    choices = []
    choices << Constants.OptionTypePlugLoadsMultiplier
    choices << Constants.OptionTypePlugLoadsEnergyUse
    option_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('option_type', choices, true)
    option_type.setDisplayName('Option Type')
    option_type.setDescription('Inputs are used/ignored below based on the option type specified.')
    option_type.setDefaultValue(Constants.OptionTypePlugLoadsMultiplier)
    args << option_type

    # make a double argument for BA Benchmark multiplier
    energy_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('energy_mult', true)
    energy_mult.setDisplayName("Energy: #{Constants.OptionTypePlugLoadsMultiplier}")
    energy_mult.setDefaultValue(1)
    energy_mult.setDescription('A multiplier on the national average energy use, which is calculated as: (1146.95 + 296.94 * Noccupants + 0.3 * FFA) for single-family detached, (1395.84 + 136.53 * Noccupants + 0.16 * FFA) for single-family attached, and (875.22 + 184.11 * Noccupants + 0.38 * FFA) for multifamily, where Noccupants is the number of occupants and FFA is the finished floor area in sqft.')
    args << energy_mult

    # make a double argument for diversity multiplier
    diversity_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('diversity_mult', true)
    diversity_mult.setDisplayName("Diversity: #{Constants.OptionTypePlugLoadsMultiplier}")
    diversity_mult.setDefaultValue(1)
    diversity_mult.setDescription('A diversity multiplier on the energy mutliplier.')
    args << diversity_mult

    # make a double argument for annual energy use
    energy_use = OpenStudio::Measure::OSArgument::makeDoubleArgument('energy_use', true)
    energy_use.setDisplayName("#{Constants.OptionTypePlugLoadsEnergyUse}")
    energy_use.setDefaultValue(2000)
    energy_use.setDescription('Annual energy use of the plug loads.')
    energy_use.setUnits('kWh/year')
    args << energy_use

    # Make a double argument for sensible fraction
    sens_frac = OpenStudio::Measure::OSArgument::makeDoubleArgument('sens_frac', true)
    sens_frac.setDisplayName('Sensible Fraction')
    sens_frac.setDescription('Fraction of internal gains that are sensible.')
    sens_frac.setDefaultValue(0.93)
    args << sens_frac

    # Make a double argument for latent fraction
    lat_frac = OpenStudio::Measure::OSArgument::makeDoubleArgument('lat_frac', true)
    lat_frac.setDisplayName('Latent Fraction')
    lat_frac.setDescription('Fraction of internal gains that are latent.')
    lat_frac.setDefaultValue(0.021)
    args << lat_frac

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    option_type = runner.getStringArgumentValue('option_type', user_arguments)
    energy_mult = runner.getDoubleArgumentValue('energy_mult', user_arguments)
    diversity_mult = runner.getDoubleArgumentValue('diversity_mult', user_arguments)
    energy_use = runner.getDoubleArgumentValue('energy_use', user_arguments)
    sens_frac = runner.getDoubleArgumentValue('sens_frac', user_arguments)
    lat_frac = runner.getDoubleArgumentValue('lat_frac', user_arguments)

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    # Remove all existing objects
    model.getSpaces.each do |space|
      MiscLoads.remove(runner, space, [Constants.ObjectNameMiscPlugLoads])
    end

    schedules_file = SchedulesFile.new(runner: runner, model: model)
    if not schedules_file.validated?
      return false
    end

    tot_mel_ann = 0
    msgs = []
    sch = nil
    units.each do |unit|
      # Calculate electric mel daily energy use
      if option_type == Constants.OptionTypePlugLoadsMultiplier
        # Get unit beds/baths/occupants
        nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
        if nbeds.nil? || nbaths.nil?
          return false
        end

        noccupants = Geometry.get_unit_occupants(model, unit, runner)

        # Get unit ffa
        ffa = Geometry.get_finished_floor_area_from_spaces(unit.spaces, runner)
        if ffa.nil?
          return false
        end

        mult = energy_mult * diversity_mult

        if [Constants.BuildingTypeSingleFamilyDetached].include? Geometry.get_building_type(model) # single-family detached equation
          mel_ann = (1146.95 + 296.94 * noccupants + 0.3 * ffa) * mult # RECS 2015
        elsif [Constants.BuildingTypeSingleFamilyAttached].include? Geometry.get_building_type(model) # single-family attached equation
          mel_ann = (1395.84 + 136.53 * noccupants + 0.16 * ffa) * mult # RECS 2015
        elsif [Constants.BuildingTypeMultifamily].include? Geometry.get_building_type(model) # multifamily equation
          mel_ann = (875.22 + 184.11 * noccupants + 0.38 * ffa) * mult # RECS 2015
        end
      elsif option_type == Constants.OptionTypePlugLoadsEnergyUse
        mel_ann = energy_use
      end

      success, sch = MiscLoads.apply_plug(model, unit, runner, mel_ann, sens_frac, lat_frac, sch, schedules_file)

      return false if not success

      if mel_ann > 0
        msgs << "Plug loads with #{mel_ann.round} kWhs annual energy consumption has been assigned to unit '#{unit.name}'."
        tot_mel_ann += mel_ann
      end
    end

    schedules_file.set_vacancy(col_name: 'plug_loads')

    # Reporting
    if msgs.size > 1
      msgs.each do |msg|
        runner.registerInfo(msg)
      end
      runner.registerFinalCondition("The building has been assigned plug loads totaling #{tot_mel_ann.round} kWhs annual energy consumption across #{units.size} units.")
    elsif msgs.size == 1
      runner.registerFinalCondition(msgs[0])
    else
      runner.registerFinalCondition('No plug loads have been assigned.')
    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ResidentialMiscElectricLoads.new.registerWithApplication
