class Constants
  # Numbers --------------------

  def self.AssumedInsideTemp
    return 73.5 # deg-F
  end

  def self.DefaultCoolingSetpoint
    return 76.0
  end

  def self.DefaultFramingFactorCeiling
    return 0.11
  end

  def self.DefaultFramingFactorFloor
    return 0.13
  end

  def self.DefaultFramingFactorInterior
    return 0.16
  end

  def self.DefaultHeatingSetpoint
    return 71.0
  end

  def self.DefaultHumiditySetpoint
    return 0.60
  end

  def self.g
    return 32.174 # gravity (ft/s2)
  end

  def self.MixedUseT
    return 110 # F
  end

  def self.NumDaysInMonths(is_leap_year = false)
    num_days_in_months = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    num_days_in_months[1] += 1 if is_leap_year
    return num_days_in_months
  end

  def self.NumDaysInYear(is_leap_year = false)
    num_days_in_months = NumDaysInMonths(is_leap_year)
    num_days_in_year = num_days_in_months.reduce(:+)
    return num_days_in_year.to_f
  end

  def self.NumHoursInYear(is_leap_year = false)
    num_days_in_year = NumDaysInYear(is_leap_year)
    num_hours_in_year = num_days_in_year * 24
    return num_hours_in_year.to_f
  end

  def self.NumApplyUpgradeOptions
    return 25
  end

  def self.NumApplyUpgradesCostsPerOption
    return 2
  end

  def self.Patm
    return 14.696 # standard atmospheric pressure (psia)
  end

  def self.small
    return 1e-9
  end

  def self.PeakFlowRate
    return 500 # gal/min
  end

  def self.PeakPower
    return 100 # kWh
  end

  # Strings --------------------

  def self.AirFilm
    return 'AirFilm'
  end

  def self.Auto
    return 'auto'
  end

  def self.ColorWhite
    return 'white'
  end

  def self.ColorLight
    return 'light'
  end

  def self.ColorMedium
    return 'medium'
  end

  def self.ColorDark
    return 'dark'
  end

  def self.CoordRelative
    return 'relative'
  end

  def self.CoordAbsolute
    return 'absolute'
  end

  def self.BAZoneCold
    return 'Cold'
  end

  def self.BAZoneHotDry
    return 'Hot-Dry'
  end

  def self.BAZoneSubarctic
    return 'Subarctic'
  end

  def self.BAZoneHotHumid
    return 'Hot-Humid'
  end

  def self.BAZoneMixedHumid
    return 'Mixed-Humid'
  end

  def self.BAZoneMixedDry
    return 'Mixed-Dry'
  end

  def self.BAZoneMarine
    return 'Marine'
  end

  def self.BAZoneVeryCold
    return 'Very Cold'
  end

  def self.BoilerTypeCondensing
    return 'hot water, condensing'
  end

  def self.BoilerTypeNaturalDraft
    return 'hot water, natural draft'
  end

  def self.BoilerTypeForcedDraft
    return 'hot water, forced draft'
  end

  def self.BoilerTypeSteam
    return 'steam'
  end

  def self.BoreConfigSingle
    return 'single'
  end

  def self.BoreConfigLine
    return 'line'
  end

  def self.BoreConfigOpenRectangle
    return 'open-rectangle'
  end

  def self.BoreConfigRectangle
    return 'rectangle'
  end

  def self.BoreConfigLconfig
    return 'l-config'
  end

  def self.BoreConfigL2config
    return 'l2-config'
  end

  def self.BoreConfigUconfig
    return 'u-config'
  end

  def self.BuildingAmericaClimateZone
    return 'Building America'
  end

  def self.BuildingTypeMultifamily
    return 'multifamily'
  end

  def self.BuildingTypeSingleFamilyAttached
    return 'singlefamilyattached'
  end

  def self.BuildingTypeSingleFamilyDetached
    return 'singlefamilydetached'
  end

  def self.BuildingUnitFeatureNumBathrooms
    return 'NumberOfBathrooms'
  end

  def self.BuildingUnitFeatureNumBedrooms
    return 'NumberOfBedrooms'
  end

  def self.BuildingUnitFeatureNumOccupants
    return 'NumberOfOccupants'
  end

  def self.BuildingUnitTypeResidential
    return 'Residential'
  end

  def self.CalcTypeERIRatedHome
    return 'ERI Rated Home'
  end

  def self.CalcTypeERIReferenceHome
    return 'ERI Reference Home'
  end

  def self.CalcTypeERIIndexAdjustmentDesign
    return 'ERI Index Adjustment Design'
  end

  def self.CalcTypeERIIndexAdjustmentReferenceHome
    return 'ERI Index Adjustment Reference Home'
  end

  def self.CalcTypeStandard
    return 'Standard'
  end

  def self.CeilingFanControlTypical
    return 'typical'
  end

  def self.CeilingFanControlSmart
    return 'smart'
  end

  def self.ClothesDryerCEF
    return __method__.to_s
  end

  def self.ClothesDryerMult
    return __method__.to_s
  end

  def self.ClothesDryerFuelType
    return __method__.to_s
  end

  def self.ClothesDryerFuelSplit
    return __method__.to_s
  end

  def self.ClothesWasherDrumVolume
    return __method__.to_s
  end

  def self.ClothesWasherIMEF
    return __method__.to_s
  end

  def self.ClothesWasherRatedAnnualEnergy
    return __method__.to_s
  end

  def self.ClothesWasherDayShift
    return __method__.to_s
  end

  def self.CondenserTypeWater
    return 'watercooled'
  end

  def self.DuctedInfoMiniSplitHeatPump
    return __method__.to_s
  end

  def self.FacadeFront
    return 'front'
  end

  def self.FacadeBack
    return 'back'
  end

  def self.FacadeLeft
    return 'left'
  end

  def self.FacadeRight
    return 'right'
  end

  def self.FacadeNone
    return 'none'
  end

  def self.FluidWater
    return 'water'
  end

  def self.FluidPropyleneGlycol
    return 'propylene-glycol'
  end

  def self.FluidEthyleneGlycol
    return 'ethylene-glycol'
  end

  def self.FuelTypeElectric
    return 'electric'
  end

  def self.FuelTypeGas
    return 'gas'
  end

  def self.FuelTypePropane
    return 'propane'
  end

  def self.FuelTypeOil
    return 'oil'
  end

  def self.FuelTypeWood
    return 'wood'
  end

  def self.LocationInterior
    return 'interior'
  end

  def self.LocationExterior
    return 'exterior'
  end

  def self.MaterialCopper
    return 'copper'
  end

  def self.MaterialGypcrete
    return 'crete'
  end

  def self.MaterialGypsum
    return 'gyp'
  end

  def self.MaterialOSB
    return 'osb'
  end

  def self.MaterialPEX
    return 'pex'
  end

  def self.MonthNames
    return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  end

  def self.PVArrayTypeFixedOpenRack
    return 'FixedOpenRack'
  end

  def self.PVArrayTypeFixedRoofMount
    return 'FixedRoofMounted'
  end

  def self.PVArrayTypeFixed1Axis
    return 'OneAxis'
  end

  def self.PVArrayTypeFixed1AxisBacktracked
    return 'OneAxisBacktracking'
  end

  def self.PVArrayTypeFixed2Axis
    return 'TwoAxis'
  end

  def self.PVModuleTypeStandard
    return 'Standard'
  end

  def self.PVModuleTypePremium
    return 'Premium'
  end

  def self.PVModuleTypeThinFilm
    return 'ThinFilm'
  end

  def self.PVNetMeteringExcessRetailElectricityCost
    return 'retail electricity cost'
  end

  def self.PVNetMeteringExcessUserSpecified
    return 'user-specified'
  end

  def self.PVTypeFeedInTariff
    return 'Feed-In Tariff'
  end

  def self.PVTypeNetMetering
    return 'Net Metering'
  end

  def self.ObjectNameAirflow(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res af#{s_unit}"
  end

  def self.ObjectNameAirSourceHeatPump(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res ashp#{s_unit}"
  end

  def self.ObjectNameBath(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res bath#{s_unit}"
  end

  def self.ObjectNameBathDist(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res bath dist#{s_unit}"
  end

  def self.ObjectNameBoiler(fueltype = '', unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res boiler #{fueltype}#{s_unit}"
  end

  def self.ObjectNameBuildingUnit(unit_num = 1)
    return "unit #{unit_num}"
  end

  def self.ObjectNameCeilingFan(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res ceil fan#{s_unit}"
  end

  def self.ObjectNameCentralAirConditioner(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res ac#{s_unit}"
  end

  def self.ObjectNameCentralSystemBoilerBaseboards(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res central system boiler baseboards#{s_unit}"
  end

  def self.ObjectNameCentralSystemFanCoil(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res central system fan coil#{s_unit}"
  end

  def self.ObjectNameCentralSystemPTAC(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res central system ptac#{s_unit}"
  end

  def self.ObjectNameClothesWasher(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res cw#{s_unit}"
  end

  def self.ObjectNameClothesDryer(fueltype, unit_name = self.ObjectNameBuildingUnit)
    s_fuel = ''
    if not fueltype.nil?
      s_fuel = " #{fueltype}"
    end
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res cd#{s_fuel}#{s_unit}"
  end

  def self.ObjectNameCookingRange(fueltype, unit_name = self.ObjectNameBuildingUnit)
    s_fuel = ''
    if not fueltype.nil?
      s_fuel = " #{fueltype}"
    end
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res range#{s_fuel}#{s_unit}"
  end

  def self.ObjectNameCoolingSeason
    return 'res cooling season'
  end

  def self.ObjectNameCoolingSetpoint
    return 'res cooling setpoint'
  end

  def self.ObjectNameDehumidifier(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res dehumid#{s_unit}"
  end

  def self.ObjectNameDishwasher(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res dw#{s_unit}"
  end

  def self.ObjectNameDucts(airloop_name)
    return "res ds #{airloop_name}"
  end

  def self.ObjectNameEaves(facade = '')
    if facade != ''
      facade = " #{facade}"
    end
    return "res eaves#{facade}"
  end

  def self.ObjectNameElectricBaseboard(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res bb#{s_unit}"
  end

  def self.ObjectNameExtraRefrigerator(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res extra refrig#{s_unit}"
  end

  def self.ObjectNameFreezer(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res freezer#{s_unit}"
  end

  def self.ObjectNameFurnace(fueltype = '', unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res fur #{fueltype}#{s_unit}"
  end

  def self.ObjectNameFurniture
    return 'res furniture'
  end

  def self.ObjectNameGasFireplace(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res gas fireplace#{s_unit}"
  end

  def self.ObjectNameGasGrill(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res gas grill#{s_unit}"
  end

  def self.ObjectNameGasLighting(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res gas lighting#{s_unit}"
  end

  def self.ObjectNameGroundSourceHeatPumpVerticalBore(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res gshp vert bore#{s_unit}"
  end

  def self.ObjectNameHeatingSeason
    return 'res heating season'
  end

  def self.ObjectNameHeatingSetpoint
    return 'res heating setpoint'
  end

  def self.ObjectNameHotTubHeater(fueltype, unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res hot tub heater #{fueltype}#{s_unit}"
  end

  def self.ObjectNameHotTubPump(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res hot tub pump#{s_unit}"
  end

  def self.ObjectNameHotWaterRecircPump(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res hot water recirc pump#{s_unit}"
  end

  def self.ObjectNameHotWaterDistribution(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res hot water distribution#{s_unit}"
  end

  def self.ObjectNameInfiltration(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res infil#{s_unit}"
  end

  def self.ObjectNameLightingInterior(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res lighting interior#{s_unit}"
  end

  def self.ObjectNameLightingGarage
    return 'res lighting garage'
  end

  def self.ObjectNameLightingExterior
    return 'res lighting exterior'
  end

  def self.ObjectNameLightingExteriorHoliday
    return 'res lighting exterior holiday'
  end

  def self.ObjectNameMechanicalVentilation(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res mv#{s_unit}"
  end

  def self.ObjectNameMiniSplitHeatPump(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res ms#{s_unit}"
  end

  def self.ObjectNameMiscPlugLoads(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res misc plug loads#{s_unit}"
  end

  def self.ObjectNameMiscTelevision(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res misc television#{s_unit}"
  end

  def self.ObjectNameNaturalVentilation(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res nv#{s_unit}"
  end

  def self.ObjectNameNeighbors(facade = '')
    if facade != ''
      facade = " #{facade}"
    end
    return "res neighbors#{facade}"
  end

  def self.ObjectNameOccupants(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res occupants#{s_unit}"
  end

  def self.ObjectNameOverhangs(facade = '')
    if facade != ''
      facade = " #{facade}"
    end
    return "res overhangs#{facade}"
  end

  def self.ObjectNamePhotovoltaics(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res photovoltaics#{s_unit}"
  end

  def self.ObjectNamePoolHeater(fueltype, unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res pool heater #{fueltype}#{s_unit}"
  end

  def self.ObjectNamePoolPump(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res pool pump#{s_unit}"
  end

  def self.ObjectNameRefrigerator(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res refrig#{s_unit}"
  end

  def self.ObjectNameRelativeHumiditySetpoint(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res rh setpoint#{s_unit}"
  end

  def self.ObjectNameRoomAirConditioner(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res room ac#{s_unit}"
  end

  def self.ObjectNameShower(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res shower#{s_unit}"
  end

  def self.ObjectNameShowerDist(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res shower dist#{s_unit}"
  end

  def self.ObjectNameSink(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res sink#{s_unit}"
  end

  def self.ObjectNameSinkDist(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res sink dist#{s_unit}"
  end

  def self.ObjectNameSolarHotWater(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res solar hot water#{s_unit}"
  end

  def self.ObjectNameUnitHeater(fueltype = '', unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res unit heater #{fueltype}#{s_unit}"
  end

  def self.ObjectNameWaterHeater(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res wh#{s_unit}"
  end

  def self.ObjectNameWellPump(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res well pump#{s_unit}"
  end

  def self.ObjectNameElectricVehicle(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "res electric vehicle#{s_unit}"
  end

  def self.OptionTypeLightingFractions
    return 'Lamp Fractions'
  end

  def self.OptionTypeLightingEnergyUses
    return 'Annual Energy Uses'
  end

  def self.OptionTypeLightingScheduleCalculated
    return 'Calculated Lighting Schedule'
  end

  def self.OptionTypeLightingScheduleUserSpecified
    return 'User-Specified Lighting Schedule'
  end

  def self.OptionTypePlugLoadsMultiplier
    return 'Multiplier'
  end

  def self.OptionTypePlugLoadsEnergyUse
    return 'Annual Energy Use'
  end

  def self.PipeTypeTrunkBranch
    return 'trunk and branch'
  end

  def self.PipeTypeHomeRun
    return 'home run'
  end

  def self.PlantLoopDomesticWater(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "Domestic Hot Water Loop#{s_unit}"
  end

  def self.PlantLoopSolarHotWater(unit_name = self.ObjectNameBuildingUnit)
    s_unit = ''
    if unit_name != self.ObjectNameBuildingUnit
      s_unit = "|#{unit_name}"
    end
    return "Solar Hot Water Loop#{s_unit}"
  end

  def self.RADuctZone
    return 'RA Duct Zone'
  end

  def self.RecircTypeTimer
    return 'timer'
  end

  def self.RecircTypeDemand
    return 'demand'
  end

  def self.RecircTypeNone
    return 'none'
  end

  def self.RoofMaterialAsphaltShingles
    return 'asphalt shingles'
  end

  def self.RoofMaterialMembrane
    return 'membrane'
  end

  def self.RoofMaterialMetal
    return 'metal'
  end

  def self.RoofMaterialTarGravel
    return 'tar gravel'
  end

  def self.RoofMaterialTile
    return 'tile'
  end

  def self.RoofMaterialWoodShakes
    return 'wood shakes'
  end

  def self.RoofStructureRafter
    return 'rafter'
  end

  def self.RoofStructureTrussCantilever
    return 'truss, cantilever'
  end

  def self.RoofTypeFlat
    return 'flat'
  end

  def self.RoofTypeGable
    return 'gable'
  end

  def self.RoofTypeHip
    return 'hip'
  end

  def self.ScheduleTypeLimitsFraction
    return 'Fractional'
  end

  def self.ScheduleTypeLimitsOnOff
    return 'OnOff'
  end

  def self.ScheduleTypeLimitsTemperature
    return 'Temperature'
  end

  def self.SeasonHeating
    return 'Heating'
  end

  def self.SeasonCooling
    return 'Cooling'
  end

  def self.SeasonOverlap
    return 'Overlap'
  end

  def self.SeasonNone
    return 'None'
  end

  def self.SizingAuto
    return 'autosize'
  end

  def self.SizingAutoMaxLoad
    return 'autosize for max load'
  end

  def self.SizingInfoCMUWallFurringInsRvalue
    return __method__.to_s
  end

  def self.SizingInfoDuctsLocationFrac
    return __method__.to_s
  end

  def self.SizingInfoDuctsLocationZone
    return __method__.to_s
  end

  def self.SizingInfoDuctsReturnLoss
    return __method__.to_s
  end

  def self.SizingInfoDuctsReturnRvalue
    return __method__.to_s
  end

  def self.SizingInfoDuctsReturnSurfaceArea
    return __method__.to_s
  end

  def self.SizingInfoDuctsSupplyLoss
    return __method__.to_s
  end

  def self.SizingInfoDuctsSupplyRvalue
    return __method__.to_s
  end

  def self.SizingInfoDuctsSupplySurfaceArea
    return __method__.to_s
  end

  def self.SizingInfoHVACFracHeatLoadServed
    return __method__.to_s
  end

  def self.SizingInfoHVACFracCoolLoadServed
    return __method__.to_s
  end

  def self.SizingInfoGSHPBoreConfig
    return __method__.to_s
  end

  def self.SizingInfoGSHPBoreDepth
    return __method__.to_s
  end

  def self.SizingInfoGSHPBoreHoles
    return __method__.to_s
  end

  def self.SizingInfoGSHPBoreSpacing
    return __method__.to_s
  end

  def self.SizingInfoGSHPCoil_BF_FT_SPEC
    return __method__.to_s
  end

  def self.SizingInfoGSHPCoilBF
    return __method__.to_s
  end

  def self.SizingInfoGSHPUTubeSpacingType
    return __method__.to_s
  end

  def self.SizingInfoHPSizedForMaxLoad
    return __method__.to_s
  end

  def self.SizingInfoHVACCapacityDerateFactorCOP
    return __method__.to_s
  end

  def self.SizingInfoHVACCapacityDerateFactorEER
    return __method__.to_s
  end

  def self.SizingInfoHVACCapacityRatioCooling
    return __method__.to_s
  end

  def self.SizingInfoHVACCapacityRatioHeating
    return __method__.to_s
  end

  def self.SizingInfoHVACCoolingCFMs
    return __method__.to_s
  end

  def self.SizingInfoHVACHeatingCapacityOffset
    return __method__.to_s
  end

  def self.SizingInfoHVACHeatingCFMs
    return __method__.to_s
  end

  def self.SizingInfoHVACRatedCFMperTonHeating
    return __method__.to_s
  end

  def self.SizingInfoHVACRatedCFMperTonCooling
    return __method__.to_s
  end

  def self.SizingInfoHVACSHR
    return __method__.to_s
  end

  def self.SizingInfoMechVentType
    return __method__.to_s
  end

  def self.SizingInfoMechVentApparentSensibleEffectiveness
    return __method__.to_s
  end

  def self.SizingInfoMechVentLatentEffectiveness
    return __method__.to_s
  end

  def self.SizingInfoMechVentTotalEfficiency
    return __method__.to_s
  end

  def self.SizingInfoMechVentWholeHouseRate
    return __method__.to_s
  end

  def self.SizingInfoRoofCavityRvalue
    return __method__.to_s
  end

  def self.SizingInfoRoofColor
    return __method__.to_s
  end

  def self.SizingInfoRoofHasRadiantBarrier
    return __method__.to_s
  end

  def self.SizingInfoRoofMaterial
    return __method__.to_s
  end

  def self.SizingInfoRoofRigidInsRvalue
    return __method__.to_s
  end

  def self.SizingInfoSIPWallInsThickness
    return __method__.to_s
  end

  def self.SizingInfoSlabRvalue
    return __method__.to_s
  end

  def self.SizingInfoStudWallCavityRvalue
    return __method__.to_s
  end

  def self.SizingInfoWallType
    return __method__.to_s
  end

  def self.SizingInfoWallRigidInsRvalue
    return __method__.to_s
  end

  def self.SizingInfoWallRigidInsThickness
    return __method__.to_s
  end

  def self.SizingInfoWindowHasOverhang
    return __method__.to_s
  end

  def self.SizingInfoWindowOverhangDepth
    return __method__.to_s
  end

  def self.SizingInfoWindowOverhangOffset
    return __method__.to_s
  end

  def self.SizingInfoZoneInfiltrationCFM
    return __method__.to_s
  end

  def self.SizingInfoZoneInfiltrationELA
    return __method__.to_s
  end

  def self.SpaceTypeBathroom
    return 'bathroom' # only used by multi-zone simulations
  end

  def self.SpaceTypeBedroom
    return 'bedroom' # only used by multi-zone simulations
  end

  def self.SpaceTypeCorridor
    return 'corridor'
  end

  def self.SpaceTypeCrawl
    return 'crawlspace'
  end

  def self.SpaceTypeFinishedBasement
    return 'finished basement'
  end

  def self.SpaceTypeGarage
    return 'garage'
  end

  def self.SpaceTypeGarageAttic
    return 'garage attic'
  end

  def self.SpaceTypeKitchen
    return 'kitchen' # only used by multi-zone simulations
  end

  def self.SpaceTypeLaundryRoom
    return 'laundry room' # only used by multi-zone simulations
  end

  def self.SpaceTypeLiving
    return 'living'
  end

  def self.SpaceTypePierBeam
    return 'pier and beam'
  end

  def self.SpaceTypeUnfinishedAttic
    return 'unfinished attic'
  end

  def self.SpaceTypeUnfinishedBasement
    return 'unfinished basement'
  end

  def self.SurfaceTypeAdiabatic # adiabatic construction instead of adiabatic outside boundary condition
    return 'Adiabatic'
  end

  def self.SurfaceTypeFloorFinInsUnfinAttic # unfinished attic floor
    return 'FloorFinInsUnfinAttic'
  end

  def self.SurfaceTypeFloorFinInsUnfin # interzonal or cantilevered floor
    return 'FloorFinInsUnfin'
  end

  def self.SurfaceTypeFloorFinUninsFin # floor between 1st/2nd story living spaces
    return 'FloorFinUninsFin'
  end

  def self.SurfaceTypeFloorUnfinUninsUnfin # floor between garage and attic
    return 'FloorUnfinUninsUnfin'
  end

  def self.SurfaceTypeFloorFndGrndFinB # finished basement floor
    return 'FloorFndGrndFinB'
  end

  def self.SurfaceTypeFloorFndGrndUnfinB # unfinished basement floor
    return 'FloorFndGrndUnfinB'
  end

  def self.SurfaceTypeFloorFndGrndFinSlab # finished slab
    return 'FloorFndGrndFinSlab'
  end

  def self.SurfaceTypeFloorFndGrndUnfinSlab # garage slab
    return 'FloorFndGrndUnfinSlab'
  end

  def self.SurfaceTypeFloorUnfinBInsFin # unfinished basement ceiling
    return 'FloorUnfinBInsFin'
  end

  def self.SurfaceTypeFloorCSInsFin # crawlspace ceiling
    return 'FloorCSInsFin'
  end

  def self.SurfaceTypeFloorPBInsFin # pier beam ceiling
    return 'FloorPBInsFin'
  end

  def self.SurfaceTypeFloorFndGrndCS # crawlspace floor
    return 'FloorFndGrndCS'
  end

  def self.SurfaceTypeRoofUnfinUninsExt # garage roof
    return 'RoofUnfinUninsExt'
  end

  def self.SurfaceTypeRoofAdiabatic # shared ceiling, single unit model
    return 'SurfaceTypeRoofAdiabatic'
  end

  def self.SurfaceTypeRoofUnfinInsExt # unfinished attic roof
    return 'RoofUnfinInsExt'
  end

  def self.SurfaceTypeRoofFinInsExt # finished attic roof
    return 'RoofFinInsExt'
  end

  def self.SurfaceTypeWallExtInsFin # living exterior wall
    return 'WallExtInsFin'
  end

  def self.SurfaceTypeWallExtInsUnfin # attic gable wall under insulated roof
    return 'WallExtInsUnfin'
  end

  def self.SurfaceTypeWallExtUninsUnfin # garage exterior wall or attic gable wall under uninsulated roof
    return 'WallExtUninsUnfin'
  end

  def self.SurfaceTypeWallFndGrndFinB # finished basement wall
    return 'WallFndGrndFinB'
  end

  def self.SurfaceTypeWallFndGrndUnfinB # unfinished basement wall
    return 'WallFndGrndUnfinB'
  end

  def self.SurfaceTypeWallFndGrndCS # crawlspace wall
    return 'WallFndGrndCS'
  end

  def self.SurfaceTypeWallIntFinInsUnfin # interzonal wall
    return 'WallIntFinInsUnfin'
  end

  def self.SurfaceTypeWallIntFinUninsFin # wall between two finished spaces
    return 'WallIntFinUninsFin'
  end

  def self.SurfaceTypeWallIntUnfinUninsUnfin # wall between two unfinished spaces
    return 'WallIntUnfinUninsUnfin'
  end

  def self.TerrainOcean
    return 'ocean'
  end

  def self.TerrainPlains
    return 'plains'
  end

  def self.TerrainRural
    return 'rural'
  end

  def self.TerrainSuburban
    return 'suburban'
  end

  def self.TerrainCity
    return 'city'
  end

  def self.TiltPitch
    return 'pitch'
  end

  def self.TiltLatitude
    return 'latitude'
  end

  def self.VentTypeExhaust
    return 'exhaust'
  end

  def self.VentTypeNone
    return 'none'
  end

  def self.VentTypeSupply
    return 'supply'
  end

  def self.VentTypeBalanced
    return 'balanced'
  end

  def self.VentTypeCFIS
    return 'central fan integrated supply'
  end

  def self.WaterHeaterDrawProfileTypeRealistic
    return 'realistic'
  end

  def self.WaterHeaterDrawProfileTypeSmooth
    return 'smooth'
  end

  def self.WaterHeaterTypeTankless
    return 'tankless'
  end

  def self.WaterHeaterTypeTank
    return 'tank'
  end

  def self.WaterHeaterTypeTankModelTypeMixed
    return 'mixed'
  end

  def self.WaterHeaterTypeTankModelTypeStratified
    return 'stratified'
  end

  def self.WaterHeaterTypeHeatPump
    return 'heatpump'
  end

  def self.WaterHeaterSetpointTypeConstant
    return 'constant'
  end

  def self.WaterHeaterSetpointTypeScheduled
    return 'scheduled'
  end

  def self.WaterHeaterOperatingModeTypeConstant
    return 'constant'
  end

  def self.WaterHeaterOperatingModeTypeScheduled
    return 'scheduled'
  end

  def self.WaterHeaterOperatingModeStandard
    return 'standard'
  end

  def self.WaterHeaterOperatingModeHeatPumpOnly
    return 'heat pump only'
  end

  def self.WorkflowDescription
    return ' See https://github.com/NREL/resstock#workflows for supported workflows using this measure.'
  end

  def self.ExpectedSpaceTypes
    return [self.SpaceTypeBathroom,
            self.SpaceTypeBedroom,
            self.SpaceTypeCorridor,
            self.SpaceTypeCrawl,
            self.SpaceTypeFinishedBasement,
            self.SpaceTypeGarage,
            self.SpaceTypeKitchen,
            self.SpaceTypeLaundryRoom,
            self.SpaceTypeLiving,
            self.SpaceTypePierBeam,
            self.SpaceTypeUnfinishedAttic,
            self.SpaceTypeUnfinishedBasement]
  end

  def self.ZoneHVACPriorityList
    return ['ZoneHVACEnergyRecoveryVentilator',
            'AirLoopHVACUnitarySystem',
            'ZoneHVACBaseboardConvectiveElectric',
            'ZoneHVACBaseboardConvectiveWater',
            'AirTerminalSingleDuctUncontrolled',
            'ZoneHVACDehumidifierDX',
            'ZoneHVACPackagedTerminalAirConditioner']
  end
end
