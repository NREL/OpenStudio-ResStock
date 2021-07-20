# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'

class HPXMLtoOpenStudioLightingTest < MiniTest::Test
  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def get_kwh_per_year(model, name)
    model.getLightss.each do |ltg|
      next unless ltg.name.to_s == name

      hrs = Schedule.annual_equivalent_full_load_hrs(model.yearDescription.get.assumedYear, ltg.schedule.get)
      kwh_yr = UnitConversions.convert(hrs * ltg.lightingLevel.get * ltg.multiplier * ltg.space.get.multiplier, 'Wh', 'kWh')
      return kwh_yr
    end
    model.getExteriorLightss.each do |ltg|
      next unless ltg.name.to_s == name

      hrs = Schedule.annual_equivalent_full_load_hrs(model.yearDescription.get.assumedYear, ltg.schedule.get)
      kwh_yr = UnitConversions.convert(hrs * ltg.exteriorLightsDefinition.designLevel * ltg.multiplier, 'Wh', 'kWh')
      return kwh_yr
    end
    return
  end

  def test_lighting
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check interior lighting
    int_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameInteriorLighting)
    assert_in_delta(1322, int_kwh_yr, 1.0)

    # Check exterior lighting
    ext_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameExteriorLighting)
    assert_in_delta(98, ext_kwh_yr, 1.0)
  end

  def test_lighting_garage
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-enclosure-2stories-garage.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check interior lighting
    int_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameInteriorLighting)
    assert_in_delta(1544, int_kwh_yr, 1.0)

    # Check garage lighting
    grg_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameGarageLighting)
    assert_in_delta(42, grg_kwh_yr, 1.0)

    # Check exterior lighting
    ext_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameExteriorLighting)
    assert_in_delta(109, ext_kwh_yr, 1.0)
  end

  def test_exterior_holiday_lighting
    ['base.xml',
     'base-misc-defaults.xml',
     'base-lighting-detailed.xml'].each do |hpxml_name|
      args_hash = {}
      args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, hpxml_name))
      model, hpxml = _test_measure(args_hash)

      if hpxml_name == 'base-lighting-detailed.xml'
        # Check exterior holiday lighting
        ext_holiday_kwh_yr = get_kwh_per_year(model, Constants.ObjectNameLightingExteriorHoliday)
        assert_in_delta(58.3, ext_holiday_kwh_yr, 1.0)
      else
        assert_equal(false, hpxml.lighting.holiday_exists)
      end
    end
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
