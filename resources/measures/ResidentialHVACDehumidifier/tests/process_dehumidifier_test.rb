require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessDehumidifierTest < MiniTest::Test
  def autosize
    return Constants.small
  end

  def test_argument_error_relative_humidity_percent
    args_hash = {}
    args_hash['humidity_setpoint'] = 60.0
    result = _test_error('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid humidity setpoint value entered.')
  end

  def test_argument_error_water_removal_rate_negative
    args_hash = {}
    args_hash['water_removal_rate'] = '-20'
    result = _test_error('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid water removal rate value entered.')
  end

  def test_argument_error_energy_factor_negative
    args_hash = {}
    args_hash['energy_factor'] = '-1.2'
    result = _test_error('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid energy factor value entered.')
  end

  def test_water_removal_rate_35
    args_hash = {}
    args_hash['water_removal_rate'] = '35'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 2, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => UnitConversions.convert(args_hash['water_removal_rate'].to_f, 'pint', 'L'), 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_water_removal_rate_high
    args_hash = {}
    args_hash['water_removal_rate'] = '200'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 2, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => UnitConversions.convert(args_hash['water_removal_rate'].to_f, 'pint', 'L'), 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_air_flow_rate_hardsized
    args_hash = {}
    args_hash['air_flow_rate'] = '88.0'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 2, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => UnitConversions.convert(args_hash['air_flow_rate'].to_f, 'cfm', 'm^3/s') }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace
    args_hash = {}
    args_hash['energy_factor'] = '1.2'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 2, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => args_hash['energy_factor'].to_f, 'air_flow_rate' => autosize }
    model = _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
    args_hash['energy_factor'] = '1.5'
    expected_num_del_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => args_hash['energy_factor'].to_f, 'air_flow_rate' => autosize }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 2)
  end

  def test_retrofit_replace_ashp
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_ASHP.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_ashp2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_ASHP2.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_central_air_conditioner
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_central_air_conditioner2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_CentralAC2.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_room_air_conditioner
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_RoomAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_electric_baseboard
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_ElectricBaseboard.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_boiler
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Boiler.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_unit_heater
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_UnitHeater.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_mshp
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_MSHP.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_furnace_central_air_conditioner
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_furnace_central_air_conditioner2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Furnace_CentralAC2.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_furnace_room_air_conditioner
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Furnace_RoomAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_electric_baseboard_central_air_conditioner
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_ElectricBaseboard_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_boiler_central_air_conditioner
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Boiler_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_unit_heater_central_air_conditioner
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_UnitHeater_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_electric_baseboard_room_air_conditioner
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_ElectricBaseboard_RoomAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_boiler_room_air_conditioner
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_Boiler_RoomAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_unit_heater_room_air_conditioner
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_UnitHeater_RoomAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_gshp_vert_bore
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1, 'ZoneHVACDehumidifierDX' => 1, 'ZoneControlHumidistat' => 1 }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFD_2000sqft_2story_FB_UA_Denver_GSHPVertBore.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => num_units + 1, 'ZoneHVACDehumidifierDX' => num_units, 'ZoneControlHumidistat' => num_units }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('SFA_4units_1story_FB_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units)
  end

  def test_multifamily_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => num_units + 1, 'ZoneHVACDehumidifierDX' => num_units, 'ZoneControlHumidistat' => num_units }
    expected_values = { 'water_removal_rate' => autosize, 'energy_factor' => autosize, 'air_flow_rate' => autosize }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units)
  end

  private

  def _test_error(osm_file_or_model, args_hash)
    # create an instance of the measure
    measure = ProcessDehumidifier.new

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
    measure = ProcessDehumidifier.new

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
    assert_equal(num_infos, result.info.size)
    assert_equal(num_warnings, result.warnings.size)

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = ['Node', 'ScheduleTypeLimits', 'CurveBiquadratic', 'CurveQuadratic']
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
        next unless obj_type == 'ZoneHVACDehumidifierDX'

        assert_in_epsilon(expected_values['water_removal_rate'], new_object.ratedWaterRemoval, 0.01)
        assert_in_epsilon(expected_values['energy_factor'], new_object.ratedEnergyFactor, 0.01)
        assert_in_epsilon(expected_values['air_flow_rate'], new_object.ratedAirFlowRate, 0.01)
      end
    end

    return model
  end
end
