require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessConstructionsPierBeamTest < MiniTest::Test
  def test_uninsulated_and_insulate
    args_hash = {}
    args_hash['cavity_r'] = 0
    args_hash['joist_height_in'] = 9.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 6, 'Construction' => 4, 'FoundationKiva' => 1, 'FoundationKivaSettings' => 1, 'SurfacePropertyExposedFoundationPerimeter' => 1 }
    ceiling_ins_r = 0.23495 / 2.598173704068639
    ceiling_plywood_r = 0.01905 / 0.1154577
    ceiling_mass_r = 0.015875 / 0.1154577
    ceiling_carpet_r = 0.0127 / 0.0433443509615385
    ceiling_r = ceiling_ins_r + ceiling_plywood_r + ceiling_mass_r + ceiling_carpet_r
    expected_values = { 'CeilingRValue' => ceiling_r }
    _test_measure('SFD_2000sqft_2story_PB_UA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_r13_gr3
    args_hash = {}
    args_hash['cavity_r'] = 13
    args_hash['install_grade'] = '3'
    args_hash['framing_factor'] = 0.13
    args_hash['joist_height_in'] = 9.25
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 6, 'Construction' => 4, 'FoundationKiva' => 1, 'FoundationKivaSettings' => 1, 'SurfacePropertyExposedFoundationPerimeter' => 1 }
    ceiling_ins_r = 0.23495 / 0.1168615354327202
    ceiling_plywood_r = 0.01905 / 0.1154577
    ceiling_mass_r = 0.015875 / 0.1154577
    ceiling_carpet_r = 0.0127 / 0.0433443509615385
    ceiling_r = ceiling_ins_r + ceiling_plywood_r + ceiling_mass_r + ceiling_carpet_r
    expected_values = { 'CeilingRValue' => ceiling_r }
    _test_measure('SFD_2000sqft_2story_PB_UA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_argument_error_cavity_r_negative
    args_hash = {}
    args_hash['cavity_r'] = -1
    result = _test_error('SFD_2000sqft_2story_PB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Ceiling Cavity Insulation Nominal R-value must be greater than or equal to 0.')
  end

  def test_argument_error_framing_factor_negative
    args_hash = {}
    args_hash['framing_factor'] = -1
    result = _test_error('SFD_2000sqft_2story_PB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Ceiling Framing Factor must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_framing_factor_eq_1
    args_hash = {}
    args_hash['framing_factor'] = 1.0
    result = _test_error('SFD_2000sqft_2story_PB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Ceiling Framing Factor must be greater than or equal to 0 and less than 1.')
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ProcessConstructionsPierBeam.new

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

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    # create an instance of the measure
    measure = ProcessConstructionsPierBeam.new

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

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = []
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    actual_values = { 'CeilingRValue' => 0 }
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        next unless obj_type == 'Construction'
        next unless new_object.name.to_s.start_with?(Constants.SurfaceTypeFloorPBInsFin) && (not new_object.name.to_s.include? 'Reversed')

        new_object.to_LayeredConstruction.get.layers.each do |layer|
          mat = layer.to_StandardOpaqueMaterial.get
          actual_values['CeilingRValue'] += mat.thickness / mat.conductivity
        end
      end
    end

    assert_in_epsilon(expected_values['CeilingRValue'], actual_values['CeilingRValue'], 0.03)

    return model
  end
end
