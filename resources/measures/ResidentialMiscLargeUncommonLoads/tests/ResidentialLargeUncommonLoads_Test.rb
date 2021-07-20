# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ResidentialMiscLargeUncommonLoadsTest < MiniTest::Test
  def test_error_missing_geometry
    args_hash = {}
    result = _test_error(nil, args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'No building geometry has been defined.')
  end

  def test_new_construction_none
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  # Extra refrigerator

  def test_fridge_new_construction_none1
    # Using rated annual energy
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_fridge_new_construction_none2
    # Using energy multiplier
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_mult'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_fridge_new_construction_ef_6_9
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 1102.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1102.0, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_fridge_new_construction_mult_0_95
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 1102.0
    args_hash['fridge_mult'] = 0.95
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1046.9, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_fridge_new_construction_mult_1_05
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 1102.0
    args_hash['fridge_mult'] = 1.05
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1157.1, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_fridge_new_construction_modified_schedule
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 1102.0
    args_hash['fridge_weekday_sch'] = '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24'
    args_hash['fridge_weekend_sch'] = '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24'
    args_hash['fridge_monthly_sch'] = '1,2,3,4,5,6,7,8,9,10,11,12'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1102.0, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_fridge_new_construction_basement
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 1102.0
    args_hash['fridge_location'] = Constants.SpaceTypeFinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1102.0, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_fridge_retrofit_replace
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 1102.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1102.0, 'fridge_location' => args_hash['fridge_location'] }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 434.0
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 434.0, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_fridge_retrofit_remove
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 1102.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1102.0, 'fridge_location' => args_hash['fridge_location'] }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_fridge'] = false
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_fridge_argument_error_rated_annual_energy_negative
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Annual energy must be greater than or equal to 0.')
  end

  def test_fridge_argument_error_mult_negative
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_mult'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy multiplier must be greater than or equal to 0.')
  end

  def test_fridge_argument_error_weekday_sch_wrong_number_of_values
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_weekday_sch'] = '1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekday schedule.')
  end

  def test_fridge_argument_error_weekday_sch_not_number
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_weekday_sch'] = 'str,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekday schedule.')
  end

  def test_fridge_argument_error_weekend_sch_wrong_number_of_values
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_weekend_sch'] = '1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekend schedule.')
  end

  def test_fridge_argument_error_weekend_sch_not_number
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_weekend_sch'] = 'str,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekend schedule.')
  end

  def test_fridge_argument_error_monthly_sch_wrong_number_of_values
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_monthly_sch'] = '1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 12 numbers must be entered for the monthly schedule.')
  end

  def test_fridge_argument_error_monthly_sch_not_number
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_monthly_sch'] = 'str,1,1,1,1,1,1,1,1,1,1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 12 numbers must be entered for the monthly schedule.')
  end

  def test_fridge_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 1102.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => num_units, 'ElectricEquipment' => num_units, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => num_units * 1102.0, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_fridge_single_family_attached_new_construction_finished_basement
    num_units = 1
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 1102.0
    args_hash['fridge_location'] = Constants.SpaceTypeFinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => num_units * 1102.0, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_fridge_single_family_attached_new_construction_unfinished_basement
    num_units = 1
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 1102.0
    args_hash['fridge_location'] = Constants.SpaceTypeUnfinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => num_units * 1102.0, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure('SFA_4units_1story_UB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_fridge_multifamily_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_fridge'] = true
    args_hash['fridge_rated_annual_energy'] = 1102.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => num_units * 1102.0, 'fridge_location' => args_hash['fridge_location'] }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  # Freezer

  def test_freezer_new_construction_none1
    # Using rated annual energy
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_freezer_new_construction_none2
    # Using energy multiplier
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_mult'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_freezer_new_construction_ef_12
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 935.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 935.0, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_freezer_new_construction_mult_0_95
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 935.0
    args_hash['freezer_mult'] = 0.95
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 888.25, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_freezer_new_construction_mult_1_05
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 935.0
    args_hash['freezer_mult'] = 1.05
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 981.75, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_freezer_new_construction_modified_schedule
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 935.0
    args_hash['freezer_weekday_sch'] = '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24'
    args_hash['freezer_weekend_sch'] = '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24'
    args_hash['freezer_monthly_sch'] = '1,2,3,4,5,6,7,8,9,10,11,12'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 935.0, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_freezer_new_construction_basement
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 935.0
    args_hash['freezer_location'] = Constants.SpaceTypeFinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 935.0, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_freezer_retrofit_replace
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 935.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 935.0, 'freezer_location' => args_hash['freezer_location'] }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 417.0
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 417.0, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_freezer_retrofit_remove
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 935.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 935.0, 'freezer_location' => args_hash['freezer_location'] }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_freezer'] = false
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_freezer_argument_error_freezer_rated_annual_energy_negative
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Annual energy must be greater than or equal to 0.')
  end

  def test_freezer_argument_error_mult_negative
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_mult'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy multiplier must be greater than or equal to 0.')
  end

  def test_freezer_argument_error_weekday_sch_wrong_number_of_values
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_weekday_sch'] = '1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekday schedule.')
  end

  def test_freezer_argument_error_weekday_sch_not_number
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_weekday_sch'] = 'str,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekday schedule.')
  end

  def test_freezer_argument_error_weekend_sch_wrong_number_of_values
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_weekend_sch'] = '1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekend schedule.')
  end

  def test_freezer_argument_error_weekend_sch_not_number
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_weekend_sch'] = 'str,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekend schedule.')
  end

  def test_freezer_argument_error_monthly_sch_wrong_number_of_values
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_monthly_sch'] = '1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 12 numbers must be entered for the monthly schedule.')
  end

  def test_freezer_argument_error_monthly_sch_not_number
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_monthly_sch'] = 'str,1,1,1,1,1,1,1,1,1,1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 12 numbers must be entered for the monthly schedule.')
  end

  def test_freezer_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 935.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => num_units, 'ElectricEquipment' => num_units, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => num_units * 935.0, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_freezer_single_family_attached_new_construction_finished_basement
    num_units = 1
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 935.0
    args_hash['freezer_location'] = Constants.SpaceTypeFinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => num_units * 935.0, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_freezer_single_family_attached_new_construction_unfinished_basement
    num_units = 1
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 935.0
    args_hash['freezer_location'] = Constants.SpaceTypeUnfinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => num_units * 935.0, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure('SFA_4units_1story_UB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_freezer_multifamily_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_freezer'] = true
    args_hash['freezer_rated_annual_energy'] = 935.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => num_units * 935.0, 'freezer_location' => args_hash['freezer_location'] }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  # Pool

  def test_pool_new_construction_none1
    # Using annual energy
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['has_pool_heater_gas'] = true
    args_hash['has_pool_pump'] = true
    args_hash['pool_heater_elec_annual_energy'] = 0.0
    args_hash['pool_heater_gas_annual_energy'] = 0.0
    args_hash['pool_pump_annual_energy'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_pool_new_construction_none2
    # Using energy multiplier
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['has_pool_heater_gas'] = true
    args_hash['has_pool_pump'] = true
    args_hash['pool_heater_elec_mult'] = 0.0
    args_hash['pool_heater_gas_mult'] = 0.0
    args_hash['pool_pump_mult'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_pool_new_construction
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['has_pool_heater_gas'] = true
    args_hash['has_pool_pump'] = true
    args_hash['pool_heater_elec_annual_energy'] = 2300.0
    args_hash['pool_heater_gas_annual_energy'] = 222.0
    args_hash['pool_pump_annual_energy'] = 2250.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 2324.0 + 2273.4, 'Annual_therm' => 224.3 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_pool_new_construction_mult_0_004
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['has_pool_heater_gas'] = true
    args_hash['has_pool_pump'] = true
    args_hash['pool_heater_elec_annual_energy'] = 2300.0
    args_hash['pool_heater_gas_annual_energy'] = 222.0
    args_hash['pool_pump_annual_energy'] = 2250.0
    args_hash['pool_heater_elec_mult'] = 0.004
    args_hash['pool_heater_gas_mult'] = 0.004
    args_hash['pool_pump_mult'] = 0.004
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 9.3 + 9.1, 'Annual_therm' => 0.90 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_pool_new_construction_modified_schedule
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['has_pool_heater_gas'] = true
    args_hash['has_pool_pump'] = true
    args_hash['pool_heater_elec_annual_energy'] = 2300.0
    args_hash['pool_heater_gas_annual_energy'] = 222.0
    args_hash['pool_pump_annual_energy'] = 2250.0
    args_hash['pool_weekday_sch'] = '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24'
    args_hash['pool_weekend_sch'] = '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24'
    args_hash['pool_monthly_sch'] = '1,2,3,4,5,6,7,8,9,10,11,12'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 2324.0 + 2273.4, 'Annual_therm' => 224.3 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_pool_new_construction_no_scale_energy
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['has_pool_heater_gas'] = true
    args_hash['has_pool_pump'] = true
    args_hash['pool_heater_elec_annual_energy'] = 2300.0
    args_hash['pool_heater_gas_annual_energy'] = 222.0
    args_hash['pool_pump_annual_energy'] = 2250.0
    args_hash['pool_scale_energy'] = false
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 2300.0 + 2250.0, 'Annual_therm' => 222.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_pool_retrofit_replace
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['has_pool_heater_gas'] = true
    args_hash['has_pool_pump'] = true
    args_hash['pool_heater_elec_annual_energy'] = 2300.0
    args_hash['pool_heater_gas_annual_energy'] = 222.0
    args_hash['pool_pump_annual_energy'] = 2250.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 2324.0 + 2273.4, 'Annual_therm' => 224.3 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['has_pool_heater_gas'] = true
    args_hash['has_pool_pump'] = true
    args_hash['pool_heater_elec_annual_energy'] = 1150.0
    args_hash['pool_heater_gas_annual_energy'] = 111.0
    args_hash['pool_pump_annual_energy'] = 1125.0
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1162.0 + 1136.7, 'Annual_therm' => 112.15 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 4)
  end

  def test_pool_retrofit_remove
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['has_pool_heater_gas'] = true
    args_hash['has_pool_pump'] = true
    args_hash['pool_heater_elec_annual_energy'] = 2300.0
    args_hash['pool_heater_gas_annual_energy'] = 222.0
    args_hash['pool_pump_annual_energy'] = 2250.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 2324.0 + 2273.4, 'Annual_therm' => 224.3 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
    args_hash = {}
    args_hash['has_pool_heater_elec'] = false
    args_hash['has_pool_heater_gas'] = false
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_pool_argument_error_annual_energy_negative
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['pool_heater_elec_annual_energy'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Annual energy must be greater than or equal to 0.')
  end

  def test_pool_argument_error_mult_negative
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['pool_heater_elec_mult'] = -1.0
    args_hash['pool_heater_gas_mult'] = -1.0
    args_hash['pool_pump_mult'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy multiplier must be greater than or equal to 0.')
  end

  def test_pool_argument_error_weekday_sch_wrong_number_of_values
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['pool_weekday_sch'] = '1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekday schedule.')
  end

  def test_pool_argument_error_weekday_sch_not_number
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['pool_weekday_sch'] = 'str,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekday schedule.')
  end

  def test_pool_argument_error_weekend_sch_wrong_number_of_values
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['pool_weekend_sch'] = '1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekend schedule.')
  end

  def test_pool_argument_error_weekend_sch_not_number
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['pool_weekend_sch'] = 'str,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekend schedule.')
  end

  def test_pool_argument_error_monthly_sch_wrong_number_of_values
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['pool_monthly_sch'] = '1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 12 numbers must be entered for the monthly schedule.')
  end

  def test_pool_argument_error_monthly_sch_not_number
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['pool_monthly_sch'] = 'str,1,1,1,1,1,1,1,1,1,1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 12 numbers must be entered for the monthly schedule.')
  end

  def test_pool_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['pool_heater_elec_annual_energy'] = 2300.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1993.2 * num_units, 'Annual_therm' => 0 }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_pool_multifamily_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_pool_heater_elec'] = true
    args_hash['pool_heater_elec_annual_energy'] = 2300.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1993.2 * num_units, 'Annual_therm' => 0 }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  # Hot Tub

  def test_hot_tub_new_construction_none1
    # Using annual energy
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['has_hot_tub_heater_gas'] = true
    args_hash['has_hot_tub_pump'] = true
    args_hash['hot_tub_heater_elec_annual_energy'] = 0.0
    args_hash['hot_tub_heater_gas_annual_energy'] = 0.0
    args_hash['hot_tub_pump_annual_energy'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_hot_tub_new_construction_none2
    # Using energy multiplier
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['has_hot_tub_heater_gas'] = true
    args_hash['has_hot_tub_pump'] = true
    args_hash['hot_tub_heater_elec_mult'] = 0.0
    args_hash['hot_tub_heater_gas_mult'] = 0.0
    args_hash['hot_tub_pump_mult'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_hot_tub_new_construction
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['has_hot_tub_heater_gas'] = true
    args_hash['has_hot_tub_pump'] = true
    args_hash['hot_tub_heater_elec_annual_energy'] = 1027.3
    args_hash['hot_tub_heater_gas_annual_energy'] = 81.0
    args_hash['hot_tub_pump_annual_energy'] = 1014.1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1038.0 + 1024.7, 'Annual_therm' => 81.8 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_hot_tub_new_construction_mult_0_048
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['has_hot_tub_heater_gas'] = true
    args_hash['has_hot_tub_pump'] = true
    args_hash['hot_tub_heater_elec_annual_energy'] = 1027.3
    args_hash['hot_tub_heater_gas_annual_energy'] = 81.0
    args_hash['hot_tub_pump_annual_energy'] = 1014.1
    args_hash['hot_tub_heater_elec_mult'] = 0.048
    args_hash['hot_tub_heater_gas_mult'] = 0.048
    args_hash['hot_tub_pump_mult'] = 0.048
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 49.8 + 49.2, 'Annual_therm' => 3.93 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_hot_tub_new_construction_modified_schedule
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['has_hot_tub_heater_gas'] = true
    args_hash['has_hot_tub_pump'] = true
    args_hash['hot_tub_heater_elec_annual_energy'] = 1027.3
    args_hash['hot_tub_heater_gas_annual_energy'] = 81.0
    args_hash['hot_tub_pump_annual_energy'] = 1014.1
    args_hash['hot_tub_weekday_sch'] = '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24'
    args_hash['hot_tub_weekend_sch'] = '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24'
    args_hash['hot_tub_monthly_sch'] = '1,2,3,4,5,6,7,8,9,10,11,12'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1038.0 + 1024.7, 'Annual_therm' => 81.8 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_hot_tub_new_construction_no_scale_energy
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['has_hot_tub_heater_gas'] = true
    args_hash['has_hot_tub_pump'] = true
    args_hash['hot_tub_heater_elec_annual_energy'] = 1027.3
    args_hash['hot_tub_heater_gas_annual_energy'] = 81.0
    args_hash['hot_tub_pump_annual_energy'] = 1014.1
    args_hash['hot_tub_scale_energy'] = false
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1027.3 + 1014.1, 'Annual_therm' => 81.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_hot_tub_retrofit_replace
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['has_hot_tub_heater_gas'] = true
    args_hash['has_hot_tub_pump'] = true
    args_hash['hot_tub_heater_elec_annual_energy'] = 1027.3
    args_hash['hot_tub_heater_gas_annual_energy'] = 81.0
    args_hash['hot_tub_pump_annual_energy'] = 1014.1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1038.0 + 1024.7, 'Annual_therm' => 81.8 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['has_hot_tub_heater_gas'] = true
    args_hash['has_hot_tub_pump'] = true
    args_hash['hot_tub_heater_elec_annual_energy'] = 1150.0
    args_hash['hot_tub_heater_gas_annual_energy'] = 111.0
    args_hash['hot_tub_pump_annual_energy'] = 1125.0
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1162.0 + 1136.7, 'Annual_therm' => 112.15 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 4)
  end

  def test_hot_tub_retrofit_remove
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['has_hot_tub_heater_gas'] = true
    args_hash['has_hot_tub_pump'] = true
    args_hash['hot_tub_heater_elec_annual_energy'] = 1027.3
    args_hash['hot_tub_heater_gas_annual_energy'] = 81.0
    args_hash['hot_tub_pump_annual_energy'] = 1014.1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 1038.0 + 1024.7, 'Annual_therm' => 81.8 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = false
    args_hash['has_hot_tub_heater_gas'] = false
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleRuleset' => 1 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_hot_tub_argument_error_annual_energy_negative
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['hot_tub_heater_elec_annual_energy'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Annual energy must be greater than or equal to 0.')
  end

  def test_hot_tub_argument_error_mult_negative
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['hot_tub_heater_elec_mult'] = -1.0
    args_hash['hot_tub_heater_gas_mult'] = -1.0
    args_hash['hot_tub_pump_mult'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy multiplier must be greater than or equal to 0.')
  end

  def test_hot_tub_argument_error_weekday_sch_wrong_number_of_values
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['hot_tub_weekday_sch'] = '1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekday schedule.')
  end

  def test_hot_tub_argument_error_weekday_sch_not_number
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['hot_tub_weekday_sch'] = 'str,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekday schedule.')
  end

  def test_hot_tub_argument_error_weekend_sch_wrong_number_of_values
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['hot_tub_weekend_sch'] = '1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekend schedule.')
  end

  def test_hot_tub_argument_error_weekend_sch_not_number
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['hot_tub_weekend_sch'] = 'str,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 24 numbers must be entered for the weekend schedule.')
  end

  def test_hot_tub_argument_error_monthly_sch_wrong_number_of_values
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['hot_tub_monthly_sch'] = '1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 12 numbers must be entered for the monthly schedule.')
  end

  def test_hot_tub_argument_error_monthly_sch_not_number
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['hot_tub_monthly_sch'] = 'str,1,1,1,1,1,1,1,1,1,1,1'
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'A comma-separated string of 12 numbers must be entered for the monthly schedule.')
  end

  def test_hot_tub_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['hot_tub_heater_elec_annual_energy'] = 1027.3
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 891.58 * num_units, 'Annual_therm' => 0 }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_hot_tub_multifamily_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_hot_tub_heater_elec'] = true
    args_hash['hot_tub_heater_elec_annual_energy'] = 1027.3
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleRuleset' => 1 }
    expected_values = { 'Annual_kwh' => 891.58 * num_units, 'Annual_therm' => 0 }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  # Well Pump

  def test_well_pump_new_construction_none1
    # Using annual energy
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_annual_energy'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_well_pump_new_construction_none2
    # Using energy multiplier
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_mult'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_well_pump_new_construction_electric
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_annual_energy'] = 400.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 404.2, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_well_pump_new_construction_mult_0_127
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_annual_energy'] = 400.0
    args_hash['well_pump_mult'] = 0.127
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 51.3, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_well_pump_new_construction_no_scale_energy
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_annual_energy'] = 400.0
    args_hash['well_pump_scale_energy'] = false
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 400.0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_well_pump_retrofit_replace
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_annual_energy'] = 400.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 404.2, 'Annual_therm' => 0 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_annual_energy'] = 200.0
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 202.1, 'Annual_therm' => 0 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_well_pump_retrofit_remove
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_annual_energy'] = 400.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 404.2, 'Annual_therm' => 0 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_annual_energy'] = 0.0
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0.0, 'Annual_therm' => 0 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_well_pump_argument_error_annual_energy_negative
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_annual_energy'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Annual energy must be greater than or equal to 0.')
  end

  def test_well_pump_argument_error_mult_negative
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_mult'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy multiplier must be greater than or equal to 0.')
  end

  def test_well_pump_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_annual_energy'] = 400.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 346.64 * num_units, 'Annual_therm' => 0 }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_well_pump_multifamily_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_well_pump'] = true
    args_hash['well_pump_annual_energy'] = 400.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 346.64 * num_units, 'Annual_therm' => 0 }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  # Electric Vehicle

  def test_electric_vehicle_new_construction_none
    # Using annual energy
    args_hash = {}
    args_hash['has_electric_vehicle'] = true
    args_hash['ev_annual_energy'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_no_electric_vehicle_new_construction_none
    # Using annual energy
    args_hash = {}
    args_hash['has_electric_vehicle'] = false
    args_hash['ev_annual_energy'] = 2000.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_electric_vehicle_new_construction_electric
    args_hash = {}
    args_hash['has_electric_vehicle'] = true
    args_hash['ev_annual_energy'] = 2000.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 2000, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_electric_vehicle_retrofit_replace
    args_hash = {}
    args_hash['has_electric_vehicle'] = true
    args_hash['ev_annual_energy'] = 2000.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 2000, 'Annual_therm' => 0 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_electric_vehicle'] = true
    args_hash['ev_annual_energy'] = 2500.0
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 2500, 'Annual_therm' => 0 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_electric_vehicle_retrofit_remove_by_boolean
    args_hash = {}
    args_hash['has_electric_vehicle'] = true
    args_hash['ev_annual_energy'] = 2000.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 2000, 'Annual_therm' => 0 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_electric_vehicle'] = false
    args_hash['ev_annual_energy'] = 2000.0
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0.0, 'Annual_therm' => 0 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_electric_vehicle_mult
    args_hash = {}
    args_hash['has_electric_vehicle'] = true
    args_hash['ev_annual_energy'] = 2000.0
    args_hash['ev_charger_mult'] = 1
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 2000, 'Annual_therm' => 0 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash['ev_charger_mult'] = 2
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    # This test passes, so it must be deleting the above objects appropriately and building new ones. The following line doesn't do anything,
    # but it does help developers understand that it's making new objects again, even though the variable is identical to the one above.
    # expected_num_new_objects = { "ElectricEquipmentDefinition" => 1, "ElectricEquipment" => 1, "ScheduleFile" => 1 }
    expected_values = { 'Annual_kwh' => 4000.0, 'Annual_therm' => 0 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_electric_vehicle_argument_error_mult_negative
    args_hash = {}
    args_hash['has_electric_vehicle'] = true
    args_hash['ev_charger_mult'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy multiplier must be greater than or equal to 0.')
  end

  def test_electric_vehicle_new_construction_mult_0
    # Using energy multiplier
    args_hash = {}
    args_hash['has_electric_vehicle'] = true
    args_hash['ev_charger_mult'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_electric_vehicle_retrofit_remove
    args_hash = {}
    args_hash['has_electric_vehicle'] = true
    args_hash['ev_annual_energy'] = 2000.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 2000, 'Annual_therm' => 0 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_electric_vehicle'] = true
    args_hash['ev_annual_energy'] = 0.0
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'ScheduleFile' => 1 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0.0, 'Annual_therm' => 0 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_electric_vehicle_argument_error_annual_energy_negative
    args_hash = {}
    args_hash['has_electric_vehicle'] = true
    args_hash['ev_annual_energy'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Annual energy must be greater than or equal to 0.')
  end

  # Gas Fireplace

  def test_gas_fireplace_new_construction_none1
    # Using annual energy
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_fireplace_new_construction_none2
    # Using energy multiplier
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_mult'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_fireplace_new_construction_gas
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 60.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 60.6, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_fireplace_new_construction_mult_0_032
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 60.0
    args_hash['gas_fireplace_mult'] = 0.032
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 1.94, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_fireplace_new_construction_no_scale_energy
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 60.0
    args_hash['gas_fireplace_scale_energy'] = false
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 60.0, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_fireplace_new_construction_basement
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 60.0
    args_hash['gas_fireplace_location'] = Constants.SpaceTypeFinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 60.6, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_fireplace_new_construction_garage
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 60.0
    args_hash['gas_fireplace_location'] = Constants.SpaceTypeGarage
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 60.6, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_fireplace_retrofit_replace
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 60.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 60.6, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 30.0
    expected_num_del_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 30.3, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_gas_fireplace_retrofit_remove
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 60.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 60.6, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 0.0
    expected_num_del_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_gas_fireplace_argument_error_base_energy_negative
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Annual energy must be greater than or equal to 0.')
  end

  def test_gas_fireplace_argument_error_mult_negative
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_mult'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy multiplier must be greater than or equal to 0.')
  end

  def test_gas_fireplace_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 60.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => num_units, 'GasEquipment' => num_units, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => num_units * 52.0, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_gas_fireplace_single_family_attached_new_construction_finished_basement
    num_units = 1
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 60.0
    args_hash['gas_fireplace_location'] = Constants.SpaceTypeFinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipment' => num_units, 'GasEquipmentDefinition' => num_units, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 52.0 * num_units, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_gas_fireplace_single_family_attached_new_construction_unfinished_basement
    num_units = 1
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 60.0
    args_hash['gas_fireplace_location'] = Constants.SpaceTypeUnfinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipment' => num_units, 'GasEquipmentDefinition' => num_units, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 52.0 * num_units, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure('SFA_4units_1story_UB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_gas_fireplace_multifamily_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_gas_fireplace'] = true
    args_hash['gas_fireplace_annual_energy'] = 60.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipment' => num_units, 'GasEquipmentDefinition' => num_units, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 52.0 * num_units, 'gas_fireplace_location' => args_hash['gas_fireplace_location'] }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  # Gas Grill

  def test_gas_grill_new_construction_none1
    # Using annual energy
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_annual_energy'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_grill_new_construction_none2
    # Using energy multiplier
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_mult'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_grill_new_construction_gas
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_annual_energy'] = 30.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 30.3 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_grill_new_construction_mult_0_029
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_annual_energy'] = 30.0
    args_hash['gas_grill_mult'] = 0.029
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0.88 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_grill_new_construction_no_scale_energy
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_annual_energy'] = 30.0
    args_hash['gas_grill_scale_energy'] = false
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 30.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_grill_retrofit_replace
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_annual_energy'] = 30.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 30.3 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_annual_energy'] = 15.0
    expected_num_del_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 15.15 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_gas_grill_retrofit_remove
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_annual_energy'] = 30.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 30.3 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_annual_energy'] = 0.0
    expected_num_del_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_gas_grill_argument_error_base_energy_negative
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_annual_energy'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Annual energy must be greater than or equal to 0.')
  end

  def test_gas_grill_argument_error_mult_negative
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_mult'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy multiplier must be greater than or equal to 0.')
  end

  def test_gas_grill_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_annual_energy'] = 30.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => num_units, 'GasEquipment' => num_units, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 26.0 * num_units }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_gas_grill_multifamily_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_gas_grill'] = true
    args_hash['gas_grill_annual_energy'] = 30.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipment' => num_units, 'GasEquipmentDefinition' => num_units, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 26.0 * num_units }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  # Gas Lighting

  def test_gas_lighting_new_construction_none1
    # Using annual energy
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_annual_energy'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_lighting_new_construction_none2
    # Using energy multiplier
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_mult'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_lighting_new_construction_gas
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_annual_energy'] = 19.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 19.2 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_lighting_new_construction_mult_0_012
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_annual_energy'] = 19.0
    args_hash['gas_lighting_mult'] = 0.012
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0.23 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_lighting_new_construction_no_scale_energy
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_annual_energy'] = 19.0
    args_hash['gas_lighting_scale_energy'] = false
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 19.0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_gas_lighting_retrofit_replace
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_annual_energy'] = 19.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 19.2 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_annual_energy'] = 9.5
    expected_num_del_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 9.6 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_gas_lighting_retrofit_remove
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_annual_energy'] = 19.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 19.2 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_annual_energy'] = 0.0
    expected_num_del_objects = { 'GasEquipmentDefinition' => 1, 'GasEquipment' => 1, 'ScheduleFile' => 1 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_gas_lighting_argument_error_base_energy_negative
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_annual_energy'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Annual energy must be greater than or equal to 0.')
  end

  def test_gas_lighting_argument_error_mult_negative
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_mult'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy multiplier must be greater than or equal to 0.')
  end

  def test_gas_lighting_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_annual_energy'] = 19.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipmentDefinition' => num_units, 'GasEquipment' => num_units, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 16.47 * num_units, 'Space' => args_hash['space'] }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_gas_lighting_multifamily_new_construction
    num_units = 1
    args_hash = {}
    args_hash['has_gas_lighting'] = true
    args_hash['gas_lighting_annual_energy'] = 19.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GasEquipment' => num_units, 'GasEquipmentDefinition' => num_units, 'ScheduleFile' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'Annual_therm' => 16.47 * num_units, 'Space' => args_hash['space'] }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ResidentialMiscLargeUncommonLoads.new

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

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_infos = 0, num_warnings = 0)
    # create an instance of the measure
    measure = ResidentialMiscLargeUncommonLoads.new

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
    assert(result.finalCondition.is_initialized)

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = ['ScheduleRule', 'ScheduleDay', 'ScheduleTypeLimits']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    actual_values = { 'Annual_kwh' => 0, 'Annual_therm' => 0, 'fridge_location' => [], 'freezer_location' => [], 'gas_fireplace_location' => [] }
    schedules_file = nil
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        if obj_type == 'ElectricEquipment'
          if new_object.name.to_s.include?(Constants.ObjectNameWellPump) || new_object.name.to_s.include?(Constants.ObjectNameElectricVehicle)
            if schedules_file.nil?
              schedule_file = new_object.schedule.get.to_ScheduleFile.get
              schedules_file = SchedulesFile.new(runner: runner, model: model)
            end
            full_load_hrs = schedules_file.annual_equivalent_full_load_hrs(col_name: schedule_file.name.to_s)
          else
            full_load_hrs = Schedule.annual_equivalent_full_load_hrs(model.getYearDescription, new_object.schedule.get)
          end
          actual_values['Annual_kwh'] += UnitConversions.convert(full_load_hrs * new_object.designLevel.get * new_object.multiplier, 'Wh', 'kWh')
          if new_object.name.to_s.start_with? Constants.ObjectNameExtraRefrigerator
            actual_values['fridge_location'] << new_object.space.get.spaceType.get.standardsSpaceType.get
          elsif new_object.name.to_s.start_with? Constants.ObjectNameFreezer
            actual_values['freezer_location'] << new_object.space.get.spaceType.get.standardsSpaceType.get
          end
        elsif obj_type == 'GasEquipment'
          if new_object.name.to_s.include?(Constants.ObjectNameGasFireplace) || new_object.name.to_s.include?(Constants.ObjectNameGasGrill) || new_object.name.to_s.include?(Constants.ObjectNameGasLighting)
            if schedules_file.nil?
              schedule_file = new_object.schedule.get.to_ScheduleFile.get
              schedules_file = SchedulesFile.new(runner: runner, model: model)
            end
            full_load_hrs = schedules_file.annual_equivalent_full_load_hrs(col_name: schedule_file.name.to_s)
          else
            full_load_hrs = Schedule.annual_equivalent_full_load_hrs(model.getYearDescription, new_object.schedule.get)
          end
          actual_values['Annual_therm'] += UnitConversions.convert(full_load_hrs * new_object.designLevel.get * new_object.multiplier, 'Wh', 'therm')
          if new_object.name.to_s.start_with? Constants.ObjectNameGasFireplace
            actual_values['gas_fireplace_location'] << new_object.space.get.spaceType.get.standardsSpaceType.get
          end
        end
      end
    end
    if not expected_values['Annual_kwh'].nil?
      assert_in_epsilon(expected_values['Annual_kwh'], actual_values['Annual_kwh'], 0.01)
    end
    if not expected_values['Annual_therm'].nil?
      assert_in_epsilon(expected_values['Annual_therm'], actual_values['Annual_therm'], 0.01)
    end

    ['fridge_location', 'freezer_location', 'gas_fireplace_location'].each do |location|
      if not expected_values[location].nil?
        assert_equal(1, actual_values[location].uniq.size)
        assert_equal(expected_values[location], actual_values[location][0])
      end
    end

    return model
  end
end
