# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessConstructionsDoorsTest < MiniTest::Test
  def test_retrofit_replace
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 1, 'Construction' => 1 }
    door_r = 0.04445 / 0.0612266553480475
    expected_values = { 'DoorR' => door_r }
    model = _test_measure('SFD_2000sqft_2story_SL_GRG_UA_Windows_Doors.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units + 2)
    args_hash = {}
    args_hash['ufactor'] = 0.48
    expected_num_del_objects = { 'Material' => 1, 'Construction' => 1 }
    expected_num_new_objects = { 'Material' => 1, 'Construction' => 1 }
    door_r = 0.04445 / 0.2092601547388782
    expected_values = { 'DoorR' => door_r }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units + 2 + 2)
  end

  def test_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 1, 'Construction' => 1 }
    door_r = 0.04445 / 0.0612266553480475
    expected_values = { 'DoorR' => door_r }
    _test_measure('SFA_4units_1story_SL_UA_Denver_Windows_Doors.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units + 2)
  end

  def test_multifamily_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 1, 'Construction' => 1 }
    door_r = 0.04445 / 0.0612266553480475
    expected_values = { 'DoorR' => door_r }
    _test_measure('MF_8units_1story_SL_Denver_Windows_Doors.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units + 2)
  end

  def test_argument_error_invalid_ufactor
    args_hash = {}
    args_hash['ufactor'] = 0
    result = _test_error('SFD_2000sqft_2story_SL_GRG_UA_Windows_Doors.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Door U-Factor must be greater than 0.')
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ProcessConstructionsDoors.new

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

    return result
  end

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_infos = 0)
    # create an instance of the measure
    measure = ProcessConstructionsDoors.new

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

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = ['ScheduleRule', 'ScheduleDay', 'ScheduleTypeLimits']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    actual_values = { 'DoorR' => 0 }
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        if obj_type == 'Material'
          new_object = new_object.to_StandardOpaqueMaterial.get
          actual_values['DoorR'] += new_object.thickness / new_object.conductivity
        end
      end
    end
    assert_in_epsilon(expected_values['DoorR'], actual_values['DoorR'], 0.01)

    return model
  end
end
