# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ResidentialDishwasherTest < MiniTest::Test
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

  def test_new_construction_318_rated_kwh
    args_hash = {}
    args_hash['num_settings'] = 8
    args_hash['rated_annual_energy'] = 318
    args_hash['annual_gas_cost'] = 24
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 111, 'HotWater_gpd' => 3.10, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_290_rated_kwh
    args_hash = {}
    args_hash['num_settings'] = 12
    args_hash['rated_annual_energy'] = 290
    args_hash['annual_gas_cost'] = 23
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 83.1, 'HotWater_gpd' => 1.65, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_270_rated_kwh
    args_hash = {}
    args_hash['num_settings'] = 12
    args_hash['rated_annual_energy'] = 270
    args_hash['annual_gas_cost'] = 22
    args_hash['test_date'] = 2013
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 73.5, 'HotWater_gpd' => 1.60, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_255_rated_kwh
    args_hash = {}
    args_hash['num_settings'] = 12
    args_hash['rated_annual_energy'] = 255
    args_hash['annual_gas_cost'] = 21
    args_hash['test_date'] = 2013
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 71.6, 'HotWater_gpd' => 1.47, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_220_rated_kwh
    args_hash = {}
    args_hash['num_settings'] = 12
    args_hash['rated_annual_energy'] = 220
    args_hash['annual_gas_cost'] = 19
    args_hash['test_date'] = 2013
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 70.6, 'HotWater_gpd' => 1.14, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_199_rated_kwh
    args_hash = {}
    args_hash['num_settings'] = 12
    args_hash['rated_annual_energy'] = 199
    args_hash['annual_gas_cost'] = 18
    args_hash['test_date'] = 2017
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 68.8, 'HotWater_gpd' => 0.96, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_144_rated_kwh
    args_hash = {}
    args_hash['num_settings'] = 12
    args_hash['rated_annual_energy'] = 144
    args_hash['annual_gas_cost'] = 13
    args_hash['test_date'] = 2017
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 49.6, 'HotWater_gpd' => 0.70, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_318_rated_kwh_mult_0_80
    args_hash = {}
    args_hash['num_settings'] = 8
    args_hash['rated_annual_energy'] = 318
    args_hash['annual_gas_cost'] = 24
    args_hash['mult_e'] = 0.8
    args_hash['mult_hw'] = 0.8
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 88.8, 'HotWater_gpd' => 2.48, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_318_rated_kwh_cold_inlet
    args_hash = {}
    args_hash['num_settings'] = 8
    args_hash['rated_annual_energy'] = 318
    args_hash['annual_gas_cost'] = 24
    args_hash['cold_inlet'] = 'true'
    args_hash['cold_use'] = 3.5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 303.8, 'HotWater_gpd' => 5.0, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_318_rated_kwh_cold_inlet_tankless
    args_hash = {}
    args_hash['num_settings'] = 8
    args_hash['rated_annual_energy'] = 318
    args_hash['annual_gas_cost'] = 24
    args_hash['cold_inlet'] = 'true'
    args_hash['cold_use'] = 3.5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 303.8, 'HotWater_gpd' => 5.0, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTankless.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_318_rated_kwh_no_int_heater
    args_hash = {}
    args_hash['num_settings'] = 8
    args_hash['rated_annual_energy'] = 318
    args_hash['annual_gas_cost'] = 24
    args_hash['has_internal_heater'] = 'false'
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 124.8, 'HotWater_gpd' => 2.41, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_basement
    args_hash = {}
    args_hash['num_settings'] = 8
    args_hash['rated_annual_energy'] = 318
    args_hash['annual_gas_cost'] = 24
    args_hash['location'] = Constants.SpaceTypeFinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 111, 'HotWater_gpd' => 3.10, 'Location' => args_hash['location'] }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_retrofit_replace
    args_hash = {}
    args_hash['num_settings'] = 8
    args_hash['rated_annual_energy'] = 318
    args_hash['annual_gas_cost'] = 24
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 111, 'HotWater_gpd' => 3.10, 'Location' => args_hash['location'] }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['num_settings'] = 12
    args_hash['rated_annual_energy'] = 290
    args_hash['annual_gas_cost'] = 23
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 83.1, 'HotWater_gpd' => 1.65, 'Location' => args_hash['location'] }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_remove
    args_hash = {}
    args_hash['num_settings'] = 8
    args_hash['rated_annual_energy'] = 318
    args_hash['annual_gas_cost'] = 24
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 111, 'HotWater_gpd' => 3.10, 'Location' => args_hash['location'] }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['mult_e'] = 0.0
    args_hash['mult_hw'] = 0.0
    expected_num_del_objects = { 'ElectricEquipmentDefinition' => 1, 'ElectricEquipment' => 1, 'WaterUseEquipmentDefinition' => 1, 'WaterUseEquipment' => 1, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'HotWater_gpd' => 0, 'Location' => args_hash['location'] }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_argument_error_num_settings_negative
    args_hash = {}
    args_hash['num_settings'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Number of place settings must be greater than or equal to 1.')
  end

  def test_argument_error_num_settings_zero
    args_hash = {}
    args_hash['num_settings'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Number of place settings must be greater than or equal to 1.')
  end

  def test_argument_error_rated_annual_energy_negative
    args_hash = {}
    args_hash['rated_annual_energy'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Rated annual energy consumption must be greater than or equal to 0.')
  end

  def test_argument_error_cold_use_negative
    args_hash = {}
    args_hash['cold_use'] = -1.0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Cold water connection use must be greater than or equal to 0.')
  end

  def test_argument_error_test_date_negative
    args_hash = {}
    args_hash['test_date'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy Guide date must be greater than or equal to 1900.')
  end

  def test_argument_error_test_date_zero
    args_hash = {}
    args_hash['test_date'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy Guide date must be greater than or equal to 1900.')
  end

  def test_argument_error_annual_gas_cost_negative
    args_hash = {}
    args_hash['annual_gas_cost'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy Guide annual gas cost must be greater than 0.')
  end

  def test_argument_error_annual_gas_cost_zero
    args_hash = {}
    args_hash['annual_gas_cost'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Energy Guide annual gas cost must be greater than 0.')
  end

  def test_argument_error_mult_e_negative
    args_hash = {}
    args_hash['mult_e'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Occupancy energy multiplier must be greater than or equal to 0.')
  end

  def test_argument_error_mult_hw_negative
    args_hash = {}
    args_hash['mult_hw'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Occupancy hot water multiplier must be greater than or equal to 0.')
  end

  def test_error_missing_geometry
    args_hash = {}
    result = _test_error(nil, args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'No building geometry has been defined.')
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
    expected_values = { 'Annual_kwh' => num_units * 83.09, 'HotWater_gpd' => num_units * 1.65, 'Location' => args_hash['location'] }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_single_family_attached_new_construction_finished_basement
    num_units = 1
    args_hash = {}
    args_hash['location'] = Constants.SpaceTypeFinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleConstant' => num_units, 'ScheduleFile' => 2, 'WaterUseEquipment' => num_units, 'WaterUseEquipmentDefinition' => num_units }
    expected_values = { 'Annual_kwh' => num_units * 83.09, 'HotWater_gpd' => num_units * 1.65, 'Location' => args_hash['location'] }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_single_family_attached_new_construction_unfinished_basement
    num_units = 1
    args_hash = {}
    args_hash['location'] = Constants.SpaceTypeUnfinishedBasement
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleConstant' => num_units, 'ScheduleFile' => 2, 'WaterUseEquipment' => num_units, 'WaterUseEquipmentDefinition' => num_units }
    expected_values = { 'Annual_kwh' => num_units * 83.09, 'HotWater_gpd' => num_units * 1.65, 'Location' => args_hash['location'] }
    _test_measure('SFA_4units_1story_UB_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_multifamily_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ElectricEquipment' => num_units, 'ElectricEquipmentDefinition' => num_units, 'ScheduleConstant' => num_units, 'ScheduleFile' => 2, 'WaterUseEquipment' => num_units, 'WaterUseEquipmentDefinition' => num_units }
    expected_values = { 'Annual_kwh' => num_units * 83.09, 'HotWater_gpd' => num_units * 1.65, 'Location' => args_hash['location'] }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ResidentialDishwasher.new

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
    measure = ResidentialDishwasher.new

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
    obj_type_exclusions = ['WaterUseConnections', 'Node', 'ScheduleTypeLimits', 'ScheduleDay', 'ScheduleRule']
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
    assert_in_epsilon(expected_values['Annual_kwh'], actual_values['Annual_kwh'], 0.01)
    assert_in_epsilon(expected_values['HotWater_gpd'], actual_values['HotWater_gpd'], 0.01)
    if not expected_values['Location'].nil?
      assert_equal(1, actual_values['Location'].uniq.size)
      assert_equal(expected_values['Location'], actual_values['Location'][0])
    end

    return model
  end
end
