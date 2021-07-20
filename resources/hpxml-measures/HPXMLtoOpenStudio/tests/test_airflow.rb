# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'
require_relative 'util.rb'

class HPXMLtoOpenStudioAirflowTest < MiniTest::Test
  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def get_eed_for_ventilation(model, ee_name)
    eeds = []
    model.getElectricEquipmentDefinitions.each do |eed|
      next if eed.name.to_s.include? 'cfis'
      next unless eed.name.to_s.include? ee_name

      eeds << eed
    end
    return eeds
  end

  def get_oed_for_ventilation(model, oe_name)
    oeds = []
    model.getOtherEquipmentDefinitions.each do |oed|
      next unless oed.name.to_s.include? oe_name

      oeds << oed
    end
    return oeds
  end

  def test_infiltration_ach50
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(0.0436, program_values['c'].sum, 0.01)
    assert_in_epsilon(0.0573, program_values['Cs'].sum, 0.01)
    assert_in_epsilon(0.1446, program_values['Cw'].sum, 0.01)
  end

  def test_infiltration_ach_house_pressure
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-enclosure-infil-ach-house-pressure.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(0.0436, program_values['c'].sum, 0.01)
    assert_in_epsilon(0.0573, program_values['Cs'].sum, 0.01)
    assert_in_epsilon(0.1446, program_values['Cw'].sum, 0.01)
  end

  def test_infiltration_ach50_flue
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-enclosure-infil-flue.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(0.0436, program_values['c'].sum, 0.01)
    assert_in_epsilon(0.0661, program_values['Cs'].sum, 0.01)
    assert_in_epsilon(0.1323, program_values['Cw'].sum, 0.01)
  end

  def test_infiltration_cfm50
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-enclosure-infil-cfm50.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(0.0436, program_values['c'].sum, 0.01)
    assert_in_epsilon(0.0573, program_values['Cs'].sum, 0.01)
    assert_in_epsilon(0.1446, program_values['Cw'].sum, 0.01)
  end

  def test_infiltration_cfm_house_pressure
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-enclosure-infil-cfm-house-pressure.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(0.0436, program_values['c'].sum, 0.01)
    assert_in_epsilon(0.0573, program_values['Cs'].sum, 0.01)
    assert_in_epsilon(0.1446, program_values['Cw'].sum, 0.01)
  end

  def test_infiltration_natural_ach
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-enclosure-infil-natural-ach.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(0.0904, program_values['c'].sum, 0.01)
    assert_in_epsilon(0.0573, program_values['Cs'].sum, 0.01)
    assert_in_epsilon(0.1446, program_values['Cw'].sum, 0.01)
  end

  def test_natural_ventilation
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check natural ventilation/whole house fan program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameNaturalVentilation} program")
    assert_in_epsilon(14.5, UnitConversions.convert(program_values['NVArea'].sum, 'cm^2', 'ft^2'), 0.01)
    assert_in_epsilon(0.000109, program_values['Cs'].sum, 0.01)
    assert_in_epsilon(0.000068, program_values['Cw'].sum, 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['WHF_Flow'].sum, 'm^3/s', 'cfm'), 0.01)
  end

  def test_mechanical_ventilation_none
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_sup'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_exh'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_bal_erv_hrv'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_equal(1, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan).size)
    assert_in_epsilon(0.0, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].designLevel.get, 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qrange'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qbath'].sum, 'm^3/s', 'cfm'), 0.01)
    # Load actuators
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} sensible load").size)
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} latent load").size)
  end

  def test_mechanical_ventilation_supply
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-mechvent-supply.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    vent_fan = hpxml.ventilation_fans.select { |f| f.used_for_whole_building_ventilation }[0]
    vent_fan_cfm = vent_fan.average_total_unit_flow_rate
    vent_fan_power = vent_fan.fan_power

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(vent_fan_cfm, UnitConversions.convert(program_values['QWHV_sup'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_exh'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_bal_erv_hrv'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_equal(1, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan).size)
    assert_in_epsilon(vent_fan_power, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].designLevel.get, 0.01)
    assert_in_epsilon(0.0, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].fractionLost, 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qrange'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qbath'].sum, 'm^3/s', 'cfm'), 0.01)
    # Load actuators
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} sensible load").size)
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} latent load").size)
  end

  def test_mechanical_ventilation_exhaust
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-mechvent-exhaust.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    vent_fan = hpxml.ventilation_fans.select { |f| f.used_for_whole_building_ventilation }[0]
    vent_fan_cfm = vent_fan.average_total_unit_flow_rate
    vent_fan_power = vent_fan.fan_power

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(vent_fan_cfm, UnitConversions.convert(program_values['QWHV_exh'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_sup'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_bal_erv_hrv'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_equal(1, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan).size)
    assert_in_epsilon(vent_fan_power, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].designLevel.get, 0.01)
    assert_in_epsilon(1.0, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].fractionLost, 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qrange'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qbath'].sum, 'm^3/s', 'cfm'), 0.01)
    # Load actuators
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} sensible load").size)
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} latent load").size)
  end

  def test_mechanical_ventilation_balanced
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-mechvent-balanced.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    vent_fan = hpxml.ventilation_fans.select { |f| f.used_for_whole_building_ventilation }[0]
    vent_fan_cfm = vent_fan.average_total_unit_flow_rate
    vent_fan_power = vent_fan.fan_power

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(vent_fan_cfm, UnitConversions.convert(program_values['QWHV_bal_erv_hrv'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_sup'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_exh'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_equal(1, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan).size)
    assert_in_epsilon(vent_fan_power, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].designLevel.get, 0.01)
    assert_in_epsilon(0.5, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].fractionLost, 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qrange'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qbath'].sum, 'm^3/s', 'cfm'), 0.01)
    # Load actuators
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} sensible load").size)
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} latent load").size)
  end

  def test_mechanical_ventilation_erv
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-mechvent-erv.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    vent_fan = hpxml.ventilation_fans.select { |f| f.used_for_whole_building_ventilation }[0]
    vent_fan_cfm = vent_fan.average_total_unit_flow_rate
    vent_fan_power = vent_fan.fan_power

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(vent_fan_cfm, UnitConversions.convert(program_values['QWHV_bal_erv_hrv'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_sup'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_exh'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_equal(1, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan).size)
    assert_in_epsilon(vent_fan_power, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].designLevel.get, 0.01)
    assert_in_epsilon(0.5, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].fractionLost, 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qrange'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qbath'].sum, 'm^3/s', 'cfm'), 0.01)
    # Load actuators
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} sensible load").size)
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} latent load").size)
  end

  def test_mechanical_ventilation_hrv
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-mechvent-hrv.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    vent_fan = hpxml.ventilation_fans.select { |f| f.used_for_whole_building_ventilation }[0]
    vent_fan_cfm = vent_fan.average_total_unit_flow_rate
    vent_fan_power = vent_fan.fan_power

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(vent_fan_cfm, UnitConversions.convert(program_values['QWHV_bal_erv_hrv'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_sup'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_exh'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_equal(1, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan).size)
    assert_in_epsilon(vent_fan_power, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].designLevel.get, 0.01)
    assert_in_epsilon(0.5, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].fractionLost, 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qrange'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qbath'].sum, 'm^3/s', 'cfm'), 0.01)
    # Load actuators
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} sensible load").size)
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} latent load").size)
  end

  def test_mechanical_ventilation_cfis
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-mechvent-cfis.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    vent_fan = hpxml.ventilation_fans.select { |f| f.used_for_whole_building_ventilation }[0]
    vent_fan_cfm = vent_fan.oa_unit_flow_rate
    vent_fan_power = vent_fan.fan_power
    vent_fan_mins = vent_fan.hours_in_operation / 24.0 * 60.0

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(vent_fan_cfm, UnitConversions.convert(program_values['CFIS_Q_duct_oa'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_bal_erv_hrv'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_sup'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_exh'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(vent_fan_power, program_values['CFIS_fan_w'].sum, 0.01)
    assert_in_epsilon(vent_fan_mins, program_values['CFIS_t_min_hr_open'].sum, 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qrange'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['Qbath'].sum, 'm^3/s', 'cfm'), 0.01)
    # Load actuators
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} sensible load").size)
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} latent load").size)
  end

  def test_ventilation_bath_kitchen_fans
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-mechvent-bath-kitchen-fans.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    bath_fan = hpxml.ventilation_fans.select { |f| f.used_for_local_ventilation && f.fan_location == HPXML::LocationBath }[0]
    bath_fan_cfm = bath_fan.rated_flow_rate * bath_fan.quantity
    bath_fan_power = bath_fan.fan_power * bath_fan.quantity
    kitchen_fan = hpxml.ventilation_fans.select { |f| f.used_for_local_ventilation && f.fan_location == HPXML::LocationKitchen }[0]
    kitchen_fan_cfm = kitchen_fan.rated_flow_rate * (kitchen_fan.quantity.nil? ? 1 : kitchen_fan.quantity)
    kitchen_fan_power = kitchen_fan.fan_power * (kitchen_fan.quantity.nil? ? 1 : kitchen_fan.quantity)

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_sup'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_exh'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0.0, UnitConversions.convert(program_values['QWHV_bal_erv_hrv'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_equal(1, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan).size)
    assert_in_epsilon(0.0, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].designLevel.get, 0.01)
    assert_in_epsilon(kitchen_fan_cfm, UnitConversions.convert(program_values['Qrange'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_equal(1, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationRangeFan).size)
    assert_in_epsilon(kitchen_fan_power, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationRangeFan)[0].designLevel.get, 0.01)
    assert_in_epsilon(1.0, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationRangeFan)[0].fractionLost, 0.01)
    assert_in_epsilon(bath_fan_cfm, UnitConversions.convert(program_values['Qbath'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_equal(1, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationBathFan).size)
    assert_in_epsilon(bath_fan_power, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationBathFan)[0].designLevel.get, 0.01)
    assert_in_epsilon(1.0, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationBathFan)[0].fractionLost, 0.01)
    # Load actuators
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} sensible load").size)
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} latent load").size)
  end

  def test_clothes_dryer_exhaust
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    clothes_dryer = hpxml.clothes_dryers[0]
    clothes_dryer_cfm = clothes_dryer.vented_flow_rate

    # Check infiltration/ventilation program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(clothes_dryer_cfm, UnitConversions.convert(program_values['Qdryer'].sum, 'm^3/s', 'cfm'), 0.01)
  end

  def test_multiple_mechvent
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-mechvent-multiple.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    bath_fans = hpxml.ventilation_fans.select { |f| f.used_for_local_ventilation && f.fan_location == HPXML::LocationBath }
    bath_fan_cfm = bath_fans.map { |bath_fan| bath_fan.rated_flow_rate * bath_fan.quantity }.sum(0.0)
    bath_fan_power = bath_fans.map { |bath_fan| bath_fan.fan_power * bath_fan.quantity }.sum(0.0)
    kitchen_fans = hpxml.ventilation_fans.select { |f| f.used_for_local_ventilation && f.fan_location == HPXML::LocationKitchen }
    kitchen_fan_cfm = kitchen_fans.map { |kitchen_fan| kitchen_fan.rated_flow_rate }.sum(0.0)
    kitchen_fan_power = kitchen_fans.map { |kitchen_fan| kitchen_fan.fan_power }.sum(0.0)

    # Get HPXML values
    vent_fan_sup = hpxml.ventilation_fans.select { |f| f.used_for_whole_building_ventilation && (f.fan_type == HPXML::MechVentTypeSupply) }
    vent_fan_cfm_sup = vent_fan_sup.map { |f| f.average_total_unit_flow_rate }.sum(0.0)
    vent_fan_power_sup = vent_fan_sup.map { |f| f.average_unit_fan_power }.sum(0.0)
    vent_fan_exh = hpxml.ventilation_fans.select { |f| f.used_for_whole_building_ventilation && (f.fan_type == HPXML::MechVentTypeExhaust) }
    vent_fan_cfm_exh = vent_fan_exh.map { |f| f.average_total_unit_flow_rate }.sum(0.0)
    vent_fan_power_exh = vent_fan_exh.map { |f| f.average_unit_fan_power }.sum(0.0)
    vent_fan_bal = hpxml.ventilation_fans.select { |f| f.used_for_whole_building_ventilation && (f.fan_type == HPXML::MechVentTypeBalanced) }
    vent_fan_cfm_bal = vent_fan_bal.map { |f| f.average_total_unit_flow_rate }.sum(0.0)
    vent_fan_power_bal = vent_fan_bal.map { |f| f.average_unit_fan_power }.sum(0.0)
    vent_fan_ervhrv = hpxml.ventilation_fans.select { |f| f.used_for_whole_building_ventilation && [HPXML::MechVentTypeERV, HPXML::MechVentTypeHRV].include?(f.fan_type) }
    vent_fan_cfm_ervhrv = vent_fan_ervhrv.map { |f| f.average_total_unit_flow_rate }.sum(0.0)
    vent_fan_power_ervhrv = vent_fan_ervhrv.map { |f| f.average_unit_fan_power }.sum(0.0)
    vent_fan_cfis = hpxml.ventilation_fans.select { |f| f.used_for_whole_building_ventilation && (f.fan_type == HPXML::MechVentTypeCFIS) }
    vent_fan_cfm_cfis = vent_fan_cfis.map { |f| f.oa_unit_flow_rate }.sum(0.0)
    vent_fan_power_cfis = vent_fan_cfis.map { |f| f.fan_power }.sum(0.0)
    vent_fan_mins_cfis = vent_fan_cfis.map { |f| f.hours_in_operation / 24.0 * 60.0 }.sum(0.0)
    # total mech vent fan power excluding cfis
    total_mechvent_pow = vent_fan_power_sup + vent_fan_power_exh + vent_fan_power_bal + vent_fan_power_ervhrv
    fraction_heat_gain = (1.0 * vent_fan_power_sup + 0.0 * vent_fan_power_sup + 0.5 * (vent_fan_power_bal + vent_fan_power_ervhrv)) / total_mechvent_pow
    fraction_heat_lost = 1.0 - fraction_heat_gain

    # Check infiltration/ventilation program
    # CFMs
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon(vent_fan_cfm_bal + vent_fan_cfm_ervhrv, UnitConversions.convert(program_values['QWHV_bal_erv_hrv'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(vent_fan_cfm_sup, UnitConversions.convert(program_values['QWHV_sup'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(vent_fan_cfm_exh, UnitConversions.convert(program_values['QWHV_exh'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(kitchen_fan_cfm, UnitConversions.convert(program_values['Qrange'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(bath_fan_cfm, UnitConversions.convert(program_values['Qbath'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(vent_fan_cfm_cfis, UnitConversions.convert(program_values['CFIS_Q_duct_oa'].sum, 'm^3/s', 'cfm'), 0.01)
    # Fan power/load implementation
    assert_equal(1, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan).size)
    assert_in_epsilon(total_mechvent_pow, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].designLevel.get, 0.01)
    assert_in_epsilon(fraction_heat_lost, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan)[0].fractionLost, 0.01)
    assert_in_epsilon(vent_fan_power_cfis, program_values['CFIS_fan_w'].sum, 0.01)
    range_fan_eeds = get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationRangeFan)
    assert_equal(2, range_fan_eeds.size)
    assert_in_epsilon(bath_fan_power, range_fan_eeds.map { |f| f.designLevel.get }.sum(0.0), 0.01)
    assert_in_epsilon(1.0, range_fan_eeds[0].fractionLost, 0.01)
    assert_in_epsilon(1.0, range_fan_eeds[1].fractionLost, 0.01)
    bath_fan_eeds = get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationBathFan)
    assert_equal(2, bath_fan_eeds.size)
    assert_in_epsilon(bath_fan_power, bath_fan_eeds.map { |f| f.designLevel.get }.sum(0.0), 0.01)
    assert_in_epsilon(1.0, bath_fan_eeds[0].fractionLost, 0.01)
    assert_in_epsilon(1.0, bath_fan_eeds[1].fractionLost, 0.01)
    # CFIS minutes
    assert_in_epsilon(vent_fan_mins_cfis, program_values['CFIS_t_min_hr_open'].sum, 0.01)
    # Load actuators
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} sensible load").size)
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} latent load").size)
  end

  def test_shared_mechvent_multiple
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-bldgtype-multifamily-shared-mechvent-multiple.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    vent_fans_preheat = hpxml.ventilation_fans.select { |f| (not f.preheating_fuel.nil?) }
    vent_fans_precool = hpxml.ventilation_fans.select { |f| (not f.precooling_fuel.nil?) }
    vent_fans_tot_pow_noncfis = hpxml.ventilation_fans.select { |f| f.fan_type != HPXML::MechVentTypeCFIS }.map { |f| f.average_unit_fan_power }.sum(0.0)
    # total cfms
    vent_fans_cfm_tot_sup = hpxml.ventilation_fans.select { |f| f.fan_type == HPXML::MechVentTypeSupply }.map { |f| f.average_total_unit_flow_rate }.sum(0.0)
    vent_fans_cfm_tot_exh = hpxml.ventilation_fans.select { |f| f.fan_type == HPXML::MechVentTypeExhaust }.map { |f| f.average_total_unit_flow_rate }.sum(0.0)
    vent_fans_cfm_tot_ervhrvbal = hpxml.ventilation_fans.select { |f| [HPXML::MechVentTypeERV, HPXML::MechVentTypeHRV, HPXML::MechVentTypeBalanced].include? f.fan_type }.map { |f| f.average_total_unit_flow_rate }.sum(0.0)
    # preconditioned mech vent oa cfms
    vent_fans_cfm_oa_preheat_sup = vent_fans_preheat.select { |f| f.fan_type == HPXML::MechVentTypeSupply }.map { |f| f.average_oa_unit_flow_rate }.sum(0.0)
    vent_fans_cfm_oa_precool_sup = vent_fans_precool.select { |f| f.fan_type == HPXML::MechVentTypeSupply }.map { |f| f.average_oa_unit_flow_rate }.sum(0.0)
    vent_fans_cfm_oa_preheat_bal = vent_fans_preheat.select { |f| f.fan_type == HPXML::MechVentTypeBalanced }.map { |f| f.average_oa_unit_flow_rate }.sum(0.0)
    vent_fans_cfm_oa_precool_bal = vent_fans_precool.select { |f| f.fan_type == HPXML::MechVentTypeBalanced }.map { |f| f.average_oa_unit_flow_rate }.sum(0.0)
    vent_fans_cfm_oa_preheat_ervhrv = vent_fans_preheat.select { |f| [HPXML::MechVentTypeERV, HPXML::MechVentTypeHRV].include? f.fan_type }.map { |f| f.average_oa_unit_flow_rate }.sum(0.0)
    vent_fans_cfm_oa_precool_ervhrv = vent_fans_precool.select { |f| [HPXML::MechVentTypeERV, HPXML::MechVentTypeHRV].include? f.fan_type }.map { |f| f.average_oa_unit_flow_rate }.sum(0.0)
    # CFIS
    vent_fans_cfm_oa_cfis = hpxml.ventilation_fans.select { |f| f.fan_type == HPXML::MechVentTypeCFIS }.map { |f| f.oa_unit_flow_rate }.sum(0.0)
    vent_fans_pow_cfis = hpxml.ventilation_fans.select { |f| f.fan_type == HPXML::MechVentTypeCFIS }.map { |f| f.unit_fan_power }.sum(0.0)
    vent_fans_mins_cfis = hpxml.ventilation_fans.select { |f| f.fan_type == HPXML::MechVentTypeCFIS }.map { |f| f.hours_in_operation / 24.0 * 60.0 }.sum(0.0)

    # Load and energy eed
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} sensible load").size)
    assert_equal(1, get_oed_for_ventilation(model, "#{Constants.ObjectNameMechanicalVentilationHouseFan} latent load").size)
    assert_equal(vent_fans_precool.size, get_oed_for_ventilation(model, 'shared mech vent precooling energy').size)
    assert_equal(vent_fans_preheat.size, get_oed_for_ventilation(model, 'shared mech vent preheating energy').size)

    # Fan power implementation
    assert_equal(1, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan).size)
    assert_in_epsilon(vent_fans_tot_pow_noncfis, get_eed_for_ventilation(model, Constants.ObjectNameMechanicalVentilationHouseFan).map { |eed| eed.designLevel.get }.sum, 0.01)

    # Check preconditioning program
    program_values = get_ems_values(model.getEnergyManagementSystemPrograms, "#{Constants.ObjectNameInfiltration} program")
    assert_in_epsilon((vent_fans_cfm_oa_preheat_sup + vent_fans_cfm_oa_preheat_bal + vent_fans_cfm_oa_preheat_ervhrv), UnitConversions.convert(program_values['Qpreheat'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon((vent_fans_cfm_oa_precool_sup + vent_fans_cfm_oa_precool_bal + vent_fans_cfm_oa_precool_ervhrv), UnitConversions.convert(program_values['Qprecool'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(vent_fans_pow_cfis, program_values['CFIS_fan_w'].sum, 0.01)
    assert_in_epsilon(vent_fans_mins_cfis, program_values['CFIS_t_min_hr_open'].sum, 0.01)
    assert_in_epsilon(vent_fans_cfm_oa_cfis, UnitConversions.convert(program_values['CFIS_Q_duct_oa'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(vent_fans_cfm_tot_ervhrvbal, UnitConversions.convert(program_values['QWHV_bal_erv_hrv'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(vent_fans_cfm_tot_sup, UnitConversions.convert(program_values['QWHV_sup'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(vent_fans_cfm_tot_exh, UnitConversions.convert(program_values['QWHV_exh'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0, UnitConversions.convert(program_values['Qrange'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(0, UnitConversions.convert(program_values['Qbath'].sum, 'm^3/s', 'cfm'), 0.01)
  end

  def test_ducts_leakage_cfm25
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    supply_leakage = hpxml.hvac_distributions[0].duct_leakage_measurements.select { |m| m.duct_type == HPXML::DuctTypeSupply }[0]
    return_leakage = hpxml.hvac_distributions[0].duct_leakage_measurements.select { |m| m.duct_type == HPXML::DuctTypeReturn }[0]
    supply_leakage_cfm25 = supply_leakage.duct_leakage_value
    return_leakage_cfm25 = return_leakage.duct_leakage_value

    # Check ducts program
    program_values = get_ems_values(model.getEnergyManagementSystemSubroutines, 'duct subroutine')
    assert_in_epsilon(supply_leakage_cfm25, UnitConversions.convert(program_values['f_sup'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(return_leakage_cfm25, UnitConversions.convert(program_values['f_ret'].sum, 'm^3/s', 'cfm'), 0.01)
    assert_in_epsilon(33.4, UnitConversions.convert(program_values['supply_ua'].sum, 'W/K', 'Btu/(hr*F)'), 0.01)
    assert_in_epsilon(29.4, UnitConversions.convert(program_values['return_ua'].sum, 'W/K', 'Btu/(hr*F)'), 0.01)
  end

  def test_ducts_leakage_percent
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-hvac-ducts-leakage-percent.xml'))
    model, hpxml = _test_measure(args_hash)

    # Get HPXML values
    supply_leakage = hpxml.hvac_distributions[0].duct_leakage_measurements.select { |m| m.duct_type == HPXML::DuctTypeSupply }[0]
    return_leakage = hpxml.hvac_distributions[0].duct_leakage_measurements.select { |m| m.duct_type == HPXML::DuctTypeReturn }[0]
    supply_leakage_frac = supply_leakage.duct_leakage_value
    return_leakage_frac = return_leakage.duct_leakage_value

    # Check ducts program
    program_values = get_ems_values(model.getEnergyManagementSystemSubroutines, 'duct subroutine')
    assert_in_epsilon(supply_leakage_frac, program_values['f_sup'].sum, 0.01)
    assert_in_epsilon(return_leakage_frac, program_values['f_ret'].sum, 0.01)
    assert_in_epsilon(33.4, UnitConversions.convert(program_values['supply_ua'].sum, 'W/K', 'Btu/(hr*F)'), 0.01)
    assert_in_epsilon(29.4, UnitConversions.convert(program_values['return_ua'].sum, 'W/K', 'Btu/(hr*F)'), 0.01)
  end

  def test_infiltration_compartmentalization_area
    # Base
    hpxml = HPXML.new(hpxml_path: File.absolute_path(File.join(sample_files_dir, 'base.xml')))
    total_area, exterior_area = hpxml.compartmentalization_boundary_areas
    assert_in_delta(5216, exterior_area, 1.0)
    assert_in_delta(5216, total_area, 1.0)

    # Test adjacent garage
    hpxml = HPXML.new(hpxml_path: File.absolute_path(File.join(sample_files_dir, 'base-enclosure-garage.xml')))
    total_area, exterior_area = hpxml.compartmentalization_boundary_areas
    assert_in_delta(4976, exterior_area, 1.0)
    assert_in_delta(5216, total_area, 1.0)

    # Test unvented attic/crawlspace within infiltration volume
    hpxml = HPXML.new(hpxml_path: File.absolute_path(File.join(sample_files_dir, 'base-foundation-unvented-crawlspace.xml')))
    hpxml.attics.each do |attic|
      attic.within_infiltration_volume = true
    end
    hpxml.foundations.each do |foundation|
      foundation.within_infiltration_volume = true
    end
    total_area, exterior_area = hpxml.compartmentalization_boundary_areas
    assert_in_delta(5066, exterior_area, 1.0)
    assert_in_delta(5066, total_area, 1.0)

    # Test unvented attic/crawlspace not within infiltration volume
    hpxml = HPXML.new(hpxml_path: File.absolute_path(File.join(sample_files_dir, 'base-foundation-unvented-crawlspace.xml')))
    hpxml.attics.each do |attic|
      attic.within_infiltration_volume = false
    end
    hpxml.foundations.each do |foundation|
      foundation.within_infiltration_volume = false
    end
    total_area, exterior_area = hpxml.compartmentalization_boundary_areas
    assert_in_delta(3900, exterior_area, 1.0)
    assert_in_delta(3900, total_area, 1.0)

    # Test multifamily
    hpxml = HPXML.new(hpxml_path: File.absolute_path(File.join(sample_files_dir, 'base-bldgtype-multifamily.xml')))
    total_area, exterior_area = hpxml.compartmentalization_boundary_areas
    assert_in_delta(686, exterior_area, 1.0)
    assert_in_delta(2780, total_area, 1.0)
  end

  def test_infiltration_assumed_height
    # Base
    hpxml = HPXML.new(hpxml_path: File.absolute_path(File.join(sample_files_dir, 'base.xml')))
    infil_volume = hpxml.air_infiltration_measurements.select { |m| !m.infiltration_volume.nil? }[0].infiltration_volume
    infil_height = hpxml.inferred_infiltration_height(infil_volume)
    assert_equal(9.75, infil_height)

    # Test w/o conditioned basement
    hpxml = HPXML.new(hpxml_path: File.absolute_path(File.join(sample_files_dir, 'base-foundation-unconditioned-basement.xml')))
    infil_volume = hpxml.air_infiltration_measurements.select { |m| !m.infiltration_volume.nil? }[0].infiltration_volume
    infil_height = hpxml.inferred_infiltration_height(infil_volume)
    assert_equal(8, infil_height)

    # Test w/ walkout basement
    hpxml = HPXML.new(hpxml_path: File.absolute_path(File.join(sample_files_dir, 'base-foundation-walkout-basement.xml')))
    infil_volume = hpxml.air_infiltration_measurements.select { |m| !m.infiltration_volume.nil? }[0].infiltration_volume
    infil_height = hpxml.inferred_infiltration_height(infil_volume)
    assert_equal(16, infil_height)

    # Test 2 story building
    hpxml = HPXML.new(hpxml_path: File.absolute_path(File.join(sample_files_dir, 'base-enclosure-2stories.xml')))
    infil_volume = hpxml.air_infiltration_measurements.select { |m| !m.infiltration_volume.nil? }[0].infiltration_volume
    infil_height = hpxml.inferred_infiltration_height(infil_volume)
    assert_equal(17.75, infil_height)

    # Test w/ cathedral ceiling
    hpxml = HPXML.new(hpxml_path: File.absolute_path(File.join(sample_files_dir, 'base-atticroof-cathedral.xml')))
    infil_volume = hpxml.air_infiltration_measurements.select { |m| !m.infiltration_volume.nil? }[0].infiltration_volume
    infil_height = hpxml.inferred_infiltration_height(infil_volume)
    assert_equal(13.75, infil_height)
  end

  def _test_measure(args_hash)
    # create an instance of the measure
    measure = HPXMLtoOpenStudio.new

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    model = OpenStudio::Model::Model.new

    # get arguments
    args_hash['output_dir'] = 'tests'
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

    hpxml = HPXML.new(hpxml_path: args_hash['hpxml_path'])

    File.delete(File.join(File.dirname(__FILE__), 'in.xml'))

    return model, hpxml
  end
end
