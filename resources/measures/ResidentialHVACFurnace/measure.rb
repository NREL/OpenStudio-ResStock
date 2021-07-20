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
class ProcessFurnace < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Furnace'
  end

  def description
    return "This measure removes any existing HVAC heating components from the building and adds a furnace along with an on/off supply fan to a unitary air loop. For multifamily buildings, the furnace can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Any heating components or baseboard convective electrics/waters are removed from any existing air/plant loops or zones. Any existing air/plant loops are also removed. A heating coil and an on/off supply fan are added to a unitary air loop. The unitary air loop is added to the supply inlet node of the air loop. This air loop is added to a branch for the living zone. A diffuser is added to the branch for the living zone as well as for the finished basement if it exists.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a string argument for furnace fuel type
    fuel_display_names = OpenStudio::StringVector.new
    fuel_display_names << Constants.FuelTypeGas
    fuel_display_names << Constants.FuelTypeOil
    fuel_display_names << Constants.FuelTypePropane
    fuel_display_names << Constants.FuelTypeElectric
    fuel_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('fuel_type', fuel_display_names, true)
    fuel_type.setDisplayName('Fuel Type')
    fuel_type.setDescription('Type of fuel used for heating.')
    fuel_type.setDefaultValue(Constants.FuelTypeGas)
    args << fuel_type

    # make an argument for entering furnace installed afue
    afue = OpenStudio::Measure::OSArgument::makeDoubleArgument('afue', true)
    afue.setDisplayName('Installed AFUE')
    afue.setUnits('Btu/Btu')
    afue.setDescription('The installed Annual Fuel Utilization Efficiency (AFUE) of the furnace, which can be used to account for performance derating or degradation relative to the rated value.')
    afue.setDefaultValue(0.78)
    args << afue

    # make an argument for entering furnace installed supply fan power
    fan_power_installed = OpenStudio::Measure::OSArgument::makeDoubleArgument('fan_power_installed', true)
    fan_power_installed.setDisplayName('Installed Supply Fan Power')
    fan_power_installed.setUnits('W/cfm')
    fan_power_installed.setDescription('Fan power (in W) per delivered airflow rate (in cfm) of the indoor fan for the maximum fan speed under actual operating conditions.')
    fan_power_installed.setDefaultValue(0.5)
    args << fan_power_installed

    # make a string argument for furnace heating output capacity
    capacity = OpenStudio::Measure::OSArgument::makeStringArgument('capacity', true)
    capacity.setDisplayName('Heating Capacity')
    capacity.setDescription("The output heating capacity of the furnace. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    capacity.setUnits('kBtu/hr')
    capacity.setDefaultValue(Constants.SizingAuto)
    args << capacity

    # make a string argument for distribution system efficiency
    dse = OpenStudio::Measure::OSArgument::makeStringArgument('dse', true)
    dse.setDisplayName('Distribution System Efficiency')
    dse.setDescription('Defines the energy losses associated with the delivery of energy from the equipment to the source of the load.')
    dse.setDefaultValue('NA')
    args << dse

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
    afue = runner.getDoubleArgumentValue('afue', user_arguments)
    capacity = runner.getStringArgumentValue('capacity', user_arguments)
    if not capacity == Constants.SizingAuto
      capacity = UnitConversions.convert(capacity.to_f, 'kBtu/hr', 'Btu/hr')
    end
    fan_power_installed = runner.getDoubleArgumentValue('fan_power_installed', user_arguments)
    dse = runner.getStringArgumentValue('dse', user_arguments)
    if dse.to_f > 0
      dse = dse.to_f
    else
      dse = 1.0
    end
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

      attached_to_multispeed_ac = false # FIXME

      success = HVAC.apply_furnace(model, unit, runner, fuel_type, afue,
                                   capacity, fan_power_installed, dse,
                                   frac_heat_load_served, attached_to_multispeed_ac)
      return false if not success
    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ProcessFurnace.new.registerWithApplication
