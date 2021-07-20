# frozen_string_literal: true

require_relative '../../HPXMLtoOpenStudio/resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require 'csv'
require_relative '../measure.rb'

class SimulationOutputReportTest < MiniTest::Test
  AnnualRows = [
    'Fuel Use: Electricity: Total (MBtu)',
    'Fuel Use: Electricity: Net (MBtu)',
    'Fuel Use: Natural Gas: Total (MBtu)',
    'Fuel Use: Fuel Oil: Total (MBtu)',
    'Fuel Use: Propane: Total (MBtu)',
    'Fuel Use: Wood Cord: Total (MBtu)',
    'Fuel Use: Wood Pellets: Total (MBtu)',
    'Fuel Use: Coal: Total (MBtu)',
    'End Use: Electricity: Heating (MBtu)',
    'End Use: Electricity: Heating Fans/Pumps (MBtu)',
    'End Use: Electricity: Cooling (MBtu)',
    'End Use: Electricity: Cooling Fans/Pumps (MBtu)',
    'End Use: Electricity: Hot Water (MBtu)',
    'End Use: Electricity: Hot Water Recirc Pump (MBtu)',
    'End Use: Electricity: Hot Water Solar Thermal Pump (MBtu)',
    'End Use: Electricity: Lighting Interior (MBtu)',
    'End Use: Electricity: Lighting Garage (MBtu)',
    'End Use: Electricity: Lighting Exterior (MBtu)',
    'End Use: Electricity: Mech Vent (MBtu)',
    'End Use: Electricity: Mech Vent Preheating (MBtu)',
    'End Use: Electricity: Mech Vent Precooling (MBtu)',
    'End Use: Electricity: Whole House Fan (MBtu)',
    'End Use: Electricity: Refrigerator (MBtu)',
    'End Use: Electricity: Freezer (MBtu)',
    'End Use: Electricity: Dehumidifier (MBtu)',
    'End Use: Electricity: Dishwasher (MBtu)',
    'End Use: Electricity: Clothes Washer (MBtu)',
    'End Use: Electricity: Clothes Dryer (MBtu)',
    'End Use: Electricity: Range/Oven (MBtu)',
    'End Use: Electricity: Ceiling Fan (MBtu)',
    'End Use: Electricity: Television (MBtu)',
    'End Use: Electricity: Plug Loads (MBtu)',
    'End Use: Electricity: Electric Vehicle Charging (MBtu)',
    'End Use: Electricity: Well Pump (MBtu)',
    'End Use: Electricity: Pool Heater (MBtu)',
    'End Use: Electricity: Pool Pump (MBtu)',
    'End Use: Electricity: Hot Tub Heater (MBtu)',
    'End Use: Electricity: Hot Tub Pump (MBtu)',
    'End Use: Electricity: PV (MBtu)',
    'End Use: Electricity: Generator (MBtu)',
    'End Use: Natural Gas: Heating (MBtu)',
    'End Use: Natural Gas: Hot Water (MBtu)',
    'End Use: Natural Gas: Clothes Dryer (MBtu)',
    'End Use: Natural Gas: Range/Oven (MBtu)',
    'End Use: Natural Gas: Pool Heater (MBtu)',
    'End Use: Natural Gas: Hot Tub Heater (MBtu)',
    'End Use: Natural Gas: Grill (MBtu)',
    'End Use: Natural Gas: Lighting (MBtu)',
    'End Use: Natural Gas: Fireplace (MBtu)',
    'End Use: Natural Gas: Mech Vent Preheating (MBtu)',
    'End Use: Natural Gas: Generator (MBtu)',
    'End Use: Fuel Oil: Heating (MBtu)',
    'End Use: Fuel Oil: Hot Water (MBtu)',
    'End Use: Fuel Oil: Clothes Dryer (MBtu)',
    'End Use: Fuel Oil: Range/Oven (MBtu)',
    'End Use: Fuel Oil: Grill (MBtu)',
    'End Use: Fuel Oil: Lighting (MBtu)',
    'End Use: Fuel Oil: Fireplace (MBtu)',
    'End Use: Fuel Oil: Mech Vent Preheating (MBtu)',
    'End Use: Fuel Oil: Generator (MBtu)',
    'End Use: Propane: Heating (MBtu)',
    'End Use: Propane: Hot Water (MBtu)',
    'End Use: Propane: Clothes Dryer (MBtu)',
    'End Use: Propane: Range/Oven (MBtu)',
    'End Use: Propane: Grill (MBtu)',
    'End Use: Propane: Lighting (MBtu)',
    'End Use: Propane: Fireplace (MBtu)',
    'End Use: Propane: Mech Vent Preheating (MBtu)',
    'End Use: Propane: Generator (MBtu)',
    'End Use: Wood Cord: Heating (MBtu)',
    'End Use: Wood Cord: Hot Water (MBtu)',
    'End Use: Wood Cord: Clothes Dryer (MBtu)',
    'End Use: Wood Cord: Range/Oven (MBtu)',
    'End Use: Wood Cord: Grill (MBtu)',
    'End Use: Wood Cord: Lighting (MBtu)',
    'End Use: Wood Cord: Fireplace (MBtu)',
    'End Use: Wood Cord: Mech Vent Preheating (MBtu)',
    'End Use: Wood Cord: Generator (MBtu)',
    'End Use: Wood Pellets: Heating (MBtu)',
    'End Use: Wood Pellets: Hot Water (MBtu)',
    'End Use: Wood Pellets: Clothes Dryer (MBtu)',
    'End Use: Wood Pellets: Range/Oven (MBtu)',
    'End Use: Wood Pellets: Grill (MBtu)',
    'End Use: Wood Pellets: Lighting (MBtu)',
    'End Use: Wood Pellets: Fireplace (MBtu)',
    'End Use: Wood Pellets: Mech Vent Preheating (MBtu)',
    'End Use: Wood Pellets: Generator (MBtu)',
    'End Use: Coal: Heating (MBtu)',
    'End Use: Coal: Hot Water (MBtu)',
    'End Use: Coal: Clothes Dryer (MBtu)',
    'End Use: Coal: Range/Oven (MBtu)',
    'End Use: Coal: Grill (MBtu)',
    'End Use: Coal: Lighting (MBtu)',
    'End Use: Coal: Fireplace (MBtu)',
    'End Use: Coal: Mech Vent Preheating (MBtu)',
    'End Use: Coal: Generator (MBtu)',
    'Load: Heating (MBtu)',
    'Load: Cooling (MBtu)',
    'Load: Hot Water: Delivered (MBtu)',
    'Load: Hot Water: Tank Losses (MBtu)',
    'Load: Hot Water: Desuperheater (MBtu)',
    'Load: Hot Water: Solar Thermal (MBtu)',
    'Unmet Load: Heating (MBtu)',
    'Unmet Load: Cooling (MBtu)',
    'Peak Electricity: Winter Total (W)',
    'Peak Electricity: Summer Total (W)',
    'Peak Load: Heating (kBtu)',
    'Peak Load: Cooling (kBtu)',
    'Component Load: Heating: Roofs (MBtu)',
    'Component Load: Heating: Ceilings (MBtu)',
    'Component Load: Heating: Walls (MBtu)',
    'Component Load: Heating: Rim Joists (MBtu)',
    'Component Load: Heating: Foundation Walls (MBtu)',
    'Component Load: Heating: Doors (MBtu)',
    'Component Load: Heating: Windows (MBtu)',
    'Component Load: Heating: Skylights (MBtu)',
    'Component Load: Heating: Floors (MBtu)',
    'Component Load: Heating: Slabs (MBtu)',
    'Component Load: Heating: Internal Mass (MBtu)',
    'Component Load: Heating: Infiltration (MBtu)',
    'Component Load: Heating: Natural Ventilation (MBtu)',
    'Component Load: Heating: Mechanical Ventilation (MBtu)',
    'Component Load: Heating: Whole House Fan (MBtu)',
    'Component Load: Heating: Ducts (MBtu)',
    'Component Load: Heating: Internal Gains (MBtu)',
    'Component Load: Cooling: Roofs (MBtu)',
    'Component Load: Cooling: Ceilings (MBtu)',
    'Component Load: Cooling: Walls (MBtu)',
    'Component Load: Cooling: Rim Joists (MBtu)',
    'Component Load: Cooling: Foundation Walls (MBtu)',
    'Component Load: Cooling: Doors (MBtu)',
    'Component Load: Cooling: Windows (MBtu)',
    'Component Load: Cooling: Skylights (MBtu)',
    'Component Load: Cooling: Floors (MBtu)',
    'Component Load: Cooling: Slabs (MBtu)',
    'Component Load: Cooling: Internal Mass (MBtu)',
    'Component Load: Cooling: Infiltration (MBtu)',
    'Component Load: Cooling: Natural Ventilation (MBtu)',
    'Component Load: Cooling: Mechanical Ventilation (MBtu)',
    'Component Load: Cooling: Whole House Fan (MBtu)',
    'Component Load: Cooling: Ducts (MBtu)',
    'Component Load: Cooling: Internal Gains (MBtu)',
    'Hot Water: Clothes Washer (gal)',
    'Hot Water: Dishwasher (gal)',
    'Hot Water: Fixtures (gal)',
    'Hot Water: Distribution Waste (gal)',
  ]

  TimeseriesColsFuels = [
    'Fuel Use: Electricity: Total',
    'Fuel Use: Natural Gas: Total',
    'Fuel Use: Fuel Oil: Total',
    'Fuel Use: Propane: Total',
    'Fuel Use: Wood Cord: Total',
    'Fuel Use: Wood Pellets: Total',
    'Fuel Use: Coal: Total',
  ]

  TimeseriesColsEndUses = [
    'End Use: Electricity: Heating',
    'End Use: Electricity: Heating Fans/Pumps',
    'End Use: Electricity: Cooling',
    'End Use: Electricity: Cooling Fans/Pumps',
    'End Use: Electricity: Hot Water',
    'End Use: Electricity: Hot Water Recirc Pump',
    'End Use: Electricity: Hot Water Solar Thermal Pump',
    'End Use: Electricity: Lighting Interior',
    'End Use: Electricity: Lighting Garage',
    'End Use: Electricity: Lighting Exterior',
    'End Use: Electricity: Mech Vent',
    'End Use: Electricity: Whole House Fan',
    'End Use: Electricity: Refrigerator',
    'End Use: Electricity: Freezer',
    'End Use: Electricity: Dehumidifier',
    'End Use: Electricity: Dishwasher',
    'End Use: Electricity: Clothes Washer',
    'End Use: Electricity: Clothes Dryer',
    'End Use: Electricity: Range/Oven',
    'End Use: Electricity: Ceiling Fan',
    'End Use: Electricity: Television',
    'End Use: Electricity: Plug Loads',
    'End Use: Electricity: Electric Vehicle Charging',
    'End Use: Electricity: Well Pump',
    'End Use: Electricity: Pool Heater',
    'End Use: Electricity: Pool Pump',
    'End Use: Electricity: Hot Tub Heater',
    'End Use: Electricity: Hot Tub Pump',
    'End Use: Electricity: PV',
    'End Use: Electricity: Generator',
    'End Use: Natural Gas: Heating',
    'End Use: Natural Gas: Hot Water',
    'End Use: Natural Gas: Clothes Dryer',
    'End Use: Natural Gas: Range/Oven',
    'End Use: Natural Gas: Pool Heater',
    'End Use: Natural Gas: Hot Tub Heater',
    'End Use: Natural Gas: Grill',
    'End Use: Natural Gas: Lighting',
    'End Use: Natural Gas: Fireplace',
    'End Use: Natural Gas: Generator',
    'End Use: Fuel Oil: Heating',
    'End Use: Fuel Oil: Hot Water',
    'End Use: Fuel Oil: Clothes Dryer',
    'End Use: Fuel Oil: Range/Oven',
    'End Use: Fuel Oil: Grill',
    'End Use: Fuel Oil: Lighting',
    'End Use: Fuel Oil: Fireplace',
    'End Use: Fuel Oil: Generator',
    'End Use: Propane: Heating',
    'End Use: Propane: Hot Water',
    'End Use: Propane: Clothes Dryer',
    'End Use: Propane: Range/Oven',
    'End Use: Propane: Grill',
    'End Use: Propane: Lighting',
    'End Use: Propane: Fireplace',
    'End Use: Propane: Generator',
    'End Use: Wood Cord: Heating',
    'End Use: Wood Cord: Hot Water',
    'End Use: Wood Cord: Clothes Dryer',
    'End Use: Wood Cord: Range/Oven',
    'End Use: Wood Cord: Grill',
    'End Use: Wood Cord: Lighting',
    'End Use: Wood Cord: Fireplace',
    'End Use: Wood Cord: Generator',
    'End Use: Wood Pellets: Heating',
    'End Use: Wood Pellets: Hot Water',
    'End Use: Wood Pellets: Clothes Dryer',
    'End Use: Wood Pellets: Range/Oven',
    'End Use: Wood Pellets: Grill',
    'End Use: Wood Pellets: Lighting',
    'End Use: Wood Pellets: Fireplace',
    'End Use: Wood Pellets: Generator',
    'End Use: Coal: Heating',
    'End Use: Coal: Hot Water',
    'End Use: Coal: Clothes Dryer',
    'End Use: Coal: Range/Oven',
    'End Use: Coal: Grill',
    'End Use: Coal: Lighting',
    'End Use: Coal: Fireplace',
    'End Use: Coal: Generator',
  ]

  TimeseriesColsWaterUses = [
    'Hot Water: Clothes Washer',
    'Hot Water: Dishwasher',
    'Hot Water: Fixtures',
    'Hot Water: Distribution Waste',
  ]

  TimeseriesColsTotalLoads = [
    'Load: Heating',
    'Load: Cooling',
    'Load: Hot Water: Delivered',
  ]

  TimeseriesColsComponentLoads = [
    'Component Load: Heating: Roofs',
    'Component Load: Heating: Ceilings',
    'Component Load: Heating: Walls',
    'Component Load: Heating: Rim Joists',
    'Component Load: Heating: Foundation Walls',
    'Component Load: Heating: Doors',
    'Component Load: Heating: Windows',
    'Component Load: Heating: Skylights',
    'Component Load: Heating: Floors',
    'Component Load: Heating: Slabs',
    'Component Load: Heating: Internal Mass',
    'Component Load: Heating: Infiltration',
    'Component Load: Heating: Natural Ventilation',
    'Component Load: Heating: Mechanical Ventilation',
    'Component Load: Heating: Whole House Fan',
    'Component Load: Heating: Ducts',
    'Component Load: Heating: Internal Gains',
    'Component Load: Cooling: Roofs',
    'Component Load: Cooling: Ceilings',
    'Component Load: Cooling: Walls',
    'Component Load: Cooling: Rim Joists',
    'Component Load: Cooling: Foundation Walls',
    'Component Load: Cooling: Doors',
    'Component Load: Cooling: Windows',
    'Component Load: Cooling: Skylights',
    'Component Load: Cooling: Floors',
    'Component Load: Cooling: Slabs',
    'Component Load: Cooling: Internal Mass',
    'Component Load: Cooling: Infiltration',
    'Component Load: Cooling: Natural Ventilation',
    'Component Load: Cooling: Mechanical Ventilation',
    'Component Load: Cooling: Whole House Fan',
    'Component Load: Cooling: Ducts',
    'Component Load: Cooling: Internal Gains',
  ]

  TimeseriesColsUnmetLoads = [
    'Unmet Load: Heating',
    'Unmet Load: Cooling',
  ]

  TimeseriesColsZoneTemps = [
    'Temperature: Attic - Unvented',
    'Temperature: Living Space',
  ]

  TimeseriesColsTempsOtherSide = [
    'Temperature: Other Multifamily Buffer Space',
    'Temperature: Other Non-freezing Space',
    'Temperature: Other Housing Unit',
    'Temperature: Other Heated Space'
  ]

  TimeseriesColsAirflows = [
    'Airflow: Infiltration',
    'Airflow: Mechanical Ventilation',
    'Airflow: Natural Ventilation',
    'Airflow: Whole House Fan',
  ]

  TimeseriesColsWeather = [
    'Weather: Drybulb Temperature',
    'Weather: Wetbulb Temperature',
    'Weather: Relative Humidity',
    'Weather: Wind Speed',
    'Weather: Diffuse Solar Radiation',
    'Weather: Direct Solar Radiation',
  ]

  ERIRows = [
    'hpxml_heat_sys_ids',
    'hpxml_cool_sys_ids',
    'hpxml_dhw_sys_ids',
    'hpxml_vent_preheat_sys_ids',
    'hpxml_vent_precool_sys_ids',
    'hpxml_eec_heats',
    'hpxml_eec_cools',
    'hpxml_eec_dhws',
    'hpxml_eec_vent_preheats',
    'hpxml_eec_vent_precools',
    'hpxml_heat_fuels',
    'hpxml_dwh_fuels',
    'hpxml_vent_preheat_fuels',
    'fuelElectricity',
    'fuelNaturalGas',
    'fuelFuelOil',
    'fuelPropane',
    'fuelWoodCord',
    'fuelWoodPellets',
    'fuelCoal',
    'enduseElectricityHeating',
    'enduseElectricityHeatingFansPumps',
    'enduseElectricityCooling',
    'enduseElectricityCoolingFansPumps',
    'enduseElectricityHotWater',
    'enduseElectricityHotWaterRecircPump',
    'enduseElectricityHotWaterSolarThermalPump',
    'enduseElectricityLightingInterior',
    'enduseElectricityLightingGarage',
    'enduseElectricityLightingExterior',
    'enduseElectricityMechVent',
    'enduseElectricityMechVentPreheating',
    'enduseElectricityMechVentPrecooling',
    'enduseElectricityWholeHouseFan',
    'enduseElectricityRefrigerator',
    'enduseElectricityDehumidifier',
    'enduseElectricityDishwasher',
    'enduseElectricityClothesWasher',
    'enduseElectricityClothesDryer',
    'enduseElectricityRangeOven',
    'enduseElectricityCeilingFan',
    'enduseElectricityTelevision',
    'enduseElectricityPlugLoads',
    'enduseElectricityPV',
    'enduseElectricityGenerator',
    'enduseNaturalGasHeating',
    'enduseNaturalGasHotWater',
    'enduseNaturalGasClothesDryer',
    'enduseNaturalGasRangeOven',
    'enduseNaturalGasMechVentPreheating',
    'enduseNaturalGasGenerator',
    'enduseFuelOilHeating',
    'enduseFuelOilHotWater',
    'enduseFuelOilClothesDryer',
    'enduseFuelOilRangeOven',
    'enduseFuelOilMechVentPreheating',
    'enduseFuelOilGenerator',
    'endusePropaneHeating',
    'endusePropaneHotWater',
    'endusePropaneClothesDryer',
    'endusePropaneRangeOven',
    'endusePropaneMechVentPreheating',
    'endusePropaneGenerator',
    'enduseWoodCordHeating',
    'enduseWoodCordHotWater',
    'enduseWoodCordClothesDryer',
    'enduseWoodCordRangeOven',
    'enduseWoodCordMechVentPreheating',
    'enduseWoodCordGenerator',
    'enduseWoodPelletsHeating',
    'enduseWoodPelletsHotWater',
    'enduseWoodPelletsClothesDryer',
    'enduseWoodPelletsRangeOven',
    'enduseWoodPelletsMechVentPreheating',
    'enduseWoodPelletsGenerator',
    'enduseCoalHeating',
    'enduseCoalHotWater',
    'enduseCoalClothesDryer',
    'enduseCoalRangeOven',
    'enduseCoalMechVentPreheating',
    'enduseCoalGenerator',
    'loadHeating',
    'loadCooling',
    'loadHotWaterDelivered',
    'hpxml_cfa',
    'hpxml_nbr',
    'hpxml_nst',
    'hpxml_residential_facility_type',
  ]

  def all_timeseries_cols
    return (TimeseriesColsFuels +
            TimeseriesColsEndUses +
            TimeseriesColsWaterUses +
            TimeseriesColsTotalLoads +
            TimeseriesColsComponentLoads +
            TimeseriesColsUnmetLoads +
            TimeseriesColsZoneTemps +
            TimeseriesColsAirflows +
            TimeseriesColsWeather)
  end

  def test_annual_only
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'add_component_loads' => true,
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(!File.exist?(timeseries_csv))
    expected_annual_rows = AnnualRows
    actual_annual_rows = File.readlines(annual_csv).map { |x| x.split(',')[0].strip }.select { |x| !x.empty? }
    assert_equal(expected_annual_rows.sort, actual_annual_rows.sort)
  end

  def test_annual_only2
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'add_component_loads' => true,
                  'timeseries_frequency' => 'none',
                  'include_timeseries_fuel_consumptions' => true,
                  'include_timeseries_end_use_consumptions' => true,
                  'include_timeseries_hot_water_uses' => true,
                  'include_timeseries_total_loads' => true,
                  'include_timeseries_component_loads' => true,
                  'include_timeseries_unmet_loads' => true,
                  'include_timeseries_zone_temperatures' => true,
                  'include_timeseries_airflows' => true,
                  'include_timeseries_weather' => true }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(!File.exist?(timeseries_csv))
    expected_annual_rows = AnnualRows
    actual_annual_rows = File.readlines(annual_csv).map { |x| x.split(',')[0].strip }.select { |x| !x.empty? }
    assert_equal(expected_annual_rows.sort, actual_annual_rows.sort)
  end

  def test_timeseries_hourly_fuels
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => true,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsFuels
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, ['Fuel Use: Electricity: Total'])
  end

  def test_timeseries_hourly_enduses
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => true,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsEndUses
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, ['End Use: Electricity: Plug Loads'])
  end

  def test_timeseries_hourly_hotwateruses
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => true,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsWaterUses
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, TimeseriesColsWaterUses)
  end

  def test_timeseries_hourly_total_loads
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => true,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsTotalLoads
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, TimeseriesColsTotalLoads)
  end

  def test_timeseries_hourly_component_loads
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'add_component_loads' => true,
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => true,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsComponentLoads
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, ['Component Load: Heating: Internal Gains', 'Component Load: Cooling: Internal Gains'])
  end

  def test_timeseries_hourly_unmet_loads
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-hvac-undersized.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => true,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsUnmetLoads
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, TimeseriesColsUnmetLoads)
  end

  def test_timeseries_hourly_zone_temperatures
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => true,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsZoneTemps
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, TimeseriesColsZoneTemps)
  end

  def test_timeseries_hourly_zone_temperatures_mf_space
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-bldgtype-multifamily-adjacent-to-multiple.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => true,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    TimeseriesColsTempsOtherSide.each do |expected_col|
      assert(actual_timeseries_cols.include? expected_col)
    end
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, TimeseriesColsTempsOtherSide)
  end

  def test_timeseries_hourly_airflows_with_exhaust_mechvent
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-mechvent-exhaust.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => true,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsAirflows
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, TimeseriesColsAirflows.select { |t| t != 'Airflow: Whole House Fan' })
  end

  def test_timeseries_hourly_airflows_with_whf
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-mechvent-whole-house-fan.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => true,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsAirflows
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, ['Airflow: Whole House Fan'])
  end

  def test_timeseries_hourly_airflows_with_clothes_dryer_exhaust
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-appliances-gas.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => true,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsAirflows
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, ['Airflow: Mechanical Ventilation'])
  end

  def test_timeseries_hourly_airflows_with_balanced_mechvent
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-mechvent-balanced.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => true,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsAirflows
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, ['Airflow: Mechanical Ventilation'])
  end

  def test_timeseries_hourly_airflows_with_cfis
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-mechvent-cfis.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => true,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsAirflows
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, ['Airflow: Mechanical Ventilation'])
  end

  def test_timeseries_hourly_weather
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => false,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => true }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + TimeseriesColsWeather
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_nonzero_timeseries_value(timeseries_csv, TimeseriesColsWeather)
  end

  def test_timeseries_hourly_ALL
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => true,
                  'include_timeseries_end_use_consumptions' => true,
                  'include_timeseries_hot_water_uses' => true,
                  'include_timeseries_total_loads' => true,
                  'include_timeseries_component_loads' => true,
                  'include_timeseries_unmet_loads' => true,
                  'include_timeseries_zone_temperatures' => true,
                  'include_timeseries_airflows' => true,
                  'include_timeseries_weather' => true }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + all_timeseries_cols
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
    _check_for_zero_baseload_timeseries_value(timeseries_csv, ['End Use: Electricity: Refrigerator'])
  end

  def test_timeseries_daily_ALL
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'timeseries_frequency' => 'daily',
                  'include_timeseries_fuel_consumptions' => true,
                  'include_timeseries_end_use_consumptions' => true,
                  'include_timeseries_hot_water_uses' => true,
                  'include_timeseries_total_loads' => true,
                  'include_timeseries_component_loads' => true,
                  'include_timeseries_unmet_loads' => true,
                  'include_timeseries_zone_temperatures' => true,
                  'include_timeseries_airflows' => true,
                  'include_timeseries_weather' => true }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + all_timeseries_cols
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(365, File.readlines(timeseries_csv).size - 2)
    _check_for_zero_baseload_timeseries_value(timeseries_csv, ['End Use: Electricity: Refrigerator'])
  end

  def test_timeseries_monthly_ALL
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'timeseries_frequency' => 'monthly',
                  'include_timeseries_fuel_consumptions' => true,
                  'include_timeseries_end_use_consumptions' => true,
                  'include_timeseries_hot_water_uses' => true,
                  'include_timeseries_total_loads' => true,
                  'include_timeseries_component_loads' => true,
                  'include_timeseries_unmet_loads' => true,
                  'include_timeseries_zone_temperatures' => true,
                  'include_timeseries_airflows' => true,
                  'include_timeseries_weather' => true }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    expected_timeseries_cols = ['Time'] + all_timeseries_cols
    actual_timeseries_cols = File.readlines(timeseries_csv)[0].strip.split(',')
    assert_equal(expected_timeseries_cols.sort, actual_timeseries_cols.sort)
    assert_equal(12, File.readlines(timeseries_csv).size - 2)
    _check_for_zero_baseload_timeseries_value(timeseries_csv, ['End Use: Electricity: Refrigerator'])
  end

  def test_timeseries_timestep
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base.xml',
                  'timeseries_frequency' => 'timestep',
                  'include_timeseries_fuel_consumptions' => true,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    assert_equal(8760, File.readlines(timeseries_csv).size - 2)
  end

  def test_timeseries_timestep_10min
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-simcontrol-timestep-10-mins.xml',
                  'timeseries_frequency' => 'timestep',
                  'include_timeseries_fuel_consumptions' => true,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    assert_equal(52560, File.readlines(timeseries_csv).size - 2)
  end

  def test_timeseries_hourly_runperiod_Jan
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-simcontrol-runperiod-1-month.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => true,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    assert_equal(31 * 24, File.readlines(timeseries_csv).size - 2)
  end

  def test_timeseries_daily_runperiod_Jan
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-simcontrol-runperiod-1-month.xml',
                  'timeseries_frequency' => 'daily',
                  'include_timeseries_fuel_consumptions' => true,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    assert_equal(31, File.readlines(timeseries_csv).size - 2)
  end

  def test_timeseries_monthly_runperiod_Jan
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-simcontrol-runperiod-1-month.xml',
                  'timeseries_frequency' => 'monthly',
                  'include_timeseries_fuel_consumptions' => true,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    assert_equal(1, File.readlines(timeseries_csv).size - 2)
  end

  def test_timeseries_timestep_runperiod_Jan
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-simcontrol-runperiod-1-month.xml',
                  'timeseries_frequency' => 'timestep',
                  'include_timeseries_fuel_consumptions' => true,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    assert_equal(31 * 24, File.readlines(timeseries_csv).size - 2)
  end

  def test_timeseries_hourly_AMY_2012
    args_hash = { 'hpxml_path' => '../workflow/sample_files/base-location-AMY-2012.xml',
                  'timeseries_frequency' => 'hourly',
                  'include_timeseries_fuel_consumptions' => true,
                  'include_timeseries_end_use_consumptions' => false,
                  'include_timeseries_hot_water_uses' => false,
                  'include_timeseries_total_loads' => false,
                  'include_timeseries_component_loads' => false,
                  'include_timeseries_unmet_loads' => false,
                  'include_timeseries_zone_temperatures' => false,
                  'include_timeseries_airflows' => false,
                  'include_timeseries_weather' => false }
    annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash)
    assert(File.exist?(annual_csv))
    assert(File.exist?(timeseries_csv))
    assert_equal(8784, File.readlines(timeseries_csv).size - 2)
  end

  def test_eri_designs
    # Create derivative HPXML file w/ ERI design type set
    require 'fileutils'
    require_relative '../../HPXMLtoOpenStudio/resources/xmlhelper.rb'
    require_relative '../../HPXMLtoOpenStudio/resources/constants.rb'
    require 'oga'
    old_hpxml_path = File.join(File.dirname(__FILE__), '../../workflow/sample_files/base.xml')
    [Constants.CalcTypeERIReferenceHome, Constants.CalcTypeERIReferenceHome].each do |eri_design|
      new_hpxml_path = File.join(File.dirname(__FILE__), '../../workflow/tests/test-eri.xml')
      FileUtils.cp(old_hpxml_path, new_hpxml_path)
      hpxml = HPXML.new(hpxml_path: new_hpxml_path)
      hpxml.header.eri_design = eri_design
      XMLHelper.write_file(hpxml.to_oga(), new_hpxml_path)

      # Run tests
      args_hash = { 'hpxml_path' => '../workflow/tests/test-eri.xml',
                    'timeseries_frequency' => 'hourly',
                    'include_timeseries_fuel_consumptions' => true,
                    'include_timeseries_end_use_consumptions' => true,
                    'include_timeseries_hot_water_uses' => true,
                    'include_timeseries_total_loads' => true,
                    'include_timeseries_component_loads' => true,
                    'include_timeseries_unmet_loads' => true,
                    'include_timeseries_zone_temperatures' => true,
                    'include_timeseries_airflows' => true,
                    'include_timeseries_weather' => true }
      annual_csv, timeseries_csv, eri_csv = _test_measure(args_hash, eri_design)
      assert(File.exist?(annual_csv))
      assert(File.exist?(timeseries_csv))
      assert(File.exist?(eri_csv))
      expected_eri_rows = ERIRows
      actual_eri_rows = File.readlines(eri_csv).map { |x| x.split(',')[0].strip }.select { |x| !x.empty? }
      assert_equal(expected_eri_rows.sort, actual_eri_rows.sort)

      # Cleanup
      File.delete(new_hpxml_path)
      File.delete(annual_csv)
      File.delete(timeseries_csv)
      File.delete(eri_csv)
    end
  end

  def _test_measure(args_hash, eri_design = nil)
    # Run measure via OSW
    require 'json'
    template_osw = File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'template.osw')
    workflow = OpenStudio::WorkflowJSON.new(template_osw)
    json = JSON.parse(workflow.to_s)

    # Update measure args
    steps = OpenStudio::WorkflowStepVector.new
    found_args = []
    json['steps'].each do |json_step|
      step = OpenStudio::MeasureStep.new(json_step['measure_dir_name'])
      json_step['arguments'].each do |json_arg_name, json_arg_val|
        if args_hash.keys.include? json_arg_name
          # Override value
          found_args << json_arg_name
          json_arg_val = args_hash[json_arg_name]
        end
        step.setArgument(json_arg_name, json_arg_val)
      end
      steps.push(step)
    end
    workflow.setWorkflowSteps(steps)
    osw_path = File.join(File.dirname(template_osw), 'test.osw')
    workflow.saveAs(osw_path)
    assert_equal(args_hash.size, found_args.size)

    # Run OSW
    success = system("#{OpenStudio.getOpenStudioCLI} run -w #{osw_path}")
    assert_equal(true, success)

    # Cleanup
    File.delete(osw_path)

    if not eri_design.nil?
      output_dir = File.dirname(File.join(File.dirname(__FILE__), '..', args_hash['hpxml_path']))
      hpxml_name = File.basename(args_hash['hpxml_path']).gsub('.xml', '')
      annual_csv = File.join(output_dir, "#{hpxml_name}.csv")
      timeseries_csv = File.join(output_dir, "#{hpxml_name}_Hourly.csv")
      eri_csv = File.join(output_dir, "#{hpxml_name}_ERI.csv")
    else
      annual_csv = File.join(File.dirname(template_osw), 'run', 'results_annual.csv')
      timeseries_csv = File.join(File.dirname(template_osw), 'run', 'results_timeseries.csv')
      eri_csv = nil
    end
    return annual_csv, timeseries_csv, eri_csv
  end

  def _check_for_nonzero_timeseries_value(timeseries_csv, timeseries_cols)
    values = {}
    timeseries_cols.each do |col|
      values[col] = []
    end
    CSV.foreach(timeseries_csv, headers: true) do |row|
      next if row['Time'].nil?

      timeseries_cols.each do |col|
        fail "Unexpected column: #{col}." if row[col].nil?

        values[col] << Float(row[col])
      end
    end
    timeseries_cols.each do |col|
      avg_value = values[col].sum(0.0) / values[col].size
      assert_operator(avg_value, :!=, 0)
    end
  end

  def _check_for_zero_baseload_timeseries_value(timeseries_csv, timeseries_cols)
    # check that every day has non zero values for baseload equipment (e.g., refrigerator)
    values = {}
    timeseries_cols.each do |col|
      values[col] = []
    end
    CSV.foreach(timeseries_csv, headers: true) do |row|
      next if row['Time'].nil?

      timeseries_cols.each do |col|
        fail "Unexpected column: #{col}." if row[col].nil?

        values[col] << Float(row[col])
      end
    end

    timeseries_cols.each do |col|
      has_no_zero_timeseries_value = !values[col].include?(0.0)
      assert(has_no_zero_timeseries_value)
    end
  end
end
