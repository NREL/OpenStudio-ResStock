# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class SetResidentialEPWFileTest < MiniTest::Test
  def test_error_invalid_weather_path
    args_hash = {}
    args_hash['weather_directory'] = './resuorces' # misspelled
    args_hash['weather_file_name'] = 'USA_CO_Denver_Intl_AP_725650_TMY3.epw'
    result = _test_error_or_NA(nil, args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, "'#{File.expand_path(File.join(File.dirname(__FILE__), '..', args_hash['weather_directory'], args_hash['weather_file_name']))}' does not exist or is not an .epw file.")
  end

  def test_error_invalid_daylight_saving
    args_hash = {}
    args_hash['dst_start_date'] = 'April 31'
    result = _test_error_or_NA(nil, args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid daylight saving date(s) specified.')
  end

  def test_NA_daylight_saving
    args_hash = {}
    args_hash['dst_start_date'] = 'NA'
    args_hash['dst_end_date'] = 'NA'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SiteGroundTemperatureDeep' => 1, 'SiteWaterMainsTemperature' => 1, 'WeatherFile' => 1, 'ClimateZones' => 1, 'Site' => 1 }
    expected_values = { 'HotWaterAnnualTemp' => 10.88, 'HotWaterMaxDiffTemp' => 23.15 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 5)
  end

  def test_change_daylight_saving
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SiteGroundTemperatureDeep' => 1, 'RunPeriodControlDaylightSavingTime' => 1, 'SiteWaterMainsTemperature' => 1, 'WeatherFile' => 1, 'ClimateZones' => 1, 'Site' => 1 }
    expected_values = { 'StartDate' => 'Mar-12', 'EndDate' => 'Nov-05', 'HotWaterAnnualTemp' => 10.88, 'HotWaterMaxDiffTemp' => 23.15 }
    model = _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 5)
    args_hash = {}
    args_hash['dst_start_date'] = 'April 8'
    args_hash['dst_end_date'] = 'October 27'
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'StartDate' => 'Apr-08', 'EndDate' => 'Oct-27', 'HotWaterAnnualTemp' => 10.88, 'HotWaterMaxDiffTemp' => 23.15 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 5)
  end

  private

  def _test_error_or_NA(osm_file_or_model, args_hash)
    # create an instance of the measure
    measure = SetResidentialEPWFile.new

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

    return result
  end

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_infos = 0, num_warnings = 0, debug = false)
    # create an instance of the measure
    measure = SetResidentialEPWFile.new

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
        if obj_type == 'RunPeriodControlDaylightSavingTime'
          assert(new_object.startDate.to_s.include?(expected_values['StartDate']))
          assert(new_object.endDate.to_s.include?(expected_values['EndDate']))
        elsif obj_type == 'SiteWaterMainsTemperature'
          assert_in_epsilon(expected_values['HotWaterAnnualTemp'], new_object.annualAverageOutdoorAirTemperature.get, 0.01)
          assert_in_epsilon(expected_values['HotWaterMaxDiffTemp'], new_object.maximumDifferenceInMonthlyAverageOutdoorAirTemperatures.get, 0.01)
        end
      end
    end

    return model
  end
end
