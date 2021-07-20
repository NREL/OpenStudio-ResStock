# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ResidentialLightingInteriorTest < MiniTest::Test
  def test_new_construction_annual_energy_uses
    args_hash = {}
    args_hash['option_type'] = Constants.OptionTypeLightingEnergyUses
    expected_num_del_objects = {}
    expected_num_new_objects = { 'LightsDefinition' => 3, 'Lights' => 3, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 900 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_100_incandescent
    args_hash = {}
    args_hash['hw_cfl'] = 0.0
    args_hash['hw_led'] = 0.0
    args_hash['hw_lfl'] = 0.0
    args_hash['pg_cfl'] = 0.0
    args_hash['pg_led'] = 0.0
    args_hash['pg_lfl'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'LightsDefinition' => 3, 'Lights' => 3, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 2205 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_20_cfl_hw_34_cfl_pg
    args_hash = {}
    args_hash['hw_cfl'] = 0.2
    args_hash['hw_led'] = 0.0
    args_hash['hw_lfl'] = 0.0
    args_hash['pg_cfl'] = 0.34
    args_hash['pg_led'] = 0.0
    args_hash['pg_lfl'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'LightsDefinition' => 3, 'Lights' => 3, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 1914 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_34_cfl_hw_34_cfl_pg
    args_hash = {}
    args_hash['hw_cfl'] = 0.34
    args_hash['hw_led'] = 0.0
    args_hash['hw_lfl'] = 0.0
    args_hash['pg_cfl'] = 0.34
    args_hash['pg_led'] = 0.0
    args_hash['pg_lfl'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'LightsDefinition' => 3, 'Lights' => 3, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 1711 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_60_led_hw_34_cfl_pg
    args_hash = {}
    args_hash['hw_cfl'] = 0.0
    args_hash['hw_led'] = 0.6
    args_hash['hw_lfl'] = 0.0
    args_hash['pg_cfl'] = 0.34
    args_hash['pg_led'] = 0.0
    args_hash['pg_lfl'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'LightsDefinition' => 3, 'Lights' => 3, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 1230 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_100_cfl
    args_hash = {}
    args_hash['hw_cfl'] = 1.0
    args_hash['hw_led'] = 0.0
    args_hash['hw_lfl'] = 0.0
    args_hash['pg_cfl'] = 1.0
    args_hash['pg_led'] = 0.0
    args_hash['pg_lfl'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'LightsDefinition' => 3, 'Lights' => 3, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 751 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_100_led
    args_hash = {}
    args_hash['hw_cfl'] = 0.0
    args_hash['hw_led'] = 1.0
    args_hash['hw_lfl'] = 0.0
    args_hash['pg_cfl'] = 0.0
    args_hash['pg_led'] = 1.0
    args_hash['pg_lfl'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'LightsDefinition' => 3, 'Lights' => 3, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 580 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_100_led_low_efficacy
    args_hash = {}
    args_hash['hw_cfl'] = 0.0
    args_hash['hw_led'] = 1.0
    args_hash['hw_lfl'] = 0.0
    args_hash['pg_cfl'] = 0.0
    args_hash['pg_led'] = 1.0
    args_hash['pg_lfl'] = 0.0
    args_hash['led_eff'] = 50
    expected_num_del_objects = {}
    expected_num_new_objects = { 'LightsDefinition' => 3, 'Lights' => 3, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 805 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_half_lamps_used
    args_hash = {}
    args_hash['mult'] = 0.5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'LightsDefinition' => 3, 'Lights' => 3, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 1711 / 2 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_retrofit_replace
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'LightsDefinition' => 3, 'Lights' => 3, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 1711 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['hw_cfl'] = 1.0
    expected_num_del_objects = { 'LightsDefinition' => 3, 'Lights' => 3, 'ScheduleFile' => 1 }
    expected_num_new_objects = { 'LightsDefinition' => 3, 'Lights' => 3, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 751 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_argument_error_hw_cfl_lt_0
    args_hash = {}
    args_hash['hw_cfl'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Hardwired Fraction CFL must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_argument_error_hw_cfl_gt_1
    args_hash = {}
    args_hash['hw_cfl'] = 1.1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Hardwired Fraction CFL must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_argument_error_hw_led_lt_0
    args_hash = {}
    args_hash['hw_led'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Hardwired Fraction LED must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_argument_error_hw_led_gt_1
    args_hash = {}
    args_hash['hw_led'] = 1.1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Hardwired Fraction LED must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_argument_error_hw_lfl_lt_0
    args_hash = {}
    args_hash['hw_lfl'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Hardwired Fraction LFL must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_argument_error_hw_lfl_gt_1
    args_hash = {}
    args_hash['hw_lfl'] = 1.1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Hardwired Fraction LFL must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_argument_error_pg_cfl_lt_0
    args_hash = {}
    args_hash['pg_cfl'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Plugin Fraction CFL must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_argument_error_pg_cfl_gt_1
    args_hash = {}
    args_hash['pg_cfl'] = 1.1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Plugin Fraction CFL must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_argument_error_pg_led_lt_0
    args_hash = {}
    args_hash['pg_led'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Plugin Fraction LED must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_argument_error_pg_led_gt_1
    args_hash = {}
    args_hash['pg_led'] = 1.1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Plugin Fraction LED must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_argument_error_pg_lfl_lt_0
    args_hash = {}
    args_hash['pg_lfl'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Plugin Fraction LFL must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_argument_error_pg_lfl_gt_1
    args_hash = {}
    args_hash['pg_lfl'] = 1.1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Plugin Fraction LFL must be greater than or equal to 0 and less than or equal to 1.')
  end

  def test_argument_error_mult_lt_1
    args_hash = {}
    args_hash['mult'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Lamps used multiplier must be greater than or equal to 0.')
  end

  def test_argument_error_in_eff_0
    args_hash = {}
    args_hash['in_eff'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Incandescent Efficacy must be greater than 0.')
  end

  def test_argument_error_cfl_eff_0
    args_hash = {}
    args_hash['cfl_eff'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'CFL Efficacy must be greater than 0.')
  end

  def test_argument_error_led_eff_0
    args_hash = {}
    args_hash['led_eff'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'LED Efficacy must be greater than 0.')
  end

  def test_argument_error_lfl_eff_0
    args_hash = {}
    args_hash['lfl_eff'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'LFL Efficacy must be greater than 0.')
  end

  def test_argument_error_hw_gt_1
    args_hash = {}
    args_hash['hw_cfl'] = 0.4
    args_hash['hw_lfl'] = 0.4
    args_hash['hw_led'] = 0.4
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Sum of CFL, LED, and LFL Hardwired Fractions must be less than or equal to 1.')
  end

  def test_argument_error_pg_gt_1
    args_hash = {}
    args_hash['pg_cfl'] = 0.4
    args_hash['pg_lfl'] = 0.4
    args_hash['pg_led'] = 0.4
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Sum of CFL, LED, and LFL Plugin Fractions must be less than or equal to 1.')
  end

  def test_argument_error_energy_use_interior_lt_0
    args_hash = {}
    args_hash['option_type'] = Constants.OptionTypeLightingEnergyUses
    args_hash['energy_use_interior'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], "#{Constants.OptionTypeLightingEnergyUses}: Interior must be greater than or equal to 0.")
  end

  def test_error_missing_geometry
    args_hash = {}
    result = _test_error(nil, args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'No building geometry has been defined.')
  end

  def test_error_missing_location
    args_hash = {}
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Model has not been assigned a weather file.')
  end

  def test_single_family_attached_new_construction
    num_units = 1
    num_ltg_spaces = num_units * 2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Lights' => num_ltg_spaces, 'LightsDefinition' => num_ltg_spaces, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => num_units * 978 }
    _test_measure('SFA_4units_1story_FB_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_single_family_attached_new_construction_double_lamps_used
    num_units = 1
    num_ltg_spaces = num_units * 2
    args_hash = {}
    args_hash['mult'] = 2
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Lights' => num_ltg_spaces, 'LightsDefinition' => num_ltg_spaces, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => num_units * 978 * 2 }
    _test_measure('SFA_4units_1story_FB_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_multifamily_new_construction
    num_units = 1
    num_ltg_spaces = num_units
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Lights' => num_ltg_spaces, 'LightsDefinition' => num_ltg_spaces, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => num_units * 978 }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_multifamily_new_construction_tenth_lamps_used
    num_units = 1
    num_ltg_spaces = num_units
    args_hash = {}
    args_hash['mult'] = 0.1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Lights' => num_ltg_spaces, 'LightsDefinition' => num_ltg_spaces, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => num_units * 978 / 10 }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ResidentialLightingInterior.new

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

    # assert that it didn't run
    assert_equal('Fail', result.value.valueName)
    assert(result.errors.size == 1)

    return result
  end

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_infos = 0, num_warnings = 0)
    # create an instance of the measure
    measure = ResidentialLightingInterior.new

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
    assert(result.finalCondition.is_initialized)

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = ['ScheduleRule', 'ScheduleDay', 'ScheduleTypeLimits', 'ScheduleConstant']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    schedules_file = nil
    actual_values = { 'Annual_kwh' => 0 }
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        next unless obj_type == 'Lights'

        if schedules_file.nil?
          schedule_file = new_object.schedule.get.to_ScheduleFile.get
          schedules_file = SchedulesFile.new(runner: runner, model: model)
        end
        full_load_hrs = schedules_file.annual_equivalent_full_load_hrs(col_name: 'lighting_interior')
        actual_values['Annual_kwh'] += UnitConversions.convert(full_load_hrs * new_object.lightingLevel.get * new_object.multiplier * new_object.space.get.multiplier, 'Wh', 'kWh')
      end
    end
    assert_in_epsilon(expected_values['Annual_kwh'], actual_values['Annual_kwh'], 0.01)

    return model
  end
end
