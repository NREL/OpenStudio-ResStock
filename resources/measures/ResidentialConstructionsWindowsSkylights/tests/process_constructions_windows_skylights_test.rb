# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessConstructionsWindowsSkylightsTest < MiniTest::Test
  def test_no_solar_gain_reduction
    args_hash = {}
    args_hash['window_heat_shade_mult'] = 1
    args_hash['window_cool_shade_mult'] = 1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SimpleGlazing' => 1, 'Construction' => 1 }
    expected_values = { 'shgc' => 0.3, 'ufactor' => 0.37, 'SubSurfacesWithConstructions' => 36, 'SubSurfacesWithShadingControls' => 0 }
    result = _test_measure('SFD_2000sqft_2story_SL_UA_Denver_Windows.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_retrofit_replace
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SimpleGlazing' => 1, 'Construction' => 1, 'ShadingControl' => 1, 'WindowMaterialShade' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'shgc' => 0.3 * 0.7, 'ufactor' => 0.37, 'SubSurfacesWithConstructions' => 36, 'SubSurfacesWithShadingControls' => 36 }
    model = _test_measure('SFD_2000sqft_2story_SL_UA_Denver_Windows.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['window_ufactor'] = 0.20
    args_hash['window_shgc'] = 0.5
    args_hash['window_heat_shade_mult'] = 1
    args_hash['window_cool_shade_mult'] = 1
    expected_num_del_objects = expected_num_new_objects
    expected_num_new_objects = { 'SimpleGlazing' => 1, 'Construction' => 1 }
    expected_values = { 'shgc' => 0.5, 'ufactor' => 0.20, 'SubSurfacesWithConstructions' => 36, 'SubSurfacesWithShadingControls' => 0 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SimpleGlazing' => 1, 'Construction' => 1, 'ShadingControl' => 1, 'WindowMaterialShade' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'shgc' => 0.3 * 0.7, 'ufactor' => 0.37, 'SubSurfacesWithConstructions' => 12, 'SubSurfacesWithShadingControls' => 12 }
    _test_measure('SFA_4units_1story_SL_UA_Denver_Windows_Doors.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SimpleGlazing' => 1, 'Construction' => 1, 'ShadingControl' => 1, 'WindowMaterialShade' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'shgc' => 0.3 * 0.7, 'ufactor' => 0.37, 'SubSurfacesWithConstructions' => 9, 'SubSurfacesWithShadingControls' => 9 }
    _test_measure('MF_8units_1story_SL_Denver_Windows_Doors.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_argument_error_invalid_ufactor
    args_hash = {}
    args_hash['window_ufactor'] = 0
    result = _test_error('SFD_2000sqft_2story_SL_UA_Denver_Windows.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Window U-factor must be greater than zero.')
  end

  def test_argument_error_invalid_shgc
    args_hash = {}
    args_hash['window_shgc'] = 0
    result = _test_error('SFD_2000sqft_2story_SL_UA_Denver_Windows.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Window SHGC must be greater than zero.')
  end

  def test_error_no_weather
    args_hash = {}
    result = _test_error('SFD_2000sqft_2story_SL_UA_Windows.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Model has not been assigned a weather file.')
  end

  def test_windows_and_skylights
    args_hash = {}
    args_hash['skylight_ufactor'] = 0.20
    args_hash['skylight_shgc'] = 0.5
    args_hash['skylight_heat_shade_mult'] = 0.7
    args_hash['skylight_cool_shade_mult'] = 0.7
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SimpleGlazing' => 2, 'Construction' => 2, 'ShadingControl' => 2, 'WindowMaterialShade' => 1, 'ScheduleRuleset' => 2 }
    expected_values = { 'shgc' => 0.3 * 0.7 + 0.5 * 0.7, 'ufactor' => 0.37 + 0.20, 'SubSurfacesWithConstructions' => 34, 'SubSurfacesWithShadingControls' => 34 }
    result = _test_measure('SFD_2000sqft_2story_SL_FA_Denver_Windows_Skylights.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ProcessConstructionsWindowsSkylights.new

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

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    # create an instance of the measure
    measure = ProcessConstructionsWindowsSkylights.new

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

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = ['ScheduleRule', 'ScheduleDay', 'ScheduleTypeLimits']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    actual_values = { 'shgc' => 0, 'ufactor' => 0, 'SubSurfacesWithConstructions' => 0, 'SubSurfacesWithShadingControls' => 0 }
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        if obj_type == 'SimpleGlazing'
          new_object = new_object.to_SimpleGlazing.get
          actual_values['ufactor'] += UnitConversions.convert(new_object.uFactor, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
          actual_values['shgc'] += new_object.solarHeatGainCoefficient
        elsif obj_type == 'Construction'
          model.getSubSurfaces.each do |sub_surface|
            next unless sub_surface.construction.is_initialized
            next unless sub_surface.construction.get == new_object

            actual_values['SubSurfacesWithConstructions'] += 1
          end
        elsif obj_type == 'ShadingControl'
          model.getSubSurfaces.each do |sub_surface|
            next unless sub_surface.shadingControl.is_initialized
            next unless sub_surface.shadingControl.get == new_object

            actual_values['SubSurfacesWithShadingControls'] += 1
          end
        end
      end
    end
    assert_in_epsilon(expected_values['shgc'], actual_values['shgc'], 0.01)
    assert_in_epsilon(expected_values['ufactor'], actual_values['ufactor'], 0.01)
    assert_equal(expected_values['SubSurfacesWithConstructions'], actual_values['SubSurfacesWithConstructions'])
    assert_equal(expected_values['SubSurfacesWithShadingControls'], actual_values['SubSurfacesWithShadingControls'])

    return model
  end
end
