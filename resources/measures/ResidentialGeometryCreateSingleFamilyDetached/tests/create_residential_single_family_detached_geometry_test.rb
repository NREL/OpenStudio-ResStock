# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class CreateResidentialSingleFamilyDetachedGeometryTest < MiniTest::Test
  def test_error_existing_geometry
    args_hash = {}
    result = _test_error('SFD_2000sqft_2story_SL_UA.osm', args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Starting model is not empty.')
  end

  def test_argument_error_aspect_ratio_invalid
    args_hash = {}
    args_hash['aspect_ratio'] = -1.0
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid aspect ratio entered.')
  end

  def test_argument_error_pierbeam_height_invalid
    args_hash = {}
    args_hash['foundation_type'] = 'pier and beam'
    args_hash['foundation_height'] = 0
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'The pier & beam height must be greater than 0 ft.')
  end

  def test_argument_error_pierbeam_with_garage
    args_hash = {}
    args_hash['garage_width'] = 12
    args_hash['foundation_type'] = 'pier and beam'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Cannot handle garages with a pier & beam foundation type.')
  end

  def test_argument_error_num_floors_invalid
    args_hash = {}
    args_hash['num_floors'] = 7
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Too many floors.')
  end

  def test_argument_error_garage_protrusion_invalid
    args_hash = {}
    args_hash['garage_protrusion'] = 2
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid garage protrusion value entered.')
  end

  def test_argument_error_hip_roof_and_garage_protrudes
    args_hash = {}
    args_hash['garage_width'] = 12
    args_hash['garage_protrusion'] = 0.5
    args_hash['roof_type'] = Constants.RoofTypeHip
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Cannot handle protruding garage and hip roof.')
  end

  def test_argument_error_living_and_garage_ridges_are_parallel
    args_hash = {}
    args_hash['garage_width'] = 12
    args_hash['garage_protrusion'] = 0.5
    args_hash['aspect_ratio'] = 0.75
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Cannot handle protruding garage and attic ridge running from front to back.')
  end

  def test_argument_error_garage_width_exceeds_living_width
    args_hash = {}
    args_hash['garage_width'] = 10000
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid living space and garage dimensions.')
  end

  def test_argument_error_garage_depth_exceeds_living_depth
    args_hash = {}
    args_hash['garage_width'] = 12
    args_hash['garage_depth'] = 10000
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid living space and garage dimensions.')
  end

  def test_change_garage_pitch_when_garage_ridge_higher_than_house_ridge
    num_finished_spaces = 1
    args_hash = {}
    args_hash['num_floors'] = 1
    args_hash['garage_protrusion'] = 0.5
    args_hash['garage_width'] = 40
    args_hash['garage_depth'] = 24
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 26, 'ThermalZone' => 3, 'Space' => 4, 'SpaceType' => 4, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'GarageAtticHeight' => 9.65, 'GarageFloorArea' => 960, 'UnfinishedAtticHeight' => 9.80, 'UnfinishedAtticFloorArea' => 2960, 'BuildingHeight' => 17.8, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_slab_three_quarter_garage_protrusion
    num_finished_spaces = 1
    args_hash = {}
    args_hash['total_ffa'] = 633
    args_hash['num_floors'] = 1
    args_hash['garage_width'] = 12
    args_hash['garage_depth'] = 24
    args_hash['garage_protrusion'] = 0.75
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 26, 'ThermalZone' => 3, 'Space' => 4, 'SpaceType' => 4, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 633, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 12 * 24, 'UnfinishedAtticHeight' => 5.69, 'UnfinishedAtticFloorArea' => 633 + 12 * 24, 'BuildingHeight' => 8 + 5.69, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_fbasement
    num_finished_spaces = 3
    args_hash = {}
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 23, 'ThermalZone' => 3, 'Space' => 4, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 2000 / 3, 'UnfinishedAtticHeight' => 5.56, 'UnfinishedAtticFloorArea' => 2000 / 3, 'BuildingHeight' => 8 + 8 + 8 + 5.56, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_ufbasement
    num_finished_spaces = 2
    args_hash = {}
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'unfinished basement'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 23, 'ThermalZone' => 3, 'Space' => 4, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'UnfinishedBasementHeight' => 8, 'UnfinishedBasementFloorArea' => 2000 / 2, 'UnfinishedAtticHeight' => 6.59, 'UnfinishedAtticFloorArea' => 2000 / 2, 'BuildingHeight' => 8 + 8 + 8 + 6.59, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_crawlspace
    num_finished_spaces = 2
    args_hash = {}
    args_hash['foundation_type'] = 'crawlspace'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 23, 'ThermalZone' => 3, 'Space' => 4, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'CrawlspaceHeight' => 3, 'CrawlspaceFloorArea' => 2000 / 2, 'UnfinishedAtticHeight' => 6.59, 'UnfinishedAtticFloorArea' => 2000 / 2, 'BuildingHeight' => 3 + 8 + 8 + 6.59, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_pierandbeam
    num_finished_spaces = 2
    args_hash = {}
    args_hash['foundation_type'] = 'pier and beam'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 23, 'ThermalZone' => 3, 'Space' => 4, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'CrawlspaceHeight' => 3, 'CrawlspaceFloorArea' => 2000 / 2, 'UnfinishedAtticHeight' => 6.59, 'UnfinishedAtticFloorArea' => 2000 / 2, 'BuildingHeight' => 3 + 8 + 8 + 6.59, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_finished_attic_and_finished_basement
    num_finished_spaces = 4
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['foundation_height'] = 8.0
    args_hash['attic_type'] = 'finished attic'
    args_hash['foundation_type'] = 'finished basement'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 23, 'ThermalZone' => 2, 'Space' => 4, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 2000 / 4, 'FinishedAtticHeight' => 4.95, 'FinishedAtticFloorArea' => 2000 / 4, 'BuildingHeight' => 8 + 8 + 8 + 4.95, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_hip_finished_attic
    num_finished_spaces = 3
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['attic_type'] = 'finished attic'
    args_hash['roof_type'] = Constants.RoofTypeHip
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 17, 'ThermalZone' => 1, 'Space' => 3, 'SpaceType' => 1, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedAtticHeight' => 5.56, 'FinishedAtticFloorArea' => 2000 / 3, 'BuildingHeight' => 8 + 8 + 5.56, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_onestory_fbasement_hasgarage_noprotrusion_garageright_gableroof
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 1
    args_hash['garage_width'] = 12
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 28, 'ThermalZone' => 4, 'Space' => 4, 'SpaceType' => 4, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 1000, 'UnfinishedAtticHeight' => 7.22, 'UnfinishedAtticFloorArea' => 1240, 'GarageAtticHeight' => 3, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 7.22, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_onestory_fbasement_hasgarage_halfprotrusion_garageright_gableroof
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 1
    args_hash['garage_width'] = 12
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    args_hash['garage_protrusion'] = 0.5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 34, 'ThermalZone' => 4, 'Space' => 5, 'SpaceType' => 5, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 1000, 'UnfinishedAtticHeight' => 6.91, 'UnfinishedAtticFloorArea' => 1240, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 6.91, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_onestory_fbasement_hasgarage_halfprotrusion_garageright_gableroof_fattic
    num_finished_spaces = 3
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['garage_width'] = 12
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    args_hash['attic_type'] = 'finished attic'
    args_hash['garage_protrusion'] = 0.5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 34, 'ThermalZone' => 3, 'Space' => 4, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 586.66, 'FinishedAtticHeight' => 5.69, 'FinishedAtticFloorArea' => 826.66, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 5.69, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_onestory_ubasement_hasgarage_halfprotrusion_garageright_gableroof_fattic
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 2
    args_hash['garage_width'] = 12
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'unfinished basement'
    args_hash['attic_type'] = 'finished attic'
    args_hash['garage_protrusion'] = 0.5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 34, 'ThermalZone' => 3, 'Space' => 4, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'UnfinishedBasementHeight' => 8, 'UnfinishedBasementFloorArea' => 880, 'FinishedAtticHeight' => 6.59, 'FinishedAtticFloorArea' => 1120, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 6.59, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_onestory_fbasement_hasgarage_fullprotrusion_garageright_gableroof
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 1
    args_hash['garage_width'] = 12
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    args_hash['garage_protrusion'] = 1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 28, 'ThermalZone' => 4, 'Space' => 5, 'SpaceType' => 5, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 2000 / 2, 'UnfinishedAtticHeight' => 6.59, 'UnfinishedAtticFloorArea' => 1240, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 6.59, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_twostory_fbasement_hasgarage_noprotrusion_garageright_garagetobackwall_gableroof
    num_finished_spaces = 3
    args_hash = {}
    args_hash['garage_width'] = 10
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 30, 'ThermalZone' => 4, 'Space' => 5, 'SpaceType' => 4, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 600, 'UnfinishedAtticHeight' => 6, 'UnfinishedAtticFloorArea' => 800, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 200, 'BuildingHeight' => 8 + 8 + 8 + 6, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_twostory_fbasement_hasgarage_noprotrusion_garageright_gableroof
    num_finished_spaces = 3
    args_hash = {}
    args_hash['garage_width'] = 12
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 34, 'ThermalZone' => 4, 'Space' => 5, 'SpaceType' => 4, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 586.66, 'UnfinishedAtticHeight' => 6.08, 'UnfinishedAtticFloorArea' => 826.66, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 8 + 6.08, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_twostory_fbasement_hasgarage_halfprotrusion_garageright_gableroof
    num_finished_spaces = 3
    args_hash = {}
    args_hash['garage_width'] = 12
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    args_hash['garage_protrusion'] = 0.5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 42, 'ThermalZone' => 4, 'Space' => 5, 'SpaceType' => 4, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 586.66, 'UnfinishedAtticHeight' => 5.69, 'UnfinishedAtticFloorArea' => 826.66, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 8 + 5.69, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_twostory_fbasement_hasgarage_halfprotrusion_garageright_gableroof_fattic
    num_finished_spaces = 4
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['garage_width'] = 12
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    args_hash['attic_type'] = 'finished attic'
    args_hash['garage_protrusion'] = 0.5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 42, 'ThermalZone' => 3, 'Space' => 5, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 380, 'FinishedAtticHeight' => 4.95, 'FinishedAtticFloorArea' => 620, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 8 + 4.95, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_twostory_ubasement_hasgarage_halfprotrusion_garageright_gableroof_fattic
    num_finished_spaces = 3
    args_hash = {}
    args_hash['num_floors'] = 3
    args_hash['garage_width'] = 12
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'unfinished basement'
    args_hash['attic_type'] = 'finished attic'
    args_hash['garage_protrusion'] = 0.5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 42, 'ThermalZone' => 3, 'Space' => 5, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'UnfinishedBasementHeight' => 8, 'UnfinishedBasementFloorArea' => 506.66, 'FinishedAtticHeight' => 5.43, 'FinishedAtticFloorArea' => 746.66, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 8 + 5.43, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_twostory_fbasement_hasgarage_fullprotrusion_garageright_gableroof
    num_finished_spaces = 3
    args_hash = {}
    args_hash['garage_width'] = 12
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    args_hash['garage_protrusion'] = 1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 38, 'ThermalZone' => 4, 'Space' => 5, 'SpaceType' => 4, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 586.66, 'UnfinishedAtticHeight' => 5.28, 'UnfinishedAtticFloorArea' => 826.66, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 8 + 5.28, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_onestory_fbasement_hasgarage_noprotrusion_garageleft_gableroof
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 1
    args_hash['garage_width'] = 12
    args_hash['garage_position'] = 'Left'
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 28, 'ThermalZone' => 4, 'Space' => 4, 'SpaceType' => 4, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 1000, 'UnfinishedAtticHeight' => 7.22, 'UnfinishedAtticFloorArea' => 1240, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 7.22, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_onestory_fbasement_hasgarage_halfprotrusion_garageleft_gableroof
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 1
    args_hash['garage_width'] = 12
    args_hash['garage_position'] = 'Left'
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    args_hash['garage_protrusion'] = 0.5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 34, 'ThermalZone' => 4, 'Space' => 5, 'SpaceType' => 5, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 1000, 'UnfinishedAtticHeight' => 6.91, 'UnfinishedAtticFloorArea' => 1240, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 6.91, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_onestory_fbasement_hasgarage_fullprotrusion_garageleft_gableroof
    num_finished_spaces = 2
    args_hash = {}
    args_hash['num_floors'] = 1
    args_hash['garage_width'] = 12
    args_hash['garage_position'] = 'Left'
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    args_hash['garage_protrusion'] = 1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 28, 'ThermalZone' => 4, 'Space' => 5, 'SpaceType' => 5, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 2000 / 2, 'UnfinishedAtticHeight' => 6.59, 'UnfinishedAtticFloorArea' => 1240, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 6.59, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_twostory_fbasement_hasgarage_noprotrusion_garageleft_gableroof
    num_finished_spaces = 3
    args_hash = {}
    args_hash['garage_width'] = 12
    args_hash['garage_position'] = 'Left'
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 34, 'ThermalZone' => 4, 'Space' => 5, 'SpaceType' => 4, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 586.66, 'UnfinishedAtticHeight' => 6.08, 'UnfinishedAtticFloorArea' => 826.66, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 8 + 6.08, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_twostory_fbasement_hasgarage_halfprotrusion_garageleft_gableroof
    num_finished_spaces = 3
    args_hash = {}
    args_hash['garage_width'] = 12
    args_hash['garage_position'] = 'Left'
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    args_hash['garage_protrusion'] = 0.5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 42, 'ThermalZone' => 4, 'Space' => 5, 'SpaceType' => 4, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 586.66, 'UnfinishedAtticHeight' => 5.69, 'UnfinishedAtticFloorArea' => 826.66, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 8 + 5.69, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_twostory_fbasement_hasgarage_fullprotrusion_garageleft_gableroof
    num_finished_spaces = 3
    args_hash = {}
    args_hash['garage_width'] = 12
    args_hash['garage_position'] = 'Left'
    args_hash['foundation_height'] = 8.0
    args_hash['foundation_type'] = 'finished basement'
    args_hash['garage_protrusion'] = 1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 38, 'ThermalZone' => 4, 'Space' => 5, 'SpaceType' => 4, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 586.66, 'UnfinishedAtticHeight' => 5.28, 'UnfinishedAtticFloorArea' => 826.66, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 8 + 5.28, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_twostory_slab_hasgarage_noprotrusion_garageright_hiproof
    num_finished_spaces = 2
    args_hash = {}
    args_hash['garage_width'] = 12
    args_hash['roof_type'] = Constants.RoofTypeHip
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 26, 'ThermalZone' => 3, 'Space' => 4, 'SpaceType' => 3, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 2000 / 2, 'UnfinishedAtticHeight' => 6.91, 'UnfinishedAtticFloorArea' => 1120, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 240, 'BuildingHeight' => 8 + 8 + 6.91, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_gable_ridge_front_to_back
    num_finished_spaces = 2
    args_hash = {}
    args_hash['aspect_ratio'] = 0.75
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 17, 'ThermalZone' => 2, 'Space' => 3, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 8, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 2000 / 2, 'UnfinishedAtticHeight' => 7.84, 'UnfinishedAtticFloorArea' => 2000 / 2, 'BuildingHeight' => 8 + 8 + 7.84, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_hip_ridge_front_to_back
    num_finished_spaces = 2
    args_hash = {}
    args_hash['aspect_ratio'] = 0.75
    args_hash['roof_type'] = Constants.RoofTypeHip
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 17, 'ThermalZone' => 2, 'Space' => 3, 'SpaceType' => 2, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 6, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 2000, 'FinishedBasementHeight' => 8, 'FinishedBasementFloorArea' => 2000 / 2, 'UnfinishedAtticHeight' => 7.84, 'UnfinishedAtticFloorArea' => 2000 / 2, 'BuildingHeight' => 8 + 8 + 7.84, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
    _test_measure(nil, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, __method__)
  end

  def test_threestory_ufbasement_halfprotrusion_garageright_gableroof
    num_finished_spaces = 3
    args_hash = {}
    args_hash['aspect_ratio'] = '1.8'
    args_hash['foundation_height'] = '8'
    args_hash['foundation_type'] = 'unfinished basement'
    args_hash['garage_depth'] = '24'
    args_hash['garage_protrusion'] = '0.5'
    args_hash['garage_width'] = '12'
    args_hash['num_floors'] = '3'
    args_hash['total_ffa'] = '4500'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'BuildingUnit' => 1, 'Surface' => 50, 'ThermalZone' => 4, 'Space' => 6, 'SpaceType' => 4, 'PeopleDefinition' => num_finished_spaces, 'People' => num_finished_spaces, 'ScheduleConstant' => 1, 'ShadingSurfaceGroup' => 2, 'ShadingSurface' => 12, 'ExternalFile' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'FinishedFloorArea' => 4500, 'UnfinishedBasementHeight' => 8, 'UnfinishedBasementFloorArea' => 1308, 'UnfinishedAtticHeight' => 8.10, 'UnfinishedAtticFloorArea' => 1596, 'GarageAtticHeight' => 4, 'GarageFloorArea' => 288, 'BuildingHeight' => 8 + 8 + 8 + 8 + 8.10, 'Beds' => 3.0, 'Baths' => 2.0, 'NumOccupants' => 2.64, 'EavesDepth' => 2 }
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
    args_hash['num_bedrooms'] = '3.0, 3.0'
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Number of bedroom elements specified inconsistent with number of multifamily units defined in the model.')
  end

  def test_argument_error_baths_not_equal_to_units
    args_hash = {}
    args_hash['num_bathrooms'] = '2.0, 2.0'
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
    measure = CreateResidentialSingleFamilyDetachedGeometry.new

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
    measure = CreateResidentialSingleFamilyDetachedGeometry.new

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

    actual_values = { 'FinishedFloorArea' => 0, 'GarageFloorArea' => 0, 'FinishedBasementFloorArea' => 0, 'UnfinishedBasementFloorArea' => 0, 'CrawlspaceFloorArea' => 0, 'UnfinishedAtticFloorArea' => 0, 'FinishedAtticFloorArea' => 0, 'BuildingHeight' => 0, 'GarageAtticHeight' => 0, 'FinishedBasementHeight' => 0, 'UnfinishedBasementHeight' => 0, 'CrawlspaceHeight' => 0, 'UnfinishedAtticHeight' => 0, 'FinishedAtticHeight' => 0, 'NumOccupants' => 0 }
    new_spaces = []
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        if obj_type == 'Space'
          if new_object.name.to_s.start_with?('garage attic space')
            actual_values['GarageAtticHeight'] = Geometry.get_height_of_spaces([new_object])
            actual_values['UnfinishedAtticFloorArea'] += UnitConversions.convert(new_object.floorArea, 'm^2', 'ft^2')
          elsif new_object.name.to_s.start_with?('garage space')
            actual_values['GarageFloorArea'] += UnitConversions.convert(new_object.floorArea, 'm^2', 'ft^2')
          elsif new_object.name.to_s.start_with?('finished basement')
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
          elsif new_object.name.to_s.start_with?('finished attic') || new_object.name.to_s.start_with?("garage #{'finished attic'}")
            if Geometry.get_height_of_spaces([new_object]) > actual_values['FinishedAtticHeight']
              actual_values['FinishedAtticHeight'] = Geometry.get_height_of_spaces([new_object])
            end
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
        end
      end
    end
    if new_spaces.any? { |new_space| new_space.name.to_s.start_with?('garage attic space') }
      assert_in_epsilon(expected_values['GarageAtticHeight'], actual_values['GarageAtticHeight'], 0.01)
    end
    if new_spaces.any? { |new_space| new_space.name.to_s.start_with?('garage space') }
      assert_in_epsilon(expected_values['GarageFloorArea'], actual_values['GarageFloorArea'], 0.01)
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

    return model
  end
end
