# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessConstructionsWallsGenericTest < MiniTest::Test
  def test_tmass_wall_metal_ties
    args_hash = {}
    args_hash['thick_in_1'] = 2.5
    args_hash['thick_in_2'] = 3.0
    args_hash['thick_in_3'] = 2.5
    args_hash['conductivity_1'] = 9.211
    args_hash['conductivity_2'] = 0.425
    args_hash['conductivity_3'] = 7.471
    args_hash['density_1'] = 138.33
    args_hash['density_2'] = 2.6
    args_hash['density_3'] = 136.59
    args_hash['specific_heat_1'] = 0.23
    args_hash['specific_heat_2'] = 0.28
    args_hash['specific_heat_3'] = 0.28
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 8, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    layer1_r = 0.0635 / 1.3286867500000001
    layer2_r = 0.0762 / 0.06130625
    layer3_r = 0.0635 / 1.07769175
    assembly_r = ext_finish_r + osb_r + drywall_r + layer1_r + layer2_r + layer3_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_10in_grid_icf_and_replace
    args_hash = {}
    args_hash['thick_in_1'] = 2.75
    args_hash['thick_in_2'] = 3.725
    args_hash['thick_in_3'] = 3.5
    args_hash['conductivity_1'] = 0.4429
    args_hash['conductivity_2'] = 3.457
    args_hash['conductivity_3'] = 0.927
    args_hash['density_1'] = 66.48
    args_hash['density_2'] = 97.0
    args_hash['density_3'] = 52.03
    args_hash['specific_heat_1'] = 0.25
    args_hash['specific_heat_2'] = 0.21
    args_hash['specific_heat_3'] = 0.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 8, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    layer1_r = 0.06985 / 0.063888325
    layer2_r = 0.094615 / 0.49867225
    layer3_r = 0.0889 / 0.13371975
    assembly_r = ext_finish_r + osb_r + drywall_r + layer1_r + layer2_r + layer3_r
    expected_values = { 'AssemblyR' => assembly_r }
    model = _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    # Replace
    expected_num_del_objects = { 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    expected_num_new_objects = { 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_10in_grid_icf_etc
    args_hash = {}
    args_hash['thick_in_1'] = 2.75
    args_hash['thick_in_2'] = 3.725
    args_hash['thick_in_3'] = 3.5
    args_hash['conductivity_1'] = 0.4429
    args_hash['conductivity_2'] = 3.457
    args_hash['conductivity_3'] = 0.927
    args_hash['density_1'] = 66.48
    args_hash['density_2'] = 97.0
    args_hash['density_3'] = 52.03
    args_hash['specific_heat_1'] = 0.25
    args_hash['specific_heat_2'] = 0.21
    args_hash['specific_heat_3'] = 0.25
    args_hash['drywall_thick_in'] = 1.0
    args_hash['osb_thick_in'] = 0
    args_hash['rigid_r'] = 10
    args_hash['exterior_finish'] = Material.ExtFinishBrickMedDark.name
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 9, 'Construction' => 5, 'InternalMass' => 4, 'InternalMassDefinition' => 4 }
    ext_finish_r = 0.1016 / 0.793375
    drywall_r = 0.0254 / 0.1602906
    layer1_r = 0.06985 / 0.063888325
    layer2_r = 0.094615 / 0.49867225
    layer3_r = 0.0889 / 0.13371975
    rigid_r = 0.0508 / 0.02885
    assembly_r = ext_finish_r + rigid_r + drywall_r + layer1_r + layer2_r + layer3_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction
    args_hash = {}
    args_hash['thick_in_1'] = 2.5
    args_hash['thick_in_2'] = 3.0
    args_hash['thick_in_3'] = 2.5
    args_hash['conductivity_1'] = 9.211
    args_hash['conductivity_2'] = 0.425
    args_hash['conductivity_3'] = 7.471
    args_hash['density_1'] = 138.33
    args_hash['density_2'] = 2.6
    args_hash['density_3'] = 136.59
    args_hash['specific_heat_1'] = 0.23
    args_hash['specific_heat_2'] = 0.28
    args_hash['specific_heat_3'] = 0.28
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 11, 'Construction' => 6, 'InternalMass' => 2, 'InternalMassDefinition' => 2 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    layer1_r = 0.0635 / 1.3286867500000001
    layer2_r = 0.0762 / 0.06130625
    layer3_r = 0.0635 / 1.07769175
    assembly_r = ext_finish_r + osb_r + drywall_r + layer1_r + layer2_r + layer3_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('SFA_4units_1story_SL_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction
    args_hash = {}
    args_hash['thick_in_1'] = 2.5
    args_hash['thick_in_2'] = 3.0
    args_hash['thick_in_3'] = 2.5
    args_hash['conductivity_1'] = 9.211
    args_hash['conductivity_2'] = 0.425
    args_hash['conductivity_3'] = 7.471
    args_hash['density_1'] = 138.33
    args_hash['density_2'] = 2.6
    args_hash['density_3'] = 136.59
    args_hash['specific_heat_1'] = 0.23
    args_hash['specific_heat_2'] = 0.28
    args_hash['specific_heat_3'] = 0.28
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 11, 'Construction' => 6, 'InternalMass' => 2, 'InternalMassDefinition' => 2 }
    ext_finish_r = 0.009525 / 0.089435
    osb_r = 0.0127 / 0.1154577
    drywall_r = 0.0127 / 0.1602906
    layer1_r = 0.0635 / 1.3286867500000001
    layer2_r = 0.0762 / 0.06130625
    layer3_r = 0.0635 / 1.07769175
    assembly_r = ext_finish_r + osb_r + drywall_r + layer1_r + layer2_r + layer3_r
    expected_values = { 'AssemblyR' => assembly_r }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_argument_error_thick_in_zero
    (1..5).each do |layer_num|
      args_hash = {}
      args_hash["thick_in_#{layer_num}"] = 0
      args_hash["conductivity_#{layer_num}"] = 0.5
      args_hash["density_#{layer_num}"] = 0.5
      args_hash["specific_heat_#{layer_num}"] = 0.5
      result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
      assert_equal(result.errors.map { |x| x.logMessage }[0], "Thickness #{layer_num} must be greater than 0.")
    end
  end

  def test_argument_error_conductivity_zero
    (1..5).each do |layer_num|
      args_hash = {}
      args_hash["thick_in_#{layer_num}"] = 0.5
      args_hash["conductivity_#{layer_num}"] = 0
      args_hash["density_#{layer_num}"] = 0.5
      args_hash["specific_heat_#{layer_num}"] = 0.5
      result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
      assert_equal(result.errors.map { |x| x.logMessage }[0], "Conductivity #{layer_num} must be greater than 0.")
    end
  end

  def test_argument_error_density_zero
    (1..5).each do |layer_num|
      args_hash = {}
      args_hash["thick_in_#{layer_num}"] = 0.5
      args_hash["conductivity_#{layer_num}"] = 0.5
      args_hash["density_#{layer_num}"] = 0
      args_hash["specific_heat_#{layer_num}"] = 0.5
      result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
      assert_equal(result.errors.map { |x| x.logMessage }[0], "Density #{layer_num} must be greater than 0.")
    end
  end

  def test_argument_error_specific_heat_zero
    (1..5).each do |layer_num|
      args_hash = {}
      args_hash["thick_in_#{layer_num}"] = 0.5
      args_hash["conductivity_#{layer_num}"] = 0.5
      args_hash["density_#{layer_num}"] = 0.5
      args_hash["specific_heat_#{layer_num}"] = 0
      result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
      assert_equal(result.errors.map { |x| x.logMessage }[0], "Specific Heat #{layer_num} must be greater than 0.")
    end
  end

  def test_argument_error_layer_missing_properties
    (2..5).each do |layer_num|
      args_hash = {}
      args_hash['thick_in_1'] = 0.5
      if layer_num != 2
        args_hash['thick_in_2'] = 0.5
      end
      args_hash['thick_in_3'] = 0.5
      args_hash['thick_in_4'] = 0.5
      args_hash['thick_in_5'] = 0.5
      args_hash['conductivity_1'] = 0.5
      args_hash['conductivity_2'] = 0.5
      if layer_num != 3
        args_hash['conductivity_3'] = 0.5
      end
      args_hash['conductivity_4'] = 0.5
      args_hash['conductivity_5'] = 0.5
      args_hash['density_1'] = 0.5
      args_hash['density_2'] = 0.5
      args_hash['density_3'] = 0.5
      if layer_num != 4
        args_hash['density_4'] = 0.5
      end
      args_hash['density_5'] = 0.5
      args_hash['specific_heat_1'] = 0.5
      args_hash['specific_heat_2'] = 0.5
      args_hash['specific_heat_3'] = 0.5
      args_hash['specific_heat_4'] = 0.5
      if layer_num != 5
        args_hash['specific_heat_5'] = 0.5
      end
      result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
      assert_equal(result.errors.map { |x| x.logMessage }[0], "Layer #{layer_num} does not have all four properties (thickness, conductivity, density, specific heat) entered.")
    end
  end

  def test_argument_error_none_ext_finish
    args_hash = {}
    args_hash['exterior_finish'] = 'None, Brick'
    result = _test_error('SFD_2000sqft_2story_SL_UA_CeilingIns.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], "Generic wall type cannot have a 'None' exterior finish")
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ProcessConstructionsWallsGeneric.new

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
    measure = ProcessConstructionsWallsGeneric.new

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
