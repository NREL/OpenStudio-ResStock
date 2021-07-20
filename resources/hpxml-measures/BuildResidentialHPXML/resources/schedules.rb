# frozen_string_literal: true

require 'csv'
require 'json'
require 'matrix'

class ScheduleGenerator
  def initialize(runner:,
                 model:,
                 epw_file:,
                 building_id: nil,
                 random_seed: nil)
    @runner = runner
    @model = model
    @epw_file = epw_file
    @state = 'CO'
    unless epw_file.stateProvinceRegion.empty?
      @state = epw_file.stateProvinceRegion
    end
    @building_id = building_id
    @random_seed = random_seed
  end

  def get_simulation_parameters
    @minutes_per_step = 60
    if @model.getSimulationControl.timestep.is_initialized
      @minutes_per_step = 60 / @model.getSimulationControl.timestep.get.numberOfTimestepsPerHour
    end

    @steps_in_day = 24 * 60 / @minutes_per_step

    @mkc_ts_per_day = 96
    @mkc_ts_per_hour = @mkc_ts_per_day / 24

    @model.getYearDescription.isLeapYear ? @total_days_in_year = 366 : @total_days_in_year = 365

    @sim_year = @model.getYearDescription.calendarYear.get
    @sim_start_day = DateTime.new(@sim_year, 1, 1)
  end

  def get_random_seed
    if @random_seed.nil?
      @runner.registerInfo('Unable to retrieve the schedules random seed; setting it to 1.')
      seed = 1
    else
      @runner.registerInfo("Retrieved the schedules random seed; setting it to #{@random_seed}.")
      seed = @random_seed
    end
    return seed
  end

  def self.col_names
    # col_name => affected_by_vacancy
    return {
      'occupants' => true,
      'lighting_interior' => true,
      'lighting_exterior' => true,
      'lighting_garage' => true,
      'lighting_exterior_holiday' => true,
      'cooking_range' => true,
      'refrigerator' => false,
      'extra_refrigerator' => false,
      'freezer' => false,
      'dishwasher' => true,
      'dishwasher_power' => true,
      'clothes_washer' => true,
      'clothes_washer_power' => true,
      'clothes_dryer' => true,
      'clothes_dryer_exhaust' => true,
      'baths' => true,
      'showers' => true,
      'sinks' => true,
      'fixtures' => true,
      'ceiling_fan' => true,
      'plug_loads_other' => true,
      'plug_loads_tv' => true,
      'plug_loads_vehicle' => true,
      'plug_loads_well_pump' => true,
      'fuel_loads_grill' => true,
      'fuel_loads_lighting' => true,
      'fuel_loads_fireplace' => true,
      'pool_pump' => false,
      'pool_heater' => false,
      'hot_tub_pump' => false,
      'hot_tub_heater' => false,
      'sleep' => nil,
      'vacancy' => nil
    }
  end

  def initialize_schedules
    @schedules = {}

    ScheduleGenerator.col_names.keys.each do |col_name|
      @schedules[col_name] = Array.new(@total_days_in_year * @steps_in_day, 0.0)
    end

    return @schedules
  end

  def schedules
    return @schedules
  end

  def create(args:)
    get_simulation_parameters
    initialize_schedules

    success = create_average_schedules(args: args)
    return false if not success

    success = create_stochastic_schedules(args: args)
    return false if not success

    success = set_vacancy(args: args)
    return false if not success

    return true
  end

  def create_average_schedules(args:)
    create_average_occupants
    create_average_cooking_range
    create_average_plug_loads_other
    create_average_plug_loads_tv
    create_average_plug_loads_vehicle
    create_average_plug_loads_well_pump
    create_average_lighting_interior
    create_average_lighting_exterior
    create_average_lighting_garage
    create_average_lighting_exterior_holiday
    create_average_clothes_washer(args: args)
    create_average_clothes_dryer(args: args)
    create_average_dishwasher(args: args)
    create_average_fixtures(args: args)
    create_average_ceiling_fan
    create_average_refrigerator
    create_average_extra_refrigerator
    create_average_freezer
    create_average_fuel_loads_grill
    create_average_fuel_loads_lighting
    create_average_fuel_loads_fireplace
    create_average_pool_pump
    create_average_pool_heater
    create_average_hot_tub_pump
    create_average_hot_tub_heater
  end

  def create_average_occupants
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'occupants', weekday_sch: Schedule.OccupantsWeekdayFractions, weekend_sch: Schedule.OccupantsWeekendFractions, monthly_sch: Schedule.OccupantsMonthlyMultipliers)
  end

  def create_average_lighting_interior
    lighting_sch = Lighting.get_schedule(@model, @epw_file)
    create_timeseries_from_months(sch_name: 'lighting_interior', month_schs: lighting_sch)
  end

  def create_average_lighting_exterior
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'lighting_exterior', weekday_sch: Schedule.LightingExteriorWeekdayFractions, weekend_sch: Schedule.LightingExteriorWeekendFractions, monthly_sch: Schedule.LightingExteriorMonthlyMultipliers)
  end

  def create_average_lighting_garage
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'lighting_garage', weekday_sch: Schedule.LightingExteriorWeekdayFractions, weekend_sch: Schedule.LightingExteriorWeekendFractions, monthly_sch: Schedule.LightingExteriorMonthlyMultipliers)
  end

  def create_average_lighting_exterior_holiday
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'lighting_exterior_holiday', weekday_sch: Schedule.LightingExteriorHolidayWeekdayFractions, weekend_sch: Schedule.LightingExteriorHolidayWeekendFractions, monthly_sch: Schedule.LightingExteriorHolidayMonthlyMultipliers, begin_month: 11, begin_day_of_month: 24, end_month: 1, end_day_of_month: 6)
  end

  def create_average_cooking_range
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'cooking_range', weekday_sch: Schedule.CookingRangeWeekdayFractions, weekend_sch: Schedule.CookingRangeWeekendFractions, monthly_sch: Schedule.CookingRangeMonthlyMultipliers)
  end

  def create_average_refrigerator
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'refrigerator', weekday_sch: Schedule.RefrigeratorWeekdayFractions, weekend_sch: Schedule.RefrigeratorWeekendFractions, monthly_sch: Schedule.RefrigeratorMonthlyMultipliers)
  end

  def create_average_extra_refrigerator
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'extra_refrigerator', weekday_sch: Schedule.ExtraRefrigeratorWeekdayFractions, weekend_sch: Schedule.ExtraRefrigeratorWeekendFractions, monthly_sch: Schedule.ExtraRefrigeratorMonthlyMultipliers)
  end

  def create_average_freezer
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'freezer', weekday_sch: Schedule.FreezerWeekdayFractions, weekend_sch: Schedule.FreezerWeekendFractions, monthly_sch: Schedule.FreezerMonthlyMultipliers)
  end

  def create_average_dishwasher(args:)
    create_timeseries_from_minutely(sch_name: 'dishwasher', obj_name: Constants.ObjectNameDishwasher, days_shift: 0, dryer_exhaust_min_runtime: 0, args: args)
    create_timeseries_from_minutely(sch_name: 'dishwasher_power', obj_name: Constants.ObjectNameDishwasher, days_shift: 0, dryer_exhaust_min_runtime: 0, args: args)
  end

  def create_average_clothes_washer(args:)
    create_timeseries_from_minutely(sch_name: 'clothes_washer', obj_name: Constants.ObjectNameClothesWasher, days_shift: 0, dryer_exhaust_min_runtime: 0, args: args)
    create_timeseries_from_minutely(sch_name: 'clothes_washer_power', obj_name: Constants.ObjectNameClothesWasher, days_shift: 0, dryer_exhaust_min_runtime: 0, args: args)
  end

  def create_average_clothes_dryer(args:)
    create_timeseries_from_minutely(sch_name: 'clothes_dryer', obj_name: Constants.ObjectNameClothesDryer, days_shift: -1.0 / 24.0, dryer_exhaust_min_runtime: 0, args: args)
    create_timeseries_from_minutely(sch_name: 'clothes_dryer_exhaust', obj_name: Constants.ObjectNameClothesDryerExhaust, days_shift: -1.0 / 24.0, dryer_exhaust_min_runtime: 24, args: args)
  end

  def create_average_fixtures(args:)
    create_timeseries_from_minutely(sch_name: 'fixtures', obj_name: Constants.ObjectNameFixtures, days_shift: 0, dryer_exhaust_min_runtime: 0, args: args)
  end

  def create_average_ceiling_fan
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'ceiling_fan', weekday_sch: Schedule.CeilingFanWeekdayFractions, weekend_sch: Schedule.CeilingFanWeekendFractions, monthly_sch: '1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0')
  end

  def create_average_plug_loads_other
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'plug_loads_other', weekday_sch: Schedule.PlugLoadsOtherWeekdayFractions, weekend_sch: Schedule.PlugLoadsOtherWeekendFractions, monthly_sch: Schedule.PlugLoadsOtherMonthlyMultipliers)
  end

  def create_average_plug_loads_tv
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'plug_loads_tv', weekday_sch: Schedule.PlugLoadsTVWeekdayFractions, weekend_sch: Schedule.PlugLoadsTVWeekendFractions, monthly_sch: Schedule.PlugLoadsTVMonthlyMultipliers)
  end

  def create_average_plug_loads_vehicle
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'plug_loads_vehicle', weekday_sch: Schedule.PlugLoadsVehicleWeekdayFractions, weekend_sch: Schedule.PlugLoadsVehicleWeekendFractions, monthly_sch: Schedule.PlugLoadsVehicleMonthlyMultipliers)
  end

  def create_average_plug_loads_well_pump
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'plug_loads_well_pump', weekday_sch: Schedule.PlugLoadsWellPumpWeekdayFractions, weekend_sch: Schedule.PlugLoadsWellPumpWeekendFractions, monthly_sch: Schedule.PlugLoadsWellPumpMonthlyMultipliers)
  end

  def create_average_fuel_loads_grill
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'fuel_loads_grill', weekday_sch: Schedule.FuelLoadsGrillWeekdayFractions, weekend_sch: Schedule.FuelLoadsGrillWeekendFractions, monthly_sch: Schedule.FuelLoadsGrillMonthlyMultipliers)
  end

  def create_average_fuel_loads_lighting
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'fuel_loads_lighting', weekday_sch: Schedule.FuelLoadsLightingWeekdayFractions, weekend_sch: Schedule.FuelLoadsLightingWeekendFractions, monthly_sch: Schedule.FuelLoadsLightingMonthlyMultipliers)
  end

  def create_average_fuel_loads_fireplace
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'fuel_loads_fireplace', weekday_sch: Schedule.FuelLoadsFireplaceWeekdayFractions, weekend_sch: Schedule.FuelLoadsFireplaceWeekendFractions, monthly_sch: Schedule.FuelLoadsFireplaceMonthlyMultipliers)
  end

  def create_average_pool_pump
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'pool_pump', weekday_sch: Schedule.PoolPumpWeekdayFractions, weekend_sch: Schedule.PoolPumpWeekendFractions, monthly_sch: Schedule.PoolPumpMonthlyMultipliers)
  end

  def create_average_pool_heater
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'pool_heater', weekday_sch: Schedule.PoolPumpWeekdayFractions, weekend_sch: Schedule.PoolPumpWeekendFractions, monthly_sch: Schedule.PoolHeaterMonthlyMultipliers)
  end

  def create_average_hot_tub_pump
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'hot_tub_pump', weekday_sch: Schedule.HotTubPumpWeekdayFractions, weekend_sch: Schedule.HotTubPumpWeekendFractions, monthly_sch: Schedule.HotTubPumpMonthlyMultipliers)
  end

  def create_average_hot_tub_heater
    create_timeseries_from_weekday_weekend_monthly(sch_name: 'hot_tub_heater', weekday_sch: Schedule.HotTubHeaterWeekdayFractions, weekend_sch: Schedule.HotTubHeaterWeekendFractions, monthly_sch: Schedule.HotTubHeaterMonthlyMultipliers)
  end

  def create_timeseries_from_weekday_weekend_monthly(sch_name:,
                                                     weekday_sch:,
                                                     weekend_sch:,
                                                     monthly_sch:,
                                                     begin_month: nil,
                                                     begin_day_of_month: nil,
                                                     end_month: nil,
                                                     end_day_of_month: nil)

    daily_sch = { 'weekday_sch' => weekday_sch.split(',').map { |i| i.to_f },
                  'weekend_sch' => weekend_sch.split(',').map { |i| i.to_f },
                  'monthly_multiplier' => monthly_sch.split(',').map { |i| i.to_f } }

    if begin_month.nil? && begin_day_of_month.nil? && end_month.nil? && end_day_of_month.nil?
      begin_day = @sim_start_day
      end_day = DateTime.new(@sim_year, 12, 31)
    else
      begin_day = DateTime.new(@sim_year, begin_month, begin_day_of_month)
      end_day = DateTime.new(@sim_year, end_month, end_day_of_month)
    end

    @total_days_in_year.times do |day|
      today = @sim_start_day + day
      if begin_day <= end_day
        next if not (begin_day <= today && today <= end_day)
      else
        next if not (begin_day <= today || today <= end_day)
      end
      month = today.month
      day_of_week = today.wday
      [0, 6].include?(day_of_week) ? is_weekday = false : is_weekday = true
      @steps_in_day.times do |step|
        minute = day * 1440 + step * @minutes_per_step
        @schedules[sch_name][day * @steps_in_day + step] = get_value_from_daily_sch(daily_sch, month, is_weekday, minute, 1)
      end
    end
    @schedules[sch_name] = normalize(@schedules[sch_name])
  end

  def create_timeseries_from_months(sch_name:,
                                    month_schs:)

    num_days_in_months = Constants.NumDaysInMonths(@model.getYearDescription)
    sch = []
    for month in 0..11
      sch << month_schs[month] * num_days_in_months[month]
    end
    sch = sch.flatten
    m = sch.max
    sch = sch.map { |s| s / m }

    @total_days_in_year.times do |day|
      @steps_in_day.times do |step|
        minute = day * 1440 + step * @minutes_per_step
        @schedules[sch_name][day * @steps_in_day + step] = scale_lighting_by_occupancy(sch, minute, 1)
      end
    end
    @schedules[sch_name] = normalize(@schedules[sch_name])
  end

  def create_timeseries_from_minutely(sch_name:,
                                      obj_name:,
                                      days_shift:,
                                      dryer_exhaust_min_runtime:,
                                      args:)

    nbeds = args[:geometry_num_bedrooms]
    create_sch_object = false
    sch = HotWaterSchedule.new(@model, obj_name, nbeds, days_shift, dryer_exhaust_min_runtime, create_sch_object)

    weeks = 1 # use a single week that repeats

    year_description = @model.getYearDescription
    last_day_of_year = 365
    last_day_of_year += 1 if year_description.isLeapYear

    time = []
    (@minutes_per_step..24 * 60).step(@minutes_per_step).to_a.each_with_index do |m, i|
      time[i] = OpenStudio::Time.new(0, 0, m, 0)
    end

    data = sch.data

    unique_day_schedule = []
    for d in 1..7 * weeks # how many unique day schedules
      next if d > last_day_of_year

      time.each_with_index do |m, i|
        previous_value = data[i + (d - 1) * 24 * 60 / @minutes_per_step]
        unique_day_schedule << previous_value
      end
    end

    repeated_schedule = []
    for w in 0..52 # max num of weeks
      repeated_schedule += unique_day_schedule
    end

    @schedules[sch_name] = repeated_schedule[0...@total_days_in_year * @steps_in_day]
  end

  def create_stochastic_schedules(args:)
    # initialize a random number generator
    prng = Random.new(get_random_seed)

    # load the schedule configuration file
    schedule_config = JSON.parse(File.read(args[:resources_path] + '/schedules_config.json'))

    # pre-load the probability distribution csv files for speed
    cluster_size_prob_map = read_activity_cluster_size_probs(resources_path: args[:resources_path])
    event_duration_prob_map = read_event_duration_probs(resources_path: args[:resources_path])
    activity_duration_prob_map = read_activity_duration_prob(resources_path: args[:resources_path])
    appliance_power_dist_map = read_appliance_power_dist(resources_path: args[:resources_path])
    weekday_monthly_shift_dict = read_monthly_shift_minutes(resources_path: args[:resources_path], daytype: 'weekday')
    weekend_monthly_shift_dict = read_monthly_shift_minutes(resources_path: args[:resources_path], daytype: 'weekend')

    all_simulated_values = [] # holds the markov-chain state for each of the seven simulated states for each occupant.
    # States are: 'sleeping', 'shower', 'laundry', 'cooking', 'dishwashing', 'absent', 'nothingAtHome'
    # if geometry_num_occupants = 2, period_in_a_year = 35040,  num_of_states = 7, then
    # shape of all_simulated_values is [2, 35040, 7]
    (1..args[:geometry_num_occupants]).each do |i|
      occ_type_id = weighted_random(prng, schedule_config['occupancy_types']['probabilities'])
      init_prob_file_weekday = args[:resources_path] + "/schedules_weekday_mkv_chain_initial_prob_cluster_#{occ_type_id}.csv"
      initial_prob_weekday = CSV.read(init_prob_file_weekday)
      initial_prob_weekday = initial_prob_weekday.map { |x| x[0].to_f }
      init_prob_file_weekend = args[:resources_path] + "/schedules_weekend_mkv_chain_initial_prob_cluster_#{occ_type_id}.csv"
      initial_prob_weekend = CSV.read(init_prob_file_weekend)
      initial_prob_weekend = initial_prob_weekend.map { |x| x[0].to_f }

      transition_matrix_file_weekday = args[:resources_path] + "/schedules_weekday_mkv_chain_transition_prob_cluster_#{occ_type_id}.csv"
      transition_matrix_weekday = CSV.read(transition_matrix_file_weekday)
      transition_matrix_weekday = transition_matrix_weekday.map { |x| x.map { |y| y.to_f } }
      transition_matrix_file_weekend = args[:resources_path] + "/schedules_weekend_mkv_chain_transition_prob_cluster_#{occ_type_id}.csv"
      transition_matrix_weekend = CSV.read(transition_matrix_file_weekend)
      transition_matrix_weekend = transition_matrix_weekend.map { |x| x.map { |y| y.to_f } }

      simulated_values = []
      @total_days_in_year.times do |day|
        today = @sim_start_day + day
        day_of_week = today.wday
        if [0, 6].include?(day_of_week)
          # Weekend
          day_type = 'weekend'
          initial_prob = initial_prob_weekend
          transition_matrix = transition_matrix_weekend
        else
          # weekday
          day_type = 'weekday'
          initial_prob = initial_prob_weekday
          transition_matrix = transition_matrix_weekday
        end
        j = 0
        state_prob = initial_prob # [] shape = 1x7. probability of transitioning to each of the 7 states
        while j < @mkc_ts_per_day do
          active_state = weighted_random(prng, state_prob) # Randomly pick the next state
          state_vector = [0] * 7 # there are 7 states
          state_vector[active_state] = 1 # Transition to the new state
          # sample the duration of the state, and skip markov-chain based state transition until the end of the duration
          activity_duration = sample_activity_duration(prng, activity_duration_prob_map, occ_type_id, active_state, day_type, j / 4)
          activity_duration.times do |repeat_activity_count|
            # repeat the same activity for the duration times
            simulated_values << state_vector
            j += 1
            if j >= @mkc_ts_per_day then break end # break as soon as we have filled acitivities for the day
          end
          if j >= @mkc_ts_per_day then break end # break as soon as we have filled activities for the day

          transition_probs = transition_matrix[(j - 1) * 7...j * 7] # obtain the transition matrix for current timestep
          state_prob = transition_probs[active_state]
        end
      end
      # Markov-chain transition probabilities is based on ATUS data, and the starting time of day for the data is
      # 4 am. We need to shift everything forward by 16 timesteps to make it midnight-based.
      simulated_values = simulated_values.rotate(-4 * 4) # 4am shifting (4 hours  = 4 * 4 steps of 15 min intervals)
      all_simulated_values << Matrix[*simulated_values]
    end
    # shape of all_simulated_values is [2, 35040, 7] i.e. (geometry_num_occupants, period_in_a_year, number_of_states)
    plugload_sch = schedule_config['plugload']
    lighting_sch = schedule_config['lighting']
    ceiling_fan_sch = schedule_config['ceiling_fan']

    monthly_lighting_schedule = schedule_config['lighting']['monthly_multiplier']
    holiday_lighting_schedule = schedule_config['lighting']['holiday_sch']

    sch_option_type = Constants.OptionTypeLightingScheduleCalculated
    sch = Lighting.get_schedule(@model, @epw_file)
    interior_lighting_schedule = []
    year_description = @model.getYearDescription
    num_days_in_months = Constants.NumDaysInMonths(year_description.isLeapYear)
    for month in 0..11
      interior_lighting_schedule << sch[month] * num_days_in_months[month]
    end
    interior_lighting_schedule = interior_lighting_schedule.flatten
    m = interior_lighting_schedule.max
    interior_lighting_schedule = interior_lighting_schedule.map { |s| s / m }

    holiday_lighting_schedule = get_holiday_lighting_sch(@model, @runner, holiday_lighting_schedule)

    away_schedule = []
    idle_schedule = []

    # fill in the yearly time_step resolution schedule for plug/lighting and ceiling fan based on weekday/weekend sch
    # States are: 0='sleeping', 1='shower', 2='laundry', 3='cooking', 4='dishwashing', 5='absent', 6='nothingAtHome'
    @total_days_in_year.times do |day|
      today = @sim_start_day + day
      month = today.month
      day_of_week = today.wday
      [0, 6].include?(day_of_week) ? is_weekday = false : is_weekday = true
      @steps_in_day.times do |step|
        minute = day * 1440 + step * @minutes_per_step
        index_15 = (minute / 15).to_i
        sleep = sum_across_occupants(all_simulated_values, 0, index_15).to_f / args[:geometry_num_occupants]
        @schedules['sleep'][day * @steps_in_day + step] = sleep
        away_schedule << sum_across_occupants(all_simulated_values, 5, index_15).to_f / args[:geometry_num_occupants]
        idle_schedule << sum_across_occupants(all_simulated_values, 6, index_15).to_f / args[:geometry_num_occupants]
        active_occupancy_percentage = 1 - (away_schedule[-1] + sleep)
        @schedules['plug_loads_other'][day * @steps_in_day + step] = get_value_from_daily_sch(plugload_sch, month, is_weekday, minute, active_occupancy_percentage)
        @schedules['lighting_interior'][day * @steps_in_day + step] = scale_lighting_by_occupancy(interior_lighting_schedule, minute, active_occupancy_percentage)
        @schedules['lighting_exterior'][day * @steps_in_day + step] = get_value_from_daily_sch(lighting_sch, month, is_weekday, minute, 1)
        @schedules['lighting_garage'][day * @steps_in_day + step] = get_value_from_daily_sch(lighting_sch, month, is_weekday, minute, 1)
        @schedules['lighting_exterior_holiday'][day * @steps_in_day + step] = scale_lighting_by_occupancy(holiday_lighting_schedule, minute, 1)
        @schedules['ceiling_fan'][day * @steps_in_day + step] = get_value_from_daily_sch(ceiling_fan_sch, month, is_weekday, minute, active_occupancy_percentage)
      end
    end
    @schedules['plug_loads_other'] = normalize(@schedules['plug_loads_other'])
    @schedules['lighting_interior'] = normalize(@schedules['lighting_interior'])
    @schedules['lighting_exterior'] = normalize(@schedules['lighting_exterior'])
    @schedules['lighting_garage'] = normalize(@schedules['lighting_garage'])
    @schedules['lighting_exterior_holiday'] = normalize(@schedules['lighting_exterior_holiday'])
    @schedules['ceiling_fan'] = normalize(@schedules['ceiling_fan'])

    # Generate the Sink Schedule
    # 1. Find indexes (minutes) when at least one occupant can have sink event (they aren't sleeping or absent)
    # 2. Determine number of cluster per day
    # 3. Sample flow-rate for the sink
    # 4. For each cluster
    #   a. sample for number_of_events
    #   b. Re-normalize onset probability by removing invalid indexes (invalid = where we already have sink events)
    #   b. Probabilistically determine the start of the first event based on onset probability.
    #   c. For each event in number_of_events
    #      i. Sample the duration
    #      ii. Add the time occupied by event to invalid_index
    #      ii. if more events, offset by fixed wait time and goto c
    #   d. if more cluster, go to 4.
    mins_in_year = 1440 * @total_days_in_year
    mkc_steps_in_a_year = @total_days_in_year * @mkc_ts_per_day
    sink_activity_probable_mins = [0] * mkc_steps_in_a_year # 0 indicates sink activity cannot happen at that time
    sink_activity_sch = [0] * 1440 * @total_days_in_year
    # mark minutes when at least one occupant is doing nothing at home as possible sink activity time
    # States are: 0='sleeping', 1='shower', 2='laundry', 3='cooking', 4='dishwashing', 5='absent', 6='nothingAtHome'
    mkc_steps_in_a_year.times do |step|
      all_simulated_values.size.times do |i| # across occupants
        # if at least one occupant is not sleeping and not absent from home, then sink event can occur at that time
        if not ((all_simulated_values[i][step, 0] == 1) || (all_simulated_values[i][step, 5] == 1))
          sink_activity_probable_mins[step] = 1
        end
      end
    end

    sink_duration_probs = schedule_config['sink']['duration_probability']
    events_per_cluster_probs = schedule_config['sink']['events_per_cluster_probs']
    hourly_onset_prob = schedule_config['sink']['hourly_onset_prob']
    # Lookup avg_clusters_per_occ from json
    avg_sink_clusters_per_hh = schedule_config['sink']['avg_sink_clusters_per_hh']
    # Adjust avg_clusters_per_hh for number of occupants in household
    total_clusters = avg_sink_clusters_per_hh * (0.29 * args[:geometry_num_occupants] + 0.26) # Eq based on cluster scaling in Building America DHW Event Schedule Generator (fewer sink draw clusters for larger households)
    sink_minutes_between_event_gap = schedule_config['sink']['minutes_between_event_gap']
    cluster_per_day = (total_clusters / @total_days_in_year).to_i
    sink_flow_rate_mean = schedule_config['sink']['flow_rate_mean']
    sink_flow_rate_std = schedule_config['sink']['flow_rate_std']
    sink_flow_rate = gaussian_rand(prng, sink_flow_rate_mean, sink_flow_rate_std, 0.1)
    @total_days_in_year.times do |day|
      cluster_per_day.times do |cluster_count|
        todays_probable_steps = sink_activity_probable_mins[day * @mkc_ts_per_day...((day + 1) * @mkc_ts_per_day)]
        todays_probablities = todays_probable_steps.map.with_index { |p, i| p * hourly_onset_prob[i / @mkc_ts_per_hour] }
        prob_sum = todays_probablities.sum(0)
        normalized_probabilities = todays_probablities.map { |p| p * 1 / prob_sum }
        cluster_start_index = weighted_random(prng, normalized_probabilities)
        if sink_activity_probable_mins[cluster_start_index] != 0
          sink_activity_probable_mins[cluster_start_index] = 0 # mark the 15-min interval as unavailable for another sink event
        end
        num_events = weighted_random(prng, events_per_cluster_probs) + 1
        start_min = cluster_start_index * 15
        end_min = (cluster_start_index + 1) * 15
        num_events.times do |event_count|
          duration = weighted_random(prng, sink_duration_probs) + 1
          if start_min + duration > end_min then duration = (end_min - start_min) end
          sink_activity_sch.fill(sink_flow_rate, (day * 1440) + start_min, duration)
          start_min += duration + sink_minutes_between_event_gap # Two minutes gap between sink activity
          if start_min >= end_min then break end
        end
      end
    end

    # Generate minute level schedule for shower and bath
    # 1. Identify the shower time slots from the mkc schedule. This corresponds to personal hygiene time
    # For each slot:
    # 2. Determine if the personal hygiene is to be bath/shower using bath_to_shower_ratio probability
    # 3. Sample for the shower and bath flow rate. (These will remain same throughout the year for a given building)
    #    However, the duration of each shower/bath event can be different, so, in 15-minute aggregation, the shower/bath
    #    Water consumption might appear different between different events
    # 4. If it is shower
    #   a. Determine the number of events in the shower cluster (there can be multiple showers)
    #   b. For each event, sample the shower duration
    #   c. Fill in the time period of personal hygiene using that many events of corresponding duration
    #      separated by shower_minutes_between_event_gap.
    #      TODO If there is room in the mkc personal hygiene slot, shift uniform randomly
    # 5. If it is bath
    #   a. Sample the bath duration
    #   b. Fill in the mkc personal hygiene slot with the bath duration and flow rate.
    #      TODO If there is room in the mkc personal hygiene slot, shift uniform randomly
    # 6. Repeat process 2-6 for each occupant
    shower_minutes_between_event_gap = schedule_config['shower']['minutes_between_event_gap']
    shower_flow_rate_mean = schedule_config['shower']['flow_rate_mean']
    shower_flow_rate_std = schedule_config['shower']['flow_rate_std']
    bath_ratio = schedule_config['bath']['bath_to_shower_ratio']
    bath_duration_mean = schedule_config['bath']['duration_mean']
    bath_duration_std = schedule_config['bath']['duration_std']
    bath_flow_rate_mean = schedule_config['bath']['flow_rate_mean']
    bath_flow_rate_std = schedule_config['bath']['flow_rate_std']
    m = 0
    shower_activity_sch = [0] * mins_in_year
    bath_activity_sch = [0] * mins_in_year
    bath_flow_rate = gaussian_rand(prng, bath_flow_rate_mean, bath_flow_rate_std, 0.1)
    shower_flow_rate = gaussian_rand(prng, shower_flow_rate_mean, shower_flow_rate_std, 0.1)
    # States are: 'sleeping','shower','laundry','cooking', 'dishwashing', 'absent', 'nothingAtHome'
    step = 0
    while step < mkc_steps_in_a_year
      # shower_state will be equal to number of occupant taking shower/bath in the given 15-minute mkc interval
      shower_state = sum_across_occupants(all_simulated_values, 1, step)
      step_jump = 1
      if shower_state > 0
        shower_state.to_i.times do |occupant_number|
          r = prng.rand
          if r <= bath_ratio
            # fill in bath for this time
            duration = gaussian_rand(prng, bath_duration_mean, bath_duration_std, 0.1)
            int_duration = duration.ceil
            # since we are rounding duration to integer minute, we compensate by scaling flow rate
            flow_rate = bath_flow_rate * duration / int_duration
            start_min = step * 15
            m = 0
            int_duration.times do
              bath_activity_sch[start_min + m] += flow_rate
              m += 1
              if (start_min + m) >= mins_in_year then break end
            end
            step_jump = [step_jump, 1 + (m / 15)].max # jump additional step if the bath occupies multiple 15-min slots
          else
            # fill in the shower
            num_events = sample_activity_cluster_size(prng, cluster_size_prob_map, 'shower')
            start_min = step * 15
            m = 0
            num_events.times do
              duration = sample_event_duration(prng, event_duration_prob_map, 'shower')
              int_duration = duration.ceil
              flow_rate = shower_flow_rate * duration / int_duration
              # since we are rounding duration to integer minute, we compensate by scaling flow rate
              int_duration.times do
                shower_activity_sch[start_min + m] += flow_rate
                m += 1
                if (start_min + m) >= mins_in_year then break end
              end
              shower_minutes_between_event_gap.times do
                # skip the gap between events
                m += 1
                if (start_min + m) >= mins_in_year then break end
              end
              if start_min + m >= mins_in_year then break end
            end
            step_jump = [step_jump, 1 + (m / 15)].max
          end
        end
      end
      step += step_jump
    end

    # Generate minute level schedule for dishwasher and clothes washer
    # 1. Identify the dishwasher/clothes washer time slots from the mkc schedule.
    # 2. Sample for the flow_rate
    # 3. Determine the number of events in the dishwasher/clothes washer cluster
    #    (it's typically composed of multiple water draw events)
    # 4. For each event, sample the event duration
    # 5. Fill in the dishwasher/clothes washer time slot using those water draw events
    dw_flow_rate_mean = schedule_config['dishwasher']['flow_rate_mean']
    dw_flow_rate_std = schedule_config['dishwasher']['flow_rate_std']
    dw_minutes_between_event_gap = schedule_config['dishwasher']['minutes_between_event_gap']
    dw_activity_sch = [0] * mins_in_year
    m = 0
    dw_flow_rate = gaussian_rand(prng, dw_flow_rate_mean, dw_flow_rate_std, 0)

    # States are: 'sleeping','shower','laundry','cooking', 'dishwashing', 'absent', 'nothingAtHome'
    # Fill in dw_water draw schedule
    step = 0
    while step < mkc_steps_in_a_year
      dish_state = sum_across_occupants(all_simulated_values, 4, step, max_clip = 1)
      step_jump = 1
      if dish_state > 0
        cluster_size = sample_activity_cluster_size(prng, cluster_size_prob_map, 'dishwasher')
        start_minute = step * 15
        m = 0
        cluster_size.times do
          duration = sample_event_duration(prng, event_duration_prob_map, 'dishwasher')
          int_duration = duration.ceil
          flow_rate = dw_flow_rate * duration / int_duration
          int_duration.times do
            dw_activity_sch[start_minute + m] = flow_rate
            m += 1
            if start_minute + m >= mins_in_year then break end
          end
          if start_minute + m >= mins_in_year then break end

          dw_minutes_between_event_gap.times do
            m += 1
            if start_minute + m >= mins_in_year then break end
          end
          if start_minute + m >= mins_in_year then break end
        end
        step_jump = [step_jump, 1 + (m / 15)].max
      end
      step += step_jump
    end

    cw_flow_rate_mean = schedule_config['clothes_washer']['flow_rate_mean']
    cw_flow_rate_std = schedule_config['clothes_washer']['flow_rate_std']
    cw_minutes_between_event_gap = schedule_config['clothes_washer']['minutes_between_event_gap']
    cw_activity_sch = [0] * mins_in_year # this is the clothes_washer water draw schedule
    cw_load_size_probability = schedule_config['clothes_washer']['load_size_probability']
    m = 0
    cw_flow_rate = gaussian_rand(prng, cw_flow_rate_mean, cw_flow_rate_std, 0)
    # States are: 'sleeping','shower','laundry','cooking', 'dishwashing', 'absent', 'nothingAtHome'
    step = 0
    # Fill in clothes washer water draw schedule based on markov-chain state 2 (laundry)
    while step < mkc_steps_in_a_year
      clothes_state = sum_across_occupants(all_simulated_values, 2, step, max_clip = 1)
      step_jump = 1
      if clothes_state > 0
        num_loads = weighted_random(prng, cw_load_size_probability) + 1
        start_minute = step * 15
        m = 0
        num_loads.times do
          cluster_size = sample_activity_cluster_size(prng, cluster_size_prob_map, 'clothes_washer')
          cluster_size.times do
            duration = sample_event_duration(prng, event_duration_prob_map, 'clothes_washer')
            int_duration = duration.ceil
            flow_rate = cw_flow_rate * duration.to_f / int_duration
            int_duration.times do
              cw_activity_sch[start_minute + m] = flow_rate
              m += 1
              if start_minute + m >= mins_in_year then break end
            end
            if start_minute + m >= mins_in_year then break end

            cw_minutes_between_event_gap.times do
              # skip the gap between events
              m += 1
              if start_minute + m >= mins_in_year then break end
            end
            if start_minute + m >= mins_in_year then break end
          end
        end
        if start_minute + m >= mins_in_year then break end

        step_jump = [step_jump, 1 + (m / 15)].max
      end
      step += step_jump
    end

    # States are: 'sleeping', 'shower', 'laundry', 'cooking', 'dishwashing', 'absent', 'nothingAtHome'
    # Fill in dishwasher and clothes_washer power draw schedule based on markov-chain
    # This follows similar pattern as filling in water draw events, except we use different set of probability
    # distribution csv files for power level and duration of each event. And there is only one event per mkc slot.
    dw_power_sch = [0] * mins_in_year
    step = 0
    last_state = 0
    start_time = Time.new(@sim_year, 1, 1)
    while step < mkc_steps_in_a_year
      dish_state = sum_across_occupants(all_simulated_values, 4, step, max_clip = 1)
      step_jump = 1
      if (dish_state > 0) && (last_state == 0) # last_state == 0 prevents consecutive dishwasher power without gap
        duration_15min, avg_power = sample_appliance_duration_power(prng, appliance_power_dist_map, 'dishwasher')

        month = (start_time + step * 15 * 60).month
        duration_min = (duration_15min * 15 * schedule_config['dishwasher']['monthly_multiplier'][month - 1]).to_i

        duration = [duration_min, mins_in_year - step * 15].min
        dw_power_sch.fill(avg_power, step * 15, duration)
        step_jump = duration_15min
      end
      last_state = dish_state
      step += step_jump
    end

    # Fill in cw and clothes dryer power schedule
    # States are: 'sleeping', 'shower', 'laundry', 'cooking', 'dishwashing', 'absent', 'nothingAtHome'
    cw_power_sch = [0] * mins_in_year
    cd_power_sch = [0] * mins_in_year
    step = 0
    last_state = 0
    start_time = Time.new(@sim_year, 1, 1)
    while step < mkc_steps_in_a_year
      clothes_state = sum_across_occupants(all_simulated_values, 2, step, max_clip = 1)
      step_jump = 1
      if (clothes_state > 0) && (last_state == 0) # last_state == 0 prevents consecutive washer power without gap
        cw_duration_15min, cw_avg_power = sample_appliance_duration_power(prng, appliance_power_dist_map, 'clothes_washer')
        cd_duration_15min, cd_avg_power = sample_appliance_duration_power(prng, appliance_power_dist_map, 'clothes_dryer')

        month = (start_time + step * 15 * 60).month
        cd_duration_min = (cd_duration_15min * 15 * schedule_config['clothes_dryer']['monthly_multiplier'][month - 1]).to_i
        cw_duration_min = (cw_duration_15min * 15 * schedule_config['clothes_washer']['monthly_multiplier'][month - 1]).to_i

        cw_duration = [cw_duration_min, mins_in_year - step * 15].min
        cw_power_sch.fill(cw_avg_power, step * 15, cw_duration)
        cd_start_time = (step * 15 + cw_duration).to_i # clothes dryer starts immediately after washer ends\
        cd_duration = [cd_duration_min, mins_in_year - cd_start_time].min # cd_duration would be negative if cd_start_time > mins_in_year, and no filling would occur
        cd_power_sch = cd_power_sch.fill(cd_avg_power, cd_start_time, cd_duration)
        step_jump = cw_duration_15min + cd_duration_15min
      end
      last_state = clothes_state
      step += step_jump
    end

    # Fill in cooking power schedule
    # States are: 'sleeping','shower','laundry','cooking', 'dishwashing', 'absent', 'nothingAtHome'
    cooking_power_sch = [0] * mins_in_year
    step = 0
    last_state = 0
    start_time = Time.new(@sim_year, 1, 1)
    while step < mkc_steps_in_a_year
      cooking_state = sum_across_occupants(all_simulated_values, 3, step, max_clip = 1)
      step_jump = 1
      if (cooking_state > 0) && (last_state == 0) # last_state == 0 prevents consecutive cooking power without gap
        duration_15min, avg_power = sample_appliance_duration_power(prng, appliance_power_dist_map, 'cooking')
        month = (start_time + step * 15 * 60).month
        duration_min = (duration_15min * 15 * schedule_config['cooking']['monthly_multiplier'][month - 1]).to_i
        duration = [duration_min, mins_in_year - step * 15].min
        cooking_power_sch.fill(avg_power, step * 15, duration)
        step_jump = duration_15min
      end
      last_state = cooking_state
      step += step_jump
    end

    offset_range = 30
    random_offset = (prng.rand * 2 * offset_range).to_i - offset_range
    sink_activity_sch = sink_activity_sch.rotate(-4 * 60 + random_offset) # 4 am shifting
    sink_activity_sch = apply_monthly_offsets(array: sink_activity_sch, weekday_monthly_shift_dict: weekday_monthly_shift_dict, weekend_monthly_shift_dict: weekend_monthly_shift_dict)
    sink_activity_sch = aggregate_array(sink_activity_sch, @minutes_per_step)
    @schedules['sinks'] = sink_activity_sch.map { |flow| flow / Constants.PeakFlowRate }

    random_offset = (prng.rand * 2 * offset_range).to_i - offset_range
    dw_activity_sch = dw_activity_sch.rotate(random_offset)
    dw_activity_sch = apply_monthly_offsets(array: dw_activity_sch, weekday_monthly_shift_dict: weekday_monthly_shift_dict, weekend_monthly_shift_dict: weekend_monthly_shift_dict)
    dw_activity_sch = aggregate_array(dw_activity_sch, @minutes_per_step)
    @schedules['dishwasher'] = dw_activity_sch.map { |flow| flow / Constants.PeakFlowRate }

    random_offset = (prng.rand * 2 * offset_range).to_i - offset_range
    cw_activity_sch = cw_activity_sch.rotate(random_offset)
    cw_activity_sch = apply_monthly_offsets(array: cw_activity_sch, weekday_monthly_shift_dict: weekday_monthly_shift_dict, weekend_monthly_shift_dict: weekend_monthly_shift_dict)
    cw_activity_sch = aggregate_array(cw_activity_sch, @minutes_per_step)
    @schedules['clothes_washer'] = cw_activity_sch.map { |flow| flow / Constants.PeakFlowRate }

    random_offset = (prng.rand * 2 * offset_range).to_i - offset_range
    shower_activity_sch = shower_activity_sch.rotate(random_offset)
    shower_activity_sch = apply_monthly_offsets(array: shower_activity_sch, weekday_monthly_shift_dict: weekday_monthly_shift_dict, weekend_monthly_shift_dict: weekend_monthly_shift_dict)
    shower_activity_sch = aggregate_array(shower_activity_sch, @minutes_per_step)
    @schedules['showers'] = shower_activity_sch.map { |flow| flow / Constants.PeakFlowRate }

    random_offset = (prng.rand * 2 * offset_range).to_i - offset_range
    bath_activity_sch = bath_activity_sch.rotate(random_offset)
    bath_activity_sch = apply_monthly_offsets(array: bath_activity_sch, weekday_monthly_shift_dict: weekday_monthly_shift_dict, weekend_monthly_shift_dict: weekend_monthly_shift_dict)
    bath_activity_sch = aggregate_array(bath_activity_sch, @minutes_per_step)
    @schedules['baths'] = bath_activity_sch.map { |flow| flow / Constants.PeakFlowRate }

    random_offset = (prng.rand * 2 * offset_range).to_i - offset_range
    cooking_power_sch = cooking_power_sch.rotate(random_offset)
    cooking_power_sch = apply_monthly_offsets(array: cooking_power_sch, weekday_monthly_shift_dict: weekday_monthly_shift_dict, weekend_monthly_shift_dict: weekend_monthly_shift_dict)
    cooking_power_sch = aggregate_array(cooking_power_sch, @minutes_per_step)
    @schedules['cooking_range'] = cooking_power_sch.map { |power| power / Constants.PeakPower }

    random_offset = (prng.rand * 2 * offset_range).to_i - offset_range
    cw_power_sch = cw_power_sch.rotate(random_offset)
    cw_power_sch = apply_monthly_offsets(array: cw_power_sch, weekday_monthly_shift_dict: weekday_monthly_shift_dict, weekend_monthly_shift_dict: weekend_monthly_shift_dict)
    cw_power_sch = aggregate_array(cw_power_sch, @minutes_per_step)
    @schedules['clothes_washer_power'] = cw_power_sch.map { |power| power / Constants.PeakPower }

    random_offset = (prng.rand * 2 * offset_range).to_i - offset_range
    cd_power_sch = cd_power_sch.rotate(random_offset)
    cd_power_sch = apply_monthly_offsets(array: cd_power_sch, weekday_monthly_shift_dict: weekday_monthly_shift_dict, weekend_monthly_shift_dict: weekend_monthly_shift_dict)
    cd_power_sch = aggregate_array(cd_power_sch, @minutes_per_step)
    @schedules['clothes_dryer'] = cd_power_sch.map { |power| power / Constants.PeakPower }
    @schedules['clothes_dryer_exhaust'] = @schedules['clothes_dryer']

    random_offset = (prng.rand * 2 * offset_range).to_i - offset_range
    dw_power_sch = dw_power_sch.rotate(random_offset)
    dw_power_sch = apply_monthly_offsets(array: dw_power_sch, weekday_monthly_shift_dict: weekday_monthly_shift_dict, weekend_monthly_shift_dict: weekend_monthly_shift_dict)
    dw_power_sch = aggregate_array(dw_power_sch, @minutes_per_step)
    @schedules['dishwasher_power'] = dw_power_sch.map { |power| power / Constants.PeakPower }

    @schedules['occupants'] = away_schedule.map { |i| 1.0 - i }

    @schedules['fixtures'] = [@schedules['showers'], @schedules['sinks'], @schedules['baths']].transpose.map { |flow| flow.reduce(:+) }

    return true
  end

  def set_vacancy(args:)
    if args[:schedules_vacancy_begin_month].is_initialized && args[:schedules_vacancy_begin_day_of_month].is_initialized && args[:schedules_vacancy_end_month].is_initialized && args[:schedules_vacancy_end_day_of_month].is_initialized
      start_day_num = Schedule.get_day_num_from_month_day(@model, args[:schedules_vacancy_begin_month].get, args[:schedules_vacancy_begin_day_of_month].get)
      end_day_num = Schedule.get_day_num_from_month_day(@model, args[:schedules_vacancy_end_month].get, args[:schedules_vacancy_end_day_of_month].get)
      num_steps_per_day = @model.getSimulationControl.timestep.get.numberOfTimestepsPerHour * 24

      vacancy = Array.new(@schedules['vacancy'].length, 0)
      if end_day_num >= start_day_num
        vacancy.fill(1.0, (start_day_num - 1) * num_steps_per_day, (end_day_num - start_day_num + 1) * num_steps_per_day) # Fill between start/end days
      else # Wrap around year
        vacancy.fill(1.0, (start_day_num - 1) * num_steps_per_day) # Fill between start day and end of year
        vacancy.fill(1.0, 0, end_day_num * num_steps_per_day) # Fill between start of year and end day
      end
      @schedules['vacancy'] = vacancy
    else
      @runner.registerInfo('No vacancy period set.')
    end
    return true
  end

  def aggregate_array(array, group_size)
    new_array_size = array.size / group_size
    new_array = [0] * new_array_size
    new_array_size.times do |j|
      new_array[j] = array[(j * group_size)...(j + 1) * group_size].sum(0)
    end
    return new_array
  end

  def apply_monthly_offsets(array:, weekday_monthly_shift_dict:, weekend_monthly_shift_dict:)
    month_strs = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'July', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    new_array = []
    @total_days_in_year.times do |day|
      today = @sim_start_day + day
      day_of_week = today.wday
      month = month_strs[today.month - 1]
      if [0, 6].include?(day_of_week)
        # Weekend
        lead = weekend_monthly_shift_dict[month]
      else
        # weekday
        lead = weekday_monthly_shift_dict[month]
      end
      if lead.nil?
        raise "Could not find the entry for month #{month}, day #{day_of_week} and state #{@state}"
      end

      new_array.concat(array[day * 1440, 1440].rotate(lead))
    end
    return new_array
  end

  def read_monthly_shift_minutes(resources_path:, daytype:)
    shift_file = resources_path + "/schedules_#{daytype}_state_and_monthly_schedule_shift.csv"
    shifts = CSV.read(shift_file)
    state_index = shifts[0].find_index('State')
    lead_index = shifts[0].find_index('Lead')
    month_index = shifts[0].find_index('Month')
    state_shifts = shifts.select { |row| row[state_index] == @state }
    monthly_shifts_dict = Hash[state_shifts.map { |row| [row[month_index], row[lead_index].to_i] }]
    return monthly_shifts_dict
  end

  def read_appliance_power_dist(resources_path:)
    activity_names = ['clothes_washer', 'dishwasher', 'clothes_dryer', 'cooking']
    power_dist_map = {}
    activity_names.each do |activity|
      duration_file = resources_path + "/schedules_#{activity}_power_duration_dist.csv"
      consumption_file = resources_path + "/schedules_#{activity}_power_consumption_dist.csv"
      duration_vals = CSV.read(duration_file)
      consumption_vals = CSV.read(consumption_file)
      duration_vals = duration_vals.map { |a| a.map { |i| i.to_i } }
      consumption_vals = consumption_vals.map { |a| a[0].to_f }
      power_dist_map[activity] = [duration_vals, consumption_vals]
    end
    return power_dist_map
  end

  def sample_appliance_duration_power(prng, power_dist_map, appliance_name)
    # returns number number of 15-min interval the appliance runs, and the average 15-min power
    duration_vals, consumption_vals = power_dist_map[appliance_name]
    if @consumption_row.nil?
      # initialize and pick the consumption and duration row only the first time
      # checking only consumption_row is sufficient because duration_row always go side by side with consumption row
      @consumption_row = {}
      @duration_row = {}
    end
    if !@consumption_row.has_key?(appliance_name)
      @consumption_row[appliance_name] = (prng.rand * consumption_vals.size).to_i
      @duration_row[appliance_name] = (prng.rand * duration_vals.size).to_i
    end
    power = consumption_vals[@consumption_row[appliance_name]]
    sample = prng.rand(0..(duration_vals[@duration_row[appliance_name]].length - 1))
    duration = duration_vals[@duration_row[appliance_name]][sample]
    return [duration, power]
  end

  def read_activity_cluster_size_probs(resources_path:)
    activity_names = ['clothes_washer', 'dishwasher', 'shower']
    cluster_size_prob_map = {}
    activity_names.each do |activity|
      cluster_size_file = resources_path + "/schedules_#{activity}_cluster_size_probability.csv"
      cluster_size_probabilities = CSV.read(cluster_size_file)
      cluster_size_probabilities = cluster_size_probabilities.map { |entry| entry[0].to_f }
      cluster_size_prob_map[activity] = cluster_size_probabilities
    end
    return cluster_size_prob_map
  end

  def read_event_duration_probs(resources_path:)
    activity_names = ['clothes_washer', 'dishwasher', 'shower']
    event_duration_probabilites_map = {}
    activity_names.each do |activity|
      duration_file = resources_path + "/schedules_#{activity}_event_duration_probability.csv"
      duration_probabilities = CSV.read(duration_file)
      durations = duration_probabilities.map { |entry| entry[0].to_f / 60 } # convert to minute
      probabilities = duration_probabilities.map { |entry| entry[1].to_f }
      event_duration_probabilites_map[activity] = [durations, probabilities]
    end
    return event_duration_probabilites_map
  end

  def read_activity_duration_prob(resources_path:)
    cluster_types = ['0', '1', '2', '3']
    day_types = ['weekday', 'weekend']
    time_of_days = ['morning', 'midday', 'evening']
    activity_names = ['shower', 'cooking', 'dishwashing', 'laundry']
    activity_duration_prob_map = {}
    cluster_types.each do |cluster_type|
      day_types.each do |day_type|
        time_of_days.each do |time_of_day|
          activity_names.each do |activity_name|
            duration_file = resources_path + "/schedules_#{day_type}_duration_probability_cluster_#{cluster_type}_#{activity_name}_#{time_of_day}_duration_probability.csv"
            duration_probabilities = CSV.read(duration_file)
            durations = duration_probabilities.map { |entry| entry[0].to_i }
            probabilities = duration_probabilities.map { |entry| entry[1].to_f }
            activity_duration_prob_map["#{cluster_type}_#{activity_name}_#{day_type}_#{time_of_day}"] = [durations, probabilities]
          end
        end
      end
    end
    return activity_duration_prob_map
  end

  def sample_activity_cluster_size(prng, cluster_size_prob_map, activity_type_name)
    cluster_size_probabilities = cluster_size_prob_map[activity_type_name]
    return weighted_random(prng, cluster_size_probabilities) + 1
  end

  def sample_event_duration(prng, duration_probabilites_map, event_type)
    durations = duration_probabilites_map[event_type][0]
    probabilities = duration_probabilites_map[event_type][1]
    return durations[weighted_random(prng, probabilities)]
  end

  def sample_activity_duration(prng, activity_duration_prob_map, occ_type_id, activity, day_type, hour)
    # States are: 'sleeping', 'shower', 'laundry', 'cooking', 'dishwashing', 'absent', 'nothingAtHome'
    if hour < 8
      time_of_day = 'morning'
    elsif hour < 16
      time_of_day = 'midday'
    else
      time_of_day = 'evening'
    end

    if activity == 1
      activity_name = 'shower'
    elsif activity == 2
      activity_name = 'laundry'
    elsif activity == 3
      activity_name = 'cooking'
    elsif activity == 4
      activity_name = 'dishwashing'
    else
      return 1 # all other activity will span only one mkc step
    end
    durations = activity_duration_prob_map["#{occ_type_id}_#{activity_name}_#{day_type}_#{time_of_day}"][0]
    probabilities = activity_duration_prob_map["#{occ_type_id}_#{activity_name}_#{day_type}_#{time_of_day}"][1]
    return durations[weighted_random(prng, probabilities)]
  end

  def export(schedules_path:)
    CSV.open(schedules_path, 'w') do |csv|
      csv << @schedules.keys
      rows = @schedules.values.transpose
      rows.each do |row|
        csv << row.map { |x| '%.3g' % x }
      end
    end
    return true
  end

  def gaussian_rand(prng, mean, std, min = nil, max = nil)
    t = 2 * Math::PI * prng.rand
    r = Math.sqrt(-2 * Math.log(1 - prng.rand))
    scale = std * r
    x = mean + scale * Math.cos(t)
    if (not min.nil?) && (x < min) then x = min end
    if (not max.nil?) && (x > max) then x = max end
    # y = mean + scale * Math.sin(t)
    return x
  end

  def sum_across_occupants(all_simulated_values, activity_index, time_index, max_clip = nil)
    sum = 0
    all_simulated_values.size.times do |i|
      sum += all_simulated_values[i][time_index, activity_index]
    end
    if (not max_clip.nil?) && (sum > max_clip)
      sum = max_clip
    end
    return sum
  end

  def normalize(arr)
    m = arr.max
    arr = arr.map { |a| a / m }
    return arr
  end

  def scale_lighting_by_occupancy(sch, minute, active_occupant_percentage)
    day_start = minute / 1440
    day_sch = sch[day_start * 24, 24]
    current_val = sch[minute / 60]
    return day_sch.min + (current_val - day_sch.min) * active_occupant_percentage
  end

  def get_value_from_daily_sch(daily_sch, month, is_weekday, minute, active_occupant_percentage)
    is_weekday ? sch = daily_sch['weekday_sch'] : sch = daily_sch['weekend_sch']
    full_occupancy_current_val = sch[((minute % 1440) / 60).to_i].to_f * daily_sch['monthly_multiplier'][month - 1].to_f
    return sch.min + (full_occupancy_current_val - sch.min) * active_occupant_percentage
  end

  def weighted_random(prng, weights)
    n = prng.rand
    cum_weights = 0
    weights.each_with_index do |w, index|
      cum_weights += w
      if n <= cum_weights
        return index
      end
    end
    return weights.size - 1 # If the prob weight don't sum to n, return last index
  end

  def get_holiday_lighting_sch(model, runner, holiday_sch)
    holiday_start_day = 332 # November 27
    holiday_end_day = 6 # Jan 6
    sch = [0] * 24 * @total_days_in_year
    final_days = @total_days_in_year - holiday_start_day + 1
    beginning_days = holiday_end_day
    sch[0...holiday_end_day * 24] = holiday_sch * beginning_days
    sch[(holiday_start_day - 1) * 24..-1] = holiday_sch * final_days
    m = sch.max
    sch = sch.map { |s| s / m }
    return sch
  end
end
