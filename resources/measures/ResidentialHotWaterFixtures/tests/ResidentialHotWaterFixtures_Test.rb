require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ResidentialHotWaterFixturesTest < MiniTest::Test
  def test_new_construction_none
    # Using energy multiplier
    args_hash = {}
    args_hash['shower_mult'] = 0.0
    args_hash['sink_mult'] = 0.0
    args_hash['bath_mult'] = 0.0
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'HotWater_gpd' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_standard
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'OtherEquipmentDefinition' => 3, 'OtherEquipment' => 3, 'WaterUseEquipmentDefinition' => 3, 'WaterUseEquipment' => 3, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'EnergyManagementSystemSensor' => 3, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemOutputVariable' => 3 }
    expected_values = { 'Annual_kwh' => 445.1, 'HotWater_gpd' => 60 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_varying_mults
    args_hash = {}
    args_hash['shower_mult'] = 0.0
    args_hash['sink_mult'] = 0.5
    args_hash['bath_mult'] = 1.5
    expected_num_del_objects = {}
    expected_num_new_objects = { 'OtherEquipmentDefinition' => 2, 'OtherEquipment' => 2, 'WaterUseEquipmentDefinition' => 2, 'WaterUseEquipment' => 2, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 107.7, 'HotWater_gpd' => 23 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_new_construction_basement
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'OtherEquipmentDefinition' => 3, 'OtherEquipment' => 3, 'WaterUseEquipmentDefinition' => 3, 'WaterUseEquipment' => 3, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'EnergyManagementSystemSensor' => 3, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemOutputVariable' => 3 }
    expected_values = { 'Annual_kwh' => 445.1, 'HotWater_gpd' => 60 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
  end

  def test_retrofit_replace
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'OtherEquipmentDefinition' => 3, 'OtherEquipment' => 3, 'WaterUseEquipmentDefinition' => 3, 'WaterUseEquipment' => 3, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'EnergyManagementSystemSensor' => 3, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemOutputVariable' => 3 }
    expected_values = { 'Annual_kwh' => 445.1, 'HotWater_gpd' => 60 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['shower_mult'] = 0.0 # no new EMS objects
    args_hash['sink_mult'] = 0.5
    args_hash['bath_mult'] = 1.5
    expected_num_del_objects = { 'OtherEquipmentDefinition' => 3, 'OtherEquipment' => 3, 'WaterUseEquipmentDefinition' => 3, 'WaterUseEquipment' => 3, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'EnergyManagementSystemSensor' => 3, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemOutputVariable' => 3 }
    expected_num_new_objects = { 'OtherEquipmentDefinition' => 2, 'OtherEquipment' => 2, 'WaterUseEquipmentDefinition' => 2, 'WaterUseEquipment' => 2, 'ScheduleFile' => 2, 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 107.7, 'HotWater_gpd' => 23 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace2
    args_hash = {}
    expected_num_del_objects = { 'OtherEquipmentDefinition' => 3, 'OtherEquipment' => 3, 'WaterUseEquipmentDefinition' => 3, 'WaterUseEquipment' => 3, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'EnergyManagementSystemSensor' => 3, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemOutputVariable' => 3 }
    expected_num_new_objects = { 'OtherEquipmentDefinition' => 3, 'OtherEquipment' => 3, 'WaterUseEquipmentDefinition' => 3, 'WaterUseEquipment' => 3, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'EnergyManagementSystemSensor' => 3, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemOutputVariable' => 3 }
    expected_values = { 'Annual_kwh' => 445.1, 'HotWater_gpd' => 60 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank_HWFixtures_RecircDist.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_remove
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'OtherEquipmentDefinition' => 3, 'OtherEquipment' => 3, 'WaterUseEquipmentDefinition' => 3, 'WaterUseEquipment' => 3, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'EnergyManagementSystemSensor' => 3, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemOutputVariable' => 3 }
    expected_values = { 'Annual_kwh' => 445.1, 'HotWater_gpd' => 60 }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values)
    args_hash = {}
    args_hash['shower_mult'] = 0.0
    args_hash['sink_mult'] = 0.0
    args_hash['bath_mult'] = 0.0
    expected_num_del_objects = { 'OtherEquipmentDefinition' => 3, 'OtherEquipment' => 3, 'WaterUseEquipmentDefinition' => 3, 'WaterUseEquipment' => 3, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'EnergyManagementSystemSensor' => 3, 'EnergyManagementSystemProgram' => 1, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemOutputVariable' => 3 }
    expected_num_new_objects = {}
    expected_values = { 'Annual_kwh' => 0, 'HotWater_gpd' => 0 }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_argument_error_shower_mult_negative
    args_hash = {}
    args_hash['shower_mult'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Shower hot water usage multiplier must be greater than or equal to 0.')
  end

  def test_argument_error_sink_mult_negative
    args_hash = {}
    args_hash['sink_mult'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Sink hot water usage multiplier must be greater than or equal to 0.')
  end

  def test_argument_error_bath_mult_negative
    args_hash = {}
    args_hash['bath_mult'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Bath hot water usage multiplier must be greater than or equal to 0.')
  end

  def test_error_missing_geometry
    args_hash = {}
    result = _test_error(nil, args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'No building geometry has been defined.')
  end

  def test_warning_missing_water_heater
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'ScheduleConstant' => 1 }
    expected_values = { 'Annual_kwh' => 0, 'HotWater_gpd' => 0 }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0, 1)
  end

  def test_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'OtherEquipmentDefinition' => num_units * 3, 'OtherEquipment' => num_units * 3, 'WaterUseEquipmentDefinition' => num_units * 3, 'WaterUseEquipment' => num_units * 3, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'EnergyManagementSystemSensor' => num_units * 3, 'EnergyManagementSystemProgram' => num_units, 'EnergyManagementSystemProgramCallingManager' => num_units, 'EnergyManagementSystemOutputVariable' => num_units * 3 }
    expected_values = { 'Annual_kwh' => num_units * 445.1, 'HotWater_gpd' => num_units * 60 }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  def test_multifamily_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'OtherEquipmentDefinition' => num_units * 3, 'OtherEquipment' => num_units * 3, 'WaterUseEquipmentDefinition' => num_units * 3, 'WaterUseEquipment' => num_units * 3, 'ScheduleFile' => 3, 'ScheduleConstant' => 1, 'EnergyManagementSystemSensor' => num_units * 3, 'EnergyManagementSystemProgram' => num_units, 'EnergyManagementSystemProgramCallingManager' => num_units, 'EnergyManagementSystemOutputVariable' => num_units * 3 }
    expected_values = { 'Annual_kwh' => num_units * 445.1, 'HotWater_gpd' => num_units * 60 }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 0)
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ResidentialHotWaterFixtures.new

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
    measure = ResidentialHotWaterFixtures.new

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

    year_description = model.getYearDescription
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)

    actual_values = { 'Annual_kwh' => 0, 'HotWater_gpd' => 0 }
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        if obj_type == 'OtherEquipment'
          schedule_file = new_object.schedule.get.to_ScheduleFile.get
          schedules_file = SchedulesFile.new(runner: runner, model: model)
          full_load_hrs = schedules_file.annual_equivalent_full_load_hrs(col_name: schedule_file.name.to_s)
          actual_values['Annual_kwh'] += UnitConversions.convert(full_load_hrs * new_object.otherEquipmentDefinition.designLevel.get * new_object.multiplier, 'Wh', 'kWh')
        elsif obj_type == 'WaterUseEquipment'
          schedule_file = new_object.flowRateFractionSchedule.get.to_ScheduleFile.get
          schedules_file = SchedulesFile.new(runner: runner, model: model)
          full_load_hrs = schedules_file.annual_equivalent_full_load_hrs(col_name: schedule_file.name.to_s)
          peak_flow_rate = UnitConversions.convert(new_object.waterUseEquipmentDefinition.peakFlowRate * new_object.multiplier, 'm^3/s', 'gal/min')
          daily_gallons = (full_load_hrs * 60 * peak_flow_rate) / num_days_in_year # multiply by 60 because peak_flow_rate is in gal/min
          actual_values['HotWater_gpd'] += daily_gallons
        end
      end
    end
    assert_in_epsilon(expected_values['Annual_kwh'], actual_values['Annual_kwh'], 0.01)
    assert_in_epsilon(expected_values['HotWater_gpd'], actual_values['HotWater_gpd'], 0.01)

    model.getElectricEquipments.each do |ee|
      assert(ee.schedule.is_initialized)
    end

    return model
  end
end
