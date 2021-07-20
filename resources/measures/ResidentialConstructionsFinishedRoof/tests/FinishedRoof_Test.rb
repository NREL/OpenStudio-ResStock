require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessConstructionsFinishedRoofTest < MiniTest::Test
  def test_uninsulated_2x6
    args_hash = {}
    args_hash['cavity_r'] = 0
    args_hash['install_grade'] = '3' # no insulation, shouldn't apply
    args_hash['cavity_depth'] = 5.5
    args_hash['filled_cavity'] = false # no insulation, shouldn't apply
    args_hash['framing_factor'] = 0.07
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 4, 'Construction' => 1 }
    roofing_r = 0.0094488 / 0.162714
    osb_r = 0.01905 / 0.1154577
    ins_r = 0.1397 / 0.6819557830565512
    drywall_r = 0.0127 / 0.1602906
    assembly_r = roofing_r + osb_r + ins_r + drywall_r
    expected_values = { 'AssemblyR' => assembly_r, 'ThermalAbsorptance' => 0.91, 'SolarAbsorptance' => 0.85, 'VisibleAbsorptance' => 0.85 }
    _test_measure('SFD_2000sqft_2story_SL_FA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_uninsulated_2x6_gr3
    args_hash = {}
    args_hash['cavity_r'] = 0
    args_hash['install_grade'] = '3' # no insulation, shouldn't apply
    args_hash['cavity_depth'] = 5.5
    args_hash['filled_cavity'] = true # no insulation, shouldn't apply
    args_hash['framing_factor'] = 0.07
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 4, 'Construction' => 1 }
    roofing_r = 0.0094488 / 0.162714
    osb_r = 0.01905 / 0.1154577
    ins_r = 0.1397 / 0.6819557830565512
    drywall_r = 0.0127 / 0.1602906
    assembly_r = roofing_r + osb_r + ins_r + drywall_r
    expected_values = { 'AssemblyR' => assembly_r, 'ThermalAbsorptance' => 0.91, 'SolarAbsorptance' => 0.85, 'VisibleAbsorptance' => 0.85 }
    _test_measure('SFD_2000sqft_2story_SL_FA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_r19_2x6_gr1
    args_hash = {}
    args_hash['cavity_r'] = 17.3 # compressed R-value
    args_hash['install_grade'] = '1'
    args_hash['cavity_depth'] = 5.5
    args_hash['filled_cavity'] = true
    args_hash['framing_factor'] = 0.07
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 4, 'Construction' => 1 }
    roofing_r = 0.0094488 / 0.162714
    osb_r = 0.01905 / 0.1154577
    ins_r = 0.1397 / 0.0499725655190589
    drywall_r = 0.0127 / 0.1602906
    assembly_r = roofing_r + osb_r + ins_r + drywall_r
    expected_values = { 'AssemblyR' => assembly_r, 'ThermalAbsorptance' => 0.91, 'SolarAbsorptance' => 0.85, 'VisibleAbsorptance' => 0.85 }
    _test_measure('SFD_2000sqft_2story_SL_FA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_r19_2x10_gr3_ff11
    args_hash = {}
    args_hash['cavity_r'] = 19
    args_hash['install_grade'] = '3'
    args_hash['cavity_depth'] = 9.25
    args_hash['filled_cavity'] = false
    args_hash['framing_factor'] = 0.11
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 4, 'Construction' => 1 }
    roofing_r = 0.0094488 / 0.162714
    osb_r = 0.01905 / 0.1154577
    ins_r = 0.23495 / 0.0902761063120803
    drywall_r = 0.0127 / 0.1602906
    assembly_r = roofing_r + osb_r + ins_r + drywall_r
    expected_values = { 'AssemblyR' => assembly_r, 'ThermalAbsorptance' => 0.91, 'SolarAbsorptance' => 0.85, 'VisibleAbsorptance' => 0.85 }
    _test_measure('SFD_2000sqft_2story_SL_FA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_single_family_attached_new_construction
    args_hash = {}
    args_hash['cavity_r'] = 0
    args_hash['install_grade'] = '3' # no insulation, shouldn't apply
    args_hash['cavity_depth'] = 5.5
    args_hash['filled_cavity'] = false # no insulation, shouldn't apply
    args_hash['framing_factor'] = 0.07
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 4, 'Construction' => 1 }
    roofing_r = 0.0094488 / 0.162714
    osb_r = 0.01905 / 0.1154577
    ins_r = 0.1397 / 0.6819557830565512
    drywall_r = 0.0127 / 0.1602906
    assembly_r = roofing_r + osb_r + ins_r + drywall_r
    expected_values = { 'AssemblyR' => assembly_r, 'ThermalAbsorptance' => 0.91, 'SolarAbsorptance' => 0.85, 'VisibleAbsorptance' => 0.85 }
    _test_measure('SFA_4units_1story_SL_FA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_multifamily_new_construction
    args_hash = {}
    args_hash['cavity_r'] = 0
    args_hash['install_grade'] = '3' # no insulation, shouldn't apply
    args_hash['cavity_depth'] = 5.5
    args_hash['filled_cavity'] = false # no insulation, shouldn't apply
    args_hash['framing_factor'] = 0.07
    expected_num_del_objects = {}
    expected_num_new_objects = { 'Material' => 5, 'Construction' => 2 }
    roofing_r = 0.0094488 / 0.162714
    osb_r = 0.01905 / 0.1154577
    ins_r = 0.1397 / 0.6819557830565512
    drywall_r = 0.0127 / 0.1602906
    assembly_r = roofing_r + osb_r + ins_r + drywall_r
    expected_values = { 'AssemblyR' => assembly_r, 'ThermalAbsorptance' => 0.91, 'SolarAbsorptance' => 0.85, 'VisibleAbsorptance' => 0.85 }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_argument_error_cavity_r_negative
    args_hash = {}
    args_hash['cavity_r'] = -1
    result = _test_error('SFD_2000sqft_2story_SL_FA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Cavity Insulation Installed R-value must be greater than or equal to 0.')
  end

  def test_argument_error_cavity_depth_negative
    args_hash = {}
    args_hash['cavity_depth'] = -1
    result = _test_error('SFD_2000sqft_2story_SL_FA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Cavity Depth must be greater than 0.')
  end

  def test_argument_error_cavity_depth_zero
    args_hash = {}
    args_hash['cavity_depth'] = 0
    result = _test_error('SFD_2000sqft_2story_SL_FA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Cavity Depth must be greater than 0.')
  end

  def test_argument_error_framing_factor_negative
    args_hash = {}
    args_hash['framing_factor'] = -1
    result = _test_error('SFD_2000sqft_2story_SL_FA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Framing Factor must be greater than or equal to 0 and less than 1.')
  end

  def test_argument_error_framing_factor_eq_1
    args_hash = {}
    args_hash['framing_factor'] = 1.0
    result = _test_error('SFD_2000sqft_2story_SL_FA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Framing Factor must be greater than or equal to 0 and less than 1.')
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ProcessConstructionsFinishedRoof.new

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
    measure = ProcessConstructionsFinishedRoof.new

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

    actual_values = { 'AssemblyR' => 0 }
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        next unless obj_type == 'Construction'
        next if not new_object.name.to_s.start_with? Constants.SurfaceTypeRoofFinInsExt

        new_object.to_LayeredConstruction.get.layers.each do |layer|
          material = layer.to_StandardOpaqueMaterial.get
          actual_values['AssemblyR'] += material.thickness / material.conductivity
        end
        next unless not new_object.name.to_s.include? 'Reversed'

        material = new_object.to_LayeredConstruction.get.layers[0].to_StandardOpaqueMaterial.get
        assert_equal(expected_values['ThermalAbsorptance'], material.thermalAbsorptance)
        assert_equal(expected_values['SolarAbsorptance'], material.solarAbsorptance)
        assert_equal(expected_values['VisibleAbsorptance'], material.visibleAbsorptance)
      end
    end
    assert_in_epsilon(expected_values['AssemblyR'], actual_values['AssemblyR'], 0.01)

    return model
  end
end
