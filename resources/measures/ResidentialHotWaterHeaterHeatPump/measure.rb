# frozen_string_literal: true

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
class ResidentialHotWaterHeaterHeatPump < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Heat Pump Water Heater'
  end

  def description
    return "This measure adds a new residential heat pump water heater to the model based on user inputs. If there is already an existing residential water heater in the model, it is replaced. For multifamily buildings, the water heater can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return "The measure will create a new instance of the OS:WaterHeater:HeatPump:WrappedCondenser object representing a heat pump water heater and EMS code for the controls. The water heater will be placed on the plant loop 'Domestic Hot Water Loop'. If this loop already exists, any water heater on that loop will be removed and replaced with a water heater consistent with this measure. If it doesn't exist, it will be created."
  end

  # define the arguments that the user will input
  def arguments(model)
    ruleset = OpenStudio::Ruleset

    osargument = OpenStudio::Measure::OSArgument

    args = OpenStudio::Measure::OSArgumentVector.new

    # make an argument for the storage tank volume
    storage_tank_volume = osargument::makeDoubleArgument('storage_tank_volume', true)
    storage_tank_volume.setDisplayName('Tank Volume')
    storage_tank_volume.setDescription('Nominal volume of the of the water heater tank.')
    storage_tank_volume.setUnits('gal')
    storage_tank_volume.setDefaultValue(50)
    args << storage_tank_volume

    # make an argument for setpoint type (constant or variable)
    setpoint_type_args = OpenStudio::StringVector.new
    setpoint_type_args << Constants.WaterHeaterSetpointTypeConstant
    setpoint_type_args << Constants.WaterHeaterSetpointTypeScheduled
    setpoint_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('setpoint_type', setpoint_type_args, true)
    setpoint_type.setDisplayName('Setpoint type')
    setpoint_type.setDescription("The water heater setpoint type. The '#{Constants.WaterHeaterSetpointTypeConstant}' option will use a constant value for the whole year, while '#{Constants.WaterHeaterSetpointTypeScheduled}' will use 8760 values in a schedule file.")
    setpoint_type.setDefaultValue(Constants.WaterHeaterSetpointTypeConstant)
    args << setpoint_type

    # make an argument for hot water setpoint temperature
    dhw_setpoint = osargument::makeDoubleArgument('setpoint_temp', true)
    dhw_setpoint.setDisplayName('Setpoint')
    dhw_setpoint.setDescription('Water heater setpoint temperature.')
    dhw_setpoint.setUnits('F')
    dhw_setpoint.setDefaultValue(125)
    args << dhw_setpoint

    # make an argument for operating mode type (constant or variable)
    operating_mode_schedule_type_args = OpenStudio::StringVector.new
    operating_mode_schedule_type_args << Constants.WaterHeaterOperatingModeTypeConstant
    operating_mode_schedule_type_args << Constants.WaterHeaterOperatingModeTypeScheduled
    operating_mode_schedule_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('operating_mode_schedule_type', operating_mode_schedule_type_args, true)
    operating_mode_schedule_type.setDisplayName('Operating mode type')
    operating_mode_schedule_type.setDescription("The water heater operating mode type. The '#{Constants.WaterHeaterOperatingModeTypeConstant}' option will use a constant control strategy for the whole year, while '#{Constants.WaterHeaterOperatingModeTypeScheduled}' will use 8760 values in a schedule file.")
    operating_mode_schedule_type.setDefaultValue(Constants.WaterHeaterOperatingModeTypeConstant)
    args << operating_mode_schedule_type

    # make an argument for operating mode (standard or hp_only)
    operating_mode_args = OpenStudio::StringVector.new
    operating_mode_args << Constants.WaterHeaterOperatingModeStandard
    operating_mode_args << Constants.WaterHeaterOperatingModeHeatPumpOnly
    operating_mode = OpenStudio::Measure::OSArgument::makeChoiceArgument('operating_mode', operating_mode_args, true)
    operating_mode.setDisplayName('Operating Mode')
    operating_mode.setDescription("The water heater operating mode. The '#{Constants.WaterHeaterOperatingModeHeatPumpOnly}' option only uses the heat pump, while '#{Constants.WaterHeaterOperatingModeStandard}' allows the backup electric resistance to come on in high demand situations. This is ignored if a scheduled operating mode type is selected.")
    operating_mode.setDefaultValue(Constants.WaterHeaterOperatingModeStandard)
    args << operating_mode

    # make an argument for the directory that contains the hourly schedules
    arg = OpenStudio::Measure::OSArgument.makeStringArgument('schedules_directory', true)
    arg.setDisplayName('Setpoint and Operating Mode Schedule Directory')
    arg.setDescription('Absolute (or relative) directory to schedule files. This argument will be ignored if a constant setpoint type is used instead.')
    arg.setDefaultValue('./resources')
    args << arg

    # make an argument for the 8760 hourly setpoint schedule
    arg = OpenStudio::Measure::OSArgument.makeStringArgument('setpoint_schedule', true)
    arg.setDisplayName('Setpoint Schedule File Name')
    arg.setDescription('Name of the hourly setpoint schedule. Setpoint should be defined (in F) for every hour. The operating mode schedule must also be located in the same location. This will be ignored if a constant setpoint is selected.')
    arg.setDefaultValue('hourly_setpoint_schedule.csv')
    args << arg

    # make an argument for the 8760 hourly control mode schedule
    arg = OpenStudio::Measure::OSArgument.makeStringArgument('operating_mode_schedule', true)
    arg.setDisplayName('Operating Mode Schedule File Name')
    arg.setDescription("Name of the hourly operating mode schedule. Valid values are 'standard' and 'hp_only' and values must be specified for every hour. The setpoint schedule must also be located in the same location.")
    arg.setDefaultValue('hourly_operating_mode_schedule.csv')
    args << arg

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

    # make an argument for element_capacity
    element_capacity = osargument::makeDoubleArgument('element_capacity', true)
    element_capacity.setDisplayName('Input Capacity')
    element_capacity.setDescription('The capacity of the backup electric resistance elements in the tank.')
    element_capacity.setUnits('kW')
    element_capacity.setDefaultValue(4.5)
    args << element_capacity

    # make an argument for min_temp
    min_temp = osargument::makeDoubleArgument('min_temp', true)
    min_temp.setDisplayName('Minimum Abient Temperature')
    min_temp.setDescription('The minimum ambient air temperature at which the heat pump compressor will operate.')
    min_temp.setUnits('F')
    min_temp.setDefaultValue(45)
    args << min_temp

    # make an argument for max_temp
    max_temp = osargument::makeDoubleArgument('max_temp', true)
    max_temp.setDisplayName('Maximum Ambient Temperature')
    max_temp.setDescription('The maximum ambient air temperature at which the heat pump compressor will operate.')
    max_temp.setUnits('F')
    max_temp.setDefaultValue(120)
    args << max_temp

    # make an argument for cap
    cap = osargument::makeDoubleArgument('cap', true)
    cap.setDisplayName('Rated Capacity')
    cap.setDescription('The input power of the HPWH compressor at rated conditions.')
    cap.setUnits('kW')
    cap.setDefaultValue(0.5)
    args << cap

    # make an argument for cop
    cop = osargument::makeDoubleArgument('cop', true)
    cop.setDisplayName('Rated COP')
    cop.setDescription('The coefficient of performance of the HPWH compressor at rated conditions.')
    cop.setDefaultValue(2.8)
    args << cop

    # make an argument for shr
    shr = osargument::makeDoubleArgument('shr', true)
    shr.setDisplayName('Rated SHR')
    shr.setDescription("The sensible heat ratio of the HPWH's evaporator at rated conditions. This is the net SHR of the evaporator and includes the effects of fan heat.")
    shr.setDefaultValue(0.88)
    args << shr

    # make an argument for airflow_rate
    airflow_rate = osargument::makeDoubleArgument('airflow_rate', true)
    airflow_rate.setDisplayName('Airflow Rate')
    airflow_rate.setDescription('Air flow rate of the HPWH.')
    airflow_rate.setUnits('cfm')
    airflow_rate.setDefaultValue(181)
    args << airflow_rate

    # make an argument for fan_power
    fan_power = osargument::makeDoubleArgument('fan_power', true)
    fan_power.setDisplayName('Fan Power')
    fan_power.setDescription('Fan power (in W) per delivered airflow rate (in cfm).')
    fan_power.setUnits('W/cfm')
    fan_power.setDefaultValue(0.0462)
    args << fan_power

    # make an argument for parasitics
    parasitics = osargument::makeDoubleArgument('parasitics', true)
    parasitics.setDisplayName('Parasitics')
    parasitics.setDescription('Parasitic electricity consumption of the HPWH.')
    parasitics.setUnits('W')
    parasitics.setDefaultValue(3)
    args << parasitics

    # make an argument for tank_ua
    tank_ua = osargument::makeDoubleArgument('tank_ua', true)
    tank_ua.setDisplayName('Tank UA')
    tank_ua.setDescription('The overall UA of the tank.')
    tank_ua.setUnits('Btu/h-R')
    tank_ua.setDefaultValue(3.9)
    args << tank_ua

    # make an argument for int_factor
    int_factor = osargument::makeDoubleArgument('int_factor', true)
    int_factor.setDisplayName('Interaction Factor')
    int_factor.setDescription("Specifies how much the HPWH space conditioning impact interacts with the building's HVAC equipment. This can be used to account for situations such as when a HPWH is in a closet and only a portion of the HPWH's space cooling affects the HVAC system.")
    int_factor.setDefaultValue(1.0)
    args << int_factor

    # make an argument for temp_depress
    temp_depress = osargument::makeDoubleArgument('temp_depress', true)
    temp_depress.setDisplayName('Temperature Depression')
    temp_depress.setDescription('The reduction in ambient air temperature in the space where the water heater is located. This variable can be used to simulate the impact the HPWH has on its own performance when installing in a confined space suc as a utility closet.')
    temp_depress.setUnits('F')
    temp_depress.setDefaultValue(0)
    args << temp_depress

    # make an argument for ducting
    # COMMENTED OUT FOR NOW, NEED TO INTEGRATE WITH AIRFLOW MEASURE
    # ducting_names = OpenStudio::StringVector.new
    # ducting_names << "none"
    # ducting_names << Constants.VentTypeExhaust
    # ducting_names << Constants.VentTypeSupply
    # ducting_names << Constants.VentTypeBalanced
    # ducting = osargument::makeChoiceArgument("ducting", ducting_names, true)
    # ducting.setDisplayName("Ducting")
    # ducting.setDescription("Specifies where the HPWH pulls air from/exhausts to. The HPWH can currentlyonly be ducted outside of the home, not to different zones within the home.")
    # ducting.setDefaultValue("none")
    # args << ducting

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Assign user inputs to variables
    e_cap = runner.getDoubleArgumentValue('element_capacity', user_arguments)
    vol = runner.getDoubleArgumentValue('storage_tank_volume', user_arguments)
    location = runner.getStringArgumentValue('location', user_arguments)
    setpoint_type = runner.getStringArgumentValue('setpoint_type', user_arguments)
    t_set = runner.getDoubleArgumentValue('setpoint_temp', user_arguments).to_f
    operating_mode_schedule_type = runner.getStringArgumentValue('operating_mode_schedule_type', user_arguments)
    operating_mode = runner.getStringArgumentValue('operating_mode', user_arguments)
    schedule_directory = runner.getStringArgumentValue('schedules_directory', user_arguments)
    setpoint_schedule = runner.getStringArgumentValue('setpoint_schedule', user_arguments)
    operating_mode_schedule = runner.getStringArgumentValue('operating_mode_schedule', user_arguments)
    min_temp = runner.getDoubleArgumentValue('min_temp', user_arguments).to_f
    max_temp = runner.getDoubleArgumentValue('max_temp', user_arguments).to_f
    cap = runner.getDoubleArgumentValue('cap', user_arguments).to_f
    cop = runner.getDoubleArgumentValue('cop', user_arguments).to_f
    shr = runner.getDoubleArgumentValue('shr', user_arguments).to_f
    airflow_rate = runner.getDoubleArgumentValue('airflow_rate', user_arguments).to_f
    fan_power = runner.getDoubleArgumentValue('fan_power', user_arguments).to_f
    parasitics = runner.getDoubleArgumentValue('parasitics', user_arguments).to_f
    tank_ua = runner.getDoubleArgumentValue('tank_ua', user_arguments).to_f
    int_factor = runner.getDoubleArgumentValue('int_factor', user_arguments).to_f
    temp_depress = runner.getDoubleArgumentValue('temp_depress', user_arguments).to_f
    # ducting = runner.getStringArgumentValue("ducting",user_arguments)
    ducting = 'none'

    if (setpoint_type == Constants.WaterHeaterSetpointTypeScheduled) || (operating_mode_schedule_type == Constants.WaterHeaterOperatingModeTypeScheduled)
      unless (Pathname.new schedule_directory).absolute?
        schedule_directory = File.expand_path(File.join(File.dirname(__FILE__), schedule_directory))
      end
      if setpoint_type == Constants.WaterHeaterSetpointTypeScheduled
        setpoint_schedule_file = File.join(schedule_directory, setpoint_schedule)
        if not File.exist?(setpoint_schedule_file)
          runner.registerError("'#{setpoint_schedule_file}' does not exist.")
          return false
        end
      end
      if operating_mode_schedule_type == Constants.WaterHeaterOperatingModeTypeScheduled
        operating_mode_schedule_file = File.join(schedule_directory, operating_mode_schedule)
        if not File.exist?(operating_mode_schedule_file)
          runner.registerError("'#{operating_mode_schedule_file}' does not exist.")
          return false
        end
      end
    end

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

    weather = WeatherProcess.new(model, runner)
    if weather.error?
      return false
    end

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

      success = Waterheater.apply_heatpump(model, unit, runner, loop, space, weather,
                                           e_cap, vol, setpoint_type, t_set, operating_mode,
                                           operating_mode_schedule_type, setpoint_schedule_file,
                                           operating_mode_schedule_file, min_temp, max_temp,
                                           cap, cop, shr, airflow_rate, fan_power,
                                           parasitics, tank_ua, int_factor, temp_depress,
                                           ducting, unit_index)
      return false if not success
    end

    runner.registerFinalCondition("A new #{vol.round} gallon heat pump water heater, with a rated COP of #{cop} and a nominal heat pump capacity of #{(cap * cop).round(2)} kW has been added to the model")

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ResidentialHotWaterHeaterHeatPump.new.registerWithApplication
