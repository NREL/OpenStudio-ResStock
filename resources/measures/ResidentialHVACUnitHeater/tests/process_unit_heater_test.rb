# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessUnitHeaterTest < MiniTest::Test
  def test_new_construction_eff_0_78_gas_fan
    args_hash = {}
    args_hash['fan_power'] = '0.7'
    args_hash['airflow_rate'] = '65.0'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 1, 'CoilHeatingGas' => 1, 'FanOnOff' => 1 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 2)
  end

  def test_new_construction_eff_0_78_wood_nofan_finished_basement
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeWood
    expected_num_del_objects = {}
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeWood }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 4)
  end

  def test_retrofit_replace_furnace
    args_hash = {}
    expected_num_del_objects = { 'AirLoopHVACUnitarySystem' => 1, 'AirLoopHVAC' => 1, 'CoilHeatingGas' => 1, 'FanOnOff' => 1, 'AirTerminalSingleDuctConstantVolumeNoReheat' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Furnace.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
  end

  def test_retrofit_replace_ashp
    args_hash = {}
    expected_num_del_objects = { 'AirLoopHVACUnitarySystem' => 2, 'AirLoopHVAC' => 2, 'CoilHeatingElectric' => 1, 'FanOnOff' => 2, 'AirTerminalSingleDuctConstantVolumeNoReheat' => 4, 'CoilHeatingDXSingleSpeed' => 1, 'CoilCoolingDXSingleSpeed' => 1 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_ASHP.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 8)
  end

  def test_retrofit_replace_ashp2
    args_hash = {}
    expected_num_del_objects = { 'AirLoopHVACUnitarySystem' => 2, 'AirLoopHVAC' => 2, 'CoilHeatingElectric' => 1, 'FanOnOff' => 2, 'AirTerminalSingleDuctConstantVolumeNoReheat' => 4, 'CoilHeatingDXMultiSpeed' => 1, 'CoilHeatingDXMultiSpeedStageData' => 2, 'CoilCoolingDXMultiSpeed' => 1, 'CoilCoolingDXMultiSpeedStageData' => 2, 'UnitarySystemPerformanceMultispeed' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_ASHP2.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 8)
  end

  def test_retrofit_replace_central_air_conditioner
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 4)
  end

  def test_retrofit_replace_central_air_conditioner2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_CentralAC2.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 4)
  end

  def test_retrofit_replace_room_air_conditioner
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_RoomAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 4)
  end

  def test_retrofit_replace_electric_baseboard
    args_hash = {}
    expected_num_del_objects = { 'ZoneHVACBaseboardConvectiveElectric' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_ElectricBaseboard.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
  end

  def test_retrofit_replace_boiler
    args_hash = {}
    expected_num_del_objects = { 'PlantLoop' => 1, 'BoilerHotWater' => 1, 'CoilHeatingWaterBaseboard' => 2, 'PumpVariableSpeed' => 1, 'ZoneHVACBaseboardConvectiveWater' => 2, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Boiler.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 7)
  end

  def test_retrofit_replace_unit_heater
    args_hash = {}
    expected_num_del_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_UnitHeater.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
  end

  def test_retrofit_replace_mshp
    args_hash = {}
    expected_num_del_objects = { 'AirLoopHVACUnitarySystem' => 2, 'AirLoopHVAC' => 2, 'CoilCoolingDXMultiSpeed' => 1, 'FanOnOff' => 2, 'AirTerminalSingleDuctConstantVolumeNoReheat' => 4, 'CoilHeatingElectric' => 1, 'CoilHeatingDXMultiSpeed' => 1, 'CoilCoolingDXMultiSpeedStageData' => 4, 'CoilHeatingDXMultiSpeedStageData' => 4, 'UnitarySystemPerformanceMultispeed' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_MSHP.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 8)
  end

  def test_retrofit_replace_furnace_central_air_conditioner
    args_hash = {}
    expected_num_del_objects = { 'CoilHeatingGas' => 1, 'AirLoopHVAC' => 1, 'AirLoopHVACUnitarySystem' => 1, 'FanOnOff' => 1, 'AirTerminalSingleDuctConstantVolumeNoReheat' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
  end

  def test_retrofit_replace_furnace_central_air_conditioner2
    args_hash = {}
    expected_num_del_objects = { 'CoilHeatingGas' => 1, 'AirLoopHVAC' => 1, 'AirLoopHVACUnitarySystem' => 1, 'FanOnOff' => 1, 'AirTerminalSingleDuctConstantVolumeNoReheat' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Furnace_CentralAC2.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
  end

  def test_retrofit_replace_furnace_room_air_conditioner
    args_hash = {}
    expected_num_del_objects = { 'AirLoopHVACUnitarySystem' => 1, 'AirLoopHVAC' => 1, 'CoilHeatingGas' => 1, 'FanOnOff' => 1, 'AirTerminalSingleDuctConstantVolumeNoReheat' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Furnace_RoomAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
  end

  def test_retrofit_replace_electric_baseboard_central_air_conditioner
    args_hash = {}
    expected_num_del_objects = { 'ZoneHVACBaseboardConvectiveElectric' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_ElectricBaseboard_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
  end

  def test_retrofit_replace_boiler_central_air_conditioner
    args_hash = {}
    expected_num_del_objects = { 'PlantLoop' => 1, 'BoilerHotWater' => 1, 'CoilHeatingWaterBaseboard' => 2, 'PumpVariableSpeed' => 1, 'ZoneHVACBaseboardConvectiveWater' => 2, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Boiler_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 7)
  end

  def test_retrofit_replace_unit_heater_central_air_conditioner
    args_hash = {}
    expected_num_del_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_UnitHeater_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
  end

  def test_retrofit_replace_electric_baseboard_room_air_conditioner
    args_hash = {}
    expected_num_del_objects = { 'ZoneHVACBaseboardConvectiveElectric' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_ElectricBaseboard_RoomAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
  end

  def test_retrofit_replace_boiler_room_air_conditioner
    args_hash = {}
    expected_num_del_objects = { 'PlantLoop' => 1, 'BoilerHotWater' => 1, 'CoilHeatingWaterBaseboard' => 2, 'PumpVariableSpeed' => 1, 'ZoneHVACBaseboardConvectiveWater' => 2, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Boiler_RoomAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 7)
  end

  def test_retrofit_replace_unit_heater_room_air_conditioner
    args_hash = {}
    expected_num_del_objects = { 'CoilHeatingGas' => 2, 'AirLoopHVACUnitarySystem' => 2, 'FanOnOff' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_UnitHeater_RoomAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
  end

  def test_retrofit_replace_gshp_vert_bore
    args_hash = {}
    expected_num_del_objects = { 'SetpointManagerFollowGroundTemperature' => 1, 'GroundHeatExchangerVertical' => 1, 'FanOnOff' => 2, 'CoilHeatingWaterToAirHeatPumpEquationFit' => 1, 'CoilCoolingWaterToAirHeatPumpEquationFit' => 1, 'PumpVariableSpeed' => 1, 'CoilHeatingElectric' => 1, 'PlantLoop' => 1, 'AirTerminalSingleDuctConstantVolumeNoReheat' => 4, 'AirLoopHVACUnitarySystem' => 2, 'AirLoopHVAC' => 2, 'EnergyManagementSystemSensor' => 3, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 2, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => 2, 'CoilHeatingGas' => 2, 'FanOnOff' => 2 }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_GSHPVertBore.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 9)
  end

  def test_retrofit_replace_central_system_boiler_baseboards
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'CoilHeatingWaterBaseboard' => num_units, 'ZoneHVACBaseboardConvectiveWater' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => num_units, 'CoilHeatingGas' => num_units, 'FanOnOff' => num_units }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Central_System_Boiler_Baseboards.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units * 3 + 1)
  end

  def test_retrofit_replace_central_system_fan_coil
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'PlantLoop' => 2, 'PumpVariableSpeed' => 2, 'BoilerHotWater' => 1, 'ChillerElectricEIR' => 1, 'ControllerWaterCoil' => 2 * num_units, 'CoilCoolingWater' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'ZoneHVACFourPipeFanCoil' => num_units, 'SetpointManagerScheduled' => 2, 'EnergyManagementSystemSensor' => 2, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemOutputVariable' => 2, 'EnergyManagementSystemProgramCallingManager' => 2 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => num_units, 'CoilHeatingGas' => num_units, 'FanOnOff' => num_units }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Central_System_Fan_Coil.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units * 3 + 2)
  end

  def test_retrofit_replace_central_system_ptac
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => num_units, 'CoilHeatingGas' => num_units, 'FanOnOff' => num_units }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Central_System_PTAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units * 3 + 1)
  end

  def test_multifamily_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'AirLoopHVACUnitarySystem' => num_units, 'CoilHeatingGas' => num_units, 'FanOnOff' => num_units }
    expected_values = { 'Efficiency' => 0.78, 'MaximumSupplyAirTemperature' => 48.88, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units * 2)
  end

  def test_error_fan_power_without_airflow
    args_hash = {}
    args_hash['fan_power'] = '0.7'
    args_hash['airflow_rate'] = '0.0'
    result = _test_error('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'If Fan Power > 0, then Airflow Rate cannot be zero.')
  end

  private

  def _test_error(osm_file_or_model, args_hash)
    # create an instance of the measure
    measure = ProcessUnitHeater.new

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

    # show the output
    show_output(result) unless result.value.valueName == 'Fail'

    # assert that it didn't run
    assert_equal('Fail', result.value.valueName)
    assert(result.errors.size == 1)

    return result
  end

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_infos = 0, num_warnings = 0, debug = false)
    # create an instance of the measure
    measure = ProcessUnitHeater.new

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

    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert_equal(result.info.size, num_infos)
    assert_equal(result.warnings.size, num_warnings)

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = ['CurveBicubic', 'CurveCubic', 'CurveQuadLinear', 'CurveQuintLinear', 'CurveQuadratic', 'CurveBiquadratic', 'Node', 'AirLoopHVACZoneMixer', 'SizingSystem', 'AirLoopHVACZoneSplitter', 'ScheduleTypeLimits', 'CurveExponent', 'ScheduleConstant', 'SizingPlant', 'PipeAdiabatic', 'ConnectorSplitter', 'ModelObjectList', 'ConnectorMixer', 'AvailabilityManagerAssignmentList']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')
    check_hvac_priorities(model, Constants.ZoneHVACPriorityList)

    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        if obj_type == 'AirLoopHVACUnitarySystem'
          assert_in_epsilon(expected_values['MaximumSupplyAirTemperature'], new_object.maximumSupplyAirTemperature.get, 0.01)
        elsif obj_type == 'CoilHeatingGas'
          assert_in_epsilon(expected_values['Efficiency'], new_object.gasBurnerEfficiency, 0.01)
          assert_equal(HelperMethods.eplus_fuel_map(expected_values['FuelType']), new_object.fuelType)
          if new_object.nominalCapacity.is_initialized
            assert_in_epsilon(expected_values['NominalCapacity'], new_object.nominalCapacity.get, 0.01)
          end
        end
      end
    end

    return model
  end
end
