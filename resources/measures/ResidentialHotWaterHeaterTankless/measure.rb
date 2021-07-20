# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'waterheater')
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'unit_conversions')

# start the measure
class ResidentialHotWaterHeaterTankless < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Tankless Water Heater'
  end

  def description
    return "This measure adds a new residential tankless water heater to the model based on user inputs. If there is already an existing residential water heater in the model, it is replaced. For multifamily buildings, the water heater can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return "The measure will create a new instance of the OS:WaterHeater:Mixed object representing a tankless water heater. The water heater will be placed on the plant loop 'Domestic Hot Water Loop'. If this loop already exists, any water heater on that loop will be removed and replaced with a water heater consistent with this measure. If it doesn't exist, it will be created."
  end

  # define the arguments that the user will input
  def arguments(model)
    ruleset = OpenStudio::Measure

    osargument = ruleset::OSArgument

    args = ruleset::OSArgumentVector.new

    # make a string argument for tankless fuel type
    fuel_display_names = OpenStudio::StringVector.new
    fuel_display_names << Constants.FuelTypeGas
    fuel_display_names << Constants.FuelTypePropane
    fuel_display_names << Constants.FuelTypeElectric
    fuel_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('fuel_type', fuel_display_names, true)
    fuel_type.setDisplayName('Fuel Type')
    fuel_type.setDescription('Type of fuel used for water heating.')
    fuel_type.setDefaultValue(Constants.FuelTypeGas)
    args << fuel_type

    # make an argument for hot water setpoint temperature
    setpoint_temp = osargument::makeDoubleArgument('setpoint_temp', true)
    setpoint_temp.setDisplayName('Setpoint')
    setpoint_temp.setDescription('Water heater setpoint temperature. This value will be ignored if the setpoint type is Scheduled.')
    setpoint_temp.setUnits('F')
    setpoint_temp.setDefaultValue(125)
    args << setpoint_temp

    # make a choice argument for location
    location_args = OpenStudio::StringVector.new
    location_args << Constants.Auto
    Geometry.get_model_locations(model).each do |loc|
      location_args << loc
    end
    location = OpenStudio::Measure::OSArgument::makeChoiceArgument('location', location_args, true)
    location.setDisplayName('Location')
    location.setDescription("The space type for the location. '#{Constants.Auto}' will automatically choose a space type based on the space types found in the model.")
    location.setDefaultValue(Constants.Auto)
    args << location

    # make an argument for capacity
    capacity = osargument::makeDoubleArgument('capacity', true)
    capacity.setDisplayName('Input Capacity')
    capacity.setDescription('The maximum energy input rating of the water heater.')
    capacity.setUnits('kBtu/hr')
    capacity.setDefaultValue(100000000.0)
    args << capacity

    # make an argument for the rated energy factor
    energy_factor = osargument::makeDoubleArgument('energy_factor', true)
    energy_factor.setDisplayName('Rated Energy Factor')
    energy_factor.setDescription('Ratio of useful energy output from the water heater to the total amount of energy delivered from the water heater.')
    energy_factor.setDefaultValue(0.82)
    args << energy_factor

    # make an argument for cycling_derate
    cycling_derate = osargument::makeDoubleArgument('cycling_derate', true)
    cycling_derate.setDisplayName('Cycling Derate')
    cycling_derate.setDescription("Annual energy derate for cycling inefficiencies -- accounts for the impact of thermal cycling and small hot water draws on the heat exchanger. CEC's 2008 Title24 implemented an 8% derate for tankless water heaters. ")
    cycling_derate.setUnits('Frac')
    cycling_derate.setDefaultValue(0.08)
    args << cycling_derate

    # make an argument on cycle electricity consumption
    offcyc_power = osargument::makeDoubleArgument('offcyc_power', true)
    offcyc_power.setDisplayName('Parasitic Electric Power')
    offcyc_power.setDescription('Off cycle electric power draw for controls, etc. Only used for non-electric water heaters.')
    offcyc_power.setUnits('W')
    offcyc_power.setDefaultValue(5.0)
    args << offcyc_power

    # make an argument on cycle electricity consumption
    oncyc_power = osargument::makeDoubleArgument('oncyc_power', true)
    oncyc_power.setDisplayName('Forced Draft Fan Power')
    oncyc_power.setDescription('On cycle electric power draw from the forced draft fan motor. Only used for non-electric water heaters.')
    oncyc_power.setUnits('W')
    oncyc_power.setDefaultValue(65.0)
    args << oncyc_power

    # make a bool argument for open water heater flue
    has_water_heater_flue = OpenStudio::Measure::OSArgument::makeBoolArgument('has_water_heater_flue', true)
    has_water_heater_flue.setDisplayName('Air Leakage: Has Open Water Heater Flue')
    has_water_heater_flue.setDescription('Specifies whether the building has an open flue associated with the water heater.')
    has_water_heater_flue.setDefaultValue(false)
    args << has_water_heater_flue

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Assign user inputs to variables
    fuel_type = runner.getStringArgumentValue('fuel_type', user_arguments)
    capacity = runner.getDoubleArgumentValue('capacity', user_arguments)
    energy_factor = runner.getDoubleArgumentValue('energy_factor', user_arguments)
    cycling_derate = runner.getDoubleArgumentValue('cycling_derate', user_arguments)
    location = runner.getStringArgumentValue('location', user_arguments)
    setpoint_temp = runner.getDoubleArgumentValue('setpoint_temp', user_arguments).to_f
    oncycle_power = runner.getDoubleArgumentValue('oncyc_power', user_arguments)
    offcycle_power = runner.getDoubleArgumentValue('offcyc_power', user_arguments)
    model.getBuilding.additionalProperties.setFeature('has_water_heater_flue', runner.getBoolArgumentValue('has_water_heater_flue', user_arguments))

    # Validate inputs
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    # Check if mains temperature has been set
    if !model.getSite.siteWaterMainsTemperature.is_initialized
      runner.registerError('Mains water temperature has not been set.')
      return false
    end

    # Get Building America climate zone
    ba_cz_name = nil
    model.getClimateZones.climateZones.each do |climateZone|
      next if climateZone.institution != Constants.BuildingAmericaClimateZone

      ba_cz_name = climateZone.value.to_s
    end

    location_hierarchy = Waterheater.get_location_hierarchy(ba_cz_name)

    Waterheater.remove(model, runner)

    units.each_with_index do |unit, unit_index|
      # Get space
      space = Geometry.get_space_from_location(unit, location, location_hierarchy)
      next if space.nil?

      # Get loop if it exists
      loop = nil
      model.getPlantLoops.each do |pl|
        next if pl.name.to_s != Constants.PlantLoopDomesticWater(unit.name.to_s)

        loop = pl
      end

      success = Waterheater.apply_tankless(model, unit, runner, loop, space, fuel_type,
                                           capacity, energy_factor, cycling_derate,
                                           Constants.WaterHeaterSetpointTypeConstant, setpoint_temp,
                                           'none', oncycle_power,
                                           offcycle_power, 1.0)
      return false if not success
    end

    final_condition = list_water_heaters(model, runner).join("\n")
    runner.registerFinalCondition(final_condition)

    return true
  end # end the run method

  def list_water_heaters(model, runner)
    water_heaters = []

    existing_heaters = model.getWaterHeaterMixeds
    for heater in existing_heaters do
      heatername = heater.name.get
      loopname = heater.plantLoop.get.name.get

      capacity_si = heater.getHeaterMaximumCapacity.get
      capacity = UnitConversions.convert(capacity_si.value, 'W', 'kBtu/hr')
      volume_si = heater.getTankVolume.get
      volume = UnitConversions.convert(volume_si.value, 'm^3', 'gal')
      te = heater.getHeaterThermalEfficiency.get.value

      water_heaters << "Water heater '#{heatername}' added to plant loop '#{loopname}', with a capacity of #{capacity.round(1)} kBtu/hr" +
                       " and a burner efficiency of  #{te.round(2)}."
    end
    water_heaters
  end
end # end the measure

# this allows the measure to be use by the application
ResidentialHotWaterHeaterTankless.new.registerWithApplication
