# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'

class HPXMLtoOpenStudioMiscLoadsTest < MiniTest::Test
  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def get_kwh_therm_per_year(model, name)
    kwh_yr = 0.0
    therm_yr = 0.0
    model.getElectricEquipments.each do |ee|
      next unless ee.name.to_s.include?(name)

      hrs = Schedule.annual_equivalent_full_load_hrs(model.yearDescription.get.assumedYear, ee.schedule.get)
      kwh_yr += UnitConversions.convert(hrs * ee.designLevel.get * ee.multiplier * ee.space.get.multiplier, 'Wh', 'kWh')
    end
    model.getGasEquipments.each do |ge|
      next unless ge.name.to_s.include?(name)

      hrs = Schedule.annual_equivalent_full_load_hrs(model.yearDescription.get.assumedYear, ge.schedule.get)
      therm_yr += UnitConversions.convert(hrs * ge.definition.to_GasEquipmentDefinition.get.designLevel.get * ge.multiplier * ge.space.get.multiplier, 'Wh', 'therm')
    end
    model.getOtherEquipments.each do |oe|
      next unless oe.name.to_s.include?(name)

      hrs = Schedule.annual_equivalent_full_load_hrs(model.yearDescription.get.assumedYear, oe.schedule.get)
      therm_yr += UnitConversions.convert(hrs * oe.definition.to_OtherEquipmentDefinition.get.designLevel.get * oe.multiplier * oe.space.get.multiplier, 'Wh', 'therm')
    end
    return kwh_yr, therm_yr
  end

  def test_misc_loads
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check misc plug loads
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscPlugLoads)
    assert_in_delta(2454, kwh_yr, 1.0)
    assert_equal(0, therm_yr)

    # Check television
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscTelevision)
    assert_in_delta(619, kwh_yr, 1.0)
    assert_equal(0, therm_yr)

    # Check others
    objects = [Constants.ObjectNameMiscElectricVehicleCharging,
               Constants.ObjectNameMiscWellPump,
               Constants.ObjectNameMiscPoolPump,
               Constants.ObjectNameMiscPoolHeater,
               Constants.ObjectNameMiscHotTubPump,
               Constants.ObjectNameMiscHotTubHeater,
               Constants.ObjectNameMiscGrill,
               Constants.ObjectNameMiscLighting,
               Constants.ObjectNameMiscFireplace]
    objects.each do |object_name|
      kwh_yr, therm_yr = get_kwh_therm_per_year(model, object_name)
      assert_equal(0, kwh_yr)
      assert_equal(0, therm_yr)
    end
  end

  def test_large_uncommon_loads
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-misc-loads-large-uncommon.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check misc plug loads
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscPlugLoads)
    assert_in_delta(2454, kwh_yr, 1.0)
    assert_equal(0, therm_yr)

    # Check television
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscTelevision)
    assert_in_delta(619, kwh_yr, 1.0)
    assert_equal(0, therm_yr)

    # Check vehicle
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscElectricVehicleCharging)
    assert_in_epsilon(1500, kwh_yr, 0.1)
    assert_equal(0, therm_yr)

    # Check well pump
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscWellPump)
    assert_in_epsilon(475, kwh_yr, 0.1)
    assert_equal(0, therm_yr)

    # Check pool pump
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscPoolPump)
    assert_in_epsilon(2700, kwh_yr, 0.1)
    assert_equal(0, therm_yr)

    # Check pool heater
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscPoolHeater)
    assert_equal(0, kwh_yr)
    assert_in_epsilon(500, therm_yr, 0.1)

    # Check hot tub pump
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscHotTubPump)
    assert_in_epsilon(1000, kwh_yr, 0.1)
    assert_equal(0, therm_yr)

    # Check hot tub heater
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscHotTubHeater)
    assert_in_epsilon(1300, kwh_yr, 0.1)
    assert_equal(0, therm_yr)

    # Check grill
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscGrill)
    assert_equal(0, kwh_yr)
    assert_in_epsilon(25, therm_yr, 0.1)

    # Check lighting
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscLighting)
    assert_equal(0, kwh_yr)
    assert_in_epsilon(28, therm_yr, 0.1)

    # Check fireplace
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscFireplace)
    assert_equal(0, kwh_yr)
    assert_in_epsilon(55, therm_yr, 0.1)
  end

  def test_large_uncommon_loads2
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-misc-loads-large-uncommon2.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check misc plug loads
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscPlugLoads)
    assert_in_delta(2454, kwh_yr, 1.0)
    assert_equal(0, therm_yr)

    # Check television
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscTelevision)
    assert_in_delta(619, kwh_yr, 1.0)
    assert_equal(0, therm_yr)

    # Check vehicle
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscElectricVehicleCharging)
    assert_in_epsilon(1500, kwh_yr, 0.1)
    assert_equal(0, therm_yr)

    # Check well pump
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscWellPump)
    assert_in_epsilon(475, kwh_yr, 0.1)
    assert_equal(0, therm_yr)

    # Check pool pump
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscPoolPump)
    assert_in_epsilon(2700, kwh_yr, 0.1)
    assert_equal(0, therm_yr)

    # Check pool heater
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscPoolHeater)
    assert_equal(0, kwh_yr)
    assert_equal(0, therm_yr)

    # Check hot tub pump
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscHotTubPump)
    assert_in_epsilon(1000, kwh_yr, 0.1)
    assert_equal(0, therm_yr)

    # Check hot tub heater
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscHotTubHeater)
    assert_in_epsilon(260, kwh_yr, 0.1)
    assert_equal(0, therm_yr)

    # Check grill
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscGrill)
    assert_equal(0, kwh_yr)
    assert_in_epsilon(25, therm_yr, 0.1)

    # Check lighting
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscLighting)
    assert_equal(0, kwh_yr)
    assert_in_epsilon(28, therm_yr, 0.1)

    # Check fireplace
    kwh_yr, therm_yr = get_kwh_therm_per_year(model, Constants.ObjectNameMiscFireplace)
    assert_equal(0, kwh_yr)
    assert_in_epsilon(55, therm_yr, 0.1)
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
