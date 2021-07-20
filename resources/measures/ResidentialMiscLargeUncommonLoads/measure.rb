# frozen_string_literal: true

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'misc_loads')

# start the measure
class ResidentialMiscLargeUncommonLoads < OpenStudio::Measure::ModelMeasure
  def name
    return 'Set Residential Large Uncommon Loads'
  end

  def description
    return "Adds (or replaces) the specified large, uncommon loads -- loads that have substantial energy consumption but are not found in most homes. For multifamily buildings, the loads can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Since there are no large, uncommon loads objects in OpenStudio/EnergyPlus, we look for ElectricEquipment/GasEquipment objects with the name that denotes it is a residential large, uncommon load. If one is found, it is replaced with the specified properties. Otherwise, a new such object is added to the model.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Has Loads

    # make a boolean argument for has fridge
    has_fridge = OpenStudio::Measure::OSArgument::makeBoolArgument('has_fridge', true)
    has_fridge.setDisplayName('Has Extra Refrigerator')
    has_fridge.setDescription('Specifies whether the building has an extra refrigerator.')
    has_fridge.setDefaultValue(false)
    args << has_fridge

    # make a boolean argument for has freezer
    has_freezer = OpenStudio::Measure::OSArgument::makeBoolArgument('has_freezer', true)
    has_freezer.setDisplayName('Has Freezer')
    has_freezer.setDescription('Specifies whether the building has a freezer.')
    has_freezer.setDefaultValue(false)
    args << has_freezer

    # make a boolean argument for has elec pool heater
    has_pool_heater_elec = OpenStudio::Measure::OSArgument::makeBoolArgument('has_pool_heater_elec', true)
    has_pool_heater_elec.setDisplayName('Has Pool Electric Heater')
    has_pool_heater_elec.setDescription('Specifies whether the building has an electric pool heater.')
    has_pool_heater_elec.setDefaultValue(false)
    args << has_pool_heater_elec

    # make a boolean argument for has gas pool heater
    has_pool_heater_gas = OpenStudio::Measure::OSArgument::makeBoolArgument('has_pool_heater_gas', true)
    has_pool_heater_gas.setDisplayName('Has Pool Gas Heater')
    has_pool_heater_gas.setDescription('Specifies whether the building has a gas pool heater.')
    has_pool_heater_gas.setDefaultValue(false)
    args << has_pool_heater_gas

    # make a boolean argument for has pool pump
    has_pool_pump = OpenStudio::Measure::OSArgument::makeBoolArgument('has_pool_pump', true)
    has_pool_pump.setDisplayName('Has Pool Pump')
    has_pool_pump.setDescription('Specifies whether the building has a pool pump.')
    has_pool_pump.setDefaultValue(false)
    args << has_pool_pump

    # make a boolean argument for has elec hot tub heater
    has_hot_tub_heater_elec = OpenStudio::Measure::OSArgument::makeBoolArgument('has_hot_tub_heater_elec', true)
    has_hot_tub_heater_elec.setDisplayName('Has Hot Tub Electric Heater')
    has_hot_tub_heater_elec.setDescription('Specifies whether the building has an electric hot tub heater.')
    has_hot_tub_heater_elec.setDefaultValue(false)
    args << has_hot_tub_heater_elec

    # make a boolean argument for has gas hot tub heater
    has_hot_tub_heater_gas = OpenStudio::Measure::OSArgument::makeBoolArgument('has_hot_tub_heater_gas', true)
    has_hot_tub_heater_gas.setDisplayName('Has Hot Tub Gas Heater')
    has_hot_tub_heater_gas.setDescription('Specifies whether the building has a gas hot tub heater.')
    has_hot_tub_heater_gas.setDefaultValue(false)
    args << has_hot_tub_heater_gas

    # make a boolean argument for has hot tub pump
    has_hot_tub_pump = OpenStudio::Measure::OSArgument::makeBoolArgument('has_hot_tub_pump', true)
    has_hot_tub_pump.setDisplayName('Has Hot Tub Pump')
    has_hot_tub_pump.setDescription('Specifies whether the building has a hot tub pump.')
    has_hot_tub_pump.setDefaultValue(false)
    args << has_hot_tub_pump

    # make a boolean argument for has well pump
    has_well_pump = OpenStudio::Measure::OSArgument::makeBoolArgument('has_well_pump', true)
    has_well_pump.setDisplayName('Has Well Pump')
    has_well_pump.setDescription('Specifies whether the building has a well pump.')
    has_well_pump.setDefaultValue(false)
    args << has_well_pump

    # make a boolean argument for has gas fireplace
    has_gas_fireplace = OpenStudio::Measure::OSArgument::makeBoolArgument('has_gas_fireplace', true)
    has_gas_fireplace.setDisplayName('Has Gas Fireplace')
    has_gas_fireplace.setDescription('Specifies whether the building has a gas fireplace.')
    has_gas_fireplace.setDefaultValue(false)
    args << has_gas_fireplace

    # make a boolean argument for has gas grill
    has_gas_grill = OpenStudio::Measure::OSArgument::makeBoolArgument('has_gas_grill', true)
    has_gas_grill.setDisplayName('Has Gas grill')
    has_gas_grill.setDescription('Specifies whether the building has a gas grill.')
    has_gas_grill.setDefaultValue(false)
    args << has_gas_grill

    # make a boolean argument for has gas lighting
    has_gas_lighting = OpenStudio::Measure::OSArgument::makeBoolArgument('has_gas_lighting', true)
    has_gas_lighting.setDisplayName('Has Gas lighting')
    has_gas_lighting.setDescription('Specifies whether the building has a gas lighting.')
    has_gas_lighting.setDefaultValue(false)
    args << has_gas_lighting

    # Make a boolean argument for has electric vehicle
    has_electric_vehicle = OpenStudio::Measure::OSArgument::makeBoolArgument('has_electric_vehicle', true)
    has_electric_vehicle.setDisplayName('Has Electric Vehicle')
    has_electric_vehicle.setDescription('Specifies whether the building has an electric vehicle.')
    has_electric_vehicle.setDefaultValue(false)
    args << has_electric_vehicle

    # Extra Refrigerator

    # make a double argument for user defined fridge options
    fridge_rated_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('fridge_rated_annual_energy', true)
    fridge_rated_annual_energy.setDisplayName('Extra Refrigerator: Rated Annual Consumption')
    fridge_rated_annual_energy.setUnits('kWh/yr')
    fridge_rated_annual_energy.setDescription('The EnergyGuide rated annual energy consumption for a refrigerator.')
    fridge_rated_annual_energy.setDefaultValue(1102)
    args << fridge_rated_annual_energy

    # make a double argument for Energy Multiplier
    fridge_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('fridge_mult')
    fridge_mult.setDisplayName('Extra Refrigerator: Energy Multiplier')
    fridge_mult.setDescription('Appliance energy use is multiplied by this factor to account for occupancy usage that differs from the national average.')
    fridge_mult.setDefaultValue(1)
    args << fridge_mult

    # Make a string argument for 24 weekday schedule values
    fridge_weekday_sch = OpenStudio::Measure::OSArgument::makeStringArgument('fridge_weekday_sch')
    fridge_weekday_sch.setDisplayName('Extra Refrigerator: Weekday schedule')
    fridge_weekday_sch.setDescription('Specify the 24-hour weekday schedule.')
    fridge_weekday_sch.setDefaultValue('0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041')
    args << fridge_weekday_sch

    # Make a string argument for 24 weekend schedule values
    fridge_weekend_sch = OpenStudio::Measure::OSArgument::makeStringArgument('fridge_weekend_sch')
    fridge_weekend_sch.setDisplayName('Extra Refrigerator: Weekend schedule')
    fridge_weekend_sch.setDescription('Specify the 24-hour weekend schedule.')
    fridge_weekend_sch.setDefaultValue('0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041')
    args << fridge_weekend_sch

    # Make a string argument for 12 monthly schedule values
    fridge_monthly_sch = OpenStudio::Measure::OSArgument::makeStringArgument('fridge_monthly_sch')
    fridge_monthly_sch.setDisplayName('Extra Refrigerator: Month schedule')
    fridge_monthly_sch.setDescription('Specify the 12-month schedule.')
    fridge_monthly_sch.setDefaultValue('0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837')
    args << fridge_monthly_sch

    # make a choice argument for location
    fridge_location_args = OpenStudio::StringVector.new
    fridge_location_args << Constants.Auto
    Geometry.get_model_locations(model).each do |loc|
      fridge_location_args << loc
    end
    fridge_location = OpenStudio::Measure::OSArgument::makeChoiceArgument('fridge_location', fridge_location_args, true, true)
    fridge_location.setDisplayName('Extra Refrigerator: Location')
    fridge_location.setDescription("The space type for the location. '#{Constants.Auto}' will automatically choose a space type based on the space types found in the model.")
    fridge_location.setDefaultValue(Constants.Auto)
    args << fridge_location

    # Freezer

    # make a double argument for user defined freezer options
    freezer_rated_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('freezer_rated_annual_energy', true)
    freezer_rated_annual_energy.setDisplayName('Freezer: Rated Annual Consumption')
    freezer_rated_annual_energy.setUnits('kWh/yr')
    freezer_rated_annual_energy.setDescription('The EnergyGuide rated annual energy consumption for a freezer.')
    freezer_rated_annual_energy.setDefaultValue(935)
    args << freezer_rated_annual_energy

    # make a double argument for Energy Multiplier
    freezer_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('freezer_mult')
    freezer_mult.setDisplayName('Freezer: Energy Multiplier')
    freezer_mult.setDescription('Appliance energy use is multiplied by this factor to account for occupancy usage that differs from the national average.')
    freezer_mult.setDefaultValue(1)
    args << freezer_mult

    # Make a string argument for 24 weekday schedule values
    freezer_weekday_sch = OpenStudio::Measure::OSArgument::makeStringArgument('freezer_weekday_sch')
    freezer_weekday_sch.setDisplayName('Freezer: Weekday schedule')
    freezer_weekday_sch.setDescription('Specify the 24-hour weekday schedule.')
    freezer_weekday_sch.setDefaultValue('0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041')
    args << freezer_weekday_sch

    # Make a string argument for 24 weekend schedule values
    freezer_weekend_sch = OpenStudio::Measure::OSArgument::makeStringArgument('freezer_weekend_sch')
    freezer_weekend_sch.setDisplayName('Freezer: Weekend schedule')
    freezer_weekend_sch.setDescription('Specify the 24-hour weekend schedule.')
    freezer_weekend_sch.setDefaultValue('0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041')
    args << freezer_weekend_sch

    # Make a string argument for 12 monthly schedule values
    freezer_monthly_sch = OpenStudio::Measure::OSArgument::makeStringArgument('freezer_monthly_sch')
    freezer_monthly_sch.setDisplayName('Freezer: Month schedule')
    freezer_monthly_sch.setDescription('Specify the 12-month schedule.')
    freezer_monthly_sch.setDefaultValue('0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837')
    args << freezer_monthly_sch

    # make a choice argument for location
    freezer_location_args = OpenStudio::StringVector.new
    freezer_location_args << Constants.Auto
    Geometry.get_model_locations(model).each do |loc|
      freezer_location_args << loc
    end
    freezer_location = OpenStudio::Measure::OSArgument::makeChoiceArgument('freezer_location', freezer_location_args, true, true)
    freezer_location.setDisplayName('Freezer: Location')
    freezer_location.setDescription("The space type for the location. '#{Constants.Auto}' will automatically choose a space type based on the space types found in the model.")
    freezer_location.setDefaultValue(Constants.Auto)
    args << freezer_location

    # Pool

    # make a double argument for Elec Heater Annual Energy Use
    pool_heater_elec_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_heater_elec_annual_energy')
    pool_heater_elec_annual_energy.setDisplayName('Pool: Electric Heater Annual Energy Use')
    pool_heater_elec_annual_energy.setUnits('kWh/yr')
    pool_heater_elec_annual_energy.setDescription('The annual energy use for the electric heater (defaults to national average).')
    pool_heater_elec_annual_energy.setDefaultValue(2300)
    args << pool_heater_elec_annual_energy

    # make a double argument for Energy Multiplier
    pool_heater_elec_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_heater_elec_mult')
    pool_heater_elec_mult.setDisplayName('Pool: Electric Heater Energy Multiplier')
    pool_heater_elec_mult.setDescription('Sets the annual energy use equal to the annual energy use times this multiplier.')
    pool_heater_elec_mult.setDefaultValue(1)
    args << pool_heater_elec_mult

    # make a double argument for Gas Heater Annual Energy Use
    pool_heater_gas_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_heater_gas_annual_energy')
    pool_heater_gas_annual_energy.setDisplayName('Pool: Gas Heater Annual Energy Use')
    pool_heater_gas_annual_energy.setUnits('therm/yr')
    pool_heater_gas_annual_energy.setDescription('The annual energy use for the gas heater (defaults to national average).')
    pool_heater_gas_annual_energy.setDefaultValue(222)
    args << pool_heater_gas_annual_energy

    # make a double argument for Energy Multiplier
    pool_heater_gas_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_heater_gas_mult')
    pool_heater_gas_mult.setDisplayName('Pool: Gas Heater Energy Multiplier')
    pool_heater_gas_mult.setDescription('Sets the annual energy use equal to the annual energy use times this multiplier.')
    pool_heater_gas_mult.setDefaultValue(1)
    args << pool_heater_gas_mult

    # make a double argument for Pump Annual Energy Use
    pool_pump_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_pump_annual_energy')
    pool_pump_annual_energy.setDisplayName('Pool: Pump Annual Energy Use')
    pool_pump_annual_energy.setUnits('kWh/yr')
    pool_pump_annual_energy.setDescription('The annual energy use for the pump (defaults to national average).')
    pool_pump_annual_energy.setDefaultValue(2250)
    args << pool_pump_annual_energy

    # make a double argument for Energy Multiplier
    pool_pump_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_pump_mult')
    pool_pump_mult.setDisplayName('Pool: Pump Energy Multiplier')
    pool_pump_mult.setDescription('Sets the annual energy use equal to the annual energy use times this multiplier.')
    pool_pump_mult.setDefaultValue(1)
    args << pool_pump_mult

    # make a boolean argument for Scale Energy Use
    pool_scale_energy = OpenStudio::Measure::OSArgument::makeBoolArgument('pool_scale_energy', true)
    pool_scale_energy.setDisplayName('Pool: Scale Energy Use')
    pool_scale_energy.setDescription('If true, scales the energy use relative to a 3-bedroom, 1920 sqft house using the following equation: Fscale = (0.5 + 0.25 x Nbr/3 + 0.25 x FFA/1920) where Nbr is the number of bedrooms and FFA is the finished floor area.')
    pool_scale_energy.setDefaultValue(true)
    args << pool_scale_energy

    # Make a string argument for 24 weekday schedule values
    pool_weekday_sch = OpenStudio::Measure::OSArgument::makeStringArgument('pool_weekday_sch')
    pool_weekday_sch.setDisplayName('Pool: Weekday schedule')
    pool_weekday_sch.setDescription('Specify the 24-hour weekday schedule.')
    pool_weekday_sch.setDefaultValue('0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003')
    args << pool_weekday_sch

    # Make a string argument for 24 weekend schedule values
    pool_weekend_sch = OpenStudio::Measure::OSArgument::makeStringArgument('pool_weekend_sch')
    pool_weekend_sch.setDisplayName('Pool: Weekend schedule')
    pool_weekend_sch.setDescription('Specify the 24-hour weekend schedule.')
    pool_weekend_sch.setDefaultValue('0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003')
    args << pool_weekend_sch

    # Make a string argument for 12 monthly schedule values
    pool_monthly_sch = OpenStudio::Measure::OSArgument::makeStringArgument('pool_monthly_sch')
    pool_monthly_sch.setDisplayName('Pool: Month schedule')
    pool_monthly_sch.setDescription('Specify the 12-month schedule.')
    pool_monthly_sch.setDefaultValue('1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154')
    args << pool_monthly_sch

    # Hot Tub/Spa

    # make a double argument for Elec Heater Annual Energy Use
    hot_tub_heater_elec_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_heater_elec_annual_energy')
    hot_tub_heater_elec_annual_energy.setDisplayName('Hot Tub: Electric Heater Annual Energy Use')
    hot_tub_heater_elec_annual_energy.setUnits('kWh/yr')
    hot_tub_heater_elec_annual_energy.setDescription('The annual energy use for the electric heater (defaults to national average).')
    hot_tub_heater_elec_annual_energy.setDefaultValue(1027.3)
    args << hot_tub_heater_elec_annual_energy

    # make a double argument for Energy Multiplier
    hot_tub_heater_elec_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_heater_elec_mult')
    hot_tub_heater_elec_mult.setDisplayName('Hot Tub: Electric Heater Energy Multiplier')
    hot_tub_heater_elec_mult.setDescription('Sets the annual energy use equal to the annual energy use times this multiplier.')
    hot_tub_heater_elec_mult.setDefaultValue(1)
    args << hot_tub_heater_elec_mult

    # make a double argument for Gas Heater Annual Energy Use
    hot_tub_heater_gas_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_heater_gas_annual_energy')
    hot_tub_heater_gas_annual_energy.setDisplayName('Hot Tub: Gas Heater Annual Energy Use')
    hot_tub_heater_gas_annual_energy.setUnits('therm/yr')
    hot_tub_heater_gas_annual_energy.setDescription('The annual energy use for the gas heater (defaults to national average).')
    hot_tub_heater_gas_annual_energy.setDefaultValue(81)
    args << hot_tub_heater_gas_annual_energy

    # make a double argument for Energy Multiplier
    hot_tub_heater_gas_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_heater_gas_mult')
    hot_tub_heater_gas_mult.setDisplayName('Hot Tub: Gas Heater Energy Multiplier')
    hot_tub_heater_gas_mult.setDescription('Sets the annual energy use equal to the annual energy use times this multiplier.')
    hot_tub_heater_gas_mult.setDefaultValue(1)
    args << hot_tub_heater_gas_mult

    # make a double argument for Pump Annual Energy Use
    hot_tub_pump_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_pump_annual_energy')
    hot_tub_pump_annual_energy.setDisplayName('Hot Tub: Pump Annual Energy Use')
    hot_tub_pump_annual_energy.setUnits('kWh/yr')
    hot_tub_pump_annual_energy.setDescription('The annual energy use for the pump (defaults to national average).')
    hot_tub_pump_annual_energy.setDefaultValue(1014.1)
    args << hot_tub_pump_annual_energy

    # make a double argument for Energy Multiplier
    hot_tub_pump_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_pump_mult')
    hot_tub_pump_mult.setDisplayName('Hot Tub: Pump Energy Multiplier')
    hot_tub_pump_mult.setDescription('Sets the annual energy use equal to the annual energy use times this multiplier.')
    hot_tub_pump_mult.setDefaultValue(1)
    args << hot_tub_pump_mult

    # make a boolean argument for Scale Energy Use
    hot_tub_scale_energy = OpenStudio::Measure::OSArgument::makeBoolArgument('hot_tub_scale_energy', true)
    hot_tub_scale_energy.setDisplayName('Hot Tub: Scale Energy Use')
    hot_tub_scale_energy.setDescription('If true, scales the energy use relative to a 3-bedroom, 1920 sqft house using the following equation: Fscale = (0.5 + 0.25 x Nbr/3 + 0.25 x FFA/1920) where Nbr is the number of bedrooms and FFA is the finished floor area.')
    hot_tub_scale_energy.setDefaultValue(true)
    args << hot_tub_scale_energy

    # Make a string argument for 24 weekday schedule values
    hot_tub_weekday_sch = OpenStudio::Measure::OSArgument::makeStringArgument('hot_tub_weekday_sch')
    hot_tub_weekday_sch.setDisplayName('Hot Tub: Weekday schedule')
    hot_tub_weekday_sch.setDescription('Specify the 24-hour weekday schedule.')
    hot_tub_weekday_sch.setDefaultValue('0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024')
    args << hot_tub_weekday_sch

    # Make a string argument for 24 weekend schedule values
    hot_tub_weekend_sch = OpenStudio::Measure::OSArgument::makeStringArgument('hot_tub_weekend_sch')
    hot_tub_weekend_sch.setDisplayName('Hot Tub: Weekend schedule')
    hot_tub_weekend_sch.setDescription('Specify the 24-hour weekend schedule.')
    hot_tub_weekend_sch.setDefaultValue('0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024')
    args << hot_tub_weekend_sch

    # Make a string argument for 12 monthly schedule values
    hot_tub_monthly_sch = OpenStudio::Measure::OSArgument::makeStringArgument('hot_tub_monthly_sch')
    hot_tub_monthly_sch.setDisplayName('Hot Tub: Month schedule')
    hot_tub_monthly_sch.setDescription('Specify the 12-month schedule.')
    hot_tub_monthly_sch.setDefaultValue('0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837')
    args << hot_tub_monthly_sch

    # Well Pump

    # make a double argument for Annual Energy Use
    well_pump_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('well_pump_annual_energy')
    well_pump_annual_energy.setDisplayName('Well Pump: Annual Energy Use')
    well_pump_annual_energy.setUnits('kWh/yr')
    well_pump_annual_energy.setDescription('The annual energy use for the well pump (defaults to national average).')
    well_pump_annual_energy.setDefaultValue(400)
    args << well_pump_annual_energy

    # make a double argument for Energy Multiplier
    well_pump_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('well_pump_mult')
    well_pump_mult.setDisplayName('Well Pump: Energy Multiplier')
    well_pump_mult.setDescription('Sets the annual energy use equal to the annual energy use times this multiplier.')
    well_pump_mult.setDefaultValue(1)
    args << well_pump_mult

    # make a boolean argument for Scale Energy Use
    well_pump_scale_energy = OpenStudio::Measure::OSArgument::makeBoolArgument('well_pump_scale_energy', true)
    well_pump_scale_energy.setDisplayName('Well Pump: Scale Energy Use')
    well_pump_scale_energy.setDescription('If true, scales the energy use relative to a 3-bedroom, 1920 sqft house using the following equation: Fscale = (0.5 + 0.25 x Nbr/3 + 0.25 x FFA/1920) where Nbr is the number of bedrooms and FFA is the finished floor area.')
    well_pump_scale_energy.setDefaultValue(true)
    args << well_pump_scale_energy

    # Gas Fireplace

    # make a double argument for Annual Energy Use
    gas_fireplace_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('gas_fireplace_annual_energy')
    gas_fireplace_annual_energy.setDisplayName('Gas Fireplace: Annual Energy Use')
    gas_fireplace_annual_energy.setUnits('therm/yr')
    gas_fireplace_annual_energy.setDescription('The annual energy use for the gas fireplace (defaults to national average).')
    gas_fireplace_annual_energy.setDefaultValue(60)
    args << gas_fireplace_annual_energy

    # make a double argument for Energy Multiplier
    gas_fireplace_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('gas_fireplace_mult')
    gas_fireplace_mult.setDisplayName('Gas Fireplace: Energy Multiplier')
    gas_fireplace_mult.setDescription('Sets the annual energy use equal to the annual energy use times this multiplier.')
    gas_fireplace_mult.setDefaultValue(1)
    args << gas_fireplace_mult

    # make a boolean argument for Scale Energy Use
    gas_fireplace_scale_energy = OpenStudio::Measure::OSArgument::makeBoolArgument('gas_fireplace_scale_energy', true)
    gas_fireplace_scale_energy.setDisplayName('Gas Fireplace: Scale Energy Use')
    gas_fireplace_scale_energy.setDescription('If true, scales the energy use relative to a 3-bedroom, 1920 sqft house using the following equation: Fscale = (0.5 + 0.25 x Nbr/3 + 0.25 x FFA/1920) where Nbr is the number of bedrooms and FFA is the finished floor area.')
    gas_fireplace_scale_energy.setDefaultValue(true)
    args << gas_fireplace_scale_energy

    # make a choice argument for location
    gas_fireplace_location_args = OpenStudio::StringVector.new
    gas_fireplace_location_args << Constants.Auto
    Geometry.get_model_locations(model).each do |loc|
      gas_fireplace_location_args << loc
    end
    gas_fireplace_location = OpenStudio::Measure::OSArgument::makeChoiceArgument('gas_fireplace_location', gas_fireplace_location_args, true, true)
    gas_fireplace_location.setDisplayName('Gas Fireplace: Location')
    gas_fireplace_location.setDescription("The space type for the location. '#{Constants.Auto}' will automatically choose a space type based on the space types found in the model.")
    gas_fireplace_location.setDefaultValue(Constants.Auto)
    args << gas_fireplace_location

    # make a bool argument for open fireplace chimney
    has_fireplace_chimney = OpenStudio::Measure::OSArgument::makeBoolArgument('has_fireplace_chimney', true)
    has_fireplace_chimney.setDisplayName('Air Leakage: Has Open HVAC Flue')
    has_fireplace_chimney.setDescription('Specifies whether the building has an open chimney associated with a fireplace.')
    has_fireplace_chimney.setDefaultValue(false)
    args << has_fireplace_chimney

    # Gas Grill

    # make a double argument for Annual Energy Use
    gas_grill_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('gas_grill_annual_energy')
    gas_grill_annual_energy.setDisplayName('Gas Grill: Annual Energy Use')
    gas_grill_annual_energy.setUnits('therm/yr')
    gas_grill_annual_energy.setDescription('The annual energy use for the gas grill (defaults to national average).')
    gas_grill_annual_energy.setDefaultValue(30)
    args << gas_grill_annual_energy

    # make a double argument for Energy Multiplier
    gas_grill_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('gas_grill_mult')
    gas_grill_mult.setDisplayName('Gas Grill: Energy Multiplier')
    gas_grill_mult.setDescription('Sets the annual energy use equal to the annual energy use times this multiplier.')
    gas_grill_mult.setDefaultValue(1)
    args << gas_grill_mult

    # make a boolean argument for Scale Energy Use
    gas_grill_scale_energy = OpenStudio::Measure::OSArgument::makeBoolArgument('gas_grill_scale_energy', true)
    gas_grill_scale_energy.setDisplayName('Gas Grill: Scale Energy Use')
    gas_grill_scale_energy.setDescription('If true, scales the energy use relative to a 3-bedroom, 1920 sqft house using the following equation: Fscale = (0.5 + 0.25 x Nbr/3 + 0.25 x FFA/1920) where Nbr is the number of bedrooms and FFA is the finished floor area.')
    gas_grill_scale_energy.setDefaultValue(true)
    args << gas_grill_scale_energy

    # Gas Lighting

    # make a double argument for Annual Energy Use
    gas_lighting_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('gas_lighting_annual_energy')
    gas_lighting_annual_energy.setDisplayName('Gas Lighting: Annual Energy Use')
    gas_lighting_annual_energy.setUnits('therm/yr')
    gas_lighting_annual_energy.setDescription('The annual energy use for the gas lighting (defaults to national average).')
    gas_lighting_annual_energy.setDefaultValue(19)
    args << gas_lighting_annual_energy

    # make a double argument for Energy Multiplier
    gas_lighting_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('gas_lighting_mult')
    gas_lighting_mult.setDisplayName('Gas Lighting: Energy Multiplier')
    gas_lighting_mult.setDescription('Sets the annual energy use equal to the annual energy use times this multiplier.')
    gas_lighting_mult.setDefaultValue(1)
    args << gas_lighting_mult

    # make a boolean argument for Scale Energy Use
    gas_lighting_scale_energy = OpenStudio::Measure::OSArgument::makeBoolArgument('gas_lighting_scale_energy', true)
    gas_lighting_scale_energy.setDisplayName('Gas Lighting: Scale Energy Use')
    gas_lighting_scale_energy.setDescription('If true, scales the energy use relative to a 3-bedroom, 1920 sqft house using the following equation: Fscale = (0.5 + 0.25 x Nbr/3 + 0.25 x FFA/1920) where Nbr is the number of bedrooms and FFA is the finished floor area.')
    gas_lighting_scale_energy.setDefaultValue(true)
    args << gas_lighting_scale_energy

    # Electric Vehicle

    # Make a double argument for EV annual energy usage
    ev_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('ev_annual_energy')
    ev_annual_energy.setDisplayName('EV charger: Annual energy consumption')
    ev_annual_energy.setDescription('Specify the total annual energy use of charging the EV at home.')
    ev_annual_energy.setDefaultValue(0)
    args << ev_annual_energy
    # ev_annual_energy is calculated like this:
    # vehicle_annual_miles_driven * vehicle_kWh_per_mile / (ev_charger_efficiency * ev_battery_efficiency)

    # Assume 0.3 kWh/mile based on https://wattev2buy.com/efficient-ev-ranking-efficiency-electric-vehicles-usa/
    # Tesla vehicles display consumption in Wh/mi, with numbers 250-400 depending on driving style. Users report 300 (0.3 kWh/mi) is normal. https://forums.tesla.com/forum/forums/miles-kwh
    # Also note that charger efficiency and battery efficiency are roughly 90% each, for a combined efficiency of 80% (https://fueleconomy.gov/feg/evtech.shtml - "view data sources", Chae et. al, Gautam et. al)
    # An example calculation: 5000mi * 0.3kWh/mi / (0.9 * 0.9) == 1852

    # make a double argument for Energy Multiplier
    ev_charger_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('ev_charger_mult')
    ev_charger_mult.setDisplayName('EV charger: Energy Multiplier')
    ev_charger_mult.setDescription('Sets the annual energy use equal to the annual energy use times this multiplier.')
    ev_charger_mult.setDefaultValue(1)
    args << ev_charger_mult

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    has_fridge = runner.getBoolArgumentValue('has_fridge', user_arguments)
    has_freezer = runner.getBoolArgumentValue('has_freezer', user_arguments)
    has_pool_heater_elec = runner.getBoolArgumentValue('has_pool_heater_elec', user_arguments)
    has_pool_heater_gas = runner.getBoolArgumentValue('has_pool_heater_gas', user_arguments)
    has_pool_pump = runner.getBoolArgumentValue('has_pool_pump', user_arguments)
    has_hot_tub_heater_elec = runner.getBoolArgumentValue('has_hot_tub_heater_elec', user_arguments)
    has_hot_tub_heater_gas = runner.getBoolArgumentValue('has_hot_tub_heater_gas', user_arguments)
    has_hot_tub_pump = runner.getBoolArgumentValue('has_hot_tub_pump', user_arguments)
    has_well_pump = runner.getBoolArgumentValue('has_well_pump', user_arguments)
    has_gas_fireplace = runner.getBoolArgumentValue('has_gas_fireplace', user_arguments)
    has_gas_grill = runner.getBoolArgumentValue('has_gas_grill', user_arguments)
    has_gas_lighting = runner.getBoolArgumentValue('has_gas_lighting', user_arguments)
    has_electric_vehicle = runner.getBoolArgumentValue('has_electric_vehicle', user_arguments)

    ev_charger_mult = runner.getDoubleArgumentValue('ev_charger_mult', user_arguments)
    ev_annual_energy = runner.getDoubleArgumentValue('ev_annual_energy', user_arguments)

    fridge_rated_annual_energy = runner.getDoubleArgumentValue('fridge_rated_annual_energy', user_arguments)
    fridge_mult = runner.getDoubleArgumentValue('fridge_mult', user_arguments)
    fridge_weekday_sch = runner.getStringArgumentValue('fridge_weekday_sch', user_arguments)
    fridge_weekend_sch = runner.getStringArgumentValue('fridge_weekend_sch', user_arguments)
    fridge_monthly_sch = runner.getStringArgumentValue('fridge_monthly_sch', user_arguments)
    fridge_location = runner.getStringArgumentValue('fridge_location', user_arguments)

    freezer_rated_annual_energy = runner.getDoubleArgumentValue('freezer_rated_annual_energy', user_arguments)
    freezer_mult = runner.getDoubleArgumentValue('freezer_mult', user_arguments)
    freezer_weekday_sch = runner.getStringArgumentValue('freezer_weekday_sch', user_arguments)
    freezer_weekend_sch = runner.getStringArgumentValue('freezer_weekend_sch', user_arguments)
    freezer_monthly_sch = runner.getStringArgumentValue('freezer_monthly_sch', user_arguments)
    freezer_location = runner.getStringArgumentValue('freezer_location', user_arguments)

    pool_heater_elec_annual_energy = runner.getDoubleArgumentValue('pool_heater_elec_annual_energy', user_arguments)
    pool_heater_elec_mult = runner.getDoubleArgumentValue('pool_heater_elec_mult', user_arguments)
    pool_heater_gas_annual_energy = runner.getDoubleArgumentValue('pool_heater_gas_annual_energy', user_arguments)
    pool_heater_gas_mult = runner.getDoubleArgumentValue('pool_heater_gas_mult', user_arguments)
    pool_pump_annual_energy = runner.getDoubleArgumentValue('pool_pump_annual_energy', user_arguments)
    pool_pump_mult = runner.getDoubleArgumentValue('pool_pump_mult', user_arguments)
    pool_scale_energy = runner.getBoolArgumentValue('pool_scale_energy', user_arguments)
    pool_weekday_sch = runner.getStringArgumentValue('pool_weekday_sch', user_arguments)
    pool_weekend_sch = runner.getStringArgumentValue('pool_weekend_sch', user_arguments)
    pool_monthly_sch = runner.getStringArgumentValue('pool_monthly_sch', user_arguments)

    hot_tub_heater_elec_annual_energy = runner.getDoubleArgumentValue('hot_tub_heater_elec_annual_energy', user_arguments)
    hot_tub_heater_elec_mult = runner.getDoubleArgumentValue('hot_tub_heater_elec_mult', user_arguments)
    hot_tub_heater_gas_annual_energy = runner.getDoubleArgumentValue('hot_tub_heater_gas_annual_energy', user_arguments)
    hot_tub_heater_gas_mult = runner.getDoubleArgumentValue('hot_tub_heater_gas_mult', user_arguments)
    hot_tub_pump_annual_energy = runner.getDoubleArgumentValue('hot_tub_pump_annual_energy', user_arguments)
    hot_tub_pump_mult = runner.getDoubleArgumentValue('hot_tub_pump_mult', user_arguments)
    hot_tub_scale_energy = runner.getBoolArgumentValue('hot_tub_scale_energy', user_arguments)
    hot_tub_weekday_sch = runner.getStringArgumentValue('hot_tub_weekday_sch', user_arguments)
    hot_tub_weekend_sch = runner.getStringArgumentValue('hot_tub_weekend_sch', user_arguments)
    hot_tub_monthly_sch = runner.getStringArgumentValue('hot_tub_monthly_sch', user_arguments)

    well_pump_annual_energy = runner.getDoubleArgumentValue('well_pump_annual_energy', user_arguments)
    well_pump_mult = runner.getDoubleArgumentValue('well_pump_mult', user_arguments)
    well_pump_scale_energy = runner.getBoolArgumentValue('well_pump_scale_energy', user_arguments)

    gas_fireplace_annual_energy = runner.getDoubleArgumentValue('gas_fireplace_annual_energy', user_arguments)
    gas_fireplace_mult = runner.getDoubleArgumentValue('gas_fireplace_mult', user_arguments)
    gas_fireplace_scale_energy = runner.getBoolArgumentValue('gas_fireplace_scale_energy', user_arguments)
    gas_fireplace_location = runner.getStringArgumentValue('gas_fireplace_location', user_arguments)
    model.getBuilding.additionalProperties.setFeature('has_fireplace_chimney', runner.getBoolArgumentValue('has_fireplace_chimney', user_arguments))

    gas_grill_annual_energy = runner.getDoubleArgumentValue('gas_grill_annual_energy', user_arguments)
    gas_grill_mult = runner.getDoubleArgumentValue('gas_grill_mult', user_arguments)
    gas_grill_scale_energy = runner.getBoolArgumentValue('gas_grill_scale_energy', user_arguments)

    gas_lighting_annual_energy = runner.getDoubleArgumentValue('gas_lighting_annual_energy', user_arguments)
    gas_lighting_mult = runner.getDoubleArgumentValue('gas_lighting_mult', user_arguments)
    gas_lighting_scale_energy = runner.getBoolArgumentValue('gas_lighting_scale_energy', user_arguments)

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    # Remove all existing objects
    obj_names = [Constants.ObjectNameExtraRefrigerator,
                 Constants.ObjectNameFreezer,
                 Constants.ObjectNamePoolHeater(nil),
                 Constants.ObjectNamePoolPump,
                 Constants.ObjectNameHotTubHeater(nil),
                 Constants.ObjectNameHotTubPump,
                 Constants.ObjectNameWellPump,
                 Constants.ObjectNameGasFireplace,
                 Constants.ObjectNameGasGrill,
                 Constants.ObjectNameGasLighting,
                 Constants.ObjectNameElectricVehicle]
    model.getSpaces.each do |space|
      MiscLoads.remove(runner, space, obj_names)
    end

    fridge_location_hierarchy = [Constants.SpaceTypeGarage,
                                 Constants.SpaceTypeFinishedBasement,
                                 Constants.SpaceTypeUnfinishedBasement,
                                 Constants.SpaceTypeLiving]

    freezer_location_hierarchy = [Constants.SpaceTypeGarage,
                                  Constants.SpaceTypeFinishedBasement,
                                  Constants.SpaceTypeUnfinishedBasement,
                                  Constants.SpaceTypeLiving]

    gas_fireplace_location_hierarchy = [Constants.SpaceTypeLiving,
                                        Constants.SpaceTypeFinishedBasement]

    schedules_file = SchedulesFile.new(runner: runner, model: model)
    if not schedules_file.validated?
      return false
    end

    fridge_sch = nil
    freezer_sch = nil
    pool_sch = nil
    hot_tub_sch = nil
    well_pump_sch = nil
    gas_fireplace_sch = nil
    gas_grill_sch = nil
    gas_lighting_sch = nil
    electric_vehicle_sch = nil

    msgs = []
    tot_ann_e = 0
    tot_ann_g = 0
    units.each_with_index do |unit, unit_index|
      # Extra Refrigerator

      if has_fridge

        space = Geometry.get_space_from_location(unit, fridge_location, fridge_location_hierarchy)
        if not space.nil?

          unit_obj_name = Constants.ObjectNameExtraRefrigerator(unit.name.to_s)
          success, ann_e, fridge_sch = MiscLoads.apply_electric(model, unit, runner, fridge_rated_annual_energy, fridge_mult,
                                                                fridge_weekday_sch, fridge_weekend_sch, fridge_monthly_sch,
                                                                fridge_sch, space, unit_obj_name, false, nil)

          return false if not success

          if ann_e > 0
            msgs << "An extra refrigerator with #{ann_e.round} kWhs annual energy consumption has been assigned to space '#{space.name}'."
            tot_ann_e += ann_e
          end

        end

      end

      # Freezer

      if has_freezer

        space = Geometry.get_space_from_location(unit, freezer_location, freezer_location_hierarchy)
        if not space.nil?

          unit_obj_name = Constants.ObjectNameFreezer(unit.name.to_s)
          success, ann_e, freezer_sch = MiscLoads.apply_electric(model, unit, runner, freezer_rated_annual_energy, freezer_mult,
                                                                 freezer_weekday_sch, freezer_weekend_sch, freezer_monthly_sch,
                                                                 freezer_sch, space, unit_obj_name, false, nil)

          return false if not success

          if ann_e > 0
            msgs << "A freezer with #{ann_e.round} kWhs annual energy consumption has been assigned to space '#{space.name}'."
            tot_ann_e += ann_e
          end

        end

      end

      # Electric Pool Heater

      if has_pool_heater_elec

        unit_obj_name = Constants.ObjectNamePoolHeater(Constants.FuelTypeElectric, unit.name.to_s)
        success, ann_e, pool_sch = MiscLoads.apply_electric(model, unit, runner, pool_heater_elec_annual_energy,
                                                            pool_heater_elec_mult, pool_weekday_sch, pool_weekend_sch,
                                                            pool_monthly_sch, pool_sch, nil, unit_obj_name,
                                                            pool_scale_energy, nil)

        return false if not success

        if ann_e > 0
          msgs << "A pool heater with #{ann_e.round} kWhs annual energy consumption has been assigned to outside."
          tot_ann_e += ann_e
        end

      end

      # Gas Pool Heater

      if has_pool_heater_gas

        unit_obj_name = Constants.ObjectNamePoolHeater(Constants.FuelTypeGas, unit.name.to_s)
        success, ann_g, pool_sch = MiscLoads.apply_gas(model, unit, runner, pool_heater_gas_annual_energy,
                                                       pool_heater_gas_mult, pool_weekday_sch, pool_weekend_sch,
                                                       pool_monthly_sch, pool_sch, nil, unit_obj_name,
                                                       pool_scale_energy, nil)

        return false if not success

        if ann_g > 0
          msgs << "A pool heater with #{ann_g.round} therms annual energy consumption has been assigned to outside."
          tot_ann_g += ann_g
        end

      end

      # Pool Pump

      if has_pool_pump

        unit_obj_name = Constants.ObjectNamePoolPump(unit.name.to_s)
        success, ann_e, pool_sch = MiscLoads.apply_electric(model, unit, runner, pool_pump_annual_energy,
                                                            pool_pump_mult, pool_weekday_sch, pool_weekend_sch,
                                                            pool_monthly_sch, pool_sch, nil, unit_obj_name,
                                                            pool_scale_energy, nil)

        return false if not success

        if ann_e > 0
          msgs << "A pool pump with #{ann_e.round} kWhs annual energy consumption has been assigned to outside."
          tot_ann_e += ann_e
        end

      end

      # Electric Hot Tub Heater

      if has_hot_tub_heater_elec

        unit_obj_name = Constants.ObjectNameHotTubHeater(Constants.FuelTypeElectric, unit.name.to_s)
        success, ann_e, hot_tub_sch = MiscLoads.apply_electric(model, unit, runner, hot_tub_heater_elec_annual_energy,
                                                               hot_tub_heater_elec_mult, hot_tub_weekday_sch,
                                                               hot_tub_weekend_sch, hot_tub_monthly_sch, hot_tub_sch,
                                                               nil, unit_obj_name, hot_tub_scale_energy, nil)

        return false if not success

        if ann_e > 0
          msgs << "A hot tub heater with #{ann_e.round} kWhs annual energy consumption has been assigned to outside."
          tot_ann_e += ann_e
        end

      end

      # Gas Hot Tub Heater

      if has_hot_tub_heater_gas

        unit_obj_name = Constants.ObjectNameHotTubHeater(Constants.FuelTypeGas, unit.name.to_s)
        success, ann_g, hot_tub_sch = MiscLoads.apply_gas(model, unit, runner, hot_tub_heater_gas_annual_energy,
                                                          hot_tub_heater_gas_mult, hot_tub_weekday_sch,
                                                          hot_tub_weekend_sch, hot_tub_monthly_sch, hot_tub_sch,
                                                          nil, unit_obj_name, hot_tub_scale_energy, nil)

        return false if not success

        if ann_g > 0
          msgs << "A hot tub heater with #{ann_g.round} therms annual energy consumption has been assigned to outside."
          tot_ann_g += ann_g
        end

      end

      # Hot Tub Pump

      if has_hot_tub_pump

        unit_obj_name = Constants.ObjectNameHotTubPump(unit.name.to_s)
        success, ann_e, hot_tub_sch = MiscLoads.apply_electric(model, unit, runner, hot_tub_pump_annual_energy, hot_tub_pump_mult,
                                                               hot_tub_weekday_sch, hot_tub_weekend_sch, hot_tub_monthly_sch,
                                                               hot_tub_sch, nil, unit_obj_name, hot_tub_scale_energy, nil)

        return false if not success

        if ann_e > 0
          msgs << "A hot tub pump with #{ann_e.round} kWhs annual energy consumption has been assigned to outside."
          tot_ann_e += ann_e
        end

      end

      # Well Pump

      if has_well_pump

        unit_obj_name = Constants.ObjectNameWellPump(unit.name.to_s)
        success, ann_e, well_pump_sch = MiscLoads.apply_electric(model, unit, runner, well_pump_annual_energy, well_pump_mult,
                                                                 nil, nil, nil,
                                                                 well_pump_sch, nil, unit_obj_name, well_pump_scale_energy, schedules_file)

        return false if not success

        if ann_e > 0
          msgs << "A well pump with #{ann_e.round} kWhs annual energy consumption has been assigned to outside."
          tot_ann_e += ann_e
        end

        schedules_file.set_vacancy(col_name: 'plug_loads_well_pump')
      end

      # Gas Fireplace

      if has_gas_fireplace

        space = Geometry.get_space_from_location(unit, gas_fireplace_location, gas_fireplace_location_hierarchy)
        if not space.nil?

          unit_obj_name = Constants.ObjectNameGasFireplace(unit.name.to_s)
          success, ann_g, gas_fireplace_sch = MiscLoads.apply_gas(model, unit, runner, gas_fireplace_annual_energy, gas_fireplace_mult,
                                                                  nil, nil, nil,
                                                                  gas_fireplace_sch, space, unit_obj_name, gas_fireplace_scale_energy, schedules_file)

          return false if not success

          if ann_g > 0
            msgs << "A gas fireplace with #{ann_g.round} therms annual energy consumption has been assigned to space '#{space.name}'."
            tot_ann_g += ann_g
          end

        end

        schedules_file.set_vacancy(col_name: 'fuel_loads_fireplace')
      end

      # Gas Grill

      if has_gas_grill

        unit_obj_name = Constants.ObjectNameGasGrill(unit.name.to_s)
        success, ann_g, gas_grill_sch = MiscLoads.apply_gas(model, unit, runner, gas_grill_annual_energy, gas_grill_mult,
                                                            nil, nil, nil,
                                                            gas_grill_sch, space, unit_obj_name, gas_grill_scale_energy, schedules_file)

        return false if not success

        if ann_g > 0
          msgs << "A gas grill with #{ann_g.round} therms annual energy consumption has been assigned to outside."
          tot_ann_g += ann_g
        end

        schedules_file.set_vacancy(col_name: 'fuel_loads_grill')
      end

      # Gas Lighting

      if has_gas_lighting

        unit_obj_name = Constants.ObjectNameGasLighting(unit.name.to_s)
        success, ann_g, gas_lighting_sch = MiscLoads.apply_gas(model, unit, runner, gas_lighting_annual_energy, gas_lighting_mult,
                                                               nil, nil, nil,
                                                               gas_lighting_sch, space, unit_obj_name, gas_lighting_scale_energy, schedules_file)

        return false if not success

        if ann_g > 0
          msgs << "Gas lighting with #{ann_g.round} therms annual energy consumption has been assigned to outside."
          tot_ann_g += ann_g
        end

        schedules_file.set_vacancy(col_name: 'fuel_loads_lighting')
      end

      # Electric Vehicle

      next unless has_electric_vehicle

      unit_obj_name = Constants.ObjectNameElectricVehicle(unit.name.to_s)
      success, ann_e, electric_vehicle_sch = MiscLoads.apply_electric(model, unit, runner, ev_annual_energy, ev_charger_mult,
                                                                      nil, nil, nil,
                                                                      nil, nil, unit_obj_name, false, schedules_file)

      return false if not success

      if ann_e > 0
        msgs << "An electric vehicle with #{ann_e.round} kWhs annual energy consumption has been assigned to outside."
        tot_ann_e += ann_e
      end

      schedules_file.set_vacancy(col_name: 'plug_loads_vehicle')
    end

    # Reporting
    if msgs.size > 1
      msgs.each do |msg|
        runner.registerInfo(msg)
      end
      runner.registerFinalCondition("The building has been assigned large, uncommon loads totaling #{tot_ann_e.round} kWhs and #{tot_ann_g} therms annual energy consumption across #{units.size} units.")
    elsif msgs.size == 1
      runner.registerFinalCondition(msgs[0])
    else
      runner.registerFinalCondition('No large, uncommon loads have been assigned.')
    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ResidentialMiscLargeUncommonLoads.new.registerWithApplication
