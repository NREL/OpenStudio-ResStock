# frozen_string_literal: true

# This file, which has 301 calculations, will eventually replace appliances.rb,
# which has Building America calculations.

require_relative 'constants'

class HotWaterAndAppliances
  def self.apply(model, unit, runner, weather,
                 cfa, nbeds, ncfl, has_uncond_bsmnt,
                 cw_mef, cw_ler, cw_elec_rate, cw_gas_rate,
                 cw_agc, cw_cap, cw_space, cd_fuel, cd_ef, cd_control,
                 cd_space, dw_ef, dw_cap, fridge_annual_kwh, fridge_space,
                 cook_fuel_type, cook_is_induction, oven_is_convection,
                 has_low_flow_fixtures, dist_type, pipe_r,
                 std_pipe_length, recirc_loop_length,
                 recirc_branch_length, recirc_control_type,
                 recirc_pump_power, dwhr_present,
                 dwhr_facilities_connected, dwhr_is_equal_flow,
                 dwhr_efficiency, dhw_loop_fracs, eri_version)

    # Get number of days in months/year
    year_description = model.getYearDescription
    assumed_year = year_description.assumedYear
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)

    # Table 4.6.1.1(1): Hourly Hot Water Draw Fraction for Hot Water Tests
    daily_fraction = [0.0085, 0.0085, 0.0085, 0.0085, 0.0085, 0.0100, 0.0750, 0.0750,
                      0.0650, 0.0650, 0.0650, 0.0460, 0.0460, 0.0370, 0.0370, 0.0370,
                      0.0370, 0.0630, 0.0630, 0.0630, 0.0630, 0.0510, 0.0510, 0.0085]
    norm_daily_fraction = []
    daily_fraction.each do |frac|
      norm_daily_fraction << (frac / daily_fraction.max)
    end

    # Schedules init
    timestep_minutes = (60.0 / model.getTimestep.numberOfTimestepsPerHour).to_i
    start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(1), 1, assumed_year)
    timestep_interval = OpenStudio::Time.new(0, 0, timestep_minutes)
    timestep_day = OpenStudio::Time.new(0, 0, 60 * 24)
    temp_sch_limits = model.getScheduleTypeLimitsByName('Temperature')

    if not dist_type.nil?

      water_use_connections = {}
      setpoint_scheds = {}
      setpoint_temps = {}

      dhw_loop_fracs.each do |dhw_loop, dhw_load_frac|
        water_use_connections[dhw_loop] = OpenStudio::Model::WaterUseConnections.new(model)
        dhw_loop.addDemandBranchForComponent(water_use_connections[dhw_loop])

        # Get water heater setpoint schedule
        setpoint_scheds[dhw_loop] = Waterheater.get_water_heater_setpoint_schedule(model, dhw_loop, runner)
        if setpoint_scheds[dhw_loop].nil?
          return false
        end

        setpoint_temps[dhw_loop] = Waterheater.get_water_heater_setpoint(model, dhw_loop, runner)
        if setpoint_temps[dhw_loop].nil?
          return false
        end
      end

      if setpoint_temps.values.max - setpoint_temps.values.min > 0.1
        runner.registerError('Cannot handle different water heater setpoints.')
        return false
      end
      setpoint_temp = setpoint_temps.values.reduce(:+) / setpoint_temps.size.to_f # average

      # Create hot water draw profile schedule
      fractions_hw = []
      for day in 0..(num_days_in_year - 1)
        for hr in 0..23
          for timestep in 1..(60.0 / timestep_minutes)
            fractions_hw << norm_daily_fraction[hr]
          end
        end
      end
      sum_fractions_hw = fractions_hw.reduce(:+).to_f
      time_series_hw = OpenStudio::TimeSeries.new(start_date, timestep_interval, OpenStudio::createVector(fractions_hw), '')
      schedule_hw = OpenStudio::Model::ScheduleInterval.fromTimeSeries(time_series_hw, model).get
      schedule_hw.setName('Hot Water Draw Profile')
      Schedule.set_schedule_type_limits(model, schedule_hw, Constants.ScheduleTypeLimitsFraction)

      # Create mixed water draw profile schedule
      dwhr_eff_adj, dwhr_iFrac, dwhr_plc, dwhr_locF, dwhr_fixF = get_dwhr_factors(nbeds, dist_type, std_pipe_length, recirc_branch_length, dwhr_is_equal_flow, dwhr_facilities_connected, has_low_flow_fixtures)
      daily_wh_inlet_temperatures = calc_water_heater_daily_inlet_temperatures(weather, dwhr_present, dwhr_iFrac, dwhr_efficiency, dwhr_eff_adj, dwhr_plc, dwhr_locF, dwhr_fixF)
      daily_mw_fractions = calc_mixed_water_daily_fractions(daily_wh_inlet_temperatures, setpoint_temp)
      fractions_mw = []
      for day in 0..(num_days_in_year - 1)
        for hr in 0..23
          for timestep in 1..(60.0 / timestep_minutes)
            fractions_mw << norm_daily_fraction[hr] * daily_mw_fractions[day]
          end
        end
      end
      time_series_mw = OpenStudio::TimeSeries.new(start_date, timestep_interval, OpenStudio::createVector(fractions_mw), '')
      schedule_mw = OpenStudio::Model::ScheduleInterval.fromTimeSeries(time_series_mw, model).get
      schedule_mw.setName('Mixed Water Draw Profile')
      Schedule.set_schedule_type_limits(model, schedule_mw, Constants.ScheduleTypeLimitsFraction)

      # Replace mains water temperature schedule with water heater inlet temperature schedule.
      # These are identical unless there is a DWHR.
      daily_wh_inlet_temperatures_c = daily_wh_inlet_temperatures.map { |t| UnitConversions.convert(t, 'F', 'C') }
      time_series_tmains = OpenStudio::TimeSeries.new(start_date, timestep_day, OpenStudio::createVector(daily_wh_inlet_temperatures_c), '')
      schedule_tmains = OpenStudio::Model::ScheduleInterval.fromTimeSeries(time_series_tmains, model).get
      model.getSiteWaterMainsTemperature.setTemperatureSchedule(schedule_tmains)
    end

    location_hierarchy = [Constants.SpaceTypeLiving,
                          Constants.SpaceTypeFinishedBasement]

    # Clothes washer
    if (not dist_type.nil?) && (not cw_mef.nil?)
      cw_annual_kwh, cw_frac_sens, cw_frac_lat, cw_gpd = calc_clothes_washer_energy_gpd(eri_version, nbeds, cw_ler, cw_elec_rate, cw_gas_rate, cw_agc, cw_cap)
      cw_name = Constants.ObjectNameClothesWasher(unit.name.to_s)
      cw_peak_flow_gpm = cw_gpd / sum_fractions_hw / timestep_minutes * num_days_in_year
      cw_design_level_w = UnitConversions.convert(cw_annual_kwh * 60.0 / (cw_gpd * num_days_in_year / cw_peak_flow_gpm), 'kW', 'W')
      add_electric_equipment(model, cw_name, cw_space, cw_design_level_w, cw_frac_sens, cw_frac_lat, schedule_hw)
      dhw_loop_fracs.each do |dhw_loop, dhw_load_frac|
        add_water_use_equipment(model, cw_name, cw_peak_flow_gpm * dhw_load_frac, schedule_hw, setpoint_scheds[dhw_loop], water_use_connections[dhw_loop])
      end
    end

    # Clothes dryer
    if (not cw_mef.nil?) && (not cd_ef.nil?)
      cd_annual_kwh, cd_annual_therm, cd_frac_sens, cd_frac_lat = calc_clothes_dryer_energy(nbeds, cd_fuel, cd_ef, cd_control, cw_ler, cw_cap, cw_mef)
      cd_name = Constants.ObjectNameClothesDryer(cd_fuel, unit.name.to_s)
      cd_weekday_sch = '0.010, 0.006, 0.004, 0.002, 0.004, 0.006, 0.016, 0.032, 0.048, 0.068, 0.078, 0.081, 0.074, 0.067, 0.057, 0.061, 0.055, 0.054, 0.051, 0.051, 0.052, 0.054, 0.044, 0.024'
      cd_monthly_sch = '1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0'
      cd_schedule = MonthWeekdayWeekendSchedule.new(model, runner, cd_name, cd_weekday_sch, cd_weekday_sch, cd_monthly_sch, mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = true, create_sch_object = true, winter_design_day_sch = nil, summer_design_day_sch = nil, schedule_type_limits_name = Constants.ScheduleTypeLimitsFraction)
      cd_design_level_e = cd_schedule.calcDesignLevelFromDailykWh(cd_annual_kwh / num_days_in_year)
      cd_design_level_f = cd_schedule.calcDesignLevelFromDailyTherm(cd_annual_therm / num_days_in_year)
      add_electric_equipment(model, cd_name, cd_space, cd_design_level_e, cd_frac_sens, cd_frac_lat, cd_schedule.schedule)
      add_other_equipment(model, cd_name, cd_space, cd_design_level_f, cd_frac_sens, cd_frac_lat, cd_schedule.schedule, cd_fuel)
    end

    # Dishwasher
    if (not dist_type.nil?) && (not dw_ef.nil?)
      dw_annual_kwh, dw_frac_sens, dw_frac_lat, dw_gpd = calc_dishwasher_energy_gpd(eri_version, nbeds, dw_ef, dw_cap, num_days_in_year)
      dw_name = Constants.ObjectNameDishwasher(unit.name.to_s)
      dw_space = Geometry.get_space_from_location(unit, Constants.Auto, location_hierarchy)
      dw_peak_flow_gpm = dw_gpd / sum_fractions_hw / timestep_minutes * num_days_in_year
      dw_design_level_w = UnitConversions.convert(dw_annual_kwh * 60.0 / (dw_gpd * num_days_in_year / dw_peak_flow_gpm), 'kW', 'W')
      add_electric_equipment(model, dw_name, dw_space, dw_design_level_w, dw_frac_sens, dw_frac_lat, schedule_hw)
      dhw_loop_fracs.each do |dhw_loop, dhw_load_frac|
        add_water_use_equipment(model, dw_name, dw_peak_flow_gpm * dhw_load_frac, schedule_hw, setpoint_scheds[dhw_loop], water_use_connections[dhw_loop])
      end
    end

    # Refrigerator
    if not fridge_annual_kwh.nil?
      fridge_name = Constants.ObjectNameRefrigerator(unit.name.to_s)
      fridge_weekday_sch = '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
      fridge_monthly_sch = '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837'
      fridge_schedule = MonthWeekdayWeekendSchedule.new(model, runner, fridge_name, fridge_weekday_sch, fridge_weekday_sch, fridge_monthly_sch, mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = true, create_sch_object = true, winter_design_day_sch = nil, summer_design_day_sch = nil, schedule_type_limits_name = Constants.ScheduleTypeLimitsFraction)
      fridge_design_level = fridge_schedule.calcDesignLevelFromDailykWh(fridge_annual_kwh / num_days_in_year)
      add_electric_equipment(model, fridge_name, fridge_space, fridge_design_level, 1.0, 0.0, fridge_schedule.schedule)
    end

    # Cooking Range
    if not cook_fuel_type.nil?
      cook_annual_kwh, cook_annual_therm, cook_frac_sens, cook_frac_lat = calc_range_oven_energy(nbeds, cook_fuel_type, cook_is_induction, oven_is_convection, num_days_in_year)
      cook_name = Constants.ObjectNameCookingRange(cook_fuel_type, unit.name.to_s)
      cook_weekday_sch = '0.007, 0.007, 0.004, 0.004, 0.007, 0.011, 0.025, 0.042, 0.046, 0.048, 0.042, 0.050, 0.057, 0.046, 0.057, 0.044, 0.092, 0.150, 0.117, 0.060, 0.035, 0.025, 0.016, 0.011'
      cook_monthly_sch = '1.097, 1.097, 0.991, 0.987, 0.991, 0.890, 0.896, 0.896, 0.890, 1.085, 1.085, 1.097'
      cook_space = Geometry.get_space_from_location(unit, Constants.Auto, location_hierarchy)
      cook_schedule = MonthWeekdayWeekendSchedule.new(model, runner, cook_name, cook_weekday_sch, cook_weekday_sch, cook_monthly_sch, mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = true, create_sch_object = true, winter_design_day_sch = nil, summer_design_day_sch = nil, schedule_type_limits_name = Constants.ScheduleTypeLimitsFraction)
      cook_design_level_e = cook_schedule.calcDesignLevelFromDailykWh(cook_annual_kwh / num_days_in_year)
      cook_design_level_f = cook_schedule.calcDesignLevelFromDailyTherm(cook_annual_therm / num_days_in_year)
      add_electric_equipment(model, cook_name, cook_space, cook_design_level_e, cook_frac_sens, cook_frac_lat, cook_schedule.schedule)
      add_other_equipment(model, cook_name, cook_space, cook_design_level_f, cook_frac_sens, cook_frac_lat, cook_schedule.schedule, cook_fuel_type)
    end

    if not dist_type.nil?
      # Fixtures (showers, sinks, baths)
      fx_gpd = get_fixtures_gpd(eri_version, nbeds, has_low_flow_fixtures)
      fx_sens_btu, fx_lat_btu = get_fixtures_gains_sens_lat(nbeds, num_days_in_year)
      fx_obj_name = Constants.ObjectNameShower(unit.name.to_s)
      fx_obj_name_sens = "#{fx_obj_name} Sensible"
      fx_obj_name_lat = "#{fx_obj_name} Latent"
      fx_peak_flow_gpm = fx_gpd / sum_fractions_hw / timestep_minutes * num_days_in_year
      fx_space = Geometry.get_space_from_location(unit, Constants.Auto, location_hierarchy)
      fx_weekday_sch = '0.010, 0.006, 0.004, 0.002, 0.004, 0.006, 0.016, 0.032, 0.048, 0.068, 0.078, 0.081, 0.074, 0.067, 0.057, 0.061, 0.055, 0.054, 0.051, 0.051, 0.052, 0.054, 0.044, 0.024'
      fx_monthly_sch = '1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0'
      fx_schedule = MonthWeekdayWeekendSchedule.new(model, runner, fx_obj_name, fx_weekday_sch, fx_weekday_sch, fx_monthly_sch, mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = true, create_sch_object = true, winter_design_day_sch = nil, summer_design_day_sch = nil, lower_limit_value = 0, upper_limit_value = 1, numeric_type = 'Continuous')
      fx_design_level_sens = fx_schedule.calcDesignLevelFromDailykWh(UnitConversions.convert(fx_sens_btu, 'Btu', 'kWh') / num_days_in_year)
      fx_design_level_lat = fx_schedule.calcDesignLevelFromDailykWh(UnitConversions.convert(fx_lat_btu, 'Btu', 'kWh') / num_days_in_year)
      dhw_loop_fracs.each do |dhw_loop, dhw_load_frac|
        add_water_use_equipment(model, fx_obj_name, fx_peak_flow_gpm * dhw_load_frac, schedule_mw, setpoint_scheds[dhw_loop], water_use_connections[dhw_loop])
      end
      add_other_equipment(model, fx_obj_name_sens, fx_space, fx_design_level_sens, 1.0, 0.0, fx_schedule.schedule, nil)
      add_other_equipment(model, fx_obj_name_lat, fx_space, fx_design_level_lat, 0.0, 1.0, fx_schedule.schedule, nil)

      # Distribution losses
      dist_gpd = get_dist_waste_gpd(eri_version, nbeds, has_uncond_bsmnt, cfa, ncfl, dist_type, pipe_r, std_pipe_length, recirc_branch_length, has_low_flow_fixtures)
      dist_obj_name = Constants.ObjectNameHotWaterDistribution(unit.name.to_s)
      dist_peak_flow_gpm = dist_gpd / sum_fractions_hw / timestep_minutes * num_days_in_year
      dhw_loop_fracs.each do |dhw_loop, dhw_load_frac|
        add_water_use_equipment(model, dist_obj_name, dist_peak_flow_gpm * dhw_load_frac, schedule_mw, setpoint_scheds[dhw_loop], water_use_connections[dhw_loop])
      end

      # Recirculation pump
      dist_pump_annual_kwh = get_hwdist_recirc_pump_energy(dist_type, recirc_control_type, recirc_pump_power)
      dist_pump_obj_name = Constants.ObjectNameHotWaterRecircPump(unit.name.to_s)
      dist_pump_weekday_sch = '0.010, 0.006, 0.004, 0.002, 0.004, 0.006, 0.016, 0.032, 0.048, 0.068, 0.078, 0.081, 0.074, 0.067, 0.057, 0.061, 0.055, 0.054, 0.051, 0.051, 0.052, 0.054, 0.044, 0.024'
      dist_pump_monthly_sch = '1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0'
      dist_pump_schedule = MonthWeekdayWeekendSchedule.new(model, runner, dist_pump_obj_name, dist_pump_weekday_sch, dist_pump_weekday_sch, dist_pump_monthly_sch, mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = true, create_sch_object = true, winter_design_day_sch = nil, summer_design_day_sch = nil, schedule_type_limits_name = Constants.ScheduleTypeLimitsFraction)
      dist_pump_space = Geometry.get_space_from_location(unit, Constants.Auto, location_hierarchy)
      dist_pump_design_level = dist_pump_schedule.calcDesignLevelFromDailykWh(dist_pump_annual_kwh / num_days_in_year)
      dhw_loop_fracs.each do |dhw_loop, dhw_load_frac|
        dist_pump = add_electric_equipment(model, dist_pump_obj_name, dist_pump_space, dist_pump_design_level * dhw_load_frac, 0.0, 0.0, dist_pump_schedule.schedule)
        if not dist_pump.nil?
          dhw_loop.additionalProperties.setFeature('PlantLoopRecircPump', dist_pump.name.to_s)
        end
      end
    end

    return true
  end

  def self.get_range_oven_reference_is_induction()
    return false
  end

  def self.get_range_oven_reference_is_convection()
    return false
  end

  def self.calc_range_oven_energy(nbeds, fuel_type, is_induction, is_convection, num_days_in_year)
    if is_induction
      burner_ef = 0.91
    else
      burner_ef = 1.0
    end
    if is_convection
      oven_ef = 0.95
    else
      oven_ef = 1.0
    end
    if fuel_type != Constants.FuelTypeElectric
      annual_kwh = 22.6 + 2.7 * nbeds
      annual_therm = oven_ef * (22.6 + 2.7 * nbeds)
      tot_btu = UnitConversions.convert(annual_kwh, 'kWh', 'Btu') + UnitConversions.convert(annual_therm, 'therm', 'Btu')
      gains_sens = (4086.0 + 488.0 * nbeds) * num_days_in_year # Btu
      gains_lat = (1037.0 + 124.0 * nbeds) * num_days_in_year # Btu
      frac_sens = gains_sens / tot_btu
      frac_lat = gains_lat / tot_btu
    else
      annual_kwh = burner_ef * oven_ef * (331 + 39.0 * nbeds)
      annual_therm = 0.0
      tot_btu = UnitConversions.convert(annual_kwh, 'kWh', 'Btu') + UnitConversions.convert(annual_therm, 'therm', 'Btu')
      gains_sens = (2228.0 + 262.0 * nbeds) * num_days_in_year # Btu
      gains_lat = (248.0 + 29.0 * nbeds) * num_days_in_year # Btu
      frac_sens = gains_sens / tot_btu
      frac_lat = gains_lat / tot_btu
    end
    return annual_kwh, annual_therm, frac_sens, frac_lat
  end

  def self.get_dishwasher_reference_ef()
    return 0.46
  end

  def self.get_dishwasher_reference_cap()
    return 12.0 # number of place settings
  end

  def self.calc_dishwasher_energy_gpd(eri_version, nbeds, ef, cap, num_days_in_year)
    dwcpy = (88.4 + 34.9 * nbeds) * (12.0 / cap) # Eq 4.2-8a (dWcpy)
    annual_kwh = ((86.3 + 47.73 / ef) / 215.0) * dwcpy # Eq 4.2-8a
    tot_btu = UnitConversions.convert(annual_kwh, 'kWh', 'Btu')

    gains_sens = (219.0 + 87.0 * nbeds) * num_days_in_year # Btu
    gains_lat = (219.0 + 87.0 * nbeds) * num_days_in_year # Btu
    frac_sens = gains_sens / tot_btu
    frac_lat = gains_lat / tot_btu

    if eri_version.include? 'A'
      gpd = dwcpy * (4.6415 * (1.0 / ef) - 1.9295) / num_days_in_year # Eq. 4.2-11 (DWgpd)
    else
      gpd = 30.0 + 10.0 * nbeds # Table 4.2.2(1) Service water heating systems
      gpd += ((88.4 + 34.9 * nbeds) * 8.16 - (88.4 + 34.9 * nbeds) * 12.0 / cap * (4.6415 * (1.0 / ef) - 1.9295)) / num_days_in_year # Eq 4.2-8b
    end

    return annual_kwh, frac_sens, frac_lat, gpd
  end

  def self.calc_dishwasher_ef_from_annual_kwh(annual_kwh)
    return 215.0 / annual_kwh # 4.2.2.5.2.9. Dishwashers
  end

  def self.get_refrigerator_reference_annual_kwh(nbeds)
    annual_kwh = 637.0 + 18.0 * nbeds # kWh/yr
    return annual_kwh
  end

  def self.get_clothes_dryer_reference_ef(fuel_type)
    if fuel_type == Constants.FuelTypeElectric
      return 3.01 # lb/kWh
    else
      return 2.67 # lb/kWh
    end
  end

  def self.get_clothes_dryer_reference_control()
    return 'timer'
  end

  def self.calc_clothes_dryer_energy(nbeds, fuel_type, ef, control_type, cw_ler, cw_cap, cw_mef)
    # Eq 4.2-6 (FU)
    field_util_factor = nil
    if control_type == 'timer'
      field_util_factor = 1.18
    elsif control_type == 'moisture'
      field_util_factor = 1.04
    end
    if fuel_type == Constants.FuelTypeElectric
      annual_kwh = 12.5 * (164.0 + 46.5 * nbeds) * (field_util_factor / ef) * ((cw_cap / cw_mef) - cw_ler / 392.0) / (0.2184 * (cw_cap * 4.08 + 0.24)) # Eq 4.2-6
      annual_therm = 0.0
    else
      annual_kwh = 12.5 * (164.0 + 46.5 * nbeds) * (field_util_factor / 3.01) * ((cw_cap / cw_mef) - cw_ler / 392.0) / (0.2184 * (cw_cap * 4.08 + 0.24)) # Eq 4.2-6
      annual_therm = annual_kwh * 3412.0 * (1.0 - 0.07) * (3.01 / ef) / 100000 # Eq 4.2-7a
      annual_kwh = annual_kwh * 0.07 * (3.01 / ef)
    end
    tot_btu = UnitConversions.convert(annual_kwh, 'kWh', 'Btu') + UnitConversions.convert(annual_therm, 'therm', 'Btu')

    if fuel_type != Constants.FuelTypeElectric
      gains_sens = (738.0 + 209.0 * nbeds) * num_days_in_year # Btu
      gains_lat = (91.0 + 26.0 * nbeds) * num_days_in_year # Btu
    else
      gains_sens = (661.0 + 188.0 * nbeds) * num_days_in_year # Btu
      gains_lat = (73.0 + 21.0 * nbeds) * num_days_in_year # Btu
    end
    frac_sens = gains_sens / tot_btu
    frac_lat = gains_lat / tot_btu

    return annual_kwh, annual_therm, frac_sens, frac_lat
  end

  def self.calc_clothes_dryer_ef_from_cef(cef)
    return cef * 1.15 # Interpretation on ANSI/RESNET/ICC 301-2014 Clothes Dryer CEF
  end

  def self.get_clothes_washer_reference_mef()
    return 0.817
  end

  def self.get_clothes_washer_reference_ler()
    return 704.0 # kWh/yr
  end

  def self.get_clothes_washer_reference_elec_rate()
    return 0.08 # $/kWh
  end

  def self.get_clothes_washer_reference_gas_rate()
    return 0.58 # $/therm
  end

  def self.get_clothes_washer_reference_agc()
    return 23.0 # $
  end

  def self.get_clothes_washer_reference_cap()
    return 2.874 # ft^3
  end

  def self.calc_clothes_washer_energy_gpd(eri_version, nbeds, ler, elec_rate, gas_rate, agc, cap)
    # Eq 4.2-9a
    ncy = (3.0 / 2.847) * (164 + nbeds * 45.6)
    if eri_version.include? 'A'
      ncy = (3.0 / 2.847) * (164 + nbeds * 46.5)
    end
    acy = ncy * ((3.0 * 2.08 + 1.59) / (cap * 2.08 + 1.59)) # Adjusted Cycles per Year
    annual_kwh = ((ler / 392.0) - ((ler * elec_rate - agc) / (21.9825 * elec_rate - gas_rate) / 392.0) * 21.9825) * acy
    tot_btu = UnitConversions.convert(annual_kwh, 'kWh', 'Btu')

    gains_sens = (95.0 + 26.0 * nbeds) * num_days_in_year # Btu
    gains_lat = (11.0 + 3.0 * nbeds) * num_days_in_year # Btu
    frac_sens = gains_sens / tot_btu
    frac_lat = gains_lat / tot_btu

    gpd = 60.0 * ((ler * elec_rate - agc) / (21.9825 * elec_rate - gas_rate) / 392.0) * acy / num_days_in_year
    if not eri_version.include? 'A'
      gpd -= 3.97 # Section 4.2.2.5.2.10
    end

    return annual_kwh, frac_sens, frac_lat, gpd
  end

  def self.calc_clothes_washer_mef_from_imef(imef)
    return 0.503 + 0.95 * imef # Interpretation on ANSI/RESNET 301-2014 Clothes Washer IMEF
  end

  def self.get_dist_energy_consumption_adjustment(has_uncond_bsmnt, cfa, ncfl,
                                                  dist_type, recirc_control_type,
                                                  pipe_r, std_pipe_length, recirc_loop_length)
    # ANSI/RESNET 301-2014 Addendum A-2015
    # Amendment on Domestic Hot Water (DHW) Systems
    # Eq. 4.2-16
    ew_fact = get_dist_energy_waste_factor(dist_type, recirc_control_type, pipe_r)
    o_frac = 0.25 # fraction of hot water waste from standard operating conditions
    oew_fact = ew_fact * o_frac # standard operating condition portion of hot water energy waste
    ocd_eff = 0.0 # TODO: Need an HPXML input for this?
    sew_fact = ew_fact - oew_fact
    ref_pipe_l = get_default_std_pipe_length(has_uncond_bsmnt, cfa, ncfl)
    if dist_type == 'standard'
      pe_ratio = std_pipe_length / ref_pipe_l
    elsif dist_type == 'recirculation'
      ref_loop_l = get_default_recirc_loop_length(ref_pipe_l)
      pe_ratio = recirc_loop_length / ref_loop_l
    end
    e_waste = oew_fact * (1.0 - ocd_eff) + sew_fact * pe_ratio
    return (e_waste + 128.0) / 160.0
  end

  def self.get_default_std_pipe_length(has_uncond_bsmnt, cfa, ncfl)
    # ANSI/RESNET 301-2014 Addendum A-2015
    # Amendment on Domestic Hot Water (DHW) Systems
    bsmnt = has_uncond_bsmnt ? 1 : 0
    return 2.0 * (cfa / ncfl)**0.5 + 10.0 * ncfl + 5.0 * bsmnt # Eq. 4.2-13 (refPipeL)
  end

  def self.get_default_recirc_loop_length(std_pipe_length)
    # ANSI/RESNET 301-2014 Addendum A-2015
    # Amendment on Domestic Hot Water (DHW) Systems
    return 2.0 * std_pipe_length - 20.0 # Eq. 4.2-17 (refLoopL)
  end

  private

  def self.add_electric_equipment(model, obj_name, space, design_level_w, frac_sens, frac_lat, schedule)
    return if design_level_w == 0.0

    ee_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    ee = OpenStudio::Model::ElectricEquipment.new(ee_def)
    ee.setName(obj_name)
    ee.setEndUseSubcategory(obj_name)
    ee.setSpace(space)
    ee_def.setName(obj_name)
    ee_def.setDesignLevel(design_level_w)
    ee_def.setFractionRadiant(0.6 * frac_sens)
    ee_def.setFractionLatent(frac_lat)
    ee_def.setFractionLost(1.0 - frac_sens - frac_lat)
    ee.setSchedule(schedule)

    return ee
  end

  def self.add_other_equipment(model, obj_name, space, design_level_w, frac_sens, frac_lat, schedule, fuel_type)
    return if design_level_w == 0.0

    oe_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
    oe = OpenStudio::Model::OtherEquipment.new(oe_def)
    oe.setName(obj_name)
    oe.setEndUseSubcategory(obj_name)
    if fuel_type.nil?
      oe.setFuelType('None')
    else
      oe.setFuelType(HelperMethods.eplus_fuel_map(fuel_type))
    end
    oe.setSpace(space)
    oe_def.setName(obj_name)
    oe_def.setDesignLevel(design_level_w)
    oe_def.setFractionRadiant(0.6 * frac_sens)
    oe_def.setFractionLatent(frac_lat)
    oe_def.setFractionLost(1.0 - frac_sens - frac_lat)
    oe.setSchedule(schedule)

    return oe
  end

  def self.add_water_use_equipment(model, obj_name, peak_flow_gpm, schedule, temp_schedule, water_use_connection)
    return if peak_flow_gpm == 0.0

    wu_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
    wu = OpenStudio::Model::WaterUseEquipment.new(wu_def)
    wu.setName(obj_name)
    wu_def.setName(obj_name)
    wu_def.setPeakFlowRate(UnitConversions.convert(peak_flow_gpm, 'gal/min', 'm^3/s'))
    wu_def.setEndUseSubcategory(obj_name)
    wu.setFlowRateFractionSchedule(schedule)
    wu_def.setTargetTemperatureSchedule(temp_schedule)
    water_use_connection.addWaterUseEquipment(wu)

    return wu
  end

  def self.get_dwhr_factors(nbeds, dist_type, std_pipe_length, recirc_branch_length, is_equal_flow, facilities_connected, has_low_flow_fixtures)
    # ANSI/RESNET 301-2014 Addendum A-2015
    # Amendment on Domestic Hot Water (DHW) Systems
    # Eq. 4.2-14

    eff_adj = 1.0
    if has_low_flow_fixtures
      eff_adj = 1.082
    end

    iFrac = 0.56 + 0.015 * nbeds - 0.0004 * nbeds**2 # fraction of hot water use impacted by DWHR

    if dist_type == 'recirculation'
      pLength = recirc_branch_length
    elsif dist_type == 'standard'
      pLength = std_pipe_length
    end
    plc = 1 - 0.0002 * pLength # piping loss coefficient

    # Location factors for DWHR placement
    if is_equal_flow
      locF = 1.000
    else
      locF = 0.777
    end

    # Fixture Factor
    if facilities_connected == 'all'
      fixF = 1.0
    elsif facilities_connected == 'one'
      fixF = 0.5
    end

    return eff_adj, iFrac, plc, locF, fixF
  end

  def self.calc_water_heater_daily_inlet_temperatures(weather, dwhr_present = false, dwhr_iFrac = nil, dwhr_eff = nil,
                                                      dwhr_eff_adj = nil, dwhr_plc = nil, dwhr_locF = nil, dwhr_fixF = nil)

    # Get daily mains temperatures
    avgOAT = weather.data.AnnualAvgDrybulb
    maxDiffMonthlyAvgOAT = weather.data.MonthlyAvgDrybulbs.max - weather.data.MonthlyAvgDrybulbs.min
    tmains_daily = WeatherProcess.calc_mains_temperatures(avgOAT, maxDiffMonthlyAvgOAT, weather.header.Latitude)[2]

    wh_temps_daily = tmains_daily
    if dwhr_present
      # Adjust inlet temperatures
      dwhr_inT = 97.0 # F
      for day in 0..(num_days_in_year - 1)
        dwhr_WHinTadj = dwhr_iFrac * (dwhr_inT - tmains_daily[day]) * dwhr_eff * dwhr_eff_adj * dwhr_plc * dwhr_locF * dwhr_fixF
        wh_temps_daily[day] = (wh_temps_daily[day] + dwhr_WHinTadj).round(3)
      end
    else
      for day in 0..(num_days_in_year - 1)
        wh_temps_daily[day] = (wh_temps_daily[day]).round(3)
      end
    end

    return wh_temps_daily
  end

  def self.calc_mixed_water_daily_fractions(daily_wh_inlet_temperatures, tHot)
    tMix = 105.0 # F, Temperature of mixed water at fixtures
    adjFmix = []
    for day in 0..(num_days_in_year - 1)
      adjFmix << (1.0 - ((tHot - tMix) / (tHot - daily_wh_inlet_temperatures[day]))).round(4)
    end

    return adjFmix
  end

  def self.get_hwdist_recirc_pump_energy(dist_type, recirc_control_type, recirc_pump_power)
    # ANSI/RESNET 301-2014 Addendum A-2015
    # Amendment on Domestic Hot Water (DHW) Systems
    # Table 4.2.2.5.2.11(5) Annual electricity consumption factor for hot water recirculation system pumps
    if dist_type == 'recirculation'
      if (recirc_control_type == 'no control') || (recirc_control_type == 'timer')
        return 8.76 * recirc_pump_power
      elsif recirc_control_type == 'temperature'
        return 1.46 * recirc_pump_power
      elsif recirc_control_type == 'presence sensor demand control'
        return 0.15 * recirc_pump_power
      elsif recirc_control_type == 'manual demand control'
        return 0.10 * recirc_pump_power
      end
    elsif dist_type == 'standard'
      return 0.0
    end
    return
  end

  def self.get_fixtures_effectiveness(has_low_flow_fixtures)
    f_eff = has_low_flow_fixtures ? 0.95 : 1.0
    return f_eff
  end

  def self.get_fixtures_gpd(eri_version, nbeds, has_low_flow_fixtures)
    # ANSI/RESNET 301-2014 Addendum A-2015
    # Amendment on Domestic Hot Water (DHW) Systems

    if not eri_version.include? 'A'
      # Hot (not mixed) water GPD defined, so added to dishwasher instead.
      # Mixed water GPD here set to zero.
      return 0.0
    end

    ref_f_gpd = 14.6 + 10.0 * nbeds # Eq. 4.2-2 (refFgpd)
    f_eff = get_fixtures_effectiveness(has_low_flow_fixtures)
    return f_eff * ref_f_gpd
  end

  def self.get_fixtures_gains_sens_lat(nbeds, num_days_in_year)
    # Table 4.2.2(3). Internal Gains for Reference Homes
    sens_gains = -1227.0 - 409.0 * nbeds # Btu/day
    lat_gains = 1245.0 + 415.0 * nbeds # Btu/day
    return sens_gains * num_days_in_year, lat_gains * num_days_in_year
  end

  def self.get_dist_waste_gpd(eri_version, nbeds, has_uncond_bsmnt, cfa, ncfl,
                              dist_type, pipe_r, std_pipe_length,
                              recirc_branch_length, has_low_flow_fixtures)
    # ANSI/RESNET 301-2014 Addendum A-2015
    # Amendment on Domestic Hot Water (DHW) Systems
    # 4.2.2.5.2.11 Service Hot Water Use

    if not eri_version.include? 'A'
      # Hot (not mixed) water GPD defined, so added to dishwasher instead.
      # Mixed water GPD here set to zero.
      return 0.0
    end

    # Table 4.2.2.5.2.11(2) Hot Water Distribution System Insulation Factors
    sys_factor = nil
    if (dist_type == 'recirculation') && (pipe_r < 3.0)
      sys_factor = 1.11
    elsif (dist_type == 'recirculation') && (pipe_r >= 3.0)
      sys_factor = 1.0
    elsif (dist_type == 'standard') && (pipe_r >= 3.0)
      sys_factor = 0.90
    elsif (dist_type == 'standard') && (pipe_r < 3.0)
      sys_factor = 1.0
    end

    ref_w_gpd = 9.8 * (nbeds**0.43) # Eq. 4.2-2 (refWgpd)
    o_frac = 0.25
    o_cd_eff = 0.0

    if dist_type == 'recirculation'
      p_ratio = recirc_branch_length / 10.0
    elsif dist_type == 'standard'
      ref_pipe_l = get_default_std_pipe_length(has_uncond_bsmnt, cfa, ncfl)
      p_ratio = std_pipe_length / ref_pipe_l
    end

    o_w_gpd = ref_w_gpd * o_frac * (1.0 - o_cd_eff) # Eq. 4.2-12
    s_w_gpd = (ref_w_gpd - ref_w_gpd * o_frac) * p_ratio * sys_factor # Eq. 4.2-13

    # Table 4.2.2.5.2.11(3) Distribution system water use effectiveness
    if dist_type == 'recirculation'
      wd_eff = 0.1
    elsif dist_type == 'standard'
      wd_eff = 1.0
    end

    f_eff = get_fixtures_effectiveness(has_low_flow_fixtures)

    mw_gpd = f_eff * (o_w_gpd + s_w_gpd * wd_eff) # Eq. 4.2-11

    return mw_gpd
  end

  def self.get_dist_energy_waste_factor(dist_type, recirc_control_type, pipe_r)
    # ANSI/RESNET 301-2014 Addendum A-2015
    # Amendment on Domestic Hot Water (DHW) Systems
    # Table 4.2.2.5.2.11(6) Hot water distribution system relative annual energy waste factors
    if dist_type == 'recirculation'
      if (recirc_control_type == 'no control') || (recirc_control_type == 'timer')
        if pipe_r < 3.0
          return 500.0
        else
          return 250.0
        end
      elsif recirc_control_type == 'temperature'
        if pipe_r < 3.0
          return 375.0
        else
          return 187.5
        end
      elsif recirc_control_type == 'presence sensor demand control'
        if pipe_r < 3.0
          return 64.8
        else
          return 43.2
        end
      elsif recirc_control_type == 'manual demand control'
        if pipe_r < 3.0
          return 43.2
        else
          return 28.8
        end
      end
    elsif dist_type == 'standard'
      if pipe_r < 3.0
        return 32.0
      else
        return 28.8
      end
    end
    return
  end
end
