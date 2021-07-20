# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'hvac')

# start the measure
class ProcessRoomAirConditioner < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Set Residential Room Air Conditioner'
  end

  # human readable description
  def description
    return "This measure removes any existing HVAC cooling components from the building and adds a room air conditioner. For multifamily buildings, the room air conditioner can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Any cooling components are removed from any existing air loops or zones. Any existing air loops are also removed. An HVAC packaged terminal air conditioner is added to the living zone.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for room ac eer
    eer = OpenStudio::Measure::OSArgument::makeDoubleArgument('eer', true)
    eer.setDisplayName('EER')
    eer.setUnits('Btu/W-h')
    eer.setDescription('This is a measure of the instantaneous energy efficiency of the cooling equipment.')
    eer.setDefaultValue(8.5)
    args << eer

    # make a double argument for room ac shr
    shr = OpenStudio::Measure::OSArgument::makeDoubleArgument('shr', true)
    shr.setDisplayName('Rated SHR')
    shr.setDescription('The sensible heat ratio (ratio of the sensible portion of the load to the total load) at the nominal rated capacity.')
    shr.setDefaultValue(0.65)
    args << shr

    # make a double argument for room ac airflow
    airflow_rate = OpenStudio::Measure::OSArgument::makeDoubleArgument('airflow_rate', true)
    airflow_rate.setDisplayName('Airflow')
    airflow_rate.setUnits('cfm/ton')
    airflow_rate.setDefaultValue(350.0)
    args << airflow_rate

    # make a choice argument for room ac cooling output capacity
    capacity = OpenStudio::Measure::OSArgument::makeStringArgument('capacity', true)
    capacity.setDisplayName('Cooling Capacity')
    capacity.setDescription("The output cooling capacity of the air conditioner. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    capacity.setUnits('tons')
    capacity.setDefaultValue(Constants.SizingAuto)
    args << capacity

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    eer = runner.getDoubleArgumentValue('eer', user_arguments)
    shr = runner.getDoubleArgumentValue('shr', user_arguments)
    airflow_rate = runner.getDoubleArgumentValue('airflow_rate', user_arguments)
    capacity = runner.getStringArgumentValue('capacity', user_arguments)
    unless capacity == Constants.SizingAuto
      capacity = UnitConversions.convert(capacity.to_f, 'ton', 'Btu/hr')
    end
    frac_cool_load_served = 1.0

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    units.each do |unit|
      thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)
      HVAC.get_control_and_slave_zones(thermal_zones).each do |control_zone, slave_zones|
        ([control_zone] + slave_zones).each do |zone|
          HVAC.remove_cooling(model, runner, zone, unit)
        end
      end

      success = HVAC.apply_room_ac(model, unit, runner, eer, shr,
                                   airflow_rate, capacity, frac_cool_load_served)
      return false if not success
    end # unit

    return true
  end
end

# register the measure to be used by the application
ProcessRoomAirConditioner.new.registerWithApplication
