# frozen_string_literal: true

require 'openstudio'

require_relative '../measure.rb'
require_relative '../../../resources/hpxml-measures/HPXMLtoOpenStudio/resources/minitest_helper'
require_relative '../../../resources/hpxml-measures/HPXMLtoOpenStudio/measure'

class ApplyUpgradeTest < MiniTest::Test
  def test_SFD_1story_FB_UA_GRG_MSHP_FuelTanklessWH
    # Retain the heat pump capacities since you aren't upgrading the heat pump
    args_hash = {}
    expected_capacities = {
      'heating_system_heating_capacity' => nil,
      'heating_system_heating_capacity_2' => nil,
      'cooling_system_cooling_capacity' => nil,
      'heat_pump_heating_capacity' => 60000.0,
      'heat_pump_cooling_capacity' => 60000.0,
      'heat_pump_backup_heating_capacity' => 100000.0,
    }
    _test_retaining_capacities('SFD_1story_FB_UA_GRG_MSHP_FuelTanklessWH.xml', args_hash, expected_capacities)

    # Don't retain the heat pump capacities because you are upgrading the heat pump
    args_hash['heat_pump_type'] = 'air-to-air'
    expected_capacities['heat_pump_heating_capacity'] = nil
    expected_capacities['heat_pump_cooling_capacity'] = nil
    expected_capacities['heat_pump_backup_heating_capacity'] = nil
    _test_retaining_capacities('SFD_1story_FB_UA_GRG_MSHP_FuelTanklessWH.xml', args_hash, expected_capacities)

    # Don't retain the heat pump capacities, but inputs are ignored anyway
    args_hash = {}
    args_hash['heating_system_type'] = 'Furnace'
    args_hash['heat_pump_type'] = 'none'
    _test_retaining_capacities('SFD_1story_FB_UA_GRG_MSHP_FuelTanklessWH.xml', args_hash, expected_capacities)
  end

  def test_SFD_1story_UB_UA_GRG_ACV_FuelFurnace_PortableHeater_HPWH
    # Retain the heating system, second heating system, cooling system capacities since you aren't upgrading them
    args_hash = {}
    expected_capacities = {
      'heating_system_heating_capacity' => 100000.0,
      'heating_system_heating_capacity_2' => 20000.0,
      'cooling_system_cooling_capacity' => 60000.0,
      'heat_pump_heating_capacity' => nil,
      'heat_pump_cooling_capacity' => nil,
      'heat_pump_backup_heating_capacity' => nil,
    }
    _test_retaining_capacities('SFD_1story_UB_UA_GRG_ACV_FuelFurnace_PortableHeater_HPWH.xml', args_hash, expected_capacities)

    # Don't retain the heating system capacity because you are upgrading the heating system
    args_hash['heating_system_type'] = 'Furnace'
    expected_capacities['heating_system_heating_capacity'] = nil
    _test_retaining_capacities('SFD_1story_UB_UA_GRG_ACV_FuelFurnace_PortableHeater_HPWH.xml', args_hash, expected_capacities)

    # Don't retain the second heating system capacity because you are upgrading the second heating system
    args_hash['heating_system_type_2'] = 'Fireplace'
    expected_capacities['heating_system_heating_capacity_2'] = nil
    _test_retaining_capacities('SFD_1story_UB_UA_GRG_ACV_FuelFurnace_PortableHeater_HPWH.xml', args_hash, expected_capacities)

    # Don't retain the cooling system capacity because you are upgrading the cooling system
    args_hash['cooling_system_type'] = 'room air conditioner'
    expected_capacities['cooling_system_cooling_capacity'] = nil
    _test_retaining_capacities('SFD_1story_UB_UA_GRG_ACV_FuelFurnace_PortableHeater_HPWH.xml', args_hash, expected_capacities)

    # Don't retain the heating system, second heating system, cooling system capacities, but inputs are ignored anyway
    args_hash['heat_pump_type'] = 'mini-split'
    args_hash['heating_system_type'] = 'none'
    args_hash['heating_system_type_2'] = 'none'
    args_hash['cooling_system_type'] = 'none'
    _test_retaining_capacities('SFD_1story_UB_UA_GRG_ACV_FuelFurnace_PortableHeater_HPWH.xml', args_hash, expected_capacities)
  end

  private

  def _test_retaining_capacities(hpxml_file, args_hash, expected_capacities)
    this_dir = File.dirname(__FILE__)
    hpxml_path = File.absolute_path("#{this_dir}/#{hpxml_file}")

    puts "\nTesting #{File.basename(hpxml_path)} with #{args_hash}..."

    hpxml = HPXML.new(hpxml_path: hpxml_path)

    # create an instance of the measure
    measure = ApplyUpgrade.new

    system_upgrades = measure.get_system_upgrades([], args_hash)
    actual_capacities = measure.get_system_capacities(hpxml, system_upgrades)

    expected_capacities.each do |str, val|
      if val.nil?
        assert_nil(actual_capacities[str])
      else
        assert_equal(val, actual_capacities[str])
      end
    end
  end
end
