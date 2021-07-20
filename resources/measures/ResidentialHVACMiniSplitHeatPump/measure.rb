# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'hvac')

# start the measure
class ProcessMiniSplitHeatPump < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Set Residential Mini-Split Heat Pump'
  end

  # human readable description
  def description
    return "This measure removes any existing HVAC components from the building and adds a mini-split heat pump. For multifamily buildings, the mini-split heat pump can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Any supply components or baseboard convective electrics/waters are removed from any existing air/plant loops or zones. Any existing air/plant loops are also removed. A heating DX coil, cooling DX coil, and an on/off supply fan are added to a variable refrigerant flow terminal unit.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for minisplit cooling rated seer
    seer = OpenStudio::Measure::OSArgument::makeDoubleArgument('seer', true)
    seer.setDisplayName('Rated SEER')
    seer.setUnits('Btu/W-h')
    seer.setDescription('Seasonal Energy Efficiency Ratio (SEER) is a measure of equipment energy efficiency over the cooling season.')
    seer.setDefaultValue(14.5)
    args << seer

    # make a double argument for minisplit rated hspf
    hspf = OpenStudio::Measure::OSArgument::makeDoubleArgument('hspf', true)
    hspf.setDisplayName('Rated HSPF')
    hspf.setUnits('Btu/W-h')
    hspf.setDescription("The Heating Seasonal Performance Factor (HSPF) is a measure of a heat pump's energy efficiency over one heating season.")
    hspf.setDefaultValue(8.2)
    args << hspf

    # make a double argument for minisplit rated shr
    shr = OpenStudio::Measure::OSArgument::makeDoubleArgument('shr', true)
    shr.setDisplayName('Rated SHR')
    shr.setDescription('The sensible heat ratio (ratio of the sensible portion of the load to the total load) at the nominal rated capacity.')
    shr.setDefaultValue(0.73)
    args << shr

    # make a double argument for minisplit cooling min capacity
    min_cooling_capacity = OpenStudio::Measure::OSArgument::makeDoubleArgument('min_cooling_capacity', true)
    min_cooling_capacity.setDisplayName('Minimum Cooling Capacity')
    min_cooling_capacity.setUnits('frac')
    min_cooling_capacity.setDescription('Minimum cooling capacity as a fraction of the nominal cooling capacity at rated conditions.')
    min_cooling_capacity.setDefaultValue(0.4)
    args << min_cooling_capacity

    # make a double argument for minisplit cooling max capacity
    max_cooling_capacity = OpenStudio::Measure::OSArgument::makeDoubleArgument('max_cooling_capacity', true)
    max_cooling_capacity.setDisplayName('Maximum Cooling Capacity')
    max_cooling_capacity.setUnits('frac')
    max_cooling_capacity.setDescription('Maximum cooling capacity as a fraction of the nominal cooling capacity at rated conditions.')
    max_cooling_capacity.setDefaultValue(1.2)
    args << max_cooling_capacity

    # make a double argument for minisplit cooling min airflow
    min_cooling_airflow_rate = OpenStudio::Measure::OSArgument::makeDoubleArgument('min_cooling_airflow_rate', true)
    min_cooling_airflow_rate.setDisplayName('Minimum Cooling Airflow')
    min_cooling_airflow_rate.setUnits('cfm/ton')
    min_cooling_airflow_rate.setDescription('Minimum cooling cfm divided by the nominal rated cooling capacity.')
    min_cooling_airflow_rate.setDefaultValue(200.0)
    args << min_cooling_airflow_rate

    # make a double argument for minisplit cooling max airflow
    max_cooling_airflow_rate = OpenStudio::Measure::OSArgument::makeDoubleArgument('max_cooling_airflow_rate', true)
    max_cooling_airflow_rate.setDisplayName('Maximum Cooling Airflow')
    max_cooling_airflow_rate.setUnits('cfm/ton')
    max_cooling_airflow_rate.setDescription('Maximum cooling cfm divided by the nominal rated cooling capacity.')
    max_cooling_airflow_rate.setDefaultValue(425.0)
    args << max_cooling_airflow_rate

    # make a double argument for minisplit heating min capacity
    min_heating_capacity = OpenStudio::Measure::OSArgument::makeDoubleArgument('min_heating_capacity', true)
    min_heating_capacity.setDisplayName('Minimum Heating Capacity')
    min_heating_capacity.setUnits('frac')
    min_heating_capacity.setDescription('Minimum heating capacity as a fraction of nominal heating capacity at rated conditions.')
    min_heating_capacity.setDefaultValue(0.3)
    args << min_heating_capacity

    # make a double argument for minisplit heating max capacity
    max_heating_capacity = OpenStudio::Measure::OSArgument::makeDoubleArgument('max_heating_capacity', true)
    max_heating_capacity.setDisplayName('Maximum Heating Capacity')
    max_heating_capacity.setUnits('frac')
    max_heating_capacity.setDescription('Maximum heating capacity as a fraction of nominal heating capacity at rated conditions.')
    max_heating_capacity.setDefaultValue(1.2)
    args << max_heating_capacity

    # make a double argument for minisplit heating min airflow
    min_heating_airflow_rate = OpenStudio::Measure::OSArgument::makeDoubleArgument('min_heating_airflow_rate', true)
    min_heating_airflow_rate.setDisplayName('Minimum Heating Airflow')
    min_heating_airflow_rate.setUnits('cfm/ton')
    min_heating_airflow_rate.setDescription('Minimum heating cfm divided by the nominal rated heating capacity.')
    min_heating_airflow_rate.setDefaultValue(200.0)
    args << min_heating_airflow_rate

    # make a double argument for minisplit heating min airflow
    max_heating_airflow_rate = OpenStudio::Measure::OSArgument::makeDoubleArgument('max_heating_airflow_rate', true)
    max_heating_airflow_rate.setDisplayName('Maximum Heating Airflow')
    max_heating_airflow_rate.setUnits('cfm/ton')
    max_heating_airflow_rate.setDescription('Maximum heating cfm divided by the nominal rated heating capacity.')
    max_heating_airflow_rate.setDefaultValue(400.0)
    args << max_heating_airflow_rate

    # make a double argument for minisplit heating capacity offset
    heating_capacity_offset = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_capacity_offset', true)
    heating_capacity_offset.setDisplayName('Heating Capacity Offset')
    heating_capacity_offset.setUnits('Btu/hr')
    heating_capacity_offset.setDescription('The difference between the nominal rated heating capacity and the nominal rated cooling capacity.')
    heating_capacity_offset.setDefaultValue(2300.0)
    args << heating_capacity_offset

    # make a double argument for minisplit capacity retention fraction
    cap_retention_frac = OpenStudio::Measure::OSArgument::makeDoubleArgument('cap_retention_frac', true)
    cap_retention_frac.setDisplayName('Heating Capacity Retention Fraction')
    cap_retention_frac.setUnits('frac')
    cap_retention_frac.setDescription('The maximum heating capacity at X degrees divided by the maximum heating capacity at 47 degrees F.')
    cap_retention_frac.setDefaultValue(0.25)
    args << cap_retention_frac

    # make a double argument for minisplit capacity retention temperature
    cap_retention_temp = OpenStudio::Measure::OSArgument::makeDoubleArgument('cap_retention_temp', true)
    cap_retention_temp.setDisplayName('Heating Capacity Retention Temperature')
    cap_retention_temp.setUnits('degrees F')
    cap_retention_temp.setDescription('The outdoor drybulb temperature at which the heating capacity retention fraction is defined.')
    cap_retention_temp.setDefaultValue(-5.0)
    args << cap_retention_temp

    # make a double argument for minisplit pan heater power
    pan_heater_power = OpenStudio::Measure::OSArgument::makeDoubleArgument('pan_heater_power', true)
    pan_heater_power.setDisplayName('Pan Heater')
    pan_heater_power.setUnits('W/unit')
    pan_heater_power.setDescription('Prevents ice build up from damaging the coil.')
    pan_heater_power.setDefaultValue(0.0)
    args << pan_heater_power

    # make a double argument for minisplit supply fan power
    fan_power = OpenStudio::Measure::OSArgument::makeDoubleArgument('fan_power', true)
    fan_power.setDisplayName('Supply Fan Power')
    fan_power.setUnits('W/cfm')
    fan_power.setDescription('Fan power (in W) per delivered airflow rate (in cfm) of the fan.')
    fan_power.setDefaultValue(0.07)
    args << fan_power

    # make a string argument for minisplit cooling output capacity
    heat_pump_capacity = OpenStudio::Measure::OSArgument::makeStringArgument('heat_pump_capacity', true)
    heat_pump_capacity.setDisplayName('Heat Pump Capacity')
    heat_pump_capacity.setDescription("The output cooling capacity of the heat pump. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the heat pump capacity based on the cooling load, with up to 1.3x oversizing allowed for variable-speed equipment in colder climates when the heating load exceeds the cooling load. If using '#{Constants.SizingAutoMaxLoad}', the autosizing algorithm will override ACCA Manual S and use the maximum of the heating and cooling loads to set the heat pump capacity, based on the heating/cooling capacities under design conditions.")
    heat_pump_capacity.setUnits('tons')
    heat_pump_capacity.setDefaultValue(Constants.SizingAuto)
    args << heat_pump_capacity

    # make an argument for entering supplemental efficiency
    supplemental_efficiency = OpenStudio::Measure::OSArgument::makeDoubleArgument('supplemental_efficiency', true)
    supplemental_efficiency.setDisplayName('Supplemental Efficiency')
    supplemental_efficiency.setUnits('Btu/Btu')
    supplemental_efficiency.setDescription('The efficiency of the supplemental electric baseboard.')
    supplemental_efficiency.setDefaultValue(1.0)
    args << supplemental_efficiency

    # make a string argument for supplemental heating output capacity
    supplemental_capacity = OpenStudio::Measure::OSArgument::makeStringArgument('supplemental_capacity', true)
    supplemental_capacity.setDisplayName('Supplemental Heating Capacity')
    supplemental_capacity.setDescription("The output heating capacity of the supplemental electric baseboard. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the supplemental heating capacity.")
    supplemental_capacity.setUnits('kBtu/hr')
    supplemental_capacity.setDefaultValue(Constants.SizingAuto)
    args << supplemental_capacity

    # make a bool argument for whether the minisplit is ducted or ductless
    is_ducted = OpenStudio::Measure::OSArgument::makeBoolArgument('is_ducted', true)
    is_ducted.setDisplayName('Is Ducted')
    is_ducted.setDescription('Specified whether the mini-split heat pump is ducted or ductless.')
    is_ducted.setDefaultValue(false)
    args << is_ducted

    # make a string argument for distribution system efficiency
    dse = OpenStudio::Measure::OSArgument::makeStringArgument('dse', true)
    dse.setDisplayName('Distribution System Efficiency')
    dse.setDescription('Defines the energy losses associated with the delivery of energy from the equipment to the source of the load.')
    dse.setDefaultValue('NA')
    args << dse

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    seer = runner.getDoubleArgumentValue('seer', user_arguments)
    hspf = runner.getDoubleArgumentValue('hspf', user_arguments)
    shr = runner.getDoubleArgumentValue('shr', user_arguments)
    min_cooling_capacity = runner.getDoubleArgumentValue('min_cooling_capacity', user_arguments)
    max_cooling_capacity = runner.getDoubleArgumentValue('max_cooling_capacity', user_arguments)
    min_cooling_airflow_rate = runner.getDoubleArgumentValue('min_cooling_airflow_rate', user_arguments)
    max_cooling_airflow_rate = runner.getDoubleArgumentValue('max_cooling_airflow_rate', user_arguments)
    min_heating_capacity = runner.getDoubleArgumentValue('min_heating_capacity', user_arguments)
    max_heating_capacity = runner.getDoubleArgumentValue('max_heating_capacity', user_arguments)
    min_heating_airflow_rate = runner.getDoubleArgumentValue('min_heating_airflow_rate', user_arguments)
    max_heating_airflow_rate = runner.getDoubleArgumentValue('max_heating_airflow_rate', user_arguments)
    heating_capacity_offset = runner.getDoubleArgumentValue('heating_capacity_offset', user_arguments)
    cap_retention_frac = runner.getDoubleArgumentValue('cap_retention_frac', user_arguments)
    cap_retention_temp = runner.getDoubleArgumentValue('cap_retention_temp', user_arguments)
    pan_heater_power = runner.getDoubleArgumentValue('pan_heater_power', user_arguments)
    fan_power = runner.getDoubleArgumentValue('fan_power', user_arguments)
    heat_pump_capacity = runner.getStringArgumentValue('heat_pump_capacity', user_arguments)
    unless (heat_pump_capacity == Constants.SizingAuto) || (heat_pump_capacity == Constants.SizingAutoMaxLoad)
      heat_pump_capacity = UnitConversions.convert(heat_pump_capacity.to_f, 'ton', 'Btu/hr')
    end
    supplemental_efficiency = runner.getDoubleArgumentValue('supplemental_efficiency', user_arguments)
    supplemental_capacity = runner.getStringArgumentValue('supplemental_capacity', user_arguments)
    unless supplemental_capacity == Constants.SizingAuto
      supplemental_capacity = UnitConversions.convert(supplemental_capacity.to_f, 'kBtu/hr', 'Btu/hr')
    end
    is_ducted = runner.getBoolArgumentValue('is_ducted', user_arguments)
    dse = runner.getStringArgumentValue('dse', user_arguments)
    if dse.to_f > 0
      dse = dse.to_f
    else
      dse = 1.0
    end
    frac_heat_load_served = 1.0
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
          HVAC.remove_heating(model, runner, zone, unit)
          HVAC.remove_cooling(model, runner, zone, unit)
        end
      end

      success = HVAC.apply_mshp(model, unit, runner, seer, hspf, shr,
                                min_cooling_capacity, max_cooling_capacity,
                                min_cooling_airflow_rate, max_cooling_airflow_rate,
                                min_heating_capacity, max_heating_capacity,
                                min_heating_airflow_rate, max_heating_airflow_rate,
                                heating_capacity_offset, cap_retention_frac, cap_retention_temp,
                                pan_heater_power, fan_power, is_ducted,
                                heat_pump_capacity, supplemental_efficiency, supplemental_capacity,
                                dse, frac_heat_load_served, frac_cool_load_served)
      return false if not success
    end # unit

    return true
  end
end

# register the measure to be used by the application
ProcessMiniSplitHeatPump.new.registerWithApplication
