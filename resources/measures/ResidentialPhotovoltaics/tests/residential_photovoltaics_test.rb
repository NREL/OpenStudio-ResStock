# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ResidentialPhotovoltaicsTest < MiniTest::Test
  def test_error_missing_weather
    args_hash = {}
    result = _test_error(nil, args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Model has not been assigned a weather file.')
  end

  def test_error_invalid_azimuth
    args_hash = {}
    args_hash['azimuth'] = -180
    result = _test_error('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash)
    assert_includes(result.errors.map { |x| x.logMessage }, 'Invalid azimuth entered.')
  end

  def test_faces_north_azimuth_back_roof
    args_hash = {}
    args_hash['azimuth'] = 180.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 180, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_North.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_west_azimuth_back_roof
    args_hash = {}
    args_hash['azimuth'] = 180.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 90, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_West.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_east_azimuth_back_roof
    args_hash = {}
    args_hash['azimuth'] = 180.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 270, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_East.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_south_azimuth_back_roof
    args_hash = {}
    args_hash['azimuth'] = 180.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 0, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_north_azimuth_absolute_west
    args_hash = {}
    args_hash['azimuth_type'] = Constants.CoordAbsolute
    args_hash['azimuth'] = 90.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 270, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_North.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_west_azimuth_absolute_west
    args_hash = {}
    args_hash['azimuth_type'] = Constants.CoordAbsolute
    args_hash['azimuth'] = 90.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 270, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_West.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_east_azimuth_absolute_west
    args_hash = {}
    args_hash['azimuth_type'] = Constants.CoordAbsolute
    args_hash['azimuth'] = 90.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 270, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_East.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_south_azimuth_absolute_west
    args_hash = {}
    args_hash['azimuth_type'] = Constants.CoordAbsolute
    args_hash['azimuth'] = 90.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 270, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_north_azimuth_absolute_southwest
    args_hash = {}
    args_hash['azimuth_type'] = Constants.CoordAbsolute
    args_hash['azimuth'] = 45.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 225, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_North.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_west_azimuth_absolute_southwest
    args_hash = {}
    args_hash['azimuth_type'] = Constants.CoordAbsolute
    args_hash['azimuth'] = 45.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 225, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_West.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_east_azimuth_absolute_southwest
    args_hash = {}
    args_hash['azimuth_type'] = Constants.CoordAbsolute
    args_hash['azimuth'] = 45.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 225, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_East.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_south_azimuth_absolute_southwest
    args_hash = {}
    args_hash['azimuth_type'] = Constants.CoordAbsolute
    args_hash['azimuth'] = 45.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 225, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_north_tilt_absolute_zero
    args_hash = {}
    args_hash['tilt_type'] = Constants.CoordAbsolute
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 0, 'AzimuthAngle' => 180, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_North.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_west_tilt_absolute_zero
    args_hash = {}
    args_hash['tilt_type'] = Constants.CoordAbsolute
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 0, 'AzimuthAngle' => 90, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_West.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_east_tilt_absolute_zero
    args_hash = {}
    args_hash['tilt_type'] = Constants.CoordAbsolute
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 0, 'AzimuthAngle' => 270, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_East.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_south_tilt_absolute_zero
    args_hash = {}
    args_hash['tilt_type'] = Constants.CoordAbsolute
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 0, 'AzimuthAngle' => 0, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_north_tilt_absolute_thirty
    args_hash = {}
    args_hash['tilt_type'] = Constants.CoordAbsolute
    args_hash['tilt'] = 30.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 30, 'AzimuthAngle' => 180, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_North.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_west_tilt_absolute_thirty
    args_hash = {}
    args_hash['tilt_type'] = Constants.CoordAbsolute
    args_hash['tilt'] = 30.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 30, 'AzimuthAngle' => 90, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_West.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_east_tilt_absolute_thirty
    args_hash = {}
    args_hash['tilt_type'] = Constants.CoordAbsolute
    args_hash['tilt'] = 30.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 30, 'AzimuthAngle' => 270, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_East.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_south_tilt_absolute_thirty
    args_hash = {}
    args_hash['tilt_type'] = Constants.CoordAbsolute
    args_hash['tilt'] = 30.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 30, 'AzimuthAngle' => 0, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_north_tilt_latitude_minus_15_deg
    args_hash = {}
    args_hash['tilt_type'] = Constants.TiltLatitude
    args_hash['tilt'] = -15.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 39.7 - 15, 'AzimuthAngle' => 180, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_North.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_west_tilt_latitude_minus_15_deg
    args_hash = {}
    args_hash['tilt_type'] = Constants.TiltLatitude
    args_hash['tilt'] = -15.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 39.7 - 15, 'AzimuthAngle' => 90, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_West.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_east_tilt_latitude_minus_15_deg
    args_hash = {}
    args_hash['tilt_type'] = Constants.TiltLatitude
    args_hash['tilt'] = -15.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 39.7 - 15, 'AzimuthAngle' => 270, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_East.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_south_tilt_latitude_minus_15_deg
    args_hash = {}
    args_hash['tilt_type'] = Constants.TiltLatitude
    args_hash['tilt'] = -15.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 39.7 - 15, 'AzimuthAngle' => 0, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_north_tilt_latitude_plus_15_deg
    args_hash = {}
    args_hash['tilt_type'] = Constants.TiltLatitude
    args_hash['tilt'] = 15.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 39.7 + 15, 'AzimuthAngle' => 180, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_North.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_west_tilt_latitude_plus_15_deg
    args_hash = {}
    args_hash['tilt_type'] = Constants.TiltLatitude
    args_hash['tilt'] = 15.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 39.7 + 15, 'AzimuthAngle' => 90, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_West.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_east_tilt_latitude_plus_15_deg
    args_hash = {}
    args_hash['tilt_type'] = Constants.TiltLatitude
    args_hash['tilt'] = 15.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 39.7 + 15, 'AzimuthAngle' => 270, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_East.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_south_tilt_latitude_plus_15_deg
    args_hash = {}
    args_hash['tilt_type'] = Constants.TiltLatitude
    args_hash['tilt'] = 15.0
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 39.7 + 15, 'AzimuthAngle' => 0, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_north_tilt_pitch_roof
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 180, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_North.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_west_tilt_pitch_roof
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 90, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_West.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_east_tilt_pitch_roof
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 270, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver_East.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_south_tilt_pitch_roof
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 0, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_south_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 0, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('SFA_4units_1story_FB_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_south_multifamily_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 0, 'AzimuthAngle' => 0, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_faces_south_retrofit_size
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 2500, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 0, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    model = _test_measure('SFD_2000sqft_2story_SL_UA_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash['size'] = 5.0
    expected_num_del_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_num_new_objects = { 'GeneratorPVWatts' => 1, 'ElectricLoadCenterInverterPVWatts' => 1, 'ElectricLoadCenterDistribution' => 1 }
    expected_values = { 'SystemCapacity' => 5000, 'ModuleType' => Constants.PVModuleTypeStandard, 'TiltAngle' => 26.57, 'AzimuthAngle' => 0, 'InverterEfficiency' => 0.96, 'ArrayType' => Constants.PVArrayTypeFixedRoofMount }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  private

  def _test_error(osm_file_or_model, args_hash)
    # create an instance of the measure
    measure = ResidentialPhotovoltaics.new

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

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_infos = 0, num_warnings = 0, debug = false)
    # create an instance of the measure
    measure = ResidentialPhotovoltaics.new

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

    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert_equal(num_infos, result.info.size)
    assert_equal(num_warnings, result.warnings.size)

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = ['ModelObjectList']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        if obj_type == 'GeneratorPVWatts'
          assert_in_epsilon(expected_values['SystemCapacity'], new_object.dcSystemCapacity, 0.01)
          assert_equal(expected_values['ModuleType'], new_object.moduleType)
          assert_in_epsilon(expected_values['TiltAngle'], new_object.tiltAngle, 0.01)
          assert_in_epsilon(expected_values['AzimuthAngle'], new_object.azimuthAngle, 0.01)
          assert_equal(expected_values['ArrayType'], new_object.arrayType)
        elsif obj_type == 'ElectricLoadCenterInverterPVWatts'
          assert_in_epsilon(expected_values['InverterEfficiency'], new_object.inverterEfficiency, 0.01)
        end
      end
    end

    return model
  end
end
