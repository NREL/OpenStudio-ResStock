# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ResidentialAirflowTest < MiniTest::Test
  def mech_vent_none_new_options(num_airloops)
    return { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
  end

  def test_no_hvac_equip
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemSensor' => 10, 'EnergyManagementSystemActuator' => 5, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'Material' => 1, 'Construction' => 1 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.074880, 'Cw' => 0.140569, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'TerrainType' => 'Suburbs' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, 1, 4)
  end

  def test_non_ducted_hvac_equipment
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemSensor' => 10, 'EnergyManagementSystemActuator' => 5, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'Material' => 1, 'Construction' => 1 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.074880, 'Cw' => 0.140569, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'TerrainType' => 'Suburbs' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_ElectricBaseboard.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, 1, 2)
    assert_includes(result.warnings.map { |x| x.logMessage }, 'No ducted HVAC equipment was found but ducts were specified. Overriding duct specification.')
  end

  def test_has_clothes_dryer
    num_airloops = 2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 11 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops, 'ScheduleFile' => 1 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC_ElecWHTank_ClothesWasher_ClothesDryer.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops)
  end

  def test_neighbors
    num_airloops = 2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000087 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC_Neighbors.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_mech_vent_none
    num_airloops = 2
    args_hash = {}
    args_hash['mech_vent_type'] = 'none'
    expected_num_del_objects = {}
    expected_num_new_objects = mech_vent_none_new_options(num_airloops)
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 1, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_mech_vent_supply
    num_airloops = 2
    args_hash = {}
    args_hash['mech_vent_type'] = Constants.VentTypeSupply
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
    # test objects are removed correctly
    args_hash['mech_vent_type'] = 'none'
    expected_num_del_objects = expected_num_new_objects
    expected_num_new_objects = mech_vent_none_new_options(num_airloops)
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, {}, __method__, num_airloops, 1)
  end

  def test_mech_vent_cfis
    num_airloops = 2
    args_hash = {}
    args_hash['mech_vent_type'] = Constants.VentTypeCFIS
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + 2 * num_airloops, 'EnergyManagementSystemProgram' => 1 + 2 * num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 3 + 23 * num_airloops, 'EnergyManagementSystemInternalVariable' => num_airloops + 2, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops, 'EnergyManagementSystemOutputVariable' => 1 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops + 1, 1)
    # test objects are removed correctly
    args_hash['mech_vent_type'] = 'none'
    expected_num_del_objects = expected_num_new_objects
    expected_num_new_objects = mech_vent_none_new_options(num_airloops)
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, {}, __method__, num_airloops, 1)
  end

  def test_mech_vent_cfis_no_ducts
    args_hash = {}
    args_hash['mech_vent_type'] = Constants.VentTypeCFIS
    result = _test_error('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_ElectricBaseboard.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'A CFIS ventilation system has been selected but the building does not have central, forced air equipment.')
  end

  def test_mech_vent_cfis_duct_location_in_living
    num_airloops = 2
    args_hash = {}
    args_hash['duct_location'] = Constants.SpaceTypeLiving
    args_hash['mech_vent_type'] = Constants.VentTypeCFIS
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemProgramCallingManager' => 3, 'EnergyManagementSystemProgram' => 3, 'EnergyManagementSystemSensor' => 12, 'EnergyManagementSystemActuator' => 5, 'EnergyManagementSystemGlobalVariable' => 3, 'EnergyManagementSystemInternalVariable' => 4, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'Material' => 1, 'Construction' => 1, 'EnergyManagementSystemOutputVariable' => 1 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.0, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'TerrainType' => 'Suburbs' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, 2, 1)
    # test objects are removed correctly
    args_hash['mech_vent_type'] = 'none'
    args_hash['duct_location'] = Constants.Auto
    expected_num_del_objects = expected_num_new_objects
    expected_num_new_objects = mech_vent_none_new_options(num_airloops)
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, {}, __method__, 2, 1)
  end

  def test_mech_vent_exhaust_ashrae_622_2013
    num_airloops = 2
    args_hash = {}
    args_hash['mech_vent_ashrae_std'] = '2013'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
    # test objects are removed correctly
    args_hash['mech_vent_type'] = 'none'
    expected_num_del_objects = expected_num_new_objects
    expected_num_new_objects = mech_vent_none_new_options(num_airloops)
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, {}, __method__, num_airloops, 1)
  end

  def test_existing_building
    num_airloops = 2
    args_hash = {}
    args_hash['is_existing_home'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_crawl
    num_airloops = 2
    args_hash = {}
    args_hash['crawl_ach'] = 0.1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 3, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.093461, 'Cw' => 0.108877, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'crawl zone' }
    model, result = _test_measure('SFD_2000sqft_2story_CS_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_pier_beam
    num_airloops = 2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 3, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.091302, 'Cw' => 0.108877, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000307 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'pier and beam zone' }
    model, result = _test_measure('SFD_2000sqft_2story_PB_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_ufbasement
    num_airloops = 2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 3, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished basement zone' }
    model, result = _test_measure('SFD_2000sqft_2story_UB_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_duct_location_ufbasement
    num_airloops = 2
    args_hash = {}
    args_hash['duct_location'] = Constants.SpaceTypeUnfinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 3, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished basement zone' }
    model, result = _test_measure('SFD_2000sqft_2story_UB_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_fbasement
    num_airloops = 2
    args_hash = {}
    args_hash['finished_basement_ach'] = 0.1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 3, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.046322, 'Cs' => 0.084549, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'finished basement zone' }
    model, result = _test_measure('SFD_2000sqft_2story_FB_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_duct_location_fbasement
    num_airloops = 2
    args_hash = {}
    args_hash['duct_location'] = Constants.SpaceTypeFinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.046322, 'Cs' => 0.084549, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'finished basement zone' }
    model, result = _test_measure('SFD_2000sqft_2story_FB_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_duct_location_ufattic
    num_airloops = 2
    args_hash = {}
    args_hash['duct_location'] = Constants.SpaceTypeUnfinishedAttic
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_duct_location_in_living
    args_hash = {}
    args_hash['duct_location'] = Constants.SpaceTypeLiving
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemSensor' => 12, 'EnergyManagementSystemActuator' => 5, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'Material' => 1, 'Construction' => 1 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'TerrainType' => 'Suburbs' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, 1, 1)
  end

  def test_terrain_ocean
    num_airloops = 2
    args_hash = {}
    args_hash['terrain'] = Constants.TerrainOcean
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.001317 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Ocean', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_terrain_plains
    num_airloops = 2
    args_hash = {}
    args_hash['terrain'] = Constants.TerrainPlains
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000725 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Country', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_terrain_rural
    num_airloops = 2
    args_hash = {}
    args_hash['terrain'] = Constants.TerrainRural
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000487 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Country', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_terrain_city
    num_airloops = 2
    args_hash = {}
    args_hash['terrain'] = Constants.TerrainCity
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000120 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'City', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_mech_vent_hrv
    num_airloops = 2
    args_hash = {}
    args_hash['mech_vent_type'] = Constants.VentTypeBalanced
    args_hash['mech_vent_sensible_efficiency'] = 0.6
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'FanOnOff' => 2, 'HeatExchangerAirToAirSensibleAndLatent' => 1, 'ZoneHVACEnergyRecoveryVentilatorController' => 1, 'ZoneHVACEnergyRecoveryVentilator' => 1, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone', 'res mv_1 erv' => { 'SupAirRate' => 0.023597, 'ExhAirRate' => 0.023597, 'Priority' => 1 } }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
    # test objects are removed correctly
    args_hash['mech_vent_type'] = 'none'
    expected_num_del_objects = expected_num_new_objects
    expected_num_new_objects = mech_vent_none_new_options(num_airloops)
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, {}, __method__, num_airloops, 1)
  end

  def test_mech_vent_erv
    num_airloops = 2
    args_hash = {}
    args_hash['mech_vent_type'] = Constants.VentTypeBalanced
    args_hash['mech_vent_total_efficiency'] = 0.48
    args_hash['mech_vent_sensible_efficiency'] = 0.72
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'FanOnOff' => 2, 'HeatExchangerAirToAirSensibleAndLatent' => 1, 'ZoneHVACEnergyRecoveryVentilatorController' => 1, 'ZoneHVACEnergyRecoveryVentilator' => 1, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone', 'res mv_1 erv' => { 'SupAirRate' => 0.023597, 'ExhAirRate' => 0.023597, 'Priority' => 1 } }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
    # test objects are removed correctly
    args_hash['mech_vent_type'] = 'none'
    expected_num_del_objects = expected_num_new_objects
    expected_num_new_objects = mech_vent_none_new_options(num_airloops)
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, {}, __method__, num_airloops, 1)
  end

  def test_nat_vent_0_wkdy_0_wked
    num_airloops = 2
    args_hash = {}
    args_hash['nat_vent_num_weekdays'] = 0
    args_hash['nat_vent_num_weekends'] = 0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_nat_vent_1_wkdy_1_wked
    num_airloops = 2
    args_hash = {}
    args_hash['nat_vent_num_weekdays'] = 1
    args_hash['nat_vent_num_weekends'] = 1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_nat_vent_2_wkdy_2_wked
    num_airloops = 2
    args_hash = {}
    args_hash['nat_vent_num_weekdays'] = 2
    args_hash['nat_vent_num_weekends'] = 2
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_nat_vent_4_wkdy
    num_airloops = 2
    args_hash = {}
    args_hash['nat_vent_num_weekdays'] = 4
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_nat_vent_5_wkdy
    num_airloops = 2
    args_hash = {}
    args_hash['nat_vent_num_weekdays'] = 5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_ductless_mini_split_heat_pump_no_ducts # miniSplitHPIsDucted=false, duct_location=none
    args_hash = {}
    args_hash['duct_location'] = 'none'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemSensor' => 12, 'EnergyManagementSystemActuator' => 5, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.074880, 'Cw' => 0.140569, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'TerrainType' => 'Suburbs' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_MSHP.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, 1, 1)
  end

  def test_ductless_mini_split_heat_pump_has_ducts # miniSplitHPIsDucted=false, duct_location=auto (WARNING, OVERRIDE)
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemSensor' => 12, 'EnergyManagementSystemActuator' => 5, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.074880, 'Cw' => 0.140569, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'TerrainType' => 'Suburbs' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_MSHP.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, 1, 2)
  end

  def test_ducted_mini_split_heat_pump_no_ducts # miniSplitHPIsDucted=true, duct_location=none (WARNING)
    args_hash = {}
    args_hash['duct_location'] = 'none'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemSensor' => 12, 'EnergyManagementSystemActuator' => 5, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.074880, 'Cw' => 0.140569, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'TerrainType' => 'Suburbs' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_MSHPDucted.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, 1, 2)
  end

  def test_ducted_mini_split_heat_pump_has_ducts # miniSplitHPIsDucted=true, duct_location=auto
    num_airloops = 2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.074880, 'Cw' => 0.140569, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_ms_htg_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ms_clg_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_MSHPDucted.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_ducted_mini_split_heat_pump_cfis
    num_airloops = 2
    args_hash = {}
    args_hash['mech_vent_type'] = Constants.VentTypeCFIS
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 3 + num_airloops, 'EnergyManagementSystemProgram' => 3 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 3 + 23 * num_airloops, 'EnergyManagementSystemInternalVariable' => num_airloops + 2, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops, 'EnergyManagementSystemOutputVariable' => 1 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.074880, 'Cw' => 0.140569, 'faneff_wh' => 0.0, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_ms_htg_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ms_clg_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_MSHPDucted.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops + 1, 1)
  end

  def test_ductless_mini_split_heat_pump_cfis
    args_hash = {}
    args_hash['mech_vent_type'] = Constants.VentTypeCFIS
    result = _test_error('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_MSHP.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'A CFIS ventilation system has been selected but the building does not have central, forced air equipment.')
  end

  def test_duct_location_frac
    num_airloops = 2
    args_hash = {}
    args_hash['duct_location'] = Constants.SpaceTypeUnfinishedAttic
    args_hash['duct_location_frac'] = '0.5'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.099950, 'f_ret' => 0.050049, 'f_OA' => 0.049900 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.099950, 'f_ret' => 0.050049, 'f_OA' => 0.049900 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_return_loss_greater_than_supply_loss
    num_airloops = 2
    args_hash = {}
    args_hash['duct_supply_frac'] = 0.067
    args_hash['duct_return_frac'] = 0.6
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.030119, 'f_ret' => 0.194880, 'f_OA' => 0.164760 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.030119, 'f_ret' => 0.194880, 'f_OA' => 0.164760 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_duct_num_returns
    num_airloops = 2
    args_hash = {}
    args_hash['has_hvac_flue'] = 'true'
    args_hash['duct_num_returns'] = '1'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_no_living_garage_attic_infiltration
    num_airloops = 2
    args_hash = {}
    args_hash['living_ach50'] = 0
    args_hash['garage_ach50'] = 0
    args_hash['unfinished_attic_sla'] = 0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_GRG_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_garage_with_attic
    num_airloops = 2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 2, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_GRG_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_garage_without_attic
    num_airloops = 2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.05, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000229, 'Cw' => 0.000319 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'garage zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_GRG_FR_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_error_duct_total_leakage_invalid
    args_hash = {}
    args_hash['duct_total_leakage'] = -0.00001
    result = _test_error('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Ducts: Total Leakage must be greater than or equal to 0.')
  end

  def test_error_duct_supply_leakage_frac_invalid
    args_hash = {}
    args_hash['duct_supply_frac'] = -0.00001
    result = _test_error('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Ducts: Supply Leakage Fraction of Total must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_error_duct_return_leakage_frac_invalid
    args_hash = {}
    args_hash['duct_return_frac'] = -0.00001
    result = _test_error('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Ducts: Return Leakage Fraction of Total must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_error_duct_supply_ah_leakage_frac_invalid
    args_hash = {}
    args_hash['duct_ah_supply_frac'] = -0.00001
    result = _test_error('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Ducts: Supply Air Handler Leakage Fraction of Total must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_error_duct_return_ah_leakage_frac_invalid
    args_hash = {}
    args_hash['duct_ah_return_frac'] = -0.00001
    result = _test_error('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Ducts: Return Air Handler Leakage Fraction of Total must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_error_duct_r_value_invalid
    args_hash = {}
    args_hash['duct_r'] = -0.00001
    result = _test_error('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Ducts: Insulation Nominal R-Value must be greater than or equal to 0.')
  end

  def test_error_duct_supply_surface_area_mult_invalid
    args_hash = {}
    args_hash['duct_supply_area_mult'] = -0.00001
    result = _test_error('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Ducts: Supply Surface Area Multiplier must be greater than or equal to 0.')
  end

  def test_error_duct_return_surface_area_mult_invalid
    args_hash = {}
    args_hash['duct_return_area_mult'] = -0.00001
    result = _test_error('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Ducts: Return Surface Area Multiplier must be greater than or equal to 0.')
  end

  def test_retrofit_infiltration
    num_airloops = 2
    args_hash = {}
    args_hash['mech_vent_type'] = Constants.VentTypeBalanced
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 4, 'EnergyManagementSystemSubroutine' => num_airloops, 'EnergyManagementSystemProgramCallingManager' => 1 + num_airloops, 'EnergyManagementSystemProgram' => 2 + num_airloops, 'EnergyManagementSystemSensor' => 10 + 10 * num_airloops, 'EnergyManagementSystemActuator' => 5 + 12 * num_airloops, 'EnergyManagementSystemGlobalVariable' => 23 * num_airloops, 'AirLoopHVACReturnPlenum' => num_airloops, 'OtherEquipmentDefinition' => 10 * num_airloops, 'OtherEquipment' => 10 * num_airloops, 'ThermalZone' => num_airloops, 'ZoneMixing' => 2 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Space' => num_airloops, 'FanOnOff' => 2, 'HeatExchangerAirToAirSensibleAndLatent' => 1, 'ZoneHVACEnergyRecoveryVentilatorController' => 1, 'ZoneHVACEnergyRecoveryVentilator' => 1, 'Material' => 1, 'ElectricEquipmentDefinition' => 3, 'ElectricEquipment' => 3, 'SurfacePropertyConvectionCoefficients' => 6 * num_airloops, 'Surface' => 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.069658, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
    args_hash['living_ach50'] = 3
    args_hash['mech_vent_type'] = Constants.VentTypeBalanced
    expected_num_del_objects = expected_num_new_objects
    expected_num_new_objects = expected_num_new_objects
    expected_values = { 'res_infil_1_program' => { 'c' => 0.029853, 'Cs' => 0.086238, 'Cw' => 0.128435, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000179, 'Cw' => 0.000282 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.149925, 'f_ret' => 0.075074, 'f_OA' => 0.074850 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_airloops, 1)
  end

  def test_single_family_attached_new_construction_furnace_central_air_conditioner
    num_units = 1
    num_airloops = 2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => num_units * 4, 'EnergyManagementSystemSubroutine' => num_units * num_airloops, 'EnergyManagementSystemProgramCallingManager' => num_units * (1 + num_airloops), 'EnergyManagementSystemProgram' => num_units * (2 + num_airloops), 'EnergyManagementSystemSensor' => 27 * num_units + 3, 'EnergyManagementSystemActuator' => num_units * (5 + 12 * num_airloops), 'EnergyManagementSystemGlobalVariable' => num_units * 23 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => num_units * 2, 'ZoneMixing' => num_units * 2 * num_airloops, 'OtherEquipment' => num_units * 10 * num_airloops, 'OtherEquipmentDefinition' => num_units * 10 * num_airloops, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Surface' => num_units * 6 * num_airloops, 'Space' => num_units * num_airloops, 'ThermalZone' => num_units * num_airloops, 'AirLoopHVACReturnPlenum' => num_units * 2, 'Material' => 1, 'ElectricEquipmentDefinition' => num_units * 3, 'ElectricEquipment' => num_units * 3, 'SurfacePropertyConvectionCoefficients' => num_units * 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.042099, 'Cs' => 0.066417, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000089, 'Cw' => 0.000199 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.199900, 'f_ret' => 0.100099, 'f_OA' => 0.099800 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.199900, 'f_ret' => 0.100099, 'f_OA' => 0.099800 }, \
                        'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished attic zone' }
    model, result = _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * num_airloops, num_units)
  end

  def test_single_family_attached_new_construction_central_system_boiler_baseboards
    num_units = 1
    num_airloops = 0
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => num_units * 4, 'EnergyManagementSystemProgramCallingManager' => num_units * (1 + num_airloops), 'EnergyManagementSystemProgram' => num_units * (2 + num_airloops), 'EnergyManagementSystemSensor' => num_units * 7 + 3, 'EnergyManagementSystemActuator' => num_units * (5 + 12 * num_airloops), 'SpaceInfiltrationDesignFlowRate' => num_units * 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Material' => 1, 'ElectricEquipmentDefinition' => num_units * 3, 'ElectricEquipment' => num_units * 3 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.042099, 'Cs' => 0.066417, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000089, 'Cw' => 0.000199 }, 'TerrainType' => 'Suburbs' }
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Central_System_Boiler_Baseboards.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units, num_units + 1)
  end

  def test_single_family_attached_new_construction_central_system_fan_coil
    num_units = 1
    num_airloops = 0
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => num_units * 4, 'EnergyManagementSystemProgramCallingManager' => num_units * (1 + num_airloops), 'EnergyManagementSystemProgram' => num_units * (2 + num_airloops), 'EnergyManagementSystemSensor' => num_units * 7 + 3, 'EnergyManagementSystemActuator' => num_units * (5 + 12 * num_airloops), 'SpaceInfiltrationDesignFlowRate' => num_units * 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Material' => 1, 'ElectricEquipmentDefinition' => num_units * 3, 'ElectricEquipment' => num_units * 3 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.042099, 'Cs' => 0.066417, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000089, 'Cw' => 0.000199 }, 'TerrainType' => 'Suburbs' }
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Central_System_Fan_Coil.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units, num_units + 1)
  end

  def test_single_family_attached_new_construction_central_system_ptac
    num_units = 1
    num_airloops = 0
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => num_units * 4, 'EnergyManagementSystemProgramCallingManager' => num_units * (1 + num_airloops), 'EnergyManagementSystemProgram' => num_units * (2 + num_airloops), 'EnergyManagementSystemSensor' => num_units * 7 + 3, 'EnergyManagementSystemActuator' => num_units * (5 + 12 * num_airloops), 'SpaceInfiltrationDesignFlowRate' => num_units * 2, 'SpaceInfiltrationEffectiveLeakageArea' => 1, 'Construction' => 1, 'Material' => 1, 'ElectricEquipmentDefinition' => num_units * 3, 'ElectricEquipment' => num_units * 3 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.042099, 'Cs' => 0.066417, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000089, 'Cw' => 0.000199 }, 'TerrainType' => 'Suburbs' }
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Central_System_PTAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units, num_units + 1)
  end

  def test_multifamily_slab_new_construction_furnace_central_air_conditioner
    num_units = 1
    num_airloops = 2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => num_units * 4, 'EnergyManagementSystemProgramCallingManager' => num_units, 'EnergyManagementSystemProgram' => num_units * 2, 'EnergyManagementSystemSensor' => 3 + (num_units * 9), 'EnergyManagementSystemActuator' => num_units * 5, 'SpaceInfiltrationDesignFlowRate' => num_units * 2, 'ElectricEquipmentDefinition' => num_units * 3, 'ElectricEquipment' => num_units * 3, 'Material' => 1, 'Construction' => 1 }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.047360, 'Cs' => 0.049758, 'Cw' => 0.128435, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000089, 'Cw' => 0.000199 }, 'TerrainType' => 'Suburbs' }
    model, result = _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units, num_units)
  end

  def test_multifamily_cs_new_construction_furnace_central_air_conditioner
    num_units = 1
    num_airloops = 2
    args_hash = {}
    args_hash['crawl_ach'] = 0.1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => num_units * 4, 'EnergyManagementSystemSubroutine' => num_units * num_airloops, 'EnergyManagementSystemProgramCallingManager' => num_units * (1 + num_airloops), 'EnergyManagementSystemProgram' => num_units * (2 + num_airloops), 'EnergyManagementSystemSensor' => 3 + (num_units * 27), 'EnergyManagementSystemActuator' => num_units * (5 + 12 * num_airloops), 'EnergyManagementSystemGlobalVariable' => num_units * 23 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => num_units * 2 + 2, 'ZoneMixing' => num_units * 2 * num_airloops, 'OtherEquipment' => num_units * 10 * num_airloops, 'OtherEquipmentDefinition' => num_units * 10 * num_airloops, 'Construction' => 1, 'Surface' => num_units * 6 * num_airloops, 'Space' => num_units * num_airloops, 'ThermalZone' => num_units * num_airloops, 'AirLoopHVACReturnPlenum' => num_units * 2, 'Material' => 1, 'ElectricEquipmentDefinition' => num_units * 3, 'ElectricEquipment' => num_units * 3, 'SurfacePropertyConvectionCoefficients' => num_units * 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.047360, 'Cs' => 0.0543, 'Cw' => 0.1089, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000089, 'Cw' => 0.000199 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.199900, 'f_ret' => 0.100099, 'f_OA' => 0.099800 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.199900, 'f_ret' => 0.100099, 'f_OA' => 0.099800 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'crawl zone' }
    model, result = _test_measure('MF_8units_1story_CS_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * num_airloops, num_units)
  end

  def test_multifamily_ub_new_construction_furnace_central_air_conditioner
    num_units = 1
    num_airloops = 2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => num_units * 4, 'EnergyManagementSystemSubroutine' => num_units * num_airloops, 'EnergyManagementSystemProgramCallingManager' => num_units * (1 + num_airloops), 'EnergyManagementSystemProgram' => num_units * (2 + num_airloops), 'EnergyManagementSystemSensor' => 3 + (num_units * 27), 'EnergyManagementSystemActuator' => num_units * (5 + 12 * num_airloops), 'EnergyManagementSystemGlobalVariable' => num_units * 23 * num_airloops, 'SpaceInfiltrationDesignFlowRate' => num_units * 2 + 2, 'ZoneMixing' => num_units * 2 * num_airloops, 'OtherEquipment' => num_units * 10 * num_airloops, 'OtherEquipmentDefinition' => num_units * 10 * num_airloops, 'Construction' => 1, 'Surface' => num_units * 6 * num_airloops, 'Space' => num_units * num_airloops, 'ThermalZone' => num_units * num_airloops, 'AirLoopHVACReturnPlenum' => num_units * 2, 'Material' => 1, 'ElectricEquipmentDefinition' => num_units * 3, 'ElectricEquipment' => num_units * 3, 'SurfacePropertyConvectionCoefficients' => num_units * 6 * num_airloops }
    expected_values = { 'res_infil_1_program' => { 'c' => 0.047360, 'Cs' => 0.0498, 'Cw' => 0.1284, 'faneff_wh' => 0.943894, 'faneff_sp' => 0.471947 }, 'res_nv_1_program' => { 'Cs' => 0.000089, 'Cw' => 0.000199 }, 'res_ds_res_fur_gas_asys_lk_subrout' => { 'f_sup' => 0.199900, 'f_ret' => 0.100099, 'f_OA' => 0 }, 'res_ds_res_ac_asys_lk_subrout' => { 'f_sup' => 0.199900, 'f_ret' => 0.100099, 'f_OA' => 0 }, 'TerrainType' => 'Suburbs', 'DuctLocation' => 'unfinished basement zone' }
    model, result = _test_measure('MF_8units_1story_UB_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * num_airloops, num_units)
  end

  private

  def _test_error(osm_file_or_model, args_hash)
    # create an instance of the measure
    measure = ResidentialAirflow.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    model = get_model(File.dirname(__FILE__), osm_file_or_model)

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    show_output(result) unless result.value.valueName == 'Fail'

    # assert that it didn't run
    assert_equal('Fail', result.value.valueName)
    assert(result.errors.size == 1)

    return result
  end

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, test_name, num_infos = 0, num_warnings = 0)
    # create an instance of the measure
    measure = ResidentialAirflow.new

    # check for standard methods
    assert(!measure.name.empty?)
    assert(!measure.description.empty?)
    assert(!measure.modeler_description.empty?)

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    model = get_model(File.dirname(__FILE__), osm_file_or_model)

    # get the initial objects in the model
    initial_objects = get_objects(model)

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # save the model to test output directory
    # output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/#{test_name}.osm")
    # model.save(output_file_path, true)

    # show the output
    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert_equal(num_infos, result.info.size)
    assert_equal(num_warnings, result.warnings.size)

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = ['ScheduleDay', 'ZoneHVACEquipmentList', 'PortList', 'Node', 'SizingZone', 'ScheduleConstant', 'ScheduleTypeLimits', 'CurveCubic', 'CurveExponent', 'ScheduleRule']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')
    check_ems(model)
    check_hvac_priorities(model, Constants.ZoneHVACPriorityList)

    actual_values = {}

    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        unless actual_values.keys.include? new_object.name.to_s
          actual_values[new_object.name.to_s] = {}
        end
        if ['EnergyManagementSystemProgram', 'EnergyManagementSystemSubroutine'].include? obj_type
          new_object.lines.each do |line|
            next unless line.downcase.start_with? 'set'

            lhs, rhs = line.split('=')
            lhs = lhs.gsub('Set', '').gsub('set', '').strip
            rhs = rhs.gsub(',', '').gsub(';', '').strip
            actual_values[new_object.name.to_s][lhs] = rhs
          end
        elsif obj_type == 'EnergyManagementSystemSensor'
          next if new_object.outputVariableOrMeterName != 'Zone Air Temperature'

          actual_values['DuctLocation'] = new_object.keyName
        elsif obj_type == 'ZoneHVACEnergyRecoveryVentilator'
          actual_values[new_object.name.to_s]['SupAirRate'] = new_object.supplyAirFlowRate
          actual_values[new_object.name.to_s]['ExhAirRate'] = new_object.exhaustAirFlowRate
          model.getThermalZones.each do |thermal_zone|
            heating_seq = thermal_zone.equipmentInHeatingOrder.index(new_object)
            next if heating_seq.nil?

            actual_values[new_object.name.to_s]['Priority'] = heating_seq + 1
          end
        end
      end
    end
    actual_values['TerrainType'] = model.getSite.terrain.to_s

    expected_values.each do |obj_name, values|
      if values.respond_to? :to_str
        assert_equal(values, actual_values[obj_name])
      else
        values.each do |lhs, rhs|
          assert_in_epsilon(rhs, actual_values[obj_name][lhs].to_f, 0.0125)
        end
      end
    end

    return model, result
  end
end
