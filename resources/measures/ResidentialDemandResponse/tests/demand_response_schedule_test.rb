# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class DemandResponseScheduleTest < MiniTest::Test
  def test_error_invalid_DR_schedule
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_invalid.csv'
    result = _test_error('SFD_2000sqft_2story_CS_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'The DR schedule must have values of -1, 0, or 1.')
  end

  def test_error_no_DR_schedule
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'doesnt_exist.csv'
    result = _test_error('SFD_2000sqft_2story_CS_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'File doesnt_exist.csv does not exist')
  end

  def test_wrong_DR_schedule_length
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_wrong_number.csv'
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {}
    _test_measure('SFD_2000sqft_2story_CS_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 2)
  end

  def test_no_offset
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 0
    args_hash['offset_magnitude_cool'] = 0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {}
    _test_measure('SFD_2000sqft_2story_CS_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_normal_tsp
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['offset_magnitude_cool'] = 3
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_h.csv'
    args_hash['dr_schedule_cool'] = 'DR_schedule_c.csv'
    expected_num_new_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 4 } # Cool/Heat rulesets 1x, Cool/Heat 2 schedule rule days each
    expected_num_del_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 24 } # Cool/Heat original rulesets 2x; Cool/Heat 12 original schedule rule days each
    expected_values = { 'heat_tsp_non_dr' => 70,
                        'heat_tsp_dr_plus' => 74,
                        'heat_tsp_dr_minus' => 66,
                        'cool_tsp_non_dr' => 75,
                        'cool_tsp_dr_plus' => 78,
                        'cool_tsp_dr_minus' => 72 }
    _test_measure('SFD_70heat_75cool_12mo_seasons.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
    # 6 assertions: 2 DR sched found, 2 Thermostat found, 2 setting thermostat
  end

  def test_normal_tsp_auto_seasons
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['offset_magnitude_cool'] = 3
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_h.csv'
    args_hash['dr_schedule_cool'] = 'DR_schedule_c.csv'
    expected_num_new_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 4 } # Cool/Heat rulesets 1x, Cool/Heat 2 schedule rule days each
    expected_num_del_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 24 } # Cool/Heat original rulesets 2x; Cool/Heat 12 original schedule rule days each
    expected_values = { 'heat_tsp_non_dr' => 70,
                        'heat_tsp_dr_plus' => 74,
                        'heat_tsp_dr_minus' => 66,
                        'heat_tsp_coolseason' => 70,
                        'cool_tsp_non_dr' => 75,
                        'cool_tsp_dr_plus' => 78,
                        'cool_tsp_dr_minus' => 72,
                        'cool_tsp_coolseason' => 75 }
    _test_measure('SFD_70heat_75cool_auto_seasons.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
    # 6 assertions: 2 DR sched found, 2 Thermostat found, 2 setting thermostat
  end

  def test_short_period
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['offset_magnitude_cool'] = 3
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_h_feb.csv'
    args_hash['dr_schedule_cool'] = 'DR_schedule_c_feb.csv'
    expected_num_new_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 4 } # Cool/Heat rulesets 1x, Cool/Heat 2 schedule rule days each
    expected_num_del_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 24 } # Cool/Heat original rulesets 2x; Cool/Heat 12 original schedule rule days each
    expected_values = { 'heat_tsp_non_dr' => 71,
                        'heat_tsp_dr_plus' => 75,
                        'heat_tsp_dr_minus' => 67,
                        'cool_tsp_non_dr' => 76,
                        'cool_tsp_dr_plus' => 79,
                        'cool_tsp_dr_minus' => 73 }
    _test_measure('SFD_Successful_EnergyPlus_Run_TMY_February.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
    # 6 assertions: 2 DR sched found, 2 Thermostat found, 2 setting thermostat
  end

  def test_short_period_8760_DR
    # Simulation period of 28 days with a 365-day DR schedule
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['offset_magnitude_cool'] = 3
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_h_feb_8760.csv'
    args_hash['dr_schedule_cool'] = 'DR_schedule_c_feb_8760.csv'
    expected_num_new_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 4 } # Cool/Heat rulesets 1x, Cool/Heat 2 schedule rule days each
    expected_num_del_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 24 } # Cool/Heat original rulesets 2x; Cool/Heat 12 original schedule rule days each
    expected_values = { 'heat_tsp_non_dr' => 71,
                        'heat_tsp_dr_plus' => 75,
                        'heat_tsp_dr_minus' => 67,
                        'cool_tsp_non_dr' => 76,
                        'cool_tsp_dr_plus' => 79,
                        'cool_tsp_dr_minus' => 73 }
    _test_measure('SFD_Successful_EnergyPlus_Run_TMY_February.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
    # 6 assertions: 2 DR sched found, 2 Thermostat found, 2 setting thermostat
  end

  # Inverted setpoints with overlapping seasons
  def test_inverted_tsp
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['offset_magnitude_cool'] = 4
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_h.csv'
    args_hash['dr_schedule_cool'] = 'DR_schedule_c.csv'
    expected_num_new_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 4 } # Cool/Heat rulesets 1x, Cool/Heat 2 schedule rule days each
    expected_num_del_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 24 } # Cool/Heat original rulesets 2x; Cool/Heat 12 original schedule rule days each
    expected_values = { 'heat_tsp_non_dr' => 69, # averaged
                        'heat_tsp_dr_plus' => 71,    #+DR --> averaged
                        'heat_tsp_dr_minus' => 66,   #-DR (not inverted)
                        'cool_tsp_non_dr' => 69,     # averaged
                        'cool_tsp_dr_plus' => 72,    #+DR (not inverted)
                        'cool_tsp_dr_minus' => 67 } #-DR --> averaged
    _test_measure('SFD_70heat_68cool_12mo_seasons.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
  end

  # Inverted setpoints without overlapping seasons
  def test_inverted_tsp_auto_season
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['offset_magnitude_cool'] = 4
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_h.csv'
    args_hash['dr_schedule_cool'] = 'DR_schedule_c.csv'
    expected_num_new_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 12 } # Cool/Heat rulesets 1x, Cool/Heat 1 each w/ DR, 2 overlapping seasons each, 3 non-overlapping seasons each
    expected_num_del_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 24 } # Cool/Heat original rulesets 2x; Cool/Heat 12 original schedule rule days each
    expected_values = { 'heat_tsp_non_dr' => 70,
                        'heat_tsp_dr_plus' => 74,
                        'heat_tsp_dr_minus' => 66,
                        'heat_tsp_coolseason' => 68, # match clg
                        'cool_tsp_non_dr' => 70,     # match htg
                        'cool_tsp_dr_plus' => 72,    #+DR
                        'cool_tsp_dr_minus' => 70,   # match htg
                        'cool_tsp_coolseason' => 68 }
    _test_measure('SFD_70heat_68cool_auto_seasons.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
  end

  # DR signal occurs at same time for cooling and heating
  def test_overlap_offset
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['offset_magnitude_cool'] = 4
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_overlap.csv'
    args_hash['dr_schedule_cool'] = 'DR_schedule_overlap.csv'
    expected_num_new_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 4 } # Cool/Heat rulesets 1x, Cool/Heat 2 schedule rule days each
    expected_num_del_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 24 } # Cool/Heat original rulesets 2x; Cool/Heat 12 original schedule rule days each
    expected_values = { 'heat_tsp_non_dr' => 70,
                        'heat_tsp_dr_plus' => 74,
                        'heat_tsp_dr_minus' => 66,
                        'cool_tsp_non_dr' => 75,
                        'cool_tsp_dr_plus' => 79,
                        'cool_tsp_dr_minus' => 71 }
    _test_measure('SFD_70heat_75cool_12mo_seasons.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
    # 6 assertions: 2 DR sched found, 2 Thermostat found, 2 setting thermostat
  end

  def test_zero_DR_schedule
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_zeros.csv'
    args_hash['dr_schedule_cool'] = 'DR_schedule_zeros.csv'
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {}
    _test_measure('SFD_2000sqft_2story_CS_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_no_thermostat
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_h.csv'
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {}
    _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver_CentralAC_NoSetpoints.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_normal_tsp_MF
    num_units = 1
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['offset_magnitude_cool'] = 3
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_h.csv'
    args_hash['dr_schedule_cool'] = 'DR_schedule_c.csv'
    expected_num_new_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 4 }  # Cool/Heat rulesets 2x, Cool/Heat 2 schedule rule days each
    expected_num_del_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 24 } # Cool/Heat original rulesets 2x; Cool/Heat 12 original schedule rule days each
    expected_values = { 'heat_tsp_non_dr' => 71, # default
                        'heat_tsp_dr_plus' => 75,
                        'heat_tsp_dr_minus' => 67,
                        'cool_tsp_non_dr' => 76, # default
                        'cool_tsp_dr_plus' => 79,
                        'cool_tsp_dr_minus' => 73 }
    _test_measure('MF_40units_4story_SL_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 2 * num_units + 4)
    # 84 assertions: 2 DR sched found, 2 Thermostat found, 40 setting cooling TSP, 40 setting heating TSP
  end

  def test_normal_tsp_basement
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['offset_magnitude_cool'] = 3
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_h.csv'
    args_hash['dr_schedule_cool'] = 'DR_schedule_c.csv'
    expected_num_new_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 4 }  # Cool/Heat rulesets 2x, Cool/Heat 2 schedule rule days each
    expected_num_del_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 24 } # Cool/Heat original rulesets 2x; Cool/Heat 12 original schedule rule days each
    expected_values = { 'heat_tsp_non_dr' => 70,
                        'heat_tsp_dr_plus' => 74,
                        'heat_tsp_dr_minus' => 66,
                        'cool_tsp_non_dr' => 75,
                        'cool_tsp_dr_plus' => 78,
                        'cool_tsp_dr_minus' => 72 }
    _test_measure('SFD_70heat_75cool_12mo_seasons_FB.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 8)
    # 8 assertions: 2 DR sched found, 2 Thermostat found, 2 setting cooling TSP, 2 setting heating TSP
  end

  # Test case that uses weekday_offset argument in `ResidentialHVACHeatingSetpoints`
  def test_weekday_offset
    args_hash = {}
    args_hash['offset_magnitude_heat'] = 4
    args_hash['offset_magnitude_cool'] = 4
    args_hash['dr_directory'] = './tests'
    args_hash['dr_schedule_heat'] = 'DR_schedule_const.csv'
    args_hash['dr_schedule_cool'] = 'DR_schedule_const.csv'
    expected_num_new_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 106 } # Cool/Heat rulesets 1x, 104 heat schedule rule days, 2 cool schedule rule days each
    expected_num_del_objects = { 'ScheduleRuleset' => 2, 'ScheduleRule' => 36 } # Cool/Heat original rulesets 2x; 24 original heat schedule rule, 12 original cool schedule rule days each
    expected_values = { 'wkday_offset_ht' => 76, # +2 wkday offset, +4 DR offset
                        'wkday_no_offset_ht' => 74, # +4 DR offset
                        'wknd_ht' => 74 }
    _test_measure('SFD_70heat_75cool_2wkdy_offset_12mo_seasons.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 6)
    # 8 assertions: 2 DR sched found, 2 Thermostat found, 2 setting cooling TSP, 2 setting heating TSP
  end

  private

  def _test_error(osm_file_or_model, args_hash)
    # create an instance of the measure
    measure = DemandResponseSchedule.new

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
    # assert that it didn't run
    assert_equal('Fail', result.value.valueName)
    assert(result.errors.size == 1)

    return result
  end

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_infos = 0, num_warnings = 0, debug = false)
    # create an instance of the measure
    measure = DemandResponseSchedule.new

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

    # show_output(result)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert_equal(num_infos, result.info.size)
    assert_equal(num_warnings, result.warnings.size)

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = ['ScheduleDay', 'ScheduleTypeLimits']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    dr_day = 1
    no_dr = 0
    if ((args_hash['dr_schedule_heat'] == 'DR_schedule_h_feb.csv') ||
        (args_hash['dr_schedule_cool'] == 'DR_schedule_c_feb.csv') ||
        (args_hash['dr_schedule_heat'] == 'DR_schedule_h_feb_8760.csv') ||
        (args_hash['dr_schedule_cool'] == 'DR_schedule_c_feb_8760.csv'))
      dr_month = 2
    else
      dr_month = 1
    end
    if ((args_hash['dr_schedule_heat'] == 'DR_schedule_overlap.csv') ||
        (args_hash['dr_schedule_cool'] == 'DR_schedule_overlap.csv'))
      ht_dr_plus = 1
      ht_dr_minus = 2
      cl_dr_plus = 1
      cl_dr_minus = 2
    else
      ht_dr_plus = 1
      ht_dr_minus = 2
      cl_dr_plus = 3
      cl_dr_minus = 4
    end
    if osm_file_or_model == 'SFD_70heat_75cool_2wkdy_offset_12mo_seasons.osm'
      check_month = 1
      wkday = 1
      wknd_day = 6
      offset_hour = 0
      no_offset_hour = 1
    end

    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next unless obj_type == 'ScheduleRule'
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        actual_values = []
        step = 0
        new_object.daySchedule.times.each_with_index do |t, i|
          h = t.to_s.split(':')[0].to_i
          (step...h).to_a.each do |j|
            actual_values << UnitConversions.convert(new_object.daySchedule.values[i], 'C', 'F') # method to create `actual_value` array from the day schedule
          end
          step = h
        end

        if osm_file_or_model == 'SFD_70heat_75cool_2wkdy_offset_12mo_seasons.osm'
          if new_object.name.to_s.start_with? Constants.ObjectNameHeatingSetpoint
            # Offset
            if (new_object.startDate.get.monthOfYear.value == check_month) &&
               (new_object.startDate.get.dayOfMonth == wkday)
              assert_in_epsilon(expected_values['wkday_offset_ht'], actual_values[offset_hour], 0.01)
              assert_in_epsilon(expected_values['wkday_no_offset_ht'], actual_values[no_offset_hour], 0.01)
            # No offset
            elsif (new_object.startDate.get.monthOfYear.value == check_month) &&
                  (new_object.startDate.get.dayOfMonth == wknd_day)
              assert_in_epsilon(expected_values['wknd_ht'], actual_values[no_offset_hour], 0.01)
            end
          end
          next
        end

        # DR period:
        if (new_object.startDate.get.monthOfYear.value == dr_month) &&
           (new_object.startDate.get.dayOfMonth == dr_day)
          if new_object.name.to_s.start_with? Constants.ObjectNameHeatingSetpoint
            assert_in_epsilon(expected_values['heat_tsp_non_dr'], actual_values[no_dr], 0.01)
            assert_in_epsilon(expected_values['heat_tsp_dr_plus'], actual_values[ht_dr_plus], 0.01)
            assert_in_epsilon(expected_values['heat_tsp_dr_minus'], actual_values[ht_dr_minus], 0.01)
          elsif new_object.name.to_s.start_with? Constants.ObjectNameCoolingSetpoint
            assert_in_epsilon(expected_values['cool_tsp_non_dr'], actual_values[no_dr], 0.01)
            assert_in_epsilon(expected_values['cool_tsp_dr_plus'], actual_values[cl_dr_plus], 0.01)
            assert_in_epsilon(expected_values['cool_tsp_dr_minus'], actual_values[cl_dr_minus], 0.01)
          end
        # No DR:
        elsif new_object.startDate.get.monthOfYear.value == 7 # Cooling season
          if new_object.name.to_s.start_with? Constants.ObjectNameHeatingSetpoint
            assert_in_epsilon(expected_values['heat_tsp_coolseason'], actual_values[no_dr],  0.01)
          elsif new_object.name.to_s.start_with? Constants.ObjectNameCoolingSetpoint
            assert_in_epsilon(expected_values['cool_tsp_coolseason'], actual_values[no_dr],  0.01)
          end
        elsif new_object.startDate.get.monthOfYear.value == 1 # Heating season
          if new_object.name.to_s.start_with? Constants.ObjectNameHeatingSetpoint
            assert_in_epsilon(expected_values['heat_tsp_non_dr'], actual_values[no_dr],  0.01)
          elsif new_object.name.to_s.start_with? Constants.ObjectNameCoolingSetpoint
            assert_in_epsilon(expected_values['cool_tsp_non_dr'], actual_values[no_dr],  0.01)
          end
        end
      end
    end

    return model
  end
end
