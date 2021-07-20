# frozen_string_literal: true

require_relative '../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ResidentialSimulationControlsTest < MiniTest::Test
  def test_error_timesteps_per_hr_out_of_range
    args_hash = {}
    args_hash['timesteps_per_hr'] = '0'
    result = _test_error_or_NA(nil, args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, "User-entered #{args_hash['timesteps_per_hr'].to_i} timesteps per hour must be between 1 and 60.")
  end

  def test_error_60_divisible_by_timesteps_per_hr
    args_hash = {}
    args_hash['timesteps_per_hr'] = '8'
    result = _test_error_or_NA(nil, args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, "User-entered #{args_hash['timesteps_per_hr'].to_i} timesteps per hour does not divide evenly into 60.")
  end

  def test_simulation_timestep
    args_hash = {}
    args_hash['timesteps_per_hr'] = '4'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SimulationControl' => 1, 'Timestep' => 1, 'ShadowCalculation' => 1, 'ZoneCapacitanceMultiplierResearchSpecial' => 1, 'RunPeriod' => 1 }
    expected_values = { 'TimestepsPerHour' => args_hash['timesteps_per_hr'].to_i, 'BeginMonth' => 1, 'BeginDayOfMonth' => 1, 'EndMonth' => 12, 'EndDayOfMonth' => 31, 'StartDayOfWeek' => 'Monday' }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_error_bad_begin_month
    args_hash = {}
    args_hash['begin_month'] = '0'
    result = _test_error_or_NA(nil, args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, "Invalid begin month (#{args_hash['begin_month'].to_i}) and/or end month (12) entered.")
  end

  def test_error_bad_end_day_of_month
    args_hash = {}
    args_hash['end_day_of_month'] = '32'
    result = _test_error_or_NA(nil, args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, "Invalid end day of month (#{args_hash['end_day_of_month'].to_i}) entered.")
  end

  def test_runperiod_begin_and_end
    args_hash = {}
    args_hash['begin_month'] = '3'
    args_hash['end_month'] = '3'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SimulationControl' => 1, 'Timestep' => 1, 'ShadowCalculation' => 1, 'ZoneCapacitanceMultiplierResearchSpecial' => 1, 'RunPeriod' => 1 }
    expected_values = { 'TimestepsPerHour' => 6, 'BeginMonth' => args_hash['begin_month'].to_i, 'BeginDayOfMonth' => 1, 'EndMonth' => args_hash['end_month'].to_i, 'EndDayOfMonth' => 31, 'StartDayOfWeek' => 'Monday' }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_error_bad_calendar_year
    args_hash = {}
    args_hash['calendar_year'] = '209'
    result = _test_error_or_NA(nil, args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, "Your calendar year value of #{args_hash['calendar_year']} is not in the range 1600-9999.")
  end

  def test_calendar_year_nondefault
    args_hash = {}
    args_hash['calendar_year'] = '2006'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SimulationControl' => 1, 'Timestep' => 1, 'ShadowCalculation' => 1, 'ZoneCapacitanceMultiplierResearchSpecial' => 1, 'RunPeriod' => 1 }
    expected_values = { 'TimestepsPerHour' => 6, 'BeginMonth' => 1, 'BeginDayOfMonth' => 1, 'EndMonth' => 12, 'EndDayOfMonth' => 31, 'StartDayOfWeek' => 'Sunday' }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  private

  def _test_error_or_NA(osm_file_or_model, args_hash)
    # create an instance of the measure
    measure = ResidentialSimulationControls.new

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

    return result
  end

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_infos = 0, num_warnings = 0, debug = false)
    # create an instance of the measure
    measure = ResidentialSimulationControls.new

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

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = []
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        if obj_type == 'Timestep'
          assert_in_epsilon(expected_values['TimestepsPerHour'], new_object.numberOfTimestepsPerHour, 0.01)
        elsif obj_type == 'RunPeriod'
          assert_in_epsilon(expected_values['BeginMonth'], new_object.getBeginMonth, 0.01)
          assert_in_epsilon(expected_values['BeginDayOfMonth'], new_object.getBeginDayOfMonth, 0.01)
          assert_in_epsilon(expected_values['EndMonth'], new_object.getEndMonth, 0.01)
          assert_in_epsilon(expected_values['EndDayOfMonth'], new_object.getEndDayOfMonth, 0.01)
        end
      end
    end

    assert_equal(expected_values['StartDayOfWeek'], model.getYearDescription.dayofWeekforStartDay)

    return model
  end
end
