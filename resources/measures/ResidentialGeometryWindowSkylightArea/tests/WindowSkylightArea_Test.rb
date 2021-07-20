require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class WindowSkylightAreaTest < MiniTest::Test
  def test_no_window_area
    args_hash = {}
    args_hash['front_wwr'] = 0
    args_hash['back_wwr'] = 0
    args_hash['left_wwr'] = 0
    args_hash['right_wwr'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 0)
    assert_equal('Success', result.value.valueName)
    assert_equal(result.finalCondition.get.logMessage, 'No windows or skylights added.')
  end

  def test_below_minimum_window_area
    args_hash = {}
    args_hash['front_window_area'] = 5 # < min
    args_hash['back_window_area'] = 15 # > min
    args_hash['front_wwr'] = 0
    args_hash['back_wwr'] = 0
    args_hash['left_wwr'] = 0
    args_hash['right_wwr'] = 0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 2, 'ShadingSurface' => 2, 'ShadingSurfaceGroup' => 2 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    result = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Southwest.osm', args_hash, [0, 0, 0, 0, 0], [0, 20, 0, 0], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_sfd_new_construction_rotated
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 33, 'ShadingSurface' => 33, 'ShadingSurfaceGroup' => 33 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Southwest.osm', args_hash, [0, 0, 0, 0], [81.5, 110.3, 70.0, 55.1], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_sfd_new_construction_door_area
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Surface' => 2, 'SubSurface' => 10, 'ShadingSurface' => 10, 'ShadingSurfaceGroup' => 10 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    model = _test_measure('SFD_1000sqft_1story_FB_GRG_UA_DoorArea.osm', args_hash, [0, 0, 0, 0], [0.0, 59.0, 32.8, 15.5], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_sfd_new_construction_door_area2
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Surface' => 2, 'SubSurface' => 36, 'ShadingSurface' => 36, 'ShadingSurfaceGroup' => 36 }
    expected_values = { 'Constructions' => 1, 'OverhangDepth' => 2 }
    model = _test_measure('SFD_2000sqft_2story_SL_GRG_UA_Doors_OneConstruction.osm', args_hash, [0, 0, 0, 0], [100.0, 128.8, 78.8, 64.4], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_sfd_retrofit_replace
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 33, 'ShadingSurface' => 33, 'ShadingSurfaceGroup' => 33 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash, [0, 0, 0, 0], [81.5, 110.3, 70.0, 55.1], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['front_wwr'] = 0.12
    args_hash['left_wwr'] = 0.12
    expected_num_del_objects = { 'SubSurface' => 33, 'ShadingSurface' => 33, 'ShadingSurfaceGroup' => 33 }
    expected_num_new_objects = { 'SubSurface' => 27, 'ShadingSurface' => 27, 'ShadingSurfaceGroup' => 27 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure(model, args_hash, [81.5, 110.3, 70.0, 55.1], [54.3, 110.3, 46.4, 55.1], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_argument_error_invalid_window_area_front_lt_0
    args_hash = {}
    args_hash['front_wwr'] = -20
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Front window-to-wall ratio must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_invalid_window_area_back_lt_0
    args_hash = {}
    args_hash['back_wwr'] = -20
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Back window-to-wall ratio must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_invalid_window_area_left_lt_0
    args_hash = {}
    args_hash['left_wwr'] = -20
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Left window-to-wall ratio must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_invalid_window_area_right_lt_0
    args_hash = {}
    args_hash['right_wwr'] = -20
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Right window-to-wall ratio must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_invalid_window_area_front_eq_1
    args_hash = {}
    args_hash['front_wwr'] = 1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Front window-to-wall ratio must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_invalid_window_area_back_eq_1
    args_hash = {}
    args_hash['back_wwr'] = 1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Back window-to-wall ratio must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_invalid_window_area_left_eq_1
    args_hash = {}
    args_hash['left_wwr'] = 1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Left window-to-wall ratio must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_invalid_window_area_right_eq_1
    args_hash = {}
    args_hash['right_wwr'] = 1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Right window-to-wall ratio must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_invalid_aspect_ratio
    args_hash = {}
    args_hash['window_aspect_ratio'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Window Aspect Ratio must be greater than 0.')
  end

  def test_argument_error_both_front
    args_hash = {}
    args_hash['front_wwr'] = 0.5
    args_hash['front_window_area'] = 50
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Both front window-to-wall ratio and front window area are specified.')
  end

  def test_argument_error_both_back
    args_hash = {}
    args_hash['back_wwr'] = 0.5
    args_hash['back_window_area'] = 50
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Both back window-to-wall ratio and back window area are specified.')
  end

  def test_argument_error_both_left
    args_hash = {}
    args_hash['left_wwr'] = 0.5
    args_hash['left_window_area'] = 50
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Both left window-to-wall ratio and left window area are specified.')
  end

  def test_argument_error_both_right
    args_hash = {}
    args_hash['right_wwr'] = 0.5
    args_hash['right_window_area'] = 50
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Both right window-to-wall ratio and right window area are specified.')
  end

  def test_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    args_hash['back_wwr'] = 0.12
    args_hash['right_wwr'] = 0.12
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 8, 'ShadingSurface' => 8, 'ShadingSurfaceGroup' => 8 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure('SFA_4units_1story_FB_UA_Denver.osm', args_hash, [0, 0, 0, 0, 0], [86.4 / 4, 57.6 / 4, 43.2, 0], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction_areas
    num_units = 1
    args_hash = {}
    args_hash['front_wwr'] = 0.0
    args_hash['back_wwr'] = 0.0
    args_hash['left_wwr'] = 0.0
    args_hash['right_wwr'] = 0.0
    args_hash['front_window_area'] = 86.4 / 4
    args_hash['back_window_area'] = 57.6 / 4
    args_hash['left_window_area'] = 43.2
    args_hash['right_window_area'] = 0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 8, 'ShadingSurface' => 8, 'ShadingSurfaceGroup' => 8 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure('SFA_4units_1story_FB_UA_Denver.osm', args_hash, [0, 0, 0, 0, 0], [86.4 / 4, 57.6 / 4, 43.2, 0], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction_offset
    num_units = 1
    args_hash = {}
    args_hash['back_wwr'] = 0.12
    args_hash['right_wwr'] = 0.12
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 11, 'ShadingSurface' => 11, 'ShadingSurfaceGroup' => 11 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure('SFA_4units_1story_SL_UA_Offset.osm', args_hash, [0, 0, 0, 0, 0], [122.19 / 4, 81.46 / 4, 61.09, 0], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction
    num_units = 1
    args_hash = {}
    args_hash['back_wwr'] = 0.12
    args_hash['right_wwr'] = 0.12
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 9, 'ShadingSurface' => 9, 'ShadingSurfaceGroup' => 9 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, [0, 0, 0, 0, 0], [122.19 / 4, 0, 122.19 / 2, 0], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction_inset
    num_units = 1
    args_hash = {}
    args_hash['back_wwr'] = 0.12
    args_hash['right_wwr'] = 0.12
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 10, 'ShadingSurface' => 10, 'ShadingSurfaceGroup' => 10 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure('MF_8units_1story_SL_Inset.osm', args_hash, [0, 0, 0, 0, 0], [124.61 / 4, 0, 62.3, 5.76], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_sfd_retrofit_replace_one_construction
    args_hash = {}
    args_hash['front_wwr'] = 0.12
    args_hash['left_wwr'] = 0.12
    expected_num_del_objects = { 'SubSurface' => 36, 'ShadingSurface' => 36, 'ShadingSurfaceGroup' => 36 }
    expected_num_new_objects = { 'SubSurface' => 30, 'ShadingSurface' => 30, 'ShadingSurfaceGroup' => 30 }
    expected_values = { 'Constructions' => 1, 'OverhangDepth' => 2 }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_Windows_OneConstruction.osm', args_hash, [128.8, 128.8, 64.6, 64.4], [85.9, 128.8, 42.9, 64.6], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_error_invalid_overhang_depth
    args_hash = {}
    args_hash['overhang_depth'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Overhang depth must be greater than or equal to 0.')
  end

  def test_error_invalid_overhang_offset
    args_hash = {}
    args_hash['overhang_offset'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Overhang offset must be greater than or equal to 0.')
  end

  def test_retrofit_replace_one_ft_with_two_ft_overhangs
    args_hash = {}
    args_hash['overhang_depth'] = 1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 33, 'ShadingSurface' => 33, 'ShadingSurfaceGroup' => 33 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 1 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash, [0, 0, 0, 0], [81.5, 110.3, 70.0, 55.1], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash['overhang_depth'] = 2
    expected_num_del_objects = { 'SubSurface' => 33, 'ShadingSurface' => 33, 'ShadingSurfaceGroup' => 33 }
    expected_num_new_objects = { 'SubSurface' => 33, 'ShadingSurface' => 33, 'ShadingSurfaceGroup' => 33 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure(model, args_hash, [81.5, 110.3, 70.0, 55.1], [81.5, 110.3, 70.0, 55.1], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction_overhangs
    num_units = 1
    args_hash = {}
    args_hash['back_wwr'] = 0.12
    args_hash['right_wwr'] = 0.12
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 8, 'ShadingSurface' => 8, 'ShadingSurfaceGroup' => 8 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure('SFA_4units_1story_FB_UA_Denver.osm', args_hash, [0, 0, 0, 0, 0], [86.4 / 4, 57.6 / 4, 43.2, 0], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction_offset_overhangs
    num_units = 1
    args_hash = {}
    args_hash['back_wwr'] = 0.12
    args_hash['right_wwr'] = 0.12
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 11, 'ShadingSurface' => 11, 'ShadingSurfaceGroup' => 11 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure('SFA_4units_1story_SL_UA_Offset.osm', args_hash, [0, 0, 0, 0, 0], [122.19 / 4, 81.46 / 4, 61.1, 0], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction_overhangs
    num_units = 1
    args_hash = {}
    args_hash['back_wwr'] = 0.12
    args_hash['right_wwr'] = 0.12
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 9, 'ShadingSurface' => 9, 'ShadingSurfaceGroup' => 9 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, [0, 0, 0, 0, 0], [122.19 / 4, 0, 122.19 / 2, 0], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction_inset_overhangs
    num_units = 1
    args_hash = {}
    args_hash['back_wwr'] = 0.12
    args_hash['right_wwr'] = 0.12
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 10, 'ShadingSurface' => 10, 'ShadingSurfaceGroup' => 10 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure('MF_8units_1story_SL_Inset.osm', args_hash, [0, 0, 0, 0, 0], [124.61 / 4, 0, 62.3, 5.76], [0] * 5, [0] * 5, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_sfd_new_construction_gable_roof_skylights_front_back
    args_hash = {}
    args_hash['front_skylight_area'] = 15
    args_hash['back_skylight_area'] = 15
    args_hash['left_skylight_area'] = 0
    args_hash['right_skylight_area'] = 0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 34, 'ShadingSurface' => 32, 'ShadingSurfaceGroup' => 32 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    model = _test_measure('SFD_2000sqft_2story_SL_FA.osm', args_hash, [0, 0, 0, 0], [105.2, 105.2, 60.1, 60.1], [0] * 5, [15, 15, 0, 0, 0], expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_error_sfd_new_construction_gable_roof_skylights_front_back_left_nonzero
    args_hash = {}
    args_hash['front_skylight_area'] = 15
    args_hash['back_skylight_area'] = 15
    args_hash['left_skylight_area'] = 15
    args_hash['right_skylight_area'] = 0
    result = _test_error('SFD_2000sqft_2story_SL_FA.osm', args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'There are no left roof surfaces, but 15.0 ft^2 of skylights were specified.')
  end

  def test_sfd_new_construction_gable_roof_skylights_left_right
    args_hash = {}
    args_hash['front_skylight_area'] = 0
    args_hash['back_skylight_area'] = 0
    args_hash['left_skylight_area'] = 12
    args_hash['right_skylight_area'] = 12
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 34, 'ShadingSurface' => 32, 'ShadingSurfaceGroup' => 32 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    model = _test_measure('SFD_2000sqft_2story_SL_FA_LeftRight.osm', args_hash, [0, 0, 0, 0], [60.1, 60.1, 105.2, 105.2], [0] * 5, [0, 0, 12, 12, 0], expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_sfd_new_construction_hip_roof_skylights
    args_hash = {}
    args_hash['front_skylight_area'] = 5
    args_hash['back_skylight_area'] = 5
    args_hash['left_skylight_area'] = 5
    args_hash['right_skylight_area'] = 5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 36, 'ShadingSurface' => 32, 'ShadingSurfaceGroup' => 32 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    model = _test_measure('SFD_2000sqft_2story_SL_FA_HipRoof.osm', args_hash, [0, 0, 0, 0], [105.2, 105.2, 52.6, 52.6], [0] * 5, [5, 5, 5, 5, 0], expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_sfd_retrofit_hip_roof_skylights
    args_hash = {}
    args_hash['front_skylight_area'] = 5
    args_hash['back_skylight_area'] = 5
    args_hash['left_skylight_area'] = 5
    args_hash['right_skylight_area'] = 5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 36, 'ShadingSurface' => 32, 'ShadingSurfaceGroup' => 32 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    model = _test_measure('SFD_2000sqft_2story_SL_FA_HipRoof.osm', args_hash, [0, 0, 0, 0], [105.2, 105.2, 52.6, 52.6], [0] * 5, [5, 5, 5, 5, 0], expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['front_skylight_area'] = 6
    args_hash['back_skylight_area'] = 6
    args_hash['left_skylight_area'] = 6
    args_hash['right_skylight_area'] = 6
    expected_num_del_objects = { 'SubSurface' => 36, 'ShadingSurface' => 32, 'ShadingSurfaceGroup' => 32 }
    expected_num_new_objects = { 'SubSurface' => 36, 'ShadingSurface' => 32, 'ShadingSurfaceGroup' => 32 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure(model, args_hash, [105.2, 105.2, 52.6, 52.6], [105.2, 105.2, 52.6, 52.6], [5, 5, 5, 5, 0], [6, 6, 6, 6, 0], expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_sfd_new_construction_flat_roof_skylights
    args_hash = {}
    args_hash['front_skylight_area'] = 15
    args_hash['back_skylight_area'] = 15
    args_hash['left_skylight_area'] = 5
    args_hash['right_skylight_area'] = 5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 33, 'ShadingSurface' => 32, 'ShadingSurfaceGroup' => 32 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    model = _test_measure('SFD_2000sqft_2story_SL_FA_FlatRoof.osm', args_hash, [0, 0, 0, 0], [105.2, 105.2, 52.6, 52.6], [0, 0, 0, 0, 0], [0, 0, 0, 0, 40], expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction_overhangs_skylights
    num_units = 1
    args_hash = {}
    args_hash['back_wwr'] = 0.12
    args_hash['right_wwr'] = 0.12
    args_hash['front_skylight_area'] = 11
    args_hash['back_skylight_area'] = 8
    args_hash['left_skylight_area'] = 0
    args_hash['right_skylight_area'] = 12
    expected_num_del_objects = {}
    expected_num_new_objects = { 'SubSurface' => 10, 'ShadingSurface' => 9, 'ShadingSurfaceGroup' => 9 }
    expected_values = { 'Constructions' => 0, 'OverhangDepth' => 2 }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, [0, 0, 0, 0, 0], [122.19 / 4, 0, 122.19 / 2, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 31], expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = SetResidentialWindowSkylightArea.new

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

    return result
  end

  def _test_measure(osm_file_or_model, args_hash, expected_fblr_win_area_removed, expected_fblr_win_area_added, expected_fblr_sky_area_removed, expected_fblr_sky_area_added, expected_num_del_objects, expected_num_new_objects, expected_values)
    # create an instance of the measure
    measure = SetResidentialWindowSkylightArea.new

    # check for standard methods
    assert(!measure.name.empty?)
    assert(!measure.description.empty?)
    assert(!measure.modeler_description.empty?)

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    model = get_model(File.dirname(__FILE__), osm_file_or_model)

    # store the original windows in the model
    orig_windows = []
    model.getSubSurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType.downcase != 'fixedwindow'

      orig_windows << sub_surface
    end

    # store the original skylights in the model
    orig_skylights = []
    model.getSubSurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType.downcase != 'skylight'

      orig_skylights << sub_surface
    end

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
    assert(result.finalCondition.is_initialized)

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new/deleted window objects
    new_win_objects = []
    model.getSubSurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType.downcase != 'fixedwindow'
      next if orig_windows.include?(sub_surface)

      new_win_objects << sub_surface
    end
    del_objects = []
    orig_windows.each do |orig_window|
      has_window = false
      model.getSubSurfaces.each do |sub_surface|
        next if sub_surface != orig_window

        has_window = true
      end
      next if has_window

      del_objects << orig_window
    end

    new_win_area = { Constants.FacadeFront => 0, Constants.FacadeBack => 0,
                     Constants.FacadeLeft => 0, Constants.FacadeRight => 0 }
    new_win_objects.each do |window|
      new_win_area[Geometry.get_facade_for_surface(window)] += UnitConversions.convert(window.grossArea, 'm^2', 'ft^2')
    end

    del_win_area = { Constants.FacadeFront => 0, Constants.FacadeBack => 0,
                     Constants.FacadeLeft => 0, Constants.FacadeRight => 0 }
    del_objects.each do |window|
      del_win_area[Geometry.get_facade_for_surface(window)] += UnitConversions.convert(window.grossArea, 'm^2', 'ft^2')
    end

    assert_in_epsilon(expected_fblr_win_area_added[0], new_win_area[Constants.FacadeFront], 0.01)
    assert_in_epsilon(expected_fblr_win_area_added[1], new_win_area[Constants.FacadeBack], 0.01)
    assert_in_epsilon(expected_fblr_win_area_added[2], new_win_area[Constants.FacadeLeft], 0.01)
    assert_in_epsilon(expected_fblr_win_area_added[3], new_win_area[Constants.FacadeRight], 0.01)

    assert_in_epsilon(expected_fblr_win_area_removed[0], del_win_area[Constants.FacadeFront], 0.01)
    assert_in_epsilon(expected_fblr_win_area_removed[1], del_win_area[Constants.FacadeBack], 0.01)
    assert_in_epsilon(expected_fblr_win_area_removed[2], del_win_area[Constants.FacadeLeft], 0.01)
    assert_in_epsilon(expected_fblr_win_area_removed[3], del_win_area[Constants.FacadeRight], 0.01)

    # get new/deleted skylight objects
    new_sky_objects = []
    model.getSubSurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType.downcase != 'skylight'
      next if orig_skylights.include?(sub_surface)

      # next if sub_surface.tilt == 0
      new_sky_objects << sub_surface
    end
    del_objects = []
    orig_skylights.each do |orig_skylight|
      has_skylight = false
      model.getSubSurfaces.each do |sub_surface|
        next if sub_surface != orig_skylight

        has_skylight = true
      end
      next if has_skylight

      del_objects << orig_skylight
    end

    new_sky_area = { Constants.FacadeFront => 0, Constants.FacadeBack => 0,
                     Constants.FacadeLeft => 0, Constants.FacadeRight => 0,
                     Constants.FacadeNone => 0 }
    new_sky_objects.each do |skylight|
      facade = Geometry.get_facade_for_surface(skylight)
      if facade.nil?
        facade = Constants.FacadeNone
      end
      new_sky_area[facade] += UnitConversions.convert(skylight.grossArea, 'm^2', 'ft^2')
    end

    del_sky_area = { Constants.FacadeFront => 0, Constants.FacadeBack => 0,
                     Constants.FacadeLeft => 0, Constants.FacadeRight => 0,
                     Constants.FacadeNone => 0 }
    del_objects.each do |skylight|
      facade = Geometry.get_facade_for_surface(skylight)
      if facade.nil?
        facade = Constants.FacadeNone
      end
      del_sky_area[facade] += UnitConversions.convert(skylight.grossArea, 'm^2', 'ft^2')
    end

    assert_in_epsilon(expected_fblr_sky_area_added[0], new_sky_area[Constants.FacadeFront], 0.01)
    assert_in_epsilon(expected_fblr_sky_area_added[1], new_sky_area[Constants.FacadeBack], 0.01)
    assert_in_epsilon(expected_fblr_sky_area_added[2], new_sky_area[Constants.FacadeLeft], 0.01)
    assert_in_epsilon(expected_fblr_sky_area_added[3], new_sky_area[Constants.FacadeRight], 0.01)
    assert_in_epsilon(expected_fblr_sky_area_added[4], new_sky_area[Constants.FacadeNone], 0.01)

    assert_in_epsilon(expected_fblr_sky_area_removed[0], del_sky_area[Constants.FacadeFront], 0.01)
    assert_in_epsilon(expected_fblr_sky_area_removed[1], del_sky_area[Constants.FacadeBack], 0.01)
    assert_in_epsilon(expected_fblr_sky_area_removed[2], del_sky_area[Constants.FacadeLeft], 0.01)
    assert_in_epsilon(expected_fblr_sky_area_removed[3], del_sky_area[Constants.FacadeRight], 0.01)
    assert_in_epsilon(expected_fblr_sky_area_removed[4], del_sky_area[Constants.FacadeNone], 0.01)

    model.getSurfaces.each do |surface|
      assert(surface.netArea > 0)
    end

    actual_values = { 'Constructions' => 0 }
    constructions = []
    model.getSubSurfaces.each do |sub_surface|
      next unless sub_surface.construction.is_initialized

      if not constructions.include? sub_surface.construction.get
        constructions << sub_surface.construction.get
        actual_values['Constructions'] += 1
      end
    end
    assert_equal(expected_values['Constructions'], actual_values['Constructions'])

    # get new and deleted objects
    obj_type_exclusions = []
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        next unless obj_type == 'ShadingSurface'

        l, w, h = Geometry.get_surface_dimensions(new_object)
        if l < w
          assert_in_epsilon(expected_values['OverhangDepth'], UnitConversions.convert(l, 'm', 'ft'), 0.01)
        else
          assert_in_epsilon(expected_values['OverhangDepth'], UnitConversions.convert(w, 'm', 'ft'), 0.01)
        end
      end
    end

    return model
  end
end
