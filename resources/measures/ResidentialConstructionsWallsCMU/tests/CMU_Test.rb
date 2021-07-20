# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessConstructionsWallsCMUTest < MiniTest::Test
  def test_6in_hollow
    args_hash = {}
    args_hash['thick_in'] = 6
    args_hash['conductivity'] = 4.29
    args_hash['density'] = 65
    args_hash['framing_factor'] = 0.076
    args_hash['furring_r'] = 0
    args_hash['furring_cavity_depth_in'] = 1
    args_hash['furring_spacing'] = 24
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 7, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    cmu_r = 0.1524 / 0.538472282078089
    furring_r = 0.0254 / 0.14026226645
    assembly_r = ext_finish_r + osb_r + drywall_r + cmu_r + furring_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_6in_hollow_no_furring_and_replace
    args_hash = {}
    args_hash['thick_in'] = 6
    args_hash['conductivity'] = 4.29
    args_hash['density'] = 65
    args_hash['framing_factor'] = 0.076
    args_hash['furring_r'] = 0
    args_hash['furring_cavity_depth_in'] = 0
    args_hash['furring_spacing'] = 0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 6, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    cmu_r = 0.1524 / 0.538472282078089
    assembly_r = ext_finish_r + osb_r + drywall_r + cmu_r
    expected_values = { 'AssemblyR' => assembly_r }
    model = _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    # Replace
    expected_num_del_objects = { 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    expected_num_new_objects = { 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_8in_hollow_r10
    args_hash = {}
    args_hash['thick_in'] = 8
    args_hash['conductivity'] = 4
    args_hash['density'] = 45
    args_hash['framing_factor'] = 0.076
    args_hash['furring_r'] = 10
    args_hash['furring_cavity_depth_in'] = 2
    args_hash['furring_spacing'] = 24
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 7, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    cmu_r = 0.2032 / 0.284117053906069
    furring_r = 0.0508 / 0.04084516645
    assembly_r = ext_finish_r + osb_r + drywall_r + cmu_r + furring_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_6in_concrete_filled_etc
    args_hash = {}
    args_hash['thick_in'] = 6
    args_hash['conductivity'] = 5.33
    args_hash['density'] = 119
    args_hash['framing_factor'] = 0.076
    args_hash['furring_r'] = 0
    args_hash['furring_cavity_depth_in'] = 1
    args_hash['furring_spacing'] = 24
    args_hash['drywall_thick_in'] = 1.0
    args_hash['osb_thick_in'] = 0
    args_hash['rigid_r'] = 10
    args_hash['exterior_finish'] = Material.ExtFinishBrickMedDark.name
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 8, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.1016 / 0.793375
    drywall_r = 0.0254 / 0.1602906
    cmu_r = 0.1524 / 0.5895186350785937
    furring_r = 0.0254 / 0.14026226645
    rigid_r = 0.0508 / 0.02885
    assembly_r = ext_finish_r + drywall_r + cmu_r + furring_r + rigid_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_no_ext_finish_cmu
    args_hash = {}
    args_hash['thick_in'] = 6
    args_hash['conductivity'] = 4.29
    args_hash['density'] = 65
    args_hash['framing_factor'] = 0.076
    args_hash['furring_r'] = 0
    args_hash['furring_cavity_depth_in'] = 1
    args_hash['furring_spacing'] = 24
    args_hash['exterior_finish'] = 'None, CMU'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 7, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0
    osb_r = 0
    drywall_r = 0.0127 / 0.1602906
    cmu_r = 0.1524 / 0.562061786498589
    furring_r = 0.0254 / 0.13578938501631
    assembly_r = ext_finish_r + osb_r + drywall_r + cmu_r + furring_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_asbestos_shingle_ext_finish
    args_hash = {}
    args_hash['thick_in'] = 6
    args_hash['conductivity'] = 4.29
    args_hash['density'] = 65
    args_hash['framing_factor'] = 0.076
    args_hash['furring_r'] = 0
    args_hash['furring_cavity_depth_in'] = 1
    args_hash['furring_spacing'] = 24
    args_hash['exterior_finish'] = 'Asbestos Shingles'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 6, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.0094488 / 0.162714
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    cmu_r = 0.1524 / 0.562061786498589
    furring_r = 0.0254 / 0.13578938501631
    assembly_r = ext_finish_r + osb_r + drywall_r + cmu_r + furring_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_no_ext_finish_brick
    args_hash = {}
    args_hash['thick_in'] = 6
    args_hash['conductivity'] = 4.29
    args_hash['density'] = 65
    args_hash['framing_factor'] = 0.076
    args_hash['furring_r'] = 0
    args_hash['furring_cavity_depth_in'] = 1
    args_hash['furring_spacing'] = 24
    args_hash['exterior_finish'] = 'None, Brick'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 7, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0
    osb_r = 0
    drywall_r = 0.0127 / 0.1602906
    cmu_r = 0.1524 / 0.562061786498589
    furring_r = 0.0254 / 0.13578938501631
    assembly_r = ext_finish_r + osb_r + drywall_r + cmu_r + furring_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction
    args_hash = {}
    args_hash['thick_in'] = 6
    args_hash['conductivity'] = 4.29
    args_hash['density'] = 65
    args_hash['framing_factor'] = 0.076
    args_hash['furring_r'] = 0
    args_hash['furring_cavity_depth_in'] = 1
    args_hash['furring_spacing'] = 24
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 10, 'Construction' => 6, 'InternalMass' => 2, 'InternalMassDefinition' => 2 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    cmu_r = 0.1524 / 0.538472282078089
    furring_r = 0.0254 / 0.14026226645
    assembly_r = ext_finish_r + osb_r + drywall_r + cmu_r + furring_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction
    args_hash = {}
    args_hash['thick_in'] = 6
    args_hash['conductivity'] = 4.29
    args_hash['density'] = 65
    args_hash['framing_factor'] = 0.076
    args_hash['furring_r'] = 0
    args_hash['furring_cavity_depth_in'] = 1
    args_hash['furring_spacing'] = 24
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 10, 'Construction' => 6, 'InternalMass' => 2, 'InternalMassDefinition' => 2 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    cmu_r = 0.1524 / 0.538472282078089
    furring_r = 0.0254 / 0.14026226645
    assembly_r = ext_finish_r + osb_r + drywall_r + cmu_r + furring_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_argument_error_thickness_zero
    args_hash = {}
    args_hash['thick_in'] = 0
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'CMU Block Thickness must be greater than 0.')
  end

  def test_argument_error_conductivity_zero
    args_hash = {}
    args_hash['conductivity'] = 0
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'CMU Conductivity must be greater than 0.')
  end

  def test_argument_error_density_zero
    args_hash = {}
    args_hash['density'] = 0
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'CMU Density must be greater than 0.')
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

  def test_argument_error_furring_rvalue_negative
    args_hash = {}
    args_hash['furring_r'] = -1
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Furring Insulation R-value must be greater than or equal to 0.')
  end

  def test_argument_error_furring_spacing_negative
    args_hash = {}
    args_hash['furring_spacing'] = -1
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Furring Stud Spacing must be greater than or equal to 0.')
  end

  def test_argument_error_furring_cavity_depth_negative
    args_hash = {}
    args_hash['furring_cavity_depth_in'] = -1
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Furring Cavity Depth must be greater than or equal to 0.')
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ProcessConstructionsWallsCMU.new

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
    measure = ProcessConstructionsWallsCMU.new

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
