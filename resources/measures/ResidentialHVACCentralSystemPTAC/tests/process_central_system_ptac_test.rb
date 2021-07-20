# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessCentralSystemPTACTest < MiniTest::Test
  def test_single_family_detached_unfinshed_zone
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => 1, 'CoilHeatingWater' => 1, 'FanOnOff' => 1, 'CoilCoolingDXSingleSpeed' => 1, 'ZoneHVACPackagedTerminalAirConditioner' => 1, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFD_2000sqft_2story_UB_UA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, 2)
  end

  def test_single_family_attached_ptac
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => 2 * num_units, 'CoilHeatingWater' => 2 * num_units, 'FanOnOff' => 2 * num_units, 'CoilCoolingDXSingleSpeed' => 2 * num_units, 'ZoneHVACPackagedTerminalAirConditioner' => 2 * num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 2 + 1)
  end

  def test_multifamily_ptac
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units + 1)
  end

  def test_retrofit_replace_central_system_ptac
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Central_System_PTAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 2 + 2)
  end

  def test_retrofit_replace_central_system_boiler_baseboards
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'CoilHeatingWaterBaseboard' => num_units, 'ZoneHVACBaseboardConvectiveWater' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Central_System_Boiler_Baseboards.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 2 + 2)
  end

  def test_retrofit_replace_central_system_fan_coil
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'PlantLoop' => 2, 'PumpVariableSpeed' => 2, 'BoilerHotWater' => 1, 'ChillerElectricEIR' => 1, 'ControllerWaterCoil' => 2 * num_units, 'CoilCoolingWater' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'ZoneHVACFourPipeFanCoil' => num_units, 'SetpointManagerScheduled' => 2, 'EnergyManagementSystemSensor' => 2, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemOutputVariable' => 2, 'EnergyManagementSystemProgramCallingManager' => 2 }
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Central_System_Fan_Coil.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 2 + 3)
  end

  def test_retrofit_replace_furnace
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'AirLoopHVACUnitarySystem' => num_units, 'AirLoopHVAC' => num_units, 'CoilHeatingGas' => num_units, 'FanOnOff' => num_units, 'AirTerminalSingleDuctConstantVolumeNoReheat' => num_units }
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Furnace.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 3 + 1)
  end

  def test_retrofit_replace_central_air_conditioner
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'AirLoopHVACUnitarySystem' => num_units, 'AirLoopHVAC' => num_units, 'FanOnOff' => num_units, 'AirTerminalSingleDuctConstantVolumeNoReheat' => num_units, 'CoilCoolingDXSingleSpeed' => num_units }
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 3 + 1)
  end

  def test_retrofit_replace_electric_baseboard
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'ZoneHVACBaseboardConvectiveElectric' => num_units }
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_ElectricBaseboard.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 2 + 1)
  end

  def test_retrofit_replace_ashp
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'AirLoopHVACUnitarySystem' => num_units * 2, 'AirLoopHVAC' => num_units * 2, 'CoilHeatingElectric' => num_units, 'FanOnOff' => num_units * 2, 'AirTerminalSingleDuctConstantVolumeNoReheat' => num_units * 2, 'CoilHeatingDXSingleSpeed' => num_units, 'CoilCoolingDXSingleSpeed' => num_units }
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_ASHP.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 5 + 1)
  end

  def test_retrofit_replace_mshp
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'AirLoopHVACUnitarySystem' => num_units * 2, 'AirLoopHVAC' => num_units * 2, 'CoilCoolingDXMultiSpeed' => num_units, 'FanOnOff' => num_units * 2, 'AirTerminalSingleDuctConstantVolumeNoReheat' => num_units * 2, 'CoilHeatingElectric' => num_units, 'CoilHeatingDXMultiSpeed' => num_units, 'CoilCoolingDXMultiSpeedStageData' => num_units * 4, 'CoilHeatingDXMultiSpeedStageData' => num_units * 4, 'UnitarySystemPerformanceMultispeed' => num_units * 2, 'EnergyManagementSystemSensor' => num_units * 2, 'EnergyManagementSystemActuator' => num_units * 1, 'EnergyManagementSystemProgram' => num_units * 1, 'EnergyManagementSystemProgramCallingManager' => num_units * 1, 'ElectricEquipment' => num_units * 1, 'ElectricEquipmentDefinition' => num_units * 1 }
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_MSHP.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 5 + 1)
  end

  def test_retrofit_replace_boiler
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'PlantLoop' => num_units, 'BoilerHotWater' => num_units, 'CoilHeatingWaterBaseboard' => num_units, 'PumpVariableSpeed' => num_units, 'ZoneHVACBaseboardConvectiveWater' => num_units, 'SetpointManagerScheduled' => num_units, 'EnergyManagementSystemSensor' => num_units, 'EnergyManagementSystemProgram' => num_units, 'EnergyManagementSystemOutputVariable' => num_units, 'EnergyManagementSystemProgramCallingManager' => num_units }
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Boiler.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 3 + 1)
  end

  def test_retrofit_replace_unit_heater
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'CoilHeatingGas' => num_units, 'AirLoopHVACUnitarySystem' => num_units, 'FanOnOff' => num_units }
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_UnitHeater.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 2 + 1)
  end

  def test_retrofit_replace_room_air_conditioner
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'CoilHeatingElectric' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units }
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_RoomAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 2 + 1)
  end

  def test_retrofit_replace_gshp_vert_bore
    num_units = 1
    args_hash = {}
    expected_num_del_objects = { 'SetpointManagerFollowGroundTemperature' => num_units * 1, 'GroundHeatExchangerVertical' => num_units * 1, 'FanOnOff' => num_units * 2, 'CoilHeatingWaterToAirHeatPumpEquationFit' => num_units, 'CoilCoolingWaterToAirHeatPumpEquationFit' => num_units, 'PumpVariableSpeed' => num_units * 1, 'CoilHeatingElectric' => num_units, 'PlantLoop' => num_units * 1, 'AirTerminalSingleDuctConstantVolumeNoReheat' => num_units * 2, 'AirLoopHVACUnitarySystem' => num_units * 2, 'AirLoopHVAC' => num_units * 2, 'EnergyManagementSystemSensor' => num_units * 3, 'EnergyManagementSystemProgram' => num_units, 'EnergyManagementSystemOutputVariable' => num_units * 2, 'EnergyManagementSystemProgramCallingManager' => num_units * 1 }
    expected_num_new_objects = { 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'BoilerHotWater' => 1, 'ControllerWaterCoil' => num_units, 'CoilHeatingWater' => num_units, 'FanOnOff' => num_units, 'CoilCoolingDXSingleSpeed' => num_units, 'ZoneHVACPackagedTerminalAirConditioner' => num_units, 'SetpointManagerScheduled' => 1, 'EnergyManagementSystemSensor' => 1, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemOutputVariable' => 1, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_values = {}
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_GSHPVertBore.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, num_units * 6 + 1)
  end

  private

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, test_name, num_infos = 0, num_warnings = 0, debug = false)
    # create an instance of the measure
    measure = ProcessCentralSystemPTAC.new

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
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    show_output(result) unless result.value.valueName == 'Success'

    # save the model to test output directory
    # output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/#{test_name}.osm")
    # model.save(output_file_path, true)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert_equal(num_infos, result.info.size)
    assert_equal(num_warnings, result.warnings.size)

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = ['CurveBicubic', 'CurveQuadratic', 'CurveBiquadratic', 'CurveExponent', 'CurveCubic', 'CurveQuadLinear', 'CurveQuintLinear', \
                           'PipeAdiabatic', 'ScheduleTypeLimits', 'ScheduleDay',\
                           'AvailabilityManagerAssignmentList', 'ConnectorMixer', 'ConnectorSplitter', 'Node', 'SizingPlant', 'ScheduleConstant',\
                           'PlantComponentTemperatureSource', 'SizingSystem', 'AirLoopHVACZoneSplitter', 'AirLoopHVACZoneMixer', 'ModelObjectList',\
                           'ScheduleRuleset', 'CoilCoolingDXVariableSpeedSpeedData', 'AvailabilityManagerNightCycle']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
      end
    end

    return model
  end
end
