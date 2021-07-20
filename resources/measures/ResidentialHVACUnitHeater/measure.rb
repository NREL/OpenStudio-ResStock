# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'hvac')

# start the measure
class ProcessUnitHeater < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Unit Heater'
  end

  def description
    return "This measure removes any existing HVAC heating components from the building and adds a unit heater along with an optional on/off fan. For multifamily buildings, the unit heater can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Any heating components or baseboard convective electrics/waters are removed from any existing air/plant loops or zones. Any existing air/plant loops are also removed. A unitary system with a fuel heating coil and an optional on/off fan are added to each zone.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a string argument for heater fuel type
    fuel_display_names = OpenStudio::StringVector.new
    fuel_display_names << Constants.FuelTypeGas
    fuel_display_names << Constants.FuelTypeOil
    fuel_display_names << Constants.FuelTypePropane
    fuel_display_names << Constants.FuelTypeWood
    fuel_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('fuel_type', fuel_display_names, true)
    fuel_type.setDisplayName('Fuel Type')
    fuel_type.setDescription('Type of fuel used for heating.')
    fuel_type.setDefaultValue(Constants.FuelTypeGas)
    args << fuel_type

    # make an argument for entering efficiency
    efficiency = OpenStudio::Measure::OSArgument::makeDoubleArgument('efficiency', true)
    efficiency.setDisplayName('Efficiency')
    efficiency.setUnits('Btu/Btu')
    efficiency.setDescription('The efficiency of the heater.')
    efficiency.setDefaultValue(0.78)
    args << efficiency

    # make an argument for entering fan power
    fan_power = OpenStudio::Measure::OSArgument::makeDoubleArgument('fan_power', true)
    fan_power.setDisplayName('Fan Power')
    fan_power.setUnits('W/cfm')
    fan_power.setDescription('Fan power (in W) per delivered airflow rate (in cfm) of the fan. A value of 0 implies there is no fan.')
    fan_power.setDefaultValue(0.0)
    args << fan_power

    # make an argument for entering airflow rate
    airflow_rate = OpenStudio::Measure::OSArgument::makeDoubleArgument('airflow_rate', true)
    airflow_rate.setDisplayName('Airflow Rate')
    airflow_rate.setUnits('cfm/ton')
    airflow_rate.setDescription('Fan airflow rate as a function of heating capacity. A value of 0 implies there is no fan.')
    airflow_rate.setDefaultValue(0.0)
    args << airflow_rate

    # make a string argument for heating output capacity
    capacity = OpenStudio::Measure::OSArgument::makeStringArgument('capacity', true)
    capacity.setDisplayName('Heating Capacity')
    capacity.setDescription("The output heating capacity of the heater. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    capacity.setUnits('kBtu/hr')
    capacity.setDefaultValue(Constants.SizingAuto)
    args << capacity

    # make a bool argument for open hvac flue
    has_hvac_flue = OpenStudio::Measure::OSArgument::makeBoolArgument('has_hvac_flue', true)
    has_hvac_flue.setDisplayName('Air Leakage: Has Open HVAC Flue')
    has_hvac_flue.setDescription('Specifies whether the building has an open flue associated with the HVAC system.')
    has_hvac_flue.setDefaultValue(true)
    args << has_hvac_flue

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    fuel_type = runner.getStringArgumentValue('fuel_type', user_arguments)
    efficiency = runner.getDoubleArgumentValue('efficiency', user_arguments)
    capacity = runner.getStringArgumentValue('capacity', user_arguments)
    if not capacity == Constants.SizingAuto
      capacity = UnitConversions.convert(capacity.to_f, 'kBtu/hr', 'Btu/hr')
    end
    fan_power = runner.getDoubleArgumentValue('fan_power', user_arguments)
    airflow_rate = runner.getDoubleArgumentValue('airflow_rate', user_arguments)
    model.getBuilding.additionalProperties.setFeature('has_hvac_flue', runner.getBoolArgumentValue('has_hvac_flue', user_arguments))
    frac_heat_load_served = 1.0

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    units.each do |unit|
      thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)
      HVAC.get_control_and_slave_zones(thermal_zones).each do |control_zone, slave_zones|
        ([control_zone] + slave_zones).each do |zone|
          HVAC.remove_heating(model, runner, zone, unit)
        end
      end

      success = HVAC.apply_unit_heater(model, unit, runner, fuel_type,
                                       efficiency, capacity, fan_power,
                                       airflow_rate, frac_heat_load_served)
      return false if not success
    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ProcessUnitHeater.new.registerWithApplication
