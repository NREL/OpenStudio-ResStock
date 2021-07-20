# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ResidentialClothesWasherTest < MiniTest::Test
  def test_new_construction_none
    # Using energy multiplier
    args_hash = {}
    args_hash['mult_e'] = 0.0
    args_hash['mult_hw'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'HotWater_gpd' => 0, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_standard
    args_hash = {}
    args_hash['imef'] = (1.41 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 387
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 42.9, 'HotWater_gpd' => 10.00, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_energystar
    args_hash = {}
    args_hash['imef'] = (2.47 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 123
    args_hash['annual_cost'] = 9.0
    args_hash['drum_volume'] = 3.68
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 34.9, 'HotWater_gpd' => 2.27, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_energystar_more_efficient
    # Kenmore - 4126#
    # https://www.kenmore.com/products/kenmore-41262-4-5-cu-ft-front-load-washer-white
    args_hash = {}
    args_hash['imef'] = (3.2 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 90
    args_hash['annual_cost'] = 8
    args_hash['drum_volume'] = 4.5
    args_hash['test_date'] = 2013
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 33.2, 'HotWater_gpd' => 0.93, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_energystar_most_efficient
    # Samsung - WF45K62**A*
    # https://www.lowes.com/pd/Samsung-AddWash-4-5-cu-ft-High-Efficiency-Stackable-Front-Load-Washer-White-ENERGY-STAR/1000041269
    args_hash = {}
    args_hash['imef'] = (3.28 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 75
    args_hash['annual_cost'] = 7
    args_hash['drum_volume'] = 4.5
    args_hash['test_date'] = 2013
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 30.8, 'HotWater_gpd' => 0.67, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_cee_advanced_tier
    # LG - WM9500H*A
    # https://www.homedepot.com/p/LG-SIGNATURE-5-8-cu-ft-High-Efficiency-Smart-Front-Load-Washer-with-TurboWash-and-Steam-in-Black-Stainless-Steel-ENERGY-STAR-WM9500HKA/207024865
    args_hash = {}
    args_hash['imef'] = (3.45 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 120
    args_hash['annual_cost'] = 14
    args_hash['drum_volume'] = 5.8
    args_hash['test_date'] = 2013
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 58.7, 'HotWater_gpd' => 0.13, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_standard_2003
    args_hash = {}
    args_hash['imef'] = (1.41 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 387
    args_hash['test_date'] = 2003
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 176.0, 'HotWater_gpd' => 4.80, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_standard_mult_0_80
    args_hash = {}
    args_hash['imef'] = (1.41 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 387
    args_hash['mult_e'] = 0.8
    args_hash['mult_hw'] = 0.8
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 34.3, 'HotWater_gpd' => 8.00, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_standard_int_heater
    args_hash = {}
    args_hash['imef'] = (1.41 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 387
    args_hash['internal_heater'] = 'true'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 42.9, 'HotWater_gpd' => 10.00, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_standard_no_thermostatic_control
    args_hash = {}
    args_hash['imef'] = (1.41 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 387
    args_hash['thermostatic_control'] = 'false'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 42.9, 'HotWater_gpd' => 8.67, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_energystar_cold_inlet
    args_hash = {}
    args_hash['imef'] = (2.47 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 123.0
    args_hash['annual_cost'] = 9.0
    args_hash['drum_volume'] = 3.68
    args_hash['cold_cycle'] = 'true'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 34.9, 'HotWater_gpd' => 2.27, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_energystar_cold_inlet_tankless
    args_hash = {}
    args_hash['imef'] = (2.47 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 123.0
    args_hash['annual_cost'] = 9.0
    args_hash['drum_volume'] = 3.68
    args_hash['cold_cycle'] = 'true'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 34.9, 'HotWater_gpd' => 2.27, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTankless.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_basement
    args_hash = {}
    args_hash['imef'] = (1.41 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 387
    args_hash['location'] = Constants.SpaceTypeFinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 42.9, 'HotWater_gpd' => 10.00, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_retrofit_replace
    args_hash = {}
    args_hash['imef'] = (1.41 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 387
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 42.9, 'HotWater_gpd' => 10.00, 'Location' => args_hash['location'] }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['imef'] = (2.47 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 123.0
    args_hash['annual_cost'] = 9.0
    args_hash['drum_volume'] = 3.68
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 34.9, 'HotWater_gpd' => 2.27, 'Location' => args_hash['location'] }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_with_elec_dryer
    args_hash = {}
    args_hash['imef'] = (2.47 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 123.0
    args_hash['annual_cost'] = 9.0
    args_hash['drum_volume'] = 3.68
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 3, 'ScheduleConstant' => 1 }
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 3, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 34.9, 'HotWater_gpd' => 2.27, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank_ClothesWasher_ElecClothesDryer.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_retrofit_replace_with_gas_dryer
    args_hash = {}
    args_hash['imef'] = (2.47 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 123.0
    args_hash['annual_cost'] = 9.0
    args_hash['drum_volume'] = 3.68
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'OtherEquipmentDefinition' => 1, 'OtherEquipment' => 1 }
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'OtherEquipmentDefinition' => 1, 'OtherEquipment' => 1 }
    expected_values = { 'Annual_kwh' => 34.9, 'HotWater_gpd' => 2.27, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank_ClothesWasher_GasClothesDryer.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_retrofit_replace_with_propane_dryer
    args_hash = {}
    args_hash['imef'] = (2.47 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 123.0
    args_hash['annual_cost'] = 9.0
    args_hash['drum_volume'] = 3.68
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'OtherEquipmentDefinition' => 1, 'OtherEquipment' => 1 }
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 2, 'ElectricEquipment' => 2, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'OtherEquipmentDefinition' => 1, 'OtherEquipment' => 1 }
    expected_values = { 'Annual_kwh' => 34.9, 'HotWater_gpd' => 2.27, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank_ClothesWasher_PropaneClothesDryer.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 3)
  end

  def test_retrofit_remove
    args_hash = {}
    args_hash['imef'] = (1.41 - 0.503) / 0.95
    args_hash['rated_annual_energy'] = 387
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 42.9, 'HotWater_gpd' => 10.00, 'Location' => args_hash['location'] }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['mult_e'] = 0.0
    args_hash['mult_hw'] = 0.0
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'HotWater_gpd' => 0, 'Location' => args_hash['location'] }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_argument_error_cw_imef_negative
    args_hash = {}
    args_hash['imef'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Integrated modified energy factor must be greater than 0.0.')
  end

  def test_argument_error_cw_imef_zero
    args_hash = {}
    args_hash['imef'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Integrated modified energy factor must be greater than 0.0.')
  end

  def test_argument_error_cw_rated_annual_energy_negative
    args_hash = {}
    args_hash['rated_annual_energy'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Rated annual consumption must be greater than 0.0.')
  end

  def test_argument_error_cw_rated_annual_energy_zero
    args_hash = {}
    args_hash['rated_annual_energy'] = 0.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Rated annual consumption must be greater than 0.0.')
  end

  def test_argument_error_cw_test_date_negative
    args_hash = {}
    args_hash['test_date'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Test date must be greater than or equal to 1900.')
  end

  def test_argument_error_cw_test_date_zero
    args_hash = {}
    args_hash['test_date'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Test date must be greater than or equal to 1900.')
  end

  def test_argument_error_cw_annual_cost_negative
    args_hash = {}
    args_hash['annual_cost'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Annual cost with gas DHW must be greater than 0.0.')
  end

  def test_argument_error_cw_annual_cost_zero
    args_hash = {}
    args_hash['annual_cost'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Annual cost with gas DHW must be greater than 0.0.')
  end

  def test_argument_error_cw_drum_volume_negative
    args_hash = {}
    args_hash['drum_volume'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Drum volume must be greater than 0.0.')
  end

  def test_argument_error_cw_drum_volume_zero
    args_hash = {}
    args_hash['drum_volume'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Drum volume must be greater than 0.0.')
  end

  def test_argument_error_cw_mult_e_negative
    args_hash = {}
    args_hash['mult_e'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Occupancy energy multiplier must be greater than or equal to 0.0.')
  end

  def test_argument_error_cw_mult_hw_negative
    args_hash = {}
    args_hash['mult_hw'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Occupancy hot water multiplier must be greater than or equal to 0.0.')
  end

  def test_warning_missing_water_heater
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'HotWater_gpd' => 0, 'Location' => nil }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0, 1)
  end

  def test_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleConstant' => num_units, 'ScheduleFile' => 2, 'WaterUseEquipment' => num_units, 'WaterUseEquipmentDefinition' => num_units }
    expected_values = { 'Annual_kwh' => num_units * 42.94, 'HotWater_gpd' => num_units * 9.99, 'Location' => args_hash['location'] }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction_finished_basement
    num_units = 1
    args_hash = {}
    args_hash['location'] = Constants.SpaceTypeFinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleConstant' => num_units, 'ScheduleFile' => 2, 'WaterUseEquipment' => num_units, 'WaterUseEquipmentDefinition' => num_units }
    expected_values = { 'Annual_kwh' => num_units * 42.94, 'HotWater_gpd' => num_units * 9.99, 'Location' => args_hash['location'] }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction_unfinished_basement
    num_units = 1
    args_hash = {}
    args_hash['location'] = Constants.SpaceTypeUnfinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleConstant' => num_units, 'ScheduleFile' => 2, 'WaterUseEquipment' => num_units, 'WaterUseEquipmentDefinition' => num_units }
    expected_values = { 'Annual_kwh' => num_units * 42.94, 'HotWater_gpd' => num_units * 9.99, 'Location' => args_hash['location'] }
    _test_measure('SFA_4units_1story_UB_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleConstant' => num_units, 'ScheduleFile' => 2, 'WaterUseEquipment' => num_units, 'WaterUseEquipmentDefinition' => num_units }
    expected_values = { 'Annual_kwh' => 343.54 / 8, 'HotWater_gpd' => 79.99 / 8, 'Location' => args_hash['location'] }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ResidentialClothesWasher.new

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
    measure = ResidentialClothesWasher.new

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
    obj_type_exclusions = ['WaterUseConnections', 'Node', 'ScheduleTypeLimits', 'ScheduleRule', 'ScheduleDay']
    obj_name_exclusions = ['Always On Discrete']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions, obj_name_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions, obj_name_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    actual_values = { 'Annual_kwh' => 0, 'HotWater_gpd' => 0, 'Location' => [] }
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        next if not new_object.name.to_s.start_with? Constants.ObjectNameClothesWasher

        if obj_type == 'ElectricEquipment'
          schedule_file = new_object.schedule.get.to_ScheduleFile.get
          schedules_file = SchedulesFile.new(runner: runner, model: model)
          full_load_hrs = schedules_file.annual_equivalent_full_load_hrs(col_name: schedule_file.name.to_s)
          actual_values['Annual_kwh'] += UnitConversions.convert(full_load_hrs * new_object.designLevel.get * new_object.multiplier, 'Wh', 'kWh')
          actual_values['Location'] << new_object.space.get.spaceType.get.standardsSpaceType.get
        elsif obj_type == 'WaterUseEquipment'
          schedule_file = new_object.flowRateFractionSchedule.get.to_ScheduleFile.get
          schedules_file = SchedulesFile.new(runner: runner, model: model)
          full_load_hrs = schedules_file.annual_equivalent_full_load_hrs(col_name: schedule_file.name.to_s)
          peak_flow_rate = UnitConversions.convert(new_object.waterUseEquipmentDefinition.peakFlowRate * new_object.multiplier, 'm^3/s', 'gal/min')
          daily_gallons = (full_load_hrs * 60 * peak_flow_rate) / 365 # multiply by 60 because peak_flow_rate is in gal/min
          actual_values['HotWater_gpd'] += daily_gallons
          actual_values['Location'] << new_object.space.get.spaceType.get.standardsSpaceType.get
        end
      end
    end
    assert_in_epsilon(expected_values['Annual_kwh'], actual_values['Annual_kwh'], 0.05)
    assert_in_epsilon(expected_values['HotWater_gpd'], actual_values['HotWater_gpd'], 0.05)
    if not expected_values['Location'].nil?
      assert_equal(1, actual_values['Location'].uniq.size)
      assert_equal(expected_values['Location'], actual_values['Location'][0])
    end

    return model
  end
end
