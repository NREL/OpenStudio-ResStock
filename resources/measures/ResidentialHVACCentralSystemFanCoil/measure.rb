# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require_relative '../HPXMLtoOpenStudio/resources/unit_conversions'
require_relative '../HPXMLtoOpenStudio/resources/geometry'
require_relative '../HPXMLtoOpenStudio/resources/util'
require_relative '../HPXMLtoOpenStudio/resources/hvac'

# start the measure
class ProcessCentralSystemFanCoil < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'ResidentialHVACCentralSystemFanCoil'
  end

  # human readable description
  def description
    return 'Adds either: (1) a central boiler/chiller with fan coil units to the model or (2) a central chiller with cooling-only fan coil units to the model.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Adds either: (1) hot water boiler and electric chiller with variable-speed pumps to two plant loops, along with coil heating/cooling water objects on zone hvac four pipe fan coil objects, or (2) an electric chiller with variable-speed pump to a single plant loop, along with coil cooling water objects on cooling-only zone hvac four pipe fan coil objects.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a bool argument for whether there is heating
    fan_coil_heating = OpenStudio::Measure::OSArgument::makeBoolArgument('fan_coil_heating', true)
    fan_coil_heating.setDisplayName('Fan Coil Provides Heating')
    fan_coil_heating.setDescription('When the fan coil provides heating in addition to cooling, a four pipe fan coil system is modeled.')
    fan_coil_heating.setDefaultValue(true)
    args << fan_coil_heating

    # make a string argument for central boiler fuel type
    central_boiler_fuel_type_names = OpenStudio::StringVector.new
    central_boiler_fuel_type_names << Constants.FuelTypeElectric
    central_boiler_fuel_type_names << Constants.FuelTypeGas
    central_boiler_fuel_type_names << Constants.FuelTypeOil
    central_boiler_fuel_type_names << Constants.FuelTypePropane
    central_boiler_fuel_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('central_boiler_fuel_type', central_boiler_fuel_type_names, true)
    central_boiler_fuel_type.setDisplayName('Central Boiler Fuel Type')
    central_boiler_fuel_type.setDescription('The fuel type of the central boiler used for heating.')
    central_boiler_fuel_type.setDefaultValue(Constants.FuelTypeGas)
    args << central_boiler_fuel_type

    # make a bool argument for open hvac flue
    has_hvac_flue = OpenStudio::Measure::OSArgument::makeBoolArgument('has_hvac_flue', true)
    has_hvac_flue.setDisplayName('Air Leakage: Has Open HVAC Flue')
    has_hvac_flue.setDescription('Specifies whether the building has an open flue associated with the HVAC system.')
    has_hvac_flue.setDefaultValue(true)
    args << has_hvac_flue

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    require 'openstudio-standards'

    fan_coil_heating = runner.getBoolArgumentValue('fan_coil_heating', user_arguments)
    central_boiler_fuel_type = HelperMethods.eplus_fuel_map(runner.getStringArgumentValue('central_boiler_fuel_type', user_arguments))
    if central_boiler_fuel_type == 'Propane'
      central_boiler_fuel_type = 'PropaneGas' # OS-Standards is still using the old string
    end
    if fan_coil_heating
      model.getBuilding.additionalProperties.setFeature('has_hvac_flue', runner.getBoolArgumentValue('has_hvac_flue', user_arguments))
    end

    std = Standard.build('90.1-2013')

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    hot_water_loop = nil
    chilled_water_loop = nil
    units.each do |unit|
      thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)
      HVAC.get_control_and_slave_zones(thermal_zones).each do |control_zone, slave_zones|
        ([control_zone] + slave_zones).each do |zone|
          if fan_coil_heating
            HVAC.remove_heating(model, runner, zone, unit)
          end
          HVAC.remove_cooling(model, runner, zone, unit)
        end
      end

      if fan_coil_heating
        if hot_water_loop.nil?
          hot_water_loop = std.model_get_or_add_hot_water_loop(model, central_boiler_fuel_type)
          runner.registerInfo("Added '#{hot_water_loop.name}' to model.")
        end
      end

      if chilled_water_loop.nil?
        chilled_water_loop = std.model_get_or_add_chilled_water_loop(model, 'Electricity', chilled_water_loop_cooling_type: 'AirCooled')
        runner.registerInfo("Added '#{chilled_water_loop.name}' to model.")
      end

      success = HVAC.apply_central_system_fan_coil(model, unit, runner, std, fan_coil_heating, hot_water_loop, chilled_water_loop)

      return false if not success
    end # unit

    unless hot_water_loop.nil?
      pump_htg_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      pump_htg_program.setName('Central pumps htg program')

      hot_water_loop.supplyComponents.each do |supply_component|
        next unless supply_component.to_PumpVariableSpeed.is_initialized

        pump = supply_component.to_PumpVariableSpeed.get
        pump.setName('Central htg pump')

        htg_pump_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Pump Electricity Energy')
        htg_pump_sensor.setName("#{pump.name.to_s.gsub('|', '_')} s")
        htg_pump_sensor.setKeyName(pump.name.to_s)

        pump_htg_program.addLine("Set central_pumps_h = #{htg_pump_sensor.name}")

        pump_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, 'central_pumps_h')
        pump_output_var.setName('Central htg pump:Pumps:Electricity')
        pump_output_var.setTypeOfDataInVariable('Summed')
        pump_output_var.setUpdateFrequency('SystemTimestep')
        pump_output_var.setEMSProgramOrSubroutineName(pump_htg_program)
        pump_output_var.setUnits('J')
      end

      pump_htg_pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      pump_htg_pcm.setName('Central pump htg program calling manager')
      pump_htg_pcm.setCallingPoint('EndOfSystemTimestepBeforeHVACReporting')
      pump_htg_pcm.addProgram(pump_htg_program)
    end

    pump_clg_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    pump_clg_program.setName('Central pumps clg program')

    chilled_water_loop.supplyComponents.each do |supply_component|
      next unless supply_component.to_PumpVariableSpeed.is_initialized

      pump = supply_component.to_PumpVariableSpeed.get
      pump.setName('Central clg pump')

      clg_pump_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Pump Electricity Energy')
      clg_pump_sensor.setName("#{pump.name.to_s.gsub('|', '_')} s")
      clg_pump_sensor.setKeyName(pump.name.to_s)

      pump_clg_program.addLine("Set central_pumps_c = #{clg_pump_sensor.name}")

      pump_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, 'central_pumps_c')
      pump_output_var.setName('Central clg pump:Pumps:Electricity')
      pump_output_var.setTypeOfDataInVariable('Summed')
      pump_output_var.setUpdateFrequency('SystemTimestep')
      pump_output_var.setEMSProgramOrSubroutineName(pump_clg_program)
      pump_output_var.setUnits('J')
    end

    pump_clg_pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    pump_clg_pcm.setName('Central pump clg program calling manager')
    pump_clg_pcm.setCallingPoint('EndOfSystemTimestepBeforeHVACReporting')
    pump_clg_pcm.addProgram(pump_clg_program)

    simulation_control = model.getSimulationControl
    simulation_control.setRunSimulationforSizingPeriods(true) # indicate e+ autosizing

    return true
  end
end

# register the measure to be used by the application
ProcessCentralSystemFanCoil.new.registerWithApplication
