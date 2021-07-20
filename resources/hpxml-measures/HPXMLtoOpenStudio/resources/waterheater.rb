# frozen_string_literal: true

class Waterheater
  def self.apply_tank(model, loc_space, loc_schedule, water_heating_system, ec_adj, dhw_map,
                      hvac_map, solar_thermal_system)

    dhw_map[water_heating_system.id] = []

    solar_fraction = get_water_heater_solar_fraction(water_heating_system, solar_thermal_system)
    set_temp_c = get_set_temp_c(water_heating_system.temperature, water_heating_system.water_heater_type)
    loop = create_new_loop(model, Constants.ObjectNamePlantLoopDHW, set_temp_c)
    dhw_map[water_heating_system.id] << loop

    new_pump = create_new_pump(model)
    new_pump.addToNode(loop.supplyInletNode)

    new_manager = create_new_schedule_manager(model, set_temp_c)
    new_manager.addToNode(loop.supplyOutletNode)

    act_vol = calc_storage_tank_actual_vol(water_heating_system.tank_volume, water_heating_system.fuel_type)
    u, ua, eta_c = calc_tank_UA(act_vol, water_heating_system, solar_fraction)
    new_heater = create_new_heater(name: Constants.ObjectNameWaterHeater,
                                   water_heating_system: water_heating_system,
                                   act_vol: act_vol,
                                   t_set_c: set_temp_c,
                                   loc_space: loc_space,
                                   loc_schedule: loc_schedule,
                                   model: model,
                                   ua: ua,
                                   eta_c: eta_c)
    set_parasitic_power_for_storage_wh(water_heater: new_heater)
    dhw_map[water_heating_system.id] << new_heater

    loop.addSupplyBranchForComponent(new_heater)

    add_ec_adj(model, new_heater, ec_adj, loc_space, water_heating_system).each do |obj|
      dhw_map[water_heating_system.id] << obj unless obj.nil?
    end

    if water_heating_system.uses_desuperheater
      dhw_map[water_heating_system.id] << add_desuperheater(model, water_heating_system, hvac_map, new_heater, loc_space, loc_schedule, loop)
    end
  end

  def self.apply_tankless(model, loc_space, loc_schedule, water_heating_system, ec_adj, nbeds, dhw_map,
                          hvac_map, solar_thermal_system)

    dhw_map[water_heating_system.id] = []

    water_heating_system.heating_capacity = 100000000000.0
    solar_fraction = get_water_heater_solar_fraction(water_heating_system, solar_thermal_system)
    set_temp_c = get_set_temp_c(water_heating_system.temperature, water_heating_system.water_heater_type)
    loop = create_new_loop(model, Constants.ObjectNamePlantLoopDHW, set_temp_c)
    dhw_map[water_heating_system.id] << loop

    new_pump = create_new_pump(model)
    new_pump.addToNode(loop.supplyInletNode)

    new_manager = create_new_schedule_manager(model, set_temp_c)
    new_manager.addToNode(loop.supplyOutletNode)

    act_vol = 1.0
    u, ua, eta_c = calc_tank_UA(act_vol, water_heating_system, solar_fraction)
    new_heater = create_new_heater(name: Constants.ObjectNameWaterHeater,
                                   water_heating_system: water_heating_system,
                                   act_vol: act_vol,
                                   t_set_c: set_temp_c,
                                   loc_space: loc_space,
                                   loc_schedule: loc_schedule,
                                   model: model,
                                   ua: ua,
                                   eta_c: eta_c)
    set_parasitic_power_for_tankless_wh(nbeds: nbeds, water_heater: new_heater)
    dhw_map[water_heating_system.id] << new_heater

    loop.addSupplyBranchForComponent(new_heater)

    add_ec_adj(model, new_heater, ec_adj, loc_space, water_heating_system).each do |obj|
      dhw_map[water_heating_system.id] << obj unless obj.nil?
    end

    if water_heating_system.uses_desuperheater
      dhw_map[water_heating_system.id] << add_desuperheater(model, water_heating_system, hvac_map, new_heater, loc_space, loc_schedule, loop)
    end
  end

  def self.apply_heatpump(model, runner, loc_space, loc_schedule, weather, water_heating_system,
                          ec_adj, dhw_map, hvac_map, solar_thermal_system, living_zone)

    dhw_map[water_heating_system.id] = []

    obj_name_hpwh = Constants.ObjectNameWaterHeater
    solar_fraction = get_water_heater_solar_fraction(water_heating_system, solar_thermal_system)
    set_temp_c = get_set_temp_c(water_heating_system.temperature, water_heating_system.water_heater_type)
    loop = create_new_loop(model, Constants.ObjectNamePlantLoopDHW, set_temp_c)
    dhw_map[water_heating_system.id] << loop

    new_pump = create_new_pump(model)
    new_pump.addToNode(loop.supplyInletNode)

    new_manager = create_new_schedule_manager(model, set_temp_c)
    new_manager.addToNode(loop.supplyOutletNode)

    h_tank = 0.0188 * water_heating_system.tank_volume + 0.0935 # Linear relationship that gets GE height at 50 gal and AO Smith height at 80 gal

    # Add in schedules for Tamb, RHamb, and the compressor
    hpwh_tamb = OpenStudio::Model::ScheduleConstant.new(model)
    hpwh_tamb.setName("#{obj_name_hpwh} Tamb act")
    hpwh_tamb.setValue(23)

    hpwh_rhamb = OpenStudio::Model::ScheduleConstant.new(model)
    hpwh_rhamb.setName("#{obj_name_hpwh} RHamb act")
    hpwh_rhamb.setValue(0.5)

    tset_C = UnitConversions.convert(water_heating_system.temperature, 'F', 'C').to_f.round(2)

    hpwh_bottom_element_sp = OpenStudio::Model::ScheduleConstant.new(model)
    hpwh_bottom_element_sp.setName("#{obj_name_hpwh} BottomElementSetpoint")
    hpwh_bottom_element_sp.setValue(-60)

    hpwh_top_element_sp = OpenStudio::Model::ScheduleConstant.new(model)
    hpwh_top_element_sp.setName("#{obj_name_hpwh} TopElementSetpoint")
    hpwh_top_element_sp.setValue((tset_C - 9.0001).round(4))

    airflow_rate = 181.0 # cfm
    min_temp = 42.0 # F
    max_temp = 120.0 # F

    # WaterHeater:HeatPump:WrappedCondenser
    hpwh = setup_hpwh_wrapped_condenser(model, obj_name_hpwh, tset_C, h_tank, airflow_rate, hpwh_tamb, hpwh_rhamb, min_temp, max_temp)
    dhw_map[water_heating_system.id] << hpwh

    # Coil:WaterHeating:AirToWaterHeatPump:Wrapped
    coil = setup_hpwh_dxcoil(model, hpwh, water_heating_system, weather, obj_name_hpwh, airflow_rate)
    dhw_map[water_heating_system.id] << coil

    # WaterHeater:Stratified
    tank = setup_hpwh_stratified_tank(hpwh, water_heating_system, obj_name_hpwh, h_tank, solar_fraction, hpwh_tamb, hpwh_bottom_element_sp, hpwh_top_element_sp)
    loop.addSupplyBranchForComponent(tank)

    if water_heating_system.uses_desuperheater
      dhw_map[water_heating_system.id] << add_desuperheater(model, water_heating_system, hvac_map, tank, loc_space, loc_schedule, loop)
    end
    dhw_map[water_heating_system.id] << tank

    # Fan:OnOff
    fan = setup_hpwh_fan(hpwh, obj_name_hpwh, airflow_rate)
    dhw_map[water_heating_system.id] << fan

    # Amb temp & RH sensors, temp sensor shared across programs
    amb_temp_sensor, amb_rh_sensors = get_loc_temp_rh_sensors(model, obj_name_hpwh, loc_schedule, loc_space, living_zone)
    hpwh_inlet_air_program = add_hpwh_inlet_air_and_zone_heat_gain_program(model, obj_name_hpwh, loc_space, loc_schedule, hpwh_tamb, hpwh_rhamb, tank, coil, fan, amb_temp_sensor, amb_rh_sensors)

    # EMS for the HPWH control logic
    hpwh_ctrl_program = add_hpwh_control_program(model, obj_name_hpwh, amb_temp_sensor, hpwh_bottom_element_sp, min_temp, max_temp, tset_C)

    # ProgramCallingManagers
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName("#{obj_name_hpwh} ProgramManager")
    program_calling_manager.setCallingPoint('InsideHVACSystemIterationLoop')
    program_calling_manager.addProgram(hpwh_ctrl_program)
    program_calling_manager.addProgram(hpwh_inlet_air_program)

    add_ec_adj(model, hpwh, ec_adj, loc_space, water_heating_system).each do |obj|
      dhw_map[water_heating_system.id] << obj unless obj.nil?
    end
  end

  def self.apply_combi(model, runner, loc_space, loc_schedule, water_heating_system, ec_adj,
                       dhw_map, hvac_map, solar_thermal_system)

    dhw_map[water_heating_system.id] = []

    solar_fraction = get_water_heater_solar_fraction(water_heating_system, solar_thermal_system)
    boiler, boiler_plant_loop = get_combi_boiler_and_plant_loop(hvac_map, water_heating_system.related_hvac_idref)
    dhw_map[water_heating_system.id] << boiler

    obj_name_combi = Constants.ObjectNameWaterHeater
    convlim = model.getConvergenceLimits
    convlim.setMinimumPlantIterations(3) # add one more minimum plant iteration to achieve better energy balance across plant loops.

    if water_heating_system.water_heater_type == HPXML::WaterHeaterTypeCombiStorage
      if water_heating_system.standby_loss <= 0
        fail 'A negative indirect water heater standby loss was calculated, double check water heater inputs.'
      end

      act_vol = calc_storage_tank_actual_vol(water_heating_system.tank_volume, nil)
      a_side = calc_tank_areas(act_vol)[1]
      ua = calc_indirect_ua_with_standbyloss(act_vol, water_heating_system, a_side, solar_fraction)
    else
      ua = 0.0
      act_vol = 1.0
    end

    set_temp_c = get_set_temp_c(water_heating_system.temperature, water_heating_system.water_heater_type)
    loop = create_new_loop(model, Constants.ObjectNamePlantLoopDHW, set_temp_c)

    new_pump = create_new_pump(model)
    new_pump.addToNode(loop.supplyInletNode)

    new_manager = create_new_schedule_manager(model, set_temp_c)
    new_manager.addToNode(loop.supplyOutletNode)

    # Create water heater
    new_heater = create_new_heater(name: obj_name_combi,
                                   water_heating_system: water_heating_system,
                                   act_vol: act_vol,
                                   t_set_c: set_temp_c,
                                   loc_space: loc_space,
                                   loc_schedule: loc_schedule,
                                   model: model,
                                   ua: ua,
                                   is_combi: true)
    set_parasitic_power_for_storage_wh(water_heater: new_heater)
    new_heater.setSourceSideDesignFlowRate(100) # set one large number, override by EMS
    dhw_map[water_heating_system.id] << new_heater

    # Store combi assumed EF for ERI calculation
    ef = calc_tank_EF(water_heating_system.water_heater_type, ua, water_heating_system.related_hvac_system.heating_efficiency_afue)
    new_heater.additionalProperties.setFeature('EnergyFactor', ef)

    # Create alternate setpoint schedule for source side flow request
    alternate_stp_sch = OpenStudio::Model::ScheduleConstant.new(model)
    alternate_stp_sch.setName("#{obj_name_combi} Alt Spt")
    alt_temp = get_set_temp_c(water_heating_system.temperature, water_heating_system.water_heater_type)
    alternate_stp_sch.setValue(alt_temp)
    new_heater.setIndirectAlternateSetpointTemperatureSchedule(alternate_stp_sch)

    # Create hx setpoint schedule to specify source side temperature
    hx_stp_sch = OpenStudio::Model::ScheduleConstant.new(model)
    hx_stp_sch.setName("#{obj_name_combi} HX Spt")
    boiler_spt_mngr = model.getSetpointManagerScheduleds.select { |spt_mngr| spt_mngr.setpointNode.get == boiler_plant_loop.loopTemperatureSetpointNode }[0]
    boiler_spt = boiler_spt_mngr.to_SetpointManagerScheduled.get.schedule.to_ScheduleConstant.get.value
    hx_temp = (UnitConversions.convert(water_heating_system.temperature, 'F', 'C') + deadband(water_heating_system.water_heater_type) / 2.0 + boiler_spt) / 2.0 # tank source side inlet temperature, degree C
    hx_stp_sch.setValue(hx_temp)

    # change loop equipment operation scheme to heating load
    scheme_dhw = OpenStudio::Model::PlantEquipmentOperationHeatingLoad.new(model)
    scheme_dhw.addEquipment(1000000000, new_heater)
    loop.setPrimaryPlantEquipmentOperationScheme(scheme_dhw)
    dhw_map[water_heating_system.id] << loop

    # Create loop for source side
    source_loop = create_new_loop(model, 'dhw source loop', hx_temp)
    source_loop.autosizeMaximumLoopFlowRate()

    # Create heat exchanger
    combi_hx = create_new_hx(model, Constants.ObjectNameTankHX)
    dhw_map[water_heating_system.id] << combi_hx

    # Add heat exchanger to the load distribution scheme
    scheme = OpenStudio::Model::PlantEquipmentOperationHeatingLoad.new(model)
    scheme.addEquipment(1000000000, combi_hx)
    source_loop.setPrimaryPlantEquipmentOperationScheme(scheme)

    # Add components to the tank source side plant loop
    source_loop.addSupplyBranchForComponent(combi_hx)

    new_pump = create_new_pump(model)
    new_pump.autosizeRatedFlowRate()
    new_pump.addToNode(source_loop.supplyInletNode)
    dhw_map[water_heating_system.id] << new_pump

    new_source_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, hx_stp_sch)
    new_source_manager.addToNode(source_loop.supplyOutletNode)
    dhw_map[water_heating_system.id] << new_source_manager

    source_loop.addDemandBranchForComponent(new_heater)

    # Add heat exchanger to boiler loop
    boiler_plant_loop.addDemandBranchForComponent(combi_hx)
    boiler_plant_loop.setPlantLoopVolume(0.001) # Cannot be autocalculated because of large default tank source side mfr(set to be overwritten by EMS)

    loop.addSupplyBranchForComponent(new_heater)

    add_ec_adj(model, new_heater, ec_adj, loc_space, water_heating_system, boiler, combi_hx).each do |obj|
      dhw_map[water_heating_system.id] << obj unless obj.nil?
    end
  end

  def self.apply_combi_system_EMS(model, dhw_map, water_heating_systems)
    combi_sys_ids = water_heating_systems.select { |wh| [HPXML::WaterHeaterTypeCombiStorage, HPXML::WaterHeaterTypeCombiTankless].include? wh.water_heater_type }.map { |wh| wh.id }

    dhw_map.keys.each do |sys_id|
      next unless combi_sys_ids.include? sys_id

      # EMS for modulate source side mass flow rate
      # Initialization
      equipment_peaks = {}
      equipment_sch_sensors = {}
      equipment_target_temp_sensors = {}
      tank_volume, deadband, tank_source_temp = 0.0, 0.0, 0.0
      alt_spt_sch = nil
      tank_temp_sensor, tank_spt_sensor, tank_loss_energy_sensor = nil, nil, nil
      altsch_actuator, pump_actuator = nil, nil

      # Create sensors and actuators by dhw map information
      dhw_map[sys_id].each do |object|
        if object.is_a? OpenStudio::Model::WaterUseConnections
          object.waterUseEquipment.each do |wu|
            # water use equipment peak mass flow rate
            wu_peak = wu.waterUseEquipmentDefinition.peakFlowRate
            equipment_peaks[wu.name.to_s] = wu_peak
            # mfr fraction schedule sensors
            wu_sch_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
            wu_sch_sensor.setName("#{wu.name} sch value")
            wu_sch_sensor.setKeyName(wu.flowRateFractionSchedule.get.name.to_s)
            equipment_sch_sensors[wu.name.to_s] = wu_sch_sensor
            # water use equipment target temperature schedule sensors
            target_temp_sch = wu.waterUseEquipmentDefinition.targetTemperatureSchedule.get
            target_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
            target_temp_sensor.setName("#{wu.name} target temp")
            target_temp_sensor.setKeyName(target_temp_sch.name.to_s)
            equipment_target_temp_sensors[wu.name.to_s] = target_temp_sensor
          end
        elsif object.is_a? OpenStudio::Model::WaterHeaterMixed
          # Some parameters to use
          tank_volume = object.tankVolume.get
          deadband = object.deadbandTemperatureDifference
          # Sensors and actuators related to OS water heater object
          tank_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Water Heater Tank Temperature')
          tank_temp_sensor.setName("#{sys_id} Tank Temp")
          tank_temp_sensor.setKeyName(object.name.to_s)
          tank_loss_energy_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Water Heater Heat Loss Energy')
          tank_loss_energy_sensor.setName("#{sys_id} Tank Loss Energy")
          tank_loss_energy_sensor.setKeyName(object.name.to_s)
          tank_spt_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
          tank_spt_sensor.setName("#{sys_id} Setpoint Temperature")
          tank_spt_sensor.setKeyName(object.setpointTemperatureSchedule.get.name.to_s)
          alt_spt_sch = object.indirectAlternateSetpointTemperatureSchedule.get
          altsch_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(alt_spt_sch, *EPlus::EMSActuatorScheduleConstantValue)
          altsch_actuator.setName("#{sys_id} AltSchedOverride")
        elsif object.is_a? OpenStudio::Model::PumpVariableSpeed
          pump_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(object, *EPlus::EMSActuatorPumpMassFlowRate)
          pump_actuator.setName("#{sys_id} Pump MFR")
        elsif object.is_a? OpenStudio::Model::SetpointManagerScheduled
          tank_source_temp = object.schedule.to_ScheduleConstant.get.value
        end
      end

      mains_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Mains Water Temperature')
      mains_temp_sensor.setName('Mains Temperature')
      mains_temp_sensor.setKeyName('*')

      # Program
      combi_ctrl_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      combi_ctrl_program.setName("#{sys_id} Source MFR Control")
      combi_ctrl_program.addLine("Set Rho = @RhoH2O #{tank_temp_sensor.name}")
      combi_ctrl_program.addLine("Set Cp = @CpHW #{tank_temp_sensor.name}")
      combi_ctrl_program.addLine("Set Tank_Water_Mass = #{tank_volume} * Rho")
      combi_ctrl_program.addLine("Set DeltaT = #{tank_source_temp} - #{tank_spt_sensor.name}")
      combi_ctrl_program.addLine("Set WU_Hot_Temp = #{tank_temp_sensor.name}")
      combi_ctrl_program.addLine("Set WU_Cold_Temp = #{mains_temp_sensor.name}")
      combi_ctrl_program.addLine('Set Tank_Use_Total_MFR = 0.0')
      equipment_peaks.each do |wu_name, peak|
        wu_id = wu_name.gsub(' ', '_')
        combi_ctrl_program.addLine("Set #{wu_id}_Peak = #{peak}")
        combi_ctrl_program.addLine("Set #{wu_id}_MFR_Total = #{wu_id}_Peak * #{equipment_sch_sensors[wu_name].name} * Rho")
        combi_ctrl_program.addLine("If #{equipment_target_temp_sensors[wu_name].name} > WU_Hot_Temp")
        combi_ctrl_program.addLine("Set #{wu_id}_MFR_Hot = #{wu_id}_MFR_Total")
        combi_ctrl_program.addLine('Else')
        combi_ctrl_program.addLine("Set #{wu_id}_MFR_Hot = #{wu_id}_MFR_Total * (#{equipment_target_temp_sensors[wu_name].name} - WU_Cold_Temp)/(WU_Hot_Temp - WU_Cold_Temp)")
        combi_ctrl_program.addLine('EndIf')
        combi_ctrl_program.addLine("Set Tank_Use_Total_MFR = Tank_Use_Total_MFR + #{wu_id}_MFR_Hot")
      end
      combi_ctrl_program.addLine("Set WH_Loss = - #{tank_loss_energy_sensor.name}")
      combi_ctrl_program.addLine("Set WH_Use = Tank_Use_Total_MFR * Cp * (#{tank_temp_sensor.name} - #{mains_temp_sensor.name}) * ZoneTimeStep * 3600")
      combi_ctrl_program.addLine("Set WH_HeatToLowSetpoint = Tank_Water_Mass * Cp * (#{tank_temp_sensor.name} - #{tank_spt_sensor.name} + #{deadband})")
      combi_ctrl_program.addLine("Set WH_HeatToHighSetpoint = Tank_Water_Mass * Cp * (#{tank_temp_sensor.name} - #{tank_spt_sensor.name})")
      combi_ctrl_program.addLine('Set WH_Energy_Demand = WH_Use + WH_Loss - WH_HeatToLowSetpoint')
      combi_ctrl_program.addLine('Set WH_Energy_Heat = WH_Use + WH_Loss - WH_HeatToHighSetpoint')
      combi_ctrl_program.addLine('If WH_Energy_Demand > 0')
      combi_ctrl_program.addLine("Set #{pump_actuator.name} = WH_Energy_Heat / (Cp * DeltaT * 3600 * ZoneTimeStep)")
      combi_ctrl_program.addLine("Set #{altsch_actuator.name} = 100") # Set the alternate setpoint temperature to highest level to ensure maximum source side flow rate
      combi_ctrl_program.addLine('Else')
      combi_ctrl_program.addLine("Set #{pump_actuator.name} = 0")
      combi_ctrl_program.addLine("Set #{altsch_actuator.name} = #{alt_spt_sch.to_ScheduleConstant.get.value}")
      combi_ctrl_program.addLine('EndIf')

      # ProgramCallingManagers
      program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      program_calling_manager.setName("#{sys_id} ProgramManager")
      program_calling_manager.setCallingPoint('BeginTimestepBeforePredictor')
      program_calling_manager.addProgram(combi_ctrl_program)
    end
  end

  def self.apply_solar_thermal(model, loc_space, loc_schedule, solar_thermal_system, dhw_map)
    if [HPXML::WaterHeaterTypeCombiStorage, HPXML::WaterHeaterTypeCombiTankless].include? solar_thermal_system.water_heating_system.water_heater_type
      fail "Water heating system '#{solar_thermal_system.water_heating_system.id}' connected to solar thermal system '#{solar_thermal_system.id}' cannot be a space-heating boiler."
    end
    if solar_thermal_system.water_heating_system.uses_desuperheater
      fail "Water heating system '#{solar_thermal_system.water_heating_system.id}' connected to solar thermal system '#{solar_thermal_system.id}' cannot be attached to a desuperheater."
    end

    dhw_loop = nil
    if dhw_map.keys.include? solar_thermal_system.water_heating_system.id
      dhw_map[solar_thermal_system.water_heating_system.id].each do |dhw_object|
        next unless dhw_object.is_a? OpenStudio::Model::PlantLoop

        dhw_loop = dhw_object
      end
    end

    obj_name = Constants.ObjectNameSolarHotWater

    if [HPXML::SolarThermalTypeEvacuatedTube].include? solar_thermal_system.collector_type
      iam_coeff2 = 0.3023 # IAM coeff1=1 by definition, values based on a system listed by SRCC with values close to the average
      iam_coeff3 = -0.3057
    elsif [HPXML::SolarThermalTypeSingleGlazing, HPXML::SolarThermalTypeDoubleGlazing].include? solar_thermal_system.collector_type
      iam_coeff2 = 0.1
      iam_coeff3 = 0
    elsif [HPXML::SolarThermalTypeICS].include? solar_thermal_system.collector_type
      iam_coeff2 = 0.1
      iam_coeff3 = 0
    end

    if [HPXML::SolarThermalLoopTypeIndirect].include? solar_thermal_system.collector_loop_type
      fluid_type = Constants.FluidPropyleneGlycol
      heat_ex_eff = 0.7
    elsif [HPXML::SolarThermalLoopTypeDirect, HPXML::SolarThermalLoopTypeThermosyphon].include? solar_thermal_system.collector_loop_type
      fluid_type = Constants.FluidWater
      heat_ex_eff = 1.0
    end

    if solar_thermal_system.collector_loop_type == HPXML::SolarThermalLoopTypeThermosyphon
      pump_power = 0.0
    else
      pump_power = 0.8 * solar_thermal_system.collector_area
    end

    tank_r = 10.0
    test_flow = 55.0 / UnitConversions.convert(1.0, 'lbm/min', 'kg/hr') / Liquid.H2O_l.rho * UnitConversions.convert(1.0, 'ft^2', 'm^2') # cfm/ft^2
    coll_flow = test_flow * solar_thermal_system.collector_area # cfm
    storage_Uvalue = 1.0 / tank_r # Btu/hr-ft^2-R

    # Get water heater and setpoint temperature schedules from loop
    water_heater = nil
    setpoint_schedule_one = nil
    setpoint_schedule_two = nil
    dhw_loop.supplyComponents.each do |supply_component|
      if supply_component.to_WaterHeaterMixed.is_initialized
        water_heater = supply_component.to_WaterHeaterMixed.get
        setpoint_schedule_one = water_heater.setpointTemperatureSchedule.get
        setpoint_schedule_two = water_heater.setpointTemperatureSchedule.get
      elsif supply_component.to_WaterHeaterStratified.is_initialized
        water_heater = supply_component.to_WaterHeaterStratified.get
        setpoint_schedule_one = water_heater.heater1SetpointTemperatureSchedule
        setpoint_schedule_two = water_heater.heater2SetpointTemperatureSchedule
      end
    end

    dhw_setpoint_manager = nil
    dhw_loop.supplyOutletNode.setpointManagers.each do |setpoint_manager|
      if setpoint_manager.to_SetpointManagerScheduled.is_initialized
        dhw_setpoint_manager = setpoint_manager.to_SetpointManagerScheduled.get
      end
    end

    plant_loop = OpenStudio::Model::PlantLoop.new(model)
    plant_loop.setName(Constants.ObjectNamePlantLoopSHW)
    if fluid_type == Constants.FluidWater
      plant_loop.setFluidType('Water')
    else
      plant_loop.setFluidType('PropyleneGlycol')
      plant_loop.setGlycolConcentration(50)
    end
    plant_loop.setMaximumLoopTemperature(100)
    plant_loop.setMinimumLoopTemperature(0)
    plant_loop.setMinimumLoopFlowRate(0)
    plant_loop.setLoadDistributionScheme('Optimal')
    plant_loop.setPlantEquipmentOperationHeatingLoadSchedule(model.alwaysOnDiscreteSchedule)

    sizing_plant = plant_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(dhw_loop.sizingPlant.designLoopExitTemperature)
    sizing_plant.setLoopDesignTemperatureDifference(UnitConversions.convert(10.0, 'R', 'K'))

    setpoint_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, dhw_setpoint_manager.schedule)
    setpoint_manager.setName(obj_name + ' setpoint mgr')
    setpoint_manager.setControlVariable('Temperature')

    pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    pump.setName(obj_name + ' pump')
    pump.setRatedPumpHead(90000)
    pump.setRatedPowerConsumption(pump_power)
    pump.setMotorEfficiency(0.3)
    pump.setFractionofMotorInefficienciestoFluidStream(0.2)
    pump.setPumpControlType('Intermittent')
    pump.setRatedFlowRate(UnitConversions.convert(coll_flow, 'cfm', 'm^3/s'))
    pump.addToNode(plant_loop.supplyInletNode)
    dhw_map[solar_thermal_system.water_heating_system.id] << pump

    panel_length = UnitConversions.convert(solar_thermal_system.collector_area, 'ft^2', 'm^2')**0.5
    run = Math::cos(solar_thermal_system.collector_tilt * Math::PI / 180) * panel_length

    offset = 1000.0 # prevent shading

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new(offset, offset, 0)
    vertices << OpenStudio::Point3d.new(offset + panel_length, offset, 0)
    vertices << OpenStudio::Point3d.new(offset + panel_length, offset + run, (panel_length**2 - run**2)**0.5)
    vertices << OpenStudio::Point3d.new(offset, offset + run, (panel_length**2 - run**2)**0.5)

    m = OpenStudio::Matrix.new(4, 4, 0)
    azimuth = Float(solar_thermal_system.collector_azimuth)
    m[0, 0] = Math::cos((180 - azimuth) * Math::PI / 180)
    m[1, 1] = Math::cos((180 - azimuth) * Math::PI / 180)
    m[0, 1] = -Math::sin((180 - azimuth) * Math::PI / 180)
    m[1, 0] = Math::sin((180 - azimuth) * Math::PI / 180)
    m[2, 2] = 1
    m[3, 3] = 1
    transformation = OpenStudio::Transformation.new(m)
    vertices = transformation * vertices

    shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
    shading_surface_group.setName(obj_name + ' shading group')

    shading_surface = OpenStudio::Model::ShadingSurface.new(vertices, model)
    shading_surface.setName(obj_name + ' shading surface')
    shading_surface.setShadingSurfaceGroup(shading_surface_group)

    if solar_thermal_system.collector_type == HPXML::SolarThermalTypeICS
      collector_plate = OpenStudio::Model::SolarCollectorIntegralCollectorStorage.new(model)
      collector_plate.setName(obj_name + ' coll plate')
      collector_plate.setSurface(shading_surface)
      collector_plate.setMaximumFlowRate(UnitConversions.convert(coll_flow, 'cfm', 'm^3/s'))

      ics_performance = collector_plate.solarCollectorPerformance
      # Values are based on spec sheet + OG-100 listing for Solarheart ICS collectors
      ics_performance.setName(obj_name + ' coll perf')
      ics_performance.setGrossArea(UnitConversions.convert(solar_thermal_system.collector_area, 'ft^2', 'm^2'))
      ics_performance.setCollectorWaterVolume(UnitConversions.convert(solar_thermal_system.storage_volume, 'gal', 'm^3'))
      ics_performance.setBottomHeatLossConductance(1.902) # Spec sheet
      ics_performance.setSideHeatLossConductance(1.268)
      ics_performance.setAspectRatio(0.721)
      ics_performance.setCollectorSideHeight(0.17272)
      ics_performance.setNumberOfCovers(1)
      ics_performance.setAbsorptanceOfAbsorberPlate(0.94)
      ics_performance.setEmissivityOfAbsorberPlate(0.56)
      collector_plate.setSolarCollectorPerformance(ics_performance)

    else
      collector_plate = OpenStudio::Model::SolarCollectorFlatPlateWater.new(model)
      collector_plate.setName(obj_name + ' coll plate')
      collector_plate.setSurface(shading_surface)
      collector_plate.setMaximumFlowRate(UnitConversions.convert(coll_flow, 'cfm', 'm^3/s'))
      collector_performance = collector_plate.solarCollectorPerformance
      collector_performance.setName(obj_name + ' coll perf')
      collector_performance.setGrossArea(UnitConversions.convert(solar_thermal_system.collector_area, 'ft^2', 'm^2'))
      collector_performance.setTestFluid('Water')
      collector_performance.setTestFlowRate(UnitConversions.convert(coll_flow, 'cfm', 'm^3/s'))
      collector_performance.setTestCorrelationType('Inlet')
      collector_performance.setCoefficient1ofEfficiencyEquation(solar_thermal_system.collector_frta)
      collector_performance.setCoefficient2ofEfficiencyEquation(-UnitConversions.convert(solar_thermal_system.collector_frul, 'Btu/(hr*ft^2*F)', 'W/(m^2*K)'))
      collector_performance.setCoefficient2ofIncidentAngleModifier(-iam_coeff2)
      collector_performance.setCoefficient3ofIncidentAngleModifier(iam_coeff3)

    end

    plant_loop.addSupplyBranchForComponent(collector_plate)

    pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
    pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)

    plant_loop.addSupplyBranchForComponent(pipe_supply_bypass)
    pump.addToNode(plant_loop.supplyInletNode)
    pipe_supply_outlet.addToNode(plant_loop.supplyOutletNode)
    setpoint_manager.addToNode(plant_loop.supplyOutletNode)
    plant_loop.addDemandBranchForComponent(pipe_demand_bypass)
    pipe_demand_inlet.addToNode(plant_loop.demandInletNode)
    pipe_demand_outlet.addToNode(plant_loop.demandOutletNode)

    storage_tank = OpenStudio::Model::WaterHeaterStratified.new(model)
    storage_tank.setName(obj_name + ' storage tank')
    storage_tank.setSourceSideEffectiveness(heat_ex_eff)
    storage_tank.setTankShape('VerticalCylinder')
    if (solar_thermal_system.collector_type == HPXML::SolarThermalTypeICS) || (fluid_type == Constants.FluidWater) # Use a 60 gal tank dummy tank for direct systems, storage volume for ICS is assumed to be collector volume
      storage_tank.setTankVolume(0.2271)
      storage_tank.setTankHeight(1.3755)
      storage_tank.setTankPerimeter(0.120)
      storage_tank.setUseSideOutletHeight(1.3755)
      storage_tank.setSourceSideInletHeight(1.3755 / 3.0)
    else
      storage_diam = (4.0 * UnitConversions.convert(solar_thermal_system.storage_volume, 'gal', 'ft^3') / 3.0 / Math::PI)**(1.0 / 3.0) # ft
      storage_ht = 3.0 * storage_diam # ft
      storage_tank.setTankVolume(UnitConversions.convert(solar_thermal_system.storage_volume, 'gal', 'm^3'))
      storage_tank.setTankHeight(UnitConversions.convert(storage_ht, 'ft', 'm'))
      storage_tank.setTankPerimeter(Math::PI * UnitConversions.convert(storage_diam, 'in', 'm'))
      storage_tank.setUseSideOutletHeight(UnitConversions.convert(storage_ht, 'ft', 'm'))
      storage_tank.setSourceSideInletHeight(UnitConversions.convert(storage_ht, 'ft', 'm') / 3.0)
    end
    storage_tank.setMaximumTemperatureLimit(99)
    storage_tank.heater1SetpointTemperatureSchedule.remove
    storage_tank.setHeater1SetpointTemperatureSchedule(setpoint_schedule_one)
    storage_tank.setHeater1Capacity(0)
    storage_tank.setHeater1Height(0)
    storage_tank.heater2SetpointTemperatureSchedule.remove
    storage_tank.setHeater2SetpointTemperatureSchedule(setpoint_schedule_two)
    storage_tank.setHeater2Capacity(0)
    storage_tank.setHeater2Height(0)
    storage_tank.setHeaterFuelType(EPlus::FuelTypeElectricity)
    storage_tank.setHeaterThermalEfficiency(1)
    storage_tank.ambientTemperatureSchedule.get.remove
    set_wh_ambient(loc_space, loc_schedule, model, storage_tank)
    if fluid_type == Constants.FluidWater # Direct, make the storage tank a dummy tank with 0 tank losses
      storage_tank.setUniformSkinLossCoefficientperUnitAreatoAmbientTemperature(0.0)
    else
      storage_tank.setUniformSkinLossCoefficientperUnitAreatoAmbientTemperature(UnitConversions.convert(storage_Uvalue, 'Btu/(hr*ft^2*F)', 'W/(m^2*K)'))
    end
    storage_tank.setSkinLossFractiontoZone(1)
    storage_tank.setOffCycleFlueLossFractiontoZone(1)
    storage_tank.setUseSideEffectiveness(1)
    storage_tank.setUseSideInletHeight(0)
    storage_tank.setSourceSideOutletHeight(0)
    storage_tank.setInletMode('Fixed')
    storage_tank.setIndirectWaterHeatingRecoveryTime(1.5)
    storage_tank.setNumberofNodes(8)
    storage_tank.setAdditionalDestratificationConductivity(0)
    storage_tank.setNode1AdditionalLossCoefficient(0)
    storage_tank.setNode2AdditionalLossCoefficient(0)
    storage_tank.setNode3AdditionalLossCoefficient(0)
    storage_tank.setNode4AdditionalLossCoefficient(0)
    storage_tank.setNode5AdditionalLossCoefficient(0)
    storage_tank.setNode6AdditionalLossCoefficient(0)
    storage_tank.setNode7AdditionalLossCoefficient(0)
    storage_tank.setNode8AdditionalLossCoefficient(0)
    storage_tank.setSourceSideDesignFlowRate(UnitConversions.convert(coll_flow, 'cfm', 'm^3/s'))
    storage_tank.setOnCycleParasiticFuelConsumptionRate(0)
    storage_tank.setOffCycleParasiticFuelConsumptionRate(0)
    storage_tank.setUseSideDesignFlowRate(UnitConversions.convert(solar_thermal_system.storage_volume, 'gal', 'm^3') / 60.1) # Sized to ensure that E+ never autosizes the design flow rate to be larger than the tank volume getting drawn out in a hour (60 minutes)
    dhw_map[solar_thermal_system.water_heating_system.id] << storage_tank

    plant_loop.addDemandBranchForComponent(storage_tank)
    dhw_loop.addSupplyBranchForComponent(storage_tank)
    water_heater.addToNode(storage_tank.supplyOutletModelObject.get.to_Node.get)

    availability_manager = OpenStudio::Model::AvailabilityManagerDifferentialThermostat.new(model)
    availability_manager.setName(obj_name + ' useful energy')
    availability_manager.setHotNode(collector_plate.outletModelObject.get.to_Node.get)
    availability_manager.setColdNode(storage_tank.demandOutletModelObject.get.to_Node.get)
    availability_manager.setTemperatureDifferenceOnLimit(0)
    availability_manager.setTemperatureDifferenceOffLimit(0)
    plant_loop.setAvailabilityManager(availability_manager)

    # Add EMS code for SWH control (keeps the WH for the last hour if there's useful energy that can be delivered, E+ wouldn't always do this by default)
    # Sensors
    coll_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'System Node Temperature')
    coll_sensor.setName("#{obj_name} Collector Outlet")
    coll_sensor.setKeyName("#{collector_plate.outletModelObject.get.to_Node.get.name}")

    tank_source_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'System Node Temperature')
    tank_source_sensor.setName("#{obj_name} Tank Source Inlet")
    tank_source_sensor.setKeyName("#{storage_tank.demandOutletModelObject.get.to_Node.get.name}")

    # Actuators
    swh_pump_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(pump, *EPlus::EMSActuatorPumpMassFlowRate)
    swh_pump_actuator.setName("#{obj_name}_pump")

    # Program
    swh_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    swh_program.setName("#{obj_name} Controller")
    swh_program.addLine("If #{coll_sensor.name} > #{tank_source_sensor.name}")
    swh_program.addLine("Set #{swh_pump_actuator.name} = 100")
    swh_program.addLine('Else')
    swh_program.addLine("Set #{swh_pump_actuator.name} = 0")
    swh_program.addLine('EndIf')

    # ProgramCallingManager
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName("#{obj_name} Control")
    program_calling_manager.setCallingPoint('InsideHVACSystemIterationLoop')
    program_calling_manager.addProgram(swh_program)
  end

  private

  def self.setup_hpwh_wrapped_condenser(model, obj_name_hpwh, tset_C, h_tank, airflow_rate, hpwh_tamb, hpwh_rhamb, min_temp, max_temp)
    h_condtop = (1.0 - (5.5 / 12.0)) * h_tank # in the 6th node of the tank (counting from top)
    h_condbot = 0.01 # bottom node
    h_hpctrl_up = (1.0 - (2.5 / 12.0)) * h_tank # in the 3rd node of the tank
    h_hpctrl_low = (1.0 - (8.5 / 12.0)) * h_tank # in the 9th node of the tank
    hp_setpoint = OpenStudio::Model::ScheduleConstant.new(model)
    hp_setpoint.setName("#{obj_name_hpwh} WaterHeaterHPSchedule")
    hp_setpoint.setValue(tset_C)
    hpwh = OpenStudio::Model::WaterHeaterHeatPumpWrappedCondenser.new(model)
    hpwh.setName("#{obj_name_hpwh} hpwh")
    hpwh.setCompressorSetpointTemperatureSchedule(hp_setpoint)
    hpwh.setDeadBandTemperatureDifference(3.89)
    hpwh.setCondenserBottomLocation(h_condbot)
    hpwh.setCondenserTopLocation(h_condtop)
    hpwh.setEvaporatorAirFlowRate(UnitConversions.convert(airflow_rate, 'ft^3/min', 'm^3/s'))
    hpwh.setInletAirConfiguration('Schedule')
    hpwh.setInletAirTemperatureSchedule(hpwh_tamb)
    hpwh.setInletAirHumiditySchedule(hpwh_rhamb)
    hpwh.setMinimumInletAirTemperatureforCompressorOperation(UnitConversions.convert(min_temp, 'F', 'C'))
    hpwh.setMaximumInletAirTemperatureforCompressorOperation(UnitConversions.convert(max_temp, 'F', 'C'))
    hpwh.setCompressorLocation('Schedule')
    hpwh.setCompressorAmbientTemperatureSchedule(hpwh_tamb)
    hpwh.setFanPlacement('DrawThrough')
    hpwh.setOnCycleParasiticElectricLoad(0)
    hpwh.setOffCycleParasiticElectricLoad(0)
    hpwh.setParasiticHeatRejectionLocation('Outdoors')
    hpwh.setTankElementControlLogic('MutuallyExclusive')
    hpwh.setControlSensor1HeightInStratifiedTank(h_hpctrl_up)
    hpwh.setControlSensor1Weight(0.75)
    hpwh.setControlSensor2HeightInStratifiedTank(h_hpctrl_low)

    return hpwh
  end

  def self.setup_hpwh_dxcoil(model, hpwh, water_heating_system, weather, obj_name_hpwh, airflow_rate)
    # Curves
    hpwh_cap = OpenStudio::Model::CurveBiquadratic.new(model)
    hpwh_cap.setName('HPWH-Cap-fT')
    hpwh_cap.setCoefficient1Constant(0.563)
    hpwh_cap.setCoefficient2x(0.0437)
    hpwh_cap.setCoefficient3xPOW2(0.000039)
    hpwh_cap.setCoefficient4y(0.0055)
    hpwh_cap.setCoefficient5yPOW2(-0.000148)
    hpwh_cap.setCoefficient6xTIMESY(-0.000145)
    hpwh_cap.setMinimumValueofx(0)
    hpwh_cap.setMaximumValueofx(100)
    hpwh_cap.setMinimumValueofy(0)
    hpwh_cap.setMaximumValueofy(100)

    hpwh_cop = OpenStudio::Model::CurveBiquadratic.new(model)
    hpwh_cop.setName('HPWH-COP-fT')
    hpwh_cop.setCoefficient1Constant(1.1332)
    hpwh_cop.setCoefficient2x(0.063)
    hpwh_cop.setCoefficient3xPOW2(-0.0000979)
    hpwh_cop.setCoefficient4y(-0.00972)
    hpwh_cop.setCoefficient5yPOW2(-0.0000214)
    hpwh_cop.setCoefficient6xTIMESY(-0.000686)
    hpwh_cop.setMinimumValueofx(0)
    hpwh_cop.setMaximumValueofx(100)
    hpwh_cop.setMinimumValueofy(0)
    hpwh_cop.setMaximumValueofy(100)

    # Assumptions and values
    cap = 0.5 # kW
    shr = 0.88 # unitless

    # Calculate an altitude adjusted rated evaporator wetbulb temperature
    rated_ewb_F = 56.4
    rated_edb_F = 67.5
    rated_ewb = UnitConversions.convert(rated_ewb_F, 'F', 'C')
    rated_edb = UnitConversions.convert(rated_edb_F, 'F', 'C')
    w_rated = Psychrometrics.w_fT_Twb_P(rated_edb_F, rated_ewb_F, 14.7)
    dp_rated = Psychrometrics.Tdp_fP_w(14.7, w_rated)
    p_atm = Psychrometrics.Pstd_fZ(weather.header.Altitude)
    w_adj = Psychrometrics.w_fT_Twb_P(dp_rated, dp_rated, p_atm)
    twb_adj = Psychrometrics.Twb_fT_w_P(rated_edb_F, w_adj, p_atm)

    # Calculate the COP based on EF
    if not water_heating_system.energy_factor.nil?
      uef = (0.60522 + water_heating_system.energy_factor) / 1.2101
      cop = 1.174536058 * uef # Based on simulation of the UEF test procedure at varying COPs
    elsif not water_heating_system.uniform_energy_factor.nil?
      uef = water_heating_system.uniform_energy_factor
      if water_heating_system.usage_bin == HPXML::WaterHeaterUsageBinVerySmall
        fail 'It is unlikely that a heat pump water heater falls into the very small bin of the First Hour Rating (FHR) test. Double check input.'
      elsif water_heating_system.usage_bin == HPXML::WaterHeaterUsageBinLow
        cop = 1.0005 * uef - 0.0789
      elsif water_heating_system.usage_bin == HPXML::WaterHeaterUsageBinMedium
        cop = 1.0909 * uef - 0.0868
      elsif water_heating_system.usage_bin == HPXML::WaterHeaterUsageBinHigh
        cop = 1.1022 * uef - 0.0877
      end
    end

    coil = hpwh.dXCoil.to_CoilWaterHeatingAirToWaterHeatPumpWrapped.get
    coil.setName("#{obj_name_hpwh} coil")
    coil.setRatedHeatingCapacity(UnitConversions.convert(cap, 'kW', 'W') * cop)
    coil.setRatedCOP(cop)
    coil.setRatedSensibleHeatRatio(shr)
    coil.setRatedEvaporatorInletAirDryBulbTemperature(rated_edb)
    coil.setRatedEvaporatorInletAirWetBulbTemperature(UnitConversions.convert(twb_adj, 'F', 'C'))
    coil.setRatedCondenserWaterTemperature(48.89)
    coil.setRatedEvaporatorAirFlowRate(UnitConversions.convert(airflow_rate, 'ft^3/min', 'm^3/s'))
    coil.setEvaporatorFanPowerIncludedinRatedCOP(true)
    coil.setEvaporatorAirTemperatureTypeforCurveObjects('WetBulbTemperature')
    coil.setHeatingCapacityFunctionofTemperatureCurve(hpwh_cap)
    coil.setHeatingCOPFunctionofTemperatureCurve(hpwh_cop)
    coil.setMaximumAmbientTemperatureforCrankcaseHeaterOperation(0)

    return coil
  end

  def self.setup_hpwh_stratified_tank(hpwh, water_heating_system, obj_name_hpwh, h_tank, solar_fraction, hpwh_tamb, hpwh_bottom_element_sp, hpwh_top_element_sp)
    # Calculate some geometry parameters for UA, the location of sensors and heat sources in the tank
    v_actual = calc_storage_tank_actual_vol(water_heating_system.tank_volume, water_heating_system.fuel_type) # gal
    a_tank, a_side = calc_tank_areas(v_actual, UnitConversions.convert(h_tank, 'm', 'ft')) # sqft

    e_cap = 4.5 # kW
    parasitics = 3.0 # W
    # Based on Ecotope lab testing of most recent AO Smith HPWHs (series HPTU)
    if water_heating_system.tank_volume <= 58.0
      tank_ua = 3.6 # Btu/h-R
    elsif water_heating_system.tank_volume <= 73.0
      tank_ua = 4.0 # Btu/h-R
    else
      tank_ua = 4.7 # Btu/h-R
    end
    tank_ua = apply_tank_jacket(water_heating_system, tank_ua, a_side)
    u_tank = ((5.678 * tank_ua) / a_tank) * (1.0 - solar_fraction)

    h_UE = (1.0 - (3.5 / 12.0)) * h_tank # in the 3rd node of the tank (counting from top)
    h_LE = (1.0 - (9.5 / 12.0)) * h_tank # in the 10th node of the tank (counting from top)

    tank = hpwh.tank.to_WaterHeaterStratified.get
    tank.setName("#{obj_name_hpwh} tank")
    tank.setEndUseSubcategory('Domestic Hot Water')
    tank.setTankVolume(UnitConversions.convert(v_actual, 'gal', 'm^3'))
    tank.setTankHeight(h_tank)
    tank.setMaximumTemperatureLimit(90)
    tank.setHeaterPriorityControl('MasterSlave')
    tank.setHeater1SetpointTemperatureSchedule(hpwh_top_element_sp) # Overwritten later by EMS
    tank.setHeater1Capacity(UnitConversions.convert(e_cap, 'kW', 'W'))
    tank.setHeater1Height(h_UE)
    tank.setHeater1DeadbandTemperatureDifference(18.5)
    tank.setHeater2SetpointTemperatureSchedule(hpwh_bottom_element_sp)
    tank.setHeater2Capacity(UnitConversions.convert(e_cap, 'kW', 'W'))
    tank.setHeater2Height(h_LE)
    tank.setHeater2DeadbandTemperatureDifference(3.89)
    tank.setHeaterFuelType(EPlus::FuelTypeElectricity)
    tank.setHeaterThermalEfficiency(1)
    tank.setOffCycleParasiticFuelConsumptionRate(parasitics)
    tank.setOffCycleParasiticFuelType(EPlus::FuelTypeElectricity)
    tank.setOnCycleParasiticFuelConsumptionRate(parasitics)
    tank.setOnCycleParasiticFuelType(EPlus::FuelTypeElectricity)
    tank.setUniformSkinLossCoefficientperUnitAreatoAmbientTemperature(u_tank)
    tank.setAmbientTemperatureSchedule(hpwh_tamb)
    tank.setNumberofNodes(6)
    tank.setAdditionalDestratificationConductivity(0)
    tank.setNode1AdditionalLossCoefficient(0)
    tank.setNode2AdditionalLossCoefficient(0)
    tank.setNode3AdditionalLossCoefficient(0)
    tank.setNode4AdditionalLossCoefficient(0)
    tank.setNode5AdditionalLossCoefficient(0)
    tank.setNode6AdditionalLossCoefficient(0)
    tank.setUseSideDesignFlowRate(UnitConversions.convert(v_actual, 'gal', 'm^3') / 60.1) # Sized to ensure that E+ never autosizes the design flow rate to be larger than the tank volume getting drawn out in a hour (60 minutes)
    tank.setSourceSideDesignFlowRate(0)
    tank.setSourceSideFlowControlMode('')
    tank.setSourceSideInletHeight(0)
    tank.setSourceSideOutletHeight(0)

    return tank
  end

  def self.setup_hpwh_fan(hpwh, obj_name_hpwh, airflow_rate)
    fan_power = 0.0462 # W/cfm, Based on 1st gen AO Smith HPWH, could be updated but pretty minor impact
    fan = hpwh.fan.to_FanOnOff.get # TOOD: Update reporting measure if this changes to FanSystemModel per https://github.com/NREL/OpenStudio/issues/4334
    fan.setName("#{obj_name_hpwh} fan")
    fan.setFanEfficiency(65.0 / fan_power * UnitConversions.convert(1.0, 'ft^3/min', 'm^3/s'))
    fan.setPressureRise(65.0)
    fan.setMaximumFlowRate(UnitConversions.convert(airflow_rate, 'ft^3/min', 'm^3/s'))
    fan.setMotorEfficiency(1.0)
    fan.setMotorInAirstreamFraction(1.0)
    fan.setEndUseSubcategory('Domestic Hot Water')
    return fan
  end

  def self.get_loc_temp_rh_sensors(model, obj_name_hpwh, loc_schedule, loc_space, living_zone)
    rh_sensors = []
    if not loc_schedule.nil?
      amb_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
      amb_temp_sensor.setName("#{obj_name_hpwh} amb temp")
      amb_temp_sensor.setKeyName(loc_schedule.name.to_s)

      if loc_schedule.name.get == HPXML::LocationOtherNonFreezingSpace
        amb_rh_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Relative Humidity')
        amb_rh_sensor.setName("#{obj_name_hpwh} amb rh")
        amb_rh_sensor.setKeyName('Environment')
        rh_sensors << amb_rh_sensor
      elsif loc_schedule.name.get == HPXML::LocationOtherHousingUnit
        amb_rh_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Air Relative Humidity')
        amb_rh_sensor.setName("#{obj_name_hpwh} amb rh")
        amb_rh_sensor.setKeyName(living_zone.name.to_s)
        rh_sensors << amb_rh_sensor
      else
        amb_rh_sensor1 = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Relative Humidity')
        amb_rh_sensor1.setName("#{obj_name_hpwh} amb1 rh")
        amb_rh_sensor1.setKeyName('Environment')
        amb_rh_sensor2 = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Air Relative Humidity')
        amb_rh_sensor2.setName("#{obj_name_hpwh} amb2 rh")
        amb_rh_sensor2.setKeyName(living_zone.name.to_s)
        rh_sensors << amb_rh_sensor1
        rh_sensors << amb_rh_sensor2
      end
    elsif not loc_space.nil?
      amb_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Mean Air Temperature')
      amb_temp_sensor.setName("#{obj_name_hpwh} amb temp")
      amb_temp_sensor.setKeyName(loc_space.thermalZone.get.name.to_s)

      amb_rh_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Air Relative Humidity')
      amb_rh_sensor.setName("#{obj_name_hpwh} amb rh")
      amb_rh_sensor.setKeyName(loc_space.thermalZone.get.name.to_s)
      rh_sensors << amb_rh_sensor
    else # Located outside
      amb_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Drybulb Temperature')
      amb_temp_sensor.setName("#{obj_name_hpwh} amb temp")
      amb_temp_sensor.setKeyName('Environment')

      amb_rh_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Relative Humidity')
      amb_rh_sensor.setName("#{obj_name_hpwh} amb rh")
      amb_rh_sensor.setKeyName('Environment')
      rh_sensors << amb_rh_sensor
    end
    return amb_temp_sensor, rh_sensors
  end

  def self.add_hpwh_inlet_air_and_zone_heat_gain_program(model, obj_name_hpwh, loc_space, loc_schedule, hpwh_tamb, hpwh_rhamb, tank, coil, fan, amb_temp_sensor, amb_rh_sensors)
    # EMS Actuators: Inlet T & RH, sensible and latent gains to the space
    tamb_act_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(hpwh_tamb, *EPlus::EMSActuatorScheduleConstantValue)
    tamb_act_actuator.setName("#{obj_name_hpwh} Tamb act")

    rhamb_act_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(hpwh_rhamb, *EPlus::EMSActuatorScheduleConstantValue)
    rhamb_act_actuator.setName("#{obj_name_hpwh} RHamb act")

    if not loc_space.nil? # If located in space
      # Add in other equipment objects for sensible/latent gains
      hpwh_sens_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
      hpwh_sens_def.setName("#{obj_name_hpwh} sens")
      hpwh_sens = OpenStudio::Model::OtherEquipment.new(hpwh_sens_def)
      hpwh_sens.setName(hpwh_sens_def.name.to_s)
      hpwh_sens.setSpace(loc_space)
      hpwh_sens_def.setDesignLevel(0)
      hpwh_sens_def.setFractionRadiant(0)
      hpwh_sens_def.setFractionLatent(0)
      hpwh_sens_def.setFractionLost(0)
      hpwh_sens.setSchedule(model.alwaysOnDiscreteSchedule)

      hpwh_lat_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
      hpwh_lat_def.setName("#{obj_name_hpwh} lat")
      hpwh_lat = OpenStudio::Model::OtherEquipment.new(hpwh_lat_def)
      hpwh_lat.setName(hpwh_lat_def.name.to_s)
      hpwh_lat.setSpace(loc_space)
      hpwh_lat_def.setDesignLevel(0)
      hpwh_lat_def.setFractionRadiant(0)
      hpwh_lat_def.setFractionLatent(1)
      hpwh_lat_def.setFractionLost(0)
      hpwh_lat.setSchedule(model.alwaysOnDiscreteSchedule)

      sens_act_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(hpwh_sens, *EPlus::EMSActuatorOtherEquipmentPower)
      sens_act_actuator.setName("#{hpwh_sens.name} act")

      lat_act_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(hpwh_lat, *EPlus::EMSActuatorOtherEquipmentPower)
      lat_act_actuator.setName("#{hpwh_lat.name} act")
    end

    # EMS Sensors: HP sens and latent loads, tank losses, fan power
    tl_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Water Heater Heat Loss Rate')
    tl_sensor.setName("#{obj_name_hpwh} tl")
    tl_sensor.setKeyName(tank.name.to_s)

    sens_cool_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Cooling Coil Sensible Cooling Rate')
    sens_cool_sensor.setName("#{obj_name_hpwh} sens cool")
    sens_cool_sensor.setKeyName(coil.name.to_s)

    lat_cool_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Cooling Coil Latent Cooling Rate')
    lat_cool_sensor.setName("#{obj_name_hpwh} lat cool")
    lat_cool_sensor.setKeyName(coil.name.to_s)

    fan_power_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Fan #{EPlus::FuelTypeElectricity} Rate")
    fan_power_sensor.setName("#{obj_name_hpwh} fan pwr")
    fan_power_sensor.setKeyName(fan.name.to_s)

    hpwh_inlet_air_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    hpwh_inlet_air_program.setName("#{obj_name_hpwh} InletAir")
    hpwh_inlet_air_program.addLine("Set #{tamb_act_actuator.name} = #{amb_temp_sensor.name}")
    # Average relative humidity for mf spaces: other multifamily buffer space & other heated space
    hpwh_inlet_air_program.addLine("Set #{rhamb_act_actuator.name} = 0")
    amb_rh_sensors.each do |amb_rh_sensor|
      hpwh_inlet_air_program.addLine("Set #{rhamb_act_actuator.name} = #{rhamb_act_actuator.name} + (#{amb_rh_sensor.name} / 100) / #{amb_rh_sensors.size}")
    end
    if not loc_space.nil?
      # Sensible/latent heat gain to the space
      hpwh_inlet_air_program.addLine("Set #{sens_act_actuator.name} = 0 - #{sens_cool_sensor.name} - (#{tl_sensor.name} + #{fan_power_sensor.name})")
      hpwh_inlet_air_program.addLine("Set #{lat_act_actuator.name} = 0 - #{lat_cool_sensor.name}")
    end
    return hpwh_inlet_air_program
  end

  def self.add_hpwh_control_program(model, obj_name_hpwh, amb_temp_sensor, hpwh_bottom_element_sp, min_temp, max_temp, tset_C)
    # Lower element is enabled if the ambient air temperature prevents the HP from running
    leschedoverride_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(hpwh_bottom_element_sp, *EPlus::EMSActuatorScheduleConstantValue)
    leschedoverride_actuator.setName("#{obj_name_hpwh} LESchedOverride")
    hpwh_ctrl_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    hpwh_ctrl_program.setName("#{obj_name_hpwh} Control")
    hpwh_ctrl_program.addLine("If (#{amb_temp_sensor.name}<#{UnitConversions.convert(min_temp, 'F', 'C').round(2)}) || (#{amb_temp_sensor.name}>#{UnitConversions.convert(max_temp, 'F', 'C').round(2)})")
    hpwh_ctrl_program.addLine("Set #{leschedoverride_actuator.name} = #{tset_C}")
    hpwh_ctrl_program.addLine('Else')
    hpwh_ctrl_program.addLine("Set #{leschedoverride_actuator.name} = 0")
    hpwh_ctrl_program.addLine('EndIf')
    return hpwh_ctrl_program
  end

  def self.get_combi_boiler_and_plant_loop(loop_hvacs, heating_source_id)
    # Search for the right boiler OS object
    boiler = nil
    plant_loop = nil
    if loop_hvacs.keys.include? heating_source_id
      loop_hvacs[heating_source_id].each do |comp|
        if comp.is_a? OpenStudio::Model::PlantLoop
          plant_loop = comp
        elsif comp.is_a? OpenStudio::Model::BoilerHotWater
          boiler = comp
        end
      end
    end
    return boiler, plant_loop
  end

  def self.get_desuperheatercoil(water_heating_system, hvac_map)
    # search for the related cooling coil object for desuperheater
    if hvac_map.keys.include? water_heating_system.related_hvac_idref
      hvac_map[water_heating_system.related_hvac_idref].each do |comp|
        # supported coil types
        [OpenStudio::Model::CoilCoolingDXSingleSpeed,
         OpenStudio::Model::CoilCoolingDXMultiSpeed,
         OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit].each do |coiltype|
          if comp.is_a? coiltype
            return comp
          end
        end
      end
      fail "RelatedHVACSystem '#{water_heating_system.related_hvac_idref}' for water heating system '#{water_heating_system.id}' is not currently supported for desuperheaters."
    end
  end

  def self.add_desuperheater(model, water_heating_system, hvac_map, tank, loc_space, loc_schedule, loop)
    desuperheater_clg_coil = get_desuperheatercoil(water_heating_system, hvac_map)
    reclaimed_efficiency = 0.25 # default
    desuperheater_name = Constants.ObjectNameDesuperheater(tank.name)

    # create a storage tank
    vol = 50.0
    storage_vol_actual = calc_storage_tank_actual_vol(vol, nil)
    assumed_ua = 6.0 # Btu/hr-F, tank ua calculated based on 1.0 standby_loss and 50gal nominal vol
    storage_tank_name = "#{tank.name} storage tank"
    # reduce tank setpoint to enable desuperheater setpoint at t_set
    tank_setpoint = get_set_temp_c(water_heating_system.temperature - 5.0, HPXML::WaterHeaterTypeStorage)
    storage_tank = create_new_heater(name: storage_tank_name,
                                     act_vol: storage_vol_actual,
                                     t_set_c: tank_setpoint,
                                     loc_space: loc_space,
                                     loc_schedule: loc_schedule,
                                     model: model,
                                     ua: assumed_ua,
                                     is_dsh_storage: true)
    set_parasitic_power_for_storage_wh(water_heater: storage_tank)

    loop.addSupplyBranchForComponent(storage_tank)
    tank.addToNode(storage_tank.supplyOutletModelObject.get.to_Node.get)

    # Create a schedule for desuperheater
    new_schedule = OpenStudio::Model::ScheduleConstant.new(model)
    new_schedule.setName("#{desuperheater_name} setpoint schedule")
    # Preheat tank desuperheater setpoint set to be the same as main water heater
    dsh_setpoint = get_set_temp_c(water_heating_system.temperature, HPXML::WaterHeaterTypeStorage)
    new_schedule.setValue(dsh_setpoint)

    # create a desuperheater object
    desuperheater = OpenStudio::Model::CoilWaterHeatingDesuperheater.new(model, new_schedule)
    desuperheater.setName(desuperheater_name)
    desuperheater.setMaximumInletWaterTemperatureforHeatReclaim(100)
    desuperheater.setDeadBandTemperatureDifference(0.2)
    desuperheater.setRatedHeatReclaimRecoveryEfficiency(reclaimed_efficiency)
    desuperheater.addToHeatRejectionTarget(storage_tank)
    # FUTURE: Desuperheater pump power?
    desuperheater.setWaterPumpPower(0)
    # attach to the clg coil source
    desuperheater.setHeatingSource(desuperheater_clg_coil)

    return desuperheater
  end

  def self.create_new_hx(model, name)
    hx = OpenStudio::Model::HeatExchangerFluidToFluid.new(model)
    hx.setName(name)
    hx.setControlType('OperationSchemeModulated')

    return hx
  end

  def self.get_default_heating_capacity(fuel, num_beds, num_water_heaters, num_baths = nil)
    # Returns the capacity of the water heater based on the fuel type and number
    # of bedrooms and bathrooms in a home. Returns the capacity in kBtu/hr.
    # Source: Table 8. Benchmark DHW Storage and Burner Capacity in 2014 BA HSP

    if num_baths.nil?
      num_baths = get_default_num_bathrooms(num_beds)
    end

    # Adjust the heating capacity if there are multiple water heaters in the home
    num_baths /= num_water_heaters.to_f

    if fuel != HPXML::FuelTypeElectricity
      if num_beds <= 3
        cap_kbtuh = 36.0
      elsif num_beds == 4
        cap_kbtuh = 38.0
      elsif num_beds == 5
        cap_kbtuh = 48.0
      else
        cap_kbtuh = 50.0
      end
      return cap_kbtuh
    else
      if num_beds == 1
        cap_kw = 2.5
      elsif num_beds == 2
        if num_baths <= 1.5
          cap_kw = 3.5
        else
          cap_kw = 4.5
        end
      elsif num_beds == 3
        if num_baths <= 1.5
          cap_kw = 4.5
        else
          cap_kw = 5.5
        end
      else
        cap_kw = 5.5
      end
      return UnitConversions.convert(cap_kw, 'kW', 'kBtu/hr')
    end
  end

  def self.get_default_tank_volume(fuel, num_beds, num_baths)
    # Returns the volume of a water heater based on the BA HSP
    # Source: Table 8. Benchmark DHW Storage and Burner Capacity in 2014 BA HSP
    if fuel != HPXML::FuelTypeElectricity # Non-electric tank WHs
      if num_beds <= 2
        return 30.0
      elsif num_beds == 3
        if num_baths <= 1.5
          return 30.0
        else
          return 40.0
        end
      elsif num_beds == 4
        if num_baths <= 2.5
          return 40.0
        else
          return 50.0
        end
      else
        return 50.0
      end
    else
      if num_beds == 1
        return 30.0
      elsif num_beds == 2
        if num_baths <= 1.5
          return 30.0
        else
          return 40.0
        end
      elsif num_beds == 3
        if num_baths <= 1.5
          return 40.0
        else
          return 50.0
        end
      elsif num_beds == 4
        if num_baths <= 2.5
          return 50.0
        else
          return 66.0
        end
      elsif num_beds == 5
        return 66.0
      else
        return 80.0
      end
    end
  end

  def self.get_default_recovery_efficiency(water_heating_system)
    # Water Heater Recovery Efficiency by fuel and energy factor
    if water_heating_system.fuel_type == HPXML::FuelTypeElectricity
      return 0.98
    else
      # FUTURE: Develop a separate algorithm specific to UEF.
      ef = water_heating_system.energy_factor
      if ef.nil?
        ef = calc_ef_from_uef(water_heating_system)
      end
      if ef >= 0.75
        re = 0.561 * ef + 0.439
      else
        re = 0.252 * ef + 0.608
      end
      return re
    end
  end

  def self.calc_ef_from_uef(water_heating_system)
    # Interpretation on Water Heater UEF
    if water_heating_system.fuel_type == HPXML::FuelTypeElectricity
      if water_heating_system.water_heater_type == HPXML::WaterHeaterTypeStorage
        return [2.4029 * water_heating_system.uniform_energy_factor - 1.2844, 0.96].min
      elsif water_heating_system.water_heater_type == HPXML::WaterHeaterTypeTankless
        return water_heating_system.uniform_energy_factor
      elsif water_heating_system.water_heater_type == HPXML::WaterHeaterTypeHeatPump
        return 1.2101 * water_heating_system.uniform_energy_factor - 0.6052
      end
    else # Fuel
      if water_heating_system.water_heater_type == HPXML::WaterHeaterTypeStorage
        return 0.9066 * water_heating_system.uniform_energy_factor + 0.0711
      elsif water_heating_system.water_heater_type == HPXML::WaterHeaterTypeTankless
        return water_heating_system.uniform_energy_factor
      end
    end
    fail 'Unexpected water heater.'
  end

  def self.calc_tank_areas(act_vol, height = nil)
    if height.nil?
      height = get_tank_height()
    end
    diameter = 2.0 * (UnitConversions.convert(act_vol, 'gal', 'ft^3') / (height * Math::PI))**0.5 # feet
    a_top = Math::PI * diameter**2.0 / 4.0 # sqft
    a_side = Math::PI * diameter * height # sqft
    surface_area = 2.0 * a_top + a_side # sqft

    return surface_area, a_side
  end

  def self.get_tank_height()
    return 4.0 # feet
  end

  def self.calc_indirect_ua_with_standbyloss(act_vol, water_heating_system, a_side, solar_fraction)
    # Test conditions
    cp = 0.999 # Btu/lb-F
    rho = 8.216 # lb/gal
    t_amb = 70.0 # F
    t_tank_avg = 135.0 # F, Test begins at 137-138F stop at 133F

    # UA calculation
    q = water_heating_system.standby_loss * cp * act_vol * rho # Btu/hr
    ua = q / (t_tank_avg - t_amb) # Btu/hr-F

    # jacket
    ua = apply_tank_jacket(water_heating_system, ua, a_side)

    ua *= (1.0 - solar_fraction)
    return ua
  end

  def self.get_default_num_bathrooms(num_beds)
    # From BA HSP
    num_baths = num_beds / 2.0 + 0.5
  end

  def self.add_ec_adj(model, heater, ec_adj, loc_space, water_heating_system, combi_boiler = nil, combi_hx = nil)
    adjustment = ec_adj - 1.0

    if loc_space.nil? # WH is not in a zone, set the other equipment to be in a random space
      loc_space = model.getSpaces[0]
    end

    if water_heating_system.water_heater_type == HPXML::WaterHeaterTypeHeatPump
      tank = heater.tank
    else
      tank = heater
    end
    if [HPXML::WaterHeaterTypeCombiStorage, HPXML::WaterHeaterTypeCombiTankless].include? water_heating_system.water_heater_type
      fuel_type = water_heating_system.related_hvac_system.heating_system_fuel
    else
      fuel_type = water_heating_system.fuel_type
    end

    # Add an other equipment object for water heating that will get actuated, has a small initial load but gets overwritten by EMS
    ec_adj_object = HotWaterAndAppliances.add_other_equipment(model, Constants.ObjectNameWaterHeaterAdjustment(heater.name), loc_space, 0.01, 0, 0, model.alwaysOnDiscreteSchedule, fuel_type)

    # EMS for calculating the EC_adj

    # Sensors
    if [HPXML::WaterHeaterTypeCombiStorage, HPXML::WaterHeaterTypeCombiTankless].include? water_heating_system.water_heater_type
      ec_adj_sensor_hx = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Fluid Heat Exchanger Heat Transfer Energy')
      ec_adj_sensor_hx.setName("#{combi_hx.name} energy")
      ec_adj_sensor_hx.setKeyName(combi_hx.name.to_s)
      ec_adj_sensor_boiler_heating = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Boiler Heating Energy')
      ec_adj_sensor_boiler_heating.setName("#{combi_boiler.name} heating energy")
      ec_adj_sensor_boiler_heating.setKeyName(combi_boiler.name.to_s)
      ec_adj_sensor_boiler = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Boiler #{EPlus.fuel_type(fuel_type)} Rate")
      ec_adj_sensor_boiler.setName("#{combi_boiler.name} energy")
      ec_adj_sensor_boiler.setKeyName(combi_boiler.name.to_s)
    else
      ec_adj_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Water Heater #{EPlus.fuel_type(fuel_type)} Rate")
      ec_adj_sensor.setName("#{tank.name} energy")
      ec_adj_sensor.setKeyName(tank.name.to_s)
      if water_heating_system.water_heater_type == HPXML::WaterHeaterTypeHeatPump
        ec_adj_hp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Cooling Coil Water Heating #{EPlus::FuelTypeElectricity} Rate")
        ec_adj_hp_sensor.setName("#{heater.dXCoil.name} energy")
        ec_adj_hp_sensor.setKeyName(heater.dXCoil.name.to_s)
        ec_adj_fan_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Fan #{EPlus::FuelTypeElectricity} Rate")
        ec_adj_fan_sensor.setName("#{heater.fan.name} energy")
        ec_adj_fan_sensor.setKeyName(heater.fan.name.to_s)
      end
    end

    ec_adj_oncyc_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Water Heater On Cycle Parasitic #{EPlus::FuelTypeElectricity} Rate")
    ec_adj_oncyc_sensor.setName("#{tank.name} on cycle parasitic")
    ec_adj_oncyc_sensor.setKeyName(tank.name.to_s)
    ec_adj_offcyc_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Water Heater Off Cycle Parasitic #{EPlus::FuelTypeElectricity} Rate")
    ec_adj_offcyc_sensor.setName("#{tank.name} off cycle parasitic")
    ec_adj_offcyc_sensor.setKeyName(tank.name.to_s)

    # Actuators
    ec_adj_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(ec_adj_object, *EPlus::EMSActuatorOtherEquipmentPower)
    ec_adj_actuator.setName("#{heater.name} ec_adj_act")

    # Program
    ec_adj_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ec_adj_program.setName("#{heater.name} EC_adj")
    if [HPXML::WaterHeaterTypeCombiStorage, HPXML::WaterHeaterTypeCombiTankless].include? water_heating_system.water_heater_type
      ec_adj_program.addLine("Set wh_e_cons = #{ec_adj_oncyc_sensor.name} + #{ec_adj_offcyc_sensor.name}")
      ec_adj_program.addLine("If #{ec_adj_sensor_boiler_heating.name} > 0")
      ec_adj_program.addLine("  Set wh_e_cons = wh_e_cons + (@Abs #{ec_adj_sensor_hx.name}) / #{ec_adj_sensor_boiler_heating.name} * #{ec_adj_sensor_boiler.name}")
      ec_adj_program.addLine('EndIf')
      ec_adj_program.addLine('Set boiler_hw_energy = wh_e_cons * 3600 * SystemTimeStep')
    elsif water_heating_system.water_heater_type == HPXML::WaterHeaterTypeHeatPump
      ec_adj_program.addLine("Set wh_e_cons = #{ec_adj_sensor.name} + #{ec_adj_oncyc_sensor.name} + #{ec_adj_offcyc_sensor.name} + #{ec_adj_hp_sensor.name} + #{ec_adj_fan_sensor.name}")
    else
      ec_adj_program.addLine("Set wh_e_cons = #{ec_adj_sensor.name} + #{ec_adj_oncyc_sensor.name} + #{ec_adj_offcyc_sensor.name}")
    end
    ec_adj_program.addLine("Set #{ec_adj_actuator.name} = #{adjustment} * wh_e_cons")

    # Program Calling Manager
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName("#{heater.name} EC_adj ProgramManager")
    program_calling_manager.setCallingPoint('EndOfSystemTimestepBeforeHVACReporting')
    program_calling_manager.addProgram(ec_adj_program)

    # Sensor for EMS reporting
    ec_adj_object_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Other Equipment #{EPlus.fuel_type(fuel_type)} Energy")
    ec_adj_object_sensor.setName("#{ec_adj_object.name} energy consumption")
    ec_adj_object_sensor.setKeyName(ec_adj_object.name.to_s)

    # EMS Output Variable for EC_adj reporting
    ec_adj_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, ec_adj_object_sensor)
    ec_adj_output_var.setName("#{Constants.ObjectNameWaterHeaterAdjustment(heater.name)} outvar")
    ec_adj_output_var.setTypeOfDataInVariable('Summed')
    ec_adj_output_var.setUpdateFrequency('SystemTimestep')
    ec_adj_output_var.setEMSProgramOrSubroutineName(ec_adj_program)
    ec_adj_output_var.setUnits('J')

    if [HPXML::WaterHeaterTypeCombiStorage, HPXML::WaterHeaterTypeCombiTankless].include? water_heating_system.water_heater_type
      # EMS Output Variable for combi dhw energy reporting (before EC_adj is applied)
      boiler_hw_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, 'boiler_hw_energy')
      boiler_hw_output_var.setName("#{Constants.ObjectNameCombiWaterHeatingEnergy(heater.name)} outvar")
      boiler_hw_output_var.setTypeOfDataInVariable('Summed')
      boiler_hw_output_var.setUpdateFrequency('SystemTimestep')
      boiler_hw_output_var.setEMSProgramOrSubroutineName(ec_adj_program)
      boiler_hw_output_var.setUnits('J')
    else
      boiler_hw_output_var = nil
    end

    return ec_adj_output_var, boiler_hw_output_var
  end

  def self.get_default_hot_water_temperature(eri_version)
    # Returns hot water temperature in deg-F
    if Constants.ERIVersions.index(eri_version) >= Constants.ERIVersions.index('2014A')
      # 2014 w/ Addendum A or newer
      return 125.0
    else
      return 120.0
    end
  end

  def self.get_default_performance_adjustment(water_heating_system)
    return unless water_heating_system.water_heater_type == HPXML::WaterHeaterTypeTankless
    if not water_heating_system.energy_factor.nil?
      return 0.92 # Applies EF, updated per 301-2019
    elsif not water_heating_system.uniform_energy_factor.nil?
      return 0.94 # Applies UEF, updated per 301-2019
    end
  end

  def self.get_default_location(hpxml, iecc_zone)
    if ['1A', '1B', '1C', '2A', '2B', '2C', '3B', '3C'].include? iecc_zone
      location_hierarchy = [HPXML::LocationGarage,
                            HPXML::LocationLivingSpace]
    elsif ['3A', '4A', '4B', '4C', '5A', '5B', '5C', '6A', '6B', '6C', '7', '8'].include? iecc_zone
      location_hierarchy = [HPXML::LocationBasementConditioned,
                            HPXML::LocationBasementUnconditioned,
                            HPXML::LocationLivingSpace]
    elsif iecc_zone.nil?
      location_hierarchy = [HPXML::LocationBasementConditioned,
                            HPXML::LocationBasementUnconditioned,
                            HPXML::LocationLivingSpace]
    end
    location_hierarchy.each do |space_type|
      if hpxml.has_space_type(space_type)
        return space_type
      end
    end
  end

  def self.calc_default_solar_thermal_system_storage_volume(collector_area)
    return 1.5 * collector_area # 1.5 gal for every sqft of collector area
  end

  def self.deadband(wh_type)
    if [HPXML::WaterHeaterTypeStorage, HPXML::WaterHeaterTypeCombiStorage].include? wh_type
      return 2.0 # deg-C
    else
      return 0.0 # deg-C
    end
  end

  def self.calc_storage_tank_actual_vol(vol, fuel)
    # Convert the nominal tank volume to an actual volume
    if fuel.nil?
      act_vol = 0.95 * vol # indirect tank
    else
      if fuel == HPXML::FuelTypeElectricity
        act_vol = 0.9 * vol
      else
        act_vol = 0.95 * vol
      end
    end
    return act_vol
  end

  def self.calc_tank_UA(act_vol, water_heating_system, solar_fraction)
    # If using EF:
    #   Calculates the U value, UA of the tank and conversion efficiency (eta_c)
    #   based on the Energy Factor and recovery efficiency of the tank
    #   Source: Burch and Erickson 2004 - http://www.nrel.gov/docs/gen/fy04/36035.pdf
    # IF using UEF:
    #   Calculates the U value, UA of the tank and conversion efficiency (eta_c)
    #   based on the Uniform Energy Factor, First Hour Rating, and Recovery Efficiency of the tank
    #   Source: Maguire and Roberts 2020 - https://www.ashrae.org/file%20library/conferences/specialty%20conferences/2020%20building%20performance/papers/d-bsc20-c039.pdf
    if water_heating_system.water_heater_type == HPXML::WaterHeaterTypeTankless
      if not water_heating_system.energy_factor.nil?
        eta_c = water_heating_system.energy_factor * water_heating_system.performance_adjustment
      elsif not water_heating_system.uniform_energy_factor.nil?
        eta_c = water_heating_system.uniform_energy_factor * water_heating_system.performance_adjustment
      end
      ua = 0.0
      surface_area = 1.0
    else
      density = 8.2938 # lb/gal
      cp = 1.0007 # Btu/lb-F
      t_in = 58.0 # F
      t_env = 67.5 # F

      if not water_heating_system.energy_factor.nil?
        t = 135.0 # F
        volume_drawn = 64.3 # gal/day
      elsif not water_heating_system.uniform_energy_factor.nil?
        t = 125.0 # F
        if water_heating_system.usage_bin == HPXML::WaterHeaterUsageBinVerySmall
          volume_drawn = 10.0 # gal
        elsif water_heating_system.usage_bin == HPXML::WaterHeaterUsageBinLow
          volume_drawn = 38.0 # gal
        elsif water_heating_system.usage_bin == HPXML::WaterHeaterUsageBinMedium
          volume_drawn = 55.0 # gal
        elsif water_heating_system.usage_bin == HPXML::WaterHeaterUsageBinHigh
          volume_drawn = 84.0 # gal
        end
      end

      draw_mass = volume_drawn * density # lb
      q_load = draw_mass * cp * (t - t_in) # Btu/day
      pow = water_heating_system.heating_capacity # Btu/h
      surface_area, a_side = calc_tank_areas(act_vol)
      if water_heating_system.fuel_type != HPXML::FuelTypeElectricity
        if not water_heating_system.energy_factor.nil?
          ua = (water_heating_system.recovery_efficiency / water_heating_system.energy_factor - 1.0) / ((t - t_env) * (24.0 / q_load - 1.0 / (pow * water_heating_system.energy_factor))) # Btu/hr-F
          eta_c = (water_heating_system.recovery_efficiency + ua * (t - t_env) / pow) # conversion efficiency is supposed to be calculated with initial tank ua
        elsif not water_heating_system.uniform_energy_factor.nil?
          ua = ((water_heating_system.recovery_efficiency / water_heating_system.uniform_energy_factor) - 1.0) / ((t - t_env) * (24.0 / q_load) - ((t - t_env) / (pow * water_heating_system.uniform_energy_factor))) # Btu/hr-F
          eta_c = water_heating_system.recovery_efficiency + ((ua * (t - t_env)) / pow) # conversion efficiency is slightly larger than recovery efficiency
        end
      else # is Electric
        if not water_heating_system.energy_factor.nil?
          ua = q_load * (1.0 / water_heating_system.energy_factor - 1.0) / ((t - t_env) * 24.0)
        elsif not water_heating_system.uniform_energy_factor.nil?
          ua = q_load * (1.0 / water_heating_system.uniform_energy_factor - 1.0) / ((24.0 * (t - t_env)) * (0.8 + 0.2 * ((t_in - t_env) / (t - t_env))))
        end
        eta_c = 1.0
      end
      ua = apply_tank_jacket(water_heating_system, ua, a_side)
    end
    ua *= (1.0 - solar_fraction)
    if water_heating_system.is_shared_system
      # Apportion shared water heater energy use due to tank losses to the dwelling unit
      ua /= water_heating_system.number_of_units_served.to_f
    end
    u = ua / surface_area # Btu/hr-ft^2-F
    if eta_c > 1.0
      fail 'A water heater heat source (either burner or element) efficiency of > 1 has been calculated, double check water heater inputs.'
    end
    if ua < 0.0
      fail 'A negative water heater standby loss coefficient (UA) was calculated, double check water heater inputs.'
    end

    return u, ua, eta_c
  end

  def self.apply_tank_jacket(water_heating_system, ua_pre, a_side)
    if not water_heating_system.jacket_r_value.nil?
      skin_insulation_R = 5.0 # R5
      if water_heating_system.fuel_type.nil? # indirect water heater, etc. Assume 2 inch skin insulation
        skin_insulation_t = 2.0 # inch
      elsif water_heating_system.fuel_type != HPXML::FuelTypeElectricity
        if water_heating_system.energy_factor < 0.7
          skin_insulation_t = 1.0 # inch
        else
          skin_insulation_t = 2.0 # inch
        end
      else # electric
        skin_insulation_t = 2.0 # inch
      end
      # water heater wrap calculation based on:
      # Modeling Water Heat Wraps in BEopt DRAFT Technical Note
      # Authors:  Ben Polly and Jay Burch (NREL)
      u_pre_skin = 1.0 / (skin_insulation_t * skin_insulation_R + 1.0 / 1.3 + 1.0 / 52.8) # Btu/hr-ft^2-F = (1 / hout + kins / tins + t / hin)^-1
      ua = ua_pre - water_heating_system.jacket_r_value / (1.0 / u_pre_skin + water_heating_system.jacket_r_value) * u_pre_skin * a_side
    else
      ua = ua_pre
    end
    return ua
  end

  def self.calc_tank_EF(wh_type, ua, eta_c)
    # Calculates the energy factor based on UA of the tank and conversion efficiency (eta_c)
    # Source: Burch and Erickson 2004 - http://www.nrel.gov/docs/gen/fy04/36035.pdf
    if [HPXML::WaterHeaterTypeTankless, HPXML::WaterHeaterTypeCombiTankless].include? wh_type
      ef = eta_c
    else
      pi = Math::PI
      volume_drawn = 64.3 # gal/day
      density = 8.2938 # lb/gal
      draw_mass = volume_drawn * density # lb
      cp = 1.0007 # Btu/lb-F
      t = 135.0 # F
      t_in = 58.0 # F
      t_env = 67.5 # F
      q_load = draw_mass * cp * (t - t_in) # Btu/day

      ef = q_load / ((ua * (t - t_env) * 24.0 + q_load) / eta_c)
    end
    return ef
  end

  def self.create_new_pump(model)
    # Add a pump to the new DHW loop
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setRatedFlowRate(0.01)
    pump.setFractionofMotorInefficienciestoFluidStream(0)
    pump.setMotorEfficiency(1)
    pump.setRatedPowerConsumption(0)
    pump.setRatedPumpHead(1)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(1)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(0)
    pump.setPumpControlType('Intermittent')
    return pump
  end

  def self.create_new_schedule_manager(model, set_temp_c)
    new_schedule = OpenStudio::Model::ScheduleConstant.new(model)
    new_schedule.setName('dhw temp')
    new_schedule.setValue(set_temp_c)
    OpenStudio::Model::SetpointManagerScheduled.new(model, new_schedule)
  end

  def self.create_new_heater(name:, water_heating_system: nil, act_vol:, t_set_c: nil, loc_space:, loc_schedule: nil, model:, ua:, eta_c: nil, oncycle_p: 0.0, is_dsh_storage: false, is_combi: false)
    # storage tank doesn't require water_heating_system class argument being passed
    if is_dsh_storage || is_combi
      fuel = nil
      cap = 0.0
      if is_dsh_storage
        tank_type = HPXML::WaterHeaterTypeStorage
      else
        tank_type = water_heating_system.water_heater_type
      end
    else
      fuel = water_heating_system.fuel_type
      tank_type = water_heating_system.water_heater_type
      cap = water_heating_system.heating_capacity / 1000.0
    end
    new_heater = OpenStudio::Model::WaterHeaterMixed.new(model)
    new_heater.setName(name)
    new_heater.setHeaterThermalEfficiency(eta_c) unless eta_c.nil?
    new_heater.setHeaterFuelType(EPlus.fuel_type(fuel)) unless fuel.nil?
    configure_setpoint_schedule(new_heater, t_set_c, model)
    new_heater.setMaximumTemperatureLimit(99.0)
    if [HPXML::WaterHeaterTypeTankless, HPXML::WaterHeaterTypeCombiTankless].include? tank_type
      new_heater.setHeaterControlType('Modulate')
    else
      new_heater.setHeaterControlType('Cycle')
    end
    new_heater.setDeadbandTemperatureDifference(deadband(tank_type))

    # Capacity, storage tank to be 0
    new_heater.setHeaterMaximumCapacity(UnitConversions.convert(cap, 'kBtu/hr', 'W'))
    new_heater.setHeaterMinimumCapacity(0.0)
    new_heater.setTankVolume(UnitConversions.convert(act_vol, 'gal', 'm^3'))
    set_wh_parasitic_parameters(oncycle_p, water_heating_system, new_heater, is_dsh_storage)
    set_wh_ambient(loc_space, loc_schedule, model, new_heater)

    ua_w_k = UnitConversions.convert(ua, 'Btu/(hr*F)', 'W/K')
    new_heater.setOnCycleLossCoefficienttoAmbientTemperature(ua_w_k)
    new_heater.setOffCycleLossCoefficienttoAmbientTemperature(ua_w_k)

    return new_heater
  end

  def self.set_wh_parasitic_parameters(oncycle_p, water_heating_system, water_heater, is_dsh_storage)
    water_heater.setOnCycleParasiticFuelType(EPlus::FuelTypeElectricity)
    water_heater.setOnCycleParasiticHeatFractiontoTank(0)
    water_heater.setOnCycleLossFractiontoThermalZone(1.0)

    water_heater.setOffCycleParasiticFuelType(EPlus::FuelTypeElectricity)
    water_heater.setOffCycleParasiticHeatFractiontoTank(0)

    # Set fraction of heat loss from tank to ambient (vs out flue)
    # Based on lab testing done by LBNL
    skinlossfrac = 1.0
    if (not is_dsh_storage) && (water_heating_system.fuel_type != HPXML::FuelTypeElectricity) && (water_heating_system.water_heater_type == HPXML::WaterHeaterTypeStorage)
      # Fuel storage water heater
      # FUTURE: We currently always end up with oncycle_p (i.e., natural draft); revise this algorithm.
      if oncycle_p == 0.0
        skinlossfrac = 0.64 # Natural draft
      elsif water_heating_system.energy_factor < 0.8
        skinlossfrac = 0.91 # Power vent
      else
        skinlossfrac = 0.96 # Condensing
      end
    end
    water_heater.setOffCycleLossFractiontoThermalZone(skinlossfrac)
  end

  def self.set_parasitic_power_for_tankless_wh(nbeds:, oncycle_p: 0.0, offcycle_p: 0.0, water_heater:)
    # Set parasitic power consumption for tankless water heater
    # Tankless WHs are set to "modulate", not "cycle", so they end up
    # effectively always on. Thus, we need to use a weighted-average of
    # on-cycle and off-cycle parasitics.
    # Values used here are based on the average across 10 units originally used when modeling MF buildings
    avg_runtime_frac = [0.0268, 0.0333, 0.0397, 0.0462, 0.0529]
    if nbeds <= 5
      if nbeds == 0
        runtime_frac = avg_runtime_frac[0]
      else
        runtime_frac = avg_runtime_frac[nbeds - 1]
      end
    else
      runtime_frac = avg_runtime_frac[4]
    end
    avg_elec = oncycle_p * runtime_frac + offcycle_p * (1 - runtime_frac)

    # FUTURE: These are always zero right now; develop smart defaults.
    water_heater.setOnCycleParasiticFuelConsumptionRate(avg_elec)
    water_heater.setOffCycleParasiticFuelConsumptionRate(avg_elec)
  end

  def self.set_parasitic_power_for_storage_wh(oncycle_p: 0.0, offcycle_p: 0.0, water_heater:)
    # Set parasitic power consumption
    # FUTURE: These are always zero right now; develop smart defaults.
    water_heater.setOnCycleParasiticFuelConsumptionRate(oncycle_p)
    water_heater.setOffCycleParasiticFuelConsumptionRate(offcycle_p)
  end

  def self.set_wh_ambient(loc_space, loc_schedule, model, wh_obj)
    if wh_obj.ambientTemperatureSchedule.is_initialized
      wh_obj.ambientTemperatureSchedule.get.remove
    end
    if not loc_schedule.nil? # Temperature schedule indicator
      wh_obj.setAmbientTemperatureSchedule(loc_schedule)
    elsif not loc_space.nil?
      wh_obj.setAmbientTemperatureIndicator('ThermalZone')
      wh_obj.setAmbientTemperatureThermalZone(loc_space.thermalZone.get)
    else # Located outside
      wh_obj.setAmbientTemperatureIndicator('Outdoors')
    end
  end

  def self.configure_setpoint_schedule(new_heater, set_temp_c, model)
    new_schedule = OpenStudio::Model::ScheduleConstant.new(model)
    new_schedule.setName('WH Setpoint Temp')
    new_schedule.setValue(set_temp_c)
    if new_heater.setpointTemperatureSchedule.is_initialized
      new_heater.setpointTemperatureSchedule.get.remove
    end
    new_heater.setSetpointTemperatureSchedule(new_schedule)
  end

  def self.get_set_temp_c(t_set, wh_type)
    return UnitConversions.convert(t_set, 'F', 'C') + deadband(wh_type) / 2.0 # Half the deadband to account for E+ deadband
  end

  def self.create_new_loop(model, name, t_set)
    # Create a new plant loop for the water heater
    loop = OpenStudio::Model::PlantLoop.new(model)
    loop.setName(name)
    loop.sizingPlant.setDesignLoopExitTemperature(t_set)
    loop.sizingPlant.setLoopDesignTemperatureDifference(UnitConversions.convert(10.0, 'R', 'K'))
    loop.setPlantLoopVolume(0.003) # ~1 gal
    loop.setMaximumLoopFlowRate(0.01) # This size represents the physical limitations to flow due to losses in the piping system. We assume that the pipes are always adequately sized.

    bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    out_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    loop.addSupplyBranchForComponent(bypass_pipe)
    out_pipe.addToNode(loop.supplyOutletNode)

    return loop
  end

  def self.get_water_heater_solar_fraction(water_heating_system, solar_thermal_system)
    if (not solar_thermal_system.nil?) && (solar_thermal_system.water_heating_system.nil? || (solar_thermal_system.water_heating_system.id == water_heating_system.id))
      solar_fraction = solar_thermal_system.solar_fraction
    end
    return solar_fraction.to_f
  end

  def self.get_default_water_heater_efficiency_by_year_installed(year, fuel_type)
    fuel_primary_id = { EPlus::FuelTypeElectricity => 'electric',
                        EPlus::FuelTypeNaturalGas => 'natural_gas',
                        EPlus::FuelTypeOil => 'fuel_oil',
                        EPlus::FuelTypeCoal => 'fuel_oil', # assumption
                        EPlus::FuelTypeWoodCord => 'fuel_oil', # assumption
                        EPlus::FuelTypeWoodPellets => 'fuel_oil', # assumption
                        EPlus::FuelTypePropane => 'lpg' }[EPlus.fuel_type(fuel_type)]

    value = nil
    lookup_year = 0
    CSV.foreach(File.join(File.dirname(__FILE__), 'lu_water_heater_efficiency.csv'), headers: true) do |row|
      next unless row['fuel_primary_id'] == fuel_primary_id

      row_year = Integer(row['year'])
      if (row_year - year).abs <= (lookup_year - year).abs
        lookup_year = row_year
        value = Float(row['value'])
      end
    end

    return value
  end

  def self.get_usage_bin_from_first_hour_rating(fhr)
    if fhr < 18.0
      return HPXML::WaterHeaterUsageBinVerySmall
    elsif fhr < 51.0
      return HPXML::WaterHeaterUsageBinLow
    elsif fhr < 75.0
      return HPXML::WaterHeaterUsageBinMedium
    else
      return HPXML::WaterHeaterUsageBinHigh
    end
  end
end
