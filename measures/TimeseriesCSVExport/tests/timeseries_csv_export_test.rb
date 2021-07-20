# frozen_string_literal: true

require_relative '../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class TimeseriesCSVExportTest < MiniTest::Test
  # "EnduseTimeseriesWidth" => num_time_indexes + num_electricity + num_natural_gas + num_fuel_oil + num_propane + num_wood + num_energy + num_output_variables
  @@include_enduse_subcategories = {
    'false' => 3 + 15 + 4 + 3 + 4 + 2 + 1,
    'true' => 3 + 33 + 10 + 3 + 5 + 2 + 1
  }

  def test_leap_year_timestep_and_subcategories
    num_output_requests = 27 + 2
    measure = TimeseriesCSVExport.new
    args_hash = {}
    args_hash['reporting_frequency'] = 'Timestep'
    args_hash['include_enduse_subcategories'] = 'true'
    args_hash['output_variables'] = 'Zone Mean Air Temperature, Site Outdoor Air Drybulb Temperature'
    expected_values = { 'EnduseTimeseriesLength' => 8784 * 6, 'EnduseTimeseriesWidth' => @@include_enduse_subcategories[args_hash['include_enduse_subcategories']] + 5 }
    _test_measure('SFD_Successful_EnergyPlus_Run_AMY_PV.osm', args_hash, expected_values, __method__, '0465925_US_CO_Boulder_8013_0-20000-0-72469_40.13_-105.22_NSRDB_2.0.1_AMY_2012.epw', '8784.csv', num_output_requests)
  end

  def test_amy_short_run_period_hourly
    num_output_requests = 21 + 1
    measure = TimeseriesCSVExport.new
    args_hash = {}
    args_hash['include_enduse_subcategories'] = 'false'
    args_hash['output_variables'] = 'Zone People Occupant Count'
    expected_values = { 'EnduseTimeseriesLength' => 2 * 24, 'EnduseTimeseriesWidth' => @@include_enduse_subcategories[args_hash['include_enduse_subcategories']] + 1 }
    _test_measure('SFD_Successful_EnergyPlus_Run_AMY_PV_TwoDays.osm', args_hash, expected_values, __method__, '0465925_US_CO_Boulder_8013_0-20000-0-72469_40.13_-105.22_NSRDB_2.0.1_AMY_2014.epw', '8760.csv', num_output_requests)
  end

  def test_amy_short_run_period_daily
    num_output_requests = 21 + 1
    measure = TimeseriesCSVExport.new
    args_hash = {}
    args_hash['reporting_frequency'] = 'Daily'
    args_hash['include_enduse_subcategories'] = 'false'
    args_hash['output_variables'] = 'Zone People Occupant Count'
    expected_values = { 'EnduseTimeseriesLength' => 2 * 1, 'EnduseTimeseriesWidth' => @@include_enduse_subcategories[args_hash['include_enduse_subcategories']] + 1 }
    _test_measure('SFD_Successful_EnergyPlus_Run_AMY_PV_TwoDays.osm', args_hash, expected_values, __method__, '0465925_US_CO_Boulder_8013_0-20000-0-72469_40.13_-105.22_NSRDB_2.0.1_AMY_2014.epw', '8760.csv', num_output_requests)
  end

  def test_amy_short_run_period_monthly
    num_output_requests = 21 + 1
    measure = TimeseriesCSVExport.new
    args_hash = {}
    args_hash['reporting_frequency'] = 'Monthly'
    args_hash['include_enduse_subcategories'] = 'false'
    args_hash['output_variables'] = 'Zone People Occupant Count'
    expected_values = { 'EnduseTimeseriesLength' => 1, 'EnduseTimeseriesWidth' => @@include_enduse_subcategories[args_hash['include_enduse_subcategories']] + 1 }
    _test_measure('SFD_Successful_EnergyPlus_Run_AMY_PV_TwoDays.osm', args_hash, expected_values, __method__, '0465925_US_CO_Boulder_8013_0-20000-0-72469_40.13_-105.22_NSRDB_2.0.1_AMY_2014.epw', '8760.csv', num_output_requests)
  end

  def test_amy_short_run_period_runperiod
    num_output_requests = 21 + 1
    measure = TimeseriesCSVExport.new
    args_hash = {}
    args_hash['reporting_frequency'] = 'RunPeriod'
    args_hash['include_enduse_subcategories'] = 'false'
    args_hash['output_variables'] = 'Zone People Occupant Count'
    expected_values = { 'EnduseTimeseriesLength' => 1, 'EnduseTimeseriesWidth' => @@include_enduse_subcategories[args_hash['include_enduse_subcategories']] + 1 }
    _test_measure('SFD_Successful_EnergyPlus_Run_AMY_PV_TwoDays.osm', args_hash, expected_values, __method__, '0465925_US_CO_Boulder_8013_0-20000-0-72469_40.13_-105.22_NSRDB_2.0.1_AMY_2014.epw', '8760.csv', num_output_requests)
  end

  def test_tmy_hourly
    num_output_requests = 11 + 1
    measure = TimeseriesCSVExport.new
    args_hash = {}
    args_hash['include_enduse_subcategories'] = 'false'
    args_hash['output_variables'] = 'Site Wind Direction'
    expected_values = { 'EnduseTimeseriesLength' => 8760, 'EnduseTimeseriesWidth' => @@include_enduse_subcategories[args_hash['include_enduse_subcategories']] + 1 }
    _test_measure('SFD_Successful_EnergyPlus_Run_TMY_Appl_PV.osm', args_hash, expected_values, __method__, 'USA_CO_Denver.Intl.AP.725650_TMY3.epw', '8760.csv', num_output_requests)
  end

  def test_tmy_daily_and_subcategories
    num_output_requests = 27 + 2
    measure = TimeseriesCSVExport.new
    args_hash = {}
    args_hash['reporting_frequency'] = 'Daily'
    args_hash['include_enduse_subcategories'] = 'true'
    args_hash['output_variables'] = 'Electric Equipment Electricity Rate, Zone Air Heat Balance Internal Convective Heat Gain Rate'
    expected_values = { 'EnduseTimeseriesLength' => 365, 'EnduseTimeseriesWidth' => @@include_enduse_subcategories[args_hash['include_enduse_subcategories']] + 9 }
    _test_measure('SFD_Successful_EnergyPlus_Run_TMY_Appl_PV.osm', args_hash, expected_values, __method__, 'USA_CO_Denver.Intl.AP.725650_TMY3.epw', '8760.csv', num_output_requests)
  end

  def test_tmy_monthly
    num_output_requests = 11 + 2
    measure = TimeseriesCSVExport.new
    args_hash = {}
    args_hash['reporting_frequency'] = 'Monthly'
    args_hash['include_enduse_subcategories'] = 'false'
    args_hash['output_variables'] = 'Other Equipment Total Heating Energy, Surface Window Glazing Beam to Diffuse Solar Transmittance'
    expected_values = { 'EnduseTimeseriesLength' => 12, 'EnduseTimeseriesWidth' => @@include_enduse_subcategories[args_hash['include_enduse_subcategories']] + 12 }
    _test_measure('SFD_Successful_EnergyPlus_Run_TMY_Appl_PV.osm', args_hash, expected_values, __method__, 'USA_CO_Denver.Intl.AP.725650_TMY3.epw', '8760.csv', num_output_requests)
  end

  def test_tmy_runperiod
    num_output_requests = 11 + 2
    measure = TimeseriesCSVExport.new
    args_hash = {}
    args_hash['reporting_frequency'] = 'RunPeriod'
    args_hash['include_enduse_subcategories'] = 'false'
    args_hash['output_variables'] = 'Surface Outside Normal Azimuth Angle, Surface Window Heat Gain Rate'
    expected_values = { 'EnduseTimeseriesLength' => 1, 'EnduseTimeseriesWidth' => @@include_enduse_subcategories[args_hash['include_enduse_subcategories']] + 71 }
    _test_measure('SFD_Successful_EnergyPlus_Run_TMY_Appl_PV.osm', args_hash, expected_values, __method__, 'USA_CO_Denver.Intl.AP.725650_TMY3.epw', '8760.csv', num_output_requests)
  end

  def test_tmy_daily_and_subcategories_mf
    num_units = 1
    num_output_requests = 27 + 3
    measure = TimeseriesCSVExport.new
    args_hash = {}
    args_hash['reporting_frequency'] = 'Daily'
    args_hash['include_enduse_subcategories'] = 'true'
    args_hash['output_variables'] = 'Cooling Coil Runtime Fraction, Unitary System Ancillary Electricity Rate, System Node Temperature'
    expected_values = { 'EnduseTimeseriesLength' => 365, 'EnduseTimeseriesWidth' => @@include_enduse_subcategories[args_hash['include_enduse_subcategories']] + 1 }
    _test_measure('MF_Successful_EnergyPlus_Run_TMY_Appl_PV.osm', args_hash, expected_values, __method__, 'USA_CO_Denver.Intl.AP.725650_TMY3.epw', '8760.csv', num_output_requests)
  end

  def test_key_value_arg
    num_output_requests = 11 + 2
    measure = TimeseriesCSVExport.new
    args_hash = {}
    args_hash['include_enduse_subcategories'] = 'false'
    args_hash['output_variables'] = 'Surface Outside Face Incident Solar Radiation Rate per Area|Surface 2, Zone People Occupant Count|living zone'
    expected_values = { 'EnduseTimeseriesLength' => 8760, 'EnduseTimeseriesWidth' => @@include_enduse_subcategories[args_hash['include_enduse_subcategories']] + 2 }
    _test_measure('SFD_Successful_EnergyPlus_Run_TMY_Appl_PV.osm', args_hash, expected_values, __method__, 'USA_CO_Denver.Intl.AP.725650_TMY3.epw', '8760.csv', num_output_requests)
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

  def sql_path(test_name)
    return "#{test_dir(test_name)}/run/eplusout.sql"
  end

  def enduse_timeseries_path(test_name)
    return "#{test_dir(test_name)}/enduse_timeseries.csv"
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

  def _test_measure(osm_file_or_model, args_hash, expected_values, test_name, epw_name, sch_name, num_output_requests)
    # create an instance of the measure
    measure = TimeseriesCSVExport.new

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

    # temporarily change directory to the run directory and run the measure
    start_dir = Dir.pwd
    begin
      Dir.chdir(test_dir(test_name))

      # run the measure
      measure.run(runner, argument_map)
      FileUtils.mv('../enduse_timeseries.csv', 'enduse_timeseries.csv')
      result = runner.result
      show_output(result) unless result.value.valueName == 'Success'
    ensure
      Dir.chdir(start_dir)
    end

    # make sure the enduse report file exists
    if expected_values.keys.include?('EnduseTimeseriesLength') && expected_values.keys.include?('EnduseTimeseriesWidth')
      assert(File.exist?(enduse_timeseries_path(test_name)))

      # make sure you're reporting at correct frequency
      timeseries_length, timeseries_width = get_enduse_timeseries(enduse_timeseries_path(test_name))
      assert_equal(expected_values['EnduseTimeseriesLength'], timeseries_length)
      assert_equal(expected_values['EnduseTimeseriesWidth'], timeseries_width)

      # jumps are allowed in DST timestamps, but only twice at max, and each jump should be of 3600 seconds
      salient_jumps = verify_uniform_timestamps(enduse_timeseries_path(test_name), 1, jumps_allowed = true)
      # the jumps should cancel each other
      assert_equal(0, salient_jumps.map { |x| x[1] }.reduce(0, :+))
      if salient_jumps.length > 2
        raise("DST timestamps should have a maximum of 2 jumps. It had #{salient_jumps.length} jumps at: #{salient_jumps}")
      end

      salient_jumps.each do |jump|
        if jump[1].abs != 3600
          raise("DST timestamps column has an invalid jump of #{jump[1]} seconds at #{jump[0]}")
        end
      end

      verify_uniform_timestamps(enduse_timeseries_path(test_name), 0, jumps_allowed = false)
      verify_uniform_timestamps(enduse_timeseries_path(test_name), 2, jumps_allowed = false)

    end

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert(result.info.size > 0)

    return model
  end

  def get_enduse_timeseries(enduse_timeseries)
    rows = CSV.read(File.expand_path(enduse_timeseries))
    timeseries_length = rows.length - 1
    cols = rows.transpose
    timeseries_width = cols.length
    return timeseries_length, timeseries_width
  end

  def to_utctime(datetimestr)
    date, time = datetimestr.split(' ')
    date_parts = date.split('/')
    time_parts = time.split(':')
    return Time.utc(*(date_parts + time_parts))
  end

  def verify_uniform_timestamps(enduse_timeseries, col_num, jumps_allowed = false)
    # Verifies if timestamps are uniform. If they are not, it will raise an error if jumps_allowed = false.
    # if jumps_allowed = true, instead of raising error, it returns an array that contains pair of timestamp and
    # abnormal jumps.
    rows = CSV.read(File.expand_path(enduse_timeseries))
    header_row = rows[0]
    if rows.length <= 2
      return []
    end

    first_datetime = to_utctime(rows[1][col_num])
    second_datetime = to_utctime(rows[2][col_num])
    valid_diff = second_datetime - first_datetime # Assume the first diff is the valid one

    if valid_diff >= 28 * 24 * 60 * 60 # diff is larger than 28 days; likely monthly timestamps
      # The timestamps are likely in monthly interval. This function cannot test uniformity on such case so let it pass
      # TODO: Test uniformity even in case of monthly timestamps
      return []
    end

    salient_jumps = []
    last_datetime = second_datetime
    rows[3..-1].each do |entry|
      current_datetime = to_utctime(entry[col_num])
      current_diff = current_datetime - last_datetime
      if current_diff != valid_diff
        if not jumps_allowed
          raise("Timestamps in #{header_row[col_num]} column in #{enduse_timeseries} not uniform. It jumped by #{current_diff} seconds at"\
              " #{entry[0]}, while it has been jumping by #{last_diff} seconds before.")
        else
          extra_jump = current_diff - valid_diff
          salient_jumps.push([current_datetime, extra_jump])
        end
      end
      last_datetime = current_datetime
    end
    return salient_jumps
  end
end
