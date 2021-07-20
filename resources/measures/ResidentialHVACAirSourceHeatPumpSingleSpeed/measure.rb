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
class ProcessSingleSpeedAirSourceHeatPump < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Single-Speed Air Source Heat Pump'
  end

  def description
    return "This measure removes any existing HVAC components from the building and adds a single-speed air source heat pump along with an on/off supply fan to a unitary air loop. For multifamily buildings, the single-speed air source heat pump can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Any supply components or baseboard convective electrics/waters are removed from any existing air/plant loops or zones. Any existing air/plant loops are also removed. A heating DX coil, cooling DX coil, electric supplemental heating coil, and an on/off supply fan are added to a unitary air loop. The unitary air loop is added to the supply inlet node of the air loop. This air loop is added to a branch for the living zone. A diffuser is added to the branch for the living zone as well as for the finished basement if it exists.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a string argument for ashp installed seer
    seer = OpenStudio::Measure::OSArgument::makeDoubleArgument('seer', true)
    seer.setDisplayName('Installed SEER')
    seer.setUnits('Btu/W-h')
    seer.setDescription('The installed Seasonal Energy Efficiency Ratio (SEER) of the heat pump.')
    seer.setDefaultValue(13.0)
    args << seer

    # make a string argument for ashp installed hspf
    hspf = OpenStudio::Measure::OSArgument::makeDoubleArgument('hspf', true)
    hspf.setDisplayName('Installed HSPF')
    hspf.setUnits('Btu/W-h')
    hspf.setDescription('The installed Heating Seasonal Performance Factor (HSPF) of the heat pump.')
    hspf.setDefaultValue(7.7)
    args << hspf

    # make a double argument for ashp eer
    eer = OpenStudio::Measure::OSArgument::makeDoubleArgument('eer', true)
    eer.setDisplayName('EER')
    eer.setUnits('kBtu/kWh')
    eer.setDescription('EER (net) from the A test (95 ODB/80 EDB/67 EWB).')
    eer.setDefaultValue(11.4)
    args << eer

    # make a double argument for ashp cop
    cop = OpenStudio::Measure::OSArgument::makeDoubleArgument('cop', true)
    cop.setDisplayName('COP')
    cop.setUnits('Wh/Wh')
    cop.setDescription('COP (net) at 47 ODB/70 EDB/60 EWB (AHRI rated conditions).')
    cop.setDefaultValue(3.05)
    args << cop

    # make a double argument for ashp rated shr
    shr = OpenStudio::Measure::OSArgument::makeDoubleArgument('shr', true)
    shr.setDisplayName('Rated SHR')
    shr.setDescription('The sensible heat ratio (ratio of the sensible portion of the load to the total load) at the nominal rated capacity.')
    shr.setDefaultValue(0.73)
    args << shr

    # make a double argument for ashp rated supply fan power
    fan_power_rated = OpenStudio::Measure::OSArgument::makeDoubleArgument('fan_power_rated', true)
    fan_power_rated.setDisplayName('Rated Supply Fan Power')
    fan_power_rated.setUnits('W/cfm')
    fan_power_rated.setDescription('Fan power (in W) per delivered airflow rate (in cfm) of the outdoor fan under conditions prescribed by AHRI Standard 210/240 for SEER testing.')
    fan_power_rated.setDefaultValue(0.365)
    args << fan_power_rated

    # make a double argument for ashp installed supply fan power
    fan_power_installed = OpenStudio::Measure::OSArgument::makeDoubleArgument('fan_power_installed', true)
    fan_power_installed.setDisplayName('Installed Supply Fan Power')
    fan_power_installed.setUnits('W/cfm')
    fan_power_installed.setDescription('Fan power (in W) per delivered airflow rate (in cfm) of the outdoor fan for the maximum fan speed under actual operating conditions.')
    fan_power_installed.setDefaultValue(0.5)
    args << fan_power_installed

    # make a double argument for ashp min t
    min_temp = OpenStudio::Measure::OSArgument::makeDoubleArgument('min_temp', true)
    min_temp.setDisplayName('Min Temp')
    min_temp.setUnits('degrees F')
    min_temp.setDescription('Outdoor dry-bulb temperature below which compressor turns off.')
    min_temp.setDefaultValue(0.0)
    args << min_temp

    # make a double argument for central ac crankcase
    crankcase_capacity = OpenStudio::Measure::OSArgument::makeDoubleArgument('crankcase_capacity', true)
    crankcase_capacity.setDisplayName('Crankcase')
    crankcase_capacity.setUnits('kW')
    crankcase_capacity.setDescription('Capacity of the crankcase heater for the compressor.')
    crankcase_capacity.setDefaultValue(0.02)
    args << crankcase_capacity

    # make a double argument for ashp crankcase max t
    crankcase_temp = OpenStudio::Measure::OSArgument::makeDoubleArgument('crankcase_temp', true)
    crankcase_temp.setDisplayName('Crankcase Max Temp')
    crankcase_temp.setUnits('degrees F')
    crankcase_temp.setDescription('Outdoor dry-bulb temperature above which compressor crankcase heating is disabled.')
    crankcase_temp.setDefaultValue(55.0)
    args << crankcase_temp

    # make a double argument for ashp 1.5 ton eer capacity derate
    seer_capacity_derate_1ton = OpenStudio::Measure::OSArgument::makeDoubleArgument('eer_capacity_derate_1ton', true)
    seer_capacity_derate_1ton.setDisplayName('1.5 Ton EER Capacity Derate')
    seer_capacity_derate_1ton.setDescription('EER multiplier for 1.5 ton air-conditioners.')
    seer_capacity_derate_1ton.setDefaultValue(1.0)
    args << seer_capacity_derate_1ton

    # make a double argument for central ac 2 ton eer capacity derate
    seer_capacity_derate_2ton = OpenStudio::Measure::OSArgument::makeDoubleArgument('eer_capacity_derate_2ton', true)
    seer_capacity_derate_2ton.setDisplayName('2 Ton EER Capacity Derate')
    seer_capacity_derate_2ton.setDescription('EER multiplier for 2 ton air-conditioners.')
    seer_capacity_derate_2ton.setDefaultValue(1.0)
    args << seer_capacity_derate_2ton

    # make a double argument for central ac 3 ton eer capacity derate
    seer_capacity_derate_3ton = OpenStudio::Measure::OSArgument::makeDoubleArgument('eer_capacity_derate_3ton', true)
    seer_capacity_derate_3ton.setDisplayName('3 Ton EER Capacity Derate')
    seer_capacity_derate_3ton.setDescription('EER multiplier for 3 ton air-conditioners.')
    seer_capacity_derate_3ton.setDefaultValue(1.0)
    args << seer_capacity_derate_3ton

    # make a double argument for central ac 4 ton eer capacity derate
    seer_capacity_derate_4ton = OpenStudio::Measure::OSArgument::makeDoubleArgument('eer_capacity_derate_4ton', true)
    seer_capacity_derate_4ton.setDisplayName('4 Ton EER Capacity Derate')
    seer_capacity_derate_4ton.setDescription('EER multiplier for 4 ton air-conditioners.')
    seer_capacity_derate_4ton.setDefaultValue(1.0)
    args << seer_capacity_derate_4ton

    # make a double argument for central ac 5 ton eer capacity derate
    seer_capacity_derate_5ton = OpenStudio::Measure::OSArgument::makeDoubleArgument('eer_capacity_derate_5ton', true)
    seer_capacity_derate_5ton.setDisplayName('5 Ton EER Capacity Derate')
    seer_capacity_derate_5ton.setDescription('EER multiplier for 5 ton air-conditioners.')
    seer_capacity_derate_5ton.setDefaultValue(1.0)
    args << seer_capacity_derate_5ton

    # make a double argument for ashp 1.5 ton cop capacity derate
    cop_capacity_derate_1ton = OpenStudio::Measure::OSArgument::makeDoubleArgument('cop_capacity_derate_1ton', true)
    cop_capacity_derate_1ton.setDisplayName('1.5 Ton COP Capacity Derate')
    cop_capacity_derate_1ton.setDescription('COP multiplier for 1.5 ton air-conditioners.')
    cop_capacity_derate_1ton.setDefaultValue(1.0)
    args << cop_capacity_derate_1ton

    # make a double argument for ashp 2 ton cop capacity derate
    cop_capacity_derate_2ton = OpenStudio::Measure::OSArgument::makeDoubleArgument('cop_capacity_derate_2ton', true)
    cop_capacity_derate_2ton.setDisplayName('2 Ton COP Capacity Derate')
    cop_capacity_derate_2ton.setDescription('COP multiplier for 2 ton air-conditioners.')
    cop_capacity_derate_2ton.setDefaultValue(1.0)
    args << cop_capacity_derate_2ton

    # make a double argument for ashp 3 ton cop capacity derate
    cop_capacity_derate_3ton = OpenStudio::Measure::OSArgument::makeDoubleArgument('cop_capacity_derate_3ton', true)
    cop_capacity_derate_3ton.setDisplayName('3 Ton COP Capacity Derate')
    cop_capacity_derate_3ton.setDescription('COP multiplier for 3 ton air-conditioners.')
    cop_capacity_derate_3ton.setDefaultValue(1.0)
    args << cop_capacity_derate_3ton

    # make a double argument for ashp 4 ton cop capacity derate
    cop_capacity_derate_4ton = OpenStudio::Measure::OSArgument::makeDoubleArgument('cop_capacity_derate_4ton', true)
    cop_capacity_derate_4ton.setDisplayName('4 Ton COP Capacity Derate')
    cop_capacity_derate_4ton.setDescription('COP multiplier for 4 ton air-conditioners.')
    cop_capacity_derate_4ton.setDefaultValue(1.0)
    args << cop_capacity_derate_4ton

    # make a double argument for ashp 5 ton cop capacity derate
    cop_capacity_derate_5ton = OpenStudio::Measure::OSArgument::makeDoubleArgument('cop_capacity_derate_5ton', true)
    cop_capacity_derate_5ton.setDisplayName('5 Ton COP Capacity Derate')
    cop_capacity_derate_5ton.setDescription('COP multiplier for 5 ton air-conditioners.')
    cop_capacity_derate_5ton.setDefaultValue(1.0)
    args << cop_capacity_derate_5ton

    # make a string argument for ashp cooling/heating output capacity
    heat_pump_capacity = OpenStudio::Measure::OSArgument::makeStringArgument('heat_pump_capacity', true)
    heat_pump_capacity.setDisplayName('Heat Pump Capacity')
    heat_pump_capacity.setDescription("The output heating/cooling capacity of the heat pump. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the heat pump capacity based on the cooling load. If using '#{Constants.SizingAutoMaxLoad}', the autosizing algorithm will override ACCA Manual S and use the maximum of the heating and cooling loads to set the heat pump capacity, based on the heating/cooling capacities under design conditions.")
    heat_pump_capacity.setUnits('tons')
    heat_pump_capacity.setDefaultValue(Constants.SizingAuto)
    args << heat_pump_capacity

    # make an argument for entering supplemental efficiency
    supplemental_efficiency = OpenStudio::Measure::OSArgument::makeDoubleArgument('supplemental_efficiency', true)
    supplemental_efficiency.setDisplayName('Supplemental Efficiency')
    supplemental_efficiency.setUnits('Btu/Btu')
    supplemental_efficiency.setDescription('The efficiency of the supplemental electric coil.')
    supplemental_efficiency.setDefaultValue(1.0)
    args << supplemental_efficiency

    # make a string argument for supplemental heating output capacity
    supplemental_capacity = OpenStudio::Measure::OSArgument::makeStringArgument('supplemental_capacity', true)
    supplemental_capacity.setDisplayName('Supplemental Heating Capacity')
    supplemental_capacity.setDescription("The output heating capacity of the supplemental heater. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the heat pump supplemental heating capacity.")
    supplemental_capacity.setUnits('kBtu/hr')
    supplemental_capacity.setDefaultValue(Constants.SizingAuto)
    args << supplemental_capacity

    # make a string argument for distribution system efficiency
    dse = OpenStudio::Measure::OSArgument::makeStringArgument('dse', true)
    dse.setDisplayName('Distribution System Efficiency')
    dse.setDescription('Defines the energy losses associated with the delivery of energy from the equipment to the source of the load.')
    dse.setDefaultValue('NA')
    args << dse

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    seer = runner.getDoubleArgumentValue('seer', user_arguments)
    hspf = runner.getDoubleArgumentValue('hspf', user_arguments)
    eers = [runner.getDoubleArgumentValue('eer', user_arguments)]
    cops = [runner.getDoubleArgumentValue('cop', user_arguments)]
    shrs = [runner.getDoubleArgumentValue('shr', user_arguments)]
    fan_power_rated = runner.getDoubleArgumentValue('fan_power_rated', user_arguments)
    fan_power_installed = runner.getDoubleArgumentValue('fan_power_installed', user_arguments)
    min_temp = runner.getDoubleArgumentValue('min_temp', user_arguments)
    crankcase_capacity = runner.getDoubleArgumentValue('crankcase_capacity', user_arguments)
    crankcase_temp = runner.getDoubleArgumentValue('crankcase_temp', user_arguments)
    eer_capacity_derate_1ton = runner.getDoubleArgumentValue('eer_capacity_derate_1ton', user_arguments)
    eer_capacity_derate_2ton = runner.getDoubleArgumentValue('eer_capacity_derate_2ton', user_arguments)
    eer_capacity_derate_3ton = runner.getDoubleArgumentValue('eer_capacity_derate_3ton', user_arguments)
    eer_capacity_derate_4ton = runner.getDoubleArgumentValue('eer_capacity_derate_4ton', user_arguments)
    eer_capacity_derate_5ton = runner.getDoubleArgumentValue('eer_capacity_derate_5ton', user_arguments)
    eer_capacity_derates = [eer_capacity_derate_1ton, eer_capacity_derate_2ton, eer_capacity_derate_3ton, eer_capacity_derate_4ton, eer_capacity_derate_5ton]
    cop_capacity_derate_1ton = runner.getDoubleArgumentValue('cop_capacity_derate_1ton', user_arguments)
    cop_capacity_derate_2ton = runner.getDoubleArgumentValue('cop_capacity_derate_2ton', user_arguments)
    cop_capacity_derate_3ton = runner.getDoubleArgumentValue('cop_capacity_derate_3ton', user_arguments)
    cop_capacity_derate_4ton = runner.getDoubleArgumentValue('cop_capacity_derate_4ton', user_arguments)
    cop_capacity_derate_5ton = runner.getDoubleArgumentValue('cop_capacity_derate_5ton', user_arguments)
    cop_capacity_derates = [cop_capacity_derate_1ton, cop_capacity_derate_2ton, cop_capacity_derate_3ton, cop_capacity_derate_4ton, cop_capacity_derate_5ton]
    heat_pump_capacity = runner.getStringArgumentValue('heat_pump_capacity', user_arguments)
    unless (heat_pump_capacity == Constants.SizingAuto) || (heat_pump_capacity == Constants.SizingAutoMaxLoad)
      heat_pump_capacity = UnitConversions.convert(heat_pump_capacity.to_f, 'ton', 'Btu/hr')
    end
    supplemental_efficiency = runner.getDoubleArgumentValue('supplemental_efficiency', user_arguments)
    supplemental_capacity = runner.getStringArgumentValue('supplemental_capacity', user_arguments)
    unless supplemental_capacity == Constants.SizingAuto
      supplemental_capacity = UnitConversions.convert(supplemental_capacity.to_f, 'kBtu/hr', 'Btu/hr')
    end
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

      success = HVAC.apply_central_ashp_1speed(model, unit, runner, seer, hspf, eers, cops, shrs,
                                               fan_power_rated, fan_power_installed, min_temp,
                                               crankcase_capacity, crankcase_temp,
                                               eer_capacity_derates, cop_capacity_derates,
                                               heat_pump_capacity, supplemental_efficiency,
                                               supplemental_capacity, dse,
                                               frac_heat_load_served, frac_cool_load_served)
      return false if not success
    end # unit

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ProcessSingleSpeedAirSourceHeatPump.new.registerWithApplication
