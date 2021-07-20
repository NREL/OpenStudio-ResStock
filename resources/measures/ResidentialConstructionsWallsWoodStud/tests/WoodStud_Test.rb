# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessConstructionsWallsWoodStudTest < MiniTest::Test
  def test_uninsulated_and_insulate
    args_hash = {}
    args_hash['cavity_r'] = 0
    args_hash['install_grade'] = '3' # no insulation, shouldn't apply
    args_hash['cavity_depth_in'] = 3.5
    args_hash['cavity_filled'] = false
    args_hash['framing_factor'] = 0.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 6, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    cavity_r = 0.0889 / 0.3382210801424572
    assembly_r = ext_finish_r + osb_r + drywall_r + cavity_r
    expected_values = { 'AssemblyR' => assembly_r }
    model = _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    # Add R-13 Gr-II insulation
    args_hash['cavity_r'] = 13
    args_hash['cavity_filled'] = true
    args_hash['install_grade'] = '2'
    expected_num_del_objects = { 'Material' => 1, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    expected_num_new_objects = { 'Material' => 1, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    cavity_r = 0.0889 / 0.0569424553543112
    assembly_r = ext_finish_r + osb_r + drywall_r + cavity_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_r7_2x4
    args_hash = {}
    args_hash['cavity_r'] = 7
    args_hash['install_grade'] = '1'
    args_hash['cavity_depth_in'] = 3.5
    args_hash['cavity_filled'] = false
    args_hash['framing_factor'] = 0.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 6, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    cavity_r = 0.0889 / 0.0744829291443118
    assembly_r = ext_finish_r + osb_r + drywall_r + cavity_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_r13_2x4_gr2
    args_hash = {}
    args_hash['cavity_r'] = 13
    args_hash['install_grade'] = '2'
    args_hash['cavity_depth_in'] = 3.5
    args_hash['cavity_filled'] = true
    args_hash['framing_factor'] = 0.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 6, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    cavity_r = 0.0889 / 0.0569424553543112
    assembly_r = ext_finish_r + osb_r + drywall_r + cavity_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_r21_2x6_ff15
    args_hash = {}
    args_hash['cavity_r'] = 21
    args_hash['install_grade'] = '1'
    args_hash['cavity_depth_in'] = 5.5
    args_hash['cavity_filled'] = true
    args_hash['framing_factor'] = 0.15
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 6, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    cavity_r = 0.1397 / 0.0475738422192927
    assembly_r = ext_finish_r + osb_r + drywall_r + cavity_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_r21_2x6_ff15_etc
    args_hash = {}
    args_hash['cavity_r'] = 21
    args_hash['install_grade'] = '1'
    args_hash['cavity_depth_in'] = 5.5
    args_hash['cavity_filled'] = true
    args_hash['framing_factor'] = 0.15
    args_hash['drywall_thick_in'] = 1.0
    args_hash['osb_thick_in'] = 0
    args_hash['rigid_r'] = 10
    args_hash['exterior_finish'] = Material.ExtFinishBrickMedDark.name
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 7, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.1016 / 0.793375
    drywall_r = 0.0254 / 0.1602906
    cavity_r = 0.1397 / 0.0448317763517687
    rigid_r = 0.0508 / 0.02885
    assembly_r = ext_finish_r + rigid_r + drywall_r + cavity_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction
    args_hash = {}
    args_hash['cavity_r'] = 0
    args_hash['install_grade'] = '3' # no insulation, shouldn't apply
    args_hash['cavity_depth_in'] = 3.5
    args_hash['cavity_filled'] = false
    args_hash['framing_factor'] = 0.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 9, 'Construction' => 6, 'InternalMass' => 2, 'InternalMassDefinition' => 2 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    cavity_r = 0.0889 / 0.3382210801424572
    assembly_r = ext_finish_r + osb_r + drywall_r + cavity_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction
    args_hash = {}
    args_hash['cavity_r'] = 0
    args_hash['install_grade'] = '3' # no insulation, shouldn't apply
    args_hash['cavity_depth_in'] = 3.5
    args_hash['cavity_filled'] = false
    args_hash['framing_factor'] = 0.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 9, 'Construction' => 6, 'InternalMass' => 2, 'InternalMassDefinition' => 2 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    cavity_r = 0.0889 / 0.3382210801424572
    assembly_r = ext_finish_r + osb_r + drywall_r + cavity_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_argument_error_cavity_r_negative
    args_hash = {}
    args_hash['cavity_r'] = -1
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Cavity Insulation Installed R-value must be greater than or equal to 0.')
  end

  def test_argument_error_cavity_depth_negative
    args_hash = {}
    args_hash['cavity_depth_in'] = -1
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Cavity Depth must be greater than 0.')
  end

  def test_argument_error_cavity_depth_zero
    args_hash = {}
    args_hash['cavity_depth_in'] = 0
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Cavity Depth must be greater than 0.')
  end

  def test_argument_error_framing_factor_negative
    args_hash = {}
    args_hash['framing_factor'] = -1
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Framing Factor must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_framing_factor_eq_1
    args_hash = {}
    args_hash['framing_factor'] = 1.0
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Framing Factor must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_none_ext_finish
    args_hash = {}
    args_hash['exterior_finish'] = 'None, Brick'
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], "Wood stud walls cannot have a 'None' exterior finish")
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ProcessConstructionsWallsWoodStud.new

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

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    # create an instance of the measure
    measure = ProcessConstructionsWallsWoodStud.new

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
    obj_type_exclusions = []
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    actual_values = { 'AssemblyR' => 0 }
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        next unless obj_type == 'Construction'
        next if not new_object.name.to_s.start_with? Constants.SurfaceTypeWallExtInsFin

        new_object.to_LayeredConstruction.get.layers.each do |layer|
          material = layer.to_StandardOpaqueMaterial.get
          actual_values['AssemblyR'] += material.thickness / material.conductivity
        end
      end
    end
    assert_in_epsilon(expected_values['AssemblyR'], actual_values['AssemblyR'], 0.01)

    return model
  end
end
