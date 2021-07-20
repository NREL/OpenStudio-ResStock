# frozen_string_literal: true

class Lighting
  def self.apply(runner, model, epw_file, spaces, lighting_groups, lighting, eri_version, schedules_file)
    fractions = {}
    lighting_groups.each do |lg|
      fractions[[lg.location, lg.lighting_type]] = lg.fraction_of_units_in_location
    end

    if fractions[[HPXML::LocationInterior, HPXML::LightingTypeCFL]].nil? # Not the lighting group(s) we're interested in
      return
    end

    living_space = spaces[HPXML::LocationLivingSpace]
    garage_space = spaces[HPXML::LocationGarage]

    cfa = UnitConversions.convert(living_space.floorArea, 'm^2', 'ft^2')
    if not garage_space.nil?
      gfa = UnitConversions.convert(garage_space.floorArea, 'm^2', 'ft^2')
    else
      gfa = 0
    end

    int_kwh, ext_kwh, grg_kwh = calc_energy(eri_version, cfa, gfa,
                                            fractions[[HPXML::LocationInterior, HPXML::LightingTypeCFL]],
                                            fractions[[HPXML::LocationExterior, HPXML::LightingTypeCFL]],
                                            fractions[[HPXML::LocationGarage, HPXML::LightingTypeCFL]],
                                            fractions[[HPXML::LocationInterior, HPXML::LightingTypeLFL]],
                                            fractions[[HPXML::LocationExterior, HPXML::LightingTypeLFL]],
                                            fractions[[HPXML::LocationGarage, HPXML::LightingTypeLFL]],
                                            fractions[[HPXML::LocationInterior, HPXML::LightingTypeLED]],
                                            fractions[[HPXML::LocationExterior, HPXML::LightingTypeLED]],
                                            fractions[[HPXML::LocationGarage, HPXML::LightingTypeLED]],
                                            lighting.interior_usage_multiplier,
                                            lighting.garage_usage_multiplier,
                                            lighting.exterior_usage_multiplier)

    # Create schedule
    if not lighting.interior_weekday_fractions.nil?
      interior_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameInteriorLighting + ' schedule', lighting.interior_weekday_fractions, lighting.interior_weekend_fractions, lighting.interior_monthly_multipliers, Constants.ScheduleTypeLimitsFraction)
    else
      lighting_sch = get_schedule(model, epw_file)
      # Create schedule
      interior_sch = HourlyByMonthSchedule.new(model, 'lighting schedule', lighting_sch, lighting_sch, Constants.ScheduleTypeLimitsFraction)
    end
    exterior_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameExteriorLighting + ' schedule', lighting.exterior_weekday_fractions, lighting.exterior_weekend_fractions, lighting.exterior_monthly_multipliers, Constants.ScheduleTypeLimitsFraction)
    if not garage_space.nil?
      garage_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameGarageLighting + ' schedule', lighting.garage_weekday_fractions, lighting.garage_weekend_fractions, lighting.garage_monthly_multipliers, Constants.ScheduleTypeLimitsFraction)
    end
    if not lighting.holiday_kwh_per_day.nil?
      exterior_holiday_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameLightingExteriorHoliday + ' schedule', lighting.holiday_weekday_fractions, lighting.holiday_weekend_fractions, lighting.exterior_monthly_multipliers, Constants.ScheduleTypeLimitsFraction, true, lighting.holiday_period_begin_month, lighting.holiday_period_begin_day, lighting.holiday_period_end_month, lighting.holiday_period_end_day)
    end

    # Add lighting to each conditioned space
    if int_kwh > 0

      if not schedules_file.nil?
        design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: 'lighting_interior', annual_kwh: int_kwh)
        interior_sch = schedules_file.create_schedule_file(col_name: 'lighting_interior')
      else
        if lighting.interior_weekday_fractions.nil?
          design_level = interior_sch.calcDesignLevel(interior_sch.maxval * int_kwh)
        else
          design_level = interior_sch.calcDesignLevelFromDailykWh(int_kwh / 365.0)
        end
        interior_sch = interior_sch.schedule
      end

      # Add lighting
      ltg_def = OpenStudio::Model::LightsDefinition.new(model)
      ltg = OpenStudio::Model::Lights.new(ltg_def)
      ltg.setName(Constants.ObjectNameInteriorLighting)
      ltg.setSpace(living_space)
      ltg.setEndUseSubcategory(Constants.ObjectNameInteriorLighting)
      ltg_def.setName(Constants.ObjectNameInteriorLighting)
      ltg_def.setLightingLevel(design_level)
      ltg_def.setFractionRadiant(0.6)
      ltg_def.setFractionVisible(0.2)
      ltg_def.setReturnAirFraction(0.0)
      ltg.setSchedule(interior_sch)
    end

    # Add lighting to each garage space
    if grg_kwh > 0

      if not schedules_file.nil?
        design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: 'lighting_garage', annual_kwh: grg_kwh)
        garage_sch = schedules_file.create_schedule_file(col_name: 'lighting_garage')
      else
        design_level = garage_sch.calcDesignLevelFromDailykWh(grg_kwh / 365.0)
        garage_sch = garage_sch.schedule
      end

      # Add lighting
      ltg_def = OpenStudio::Model::LightsDefinition.new(model)
      ltg = OpenStudio::Model::Lights.new(ltg_def)
      ltg.setName(Constants.ObjectNameGarageLighting)
      ltg.setSpace(garage_space)
      ltg.setEndUseSubcategory(Constants.ObjectNameGarageLighting)
      ltg_def.setName(Constants.ObjectNameGarageLighting)
      ltg_def.setLightingLevel(design_level)
      ltg_def.setFractionRadiant(0.6)
      ltg_def.setFractionVisible(0.2)
      ltg_def.setReturnAirFraction(0.0)
      ltg.setSchedule(garage_sch)
    end

    if ext_kwh > 0

      if not schedules_file.nil?
        design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: 'lighting_exterior', annual_kwh: ext_kwh)
        exterior_sch = schedules_file.create_schedule_file(col_name: 'lighting_exterior')
      else
        design_level = exterior_sch.calcDesignLevelFromDailykWh(ext_kwh / 365.0)
        exterior_sch = exterior_sch.schedule
      end

      # Add exterior lighting
      ltg_def = OpenStudio::Model::ExteriorLightsDefinition.new(model)
      ltg = OpenStudio::Model::ExteriorLights.new(ltg_def)
      ltg.setName(Constants.ObjectNameExteriorLighting)
      ltg.setEndUseSubcategory(Constants.ObjectNameExteriorLighting)
      ltg_def.setName(Constants.ObjectNameExteriorLighting)
      ltg_def.setDesignLevel(design_level)
      ltg.setSchedule(exterior_sch)
    end

    if not lighting.holiday_kwh_per_day.nil?

      if not schedules_file.nil?
        design_level = schedules_file.calc_design_level_from_daily_kwh(col_name: 'lighting_exterior_holiday', daily_kwh: lighting.holiday_kwh_per_day)
        exterior_holiday_sch = schedules_file.create_schedule_file(col_name: 'lighting_exterior_holiday')
      else
        design_level = exterior_holiday_sch.calcDesignLevelFromDailykWh(lighting.holiday_kwh_per_day)
        exterior_holiday_sch = exterior_holiday_sch.schedule
      end

      # Add exterior holiday lighting
      ltg_def = OpenStudio::Model::ExteriorLightsDefinition.new(model)
      ltg = OpenStudio::Model::ExteriorLights.new(ltg_def)
      ltg.setName(Constants.ObjectNameLightingExteriorHoliday)
      ltg.setEndUseSubcategory(Constants.ObjectNameLightingExteriorHoliday)
      ltg_def.setName(Constants.ObjectNameLightingExteriorHoliday)
      ltg_def.setDesignLevel(design_level)
      ltg.setSchedule(exterior_holiday_sch)
    end
  end

  def self.get_default_fractions()
    ltg_fracs = {}
    [HPXML::LocationInterior, HPXML::LocationExterior, HPXML::LocationGarage].each do |location|
      [HPXML::LightingTypeCFL, HPXML::LightingTypeLFL, HPXML::LightingTypeLED].each do |lighting_type|
        if (location == HPXML::LocationInterior) && (lighting_type == HPXML::LightingTypeCFL)
          ltg_fracs[[location, lighting_type]] = 0.1
        else
          ltg_fracs[[location, lighting_type]] = 0
        end
      end
    end
    return ltg_fracs
  end

  private

  def self.calc_energy(eri_version, cfa, gfa, f_int_cfl, f_ext_cfl, f_grg_cfl, f_int_lfl, f_ext_lfl, f_grg_lfl,
                       f_int_led, f_ext_led, f_grg_led,
                       interior_usage_multiplier = 1.0, garage_usage_multiplier = 1.0, exterior_usage_multiplier = 1.0)

    if Constants.ERIVersions.index(eri_version) >= Constants.ERIVersions.index('2014ADEG')
      # Calculate fluorescent (CFL + LFL) fractions
      f_int_fl = f_int_cfl + f_int_lfl
      f_ext_fl = f_ext_cfl + f_ext_lfl
      f_grg_fl = f_grg_cfl + f_grg_lfl

      # Calculate incandescent fractions
      f_int_inc = 1.0 - f_int_fl - f_int_led
      f_ext_inc = 1.0 - f_ext_fl - f_ext_led
      f_grg_inc = 1.0 - f_grg_fl - f_grg_led

      # Efficacies (lm/W)
      eff_inc = 15.0
      eff_fl = 60.0
      eff_led = 90.0

      # Efficacy ratios
      eff_ratio_inc = eff_inc / eff_inc
      eff_ratio_fl = eff_inc / eff_fl
      eff_ratio_led = eff_inc / eff_led

      # Fractions of lamps that are hardwired vs plug-in
      frac_hw = 0.9
      frac_pl = 1.0 - frac_hw

      # Efficiency lighting adjustments
      int_adj = (f_int_inc * eff_ratio_inc) + (f_int_fl * eff_ratio_fl) + (f_int_led * eff_ratio_led)
      ext_adj = (f_ext_inc * eff_ratio_inc) + (f_ext_fl * eff_ratio_fl) + (f_ext_led * eff_ratio_led)
      grg_adj = (f_grg_inc * eff_ratio_inc) + (f_grg_fl * eff_ratio_fl) + (f_grg_led * eff_ratio_led)

      # Calculate energy use
      int_kwh = (0.9 / 0.925 * (455.0 + 0.8 * cfa) * int_adj) + (0.1 * (455.0 + 0.8 * cfa))
      ext_kwh = (100.0 + 0.05 * cfa) * ext_adj
      grg_kwh = 0.0
      if gfa > 0
        grg_kwh = 100.0 * grg_adj
      end
    else
      # Calculate efficient lighting fractions
      fF_int = f_int_cfl + f_int_lfl + f_int_led
      fF_ext = f_ext_cfl + f_ext_lfl + f_ext_led
      fF_grg = f_grg_cfl + f_grg_lfl + f_grg_led

      # Calculate energy use
      int_kwh = 0.8 * ((4.0 - 3.0 * fF_int) / 3.7) * (455.0 + 0.8 * cfa) + 0.2 * (455.0 + 0.8 * cfa)
      ext_kwh = (100.0 + 0.05 * cfa) * (1.0 - fF_ext) + 0.25 * (100.0 + 0.05 * cfa) * fF_ext
      grg_kwh = 0.0
      if gfa > 0
        grg_kwh = 100.0 * (1.0 - fF_grg) + 25.0 * fF_grg
      end
    end

    int_kwh *= interior_usage_multiplier
    ext_kwh *= exterior_usage_multiplier
    grg_kwh *= garage_usage_multiplier

    return int_kwh, ext_kwh, grg_kwh
  end

  def self.get_schedule(model, epw_file)
    # Sunrise and sunset hours
    sunrise_hour = []
    sunset_hour = []
    std_long = -epw_file.timeZone * 15
    normalized_hourly_lighting = [[1..24], [1..24], [1..24], [1..24], [1..24], [1..24], [1..24], [1..24], [1..24], [1..24], [1..24], [1..24]]
    for month in 0..11
      if epw_file.latitude < 51.49
        m_num = month + 1
        jul_day = m_num * 30 - 15
        if not ((m_num < 4) || (m_num > 10))
          offset = 1
        else
          offset = 0
        end
        declination = 23.45 * Math.sin(0.9863 * (284 + jul_day) * 0.01745329)
        deg_rad = Math::PI / 180
        rad_deg = 1 / deg_rad
        b = (jul_day - 1) * 0.9863
        equation_of_time = (0.01667 * (0.01719 + 0.42815 * Math.cos(deg_rad * b) - 7.35205 * Math.sin(deg_rad * b) - 3.34976 * Math.cos(deg_rad * (2 * b)) - 9.37199 * Math.sin(deg_rad * (2 * b))))
        sunset_hour_angle = rad_deg * Math.acos(-1 * Math.tan(deg_rad * epw_file.latitude) * Math.tan(deg_rad * declination))
        sunrise_hour[month] = offset + (12.0 - 1 * sunset_hour_angle / 15.0) - equation_of_time - (std_long + epw_file.longitude) / 15
        sunset_hour[month] = offset + (12.0 + 1 * sunset_hour_angle / 15.0) - equation_of_time - (std_long + epw_file.longitude) / 15
      else
        sunrise_hour = [8.125726064, 7.449258072, 6.388688653, 6.232405257, 5.27722936, 4.84705384, 5.127512162, 5.860163988, 6.684378904, 7.521267411, 7.390441945, 8.080667697]
        sunset_hour = [16.22214058, 17.08642353, 17.98324493, 19.83547864, 20.65149672, 21.20662992, 21.12124777, 20.37458274, 19.25834757, 18.08155615, 16.14359164, 15.75571306]
      end
    end

    dec_kws = [0.075, 0.055, 0.040, 0.035, 0.030, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.030, 0.045, 0.075, 0.130, 0.160, 0.140, 0.100, 0.075, 0.065, 0.060, 0.050, 0.045, 0.045, 0.045, 0.045, 0.045, 0.045, 0.050, 0.060, 0.080, 0.130, 0.190, 0.230, 0.250, 0.260, 0.260, 0.250, 0.240, 0.225, 0.225, 0.220, 0.210, 0.200, 0.180, 0.155, 0.125, 0.100]
    june_kws = [0.060, 0.040, 0.035, 0.025, 0.020, 0.020, 0.020, 0.020, 0.020, 0.020, 0.020, 0.020, 0.020, 0.025, 0.030, 0.030, 0.025, 0.020, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.020, 0.020, 0.020, 0.025, 0.025, 0.030, 0.030, 0.035, 0.045, 0.060, 0.085, 0.125, 0.145, 0.130, 0.105, 0.080]
    lighting_seasonal_multiplier =   [1.075, 1.064951905, 1.0375, 1.0, 0.9625, 0.935048095, 0.925, 0.935048095, 0.9625, 1.0, 1.0375, 1.064951905]
    amplConst1 = 0.929707907917098
    sunsetLag1 = 2.45016230615269
    stdDevCons1 = 1.58679810983444
    amplConst2 = 1.1372291802273
    sunsetLag2 = 20.1501965859073
    stdDevCons2 = 2.36567663279954

    monthly_kwh_per_day = []
    days_m = Schedule.get_num_days_per_month(nil) # Intentionally excluding leap year designation
    wtd_avg_monthly_kwh_per_day = 0
    for monthNum in 1..12
      month = monthNum - 1
      monthHalfHourKWHs = [0]
      for hourNum in 0..9
        monthHalfHourKWHs[hourNum] = june_kws[hourNum]
      end
      for hourNum in 9..17
        hour = (hourNum + 1.0) * 0.5
        monthHalfHourKWHs[hourNum] = (monthHalfHourKWHs[8] - (0.15 / (2 * Math::PI)) * Math.sin((2 * Math::PI) * (hour - 4.5) / 3.5) + (0.15 / 3.5) * (hour - 4.5)) * lighting_seasonal_multiplier[month]
      end
      for hourNum in 17..29
        hour = (hourNum + 1.0) * 0.5
        monthHalfHourKWHs[hourNum] = (monthHalfHourKWHs[16] - (-0.02 / (2 * Math::PI)) * Math.sin((2 * Math::PI) * (hour - 8.5) / 5.5) + (-0.02 / 5.5) * (hour - 8.5)) * lighting_seasonal_multiplier[month]
      end
      for hourNum in 29..45
        hour = (hourNum + 1.0) * 0.5
        monthHalfHourKWHs[hourNum] = (monthHalfHourKWHs[28] + amplConst1 * Math.exp((-1.0 * (hour - (sunset_hour[month] + sunsetLag1))**2) / (2.0 * ((25.5 / ((6.5 - monthNum).abs + 20.0)) * stdDevCons1)**2)) / ((25.5 / ((6.5 - monthNum).abs + 20.0)) * stdDevCons1 * (2.0 * Math::PI)**0.5))
      end
      for hourNum in 45..46
        hour = (hourNum + 1.0) * 0.5
        temp1 = (monthHalfHourKWHs[44] + amplConst1 * Math.exp((-1.0 * (hour - (sunset_hour[month] + sunsetLag1))**2) / (2.0 * ((25.5 / ((6.5 - monthNum).abs + 20.0)) * stdDevCons1)**2)) / ((25.5 / ((6.5 - monthNum).abs + 20.0)) * stdDevCons1 * (2.0 * Math::PI)**0.5))
        temp2 = (0.04 + amplConst2 * Math.exp((-1.0 * (hour - sunsetLag2)**2) / (2.0 * stdDevCons2**2)) / (stdDevCons2 * (2.0 * Math::PI)**0.5))
        if sunsetLag2 < sunset_hour[month] + sunsetLag1
          monthHalfHourKWHs[hourNum] = [temp1, temp2].min
        else
          monthHalfHourKWHs[hourNum] = [temp1, temp2].max
        end
      end
      for hourNum in 46..47
        hour = (hourNum + 1) * 0.5
        monthHalfHourKWHs[hourNum] = (0.04 + amplConst2 * Math.exp((-1.0 * (hour - sunsetLag2)**2) / (2.0 * stdDevCons2**2)) / (stdDevCons2 * (2.0 * Math::PI)**0.5))
      end

      sum_kWh = 0.0
      for timenum in 0..47
        sum_kWh += monthHalfHourKWHs[timenum]
      end
      for hour in 0..23
        ltg_hour = (monthHalfHourKWHs[hour * 2] + monthHalfHourKWHs[hour * 2 + 1]).to_f
        normalized_hourly_lighting[month][hour] = ltg_hour / sum_kWh
        monthly_kwh_per_day[month] = sum_kWh / 2.0
      end
      wtd_avg_monthly_kwh_per_day += monthly_kwh_per_day[month] * days_m[month] / 365.0
    end

    # Calculate normalized monthly lighting fractions
    seasonal_multiplier = []
    sumproduct_seasonal_multiplier = 0
    normalized_monthly_lighting = seasonal_multiplier
    for month in 0..11
      seasonal_multiplier[month] = (monthly_kwh_per_day[month] / wtd_avg_monthly_kwh_per_day)
      sumproduct_seasonal_multiplier += seasonal_multiplier[month] * days_m[month]
    end

    for month in 0..11
      normalized_monthly_lighting[month] = seasonal_multiplier[month] * days_m[month] / sumproduct_seasonal_multiplier
    end

    # Calculate schedule values
    lighting_sch = [[], [], [], [], [], [], [], [], [], [], [], []]
    for month in 0..11
      for hour in 0..23
        lighting_sch[month][hour] = normalized_monthly_lighting[month] * normalized_hourly_lighting[month][hour] / days_m[month]
      end
    end

    return lighting_sch
  end
end
