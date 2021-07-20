# frozen_string_literal: true

require_relative 'constants'
require_relative 'geometry'
require_relative 'util'
require_relative 'unit_conversions'
require_relative 'psychrometrics'
require_relative 'schedules'

class HVAC
  def self.apply_central_ac_1speed(model, unit, runner, seer, eers, shrs,
                                   fan_power_rated, fan_power_installed,
                                   crankcase_capacity, crankcase_temp,
                                   eer_capacity_derates, capacity, dse,
                                   frac_cool_load_served)

    return true if frac_cool_load_served <= 0

    num_speeds = 1

    # Performance curves
    # NOTE: These coefficients are in IP UNITS
    curves_in_ip = true
    cOOL_CAP_FT_SPEC = [[3.670270705, -0.098652414, 0.000955906, 0.006552414, -0.0000156, -0.000131877]]
    cOOL_EIR_FT_SPEC = [[-3.302695861, 0.137871531, -0.001056996, -0.012573945, 0.000214638, -0.000145054]]
    cOOL_CAP_FFLOW_SPEC = [[0.718605468, 0.410099989, -0.128705457]]
    cOOL_EIR_FFLOW_SPEC = [[1.32299905, -0.477711207, 0.154712157]]

    capacity_ratios = [1.0]
    fan_speed_ratios = [1.0]

    # Cooling Coil
    rated_airflow_rate = 386.1 # cfm
    cfms_ton_rated = calc_cfms_ton_rated(rated_airflow_rate, fan_speed_ratios, capacity_ratios)
    cooling_eirs = calc_cooling_eirs(num_speeds, eers, fan_power_rated)
    shrs_rated_gross = calc_shrs_rated_gross(num_speeds, shrs, fan_power_rated, cfms_ton_rated)
    cOOL_CLOSS_FPLR_SPEC = [calc_plr_coefficients_cooling(num_speeds, seer)]

    obj_name = Constants.ObjectNameCentralAirConditioner(unit.name.to_s)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      # _processCurvesDXCooling

      clg_coil_stage_data = calc_coil_stage_data_cooling(model, capacity, (0...num_speeds).to_a, cooling_eirs, shrs_rated_gross, cOOL_CAP_FT_SPEC, cOOL_EIR_FT_SPEC, cOOL_CLOSS_FPLR_SPEC, cOOL_CAP_FFLOW_SPEC, cOOL_EIR_FFLOW_SPEC, curves_in_ip, dse)

      # _processSystemCoolingCoil

      clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule, clg_coil_stage_data[0].totalCoolingCapacityFunctionofTemperatureCurve, clg_coil_stage_data[0].totalCoolingCapacityFunctionofFlowFractionCurve, clg_coil_stage_data[0].energyInputRatioFunctionofTemperatureCurve, clg_coil_stage_data[0].energyInputRatioFunctionofFlowFractionCurve, clg_coil_stage_data[0].partLoadFractionCorrelationCurve)
      clg_coil_stage_data[0].remove
      clg_coil.setName(obj_name + ' cooling coil')
      if capacity != Constants.SizingAuto
        clg_coil.setRatedTotalCoolingCapacity(UnitConversions.convert(capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
      end
      clg_coil.setRatedSensibleHeatRatio(shrs_rated_gross[0])
      clg_coil.setRatedCOP(OpenStudio::OptionalDouble.new(dse / cooling_eirs[0]))
      clg_coil.setRatedEvaporatorFanPowerPerVolumeFlowRate(OpenStudio::OptionalDouble.new(fan_power_rated / UnitConversions.convert(1.0, 'cfm', 'm^3/s')))

      clg_coil.setNominalTimeForCondensateRemovalToBegin(OpenStudio::OptionalDouble.new(1000.0))
      clg_coil.setRatioOfInitialMoistureEvaporationRateAndSteadyStateLatentCapacity(OpenStudio::OptionalDouble.new(1.5))
      clg_coil.setMaximumCyclingRate(OpenStudio::OptionalDouble.new(3.0))
      clg_coil.setLatentCapacityTimeConstant(OpenStudio::OptionalDouble.new(45.0))

      clg_coil.setCondenserType('AirCooled')
      clg_coil.setCrankcaseHeaterCapacity(OpenStudio::OptionalDouble.new(UnitConversions.convert(crankcase_capacity, 'kW', 'W')))
      clg_coil.setMaximumOutdoorDryBulbTemperatureForCrankcaseHeaterOperation(OpenStudio::OptionalDouble.new(UnitConversions.convert(crankcase_temp, 'F', 'C')))

      # _processSystemFan

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + ' clg supply fan')
      fan.setEndUseSubcategory(obj_name + ' clg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power_installed / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      # _processSystemAir

      air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      air_loop_unitary.setName(obj_name + ' unitary system')
      air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      air_loop_unitary.setCoolingCoil(clg_coil)
      air_loop_unitary.setSupplyAirFlowRateDuringHeatingOperation(0.0)
      air_loop_unitary.setSupplyFan(fan)
      air_loop_unitary.setFanPlacement('BlowThrough')
      air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(120.0, 'F', 'C'))
      air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' asys')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{fan.name}' to '#{air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{clg_coil.name}' to '#{air_loop_unitary.name}' of '#{air_loop.name}'")

      air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      # _processSystemDemandSideAir
      # Demand Side

      # Supply Air
      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end # slave_zone

      # Store info for HVAC Sizing measure
      air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityDerateFactorEER, eer_capacity_derates.join(','))
      air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACRatedCFMperTonCooling, cfms_ton_rated.join(','))
      air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracCoolLoadServed, frac_cool_load_served)
    end # control_zone

    return true
  end

  def self.apply_central_ac_2speed(model, unit, runner, seer, eers, shrs,
                                   capacity_ratios, fan_speed_ratios,
                                   fan_power_rated, fan_power_installed,
                                   crankcase_capacity, crankcase_temp,
                                   eer_capacity_derates, capacity, dse,
                                   frac_cool_load_served)

    return true if frac_cool_load_served <= 0

    num_speeds = 2

    # Performance curves
    # NOTE: These coefficients are in IP UNITS
    curves_in_ip = true
    cOOL_CAP_FT_SPEC = [[3.940185508, -0.104723455, 0.001019298, 0.006471171, -0.00000953, -0.000161658],
                        [3.109456535, -0.085520461, 0.000863238, 0.00863049, -0.0000210, -0.000140186]]
    cOOL_EIR_FT_SPEC = [[-3.877526888, 0.164566276, -0.001272755, -0.019956043, 0.000256512, -0.000133539],
                        [-1.990708931, 0.093969249, -0.00073335, -0.009062553, 0.000165099, -0.0000997]]
    cOOL_CAP_FFLOW_SPEC = [[0.65673024, 0.516470835, -0.172887149],
                           [0.690334551, 0.464383753, -0.154507638]]
    cOOL_EIR_FFLOW_SPEC = [[1.562945114, -0.791859997, 0.230030877],
                           [1.31565404, -0.482467162, 0.166239001]]

    # Cooling Coil
    rated_airflow_rate = 355.2 # cfm
    cfms_ton_rated = calc_cfms_ton_rated(rated_airflow_rate, fan_speed_ratios, capacity_ratios)
    cooling_eirs = calc_cooling_eirs(num_speeds, eers, fan_power_rated)
    shrs_rated_gross = calc_shrs_rated_gross(num_speeds, shrs, fan_power_rated, cfms_ton_rated)
    cOOL_CLOSS_FPLR_SPEC = [calc_plr_coefficients_cooling(num_speeds, seer)] * num_speeds

    obj_name = Constants.ObjectNameCentralAirConditioner(unit.name.to_s)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      # _processCurvesDXCooling

      clg_coil_stage_data = calc_coil_stage_data_cooling(model, capacity, (0...num_speeds).to_a, cooling_eirs, shrs_rated_gross, cOOL_CAP_FT_SPEC, cOOL_EIR_FT_SPEC, cOOL_CLOSS_FPLR_SPEC, cOOL_CAP_FFLOW_SPEC, cOOL_EIR_FFLOW_SPEC, curves_in_ip, dse)

      # _processSystemCoolingCoil

      clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
      clg_coil.setName(obj_name + ' cooling coil')
      clg_coil.setCondenserType('AirCooled')
      clg_coil.setApplyPartLoadFractiontoSpeedsGreaterthan1(false)
      clg_coil.setApplyLatentDegradationtoSpeedsGreaterthan1(false)
      clg_coil.setCrankcaseHeaterCapacity(UnitConversions.convert(crankcase_capacity, 'kW', 'W'))
      clg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(UnitConversions.convert(crankcase_temp, 'F', 'C'))
      clg_coil.setFuelType('Electricity')

      clg_coil_stage_data.each do |stage|
        clg_coil.addStage(stage)
      end

      # _processSystemFan

      fan_power_curve = create_curve_exponent(model, [0, 1, 3], obj_name + ' fan power curve', -100, 100)
      fan_eff_curve = create_curve_cubic(model, [0, 1, 0, 0], obj_name + ' fan eff curve', 0, 1, 0.01, 1)

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule, fan_power_curve, fan_eff_curve)
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + ' clg supply fan')
      fan.setEndUseSubcategory(obj_name + ' clg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power_installed / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      # _processSystemAir

      air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      air_loop_unitary.setName(obj_name + ' unitary system')
      air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      air_loop_unitary.setCoolingCoil(clg_coil)
      air_loop_unitary.setSupplyAirFlowRateDuringHeatingOperation(0.0)
      air_loop_unitary.setSupplyFan(fan)
      air_loop_unitary.setFanPlacement('BlowThrough')
      air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(120.0, 'F', 'C'))
      air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)

      perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
      air_loop_unitary.setDesignSpecificationMultispeedObject(perf)
      perf.setSingleModeOperation(false)
      for speed in 1..num_speeds
        f = OpenStudio::Model::SupplyAirflowRatioField.fromCoolingRatio(fan_speed_ratios[speed - 1])
        perf.addSupplyAirflowRatioField(f)
      end

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' asys')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{fan.name}' to #{air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{clg_coil.name}' to '#{air_loop_unitary.name}' of '#{air_loop.name}'")

      air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      # _processSystemDemandSideAir
      # Demand Side

      # Supply Air
      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end # slave_zone

      # Store info for HVAC Sizing measure
      air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityRatioCooling, capacity_ratios.join(','))
      air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityDerateFactorEER, eer_capacity_derates.join(','))
      air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACRatedCFMperTonCooling, cfms_ton_rated.join(','))
      air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracCoolLoadServed, frac_cool_load_served)
    end # control_zone

    return true
  end

  def self.apply_central_ac_4speed(model, unit, runner, seer, eers, shrs,
                                   capacity_ratios, fan_speed_ratios,
                                   fan_power_rated, fan_power_installed,
                                   crankcase_capacity, crankcase_temp,
                                   eer_capacity_derates, capacity, dse,
                                   frac_cool_load_served)

    return true if frac_cool_load_served <= 0

    num_speeds = 4

    # Performance curves
    # NOTE: These coefficients are in IP UNITS
    curves_in_ip = true
    cOOL_CAP_FT_SPEC = [[3.845135427537, -0.095933272242, 0.000924533273, 0.008939030321, -0.000021025870, -0.000191684744],
                        [1.902445285801, -0.042809294549, 0.000555959865, 0.009928999493, -0.000013373437, -0.000211453245],
                        [-3.176259152730, 0.107498394091, -0.000574951600, 0.005484032413, -0.000011584801, -0.000135528854],
                        [1.216308942608, -0.021962441981, 0.000410292252, 0.007362335339, -0.000000025748, -0.000202117724]]
    cOOL_EIR_FT_SPEC = [[-1.400822352, 0.075567798, -0.000589362, -0.024655521, 0.00032690848, -0.00010222178],
                        [3.278112067, -0.07106453, 0.000468081, -0.014070845, 0.00022267912, -0.00004950051],
                        [1.183747649, -0.041423179, 0.000390378, 0.021207528, 0.00011181091, -0.00034107189],
                        [-3.97662986, 0.115338094, -0.000841943, 0.015962287, 0.00007757092, -0.00018579409]]
    cOOL_CAP_FFLOW_SPEC = [[1, 0, 0]] * num_speeds
    cOOL_EIR_FFLOW_SPEC = [[1, 0, 0]] * num_speeds

    # Cooling Coil
    rated_airflow_rate = 315.8 # cfm
    cfms_ton_rated = calc_cfms_ton_rated(rated_airflow_rate, fan_speed_ratios, capacity_ratios)
    cooling_eirs = calc_cooling_eirs(num_speeds, eers, fan_power_rated)
    shrs_rated_gross = calc_shrs_rated_gross(num_speeds, shrs, fan_power_rated, cfms_ton_rated)
    cOOL_CLOSS_FPLR_SPEC = [calc_plr_coefficients_cooling(num_speeds, seer)] * num_speeds

    obj_name = Constants.ObjectNameCentralAirConditioner(unit.name.to_s)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      # _processCurvesDXCooling

      clg_coil_stage_data = calc_coil_stage_data_cooling(model, capacity, (0...num_speeds).to_a, cooling_eirs, shrs_rated_gross, cOOL_CAP_FT_SPEC, cOOL_EIR_FT_SPEC, cOOL_CLOSS_FPLR_SPEC, cOOL_CAP_FFLOW_SPEC, cOOL_EIR_FFLOW_SPEC, curves_in_ip, dse)

      # _processSystemCoolingCoil

      clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
      clg_coil.setName(obj_name + ' cooling coil')
      clg_coil.setCondenserType('AirCooled')
      clg_coil.setApplyPartLoadFractiontoSpeedsGreaterthan1(false)
      clg_coil.setApplyLatentDegradationtoSpeedsGreaterthan1(false)
      clg_coil.setCrankcaseHeaterCapacity(UnitConversions.convert(crankcase_capacity, 'kW', 'W'))
      clg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(UnitConversions.convert(crankcase_temp, 'F', 'C'))
      clg_coil.setFuelType('Electricity')

      clg_coil_stage_data.each do |stage|
        clg_coil.addStage(stage)
      end

      # _processSystemFan

      fan_power_curve = create_curve_exponent(model, [0, 1, 3], obj_name + ' fan power curve', -100, 100)
      fan_eff_curve = create_curve_cubic(model, [0, 1, 0, 0], obj_name + ' fan eff curve', 0, 1, 0.01, 1)

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule, fan_power_curve, fan_eff_curve)
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + ' clg supply fan')
      fan.setEndUseSubcategory(obj_name + ' clg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power_installed / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      # _processSystemAir

      air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      air_loop_unitary.setName(obj_name + ' unitary system')
      air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      air_loop_unitary.setCoolingCoil(clg_coil)
      air_loop_unitary.setSupplyAirFlowRateDuringHeatingOperation(0.0)
      air_loop_unitary.setSupplyFan(fan)
      air_loop_unitary.setFanPlacement('BlowThrough')
      air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(120.0, 'F', 'C'))
      air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)

      perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
      air_loop_unitary.setDesignSpecificationMultispeedObject(perf)
      perf.setSingleModeOperation(false)
      for speed in 1..num_speeds
        f = OpenStudio::Model::SupplyAirflowRatioField.fromCoolingRatio(fan_speed_ratios[speed - 1])
        perf.addSupplyAirflowRatioField(f)
      end

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' asys')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{fan.name}' to #{air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{clg_coil.name}' to #{air_loop_unitary.name}' of '#{air_loop.name}'")

      air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      # _processSystemDemandSideAir
      # Demand Side

      # Supply Air
      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end # slave_zone

      # Store info for HVAC Sizing measure
      air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityRatioCooling, capacity_ratios.join(','))
      air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityDerateFactorEER, eer_capacity_derates.join(','))
      air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACRatedCFMperTonCooling, cfms_ton_rated.join(','))
      air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracCoolLoadServed, frac_cool_load_served)
    end # control_zone

    return true
  end

  def self.apply_central_ashp_1speed(model, unit, runner, seer, hspf, eers, cops, shrs,
                                     fan_power_rated, fan_power_installed, min_temp,
                                     crankcase_capacity, crankcase_temp,
                                     eer_capacity_derates, cop_capacity_derates,
                                     heat_pump_capacity, supplemental_efficiency,
                                     supplemental_capacity, dse,
                                     frac_heat_load_served, frac_cool_load_served)

    if heat_pump_capacity == Constants.SizingAutoMaxLoad
      runner.registerWarning("Using #{Constants.SizingAutoMaxLoad} is not recommended for single-speed heat pumps. When sized larger than the cooling load, this can lead to humidity concerns due to reduced dehumidification performance by the heat pump.")
    end

    num_speeds = 1

    # Performance curves
    # NOTE: These coefficients are in IP UNITS
    curves_in_ip = true
    cOOL_CAP_FT_SPEC = [[3.68637657, -0.098352478, 0.000956357, 0.005838141, -0.0000127, -0.000131702]]
    cOOL_EIR_FT_SPEC = [[-3.437356399, 0.136656369, -0.001049231, -0.0079378, 0.000185435, -0.0001441]]
    cOOL_CAP_FFLOW_SPEC = [[0.718664047, 0.41797409, -0.136638137]]
    cOOL_EIR_FFLOW_SPEC = [[1.143487507, -0.13943972, -0.004047787]]
    hEAT_CAP_FT_SPEC = [[0.566333415, -0.000744164, -0.0000103, 0.009414634, 0.0000506, -0.00000675]]
    hEAT_EIR_FT_SPEC = [[0.718398423, 0.003498178, 0.000142202, -0.005724331, 0.00014085, -0.000215321]]
    hEAT_CAP_FFLOW_SPEC = [[0.694045465, 0.474207981, -0.168253446]]
    hEAT_EIR_FFLOW_SPEC = [[2.185418751, -1.942827919, 0.757409168]]

    capacity_ratios = [1.0]
    fan_speed_ratios_cooling = [1.0]
    fan_speed_ratios_heating = [1.0]

    # Cooling Coil
    rated_airflow_rate_cooling = 394.2 # cfm
    cfms_ton_rated_cooling = calc_cfms_ton_rated(rated_airflow_rate_cooling, fan_speed_ratios_cooling, capacity_ratios)
    cooling_eirs = calc_cooling_eirs(num_speeds, eers, fan_power_rated)
    shrs_rated_gross = calc_shrs_rated_gross(num_speeds, shrs, fan_power_rated, cfms_ton_rated_cooling)
    cOOL_CLOSS_FPLR_SPEC = [calc_plr_coefficients_cooling(num_speeds, seer)]

    # Heating Coil
    rated_airflow_rate_heating = 384.1 # cfm
    cfms_ton_rated_heating = calc_cfms_ton_rated(rated_airflow_rate_heating, fan_speed_ratios_heating, capacity_ratios)
    heating_eirs = calc_heating_eirs(num_speeds, cops, fan_power_rated)
    hEAT_CLOSS_FPLR_SPEC = [calc_plr_coefficients_heating(num_speeds, hspf)]

    # Heating defrost curve for reverse cycle
    defrost_eir_curve = create_curve_biquadratic(model, [0.1528, 0, 0, 0, 0, 0], 'DefrostEIR', -100, 100, -100, 100)

    obj_name = Constants.ObjectNameAirSourceHeatPump(unit.name.to_s)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      # _processCurvesDXHeating

      htg_coil_stage_data = calc_coil_stage_data_heating(model, heat_pump_capacity, (0...num_speeds).to_a, heating_eirs, hEAT_CAP_FT_SPEC, hEAT_EIR_FT_SPEC, hEAT_CLOSS_FPLR_SPEC, hEAT_CAP_FFLOW_SPEC, hEAT_EIR_FFLOW_SPEC, curves_in_ip, dse)

      # _processSystemHeatingCoil

      htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule, htg_coil_stage_data[0].heatingCapacityFunctionofTemperatureCurve, htg_coil_stage_data[0].heatingCapacityFunctionofFlowFractionCurve, htg_coil_stage_data[0].energyInputRatioFunctionofTemperatureCurve, htg_coil_stage_data[0].energyInputRatioFunctionofFlowFractionCurve, htg_coil_stage_data[0].partLoadFractionCorrelationCurve)
      htg_coil_stage_data[0].remove
      htg_coil.setName(obj_name + ' htg coil')
      if (heat_pump_capacity != Constants.SizingAuto) && (heat_pump_capacity != Constants.SizingAutoMaxLoad)
        htg_coil.setRatedTotalHeatingCapacity(UnitConversions.convert(heat_pump_capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
      end
      htg_coil.setRatedCOP(dse / heating_eirs[0])
      htg_coil.setRatedSupplyFanPowerPerVolumeFlowRate(fan_power_rated / UnitConversions.convert(1.0, 'cfm', 'm^3/s'))
      htg_coil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(defrost_eir_curve)
      htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(UnitConversions.convert(min_temp, 'F', 'C'))
      htg_coil.setMaximumOutdoorDryBulbTemperatureforDefrostOperation(UnitConversions.convert(40.0, 'F', 'C'))
      if frac_heat_load_served <= 0
        htg_coil.setCrankcaseHeaterCapacity(0.0)
      else
        htg_coil.setCrankcaseHeaterCapacity(UnitConversions.convert(crankcase_capacity, 'kW', 'W'))
      end
      htg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(UnitConversions.convert(crankcase_temp, 'F', 'C'))
      htg_coil.setDefrostStrategy('ReverseCycle')
      htg_coil.setDefrostControl('Timed')

      supp_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
      supp_htg_coil.setName(obj_name + ' supp heater')
      supp_htg_coil.setEfficiency(dse * supplemental_efficiency)
      if supplemental_capacity != Constants.SizingAuto
        supp_htg_coil.setNominalCapacity(UnitConversions.convert(supplemental_capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
      end

      # _processSystemFan

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + ' htg supply fan')
      fan.setEndUseSubcategory(obj_name + ' htg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power_installed / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      # _processSystemAir

      htg_air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      htg_air_loop_unitary.setName(obj_name + ' htg unitary system')
      if frac_heat_load_served <= 0
        htg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
      else
        htg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      end
      htg_air_loop_unitary.setSupplyFan(fan)
      htg_air_loop_unitary.setHeatingCoil(htg_coil)
      htg_air_loop_unitary.setSupplementalHeatingCoil(supp_htg_coil)
      htg_air_loop_unitary.setFanPlacement('BlowThrough')
      htg_air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      htg_air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(170.0, 'F', 'C')) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      htg_air_loop_unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(UnitConversions.convert(40.0, 'F', 'C'))
      htg_air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' htg asys')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      htg_air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{fan.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{htg_coil.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{supp_htg_coil.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")

      htg_air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      # _processSystemDemandSideAir
      # Demand Side

      # Supply Air
      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' htg zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' htg zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} htg direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} htg direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end # slave_zone

      # _processCurvesDXCooling

      clg_coil_stage_data = calc_coil_stage_data_cooling(model, heat_pump_capacity, (0...num_speeds).to_a, cooling_eirs, shrs_rated_gross, cOOL_CAP_FT_SPEC, cOOL_EIR_FT_SPEC, cOOL_CLOSS_FPLR_SPEC, cOOL_CAP_FFLOW_SPEC, cOOL_EIR_FFLOW_SPEC, curves_in_ip, dse)

      # _processSystemCoolingCoil

      clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule, clg_coil_stage_data[0].totalCoolingCapacityFunctionofTemperatureCurve, clg_coil_stage_data[0].totalCoolingCapacityFunctionofFlowFractionCurve, clg_coil_stage_data[0].energyInputRatioFunctionofTemperatureCurve, clg_coil_stage_data[0].energyInputRatioFunctionofFlowFractionCurve, clg_coil_stage_data[0].partLoadFractionCorrelationCurve)
      clg_coil_stage_data[0].remove
      clg_coil.setName(obj_name + ' clg coil')
      if (heat_pump_capacity != Constants.SizingAuto) && (heat_pump_capacity != Constants.SizingAutoMaxLoad)
        clg_coil.setRatedTotalCoolingCapacity(UnitConversions.convert(heat_pump_capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
      end
      clg_coil.setRatedSensibleHeatRatio(shrs_rated_gross[0])
      clg_coil.setRatedCOP(OpenStudio::OptionalDouble.new(dse / cooling_eirs[0]))
      clg_coil.setRatedEvaporatorFanPowerPerVolumeFlowRate(OpenStudio::OptionalDouble.new(fan_power_rated / UnitConversions.convert(1.0, 'cfm', 'm^3/s')))
      clg_coil.setNominalTimeForCondensateRemovalToBegin(OpenStudio::OptionalDouble.new(1000.0))
      clg_coil.setRatioOfInitialMoistureEvaporationRateAndSteadyStateLatentCapacity(OpenStudio::OptionalDouble.new(1.5))
      clg_coil.setMaximumCyclingRate(OpenStudio::OptionalDouble.new(3.0))
      clg_coil.setLatentCapacityTimeConstant(OpenStudio::OptionalDouble.new(45.0))
      clg_coil.setCondenserType('AirCooled')

      # _processSystemFan

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + ' clg supply fan')
      fan.setEndUseSubcategory(obj_name + ' clg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power_installed / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      # _processSystemAir

      clg_air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      clg_air_loop_unitary.setName(obj_name + ' clg unitary system')
      if frac_cool_load_served <= 0
        clg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
      else
        clg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      end
      clg_air_loop_unitary.setSupplyFan(fan)
      clg_air_loop_unitary.setCoolingCoil(clg_coil)
      clg_air_loop_unitary.setFanPlacement('BlowThrough')
      clg_air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      clg_air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(170.0, 'F', 'C')) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      clg_air_loop_unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(UnitConversions.convert(40.0, 'F', 'C'))
      clg_air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' clg asys')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      clg_air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{fan.name}' to '#{clg_air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{clg_coil.name}' to '#{clg_air_loop_unitary.name}' of '#{air_loop.name}'")

      clg_air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      # _processSystemDemandSideAir
      # Demand Side

      # Supply Air
      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' clg zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' clg zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} clg direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} clg direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end # slave_zone

      # Store info for HVAC Sizing measure
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityDerateFactorEER, eer_capacity_derates.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityDerateFactorCOP, cop_capacity_derates.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHPSizedForMaxLoad, (heat_pump_capacity == Constants.SizingAutoMaxLoad))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACRatedCFMperTonHeating, cfms_ton_rated_heating.join(','))
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACRatedCFMperTonCooling, cfms_ton_rated_cooling.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracHeatLoadServed, frac_heat_load_served)
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracCoolLoadServed, frac_cool_load_served)
    end # control_zone

    return true
  end

  def self.apply_central_ashp_2speed(model, unit, runner, seer, hspf, eers, cops, shrs,
                                     capacity_ratios, fan_speed_ratios_cooling,
                                     fan_speed_ratios_heating,
                                     fan_power_rated, fan_power_installed, min_temp,
                                     crankcase_capacity, crankcase_temp,
                                     eer_capacity_derates, cop_capacity_derates,
                                     heat_pump_capacity, supplemental_efficiency,
                                     supplemental_capacity, dse,
                                     frac_heat_load_served, frac_cool_load_served)

    num_speeds = 2

    # Performance curves
    # NOTE: These coefficients are in IP UNITS
    curves_in_ip = true
    cOOL_CAP_FT_SPEC = [[3.998418659, -0.108728222, 0.001056818, 0.007512314, -0.0000139, -0.000164716],
                        [3.466810106, -0.091476056, 0.000901205, 0.004163355, -0.00000919, -0.000110829]]
    cOOL_EIR_FT_SPEC = [[-4.282911381, 0.181023691, -0.001357391, -0.026310378, 0.000333282, -0.000197405],
                        [-3.557757517, 0.112737397, -0.000731381, 0.013184877, 0.000132645, -0.000338716]]
    cOOL_CAP_FFLOW_SPEC = [[0.655239515, 0.511655216, -0.166894731],
                           [0.618281092, 0.569060264, -0.187341356]]
    cOOL_EIR_FFLOW_SPEC = [[1.639108268, -0.998953996, 0.359845728],
                           [1.570774717, -0.914152018, 0.343377302]]
    hEAT_CAP_FT_SPEC = [[0.335690634, 0.002405123, -0.0000464, 0.013498735, 0.0000499, -0.00000725],
                        [0.306358843, 0.005376987, -0.0000579, 0.011645092, 0.0000591, -0.0000203]]
    hEAT_EIR_FT_SPEC = [[0.36338171, 0.013523725, 0.000258872, -0.009450269, 0.000439519, -0.000653723],
                        [0.981100941, -0.005158493, 0.000243416, -0.005274352, 0.000230742, -0.000336954]]
    hEAT_CAP_FFLOW_SPEC = [[0.741466907, 0.378645444, -0.119754733],
                           [0.76634609, 0.32840943, -0.094701495]]
    hEAT_EIR_FFLOW_SPEC = [[2.153618211, -1.737190609, 0.584269478],
                           [2.001041353, -1.58869128, 0.587593517]]

    # Cooling Coil
    rated_airflow_rate_cooling = 344.1 # cfm
    cfms_ton_rated_cooling = calc_cfms_ton_rated(rated_airflow_rate_cooling, fan_speed_ratios_cooling, capacity_ratios)
    cooling_eirs = calc_cooling_eirs(num_speeds, eers, fan_power_rated)
    shrs_rated_gross = calc_shrs_rated_gross(num_speeds, shrs, fan_power_rated, cfms_ton_rated_cooling)
    cOOL_CLOSS_FPLR_SPEC = [calc_plr_coefficients_cooling(num_speeds, seer)] * num_speeds

    # Heating Coil
    rated_airflow_rate_heating = 352.2 # cfm
    cfms_ton_rated_heating = calc_cfms_ton_rated(rated_airflow_rate_heating, fan_speed_ratios_heating, capacity_ratios)
    heating_eirs = calc_heating_eirs(num_speeds, cops, fan_power_rated)
    hEAT_CLOSS_FPLR_SPEC = [calc_plr_coefficients_heating(num_speeds, hspf)] * num_speeds

    # Heating defrost curve for reverse cycle
    defrost_eir_curve = create_curve_biquadratic(model, [0.1528, 0, 0, 0, 0, 0], 'DefrostEIR', -100, 100, -100, 100)

    obj_name = Constants.ObjectNameAirSourceHeatPump(unit.name.to_s)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      # _processCurvesDXHeating
      htg_coil_stage_data = calc_coil_stage_data_heating(model, heat_pump_capacity, (0...num_speeds).to_a, heating_eirs, hEAT_CAP_FT_SPEC, hEAT_EIR_FT_SPEC, hEAT_CLOSS_FPLR_SPEC, hEAT_CAP_FFLOW_SPEC, hEAT_EIR_FFLOW_SPEC, curves_in_ip, dse)

      # _processSystemHeatingCoil

      htg_coil = OpenStudio::Model::CoilHeatingDXMultiSpeed.new(model)
      htg_coil.setName(obj_name + ' htg coil')
      htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(UnitConversions.convert(min_temp, 'F', 'C'))
      if frac_heat_load_served <= 0
        htg_coil.setCrankcaseHeaterCapacity(0.0)
      else
        htg_coil.setCrankcaseHeaterCapacity(UnitConversions.convert(crankcase_capacity, 'kW', 'W'))
      end
      htg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(UnitConversions.convert(crankcase_temp, 'F', 'C'))
      htg_coil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(defrost_eir_curve)
      htg_coil.setMaximumOutdoorDryBulbTemperatureforDefrostOperation(UnitConversions.convert(40.0, 'F', 'C'))
      htg_coil.setDefrostStrategy('ReverseCycle')
      htg_coil.setDefrostControl('Timed')
      htg_coil.setApplyPartLoadFractiontoSpeedsGreaterthan1(false)
      htg_coil.setFuelType('Electricity')

      htg_coil_stage_data.each do |stage|
        htg_coil.addStage(stage)
      end

      supp_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
      supp_htg_coil.setName(obj_name + ' supp heater')
      supp_htg_coil.setEfficiency(dse * supplemental_efficiency)
      if supplemental_capacity != Constants.SizingAuto
        supp_htg_coil.setNominalCapacity(UnitConversions.convert(supplemental_capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
      end

      # _processSystemFan

      fan_power_curve = create_curve_exponent(model, [0, 1, 3], obj_name + ' fan power curve', -100, 100)
      fan_eff_curve = create_curve_cubic(model, [0, 1, 0, 0], obj_name + ' fan eff curve', 0, 1, 0.01, 1)

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule, fan_power_curve, fan_eff_curve)
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + ' htg supply fan')
      fan.setEndUseSubcategory(obj_name + ' htg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power_installed / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
      perf.setSingleModeOperation(false)
      for speed in 1..num_speeds
        f = OpenStudio::Model::SupplyAirflowRatioField.new(fan_speed_ratios_heating[speed - 1], Constants.small)
        perf.addSupplyAirflowRatioField(f)
      end

      # _processSystemAir

      htg_air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      htg_air_loop_unitary.setName(obj_name + ' htg unitary system')
      if frac_heat_load_served <= 0
        htg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
      else
        htg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      end
      htg_air_loop_unitary.setSupplyFan(fan)
      htg_air_loop_unitary.setHeatingCoil(htg_coil)
      htg_air_loop_unitary.setSupplementalHeatingCoil(supp_htg_coil)
      htg_air_loop_unitary.setFanPlacement('BlowThrough')
      htg_air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      htg_air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(170.0, 'F', 'C')) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      htg_air_loop_unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(UnitConversions.convert(40.0, 'F', 'C'))
      htg_air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)
      htg_air_loop_unitary.setDesignSpecificationMultispeedObject(perf)

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' htg asys')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      htg_air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{fan.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{htg_coil.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{supp_htg_coil.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")

      htg_air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      # _processSystemDemandSideAir
      # Demand Side

      # Supply Air
      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' htg zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' htg zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} htg direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} htg direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end # slave_zone

      # _processCurvesDXCooling

      clg_coil_stage_data = calc_coil_stage_data_cooling(model, heat_pump_capacity, (0...num_speeds).to_a, cooling_eirs, shrs_rated_gross, cOOL_CAP_FT_SPEC, cOOL_EIR_FT_SPEC, cOOL_CLOSS_FPLR_SPEC, cOOL_CAP_FFLOW_SPEC, cOOL_EIR_FFLOW_SPEC, curves_in_ip, dse)

      # _processSystemCoolingCoil

      clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
      clg_coil.setName(obj_name + ' clg coil')
      clg_coil.setCondenserType('AirCooled')
      clg_coil.setApplyPartLoadFractiontoSpeedsGreaterthan1(false)
      clg_coil.setApplyLatentDegradationtoSpeedsGreaterthan1(false)
      clg_coil.setFuelType('Electricity')

      clg_coil_stage_data.each do |stage|
        clg_coil.addStage(stage)
      end

      # _processSystemFan

      fan_power_curve = create_curve_exponent(model, [0, 1, 3], obj_name + ' fan power curve', -100, 100)
      fan_eff_curve = create_curve_cubic(model, [0, 1, 0, 0], obj_name + ' fan eff curve', 0, 1, 0.01, 1)

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule, fan_power_curve, fan_eff_curve)
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + ' clg supply fan')
      fan.setEndUseSubcategory(obj_name + ' clg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power_installed / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
      perf.setSingleModeOperation(false)
      for speed in 1..num_speeds
        f = OpenStudio::Model::SupplyAirflowRatioField.new(Constants.small, fan_speed_ratios_cooling[speed - 1])
        perf.addSupplyAirflowRatioField(f)
      end

      # _processSystemAir

      clg_air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      clg_air_loop_unitary.setName(obj_name + ' clg unitary system')
      if frac_cool_load_served <= 0
        clg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
      else
        clg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      end
      clg_air_loop_unitary.setSupplyFan(fan)
      clg_air_loop_unitary.setCoolingCoil(clg_coil)
      clg_air_loop_unitary.setFanPlacement('BlowThrough')
      clg_air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      clg_air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(170.0, 'F', 'C')) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      clg_air_loop_unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(UnitConversions.convert(40.0, 'F', 'C'))
      clg_air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)
      clg_air_loop_unitary.setDesignSpecificationMultispeedObject(perf)

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' clg asys')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      clg_air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{fan.name}' to '#{clg_air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{clg_coil.name}' to '#{clg_air_loop_unitary.name}' of '#{air_loop.name}'")

      clg_air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      # _processSystemDemandSideAir
      # Demand Side

      # Supply Air
      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' clg zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' clg zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} clg direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} clg direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end # slave_zone

      # Store info for HVAC Sizing measure
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityRatioCooling, capacity_ratios.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityRatioHeating, capacity_ratios.join(','))
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityDerateFactorEER, eer_capacity_derates.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityDerateFactorCOP, cop_capacity_derates.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHPSizedForMaxLoad, (heat_pump_capacity == Constants.SizingAutoMaxLoad))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACRatedCFMperTonHeating, cfms_ton_rated_heating.join(','))
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACRatedCFMperTonCooling, cfms_ton_rated_cooling.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracHeatLoadServed, frac_heat_load_served)
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracCoolLoadServed, frac_cool_load_served)
    end # control_zone

    return true
  end

  def self.apply_central_ashp_4speed(model, unit, runner, seer, hspf, eers, cops, shrs,
                                     capacity_ratios, fan_speed_ratios_cooling,
                                     fan_speed_ratios_heating,
                                     fan_power_rated, fan_power_installed, min_temp,
                                     crankcase_capacity, crankcase_temp,
                                     eer_capacity_derates, cop_capacity_derates,
                                     heat_pump_capacity, supplemental_efficiency,
                                     supplemental_capacity, dse,
                                     frac_heat_load_served, frac_cool_load_served)

    num_speeds = 4

    # Performance curves
    # NOTE: These coefficients are in IP UNITS
    curves_in_ip = true
    cOOL_CAP_FT_SPEC = [[3.63396857, -0.093606786, 0.000918114, 0.011852512, -0.0000318307, -0.000206446],
                        [1.808745668, -0.041963484, 0.000545263, 0.011346539, -0.000023838, -0.000205162],
                        [0.112814745, 0.005638646, 0.000203427, 0.011981545, -0.0000207957, -0.000212379],
                        [1.141506147, -0.023973142, 0.000420763, 0.01038334, -0.0000174633, -0.000197092]]
    cOOL_EIR_FT_SPEC = [[-1.380674217, 0.083176919, -0.000676029, -0.028120348, 0.000320593, -0.0000616147],
                        [4.817787321, -0.100122768, 0.000673499, -0.026889359, 0.00029445, -0.0000390331],
                        [-1.502227232, 0.05896401, -0.000439349, 0.002198465, 0.000148486, -0.000159553],
                        [-3.443078025, 0.115186164, -0.000852001, 0.004678056, 0.000134319, -0.000171976]]
    cOOL_CAP_FFLOW_SPEC = [[1, 0, 0]] * num_speeds
    cOOL_EIR_FFLOW_SPEC = [[1, 0, 0]] * num_speeds
    hEAT_CAP_FT_SPEC = [[0.304192655, -0.003972566, 0.0000196432, 0.024471251, -0.000000774126, -0.0000841323],
                        [0.496381324, -0.00144792, 0.0, 0.016020855, 0.0000203447, -0.0000584118],
                        [0.697171186, -0.006189599, 0.0000337077, 0.014291981, 0.0000105633, -0.0000387956],
                        [0.555513805, -0.001337363, -0.00000265117, 0.014328826, 0.0000163849, -0.0000480711]]
    hEAT_EIR_FT_SPEC = [[0.708311527, 0.020732093, 0.000391479, -0.037640031, 0.000979937, -0.001079042],
                        [0.025480155, 0.020169585, 0.000121341, -0.004429789, 0.000166472, -0.00036447],
                        [0.379003189, 0.014195012, 0.0000821046, -0.008894061, 0.000151519, -0.000210299],
                        [0.690404655, 0.00616619, 0.000137643, -0.009350199, 0.000153427, -0.000213258]]
    hEAT_CAP_FFLOW_SPEC = [[1, 0, 0]] * num_speeds
    hEAT_EIR_FFLOW_SPEC = [[1, 0, 0]] * num_speeds

    # Cooling Coil
    rated_airflow_rate_cooling = 315.8 # cfm
    cfms_ton_rated_cooling = calc_cfms_ton_rated(rated_airflow_rate_cooling, fan_speed_ratios_cooling, capacity_ratios)
    cooling_eirs = calc_cooling_eirs(num_speeds, eers, fan_power_rated)
    shrs_rated_gross = calc_shrs_rated_gross(num_speeds, shrs, fan_power_rated, cfms_ton_rated_cooling)
    cOOL_CLOSS_FPLR_SPEC = [calc_plr_coefficients_cooling(num_speeds, seer)] * num_speeds

    # Heating Coil
    rated_airflow_rate_heating = 296.9 # cfm
    cfms_ton_rated_heating = calc_cfms_ton_rated(rated_airflow_rate_heating, fan_speed_ratios_heating, capacity_ratios)
    heating_eirs = calc_heating_eirs(num_speeds, cops, fan_power_rated)
    hEAT_CLOSS_FPLR_SPEC = [calc_plr_coefficients_heating(num_speeds, hspf)] * num_speeds

    # Heating defrost curve for reverse cycle
    defrost_eir_curve = create_curve_biquadratic(model, [0.1528, 0, 0, 0, 0, 0], 'DefrostEIR', -100, 100, -100, 100)

    obj_name = Constants.ObjectNameAirSourceHeatPump(unit.name.to_s)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      # _processCurvesDXHeating

      htg_coil_stage_data = calc_coil_stage_data_heating(model, heat_pump_capacity, (0...num_speeds).to_a, heating_eirs, hEAT_CAP_FT_SPEC, hEAT_EIR_FT_SPEC, hEAT_CLOSS_FPLR_SPEC, hEAT_CAP_FFLOW_SPEC, hEAT_EIR_FFLOW_SPEC, curves_in_ip, dse)

      # _processSystemHeatingCoil

      htg_coil = OpenStudio::Model::CoilHeatingDXMultiSpeed.new(model)
      htg_coil.setName(obj_name + ' htg coil')
      htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(UnitConversions.convert(min_temp, 'F', 'C'))
      if frac_heat_load_served <= 0
        htg_coil.setCrankcaseHeaterCapacity(0.0)
      else
        htg_coil.setCrankcaseHeaterCapacity(UnitConversions.convert(crankcase_capacity, 'kW', 'W'))
      end
      htg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(UnitConversions.convert(crankcase_temp, 'F', 'C'))
      htg_coil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(defrost_eir_curve)
      htg_coil.setMaximumOutdoorDryBulbTemperatureforDefrostOperation(UnitConversions.convert(40.0, 'F', 'C'))
      htg_coil.setDefrostStrategy('ReverseCycle')
      htg_coil.setDefrostControl('Timed')
      htg_coil.setApplyPartLoadFractiontoSpeedsGreaterthan1(false)
      htg_coil.setFuelType('Electricity')

      htg_coil_stage_data.each do |stage|
        htg_coil.addStage(stage)
      end

      supp_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
      supp_htg_coil.setName(obj_name + ' supp heater')
      supp_htg_coil.setEfficiency(dse * supplemental_efficiency)
      if supplemental_capacity != Constants.SizingAuto
        supp_htg_coil.setNominalCapacity(UnitConversions.convert(supplemental_capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
      end

      # _processSystemFan

      fan_power_curve = create_curve_exponent(model, [0, 1, 3], obj_name + ' fan power curve', -100, 100)
      fan_eff_curve = create_curve_cubic(model, [0, 1, 0, 0], obj_name + ' fan eff curve', 0, 1, 0.01, 1)

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule, fan_power_curve, fan_eff_curve)
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + ' htg supply fan')
      fan.setEndUseSubcategory(obj_name + ' htg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power_installed / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
      perf.setSingleModeOperation(false)
      for speed in 1..num_speeds
        f = OpenStudio::Model::SupplyAirflowRatioField.new(fan_speed_ratios_heating[speed - 1], Constants.small)
        perf.addSupplyAirflowRatioField(f)
      end

      # _processSystemAir

      htg_air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      htg_air_loop_unitary.setName(obj_name + ' htg asys')
      if frac_heat_load_served <= 0
        htg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
      else
        htg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      end
      htg_air_loop_unitary.setSupplyFan(fan)
      htg_air_loop_unitary.setHeatingCoil(htg_coil)
      htg_air_loop_unitary.setSupplementalHeatingCoil(supp_htg_coil)
      htg_air_loop_unitary.setFanPlacement('BlowThrough')
      htg_air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      htg_air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(170.0, 'F', 'C')) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      htg_air_loop_unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(UnitConversions.convert(40.0, 'F', 'C'))
      htg_air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)
      htg_air_loop_unitary.setDesignSpecificationMultispeedObject(perf)

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' central htg air system')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      htg_air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{fan.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{htg_coil.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{supp_htg_coil.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")

      htg_air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      # _processSystemDemandSideAir
      # Demand Side

      # Supply Air
      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' htg zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' htg zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} htg direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} htg direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end # slave_zone

      # _processCurvesDXCooling

      clg_coil_stage_data = calc_coil_stage_data_cooling(model, heat_pump_capacity, (0...num_speeds).to_a, cooling_eirs, shrs_rated_gross, cOOL_CAP_FT_SPEC, cOOL_EIR_FT_SPEC, cOOL_CLOSS_FPLR_SPEC, cOOL_CAP_FFLOW_SPEC, cOOL_EIR_FFLOW_SPEC, curves_in_ip, dse)

      # _processSystemCoolingCoil

      clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
      clg_coil.setName(obj_name + ' clg coil')
      clg_coil.setCondenserType('AirCooled')
      clg_coil.setApplyPartLoadFractiontoSpeedsGreaterthan1(false)
      clg_coil.setApplyLatentDegradationtoSpeedsGreaterthan1(false)
      clg_coil.setFuelType('Electricity')

      clg_coil_stage_data.each do |stage|
        clg_coil.addStage(stage)
      end

      # _processSystemFan

      fan_power_curve = create_curve_exponent(model, [0, 1, 3], obj_name + ' fan power curve', -100, 100)
      fan_eff_curve = create_curve_cubic(model, [0, 1, 0, 0], obj_name + ' fan eff curve', 0, 1, 0.01, 1)

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule, fan_power_curve, fan_eff_curve)
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + ' clg supply fan')
      fan.setEndUseSubcategory(obj_name + ' clg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power_installed / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
      perf.setSingleModeOperation(false)
      for speed in 1..num_speeds
        f = OpenStudio::Model::SupplyAirflowRatioField.new(Constants.small, fan_speed_ratios_cooling[speed - 1])
        perf.addSupplyAirflowRatioField(f)
      end

      # _processSystemAir

      clg_air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      clg_air_loop_unitary.setName(obj_name + ' clg unitary system')
      if frac_cool_load_served <= 0
        clg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
      else
        clg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      end
      clg_air_loop_unitary.setSupplyFan(fan)
      clg_air_loop_unitary.setCoolingCoil(clg_coil)
      clg_air_loop_unitary.setFanPlacement('BlowThrough')
      clg_air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      clg_air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(170.0, 'F', 'C')) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      clg_air_loop_unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(UnitConversions.convert(40.0, 'F', 'C'))
      clg_air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)
      clg_air_loop_unitary.setDesignSpecificationMultispeedObject(perf)

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' central clg air system')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      clg_air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{fan.name}' to '#{clg_air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{clg_coil.name}' to '#{clg_air_loop_unitary.name}' of '#{air_loop.name}'")

      clg_air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      # _processSystemDemandSideAir
      # Demand Side

      # Supply Air
      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' clg zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' clg zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} clg direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} clg direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end # slave_zone

      # Store info for HVAC Sizing measure
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityRatioCooling, capacity_ratios.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityRatioHeating, capacity_ratios.join(','))
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityDerateFactorEER, eer_capacity_derates.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityDerateFactorCOP, cop_capacity_derates.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHPSizedForMaxLoad, (heat_pump_capacity == Constants.SizingAutoMaxLoad))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACRatedCFMperTonHeating, cfms_ton_rated_heating.join(','))
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACRatedCFMperTonCooling, cfms_ton_rated_cooling.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracHeatLoadServed, frac_heat_load_served)
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracCoolLoadServed, frac_cool_load_served)
    end # control_zone

    return true
  end

  def self.apply_mshp(model, unit, runner, seer, hspf, shr,
                      min_cooling_capacity, max_cooling_capacity,
                      min_cooling_airflow_rate, max_cooling_airflow_rate,
                      min_heating_capacity, max_heating_capacity,
                      min_heating_airflow_rate, max_heating_airflow_rate,
                      heating_capacity_offset, cap_retention_frac, cap_retention_temp,
                      pan_heater_power, fan_power, is_ducted,
                      heat_pump_capacity, supplemental_efficiency, supplemental_capacity,
                      dse, frac_heat_load_served, frac_cool_load_served)

    num_speeds = 10

    # htg_supply_air_temp = 105
    supp_htg_max_supply_temp = 200.0
    min_hp_temp = -30.0 # F; Minimum temperature for Heat Pump operation
    supp_htg_max_outdoor_temp = 40.0
    max_defrost_temp = 40.0 # F

    # Performance curves
    # NOTE: These coefficients are in SI UNITS
    curves_in_ip = false
    cOOL_CAP_FT_SPEC = [[1.008993521905866, 0.006512749025457, 0.0, 0.003917565735935, -0.000222646705889, 0.0]] * num_speeds
    cOOL_EIR_FT_SPEC = [[0.429214441601141, -0.003604841598515, 0.000045783162727, 0.026490875804937, -0.000159212286878, -0.000159062656483]] * num_speeds
    cOOL_CAP_FFLOW_SPEC = [[1, 0, 0]] * num_speeds
    cOOL_EIR_FFLOW_SPEC = [[1, 0, 0]] * num_speeds

    # Mini-Split Heat Pump Heating Curve Coefficients
    # Derive coefficients from user input for capacity retention at outdoor drybulb temperature X [C].
    # Biquadratic: capacity multiplier = a + b*IAT + c*IAT^2 + d*OAT + e*OAT^2 + f*IAT*OAT
    x_A = UnitConversions.convert(cap_retention_temp, 'F', 'C')
    y_A = cap_retention_frac
    x_B = UnitConversions.convert(47.0, 'F', 'C') # 47F is the rating point
    y_B = 1.0 # Maximum capacity factor is 1 at the rating point, by definition (this is maximum capacity, not nominal capacity)
    oat_slope = (y_B - y_A) / (x_B - x_A)
    oat_intercept = y_A - (x_A * oat_slope)

    # Coefficients for the indoor temperature relationship are retained from the BEoptDefault curve (Daikin lab data).
    iat_slope = -0.010386676170938
    iat_intercept = 0.219274275

    a = oat_intercept + iat_intercept
    b = iat_slope
    c = 0
    d = oat_slope
    e = 0
    f = 0
    hEAT_CAP_FT_SPEC = [[a, b, c, d, e, f]] * num_speeds

    # COP/EIR as a function of temperature
    # Generic "BEoptDefault" curves (=Daikin from lab data)
    hEAT_EIR_FT_SPEC = [[0.966475472847719, 0.005914950101249, 0.000191201688297, -0.012965668198361, 0.000042253229429, -0.000524002558712]] * num_speeds
    hEAT_CAP_FFLOW_SPEC = [[1, 0, 0]] * num_speeds
    hEAT_EIR_FFLOW_SPEC = [[1, 0, 0]] * num_speeds

    # Cooling Coil
    c_d_cooling = 0.25
    cOOL_CLOSS_FPLR_SPEC = [calc_plr_coefficients_cooling(num_speeds, seer, c_d_cooling)] * num_speeds
    dB_rated = 80.0
    wB_rated = 67.0
    cfms_cooling, capacity_ratios_cooling, shrs_rated = calc_mshp_cfms_ton_cooling(min_cooling_capacity, max_cooling_capacity, min_cooling_airflow_rate, max_cooling_airflow_rate, num_speeds, dB_rated, wB_rated, shr)
    cooling_eirs = calc_mshp_cooling_eirs(runner, seer, fan_power, c_d_cooling, num_speeds, capacity_ratios_cooling, cfms_cooling, cOOL_EIR_FT_SPEC, cOOL_CAP_FT_SPEC)

    # Heating Coil
    c_d_heating = 0.40
    hEAT_CLOSS_FPLR_SPEC = [calc_plr_coefficients_heating(num_speeds, hspf, c_d_heating)] * num_speeds
    cfms_heating, capacity_ratios_heating = calc_mshp_cfms_ton_heating(min_heating_capacity, max_heating_capacity, min_heating_airflow_rate, max_heating_airflow_rate, num_speeds)
    heating_eirs = calc_mshp_heating_eirs(runner, hspf, fan_power, min_hp_temp, c_d_heating, cfms_cooling, num_speeds, capacity_ratios_heating, cfms_heating, hEAT_EIR_FT_SPEC, hEAT_CAP_FT_SPEC)

    defrost_eir_curve = create_curve_biquadratic(model, [0.1528, 0, 0, 0, 0, 0], 'DefrostEIR', -100, 100, -100, 100)

    mshp_indices = [1, 3, 5, 9]

    obj_name = Constants.ObjectNameMiniSplitHeatPump(unit.name.to_s)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      # _processCurvesDXHeating

      htg_coil_stage_data = calc_coil_stage_data_heating(model, heat_pump_capacity, mshp_indices, heating_eirs, hEAT_CAP_FT_SPEC, hEAT_EIR_FT_SPEC, hEAT_CLOSS_FPLR_SPEC, hEAT_CAP_FFLOW_SPEC, hEAT_EIR_FFLOW_SPEC, curves_in_ip, dse)

      # _processSystemHeatingCoil

      htg_coil = OpenStudio::Model::CoilHeatingDXMultiSpeed.new(model)
      htg_coil.setName(obj_name + ' htg coil')
      htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(UnitConversions.convert(min_hp_temp, 'F', 'C'))
      htg_coil.setCrankcaseHeaterCapacity(0)
      htg_coil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(defrost_eir_curve)
      htg_coil.setMaximumOutdoorDryBulbTemperatureforDefrostOperation(UnitConversions.convert(max_defrost_temp, 'F', 'C'))
      htg_coil.setDefrostStrategy('ReverseCycle')
      htg_coil.setDefrostControl('Timed')
      htg_coil.setApplyPartLoadFractiontoSpeedsGreaterthan1(false)
      htg_coil.setFuelType('Electricity')

      htg_coil_stage_data.each do |stage|
        htg_coil.addStage(stage)
      end

      supp_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
      supp_htg_coil.setName(obj_name + ' supp heater')
      supp_htg_coil.setEfficiency(dse * supplemental_efficiency)
      if supplemental_capacity != Constants.SizingAuto
        supp_htg_coil.setNominalCapacity(UnitConversions.convert(supplemental_capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
      end

      # _processSystemFan

      fan_power_curve = create_curve_exponent(model, [0, 1, 3], obj_name + ' fan power curve', -100, 100)
      fan_eff_curve = create_curve_cubic(model, [0, 1, 0, 0], obj_name + ' fan eff curve', 0, 1, 0.01, 1)

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule, fan_power_curve, fan_eff_curve)
      fan_eff = UnitConversions.convert(UnitConversions.convert(0.1, 'inH2O', 'Pa') / fan_power, 'cfm', 'm^3/s') # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + ' htg supply fan')
      fan.setEndUseSubcategory(obj_name + ' htg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
      perf.setSingleModeOperation(false)
      mshp_indices.each do |mshp_index|
        ratio = cfms_heating[mshp_index] / cfms_heating[mshp_indices[-1]]
        f = OpenStudio::Model::SupplyAirflowRatioField.new(ratio, Constants.small)
        perf.addSupplyAirflowRatioField(f)
      end

      # _processSystemAir

      htg_air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      htg_air_loop_unitary.setName(obj_name + ' htg unitary system')
      if frac_heat_load_served <= 0
        htg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
      else
        htg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      end
      htg_air_loop_unitary.setSupplyFan(fan)
      htg_air_loop_unitary.setHeatingCoil(htg_coil)
      htg_air_loop_unitary.setSupplementalHeatingCoil(supp_htg_coil)
      htg_air_loop_unitary.setFanPlacement('BlowThrough')
      htg_air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      htg_air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(supp_htg_max_supply_temp, 'F', 'C')) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      htg_air_loop_unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(UnitConversions.convert(supp_htg_max_outdoor_temp, 'F', 'C'))
      htg_air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)
      htg_air_loop_unitary.setDesignSpecificationMultispeedObject(perf)

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' htg asys')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      htg_air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{fan.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{htg_coil.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{supp_htg_coil.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")

      htg_air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      # _processSystemDemandSideAir
      # Demand Side

      # Supply Air
      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' htg zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' htg zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} htg direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} htg direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end # slave_zone

      if pan_heater_power > 0

        mshp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Heating Coil Electricity Energy')
        mshp_sensor.setName("#{obj_name} vrf energy sensor".gsub('|', '_'))
        mshp_sensor.setKeyName(obj_name + ' htg coil')

        equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
        equip_def.setName(obj_name + ' pan heater equip')
        equip = OpenStudio::Model::ElectricEquipment.new(equip_def)
        equip.setName(equip_def.name.to_s)
        equip.setSpace(control_zone.spaces[0])
        equip_def.setFractionRadiant(0)
        equip_def.setFractionLatent(0)
        equip_def.setFractionLost(1)
        equip.setSchedule(model.alwaysOnDiscreteSchedule)
        equip.setEndUseSubcategory(obj_name + ' pan heater')

        pan_heater_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(equip, 'ElectricEquipment', 'Electricity Rate')
        pan_heater_actuator.setName("#{obj_name} pan heater actuator".gsub('|', '_'))

        tout_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Outdoor Air Drybulb Temperature')
        tout_sensor.setName("#{obj_name} tout sensor".gsub('|', '_'))
        thermal_zones.each do |thermal_zone|
          if Geometry.is_living(thermal_zone)
            tout_sensor.setKeyName(thermal_zone.name.to_s)
            break
          end
        end

        program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
        program.setName(obj_name + ' pan heater program')
        if (heat_pump_capacity != Constants.SizingAuto) && (heat_pump_capacity != Constants.SizingAutoMaxLoad)
          num_outdoor_units = (UnitConversions.convert(heat_pump_capacity, 'Btu/hr', 'ton') / 1.5).ceil # Assume 1.5 tons max per outdoor unit
        else
          num_outdoor_units = 2
        end
        unless slave_zones.empty?
          num_outdoor_units = [num_outdoor_units, 2].max
        end
        pan_heater_power *= num_outdoor_units # W
        program.addLine("Set #{pan_heater_actuator.name} = 0")
        program.addLine("If #{mshp_sensor.name} > 0")
        program.addLine("  If #{tout_sensor.name} <= #{UnitConversions.convert(32.0, 'F', 'C').round(3)}")
        program.addLine("    Set #{pan_heater_actuator.name} = #{pan_heater_power}")
        program.addLine('  EndIf')
        program.addLine('EndIf')

        program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
        program_calling_manager.setName(obj_name + ' pan heater program calling manager')
        program_calling_manager.setCallingPoint('BeginTimestepBeforePredictor')
        program_calling_manager.addProgram(program)

      end

      # _processCurvesDXCooling

      clg_coil_stage_data = calc_coil_stage_data_cooling(model, heat_pump_capacity, mshp_indices, cooling_eirs, shrs_rated, cOOL_CAP_FT_SPEC, cOOL_EIR_FT_SPEC, cOOL_CLOSS_FPLR_SPEC, cOOL_CAP_FFLOW_SPEC, cOOL_EIR_FFLOW_SPEC, curves_in_ip, dse)

      # _processSystemCoolingCoil

      clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
      clg_coil.setName(obj_name + ' clg coil')
      clg_coil.setCondenserType('AirCooled')
      clg_coil.setApplyPartLoadFractiontoSpeedsGreaterthan1(false)
      clg_coil.setApplyLatentDegradationtoSpeedsGreaterthan1(false)
      clg_coil.setCrankcaseHeaterCapacity(0)
      clg_coil.setFuelType('Electricity')

      clg_coil_stage_data.each do |stage|
        clg_coil.addStage(stage)
      end

      # _processSystemFan

      fan_power_curve = create_curve_exponent(model, [0, 1, 3], obj_name + ' fan power curve', -100, 100)
      fan_eff_curve = create_curve_cubic(model, [0, 1, 0, 0], obj_name + ' fan eff curve', 0, 1, 0.01, 1)

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule, fan_power_curve, fan_eff_curve)
      fan_eff = UnitConversions.convert(UnitConversions.convert(0.1, 'inH2O', 'Pa') / fan_power, 'cfm', 'm^3/s') # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + ' clg supply fan')
      fan.setEndUseSubcategory(obj_name + ' clg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
      perf.setSingleModeOperation(false)
      mshp_indices.each do |mshp_index|
        ratio = cfms_cooling[mshp_index] / cfms_cooling[mshp_indices[-1]]
        f = OpenStudio::Model::SupplyAirflowRatioField.new(Constants.small, ratio)
        perf.addSupplyAirflowRatioField(f)
      end

      # _processSystemAir

      clg_air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      clg_air_loop_unitary.setName(obj_name + ' clg unitary system')
      if frac_cool_load_served <= 0
        clg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
      else
        clg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      end
      clg_air_loop_unitary.setSupplyFan(fan)
      clg_air_loop_unitary.setCoolingCoil(clg_coil)
      clg_air_loop_unitary.setFanPlacement('BlowThrough')
      clg_air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      clg_air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(supp_htg_max_supply_temp, 'F', 'C')) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      clg_air_loop_unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(UnitConversions.convert(40.0, 'F', 'C'))
      clg_air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)
      clg_air_loop_unitary.setDesignSpecificationMultispeedObject(perf)

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' clg asys')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      clg_air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{fan.name}' to '#{clg_air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{clg_coil.name}' to '#{clg_air_loop_unitary.name}' of '#{air_loop.name}'")

      clg_air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      # _processSystemDemandSideAir
      # Demand Side

      # Supply Air
      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' clg zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' clg zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} clg direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} clg direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end # slave_zone

      # Store info for HVAC Sizing measure
      capacity_ratios_heating_4 = []
      capacity_ratios_cooling_4 = []
      cfms_heating_4 = []
      cfms_cooling_4 = []
      shrs_rated_4 = []
      mshp_indices.each do |mshp_index|
        capacity_ratios_heating_4 << capacity_ratios_heating[mshp_index]
        capacity_ratios_cooling_4 << capacity_ratios_cooling[mshp_index]
        cfms_heating_4 << cfms_heating[mshp_index]
        cfms_cooling_4 << cfms_cooling[mshp_index]
        shrs_rated_4 << shrs_rated[mshp_index]
      end
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.DuctedInfoMiniSplitHeatPump, is_ducted)
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.DuctedInfoMiniSplitHeatPump, is_ducted)
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityRatioHeating, capacity_ratios_heating_4.join(','))
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCapacityRatioCooling, capacity_ratios_cooling_4.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACHeatingCFMs, cfms_heating_4.join(','))
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACCoolingCFMs, cfms_cooling_4.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACHeatingCapacityOffset, heating_capacity_offset)
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHPSizedForMaxLoad, (heat_pump_capacity == Constants.SizingAutoMaxLoad))
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACSHR, shrs_rated_4.join(','))
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracHeatLoadServed, frac_heat_load_served)
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracCoolLoadServed, frac_cool_load_served)
    end # control_zone

    return true
  end

  def self.apply_gshp(model, unit, runner, weather, cop, eer, shr,
                      ground_conductivity, grout_conductivity,
                      bore_config, bore_holes, bore_depth,
                      bore_spacing, bore_diameter, pipe_size,
                      ground_diffusivity, fluid_type, frac_glycol,
                      design_delta_t, pump_head,
                      u_tube_leg_spacing, u_tube_spacing_type,
                      fan_power, heat_pump_capacity, supplemental_efficiency,
                      supplemental_capacity, dse,
                      frac_heat_load_served, frac_cool_load_served)

    if frac_glycol == 0
      fluid_type = Constants.FluidWater
      runner.registerWarning("Specified #{fluid_type} fluid type and 0 fraction of glycol, so assuming #{Constants.FluidWater} fluid type.")
    end

    # Ground Loop Heat Exchanger
    pipe_od, pipe_id = get_gshp_hx_pipe_diameters(pipe_size)

    # Thermal Resistance of Pipe
    pipe_cond = 0.23 # Pipe thermal conductivity, default to high density polyethylene

    chw_design = get_gshp_HXCHWDesign(weather)
    hw_design = get_gshp_HXHWDesign(weather, fluid_type)

    # Cooling Coil
    cOOL_CAP_FT_SPEC = [0.39039063, 0.01382596, 0.00000000, -0.00445738, 0.00000000, 0.00000000]
    cOOL_SH_FT_SPEC = [4.27136253, -0.04678521, 0.00000000, -0.00219031, 0.00000000, 0.00000000]
    cOOL_POWER_FT_SPEC = [0.01717338, 0.00316077, 0.00000000, 0.01043792, 0.00000000, 0.00000000]
    cOIL_BF_FT_SPEC = [1.21005458, -0.00664200, 0.00000000, 0.00348246, 0.00000000, 0.00000000]
    coilBF = 0.08060000

    # Heating Coil
    hEAT_CAP_FT_SEC = [0.67104926, -0.00210834, 0.00000000, 0.01491424, 0.00000000, 0.00000000]
    hEAT_POWER_FT_SPEC = [-0.46308105, 0.02008988, 0.00000000, 0.00300222, 0.00000000, 0.00000000]

    fanKW_Adjust = get_gshp_FanKW_Adjust(UnitConversions.convert(400.0, 'Btu/hr', 'ton'))
    pumpKW_Adjust = get_gshp_PumpKW_Adjust(UnitConversions.convert(3.0, 'Btu/hr', 'ton'))
    coolingEIR = get_gshp_cooling_eir(eer, fanKW_Adjust, pumpKW_Adjust)

    # Heating Coil
    heatingEIR = get_gshp_heating_eir(cop, fanKW_Adjust, pumpKW_Adjust)
    min_hp_temp = -30.0

    obj_name = Constants.ObjectNameGroundSourceHeatPumpVerticalBore(unit.name.to_s)

    ground_heat_exch_vert = OpenStudio::Model::GroundHeatExchangerVertical.new(model)
    ground_heat_exch_vert.setName(obj_name + ' exchanger')
    ground_heat_exch_vert.setBoreHoleRadius(UnitConversions.convert(bore_diameter / 2.0, 'in', 'm'))
    ground_heat_exch_vert.setGroundThermalConductivity(UnitConversions.convert(ground_conductivity, 'Btu/(hr*ft*R)', 'W/(m*K)'))
    ground_heat_exch_vert.setGroundThermalHeatCapacity(UnitConversions.convert(ground_conductivity / ground_diffusivity, 'Btu/(ft^3*F)', 'J/(m^3*K)'))
    ground_heat_exch_vert.setGroundTemperature(UnitConversions.convert(weather.data.AnnualAvgDrybulb, 'F', 'C'))
    ground_heat_exch_vert.setGroutThermalConductivity(UnitConversions.convert(grout_conductivity, 'Btu/(hr*ft*R)', 'W/(m*K)'))
    ground_heat_exch_vert.setPipeThermalConductivity(UnitConversions.convert(pipe_cond, 'Btu/(hr*ft*R)', 'W/(m*K)'))
    ground_heat_exch_vert.setPipeOutDiameter(UnitConversions.convert(pipe_od, 'in', 'm'))
    ground_heat_exch_vert.setUTubeDistance(UnitConversions.convert(u_tube_leg_spacing, 'in', 'm'))
    ground_heat_exch_vert.setPipeThickness(UnitConversions.convert((pipe_od - pipe_id) / 2.0, 'in', 'm'))
    ground_heat_exch_vert.setMaximumLengthofSimulation(1)
    ground_heat_exch_vert.setGFunctionReferenceRatio(0.0005)

    plant_loop = OpenStudio::Model::PlantLoop.new(model)
    plant_loop.setName(obj_name + ' condenser loop')
    if fluid_type == Constants.FluidWater
      plant_loop.setFluidType('Water')
    else
      plant_loop.setFluidType({ Constants.FluidPropyleneGlycol => 'PropyleneGlycol', Constants.FluidEthyleneGlycol => 'EthyleneGlycol' }[fluid_type])
      plant_loop.setGlycolConcentration((frac_glycol * 100).to_i)
    end
    plant_loop.setMaximumLoopTemperature(48.88889)
    plant_loop.setMinimumLoopTemperature(UnitConversions.convert(hw_design, 'F', 'C'))
    plant_loop.setMinimumLoopFlowRate(0)
    plant_loop.setLoadDistributionScheme('SequentialLoad')
    runner.registerInfo("Added '#{plant_loop.name}' to model.")

    sizing_plant = plant_loop.sizingPlant
    sizing_plant.setLoopType('Condenser')
    sizing_plant.setDesignLoopExitTemperature(UnitConversions.convert(chw_design, 'F', 'C'))
    sizing_plant.setLoopDesignTemperatureDifference(UnitConversions.convert(design_delta_t, 'R', 'K'))

    setpoint_mgr_follow_ground_temp = OpenStudio::Model::SetpointManagerFollowGroundTemperature.new(model)
    setpoint_mgr_follow_ground_temp.setName(obj_name + ' condenser loop temp')
    setpoint_mgr_follow_ground_temp.setControlVariable('Temperature')
    setpoint_mgr_follow_ground_temp.setMaximumSetpointTemperature(48.88889)
    setpoint_mgr_follow_ground_temp.setMinimumSetpointTemperature(UnitConversions.convert(hw_design, 'F', 'C'))
    setpoint_mgr_follow_ground_temp.setReferenceGroundTemperatureObjectType('Site:GroundTemperature:Deep')
    setpoint_mgr_follow_ground_temp.addToNode(plant_loop.supplyOutletNode)

    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setName(obj_name + ' pump')
    pump.setRatedPumpHead(pump_head)
    pump.setMotorEfficiency(dse * 0.77 * 0.6)
    pump.setFractionofMotorInefficienciestoFluidStream(0)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(1)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(0)
    pump.setMinimumFlowRate(0)
    pump.setPumpControlType('Intermittent')
    pump.addToNode(plant_loop.supplyInletNode)

    pump_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Pump Electricity Energy')
    pump_sensor.setName("#{pump.name.to_s.gsub('|', '_')} s")
    pump_sensor.setKeyName(pump.name.to_s)

    plant_loop.addSupplyBranchForComponent(ground_heat_exch_vert)

    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    plant_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    plant_loop.addDemandBranchForComponent(coil_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.addToNode(plant_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.addToNode(plant_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.addToNode(plant_loop.demandOutletNode)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    htg_coil_sensor = nil
    clg_coil_sensor = nil
    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      gshp_HEAT_CAP_fT_coeff = convert_curve_gshp(hEAT_CAP_FT_SEC, false)
      gshp_HEAT_POWER_fT_coeff = convert_curve_gshp(hEAT_POWER_FT_SPEC, false)

      htg_cap_curve = OpenStudio::Model::CurveQuadLinear.new(model)
      htg_cap_curve.setName(obj_name + ' htg cap curve')
      htg_cap_curve.setCoefficient1Constant(gshp_HEAT_CAP_fT_coeff[0])
      htg_cap_curve.setCoefficient2w(gshp_HEAT_CAP_fT_coeff[1])
      htg_cap_curve.setCoefficient3x(gshp_HEAT_CAP_fT_coeff[2])
      htg_cap_curve.setCoefficient4y(gshp_HEAT_CAP_fT_coeff[3])
      htg_cap_curve.setCoefficient5z(gshp_HEAT_CAP_fT_coeff[4])

      htg_power_curve = OpenStudio::Model::CurveQuadLinear.new(model)
      htg_power_curve.setName(obj_name + ' htg power curve')
      htg_power_curve.setCoefficient1Constant(gshp_HEAT_POWER_fT_coeff[0])
      htg_power_curve.setCoefficient2w(gshp_HEAT_POWER_fT_coeff[1])
      htg_power_curve.setCoefficient3x(gshp_HEAT_POWER_fT_coeff[2])
      htg_power_curve.setCoefficient4y(gshp_HEAT_POWER_fT_coeff[3])
      htg_power_curve.setCoefficient5z(gshp_HEAT_POWER_fT_coeff[4])

      htg_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(model, htg_cap_curve, htg_power_curve)
      htg_coil.setName(obj_name + ' heating coil')
      if heat_pump_capacity != Constants.SizingAuto
        htg_coil.setRatedHeatingCapacity(OpenStudio::OptionalDouble.new(UnitConversions.convert(heat_pump_capacity, 'Btu/hr', 'W'))) # Used by HVACSizing measure
      end
      htg_coil.setRatedHeatingCoefficientofPerformance(dse / heatingEIR)

      htg_coil_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Heating Coil Electricity Energy')
      htg_coil_sensor.setName("#{htg_coil.name.to_s.gsub('|', '_')} s")
      htg_coil_sensor.setKeyName(htg_coil.name.to_s)

      plant_loop.addDemandBranchForComponent(htg_coil)

      supp_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
      supp_htg_coil.setName(obj_name + ' supp heater')
      supp_htg_coil.setEfficiency(dse * supplemental_efficiency)
      if supplemental_capacity != Constants.SizingAuto
        supp_htg_coil.setNominalCapacity(UnitConversions.convert(supplemental_capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
      end

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + " #{control_zone.name} htg supply fan")
      fan.setEndUseSubcategory(obj_name + ' htg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      htg_air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      htg_air_loop_unitary.setName(obj_name + ' htg unitary system')
      if frac_heat_load_served <= 0
        htg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
      else
        htg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      end
      htg_air_loop_unitary.setSupplyFan(fan)
      htg_air_loop_unitary.setHeatingCoil(htg_coil)
      htg_air_loop_unitary.setSupplementalHeatingCoil(supp_htg_coil)
      htg_air_loop_unitary.setFanPlacement('BlowThrough')
      htg_air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      htg_air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(170.0, 'F', 'C')) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      htg_air_loop_unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(UnitConversions.convert(40.0, 'F', 'C'))
      htg_air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' central htg air system')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      htg_air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{htg_coil.name}' to '#{htg_air_loop_unitary.name}' of '#{air_loop.name}'")

      htg_air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' htg zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' htg zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} htg direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} htg direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end

      gshp_COOL_CAP_fT_coeff = convert_curve_gshp(cOOL_CAP_FT_SPEC, false)
      gshp_COOL_POWER_fT_coeff = convert_curve_gshp(cOOL_POWER_FT_SPEC, false)
      gshp_COOL_SH_fT_coeff = convert_curve_gshp(cOOL_SH_FT_SPEC, false)

      clg_total_cap_curve = OpenStudio::Model::CurveQuadLinear.new(model)
      clg_total_cap_curve.setName(obj_name + ' clg total cap curve')
      clg_total_cap_curve.setCoefficient1Constant(gshp_COOL_CAP_fT_coeff[0])
      clg_total_cap_curve.setCoefficient2w(gshp_COOL_CAP_fT_coeff[1])
      clg_total_cap_curve.setCoefficient3x(gshp_COOL_CAP_fT_coeff[2])
      clg_total_cap_curve.setCoefficient4y(gshp_COOL_CAP_fT_coeff[3])
      clg_total_cap_curve.setCoefficient5z(gshp_COOL_CAP_fT_coeff[4])

      clg_sens_cap_curve = OpenStudio::Model::CurveQuintLinear.new(model)
      clg_sens_cap_curve.setName(obj_name + ' clg sens cap curve')
      clg_sens_cap_curve.setCoefficient1Constant(gshp_COOL_SH_fT_coeff[0])
      clg_sens_cap_curve.setCoefficient2v(0)
      clg_sens_cap_curve.setCoefficient3w(gshp_COOL_SH_fT_coeff[1])
      clg_sens_cap_curve.setCoefficient4x(gshp_COOL_SH_fT_coeff[2])
      clg_sens_cap_curve.setCoefficient5y(gshp_COOL_SH_fT_coeff[3])
      clg_sens_cap_curve.setCoefficient6z(gshp_COOL_SH_fT_coeff[4])

      clg_power_curve = OpenStudio::Model::CurveQuadLinear.new(model)
      clg_power_curve.setName(obj_name + ' clg power curve')
      clg_power_curve.setCoefficient1Constant(gshp_COOL_POWER_fT_coeff[0])
      clg_power_curve.setCoefficient2w(gshp_COOL_POWER_fT_coeff[1])
      clg_power_curve.setCoefficient3x(gshp_COOL_POWER_fT_coeff[2])
      clg_power_curve.setCoefficient4y(gshp_COOL_POWER_fT_coeff[3])
      clg_power_curve.setCoefficient5z(gshp_COOL_POWER_fT_coeff[4])

      clg_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(model, clg_total_cap_curve, clg_sens_cap_curve, clg_power_curve)
      clg_coil.setName(obj_name + ' cooling coil')
      if heat_pump_capacity != Constants.SizingAuto
        clg_coil.setRatedTotalCoolingCapacity(UnitConversions.convert(heat_pump_capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
      end
      clg_coil.setRatedCoolingCoefficientofPerformance(dse / coolingEIR)
      clg_coil.setNominalTimeforCondensateRemovaltoBegin(1000)
      clg_coil.setRatioofInitialMoistureEvaporationRateandSteadyStateLatentCapacity(1.5)

      clg_coil_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Cooling Coil Electricity Energy')
      clg_coil_sensor.setName("#{clg_coil.name.to_s.gsub('|', '_')} s")
      clg_coil_sensor.setKeyName(clg_coil.name.to_s)

      plant_loop.addDemandBranchForComponent(clg_coil)

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + " #{control_zone.name} clg supply fan")
      fan.setEndUseSubcategory(obj_name + ' clg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      clg_air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      clg_air_loop_unitary.setName(obj_name + ' clg unitary system')
      if frac_cool_load_served <= 0
        clg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
      else
        clg_air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      end
      clg_air_loop_unitary.setSupplyFan(fan)
      clg_air_loop_unitary.setCoolingCoil(clg_coil)
      clg_air_loop_unitary.setFanPlacement('BlowThrough')
      clg_air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      clg_air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(170.0, 'F', 'C')) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      clg_air_loop_unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(UnitConversions.convert(40.0, 'F', 'C'))
      clg_air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' central clg air system')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      clg_air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{clg_coil.name}' to '#{clg_air_loop_unitary.name}' of '#{air_loop.name}'")

      clg_air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' clg zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' clg zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} clg direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} clg direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end

      # Store info for HVAC Sizing measure
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACSHR, shr.to_s)
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoGSHPCoil_BF_FT_SPEC, cOIL_BF_FT_SPEC.join(','))
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoGSHPCoilBF, coilBF)
      htg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracHeatLoadServed, frac_heat_load_served)
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracCoolLoadServed, frac_cool_load_served)
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoGSHPBoreSpacing, bore_spacing)
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoGSHPBoreHoles, bore_holes)
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoGSHPBoreDepth, bore_depth)
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoGSHPBoreConfig, bore_config)
      clg_air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoGSHPUTubeSpacingType, u_tube_spacing_type)
    end

    # Disaggregate electric pump energy
    pump_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    pump_program.setName("#{obj_name} pumps program")
    pump_program.addLine("Set #{unit.name.to_s.gsub(' ', '_')}_pumps_h = 0")
    pump_program.addLine("Set #{unit.name.to_s.gsub(' ', '_')}_pumps_c = 0")
    pump_program.addLine("If #{htg_coil_sensor.name} > 0")
    pump_program.addLine("  Set #{unit.name.to_s.gsub(' ', '_')}_pumps_h = #{pump_sensor.name}")
    pump_program.addLine("ElseIf #{clg_coil_sensor.name} > 0")
    pump_program.addLine("  Set #{unit.name.to_s.gsub(' ', '_')}_pumps_c = #{pump_sensor.name}")
    pump_program.addLine('EndIf')

    pump_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, "#{unit.name.to_s.gsub(' ', '_')}_pumps_h")
    pump_output_var.setName("#{obj_name} htg pump:Pumps:Electricity")
    pump_output_var.setTypeOfDataInVariable('Summed')
    pump_output_var.setUpdateFrequency('SystemTimestep')
    pump_output_var.setEMSProgramOrSubroutineName(pump_program)
    pump_output_var.setUnits('J')

    pump_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, "#{unit.name.to_s.gsub(' ', '_')}_pumps_c")
    pump_output_var.setName("#{obj_name} clg pump:Pumps:Electricity")
    pump_output_var.setTypeOfDataInVariable('Summed')
    pump_output_var.setUpdateFrequency('SystemTimestep')
    pump_output_var.setEMSProgramOrSubroutineName(pump_program)
    pump_output_var.setUnits('J')

    pump_program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    pump_program_calling_manager.setName("#{obj_name} pump program calling manager")
    pump_program_calling_manager.setCallingPoint('EndOfSystemTimestepBeforeHVACReporting')
    pump_program_calling_manager.addProgram(pump_program)

    return true
  end

  def self.apply_room_ac(model, unit, runner, eer, shr,
                         airflow_rate, capacity, frac_cool_load_served)

    return true if frac_cool_load_served <= 0

    # From "Improved Modeling of Residential Air Conditioners and Heat Pumps for Energy Calculations", Cutler at al
    # https://www.nrel.gov/docs/fy13osti/56354.pdf
    cOOL_CAP_FT_SPEC = [[3.68637657, -0.098352478, 0.000956357, 0.005838141, -0.0000127, -0.000131702]]
    cOOL_EIR_FT_SPEC = [[-3.437356399, 0.136656369, -0.001049231, -0.0079378, 0.000185435, -0.0001441]]
    cOOL_CAP_FFLOW_SPEC = [[1, 0, 0]]
    cOOL_EIR_FFLOW_SPEC = [[1, 0, 0]]
    cOOL_PLF_FPLR = [[0.78, 0.22, 0]]
    cfms_ton_rated = [312] # medium speed

    # Performance curves
    cOOL_CAP_FT_SPEC_SI = convert_curve_biquadratic(cOOL_CAP_FT_SPEC[0])
    cOOL_EIR_FT_SPEC_SI = convert_curve_biquadratic(cOOL_EIR_FT_SPEC[0])

    roomac_cap_ft_curve = create_curve_biquadratic(model, cOOL_CAP_FT_SPEC_SI, 'RoomAC-Cap-fT', 0, 100, 0, 100)
    roomac_cap_fff_curve = create_curve_quadratic(model, cOOL_CAP_FFLOW_SPEC[0], 'RoomAC-Cap-fFF', 0, 2, 0, 2)
    roomac_eir_ft_curve = create_curve_biquadratic(model, cOOL_EIR_FT_SPEC_SI, 'RoomAC-EIR-fT', 0, 100, 0, 100)
    roomcac_eir_fff_curve = create_curve_quadratic(model, cOOL_EIR_FFLOW_SPEC[0], 'RoomAC-EIR-fFF', 0, 2, 0, 2)
    roomac_plf_fplr_curve = create_curve_quadratic(model, cOOL_PLF_FPLR[0], 'RoomAC-PLF-fPLR', 0, 1, 0, 1)

    obj_name = Constants.ObjectNameRoomAirConditioner(unit.name.to_s)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      ([control_zone] + slave_zones).each do |zone|
        # _processSystemRoomAC

        clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule, roomac_cap_ft_curve, roomac_cap_fff_curve, roomac_eir_ft_curve, roomcac_eir_fff_curve, roomac_plf_fplr_curve)
        clg_coil.setName(obj_name + ' cooling coil')
        if capacity != Constants.SizingAuto
          clg_coil.setRatedTotalCoolingCapacity(UnitConversions.convert(capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
        end
        clg_coil.setRatedSensibleHeatRatio(shr)
        clg_coil.setRatedCOP(UnitConversions.convert(calc_ceer_from_eer(eer), 'Btu/hr', 'W'))
        clg_coil.setRatedEvaporatorFanPowerPerVolumeFlowRate(OpenStudio::OptionalDouble.new(773.3))
        clg_coil.setEvaporativeCondenserEffectiveness(OpenStudio::OptionalDouble.new(0.9))
        clg_coil.setMaximumOutdoorDryBulbTemperatureForCrankcaseHeaterOperation(OpenStudio::OptionalDouble.new(10))
        clg_coil.setBasinHeaterSetpointTemperature(OpenStudio::OptionalDouble.new(2))

        fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
        fan.setName(obj_name + " #{zone.name} clg supply fan")
        fan.setEndUseSubcategory(obj_name + ' clg supply fan')
        fan.setFanEfficiency(1)
        fan.setPressureRise(0)
        fan.setMotorEfficiency(1)
        fan.setMotorInAirstreamFraction(0)

        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOffDiscreteSchedule())
        htg_coil.setName(obj_name + ' always off heating coil')

        ptac = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model, model.alwaysOnDiscreteSchedule, fan, htg_coil, clg_coil)
        ptac.setName(obj_name + ' zone ptac')
        ptac.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
        ptac.addToThermalZone(zone)
        runner.registerInfo("Added '#{ptac.name}' to '#{zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, zone)

        # Store info for HVAC Sizing measure
        ptac.additionalProperties.setFeature(Constants.SizingInfoHVACCoolingCFMs, airflow_rate.to_s)
        ptac.additionalProperties.setFeature(Constants.SizingInfoHVACRatedCFMperTonCooling, cfms_ton_rated.join(','))
        ptac.additionalProperties.setFeature(Constants.SizingInfoHVACFracCoolLoadServed, frac_cool_load_served)
      end # zone
    end # control_zone

    return true
  end

  def self.calc_ceer_from_eer(eer)
    # Reference: http://documents.dps.ny.gov/public/Common/ViewDoc.aspx?DocRefId=%7BB6A57FC0-6376-4401-92BD-D66EC1930DCF%7D
    return eer / 1.01
  end

  def self.apply_furnace(model, unit, runner, fuel_type, afue,
                         capacity, fan_power_installed, dse,
                         frac_heat_load_served, attached_to_multispeed_ac)

    return true if frac_heat_load_served <= 0

    # Parasitic Electricity (Source: DOE. (2007). Technical Support Document: Energy Efficiency Program for Consumer Products: "Energy Conservation Standards for Residential Furnaces and Boilers". www.eere.energy.gov/buildings/appliance_standards/residential/furnaces_boilers.html)
    furnaceParasiticElecDict = { Constants.FuelTypeGas => 76.0, # W during operation
                                 Constants.FuelTypePropane => 76.0,
                                 Constants.FuelTypeOil => 220.0,
                                 Constants.FuelTypeElectric => 0.0 }
    aux_elec = furnaceParasiticElecDict[fuel_type]

    # _processAirSystem

    obj_name = Constants.ObjectNameFurnace(fuel_type, unit.name.to_s)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      # _processSystemHeatingCoil

      if fuel_type == Constants.FuelTypeElectric
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model)
        htg_coil.setEfficiency(dse * afue)
      else
        htg_coil = OpenStudio::Model::CoilHeatingGas.new(model)
        htg_coil.setGasBurnerEfficiency(dse * afue)
        htg_coil.setParasiticElectricLoad(aux_elec)
        htg_coil.setParasiticGasLoad(0)
        htg_coil.setFuelType(HelperMethods.eplus_fuel_map(fuel_type))
      end
      htg_coil.setName(obj_name + ' heating coil')
      if capacity != Constants.SizingAuto
        htg_coil.setNominalCapacity(UnitConversions.convert(capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
      end

      # _processSystemFan

      if attached_to_multispeed_ac
        fan_power_curve = create_curve_exponent(model, [0, 1, 3], obj_name + ' fan power curve', -100, 100)
        fan_eff_curve = create_curve_cubic(model, [0, 1, 0, 0], obj_name + ' fan eff curve', 0, 1, 0.01, 1)

        fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule, fan_power_curve, fan_eff_curve)
      else
        fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      end
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      fan.setName(obj_name + ' htg supply fan')
      fan.setEndUseSubcategory(obj_name + ' htg supply fan')
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power_installed / dse))
      fan.setMotorEfficiency(1.0)
      fan.setMotorInAirstreamFraction(1.0)

      # _processSystemAir

      air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      air_loop_unitary.setName(obj_name + ' unitary system')
      air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      air_loop_unitary.setHeatingCoil(htg_coil)
      air_loop_unitary.setSupplyAirFlowRateDuringCoolingOperation(0.0)
      air_loop_unitary.setSupplyFan(fan)
      air_loop_unitary.setFanPlacement('BlowThrough')
      air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(120.0, 'F', 'C'))
      air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(obj_name + ' asys')
      air_supply_inlet_node = air_loop.supplyInletNode
      air_supply_outlet_node = air_loop.supplyOutletNode
      air_demand_inlet_node = air_loop.demandInletNode
      air_demand_outlet_node = air_loop.demandOutletNode

      air_loop_unitary.addToNode(air_supply_inlet_node)

      runner.registerInfo("Added '#{fan.name}' to '#{air_loop_unitary.name}' of '#{air_loop.name}'")
      runner.registerInfo("Added '#{htg_coil.name}' to '#{air_loop_unitary.name}' of '#{air_loop.name}'")

      air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

      # _processSystemDemandSideAir
      # Demand Side

      # Supply Air
      zone_splitter = air_loop.zoneSplitter
      zone_splitter.setName(obj_name + ' zone splitter')

      zone_mixer = air_loop.zoneMixer
      zone_mixer.setName(obj_name + ' zone mixer')

      diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser_living.setName(obj_name + " #{control_zone.name} direct air")
      air_loop.multiAddBranchForZone(control_zone, diffuser_living)

      air_loop.multiAddBranchForZone(control_zone)
      runner.registerInfo("Added '#{air_loop.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)

      slave_zones.each do |slave_zone|
        diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_fbsmt.setName(obj_name + " #{slave_zone.name} direct air")
        air_loop.multiAddBranchForZone(slave_zone, diffuser_fbsmt)

        air_loop.multiAddBranchForZone(slave_zone)
        runner.registerInfo("Added '#{air_loop.name}' to '#{slave_zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, slave_zone)
      end

      air_loop_unitary.additionalProperties.setFeature(Constants.SizingInfoHVACFracHeatLoadServed, frac_heat_load_served)
    end

    return true
  end

  def self.apply_boiler(model, unit, runner, fuel_type, system_type, afue,
                        oat_reset_enabled, oat_high, oat_low, oat_hwst_high, oat_hwst_low,
                        capacity, design_temp, dse, frac_heat_load_served)

    return true if frac_heat_load_served <= 0

    # _processHydronicSystem

    if system_type == Constants.BoilerTypeSteam
      runner.registerError('Cannot currently model steam boilers.')
      return false
    end

    if oat_reset_enabled
      if oat_high.nil? || oat_low.nil? || oat_hwst_low.nil? || oat_hwst_high.nil?
        runner.registerWarning('Boiler outdoor air temperature (OAT) reset is enabled but no setpoints were specified so OAT reset is being disabled.')
        oat_reset_enabled = false
      end
    end

    # Parasitic Electricity (Source: DOE. (2007). Technical Support Document: Energy Efficiency Program for Consumer Products: "Energy Conservation Standards for Residential Furnaces and Boilers". www.eere.energy.gov/buildings/appliance_standards/residential/furnaces_boilers.html)
    boilerParasiticElecDict = { Constants.FuelTypeGas => 76.0, # W during operation
                                Constants.FuelTypePropane => 76.0,
                                Constants.FuelTypeOil => 220.0,
                                Constants.FuelTypeElectric => 0.0 }
    boiler_aux = boilerParasiticElecDict[fuel_type]

    # _processCurvesBoiler

    boiler_eff_curve = get_boiler_curve(model, system_type == Constants.BoilerTypeCondensing)

    obj_name = Constants.ObjectNameBoiler(fuel_type, unit.name.to_s)

    # _processSystemHydronic

    plant_loop = OpenStudio::Model::PlantLoop.new(model)
    plant_loop.setName(obj_name + ' hydronic heat loop')
    plant_loop.setFluidType('Water')
    plant_loop.setMaximumLoopTemperature(100)
    plant_loop.setMinimumLoopTemperature(0)
    plant_loop.setMinimumLoopFlowRate(0)
    plant_loop.autocalculatePlantLoopVolume()
    runner.registerInfo("Added '#{plant_loop.name}' to model.")

    loop_sizing = plant_loop.sizingPlant
    loop_sizing.setLoopType('Heating')
    loop_sizing.setDesignLoopExitTemperature(UnitConversions.convert(design_temp - 32.0, 'R', 'K'))
    loop_sizing.setLoopDesignTemperatureDifference(UnitConversions.convert(20.0, 'R', 'K'))

    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setName(obj_name + ' hydronic pump')
    pump.setRatedPumpHead(20000)
    pump.setMotorEfficiency(dse * 0.9)
    pump.setFractionofMotorInefficienciestoFluidStream(0)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(1)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(0)
    pump.setPumpControlType('Intermittent')

    pump_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Pump Electricity Energy')
    pump_sensor.setName("#{pump.name.to_s.gsub('|', '_')} s")
    pump_sensor.setKeyName(pump.name.to_s)

    boiler = OpenStudio::Model::BoilerHotWater.new(model)
    boiler.setName(obj_name)
    boiler.setFuelType(HelperMethods.eplus_fuel_map(fuel_type))
    if capacity != Constants.SizingAuto
      boiler.setNominalCapacity(UnitConversions.convert(capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
    end
    if system_type == Constants.BoilerTypeCondensing
      # Convert Rated Efficiency at 80F and 1.0PLR where the performance curves are derived from to Design condition as input
      boiler_RatedHWRT = UnitConversions.convert(80.0 - 32.0, 'R', 'K')
      plr_Rated = 1.0
      plr_Design = 1.0
      boiler_DesignHWRT = UnitConversions.convert(design_temp - 20.0 - 32.0, 'R', 'K')
      # Efficiency curves are normalized using 80F return water temperature, at 0.254PLR
      condBlr_TE_Coeff = [1.058343061, 0.052650153, 0.0087272, 0.001742217, 0.00000333715, 0.000513723]
      boilerEff_Norm = afue / (condBlr_TE_Coeff[0] - condBlr_TE_Coeff[1] * plr_Rated - condBlr_TE_Coeff[2] * plr_Rated**2 - condBlr_TE_Coeff[3] * boiler_RatedHWRT + condBlr_TE_Coeff[4] * boiler_RatedHWRT**2 + condBlr_TE_Coeff[5] * boiler_RatedHWRT * plr_Rated)
      boilerEff_Design = boilerEff_Norm * (condBlr_TE_Coeff[0] - condBlr_TE_Coeff[1] * plr_Design - condBlr_TE_Coeff[2] * plr_Design**2 - condBlr_TE_Coeff[3] * boiler_DesignHWRT + condBlr_TE_Coeff[4] * boiler_DesignHWRT**2 + condBlr_TE_Coeff[5] * boiler_DesignHWRT * plr_Design)
      boiler.setNominalThermalEfficiency(dse * boilerEff_Design)
      boiler.setEfficiencyCurveTemperatureEvaluationVariable('EnteringBoiler')
    else
      boiler.setNominalThermalEfficiency(dse * afue)
      boiler.setEfficiencyCurveTemperatureEvaluationVariable('LeavingBoiler')
    end
    boiler.setNormalizedBoilerEfficiencyCurve(boiler_eff_curve)
    boiler.setWaterOutletUpperTemperatureLimit(UnitConversions.convert(design_temp - 32.0, 'R', 'K'))
    boiler.setMinimumPartLoadRatio(0.0)
    boiler.setMaximumPartLoadRatio(1.0)
    boiler.setBoilerFlowMode('LeavingSetpointModulated')
    boiler.setOptimumPartLoadRatio(1.0)
    boiler.setWaterOutletUpperTemperatureLimit(99.9)
    boiler.setParasiticElectricLoad(boiler_aux)

    if (system_type == Constants.BoilerTypeCondensing) && oat_reset_enabled
      setpoint_manager_oar = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
      setpoint_manager_oar.setName(obj_name + ' outdoor reset')
      setpoint_manager_oar.setControlVariable('Temperature')
      setpoint_manager_oar.setSetpointatOutdoorLowTemperature(UnitConversions.convert(oat_hwst_low, 'F', 'C'))
      setpoint_manager_oar.setOutdoorLowTemperature(UnitConversions.convert(oat_low, 'F', 'C'))
      setpoint_manager_oar.setSetpointatOutdoorHighTemperature(UnitConversions.convert(oat_hwst_high, 'F', 'C'))
      setpoint_manager_oar.setOutdoorHighTemperature(UnitConversions.convert(oat_high, 'F', 'C'))
      setpoint_manager_oar.addToNode(plant_loop.supplyOutletNode)
    end

    hydronic_heat_supply_setpoint = OpenStudio::Model::ScheduleConstant.new(model)
    hydronic_heat_supply_setpoint.setName(obj_name + ' hydronic heat supply setpoint')
    hydronic_heat_supply_setpoint.setValue(UnitConversions.convert(design_temp, 'F', 'C'))

    setpoint_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model, hydronic_heat_supply_setpoint)
    setpoint_manager_scheduled.setName(obj_name + ' hydronic heat loop setpoint manager')
    setpoint_manager_scheduled.setControlVariable('Temperature')

    pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)

    plant_loop.addSupplyBranchForComponent(boiler)
    plant_loop.addSupplyBranchForComponent(pipe_supply_bypass)
    pump.addToNode(plant_loop.supplyInletNode)
    pipe_supply_outlet.addToNode(plant_loop.supplyOutletNode)
    setpoint_manager_scheduled.addToNode(plant_loop.supplyOutletNode)
    plant_loop.addDemandBranchForComponent(pipe_demand_bypass)
    pipe_demand_inlet.addToNode(plant_loop.demandInletNode)
    pipe_demand_outlet.addToNode(plant_loop.demandOutletNode)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      ([control_zone] + slave_zones).each do |zone|
        baseboard_coil = OpenStudio::Model::CoilHeatingWaterBaseboard.new(model)
        baseboard_coil.setName(obj_name + " #{zone.name} heating coil")
        if capacity != Constants.SizingAuto
          baseboard_coil.setHeatingDesignCapacity(UnitConversions.convert(capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
        end
        baseboard_coil.setConvergenceTolerance(0.001)

        baseboard_heater = OpenStudio::Model::ZoneHVACBaseboardConvectiveWater.new(model, model.alwaysOnDiscreteSchedule, baseboard_coil)
        baseboard_heater.setName(obj_name + " #{zone.name} convective water")
        baseboard_heater.addToThermalZone(zone)
        baseboard_heater.additionalProperties.setFeature('CentralSystem', false)
        runner.registerInfo("Added '#{baseboard_heater.name}' to '#{zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, zone)

        plant_loop.addDemandBranchForComponent(baseboard_coil)

        # Store info for HVAC Sizing measure
        baseboard_heater.additionalProperties.setFeature(Constants.SizingInfoHVACFracHeatLoadServed, frac_heat_load_served)
      end
    end

    # Disaggregate electric pump energy
    pump_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    pump_program.setName("#{obj_name} pumps program")
    pump_program.addLine("Set #{unit.name.to_s.gsub(' ', '_')}_pumps_h = #{pump_sensor.name}")

    pump_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, "#{unit.name.to_s.gsub(' ', '_')}_pumps_h")
    pump_output_var.setName("#{obj_name} htg pump:Pumps:Electricity")
    pump_output_var.setTypeOfDataInVariable('Summed')
    pump_output_var.setUpdateFrequency('SystemTimestep')
    pump_output_var.setEMSProgramOrSubroutineName(pump_program)
    pump_output_var.setUnits('J')

    pump_program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    pump_program_calling_manager.setName("#{obj_name} pump program calling manager")
    pump_program_calling_manager.setCallingPoint('EndOfSystemTimestepBeforeHVACReporting')
    pump_program_calling_manager.addProgram(pump_program)

    return true
  end

  def self.apply_electric_baseboard(model, unit, runner, efficiency, capacity, frac_heat_load_served)
    return true if frac_heat_load_served <= 0

    obj_name = Constants.ObjectNameElectricBaseboard(unit.name.to_s)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      ([control_zone] + slave_zones).each do |zone|
        htg_coil = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        htg_coil.setName(obj_name + " #{zone.name} convective electric")
        if capacity != Constants.SizingAuto
          htg_coil.setNominalCapacity(UnitConversions.convert(capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
        end
        htg_coil.setEfficiency(efficiency)

        htg_coil.addToThermalZone(zone)
        runner.registerInfo("Added '#{htg_coil.name}' to '#{zone.name}' of #{unit.name}")

        prioritize_zone_hvac(model, runner, zone)

        # Store info for HVAC Sizing measure
        htg_coil.additionalProperties.setFeature(Constants.SizingInfoHVACFracHeatLoadServed, frac_heat_load_served)
      end
    end

    return true
  end

  def self.apply_unit_heater(model, unit, runner, fuel_type,
                             efficiency, capacity, fan_power,
                             airflow_rate, frac_heat_load_served)

    return true if frac_heat_load_served <= 0

    if (fan_power > 0) && (airflow_rate == 0)
      runner.registerError('If Fan Power > 0, then Airflow Rate cannot be zero.')
      return false
    end

    obj_name = Constants.ObjectNameUnitHeater(fuel_type, unit.name.to_s)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      ([control_zone] + slave_zones).each do |zone|
        # _processSystemHeatingCoil

        htg_coil = OpenStudio::Model::CoilHeatingGas.new(model)
        htg_coil.setName(obj_name + ' heating coil')
        htg_coil.setGasBurnerEfficiency(efficiency)
        if capacity != Constants.SizingAuto
          htg_coil.setNominalCapacity(UnitConversions.convert(capacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
        end
        htg_coil.setParasiticElectricLoad(0.0)
        htg_coil.setParasiticGasLoad(0)
        htg_coil.setFuelType(HelperMethods.eplus_fuel_map(fuel_type))

        fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
        fan.setName(obj_name + ' htg supply fan')
        fan.setEndUseSubcategory(obj_name + ' htg supply fan')
        if fan_power > 0
          fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
          fan.setFanEfficiency(fan_eff)
          fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_power))
        else
          fan.setFanEfficiency(1)
          fan.setPressureRise(0)
        end
        fan.setMotorEfficiency(1.0)
        fan.setMotorInAirstreamFraction(1.0)

        # _processSystemAir

        unitary_system = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
        unitary_system.setName(obj_name + ' unitary system')
        unitary_system.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
        unitary_system.setHeatingCoil(htg_coil)
        unitary_system.setSupplyAirFlowRateMethodDuringCoolingOperation('SupplyAirFlowRate')
        unitary_system.setSupplyAirFlowRateDuringCoolingOperation(0.0)
        unitary_system.setSupplyFan(fan)
        unitary_system.setFanPlacement('BlowThrough')
        unitary_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
        unitary_system.setMaximumSupplyAirTemperature(UnitConversions.convert(120.0, 'F', 'C'))
        unitary_system.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)

        runner.registerInfo("Added '#{fan.name}' to '#{unitary_system.name}''")
        runner.registerInfo("Added '#{htg_coil.name}' to '#{unitary_system.name}'")

        unitary_system.setControllingZoneorThermostatLocation(zone)
        unitary_system.addToThermalZone(zone)

        prioritize_zone_hvac(model, runner, zone)

        # Store info for HVAC Sizing measure
        unitary_system.additionalProperties.setFeature(Constants.SizingInfoHVACRatedCFMperTonHeating, airflow_rate.to_s)
        unitary_system.additionalProperties.setFeature(Constants.SizingInfoHVACFracHeatLoadServed, frac_heat_load_served)
      end
    end

    return true
  end

  def self.apply_central_system_boiler_baseboards(model, unit, runner, std,
                                                  hot_water_loop)

    zones = []
    unit.spaces.each do |space|
      zone = space.thermalZone.get
      next if zones.include? zone

      zones << zone
    end

    baseboards = std.model_add_baseboard(model, zones, hot_water_loop: hot_water_loop)
    baseboards.each do |baseboard|
      baseboard.additionalProperties.setFeature('CentralSystem', true)
      runner.registerInfo("Added '#{baseboard.name}' onto '#{hot_water_loop.name}' for '#{unit.name}'.")
    end

    return true
  end

  def self.apply_central_system_fan_coil(model, unit, runner, std,
                                         fan_coil_heating, hot_water_loop, chilled_water_loop)

    zones = []
    unit.spaces.each do |space|
      zone = space.thermalZone.get
      next if zones.include? zone

      zones << zone
    end

    fcus = std.model_add_four_pipe_fan_coil(model, zones, chilled_water_loop, hot_water_loop: hot_water_loop)
    fcus.each do |fcu|
      if hot_water_loop.nil?
        runner.registerInfo("Added '#{fcu.name}' onto '#{chilled_water_loop.name}' for '#{unit.name}'.'")
      else
        runner.registerInfo("Added '#{fcu.name}' onto '#{hot_water_loop.name}' and '#{chilled_water_loop.name}' for '#{unit.name}'.")
      end
    end

    return true
  end

  def self.apply_central_system_ptac(model, unit, runner, std,
                                     hot_water_loop)

    zones = []
    unit.spaces.each do |space|
      zone = space.thermalZone.get
      next if zones.include? zone

      zones << zone
    end

    ptacs = std.model_add_ptac(model, zones, heating_type: 'Water', hot_water_loop: hot_water_loop, cooling_type: 'Single Speed DX AC')
    ptacs.each do |ptac|
      runner.registerInfo("Added '#{ptac.name}' onto '#{hot_water_loop.name}' for '#{unit.name}'.")
    end
  end

  def self.apply_ideal_air_loads_cooling(model, unit, runner, frac_cool_load_served)
    return true if frac_cool_load_served <= 0

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      ([control_zone] + slave_zones).each do |zone|
        ideal_air = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
        ideal_air.setName('ideal cooling system')
        ideal_air.setMaximumHeatingSupplyAirTemperature(50)
        ideal_air.setMinimumCoolingSupplyAirTemperature(10)
        ideal_air.setMaximumHeatingSupplyAirHumidityRatio(0.015)
        ideal_air.setMinimumCoolingSupplyAirHumidityRatio(0.01)
        ideal_air.setHeatingLimit('LimitCapacity')
        ideal_air.setMaximumSensibleHeatingCapacity(0.0)
        ideal_air.setHeatingAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
        ideal_air.setCoolingLimit('NoLimit')
        ideal_air.setDehumidificationControlType('None')
        ideal_air.setHumidificationControlType('None')
        ideal_air.addToThermalZone(zone)

        # Store info for HVAC Sizing measure
        ideal_air.additionalProperties.setFeature(Constants.SizingInfoHVACFracHeatLoadServed, frac_cool_load_served)
      end
    end

    return true
  end

  def self.apply_ideal_air_loads_heating(model, unit, runner, frac_heat_load_served)
    return true if frac_heat_load_served <= 0

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      ([control_zone] + slave_zones).each do |zone|
        ideal_air = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
        ideal_air.setName('ideal heating system')
        ideal_air.setMaximumHeatingSupplyAirTemperature(50)
        ideal_air.setMinimumCoolingSupplyAirTemperature(10)
        ideal_air.setMaximumHeatingSupplyAirHumidityRatio(0.015)
        ideal_air.setMinimumCoolingSupplyAirHumidityRatio(0.01)
        ideal_air.setHeatingLimit('NoLimit')
        ideal_air.setCoolingLimit('LimitCapacity')
        ideal_air.setMaximumTotalCoolingCapacity(0.0)
        ideal_air.setCoolingAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
        ideal_air.setDehumidificationControlType('None')
        ideal_air.setHumidificationControlType('None')
        ideal_air.addToThermalZone(zone)

        # Store info for HVAC Sizing measure
        ideal_air.additionalProperties.setFeature(Constants.SizingInfoHVACFracHeatLoadServed, frac_heat_load_served)
      end
    end

    return true
  end

  def self.remove_heating(model, runner, thermal_zone, unit)
    removed_furnace = remove_furnace(model, runner, thermal_zone)
    removed_boiler = remove_boiler(model, runner, thermal_zone, unit)
    removed_heater = remove_unit_heater(model, runner, thermal_zone)
    removed_elec_baseboard = remove_electric_baseboard(model, runner, thermal_zone)
    removed_ashp = remove_ashp(model, runner, thermal_zone)
    removed_mshp = remove_mshp(model, runner, thermal_zone, unit)
    removed_gshp = remove_gshp(model, runner, thermal_zone, unit)
    removed_central_fan_coil = remove_central_system_fan_coil_heating(model, runner, thermal_zone)
    removed_central_ptac = remove_central_system_ptac(model, runner, thermal_zone)
  end

  def self.remove_cooling(model, runner, thermal_zone, unit)
    removed_ac = remove_central_ac(model, runner, thermal_zone)
    removed_room_ac = remove_room_ac(model, runner, thermal_zone)
    removed_ashp = remove_ashp(model, runner, thermal_zone)
    removed_mshp = remove_mshp(model, runner, thermal_zone, unit)
    if removed_mshp
      removed_elec_baseboard = remove_electric_baseboard(model, runner, thermal_zone)
    end
    removed_gshp = remove_gshp(model, runner, thermal_zone, unit)
    removed_central_fan_coil = remove_central_system_fan_coil(model, runner, thermal_zone)
    removed_central_ptac = remove_central_system_ptac(model, runner, thermal_zone)
  end

  def self.apply_heating_setpoints(model, runner, weather, htg_wkdy_monthly, htg_wked_monthly,
                                   use_auto_season, season_start_month, season_end_month)

    # Get heating season
    if use_auto_season
      heating_season, _ = calc_heating_and_cooling_seasons(model, weather, runner)
    else
      if season_start_month <= season_end_month
        heating_season = Array.new(season_start_month - 1, 0) + Array.new(season_end_month - season_start_month + 1, 1) + Array.new(12 - season_end_month, 0)
      elsif season_start_month > season_end_month
        heating_season = Array.new(season_end_month, 1) + Array.new(season_start_month - season_end_month - 1, 0) + Array.new(12 - season_start_month + 1, 1)
      end
    end
    if heating_season.nil?
      return false
    end

    cooling_season = get_season(model, weather, runner, Constants.ObjectNameCoolingSeason)

    # Remove existing heating season schedule
    model.getScheduleRulesets.each do |sch|
      next unless sch.name.to_s == Constants.ObjectNameHeatingSeason

      sch.remove
    end

    heating_season_sch = MonthWeekdayWeekendSchedule.new(model, runner, Constants.ObjectNameHeatingSeason, Array.new(24, 1), Array.new(24, 1), heating_season, mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = false, create_sch_object = true, winter_design_day_sch = nil, summer_design_day_sch = nil, schedule_type_limits_name = Constants.ScheduleTypeLimitsOnOff)
    unless heating_season_sch.validated?
      return false
    end

    htg_wkdy_monthly = htg_wkdy_monthly.map { |i| i.map { |j| UnitConversions.convert(j, 'F', 'C') } }
    htg_wked_monthly = htg_wked_monthly.map { |i| i.map { |j| UnitConversions.convert(j, 'F', 'C') } }

    finished_zones = []
    model.getThermalZones.each do |thermal_zone|
      if Geometry.zone_is_finished(thermal_zone)
        finished_zones << thermal_zone
      end
    end

    # Remove existing heating setpoint schedule
    model.getScheduleRulesets.each do |sch|
      next unless sch.name.to_s == Constants.ObjectNameHeatingSetpoint

      sch.remove
    end

    # Make the setpoint schedules
    clg_wkdy_monthly = nil
    clg_wked_monthly = nil
    finished_zones.each do |finished_zone|
      thermostat_setpoint = finished_zone.thermostatSetpointDualSetpoint
      if thermostat_setpoint.is_initialized

        thermostat_setpoint = thermostat_setpoint.get
        runner.registerInfo("Found existing thermostat #{thermostat_setpoint.name} for #{finished_zone.name}.")

        clg_wkdy_monthly = get_setpoint_schedule(thermostat_setpoint.coolingSetpointTemperatureSchedule.get.to_Schedule.get.to_ScheduleRuleset.get, 'weekday', runner)
        clg_wked_monthly = get_setpoint_schedule(thermostat_setpoint.coolingSetpointTemperatureSchedule.get.to_Schedule.get.to_ScheduleRuleset.get, 'weekend', runner)
        if clg_wkdy_monthly.nil? || clg_wked_monthly.nil?
          return false
        end

        model.getScheduleRulesets.each do |sch|
          next unless sch.name.to_s == Constants.ObjectNameCoolingSetpoint

          sch.remove
        end
      else # no thermostat in model yet

        clg_wkdy_monthly = [[UnitConversions.convert(Constants.DefaultCoolingSetpoint, 'F', 'C')] * 24] * 12
        clg_wked_monthly = [[UnitConversions.convert(Constants.DefaultCoolingSetpoint, 'F', 'C')] * 24] * 12

      end
      break # assume all finished zones have the same schedules
    end

    # Store the setpoints on thermostat_setpoint for DR measure
    finished_zones.each do |finished_zone|
      thermostat_setpoint = finished_zone.thermostatSetpointDualSetpoint
      next unless thermostat_setpoint.is_initialized

      thermostat_setpoint = thermostat_setpoint.get
      thermostat_setpoint.additionalProperties.setFeature('htg_wkdy', "#{htg_wkdy_monthly[0].join(',')}")
      thermostat_setpoint.additionalProperties.setFeature('htg_wked', "#{htg_wked_monthly[0].join(',')}")
      thermostat_setpoint.additionalProperties.setFeature('clg_wkdy', "#{clg_wkdy_monthly[0].join(',')}")
      thermostat_setpoint.additionalProperties.setFeature('clg_wked', "#{clg_wked_monthly[0].join(',')}")
    end

    (0..11).to_a.each do |i|
      if (heating_season[i] == 1) && (cooling_season[i] == 1) # overlap seasons
        htg_wkdy = htg_wkdy_monthly[i].zip(clg_wkdy_monthly[i]).map { |h, c| c < h ? (h + c) / 2.0 : h }
        htg_wked = htg_wked_monthly[i].zip(clg_wked_monthly[i]).map { |h, c| c < h ? (h + c) / 2.0 : h }
        clg_wkdy = htg_wkdy_monthly[i].zip(clg_wkdy_monthly[i]).map { |h, c| c < h ? (h + c) / 2.0 : c }
        clg_wked = htg_wked_monthly[i].zip(clg_wked_monthly[i]).map { |h, c| c < h ? (h + c) / 2.0 : c }
      elsif heating_season[i] == 1 # heating only seasons; cooling has minimum of heating
        htg_wkdy = htg_wkdy_monthly[i].zip(clg_wkdy_monthly[i]).map { |h, c| c < h ? h : h }
        htg_wked = htg_wked_monthly[i].zip(clg_wked_monthly[i]).map { |h, c| c < h ? h : h }
        clg_wkdy = htg_wkdy_monthly[i].zip(clg_wkdy_monthly[i]).map { |h, c| c < h ? h : c }
        clg_wked = htg_wked_monthly[i].zip(clg_wked_monthly[i]).map { |h, c| c < h ? h : c }
      elsif cooling_season[i] == 1 # cooling only seasons; heating has maximum of cooling
        htg_wkdy = htg_wkdy_monthly[i].zip(clg_wkdy_monthly[i]).map { |h, c| c < h ? c : h }
        htg_wked = htg_wked_monthly[i].zip(clg_wked_monthly[i]).map { |h, c| c < h ? c : h }
        clg_wkdy = htg_wkdy_monthly[i].zip(clg_wkdy_monthly[i]).map { |h, c| c < h ? c : c }
        clg_wked = htg_wked_monthly[i].zip(clg_wked_monthly[i]).map { |h, c| c < h ? c : c }
      else
        htg_wkdy = [UnitConversions.convert(Constants.DefaultHeatingSetpoint, 'F', 'C')] * 24
        htg_wked = [UnitConversions.convert(Constants.DefaultHeatingSetpoint, 'F', 'C')] * 24
        clg_wkdy = [UnitConversions.convert(Constants.DefaultCoolingSetpoint, 'F', 'C')] * 24
        clg_wked = [UnitConversions.convert(Constants.DefaultCoolingSetpoint, 'F', 'C')] * 24
      end
      htg_wkdy_monthly[i] = htg_wkdy
      htg_wked_monthly[i] = htg_wked
      clg_wkdy_monthly[i] = clg_wkdy
      clg_wked_monthly[i] = clg_wked
    end

    # Design day schedules used when autosizing
    winter_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    winter_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), UnitConversions.convert(70, 'F', 'C'))
    summer_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    summer_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), UnitConversions.convert(75, 'F', 'C'))

    heating_setpoint = HourlyByMonthSchedule.new(model, runner, Constants.ObjectNameHeatingSetpoint, htg_wkdy_monthly, htg_wked_monthly, normalize_values = false, create_sch_object = true, winter_design_day_sch = winter_design_day_sch, summer_design_day_sch = summer_design_day_sch)
    cooling_setpoint = HourlyByMonthSchedule.new(model, runner, Constants.ObjectNameCoolingSetpoint, clg_wkdy_monthly, clg_wked_monthly, normalize_values = false, create_sch_object = true, winter_design_day_sch = winter_design_day_sch, summer_design_day_sch = summer_design_day_sch)

    unless heating_setpoint.validated? && cooling_setpoint.validated?
      return false
    end

    # Set the setpoint schedules
    finished_zones.each do |finished_zone|
      thermostat_setpoint = finished_zone.thermostatSetpointDualSetpoint
      if thermostat_setpoint.is_initialized

        thermostat_setpoint = thermostat_setpoint.get
        thermostat_setpoint.setHeatingSetpointTemperatureSchedule(heating_setpoint.schedule)
        thermostat_setpoint.setCoolingSetpointTemperatureSchedule(cooling_setpoint.schedule)

      else

        thermostat_setpoint = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
        thermostat_setpoint.setName("#{finished_zone.name} temperature setpoint")
        runner.registerInfo("Created new thermostat #{thermostat_setpoint.name} for #{finished_zone.name}.")
        thermostat_setpoint.setHeatingSetpointTemperatureSchedule(heating_setpoint.schedule)
        thermostat_setpoint.setCoolingSetpointTemperatureSchedule(cooling_setpoint.schedule)
        finished_zone.setThermostatSetpointDualSetpoint(thermostat_setpoint)
        runner.registerInfo("Set a dummy cooling setpoint schedule for #{thermostat_setpoint.name}.")

      end

      runner.registerInfo("Set the heating setpoint schedule for #{thermostat_setpoint.name}.")
    end

    model.getScheduleDays.each do |obj| # remove orphaned summer and winter design day schedules
      next if obj.directUseCount > 0

      obj.remove
    end

    return true
  end

  def self.apply_cooling_setpoints(model, runner, weather, clg_wkdy_monthly, clg_wked_monthly,
                                   use_auto_season, season_start_month, season_end_month)

    # Get cooling season
    if use_auto_season
      _, cooling_season = calc_heating_and_cooling_seasons(model, weather, runner)
    else
      if season_start_month <= season_end_month
        cooling_season = Array.new(season_start_month - 1, 0) + Array.new(season_end_month - season_start_month + 1, 1) + Array.new(12 - season_end_month, 0)
      elsif season_start_month > season_end_month
        cooling_season = Array.new(season_end_month, 1) + Array.new(season_start_month - season_end_month - 1, 0) + Array.new(12 - season_start_month + 1, 1)
      end
    end
    if cooling_season.nil?
      return false
    end

    heating_season = get_season(model, weather, runner, Constants.ObjectNameHeatingSeason)

    # Remove existing cooling season schedule
    model.getScheduleRulesets.each do |sch|
      next unless sch.name.to_s == Constants.ObjectNameCoolingSeason

      sch.remove
    end

    cooling_season_sch = MonthWeekdayWeekendSchedule.new(model, runner, Constants.ObjectNameCoolingSeason, Array.new(24, 1), Array.new(24, 1), cooling_season, mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = false, create_sch_object = true, winter_design_day_sch = nil, summer_design_day_sch = nil, schedule_type_limits_name = Constants.ScheduleTypeLimitsOnOff)
    unless cooling_season_sch.validated?
      return false
    end

    clg_wkdy_monthly = clg_wkdy_monthly.map { |i| i.map { |j| UnitConversions.convert(j, 'F', 'C') } }
    clg_wked_monthly = clg_wked_monthly.map { |i| i.map { |j| UnitConversions.convert(j, 'F', 'C') } }

    finished_zones = []
    model.getThermalZones.each do |thermal_zone|
      if Geometry.zone_is_finished(thermal_zone)
        finished_zones << thermal_zone
      end
    end

    # Remove existing cooling setpoint schedule
    model.getScheduleRulesets.each do |sch|
      next unless sch.name.to_s == Constants.ObjectNameCoolingSetpoint

      sch.remove
    end

    # Make the setpoint schedules
    htg_wkdy_monthly = nil
    htg_wked_monthly = nil
    finished_zones.each do |finished_zone|
      thermostat_setpoint = finished_zone.thermostatSetpointDualSetpoint
      if thermostat_setpoint.is_initialized

        thermostat_setpoint = thermostat_setpoint.get
        runner.registerInfo("Found existing thermostat #{thermostat_setpoint.name} for #{finished_zone.name}.")

        htg_wkdy_monthly = get_setpoint_schedule(thermostat_setpoint.heatingSetpointTemperatureSchedule.get.to_Schedule.get.to_ScheduleRuleset.get, 'weekday', runner)
        htg_wked_monthly = get_setpoint_schedule(thermostat_setpoint.heatingSetpointTemperatureSchedule.get.to_Schedule.get.to_ScheduleRuleset.get, 'weekend', runner)
        if htg_wkdy_monthly.nil? || htg_wked_monthly.nil?
          return false
        end

        model.getScheduleRulesets.each do |sch|
          next unless sch.name.to_s == Constants.ObjectNameHeatingSetpoint

          sch.remove
        end
      else # no thermostat in model yet

        htg_wkdy_monthly = [[UnitConversions.convert(Constants.DefaultHeatingSetpoint, 'F', 'C')] * 24] * 12
        htg_wked_monthly = [[UnitConversions.convert(Constants.DefaultHeatingSetpoint, 'F', 'C')] * 24] * 12

      end
      break # assume all finished zones have the same schedules
    end

    # Store the setpoints on thermostat_setpoint for DR measure
    finished_zones.each do |finished_zone|
      thermostat_setpoint = finished_zone.thermostatSetpointDualSetpoint
      next unless thermostat_setpoint.is_initialized

      thermostat_setpoint = thermostat_setpoint.get
      thermostat_setpoint.additionalProperties.setFeature('htg_wkdy', "#{htg_wkdy_monthly[0].join(',')}")
      thermostat_setpoint.additionalProperties.setFeature('htg_wked', "#{htg_wked_monthly[0].join(',')}")
      thermostat_setpoint.additionalProperties.setFeature('clg_wkdy', "#{clg_wkdy_monthly[0].join(',')}")
      thermostat_setpoint.additionalProperties.setFeature('clg_wked', "#{clg_wked_monthly[0].join(',')}")
    end

    (0..11).to_a.each do |i|
      if (heating_season[i] == 1) && (cooling_season[i] == 1) # overlap seasons
        htg_wkdy = htg_wkdy_monthly[i].zip(clg_wkdy_monthly[i]).map { |h, c| c < h ? (h + c) / 2.0 : h }
        htg_wked = htg_wked_monthly[i].zip(clg_wked_monthly[i]).map { |h, c| c < h ? (h + c) / 2.0 : h }
        clg_wkdy = htg_wkdy_monthly[i].zip(clg_wkdy_monthly[i]).map { |h, c| c < h ? (h + c) / 2.0 : c }
        clg_wked = htg_wked_monthly[i].zip(clg_wked_monthly[i]).map { |h, c| c < h ? (h + c) / 2.0 : c }
      elsif heating_season[i] == 1 # heating only seasons; cooling has minimum of heating
        htg_wkdy = htg_wkdy_monthly[i].zip(clg_wkdy_monthly[i]).map { |h, c| c < h ? h : h }
        htg_wked = htg_wked_monthly[i].zip(clg_wked_monthly[i]).map { |h, c| c < h ? h : h }
        clg_wkdy = htg_wkdy_monthly[i].zip(clg_wkdy_monthly[i]).map { |h, c| c < h ? h : c }
        clg_wked = htg_wked_monthly[i].zip(clg_wked_monthly[i]).map { |h, c| c < h ? h : c }
      elsif cooling_season[i] == 1 # cooling only seasons; heating has maximum of cooling
        htg_wkdy = htg_wkdy_monthly[i].zip(clg_wkdy_monthly[i]).map { |h, c| c < h ? c : h }
        htg_wked = htg_wked_monthly[i].zip(clg_wked_monthly[i]).map { |h, c| c < h ? c : h }
        clg_wkdy = htg_wkdy_monthly[i].zip(clg_wkdy_monthly[i]).map { |h, c| c < h ? c : c }
        clg_wked = htg_wked_monthly[i].zip(clg_wked_monthly[i]).map { |h, c| c < h ? c : c }
      else
        htg_wkdy = [UnitConversions.convert(Constants.DefaultHeatingSetpoint, 'F', 'C')] * 24
        htg_wked = [UnitConversions.convert(Constants.DefaultHeatingSetpoint, 'F', 'C')] * 24
        clg_wkdy = [UnitConversions.convert(Constants.DefaultCoolingSetpoint, 'F', 'C')] * 24
        clg_wked = [UnitConversions.convert(Constants.DefaultCoolingSetpoint, 'F', 'C')] * 24
      end
      htg_wkdy_monthly[i] = htg_wkdy
      htg_wked_monthly[i] = htg_wked
      clg_wkdy_monthly[i] = clg_wkdy
      clg_wked_monthly[i] = clg_wked
    end

    # Design day schedules used when autosizing
    winter_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    winter_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), UnitConversions.convert(70, 'F', 'C'))
    summer_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    summer_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), UnitConversions.convert(75, 'F', 'C'))

    heating_setpoint = HourlyByMonthSchedule.new(model, runner, Constants.ObjectNameHeatingSetpoint, htg_wkdy_monthly, htg_wked_monthly, normalize_values = false, create_sch_object = true, winter_design_day_sch = winter_design_day_sch, summer_design_day_sch = summer_design_day_sch)
    cooling_setpoint = HourlyByMonthSchedule.new(model, runner, Constants.ObjectNameCoolingSetpoint, clg_wkdy_monthly, clg_wked_monthly, normalize_values = false, create_sch_object = true, winter_design_day_sch = winter_design_day_sch, summer_design_day_sch = summer_design_day_sch)

    unless heating_setpoint.validated? && cooling_setpoint.validated?
      return false
    end

    # Set the setpoint schedules
    finished_zones.each do |finished_zone|
      thermostat_setpoint = finished_zone.thermostatSetpointDualSetpoint
      if thermostat_setpoint.is_initialized
        thermostat_setpoint = thermostat_setpoint.get
        thermostat_setpoint.setHeatingSetpointTemperatureSchedule(heating_setpoint.schedule)
        thermostat_setpoint.setCoolingSetpointTemperatureSchedule(cooling_setpoint.schedule)
      else
        thermostat_setpoint = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
        thermostat_setpoint.setName("#{finished_zone.name} temperature setpoint")
        runner.registerInfo("Created new thermostat #{thermostat_setpoint.name} for #{finished_zone.name}.")
        thermostat_setpoint.setHeatingSetpointTemperatureSchedule(heating_setpoint.schedule)
        thermostat_setpoint.setCoolingSetpointTemperatureSchedule(cooling_setpoint.schedule)
        finished_zone.setThermostatSetpointDualSetpoint(thermostat_setpoint)
        runner.registerInfo("Set a dummy heating setpoint schedule for #{thermostat_setpoint.name}.")
      end

      runner.registerInfo("Set the cooling setpoint schedule for #{thermostat_setpoint.name}.")
    end

    model.getScheduleDays.each do |obj| # remove orphaned summer and winter design day schedules
      next if obj.directUseCount > 0

      obj.remove
    end

    return true
  end

  def self.get_setpoint_schedule(schedule_ruleset, weekday_or_weekend, runner)
    setpoint_schedule = [[0] * 24] * 12
    schedule_ruleset.scheduleRules.each do |rule|
      month = rule.startDate.get.monthOfYear.value.to_i - 1
      next unless weekday_or_weekend_rule(rule).include? weekday_or_weekend

      rule.daySchedule.values.each_with_index do |value, i|
        hour = rule.daySchedule.times[i].hours - 1
        setpoint_schedule[month][hour] = value
      end
      setpoint_schedule[month] = backfill_schedule_values(setpoint_schedule[month])
    end
    if setpoint_schedule.any? { |m| m.any? { |h| h == 0 } }
      runner.registerError('Failed to get the setpoint schedule.')
      return
    end
    return setpoint_schedule
  end

  def self.weekday_or_weekend_rule(rule)
    if rule.applyMonday && rule.applyTuesday && rule.applyWednesday && rule.applyThursday && rule.applyFriday && rule.applySaturday && rule.applySunday
      return 'weekday/weekend'
    elsif rule.applyMonday && rule.applyTuesday && rule.applyWednesday && rule.applyThursday && rule.applyFriday
      return 'weekday'
    elsif rule.applySaturday && rule.applySunday
      return 'weekend'
    end

    return
  end

  def self.backfill_schedule_values(values)
    # backfill the array values
    values = values.reverse
    previous_value = values[0]
    values.each_with_index do |c, i|
      if values[i + 1] == 0
        values[i + 1] = previous_value
      end
      previous_value = values[i + 1]
    end
    values = values.reverse
    return values
  end

  def self.get_season(model, weather, runner, sch_name)
    season = []
    model.getScheduleRulesets.each do |sch|
      next unless sch.name.to_s == sch_name

      sch.scheduleRules.each do |rule|
        ix = rule.startDate.get.monthOfYear.value.to_i - 1
        season[ix] = rule.daySchedule.values[0]
      end
    end
    if season.empty?
      heating_season, cooling_season = calc_heating_and_cooling_seasons(model, weather, runner)
      if sch_name == Constants.ObjectNameHeatingSeason
        season = heating_season
      else
        season = cooling_season
      end
    end
    return season
  end

  def self.get_default_heating_setpoint(control_type)
    htg_sp = 68 # F
    htg_setback_sp = nil
    htg_setback_hrs_per_week = nil
    htg_setback_start_hr = nil
    if control_type == 'programmable thermostat'
      htg_setback_sp = 66 # F
      htg_setback_hrs_per_week = 7 * 7 # 11 p.m. to 5:59 a.m., 7 days a week
      htg_setback_start_hr = 23 # 11 p.m.
    elsif control_type != 'manual thermostat'
      fail "Unexpected control type #{control_type}."
    end
    return htg_sp, htg_setback_sp, htg_setback_hrs_per_week, htg_setback_start_hr
  end

  def self.get_default_cooling_setpoint(control_type)
    clg_sp = 78 # F
    clg_setup_sp = nil
    clg_setup_hrs_per_week = nil
    clg_setup_start_hr = nil
    if control_type == 'programmable thermostat'
      clg_setup_sp = 80 # F
      clg_setup_hrs_per_week = 6 * 7 # 9 a.m. to 2:59 p.m., 7 days a week
      clg_setup_start_hr = 9 # 9 a.m.
    elsif control_type != 'manual thermostat'
      fail "Unexpected control type #{control_type}."
    end
    return clg_sp, clg_setup_sp, clg_setup_hrs_per_week, clg_setup_start_hr
  end

  def self.apply_dehumidifier(model, unit, runner, energy_factor,
                              water_removal_rate, air_flow_rate, humidity_setpoint)

    # error checking
    if (humidity_setpoint < 0) || (humidity_setpoint > 1)
      runner.registerError('Invalid humidity setpoint value entered.')
      return false
    end
    if (water_removal_rate != Constants.Auto) && (water_removal_rate.to_f <= 0)
      runner.registerError('Invalid water removal rate value entered.')
      return false
    end
    if (energy_factor != Constants.Auto) && (energy_factor.to_f < 0)
      runner.registerError('Invalid energy factor value entered.')
      return false
    end
    if (air_flow_rate != Constants.Auto) && (air_flow_rate.to_f < 0)
      runner.registerError('Invalid air flow rate value entered.')
      return false
    end

    obj_name = Constants.ObjectNameDehumidifier(unit.name.to_s)

    avg_rh_setpoint = humidity_setpoint * 100.0 # (EnergyPlus uses 60 for 60% RH)
    relative_humidity_setpoint_sch = OpenStudio::Model::ScheduleConstant.new(model)
    relative_humidity_setpoint_sch.setName(Constants.ObjectNameRelativeHumiditySetpoint(unit.name.to_s))
    relative_humidity_setpoint_sch.setValue(avg_rh_setpoint)

    # Dehumidifier coefficients
    # Generic model coefficients from Winkler, Christensen, and Tomerlin (2011)
    water_removal_curve = create_curve_biquadratic(model, [-1.162525707, 0.02271469, -0.000113208, 0.021110538, -0.0000693034, 0.000378843], 'DXDH-WaterRemove-Cap-fT', -100, 100, -100, 100)
    energy_factor_curve = create_curve_biquadratic(model, [-1.902154518, 0.063466565, -0.000622839, 0.039540407, -0.000125637, -0.000176722], 'DXDH-EnergyFactor-fT', -100, 100, -100, 100)
    part_load_frac_curve = create_curve_quadratic(model, [0.90, 0.10, 0.0], 'DXDH-PLF-fPLR', 0, 1, 0.7, 1)

    thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

    control_slave_zones_hash = get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash.each do |control_zone, slave_zones|
      humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
      humidistat.setName(obj_name + " #{control_zone.name} humidistat")
      humidistat.setHumidifyingRelativeHumiditySetpointSchedule(relative_humidity_setpoint_sch)
      humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(relative_humidity_setpoint_sch)
      control_zone.setZoneControlHumidistat(humidistat)

      zone_hvac = OpenStudio::Model::ZoneHVACDehumidifierDX.new(model, water_removal_curve, energy_factor_curve, part_load_frac_curve)
      zone_hvac.setName(obj_name + " #{control_zone.name} dx")
      zone_hvac.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      if water_removal_rate != Constants.Auto
        zone_hvac.setRatedWaterRemoval(UnitConversions.convert(water_removal_rate.to_f, 'pint', 'L'))
      else
        zone_hvac.setRatedWaterRemoval(Constants.small) # Autosize flag for HVACSizing measure
      end
      if energy_factor != Constants.Auto
        zone_hvac.setRatedEnergyFactor(energy_factor.to_f)
      else
        zone_hvac.setRatedEnergyFactor(Constants.small) # Autosize flag for HVACSizing measure
      end
      if air_flow_rate != Constants.Auto
        zone_hvac.setRatedAirFlowRate(UnitConversions.convert(air_flow_rate.to_f, 'cfm', 'm^3/s'))
      else
        zone_hvac.setRatedAirFlowRate(Constants.small) # Autosize flag for HVACSizing measure
      end
      zone_hvac.setMinimumDryBulbTemperatureforDehumidifierOperation(10)
      zone_hvac.setMaximumDryBulbTemperatureforDehumidifierOperation(40)

      zone_hvac.addToThermalZone(control_zone)
      runner.registerInfo("Added '#{zone_hvac.name}' to '#{control_zone.name}' of #{unit.name}")

      prioritize_zone_hvac(model, runner, control_zone)
    end

    return true
  end

  def self.remove_dehumidifier(runner, model, zone, unit)
    # FIXME: Needs to be zone specific...
    model.getScheduleConstants.each do |sch|
      next unless sch.name.to_s == Constants.ObjectNameRelativeHumiditySetpoint(unit.name.to_s)

      sch.remove
    end

    model.getZoneHVACDehumidifierDXs.each do |dehumidifier|
      next unless zone.handle.to_s == dehumidifier.thermalZone.get.handle.to_s

      runner.registerInfo("Removed '#{dehumidifier.name}' from #{zone.name}.")
      dehumidifier.remove

      humidistat = zone.zoneControlHumidistat
      if humidistat.is_initialized
        humidistat.get.remove
      end
    end
  end

  def self.apply_ceiling_fans(model, unit, runner, coverage, specified_num, power,
                              control, use_benchmark_energy, cooling_setpoint_offset,
                              mult, sch, schedules_file)

    # check for valid inputs
    if mult < 0
      runner.registerError('Multiplier must be greater than or equal to 0.')
      return false
    end

    obj_name = Constants.ObjectNameCeilingFan(unit.name.to_s)

    num_bedrooms, num_bathrooms = Geometry.get_unit_beds_baths(model, unit, runner)
    if num_bedrooms.nil? || num_bathrooms.nil?
      return false
    end

    above_grade_finished_floor_area = Geometry.get_above_grade_finished_floor_area_from_spaces(unit.spaces, runner)
    finished_floor_area = Geometry.get_finished_floor_area_from_spaces(unit.spaces, runner)

    # Determine geometry for spaces and zones that are unit specific
    living_zone = nil
    finished_basement_zone = nil
    Geometry.get_thermal_zones_from_spaces(unit.spaces).each do |thermal_zone|
      if Geometry.is_living(thermal_zone)
        living_zone = thermal_zone
      elsif Geometry.is_finished_basement(thermal_zone)
        finished_basement_zone = thermal_zone
      end
    end

    # Determine the number of ceiling fans
    ceiling_fan_num = 0
    if not coverage.nil?
      # User has chosen to specify the number of fans by indicating
      # % coverage, where it is assumed that 100% coverage requires 1 fan
      # per 300 square feet.
      ceiling_fan_num = (above_grade_finished_floor_area * coverage / 300.0).round(1)
    elsif not specified_num.nil?
      ceiling_fan_num = specified_num
    else
      ceiling_fan_num = 0
    end

    # Adjust the power consumption based on the occupancy control.
    # The default assumption is that when the fans are "on" half of the
    # fans will be used. This is consistent with the results from an FSEC
    # survey (described in FSEC-PF-306-96) and approximates the reasonable
    # assumption that during the night the bedroom fans will be on and all
    # of the other fans will be off while during the day the reverse will
    # be true. "Smart" occupancy control indicates that fans are used more
    # sparingly; in other words, fans are frequently turned off when rooms
    # are vacant. To approximate this kind of control, the overall fan
    # power consumption is reduced by 50%.Note that although the idea here
    # is that in reality "smart" control means that fans will be run for
    # fewer hours, it is modeled as a reduction in power consumption.

    if control == Constants.CeilingFanControlSmart
      ceiling_fan_control_factor = 0.25
    else
      ceiling_fan_control_factor = 0.5
    end

    # Determine the power draw for the ceiling fans.
    # The power consumption depends on the number of fans, the "standard"
    # power consumption per fan, the fan efficiency, and the fan occupancy
    # control. Rather than specifying usage via a schedule, as for most
    # other electrical uses, the fans will be modeled as "on" with a
    # constant power consumption whenever the interior space temperature
    # exceeds the cooling setpoint and "off" at all other times (this
    # on/off behavior is accomplished in DOE2.bmi using EQUIP-PWR-FT - see
    # comments there). Note that there is also a fan schedule that accounts
    # for cooling setpoint setups (it is assumed that fans will always be
    # off during the setup period).

    if ceiling_fan_num > 0
      ceiling_fans_max_power = ceiling_fan_num * power * ceiling_fan_control_factor / UnitConversions.convert(1.0, 'kW', 'W') # kW
    else
      ceiling_fans_max_power = 0
    end

    # Determine ceiling fan schedule.
    # In addition to turning the fans off when the interior space
    # temperature falls below the cooling setpoint (handled in DOE2.bmi by
    # EQUIP-PWR-FT), the fans should be turned off during any setup of the
    # cooling setpoint (based on the assumption that the occupants leave
    # the house at those times). Therefore the fan schedule specifies zero
    # power during the setup period and full power outside of the setup
    # period. Determine the lowest value of all of the hourly cooling setpoints.

    clg_wkdy_monthly = nil
    clg_wked_monthly = nil
    thermostatsetpointdualsetpoint = living_zone.thermostatSetpointDualSetpoint
    if thermostatsetpointdualsetpoint.is_initialized

      htg_wkdy_monthly = get_setpoint_schedule(thermostatsetpointdualsetpoint.get.heatingSetpointTemperatureSchedule.get.to_Schedule.get.to_ScheduleRuleset.get, 'weekday', runner)
      htg_wked_monthly = get_setpoint_schedule(thermostatsetpointdualsetpoint.get.heatingSetpointTemperatureSchedule.get.to_Schedule.get.to_ScheduleRuleset.get, 'weekend', runner)
      clg_wkdy_monthly = get_setpoint_schedule(thermostatsetpointdualsetpoint.get.coolingSetpointTemperatureSchedule.get.to_Schedule.get.to_ScheduleRuleset.get, 'weekday', runner)
      clg_wked_monthly = get_setpoint_schedule(thermostatsetpointdualsetpoint.get.coolingSetpointTemperatureSchedule.get.to_Schedule.get.to_ScheduleRuleset.get, 'weekend', runner)

      thermostatsetpointdualsetpoint.get.coolingSetpointTemperatureSchedule.get.to_Schedule.get.to_ScheduleRuleset.get.scheduleRules.each do |rule|
        month = rule.startDate.get.monthOfYear.value.to_i - 1
        next if htg_wkdy_monthly[month].zip(clg_wkdy_monthly[month]).any? { |h, c| c < h }
        next if htg_wked_monthly[month].zip(clg_wked_monthly[month]).any? { |h, c| c < h }

        rule.daySchedule.clearValues
        if weekday_or_weekend_rule(rule).include? 'weekday'
          clg_wkdy_monthly[month].each_with_index do |value, hour|
            new_value = UnitConversions.convert(UnitConversions.convert(value, 'C', 'F') + cooling_setpoint_offset, 'F', 'C')
            rule.daySchedule.addValue(OpenStudio::Time.new(0, hour + 1, 0, 0), new_value)
            clg_wkdy_monthly[month][hour] = UnitConversions.convert(new_value, 'C', 'F')
          end
        end
        next unless weekday_or_weekend_rule(rule).include? 'weekend'

        clg_wked_monthly[month].each_with_index do |value, hour|
          new_value = UnitConversions.convert(UnitConversions.convert(value, 'C', 'F') + cooling_setpoint_offset, 'F', 'C')
          rule.daySchedule.addValue(OpenStudio::Time.new(0, hour + 1, 0, 0), UnitConversions.convert(UnitConversions.convert(value, 'C', 'F') + cooling_setpoint_offset, 'F', 'C'))
          clg_wked_monthly[month][hour] = UnitConversions.convert(new_value, 'C', 'F')
        end
      end
    end

    if clg_wkdy_monthly.nil? && clg_wked_monthly.nil?
      runner.registerWarning("No cooling setpoint schedule found. Assuming #{Constants.DefaultCoolingSetpoint} F for ceiling fan operation.")
      clg_wkdy_monthly = [[Constants.DefaultCoolingSetpoint] * 24] * 12
      clg_wked_monthly = [[Constants.DefaultCoolingSetpoint] * 24] * 12
    end

    cooling_setpoint_min = [clg_wkdy_monthly.min, clg_wked_monthly.min].min.min

    ceiling_fans_hourly_weekday = []
    ceiling_fans_hourly_weekend = []

    (0..23).to_a.each do |hour|
      if clg_wkdy_monthly[6][hour] > cooling_setpoint_min # july
        ceiling_fans_hourly_weekday << 0
      else
        ceiling_fans_hourly_weekday << 1
      end
      if clg_wked_monthly[6][hour] > cooling_setpoint_min # july
        ceiling_fans_hourly_weekend << 0
      else
        ceiling_fans_hourly_weekend << 1
      end
    end

    ceiling_fan_sch = MonthWeekdayWeekendSchedule.new(model, runner, obj_name + ' schedule', ceiling_fans_hourly_weekday, ceiling_fans_hourly_weekend, Array.new(12, 1), mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = false, create_sch_object = true, winter_design_day_sch = nil, summer_design_day_sch = nil, schedule_type_limits_name = Constants.ScheduleTypeLimitsFraction)

    unless ceiling_fan_sch.validated?
      return false
    end

    schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
    schedule_type_limits.setName('OnOff')
    schedule_type_limits.setLowerLimitValue(0)
    schedule_type_limits.setUpperLimitValue(1)
    schedule_type_limits.setNumericType('Discrete')

    ceiling_fan_master_sch = OpenStudio::Model::ScheduleConstant.new(model)
    ceiling_fan_master_sch.setName(obj_name + ' master')
    ceiling_fan_master_sch.setScheduleTypeLimits(schedule_type_limits)
    ceiling_fan_master_sch.setValue(1)

    # Ceiling Fans
    # As described in more detail in the schedules section, ceiling fans are controlled by two schedules, CeilingFan and CeilingFansMaster.
    # The program CeilingFanScheduleProgram checks to see if a cooling setpoint setup is in effect (by checking the sensor CeilingFan_sch) and
    # it checks the indoor temperature to see if it is less than the normal cooling setpoint. In either case, it turns the fans off.
    # Otherwise it turns the fans on.

    equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    equip_def.setName(obj_name + ' non benchmark equip')
    equip = OpenStudio::Model::ElectricEquipment.new(equip_def)
    equip.setName(equip_def.name.to_s)
    equip.setEndUseSubcategory(obj_name)
    equip.setSpace(living_zone.spaces[0])
    equip_def.setDesignLevel(UnitConversions.convert(ceiling_fans_max_power, 'kW', 'W'))
    equip_def.setFractionRadiant(0.558)
    equip_def.setFractionLatent(0)
    equip_def.setFractionLost(0.07)
    equip.setSchedule(ceiling_fan_master_sch)

    # Sensor that reports the value of the schedule CeilingFan (0 if cooling setpoint setup is in effect, 1 otherwise).
    sched_val_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
    sched_val_sensor.setName("#{obj_name} sched val sensor".gsub('|', '_'))
    sched_val_sensor.setKeyName(obj_name + ' schedule')

    tin_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Mean Air Temperature')
    tin_sensor.setName("#{obj_name} tin sensor".gsub('|', '_'))
    tin_sensor.setKeyName(living_zone.name.to_s)

    # Actuator that overrides the master ceiling fan schedule.
    sched_override_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(ceiling_fan_master_sch, 'Schedule:Constant', 'Schedule Value')
    sched_override_actuator.setName("#{obj_name} sched override".gsub('|', '_'))

    # Program that turns the ceiling fans off in the situations described above.
    program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    program.setName(obj_name + ' schedule program')
    program.addLine("If #{sched_val_sensor.name} == 0")
    program.addLine("Set #{sched_override_actuator.name} = 0")
    # Subtract 0.1 from cooling setpoint to avoid fans cycling on and off with minor temperature variations.
    program.addLine("ElseIf #{tin_sensor.name} < #{UnitConversions.convert(cooling_setpoint_min - 0.1 - 32.0, 'R', 'K').round(3)}")
    program.addLine("Set #{sched_override_actuator.name} = 0")
    program.addLine('Else')
    program.addLine("Set #{sched_override_actuator.name} = 1")
    program.addLine('EndIf')

    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName(obj_name + ' program calling manager')
    program_calling_manager.setCallingPoint('BeginTimestepBeforePredictor')
    program_calling_manager.addProgram(program)

    mel_ann_no_ceiling_fan = (1108.1 + 180.2 * num_bedrooms + 0.2785 * finished_floor_area) * mult
    mel_ann_with_ceiling_fan = (1185.4 + 180.2 * num_bedrooms + 0.3188 * finished_floor_area) * mult
    mel_ann = mel_ann_with_ceiling_fan - mel_ann_no_ceiling_fan

    unit.spaces.each do |space|
      next if Geometry.space_is_unfinished(space)

      space_obj_name = "#{obj_name} benchmark|#{space.name}"

      next unless (mel_ann > 0) && use_benchmark_energy

      col_name = 'ceiling_fan'
      if sch.nil?
        sch = schedules_file.create_schedule_file(col_name: col_name)
      end

      space_mel_ann = mel_ann * UnitConversions.convert(space.floorArea, 'm^2', 'ft^2') / finished_floor_area
      space_design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: space_mel_ann)

      mel_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      mel = OpenStudio::Model::ElectricEquipment.new(mel_def)
      mel.setName(space_obj_name)
      mel.setEndUseSubcategory(obj_name)
      mel.setSpace(space)
      mel_def.setName(space_obj_name)
      mel_def.setDesignLevel(space_design_level)
      mel_def.setFractionRadiant(0.558)
      mel_def.setFractionLatent(0.0)
      mel_def.setFractionLost(0.07)
      mel.setSchedule(sch)

      # benchmark
    end # unit spaces

    return true, sch
  end

  def self.get_default_ceiling_fan_power()
    return 42.6 # W
  end

  def self.get_default_ceiling_fan_quantity(nbeds)
    return nbeds + 1
  end

  def self.remove_ceiling_fans(runner, model, unit)
    obj_name = Constants.ObjectNameCeilingFan(unit.name.to_s)

    # Remove existing ceiling fan
    model.getScheduleRulesets.each do |schedule|
      next unless schedule.name.to_s == obj_name + ' schedule'

      schedule.remove
    end
    model.getEnergyManagementSystemSensors.each do |sensor|
      next unless (sensor.name.to_s == "#{obj_name} sched val sensor".gsub(' ', '_').gsub('|', '_')) || (sensor.name.to_s == "#{obj_name} tin sensor".gsub(' ', '_').gsub('|', '_'))

      sensor.remove
    end
    model.getEnergyManagementSystemActuators.each do |actuator|
      next unless actuator.name.to_s == "#{obj_name} sched override".gsub(' ', '_').gsub('|', '_')

      actuator.remove
    end
    model.getEnergyManagementSystemPrograms.each do |program|
      next unless program.name.to_s == "#{obj_name} schedule program".gsub(' ', '_')

      program.remove
    end
    model.getEnergyManagementSystemProgramCallingManagers.each do |program_calling_manager|
      next unless program_calling_manager.name.to_s == obj_name + ' program calling manager'

      program_calling_manager.remove
    end

    unit.spaces.each do |space|
      space.electricEquipment.each do |equip|
        next unless equip.name.to_s == obj_name + ' non benchmark equip'

        equip.electricEquipmentDefinition.remove
      end

      space_obj_name = "#{obj_name} benchmark|#{space.name}"

      space.electricEquipment.each do |equip|
        next unless equip.name.to_s == space_obj_name

        equip.electricEquipmentDefinition.remove
      end
      model.getScheduleRulesets.each do |schedule|
        next unless schedule.name.to_s == space_obj_name + ' schedule'

        schedule.remove
      end
    end
  end

  def self.apply_eae_to_heating_fan(runner, loop_hvac, zone_hvacs, eae, fuel, dse, has_furnace, has_boiler, load_frac, loop_hvac_cool)
    # Applies Electric Auxiliary Energy (EAE) for fuel heating equipment to fan power.

    if has_boiler

      if eae.nil?
        eae = get_default_eae(has_boiler, has_furnace, fuel, load_frac, nil)
      end

      elec_power = (eae / 2.08) # W

      loop_hvac.components.each do |plc|
        if plc.to_BoilerHotWater.is_initialized
          boiler = plc.to_BoilerHotWater.get
          boiler.setParasiticElectricLoad(0.0)
        elsif plc.to_PumpVariableSpeed.is_initialized
          pump = plc.to_PumpVariableSpeed.get
          pump_eff = 0.9
          pump_gpm = UnitConversions.convert(pump.ratedFlowRate.get, 'm^3/s', 'gal/min')
          pump_w_gpm = elec_power / pump_gpm # W/gpm
          pump.setRatedPowerConsumption(elec_power / dse)
          pump.setRatedPumpHead(calculate_pump_head(pump_eff, pump_w_gpm / dse))
          pump.setMotorEfficiency(1.0)
        end
      end

    else # Furnace/WallFurnace/Stove

      htg_unitary_systems = []
      clg_unitary_system = nil
      if has_furnace
        loop_hvac.supplyComponents.each do |supply_component|
          next unless supply_component.to_AirLoopHVACUnitarySystem.is_initialized

          htg_unitary_systems << supply_component.to_AirLoopHVACUnitarySystem.get
        end

        # Cooling system with the same supply fan
        if not loop_hvac_cool.nil?
          loop_hvac_cool.supplyComponents.each do |supply_component|
            next unless supply_component.to_AirLoopHVACUnitarySystem.is_initialized

            clg_unitary_system = supply_component.to_AirLoopHVACUnitarySystem.get
          end
        end
      else
        zone_hvacs.each do |zone_hvac|
          htg_unitary_systems << zone_hvac.to_AirLoopHVACUnitarySystem.get
        end
      end

      htg_unitary_systems.each do |htg_unitary_system|
        if eae.nil?
          htg_coil = htg_unitary_system.heatingCoil.get.to_CoilHeatingGas.get
          htg_capacity = UnitConversions.convert(htg_coil.nominalCapacity.get, 'W', 'kBtu/hr')
          eae = get_default_eae(has_boiler, has_furnace, fuel, load_frac, htg_capacity)
        end
        elec_power = eae / 2.08 # W

        htg_coil = htg_unitary_system.heatingCoil.get.to_CoilHeatingGas.get
        htg_coil.setParasiticElectricLoad(0.0)

        htg_cfm = UnitConversions.convert(htg_unitary_system.supplyAirFlowRateDuringHeatingOperation.get, 'm^3/s', 'cfm')

        [htg_unitary_system, clg_unitary_system].each do |unitary_system|
          next if unitary_system.nil?

          fan = unitary_system.supplyFan.get.to_FanOnOff.get
          if elec_power > 0
            fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
            fan_w_cfm = elec_power / htg_cfm # W/cfm
            fan.setFanEfficiency(fan_eff)
            fan.setPressureRise(calculate_fan_pressure_rise(fan_eff, fan_w_cfm / dse))
          else
            fan.setFanEfficiency(1)
            fan.setPressureRise(0)
          end
          fan.setMotorEfficiency(1.0)
          fan.setMotorInAirstreamFraction(1.0)
        end
      end

    end

    return true
  end

  def self.get_default_eae(has_boiler, has_furnace, fuel, load_frac, furnace_capacity_kbtuh)
    # From ANSI/RESNET/ICC 301 Standard
    eae = nil
    if has_boiler
      if (fuel == Constants.FuelTypeGas) || (fuel == Constants.FuelTypePropane)
        eae = 170.0 * load_frac # kWh/yr
      elsif fuel == Constants.FuelTypeOil
        eae = 330.0 * load_frac # kWh/yr
      end
    elsif has_furnace
      if (fuel == Constants.FuelTypeGas) || (fuel == Constants.FuelTypePropane)
        eae = (149.0 + 10.3 * furnace_capacity_kbtuh) * load_frac # kWh/yr
      elsif fuel == Constants.FuelTypeOil
        eae = (439.0 + 5.5 * furnace_capacity_kbtuh) * load_frac # kWh/yr
      end
    else
      eae = 0.0 # FIXME: Is this right?
    end
    return eae
  end

  private

  def self.get_gshp_hx_pipe_diameters(pipe_size)
    # Pipe norminal size convertion to pipe outside diameter and inside diameter,
    # only pipe sizes <= 2" are used here with DR11 (dimension ratio),
    if pipe_size == 0.75 # 3/4" pipe
      pipe_od = 1.050
      pipe_id = 0.859
    elsif pipe_size == 1.0 # 1" pipe
      pipe_od = 1.315
      pipe_id = 1.076
    elsif pipe_size == 1.25 # 1-1/4" pipe
      pipe_od = 1.660
      pipe_id = 1.358
    end
    return pipe_od, pipe_id
  end

  def self.get_gshp_HXCHWDesign(weather)
    return [85.0, weather.design.CoolingDrybulb - 15.0, weather.data.AnnualAvgDrybulb + 10.0].max # Temperature of water entering indoor coil,use 85F as lower bound
  end

  def self.get_gshp_HXHWDesign(weather, fluid_type)
    if fluid_type == Constants.FluidWater
      return [45.0, weather.design.HeatingDrybulb + 35.0, weather.data.AnnualAvgDrybulb - 10.0].max # Temperature of fluid entering indoor coil, use 45F as lower bound for water
    else
      return [35.0, weather.design.HeatingDrybulb + 35.0, weather.data.AnnualAvgDrybulb - 10.0].min # Temperature of fluid entering indoor coil, use 35F as upper bound
    end
  end

  def self.get_gshp_cooling_eir(eer, fanKW_Adjust, pumpKW_Adjust)
    return UnitConversions.convert((1.0 - eer * (fanKW_Adjust + pumpKW_Adjust)) / (eer * (1 + UnitConversions.convert(fanKW_Adjust, 'Wh', 'Btu'))), 'Wh', 'Btu')
  end

  def self.get_gshp_heating_eir(cop, fanKW_Adjust, pumpKW_Adjust)
    return (1.0 - cop * (fanKW_Adjust + pumpKW_Adjust)) / (cop * (1 - fanKW_Adjust))
  end

  def self.get_gshp_FanKW_Adjust(cfm_btuh)
    return cfm_btuh * UnitConversions.convert(1.0, 'cfm', 'm^3/s') * 1000.0 * 0.35 * 249.0 / 300.0 # Adjustment per ISO 13256-1 Internal pressure drop across heat pump assumed to be 0.5 in. w.g.
  end

  def self.get_gshp_PumpKW_Adjust(gpm_btuh)
    return gpm_btuh * UnitConversions.convert(1.0, 'gal/min', 'm^3/s') * 1000.0 * 6.0 * 2990.0 / 3000.0 # Adjustment per ISO 13256-1 Internal Pressure drop across heat pump coil assumed to be 11ft w.g.
  end

  def self.calc_EIR_from_COP(cop, supplyFanPower_Rated)
    return UnitConversions.convert((UnitConversions.convert(1, 'Btu', 'Wh') + supplyFanPower_Rated * 0.03333) / cop - supplyFanPower_Rated * 0.03333, 'Wh', 'Btu')
  end

  def self.calc_EIR_from_EER(eer, supplyFanPower_Rated)
    return UnitConversions.convert((1 - UnitConversions.convert(supplyFanPower_Rated * 0.03333, 'Wh', 'Btu')) / eer - supplyFanPower_Rated * 0.03333, 'Wh', 'Btu')
  end

  def self.calc_cfms_ton_rated(rated_airflow_rate, fan_speed_ratios, capacity_ratios)
    array = []
    fan_speed_ratios.each_with_index do |fanspeed_ratio, i|
      capacity_ratio = capacity_ratios[i]
      array << fanspeed_ratio * rated_airflow_rate / capacity_ratio
    end
    return array
  end

  def self.create_curve_biquadratic_constant(model)
    const_biquadratic = OpenStudio::Model::CurveBiquadratic.new(model)
    const_biquadratic.setName('ConstantBiquadratic')
    const_biquadratic.setCoefficient1Constant(1)
    const_biquadratic.setCoefficient2x(0)
    const_biquadratic.setCoefficient3xPOW2(0)
    const_biquadratic.setCoefficient4y(0)
    const_biquadratic.setCoefficient5yPOW2(0)
    const_biquadratic.setCoefficient6xTIMESY(0)
    const_biquadratic.setMinimumValueofx(-100)
    const_biquadratic.setMaximumValueofx(100)
    const_biquadratic.setMinimumValueofy(-100)
    const_biquadratic.setMaximumValueofy(100)
    return const_biquadratic
  end

  def self.create_curve_cubic_constant(model)
    constant_cubic = OpenStudio::Model::CurveCubic.new(model)
    constant_cubic.setName('ConstantCubic')
    constant_cubic.setCoefficient1Constant(1)
    constant_cubic.setCoefficient2x(0)
    constant_cubic.setCoefficient3xPOW2(0)
    constant_cubic.setCoefficient4xPOW3(0)
    constant_cubic.setMinimumValueofx(-100)
    constant_cubic.setMaximumValueofx(100)
    return constant_cubic
  end

  def self.convert_curve_biquadratic(coeff, ip_to_si = true)
    if ip_to_si
      # Convert IP curves to SI curves
      si_coeff = []
      si_coeff << coeff[0] + 32.0 * (coeff[1] + coeff[3]) + 1024.0 * (coeff[2] + coeff[4] + coeff[5])
      si_coeff << 9.0 / 5.0 * coeff[1] + 576.0 / 5.0 * coeff[2] + 288.0 / 5.0 * coeff[5]
      si_coeff << 81.0 / 25.0 * coeff[2]
      si_coeff << 9.0 / 5.0 * coeff[3] + 576.0 / 5.0 * coeff[4] + 288.0 / 5.0 * coeff[5]
      si_coeff << 81.0 / 25.0 * coeff[4]
      si_coeff << 81.0 / 25.0 * coeff[5]
      return si_coeff
    else
      # Convert SI curves to IP curves
      ip_coeff = []
      ip_coeff << coeff[0] - 160.0 / 9.0 * (coeff[1] + coeff[3]) + 25600.0 / 81.0 * (coeff[2] + coeff[4] + coeff[5])
      ip_coeff << 5.0 / 9.0 * (coeff[1] - 320.0 / 9.0 * coeff[2] - 160.0 / 9.0 * coeff[5])
      ip_coeff << 25.0 / 81.0 * coeff[2]
      ip_coeff << 5.0 / 9.0 * (coeff[3] - 320.0 / 9.0 * coeff[4] - 160.0 / 9.0 * coeff[5])
      ip_coeff << 25.0 / 81.0 * coeff[4]
      ip_coeff << 25.0 / 81.0 * coeff[5]
      return ip_coeff
    end
  end

  def self.convert_curve_gshp(coeff, gshp_to_biquadratic)
    m1 = 32 - 273.15 * 1.8
    m2 = 283 * 1.8
    if gshp_to_biquadratic
      biq_coeff = []
      biq_coeff << coeff[0] - m1 * ((coeff[1] + coeff[2]) / m2)
      biq_coeff << coeff[1] / m2
      biq_coeff << 0
      biq_coeff << coeff[2] / m2
      biq_coeff << 0
      biq_coeff << 0
      return biq_coeff
    else
      gsph_coeff = []
      gsph_coeff << coeff[0] + m1 * (coeff[1] + coeff[3])
      gsph_coeff << m2 * coeff[1]
      gsph_coeff << m2 * coeff[3]
      gsph_coeff << 0
      gsph_coeff << 0
      return gsph_coeff
    end
  end

  def self.create_curve_biquadratic(model, coeff, name, minX, maxX, minY, maxY)
    curve = OpenStudio::Model::CurveBiquadratic.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2x(coeff[1])
    curve.setCoefficient3xPOW2(coeff[2])
    curve.setCoefficient4y(coeff[3])
    curve.setCoefficient5yPOW2(coeff[4])
    curve.setCoefficient6xTIMESY(coeff[5])
    curve.setMinimumValueofx(minX)
    curve.setMaximumValueofx(maxX)
    curve.setMinimumValueofy(minY)
    curve.setMaximumValueofy(maxY)
    return curve
  end

  def self.create_curve_bicubic(model, coeff, name, minX, maxX, minY, maxY)
    curve = OpenStudio::Model::CurveBicubic.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2x(coeff[1])
    curve.setCoefficient3xPOW2(coeff[2])
    curve.setCoefficient4y(coeff[3])
    curve.setCoefficient5yPOW2(coeff[4])
    curve.setCoefficient6xTIMESY(coeff[5])
    curve.setCoefficient7xPOW3(coeff[6])
    curve.setCoefficient8yPOW3(coeff[7])
    curve.setCoefficient9xPOW2TIMESY(coeff[8])
    curve.setCoefficient10xTIMESYPOW2(coeff[9])
    curve.setMinimumValueofx(minX)
    curve.setMaximumValueofx(maxX)
    curve.setMinimumValueofy(minY)
    curve.setMaximumValueofy(maxY)
    return curve
  end

  def self.create_curve_quadratic(model, coeff, name, minX, maxX, minY, maxY, is_dimensionless = false)
    curve = OpenStudio::Model::CurveQuadratic.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2x(coeff[1])
    curve.setCoefficient3xPOW2(coeff[2])
    curve.setMinimumValueofx(minX)
    curve.setMaximumValueofx(maxX)
    if not minY.nil?
      curve.setMinimumCurveOutput(minY)
    end
    if not maxY.nil?
      curve.setMaximumCurveOutput(maxY)
    end
    if is_dimensionless
      curve.setInputUnitTypeforX('Dimensionless')
      curve.setOutputUnitType('Dimensionless')
    end
    return curve
  end

  def self.create_curve_cubic(model, coeff, name, minX, maxX, minY, maxY)
    curve = OpenStudio::Model::CurveCubic.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2x(coeff[1])
    curve.setCoefficient3xPOW2(coeff[2])
    curve.setCoefficient4xPOW3(coeff[3])
    curve.setMinimumValueofx(minX)
    curve.setMaximumValueofx(maxX)
    curve.setMinimumCurveOutput(minY)
    curve.setMaximumCurveOutput(maxY)
    return curve
  end

  def self.create_curve_exponent(model, coeff, name, minX, maxX)
    curve = OpenStudio::Model::CurveExponent.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2Constant(coeff[1])
    curve.setCoefficient3Constant(coeff[2])
    curve.setMinimumValueofx(minX)
    curve.setMaximumValueofx(maxX)
    return curve
  end

  def self.calc_coil_stage_data_cooling(model, outputCapacity, speeds, cooling_eirs, shrs_rated_gross, cOOL_CAP_FT_SPEC, cOOL_EIR_FT_SPEC, cOOL_CLOSS_FPLR_SPEC, cOOL_CAP_FFLOW_SPEC, cOOL_EIR_FFLOW_SPEC, curves_in_ip, distributionSystemEfficiency)
    const_biquadratic = create_curve_biquadratic_constant(model)

    clg_coil_stage_data = []
    speeds.each_with_index do |speed, i|
      if curves_in_ip
        cOOL_CAP_FT_SPEC_ip = convert_curve_biquadratic(cOOL_CAP_FT_SPEC[speed])
        cOOL_EIR_FT_SPEC_ip = convert_curve_biquadratic(cOOL_EIR_FT_SPEC[speed])
      else
        cOOL_CAP_FT_SPEC_ip = cOOL_CAP_FT_SPEC[speed]
        cOOL_EIR_FT_SPEC_ip = cOOL_EIR_FT_SPEC[speed]
      end
      cool_cap_ft_curve = create_curve_biquadratic(model, cOOL_CAP_FT_SPEC_ip, "Cool-Cap-fT#{speed + 1}", 13.88, 23.88, 18.33, 51.66)
      cool_eir_ft_curve = create_curve_biquadratic(model, cOOL_EIR_FT_SPEC_ip, "Cool-EIR-fT#{speed + 1}", 13.88, 23.88, 18.33, 51.66)
      cool_plf_fplr_curve = create_curve_quadratic(model, cOOL_CLOSS_FPLR_SPEC[speed], "Cool-PLF-fPLR#{speed + 1}", 0, 1, 0.7, 1)
      cool_cap_fff_curve = create_curve_quadratic(model, cOOL_CAP_FFLOW_SPEC[speed], "Cool-Cap-fFF#{speed + 1}", 0, 2, 0, 2)
      cool_eir_fff_curve = create_curve_quadratic(model, cOOL_EIR_FFLOW_SPEC[speed], "Cool-EIR-fFF#{speed + 1}", 0, 2, 0, 2)

      stage_data = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model,
                                                                           cool_cap_ft_curve,
                                                                           cool_cap_fff_curve,
                                                                           cool_eir_ft_curve,
                                                                           cool_eir_fff_curve,
                                                                           cool_plf_fplr_curve,
                                                                           const_biquadratic)
      if (outputCapacity != Constants.SizingAuto) && (outputCapacity != Constants.SizingAutoMaxLoad)
        stage_data.setGrossRatedTotalCoolingCapacity(UnitConversions.convert(outputCapacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
      end
      stage_data.setGrossRatedSensibleHeatRatio(shrs_rated_gross[speed])
      stage_data.setGrossRatedCoolingCOP(distributionSystemEfficiency / cooling_eirs[speed])
      stage_data.setNominalTimeforCondensateRemovaltoBegin(1000)
      stage_data.setRatioofInitialMoistureEvaporationRateandSteadyStateLatentCapacity(1.5)
      stage_data.setMaximumCyclingRate(3)
      stage_data.setLatentCapacityTimeConstant(45)
      stage_data.setRatedWasteHeatFractionofPowerInput(0.2)
      clg_coil_stage_data[i] = stage_data
    end
    return clg_coil_stage_data
  end

  def self.calc_coil_stage_data_heating(model, outputCapacity, speeds, heating_eirs, hEAT_CAP_FT_SPEC, hEAT_EIR_FT_SPEC, hEAT_CLOSS_FPLR_SPEC, hEAT_CAP_FFLOW_SPEC, hEAT_EIR_FFLOW_SPEC, curves_in_ip, distributionSystemEfficiency)
    const_biquadratic = create_curve_biquadratic_constant(model)

    htg_coil_stage_data = []
    # Loop through speeds to create curves for each speed
    speeds.each_with_index do |speed, i|
      if curves_in_ip
        hEAT_CAP_FT_SPEC_ip = convert_curve_biquadratic(hEAT_CAP_FT_SPEC[speed])
        hEAT_EIR_FT_SPEC_ip = convert_curve_biquadratic(hEAT_EIR_FT_SPEC[speed])
      else
        hEAT_CAP_FT_SPEC_ip = hEAT_CAP_FT_SPEC[speed]
        hEAT_EIR_FT_SPEC_ip = hEAT_EIR_FT_SPEC[speed]
      end
      hp_heat_cap_ft_curve = create_curve_biquadratic(model, hEAT_CAP_FT_SPEC_ip, "HP_Heat-Cap-fT#{speed + 1}", -100, 100, -100, 100)
      hp_heat_eir_ft_curve = create_curve_biquadratic(model, hEAT_EIR_FT_SPEC_ip, "HP_Heat-EIR-fT#{speed + 1}", -100, 100, -100, 100)
      hp_heat_plf_fplr_curve = create_curve_quadratic(model, hEAT_CLOSS_FPLR_SPEC[speed], "HP_Heat-PLF-fPLR#{speed + 1}", 0, 1, 0.7, 1)
      hp_heat_cap_fff_curve = create_curve_quadratic(model, hEAT_CAP_FFLOW_SPEC[speed], "HP_Heat-CAP-fFF#{speed + 1}", 0, 2, 0, 2)
      hp_heat_eir_fff_curve = create_curve_quadratic(model, hEAT_EIR_FFLOW_SPEC[speed], "HP_Heat-EIR-fFF#{speed + 1}", 0, 2, 0, 2)

      stage_data = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model,
                                                                           hp_heat_cap_ft_curve,
                                                                           hp_heat_cap_fff_curve,
                                                                           hp_heat_eir_ft_curve,
                                                                           hp_heat_eir_fff_curve,
                                                                           hp_heat_plf_fplr_curve,
                                                                           const_biquadratic)
      if (outputCapacity != Constants.SizingAuto) && (outputCapacity != Constants.SizingAutoMaxLoad)
        stage_data.setGrossRatedHeatingCapacity(UnitConversions.convert(outputCapacity, 'Btu/hr', 'W')) # Used by HVACSizing measure
      end
      stage_data.setGrossRatedHeatingCOP(distributionSystemEfficiency / heating_eirs[speed])
      stage_data.setRatedWasteHeatFractionofPowerInput(0.2)
      htg_coil_stage_data[i] = stage_data
    end
    return htg_coil_stage_data
  end

  def self.calc_cooling_eirs(num_speeds, coolingEER, supplyFanPower_Rated)
    cooling_eirs = []
    (0...num_speeds).to_a.each do |speed|
      eir = calc_EIR_from_EER(coolingEER[speed], supplyFanPower_Rated)
      cooling_eirs << eir
    end
    return cooling_eirs
  end

  def self.calc_heating_eirs(num_speeds, heatingCOP, supplyFanPower_Rated)
    heating_eirs = []
    (0...num_speeds).to_a.each do |speed|
      eir = calc_EIR_from_COP(heatingCOP[speed], supplyFanPower_Rated)
      heating_eirs << eir
    end
    return heating_eirs
  end

  def self.calc_shrs_rated_gross(num_speeds, shr_Rated_Net, supplyFanPower_Rated, cfms_ton_rated)
    # Convert SHRs from net to gross
    shrs_rated_gross = []
    (0...num_speeds).to_a.each do |speed|
      qtot_net_nominal = 12000.0
      qsens_net_nominal = qtot_net_nominal * shr_Rated_Net[speed]
      qtot_gross_nominal = qtot_net_nominal + UnitConversions.convert(cfms_ton_rated[speed] * supplyFanPower_Rated, 'Wh', 'Btu')
      qsens_gross_nominal = qsens_net_nominal + UnitConversions.convert(cfms_ton_rated[speed] * supplyFanPower_Rated, 'Wh', 'Btu')
      shrs_rated_gross << (qsens_gross_nominal / qtot_gross_nominal)

      # Make sure SHR's are in valid range based on E+ model limits.
      # The following correlation was developed by Jon Winkler to test for maximum allowed SHR based on the 300 - 450 cfm/ton limits in E+
      maxSHR = 0.3821066 + 0.001050652 * cfms_ton_rated[speed] - 0.01
      shrs_rated_gross[speed] = [shrs_rated_gross[speed], maxSHR].min
      minSHR = 0.60 # Approximate minimum SHR such that an ADP exists
      shrs_rated_gross[speed] = [shrs_rated_gross[speed], minSHR].max
    end

    return shrs_rated_gross
  end

  def self.calc_plr_coefficients_cooling(num_speeds, coolingSEER, c_d = nil)
    if c_d.nil?
      c_d = get_c_d_cooling(num_speeds, coolingSEER)
    end
    return [(1.0 - c_d), c_d, 0.0] # Linear part load model
  end

  def self.calc_plr_coefficients_heating(num_speeds, heatingHSPF, c_d = nil)
    if c_d.nil?
      c_d = get_c_d_heating(num_speeds, heatingHSPF)
    end
    return [(1 - c_d), c_d, 0] # Linear part load model
  end

  def self.get_c_d_cooling(num_speeds, coolingSEER)
    # Degradation coefficient for cooling
    if num_speeds == 1
      if coolingSEER < 13.0
        return 0.20
      else
        return 0.07
      end
    elsif num_speeds == 2
      return 0.11
    elsif num_speeds == 4
      return 0.25
    end
  end

  def self.get_c_d_heating(num_speeds, heatingHSPF)
    # Degradation coefficient for heating
    if num_speeds == 1
      if heatingHSPF < 7.0
        return 0.20
      else
        return 0.11
      end
    elsif num_speeds == 2
      return 0.11
    elsif num_speeds == 4
      return 0.24
    end
  end

  def self.get_boiler_curve(model, isCondensing)
    if isCondensing
      return create_curve_biquadratic(model, [1.058343061, -0.052650153, -0.0087272, -0.001742217, 0.00000333715, 0.000513723], 'CondensingBoilerEff', 0.2, 1.0, 30.0, 85.0)
    else
      return create_curve_bicubic(model, [1.111720116, 0.078614078, -0.400425756, 0.0, -0.000156783, 0.009384599, 0.234257955, 1.32927e-06, -0.004446701, -1.22498e-05], 'NonCondensingBoilerEff', 0.1, 1.0, 20.0, 80.0)
    end
  end

  def self.calculate_fan_pressure_rise(fan_eff, fan_power)
    # Calculates needed fan pressure rise to achieve a given fan power with an assumed efficiency.
    # Previously we calculated the fan efficiency from an assumed pressure rise, which could lead to
    # errors (fan efficiencies > 1).
    return fan_eff * fan_power / UnitConversions.convert(1.0, 'cfm', 'm^3/s') # Pa
  end

  def self.calculate_pump_head(pump_eff, pump_power)
    # Calculate needed pump head to achieve a given pump power with an assumed efficiency.
    # Previously we calculated the pump efficiency from an assumed pump head, which could lead to
    # errors (pump efficiencies > 1).
    return pump_eff * pump_power / UnitConversions.convert(1.0, 'gal/min', 'm^3/s') # Pa
  end

  def self.get_control_and_slave_zones(thermal_zones)
    control_slave_zones_hash = {}
    finished_above_grade_zones, finished_below_grade_zones = Geometry.get_finished_above_and_below_grade_zones(thermal_zones)
    control_zone = nil
    slave_zones = []
    [finished_above_grade_zones, finished_below_grade_zones].each do |finished_zones| # Preference to above-grade zone as control zone
      finished_zones.each do |finished_zone|
        if control_zone.nil?
          control_zone = finished_zone
        else
          slave_zones << finished_zone
        end
      end
    end
    unless control_zone.nil?
      control_slave_zones_hash[control_zone] = slave_zones
    end
    return control_slave_zones_hash
  end

  def self.existing_cooling_equipment(model, runner, thermal_zone, exclude_central = false)
    # Returns a list of cooling equipment objects

    cooling_equipment = []
    if has_ashp(model, runner, thermal_zone)
      runner.registerInfo("Found air source heat pump providing cooling in #{thermal_zone.name}.")
    end
    if has_central_ac(model, runner, thermal_zone)
      runner.registerInfo("Found central air conditioner in #{thermal_zone.name}.")
    end
    if has_gshp(model, runner, thermal_zone)
      runner.registerInfo("Found ground source heat pump providing cooling in #{thermal_zone.name}.")
    end
    if has_room_ac(model, runner, thermal_zone)
      runner.registerInfo("Found room air conditioner in #{thermal_zone.name}.")
    end
    if has_mshp(model, runner, thermal_zone)
      runner.registerInfo("Found mini split heat pump providing cooling in #{thermal_zone.name}.")
    end
    if has_central_fan_coil(model, runner, thermal_zone)
      runner.registerInfo("Found central cooling fan coil in #{thermal_zone.name}.")
    end
    if has_central_ptac(model, runner, thermal_zone)
      runner.registerInfo("Found central ptac in #{thermal_zone.name}.")
    end

    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next if clg_coil.nil?

      cooling_equipment << system
    end

    ptacs = get_ptacs(model, runner, thermal_zone)
    ptacs.each do |ptac|
      cooling_equipment << ptac
    end

    unless exclude_central

      fcus = get_central_fan_coils(model, runner, thermal_zone)
      fcus.each do |fcu|
        cooling_equipment << fcu
      end

      ptacs = get_central_ptacs(model, runner, thermal_zone)
      ptacs.each do |ptac|
        cooling_equipment << ptac
      end

    end

    if has_ideal_air_cooling(model, runner, thermal_zone)
      runner.registerInfo("Found ideal air system in #{thermal_zone.name}.")
      ideal_air = get_ideal_air_cooling(model, runner, thermal_zone)
      cooling_equipment << ideal_air
    end

    return cooling_equipment
  end

  def self.existing_heating_equipment(model, runner, thermal_zone, exclude_central = false)
    # Returns a list of heating equipment objects

    heating_equipment = []
    if has_ashp(model, runner, thermal_zone)
      runner.registerInfo("Found air source heat pump providing heating in #{thermal_zone.name}.")
    end
    if has_furnace(model, runner, thermal_zone)
      runner.registerInfo("Found furnace in #{thermal_zone.name}.")
    end
    if has_gshp(model, runner, thermal_zone)
      runner.registerInfo("Found ground source heat pump providing heating in #{thermal_zone.name}.")
    end
    if has_boiler(model, runner, thermal_zone)
      runner.registerInfo("Found boiler serving #{thermal_zone.name}.")
    end
    if has_electric_baseboard(model, runner, thermal_zone)
      runner.registerInfo("Found electric baseboard in #{thermal_zone.name}.")
    end
    if has_mshp(model, runner, thermal_zone)
      runner.registerInfo("Found mini split heat pump providing heating in #{thermal_zone.name}.")
    end
    if has_unit_heater(model, runner, thermal_zone)
      runner.registerInfo("Found unit heater in #{thermal_zone.name}.")
    end
    if has_central_boiler(model, runner, thermal_zone)
      runner.registerInfo("Found central boiler in #{thermal_zone.name}.")
    end
    if has_central_fan_coil(model, runner, thermal_zone)
      runner.registerInfo("Found central heating fan coil in #{thermal_zone.name}.")
    end
    if has_central_ptac(model, runner, thermal_zone)
      runner.registerInfo("Found central ptac in #{thermal_zone.name}.")
    end

    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next if htg_coil.nil?

      heating_equipment << system
    end

    baseboards = get_baseboard_waters(model, runner, thermal_zone)
    baseboards.each do |baseboard|
      heating_equipment << baseboard
    end

    baseboards = get_baseboard_electrics(model, runner, thermal_zone)
    baseboards.each do |baseboard|
      heating_equipment << baseboard
    end

    unitary_system_zone_hvacs = get_unitary_system_zone_hvacs(model, runner, thermal_zone)
    unitary_system_zone_hvacs.each do |unitary_system_zone_hvac|
      system, clg_coil, htg_coil = unitary_system_zone_hvac
      next if htg_coil.nil?

      heating_equipment << system
    end

    unless exclude_central

      baseboards = get_central_baseboard_waters(model, runner, thermal_zone)
      baseboards.each do |baseboard|
        heating_equipment << baseboard
      end

      fcus = get_central_fan_coils(model, runner, thermal_zone)
      fcus.each do |fcu|
        heating_equipment << fcu
      end

      ptacs = get_central_ptacs(model, runner, thermal_zone)
      ptacs.each do |ptac|
        heating_equipment << ptac
      end

    end

    if has_ideal_air_heating(model, runner, thermal_zone)
      runner.registerInfo("Found ideal air system in #{thermal_zone.name}.")
      ideal_air = get_ideal_air_heating(model, runner, thermal_zone)
      heating_equipment << ideal_air
    end

    return heating_equipment
  end

  def self.get_coils_from_hvac_equip(hvac_equip)
    # Returns the clg coil, htg coil, and supp htg coil as applicable
    clg_coil = nil
    htg_coil = nil
    supp_htg_coil = nil
    if hvac_equip.is_a? OpenStudio::Model::AirLoopHVACUnitarySystem
      htg_coil = get_coil_from_hvac_component(hvac_equip.heatingCoil)
      clg_coil = get_coil_from_hvac_component(hvac_equip.coolingCoil)
      supp_htg_coil = get_coil_from_hvac_component(hvac_equip.supplementalHeatingCoil)
    elsif hvac_equip.is_a? OpenStudio::Model::ZoneHVACBaseboardConvectiveWater
      htg_coil = get_coil_from_hvac_component(hvac_equip.heatingCoil)
    elsif hvac_equip.is_a? OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner
      htg_coil = get_coil_from_hvac_component(hvac_equip.heatingCoil)
      clg_coil = get_coil_from_hvac_component(hvac_equip.coolingCoil)
    elsif hvac_equip.is_a? OpenStudio::Model::ZoneHVACFourPipeFanCoil
      htg_coil = HVAC.get_coil_from_hvac_component(hvac_equip.heatingCoil)
      clg_coil = HVAC.get_coil_from_hvac_component(hvac_equip.coolingCoil)
    end
    return clg_coil, htg_coil, supp_htg_coil
  end

  def self.get_coil_from_hvac_component(hvac_component)
    # Check for optional objects
    if hvac_component.is_a? OpenStudio::Model::OptionalHVACComponent
      return if not hvac_component.is_initialized

      hvac_component = hvac_component.get
    end

    # Cooling coils
    if hvac_component.to_CoilCoolingDXSingleSpeed.is_initialized
      return hvac_component.to_CoilCoolingDXSingleSpeed.get
    elsif hvac_component.to_CoilCoolingDXMultiSpeed.is_initialized
      return hvac_component.to_CoilCoolingDXMultiSpeed.get
    elsif hvac_component.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
      return hvac_component.to_CoilCoolingWaterToAirHeatPumpEquationFit.get
    elsif hvac_component.to_CoilCoolingWater.is_initialized
      return hvac_component.to_CoilCoolingWater.get
    end

    # Heating coils
    if hvac_component.to_CoilHeatingDXSingleSpeed.is_initialized
      return hvac_component.to_CoilHeatingDXSingleSpeed.get
    elsif hvac_component.to_CoilHeatingDXMultiSpeed.is_initialized
      return hvac_component.to_CoilHeatingDXMultiSpeed.get
    elsif hvac_component.to_CoilHeatingGas.is_initialized
      return hvac_component.to_CoilHeatingGas.get
    elsif hvac_component.to_CoilHeatingElectric.is_initialized
      return hvac_component.to_CoilHeatingElectric.get
    elsif hvac_component.to_CoilHeatingWaterBaseboard.is_initialized
      return hvac_component.to_CoilHeatingWaterBaseboard.get
    elsif hvac_component.to_CoilHeatingWaterToAirHeatPumpEquationFit.is_initialized
      return hvac_component.to_CoilHeatingWaterToAirHeatPumpEquationFit.get
    elsif hvac_component.to_CoilHeatingWater.is_initialized
      return hvac_component.to_CoilHeatingWater.get
    end

    return hvac_component
  end

  def self.get_unitary_system_air_loops(model, runner, thermal_zone)
    # Returns the unitary system(s), cooling coil(s), heating coil(s), and air loops(s) if available
    unitary_system_air_loops = []
    thermal_zone.airLoopHVACs.each do |air_loop|
      air_loop.supplyComponents.each do |supply_component|
        next unless supply_component.to_AirLoopHVACUnitarySystem.is_initialized

        system = supply_component.to_AirLoopHVACUnitarySystem.get
        clg_coil = nil
        htg_coil = nil
        if system.coolingCoil.is_initialized
          clg_coil = system.coolingCoil.get
        end
        if system.heatingCoil.is_initialized
          htg_coil = system.heatingCoil.get
        end
        unitary_system_air_loops << [system, clg_coil, htg_coil, air_loop]
      end
    end
    return unitary_system_air_loops
  end

  def self.get_unitary_system_zone_hvacs(model, runner, thermal_zone)
    # Returns the unitary system, cooling coil, and heating coil if available
    unitary_system_zone_hvacs = []
    thermal_zone.equipment.each do |equipment|
      next unless equipment.to_AirLoopHVACUnitarySystem.is_initialized

      system = equipment.to_AirLoopHVACUnitarySystem.get
      clg_coil = nil
      htg_coil = nil
      if system.coolingCoil.is_initialized
        clg_coil = system.coolingCoil.get
      end
      if system.heatingCoil.is_initialized
        htg_coil = system.heatingCoil.get
      end
      unitary_system_zone_hvacs << [system, clg_coil, htg_coil]
    end
    return unitary_system_zone_hvacs
  end

  def self.get_ptacs(model, runner, thermal_zone)
    # Returns the PTAC(s) if available
    ptacs = []
    model.getZoneHVACPackagedTerminalAirConditioners.each do |ptac|
      next unless thermal_zone.handle.to_s == ptac.thermalZone.get.handle.to_s
      next if ptac.heatingCoil.to_CoilHeatingWater.is_initialized # exclude central PTAC

      ptacs << ptac
    end
    return ptacs
  end

  def self.get_central_baseboard_waters(model, runner, thermal_zone)
    # Returns the central water baseboard(s) if available
    baseboards = []
    model.getZoneHVACBaseboardConvectiveWaters.each do |baseboard|
      next unless baseboard.additionalProperties.getFeatureAsBoolean('CentralSystem').get
      next unless thermal_zone.handle.to_s == baseboard.thermalZone.get.handle.to_s

      baseboards << baseboard
    end
    return baseboards
  end

  def self.get_central_ptacs(model, runner, thermal_zone)
    # Returns the central PTAC(s) if available
    ptacs = []
    model.getZoneHVACPackagedTerminalAirConditioners.each do |ptac|
      next unless thermal_zone.handle.to_s == ptac.thermalZone.get.handle.to_s
      next unless ptac.heatingCoil.to_CoilHeatingWater.is_initialized

      ptacs << ptac
    end
    return ptacs
  end

  def self.get_central_fan_coils(model, runner, thermal_zone)
    # Returns the fan coil(s) if available
    fcus = []
    model.getZoneHVACFourPipeFanCoils.each do |fcu|
      next unless thermal_zone.handle.to_s == fcu.thermalZone.get.handle.to_s

      fcus << fcu
    end
    return fcus
  end

  def self.get_baseboard_waters(model, runner, thermal_zone)
    # Returns the water baseboard if available
    baseboards = []
    model.getZoneHVACBaseboardConvectiveWaters.each do |baseboard|
      next if baseboard.additionalProperties.getFeatureAsBoolean('CentralSystem').get
      next unless thermal_zone.handle.to_s == baseboard.thermalZone.get.handle.to_s

      baseboards << baseboard
    end
    return baseboards
  end

  def self.get_baseboard_electrics(model, runner, thermal_zone)
    # Returns the electric baseboard if available
    baseboards = []
    model.getZoneHVACBaseboardConvectiveElectrics.each do |baseboard|
      next unless thermal_zone.handle.to_s == baseboard.thermalZone.get.handle.to_s

      baseboards << baseboard
    end
    return baseboards
  end

  def self.get_dehumidifiers(model, runner, thermal_zone)
    # Returns the dehumidifier if available
    dehums = []
    model.getZoneHVACDehumidifierDXs.each do |dehum|
      next unless thermal_zone.handle.to_s == dehum.thermalZone.get.handle.to_s

      dehums << dehum
    end
    return dehums
  end

  def self.get_ideal_air_heating(model, runner, thermal_zone)
    # Returns the heating ideal air loads system if available
    model.getZoneHVACIdealLoadsAirSystems.each do |ideal_air|
      next unless thermal_zone.handle.to_s == ideal_air.thermalZone.get.handle.to_s
      next if ideal_air.heatingAvailabilitySchedule == model.alwaysOffDiscreteSchedule

      return ideal_air
    end
    return
  end

  def self.get_ideal_air_cooling(model, runner, thermal_zone)
    # Returns the heating ideal air loads system if available
    model.getZoneHVACIdealLoadsAirSystems.each do |ideal_air|
      next unless thermal_zone.handle.to_s == ideal_air.thermalZone.get.handle.to_s
      next if ideal_air.coolingAvailabilitySchedule == model.alwaysOffDiscreteSchedule

      return ideal_air
    end
    return
  end

  # Num Equipment methods

  def self.num_central_ac(model, runner, thermal_zone)
    num = 0
    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next unless system.name.to_s.start_with? Constants.ObjectNameCentralAirConditioner

      num += 1
    end
    return num
  end

  def self.num_ashp(model, runner, thermal_zone)
    num = 0
    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next unless system.name.to_s.start_with? Constants.ObjectNameAirSourceHeatPump

      num += 1
    end
    return num
  end

  def self.num_gshp(model, runner, thermal_zone)
    num = 0
    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next unless system.name.to_s.start_with? Constants.ObjectNameGroundSourceHeatPumpVerticalBore

      num += 1
    end
    return num
  end

  def self.num_furnace(model, runner, thermal_zone)
    num = 0
    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next unless system.name.to_s.start_with? Constants.ObjectNameFurnace

      num += 1
    end
    return num
  end

  def self.num_mshp(model, runner, thermal_zone)
    num = 0
    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next unless system.name.to_s.start_with? Constants.ObjectNameMiniSplitHeatPump

      num += 1
    end
    return num
  end

  def self.num_room_ac(model, runner, thermal_zone)
    return get_ptacs(model, runner, thermal_zone).length
  end

  def self.num_boiler(model, runner, thermal_zone)
    return get_baseboard_waters(model, runner, thermal_zone).length
  end

  def self.num_electric_baseboard(model, runner, thermal_zone)
    return get_baseboard_electrics(model, runner, thermal_zone).length
  end

  def self.num_unit_heater(model, runner, thermal_zone)
    return get_unitary_system_zone_hvacs(model, runner, thermal_zone).length
  end

  def self.num_central_boiler(model, runner, thermal_zone)
    return get_central_baseboard_waters(model, runner, thermal_zone).length
  end

  def self.num_central_ptac(model, runner, thermal_zone)
    return get_central_ptacs(model, runner, thermal_zone).length
  end

  def self.num_central_fan_coil(model, runner, thermal_zone)
    return get_central_fan_coils(model, runner, thermal_zone).length
  end

  def self.num_air_loop_hvac_unitary_system_clg_coils(model, runner, thermal_zone)
    clg_coils = []
    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next if clg_coil.nil?

      clg_coils << clg_coil
    end
    return clg_coils.length
  end

  def self.num_air_loop_hvac_unitary_system_htg_coils(model, runner, thermal_zone)
    htg_coils = []
    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next if htg_coil.nil?

      htg_coils << htg_coil
    end
    return htg_coils.length
  end

  def self.num_zone_hvac_unitary_system_clg_coils(model, runner, thermal_zone)
    clg_coils = []
    unitary_system_zone_hvacs = get_unitary_system_zone_hvacs(model, runner, thermal_zone)
    unitary_system_zone_hvacs.each do |unitary_system_zone_hvac|
      system, clg_coil, htg_coil = unitary_system_zone_hvac
      next if clg_coil.nil?

      clg_coils << clg_coil
    end
    return clg_coils.length
  end

  def self.num_zone_hvac_unitary_system_htg_coils(model, runner, thermal_zone)
    htg_coils = []
    unitary_system_zone_hvacs = get_unitary_system_zone_hvacs(model, runner, thermal_zone)
    unitary_system_zone_hvacs.each do |unitary_system_zone_hvac|
      system, clg_coil, htg_coil = unitary_system_zone_hvac
      next if htg_coil.nil?

      htg_coils << htg_coil
    end
    return htg_coils.length
  end

  # Has Equipment methods

  def self.has_central_ac(model, runner, thermal_zone)
    return num_central_ac(model, runner, thermal_zone) > 0
  end

  def self.has_ashp(model, runner, thermal_zone)
    return num_ashp(model, runner, thermal_zone) > 0
  end

  def self.has_gshp(model, runner, thermal_zone)
    return num_gshp(model, runner, thermal_zone) > 0
  end

  def self.has_furnace(model, runner, thermal_zone)
    return num_furnace(model, runner, thermal_zone) > 0
  end

  def self.has_mshp(model, runner, thermal_zone)
    return num_mshp(model, runner, thermal_zone) > 0
  end

  def self.has_ducted_mshp(model, runner, thermal_zone)
    if not has_mshp(model, runner, thermal_zone)
      return false
    end

    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next unless system.name.to_s.start_with? Constants.ObjectNameMiniSplitHeatPump

      is_ducted = system.additionalProperties.getFeatureAsBoolean(Constants.DuctedInfoMiniSplitHeatPump).get
      return is_ducted
    end
    return false
  end

  def self.has_room_ac(model, runner, thermal_zone)
    return num_room_ac(model, runner, thermal_zone) > 0
  end

  def self.has_boiler(model, runner, thermal_zone)
    return num_boiler(model, runner, thermal_zone) > 0
  end

  def self.has_electric_baseboard(model, runner, thermal_zone)
    return num_electric_baseboard(model, runner, thermal_zone) > 0
  end

  def self.has_unit_heater(model, runner, thermal_zone)
    return num_unit_heater(model, runner, thermal_zone) > 0
  end

  def self.has_central_boiler(model, runner, thermal_zone)
    return num_central_boiler(model, runner, thermal_zone) > 0
  end

  def self.has_central_ptac(model, runner, thermal_zone)
    return num_central_ptac(model, runner, thermal_zone) > 0
  end

  def self.has_central_fan_coil(model, runner, thermal_zone)
    return num_central_fan_coil(model, runner, thermal_zone) > 0
  end

  def self.has_dehumidifier(model, runner, thermal_zone)
    dehums = get_dehumidifiers(model, runner, thermal_zone)
    unless dehums.empty?
      return false
    end

    return true
  end

  def self.has_ideal_air_heating(model, runner, thermal_zone)
    ideal_air = get_ideal_air_heating(model, runner, thermal_zone)
    if not ideal_air.nil?
      return true
    end

    return false
  end

  def self.has_ideal_air_cooling(model, runner, thermal_zone)
    ideal_air = get_ideal_air_heating(model, runner, thermal_zone)
    if not ideal_air.nil?
      return true
    end

    return false
  end

  def self.has_ducted_equipment(model, runner, thermal_zone)
    if has_central_ac(model, runner, thermal_zone)
      return true
    elsif has_furnace(model, runner, thermal_zone)
      return true
    elsif has_ashp(model, runner, thermal_zone)
      return true
    elsif has_gshp(model, runner, thermal_zone)
      return true
    elsif has_ducted_mshp(model, runner, thermal_zone)
      return true
    end

    return false
  end

  # Remove Equipment methods

  def self.remove_central_ac(model, runner, thermal_zone)
    # Returns true if the object was removed
    return false if not has_central_ac(model, runner, thermal_zone)

    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next unless system.name.to_s.start_with? Constants.ObjectNameCentralAirConditioner

      runner.registerInfo("Removed '#{clg_coil.name}' from '#{air_loop.name}'.")
      system.resetCoolingCoil
      clg_coil.remove
      system.supplyFan.get.remove
      runner.registerInfo("Removed '#{air_loop.name}' from #{thermal_zone.name}.")
      air_loop.remove
    end
    return true
  end

  def self.remove_ashp(model, runner, thermal_zone)
    # Returns true if the object was removed
    return false if not has_ashp(model, runner, thermal_zone)

    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next unless system.name.to_s.start_with? Constants.ObjectNameAirSourceHeatPump

      unless htg_coil.nil?
        runner.registerInfo("Removed '#{htg_coil.name}' from '#{air_loop.name}'.")
        system.resetHeatingCoil
        htg_coil.remove
      end
      unless clg_coil.nil?
        runner.registerInfo("Removed '#{clg_coil.name}' from '#{air_loop.name}'.")
        system.resetCoolingCoil
        clg_coil.remove
      end
      system.supplyFan.get.remove
      runner.registerInfo("Removed '#{air_loop.name}' from #{thermal_zone.name}.")
      air_loop.remove
    end
    return true
  end

  def self.remove_gshp(model, runner, thermal_zone, unit)
    # Returns true if the object was removed
    return false if not has_gshp(model, runner, thermal_zone)

    remove_boiler_and_gshp_loops(model, runner, thermal_zone)
    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next unless system.name.to_s.start_with? Constants.ObjectNameGroundSourceHeatPumpVerticalBore

      unless htg_coil.nil?
        runner.registerInfo("Removed '#{htg_coil.name}' from '#{air_loop.name}'.")
        system.resetHeatingCoil
        htg_coil.remove
      end
      unless clg_coil.nil?
        runner.registerInfo("Removed '#{clg_coil.name}' from '#{air_loop.name}'.")
        system.resetCoolingCoil
        clg_coil.remove
      end
      system.supplyFan.get.remove
      air_loop.remove
      runner.registerInfo("Removed '#{air_loop.name}' from #{thermal_zone.name}.")
    end
    obj_name = Constants.ObjectNameGroundSourceHeatPumpVerticalBore(unit.name.to_s)
    model.getEnergyManagementSystemSensors.each do |sensor|
      next if (sensor.name.to_s != "#{obj_name} pump s".gsub(' ', '_').gsub('|', '_')) && (sensor.name.to_s != "#{obj_name} heating coil s".gsub(' ', '_').gsub('|', '_')) && (sensor.name.to_s != "#{obj_name} cooling coil s".gsub(' ', '_').gsub('|', '_'))

      sensor.remove
    end
    model.getEnergyManagementSystemOutputVariables.each do |output_var|
      next if (output_var.name.to_s != "#{obj_name} htg pump:Pumps:Electricity") && (output_var.name.to_s != "#{obj_name} clg pump:Pumps:Electricity")

      output_var.remove
    end
    model.getEnergyManagementSystemPrograms.each do |program|
      next unless program.name.to_s == "#{obj_name} pumps program".gsub(' ', '_')

      program.remove
    end
    model.getEnergyManagementSystemProgramCallingManagers.each do |program_calling_manager|
      next unless program_calling_manager.name.to_s == "#{obj_name} pump program calling manager"

      program_calling_manager.remove
    end
    return true
  end

  def self.remove_furnace(model, runner, thermal_zone)
    # Returns true if the object was removed
    return false if not has_furnace(model, runner, thermal_zone)

    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next unless system.name.to_s.start_with? Constants.ObjectNameFurnace

      runner.registerInfo("Removed '#{htg_coil.name}' from '#{air_loop.name}'.")
      system.resetHeatingCoil
      htg_coil.remove
      system.supplyFan.get.remove
      runner.registerInfo("Removed '#{air_loop.name}' from #{thermal_zone.name}.")
      air_loop.remove
    end
    return true
  end

  def self.remove_mshp(model, runner, thermal_zone, unit)
    # Returns true if the object was removed
    return false if not has_mshp(model, runner, thermal_zone)

    unitary_system_air_loops = get_unitary_system_air_loops(model, runner, thermal_zone)
    unitary_system_air_loops.each do |unitary_system_air_loop|
      system, clg_coil, htg_coil, air_loop = unitary_system_air_loop
      next unless system.name.to_s.start_with? Constants.ObjectNameMiniSplitHeatPump

      unless htg_coil.nil?
        runner.registerInfo("Removed '#{htg_coil.name}' from '#{air_loop.name}'.")
        system.resetHeatingCoil
        htg_coil.remove
      end
      unless clg_coil.nil?
        runner.registerInfo("Removed '#{clg_coil.name}' from '#{air_loop.name}'.")
        system.resetCoolingCoil
        clg_coil.remove
      end
      system.supplyFan.get.remove
      runner.registerInfo("Removed '#{air_loop.name}' from #{thermal_zone.name}.")
      air_loop.remove
    end
    obj_name = Constants.ObjectNameMiniSplitHeatPump(unit.name.to_s)
    model.getEnergyManagementSystemSensors.each do |sensor|
      next unless sensor.name.to_s == "#{obj_name} vrf energy sensor".gsub(' ', '_').gsub('|', '_')

      sensor.remove
    end
    model.getEnergyManagementSystemSensors.each do |sensor|
      next unless sensor.name.to_s == "#{obj_name} tout sensor".gsub(' ', '_').gsub('|', '_')

      sensor.remove
    end
    model.getEnergyManagementSystemActuators.each do |actuator|
      next unless actuator.name.to_s == "#{obj_name} pan heater actuator".gsub(' ', '_').gsub('|', '_')

      actuator.remove
    end
    model.getEnergyManagementSystemPrograms.each do |program|
      next unless program.name.to_s == "#{obj_name} pan heater program".gsub(' ', '_')

      program.remove
    end
    model.getEnergyManagementSystemProgramCallingManagers.each do |program_calling_manager|
      next unless program_calling_manager.name.to_s == obj_name + ' pan heater program calling manager'

      program_calling_manager.remove
    end
    thermal_zone.spaces.each do |space|
      space.electricEquipment.each do |equip|
        next unless equip.name.to_s == obj_name + ' pan heater equip'

        equip.electricEquipmentDefinition.remove
      end
    end
    return true
  end

  def self.remove_room_ac(model, runner, thermal_zone)
    # Returns true if the object was removed
    return false if not has_room_ac(model, runner, thermal_zone)

    ptacs = get_ptacs(model, runner, thermal_zone)
    ptacs.each do |ptac|
      runner.registerInfo("Removed '#{ptac.name}' from #{thermal_zone.name}.")
      ptac.remove
    end
    return true
  end

  def self.remove_boiler(model, runner, thermal_zone, unit)
    # Returns true if the object was removed
    return false unless has_boiler(model, runner, thermal_zone) || has_central_boiler(model, runner, thermal_zone)

    remove_boiler_and_gshp_loops(model, runner, thermal_zone)
    baseboards = get_baseboard_waters(model, runner, thermal_zone) + get_central_baseboard_waters(model, runner, thermal_zone)
    baseboards.each do |baseboard|
      runner.registerInfo("Removed '#{baseboard.name}' from #{thermal_zone.name}.")
      baseboard.remove
    end
    [Constants.FuelTypeGas, Constants.FuelTypeOil, Constants.FuelTypePropane, Constants.FuelTypeElectric].each do |fuel_type|
      obj_name = Constants.ObjectNameBoiler(fuel_type, unit.name.to_s)
      model.getEnergyManagementSystemSensors.each do |sensor|
        next if (sensor.name.to_s != "#{obj_name} hydronic pump s".gsub(' ', '_').gsub('|', '_')) && (sensor.name.to_s != 'Central pump s'.gsub(' ', '_').gsub('|', '_'))

        sensor.remove
      end
      model.getEnergyManagementSystemOutputVariables.each do |output_var|
        next if (output_var.name.to_s != "#{obj_name} htg pump:Pumps:Electricity") && (output_var.name.to_s != 'Central htg pump:Pumps:Electricity')

        output_var.remove
      end
      model.getEnergyManagementSystemPrograms.each do |program|
        next if (program.name.to_s != "#{obj_name} pumps program".gsub(' ', '_')) && (program.name.to_s != 'Central pumps program'.gsub(' ', '_'))

        program.remove
      end
      model.getEnergyManagementSystemProgramCallingManagers.each do |program_calling_manager|
        next if (program_calling_manager.name.to_s != "#{obj_name} pump program calling manager") && (program_calling_manager.name.to_s != 'Central pump program calling manager')

        program_calling_manager.remove
      end
    end
    return true
  end

  def self.remove_electric_baseboard(model, runner, thermal_zone)
    # Returns true if the object was removed
    return false if not has_electric_baseboard(model, runner, thermal_zone)

    baseboards = get_baseboard_electrics(model, runner, thermal_zone)
    baseboards.each do |baseboard|
      runner.registerInfo("Removed '#{baseboard.name}' from #{thermal_zone.name}.")
      baseboard.remove
    end
    return true
  end

  def self.remove_unit_heater(model, runner, thermal_zone)
    # Returns true if the object was removed
    return false if not has_unit_heater(model, runner, thermal_zone)

    unitary_system_zone_hvacs = get_unitary_system_zone_hvacs(model, runner, thermal_zone)
    unitary_system_zone_hvacs.each do |unitary_system_zone_hvac|
      system, clg_coil, htg_coil = unitary_system_zone_hvac
      runner.registerInfo("Removed '#{system.name}' from '#{thermal_zone.name}'.")
      system.resetHeatingCoil
      htg_coil.remove
      if system.supplyFan.is_initialized
        system.supplyFan.get.remove
      end
      system.remove
    end
    return true
  end

  def self.remove_boiler_and_gshp_loops(model, runner, thermal_zone)
    model.getPlantLoops.each do |plant_loop|
      remove = false

      # Ensure we're operating on the right plant loop
      is_specified_zone = false
      plant_loop.demandComponents.each do |demand_component|
        demand_coil = nil
        if demand_component.to_CoilHeatingWaterBaseboard.is_initialized
          demand_coil = demand_component.to_CoilHeatingWaterBaseboard.get
        elsif demand_component.to_CoilHeatingWaterToAirHeatPumpEquationFit.is_initialized
          demand_coil = demand_component.to_CoilHeatingWaterToAirHeatPumpEquationFit.get
        elsif demand_component.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
          demand_coil = demand_component.to_CoilCoolingWaterToAirHeatPumpEquationFit.get
        elsif demand_component.to_CoilHeatingWater.is_initialized
          demand_coil = demand_component.to_CoilHeatingWater.get
        end
        next if demand_coil.nil?

        if demand_coil.containingZoneHVACComponent.is_initialized
          demand_hvac = demand_coil.containingZoneHVACComponent.get
          next if (not demand_hvac.thermalZone.is_initialized) || (demand_hvac.thermalZone.get != thermal_zone)

          is_specified_zone = true
        elsif demand_coil.containingHVACComponent.is_initialized
          demand_hvac = demand_coil.containingHVACComponent.get
          next if not demand_hvac.airLoopHVAC.is_initialized

          demand_air_loop = demand_hvac.airLoopHVAC.get
          demand_air_loop.thermalZones.each do |thermalZone|
            next if thermal_zone.handle.to_s != thermalZone.handle.to_s

            is_specified_zone = true
          end
        end
      end
      next if not is_specified_zone

      plant_loop.supplyComponents.each do |supply_component|
        if supply_component.to_BoilerHotWater.is_initialized || supply_component.to_GroundHeatExchangerVertical.is_initialized || supply_component.to_GroundHeatExchangerHorizontalTrench.is_initialized
          remove = true
        end
      end
      if remove
        runner.registerInfo("Removed '#{plant_loop.name}' from model.")
        plant_loop.remove
      end
    end
  end

  def self.remove_central_system_fan_coil_heating(model, runner, thermal_zone)
    # Returns true if the object was removed
    return false if not has_central_fan_coil(model, runner, thermal_zone)

    fan_coil_heating = false
    fcus = get_central_fan_coils(model, runner, thermal_zone)
    fcus.each do |fcu|
      if fcu.heatingCoil.to_CoilHeatingWater.is_initialized && fcu.coolingCoil.to_CoilCoolingWater.is_initialized
        fan_coil_heating = true
      end
    end

    if fan_coil_heating
      remove_central_system_fan_coil(model, runner, thermal_zone)
    end
  end

  def self.remove_central_system_fan_coil(model, runner, thermal_zone)
    # Returns true if the object was removed
    return false if not has_central_fan_coil(model, runner, thermal_zone)

    remove_fan_coil_loops(model, runner, thermal_zone)
    fcus = get_central_fan_coils(model, runner, thermal_zone)
    fcus.each do |fcu|
      runner.registerInfo("Removed '#{fcu.name}' from '#{thermal_zone.name}'.")
      fcu.remove
    end

    ['htg', 'clg'].each do |htg_or_clg|
      model.getEnergyManagementSystemSensors.each do |sensor|
        next if sensor.name.to_s != "Central #{htg_or_clg} pump s".gsub(' ', '_').gsub('|', '_')

        sensor.remove
      end
      model.getEnergyManagementSystemOutputVariables.each do |output_var|
        next if output_var.name.to_s != "Central #{htg_or_clg} pump:Pumps:Electricity"

        output_var.remove
      end
      model.getEnergyManagementSystemPrograms.each do |program|
        next unless program.name.to_s == "Central pumps #{htg_or_clg} program".gsub(' ', '_')

        program.remove
      end
      model.getEnergyManagementSystemProgramCallingManagers.each do |program_calling_manager|
        next unless program_calling_manager.name.to_s == "Central pump #{htg_or_clg} program calling manager"

        program_calling_manager.remove
      end
    end
  end

  def self.remove_central_system_ptac(model, runner, thermal_zone)
    # Returns true if the object was removed
    return false if not has_central_ptac(model, runner, thermal_zone)

    remove_boiler_and_gshp_loops(model, runner, thermal_zone)
    ptacs = get_central_ptacs(model, runner, thermal_zone)
    ptacs.each do |ptac|
      runner.registerInfo("Removed '#{ptac.name}' from '#{thermal_zone.name}'.")
      ptac.remove
    end
    model.getEnergyManagementSystemSensors.each do |sensor|
      next if sensor.name.to_s != 'Central pump s'.gsub(' ', '_').gsub('|', '_')

      sensor.remove
    end
    model.getEnergyManagementSystemOutputVariables.each do |output_var|
      next if output_var.name.to_s != 'Central htg pump:Pumps:Electricity'

      output_var.remove
    end
    model.getEnergyManagementSystemPrograms.each do |program|
      next unless program.name.to_s == 'Central pumps program'.gsub(' ', '_')

      program.remove
    end
    model.getEnergyManagementSystemProgramCallingManagers.each do |program_calling_manager|
      next unless program_calling_manager.name.to_s == 'Central pump program calling manager'

      program_calling_manager.remove
    end
    return true
  end

  def self.remove_fan_coil_loops(model, runner, thermal_zone)
    model.getPlantLoops.each do |plant_loop|
      remove = false

      # Ensure we're operating on the right plant loop
      is_specified_zone = false
      plant_loop.demandComponents.each do |demand_component|
        demand_coil = nil
        if demand_component.to_CoilHeatingWater.is_initialized
          demand_coil = demand_component.to_CoilHeatingWater.get
        elsif demand_component.to_CoilCoolingWater.is_initialized
          demand_coil = demand_component.to_CoilCoolingWater.get
        end
        next if demand_coil.nil?

        if demand_coil.containingZoneHVACComponent.is_initialized
          demand_hvac = demand_coil.containingZoneHVACComponent.get
          next if (not demand_hvac.thermalZone.is_initialized) || (demand_hvac.thermalZone.get != thermal_zone)

          is_specified_zone = true
        elsif demand_coil.containingHVACComponent.is_initialized
          demand_hvac = demand_coil.containingHVACComponent.get
          next if not demand_hvac.airLoopHVAC.is_initialized

          demand_air_loop = demand_hvac.airLoopHVAC.get
          demand_air_loop.thermalZones.each do |thermalZone|
            next if thermal_zone.handle.to_s != thermalZone.handle.to_s

            is_specified_zone = true
          end
        end
      end
      next if not is_specified_zone

      plant_loop.supplyComponents.each do |supply_component|
        if supply_component.to_BoilerHotWater.is_initialized || supply_component.to_ChillerElectricEIR.is_initialized
          remove = true
        end
      end
      if remove
        runner.registerInfo("Removed '#{plant_loop.name}' from model.")
        plant_loop.remove
      end
    end
  end

  def self.prioritize_zone_hvac(model, runner, zone, load_distribution_scheme = 'SequentialLoad')
    zone_hvac_list = []
    Constants.ZoneHVACPriorityList.each do |zone_hvac_type|
      zone.equipment.each do |object|
        next if not object.respond_to?("to_#{zone_hvac_type}")
        next if not object.public_send("to_#{zone_hvac_type}").is_initialized

        new_object = object.public_send("to_#{zone_hvac_type}").get
        zone_hvac_list << new_object
      end
    end
    zone_hvac_list.reverse.each do |object|
      zone.setCoolingPriority(object, 1)
      zone.setHeatingPriority(object, 1)
    end
    zone.setLoadDistributionScheme(load_distribution_scheme)
  end

  def self.calc_heating_and_cooling_seasons(model, weather, runner = nil)
    # Calculates heating/cooling seasons from BAHSP definition

    monthly_temps = weather.data.MonthlyAvgDrybulbs
    heat_design_db = weather.design.HeatingDrybulb

    # create basis lists with zero for every month
    cooling_season_temp_basis = Array.new(monthly_temps.length, 0.0)
    heating_season_temp_basis = Array.new(monthly_temps.length, 0.0)

    monthly_temps.each_with_index do |temp, i|
      if temp < 66.0
        heating_season_temp_basis[i] = 1.0
      elsif temp >= 66.0
        cooling_season_temp_basis[i] = 1.0
      end

      if ((i == 0) || (i == 11)) && (heat_design_db < 59.0)
        heating_season_temp_basis[i] = 1.0
      elsif (i == 6) || (i == 7)
        cooling_season_temp_basis[i] = 1.0
      end
    end

    cooling_season = Array.new(monthly_temps.length, 0.0)
    heating_season = Array.new(monthly_temps.length, 0.0)

    monthly_temps.each_with_index do |temp, i|
      # Heating overlaps with cooling at beginning of summer
      if i == 0 # January
        prevmonth = 11 # December
      else
        prevmonth = i - 1
      end

      if ((heating_season_temp_basis[i] == 1.0) || ((cooling_season_temp_basis[prevmonth] == 0.0) && (cooling_season_temp_basis[i] == 1.0)))
        heating_season[i] = 1.0
      else
        heating_season[i] = 0.0
      end

      if ((cooling_season_temp_basis[i] == 1.0) || ((heating_season_temp_basis[prevmonth] == 0.0) && (heating_season_temp_basis[i] == 1.0)))
        cooling_season[i] = 1.0
      else
        cooling_season[i] = 0.0
      end
    end

    # Find the first month of cooling and add one month
    (1...12).to_a.each do |i|
      if cooling_season[i] == 1.0
        cooling_season[i - 1] = 1.0
        break
      end
    end

    return heating_season, cooling_season
  end

  def self.calc_mshp_cfms_ton_cooling(cap_min_per, cap_max_per, cfm_ton_min, cfm_ton_max, num_speeds, dB_rated, wB_rated, shr)
    capacity_ratios_cooling = [0.0] * num_speeds
    cfms_cooling = [0.0] * num_speeds
    shrs_rated = [0.0] * num_speeds

    cap_nom_per = 1.0
    cfm_ton_nom = ((cfm_ton_max - cfm_ton_min) / (cap_max_per - cap_min_per)) * (cap_nom_per - cap_min_per) + cfm_ton_min

    ao = Psychrometrics.CoilAoFactor(dB_rated, wB_rated, Constants.Patm, UnitConversions.convert(1, 'ton', 'kBtu/hr'), cfm_ton_nom, shr)

    (0...num_speeds).each do |i|
      capacity_ratios_cooling[i] = cap_min_per + i * (cap_max_per - cap_min_per) / (num_speeds - 1)
      cfms_cooling[i] = cfm_ton_min + i * (cfm_ton_max - cfm_ton_min) / (num_speeds - 1)
      # Calculate the SHR for each speed. Use minimum value of 0.98 to prevent E+ bypass factor calculation errors
      shrs_rated[i] = [Psychrometrics.CalculateSHR(dB_rated, wB_rated, Constants.Patm, UnitConversions.convert(capacity_ratios_cooling[i], 'ton', 'kBtu/hr'), cfms_cooling[i], ao), 0.98].min
    end

    return cfms_cooling, capacity_ratios_cooling, shrs_rated
  end

  def self.calc_mshp_cooling_eirs(runner, coolingSEER, supplyFanPower, c_d, num_speeds, capacity_ratios_cooling, cfms_cooling, cOOL_EIR_FT_SPEC, cOOL_CAP_FT_SPEC)
    cops_Norm = [1.901, 1.859, 1.746, 1.609, 1.474, 1.353, 1.247, 1.156, 1.079, 1.0]
    fanPows_Norm = [0.604, 0.634, 0.670, 0.711, 0.754, 0.800, 0.848, 0.898, 0.948, 1.0]

    cooling_eirs = [0.0] * num_speeds
    fanPowsRated = [0.0] * num_speeds
    eers_Rated = [0.0] * num_speeds

    cop_maxSpeed = 3.5 # 3.5 is an initial guess, final value solved for below

    (0...num_speeds).each do |i|
      fanPowsRated[i] = supplyFanPower * fanPows_Norm[i]
      eers_Rated[i] = UnitConversions.convert(cop_maxSpeed, 'W', 'Btu/hr') * cops_Norm[i]
    end

    cop_maxSpeed_1 = cop_maxSpeed
    cop_maxSpeed_2 = cop_maxSpeed
    error = coolingSEER - calc_mshp_SEER_VariableSpeed(eers_Rated, c_d, capacity_ratios_cooling, cfms_cooling, fanPowsRated, true, cOOL_EIR_FT_SPEC, cOOL_CAP_FT_SPEC)
    error1 = error
    error2 = error

    itmax = 50 # maximum iterations
    cvg = false
    final_n = nil

    (1...itmax + 1).each do |n|
      final_n = n
      (0...num_speeds).each do |i|
        eers_Rated[i] = UnitConversions.convert(cop_maxSpeed, 'W', 'Btu/hr') * cops_Norm[i]
      end

      error = coolingSEER - calc_mshp_SEER_VariableSpeed(eers_Rated, c_d, capacity_ratios_cooling, cfms_cooling, fanPowsRated, true, cOOL_EIR_FT_SPEC, cOOL_CAP_FT_SPEC)

      cop_maxSpeed, cvg, cop_maxSpeed_1, error1, cop_maxSpeed_2, error2 = MathTools.Iterate(cop_maxSpeed, error, cop_maxSpeed_1, error1, cop_maxSpeed_2, error2, n, cvg)

      if cvg
        break
      end
    end

    if (not cvg) || (final_n > itmax)
      cop_maxSpeed = UnitConversions.convert(0.547 * coolingSEER - 0.104, 'Btu/hr', 'W') # Correlation developed from JonW's MatLab scripts. Only used is an EER cannot be found.
      runner.registerWarning('Mini-split heat pump COP iteration failed to converge. Setting to default value.')
    end

    (0...num_speeds).each do |i|
      cooling_eirs[i] = calc_EIR_from_EER(UnitConversions.convert(cop_maxSpeed, 'W', 'Btu/hr') * cops_Norm[i], fanPowsRated[i])
    end

    return cooling_eirs
  end

  def self.calc_mshp_SEER_VariableSpeed(eer_A, c_d, capacityRatio, cfm_Tons, supplyFanPower_Rated, isHeatPump, cOOL_EIR_FT_SPEC, cOOL_CAP_FT_SPEC)
    n_max = (eer_A.length - 1.0) - 3.0 # Don't use max speed
    n_min = 0.0
    n_int = (n_min + (n_max - n_min) / 3.0).ceil.to_i

    wBin = UnitConversions.convert(67.0, 'F', 'C')
    tout_B = UnitConversions.convert(82.0, 'F', 'C')
    tout_E = UnitConversions.convert(87.0, 'F', 'C')
    tout_F = UnitConversions.convert(67.0, 'F', 'C')

    eir_A2 = calc_EIR_from_EER(eer_A[n_max], supplyFanPower_Rated[n_max])
    eir_B2 = eir_A2 * MathTools.biquadratic(wBin, tout_B, cOOL_EIR_FT_SPEC[n_max])

    eir_Av = calc_EIR_from_EER(eer_A[n_int], supplyFanPower_Rated[n_int])
    eir_Ev = eir_Av * MathTools.biquadratic(wBin, tout_E, cOOL_EIR_FT_SPEC[n_int])

    eir_A1 = calc_EIR_from_EER(eer_A[n_min], supplyFanPower_Rated[n_min])
    eir_B1 = eir_A1 * MathTools.biquadratic(wBin, tout_B, cOOL_EIR_FT_SPEC[n_min])
    eir_F1 = eir_A1 * MathTools.biquadratic(wBin, tout_F, cOOL_EIR_FT_SPEC[n_min])

    q_A2 = capacityRatio[n_max]
    q_B2 = q_A2 * MathTools.biquadratic(wBin, tout_B, cOOL_CAP_FT_SPEC[n_max])
    q_Ev = capacityRatio[n_int] * MathTools.biquadratic(wBin, tout_E, cOOL_CAP_FT_SPEC[n_int])
    q_B1 = capacityRatio[n_min] * MathTools.biquadratic(wBin, tout_B, cOOL_CAP_FT_SPEC[n_min])
    q_F1 = capacityRatio[n_min] * MathTools.biquadratic(wBin, tout_F, cOOL_CAP_FT_SPEC[n_min])

    q_A2_net = q_A2 - supplyFanPower_Rated[n_max] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_max] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_B2_net = q_B2 - supplyFanPower_Rated[n_max] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_max] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_Ev_net = q_Ev - supplyFanPower_Rated[n_int] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_int] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_B1_net = q_B1 - supplyFanPower_Rated[n_min] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_min] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_F1_net = q_F1 - supplyFanPower_Rated[n_min] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_min] / UnitConversions.convert(1, 'ton', 'Btu/hr')

    p_A2 = UnitConversions.convert(q_A2 * eir_A2, 'Btu', 'Wh') + supplyFanPower_Rated[n_max] * cfm_Tons[n_max] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_B2 = UnitConversions.convert(q_B2 * eir_B2, 'Btu', 'Wh') + supplyFanPower_Rated[n_max] * cfm_Tons[n_max] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_Ev = UnitConversions.convert(q_Ev * eir_Ev, 'Btu', 'Wh') + supplyFanPower_Rated[n_int] * cfm_Tons[n_int] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_B1 = UnitConversions.convert(q_B1 * eir_B1, 'Btu', 'Wh') + supplyFanPower_Rated[n_min] * cfm_Tons[n_min] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_F1 = UnitConversions.convert(q_F1 * eir_F1, 'Btu', 'Wh') + supplyFanPower_Rated[n_min] * cfm_Tons[n_min] / UnitConversions.convert(1, 'ton', 'Btu/hr')

    q_k1_87 = q_F1_net + (q_B1_net - q_F1_net) / (82.0 - 67.0) * (87 - 67.0)
    q_k2_87 = q_B2_net + (q_A2_net - q_B2_net) / (95.0 - 82.0) * (87.0 - 82.0)
    n_Q = (q_Ev_net - q_k1_87) / (q_k2_87 - q_k1_87)
    m_Q = (q_B1_net - q_F1_net) / (82.0 - 67.0) * (1.0 - n_Q) + (q_A2_net - q_B2_net) / (95.0 - 82.0) * n_Q
    p_k1_87 = p_F1 + (p_B1 - p_F1) / (82.0 - 67.0) * (87.0 - 67.0)
    p_k2_87 = p_B2 + (p_A2 - p_B2) / (95.0 - 82.0) * (87.0 - 82.0)
    n_E = (p_Ev - p_k1_87) / (p_k2_87 - p_k1_87)
    m_E = (p_B1 - p_F1) / (82.0 - 67.0) * (1.0 - n_E) + (p_A2 - p_B2) / (95.0 - 82.0) * n_E

    c_T_1_1 = q_A2_net / (1.1 * (95.0 - 65.0))
    c_T_1_2 = q_F1_net
    c_T_1_3 = (q_B1_net - q_F1_net) / (82.0 - 67.0)
    t_1 = (c_T_1_2 - 67.0 * c_T_1_3 + 65.0 * c_T_1_1) / (c_T_1_1 - c_T_1_3)
    q_T_1 = q_F1_net + (q_B1_net - q_F1_net) / (82.0 - 67.0) * (t_1 - 67.0)
    p_T_1 = p_F1 + (p_B1 - p_F1) / (82.0 - 67.0) * (t_1 - 67.0)
    eer_T_1 = q_T_1 / p_T_1

    t_v = (q_Ev_net - 87.0 * m_Q + 65.0 * c_T_1_1) / (c_T_1_1 - m_Q)
    q_T_v = q_Ev_net + m_Q * (t_v - 87.0)
    p_T_v = p_Ev + m_E * (t_v - 87.0)
    eer_T_v = q_T_v / p_T_v

    c_T_2_1 = c_T_1_1
    c_T_2_2 = q_B2_net
    c_T_2_3 = (q_A2_net - q_B2_net) / (95.0 - 82.0)
    t_2 = (c_T_2_2 - 82.0 * c_T_2_3 + 65.0 * c_T_2_1) / (c_T_2_1 - c_T_2_3)
    q_T_2 = q_B2_net + (q_A2_net - q_B2_net) / (95.0 - 82.0) * (t_2 - 82.0)
    p_T_2 = p_B2 + (p_A2 - p_B2) / (95.0 - 82.0) * (t_2 - 82.0)
    eer_T_2 = q_T_2 / p_T_2

    d = (t_2**2 - t_1**2) / (t_v**2 - t_1**2)
    b = (eer_T_1 - eer_T_2 - d * (eer_T_1 - eer_T_v)) / (t_1 - t_2 - d * (t_1 - t_v))
    c = (eer_T_1 - eer_T_2 - b * (t_1 - t_2)) / (t_1**2 - t_2**2)
    a = eer_T_2 - b * t_2 - c * t_2**2

    e_tot = 0
    q_tot = 0
    t_bins = [67.0, 72.0, 77.0, 82.0, 87.0, 92.0, 97.0, 102.0]
    frac_hours = [0.214, 0.231, 0.216, 0.161, 0.104, 0.052, 0.018, 0.004]

    (0...8).each do |_i|
      bL = ((t_bins[_i] - 65.0) / (95.0 - 65.0)) * (q_A2_net / 1.1)
      q_k1 = q_F1_net + (q_B1_net - q_F1_net) / (82.0 - 67.0) * (t_bins[_i] - 67.0)
      p_k1 = p_F1 + (p_B1 - p_F1) / (82.0 - 67.0) * (t_bins[_i] - 67)
      q_k2 = q_B2_net + (q_A2_net - q_B2_net) / (95.0 - 82.0) * (t_bins[_i] - 82.0)
      p_k2 = p_B2 + (p_A2 - p_B2) / (95.0 - 82.0) * (t_bins[_i] - 82.0)

      if bL <= q_k1
        x_k1 = bL / q_k1
        q_Tj_N = x_k1 * q_k1 * frac_hours[_i]
        e_Tj_N = x_k1 * p_k1 * frac_hours[_i] / (1 - c_d * (1 - x_k1))
      elsif (q_k1 < bL) && (bL <= q_k2)
        q_Tj_N = bL * frac_hours[_i]
        eer_T_j = a + b * t_bins[_i] + c * t_bins[_i]**2
        e_Tj_N = q_Tj_N / eer_T_j
      else
        q_Tj_N = frac_hours[_i] * q_k2
        e_Tj_N = frac_hours[_i] * p_k2
      end

      q_tot += q_Tj_N
      e_tot += e_Tj_N
    end

    seer = q_tot / e_tot
    return seer
  end

  def self.calc_mshp_cfms_ton_heating(cap_min_per, cap_max_per, cfm_ton_min, cfm_ton_max, num_speeds)
    capacity_ratios_heating = [0.0] * num_speeds
    cfms_heating = [0.0] * num_speeds

    (0...num_speeds).each do |i|
      capacity_ratios_heating[i] = cap_min_per + i * (cap_max_per - cap_min_per) / (num_speeds - 1)
      cfms_heating[i] = cfm_ton_min + i * (cfm_ton_max - cfm_ton_min) / (num_speeds - 1)
    end

    return cfms_heating, capacity_ratios_heating
  end

  def self.calc_mshp_heating_eirs(runner, heatingHSPF, supplyFanPower, min_hp_temp, c_d, cfms_cooling, num_speeds, capacity_ratios_heating, cfms_heating, hEAT_EIR_FT_SPEC, hEAT_CAP_FT_SPEC)
    # COPs_Norm = [1.636, 1.757, 1.388, 1.240, 1.162, 1.119, 1.084, 1.062, 1.044, 1] #Report Avg
    # COPs_Norm = [1.792, 1.502, 1.308, 1.207, 1.145, 1.105, 1.077, 1.056, 1.041, 1] #BEopt Default

    cops_Norm = [1.792, 1.502, 1.308, 1.207, 1.145, 1.105, 1.077, 1.056, 1.041, 1] # BEopt Default
    fanPows_Norm = [0.577, 0.625, 0.673, 0.720, 0.768, 0.814, 0.861, 0.907, 0.954, 1]

    heating_eirs = [0.0] * num_speeds
    fanPowsRated = [0.0] * num_speeds
    cops_Rated = [0.0] * num_speeds

    cop_maxSpeed = 3.25 # 3.35 is an initial guess, final value solved for below

    (0...num_speeds).each do |i|
      fanPowsRated[i] = supplyFanPower * fanPows_Norm[i]
      cops_Rated[i] = cop_maxSpeed * cops_Norm[i]
    end

    cop_maxSpeed_1 = cop_maxSpeed
    cop_maxSpeed_2 = cop_maxSpeed
    error = heatingHSPF - calc_mshp_HSPF_VariableSpeed(cops_Rated, c_d, capacity_ratios_heating, cfms_heating, fanPowsRated, min_hp_temp, hEAT_EIR_FT_SPEC, hEAT_CAP_FT_SPEC)

    error1 = error
    error2 = error

    itmax = 50 # maximum iterations
    cvg = false
    final_n = nil

    (1...itmax + 1).each do |n|
      final_n = n
      (0...num_speeds).each do |i|
        cops_Rated[i] = cop_maxSpeed * cops_Norm[i]
      end

      error = heatingHSPF - calc_mshp_HSPF_VariableSpeed(cops_Rated, c_d, capacity_ratios_heating, cfms_cooling, fanPowsRated, min_hp_temp, hEAT_EIR_FT_SPEC, hEAT_CAP_FT_SPEC)

      cop_maxSpeed, cvg, cop_maxSpeed_1, error1, cop_maxSpeed_2, error2 = MathTools.Iterate(cop_maxSpeed, error, cop_maxSpeed_1, error1, cop_maxSpeed_2, error2, n, cvg)

      if cvg
        break
      end
    end

    if (not cvg) || (final_n > itmax)
      cop_maxSpeed = UnitConversions.convert(0.4174 * heatingHSPF - 1.1134, 'Btu/hr', 'W') # Correlation developed from JonW's MatLab scripts. Only used if a COP cannot be found.
      runner.registerWarning('Mini-split heat pump COP iteration failed to converge. Setting to default value.')
    end

    (0...num_speeds).each do |i|
      heating_eirs[i] = calc_EIR_from_COP(cop_maxSpeed * cops_Norm[i], fanPowsRated[i])
    end

    return heating_eirs
  end

  def self.calc_mshp_HSPF_VariableSpeed(cop_47, c_d, capacityRatio, cfm_Tons, supplyFanPower_Rated, min_temp, hEAT_EIR_FT_SPEC, hEAT_CAP_FT_SPEC)
    n_max = (cop_47.length - 1.0) #-3 # Don't use max speed
    n_min = 0
    n_int = (n_min + (n_max - n_min) / 3.0).ceil.to_i

    tin = UnitConversions.convert(70.0, 'F', 'C')
    tout_3 = UnitConversions.convert(17.0, 'F', 'C')
    tout_2 = UnitConversions.convert(35.0, 'F', 'C')
    tout_0 = UnitConversions.convert(62.0, 'F', 'C')

    eir_H1_2 = calc_EIR_from_COP(cop_47[n_max], supplyFanPower_Rated[n_max])
    eir_H3_2 = eir_H1_2 * MathTools.biquadratic(tin, tout_3, hEAT_EIR_FT_SPEC[n_max])

    eir_adjv = calc_EIR_from_COP(cop_47[n_int], supplyFanPower_Rated[n_int])
    eir_H2_v = eir_adjv * MathTools.biquadratic(tin, tout_2, hEAT_EIR_FT_SPEC[n_int])

    eir_H1_1 = calc_EIR_from_COP(cop_47[n_min], supplyFanPower_Rated[n_min])
    eir_H0_1 = eir_H1_1 * MathTools.biquadratic(tin, tout_0, hEAT_EIR_FT_SPEC[n_min])

    q_H1_2 = capacityRatio[n_max]
    q_H3_2 = q_H1_2 * MathTools.biquadratic(tin, tout_3, hEAT_CAP_FT_SPEC[n_max])

    q_H2_v = capacityRatio[n_int] * MathTools.biquadratic(tin, tout_2, hEAT_CAP_FT_SPEC[n_int])

    q_H1_1 = capacityRatio[n_min]
    q_H0_1 = q_H1_1 * MathTools.biquadratic(tin, tout_0, hEAT_CAP_FT_SPEC[n_min])

    q_H1_2_net = q_H1_2 + supplyFanPower_Rated[n_max] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_max] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_H3_2_net = q_H3_2 + supplyFanPower_Rated[n_max] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_max] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_H2_v_net = q_H2_v + supplyFanPower_Rated[n_int] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_int] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_H1_1_net = q_H1_1 + supplyFanPower_Rated[n_min] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_min] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_H0_1_net = q_H0_1 + supplyFanPower_Rated[n_min] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_min] / UnitConversions.convert(1, 'ton', 'Btu/hr')

    p_H1_2 = q_H1_2 * eir_H1_2 + supplyFanPower_Rated[n_max] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_max] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_H3_2 = q_H3_2 * eir_H3_2 + supplyFanPower_Rated[n_max] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_max] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_H2_v = q_H2_v * eir_H2_v + supplyFanPower_Rated[n_int] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_int] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_H1_1 = q_H1_1 * eir_H1_1 + supplyFanPower_Rated[n_min] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_min] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_H0_1 = q_H0_1 * eir_H0_1 + supplyFanPower_Rated[n_min] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_Tons[n_min] / UnitConversions.convert(1, 'ton', 'Btu/hr')

    q_H35_2 = 0.9 * (q_H3_2_net + 0.6 * (q_H1_2_net - q_H3_2_net))
    p_H35_2 = 0.985 * (p_H3_2 + 0.6 * (p_H1_2 - p_H3_2))
    q_H35_1 = q_H1_1_net + (q_H0_1_net - q_H1_1_net) / (62.0 - 47.0) * (35.0 - 47.0)
    p_H35_1 = p_H1_1 + (p_H0_1 - p_H1_1) / (62.0 - 47.0) * (35.0 - 47.0)
    n_Q = (q_H2_v_net - q_H35_1) / (q_H35_2 - q_H35_1)
    m_Q = (q_H0_1_net - q_H1_1_net) / (62.0 - 47.0) * (1 - n_Q) + n_Q * (q_H35_2 - q_H3_2_net) / (35.0 - 17.0)
    n_E = (p_H2_v - p_H35_1) / (p_H35_2 - p_H35_1)
    m_E = (p_H0_1 - p_H1_1) / (62.0 - 47.0) * (1.0 - n_E) + n_E * (p_H35_2 - p_H3_2) / (35.0 - 17.0)

    t_OD = 5.0
    dHR = q_H1_2_net * (65.0 - t_OD) / 60.0

    c_T_3_1 = q_H1_1_net
    c_T_3_2 = (q_H0_1_net - q_H1_1_net) / (62.0 - 47.0)
    c_T_3_3 = 0.77 * dHR / (65.0 - t_OD)
    t_3 = (47.0 * c_T_3_2 + 65.0 * c_T_3_3 - c_T_3_1) / (c_T_3_2 + c_T_3_3)
    q_HT3_1 = q_H1_1_net + (q_H0_1_net - q_H1_1_net) / (62.0 - 47.0) * (t_3 - 47.0)
    p_HT3_1 = p_H1_1 + (p_H0_1 - p_H1_1) / (62.0 - 47.0) * (t_3 - 47.0)
    cop_T3_1 = q_HT3_1 / p_HT3_1

    c_T_v_1 = q_H2_v_net
    c_T_v_3 = c_T_3_3
    t_v = (35.0 * m_Q + 65.0 * c_T_v_3 - c_T_v_1) / (m_Q + c_T_v_3)
    q_HTv_v = q_H2_v_net + m_Q * (t_v - 35.0)
    p_HTv_v = p_H2_v + m_E * (t_v - 35.0)
    cop_Tv_v = q_HTv_v / p_HTv_v

    c_T_4_1 = q_H3_2_net
    c_T_4_2 = (q_H35_2 - q_H3_2_net) / (35.0 - 17.0)
    c_T_4_3 = c_T_v_3
    t_4 = (17.0 * c_T_4_2 + 65.0 * c_T_4_3 - c_T_4_1) / (c_T_4_2 + c_T_4_3)
    q_HT4_2 = q_H3_2_net + (q_H35_2 - q_H3_2_net) / (35.0 - 17.0) * (t_4 - 17.0)
    p_HT4_2 = p_H3_2 + (p_H35_2 - p_H3_2) / (35.0 - 17.0) * (t_4 - 17.0)
    cop_T4_2 = q_HT4_2 / p_HT4_2

    d = (t_3**2 - t_4**2) / (t_v**2 - t_4**2)
    b = (cop_T4_2 - cop_T3_1 - d * (cop_T4_2 - cop_Tv_v)) / (t_4 - t_3 - d * (t_4 - t_v))
    c = (cop_T4_2 - cop_T3_1 - b * (t_4 - t_3)) / (t_4**2 - t_3**2)
    a = cop_T4_2 - b * t_4 - c * t_4**2

    t_bins = [62.0, 57.0, 52.0, 47.0, 42.0, 37.0, 32.0, 27.0, 22.0, 17.0, 12.0, 7.0, 2.0, -3.0, -8.0]
    frac_hours = [0.132, 0.111, 0.103, 0.093, 0.100, 0.109, 0.126, 0.087, 0.055, 0.036, 0.026, 0.013, 0.006, 0.002, 0.001]

    # T_off = min_temp
    t_off = 10.0
    t_on = t_off + 4.0
    etot = 0
    bLtot = 0

    (0...15).each do |_i|
      bL = ((65.0 - t_bins[_i]) / (65.0 - t_OD)) * 0.77 * dHR

      q_1 = q_H1_1_net + (q_H0_1_net - q_H1_1_net) / (62.0 - 47.0) * (t_bins[_i] - 47.0)
      p_1 = p_H1_1 + (p_H0_1 - p_H1_1) / (62.0 - 47.0) * (t_bins[_i] - 47.0)

      if (t_bins[_i] <= 17.0) || (t_bins[_i] >= 45.0)
        q_2 = q_H3_2_net + (q_H1_2_net - q_H3_2_net) * (t_bins[_i] - 17.0) / (47.0 - 17.0)
        p_2 = p_H3_2 + (p_H1_2 - p_H3_2) * (t_bins[_i] - 17.0) / (47.0 - 17.0)
      else
        q_2 = q_H3_2_net + (q_H35_2 - q_H3_2_net) * (t_bins[_i] - 17) / (35.0 - 17.0)
        p_2 = p_H3_2 + (p_H35_2 - p_H3_2) * (t_bins[_i] - 17.0) / (35.0 - 17.0)
      end

      if t_bins[_i] <= t_off
        delta = 0
      elsif t_bins[_i] >= t_on
        delta = 1.0
      else
        delta = 0.5
      end

      if bL <= q_1
        x_1 = bL / q_1
        e_Tj_n = delta * x_1 * p_1 * frac_hours[_i] / (1.0 - c_d * (1.0 - x_1))
      elsif (q_1 < bL) && (bL <= q_2)
        cop_T_j = a + b * t_bins[_i] + c * t_bins[_i]**2
        e_Tj_n = delta * frac_hours[_i] * bL / cop_T_j + (1.0 - delta) * bL * (frac_hours[_i])
      else
        e_Tj_n = delta * frac_hours[_i] * p_2 + frac_hours[_i] * (bL - delta * q_2)
      end

      bLtot += frac_hours[_i] * bL
      etot += e_Tj_n
    end

    hspf = bLtot / UnitConversions.convert(etot, 'Btu/hr', 'W')
    return hspf
  end
end
