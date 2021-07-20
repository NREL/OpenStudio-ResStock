# frozen_string_literal: true

class HVAC
  def self.apply_central_air_conditioner_furnace(model, runner, cooling_system, heating_system,
                                                 sequential_cool_load_fracs, sequential_heat_load_fracs,
                                                 control_zone, hvac_map)

    hvac_map[cooling_system.id] = [] unless cooling_system.nil?
    hvac_map[heating_system.id] = [] unless heating_system.nil?
    if heating_system.nil?
      obj_name = Constants.ObjectNameCentralAirConditioner
    elsif cooling_system.nil?
      obj_name = Constants.ObjectNameFurnace
    else
      obj_name = Constants.ObjectNameCentralAirConditionerAndFurnace
    end

    if not heating_system.nil?
      htg_ap = heating_system.additional_properties
    end
    if not cooling_system.nil?
      clg_ap = cooling_system.additional_properties
    end

    # Cooling Coil
    if not cooling_system.nil?
      clg_coil = create_dx_cooling_coil(model, obj_name, cooling_system)
      hvac_map[cooling_system.id] << clg_coil
    end

    # Heating Coil
    if not heating_system.nil?
      if heating_system.heating_system_fuel == HPXML::FuelTypeElectricity
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model)
        htg_coil.setEfficiency(heating_system.heating_efficiency_afue)
      else
        htg_coil = OpenStudio::Model::CoilHeatingGas.new(model)
        htg_coil.setGasBurnerEfficiency(heating_system.heating_efficiency_afue)
        htg_coil.setParasiticElectricLoad(0)
        htg_coil.setParasiticGasLoad(0)
        htg_coil.setFuelType(EPlus.fuel_type(heating_system.heating_system_fuel))
      end
      htg_coil.setNominalCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
      htg_coil.setName(obj_name + ' htg coil')
      hvac_map[heating_system.id] << htg_coil
    end

    # Fan
    if (not cooling_system.nil?) && (not heating_system.nil?) && (cooling_system.fan_watts_per_cfm.to_f != heating_system.fan_watts_per_cfm.to_f)
      fail "Fan powers for heating system '#{heating_system.id}' and cooling system '#{cooling_system.id}' are attached to a single distribution system and therefore must be the same."
    end

    if (not cooling_system.nil?) && (not cooling_system.fan_watts_per_cfm.nil?)
      fan_watts_per_cfm = cooling_system.fan_watts_per_cfm
    else
      fan_watts_per_cfm = heating_system.fan_watts_per_cfm
    end
    if not cooling_system.nil?
      num_speeds = clg_ap.num_speeds
    else
      num_speeds = 1
    end
    fan_cfms = []
    if not heating_system.nil?
      htg_cfm = heating_system.heating_airflow_cfm
      fan_cfms << htg_cfm
    end
    if not cooling_system.nil?
      clg_cfm = cooling_system.cooling_airflow_cfm
      clg_ap.cool_fan_speed_ratios.each do |r|
        fan_cfms << clg_cfm * r
      end
    end
    fan = create_supply_fan(model, obj_name, fan_watts_per_cfm, fan_cfms)
    if not cooling_system.nil?
      hvac_map[cooling_system.id] += disaggregate_fan_or_pump(model, fan, nil, clg_coil, nil)
    end
    if not heating_system.nil?
      hvac_map[heating_system.id] += disaggregate_fan_or_pump(model, fan, htg_coil, nil, nil)
    end

    # Unitary System
    air_loop_unitary = create_air_loop_unitary_system(model, obj_name, fan, htg_coil, clg_coil, nil, htg_cfm, clg_cfm)
    if not cooling_system.nil?
      hvac_map[cooling_system.id] << air_loop_unitary
    end
    if not heating_system.nil?
      hvac_map[heating_system.id] << air_loop_unitary
    end

    # Unitary System Performance
    if (not cooling_system.nil?) && (num_speeds > 1)
      perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
      perf.setSingleModeOperation(false)
      for speed in 1..num_speeds
        f = OpenStudio::Model::SupplyAirflowRatioField.fromCoolingRatio(clg_ap.cool_fan_speed_ratios[speed - 1])
        perf.addSupplyAirflowRatioField(f)
      end
      air_loop_unitary.setDesignSpecificationMultispeedObject(perf)
    end

    # Air Loop
    air_loop = create_air_loop(model, obj_name, air_loop_unitary, control_zone, sequential_heat_load_fracs, sequential_cool_load_fracs, [htg_cfm.to_f, clg_cfm.to_f].max)
    if not cooling_system.nil?
      hvac_map[cooling_system.id] << air_loop
    end
    if not heating_system.nil?
      hvac_map[heating_system.id] << air_loop
    end

    # HVAC Installation Quality
    apply_installation_quality(model, heating_system, cooling_system, air_loop_unitary, htg_coil, clg_coil, control_zone)
  end

  def self.apply_room_air_conditioner(model, runner, cooling_system,
                                      sequential_cool_load_fracs, control_zone,
                                      hvac_map)

    hvac_map[cooling_system.id] = []
    obj_name = Constants.ObjectNameRoomAirConditioner

    clg_ap = cooling_system.additional_properties

    # Performance curves
    cool_cap_ft_spec_si = convert_curve_biquadratic(clg_ap.cool_cap_ft_spec[0])
    cool_eir_ft_spec_si = convert_curve_biquadratic(clg_ap.cool_eir_ft_spec[0])

    roomac_cap_ft_curve = create_curve_biquadratic(model, cool_cap_ft_spec_si, 'Cool-CAP-fT', 0, 100, 0, 100)
    roomac_cap_fff_curve = create_curve_quadratic(model, clg_ap.cool_cap_fflow_spec[0], 'Cool-CAP-fFF', 0, 2, 0, 2)
    roomac_eir_ft_curve = create_curve_biquadratic(model, cool_eir_ft_spec_si, 'Cool-EIR-fT', 0, 100, 0, 100)
    roomcac_eir_fff_curve = create_curve_quadratic(model, clg_ap.cool_eir_fflow_spec[0], 'Cool-EIR-fFF', 0, 2, 0, 2)
    roomac_plf_fplr_curve = create_curve_quadratic(model, clg_ap.cool_plf_fplr_spec[0], 'Cool-PLF-fPLR', 0, 1, 0, 1)

    # Cooling Coil
    clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule, roomac_cap_ft_curve, roomac_cap_fff_curve, roomac_eir_ft_curve, roomcac_eir_fff_curve, roomac_plf_fplr_curve)
    clg_coil.setName(obj_name + ' clg coil')
    clg_coil.setRatedSensibleHeatRatio(cooling_system.cooling_shr)
    if cooling_system.cooling_efficiency_ceer.nil?
      ceer = calc_ceer_from_eer(cooling_system)
    else
      ceer = cooling_system.cooling_efficiency_ceer
    end
    clg_coil.setRatedCOP(UnitConversions.convert(ceer, 'Btu/hr', 'W'))
    clg_coil.setRatedEvaporatorFanPowerPerVolumeFlowRate(773.3)
    clg_coil.setEvaporativeCondenserEffectiveness(0.9)
    clg_coil.setMaximumOutdoorDryBulbTemperatureForCrankcaseHeaterOperation(10)
    clg_coil.setBasinHeaterSetpointTemperature(2)
    clg_coil.setRatedTotalCoolingCapacity(UnitConversions.convert(cooling_system.cooling_capacity, 'Btu/hr', 'W'))
    clg_coil.setRatedAirFlowRate(calc_rated_airflow(cooling_system.cooling_capacity, clg_ap.cool_rated_cfm_per_ton[0], 1.0))
    hvac_map[cooling_system.id] << clg_coil

    # Fan
    clg_cfm = cooling_system.cooling_airflow_cfm
    fan = create_supply_fan(model, obj_name, 0.0, [clg_cfm]) # Fan power included in EER (net COP) above
    hvac_map[cooling_system.id] += disaggregate_fan_or_pump(model, fan, nil, clg_coil, nil)

    # Heating Coil (none)
    htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOffDiscreteSchedule())
    htg_coil.setNominalCapacity(0.0)
    htg_coil.setName(obj_name + ' htg coil')

    # PTAC
    ptac = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model, model.alwaysOnDiscreteSchedule, fan, htg_coil, clg_coil)
    ptac.setName(obj_name)
    ptac.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
    ptac.setSupplyAirFlowRateDuringCoolingOperation(UnitConversions.convert(clg_cfm, 'cfm', 'm^3/s'))
    ptac.setSupplyAirFlowRateDuringHeatingOperation(0.00001)
    ptac.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(0.0)
    ptac.setOutdoorAirFlowRateDuringCoolingOperation(0.0)
    ptac.setOutdoorAirFlowRateDuringHeatingOperation(0.0)
    ptac.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(0.0)
    ptac.addToThermalZone(control_zone)
    hvac_map[cooling_system.id] << ptac

    control_zone.setSequentialCoolingFractionSchedule(ptac, get_sequential_load_schedule(model, sequential_cool_load_fracs))
    control_zone.setSequentialHeatingFractionSchedule(ptac, get_sequential_load_schedule(model, [0]))
  end

  def self.apply_evaporative_cooler(model, runner, cooling_system,
                                    sequential_cool_load_fracs, control_zone,
                                    hvac_map)

    hvac_map[cooling_system.id] = []
    obj_name = Constants.ObjectNameEvaporativeCooler

    clg_ap = cooling_system.additional_properties
    clg_cfm = cooling_system.cooling_airflow_cfm

    # Evap Cooler
    evap_cooler = OpenStudio::Model::EvaporativeCoolerDirectResearchSpecial.new(model, model.alwaysOnDiscreteSchedule)
    evap_cooler.setName(obj_name)
    evap_cooler.setCoolerEffectiveness(clg_ap.effectiveness)
    evap_cooler.setEvaporativeOperationMinimumDrybulbTemperature(0) # relax limitation to open evap cooler for any potential cooling
    evap_cooler.setEvaporativeOperationMaximumLimitWetbulbTemperature(50) # relax limitation to open evap cooler for any potential cooling
    evap_cooler.setEvaporativeOperationMaximumLimitDrybulbTemperature(50) # relax limitation to open evap cooler for any potential cooling
    evap_cooler.setPrimaryAirDesignFlowRate(UnitConversions.convert(clg_cfm, 'cfm', 'm^3/s'))
    hvac_map[cooling_system.id] << evap_cooler

    # Air Loop
    air_loop = create_air_loop(model, obj_name, evap_cooler, control_zone, [0], sequential_cool_load_fracs, clg_cfm)
    hvac_map[cooling_system.id] << air_loop

    # Fan
    fan_watts_per_cfm = [2.79 * clg_cfm**-0.29, 0.6].min # W/cfm; fit of efficacy to air flow from the CEC listed equipment
    fan = create_supply_fan(model, obj_name, fan_watts_per_cfm, [clg_cfm])
    fan.addToNode(air_loop.supplyInletNode)
    hvac_map[cooling_system.id] += disaggregate_fan_or_pump(model, fan, nil, evap_cooler, nil)

    # Outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.resetEconomizerMinimumLimitDryBulbTemperature
    oa_intake_controller.setMinimumFractionofOutdoorAirSchedule(model.alwaysOnDiscreteSchedule)
    oa_intake_controller.setMaximumOutdoorAirFlowRate(UnitConversions.convert(clg_cfm, 'cfm', 'm^3/s'))

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA System")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # air handler controls
    # setpoint follows OAT WetBulb
    evap_stpt_manager = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(model)
    evap_stpt_manager.setName('Follow OATwb')
    evap_stpt_manager.setReferenceTemperatureType('OutdoorAirWetBulb')
    evap_stpt_manager.setOffsetTemperatureDifference(0.0)
    evap_stpt_manager.addToNode(air_loop.supplyOutletNode)
  end

  def self.apply_central_air_to_air_heat_pump(model, runner, heat_pump,
                                              sequential_heat_load_fracs, sequential_cool_load_fracs,
                                              control_zone, hvac_map)

    hvac_map[heat_pump.id] = []
    obj_name = Constants.ObjectNameAirSourceHeatPump

    hp_ap = heat_pump.additional_properties

    # Cooling Coil
    clg_coil = create_dx_cooling_coil(model, obj_name, heat_pump)
    hvac_map[heat_pump.id] << clg_coil

    # Heating Coil
    htg_coil = create_dx_heating_coil(model, obj_name, heat_pump)
    hvac_map[heat_pump.id] << htg_coil

    # Supplemental Heating Coil
    htg_supp_coil = create_supp_heating_coil(model, obj_name, heat_pump)
    hvac_map[heat_pump.id] << htg_supp_coil

    # Fan
    num_speeds = hp_ap.num_speeds
    htg_cfm = heat_pump.heating_airflow_cfm
    clg_cfm = heat_pump.cooling_airflow_cfm
    fan_cfms = []
    hp_ap.heat_fan_speed_ratios.each do |r|
      fan_cfms << htg_cfm * r
    end
    hp_ap.cool_fan_speed_ratios.each do |r|
      fan_cfms << clg_cfm * r
    end
    fan = create_supply_fan(model, obj_name, heat_pump.fan_watts_per_cfm, fan_cfms)
    hvac_map[heat_pump.id] += disaggregate_fan_or_pump(model, fan, htg_coil, clg_coil, htg_supp_coil)

    # Unitary System
    air_loop_unitary = create_air_loop_unitary_system(model, obj_name, fan, htg_coil, clg_coil, htg_supp_coil, htg_cfm, clg_cfm, hp_ap.supp_max_temp)
    hvac_map[heat_pump.id] << air_loop_unitary

    # Unitary System Performance
    if num_speeds > 1
      perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
      perf.setSingleModeOperation(false)
      for speed in 1..num_speeds
        f = OpenStudio::Model::SupplyAirflowRatioField.new(hp_ap.heat_fan_speed_ratios[speed - 1], hp_ap.cool_fan_speed_ratios[speed - 1])
        perf.addSupplyAirflowRatioField(f)
      end
      air_loop_unitary.setDesignSpecificationMultispeedObject(perf)
    end

    # Air Loop
    air_loop = create_air_loop(model, obj_name, air_loop_unitary, control_zone, sequential_heat_load_fracs, sequential_cool_load_fracs, [htg_cfm, clg_cfm].max)
    hvac_map[heat_pump.id] << air_loop

    # HVAC Installation Quality
    apply_installation_quality(model, heat_pump, heat_pump, air_loop_unitary, htg_coil, clg_coil, control_zone)
  end

  def self.apply_mini_split_air_conditioner(model, runner, cooling_system,
                                            sequential_cool_load_fracs,
                                            control_zone, hvac_map)

    hvac_map[cooling_system.id] = []
    obj_name = Constants.ObjectNameMiniSplitAirConditioner

    clg_ap = cooling_system.additional_properties

    # Cooling Coil
    clg_coil = create_dx_cooling_coil(model, obj_name, cooling_system)
    hvac_map[cooling_system.id] << clg_coil

    # Fan
    num_speeds = clg_ap.num_speeds
    clg_cfm = cooling_system.cooling_airflow_cfm
    fan_cfms = []
    clg_ap.cool_fan_speed_ratios.each do |r|
      fan_cfms << clg_cfm * r
    end
    fan = create_supply_fan(model, obj_name, cooling_system.fan_watts_per_cfm, fan_cfms)
    hvac_map[cooling_system.id] += disaggregate_fan_or_pump(model, fan, nil, clg_coil, nil)

    # Unitary System
    air_loop_unitary = create_air_loop_unitary_system(model, obj_name, fan, nil, clg_coil, nil, nil, clg_cfm)
    hvac_map[cooling_system.id] << air_loop_unitary

    # Unitary System Performance
    perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
    perf.setSingleModeOperation(false)
    for i in 0..(num_speeds - 1)
      f = OpenStudio::Model::SupplyAirflowRatioField.new(1.0, clg_ap.cool_fan_speed_ratios[i])
      perf.addSupplyAirflowRatioField(f)
    end
    air_loop_unitary.setDesignSpecificationMultispeedObject(perf)

    # Air Loop
    air_loop = create_air_loop(model, obj_name, air_loop_unitary, control_zone, [0], sequential_cool_load_fracs, clg_cfm)
    hvac_map[cooling_system.id] << air_loop

    # HVAC Installation Quality
    apply_installation_quality(model, nil, cooling_system, air_loop_unitary, nil, clg_coil, control_zone)
  end

  def self.apply_mini_split_heat_pump(model, runner, heat_pump,
                                      sequential_heat_load_fracs, sequential_cool_load_fracs,
                                      control_zone, hvac_map)

    hvac_map[heat_pump.id] = []
    obj_name = Constants.ObjectNameMiniSplitHeatPump

    hp_ap = heat_pump.additional_properties

    # Cooling Coil
    clg_coil = create_dx_cooling_coil(model, obj_name, heat_pump)
    hvac_map[heat_pump.id] << clg_coil

    # Heating Coil
    htg_coil = create_dx_heating_coil(model, obj_name, heat_pump)
    hvac_map[heat_pump.id] << htg_coil

    # Supplemental Heating Coil
    htg_supp_coil = create_supp_heating_coil(model, obj_name, heat_pump)
    hvac_map[heat_pump.id] << htg_supp_coil

    # Fan
    num_speeds = hp_ap.num_speeds
    htg_cfm = heat_pump.heating_airflow_cfm
    clg_cfm = heat_pump.cooling_airflow_cfm
    fan_cfms = []
    hp_ap.heat_fan_speed_ratios.each do |r|
      fan_cfms << htg_cfm * r
    end
    hp_ap.cool_fan_speed_ratios.each do |r|
      fan_cfms << clg_cfm * r
    end
    fan = create_supply_fan(model, obj_name, heat_pump.fan_watts_per_cfm, fan_cfms)
    hvac_map[heat_pump.id] += disaggregate_fan_or_pump(model, fan, htg_coil, clg_coil, htg_supp_coil)

    # Unitary System
    air_loop_unitary = create_air_loop_unitary_system(model, obj_name, fan, htg_coil, clg_coil, htg_supp_coil, htg_cfm, clg_cfm, hp_ap.supp_max_temp)
    hvac_map[heat_pump.id] << air_loop_unitary

    # Unitary System Performance
    perf = OpenStudio::Model::UnitarySystemPerformanceMultispeed.new(model)
    perf.setSingleModeOperation(false)
    for i in 0..(num_speeds - 1)
      f = OpenStudio::Model::SupplyAirflowRatioField.new(hp_ap.heat_fan_speed_ratios[i], hp_ap.cool_fan_speed_ratios[i])
      perf.addSupplyAirflowRatioField(f)
    end
    air_loop_unitary.setDesignSpecificationMultispeedObject(perf)

    # Air Loop
    air_loop = create_air_loop(model, obj_name, air_loop_unitary, control_zone, sequential_heat_load_fracs, sequential_cool_load_fracs, [htg_cfm, clg_cfm].max)
    hvac_map[heat_pump.id] << air_loop

    # HVAC Installation Quality
    apply_installation_quality(model, heat_pump, heat_pump, air_loop_unitary, htg_coil, clg_coil, control_zone)
  end

  def self.apply_ground_to_air_heat_pump(model, runner, weather, heat_pump,
                                         sequential_heat_load_fracs, sequential_cool_load_fracs,
                                         control_zone, hvac_map)

    hvac_map[heat_pump.id] = []
    obj_name = Constants.ObjectNameGroundSourceHeatPump

    hp_ap = heat_pump.additional_properties
    htg_cfm = heat_pump.heating_airflow_cfm
    clg_cfm = heat_pump.cooling_airflow_cfm

    if hp_ap.frac_glycol == 0
      hp_ap.fluid_type = Constants.FluidWater
      runner.registerWarning("Specified #{hp_ap.fluid_type} fluid type and 0 fraction of glycol, so assuming #{Constants.FluidWater} fluid type.")
    end

    # Cooling Coil
    clg_total_cap_curve = create_curve_quad_linear(model, hp_ap.cool_cap_curve_spec[0], obj_name + ' clg total cap curve')
    clg_sens_cap_curve = create_curve_quint_linear(model, hp_ap.cool_sh_curve_spec[0], obj_name + ' clg sens cap curve')
    clg_power_curve = create_curve_quad_linear(model, hp_ap.cool_power_curve_spec[0], obj_name + ' clg power curve')
    clg_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(model, clg_total_cap_curve, clg_sens_cap_curve, clg_power_curve)
    clg_coil.setName(obj_name + ' clg coil')
    clg_coil.setRatedCoolingCoefficientofPerformance(1.0 / hp_ap.cool_rated_eirs[0])
    clg_coil.setNominalTimeforCondensateRemovaltoBegin(1000)
    clg_coil.setRatioofInitialMoistureEvaporationRateandSteadyStateLatentCapacity(1.5)
    clg_coil.setRatedAirFlowRate(UnitConversions.convert(clg_cfm, 'cfm', 'm^3/s'))
    clg_coil.setRatedWaterFlowRate(UnitConversions.convert(hp_ap.GSHP_Loop_flow, 'gal/min', 'm^3/s'))
    clg_coil.setRatedTotalCoolingCapacity(UnitConversions.convert(heat_pump.cooling_capacity, 'Btu/hr', 'W'))
    clg_coil.setRatedSensibleCoolingCapacity(UnitConversions.convert(hp_ap.cooling_capacity_sensible, 'Btu/hr', 'W'))
    hvac_map[heat_pump.id] << clg_coil

    # Heating Coil
    htg_cap_curve = create_curve_quad_linear(model, hp_ap.heat_cap_curve_spec[0], obj_name + ' htg cap curve')
    htg_power_curve = create_curve_quad_linear(model, hp_ap.heat_power_curve_spec[0], obj_name + ' htg power curve')
    htg_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(model, htg_cap_curve, htg_power_curve)
    htg_coil.setName(obj_name + ' htg coil')
    htg_coil.setRatedHeatingCoefficientofPerformance(1.0 / hp_ap.heat_rated_eirs[0])
    htg_coil.setRatedAirFlowRate(UnitConversions.convert(htg_cfm, 'cfm', 'm^3/s'))
    htg_coil.setRatedWaterFlowRate(UnitConversions.convert(hp_ap.GSHP_Loop_flow, 'gal/min', 'm^3/s'))
    htg_coil.setRatedHeatingCapacity(UnitConversions.convert(heat_pump.heating_capacity, 'Btu/hr', 'W'))
    hvac_map[heat_pump.id] << htg_coil

    # Supplemental Heating Coil
    htg_supp_coil = create_supp_heating_coil(model, obj_name, heat_pump)
    hvac_map[heat_pump.id] << htg_supp_coil

    # Ground Heat Exchanger
    ground_heat_exch_vert = OpenStudio::Model::GroundHeatExchangerVertical.new(model)
    ground_heat_exch_vert.setName(obj_name + ' exchanger')
    ground_heat_exch_vert.setBoreHoleRadius(UnitConversions.convert(hp_ap.bore_diameter / 2.0, 'in', 'm'))
    ground_heat_exch_vert.setGroundThermalConductivity(UnitConversions.convert(hp_ap.ground_conductivity, 'Btu/(hr*ft*R)', 'W/(m*K)'))
    ground_heat_exch_vert.setGroundThermalHeatCapacity(UnitConversions.convert(hp_ap.ground_conductivity / hp_ap.ground_diffusivity, 'Btu/(ft^3*F)', 'J/(m^3*K)'))
    ground_heat_exch_vert.setGroundTemperature(UnitConversions.convert(weather.data.AnnualAvgDrybulb, 'F', 'C'))
    ground_heat_exch_vert.setGroutThermalConductivity(UnitConversions.convert(hp_ap.grout_conductivity, 'Btu/(hr*ft*R)', 'W/(m*K)'))
    ground_heat_exch_vert.setPipeThermalConductivity(UnitConversions.convert(hp_ap.pipe_cond, 'Btu/(hr*ft*R)', 'W/(m*K)'))
    ground_heat_exch_vert.setPipeOutDiameter(UnitConversions.convert(hp_ap.pipe_od, 'in', 'm'))
    ground_heat_exch_vert.setUTubeDistance(UnitConversions.convert(hp_ap.shank_spacing, 'in', 'm'))
    ground_heat_exch_vert.setPipeThickness(UnitConversions.convert((hp_ap.pipe_od - hp_ap.pipe_id) / 2.0, 'in', 'm'))
    ground_heat_exch_vert.setMaximumLengthofSimulation(1)
    ground_heat_exch_vert.setGFunctionReferenceRatio(0.0005)
    ground_heat_exch_vert.setDesignFlowRate(UnitConversions.convert(hp_ap.GSHP_Loop_flow, 'gal/min', 'm^3/s'))
    ground_heat_exch_vert.setNumberofBoreHoles(hp_ap.GSHP_Bore_Holes.to_i)
    ground_heat_exch_vert.setBoreHoleLength(UnitConversions.convert(hp_ap.GSHP_Bore_Depth, 'ft', 'm'))
    ground_heat_exch_vert.removeAllGFunctions
    for i in 0..(hp_ap.GSHP_G_Functions[0].size - 1)
      ground_heat_exch_vert.addGFunction(hp_ap.GSHP_G_Functions[0][i], hp_ap.GSHP_G_Functions[1][i])
    end

    # Plant Loop
    plant_loop = OpenStudio::Model::PlantLoop.new(model)
    plant_loop.setName(obj_name + ' condenser loop')
    if hp_ap.fluid_type == Constants.FluidWater
      plant_loop.setFluidType('Water')
    else
      plant_loop.setFluidType({ Constants.FluidPropyleneGlycol => 'PropyleneGlycol', Constants.FluidEthyleneGlycol => 'EthyleneGlycol' }[hp_ap.fluid_type])
      plant_loop.setGlycolConcentration((hp_ap.frac_glycol * 100).to_i)
    end
    plant_loop.setMaximumLoopTemperature(48.88889)
    plant_loop.setMinimumLoopTemperature(UnitConversions.convert(hp_ap.design_hw, 'F', 'C'))
    plant_loop.setMinimumLoopFlowRate(0)
    plant_loop.setLoadDistributionScheme('SequentialLoad')
    plant_loop.addSupplyBranchForComponent(ground_heat_exch_vert)
    plant_loop.addDemandBranchForComponent(htg_coil)
    plant_loop.addDemandBranchForComponent(clg_coil)
    plant_loop.setMaximumLoopFlowRate(UnitConversions.convert(hp_ap.GSHP_Loop_flow, 'gal/min', 'm^3/s'))
    hvac_map[heat_pump.id] << plant_loop

    sizing_plant = plant_loop.sizingPlant
    sizing_plant.setLoopType('Condenser')
    sizing_plant.setDesignLoopExitTemperature(UnitConversions.convert(hp_ap.design_chw, 'F', 'C'))
    sizing_plant.setLoopDesignTemperatureDifference(UnitConversions.convert(hp_ap.design_delta_t, 'R', 'K'))

    setpoint_mgr_follow_ground_temp = OpenStudio::Model::SetpointManagerFollowGroundTemperature.new(model)
    setpoint_mgr_follow_ground_temp.setName(obj_name + ' condenser loop temp')
    setpoint_mgr_follow_ground_temp.setControlVariable('Temperature')
    setpoint_mgr_follow_ground_temp.setMaximumSetpointTemperature(48.88889)
    setpoint_mgr_follow_ground_temp.setMinimumSetpointTemperature(UnitConversions.convert(hp_ap.design_hw, 'F', 'C'))
    setpoint_mgr_follow_ground_temp.setReferenceGroundTemperatureObjectType('Site:GroundTemperature:Deep')
    setpoint_mgr_follow_ground_temp.addToNode(plant_loop.supplyOutletNode)

    # Pump
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setName(obj_name + ' pump')
    pump.setMotorEfficiency(0.85)
    pump.setRatedPumpHead(20000)
    pump.setFractionofMotorInefficienciestoFluidStream(0)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(1)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(0)
    pump.setMinimumFlowRate(0)
    pump.setPumpControlType('Intermittent')
    pump.addToNode(plant_loop.supplyInletNode)
    if heat_pump.cooling_capacity > 1.0
      pump_w = heat_pump.pump_watts_per_ton * UnitConversions.convert(heat_pump.cooling_capacity, 'Btu/hr', 'ton')
    else
      pump_w = heat_pump.pump_watts_per_ton * UnitConversions.convert(heat_pump.heating_capacity, 'Btu/hr', 'ton')
    end
    pump_w = [pump_w, 1.0].max # prevent error if zero
    pump.setRatedPowerConsumption(pump_w)
    pump.setRatedFlowRate(calc_pump_rated_flow_rate(0.75, pump_w, pump.ratedPumpHead))
    hvac_map[heat_pump.id] << pump
    hvac_map[heat_pump.id] += disaggregate_fan_or_pump(model, pump, htg_coil, clg_coil, htg_supp_coil)

    # Pipes
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

    # Fan
    fan = create_supply_fan(model, obj_name, heat_pump.fan_watts_per_cfm, [htg_cfm, clg_cfm])
    hvac_map[heat_pump.id] += disaggregate_fan_or_pump(model, fan, htg_coil, clg_coil, htg_supp_coil)

    # Unitary System
    air_loop_unitary = create_air_loop_unitary_system(model, obj_name, fan, htg_coil, clg_coil, htg_supp_coil, htg_cfm, clg_cfm, 40.0)
    hvac_map[heat_pump.id] << air_loop_unitary
    set_pump_power_ems_program(model, pump_w, pump, air_loop_unitary)

    if heat_pump.is_shared_system
      # Shared pump power per ANSI/RESNET/ICC 301-2019 Section 4.4.5.1 (pump runs 8760)
      # Ancillary fields do not correctly work so using ElectricEquipment object instead;
      # Revert when https://github.com/NREL/EnergyPlus/issues/8230 is fixed.
      shared_pump_w = heat_pump.shared_loop_watts / heat_pump.number_of_units_served.to_f
      # air_loop_unitary.setAncilliaryOffCycleElectricPower(shared_pump_w)
      # air_loop_unitary.setAncilliaryOnCycleElectricPower(shared_pump_w)
      equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      equip_def.setName(Constants.ObjectNameSharedPump(obj_name))
      equip = OpenStudio::Model::ElectricEquipment.new(equip_def)
      equip.setName(equip_def.name.to_s)
      equip.setSpace(control_zone.spaces[0])
      equip_def.setDesignLevel(shared_pump_w)
      equip_def.setFractionRadiant(0)
      equip_def.setFractionLatent(0)
      equip_def.setFractionLost(1)
      equip.setSchedule(model.alwaysOnDiscreteSchedule)
      equip.setEndUseSubcategory(equip_def.name.to_s)
      hvac_map[heat_pump.id] += disaggregate_fan_or_pump(model, equip, htg_coil, clg_coil, htg_supp_coil)
    end

    # Air Loop
    air_loop = create_air_loop(model, obj_name, air_loop_unitary, control_zone, sequential_heat_load_fracs, sequential_cool_load_fracs, [htg_cfm, clg_cfm].max)
    hvac_map[heat_pump.id] << air_loop

    # HVAC Installation Quality
    apply_installation_quality(model, heat_pump, heat_pump, air_loop_unitary, htg_coil, clg_coil, control_zone)
  end

  def self.apply_water_loop_to_air_heat_pump(model, runner, heat_pump,
                                             sequential_heat_load_fracs, sequential_cool_load_fracs,
                                             control_zone, hvac_map)
    if heat_pump.fraction_cool_load_served > 0
      # WLHPs connected to chillers or cooling towers should have already been converted to
      # central air conditioners
      fail 'WLHP model should only be called for central boilers.'
    end

    hvac_map[heat_pump.id] = []
    obj_name = Constants.ObjectNameWaterLoopHeatPump

    hp_ap = heat_pump.additional_properties
    htg_cfm = heat_pump.heating_airflow_cfm

    # Cooling Coil (none)
    clg_coil = nil

    # Heating Coil (model w/ constant efficiency)
    constant_biquadratic = create_curve_biquadratic_constant(model)
    constant_quadratic = create_curve_quadratic_constant(model)
    htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule, constant_biquadratic, constant_quadratic, constant_biquadratic, constant_quadratic, constant_quadratic)
    htg_coil.setName(obj_name + ' htg coil')
    htg_coil.setRatedCOP(heat_pump.heating_efficiency_cop)
    htg_coil.setDefrostTimePeriodFraction(0.00001) # Disable defrost; avoid E+ warning w/ value of zero
    htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(UnitConversions.convert(hp_ap.hp_min_temp, 'F', 'C'))
    htg_coil.setRatedTotalHeatingCapacity(UnitConversions.convert(heat_pump.heating_capacity, 'Btu/hr', 'W'))
    htg_coil.setRatedAirFlowRate(htg_cfm)
    hvac_map[heat_pump.id] << htg_coil

    # Supplemental Heating Coil
    htg_supp_coil = create_supp_heating_coil(model, obj_name, heat_pump)
    hvac_map[heat_pump.id] << htg_supp_coil

    # Fan
    fan_power_installed = 0.0 # Use provided net COP
    fan = create_supply_fan(model, obj_name, fan_power_installed, [htg_cfm])
    hvac_map[heat_pump.id] += disaggregate_fan_or_pump(model, fan, htg_coil, clg_coil, htg_supp_coil)

    # Unitary System
    air_loop_unitary = create_air_loop_unitary_system(model, obj_name, fan, htg_coil, clg_coil, htg_supp_coil, htg_cfm, nil, hp_ap.supp_max_temp)
    hvac_map[heat_pump.id] << air_loop_unitary

    # Air Loop
    air_loop = create_air_loop(model, obj_name, air_loop_unitary, control_zone, sequential_heat_load_fracs, sequential_cool_load_fracs, htg_cfm)
    hvac_map[heat_pump.id] << air_loop
  end

  def self.apply_boiler(model, runner, heating_system,
                        sequential_heat_load_fracs, control_zone,
                        hvac_map)

    hvac_map[heating_system.id] = []
    obj_name = Constants.ObjectNameBoiler
    is_condensing = false # FUTURE: Expose as input; default based on AFUE
    oat_reset_enabled = false
    oat_high = nil
    oat_low = nil
    oat_hwst_high = nil
    oat_hwst_low = nil
    design_temp = 180.0 # deg-F

    if oat_reset_enabled
      if oat_high.nil? || oat_low.nil? || oat_hwst_low.nil? || oat_hwst_high.nil?
        runner.registerWarning('Boiler outdoor air temperature (OAT) reset is enabled but no setpoints were specified so OAT reset is being disabled.')
        oat_reset_enabled = false
      end
    end

    # Plant Loop
    plant_loop = OpenStudio::Model::PlantLoop.new(model)
    plant_loop.setName(obj_name + ' hydronic heat loop')
    plant_loop.setFluidType('Water')
    plant_loop.setMaximumLoopTemperature(100)
    plant_loop.setMinimumLoopTemperature(0)
    plant_loop.setMinimumLoopFlowRate(0)
    plant_loop.autocalculatePlantLoopVolume()
    hvac_map[heating_system.id] << plant_loop

    loop_sizing = plant_loop.sizingPlant
    loop_sizing.setLoopType('Heating')
    loop_sizing.setDesignLoopExitTemperature(UnitConversions.convert(design_temp - 32.0, 'R', 'K'))
    loop_sizing.setLoopDesignTemperatureDifference(UnitConversions.convert(20.0, 'R', 'K'))

    # Pump
    pump_w = heating_system.electric_auxiliary_energy / 2.08
    pump_w = [pump_w, 1.0].max # prevent error if zero
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setName(obj_name + ' hydronic pump')
    pump.setRatedPowerConsumption(pump_w)
    pump.setMotorEfficiency(0.85)
    pump.setRatedPumpHead(20000)
    pump.setRatedFlowRate(calc_pump_rated_flow_rate(0.75, pump_w, pump.ratedPumpHead))
    pump.setFractionofMotorInefficienciestoFluidStream(0)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(1)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(0)
    pump.setPumpControlType('Intermittent')
    pump.addToNode(plant_loop.supplyInletNode)
    hvac_map[heating_system.id] << pump

    # Boiler
    boiler = OpenStudio::Model::BoilerHotWater.new(model)
    boiler.setName(obj_name)
    boiler.setFuelType(EPlus.fuel_type(heating_system.heating_system_fuel))
    if is_condensing
      # Convert Rated Efficiency at 80F and 1.0PLR where the performance curves are derived from to Design condition as input
      boiler_RatedHWRT = UnitConversions.convert(80.0 - 32.0, 'R', 'K')
      plr_Rated = 1.0
      plr_Design = 1.0
      boiler_DesignHWRT = UnitConversions.convert(design_temp - 20.0 - 32.0, 'R', 'K')
      # Efficiency curves are normalized using 80F return water temperature, at 0.254PLR
      condBlr_TE_Coeff = [1.058343061, 0.052650153, 0.0087272, 0.001742217, 0.00000333715, 0.000513723]
      boilerEff_Norm = heating_system.heating_efficiency_afue / (condBlr_TE_Coeff[0] - condBlr_TE_Coeff[1] * plr_Rated - condBlr_TE_Coeff[2] * plr_Rated**2 - condBlr_TE_Coeff[3] * boiler_RatedHWRT + condBlr_TE_Coeff[4] * boiler_RatedHWRT**2 + condBlr_TE_Coeff[5] * boiler_RatedHWRT * plr_Rated)
      boilerEff_Design = boilerEff_Norm * (condBlr_TE_Coeff[0] - condBlr_TE_Coeff[1] * plr_Design - condBlr_TE_Coeff[2] * plr_Design**2 - condBlr_TE_Coeff[3] * boiler_DesignHWRT + condBlr_TE_Coeff[4] * boiler_DesignHWRT**2 + condBlr_TE_Coeff[5] * boiler_DesignHWRT * plr_Design)
      boiler.setNominalThermalEfficiency(boilerEff_Design)
      boiler.setEfficiencyCurveTemperatureEvaluationVariable('EnteringBoiler')
      boiler_eff_curve = create_curve_biquadratic(model, [1.058343061, -0.052650153, -0.0087272, -0.001742217, 0.00000333715, 0.000513723], 'CondensingBoilerEff', 0.2, 1.0, 30.0, 85.0)
    else
      boiler.setNominalThermalEfficiency(heating_system.heating_efficiency_afue)
      boiler.setEfficiencyCurveTemperatureEvaluationVariable('LeavingBoiler')
      boiler_eff_curve = create_curve_bicubic(model, [1.111720116, 0.078614078, -0.400425756, 0.0, -0.000156783, 0.009384599, 0.234257955, 1.32927e-06, -0.004446701, -1.22498e-05], 'NonCondensingBoilerEff', 0.1, 1.0, 20.0, 80.0)
    end
    boiler.setNormalizedBoilerEfficiencyCurve(boiler_eff_curve)
    boiler.setMinimumPartLoadRatio(0.0)
    boiler.setMaximumPartLoadRatio(1.0)
    boiler.setBoilerFlowMode('LeavingSetpointModulated')
    boiler.setOptimumPartLoadRatio(1.0)
    boiler.setWaterOutletUpperTemperatureLimit(99.9)
    boiler.setParasiticElectricLoad(0)
    boiler.setNominalCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
    plant_loop.addSupplyBranchForComponent(boiler)
    hvac_map[heating_system.id] << boiler
    set_pump_power_ems_program(model, pump_w, pump, boiler)

    if is_condensing && oat_reset_enabled
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
    setpoint_manager_scheduled.addToNode(plant_loop.supplyOutletNode)

    pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    plant_loop.addSupplyBranchForComponent(pipe_supply_bypass)
    pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_supply_outlet.addToNode(plant_loop.supplyOutletNode)
    pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    plant_loop.addDemandBranchForComponent(pipe_demand_bypass)
    pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_demand_inlet.addToNode(plant_loop.demandInletNode)
    pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_demand_outlet.addToNode(plant_loop.demandOutletNode)

    bb_ua = UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W') / UnitConversions.convert(UnitConversions.convert(loop_sizing.designLoopExitTemperature, 'C', 'F') - 10.0 - 95.0, 'R', 'K') * 3.0 # W/K
    max_water_flow = UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W') / UnitConversions.convert(20.0, 'R', 'K') / 4.186 / 998.2 / 1000.0 * 2.0 # m^3/s
    fan_cfm = 400.0 * UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'ton') # CFM; assumes 400 cfm/ton

    if heating_system.distribution_system.air_type.to_s == HPXML::AirTypeFanCoil
      # Fan
      fan = create_supply_fan(model, obj_name, 0.0, [fan_cfm]) # fan energy included in above pump via Electric Auxiliary Energy (EAE)

      # Heating Coil
      htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
      htg_coil.setRatedCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
      htg_coil.setUFactorTimesAreaValue(bb_ua)
      htg_coil.setMaximumWaterFlowRate(max_water_flow)
      htg_coil.setPerformanceInputMethod('NominalCapacity')
      htg_coil.setName(obj_name + ' htg coil')
      plant_loop.addDemandBranchForComponent(htg_coil)

      # Cooling Coil (always off)
      clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOffDiscreteSchedule)
      clg_coil.setName(obj_name + ' clg coil')
      clg_coil.setDesignWaterFlowRate(0.0022)
      clg_coil.setDesignAirFlowRate(1.45)
      clg_coil.setDesignInletWaterTemperature(6.1)
      clg_coil.setDesignInletAirTemperature(25.0)
      clg_coil.setDesignOutletAirTemperature(10.0)
      clg_coil.setDesignInletAirHumidityRatio(0.012)
      clg_coil.setDesignOutletAirHumidityRatio(0.008)
      plant_loop.addDemandBranchForComponent(clg_coil)

      # Fan Coil
      zone_hvac = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model, model.alwaysOnDiscreteSchedule, fan, clg_coil, htg_coil)
      zone_hvac.setCapacityControlMethod('CyclingFan')
      zone_hvac.setName(obj_name + ' fan coil')
      zone_hvac.setMaximumSupplyAirTemperatureInHeatingMode(UnitConversions.convert(120.0, 'F', 'C'))
      zone_hvac.setHeatingConvergenceTolerance(0.001)
      zone_hvac.setMinimumSupplyAirTemperatureInCoolingMode(UnitConversions.convert(55.0, 'F', 'C'))
      zone_hvac.setMaximumColdWaterFlowRate(0.0)
      zone_hvac.setCoolingConvergenceTolerance(0.001)
      zone_hvac.setMaximumOutdoorAirFlowRate(0.0)
      zone_hvac.setMaximumSupplyAirFlowRate(UnitConversions.convert(fan_cfm, 'cfm', 'm^3/s'))
      zone_hvac.setMaximumHotWaterFlowRate(max_water_flow)
      zone_hvac.addToThermalZone(control_zone)
      hvac_map[heating_system.id] << zone_hvac
      hvac_map[heating_system.id] += disaggregate_fan_or_pump(model, pump, zone_hvac, nil, nil)
    else
      # Heating Coil
      htg_coil = OpenStudio::Model::CoilHeatingWaterBaseboard.new(model)
      htg_coil.setName(obj_name + ' htg coil')
      htg_coil.setConvergenceTolerance(0.001)
      htg_coil.setHeatingDesignCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
      htg_coil.setUFactorTimesAreaValue(bb_ua)
      htg_coil.setMaximumWaterFlowRate(max_water_flow)
      htg_coil.setHeatingDesignCapacityMethod('HeatingDesignCapacity')
      plant_loop.addDemandBranchForComponent(htg_coil)
      hvac_map[heating_system.id] << htg_coil

      # Baseboard
      zone_hvac = OpenStudio::Model::ZoneHVACBaseboardConvectiveWater.new(model, model.alwaysOnDiscreteSchedule, htg_coil)
      zone_hvac.setName(obj_name + ' baseboard')
      zone_hvac.addToThermalZone(control_zone)
      hvac_map[heating_system.id] << zone_hvac
      hvac_map[heating_system.id] += disaggregate_fan_or_pump(model, pump, zone_hvac, nil, nil)
    end

    control_zone.setSequentialHeatingFractionSchedule(zone_hvac, get_sequential_load_schedule(model, sequential_heat_load_fracs))
    control_zone.setSequentialCoolingFractionSchedule(zone_hvac, get_sequential_load_schedule(model, [0]))
  end

  def self.apply_electric_baseboard(model, runner, heating_system,
                                    sequential_heat_load_fracs, control_zone,
                                    hvac_map)

    hvac_map[heating_system.id] = []
    obj_name = Constants.ObjectNameElectricBaseboard

    # Baseboard
    zone_hvac = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
    zone_hvac.setName(obj_name)
    zone_hvac.setEfficiency(heating_system.heating_efficiency_percent)
    zone_hvac.setNominalCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
    zone_hvac.addToThermalZone(control_zone)
    hvac_map[heating_system.id] << zone_hvac

    control_zone.setSequentialHeatingFractionSchedule(zone_hvac, get_sequential_load_schedule(model, sequential_heat_load_fracs))
    control_zone.setSequentialCoolingFractionSchedule(zone_hvac, get_sequential_load_schedule(model, [0]))
  end

  def self.apply_unit_heater(model, runner, heating_system,
                             sequential_heat_load_fracs, control_zone,
                             hvac_map)

    hvac_map[heating_system.id] = []
    obj_name = Constants.ObjectNameUnitHeater

    htg_ap = heating_system.additional_properties

    # Heating Coil
    efficiency = heating_system.heating_efficiency_afue
    efficiency = heating_system.heating_efficiency_percent if efficiency.nil?
    if heating_system.heating_system_fuel == HPXML::FuelTypeElectricity
      htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model)
      htg_coil.setEfficiency(efficiency)
    else
      htg_coil = OpenStudio::Model::CoilHeatingGas.new(model)
      htg_coil.setGasBurnerEfficiency(efficiency)
      htg_coil.setParasiticElectricLoad(0.0)
      htg_coil.setParasiticGasLoad(0)
      htg_coil.setFuelType(EPlus.fuel_type(heating_system.heating_system_fuel))
    end
    htg_coil.setNominalCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
    htg_coil.setName(obj_name + ' htg coil')
    hvac_map[heating_system.id] << htg_coil

    # Fan
    htg_cfm = heating_system.heating_airflow_cfm
    fan_watts_per_cfm = heating_system.fan_watts / htg_cfm
    fan = create_supply_fan(model, obj_name, fan_watts_per_cfm, [htg_cfm])
    hvac_map[heating_system.id] += disaggregate_fan_or_pump(model, fan, htg_coil, nil, nil)

    # Unitary System
    unitary_system = create_air_loop_unitary_system(model, obj_name, fan, htg_coil, nil, nil, htg_cfm, nil)
    unitary_system.setControllingZoneorThermostatLocation(control_zone)
    unitary_system.addToThermalZone(control_zone)
    hvac_map[heating_system.id] << unitary_system

    control_zone.setSequentialHeatingFractionSchedule(unitary_system, get_sequential_load_schedule(model, sequential_heat_load_fracs))
    control_zone.setSequentialCoolingFractionSchedule(unitary_system, get_sequential_load_schedule(model, [0]))
  end

  def self.apply_ideal_air_loads(model, runner, obj_name, sequential_cool_load_fracs,
                                 sequential_heat_load_fracs, control_zone)

    # Ideal Air System
    ideal_air = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
    ideal_air.setName(obj_name)
    ideal_air.setMaximumHeatingSupplyAirTemperature(50)
    ideal_air.setMinimumCoolingSupplyAirTemperature(10)
    ideal_air.setMaximumHeatingSupplyAirHumidityRatio(0.015)
    ideal_air.setMinimumCoolingSupplyAirHumidityRatio(0.01)
    if sequential_heat_load_fracs.sum > 0
      ideal_air.setHeatingLimit('NoLimit')
    else
      ideal_air.setHeatingLimit('LimitCapacity')
      ideal_air.setMaximumSensibleHeatingCapacity(0)
    end
    if sequential_cool_load_fracs.sum > 0
      ideal_air.setCoolingLimit('NoLimit')
    else
      ideal_air.setCoolingLimit('LimitCapacity')
      ideal_air.setMaximumTotalCoolingCapacity(0)
    end
    ideal_air.setDehumidificationControlType('None')
    ideal_air.setHumidificationControlType('None')
    ideal_air.addToThermalZone(control_zone)

    control_zone.setSequentialCoolingFractionSchedule(ideal_air, get_sequential_load_schedule(model, sequential_cool_load_fracs))
    control_zone.setSequentialHeatingFractionSchedule(ideal_air, get_sequential_load_schedule(model, sequential_heat_load_fracs))
  end

  def self.apply_dehumidifiers(model, runner, dehumidifiers, living_space, hvac_map)
    dehumidifier_id = dehumidifiers[0].id # Syncs with SimulationOutputReport, which only looks at first dehumidifier ID
    hvac_map[dehumidifier_id] = []

    if dehumidifiers.map { |d| d.rh_setpoint }.uniq.size > 1
      fail 'All dehumidifiers must have the same setpoint but multiple setpoints were specified.'
    end

    # Dehumidifier coefficients
    # Generic model coefficients from Winkler, Christensen, and Tomerlin (2011)
    w_coeff = [-1.162525707, 0.02271469, -0.000113208, 0.021110538, -0.0000693034, 0.000378843]
    ef_coeff = [-1.902154518, 0.063466565, -0.000622839, 0.039540407, -0.000125637, -0.000176722]
    pl_coeff = [0.90, 0.10, 0.0]

    dehumidifiers.each do |d|
      next unless d.energy_factor.nil?

      # shift inputs tested under IEF test conditions to those under EF test conditions with performance curves
      d.energy_factor, d.capacity = apply_dehumidifier_ief_to_ef_inputs(d.type, w_coeff, ef_coeff, d.integrated_energy_factor, d.capacity)
    end

    total_capacity = dehumidifiers.map { |d| d.capacity }.sum
    avg_energy_factor = dehumidifiers.map { |d| d.energy_factor * d.capacity }.sum / total_capacity
    total_fraction_served = dehumidifiers.map { |d| d.fraction_served }.sum

    control_zone = living_space.thermalZone.get
    obj_name = Constants.ObjectNameDehumidifier

    rh_setpoint = dehumidifiers[0].rh_setpoint * 100.0 # (EnergyPlus uses 60 for 60% RH)
    relative_humidity_setpoint_sch = OpenStudio::Model::ScheduleConstant.new(model)
    relative_humidity_setpoint_sch.setName(Constants.ObjectNameRelativeHumiditySetpoint)
    relative_humidity_setpoint_sch.setValue(rh_setpoint)

    capacity_curve = create_curve_biquadratic(model, w_coeff, 'DXDH-CAP-fT', -100, 100, -100, 100)
    energy_factor_curve = create_curve_biquadratic(model, ef_coeff, 'DXDH-EF-fT', -100, 100, -100, 100)
    part_load_frac_curve = create_curve_quadratic(model, pl_coeff, 'DXDH-PLF-fPLR', 0, 1, 0.7, 1)

    # Calculate air flow rate by assuming 2.75 cfm/pint/day (based on experimental test data)
    air_flow_rate = 2.75 * total_capacity

    # Humidity Setpoint
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
    humidistat.setName(obj_name + ' humidistat')
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(relative_humidity_setpoint_sch)
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(relative_humidity_setpoint_sch)
    control_zone.setZoneControlHumidistat(humidistat)

    # Dehumidifier
    zone_hvac = OpenStudio::Model::ZoneHVACDehumidifierDX.new(model, capacity_curve, energy_factor_curve, part_load_frac_curve)
    zone_hvac.setName(obj_name)
    zone_hvac.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    zone_hvac.setRatedWaterRemoval(UnitConversions.convert(total_capacity, 'pint', 'L'))
    zone_hvac.setRatedEnergyFactor(avg_energy_factor / total_fraction_served)
    zone_hvac.setRatedAirFlowRate(UnitConversions.convert(air_flow_rate, 'cfm', 'm^3/s'))
    zone_hvac.setMinimumDryBulbTemperatureforDehumidifierOperation(10)
    zone_hvac.setMaximumDryBulbTemperatureforDehumidifierOperation(40)

    zone_hvac.addToThermalZone(control_zone)

    hvac_map[dehumidifier_id] << zone_hvac
    if total_fraction_served < 1.0
      adjust_dehumidifier_load_EMS(total_fraction_served, zone_hvac, model, living_space)
    end
  end

  def self.apply_ceiling_fans(model, runner, weather, ceiling_fan, living_space, schedules_file)
    obj_name = Constants.ObjectNameCeilingFan
    monthly_sch = Schedule.CeilingFanMonthlyMultipliers(weather: weather).split(',').map { |i| i.to_f }
    medium_cfm = 3000.0
    weekday_sch = Schedule.CeilingFanWeekdayFractions.split(',').map { |i| i.to_f }
    weekend_sch = Schedule.CeilingFanWeekendFractions.split(',').map { |i| i.to_f }
    hrs_per_day = weekday_sch.sum(0.0)
    cfm_per_w = ceiling_fan.efficiency
    quantity = ceiling_fan.quantity
    annual_kwh = UnitConversions.convert(quantity * medium_cfm / cfm_per_w * hrs_per_day * 365.0, 'Wh', 'kWh')
    annual_kwh *= monthly_sch.sum(0.0) / 12.0

    ceiling_fan_sch = MonthWeekdayWeekendSchedule.new(model, obj_name + ' schedule', weekday_sch, weekend_sch, monthly_sch, Constants.ScheduleTypeLimitsFraction)

    if not schedules_file.nil?
      space_design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: 'ceiling_fan', annual_kwh: annual_kwh)
      ceiling_fan_sch = schedules_file.create_schedule_file(col_name: 'ceiling_fan')
    else
      space_design_level = ceiling_fan_sch.calcDesignLevelFromDailykWh(annual_kwh / 365.0)
      ceiling_fan_sch = ceiling_fan_sch.schedule
    end

    equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    equip_def.setName(obj_name)
    equip = OpenStudio::Model::ElectricEquipment.new(equip_def)
    equip.setName(equip_def.name.to_s)
    equip.setSpace(living_space)
    equip_def.setDesignLevel(space_design_level)
    equip_def.setFractionRadiant(0.558)
    equip_def.setFractionLatent(0)
    equip_def.setFractionLost(0)
    equip.setEndUseSubcategory(obj_name)
    equip.setSchedule(ceiling_fan_sch)
  end

  def self.apply_setpoints(model, runner, weather, hvac_control, living_zone, has_ceiling_fan, heating_days, cooling_days)
    num_days = Schedule.get_num_days_in_year(model)

    if hvac_control.weekday_heating_setpoints.nil? || hvac_control.weekend_heating_setpoints.nil?
      # Base heating setpoint
      htg_setpoint = hvac_control.heating_setpoint_temp
      htg_weekday_setpoints = [[htg_setpoint] * 24] * num_days

      # Apply heating setback?
      htg_setback = hvac_control.heating_setback_temp
      if not htg_setback.nil?
        htg_setback_hrs_per_week = hvac_control.heating_setback_hours_per_week
        htg_setback_start_hr = hvac_control.heating_setback_start_hour
        for d in 1..num_days
          for hr in htg_setback_start_hr..htg_setback_start_hr + Integer(htg_setback_hrs_per_week / 7.0) - 1
            htg_weekday_setpoints[d - 1][hr % 24] = htg_setback
          end
        end
      end
      htg_weekend_setpoints = htg_weekday_setpoints.dup
    else
      # 24-hr weekday/weekend heating setpoint schedules
      htg_weekday_setpoints = hvac_control.weekday_heating_setpoints.split(',').map { |i| Float(i) }
      htg_weekday_setpoints = [htg_weekday_setpoints] * num_days

      htg_weekend_setpoints = hvac_control.weekend_heating_setpoints.split(',').map { |i| Float(i) }
      htg_weekend_setpoints = [htg_weekend_setpoints] * num_days
    end

    if hvac_control.weekday_cooling_setpoints.nil? || hvac_control.weekend_cooling_setpoints.nil?
      # Base cooling setpoint
      clg_setpoint = hvac_control.cooling_setpoint_temp
      clg_weekday_setpoints = [[clg_setpoint] * 24] * num_days

      # Apply cooling setup?
      clg_setup = hvac_control.cooling_setup_temp
      if not clg_setup.nil?
        clg_setup_hrs_per_week = hvac_control.cooling_setup_hours_per_week
        clg_setup_start_hr = hvac_control.cooling_setup_start_hour
        for d in 1..num_days
          for hr in clg_setup_start_hr..clg_setup_start_hr + Integer(clg_setup_hrs_per_week / 7.0) - 1
            clg_weekday_setpoints[d - 1][hr % 24] = clg_setup
          end
        end
      end
      clg_weekend_setpoints = clg_weekday_setpoints.dup
    else
      # 24-hr weekday/weekend cooling setpoint schedules
      clg_weekday_setpoints = hvac_control.weekday_cooling_setpoints.split(',').map { |i| Float(i) }
      clg_weekday_setpoints = [clg_weekday_setpoints] * num_days

      clg_weekend_setpoints = hvac_control.weekend_cooling_setpoints.split(',').map { |i| Float(i) }
      clg_weekend_setpoints = [clg_weekend_setpoints] * num_days
    end

    # Apply cooling setpoint offset due to ceiling fan?
    if has_ceiling_fan
      clg_ceiling_fan_offset = hvac_control.ceiling_fan_cooling_setpoint_temp_offset
      if not clg_ceiling_fan_offset.nil?
        months = get_default_ceiling_fan_months(weather)
        Schedule.months_to_days(model, months).each_with_index do |operation, d|
          next if operation != 1

          clg_weekday_setpoints[d] = [clg_weekday_setpoints[d], Array.new(24, clg_ceiling_fan_offset)].transpose.map { |i| i.reduce(:+) }
          clg_weekend_setpoints[d] = [clg_weekend_setpoints[d], Array.new(24, clg_ceiling_fan_offset)].transpose.map { |i| i.reduce(:+) }
        end
      end
    end

    # Create setpoint schedules
    (0..(num_days - 1)).to_a.each do |i|
      if (heating_days[i] == 1) && (cooling_days[i] == 1) # overlap seasons
        htg_wkdy = htg_weekday_setpoints[i].zip(clg_weekday_setpoints[i]).map { |h, c| c < h ? (h + c) / 2.0 : h }
        htg_wked = htg_weekend_setpoints[i].zip(clg_weekend_setpoints[i]).map { |h, c| c < h ? (h + c) / 2.0 : h }
        clg_wkdy = htg_weekday_setpoints[i].zip(clg_weekday_setpoints[i]).map { |h, c| c < h ? (h + c) / 2.0 : c }
        clg_wked = htg_weekend_setpoints[i].zip(clg_weekend_setpoints[i]).map { |h, c| c < h ? (h + c) / 2.0 : c }
      elsif heating_days[i] == 1 # heating only seasons; cooling has minimum of heating
        htg_wkdy = htg_weekday_setpoints[i].zip(clg_weekday_setpoints[i]).map { |h, c| c < h ? h : h }
        htg_wked = htg_weekend_setpoints[i].zip(clg_weekend_setpoints[i]).map { |h, c| c < h ? h : h }
        clg_wkdy = htg_weekday_setpoints[i].zip(clg_weekday_setpoints[i]).map { |h, c| c < h ? h : c }
        clg_wked = htg_weekend_setpoints[i].zip(clg_weekend_setpoints[i]).map { |h, c| c < h ? h : c }
      elsif cooling_days[i] == 1 # cooling only seasons; heating has maximum of cooling
        htg_wkdy = htg_weekday_setpoints[i].zip(clg_weekday_setpoints[i]).map { |h, c| c < h ? c : h }
        htg_wked = htg_weekend_setpoints[i].zip(clg_weekend_setpoints[i]).map { |h, c| c < h ? c : h }
        clg_wkdy = htg_weekday_setpoints[i].zip(clg_weekday_setpoints[i]).map { |h, c| c < h ? c : c }
        clg_wked = htg_weekend_setpoints[i].zip(clg_weekend_setpoints[i]).map { |h, c| c < h ? c : c }
      else
        fail 'HeatingSeason and CoolingSeason, when combined, must span the entire year.'
      end
      htg_weekday_setpoints[i] = htg_wkdy
      htg_weekend_setpoints[i] = htg_wked
      clg_weekday_setpoints[i] = clg_wkdy
      clg_weekend_setpoints[i] = clg_wked
    end
    htg_weekday_setpoints = htg_weekday_setpoints.map { |i| i.map { |j| UnitConversions.convert(j, 'F', 'C') } }
    htg_weekend_setpoints = htg_weekend_setpoints.map { |i| i.map { |j| UnitConversions.convert(j, 'F', 'C') } }
    clg_weekday_setpoints = clg_weekday_setpoints.map { |i| i.map { |j| UnitConversions.convert(j, 'F', 'C') } }
    clg_weekend_setpoints = clg_weekend_setpoints.map { |i| i.map { |j| UnitConversions.convert(j, 'F', 'C') } }
    heating_setpoint = HourlyByDaySchedule.new(model, Constants.ObjectNameHeatingSetpoint, htg_weekday_setpoints, htg_weekend_setpoints, nil, false)
    cooling_setpoint = HourlyByDaySchedule.new(model, Constants.ObjectNameCoolingSetpoint, clg_weekday_setpoints, clg_weekend_setpoints, nil, false)

    # Set the setpoint schedules
    thermostat_setpoint = living_zone.thermostatSetpointDualSetpoint
    thermostat_setpoint = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
    thermostat_setpoint.setName("#{living_zone.name} temperature setpoint")
    thermostat_setpoint.setHeatingSetpointTemperatureSchedule(heating_setpoint.schedule)
    thermostat_setpoint.setCoolingSetpointTemperatureSchedule(cooling_setpoint.schedule)
    living_zone.setThermostatSetpointDualSetpoint(thermostat_setpoint)
  end

  def self.get_default_heating_setpoint(control_type)
    # Per ANSI/RESNET/ICC 301
    htg_sp = 68 # F
    htg_setback_sp = nil
    htg_setback_hrs_per_week = nil
    htg_setback_start_hr = nil
    if control_type == HPXML::HVACControlTypeProgrammable
      htg_setback_sp = 66 # F
      htg_setback_hrs_per_week = 7 * 7 # 11 p.m. to 5:59 a.m., 7 days a week
      htg_setback_start_hr = 23 # 11 p.m.
    elsif control_type != HPXML::HVACControlTypeManual
      fail "Unexpected control type #{control_type}."
    end
    return htg_sp, htg_setback_sp, htg_setback_hrs_per_week, htg_setback_start_hr
  end

  def self.get_default_cooling_setpoint(control_type)
    # Per ANSI/RESNET/ICC 301
    clg_sp = 78 # F
    clg_setup_sp = nil
    clg_setup_hrs_per_week = nil
    clg_setup_start_hr = nil
    if control_type == HPXML::HVACControlTypeProgrammable
      clg_setup_sp = 80 # F
      clg_setup_hrs_per_week = 6 * 7 # 9 a.m. to 2:59 p.m., 7 days a week
      clg_setup_start_hr = 9 # 9 a.m.
    elsif control_type != HPXML::HVACControlTypeManual
      fail "Unexpected control type #{control_type}."
    end
    return clg_sp, clg_setup_sp, clg_setup_hrs_per_week, clg_setup_start_hr
  end

  def self.set_cool_curves_ashp(heat_pump)
    hp_ap = heat_pump.additional_properties
    if hp_ap.num_speeds == 1
      # From "Improved Modeling of Residential Air Conditioners and Heat Pumps for Energy Calculations", Cutler at al
      # https://www.nrel.gov/docs/fy13osti/56354.pdf
      hp_ap.cool_rated_airflow_rate = 394.2 # cfm/ton of rated capacity
      hp_ap.cool_capacity_ratios = [1.0]
      hp_ap.cool_fan_speed_ratios = [1.0]
      hp_ap.cool_rated_shrs_net = [heat_pump.cooling_shr]
      hp_ap.cool_cap_ft_spec = [[3.68637657, -0.098352478, 0.000956357, 0.005838141, -0.0000127, -0.000131702]]
      hp_ap.cool_eir_ft_spec = [[-3.437356399, 0.136656369, -0.001049231, -0.0079378, 0.000185435, -0.0001441]]
      # Single stage systems have PSC or constant torque ECM blowers, so the airflow rate is affected by the static pressure losses.
      hp_ap.cool_cap_fflow_spec = [[0.718664047, 0.41797409, -0.136638137]]
      hp_ap.cool_eir_fflow_spec = [[1.143487507, -0.13943972, -0.004047787]]
      hp_ap.cool_eers = [calc_eer_cooling_1speed(heat_pump.cooling_efficiency_seer, hp_ap.cool_c_d, hp_ap.fan_power_rated, hp_ap.cool_eir_ft_spec)]
    elsif hp_ap.num_speeds == 2
      # From "Improved Modeling of Residential Air Conditioners and Heat Pumps for Energy Calculations", Cutler at al
      # https://www.nrel.gov/docs/fy13osti/56354.pdf
      hp_ap.cool_rated_airflow_rate = 344.1 # cfm/ton
      hp_ap.cool_capacity_ratios = [0.72, 1.0]
      hp_ap.cool_fan_speed_ratios = [0.86, 1.0]
      hp_ap.cool_rated_shrs_net = [heat_pump.cooling_shr - 0.014, heat_pump.cooling_shr]
      hp_ap.cool_cap_ft_spec = [[3.998418659, -0.108728222, 0.001056818, 0.007512314, -0.0000139, -0.000164716],
                                [3.466810106, -0.091476056, 0.000901205, 0.004163355, -0.00000919, -0.000110829]]
      hp_ap.cool_eir_ft_spec = [[-4.282911381, 0.181023691, -0.001357391, -0.026310378, 0.000333282, -0.000197405],
                                [-3.557757517, 0.112737397, -0.000731381, 0.013184877, 0.000132645, -0.000338716]]
      # Most two stage systems have PSC or constant torque ECM blowers, so the airflow rate is affected by the static pressure losses.
      hp_ap.cool_cap_fflow_spec = [[0.655239515, 0.511655216, -0.166894731],
                                   [0.618281092, 0.569060264, -0.187341356]]
      hp_ap.cool_eir_fflow_spec = [[1.639108268, -0.998953996, 0.359845728],
                                   [1.570774717, -0.914152018, 0.343377302]]
      hp_ap.cool_eers = calc_eers_cooling_2speed(heat_pump.cooling_efficiency_seer, hp_ap.cool_c_d, hp_ap.cool_capacity_ratios, hp_ap.cool_fan_speed_ratios, hp_ap.fan_power_rated, hp_ap.cool_eir_ft_spec, hp_ap.cool_cap_ft_spec)
    elsif hp_ap.num_speeds == 4
      # From Carrier heat pump lab testing
      hp_ap.cool_rated_airflow_rate = 411.0 # cfm/ton
      hp_ap.cool_capacity_ratios = [0.36, 0.51, 0.67, 1.0]
      hp_ap.cool_fan_speed_ratios = [0.42, 0.54, 0.68, 1.0]
      hp_ap.cool_rated_shrs_net = [1.115, 1.026, 1.013, 1.0].map { |mult| heat_pump.cooling_shr * mult }
      hp_ap.cool_cap_coeff_perf_map = [[1.6516044444444447, 0.0698916049382716, -0.0005546296296296296, -0.08870160493827162, 0.0004135802469135802, 0.00029077160493827157],
                                       [-6.84948049382716, 0.26946, -0.0019413580246913577, -0.03281469135802469, 0.00015694444444444442, 3.32716049382716e-05],
                                       [-4.53543086419753, 0.15358543209876546, -0.0009345679012345678, 0.002666913580246914, -7.993827160493826e-06, -0.00011617283950617283],
                                       [-3.500948395061729, 0.11738987654320988, -0.0006580246913580248, 0.007003148148148148, -2.8518518518518517e-05, -0.0001284259259259259],
                                       [1.8769221728395058, -0.04768641975308643, 0.0006885802469135801, 0.006643395061728395, 1.4209876543209876e-05, -0.00024043209876543206]]
      hp_ap.cool_cap_ft_spec = hp_ap.cool_cap_coeff_perf_map.select { |i| [0, 1, 2, 4].include? hp_ap.cool_cap_coeff_perf_map.index(i) }
      hp_ap.cool_cap_ft_spec_3 = hp_ap.cool_cap_coeff_perf_map.select { |i| [0, 1, 4].include? hp_ap.cool_cap_coeff_perf_map.index(i) }
      hp_ap.cool_eir_coeff_perf_map = [[2.896298765432099, -0.12487654320987657, 0.0012148148148148148, 0.04492037037037037, 8.734567901234567e-05, -0.0006348765432098764],
                                       [6.428076543209876, -0.20913209876543212, 0.0018521604938271604, 0.024392592592592594, 0.00019691358024691356, -0.0006012345679012346],
                                       [5.136356049382716, -0.1591530864197531, 0.0014151234567901232, 0.018665555555555557, 0.00020398148148148147, -0.0005407407407407407],
                                       [1.3823471604938273, -0.02875123456790123, 0.00038302469135802463, 0.006344814814814816, 0.00024836419753086417, -0.00047469135802469134],
                                       [-1.0411735802469133, 0.055261604938271605, -0.0004404320987654321, 0.0002154938271604939, 0.00017484567901234564, -0.0002017901234567901]]
      hp_ap.cool_eir_ft_spec = hp_ap.cool_eir_coeff_perf_map.select { |i| [0, 1, 2, 4].include? hp_ap.cool_eir_coeff_perf_map.index(i) }
      hp_ap.cool_eir_ft_spec_3 = hp_ap.cool_eir_coeff_perf_map.select { |i| [0, 1, 4].include? hp_ap.cool_eir_coeff_perf_map.index(i) }
      # Variable speed systems have constant flow ECM blowers, so the air handler can always achieve the design airflow rate by sacrificing blower power.
      # So we assume that there is only one corresponding airflow rate for each compressor speed.
      hp_ap.cool_eir_fflow_spec = [[1, 0, 0]] * 4
      hp_ap.cool_cap_fflow_spec = [[1, 0, 0]] * 4
      hp_ap.cap_ratio_seer_3 = hp_ap.cool_capacity_ratios.select { |i| [0, 1, 3].include? hp_ap.cool_capacity_ratios.index(i) }
      hp_ap.fan_speed_seer_3 = hp_ap.cool_fan_speed_ratios.select { |i| [0, 1, 3].include? hp_ap.cool_fan_speed_ratios.index(i) }
      hp_ap.cool_eers = calc_eers_cooling_4speed(heat_pump.cooling_efficiency_seer, hp_ap.cool_c_d, hp_ap.cap_ratio_seer_3, hp_ap.fan_speed_seer_3, hp_ap.fan_power_rated, hp_ap.cool_eir_ft_spec_3, hp_ap.cool_cap_ft_spec_3)
    end
  end

  def self.set_ashp_htg_curves(heat_pump)
    hp_ap = heat_pump.additional_properties
    if hp_ap.num_speeds == 1
      # From "Improved Modeling of Residential Air Conditioners and Heat Pumps for Energy Calculations", Cutler at al
      # https://www.nrel.gov/docs/fy13osti/56354.pdf
      hp_ap.heat_rated_airflow_rate = 384.1 # cfm/ton
      hp_ap.heat_capacity_ratios = [1.0]
      hp_ap.heat_fan_speed_ratios = [1.0]
      hp_ap.heat_eir_ft_spec = [[0.718398423, 0.003498178, 0.000142202, -0.005724331, 0.00014085, -0.000215321]]
      hp_ap.heat_cap_fflow_spec = [[0.694045465, 0.474207981, -0.168253446]]
      hp_ap.heat_eir_fflow_spec = [[2.185418751, -1.942827919, 0.757409168]]
      if heat_pump.heating_capacity_17F.nil?
        hp_ap.heat_cap_ft_spec = [[0.566333415, -0.000744164, -0.0000103, 0.009414634, 0.0000506, -0.00000675]]
      else
        hp_ap.heat_cap_ft_spec = calc_heat_cap_ft_spec_using_capacity_17F(heat_pump)
      end
      hp_ap.heat_cops = [calc_cop_heating_1speed(heat_pump.heating_efficiency_hspf, hp_ap.heat_c_d, hp_ap.fan_power_rated, hp_ap.heat_eir_ft_spec, hp_ap.heat_cap_ft_spec)]
    elsif hp_ap.num_speeds == 2
      # From "Improved Modeling of Residential Air Conditioners and Heat Pumps for Energy Calculations", Cutler at al
      # https://www.nrel.gov/docs/fy13osti/56354.pdf
      hp_ap.heat_rated_airflow_rate = 352.2 # cfm/ton
      hp_ap.heat_capacity_ratios = [0.72, 1.0]
      hp_ap.heat_fan_speed_ratios = [0.8, 1.0]
      hp_ap.heat_eir_ft_spec = [[0.36338171, 0.013523725, 0.000258872, -0.009450269, 0.000439519, -0.000653723],
                                [0.981100941, -0.005158493, 0.000243416, -0.005274352, 0.000230742, -0.000336954]]
      hp_ap.heat_cap_fflow_spec = [[0.741466907, 0.378645444, -0.119754733],
                                   [0.76634609, 0.32840943, -0.094701495]]
      hp_ap.heat_eir_fflow_spec = [[2.153618211, -1.737190609, 0.584269478],
                                   [2.001041353, -1.58869128, 0.587593517]]
      if heat_pump.heating_capacity_17F.nil?
        hp_ap.heat_cap_ft_spec = [[0.335690634, 0.002405123, -0.0000464, 0.013498735, 0.0000499, -0.00000725],
                                  [0.306358843, 0.005376987, -0.0000579, 0.011645092, 0.0000591, -0.0000203]]
      else
        hp_ap.heat_cap_ft_spec = calc_heat_cap_ft_spec_using_capacity_17F(heat_pump)
      end
      hp_ap.heat_cops = calc_cops_heating_2speed(heat_pump.heating_efficiency_hspf, hp_ap.heat_c_d, hp_ap.heat_capacity_ratios, hp_ap.heat_fan_speed_ratios, hp_ap.fan_power_rated, hp_ap.heat_eir_ft_spec, hp_ap.heat_cap_ft_spec)
    elsif hp_ap.num_speeds == 4
      # From Carrier heat pump lab testing
      hp_ap.heat_rated_airflow_rate = 296.9 # cfm/ton
      hp_ap.heat_capacity_ratios = [0.33, 0.56, 1.0, 1.17]
      hp_ap.heat_fan_speed_ratios = [0.63, 0.76, 1.0, 1.19]
      hp_ap.heat_eir_ft_spec = [[0.708311527, 0.020732093, 0.000391479, -0.037640031, 0.000979937, -0.001079042],
                                [0.025480155, 0.020169585, 0.000121341, -0.004429789, 0.000166472, -0.00036447],
                                [0.379003189, 0.014195012, 0.0000821046, -0.008894061, 0.000151519, -0.000210299],
                                [0.690404655, 0.00616619, 0.000137643, -0.009350199, 0.000153427, -0.000213258]]
      hp_ap.heat_cap_fflow_spec = [[1, 0, 0]] * 4
      hp_ap.heat_eir_fflow_spec = [[1, 0, 0]] * 4
      if heat_pump.heating_capacity_17F.nil?
        hp_ap.heat_cap_ft_spec = [[0.304192655, -0.003972566, 0.0000196432, 0.024471251, -0.000000774126, -0.0000841323],
                                  [0.496381324, -0.00144792, 0.0, 0.016020855, 0.0000203447, -0.0000584118],
                                  [0.697171186, -0.006189599, 0.0000337077, 0.014291981, 0.0000105633, -0.0000387956],
                                  [0.555513805, -0.001337363, -0.00000265117, 0.014328826, 0.0000163849, -0.0000480711]]
      else
        hp_ap.heat_cap_ft_spec = calc_heat_cap_ft_spec_using_capacity_17F(heat_pump)
      end
      hp_ap.heat_cops = calc_cops_heating_4speed(heat_pump.heating_efficiency_hspf, hp_ap.heat_c_d, hp_ap.heat_capacity_ratios, hp_ap.heat_fan_speed_ratios, hp_ap.fan_power_rated, hp_ap.heat_eir_ft_spec, hp_ap.heat_cap_ft_spec)
    end
  end

  def self.set_cool_curves_room_ac(cooling_system)
    clg_ap = cooling_system.additional_properties

    # From "Improved Modeling of Residential Air Conditioners and Heat Pumps for Energy Calculations", Cutler at al
    # https://www.nrel.gov/docs/fy13osti/56354.pdf
    clg_ap.cool_cap_ft_spec = [[3.68637657, -0.098352478, 0.000956357, 0.005838141, -0.0000127, -0.000131702]]
    clg_ap.cool_eir_ft_spec = [[-3.437356399, 0.136656369, -0.001049231, -0.0079378, 0.000185435, -0.0001441]]
    clg_ap.cool_cap_fflow_spec = [[1, 0, 0]]
    clg_ap.cool_eir_fflow_spec = [[1, 0, 0]]
  end

  def self.set_cool_curves_mshp(heat_pump, num_speeds)
    hp_ap = heat_pump.additional_properties

    # From Daikin mini-split lab testing
    hp_ap.cool_cap_ft_spec = [[0.7531983499655835, 0.003618193903031667, 0.0, 0.006574385031351544, -6.87181191015432e-05, 0.0]] * num_speeds
    hp_ap.cool_eir_ft_spec = [[-0.06376924779982301, -0.0013360593470367282, 1.413060577993827e-05, 0.019433076486584752, -4.91395947154321e-05, -4.909341249475308e-05]] * num_speeds
    hp_ap.cool_cap_fflow_spec = [[1, 0, 0]] * num_speeds
    hp_ap.cool_eir_fflow_spec = [[1, 0, 0]] * num_speeds

    hp_ap.cool_min_capacity_ratio = 0.4 # frac
    hp_ap.cool_max_capacity_ratio = 1.2 # frac
    hp_ap.cool_min_cfm_per_ton = 200.0 / hp_ap.cool_min_capacity_ratio # Convert cfm/ton of nominal rated capacity to cfm/ton of min capacity
    hp_ap.cool_max_cfm_per_ton = 425.0 / hp_ap.cool_max_capacity_ratio # Convert cfm/ton of nominal rated capacity to cfm/ton of max capacity
  end

  def self.set_heat_curves_mshp(heat_pump, num_speeds)
    hp_ap = heat_pump.additional_properties

    # From Daikin mini-split lab testing
    hp_ap.heat_eir_ft_spec = [[0.9999941697687026, 0.004684593830254383, 5.901286675833333e-05, -0.0028624467783091973, 1.3041120194135802e-05, -0.00016172918478765433]] * num_speeds
    hp_ap.heat_cap_fflow_spec = [[1, 0, 0]] * num_speeds
    hp_ap.heat_eir_fflow_spec = [[1, 0, 0]] * num_speeds

    # Derive coefficients from user input for capacity retention at outdoor drybulb temperature X [C].
    if heat_pump.heating_capacity_17F.nil? || ((heat_pump.heating_capacity_17F == 0) && (heat_pump.heating_capacity == 0))
      cap_retention_frac = 0.25 # frac
      cap_retention_temp = -5.0 # deg-F
    else
      cap_retention_frac = heat_pump.heating_capacity_17F / heat_pump.heating_capacity
      cap_retention_temp = 17.0 # deg-F
    end

    # Biquadratic: capacity multiplier = a + b*IAT + c*IAT^2 + d*OAT + e*OAT^2 + f*IAT*OAT
    x_A = UnitConversions.convert(cap_retention_temp, 'F', 'C')
    y_A = cap_retention_frac
    x_B = UnitConversions.convert(47.0, 'F', 'C') # 47F is the rating point
    y_B = 1.0 # Maximum capacity factor is 1 at the rating point, by definition (this is maximum capacity, not nominal capacity)
    oat_slope = (y_B - y_A) / (x_B - x_A)
    oat_intercept = y_A - (x_A * oat_slope)

    # Coefficients for the indoor temperature relationship are retained from the generic curve (Daikin lab data).
    iat_slope = -0.010386676170938
    iat_intercept = 0.219274275
    a = oat_intercept + iat_intercept
    b = iat_slope
    c = 0
    d = oat_slope
    e = 0
    f = 0
    hp_ap.heat_cap_ft_spec = [HVAC.convert_curve_biquadratic([a, b, c, d, e, f], false)] * num_speeds

    hp_ap.heat_min_capacity_ratio = 0.3 # frac
    hp_ap.heat_max_capacity_ratio = 1.2 # frac
    hp_ap.heat_min_cfm_per_ton = 200.0 / hp_ap.heat_min_capacity_ratio # Convert cfm/ton of nominal rated capacity to cfm/ton of min capacity
    hp_ap.heat_max_cfm_per_ton = 400.0 / hp_ap.heat_max_capacity_ratio # Convert cfm/ton of nominal rated capacity to cfm/ton of min capacity
  end

  def self.set_curves_gshp(heat_pump)
    hp_ap = heat_pump.additional_properties

    # E+ equation fit coil coefficients generated following approach in Tang's thesis:
    # See Appendix B of  https://hvac.okstate.edu/sites/default/files/pubs/theses/MS/27-Tang_Thesis_05.pdf
    # Coefficients generated by catalog data: https://files.climatemaster.com/Genesis-GS-Series-Product-Catalog.pdf, p180
    # Data point taken as rated condition:
    # EWT: 80F EAT:80/67F, AFR: 1200cfm, WFR: 4.5gpm
    hp_ap.cool_cap_curve_spec = [[-1.57177156131221, 4.60343712716819, -2.15976622898044, 0.0590964827802021, 0.0194696644460315]]
    hp_ap.cool_power_curve_spec = [[-4.42471086639888, 0.658017281046304, 4.37331801294626, 0.174096187531254, -0.0526514790164159]]
    hp_ap.cool_sh_curve_spec = [[4.54172823345154, 14.7653304889134, -18.3541272090485, -0.74401391092935, 0.545560799548833, 0.0182620032235494]]
    hp_ap.cool_rated_shrs_gross = [heat_pump.cooling_shr]
    # FUTURE: Reconcile these fan/pump adjustments with ANSI/RESNET/ICC 301-2019 Section 4.4.5
    fan_adjust_kw = UnitConversions.convert(400.0, 'Btu/hr', 'ton') * UnitConversions.convert(1.0, 'cfm', 'm^3/s') * 1000.0 * 0.35 * 249.0 / 300.0 # Adjustment per ISO 13256-1 Internal pressure drop across heat pump assumed to be 0.5 in. w.g.
    pump_adjust_kw = UnitConversions.convert(3.0, 'Btu/hr', 'ton') * UnitConversions.convert(1.0, 'gal/min', 'm^3/s') * 1000.0 * 6.0 * 2990.0 / 3000.0 # Adjustment per ISO 13256-1 Internal Pressure drop across heat pump coil assumed to be 11ft w.g.
    cool_eir = UnitConversions.convert((1.0 - heat_pump.cooling_efficiency_eer * (fan_adjust_kw + pump_adjust_kw)) / (heat_pump.cooling_efficiency_eer * (1.0 + UnitConversions.convert(fan_adjust_kw, 'Wh', 'Btu'))), 'Wh', 'Btu')
    hp_ap.cool_rated_eirs = [cool_eir]

    # E+ equation fit coil coefficients from Tang's thesis:
    # See Appendix B Figure B.3 of  https://hvac.okstate.edu/sites/default/files/pubs/theses/MS/27-Tang_Thesis_05.pdf
    # Coefficients generated by catalog data
    hp_ap.heat_cap_curve_spec = [[-5.12650150, -0.93997630, 7.21443206, 0.121065721, 0.051809805]]
    hp_ap.heat_power_curve_spec = [[-7.73235249, 6.43390775, 2.29152262, -0.175598629, 0.005888871]]
    heat_eir = (1.0 - heat_pump.heating_efficiency_cop * (fan_adjust_kw + pump_adjust_kw)) / (heat_pump.heating_efficiency_cop * (1.0 - fan_adjust_kw))
    hp_ap.heat_rated_eirs = [heat_eir]
  end

  def self.get_default_compressor_type(hvac_type, seer)
    if [HPXML::HVACTypeCentralAirConditioner,
        HPXML::HVACTypeHeatPumpAirToAir].include? hvac_type
      if seer <= 15
        return HPXML::HVACCompressorTypeSingleStage
      elsif seer <= 21
        return HPXML::HVACCompressorTypeTwoStage
      elsif seer > 21
        return HPXML::HVACCompressorTypeVariableSpeed
      end
    end
    return
  end

  def self.get_default_ceiling_fan_power()
    # Per ANSI/RESNET/ICC 301
    return 42.6 # W
  end

  def self.get_default_ceiling_fan_quantity(nbeds)
    # Per ANSI/RESNET/ICC 301
    return nbeds + 1
  end

  def self.get_default_ceiling_fan_months(weather)
    # Per ANSI/RESNET/ICC 301
    months = [0] * 12
    weather.data.MonthlyAvgDrybulbs.each_with_index do |val, m|
      next unless val > 63.0 # deg-F

      months[m] = 1
    end
    return months
  end

  def self.get_default_heating_and_cooling_seasons(weather)
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

  private

  def self.set_pump_power_ems_program(model, pump_w, pump, heating_object)
    # EMS is used to set the pump power.
    # Without EMS, the pump power will vary according to the plant loop part load ratio
    # (based on flow rate) rather than the boiler part load ratio (based on load).

    # Sensors
    if heating_object.is_a? OpenStudio::Model::BoilerHotWater
      heating_plr_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Boiler Part Load Ratio')
      heating_plr_sensor.setName("#{heating_object.name} plr s")
      heating_plr_sensor.setKeyName(heating_object.name.to_s)
    elsif heating_object.is_a? OpenStudio::Model::AirLoopHVACUnitarySystem
      heating_plr_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Unitary System Part Load Ratio')
      heating_plr_sensor.setName("#{heating_object.name} plr s")
      heating_plr_sensor.setKeyName(heating_object.name.to_s)
    end

    pump_mfr_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Pump Mass Flow Rate')
    pump_mfr_sensor.setName("#{pump.name} mfr s")
    pump_mfr_sensor.setKeyName(pump.name.to_s)

    # Internal variable
    pump_rated_mfr_var = OpenStudio::Model::EnergyManagementSystemInternalVariable.new(model, EPlus::EMSIntVarPumpMFR)
    pump_rated_mfr_var.setName("#{pump.name} rated mfr")
    pump_rated_mfr_var.setInternalDataIndexKeyName(pump.name.to_s)

    # Actuator
    pump_pressure_rise_act = OpenStudio::Model::EnergyManagementSystemActuator.new(pump, *EPlus::EMSActuatorPumpPressureRise)
    pump_pressure_rise_act.setName("#{pump.name} pressure rise act")

    # Program
    # See https://bigladdersoftware.com/epx/docs/9-3/ems-application-guide/hvac-systems-001.html#pump
    pump_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    pump_program.setName("#{pump.name} power program")
    pump_program.addLine("Set heating_plr = #{heating_plr_sensor.name}")
    pump_program.addLine("Set pump_total_eff = #{pump_rated_mfr_var.name} / 1000 * #{pump.ratedPumpHead} / #{pump.ratedPowerConsumption.get}")
    pump_program.addLine("Set pump_vfr = #{pump_mfr_sensor.name} / 1000")
    pump_program.addLine('If pump_vfr > 0')
    pump_program.addLine("  Set #{pump_pressure_rise_act.name} = #{pump_w} * heating_plr * pump_total_eff / pump_vfr")
    pump_program.addLine('Else')
    pump_program.addLine("  Set #{pump_pressure_rise_act.name} = 0")
    pump_program.addLine('EndIf')

    # Calling Point
    pump_program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    pump_program_calling_manager.setName("#{pump.name} power program calling manager")
    pump_program_calling_manager.setCallingPoint('EndOfSystemTimestepBeforeHVACReporting')
    pump_program_calling_manager.addProgram(pump_program)
  end

  def self.disaggregate_fan_or_pump(model, fan_or_pump, htg_object, clg_object, backup_htg_object)
    # Disaggregate into heating/cooling output energy use.

    hvac_objects = []

    if fan_or_pump.is_a? OpenStudio::Model::FanSystemModel
      fan_or_pump_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Fan #{EPlus::FuelTypeElectricity} Energy")
    elsif fan_or_pump.is_a? OpenStudio::Model::PumpVariableSpeed
      fan_or_pump_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Pump #{EPlus::FuelTypeElectricity} Energy")
    elsif fan_or_pump.is_a? OpenStudio::Model::ElectricEquipment
      fan_or_pump_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Electric Equipment #{EPlus::FuelTypeElectricity} Energy")
    else
      fail "Unexpected fan/pump object '#{fan_or_pump.name}'."
    end
    fan_or_pump_sensor.setName("#{fan_or_pump.name} s")
    fan_or_pump_sensor.setKeyName(fan_or_pump.name.to_s)
    hvac_objects << fan_or_pump_sensor

    if clg_object.nil?
      clg_object_sensor = nil
    else
      if clg_object.is_a? OpenStudio::Model::EvaporativeCoolerDirectResearchSpecial
        var = 'Evaporative Cooler Water Volume'
      else
        var = "Cooling Coil #{EPlus::FuelTypeElectricity} Energy"
      end
      clg_object_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
      clg_object_sensor.setName("#{clg_object.name} s")
      clg_object_sensor.setKeyName(clg_object.name.to_s)
      hvac_objects << clg_object_sensor
    end

    if htg_object.nil?
      htg_object_sensor = nil
    else
      var = "Heating Coil #{EPlus::FuelTypeElectricity} Energy"
      if htg_object.is_a? OpenStudio::Model::CoilHeatingGas
        var = "Heating Coil #{htg_object.fuelType} Energy"
      elsif htg_object.is_a? OpenStudio::Model::ZoneHVACBaseboardConvectiveWater
        var = 'Baseboard Total Heating Energy'
      elsif htg_object.is_a? OpenStudio::Model::ZoneHVACFourPipeFanCoil
        var = 'Fan Coil Heating Energy'
      end

      htg_object_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
      htg_object_sensor.setName("#{htg_object.name} s")
      htg_object_sensor.setKeyName(htg_object.name.to_s)
      hvac_objects << htg_object_sensor
    end

    if backup_htg_object.nil?
      backup_htg_object_sensor = nil
    else
      var = "Heating Coil #{EPlus::FuelTypeElectricity} Energy"
      if backup_htg_object.is_a? OpenStudio::Model::CoilHeatingGas
        var = "Heating Coil #{backup_htg_object.fuelType} Energy"
      end

      backup_htg_object_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
      backup_htg_object_sensor.setName("#{backup_htg_object.name} s")
      backup_htg_object_sensor.setKeyName(backup_htg_object.name.to_s)
      hvac_objects << backup_htg_object_sensor
    end

    sensors = { 'clg' => clg_object_sensor,
                'primary_htg' => htg_object_sensor,
                'backup_htg' => backup_htg_object_sensor }
    sensors = sensors.select { |m, s| !s.nil? }

    fan_or_pump_var = fan_or_pump.name.to_s.gsub(' ', '_')

    # Disaggregate electric fan/pump energy
    fan_or_pump_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    fan_or_pump_program.setName("#{fan_or_pump_var} disaggregate program")
    if htg_object.is_a?(OpenStudio::Model::ZoneHVACBaseboardConvectiveWater) || htg_object.is_a?(OpenStudio::Model::ZoneHVACFourPipeFanCoil)
      # Pump may occassionally run when baseboard isn't, so just assign all pump energy here
      mode, sensor = sensors.first
      if (sensors.size != 1) || (mode != 'primary_htg')
        fail 'Unexpected situation.'
      end

      fan_or_pump_program.addLine("  Set #{fan_or_pump_var}_#{mode} = #{fan_or_pump_sensor.name}")
    else
      sensors.each do |mode, sensor|
        fan_or_pump_program.addLine("Set #{fan_or_pump_var}_#{mode} = 0")
      end
      sensors.each_with_index do |(mode, sensor), i|
        if i == 0
          fan_or_pump_program.addLine("If #{sensor.name} > 0")
        elsif i == 2
          fan_or_pump_program.addLine('Else')
        else
          fan_or_pump_program.addLine("ElseIf #{sensor.name} > 0")
        end
        fan_or_pump_program.addLine("  Set #{fan_or_pump_var}_#{mode} = #{fan_or_pump_sensor.name}")
      end
      fan_or_pump_program.addLine('EndIf')
    end
    hvac_objects << fan_or_pump_program

    fan_or_pump_program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    fan_or_pump_program_calling_manager.setName("#{fan_or_pump.name} disaggregate program calling manager")
    fan_or_pump_program_calling_manager.setCallingPoint('EndOfSystemTimestepBeforeHVACReporting')
    fan_or_pump_program_calling_manager.addProgram(fan_or_pump_program)
    hvac_objects << fan_or_pump_program_calling_manager

    sensors.each do |mode, sensor|
      next if sensor.nil?

      fan_or_pump_ems_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, "#{fan_or_pump_var}_#{mode}")
      name = { 'clg' => Constants.ObjectNameFanPumpDisaggregateCool(fan_or_pump.name.to_s),
               'primary_htg' => Constants.ObjectNameFanPumpDisaggregatePrimaryHeat(fan_or_pump.name.to_s),
               'backup_htg' => Constants.ObjectNameFanPumpDisaggregateBackupHeat(fan_or_pump.name.to_s) }[mode]
      fan_or_pump_ems_output_var.setName(name)
      fan_or_pump_ems_output_var.setTypeOfDataInVariable('Summed')
      fan_or_pump_ems_output_var.setUpdateFrequency('SystemTimestep')
      fan_or_pump_ems_output_var.setEMSProgramOrSubroutineName(fan_or_pump_program)
      fan_or_pump_ems_output_var.setUnits('J')
      hvac_objects << fan_or_pump_ems_output_var
    end

    return hvac_objects
  end

  def self.adjust_dehumidifier_load_EMS(fraction_served, zone_hvac, model, living_space)
    # adjust hvac load to space when dehumidifier serves less than 100% dehumidification load. (With E+ dehumidifier object, it can only model 100%)

    # sensor
    dehumidifier_sens_htg = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Dehumidifier Sensible Heating Rate')
    dehumidifier_sens_htg.setName("#{zone_hvac.name} sens htg")
    dehumidifier_sens_htg.setKeyName(zone_hvac.name.to_s)
    dehumidifier_power = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Zone Dehumidifier #{EPlus::FuelTypeElectricity} Rate")
    dehumidifier_power.setName("#{zone_hvac.name} power htg")
    dehumidifier_power.setKeyName(zone_hvac.name.to_s)

    # actuator
    dehumidifier_load_adj_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
    dehumidifier_load_adj_def.setName("#{zone_hvac.name} sens htg adj def")
    dehumidifier_load_adj_def.setDesignLevel(0)
    dehumidifier_load_adj_def.setFractionRadiant(0)
    dehumidifier_load_adj_def.setFractionLatent(0)
    dehumidifier_load_adj_def.setFractionLost(0)
    dehumidifier_load_adj = OpenStudio::Model::OtherEquipment.new(dehumidifier_load_adj_def)
    dehumidifier_load_adj.setName("#{zone_hvac.name} sens htg adj")
    dehumidifier_load_adj.setSpace(living_space)
    dehumidifier_load_adj.setSchedule(model.alwaysOnDiscreteSchedule)

    dehumidifier_load_adj_act = OpenStudio::Model::EnergyManagementSystemActuator.new(dehumidifier_load_adj, *EPlus::EMSActuatorOtherEquipmentPower)
    dehumidifier_load_adj_act.setName("#{zone_hvac.name} sens htg adj act")

    # EMS program
    program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    program.setName("#{zone_hvac.name} load adj program")
    program.addLine("If #{dehumidifier_sens_htg.name} > 0")
    program.addLine("  Set #{dehumidifier_load_adj_act.name} = - (#{dehumidifier_sens_htg.name} - #{dehumidifier_power.name}) * (1 - #{fraction_served})")
    program.addLine('Else')
    program.addLine("  Set #{dehumidifier_load_adj_act.name} = 0")
    program.addLine('EndIf')

    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName(program.name.to_s + 'calling manager')
    program_calling_manager.setCallingPoint('BeginTimestepBeforePredictor')
    program_calling_manager.addProgram(program)
  end

  def self.create_supp_heating_coil(model, obj_name, heat_pump)
    fuel = heat_pump.backup_heating_fuel
    capacity = heat_pump.backup_heating_capacity
    efficiency = heat_pump.backup_heating_efficiency_percent
    efficiency = heat_pump.backup_heating_efficiency_afue if efficiency.nil?

    if fuel.nil?
      fuel = HPXML::FuelTypeElectricity
      capacity = 0.0
      efficiency = 1.0
    end

    if fuel == HPXML::FuelTypeElectricity
      htg_supp_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
      htg_supp_coil.setEfficiency(efficiency)
    else
      htg_supp_coil = OpenStudio::Model::CoilHeatingGas.new(model)
      htg_supp_coil.setGasBurnerEfficiency(efficiency)
      htg_supp_coil.setParasiticElectricLoad(0)
      htg_supp_coil.setParasiticGasLoad(0)
      htg_supp_coil.setFuelType(EPlus.fuel_type(fuel))
    end
    htg_supp_coil.setNominalCapacity(UnitConversions.convert(capacity, 'Btu/hr', 'W'))
    htg_supp_coil.setName(obj_name + ' ' + Constants.ObjectNameBackupHeatingCoil)
    return htg_supp_coil
  end

  def self.create_supply_fan(model, obj_name, fan_watts_per_cfm, fan_cfms)
    # Note: fan_cfms should include all unique airflow rates (both heating and cooling, at all speeds)
    fan = OpenStudio::Model::FanSystemModel.new(model)
    fan.setSpeedControlMethod('Discrete')
    fan.setDesignPowerSizingMethod('TotalEfficiencyAndPressure')
    fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    set_fan_power(fan, fan_watts_per_cfm)
    fan.setName(obj_name + ' supply fan')
    fan.setEndUseSubcategory('supply fan')
    fan.setMotorEfficiency(1.0)
    fan.setMotorInAirStreamFraction(1.0)
    max_fan_cfm = Float(fan_cfms.max) # Convert to float to prevent integer division below
    fan.setDesignMaximumAirFlowRate(UnitConversions.convert(max_fan_cfm, 'cfm', 'm^3/s'))
    fan_cfms.sort.each do |fan_cfm|
      fan_ratio = fan_cfm / max_fan_cfm
      power_fraction = fan_ratio**3 # fan power curve
      fan.addSpeed(fan_ratio.round(5), power_fraction.round(5))
    end
    return fan
  end

  def self.create_air_loop_unitary_system(model, obj_name, fan, htg_coil, clg_coil, htg_supp_coil, htg_cfm, clg_cfm, supp_max_temp = nil)
    air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
    air_loop_unitary.setName(obj_name + ' unitary system')
    air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    air_loop_unitary.setSupplyFan(fan)
    air_loop_unitary.setFanPlacement('BlowThrough')
    air_loop_unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
    air_loop_unitary.setSupplyAirFlowRateMethodDuringHeatingOperation('SupplyAirFlowRate')
    if htg_coil.nil?
      air_loop_unitary.setSupplyAirFlowRateDuringHeatingOperation(0.0)
    else
      air_loop_unitary.setHeatingCoil(htg_coil)
      air_loop_unitary.setSupplyAirFlowRateDuringHeatingOperation(UnitConversions.convert(htg_cfm, 'cfm', 'm^3/s'))
    end
    air_loop_unitary.setSupplyAirFlowRateMethodDuringCoolingOperation('SupplyAirFlowRate')
    if clg_coil.nil?
      air_loop_unitary.setSupplyAirFlowRateDuringCoolingOperation(0.0)
    else
      air_loop_unitary.setCoolingCoil(clg_coil)
      air_loop_unitary.setSupplyAirFlowRateDuringCoolingOperation(UnitConversions.convert(clg_cfm, 'cfm', 'm^3/s'))
    end
    if htg_supp_coil.nil?
      air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(120.0, 'F', 'C'))
    else
      air_loop_unitary.setSupplementalHeatingCoil(htg_supp_coil)
      air_loop_unitary.setMaximumSupplyAirTemperature(UnitConversions.convert(200.0, 'F', 'C')) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      air_loop_unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(UnitConversions.convert(supp_max_temp, 'F', 'C'))
    end
    air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)
    return air_loop_unitary
  end

  def self.create_air_loop(model, obj_name, system, control_zone, sequential_heat_load_fracs, sequential_cool_load_fracs, airflow_cfm)
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    air_loop.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    air_loop.setName(obj_name + ' airloop')
    air_loop.zoneSplitter.setName(obj_name + ' zone splitter')
    air_loop.zoneMixer.setName(obj_name + ' zone mixer')
    air_loop.setDesignSupplyAirFlowRate(UnitConversions.convert(airflow_cfm, 'cfm', 'm^3/s'))
    system.addToNode(air_loop.supplyInletNode)

    if system.is_a? OpenStudio::Model::AirLoopHVACUnitarySystem
      air_terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      system.setControllingZoneorThermostatLocation(control_zone)
    else
      air_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule)
      air_terminal.setConstantMinimumAirFlowFraction(0)
      air_terminal.setFixedMinimumAirFlowRate(0)
    end
    air_terminal.setMaximumAirFlowRate(UnitConversions.convert(airflow_cfm, 'cfm', 'm^3/s'))
    air_terminal.setName(obj_name + ' terminal')
    air_loop.multiAddBranchForZone(control_zone, air_terminal)

    control_zone.setSequentialHeatingFractionSchedule(air_terminal, get_sequential_load_schedule(model, sequential_heat_load_fracs))
    control_zone.setSequentialCoolingFractionSchedule(air_terminal, get_sequential_load_schedule(model, sequential_cool_load_fracs))

    return air_loop
  end

  def self.apply_dehumidifier_ief_to_ef_inputs(dh_type, w_coeff, ef_coeff, ief, water_removal_rate)
    # Shift inputs under IEF test conditions to E+ supported EF test conditions
    # test conditions
    if dh_type == HPXML::DehumidifierTypePortable
      ief_db = UnitConversions.convert(65.0, 'F', 'C') # degree C
    elsif dh_type == HPXML::DehumidifierTypeWholeHome
      ief_db = UnitConversions.convert(73.0, 'F', 'C') # degree C
    end
    rh = 60.0 # for both EF and IEF test conditions, %

    # Independent variables applied to curve equations
    var_array_ief = [1, ief_db, ief_db * ief_db, rh, rh * rh, ief_db * rh]

    # Curved values under EF test conditions
    curve_value_ef = 1 # Curves are normalized to 1.0 under EF test conditions, 80F, 60%
    # Curve values under IEF test conditions
    ef_curve_value_ief = var_array_ief.zip(ef_coeff).map { |var, coeff| var * coeff }.sum(0.0)
    water_removal_curve_value_ief = var_array_ief.zip(w_coeff).map { |var, coeff| var * coeff }.sum(0.0)

    # E+ inputs under EF test conditions
    ef_input = ief / ef_curve_value_ief * curve_value_ef
    water_removal_rate_input = water_removal_rate / water_removal_curve_value_ief * curve_value_ef

    return ef_input, water_removal_rate_input
  end

  def self.get_default_boiler_eae(heating_system)
    if heating_system.heating_system_type != HPXML::HVACTypeBoiler
      return
    end
    if not heating_system.electric_auxiliary_energy.nil?
      return heating_system.electric_auxiliary_energy
    end

    # From ANSI/RESNET/ICC 301-2019 Standard
    fuel = heating_system.heating_system_fuel

    if heating_system.is_shared_system
      distribution_system = heating_system.distribution_system
      distribution_type = distribution_system.distribution_system_type

      if not heating_system.shared_loop_watts.nil?
        sp_kw = UnitConversions.convert(heating_system.shared_loop_watts, 'W', 'kW')
        n_dweq = heating_system.number_of_units_served.to_f
        if distribution_system.air_type == HPXML::AirTypeFanCoil
          aux_in = UnitConversions.convert(heating_system.fan_coil_watts, 'W', 'kW')
        else
          aux_in = 0.0 # ANSI/RESNET/ICC 301-2019 Section 4.4.7.2
        end
        # ANSI/RESNET/ICC 301-2019 Equation 4.4-5
        return (((sp_kw / n_dweq) + aux_in) * 2080.0).round(2) # kWh/yr
      elsif distribution_type == HPXML::HVACDistributionTypeHydronic
        # kWh/yr, per ANSI/RESNET/ICC 301-2019 Table 4.5.2(5)
        if distribution_system.hydronic_type == HPXML::HydronicTypeWaterLoop # Shared boiler w/ WLHP
          return 265.0
        else # Shared boiler w/ baseboard/radiators/etc
          return 220.0
        end
      elsif distribution_type == HPXML::HVACDistributionTypeAir
        if distribution_system.air_type == HPXML::AirTypeFanCoil # Shared boiler w/ fan coil
          return 438.0
        end
      end

    else # In-unit boilers

      if [HPXML::FuelTypeNaturalGas,
          HPXML::FuelTypePropane,
          HPXML::FuelTypeElectricity,
          HPXML::FuelTypeWoodCord,
          HPXML::FuelTypeWoodPellets].include? fuel
        return 170.0 # kWh/yr
      elsif [HPXML::FuelTypeOil,
             HPXML::FuelTypeOil1,
             HPXML::FuelTypeOil2,
             HPXML::FuelTypeOil4,
             HPXML::FuelTypeOil5or6,
             HPXML::FuelTypeDiesel,
             HPXML::FuelTypeKerosene,
             HPXML::FuelTypeCoal,
             HPXML::FuelTypeCoalAnthracite,
             HPXML::FuelTypeCoalBituminous,
             HPXML::FuelTypeCoke].include? fuel
        return 330.0 # kWh/yr
      end

    end
  end

  def self.calc_heat_cap_ft_spec_using_capacity_17F(heat_pump)
    num_speeds = heat_pump.additional_properties.num_speeds

    # Indoor temperature slope and intercept used if Q_17 is specified (derived using heat_cap_ft_spec)
    # NOTE: Using Q_17 assumes the same curve for all speeds
    if num_speeds == 1
      iat_slope = -0.002303414
      iat_intercept = 0.18417308
    elsif num_speeds == 2
      iat_slope = -0.002947013
      iat_intercept = 0.23168251
    elsif num_speeds == 4
      iat_slope = -0.002897048
      iat_intercept = 0.209319129
    end

    # Derive coefficients from user input for heating capacity at 47F and 17F
    # Biquadratic: capacity multiplier = a + b*IAT + c*IAT^2 + d*OAT + e*OAT^2 + f*IAT*OAT
    x_A = 17.0
    if heat_pump.heating_capacity > 0
      y_A = heat_pump.heating_capacity_17F / heat_pump.heating_capacity
    else
      y_A = 0.5 # Arbitrary
    end
    x_B = 47.0 # 47F is the rating point
    y_B = 1.0

    oat_slope = (y_B - y_A) / (x_B - x_A)
    oat_intercept = y_A - (x_A * oat_slope)

    heat_cap_ft_spec = []
    (1..num_speeds).to_a.each do |speed, i|
      heat_cap_ft_spec << [oat_intercept + iat_intercept, iat_slope, 0, oat_slope, 0, 0]
    end

    return heat_cap_ft_spec
  end

  def self.calc_eir_from_cop(cop, fan_power_rated)
    return UnitConversions.convert((UnitConversions.convert(1.0, 'Btu', 'Wh') + fan_power_rated * 0.03333) / cop - fan_power_rated * 0.03333, 'Wh', 'Btu')
  end

  def self.calc_eir_from_eer(eer, fan_power_rated)
    return UnitConversions.convert((1.0 - UnitConversions.convert(fan_power_rated * 0.03333, 'Wh', 'Btu')) / eer - fan_power_rated * 0.03333, 'Wh', 'Btu')
  end

  def self.calc_eer_from_eir(eir, fan_power_rated)
    cfm_per_ton = 400.0
    cfm_per_btuh = cfm_per_ton / 12000.0
    return ((1.0 - 3.412 * (fan_power_rated * cfm_per_btuh)) / (eir / 3.412 + (fan_power_rated * cfm_per_btuh)))
  end

  def self.calc_eers_from_eir_2speed(eer_2, fan_power_rated)
    # Returns low and high stage EER A given high stage EER A

    eir_2_a = calc_eir_from_eer(eer_2, fan_power_rated)

    eir_1_a = 0.8887 * eir_2_a + 0.0083 # Relationship derived using Dylan's data for two stage heat pumps

    return [calc_eer_from_eir(eir_1_a, fan_power_rated), eer_2]
  end

  def self.calc_eers_from_eir_4speed(eer_nom, fan_power_rated, calc_type = 'seer')
    # Returns EER A at minimum, intermediate, and nominal speed given EER A (and a fourth speed if calc_type != 'seer')

    eir_nom = calc_eir_from_eer(eer_nom, fan_power_rated)

    if calc_type.include? 'seer'
      indices = [0, 1, 4]
    else
      indices = [0, 1, 2, 4]
    end

    cop_ratios = [1.07, 1.11, 1.08, 1.05, 1.0] # Gross cop

    # Seer calculation is based on performance at three speeds
    cops = [cop_ratios[indices[0]], cop_ratios[indices[1]], cop_ratios[indices[2]]]

    unless calc_type.include? 'seer'
      cops << cop_ratios[indices[3]]
    end

    eers = []
    cops.each do |mult|
      eir = eir_nom / mult
      eers << calc_eer_from_eir(eir, fan_power_rated)
    end

    return eers
  end

  def self.calc_cop_from_eir(eir, fan_power_rated)
    cfm_per_ton = 400.0
    cfm_per_btuh = cfm_per_ton / 12000.0
    return (1.0 / 3.412 + fan_power_rated * cfm_per_btuh) / (eir / 3.412 + fan_power_rated * cfm_per_btuh)
  end

  def self.calc_cops_from_eir_2speed(cop_2, fan_power_rated)
    # Returns low and high stage rated cop given high stage cop

    eir_2 = calc_eir_from_cop(cop_2, fan_power_rated)

    eir_1 = 0.6241 * eir_2 + 0.0681 # Relationship derived using Dylan's data for Carrier two stage heat pumps

    return [calc_cop_from_eir(eir_1, fan_power_rated), cop_2]
  end

  def self.calc_cops_from_eir_4speed(cop_nom, fan_power_rated, calc_type = 'hspf')
    # Returns rated cop at minimum, intermediate, and nominal speed given rated cop

    eir_nom = calc_eir_from_cop(cop_nom, fan_power_rated)

    cop_ratios = [1.385171617, 1.183214059, 1.0, 0.95544453] # Updated based on Nordyne 3 ton heat pump

    # HSPF calculation is based on performance at three speeds
    if calc_type == 'hspf'
      indices = [0, 1, 2]
    elsif calc_type == 'model'
      indices = [0, 1, 2, 3]
    end

    cops_net = []
    indices.each do |i|
      eir = eir_nom / cop_ratios[i]
      cops_net << calc_cop_from_eir(eir, fan_power_rated)
    end

    return cops_net
  end

  def self.calc_eer_cooling_1speed(seer, c_d, fan_power_rated, coeff_eir)
    # Directly calculate cooling coil net EER at condition A (95/80/67) using SEER

    # 1. Calculate EER_b using SEER and c_d
    eer_b = seer / (1.0 - 0.5 * c_d)

    # 2. Calculate EIR_b
    eir_b = calc_eir_from_eer(eer_b, fan_power_rated)

    # 3. Calculate EIR_a using performance curves
    eir_a = eir_b / MathTools.biquadratic(67.0, 82.0, coeff_eir[0])
    eer_a = calc_eer_from_eir(eir_a, fan_power_rated)

    return eer_a
  end

  def self.calc_eers_cooling_2speed(seer, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q)
    # Iterate to find rated net EERs given SEER using simple bisection method for two stage heat pumps

    # Initial large bracket of EER (A condition) to span possible SEER range
    eer_a = 5.0
    eer_b = 20.0

    # Iterate
    iter_max = 100
    tol = 0.0001

    err = 1
    eer_c = (eer_a + eer_b) / 2.0
    (1..iter_max).each do |n|
      eers = calc_eers_from_eir_2speed(eer_a, fan_power_rated)
      f_a = calc_seer_2speed(eers, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q) - seer

      eers = calc_eers_from_eir_2speed(eer_c, fan_power_rated)
      f_c = calc_seer_2speed(eers, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q) - seer

      if f_c == 0
        return eer_c
      elsif f_a * f_c < 0
        eer_b = eer_c
      else
        eer_a = eer_c
      end

      eer_c = (eer_a + eer_b) / 2.0
      err = (eer_b - eer_a) / 2.0

      if err <= tol
        break
      end
    end

    if err > tol
      fail 'Two-speed cooling eers iteration failed to converge.'
    end

    return calc_eers_from_eir_2speed(eer_c, fan_power_rated)
  end

  def self.calc_eers_cooling_4speed(seer, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q)
    # Iterate to find rated net eers given Seer using simple bisection method for two stage and variable speed air conditioners

    # Initial large bracket of eer (A condition) to span possible seer range
    eer_a = 5.0
    eer_b = 30.0

    # Iterate
    iter_max = 100
    tol = 0.0001

    err = 1
    eer_c = (eer_a + eer_b) / 2.0
    (1..iter_max).each do |n|
      eers = calc_eers_from_eir_4speed(eer_a, fan_power_rated, calc_type = 'seer')
      f_a = calc_seer_4speed(eers, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q) - seer

      eers = calc_eers_from_eir_4speed(eer_c, fan_power_rated, calc_type = 'seer')
      f_c = calc_seer_4speed(eers, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q) - seer

      if f_c == 0
        return eer_c
      elsif f_a * f_c < 0
        eer_b = eer_c
      else
        eer_a = eer_c
      end

      eer_c = (eer_a + eer_b) / 2.0
      err = (eer_b - eer_a) / 2.0

      if err <= tol
        break
      end
    end

    if err > tol
      fail 'Variable-speed cooling eers iteration failed to converge.'
    end

    return calc_eers_from_eir_4speed(eer_c, fan_power_rated, calc_type = 'model')
  end

  def self.calc_seer_2speed(eers, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q)
    eir_A2 = calc_eir_from_eer(eers[1], fan_power_rated)
    eir_B2 = eir_A2 * MathTools.biquadratic(67.0, 82.0, coeff_eir[1])

    eir_A1 = calc_eir_from_eer(eers[0], fan_power_rated)
    eir_B1 = eir_A1 * MathTools.biquadratic(67.0, 82.0, coeff_eir[0])
    eir_F1 = eir_A1 * MathTools.biquadratic(67.0, 67.0, coeff_eir[0])

    q_A2 = 1.0
    q_B2 = q_A2 * MathTools.biquadratic(67.0, 82.0, coeff_q[1])

    q_B1 = q_A2 * capacity_ratios[0] * MathTools.biquadratic(67.0, 82.0, coeff_q[0])
    q_F1 = q_A2 * capacity_ratios[0] * MathTools.biquadratic(67.0, 67.0, coeff_q[0])

    cfm_Btu_h = 400.0 / 12000.0

    q_A2_net = q_A2 - fan_power_rated * 3.412 * cfm_Btu_h
    q_B2_net = q_B2 - fan_power_rated * 3.412 * cfm_Btu_h
    q_B1_net = q_B1 - fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[0]
    q_F1_net = q_F1 - fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[0]

    p_A2 = (q_A2 * eir_A2) / 3.412 + fan_power_rated * cfm_Btu_h
    p_B2 = (q_B2 * eir_B2) / 3.412 + fan_power_rated * cfm_Btu_h
    p_B1 = (q_B1 * eir_B1) / 3.412 + fan_power_rated * cfm_Btu_h * fanspeed_ratios[0]
    p_F1 = (q_F1 * eir_F1) / 3.412 + fan_power_rated * cfm_Btu_h * fanspeed_ratios[0]

    t_bins = [67.0, 72.0, 77.0, 82.0, 87.0, 92.0, 97.0, 102.0]
    frac_hours = [0.214, 0.231, 0.216, 0.161, 0.104, 0.052, 0.018, 0.004]

    e_tot = 0.0
    q_tot = 0.0
    (0..7).each do |i|
      bL_i = ((t_bins[i] - 65.0) / (95.0 - 65.0)) * (q_A2_net / 1.1)
      q_low_i = q_F1_net + ((q_B1_net - q_F1_net) / (82.0 - 67.0)) * (t_bins[i] - 67.0)
      e_low_i = p_F1 + ((p_B1 - p_F1) / (82.0 - 67.0)) * (t_bins[i] - 67.0)
      q_high_i = q_B2_net + ((q_A2_net - q_B2_net) / (95.0 - 82.0)) * (t_bins[i] - 82.0)
      e_high_i = p_B2 + ((p_A2 - p_B2) / (95.0 - 82.0)) * (t_bins[i] - 82.0)
      if q_low_i >= bL_i
        pLF_i = 1.0 - c_d * (1.0 - (bL_i / q_low_i))
        q_i = bL_i * frac_hours[i]
        e_i = (((bL_i / q_low_i) * e_low_i) / pLF_i) * frac_hours[i]
      elsif (q_low_i < bL_i) && (bL_i < q_high_i)
        x_i = (q_high_i - bL_i) / (q_high_i - q_low_i)
        q_i = (x_i * q_low_i + (1.0 - x_i) * q_high_i) * frac_hours[i]
        e_i = (x_i * e_low_i + (1.0 - x_i) * e_high_i) * frac_hours[i]
      elsif q_high_i <= bL_i
        q_i = q_high_i * frac_hours[i]
        e_i = e_high_i * frac_hours[i]
      end

      e_tot += e_i
      q_tot += q_i
    end

    seer = q_tot / e_tot
    return seer
  end

  def self.calc_seer_4speed(eers, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q)
    n_max = 2
    n_int = 1
    n_min = 0

    wBin = 67.0
    tout_B = 82.0
    tout_E = 87.0
    tout_F = 67.0

    eir_A2 = calc_eir_from_eer(eers[n_max], fan_power_rated)
    eir_B2 = eir_A2 * MathTools.biquadratic(wBin, tout_B, coeff_eir[n_max])

    eir_Av = calc_eir_from_eer(eers[n_int], fan_power_rated)
    eir_Ev = eir_Av * MathTools.biquadratic(wBin, tout_E, coeff_eir[n_int])

    eir_A1 = calc_eir_from_eer(eers[n_min], fan_power_rated)
    eir_B1 = eir_A1 * MathTools.biquadratic(wBin, tout_B, coeff_eir[n_min])
    eir_F1 = eir_A1 * MathTools.biquadratic(wBin, tout_F, coeff_eir[n_min])

    q_A2 = capacity_ratios[n_max]
    q_B2 = q_A2 * MathTools.biquadratic(wBin, tout_B, coeff_q[n_max])
    q_Ev = capacity_ratios[n_int] * MathTools.biquadratic(wBin, tout_E, coeff_q[n_int])
    q_B1 = capacity_ratios[n_min] * MathTools.biquadratic(wBin, tout_B, coeff_q[n_min])
    q_F1 = capacity_ratios[n_min] * MathTools.biquadratic(wBin, tout_F, coeff_q[n_min])

    cfm_Btu_h = 400.0 / 12000.0

    q_A2_net = q_A2 - fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_max]
    q_B2_net = q_B2 - fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_max]
    q_Ev_net = q_Ev - fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_int]
    q_B1_net = q_B1 - fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_min]
    q_F1_net = q_F1 - fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_min]

    p_A2 = (q_A2 * eir_A2) / 3.412 + fan_power_rated * cfm_Btu_h * fanspeed_ratios[n_max]
    p_B2 = (q_B2 * eir_B2) / 3.412 + fan_power_rated * cfm_Btu_h * fanspeed_ratios[n_max]
    p_Ev = (q_Ev * eir_Ev) / 3.412 + fan_power_rated * cfm_Btu_h * fanspeed_ratios[n_int]
    p_B1 = (q_B1 * eir_B1) / 3.412 + fan_power_rated * cfm_Btu_h * fanspeed_ratios[n_min]
    p_F1 = (q_F1 * eir_F1) / 3.412 + fan_power_rated * cfm_Btu_h * fanspeed_ratios[n_min]

    q_k1_87 = q_F1_net + (q_B1_net - q_F1_net) / (82.0 - 67.0) * (87.0 - 67.0)
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

    d = (t_2**2.0 - t_1**2.0) / (t_v**2.0 - t_1**2.0)
    b = (eer_T_1 - eer_T_2 - d * (eer_T_1 - eer_T_v)) / (t_1 - t_2 - d * (t_1 - t_v))
    c = (eer_T_1 - eer_T_2 - b * (t_1 - t_2)) / (t_1**2.0 - t_2**2.0)
    a = eer_T_2 - b * t_2 - c * t_2**2.0

    t_bins = [67.0, 72.0, 77.0, 82.0, 87.0, 92.0, 97.0, 102.0]
    frac_hours = [0.214, 0.231, 0.216, 0.161, 0.104, 0.052, 0.018, 0.004]

    e_tot = 0.0
    q_tot = 0.0
    (0..7).each do |i|
      bL = ((t_bins[i] - 65.0) / (95.0 - 65.0)) * (q_A2_net / 1.1)
      q_k1 = q_F1_net + (q_B1_net - q_F1_net) / (82.0 - 67.0) * (t_bins[i] - 67.0)
      p_k1 = p_F1 + (p_B1 - p_F1) / (82.0 - 67.0) * (t_bins[i] - 67)
      q_k2 = q_B2_net + (q_A2_net - q_B2_net) / (95.0 - 82.0) * (t_bins[i] - 82.0)
      p_k2 = p_B2 + (p_A2 - p_B2) / (95.0 - 82.0) * (t_bins[i] - 82.0)

      if bL <= q_k1
        x_k1 = bL / q_k1
        q_Tj_N = x_k1 * q_k1 * frac_hours[i]
        e_Tj_N = x_k1 * p_k1 * frac_hours[i] / (1.0 - c_d * (1.0 - x_k1))
      elsif (q_k1 < bL) && (bL <= q_k2)
        q_Tj_N = bL * frac_hours[i]
        eer_T_j = a + b * t_bins[i] + c * t_bins[i]**2.0
        e_Tj_N = q_Tj_N / eer_T_j
      else
        q_Tj_N = frac_hours[i] * q_k2
        e_Tj_N = frac_hours[i] * p_k2
      end

      q_tot += q_Tj_N
      e_tot += e_Tj_N
    end

    seer = q_tot / e_tot
    return seer
  end

  def self.calc_cop_heating_1speed(hspf, c_d, fan_power_rated, coeff_eir, coeff_q)
    # Iterate to find rated net cop given HSPF using simple bisection method

    # Initial large bracket to span possible hspf range
    cop_a = 0.1
    cop_b = 10.0

    # Iterate
    iter_max = 100
    tol = 0.0001

    err = 1
    cop_c = (cop_a + cop_b) / 2.0
    (1..iter_max).each do |n|
      f_a = calc_hspf_1speed(cop_a, c_d, fan_power_rated, coeff_eir, coeff_q) - hspf
      f_c = calc_hspf_1speed(cop_c, c_d, fan_power_rated, coeff_eir, coeff_q) - hspf

      if f_c == 0
        return cop_c
      elsif f_a * f_c < 0
        cop_b = cop_c
      else
        cop_a = cop_c
      end

      cop_c = (cop_a + cop_b) / 2.0
      err = (cop_b - cop_a) / 2.0

      if err <= tol
        break
      end
    end

    if err > tol
      fail 'Single-speed heating cop iteration failed to converge.'
    end

    return cop_c
  end

  def self.calc_cops_heating_2speed(hspf, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q)
    # Iterate to find rated net eers given Seer using simple bisection method for two stage air conditioners

    # Initial large bracket of cop to span possible hspf range
    cop_a = 1.0
    cop_b = 10.0

    # Iterate
    iter_max = 100
    tol = 0.0001

    err = 1
    cop_c = (cop_a + cop_b) / 2.0
    (1..iter_max).each do |n|
      cops = calc_cops_from_eir_2speed(cop_a, fan_power_rated)
      f_a = calc_hspf_2speed(cops, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q) - hspf

      cops = calc_cops_from_eir_2speed(cop_c, fan_power_rated)
      f_c = calc_hspf_2speed(cops, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q) - hspf

      if f_c == 0
        return cop_c
      elsif f_a * f_c < 0
        cop_b = cop_c
      else
        cop_a = cop_c
      end

      cop_c = (cop_a + cop_b) / 2.0
      err = (cop_b - cop_a) / 2.0

      if err <= tol
        break
      end
    end

    if err > tol
      fail 'Two-speed heating cop iteration failed to converge.'
    end

    return calc_cops_from_eir_2speed(cop_c, fan_power_rated)
  end

  def self.calc_cops_heating_4speed(hspf, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q)
    # Iterate to find rated net cops given HSPF using simple bisection method for variable speed heat pumps

    # Initial large bracket of cop to span possible hspf range
    cop_a = 1.0
    cop_b = 15.0

    # Iterate
    iter_max = 100
    tol = 0.0001

    err = 1
    cop_c = (cop_a + cop_b) / 2.0
    (1..iter_max).each do |n|
      cops = calc_cops_from_eir_4speed(cop_a, fan_power_rated, calc_type = 'hspf')
      f_a = calc_hspf_4speed(cops, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q) - hspf

      cops = calc_cops_from_eir_4speed(cop_c, fan_power_rated, calc_type = 'hspf')
      f_c = calc_hspf_4speed(cops, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q) - hspf

      if f_c == 0
        return cop_c
      elsif f_a * f_c < 0
        cop_b = cop_c
      else
        cop_a = cop_c
      end

      cop_c = (cop_a + cop_b) / 2.0
      err = (cop_b - cop_a) / 2.0

      if err <= tol
        break
      end
    end

    if err > tol
      fail 'Variable-speed heating cops iteration failed to converge.'
    end

    return calc_cops_from_eir_4speed(cop_c, fan_power_rated, calc_type = 'model')
  end

  def self.calc_hspf_1speed(cop_47, c_d, fan_power_rated, coeff_eir, coeff_q)
    eir_47 = calc_eir_from_cop(cop_47, fan_power_rated)
    eir_35 = eir_47 * MathTools.biquadratic(70.0, 35.0, coeff_eir[0])
    eir_17 = eir_47 * MathTools.biquadratic(70.0, 17.0, coeff_eir[0])

    q_47 = 1.0
    q_35 = 0.7519
    q_17 = q_47 * MathTools.biquadratic(70.0, 17.0, coeff_q[0])

    cfm_Btu_h = 400.0 / 12000.0

    q_47_net = q_47 + fan_power_rated * 3.412 * cfm_Btu_h
    q_35_net = q_35 + fan_power_rated * 3.412 * cfm_Btu_h
    q_17_net = q_17 + fan_power_rated * 3.412 * cfm_Btu_h

    p_47 = (q_47 * eir_47) / 3.412 + fan_power_rated * cfm_Btu_h
    p_35 = (q_35 * eir_35) / 3.412 + fan_power_rated * cfm_Btu_h
    p_17 = (q_17 * eir_17) / 3.412 + fan_power_rated * cfm_Btu_h

    t_bins = [62.0, 57.0, 52.0, 47.0, 42.0, 37.0, 32.0, 27.0, 22.0, 17.0, 12.0, 7.0, 2.0, -3.0, -8.0]
    frac_hours = [0.132, 0.111, 0.103, 0.093, 0.100, 0.109, 0.126, 0.087, 0.055, 0.036, 0.026, 0.013, 0.006, 0.002, 0.001]

    designtemp = 5.0
    t_off = 10.0
    t_on = 14.0
    ptot = 0.0
    rHtot = 0.0
    bLtot = 0.0
    dHRmin = q_47
    (0..14).each do |i|
      bL = ((65.0 - t_bins[i]) / (65.0 - designtemp)) * 0.77 * dHRmin

      if (t_bins[i] > 17.0) && (t_bins[i] < 45.0)
        q_h = q_17_net + (((q_35_net - q_17_net) * (t_bins[i] - 17.0)) / (35.0 - 17.0))
        p_h = p_17 + (((p_35 - p_17) * (t_bins[i] - 17.0)) / (35.0 - 17.0))
      else
        q_h = q_17_net + (((q_47_net - q_17_net) * (t_bins[i] - 17.0)) / (47.0 - 17.0))
        p_h = p_17 + (((p_47 - p_17) * (t_bins[i] - 17.0)) / (47.0 - 17.0))
      end

      x_t = [bL / q_h, 1.0].min

      pLF = 1.0 - (c_d * (1.0 - x_t))
      if (t_bins[i] <= t_off) || (q_h / (3.412 * p_h) < 1.0)
        sigma_t = 0.0
      elsif (t_off < t_bins[i]) && (t_bins[i] <= t_on) && (q_h / (p_h * 3.412) >= 1.0)
        sigma_t = 0.5
      elsif (t_bins[i] > t_on) && (q_h / (3.412 * p_h) >= 1.0)
        sigma_t = 1.0
      end

      p_h_i = (x_t * p_h * sigma_t / pLF) * frac_hours[i]
      rH_i = ((bL - (x_t * q_h * sigma_t)) / 3.412) * frac_hours[i]
      bL_i = bL * frac_hours[i]
      ptot += p_h_i
      rHtot += rH_i
      bLtot += bL_i
    end

    hspf = bLtot / (ptot + rHtot)
    return hspf
  end

  def self.calc_hspf_2speed(cops, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q)
    eir_47_H = calc_eir_from_cop(cops[1], fan_power_rated)
    eir_35_H = eir_47_H * MathTools.biquadratic(70.0, 35.0, coeff_eir[1])
    eir_17_H = eir_47_H * MathTools.biquadratic(70.0, 17.0, coeff_eir[1])

    eir_47_L = calc_eir_from_cop(cops[0], fan_power_rated)
    eir_62_L = eir_47_L * MathTools.biquadratic(70.0, 62.0, coeff_eir[0])
    eir_35_L = eir_47_L * MathTools.biquadratic(70.0, 35.0, coeff_eir[0])
    eir_17_L = eir_47_L * MathTools.biquadratic(70.0, 17.0, coeff_eir[0])

    q_H47 = 1.0
    q_H35 = q_H47 * MathTools.biquadratic(70.0, 35.0, coeff_q[1])
    q_H17 = q_H47 * MathTools.biquadratic(70.0, 17.0, coeff_q[1])

    q_L47 = q_H47 * capacity_ratios[0]
    q_L62 = q_L47 * MathTools.biquadratic(70.0, 62.0, coeff_q[0])
    q_L35 = q_L47 * MathTools.biquadratic(70.0, 35.0, coeff_q[0])
    q_L17 = q_L47 * MathTools.biquadratic(70.0, 17.0, coeff_q[0])

    cfm_Btu_h = 400.0 / 12000.0

    q_H47_net = q_H47 + fan_power_rated * 3.412 * cfm_Btu_h
    q_H35_net = q_H35 + fan_power_rated * 3.412 * cfm_Btu_h
    q_H17_net = q_H17 + fan_power_rated * 3.412 * cfm_Btu_h
    q_L62_net = q_L62 + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[0]
    q_L47_net = q_L47 + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[0]
    q_L35_net = q_L35 + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[0]
    q_L17_net = q_L17 + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[0]

    p_H47 = (q_H47 * eir_47_H) / 3.412 + fan_power_rated * cfm_Btu_h
    p_H35 = (q_H35 * eir_35_H) / 3.412 + fan_power_rated * cfm_Btu_h
    p_H17 = (q_H17 * eir_17_H) / 3.412 + fan_power_rated * cfm_Btu_h
    p_L62 = (q_L62 * eir_62_L) / 3.412 + fan_power_rated * cfm_Btu_h * fanspeed_ratios[0]
    p_L47 = (q_L47 * eir_47_L) / 3.412 + fan_power_rated * cfm_Btu_h * fanspeed_ratios[0]
    p_L35 = (q_L35 * eir_35_L) / 3.412 + fan_power_rated * cfm_Btu_h * fanspeed_ratios[0]
    p_L17 = (q_L17 * eir_17_L) / 3.412 + fan_power_rated * cfm_Btu_h * fanspeed_ratios[0]

    t_bins = [62.0, 57.0, 52.0, 47.0, 42.0, 37.0, 32.0, 27.0, 22.0, 17.0, 12.0, 7.0, 2.0, -3.0, -8.0]
    frac_hours = [0.132, 0.111, 0.103, 0.093, 0.100, 0.109, 0.126, 0.087, 0.055, 0.036, 0.026, 0.013, 0.006, 0.002, 0.001]

    designtemp = 5.0
    t_off = 10.0
    t_on = 14.0
    ptot = 0.0
    rHtot = 0.0
    bLtot = 0.0
    dHRmin = q_H47
    (0..14).each do |i|
      bL = ((65.0 - t_bins[i]) / (65.0 - designtemp)) * 0.77 * dHRmin

      if (17.0 < t_bins[i]) && (t_bins[i] < 45.0)
        q_h = q_H17_net + (((q_H35_net - q_H17_net) * (t_bins[i] - 17.0)) / (35.0 - 17.0))
        p_h = p_H17 + (((p_H35 - p_H17) * (t_bins[i] - 17.0)) / (35.0 - 17.0))
      else
        q_h = q_H17_net + (((q_H47_net - q_H17_net) * (t_bins[i] - 17.0)) / (47.0 - 17.0))
        p_h = p_H17 + (((p_H47 - p_H17) * (t_bins[i] - 17.0)) / (47.0 - 17.0))
      end

      if t_bins[i] >= 40.0
        q_l = q_L47_net + (((q_L62_net - q_L47_net) * (t_bins[i] - 47.0)) / (62.0 - 47.0))
        p_l = p_L47 + (((p_L62 - p_L47) * (t_bins[i] - 47.0)) / (62.0 - 47.0))
      elsif (17.0 <= t_bins[i]) && (t_bins[i] < 40.0)
        q_l = q_L17_net + (((q_L35_net - q_L17_net) * (t_bins[i] - 17.0)) / (35.0 - 17.0))
        p_l = p_L17 + (((p_L35 - p_L17) * (t_bins[i] - 17.0)) / (35.0 - 17.0))
      else
        q_l = q_L17_net + (((q_L47_net - q_L17_net) * (t_bins[i] - 17.0)) / (47.0 - 17.0))
        p_l = p_L17 + (((p_L47 - p_L17) * (t_bins[i] - 17.0)) / (47.0 - 17.0))
      end

      x_t_h = [bL / q_h, 1.0].min
      x_t_l = [bL / q_l, 1.0].min
      pLF = 1.0 - (c_d * (1.0 - x_t_l))
      if (t_bins[i] <= t_off) || (q_h / (p_h * 3.412) < 1.0)
        sigma_t_h = 0.0
      elsif (t_off < t_bins[i]) && (t_bins[i] <= t_on) && (q_h / (p_h * 3.412) >= 1.0)
        sigma_t_h = 0.5
      elsif (t_bins[i] > t_on) && (q_h / (p_h * 3.412) >= 1.0)
        sigma_t_h = 1.0
      end

      if t_bins[i] <= t_off
        sigma_t_l = 0.0
      elsif (t_off < t_bins[i]) && (t_bins[i] <= t_on)
        sigma_t_l = 0.5
      elsif t_bins[i] > t_on
        sigma_t_l = 1.0
      end

      if q_l > bL
        p_h_i = (x_t_l * p_l * sigma_t_l / pLF) * frac_hours[i]
        rH_i = (bL * (1.0 - sigma_t_l)) / 3.412 * frac_hours[i]
      elsif (q_l < bL) && (q_h > bL)
        x_t_l = ((q_h - bL) / (q_h - q_l))
        x_t_h = 1.0 - x_t_l
        p_h_i = (x_t_l * p_l + x_t_h * p_h) * sigma_t_l * frac_hours[i]
        rH_i = (bL * (1.0 - sigma_t_l)) / 3.412 * frac_hours[i]
      elsif q_h <= bL
        p_h_i = p_h * sigma_t_h * frac_hours[i]
        rH_i = (bL - (q_h * sigma_t_l)) / 3.412 * frac_hours[i]
      end

      bL_i = bL * frac_hours[i]
      ptot += p_h_i
      rHtot += rH_i
      bLtot += bL_i
    end

    hspf = bLtot / (ptot + rHtot)
    return hspf
  end

  def self.calc_hspf_4speed(cop_47, c_d, capacity_ratios, fanspeed_ratios, fan_power_rated, coeff_eir, coeff_q)
    n_max = 2
    n_int = 1
    n_min = 0

    tin = 70.0
    tout_3 = 17.0
    tout_2 = 35.0
    tout_0 = 62.0

    eir_H1_2 = calc_eir_from_cop(cop_47[n_max], fan_power_rated)
    eir_H3_2 = eir_H1_2 * MathTools.biquadratic(tin, tout_3, coeff_eir[n_max])

    eir_adjv = calc_eir_from_cop(cop_47[n_int], fan_power_rated)
    eir_H2_v = eir_adjv * MathTools.biquadratic(tin, tout_2, coeff_eir[n_int])

    eir_H1_1 = calc_eir_from_cop(cop_47[n_min], fan_power_rated)
    eir_H0_1 = eir_H1_1 * MathTools.biquadratic(tin, tout_0, coeff_eir[n_min])

    q_H1_2 = capacity_ratios[n_max]
    q_H3_2 = q_H1_2 * MathTools.biquadratic(tin, tout_3, coeff_q[n_max])

    q_H2_v = capacity_ratios[n_int] * MathTools.biquadratic(tin, tout_2, coeff_q[n_int])

    q_H1_1 = capacity_ratios[n_min]
    q_H0_1 = q_H1_1 * MathTools.biquadratic(tin, tout_0, coeff_q[n_min])

    cfm_Btu_h = 400.0 / 12000.0

    q_H1_2_net = q_H1_2 + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_max]
    q_H3_2_net = q_H3_2 + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_max]
    q_H2_v_net = q_H2_v + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_int]
    q_H1_1_net = q_H1_1 + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_min]
    q_H0_1_net = q_H0_1 + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_min]

    p_H1_2 = q_H1_2 * eir_H1_2 + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_max]
    p_H3_2 = q_H3_2 * eir_H3_2 + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_max]
    p_H2_v = q_H2_v * eir_H2_v + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_int]
    p_H1_1 = q_H1_1 * eir_H1_1 + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_min]
    p_H0_1 = q_H0_1 * eir_H0_1 + fan_power_rated * 3.412 * cfm_Btu_h * fanspeed_ratios[n_min]

    q_H35_2 = 0.9 * (q_H3_2_net + 0.6 * (q_H1_2_net - q_H3_2_net))
    p_H35_2 = 0.985 * (p_H3_2 + 0.6 * (p_H1_2 - p_H3_2))
    q_H35_1 = q_H1_1_net + (q_H0_1_net - q_H1_1_net) / (62.0 - 47.0) * (35.0 - 47.0)
    p_H35_1 = p_H1_1 + (p_H0_1 - p_H1_1) / (62.0 - 47.0) * (35.0 - 47.0)
    n_Q = (q_H2_v_net - q_H35_1) / (q_H35_2 - q_H35_1)
    m_Q = (q_H0_1_net - q_H1_1_net) / (62.0 - 47.0) * (1.0 - n_Q) + n_Q * (q_H35_2 - q_H3_2_net) / (35.0 - 17.0)
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
    t_v = (35.0 * m_Q + 65 * c_T_v_3 - c_T_v_1) / (m_Q + c_T_v_3)
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

    d = (t_3**2.0 - t_4**2.0) / (t_v**2.0 - t_4**2.0)
    b = (cop_T4_2 - cop_T3_1 - d * (cop_T4_2 - cop_Tv_v)) / (t_4 - t_3 - d * (t_4 - t_v))
    c = (cop_T4_2 - cop_T3_1 - b * (t_4 - t_3)) / (t_4**2.0 - t_3**2.0)
    a = cop_T4_2 - b * t_4 - c * t_4**2.0

    t_bins = [62.0, 57.0, 52.0, 47.0, 42.0, 37.0, 32.0, 27.0, 22.0, 17.0, 12.0, 7.0, 2.0, -3.0, -8.0]
    frac_hours = [0.132, 0.111, 0.103, 0.093, 0.100, 0.109, 0.126, 0.087, 0.055, 0.036, 0.026, 0.013, 0.006, 0.002, 0.001]

    t_off = 10.0
    t_on = t_off + 4
    etot = 0.0
    bLtot = 0.0
    (0..14).each do |i|
      bL = ((65.0 - t_bins[i]) / (65.0 - t_OD)) * 0.77 * dHR

      q_1 = q_H1_1_net + (q_H0_1_net - q_H1_1_net) / (62.0 - 47.0) * (t_bins[i] - 47.0)
      p_1 = p_H1_1 + (p_H0_1 - p_H1_1) / (62.0 - 47.0) * (t_bins[i] - 47.0)

      if (t_bins[i] <= 17.0) || (t_bins[i] >= 45.0)
        q_2 = q_H3_2_net + (q_H1_2_net - q_H3_2_net) * (t_bins[i] - 17.0) / (47.0 - 17.0)
        p_2 = p_H3_2 + (p_H1_2 - p_H3_2) * (t_bins[i] - 17.0) / (47.0 - 17.0)
      else
        q_2 = q_H3_2_net + (q_H35_2 - q_H3_2_net) * (t_bins[i] - 17.0) / (35.0 - 17.0)
        p_2 = p_H3_2 + (p_H35_2 - p_H3_2) * (t_bins[i] - 17.0) / (35.0 - 17.0)
      end

      if t_bins[i] <= t_off
        delta = 0.0
      elsif t_bins[i] >= t_on
        delta = 1.0
      else
        delta = 0.5
      end

      if bL <= q_1
        x_1 = bL / q_1
        e_Tj_n = delta * x_1 * p_1 * frac_hours[i] / (1.0 - c_d * (1.0 - x_1))
      elsif (q_1 < bL) && (bL <= q_2)
        cop_T_j = a + b * t_bins[i] + c * t_bins[i]**2.0
        e_Tj_n = delta * frac_hours[i] * bL / cop_T_j + (1.0 - delta) * bL * (frac_hours[i])
      else
        e_Tj_n = delta * frac_hours[i] * p_2 + frac_hours[i] * (bL - delta * q_2)
      end

      bLtot += frac_hours[i] * bL
      etot += e_Tj_n
    end

    hspf = bLtot / (etot / 3.412)
    return hspf
  end

  def self.set_cool_rated_cfm_per_ton(cooling_system)
    clg_ap = cooling_system.additional_properties

    if cooling_system.is_a?(HPXML::CoolingSystem) && (cooling_system.cooling_system_type == HPXML::HVACTypeRoomAirConditioner)
      clg_ap.cool_rated_cfm_per_ton = [312.0] # medium speed
    else
      clg_ap.cool_rated_cfm_per_ton = []
      clg_ap.cool_fan_speed_ratios.each_with_index do |fanspeed_ratio, i|
        clg_ap.cool_rated_cfm_per_ton << fanspeed_ratio * clg_ap.cool_rated_airflow_rate / clg_ap.cool_capacity_ratios[i]
      end
    end
  end

  def self.set_heat_rated_cfm_per_ton(heating_system)
    htg_ap = heating_system.additional_properties

    if heating_system.is_a? HPXML::HeatingSystem
      htg_ap.heat_rated_cfm_per_ton = [350.0]
    else
      htg_ap.heat_rated_cfm_per_ton = []
      htg_ap.heat_fan_speed_ratios.each_with_index do |fanspeed_ratio, i|
        htg_ap.heat_rated_cfm_per_ton << fanspeed_ratio * htg_ap.heat_rated_airflow_rate / htg_ap.heat_capacity_ratios[i]
      end
    end
  end

  def self.create_curve_biquadratic_constant(model)
    curve = OpenStudio::Model::CurveBiquadratic.new(model)
    curve.setName('ConstantBiquadratic')
    curve.setCoefficient1Constant(1)
    curve.setCoefficient2x(0)
    curve.setCoefficient3xPOW2(0)
    curve.setCoefficient4y(0)
    curve.setCoefficient5yPOW2(0)
    curve.setCoefficient6xTIMESY(0)
    curve.setMinimumValueofx(-100)
    curve.setMaximumValueofx(100)
    curve.setMinimumValueofy(-100)
    curve.setMaximumValueofy(100)
    return curve
  end

  def self.create_curve_quadratic_constant(model)
    curve = OpenStudio::Model::CurveQuadratic.new(model)
    curve.setName('ConstantQuadratic')
    curve.setCoefficient1Constant(1)
    curve.setCoefficient2x(0)
    curve.setCoefficient3xPOW2(0)
    curve.setMinimumValueofx(-100)
    curve.setMaximumValueofx(100)
    curve.setMinimumCurveOutput(-100)
    curve.setMaximumCurveOutput(100)
    return curve
  end

  def self.create_curve_cubic_constant(model)
    curve = OpenStudio::Model::CurveCubic.new(model)
    curve.setName('ConstantCubic')
    curve.setCoefficient1Constant(1)
    curve.setCoefficient2x(0)
    curve.setCoefficient3xPOW2(0)
    curve.setCoefficient4xPOW3(0)
    curve.setMinimumValueofx(-100)
    curve.setMaximumValueofx(100)
    return curve
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

  def self.create_curve_biquadratic(model, coeff, name, min_x, max_x, min_y, max_y)
    curve = OpenStudio::Model::CurveBiquadratic.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2x(coeff[1])
    curve.setCoefficient3xPOW2(coeff[2])
    curve.setCoefficient4y(coeff[3])
    curve.setCoefficient5yPOW2(coeff[4])
    curve.setCoefficient6xTIMESY(coeff[5])
    curve.setMinimumValueofx(min_x)
    curve.setMaximumValueofx(max_x)
    curve.setMinimumValueofy(min_y)
    curve.setMaximumValueofy(max_y)
    return curve
  end

  def self.create_curve_bicubic(model, coeff, name, min_x, max_x, min_y, max_y)
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
    curve.setMinimumValueofx(min_x)
    curve.setMaximumValueofx(max_x)
    curve.setMinimumValueofy(min_y)
    curve.setMaximumValueofy(max_y)
    return curve
  end

  def self.create_curve_quadratic(model, coeff, name, min_x, max_x, min_y, max_y, is_dimensionless = false)
    curve = OpenStudio::Model::CurveQuadratic.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2x(coeff[1])
    curve.setCoefficient3xPOW2(coeff[2])
    curve.setMinimumValueofx(min_x)
    curve.setMaximumValueofx(max_x)
    if not min_y.nil?
      curve.setMinimumCurveOutput(min_y)
    end
    if not max_y.nil?
      curve.setMaximumCurveOutput(max_y)
    end
    if is_dimensionless
      curve.setInputUnitTypeforX('Dimensionless')
      curve.setOutputUnitType('Dimensionless')
    end
    return curve
  end

  def self.create_curve_cubic(model, coeff, name, min_x, max_x, min_y, max_y)
    curve = OpenStudio::Model::CurveCubic.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2x(coeff[1])
    curve.setCoefficient3xPOW2(coeff[2])
    curve.setCoefficient4xPOW3(coeff[3])
    curve.setMinimumValueofx(min_x)
    curve.setMaximumValueofx(max_x)
    curve.setMinimumCurveOutput(min_y)
    curve.setMaximumCurveOutput(max_y)
    return curve
  end

  def self.create_curve_exponent(model, coeff, name, min_x, max_x)
    curve = OpenStudio::Model::CurveExponent.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2Constant(coeff[1])
    curve.setCoefficient3Constant(coeff[2])
    curve.setMinimumValueofx(min_x)
    curve.setMaximumValueofx(max_x)
    return curve
  end

  def self.create_curve_quad_linear(model, coeff, name)
    curve = OpenStudio::Model::CurveQuadLinear.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2w(coeff[1])
    curve.setCoefficient3x(coeff[2])
    curve.setCoefficient4y(coeff[3])
    curve.setCoefficient5z(coeff[4])
    return curve
  end

  def self.create_curve_quint_linear(model, coeff, name)
    curve = OpenStudio::Model::CurveQuintLinear.new(model)
    curve.setName(name)
    curve.setCoefficient1Constant(coeff[0])
    curve.setCoefficient2v(coeff[1])
    curve.setCoefficient3w(coeff[2])
    curve.setCoefficient4x(coeff[3])
    curve.setCoefficient5y(coeff[4])
    curve.setCoefficient6z(coeff[5])
    return curve
  end

  def self.create_dx_cooling_coil(model, obj_name, cooling_system)
    clg_ap = cooling_system.additional_properties

    if cooling_system.is_a? HPXML::CoolingSystem
      clg_type = cooling_system.cooling_system_type
    elsif cooling_system.is_a? HPXML::HeatPump
      clg_type = cooling_system.heat_pump_type
    end

    if clg_ap.num_speeds > 1
      constant_biquadratic = create_curve_biquadratic_constant(model)
    end

    clg_coil = nil

    for i in 0..(clg_ap.num_speeds - 1)
      cap_ft_spec_si = convert_curve_biquadratic(clg_ap.cool_cap_ft_spec[i])
      eir_ft_spec_si = convert_curve_biquadratic(clg_ap.cool_eir_ft_spec[i])
      cap_ft_curve = create_curve_biquadratic(model, cap_ft_spec_si, "Cool-CAP-fT#{i + 1}", 13.88, 23.88, 18.33, 51.66)
      eir_ft_curve = create_curve_biquadratic(model, eir_ft_spec_si, "Cool-EIR-fT#{i + 1}", 13.88, 23.88, 18.33, 51.66)
      plf_fplr_curve = create_curve_quadratic(model, clg_ap.cool_plf_fplr_spec[i], "Cool-PLF-fPLR#{i + 1}", 0, 1, 0.7, 1)
      cap_fff_curve = create_curve_quadratic(model, clg_ap.cool_cap_fflow_spec[i], "Cool-CAP-fFF#{i + 1}", 0, 2, 0, 2)
      eir_fff_curve = create_curve_quadratic(model, clg_ap.cool_eir_fflow_spec[i], "Cool-EIR-fFF#{i + 1}", 0, 2, 0, 2)

      if clg_ap.num_speeds == 1
        clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule, cap_ft_curve, cap_fff_curve, eir_ft_curve, eir_fff_curve, plf_fplr_curve)
        clg_coil.setRatedEvaporatorFanPowerPerVolumeFlowRate(clg_ap.fan_power_rated / UnitConversions.convert(1.0, 'cfm', 'm^3/s'))
        if not clg_ap.crankcase_temp.nil?
          clg_coil.setMaximumOutdoorDryBulbTemperatureForCrankcaseHeaterOperation(UnitConversions.convert(clg_ap.crankcase_temp, 'F', 'C'))
        end
        clg_coil.setRatedCOP(1.0 / clg_ap.cool_rated_eirs[i])
        clg_coil.setRatedSensibleHeatRatio(clg_ap.cool_rated_shrs_gross[i])
        clg_coil.setNominalTimeForCondensateRemovalToBegin(1000.0)
        clg_coil.setRatioOfInitialMoistureEvaporationRateAndSteadyStateLatentCapacity(1.5)
        clg_coil.setMaximumCyclingRate(3.0)
        clg_coil.setLatentCapacityTimeConstant(45.0)
        clg_coil.setRatedTotalCoolingCapacity(UnitConversions.convert(cooling_system.cooling_capacity, 'Btu/hr', 'W'))
        clg_coil.setRatedAirFlowRate(calc_rated_airflow(cooling_system.cooling_capacity, clg_ap.cool_rated_cfm_per_ton[0], 1.0))
      else
        if clg_coil.nil?
          clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
          clg_coil.setApplyPartLoadFractiontoSpeedsGreaterthan1(false)
          clg_coil.setApplyLatentDegradationtoSpeedsGreaterthan1(false)
          clg_coil.setFuelType(EPlus::FuelTypeElectricity)
          clg_coil.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
          if not clg_ap.crankcase_temp.nil?
            clg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(UnitConversions.convert(clg_ap.crankcase_temp, 'F', 'C'))
          end
        end
        stage = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model, cap_ft_curve, cap_fff_curve, eir_ft_curve, eir_fff_curve, plf_fplr_curve, constant_biquadratic)
        stage.setGrossRatedCoolingCOP(1.0 / clg_ap.cool_rated_eirs[i])
        stage.setGrossRatedSensibleHeatRatio(clg_ap.cool_rated_shrs_gross[i])
        stage.setNominalTimeforCondensateRemovaltoBegin(1000)
        stage.setRatioofInitialMoistureEvaporationRateandSteadyStateLatentCapacity(1.5)
        stage.setRatedWasteHeatFractionofPowerInput(0.2)
        stage.setMaximumCyclingRate(3.0)
        stage.setLatentCapacityTimeConstant(45.0)
        stage.setGrossRatedTotalCoolingCapacity(UnitConversions.convert(cooling_system.cooling_capacity, 'Btu/hr', 'W') * clg_ap.cool_capacity_ratios[i])
        stage.setRatedAirFlowRate(calc_rated_airflow(cooling_system.cooling_capacity, clg_ap.cool_rated_cfm_per_ton[i], clg_ap.cool_capacity_ratios[i]))
        clg_coil.addStage(stage)
      end
    end

    clg_coil.setName(obj_name + ' clg coil')
    clg_coil.setCondenserType('AirCooled')
    clg_coil.setCrankcaseHeaterCapacity(UnitConversions.convert(clg_ap.crankcase_kw, 'kW', 'W'))

    return clg_coil
  end

  def self.create_dx_heating_coil(model, obj_name, heating_system)
    htg_ap = heating_system.additional_properties

    if heating_system.is_a? HPXML::HeatingSystem
      htg_type = heating_system.heating_system_type
    elsif heating_system.is_a? HPXML::HeatPump
      htg_type = heating_system.heat_pump_type
    end

    if htg_ap.num_speeds > 1
      constant_biquadratic = create_curve_biquadratic_constant(model)
    end

    htg_coil = nil

    for i in 0..(htg_ap.num_speeds - 1)
      cap_ft_spec_si = convert_curve_biquadratic(htg_ap.heat_cap_ft_spec[i])
      eir_ft_spec_si = convert_curve_biquadratic(htg_ap.heat_eir_ft_spec[i])
      cap_ft_curve = create_curve_biquadratic(model, cap_ft_spec_si, "Heat-CAP-fT#{i + 1}", -100, 100, -100, 100)
      eir_ft_curve = create_curve_biquadratic(model, eir_ft_spec_si, "Heat-EIR-fT#{i + 1}", -100, 100, -100, 100)
      plf_fplr_curve = create_curve_quadratic(model, htg_ap.heat_plf_fplr_spec[i], "Heat-PLF-fPLR#{i + 1}", 0, 1, 0.7, 1)
      cap_fff_curve = create_curve_quadratic(model, htg_ap.heat_cap_fflow_spec[i], "Heat-CAP-fFF#{i + 1}", 0, 2, 0, 2)
      eir_fff_curve = create_curve_quadratic(model, htg_ap.heat_eir_fflow_spec[i], "Heat-EIR-fFF#{i + 1}", 0, 2, 0, 2)

      if htg_ap.num_speeds == 1
        htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule, cap_ft_curve, cap_fff_curve, eir_ft_curve, eir_fff_curve, plf_fplr_curve)
        htg_coil.setRatedSupplyFanPowerPerVolumeFlowRate(htg_ap.fan_power_rated / UnitConversions.convert(1.0, 'cfm', 'm^3/s'))
        htg_coil.setRatedCOP(1.0 / htg_ap.heat_rated_eirs[i])
        if not htg_ap.crankcase_temp.nil?
          htg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(UnitConversions.convert(htg_ap.crankcase_temp, 'F', 'C'))
        end
        htg_coil.setRatedTotalHeatingCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W'))
        htg_coil.setRatedAirFlowRate(calc_rated_airflow(heating_system.heating_capacity, htg_ap.heat_rated_cfm_per_ton[0], 1.0))
      else
        if htg_coil.nil?
          htg_coil = OpenStudio::Model::CoilHeatingDXMultiSpeed.new(model)
          htg_coil.setFuelType(EPlus::FuelTypeElectricity)
          htg_coil.setApplyPartLoadFractiontoSpeedsGreaterthan1(false)
          htg_coil.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
          if not htg_ap.crankcase_temp.nil?
            htg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(UnitConversions.convert(htg_ap.crankcase_temp, 'F', 'C'))
          end
        end
        stage = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model, cap_ft_curve, cap_fff_curve, eir_ft_curve, eir_fff_curve, plf_fplr_curve, constant_biquadratic)
        stage.setGrossRatedHeatingCOP(1.0 / htg_ap.heat_rated_eirs[i])
        stage.setRatedWasteHeatFractionofPowerInput(0.2)
        stage.setGrossRatedHeatingCapacity(UnitConversions.convert(heating_system.heating_capacity, 'Btu/hr', 'W') * htg_ap.heat_capacity_ratios[i])
        stage.setRatedAirFlowRate(calc_rated_airflow(heating_system.heating_capacity, htg_ap.heat_rated_cfm_per_ton[i], htg_ap.heat_capacity_ratios[i]))
        htg_coil.addStage(stage)
      end
    end

    htg_coil.setName(obj_name + ' htg coil')
    htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(UnitConversions.convert(htg_ap.hp_min_temp, 'F', 'C'))
    htg_coil.setMaximumOutdoorDryBulbTemperatureforDefrostOperation(UnitConversions.convert(40.0, 'F', 'C'))
    defrost_eir_curve = create_curve_biquadratic(model, [0.1528, 0, 0, 0, 0, 0], 'Defrosteir', -100, 100, -100, 100) # Heating defrost curve for reverse cycle
    htg_coil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(defrost_eir_curve)
    htg_coil.setDefrostStrategy('ReverseCycle')
    htg_coil.setDefrostControl('Timed')
    if heating_system.fraction_heat_load_served == 0
      htg_coil.setResistiveDefrostHeaterCapacity(0)
    end
    htg_coil.setCrankcaseHeaterCapacity(UnitConversions.convert(htg_ap.crankcase_kw, 'kW', 'W'))

    return htg_coil
  end

  def self.set_cool_rated_eirs(cooling_system)
    clg_ap = cooling_system.additional_properties

    clg_ap.cool_rated_eirs = []
    (0...clg_ap.num_speeds).to_a.each do |speed|
      clg_ap.cool_rated_eirs << calc_eir_from_eer(clg_ap.cool_eers[speed], clg_ap.fan_power_rated)
    end
  end

  def self.set_heat_rated_eirs(heating_system)
    htg_ap = heating_system.additional_properties

    htg_ap.heat_rated_eirs = []
    (0...htg_ap.num_speeds).to_a.each do |speed|
      htg_ap.heat_rated_eirs << calc_eir_from_cop(htg_ap.heat_cops[speed], htg_ap.fan_power_rated)
    end
  end

  def self.set_cool_rated_shrs_gross(cooling_system)
    clg_ap = cooling_system.additional_properties

    # Convert SHRs from net to gross.
    if cooling_system.is_a?(HPXML::CoolingSystem) && (cooling_system.cooling_system_type == HPXML::HVACTypeRoomAirConditioner)
      clg_ap.cool_rated_shrs_gross = [cooling_system.cooling_shr] # We don't model the fan separately, so set gross == net
    else
      clg_ap.cool_rated_shrs_gross = []
      (0...clg_ap.num_speeds).to_a.each do |speed|
        qtot_net_nominal = 12000.0
        qsens_net_nominal = qtot_net_nominal * clg_ap.cool_rated_shrs_net[speed]
        qtot_gross_nominal = qtot_net_nominal + UnitConversions.convert(clg_ap.cool_rated_cfm_per_ton[speed] * clg_ap.fan_power_rated, 'Wh', 'Btu')
        qsens_gross_nominal = qsens_net_nominal + UnitConversions.convert(clg_ap.cool_rated_cfm_per_ton[speed] * clg_ap.fan_power_rated, 'Wh', 'Btu')
        clg_ap.cool_rated_shrs_gross << (qsens_gross_nominal / qtot_gross_nominal)

        # Make sure SHR's are in valid range based on E+ model limits.
        # The following correlation was developed by Jon Winkler to test for maximum allowed SHR based on the 300 - 450 cfm/ton limits in E+
        max_shr = 0.3821066 + 0.001050652 * clg_ap.cool_rated_cfm_per_ton[speed] - 0.01
        clg_ap.cool_rated_shrs_gross[speed] = [clg_ap.cool_rated_shrs_gross[speed], max_shr].min
        min_shr = 0.60 # Approximate minimum SHR such that an ADP exists
        clg_ap.cool_rated_shrs_gross[speed] = [clg_ap.cool_rated_shrs_gross[speed], min_shr].max
      end
    end
  end

  def self.calc_plr_coefficients(c_d)
    return [(1.0 - c_d), c_d, 0.0] # Linear part load model
  end

  def self.set_cool_c_d(cooling_system, num_speeds)
    clg_ap = cooling_system.additional_properties

    # Degradation coefficient for cooling
    if cooling_system.is_a?(HPXML::CoolingSystem) && (cooling_system.cooling_system_type == HPXML::HVACTypeRoomAirConditioner)
      clg_ap.cool_c_d = 0.22
    elsif num_speeds == 1
      if cooling_system.cooling_efficiency_seer < 13.0
        clg_ap.cool_c_d = 0.20
      else
        clg_ap.cool_c_d = 0.07
      end
    elsif num_speeds == 2
      clg_ap.cool_c_d = 0.11
    elsif num_speeds >= 4
      clg_ap.cool_c_d = 0.25
    end

    # PLF curve
    clg_ap.cool_plf_fplr_spec = [calc_plr_coefficients(clg_ap.cool_c_d)] * num_speeds
  end

  def self.set_heat_c_d(heating_system, num_speeds)
    htg_ap = heating_system.additional_properties

    # Degradation coefficient for heating
    if num_speeds == 1
      if heating_system.heating_efficiency_hspf < 7.0
        htg_ap.heat_c_d =  0.20
      else
        htg_ap.heat_c_d =  0.11
      end
    elsif num_speeds == 2
      htg_ap.heat_c_d =  0.11
    elsif num_speeds == 4
      htg_ap.heat_c_d =  0.24
    elsif num_speeds == 10 # mini-split heat pump
      htg_ap.heat_c_d =  0.40
    end

    htg_ap.heat_plf_fplr_spec = [calc_plr_coefficients(htg_ap.heat_c_d)] * num_speeds
  end

  def self.calc_ceer_from_eer(cooling_system)
    return if cooling_system.cooling_system_type != HPXML::HVACTypeRoomAirConditioner

    # Reference: http://documents.dps.ny.gov/public/Common/ViewDoc.aspx?DocRefId=%7BB6A57FC0-6376-4401-92BD-D66EC1930DCF%7D
    return cooling_system.cooling_efficiency_eer / 1.01
  end

  def self.set_fan_power_rated(hvac_system)
    hvac_ap = hvac_system.additional_properties

    if hvac_system.distribution_system.nil?
      # Ductless, installed and rated value should be equal
      hvac_ap.fan_power_rated = hvac_system.fan_watts_per_cfm # W/cfm
    elsif (hvac_system.is_a?(HPXML::CoolingSystem) && (hvac_system.cooling_system_type == HPXML::HVACTypeMiniSplitAirConditioner)) ||
          (hvac_system.is_a?(HPXML::HeatPump) && (hvac_system.heat_pump_type == HPXML::HVACTypeHeatPumpMiniSplit))
      hvac_ap.fan_power_rated = 0.18 # W/cfm
    elsif hvac_system.cooling_efficiency_seer <= 15
      hvac_ap.fan_power_rated = 0.365 # W/cfm
    else
      hvac_ap.fan_power_rated = 0.14 # W/cfm
    end
  end

  def self.set_fan_power(fan, fan_watts_per_cfm)
    if fan_watts_per_cfm > 0
      fan_eff = 0.75 # Overall Efficiency of the Fan, Motor and Drive
      pressure_rise = fan_eff * fan_watts_per_cfm / UnitConversions.convert(1.0, 'cfm', 'm^3/s') # Pa
    else
      fan_eff = 1
      pressure_rise = 0.000001
    end
    fan.setFanTotalEfficiency(fan_eff)
    fan.setDesignPressureRise(pressure_rise)
  end

  def self.calc_pump_rated_flow_rate(pump_eff, pump_w, pump_head_pa)
    # Calculate needed pump rated flow rate to achieve a given pump power with an assumed
    # efficiency and pump head.
    return pump_eff * pump_w / pump_head_pa # m3/s
  end

  def self.get_unitary_system_from_air_loop_hvac(air_loop)
    # Returns the unitary system or nil
    air_loop.supplyComponents.each do |comp|
      next unless comp.to_AirLoopHVACUnitarySystem.is_initialized

      return comp.to_AirLoopHVACUnitarySystem.get
    end
    return
  end

  def self.set_cool_rated_cfm_per_ton_mshp(heat_pump, num_speeds)
    hp_ap = heat_pump.additional_properties

    dB_rated = 80.0 # deg-F
    wB_rated = 67.0 # deg-F

    cool_nominal_capacity_ratio = 1.0
    cool_nominal_cfm_per_ton = ((hp_ap.cool_max_cfm_per_ton * hp_ap.cool_max_capacity_ratio - hp_ap.cool_min_cfm_per_ton * hp_ap.cool_min_capacity_ratio) /
                                (hp_ap.cool_max_capacity_ratio - hp_ap.cool_min_capacity_ratio)) *
                               (cool_nominal_capacity_ratio - hp_ap.cool_min_capacity_ratio) + hp_ap.cool_min_cfm_per_ton * hp_ap.cool_min_capacity_ratio

    p_atm = 14.696 # standard atmospheric pressure (psia)

    ao = Psychrometrics.CoilAoFactor(dB_rated, wB_rated, p_atm, UnitConversions.convert(1, 'ton', 'kBtu/hr'), cool_nominal_cfm_per_ton, heat_pump.cooling_shr)

    hp_ap.cool_capacity_ratios = []
    hp_ap.cool_rated_cfm_per_ton = []
    hp_ap.cool_rated_shrs_gross = []

    (0...num_speeds).each do |i|
      hp_ap.cool_capacity_ratios << hp_ap.cool_min_capacity_ratio + i * (hp_ap.cool_max_capacity_ratio - hp_ap.cool_min_capacity_ratio) / (num_speeds - 1)
      hp_ap.cool_rated_cfm_per_ton << (hp_ap.cool_min_cfm_per_ton * hp_ap.cool_min_capacity_ratio + i * (hp_ap.cool_max_cfm_per_ton * hp_ap.cool_max_capacity_ratio - hp_ap.cool_min_cfm_per_ton * hp_ap.cool_min_capacity_ratio) / (num_speeds - 1)) / hp_ap.cool_capacity_ratios[-1]
      # Calculate the SHR for each speed. Use minimum value of 0.98 to prevent E+ bypass factor calculation errors
      hp_ap.cool_rated_shrs_gross[i] = [Psychrometrics.CalculateSHR(dB_rated, wB_rated, p_atm, UnitConversions.convert(hp_ap.cool_capacity_ratios[i], 'ton', 'kBtu/hr'), hp_ap.cool_rated_cfm_per_ton[i] * hp_ap.cool_capacity_ratios[i], ao), 0.98].min
    end
  end

  def self.set_cool_rated_eirs_mshp(cooling_system, num_speeds)
    clg_ap = cooling_system.additional_properties

    cops_norm = [1.901, 1.859, 1.746, 1.609, 1.474, 1.353, 1.247, 1.156, 1.079, 1.0]
    fan_powers_norm = [0.604, 0.634, 0.670, 0.711, 0.754, 0.800, 0.848, 0.898, 0.948, 1.0]

    cop_max_speed = 3.5 # 3.5 is an initial guess, final value solved for below

    fan_powers_rated = []
    eers_rated = []

    (0...num_speeds).each do |i|
      fan_powers_rated << clg_ap.fan_power_rated * fan_powers_norm[i]
      eers_rated << UnitConversions.convert(cop_max_speed, 'W', 'Btu/hr') * cops_norm[i]
    end

    cop_max_speed_1 = cop_max_speed
    cop_max_speed_2 = cop_max_speed
    error = cooling_system.cooling_efficiency_seer - calc_mshp_seer(eers_rated, clg_ap.cool_c_d, clg_ap.cool_capacity_ratios, clg_ap.cool_rated_cfm_per_ton, fan_powers_rated, clg_ap.cool_eir_ft_spec, clg_ap.cool_cap_ft_spec)
    error1 = error
    error2 = error

    itmax = 50 # maximum iterations
    cvg = false
    final_n = nil

    (1...itmax + 1).each do |n|
      final_n = n
      (0...num_speeds).each do |i|
        eers_rated[i] = UnitConversions.convert(cop_max_speed, 'W', 'Btu/hr') * cops_norm[i]
      end

      error = cooling_system.cooling_efficiency_seer - calc_mshp_seer(eers_rated, clg_ap.cool_c_d, clg_ap.cool_capacity_ratios, clg_ap.cool_rated_cfm_per_ton, fan_powers_rated, clg_ap.cool_eir_ft_spec, clg_ap.cool_cap_ft_spec)

      cop_max_speed, cvg, cop_max_speed_1, error1, cop_max_speed_2, error2 = MathTools.Iterate(cop_max_speed, error, cop_max_speed_1, error1, cop_max_speed_2, error2, n, cvg)

      if cvg
        break
      end
    end

    if (not cvg) || (final_n > itmax)
      cop_max_speed = UnitConversions.convert(0.547 * cooling_system.cooling_efficiency_seer - 0.104, 'Btu/hr', 'W') # Correlation developed from JonW's MatLab scripts. Only used if an eer cannot be found.
    end

    clg_ap.cool_rated_eirs = []

    (0...num_speeds).each do |i|
      clg_ap.cool_rated_eirs << calc_eir_from_eer(UnitConversions.convert(cop_max_speed, 'W', 'Btu/hr') * cops_norm[i], fan_powers_rated[i])
    end
  end

  def self.set_mshp_downselected_speed_indices(heat_pump)
    hp_ap = heat_pump.additional_properties

    # Down-select to speed indices

    # Cooling
    hp_ap.cool_cap_ft_spec = hp_ap.cool_cap_ft_spec.select.with_index { |x, i| hp_ap.speed_indices.include? i }
    hp_ap.cool_eir_ft_spec = hp_ap.cool_eir_ft_spec.select.with_index { |x, i| hp_ap.speed_indices.include? i }
    hp_ap.cool_cap_fflow_spec = hp_ap.cool_cap_fflow_spec.select.with_index { |x, i| hp_ap.speed_indices.include? i }
    hp_ap.cool_eir_fflow_spec = hp_ap.cool_eir_fflow_spec.select.with_index { |x, i| hp_ap.speed_indices.include? i }
    hp_ap.cool_plf_fplr_spec = hp_ap.cool_plf_fplr_spec.select.with_index { |x, i| hp_ap.speed_indices.include? i }
    hp_ap.cool_rated_cfm_per_ton = hp_ap.cool_rated_cfm_per_ton.select.with_index { |x, i| hp_ap.speed_indices.include? i }
    hp_ap.cool_capacity_ratios = hp_ap.cool_capacity_ratios.select.with_index { |x, i| hp_ap.speed_indices.include? i }
    hp_ap.cool_rated_shrs_gross = hp_ap.cool_rated_shrs_gross.select.with_index { |x, i| hp_ap.speed_indices.include? i }
    hp_ap.cool_rated_eirs = hp_ap.cool_rated_eirs.select.with_index { |x, i| hp_ap.speed_indices.include? i }
    hp_ap.cool_fan_speed_ratios = []
    for i in 0..(hp_ap.speed_indices.size - 1)
      hp_ap.cool_fan_speed_ratios << hp_ap.cool_rated_cfm_per_ton[i] * hp_ap.cool_capacity_ratios[i] / (hp_ap.cool_rated_cfm_per_ton[-1] * hp_ap.cool_capacity_ratios[-1])
    end

    if heat_pump.is_a? HPXML::HeatPump # Skip for mini-split air conditioner
      # Heating
      hp_ap.heat_eir_ft_spec = hp_ap.heat_eir_ft_spec.select.with_index { |x, i| hp_ap.speed_indices.include? i }
      hp_ap.heat_cap_fflow_spec = hp_ap.heat_cap_fflow_spec.select.with_index { |x, i| hp_ap.speed_indices.include? i }
      hp_ap.heat_eir_fflow_spec = hp_ap.heat_eir_fflow_spec.select.with_index { |x, i| hp_ap.speed_indices.include? i }
      hp_ap.heat_cap_ft_spec = hp_ap.heat_cap_ft_spec.select.with_index { |x, i| hp_ap.speed_indices.include? i }
      hp_ap.heat_plf_fplr_spec = hp_ap.heat_plf_fplr_spec.select.with_index { |x, i| hp_ap.speed_indices.include? i }
      hp_ap.heat_rated_cfm_per_ton = hp_ap.heat_rated_cfm_per_ton.select.with_index { |x, i| hp_ap.speed_indices.include? i }
      hp_ap.heat_capacity_ratios = hp_ap.heat_capacity_ratios.select.with_index { |x, i| hp_ap.speed_indices.include? i }
      hp_ap.heat_rated_eirs = hp_ap.heat_rated_eirs.select.with_index { |x, i| hp_ap.speed_indices.include? i }
      hp_ap.heat_fan_speed_ratios = []
      for i in 0..(hp_ap.speed_indices.size - 1)
        hp_ap.heat_fan_speed_ratios << hp_ap.heat_rated_cfm_per_ton[i] * hp_ap.heat_capacity_ratios[i] / (hp_ap.heat_rated_cfm_per_ton[-1] * hp_ap.heat_capacity_ratios[-1])
      end
    end
  end

  def self.calc_mshp_seer(eer_a, c_d, capacity_ratio, cfm_tons, fan_power_rated, cool_eir_ft_spec, cool_cap_ft_spec)
    n_max = (eer_a.length - 1.0) - 3.0 # Don't use max speed; FIXME: this is different than calc_mshp_hspf?
    n_min = 0
    n_int = (n_min + (n_max - n_min) / 3.0).ceil.to_i

    wBin = 67.0
    tout_B = 82.0
    tout_E = 87.0
    tout_F = 67.0

    eir_A2 = calc_eir_from_eer(eer_a[n_max], fan_power_rated[n_max])
    eir_B2 = eir_A2 * MathTools.biquadratic(wBin, tout_B, cool_eir_ft_spec[n_max])

    eir_Av = calc_eir_from_eer(eer_a[n_int], fan_power_rated[n_int])
    eir_Ev = eir_Av * MathTools.biquadratic(wBin, tout_E, cool_eir_ft_spec[n_int])

    eir_A1 = calc_eir_from_eer(eer_a[n_min], fan_power_rated[n_min])
    eir_B1 = eir_A1 * MathTools.biquadratic(wBin, tout_B, cool_eir_ft_spec[n_min])
    eir_F1 = eir_A1 * MathTools.biquadratic(wBin, tout_F, cool_eir_ft_spec[n_min])

    q_A2 = capacity_ratio[n_max]
    q_B2 = q_A2 * MathTools.biquadratic(wBin, tout_B, cool_cap_ft_spec[n_max])
    q_Ev = capacity_ratio[n_int] * MathTools.biquadratic(wBin, tout_E, cool_cap_ft_spec[n_int])
    q_B1 = capacity_ratio[n_min] * MathTools.biquadratic(wBin, tout_B, cool_cap_ft_spec[n_min])
    q_F1 = capacity_ratio[n_min] * MathTools.biquadratic(wBin, tout_F, cool_cap_ft_spec[n_min])

    q_A2_net = q_A2 - fan_power_rated[n_max] * UnitConversions.convert(1, 'W', 'Btu/hr') * (cfm_tons[n_max] * capacity_ratio[n_max]) / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_B2_net = q_B2 - fan_power_rated[n_max] * UnitConversions.convert(1, 'W', 'Btu/hr') * (cfm_tons[n_max] * capacity_ratio[n_max]) / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_Ev_net = q_Ev - fan_power_rated[n_int] * UnitConversions.convert(1, 'W', 'Btu/hr') * (cfm_tons[n_int] * capacity_ratio[n_int]) / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_B1_net = q_B1 - fan_power_rated[n_min] * UnitConversions.convert(1, 'W', 'Btu/hr') * (cfm_tons[n_min] * capacity_ratio[n_min]) / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_F1_net = q_F1 - fan_power_rated[n_min] * UnitConversions.convert(1, 'W', 'Btu/hr') * (cfm_tons[n_min] * capacity_ratio[n_min]) / UnitConversions.convert(1, 'ton', 'Btu/hr')

    p_A2 = UnitConversions.convert(q_A2 * eir_A2, 'Btu', 'Wh') + fan_power_rated[n_max] * (cfm_tons[n_max] * capacity_ratio[n_max]) / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_B2 = UnitConversions.convert(q_B2 * eir_B2, 'Btu', 'Wh') + fan_power_rated[n_max] * (cfm_tons[n_max] * capacity_ratio[n_max]) / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_Ev = UnitConversions.convert(q_Ev * eir_Ev, 'Btu', 'Wh') + fan_power_rated[n_int] * (cfm_tons[n_int] * capacity_ratio[n_int]) / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_B1 = UnitConversions.convert(q_B1 * eir_B1, 'Btu', 'Wh') + fan_power_rated[n_min] * (cfm_tons[n_min] * capacity_ratio[n_min]) / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_F1 = UnitConversions.convert(q_F1 * eir_F1, 'Btu', 'Wh') + fan_power_rated[n_min] * (cfm_tons[n_min] * capacity_ratio[n_min]) / UnitConversions.convert(1, 'ton', 'Btu/hr')

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

  def self.set_heat_rated_cfm_per_ton_mshp(heat_pump, num_speeds)
    hp_ap = heat_pump.additional_properties

    hp_ap.heat_capacity_ratios = []
    hp_ap.heat_rated_cfm_per_ton = []

    (0...num_speeds).each do |i|
      hp_ap.heat_capacity_ratios << hp_ap.heat_min_capacity_ratio + i * (hp_ap.heat_max_capacity_ratio - hp_ap.heat_min_capacity_ratio) / (num_speeds - 1)
      hp_ap.heat_rated_cfm_per_ton << (hp_ap.heat_min_cfm_per_ton * hp_ap.heat_min_capacity_ratio + i * (hp_ap.heat_max_cfm_per_ton * hp_ap.heat_max_capacity_ratio - hp_ap.heat_min_cfm_per_ton * hp_ap.heat_min_capacity_ratio) / (num_speeds - 1)) / hp_ap.heat_capacity_ratios[-1]
    end
  end

  def self.set_heat_rated_eirs_mshp(heat_pump, num_speeds)
    hp_ap = heat_pump.additional_properties

    cops_norm = [1.792, 1.502, 1.308, 1.207, 1.145, 1.105, 1.077, 1.056, 1.041, 1.0]
    fan_powers_norm = [0.577, 0.625, 0.673, 0.720, 0.768, 0.814, 0.861, 0.907, 0.954, 1.0]

    cop_max_speed = 3.25 # 3.35 is an initial guess, final value solved for below

    fan_powers_rated = []
    cops_rated = []

    (0...num_speeds).each do |i|
      fan_powers_rated << hp_ap.fan_power_rated * fan_powers_norm[i]
      cops_rated << cop_max_speed * cops_norm[i]
    end

    cop_max_speed_1 = cop_max_speed
    cop_max_speed_2 = cop_max_speed
    error = heat_pump.heating_efficiency_hspf - calc_mshp_hspf(cops_rated, hp_ap.heat_c_d, hp_ap.heat_capacity_ratios, hp_ap.heat_rated_cfm_per_ton, fan_powers_rated, hp_ap.hp_min_temp, hp_ap.heat_eir_ft_spec, hp_ap.heat_cap_ft_spec)

    error1 = error
    error2 = error

    itmax = 50 # maximum iterations
    cvg = false
    final_n = nil

    (1...itmax + 1).each do |n|
      final_n = n
      (0...num_speeds).each do |i|
        cops_rated[i] = cop_max_speed * cops_norm[i]
      end

      error = heat_pump.heating_efficiency_hspf - calc_mshp_hspf(cops_rated, hp_ap.heat_c_d, hp_ap.heat_capacity_ratios, hp_ap.heat_rated_cfm_per_ton, fan_powers_rated, hp_ap.hp_min_temp, hp_ap.heat_eir_ft_spec, hp_ap.heat_cap_ft_spec)

      cop_max_speed, cvg, cop_max_speed_1, error1, cop_max_speed_2, error2 = MathTools.Iterate(cop_max_speed, error, cop_max_speed_1, error1, cop_max_speed_2, error2, n, cvg)

      if cvg
        break
      end
    end

    if (not cvg) || (final_n > itmax)
      cop_max_speed = UnitConversions.convert(0.4174 * hspf - 1.1134, 'Btu/hr', 'W') # Correlation developed from JonW's MatLab scripts. Only used if a cop cannot be found.
    end

    hp_ap.heat_rated_eirs = []
    (0...num_speeds).each do |i|
      hp_ap.heat_rated_eirs << calc_eir_from_cop(cop_max_speed * cops_norm[i], fan_powers_rated[i])
    end
  end

  def self.set_gshp_assumptions(heat_pump, weather)
    hp_ap = heat_pump.additional_properties

    hp_ap.design_chw = [85.0, weather.design.CoolingDrybulb - 15.0, weather.data.AnnualAvgDrybulb + 10.0].max # Temperature of water entering indoor coil,use 85F as lower bound
    hp_ap.design_delta_t = 10.0
    hp_ap.fluid_type = Constants.FluidPropyleneGlycol
    hp_ap.frac_glycol = 0.3
    if hp_ap.fluid_type == Constants.FluidWater
      hp_ap.design_hw = [45.0, weather.design.HeatingDrybulb + 35.0, weather.data.AnnualAvgDrybulb - 10.0].max # Temperature of fluid entering indoor coil, use 45F as lower bound for water
    else
      hp_ap.design_hw = [35.0, weather.design.HeatingDrybulb + 35.0, weather.data.AnnualAvgDrybulb - 10.0].min # Temperature of fluid entering indoor coil, use 35F as upper bound
    end
    hp_ap.ground_conductivity = 0.6 # Btu/h-ft-R
    hp_ap.ground_diffusivity = 0.0208
    hp_ap.grout_conductivity = 0.4 # Btu/h-ft-R
    hp_ap.bore_diameter = 5.0 # in
    hp_ap.pipe_size = 0.75 # in
    # Pipe nominal size conversion to pipe outside diameter and inside diameter,
    # only pipe sizes <= 2" are used here with DR11 (dimension ratio),
    if hp_ap.pipe_size == 0.75 # 3/4" pipe
      hp_ap.pipe_od = 1.050 # in
      hp_ap.pipe_id = 0.859 # in
    elsif hp_ap.pipe_size == 1.0 # 1" pipe
      hp_ap.pipe_od = 1.315 # in
      hp_ap.pipe_id = 1.076 # in
    elsif hp_ap.pipe_size == 1.25 # 1-1/4" pipe
      hp_ap.pipe_od = 1.660 # in
      hp_ap.pipe_id = 1.358 # in
    end
    hp_ap.pipe_cond = 0.23 # Btu/h-ft-R; Pipe thermal conductivity, default to high density polyethylene
    hp_ap.u_tube_spacing_type = 'b'
    # Calculate distance between pipes
    if hp_ap.u_tube_spacing_type == 'as'
      # Two tubes, spaced 1/8” apart at the center of the borehole
      hp_ap.u_tube_spacing = 0.125
    elsif hp_ap.u_tube_spacing_type == 'b'
      # Two tubes equally spaced between the borehole edges
      hp_ap.u_tube_spacing = 0.9661
    elsif hp_ap.u_tube_spacing_type == 'c'
      # Both tubes placed against outer edge of borehole
      hp_ap.u_tube_spacing = hp_ap.bore_diameter - 2 * hp_ap.pipe_od
    end
    hp_ap.shank_spacing = hp_ap.u_tube_spacing + hp_ap.pipe_od # Distance from center of pipe to center of pipe
  end

  def self.calc_mshp_hspf(cop_47, c_d, capacity_ratio, cfm_tons, fan_power_rated, hp_min_temp, heat_eir_ft_spec, heat_cap_ft_spec)
    n_max = (cop_47.length - 1.0) #-3 # Don't use max speed; FIXME: this is different than calc_mshp_seer?
    n_min = 0
    n_int = (n_min + (n_max - n_min) / 3.0).ceil.to_i

    tin = 70.0
    tout_3 = 17.0
    tout_2 = 35.0
    tout_0 = 62.0

    eir_H1_2 = calc_eir_from_cop(cop_47[n_max], fan_power_rated[n_max])
    eir_H3_2 = eir_H1_2 * MathTools.biquadratic(tin, tout_3, heat_eir_ft_spec[n_max])

    eir_adjv = calc_eir_from_cop(cop_47[n_int], fan_power_rated[n_int])
    eir_H2_v = eir_adjv * MathTools.biquadratic(tin, tout_2, heat_eir_ft_spec[n_int])

    eir_H1_1 = calc_eir_from_cop(cop_47[n_min], fan_power_rated[n_min])
    eir_H0_1 = eir_H1_1 * MathTools.biquadratic(tin, tout_0, heat_eir_ft_spec[n_min])

    q_H1_2 = capacity_ratio[n_max]
    q_H3_2 = q_H1_2 * MathTools.biquadratic(tin, tout_3, heat_cap_ft_spec[n_max])

    q_H2_v = capacity_ratio[n_int] * MathTools.biquadratic(tin, tout_2, heat_cap_ft_spec[n_int])

    q_H1_1 = capacity_ratio[n_min]
    q_H0_1 = q_H1_1 * MathTools.biquadratic(tin, tout_0, heat_cap_ft_spec[n_min])

    q_H1_2_net = q_H1_2 + fan_power_rated[n_max] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_tons[n_max] * capacity_ratio[n_max] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_H3_2_net = q_H3_2 + fan_power_rated[n_max] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_tons[n_max] * capacity_ratio[n_max] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_H2_v_net = q_H2_v + fan_power_rated[n_int] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_tons[n_int] * capacity_ratio[n_int] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_H1_1_net = q_H1_1 + fan_power_rated[n_min] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_tons[n_min] * capacity_ratio[n_min] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    q_H0_1_net = q_H0_1 + fan_power_rated[n_min] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_tons[n_min] * capacity_ratio[n_min] / UnitConversions.convert(1, 'ton', 'Btu/hr')

    p_H1_2 = q_H1_2 * eir_H1_2 + fan_power_rated[n_max] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_tons[n_max] * capacity_ratio[n_max] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_H3_2 = q_H3_2 * eir_H3_2 + fan_power_rated[n_max] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_tons[n_max] * capacity_ratio[n_max] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_H2_v = q_H2_v * eir_H2_v + fan_power_rated[n_int] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_tons[n_int] * capacity_ratio[n_int] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_H1_1 = q_H1_1 * eir_H1_1 + fan_power_rated[n_min] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_tons[n_min] * capacity_ratio[n_min] / UnitConversions.convert(1, 'ton', 'Btu/hr')
    p_H0_1 = q_H0_1 * eir_H0_1 + fan_power_rated[n_min] * UnitConversions.convert(1, 'W', 'Btu/hr') * cfm_tons[n_min] * capacity_ratio[n_min] / UnitConversions.convert(1, 'ton', 'Btu/hr')

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

    # T_off = hp_min_temp
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

  def self.calc_sequential_load_fractions(load_fraction, remaining_fraction, availability_days)
    # Returns the EnergyPlus sequential load fractions for every day of the year
    if remaining_fraction > 0
      sequential_load_frac = load_fraction / remaining_fraction # Fraction of remaining load served by this system
    else
      sequential_load_frac = 0.0
    end
    sequential_load_fracs = availability_days.map { |d| d * sequential_load_frac }

    return sequential_load_fracs
  end

  def self.get_sequential_load_schedule(model, fractions)
    values = fractions.map { |f| f > 1 ? 1.0 : f.round(5) }

    if values.uniq.length == 1
      s = OpenStudio::Model::ScheduleConstant.new(model)
      s.setValue(values[0])
    else
      s = Schedule.create_ruleset_from_daily_season(model, values)
    end

    s.setName('Sequential Fraction Schedule')
    Schedule.set_schedule_type_limits(model, s, Constants.ScheduleTypeLimitsFraction)
    return s
  end

  def self.set_crankcase_assumptions(hvac_system)
    hvac_ap = hvac_system.additional_properties

    if hvac_system.is_a?(HPXML::HeatPump) && (hvac_system.fraction_heat_load_served <= 0)
      hvac_ap.crankcase_kw = 0.0
      hvac_ap.crankcase_temp = nil
    elsif hvac_system.is_a?(HPXML::HeatPump) && (hvac_system.heat_pump_type == HPXML::HVACTypeHeatPumpMiniSplit)
      hvac_ap.crankcase_kw = 0.0
      hvac_ap.crankcase_temp = nil
    elsif hvac_system.is_a?(HPXML::CoolingSystem) && (hvac_system.cooling_system_type == HPXML::HVACTypeMiniSplitAirConditioner)
      hvac_ap.crankcase_kw = 0.0
      hvac_ap.crankcase_temp = nil
    else
      hvac_ap.crankcase_kw = 0.05 * hvac_system.fraction_cool_load_served # From RESNET Publication No. 002-2017
      hvac_ap.crankcase_temp = 50.0 # From RESNET Publication No. 002-2017
    end
  end

  def self.set_heat_pump_temperatures(heat_pump)
    hp_ap = heat_pump.additional_properties

    # Sets:
    # 1. Minimum temperature (deg-F) for HP compressor operation
    # 2. Maximum temperature (deg-F) for HP supplemental heating operation
    if not heat_pump.backup_heating_switchover_temp.nil?
      hp_ap.hp_min_temp = heat_pump.backup_heating_switchover_temp
      hp_ap.supp_max_temp = heat_pump.backup_heating_switchover_temp
    else
      hp_ap.supp_max_temp = 40.0
      hp_ap.hp_min_temp = -40.0
    end
  end

  def self.get_default_duct_surface_area(duct_type, ncfl_ag, cfa_served, n_returns)
    # Fraction of primary ducts (ducts outside conditioned space)
    f_out = (ncfl_ag <= 1) ? 1.0 : 0.75

    if duct_type == HPXML::DuctTypeSupply
      primary_duct_area = 0.27 * cfa_served * f_out
      secondary_duct_area = 0.27 * cfa_served * (1.0 - f_out)
    elsif duct_type == HPXML::DuctTypeReturn
      b_r = (n_returns < 6) ? (0.05 * n_returns) : 0.25
      primary_duct_area = b_r * cfa_served * f_out
      secondary_duct_area = b_r * cfa_served * (1.0 - f_out)
    end

    return primary_duct_area, secondary_duct_area
  end

  def self.get_default_duct_locations(hpxml)
    primary_duct_location_hierarchy = [HPXML::LocationBasementConditioned,
                                       HPXML::LocationBasementUnconditioned,
                                       HPXML::LocationCrawlspaceVented,
                                       HPXML::LocationCrawlspaceUnvented,
                                       HPXML::LocationAtticVented,
                                       HPXML::LocationAtticUnvented,
                                       HPXML::LocationGarage]

    primary_duct_location = nil
    primary_duct_location_hierarchy.each do |space_type|
      if hpxml.has_space_type(space_type)
        primary_duct_location = space_type
        break
      end
    end
    secondary_duct_location = HPXML::LocationLivingSpace

    return primary_duct_location, secondary_duct_location
  end

  def self.get_installation_quality_cooling_coeff(f_chg)
    if f_chg <= 0
      qgr_values = [-9.46E-01, 4.93E-02, -1.18E-03, -1.15E+00]
      p_values = [-3.13E-01, 1.15E-02, 2.66E-03, -1.16E-01]
    else
      qgr_values = [-1.63E-01, 1.14E-02, -2.10E-04, -1.40E-01]
      p_values = [2.19E-01, -5.01E-03, 9.89E-04, 2.84E-01]
    end
    ff_chg_values = [26.67, 35.0]
    return qgr_values, p_values, ff_chg_values
  end

  def self.get_installation_quality_heating_coeff(f_chg)
    if f_chg <= 0
      qgr_values = [-0.0338595, 0.0202827, -2.6226343]
      p_values = [0.0615649, 0.0044554, -0.2598507]
    else
      qgr_values = [-0.0029514, 0.0007379, -0.0064112]
      p_values = [-0.0594134, 0.0159205, 1.8872153]
    end
    ff_chg_values = [8.33]
    return qgr_values, p_values, ff_chg_values
  end

  def self.apply_installation_quality(model, heating_system, cooling_system, unitary_system, htg_coil, clg_coil, control_zone)
    if not cooling_system.nil?
      charge_defect_ratio = cooling_system.charge_defect_ratio
      cool_airflow_defect_ratio = cooling_system.airflow_defect_ratio
    end
    if not heating_system.nil?
      heat_airflow_defect_ratio = heating_system.airflow_defect_ratio
    end
    return if (charge_defect_ratio.to_f.abs < 0.001) && (cool_airflow_defect_ratio.to_f.abs < 0.001) && (heat_airflow_defect_ratio.to_f.abs < 0.001)

    cool_airflow_rated_defect_ratio = []
    if (not clg_coil.nil?) && (cooling_system.fraction_cool_load_served > 0)
      clg_ap = cooling_system.additional_properties
      clg_cfm = cooling_system.cooling_airflow_cfm
      if clg_coil.to_CoilCoolingDXSingleSpeed.is_initialized || clg_coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
        cool_airflow_rated_defect_ratio = [UnitConversions.convert(clg_cfm, 'cfm', 'm^3/s') / clg_coil.ratedAirFlowRate.get - 1.0]
      elsif clg_coil.to_CoilCoolingDXMultiSpeed.is_initialized
        cool_airflow_rated_defect_ratio = clg_coil.stages.zip(clg_ap.cool_fan_speed_ratios).map { |stage, speed_ratio| UnitConversions.convert(clg_cfm * speed_ratio, 'cfm', 'm^3/s') / stage.ratedAirFlowRate.get - 1.0 }
      end
    end

    heat_airflow_rated_defect_ratio = []
    if (not htg_coil.nil?) && (heating_system.fraction_heat_load_served > 0)
      htg_ap = heating_system.additional_properties
      htg_cfm = heating_system.heating_airflow_cfm
      if htg_coil.to_CoilHeatingDXSingleSpeed.is_initialized || htg_coil.to_CoilHeatingWaterToAirHeatPumpEquationFit.is_initialized
        heat_airflow_rated_defect_ratio = [UnitConversions.convert(htg_cfm, 'cfm', 'm^3/s') / htg_coil.ratedAirFlowRate.get - 1.0]
      elsif htg_coil.to_CoilHeatingDXMultiSpeed.is_initialized
        heat_airflow_rated_defect_ratio = htg_coil.stages.zip(htg_ap.heat_fan_speed_ratios).map { |stage, speed_ratio| UnitConversions.convert(htg_cfm * speed_ratio, 'cfm', 'm^3/s') / stage.ratedAirFlowRate.get - 1.0 }
      end
    end

    return if cool_airflow_rated_defect_ratio.empty? && heat_airflow_rated_defect_ratio.empty?

    obj_name = "#{unitary_system.name} install quality"

    tin_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Mean Air Temperature')
    tin_sensor.setName("#{obj_name} tin s")
    tin_sensor.setKeyName(control_zone.name.to_s)

    tout_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Outdoor Air Drybulb Temperature')
    tout_sensor.setName("#{obj_name} tt s")
    tout_sensor.setKeyName(control_zone.name.to_s)

    fault_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    fault_program.setName("#{obj_name} program")

    f_chg = charge_defect_ratio.to_f
    fault_program.addLine("Set F_CH = #{f_chg.round(3)}")

    if not cool_airflow_rated_defect_ratio.empty?
      if clg_coil.is_a? OpenStudio::Model::CoilCoolingDXSingleSpeed
        num_speeds = 1
        cool_cap_fff_curves = [clg_coil.totalCoolingCapacityFunctionOfFlowFractionCurve.to_CurveQuadratic.get]
        cool_eir_fff_curves = [clg_coil.energyInputRatioFunctionOfFlowFractionCurve.to_CurveQuadratic.get]
      elsif clg_coil.is_a? OpenStudio::Model::CoilCoolingDXMultiSpeed
        num_speeds = clg_coil.stages.size
        cool_cap_fff_curves = clg_coil.stages.map { |stage| stage.totalCoolingCapacityFunctionofFlowFractionCurve.to_CurveQuadratic.get }
        cool_eir_fff_curves = clg_coil.stages.map { |stage| stage.energyInputRatioFunctionofFlowFractionCurve.to_CurveQuadratic.get }
      elsif clg_coil.is_a? OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit
        num_speeds = 1
        cool_cap_fff_curves = [clg_coil.totalCoolingCapacityCurve.to_CurveQuadLinear.get] # quadlinear curve, only forth term is for airflow
        cool_eir_fff_curves = [clg_coil.coolingPowerConsumptionCurve.to_CurveQuadLinear.get] # quadlinear curve, only forth term is for airflow
        # variables are the same for eir and cap curve
        var1_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 1 Value')
        var1_sensor.setName('Cool Cap Curve Var 1')
        var1_sensor.setKeyName(cool_cap_fff_curves[0].name.to_s)
        var2_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 2 Value')
        var2_sensor.setName('Cool Cap Curve Var 2')
        var2_sensor.setKeyName(cool_cap_fff_curves[0].name.to_s)
        var4_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 4 Value')
        var4_sensor.setName('Cool Cap Curve Var 4')
        var4_sensor.setKeyName(cool_cap_fff_curves[0].name.to_s)
      else
        fail 'cooling coil not supported'
      end

      for speed in 0..(num_speeds - 1)
        cool_cap_fff_curve = cool_cap_fff_curves[speed]
        cool_cap_fff_act = OpenStudio::Model::EnergyManagementSystemActuator.new(cool_cap_fff_curve, 'Curve', 'Curve Result')
        cool_cap_fff_act.setName("#{obj_name} cap clg act")

        cool_eir_fff_curve = cool_eir_fff_curves[speed]
        cool_eir_fff_act = OpenStudio::Model::EnergyManagementSystemActuator.new(cool_eir_fff_curve, 'Curve', 'Curve Result')
        cool_eir_fff_act.setName("#{obj_name} eir clg act")

        # NOTE: heat pump (cooling) curves don't exhibit expected trends at extreme faults;
        if not clg_coil.is_a? OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit
          fault_program.addLine("Set a1_AF_Qgr_c = #{cool_cap_fff_curve.coefficient1Constant}")
          fault_program.addLine("Set a2_AF_Qgr_c = #{cool_cap_fff_curve.coefficient2x}")
          fault_program.addLine("Set a3_AF_Qgr_c = #{cool_cap_fff_curve.coefficient3xPOW2}")
          fault_program.addLine("Set a1_AF_EIR_c = #{cool_eir_fff_curve.coefficient1Constant}")
          fault_program.addLine("Set a2_AF_EIR_c = #{cool_eir_fff_curve.coefficient2x}")
          fault_program.addLine("Set a3_AF_EIR_c = #{cool_eir_fff_curve.coefficient3xPOW2}")
        else
          fault_program.addLine("Set a1_AF_Qgr_c = #{cool_cap_fff_curve.coefficient1Constant} + (#{cool_cap_fff_curve.coefficient2w}*#{var1_sensor.name}) + (#{cool_cap_fff_curve.coefficient3x}*#{var2_sensor.name}) + (#{cool_cap_fff_curve.coefficient5z}*#{var4_sensor.name})")
          fault_program.addLine("Set a2_AF_Qgr_c = #{cool_cap_fff_curve.coefficient4y}")
          fault_program.addLine('Set a3_AF_Qgr_c = 0')
          fault_program.addLine("Set a1_AF_EIR_c = #{cool_eir_fff_curve.coefficient1Constant} + (#{cool_eir_fff_curve.coefficient2w}*#{var1_sensor.name}) + (#{cool_eir_fff_curve.coefficient3x}*#{var2_sensor.name}) + (#{cool_eir_fff_curve.coefficient5z}*#{var4_sensor.name})")
          fault_program.addLine("Set a2_AF_EIR_c = #{cool_eir_fff_curve.coefficient4y}")
          fault_program.addLine('Set a3_AF_EIR_c = 0')
        end

        qgr_values, p_values, ff_chg_values = get_installation_quality_cooling_coeff(f_chg)

        # charge defect impact
        fault_program.addLine("Set a1_CH_Qgr_c = #{qgr_values[0]}")
        fault_program.addLine("Set a2_CH_Qgr_c = #{qgr_values[1]}")
        fault_program.addLine("Set a3_CH_Qgr_c = #{qgr_values[2]}")
        fault_program.addLine("Set a4_CH_Qgr_c = #{qgr_values[3]}")

        fault_program.addLine("Set a1_CH_P_c = #{p_values[0]}")
        fault_program.addLine("Set a2_CH_P_c = #{p_values[1]}")
        fault_program.addLine("Set a3_CH_P_c = #{p_values[2]}")
        fault_program.addLine("Set a4_CH_P_c = #{p_values[3]}")

        fault_program.addLine('Set q0_CH = a1_CH_Qgr_c')
        fault_program.addLine("Set q1_CH = a2_CH_Qgr_c*#{tin_sensor.name}")
        fault_program.addLine("Set q2_CH = a3_CH_Qgr_c*#{tout_sensor.name}")
        fault_program.addLine('Set q3_CH = a4_CH_Qgr_c*F_CH')
        fault_program.addLine('Set Y_CH_Q_c = 1 + ((q0_CH+(q1_CH)+(q2_CH)+(q3_CH))*F_CH)')

        fault_program.addLine('Set p1_CH = a1_CH_P_c')
        fault_program.addLine("Set p2_CH = a2_CH_P_c*#{tin_sensor.name}")
        fault_program.addLine("Set p3_CH = a3_CH_P_c*#{tout_sensor.name}")
        fault_program.addLine('Set p4_CH = a4_CH_P_c*F_CH')
        fault_program.addLine('Set Y_CH_COP_c = Y_CH_Q_c/(1 + (p1_CH+(p2_CH)+(p3_CH)+(p4_CH))*F_CH)')

        # air flow defect and charge defect combined to modify airflow curve output
        ff_ch_c = 1.0 / (1.0 + (qgr_values[0] + (qgr_values[1] * ff_chg_values[0]) + (qgr_values[2] * ff_chg_values[1]) + (qgr_values[3] * f_chg)) * f_chg)
        fault_program.addLine("Set FF_CH_c = #{ff_ch_c.round(3)}")
        fault_program.addLine("Set FF_AF_c = 1.0 + #{cool_airflow_rated_defect_ratio[speed].round(3)}")
        fault_program.addLine('Set FF_AF_comb_c = FF_CH_c * FF_AF_c')

        fault_program.addLine('Set q_AF_CH = (a1_AF_Qgr_c) + (a2_AF_Qgr_c*FF_CH_c) + (a3_AF_Qgr_c*FF_CH_c*FF_CH_c)')
        fault_program.addLine('Set eir_AF_CH = (a1_AF_EIR_c) + (a2_AF_EIR_c*FF_CH_c) + (a3_AF_EIR_c*FF_CH_c*FF_CH_c)')
        fault_program.addLine('Set p_CH_Q_c = Y_CH_Q_c/q_AF_CH')
        fault_program.addLine('Set p_CH_COP_c = Y_CH_COP_c*eir_AF_CH')

        fault_program.addLine('Set p_AF_Q_c = (a1_AF_Qgr_c) + (a2_AF_Qgr_c*FF_AF_comb_c) + (a3_AF_Qgr_c*FF_AF_comb_c*FF_AF_comb_c)')
        fault_program.addLine('Set p_AF_COP_c = 1.0 / ((a1_AF_EIR_c) + (a2_AF_EIR_c*FF_AF_comb_c) + (a3_AF_EIR_c*FF_AF_comb_c*FF_AF_comb_c))')

        fault_program.addLine("Set #{cool_cap_fff_act.name} = (p_CH_Q_c * p_AF_Q_c)")
        fault_program.addLine("Set #{cool_eir_fff_act.name} = (1.0 / (p_CH_COP_c * p_AF_COP_c))")
      end
    end

    if not heat_airflow_rated_defect_ratio.empty?

      if htg_coil.is_a? OpenStudio::Model::CoilHeatingDXSingleSpeed
        num_speeds = 1
        heat_cap_fff_curves = [htg_coil.totalHeatingCapacityFunctionofFlowFractionCurve.to_CurveQuadratic.get]
        heat_eir_fff_curves = [htg_coil.energyInputRatioFunctionofFlowFractionCurve.to_CurveQuadratic.get]
      elsif htg_coil.is_a? OpenStudio::Model::CoilHeatingDXMultiSpeed
        num_speeds = htg_coil.stages.size
        heat_cap_fff_curves = htg_coil.stages.map { |stage| stage.heatingCapacityFunctionofFlowFractionCurve.to_CurveQuadratic.get }
        heat_eir_fff_curves = htg_coil.stages.map { |stage| stage.energyInputRatioFunctionofFlowFractionCurve.to_CurveQuadratic.get }
      elsif htg_coil.is_a? OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit
        num_speeds = 1
        heat_cap_fff_curves = [htg_coil.heatingCapacityCurve.to_CurveQuadLinear.get] # quadlinear curve, only forth term is for airflow
        heat_eir_fff_curves = [htg_coil.heatingPowerConsumptionCurve.to_CurveQuadLinear.get] # quadlinear curve, only forth term is for airflow
        # variables are the same for eir and cap curve
        var1_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 1 Value')
        var1_sensor.setName('Heat Cap Curve Var 1')
        var1_sensor.setKeyName(heat_cap_fff_curves[0].name.to_s)
        var2_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 2 Value')
        var2_sensor.setName('Heat Cap Curve Var 2')
        var2_sensor.setKeyName(heat_cap_fff_curves[0].name.to_s)
        var4_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Performance Curve Input Variable 4 Value')
        var4_sensor.setName('Heat Cap Curve Var 4')
        var4_sensor.setKeyName(heat_cap_fff_curves[0].name.to_s)
      else
        fail 'heating coil not supported'
      end
      for speed in 0..(num_speeds - 1)
        heat_cap_fff_curve = heat_cap_fff_curves[speed]
        heat_cap_fff_act = OpenStudio::Model::EnergyManagementSystemActuator.new(heat_cap_fff_curve, 'Curve', 'Curve Result')
        heat_cap_fff_act.setName("#{obj_name} cap htg act")

        heat_eir_fff_curve = heat_eir_fff_curves[speed]
        heat_eir_fff_act = OpenStudio::Model::EnergyManagementSystemActuator.new(heat_eir_fff_curve, 'Curve', 'Curve Result')
        heat_eir_fff_act.setName("#{obj_name} eir htg act")

        # NOTE: heat pump (cooling) curves don't exhibit expected trends at extreme faults;
        if not htg_coil.is_a? OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit
          fault_program.addLine("Set a1_AF_Qgr_h = #{heat_cap_fff_curve.coefficient1Constant}")
          fault_program.addLine("Set a2_AF_Qgr_h = #{heat_cap_fff_curve.coefficient2x}")
          fault_program.addLine("Set a3_AF_Qgr_h = #{heat_cap_fff_curve.coefficient3xPOW2}")
          fault_program.addLine("Set a1_AF_EIR_h = #{heat_eir_fff_curve.coefficient1Constant}")
          fault_program.addLine("Set a2_AF_EIR_h = #{heat_eir_fff_curve.coefficient2x}")
          fault_program.addLine("Set a3_AF_EIR_h = #{heat_eir_fff_curve.coefficient3xPOW2}")
        else
          fault_program.addLine("Set a1_AF_Qgr_h = #{heat_cap_fff_curve.coefficient1Constant} + (#{heat_cap_fff_curve.coefficient2w}*#{var1_sensor.name}) + (#{heat_cap_fff_curve.coefficient3x}*#{var2_sensor.name}) + (#{heat_cap_fff_curve.coefficient5z}*#{var4_sensor.name})")
          fault_program.addLine("Set a2_AF_Qgr_h = #{heat_cap_fff_curve.coefficient4y}")
          fault_program.addLine('Set a3_AF_Qgr_h = 0')
          fault_program.addLine("Set a1_AF_EIR_h = #{heat_eir_fff_curve.coefficient1Constant} + (#{heat_eir_fff_curve.coefficient2w}*#{var1_sensor.name}) + (#{heat_eir_fff_curve.coefficient3x}*#{var2_sensor.name}) + (#{heat_eir_fff_curve.coefficient5z}*#{var4_sensor.name})")
          fault_program.addLine("Set a2_AF_EIR_h = #{heat_eir_fff_curve.coefficient4y}")
          fault_program.addLine('Set a3_AF_EIR_h = 0')
        end

        qgr_values, p_values, ff_chg_values = get_installation_quality_heating_coeff(f_chg)

        # charge defect impact
        fault_program.addLine("Set a1_CH_Qgr_h = #{qgr_values[0]}")
        fault_program.addLine("Set a2_CH_Qgr_h = #{qgr_values[1]}")
        fault_program.addLine("Set a3_CH_Qgr_h = #{qgr_values[2]}")

        fault_program.addLine("Set a1_CH_P_h = #{p_values[0]}")
        fault_program.addLine("Set a2_CH_P_h = #{p_values[1]}")
        fault_program.addLine("Set a3_CH_P_h = #{p_values[2]}")

        fault_program.addLine('Set qh1_CH = a1_CH_Qgr_h')
        fault_program.addLine("Set qh2_CH = a2_CH_Qgr_h*#{tout_sensor.name}")
        fault_program.addLine('Set qh3_CH = a3_CH_Qgr_h*F_CH')
        fault_program.addLine('Set Y_CH_Q_h = 1 + ((qh1_CH+(qh2_CH)+(qh3_CH))*F_CH)')

        fault_program.addLine('Set ph1_CH = a1_CH_P_h')
        fault_program.addLine("Set ph2_CH = a2_CH_P_h*#{tout_sensor.name}")
        fault_program.addLine('Set ph3_CH = a3_CH_P_h*F_CH')
        fault_program.addLine('Set Y_CH_COP_h = Y_CH_Q_h/(1 + ((ph1_CH+(ph2_CH)+(ph3_CH))*F_CH))')

        # air flow defect and charge defect combined to modify airflow curve output
        ff_ch_h = 1 / (1 + (qgr_values[0] + qgr_values[1] * ff_chg_values[0] + qgr_values[2] * f_chg) * f_chg)
        fault_program.addLine("Set FF_CH_h = #{ff_ch_h.round(3)}")

        fault_program.addLine("Set FF_AF_h = 1.0 + #{heat_airflow_rated_defect_ratio[speed].round(3)}")
        fault_program.addLine('Set FF_AF_comb_h = FF_CH_h * FF_AF_h')

        fault_program.addLine('Set qh_AF_CH = a1_AF_Qgr_h + (a2_AF_Qgr_h*FF_CH_h) + (a3_AF_Qgr_h*FF_CH_h*FF_CH_h)')
        fault_program.addLine('Set eirh_AF_CH = a1_AF_EIR_h + (a2_AF_EIR_h*FF_CH_h) + (a3_AF_EIR_h*FF_CH_h*FF_CH_h)')
        fault_program.addLine('Set p_CH_Q_h = Y_CH_Q_h / qh_AF_CH')
        fault_program.addLine('Set p_CH_COP_h = Y_CH_COP_h * eirh_AF_CH')

        fault_program.addLine('Set p_AF_Q_h = a1_AF_Qgr_h + (a2_AF_Qgr_h*FF_AF_comb_h) + (a3_AF_Qgr_h*FF_AF_comb_h*FF_AF_comb_h)')
        fault_program.addLine('Set p_AF_COP_h = 1.0 / ((a1_AF_EIR_h)+(a2_AF_EIR_h*FF_AF_comb_h)+(a3_AF_EIR_h*FF_AF_comb_h*FF_AF_comb_h))')

        fault_program.addLine("Set #{heat_cap_fff_act.name} = (p_CH_Q_h * p_AF_Q_h)")
        fault_program.addLine("Set #{heat_eir_fff_act.name} = 1.0 / (p_CH_COP_h * p_AF_COP_h)")
      end
    end
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName("#{obj_name} program manager")
    program_calling_manager.setCallingPoint('BeginTimestepBeforePredictor')
    program_calling_manager.addProgram(fault_program)
  end

  def self.get_default_gshp_pump_power()
    return 30.0 # W/ton, per ANSI/RESNET/ICC 301-2019 Section 4.4.5 (closed loop)
  end

  def self.apply_shared_systems(hpxml)
    applied_clg = apply_shared_cooling_systems(hpxml)
    applied_htg = apply_shared_heating_systems(hpxml)
    return unless (applied_clg || applied_htg)

    # Remove WLHP if not serving heating nor cooling
    hpxml.heat_pumps.each do |hp|
      next unless hp.heat_pump_type == HPXML::HVACTypeHeatPumpWaterLoopToAir
      next if hp.fraction_heat_load_served > 0
      next if hp.fraction_cool_load_served > 0

      hp.delete
    end

    # Remove any orphaned HVAC distributions
    hpxml.hvac_distributions.each do |hvac_distribution|
      hvac_systems = []
      hpxml.hvac_systems.each do |hvac_system|
        next if hvac_system.distribution_system_idref.nil?
        next unless hvac_system.distribution_system_idref == hvac_distribution.id

        hvac_systems << hvac_system
      end
      next unless hvac_systems.empty?

      hvac_distribution.delete
    end
  end

  def self.apply_shared_cooling_systems(hpxml)
    applied = false
    hpxml.cooling_systems.each do |cooling_system|
      next unless cooling_system.is_shared_system

      applied = true
      wlhp = nil
      distribution_system = cooling_system.distribution_system
      distribution_type = distribution_system.distribution_system_type

      # Calculate air conditioner SEER equivalent
      n_dweq = cooling_system.number_of_units_served.to_f
      aux = cooling_system.shared_loop_watts

      if cooling_system.cooling_system_type == HPXML::HVACTypeChiller

        # Chiller w/ baseboard or fan coil or water loop heat pump
        cap = cooling_system.cooling_capacity
        chiller_input = UnitConversions.convert(cooling_system.cooling_efficiency_kw_per_ton * UnitConversions.convert(cap, 'Btu/hr', 'ton'), 'kW', 'W')
        if distribution_type == HPXML::HVACDistributionTypeHydronic
          if distribution_system.hydronic_type == HPXML::HydronicTypeWaterLoop
            wlhp = hpxml.heat_pumps.select { |hp| hp.heat_pump_type == HPXML::HVACTypeHeatPumpWaterLoopToAir }[0]
            aux_dweq = wlhp.cooling_capacity / wlhp.cooling_efficiency_eer
          else
            aux_dweq = 0.0
          end
        elsif distribution_type == HPXML::HVACDistributionTypeAir
          if distribution_system.air_type == HPXML::AirTypeFanCoil
            aux_dweq = cooling_system.fan_coil_watts
          end
        end
        # ANSI/RESNET/ICC 301-2019 Equation 4.4-2
        seer_eq = (cap - 3.41 * aux - 3.41 * aux_dweq * n_dweq) / (chiller_input + aux + aux_dweq * n_dweq)

      elsif cooling_system.cooling_system_type == HPXML::HVACTypeCoolingTower

        # Cooling tower w/ water loop heat pump
        if distribution_type == HPXML::HVACDistributionTypeHydronic
          if distribution_system.hydronic_type == HPXML::HydronicTypeWaterLoop
            wlhp = hpxml.heat_pumps.select { |hp| hp.heat_pump_type == HPXML::HVACTypeHeatPumpWaterLoopToAir }[0]
            wlhp_cap = wlhp.cooling_capacity
            wlhp_input = wlhp_cap / wlhp.cooling_efficiency_eer
          end
        end
        # ANSI/RESNET/ICC 301-2019 Equation 4.4-3
        seer_eq = (wlhp_cap - 3.41 * aux / n_dweq) / (wlhp_input + aux / n_dweq)

      else
        fail "Unexpected cooling system type '#{cooling_system.cooling_system_type}'."
      end

      if seer_eq <= 0
        fail "Negative SEER equivalent calculated for cooling system '#{cooling_system.id}', double check inputs."
      end

      cooling_system.cooling_system_type = HPXML::HVACTypeCentralAirConditioner
      cooling_system.cooling_efficiency_seer = seer_eq.round(2)
      cooling_system.cooling_efficiency_kw_per_ton = nil
      cooling_system.cooling_capacity = nil # Autosize the equipment
      cooling_system.is_shared_system = false
      cooling_system.number_of_units_served = nil
      cooling_system.shared_loop_watts = nil
      cooling_system.shared_loop_motor_efficiency = nil
      cooling_system.fan_coil_watts = nil

      # Assign new distribution system to air conditioner
      if distribution_type == HPXML::HVACDistributionTypeHydronic
        if distribution_system.hydronic_type == HPXML::HydronicTypeWaterLoop
          # Assign WLHP air distribution
          cooling_system.distribution_system_idref = wlhp.distribution_system_idref
          wlhp.fraction_cool_load_served = 0.0
          wlhp.fraction_heat_load_served = 0.0
        else
          # Assign DSE=1
          hpxml.hvac_distributions.add(id: "#{cooling_system.id}AirDistributionSystem",
                                       distribution_system_type: HPXML::HVACDistributionTypeDSE,
                                       annual_cooling_dse: 1.0,
                                       annual_heating_dse: 1.0)
          cooling_system.distribution_system_idref = hpxml.hvac_distributions[-1].id
        end
      elsif (distribution_type == HPXML::HVACDistributionTypeAir) && (distribution_system.air_type == HPXML::AirTypeFanCoil)
        # Convert "fan coil" air distribution system to "regular velocity"
        if distribution_system.hvac_systems.size > 1
          # Has attached heating system, so create a copy specifically for the cooling system
          hpxml.hvac_distributions << distribution_system.dup
          hpxml.hvac_distributions[-1].id += "#{cooling_system.id}AirDistributionSystem"
          cooling_system.distribution_system_idref = hpxml.hvac_distributions[-1].id
        end
        hpxml.hvac_distributions[-1].air_type = HPXML::AirTypeRegularVelocity
        if hpxml.hvac_distributions[-1].duct_leakage_measurements.select { |lm| (lm.duct_type == HPXML::DuctTypeSupply) && (lm.duct_leakage_total_or_to_outside == HPXML::DuctLeakageToOutside) }.size == 0
          # Assign zero supply leakage
          hpxml.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                                     duct_leakage_units: HPXML::UnitsCFM25,
                                                                     duct_leakage_value: 0,
                                                                     duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
        end
        if hpxml.hvac_distributions[-1].duct_leakage_measurements.select { |lm| (lm.duct_type == HPXML::DuctTypeReturn) && (lm.duct_leakage_total_or_to_outside == HPXML::DuctLeakageToOutside) }.size == 0
          # Assign zero return leakage
          hpxml.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                                     duct_leakage_units: HPXML::UnitsCFM25,
                                                                     duct_leakage_value: 0,
                                                                     duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
        end
      end
    end

    return applied
  end

  def self.apply_shared_heating_systems(hpxml)
    applied = false
    hpxml.heating_systems.each do |heating_system|
      next unless heating_system.is_shared_system

      applied = true
      distribution_system = heating_system.distribution_system
      distribution_type = distribution_system.distribution_system_type
      hydronic_type = distribution_system.hydronic_type

      if heating_system.heating_system_type == HPXML::HVACTypeBoiler && hydronic_type.to_s == HPXML::HydronicTypeWaterLoop

        # Shared boiler w/ water loop heat pump
        # Per ANSI/RESNET/ICC 301-2019 Section 4.4.7.2, model as:
        # A) heat pump with constant efficiency and duct losses, fraction heat load served = 1/COP
        # B) boiler, fraction heat load served = 1-1/COP
        fraction_heat_load_served = heating_system.fraction_heat_load_served

        # Heat pump
        # If this approach is ever removed, also remove code in HVACSizing.apply_hvac_loads()
        wlhp = hpxml.heat_pumps.select { |hp| hp.heat_pump_type == HPXML::HVACTypeHeatPumpWaterLoopToAir }[0]
        wlhp.fraction_heat_load_served = fraction_heat_load_served * (1.0 / wlhp.heating_efficiency_cop)
        wlhp.fraction_cool_load_served = 0.0

        # Boiler
        heating_system.fraction_heat_load_served = fraction_heat_load_served * (1.0 - 1.0 / wlhp.heating_efficiency_cop)
      end

      heating_system.heating_capacity = nil # Autosize the equipment
    end

    return applied
  end

  def self.set_num_speeds(hvac_system)
    hvac_ap = hvac_system.additional_properties

    if hvac_system.is_a?(HPXML::CoolingSystem) && (hvac_system.cooling_system_type == HPXML::HVACTypeRoomAirConditioner)
      hvac_ap.num_speeds = 1
    elsif (hvac_system.is_a?(HPXML::CoolingSystem) && (hvac_system.cooling_system_type == HPXML::HVACTypeMiniSplitAirConditioner)) ||
          (hvac_system.is_a?(HPXML::HeatPump) && (hvac_system.heat_pump_type == HPXML::HVACTypeHeatPumpMiniSplit))
      hvac_ap.speed_indices = [1, 3, 5, 9] # Speeds we model
      hvac_ap.num_speeds = hvac_ap.speed_indices.size
    elsif hvac_system.compressor_type == HPXML::HVACCompressorTypeSingleStage
      hvac_ap.num_speeds = 1
    elsif hvac_system.compressor_type == HPXML::HVACCompressorTypeTwoStage
      hvac_ap.num_speeds =  2
    elsif hvac_system.compressor_type == HPXML::HVACCompressorTypeVariableSpeed
      hvac_ap.num_speeds =  4
    end
  end

  def self.calc_rated_airflow(capacity, rated_cfm_per_ton, capacity_ratio)
    return UnitConversions.convert(capacity, 'Btu/hr', 'ton') * UnitConversions.convert(rated_cfm_per_ton, 'cfm', 'm^3/s') * capacity_ratio
  end

  def self.is_central_air_conditioner_and_furnace(hpxml, heating_system, cooling_system)
    if not (hpxml.heating_systems.include?(heating_system) && (heating_system.heating_system_type == HPXML::HVACTypeFurnace))
      return false
    end
    if not (hpxml.cooling_systems.include?(cooling_system) && (cooling_system.cooling_system_type == HPXML::HVACTypeCentralAirConditioner))
      return false
    end

    return true
  end

  def self.get_hpxml_hvac_systems(hpxml)
    # Returns a list of heating/cooling systems, incorporating whether
    # multiple systems are connected to the same distribution system
    # (e.g., a furnace + central air conditioner w/ the same ducts).
    hvac_systems = []

    hpxml.cooling_systems.each do |cooling_system|
      heating_system = nil
      if is_central_air_conditioner_and_furnace(hpxml, cooling_system.attached_heating_system, cooling_system)
        heating_system = cooling_system.attached_heating_system
      end
      hvac_systems << { cooling: cooling_system,
                        heating: heating_system }
    end

    hpxml.heating_systems.each do |heating_system|
      if is_central_air_conditioner_and_furnace(hpxml, heating_system, heating_system.attached_cooling_system)
        next # Already processed combined AC+furnace
      end

      hvac_systems << { cooling: nil,
                        heating: heating_system }
    end

    hpxml.heat_pumps.each do |heat_pump|
      hvac_systems << { cooling: heat_pump,
                        heating: heat_pump }
    end

    return hvac_systems
  end

  def self.ensure_nonzero_sizing_values(hpxml)
    min_capacity = 1.0 # Btuh
    min_airflow = 3.0 # cfm; E+ min airflow is 0.001 m3/s
    hpxml.heating_systems.each do |htg_sys|
      htg_sys.heating_capacity = [htg_sys.heating_capacity, min_capacity].max
      htg_sys.heating_airflow_cfm = [htg_sys.heating_airflow_cfm, min_airflow].max
    end
    hpxml.cooling_systems.each do |clg_sys|
      clg_sys.cooling_capacity = [clg_sys.cooling_capacity, min_capacity].max
      clg_sys.cooling_airflow_cfm = [clg_sys.cooling_airflow_cfm, min_airflow].max
    end
    hpxml.heat_pumps.each do |hp_sys|
      hp_sys.cooling_capacity = [hp_sys.cooling_capacity, min_capacity].max
      hp_sys.cooling_airflow_cfm = [hp_sys.cooling_airflow_cfm, min_airflow].max
      hp_sys.additional_properties.cooling_capacity_sensible = [hp_sys.additional_properties.cooling_capacity_sensible, min_capacity].max
      hp_sys.heating_capacity = [hp_sys.heating_capacity, min_capacity].max
      hp_sys.heating_airflow_cfm = [hp_sys.heating_airflow_cfm, min_airflow].max
      if not hp_sys.heating_capacity_17F.nil?
        hp_sys.heating_capacity_17F = [hp_sys.heating_capacity_17F, min_capacity].max
      end
      if not hp_sys.backup_heating_capacity.nil?
        hp_sys.backup_heating_capacity = [hp_sys.backup_heating_capacity, min_capacity].max
      end
    end
  end

  def self.get_dehumidifier_default_values(capacity)
    rh_setpoint = 0.6
    if capacity <= 25.0
      ief = 0.79
    elsif capacity <= 35.0
      ief = 0.95
    elsif capacity <= 54.0
      ief = 1.04
    elsif capacity < 75.0
      ief = 1.20
    else
      ief = 1.82
    end

    return { rh_setpoint: rh_setpoint, ief: ief }
  end

  def self.get_default_hvac_efficiency_by_year_installed(year, hvac_type, fuel_type, units)
    if [HPXML::HVACTypeWallFurnace, HPXML::HVACTypeFloorFurnace].include? hvac_type
      # For wall/floor furnaces, map other fuel types to natural gas because the lookup table only provides efficiencies for natural gas.
      fuel_type = HPXML::FuelTypeNaturalGas
    end

    type_id = { HPXML::HVACTypeCentralAirConditioner => 'split_dx',
                HPXML::HVACTypeRoomAirConditioner => 'packaged_dx',
                HPXML::HVACTypeHeatPumpAirToAir => 'heat_pump',
                HPXML::HVACTypeFurnace => 'central_furnace',
                HPXML::HVACTypeWallFurnace => 'wall_furnace',
                HPXML::HVACTypeFloorFurnace => 'wall_furnace', # floor furnaces mapped to wall furnaces
                HPXML::HVACTypeBoiler => 'boiler' }[hvac_type]

    fuel_primary_id = { EPlus::FuelTypeElectricity => 'electric',
                        EPlus::FuelTypeNaturalGas => 'natural_gas',
                        EPlus::FuelTypeOil => 'fuel_oil',
                        EPlus::FuelTypeCoal => 'fuel_oil', # assumption
                        EPlus::FuelTypeWoodCord => 'fuel_oil', # assumption
                        EPlus::FuelTypeWoodPellets => 'fuel_oil', # assumption
                        EPlus::FuelTypePropane => 'lpg' }[EPlus.fuel_type(fuel_type)]

    metric_id = units.downcase
    value = nil
    lookup_year = 0
    CSV.foreach(File.join(File.dirname(__FILE__), 'lu_hvac_equipment_efficiency.csv'), headers: true) do |row|
      next unless row['type_id'] == type_id
      next unless row['fuel_primary_id'] == fuel_primary_id
      next unless row['metric_id'] == metric_id

      row_year = Integer(row['year'])
      if (row_year - year).abs <= (lookup_year - year).abs
        lookup_year = row_year
        value = Float(row['value'])
      end
    end

    return value
  end
end
