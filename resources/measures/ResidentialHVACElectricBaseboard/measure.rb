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
class ProcessElectricBaseboard < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Electric Baseboard'
  end

  def description
    return "This measure removes any existing electric baseboards from the building and adds electric baseboards. For multifamily buildings, the electric baseboard can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Any heating components or baseboard convective electrics/waters are removed from any existing air/plant loops or zones. An HVAC baseboard convective electric is added to the living zone, as well as to the finished basement if it exists.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make an argument for entering baseboard efficiency
    efficiency = OpenStudio::Measure::OSArgument::makeDoubleArgument('efficiency', true)
    efficiency.setDisplayName('Efficiency')
    efficiency.setUnits('Btu/Btu')
    efficiency.setDescription('The efficiency of the electric baseboard.')
    efficiency.setDefaultValue(1.0)
    args << efficiency

    # make a string argument for baseboard heating output capacity
    capacity = OpenStudio::Measure::OSArgument::makeStringArgument('capacity', true)
    capacity.setDisplayName('Heating Capacity')
    capacity.setDescription("The output heating capacity of the electric baseboard. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    capacity.setUnits('kBtu/hr')
    capacity.setDefaultValue(Constants.SizingAuto)
    args << capacity

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    efficiency = runner.getDoubleArgumentValue('efficiency', user_arguments)
    capacity = runner.getStringArgumentValue('capacity', user_arguments)
    unless capacity == Constants.SizingAuto
      capacity = UnitConversions.convert(capacity.to_f, 'kBtu/hr', 'Btu/hr')
    end
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

      success = HVAC.apply_electric_baseboard(model, unit, runner, efficiency, capacity, frac_heat_load_served)
      return false if not success
    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ProcessElectricBaseboard.new.registerWithApplication
