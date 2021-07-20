# frozen_string_literal: true

require_relative '../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ResilienceMetricsReportTest < MiniTest::Test
  def test_argument_error
    args_hash = {}
    args_hash['output_vars'] = 'Zone Mean Air Temperature, Zone Air Relative Humidity'
    args_hash['min_vals'] = '60, 5, 0'
    args_hash['max_vals'] = '80, 60, 0'
    result = _test_error(args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Number of output variable elements specified inconsistent with either number of minimum or maximum values.')
  end

  def test_resilience_metrics
    resilience_metrics = {
      # output_var=>[timeseries, min_val, max_val, hours_spent_below, hours_spent_above, ix_outage_start, ix_outage_end]
      'Zone Mean Air Temperature' => [[4.4] * 8760, 60, 80, 16, 0, 10, 25],
      'Zone Air Relative Humidity' => [[60] * 8760, 'NA', 60, nil, 0, 0, 24],
      'Wetbulb Globe Temperature' => [[32] * 8760, 'NA', 88, nil, 49, 24, 72]
    }
    _test_resilience_metrics(resilience_metrics)
  end

  def test_coast_times
    coast_times = {
      # output_var=>[timeseries, min_val, max_val, hours_until_below, hours_until_above, ix_outage_start, ix_outage_end]
      'Zone Mean Air Temperature' => [[-6.6] * 10 + [0] * 8750, 60, 80, 1, nil, 0, 24],
      'Zone Air Relative Humidity' => [[50] * 100 + [65] * 8660, 'NA', 60, nil, 21, 80, 120],
      'Wetbulb Globe Temperature' => [[29.4] * 5 + [32] * 8755, 'NA', 88, nil, 3, 3, 24]
    }
    _test_coast_times(coast_times)
  end

  def test_end_of_outage_vals
    end_of_outage_vals = {
      # output_var=>[timeseries, end_of_outage_val, ix_outage_end]
      'End Of Outage Indoor Drybulb Temperature' => [[29.4] * 50 + [32] * 8710, 90, 60]
    }
    _test_end_of_outage_vals(end_of_outage_vals)
  end

  def test_calc_maximum_during_outage_vals
    maximum_wetbulb_globe_temperature_during_outage_vals = {
      # output_var=>[timeseries, maximum_wetbulb_globe_temperature_during_outage_val, ix_outage_start, ix_outage_end]
      'Maximum Wetbulb Globe Temperature During Outage' => [[29.4] * 50 + [32] * 8710, 90, 40, 60]
    }
    _test_maximum_wetbulb_globe_temperature_during_outage_vals(maximum_wetbulb_globe_temperature_during_outage_vals)
  end

  def test_calc_minimum_during_outage_vals
    minimum_indoor_drybulb_temperature_during_outage_vals = {
      # output_var=>[timeseries, minimum_indoor_drybulb_temperature_during_outage_val, ix_outage_start, ix_outage_end]
      'Minimum Indoor Drybulb Temperature During Outage' => [[29.4] * 50 + [32] * 8710, 85, 40, 60]
    }
    _test_minimum_indoor_drybulb_temperature_during_outage_vals(minimum_indoor_drybulb_temperature_during_outage_vals)
  end

  def test_functionality
    measure = ResilienceMetricsReport.new
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {}
    _test_measure('SFD_Successful_EnergyPlus_Run_TMY_Outages.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__, 'USA_CO_Denver.Intl.AP.725650_TMY3.epw', '8760.csv', 11, 0, 5)
  end

  private

  def _test_resilience_metrics(resilience_metrics)
    # create an instance of the measure
    measure = ResilienceMetricsReport.new

    # Check for correct resilience metrics values
    resilience_metrics.each do |resilience_metric, resilience_metric_values|
      values, min_val, max_val, expected_hours_below, expected_hours_above, ix_outage_start, ix_outage_end = resilience_metric_values
      actual_hours_below, actual_hours_above = measure.calc_resilience_metric(resilience_metric, values, min_val, max_val, ix_outage_start, ix_outage_end)
      if expected_hours_below.nil?
        assert_nil(actual_hours_below)
      else
        assert_in_epsilon(expected_hours_below, actual_hours_below, 0.01)
      end
      if expected_hours_above.nil?
        assert_nil(actual_hours_above)
      else
        assert_in_epsilon(expected_hours_above, actual_hours_above, 0.01)
      end
    end
  end

  def _test_coast_times(coast_times)
    # create an instance of the measure
    measure = ResilienceMetricsReport.new

    # Check for correct resilience metrics values
    coast_times.each do |coast_time, coast_time_values|
      values, min_val, max_val, expected_hours_below, expected_hours_above, ix_outage_start, ix_outage_end = coast_time_values
      actual_hours_below, actual_hours_above = measure.calc_coast_time(coast_time, values, min_val, max_val, ix_outage_start, ix_outage_end)
      if expected_hours_below.nil?
        assert_nil(actual_hours_below)
      else
        assert_in_epsilon(expected_hours_below, actual_hours_below, 0.01)
      end
      if expected_hours_above.nil?
        assert_nil(actual_hours_above)
      else
        assert_in_epsilon(expected_hours_above, actual_hours_above, 0.01)
      end
    end
  end

  def _test_end_of_outage_vals(end_of_outage_vals)
    # create an instance of the measure
    measure = ResilienceMetricsReport.new

    # Check for correct resilience metrics values
    end_of_outage_vals.each do |end_of_outage_val, end_of_outage_val_values|
      values, expected_val, ix_outage_end = end_of_outage_val_values
      actual_val = measure.calc_end_of_outage_val(end_of_outage_val, values, ix_outage_end)
      assert_in_epsilon(expected_val, actual_val, 0.01)
    end
  end

  def _test_maximum_wetbulb_globe_temperature_during_outage_vals(maximum_wetbulb_globe_temperature_during_outage_vals)
    # create an instance of the measure
    measure = ResilienceMetricsReport.new

    # Check for correct resilience metrics values
    maximum_wetbulb_globe_temperature_during_outage_vals.each do |maximum_wetbulb_globe_temperature_during_outage_val, maximum_wetbulb_globe_temperature_during_outage_values|
      values, expected_val, ix_outage_start, ix_outage_end = maximum_wetbulb_globe_temperature_during_outage_values
      actual_val = measure.calc_maximum_during_outage_val(maximum_wetbulb_globe_temperature_during_outage_val, values, ix_outage_start, ix_outage_end)
      assert_in_epsilon(expected_val, actual_val, 0.01)
    end
  end

  def _test_minimum_indoor_drybulb_temperature_during_outage_vals(minimum_indoor_drybulb_temperature_during_outage_vals)
    # create an instance of the measure
    measure = ResilienceMetricsReport.new

    # Check for correct resilience metrics values
    minimum_indoor_drybulb_temperature_during_outage_vals.each do |minimum_indoor_drybulb_temperature_during_outage_val, minimum_indoor_drybulb_temperature_during_outage_values|
      values, expected_val, ix_outage_start, ix_outage_end = minimum_indoor_drybulb_temperature_during_outage_values
      actual_val = measure.calc_minimum_during_outage_val(minimum_indoor_drybulb_temperature_during_outage_val, values, ix_outage_start, ix_outage_end)
      assert_in_epsilon(expected_val, actual_val, 0.01)
    end
  end

  def _test_error(args_hash)
    # create an instance of the measure
    measure = ResilienceMetricsReport.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # get arguments
    arguments = measure.arguments
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
    measure.run(runner, argument_map)
    result = runner.result

    # show the output
    show_output(result) unless result.value.valueName == 'Fail'

    # assert that it didn't run
    assert_equal('Fail', result.value.valueName)
    assert(result.errors.size == 1)

    return result
  end

  def model_in_path_default(osm_file_or_model)
    return File.absolute_path(File.join(File.dirname(__FILE__), '../../../test/osm_files', osm_file_or_model))
  end

  def epw_path_default(epw_name)
    epw = OpenStudio::Path.new("#{File.dirname(__FILE__)}/../../../resources/measures/HPXMLtoOpenStudio/weather/#{epw_name}")
    assert(File.exist?(epw.to_s))
    return epw.to_s
  end

  def sch_path_default(sch_name)
    sch = OpenStudio::Path.new("#{File.dirname(__FILE__)}/../../../files/#{sch_name}")
    assert(File.exist?(sch.to_s))
    return sch.to_s
  end

  def test_dir(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}"
  end

  def model_out_path(osm_file_or_model, test_name)
    return "#{test_dir(test_name)}/#{osm_file_or_model}"
  end

  def sql_path(test_name)
    return "#{test_dir(test_name)}/run/eplusout.sql"
  end

  # create test files if they do not exist when the test first runs
  def setup_test(osm_file_or_model, test_name, idf_output_requests, epw_path, sch_path, model_in_path)
    # convert output requests to OSM for testing, OS App and PAT will add these to the E+ Idf
    workspace = OpenStudio::Workspace.new('Draft'.to_StrictnessLevel, 'EnergyPlus'.to_IddFileType)
    workspace.addObjects(idf_output_requests)
    rt = OpenStudio::EnergyPlus::ReverseTranslator.new
    request_model = rt.translateWorkspace(workspace)

    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(model_in_path)
    assert((not model.empty?))
    model = model.get
    model.addObjects(request_model.objects)
    model.save(model_out_path(osm_file_or_model, test_name), true)

    osw_path = File.join(test_dir(test_name), 'in.osw')
    osw_path = File.absolute_path(osw_path)

    workflow = OpenStudio::WorkflowJSON.new
    workflow.setSeedFile(File.absolute_path(model_out_path(osm_file_or_model, test_name)))
    workflow.setWeatherFile(epw_path)
    workflow.saveAs(osw_path)

    if !File.exist?("#{test_dir(test_name)}")
      FileUtils.mkdir_p("#{test_dir(test_name)}")
    end

    FileUtils.cp(sch_path, "#{test_dir(test_name)}")

    cli_path = OpenStudio.getOpenStudioCLI
    cmd = "\"#{cli_path}\" run -w \"#{osw_path}\""
    puts cmd
    system(cmd)

    return model
  end

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, test_name, epw_name, sch_name, num_infos = 0, num_warnings = 0, num_output_requests = 0)
    # create an instance of the measure
    measure = ResilienceMetricsReport.new

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
    arguments = measure.arguments()
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    if !File.exist?(test_dir(test_name))
      FileUtils.mkdir_p(test_dir(test_name))
    end
    assert(File.exist?(test_dir(test_name)))

    assert(File.exist?(model_in_path_default(osm_file_or_model)))

    # set up runner, this will happen automatically when measure is run in PAT or OpenStudio
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(model_in_path_default(osm_file_or_model)))
    runner.setLastEpwFilePath(File.expand_path(epw_path_default(epw_name)))

    # get the energyplus output requests, this will be done automatically by OS App and PAT
    idf_output_requests = measure.energyPlusOutputRequests(runner, argument_map)
    assert(idf_output_requests.size == num_output_requests)

    # mimic the process of running this measure in OS App or PAT. Optionally set custom model_in_path and custom epw_path.
    model = setup_test(osm_file_or_model, test_name, idf_output_requests, File.expand_path(epw_path_default(epw_name)), File.expand_path(sch_path_default(sch_name)), model_in_path_default(osm_file_or_model))
    assert(File.exist?(model_out_path(osm_file_or_model, test_name)))
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sql_path(test_name)))

    # temporarily change directory to the run directory and run the measure
    start_dir = Dir.pwd
    begin
      Dir.chdir(test_dir(test_name))

      # run the measure
      measure.run(runner, argument_map)
      result = runner.result
      show_output(result) unless result.value.valueName == 'Success'
    ensure
      Dir.chdir(start_dir)
    end

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    result.info.each do |i|
      puts i.logMessage
    end
    assert_equal(num_infos, result.info.size)
    assert_equal(num_warnings, result.warnings.size)

    return model
  end
end
