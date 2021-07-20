# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessConstructionsUnfinishedBasementTest < MiniTest::Test
  def test_uninsulated
    args_hash = {}
    args_hash['wall_ins_height'] = 0
    args_hash['wall_cavity_r'] = 0
    args_hash['wall_install_grade'] = '2' # no insulation, shouldn't apply
    args_hash['wall_cavity_depth_in'] = 0
    args_hash['wall_filled_cavity'] = true
    args_hash['wall_framing_factor'] = 0
    args_hash['wall_rigid_r'] = 0
    args_hash['ceiling_cavity_r'] = 0
    args_hash['ceiling_install_grade'] = '2' # no insulation, shouldn't apply
    args_hash['ceiling_framing_factor'] = 0.13
    args_hash['ceiling_joist_height_in'] = 9.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 6, 'Construction' => 4, 'FoundationKiva' => 1, 'FoundationKivaSettings' => 1, 'SurfacePropertyExposedFoundationPerimeter' => 1 }
    ceiling_ins_r = 0.23495 / 2.598173704068639
    ceiling_plywood_r = 0.01905 / 0.1154577
    ceiling_mass_r = 0.015875 / 0.1154577
    ceiling_carpet_r = 0.0127 / 0.0433443509615385
    ceiling_r = ceiling_ins_r + ceiling_plywood_r + ceiling_mass_r + ceiling_carpet_r
    expected_values = { 'WallRValue' => 0, 'WallDepth' => 0, 'CeilingRValue' => ceiling_r, 'ExposedPerimeter' => 134.165 }
    _test_measure('SFD_2000sqft_2story_UB_UA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_half_wall_r10
    args_hash = {}
    args_hash['wall_ins_height'] = 4
    args_hash['wall_cavity_r'] = 0
    args_hash['wall_install_grade'] = '2' # no insulation, shouldn't apply
    args_hash['wall_cavity_depth_in'] = 0
    args_hash['wall_filled_cavity'] = true
    args_hash['wall_framing_factor'] = 0
    args_hash['wall_rigid_r'] = 10
    args_hash['ceiling_cavity_r'] = 0
    args_hash['ceiling_install_grade'] = '2' # no insulation, shouldn't apply
    args_hash['ceiling_framing_factor'] = 0.13
    args_hash['ceiling_joist_height_in'] = 9.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 7, 'Construction' => 4, 'FoundationKiva' => 1, 'FoundationKivaSettings' => 1, 'SurfacePropertyExposedFoundationPerimeter' => 1 }
    ceiling_ins_r = 0.23495 / 2.598173704068639
    ceiling_plywood_r = 0.01905 / 0.1154577
    ceiling_mass_r = 0.015875 / 0.1154577
    ceiling_carpet_r = 0.0127 / 0.0433443509615385
    ceiling_r = ceiling_ins_r + ceiling_plywood_r + ceiling_mass_r + ceiling_carpet_r
    expected_values = { 'WallRValue' => 1.76, 'WallDepth' => 1.22, 'CeilingRValue' => ceiling_r, 'ExposedPerimeter' => 134.165 }
    _test_measure('SFD_2000sqft_2story_UB_UA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_whole_wall_r10
    args_hash = {}
    args_hash['wall_ins_height'] = 8
    args_hash['wall_cavity_r'] = 0
    args_hash['wall_install_grade'] = '2' # no insulation, shouldn't apply
    args_hash['wall_cavity_depth_in'] = 0
    args_hash['wall_filled_cavity'] = true
    args_hash['wall_framing_factor'] = 0
    args_hash['wall_rigid_r'] = 10
    args_hash['ceiling_cavity_r'] = 0
    args_hash['ceiling_install_grade'] = '2' # no insulation, shouldn't apply
    args_hash['ceiling_framing_factor'] = 0.13
    args_hash['ceiling_joist_height_in'] = 9.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 7, 'Construction' => 4, 'FoundationKiva' => 1, 'FoundationKivaSettings' => 1, 'SurfacePropertyExposedFoundationPerimeter' => 1 }
    ceiling_ins_r = 0.23495 / 2.598173704068639
    ceiling_plywood_r = 0.01905 / 0.1154577
    ceiling_mass_r = 0.015875 / 0.1154577
    ceiling_carpet_r = 0.0127 / 0.0433443509615385
    ceiling_r = ceiling_ins_r + ceiling_plywood_r + ceiling_mass_r + ceiling_carpet_r
    expected_values = { 'WallRValue' => 1.76, 'WallDepth' => 2.44, 'CeilingRValue' => ceiling_r, 'ExposedPerimeter' => 134.165 }
    _test_measure('SFD_2000sqft_2story_UB_UA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_whole_wall_r13_plus_r5
    args_hash = {}
    args_hash['wall_ins_height'] = 8
    args_hash['wall_cavity_r'] = 13
    args_hash['wall_install_grade'] = '2'
    args_hash['wall_cavity_depth_in'] = 3.5
    args_hash['wall_filled_cavity'] = true
    args_hash['wall_framing_factor'] = 0.25
    args_hash['wall_rigid_r'] = 5
    args_hash['ceiling_cavity_r'] = 0
    args_hash['ceiling_install_grade'] = '2' # no insulation, shouldn't apply
    args_hash['ceiling_framing_factor'] = 0.13
    args_hash['ceiling_joist_height_in'] = 9.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 8, 'Construction' => 4, 'FoundationKiva' => 1, 'FoundationKivaSettings' => 1, 'SurfacePropertyExposedFoundationPerimeter' => 1 }
    ceiling_ins_r = 0.23495 / 2.598173704068639
    ceiling_plywood_r = 0.01905 / 0.1154577
    ceiling_mass_r = 0.015875 / 0.1154577
    ceiling_carpet_r = 0.0127 / 0.0433443509615385
    ceiling_r = ceiling_ins_r + ceiling_plywood_r + ceiling_mass_r + ceiling_carpet_r
    expected_values = { 'WallRValue' => 1.79 + 0.88, 'WallDepth' => 2.44 + 2.44, 'CeilingRValue' => ceiling_r, 'ExposedPerimeter' => 134.165 }
    _test_measure('SFD_2000sqft_2story_UB_UA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_ceiling_r13_gr3
    args_hash = {}
    args_hash['wall_ins_height'] = 0
    args_hash['wall_cavity_r'] = 0
    args_hash['wall_install_grade'] = '2' # no insulation, shouldn't apply
    args_hash['wall_cavity_depth_in'] = 0
    args_hash['wall_filled_cavity'] = true
    args_hash['wall_framing_factor'] = 0
    args_hash['wall_rigid_r'] = 0
    args_hash['ceiling_cavity_r'] = 13
    args_hash['ceiling_install_grade'] = '3'
    args_hash['ceiling_framing_factor'] = 0.13
    args_hash['ceiling_joist_height_in'] = 9.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 6, 'Construction' => 4, 'FoundationKiva' => 1, 'FoundationKivaSettings' => 1, 'SurfacePropertyExposedFoundationPerimeter' => 1 }
    ceiling_ins_r = 0.23495 / 0.1168615354327202
    ceiling_plywood_r = 0.01905 / 0.1154577
    ceiling_mass_r = 0.015875 / 0.1154577
    ceiling_carpet_r = 0.0127 / 0.0433443509615385
    ceiling_r = ceiling_ins_r + ceiling_plywood_r + ceiling_mass_r + ceiling_carpet_r
    expected_values = { 'WallRValue' => 0, 'WallDepth' => 0, 'CeilingRValue' => ceiling_r, 'ExposedPerimeter' => 134.165 }
    _test_measure('SFD_2000sqft_2story_UB_UA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_exposed_perimeter_with_garage
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 8, 'Construction' => 6, 'FoundationKiva' => 2, 'FoundationKivaSettings' => 1, 'SurfacePropertyExposedFoundationPerimeter' => 2 }
    expected_values = { 'ExposedPerimeter' => 107 }
    _test_measure('SFD_2000sqft_2story_UB_GRG_UA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 7, 'Construction' => 4, 'FoundationKiva' => num_units, 'FoundationKivaSettings' => 1, 'SurfacePropertyExposedFoundationPerimeter' => num_units }
    expected_values = { 'ExposedPerimeter' => 21.21 + 21.21 + 42.43 }
    _test_measure('SFA_4units_1story_UB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction2
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 7, 'Construction' => 4, 'FoundationKiva' => num_units, 'FoundationKivaSettings' => 1, 'SurfacePropertyExposedFoundationPerimeter' => num_units }
    expected_values = { 'ExposedPerimeter' => 15 + 15 + 30 }
    _test_measure('SFA_10units_2story_UB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction
    num_units = 1 + 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 8, 'Construction' => 6, 'FoundationKiva' => num_units, 'FoundationKivaSettings' => 1, 'SurfacePropertyExposedFoundationPerimeter' => 2 }
    expected_values = { 'ExposedPerimeter' => 42.43 + 21.21 + 5 }
    _test_measure('MF_8units_1story_UB_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction2
    num_units = 1 + 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 8, 'Construction' => 6, 'FoundationKiva' => num_units, 'FoundationKivaSettings' => 1, 'SurfacePropertyExposedFoundationPerimeter' => 2 }
    expected_values = { 'ExposedPerimeter' => 42.43 + 21.21 + 5 }
    _test_measure('MF_40units_4story_UB_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_argument_error_wall_ins_height_negative
    args_hash = {}
    args_hash['wall_ins_height'] = -1
    result = _test_error('SFD_2000sqft_2story_UB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Wall Insulation Height must be greater than or equal to 0.')
  end

  def test_argument_error_wall_ins_height_negative
    args_hash = {}
    args_hash['wall_cavity_r'] = -1
    result = _test_error('SFD_2000sqft_2story_UB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Wall Cavity Insulation Installed R-value must be greater than or equal to 0.')
  end

  def test_argument_error_wall_cavity_depth_in_negative
    args_hash = {}
    args_hash['wall_cavity_depth_in'] = -1
    result = _test_error('SFD_2000sqft_2story_UB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Wall Cavity Depth must be greater than or equal to 0.')
  end

  def test_argument_error_framing_factor_negative
    args_hash = {}
    args_hash['wall_framing_factor'] = -1
    result = _test_error('SFD_2000sqft_2story_UB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Wall Framing Factor must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_framing_factor_eq_1
    args_hash = {}
    args_hash['wall_framing_factor'] = 1.0
    result = _test_error('SFD_2000sqft_2story_UB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Wall Framing Factor must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_wall_rigid_r_negative
    args_hash = {}
    args_hash['wall_rigid_r'] = -1
    result = _test_error('SFD_2000sqft_2story_UB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Wall Continuous Insulation Nominal R-value must be greater than or equal to 0.')
  end

  def test_argument_error_ceiling_cavity_r_negative
    args_hash = {}
    args_hash['ceiling_cavity_r'] = -1
    result = _test_error('SFD_2000sqft_2story_UB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Ceiling Cavity Insulation Nominal R-value must be greater than or equal to 0.')
  end

  def test_argument_error_ceiling_framing_factor_negative
    args_hash = {}
    args_hash['ceiling_framing_factor'] = -1
    result = _test_error('SFD_2000sqft_2story_UB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Ceiling Framing Factor must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_ceiling_framing_factor_eq_1
    args_hash = {}
    args_hash['ceiling_framing_factor'] = 1
    result = _test_error('SFD_2000sqft_2story_UB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Ceiling Framing Factor must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_ceiling_joist_height_in_zero
    args_hash = {}
    args_hash['ceiling_joist_height_in'] = 0
    result = _test_error('SFD_2000sqft_2story_UB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Ceiling Joist Height must be greater than 0.')
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ProcessConstructionsUnfinishedBasement.new

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
    measure = ProcessConstructionsUnfinishedBasement.new

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

    actual_values = { 'WallRValue' => 0, 'WallDepth' => 0, 'CeilingRValue' => 0, 'ExposedPerimeter' => 0 }
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        if obj_type == 'FoundationKiva'
          if new_object.interiorVerticalInsulationMaterial.is_initialized
            mat = new_object.interiorVerticalInsulationMaterial.get.to_StandardOpaqueMaterial.get
            actual_values['WallRValue'] += mat.thickness / mat.conductivity
          end
          if new_object.interiorVerticalInsulationDepth.is_initialized
            actual_values['WallDepth'] += new_object.interiorVerticalInsulationDepth.get
          end
          if new_object.exteriorVerticalInsulationMaterial.is_initialized
            mat = new_object.exteriorVerticalInsulationMaterial.get.to_StandardOpaqueMaterial.get
            actual_values['WallRValue'] += mat.thickness / mat.conductivity
          end
          if new_object.exteriorVerticalInsulationDepth.is_initialized
            actual_values['WallDepth'] += new_object.exteriorVerticalInsulationDepth.get
          end
        elsif obj_type == 'Construction'
          if new_object.name.to_s.start_with?(Constants.SurfaceTypeFloorUnfinBInsFin) && (not new_object.name.to_s.include? 'Reversed')
            new_object.to_LayeredConstruction.get.layers.each do |layer|
              mat = layer.to_StandardOpaqueMaterial.get
              actual_values['CeilingRValue'] += mat.thickness / mat.conductivity
            end
          elsif new_object.name.to_s.start_with? Constants.SurfaceTypeFloorFndGrndUnfinB
            model.getSurfaces.each do |surface|
              next if not surface.construction.is_initialized
              next if surface.construction.get.name.to_s != new_object.name.to_s
              next if not surface.surfacePropertyExposedFoundationPerimeter.is_initialized

              actual_values['ExposedPerimeter'] += UnitConversions.convert(surface.surfacePropertyExposedFoundationPerimeter.get.totalExposedPerimeter.get, 'm', 'ft')
            end
          end
        end
      end
    end

    if not expected_values['WallRValue'].nil?
      assert_in_epsilon(expected_values['WallRValue'], actual_values['WallRValue'], 0.01)
    end
    if not expected_values['WallDepth'].nil?
      assert_in_epsilon(expected_values['WallDepth'], actual_values['WallDepth'], 0.01)
    end
    if not expected_values['CeilingRValue'].nil?
      assert_in_epsilon(expected_values['CeilingRValue'], actual_values['CeilingRValue'], 0.03)
    end
    if not expected_values['ExposedPerimeter'].nil?
      assert_in_epsilon(expected_values['ExposedPerimeter'], actual_values['ExposedPerimeter'], 0.01)
    end

    return model
  end
end
