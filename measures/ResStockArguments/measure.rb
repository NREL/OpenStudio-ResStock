# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'openstudio'
if File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/hpxml-measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock on AWS
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/hpxml-measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/hpxml-measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock unit tests locally
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/hpxml-measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources')
else
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
end
require File.join(resources_path, 'location')
require File.join(resources_path, 'meta_measure')
require File.join(resources_path, 'weather')

require_relative 'resources/constants'

# start the measure
class ResStockArguments < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'ResStock Arguments'
  end

  # human readable description
  def description
    return 'Measure that extends the arguments available for ResStock.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Defines the set of arguments needed for ResStock that are not available in BuildResidentialHPXML.'
  end

  # define the arguments that the user will input
  def arguments(model)
    measures_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/hpxml-measures'))
    measure_subdir = 'BuildResidentialHPXML'
    full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
    measure = get_measure_instance(full_measure_path)

    args = OpenStudio::Measure::OSArgumentVector.new
    measure.arguments(model).each do |arg|
      next if Constants.excludes.include? arg.name

      # Exclude the geometry_cfa arg from BuildResHPXML in lieu of the one below.
      # We can't add it to Constants.excludes because a geometry_cfa value will still
      # need to be passed to the BuildResHPXML measure.
      next if arg.name == 'geometry_cfa'

      args << arg
    end

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('geometry_cfa_bin', true)
    arg.setDisplayName('Geometry: Conditioned Floor Area Bin')
    arg.setDescription("E.g., '2000-2499'")
    arg.setDefaultValue('2000-2499')
    args << arg

    # Adds a geometry_cfa argument similar to the BuildResidentialHPXML measure, but as a string with "auto" allowed
    arg = OpenStudio::Measure::OSArgument::makeStringArgument('geometry_cfa', true)
    arg.setDisplayName('Geometry: Conditioned Floor Area')
    arg.setDescription("E.g., '2000' or '#{Constants.Auto}'")
    arg.setUnits('sqft')
    arg.setDefaultValue('2000')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('plug_loads_other_usage_multiplier_2', true)
    arg.setDisplayName('Plug Loads: Other Usage Multiplier 2')
    arg.setDescription('Additional multiplier on the other energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('plug_loads_well_pump_usage_multiplier_2', true)
    arg.setDisplayName('Plug Loads: Well Pump Usage Multiplier 2')
    arg.setDescription('Additional multiplier on the well pump energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('plug_loads_vehicle_usage_multiplier_2', true)
    arg.setDisplayName('Plug Loads: Vehicle Usage Multiplier 2')
    arg.setDescription('Additional multiplier on the electric vehicle energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('setpoint_heating_weekday_temp', true)
    arg.setDisplayName('Heating Setpoint: Weekday Temperature')
    arg.setDescription('Specify the weekday heating setpoint temperature.')
    arg.setUnits('deg-F')
    arg.setDefaultValue(71)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('setpoint_heating_weekend_temp', true)
    arg.setDisplayName('Heating Setpoint: Weekend Temperature')
    arg.setDescription('Specify the weekend heating setpoint temperature.')
    arg.setUnits('deg-F')
    arg.setDefaultValue(71)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('setpoint_heating_weekday_offset_magnitude', true)
    arg.setDisplayName('Heating Setpoint: Weekday Offset Magnitude')
    arg.setDescription('Specify the weekday heating offset magnitude.')
    arg.setUnits('deg-F')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('setpoint_heating_weekend_offset_magnitude', true)
    arg.setDisplayName('Heating Setpoint: Weekend Offset Magnitude')
    arg.setDescription('Specify the weekend heating offset magnitude.')
    arg.setUnits('deg-F')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('setpoint_heating_weekday_schedule', true)
    arg.setDisplayName('Heating Setpoint: Weekday Schedule')
    arg.setDescription('Specify the 24-hour comma-separated weekday heating schedule of 0s and 1s.')
    arg.setDefaultValue('0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('setpoint_heating_weekend_schedule', true)
    arg.setDisplayName('Heating Setpoint: Weekend Schedule')
    arg.setDescription('Specify the 24-hour comma-separated weekend heating schedule of 0s and 1s.')
    arg.setDefaultValue('0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('use_auto_heating_season', true)
    arg.setDisplayName('Use Auto Heating Season')
    arg.setDescription('Specifies whether to automatically define the heating season based on the weather file.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('setpoint_cooling_weekday_temp', true)
    arg.setDisplayName('Cooling Setpoint: Weekday Temperature')
    arg.setDescription('Specify the weekday cooling setpoint temperature.')
    arg.setUnits('deg-F')
    arg.setDefaultValue(76)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('setpoint_cooling_weekend_temp', true)
    arg.setDisplayName('Cooling Setpoint: Weekend Temperature')
    arg.setDescription('Specify the weekend cooling setpoint temperature.')
    arg.setUnits('deg-F')
    arg.setDefaultValue(76)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('setpoint_cooling_weekday_offset_magnitude', true)
    arg.setDisplayName('Cooling Setpoint: Weekday Offset Magnitude')
    arg.setDescription('Specify the weekday cooling offset magnitude.')
    arg.setUnits('deg-F')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('setpoint_cooling_weekend_offset_magnitude', true)
    arg.setDisplayName('Cooling Setpoint: Weekend Offset Magnitude')
    arg.setDescription('Specify the weekend cooling offset magnitude.')
    arg.setUnits('deg-F')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('setpoint_cooling_weekday_schedule', true)
    arg.setDisplayName('Cooling Setpoint: Weekday Schedule')
    arg.setDescription('Specify the 24-hour comma-separated weekday cooling schedule of 0s and 1s.')
    arg.setDefaultValue('0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('setpoint_cooling_weekend_schedule', true)
    arg.setDisplayName('Cooling Setpoint: Weekend Schedule')
    arg.setDescription('Specify the 24-hour comma-separated weekend cooling schedule of 0s and 1s.')
    arg.setDefaultValue('0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('use_auto_cooling_season', true)
    arg.setDisplayName('Use Auto Cooling Season')
    arg.setDescription('Specifies whether to automatically define the cooling season based on the weather file.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('heating_system_has_flue_or_chimney', true)
    arg.setDisplayName('Heating System: Has Flue or Chimney')
    arg.setDescription('Whether the heating system has a flue or chimney.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('heating_system_has_flue_or_chimney_2', true)
    arg.setDisplayName('Heating System 2: Has Flue or Chimney')
    arg.setDescription('Whether the second heating system has a flue or chimney.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('water_heater_has_flue_or_chimney', true)
    arg.setDisplayName('Water Heater: Has Flue or Chimney')
    arg.setDescription('Whether the water heater has a flue or chimney.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_rated_cfm_per_ton', false)
    arg.setDisplayName('Heating System: Rated CFM Per Ton')
    arg.setUnits('cfm/ton')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_actual_cfm_per_ton', false)
    arg.setDisplayName('Heating System: Actual CFM Per Ton')
    arg.setUnits('cfm/ton')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_rated_cfm_per_ton', false)
    arg.setDisplayName('Cooling System: Rated CFM Per Ton')
    arg.setUnits('cfm/ton')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_actual_cfm_per_ton', false)
    arg.setDisplayName('Cooling System: Actual CFM Per Ton')
    arg.setUnits('cfm/ton')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_frac_manufacturer_charge', false)
    arg.setDisplayName('Cooling System: Fraction of Manufacturer Recommended Charge')
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_rated_cfm_per_ton', false)
    arg.setDisplayName('Heat Pump: Rated CFM Per Ton')
    arg.setUnits('cfm/ton')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_actual_cfm_per_ton', false)
    arg.setDisplayName('Heat Pump: Actual CFM Per Ton')
    arg.setUnits('cfm/ton')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_frac_manufacturer_charge', false)
    arg.setDisplayName('Heat Pump: Fraction of Manufacturer Recommended Charge')
    arg.setUnits('Frac')
    args << arg

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    args = get_argument_values(runner, arguments(model), user_arguments)

    measures_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/hpxml-measures'))
    measure_subdir = 'BuildResidentialHPXML'
    full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
    measure = get_measure_instance(full_measure_path)

    arg_names = []
    measure.arguments(model).each do |arg|
      next if Constants.excludes.include? arg.name

      arg_names << arg.name
    end

    args_to_delete = args.keys - arg_names # these are the extra ones added in the arguments section

    # Conditioned floor area
    if args['geometry_cfa'] == Constants.Auto
      cfas = { ['0-499', HPXML::ResidentialTypeSFD] => 328,
               ['0-499', HPXML::ResidentialTypeSFA] => 317,
               ['0-499', HPXML::ResidentialTypeApartment] => 333,
               ['500-749', HPXML::ResidentialTypeSFD] => 633,
               ['500-749', HPXML::ResidentialTypeSFA] => 617,
               ['500-749', HPXML::ResidentialTypeApartment] => 617,
               ['750-999', HPXML::ResidentialTypeSFD] => 885,
               ['750-999', HPXML::ResidentialTypeSFA] => 866,
               ['750-999', HPXML::ResidentialTypeApartment] => 853,
               ['1000-1499', HPXML::ResidentialTypeSFD] => 1220,
               ['1000-1499', HPXML::ResidentialTypeSFA] => 1202,
               ['1000-1499', HPXML::ResidentialTypeApartment] => 1138,
               ['1500-1999', HPXML::ResidentialTypeSFD] => 1690,
               ['1500-1999', HPXML::ResidentialTypeSFA] => 1675,
               ['1500-1999', HPXML::ResidentialTypeApartment] => 1623,
               ['2000-2499', HPXML::ResidentialTypeSFD] => 2176,
               ['2000-2499', HPXML::ResidentialTypeSFA] => 2152,
               ['2000-2499', HPXML::ResidentialTypeApartment] => 2115,
               ['2500-2999', HPXML::ResidentialTypeSFD] => 2663,
               ['2500-2999', HPXML::ResidentialTypeSFA] => 2631,
               ['2500-2999', HPXML::ResidentialTypeApartment] => 2590,
               ['3000-3999', HPXML::ResidentialTypeSFD] => 3301,
               ['3000-3999', HPXML::ResidentialTypeSFA] => 3241,
               ['3000-3999', HPXML::ResidentialTypeApartment] => 3138,
               ['4000+', HPXML::ResidentialTypeSFD] => 8194,
               ['4000+', HPXML::ResidentialTypeSFA] => 13414,
               ['4000+', HPXML::ResidentialTypeApartment] => 12291 }
      cfa = cfas[[args['geometry_cfa_bin'], args['geometry_unit_type']]]
      if cfa.nil?
        runner.registerError("Could not look up conditioned floor area for '#{args['geometry_cfa_bin']}' and 'args['geometry_unit_type']'.")
        return false
      end
      args['geometry_cfa'] = Float(cfa)
    else
      args['geometry_cfa'] = Float(args['geometry_cfa'])
    end

    # Num Occupants
    if args['geometry_num_occupants'] == Constants.Auto
      args['geometry_num_occupants'] = Geometry.get_occupancy_default_num(args['geometry_num_bedrooms'])
    else
      args['geometry_num_occupants'] = Integer(args['geometry_num_occupants'])
    end

    # Plug Loads
    args['plug_loads_television_annual_kwh'] = 0.0 # "other" now accounts for television
    args['plug_loads_television_usage_multiplier'] = 0.0 # "other" now accounts for television
    args['plug_loads_other_usage_multiplier'] *= args['plug_loads_other_usage_multiplier_2']
    args['plug_loads_well_pump_usage_multiplier'] *= args['plug_loads_well_pump_usage_multiplier_2']
    args['plug_loads_vehicle_usage_multiplier'] *= args['plug_loads_vehicle_usage_multiplier_2']

    if args['plug_loads_other_annual_kwh'] == Constants.Auto
      if [HPXML::ResidentialTypeSFD].include?(args['geometry_unit_type'])
        args['plug_loads_other_annual_kwh'] = 1146.95 + 296.94 * args['geometry_num_occupants'] + 0.3 * args['geometry_cfa'] # RECS 2015
      elsif [HPXML::ResidentialTypeSFA].include?(args['geometry_unit_type'])
        args['plug_loads_other_annual_kwh'] = 1395.84 + 136.53 * args['geometry_num_occupants'] + 0.16 * args['geometry_cfa'] # RECS 2015
      elsif [HPXML::ResidentialTypeApartment].include?(args['geometry_unit_type'])
        args['plug_loads_other_annual_kwh'] = 875.22 + 184.11 * args['geometry_num_occupants'] + 0.38 * args['geometry_cfa'] # RECS 2015
      end
    end

    # Misc LULs
    constant = 1.0 / 2
    nbr_coef = 1.0 / 4 / 3
    ffa_coef = 1.0 / 4 / 1920

    ['plug_loads_well_pump_annual_kwh',
     'fuel_loads_grill_annual_therm',
     'fuel_loads_lighting_annual_therm',
     'fuel_loads_fireplace_annual_therm',
     'pool_pump_annual_kwh',
     'pool_heater_annual_kwh',
     'pool_heater_annual_therm',
     'hot_tub_pump_annual_kwh',
     'hot_tub_heater_annual_kwh',
     'hot_tub_heater_annual_therm'].each do |annual_energy|
      next if args[annual_energy] != Constants.Auto

      if annual_energy == 'plug_loads_well_pump_annual_kwh'
        args[annual_energy] = 50.8 / 0.127
      elsif annual_energy == 'fuel_loads_grill_annual_therm'
        args[annual_energy] = 0.87 / 0.029
      elsif annual_energy == 'fuel_loads_lighting_annual_therm'
        args[annual_energy] = 0.22 / 0.012
      elsif annual_energy == 'fuel_loads_fireplace_annual_therm'
        args[annual_energy] = 1.95 / 0.032
      elsif annual_energy == 'pool_pump_annual_kwh'
        args[annual_energy] = 158.6 / 0.070
      elsif annual_energy == 'pool_heater_annual_kwh'
        args[annual_energy] = 8.3 / 0.004
      elsif annual_energy == 'pool_heater_annual_therm'
        args[annual_energy] = 3.0 / 0.014
      elsif annual_energy == 'hot_tub_pump_annual_kwh'
        args[annual_energy] = 59.5 / 0.059
      elsif annual_energy == 'hot_tub_heater_annual_kwh'
        args[annual_energy] = 49.0 / 0.048
      elsif annual_energy == 'hot_tub_heater_annual_therm'
        args[annual_energy] = 0.87 / 0.011
      end

      if [HPXML::ResidentialTypeSFD].include?(args['geometry_unit_type'])
        args[annual_energy] *= (constant + nbr_coef * (-1.47 + 1.69 * args['geometry_num_occupants']) + ffa_coef * args['geometry_cfa'])
      elsif [HPXML::ResidentialTypeSFA, HPXML::ResidentialTypeApartment].include?(args['geometry_unit_type'])
        args[annual_energy] *= (constant + nbr_coef * (-0.68 + 1.09 * args['geometry_num_occupants']) + ffa_coef * args['geometry_cfa'])
      end

      if annual_energy == 'pool_heater_annual_kwh' && args['pool_heater_type'] == HPXML::HeaterTypeHeatPump
        args[annual_energy] /= 5.0
      elsif annual_energy == 'hot_tub_heater_annual_kwh' && args['hot_tub_heater_type'] == HPXML::HeaterTypeHeatPump
        args[annual_energy] /= 5.0
      end
    end

    # Setpoints
    weekday_heating_setpoints = [args['setpoint_heating_weekday_temp']] * 24
    weekend_heating_setpoints = [args['setpoint_heating_weekend_temp']] * 24

    weekday_cooling_setpoints = [args['setpoint_cooling_weekday_temp']] * 24
    weekend_cooling_setpoints = [args['setpoint_cooling_weekend_temp']] * 24

    setpoint_heating_weekday_offset_magnitude = args['setpoint_heating_weekday_offset_magnitude']
    setpoint_heating_weekday_schedule = args['setpoint_heating_weekday_schedule'].split(',').map { |i| Float(i) }
    weekday_heating_setpoints = modify_setpoint_schedule(weekday_heating_setpoints, setpoint_heating_weekday_offset_magnitude, setpoint_heating_weekday_schedule)

    setpoint_heating_weekend_offset_magnitude = args['setpoint_heating_weekend_offset_magnitude']
    setpoint_heating_weekend_schedule = args['setpoint_heating_weekend_schedule'].split(',').map { |i| Float(i) }
    weekend_heating_setpoints = modify_setpoint_schedule(weekend_heating_setpoints, setpoint_heating_weekend_offset_magnitude, setpoint_heating_weekend_schedule)

    setpoint_cooling_weekday_offset_magnitude = args['setpoint_cooling_weekday_offset_magnitude']
    setpoint_cooling_weekday_schedule = args['setpoint_cooling_weekday_schedule'].split(',').map { |i| Float(i) }
    weekday_cooling_setpoints = modify_setpoint_schedule(weekday_cooling_setpoints, setpoint_cooling_weekday_offset_magnitude, setpoint_cooling_weekday_schedule)

    setpoint_cooling_weekend_offset_magnitude = args['setpoint_cooling_weekend_offset_magnitude']
    setpoint_cooling_weekend_schedule = args['setpoint_cooling_weekend_schedule'].split(',').map { |i| Float(i) }
    weekend_cooling_setpoints = modify_setpoint_schedule(weekend_cooling_setpoints, setpoint_cooling_weekend_offset_magnitude, setpoint_cooling_weekend_schedule)

    args['setpoint_heating_weekday'] = weekday_heating_setpoints.join(', ')
    args['setpoint_heating_weekend'] = weekend_heating_setpoints.join(', ')
    args['setpoint_cooling_weekday'] = weekday_cooling_setpoints.join(', ')
    args['setpoint_cooling_weekend'] = weekend_cooling_setpoints.join(', ')

    # Appliance energy adjustments based on # occupants
    occ_to_nbr_ratio = Float(args['geometry_num_occupants']) / Float(args['geometry_num_bedrooms'])
    if [HPXML::ResidentialTypeApartment, HPXML::ResidentialTypeSFA].include? args['geometry_unit_type']
      occ_factor = occ_to_nbr_ratio**0.51
    elsif [HPXML::ResidentialTypeSFD].include? args['geometry_unit_type']
      occ_factor = occ_to_nbr_ratio**0.70
    end
    if args['cooking_range_oven_location'] != 'none'
      args['cooking_range_oven_usage_multiplier'] *= occ_factor
    end
    if args['clothes_washer_location'] != 'none'
      args['clothes_washer_usage_multiplier'] *= occ_factor
    end
    if args['clothes_dryer_location'] != 'none'
      args['clothes_dryer_usage_multiplier'] *= occ_factor
    end
    if args['dishwasher_location'] != 'none'
      args['dishwasher_usage_multiplier'] *= occ_factor
    end

    # Seasons
    if args['use_auto_heating_season'] || args['use_auto_cooling_season']
      epw_path, cache_path = process_weather(args['weather_station_epw_filepath'], runner, model, '../in.xml')
      weather, epw_file = Location.apply_weather_file(model, runner, epw_path, cache_path)
      heating_months, cooling_months = HVAC.get_default_heating_and_cooling_seasons(weather)
    end

    if args['use_auto_heating_season']
      season_heating_begin_month, season_heating_begin_day_of_month, season_heating_end_month, season_heating_end_day_of_month = get_begin_and_end_dates_from_monthly_array(model, heating_months)
      args['season_heating_begin_month'] = season_heating_begin_month
      args['season_heating_begin_day_of_month'] = season_heating_begin_day_of_month
      args['season_heating_end_month'] = season_heating_end_month
      args['season_heating_end_day_of_month'] = season_heating_end_day_of_month
    end

    if args['use_auto_cooling_season']
      season_cooling_begin_month, season_cooling_begin_day_of_month, season_cooling_end_month, season_cooling_end_day_of_month = get_begin_and_end_dates_from_monthly_array(model, cooling_months)
      args['season_cooling_begin_month'] = season_cooling_begin_month
      args['season_cooling_begin_day_of_month'] = season_cooling_begin_day_of_month
      args['season_cooling_end_month'] = season_cooling_end_month
      args['season_cooling_end_day_of_month'] = season_cooling_end_day_of_month
    end

    # Flue or Chimney
    args['geometry_has_flue_or_chimney'] = Constants.Auto
    if (args['heating_system_has_flue_or_chimney'] == 'false') &&
       (args['heating_system_has_flue_or_chimney_2'] == 'false') &&
       (args['water_heater_has_flue_or_chimney'] == 'false')
      args['geometry_has_flue_or_chimney'] = 'false'
    elsif (args['heating_system_type'] != 'none' && args['heating_system_has_flue_or_chimney'] == 'true') ||
          (args['heating_system_type_2'] != 'none' && args['heating_system_has_flue_or_chimney_2'] == 'true') ||
          (args['water_heater_type'] != 'none' && args['water_heater_has_flue_or_chimney'] == 'true')
      args['geometry_has_flue_or_chimney'] = 'true'
    end

    # HVAC Faults
    if args['heating_system_rated_cfm_per_ton'].is_initialized && args['heating_system_actual_cfm_per_ton'].is_initialized
      args['heating_system_airflow_defect_ratio'] = (args['heating_system_actual_cfm_per_ton'].get - args['heating_system_rated_cfm_per_ton'].get) / args['heating_system_rated_cfm_per_ton'].get
    end

    if args['cooling_system_rated_cfm_per_ton'].is_initialized && args['cooling_system_actual_cfm_per_ton'].is_initialized
      args['cooling_system_airflow_defect_ratio'] = (args['cooling_system_actual_cfm_per_ton'].get - args['cooling_system_rated_cfm_per_ton'].get) / args['cooling_system_rated_cfm_per_ton'].get
    end

    if args['cooling_system_frac_manufacturer_charge'].is_initialized
      args['cooling_system_charge_defect_ratio'] = args['cooling_system_frac_manufacturer_charge'].get - 1.0
    end

    if args['heat_pump_rated_cfm_per_ton'].is_initialized && args['heat_pump_actual_cfm_per_ton'].is_initialized
      args['heat_pump_airflow_defect_ratio'] = (args['heat_pump_actual_cfm_per_ton'].get - args['heat_pump_rated_cfm_per_ton'].get) / args['cooling_system_rated_cfm_per_ton'].get
    end

    if args['heat_pump_frac_manufacturer_charge'].is_initialized
      args['heat_pump_charge_defect_ratio'] = args['heat_pump_frac_manufacturer_charge'].get - 1.0
    end

    # Infiltration adjustment for SFA/MF units
    if [HPXML::ResidentialTypeApartment, HPXML::ResidentialTypeSFA].include? args['geometry_unit_type']
      n_units = Float(args['geometry_building_num_units'])
      n_floors = Float(args['geometry_num_floors_above_grade'])
      aspect_ratio = Float(args['geometry_aspect_ratio'])
      horiz_location = args['geometry_horizontal_location'].to_s
      corridor_position = args['geometry_corridor_position'].to_s

      if args['geometry_unit_type'] == HPXML::ResidentialTypeApartment
        n_units_per_floor = n_units / n_floors
        if (n_units_per_floor >= 4) && (corridor_position != 'Single Exterior (Front)') # assume double-loaded corridor
          has_rear_units = true
        elsif (n_units_per_floor == 2) && (horiz_location == 'None') # double-loaded corridor for 2 units/story
          has_rear_units = true
        else
          has_rear_units = false
        end
      elsif args['geometry_unit_type'] == HPXML::ResidentialTypeSFA
        n_floors = 1.0
        n_units_per_floor = n_units
        has_rear_units = false
      end

      # Calculate exposed wall area ratio for the unit (unit exposed wall area
      # divided by average unit exposed wall area)
      if (n_units_per_floor <= 2) || (n_units_per_floor == 4 && has_rear_units) # No middle unit(s)
        exposed_wall_area_ratio = 1.0 # all units have same exterior wall area
      else # Has middle unit(s)
        if has_rear_units
          n_end_units = 4 * n_floors
          n_mid_units = n_units - n_end_units
          n_bldg_fronts_backs = n_end_units + n_mid_units
          n_bldg_sides = n_end_units
        else
          n_end_units = 2 * n_floors
          n_mid_units = n_units - n_end_units
          n_bldg_fronts_backs = n_end_units * 2 + n_mid_units * 2
          n_bldg_sides = n_end_units
        end
        if has_rear_units
          n_unit_fronts_backs = 1
        else
          n_unit_fronts_backs = 2
        end
        if ['Middle'].include? horiz_location
          n_unit_sides = 0
        elsif ['Left', 'Right'].include? horiz_location
          n_unit_sides = 1
        end
        n_bldg_sides_equivalent = n_bldg_sides + n_bldg_fronts_backs / aspect_ratio
        n_unit_sides_equivalent = n_unit_sides + n_unit_fronts_backs / aspect_ratio
        exposed_wall_area_ratio = n_unit_sides_equivalent / (n_bldg_sides_equivalent / n_units)
      end

      # Apply adjustment to infiltration value
      args['air_leakage_value'] *= exposed_wall_area_ratio
    end

    args.each do |arg_name, arg_value|
      begin
        if arg_value.is_initialized
          arg_value = arg_value.get
        else
          next
        end
      rescue
      end

      if args_to_delete.include? arg_name
        arg_value = '' # don't assign these to BuildResidentialHPXML
      end

      runner.registerValue(arg_name, arg_value)
    end

    return true
  end

  def modify_setpoint_schedule(schedule, offset_magnitude, offset_schedule)
    offset_schedule.each_with_index do |direction, i|
      schedule[i] += offset_magnitude * direction
    end
    return schedule
  end

  def process_weather(weather_station_epw_filepath, runner, model, hpxml_path)
    epw_path = weather_station_epw_filepath

    if not File.exist? epw_path
      test_epw_path = File.join(File.dirname(hpxml_path), epw_path)
      epw_path = test_epw_path if File.exist? test_epw_path
    end
    if not File.exist? epw_path
      test_epw_path = File.join(File.dirname(__FILE__), '..', 'weather', epw_path)
      epw_path = test_epw_path if File.exist? test_epw_path
    end
    if not File.exist? epw_path
      test_epw_path = File.join(File.dirname(__FILE__), '..', '..', 'weather', epw_path)
      epw_path = test_epw_path if File.exist? test_epw_path
    end
    if not File.exist?(epw_path)
      fail "'#{epw_path}' could not be found."
    end

    cache_path = epw_path.gsub('.epw', '-cache.csv')
    if not File.exist?(cache_path)
      # Process weather file to create cache .csv
      runner.registerWarning("'#{cache_path}' could not be found; regenerating it.")
      epw_file = OpenStudio::EpwFile.new(epw_path)
      OpenStudio::Model::WeatherFile.setWeatherFile(model, epw_file)
      weather = WeatherProcess.new(model, runner)
      begin
        File.open(cache_path, 'wb') do |file|
          weather.dump_to_csv(file)
        end
      rescue SystemCallError
        runner.registerWarning("#{cache_path} could not be written, skipping.")
      end
    end

    return epw_path, cache_path
  end

  def get_begin_and_end_dates_from_monthly_array(model, months)
    if months.include? 0
      if months[0] == 1 && months[11] == 1 # Wrap around year
        begin_month = 12 - months.reverse.index(0) + 1
        end_month = months.index(0)
      else
        begin_month = months.index(1) + 1
        end_month = 12 - months.reverse.index(1)
      end
    end
    get_num_days_per_month = Schedule.get_num_days_per_month(model)
    begin_day = 1
    end_day = get_num_days_per_month[end_month - 1]
    return begin_month, begin_day, end_month, end_day
  end
end

# register the measure to be used by the application
ResStockArguments.new.registerWithApplication
