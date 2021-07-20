# frozen_string_literal: true

require_relative 'constants'
require_relative 'unit_conversions'
require_relative 'weather'
require_relative 'schedules'
require_relative 'waterheater'

class Refrigerator
  def self.apply(model, unit, runner, rated_annual_energy, mult,
                 weekday_sch, weekend_sch, monthly_sch, sch, space)

    # check for valid inputs
    if rated_annual_energy < 0
      runner.registerError('Rated annual consumption must be greater than or equal to 0.')
      return false
    end
    if mult < 0
      runner.registerError('Occupancy energy multiplier must be greater than or equal to 0.')
      return false
    end

    unit_obj_name = Constants.ObjectNameRefrigerator(unit.name.to_s)

    # Design day schedules used when autosizing
    winter_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    winter_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    summer_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    summer_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

    # Get number of days in months/year
    year_description = model.getYearDescription
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)

    # Calculate fridge daily energy use
    ann_e = rated_annual_energy * mult

    if ann_e > 0

      if sch.nil?
        # Create schedule
        sch = MonthWeekdayWeekendSchedule.new(model, runner, Constants.ObjectNameRefrigerator + ' schedule', weekday_sch, weekend_sch, monthly_sch, mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = true, create_sch_object = true, winter_design_day_sch = winter_design_day_sch, summer_design_day_sch = summer_design_day_sch, schedule_type_limits_name = Constants.ScheduleTypeLimitsFraction)
        if not sch.validated?
          return false
        end
      end

      design_level = sch.calcDesignLevelFromDailykWh(ann_e / num_days_in_year)

      # Add electric equipment for the fridge
      frg_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      frg = OpenStudio::Model::ElectricEquipment.new(frg_def)
      frg.setName(unit_obj_name)
      frg.setEndUseSubcategory(unit_obj_name)
      frg.setSpace(space)
      frg_def.setName(unit_obj_name)
      frg_def.setDesignLevel(design_level)
      frg_def.setFractionRadiant(0.0)
      frg_def.setFractionLatent(0.0)
      frg_def.setFractionLost(0.0)
      frg.setSchedule(sch.schedule)

    end

    return true, ann_e, sch
  end

  def self.remove(runner, space, obj_name)
    # Remove any existing refrigerator
    objects_to_remove = []
    space.electricEquipment.each do |space_equipment|
      next if not space_equipment.name.to_s.start_with? obj_name

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.electricEquipmentDefinition
      if space_equipment.schedule.is_initialized
        objects_to_remove << space_equipment.schedule.get
      end
    end
    if objects_to_remove.size > 0
      runner.registerInfo("Removed existing refrigerator from space '#{space.name}'.")
    end
    objects_to_remove.uniq.each do |object|
      begin
        object.remove
      rescue
        # no op
      end
    end
  end
end

class ClothesWasher
  # @param schedules_file [SchedulesFile]
  def self.apply(model, unit, runner, imef, rated_annual_energy, annual_cost,
                 test_date, drum_volume, cold_cycle, thermostatic_control,
                 internal_heater, fill_sensor, mult_e, mult_hw, cd_sch,
                 space, plant_loop, mains_temps, water_sch, schedules_file)

    # Check for valid inputs
    if imef <= 0
      runner.registerError('Integrated modified energy factor must be greater than 0.0.')
      return false
    end
    if rated_annual_energy <= 0
      runner.registerError('Rated annual consumption must be greater than 0.0.')
      return false
    end
    if annual_cost <= 0
      runner.registerError('Annual cost with gas DHW must be greater than 0.0.')
      return false
    end
    if test_date < 1900
      runner.registerError('Test date must be greater than or equal to 1900.')
      return false
    end
    if drum_volume <= 0
      runner.registerError('Drum volume must be greater than 0.0.')
      return false
    end
    if mult_e < 0
      runner.registerError('Occupancy energy multiplier must be greater than or equal to 0.0.')
      return false
    end
    if mult_hw < 0
      runner.registerError('Occupancy hot water multiplier must be greater than or equal to 0.0.')
      return false
    end

    # Get unit beds/baths/occupants
    nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
    if nbeds.nil? || nbaths.nil?
      return false
    end

    noccupants = Geometry.get_unit_occupants(model, unit, runner)

    # Get water heater setpoint
    wh_setpoint = Waterheater.get_water_heater_setpoint(model, plant_loop, runner)
    if wh_setpoint.nil?
      return false
    end

    # Get number of days in months/year
    year_description = model.getYearDescription
    num_days_in_months = Constants.NumDaysInMonths(year_description.isLeapYear)
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)

    if mains_temps.nil?
      # Get mains monthly temperatures
      site = model.getSite
      if !site.siteWaterMainsTemperature.is_initialized
        runner.registerError('Mains water temperature has not been set.')
        return false
      end
      waterMainsTemperature = site.siteWaterMainsTemperature.get
      avgOAT = UnitConversions.convert(waterMainsTemperature.annualAverageOutdoorAirTemperature.get, 'C', 'F')
      maxDiffMonthlyAvgOAT = UnitConversions.convert(waterMainsTemperature.maximumDifferenceInMonthlyAverageOutdoorAirTemperatures.get, 'K', 'R')
      mains_temps = WeatherProcess.calc_mains_temperatures(avgOAT, maxDiffMonthlyAvgOAT, site.latitude, num_days_in_year)[1]
    end

    unit_obj_name = Constants.ObjectNameClothesWasher(unit.name.to_s)

    # Use EnergyGuide Label test data to calculate per-cycle energy and water consumption.
    # Calculations are based on "Method for Evaluating Energy Use of Dishwashers, Clothes Washers,
    # and Clothes Dryers" by Eastment and Hendron, Conference Paper NREL/CP-550-39769, August 2006.
    # Their paper is in part based on the energy use calculations  presented in the 10CFR Part 430,
    # Subpt. B, App. J1 (DOE 1999),
    # http://ecfr.gpoaccess.gov/cgi/t/text/text-idx?c=ecfr&tpl=/ecfrbrowse/Title10/10cfr430_main_02.tpl

    # Set the number of cycles per year for test conditions
    cycles_per_year_test = 392 # (see Eastment and Hendron, NREL/CP-550-39769, 2006)

    # The water heater recovery efficiency - how efficiently the heat from natural gas is transferred
    # to the water in the water heater. The DOE 10CFR Part 430 assumes a nominal gas water heater
    # recovery efficiency of 0.75.
    gas_dhw_heater_efficiency_test = 0.75

    # Calculate test load weight (correlation based on data in Table 5.1 of 10CFR Part 430,
    # Subpt. B, App. J1, DOE 1999)
    test_load = 4.103003337 * drum_volume + 0.198242492 # lb

    # Set the Hot Water Inlet Temperature for test conditions
    if test_date < 2004
      # (see 10CFR Part 430, Subpt. B, App. J, Section 2.3, DOE 1999)
      hot_water_inlet_temperature_test = 140 # degF
    elsif test_date >= 2004
      # (see 10CFR Part 430, Subpt. B, App. J1, Section 2.3, DOE 1999)
      hot_water_inlet_temperature_test = 135 # degF
    end

    # Set the cold water inlet temperature for test conditions (see 10CFR Part 430, Subpt. B, App. J,
    # Section 2.3, DOE 1999)
    cold_water_inlet_temp_test = 60 # degF

    # Set/calculate the hot water fraction and mixed water temperature for test conditions.
    # Washer varies relative amounts of hot and cold water (by opening and closing valves) to achieve
    # a specific wash temperature. This includes the option to simulate washers operating on cold
    # cycle only (cold_cycle = True). This is an operating choice for the occupant - the
    # washer itself was tested under normal test conditions (not cold cycle).
    if thermostatic_control
      # (see p. 10 of Eastment and Hendron, NREL/CP-550-39769, 2006)
      mixed_cycle_temperature_test = 92.5 # degF
      # (eq. 17 Eastment and Hendron, NREL/CP-550-39769, 2006)
      hot_water_vol_frac_test = ((mixed_cycle_temperature_test - cold_water_inlet_temp_test) /
                                (hot_water_inlet_temperature_test - cold_water_inlet_temp_test))
    else
      # Note: if washer only has cold water supply then the following code will run and
      # incorrectly set the hot water fraction to 0.5. However, the code below will correctly
      # determine hot and cold water usage.
      hot_water_vol_frac_test = 0.5
      mixed_cycle_temperature_test = ((hot_water_inlet_temperature_test - cold_water_inlet_temp_test) * \
                                     hot_water_vol_frac_test + cold_water_inlet_temp_test) # degF
    end

    # Determine the Gas use for domestic hot water per cycle for test conditions
    energy_guide_gas_cost = EnergyGuideLabel.get_energy_guide_gas_cost(test_date) / 100
    energy_guide_elec_cost = EnergyGuideLabel.get_energy_guide_elec_cost(test_date) / 100

    # Use the EnergyGuide Label information (eq. 4 Eastment and Hendron, NREL/CP-550-39769, 2006).
    gas_consumption_for_dhw_per_cycle_test = ((rated_annual_energy * energy_guide_elec_cost -
                                                annual_cost) /
                                                (UnitConversions.convert(gas_dhw_heater_efficiency_test, 'therm', 'kWh') *
                                                energy_guide_elec_cost - energy_guide_gas_cost) /
                                                cycles_per_year_test) # therms/cycle

    # Use additional EnergyGuide Label information to determine how  much electricity was used in
    # the test to power the clothes washer's internal machinery (eq. 5 Eastment and Hendron,
    # NREL/CP-550-39769, 2006). Any energy required for internal water heating will be included
    # in this value.
    elec_use_per_cycle_test = (rated_annual_energy / cycles_per_year_test -
                                 gas_consumption_for_dhw_per_cycle_test *
                                 UnitConversions.convert(gas_dhw_heater_efficiency_test, 'therm', 'kWh')) # kWh/cycle

    if test_date < 2004
      # (see 10CFR Part 430, Subpt. B, App. J, Section 4.1.2, DOE 1999)
      dhw_deltaT_test = 90
    else
      # (see 10CFR Part 430, Subpt. B, App. J1, Section 4.1.2, DOE 1999)
      dhw_deltaT_test = 75
    end

    # Determine how much hot water was used in the test based on the amount of gas used in the
    # test to heat the water and the temperature rise in the water heater in the test (eq. 6
    # Eastment and Hendron, NREL/CP-550-39769, 2006).
    water_dens = Liquid.H2O_l.rho # lbm/ft^3
    water_sh = Liquid.H2O_l.cp # Btu/lbm-R
    dhw_use_per_cycle_test = ((UnitConversions.convert(gas_consumption_for_dhw_per_cycle_test, 'therm', 'kWh') *
                                gas_dhw_heater_efficiency_test) / (dhw_deltaT_test *
                                water_dens * water_sh * UnitConversions.convert(1.0, 'Btu', 'kWh') / UnitConversions.convert(1.0, 'ft^3', 'gal')))

    if fill_sensor && (test_date < 2004)
      # For vertical axis washers that are sensor-filled, use a multiplying factor of 0.94
      # (see 10CFR Part 430, Subpt. B, App. J, Section 4.1.2, DOE 1999)
      dhw_use_per_cycle_test /= 0.94
    end

    # Calculate total per-cycle usage of water (combined from hot and cold supply).
    # Note that the actual total amount of water used per cycle is assumed to be the same as
    # the total amount of water used per cycle in the test. Under actual conditions, however,
    # the ratio of hot and cold water can vary with thermostatic control (see below).
    actual_total_per_cycle_water_use = dhw_use_per_cycle_test / hot_water_vol_frac_test # gal/cycle

    # Set actual clothes washer water temperature for calculations below.
    if cold_cycle
      # To model occupant behavior of using only a cold cycle.
      water_temp = mains_temps.inject(:+) / 12 # degF
    elsif thermostatic_control
      # Washer is being operated "normally" - at the same temperature as in the test.
      water_temp = mixed_cycle_temperature_test # degF
    else
      water_temp = wh_setpoint # degF
    end

    # (eq. 14 Eastment and Hendron, NREL/CP-550-39769, 2006)
    if [Constants.BuildingTypeMultifamily, Constants.BuildingTypeSingleFamilyAttached].include? Geometry.get_building_type(model) # multifamily equation
      actual_cycles_per_year = (cycles_per_year_test * (0.5 + (-0.68 + 1.09 * noccupants) / 6) * (12.5 / test_load)) # cycles/year
    elsif [Constants.BuildingTypeSingleFamilyDetached].include? Geometry.get_building_type(model) # single-family equation
      actual_cycles_per_year = (cycles_per_year_test * (0.5 + (-1.47 + 1.69 * noccupants) / 6) * (12.5 / test_load)) # cycles/year
    end

    total_daily_water_use = (actual_total_per_cycle_water_use * actual_cycles_per_year /
                             num_days_in_year) # gal/day

    # Calculate actual DHW use and elecricity use.
    # First calculate per-cycle usages.
    #    If the clothes washer has thermostatic control, then the test per-cycle DHW usage
    #    amounts will have to be adjusted (up or down) to account for differences between
    #    actual water supply temperatures and test conditions. If the clothes washer has
    #    an internal heater, then the test per-cycle electricity usage amounts will have to
    #    be adjusted (up or down) to account for differences between actual water supply
    #    temperatures and hot water amounts and test conditions.
    # The calculations are done on a monthly basis to reflect monthly variations in TMains
    # temperatures. Per-cycle amounts are then used to calculate monthly amounts and finally
    # daily amounts.

    monthly_dhw = Array.new(12, 0)
    monthly_energy = Array.new(12, 0)

    mains_temps.each_with_index do |monthly_main, i|
      # Adjust per-cycle DHW amount.
      if thermostatic_control
        # If the washer has thermostatic control then its use of DHW will vary as the
        # cold and hot water supply temperatures vary.

        if cold_cycle && (monthly_main >= water_temp)
          # In this special case, the washer uses only a cold cycle and the TMains
          # temperature exceeds the desired cold cycle temperature. In this case, no
          # DHW will be used (the adjustment is -100%). A special calculation is
          # needed here since the formula for the general case (below) would imply
          # that a negative volume of DHW is used.
          dhw_use_per_cycle_adjustment = -1 * dhw_use_per_cycle_test # gal/cycle

        else
          # With thermostatic control, the washer will adjust the amount of hot water
          # when either the hot water or cold water supply temperatures vary (eq. 18
          # Eastment and Hendron, NREL/CP-550-39769, 2006).
          dhw_use_per_cycle_adjustment = (dhw_use_per_cycle_test *
                                            ((1 / hot_water_vol_frac_test) *
                                            (water_temp - monthly_main) +
                                            monthly_main - wh_setpoint) /
                                            (wh_setpoint - monthly_main)) # gal/cycle

        end

      else
        # Without thermostatic control, the washer will not adjust the amount of hot water.
        dhw_use_per_cycle_adjustment = 0 # gal/cycle
      end

      # Calculate actual water usage amounts for the current month in the loop.
      actual_dhw_use_per_cycle = (dhw_use_per_cycle_test +
                                    dhw_use_per_cycle_adjustment) # gal/cycle

      # Adjust per-cycle electricity amount.
      if internal_heater
        # If the washer heats the water internally, then its use of electricity will vary
        # as the cold and hot water supply temperatures vary.

        # Calculate cold water usage per cycle to facilitate calculation of electricity
        # usage below.
        actual_cold_water_use_per_cycle = (actual_total_per_cycle_water_use -
                                             actual_dhw_use_per_cycle) # gal/cycle

        # With an internal heater, the washer will adjust its heating (up or down) when
        # actual conditions differ from test conditions according to the following three
        # equations. Compensation for changes in sensible heat due to:
        # 1) a difference in hot water supply temperatures and
        # 2) a difference in cold water supply temperatures
        # (modified version of eq. 20 Eastment and Hendron, NREL/CP-550-39769, 2006).
        elec_use_per_cycle_adjustment_supply_temps = ((actual_dhw_use_per_cycle *
                                                        (hot_water_inlet_temperature_test -
                                                        wh_setpoint) +
                                                        actual_cold_water_use_per_cycle *
                                                        (cold_water_inlet_temp_test -
                                                        monthly_main)) *
                                                        (water_dens * water_sh *
                                                        UnitConversions.convert(1.0, 'Btu', 'kWh') /
                                                        UnitConversions.convert(1.0, 'ft^3', 'gal'))) # kWh/cycle

        # Compensation for the change in sensible heat due to a difference in hot water
        # amounts due to thermostatic control.
        elec_use_per_cycle_adjustment_hot_water_amount = (dhw_use_per_cycle_adjustment *
                                                            (cold_water_inlet_temp_test -
                                                            hot_water_inlet_temperature_test) *
                                                            (water_dens * water_sh *
                                                            UnitConversions.convert(1.0, 'Btu', 'kWh') /
                                                            UnitConversions.convert(1.0, 'ft^3', 'gal'))) # kWh/cycle

        # Compensation for the change in sensible heat due to a difference in operating
        # temperature vs. test temperature (applies only to cold cycle only).
        # Note: This adjustment can result in the calculation of zero electricity use
        # per cycle below. This would not be correct (the washer will always use some
        # electricity to operate). However, if the washer has an internal heater, it is
        # not possible to determine how much of the electricity was  used for internal
        # heating of water and how much for other machine operations.
        elec_use_per_cycle_adjustment_operating_temp = (actual_total_per_cycle_water_use *
                                                          (water_temp - mixed_cycle_temperature_test) *
                                                          (water_dens * water_sh *
                                                          UnitConversions.convert(1.0, 'Btu', 'kWh') /
                                                          UnitConversions.convert(1.0, 'ft^3', 'gal'))) # kWh/cycle

        # Sum the three adjustments above
        elec_use_per_cycle_adjustment = elec_use_per_cycle_adjustment_supply_temps +
                                        elec_use_per_cycle_adjustment_hot_water_amount +
                                        elec_use_per_cycle_adjustment_operating_temp

      else

        elec_use_per_cycle_adjustment = 0 # kWh/cycle

      end

      # Calculate actual electricity usage amount for the current month in the loop.
      actual_elec_use_per_cycle = (elec_use_per_cycle_test +
                                     elec_use_per_cycle_adjustment) # kWh/cycle

      # Do not allow negative electricity use
      if actual_elec_use_per_cycle < 0
        actual_elec_use_per_cycle = 0
      end

      # Calculate monthly totals
      monthly_dhw[i] = ((actual_dhw_use_per_cycle *
                         actual_cycles_per_year *
                         num_days_in_months[i] / num_days_in_year)) # gal/month
      monthly_energy[i] = ((actual_elec_use_per_cycle *
                            actual_cycles_per_year *
                            num_days_in_months[i] / num_days_in_year)) # kWh/month
    end

    daily_energy = monthly_energy.inject(:+) / num_days_in_year

    daily_energy *= mult_e
    total_daily_water_use *= mult_hw

    ann_e = daily_energy * num_days_in_year

    cd_updated = false

    water_col_name = 'clothes_washer'
    power_col_name = 'clothes_washer_power'
    if ann_e > 0

      if water_sch.nil?
        water_sch = schedules_file.create_schedule_file(col_name: water_col_name)
        power_sch = schedules_file.create_schedule_file(col_name: power_col_name)
      else
        power_sch = water_sch
      end

      # Reuse existing water use connection if possible
      water_use_connection = nil
      plant_loop.demandComponents.each do |component|
        next unless component.to_WaterUseConnections.is_initialized

        water_use_connection = component.to_WaterUseConnections.get
        break
      end
      if water_use_connection.nil?
        # Need new water heater connection
        water_use_connection = OpenStudio::Model::WaterUseConnections.new(model)
        plant_loop.addDemandBranchForComponent(water_use_connection)
      end

      temperature_sch = OpenStudio::Model::ScheduleConstant.new(model) # FIXME
      temperature_sch.setValue(52.666)
      temperature_sch.setName("#{Constants.ObjectNameClothesWasher} temperature schedule")
      Schedule.set_schedule_type_limits(model, temperature_sch, Constants.ScheduleTypeLimitsTemperature)

      design_level = schedules_file.calc_design_level_from_daily_kwh(col_name: power_col_name, daily_kwh: daily_energy)
      peak_flow = schedules_file.calc_peak_flow_from_daily_gpm(col_name: water_col_name, daily_water: total_daily_water_use)
      # Add equipment for the cw
      cw_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      cw = OpenStudio::Model::ElectricEquipment.new(cw_def)
      cw.setName(unit_obj_name)
      cw.setEndUseSubcategory(unit_obj_name)
      cw.setSpace(space)
      cw_def.setName(unit_obj_name)
      cw_def.setDesignLevel(design_level)
      cw_def.setFractionRadiant(0.48)
      cw_def.setFractionLatent(0.0)
      cw_def.setFractionLost(0.2)
      cw.setSchedule(power_sch)

      # Add water use equipment for the dw
      cw_def2 = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
      cw2 = OpenStudio::Model::WaterUseEquipment.new(cw_def2)
      cw2.setName(unit_obj_name)
      cw2.setSpace(space)
      cw_def2.setName(unit_obj_name)
      cw_def2.setPeakFlowRate(peak_flow)
      cw_def2.setEndUseSubcategory(unit_obj_name)
      cw2.setFlowRateFractionSchedule(water_sch)
      cw_def2.setTargetTemperatureSchedule(temperature_sch)
      water_use_connection.addWaterUseEquipment(cw2)

      # Store some info for Clothes Dryer measures
      cw.additionalProperties.setFeature(Constants.ClothesWasherIMEF, imef)
      cw.additionalProperties.setFeature(Constants.ClothesWasherRatedAnnualEnergy, rated_annual_energy)
      cw.additionalProperties.setFeature(Constants.ClothesWasherDrumVolume, drum_volume)

      # Check if there's a clothes dryer that needs to be updated
      cd_unit_obj_name = Constants.ObjectNameClothesDryer(nil)
      cd = nil
      model.getElectricEquipments.each do |ee|
        next if not ee.name.to_s.start_with? cd_unit_obj_name
        next if not unit.spaces.include? ee.space.get

        cd = ee
      end
      model.getOtherEquipments.each do |oe|
        next if not oe.name.to_s.start_with? cd_unit_obj_name
        next if not unit.spaces.include? oe.space.get

        cd = oe
      end
      if not cd.nil?

        # Get clothes dryer properties
        cd_cef = cd.additionalProperties.getFeatureAsDouble(Constants.ClothesDryerCEF)
        cd_mult = cd.additionalProperties.getFeatureAsDouble(Constants.ClothesDryerMult)
        cd_fuel_type = cd.additionalProperties.getFeatureAsString(Constants.ClothesDryerFuelType)
        cd_fuel_split = cd.additionalProperties.getFeatureAsDouble(Constants.ClothesDryerFuelSplit)
        if !cd_cef.is_initialized || !cd_mult.is_initialized || !cd_fuel_type.is_initialized || !cd_fuel_split.is_initialized
          runner.registerError('Could not find clothes dryer properties.')
          return false
        end
        cd_cef = cd_cef.get
        cd_mult = cd_mult.get
        cd_fuel_type = cd_fuel_type.get
        cd_fuel_split = cd_fuel_split.get

        # Update clothes dryer
        cd_space = cd.space.get
        ClothesDryer.remove(runner, cd_space, cd_unit_obj_name, false)

        success, cd_ann_e, cd_ann_f, cd_sch = ClothesDryer.apply(model, unit, runner, cd_cef, cd_mult,
                                                                 cd_space, cd_fuel_type, cd_fuel_split, cd_sch, schedules_file)

        if not success
          return false
        end

        if (cd_ann_e > 0) || (cd_ann_f > 0)
          cd_updated = true
        end

      end

    end

    return true, ann_e, cd_updated, cd_sch, mains_temps
  end

  def self.remove(runner, space, obj_name)
    # Remove any existing clothes washer
    objects_to_remove = []
    space.electricEquipment.each do |space_equipment|
      next if not space_equipment.name.to_s.start_with? obj_name

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.electricEquipmentDefinition
      if space_equipment.schedule.is_initialized
        objects_to_remove << space_equipment.schedule.get
      end
    end
    space.waterUseEquipment.each do |space_equipment|
      next if not space_equipment.name.to_s.start_with? obj_name

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.waterUseEquipmentDefinition
      if space_equipment.flowRateFractionSchedule.is_initialized
        objects_to_remove << space_equipment.flowRateFractionSchedule.get
      end
      if space_equipment.waterUseEquipmentDefinition.targetTemperatureSchedule.is_initialized
        objects_to_remove << space_equipment.waterUseEquipmentDefinition.targetTemperatureSchedule.get
      end
    end
    if objects_to_remove.size > 0
      runner.registerInfo("Removed existing clothes washer from space '#{space.name}'.")
    end
    objects_to_remove.uniq.each do |object|
      begin
        object.remove
      rescue
        # no op
      end
    end
  end
end

class ClothesDryer
  # @param schedules_file [SchedulesFile]
  def self.apply(model, unit, runner, cef, mult, space, fuel_type, fuel_split, sch, schedules_file)
    # Check for valid inputs
    if cef <= 0
      runner.registerError('Combined energy factor must be greater than 0.0.')
      return false
    end
    if (fuel_split < 0) || (fuel_split > 1)
      runner.registerError('Assumed fuel electric split must be greater than or equal to 0.0 and less than or equal to 1.0.')
      return false
    end
    if mult < 0
      runner.registerError('Occupancy energy multiplier must be greater than or equal to 0.0.')
      return false
    end

    # Get unit beds/baths/occupants
    nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
    if nbeds.nil? || nbaths.nil?
      return false
    end

    noccupants = Geometry.get_unit_occupants(model, unit, runner)

    # Get number of days in months/year
    year_description = model.getYearDescription
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)

    # Get clothes washer properties
    cw = nil
    model.getElectricEquipments.each do |ee|
      next if ee.name.to_s != Constants.ObjectNameClothesWasher(unit.name.to_s)

      cw = ee
    end
    if cw.nil?
      runner.registerWarning('Could not find clothes washer equipment.')
      return
    end
    drum_volume = cw.additionalProperties.getFeatureAsDouble(Constants.ClothesWasherDrumVolume)
    imef = cw.additionalProperties.getFeatureAsDouble(Constants.ClothesWasherIMEF)
    rated_annual_energy = cw.additionalProperties.getFeatureAsDouble(Constants.ClothesWasherRatedAnnualEnergy)
    if !drum_volume.is_initialized || !imef.is_initialized || !rated_annual_energy.is_initialized
      runner.registerError('Could not find clothes washer properties.')
      return false
    end
    drum_volume = drum_volume.get
    imef = imef.get
    rated_annual_energy = rated_annual_energy.get

    unit_obj_name_e = Constants.ObjectNameClothesDryer(Constants.FuelTypeElectric, unit.name.to_s)
    unit_obj_name_f = Constants.ObjectNameClothesDryer(fuel_type, unit.name.to_s)

    ef = cef * 1.15 # RESNET interpretation
    cw_mef = 0.503 + 0.95 * imef # RESNET interpretation

    # Energy Use is based on "Method for Evaluating Energy Use of Dishwashers, Clothes
    # Washers, and Clothes Dryers" by Eastment and Hendron, Conference Paper NREL/CP-550-39769,
    # August 2006. Their paper is in part based on the energy use calculations presented in the
    # 10CFR Part 430, Subpt. B, App. D (DOE 1999),
    # http://ecfr.gpoaccess.gov/cgi/t/text/text-idx?c=ecfr&tpl=/ecfrbrowse/Title10/10cfr430_main_02.tpl
    # Eastment and Hendron present a method for estimating the energy consumption per cycle
    # based on the dryer's energy factor.

    # Set some intermediate variables. An experimentally determined value for the percent
    # reduction in the moisture content of the test load, expressed here as a fraction
    # (DOE 10CFR Part 430, Subpt. B, App. D, Section 4.1)
    dryer_nominal_reduction_in_moisture_content = 0.66
    # The fraction of washer loads dried in a clothes dryer (DOE 10CFR Part 430, Subpt. B,
    # App. J1, Section 4.3)
    dryer_usage_factor = 0.84
    load_adjustment_factor = 0.52

    # Set the number of cycles per year for test conditions
    cycles_per_year_test = 392 # (see Eastment and Hendron, NREL/CP-550-39769, 2006)

    # Calculate test load weight (correlation based on data in Table 5.1 of 10CFR Part 430,
    # Subpt. B, App. J1, DOE 1999)
    test_load = 4.103003337 * drum_volume + 0.198242492 # lb

    # Eq. 10 of Eastment and Hendron, NREL/CP-550-39769, 2006.
    dryer_energy_factor_std = 0.5 # Nominal drying energy required, kWh/lb dry cloth
    dryer_elec_per_year = (cycles_per_year_test * drum_volume / cw_mef -
                          rated_annual_energy) # kWh
    dryer_elec_per_cycle = dryer_elec_per_year / cycles_per_year_test # kWh
    remaining_moisture_after_spin = (dryer_elec_per_cycle / (load_adjustment_factor *
                                    dryer_energy_factor_std * dryer_usage_factor *
                                    test_load) + 0.04) # lb water/lb dry cloth
    cw_remaining_water = test_load * remaining_moisture_after_spin

    # Use the dryer energy factor and remaining water from the clothes washer to calculate
    # total energy use per cycle (eq. 7 Eastment and Hendron, NREL/CP-550-39769, 2006).
    actual_cd_energy_use_per_cycle = (cw_remaining_water / (ef *
                                     dryer_nominal_reduction_in_moisture_content)) # kWh/cycle

    if fuel_type == Constants.FuelTypeElectric
      # All energy use is electric.
      actual_cd_elec_use_per_cycle = actual_cd_energy_use_per_cycle # kWh/cycle
    else
      # Use assumed split between electricity and fuel use to calculate each.
      # eq. 8 of Eastment and Hendron, NREL/CP-550-39769, 2006
      actual_cd_elec_use_per_cycle = fuel_split * actual_cd_energy_use_per_cycle # kWh/cycle
      # eq. 9 of Eastment and Hendron, NREL/CP-550-39769, 2006
      actual_cd_fuel_use_per_cycle = (1 - fuel_split) * actual_cd_energy_use_per_cycle # kWh/cycle
    end

    # (eq. 14 Eastment and Hendron, NREL/CP-550-39769, 2006)
    if [Constants.BuildingTypeMultifamily, Constants.BuildingTypeSingleFamilyAttached].include? Geometry.get_building_type(model) # multifamily equation
      actual_cycles_per_year = (cycles_per_year_test * (0.5 + (-0.68 + 1.09 * noccupants) / 6) * (12.5 / test_load)) # cycles/year
    elsif [Constants.BuildingTypeSingleFamilyDetached].include? Geometry.get_building_type(model) # single-family equation
      actual_cycles_per_year = (cycles_per_year_test * (0.5 + (-1.47 + 1.69 * noccupants) / 6) * (12.5 / test_load)) # cycles/year
    end

    # eq. 15 of Eastment and Hendron, NREL/CP-550-39769, 2006
    actual_cd_cycles_per_year = dryer_usage_factor * actual_cycles_per_year # cycles/year

    daily_energy_elec = actual_cd_cycles_per_year * actual_cd_elec_use_per_cycle / num_days_in_year # kWh/day
    daily_energy_elec *= mult
    ann_e = daily_energy_elec * num_days_in_year # kWh/yr

    ann_f = 0
    if fuel_type != Constants.FuelTypeElectric
      daily_energy_fuel = actual_cd_cycles_per_year * actual_cd_fuel_use_per_cycle / num_days_in_year # kWh/day
      daily_energy_fuel = UnitConversions.convert(daily_energy_fuel * mult, 'kWh', 'therm') # therm/day
      ann_f = daily_energy_fuel * num_days_in_year # therms/yr
    end

    col_name = 'clothes_dryer'
    if (ann_e > 0) || (ann_f > 0)

      if sch.nil?
        sch = schedules_file.create_schedule_file(col_name: col_name)
      end

      # Add equipment for the cd
      if fuel_type == Constants.FuelTypeElectric

        design_level_e = schedules_file.calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: ann_e)

        cd_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
        cd = OpenStudio::Model::ElectricEquipment.new(cd_def)
        cd.setName(unit_obj_name_e)
        cd.setEndUseSubcategory(unit_obj_name_e)
        cd.setSpace(space)
        cd_def.setName(unit_obj_name_e)
        cd_def.setDesignLevel(design_level_e)
        cd_def.setFractionRadiant(0.09)
        cd_def.setFractionLatent(0.05)
        cd_def.setFractionLost(0.8)
        cd.setSchedule(sch)

      else

        design_level_e = schedules_file.calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: ann_e)

        if design_level_e > 0
          cd_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
          cd2 = OpenStudio::Model::ElectricEquipment.new(cd_def2)
          cd2.setName(unit_obj_name_e)
          cd2.setEndUseSubcategory(unit_obj_name_e)
          cd2.setSpace(space)
          cd_def2.setName(unit_obj_name_e)
          cd_def2.setDesignLevel(design_level_e)
          cd_def2.setFractionRadiant(0.6)
          cd_def2.setFractionLatent(0.0)
          cd_def2.setFractionLost(0.0)
          cd2.setSchedule(sch)
        end

        design_level_f = schedules_file.calc_design_level_from_annual_therm(col_name: col_name, annual_therm: ann_f)

        cd_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
        cd = OpenStudio::Model::OtherEquipment.new(cd_def)
        cd.setName(unit_obj_name_f)
        cd.setEndUseSubcategory(unit_obj_name_f)
        cd.setFuelType(HelperMethods.eplus_fuel_map(fuel_type))
        cd.setSpace(space)
        cd_def.setName(unit_obj_name_f)
        cd_def.setDesignLevel(design_level_f)
        cd_def.setFractionRadiant(0.06)
        cd_def.setFractionLatent(0.05)
        cd_def.setFractionLost(0.85)
        cd.setSchedule(sch)

      end

      cd.additionalProperties.setFeature(Constants.ClothesDryerCEF, cef.to_f)
      cd.additionalProperties.setFeature(Constants.ClothesDryerMult, mult.to_f)
      cd.additionalProperties.setFeature(Constants.ClothesDryerFuelType, fuel_type.to_s)
      cd.additionalProperties.setFeature(Constants.ClothesDryerFuelSplit, fuel_split.to_f)

    end

    return true, ann_e, ann_f, sch
  end

  def self.remove(runner, space, obj_name, display_remove_msg = true)
    # Remove any existing clothes dryer
    objects_to_remove = []
    space.electricEquipment.each do |space_equipment|
      next if not space_equipment.name.to_s.start_with? obj_name

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.electricEquipmentDefinition
      if space_equipment.schedule.is_initialized
        objects_to_remove << space_equipment.schedule.get
      end
    end
    space.otherEquipment.each do |space_equipment|
      next if not space_equipment.name.to_s.start_with? obj_name

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.otherEquipmentDefinition
      if space_equipment.schedule.is_initialized
        objects_to_remove << space_equipment.schedule.get
      end
    end
    if (objects_to_remove.size > 0) && display_remove_msg
      runner.registerInfo("Removed existing clothes dryer from space '#{space.name}'.")
    end
    objects_to_remove.uniq.each do |object|
      begin
        object.remove
      rescue
        # no op
      end
    end
  end
end

class CookingRange
  # @param schedules_file [SchedulesFile]
  def self.apply(model, unit, runner, fuel_type, cooktop_ef, oven_ef,
                 has_elec_ignition, mult, sch, space, schedules_file)

    # check for valid inputs
    if (oven_ef <= 0) || (oven_ef > 1)
      runner.registerError('Oven energy factor must be greater than 0 and less than or equal to 1.')
      return false
    end
    if (cooktop_ef <= 0) || (cooktop_ef > 1)
      runner.registerError('Cooktop energy factor must be greater than 0 and less than or equal to 1.')
      return false
    end
    if mult < 0
      runner.registerError('Occupancy energy multiplier must be greater than or equal to 0.')
      return false
    end

    # Get unit beds/baths/occupants
    nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
    if nbeds.nil? || nbaths.nil?
      return false
    end

    noccupants = Geometry.get_unit_occupants(model, unit, runner)

    unit_obj_name = Constants.ObjectNameCookingRange(fuel_type, unit.name.to_s)

    # Design day schedules used when autosizing
    winter_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    winter_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    summer_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    summer_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

    # Calculate range daily energy use
    if fuel_type == Constants.FuelTypeElectric
      if [Constants.BuildingTypeMultifamily, Constants.BuildingTypeSingleFamilyAttached].include? Geometry.get_building_type(model) # multifamily equation
        ann_e = ((66.8 + 31.5 * noccupants) / cooktop_ef + (11.3 + 5.3 * noccupants) / oven_ef) * mult # kWh/yr
      elsif [Constants.BuildingTypeSingleFamilyDetached].include? Geometry.get_building_type(model) # single-family equation
        ann_e = ((44.0 + 48.8 * noccupants) / cooktop_ef + (7.4 + 8.3 * noccupants) / oven_ef) * mult # kWh/yr
      end
      ann_f = 0
      ann_i = 0
    else
      ann_e = 0
      if [Constants.BuildingTypeMultifamily, Constants.BuildingTypeSingleFamilyAttached].include? Geometry.get_building_type(model) # multifamily equation
        ann_f = ((2.04 + 0.96 * noccupants) / cooktop_ef + (0.34 + 0.16 * noccupants) / oven_ef) * mult # therm/yr
      elsif [Constants.BuildingTypeSingleFamilyDetached].include? Geometry.get_building_type(model) # single-family equation
        ann_f = ((1.35 + 1.49 * noccupants) / cooktop_ef + (0.22 + 0.25 * noccupants) / oven_ef) * mult # therm/yr
      end
      if has_elec_ignition == true
        if [Constants.BuildingTypeMultifamily, Constants.BuildingTypeSingleFamilyAttached].include? Geometry.get_building_type(model) # multifamily equation
          ann_i = (30.95 + 14.50 * noccupants) * mult # kWh/yr
        elsif [Constants.BuildingTypeSingleFamilyDetached].include? Geometry.get_building_type(model) # single-family equation
          ann_i = (20.45 + 22.48 * noccupants) * mult # kWh/yr
        end
      else
        ann_i = 0
      end
    end

    col_name = 'cooking_range'
    if (ann_f > 0) || (ann_e > 0)

      if sch.nil?
        sch = schedules_file.create_schedule_file(col_name: col_name)
      end

    end

    if ann_f > 0

      design_level_f = schedules_file.calc_design_level_from_annual_therm(col_name: col_name, annual_therm: ann_f)
      design_level_i = schedules_file.calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: ann_i)

      # Add equipment for the range
      if has_elec_ignition == true
        unit_obj_name_i = Constants.ObjectNameCookingRange(Constants.FuelTypeElectric, unit.name.to_s)

        rng_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
        rng2 = OpenStudio::Model::ElectricEquipment.new(rng_def2)
        rng2.setName(unit_obj_name_i)
        rng2.setEndUseSubcategory(unit_obj_name_i)
        rng2.setSpace(space)
        rng_def2.setName(unit_obj_name_i)
        rng_def2.setDesignLevel(design_level_i)
        rng_def2.setFractionRadiant(0.24)
        rng_def2.setFractionLatent(0.3)
        rng_def2.setFractionLost(0.3)
        rng2.setSchedule(sch)
      end

      rng_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
      rng = OpenStudio::Model::OtherEquipment.new(rng_def)
      rng.setName(unit_obj_name)
      rng.setEndUseSubcategory(unit_obj_name)
      rng.setFuelType(HelperMethods.eplus_fuel_map(fuel_type))
      rng.setSpace(space)
      rng_def.setName(unit_obj_name)
      rng_def.setDesignLevel(design_level_f)
      rng_def.setFractionRadiant(0.18)
      rng_def.setFractionLatent(0.2)
      rng_def.setFractionLost(0.5)
      rng.setSchedule(sch)

    elsif ann_e > 0
      design_level_e = schedules_file.calc_design_level_from_annual_kwh(col_name: 'cooking_range', annual_kwh: ann_e)

      # Add equipment for the range
      rng_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      rng = OpenStudio::Model::ElectricEquipment.new(rng_def)
      rng.setName(unit_obj_name)
      rng.setEndUseSubcategory(unit_obj_name)
      rng.setSpace(space)
      rng_def.setName(unit_obj_name)
      rng_def.setDesignLevel(design_level_e)
      rng_def.setFractionRadiant(0.24)
      rng_def.setFractionLatent(0.3)
      rng_def.setFractionLost(0.3)
      rng.setSchedule(sch)

    end

    return true, ann_e, ann_f, ann_i, sch
  end

  def self.remove(runner, space, obj_name)
    # Remove any existing cooking range
    objects_to_remove = []
    space.electricEquipment.each do |space_equipment|
      next if not space_equipment.name.to_s.start_with? obj_name

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.electricEquipmentDefinition
      if space_equipment.schedule.is_initialized
        objects_to_remove << space_equipment.schedule.get
      end
    end
    space.otherEquipment.each do |space_equipment|
      next if not space_equipment.name.to_s.start_with? obj_name

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.otherEquipmentDefinition
      if space_equipment.schedule.is_initialized
        objects_to_remove << space_equipment.schedule.get
      end
    end
    if objects_to_remove.size > 0
      runner.registerInfo("Removed existing cooking range from space '#{space.name}'.")
    end
    objects_to_remove.uniq.each do |object|
      begin
        object.remove
      rescue
        # no op
      end
    end
  end
end

class Dishwasher
  # @param schedules_file [SchedulesFile]
  def self.apply(model, unit, runner, num_settings, rated_annual_energy,
                 cold_inlet, has_internal_heater, cold_use, test_date,
                 annual_gas_cost, mult_e, mult_hw, space, plant_loop,
                 mains_temps, water_sch, schedules_file)
    # Check for valid inputs
    if num_settings < 1
      runner.registerError('Number of place settings must be greater than or equal to 1.')
      return false
    end
    if rated_annual_energy < 0
      runner.registerError('Rated annual energy consumption must be greater than or equal to 0.')
      return false
    end
    if cold_use < 0
      runner.registerError('Cold water connection use must be greater than or equal to 0.')
      return false
    end
    if test_date < 1900
      runner.registerError('Energy Guide date must be greater than or equal to 1900.')
      return false
    end
    if annual_gas_cost <= 0
      runner.registerError('Energy Guide annual gas cost must be greater than 0.')
      return false
    end
    if mult_e < 0
      runner.registerError('Occupancy energy multiplier must be greater than or equal to 0.')
      return false
    end
    if mult_hw < 0
      runner.registerError('Occupancy hot water multiplier must be greater than or equal to 0.')
      return false
    end

    # Get unit beds/baths/occupants
    nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
    if nbeds.nil? || nbaths.nil?
      return false
    end

    noccupants = Geometry.get_unit_occupants(model, unit, runner)

    # Get water heater setpoint
    wh_setpoint = Waterheater.get_water_heater_setpoint(model, plant_loop, runner)
    if wh_setpoint.nil?
      return false
    end

    # Get number of days in months/year
    year_description = model.getYearDescription
    num_days_in_months = Constants.NumDaysInMonths(year_description.isLeapYear)
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)

    if cold_inlet && mains_temps.nil?
      # Get mains monthly temperatures if needed
      site = model.getSite
      if !site.siteWaterMainsTemperature.is_initialized
        runner.registerError('Mains water temperature has not been set.')
        return false
      end
      waterMainsTemperature = site.siteWaterMainsTemperature.get
      avgOAT = UnitConversions.convert(waterMainsTemperature.annualAverageOutdoorAirTemperature.get, 'C', 'F')
      maxDiffMonthlyAvgOAT = UnitConversions.convert(waterMainsTemperature.maximumDifferenceInMonthlyAverageOutdoorAirTemperatures.get, 'K', 'R')
      mains_temps = WeatherProcess.calc_mains_temperatures(avgOAT, maxDiffMonthlyAvgOAT, site.latitude, num_days_in_year)[1]
    end

    unit_obj_name = Constants.ObjectNameDishwasher(unit.name.to_s)

    # The water used in dishwashers must be heated, either internally or
    # externally, to at least 140 degF for proper operation (dissolving of
    # detergent, cleaning of dishes).
    operating_water_temp = 140 # degF

    water_dens = Liquid.H2O_l.rho # lbm/ft^3
    water_sh = Liquid.H2O_l.cp # Btu/lbm-R

    # Use EnergyGuide Label test data to calculate per-cycle energy and
    # water consumption. Calculations are based on "Method for
    # Evaluating Energy Use of Dishwashers, Clothes Washers, and
    # Clothes Dryers" by Eastment and Hendron, Conference Paper
    # NREL/CP-550-39769, August 2006. Their paper is in part based on
    # the energy use calculations presented in the 10CFR Part 430,
    # Subpt. B, App. C (DOE 1999),
    # http://ecfr.gpoaccess.gov/cgi/t/text/text-idx?c=ecfr&tpl=/ecfrbrowse/Title10/10cfr430_main_02.tpl
    if test_date <= 2002
      test_cycles_per_year = 322
    elsif test_date < 2004
      test_cycles_per_year = 264
    else
      test_cycles_per_year = 215
    end

    # The water heater recovery efficiency - how efficiently the heat
    # from natural gas is transferred to the water in the water heater.
    # The DOE 10CFR Part 430 assumes a nominal gas water heater
    # recovery efficiency of 0.75.
    test_gas_dhw_heater_efficiency = 0.75

    # Cold water supply temperature during tests (see 10CFR Part 430,
    # Subpt. B, App. C, Section 1.19, DOE 1999).
    test_mains_temp = 50 # degF
    # Hot water supply temperature during tests (see 10CFR Part 430,
    # Subpt. B, App. C, Section 1.19, DOE 1999).
    test_dhw_temp = 120 # degF

    # Determine the Gas use for domestic hot water per cycle for test conditions
    if cold_inlet
      test_gas_use_per_cycle = 0 # therms/cycle
    else
      # Use the EnergyGuide Label information (eq. 1 Eastment and
      # Hendron, NREL/CP-550-39769, 2006).
      rated_annual_eg_gas_cost = EnergyGuideLabel.get_energy_guide_gas_cost(test_date) / 100
      rated_annual_eg_elec_cost = EnergyGuideLabel.get_energy_guide_elec_cost(test_date) / 100
      test_gas_use_per_cycle = ((rated_annual_energy *
                                   rated_annual_eg_elec_cost -
                                   annual_gas_cost) /
                                  (UnitConversions.convert(test_gas_dhw_heater_efficiency, 'therm', 'kWh') *
                                   rated_annual_eg_elec_cost -
                                   rated_annual_eg_gas_cost) /
                                  test_cycles_per_year) # Therns/cycle
    end

    # Use additional EnergyGuide Label information to determine how much
    # electricity was used in the test to power the dishwasher's
    # internal machinery (eq. 2 Eastment and Hendron, NREL/CP-550-39769,
    # 2006). Any energy required for internal water heating will be
    # included in this value.
    test_rated_annual_elec_use_per_cycle = rated_annual_energy / \
                                           test_cycles_per_year - \
                                           UnitConversions.convert(test_gas_dhw_heater_efficiency, 'therm', 'kWh') * \
                                           test_gas_use_per_cycle # kWh/cycle

    if cold_inlet
      # for Type 3 Dishwashers - those with an electric element
      # internal to the machine to provide all of the water heating
      # (see Eastment and Hendron, NREL/CP-550-39769, 2006)
      test_dhw_use_per_cycle = 0 # gal/cycle
    else
      if has_internal_heater
        # for Type 2 Dishwashers - those with an electric element
        # internal to the machine for providing auxiliary water
        # heating (see Eastment and Hendron, NREL/CP-550-39769,
        # 2006)
        test_water_heater_temp_diff = test_dhw_temp - \
                                      test_mains_temp # degF water heater temperature rise in the test
      else
        test_water_heater_temp_diff = operating_water_temp - \
                                      test_mains_temp # water heater temperature rise in the test
      end

      # Determine how much hot water was used in the test based on
      # the amount of gas used in the test to heat the water and the
      # temperature rise in the water heater in the test (eq. 3
      # Eastment and Hendron, NREL/CP-550-39769, 2006).
      test_dhw_use_per_cycle = (UnitConversions.convert(test_gas_use_per_cycle, 'therm', 'kWh') * \
                                   test_gas_dhw_heater_efficiency) / \
                               (test_water_heater_temp_diff * \
                                water_dens * water_sh * \
                                UnitConversions.convert(1, 'Btu', 'kWh') / UnitConversions.convert(1, 'ft^3', 'gal')) # gal/cycle (hot water)
    end

    # (eq. 16 Eastment and Hendron, NREL/CP-550-39769, 2006)
    if [Constants.BuildingTypeMultifamily, Constants.BuildingTypeSingleFamilyAttached].include? Geometry.get_building_type(model) # multifamily equation
      actual_cycles_per_year = 215 * (0.5 + (-0.68 + 1.09 * noccupants) / 6) * (8 / num_settings) # cycles/year
    elsif [Constants.BuildingTypeSingleFamilyDetached].include? Geometry.get_building_type(model) # single-family equation
      actual_cycles_per_year = 215 * (0.5 + (-1.47 + 1.69 * noccupants) / 6) * (8 / num_settings) # cycles/year
    end

    daily_dishwasher_dhw = actual_cycles_per_year * test_dhw_use_per_cycle / num_days_in_year # gal/day (hot water)

    # Calculate total (hot or cold) daily water usage.
    if cold_inlet
      # From the 2010 BA Benchmark for dishwasher hot water
      # consumption. Should be appropriate for cold-water-inlet-only
      # dishwashers also.
      if [Constants.BuildingTypeMultifamily, Constants.BuildingTypeSingleFamilyAttached].include? Geometry.get_building_type(model) # multifamily equation
        daily_water = 1.93 + 0.91 * noccupants # gal/day
      elsif [Constants.BuildingTypeSingleFamilyDetached].include? Geometry.get_building_type(model) # single-family equation
        daily_water = 1.28 + 1.41 * noccupants # gal/day
      end
    else
      # Dishwasher uses only hot water so total water usage = DHW usage.
      daily_water = daily_dishwasher_dhw # gal/day
    end

    # Calculate actual electricity use per cycle by adjusting test
    # electricity use per cycle (up or down) to account for differences
    # between actual water supply temperatures and test conditions.
    # Also convert from per-cycle to daily electricity usage amounts.
    if cold_inlet

      monthly_energy = Array.new(12, 0)
      mains_temps.each_with_index do |monthly_main, i|
        # Adjust for monthly variation in Tmains vs. test cold
        # water supply temperature.
        actual_rated_annual_elec_use_per_cycle = test_rated_annual_elec_use_per_cycle + \
                                                 (test_mains_temp - monthly_main) * \
                                                 cold_use * \
                                                 (water_dens * water_sh * UnitConversions.convert(1, 'Btu', 'kWh') /
                                                 UnitConversions.convert(1, 'ft^3', 'gal')) # kWh/cycle
        monthly_energy[i] = (actual_rated_annual_elec_use_per_cycle * \
                                        num_days_in_months[i] * \
                                        actual_cycles_per_year / \
                                        num_days_in_year) # kWh/month
      end

      daily_energy = monthly_energy.inject(:+) / num_days_in_year # kWh/day

    elsif has_internal_heater

      # Adjust for difference in water heater supply temperature vs.
      # test hot water supply temperature.
      actual_rated_annual_elec_use_per_cycle = test_rated_annual_elec_use_per_cycle + \
                                               (test_dhw_temp - wh_setpoint) * \
                                               test_dhw_use_per_cycle * \
                                               (water_dens * water_sh * \
                                                UnitConversions.convert(1, 'Btu', 'kWh') /
                                                UnitConversions.convert(1, 'ft^3', 'gal')) # kWh/cycle
      daily_energy = actual_rated_annual_elec_use_per_cycle * \
                     actual_cycles_per_year / num_days_in_year # kWh/day

    else

      # Dishwasher has no internal heater
      actual_rated_annual_elec_use_per_cycle = test_rated_annual_elec_use_per_cycle # kWh/cycle
      daily_energy = actual_rated_annual_elec_use_per_cycle * \
                     actual_cycles_per_year / num_days_in_year # kWh/day

    end

    daily_energy *= mult_e
    daily_water *= mult_hw

    ann_e = daily_energy * num_days_in_year

    if daily_energy < 0
      runner.registerError('The inputs for the dishwasher resulted in a negative amount of energy consumption.')
      return false
    end

    water_col_name = 'dishwasher'
    power_col_name = 'dishwasher_power'
    if ann_e > 0

      if water_sch.nil?
        water_sch = schedules_file.create_schedule_file(col_name: water_col_name)
        power_sch = schedules_file.create_schedule_file(col_name: power_col_name)
      else
        power_sch = water_sch
      end

      # Reuse existing water use connection if possible
      water_use_connection = nil
      plant_loop.demandComponents.each do |component|
        next unless component.to_WaterUseConnections.is_initialized

        water_use_connection = component.to_WaterUseConnections.get
        break
      end
      if water_use_connection.nil?
        # Need new water heater connection
        water_use_connection = OpenStudio::Model::WaterUseConnections.new(model)
        plant_loop.addDemandBranchForComponent(water_use_connection)
      end

      temperature_sch = OpenStudio::Model::ScheduleConstant.new(model) # FIXME
      temperature_sch.setValue(52.666)
      temperature_sch.setName("#{Constants.ObjectNameDishwasher} temperature schedule")
      Schedule.set_schedule_type_limits(model, temperature_sch, Constants.ScheduleTypeLimitsTemperature)

      design_level = schedules_file.calc_design_level_from_daily_kwh(col_name: power_col_name, daily_kwh: daily_energy)
      peak_flow = schedules_file.calc_peak_flow_from_daily_gpm(col_name: water_col_name, daily_water: daily_water)

      # Add electric equipment for the dw
      dw_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      dw = OpenStudio::Model::ElectricEquipment.new(dw_def)
      dw.setName(unit_obj_name)
      dw.setEndUseSubcategory(unit_obj_name)
      dw.setSpace(space)
      dw_def.setName(unit_obj_name)
      dw_def.setDesignLevel(design_level)
      dw_def.setFractionRadiant(0.36)
      dw_def.setFractionLatent(0.15)
      dw_def.setFractionLost(0.25)
      dw.setSchedule(power_sch)

      # Add water use equipment for the dw
      dw_def2 = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
      dw2 = OpenStudio::Model::WaterUseEquipment.new(dw_def2)
      dw2.setName(unit_obj_name)
      dw2.setSpace(space)
      dw_def2.setName(unit_obj_name)
      dw_def2.setPeakFlowRate(peak_flow)
      dw_def2.setEndUseSubcategory(unit_obj_name)
      dw2.setFlowRateFractionSchedule(water_sch)
      dw_def2.setTargetTemperatureSchedule(temperature_sch)
      water_use_connection.addWaterUseEquipment(dw2)

    end

    return true, ann_e, mains_temps
  end

  def self.remove(runner, space, obj_name)
    # Remove any existing dishwasher
    objects_to_remove = []
    space.electricEquipment.each do |space_equipment|
      next if not space_equipment.name.to_s.start_with? obj_name

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.electricEquipmentDefinition
      if space_equipment.schedule.is_initialized
        objects_to_remove << space_equipment.schedule.get
      end
    end
    space.waterUseEquipment.each do |space_equipment|
      next if not space_equipment.name.to_s.start_with? obj_name

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.waterUseEquipmentDefinition
      if space_equipment.flowRateFractionSchedule.is_initialized
        objects_to_remove << space_equipment.flowRateFractionSchedule.get
      end
      if space_equipment.waterUseEquipmentDefinition.targetTemperatureSchedule.is_initialized
        objects_to_remove << space_equipment.waterUseEquipmentDefinition.targetTemperatureSchedule.get
      end
    end
    if objects_to_remove.size > 0
      runner.registerInfo("Removed existing dishwasher from space '#{space.name}'.")
    end
    objects_to_remove.uniq.each do |object|
      begin
        object.remove
      rescue
        # no op
      end
    end
  end
end

class EnergyGuideLabel
  def self.get_energy_guide_gas_cost(date)
    # Search for, e.g., "Representative Average Unit Costs of Energy for Five Residential Energy Sources (1996)"
    if date <= 1991
      # http://books.google.com/books?id=GsY5AAAAIAAJ&pg=PA184&lpg=PA184&dq=%22Representative+Average+Unit+Costs+of+Energy+for+Five+Residential+Energy+Sources%22+1991&source=bl&ots=QuQ83OQ1Wd&sig=jEsENidBQCtDnHkqpXGE3VYoLEg&hl=en&sa=X&ei=3QOjT-y4IJCo8QSsgIHVCg&ved=0CDAQ6AEwBA#v=onepage&q=%22Representative%20Average%20Unit%20Costs%20of%20Energy%20for%20Five%20Residential%20Energy%20Sources%22%201991&f=false
      return 60.54
    elsif date == 1992
      # http://books.google.com/books?id=esk5AAAAIAAJ&pg=PA193&lpg=PA193&dq=%22Representative+Average+Unit+Costs+of+Energy+for+Five+Residential+Energy+Sources%22+1992&source=bl&ots=tiUb_2hZ7O&sig=xG2k0WRDwVNauPhoXEQOAbCF80w&hl=en&sa=X&ei=owOjT7aOMoic9gTw6P3vCA&ved=0CDIQ6AEwAw#v=onepage&q=%22Representative%20Average%20Unit%20Costs%20of%20Energy%20for%20Five%20Residential%20Energy%20Sources%22%201992&f=false
      return 58.0
    elsif date == 1993
      # No data, use prev/next years
      return (58.0 + 60.40) / 2.0
    elsif date == 1994
      # http://govpulse.us/entries/1994/02/08/94-2823/rule-concerning-disclosures-of-energy-consumption-and-water-use-information-about-certain-home-appli
      return 60.40
    elsif date == 1995
      # http://www.ftc.gov/os/fedreg/1995/february/950217appliancelabelingrule.pdf
      return 63.0
    elsif date == 1996
      # http://www.gpo.gov/fdsys/pkg/FR-1996-01-19/pdf/96-574.pdf
      return 62.6
    elsif date == 1997
      # http://www.ftc.gov/os/fedreg/1997/february/970205ruleconcerningdisclosures.pdf
      return 61.2
    elsif date == 1998
      # http://www.gpo.gov/fdsys/pkg/FR-1997-12-08/html/97-32046.htm
      return 61.9
    elsif date == 1999
      # http://www.gpo.gov/fdsys/pkg/FR-1999-01-05/html/99-89.htm
      return 68.8
    elsif date == 2000
      # http://www.gpo.gov/fdsys/pkg/FR-2000-02-07/html/00-2707.htm
      return 68.8
    elsif date == 2001
      # http://www.gpo.gov/fdsys/pkg/FR-2001-03-08/html/01-5668.htm
      return 83.7
    elsif date == 2002
      # http://govpulse.us/entries/2002/06/07/02-14333/rule-concerning-disclosures-regarding-energy-consumption-and-water-use-of-certain-home-appliances-an#id963086
      return 65.6
    elsif date == 2003
      # http://www.gpo.gov/fdsys/pkg/FR-2003-04-09/html/03-8634.htm
      return 81.6
    elsif date == 2004
      # http://www.ftc.gov/os/fedreg/2004/april/040430ruleconcerningdisclosures.pdf
      return 91.0
    elsif date == 2005
      # http://www1.eere.energy.gov/buildings/appliance_standards/pdfs/2005_costs.pdf
      return 109.2
    elsif date == 2006
      # http://www1.eere.energy.gov/buildings/appliance_standards/pdfs/2006_energy_costs.pdf
      return 141.5
    elsif date == 2007
      # http://www1.eere.energy.gov/buildings/appliance_standards/pdfs/price_notice_032707.pdf
      return 121.8
    elsif date == 2008
      # http://www1.eere.energy.gov/buildings/appliance_standards/pdfs/2008_forecast.pdf
      return 132.8
    elsif date == 2009
      # http://www1.eere.energy.gov/buildings/appliance_standards/commercial/pdfs/ee_rep_avg_unit_costs.pdf
      return 111.2
    elsif date == 2010
      # http://www.gpo.gov/fdsys/pkg/FR-2010-03-18/html/2010-5936.htm
      return 119.4
    elsif date == 2011
      # http://www1.eere.energy.gov/buildings/appliance_standards/pdfs/2011_average_representative_unit_costs_of_energy.pdf
      return 110.1
    elsif date == 2012
      # http://www.gpo.gov/fdsys/pkg/FR-2012-04-26/pdf/2012-10058.pdf
      return 105.9
    elsif date == 2013
      # http://www.gpo.gov/fdsys/pkg/FR-2013-03-22/pdf/2013-06618.pdf
      return 108.7
    elsif date == 2014
      # http://www.gpo.gov/fdsys/pkg/FR-2014-03-18/pdf/2014-05949.pdf
      return 112.8
    elsif date >= 2015
      # http://www.gpo.gov/fdsys/pkg/FR-2015-08-27/pdf/2015-21243.pdf
      return 100.3
    elsif date >= 2016
      # https://www.gpo.gov/fdsys/pkg/FR-2016-03-23/pdf/2016-06505.pdf
      return 93.2
    elsif date >= 2017
      # https://www.govinfo.gov/content/pkg/FR-2017-05-05/pdf/2017-09128.pdf
      return 105.2
    elsif date >= 2018
      # https://www.govinfo.gov/content/pkg/FR-2018-04-24/pdf/2018-08519.pdf
      return 102.2
    elsif date >= 2019
      # https://www.govinfo.gov/content/pkg/FR-2019-03-08/pdf/2019-04245.pdf
      return 103.8
    end
  end

  def self.get_energy_guide_elec_cost(date)
    # Search for, e.g., "Representative Average Unit Costs of Energy for Five Residential Energy Sources (1996)"
    if date <= 1991
      # http://books.google.com/books?id=GsY5AAAAIAAJ&pg=PA184&lpg=PA184&dq=%22Representative+Average+Unit+Costs+of+Energy+for+Five+Residential+Energy+Sources%22+1991&source=bl&ots=QuQ83OQ1Wd&sig=jEsENidBQCtDnHkqpXGE3VYoLEg&hl=en&sa=X&ei=3QOjT-y4IJCo8QSsgIHVCg&ved=0CDAQ6AEwBA#v=onepage&q=%22Representative%20Average%20Unit%20Costs%20of%20Energy%20for%20Five%20Residential%20Energy%20Sources%22%201991&f=false
      return 8.24
    elsif date == 1992
      # http://books.google.com/books?id=esk5AAAAIAAJ&pg=PA193&lpg=PA193&dq=%22Representative+Average+Unit+Costs+of+Energy+for+Five+Residential+Energy+Sources%22+1992&source=bl&ots=tiUb_2hZ7O&sig=xG2k0WRDwVNauPhoXEQOAbCF80w&hl=en&sa=X&ei=owOjT7aOMoic9gTw6P3vCA&ved=0CDIQ6AEwAw#v=onepage&q=%22Representative%20Average%20Unit%20Costs%20of%20Energy%20for%20Five%20Residential%20Energy%20Sources%22%201992&f=false
      return 8.25
    elsif date == 1993
      # No data, use prev/next years
      return (8.25 + 8.41) / 2.0
    elsif date == 1994
      # http://govpulse.us/entries/1994/02/08/94-2823/rule-concerning-disclosures-of-energy-consumption-and-water-use-information-about-certain-home-appli
      return 8.41
    elsif date == 1995
      # http://www.ftc.gov/os/fedreg/1995/february/950217appliancelabelingrule.pdf
      return 8.67
    elsif date == 1996
      # http://www.gpo.gov/fdsys/pkg/FR-1996-01-19/pdf/96-574.pdf
      return 8.60
    elsif date == 1997
      # http://www.ftc.gov/os/fedreg/1997/february/970205ruleconcerningdisclosures.pdf
      return 8.31
    elsif date == 1998
      # http://www.gpo.gov/fdsys/pkg/FR-1997-12-08/html/97-32046.htm
      return 8.42
    elsif date == 1999
      # http://www.gpo.gov/fdsys/pkg/FR-1999-01-05/html/99-89.htm
      return 8.22
    elsif date == 2000
      # http://www.gpo.gov/fdsys/pkg/FR-2000-02-07/html/00-2707.htm
      return 8.03
    elsif date == 2001
      # http://www.gpo.gov/fdsys/pkg/FR-2001-03-08/html/01-5668.htm
      return 8.29
    elsif date == 2002
      # http://govpulse.us/entries/2002/06/07/02-14333/rule-concerning-disclosures-regarding-energy-consumption-and-water-use-of-certain-home-appliances-an#id963086
      return 8.28
    elsif date == 2003
      # http://www.gpo.gov/fdsys/pkg/FR-2003-04-09/html/03-8634.htm
      return 8.41
    elsif date == 2004
      # http://www.ftc.gov/os/fedreg/2004/april/040430ruleconcerningdisclosures.pdf
      return 8.60
    elsif date == 2005
      # http://www1.eere.energy.gov/buildings/appliance_standards/pdfs/2005_costs.pdf
      return 9.06
    elsif date == 2006
      # http://www1.eere.energy.gov/buildings/appliance_standards/pdfs/2006_energy_costs.pdf
      return 9.91
    elsif date == 2007
      # http://www1.eere.energy.gov/buildings/appliance_standards/pdfs/price_notice_032707.pdf
      return 10.65
    elsif date == 2008
      # http://www1.eere.energy.gov/buildings/appliance_standards/pdfs/2008_forecast.pdf
      return 10.80
    elsif date == 2009
      # http://www1.eere.energy.gov/buildings/appliance_standards/commercial/pdfs/ee_rep_avg_unit_costs.pdf
      return 11.40
    elsif date == 2010
      # http://www.gpo.gov/fdsys/pkg/FR-2010-03-18/html/2010-5936.htm
      return 11.50
    elsif date == 2011
      # http://www1.eere.energy.gov/buildings/appliance_standards/pdfs/2011_average_representative_unit_costs_of_energy.pdf
      return 11.65
    elsif date == 2012
      # http://www.gpo.gov/fdsys/pkg/FR-2012-04-26/pdf/2012-10058.pdf
      return 11.84
    elsif date == 2013
      # http://www.gpo.gov/fdsys/pkg/FR-2013-03-22/pdf/2013-06618.pdf
      return 12.10
    elsif date == 2014
      # http://www.gpo.gov/fdsys/pkg/FR-2014-03-18/pdf/2014-05949.pdf
      return 12.40
    elsif date >= 2015
      # http://www.gpo.gov/fdsys/pkg/FR-2015-08-27/pdf/2015-21243.pdf
      return 12.70
    elsif date >= 2016
      # https://www.gpo.gov/fdsys/pkg/FR-2016-03-23/pdf/2016-06505.pdf
      return 12.60
    elsif date >= 2017
      # https://www.govinfo.gov/content/pkg/FR-2017-05-05/pdf/2017-09128.pdf
      return 12.90
    elsif date >= 2018
      # https://www.govinfo.gov/content/pkg/FR-2018-04-24/pdf/2018-08519.pdf
      return 13.2
    elsif date >= 2019
      # https://www.govinfo.gov/content/pkg/FR-2019-03-08/pdf/2019-04245.pdf
      return 13.2
    end
  end
end
