# frozen_string_literal: true

class EnergyPlusValidator
  def self.run_validator(hpxml_doc)
    # A hash of hashes that defines the XML elements used by the EnergyPlus HPXML Use Case.
    #
    # Example:
    #
    # use_case = {
    #     nil => {
    #         'floor_area' => one,            # 1 element required always
    #         'garage_area' => zero_or_one,   # 0 or 1 elements required always
    #         'walls' => one_or_more,         # 1 or more elements required always
    #     },
    #     '/walls' => {
    #         'rvalue' => one,                # 1 element required if /walls element exists (conditional)
    #         'windows' => zero_or_one,       # 0 or 1 elements required if /walls element exists (conditional)
    #         'layers' => one_or_more,        # 1 or more elements required if /walls element exists (conditional)
    #     }
    # }
    #

    zero = [0]
    one = [1]
    zero_or_one = [0, 1]
    zero_or_more = nil
    one_or_more = []

    requirements = {

      # Root
      nil => {
        '/HPXML/XMLTransactionHeaderInformation/XMLType' => one, # Required by HPXML schema
        '/HPXML/XMLTransactionHeaderInformation/XMLGeneratedBy' => one, # Required by HPXML schema
        '/HPXML/XMLTransactionHeaderInformation/CreatedDateAndTime' => one, # Required by HPXML schema
        '/HPXML/XMLTransactionHeaderInformation/Transaction' => one, # Required by HPXML schema
        '/HPXML/SoftwareInfo/extension/ERICalculation[Version="2014" or Version="2014A" or Version="2014AE" or Version="2014AEG"]' => one, # Choose version of 301 standard and addenda (e.g., A, E, G)

        '/HPXML/Building' => one,
        '/HPXML/Building/BuildingID' => one, # Required by HPXML schema
        '/HPXML/Building/ProjectStatus/EventType' => one, # Required by HPXML schema

        '/HPXML/Building/BuildingDetails/BuildingSummary/Site/FuelTypesAvailable[Fuel="electricity" or Fuel="natural gas" or Fuel="fuel oil" or Fuel="propane" or Fuel="kerosene" or Fuel="diesel" or Fuel="coal" or Fuel="coke" or Fuel="wood" or Fuel="wood pellets"]' => one_or_more,
        '/HPXML/Building/BuildingDetails/BuildingSummary/Site/extension/ShelterCoefficient' => zero_or_one, # Uses ERI assumption if not provided
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingOccupancy/NumberofResidents' => zero_or_one, # Uses ERI assumption if not provided
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloors' => one,
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloorsAboveGrade' => one,
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofBedrooms' => one,
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedFloorArea' => one,
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedBuildingVolume' => one,
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/GaragePresent' => one,

        '/HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC[Year="2006"]' => one, # See [ClimateZone]
        '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation' => one, # See [WeatherStation]

        '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration[AirInfiltrationMeasurement[HousePressure="50"]/BuildingAirLeakage[UnitofMeasure="ACH"]/AirLeakage | AirInfiltrationMeasurement/extension/ConstantACHnatural]' => one, # ACH50 or constant nACH; see [AirInfiltration]
        '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement/InfiltrationVolume' => zero_or_one, # Assumes InfiltrationVolume = ConditionedVolume if not provided

        '/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic' => one_or_more, # See [Attic]
        '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation' => one_or_more, # See [Foundation]
        '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist' => zero_or_more, # See [RimJoist]
        '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall' => one_or_more, # See [Wall]
        '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window' => zero_or_more, # See [Window]
        '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight' => zero_or_more, # See [Skylight]
        '/HPXML/Building/BuildingDetails/Enclosure/Doors/Door' => zero_or_more, # See [Door]

        '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem' => zero_or_more, # See [HeatingSystem]
        '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem' => zero_or_more, # See [CoolingSystem]
        '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump' => zero_or_more, # See [HeatPump]
        '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl' => zero_or_one, # See [HVACControl]
        '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution' => zero_or_more, # See [HVACDistribution]
        '/HPXML/Building/BuildingDetails/Systems/HVAC/extension/NaturalVentilation' => zero_or_one, # See [NaturalVentilation]

        '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true"]' => zero_or_one, # See [MechanicalVentilation]
        '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem' => zero_or_more, # See [WaterHeatingSystem]
        '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterFixture' => zero_or_more, # See [WaterFixture]
        '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution' => zero_or_one, # See [HotWaterDistribution]
        '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem' => zero_or_more, # See [PVSystem]

        '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher' => zero_or_one, # See [ClothesWasher]
        '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer' => zero_or_one, # See [ClothesDryer]
        '/HPXML/Building/BuildingDetails/Appliances/Dishwasher' => zero_or_one, # See [Dishwasher]
        '/HPXML/Building/BuildingDetails/Appliances/Refrigerator' => zero_or_one, # See [Refrigerator]
        '/HPXML/Building/BuildingDetails/Appliances/CookingRange' => zero_or_one, # See [CookingRange]

        '/HPXML/Building/BuildingDetails/Lighting' => zero_or_one, # See [Lighting]
        '/HPXML/Building/BuildingDetails/Lighting/CeilingFan' => zero_or_one, # See [CeilingFan]

        '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad[PlugLoadType="other"]' => zero_or_one, # See [PlugLoads]
        '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad[PlugLoadType="TV other"]' => zero_or_one, # See [Television]
      },

      # [ClimateZone]
      '/HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC' => {
        '[ClimateZone="1A" or ClimateZone="1B" or ClimateZone="1C" or ClimateZone="2A" or ClimateZone="2B" or ClimateZone="2C" or ClimateZone="3A" or ClimateZone="3B" or ClimateZone="3C" or ClimateZone="4A" or ClimateZone="4B" or ClimateZone="4C" or ClimateZone="5A" or ClimateZone="5B" or ClimateZone="5C" or ClimateZone="6A" or ClimateZone="6B" or ClimateZone="6C" or ClimateZone="7" or ClimateZone="8"]' => one,
      },

      # [WeatherStation]
      '/HPXML/Building/BuildingDetails/ClimateandRiskZones/WeatherStation' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Name' => one, # Required by HPXML schema
        'WMO' => one, # Reference weather/data.csv for the list of acceptable WMO station numbers
      },

      # [Attic]
      '/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic' => {
        'AtticType[Attic[Vented="false"] | Attic[Vented="true"] | Attic[Conditioned="true"] | FlatRoof | CathedralCeiling]' => one, # See [AtticType=Unvented] or [AtticType=Vented] or [AtticType=Conditioned]
        'Roofs/Roof' => one_or_more, # See [AtticRoof]
        'Walls/Wall' => zero_or_more, # See [AtticWall]
      },

      ## [AtticType=Unvented]
      '/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic[AtticType/Attic[Vented="false"]]' => {
        'Floors/Floor' => one_or_more, # See [AtticFloor]
      },

      ## [AtticType=Vented]
      '/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic[AtticType/Attic[Vented="true"]]' => {
        'Floors/Floor' => one_or_more, # See [AtticFloor]
        '[SpecificLeakageArea | extension/AtticConstantACHnatural]' => zero_or_one, # Uses ERI Reference Home if not provided
      },

      ## [AtticRoof]
      '/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic/Roofs/Roof' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Area' => one,
        'Azimuth' => zero_or_one,
        'SolarAbsorptance' => one,
        'Emittance' => one,
        'Pitch' => one,
        'RadiantBarrier' => one,
        'Insulation/SystemIdentifier' => one, # Required by HPXML schema
        'Insulation/AssemblyEffectiveRValue' => one,
      },

      ## [AtticFloor]
      '/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic/Floors/Floor' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[AdjacentTo="living space" or AdjacentTo="garage" or AdjacentTo="outside"]' => one,
        'Area' => one,
        'Insulation/SystemIdentifier' => one, # Required by HPXML schema
        'Insulation/AssemblyEffectiveRValue' => zero_or_one, # Uses ERI Reference Home if not provided
      },

      ## [AtticWall]
      '/HPXML/Building/BuildingDetails/Enclosure/Attics/Attic/Walls/Wall' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[AdjacentTo="living space" or AdjacentTo="garage" or AdjacentTo="attic - vented" or AdjacentTo="attic - unvented" or AdjacentTo="attic - conditioned" or AdjacentTo="outside"]' => one,
        'WallType[WoodStud | DoubleWoodStud | ConcreteMasonryUnit | StructurallyInsulatedPanel | InsulatedConcreteForms | SteelFrame | SolidConcrete | StructuralBrick | StrawBale | Stone | LogWall]' => one,
        'Area' => one,
        'Azimuth' => zero_or_one,
        'SolarAbsorptance' => one,
        'Emittance' => one,
        'Insulation/SystemIdentifier' => one, # Required by HPXML schema
        'Insulation/AssemblyEffectiveRValue' => one,
      },

      # [Foundation]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'FoundationType[Basement | Crawlspace | SlabOnGrade | Ambient]' => one, # See [FoundationType=Basement] or [FoundationType=Crawl] or [FoundationType=Slab] or [FoundationType=Ambient]
      },

      ## [FoundationType=Basement]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/Basement]' => {
        'FoundationType/Basement/Conditioned' => one, # If not conditioned, see [FoundationType=UnconditionedBasement]
        'FoundationWall' => one_or_more, # See [FoundationWall]
        'Slab' => one_or_more, # See [FoundationSlab]
      },

      ## [FoundationType=UnconditionedBasement]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/Basement[Conditioned="false"]]' => {
        'FrameFloor' => one_or_more, # See [FoundationFrameFloor]
      },

      ## [FoundationType=Crawl]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/Crawlspace]' => {
        'FoundationType/Crawlspace/Vented' => one, # If vented, see [FoundationType=VentedCrawl]
        'FrameFloor' => one_or_more, # See [FoundationFrameFloor]
        'FoundationWall' => one_or_more, # See [FoundationWall]
        'Slab' => one_or_more, # See [FoundationSlab]; use slab with zero thickness for dirt floor
      },

      ## [FoundationType=VentedCrawl]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/Crawlspace[Vented="true"]]' => {
        'SpecificLeakageArea' => zero_or_one, # Uses ERI Reference Home if not provided
      },

      ## [FoundationType=Slab]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/SlabOnGrade]' => {
        'Slab' => one_or_more, # See [FoundationSlab]
      },

      ## [FoundationType=Ambient]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/Ambient]' => {
        'FrameFloor' => one_or_more, # See [FoundationFrameFloor]
      },

      ## [FoundationFrameFloor]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation/FrameFloor' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[AdjacentTo="living space" or AdjacentTo="garage"]' => one,
        'Area' => one,
        'Insulation/SystemIdentifier' => one, # Required by HPXML schema
        'Insulation/AssemblyEffectiveRValue' => zero_or_one, # Uses ERI Reference Home if not provided
      },

      ## [FoundationWall]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation/FoundationWall' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Height' => one,
        'Area' => one,
        'Azimuth' => zero_or_one,
        'Thickness' => one,
        'DepthBelowGrade' => one,
        '[AdjacentTo="ground" or AdjacentTo="basement - unconditioned" or AdjacentTo="basement - conditioned" or AdjacentTo="crawlspace - vented" or AdjacentTo="crawlspace - unvented"]' => one,
        'Insulation/SystemIdentifier' => one, # Required by HPXML schema
        'Insulation/AssemblyEffectiveRValue' => zero_or_one, # Uses ERI Reference Home if not provided
      },

      ## [FoundationSlab]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation/Slab' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Area' => one,
        'Thickness' => one, # Use zero for dirt floor
        'ExposedPerimeter' => one,
        'PerimeterInsulationDepth' => zero_or_one, # Uses ERI Reference Home if not provided
        'UnderSlabInsulationWidth' => zero_or_one, # Uses ERI Reference Home if not provided
        'DepthBelowGrade' => one,
        'PerimeterInsulation/SystemIdentifier' => one, # Required by HPXML schema
        'PerimeterInsulation/Layer[InstallationType="continuous"]/NominalRValue' => zero_or_one, # Uses ERI Reference Home if not provided
        'UnderSlabInsulation/SystemIdentifier' => one, # Required by HPXML schema
        'UnderSlabInsulation/Layer[InstallationType="continuous"]/NominalRValue' => zero_or_one, # Uses ERI Reference Home if not provided
        'extension/CarpetFraction' => one,
        'extension/CarpetRValue' => one,
      },

      # [RimJoist]
      '/HPXML/Building/BuildingDetails/Enclosure/RimJoists/RimJoist' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[ExteriorAdjacentTo="outside" or ExteriorAdjacentTo="basement - unconditioned" or ExteriorAdjacentTo="crawlspace - vented" or ExteriorAdjacentTo="crawlspace - unvented" or ExteriorAdjacentTo="attic - vented" or ExteriorAdjacentTo="attic - unvented" or ExteriorAdjacentTo="attic - conditioned" or ExteriorAdjacentTo="garage"]' => one,
        '[InteriorAdjacentTo="living space" or InteriorAdjacentTo="basement - unconditioned" or InteriorAdjacentTo="crawlspace - vented" or InteriorAdjacentTo="crawlspace - unvented" or InteriorAdjacentTo="attic - vented" or InteriorAdjacentTo="attic - unvented" or InteriorAdjacentTo="attic - conditioned" or InteriorAdjacentTo="garage"]' => one,
        'Area' => one,
        'Azimuth' => zero_or_one,
        'Insulation/SystemIdentifier' => one, # Required by HPXML schema
        'Insulation/AssemblyEffectiveRValue' => one,
      },

      # [Wall]
      '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[ExteriorAdjacentTo="living space" or ExteriorAdjacentTo="garage" or ExteriorAdjacentTo="attic - vented" or ExteriorAdjacentTo="attic - unvented" or ExteriorAdjacentTo="attic - conditioned" or ExteriorAdjacentTo="outside"]' => one,
        '[InteriorAdjacentTo="living space" or InteriorAdjacentTo="garage" or InteriorAdjacentTo="attic - vented" or InteriorAdjacentTo="attic - unvented" or InteriorAdjacentTo="attic - conditioned"]' => one,
        'WallType[WoodStud | DoubleWoodStud | ConcreteMasonryUnit | StructurallyInsulatedPanel | InsulatedConcreteForms | SteelFrame | SolidConcrete | StructuralBrick | StrawBale | Stone | LogWall]' => one, # See [WallType=WoodStud] or [WallType=NotWoodStud]
        'Area' => one,
        'Azimuth' => zero_or_one,
        'SolarAbsorptance' => one,
        'Emittance' => one,
        'Insulation/SystemIdentifier' => one, # Required by HPXML schema
      },

      # [WallType=WoodStud]
      '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall[WallType/WoodStud]' => {
        'Insulation/AssemblyEffectiveRValue' => zero_or_one, # Uses ERI Reference Home if not provided
      },

      # [WallType=NotWoodStud]
      '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall[not(WallType/WoodStud)]' => {
        'Insulation/AssemblyEffectiveRValue' => one,
      },

      # [Window]
      '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Area' => one,
        'Azimuth' => one,
        'UFactor' => one,
        'SHGC' => one,
        'Overhangs' => zero_or_one, # See [WindowOverhang]
        'AttachedToWall' => one,
        'extension/InteriorShadingFactorSummer' => zero_or_one, # Uses ERI assumption if not provided
        'extension/InteriorShadingFactorWinter' => zero_or_one, # Uses ERI assumption if not provided
      },

      ## [WindowOverhang]
      '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window/Overhangs' => {
        'Depth' => one,
        'DistanceToTopOfWindow' => one,
        'DistanceToBottomOfWindow' => one,
      },

      # [Skylight]
      '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Area' => one,
        'Azimuth' => one,
        'UFactor' => one,
        'SHGC' => one,
        'AttachedToRoof' => one,
      },

      # [Door]
      '/HPXML/Building/BuildingDetails/Enclosure/Doors/Door' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'AttachedToWall' => one,
        'Area' => zero_or_one, # Uses ERI Reference Home if not provided
        'Azimuth' => zero_or_one, # Uses ERI Reference Home if not provided
        'RValue' => zero_or_one, # Uses ERI Reference Home if not provided
      },

      # [AirInfiltration]
      'BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement' => {
        'SystemIdentifier' => one, # Required by HPXML schema
      },

      # [HeatingSystem]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '../../HVACControl' => one, # See [HVACControl]
        'HeatingSystemType[ElectricResistance | Furnace | WallFurnace | Boiler | Stove]' => one, # See [HeatingType=Resistance] or [HeatingType=Furnace] or [HeatingType=WallFurnace] or [HeatingType=Boiler] or [HeatingType=Stove]
        'HeatingCapacity' => one, # Use -1 for autosizing
        'FractionHeatLoadServed' => one, # Must sum to <= 1 across all HeatingSystems and HeatPumps
      },

      ## [HeatingType=Resistance]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/ElectricResistance]' => {
        'DistributionSystem' => zero,
        '[HeatingSystemFuel="electricity"]' => one,
        'AnnualHeatingEfficiency[Units="Percent"]/Value' => one,
      },

      ## [HeatingType=Furnace]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/Furnace]' => {
        'DistributionSystem' => one, # See [HVACDistribution]
        '[HeatingSystemFuel="natural gas" or HeatingSystemFuel="fuel oil" or HeatingSystemFuel="propane" or HeatingSystemFuel="electricity"]' => one, # See [HeatingType=FuelEquipment] if not electricity
        'AnnualHeatingEfficiency[Units="AFUE"]/Value' => one,
      },

      ## [HeatingType=WallFurnace]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/WallFurnace]' => {
        'DistributionSystem' => zero,
        '[HeatingSystemFuel="natural gas" or HeatingSystemFuel="fuel oil" or HeatingSystemFuel="propane" or HeatingSystemFuel="electricity"]' => one, # See [HeatingType=FuelEquipment] if not electricity
        'AnnualHeatingEfficiency[Units="AFUE"]/Value' => one,
      },

      ## [HeatingType=Boiler]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/Boiler]' => {
        'DistributionSystem' => one, # See [HVACDistribution]
        '[HeatingSystemFuel="natural gas" or HeatingSystemFuel="fuel oil" or HeatingSystemFuel="propane" or HeatingSystemFuel="electricity"]' => one, # See [HeatingType=FuelEquipment] if not electricity
        'AnnualHeatingEfficiency[Units="AFUE"]/Value' => one,
      },

      ## [HeatingType=Stove]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/Stove]' => {
        'DistributionSystem' => zero,
        '[HeatingSystemFuel="natural gas" or HeatingSystemFuel="fuel oil" or HeatingSystemFuel="propane" or HeatingSystemFuel="electricity"]' => one, # See [HeatingType=FuelEquipment] if not electricity
        'AnnualHeatingEfficiency[Units="Percent"]/Value' => one,
      },

      ## [HeatingType=FuelEquipment]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemFuel="natural gas" or HeatingSystemFuel="fuel oil" or HeatingSystemFuel="propane"]' => {
        'ElectricAuxiliaryEnergy' => zero_or_one, # If not provided, uses 301 defaults for furnace/boiler and zero for other heating systems
      },

      ## [CoolingSystem]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '../../HVACControl' => one, # See [HVACControl]
        '[CoolingSystemType="central air conditioning" or CoolingSystemType="room air conditioner"]' => one, # See [CoolingType=CentralAC] or [CoolingType=RoomAC]
        '[CoolingSystemFuel="electricity"]' => one,
        'CoolingCapacity' => one, # Use -1 for autosizing
        'FractionCoolLoadServed' => one, # Must sum to <= 1 across all CoolingSystems and HeatPumps
      },

      ## [CoolingType=CentralAC]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[CoolingSystemType="central air conditioning"]' => {
        'DistributionSystem' => one, # See [HVACDistribution]
        'AnnualCoolingEfficiency[Units="SEER"]/Value' => one,
      },

      ## [CoolingType=RoomAC]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[CoolingSystemType="room air conditioning"]' => {
        'DistributionSystem' => zero,
        'AnnualCoolingEfficiency[Units="EER"]/Value' => one,
      },

      ## [HeatPump]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '../../HVACControl' => one, # See [HVACControl]
        '[HeatPumpType="air-to-air" or HeatPumpType="mini-split" or HeatPumpType="ground-to-air"]' => one, # See [HeatPumpType=ASHP] or [HeatPumpType=MSHP] or [HeatPumpType=GSHP]
        '[HeatPumpFuel="electricity"]' => one,
        'CoolingCapacity' => one, # Use -1 for autosizing
        'FractionHeatLoadServed' => one, # Must sum to <= 1 across all HeatPumps and HeatingSystems
        'FractionCoolLoadServed' => one, # Must sum to <= 1 across all HeatPumps and CoolingSystems
      },

      ## [HeatPumpType=ASHP]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[HeatPumpType="air-to-air"]' => {
        'DistributionSystem' => one, # See [HVACDistribution]
        'AnnualCoolingEfficiency[Units="SEER"]/Value' => one,
        'AnnualHeatingEfficiency[Units="HSPF"]/Value' => one,
      },

      ## [HeatPumpType=MSHP]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[HeatPumpType="mini-split"]' => {
        'DistributionSystem' => zero_or_one, # See [HVACDistribution]
        'AnnualCoolingEfficiency[Units="SEER"]/Value' => one,
        'AnnualHeatingEfficiency[Units="HSPF"]/Value' => one,
      },

      ## [HeatPumpType=GSHP]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[HeatPumpType="ground-to-air"]' => {
        'DistributionSystem' => one, # See [HVACDistribution]
        'AnnualCoolingEfficiency[Units="EER"]/Value' => one,
        'AnnualHeatingEfficiency[Units="COP"]/Value' => one,
      },

      # [HVACControl]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACControl' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[ControlType="manual thermostat" or ControlType="programmable thermostat"]' => one,
        'SetpointTempHeatingSeason' => zero_or_one, # Uses ERI assumption if not provided
        'SetpointTempCoolingSeason' => zero_or_one, # Uses ERI assumption if not provided
      },

      # [HVACDistribution]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[DistributionSystemType/AirDistribution | DistributionSystemType/HydronicDistribution | DistributionSystemType[Other="DSE"]]' => one, # See [HVACDistType=Air] or [HVACDistType=DSE]
      },

      ## [HVACDistType=Air]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution' => {
        'DuctLeakageMeasurement[DuctType="supply"]/DuctLeakage[Units="CFM25" and TotalOrToOutside="to outside"]/Value' => one,
        'DuctLeakageMeasurement[DuctType="return"]/DuctLeakage[Units="CFM25" and TotalOrToOutside="to outside"]/Value' => one,
        'Ducts[DuctType="supply"]' => one_or_more, # See [HVACDuct]
        'Ducts[DuctType="return"]' => one_or_more, # See [HVACDuct]
      },

      ## [HVACDistType=DSE]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution[DistributionSystemType[Other="DSE"]]' => {
        '[AnnualHeatingDistributionSystemEfficiency | AnnualCoolingDistributionSystemEfficiency]' => one_or_more,
      },

      ## [HVACDuct]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts[DuctType="supply" or DuctType="return"]' => {
        'DuctInsulationRValue' => one,
        '[DuctLocation="living space" or DuctLocation="basement - conditioned" or DuctLocation="basement - unconditioned" or DuctLocation="crawlspace - vented" or DuctLocation="crawlspace - unvented" or DuctLocation="attic - vented" or DuctLocation="attic - unvented" or DuctLocation="attic - conditioned" or DuctLocation="garage"]' => one,
        'DuctSurfaceArea' => one,
      },

      # [MechanicalVentilation]
      '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true"]' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[FanType="energy recovery ventilator" or FanType="heat recovery ventilator" or FanType="exhaust only" or FanType="supply only" or FanType="balanced" or FanType="central fan integrated supply"]' => one, # See [MechVentType=HRV] or [MechVentType=ERV] or [MechVentType=CFIS]
        'RatedFlowRate' => one,
        'HoursInOperation' => one,
        'UsedForWholeBuildingVentilation' => one,
        'FanPower' => one,
      },

      ## [MechVentType=HRV]
      '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true"][FanType="heat recovery ventilator"]' => {
        'SensibleRecoveryEfficiency' => one,
      },

      ## [MechVentType=ERV]
      '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true"][FanType="energy recovery ventilator"]' => {
        'TotalRecoveryEfficiency' => one,
        'SensibleRecoveryEfficiency' => one,
      },

      ## [MechVentType=CFIS]
      '/HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true"][FanType="central fan integrated supply"]' => {
        'AttachedToHVACDistributionSystem' => one,
      },

      # [WaterHeatingSystem]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem' => {
        '../HotWaterDistribution' => one, # See [HotWaterDistribution]
        '../WaterFixture' => one_or_more, # See [WaterFixture]
        'SystemIdentifier' => one, # Required by HPXML schema
        '[WaterHeaterType="storage water heater" or WaterHeaterType="instantaneous water heater" or WaterHeaterType="heat pump water heater"]' => one, # See [WHType=Tank]
        '[Location="living space" or Location="basement - unconditioned" or Location="basement - conditioned" or Location="attic - unvented" or Location="attic - vented" or Location="garage" or Location="crawlspace - unvented" or Location="crawlspace - vented"]' => one,
        'FractionDHWLoadServed' => one,
        '[EnergyFactor | UniformEnergyFactor]' => one,
        'extension/EnergyFactorMultiplier' => zero_or_one, # Uses ERI assumption if not provided
      },

      ## [WHType=Tank]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="storage water heater"]' => {
        '[FuelType="natural gas" or FuelType="fuel oil" or FuelType="propane" or FuelType="electricity"]' => one, # If not electricity, see [WHType=FuelTank]
        'TankVolume' => one,
        'HeatingCapacity' => one,
      },

      ## [WHType=FuelTank]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="storage water heater" and FuelType!="electricity"]' => {
        'RecoveryEfficiency' => one,
      },

      ## [WHType=Tankless]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="instantaneous water heater"]' => {
        '[FuelType="natural gas" or FuelType="fuel oil" or FuelType="propane" or FuelType="electricity"]' => one,
      },

      ## [WHType=HeatPump]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="heat pump water heater"]' => {
        '[FuelType="electricity"]' => one,
        'TankVolume' => one,
      },

      # [HotWaterDistribution]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[SystemType/Standard | SystemType/Recirculation]' => one, # See [HWDistType=Standard] or [HWDistType=Recirculation]
        'PipeInsulation/PipeRValue' => one,
        'DrainWaterHeatRecovery' => zero_or_one, # See [DrainWaterHeatRecovery]
      },

      ## [HWDistType=Standard]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Standard' => {
        'PipingLength' => zero_or_one, # Uses ERI Reference Home if not provided
      },

      ## [HWDistType=Recirculation]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/SystemType/Recirculation' => {
        'ControlType' => one,
        'RecirculationPipingLoopLength' => zero_or_one, # Uses ERI Reference Home if not provided
        'BranchPipingLoopLength' => one,
        'PumpPower' => one,
      },

      ## [DrainWaterHeatRecovery]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution/DrainWaterHeatRecovery' => {
        'FacilitiesConnected' => one,
        'EqualFlow' => one,
        'Efficiency' => one,
      },

      # [WaterFixture]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterFixture' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[WaterFixtureType="shower head" or WaterFixtureType="faucet"]' => one, # Required by HPXML schema
        'LowFlow' => one,
      },

      # [PVSystem]
      '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[ModuleType="standard" or ModuleType="premium" or ModuleType="thin film"]' => one,
        '[ArrayType="fixed roof mount" or ArrayType="fixed open rack" or ArrayType="1-axis" or ArrayType="1-axis backtracked" or ArrayType="2-axis"]' => one,
        'ArrayAzimuth' => one,
        'ArrayTilt' => one,
        'MaxPowerOutput' => one,
        'InverterEfficiency' => one, # PVWatts default is 0.96
        'SystemLossesFraction' => one, # PVWatts default is 0.14
      },

      # [ClothesWasher]
      '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[Location="living space" or Location="basement - conditioned" or Location="basement - unconditioned" or Location="garage"]' => zero_or_one,
        '[ModifiedEnergyFactor | IntegratedModifiedEnergyFactor]' => zero_or_one, # Uses ERI Reference Home if neither provided; otherwise see [CWType=UserSpecified]
      },

      ## [CWType=UserSpecified]
      '/HPXML/Building/BuildingDetails/Appliances/ClothesWasher[ModifiedEnergyFactor]' => {
        'RatedAnnualkWh' => one,
        'LabelElectricRate' => one,
        'LabelGasRate' => one,
        'LabelAnnualGasCost' => one,
        'Capacity' => one,
      },

      # [ClothesDryer]
      '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[Location="living space" or Location="basement - conditioned" or Location="basement - unconditioned" or Location="garage"]' => zero_or_one,
        '[FuelType="natural gas" or FuelType="fuel oil" or FuelType="propane" or FuelType="electricity"]' => one,
        '[EnergyFactor | CombinedEnergyFactor]' => zero_or_one, # Uses ERI Reference Home if neither provided; otherwise see [CDType=UserSpecified]
      },

      ## [CDType=UserSpecified]
      '/HPXML/Building/BuildingDetails/Appliances/ClothesDryer[EnergyFactor]' => {
        '[ControlType="timer" or ControlType="moisture"]' => one,
      },

      # [Dishwasher]
      '/HPXML/Building/BuildingDetails/Appliances/Dishwasher' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[EnergyFactor | RatedAnnualkWh]' => zero_or_one, # Uses ERI Reference Home if neither provided; otherwise see [DWType=UserSpecified]
      },

      ## [DWType=UserSpecified]
      '/HPXML/Building/BuildingDetails/Appliances/Dishwasher[EnergyFactor | RatedAnnualkWh]' => {
        'PlaceSettingCapacity' => one,
      },

      # [Refrigerator]
      '/HPXML/Building/BuildingDetails/Appliances/Refrigerator' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[Location="living space" or Location="basement - conditioned" or Location="basement - unconditioned" or Location="garage"]' => zero_or_one,
        'RatedAnnualkWh' => zero_or_one, # Uses ERI Reference Home if not provided
      },

      # [CookingRange]
      '/HPXML/Building/BuildingDetails/Appliances/CookingRange' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        '[FuelType="natural gas" or FuelType="fuel oil" or FuelType="propane" or FuelType="electricity"]' => one,
        'IsInduction' => zero_or_one, # Uses ERI Reference Home if not provided; otherwise see [CRType=UserSpecified]
      },

      ## [CRType=UserSpecified]
      '/HPXML/Building/BuildingDetails/Appliances/CookingRange[IsInduction]' => {
        '../Oven/IsConvection' => one,
      },

      # [Lighting]
      '/HPXML/Building/BuildingDetails/Lighting' => {
        'LightingGroup[ThirdPartyCertification="ERI Tier I" and Location="interior"]' => zero_or_one, # Uses ERI Reference Home if not provided; otherwise see [LightingGroup]
        'LightingGroup[ThirdPartyCertification="ERI Tier I" and Location="exterior"]' => zero_or_one, # Uses ERI Reference Home if not provided; otherwise see [LightingGroup]
        'LightingGroup[ThirdPartyCertification="ERI Tier I" and Location="garage"]' => zero_or_one, # Uses ERI Reference Home if not provided; otherwise see [LightingGroup]
        'LightingGroup[ThirdPartyCertification="ERI Tier II" and Location="interior"]' => zero_or_one, # Uses ERI Reference Home if not provided; otherwise see [LightingGroup]
        'LightingGroup[ThirdPartyCertification="ERI Tier II" and Location="exterior"]' => zero_or_one, # Uses ERI Reference Home if not provided; otherwise see [LightingGroup]
        'LightingGroup[ThirdPartyCertification="ERI Tier II" and Location="garage"]' => zero_or_one, # Uses ERI Reference Home if not provided; otherwise see [LightingGroup]
      },

      ## [LightingGroup]
      '/HPXML/Building/BuildingDetails/Lighting/LightingGroup[ThirdPartyCertification="ERI Tier I" or ThirdPartyCertification="ERI Tier II"][Location="interior" or Location="exterior" or Location="garage"]' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'FractionofUnitsInLocation' => one,
      },

      # [CeilingFan]
      '/HPXML/Building/BuildingDetails/Lighting/CeilingFan' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Airflow[FanSpeed="medium"]/Efficiency' => zero_or_one, # Uses Reference Home if not provided
        'Quantity' => zero_or_one, # Uses Reference Home if not provided
      },

      # [PlugLoads]
      '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad[PlugLoadType="other"]' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Load[Units="kWh/year"]/Value' => zero_or_one, # Uses ERI Reference Home if not provided
        'extension/FracSensible' => zero_or_one, # Uses ERI Reference Home if not provided
        'extension/FracLatent' => zero_or_one, # Uses ERI Reference Home if not provided
        '../extension/WeekdayScheduleFractions' => zero_or_one, # Uses ERI Reference Home if not provided
        '../extension/WeekendScheduleFractions' => zero_or_one, # Uses ERI Reference Home if not provided
        '../extension/MonthlyScheduleMultipliers' => zero_or_one, # Uses ERI Reference Home if not provided
      },

      # [Television]
      '/HPXML/Building/BuildingDetails/MiscLoads/PlugLoad[PlugLoadType="TV other"]' => {
        'SystemIdentifier' => one, # Required by HPXML schema
        'Load[Units="kWh/year"]/Value' => zero_or_one, # Uses ERI Reference Home if not provided
        '../extension/WeekdayScheduleFractions' => zero_or_one, # Uses ERI Reference Home if not provided
        '../extension/WeekendScheduleFractions' => zero_or_one, # Uses ERI Reference Home if not provided
        '../extension/MonthlyScheduleMultipliers' => zero_or_one, # Uses ERI Reference Home if not provided
      },

    }

    # TODO: Make common across all validators
    # TODO: Profile code for runtime improvements
    errors = []
    requirements.each do |parent, requirement|
      if parent.nil? # Unconditional
        requirement.each do |child, expected_sizes|
          next if expected_sizes.nil?

          xpath = combine_into_xpath(parent, child)
          actual_size = REXML::XPath.first(hpxml_doc, "count(#{xpath})")
          check_number_of_elements(actual_size, expected_sizes, xpath, errors)
        end
      else # Conditional based on parent element existence
        next if hpxml_doc.elements[parent].nil? # Skip if parent element doesn't exist

        hpxml_doc.elements.each(parent) do |parent_element|
          requirement.each do |child, expected_sizes|
            next if expected_sizes.nil?

            xpath = combine_into_xpath(parent, child)
            actual_size = REXML::XPath.first(parent_element, "count(#{child})")
            check_number_of_elements(actual_size, expected_sizes, xpath, errors)
          end
        end
      end
    end

    # Check sum of FractionCoolLoadServeds <= 1
    frac_cool_load = hpxml_doc.elements['sum(/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem/FractionCoolLoadServed/text())']
    frac_cool_load += hpxml_doc.elements['sum(/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/FractionCoolLoadServed/text())']
    if frac_cool_load > 1
      errors << "Expected FractionCoolLoadServed to sum to <= 1, but calculated sum is #{frac_cool_load}."
    end

    # Check sum of FractionHeatLoadServeds <= 1
    frac_heat_load = hpxml_doc.elements['sum(/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem/FractionHeatLoadServed/text())']
    frac_heat_load += hpxml_doc.elements['sum(/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump/FractionHeatLoadServed/text())']
    if frac_heat_load > 1
      errors << "Expected FractionHeatLoadServed to sum to <= 1, but calculated sum is #{frac_heat_load}."
    end

    # Check sum of FractionDHWLoadServed == 1
    frac_dhw_load = hpxml_doc.elements['sum(/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem/FractionDHWLoadServed/text())']
    if (frac_dhw_load > 0) && ((frac_dhw_load < 0.99) || (frac_dhw_load > 1.01))
      errors << "Expected FractionDHWLoadServed to sum to 1, but calculated sum is #{frac_dhw_load}."
    end

    return errors
  end

  def self.check_number_of_elements(actual_size, expected_sizes, xpath, errors)
    if expected_sizes.size > 0
      return if expected_sizes.include?(actual_size)

      errors << "Expected #{expected_sizes} element(s) but found #{actual_size} element(s) for xpath: #{xpath}"
    else
      return if actual_size > 0

      errors << "Expected 1 or more element(s) but found 0 elements for xpath: #{xpath}"
    end
  end

  def self.combine_into_xpath(parent, child)
    if parent.nil?
      return child
    elsif child.start_with?('[')
      return [parent, child].join('')
    end

    return [parent, child].join('/')
  end
end
