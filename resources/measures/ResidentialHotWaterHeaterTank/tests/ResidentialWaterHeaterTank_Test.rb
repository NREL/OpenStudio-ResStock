require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ResidentialHotWaterHeaterTankTest < MiniTest::Test
  def test_new_construction_standard_gas
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_premium_gas
    args_hash = {}
    args_hash['energy_factor'] = '0.67'
    args_hash['recovery_efficiency'] = 0.78
    args_hash['capacity'] = '34'
    args_hash['oncyc_power'] = 165
    args_hash['offcyc_power'] = 1
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 9.97, 'ThermalEfficiency' => 0.789, 'TankUA' => 4.503, 'Setpoint' => 125, 'OnCycle' => 165, 'OffCycle' => 1, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.91 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_auto_ef_and_capacity_gas
    args_hash = {}
    args_hash['energy_factor'] = Constants.Auto
    args_hash['capacity'] = Constants.Auto
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 10.55, 'ThermalEfficiency' => 0.774, 'TankUA' => 7.706, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_elec
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.92'
    args_hash['capacity'] = '15.35'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 4.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 2.21, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_premium_elec
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 1.34, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_elec_stratified
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.92'
    args_hash['capacity'] = '15.35'
    args_hash['tank_model_type'] = 'stratified'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 4.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.205, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_premium_elec_stratified
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_premium_elec_stratified_scheduled_sp
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_setpoint_schedule.csv'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleFixedInterval' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_auto_ef_and_capacity_elec
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = Constants.Auto
    args_hash['capacity'] = Constants.Auto
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 2.69, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_oil
    args_hash = {}
    args_hash['capacity'] = '90.0'
    args_hash['energy_factor'] = '0.62'
    args_hash['recovery_efficiency'] = 0.78
    args_hash['fuel_type'] = Constants.FuelTypeOil
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 26.38, 'ThermalEfficiency' => 0.785, 'TankUA' => 6.753, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeOil, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_premium_oil
    args_hash = {}
    args_hash['capacity'] = '104'
    args_hash['energy_factor'] = '0.68'
    args_hash['recovery_efficiency'] = 0.9
    args_hash['oncyc_power'] = 165
    args_hash['offcyc_power'] = 1
    args_hash['fuel_type'] = Constants.FuelTypeOil
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 30.48, 'ThermalEfficiency' => 0.905, 'TankUA' => 8.410, 'Setpoint' => 125, 'OnCycle' => 165, 'OffCycle' => 1, 'FuelType' => Constants.FuelTypeOil, 'SkinLossFrac' => 0.91 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_auto_ef_and_capacity_oil
    args_hash = {}
    args_hash['capacity'] = Constants.Auto
    args_hash['energy_factor'] = Constants.Auto
    args_hash['recovery_efficiency'] = 0.78
    args_hash['fuel_type'] = Constants.FuelTypeOil
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 10.55, 'ThermalEfficiency' => 0.807, 'TankUA' => 14.465, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeOil, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_propane
    args_hash = {}
    args_hash['capacity'] = '47'
    args_hash['fuel_type'] = Constants.FuelTypePropane
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 13.78, 'ThermalEfficiency' => 0.771, 'TankUA' => 7.790, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypePropane, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_premium_propane
    args_hash = {}
    args_hash['capacity'] = '47'
    args_hash['energy_factor'] = '0.67'
    args_hash['recovery_efficiency'] = 0.78
    args_hash['oncyc_power'] = 140
    args_hash['offcyc_power'] = 1
    args_hash['fuel_type'] = Constants.FuelTypePropane
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 13.78, 'ThermalEfficiency' => 0.786, 'TankUA' => 4.404, 'Setpoint' => 125, 'OnCycle' => 140, 'OffCycle' => 1, 'FuelType' => Constants.FuelTypePropane, 'SkinLossFrac' => 0.91 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_auto_ef_and_capacity_propane
    args_hash = {}
    args_hash['capacity'] = Constants.Auto
    args_hash['energy_factor'] = Constants.Auto
    args_hash['fuel_type'] = Constants.FuelTypePropane
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 10.55, 'ThermalEfficiency' => 0.774, 'TankUA' => 7.706, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypePropane, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_living_gas
    args_hash = {}
    args_hash['location'] = Constants.SpaceTypeLiving
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_setpoint_130_gas
    args_hash = {}
    args_hash['setpoint_temp'] = 130
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => 130, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_volume_30_gas
    args_hash = {}
    args_hash['tank_volume'] = '30'
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 30, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_stratified_tank_gas_with_stratified_tank_electric
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    expected_num_del_objects = { 'WaterHeaterStratified' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_Stratified_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_tank_gas_with_stratified_tank_electric
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    expected_num_del_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_stratified_tank_gas_with_stratified_tank_electric_scheduled_sp
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_setpoint_schedule.csv'
    expected_num_del_objects = { 'WaterHeaterStratified' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'ScheduleFixedInterval' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_Stratified_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_hpwh_with_tank_electric
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    expected_num_del_objects = { 'WaterHeaterStratified' => 1, 'ScheduleConstant' => 6, 'CoilWaterHeatingAirToWaterHeatPumpWrapped' => 1, 'FanOnOff' => 1, 'WaterHeaterHeatPumpWrappedCondenser' => 1, 'OtherEquipment' => 2, 'OtherEquipmentDefinition' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemActuator' => 7, 'EnergyManagementSystemSensor' => 10, 'EnergyManagementSystemTrendVariable' => 3 }
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_HPWH.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_hpwh_with_tank_electric_scheduled_sp
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_setpoint_schedule.csv'
    expected_num_del_objects = { 'WaterHeaterStratified' => 1, 'ScheduleConstant' => 6, 'CoilWaterHeatingAirToWaterHeatPumpWrapped' => 1, 'FanOnOff' => 1, 'WaterHeaterHeatPumpWrappedCondenser' => 1, 'OtherEquipment' => 2, 'OtherEquipmentDefinition' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemActuator' => 7, 'EnergyManagementSystemSensor' => 10, 'EnergyManagementSystemTrendVariable' => 3 }
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'ScheduleFixedInterval' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_HPWH.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_hpwh_scheduled_sp_with_tank_electric_scheduled_sp
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_setpoint_schedule.csv'
    expected_num_del_objects = { 'WaterHeaterStratified' => 1, 'ScheduleFixedInterval' => 3, 'ScheduleConstant' => 4, 'WaterHeaterHeatPumpWrappedCondenser' => 1, 'CoilWaterHeatingAirToWaterHeatPumpWrapped' => 1, 'FanOnOff' => 1, 'OtherEquipment' => 2, 'OtherEquipmentDefinition' => 2, 'EnergyManagementSystemSensor' => 10, 'EnergyManagementSystemActuator' => 7, 'EnergyManagementSystemTrendVariable' => 3, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'ScheduleFixedInterval' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_HPWH_scheduled_SP.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_tank_electric_scheduled_sp_with_tank_electric_scheduled_sp
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_setpoint_schedule.csv'
    expected_num_del_objects = { 'WaterHeaterStratified' => 1, 'ScheduleFixedInterval' => 2 }
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'ScheduleFixedInterval' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_Stratified_WHTank_scheduled_SP.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_tankless_gas_with_tank_gas
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTankless.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_tankless_gas_with_tank_gas_scheduled_sp
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_setpoint_schedule.csv'
    expected_num_del_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'ScheduleFixedInterval' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTankless.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_tankless_gas_with_tank_electric_scheduled_sp
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_setpoint_schedule.csv'
    expected_num_del_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'ScheduleFixedInterval' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTankless.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_tank_gas_swh_with_stratified_tank_electric
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    expected_num_del_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0, 'StorageTankSetpoint1' => 125, 'StorageTankSetpoint2' => 125 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank_SHW.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_tank_gas_swh_with_stratified_tank_electric_scheduled_sp
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_setpoint_schedule.csv'
    expected_num_del_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'ScheduleFixedInterval' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0, 'StorageTankSetpoint1' => 126, 'StorageTankSetpoint2' => 126 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank_SHW.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
    args_hash = {}
    args_hash['energy_factor'] = '0.67'
    args_hash['recovery_efficiency'] = 0.78
    args_hash['capacity'] = '34'
    args_hash['oncyc_power'] = 165
    args_hash['offcyc_power'] = 1
    args_hash['setpoint_temp'] = 130
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 9.97, 'ThermalEfficiency' => 0.789, 'TankUA' => 4.503, 'Setpoint' => 130, 'OnCycle' => 165, 'OffCycle' => 1, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.91 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_hpwh_with_tank_gas
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = { 'WaterHeaterStratified' => 1, 'ScheduleConstant' => 6, 'CoilWaterHeatingAirToWaterHeatPumpWrapped' => 1, 'FanOnOff' => 1, 'WaterHeaterHeatPumpWrappedCondenser' => 1, 'OtherEquipment' => 2, 'OtherEquipmentDefinition' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemActuator' => 7, 'EnergyManagementSystemSensor' => 10, 'EnergyManagementSystemTrendVariable' => 3 }
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_HPWH.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_tank_gas_swh_with_tank_gas
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    args_hash['setpoint_temp'] = '130'
    expected_num_del_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => args_hash['setpoint_temp'].to_f, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64, 'StorageTankSetpoint1' => args_hash['setpoint_temp'].to_f, 'StorageTankSetpoint2' => args_hash['setpoint_temp'].to_f }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank_SHW.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_error_missing_setpoint_schedule
    args_hash = {}
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'non_existent_schedule.csv'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], "'#{File.expand_path('..', __dir__)}/resources/non_existent_schedule.csv' does not exist.")
  end

  def test_error_setpoint_schedule_wrong_length
    args_hash = {}
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'wrong_length_schedule.csv'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Hourly water heater schedule must be the length of the simulation period or a full year')
  end

  def test_argument_error_setpoint_gt_212_scheduled
    args_hash = {}
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_schedule_high_above_212.csv'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Water heater temperature setpoint must not be less than 0F or greater than 212F.')
  end

  def test_argument_warning_setpoint_gt_140_scheduled
    args_hash = {}
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_schedule_high_above_140.csv'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleFixedInterval' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1, 2)
  end

  def test_argument_error_setpoint_lt_0_scheduled
    args_hash = {}
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_schedule_low_below_0.csv'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Water heater temperature setpoint must not be less than 0F or greater than 212F.')
  end

  def test_argument_warning_setpoint_lt_110_scheduled
    args_hash = {}
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_schedule_low_below_110.csv'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleFixedInterval' => 2 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1, 2)
  end

  def test_short_period_with_short_schedule
    args_hash = {}
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_setpoint_schedule_feb.csv'
    expected_num_del_objects = {   'ScheduleConstant' => 2, 'WaterHeaterMixed' => 1 }
    expected_num_new_objects = { 'ScheduleFixedInterval' => 2, 'WaterHeaterMixed' => 1 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_Successful_EnergyPlus_Run_TMY_February.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_short_period_with_full_year_schedule
    args_hash = {}
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeScheduled
    args_hash['schedule_directory'] = './resources'
    args_hash['setpoint_schedule'] = 'hourly_setpoint_schedule.csv'
    expected_num_del_objects = {   'ScheduleConstant' => 2, 'WaterHeaterMixed' => 1 }
    expected_num_new_objects = { 'ScheduleFixedInterval' => 2, 'WaterHeaterMixed' => 1 }
    expected_values = { 'TankVolume' => 40, 'InputCapacity' => 11.72, 'ThermalEfficiency' => 0.773, 'TankUA' => 7.88, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => 0.64 }
    _test_measure('SFD_Successful_EnergyPlus_Run_TMY_February.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_argument_error_tank_volume_invalid_str
    args_hash = {}
    args_hash['tank_volume'] = 'test'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Storage tank volume must be greater than 0.')
  end

  def test_argument_error_tank_volume_lt_0
    args_hash = {}
    args_hash['tank_volume'] = '-10'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Storage tank volume must be greater than 0.')
  end

  def test_argument_error_tank_volume_eq_0
    args_hash = {}
    args_hash['tank_volume'] = '0'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Storage tank volume must be greater than 0.')
  end

  def test_argument_error_setpoint_lt_0
    args_hash = {}
    args_hash['setpoint_temp'] = -10
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Water heater temperature setpoint must not be less than 0F or greater than 212F.')
  end

  def test_argument_warning_setpoint_lt_110
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeConstant
    args_hash['setpoint_temp'] = 100
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1, 1)
  end

  def test_argument_error_setpoint_gt_300
    args_hash = {}
    args_hash['setpoint_temp'] = 300
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Water heater temperature setpoint must not be less than 0F or greater than 212F.')
  end

  def test_argument_warning_setpoint_gt_140
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = '0.95'
    args_hash['capacity'] = '18.77'
    args_hash['tank_model_type'] = 'stratified'
    args_hash['setpoint_type'] = Constants.WaterHeaterSetpointTypeConstant
    args_hash['setpoint_temp'] = 150
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterStratified' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'TankVolume' => 50, 'InputCapacity' => 5.5, 'ThermalEfficiency' => 1.0, 'TankUA' => 0.124, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric, 'SkinLossFrac' => 1.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1, 1)
  end

  def test_argument_error_capacity_invalid_str
    args_hash = {}
    args_hash['capacity'] = 'test'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Nominal capacity must be greater than 0.')
  end

  def test_argument_error_capacity_lt_0
    args_hash = {}
    args_hash['capacity'] = '-10'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Nominal capacity must be greater than 0.')
  end

  def test_argument_error_capacity_eq_0
    args_hash = {}
    args_hash['capacity'] = '0'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Nominal capacity must be greater than 0.')
  end

  def test_argument_error_re_lt_0
    args_hash = {}
    args_hash['recovery_efficiency'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Recovery efficiency must be at least 0 and at most 1.')
  end

  def test_argument_error_re_gt_1
    args_hash = {}
    args_hash['recovery_efficiency'] = 1.1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Recovery efficiency must be at least 0 and at most 1.')
  end

  def test_argument_error_ef_invalid_str
    args_hash = {}
    args_hash['energy_factor'] = 'test'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Rated energy factor must be greater than 0 and less than 1.')
  end

  def test_argument_error_ef_lt_0
    args_hash = {}
    args_hash['energy_factor'] = '-10'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Rated energy factor must be greater than 0 and less than 1.')
  end

  def test_argument_error_ef_eq_0
    args_hash = {}
    args_hash['energy_factor'] = '0'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Rated energy factor must be greater than 0 and less than 1.')
  end

  def test_argument_error_ef_gt_1
    args_hash = {}
    args_hash['energy_factor'] = '1.1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Rated energy factor must be greater than 0 and less than 1.')
  end

  def test_argument_error_oncycle_lt_0
    args_hash = {}
    args_hash['oncyc_power'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Forced draft fan power must be greater than 0.')
  end

  def test_argument_error_offcycle_lt_0
    args_hash = {}
    args_hash['offcyc_power'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Parasitic electricity power must be greater than 0.')
  end

  def test_error_missing_geometry
    args_hash = {}
    result = _test_error(nil, args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'No building geometry has been defined.')
  end

  def test_error_missing_mains_temp
    args_hash = {}
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Mains water temperature has not been set.')
  end

  def test_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => num_units, 'PlantLoop' => num_units, 'PumpVariableSpeed' => num_units, 'ScheduleConstant' => 2 * num_units }
    expected_values = { 'TankVolume' => num_units * 40, 'InputCapacity' => num_units * 11.72, 'ThermalEfficiency' => num_units * 0.773, 'TankUA' => num_units * 7.88, 'Setpoint' => num_units * 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => num_units * 0.64 }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units)
  end

  def test_single_family_attached_new_construction_living_zone
    num_units = 1
    args_hash = {}
    args_hash['location'] = Constants.SpaceTypeLiving
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => num_units, 'PlantLoop' => num_units, 'PumpVariableSpeed' => num_units, 'ScheduleConstant' => 2 * num_units }
    expected_values = { 'TankVolume' => num_units * 40, 'InputCapacity' => num_units * 11.72, 'ThermalEfficiency' => num_units * 0.773, 'TankUA' => num_units * 7.88, 'Setpoint' => num_units * 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => num_units * 0.64 }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units)
  end

  def test_multifamily_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => num_units, 'PlantLoop' => num_units, 'PumpVariableSpeed' => num_units, 'ScheduleConstant' => 2 * num_units }
    expected_values = { 'TankVolume' => num_units * 40, 'InputCapacity' => num_units * 11.72, 'ThermalEfficiency' => num_units * 0.773, 'TankUA' => num_units * 7.88, 'Setpoint' => num_units * 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeGas, 'SkinLossFrac' => num_units * 0.64 }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units)
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ResidentialHotWaterHeaterTank.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    model = get_model(File.dirname(__FILE__), osm_file)

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

    # show the output
    show_output(result) unless result.value.valueName == 'Fail'

    # assert that it didn't run
    assert_equal('Fail', result.value.valueName)
    assert(result.errors.size == 1)

    return result
  end

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_infos = 0, num_warnings = 0)
    # create an instance of the measure
    measure = ResidentialHotWaterHeaterTank.new

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

    # show the output
    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert_equal(num_infos, result.info.size)
    assert_equal(num_warnings, result.warnings.size)
    assert(result.finalCondition.is_initialized)

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = ['ConnectorMixer', 'ConnectorSplitter', 'Node', 'SetpointManagerScheduled', 'ScheduleDay', 'PipeAdiabatic', 'ScheduleTypeLimits', 'SizingPlant', 'AvailabilityManagerAssignmentList']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    actual_values = { 'TankVolume' => 0, 'InputCapacity' => 0, 'ThermalEfficiency' => 0, 'TankUA1' => 0, 'TankUA2' => 0, 'Setpoint' => 0, 'OnCycle' => 0, 'OffCycle' => 0, 'SkinLossFrac' => 0, 'StorageTankSetpoint1' => 0, 'StorageTankSetpoint2' => 0 }
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        next unless (obj_type == 'WaterHeaterMixed') || (obj_type == 'WaterHeaterStratified')
        actual_values['TankVolume'] += UnitConversions.convert(new_object.tankVolume.get, 'm^3', 'gal')
        if obj_type == 'WaterHeaterMixed'
          actual_values['InputCapacity'] += UnitConversions.convert(new_object.heaterMaximumCapacity.get, 'W', 'kW')
          actual_values['ThermalEfficiency'] += new_object.heaterThermalEfficiency.get
          actual_values['TankUA1'] += UnitConversions.convert(new_object.onCycleLossCoefficienttoAmbientTemperature.get, 'W/K', 'Btu/(hr*F)')
          actual_values['TankUA2'] += UnitConversions.convert(new_object.offCycleLossCoefficienttoAmbientTemperature.get, 'W/K', 'Btu/(hr*F)')
          actual_values['Setpoint'] += Waterheater.get_water_heater_setpoint(model, new_object.plantLoop.get, nil)
          assert_equal(HelperMethods.eplus_fuel_map(expected_values['FuelType']), new_object.heaterFuelType)
          actual_values['SkinLossFrac'] += new_object.offCycleLossFractiontoThermalZone
        else # Stratified tank
          actual_values['InputCapacity'] += UnitConversions.convert(new_object.heater1Capacity.get, 'W', 'kW')
          actual_values['ThermalEfficiency'] += new_object.heaterThermalEfficiency.to_f
          actual_values['TankUA1'] += UnitConversions.convert(new_object.uniformSkinLossCoefficientperUnitAreatoAmbientTemperature.to_f, 'W/K', 'Btu/(hr*F)')
          actual_values['TankUA2'] += UnitConversions.convert(new_object.uniformSkinLossCoefficientperUnitAreatoAmbientTemperature.to_f, 'W/K', 'Btu/(hr*F)')
          actual_values['SkinLossFrac'] += new_object.skinLossFractiontoZone.to_f
          if defined? new_object.heater1SetpointTemperatureSchedule.to_ScheduleConstant.get.value
            actual_values['Setpoint'] += UnitConversions.convert(new_object.heater1SetpointTemperatureSchedule.to_ScheduleConstant.get.value, 'C', 'F')
          end
        end
        actual_values['OnCycle'] += new_object.onCycleParasiticFuelConsumptionRate
        actual_values['OffCycle'] += new_object.offCycleParasiticFuelConsumptionRate
        next unless new_object.supplyInletModelObject.is_initialized
        inlet_object = new_object.supplyInletModelObject.get.connectedObject(new_object.supplyInletModelObject.get.to_Node.get.inletPort).get
        next unless inlet_object.to_WaterHeaterStratified.is_initialized
        storage_tank = inlet_object.to_WaterHeaterStratified.get
        set_type = runner.getStringArgumentValue('setpoint_type', argument_map)
        if set_type == Constants.WaterHeaterSetpointTypeConstant
          setpoint_schedule_one = storage_tank.heater1SetpointTemperatureSchedule.to_ScheduleConstant.get
          setpoint_schedule_two = storage_tank.heater2SetpointTemperatureSchedule.to_ScheduleConstant.get
          actual_values['StorageTankSetpoint1'] += UnitConversions.convert(setpoint_schedule_one.value, 'C', 'F')
          actual_values['StorageTankSetpoint2'] += UnitConversions.convert(setpoint_schedule_two.value, 'C', 'F')
        elsif set_type == Constants.WaterHeaterSetpointTypeScheduled
          setpoint_schedule_one = storage_tank.heater1SetpointTemperatureSchedule
          setpoint_schedule_two = storage_tank.heater2SetpointTemperatureSchedule
          actual_values['StorageTankSetpoint1'] += UnitConversions.convert(setpoint_schedule_one.to_ScheduleFixedInterval.get.timeSeries.averageValue, 'C', 'F')
          actual_values['StorageTankSetpoint2'] += UnitConversions.convert(setpoint_schedule_two.to_ScheduleFixedInterval.get.timeSeries.averageValue, 'C', 'F')
        end
      end
    end
    assert_in_epsilon(Waterheater.calc_actual_tankvol(expected_values['TankVolume'], args_hash['fuel_type'], Constants.WaterHeaterTypeTank), actual_values['TankVolume'], 0.01)
    assert_in_epsilon(expected_values['InputCapacity'], actual_values['InputCapacity'], 0.01)
    assert_in_epsilon(expected_values['ThermalEfficiency'], actual_values['ThermalEfficiency'], 0.01)
    assert_in_epsilon(expected_values['TankUA'], actual_values['TankUA1'], 0.01)
    assert_in_epsilon(expected_values['TankUA'], actual_values['TankUA2'], 0.01)
    if not expected_values['Setpoint'].nil?
      assert_in_epsilon(expected_values['Setpoint'], actual_values['Setpoint'], 0.01)
    end
    assert_in_epsilon(expected_values['OnCycle'], actual_values['OnCycle'], 0.01)
    assert_in_epsilon(expected_values['OffCycle'], actual_values['OffCycle'], 0.01)
    assert_in_epsilon(expected_values['SkinLossFrac'], actual_values['SkinLossFrac'], 0.01)
    if (not expected_values['StorageTankSetpoint1'].nil?) && (not expected_values['StorageTankSetpoint2'].nil?)
      assert_in_epsilon(expected_values['StorageTankSetpoint1'], actual_values['StorageTankSetpoint1'], 0.01)
      assert_in_epsilon(expected_values['StorageTankSetpoint2'], actual_values['StorageTankSetpoint2'], 0.01)
    end

    return model
  end
end
