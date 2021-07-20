# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'airflow')

# start the measure
class ResidentialAirflow < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Set Residential Airflow'
  end

  # human readable description
  def description
    return "Adds (or replaces) all building components related to airflow: infiltration, mechanical ventilation, natural ventilation, and ducts.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Uses EMS to model the building airflow.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for infiltration of living space
    living_ach50 = OpenStudio::Measure::OSArgument::makeDoubleArgument('living_ach50', true)
    living_ach50.setDisplayName('Air Leakage: Above-Grade Living ACH50')
    living_ach50.setUnits('1/hr')
    living_ach50.setDescription('Air exchange rate, in Air Changes per Hour at 50 Pascals (ACH50), for above-grade living space (including finished attic).')
    living_ach50.setDefaultValue(7)
    args << living_ach50

    # make a double argument for infiltration of garage
    garage_ach50 = OpenStudio::Measure::OSArgument::makeDoubleArgument('garage_ach50', true)
    garage_ach50.setDisplayName('Air Leakage: Garage ACH50')
    garage_ach50.setUnits('1/hr')
    garage_ach50.setDescription('Air exchange rate, in Air Changes per Hour at 50 Pascals (ACH50), for the garage.')
    garage_ach50.setDefaultValue(7)
    args << garage_ach50

    # make a double argument for infiltration of finished basement
    finished_basement_ach = OpenStudio::Measure::OSArgument::makeDoubleArgument('finished_basement_ach', true)
    finished_basement_ach.setDisplayName('Air Leakage: Finished Basement Constant ACH')
    finished_basement_ach.setUnits('1/hr')
    finished_basement_ach.setDescription('Constant air exchange rate, in Air Changes per Hour (ACH), for the finished basement.')
    finished_basement_ach.setDefaultValue(0.0)
    args << finished_basement_ach

    # make a double argument for infiltration of unfinished basement
    unfinished_basement_ach = OpenStudio::Measure::OSArgument::makeDoubleArgument('unfinished_basement_ach', true)
    unfinished_basement_ach.setDisplayName('Air Leakage: Unfinished Basement Constant ACH')
    unfinished_basement_ach.setUnits('1/hr')
    unfinished_basement_ach.setDescription('Constant air exchange rate, in Air Changes per Hour (ACH), for the unfinished basement. A value of 0.10 ACH or greater is recommended for modeling Heat Pump Water Heaters in unfinished basements.')
    unfinished_basement_ach.setDefaultValue(0.1)
    args << unfinished_basement_ach

    # make a double argument for infiltration of crawlspace
    crawl_ach = OpenStudio::Measure::OSArgument::makeDoubleArgument('crawl_ach', true)
    crawl_ach.setDisplayName('Air Leakage: Crawlspace Constant ACH')
    crawl_ach.setUnits('1/hr')
    crawl_ach.setDescription('Air exchange rate, in Air Changes per Hour at 50 Pascals (ACH50), for the crawlspace.')
    crawl_ach.setDefaultValue(0.0)
    args << crawl_ach

    # make a double argument for infiltration of pier & beam
    pier_beam_ach = OpenStudio::Measure::OSArgument::makeDoubleArgument('pier_beam_ach', true)
    pier_beam_ach.setDisplayName('Air Leakage: Pier & Beam Constant ACH')
    pier_beam_ach.setUnits('1/hr')
    pier_beam_ach.setDescription('Air exchange rate, in Air Changes per Hour at 50 Pascals (ACH50), for the pier & beam foundation.')
    pier_beam_ach.setDefaultValue(100.0)
    args << pier_beam_ach

    # make a double argument for infiltration of unfinished attic
    unfinished_attic_sla = OpenStudio::Measure::OSArgument::makeDoubleArgument('unfinished_attic_sla', true)
    unfinished_attic_sla.setDisplayName('Air Leakage: Unfinished Attic SLA')
    unfinished_attic_sla.setDescription('Ratio of the effective leakage area (infiltration and/or ventilation) in the unfinished attic to the total floor area of the attic.')
    unfinished_attic_sla.setDefaultValue(0.00333)
    args << unfinished_attic_sla

    # make a double argument for shelter coefficient
    shelter_coef = OpenStudio::Measure::OSArgument::makeStringArgument('shelter_coef', true)
    shelter_coef.setDisplayName('Air Leakage: Shelter Coefficient')
    shelter_coef.setDescription('The local shelter coefficient (AIM-2 infiltration model) accounts for nearby buildings, trees and obstructions.')
    shelter_coef.setDefaultValue('auto')
    args << shelter_coef

    # make a choice arguments for terrain type
    terrain_types_names = OpenStudio::StringVector.new
    terrain_types_names << Constants.TerrainOcean
    terrain_types_names << Constants.TerrainPlains
    terrain_types_names << Constants.TerrainRural
    terrain_types_names << Constants.TerrainSuburban
    terrain_types_names << Constants.TerrainCity
    terrain = OpenStudio::Measure::OSArgument::makeChoiceArgument('terrain', terrain_types_names, true)
    terrain.setDisplayName('Air Leakage: Site Terrain')
    terrain.setDescription('The terrain of the site.')
    terrain.setDefaultValue(Constants.TerrainSuburban)
    args << terrain

    # make a choice argument for ventilation type
    ventilation_types_names = OpenStudio::StringVector.new
    ventilation_types_names << Constants.VentTypeNone
    ventilation_types_names << Constants.VentTypeExhaust
    ventilation_types_names << Constants.VentTypeSupply
    ventilation_types_names << Constants.VentTypeCFIS
    ventilation_types_names << Constants.VentTypeBalanced
    mech_vent_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('mech_vent_type', ventilation_types_names, true)
    mech_vent_type.setDisplayName('Mechanical Ventilation: Ventilation Type')
    mech_vent_type.setDescription('Whole house ventilation strategy used.')
    mech_vent_type.setDefaultValue(Constants.VentTypeExhaust)
    args << mech_vent_type

    # make a double argument for house fan power
    mech_vent_fan_power = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_fan_power', true)
    mech_vent_fan_power.setDisplayName('Mechanical Ventilation: Fan Power')
    mech_vent_fan_power.setUnits('W/cfm')
    mech_vent_fan_power.setDescription("Fan power (in W) per delivered airflow rate (in cfm) of fan(s) providing whole house ventilation. If the house uses a balanced ventilation system there is assumed to be two fans operating at this efficiency. Not used for #{Constants.VentTypeCFIS} systems.")
    mech_vent_fan_power.setDefaultValue(0.15)
    args << mech_vent_fan_power

    # make a double argument for total efficiency
    mech_vent_total_efficiency = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_total_efficiency', true)
    mech_vent_total_efficiency.setDisplayName('Mechanical Ventilation: Total Recovery Efficiency')
    mech_vent_total_efficiency.setDescription("The net total energy (sensible plus latent, also called enthalpy) recovered by the supply airstream adjusted by electric consumption, case heat loss or heat gain, air leakage and airflow mass imbalance between the two airstreams, as a percent of the potential total energy that could be recovered plus the exhaust fan energy. Only used for #{Constants.VentTypeBalanced} systems.")
    mech_vent_total_efficiency.setDefaultValue(0)
    args << mech_vent_total_efficiency

    # make a double argument for sensible efficiency
    mech_vent_sensible_efficiency = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_sensible_efficiency', true)
    mech_vent_sensible_efficiency.setDisplayName('Mechanical Ventilation: Sensible Recovery Efficiency')
    mech_vent_sensible_efficiency.setDescription("The net sensible energy recovered by the supply airstream as adjusted by electric consumption, case heat loss or heat gain, air leakage, airflow mass imbalance between the two airstreams and the energy used for defrost (when running the Very Low Temperature Test), as a percent of the potential sensible energy that could be recovered plus the exhaust fan energy. Only used for #{Constants.VentTypeBalanced} systems.")
    mech_vent_sensible_efficiency.setDefaultValue(0)
    args << mech_vent_sensible_efficiency

    # make a double argument for fraction of ashrae
    mech_vent_frac_62_2 = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_frac_62_2', true)
    mech_vent_frac_62_2.setDisplayName('Mechanical Ventilation: Fraction of ASHRAE 62.2')
    mech_vent_frac_62_2.setUnits('frac')
    mech_vent_frac_62_2.setDescription('Fraction of the ventilation rate (including any infiltration credit) specified by ASHRAE 62.2 that is desired in the building.')
    mech_vent_frac_62_2.setDefaultValue(1.0)
    args << mech_vent_frac_62_2

    # make a choice argument for ashrae standard
    standard_types_names = OpenStudio::StringVector.new
    standard_types_names << '2010'
    standard_types_names << '2013'

    # make a double argument for ashrae standard
    mech_vent_ashrae_std = OpenStudio::Measure::OSArgument::makeChoiceArgument('mech_vent_ashrae_std', standard_types_names, true)
    mech_vent_ashrae_std.setDisplayName('Mechanical Ventilation: ASHRAE 62.2 Standard')
    mech_vent_ashrae_std.setDescription('Specifies which version (year) of the ASHRAE 62.2 Standard should be used.')
    mech_vent_ashrae_std.setDefaultValue('2010')
    args << mech_vent_ashrae_std

    # make a bool argument for infiltration credit
    mech_vent_infil_credit = OpenStudio::Measure::OSArgument::makeBoolArgument('mech_vent_infil_credit', true)
    mech_vent_infil_credit.setDisplayName('Mechanical Ventilation: Allow Infiltration Credit')
    mech_vent_infil_credit.setDescription('Defines whether the infiltration credit allowed per the ASHRAE 62.2 Standard will be included in the calculation of the mechanical ventilation rate. If True, the infiltration credit will apply 1) to new/existing single-family detached homes for 2013 ASHRAE 62.2, or 2) to existing single-family detached or multi-family homes for 2010 ASHRAE 62.2.')
    mech_vent_infil_credit.setDefaultValue(true)
    args << mech_vent_infil_credit

    # make a boolean argument for if an existing home
    is_existing_home = OpenStudio::Measure::OSArgument::makeBoolArgument('is_existing_home', true)
    is_existing_home.setDisplayName('Mechanical Ventilation: Is Existing Home')
    is_existing_home.setDescription('Specifies whether the building is an existing home or new construction.')
    is_existing_home.setDefaultValue(false)
    args << is_existing_home

    # make a double argument for cfis open time
    mech_vent_cfis_open_time = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_cfis_open_time', true)
    mech_vent_cfis_open_time.setDisplayName('Mechanical Ventilation: CFIS Damper Open Time')
    mech_vent_cfis_open_time.setDescription("Minimum damper open time for a #{Constants.VentTypeCFIS} system.")
    mech_vent_cfis_open_time.setDefaultValue(20.0)
    args << mech_vent_cfis_open_time

    # make a double argument for cfis airflow fraction
    mech_vent_cfis_airflow_frac = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_cfis_airflow_frac', true)
    mech_vent_cfis_airflow_frac.setDisplayName('Mechanical Ventilation: CFIS Ventilation Mode Airflow Fraction')
    mech_vent_cfis_airflow_frac.setDescription("Blower airflow rate, when the #{Constants.VentTypeCFIS} system is operating in ventilation mode, as a fraction of maximum blower airflow rate.")
    mech_vent_cfis_airflow_frac.setDefaultValue(1.0)
    args << mech_vent_cfis_airflow_frac

    # make an integer argument for hour of range spot ventilation
    range_exhaust_hour = OpenStudio::Measure::OSArgument::makeIntegerArgument('range_exhaust_hour', true)
    range_exhaust_hour.setDisplayName('Spot Ventilation: Hour of range spot ventilation')
    range_exhaust_hour.setDescription('Hour in which range spot ventilation occurs. Values indicate the time of spot ventilation, which lasts for 1 hour.')
    range_exhaust_hour.setDefaultValue(16)
    args << range_exhaust_hour

    # make an integer argument for hour of bathroom spot ventilation
    bathroom_exhaust_hour = OpenStudio::Measure::OSArgument::makeIntegerArgument('bathroom_exhaust_hour', true)
    bathroom_exhaust_hour.setDisplayName('Spot Ventilation: Hour of bathroom spot ventilation')
    bathroom_exhaust_hour.setDescription('Hour in which bathroom spot ventilation occurs. Values indicate the time of spot ventilation, which lasts for 1 hour.')
    bathroom_exhaust_hour.setDefaultValue(5)
    args << bathroom_exhaust_hour

    # make a double argument for dryer exhaust
    clothes_dryer_exhaust = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_dryer_exhaust', true)
    clothes_dryer_exhaust.setDisplayName('Clothes Dryer: Exhaust')
    clothes_dryer_exhaust.setUnits('cfm')
    clothes_dryer_exhaust.setDescription('Rated flow capacity of the clothes dryer exhaust. This fan is assumed to run after any clothes dryer events.')
    clothes_dryer_exhaust.setDefaultValue(100.0)
    args << clothes_dryer_exhaust

    # make a double argument for heating season setpoint offset
    nat_vent_htg_offset = OpenStudio::Measure::OSArgument::makeDoubleArgument('nat_vent_htg_offset', true)
    nat_vent_htg_offset.setDisplayName('Natural Ventilation: Heating Season Setpoint Offset')
    nat_vent_htg_offset.setUnits('degrees F')
    nat_vent_htg_offset.setDescription('The temperature offset below the hourly cooling setpoint, to which the living space is allowed to cool during months that are only in the heating season.')
    nat_vent_htg_offset.setDefaultValue(1.0)
    args << nat_vent_htg_offset

    # make a double argument for cooling season setpoint offset
    nat_vent_clg_offset = OpenStudio::Measure::OSArgument::makeDoubleArgument('nat_vent_clg_offset', true)
    nat_vent_clg_offset.setDisplayName('Natural Ventilation: Cooling Season Setpoint Offset')
    nat_vent_clg_offset.setUnits('degrees F')
    nat_vent_clg_offset.setDescription('The temperature offset above the hourly heating setpoint, to which the living space is allowed to cool during months that are only in the cooling season.')
    nat_vent_clg_offset.setDefaultValue(1.0)
    args << nat_vent_clg_offset

    # make a double argument for overlap season setpoint offset
    nat_vent_ovlp_offset = OpenStudio::Measure::OSArgument::makeDoubleArgument('nat_vent_ovlp_offset', true)
    nat_vent_ovlp_offset.setDisplayName('Natural Ventilation: Overlap Season Setpoint Offset')
    nat_vent_ovlp_offset.setUnits('degrees F')
    nat_vent_ovlp_offset.setDescription('The temperature offset above the maximum heating setpoint, to which the living space is allowed to cool during months that are in both the heating season and cooling season.')
    nat_vent_ovlp_offset.setDefaultValue(1.0)
    args << nat_vent_ovlp_offset

    # make a bool argument for heating season
    nat_vent_htg_season = OpenStudio::Measure::OSArgument::makeBoolArgument('nat_vent_htg_season', true)
    nat_vent_htg_season.setDisplayName('Natural Ventilation: Heating Season')
    nat_vent_htg_season.setDescription('True if windows are allowed to be opened during months that are only in the heating season.')
    nat_vent_htg_season.setDefaultValue(true)
    args << nat_vent_htg_season

    # make a bool argument for cooling season
    nat_vent_clg_season = OpenStudio::Measure::OSArgument::makeBoolArgument('nat_vent_clg_season', true)
    nat_vent_clg_season.setDisplayName('Natural Ventilation: Cooling Season')
    nat_vent_clg_season.setDescription('True if windows are allowed to be opened during months that are only in the cooling season.')
    nat_vent_clg_season.setDefaultValue(true)
    args << nat_vent_clg_season

    # make a bool argument for overlap season
    nat_vent_ovlp_season = OpenStudio::Measure::OSArgument::makeBoolArgument('nat_vent_ovlp_season', true)
    nat_vent_ovlp_season.setDisplayName('Natural Ventilation: Overlap Season')
    nat_vent_ovlp_season.setDescription('True if windows are allowed to be opened during months that are in both the heating season and cooling season.')
    nat_vent_ovlp_season.setDefaultValue(true)
    args << nat_vent_ovlp_season

    # make a double argument for number weekdays
    nat_vent_num_weekdays = OpenStudio::Measure::OSArgument::makeIntegerArgument('nat_vent_num_weekdays', true)
    nat_vent_num_weekdays.setDisplayName('Natural Ventilation: Number Weekdays')
    nat_vent_num_weekdays.setDescription('Number of weekdays in the week that natural ventilation can occur.')
    nat_vent_num_weekdays.setDefaultValue(3)
    args << nat_vent_num_weekdays

    # make a double argument for number weekend days
    nat_vent_num_weekends = OpenStudio::Measure::OSArgument::makeIntegerArgument('nat_vent_num_weekends', true)
    nat_vent_num_weekends.setDisplayName('Natural Ventilation: Number Weekend Days')
    nat_vent_num_weekends.setDescription('Number of weekend days in the week that natural ventilation can occur.')
    nat_vent_num_weekends.setDefaultValue(0)
    args << nat_vent_num_weekends

    # make a double argument for fraction of windows open
    nat_vent_frac_windows_open = OpenStudio::Measure::OSArgument::makeDoubleArgument('nat_vent_frac_windows_open', true)
    nat_vent_frac_windows_open.setDisplayName('Natural Ventilation: Fraction of Openable Windows Open')
    nat_vent_frac_windows_open.setUnits('frac')
    nat_vent_frac_windows_open.setDescription('Specifies the fraction of the total openable window area in the building that is opened for ventilation.')
    nat_vent_frac_windows_open.setDefaultValue(0.33)
    args << nat_vent_frac_windows_open

    # make a double argument for fraction of window area open
    nat_vent_frac_window_area_openable = OpenStudio::Measure::OSArgument::makeDoubleArgument('nat_vent_frac_window_area_openable', true)
    nat_vent_frac_window_area_openable.setDisplayName('Natural Ventilation: Fraction Window Area Openable')
    nat_vent_frac_window_area_openable.setUnits('frac')
    nat_vent_frac_window_area_openable.setDescription('Specifies the fraction of total window area in the home that can be opened (e.g. typical sliding windows can be opened to half of their area).')
    nat_vent_frac_window_area_openable.setDefaultValue(0.2)
    args << nat_vent_frac_window_area_openable

    # make a double argument for humidity ratio
    nat_vent_max_oa_hr = OpenStudio::Measure::OSArgument::makeDoubleArgument('nat_vent_max_oa_hr', true)
    nat_vent_max_oa_hr.setDisplayName('Natural Ventilation: Max OA Humidity Ratio')
    nat_vent_max_oa_hr.setUnits('frac')
    nat_vent_max_oa_hr.setDescription('Outdoor air humidity ratio above which windows will not open for natural ventilation.')
    nat_vent_max_oa_hr.setDefaultValue(0.0115)
    args << nat_vent_max_oa_hr

    # make a double argument for relative humidity ratio
    nat_vent_max_oa_rh = OpenStudio::Measure::OSArgument::makeDoubleArgument('nat_vent_max_oa_rh', true)
    nat_vent_max_oa_rh.setDisplayName('Natural Ventilation: Max OA Relative Humidity')
    nat_vent_max_oa_rh.setUnits('frac')
    nat_vent_max_oa_rh.setDescription('Outdoor air relative humidity (0-1) above which windows will not open for natural ventilation.')
    nat_vent_max_oa_rh.setDefaultValue(0.7)
    args << nat_vent_max_oa_rh

    # make a choice arguments for duct location
    location_args = OpenStudio::StringVector.new
    location_args << 'none'
    location_args << Constants.Auto
    Geometry.get_model_locations(model).each do |loc|
      location_args << loc
    end
    duct_location = OpenStudio::Measure::OSArgument::makeChoiceArgument('duct_location', location_args, true, true)
    duct_location.setDisplayName('Ducts: Location')
    duct_location.setDescription('The primary location of ducts.')
    duct_location.setDefaultValue(Constants.Auto)
    args << duct_location

    # make a double argument for total leakage
    duct_total_leakage = OpenStudio::Measure::OSArgument::makeDoubleArgument('duct_total_leakage', true)
    duct_total_leakage.setDisplayName('Ducts: Total Leakage')
    duct_total_leakage.setUnits('frac')
    duct_total_leakage.setDescription('The total amount of air flow leakage expressed as a fraction of the total air flow rate.')
    duct_total_leakage.setDefaultValue(0.3)
    args << duct_total_leakage

    # make a double argument for supply leakage fraction of total
    duct_supply_frac = OpenStudio::Measure::OSArgument::makeDoubleArgument('duct_supply_frac', true)
    duct_supply_frac.setDisplayName('Ducts: Supply Leakage Fraction of Total')
    duct_supply_frac.setUnits('frac')
    duct_supply_frac.setDescription('The amount of air flow leakage leaking out from the supply duct expressed as a fraction of the total duct leakage.')
    duct_supply_frac.setDefaultValue(0.6)
    args << duct_supply_frac

    # make a double argument for return leakage fraction of total
    duct_return_frac = OpenStudio::Measure::OSArgument::makeDoubleArgument('duct_return_frac', true)
    duct_return_frac.setDisplayName('Ducts: Return Leakage Fraction of Total')
    duct_return_frac.setUnits('frac')
    duct_return_frac.setDescription('The amount of air flow leakage leaking into the return duct expressed as a fraction of the total duct leakage.')
    duct_return_frac.setDefaultValue(0.067)
    args << duct_return_frac

    # make a double argument for supply AH leakage fraction of total
    duct_ah_supply_frac = OpenStudio::Measure::OSArgument::makeDoubleArgument('duct_ah_supply_frac', true)
    duct_ah_supply_frac.setDisplayName('Ducts: Supply Air Handler Leakage Fraction of Total')
    duct_ah_supply_frac.setUnits('frac')
    duct_ah_supply_frac.setDescription('The amount of air flow leakage leaking out from the supply-side of the air handler expressed as a fraction of the total duct leakage.')
    duct_ah_supply_frac.setDefaultValue(0.067)
    args << duct_ah_supply_frac

    # make a double argument for return AH leakage fraction of total
    duct_ah_return_frac = OpenStudio::Measure::OSArgument::makeDoubleArgument('duct_ah_return_frac', true)
    duct_ah_return_frac.setDisplayName('Ducts: Return Air Handler Leakage Fraction of Total')
    duct_ah_return_frac.setUnits('frac')
    duct_ah_return_frac.setDescription('The amount of air flow leakage leaking out from the return-side of the air handler expressed as a fraction of the total duct leakage.')
    duct_ah_return_frac.setDefaultValue(0.267)
    args << duct_ah_return_frac

    # #make a string argument for norm leakage to outside
    # duct_norm_leakage_25pa = OpenStudio::Measure::OSArgument::makeStringArgument("duct_norm_leakage_25pa", true)
    # duct_norm_leakage_25pa.setDisplayName("Ducts: Leakage to Outside at 25Pa")
    # duct_norm_leakage_25pa.setUnits("cfm/100 ft^2 Finished Floor")
    # duct_norm_leakage_25pa.setDescription("Normalized leakage to the outside when tested at a pressure differential of 25 Pascals (0.1 inches w.g.) across the system.")
    # duct_norm_leakage_25pa.setDefaultValue("NA")
    # args << duct_norm_leakage_25pa

    # make a string argument for duct location frac
    duct_location_frac = OpenStudio::Measure::OSArgument::makeStringArgument('duct_location_frac', true)
    duct_location_frac.setDisplayName('Ducts: Location Fraction')
    duct_location_frac.setUnits('frac')
    duct_location_frac.setDescription('Fraction of supply ducts in the specified Duct Location; the remainder of supply ducts will be located in above-grade conditioned space.')
    duct_location_frac.setDefaultValue(Constants.Auto)
    args << duct_location_frac

    # make a string argument for duct num returns
    duct_num_returns = OpenStudio::Measure::OSArgument::makeStringArgument('duct_num_returns', true)
    duct_num_returns.setDisplayName('Ducts: Number of Returns')
    duct_num_returns.setUnits('#')
    duct_num_returns.setDescription('The number of duct returns.')
    duct_num_returns.setDefaultValue(Constants.Auto)
    args << duct_num_returns

    # make a double argument for supply surface area multiplier
    duct_supply_area_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('duct_supply_area_mult', true)
    duct_supply_area_mult.setDisplayName('Ducts: Supply Surface Area Multiplier')
    duct_supply_area_mult.setUnits('mult')
    duct_supply_area_mult.setDescription('Values specify a fraction of the Building America Benchmark supply duct surface area.')
    duct_supply_area_mult.setDefaultValue(1.0)
    args << duct_supply_area_mult

    # make a double argument for return surface area multiplier
    duct_return_area_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('duct_return_area_mult', true)
    duct_return_area_mult.setDisplayName('Ducts: Return Surface Area Multiplier')
    duct_return_area_mult.setUnits('mult')
    duct_return_area_mult.setDescription('Values specify a fraction of the Building America Benchmark return duct surface area.')
    duct_return_area_mult.setDefaultValue(1.0)
    args << duct_return_area_mult

    # make a double argument for duct unconditioned r value
    duct_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('duct_r', true)
    duct_r.setDisplayName('Ducts: Insulation Nominal R-Value')
    duct_r.setUnits('h-ft^2-R/Btu')
    duct_r.setDescription('The nominal R-value for duct insulation.')
    duct_r.setDefaultValue(0.0)
    args << duct_r

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Air leakage
    living_ach50 = runner.getDoubleArgumentValue('living_ach50', user_arguments)
    garage_ach50 = runner.getDoubleArgumentValue('garage_ach50', user_arguments)
    crawl_ach = runner.getDoubleArgumentValue('crawl_ach', user_arguments)
    pier_beam_ach = runner.getDoubleArgumentValue('pier_beam_ach', user_arguments)
    finished_basement_ach = runner.getDoubleArgumentValue('finished_basement_ach', user_arguments)
    unfinished_basement_ach = runner.getDoubleArgumentValue('unfinished_basement_ach', user_arguments)
    unfinished_attic_sla = runner.getDoubleArgumentValue('unfinished_attic_sla', user_arguments)
    shelter_coef = runner.getStringArgumentValue('shelter_coef', user_arguments)
    has_hvac_flue = false
    if model.getBuilding.additionalProperties.getFeatureAsBoolean('has_hvac_flue').is_initialized
      has_hvac_flue = model.getBuilding.additionalProperties.getFeatureAsBoolean('has_hvac_flue').get
    end
    has_water_heater_flue = false
    if model.getBuilding.additionalProperties.getFeatureAsBoolean('has_water_heater_flue').is_initialized
      has_water_heater_flue = model.getBuilding.additionalProperties.getFeatureAsBoolean('has_water_heater_flue').get
    end
    has_fireplace_chimney = false
    if model.getBuilding.additionalProperties.getFeatureAsBoolean('has_fireplace_chimney').is_initialized
      has_fireplace_chimney = model.getBuilding.additionalProperties.getFeatureAsBoolean('has_fireplace_chimney').get
    end
    terrain = runner.getStringArgumentValue('terrain', user_arguments)

    # Mechanical Ventilation
    mech_vent_type = runner.getStringArgumentValue('mech_vent_type', user_arguments)
    mech_vent_infil_credit = runner.getBoolArgumentValue('mech_vent_infil_credit', user_arguments)
    mech_vent_total_efficiency = runner.getDoubleArgumentValue('mech_vent_total_efficiency', user_arguments)
    mech_vent_sensible_efficiency = runner.getDoubleArgumentValue('mech_vent_sensible_efficiency', user_arguments)
    mech_vent_fan_power = runner.getDoubleArgumentValue('mech_vent_fan_power', user_arguments)
    mech_vent_frac_62_2 = runner.getDoubleArgumentValue('mech_vent_frac_62_2', user_arguments)
    mech_vent_ashrae_std = runner.getStringArgumentValue('mech_vent_ashrae_std', user_arguments)
    mech_vent_cfis_open_time = runner.getDoubleArgumentValue('mech_vent_cfis_open_time', user_arguments)
    mech_vent_cfis_airflow_frac = runner.getDoubleArgumentValue('mech_vent_cfis_airflow_frac', user_arguments)
    if mech_vent_type == Constants.VentTypeNone
      mech_vent_frac_62_2 = 0.0
      mech_vent_fan_power = 0.0
      mech_vent_total_efficiency = 0.0
      mech_vent_sensible_efficiency = 0.0
    end
    clothes_dryer_exhaust = runner.getDoubleArgumentValue('clothes_dryer_exhaust', user_arguments)
    range_exhaust = 100.0 # cfm per HSP
    range_exhaust_hour = runner.getIntegerArgumentValue('range_exhaust_hour', user_arguments)
    bathroom_exhaust = 50.0 # cfm per HSP
    bathroom_exhaust_hour = runner.getIntegerArgumentValue('bathroom_exhaust_hour', user_arguments)
    is_existing_home = runner.getBoolArgumentValue('is_existing_home', user_arguments)

    # Natural Ventilation
    nat_vent_htg_offset = runner.getDoubleArgumentValue('nat_vent_htg_offset', user_arguments)
    nat_vent_clg_offset = runner.getDoubleArgumentValue('nat_vent_clg_offset', user_arguments)
    nat_vent_ovlp_offset = runner.getDoubleArgumentValue('nat_vent_ovlp_offset', user_arguments)
    nat_vent_htg_season = runner.getBoolArgumentValue('nat_vent_htg_season', user_arguments)
    nat_vent_clg_season = runner.getBoolArgumentValue('nat_vent_clg_season', user_arguments)
    nat_vent_ovlp_season = runner.getBoolArgumentValue('nat_vent_ovlp_season', user_arguments)
    nat_vent_num_weekdays = runner.getIntegerArgumentValue('nat_vent_num_weekdays', user_arguments)
    nat_vent_num_weekends = runner.getIntegerArgumentValue('nat_vent_num_weekends', user_arguments)
    nat_vent_frac_windows_open = runner.getDoubleArgumentValue('nat_vent_frac_windows_open', user_arguments)
    nat_vent_frac_window_area_openable = runner.getDoubleArgumentValue('nat_vent_frac_window_area_openable', user_arguments)
    nat_vent_max_oa_hr = runner.getDoubleArgumentValue('nat_vent_max_oa_hr', user_arguments)
    nat_vent_max_oa_rh = runner.getDoubleArgumentValue('nat_vent_max_oa_rh', user_arguments)

    # Ducts
    duct_location = runner.getStringArgumentValue('duct_location', user_arguments)
    duct_total_leakage = runner.getDoubleArgumentValue('duct_total_leakage', user_arguments)
    duct_supply_frac = runner.getDoubleArgumentValue('duct_supply_frac', user_arguments)
    duct_return_frac = runner.getDoubleArgumentValue('duct_return_frac', user_arguments)
    duct_ah_supply_frac = runner.getDoubleArgumentValue('duct_ah_supply_frac', user_arguments)
    duct_ah_return_frac = runner.getDoubleArgumentValue('duct_ah_return_frac', user_arguments)
    # duct_norm_leakage_25pa = runner.getStringArgumentValue("duct_norm_leakage_25pa",user_arguments)
    duct_norm_leakage_25pa = 'NA'
    unless duct_norm_leakage_25pa == 'NA'
      duct_norm_leakage_25pa = duct_norm_leakage_25pa.to_f
    else
      duct_norm_leakage_25pa = nil
    end
    duct_location_frac = runner.getStringArgumentValue('duct_location_frac', user_arguments)
    duct_num_returns = runner.getStringArgumentValue('duct_num_returns', user_arguments)
    duct_supply_area_mult = runner.getDoubleArgumentValue('duct_supply_area_mult', user_arguments)
    duct_return_area_mult = runner.getDoubleArgumentValue('duct_return_area_mult', user_arguments)
    duct_r = runner.getDoubleArgumentValue('duct_r', user_arguments)

    Airflow.remove(model,
                   Constants.ObjectNameAirflow,
                   Constants.ObjectNameNaturalVentilation,
                   Constants.ObjectNameInfiltration,
                   Constants.ObjectNameDucts(''),
                   Constants.ObjectNameMechanicalVentilation)

    # Create the airflow objects
    has_flue_chimney = (has_hvac_flue || has_water_heater_flue || has_fireplace_chimney)
    infil = Infiltration.new(living_ach50, nil, shelter_coef, garage_ach50, crawl_ach, unfinished_attic_sla, nil, unfinished_basement_ach, finished_basement_ach, pier_beam_ach, has_flue_chimney, is_existing_home, terrain)
    mech_vent = MechanicalVentilation.new(mech_vent_type, mech_vent_infil_credit, mech_vent_total_efficiency, mech_vent_frac_62_2, nil, mech_vent_fan_power, mech_vent_sensible_efficiency, mech_vent_ashrae_std, clothes_dryer_exhaust, range_exhaust, range_exhaust_hour, bathroom_exhaust, bathroom_exhaust_hour)
    cfis = CFIS.new(mech_vent_cfis_open_time, mech_vent_cfis_airflow_frac)
    nat_vent = NaturalVentilation.new(nat_vent_htg_offset, nat_vent_clg_offset, nat_vent_ovlp_offset, nat_vent_htg_season, nat_vent_clg_season, nat_vent_ovlp_season, nat_vent_num_weekdays, nat_vent_num_weekends, nat_vent_frac_windows_open, nat_vent_frac_window_area_openable, nat_vent_max_oa_hr, nat_vent_max_oa_rh)
    ducts = Ducts.new(duct_total_leakage, duct_norm_leakage_25pa, duct_supply_area_mult, duct_return_area_mult, duct_r, duct_supply_frac, duct_return_frac, duct_ah_supply_frac, duct_ah_return_frac, duct_location_frac, duct_num_returns, duct_location)

    duct_systems = { ducts => model.getAirLoopHVACs }
    cfis_systems = { cfis => model.getAirLoopHVACs }

    if not Airflow.apply(model, runner, infil, mech_vent, nat_vent, duct_systems, cfis_systems)
      return false
    end

    return true
  end
end

# register the measure to be used by the application
ResidentialAirflow.new.registerWithApplication
