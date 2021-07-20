# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class CreateResidentialSingleFamilyAttachedGeometryTest < MiniTest::Test
  def test_error_existing_geometry
    args_hash = {}
    result = _test_error('SFA_4units_1story_FB_UA_Denver.osm', args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Starting model is not empty.')
  end

  def test_argument_error_crawl_height_invalid
    args_hash = {}
    args_hash['foundation_type'] = 'crawlspace'
    args_hash['foundation_height'] = 0
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'The crawlspace height can be set between 1.5 and 5 ft.')
  end

  def test_argument_error_aspect_ratio_invalid
    args_hash = {}
    args_hash['unit_aspect_ratio'] = -1.0
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid aspect ratio entered.')
  end

  def test_argument_error_odd_and_rear_units
    num_finished_spaces = 8
    args_hash = {}
    args_hash['num_units'] = 9
    args_hash['has_rear_units'] = 'true'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Specified a building with rear units and an odd number of units.')
  end

  # Left horizontal, 2 story, no rear
  def test_two_story_left_front_units_gable
    num_finished_spaces = 3
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['num_units'] = 4
    args_hash['foundation_type'] = 'finished basement'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 23, 'ThermalZone' => 2 * 1 + 1, 'Space' => 2 + 1 + 1, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 300, 'UnfinishedAtticHeight' => 7.12, 'UnfinishedAtticFloorArea' => 300, 'BuildingHeight' => 8 + 8 + 8 + 7.12, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 4 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Left horizontal, 2 story, has rear
  def test_two_story_left_rear_units_gable
    num_finished_spaces = 3
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['num_units'] = 4
    args_hash['foundation_type'] = 'finished basement'
    args_hash['has_rear_units'] = 'true'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 23, 'ThermalZone' => 2 * 1 + 1, 'Space' => 2 + 1 + 1, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 300, 'UnfinishedAtticHeight' => 7.12, 'UnfinishedAtticFloorArea' => 300, 'BuildingHeight' => 8 + 8 + 8 + 7.12, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 7 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle horizontal, 2 story, no rear
  def test_two_story_mid_front_units_gable
    num_finished_spaces = 3
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['num_units'] = 4
    args_hash['foundation_type'] = 'finished basement'
    args_hash['horz_location'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 23, 'ThermalZone' => 2 * 1 + 1, 'Space' => 2 + 1 + 1, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 300, 'UnfinishedAtticHeight' => 7.12, 'UnfinishedAtticFloorArea' => 300, 'BuildingHeight' => 8 + 8 + 8 + 7.12, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 8 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle horizontal, 2 story, has rear
  def test_two_story_mid_rear_units_gable
    num_finished_spaces = 3
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['num_units'] = 6
    args_hash['foundation_type'] = 'finished basement'
    args_hash['has_rear_units'] = 'true'
    args_hash['horz_location'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 23, 'ThermalZone' => 2 * 1 + 1, 'Space' => 2 + 1 + 1, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 300, 'UnfinishedAtticHeight' => 7.12, 'UnfinishedAtticFloorArea' => 300, 'BuildingHeight' => 8 + 8 + 8 + 7.12, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 11 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Left Horizontal, 1 story, no rear
  def test_one_story_left_front_units_gable
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 1
    args_hash['num_units'] = 4
    args_hash['foundation_type'] = 'finished basement'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 17, 'ThermalZone' => 2 * 1 + 1, 'Space' => 2 + 1, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 450, 'UnfinishedAtticHeight' => 8.5, 'UnfinishedAtticFloorArea' => 450, 'BuildingHeight' => 8 + 8 + 8.5, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 3 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Left Horizontal, 1 story, has rear
  def test_one_story_left_rear_units_gable
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 1
    args_hash['num_units'] = 4
    args_hash['foundation_type'] = 'finished basement'
    args_hash['horz_location'] = 'Left'
    args_hash['has_rear_units'] = 'true'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 17, 'ThermalZone' => 2 * 1 + 1, 'Space' => 2 + 1, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 450, 'UnfinishedAtticHeight' => 8.5, 'UnfinishedAtticFloorArea' => 450, 'BuildingHeight' => 8 + 8 + 8.5, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 5 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle Horizontal, 1 story, no rear
  def test_one_story_mid_front_units_gable
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 1
    args_hash['num_units'] = 4
    args_hash['foundation_type'] = 'finished basement'
    args_hash['horz_location'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 17, 'ThermalZone' => 2 * 1 + 1, 'Space' => 2 + 1, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 450, 'UnfinishedAtticHeight' => 8.5, 'UnfinishedAtticFloorArea' => 450, 'BuildingHeight' => 8 + 8 + 8.5, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 6 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle Horizontal, 1 story, has rear
  def test_one_story_mid_rear_units_gable
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 1
    args_hash['num_units'] = 6
    args_hash['foundation_type'] = 'finished basement'
    args_hash['horz_location'] = 'Middle'
    args_hash['has_rear_units'] = 'true'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 17, 'ThermalZone' => 2 * 1 + 1, 'Space' => 2 + 1, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 450, 'UnfinishedAtticHeight' => 8.5, 'UnfinishedAtticFloorArea' => 450, 'BuildingHeight' => 8 + 8 + 8.5, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 8 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_two_story_fourplex_rear_units_hip
    num_finished_spaces = 3
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['num_units'] = 4
    args_hash['has_rear_units'] = 'true'
    args_hash['foundation_type'] = 'finished basement'
    args_hash['roof_type'] = Constants.RoofTypeHip
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 23, 'ThermalZone' => 2 * 1 + 1, 'Space' => (2 + 1) * 1 + 1, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 300, 'UnfinishedAtticHeight' => 8.12, 'UnfinishedAtticFloorArea' => 300, 'BuildingHeight' => 8 + 8 + 8 + 8.12, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 6 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_ufbasement
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_units'] = 4
    args_hash['foundation_type'] = 'unfinished basement'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 17, 'ThermalZone' => 1 + 1 + 1, 'Space' => 1 + 1 + 1, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'UnfinishedBasementHeight' => 8, 'UnfinishedBasementFloorArea' => 900, 'UnfinishedAtticHeight' => 11.61, 'UnfinishedAtticFloorArea' => 900, 'BuildingHeight' => 8 + 8 + 11.61, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 3 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_crawl
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_units'] = 4
    args_hash['foundation_type'] = 'crawlspace'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 17, 'ThermalZone' => 1 + 1 + 1, 'Space' => 1 + 1 + 1, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'CrawlspaceHeight' => 3, 'CrawlspaceFloorArea' => 900, 'UnfinishedAtticHeight' => 11.61, 'UnfinishedAtticFloorArea' => 900, 'BuildingHeight' => 3 + 8 + 11.61, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 3 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_one_unit_per_floor_with_rear_units
    args_hash = {}
    args_hash['num_units'] = 1
    args_hash['has_rear_units'] = 'true'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, "Specified building as having rear units, but didn't specify enough units.")
  end

  def test_fourplex_finished_hip_roof
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['num_units'] = 4
    args_hash['attic_type'] = 'finished attic'
    args_hash['roof_type'] = Constants.RoofTypeHip
    args_hash['roof_pitch'] = '12:12'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 11, 'ThermalZone' => 1, 'Space' => 2, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'FinishedAtticHeight' => 19, 'FinishedAtticFloorArea' => 450 * 1, 'BuildingHeight' => 8 + 19, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2.0, 'NumAdiabaticSurfaces' => 1 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_fourplex_finished_hip_roof_with_rear_units
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['num_units'] = 4
    args_hash['has_rear_units'] = 'true'
    args_hash['attic_type'] = 'finished attic'
    args_hash['roof_type'] = Constants.RoofTypeHip
    args_hash['roof_pitch'] = '12:12'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 11, 'ThermalZone' => 1, 'Space' => 2, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'FinishedAtticHeight' => 19, 'FinishedAtticFloorArea' => 450, 'BuildingHeight' => 8 + 19, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_fourplex_gable_roof_aspect_ratio_half
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_units'] = 4
    args_hash['unit_aspect_ratio'] = 0.5
    args_hash['has_rear_units'] = 'true'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 11, 'ThermalZone' => 1 + 1, 'Space' => 1 + 1, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'UnfinishedAtticHeight' => 6.30, 'UnfinishedAtticFloorArea' => 900, 'BuildingHeight' => 8 + 6.30, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 3 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_fourplex_hip_roof
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_units'] = 4
    args_hash['has_rear_units'] = 'true'
    args_hash['roof_type'] = Constants.RoofTypeHip
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 11, 'ThermalZone' => 1 + 1, 'Space' => 1 + 1, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'UnfinishedAtticHeight' => 12.61, 'UnfinishedAtticFloorArea' => 900, 'BuildingHeight' => 8 + 12.61, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_fourplex_hip_roof_aspect_ratio_half_offset
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_units'] = 4
    args_hash['unit_aspect_ratio'] = 0.5
    args_hash['has_rear_units'] = 'true'
    args_hash['roof_type'] = Constants.RoofTypeHip
    args_hash['offset'] = 6
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 11, 'ThermalZone' => 1 + 1, 'Space' => 1 + 1, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'UnfinishedAtticHeight' => 6.30, 'UnfinishedAtticFloorArea' => 900, 'BuildingHeight' => 8 + 6.30, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_argument_error_beds_not_equal_to_baths
    args_hash = {}
    args_hash['num_bedrooms'] = '3.0, 3.0, 3.0'
    args_hash['num_bathrooms'] = '2.0, 2.0'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Number of bedroom elements specified inconsistent with number of bathroom elements specified.')
  end

  def test_argument_error_beds_not_equal_to_units
    args_hash = {}
    args_hash['num_bedrooms'] = '3.0, 3.0, 3.0'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Number of bedroom elements specified inconsistent with number of multifamily units defined in the model.')
  end

  def test_argument_error_baths_not_equal_to_units
    args_hash = {}
    args_hash['num_bathrooms'] = '2.0, 2.0, 2.0'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Number of bathroom elements specified inconsistent with number of multifamily units defined in the model.')
  end

  def test_argument_error_beds_not_numerical
    args_hash = {}
    args_hash['num_bedrooms'] = '3.0, 3.0, typo'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Number of bedrooms must be a numerical value.')
  end

  def test_argument_error_baths_not_numerical
    args_hash = {}
    args_hash['num_bathrooms'] = '2.0, 2.0, typo'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Number of bathrooms must be a numerical value.')
  end

  def test_argument_error_beds_not_integer
    args_hash = {}
    args_hash['num_bedrooms'] = '3.0, 3.0, 3.5'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Number of bedrooms must be a non-negative integer.')
  end

  def test_argument_error_baths_not_positive_multiple_of_0pt25
    args_hash = {}
    args_hash['num_bathrooms'] = '2.0, 2.0, 2.8'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Number of bathrooms must be a positive multiple of 0.25.')
  end

  def test_error_invalid_eaves_depth
    args_hash = {}
    args_hash['eaves_depth'] = -1
    result = _test_error(nil, args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Eaves depth must be greater than or equal to 0.')
  end

  def test_error_invalid_neighbor_offset
    args_hash = {}
    args_hash['neighbor_left_offset'] = -10
    result = _test_error(nil, args_hash)
    assert(result.errors.size == 1)
    assert_equal('Fail', result.value.valueName)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Neighbor offsets must be greater than or equal to 0.')
  end

  def test_error_invalid_orientation
    args_hash = {}
    args_hash['orientation'] = -180
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid orientation entered.')
  end

  private

  def _test_error(osm_file_or_model, args_hash)
    # create an instance of the measure
    measure = CreateResidentialSingleFamilyAttachedGeometry.new

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

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, test_name)
    # create an instance of the measure
    measure = CreateResidentialSingleFamilyAttachedGeometry.new

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

    # save the model to test output directory
    # output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/#{test_name}.osm")
    # model.save(output_file_path, true)

    # show the output
    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = ['PortList', 'Node', 'ZoneEquipmentList', 'SizingZone', 'ZoneHVACEquipmentList', 'Building', 'ScheduleRule', 'ScheduleDay', 'ScheduleTypeLimits', 'YearDescription']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    actual_values = { 'FinishedFloorArea' => 0, 'FinishedBasementFloorArea' => 0, 'UnfinishedBasementFloorArea' => 0, 'CrawlspaceFloorArea' => 0, 'UnfinishedAtticFloorArea' => 0, 'FinishedAtticFloorArea' => 0, 'FinishedBasementHeight' => 0, 'UnfinishedBasementHeight' => 0, 'CrawlspaceHeight' => 0, 'UnfinishedAtticHeight' => 0, 'FinishedAtticHeight' => 0, 'BuildingHeight' => 0, 'NumOccupants' => 0, 'NumAdiabaticSurfaces' => 0 }
    new_spaces = []
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        if obj_type == 'Space'
          if new_object.name.to_s.start_with?('finished basement')
            actual_values['FinishedBasementHeight'] = Geometry.get_height_of_spaces([new_object])
            actual_values['FinishedBasementFloorArea'] += UnitConversions.convert(new_object.floorArea, 'm^2', 'ft^2')
          elsif new_object.name.to_s.start_with?('unfinished basement')
            actual_values['UnfinishedBasementHeight'] = Geometry.get_height_of_spaces([new_object])
            actual_values['UnfinishedBasementFloorArea'] += UnitConversions.convert(new_object.floorArea, 'm^2', 'ft^2')
          elsif new_object.name.to_s.start_with?('crawlspace')
            actual_values['CrawlspaceHeight'] = Geometry.get_height_of_spaces([new_object])
            actual_values['CrawlspaceFloorArea'] += UnitConversions.convert(new_object.floorArea, 'm^2', 'ft^2')
          elsif new_object.name.to_s.start_with?('unfinished attic')
            actual_values['UnfinishedAtticHeight'] = Geometry.get_height_of_spaces([new_object])
            actual_values['UnfinishedAtticFloorArea'] += UnitConversions.convert(new_object.floorArea, 'm^2', 'ft^2')
          elsif new_object.name.to_s.start_with?('finished attic')
            actual_values['FinishedAtticHeight'] = Geometry.get_height_of_spaces([new_object])
            actual_values['FinishedAtticFloorArea'] += UnitConversions.convert(new_object.floorArea, 'm^2', 'ft^2')
          end
          if Geometry.space_is_finished(new_object)
            actual_values['FinishedFloorArea'] += UnitConversions.convert(new_object.floorArea, 'm^2', 'ft^2')
          end
          new_spaces << new_object
        elsif obj_type == 'People'
          actual_values['NumOccupants'] += new_object.peopleDefinition.numberofPeople.get
        elsif obj_type == 'ShadingSurface'
          next unless new_object.name.to_s.include? Constants.ObjectNameEaves

          l, w, h = Geometry.get_surface_dimensions(new_object)
          actual_values['EavesDepth'] = [UnitConversions.convert(l, 'm', 'ft'), UnitConversions.convert(w, 'm', 'ft')].min
          assert_in_epsilon(expected_values['EavesDepth'], actual_values['EavesDepth'], 0.01)
        elsif obj_type == 'Surface'
          if ['outdoors', 'foundation'].include? new_object.outsideBoundaryCondition.downcase
            if new_object.construction.is_initialized
              new_object.construction.get.to_LayeredConstruction.get.layers.each do |layer|
                next unless layer.name.to_s.include? Constants.SurfaceTypeAdiabatic

                actual_values['NumAdiabaticSurfaces'] += 1
              end
            end
          elsif new_object.outsideBoundaryCondition.downcase == 'adiabatic'
            actual_values['NumAdiabaticSurfaces'] += 1
          end
        end
      end
    end
    if new_spaces.any? { |new_space| new_space.name.to_s.start_with?('finished basement') }
      assert_in_epsilon(expected_values['FinishedBasementHeight'], actual_values['FinishedBasementHeight'], 0.01)
      assert_in_epsilon(expected_values['FinishedBasementFloorArea'], actual_values['FinishedBasementFloorArea'], 0.01)
    end
    if new_spaces.any? { |new_space| new_space.name.to_s.start_with?('unfinished basement') }
      assert_in_epsilon(expected_values['UnfinishedBasementHeight'], actual_values['UnfinishedBasementHeight'], 0.01)
      assert_in_epsilon(expected_values['UnfinishedBasementFloorArea'], actual_values['UnfinishedBasementFloorArea'], 0.01)
    end
    if new_spaces.any? { |new_space| new_space.name.to_s.start_with?('crawlspace') }
      assert_in_epsilon(expected_values['CrawlspaceHeight'], actual_values['CrawlspaceHeight'], 0.01)
      assert_in_epsilon(expected_values['CrawlspaceFloorArea'], actual_values['CrawlspaceFloorArea'], 0.01)
    end
    if new_spaces.any? { |new_space| new_space.name.to_s.start_with?('unfinished attic') }
      assert_in_epsilon(expected_values['UnfinishedAtticHeight'], actual_values['UnfinishedAtticHeight'], 0.01)
      assert_in_epsilon(expected_values['UnfinishedAtticFloorArea'], actual_values['UnfinishedAtticFloorArea'], 0.01)
    end
    if new_spaces.any? { |new_space| new_space.name.to_s.start_with?('finished attic') }
      assert_in_epsilon(expected_values['FinishedAtticHeight'], actual_values['FinishedAtticHeight'], 0.01)
      assert_in_epsilon(expected_values['FinishedAtticFloorArea'], actual_values['FinishedAtticFloorArea'], 0.01)
    end
    assert_in_epsilon(expected_values['FinishedFloorArea'], actual_values['FinishedFloorArea'], 0.01)
    assert_in_epsilon(expected_values['BuildingHeight'], Geometry.get_height_of_spaces(new_spaces), 0.01)
    assert_in_epsilon(expected_values['NumOccupants'], actual_values['NumOccupants'], 0.01)

    # Ensure no surfaces adjacent to "ground" (should be Kiva "foundation")
    model.getSurfaces.each do |surface|
      refute_equal(surface.outsideBoundaryCondition.downcase, 'ground')
    end

    Geometry.get_building_units(model, runner).each do |unit|
      nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
      assert_equal(expected_values['Beds'], nbeds)
      assert_equal(expected_values['Baths'], nbaths)
    end

    assert_equal(expected_values['NumAdiabaticSurfaces'], actual_values['NumAdiabaticSurfaces'])

    return model
  end
end
