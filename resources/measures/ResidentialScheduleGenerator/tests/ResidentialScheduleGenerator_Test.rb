# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end

require File.join(resources_path, 'weather')

class ResidentialScheduleGeneratorTest < MiniTest::Test
  @@design_levels_e = {
    'cooking_range' => 224.799466698323, # test_new_construction_electric
    'plug_loads' => 97.542065513059 + 97.542065513059 + 170.698614647853, # test_new_construction_energy_use
    'lighting_interior' => 239.813313104278 + 137.03617891673 + 137.03617891673, # test_new_construction_100_incandescent
    'lighting_exterior' => 105.096505339876, # test_new_construction_100_incandescent
    'lighting_garage' => 14.4960697020519, # test_new_construction_100_incandescent
    'lighting_exterior_holiday' => 311.901700057588, # test_new_construction_holiday_schedule_overlap_years
    'clothes_washer' => 70491.5361082842, # test_new_construction_standard
    'clothes_dryer' => 187100.865402176, # test_new_construction_standard_elec
    'dishwasher' => 182309.775344607, # test_new_construction_318_rated_kwh
    'baths' => 65146.3417951306, # test_new_construction_standard
    'showers' => 507081.308470722, # test_new_construction_standard
    'sinks' => 158036.112491921, # test_new_construction_standard
    'ceiling_fan' => 22.5, # test_specified_num
    'plug_loads_vehicle' => 228.31050228310502, # test_electric_vehicle_new_construction_electric
    'plug_loads_well_pump' => 110.01639291891935 # test_well_pump_new_construction_electric
  }

  @@design_levels_g = {
    'fuel_loads_grill' => 427.95296983055385, # test_gas_grill_new_construction_gas
    'fuel_loads_lighting' => 153.15245454386806, # test_gas_lighting_new_construction_gas
    'fuel_loads_fireplace' => 483.6393301385308 # test_gas_fireplace_new_construction_gas
  }

  @@peak_flow_rates = {
    'clothes_washer' => 0.00629935656948612, # test_new_construction_standard
    'dishwasher' => 0.00195236583980626, # test_new_construction_318_rated_kwh
    'baths' => 0.00441642226310263, # test_new_construction_standard
    'showers' => 0.0176468149892557, # test_new_construction_standard
    'sinks' => 0.0157378848223646 # test_new_construction_standard
  }

  def test_sweep_building_ids_and_num_occupants
    full_load_hours = { 'schedules_length' => [], 'building_id' => [], 'num_occupants' => [] }
    annual_energy_use = { 'schedules_length' => [], 'building_id' => [], 'num_occupants' => [] }
    hot_water_gpd = { 'schedules_length' => [], 'building_id' => [], 'num_occupants' => [] }
    args_hash = {}

    expected_values = { 'SchedulesLength' => 8760, 'SchedulesWidth' => 23 } # these are the old schedules
    full_load_hours['building_id'] << 1
    full_load_hours['num_occupants'] << 2.64
    annual_energy_use['building_id'] << 1
    annual_energy_use['num_occupants'] << 2.64
    hot_water_gpd['building_id'] << 1
    hot_water_gpd['num_occupants'] << 2.64
    full_load_hours, annual_energy_use, hot_water_gpd = _test_generator('SFD_2000sqft_2story_FB_UA_Denver.osm', args_hash, expected_values, '8760', 'USA_CO_Denver.Intl.AP.725650_TMY3.epw', full_load_hours, annual_energy_use, hot_water_gpd)

    expected_values = { 'SchedulesLength' => 8784, 'SchedulesWidth' => 23 } # these are the old schedules
    full_load_hours['building_id'] << 1
    full_load_hours['num_occupants'] << 2.64
    annual_energy_use['building_id'] << 1
    annual_energy_use['num_occupants'] << 2.64
    hot_water_gpd['building_id'] << 1
    hot_water_gpd['num_occupants'] << 2.64
    full_load_hours, annual_energy_use, hot_water_gpd = _test_generator('SFD_Successful_EnergyPlus_Run_AMY_PV.osm', args_hash, expected_values, '8784', 'USA_CO_Denver.Intl.AP.725650_TMY3.epw', full_load_hours, annual_energy_use, hot_water_gpd)

    num_building_ids = 1
    num_occupants = [2]
    vacancy_start_date = 'NA'
    vacancy_end_date = 'NA'
    expected_values = { 'SchedulesLength' => 52560, 'SchedulesWidth' => 24 }
    prng = Random.new(1) # initialize with certain seed
    (1..num_building_ids).to_a.each do |building_id|
      building_id = rand(1..450000)
      # building_id = prng.rand(1..450000) # uncomment to use deterministic testing
      num_occupants.each do |num_occupant|
        puts "\nBUILDING ID: #{building_id}, NUM_OCCUPANTS: #{num_occupant}"
        full_load_hours['building_id'] << building_id
        full_load_hours['num_occupants'] << num_occupant
        annual_energy_use['building_id'] << building_id
        annual_energy_use['num_occupants'] << num_occupant
        hot_water_gpd['building_id'] << building_id
        hot_water_gpd['num_occupants'] << num_occupant
        args_hash[:building_id] = building_id
        args_hash[:num_occupants] = num_occupant
        args_hash[:vacancy_start_date] = vacancy_start_date
        args_hash[:vacancy_end_date] = vacancy_end_date
        full_load_hours, annual_energy_use, hot_water_gpd = _test_generator('SFD_2000sqft_2story_FB_UA_Denver.osm', args_hash, expected_values, __method__, 'USA_CO_Denver.Intl.AP.725650_TMY3.epw', full_load_hours, annual_energy_use, hot_water_gpd)
      end
    end

    csv_path = File.join(test_dir(__method__), 'full_load_hours.csv')
    CSV.open(csv_path, 'wb') do |csv|
      csv << full_load_hours.keys
      rows = full_load_hours.values.transpose
      rows.each do |row|
        csv << row
      end
    end

    csv_path = File.join(test_dir(__method__), 'annual_electricity_use.csv')
    CSV.open(csv_path, 'wb') do |csv|
      csv << annual_energy_use.keys
      rows = annual_energy_use.values.transpose
      rows.each do |row|
        csv << row
      end
    end

    csv_path = File.join(test_dir(__method__), 'hot_water_gpd.csv')
    CSV.open(csv_path, 'wb') do |csv|
      csv << hot_water_gpd.keys
      rows = hot_water_gpd.values.transpose
      rows.each do |row|
        csv << row
      end
    end
  end

  def test_argument_error_num_occ_nonpositive
    args_hash = {}
    args_hash['num_occupants'] = '0'
    result = _test_error_or_NA('Denver.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, "Number of Occupants '#{args_hash['num_occupants']} must be greater than 0.")
  end

  def test_error_invalid_vacancy
    args_hash = {}
    args_hash['state'] = 'CO'
    args_hash['vacancy_start_date'] = 'April 31'
    result = _test_error_or_NA('Denver.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid vacancy date(s) specified.')
  end

  def test_NA_vacancy
    args_hash = {}
    args_hash['state'] = 'CO'
    args_hash['vacancy_start_date'] = 'NA'
    args_hash['vacancy_end_date'] = 'NA'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Building' => 1 }
    expected_values = {}
    _test_measure('Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 2, 1)
  end

  def test_change_vacancy
    args_hash = {}
    args_hash['state'] = 'CO'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Building' => 1 }
    expected_values = {}
    model = _test_measure('Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 2, 1)
    args_hash = {}
    args_hash['state'] = 'CO'
    args_hash['vacancy_start_date'] = 'April 8'
    args_hash['vacancy_end_date'] = 'October 27'
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {}
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 2, 1)
  end

  private

  def test_dir(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}"
  end

  def schedule_file_path(test_name)
    return "#{test_dir(test_name)}/schedules.csv"
  end

  def _test_generator(osm_file_or_model, args_hash, expected_values, test_name, epw_name, full_load_hours, annual_energy_use, hot_water_gpd)
    # create an instance of the measure
    measure = ResidentialScheduleGenerator.new

    # check for standard methods
    assert(!measure.name.empty?)
    assert(!measure.description.empty?)

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    model = get_model(File.dirname(__FILE__), osm_file_or_model)

    args_hash[:schedules_path] = File.join(File.dirname(__FILE__), '../../HPXMLtoOpenStudio/resources/schedules')
    args_hash[:state] = 'CO' # use an arbitrary state for testing

    if "#{test_name}".include? '8760'
      schedules_path = File.join(File.dirname(__FILE__), '../../../../files/8760.csv')
    elsif "#{test_name}".include? '8784'
      schedules_path = File.join(File.dirname(__FILE__), '../../../../files/8784.csv')
    else
      if !File.exist?("#{test_dir(test_name)}")
        FileUtils.mkdir_p("#{test_dir(test_name)}")
      end
      weather = WeatherProcess.new(model, runner) # required for lighting schedule generation
      if weather.error?
        return false
      end

      schedules_path = schedule_file_path(test_name)
      schedule_generator = ScheduleGenerator.new(runner: runner, model: model, weather: weather, **args_hash)
      success = schedule_generator.create
      success = schedule_generator.export(output_path: schedules_path)
    end

    # make sure the enduse report file exists
    if expected_values.keys.include?('SchedulesLength') && expected_values.keys.include?('SchedulesWidth')
      assert(File.exist?(schedules_path))

      # make sure you're reporting at correct frequency
      schedules_length, schedules_width, full_load_hours, annual_energy_use, hot_water_gpd = get_schedule_file(model, runner, schedules_path, full_load_hours, annual_energy_use, hot_water_gpd)
      assert_equal(expected_values['SchedulesLength'], schedules_length)
      assert_equal(expected_values['SchedulesWidth'], schedules_width)
      full_load_hours['schedules_length'] << schedules_length
      annual_energy_use['schedules_length'] << schedules_length
      hot_water_gpd['schedules_length'] << schedules_length
    end

    return full_load_hours, annual_energy_use, hot_water_gpd
  end

  def _test_error_or_NA(osm_file_or_model, args_hash)
    # create an instance of the measure
    measure = ResidentialScheduleGenerator.new

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
    measure = ResidentialScheduleGenerator.new

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

    return model
  end

  def get_schedule_file(model, runner, schedules_path, full_load_hours, annual_energy_use, hot_water_gpd)
    schedules_file = SchedulesFile.new(runner: runner, model: model, schedules_path: schedules_path)
    if not schedules_file.validated?
      return false
    end

    rows = CSV.read(File.expand_path(schedules_path))
    full_load_hours, annual_energy_use, hot_water_gpd = check_columns(rows[0], schedules_file, full_load_hours, annual_energy_use, hot_water_gpd)
    schedules_length = rows.length - 1
    cols = rows.transpose
    schedules_width = cols.length
    return schedules_length, schedules_width, full_load_hours, annual_energy_use, hot_water_gpd
  end

  def check_columns(col_names, schedules_file, full_load_hours, annual_energy_use, hot_water_gpd)
    col_names.each do |col_name|
      next if col_name.include? 'sleep'

      flh = schedules_file.annual_equivalent_full_load_hrs(col_name: col_name)
      aeu = nil
      if @@design_levels_e.keys.include? col_name
        aeu = UnitConversions.convert(flh * @@design_levels_e[col_name], 'Wh', 'kWh')
      end
      if @@design_levels_g.keys.include? col_name
        aeu = UnitConversions.convert(flh * @@design_levels_g[col_name], 'Wh', 'therm')
      end
      hwg = nil
      if @@peak_flow_rates.keys.include? col_name
        hwg = UnitConversions.convert(flh * @@peak_flow_rates[col_name], 'm^3/s', 'gal/min') * 60.0 / 365.0
      end

      full_load_hours[col_name] = [] unless full_load_hours.keys.include? col_name
      annual_energy_use[col_name] = [] unless annual_energy_use.keys.include? col_name
      hot_water_gpd[col_name] = [] unless hot_water_gpd.keys.include? col_name

      full_load_hours[col_name] << flh
      annual_energy_use[col_name] << aeu
      hot_water_gpd[col_name] << hwg
    end

    return full_load_hours, annual_energy_use, hot_water_gpd
  end
end
