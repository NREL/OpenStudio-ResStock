# frozen_string_literal: true

require 'openstudio'
if File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../../lib/resources/measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock on AWS
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../../lib/resources/measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../../resources/measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock unit tests locally
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../../resources/measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources')
else
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
end

require_relative '../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
require File.join(resources_path, 'hvac')
require File.join(resources_path, 'waterheater')

class LoadComponentsReportTest < MiniTest::Test
  def test_sfd
    measure = LoadComponentsReport.new
    args_hash = {}
    expected_values = {}
    error_threshold = 0.10 # percent error threshold (< 0.10 %)
    weather_file = 'USA_CO_Denver.Intl.AP.725650_TMY3.epw'
    _test_measure('SFD_Successful_EnergyPlus_Run_TMY_Appl_PV.osm', args_hash, expected_values, __method__, weather_file, '8760.csv', 55, error_threshold)
  end

  private

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

  def idf_out_path(test_name)
    return "#{test_dir(test_name)}/run/in.idf"
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

  def _test_measure(osm_file_or_model, args_hash, expected_values, test_name, epw_name, sch_name, num_output_requests, error_threshold)
    # create an instance of the measure
    measure = LoadComponentsReport.new

    # check for standard methods
    assert(!measure.name.empty?)
    assert(!measure.description.empty?)

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
    assert_equal(num_output_requests, idf_output_requests.size)

    # mimic the process of running this measure in OS App or PAT. Optionally set custom model_in_path and custom epw_path.
    model = setup_test(osm_file_or_model, test_name, idf_output_requests, File.expand_path(epw_path_default(epw_name)), File.expand_path(sch_path_default(sch_name)), model_in_path_default(osm_file_or_model))

    assert(File.exist?(model_out_path(osm_file_or_model, test_name)))
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sql_path(test_name)))
    runner.setLastEnergyPlusWorkspacePath(OpenStudio::Path.new(idf_out_path(test_name)))

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

    result.stepValues.each do |step_value|
      next unless (step_value.name == 'heating_demand_error_percent') || (step_value.name == 'cooling_demand_error_percent')

      if step_value.valueAsDouble.abs > error_threshold
        assert_operator(step_value.valueAsDouble.abs, :<=, error_threshold, "#{step_value.name} is greater than threshold of #{error_threshold}%")
      end
    end

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert(result.info.size > 0)

    return model
  end
end
