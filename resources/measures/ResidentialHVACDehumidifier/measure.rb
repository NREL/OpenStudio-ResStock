# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'hvac')
require File.join(resources_path, 'constants')

# start the measure
class ProcessDehumidifier < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Set Residential Dehumidifier'
  end

  # human readable description
  def description
    return "This measure removes any existing dehumidifiers from the building and adds a dehumidifier. For multifamily buildings, the dehumidifier can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Any HVAC dehumidifier DXs are removed from any existing zones. An HVAC dehumidifier DX is added to the living zone, as well as to the finished basement if it exists. A humidistat is also added to the zone, with the relative humidity setpoint input by the user.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Make a string argument for dehumidifier energy factor
    energy_factor = OpenStudio::Measure::OSArgument::makeStringArgument('energy_factor', true)
    energy_factor.setDisplayName('Energy Factor')
    energy_factor.setDescription('The energy efficiency of dehumidifiers is measured by its energy factor, in liters of water removed per kilowatt-hour (kWh) of energy consumed or L/kWh.')
    energy_factor.setUnits('L/kWh')
    energy_factor.setDefaultValue(Constants.Auto)
    args << energy_factor

    # Make a string argument for dehumidifier water removal rate
    water_removal_rate = OpenStudio::Measure::OSArgument::makeStringArgument('water_removal_rate', true)
    water_removal_rate.setDisplayName('Water Removal Rate')
    water_removal_rate.setDescription('Dehumidifier rated water removal rate measured in pints per day at an inlet condition of 80 degrees F DB/60%RH.')
    water_removal_rate.setUnits('Pints/day')
    water_removal_rate.setDefaultValue(Constants.Auto)
    args << water_removal_rate

    # Make a string argument for dehumidifier air flow rate
    air_flow_rate = OpenStudio::Measure::OSArgument::makeStringArgument('air_flow_rate', true)
    air_flow_rate.setDisplayName('Air Flow Rate')
    air_flow_rate.setDescription("The dehumidifier rated air flow rate in CFM. If 'auto' is entered, the air flow will be determined using the rated water removal rate.")
    air_flow_rate.setUnits('cfm')
    air_flow_rate.setDefaultValue(Constants.Auto)
    args << air_flow_rate

    # Make a string argument for humidity setpoint
    humidity_setpoint = OpenStudio::Measure::OSArgument::makeDoubleArgument('humidity_setpoint', true)
    humidity_setpoint.setDisplayName('Annual Relative Humidity Setpoint')
    humidity_setpoint.setDescription('The annual relative humidity setpoint.')
    humidity_setpoint.setUnits('frac')
    humidity_setpoint.setDefaultValue(Constants.DefaultHumiditySetpoint)
    args << humidity_setpoint

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    energy_factor = runner.getStringArgumentValue('energy_factor', user_arguments)
    water_removal_rate = runner.getStringArgumentValue('water_removal_rate', user_arguments)
    air_flow_rate = runner.getStringArgumentValue('air_flow_rate', user_arguments)
    humidity_setpoint = runner.getDoubleArgumentValue('humidity_setpoint', user_arguments)

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    units.each do |unit|
      Geometry.get_thermal_zones_from_spaces(unit.spaces).each do |zone|
        HVAC.remove_dehumidifier(runner, model, zone, unit)
      end

      success = HVAC.apply_dehumidifier(model, unit, runner, energy_factor,
                                        water_removal_rate, air_flow_rate, humidity_setpoint)
      return false if not success
    end

    return true
  end
end

# register the measure to be used by the application
ProcessDehumidifier.new.registerWithApplication
