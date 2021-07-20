# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class CreateResidentialMultifamilyGeometryTest < MiniTest::Test
  def test_error_existing_geometry
    args_hash = {}
    result = _test_error('MF_8units_1story_SL_Denver.osm', args_hash)
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

  def test_error_no_corr
    args_hash = {}
    args_hash['corridor_width'] = -1
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid corridor width entered.')
  end

  def test_uneven_units_per_floor_with_interior_corr
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_units'] = 3
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 3, 'ShadingSurface' => 7, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 1 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_warning_balc_but_no_inset
    num_finished_spaces = 1
    args_hash = {}
    args_hash['balcony_depth'] = 6
    args_hash['corridor_position'] = 'None'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * num_finished_spaces, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 1 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_two_story_double_exterior
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['num_units'] = 2 * 4
    args_hash['corridor_position'] = 'Double Exterior'
    args_hash['inset_width'] = 8
    args_hash['inset_depth'] = 6
    args_hash['balcony_depth'] = 6
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 8, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 3, 'ShadingSurface' => 4, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 3 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_multiplex_right_inset
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 8
    args_hash['num_units'] = 8 * 6
    args_hash['inset_width'] = 8
    args_hash['inset_depth'] = 6
    args_hash['foundation_type'] = 'unfinished basement'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 28, 'ThermalZone' => 4, 'Space' => 4, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'UnfinishedBasementHeight' => 8, 'UnfinishedBasementFloorArea' => 900 + 0.5 * 21.77 * 10, 'BuildingHeight' => 8 + 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 11 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_multiplex_left_inset_balcony
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 8
    args_hash['num_units'] = 8 * 6
    args_hash['inset_width'] = 8
    args_hash['inset_depth'] = 6
    args_hash['inset_position'] = 'Left'
    args_hash['balcony_depth'] = 6
    args_hash['foundation_type'] = 'unfinished basement'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 28, 'ThermalZone' => 4, 'Space' => 4, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'UnfinishedBasementHeight' => 8, 'UnfinishedBasementFloorArea' => 900 + 0.5 * 21.77 * 10, 'BuildingHeight' => 8 + 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 10 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Foundation tests
  def test_bot_ufbasement_double_loaded_corr
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_units'] = 4
    args_hash['foundation_type'] = 'unfinished basement'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 24, 'ThermalZone' => 4, 'Space' => 4, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'UnfinishedBasementHeight' => 8, 'UnfinishedBasementFloorArea' => 900 + 0.5 * 21.21 * 10, 'BuildingHeight' => 8 + 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 8 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_top_ufbasement_double_loaded_corr
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_units'] = 8
    args_hash['foundation_type'] = 'unfinished basement'
    args_hash['num_floors'] = 2
    args_hash['level'] = 'Top'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 1 + 1, 'Space' => 1 + 1, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'UnfinishedBasementHeight' => 0, 'UnfinishedBasementFloorArea' => 0, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 7 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_bot_crawl_single_exterior
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['num_units'] = 12 * 2
    args_hash['corridor_position'] = 'Single Exterior (Front)'
    args_hash['foundation_type'] = 'crawlspace'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 2, 'Space' => 2, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'CrawlspaceHeight' => 3, 'CrawlspaceFloorArea' => 1 * 900, 'BuildingHeight' => 3 + 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 3 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_top_crawl_single_exterior
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['num_units'] = 12 * 2
    args_hash['corridor_position'] = 'Single Exterior (Front)'
    args_hash['foundation_type'] = 'crawlspace'
    args_hash['level'] = 'Top'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 3, 'ShadingSurface' => 7, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900, 'CrawlspaceHeight' => 0, 'CrawlspaceFloorArea' => 0, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_bot_crawl_double_loaded_corr
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_units'] = 4
    args_hash['foundation_type'] = 'crawlspace'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 24, 'ThermalZone' => 4, 'Space' => 4, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'CrawlspaceHeight' => 3, 'CrawlspaceFloorArea' => 900 + 0.5 * 21.21 * 10, 'BuildingHeight' => 3 + 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 8 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_top_crawl_double_loaded_corr
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_units'] = 8
    args_hash['num_floors'] = 2
    args_hash['foundation_type'] = 'crawlspace'
    args_hash['level'] = 'Top'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 1 + 1, 'Space' => 1 + 1, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'CrawlspaceHeight' => 0, 'CrawlspaceFloorArea' => 0, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 7 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  #- [No horizontal, 1 unit/floor]
  # Top, No horz, Double cor, 1 unit/floor (default to single exterior)
  def test_top_one_unit_per_floor_with_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 3
    args_hash['level'] = 'Top'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 3, 'ShadingSurface' => 7, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 1 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Top, No horz, No cor, 1 unit/floor
  def test_top_one_unit_per_floor_no_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 3
    args_hash['level'] = 'Top'
    args_hash['corridor_position'] = 'None'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 1 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, No horz, Double cor, 1 unit/floor (default to single exterior)
  def test_mid_one_unit_per_floor_with_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 3
    args_hash['level'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, No horz, No cor, 1 unit/floor
  def test_mid_one_unit_per_floor_no_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 3
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'None'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, No horz, Double cor, 1 unit/floor (default to single exterior)
  def test_bot_one_unit_per_floor_with_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 3
    args_hash['level'] = 'Bottom'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 1 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, No horz, No cor, 1 unit/floor
  def test_bot_one_unit_per_floor_no_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 3
    args_hash['level'] = 'Bottom'
    args_hash['corridor_position'] = 'None'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 1 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  #- [No horizontal, 2 unit/floor]
  # Top, No Horz, Double cor, 2 unit/floor
  def test_top_two_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Top'
    args_hash['horz_location'] = 'None'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 2, 'Space' => 2, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 5 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Top, No Horz, Ext cor, 2 unit/floor
  def test_top_two_unit_per_floor_exterior_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Top'
    args_hash['corridor_position'] = 'Double Exterior'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 3, 'ShadingSurface' => 7, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, No Horz, Double cor, 2 unit/floor
  def test_mid_two_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'None'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 2, 'Space' => 2, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 7 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, No Horz, Ext cor, 2 unit/floor
  def test_mid_two_unit_per_floor_exterior_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'Double Exterior'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 3 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, No horz, Double cor, 2 unit/floor
  def test_bot_two_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Bottom'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'None'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 2, 'Space' => 2, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 5 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, No Horz, Ext cor, 2 unit/floor
  def test_bot_two_unit_per_floor_exterior_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Bottom'
    args_hash['corridor_position'] = 'Double Exterior'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  #- [Left Horizontal, 1 unit/floor]
  # Top, Left horz, No cor, 1 unit/floor
  def test_top_left_one_unit_per_floor_no_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 3
    args_hash['level'] = 'Top'
    args_hash['corridor_position'] = 'None'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 1 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Top, Left horz, single cor, 1 unit/floor
  def test_top_left_one_unit_per_floor_single_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 3
    args_hash['level'] = 'Top'
    args_hash['corridor_position'] = 'Single Exterior (Front)'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 3, 'ShadingSurface' => 7, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 1 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, Left horz, No cor, 1 unit/floor
  def test_mid_left_one_unit_per_floor_no_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 3
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'None'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, Left horz, Single cor, 1 unit/floor
  def test_mid_left_one_unit_per_floor_single_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 3
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'Single Exterior (Front)'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, Left horz, No cor, 1 unit/floor
  def test_bot_left_one_unit_per_floor_no_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 3
    args_hash['level'] = 'Bottom'
    args_hash['corridor_position'] = 'None'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 1 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, Left horz, Single cor, 1 unit/floor
  def test_bot_left_one_unit_per_floor_single_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 3
    args_hash['level'] = 'Bottom'
    args_hash['corridor_position'] = 'Single Exterior (Front)'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 1 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  #- [Left horizontal, 2 unit/floor]
  # Top, Left Horz, Double cor, 2 unit/floor
  def test_top_left_two_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Top'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'None'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 2, 'Space' => 2, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 5 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Top, Left Horz, Single cor, 2 unit/floor
  def test_top_left_two_unit_per_floor_single_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Top'
    args_hash['corridor_position'] = 'Single Exterior (Front)'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 3, 'ShadingSurface' => 7, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Top, Left Horz, No cor, 2 unit/floor
  def test_top_left_two_unit_per_floor_no_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Top'
    args_hash['corridor_position'] = 'None'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, Left Horz, Double cor, 2 unit/floor
  def test_mid_left_two_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'Left' # Forces single front corridor
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 3 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, Left Horz, Single cor, 2 unit/floor
  def test_mid_left_two_unit_per_floor_single_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'Single Exterior (Front)'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 3 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, Left Horz, No cor, 2 unit/floor
  def test_mid_left_two_unit_per_floor_no_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'None'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 3 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, Left horz, Double cor, 2 unit/floor
  def test_bot_left_two_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Bottom'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'None'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 2, 'Space' => 2, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 5 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, Left Horz, Single cor, 2 unit/floor
  def test_bot_left_two_unit_per_floor_single_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Bottom'
    args_hash['corridor_position'] = 'Single Exterior (Front)'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, Left Horz, No cor, 2 unit/floor
  def test_bot_left_two_unit_per_floor_no_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['level'] = 'Bottom'
    args_hash['corridor_position'] = 'None'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  #- [Middle Horizontal, 3 unit/floor]
  # Top, Middle Horz, Double cor, 3 unit/floor
  def test_top_mid_three_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 9
    args_hash['level'] = 'Top'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 3, 'ShadingSurface' => 7, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 3 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, Middle Horz, Double cor, 3 unit/floor
  def test_mid_mid_three_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 9
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 4 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, Middle Horz, Double cor, 3 unit/floor
  def test_bot_mid_three_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 9
    args_hash['level'] = 'Bottom'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 3 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  #- [Left Horizontal, 4 unit/floor]
  # Top, Left Horz, Double cor, 4 unit/floor
  def test_top_left_four_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 12
    args_hash['level'] = 'Top'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 2, 'Space' => 2, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 7 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, Left Horz, Double cor, 4 unit/floor
  def test_mid_left_four_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 12
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 2, 'Space' => 2, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 9 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, Left Horz, Double cor, 4 unit/floor
  def test_bot_left_four_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 12
    args_hash['level'] = 'Bottom'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'Left'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 2, 'Space' => 2, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 7 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  #- [Middle Horizontal, 6 unit/floor]
  # Top, Middle Horz, Double cor, 6 unit/floor
  def test_top_mid_six_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 18
    args_hash['level'] = 'Top'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 2, 'Space' => 2, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 9 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Top, Middle Horz, Double ext cor, 6 unit/floor
  def test_top_mid_six_unit_per_floor_double_ext_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 18
    args_hash['level'] = 'Top'
    args_hash['corridor_position'] = 'Double Exterior'
    args_hash['horz_location'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 3, 'ShadingSurface' => 7, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 4 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, Middle Horz, Double cor, 6 unit/floor
  def test_mid_mid_six_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 18
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 2, 'Space' => 2, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 11 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Middle, Middle Horz, Double ext cor, 6 unit/floor
  def test_mid_mid_six_unit_per_floor_double_ext_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 18
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'Double Exterior'
    args_hash['horz_location'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 5 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, Middle Horz, Double cor, 6 unit/floor
  def test_bot_mid_six_unit_per_floor_double_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 18
    args_hash['level'] = 'Bottom'
    args_hash['corridor_position'] = 'Double-Loaded Interior'
    args_hash['horz_location'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 12, 'ThermalZone' => 2, 'Space' => 2, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 1, 'ShadingSurface' => 2, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 10 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  # Bottom, Middle Horz, Double ext cor, 6 unit/floor
  def test_bot_mid_six_unit_per_floor_double_ext_corridor
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 18
    args_hash['level'] = 'Bottom'
    args_hash['corridor_position'] = 'Double Exterior'
    args_hash['horz_location'] = 'Middle'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 3, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 4 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_argument_error_invalid_none_horizontal
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['num_units'] = 6
    args_hash['horz_location'] = 'None'
    args_hash['corridor_position'] = 'None'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Specified incompatible horizontal location for the corridor and unit configuration.')
  end

  def test_argument_error_invalid_middle_horizontal
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['num_units'] = 6
    args_hash['horz_location'] = 'Middle'
    args_hash['corridor_position'] = 'None'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid horizontal location entered, no middle location exists.')
  end

  def test_argument_error_invalid_middle_level
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['num_units'] = 6
    args_hash['level'] = 'Middle'
    args_hash['corridor_position'] = 'None'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Building is 2 stories and does not have middle units')
  end

  def test_corr_width_zero_but_corr_not_none
    num_finished_spaces = 1
    args_hash = {}
    args_hash['corridor_width'] = 0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 6, 'ThermalZone' => 1, 'Space' => 1, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 900 * 1, 'BuildingHeight' => 8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 3.39, 'EavesDepth' => 2, 'NumAdiabaticSurfaces' => 1 }
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
    measure = CreateResidentialMultifamilyGeometry.new

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
    # show_output(result) unless result.value.valueName == 'Fail'

    # assert that it didn't run
    assert_equal('Fail', result.value.valueName)
    assert(result.errors.size == 1)

    return result
  end

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, test_name)
    # create an instance of the measure
    measure = CreateResidentialMultifamilyGeometry.new

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
    # show_output(result) unless result.value.valueName == 'Success'

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

    actual_values = { 'FinishedFloorArea' => 0, 'UnfinishedBasementFloorArea' => 0, 'CrawlspaceFloorArea' => 0, 'UnfinishedBasementHeight' => 0, 'CrawlspaceHeight' => 0, 'NumOccupants' => 0, 'NumAdiabaticSurfaces' => 0 }
    new_spaces = []
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        if obj_type == 'Space'
          if new_object.name.to_s.start_with?('unfinished basement')
            actual_values['UnfinishedBasementHeight'] = Geometry.get_height_of_spaces([new_object])
            actual_values['UnfinishedBasementFloorArea'] += UnitConversions.convert(new_object.floorArea, 'm^2', 'ft^2')
          elsif new_object.name.to_s.start_with?('crawl')
            actual_values['CrawlspaceHeight'] = Geometry.get_height_of_spaces([new_object])
            actual_values['CrawlspaceFloorArea'] += UnitConversions.convert(new_object.floorArea, 'm^2', 'ft^2')
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
    if new_spaces.any? { |new_space| new_space.name.to_s.start_with?('unfinished basement') }
      assert_in_epsilon(expected_values['UnfinishedBasementHeight'], actual_values['UnfinishedBasementHeight'], 0.01)
      assert_in_epsilon(expected_values['UnfinishedBasementFloorArea'], actual_values['UnfinishedBasementFloorArea'], 0.01)
    end
    if new_spaces.any? { |new_space| new_space.name.to_s.start_with?('crawl') }
      assert_in_epsilon(expected_values['CrawlspaceHeight'], actual_values['CrawlspaceHeight'], 0.01)
      assert_in_epsilon(expected_values['CrawlspaceFloorArea'], actual_values['CrawlspaceFloorArea'], 0.01)
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
