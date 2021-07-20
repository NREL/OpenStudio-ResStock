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
class ResidentialHotWaterHeaterTank < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Tank Water Heater'
  end

  def description
    return "This measure adds a new residential storage water heater to the model based on user inputs. If there is already an existing residential water heater in the model, it is replaced. For multifamily buildings, the water heater can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return "The measure will create a new instance of the OS:WaterHeater:Mixed object representing a storage water heater. The water heater will be placed on the plant loop 'Domestic Hot Water Loop'. If this loop already exists, any water heater on that loop will be removed and replaced with a water heater consistent with this measure. If it doesn't exist, it will be created."
  end

  # define the arguments that the user will input
  def arguments(model)
    ruleset = OpenStudio::Measure

    osargument = ruleset::OSArgument

    args = ruleset::OSArgumentVector.new

    # make a string argument for water heater fuel type
    fuel_display_names = OpenStudio::StringVector.new
    fuel_display_names << Constants.FuelTypeGas
    fuel_display_names << Constants.FuelTypeOil
    fuel_display_names << Constants.FuelTypePropane
    fuel_display_names << Constants.FuelTypeElectric
    fuel_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('fuel_type', fuel_display_names, true)
    fuel_type.setDisplayName('Fuel Type')
    fuel_type.setDescription('Type of fuel used for water heating.')
    fuel_type.setDefaultValue(Constants.FuelTypeGas)
    args << fuel_type

    # make an argument for the storage tank volume
    tank_volume = osargument::makeStringArgument('tank_volume', true)
    tank_volume.setDisplayName('Tank Volume')
    tank_volume.setDescription("Nominal volume of the of the water heater tank. Set to #{Constants.Auto} to have volume autosized.")
    tank_volume.setUnits('gal')
    tank_volume.setDefaultValue(Constants.Auto)
    args << tank_volume

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
    setpoint_temp = osargument::makeDoubleArgument('setpoint_temp', true)
    setpoint_temp.setDisplayName('Setpoint')
    setpoint_temp.setDescription('Water heater setpoint temperature. This value will be ignored if the setpoint type is Scheduled.')
    setpoint_temp.setUnits('F')
    setpoint_temp.setDefaultValue(125)
    args << setpoint_temp

    # make an argument for the directory that contains the hourly schedules
    sp_dir = OpenStudio::Measure::OSArgument.makeStringArgument('schedules_directory', true)
    sp_dir.setDisplayName('Setpoint and Operating Mode Schedule Directory')
    sp_dir.setDescription('Absolute (or relative) directory to schedule files. This argument will be ignored if a constant setpoint type is used instead.')
    sp_dir.setDefaultValue('./resources')
    args << sp_dir

    # make an argument for the 8760 hourly setpoint schedule
    sp_sch = OpenStudio::Measure::OSArgument.makeStringArgument('setpoint_schedule', true)
    sp_sch.setDisplayName('Setpoint Schedule File Name')
    sp_sch.setDescription('Name of the hourly setpoint schedule. Setpoint should be defined (in F) for every hour. The operating mode schedule must also be located in the same location.')
    sp_sch.setDefaultValue('hourly_setpoint_schedule.csv')
    args << sp_sch

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
    capacity = osargument::makeStringArgument('capacity', true)
    capacity.setDisplayName('Input Capacity')
    capacity.setDescription("The maximum energy input rating of the water heater. Set to #{Constants.Auto} to have this field autosized.")
    capacity.setUnits('kBtu/hr')
    capacity.setDefaultValue('40.0')
    args << capacity

    # make an argument for the rated energy factor
    energy_factor = osargument::makeStringArgument('energy_factor', true)
    energy_factor.setDisplayName('Rated Energy Factor')
    energy_factor.setDescription("Ratio of useful energy output from the water heater to the total amount of energy delivered from the water heater. Enter #{Constants.Auto} for a water heater that meets the minimum federal efficiency requirements.")
    energy_factor.setDefaultValue('0.59')
    args << energy_factor

    # make an argument for recovery_efficiency
    recovery_efficiency = osargument::makeDoubleArgument('recovery_efficiency', true)
    recovery_efficiency.setDisplayName('Recovery Efficiency')
    recovery_efficiency.setDescription('Ratio of energy delivered to the water to the energy content of the fuel consumed by the water heater. Only used for non-electric water heaters.')
    recovery_efficiency.setUnits('Frac')
    recovery_efficiency.setDefaultValue(0.76)
    args << recovery_efficiency

    # make an argument on cycle electricity consumption
    offcyc_power = osargument::makeDoubleArgument('offcyc_power', true)
    offcyc_power.setDisplayName('Parasitic Electric Power')
    offcyc_power.setDescription('Off cycle electric power draw for controls, etc. Only used for non-electric water heaters.')
    offcyc_power.setUnits('W')
    offcyc_power.setDefaultValue(0)
    args << offcyc_power

    # make an argument on cycle electricity consumption
    oncyc_power = osargument::makeDoubleArgument('oncyc_power', true)
    oncyc_power.setDisplayName('Forced Draft Fan Power')
    oncyc_power.setDescription('On cycle electric power draw from the forced draft fan motor. Only used for non-electric water heaters.')
    oncyc_power.setUnits('W')
    oncyc_power.setDefaultValue(0)
    args << oncyc_power

    # make a bool argument for open water heater flue
    has_water_heater_flue = OpenStudio::Measure::OSArgument::makeBoolArgument('has_water_heater_flue', true)
    has_water_heater_flue.setDisplayName('Air Leakage: Has Open Water Heater Flue')
    has_water_heater_flue.setDescription('Specifies whether the building has an open flue associated with the water heater.')
    has_water_heater_flue.setDefaultValue(false)
    args << has_water_heater_flue

    # make a string argument for mixed or stratified tank
    tank_model_type_display_name = OpenStudio::StringVector.new
    tank_model_type_display_name << Constants.WaterHeaterTypeTankModelTypeMixed
    tank_model_type_display_name << Constants.WaterHeaterTypeTankModelTypeStratified
    tank_model_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('tank_model_type', tank_model_type_display_name, true)
    tank_model_type.setDisplayName('Tank Type')
    tank_model_type.setDescription("Type of tank model to use. The '#{Constants.WaterHeaterTypeTankModelTypeStratified}' tank generally provide more accurate results, but may significantly increase run time.")
    tank_model_type.setDefaultValue(Constants.WaterHeaterTypeTankModelTypeMixed)
    args << tank_model_type

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Assign user inputs to variables
    fuel_type = runner.getStringArgumentValue('fuel_type', user_arguments)
    capacity = runner.getStringArgumentValue('capacity', user_arguments)
    tank_volume = runner.getStringArgumentValue('tank_volume', user_arguments)
    energy_factor = runner.getStringArgumentValue('energy_factor', user_arguments)
    recovery_efficiency = runner.getDoubleArgumentValue('recovery_efficiency', user_arguments)
    location = runner.getStringArgumentValue('location', user_arguments)
    setpoint_type = runner.getStringArgumentValue('setpoint_type', user_arguments)
    setpoint_temp = runner.getDoubleArgumentValue('setpoint_temp', user_arguments).to_f
    schedule_directory = runner.getStringArgumentValue('schedules_directory', user_arguments)
    setpoint_schedule = runner.getStringArgumentValue('setpoint_schedule', user_arguments)
    oncycle_power = runner.getDoubleArgumentValue('oncyc_power', user_arguments)
    offcycle_power = runner.getDoubleArgumentValue('offcyc_power', user_arguments)
    model.getBuilding.additionalProperties.setFeature('has_water_heater_flue', runner.getBoolArgumentValue('has_water_heater_flue', user_arguments))
    tank_model_type = runner.getStringArgumentValue('tank_model_type', user_arguments)

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

    if setpoint_type == Constants.WaterHeaterSetpointTypeScheduled
      unless (Pathname.new schedule_directory).absolute?
        schedule_directory = File.expand_path(File.join(File.dirname(__FILE__), schedule_directory))
      end
      setpoint_schedule_file = File.join(schedule_directory, setpoint_schedule)

      # Error checking: make sure the schedule file is an appropriate length and values are valid
      # setpoint_hourly = HourlySchedule.new(model, runner, sch_name, dr_schedule_file, 0, false, [])
      # setpoint_hourly_array = setpoint_hourly.schedule_array.map { |x| x.to_i }
      # setpoint_hourly.schedule.remove

      # year_description = model.getYearDescription
      # assumed_year = year_description.assumedYear
      # yr_hrs = Constants.NumHoursInYear(year_description.isLeapYear)
      # run_period = model.getRunPeriod
      # run_period_start = Time.new(assumed_year, run_period.getBeginMonth, run_period.getBeginDayOfMonth)
      # run_period_end = Time.new(assumed_year, run_period.getEndMonth, run_period.getEndDayOfMonth, 24)
      # sim_hours = (run_period_end - run_period_start) / 3600

      # year_description = model.getYearDescription
      # n_days = Constants.NumDaysInYear(year_description.isLeapYear)
      # if (sp_hourly_array.length != sim_hours) and (sp_hourly_array.length != n_days * 24)
      #  runner.registerError("Hourly water heater setpoint schedule length must equal to a full year")
      #  return false
      # end
      # return true

      if not File.exist?(setpoint_schedule_file)
        runner.registerError("'#{setpoint_schedule_file}' does not exist.")
        return false
      end
    end

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

      # Get unit beds/baths
      nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
      if nbeds.nil? || nbaths.nil?
        return false
      end

      # Calculate values if autosized
      capacity = Waterheater.calc_capacity(capacity, fuel_type, nbeds, nbaths)
      tank_volume = calc_nom_tankvol(tank_volume, fuel_type, nbeds, nbaths)
      energy_factor = calc_ef(energy_factor, tank_volume, fuel_type)

      success = Waterheater.apply_tank(model, unit, runner, loop, space, fuel_type,
                                       capacity, tank_volume, energy_factor,
                                       recovery_efficiency, setpoint_type,
                                       setpoint_temp, setpoint_schedule_file,
                                       oncycle_power, offcycle_power, 1.0,
                                       tank_model_type)
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
      te = heater.getHeaterThermalEfficiency

      water_heaters << "Water heater '#{heatername}' added to plant loop '#{loopname}', with a capacity of #{capacity.round(1)} kBtu/hr" +
                       " and an actual tank volume of #{volume.round(1)} gal."
    end
    water_heaters
  end

  def calc_nom_tankvol(vol, fuel, num_beds, num_baths)
    # Calculates the volume of a water heater
    if vol == Constants.Auto
      # Based on the BA HSP
      if fuel == Constants.FuelTypeElectric
        # Source: Table 5 HUD-FHA Minimum Water Heater Capacities for One- and
        # Two-Family Living Units (ASHRAE HVAC Applications 2007)
        if num_baths < 2
          if num_beds < 2
            return 20
          elsif num_beds < 3
            return 30
          else
            return 40
          end
        elsif num_baths < 3
          if num_beds < 3
            return 40
          elsif num_beds < 5
            return 50
          else
            return 66
          end
        else
          if num_beds < 4
            return 50
          elsif num_beds < 6
            return 66
          else
            return 80
          end
        end

      else # Non-electric tank WHs
        # Source: 2010 HSP Addendum
        if num_beds <= 2
          return 30
        elsif num_beds == 3
          if num_baths <= 1.5
            return 30
          else
            return 40
          end
        elsif num_beds == 4
          if num_baths <= 2.5
            return 40
          else
            return 50
          end
        else
          return 50
        end
      end
    else # user entered volume
      return vol.to_f
    end
  end

  def calc_ef(ef, vol, fuel)
    # Calculate the energy factor as a function of the tank volume and fuel type
    if ef == Constants.Auto
      if (fuel == Constants.FuelTypePropane) || (fuel == Constants.FuelTypeGas)
        return 0.67 - (0.0019 * vol)
      elsif fuel == Constants.FuelTypeElectric
        return 0.97 - (0.00132 * vol)
      else
        return 0.59 - (0.0019 * vol)
      end
    else # user input energy factor
      return ef.to_f
    end
  end
end # end the measure

# this allows the measure to be use by the application
ResidentialHotWaterHeaterTank.new.registerWithApplication
