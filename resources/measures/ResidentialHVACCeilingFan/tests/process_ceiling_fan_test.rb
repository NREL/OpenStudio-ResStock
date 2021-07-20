# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessCeilingFanTest < MiniTest::Test
  def test_argument_error_mult_negative
    args_hash = {}
    args_hash['mult'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Multiplier must be greater than or equal to 0.')
  end

  def test_specified_num
    args_hash = {}
    args_hash['use_benchmark_energy'] = 'false'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 1, 'ScheduleRule' => 12, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemActuator' => 1, 'EnergyManagementSystemSensor' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1 }
    expected_values = { 'ceiling_fans_design_level' => 22.5 }
    _test_measure('SFD_2000sqft_2story_FB_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_coverage
    args_hash = {}
    args_hash['coverage'] = '0.5'
    args_hash['specified_num'] = 'NA'
    args_hash['use_benchmark_energy'] = 'false'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 1, 'ScheduleRule' => 12, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemActuator' => 1, 'EnergyManagementSystemSensor' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1 }
    expected_values = { 'ceiling_fans_design_level' => 49.5 }
    _test_measure('SFD_2000sqft_2story_FB_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_coverage_cooling_offset
    args_hash = {}
    args_hash['coverage'] = '0.5'
    args_hash['specified_num'] = 'NA'
    args_hash['use_benchmark_energy'] = 'false'
    args_hash['cooling_setpoint_offset'] = '4.0'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 1, 'ScheduleRule' => 12, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemActuator' => 1, 'EnergyManagementSystemSensor' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1 }
    expected_values_clg_wkday_setpoints = [80] * 24
    expected_values_clg_wked_setpoints = [80] * 24
    expected_values = { 'ceiling_fans_design_level' => 49.5, 'clg_wkday_setpoints' => expected_values_clg_wkday_setpoints, 'clg_wked_setpoints' => expected_values_clg_wked_setpoints }
    _test_measure('SFD_2000sqft_2story_FB_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_coverage_cooling_offset_var_tstat
    args_hash = {}
    args_hash['coverage'] = '0.5'
    args_hash['specified_num'] = 'NA'
    args_hash['use_benchmark_energy'] = 'false'
    args_hash['cooling_setpoint_offset'] = '4.0'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 1, 'ScheduleRule' => 24, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemActuator' => 1, 'EnergyManagementSystemSensor' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1 }
    expected_values_clg_wkday_setpoints = [80, 79, 78, 78, 79, 80, 80, 79, 78, 78, 79, 80, 80, 79, 78, 78, 79, 80, 80, 79, 78, 78, 79, 80]
    expected_values_clg_wked_setpoints = [81, 82, 83, 83, 82, 81, 81, 82, 83, 83, 82, 81, 81, 82, 83, 83, 82, 81, 81, 82, 83, 83, 82, 81]
    expected_values = { 'ceiling_fans_design_level' => 49.5, 'clg_wkday_setpoints' => expected_values_clg_wkday_setpoints, 'clg_wked_setpoints' => expected_values_clg_wked_setpoints }
    _test_measure('SFD_2000sqft_2story_FB_UA_3Beds_2Baths_Denver_Furnace_CentralAC_VarTstat.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_smart_control
    args_hash = {}
    args_hash['control'] = Constants.CeilingFanControlSmart
    args_hash['use_benchmark_energy'] = 'false'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 1, 'ScheduleRule' => 12, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemActuator' => 1, 'EnergyManagementSystemSensor' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1 }
    expected_values = { 'ceiling_fans_design_level' => 11.25 }
    _test_measure('SFD_2000sqft_2story_FB_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_no_cooling_system
    args_hash = {}
    args_hash['use_benchmark_energy'] = 'false'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 1, 'ScheduleRule' => 12, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemActuator' => 1, 'EnergyManagementSystemSensor' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1 }
    expected_values = { 'ceiling_fans_design_level' => 22.5 }
    _test_measure('SFD_2000sqft_2story_SL_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0, 1)
  end

  def test_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    args_hash['use_benchmark_energy'] = 'false'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => num_units * 1, 'ScheduleRule' => num_units * 12, 'EnergyManagementSystemProgram' => num_units * 1, 'EnergyManagementSystemActuator' => num_units * 1, 'EnergyManagementSystemSensor' => num_units * 2, 'EnergyManagementSystemProgramCallingManager' => num_units * 1, 'ElectricEquipmentDefinition' => num_units * 1, 'ElectricEquipment' => num_units * 1 }
    expected_values = { 'ceiling_fans_design_level' => 22.5 }
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction
    num_units = 1
    args_hash = {}
    args_hash['use_benchmark_energy'] = 'false'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => num_units * 1, 'ScheduleRule' => num_units * 12, 'EnergyManagementSystemProgram' => num_units * 1, 'EnergyManagementSystemActuator' => num_units * 1, 'EnergyManagementSystemSensor' => num_units * 2, 'EnergyManagementSystemProgramCallingManager' => num_units * 1, 'ElectricEquipmentDefinition' => num_units * 1, 'ElectricEquipment' => num_units * 1 }
    expected_values = { 'ceiling_fans_design_level' => 22.5 }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_retrofit_specify_instead_of_benchmark
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleRuleset' => 1, 'ScheduleRule' => 12, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemActuator' => 1, 'EnergyManagementSystemSensor' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'ElectricEquipmentDefinition' => 4, 'ElectricEquipment' => 4, 'ScheduleFile' => 1 }
    expected_values = { 'ceiling_fans_design_level' => 0, 'misc_elec_load_design_level' => 12.86 }
    model = _test_measure('SFD_2000sqft_2story_FB_UA_3Beds_2Baths_Denver_Furnace_CentralAC.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash['specified_num'] = '2'
    args_hash['use_benchmark_energy'] = 'false'
    expected_num_del_objects = { 'ScheduleRuleset' => 1, 'ScheduleRule' => 12, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemActuator' => 1, 'EnergyManagementSystemSensor' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'ElectricEquipmentDefinition' => 4, 'ElectricEquipment' => 4 }
    expected_num_new_objects = { 'ScheduleRuleset' => 1, 'ScheduleRule' => 12, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemActuator' => 1, 'EnergyManagementSystemSensor' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1 }
    expected_values = { 'ceiling_fans_design_level' => 45 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  private

  def _test_error(osm_file_or_model, args_hash)
    # create an instance of the measure
    measure = ProcessCeilingFan.new

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
    measure = ProcessCeilingFan.new

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
    obj_type_exclusions = ['ScheduleDay', 'ScheduleConstant', 'ScheduleTypeLimits']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    check_ems(model)

    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        next unless obj_type == 'ElectricEquipment'

        if new_object.name.to_s.start_with? Constants.ObjectNameCeilingFan + ' non benchmark'
          assert_in_epsilon(expected_values['ceiling_fans_design_level'], new_object.designLevel.get, 0.01)
        end
        if new_object.name.to_s.start_with? Constants.ObjectNameCeilingFan + ' benchmark'
          assert_in_epsilon(expected_values['misc_elec_load_design_level'], new_object.designLevel.get, 0.01)
        end
      end
    end

    if expected_values.include?('clg_wkday_setpoints') && expected_values.include?('clg_wked_setpoints')
      final_objects.each do |obj_type, final_object|
        next if not final_object.respond_to?("to_#{obj_type}")

        final_object = final_object.public_send("to_#{obj_type}").get
        if (obj_type == 'ScheduleDay') && final_object.name.to_s.start_with?(Constants.ObjectNameCoolingSetpoint) && (not final_object.name.to_s.include? 'design')
          if final_object.name.to_s.include?(Schedule.allday_name)
            for i in 1..24
              next if final_object.values[i - 1] > 999

              assert_in_epsilon(expected_values['clg_wkday_setpoints'][i - 1], UnitConversions.convert(final_object.values[i - 1], 'C', 'F'))
              assert_in_epsilon(expected_values['clg_wked_setpoints'][i - 1], UnitConversions.convert(final_object.values[i - 1], 'C', 'F'))
              end
          elsif final_object.name.to_s.include?(Schedule.weekday_name)
            for i in 1..24
              next if final_object.values[i - 1] > 999

              assert_in_epsilon(expected_values['clg_wkday_setpoints'][i - 1], UnitConversions.convert(final_object.values[i - 1], 'C', 'F'))
              end
          elsif final_object.name.to_s.include?(Schedule.weekend_name)
            for i in 1..24
              next if final_object.values[i - 1] > 999

              assert_in_epsilon(expected_values['clg_wked_setpoints'][i - 1], UnitConversions.convert(final_object.values[i - 1], 'C', 'F'))
              end
          else
            flunk('Unexpected schedule.')
          end
        end
      end
    end

    return model
  end
end
