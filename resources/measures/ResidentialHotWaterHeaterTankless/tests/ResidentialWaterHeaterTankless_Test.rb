require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ResidentialHotWaterHeaterTanklessTest < MiniTest::Test
  def test_new_construction_standard_gas
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.754, 'Setpoint' => 125, 'OnCycle' => 7.38, 'OffCycle' => 7.38, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_elec
    args_hash = {}
    expected_num_del_objects = {}
    args_hash['fuel_type'] = Constants.FuelTypeElectric
    args_hash['energy_factor'] = 0.99
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.911, 'Setpoint' => 125, 'OnCycle' => 0, 'OffCycle' => 0, 'FuelType' => Constants.FuelTypeElectric }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_propane
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypePropane
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.754, 'Setpoint' => 125, 'OnCycle' => 7.38, 'OffCycle' => 7.38, 'FuelType' => Constants.FuelTypePropane }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_living_gas
    args_hash = {}
    args_hash['location'] = Constants.SpaceTypeLiving
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.754, 'Setpoint' => 125, 'OnCycle' => 7.38, 'OffCycle' => 7.38, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_setpoint_130_gas
    args_hash = {}
    args_hash['setpoint_temp'] = 130
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.754, 'Setpoint' => 130, 'OnCycle' => 7.38, 'OffCycle' => 7.38, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_new_construction_standard_cd_0_gas
    args_hash = {}
    args_hash['cycling_derate'] = 0
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.82, 'Setpoint' => 125, 'OnCycle' => 7.38, 'OffCycle' => 7.38, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'PlantLoop' => 1, 'PumpVariableSpeed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.754, 'Setpoint' => 125, 'OnCycle' => 7.38, 'OffCycle' => 7.38, 'FuelType' => Constants.FuelTypeGas }
    model = _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
    args_hash = {}
    args_hash['energy_factor'] = 0.96
    args_hash['setpoint_temp'] = 130
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.883, 'Setpoint' => 130, 'OnCycle' => 7.38, 'OffCycle' => 7.38, 'FuelType' => Constants.FuelTypeGas }
    _test_measure(model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_tank_with_tankless_gas
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.754, 'Setpoint' => 125, 'OnCycle' => 7.38, 'OffCycle' => 7.38, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_tank_scheduled_sp_with_tankless_gas
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = { 'WaterHeaterStratified' => 1, 'ScheduleFixedInterval' => 2 }
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.754, 'Setpoint' => 125, 'OnCycle' => 7.38, 'OffCycle' => 7.38, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_Stratified_WHTank_scheduled_SP.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_hpwh_with_tankless_gas
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = { 'WaterHeaterStratified' => 1, 'ScheduleConstant' => 6, 'CoilWaterHeatingAirToWaterHeatPumpWrapped' => 1, 'FanOnOff' => 1, 'WaterHeaterHeatPumpWrappedCondenser' => 1, 'OtherEquipment' => 2, 'OtherEquipmentDefinition' => 2, 'EnergyManagementSystemProgramCallingManager' => 1, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemActuator' => 7, 'EnergyManagementSystemSensor' => 10, 'EnergyManagementSystemTrendVariable' => 3 }
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.754, 'Setpoint' => 125, 'OnCycle' => 7.38, 'OffCycle' => 7.38, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_HPWH.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_hpwh_scheduled_sp_with_tankless_gas
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    expected_num_del_objects = { 'WaterHeaterStratified' => 1, 'ScheduleFixedInterval' => 3, 'ScheduleConstant' => 4, 'WaterHeaterHeatPumpWrappedCondenser' => 1, 'CoilWaterHeatingAirToWaterHeatPumpWrapped' => 1, 'FanOnOff' => 1, 'OtherEquipment' => 2, 'OtherEquipmentDefinition' => 2, 'EnergyManagementSystemSensor' => 10, 'EnergyManagementSystemActuator' => 7, 'EnergyManagementSystemTrendVariable' => 3, 'EnergyManagementSystemProgram' => 2, 'EnergyManagementSystemProgramCallingManager' => 1 }
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.754, 'Setpoint' => 125, 'OnCycle' => 7.38, 'OffCycle' => 7.38, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_HPWH_scheduled_SP.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_retrofit_replace_tank_electric_shw_with_tankless_gas
    args_hash = {}
    args_hash['fuel_type'] = Constants.FuelTypeGas
    args_hash['setpoint_temp'] = '130'
    expected_num_del_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_num_new_objects = { 'WaterHeaterMixed' => 1, 'ScheduleConstant' => 2 }
    expected_values = { 'InputCapacity' => 29307107, 'ThermalEfficiency' => 0.754, 'Setpoint' => args_hash['setpoint_temp'].to_f, 'OnCycle' => 7.38, 'OffCycle' => 7.38, 'FuelType' => Constants.FuelTypeGas, 'StorageTankSetpoint1' => args_hash['setpoint_temp'].to_f, 'StorageTankSetpoint2' => args_hash['setpoint_temp'].to_f }
    _test_measure('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver_WHTank_SHW.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, 1)
  end

  def test_argument_error_setpoint_lt_0
    args_hash = {}
    args_hash['setpoint_temp'] = -10
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Water heater temperature setpoint must not be less than 0F or greater than 212F.')
  end

  def test_argument_error_setpoint_lg_300
    args_hash = {}
    args_hash['setpoint_temp'] = 300
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Water heater temperature setpoint must not be less than 0F or greater than 212F.')
  end

  def test_argument_error_capacity_lt_0
    args_hash = {}
    args_hash['capacity'] = -10
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Nominal capacity must be greater than 0.')
  end

  def test_argument_error_capacity_eq_0
    args_hash = {}
    args_hash['capacity'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Nominal capacity must be greater than 0.')
  end

  def test_argument_error_ef_lt_0
    args_hash = {}
    args_hash['energy_factor'] = -10
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Rated energy factor must be greater than 0 and less than or equal to 1.')
  end

  def test_argument_error_ef_eq_0
    args_hash = {}
    args_hash['energy_factor'] = 0
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Rated energy factor must be greater than 0 and less than or equal to 1.')
  end

  def test_argument_error_ef_gt_1
    args_hash = {}
    args_hash['energy_factor'] = 1.1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Rated energy factor must be greater than 0 and less than or equal to 1.')
  end

  def test_argument_error_cd_lt_0
    args_hash = {}
    args_hash['cycling_derate'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Cycling derate must be at least 0 and at most 1.')
  end

  def test_argument_error_cd_gt_1
    args_hash = {}
    args_hash['cycling_derate'] = 1.1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Cycling derate must be at least 0 and at most 1.')
  end

  def test_argument_error_oncycle_lt_0
    args_hash = {}
    args_hash['oncyc_power'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Forced draft fan power must be greater than 0.')
  end

  def test_argument_error_offcycle_lt_0
    args_hash = {}
    args_hash['offcyc_power'] = -1
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Parasitic electricity power must be greater than 0.')
  end

  def test_error_missing_geometry
    args_hash = {}
    result = _test_error(nil, args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'No building geometry has been defined.')
  end

  def test_error_missing_mains_temp
    args_hash = {}
    result = _test_error('SFD_2000sqft_2story_FB_GRG_UA_3Beds_2Baths.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Mains water temperature has not been set.')
  end

  def test_single_family_attached_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => num_units, 'PlantLoop' => num_units, 'PumpVariableSpeed' => num_units, 'ScheduleConstant' => 2 * num_units }
    expected_values = { 'InputCapacity' => num_units * 29307107, 'ThermalEfficiency' => num_units * 0.754, 'Setpoint' => num_units * 125, 'OnCycle' => num_units * 7.38, 'OffCycle' => num_units * 7.38, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units)
  end

  def test_single_family_attached_new_construction_living_zone
    num_units = 1
    args_hash = {}
    args_hash['location'] = Constants.SpaceTypeLiving
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => num_units, 'PlantLoop' => num_units, 'PumpVariableSpeed' => num_units, 'ScheduleConstant' => 2 * num_units }
    expected_values = { 'InputCapacity' => num_units * 29307107, 'ThermalEfficiency' => num_units * 0.754, 'Setpoint' => num_units * 125, 'OnCycle' => num_units * 7.38, 'OffCycle' => num_units * 7.38, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('SFA_4units_1story_FB_UA_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units)
  end

  def test_multifamily_new_construction
    num_units = 1
    args_hash = {}
    expected_num_del_objects = {}
    expected_num_new_objects = { 'WaterHeaterMixed' => num_units, 'PlantLoop' => num_units, 'PumpVariableSpeed' => num_units, 'ScheduleConstant' => 2 * num_units }
    expected_values = { 'InputCapacity' => num_units * 29307107, 'ThermalEfficiency' => num_units * 0.754, 'Setpoint' => num_units * 125, 'OnCycle' => num_units * 7.38, 'OffCycle' => num_units * 7.38, 'FuelType' => Constants.FuelTypeGas }
    _test_measure('MF_8units_1story_SL_3Beds_2Baths_Denver.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, num_units)
  end

  private

  def _test_error(osm_file, args_hash)
    # create an instance of the measure
    measure = ResidentialHotWaterHeaterTankless.new

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
    measure = ResidentialHotWaterHeaterTankless.new

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
    obj_type_exclusions = ['ConnectorMixer', 'ConnectorSplitter', 'Node', 'SetpointManagerScheduled', 'ScheduleDay', 'PipeAdiabatic', 'ScheduleTypeLimits', 'SizingPlant', 'AvailabilityManagerAssignmentList']
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    actual_values = { 'TankVolume' => 0, 'InputCapacity' => 0, 'ThermalEfficiency' => 0, 'TankUA1' => 0, 'TankUA2' => 0, 'Setpoint' => 0, 'OnCycle' => 0, 'OffCycle' => 0, 'SkinLossFrac' => 0, 'StorageTankSetpoint1' => 0, 'StorageTankSetpoint2' => 0 }
    num_new_whs = 0
    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
        next unless (obj_type == 'WaterHeaterMixed') || (obj_type == 'WaterHeaterStratified')

        actual_values['TankVolume'] += UnitConversions.convert(new_object.tankVolume.get, 'm^3', 'gal')
        actual_values['InputCapacity'] += UnitConversions.convert(new_object.heaterMaximumCapacity.get, 'W', 'kW')
        actual_values['ThermalEfficiency'] += new_object.heaterThermalEfficiency.get
        actual_values['TankUA1'] += UnitConversions.convert(new_object.onCycleLossCoefficienttoAmbientTemperature.get, 'W/K', 'Btu/(hr*F)')
        actual_values['TankUA2'] += UnitConversions.convert(new_object.offCycleLossCoefficienttoAmbientTemperature.get, 'W/K', 'Btu/(hr*F)')
        actual_values['Setpoint'] += Waterheater.get_water_heater_setpoint(model, new_object.plantLoop.get, nil)
        actual_values['OnCycle'] += new_object.onCycleParasiticFuelConsumptionRate
        actual_values['OffCycle'] += new_object.offCycleParasiticFuelConsumptionRate
        assert_equal(HelperMethods.eplus_fuel_map(expected_values['FuelType']), new_object.heaterFuelType)
        actual_values['SkinLossFrac'] += new_object.offCycleLossFractiontoThermalZone
        if new_object.supplyInletModelObject.is_initialized
          inlet_object = new_object.supplyInletModelObject.get.connectedObject(new_object.supplyInletModelObject.get.to_Node.get.inletPort).get
          if inlet_object.to_WaterHeaterStratified.is_initialized
            storage_tank = inlet_object.to_WaterHeaterStratified.get
            setpoint_schedule_one = storage_tank.heater1SetpointTemperatureSchedule.to_ScheduleConstant.get
            setpoint_schedule_two = storage_tank.heater2SetpointTemperatureSchedule.to_ScheduleConstant.get
            actual_values['StorageTankSetpoint1'] += UnitConversions.convert(setpoint_schedule_one.value - new_object.deadbandTemperatureDifference / 2.0, 'C', 'F')
            actual_values['StorageTankSetpoint2'] += UnitConversions.convert(setpoint_schedule_two.value - new_object.deadbandTemperatureDifference / 2.0, 'C', 'F')
          end
        end
        num_new_whs += 1
      end
    end
    assert_in_epsilon(num_new_whs.to_f * Waterheater.calc_actual_tankvol(nil, args_hash['fuel_type'], Constants.WaterHeaterTypeTankless), actual_values['TankVolume'], 0.01)
    assert_in_epsilon(expected_values['InputCapacity'], actual_values['InputCapacity'], 0.01)
    assert_in_epsilon(expected_values['ThermalEfficiency'], actual_values['ThermalEfficiency'], 0.01)
    assert_in_epsilon(0, actual_values['TankUA1'], 0.01)
    assert_in_epsilon(0, actual_values['TankUA2'], 0.01)
    if not expected_values['Setpoint'].nil?
      assert_in_epsilon(expected_values['Setpoint'], actual_values['Setpoint'], 0.01)
    end
    assert_in_epsilon(expected_values['OnCycle'], actual_values['OnCycle'], 0.01)
    assert_in_epsilon(expected_values['OffCycle'], actual_values['OffCycle'], 0.01)
    assert_in_epsilon(num_new_whs.to_f, actual_values['SkinLossFrac'], 0.01)
    if (not expected_values['StorageTankSetpoint1'].nil?) && (not expected_values['StorageTankSetpoint2'].nil?)
      assert_in_epsilon(expected_values['StorageTankSetpoint1'], actual_values['StorageTankSetpoint1'], 0.01)
      assert_in_epsilon(expected_values['StorageTankSetpoint2'], actual_values['StorageTankSetpoint2'], 0.01)
    end

    return model
  end
end
