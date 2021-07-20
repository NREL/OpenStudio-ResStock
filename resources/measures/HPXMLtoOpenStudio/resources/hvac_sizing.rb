# frozen_string_literal: true

require_relative 'geometry'
require_relative 'hvac'
require_relative 'unit_conversions'
require_relative 'util'
require_relative 'schedules'
require_relative 'constructions'

class HVACSizing
  def self.apply(model, unit, runner, weather, show_debug_info)
    # Get year description of model
    @year_description = model.getYearDescription

    @northAxis = model.getBuilding.northAxis
    @minCoolingCapacity = 1 # Btu/hr

    # Based on EnergyPlus's model for calculating SHR at off-rated conditions. This curve fit
    # avoids the iterations in the actual model. It does not account for altitude or variations
    # in the SHRRated. It is a function of ODB (MJ design temp) and CFM/Ton (from MJ)
    @shr_biquadratic = [1.08464364, 0.002096954, 0, -0.005766327, 0, -0.000011147]

    @finished_heat_design_temp = 70 # Indoor heating design temperature according to acca MANUAL J
    @finished_cool_design_temp = 75 # Indoor heating design temperature according to acca MANUAL J
    @finished_dehum_design_temp = 75

    # Manual J: The default values for wind velocity are 15 mph for heating and 7.5 mph for cooling.
    # These velocities do not represent the most severe wind conditions that will be experienced when
    # the outdoor temperature is at the winter or summer design temperature, but they do represent
    # values that are compatible with normal weather patterns. If a location has a reputation for
    # wind velocities that consistently exceed these defaults during non-storm conditions, an
    # appropriate set of velocity values may be substituted for the default values
    @windspeed_heating = UnitConversions.convert(15.0, 'mph', 'm/s')
    @windspeed_cooling = UnitConversions.convert(7.5, 'mph', 'm/s')

    assumed_inside_temp = 73.5 # F
    @inside_air_dens = UnitConversions.convert(weather.header.LocalPressure, 'atm', 'Btu/ft^3') / (Gas.Air.r * (assumed_inside_temp + 460.0))

    mj8 = process_site_calcs_and_design_temps(runner, mj8, weather, model)
    return false if mj8.nil?

    # Get unit beds/baths
    nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
    if nbeds.nil? || nbaths.nil?
      return false
    end

    # Get finished floor area for unit
    unit_ffa = Geometry.get_finished_floor_area_from_spaces(unit.spaces)

    # Get shelter class
    unit_shelter_class = get_shelter_class(model, unit)

    # Get HVAC system info
    hvac = get_hvac_for_unit(runner, model, unit)
    return false if hvac.nil?

    ducts = get_ducts_for_unit(runner, model, unit, hvac, unit_ffa)
    return false if ducts.nil?

    # Calculate loads for each conditioned thermal zone in the unit
    zones_loads = process_zone_loads(runner, mj8, unit, weather, mj8.htd, nbeds, unit_ffa, unit_shelter_class)
    return false if zones_loads.nil?

    # Aggregate zone loads into initial unit loads
    unit_init = process_intermediate_total_loads(runner, mj8, zones_loads, weather, hvac)
    return false if unit_init.nil?

    # Process unit duct loads and equipment
    unit_init, unit_final = process_unit_loads_and_equipment(runner, mj8, unit, zones_loads, unit_init, weather, hvac, ducts, nbeds, unit_ffa, unit_shelter_class)
    return false if unit_final.nil? || unit_init.nil?

    # Display debug info
    if show_debug_info
      display_zone_loads(runner, unit, zones_loads)
      display_unit_initial_results(runner, unit, unit_init)
      display_unit_final_results(runner, unit, unit_final)
    end

    # Set object values
    if not setObjectValues(runner, model, unit, hvac, ducts, unit_final)
      return false
    end

    return true
  end

  private

  def self.process_site_calcs_and_design_temps(runner, mj8, weather, model)
    '''
    Site Calculations and Design Temperatures
    '''

    mj8 = MJ8.new

    # CLTD adjustments based on daily temperature range
    mj8.daily_range_temp_adjust = [4, 0, -5]

    # Manual J inside conditions
    mj8.cool_setpoint = 75
    mj8.heat_setpoint = 70

    mj8.cool_design_grains = UnitConversions.convert(weather.design.CoolingHumidityRatio, 'lbm/lbm', 'grains')
    mj8.dehum_design_grains = UnitConversions.convert(weather.design.DehumidHumidityRatio, 'lbm/lbm', 'grains')

    # # Calculate the design temperature differences
    mj8.ctd = weather.design.CoolingDrybulb - mj8.cool_setpoint
    mj8.htd = mj8.heat_setpoint - weather.design.HeatingDrybulb
    mj8.dtd = weather.design.DehumidDrybulb - mj8.cool_setpoint

    # # Calculate the average Daily Temperature Range (DTR) to determine the class (low, medium, high)
    dtr = weather.design.DailyTemperatureRange

    if dtr < 16
      mj8.daily_range_num = 0   # Low
    elsif dtr > 25
      mj8.daily_range_num = 2   # High
    else
      mj8.daily_range_num = 1   # Medium
    end

    # Altitude Correction Factors (ACF) taken from Table 10A (sea level - 12,000 ft)
    acfs = [1.0, 0.97, 0.93, 0.89, 0.87, 0.84, 0.80, 0.77, 0.75, 0.72, 0.69, 0.66, 0.63]

    # Calculate the altitude correction factor (ACF) for the site
    alt_cnt = (weather.header.Altitude / 1000.0).to_i
    mj8.acf = MathTools.interp2(weather.header.Altitude, alt_cnt * 1000, (alt_cnt + 1) * 1000, acfs[alt_cnt], acfs[alt_cnt + 1])

    # Calculate the interior humidity in Grains and enthalpy in Btu/lb for cooling
    pwsat = UnitConversions.convert(0.430075, 'psi', 'kPa') # Calculated for 75degF indoor temperature
    rh_indoor_cooling = 0.55 # Manual J is vague on the indoor RH. 55% corresponds to BA goals
    hr_indoor_cooling = (0.62198 * rh_indoor_cooling * pwsat) / (UnitConversions.convert(weather.header.LocalPressure, 'atm', 'kPa') - rh_indoor_cooling * pwsat)
    mj8.grains_indoor_cooling = UnitConversions.convert(hr_indoor_cooling, 'lbm/lbm', 'grains')
    mj8.wetbulb_indoor_cooling = Psychrometrics.Twb_fT_R_P(mj8.cool_setpoint, rh_indoor_cooling, UnitConversions.convert(weather.header.LocalPressure, 'atm', 'psi'))

    db_indoor_degC = UnitConversions.convert(mj8.cool_setpoint, 'F', 'C')
    mj8.enthalpy_indoor_cooling = (1.006 * db_indoor_degC + hr_indoor_cooling * (2501 + 1.86 * db_indoor_degC)) * UnitConversions.convert(1.0, 'kJ', 'Btu') * UnitConversions.convert(1.0, 'lbm', 'kg')

    # Calculate the interior humidity in Grains and enthalpy in Btu/lb for dehumidification
    mj8.RH_indoor_dehumid = 0.60
    hr_indoor_dehumid = (0.62198 * mj8.RH_indoor_dehumid * pwsat) / (UnitConversions.convert(weather.header.LocalPressure, 'atm', 'kPa') - mj8.RH_indoor_dehumid * pwsat)
    mj8.grains_indoor_dehumid = UnitConversions.convert(hr_indoor_dehumid, 'lbm/lbm', 'grains')
    mj8.wetbulb_indoor_dehumid = Psychrometrics.Twb_fT_R_P(mj8.cool_setpoint, mj8.RH_indoor_dehumid, UnitConversions.convert(weather.header.LocalPressure, 'atm', 'psi'))

    # Design Temperatures

    mj8.cool_design_temps = {}
    mj8.heat_design_temps = {}
    mj8.dehum_design_temps = {}

    # Arbitrary unit for retrieving unit features
    unit = nil
    model.getBuildingUnits.each do |u|
      next if u.spaces.size == 0

      unit = u
    end

    # Initialize Manual J buffer space temperatures using current design temperatures
    model.getSpaces.each do |space|
      mj8.cool_design_temps[space] = process_design_temp_cooling(runner, mj8, weather, space, unit)
      return nil if mj8.cool_design_temps[space].nil?

      mj8.heat_design_temps[space] = process_design_temp_heating(runner, mj8, weather, space, weather.design.HeatingDrybulb, unit)
      return nil if mj8.heat_design_temps[space].nil?

      mj8.dehum_design_temps[space] = process_design_temp_dehumid(runner, mj8, weather, space, unit)
      return nil if mj8.dehum_design_temps[space].nil?
    end

    return mj8
  end

  def self.process_design_temp_heating(runner, mj8, weather, space, design_db, unit)
    if Geometry.space_is_finished(space)
      # Living space, finished attic, finished basement
      heat_temp = @finished_heat_design_temp

    elsif Geometry.is_garage(space)
      # Garage
      heat_temp = design_db + 13

    elsif Geometry.is_unfinished_attic(space)

      is_vented = space_is_vented(space, 0.001)

      attic_floor_r = get_space_r_value(runner, space, 'floor', true)
      return if attic_floor_r.nil?

      attic_roof_r = get_space_r_value(runner, space, 'roofceiling', true)
      return if attic_roof_r.nil?

      # Unfinished attic
      if attic_floor_r < attic_roof_r

        # Attic is considered to be encapsulated. MJ8 says to use an attic
        # temperature of 95F, however alternative approaches are permissible

        if is_vented
          heat_temp = design_db
        else # not is_vented
          heat_temp = calculate_space_design_temps(runner, space, weather, unit, @finished_heat_design_temp, design_db, weather.data.GroundMonthlyTemps.min)
        end

      else

        heat_temp = design_db

      end

    elsif Geometry.is_pier_beam(space)
      # Pier & beam
      heat_temp = design_db

    else
      # Unfinished basement, Crawlspace
      heat_temp = calculate_space_design_temps(runner, space, weather, unit, @finished_heat_design_temp, design_db, weather.data.GroundMonthlyTemps.min)

    end

    return heat_temp
  end

  def self.process_design_temp_cooling(runner, mj8, weather, space, unit)
    if Geometry.space_is_finished(space)
      # Living space, finished attic, finished basement
      cool_temp = @finished_cool_design_temp

    elsif Geometry.is_garage(space)
      # Garage
      # Calculate the cooling design temperature for the garage

      # Calculate fraction of garage under finished space
      area_total = 0.0
      area_finished = 0.0
      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != 'roofceiling'

        area_total += surface.netArea
        next if not surface.adjacentSurface.is_initialized
        next if not surface.adjacentSurface.get.space.is_initialized
        next if not Geometry.space_is_finished(surface.adjacentSurface.get.space.get)

        area_finished += surface.netArea
      end
      garage_frac_under_finished = area_finished / area_total

      # Calculate the garage cooling design temperature based on Table 4C
      # Linearly interpolate between having living space over the garage and not having living space above the garage
      if mj8.daily_range_num == 0
        cool_temp = (weather.design.CoolingDrybulb +
                     (11 * garage_frac_under_finished) +
                     (22 * (1 - garage_frac_under_finished)))
      elsif mj8.daily_range_num == 1
        cool_temp = (weather.design.CoolingDrybulb +
                     (6 * garage_frac_under_finished) +
                     (17 * (1 - garage_frac_under_finished)))
      else
        cool_temp = (weather.design.CoolingDrybulb +
                     (1 * garage_frac_under_finished) +
                     (12 * (1 - garage_frac_under_finished)))
      end

    elsif Geometry.is_unfinished_attic(space)

      is_vented = space_is_vented(space, 0.001)

      attic_floor_r = get_space_r_value(runner, space, 'floor', true)
      return if attic_floor_r.nil?

      attic_roof_r = get_space_r_value(runner, space, 'roofceiling', true)
      return if attic_roof_r.nil?

      # Unfinished attic
      if attic_floor_r < attic_roof_r

        # Attic is considered to be encapsulated. MJ8 says to use an attic
        # temperature of 95F, however alternative approaches are permissible

        if is_vented
          cool_temp = weather.design.CoolingDrybulb + 40 # This is the number from a California study with dark shingle roof and similar ventilation.
        else # not is_vented
          cool_temp = calculate_space_design_temps(runner, space, weather, unit, @finished_cool_design_temp, weather.design.CoolingDrybulb, weather.data.GroundMonthlyTemps.max, true)
        end

      else

        # Calculate the cooling design temperature for the unfinished attic based on Figure A12-14
        # Use an area-weighted temperature in case roof surfaces are different
        tot_roof_area = 0
        cool_temp = 0

        space.surfaces.each do |surface|
          next if surface.surfaceType.downcase != 'roofceiling'

          tot_roof_area += surface.netArea

          roof_color = get_feature(runner, surface, Constants.SizingInfoRoofColor, 'string')
          roof_material = get_feature(runner, surface, Constants.SizingInfoRoofMaterial, 'string')
          return nil if roof_color.nil? || roof_material.nil?

          has_radiant_barrier = get_feature(runner, surface, Constants.SizingInfoRoofHasRadiantBarrier, 'boolean', false)
          has_radiant_barrier = false if has_radiant_barrier.nil?

          if not is_vented

            if not has_radiant_barrier
              cool_temp += (150 + (weather.design.CoolingDrybulb - 95) + mj8.daily_range_temp_adjust[mj8.daily_range_num]) * surface.netArea
            else
              cool_temp += (130 + (weather.design.CoolingDrybulb - 95) + mj8.daily_range_temp_adjust[mj8.daily_range_num]) * surface.netArea
            end
          else # is_vented

            if not has_radiant_barrier
              if [Constants.RoofMaterialAsphaltShingles, Constants.RoofMaterialTarGravel].include?(roof_material)
                if roof_color == Constants.ColorDark
                  cool_temp += 130 * surface.netArea
                else
                  cool_temp += 120 * surface.netArea
                end

              elsif [Constants.RoofMaterialWoodShakes].include?(roof_material)
                cool_temp += 120 * surface.netArea

              elsif [Constants.RoofMaterialMetal, Constants.RoofMaterialMembrane].include?(roof_material)
                if roof_color == Constants.ColorDark
                  cool_temp += 130 * surface.netArea
                elsif roof_color == Constants.ColorWhite
                  cool_temp += 95 * surface.netArea
                else
                  cool_temp += 120 * surface.netArea
                end

              elsif [Constants.RoofMaterialTile].include?(roof_material)
                if roof_color == Constants.ColorDark
                  cool_temp += 110 * surface.netArea
                elsif roof_color == Constants.ColorWhite
                  cool_temp += 95 * surface.netArea
                else
                  cool_temp += 105 * surface.netArea
                end

              else
                runner.registerWarning("Specified roofing material (#{roof_material}) is not supported by BEopt Manual J calculations. Assuming dark asphalt shingles")
                cool_temp += 130 * surface.netArea
              end
            else # with a radiant barrier
              if [Constants.RoofMaterialAsphaltShingles, Constants.RoofMaterialTarGravel].include?(roof_material)
                if roof_color == Constants.ColorDark
                  cool_temp += 120 * surface.netArea
                else
                  cool_temp += 110 * surface.netArea
                end

              elsif [Constants.RoofMaterialWoodShakes].include?(roof_material)
                cool_temp += 110 * surface.netArea

              elsif [Constants.RoofMaterialMetal, Constants.RoofMaterialMembrane].include?(roof_material)
                if roof_color == Constants.ColorDark
                  cool_temp += 120 * surface.netArea
                elsif roof_color == Constants.ColorWhite
                  cool_temp += 95 * surface.netArea
                else
                  cool_temp += 110 * surface.netArea
                end

              elsif [Constants.RoofMaterialTile].include?(roof_material)
                if roof_color == Constants.ColorDark
                  cool_temp += 105 * surface.netArea
                elsif roof_color == Constants.ColorWhite
                  cool_temp += 95 * surface.netArea
                else
                  cool_temp += 105 * surface.netArea
                end

              else
                runner.registerWarning("Specified roofing material (#{roof_material}) is not supported by BEopt Manual J calculations. Assuming dark asphalt shingles")
                cool_temp += 120 * surface.netArea

              end
            end
          end # vented/unvented
        end # each roof surface

        cool_temp /= tot_roof_area

        # Adjust base CLTD for cooling design temperature and daily range
        cool_temp += (weather.design.CoolingDrybulb - 95) + mj8.daily_range_temp_adjust[mj8.daily_range_num]

      end

    elsif Geometry.is_pier_beam(space)
      # Pier & beam
      cool_temp = weather.design.CoolingDrybulb

    else
      # Unfinished basement, Crawlspace
      cool_temp = calculate_space_design_temps(runner, space, weather, unit, @finished_cool_design_temp, weather.design.CoolingDrybulb, weather.data.GroundMonthlyTemps.max)
    end

    return cool_temp
  end

  def self.process_design_temp_dehumid(runner, mj8, weather, space, unit)
    if Geometry.space_is_finished(space)
      # Living space, finished attic, finished basement
      dehum_temp = @finished_dehum_design_temp

    elsif Geometry.is_garage(space)
      # Garage
      dehum_temp = weather.design.DehumidDrybulb + 7

    elsif Geometry.is_unfinished_attic(space)

      is_vented = space_is_vented(space, 0.001)

      attic_floor_r = get_space_r_value(runner, space, 'floor', true)
      return if attic_floor_r.nil?

      attic_roof_r = get_space_r_value(runner, space, 'roofceiling', true)
      return if attic_roof_r.nil?

      # Unfinished attic
      if attic_floor_r < attic_roof_r

        # Attic is considered to be encapsulated. MJ8 says to use an attic
        # temperature of 95F, however alternative approaches are permissible

        if is_vented
          dehum_temp = weather.design.DehumidDrybulb
        else # not is_vented
          dehum_temp = calculate_space_design_temps(runner, space, weather, unit, @finished_dehum_design_temp, weather.design.DehumidDrybulb, weather.data.GroundMonthlyTemps.min)
        end

      else

        dehum_temp = weather.design.DehumidDrybulb

      end

    elsif Geometry.is_pier_beam(space)
      # Pier & beam
      dehum_temp = weather.design.DehumidDrybulb

    else
      # Unfinished basement, Crawlspace
      dehum_temp = calculate_space_design_temps(runner, space, weather, unit, @finished_dehum_design_temp, weather.design.DehumidDrybulb, weather.data.GroundMonthlyTemps.min)

    end

    return dehum_temp
  end

  def self.process_zone_loads(runner, mj8, unit, weather, htd, nbeds, unit_ffa, unit_shelter_class)
    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    # Constant loads (no variation throughout day)
    zones_loads = {}
    thermal_zones.each do |thermal_zone|
      next if not Geometry.zone_is_finished(thermal_zone)

      zone_loads = ZoneValues.new
      zone_loads = process_load_windows_skylights(runner, mj8, thermal_zone, zone_loads, weather, htd)
      zone_loads = process_load_doors(runner, mj8, thermal_zone, zone_loads, weather, htd)
      zone_loads = process_load_walls(runner, mj8, unit, thermal_zone, zone_loads, weather, htd)
      zone_loads = process_load_roofs(runner, mj8, unit, thermal_zone, zone_loads, weather, htd)
      zone_loads = process_load_floors(runner, mj8, unit, thermal_zone, zone_loads, weather, htd)
      zone_loads = process_infiltration_ventilation(runner, mj8, unit, thermal_zone, zone_loads, weather, htd, unit_shelter_class)
      zone_loads = process_internal_gains(runner, mj8, thermal_zone, zone_loads, nbeds, unit_ffa)
      return nil if zone_loads.nil?

      zones_loads[thermal_zone] = zone_loads
    end

    return zones_loads
  end

  def self.process_load_windows_skylights(runner, mj8, thermal_zone, zone_loads, weather, htd)
    '''
    Heating, Cooling, and Dehumidification Loads: Windows & Skylights
    '''

    return if mj8.nil? || zone_loads.nil?

    # Average cooling load factors for windows/skylights WITHOUT internal shading for surface
    # azimuths of 0,22.5,45, ... ,337.5,360
    # Additional values (compared to values in MJ8 Table 3D-3) have been determined by
    # linear interpolation to avoid interpolating
    clf_avg_nois = [0.24, 0.295, 0.35, 0.365, 0.38, 0.39, 0.4, 0.44, 0.48, 0.44, 0.4, 0.39, 0.38, 0.365, 0.35, 0.295, 0.24]
    clf_avg_nois_horiz = 0.68

    # Average cooling load factors for windows/skylights WITH internal shading for surface
    # azimuths of 0,22.5,45, ... ,337.5,360
    # Additional values (compared to values in MJ8 Table 3D-3) have been determined
    # by linear interpolation to avoid interpolating in BMI
    clf_avg_is = [0.18, 0.235, 0.29, 0.305, 0.32, 0.32, 0.32, 0.305, 0.29, 0.305, 0.32, 0.32, 0.32, 0.305, 0.29, 0.235, 0.18]
    clf_avg_is_horiz = 0.52

    # Hourly cooling load factor (CLF) for windows/skylights WITHOUT an internal shade taken from
    # ASHRAE HOF Ch.26 Table 36 (subset of data in MJ8 Table A11-5)
    # Surface Azimuth = 0 (South), 22.5, 45.0, ... ,337.5,360 and Hour = 8,9, ... ,19,20
    clf_hr_nois = [[0.14, 0.22, 0.34, 0.48, 0.59, 0.65, 0.65, 0.59, 0.50, 0.43, 0.36, 0.28, 0.22],
                   [0.11, 0.15, 0.19, 0.27, 0.39, 0.52, 0.62, 0.67, 0.65, 0.58, 0.46, 0.36, 0.28],
                   [0.10, 0.12, 0.14, 0.16, 0.24, 0.36, 0.49, 0.60, 0.66, 0.66, 0.58, 0.43, 0.33],
                   [0.09, 0.10, 0.12, 0.13, 0.17, 0.26, 0.40, 0.52, 0.62, 0.66, 0.61, 0.44, 0.34],
                   [0.08, 0.10, 0.11, 0.12, 0.14, 0.20, 0.32, 0.45, 0.57, 0.64, 0.61, 0.44, 0.34],
                   [0.09, 0.10, 0.12, 0.13, 0.15, 0.17, 0.26, 0.40, 0.53, 0.63, 0.62, 0.44, 0.34],
                   [0.10, 0.12, 0.14, 0.16, 0.17, 0.19, 0.23, 0.33, 0.47, 0.59, 0.60, 0.43, 0.33],
                   [0.14, 0.18, 0.22, 0.25, 0.27, 0.29, 0.30, 0.33, 0.44, 0.57, 0.62, 0.44, 0.33],
                   [0.48, 0.56, 0.63, 0.71, 0.76, 0.80, 0.82, 0.82, 0.79, 0.75, 0.69, 0.61, 0.48],
                   [0.47, 0.44, 0.41, 0.40, 0.39, 0.39, 0.38, 0.36, 0.33, 0.30, 0.26, 0.20, 0.16],
                   [0.51, 0.51, 0.45, 0.39, 0.36, 0.33, 0.31, 0.28, 0.26, 0.23, 0.19, 0.15, 0.12],
                   [0.52, 0.57, 0.50, 0.45, 0.39, 0.34, 0.31, 0.28, 0.25, 0.22, 0.18, 0.14, 0.12],
                   [0.51, 0.57, 0.57, 0.50, 0.42, 0.37, 0.32, 0.29, 0.25, 0.22, 0.19, 0.15, 0.12],
                   [0.49, 0.58, 0.61, 0.57, 0.48, 0.41, 0.36, 0.32, 0.28, 0.24, 0.20, 0.16, 0.13],
                   [0.43, 0.55, 0.62, 0.63, 0.57, 0.48, 0.42, 0.37, 0.33, 0.28, 0.24, 0.19, 0.15],
                   [0.27, 0.43, 0.55, 0.63, 0.64, 0.60, 0.52, 0.45, 0.40, 0.35, 0.29, 0.23, 0.18],
                   [0.14, 0.22, 0.34, 0.48, 0.59, 0.65, 0.65, 0.59, 0.50, 0.43, 0.36, 0.28, 0.22]]
    clf_hr_nois_horiz = [0.24, 0.36, 0.48, 0.58, 0.66, 0.72, 0.74, 0.73, 0.67, 0.59, 0.47, 0.37, 0.29]

    # Hourly cooling load factor (CLF) for windows/skylights WITH an internal shade taken from
    # ASHRAE HOF Ch.26 Table 39 (subset of data in MJ8 Table A11-6)
    # Surface Azimuth = 0 (South), 22.5, 45.0, ... ,337.5,360 and Hour = 8,9, ... ,19,20
    clf_hr_is = [[0.23, 0.38, 0.58, 0.75, 0.83, 0.80, 0.68, 0.50, 0.35, 0.27, 0.19, 0.11, 0.09],
                 [0.18, 0.22, 0.27, 0.43, 0.63, 0.78, 0.84, 0.80, 0.66, 0.46, 0.25, 0.13, 0.11],
                 [0.14, 0.16, 0.19, 0.22, 0.38, 0.59, 0.75, 0.83, 0.81, 0.69, 0.45, 0.16, 0.12],
                 [0.12, 0.14, 0.16, 0.17, 0.23, 0.44, 0.64, 0.78, 0.84, 0.78, 0.55, 0.16, 0.12],
                 [0.11, 0.13, 0.15, 0.16, 0.17, 0.31, 0.53, 0.72, 0.82, 0.81, 0.61, 0.16, 0.12],
                 [0.12, 0.14, 0.16, 0.17, 0.18, 0.22, 0.43, 0.65, 0.80, 0.84, 0.66, 0.16, 0.12],
                 [0.14, 0.17, 0.19, 0.20, 0.21, 0.22, 0.30, 0.52, 0.73, 0.82, 0.69, 0.16, 0.12],
                 [0.22, 0.26, 0.30, 0.32, 0.33, 0.34, 0.34, 0.39, 0.61, 0.82, 0.76, 0.17, 0.12],
                 [0.65, 0.73, 0.80, 0.86, 0.89, 0.89, 0.86, 0.82, 0.75, 0.78, 0.91, 0.24, 0.18],
                 [0.62, 0.42, 0.37, 0.37, 0.37, 0.36, 0.35, 0.32, 0.28, 0.23, 0.17, 0.08, 0.07],
                 [0.74, 0.58, 0.37, 0.29, 0.27, 0.26, 0.24, 0.22, 0.20, 0.16, 0.12, 0.06, 0.05],
                 [0.80, 0.71, 0.52, 0.31, 0.26, 0.24, 0.22, 0.20, 0.18, 0.15, 0.11, 0.06, 0.05],
                 [0.80, 0.76, 0.62, 0.41, 0.27, 0.24, 0.22, 0.20, 0.17, 0.14, 0.11, 0.06, 0.05],
                 [0.79, 0.80, 0.72, 0.54, 0.34, 0.27, 0.24, 0.21, 0.19, 0.15, 0.12, 0.07, 0.06],
                 [0.74, 0.81, 0.79, 0.68, 0.49, 0.33, 0.28, 0.25, 0.22, 0.18, 0.13, 0.08, 0.07],
                 [0.54, 0.72, 0.81, 0.81, 0.71, 0.54, 0.38, 0.32, 0.27, 0.22, 0.16, 0.09, 0.08],
                 [0.23, 0.38, 0.58, 0.75, 0.83, 0.80, 0.68, 0.50, 0.35, 0.27, 0.19, 0.11, 0.09]]
    clf_hr_is_horiz = [0.44, 0.59, 0.72, 0.81, 0.85, 0.85, 0.81, 0.71, 0.58, 0.42, 0.25, 0.14, 0.12]

    # Shade Line Multipliers (SLM) for shaded windows will be calculated using the procedure
    # described in ASHRAE HOF 1997 instead of using the SLM's from MJ8 Table 3E-1

    # The time of day (assuming 24 hr clock) to calculate the SLM for the ALP for azimuths
    # starting at 0 (South) in increments of 22.5 to 360
    # Nil denotes directions not used in the shading calculation (Note: south direction is symmetrical around noon)
    slm_alp_hr = [15.5, 14.75, 14, 14.75, 15.5, nil, nil, nil, nil, nil, nil, nil, 8.5, 9.75, 10, 9.75, 8.5]

    # Mid summer declination angle used for shading calculations
    declination_angle = 12.1 # Mid August

    # Peak solar factor (PSF) (aka solar heat gain factor) taken from ASHRAE HOF 1989 Ch.26 Table 34
    # (subset of data in MJ8 Table 3D-2)
    # Surface Azimuth = 0 (South), 22.5, 45.0, ... ,337.5,360 and Latitude = 20,24,28, ... ,60,64
    psf = [[57, 72, 91, 111, 131, 149, 165, 180, 193, 203, 211, 217],
           [88, 103, 120, 136, 151, 165, 177, 188, 197, 206, 213, 217],
           [152, 162, 172, 181, 189, 196, 202, 208, 212, 215, 217, 217],
           [200, 204, 207, 210, 212, 214, 215, 216, 216, 216, 214, 211],
           [220, 220, 220, 219, 218, 216, 214, 211, 208, 203, 199, 193],
           [206, 203, 199, 195, 190, 185, 180, 174, 169, 165, 161, 157],
           [162, 156, 149, 141, 138, 135, 132, 128, 124, 119, 114, 109],
           [91,  87,  83,  79,  75,  71,  66,  61,  56,  56,  57,  58],
           [40,  38,  38,  37,  36,  35,  34,  33,  32,  30,  28,  27],
           [91,  87,  83,  79,  75,  71,  66,  61,  56,  56,  57,  58],
           [162, 156, 149, 141, 138, 135, 132, 128, 124, 119, 114, 109],
           [206, 203, 199, 195, 190, 185, 180, 174, 169, 165, 161, 157],
           [220, 220, 220, 219, 218, 216, 214, 211, 208, 203, 199, 193],
           [200, 204, 207, 210, 212, 214, 215, 216, 216, 216, 214, 211],
           [152, 162, 172, 181, 189, 196, 202, 208, 212, 215, 217, 217],
           [88, 103, 120, 136, 151, 165, 177, 188, 197, 206, 213, 217],
           [57, 72, 91, 111, 131, 149, 165, 180, 193, 203, 211, 217]]
    psf_horiz = [280, 277, 272, 265, 257, 247, 236, 223, 208, 193, 176, 159]

    # Hourly Temperature Adjustment Values (HTA_DR) (MJ8 Table A11-3)
    # Low DR, Medium DR, High DR and Hour = 8,9, ... ,19,20
    hta = [[-6.3, -5.0, -3.7, -2.5, -1.5, -0.7, -0.2, 0.0, -0.2, -0.7, -1.5, -2.5, -3.7], # Low DR
           [-12.6, -10.0, -7.4, -5.0, -2.9, -1.3, -0.3, 0.0, -0.3, -1.3, -2.9, -5.0, -7.4], # Medium DR
           [-18.9, -15.0, -11.1, -7.5, -4.4, -2.0, -0.5, 0.0, -0.5, -2.0, -4.4, -7.5, -11.1]] # High DR

    # Determine the PSF's for the building latitude
    psf_lat = []
    psf_lat_horiz = nil
    latitude = weather.header.Latitude.to_f
    for cnt in 0..16
      if latitude < 20.0
        psf_lat << psf[cnt][0]
        if cnt == 0
          runner.registerWarning('Latitude of 20 was assumed for Manual J solar load calculations.')
          psf_lat_horiz = psf_horiz[0]
        end
      elsif latitude > 64.0
        psf_lat << psf[cnt][11]
        if cnt == 0
          runner.registerWarning('Latitude of 64 was assumed for Manual J solar load calculations.')
          psf_lat_horiz = psf_horiz[11]
        end
      else
        cnt_lat_s = ((latitude - 20.0) / 4.0).to_i
        cnt_lat_n = cnt_lat_s + 1
        lat_s = 20 + 4 * cnt_lat_s
        lat_n = lat_s + 4
        psf_lat << MathTools.interp2(latitude, lat_s, lat_n, psf[cnt][cnt_lat_s], psf[cnt][cnt_lat_n])
        if cnt == 0
          psf_lat_horiz = MathTools.interp2(latitude, lat_s, lat_n, psf_horiz[cnt_lat_s], psf_horiz[cnt_lat_n])
        end
      end
    end

    # Windows
    zone_loads.Heat_Windows = 0
    zone_loads.Dehumid_Windows = 0
    alp_load = 0 # Average Load Procedure (ALP) Load
    afl_hr = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] # Initialize Hourly Aggregate Fenestration Load (AFL)

    Geometry.get_spaces_above_grade_exterior_walls(thermal_zone.spaces).each do |wall|
      wall_true_azimuth = true_azimuth(wall)
      cnt225 = (wall_true_azimuth / 22.5).round.to_i

      wall.subSurfaces.each do |window|
        next if not window.subSurfaceType.downcase.include?('window')

        # U-factor
        u_window = get_surface_ufactor(runner, window, window.subSurfaceType, true)
        return nil if u_window.nil?

        zone_loads.Heat_Windows += u_window * UnitConversions.convert(window.grossArea, 'm^2', 'ft^2') * htd
        zone_loads.Dehumid_Windows += u_window * UnitConversions.convert(window.grossArea, 'm^2', 'ft^2') * mj8.dtd

        # SHGC & Internal Shading
        shgc_with_interior_shade_cool, shgc_with_interior_shade_heat = get_fenestration_shgc(runner, window)
        return nil if shgc_with_interior_shade_cool.nil? || shgc_with_interior_shade_heat.nil?

        windowHeight = Geometry.surface_height(window)
        windowHasIntShading = window.shadingControl.is_initialized

        # Determine window overhang properties
        windowHasOverhang = false
        windowOverhangDepth = nil
        windowOverhangOffset = nil
        window.shadingSurfaceGroups.each do |ssg|
          ssg.shadingSurfaces.each do |ss|
            windowHasOverhang = true
            windowOverhangDepth = get_feature(runner, window, Constants.SizingInfoWindowOverhangDepth, 'double')
            windowOverhangOffset = get_feature(runner, window, Constants.SizingInfoWindowOverhangOffset, 'double')
            return nil if windowOverhangDepth.nil? || windowOverhangOffset.nil?
          end
        end

        for hr in -1..12

          # If hr == -1: Calculate the Average Load Procedure (ALP) Load
          # Else: Calculate the hourly Aggregate Fenestration Load (AFL)

          # clf_d: Average Cooling Load Factor for the given window direction
          # clf_n: Average Cooling Load Factor for a window facing North (fully shaded)
          if hr == -1
            if windowHasIntShading
              clf_d = clf_avg_is[cnt225]
              clf_n = clf_avg_is[8]
            else
              clf_d = clf_avg_nois[cnt225]
              clf_n = clf_avg_nois[8]
            end
          else
            if windowHasIntShading
              clf_d = clf_hr_is[cnt225][hr]
              clf_n = clf_hr_is[8][hr]
            else
              clf_d = clf_hr_nois[cnt225][hr]
              clf_n = clf_hr_nois[8][hr]
            end
          end

          ctd = mj8.ctd
          if hr > -1
            # Calculate hourly CTD adjusted value for mid-summer
            ctd += hta[mj8.daily_range_num][hr]
          end

          # Hourly Heat Transfer Multiplier for the given window Direction
          htm_d = psf_lat[cnt225] * clf_d * shgc_with_interior_shade_cool / 0.87 + u_window * ctd

          # Hourly Heat Transfer Multiplier for a window facing North (fully shaded)
          htm_n = psf_lat[8] * clf_n * shgc_with_interior_shade_cool / 0.87 + u_window * ctd

          if wall_true_azimuth < 180
            surf_azimuth = wall_true_azimuth
          else
            surf_azimuth = wall_true_azimuth - 360
          end

          # TODO: Account for eaves, porches, etc.
          if windowHasOverhang
            if ((hr == -1) && (surf_azimuth.abs < 90.1)) || (hr > -1)
              if hr == -1
                actual_hr = slm_alp_hr[cnt225]
              else
                actual_hr = hr + 8 # start at hour 8
              end
              hour_angle = 0.25 * (actual_hr - 12) * 60 # ASHRAE HOF 1997 pg 29.19
              altitude_angle = Math::asin((Math::cos(weather.header.Latitude.deg2rad) *
                                            Math::cos(declination_angle.deg2rad) *
                                            Math::cos(hour_angle.deg2rad) +
                                            Math::sin(weather.header.Latitude.deg2rad) *
                                            Math::sin(declination_angle.deg2rad))).rad2deg
              temp_arg = [(Math::sin(altitude_angle.deg2rad) *
                           Math::sin(weather.header.Latitude.deg2rad) -
                           Math::sin(declination_angle.deg2rad)) /
                (Math::cos(altitude_angle.deg2rad) *
                   Math::cos(weather.header.Latitude.deg2rad)), 1.0].min
              temp_arg = [temp_arg, -1.0].max
              solar_azimuth = Math::acos(temp_arg).rad2deg
              if actual_hr < 12
                solar_azimuth = -1.0 * solar_azimuth
              end

              sol_surf_azimuth = solar_azimuth - surf_azimuth
              if (sol_surf_azimuth.abs >= 90) && (sol_surf_azimuth.abs <= 270)
                # Window is entirely in the shade if the solar surface azimuth is greater than 90 and less than 270
                htm = htm_n
              else
                slm = Math::tan(altitude_angle.deg2rad) / Math::cos(sol_surf_azimuth.deg2rad)
                z_sl = slm * windowOverhangDepth

                if z_sl < windowOverhangOffset
                  # Overhang is too short to provide shade
                  htm = htm_d
                elsif z_sl < (windowOverhangOffset + windowHeight)
                  percent_shaded = (z_sl - windowOverhangOffset) / windowHeight
                  htm = percent_shaded * htm_n + (1 - percent_shaded) * htm_d
                else
                  # Window is entirely in the shade since the shade line is below the windowsill
                  htm = htm_n
                end
              end
            else
              # Window is north of East and West azimuths. Shading calculations do not apply.
              htm = htm_d
            end
          else
            htm = htm_d
          end

          if hr == -1
            alp_load += htm * UnitConversions.convert(window.grossArea, 'm^2', 'ft^2')
          else
            afl_hr[hr] += htm * UnitConversions.convert(window.grossArea, 'm^2', 'ft^2')
          end
        end
      end # window
    end # wall

    # Daily Average Load (DAL)
    dal = afl_hr.inject { |sum, n| sum + n } / afl_hr.size

    # Excursion Limit line (ELL)
    ell = 1.3 * dal

    # Peak Fenestration Load (PFL)
    pfl = afl_hr.max

    # Excursion Adjustment Load (EAL)
    eal = [0, pfl - ell].max

    # Window Cooling Load
    zone_loads.Cool_Windows = alp_load + eal

    # Skylights
    zone_loads.Heat_Skylights = 0
    zone_loads.Dehumid_Skylights = 0
    alp_load = 0 # Average Load Procedure (ALP) Load
    afl_hr = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] # Initialize Hourly Aggregate Fenestration Load (AFL)

    Geometry.get_spaces_above_grade_exterior_roofs(thermal_zone.spaces).each do |roof|
      roof_true_azimuth = true_azimuth(roof)
      cnt225 = (roof_true_azimuth / 22.5).round.to_i
      inclination_angle = Geometry.get_roof_pitch([roof])

      roof.subSurfaces.each do |skylight|
        next if not skylight.subSurfaceType.downcase.include?('skylight')

        # U-factor
        u_skylight = get_surface_ufactor(runner, skylight, skylight.subSurfaceType, true)
        return nil if u_skylight.nil?

        zone_loads.Heat_Skylights += u_skylight * UnitConversions.convert(skylight.grossArea, 'm^2', 'ft^2') * htd
        zone_loads.Dehumid_Skylights += u_skylight * UnitConversions.convert(skylight.grossArea, 'm^2', 'ft^2') * mj8.dtd

        # SHGC & Internal Shading
        shgc_with_interior_shade_cool, shgc_with_interior_shade_heat = get_fenestration_shgc(runner, skylight)
        return nil if shgc_with_interior_shade_cool.nil? || shgc_with_interior_shade_heat.nil?

        skylightHasIntShading = skylight.shadingControl.is_initialized

        for hr in -1..12

          # If hr == -1: Calculate the Average Load Procedure (ALP) Load
          # Else: Calculate the hourly Aggregate Fenestration Load (AFL)

          # clf_d: Average Cooling Load Factor for the given skylight direction
          # clf_d: Average Cooling Load Factor for horizontal
          if hr == -1
            if skylightHasIntShading
              clf_d = clf_avg_is[cnt225]
              clf_horiz = clf_avg_is_horiz
            else
              clf_d = clf_avg_nois[cnt225]
              clf_horiz = clf_avg_nois_horiz
            end
          else
            if skylightHasIntShading
              clf_d = clf_hr_is[cnt225][hr]
              clf_horiz = clf_hr_is_horiz[hr]
            else
              clf_d = clf_hr_nois[cnt225][hr]
              clf_horiz = clf_hr_nois_horiz[hr]
            end
          end

          sol_h = Math::cos(inclination_angle.deg2rad) * (psf_lat_horiz * clf_horiz)
          sol_v = Math::sin(inclination_angle.deg2rad) * (psf_lat[cnt225] * clf_d)

          ctd = mj8.ctd
          if hr > -1
            # Calculate hourly CTD adjusted value for mid-summer
            ctd += hta[mj8.daily_range_num][hr]
          end

          # Hourly Heat Transfer Multiplier for the given skylight Direction
          u_curb = 0.51 # default to wood (Table 2B-3)
          ar_curb = 0.35 # default to small (Table 2B-3)
          u_eff_skylight = u_skylight + u_curb * ar_curb
          htm = (sol_h + sol_v) * (shgc_with_interior_shade_cool / 0.87) + u_eff_skylight * (ctd + 15)

          if hr == -1
            alp_load += htm * UnitConversions.convert(skylight.grossArea, 'm^2', 'ft^2')
          else
            afl_hr[hr] += htm * UnitConversions.convert(skylight.grossArea, 'm^2', 'ft^2')
          end
        end
      end # skylight
    end # roof

    # Daily Average Load (DAL)
    dal = afl_hr.inject { |sum, n| sum + n } / afl_hr.size

    # Excursion Limit line (ELL)
    ell = 1.3 * dal

    # Peak Fenestration Load (PFL)
    pfl = afl_hr.max

    # Excursion Adjustment Load (EAL)
    eal = [0, pfl - ell].max

    # Skylight Cooling Load
    zone_loads.Cool_Skylights = alp_load + eal

    return zone_loads
  end

  def self.process_load_doors(runner, mj8, thermal_zone, zone_loads, weather, htd)
    '''
    Heating, Cooling, and Dehumidification Loads: Doors
    '''

    return if mj8.nil? || zone_loads.nil?

    if mj8.daily_range_num == 0
      cltd_Door = mj8.ctd + 15
    elsif mj8.daily_range_num == 1
      cltd_Door = mj8.ctd + 11
    else
      cltd_Door = mj8.ctd + 6
    end

    zone_loads.Heat_Doors = 0
    zone_loads.Cool_Doors = 0
    zone_loads.Dehumid_Doors = 0

    Geometry.get_spaces_above_grade_exterior_walls(thermal_zone.spaces).each do |wall|
      wall.subSurfaces.each do |door|
        next if not door.subSurfaceType.downcase.include?('door')

        door_ufactor = get_surface_ufactor(runner, door, door.subSurfaceType, true)
        return nil if door_ufactor.nil?

        zone_loads.Heat_Doors += door_ufactor * UnitConversions.convert(door.grossArea, 'm^2', 'ft^2') * htd
        zone_loads.Cool_Doors += door_ufactor * UnitConversions.convert(door.grossArea, 'm^2', 'ft^2') * cltd_Door
        zone_loads.Dehumid_Doors += door_ufactor * UnitConversions.convert(door.grossArea, 'm^2', 'ft^2') * mj8.dtd
      end
    end

    return zone_loads
  end

  def self.process_load_walls(runner, mj8, unit, thermal_zone, zone_loads, weather, htd)
    '''
    Heating, Cooling, and Dehumidification Loads: Walls
    '''

    return if mj8.nil? || zone_loads.nil?

    zone_loads.Heat_Walls = 0
    zone_loads.Cool_Walls = 0
    zone_loads.Dehumid_Walls = 0

    # Above-Grade Exterior Walls
    Geometry.get_spaces_above_grade_exterior_walls(thermal_zone.spaces).each do |wall|
      wallGroup = get_wallgroup(runner, unit, wall)
      return nil if wallGroup.nil?

      # Adjust base Cooling Load Temperature Difference (CLTD)
      # Assume absorptivity for light walls < 0.5, medium walls <= 0.75, dark walls > 0.75 (based on MJ8 Table 4B Notes)

      exteriorFinishAbsorptivity = wall.construction.get.to_LayeredConstruction.get.getLayer(0).to_StandardOpaqueMaterial.get.solarAbsorptance

      if exteriorFinishAbsorptivity <= 0.5
        colorMultiplier = 0.65      # MJ8 Table 4B Notes, pg 348
      elsif exteriorFinishAbsorptivity <= 0.75
        colorMultiplier = 0.83      # MJ8 Appendix 12, pg 519
      else
        colorMultiplier = 1.0
      end

      wall_true_azimuth = true_azimuth(wall)

      # Base Cooling Load Temperature Differences (CLTD's) for dark colored sunlit and shaded walls
      # with 95 degF outside temperature taken from MJ8 Figure A12-8 (intermediate wall groups were
      # determined using linear interpolation). Shaded walls apply to north facing and partition walls only.
      cltd_base_sun = [38, 34.95, 31.9, 29.45, 27, 24.5, 22, 21.25, 20.5, 19.65, 18.8]
      cltd_base_shade = [25, 22.5, 20, 18.45, 16.9, 15.45, 14, 13.55, 13.1, 12.85, 12.6]

      if (wall_true_azimuth >= 157.5) && (wall_true_azimuth <= 202.5)
        cltd_Wall = cltd_base_shade[wallGroup - 1] * colorMultiplier
      else
        cltd_Wall = cltd_base_sun[wallGroup - 1] * colorMultiplier
      end

      if mj8.ctd >= 10
        # Adjust the CLTD for different cooling design temperatures
        cltd_Wall += (weather.design.CoolingDrybulb - 95)
        # Adjust the CLTD for daily temperature range
        cltd_Wall += mj8.daily_range_temp_adjust[mj8.daily_range_num]
      else
        # Handling cases ctd < 10 is based on A12-18 in MJ8
        cltd_corr = mj8.ctd - 20 - mj8.daily_range_temp_adjust[mj8.daily_range_num]
        cltd_Wall = [cltd_Wall + cltd_corr, 0].max # Assume zero cooling load for negative CLTD's
      end

      wall_ufactor = get_surface_ufactor(runner, wall, wall.surfaceType, true)
      return nil if wall_ufactor.nil?

      zone_loads.Cool_Walls += wall_ufactor * UnitConversions.convert(wall.netArea, 'm^2', 'ft^2') * cltd_Wall
      zone_loads.Heat_Walls += wall_ufactor * UnitConversions.convert(wall.netArea, 'm^2', 'ft^2') * htd
      zone_loads.Dehumid_Walls += wall_ufactor * UnitConversions.convert(wall.netArea, 'm^2', 'ft^2') * mj8.dtd
    end

    # Interzonal Walls
    Geometry.get_spaces_interzonal_walls(thermal_zone.spaces).each do |wall|
      wall_ufactor = get_surface_ufactor(runner, wall, wall.surfaceType, true)
      return nil if wall_ufactor.nil?

      adjacent_space = wall.adjacentSurface.get.space.get
      zone_loads.Cool_Walls += wall_ufactor * UnitConversions.convert(wall.netArea, 'm^2', 'ft^2') * (mj8.cool_design_temps[adjacent_space] - mj8.cool_setpoint)
      zone_loads.Heat_Walls += wall_ufactor * UnitConversions.convert(wall.netArea, 'm^2', 'ft^2') * (mj8.heat_setpoint - mj8.heat_design_temps[adjacent_space])
      zone_loads.Dehumid_Walls += wall_ufactor * UnitConversions.convert(wall.netArea, 'm^2', 'ft^2') * (mj8.cool_setpoint - mj8.dehum_design_temps[adjacent_space])
    end

    # Foundation walls
    Geometry.get_spaces_below_grade_exterior_walls(thermal_zone.spaces).each do |wall|
      wall_ins_rvalue, wall_ins_height, wall_constr_rvalue = get_foundation_wall_insulation_props(runner, wall)
      if wall_ins_rvalue.nil? || wall_ins_height.nil? || wall_constr_rvalue.nil?
        return nil
      end

      k_soil = UnitConversions.convert(BaseMaterial.Soil.k_in, 'in', 'ft')
      ins_wall_ufactor = 1.0 / (wall_constr_rvalue + wall_ins_rvalue + Material.AirFilmVertical.rvalue)
      unins_wall_ufactor = 1.0 / (wall_constr_rvalue + Material.AirFilmVertical.rvalue)
      above_grade_height = Geometry.space_height(wall.space.get) - Geometry.surface_height(wall)

      # Calculated based on Manual J 8th Ed. procedure in section A12-4 (15% decrease due to soil thermal storage)
      u_value_mj8 = 0.0
      wall_height_ft = Geometry.get_surface_height(wall).round
      for d in 1..wall_height_ft
        r_soil = (Math::PI * d / 2.0) / k_soil
        if d <= above_grade_height
          r_wall = 1.0 / ins_wall_ufactor + AirFilms.OutsideR
        elsif d <= wall_ins_height
          r_wall = 1.0 / ins_wall_ufactor
        else
          r_wall = 1.0 / unins_wall_ufactor
        end
        u_value_mj8 += 1.0 / (r_soil + r_wall)
      end
      u_value_mj8 = (u_value_mj8 / wall_height_ft) * 0.85

      zone_loads.Heat_Walls += u_value_mj8 * UnitConversions.convert(wall.netArea, 'm^2', 'ft^2') * htd
    end

    return zone_loads
  end

  def self.process_load_roofs(runner, mj8, unit, thermal_zone, zone_loads, weather, htd)
    '''
    Heating, Cooling, and Dehumidification Loads: Ceilings
    '''

    return if mj8.nil? || zone_loads.nil?

    cltd_FinishedRoof = 0

    zone_loads.Heat_Roofs = 0
    zone_loads.Cool_Roofs = 0
    zone_loads.Dehumid_Roofs = 0

    # Roofs
    Geometry.get_spaces_above_grade_exterior_roofs(thermal_zone.spaces).each do |roof|
      roof_color = get_feature(runner, roof, Constants.SizingInfoRoofColor, 'string')
      return nil if roof_color.nil?

      roof_material = get_feature(runner, roof, Constants.SizingInfoRoofMaterial, 'string')
      return nil if roof_material.nil?

      cavity_r = get_feature(runner, roof, Constants.SizingInfoRoofCavityRvalue, 'double')
      return nil if cavity_r.nil?

      rigid_r = get_feature(runner, roof, Constants.SizingInfoRoofRigidInsRvalue, 'double', false)
      rigid_r = 0 if rigid_r.nil?

      total_r = cavity_r + rigid_r

      # Base CLTD for finished roofs (Roof-Joist-Ceiling Sandwiches) taken from MJ8 Figure A12-16
      if total_r <= 6
        cltd_FinishedRoof = 50
      elsif total_r <= 13
        cltd_FinishedRoof = 45
      elsif total_r <= 15
        cltd_FinishedRoof = 38
      elsif total_r <= 21
        cltd_FinishedRoof = 31
      elsif total_r <= 30
        cltd_FinishedRoof = 30
      else
        cltd_FinishedRoof = 27
      end

      # Base CLTD color adjustment based on notes in MJ8 Figure A12-16
      if roof_color == Constants.ColorDark
        if [Constants.RoofMaterialTile, Constants.RoofMaterialWoodShakes].include?(roof_material)
          cltd_FinishedRoof *= 0.83
        end
      elsif [Constants.ColorMedium, Constants.ColorLight].include?(roof_color)
        if roof_material == Constants.RoofMaterialTile
          cltd_FinishedRoof *= 0.65
        else
          cltd_FinishedRoof *= 0.83
        end
      elsif roof_color == Constants.ColorWhite
        if [Constants.RoofMaterialAsphaltShingles, Constants.RoofMaterialWoodShakes].include?(roof_material)
          cltd_FinishedRoof *= 0.83
        else
          cltd_FinishedRoof *= 0.65
        end
      end

      # Adjust base CLTD for different CTD or DR
      cltd_FinishedRoof = cltd_FinishedRoof + (weather.design.CoolingDrybulb - 95) + mj8.daily_range_temp_adjust[mj8.daily_range_num]

      roof_ufactor = get_surface_ufactor(runner, roof, roof.surfaceType, true)
      return nil if roof_ufactor.nil?

      zone_loads.Cool_Roofs += roof_ufactor * UnitConversions.convert(roof.netArea, 'm^2', 'ft^2') * cltd_FinishedRoof
      zone_loads.Heat_Roofs += roof_ufactor * UnitConversions.convert(roof.netArea, 'm^2', 'ft^2') * htd
      zone_loads.Dehumid_Roofs += roof_ufactor * UnitConversions.convert(roof.netArea, 'm^2', 'ft^2') * mj8.dtd
    end

    return zone_loads
  end

  def self.process_load_floors(runner, mj8, unit, thermal_zone, zone_loads, weather, htd)
    '''
    Heating, Cooling, and Dehumidification Loads: Floors
    '''
    return if mj8.nil? || zone_loads.nil?

    zone_loads.Heat_Floors = 0
    zone_loads.Cool_Floors = 0
    zone_loads.Dehumid_Floors = 0

    # Exterior Floors
    floor_ufactor = nil
    Geometry.get_spaces_above_grade_exterior_floors(thermal_zone.spaces).each do |floor|
      floor_ufactor = get_surface_ufactor(runner, floor, floor.surfaceType, true)
      return nil if floor_ufactor.nil?

      zone_loads.Cool_Floors += floor_ufactor * UnitConversions.convert(floor.netArea, 'm^2', 'ft^2') * (mj8.ctd - 5 + mj8.daily_range_temp_adjust[mj8.daily_range_num])
      zone_loads.Heat_Floors += floor_ufactor * UnitConversions.convert(floor.netArea, 'm^2', 'ft^2') * htd
      zone_loads.Dehumid_Floors += floor_ufactor * UnitConversions.convert(floor.netArea, 'm^2', 'ft^2') * mj8.dtd
    end

    # Interzonal Floors
    Geometry.get_spaces_interzonal_floors_and_ceilings(thermal_zone.spaces).each do |floor|
      floor_ufactor = get_surface_ufactor(runner, floor, floor.surfaceType, true)
      return nil if floor_ufactor.nil?

      adjacent_space = floor.adjacentSurface.get.space.get
      zone_loads.Cool_Floors += floor_ufactor * UnitConversions.convert(floor.netArea, 'm^2', 'ft^2') * (mj8.cool_design_temps[adjacent_space] - mj8.cool_setpoint)
      zone_loads.Heat_Floors += floor_ufactor * UnitConversions.convert(floor.netArea, 'm^2', 'ft^2') * (mj8.heat_setpoint - mj8.heat_design_temps[adjacent_space])
      zone_loads.Dehumid_Floors += floor_ufactor * UnitConversions.convert(floor.netArea, 'm^2', 'ft^2') * (mj8.cool_setpoint - mj8.dehum_design_temps[adjacent_space])
    end

    # Foundation Floors
    Geometry.get_spaces_below_grade_exterior_floors(thermal_zone.spaces).each do |floor|
      # Finished basement floor combinations based on MJ 8th Ed. A12-7 and ASHRAE HoF 2013 pg 18.31 Eq 40
      k_soil = UnitConversions.convert(BaseMaterial.Soil.k_in, 'in', 'ft')
      r_other = Material.Concrete(4.0).rvalue + Material.AirFilmFloorAverage.rvalue
      z_f = -1 * (Geometry.getSurfaceZValues([floor]).min + UnitConversions.convert(floor.space.get.zOrigin, 'm', 'ft'))
      w_b = [Geometry.getSurfaceXValues([floor]).max - Geometry.getSurfaceXValues([floor]).min, Geometry.getSurfaceYValues([floor]).max - Geometry.getSurfaceYValues([floor]).min].min
      u_avg_bf = (2.0 * k_soil / (Math::PI * w_b)) * (Math::log(w_b / 2.0 + z_f / 2.0 + (k_soil * r_other) / Math::PI) - Math::log(z_f / 2.0 + (k_soil * r_other) / Math::PI))
      u_value_mj8 = 0.85 * u_avg_bf
      zone_loads.Heat_Floors += u_value_mj8 * UnitConversions.convert(floor.netArea, 'm^2', 'ft^2') * htd
    end

    # Ground Floors (Slab)
    Geometry.get_spaces_above_grade_ground_floors(thermal_zone.spaces).each do |floor|
      # Get stored u-factor since the surface u-factor is fictional
      # TODO: Revert this some day.
      # floor_ufactor = get_surface_ufactor(runner, floor, floor.surfaceType, true)
      # return nil if floor_ufactor.nil?
      floor_rvalue = get_feature(runner, floor, Constants.SizingInfoSlabRvalue, 'double')
      return nil if floor_rvalue.nil?

      floor_ufactor = 1.0 / floor_rvalue
      zone_loads.Heat_Floors += floor_ufactor * UnitConversions.convert(floor.netArea, 'm^2', 'ft^2') * (mj8.heat_setpoint - weather.data.GroundMonthlyTemps[0])
    end

    return zone_loads
  end

  def self.process_infiltration_ventilation(runner, mj8, unit, thermal_zone, zone_loads, weather, htd, unit_shelter_class)
    '''
    Heating, Cooling, and Dehumidification Loads: Infiltration & Ventilation
    '''

    return if mj8.nil? || zone_loads.nil?

    if Geometry.zone_is_below_grade(thermal_zone)
      zone_loads.Heat_Infil = 0 # TODO: Calculate using actual basement infiltration?
      zone_loads.Cool_Infil_Sens = 0
      zone_loads.Cool_Infil_Lat = 0
      zone_loads.Dehumid_Infil_Sens = 0
      zone_loads.Dehumid_Infil_Lat = 0
      return zone_loads
    end

    # Stack Coefficient (Cs) for infiltration calculation taken from Table 5D
    # Wind Coefficient (Cw) for Shielding Classes 1-5 for infiltration calculation taken from Table 5D
    # Coefficients converted to regression equations to allow for more than 3 stories
    zone_finished_top = Geometry.get_height_of_spaces(Geometry.get_finished_spaces(thermal_zone.spaces))
    zone_top_story = (zone_finished_top / 8.0).round
    c_s = 0.015 * zone_top_story
    if unit_shelter_class == 1
      c_w = 0.0119 * zone_top_story**0.4
    elsif unit_shelter_class == 2
      c_w = 0.0092 * zone_top_story**0.4
    elsif unit_shelter_class == 3
      c_w = 0.0065 * zone_top_story**0.4
    elsif unit_shelter_class == 4
      c_w = 0.0039 * zone_top_story**0.4
    elsif unit_shelter_class == 5
      c_w = 0.0012 * zone_top_story**0.4
    else
      runner.registerError('Invalid shelter_class: {}'.format(unit_shelter_class))
      return
    end

    ela = get_feature(runner, thermal_zone, Constants.SizingInfoZoneInfiltrationELA, 'double', false)
    ela = 0 if ela.nil?

    ela_in2 = UnitConversions.convert(ela, 'ft^2', 'in^2')
    windspeed_cooling_mph = UnitConversions.convert(@windspeed_cooling, 'm/s', 'mph')
    windspeed_heating_mph = UnitConversions.convert(@windspeed_heating, 'm/s', 'mph')

    icfm_Cooling = ela_in2 * (c_s * mj8.ctd.abs + c_w * windspeed_cooling_mph**2)**0.5
    icfm_Heating = ela_in2 * (c_s * htd.abs + c_w * windspeed_heating_mph**2)**0.5
    icfm_Dehumid = ela_in2 * (c_s * mj8.dtd.abs + c_w * [windspeed_cooling_mph, windspeed_heating_mph].max**2)**0.5

    q_unb, q_bal_Sens, q_bal_Lat = get_ventilation_rates(runner, unit)
    return if q_unb.nil? || q_bal_Sens.nil? || q_bal_Lat.nil?

    cfm_Heating = q_bal_Sens + (icfm_Heating**2 + q_unb**2)**0.5

    cfm_Cool_Load_Sens = q_bal_Sens + (icfm_Cooling**2 + q_unb**2)**0.5
    cfm_Cool_Load_Lat = q_bal_Lat + (icfm_Cooling**2 + q_unb**2)**0.5

    cfm_Dehumid_Load_Sens = q_bal_Sens + (icfm_Dehumid**2 + q_unb**2)**0.5
    cfm_Dehumid_Load_Lat = q_bal_Lat + (icfm_Dehumid**2 + q_unb**2)**0.5

    zone_loads.Heat_Infil = 1.1 * mj8.acf * cfm_Heating * htd

    zone_loads.Cool_Infil_Sens = 1.1 * mj8.acf * cfm_Cool_Load_Sens * mj8.ctd
    zone_loads.Cool_Infil_Lat = 0.68 * mj8.acf * cfm_Cool_Load_Lat * (mj8.cool_design_grains - mj8.grains_indoor_cooling)

    zone_loads.Dehumid_Infil_Sens = 1.1 * mj8.acf * cfm_Dehumid_Load_Sens * mj8.dtd
    zone_loads.Dehumid_Infil_Lat = 0.68 * mj8.acf * cfm_Dehumid_Load_Lat * (mj8.dehum_design_grains - mj8.grains_indoor_dehumid)

    return zone_loads
  end

  def self.process_internal_gains(runner, mj8, thermal_zone, zone_loads, nbeds, unit_ffa)
    '''
    Cooling and Dehumidification Loads: Internal Gains
    '''

    return if mj8.nil?

    zone_ffa = Geometry.get_finished_floor_area_from_spaces(thermal_zone.spaces)
    zone_frac = zone_ffa / unit_ffa

    # Per ANSI/RESNET/ICC 301
    n_occupants = nbeds + 1
    zone_loads.Cool_IntGains_Sens = (1600.0 + 230.0 * n_occupants) * zone_frac
    zone_loads.Cool_IntGains_Lat = (200.0 * n_occupants) * zone_frac
    zone_loads.Dehumid_IntGains_Sens = zone_loads.Cool_IntGains_Sens
    zone_loads.Dehumid_IntGains_Lat = zone_loads.Cool_IntGains_Lat

    return zone_loads
  end

  def self.process_intermediate_total_loads(runner, mj8, zones_loads, weather, hvac)
    '''
    Intermediate Loads
    (total loads excluding ducts)
    '''

    return if mj8.nil? || zones_loads.nil?

    # TODO: Ideally this would require an iterative procedure.

    # TODO ASKJON: Ask about where max(0,foo) should be used below
    unit_init = UnitInitialValues.new
    unit_init.Heat_Load = 0
    unit_init.Cool_Load_Sens = 0
    unit_init.Cool_Load_Lat = 0
    unit_init.Dehumid_Load_Sens = 0
    unit_init.Dehumid_Load_Lat = 0
    zones_loads.keys.each do |thermal_zone|
      zone_loads = zones_loads[thermal_zone]

      # Heating
      unit_init.Heat_Load += [zone_loads.Heat_Windows + zone_loads.Heat_Skylights +
        zone_loads.Heat_Doors + zone_loads.Heat_Walls +
        zone_loads.Heat_Floors + zone_loads.Heat_Roofs, 0].max +
                             zone_loads.Heat_Infil
      # Cooling
      unit_init.Cool_Load_Sens += zone_loads.Cool_Windows + zone_loads.Cool_Skylights +
                                  zone_loads.Cool_Doors + zone_loads.Cool_Walls +
                                  zone_loads.Cool_Floors + zone_loads.Cool_Roofs +
                                  zone_loads.Cool_Infil_Sens + zone_loads.Cool_IntGains_Sens
      unit_init.Cool_Load_Lat += zone_loads.Cool_Infil_Lat + zone_loads.Cool_IntGains_Lat

      # Dehumidification
      unit_init.Dehumid_Load_Sens += zone_loads.Dehumid_Windows + zone_loads.Dehumid_Skylights +
                                     zone_loads.Dehumid_Doors + zone_loads.Dehumid_Walls +
                                     zone_loads.Dehumid_Floors + zone_loads.Dehumid_Roofs +
                                     zone_loads.Dehumid_Infil_Sens + zone_loads.Dehumid_IntGains_Sens
      unit_init.Dehumid_Load_Lat += zone_loads.Dehumid_Infil_Lat + zone_loads.Dehumid_IntGains_Lat
    end

    unit_init.Cool_Load_Lat = [unit_init.Cool_Load_Lat, 0].max

    unit_init.Cool_Load_Tot = unit_init.Cool_Load_Sens + unit_init.Cool_Load_Lat
    shr = [unit_init.Cool_Load_Sens / unit_init.Cool_Load_Tot, 1.0].min

    # Determine the Leaving Air Temperature (LAT) based on Manual S Table 1-4
    if shr < 0.80
      unit_init.LAT = 54
    elsif shr < 0.85
      # MJ8 says to use 56 degF in this SHR range. Linear interpolation provides a more
      # continuous supply air flow rate across building efficiency levels.
      unit_init.LAT = ((58 - 54) / (0.85 - 0.80)) * (shr - 0.8) + 54
    else
      unit_init.LAT = 58
    end

    if hvac.HtgSupplyAirTemp.nil?
      if hvac.HasFurnace
        hvac.HtgSupplyAirTemp = 120 # F
      else
        hvac.HtgSupplyAirTemp = 105 # F
      end
    end

    unit_init.Cool_Airflow = unit_init.Cool_Load_Sens / (1.1 * mj8.acf * (mj8.cool_setpoint - unit_init.LAT))
    if hvac.HasDuctedHeating
      unit_init.Heat_Airflow = calc_heat_cfm(unit_init.Heat_Load, mj8.acf, mj8.heat_setpoint, hvac.HtgSupplyAirTemp)
    else
      unit_init.Heat_Airflow = 0
    end

    return unit_init
  end

  def self.process_unit_loads_and_equipment(runner, mj8, unit, zones_loads, unit_init, weather, hvac, ducts, nbeds, unit_ffa, unit_shelter_class)
    # TODO: Combine process_duct_loads_cool_dehum with process_duct_loads_heating? Some duplicate code
    unit_final = UnitFinalValues.new
    unit_final = process_duct_regain_factors(runner, unit, unit_final, ducts)
    unit_final = process_duct_loads_heating(runner, mj8, unit_final, weather, hvac, unit_init.Heat_Load, ducts)
    unit_init, unit_final = process_duct_loads_cool_dehum(runner, mj8, unit, zones_loads, unit_init, unit_final, weather, hvac, ducts)
    unit_final = process_cooling_equipment_adjustments(runner, mj8, unit, unit_init, unit_final, weather, hvac)
    unit_final = process_slave_zone_flow_ratios(runner, zones_loads, ducts, unit_final)
    unit_final = process_fixed_equipment(runner, unit_final, hvac)
    unit_final = process_finalize(runner, mj8, unit, zones_loads, unit_init, unit_final, weather, hvac, ducts, nbeds, unit_ffa, unit_shelter_class)
    unit_final = process_efficiency_capacity_derate(runner, hvac, unit_final)
    unit_final = process_dehumidifier_sizing(runner, mj8, unit_init, unit_final, weather, hvac)
    return unit_init, unit_final
  end

  def self.process_duct_regain_factors(runner, unit, unit_final, ducts)
    return if unit_final.nil?

    unit_final.dse_Fregain = nil

    # Distribution system efficiency (DSE) calculations based on ASHRAE Standard 152
    if ducts.Has && ducts.NotInLiving
      # dse_Fregain values comes from MJ8 pg 204 and Walker (1998) "Technical background for default
      # values used for forced air systems in proposed ASHRAE Std. 152"

      if Geometry.is_unfinished_basement(ducts.LocationSpace) || Geometry.is_finished_basement(ducts.LocationSpace)

        walls_insulated, ceiling_insulated = get_foundation_walls_ceilings_insulated(runner, ducts.LocationSpace)
        return if walls_insulated.nil? || ceiling_insulated.nil?

        infiltration_cfm = get_feature(runner, ducts.LocationSpace.thermalZone.get, Constants.SizingInfoZoneInfiltrationCFM, 'double', false)
        infiltration_cfm = 0 if infiltration_cfm.nil?

        if not ceiling_insulated
          if not walls_insulated
            if infiltration_cfm == 0
              unit_final.dse_Fregain = 0.55 # Uninsulated ceiling, uninsulated walls, no infiltration
            else # infiltration_cfm > 0
              unit_final.dse_Fregain = 0.51 # Uninsulated ceiling, uninsulated walls, with infiltration
            end
          else # walls_insulated
            if infiltration_cfm == 0
              unit_final.dse_Fregain = 0.78 # Uninsulated ceiling, insulated walls, no infiltration
            else # infiltration_cfm > 0
              unit_final.dse_Fregain = 0.74 # Uninsulated ceiling, insulated walls, with infiltration
            end
          end
        else # ceiling_insulated
          if walls_insulated
            if infiltration_cfm == 0
              unit_final.dse_Fregain = 0.32 # Insulated ceiling, insulated walls, no infiltration
            else # infiltration_cfm > 0
              unit_final.dse_Fregain = 0.27 # Insulated ceiling, insulated walls, with infiltration
            end
          else # not walls_insulated
            unit_final.dse_Fregain = 0.06    # Insulated ceiling and uninsulated walls
          end
        end

      elsif Geometry.is_crawl(ducts.LocationSpace) || Geometry.is_pier_beam(ducts.LocationSpace)

        walls_insulated, ceiling_insulated = get_foundation_walls_ceilings_insulated(runner, ducts.LocationSpace)
        return if walls_insulated.nil? || ceiling_insulated.nil?

        infiltration_cfm = get_feature(runner, ducts.LocationSpace.thermalZone.get, Constants.SizingInfoZoneInfiltrationCFM, 'double', false)
        infiltration_cfm = 0 if infiltration_cfm.nil?

        if infiltration_cfm > 0
          if ceiling_insulated
            unit_final.dse_Fregain = 0.12    # Insulated ceiling and uninsulated walls
          else
            unit_final.dse_Fregain = 0.50    # Uninsulated ceiling and uninsulated walls
          end
        else # infiltration_cfm == 0
          if (not ceiling_insulated) && (not walls_insulated)
            unit_final.dse_Fregain = 0.60    # Uninsulated ceiling and uninsulated walls
          elsif ceiling_insulated && (not walls_insulated)
            unit_final.dse_Fregain = 0.16    # Insulated ceiling and uninsulated walls
          elsif (not ceiling_insulated) && walls_insulated
            unit_final.dse_Fregain = 0.76    # Uninsulated ceiling and insulated walls (not explicitly included in A152)
          else
            unit_final.dse_Fregain = 0.30    # Insulated ceiling and insulated walls (option currently not included in BEopt)
          end
        end

      elsif Geometry.is_unfinished_attic(ducts.LocationSpace)
        unit_final.dse_Fregain = 0.10 # This would likely be higher for unvented attics with roof insulation

      elsif Geometry.is_garage(ducts.LocationSpace)
        unit_final.dse_Fregain = 0.05

      elsif Geometry.is_living(ducts.LocationSpace) || Geometry.is_finished_attic(ducts.LocationSpace)
        unit_final.dse_Fregain = 1.0

      else
        runner.registerError("Unexpected duct location: #{ducts.LocationSpace.name}")
        return
      end
    end

    return unit_final
  end

  def self.process_duct_loads_heating(runner, mj8, unit_final, weather, hvac, heatingLoad, ducts)
    return if mj8.nil? || unit_final.nil?

    # Distribution system efficiency (DSE) calculations based on ASHRAE Standard 152
    if ducts.Has && ducts.NotInLiving && hvac.HasDuctedHeating
      dse_Tamb_heating = mj8.heat_design_temps[ducts.LocationSpace]
      unit_final.Heat_Load_Ducts = calc_heat_duct_load(ducts, mj8.acf, mj8.heat_setpoint, unit_final.dse_Fregain, heatingLoad, hvac.HtgSupplyAirTemp, dse_Tamb_heating)
      if Geometry.space_is_finished(ducts.LocationSpace)
        # Ducts in finished spaces shouldn't affect the total heating capacity
        unit_final.Heat_Load = heatingLoad
      else
        unit_final.Heat_Load = heatingLoad + unit_final.Heat_Load_Ducts
      end
    else
      unit_final.Heat_Load = heatingLoad
      unit_final.Heat_Load_Ducts = 0
    end

    return unit_final
  end

  def self.process_duct_loads_cool_dehum(runner, mj8, unit, zones_loads, unit_init, unit_final, weather, hvac, ducts)
    '''
    Duct Loads
    '''

    return if mj8.nil? || zones_loads.nil? || unit_init.nil? || unit_final.nil?

    # Distribution system efficiency (DSE) calculations based on ASHRAE Standard 152
    if ducts.Has && ducts.NotInLiving && hvac.HasDuctedCooling && (unit_init.Cool_Load_Sens > 0)

      dse_Tamb_cooling = mj8.cool_design_temps[ducts.LocationSpace]
      dse_Tamb_dehumid = mj8.dehum_design_temps[ducts.LocationSpace]

      # Calculate the air enthalpy in the return duct location for DSE calculations
      dse_h_Return_Cooling = (1.006 * UnitConversions.convert(dse_Tamb_cooling, 'F', 'C') + weather.design.CoolingHumidityRatio * (2501 + 1.86 * UnitConversions.convert(dse_Tamb_cooling, 'F', 'C'))) * UnitConversions.convert(1, 'kJ', 'Btu') * UnitConversions.convert(1, 'lbm', 'kg')

      # Supply and return duct surface areas located outside conditioned space
      dse_As = ducts.SupplySurfaceArea * ducts.LocationFrac
      dse_Ar = ducts.ReturnSurfaceArea

      iterate_Tattic = false
      if Geometry.is_unfinished_attic(ducts.LocationSpace)
        iterate_Tattic = true

        attic_UAs = get_space_ua_values(runner, ducts.LocationSpace, weather, unit)
        return if attic_UAs.nil?

        # Get area-weighted average roofing material absorptance
        roofAbsorptance = 0.0
        total_area = 0.0
        ducts.LocationSpace.surfaces.each do |surface|
          next if surface.surfaceType.downcase != 'roofceiling'

          surf_area = UnitConversions.convert(surface.netArea, 'm^2', 'ft^2')
          surf_abs = surface.construction.get.to_LayeredConstruction.get.getLayer(0).to_StandardOpaqueMaterial.get.solarAbsorptance
          roofAbsorptance += (surf_area * surf_abs)
          total_area += surf_area
        end
        roofAbsorptance /= total_area

        roofPitch = Geometry.get_roof_pitch(ducts.LocationSpace.surfaces)

        t_solair = calculate_t_solair(weather, roofAbsorptance, roofPitch) # Sol air temperature on outside of roof surface # 1)

        # Calculate starting attic temp (ignoring duct losses)
        unit_final.Cool_Load_Ducts_Sens = 0
        t_attic_iter = calculate_t_attic_iter(runner, attic_UAs, t_solair, mj8.cool_setpoint, unit_final.Cool_Load_Ducts_Sens)
        return if t_attic_iter.nil?

        dse_Tamb_cooling = t_attic_iter
      end

      # Initialize for the iteration
      delta = 1
      coolingLoad_Tot_Prev = unit_init.Cool_Load_Tot
      coolingLoad_Tot_Next = unit_init.Cool_Load_Tot
      unit_final.Cool_Load_Tot  = unit_init.Cool_Load_Tot
      unit_final.Cool_Load_Sens = unit_init.Cool_Load_Sens

      unit_final.Cool_Load_Lat, unit_final.Cool_Load_Sens = calculate_sensible_latent_split(mj8.cool_design_grains, mj8.grains_indoor_cooling, mj8.acf, ducts.ReturnLoss, coolingLoad_Tot_Next, unit_init.Cool_Load_Lat, unit_init.Cool_Airflow)

      for _iter in 1..50
        break if delta.abs <= 0.001

        coolingLoad_Tot_Prev = coolingLoad_Tot_Next

        unit_final.Cool_Load_Lat, unit_final.Cool_Load_Sens = calculate_sensible_latent_split(mj8.cool_design_grains, mj8.grains_indoor_cooling, mj8.acf, ducts.ReturnLoss, coolingLoad_Tot_Next, unit_init.Cool_Load_Lat, unit_init.Cool_Airflow)
        unit_final.Cool_Load_Tot = unit_final.Cool_Load_Lat + unit_final.Cool_Load_Sens

        # Calculate the new cooling air flow rate
        unit_init.Cool_Airflow = unit_final.Cool_Load_Sens / (1.1 * mj8.acf * (mj8.cool_setpoint - unit_init.LAT))

        unit_final.Cool_Load_Ducts_Sens = unit_final.Cool_Load_Sens - unit_init.Cool_Load_Sens
        unit_final.Cool_Load_Ducts_Tot = coolingLoad_Tot_Next - unit_init.Cool_Load_Tot

        dse_DEcorr_cooling, dse_dTe_cooling, unit_final.Cool_Load_Ducts_Sens = calc_dse_cooling(ducts, mj8.acf, mj8.enthalpy_indoor_cooling, unit_init.LAT, unit_init.Cool_Airflow, unit_final.Cool_Load_Sens, dse_Tamb_cooling, dse_As, dse_Ar, mj8.cool_setpoint, unit_final.dse_Fregain, unit_final.Cool_Load_Tot, dse_h_Return_Cooling)
        dse_precorrect = 1 - (unit_final.Cool_Load_Ducts_Sens / unit_final.Cool_Load_Sens)

        if iterate_Tattic # Iterate attic temperature based on duct losses
          delta_attic = 1

          for _iter_attic in 1..20
            break if delta_attic.abs <= 0.001

            t_attic_old = t_attic_iter
            t_attic_iter = calculate_t_attic_iter(runner, attic_UAs, t_solair, mj8.cool_setpoint, unit_final.Cool_Load_Ducts_Sens)
            return if t_attic_iter.nil?

            mj8.cool_design_temps[ducts.LocationSpace] = t_attic_iter

            # Calculate the change since the last iteration
            delta_attic = (t_attic_iter - t_attic_old) / t_attic_old

            # Calculate enthalpy in attic using new Tattic
            dse_h_Return_Cooling = (1.006 * UnitConversions.convert(t_attic_iter, 'F', 'C') + weather.design.CoolingHumidityRatio * (2501 + 1.86 * UnitConversions.convert(t_attic_iter, 'F', 'C'))) * UnitConversions.convert(1, 'kJ', 'Btu') * UnitConversions.convert(1, 'lbm', 'kg')

            # Calculate duct efficiency using new Tattic:
            dse_DEcorr_cooling, dse_dTe_cooling, unit_final.Cool_Load_Ducts_Sens = calc_dse_cooling(ducts, mj8.acf, mj8.enthalpy_indoor_cooling, unit_init.LAT, unit_init.Cool_Airflow, unit_final.Cool_Load_Sens, dse_Tamb_cooling, dse_As, dse_Ar, mj8.cool_setpoint, unit_final.dse_Fregain, unit_final.Cool_Load_Tot, dse_h_Return_Cooling)

            dse_precorrect = 1 - (unit_final.Cool_Load_Ducts_Sens / unit_final.Cool_Load_Sens)
          end

          dse_Tamb_cooling = t_attic_iter
          Geometry.get_thermal_zones_from_spaces(unit.spaces).each do |thermal_zone|
            next if not Geometry.zone_is_finished(thermal_zone)

            zones_loads[thermal_zone] = process_load_floors(runner, mj8, unit, thermal_zone, zones_loads[thermal_zone], weather, mj8.htd)
          end
          unit_init = process_intermediate_total_loads(runner, mj8, zones_loads, weather, hvac)

          # Calculate the increase in total cooling load due to ducts (conservatively to prevent overshoot)
          coolingLoad_Tot_Next = unit_init.Cool_Load_Tot + coolingLoad_Tot_Prev * (1 - dse_precorrect)

          # Calculate unmet zone load:
          delta = unit_init.Cool_Load_Tot - (unit_final.Cool_Load_Tot * dse_precorrect)
        else
          coolingLoad_Tot_Next = unit_init.Cool_Load_Tot / dse_DEcorr_cooling

          # Calculate the change since the last iteration
          delta = (coolingLoad_Tot_Next - coolingLoad_Tot_Prev) / coolingLoad_Tot_Prev
        end
      end # _iter

      # Calculate the air flow rate required for design conditions
      unit_final.Cool_Airflow = unit_final.Cool_Load_Sens / (1.1 * mj8.acf * (mj8.cool_setpoint - unit_init.LAT))

      # Dehumidification duct loads

      dse_Qs_Dehumid = ducts.SupplyLoss * unit_final.Cool_Airflow
      dse_Qr_Dehumid = ducts.ReturnLoss * unit_final.Cool_Airflow

      # Supply and return conduction functions, Bs and Br
      dse_Bs_dehumid = Math.exp((-1.0 * dse_As) / (60 * unit_final.Cool_Airflow * @inside_air_dens * Gas.Air.cp * ducts.SupplyRvalue))
      dse_Br_dehumid = Math.exp((-1.0 * dse_Ar) / (60 * unit_final.Cool_Airflow * @inside_air_dens * Gas.Air.cp * ducts.ReturnRvalue))

      dse_a_s_dehumid = (unit_final.Cool_Airflow - dse_Qs_Dehumid) / unit_final.Cool_Airflow
      dse_a_r_dehumid = (unit_final.Cool_Airflow - dse_Qr_Dehumid) / unit_final.Cool_Airflow

      dse_dTe_dehumid = dse_dTe_cooling
      dse_dT_dehumid = mj8.cool_setpoint - dse_Tamb_dehumid

      # Calculate the delivery effectiveness (Equation 6-23)
      dse_DE_dehumid = dse_a_s_dehumid * dse_Bs_dehumid - dse_a_s_dehumid * dse_Bs_dehumid * \
                                                          (1 - dse_a_r_dehumid * dse_Br_dehumid) * (dse_dT_dehumid / dse_dTe_dehumid) - \
                       dse_a_s_dehumid * (1 - dse_Bs_dehumid) * (dse_dT_dehumid / dse_dTe_dehumid)

      # Calculate the delivery effectiveness corrector for regain (Equation 6-40)
      dse_DEcorr_dehumid = dse_DE_dehumid + unit_final.dse_Fregain * (1 - dse_DE_dehumid) + dse_Br_dehumid * \
                                                                                            (dse_a_r_dehumid * unit_final.dse_Fregain - unit_final.dse_Fregain) * (dse_dT_dehumid / dse_dTe_dehumid)

      # Limit the DE to a reasonable value to prevent negative values and huge equipment
      dse_DEcorr_dehumid = [dse_DEcorr_dehumid, 0.25].max

      # Calculate the increase in sensible dehumidification load due to ducts
      unit_final.Dehumid_Load_Sens = unit_init.Dehumid_Load_Sens / dse_DEcorr_dehumid

      # Calculate the latent duct leakage load (Manual J accounts only for return duct leakage)
      unit_final.Dehumid_Load_Ducts_Lat = 0.68 * mj8.acf * dse_Qr_Dehumid * (mj8.dehum_design_grains - mj8.grains_indoor_dehumid)

    else
      unit_final.Cool_Load_Lat = unit_init.Cool_Load_Lat
      unit_final.Cool_Load_Sens = unit_init.Cool_Load_Sens
      unit_final.Cool_Load_Tot = unit_final.Cool_Load_Sens + unit_final.Cool_Load_Lat

      unit_final.Cool_Load_Ducts_Sens = 0
      unit_final.Cool_Load_Ducts_Tot = 0

      unit_final.Dehumid_Load_Sens = unit_init.Dehumid_Load_Sens
      unit_final.Dehumid_Load_Ducts_Lat = 0

      # Calculate the air flow rate required for design conditions
      unit_final.Cool_Airflow = unit_final.Cool_Load_Sens / (1.1 * mj8.acf * (mj8.cool_setpoint - unit_init.LAT))
    end

    unit_final.Cool_Load_Ducts_Lat = unit_final.Cool_Load_Ducts_Tot - unit_final.Cool_Load_Ducts_Sens

    return unit_init, unit_final
  end

  def self.process_cooling_equipment_adjustments(runner, mj8, unit, unit_init, unit_final, weather, hvac)
    '''
    Equipment Adjustments
    '''

    return if mj8.nil? || unit_final.nil?

    underSizeLimit = 0.9

    if hvac.HasCooling

      if unit_final.Cool_Load_Tot < 0
        unit_final.Cool_Capacity = @minCoolingCapacity
        unit_final.Cool_Capacity_Sens = 0.78 * @minCoolingCapacity
        unit_final.Cool_Airflow = 400.0 * UnitConversions.convert(@minCoolingCapacity, 'Btu/hr', 'ton')
        return unit_final
      end

      # Adjust the total cooling capacity to the rated conditions using performance curves
      if not hvac.HasGroundSourceHeatPump
        enteringTemp = weather.design.CoolingDrybulb
      else
        enteringTemp = hvac.HXCHWDesign
      end

      if hvac.HasCentralAirConditioner || hvac.HasAirSourceHeatPump

        if hvac.NumSpeedsCooling > 1
          sizingSpeed = hvac.NumSpeedsCooling # Default
          sizingSpeed_Test = 10 # Initialize
          for speed in 0..(hvac.NumSpeedsCooling - 1)
            # Select curves for sizing using the speed with the capacity ratio closest to 1
            temp = (hvac.CapacityRatioCooling[speed] - 1).abs
            if temp <= sizingSpeed_Test
              sizingSpeed = speed
              sizingSpeed_Test = temp
            end
          end
          coefficients = hvac.COOL_CAP_FT_SPEC[sizingSpeed]
        else
          coefficients = hvac.COOL_CAP_FT_SPEC[0]
        end

        unit_final.TotalCap_CurveValue = MathTools.biquadratic(mj8.wetbulb_indoor_cooling, enteringTemp, coefficients)
        coolCap_Rated = unit_final.Cool_Load_Tot / unit_final.TotalCap_CurveValue
        if hvac.NumSpeedsCooling > 1
          sHR_Rated_Equip = hvac.SHRRated[sizingSpeed]
        else
          sHR_Rated_Equip = hvac.SHRRated[0]
        end

        sensCap_Rated = coolCap_Rated * sHR_Rated_Equip

        unit_final.SensibleCap_CurveValue = process_curve_fit(unit_final.Cool_Airflow, unit_final.Cool_Load_Tot, enteringTemp)
        sensCap_Design = sensCap_Rated * unit_final.SensibleCap_CurveValue
        latCap_Design = [unit_final.Cool_Load_Tot - sensCap_Design, 1].max

        a_sens = @shr_biquadratic[0]
        b_sens = @shr_biquadratic[1]
        c_sens = @shr_biquadratic[3]
        d_sens = @shr_biquadratic[5]

        # Adjust Sizing
        if latCap_Design < unit_final.Cool_Load_Lat
          # Size by MJ8 Latent load, return to rated conditions

          # Solve for the new sensible and total capacity at design conditions:
          # CoolingLoad_Lat = cool_Capacity_Design - cool_Load_SensCap_Design
          # solve the following for cool_Capacity_Design: SensCap_Design = SHRRated * cool_Capacity_Design / TotalCap_CurveValue * function(CFM/cool_Capacity_Design, ODB)
          # substituting in CFM = cool_Load_SensCap_Design / (1.1 * ACF * (cool_setpoint - LAT))

          cool_Load_SensCap_Design = unit_final.Cool_Load_Lat / ((unit_final.TotalCap_CurveValue / sHR_Rated_Equip - \
                                    (UnitConversions.convert(b_sens, 'ton', 'Btu/hr') + UnitConversions.convert(d_sens, 'ton', 'Btu/hr') * enteringTemp) / \
                                    (1.1 * mj8.acf * (mj8.cool_setpoint - unit_init.LAT))) / \
                                    (a_sens + c_sens * enteringTemp) - 1)

          cool_Capacity_Design = cool_Load_SensCap_Design + unit_final.Cool_Load_Lat

          # The SHR of the equipment at the design condition
          sHR_design = cool_Load_SensCap_Design / cool_Capacity_Design

          # If the adjusted equipment size is negative (occurs at altitude), oversize by 15% (the adjustment
          # almost always hits the oversize limit in this case, making this a safe assumption)
          if (cool_Capacity_Design < 0) || (cool_Load_SensCap_Design < 0)
            cool_Capacity_Design = hvac.OverSizeLimit * unit_final.Cool_Load_Tot
          end

          # Limit total capacity to oversize limit
          cool_Capacity_Design = [cool_Capacity_Design, hvac.OverSizeLimit * unit_final.Cool_Load_Tot].min

          # Determine the final sensible capacity at design using the SHR
          cool_Load_SensCap_Design = sHR_design * cool_Capacity_Design

          # Calculate the final air flow rate using final sensible capacity at design
          unit_final.Cool_Airflow = cool_Load_SensCap_Design / (1.1 * mj8.acf * \
                                 (mj8.cool_setpoint - unit_init.LAT))

          # Determine rated capacities
          unit_final.Cool_Capacity = cool_Capacity_Design / unit_final.TotalCap_CurveValue
          unit_final.Cool_Capacity_Sens = unit_final.Cool_Capacity * sHR_Rated_Equip

        elsif sensCap_Design < underSizeLimit * unit_final.Cool_Load_Sens
          # Size by MJ8 Sensible load, return to rated conditions, find Sens with SHRRated. Limit total
          # capacity to oversizing limit

          sensCap_Design = underSizeLimit * unit_final.Cool_Load_Sens

          # Solve for the new total system capacity at design conditions:
          # SensCap_Design   = SensCap_Rated * SensibleCap_CurveValue
          #                  = SHRRated * cool_Capacity_Design / TotalCap_CurveValue * SensibleCap_CurveValue
          #                  = SHRRated * cool_Capacity_Design / TotalCap_CurveValue * function(CFM/cool_Capacity_Design, ODB)

          cool_Capacity_Design = (sensCap_Design / (sHR_Rated_Equip / unit_final.TotalCap_CurveValue) - \
                                             (b_sens * UnitConversions.convert(unit_final.Cool_Airflow, 'ton', 'Btu/hr') + \
                                             d_sens * UnitConversions.convert(unit_final.Cool_Airflow, 'ton', 'Btu/hr') * enteringTemp)) / \
                                 (a_sens + c_sens * enteringTemp)

          # Limit total capacity to oversize limit
          cool_Capacity_Design = [cool_Capacity_Design, hvac.OverSizeLimit * unit_final.Cool_Load_Tot].min

          unit_final.Cool_Capacity = cool_Capacity_Design / unit_final.TotalCap_CurveValue
          unit_final.Cool_Capacity_Sens = unit_final.Cool_Capacity * sHR_Rated_Equip

          # Recalculate the air flow rate in case the oversizing limit has been used
          cool_Load_SensCap_Design = unit_final.Cool_Capacity_Sens * unit_final.SensibleCap_CurveValue
          unit_final.Cool_Airflow = cool_Load_SensCap_Design / (1.1 * mj8.acf * (mj8.cool_setpoint - unit_init.LAT))

        else
          unit_final.Cool_Capacity = unit_final.Cool_Load_Tot / unit_final.TotalCap_CurveValue
          unit_final.Cool_Capacity_Sens = unit_final.Cool_Capacity * sHR_Rated_Equip

          cool_Load_SensCap_Design = unit_final.Cool_Capacity_Sens * unit_final.SensibleCap_CurveValue
          unit_final.Cool_Airflow = cool_Load_SensCap_Design / (1.1 * mj8.acf * (mj8.cool_setpoint - unit_init.LAT))

        end

        # Ensure the air flow rate is in between 200 and 500 cfm/ton.
        # Reset the air flow rate (with a safety margin), if required.
        if unit_final.Cool_Airflow / UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton') > 500
          unit_final.Cool_Airflow = 499 * UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton')      # CFM
        elsif unit_final.Cool_Airflow / UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton') < 200
          unit_final.Cool_Airflow = 201 * UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton')      # CFM
        end

      elsif hvac.HasMiniSplitHeatPump

        sizingSpeed = hvac.NumSpeedsCooling # Default
        sizingSpeed_Test = 10 # Initialize
        for speed in 0..(hvac.NumSpeedsCooling - 1)
          # Select curves for sizing using the speed with the capacity ratio closest to 1
          temp = (hvac.CapacityRatioCooling[speed] - 1).abs
          if temp <= sizingSpeed_Test
            sizingSpeed = speed
            sizingSpeed_Test = temp
          end
        end
        coefficients = hvac.COOL_CAP_FT_SPEC[sizingSpeed]

        unit_final.TotalCap_CurveValue = MathTools.biquadratic(mj8.wetbulb_indoor_cooling, enteringTemp, coefficients)

        unit_final.Cool_Capacity = (unit_final.Cool_Load_Tot / unit_final.TotalCap_CurveValue)
        unit_final.Cool_Capacity_Sens = unit_final.Cool_Capacity * hvac.SHRRated[sizingSpeed]
        unit_final.Cool_Airflow = hvac.CoolingCFMs[-1] * UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton')

      elsif hvac.HasRoomAirConditioner

        unit_final.TotalCap_CurveValue = MathTools.biquadratic(mj8.wetbulb_indoor_cooling, enteringTemp, hvac.COOL_CAP_FT_SPEC[0])

        unit_final.Cool_Capacity = unit_final.Cool_Load_Tot / unit_final.TotalCap_CurveValue
        unit_final.Cool_Capacity_Sens = unit_final.Cool_Capacity * hvac.SHRRated[0]
        unit_final.Cool_Airflow = hvac.CoolingCFMs[0] * UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton')

      elsif hvac.HasGroundSourceHeatPump

        # Single speed as current
        unit_final.TotalCap_CurveValue = MathTools.biquadratic(mj8.wetbulb_indoor_cooling, enteringTemp, hvac.COOL_CAP_FT_SPEC[0])
        unit_final.SensibleCap_CurveValue = MathTools.biquadratic(mj8.wetbulb_indoor_cooling, enteringTemp, hvac.COOL_SH_FT_SPEC[0])
        unit_final.BypassFactor_CurveValue = MathTools.biquadratic(mj8.wetbulb_indoor_cooling, mj8.cool_setpoint, hvac.COIL_BF_FT_SPEC[0])

        unit_final.Cool_Capacity = unit_final.Cool_Load_Tot / unit_final.TotalCap_CurveValue # Note: cool_Capacity_Design = unit_final.Cool_Load_Tot
        unit_final.Cool_Capacity_Sens = unit_final.Cool_Capacity * hvac.SHRRated[0]

        cool_Load_SensCap_Design = (unit_final.Cool_Capacity_Sens * unit_final.SensibleCap_CurveValue /
                                   (1 + (1 - hvac.CoilBF * unit_final.BypassFactor_CurveValue) *
                                   (80 - mj8.cool_setpoint) / (mj8.cool_setpoint - unit_init.LAT)))
        cool_Load_LatCap_Design = unit_final.Cool_Load_Tot - cool_Load_SensCap_Design

        # Adjust Sizing so that coil sensible at design >= CoolingLoad_MJ8_Sens, and coil latent at design >= CoolingLoad_MJ8_Lat, and equipment SHRRated is maintained.
        cool_Load_SensCap_Design = [cool_Load_SensCap_Design, unit_final.Cool_Load_Sens].max
        cool_Load_LatCap_Design = [cool_Load_LatCap_Design, unit_final.Cool_Load_Lat].max
        cool_Capacity_Design = cool_Load_SensCap_Design + cool_Load_LatCap_Design

        # Limit total capacity to 15% oversizing
        cool_Capacity_Design = [cool_Capacity_Design, hvac.OverSizeLimit * unit_final.Cool_Load_Tot].min
        unit_final.Cool_Capacity = cool_Capacity_Design / unit_final.TotalCap_CurveValue
        unit_final.Cool_Capacity_Sens = unit_final.Cool_Capacity * hvac.SHRRated[0]

        # Recalculate the air flow rate in case the 15% oversizing rule has been used
        cool_Load_SensCap_Design = (unit_final.Cool_Capacity_Sens * unit_final.SensibleCap_CurveValue /
                                   (1 + (1 - hvac.CoilBF * unit_final.BypassFactor_CurveValue) *
                                   (80 - mj8.cool_setpoint) / (mj8.cool_setpoint - unit_init.LAT)))
        unit_final.Cool_Airflow = (cool_Load_SensCap_Design / (1.1 * mj8.acf * (mj8.cool_setpoint - unit_init.LAT)))

      else

        runner.registerError('Unexpected cooling system.')
        return

      end

    else
      unit_final.Cool_Capacity = 0
      unit_final.Cool_Capacity_Sens = 0
      unit_final.Cool_Airflow = 0
    end
    return unit_final
  end

  def self.process_fixed_equipment(runner, unit_final, hvac)
    '''
    Fixed Sizing Equipment
    '''

    return if unit_final.nil?

    # Override Manual J sizes if Fixed sizes are being used
    if not hvac.FixedCoolingCapacity.nil?
      prev_capacity = unit_final.Cool_Capacity
      unit_final.Cool_Capacity = UnitConversions.convert(hvac.FixedCoolingCapacity, 'ton', 'Btu/hr')
      unit_final.Cool_Airflow = unit_final.Cool_Airflow * unit_final.Cool_Capacity / prev_capacity
    end
    if not hvac.FixedSuppHeatingCapacity.nil?
      unit_final.Heat_Load = UnitConversions.convert(hvac.FixedSuppHeatingCapacity, 'ton', 'Btu/hr')
    elsif not hvac.FixedHeatingCapacity.nil?
      unit_final.Heat_Load = UnitConversions.convert(hvac.FixedHeatingCapacity, 'ton', 'Btu/hr')
    end

    return unit_final
  end

  def self.process_finalize(runner, mj8, unit, zones_loads, unit_init, unit_final, weather, hvac, ducts, nbeds, unit_ffa, unit_shelter_class)
    '''
    Finalize Sizing Calculations
    '''

    return if mj8.nil? || unit_final.nil? || unit_init.nil?

    unit_final.Heat_Capacity_Supp = 0

    if hvac.HasFurnace
      unit_final.Heat_Capacity = unit_final.Heat_Load
      unit_final.Heat_Airflow = calc_heat_cfm(unit_final.Heat_Capacity, mj8.acf, mj8.heat_setpoint, hvac.HtgSupplyAirTemp)

    elsif hvac.HasUnitHeater
      unit_final.Heat_Capacity = unit_final.Heat_Load

      if hvac.RatedCFMperTonHeating[0] > 0
        # Fixed airflow rate
        unit_final.Heat_Airflow = UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'ton') * hvac.RatedCFMperTonHeating[0]
      else
        # Autosized airflow rate
        unit_final.Heat_Airflow = calc_heat_cfm(unit_final.Heat_Capacity, mj8.acf, mj8.heat_setpoint, hvac.HtgSupplyAirTemp)
      end

    elsif hvac.HasAirSourceHeatPump

      if hvac.FixedCoolingCapacity.nil?
        unit_final = process_heat_pump_adjustment(runner, mj8, unit, unit_final, weather, hvac, ducts, nbeds, unit_ffa, unit_shelter_class)
        return if unit_final.nil?
      end

      unit_final.Heat_Capacity = unit_final.Cool_Capacity
      unit_final.Heat_Capacity_Supp = unit_final.Heat_Load

      if unit_final.Cool_Capacity > @minCoolingCapacity
        unit_final.Heat_Airflow = unit_final.Heat_Capacity / (1.1 * mj8.acf * (hvac.HtgSupplyAirTemp - mj8.heat_setpoint))
      else
        unit_final.Heat_Airflow = unit_final.Heat_Capacity_Supp / (1.1 * mj8.acf * (hvac.HtgSupplyAirTemp - mj8.heat_setpoint))
      end

    elsif hvac.HasMiniSplitHeatPump

      if hvac.FixedCoolingCapacity.nil?
        unit_final = process_heat_pump_adjustment(runner, mj8, unit, unit_final, weather, hvac, ducts, nbeds, unit_ffa, unit_shelter_class)
        return if unit_final.nil?
      end

      unit_final.Heat_Capacity = unit_final.Cool_Capacity + hvac.HeatingCapacityOffset
      unit_final.Heat_Capacity_Supp = unit_final.Heat_Load

      unit_final.Heat_Airflow = hvac.HeatingCFMs[-1] * UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'ton') # Maximum air flow under heating operation

    elsif hvac.HasBoiler || hvac.HasElecBaseboard
      unit_final.Heat_Airflow = 0
      unit_final.Heat_Capacity = unit_final.Heat_Load

    elsif hvac.HasGroundSourceHeatPump

      if hvac.FixedCoolingCapacity.nil?
        unit_final.Heat_Capacity = unit_final.Heat_Load
      else
        unit_final.Heat_Capacity = unit_final.Cool_Capacity
      end
      unit_final.Heat_Capacity_Supp = unit_final.Heat_Load

      # For single stage compressor, when heating capacity is much larger than cooling capacity,
      # in order to avoid frequent cycling in cooling mode, heating capacity is derated to 75%.
      if unit_final.Heat_Capacity >= 1.5 * unit_final.Cool_Capacity
        unit_final.Heat_Capacity = unit_final.Heat_Load * 0.75
      elsif unit_final.Heat_Capacity < unit_final.Cool_Capacity
        unit_final.Heat_Capacity_Supp = unit_final.Heat_Capacity
      end

      ground_conductivity = UnitConversions.convert(hvac.GroundHXVertical.groundThermalConductivity.get, 'W/(m*K)', 'Btu/(hr*ft*R)')
      grout_conductivity = UnitConversions.convert(hvac.GroundHXVertical.groutThermalConductivity.get, 'W/(m*K)', 'Btu/(hr*ft*R)')
      bore_diameter = UnitConversions.convert(hvac.GroundHXVertical.boreHoleRadius.get * 2.0, 'm', 'in')
      pipe_od = UnitConversions.convert(hvac.GroundHXVertical.pipeOutDiameter.get, 'm', 'in')
      pipe_id = pipe_od - UnitConversions.convert(hvac.GroundHXVertical.pipeThickness.get * 2.0, 'm', 'in')
      pipe_cond = UnitConversions.convert(hvac.GroundHXVertical.pipeThermalConductivity.get, 'W/(m*K)', 'Btu/(hr*ft*R)')
      pipe_r_value = gshp_hx_pipe_rvalue(pipe_od, pipe_id, pipe_cond)

      # Autosize ground loop heat exchanger length
      nom_length_heat, nom_length_cool = gshp_hxbore_ft_per_ton(weather, mj8.htd, mj8.ctd, hvac.GSHPBoreSpacing, ground_conductivity, hvac.GSHPSpacingType, grout_conductivity, bore_diameter, pipe_od, pipe_r_value, hvac.HeatingEIR, hvac.CoolingEIR, hvac.HXCHWDesign, hvac.HXHWDesign, hvac.HXDTDesign)

      bore_length_heat = nom_length_heat * unit_final.Heat_Capacity / UnitConversions.convert(1.0, 'ton', 'Btu/hr')
      bore_length_cool = nom_length_cool * unit_final.Cool_Capacity / UnitConversions.convert(1.0, 'ton', 'Btu/hr')
      bore_length = [bore_length_heat, bore_length_cool].max

      # Degree day calculation for balance temperature
      intGains_Sens = 0
      zones_loads.each do |thermal_zone, zone_loads|
        intGains_Sens += zone_loads.Cool_IntGains_Sens
      end
      bLC_Heat = unit_init.Heat_Load / mj8.htd
      bLC_Cool = unit_init.Cool_Load_Sens / mj8.ctd
      t_Ref_Bal = mj8.heat_setpoint - intGains_Sens / bLC_Heat
      hDD_Ref_Bal = [weather.data.HDD65F, [weather.data.HDD50F, weather.data.HDD50F + (weather.data.HDD65F - weather.data.HDD50F) / (65 - 50) * (t_Ref_Bal - 50)].max].min
      cDD_Ref_Bal = [weather.data.CDD50F, [weather.data.CDD65F, weather.data.CDD50F + (weather.data.CDD65F - weather.data.CDD50F) / (65 - 50) * (t_Ref_Bal - 50)].max].min
      aNNL_Grnd_Cool = (1 + hvac.CoolingEIR) * cDD_Ref_Bal * bLC_Cool * 24 * 0.6 # use 0.6 to account for average solar load
      aNNL_Grnd_Heat = (1 - hvac.HeatingEIR) * hDD_Ref_Bal * bLC_Heat * 24

      # Normalized net annual ground energy load
      nNAGL = [(aNNL_Grnd_Heat - aNNL_Grnd_Cool) / (weather.data.AnnualAvgDrybulb - (2 * hvac.HXHWDesign - hvac.HXDTDesign) / 2),
               (aNNL_Grnd_Cool - aNNL_Grnd_Heat) / ((2 * hvac.HXDTDesign + hvac.HXDTDesign) / 2 - weather.data.AnnualAvgDrybulb)].max / bore_length

      if (hvac.GSHPBoreSpacing > 15) && (hvac.GSHPBoreSpacing <= 20)
        bore_length_mult = 1.0 + nNAGL / 7000 * (0.55 / ground_conductivity)
      else
        bore_length_mult = 1.0 + nNAGL / 6700 * (1.00 / ground_conductivity)
      end

      bore_length *= bore_length_mult

      unit_final.Cool_Capacity = [unit_final.Cool_Capacity, unit_final.Heat_Capacity].max
      unit_final.Heat_Capacity = unit_final.Cool_Capacity
      unit_final.Cool_Capacity_Sens = unit_final.Cool_Capacity * hvac.SHRRated[0]
      cool_Load_SensCap_Design = (unit_final.Cool_Capacity_Sens * unit_final.SensibleCap_CurveValue /
                                 (1 + (1 - hvac.CoilBF * unit_final.BypassFactor_CurveValue) *
                                 (80 - mj8.cool_setpoint) / (mj8.cool_setpoint - unit_init.LAT)))
      unit_final.Cool_Airflow = (cool_Load_SensCap_Design / (1.1 * mj8.acf * (mj8.cool_setpoint - unit_init.LAT)))
      unit_final.Heat_Airflow = (unit_final.Heat_Capacity / (1.1 * mj8.acf * (hvac.HtgSupplyAirTemp - mj8.heat_setpoint)))

      loop_flow = [1.0, UnitConversions.convert([unit_final.Heat_Capacity, unit_final.Cool_Capacity].max, 'Btu/hr', 'ton')].max.floor * 3.0

      if (hvac.GSHPBoreHoles == Constants.SizingAuto) && (hvac.GSHPBoreDepth == Constants.SizingAuto)
        hvac.GSHPBoreHoles = [1, (UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton') + 0.5).floor].max
        hvac.GSHPBoreDepth = (bore_length / hvac.GSHPBoreHoles).floor
        min_bore_depth = 0.15 * hvac.GSHPBoreSpacing # 0.15 is the maximum Spacing2DepthRatio defined for the G-function

        (0..4).to_a.each do |tmp|
          if (hvac.GSHPBoreDepth < min_bore_depth) && (hvac.GSHPBoreHoles > 1)
            hvac.GSHPBoreHoles -= 1
            hvac.GSHPBoreDepth = (bore_length / hvac.GSHPBoreHoles).floor
          elsif hvac.GSHPBoreDepth > 345
            hvac.GSHPBoreHoles += 1
            hvac.GSHPBoreDepth = (bore_length / hvac.GSHPBoreHoles).floor
          end
        end

        hvac.GSHPBoreDepth = (bore_length / hvac.GSHPBoreHoles).floor + 5

      elsif (hvac.GSHPBoreHoles == Constants.SizingAuto) && (hvac.GSHPBoreDepth != Constants.SizingAuto)
        hvac.GSHPBoreHoles = (bore_length / hvac.GSHPBoreDepth.to_f + 0.5).floor
        hvac.GSHPBoreDepth = hvac.GSHPBoreDepth.to_f
      elsif (hvac.GSHPBoreHoles != Constants.SizingAuto) && (hvac.GSHPBoreDepth == Constants.SizingAuto)
        hvac.GSHPBoreHoles = hvac.GSHPBoreHoles.to_f
        hvac.GSHPBoreDepth = (bore_length / hvac.GSHPBoreHoles).floor + 5
      else
        runner.registerWarning('User is hard sizing the bore field, improper sizing may lead to unbalanced / unsteady ground loop temperature and erroneous prediction of system energy related cost.')
        hvac.GSHPBoreHoles = hvac.GSHPBoreHoles.to_f
        hvac.GSHPBoreDepth = hvac.GSHPBoreDepth.to_f
      end

      bore_length = hvac.GSHPBoreDepth * hvac.GSHPBoreHoles

      if hvac.GSHPBoreConfig == Constants.SizingAuto
        if hvac.GSHPBoreHoles == 1
          hvac.GSHPBoreConfig = Constants.BoreConfigSingle
        elsif hvac.GSHPBoreHoles == 2
          hvac.GSHPBoreConfig = Constants.BoreConfigLine
        elsif hvac.GSHPBoreHoles == 3
          hvac.GSHPBoreConfig = Constants.BoreConfigLine
        elsif hvac.GSHPBoreHoles == 4
          hvac.GSHPBoreConfig = Constants.BoreConfigRectangle
        elsif hvac.GSHPBoreHoles == 5
          hvac.GSHPBoreConfig = Constants.BoreConfigUconfig
        elsif hvac.GSHPBoreHoles > 5
          hvac.GSHPBoreConfig = Constants.BoreConfigLine
        end
      end

      # Test for valid GSHP bore field configurations
      valid_configs = { Constants.BoreConfigSingle => [1],
                        Constants.BoreConfigLine => [2, 3, 4, 5, 6, 7, 8, 9, 10],
                        Constants.BoreConfigLconfig => [3, 4, 5, 6],
                        Constants.BoreConfigRectangle => [2, 4, 6, 8],
                        Constants.BoreConfigUconfig => [5, 7, 9],
                        Constants.BoreConfigL2config => [8],
                        Constants.BoreConfigOpenRectangle => [8] }
      valid_num_bores = valid_configs[hvac.GSHPBoreConfig]
      max_valid_configs = { Constants.BoreConfigLine => 10, Constants.BoreConfigLconfig => 6 }
      unless valid_num_bores.include? hvac.GSHPBoreHoles
        # Any configuration with a max_valid_configs value can accept any number of bores up to the maximum
        if max_valid_configs.keys.include? hvac.GSHPBoreConfig
          max_bore_holes = max_valid_configs[hvac.GSHPBoreConfig]
          runner.registerWarning("Maximum number of bore holes for '#{hvac.GSHPBoreConfig}' bore configuration is #{max_bore_holes}. Overriding value of #{hvac.GSHPBoreHoles} bore holes to #{max_bore_holes}.")
          hvac.GSHPBoreHoles = max_bore_holes
        else
          # Search for first valid bore field
          new_bore_config = nil
          valid_field_found = false
          valid_configs.keys.each do |bore_config|
            next unless valid_configs[bore_config].include? hvac.GSHPBoreHoles

            valid_field_found = true
            new_bore_config = bore_config
            break
          end
          if valid_field_found
            runner.registerWarning("Bore field '#{hvac.GSHPBoreConfig}' with #{hvac.GSHPBoreHoles.to_i} bore holes is an invalid configuration. Changing layout to '#{new_bore_config}' configuration.")
            hvac.GSHPBoreConfig = new_bore_config
          else
            runner.registerError('Could not construct a valid GSHP bore field configuration.')
            return
          end
        end
      end

      spacing_to_depth_ratio = hvac.GSHPBoreSpacing / hvac.GSHPBoreDepth

      lntts = [-8.5, -7.8, -7.2, -6.5, -5.9, -5.2, -4.5, -3.963, -3.27, -2.864, -2.577, -2.171, -1.884, -1.191, -0.497, -0.274, -0.051, 0.196, 0.419, 0.642, 0.873, 1.112, 1.335, 1.679, 2.028, 2.275, 3.003]
      gfnc_coeff = gshp_gfnc_coeff(hvac.GSHPBoreConfig, hvac.GSHPBoreHoles, spacing_to_depth_ratio)

      unit_final.GSHP_Loop_flow = loop_flow
      unit_final.GSHP_Bore_Depth = hvac.GSHPBoreDepth
      unit_final.GSHP_Bore_Holes = hvac.GSHPBoreHoles
      unit_final.GSHP_G_Functions = [lntts, gfnc_coeff]

    else
      unit_final.Heat_Capacity = 0
      unit_final.Heat_Airflow = 0
    end

    return unit_final
  end

  def self.process_heat_pump_adjustment(runner, mj8, unit, unit_final, weather, hvac, ducts, nbeds, unit_ffa, unit_shelter_class)
    '''
    Adjust heat pump sizing
    '''
    return if unit_final.nil?

    if hvac.NumSpeedsHeating > 1
      coefficients = hvac.HEAT_CAP_FT_SPEC[hvac.NumSpeedsHeating - 1]
      capacity_ratio = hvac.CapacityRatioHeating[hvac.NumSpeedsHeating - 1]
    else
      coefficients = hvac.HEAT_CAP_FT_SPEC[0]
      capacity_ratio = 1.0
    end

    if hvac.MinOutdoorTemp < weather.design.HeatingDrybulb
      heat_db = weather.design.HeatingDrybulb
      heat_pump_load = unit_final.Heat_Load
    else

      # Calculate the heating load at the minimum compressor temperature to limit unutilized capacity
      heat_db = hvac.MinOutdoorTemp
      htd = mj8.heat_setpoint - heat_db

      # Update the buffer space temperatures for the minimum
      (unit.spaces + Geometry.get_unit_adjacent_common_spaces(unit)).each do |space|
        if not Geometry.space_is_finished(space)
          mj8.heat_design_temps[space] = process_design_temp_heating(runner, mj8, weather, space, heat_db, unit)
        end

        # Calculate the cooling design temperature for the unfinished attic based on Figure A12-14
        next unless Geometry.is_unfinished_attic(space)

        attic_floor_r = get_space_r_value(runner, space, 'floor', true)
        return nil if attic_floor_r.nil?

        attic_roof_r = get_space_r_value(runner, space, 'roofceiling', true)
        return nil if attic_roof_r.nil?

        if attic_floor_r > attic_roof_r
          mj8.heat_design_temps[space] = heat_db
        end
      end

      # Calculate heating loads at the minimum compressor temperature
      min_temp_zones_loads = process_zone_loads(runner, mj8, unit, weather, htd, nbeds, unit_ffa, unit_shelter_class)
      return if min_temp_zones_loads.nil?

      min_temp_unit_init = process_intermediate_total_loads(runner, mj8, min_temp_zones_loads, weather, hvac)
      return if min_temp_unit_init.nil?

      # TODO: Combine with code in process_duct_loads_heating
      if ducts.Has && ducts.NotInLiving
        if not Geometry.is_unfinished_basement(ducts.LocationSpace)
          dse_Tamb_heating = mj8.heat_design_temps[ducts.LocationSpace]
          duct_load_heating = calc_heat_duct_load(ducts, mj8.acf, mj8.heat_setpoint, unit_final.dse_Fregain, min_temp_unit_init.Heat_Load, hvac.HtgSupplyAirTemp, dse_Tamb_heating)
        else
          # Ducts in the finished basement does not impact equipment capacity
          duct_load_heating = 0
        end
      else
        duct_load_heating = 0
      end

      heat_pump_load = min_temp_unit_init.Heat_Load + duct_load_heating
    end

    heatCap_Rated = (heat_pump_load / MathTools.biquadratic(mj8.heat_setpoint, heat_db, coefficients)) / capacity_ratio

    if heatCap_Rated < unit_final.Cool_Capacity
      if hvac.HasAirSourceHeatPump
        unit_final.Heat_Capacity = unit_final.Cool_Capacity
      elsif hvac.HasMiniSplitHeatPump
        unit_final.Heat_Capacity = unit_final.Cool_Capacity + hvac.HeatingCapacityOffset
      end
    else
      if hvac.HPSizedForMaxLoad
        # Auto size the heat pump heating capacity based on the heating design temperature (if the heating capacity is larger than the cooling capacity)
        unit_final.Heat_Capacity = heatCap_Rated
        if hvac.HasAirSourceHeatPump
          cfm_Btu = unit_final.Cool_Airflow / unit_final.Cool_Capacity
          unit_final.Cool_Capacity = unit_final.Heat_Capacity
          unit_final.Cool_Airflow = cfm_Btu * unit_final.Cool_Capacity
        elsif hvac.HasMiniSplitHeatPump
          unit_final.Cool_Capacity = unit_final.Heat_Capacity - hvac.HeatingCapacityOffset
          unit_final.Cool_Airflow = hvac.CoolingCFMs[-1] * UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton')
        end
      else
        cfm_Btu = unit_final.Cool_Airflow / unit_final.Cool_Capacity
        load_shr = unit_final.Cool_Load_Sens / unit_final.Cool_Load_Tot
        if ((weather.data.HDD65F / weather.data.CDD50F) < 2.0) || (load_shr < 0.95)
          # Mild winter or has a latent cooling load
          unit_final.Cool_Capacity = [(hvac.OverSizeLimit * unit_final.Cool_Load_Tot) / unit_final.TotalCap_CurveValue, heatCap_Rated].min
        else
          # Cold winter and no latent cooling load (add a ton rule applies)
          unit_final.Cool_Capacity = [(unit_final.Cool_Load_Tot + 15000) / unit_final.TotalCap_CurveValue, heatCap_Rated].min
        end
        if hvac.HasAirSourceHeatPump
          unit_final.Cool_Airflow = cfm_Btu * unit_final.Cool_Capacity
          unit_final.Heat_Capacity = unit_final.Cool_Capacity
        elsif hvac.HasMiniSplitHeatPump
          unit_final.Cool_Airflow = hvac.CoolingCFMs[-1] * UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton')
          unit_final.Heat_Capacity = unit_final.Cool_Capacity + hvac.HeatingCapacityOffset
        end
      end
    end

    return unit_final
  end

  def self.process_slave_zone_flow_ratios(runner, zones_loads, ducts, unit_final)
    '''
    Flow Ratios for Slave Zones
    '''

    return if unit_final.nil?

    zone_heat_loads = {}
    zones_loads.each do |thermal_zone, zone_loads|
      zone_heat_loads[thermal_zone] = [zone_loads.Heat_Windows + zone_loads.Heat_Skylights +
        zone_loads.Heat_Doors + zone_loads.Heat_Walls +
        zone_loads.Heat_Floors + zone_loads.Heat_Roofs, 0].max +
                                      zone_loads.Heat_Infil
      if !ducts.LocationSpace.nil? && thermal_zone.spaces.include?(ducts.LocationSpace)
        zone_heat_loads[thermal_zone] -= unit_final.Heat_Load_Ducts
      end
    end

    # Divide up flow rate to thermal zones based on MJ8 loads
    unit_final.Zone_Ratios = {}
    total = 0.0
    zones_loads.each do |thermal_zone, zone_loads|
      next if Geometry.is_living(thermal_zone)

      unit_final.Zone_Ratios[thermal_zone] = zone_heat_loads[thermal_zone] / unit_final.Heat_Load
      # Use a minimum flow ratio of 1%. (Low flow ratios can be calculated, e.g., for buildings
      # with inefficient above grade construction or poor ductwork in the finished basement.)
      unit_final.Zone_Ratios[thermal_zone] = [unit_final.Zone_Ratios[thermal_zone], 0.01].max
      total += unit_final.Zone_Ratios[thermal_zone]
    end

    zones_loads.each do |thermal_zone, zone_loads|
      next if not Geometry.is_living(thermal_zone)

      unit_final.Zone_Ratios[thermal_zone] = 1.0 - total
      total += unit_final.Zone_Ratios[thermal_zone]
    end

    if (total - 1.0).abs > 0.001
      s = ''
      unit_final.Zone_Ratios.each do |zone, flow_ratio|
        s += " #{zone.name}: #{flow_ratio.round(3)},"
      end
      runner.registerError("Zone flow ratios do not add up to one:#{s.chomp(',')}")
      return
    end

    return unit_final
  end

  def self.process_efficiency_capacity_derate(runner, hvac, unit_final)
    '''
    AC & HP Efficiency Capacity Derate
    '''

    return if unit_final.nil?

    # Initialize
    unit_final.EER_Multiplier = 1.0
    unit_final.COP_Multiplier = 1.0

    if (not hvac.HasCentralAirConditioner) && (not hvac.HasAirSourceHeatPump)
      return unit_final
    end

    tonnages = [1.5, 2, 3, 4, 5]

    # capacityDerateFactorEER values correspond to 1.5, 2, 3, 4, 5 ton equipment. Interpolate in between nominal sizes.
    tons = UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton')

    if tons <= 1.5
      unit_final.EER_Multiplier = hvac.CapacityDerateFactorEER[0]
    elsif tons <= 5
      index = (tons.floor - 1).to_i
      unit_final.EER_Multiplier = MathTools.interp2(tons, tonnages[index - 1], tonnages[index],
                                                    hvac.CapacityDerateFactorEER[index - 1],
                                                    hvac.CapacityDerateFactorEER[index])
    elsif tons <= 10
      index = ((tons / 2.0).floor - 1).to_i
      unit_final.EER_Multiplier = MathTools.interp2(tons / 2.0, tonnages[index - 1], tonnages[index],
                                                    hvac.CapacityDerateFactorEER[index - 1],
                                                    hvac.CapacityDerateFactorEER[index])
    else
      unit_final.EER_Multiplier = hvac.CapacityDerateFactorEER[-1]
    end

    if hvac.HasAirSourceHeatPump

      if tons <= 1.5
        unit_final.COP_Multiplier = hvac.CapacityDerateFactorCOP[0]
      elsif tons <= 5
        index = (tons.floor - 1).to_i
        unit_final.COP_Multiplier = MathTools.interp2(tons, tonnages[index - 1], tonnages[index],
                                                      hvac.CapacityDerateFactorCOP[index - 1],
                                                      hvac.CapacityDerateFactorCOP[index])
      elsif tons <= 10
        index = ((tons / 2.0).floor - 1).to_i
        unit_final.COP_Multiplier = MathTools.interp2(tons / 2.0, tonnages[index - 1], tonnages[index],
                                                      hvac.CapacityDerateFactorCOP[index - 1],
                                                      hvac.CapacityDerateFactorCOP[index])
      else
        unit_final.COP_Multiplier = hvac.CapacityDerateFactorCOP[-1]
      end

    end

    return unit_final
  end

  def self.process_dehumidifier_sizing(runner, mj8, unit_init, unit_final, weather, hvac)
    '''
    Dehumidifier Sizing
    '''

    return if mj8.nil? || unit_init.nil? || unit_final.nil?

    if hvac.HasCooling && (unit_final.Cool_Capacity > @minCoolingCapacity)

      dehum_design_db = weather.design.DehumidDrybulb

      if hvac.NumSpeedsCooling > 1

        if not hvac.HasMiniSplitHeatPump

          dehumid_AC_TotCap_i = []
          dehumid_AC_SensCap_i = []

          for i in 0..(hvac.NumSpeedsCooling - 1)

            totalCap_CurveValue_i = MathTools.biquadratic(mj8.wetbulb_indoor_dehumid, dehum_design_db, hvac.COOL_CAP_FT_SPEC[i])
            dehumid_AC_TotCap_i << (totalCap_CurveValue_i * unit_final.Cool_Capacity * hvac.CapacityRatioCooling[0])

            sensibleCap_CurveValue_i = process_curve_fit(unit_final.Cool_Airflow * hvac.FanspeedRatioCooling[0], dehumid_AC_TotCap_i[i], dehum_design_db)
            dehumid_AC_SensCap_i << (sensibleCap_CurveValue_i * unit_final.Cool_Capacity_Sens * hvac.CapacityRatioCooling[0])

            next unless (dehumid_AC_SensCap_i[i] > unit_final.Dehumid_Load_Sens) || (i == hvac.NumSpeedsCooling - 1)

            if i > 0
              dehumid_AC_SensCap = unit_final.Dehumid_Load_Sens

              # Determine portion of load met by speed i and i-1 using: Q_i*s + Q_i-1*(s-1) = Q_load
              s = (unit_final.Dehumid_Load_Sens + dehumid_AC_SensCap_i[i - 1]) / (dehumid_AC_SensCap_i[i] + dehumid_AC_SensCap_i[i - 1])

              dehumid_AC_LatCap = s * (1 - hvac.SHRRated[i]) * dehumid_AC_TotCap_i[i] + \
                                  (1 - s) * (1 - hvac.SHRRated[i - 1]) * dehumid_AC_TotCap_i[i - 1]

              dehumid_AC_RTF = 1
            else
              # System is cycling because the sensible load is less than the sensible capacity at the minimum speed
              dehumid_AC_SensCap = dehumid_AC_SensCap_i[0]
              dehumid_AC_LatCap = dehumid_AC_TotCap_i[0] - dehumid_AC_SensCap_i[0]
              dehumid_AC_RTF = [0, unit_final.Dehumid_Load_Sens / dehumid_AC_SensCap].max
            end

            break

          end

        else # MSHP

          dehumid_AC_TotCap_i_1 = 0
          for i in 0..(hvac.NumSpeedsCooling - 1)

            totalCap_CurveValue = MathTools.biquadratic(mj8.wetbulb_indoor_dehumid, dehum_design_db, hvac.COOL_CAP_FT_SPEC[i])

            dehumid_AC_TotCap = totalCap_CurveValue * unit_final.Cool_Capacity * hvac.CapacityRatioCooling[i]
            sens_cap = hvac.SHRRated[i] * dehumid_AC_TotCap # TODO: This could be slightly improved by not assuming a constant SHR

            if (sens_cap >= unit_final.Dehumid_Load_Sens) || (i == hvac.NumSpeedsCooling - 1)

              if i > 0
                dehumid_AC_SensCap = unit_final.Dehumid_Load_Sens

                # Determine portion of load met by speed i and i-1 using: Q_i*s + Q_i-1*(s-1) = Q_load
                s = (unit_final.Dehumid_Load_Sens + dehumid_AC_TotCap_i_1 * hvac.SHRRated[i - 1]) / (sens_cap + dehumid_AC_TotCap_i_1 * hvac.SHRRated[i - 1])

                dehumid_AC_LatCap = s * (1 - hvac.SHRRated[i]) * dehumid_AC_TotCap + \
                                    (1 - s) * (1 - hvac.SHRRated[i - 1]) * dehumid_AC_TotCap_i_1

                dehumid_AC_RTF = 1
              else
                dehumid_AC_SensCap = sens_cap
                dehumid_AC_LatCap = dehumid_AC_TotCap - dehumid_AC_SensCap
                dehumid_AC_RTF = [0, unit_final.Dehumid_Load_Sens / dehumid_AC_SensCap].max
              end

              break

            end

            dehumid_AC_TotCap_i_1 = dehumid_AC_TotCap

          end

        end

      else # Single Speed

        if not hvac.HasGroundSourceHeatPump
          enteringTemp = dehum_design_db
        else # Use annual average temperature for this evaluation
          enteringTemp = weather.data.AnnualAvgDrybulb
        end

        totalCap_CurveValue = MathTools.biquadratic(mj8.wetbulb_indoor_dehumid, enteringTemp, hvac.COOL_CAP_FT_SPEC[0])
        dehumid_AC_TotCap = totalCap_CurveValue * unit_final.Cool_Capacity

        if hvac.HasRoomAirConditioner # Assume constant SHR for now.
          sensibleCap_CurveValue = hvac.SHRRated[0]
        else
          sensibleCap_CurveValue = process_curve_fit(unit_final.Cool_Airflow, dehumid_AC_TotCap, enteringTemp)
        end

        dehumid_AC_SensCap = sensibleCap_CurveValue * unit_final.Cool_Capacity_Sens
        dehumid_AC_LatCap = dehumid_AC_TotCap - dehumid_AC_SensCap
        dehumid_AC_RTF = [0, unit_final.Dehumid_Load_Sens / dehumid_AC_SensCap].max

      end

    else
      dehumid_AC_SensCap = 0
      dehumid_AC_LatCap = 0
      dehumid_AC_RTF = 0

    end

    # Determine the average total latent load (there's duct latent load only when the AC is running)
    unit_final.Dehumid_Load_Ducts_Lat = [0, unit_init.Dehumid_Load_Lat + unit_final.Dehumid_Load_Ducts_Lat * dehumid_AC_RTF].max

    air_h_fg = 1075.6 # Btu/lbm

    # Calculate the required water removal (in L/day) at 75 deg-F DB, 50% RH indoor conditions
    dehumid_WaterRemoval = [0, (unit_init.Dehumid_Load_Lat - dehumid_AC_RTF * dehumid_AC_LatCap) / air_h_fg /
      Liquid.H2O_l.rho * UnitConversions.convert(1, 'ft^3', 'L') * UnitConversions.convert(1, 'day', 'hr')].max

    if hvac.HasDehumidifier
      # Determine the rated water removal rate using the performance curve
      dehumid_CurveValue = MathTools.biquadratic(UnitConversions.convert(mj8.cool_setpoint, 'F', 'C'), mj8.RH_indoor_dehumid * 100, hvac.Dehumidifier_Water_Remove_Cap_Ft_DB_RH)
      unit_final.Dehumid_WaterRemoval = dehumid_WaterRemoval / dehumid_CurveValue
    else
      unit_final.Dehumid_WaterRemoval = 0
    end

    return unit_final
  end

  def self.get_shelter_class(model, unit)
    neighbor_offset_ft = Geometry.get_closest_neighbor_distance(model)

    unit_height_ft = Geometry.get_height_of_spaces(Geometry.get_finished_spaces(unit.spaces))
    exposed_wall_ratio = Geometry.calculate_above_grade_exterior_wall_area(unit.spaces) / Geometry.calculate_above_grade_wall_area(unit.spaces)

    if exposed_wall_ratio > 0.5 # 3 or 4 exposures; Table 5D
      if neighbor_offset_ft == 0
        shelter_class = 2 # Typical shelter for isolated rural house
      elsif neighbor_offset_ft > unit_height_ft
        shelter_class = 3 # Typical shelter caused by other buildings across the street
      else
        shelter_class = 4 # Typical shelter for urban buildings where sheltering obstacles are less than one building height away
      end
    else # 0, 1, or 2 exposures; Table 5E
      if neighbor_offset_ft == 0
        if exposed_wall_ratio > 0.25 # 2 exposures; Table 5E
          shelter_class = 2 # Typical shelter for isolated rural house
        else # 1 exposure; Table 5E
          shelter_class = 3 # Typical shelter caused by other buildings across the street
        end
      elsif neighbor_offset_ft > unit_height_ft
        shelter_class = 4 # Typical shelter for urban buildings where sheltering obstacles are less than one building height away
      else
        shelter_class = 5 # Typical shelter for urban buildings where sheltering obstacles are less than one building height away
      end
    end

    return shelter_class
  end

  def self.get_wallgroup_wood_or_steel_stud(cavity_ins_r_value)
    '''
    Determine the base Group Number based on cavity R-value for siding or stucco walls
    '''
    if cavity_ins_r_value < 2
      wallGroup = 1   # A
    elsif cavity_ins_r_value <= 11
      wallGroup = 2   # B
    elsif cavity_ins_r_value <= 13
      wallGroup = 3   # C
    elsif cavity_ins_r_value <= 15
      wallGroup = 4   # D
    elsif cavity_ins_r_value <= 19
      wallGroup = 5   # E
    elsif cavity_ins_r_value <= 21
      wallGroup = 6   # F
    else
      wallGroup = 7   # G
    end

    return wallGroup
  end

  def self.get_ventilation_rates(runner, unit)
    mechVentType = get_feature(runner, unit, Constants.SizingInfoMechVentType, 'string')
    mechVentWholeHouseRate = get_feature(runner, unit, Constants.SizingInfoMechVentWholeHouseRate, 'double')
    return if mechVentType.nil? || mechVentWholeHouseRate.nil?

    q_unb = 0
    q_bal_Sens = 0
    q_bal_Lat = 0

    if mechVentType == Constants.VentTypeExhaust
      q_unb = mechVentWholeHouseRate
    elsif (mechVentType == Constants.VentTypeSupply) || (mechVentType == Constants.VentTypeCFIS)
      q_unb = mechVentWholeHouseRate
    elsif mechVentType == Constants.VentTypeBalanced
      totalEfficiency = get_feature(runner, unit, Constants.SizingInfoMechVentTotalEfficiency, 'double')
      apparentSensibleEffectiveness = get_feature(runner, unit, Constants.SizingInfoMechVentApparentSensibleEffectiveness, 'double')
      latentEffectiveness = get_feature(runner, unit, Constants.SizingInfoMechVentLatentEffectiveness, 'double')
      return if totalEfficiency.nil? || latentEffectiveness.nil? || apparentSensibleEffectiveness.nil?

      q_bal_Sens = mechVentWholeHouseRate * (1 - apparentSensibleEffectiveness)
      q_bal_Lat = mechVentWholeHouseRate * (1 - latentEffectiveness)
    elsif mechVentType == Constants.VentTypeNone
    # nop
    else
      runner.registerError("Unexpected mechanical ventilation type: #{mechVentType}.")
      return
    end

    return [q_unb, q_bal_Sens, q_bal_Lat]
  end

  def self.get_fenestration_shgc(runner, surface)
    simple_glazing = get_window_simple_glazing(runner, surface, true)
    return if simple_glazing.nil?

    shgc_with_interior_shade_heat = simple_glazing.solarHeatGainCoefficient

    int_shade_heat_to_cool_ratio = 1.0
    if surface.shadingControl.is_initialized
      shading_control = surface.shadingControl.get
      if shading_control.shadingMaterial.is_initialized
        shading_material = shading_control.shadingMaterial.get
        if shading_material.to_Shade.is_initialized
          shade = shading_material.to_Shade.get
          int_shade_heat_to_cool_ratio = shade.solarTransmittance
        else
          runner.registerError("Unhandled shading material: #{shading_material.name}.")
          return
        end
      end
    end

    shgc_with_interior_shade_cool = shgc_with_interior_shade_heat * int_shade_heat_to_cool_ratio

    return [shgc_with_interior_shade_cool, shgc_with_interior_shade_heat]
  end

  def self.calc_heat_cfm(load, acf, heat_setpoint, htg_supply_air_temp)
    return load / (1.1 * acf * (htg_supply_air_temp - heat_setpoint))
  end

  def self.calc_heat_duct_load(ducts, acf, heat_setpoint, dse_Fregain, heatingLoad, htg_supply_air_temp, t_amb)
    # Supply and return duct surface areas located outside conditioned space
    dse_As = ducts.SupplySurfaceArea * ducts.LocationFrac
    dse_Ar = ducts.ReturnSurfaceArea

    # Initialize for the iteration
    delta = 1
    heatingLoad_Prev = heatingLoad
    heat_cfm = calc_heat_cfm(heatingLoad, acf, heat_setpoint, htg_supply_air_temp)

    for _iter in 0..19
      break if delta.abs <= 0.001

      dse_DEcorr_heating, _dse_dTe_heating = calc_dse_heating(ducts, acf, heat_cfm, heatingLoad_Prev, t_amb, dse_As, dse_Ar, heat_setpoint, dse_Fregain)

      # Calculate the increase in heating load due to ducts (Approach: DE = Qload/Qequip -> Qducts = Qequip-Qload)
      heatingLoad_Next = heatingLoad / dse_DEcorr_heating

      # Calculate the change since the last iteration
      delta = (heatingLoad_Next - heatingLoad_Prev) / heatingLoad_Prev

      # Update the flow rate for the next iteration
      heatingLoad_Prev = heatingLoad_Next
      heat_cfm = calc_heat_cfm(heatingLoad_Next, acf, heat_setpoint, htg_supply_air_temp)

    end

    return heatingLoad_Next - heatingLoad
  end

  def self.calc_dse_heating(ducts, acf, cfm_inter, load_Inter_Sens, dse_Tamb, dse_As, dse_Ar, t_setpoint, dse_Fregain)
    '''
    Calculate the Distribution System Efficiency using the method of ASHRAE Standard 152 (used for heating and cooling).
    '''
    dse_Bs, dse_Br, dse_a_s, dse_a_r, dse_dTe, dse_dT = _calc_dse_init(ducts, acf, cfm_inter, load_Inter_Sens, dse_Tamb, dse_As, dse_Ar, t_setpoint)
    dse_DE = _calc_dse_DE_heating(dse_a_s, dse_Bs, dse_a_r, dse_Br, dse_dT, dse_dTe)
    dse_DEcorr = _calc_dse_DEcorr(ducts, dse_DE, dse_Fregain, dse_Br, dse_a_r)

    return dse_DEcorr, dse_dTe
  end

  def self.calc_dse_cooling(ducts, acf, enthalpy_indoor_cooling, leavingAirTemp, cfm_inter, load_Inter_Sens, dse_Tamb, dse_As, dse_Ar, t_setpoint, dse_Fregain, coolingLoad_Tot, dse_h_Return_Cooling)
    '''
    Calculate the Distribution System Efficiency using the method of ASHRAE Standard 152 (used for heating and cooling).
    '''

    dse_Bs, dse_Br, dse_a_s, dse_a_r, dse_dTe, dse_dT = _calc_dse_init(ducts, acf, cfm_inter, load_Inter_Sens, dse_Tamb, dse_As, dse_Ar, t_setpoint)
    dse_DE, coolingLoad_Ducts_Sens = _calc_dse_DE_cooling(dse_a_s, cfm_inter, coolingLoad_Tot, dse_a_r, dse_h_Return_Cooling, enthalpy_indoor_cooling, dse_Br, dse_dT, dse_Bs, leavingAirTemp, dse_Tamb, load_Inter_Sens)
    dse_DEcorr = _calc_dse_DEcorr(ducts, dse_DE, dse_Fregain, dse_Br, dse_a_r)

    return dse_DEcorr, dse_dTe, coolingLoad_Ducts_Sens
  end

  def self._calc_dse_init(ducts, acf, cfm_inter, load_Inter_Sens, dse_Tamb, dse_As, dse_Ar, t_setpoint)
    dse_Qs = ducts.SupplyLoss * cfm_inter
    dse_Qr = ducts.ReturnLoss * cfm_inter

    # Supply and return conduction functions, Bs and Br
    if ducts.NotInLiving
      dse_Bs = Math.exp((-1.0 * dse_As) / (60 * cfm_inter * @inside_air_dens * Gas.Air.cp * ducts.SupplyRvalue))
      dse_Br = Math.exp((-1.0 * dse_Ar) / (60 * cfm_inter * @inside_air_dens * Gas.Air.cp * ducts.ReturnRvalue))

    else
      dse_Bs = 1
      dse_Br = 1
    end

    dse_a_s = (cfm_inter - dse_Qs) / cfm_inter
    dse_a_r = (cfm_inter - dse_Qr) / cfm_inter

    dse_dTe = load_Inter_Sens / (1.1 * acf * cfm_inter)
    dse_dT = t_setpoint - dse_Tamb

    return dse_Bs, dse_Br, dse_a_s, dse_a_r, dse_dTe, dse_dT
  end

  def self._calc_dse_DE_cooling(dse_a_s, cfm_inter, coolingLoad_Tot, dse_a_r, dse_h_Return_Cooling, enthalpy_indoor_cooling, dse_Br, dse_dT, dse_Bs, leavingAirTemp, dse_Tamb, load_Inter_Sens)
    # Calculate the delivery effectiveness (Equation 6-23)
    # NOTE: This equation is for heating but DE equation for cooling requires psychrometric calculations. This should be corrected.
    dse_DE = ((dse_a_s * 60 * cfm_inter * @inside_air_dens) / (-1 * coolingLoad_Tot)) * \
             (((-1 * coolingLoad_Tot) / (60 * cfm_inter * @inside_air_dens)) + \
              (1 - dse_a_r) * (dse_h_Return_Cooling - enthalpy_indoor_cooling) + \
              dse_a_r * Gas.Air.cp * (dse_Br - 1) * dse_dT + \
              Gas.Air.cp * (dse_Bs - 1) * (leavingAirTemp - dse_Tamb))

    # Calculate the sensible heat transfer from surroundings
    coolingLoad_Ducts_Sens = (1 - [dse_DE, 0].max) * load_Inter_Sens

    return dse_DE, coolingLoad_Ducts_Sens
  end

  def self._calc_dse_DE_heating(dse_a_s, dse_Bs, dse_a_r, dse_Br, dse_dT, dse_dTe)
    # Calculate the delivery effectiveness (Equation 6-23)
    # NOTE: This equation is for heating but DE equation for cooling requires psychrometric calculations. This should be corrected.
    dse_DE = (dse_a_s * dse_Bs -
              dse_a_s * dse_Bs * (1 - dse_a_r * dse_Br) * (dse_dT / dse_dTe) -
              dse_a_s * (1 - dse_Bs) * (dse_dT / dse_dTe))

    return dse_DE
  end

  def self._calc_dse_DEcorr(ducts, dse_DE, dse_Fregain, dse_Br, dse_a_r)
    # Calculate the delivery effectiveness corrector for regain (Equation 6-40)
    dse_DEcorr = (dse_DE + dse_Fregain * (1 - dse_DE) +
                  dse_Br * (dse_a_r * dse_Fregain - dse_Fregain))

    # Limit the DE to a reasonable value to prevent negative values and huge equipment
    dse_DEcorr = [dse_DEcorr, 0.25].max
    dse_DEcorr = [dse_DEcorr, 1.00].min

    return dse_DEcorr
  end

  def self.calculate_sensible_latent_split(cool_design_grains, grains_indoor_cooling, acf, return_duct_loss, cool_load_tot, coolingLoadLat, cool_Airflow)
    # Calculate the latent duct leakage load (Manual J accounts only for return duct leakage)
    dse_Cool_Load_Latent = [0, 0.68 * acf * return_duct_loss * cool_Airflow *
      (cool_design_grains - grains_indoor_cooling)].max

    # Calculate final latent and load
    cool_Load_Lat = coolingLoadLat + dse_Cool_Load_Latent
    cool_Load_Sens = cool_load_tot - cool_Load_Lat

    return cool_Load_Lat, cool_Load_Sens
  end

  def self.get_ducts_for_unit(runner, model, unit, hvac, unit_ffa)
    ducts = DuctsInfo.new

    ducts.Has = false
    if hvac.HasDuctedHeating || hvac.HasDuctedCooling
      ducts.Has = true
      ducts.NotInLiving = false # init

      ducts.SupplySurfaceArea = get_feature(runner, unit, Constants.SizingInfoDuctsSupplySurfaceArea, 'double')
      ducts.ReturnSurfaceArea = get_feature(runner, unit, Constants.SizingInfoDuctsReturnSurfaceArea, 'double')
      return if ducts.SupplySurfaceArea.nil? || ducts.ReturnSurfaceArea.nil?

      ducts.LocationFrac = get_feature(runner, unit, Constants.SizingInfoDuctsLocationFrac, 'double')
      return if ducts.LocationFrac.nil?

      ducts.SupplyLoss = get_feature(runner, unit, Constants.SizingInfoDuctsSupplyLoss, 'double')
      ducts.ReturnLoss = get_feature(runner, unit, Constants.SizingInfoDuctsReturnLoss, 'double')
      return if ducts.SupplyLoss.nil? || ducts.ReturnLoss.nil?

      ducts.SupplyRvalue = get_feature(runner, unit, Constants.SizingInfoDuctsSupplyRvalue, 'double')
      ducts.ReturnRvalue = get_feature(runner, unit, Constants.SizingInfoDuctsReturnRvalue, 'double')
      return if ducts.SupplyRvalue.nil? || ducts.ReturnRvalue.nil?

      locationZoneName = get_feature(runner, unit, Constants.SizingInfoDuctsLocationZone, 'string')
      return if locationZoneName.nil?

      # Get arbitrary space from zone
      ducts.LocationSpace = nil
      unit_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)
      adjacent_common_spaces = Geometry.get_unit_adjacent_common_spaces(unit)
      adjacent_common_zones = Geometry.get_thermal_zones_from_spaces(adjacent_common_spaces)
      (unit_zones + adjacent_common_zones).each do |zone|
        next if not zone.name.to_s.start_with?(locationZoneName)

        ducts.LocationSpace = zone.spaces[0]
      end
      if ducts.LocationSpace.nil?
        runner.registerError('Could not determine duct location.')
        return
      end
      if not Geometry.is_living(ducts.LocationSpace)
        ducts.NotInLiving = true
      end
    end

    return ducts
  end

  def self.get_hvac_for_unit(runner, model, unit)
    # Init
    hvac = HVACInfo.new
    hvac.HasDuctedHeating = false
    hvac.HasDuctedCooling = false
    hvac.HasCooling = false
    hvac.HasHeating = false
    hvac.HasCentralAirConditioner = false
    hvac.HasRoomAirConditioner = false
    hvac.HasFurnace = false
    hvac.HasBoiler = false
    hvac.HasElecBaseboard = false
    hvac.HasUnitHeater = false
    hvac.HasAirSourceHeatPump = false
    hvac.HasMiniSplitHeatPump = false
    hvac.HasGroundSourceHeatPump = false
    hvac.HasDehumidifier = false
    hvac.NumSpeedsCooling = 0
    hvac.NumSpeedsHeating = 0
    hvac.COOL_CAP_FT_SPEC = nil
    hvac.HEAT_CAP_FT_SPEC = nil
    hvac.COOL_SH_FT_SPEC = nil
    hvac.COIL_BF_FT_SPEC = nil
    hvac.CoilBF = nil
    hvac.HtgSupplyAirTemp = nil
    hvac.MinOutdoorTemp = nil
    hvac.SHRRated = nil
    hvac.CapacityRatioCooling = [1.0]
    hvac.CapacityRatioHeating = [1.0]
    hvac.FixedCoolingCapacity = nil
    hvac.FixedHeatingCapacity = nil
    hvac.FixedSuppHeatingCapacity = nil
    hvac.HeatingCapacityOffset = nil
    hvac.OverSizeLimit = 1.15
    hvac.HPSizedForMaxLoad = false
    hvac.CoolingCFMs = nil
    hvac.HeatingCFMs = nil
    hvac.FanspeedRatioCooling = [1.0]
    hvac.CapacityDerateFactorEER = nil
    hvac.CapacityDerateFactorCOP = nil
    hvac.BoilerDesignTemp = nil
    hvac.Dehumidifier_Water_Remove_Cap_Ft_DB_RH = nil
    hvac.GroundHXVertical = nil
    hvac.HeatingEIR = nil
    hvac.CoolingEIR = nil
    hvac.HXDTDesign = nil
    hvac.HXCHWDesign = nil
    hvac.HXHWDesign = nil
    hvac.RatedCFMperTonCooling = nil
    hvac.RatedCFMperTonHeating = nil
    hvac.GSHPBoreSpacing = nil
    hvac.GSHPBoreHoles = nil
    hvac.GSHPBoreDepth = nil
    hvac.GSHPBoreConfig = nil
    hvac.GSHPSpacingType = nil
    hvac.HeatingLoadFraction = 0
    hvac.CoolingLoadFraction = 0

    clg_equips = []
    htg_equips = []

    unit_thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)
    control_slave_zones_hash = HVAC.get_control_and_slave_zones(unit_thermal_zones)

    if control_slave_zones_hash.keys.size > 1
      runner.registerError('Cannot handle multiple HVAC equipment in a unit.')
      return
    end

    control_zone = control_slave_zones_hash.keys[0]

    HVAC.existing_cooling_equipment(model, runner, control_zone, exclude_central = true).each do |clg_equip|
      next if clg_equips.include? clg_equip
      next if clg_equip.is_a? OpenStudio::Model::ZoneHVACIdealLoadsAirSystem

      clg_equips << clg_equip
    end

    HVAC.existing_heating_equipment(model, runner, control_zone, exclude_central = true).each do |htg_equip|
      next if htg_equips.include? htg_equip
      next if htg_equip.is_a? OpenStudio::Model::ZoneHVACIdealLoadsAirSystem

      htg_equips << htg_equip
    end

    hvac.HasCentralAirConditioner = HVAC.has_central_ac(model, runner, control_zone)
    hvac.HasRoomAirConditioner = HVAC.has_room_ac(model, runner, control_zone)
    hvac.HasFurnace = HVAC.has_furnace(model, runner, control_zone)
    hvac.HasBoiler = HVAC.has_boiler(model, runner, control_zone)
    hvac.HasElecBaseboard = HVAC.has_electric_baseboard(model, runner, control_zone)
    hvac.HasUnitHeater = HVAC.has_unit_heater(model, runner, control_zone)
    hvac.HasAirSourceHeatPump = HVAC.has_ashp(model, runner, control_zone)
    hvac.HasGroundSourceHeatPump = HVAC.has_gshp(model, runner, control_zone)
    hvac.HasMiniSplitHeatPump = HVAC.has_mshp(model, runner, control_zone)
    has_ducted_mshp = HVAC.has_ducted_mshp(model, runner, control_zone)

    # Cooling equipment
    if clg_equips.size > 0
      hvac.HasCooling = true

      clg_equips.each do |clg_equip|
        clg_coil, htg_coil, supp_htg_coil = HVAC.get_coils_from_hvac_equip(clg_equip)

        if clg_equip.is_a? OpenStudio::Model::AirLoopHVACUnitarySystem
          if clg_equip.airLoopHVAC.is_initialized
            hvac.HasDuctedCooling = true
          end
        end

        ratedCFMperTonCooling = get_feature(runner, clg_equip, Constants.SizingInfoHVACRatedCFMperTonCooling, 'string', false)
        if not ratedCFMperTonCooling.nil?
          hvac.RatedCFMperTonCooling = ratedCFMperTonCooling.split(',').map(&:to_f)
        end

        hvac.CoolingLoadFraction = get_feature(runner, clg_equip, Constants.SizingInfoHVACFracCoolLoadServed, 'double')
        return nil if hvac.CoolingLoadFraction.nil?

        # Cooling coil
        if clg_coil.is_a? OpenStudio::Model::CoilCoolingDXSingleSpeed
          hvac.NumSpeedsCooling = 1

          if hvac.HasRoomAirConditioner
            coolingCFMs = get_feature(runner, clg_equip, Constants.SizingInfoHVACCoolingCFMs, 'string')
            return nil if coolingCFMs.nil?

            hvac.CoolingCFMs = coolingCFMs.split(',').map(&:to_f)
          end

          curves = [clg_coil.totalCoolingCapacityFunctionOfTemperatureCurve]
          hvac.COOL_CAP_FT_SPEC = get_2d_vector_from_CAP_FT_SPEC_curves(curves, hvac.NumSpeedsCooling)
          if not clg_coil.ratedSensibleHeatRatio.is_initialized
            runner.registerError("SHR not set for #{clg_coil.name}.")
            return nil
          end
          hvac.SHRRated = [clg_coil.ratedSensibleHeatRatio.get]
          if clg_coil.ratedTotalCoolingCapacity.is_initialized
            hvac.FixedCoolingCapacity = UnitConversions.convert(clg_coil.ratedTotalCoolingCapacity.get, 'W', 'ton')
          end

          if not hvac.HasRoomAirConditioner
            capacityDerateFactorEER = get_feature(runner, clg_equip, Constants.SizingInfoHVACCapacityDerateFactorEER, 'string')
            return nil if capacityDerateFactorEER.nil?

            hvac.CapacityDerateFactorEER = capacityDerateFactorEER.split(',').map(&:to_f)
          end

        elsif clg_coil.is_a? OpenStudio::Model::CoilCoolingDXMultiSpeed
          hvac.NumSpeedsCooling = clg_coil.stages.size
          if hvac.NumSpeedsCooling == 2
            hvac.OverSizeLimit = 1.2
          else
            hvac.OverSizeLimit = 1.3
          end

          capacityRatioCooling = get_feature(runner, clg_equip, Constants.SizingInfoHVACCapacityRatioCooling, 'string')
          return nil if capacityRatioCooling.nil?

          hvac.CapacityRatioCooling = capacityRatioCooling.split(',').map(&:to_f)

          if not clg_equip.designSpecificationMultispeedObject.is_initialized
            runner.registerError("DesignSpecificationMultispeedObject not set for #{clg_equip.name}.")
            return nil
          end
          perf = clg_equip.designSpecificationMultispeedObject.get
          hvac.FanspeedRatioCooling = []
          perf.supplyAirflowRatioFields.each do |airflowRatioField|
            if not airflowRatioField.coolingRatio.is_initialized
              runner.registerError("Cooling airflow ratio not set for #{perf.name}")
              return nil
            end
            hvac.FanspeedRatioCooling << airflowRatioField.coolingRatio.get
          end

          curves = []
          hvac.SHRRated = []
          clg_coil.stages.each_with_index do |stage, speed|
            curves << stage.totalCoolingCapacityFunctionofTemperatureCurve
            if not stage.grossRatedSensibleHeatRatio.is_initialized
              runner.registerError("SHR not set for #{clg_coil.name}.")
              return nil
            end
            hvac.SHRRated << stage.grossRatedSensibleHeatRatio.get
            next if !stage.grossRatedTotalCoolingCapacity.is_initialized

            hvac.FixedCoolingCapacity = UnitConversions.convert(stage.grossRatedTotalCoolingCapacity.get, 'W', 'ton')
          end
          hvac.COOL_CAP_FT_SPEC = get_2d_vector_from_CAP_FT_SPEC_curves(curves, hvac.NumSpeedsCooling)

          if clg_equip.name.to_s.start_with?(Constants.ObjectNameCentralAirConditioner) || clg_equip.name.to_s.start_with?(Constants.ObjectNameAirSourceHeatPump)
            capacityDerateFactorEER = get_feature(runner, clg_equip, Constants.SizingInfoHVACCapacityDerateFactorEER, 'string')
            return nil if capacityDerateFactorEER.nil?

            hvac.CapacityDerateFactorEER = capacityDerateFactorEER.split(',').map(&:to_f)
          end

          if clg_equip.name.to_s.start_with? Constants.ObjectNameMiniSplitHeatPump
            coolingCFMs = get_feature(runner, clg_equip, Constants.SizingInfoHVACCoolingCFMs, 'string')
            return nil if coolingCFMs.nil?

            hvac.CoolingCFMs = coolingCFMs.split(',').map(&:to_f)
          end

        elsif clg_coil.is_a? OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit
          hvac.NumSpeedsCooling = 1

          cOOL_CAP_FT_SPEC = [clg_coil.totalCoolingCapacityCoefficient1,
                              clg_coil.totalCoolingCapacityCoefficient2,
                              clg_coil.totalCoolingCapacityCoefficient3,
                              clg_coil.totalCoolingCapacityCoefficient4,
                              clg_coil.totalCoolingCapacityCoefficient5]
          hvac.COOL_CAP_FT_SPEC = [HVAC.convert_curve_gshp(cOOL_CAP_FT_SPEC, true)]

          cOOL_SH_FT_SPEC = [clg_coil.sensibleCoolingCapacityCoefficient1,
                             clg_coil.sensibleCoolingCapacityCoefficient3,
                             clg_coil.sensibleCoolingCapacityCoefficient4,
                             clg_coil.sensibleCoolingCapacityCoefficient5,
                             clg_coil.sensibleCoolingCapacityCoefficient6]
          hvac.COOL_SH_FT_SPEC = [HVAC.convert_curve_gshp(cOOL_SH_FT_SPEC, true)]

          cOIL_BF_FT_SPEC = get_feature(runner, clg_equip, Constants.SizingInfoGSHPCoil_BF_FT_SPEC, 'string')
          return nil if cOIL_BF_FT_SPEC.nil?

          hvac.COIL_BF_FT_SPEC = [cOIL_BF_FT_SPEC.split(',').map(&:to_f)]

          shr_rated = get_feature(runner, clg_equip, Constants.SizingInfoHVACSHR, 'string')
          return nil if shr_rated.nil?

          hvac.SHRRated = shr_rated.split(',').map(&:to_f)

          hvac.CoilBF = get_feature(runner, clg_equip, Constants.SizingInfoGSHPCoilBF, 'double')
          return nil if hvac.CoilBF.nil?

          if clg_coil.ratedTotalCoolingCapacity.is_initialized
            hvac.FixedCoolingCapacity = UnitConversions.convert(clg_coil.ratedTotalCoolingCapacity.get, 'W', 'ton')
          end

          hvac.CoolingEIR = 1.0 / clg_coil.ratedCoolingCoefficientofPerformance

          hvac.GSHPBoreSpacing = get_feature(runner, clg_equip, Constants.SizingInfoGSHPBoreSpacing, 'double')
          hvac.GSHPBoreHoles = get_feature(runner, clg_equip, Constants.SizingInfoGSHPBoreHoles, 'string')
          hvac.GSHPBoreDepth = get_feature(runner, clg_equip, Constants.SizingInfoGSHPBoreDepth, 'string')
          hvac.GSHPBoreConfig = get_feature(runner, clg_equip, Constants.SizingInfoGSHPBoreConfig, 'string')
          hvac.GSHPSpacingType = get_feature(runner, clg_equip, Constants.SizingInfoGSHPUTubeSpacingType, 'string')
          return nil if hvac.GSHPBoreSpacing.nil? || hvac.GSHPBoreHoles.nil? || hvac.GSHPBoreDepth.nil? || hvac.GSHPBoreConfig.nil? || hvac.GSHPSpacingType.nil?

        elsif not clg_coil.nil?
          runner.registerError("Unexpected cooling coil: #{clg_coil.name}.")
          return nil
        end
      end
    end

    # Heating equipment
    if htg_equips.size > 0
      hvac.HasHeating = true

      htg_equips.each do |htg_equip|
        clg_coil, htg_coil, supp_htg_coil = HVAC.get_coils_from_hvac_equip(htg_equip)

        if htg_equip.is_a? OpenStudio::Model::AirLoopHVACUnitarySystem
          if htg_equip.airLoopHVAC.is_initialized
            hvac.HasDuctedHeating = true
          end
          if hvac.HasAirSourceHeatPump
            hvac.HPSizedForMaxLoad = get_feature(runner, htg_equip, Constants.SizingInfoHPSizedForMaxLoad, 'boolean', true)
            return nil if hvac.HPSizedForMaxLoad.nil?
          end
        end

        ratedCFMperTonHeating = get_feature(runner, htg_equip, Constants.SizingInfoHVACRatedCFMperTonHeating, 'string', false)
        if not ratedCFMperTonHeating.nil?
          hvac.RatedCFMperTonHeating = ratedCFMperTonHeating.split(',').map(&:to_f)
        end

        hvac.HeatingLoadFraction = get_feature(runner, htg_equip, Constants.SizingInfoHVACFracHeatLoadServed, 'double')
        return nil if hvac.HeatingLoadFraction.nil?

        # Heating coil
        if htg_coil.is_a? OpenStudio::Model::CoilHeatingElectric
          hvac.NumSpeedsHeating = 1
          if htg_coil.nominalCapacity.is_initialized
            hvac.FixedHeatingCapacity = UnitConversions.convert(htg_coil.nominalCapacity.get, 'W', 'ton')
          end

        elsif htg_coil.is_a? OpenStudio::Model::CoilHeatingGas
          hvac.NumSpeedsHeating = 1
          if htg_coil.nominalCapacity.is_initialized
            hvac.FixedHeatingCapacity = UnitConversions.convert(htg_coil.nominalCapacity.get, 'W', 'ton')
          end

        elsif htg_coil.is_a? OpenStudio::Model::CoilHeatingWaterBaseboard
          hvac.NumSpeedsHeating = 1
          if htg_coil.heatingDesignCapacity.is_initialized
            hvac.FixedHeatingCapacity = UnitConversions.convert(htg_coil.heatingDesignCapacity.get, 'W', 'ton')
          end
          hvac.BoilerDesignTemp = UnitConversions.convert(htg_coil.plantLoop.get.sizingPlant.designLoopExitTemperature, 'C', 'F')

        elsif htg_coil.is_a? OpenStudio::Model::CoilHeatingDXSingleSpeed
          hvac.NumSpeedsHeating = 1
          hvac.MinOutdoorTemp = UnitConversions.convert(htg_coil.minimumOutdoorDryBulbTemperatureforCompressorOperation, 'C', 'F')

          curves = [htg_coil.totalHeatingCapacityFunctionofTemperatureCurve]
          hvac.HEAT_CAP_FT_SPEC = get_2d_vector_from_CAP_FT_SPEC_curves(curves, hvac.NumSpeedsHeating)

          if htg_coil.ratedTotalHeatingCapacity.is_initialized
            hvac.FixedHeatingCapacity = UnitConversions.convert(htg_coil.ratedTotalHeatingCapacity.get, 'W', 'ton')
          end

          capacityDerateFactorCOP = get_feature(runner, htg_equip, Constants.SizingInfoHVACCapacityDerateFactorCOP, 'string')
          return nil if capacityDerateFactorCOP.nil?

          hvac.CapacityDerateFactorCOP = capacityDerateFactorCOP.split(',').map(&:to_f)

        elsif htg_coil.is_a? OpenStudio::Model::CoilHeatingDXMultiSpeed
          hvac.NumSpeedsHeating = htg_coil.stages.size
          hvac.MinOutdoorTemp = UnitConversions.convert(htg_coil.minimumOutdoorDryBulbTemperatureforCompressorOperation, 'C', 'F')

          capacityRatioHeating = get_feature(runner, htg_equip, Constants.SizingInfoHVACCapacityRatioHeating, 'string')
          return nil if capacityRatioHeating.nil?

          hvac.CapacityRatioHeating = capacityRatioHeating.split(',').map(&:to_f)

          curves = []
          htg_coil.stages.each_with_index do |stage, speed|
            curves << stage.heatingCapacityFunctionofTemperatureCurve
            next if !stage.grossRatedHeatingCapacity.is_initialized

            hvac.FixedHeatingCapacity = UnitConversions.convert(stage.grossRatedHeatingCapacity.get, 'W', 'ton')
          end
          hvac.HEAT_CAP_FT_SPEC = get_2d_vector_from_CAP_FT_SPEC_curves(curves, hvac.NumSpeedsHeating)

          if htg_equip.name.to_s.start_with? Constants.ObjectNameAirSourceHeatPump
            capacityDerateFactorCOP = get_feature(runner, htg_equip, Constants.SizingInfoHVACCapacityDerateFactorCOP, 'string')
            return nil if capacityDerateFactorCOP.nil?

            hvac.CapacityDerateFactorCOP = capacityDerateFactorCOP.split(',').map(&:to_f)
          end

          if htg_equip.name.to_s.start_with? Constants.ObjectNameMiniSplitHeatPump
            heatingCFMs = get_feature(runner, htg_equip, Constants.SizingInfoHVACHeatingCFMs, 'string')
            return nil if heatingCFMs.nil?

            hvac.HeatingCFMs = heatingCFMs.split(',').map(&:to_f)

            hvac.HeatingCapacityOffset = get_feature(runner, htg_equip, Constants.SizingInfoHVACHeatingCapacityOffset, 'double')
            return nil if hvac.HeatingCapacityOffset.nil?
          end

        elsif htg_coil.is_a? OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit
          hvac.NumSpeedsHeating = 1

          if htg_coil.ratedHeatingCapacity.is_initialized
            hvac.FixedHeatingCapacity = UnitConversions.convert(htg_coil.ratedHeatingCapacity.get, 'W', 'ton')
          end

          hvac.HeatingEIR = 1.0 / htg_coil.ratedHeatingCoefficientofPerformance

        elsif not htg_coil.nil?
          runner.registerError("Unexpected heating coil: #{htg_coil.name}.")
          return nil

        end

        # Supplemental heating
        if htg_equip.is_a? OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric
          if htg_equip.nominalCapacity.is_initialized
            hvac.FixedSuppHeatingCapacity = UnitConversions.convert(htg_equip.nominalCapacity.get, 'W', 'ton')
          end

        elsif supp_htg_coil.is_a? OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric
          if supp_htg_coil.nominalCapacity.is_initialized
            hvac.FixedSuppHeatingCapacity = UnitConversions.convert(supp_htg_coil.nominalCapacity.get, 'W', 'ton')
          end

        elsif supp_htg_coil.is_a? OpenStudio::Model::CoilHeatingElectric
          if supp_htg_coil.nominalCapacity.is_initialized
            hvac.FixedSuppHeatingCapacity = UnitConversions.convert(supp_htg_coil.nominalCapacity.get, 'W', 'ton')
          end

        elsif not supp_htg_coil.nil?
          runner.registerError("Unexpected supplemental heating coil: #{supp_htg_coil.name}.")
          return nil
        end
      end
    end

    # Dehumidifier
    dehumids = model.getZoneHVACDehumidifierDXs
    if dehumids.size >= 1
      hvac.HasDehumidifier = true
      curve = dehumids[0].waterRemovalCurve.to_CurveBiquadratic.get
      hvac.Dehumidifier_Water_Remove_Cap_Ft_DB_RH = [curve.coefficient1Constant, curve.coefficient2x, curve.coefficient3xPOW2, curve.coefficient4y, curve.coefficient5yPOW2, curve.coefficient6xTIMESY]
    end

    # GSHP
    if hvac.HasGroundSourceHeatPump
      model.getPlantLoops.each do |pl|
        next if not pl.name.to_s.start_with?(Constants.ObjectNameGroundSourceHeatPumpVerticalBore)

        pl.supplyComponents.each do |plc|
          next if !plc.to_GroundHeatExchangerVertical.is_initialized

          hvac.GroundHXVertical = plc.to_GroundHeatExchangerVertical.get
        end
        hvac.HXDTDesign = UnitConversions.convert(pl.sizingPlant.loopDesignTemperatureDifference, 'K', 'R')
        hvac.HXCHWDesign = UnitConversions.convert(pl.sizingPlant.designLoopExitTemperature, 'C', 'F')
        hvac.HXHWDesign = UnitConversions.convert(pl.minimumLoopTemperature, 'C', 'F')
      end
      if hvac.HXDTDesign.nil? || hvac.HXCHWDesign.nil? || hvac.HXHWDesign.nil?
        runner.registerError('Could not find GSHP plant loop.')
        return
      end
      if hvac.GroundHXVertical.nil?
        runner.registerError('Could not find GroundHeatExchangerVertical object on GSHP plant loop.')
        return
      end
    end

    return hvac
  end

  def self.get_2d_vector_from_CAP_FT_SPEC_curves(curves, num_speeds)
    vector = []
    curves.each do |curve|
      bi = curve.to_CurveBiquadratic.get
      c_si = [bi.coefficient1Constant, bi.coefficient2x, bi.coefficient3xPOW2, bi.coefficient4y, bi.coefficient5yPOW2, bi.coefficient6xTIMESY]
      vector << HVAC.convert_curve_biquadratic(c_si, false)
    end
    if (num_speeds > 1) && (vector.size == 1)
      # Repeat coefficients for each speed
      for i in 1..num_speeds
        vector << vector[0]
      end
    end
    return vector
  end

  def self.process_curve_fit(airFlowRate, capacity, temp)
    # TODO: Get rid of this curve by using ADP/BF calculations
    capacity_tons = UnitConversions.convert(capacity, 'Btu/hr', 'ton')
    return MathTools.biquadratic(airFlowRate / capacity_tons, temp, @shr_biquadratic)
  end

  def self.space_is_vented(space, min_sla_for_venting)
    ela = 0.0
    space.spaceInfiltrationEffectiveLeakageAreas.each do |leakage_area|
      ela += UnitConversions.convert(leakage_area.effectiveAirLeakageArea, 'cm^2', 'ft^2')
    end
    sla = ela / UnitConversions.convert(space.floorArea, 'm^2', 'ft^2')
    if sla > min_sla_for_venting
      return true
    end

    return false
  end

  def self.true_azimuth(surface)
    true_azimuth = nil
    facade = Geometry.get_facade_for_surface(surface)
    if facade.nil?
      relative_azimuth = UnitConversions.convert(surface.azimuth, 'rad', 'deg')
      true_azimuth = @northAxis + relative_azimuth + 180.0
    elsif facade == Constants.FacadeFront
      true_azimuth = @northAxis
    elsif facade == Constants.FacadeBack
      true_azimuth = @northAxis + 180
    elsif facade == Constants.FacadeLeft
      true_azimuth = @northAxis + 90
    elsif facade == Constants.FacadeRight
      true_azimuth = @northAxis + 270
    end
    if true_azimuth >= 360
      true_azimuth -= 360
    end
    return true_azimuth
  end

  def self.calculate_t_attic_iter(runner, attic_UAs, t_solair, cool_setpoint, coolingLoad_Ducts_Sens)
    # Calculate new value for Tattic based on updated duct losses
    sum_uat = -coolingLoad_Ducts_Sens
    attic_UAs.each do |ua_type, ua|
      if (ua_type == 'outdoors') || (ua_type == 'infil')
        sum_uat += ua * t_solair
      elsif ua_type == 'surface' # adjacent to finished
        sum_uat += ua * cool_setpoint
      elsif (ua_type == 'total') || (ua_type == 'foundation')
      # skip
      else
        runner.registerError("Unexpected ua_type: '#{ua_type}'.")
        return nil
      end
    end
    t_attic_iter = sum_uat / attic_UAs['total']
    t_attic_iter = [t_attic_iter, t_solair].min # Prevent attic from being hotter than T_solair
    t_attic_iter = [t_attic_iter, cool_setpoint].max # Prevent attic from being colder than cool_setpoint
    return t_attic_iter
  end

  def self.calculate_t_solair(weather, roofAbsorptance, roofPitch)
    # Calculates Tsolair under design conditions
    # Uses equation (30) from 2009 ASHRAE Handbook-Fundamentals (IP), p 18.22:

    t_outdoor = weather.design.CoolingDrybulb # Design outdoor air temp (F)
    i_b = weather.design.CoolingDirectNormal
    i_d = weather.design.CoolingDiffuseHorizontal

    # Use max summer direct normal plus diffuse solar radiation, adjusted for roof pitch
    # (Not calculating max coincident i_b + i_d because that requires knowing roofPitch in advance; will typically coincide with peak i_b though.)
    i_T = UnitConversions.convert(i_b + i_d * (1 + Math::cos(roofPitch.deg2rad)) / 2, 'W/m^2', 'Btu/(hr*ft^2)') # total solar radiation incident on surface (Btu/h/ft2)
    # Adjust diffuse horizontal for roof pitch using isotropic diffuse model (Liu and Jordan 1963) from Duffie and Beckman eq 2.15.1

    h_o = 4 # coefficient of heat transfer for long-wave radiation and convection at outer surface (Btu/h-ft2-F)
    # Value of 4.0 for 7.5 mph wind (summer design) from 2009 ASHRAE H-F (IP) p 26.1
    # p 18.22 assumes h_o = 3.0 Btu/hft2F for horizontal surfaces, but we found 4.0 gives
    # more realistic sol air temperatures and is more realistic for residential roofs.

    emittance = 1.0 # hemispherical emittance of surface = 1 for horizontal surface, from 2009 ASHRAE H-F (IP) p 18.22

    deltaR = 20 # difference between long-wave radiation incident on surface from sky and surroundings
    # and radiation emitted by blackbody at outdoor air temperature
    # 20 Btu/h-ft2 appropriate for horizontal surfaces, from ASHRAE H-F (IP) p 18.22

    deltaR_inclined = deltaR * Math::cos(roofPitch.deg2rad) # Correct deltaR for inclined surface,
    # from eq. 2.32 in  Castelino, R.L. 1992. "Implementation of the Revised Transfer Function Method and Evaluation of the CLTD/SCL/CLF Method" (Thesis) Oklahoma State University

    t_solair = t_outdoor + (roofAbsorptance * i_T - emittance * deltaR_inclined) / h_o
    return t_solair
  end

  def self.get_space_ua_values(runner, space, weather, unit)
    if Geometry.space_is_finished(space)
      runner.registerError("Method should not be called for a finished space: '#{space.name}'.")
      return
    end

    space_UAs = { 'foundation' => 0, 'outdoors' => 0, 'surface' => 0 }

    # Surface UAs
    space.surfaces.each do |surface|
      obc = surface.outsideBoundaryCondition.downcase

      if obc == 'foundation'
        # FIXME: Original approach used Winkelmann U-factors...
        if surface.surfaceType.downcase == 'wall'
          wall_ins_rvalue, wall_ins_height, wall_constr_rvalue = get_foundation_wall_insulation_props(runner, surface)
          if wall_ins_rvalue.nil? || wall_ins_height.nil? || wall_constr_rvalue.nil?
            return nil
          end

          ufactor = 1.0 / (wall_ins_rvalue + wall_constr_rvalue)
        elsif surface.surfaceType.downcase == 'floor'
          next
        end
      else
        ufactor = get_surface_ufactor(runner, surface, surface.surfaceType, true)
        return nil if ufactor.nil?
      end

      # Exclude surfaces adjacent to unfinished space
      next if (not ['foundation', 'outdoors'].include?(obc)) && (not Geometry.is_interzonal_surface(surface))

      space_UAs[obc] += ufactor * UnitConversions.convert(surface.netArea, 'm^2', 'ft^2')
    end

    # Infiltration UA
    infiltration_cfm = get_feature(runner, space.thermalZone.get, Constants.SizingInfoZoneInfiltrationCFM, 'double', false)
    infiltration_cfm = 0 if infiltration_cfm.nil?
    outside_air_density = UnitConversions.convert(weather.header.LocalPressure, 'atm', 'Btu/ft^3') / (Gas.Air.r * (weather.data.AnnualAvgDrybulb + 460.0))
    space_UAs['infil'] = infiltration_cfm * outside_air_density * Gas.Air.cp * UnitConversions.convert(1.0, 'hr', 'min')

    # Total UA
    total_UA = 0.0
    space_UAs.each do |ua_type, ua|
      total_UA += ua
    end
    space_UAs['total'] = total_UA
    return space_UAs
  end

  def self.calculate_space_design_temps(runner, space, weather, unit, finished_design_temp, design_db, ground_db, is_cooling_for_unvented_attic_roof_insulation = false)
    space_UAs = get_space_ua_values(runner, space, weather, unit)
    return if space_UAs.nil?

    # Calculate space design temp from space UAs
    design_temp = nil
    if not is_cooling_for_unvented_attic_roof_insulation

      sum_uat = 0
      space_UAs.each do |ua_type, ua|
        if ua_type == 'foundation'
          sum_uat += ua * ground_db
        elsif (ua_type == 'outdoors') || (ua_type == 'infil')
          sum_uat += ua * design_db
        elsif ua_type == 'surface' # adjacent to finished
          sum_uat += ua * finished_design_temp
        elsif ua_type == 'total'
        # skip
        else
          runner.registerError("Unexpected space ua type: '#{ua_type}'.")
          return nil
        end
      end
      design_temp = sum_uat / space_UAs['total']

    else

      # Special case due to effect of solar

      # This number comes from the number from the Vented Attic
      # assumption, but assuming an unvented attic will be hotter
      # during the summer when insulation is at the ceiling level
      max_temp_rise = 50
      # Estimate from running a few cases in E+ and DOE2 since the
      # attic will always be a little warmer than the living space
      # when the roof is insulated
      min_temp_rise = 5

      max_cooling_temp = @finished_cool_design_temp + max_temp_rise
      min_cooling_temp = @finished_cool_design_temp + min_temp_rise

      ua_finished = 0
      ua_outside = 0
      space_UAs.each do |ua_type, ua|
        if (ua_type == 'outdoors') || (ua_type == 'infil')
          ua_outside += ua
        elsif ua_type == 'surface' # adjacent to finished
          ua_finished += ua
        elsif (ua_type == 'total') || (ua_type == 'foundation')
        # skip
        else
          runner.registerError("Unexpected space ua type: '#{ua_type}'.")
          return nil
        end
      end
      percent_ua_finished = ua_finished / (ua_finished + ua_outside)
      design_temp = max_cooling_temp - percent_ua_finished * (max_cooling_temp - min_cooling_temp)

    end

    return design_temp
  end

  def self.get_wallgroup(runner, unit, wall)
    exteriorFinishDensity = UnitConversions.convert(wall.construction.get.to_LayeredConstruction.get.getLayer(0).to_StandardOpaqueMaterial.get.density, 'kg/m^3', 'lbm/ft^3')

    wall_type = get_feature(runner, wall, Constants.SizingInfoWallType, 'string')
    return if wall_type.nil?

    rigid_r = get_feature(runner, wall, Constants.SizingInfoWallRigidInsRvalue, 'double', false)
    rigid_r = 0 if rigid_r.nil?

    # Determine the wall Group Number (A - K = 1 - 11) for exterior walls (ie. all walls except basement walls)
    maxWallGroup = 11

    # The following correlations were estimated by analyzing MJ8 construction tables. This is likely a better
    # approach than including the Group Number.
    if ['WoodStud', 'SteelStud'].include?(wall_type)
      cavity_r = get_feature(runner, wall, Constants.SizingInfoStudWallCavityRvalue, 'double')
      return if cavity_r.nil?

      wallGroup = get_wallgroup_wood_or_steel_stud(cavity_r)

      # Adjust the base wall group for rigid foam insulation
      if (rigid_r > 1) && (rigid_r <= 7)
        if cavity_r < 2
          wallGroup += 2
        else
          wallGroup += 4
        end
      elsif rigid_r > 7
        if cavity_r < 2
          wallGroup += 4
        else
          wallGroup += 6
        end
      end

      # Assume brick if the outside finish density is >= 100 lb/ft^3
      if exteriorFinishDensity >= 100
        if cavity_r < 2
          wallGroup += 4
        else
          wallGroup += 6
        end
      end

    elsif wall_type == 'DoubleWoodStud'
      wallGroup = 10 # J (assumed since MJ8 does not include double stud constructions)
      if exteriorFinishDensity >= 100
        wallGroup = 11 # K
      end

    elsif wall_type == 'SIP'
      rigid_thick_in = get_feature(runner, wall, Constants.SizingInfoWallRigidInsThickness, 'double', false)
      rigid_thick_in = 0 if rigid_thick_in.nil?

      sip_ins_thick_in = get_feature(runner, wall, Constants.SizingInfoSIPWallInsThickness, 'double')
      return if sip_ins_thick_in.nil?

      # Manual J refers to SIPs as Structural Foam Panel (SFP)
      if sip_ins_thick_in + rigid_thick_in < 4.5
        wallGroup = 7   # G
      elsif sip_ins_thick_in + rigid_thick_in < 6.5
        wallGroup = 9   # I
      else
        wallGroup = 11  # K
      end
      if exteriorFinishDensity >= 100
        wallGroup += 3
      end

    elsif wall_type == 'CMU'
      cmu_furring_ins_r = get_feature(runner, wall, Constants.SizingInfoCMUWallFurringInsRvalue, 'double', false)
      cmu_furring_ins_r = 0 if cmu_furring_ins_r.nil?

      # Manual J uses the same wall group for filled or hollow block
      if cmu_furring_ins_r < 2
        wallGroup = 5   # E
      elsif cmu_furring_ins_r <= 11
        wallGroup = 8   # H
      elsif cmu_furring_ins_r <= 13
        wallGroup = 9   # I
      elsif cmu_furring_ins_r <= 15
        wallGroup = 9   # I
      elsif cmu_furring_ins_r <= 19
        wallGroup = 10  # J
      elsif cmu_furring_ins_r <= 21
        wallGroup = 11  # K
      else
        wallGroup = 11  # K
      end
      # This is an estimate based on Table 4A - Construction Number 13
      wallGroup += (rigid_r / 3.0).floor # Group is increased by approximately 1 letter for each R3

    elsif wall_type == 'ICF'
      wallGroup = 11 # K

    elsif wall_type == 'Generic'
      # Assume Wall Group K since 'Other' Wall Type is likely to have a high thermal mass
      wallGroup = 11 # K

    else
      runner.registerError("Unexpected wall type: '#{@wall_type}'.")
      return
    end

    # Maximum wall group is K
    wallGroup = [wallGroup, maxWallGroup].min

    return wallGroup
  end

  def self.gshp_hx_pipe_rvalue(pipe_od, pipe_id, pipe_cond)
    # Thermal Resistance of Pipe
    return Math.log(pipe_od / pipe_id) / 2.0 / Math::PI / pipe_cond
  end

  def self.gshp_hxbore_ft_per_ton(weather, htd, ctd, bore_spacing, ground_conductivity, spacing_type, grout_conductivity, bore_diameter, pipe_od, pipe_r_value, heating_eir, cooling_eir, chw_design, hw_design, design_delta_t)
    if spacing_type == 'b'
      beta_0 = 17.4427
      beta_1 = -0.6052
    elsif spacing_type == 'c'
      beta_0 = 21.9059
      beta_1 = -0.3796
    elsif spacing_type == 'as'
      beta_0 = 20.1004
      beta_1 = -0.94467
    end

    r_value_ground = Math.log(bore_spacing / bore_diameter * 12.0) / 2.0 / Math::PI / ground_conductivity
    r_value_grout = 1.0 / grout_conductivity / beta_0 / ((bore_diameter / pipe_od)**beta_1)
    r_value_bore = r_value_grout + pipe_r_value / 2.0 # Note: Convection resistance is negligible when calculated against Glhepro (Jeffrey D. Spitler, 2000)

    rtf_DesignMon_Heat = [0.25, (71.0 - weather.data.MonthlyAvgDrybulbs[0]) / htd].max
    rtf_DesignMon_Cool = [0.25, (weather.data.MonthlyAvgDrybulbs[6] - 76.0) / ctd].max

    nom_length_heat = (1.0 - heating_eir) * (r_value_bore + r_value_ground * rtf_DesignMon_Heat) / (weather.data.AnnualAvgDrybulb - (2.0 * hw_design - design_delta_t) / 2.0) * UnitConversions.convert(1.0, 'ton', 'Btu/hr')
    nom_length_cool = (1.0 + cooling_eir) * (r_value_bore + r_value_ground * rtf_DesignMon_Cool) / ((2.0 * chw_design + design_delta_t) / 2.0 - weather.data.AnnualAvgDrybulb) * UnitConversions.convert(1.0, 'ton', 'Btu/hr')

    return nom_length_heat, nom_length_cool
  end

  def self.gshp_gfnc_coeff(bore_config, num_bore_holes, spacing_to_depth_ratio)
    # Set GFNC coefficients
    gfnc_coeff = nil
    if bore_config == Constants.BoreConfigSingle
      gfnc_coeff = 2.681, 3.024, 3.320, 3.666, 3.963, 4.306, 4.645, 4.899, 5.222, 5.405, 5.531, 5.704, 5.821, 6.082, 6.304, 6.366, 6.422, 6.477, 6.520, 6.558, 6.591, 6.619, 6.640, 6.665, 6.893, 6.694, 6.715
    elsif bore_config == Constants.BoreConfigLine
      if num_bore_holes == 2
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.681, 3.043, 3.397, 3.9, 4.387, 5.005, 5.644, 6.137, 6.77, 7.131, 7.381, 7.722, 7.953, 8.462, 8.9, 9.022, 9.13, 9.238, 9.323, 9.396, 9.46, 9.515, 9.556, 9.604, 9.636, 9.652, 9.678
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.024, 3.332, 3.734, 4.143, 4.691, 5.29, 5.756, 6.383, 6.741, 6.988, 7.326, 7.557, 8.058, 8.5, 8.622, 8.731, 8.839, 8.923, 8.997, 9.061, 9.115, 9.156, 9.203, 9.236, 9.252, 9.277
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.668, 3.988, 4.416, 4.921, 5.323, 5.925, 6.27, 6.512, 6.844, 7.073, 7.574, 8.015, 8.137, 8.247, 8.354, 8.439, 8.511, 8.575, 8.629, 8.67, 8.718, 8.75, 8.765, 8.791
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.31, 4.672, 4.919, 5.406, 5.711, 5.932, 6.246, 6.465, 6.945, 7.396, 7.52, 7.636, 7.746, 7.831, 7.905, 7.969, 8.024, 8.066, 8.113, 8.146, 8.161, 8.187
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.648, 4.835, 5.232, 5.489, 5.682, 5.964, 6.166, 6.65, 7.087, 7.208, 7.32, 7.433, 7.52, 7.595, 7.661, 7.717, 7.758, 7.806, 7.839, 7.855, 7.88
        end
      elsif num_bore_holes == 3
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.682, 3.05, 3.425, 3.992, 4.575, 5.366, 6.24, 6.939, 7.86, 8.39, 8.759, 9.263, 9.605, 10.358, 11.006, 11.185, 11.345, 11.503, 11.628, 11.736, 11.831, 11.911, 11.971, 12.041, 12.089, 12.112, 12.151
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.336, 3.758, 4.21, 4.855, 5.616, 6.243, 7.124, 7.639, 7.999, 8.493, 8.833, 9.568, 10.22, 10.399, 10.56, 10.718, 10.841, 10.949, 11.043, 11.122, 11.182, 11.252, 11.299, 11.322, 11.36
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.67, 3.997, 4.454, 5.029, 5.517, 6.298, 6.768, 7.106, 7.578, 7.907, 8.629, 9.274, 9.452, 9.612, 9.769, 9.893, 9.999, 10.092, 10.171, 10.231, 10.3, 10.347, 10.37, 10.407
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.311, 4.681, 4.942, 5.484, 5.844, 6.116, 6.518, 6.807, 7.453, 8.091, 8.269, 8.435, 8.595, 8.719, 8.826, 8.919, 8.999, 9.06, 9.128, 9.175, 9.198, 9.235
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.649, 4.836, 5.25, 5.53, 5.746, 6.076, 6.321, 6.924, 7.509, 7.678, 7.836, 7.997, 8.121, 8.229, 8.325, 8.405, 8.465, 8.535, 8.582, 8.605, 8.642
        end
      elsif num_bore_holes == 4
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.682, 3.054, 3.438, 4.039, 4.676, 5.575, 6.619, 7.487, 8.662, 9.35, 9.832, 10.492, 10.943, 11.935, 12.787, 13.022, 13.232, 13.44, 13.604, 13.745, 13.869, 13.975, 14.054, 14.145, 14.208, 14.238, 14.289
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.339, 3.77, 4.244, 4.941, 5.798, 6.539, 7.622, 8.273, 8.734, 9.373, 9.814, 10.777, 11.63, 11.864, 12.074, 12.282, 12.443, 12.584, 12.706, 12.81, 12.888, 12.979, 13.041, 13.071, 13.12
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.671, 4.001, 4.474, 5.086, 5.62, 6.514, 7.075, 7.487, 8.075, 8.49, 9.418, 10.253, 10.484, 10.692, 10.897, 11.057, 11.195, 11.316, 11.419, 11.497, 11.587, 11.647, 11.677, 11.726
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.311, 4.686, 4.953, 5.523, 5.913, 6.214, 6.67, 7.005, 7.78, 8.574, 8.798, 9.011, 9.215, 9.373, 9.512, 9.632, 9.735, 9.814, 9.903, 9.963, 9.993, 10.041
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.649, 4.837, 5.259, 5.55, 5.779, 6.133, 6.402, 7.084, 7.777, 7.983, 8.178, 8.379, 8.536, 8.672, 8.795, 8.898, 8.975, 9.064, 9.125, 9.155, 9.203
        end
      elsif num_bore_holes == 5
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.683, 3.056, 3.446, 4.067, 4.737, 5.709, 6.877, 7.879, 9.272, 10.103, 10.69, 11.499, 12.053, 13.278, 14.329, 14.618, 14.878, 15.134, 15.336, 15.51, 15.663, 15.792, 15.89, 16.002, 16.079, 16.117, 16.179
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.34, 3.777, 4.265, 4.993, 5.913, 6.735, 7.974, 8.737, 9.285, 10.054, 10.591, 11.768, 12.815, 13.103, 13.361, 13.616, 13.814, 13.987, 14.137, 14.264, 14.36, 14.471, 14.548, 14.584, 14.645
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.671, 4.004, 4.485, 5.12, 5.683, 6.653, 7.279, 7.747, 8.427, 8.914, 10.024, 11.035, 11.316, 11.571, 11.82, 12.016, 12.185, 12.332, 12.458, 12.553, 12.663, 12.737, 12.773, 12.833
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.312, 4.688, 4.96, 5.547, 5.955, 6.274, 6.764, 7.132, 8.002, 8.921, 9.186, 9.439, 9.683, 9.873, 10.041, 10.186, 10.311, 10.406, 10.514, 10.588, 10.624, 10.683
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.65, 4.837, 5.264, 5.562, 5.798, 6.168, 6.452, 7.186, 7.956, 8.191, 8.415, 8.649, 8.834, 8.995, 9.141, 9.265, 9.357, 9.465, 9.539, 9.575, 9.634
        end
      elsif num_bore_holes == 6
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.683, 3.057, 3.452, 4.086, 4.779, 5.8, 7.06, 8.162, 9.74, 10.701, 11.385, 12.334, 12.987, 14.439, 15.684, 16.027, 16.335, 16.638, 16.877, 17.083, 17.264, 17.417, 17.532, 17.665, 17.756, 17.801, 17.874
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.341, 3.782, 4.278, 5.029, 5.992, 6.87, 8.226, 9.081, 9.704, 10.59, 11.212, 12.596, 13.828, 14.168, 14.473, 14.773, 15.007, 15.211, 15.388, 15.538, 15.652, 15.783, 15.872, 15.916, 15.987
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.671, 4.005, 4.493, 5.143, 5.726, 6.747, 7.42, 7.93, 8.681, 9.227, 10.5, 11.672, 12.001, 12.299, 12.591, 12.821, 13.019, 13.192, 13.34, 13.452, 13.581, 13.668, 13.71, 13.78
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.312, 4.69, 4.964, 5.563, 5.983, 6.314, 6.828, 7.218, 8.159, 9.179, 9.479, 9.766, 10.045, 10.265, 10.458, 10.627, 10.773, 10.883, 11.01, 11.096, 11.138, 11.207
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.65, 4.838, 5.268, 5.57, 5.811, 6.191, 6.485, 7.256, 8.082, 8.339, 8.586, 8.848, 9.055, 9.238, 9.404, 9.546, 9.653, 9.778, 9.864, 9.907, 9.976
        end
      elsif num_bore_holes == 7
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.683, 3.058, 3.456, 4.1, 4.809, 5.867, 7.195, 8.38, 10.114, 11.189, 11.961, 13.04, 13.786, 15.456, 16.89, 17.286, 17.64, 17.989, 18.264, 18.501, 18.709, 18.886, 19.019, 19.172, 19.276, 19.328, 19.412
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.342, 3.785, 4.288, 5.054, 6.05, 6.969, 8.418, 9.349, 10.036, 11.023, 11.724, 13.296, 14.706, 15.096, 15.446, 15.791, 16.059, 16.293, 16.497, 16.668, 16.799, 16.949, 17.052, 17.102, 17.183
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.672, 4.007, 4.499, 5.159, 5.756, 6.816, 7.524, 8.066, 8.874, 9.469, 10.881, 12.2, 12.573, 12.912, 13.245, 13.508, 13.734, 13.932, 14.1, 14.228, 14.376, 14.475, 14.524, 14.604
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.312, 4.691, 4.967, 5.574, 6.003, 6.343, 6.874, 7.28, 8.276, 9.377, 9.706, 10.022, 10.333, 10.578, 10.795, 10.985, 11.15, 11.276, 11.419, 11.518, 11.565, 11.644
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.65, 4.838, 5.27, 5.576, 5.821, 6.208, 6.509, 7.307, 8.175, 8.449, 8.715, 8.998, 9.224, 9.426, 9.61, 9.768, 9.887, 10.028, 10.126, 10.174, 10.252
        end
      elsif num_bore_holes == 8
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.683, 3.059, 3.459, 4.11, 4.832, 5.918, 7.3, 8.55, 10.416, 11.59, 12.442, 13.641, 14.475, 16.351, 17.97, 18.417, 18.817, 19.211, 19.522, 19.789, 20.024, 20.223, 20.373, 20.546, 20.664, 20.721, 20.816
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.342, 3.788, 4.295, 5.073, 6.093, 7.045, 8.567, 9.56, 10.301, 11.376, 12.147, 13.892, 15.472, 15.911, 16.304, 16.692, 16.993, 17.257, 17.486, 17.679, 17.826, 17.995, 18.111, 18.167, 18.259
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.672, 4.008, 4.503, 5.171, 5.779, 6.868, 7.603, 8.17, 9.024, 9.659, 11.187, 12.64, 13.055, 13.432, 13.804, 14.098, 14.351, 14.573, 14.762, 14.905, 15.07, 15.182, 15.237, 15.326
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.312, 4.692, 4.97, 5.583, 6.018, 6.364, 6.909, 7.327, 8.366, 9.531, 9.883, 10.225, 10.562, 10.83, 11.069, 11.28, 11.463, 11.602, 11.762, 11.872, 11.925, 12.013
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.65, 4.838, 5.272, 5.58, 5.828, 6.22, 6.527, 7.345, 8.246, 8.533, 8.814, 9.114, 9.356, 9.573, 9.772, 9.944, 10.076, 10.231, 10.34, 10.393, 10.481
        end
      elsif num_bore_holes == 9
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.683, 3.06, 3.461, 4.118, 4.849, 5.958, 7.383, 8.687, 10.665, 11.927, 12.851, 14.159, 15.075, 17.149, 18.947, 19.443, 19.888, 20.326, 20.672, 20.969, 21.23, 21.452, 21.618, 21.81, 21.941, 22.005, 22.11
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.342, 3.79, 4.301, 5.088, 6.127, 7.105, 8.686, 9.732, 10.519, 11.671, 12.504, 14.408, 16.149, 16.633, 17.069, 17.499, 17.833, 18.125, 18.379, 18.593, 18.756, 18.943, 19.071, 19.133, 19.235
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.672, 4.008, 4.506, 5.181, 5.797, 6.909, 7.665, 8.253, 9.144, 9.813, 11.441, 13.015, 13.468, 13.881, 14.29, 14.613, 14.892, 15.136, 15.345, 15.503, 15.686, 15.809, 15.87, 15.969
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.312, 4.693, 4.972, 5.589, 6.03, 6.381, 6.936, 7.364, 8.436, 9.655, 10.027, 10.391, 10.751, 11.04, 11.298, 11.527, 11.726, 11.879, 12.054, 12.175, 12.234, 12.331
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.65, 4.838, 5.273, 5.584, 5.833, 6.23, 6.541, 7.375, 8.302, 8.6, 8.892, 9.208, 9.463, 9.692, 9.905, 10.089, 10.231, 10.4, 10.518, 10.576, 10.673
        end
      elsif num_bore_holes == 10
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.683, 3.06, 3.463, 4.125, 4.863, 5.99, 7.45, 8.799, 10.872, 12.211, 13.197, 14.605, 15.598, 17.863, 19.834, 20.379, 20.867, 21.348, 21.728, 22.055, 22.342, 22.585, 22.767, 22.978, 23.122, 23.192, 23.307
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.026, 3.343, 3.792, 4.306, 5.1, 6.154, 7.153, 8.784, 9.873, 10.699, 11.918, 12.805, 14.857, 16.749, 17.278, 17.755, 18.225, 18.591, 18.91, 19.189, 19.423, 19.601, 19.807, 19.947, 20.015, 20.126
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.672, 4.009, 4.509, 5.189, 5.812, 6.942, 7.716, 8.32, 9.242, 9.939, 11.654, 13.336, 13.824, 14.271, 14.714, 15.065, 15.368, 15.635, 15.863, 16.036, 16.235, 16.37, 16.435, 16.544
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.312, 4.694, 4.973, 5.595, 6.039, 6.395, 6.958, 7.394, 8.493, 9.757, 10.146, 10.528, 10.909, 11.215, 11.491, 11.736, 11.951, 12.116, 12.306, 12.437, 12.501, 12.607
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.65, 4.838, 5.275, 5.587, 5.837, 6.238, 6.552, 7.399, 8.347, 8.654, 8.956, 9.283, 9.549, 9.79, 10.014, 10.209, 10.36, 10.541, 10.669, 10.732, 10.837
        end
      end
    elsif bore_config == Constants.BoreConfigLconfig
      if num_bore_holes == 3
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.682, 3.052, 3.435, 4.036, 4.668, 5.519, 6.435, 7.155, 8.091, 8.626, 8.997, 9.504, 9.847, 10.605, 11.256, 11.434, 11.596, 11.755, 11.88, 11.988, 12.083, 12.163, 12.224, 12.294, 12.342, 12.365, 12.405
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.337, 3.767, 4.242, 4.937, 5.754, 6.419, 7.33, 7.856, 8.221, 8.721, 9.063, 9.818, 10.463, 10.641, 10.801, 10.959, 11.084, 11.191, 11.285, 11.365, 11.425, 11.495, 11.542, 11.565, 11.603
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.67, 3.999, 4.472, 5.089, 5.615, 6.449, 6.942, 7.292, 7.777, 8.111, 8.847, 9.497, 9.674, 9.836, 9.993, 10.117, 10.224, 10.317, 10.397, 10.457, 10.525, 10.573, 10.595, 10.633
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.311, 4.684, 4.95, 5.525, 5.915, 6.209, 6.64, 6.946, 7.645, 8.289, 8.466, 8.63, 8.787, 8.912, 9.018, 9.112, 9.192, 9.251, 9.32, 9.367, 9.39, 9.427
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.649, 4.836, 5.255, 5.547, 5.777, 6.132, 6.397, 7.069, 7.673, 7.848, 8.005, 8.161, 8.29, 8.397, 8.492, 8.571, 8.631, 8.7, 8.748, 8.771, 8.808
        end
      elsif num_bore_holes == 4
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.683, 3.055, 3.446, 4.075, 4.759, 5.729, 6.841, 7.753, 8.96, 9.659, 10.147, 10.813, 11.266, 12.265, 13.122, 13.356, 13.569, 13.778, 13.942, 14.084, 14.208, 14.314, 14.393, 14.485, 14.548, 14.579, 14.63
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.339, 3.777, 4.27, 5.015, 5.945, 6.739, 7.875, 8.547, 9.018, 9.668, 10.116, 11.107, 11.953, 12.186, 12.395, 12.603, 12.766, 12.906, 13.029, 13.133, 13.212, 13.303, 13.365, 13.395, 13.445
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.671, 4.003, 4.488, 5.137, 5.713, 6.678, 7.274, 7.707, 8.319, 8.747, 9.698, 10.543, 10.774, 10.984, 11.19, 11.351, 11.49, 11.612, 11.715, 11.793, 11.882, 11.944, 11.974, 12.022
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.311, 4.688, 4.959, 5.558, 5.976, 6.302, 6.794, 7.155, 8.008, 8.819, 9.044, 9.255, 9.456, 9.618, 9.755, 9.877, 9.98, 10.057, 10.146, 10.207, 10.236, 10.285
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.649, 4.837, 5.263, 5.563, 5.804, 6.183, 6.473, 7.243, 7.969, 8.185, 8.382, 8.58, 8.743, 8.88, 9.001, 9.104, 9.181, 9.27, 9.332, 9.361, 9.409
        end
      elsif num_bore_holes == 5
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.683, 3.057, 3.453, 4.097, 4.806, 5.842, 7.083, 8.14, 9.579, 10.427, 11.023, 11.841, 12.399, 13.633, 14.691, 14.98, 15.242, 15.499, 15.701, 15.877, 16.03, 16.159, 16.257, 16.37, 16.448, 16.485, 16.549
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.34, 3.783, 4.285, 5.054, 6.038, 6.915, 8.219, 9.012, 9.576, 10.362, 10.907, 12.121, 13.161, 13.448, 13.705, 13.96, 14.16, 14.332, 14.483, 14.61, 14.707, 14.819, 14.895, 14.932, 14.993
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.671, 4.005, 4.497, 5.162, 5.76, 6.796, 7.461, 7.954, 8.665, 9.17, 10.31, 11.338, 11.62, 11.877, 12.127, 12.324, 12.494, 12.643, 12.77, 12.865, 12.974, 13.049, 13.085, 13.145
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.312, 4.69, 4.964, 5.575, 6.006, 6.347, 6.871, 7.263, 8.219, 9.164, 9.432, 9.684, 9.926, 10.121, 10.287, 10.434, 10.56, 10.654, 10.762, 10.836, 10.872, 10.93
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.65, 4.837, 5.267, 5.573, 5.819, 6.208, 6.51, 7.33, 8.136, 8.384, 8.613, 8.844, 9.037, 9.2, 9.345, 9.468, 9.562, 9.67, 9.744, 9.78, 9.839
        end
      elsif num_bore_holes == 6
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.683, 3.058, 3.457, 4.111, 4.837, 5.916, 7.247, 8.41, 10.042, 11.024, 11.72, 12.681, 13.339, 14.799, 16.054, 16.396, 16.706, 17.011, 17.25, 17.458, 17.639, 17.792, 17.907, 18.041, 18.133, 18.177, 18.253
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.341, 3.786, 4.296, 5.08, 6.099, 7.031, 8.456, 9.346, 9.988, 10.894, 11.528, 12.951, 14.177, 14.516, 14.819, 15.12, 15.357, 15.56, 15.737, 15.888, 16.002, 16.134, 16.223, 16.267, 16.338
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.671, 4.007, 4.503, 5.178, 5.791, 6.872, 7.583, 8.119, 8.905, 9.472, 10.774, 11.969, 12.3, 12.6, 12.895, 13.126, 13.326, 13.501, 13.649, 13.761, 13.89, 13.977, 14.02, 14.09
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.312, 4.691, 4.968, 5.586, 6.026, 6.375, 6.919, 7.331, 8.357, 9.407, 9.71, 9.997, 10.275, 10.501, 10.694, 10.865, 11.011, 11.121, 11.247, 11.334, 11.376, 11.445
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.65, 4.838, 5.27, 5.579, 5.828, 6.225, 6.535, 7.384, 8.244, 8.515, 8.768, 9.026, 9.244, 9.428, 9.595, 9.737, 9.845, 9.97, 10.057, 10.099, 10.168
        end
      end
    elsif bore_config == Constants.BoreConfigL2config
      if num_bore_holes == 8
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.685, 3.078, 3.547, 4.438, 5.521, 7.194, 9.237, 10.973, 13.311, 14.677, 15.634, 16.942, 17.831, 19.791, 21.462, 21.917, 22.329, 22.734, 23.052, 23.328, 23.568, 23.772, 23.925, 24.102, 24.224, 24.283, 24.384
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.027, 3.354, 3.866, 4.534, 5.682, 7.271, 8.709, 10.845, 12.134, 13.046, 14.308, 15.177, 17.106, 18.741, 19.19, 19.592, 19.989, 20.303, 20.57, 20.805, 21.004, 21.155, 21.328, 21.446, 21.504, 21.598
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.676, 4.034, 4.639, 5.587, 6.514, 8.195, 9.283, 10.09, 11.244, 12.058, 13.88, 15.491, 15.931, 16.328, 16.716, 17.02, 17.282, 17.511, 17.706, 17.852, 18.019, 18.134, 18.19, 18.281
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.315, 4.72, 5.041, 5.874, 6.525, 7.06, 7.904, 8.541, 10.093, 11.598, 12.018, 12.41, 12.784, 13.084, 13.338, 13.562, 13.753, 13.895, 14.058, 14.169, 14.223, 14.312
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.307, 4.653, 4.842, 5.325, 5.717, 6.058, 6.635, 7.104, 8.419, 9.714, 10.108, 10.471, 10.834, 11.135, 11.387, 11.61, 11.798, 11.94, 12.103, 12.215, 12.268, 12.356
        end
      elsif num_bore_holes == 10
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.685, 3.08, 3.556, 4.475, 5.611, 7.422, 9.726, 11.745, 14.538, 16.199, 17.369, 18.975, 20.071, 22.489, 24.551, 25.111, 25.619, 26.118, 26.509, 26.848, 27.143, 27.393, 27.582, 27.8, 27.949, 28.022, 28.146
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.027, 3.356, 3.874, 4.559, 5.758, 7.466, 9.07, 11.535, 13.06, 14.153, 15.679, 16.739, 19.101, 21.106, 21.657, 22.15, 22.637, 23.021, 23.348, 23.635, 23.879, 24.063, 24.275, 24.42, 24.49, 24.605
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.676, 4.037, 4.653, 5.634, 6.61, 8.44, 9.664, 10.589, 11.936, 12.899, 15.086, 17.041, 17.575, 18.058, 18.53, 18.9, 19.218, 19.496, 19.733, 19.91, 20.113, 20.252, 20.32, 20.431
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.315, 4.723, 5.048, 5.904, 6.584, 7.151, 8.062, 8.764, 10.521, 12.281, 12.779, 13.246, 13.694, 14.054, 14.36, 14.629, 14.859, 15.03, 15.226, 15.36, 15.425, 15.531
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.307, 4.653, 4.842, 5.331, 5.731, 6.083, 6.683, 7.178, 8.6, 10.054, 10.508, 10.929, 11.356, 11.711, 12.009, 12.275, 12.5, 12.671, 12.866, 13, 13.064, 13.17
        end
      end
    elsif bore_config == Constants.BoreConfigUconfig
      if num_bore_holes == 5
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.683, 3.057, 3.46, 4.134, 4.902, 6.038, 7.383, 8.503, 9.995, 10.861, 11.467, 12.294, 12.857, 14.098, 15.16, 15.449, 15.712, 15.97, 16.173, 16.349, 16.503, 16.633, 16.731, 16.844, 16.922, 16.96, 17.024
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.341, 3.789, 4.31, 5.136, 6.219, 7.172, 8.56, 9.387, 9.97, 10.774, 11.328, 12.556, 13.601, 13.889, 14.147, 14.403, 14.604, 14.777, 14.927, 15.056, 15.153, 15.265, 15.341, 15.378, 15.439
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.671, 4.007, 4.51, 5.213, 5.864, 6.998, 7.717, 8.244, 8.993, 9.518, 10.69, 11.73, 12.015, 12.273, 12.525, 12.723, 12.893, 13.043, 13.17, 13.265, 13.374, 13.449, 13.486, 13.546
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.312, 4.692, 4.969, 5.607, 6.072, 6.444, 7.018, 7.446, 8.474, 9.462, 9.737, 9.995, 10.241, 10.438, 10.606, 10.754, 10.88, 10.975, 11.083, 11.157, 11.193, 11.252
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.65, 4.838, 5.27, 5.585, 5.843, 6.26, 6.588, 7.486, 8.353, 8.614, 8.854, 9.095, 9.294, 9.46, 9.608, 9.733, 9.828, 9.936, 10.011, 10.047, 10.106
        end
      elsif num_bore_holes == 7
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.683, 3.059, 3.467, 4.164, 4.994, 6.319, 8.011, 9.482, 11.494, 12.679, 13.511, 14.651, 15.427, 17.139, 18.601, 18.999, 19.359, 19.714, 19.992, 20.233, 20.443, 20.621, 20.755, 20.91, 21.017, 21.069, 21.156
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.342, 3.795, 4.329, 5.214, 6.465, 7.635, 9.435, 10.54, 11.327, 12.421, 13.178, 14.861, 16.292, 16.685, 17.038, 17.386, 17.661, 17.896, 18.101, 18.276, 18.408, 18.56, 18.663, 18.714, 18.797
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.672, 4.009, 4.519, 5.253, 5.965, 7.304, 8.204, 8.882, 9.866, 10.566, 12.145, 13.555, 13.941, 14.29, 14.631, 14.899, 15.129, 15.331, 15.502, 15.631, 15.778, 15.879, 15.928, 16.009
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.312, 4.694, 4.975, 5.629, 6.127, 6.54, 7.207, 7.723, 9.019, 10.314, 10.68, 11.023, 11.352, 11.617, 11.842, 12.04, 12.209, 12.335, 12.48, 12.579, 12.627, 12.705
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.65, 4.838, 5.275, 5.595, 5.861, 6.304, 6.665, 7.709, 8.785, 9.121, 9.434, 9.749, 10.013, 10.233, 10.43, 10.597, 10.723, 10.868, 10.967, 11.015, 11.094
        end
      elsif num_bore_holes == 9
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.683, 3.061, 3.47, 4.178, 5.039, 6.472, 8.405, 10.147, 12.609, 14.086, 15.131, 16.568, 17.55, 19.72, 21.571, 22.073, 22.529, 22.976, 23.327, 23.632, 23.896, 24.121, 24.29, 24.485, 24.619, 24.684, 24.795
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.025, 3.343, 3.798, 4.338, 5.248, 6.588, 7.902, 10.018, 11.355, 12.321, 13.679, 14.625, 16.74, 18.541, 19.036, 19.478, 19.916, 20.261, 20.555, 20.812, 21.031, 21.197, 21.387, 21.517, 21.58, 21.683
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.672, 4.01, 4.524, 5.27, 6.01, 7.467, 8.489, 9.281, 10.452, 11.299, 13.241, 14.995, 15.476, 15.912, 16.337, 16.67, 16.957, 17.208, 17.421, 17.581, 17.764, 17.889, 17.95, 18.05
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.312, 4.695, 4.977, 5.639, 6.15, 6.583, 7.298, 7.869, 9.356, 10.902, 11.347, 11.766, 12.169, 12.495, 12.772, 13.017, 13.225, 13.381, 13.559, 13.681, 13.74, 13.837
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.65, 4.838, 5.277, 5.6, 5.87, 6.322, 6.698, 7.823, 9.044, 9.438, 9.809, 10.188, 10.506, 10.774, 11.015, 11.219, 11.374, 11.552, 11.674, 11.733, 11.83
        end
      end
    elsif bore_config == Constants.BoreConfigOpenRectangle
      if num_bore_holes == 8
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.684, 3.066, 3.497, 4.275, 5.229, 6.767, 8.724, 10.417, 12.723, 14.079, 15.03, 16.332, 17.217, 19.17, 20.835, 21.288, 21.698, 22.101, 22.417, 22.692, 22.931, 23.133, 23.286, 23.462, 23.583, 23.642, 23.742
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.026, 3.347, 3.821, 4.409, 5.418, 6.87, 8.226, 10.299, 11.565, 12.466, 13.716, 14.58, 16.498, 18.125, 18.572, 18.972, 19.368, 19.679, 19.946, 20.179, 20.376, 20.527, 20.699, 20.816, 20.874, 20.967
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.673, 4.018, 4.564, 5.389, 6.21, 7.763, 8.801, 9.582, 10.709, 11.51, 13.311, 14.912, 15.349, 15.744, 16.13, 16.432, 16.693, 16.921, 17.114, 17.259, 17.426, 17.54, 17.595, 17.686
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.313, 4.704, 4.999, 5.725, 6.294, 6.771, 7.543, 8.14, 9.629, 11.105, 11.52, 11.908, 12.28, 12.578, 12.831, 13.054, 13.244, 13.386, 13.548, 13.659, 13.712, 13.8
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.651, 4.839, 5.293, 5.641, 5.938, 6.44, 6.856, 8.062, 9.297, 9.681, 10.036, 10.394, 10.692, 10.941, 11.163, 11.35, 11.492, 11.654, 11.766, 11.819, 11.907
        end
      elsif num_bore_holes == 10
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.684, 3.066, 3.494, 4.262, 5.213, 6.81, 8.965, 10.906, 13.643, 15.283, 16.443, 18.038, 19.126, 21.532, 23.581, 24.138, 24.642, 25.137, 25.525, 25.862, 26.155, 26.403, 26.59, 26.806, 26.955, 27.027, 27.149
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.026, 3.346, 3.818, 4.399, 5.4, 6.889, 8.358, 10.713, 12.198, 13.27, 14.776, 15.824, 18.167, 20.158, 20.704, 21.194, 21.677, 22.057, 22.382, 22.666, 22.907, 23.09, 23.3, 23.443, 23.513, 23.627
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.673, 4.018, 4.559, 5.374, 6.193, 7.814, 8.951, 9.831, 11.13, 12.069, 14.219, 16.154, 16.684, 17.164, 17.631, 17.998, 18.314, 18.59, 18.824, 19, 19.201, 19.338, 19.405, 19.515
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.313, 4.703, 4.996, 5.712, 6.275, 6.755, 7.549, 8.183, 9.832, 11.54, 12.029, 12.49, 12.933, 13.29, 13.594, 13.862, 14.09, 14.26, 14.455, 14.588, 14.652, 14.758
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.651, 4.839, 5.292, 5.636, 5.928, 6.425, 6.841, 8.089, 9.44, 9.875, 10.284, 10.7, 11.05, 11.344, 11.608, 11.831, 12.001, 12.196, 12.329, 12.393, 12.499
        end
      end
    elsif bore_config == Constants.BoreConfigRectangle
      if num_bore_holes == 4
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.684, 3.066, 3.493, 4.223, 5.025, 6.131, 7.338, 8.291, 9.533, 10.244, 10.737, 11.409, 11.865, 12.869, 13.73, 13.965, 14.178, 14.388, 14.553, 14.696, 14.821, 14.927, 15.007, 15.099, 15.162, 15.193, 15.245
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.026, 3.347, 3.818, 4.383, 5.255, 6.314, 7.188, 8.392, 9.087, 9.571, 10.233, 10.686, 11.685, 12.536, 12.77, 12.98, 13.189, 13.353, 13.494, 13.617, 13.721, 13.801, 13.892, 13.955, 13.985, 14.035
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.673, 4.018, 4.555, 5.313, 5.984, 7.069, 7.717, 8.177, 8.817, 9.258, 10.229, 11.083, 11.316, 11.527, 11.733, 11.895, 12.035, 12.157, 12.261, 12.339, 12.429, 12.491, 12.521, 12.57
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.313, 4.703, 4.998, 5.69, 6.18, 6.557, 7.115, 7.514, 8.428, 9.27, 9.501, 9.715, 9.92, 10.083, 10.221, 10.343, 10.447, 10.525, 10.614, 10.675, 10.704, 10.753
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.306, 4.651, 4.839, 5.293, 5.633, 5.913, 6.355, 6.693, 7.559, 8.343, 8.57, 8.776, 8.979, 9.147, 9.286, 9.409, 9.512, 9.59, 9.68, 9.741, 9.771, 9.819
        end
      elsif num_bore_holes == 6
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.684, 3.074, 3.526, 4.349, 5.308, 6.719, 8.363, 9.72, 11.52, 12.562, 13.289, 14.282, 14.956, 16.441, 17.711, 18.057, 18.371, 18.679, 18.921, 19.132, 19.315, 19.47, 19.587, 19.722, 19.815, 19.861, 19.937
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.026, 3.351, 3.847, 4.472, 5.499, 6.844, 8.016, 9.702, 10.701, 11.403, 12.369, 13.032, 14.502, 15.749, 16.093, 16.4, 16.705, 16.945, 17.15, 17.329, 17.482, 17.598, 17.731, 17.822, 17.866, 17.938
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.675, 4.028, 4.605, 5.471, 6.283, 7.688, 8.567, 9.207, 10.112, 10.744, 12.149, 13.389, 13.727, 14.033, 14.332, 14.567, 14.769, 14.946, 15.096, 15.21, 15.339, 15.428, 15.471, 15.542
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.314, 4.714, 5.024, 5.798, 6.378, 6.841, 7.553, 8.079, 9.327, 10.512, 10.84, 11.145, 11.437, 11.671, 11.869, 12.044, 12.192, 12.303, 12.431, 12.518, 12.56, 12.629
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.307, 4.652, 4.841, 5.313, 5.684, 5.999, 6.517, 6.927, 8.034, 9.087, 9.401, 9.688, 9.974, 10.21, 10.408, 10.583, 10.73, 10.841, 10.969, 11.056, 11.098, 11.167
        end
      elsif num_bore_holes == 8
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.685, 3.078, 3.543, 4.414, 5.459, 7.06, 9.021, 10.701, 12.991, 14.34, 15.287, 16.586, 17.471, 19.423, 21.091, 21.545, 21.956, 22.36, 22.677, 22.953, 23.192, 23.395, 23.548, 23.725, 23.847, 23.906, 24.006
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.027, 3.354, 3.862, 4.517, 5.627, 7.142, 8.525, 10.589, 11.846, 12.741, 13.986, 14.847, 16.762, 18.391, 18.839, 19.24, 19.637, 19.95, 20.217, 20.45, 20.649, 20.8, 20.973, 21.091, 21.148, 21.242
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.675, 4.033, 4.63, 5.553, 6.444, 8.051, 9.096, 9.874, 10.995, 11.79, 13.583, 15.182, 15.619, 16.016, 16.402, 16.705, 16.967, 17.195, 17.389, 17.535, 17.702, 17.817, 17.873, 17.964
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.315, 4.719, 5.038, 5.852, 6.48, 6.993, 7.799, 8.409, 9.902, 11.371, 11.784, 12.17, 12.541, 12.839, 13.092, 13.315, 13.505, 13.647, 13.81, 13.921, 13.975, 14.063
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.307, 4.653, 4.842, 5.323, 5.71, 6.042, 6.6, 7.05, 8.306, 9.552, 9.935, 10.288, 10.644, 10.94, 11.188, 11.409, 11.596, 11.738, 11.9, 12.011, 12.065, 12.153
        end
      elsif num_bore_holes == 9
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.685, 3.082, 3.561, 4.49, 5.635, 7.436, 9.672, 11.59, 14.193, 15.721, 16.791, 18.256, 19.252, 21.447, 23.318, 23.826, 24.287, 24.74, 25.095, 25.404, 25.672, 25.899, 26.071, 26.269, 26.405, 26.471, 26.583
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.027, 3.357, 3.879, 4.57, 5.781, 7.488, 9.052, 11.408, 12.84, 13.855, 15.263, 16.235, 18.39, 20.216, 20.717, 21.166, 21.61, 21.959, 22.257, 22.519, 22.74, 22.909, 23.102, 23.234, 23.298, 23.403
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.676, 4.039, 4.659, 5.65, 6.633, 8.447, 9.638, 10.525, 11.802, 12.705, 14.731, 16.525, 17.014, 17.456, 17.887, 18.225, 18.516, 18.77, 18.986, 19.148, 19.334, 19.461, 19.523, 19.625
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.316, 4.725, 5.052, 5.917, 6.603, 7.173, 8.08, 8.772, 10.47, 12.131, 12.596, 13.029, 13.443, 13.775, 14.057, 14.304, 14.515, 14.673, 14.852, 14.975, 15.035, 15.132
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.307, 4.653, 4.842, 5.334, 5.739, 6.094, 6.7, 7.198, 8.611, 10.023, 10.456, 10.855, 11.256, 11.588, 11.866, 12.112, 12.32, 12.477, 12.656, 12.779, 12.839, 12.935
        end
      elsif num_bore_holes == 10
        if spacing_to_depth_ratio <= 0.02
          gfnc_coeff = 2.685, 3.08, 3.553, 4.453, 5.552, 7.282, 9.472, 11.405, 14.111, 15.737, 16.888, 18.476, 19.562, 21.966, 24.021, 24.579, 25.086, 25.583, 25.973, 26.311, 26.606, 26.855, 27.043, 27.26, 27.409, 27.482, 27.605
        elsif spacing_to_depth_ratio <= 0.03
          gfnc_coeff = 2.679, 3.027, 3.355, 3.871, 4.545, 5.706, 7.332, 8.863, 11.218, 12.688, 13.749, 15.242, 16.284, 18.618, 20.613, 21.161, 21.652, 22.138, 22.521, 22.847, 23.133, 23.376, 23.56, 23.771, 23.915, 23.985, 24.1
        elsif spacing_to_depth_ratio <= 0.05
          gfnc_coeff = 2.679, 3.023, 3.319, 3.676, 4.036, 4.645, 5.603, 6.543, 8.285, 9.449, 10.332, 11.623, 12.553, 14.682, 16.613, 17.143, 17.624, 18.094, 18.462, 18.78, 19.057, 19.293, 19.47, 19.673, 19.811, 19.879, 19.989
        elsif spacing_to_depth_ratio <= 0.1
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.962, 4.315, 4.722, 5.045, 5.885, 6.543, 7.086, 7.954, 8.621, 10.291, 11.988, 12.473, 12.931, 13.371, 13.727, 14.03, 14.299, 14.527, 14.698, 14.894, 15.027, 15.092, 15.199
        else
          gfnc_coeff = 2.679, 3.023, 3.318, 3.664, 3.961, 4.307, 4.653, 4.842, 5.329, 5.725, 6.069, 6.651, 7.126, 8.478, 9.863, 10.298, 10.704, 11.117, 11.463, 11.755, 12.016, 12.239, 12.407, 12.602, 12.735, 12.8, 12.906
        end
      end
    end
    return gfnc_coeff
  end

  def self.get_foundation_walls_ceilings_insulated(runner, space)
    # Check if walls insulated via Kiva:Foundation object
    walls_insulated = false
    space.surfaces.each do |surface|
      next if surface.surfaceType.downcase != 'wall'
      next if not surface.adjacentFoundation.is_initialized

      wall_ins_rvalue, wall_ins_height, wall_constr_rvalue = get_foundation_wall_insulation_props(runner, surface)
      if wall_ins_rvalue.nil? || wall_ins_height.nil? || wall_constr_rvalue.nil?
        return nil
      end

      wall_rvalue = wall_ins_rvalue + wall_constr_rvalue
      if wall_rvalue >= 3.0
        walls_insulated = true
      end
      break
    end

    # Check if ceilings insulated
    ceilings_insulated = false
    ceiling_ufactor = nil
    space.surfaces.each do |surface|
      next if surface.surfaceType.downcase != 'roofceiling'

      ceiling_ufactor = get_surface_ufactor(runner, surface, surface.surfaceType, true)
    end
    return if ceiling_ufactor.nil?

    ceiling_rvalue = 1.0 / UnitConversions.convert(ceiling_ufactor, 'm^2*k/w', 'hr*ft^2*f/btu')
    if ceiling_rvalue >= 3.0
      ceilings_insulated = true
    end

    return walls_insulated, ceilings_insulated
  end

  def self.get_foundation_wall_insulation_props(runner, surface)
    if surface.surfaceType.downcase != 'wall'
      return
    end

    # Get wall insulation R-value/height from Kiva:Foundation object
    if not surface.adjacentFoundation.is_initialized
      runner.registerError("Could not get foundation object for wall '#{surface.name}'.")
      return
    end
    foundation = surface.adjacentFoundation.get

    wall_ins_rvalue = 0.0
    wall_ins_height = 0.0
    if foundation.interiorVerticalInsulationMaterial.is_initialized
      int_mat = foundation.interiorVerticalInsulationMaterial.get.to_StandardOpaqueMaterial.get
      k = UnitConversions.convert(int_mat.thermalConductivity, 'W/(m*K)', 'Btu/(hr*ft*R)')
      thick = UnitConversions.convert(int_mat.thickness, 'm', 'ft')
      wall_ins_rvalue += thick / k
      wall_ins_height = UnitConversions.convert(foundation.interiorVerticalInsulationDepth.get, 'm', 'ft').round
    end
    if foundation.exteriorVerticalInsulationMaterial.is_initialized
      ext_mat = foundation.exteriorVerticalInsulationMaterial.get.to_StandardOpaqueMaterial.get
      k = UnitConversions.convert(ext_mat.thermalConductivity, 'W/(m*K)', 'Btu/(hr*ft*R)')
      thick = UnitConversions.convert(ext_mat.thickness, 'm', 'ft')
      wall_ins_rvalue += thick / k
      wall_ins_height = UnitConversions.convert(foundation.exteriorVerticalInsulationDepth.get, 'm', 'ft').round
    end

    wall_constr_rvalue = get_surface_ufactor(runner, surface, surface.surfaceType, true)

    return wall_ins_rvalue, wall_ins_height, wall_constr_rvalue
  end

  def self.get_feature(runner, obj, feature, datatype, register_error = true)
    val = nil
    if datatype == 'string'
      val = obj.additionalProperties.getFeatureAsString(feature)
    elsif datatype == 'double'
      val = obj.additionalProperties.getFeatureAsDouble(feature)
    elsif datatype == 'boolean'
      val = obj.additionalProperties.getFeatureAsBoolean(feature)
    end
    if not val.is_initialized
      if register_error
        runner.registerError("Could not find additionalProperties value for '#{feature}' with datatype #{datatype} on object #{obj.name}.")
      end
      return
    end
    return val.get
  end

  def self.setObjectValues(runner, model, unit, hvac, ducts, unit_final)
    # Updates object properties in the model

    model_plant_loops = model.getPlantLoops

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)
    control_and_slave_zones = HVAC.get_control_and_slave_zones(thermal_zones)

    # Unitary System - Air Loop
    thermal_zones.each do |thermal_zone|
      unitary_system_air_loops = HVAC.get_unitary_system_air_loops(model, runner, thermal_zone)
      unitary_system_air_loops.each do |unitary_system_air_loop|
        system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
        next if system.nil?

        # Fan Airflow
        if system.name.to_s.start_with?(Constants.ObjectNameAirSourceHeatPump) ||
           system.name.to_s.start_with?(Constants.ObjectNameGroundSourceHeatPumpVerticalBore) ||
           system.name.to_s.start_with?(Constants.ObjectNameMiniSplitHeatPump)
          fan_airflow = [unit_final.Heat_Airflow, unit_final.Cool_Airflow].max
        elsif system.name.to_s.start_with? Constants.ObjectNameCentralAirConditioner
          if hvac.HasFurnace
            fan_airflow = [unit_final.Heat_Airflow, unit_final.Cool_Airflow].max
          else
            fan_airflow = unit_final.Cool_Airflow
          end
        elsif system.name.to_s.start_with? Constants.ObjectNameFurnace
          if hvac.HasCentralAirConditioner
            fan_airflow = [unit_final.Heat_Airflow, unit_final.Cool_Airflow].max
          else
            fan_airflow = unit_final.Heat_Airflow
          end
        else
          runner.registerError('Unexpected unitary system.')
          return false
        end

        # Unitary System
        system.setSupplyAirFlowRateMethodDuringCoolingOperation('SupplyAirFlowRate')
        if not clg_coil.nil?
          system.setSupplyAirFlowRateDuringCoolingOperation(UnitConversions.convert(unit_final.Cool_Airflow, 'cfm', 'm^3/s'))
        else
          system.setSupplyAirFlowRateDuringCoolingOperation(0.0)
        end
        system.setSupplyAirFlowRateMethodDuringHeatingOperation('SupplyAirFlowRate')
        if not htg_coil.nil?
          system.setSupplyAirFlowRateDuringHeatingOperation(UnitConversions.convert(unit_final.Heat_Airflow, 'cfm', 'm^3/s'))
        else
          system.setSupplyAirFlowRateDuringHeatingOperation(0.0)
        end

        # Fan
        fanonoff = system.supplyFan.get.to_FanOnOff.get
        fanonoff.setMaximumFlowRate(hvac.FanspeedRatioCooling.max * UnitConversions.convert(fan_airflow + 0.01, 'cfm', 'm^3/s'))

        # Air Loop
        air_loop.setDesignSupplyAirFlowRate(hvac.FanspeedRatioCooling.max * UnitConversions.convert(fan_airflow, 'cfm', 'm^3/s'))

        thermal_zone.airLoopHVACTerminals.each do |aterm|
          next if air_loop != aterm.airLoopHVAC.get
          next unless aterm.to_AirTerminalSingleDuctUncontrolled.is_initialized

          aterm = aterm.to_AirTerminalSingleDuctUncontrolled.get
          aterm.setMaximumAirFlowRate(UnitConversions.convert(fan_airflow, 'cfm', 'm^3/s') * unit_final.Zone_Ratios[thermal_zone])
        end

        # Coils
        setCoilsObjectValues(runner, unit, hvac, system, unit_final, 1.0)

        model_plant_loops.each do |pl|
          has_gshp = false
          pl.supplyComponents.each do |supply_component|
            next if (not supply_component.to_GroundHeatExchangerVertical.is_initialized) && (not supply_component.to_GroundHeatExchangerHorizontalTrench.is_initialized)

            has_gshp = true
          end

          next if not has_gshp

          # Ground Source Heat Pump
          pl.supplyComponents.each do |plc|
            if plc.to_GroundHeatExchangerVertical.is_initialized
              # Ground Heat Exchanger Vertical
              ground_heat_exch_vert = plc.to_GroundHeatExchangerVertical.get
              ground_heat_exch_vert.setDesignFlowRate(UnitConversions.convert(unit_final.GSHP_Loop_flow, 'gal/min', 'm^3/s'))
              ground_heat_exch_vert.setNumberofBoreHoles(unit_final.GSHP_Bore_Holes.to_i)
              ground_heat_exch_vert.setBoreHoleLength(UnitConversions.convert(unit_final.GSHP_Bore_Depth, 'ft', 'm'))
              ground_heat_exch_vert.removeAllGFunctions
              for i in 0..(unit_final.GSHP_G_Functions[0].size - 1)
                ground_heat_exch_vert.addGFunction(unit_final.GSHP_G_Functions[0][i], unit_final.GSHP_G_Functions[1][i])
              end

            elsif plc.to_PumpVariableSpeed.is_initialized
              # Pump
              pump = plc.to_PumpVariableSpeed.get
              pump.setRatedFlowRate(UnitConversions.convert(unit_final.GSHP_Loop_flow, 'gal/min', 'm^3/s'))

            end
          end

          # Plant Loop
          pl.setMaximumLoopFlowRate(UnitConversions.convert(unit_final.GSHP_Loop_flow, 'gal/min', 'm^3/s'))
        end
      end
    end

    # Unitary System - Zone HVAC
    thermal_zones.each do |thermal_zone|
      unitary_system_zone_hvacs = HVAC.get_unitary_system_zone_hvacs(model, runner, thermal_zone)
      unitary_system_zone_hvacs.each do |unitary_system_zone_hvac|
        system, clg_coil, htg_coil = unitary_system_zone_hvac
        next if system.nil?

        # Fan Airflow
        if system.name.to_s.start_with? Constants.ObjectNameUnitHeater
          fan_airflow = unit_final.Heat_Airflow
        else
          runner.registerError('Unexpected unitary system.')
          return false
        end

        # Unitary System
        system.setSupplyAirFlowRateMethodDuringCoolingOperation('SupplyAirFlowRate')
        if not clg_coil.nil?
          system.setSupplyAirFlowRateDuringCoolingOperation(UnitConversions.convert(unit_final.Cool_Airflow * unit_final.Zone_Ratios[thermal_zone], 'cfm', 'm^3/s'))
        else
          system.setSupplyAirFlowRateDuringCoolingOperation(0.0)
        end
        system.setSupplyAirFlowRateMethodDuringHeatingOperation('SupplyAirFlowRate')
        if not htg_coil.nil?
          system.setSupplyAirFlowRateDuringHeatingOperation(UnitConversions.convert(unit_final.Heat_Airflow * unit_final.Zone_Ratios[thermal_zone], 'cfm', 'm^3/s'))
        else
          system.setSupplyAirFlowRateDuringHeatingOperation(0.0)
        end

        # Fan
        fanonoff = system.supplyFan.get.to_FanOnOff.get
        fanonoff.setMaximumFlowRate(UnitConversions.convert(fan_airflow + 0.01, 'cfm', 'm^3/s') * unit_final.Zone_Ratios[thermal_zone])

        # Coils
        setCoilsObjectValues(runner, unit, hvac, system, unit_final, unit_final.Zone_Ratios[thermal_zone])
      end
    end

    # Window AC
    thermal_zones.each do |thermal_zone|
      ptacs = HVAC.get_ptacs(model, runner, thermal_zone)
      ptacs.each do |ptac|
        # PTAC
        ptac.setSupplyAirFlowRateDuringCoolingOperation(UnitConversions.convert(unit_final.Cool_Airflow * unit_final.Zone_Ratios[thermal_zone], 'cfm', 'm^3/s'))
        ptac.setSupplyAirFlowRateDuringHeatingOperation(0.00001)
        ptac.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(0.0)
        ptac.setOutdoorAirFlowRateDuringCoolingOperation(0.0)
        ptac.setOutdoorAirFlowRateDuringHeatingOperation(0.0)
        ptac.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(0.0)

        # Fan
        fanonoff = ptac.supplyAirFan.to_FanOnOff.get
        fanonoff.setMaximumFlowRate(UnitConversions.convert(unit_final.Cool_Airflow * unit_final.Zone_Ratios[thermal_zone], 'cfm', 'm^3/s'))

        # Coils
        setCoilsObjectValues(runner, unit, hvac, ptac, unit_final, unit_final.Zone_Ratios[thermal_zone])

        # Heating Coil override
        ptac_htg_coil = ptac.heatingCoil.to_CoilHeatingElectric.get
        ptac_htg_coil.setNominalCapacity(0.0)
      end
    end

    # Electric Baseboard
    thermal_zones.each do |thermal_zone|
      baseboards = HVAC.get_baseboard_electrics(model, runner, thermal_zone)
      baseboards.each do |baseboard|
        baseboard.setNominalCapacity(UnitConversions.convert(unit_final.Heat_Capacity * unit_final.Zone_Ratios[thermal_zone], 'Btu/hr', 'W'))
      end
    end

    # Hot Water Baseboard
    thermal_zones.each do |thermal_zone|
      baseboards = HVAC.get_baseboard_waters(model, runner, thermal_zone)
      baseboards.each do |baseboard|
        bb_UA = UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'W') / UnitConversions.convert(hvac.BoilerDesignTemp - 10.0 - 95.0, 'R', 'K') * 3.0
        bb_max_flow = UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'W') / UnitConversions.convert(20.0, 'R', 'K') / 4.186 / 998.2 / 1000.0 * 2.0

        # Coils
        setCoilsObjectValues(runner, unit, hvac, baseboard, unit_final, 1.0)

        # Baseboard Coil
        coilHeatingWaterBaseboard = baseboard.heatingCoil.to_CoilHeatingWaterBaseboard.get
        coilHeatingWaterBaseboard.setUFactorTimesAreaValue(bb_UA)
        coilHeatingWaterBaseboard.setMaximumWaterFlowRate(bb_max_flow)
        coilHeatingWaterBaseboard.setHeatingDesignCapacityMethod('autosize')

        pl = baseboard.heatingCoil.plantLoop.get
        pl.components.each do |plc|
          # Boiler
          if plc.to_BoilerHotWater.is_initialized
            boiler = plc.to_BoilerHotWater.get
            boiler.setNominalCapacity(UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'W'))
          end

          # Pump
          if plc.to_PumpVariableSpeed.is_initialized
            pump = plc.to_PumpVariableSpeed.get
            pump.setRatedFlowRate(UnitConversions.convert(unit_final.Heat_Capacity / 20.0 / 500.0, 'gal/min', 'm^3/s'))
          end
        end
      end
    end

    # Dehumidifier
    thermal_zones.each do |thermal_zone|
      dehums = HVAC.get_dehumidifiers(model, runner, thermal_zone)
      dehums.each do |dehum|
        if dehum.ratedWaterRemoval == Constants.small # Autosized
          # Use a minimum capacity of 20 pints/day
          water_removal_rate = [unit_final.Dehumid_WaterRemoval, UnitConversions.convert(20.0, 'pint', 'L')].max # L/day
          dehum.setRatedWaterRemoval(water_removal_rate)
        else
          water_removal_rate = dehum.ratedWaterRemoval
        end

        if dehum.ratedEnergyFactor == Constants.small # Autosized
          # Select an Energy Factor based on ENERGY STAR requirements
          water_removal_rate_pints = UnitConversions.convert(water_removal_rate, 'L', 'pint')
          if water_removal_rate_pints <= 25.0
            energy_factor = 1.2
          elsif water_removal_rate_pints <= 35.0
            energy_factor = 1.4
          elsif water_removal_rate_pints <= 45.0
            energy_factor = 1.5
          elsif water_removal_rate_pints <= 54.0
            energy_factor = 1.6
          elsif water_removal_rate_pints <= 75.0
            energy_factor = 1.8
          else
            energy_factor = 2.5
          end
          dehum.setRatedEnergyFactor(energy_factor)
        else
          energy_factor = dehum.ratedEnergyFactor
        end

        next unless dehum.ratedAirFlowRate == Constants.small # Autosized

        # Calculate the dehumidifier air flow rate by assuming 2.75 cfm/pint/day (based on experimental test data)
        air_flow_rate = UnitConversions.convert(water_removal_rate, 'L', 'pint') * UnitConversions.convert(2.75, 'cfm', 'm^3/s')
        dehum.setRatedAirFlowRate(air_flow_rate)
      end
    end

    return true
  end

  def self.setCoilsObjectValues(runner, unit, hvac, equip, unit_final, zone_ratio)
    # zone_ratio is 1.0 unless there are multiple coils for the system (e.g., living coil and finished basement coil)

    clg_coil, htg_coil, supp_htg_coil = HVAC.get_coils_from_hvac_equip(equip)

    # Cooling coil
    if clg_coil.is_a? OpenStudio::Model::CoilCoolingDXSingleSpeed
      clg_coil.setRatedTotalCoolingCapacity(zone_ratio * UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'W'))
      clg_coil.setRatedAirFlowRate(zone_ratio * UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton') * UnitConversions.convert(hvac.RatedCFMperTonCooling[0], 'cfm', 'm^3/s'))

      # Adjust COP as appropriate
      clg_coil.setRatedCOP(clg_coil.ratedCOP.get * unit_final.EER_Multiplier)

    elsif clg_coil.is_a? OpenStudio::Model::CoilCoolingDXMultiSpeed
      clg_coil.stages.each_with_index do |stage, speed|
        stage.setGrossRatedTotalCoolingCapacity(zone_ratio * UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'W') * hvac.CapacityRatioCooling[speed])
        if clg_coil.name.to_s.start_with?(Constants.ObjectNameAirSourceHeatPump) || clg_coil.name.to_s.start_with?(Constants.ObjectNameCentralAirConditioner)
          stage.setRatedAirFlowRate(zone_ratio * UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton') * UnitConversions.convert(hvac.RatedCFMperTonCooling[speed], 'cfm', 'm^3/s') * hvac.CapacityRatioCooling[speed])
        elsif clg_coil.name.to_s.start_with? Constants.ObjectNameMiniSplitHeatPump
          stage.setRatedAirFlowRate(zone_ratio * UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'ton') * UnitConversions.convert(hvac.CoolingCFMs[speed], 'cfm', 'm^3/s'))
        end

        # Adjust COP as appropriate
        stage.setGrossRatedCoolingCOP(stage.grossRatedCoolingCOP * unit_final.EER_Multiplier)
      end

    elsif clg_coil.is_a? OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit
      clg_coil.setRatedAirFlowRate(zone_ratio * UnitConversions.convert(unit_final.Cool_Airflow, 'cfm', 'm^3/s'))
      clg_coil.setRatedWaterFlowRate(zone_ratio * UnitConversions.convert(unit_final.GSHP_Loop_flow, 'gal/min', 'm^3/s'))
      clg_coil.setRatedTotalCoolingCapacity(zone_ratio * UnitConversions.convert(unit_final.Cool_Capacity, 'Btu/hr', 'W'))
      clg_coil.setRatedSensibleCoolingCapacity(zone_ratio * UnitConversions.convert(unit_final.Cool_Capacity_Sens, 'Btu/hr', 'W'))

    end

    # Heating coil
    if htg_coil.is_a? OpenStudio::Model::CoilHeatingElectric
      if not equip.is_a? OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner
        htg_coil.setNominalCapacity(zone_ratio * UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'W'))
      end

    elsif htg_coil.is_a? OpenStudio::Model::CoilHeatingGas
      htg_coil.setNominalCapacity(zone_ratio * UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'W'))

    elsif htg_coil.is_a? OpenStudio::Model::CoilHeatingDXSingleSpeed
      htg_coil.setRatedTotalHeatingCapacity(zone_ratio * UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'W'))
      htg_coil.setRatedAirFlowRate(zone_ratio * UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'ton') * UnitConversions.convert(hvac.RatedCFMperTonHeating[0], 'cfm', 'm^3/s'))

      # Adjust COP as appropriate
      htg_coil.setRatedCOP(htg_coil.ratedCOP * unit_final.COP_Multiplier)

    elsif htg_coil.is_a? OpenStudio::Model::CoilHeatingDXMultiSpeed
      htg_coil.stages.each_with_index do |stage, speed|
        stage.setGrossRatedHeatingCapacity(zone_ratio * UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'W') * hvac.CapacityRatioHeating[speed])
        if htg_coil.name.to_s.start_with? Constants.ObjectNameAirSourceHeatPump
          stage.setRatedAirFlowRate(zone_ratio * UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'ton') * UnitConversions.convert(hvac.RatedCFMperTonHeating[speed], 'cfm', 'm^3/s') * hvac.CapacityRatioHeating[speed])
        elsif htg_coil.name.to_s.start_with? Constants.ObjectNameMiniSplitHeatPump
          stage.setRatedAirFlowRate(zone_ratio * UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'ton') * UnitConversions.convert(hvac.HeatingCFMs[speed], 'cfm', 'm^3/s'))
        end

        # Adjust COP as appropriate
        stage.setGrossRatedHeatingCOP(stage.grossRatedHeatingCOP * unit_final.COP_Multiplier)
      end

    elsif htg_coil.is_a? OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit
      htg_coil.setRatedAirFlowRate(zone_ratio * UnitConversions.convert(unit_final.Heat_Airflow, 'cfm', 'm^3/s'))
      htg_coil.setRatedWaterFlowRate(zone_ratio * UnitConversions.convert(unit_final.GSHP_Loop_flow, 'gal/min', 'm^3/s'))
      htg_coil.setRatedHeatingCapacity(zone_ratio * UnitConversions.convert(unit_final.Heat_Capacity, 'Btu/hr', 'W'))

    end

    # Supplemental heating coil
    if supp_htg_coil.is_a? OpenStudio::Model::CoilHeatingElectric
      supp_htg_coil.setNominalCapacity(UnitConversions.convert(unit_final.Heat_Capacity_Supp, 'Btu/hr', 'W'))

    end

    return true
  end

  def self.display_zone_loads(runner, unit, zone_loads)
    zone_loads.keys.each do |thermal_zone|
      loads = zone_loads[thermal_zone]
      s = "#{unit.name} Zone Loads for #{thermal_zone.name}:"
      properties = [
        :Heat_Windows, :Heat_Skylights,
        :Heat_Doors, :Heat_Walls,
        :Heat_Roofs, :Heat_Floors,
        :Heat_Infil,
        :Cool_Windows, :Cool_Skylights,
        :Cool_Doors, :Cool_Walls,
        :Cool_Roofs, :Cool_Floors,
        :Cool_Infil_Sens, :Cool_Infil_Lat,
        :Cool_IntGains_Sens, :Cool_IntGains_Lat,
        :Dehumid_Windows, :Dehumid_Skylights,
        :Dehumid_Doors, :Dehumid_Walls,
        :Dehumid_Roofs, :Dehumid_Floors,
        :Dehumid_Infil_Sens, :Dehumid_Infil_Lat,
        :Dehumid_IntGains_Sens, :Dehumid_IntGains_Lat,
      ]
      properties.each do |property|
        s += "\n#{property.to_s.gsub('_', ' ')} = #{loads.send(property).round(0)} Btu/hr"
      end
      runner.registerInfo("#{s}\n")
    end
  end

  def self.display_unit_initial_results(runner, unit, unit_init)
    s = "#{unit.name} Initial Results (w/o ducts):"
    loads = [
      :Heat_Load, :Cool_Load_Sens, :Cool_Load_Lat,
      :Dehumid_Load_Sens, :Dehumid_Load_Lat,
    ]
    airflows = [
      :Heat_Airflow, :Cool_Airflow,
    ]
    loads.each do |load|
      s += "\n#{load.to_s.gsub('_', ' ')} = #{unit_init.send(load).round(0)} Btu/hr"
    end
    airflows.each do |airflow|
      s += "\n#{airflow.to_s.gsub('_', ' ')} = #{unit_init.send(airflow).round(0)} cfm"
    end
    runner.registerInfo("#{s}\n")
  end

  def self.display_unit_final_results(runner, unit, unit_final)
    s = "#{unit.name} Final Results:"
    loads = [
      :Heat_Load, :Heat_Load_Ducts,
      :Cool_Load_Lat, :Cool_Load_Sens,
      :Cool_Load_Ducts_Lat, :Cool_Load_Ducts_Sens,
      :Dehumid_Load_Sens, :Dehumid_Load_Ducts_Lat,
    ]
    caps = [
      :Cool_Capacity, :Cool_Capacity_Sens,
      :Heat_Capacity, :Heat_Capacity_Supp,
    ]
    airflows = [
      :Cool_Airflow, :Heat_Airflow,
    ]
    waters = [
      :Dehumid_WaterRemoval,
    ]
    loads.each do |load|
      s += "\n#{load.to_s.gsub('_', ' ')} = #{unit_final.send(load).round(0)} Btu/hr"
    end
    caps.each do |cap|
      s += "\n#{cap.to_s.gsub('_', ' ')} = #{unit_final.send(cap).round(0)} Btu/hr"
    end
    airflows.each do |airflow|
      s += "\n#{airflow.to_s.gsub('_', ' ')} = #{unit_final.send(airflow).round(0)} cfm"
    end
    waters.each do |water|
      s += "\n#{water.to_s.gsub('_', ' ')} = #{unit_final.send(water).round(0)} L/day"
    end
    runner.registerInfo("#{s}\n")
  end
end

class MJ8
  def initialize
  end
  attr_accessor(:daily_range_temp_adjust, :acf, :Cs, :Cw,
                :cool_setpoint, :heat_setpoint, :cool_design_grains, :dehum_design_grains, :ctd, :htd,
                :dtd, :daily_range_num, :grains_indoor_cooling, :wetbulb_indoor_cooling, :enthalpy_indoor_cooling,
                :RH_indoor_dehumid, :grains_indoor_dehumid, :wetbulb_indoor_dehumid, :LAT,
                :cool_design_temps, :heat_design_temps, :dehum_design_temps)
end

class ZoneValues
  # Thermal zone loads
  def initialize
  end
  attr_accessor(:Cool_Windows, :Cool_Skylights, :Cool_Doors, :Cool_Walls, :Cool_Roofs, :Cool_Floors,
                :Dehumid_Windows, :Dehumid_Skylights, :Dehumid_Doors, :Dehumid_Walls, :Dehumid_Roofs, :Dehumid_Floors,
                :Heat_Windows, :Heat_Skylights, :Heat_Doors, :Heat_Walls, :Heat_Roofs, :Heat_Floors,
                :Cool_Infil_Sens, :Cool_Infil_Lat, :Cool_IntGains_Sens, :Cool_IntGains_Lat,
                :Dehumid_Infil_Sens, :Dehumid_Infil_Lat, :Dehumid_IntGains_Sens, :Dehumid_IntGains_Lat,
                :Heat_Infil)
end

class UnitInitialValues
  # Unit initial loads (aggregated across thermal zones and excluding ducts) and airflow rates
  def initialize
  end
  attr_accessor(:Cool_Load_Sens, :Cool_Load_Lat, :Cool_Load_Tot, :Cool_Airflow,
                :Dehumid_Load_Sens, :Dehumid_Load_Lat,
                :Heat_Load, :Heat_Airflow,
                :LAT)
end

class UnitFinalValues
  # Unit final loads (including ducts), airflow rates, and equipment capacities
  def initialize
  end
  attr_accessor(:Cool_Load_Sens, :Cool_Load_Lat, :Cool_Load_Tot,
                :Cool_Load_Ducts_Sens, :Cool_Load_Ducts_Lat, :Cool_Load_Ducts_Tot,
                :Cool_Capacity, :Cool_Capacity_Sens, :Cool_Airflow,
                :Dehumid_Load_Sens, :Dehumid_Load_Ducts_Lat,
                :Heat_Load, :Heat_Load_Ducts,
                :Heat_Capacity, :Heat_Capacity_Supp, :Heat_Airflow,
                :dse_Fregain, :Dehumid_WaterRemoval,
                :TotalCap_CurveValue, :SensibleCap_CurveValue, :BypassFactor_CurveValue,
                :Zone_Ratios, :EER_Multiplier, :COP_Multiplier,
                :GSHP_Loop_flow, :GSHP_Bore_Holes, :GSHP_Bore_Depth, :GSHP_G_Functions)
end

class HVACInfo
  # Model info for HVAC
  def initialize
  end
  attr_accessor(:HasCooling, :HasHeating, :HasDuctedCooling, :HasDuctedHeating,
                :FixedCoolingCapacity, :FixedHeatingCapacity, :FixedSuppHeatingCapacity,
                :HasCentralAirConditioner, :HasRoomAirConditioner, :HasUnitHeater,
                :HasFurnace, :HasBoiler, :HasElecBaseboard, :HasDehumidifier,
                :HasAirSourceHeatPump, :HasMiniSplitHeatPump, :HasGroundSourceHeatPump,
                :NumSpeedsCooling, :NumSpeedsHeating, :CoolingCFMs, :HeatingCFMs,
                :COOL_CAP_FT_SPEC, :HEAT_CAP_FT_SPEC, :COOL_SH_FT_SPEC, :COIL_BF_FT_SPEC,
                :HtgSupplyAirTemp, :SHRRated, :CapacityRatioCooling, :CapacityRatioHeating,
                :MinOutdoorTemp, :HeatingCapacityOffset, :OverSizeLimit, :HPSizedForMaxLoad,
                :FanspeedRatioCooling, :CapacityDerateFactorEER, :CapacityDerateFactorCOP,
                :BoilerDesignTemp, :Dehumidifier_Water_Remove_Cap_Ft_DB_RH, :CoilBF,
                :GroundHXVertical, :HeatingEIR, :CoolingEIR,
                :HXDTDesign, :HXCHWDesign, :HXHWDesign,
                :RatedCFMperTonCooling, :RatedCFMperTonHeating,
                :GSHPBoreSpacing, :GSHPBoreHoles, :GSHPBoreDepth,
                :GSHPBoreConfig, :GSHPSpacingType, :HeatingLoadFraction, :CoolingLoadFraction)
end

class DuctsInfo
  # Model info for ducts
  def initial
  end
  attr_accessor(:Has, :NotInLiving, :SupplySurfaceArea, :ReturnSurfaceArea,
                :SupplyLoss, :ReturnLoss, :SupplyRvalue, :ReturnRvalue,
                :Location, :LocationSpace, :LocationFrac)
end

class Numeric
  def deg2rad
    self * Math::PI / 180
  end

  def rad2deg
    self * 180 / Math::PI
  end
end
