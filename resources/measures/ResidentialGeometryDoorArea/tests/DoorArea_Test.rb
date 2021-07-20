# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class DoorAreaTest < MiniTest::Test
  def test_no_door_area
    args_hash = {}
    args_hash['door_area'] = 0
    expected_values = { 'Constructions' => 0 }
    result = _test_measure('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash, 0, 0, 0, expected_values)
  end

  def test_sfd_new_construction_rotated
    args_hash = {}
    expected_values = { 'Constructions' => 0 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_Southwest.osm', args_hash, 0, 20, 0, expected_values)
  end

  def test_sfd_retrofit_replace
    args_hash = {}
    expected_values = { 'Constructions' => 0 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash, 0, 20, 0, expected_values)
    args_hash = {}
    args_hash['door_area'] = 30
    expected_values = { 'Constructions' => 0 }
    _test_measure(model, args_hash, 20, 30, 0, expected_values)
  end

  def test_argument_error_invalid_door_area
    args_hash = {}
    args_hash['door_area'] = -20
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Invalid door area.')
  end

  def test_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    expected_values = { 'Constructions' => 0 }
    _test_measure('SFA_4units_1story_FB_UA_Denver.osm', args_hash, 0, 20 * num_units, 0, expected_values)
  end

  def test_multifamily_new_construction_interior_corridor
    num_units = 1
    args_hash = {}
    expected_values = { 'Constructions' => 0 }
    _test_measure('MF_8units_1story_SL_Denver.osm', args_hash, 0, 0, 20 * num_units, expected_values)
  end

  def test_multifamily_new_construction_exterior_corridor
    num_units = 1
    args_hash = {}
    expected_values = { 'Constructions' => 0 }
    _test_measure('MF_8units_1story_SL_Denver_ExteriorCorridor.osm', args_hash, 0, 20 * num_units, 0, expected_values)
  end

  def test_sfd_retrofit_replace_one_construction
    args_hash = {}
    args_hash['door_area'] = 30
    expected_values = { 'Constructions' => 1 }
    _test_measure('SFD_2000sqft_2story_SL_GRG_UA_Doors_OneConstruction.osm', args_hash, 20, 30, 0, expected_values)
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = CreateResidentialDoorArea.new

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

    # assert that it didn't run
    assert_equal('Fail', result.value.valueName)
    assert(result.errors.size == 1)

    return result
  end

  def _test_measure(osm_file_or_model, args_hash, expected_door_area_removed, expected_exterior_door_area_added, expected_corridor_door_area_added, expected_values)
    # create an instance of the measure
    measure = CreateResidentialDoorArea.new

    # check for standard methods
    assert(!measure.name.empty?)
    assert(!measure.description.empty?)
    assert(!measure.modeler_description.empty?)

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    model = get_model(File.dirname(__FILE__), osm_file_or_model)

    # store the original doors in the model
    orig_doors = []
    model.getSubSurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType.downcase != 'door'

      orig_doors << sub_surface
    end

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
    assert(result.finalCondition.is_initialized)

    # get new/deleted door objects
    new_objects = []
    model.getSubSurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType.downcase != 'door'
      next if orig_doors.include?(sub_surface)

      new_objects << sub_surface
    end
    del_objects = []
    orig_doors.each do |orig_door|
      has_door = false
      model.getSubSurfaces.each do |sub_surface|
        next if sub_surface != orig_door

        has_door = true
      end
      next if has_door

      del_objects << orig_door
    end

    new_exterior_door_area = 0
    new_corridor_door_area = 0
    new_objects.each do |door|
      if door.surface.get.outsideBoundaryCondition.downcase == 'adiabatic'
        new_corridor_door_area += UnitConversions.convert(door.grossArea, 'm^2', 'ft^2')
      else
        new_exterior_door_area += UnitConversions.convert(door.grossArea, 'm^2', 'ft^2')
      end
    end

    del_door_area = 0
    del_objects.each do |door|
      del_door_area += UnitConversions.convert(door.grossArea, 'm^2', 'ft^2')
    end

    assert_in_epsilon(expected_exterior_door_area_added, new_exterior_door_area, 0.01)
    assert_in_epsilon(expected_corridor_door_area_added, new_corridor_door_area, 0.01)
    assert_in_epsilon(expected_door_area_removed, del_door_area, 0.01)

    model.getSurfaces.each do |surface|
      assert(surface.netArea > 0)
    end

    actual_values = { 'Constructions' => 0 }
    constructions = []
    model.getSubSurfaces.each do |sub_surface|
      next unless sub_surface.construction.is_initialized

      if not constructions.include? sub_surface.construction.get
        constructions << sub_surface.construction.get
        actual_values['Constructions'] += 1
      end
    end
    assert_equal(expected_values['Constructions'], actual_values['Constructions'])

    return model
  end
end
