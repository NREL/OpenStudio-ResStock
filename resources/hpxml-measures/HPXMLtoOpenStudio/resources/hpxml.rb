# frozen_string_literal: true

'''
Example Usage:

-----------------
Reading from file
-----------------

hpxml = HPXML.new(hpxml_path: ...)

# Singleton elements
puts hpxml.building_construction.number_of_bedrooms

# Array elements
hpxml.walls.each do |wall|
  wall.windows.each do |window|
    puts window.area
  end
end

---------------------
Creating from scratch
---------------------

hpxml = HPXML.new()

# Singleton elements
hpxml.building_construction.number_of_bedrooms = 3
hpxml.building_construction.conditioned_floor_area = 2400

# Array elements
hpxml.walls.clear
hpxml.walls.add(id: "WallNorth", area: 500)
hpxml.walls.add(id: "WallSouth", area: 500)
hpxml.walls.add
hpxml.walls[-1].id = "WallEastWest"
hpxml.walls[-1].area = 1000

# Write file
XMLHelper.write_file(hpxml.to_oga, "out.xml")

'''

require_relative 'version'
require 'ostruct'

# FUTURE: Remove all idref attributes, make object attributes instead
#         E.g., in class Window, :wall_idref => :wall

class HPXML < Object
  HPXML_ATTRS = [:header, :site, :neighbor_buildings, :building_occupancy, :building_construction,
                 :climate_and_risk_zones, :air_infiltration_measurements, :attics, :foundations,
                 :roofs, :rim_joists, :walls, :foundation_walls, :frame_floors, :slabs, :windows,
                 :skylights, :doors, :heating_systems, :cooling_systems, :heat_pumps, :hvac_plant,
                 :hvac_controls, :hvac_distributions, :ventilation_fans, :water_heating_systems,
                 :hot_water_distributions, :water_fixtures, :water_heating, :solar_thermal_systems,
                 :pv_systems, :generators, :clothes_washers, :clothes_dryers, :dishwashers, :refrigerators,
                 :freezers, :dehumidifiers, :cooking_ranges, :ovens, :lighting_groups, :lighting,
                 :ceiling_fans, :pools, :hot_tubs, :plug_loads, :fuel_loads]
  attr_reader(*HPXML_ATTRS, :doc, :errors, :warnings)

  # Constants
  # FUTURE: Move some of these to within child classes (e.g., HPXML::Attic class)
  AirTypeFanCoil = 'fan coil'
  AirTypeGravity = 'gravity'
  AirTypeHighVelocity = 'high velocity'
  AirTypeRegularVelocity = 'regular velocity'
  AtticTypeCathedral = 'CathedralCeiling'
  AtticTypeConditioned = 'ConditionedAttic'
  AtticTypeFlatRoof = 'FlatRoof'
  AtticTypeUnvented = 'UnventedAttic'
  AtticTypeVented = 'VentedAttic'
  CertificationEnergyStar = 'Energy Star'
  ClothesDryerControlTypeMoisture = 'moisture'
  ClothesDryerControlTypeTimer = 'timer'
  ColorDark = 'dark'
  ColorLight = 'light'
  ColorMedium = 'medium'
  ColorMediumDark = 'medium dark'
  ColorReflective = 'reflective'
  DehumidifierTypePortable = 'portable'
  DehumidifierTypeWholeHome = 'whole-home'
  DHWRecirControlTypeManual = 'manual demand control'
  DHWRecirControlTypeNone = 'no control'
  DHWRecirControlTypeSensor = 'presence sensor demand control'
  DHWRecirControlTypeTemperature = 'temperature'
  DHWRecirControlTypeTimer = 'timer'
  DHWDistTypeRecirc = 'Recirculation'
  DHWDistTypeStandard = 'Standard'
  DuctInsulationMaterialUnknown = 'Unknown'
  DuctInsulationMaterialNone = 'None'
  DuctLeakageTotal = 'total'
  DuctLeakageToOutside = 'to outside'
  DuctTypeReturn = 'return'
  DuctTypeSupply = 'supply'
  DWHRFacilitiesConnectedAll = 'all'
  DWHRFacilitiesConnectedOne = 'one'
  ExteriorShadingTypeSolarScreens = 'solar screens'
  FoundationTypeAmbient = 'Ambient'
  FoundationTypeBasementConditioned = 'ConditionedBasement'
  FoundationTypeBasementUnconditioned = 'UnconditionedBasement'
  FoundationTypeCrawlspaceUnvented = 'UnventedCrawlspace'
  FoundationTypeCrawlspaceVented = 'VentedCrawlspace'
  FoundationTypeSlab = 'SlabOnGrade'
  FrameFloorOtherSpaceAbove = 'above'
  FrameFloorOtherSpaceBelow = 'below'
  FuelLoadTypeGrill = 'grill'
  FuelLoadTypeLighting = 'lighting'
  FuelLoadTypeFireplace = 'fireplace'
  FuelTypeCoal = 'coal'
  FuelTypeCoalAnthracite = 'anthracite coal'
  FuelTypeCoalBituminous = 'bituminous coal'
  FuelTypeCoke = 'coke'
  FuelTypeDiesel = 'diesel'
  FuelTypeElectricity = 'electricity'
  FuelTypeKerosene = 'kerosene'
  FuelTypeNaturalGas = 'natural gas'
  FuelTypeOil = 'fuel oil'
  FuelTypeOil1 = 'fuel oil 1'
  FuelTypeOil2 = 'fuel oil 2'
  FuelTypeOil4 = 'fuel oil 4'
  FuelTypeOil5or6 = 'fuel oil 5/6'
  FuelTypePropane = 'propane'
  FuelTypeWoodCord = 'wood'
  FuelTypeWoodPellets = 'wood pellets'
  HeaterTypeElectricResistance = 'electric resistance'
  HeaterTypeGas = 'gas fired'
  HeaterTypeHeatPump = 'heat pump'
  HVACCompressorTypeSingleStage = 'single stage'
  HVACCompressorTypeTwoStage = 'two stage'
  HVACCompressorTypeVariableSpeed = 'variable speed'
  HVACControlTypeManual = 'manual thermostat'
  HVACControlTypeProgrammable = 'programmable thermostat'
  HVACDistributionTypeAir = 'AirDistribution'
  HVACDistributionTypeDSE = 'DSE'
  HVACDistributionTypeHydronic = 'HydronicDistribution'
  HVACTypeBoiler = 'Boiler'
  HVACTypeCentralAirConditioner = 'central air conditioner'
  HVACTypeChiller = 'chiller'
  HVACTypeCoolingTower = 'cooling tower'
  HVACTypeElectricResistance = 'ElectricResistance'
  HVACTypeEvaporativeCooler = 'evaporative cooler'
  HVACTypeFireplace = 'Fireplace'
  HVACTypeFixedHeater = 'FixedHeater'
  HVACTypeFloorFurnace = 'FloorFurnace'
  HVACTypeFurnace = 'Furnace'
  HVACTypeHeatPumpAirToAir = 'air-to-air'
  HVACTypeHeatPumpGroundToAir = 'ground-to-air'
  HVACTypeHeatPumpMiniSplit = 'mini-split'
  HVACTypeHeatPumpWaterLoopToAir = 'water-loop-to-air'
  HVACTypeMiniSplitAirConditioner = 'mini-split'
  HVACTypePortableHeater = 'PortableHeater'
  HVACTypeRoomAirConditioner = 'room air conditioner'
  HVACTypeStove = 'Stove'
  HVACTypeWallFurnace = 'WallFurnace'
  HydronicTypeBaseboard = 'baseboard'
  HydronicTypeRadiantCeiling = 'radiant ceiling'
  HydronicTypeRadiantFloor = 'radiant floor'
  HydronicTypeRadiator = 'radiator'
  HydronicTypeWaterLoop = 'water loop'
  InteriorFinishGypsumBoard = 'gypsum board'
  InteriorFinishGypsumCompositeBoard = 'gypsum composite board'
  InteriorFinishNone = 'none'
  InteriorFinishPlaster = 'plaster'
  InteriorFinishWood = 'wood'
  LeakinessTight = 'tight'
  LeakinessAverage = 'average'
  LightingTypeCFL = 'CompactFluorescent'
  LightingTypeLED = 'LightEmittingDiode'
  LightingTypeLFL = 'FluorescentTube'
  LocationAtticUnconditioned = 'attic - unconditioned'
  LocationAtticUnvented = 'attic - unvented'
  LocationAtticVented = 'attic - vented'
  LocationBasementConditioned = 'basement - conditioned'
  LocationBasementUnconditioned = 'basement - unconditioned'
  LocationBath = 'bath'
  LocationCrawlspaceUnvented = 'crawlspace - unvented'
  LocationCrawlspaceVented = 'crawlspace - vented'
  LocationExterior = 'exterior'
  LocationExteriorWall = 'exterior wall'
  LocationGarage = 'garage'
  LocationGround = 'ground'
  LocationInterior = 'interior'
  LocationKitchen = 'kitchen'
  LocationLivingSpace = 'living space'
  LocationOtherExterior = 'other exterior'
  LocationOtherHousingUnit = 'other housing unit'
  LocationOtherHeatedSpace = 'other heated space'
  LocationOtherMultifamilyBufferSpace = 'other multifamily buffer space'
  LocationOtherNonFreezingSpace = 'other non-freezing space'
  LocationOutside = 'outside'
  LocationRoof = 'roof'
  LocationRoofDeck = 'roof deck'
  LocationUnconditionedSpace = 'unconditioned space'
  LocationUnderSlab = 'under slab'
  MechVentTypeBalanced = 'balanced'
  MechVentTypeCFIS = 'central fan integrated supply'
  MechVentTypeERV = 'energy recovery ventilator'
  MechVentTypeExhaust = 'exhaust only'
  MechVentTypeHRV = 'heat recovery ventilator'
  MechVentTypeSupply = 'supply only'
  OrientationEast = 'east'
  OrientationNorth = 'north'
  OrientationNortheast = 'northeast'
  OrientationNorthwest = 'northwest'
  OrientationSouth = 'south'
  OrientationSoutheast = 'southeast'
  OrientationSouthwest = 'southwest'
  OrientationWest = 'west'
  PlugLoadTypeElectricVehicleCharging = 'electric vehicle charging'
  PlugLoadTypeOther = 'other'
  PlugLoadTypeTelevision = 'TV other'
  PlugLoadTypeWellPump = 'well pump'
  PVModuleTypePremium = 'premium'
  PVModuleTypeStandard = 'standard'
  PVModuleTypeThinFilm = 'thin film'
  PVTrackingTypeFixed = 'fixed'
  PVTrackingType1Axis = '1-axis'
  PVTrackingType1AxisBacktracked = '1-axis backtracked'
  PVTrackingType2Axis = '2-axis'
  ResidentialTypeApartment = 'apartment unit'
  ResidentialTypeManufactured = 'manufactured home'
  ResidentialTypeSFA = 'single-family attached'
  ResidentialTypeSFD = 'single-family detached'
  RoofTypeAsphaltShingles = 'asphalt or fiberglass shingles'
  RoofTypeConcrete = 'concrete'
  RoofTypeCool = 'cool roof'
  RoofTypeClayTile = 'slate or tile shingles'
  RoofTypeEPS = 'expanded polystyrene sheathing'
  RoofTypeMetal = 'metal surfacing'
  RoofTypePlasticRubber = 'plastic/rubber/synthetic sheeting'
  RoofTypeShingles = 'shingles'
  RoofTypeWoodShingles = 'wood shingles or shakes'
  ShieldingExposed = 'exposed'
  ShieldingNormal = 'normal'
  ShieldingWellShielded = 'well-shielded'
  SidingTypeAluminum = 'aluminum siding'
  SidingTypeAsbestos = 'asbestos siding'
  SidingTypeBrick = 'brick veneer'
  SidingTypeCompositeShingle = 'composite shingle siding'
  SidingTypeFiberCement = 'fiber cement siding'
  SidingTypeMasonite = 'masonite siding'
  SidingTypeNone = 'none'
  SidingTypeStucco = 'stucco'
  SidingTypeSyntheticStucco = 'synthetic stucco'
  SidingTypeVinyl = 'vinyl siding'
  SidingTypeWood = 'wood siding'
  SiteTypeUrban = 'urban'
  SiteTypeSuburban = 'suburban'
  SiteTypeRural = 'rural'
  SolarThermalLoopTypeDirect = 'liquid direct'
  SolarThermalLoopTypeIndirect = 'liquid indirect'
  SolarThermalLoopTypeThermosyphon = 'passive thermosyphon'
  SolarThermalTypeDoubleGlazing = 'double glazing black'
  SolarThermalTypeEvacuatedTube = 'evacuated tube'
  SolarThermalTypeICS = 'integrated collector storage'
  SolarThermalTypeSingleGlazing = 'single glazing black'
  TypeNone = 'none'
  TypeUnknown = 'unknown'
  UnitsACH = 'ACH'
  UnitsACHNatural = 'ACHnatural'
  UnitsAFUE = 'AFUE'
  UnitsCFM = 'CFM'
  UnitsCFM25 = 'CFM25'
  UnitsCOP = 'COP'
  UnitsEER = 'EER'
  UnitsCEER = 'CEER'
  UnitsHSPF = 'HSPF'
  UnitsKwhPerYear = 'kWh/year'
  UnitsKwPerTon = 'kW/ton'
  UnitsPercent = 'Percent'
  UnitsSEER = 'SEER'
  UnitsSLA = 'SLA'
  UnitsThermPerYear = 'therm/year'
  WallTypeAdobe = 'Adobe'
  WallTypeBrick = 'StructuralBrick'
  WallTypeCMU = 'ConcreteMasonryUnit'
  WallTypeConcrete = 'SolidConcrete'
  WallTypeDoubleWoodStud = 'DoubleWoodStud'
  WallTypeICF = 'InsulatedConcreteForms'
  WallTypeLog = 'LogWall'
  WallTypeSIP = 'StructurallyInsulatedPanel'
  WallTypeSteelStud = 'SteelFrame'
  WallTypeStone = 'Stone'
  WallTypeStrawBale = 'StrawBale'
  WallTypeWoodStud = 'WoodStud'
  WaterFixtureTypeFaucet = 'faucet'
  WaterFixtureTypeShowerhead = 'shower head'
  WaterHeaterTypeCombiStorage = 'space-heating boiler with storage tank'
  WaterHeaterTypeCombiTankless = 'space-heating boiler with tankless coil'
  WaterHeaterTypeHeatPump = 'heat pump water heater'
  WaterHeaterTypeTankless = 'instantaneous water heater'
  WaterHeaterTypeStorage = 'storage water heater'
  WaterHeaterUsageBinVerySmall = 'very small'
  WaterHeaterUsageBinLow = 'low'
  WaterHeaterUsageBinMedium = 'medium'
  WaterHeaterUsageBinHigh = 'high'
  WindowFrameTypeAluminum = 'Aluminum'
  WindowFrameTypeComposite = 'Composite'
  WindowFrameTypeFiberglass = 'Fiberglass'
  WindowFrameTypeMetal = 'Metal'
  WindowFrameTypeVinyl = 'Vinyl'
  WindowFrameTypeWood = 'Wood'
  WindowGasAir = 'air'
  WindowGasArgon = 'argon'
  WindowGlazingLowE = 'low-e'
  WindowGlazingReflective = 'reflective'
  WindowGlazingTintedReflective = 'tinted/reflective'
  WindowLayersDoublePane = 'double-pane'
  WindowLayersSinglePane = 'single-pane'
  WindowLayersTriplePane = 'triple-pane'
  WindowClassArchitectural = 'architectural'
  WindowClassCommercial = 'commercial'
  WindowClassHeavyCommercial = 'heavy commercial'
  WindowClassResidential = 'residential'
  WindowClassLightCommercial = 'light commercial'

  def initialize(hpxml_path: nil, schematron_validators: [], collapse_enclosure: true, building_id: nil)
    @doc = nil
    @hpxml_path = hpxml_path
    @errors = []
    @warnings = []

    hpxml = nil
    if not hpxml_path.nil?
      @doc = XMLHelper.parse_file(hpxml_path)

      # Check HPXML version
      hpxml = XMLHelper.get_element(@doc, '/HPXML')
      Version.check_hpxml_version(XMLHelper.get_attribute_value(hpxml, 'schemaVersion'))

      # Validate against Schematron docs
      @errors, @warnings = validate_against_schematron(schematron_validators: schematron_validators)
      return unless @errors.empty?

      # Handle multiple buildings
      if XMLHelper.get_elements(hpxml, 'Building').size > 1
        if building_id.nil?
          @errors << 'Multiple Building elements defined in HPXML file; Building ID argument must be provided.'
          return unless @errors.empty?
        end

        # Discard all Building elements except the one of interest
        XMLHelper.get_elements(hpxml, 'Building').reverse_each do |building|
          next if XMLHelper.get_attribute_value(XMLHelper.get_element(building, 'BuildingID'), 'id') == building_id

          building.remove
        end
        if XMLHelper.get_elements(hpxml, 'Building').size == 0
          @errors << "Could not find Building element with ID '#{building_id}'."
          return unless @errors.empty?
        end
      end
    end

    # Create/populate child objects
    from_oga(hpxml)

    # Check for additional errors (those hard to check via Schematron)
    @errors += check_for_errors()
    return unless @errors.empty?

    # Clean up
    delete_tiny_surfaces()
    delete_adiabatic_subsurfaces()
    if collapse_enclosure
      collapse_enclosure_surfaces()
    end
  end

  def hvac_systems
    return (@heating_systems + @cooling_systems + @heat_pumps)
  end

  def has_space_type(space_type)
    # Look for surfaces attached to this space type
    (@roofs + @rim_joists + @walls + @foundation_walls + @frame_floors + @slabs).each do |surface|
      return true if surface.interior_adjacent_to == space_type
      return true if surface.exterior_adjacent_to == space_type
    end
    return false
  end

  def has_fuel_access
    @site.fuels.each do |fuel|
      if fuel != FuelTypeElectricity
        return true
      end
    end
    return false
  end

  def predominant_heating_fuel
    fuel_fracs = {}
    @heating_systems.each do |heating_system|
      fuel = heating_system.heating_system_fuel
      fuel_fracs[fuel] = 0.0 if fuel_fracs[fuel].nil?
      fuel_fracs[fuel] += heating_system.fraction_heat_load_served.to_f
    end
    @heat_pumps.each do |heat_pump|
      fuel = heat_pump.heat_pump_fuel
      fuel_fracs[fuel] = 0.0 if fuel_fracs[fuel].nil?
      fuel_fracs[fuel] += heat_pump.fraction_heat_load_served.to_f
    end
    return FuelTypeElectricity if fuel_fracs.empty?
    return FuelTypeElectricity if fuel_fracs[FuelTypeElectricity].to_f > 0.5

    # Choose fossil fuel
    fuel_fracs.delete FuelTypeElectricity
    return fuel_fracs.key(fuel_fracs.values.max)
  end

  def predominant_water_heating_fuel
    fuel_fracs = {}
    @water_heating_systems.each do |water_heating_system|
      fuel = water_heating_system.fuel_type
      if fuel.nil? # Combi boiler
        fuel = water_heating_system.related_hvac_system.heating_system_fuel
      end
      fuel_fracs[fuel] = 0.0 if fuel_fracs[fuel].nil?
      fuel_fracs[fuel] += water_heating_system.fraction_dhw_load_served
    end
    return FuelTypeElectricity if fuel_fracs.empty?
    return FuelTypeElectricity if fuel_fracs[FuelTypeElectricity].to_f > 0.5

    # Choose fossil fuel
    fuel_fracs.delete FuelTypeElectricity
    return fuel_fracs.key(fuel_fracs.values.max)
  end

  def fraction_of_windows_operable()
    # Calculates the fraction of windows that are operable.
    # Since we don't have quantity available, we use area as an approximation.
    window_area_total = @windows.map { |w| w.area }.sum(0.0)
    window_area_operable = @windows.map { |w| w.fraction_operable * w.area }.sum(0.0)
    if window_area_total <= 0
      return 0.0
    end

    return window_area_operable / window_area_total
  end

  def total_fraction_cool_load_served()
    return @cooling_systems.total_fraction_cool_load_served + @heat_pumps.total_fraction_cool_load_served
  end

  def total_fraction_heat_load_served()
    return @heating_systems.total_fraction_heat_load_served + @heat_pumps.total_fraction_heat_load_served
  end

  def has_walkout_basement()
    has_conditioned_basement = has_space_type(LocationBasementConditioned)
    ncfl = @building_construction.number_of_conditioned_floors
    ncfl_ag = @building_construction.number_of_conditioned_floors_above_grade
    return (has_conditioned_basement && (ncfl == ncfl_ag))
  end

  def thermal_boundary_wall_areas()
    above_grade_area = 0.0 # Thermal boundary walls not in contact with soil
    below_grade_area = 0.0 # Thermal boundary walls in contact with soil

    (@walls + @rim_joists).each do |wall|
      if wall.is_thermal_boundary
        above_grade_area += wall.area
      end
    end

    @foundation_walls.each do |foundation_wall|
      next unless foundation_wall.is_thermal_boundary

      height = foundation_wall.height
      bg_depth = foundation_wall.depth_below_grade
      above_grade_area += (height - bg_depth) / height * foundation_wall.area
      below_grade_area += bg_depth / height * foundation_wall.area
    end

    return above_grade_area, below_grade_area
  end

  def common_wall_area()
    # Wall area for walls adjacent to Unrated Conditioned Space, not including
    # foundation walls.
    area = 0.0

    (@walls + @rim_joists).each do |wall|
      if wall.exterior_adjacent_to == HPXML::LocationOtherHousingUnit
        area += wall.area
      end
    end

    return area
  end

  def compartmentalization_boundary_areas()
    # Returns the infiltration compartmentalization boundary areas
    total_area = 0.0 # Total surface area that bounds the Infiltration Volume
    exterior_area = 0.0 # Same as above excluding surfaces attached to garage or other housing units

    # Determine which spaces are within infiltration volume
    spaces_within_infil_volume = [LocationLivingSpace, LocationBasementConditioned]
    @attics.each do |attic|
      next unless [AtticTypeUnvented].include? attic.attic_type
      next unless attic.within_infiltration_volume

      spaces_within_infil_volume << attic.to_location
    end
    @foundations.each do |foundation|
      next unless [FoundationTypeBasementUnconditioned, FoundationTypeCrawlspaceUnvented].include? foundation.foundation_type
      next unless foundation.within_infiltration_volume

      spaces_within_infil_volume << foundation.to_location
    end

    # Get surfaces bounding infiltration volume
    spaces_within_infil_volume.each do |space_type|
      (@roofs + @rim_joists + @walls + @foundation_walls + @frame_floors + @slabs).each do |surface|
        next unless [surface.interior_adjacent_to, surface.exterior_adjacent_to].include? space_type

        # Exclude surfaces between two spaces that are both within infiltration volume
        next if spaces_within_infil_volume.include?(surface.interior_adjacent_to) && spaces_within_infil_volume.include?(surface.exterior_adjacent_to)

        # Update Compartmentalization Boundary areas
        total_area += surface.area
        if not [LocationGarage, LocationOtherHousingUnit, LocationOtherHeatedSpace,
                LocationOtherMultifamilyBufferSpace, LocationOtherNonFreezingSpace].include? surface.exterior_adjacent_to
          exterior_area += surface.area
        end
      end
    end

    return total_area, exterior_area
  end

  def inferred_infiltration_height(infil_volume)
    # Infiltration height: vertical distance between lowest and highest above-grade points within the pressure boundary.
    # Height is inferred from available HPXML properties.
    # The WithinInfiltrationVolume properties are intentionally ignored for now.
    # FUTURE: Move into AirInfiltrationMeasurement class?
    cfa = @building_construction.conditioned_floor_area
    ncfl_ag = @building_construction.number_of_conditioned_floors_above_grade
    if has_walkout_basement()
      infil_height = ncfl_ag * infil_volume / cfa
    else
      # Calculate maximum above-grade height of conditioned basement walls
      max_cond_bsmt_wall_height_ag = 0.0
      @foundation_walls.each do |foundation_wall|
        next unless foundation_wall.is_exterior && (foundation_wall.interior_adjacent_to == LocationBasementConditioned)

        height_ag = foundation_wall.height - foundation_wall.depth_below_grade
        next unless height_ag > max_cond_bsmt_wall_height_ag

        max_cond_bsmt_wall_height_ag = height_ag
      end
      # Add assumed rim joist height
      cond_bsmt_rim_joist_height = 0
      @rim_joists.each do |rim_joist|
        next unless rim_joist.is_exterior && (rim_joist.interior_adjacent_to == LocationBasementConditioned)

        cond_bsmt_rim_joist_height = UnitConversions.convert(9, 'in', 'ft')
      end
      infil_height = ncfl_ag * infil_volume / cfa + max_cond_bsmt_wall_height_ag + cond_bsmt_rim_joist_height
    end
    return infil_height
  end

  def to_oga()
    @doc = _create_oga_document()
    @header.to_oga(@doc)
    @site.to_oga(@doc)
    @neighbor_buildings.to_oga(@doc)
    @building_occupancy.to_oga(@doc)
    @building_construction.to_oga(@doc)
    @climate_and_risk_zones.to_oga(@doc)
    @air_infiltration_measurements.to_oga(@doc)
    @attics.to_oga(@doc)
    @foundations.to_oga(@doc)
    @roofs.to_oga(@doc)
    @rim_joists.to_oga(@doc)
    @walls.to_oga(@doc)
    @foundation_walls.to_oga(@doc)
    @frame_floors.to_oga(@doc)
    @slabs.to_oga(@doc)
    @windows.to_oga(@doc)
    @skylights.to_oga(@doc)
    @doors.to_oga(@doc)
    @heating_systems.to_oga(@doc)
    @cooling_systems.to_oga(@doc)
    @heat_pumps.to_oga(@doc)
    @hvac_plant.to_oga(@doc)
    @hvac_controls.to_oga(@doc)
    @hvac_distributions.to_oga(@doc)
    @ventilation_fans.to_oga(@doc)
    @water_heating_systems.to_oga(@doc)
    @hot_water_distributions.to_oga(@doc)
    @water_fixtures.to_oga(@doc)
    @water_heating.to_oga(@doc)
    @solar_thermal_systems.to_oga(@doc)
    @pv_systems.to_oga(@doc)
    @generators.to_oga(@doc)
    @clothes_washers.to_oga(@doc)
    @clothes_dryers.to_oga(@doc)
    @dishwashers.to_oga(@doc)
    @refrigerators.to_oga(@doc)
    @freezers.to_oga(@doc)
    @dehumidifiers.to_oga(@doc)
    @cooking_ranges.to_oga(@doc)
    @ovens.to_oga(@doc)
    @lighting_groups.to_oga(@doc)
    @ceiling_fans.to_oga(@doc)
    @lighting.to_oga(@doc)
    @pools.to_oga(@doc)
    @hot_tubs.to_oga(@doc)
    @plug_loads.to_oga(@doc)
    @fuel_loads.to_oga(@doc)
    return @doc
  end

  def from_oga(hpxml)
    @header = Header.new(self, hpxml)
    @site = Site.new(self, hpxml)
    @neighbor_buildings = NeighborBuildings.new(self, hpxml)
    @building_occupancy = BuildingOccupancy.new(self, hpxml)
    @building_construction = BuildingConstruction.new(self, hpxml)
    @climate_and_risk_zones = ClimateandRiskZones.new(self, hpxml)
    @air_infiltration_measurements = AirInfiltrationMeasurements.new(self, hpxml)
    @attics = Attics.new(self, hpxml)
    @foundations = Foundations.new(self, hpxml)
    @roofs = Roofs.new(self, hpxml)
    @rim_joists = RimJoists.new(self, hpxml)
    @walls = Walls.new(self, hpxml)
    @foundation_walls = FoundationWalls.new(self, hpxml)
    @frame_floors = FrameFloors.new(self, hpxml)
    @slabs = Slabs.new(self, hpxml)
    @windows = Windows.new(self, hpxml)
    @skylights = Skylights.new(self, hpxml)
    @doors = Doors.new(self, hpxml)
    @heating_systems = HeatingSystems.new(self, hpxml)
    @cooling_systems = CoolingSystems.new(self, hpxml)
    @heat_pumps = HeatPumps.new(self, hpxml)
    @hvac_plant = HVACPlant.new(self, hpxml)
    @hvac_controls = HVACControls.new(self, hpxml)
    @hvac_distributions = HVACDistributions.new(self, hpxml)
    @ventilation_fans = VentilationFans.new(self, hpxml)
    @water_heating_systems = WaterHeatingSystems.new(self, hpxml)
    @hot_water_distributions = HotWaterDistributions.new(self, hpxml)
    @water_fixtures = WaterFixtures.new(self, hpxml)
    @water_heating = WaterHeating.new(self, hpxml)
    @solar_thermal_systems = SolarThermalSystems.new(self, hpxml)
    @pv_systems = PVSystems.new(self, hpxml)
    @generators = Generators.new(self, hpxml)
    @clothes_washers = ClothesWashers.new(self, hpxml)
    @clothes_dryers = ClothesDryers.new(self, hpxml)
    @dishwashers = Dishwashers.new(self, hpxml)
    @refrigerators = Refrigerators.new(self, hpxml)
    @freezers = Freezers.new(self, hpxml)
    @dehumidifiers = Dehumidifiers.new(self, hpxml)
    @cooking_ranges = CookingRanges.new(self, hpxml)
    @ovens = Ovens.new(self, hpxml)
    @lighting_groups = LightingGroups.new(self, hpxml)
    @ceiling_fans = CeilingFans.new(self, hpxml)
    @lighting = Lighting.new(self, hpxml)
    @pools = Pools.new(self, hpxml)
    @hot_tubs = HotTubs.new(self, hpxml)
    @plug_loads = PlugLoads.new(self, hpxml)
    @fuel_loads = FuelLoads.new(self, hpxml)
  end

  # Class to store additional properties on an HPXML object that are not intended
  # to end up in the HPXML file. For example, you can store the OpenStudio::Model::Space
  # object for an appliance.
  class AdditionalProperties < OpenStruct
    def method_missing(meth, *args)
      # Complain if no value has been set rather than just returning nil
      raise NoMethodError, "undefined method '#{meth}' for #{self}" unless meth.to_s.end_with?('=')

      super
    end
  end

  # HPXML Standard Element (e.g., Roof)
  class BaseElement
    attr_accessor(:hpxml_object, :additional_properties)

    def initialize(hpxml_object, oga_element = nil, **kwargs)
      @hpxml_object = hpxml_object
      @additional_properties = AdditionalProperties.new

      # Automatically add :foo_isdefaulted attributes to class
      self.class::ATTRS.each do |attribute|
        next if attribute.to_s.end_with? '_isdefaulted'

        attr = "#{attribute}_isdefaulted".to_sym
        next if self.class::ATTRS.include? attr

        # Add attribute to ATTRS and class
        self.class::ATTRS << attr
        create_attr(attr.to_s) # From https://stackoverflow.com/a/4082937
      end

      if not oga_element.nil?
        # Set values from HPXML Oga element
        from_oga(oga_element)
      else
        # Set values from **kwargs
        kwargs.each do |k, v|
          send(k.to_s + '=', v)
        end
      end
    end

    def create_method(name, &block)
      self.class.send(:define_method, name, &block)
    end

    def create_attr(name)
      create_method("#{name}=".to_sym) { |val| instance_variable_set('@' + name, val) }
      create_method(name.to_sym) { instance_variable_get('@' + name) }
    end

    def to_h
      h = {}
      self.class::ATTRS.each do |attribute|
        h[attribute] = send(attribute)
      end
      return h
    end

    def to_s
      return to_h.to_s
    end

    def nil?
      # Returns true if all attributes are nil
      to_h.each do |k, v|
        next if k.to_s.end_with? '_isdefaulted'
        return false if not v.nil?
      end
      return true
    end
  end

  # HPXML Array Element (e.g., Roofs)
  class BaseArrayElement < Array
    attr_accessor(:hpxml_object, :additional_properties)

    def initialize(hpxml_object, oga_element = nil)
      @hpxml_object = hpxml_object
      @additional_properties = AdditionalProperties.new

      if not oga_element.nil?
        # Set values from HPXML Oga element
        from_oga(oga_element)
      end
    end

    def check_for_errors
      errors = []
      each do |child|
        if not child.respond_to? :check_for_errors
          fail "Need to add 'check_for_errors' method to #{child.class} class."
        end

        errors += child.check_for_errors
      end
      return errors
    end

    def to_oga(doc)
      each do |child|
        child.to_oga(doc)
      end
    end

    def to_s
      return map { |x| x.to_s }
    end
  end

  class Header < BaseElement
    ATTRS = [:xml_type, :xml_generated_by, :created_date_and_time, :transaction,
             :software_program_used, :software_program_version, :eri_calculation_version,
             :eri_design, :timestep, :building_id, :event_type, :state_code,
             :sim_begin_month, :sim_begin_day, :sim_end_month, :sim_end_day, :sim_calendar_year,
             :dst_enabled, :dst_begin_month, :dst_begin_day, :dst_end_month, :dst_end_day,
             :use_max_load_for_heat_pumps, :allow_increased_fixed_capacities,
             :apply_ashrae140_assumptions, :energystar_calculation_version, :schedules_path]
    attr_accessor(*ATTRS)

    def check_for_errors
      errors = []

      if not @timestep.nil?
        valid_tsteps = [60, 30, 20, 15, 12, 10, 6, 5, 4, 3, 2, 1]
        if not valid_tsteps.include? @timestep
          errors << "Timestep (#{@timestep}) must be one of: #{valid_tsteps.join(', ')}."
        end
      end

      errors += HPXML::check_dates('Run Period', @sim_begin_month, @sim_begin_day, @sim_end_month, @sim_end_day)

      if (not @sim_begin_month.nil?) && (not @sim_end_month.nil?)
        if @sim_begin_month > @sim_end_month
          errors << "Run Period Begin Month (#{@sim_begin_month}) cannot come after Run Period End Month (#{@sim_end_month})."
        end

        if (not @sim_begin_day.nil?) && (not @sim_end_day.nil?)
          if @sim_begin_month == @sim_end_month && @sim_begin_day > @sim_end_day
            errors << "Run Period Begin Day of Month (#{@sim_begin_day}) cannot come after Run Period End Day of Month (#{@sim_end_day}) for the same month (#{begin_month})."
          end
        end
      end

      errors += HPXML::check_dates('Daylight Saving', @dst_begin_month, @dst_begin_day, @dst_end_month, @dst_end_day)

      return errors
    end

    def to_oga(doc)
      return if nil?

      hpxml = XMLHelper.get_element(doc, '/HPXML')
      header = XMLHelper.add_element(hpxml, 'XMLTransactionHeaderInformation')
      XMLHelper.add_element(header, 'XMLType', @xml_type, :string)
      XMLHelper.add_element(header, 'XMLGeneratedBy', @xml_generated_by, :string)
      if not @created_date_and_time.nil?
        XMLHelper.add_element(header, 'CreatedDateAndTime', @created_date_and_time, :string)
      else
        XMLHelper.add_element(header, 'CreatedDateAndTime', Time.now.strftime('%Y-%m-%dT%H:%M:%S%:z'), :string)
      end
      XMLHelper.add_element(header, 'Transaction', @transaction, :string)

      software_info = XMLHelper.add_element(hpxml, 'SoftwareInfo')
      XMLHelper.add_element(software_info, 'SoftwareProgramUsed', @software_program_used, :string) unless @software_program_used.nil?
      XMLHelper.add_element(software_info, 'SoftwareProgramVersion', @software_program_version, :string) unless @software_program_version.nil?
      if not @apply_ashrae140_assumptions.nil?
        extension = XMLHelper.create_elements_as_needed(software_info, ['extension'])
        XMLHelper.add_element(extension, 'ApplyASHRAE140Assumptions', @apply_ashrae140_assumptions, :boolean) unless @apply_ashrae140_assumptions.nil?
      end
      if (not @eri_calculation_version.nil?) || (not @eri_design.nil?)
        extension = XMLHelper.create_elements_as_needed(software_info, ['extension'])
        eri_calculation = XMLHelper.add_element(extension, 'ERICalculation')
        XMLHelper.add_element(eri_calculation, 'Version', @eri_calculation_version, :string) unless @eri_calculation_version.nil?
        XMLHelper.add_element(eri_calculation, 'Design', @eri_design, :string) unless @eri_design.nil?
      end
      if not @energystar_calculation_version.nil?
        extension = XMLHelper.create_elements_as_needed(software_info, ['extension'])
        energystar_calculation = XMLHelper.add_element(extension, 'EnergyStarCalculation')
        XMLHelper.add_element(energystar_calculation, 'Version', @energystar_calculation_version, :string) unless @energystar_calculation_version.nil?
      end
      if (not @timestep.nil?) || (not @sim_begin_month.nil?) || (not @sim_begin_day.nil?) || (not @sim_end_month.nil?) || (not @sim_end_day.nil?) || (not @dst_enabled.nil?) || (not @dst_begin_month.nil?) || (not @dst_begin_day.nil?) || (not @dst_end_month.nil?) || (not @dst_end_day.nil?)
        extension = XMLHelper.create_elements_as_needed(software_info, ['extension'])
        simulation_control = XMLHelper.add_element(extension, 'SimulationControl')
        XMLHelper.add_element(simulation_control, 'Timestep', @timestep, :integer, @timestep_isdefaulted) unless @timestep.nil?
        XMLHelper.add_element(simulation_control, 'BeginMonth', @sim_begin_month, :integer, @sim_begin_month_isdefaulted) unless @sim_begin_month.nil?
        XMLHelper.add_element(simulation_control, 'BeginDayOfMonth', @sim_begin_day, :integer, @sim_begin_day_isdefaulted) unless @sim_begin_day.nil?
        XMLHelper.add_element(simulation_control, 'EndMonth', @sim_end_month, :integer, @sim_end_month_isdefaulted) unless @sim_end_month.nil?
        XMLHelper.add_element(simulation_control, 'EndDayOfMonth', @sim_end_day, :integer, @sim_end_day_isdefaulted) unless @sim_end_day.nil?
        XMLHelper.add_element(simulation_control, 'CalendarYear', @sim_calendar_year, :integer, @sim_calendar_year_isdefaulted) unless @sim_calendar_year.nil?
        if (not @dst_enabled.nil?) || (not @dst_begin_month.nil?) || (not @dst_begin_day.nil?) || (not @dst_end_month.nil?) || (not @dst_end_day.nil?)
          daylight_saving = XMLHelper.add_element(simulation_control, 'DaylightSaving')
          XMLHelper.add_element(daylight_saving, 'Enabled', @dst_enabled, :boolean, @dst_enabled_isdefaulted) unless @dst_enabled.nil?
          XMLHelper.add_element(daylight_saving, 'BeginMonth', @dst_begin_month, :integer, @dst_begin_month_isdefaulted) unless @dst_begin_month.nil?
          XMLHelper.add_element(daylight_saving, 'BeginDayOfMonth', @dst_begin_day, :integer, @dst_begin_day_isdefaulted) unless @dst_begin_day.nil?
          XMLHelper.add_element(daylight_saving, 'EndMonth', @dst_end_month, :integer, @dst_end_month_isdefaulted) unless @dst_end_month.nil?
          XMLHelper.add_element(daylight_saving, 'EndDayOfMonth', @dst_end_day, :integer, @dst_end_day_isdefaulted) unless @dst_end_day.nil?
        end
      end
      if (not @use_max_load_for_heat_pumps.nil?) || (not @allow_increased_fixed_capacities.nil?)
        extension = XMLHelper.create_elements_as_needed(software_info, ['extension'])
        hvac_sizing_control = XMLHelper.add_element(extension, 'HVACSizingControl')
        XMLHelper.add_element(hvac_sizing_control, 'UseMaxLoadForHeatPumps', @use_max_load_for_heat_pumps, :boolean, @use_max_load_for_heat_pumps_isdefaulted) unless @use_max_load_for_heat_pumps.nil?
        XMLHelper.add_element(hvac_sizing_control, 'AllowIncreasedFixedCapacities', @allow_increased_fixed_capacities, :boolean, @allow_increased_fixed_capacities_isdefaulted) unless @allow_increased_fixed_capacities.nil?
      end
      if not @schedules_path.nil?
        extension = XMLHelper.create_elements_as_needed(software_info, ['extension'])
        XMLHelper.add_element(extension, 'OccupancySchedulesCSVPath', @schedules_path, :string) unless @schedules_path.nil?
      end

      building = XMLHelper.add_element(hpxml, 'Building')
      building_building_id = XMLHelper.add_element(building, 'BuildingID')
      XMLHelper.add_attribute(building_building_id, 'id', @building_id)
      if not @state_code.nil?
        site = XMLHelper.add_element(building, 'Site')
        site_id = XMLHelper.add_element(site, 'SiteID')
        XMLHelper.add_attribute(site_id, 'id', 'SiteID')
        address = XMLHelper.add_element(site, 'Address')
        XMLHelper.add_element(address, 'StateCode', @state_code, :string)
      end
      project_status = XMLHelper.add_element(building, 'ProjectStatus')
      XMLHelper.add_element(project_status, 'EventType', @event_type, :string)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      @xml_type = XMLHelper.get_value(hpxml, 'XMLTransactionHeaderInformation/XMLType', :string)
      @xml_generated_by = XMLHelper.get_value(hpxml, 'XMLTransactionHeaderInformation/XMLGeneratedBy', :string)
      @created_date_and_time = XMLHelper.get_value(hpxml, 'XMLTransactionHeaderInformation/CreatedDateAndTime', :string)
      @transaction = XMLHelper.get_value(hpxml, 'XMLTransactionHeaderInformation/Transaction', :string)
      @software_program_used = XMLHelper.get_value(hpxml, 'SoftwareInfo/SoftwareProgramUsed', :string)
      @software_program_version = XMLHelper.get_value(hpxml, 'SoftwareInfo/SoftwareProgramVersion', :string)
      @eri_calculation_version = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/ERICalculation/Version', :string)
      @eri_design = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/ERICalculation/Design', :string)
      @energystar_calculation_version = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/EnergyStarCalculation/Version', :string)
      @timestep = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/SimulationControl/Timestep', :integer)
      @sim_begin_month = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/SimulationControl/BeginMonth', :integer)
      @sim_begin_day = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/SimulationControl/BeginDayOfMonth', :integer)
      @sim_end_month = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/SimulationControl/EndMonth', :integer)
      @sim_end_day = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/SimulationControl/EndDayOfMonth', :integer)
      @sim_calendar_year = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/SimulationControl/CalendarYear', :integer)
      @dst_enabled = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/SimulationControl/DaylightSaving/Enabled', :boolean)
      @dst_begin_month = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/SimulationControl/DaylightSaving/BeginMonth', :integer)
      @dst_begin_day = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/SimulationControl/DaylightSaving/BeginDayOfMonth', :integer)
      @dst_end_month = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/SimulationControl/DaylightSaving/EndMonth', :integer)
      @dst_end_day = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/SimulationControl/DaylightSaving/EndDayOfMonth', :integer)
      @apply_ashrae140_assumptions = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/ApplyASHRAE140Assumptions', :boolean)
      @use_max_load_for_heat_pumps = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/HVACSizingControl/UseMaxLoadForHeatPumps', :boolean)
      @allow_increased_fixed_capacities = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/HVACSizingControl/AllowIncreasedFixedCapacities', :boolean)
      @schedules_path = XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/OccupancySchedulesCSVPath', :string)
      @building_id = HPXML::get_id(hpxml, 'Building/BuildingID')
      @event_type = XMLHelper.get_value(hpxml, 'Building/ProjectStatus/EventType', :string)
      @state_code = XMLHelper.get_value(hpxml, 'Building/Site/Address/StateCode', :string)
    end
  end

  class Site < BaseElement
    ATTRS = [:site_type, :surroundings, :shielding_of_home, :orientation_of_front_of_home, :fuels]
    attr_accessor(*ATTRS)

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      site = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'BuildingSummary', 'Site'])
      XMLHelper.add_element(site, 'SiteType', @site_type, :string, @site_type_isdefaulted) unless @site_type.nil?
      XMLHelper.add_element(site, 'Surroundings', @surroundings, :string) unless @surroundings.nil?
      XMLHelper.add_element(site, 'ShieldingofHome', @shielding_of_home, :string, @shielding_of_home_isdefaulted) unless @shielding_of_home.nil?
      XMLHelper.add_element(site, 'OrientationOfFrontOfHome', @orientation_of_front_of_home, :string) unless @orientation_of_front_of_home.nil?
      if (not @fuels.nil?) && (not @fuels.empty?)
        fuel_types_available = XMLHelper.add_element(site, 'FuelTypesAvailable')
        @fuels.each do |fuel|
          XMLHelper.add_element(fuel_types_available, 'Fuel', fuel, :string)
        end
      end
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      site = XMLHelper.get_element(hpxml, 'Building/BuildingDetails/BuildingSummary/Site')
      return if site.nil?

      @site_type = XMLHelper.get_value(site, 'SiteType', :string)
      @surroundings = XMLHelper.get_value(site, 'Surroundings', :string)
      @shielding_of_home = XMLHelper.get_value(site, 'ShieldingofHome', :string)
      @orientation_of_front_of_home = XMLHelper.get_value(site, 'OrientationOfFrontOfHome', :string)
      @fuels = XMLHelper.get_values(site, 'FuelTypesAvailable/Fuel', :string)
    end
  end

  class NeighborBuildings < BaseArrayElement
    def add(**kwargs)
      self << NeighborBuilding.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/BuildingSummary/Site/extension/Neighbors/NeighborBuilding').each do |neighbor_building|
        self << NeighborBuilding.new(@hpxml_object, neighbor_building)
      end
    end
  end

  class NeighborBuilding < BaseElement
    ATTRS = [:azimuth, :orientation, :distance, :height]
    attr_accessor(*ATTRS)

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      neighbors = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'BuildingSummary', 'Site', 'extension', 'Neighbors'])
      neighbor_building = XMLHelper.add_element(neighbors, 'NeighborBuilding')
      XMLHelper.add_element(neighbor_building, 'Orientation', @orientation, :string, @orientation_isdefaulted) unless @orientation.nil?
      XMLHelper.add_element(neighbor_building, 'Azimuth', @azimuth, :integer, @azimuth_isdefaulted) unless @azimuth.nil?
      XMLHelper.add_element(neighbor_building, 'Distance', @distance, :float) unless @distance.nil?
      XMLHelper.add_element(neighbor_building, 'Height', @height, :float) unless @height.nil?
    end

    def from_oga(neighbor_building)
      return if neighbor_building.nil?

      @orientation = XMLHelper.get_value(neighbor_building, 'Orientation', :string)
      @azimuth = XMLHelper.get_value(neighbor_building, 'Azimuth', :integer)
      @distance = XMLHelper.get_value(neighbor_building, 'Distance', :float)
      @height = XMLHelper.get_value(neighbor_building, 'Height', :float)
    end
  end

  class BuildingOccupancy < BaseElement
    ATTRS = [:number_of_residents]
    attr_accessor(*ATTRS)

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      building_occupancy = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'BuildingSummary', 'BuildingOccupancy'])
      XMLHelper.add_element(building_occupancy, 'NumberofResidents', @number_of_residents, :float, @number_of_residents_isdefaulted) unless @number_of_residents.nil?
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      building_occupancy = XMLHelper.get_element(hpxml, 'Building/BuildingDetails/BuildingSummary/BuildingOccupancy')
      return if building_occupancy.nil?

      @number_of_residents = XMLHelper.get_value(building_occupancy, 'NumberofResidents', :float)
    end
  end

  class BuildingConstruction < BaseElement
    ATTRS = [:year_built, :number_of_conditioned_floors, :number_of_conditioned_floors_above_grade,
             :average_ceiling_height, :number_of_bedrooms, :number_of_bathrooms,
             :conditioned_floor_area, :conditioned_building_volume, :residential_facility_type,
             :has_flue_or_chimney]
    attr_accessor(*ATTRS)

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      building_construction = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'BuildingSummary', 'BuildingConstruction'])
      XMLHelper.add_element(building_construction, 'YearBuilt', @year_built, :integer) unless @year_built.nil?
      XMLHelper.add_element(building_construction, 'ResidentialFacilityType', @residential_facility_type, :string) unless @residential_facility_type.nil?
      XMLHelper.add_element(building_construction, 'NumberofConditionedFloors', @number_of_conditioned_floors, :float) unless @number_of_conditioned_floors.nil?
      XMLHelper.add_element(building_construction, 'NumberofConditionedFloorsAboveGrade', @number_of_conditioned_floors_above_grade, :float) unless @number_of_conditioned_floors_above_grade.nil?
      XMLHelper.add_element(building_construction, 'AverageCeilingHeight', @average_ceiling_height, :float, @average_ceiling_height_isdefaulted) unless @average_ceiling_height.nil?
      XMLHelper.add_element(building_construction, 'NumberofBedrooms', @number_of_bedrooms, :integer) unless @number_of_bedrooms.nil?
      XMLHelper.add_element(building_construction, 'NumberofBathrooms', @number_of_bathrooms, :integer, @number_of_bathrooms_isdefaulted) unless @number_of_bathrooms.nil?
      XMLHelper.add_element(building_construction, 'ConditionedFloorArea', @conditioned_floor_area, :float) unless @conditioned_floor_area.nil?
      XMLHelper.add_element(building_construction, 'ConditionedBuildingVolume', @conditioned_building_volume, :float, @conditioned_building_volume_isdefaulted) unless @conditioned_building_volume.nil?
      XMLHelper.add_extension(building_construction, 'HasFlueOrChimney', @has_flue_or_chimney, :boolean, @has_flue_or_chimney_isdefaulted) unless @has_flue_or_chimney.nil?
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      building_construction = XMLHelper.get_element(hpxml, 'Building/BuildingDetails/BuildingSummary/BuildingConstruction')
      return if building_construction.nil?

      @year_built = XMLHelper.get_value(building_construction, 'YearBuilt', :integer)
      @residential_facility_type = XMLHelper.get_value(building_construction, 'ResidentialFacilityType', :string)
      @number_of_conditioned_floors = XMLHelper.get_value(building_construction, 'NumberofConditionedFloors', :float)
      @number_of_conditioned_floors_above_grade = XMLHelper.get_value(building_construction, 'NumberofConditionedFloorsAboveGrade', :float)
      @average_ceiling_height = XMLHelper.get_value(building_construction, 'AverageCeilingHeight', :float)
      @number_of_bedrooms = XMLHelper.get_value(building_construction, 'NumberofBedrooms', :integer)
      @number_of_bathrooms = XMLHelper.get_value(building_construction, 'NumberofBathrooms', :integer)
      @conditioned_floor_area = XMLHelper.get_value(building_construction, 'ConditionedFloorArea', :float)
      @conditioned_building_volume = XMLHelper.get_value(building_construction, 'ConditionedBuildingVolume', :float)
      @has_flue_or_chimney = XMLHelper.get_value(building_construction, 'extension/HasFlueOrChimney', :boolean)
    end
  end

  class ClimateandRiskZones < BaseElement
    ATTRS = [:iecc_year, :iecc_zone, :weather_station_id, :weather_station_name, :weather_station_wmo,
             :weather_station_epw_filepath]
    attr_accessor(*ATTRS)

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      climate_and_risk_zones = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'ClimateandRiskZones'])

      if (not @iecc_year.nil?) && (not @iecc_zone.nil?)
        climate_zone_iecc = XMLHelper.add_element(climate_and_risk_zones, 'ClimateZoneIECC')
        XMLHelper.add_element(climate_zone_iecc, 'Year', @iecc_year, :integer) unless @iecc_year.nil?
        XMLHelper.add_element(climate_zone_iecc, 'ClimateZone', @iecc_zone, :string) unless @iecc_zone.nil?
      end

      if not @weather_station_id.nil?
        weather_station = XMLHelper.add_element(climate_and_risk_zones, 'WeatherStation')
        sys_id = XMLHelper.add_element(weather_station, 'SystemIdentifier')
        XMLHelper.add_attribute(sys_id, 'id', @weather_station_id)
        XMLHelper.add_element(weather_station, 'Name', @weather_station_name, :string) unless @weather_station_name.nil?
        XMLHelper.add_element(weather_station, 'WMO', @weather_station_wmo, :string) unless @weather_station_wmo.nil?
        XMLHelper.add_extension(weather_station, 'EPWFilePath', @weather_station_epw_filepath, :string) unless @weather_station_epw_filepath.nil?
      end
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      climate_and_risk_zones = XMLHelper.get_element(hpxml, 'Building/BuildingDetails/ClimateandRiskZones')
      return if climate_and_risk_zones.nil?

      @iecc_year = XMLHelper.get_value(climate_and_risk_zones, 'ClimateZoneIECC/Year', :integer)
      @iecc_zone = XMLHelper.get_value(climate_and_risk_zones, 'ClimateZoneIECC/ClimateZone', :string)
      weather_station = XMLHelper.get_element(climate_and_risk_zones, 'WeatherStation')
      if not weather_station.nil?
        @weather_station_id = HPXML::get_id(weather_station)
        @weather_station_name = XMLHelper.get_value(weather_station, 'Name', :string)
        @weather_station_wmo = XMLHelper.get_value(weather_station, 'WMO', :string)
        @weather_station_epw_filepath = XMLHelper.get_value(weather_station, 'extension/EPWFilePath', :string)
      end
    end
  end

  class AirInfiltrationMeasurements < BaseArrayElement
    def add(**kwargs)
      self << AirInfiltrationMeasurement.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement').each do |air_infiltration_measurement|
        self << AirInfiltrationMeasurement.new(@hpxml_object, air_infiltration_measurement)
      end
    end
  end

  class AirInfiltrationMeasurement < BaseElement
    ATTRS = [:id, :house_pressure, :unit_of_measure, :air_leakage, :effective_leakage_area, :type,
             :infiltration_volume, :leakiness_description, :infiltration_height, :a_ext]
    attr_accessor(*ATTRS)

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      air_infiltration = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Enclosure', 'AirInfiltration'])
      air_infiltration_measurement = XMLHelper.add_element(air_infiltration, 'AirInfiltrationMeasurement')
      sys_id = XMLHelper.add_element(air_infiltration_measurement, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(air_infiltration_measurement, 'TypeOfInfiltrationMeasurement', @type, :string) unless @type.nil?
      XMLHelper.add_element(air_infiltration_measurement, 'HousePressure', @house_pressure, :float) unless @house_pressure.nil?
      XMLHelper.add_element(air_infiltration_measurement, 'LeakinessDescription', @leakiness_description, :string) unless @leakiness_description.nil?
      if (not @unit_of_measure.nil?) && (not @air_leakage.nil?)
        building_air_leakage = XMLHelper.add_element(air_infiltration_measurement, 'BuildingAirLeakage')
        XMLHelper.add_element(building_air_leakage, 'UnitofMeasure', @unit_of_measure, :string)
        XMLHelper.add_element(building_air_leakage, 'AirLeakage', @air_leakage, :float)
      end
      XMLHelper.add_element(air_infiltration_measurement, 'EffectiveLeakageArea', @effective_leakage_area, :float) unless @effective_leakage_area.nil?
      XMLHelper.add_element(air_infiltration_measurement, 'InfiltrationVolume', @infiltration_volume, :float, @infiltration_volume_isdefaulted) unless @infiltration_volume.nil?
      XMLHelper.add_extension(air_infiltration_measurement, 'InfiltrationHeight', @infiltration_height, :float) unless @infiltration_height.nil?
      XMLHelper.add_extension(air_infiltration_measurement, 'Aext', @a_ext, :float) unless @a_ext.nil?
    end

    def from_oga(air_infiltration_measurement)
      return if air_infiltration_measurement.nil?

      @id = HPXML::get_id(air_infiltration_measurement)
      @type = XMLHelper.get_value(air_infiltration_measurement, 'TypeOfInfiltrationMeasurement', :string)
      @house_pressure = XMLHelper.get_value(air_infiltration_measurement, 'HousePressure', :float)
      @leakiness_description = XMLHelper.get_value(air_infiltration_measurement, 'LeakinessDescription', :string)
      @unit_of_measure = XMLHelper.get_value(air_infiltration_measurement, 'BuildingAirLeakage/UnitofMeasure', :string)
      @air_leakage = XMLHelper.get_value(air_infiltration_measurement, 'BuildingAirLeakage/AirLeakage', :float)
      @effective_leakage_area = XMLHelper.get_value(air_infiltration_measurement, 'EffectiveLeakageArea', :float)
      @infiltration_volume = XMLHelper.get_value(air_infiltration_measurement, 'InfiltrationVolume', :float)
      @infiltration_height = XMLHelper.get_value(air_infiltration_measurement, 'extension/InfiltrationHeight', :float)
      @a_ext = XMLHelper.get_value(air_infiltration_measurement, 'extension/Aext', :float)
    end
  end

  class Attics < BaseArrayElement
    def add(**kwargs)
      self << Attic.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Enclosure/Attics/Attic').each do |attic|
        self << Attic.new(@hpxml_object, attic)
      end
    end
  end

  class Attic < BaseElement
    ATTRS = [:id, :attic_type, :vented_attic_sla, :vented_attic_ach, :within_infiltration_volume,
             :attached_to_roof_idrefs, :attached_to_frame_floor_idrefs]
    attr_accessor(*ATTRS)

    def attached_roofs
      return [] if @attached_to_roof_idrefs.nil?

      list = @hpxml_object.roofs.select { |roof| @attached_to_roof_idrefs.include? roof.id }
      if @attached_to_roof_idrefs.size > list.size
        fail "Attached roof not found for attic '#{@id}'."
      end

      return list
    end

    def attached_frame_floors
      return [] if @attached_to_frame_floor_idrefs.nil?

      list = @hpxml_object.frame_floors.select { |frame_floor| @attached_to_frame_floor_idrefs.include? frame_floor.id }
      if @attached_to_frame_floor_idrefs.size > list.size
        fail "Attached frame floor not found for attic '#{@id}'."
      end

      return list
    end

    def to_location
      return if @attic_type.nil?

      if @attic_type == AtticTypeCathedral
        return LocationLivingSpace
      elsif @attic_type == AtticTypeConditioned
        return LocationLivingSpace
      elsif @attic_type == AtticTypeFlatRoof
        return LocationLivingSpace
      elsif @attic_type == AtticTypeUnvented
        return LocationAtticUnvented
      elsif @attic_type == AtticTypeVented
        return LocationAtticVented
      else
        fail "Unexpected attic type: '#{@attic_type}'."
      end
    end

    def check_for_errors
      errors = []
      begin; attached_roofs; rescue StandardError => e; errors << e.message; end
      begin; attached_frame_floors; rescue StandardError => e; errors << e.message; end
      begin; to_location; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      attics = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Enclosure', 'Attics'])
      attic = XMLHelper.add_element(attics, 'Attic')
      sys_id = XMLHelper.add_element(attic, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      if not @attic_type.nil?
        attic_type_el = XMLHelper.add_element(attic, 'AtticType')
        if @attic_type == AtticTypeUnvented
          attic_type_attic = XMLHelper.add_element(attic_type_el, 'Attic')
          XMLHelper.add_element(attic_type_attic, 'Vented', false, :boolean)
        elsif @attic_type == AtticTypeVented
          attic_type_attic = XMLHelper.add_element(attic_type_el, 'Attic')
          XMLHelper.add_element(attic_type_attic, 'Vented', true, :boolean)
          if not @vented_attic_sla.nil?
            ventilation_rate = XMLHelper.add_element(attic, 'VentilationRate')
            XMLHelper.add_element(ventilation_rate, 'UnitofMeasure', UnitsSLA, :string)
            XMLHelper.add_element(ventilation_rate, 'Value', @vented_attic_sla, :float, @vented_attic_sla_isdefaulted)
          elsif not @vented_attic_ach.nil?
            ventilation_rate = XMLHelper.add_element(attic, 'VentilationRate')
            XMLHelper.add_element(ventilation_rate, 'UnitofMeasure', UnitsACHNatural, :string)
            XMLHelper.add_element(ventilation_rate, 'Value', @vented_attic_ach, :float)
          end
        elsif @attic_type == AtticTypeConditioned
          attic_type_attic = XMLHelper.add_element(attic_type_el, 'Attic')
          XMLHelper.add_element(attic_type_attic, 'Conditioned', true, :boolean)
        elsif (@attic_type == AtticTypeFlatRoof) || (@attic_type == AtticTypeCathedral)
          XMLHelper.add_element(attic_type_el, @attic_type)
        else
          fail "Unhandled attic type '#{@attic_type}'."
        end
      end
      XMLHelper.add_element(attic, 'WithinInfiltrationVolume', within_infiltration_volume, :boolean) unless @within_infiltration_volume.nil?
    end

    def from_oga(attic)
      return if attic.nil?

      @id = HPXML::get_id(attic)
      if XMLHelper.has_element(attic, "AtticType/Attic[Vented='false']")
        @attic_type = AtticTypeUnvented
      elsif XMLHelper.has_element(attic, "AtticType/Attic[Vented='true']")
        @attic_type = AtticTypeVented
      elsif XMLHelper.has_element(attic, "AtticType/Attic[Conditioned='true']")
        @attic_type = AtticTypeConditioned
      elsif XMLHelper.has_element(attic, 'AtticType/FlatRoof')
        @attic_type = AtticTypeFlatRoof
      elsif XMLHelper.has_element(attic, 'AtticType/CathedralCeiling')
        @attic_type = AtticTypeCathedral
      end
      if @attic_type == AtticTypeVented
        @vented_attic_sla = XMLHelper.get_value(attic, "VentilationRate[UnitofMeasure='#{UnitsSLA}']/Value", :float)
        @vented_attic_ach = XMLHelper.get_value(attic, "VentilationRate[UnitofMeasure='#{UnitsACHNatural}']/Value", :float)
      end
      @within_infiltration_volume = XMLHelper.get_value(attic, 'WithinInfiltrationVolume', :boolean)
      @attached_to_roof_idrefs = []
      XMLHelper.get_elements(attic, 'AttachedToRoof').each do |roof|
        @attached_to_roof_idrefs << HPXML::get_idref(roof)
      end
      @attached_to_frame_floor_idrefs = []
      XMLHelper.get_elements(attic, 'AttachedToFrameFloor').each do |frame_floor|
        @attached_to_frame_floor_idrefs << HPXML::get_idref(frame_floor)
      end
    end
  end

  class Foundations < BaseArrayElement
    def add(**kwargs)
      self << Foundation.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Enclosure/Foundations/Foundation').each do |foundation|
        self << Foundation.new(@hpxml_object, foundation)
      end
    end
  end

  class Foundation < BaseElement
    ATTRS = [:id, :foundation_type, :vented_crawlspace_sla, :within_infiltration_volume,
             :attached_to_slab_idrefs, :attached_to_frame_floor_idrefs, :attached_to_foundation_wall_idrefs]
    attr_accessor(*ATTRS)

    def attached_slabs
      return [] if @attached_to_slab_idrefs.nil?

      list = @hpxml_object.slabs.select { |slab| @attached_to_slab_idrefs.include? slab.id }
      if @attached_to_slab_idrefs.size > list.size
        fail "Attached slab not found for foundation '#{@id}'."
      end

      return list
    end

    def attached_frame_floors
      return [] if @attached_to_frame_floor_idrefs.nil?

      list = @hpxml_object.frame_floors.select { |frame_floor| @attached_to_frame_floor_idrefs.include? frame_floor.id }
      if @attached_to_frame_floor_idrefs.size > list.size
        fail "Attached frame floor not found for foundation '#{@id}'."
      end

      return list
    end

    def attached_foundation_walls
      return [] if @attached_to_foundation_wall_idrefs.nil?

      list = @hpxml_object.foundation_walls.select { |foundation_wall| @attached_to_foundation_wall_idrefs.include? foundation_wall.id }
      if @attached_to_foundation_wall_idrefs.size > list.size
        fail "Attached foundation wall not found for foundation '#{@id}'."
      end

      return list
    end

    def to_location
      return if @foundation_type.nil?

      if @foundation_type == FoundationTypeAmbient
        return LocationOutside
      elsif @foundation_type == FoundationTypeBasementConditioned
        return LocationBasementConditioned
      elsif @foundation_type == FoundationTypeBasementUnconditioned
        return LocationBasementUnconditioned
      elsif @foundation_type == FoundationTypeCrawlspaceUnvented
        return LocationCrawlspaceUnvented
      elsif @foundation_type == FoundationTypeCrawlspaceVented
        return LocationCrawlspaceVented
      elsif @foundation_type == FoundationTypeSlab
        return LocationLivingSpace
      else
        fail "Unexpected foundation type: '#{@foundation_type}'."
      end
    end

    def area
      sum_area = 0.0
      # Check Slabs first
      attached_slabs.each do |slab|
        sum_area += slab.area
      end
      if sum_area <= 0
        # Check FrameFloors next
        attached_frame_floors.each do |frame_floor|
          sum_area += frame_floor.area
        end
      end
      return sum_area
    end

    def check_for_errors
      errors = []
      begin; attached_slabs; rescue StandardError => e; errors << e.message; end
      begin; attached_frame_floors; rescue StandardError => e; errors << e.message; end
      begin; attached_foundation_walls; rescue StandardError => e; errors << e.message; end
      begin; to_location; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      foundations = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Enclosure', 'Foundations'])
      foundation = XMLHelper.add_element(foundations, 'Foundation')
      sys_id = XMLHelper.add_element(foundation, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      if not @foundation_type.nil?
        foundation_type_el = XMLHelper.add_element(foundation, 'FoundationType')
        if [FoundationTypeSlab, FoundationTypeAmbient].include? @foundation_type
          XMLHelper.add_element(foundation_type_el, @foundation_type)
        elsif @foundation_type == FoundationTypeBasementConditioned
          basement = XMLHelper.add_element(foundation_type_el, 'Basement')
          XMLHelper.add_element(basement, 'Conditioned', true, :boolean)
        elsif @foundation_type == FoundationTypeBasementUnconditioned
          basement = XMLHelper.add_element(foundation_type_el, 'Basement')
          XMLHelper.add_element(basement, 'Conditioned', false, :boolean)
        elsif @foundation_type == FoundationTypeCrawlspaceVented
          crawlspace = XMLHelper.add_element(foundation_type_el, 'Crawlspace')
          XMLHelper.add_element(crawlspace, 'Vented', true, :boolean)
          if not @vented_crawlspace_sla.nil?
            ventilation_rate = XMLHelper.add_element(foundation, 'VentilationRate')
            XMLHelper.add_element(ventilation_rate, 'UnitofMeasure', UnitsSLA, :string)
            XMLHelper.add_element(ventilation_rate, 'Value', @vented_crawlspace_sla, :float, @vented_crawlspace_sla_isdefaulted)
          end
        elsif @foundation_type == FoundationTypeCrawlspaceUnvented
          crawlspace = XMLHelper.add_element(foundation_type_el, 'Crawlspace')
          XMLHelper.add_element(crawlspace, 'Vented', false, :boolean)
        else
          fail "Unhandled foundation type '#{@foundation_type}'."
        end
      end
      XMLHelper.add_element(foundation, 'WithinInfiltrationVolume', @within_infiltration_volume, :boolean) unless @within_infiltration_volume.nil?
    end

    def from_oga(foundation)
      return if foundation.nil?

      @id = HPXML::get_id(foundation)
      if XMLHelper.has_element(foundation, 'FoundationType/SlabOnGrade')
        @foundation_type = FoundationTypeSlab
      elsif XMLHelper.has_element(foundation, "FoundationType/Basement[Conditioned='false']")
        @foundation_type = FoundationTypeBasementUnconditioned
      elsif XMLHelper.has_element(foundation, "FoundationType/Basement[Conditioned='true']")
        @foundation_type = FoundationTypeBasementConditioned
      elsif XMLHelper.has_element(foundation, "FoundationType/Crawlspace[Vented='false']")
        @foundation_type = FoundationTypeCrawlspaceUnvented
      elsif XMLHelper.has_element(foundation, "FoundationType/Crawlspace[Vented='true']")
        @foundation_type = FoundationTypeCrawlspaceVented
      elsif XMLHelper.has_element(foundation, 'FoundationType/Ambient')
        @foundation_type = FoundationTypeAmbient
      end
      if @foundation_type == FoundationTypeCrawlspaceVented
        @vented_crawlspace_sla = XMLHelper.get_value(foundation, "VentilationRate[UnitofMeasure='#{UnitsSLA}']/Value", :float)
      end
      @within_infiltration_volume = XMLHelper.get_value(foundation, 'WithinInfiltrationVolume', :boolean)
      @attached_to_slab_idrefs = []
      XMLHelper.get_elements(foundation, 'AttachedToSlab').each do |slab|
        @attached_to_slab_idrefs << HPXML::get_idref(slab)
      end
      @attached_to_frame_floor_idrefs = []
      XMLHelper.get_elements(foundation, 'AttachedToFrameFloor').each do |frame_floor|
        @attached_to_frame_floor_idrefs << HPXML::get_idref(frame_floor)
      end
      @attached_to_foundation_wall_idrefs = []
      XMLHelper.get_elements(foundation, 'AttachedToFoundationWall').each do |foundation_wall|
        @attached_to_foundation_wall_idrefs << HPXML::get_idref(foundation_wall)
      end
    end
  end

  class Roofs < BaseArrayElement
    def add(**kwargs)
      self << Roof.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Enclosure/Roofs/Roof').each do |roof|
        self << Roof.new(@hpxml_object, roof)
      end
    end
  end

  class Roof < BaseElement
    ATTRS = [:id, :interior_adjacent_to, :area, :azimuth, :orientation, :roof_type,
             :roof_color, :solar_absorptance, :emittance, :pitch, :radiant_barrier,
             :insulation_id, :insulation_assembly_r_value, :insulation_cavity_r_value,
             :insulation_continuous_r_value, :radiant_barrier_grade,
             :interior_finish_type, :interior_finish_thickness]
    attr_accessor(*ATTRS)

    def skylights
      return @hpxml_object.skylights.select { |skylight| skylight.roof_idref == @id }
    end

    def net_area
      return if nil?
      return if @area.nil?

      val = @area
      skylights.each do |skylight|
        val -= skylight.area
      end
      fail "Calculated a negative net surface area for surface '#{@id}'." if val < 0

      return val
    end

    def exterior_adjacent_to
      return LocationOutside
    end

    def is_exterior
      return true
    end

    def is_interior
      return !is_exterior
    end

    def is_thermal_boundary
      return HPXML::is_thermal_boundary(self)
    end

    def is_exterior_thermal_boundary
      return (is_exterior && is_thermal_boundary)
    end

    def is_conditioned
      return HPXML::is_conditioned(self)
    end

    def delete
      @hpxml_object.roofs.delete(self)
      skylights.reverse_each do |skylight|
        skylight.delete
      end
      @hpxml_object.attics.each do |attic|
        attic.attached_to_roof_idrefs.delete(@id) unless attic.attached_to_roof_idrefs.nil?
      end
    end

    def check_for_errors
      errors = []
      begin; net_area; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      roofs = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Enclosure', 'Roofs'])
      roof = XMLHelper.add_element(roofs, 'Roof')
      sys_id = XMLHelper.add_element(roof, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(roof, 'InteriorAdjacentTo', @interior_adjacent_to, :string) unless @interior_adjacent_to.nil?
      XMLHelper.add_element(roof, 'Area', @area, :float) unless @area.nil?
      XMLHelper.add_element(roof, 'Orientation', @orientation, :string, @orientation_isdefaulted) unless @orientation.nil?
      XMLHelper.add_element(roof, 'Azimuth', @azimuth, :integer, @azimuth_isdefaulted) unless @azimuth.nil?
      XMLHelper.add_element(roof, 'RoofType', @roof_type, :string, @roof_type_isdefaulted) unless @roof_type.nil?
      XMLHelper.add_element(roof, 'RoofColor', @roof_color, :string, @roof_color_isdefaulted) unless @roof_color.nil?
      XMLHelper.add_element(roof, 'SolarAbsorptance', @solar_absorptance, :float, @solar_absorptance_isdefaulted) unless @solar_absorptance.nil?
      XMLHelper.add_element(roof, 'Emittance', @emittance, :float, @emittance_isdefaulted) unless @emittance.nil?
      if (not @interior_finish_type.nil?) || (not @interior_finish_thickness.nil?)
        interior_finish = XMLHelper.add_element(roof, 'InteriorFinish')
        XMLHelper.add_element(interior_finish, 'Type', @interior_finish_type, :string, @interior_finish_type_isdefaulted) unless @interior_finish_type.nil?
        XMLHelper.add_element(interior_finish, 'Thickness', @interior_finish_thickness, :float, @interior_finish_thickness_isdefaulted) unless @interior_finish_thickness.nil?
      end
      XMLHelper.add_element(roof, 'Pitch', @pitch, :float) unless @pitch.nil?
      XMLHelper.add_element(roof, 'RadiantBarrier', @radiant_barrier, :boolean, @radiant_barrier_isdefaulted) unless @radiant_barrier.nil?
      XMLHelper.add_element(roof, 'RadiantBarrierGrade', @radiant_barrier_grade, :integer, @radiant_barrier_grade_isdefaulted) unless @radiant_barrier_grade.nil?
      insulation = XMLHelper.add_element(roof, 'Insulation')
      sys_id = XMLHelper.add_element(insulation, 'SystemIdentifier')
      if not @insulation_id.nil?
        XMLHelper.add_attribute(sys_id, 'id', @insulation_id)
      else
        XMLHelper.add_attribute(sys_id, 'id', @id + 'Insulation')
      end
      XMLHelper.add_element(insulation, 'AssemblyEffectiveRValue', @insulation_assembly_r_value, :float) unless @insulation_assembly_r_value.nil?
      if not @insulation_cavity_r_value.nil?
        layer = XMLHelper.add_element(insulation, 'Layer')
        XMLHelper.add_element(layer, 'InstallationType', 'cavity', :string)
        XMLHelper.add_element(layer, 'NominalRValue', @insulation_cavity_r_value, :float)
      end
      if not @insulation_continuous_r_value.nil?
        layer = XMLHelper.add_element(insulation, 'Layer')
        XMLHelper.add_element(layer, 'InstallationType', 'continuous', :string)
        XMLHelper.add_element(layer, 'NominalRValue', @insulation_continuous_r_value, :float)
      end
    end

    def from_oga(roof)
      return if roof.nil?

      @id = HPXML::get_id(roof)
      @interior_adjacent_to = XMLHelper.get_value(roof, 'InteriorAdjacentTo', :string)
      @area = XMLHelper.get_value(roof, 'Area', :float)
      @orientation = XMLHelper.get_value(roof, 'Orientation', :string)
      @azimuth = XMLHelper.get_value(roof, 'Azimuth', :integer)
      @roof_type = XMLHelper.get_value(roof, 'RoofType', :string)
      @roof_color = XMLHelper.get_value(roof, 'RoofColor', :string)
      @solar_absorptance = XMLHelper.get_value(roof, 'SolarAbsorptance', :float)
      @emittance = XMLHelper.get_value(roof, 'Emittance', :float)
      interior_finish = XMLHelper.get_element(roof, 'InteriorFinish')
      if not interior_finish.nil?
        @interior_finish_type = XMLHelper.get_value(interior_finish, 'Type', :string)
        @interior_finish_thickness = XMLHelper.get_value(interior_finish, 'Thickness', :float)
      end
      @pitch = XMLHelper.get_value(roof, 'Pitch', :float)
      @radiant_barrier = XMLHelper.get_value(roof, 'RadiantBarrier', :boolean)
      @radiant_barrier_grade = XMLHelper.get_value(roof, 'RadiantBarrierGrade', :integer)
      insulation = XMLHelper.get_element(roof, 'Insulation')
      if not insulation.nil?
        @insulation_id = HPXML::get_id(insulation)
        @insulation_assembly_r_value = XMLHelper.get_value(insulation, 'AssemblyEffectiveRValue', :float)
        @insulation_cavity_r_value = XMLHelper.get_value(insulation, "Layer[InstallationType='cavity']/NominalRValue", :float)
        @insulation_continuous_r_value = XMLHelper.get_value(insulation, "Layer[InstallationType='continuous']/NominalRValue", :float)
      end
    end
  end

  class RimJoists < BaseArrayElement
    def add(**kwargs)
      self << RimJoist.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Enclosure/RimJoists/RimJoist').each do |rim_joist|
        self << RimJoist.new(@hpxml_object, rim_joist)
      end
    end
  end

  class RimJoist < BaseElement
    ATTRS = [:id, :exterior_adjacent_to, :interior_adjacent_to, :area, :orientation, :azimuth, :siding,
             :color, :solar_absorptance, :emittance, :insulation_id, :insulation_assembly_r_value,
             :insulation_cavity_r_value, :insulation_continuous_r_value]
    attr_accessor(*ATTRS)

    def is_exterior
      if @exterior_adjacent_to == LocationOutside
        return true
      end

      return false
    end

    def is_interior
      return !is_exterior
    end

    def is_adiabatic
      return HPXML::is_adiabatic(self)
    end

    def is_thermal_boundary
      return HPXML::is_thermal_boundary(self)
    end

    def is_exterior_thermal_boundary
      return (is_exterior && is_thermal_boundary)
    end

    def is_conditioned
      return HPXML::is_conditioned(self)
    end

    def delete
      @hpxml_object.rim_joists.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      rim_joists = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Enclosure', 'RimJoists'])
      rim_joist = XMLHelper.add_element(rim_joists, 'RimJoist')
      sys_id = XMLHelper.add_element(rim_joist, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(rim_joist, 'ExteriorAdjacentTo', @exterior_adjacent_to, :string) unless @exterior_adjacent_to.nil?
      XMLHelper.add_element(rim_joist, 'InteriorAdjacentTo', @interior_adjacent_to, :string) unless @interior_adjacent_to.nil?
      XMLHelper.add_element(rim_joist, 'Area', @area, :float) unless @area.nil?
      XMLHelper.add_element(rim_joist, 'Orientation', @orientation, :string, @orientation_isdefaulted) unless @orientation.nil?
      XMLHelper.add_element(rim_joist, 'Azimuth', @azimuth, :integer, @azimuth_isdefaulted) unless @azimuth.nil?
      XMLHelper.add_element(rim_joist, 'Siding', @siding, :string, @siding_isdefaulted) unless @siding.nil?
      XMLHelper.add_element(rim_joist, 'Color', @color, :string, @color_isdefaulted) unless @color.nil?
      XMLHelper.add_element(rim_joist, 'SolarAbsorptance', @solar_absorptance, :float, @solar_absorptance_isdefaulted) unless @solar_absorptance.nil?
      XMLHelper.add_element(rim_joist, 'Emittance', @emittance, :float, @emittance_isdefaulted) unless @emittance.nil?
      insulation = XMLHelper.add_element(rim_joist, 'Insulation')
      sys_id = XMLHelper.add_element(insulation, 'SystemIdentifier')
      if not @insulation_id.nil?
        XMLHelper.add_attribute(sys_id, 'id', @insulation_id)
      else
        XMLHelper.add_attribute(sys_id, 'id', @id + 'Insulation')
      end
      XMLHelper.add_element(insulation, 'AssemblyEffectiveRValue', @insulation_assembly_r_value, :float) unless @insulation_assembly_r_value.nil?
      if not @insulation_cavity_r_value.nil?
        layer = XMLHelper.add_element(insulation, 'Layer')
        XMLHelper.add_element(layer, 'InstallationType', 'cavity', :string)
        XMLHelper.add_element(layer, 'NominalRValue', @insulation_cavity_r_value, :float)
      end
      if not @insulation_continuous_r_value.nil?
        layer = XMLHelper.add_element(insulation, 'Layer')
        XMLHelper.add_element(layer, 'InstallationType', 'continuous', :string)
        XMLHelper.add_element(layer, 'NominalRValue', @insulation_continuous_r_value, :float)
      end
    end

    def from_oga(rim_joist)
      return if rim_joist.nil?

      @id = HPXML::get_id(rim_joist)
      @exterior_adjacent_to = XMLHelper.get_value(rim_joist, 'ExteriorAdjacentTo', :string)
      @interior_adjacent_to = XMLHelper.get_value(rim_joist, 'InteriorAdjacentTo', :string)
      @area = XMLHelper.get_value(rim_joist, 'Area', :float)
      @orientation = XMLHelper.get_value(rim_joist, 'Orientation', :string)
      @azimuth = XMLHelper.get_value(rim_joist, 'Azimuth', :integer)
      @siding = XMLHelper.get_value(rim_joist, 'Siding', :string)
      @color = XMLHelper.get_value(rim_joist, 'Color', :string)
      @solar_absorptance = XMLHelper.get_value(rim_joist, 'SolarAbsorptance', :float)
      @emittance = XMLHelper.get_value(rim_joist, 'Emittance', :float)
      insulation = XMLHelper.get_element(rim_joist, 'Insulation')
      if not insulation.nil?
        @insulation_id = HPXML::get_id(insulation)
        @insulation_assembly_r_value = XMLHelper.get_value(insulation, 'AssemblyEffectiveRValue', :float)
        @insulation_cavity_r_value = XMLHelper.get_value(insulation, "Layer[InstallationType='cavity']/NominalRValue", :float)
        @insulation_continuous_r_value = XMLHelper.get_value(insulation, "Layer[InstallationType='continuous']/NominalRValue", :float)
      end
    end
  end

  class Walls < BaseArrayElement
    def add(**kwargs)
      self << Wall.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Enclosure/Walls/Wall').each do |wall|
        self << Wall.new(@hpxml_object, wall)
      end
    end
  end

  class Wall < BaseElement
    ATTRS = [:id, :exterior_adjacent_to, :interior_adjacent_to, :wall_type, :optimum_value_engineering,
             :area, :orientation, :azimuth, :siding, :color, :solar_absorptance, :emittance, :insulation_id,
             :insulation_assembly_r_value, :insulation_cavity_r_value, :insulation_continuous_r_value,
             :interior_finish_type, :interior_finish_thickness]
    attr_accessor(*ATTRS)

    def windows
      return @hpxml_object.windows.select { |window| window.wall_idref == @id }
    end

    def doors
      return @hpxml_object.doors.select { |door| door.wall_idref == @id }
    end

    def net_area
      return if nil?
      return if @area.nil?

      val = @area
      (windows + doors).each do |subsurface|
        val -= subsurface.area
      end
      fail "Calculated a negative net surface area for surface '#{@id}'." if val < 0

      return val
    end

    def is_exterior
      if @exterior_adjacent_to == LocationOutside
        return true
      end

      return false
    end

    def is_interior
      return !is_exterior
    end

    def is_adiabatic
      return HPXML::is_adiabatic(self)
    end

    def is_thermal_boundary
      return HPXML::is_thermal_boundary(self)
    end

    def is_exterior_thermal_boundary
      return (is_exterior && is_thermal_boundary)
    end

    def is_conditioned
      return HPXML::is_conditioned(self)
    end

    def delete
      @hpxml_object.walls.delete(self)
      windows.reverse_each do |window|
        window.delete
      end
      doors.reverse_each do |door|
        door.delete
      end
    end

    def check_for_errors
      errors = []
      begin; net_area; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      walls = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Enclosure', 'Walls'])
      wall = XMLHelper.add_element(walls, 'Wall')
      sys_id = XMLHelper.add_element(wall, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(wall, 'ExteriorAdjacentTo', @exterior_adjacent_to, :string) unless @exterior_adjacent_to.nil?
      XMLHelper.add_element(wall, 'InteriorAdjacentTo', @interior_adjacent_to, :string) unless @interior_adjacent_to.nil?
      if not @wall_type.nil?
        wall_type_el = XMLHelper.add_element(wall, 'WallType')
        wall_type = XMLHelper.add_element(wall_type_el, @wall_type)
        if @wall_type == HPXML::WallTypeWoodStud
          XMLHelper.add_element(wall_type, 'OptimumValueEngineering', @optimum_value_engineering, :boolean) unless @optimum_value_engineering.nil?
        end
      end
      XMLHelper.add_element(wall, 'Area', @area, :float) unless @area.nil?
      XMLHelper.add_element(wall, 'Orientation', @orientation, :string, @orientation_isdefaulted) unless @orientation.nil?
      XMLHelper.add_element(wall, 'Azimuth', @azimuth, :integer, @azimuth_isdefaulted) unless @azimuth.nil?
      XMLHelper.add_element(wall, 'Siding', @siding, :string, @siding_isdefaulted) unless @siding.nil?
      XMLHelper.add_element(wall, 'Color', @color, :string, @color_isdefaulted) unless @color.nil?
      XMLHelper.add_element(wall, 'SolarAbsorptance', @solar_absorptance, :float, @solar_absorptance_isdefaulted) unless @solar_absorptance.nil?
      XMLHelper.add_element(wall, 'Emittance', @emittance, :float, @emittance_isdefaulted) unless @emittance.nil?
      if (not @interior_finish_type.nil?) || (not @interior_finish_thickness.nil?)
        interior_finish = XMLHelper.add_element(wall, 'InteriorFinish')
        XMLHelper.add_element(interior_finish, 'Type', @interior_finish_type, :string, @interior_finish_type_isdefaulted) unless @interior_finish_type.nil?
        XMLHelper.add_element(interior_finish, 'Thickness', @interior_finish_thickness, :float, @interior_finish_thickness_isdefaulted) unless @interior_finish_thickness.nil?
      end
      insulation = XMLHelper.add_element(wall, 'Insulation')
      sys_id = XMLHelper.add_element(insulation, 'SystemIdentifier')
      if not @insulation_id.nil?
        XMLHelper.add_attribute(sys_id, 'id', @insulation_id)
      else
        XMLHelper.add_attribute(sys_id, 'id', @id + 'Insulation')
      end
      XMLHelper.add_element(insulation, 'AssemblyEffectiveRValue', @insulation_assembly_r_value, :float) unless @insulation_assembly_r_value.nil?
      if not @insulation_cavity_r_value.nil?
        layer = XMLHelper.add_element(insulation, 'Layer')
        XMLHelper.add_element(layer, 'InstallationType', 'cavity', :string)
        XMLHelper.add_element(layer, 'NominalRValue', @insulation_cavity_r_value, :float)
      end
      if not @insulation_continuous_r_value.nil?
        layer = XMLHelper.add_element(insulation, 'Layer')
        XMLHelper.add_element(layer, 'InstallationType', 'continuous', :string)
        XMLHelper.add_element(layer, 'NominalRValue', @insulation_continuous_r_value, :float)
      end
    end

    def from_oga(wall)
      return if wall.nil?

      @id = HPXML::get_id(wall)
      @exterior_adjacent_to = XMLHelper.get_value(wall, 'ExteriorAdjacentTo', :string)
      @interior_adjacent_to = XMLHelper.get_value(wall, 'InteriorAdjacentTo', :string)
      @wall_type = XMLHelper.get_child_name(wall, 'WallType')
      if @wall_type == HPXML::WallTypeWoodStud
        @optimum_value_engineering = XMLHelper.get_value(wall, 'WallType/WoodStud/OptimumValueEngineering', :boolean)
      end
      @area = XMLHelper.get_value(wall, 'Area', :float)
      @orientation = XMLHelper.get_value(wall, 'Orientation', :string)
      @azimuth = XMLHelper.get_value(wall, 'Azimuth', :integer)
      @siding = XMLHelper.get_value(wall, 'Siding', :string)
      @color = XMLHelper.get_value(wall, 'Color', :string)
      @solar_absorptance = XMLHelper.get_value(wall, 'SolarAbsorptance', :float)
      @emittance = XMLHelper.get_value(wall, 'Emittance', :float)
      interior_finish = XMLHelper.get_element(wall, 'InteriorFinish')
      if not interior_finish.nil?
        @interior_finish_type = XMLHelper.get_value(interior_finish, 'Type', :string)
        @interior_finish_thickness = XMLHelper.get_value(interior_finish, 'Thickness', :float)
      end
      insulation = XMLHelper.get_element(wall, 'Insulation')
      if not insulation.nil?
        @insulation_id = HPXML::get_id(insulation)
        @insulation_assembly_r_value = XMLHelper.get_value(insulation, 'AssemblyEffectiveRValue', :float)
        @insulation_cavity_r_value = XMLHelper.get_value(insulation, "Layer[InstallationType='cavity']/NominalRValue", :float)
        @insulation_continuous_r_value = XMLHelper.get_value(insulation, "Layer[InstallationType='continuous']/NominalRValue", :float)
      end
    end
  end

  class FoundationWalls < BaseArrayElement
    def add(**kwargs)
      self << FoundationWall.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall').each do |foundation_wall|
        self << FoundationWall.new(@hpxml_object, foundation_wall)
      end
    end
  end

  class FoundationWall < BaseElement
    ATTRS = [:id, :exterior_adjacent_to, :interior_adjacent_to, :length, :height, :area, :orientation,
             :azimuth, :thickness, :depth_below_grade, :insulation_id, :insulation_interior_r_value,
             :insulation_interior_distance_to_top, :insulation_interior_distance_to_bottom,
             :insulation_exterior_r_value, :insulation_exterior_distance_to_top,
             :insulation_exterior_distance_to_bottom, :insulation_assembly_r_value,
             :insulation_continuous_r_value, :interior_finish_type, :interior_finish_thickness]
    attr_accessor(*ATTRS)

    def windows
      return @hpxml_object.windows.select { |window| window.wall_idref == @id }
    end

    def doors
      return @hpxml_object.doors.select { |door| door.wall_idref == @id }
    end

    def net_area
      return if nil?
      return if @area.nil?

      val = @area
      (@hpxml_object.windows + @hpxml_object.doors).each do |subsurface|
        next unless subsurface.wall_idref == @id

        val -= subsurface.area
      end
      fail "Calculated a negative net surface area for surface '#{@id}'." if val < 0

      return val
    end

    def is_exterior
      if @exterior_adjacent_to == LocationGround
        return true
      end

      return false
    end

    def is_interior
      return !is_exterior
    end

    def is_adiabatic
      return HPXML::is_adiabatic(self)
    end

    def is_thermal_boundary
      return HPXML::is_thermal_boundary(self)
    end

    def is_exterior_thermal_boundary
      return (is_exterior && is_thermal_boundary)
    end

    def is_conditioned
      return HPXML::is_conditioned(self)
    end

    def delete
      @hpxml_object.foundation_walls.delete(self)
      windows.reverse_each do |window|
        window.delete
      end
      doors.reverse_each do |door|
        door.delete
      end
      @hpxml_object.foundations.each do |foundation|
        foundation.attached_to_foundation_wall_idrefs.delete(@id) unless foundation.attached_to_foundation_wall_idrefs.nil?
      end
    end

    def check_for_errors
      errors = []
      begin; net_area; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      foundation_walls = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Enclosure', 'FoundationWalls'])
      foundation_wall = XMLHelper.add_element(foundation_walls, 'FoundationWall')
      sys_id = XMLHelper.add_element(foundation_wall, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(foundation_wall, 'ExteriorAdjacentTo', @exterior_adjacent_to, :string) unless @exterior_adjacent_to.nil?
      XMLHelper.add_element(foundation_wall, 'InteriorAdjacentTo', @interior_adjacent_to, :string) unless @interior_adjacent_to.nil?
      XMLHelper.add_element(foundation_wall, 'Length', @length, :float) unless @length.nil?
      XMLHelper.add_element(foundation_wall, 'Height', @height, :float) unless @height.nil?
      XMLHelper.add_element(foundation_wall, 'Area', @area, :float, @area_isdefaulted) unless @area.nil?
      XMLHelper.add_element(foundation_wall, 'Orientation', @orientation, :string, @orientation_isdefaulted) unless @orientation.nil?
      XMLHelper.add_element(foundation_wall, 'Azimuth', @azimuth, :integer, @azimuth_isdefaulted) unless @azimuth.nil?
      XMLHelper.add_element(foundation_wall, 'Thickness', @thickness, :float, @thickness_isdefaulted) unless @thickness.nil?
      XMLHelper.add_element(foundation_wall, 'DepthBelowGrade', @depth_below_grade, :float) unless @depth_below_grade.nil?
      if (not @interior_finish_type.nil?) || (not @interior_finish_thickness.nil?)
        interior_finish = XMLHelper.add_element(foundation_wall, 'InteriorFinish')
        XMLHelper.add_element(interior_finish, 'Type', @interior_finish_type, :string, @interior_finish_type_isdefaulted) unless @interior_finish_type.nil?
        XMLHelper.add_element(interior_finish, 'Thickness', @interior_finish_thickness, :float, @interior_finish_thickness_isdefaulted) unless @interior_finish_thickness.nil?
      end
      insulation = XMLHelper.add_element(foundation_wall, 'Insulation')
      sys_id = XMLHelper.add_element(insulation, 'SystemIdentifier')
      if not @insulation_id.nil?
        XMLHelper.add_attribute(sys_id, 'id', @insulation_id)
      else
        XMLHelper.add_attribute(sys_id, 'id', @id + 'Insulation')
      end
      XMLHelper.add_element(insulation, 'AssemblyEffectiveRValue', @insulation_assembly_r_value, :float) unless @insulation_assembly_r_value.nil?
      if not @insulation_exterior_r_value.nil?
        layer = XMLHelper.add_element(insulation, 'Layer')
        XMLHelper.add_element(layer, 'InstallationType', 'continuous - exterior', :string)
        XMLHelper.add_element(layer, 'NominalRValue', @insulation_exterior_r_value, :float)
        XMLHelper.add_extension(layer, 'DistanceToTopOfInsulation', @insulation_exterior_distance_to_top, :float, @insulation_exterior_distance_to_top_isdefaulted) unless @insulation_exterior_distance_to_top.nil?
        XMLHelper.add_extension(layer, 'DistanceToBottomOfInsulation', @insulation_exterior_distance_to_bottom, :float, @insulation_exterior_distance_to_bottom_isdefaulted) unless @insulation_exterior_distance_to_bottom.nil?
      end
      if not @insulation_interior_r_value.nil?
        layer = XMLHelper.add_element(insulation, 'Layer')
        XMLHelper.add_element(layer, 'InstallationType', 'continuous - interior', :string)
        XMLHelper.add_element(layer, 'NominalRValue', @insulation_interior_r_value, :float)
        XMLHelper.add_extension(layer, 'DistanceToTopOfInsulation', @insulation_interior_distance_to_top, :float, @insulation_interior_distance_to_top_isdefaulted) unless @insulation_interior_distance_to_top.nil?
        XMLHelper.add_extension(layer, 'DistanceToBottomOfInsulation', @insulation_interior_distance_to_bottom, :float, @insulation_interior_distance_to_bottom_isdefaulted) unless @insulation_interior_distance_to_bottom.nil?
      end
    end

    def from_oga(foundation_wall)
      return if foundation_wall.nil?

      @id = HPXML::get_id(foundation_wall)
      @exterior_adjacent_to = XMLHelper.get_value(foundation_wall, 'ExteriorAdjacentTo', :string)
      @interior_adjacent_to = XMLHelper.get_value(foundation_wall, 'InteriorAdjacentTo', :string)
      @length = XMLHelper.get_value(foundation_wall, 'Length', :float)
      @height = XMLHelper.get_value(foundation_wall, 'Height', :float)
      @area = XMLHelper.get_value(foundation_wall, 'Area', :float)
      @orientation = XMLHelper.get_value(foundation_wall, 'Orientation', :string)
      @azimuth = XMLHelper.get_value(foundation_wall, 'Azimuth', :integer)
      @thickness = XMLHelper.get_value(foundation_wall, 'Thickness', :float)
      @depth_below_grade = XMLHelper.get_value(foundation_wall, 'DepthBelowGrade', :float)
      interior_finish = XMLHelper.get_element(foundation_wall, 'InteriorFinish')
      if not interior_finish.nil?
        @interior_finish_type = XMLHelper.get_value(interior_finish, 'Type', :string)
        @interior_finish_thickness = XMLHelper.get_value(interior_finish, 'Thickness', :float)
      end
      insulation = XMLHelper.get_element(foundation_wall, 'Insulation')
      if not insulation.nil?
        @insulation_id = HPXML::get_id(insulation)
        @insulation_assembly_r_value = XMLHelper.get_value(insulation, 'AssemblyEffectiveRValue', :float)
        @insulation_continuous_r_value = XMLHelper.get_value(insulation, "Layer[InstallationType='continuous']/NominalRValue", :float)
        @insulation_interior_r_value = XMLHelper.get_value(insulation, "Layer[InstallationType='continuous - interior']/NominalRValue", :float)
        @insulation_interior_distance_to_top = XMLHelper.get_value(insulation, "Layer[InstallationType='continuous - interior']/extension/DistanceToTopOfInsulation", :float)
        @insulation_interior_distance_to_bottom = XMLHelper.get_value(insulation, "Layer[InstallationType='continuous - interior']/extension/DistanceToBottomOfInsulation", :float)
        @insulation_exterior_r_value = XMLHelper.get_value(insulation, "Layer[InstallationType='continuous - exterior']/NominalRValue", :float)
        @insulation_exterior_distance_to_top = XMLHelper.get_value(insulation, "Layer[InstallationType='continuous - exterior']/extension/DistanceToTopOfInsulation", :float)
        @insulation_exterior_distance_to_bottom = XMLHelper.get_value(insulation, "Layer[InstallationType='continuous - exterior']/extension/DistanceToBottomOfInsulation", :float)
      end
    end
  end

  class FrameFloors < BaseArrayElement
    def add(**kwargs)
      self << FrameFloor.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Enclosure/FrameFloors/FrameFloor').each do |frame_floor|
        self << FrameFloor.new(@hpxml_object, frame_floor)
      end
    end
  end

  class FrameFloor < BaseElement
    ATTRS = [:id, :exterior_adjacent_to, :interior_adjacent_to, :area, :insulation_id,
             :insulation_assembly_r_value, :insulation_cavity_r_value, :insulation_continuous_r_value,
             :other_space_above_or_below, :interior_finish_type, :interior_finish_thickness]
    attr_accessor(*ATTRS)

    def is_ceiling
      if [LocationAtticVented, LocationAtticUnvented].include? @interior_adjacent_to
        return true
      elsif [LocationAtticVented, LocationAtticUnvented].include? @exterior_adjacent_to
        return true
      elsif [LocationOtherHousingUnit, LocationOtherHeatedSpace, LocationOtherMultifamilyBufferSpace, LocationOtherNonFreezingSpace].include?(@exterior_adjacent_to) && (@other_space_above_or_below == FrameFloorOtherSpaceAbove)
        return true
      end

      return false
    end

    def is_floor
      !is_ceiling
    end

    def is_exterior
      if @exterior_adjacent_to == LocationOutside
        return true
      end

      return false
    end

    def is_interior
      return !is_exterior
    end

    def is_adiabatic
      return HPXML::is_adiabatic(self)
    end

    def is_thermal_boundary
      return HPXML::is_thermal_boundary(self)
    end

    def is_exterior_thermal_boundary
      return (is_exterior && is_thermal_boundary)
    end

    def is_conditioned
      return HPXML::is_conditioned(self)
    end

    def delete
      @hpxml_object.frame_floors.delete(self)
      @hpxml_object.attics.each do |attic|
        attic.attached_to_frame_floor_idrefs.delete(@id) unless attic.attached_to_frame_floor_idrefs.nil?
      end
      @hpxml_object.foundations.each do |foundation|
        foundation.attached_to_frame_floor_idrefs.delete(@id) unless foundation.attached_to_frame_floor_idrefs.nil?
      end
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      frame_floors = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Enclosure', 'FrameFloors'])
      frame_floor = XMLHelper.add_element(frame_floors, 'FrameFloor')
      sys_id = XMLHelper.add_element(frame_floor, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(frame_floor, 'ExteriorAdjacentTo', @exterior_adjacent_to, :string) unless @exterior_adjacent_to.nil?
      XMLHelper.add_element(frame_floor, 'InteriorAdjacentTo', @interior_adjacent_to, :string) unless @interior_adjacent_to.nil?
      XMLHelper.add_element(frame_floor, 'Area', @area, :float) unless @area.nil?
      if (not @interior_finish_type.nil?) || (not @interior_finish_thickness.nil?)
        interior_finish = XMLHelper.add_element(frame_floor, 'InteriorFinish')
        XMLHelper.add_element(interior_finish, 'Type', @interior_finish_type, :string, @interior_finish_type_isdefaulted) unless @interior_finish_type.nil?
        XMLHelper.add_element(interior_finish, 'Thickness', @interior_finish_thickness, :float, @interior_finish_thickness_isdefaulted) unless @interior_finish_thickness.nil?
      end
      insulation = XMLHelper.add_element(frame_floor, 'Insulation')
      sys_id = XMLHelper.add_element(insulation, 'SystemIdentifier')
      if not @insulation_id.nil?
        XMLHelper.add_attribute(sys_id, 'id', @insulation_id)
      else
        XMLHelper.add_attribute(sys_id, 'id', @id + 'Insulation')
      end
      XMLHelper.add_element(insulation, 'AssemblyEffectiveRValue', @insulation_assembly_r_value, :float) unless @insulation_assembly_r_value.nil?
      if not @insulation_cavity_r_value.nil?
        layer = XMLHelper.add_element(insulation, 'Layer')
        XMLHelper.add_element(layer, 'InstallationType', 'cavity', :string)
        XMLHelper.add_element(layer, 'NominalRValue', @insulation_cavity_r_value, :float)
      end
      if not @insulation_continuous_r_value.nil?
        layer = XMLHelper.add_element(insulation, 'Layer')
        XMLHelper.add_element(layer, 'InstallationType', 'continuous', :string)
        XMLHelper.add_element(layer, 'NominalRValue', @insulation_continuous_r_value, :float)
      end
      XMLHelper.add_extension(frame_floor, 'OtherSpaceAboveOrBelow', @other_space_above_or_below, :string) unless @other_space_above_or_below.nil?
    end

    def from_oga(frame_floor)
      return if frame_floor.nil?

      @id = HPXML::get_id(frame_floor)
      @exterior_adjacent_to = XMLHelper.get_value(frame_floor, 'ExteriorAdjacentTo', :string)
      @interior_adjacent_to = XMLHelper.get_value(frame_floor, 'InteriorAdjacentTo', :string)
      @area = XMLHelper.get_value(frame_floor, 'Area', :float)
      interior_finish = XMLHelper.get_element(frame_floor, 'InteriorFinish')
      if not interior_finish.nil?
        @interior_finish_type = XMLHelper.get_value(interior_finish, 'Type', :string)
        @interior_finish_thickness = XMLHelper.get_value(interior_finish, 'Thickness', :float)
      end
      insulation = XMLHelper.get_element(frame_floor, 'Insulation')
      if not insulation.nil?
        @insulation_id = HPXML::get_id(insulation)
        @insulation_assembly_r_value = XMLHelper.get_value(insulation, 'AssemblyEffectiveRValue', :float)
        @insulation_cavity_r_value = XMLHelper.get_value(insulation, "Layer[InstallationType='cavity']/NominalRValue", :float)
        @insulation_continuous_r_value = XMLHelper.get_value(insulation, "Layer[InstallationType='continuous']/NominalRValue", :float)
      end
      @other_space_above_or_below = XMLHelper.get_value(frame_floor, 'extension/OtherSpaceAboveOrBelow', :string)
    end
  end

  class Slabs < BaseArrayElement
    def add(**kwargs)
      self << Slab.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Enclosure/Slabs/Slab').each do |slab|
        self << Slab.new(@hpxml_object, slab)
      end
    end
  end

  class Slab < BaseElement
    ATTRS = [:id, :interior_adjacent_to, :exterior_adjacent_to, :area, :thickness, :exposed_perimeter,
             :perimeter_insulation_depth, :under_slab_insulation_width,
             :under_slab_insulation_spans_entire_slab, :depth_below_grade, :carpet_fraction,
             :carpet_r_value, :perimeter_insulation_id, :perimeter_insulation_r_value,
             :under_slab_insulation_id, :under_slab_insulation_r_value]
    attr_accessor(*ATTRS)

    def exterior_adjacent_to
      return LocationGround
    end

    def is_exterior
      return true
    end

    def is_interior
      return !is_exterior
    end

    def is_thermal_boundary
      return HPXML::is_thermal_boundary(self)
    end

    def is_exterior_thermal_boundary
      return (is_exterior && is_thermal_boundary)
    end

    def is_conditioned
      return HPXML::is_conditioned(self)
    end

    def delete
      @hpxml_object.slabs.delete(self)
      @hpxml_object.foundations.each do |foundation|
        foundation.attached_to_slab_idrefs.delete(@id) unless foundation.attached_to_slab_idrefs.nil?
      end
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      slabs = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Enclosure', 'Slabs'])
      slab = XMLHelper.add_element(slabs, 'Slab')
      sys_id = XMLHelper.add_element(slab, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(slab, 'InteriorAdjacentTo', @interior_adjacent_to, :string) unless @interior_adjacent_to.nil?
      XMLHelper.add_element(slab, 'Area', @area, :float) unless @area.nil?
      XMLHelper.add_element(slab, 'Thickness', @thickness, :float, @thickness_isdefaulted) unless @thickness.nil?
      XMLHelper.add_element(slab, 'ExposedPerimeter', @exposed_perimeter, :float) unless @exposed_perimeter.nil?
      XMLHelper.add_element(slab, 'PerimeterInsulationDepth', @perimeter_insulation_depth, :float) unless @perimeter_insulation_depth.nil?
      XMLHelper.add_element(slab, 'UnderSlabInsulationWidth', @under_slab_insulation_width, :float) unless @under_slab_insulation_width.nil?
      XMLHelper.add_element(slab, 'UnderSlabInsulationSpansEntireSlab', @under_slab_insulation_spans_entire_slab, :boolean) unless @under_slab_insulation_spans_entire_slab.nil?
      XMLHelper.add_element(slab, 'DepthBelowGrade', @depth_below_grade, :float) unless @depth_below_grade.nil?
      insulation = XMLHelper.add_element(slab, 'PerimeterInsulation')
      sys_id = XMLHelper.add_element(insulation, 'SystemIdentifier')
      if not @perimeter_insulation_id.nil?
        XMLHelper.add_attribute(sys_id, 'id', @perimeter_insulation_id)
      else
        XMLHelper.add_attribute(sys_id, 'id', @id + 'PerimeterInsulation')
      end
      layer = XMLHelper.add_element(insulation, 'Layer')
      XMLHelper.add_element(layer, 'NominalRValue', @perimeter_insulation_r_value, :float) unless @perimeter_insulation_r_value.nil?
      insulation = XMLHelper.add_element(slab, 'UnderSlabInsulation')
      sys_id = XMLHelper.add_element(insulation, 'SystemIdentifier')
      if not @under_slab_insulation_id.nil?
        XMLHelper.add_attribute(sys_id, 'id', @under_slab_insulation_id)
      else
        XMLHelper.add_attribute(sys_id, 'id', @id + 'UnderSlabInsulation')
      end
      layer = XMLHelper.add_element(insulation, 'Layer')
      XMLHelper.add_element(layer, 'NominalRValue', @under_slab_insulation_r_value, :float) unless @under_slab_insulation_r_value.nil?
      XMLHelper.add_extension(slab, 'CarpetFraction', @carpet_fraction, :float, @carpet_fraction_isdefaulted) unless @carpet_fraction.nil?
      XMLHelper.add_extension(slab, 'CarpetRValue', @carpet_r_value, :float, @carpet_r_value_isdefaulted) unless @carpet_r_value.nil?
    end

    def from_oga(slab)
      return if slab.nil?

      @id = HPXML::get_id(slab)
      @interior_adjacent_to = XMLHelper.get_value(slab, 'InteriorAdjacentTo', :string)
      @area = XMLHelper.get_value(slab, 'Area', :float)
      @thickness = XMLHelper.get_value(slab, 'Thickness', :float)
      @exposed_perimeter = XMLHelper.get_value(slab, 'ExposedPerimeter', :float)
      @perimeter_insulation_depth = XMLHelper.get_value(slab, 'PerimeterInsulationDepth', :float)
      @under_slab_insulation_width = XMLHelper.get_value(slab, 'UnderSlabInsulationWidth', :float)
      @under_slab_insulation_spans_entire_slab = XMLHelper.get_value(slab, 'UnderSlabInsulationSpansEntireSlab', :boolean)
      @depth_below_grade = XMLHelper.get_value(slab, 'DepthBelowGrade', :float)
      perimeter_insulation = XMLHelper.get_element(slab, 'PerimeterInsulation')
      if not perimeter_insulation.nil?
        @perimeter_insulation_id = HPXML::get_id(perimeter_insulation)
        @perimeter_insulation_r_value = XMLHelper.get_value(perimeter_insulation, 'Layer/NominalRValue', :float)
      end
      under_slab_insulation = XMLHelper.get_element(slab, 'UnderSlabInsulation')
      if not under_slab_insulation.nil?
        @under_slab_insulation_id = HPXML::get_id(under_slab_insulation)
        @under_slab_insulation_r_value = XMLHelper.get_value(under_slab_insulation, 'Layer/NominalRValue', :float)
      end
      @carpet_fraction = XMLHelper.get_value(slab, 'extension/CarpetFraction', :float)
      @carpet_r_value = XMLHelper.get_value(slab, 'extension/CarpetRValue', :float)
    end
  end

  class Windows < BaseArrayElement
    def add(**kwargs)
      self << Window.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Enclosure/Windows/Window').each do |window|
        self << Window.new(@hpxml_object, window)
      end
    end
  end

  class Window < BaseElement
    ATTRS = [:id, :area, :azimuth, :orientation, :frame_type, :aluminum_thermal_break, :glass_layers,
             :glass_type, :gas_fill, :ufactor, :shgc, :interior_shading_factor_summer,
             :interior_shading_factor_winter, :interior_shading_type, :exterior_shading_factor_summer,
             :exterior_shading_factor_winter, :exterior_shading_type, :overhangs_depth,
             :overhangs_distance_to_top_of_window, :overhangs_distance_to_bottom_of_window,
             :fraction_operable, :performance_class, :wall_idref]
    attr_accessor(*ATTRS)

    def wall
      return if @wall_idref.nil?

      (@hpxml_object.walls + @hpxml_object.foundation_walls).each do |wall|
        next unless wall.id == @wall_idref

        return wall
      end
      fail "Attached wall '#{@wall_idref}' not found for window '#{@id}'."
    end

    def is_exterior
      return wall.is_exterior
    end

    def is_interior
      return !is_exterior
    end

    def is_thermal_boundary
      return HPXML::is_thermal_boundary(wall)
    end

    def is_exterior_thermal_boundary
      return (is_exterior && is_thermal_boundary)
    end

    def is_conditioned
      return HPXML::is_conditioned(self)
    end

    def delete
      @hpxml_object.windows.delete(self)
    end

    def check_for_errors
      errors = []
      begin; wall; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      windows = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Enclosure', 'Windows'])
      window = XMLHelper.add_element(windows, 'Window')
      sys_id = XMLHelper.add_element(window, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(window, 'Area', @area, :float) unless @area.nil?
      XMLHelper.add_element(window, 'Azimuth', @azimuth, :integer, @azimuth_isdefaulted) unless @azimuth.nil?
      XMLHelper.add_element(window, 'Orientation', @orientation, :string, @orientation_isdefaulted) unless @orientation.nil?
      if not @frame_type.nil?
        frame_type_el = XMLHelper.add_element(window, 'FrameType')
        frame_type = XMLHelper.add_element(frame_type_el, @frame_type)
        if @frame_type == HPXML::WindowFrameTypeAluminum
          XMLHelper.add_element(frame_type, 'ThermalBreak', @aluminum_thermal_break, :boolean) unless @aluminum_thermal_break.nil?
        end
      end
      XMLHelper.add_element(window, 'GlassLayers', @glass_layers, :string) unless @glass_layers.nil?
      XMLHelper.add_element(window, 'GlassType', @glass_type, :string) unless @glass_type.nil?
      XMLHelper.add_element(window, 'GasFill', @gas_fill, :string) unless @gas_fill.nil?
      XMLHelper.add_element(window, 'UFactor', @ufactor, :float) unless @ufactor.nil?
      XMLHelper.add_element(window, 'SHGC', @shgc, :float) unless @shgc.nil?
      if (not @exterior_shading_type.nil?) || (not @exterior_shading_factor_summer.nil?) || (not @exterior_shading_factor_winter.nil?)
        exterior_shading = XMLHelper.add_element(window, 'ExteriorShading')
        sys_id = XMLHelper.add_element(exterior_shading, 'SystemIdentifier')
        XMLHelper.add_attribute(sys_id, 'id', "#{id}ExteriorShading")
        XMLHelper.add_element(exterior_shading, 'Type', @exterior_shading_type, :string) unless @exterior_shading_type.nil?
        XMLHelper.add_element(exterior_shading, 'SummerShadingCoefficient', @exterior_shading_factor_summer, :float, @exterior_shading_factor_summer_isdefaulted) unless @exterior_shading_factor_summer.nil?
        XMLHelper.add_element(exterior_shading, 'WinterShadingCoefficient', @exterior_shading_factor_winter, :float, @exterior_shading_factor_winter_isdefaulted) unless @exterior_shading_factor_winter.nil?
      end
      if (not @interior_shading_type.nil?) || (not @interior_shading_factor_summer.nil?) || (not @interior_shading_factor_winter.nil?)
        interior_shading = XMLHelper.add_element(window, 'InteriorShading')
        sys_id = XMLHelper.add_element(interior_shading, 'SystemIdentifier')
        XMLHelper.add_attribute(sys_id, 'id', "#{id}InteriorShading")
        XMLHelper.add_element(interior_shading, 'Type', @interior_shading_type, :string) unless @interior_shading_type.nil?
        XMLHelper.add_element(interior_shading, 'SummerShadingCoefficient', @interior_shading_factor_summer, :float, @interior_shading_factor_summer_isdefaulted) unless @interior_shading_factor_summer.nil?
        XMLHelper.add_element(interior_shading, 'WinterShadingCoefficient', @interior_shading_factor_winter, :float, @interior_shading_factor_winter_isdefaulted) unless @interior_shading_factor_winter.nil?
      end
      if (not @overhangs_depth.nil?) || (not @overhangs_distance_to_top_of_window.nil?) || (not @overhangs_distance_to_bottom_of_window.nil?)
        overhangs = XMLHelper.add_element(window, 'Overhangs')
        XMLHelper.add_element(overhangs, 'Depth', @overhangs_depth, :float) unless @overhangs_depth.nil?
        XMLHelper.add_element(overhangs, 'DistanceToTopOfWindow', @overhangs_distance_to_top_of_window, :float) unless @overhangs_distance_to_top_of_window.nil?
        XMLHelper.add_element(overhangs, 'DistanceToBottomOfWindow', @overhangs_distance_to_bottom_of_window, :float) unless @overhangs_distance_to_bottom_of_window.nil?
      end
      XMLHelper.add_element(window, 'FractionOperable', @fraction_operable, :float, @fraction_operable_isdefaulted) unless @fraction_operable.nil?
      XMLHelper.add_element(window, 'PerformanceClass', @performance_class, :string, @performance_class_isdefaulted) unless @performance_class.nil?
      if not @wall_idref.nil?
        attached_to_wall = XMLHelper.add_element(window, 'AttachedToWall')
        XMLHelper.add_attribute(attached_to_wall, 'idref', @wall_idref)
      end
    end

    def from_oga(window)
      return if window.nil?

      @id = HPXML::get_id(window)
      @area = XMLHelper.get_value(window, 'Area', :float)
      @azimuth = XMLHelper.get_value(window, 'Azimuth', :integer)
      @orientation = XMLHelper.get_value(window, 'Orientation', :string)
      @frame_type = XMLHelper.get_child_name(window, 'FrameType')
      if not @frame_type.nil?
        @aluminum_thermal_break = XMLHelper.get_value(window, 'FrameType/Aluminum/ThermalBreak', :boolean)
      end
      @glass_layers = XMLHelper.get_value(window, 'GlassLayers', :string)
      @glass_type = XMLHelper.get_value(window, 'GlassType', :string)
      @gas_fill = XMLHelper.get_value(window, 'GasFill', :string)
      @ufactor = XMLHelper.get_value(window, 'UFactor', :float)
      @shgc = XMLHelper.get_value(window, 'SHGC', :float)
      @exterior_shading_type = XMLHelper.get_value(window, 'ExteriorShading/Type', :string)
      @exterior_shading_factor_summer = XMLHelper.get_value(window, 'ExteriorShading/SummerShadingCoefficient', :float)
      @exterior_shading_factor_winter = XMLHelper.get_value(window, 'ExteriorShading/WinterShadingCoefficient', :float)
      @interior_shading_type = XMLHelper.get_value(window, 'InteriorShading/Type', :string)
      @interior_shading_factor_summer = XMLHelper.get_value(window, 'InteriorShading/SummerShadingCoefficient', :float)
      @interior_shading_factor_winter = XMLHelper.get_value(window, 'InteriorShading/WinterShadingCoefficient', :float)
      @overhangs_depth = XMLHelper.get_value(window, 'Overhangs/Depth', :float)
      @overhangs_distance_to_top_of_window = XMLHelper.get_value(window, 'Overhangs/DistanceToTopOfWindow', :float)
      @overhangs_distance_to_bottom_of_window = XMLHelper.get_value(window, 'Overhangs/DistanceToBottomOfWindow', :float)
      @fraction_operable = XMLHelper.get_value(window, 'FractionOperable', :float)
      @performance_class = XMLHelper.get_value(window, 'PerformanceClass', :string)
      @wall_idref = HPXML::get_idref(XMLHelper.get_element(window, 'AttachedToWall'))
    end
  end

  class Skylights < BaseArrayElement
    def add(**kwargs)
      self << Skylight.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Enclosure/Skylights/Skylight').each do |skylight|
        self << Skylight.new(@hpxml_object, skylight)
      end
    end
  end

  class Skylight < BaseElement
    ATTRS = [:id, :area, :azimuth, :orientation, :frame_type, :aluminum_thermal_break, :glass_layers,
             :glass_type, :gas_fill, :ufactor, :shgc, :interior_shading_factor_summer,
             :interior_shading_factor_winter, :interior_shading_type, :exterior_shading_factor_summer,
             :exterior_shading_factor_winter, :exterior_shading_type, :roof_idref]
    attr_accessor(*ATTRS)

    def roof
      return if @roof_idref.nil?

      @hpxml_object.roofs.each do |roof|
        next unless roof.id == @roof_idref

        return roof
      end
      fail "Attached roof '#{@roof_idref}' not found for skylight '#{@id}'."
    end

    def is_exterior
      return roof.is_exterior
    end

    def is_interior
      return !is_exterior
    end

    def is_thermal_boundary
      return HPXML::is_thermal_boundary(roof)
    end

    def is_exterior_thermal_boundary
      return (is_exterior && is_thermal_boundary)
    end

    def is_conditioned
      return HPXML::is_conditioned(self)
    end

    def delete
      @hpxml_object.skylights.delete(self)
    end

    def check_for_errors
      errors = []
      begin; roof; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      skylights = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Enclosure', 'Skylights'])
      skylight = XMLHelper.add_element(skylights, 'Skylight')
      sys_id = XMLHelper.add_element(skylight, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(skylight, 'Area', @area, :float) unless @area.nil?
      XMLHelper.add_element(skylight, 'Azimuth', @azimuth, :integer, @azimuth_isdefaulted) unless @azimuth.nil?
      XMLHelper.add_element(skylight, 'Orientation', @orientation, :string, @orientation_isdefaulted) unless @orientation.nil?
      if not @frame_type.nil?
        frame_type_el = XMLHelper.add_element(skylight, 'FrameType')
        frame_type = XMLHelper.add_element(frame_type_el, @frame_type)
        if @frame_type == HPXML::WindowFrameTypeAluminum
          XMLHelper.add_element(frame_type, 'ThermalBreak', @aluminum_thermal_break, :boolean) unless @aluminum_thermal_break.nil?
        end
      end
      XMLHelper.add_element(skylight, 'GlassLayers', @glass_layers, :string) unless @glass_layers.nil?
      XMLHelper.add_element(skylight, 'GlassType', @glass_type, :string) unless @glass_type.nil?
      XMLHelper.add_element(skylight, 'GasFill', @gas_fill, :string) unless @gas_fill.nil?
      XMLHelper.add_element(skylight, 'UFactor', @ufactor, :float) unless @ufactor.nil?
      XMLHelper.add_element(skylight, 'SHGC', @shgc, :float) unless @shgc.nil?
      if (not @exterior_shading_type.nil?) || (not @exterior_shading_factor_summer.nil?) || (not @exterior_shading_factor_winter.nil?)
        exterior_shading = XMLHelper.add_element(skylight, 'ExteriorShading')
        sys_id = XMLHelper.add_element(exterior_shading, 'SystemIdentifier')
        XMLHelper.add_attribute(sys_id, 'id', "#{id}ExteriorShading")
        XMLHelper.add_element(exterior_shading, 'Type', @exterior_shading_type, :string) unless @exterior_shading_type.nil?
        XMLHelper.add_element(exterior_shading, 'SummerShadingCoefficient', @exterior_shading_factor_summer, :float, @exterior_shading_factor_summer_isdefaulted) unless @exterior_shading_factor_summer.nil?
        XMLHelper.add_element(exterior_shading, 'WinterShadingCoefficient', @exterior_shading_factor_winter, :float, @exterior_shading_factor_winter_isdefaulted) unless @exterior_shading_factor_winter.nil?
      end
      if (not @interior_shading_type.nil?) || (not @interior_shading_factor_summer.nil?) || (not @interior_shading_factor_winter.nil?)
        interior_shading = XMLHelper.add_element(skylight, 'InteriorShading')
        sys_id = XMLHelper.add_element(interior_shading, 'SystemIdentifier')
        XMLHelper.add_attribute(sys_id, 'id', "#{id}InteriorShading")
        XMLHelper.add_element(interior_shading, 'Type', @interior_shading_type, :string) unless @interior_shading_type.nil?
        XMLHelper.add_element(interior_shading, 'SummerShadingCoefficient', @interior_shading_factor_summer, :float, @interior_shading_factor_summer_isdefaulted) unless @interior_shading_factor_summer.nil?
        XMLHelper.add_element(interior_shading, 'WinterShadingCoefficient', @interior_shading_factor_winter, :float, @interior_shading_factor_winter_isdefaulted) unless @interior_shading_factor_winter.nil?
      end
      if not @roof_idref.nil?
        attached_to_roof = XMLHelper.add_element(skylight, 'AttachedToRoof')
        XMLHelper.add_attribute(attached_to_roof, 'idref', @roof_idref)
      end
    end

    def from_oga(skylight)
      return if skylight.nil?

      @id = HPXML::get_id(skylight)
      @area = XMLHelper.get_value(skylight, 'Area', :float)
      @azimuth = XMLHelper.get_value(skylight, 'Azimuth', :integer)
      @orientation = XMLHelper.get_value(skylight, 'Orientation', :string)
      @frame_type = XMLHelper.get_child_name(skylight, 'FrameType')
      @aluminum_thermal_break = XMLHelper.get_value(skylight, 'FrameType/Aluminum/ThermalBreak', :boolean)
      @glass_layers = XMLHelper.get_value(skylight, 'GlassLayers', :string)
      @glass_type = XMLHelper.get_value(skylight, 'GlassType', :string)
      @gas_fill = XMLHelper.get_value(skylight, 'GasFill', :string)
      @ufactor = XMLHelper.get_value(skylight, 'UFactor', :float)
      @shgc = XMLHelper.get_value(skylight, 'SHGC', :float)
      @exterior_shading_type = XMLHelper.get_value(skylight, 'ExteriorShading/Type', :string)
      @exterior_shading_factor_summer = XMLHelper.get_value(skylight, 'ExteriorShading/SummerShadingCoefficient', :float)
      @exterior_shading_factor_winter = XMLHelper.get_value(skylight, 'ExteriorShading/WinterShadingCoefficient', :float)
      @interior_shading_type = XMLHelper.get_value(skylight, 'InteriorShading/Type', :string)
      @interior_shading_factor_summer = XMLHelper.get_value(skylight, 'InteriorShading/SummerShadingCoefficient', :float)
      @interior_shading_factor_winter = XMLHelper.get_value(skylight, 'InteriorShading/WinterShadingCoefficient', :float)
      @roof_idref = HPXML::get_idref(XMLHelper.get_element(skylight, 'AttachedToRoof'))
    end
  end

  class Doors < BaseArrayElement
    def add(**kwargs)
      self << Door.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Enclosure/Doors/Door').each do |door|
        self << Door.new(@hpxml_object, door)
      end
    end
  end

  class Door < BaseElement
    ATTRS = [:id, :wall_idref, :area, :azimuth, :orientation, :r_value]
    attr_accessor(*ATTRS)

    def wall
      return if @wall_idref.nil?

      (@hpxml_object.walls + @hpxml_object.foundation_walls).each do |wall|
        next unless wall.id == @wall_idref

        return wall
      end
      fail "Attached wall '#{@wall_idref}' not found for door '#{@id}'."
    end

    def is_exterior
      return wall.is_exterior
    end

    def is_interior
      return !is_exterior
    end

    def is_thermal_boundary
      return HPXML::is_thermal_boundary(wall)
    end

    def is_exterior_thermal_boundary
      return (is_exterior && is_thermal_boundary)
    end

    def is_conditioned
      return HPXML::is_conditioned(self)
    end

    def delete
      @hpxml_object.doors.delete(self)
    end

    def check_for_errors
      errors = []
      begin; wall; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      doors = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Enclosure', 'Doors'])
      door = XMLHelper.add_element(doors, 'Door')
      sys_id = XMLHelper.add_element(door, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      if not @wall_idref.nil?
        attached_to_wall = XMLHelper.add_element(door, 'AttachedToWall')
        XMLHelper.add_attribute(attached_to_wall, 'idref', @wall_idref)
      end
      XMLHelper.add_element(door, 'Area', @area, :float) unless @area.nil?
      XMLHelper.add_element(door, 'Azimuth', @azimuth, :integer, @azimuth_isdefaulted) unless @azimuth.nil?
      XMLHelper.add_element(door, 'Orientation', @orientation, :string, @orientation_isdefaulted) unless @orientation.nil?
      XMLHelper.add_element(door, 'RValue', @r_value, :float) unless @r_value.nil?
    end

    def from_oga(door)
      return if door.nil?

      @id = HPXML::get_id(door)
      @wall_idref = HPXML::get_idref(XMLHelper.get_element(door, 'AttachedToWall'))
      @area = XMLHelper.get_value(door, 'Area', :float)
      @azimuth = XMLHelper.get_value(door, 'Azimuth', :integer)
      @orientation = XMLHelper.get_value(door, 'Orientation', :string)
      @r_value = XMLHelper.get_value(door, 'RValue', :float)
    end
  end

  class HeatingSystems < BaseArrayElement
    def add(**kwargs)
      self << HeatingSystem.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem').each do |heating_system|
        self << HeatingSystem.new(@hpxml_object, heating_system)
      end
    end

    def total_fraction_heat_load_served
      map { |htg_sys| htg_sys.fraction_heat_load_served.to_f }.sum(0.0)
    end
  end

  class HeatingSystem < BaseElement
    ATTRS = [:id, :distribution_system_idref, :year_installed, :heating_system_type,
             :heating_system_fuel, :heating_capacity, :heating_efficiency_afue,
             :heating_efficiency_percent, :fraction_heat_load_served, :electric_auxiliary_energy,
             :third_party_certification, :seed_id, :is_shared_system, :number_of_units_served,
             :shared_loop_watts, :shared_loop_motor_efficiency, :fan_coil_watts, :fan_watts_per_cfm,
             :airflow_defect_ratio, :fan_watts, :heating_airflow_cfm, :location]
    attr_accessor(*ATTRS)

    def distribution_system
      return if @distribution_system_idref.nil?

      @hpxml_object.hvac_distributions.each do |hvac_distribution|
        next unless hvac_distribution.id == @distribution_system_idref

        return hvac_distribution
      end
      fail "Attached HVAC distribution system '#{@distribution_system_idref}' not found for HVAC system '#{@id}'."
    end

    def attached_cooling_system
      return if distribution_system.nil?

      distribution_system.hvac_systems.each do |hvac_system|
        next if hvac_system.id == @id

        return hvac_system
      end
      return
    end

    def delete
      @hpxml_object.heating_systems.delete(self)
      @hpxml_object.water_heating_systems.each do |water_heating_system|
        next unless water_heating_system.related_hvac_idref == @id

        water_heating_system.related_hvac_idref = nil
      end
    end

    def check_for_errors
      errors = []
      begin; distribution_system; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      hvac_plant = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'HVAC', 'HVACPlant'])
      heating_system = XMLHelper.add_element(hvac_plant, 'HeatingSystem')
      sys_id = XMLHelper.add_element(heating_system, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(heating_system, 'UnitLocation', @location, :string) unless @location.nil?
      XMLHelper.add_element(heating_system, 'YearInstalled', @year_installed, :integer) unless @year_installed.nil?
      XMLHelper.add_element(heating_system, 'ThirdPartyCertification', @third_party_certification, :string) unless @third_party_certification.nil?
      if not @distribution_system_idref.nil?
        distribution_system = XMLHelper.add_element(heating_system, 'DistributionSystem')
        XMLHelper.add_attribute(distribution_system, 'idref', @distribution_system_idref)
      end
      XMLHelper.add_element(heating_system, 'IsSharedSystem', @is_shared_system, :boolean) unless @is_shared_system.nil?
      XMLHelper.add_element(heating_system, 'NumberofUnitsServed', @number_of_units_served, :integer) unless @number_of_units_served.nil?
      if not @heating_system_type.nil?
        heating_system_type_el = XMLHelper.add_element(heating_system, 'HeatingSystemType')
        XMLHelper.add_element(heating_system_type_el, @heating_system_type)
      end
      XMLHelper.add_element(heating_system, 'HeatingSystemFuel', @heating_system_fuel, :string) unless @heating_system_fuel.nil?
      XMLHelper.add_element(heating_system, 'HeatingCapacity', @heating_capacity, :float, @heating_capacity_isdefaulted) unless @heating_capacity.nil?

      efficiency_units = nil
      efficiency_value = nil
      if [HVACTypeFurnace, HVACTypeWallFurnace, HVACTypeFloorFurnace, HVACTypeBoiler].include? @heating_system_type
        efficiency_units = UnitsAFUE
        efficiency_value = @heating_efficiency_afue
        efficiency_value_isdefaulted = @heating_efficiency_afue_isdefaulted
      elsif [HVACTypeElectricResistance, HVACTypeStove, HVACTypePortableHeater, HVACTypeFixedHeater, HVACTypeFireplace].include? @heating_system_type
        efficiency_units = UnitsPercent
        efficiency_value = @heating_efficiency_percent
        efficiency_value_isdefaulted = @heating_efficiency_percent_isdefaulted
      end
      if not efficiency_value.nil?
        annual_efficiency = XMLHelper.add_element(heating_system, 'AnnualHeatingEfficiency')
        XMLHelper.add_element(annual_efficiency, 'Units', efficiency_units, :string)
        XMLHelper.add_element(annual_efficiency, 'Value', efficiency_value, :float, efficiency_value_isdefaulted)
      end
      XMLHelper.add_element(heating_system, 'FractionHeatLoadServed', @fraction_heat_load_served, :float, @fraction_heat_load_served_isdefaulted) unless @fraction_heat_load_served.nil?
      XMLHelper.add_element(heating_system, 'ElectricAuxiliaryEnergy', @electric_auxiliary_energy, :float, @electric_auxiliary_energy_isdefaulted) unless @electric_auxiliary_energy.nil?
      XMLHelper.add_extension(heating_system, 'SharedLoopWatts', @shared_loop_watts, :float) unless @shared_loop_watts.nil?
      XMLHelper.add_extension(heating_system, 'SharedLoopMotorEfficiency', @shared_loop_motor_efficiency, :float) unless @shared_loop_motor_efficiency.nil?
      XMLHelper.add_extension(heating_system, 'FanCoilWatts', @fan_coil_watts, :float) unless @fan_coil_watts.nil?
      XMLHelper.add_extension(heating_system, 'FanPowerWattsPerCFM', @fan_watts_per_cfm, :float, @fan_watts_per_cfm_isdefaulted) unless @fan_watts_per_cfm.nil?
      XMLHelper.add_extension(heating_system, 'FanPowerWatts', @fan_watts, :float, @fan_watts_isdefaulted) unless @fan_watts.nil?
      XMLHelper.add_extension(heating_system, 'AirflowDefectRatio', @airflow_defect_ratio, :float, @airflow_defect_ratio_isdefaulted) unless @airflow_defect_ratio.nil?
      XMLHelper.add_extension(heating_system, 'HeatingAirflowCFM', @heating_airflow_cfm, :float, @heating_airflow_cfm_isdefaulted) unless @heating_airflow_cfm.nil?
      XMLHelper.add_extension(heating_system, 'SeedId', @seed_id, :string) unless @seed_id.nil?
    end

    def from_oga(heating_system)
      return if heating_system.nil?

      @id = HPXML::get_id(heating_system)
      @location = XMLHelper.get_value(heating_system, 'UnitLocation', :string)
      @year_installed = XMLHelper.get_value(heating_system, 'YearInstalled', :integer)
      @third_party_certification = XMLHelper.get_value(heating_system, 'ThirdPartyCertification', :string)
      @distribution_system_idref = HPXML::get_idref(XMLHelper.get_element(heating_system, 'DistributionSystem'))
      @is_shared_system = XMLHelper.get_value(heating_system, 'IsSharedSystem', :boolean)
      @number_of_units_served = XMLHelper.get_value(heating_system, 'NumberofUnitsServed', :integer)
      @heating_system_type = XMLHelper.get_child_name(heating_system, 'HeatingSystemType')
      @heating_system_fuel = XMLHelper.get_value(heating_system, 'HeatingSystemFuel', :string)
      @heating_capacity = XMLHelper.get_value(heating_system, 'HeatingCapacity', :float)
      if [HVACTypeFurnace, HVACTypeWallFurnace, HVACTypeFloorFurnace, HVACTypeBoiler].include? @heating_system_type
        @heating_efficiency_afue = XMLHelper.get_value(heating_system, "AnnualHeatingEfficiency[Units='#{UnitsAFUE}']/Value", :float)
      elsif [HVACTypeElectricResistance, HVACTypeStove, HVACTypePortableHeater, HVACTypeFixedHeater, HVACTypeFireplace].include? @heating_system_type
        @heating_efficiency_percent = XMLHelper.get_value(heating_system, "AnnualHeatingEfficiency[Units='Percent']/Value", :float)
      end
      @fraction_heat_load_served = XMLHelper.get_value(heating_system, 'FractionHeatLoadServed', :float)
      @electric_auxiliary_energy = XMLHelper.get_value(heating_system, 'ElectricAuxiliaryEnergy', :float)
      @shared_loop_watts = XMLHelper.get_value(heating_system, 'extension/SharedLoopWatts', :float)
      @shared_loop_motor_efficiency = XMLHelper.get_value(heating_system, 'extension/SharedLoopMotorEfficiency', :float)
      @fan_coil_watts = XMLHelper.get_value(heating_system, 'extension/FanCoilWatts', :float)
      @fan_watts_per_cfm = XMLHelper.get_value(heating_system, 'extension/FanPowerWattsPerCFM', :float)
      @fan_watts = XMLHelper.get_value(heating_system, 'extension/FanPowerWatts', :float)
      @airflow_defect_ratio = XMLHelper.get_value(heating_system, 'extension/AirflowDefectRatio', :float)
      @heating_airflow_cfm = XMLHelper.get_value(heating_system, 'extension/HeatingAirflowCFM', :float)
      @seed_id = XMLHelper.get_value(heating_system, 'extension/SeedId', :string)
    end
  end

  class CoolingSystems < BaseArrayElement
    def add(**kwargs)
      self << CoolingSystem.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem').each do |cooling_system|
        self << CoolingSystem.new(@hpxml_object, cooling_system)
      end
    end

    def total_fraction_cool_load_served
      map { |clg_sys| clg_sys.fraction_cool_load_served.to_f }.sum(0.0)
    end
  end

  class CoolingSystem < BaseElement
    ATTRS = [:id, :distribution_system_idref, :year_installed, :cooling_system_type,
             :cooling_system_fuel, :cooling_capacity, :compressor_type, :fraction_cool_load_served,
             :cooling_efficiency_seer, :cooling_efficiency_eer, :cooling_efficiency_ceer, :cooling_efficiency_kw_per_ton,
             :cooling_shr, :third_party_certification, :seed_id, :is_shared_system, :number_of_units_served,
             :shared_loop_watts, :shared_loop_motor_efficiency, :fan_coil_watts, :airflow_defect_ratio,
             :fan_watts_per_cfm, :charge_defect_ratio, :cooling_airflow_cfm, :location]
    attr_accessor(*ATTRS)

    def distribution_system
      return if @distribution_system_idref.nil?

      @hpxml_object.hvac_distributions.each do |hvac_distribution|
        next unless hvac_distribution.id == @distribution_system_idref

        return hvac_distribution
      end
      fail "Attached HVAC distribution system '#{@distribution_system_idref}' not found for HVAC system '#{@id}'."
    end

    def attached_heating_system
      return if distribution_system.nil?

      distribution_system.hvac_systems.each do |hvac_system|
        next if hvac_system.id == @id

        return hvac_system
      end
      return
    end

    def delete
      @hpxml_object.cooling_systems.delete(self)
      @hpxml_object.water_heating_systems.each do |water_heating_system|
        next unless water_heating_system.related_hvac_idref == @id

        water_heating_system.related_hvac_idref = nil
      end
    end

    def check_for_errors
      errors = []
      begin; distribution_system; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      hvac_plant = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'HVAC', 'HVACPlant'])
      cooling_system = XMLHelper.add_element(hvac_plant, 'CoolingSystem')
      sys_id = XMLHelper.add_element(cooling_system, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(cooling_system, 'UnitLocation', @location, :string) unless @location.nil?
      XMLHelper.add_element(cooling_system, 'YearInstalled', @year_installed, :integer) unless @year_installed.nil?
      XMLHelper.add_element(cooling_system, 'ThirdPartyCertification', @third_party_certification, :string) unless @third_party_certification.nil?
      if not @distribution_system_idref.nil?
        distribution_system = XMLHelper.add_element(cooling_system, 'DistributionSystem')
        XMLHelper.add_attribute(distribution_system, 'idref', @distribution_system_idref)
      end
      XMLHelper.add_element(cooling_system, 'IsSharedSystem', @is_shared_system, :boolean) unless @is_shared_system.nil?
      XMLHelper.add_element(cooling_system, 'NumberofUnitsServed', @number_of_units_served, :integer) unless @number_of_units_served.nil?
      XMLHelper.add_element(cooling_system, 'CoolingSystemType', @cooling_system_type, :string) unless @cooling_system_type.nil?
      XMLHelper.add_element(cooling_system, 'CoolingSystemFuel', @cooling_system_fuel, :string) unless @cooling_system_fuel.nil?
      XMLHelper.add_element(cooling_system, 'CoolingCapacity', @cooling_capacity, :float, @cooling_capacity_isdefaulted) unless @cooling_capacity.nil?
      XMLHelper.add_element(cooling_system, 'CompressorType', @compressor_type, :string, @compressor_type_isdefaulted) unless @compressor_type.nil?
      XMLHelper.add_element(cooling_system, 'FractionCoolLoadServed', @fraction_cool_load_served, :float, @fraction_cool_load_served_isdefaulted) unless @fraction_cool_load_served.nil?

      efficiency_units = nil
      efficiency_value = nil
      if [HVACTypeCentralAirConditioner, HVACTypeMiniSplitAirConditioner].include? @cooling_system_type
        efficiency_units = UnitsSEER
        efficiency_value = @cooling_efficiency_seer
        efficiency_value_isdefaulted = @cooling_efficiency_seer_isdefaulted
      elsif [HVACTypeRoomAirConditioner].include? @cooling_system_type
        if not @cooling_efficiency_eer.nil?
          efficiency_units = UnitsEER
          efficiency_value = @cooling_efficiency_eer
          efficiency_value_isdefaulted = @cooling_efficiency_eer_isdefaulted
        elsif not @cooling_efficiency_ceer.nil?
          efficiency_units = UnitsCEER
          efficiency_value = @cooling_efficiency_ceer
          efficiency_value_isdefaulted = @cooling_efficiency_ceer_isdefaulted
        end
      elsif [HVACTypeChiller].include? @cooling_system_type
        efficiency_units = UnitsKwPerTon
        efficiency_value = @cooling_efficiency_kw_per_ton
        efficiency_value_isdefaulted = @cooling_efficiency_kw_per_ton_isdefaulted
      end
      if not efficiency_value.nil?
        annual_efficiency = XMLHelper.add_element(cooling_system, 'AnnualCoolingEfficiency')
        XMLHelper.add_element(annual_efficiency, 'Units', efficiency_units, :string)
        XMLHelper.add_element(annual_efficiency, 'Value', efficiency_value, :float, efficiency_value_isdefaulted)
      end
      XMLHelper.add_element(cooling_system, 'SensibleHeatFraction', @cooling_shr, :float, @cooling_shr_isdefaulted) unless @cooling_shr.nil?
      XMLHelper.add_extension(cooling_system, 'AirflowDefectRatio', @airflow_defect_ratio, :float, @airflow_defect_ratio_isdefaulted) unless @airflow_defect_ratio.nil?
      XMLHelper.add_extension(cooling_system, 'ChargeDefectRatio', @charge_defect_ratio, :float, @charge_defect_ratio_isdefaulted) unless @charge_defect_ratio.nil?
      XMLHelper.add_extension(cooling_system, 'FanPowerWattsPerCFM', @fan_watts_per_cfm, :float, @fan_watts_per_cfm_isdefaulted) unless @fan_watts_per_cfm.nil?
      XMLHelper.add_extension(cooling_system, 'CoolingAirflowCFM', @cooling_airflow_cfm, :float, @cooling_airflow_cfm_isdefaulted) unless @cooling_airflow_cfm.nil?
      XMLHelper.add_extension(cooling_system, 'SharedLoopWatts', @shared_loop_watts, :float) unless @shared_loop_watts.nil?
      XMLHelper.add_extension(cooling_system, 'SharedLoopMotorEfficiency', @shared_loop_motor_efficiency, :float) unless @shared_loop_motor_efficiency.nil?
      XMLHelper.add_extension(cooling_system, 'FanCoilWatts', @fan_coil_watts, :float) unless @fan_coil_watts.nil?
      XMLHelper.add_extension(cooling_system, 'SeedId', @seed_id, :string) unless @seed_id.nil?
    end

    def from_oga(cooling_system)
      return if cooling_system.nil?

      @id = HPXML::get_id(cooling_system)
      @location = XMLHelper.get_value(cooling_system, 'UnitLocation', :string)
      @year_installed = XMLHelper.get_value(cooling_system, 'YearInstalled', :integer)
      @third_party_certification = XMLHelper.get_value(cooling_system, 'ThirdPartyCertification', :string)
      @distribution_system_idref = HPXML::get_idref(XMLHelper.get_element(cooling_system, 'DistributionSystem'))
      @is_shared_system = XMLHelper.get_value(cooling_system, 'IsSharedSystem', :boolean)
      @number_of_units_served = XMLHelper.get_value(cooling_system, 'NumberofUnitsServed', :integer)
      @cooling_system_type = XMLHelper.get_value(cooling_system, 'CoolingSystemType', :string)
      @cooling_system_fuel = XMLHelper.get_value(cooling_system, 'CoolingSystemFuel', :string)
      @cooling_capacity = XMLHelper.get_value(cooling_system, 'CoolingCapacity', :float)
      @compressor_type = XMLHelper.get_value(cooling_system, 'CompressorType', :string)
      @fraction_cool_load_served = XMLHelper.get_value(cooling_system, 'FractionCoolLoadServed', :float)
      if [HVACTypeCentralAirConditioner, HVACTypeMiniSplitAirConditioner].include? @cooling_system_type
        @cooling_efficiency_seer = XMLHelper.get_value(cooling_system, "AnnualCoolingEfficiency[Units='#{UnitsSEER}']/Value", :float)
      elsif [HVACTypeRoomAirConditioner].include? @cooling_system_type
        @cooling_efficiency_eer = XMLHelper.get_value(cooling_system, "AnnualCoolingEfficiency[Units='#{UnitsEER}']/Value", :float)
        @cooling_efficiency_ceer = XMLHelper.get_value(cooling_system, "AnnualCoolingEfficiency[Units='#{UnitsCEER}']/Value", :float)
      elsif [HVACTypeChiller].include? @cooling_system_type
        @cooling_efficiency_kw_per_ton = XMLHelper.get_value(cooling_system, "AnnualCoolingEfficiency[Units='#{UnitsKwPerTon}']/Value", :float)
      end
      @cooling_shr = XMLHelper.get_value(cooling_system, 'SensibleHeatFraction', :float)
      @airflow_defect_ratio = XMLHelper.get_value(cooling_system, 'extension/AirflowDefectRatio', :float)
      @charge_defect_ratio = XMLHelper.get_value(cooling_system, 'extension/ChargeDefectRatio', :float)
      @fan_watts_per_cfm = XMLHelper.get_value(cooling_system, 'extension/FanPowerWattsPerCFM', :float)
      @cooling_airflow_cfm = XMLHelper.get_value(cooling_system, 'extension/CoolingAirflowCFM', :float)
      @shared_loop_watts = XMLHelper.get_value(cooling_system, 'extension/SharedLoopWatts', :float)
      @shared_loop_motor_efficiency = XMLHelper.get_value(cooling_system, 'extension/SharedLoopMotorEfficiency', :float)
      @fan_coil_watts = XMLHelper.get_value(cooling_system, 'extension/FanCoilWatts', :float)
      @seed_id = XMLHelper.get_value(cooling_system, 'extension/SeedId', :string)
    end
  end

  class HeatPumps < BaseArrayElement
    def add(**kwargs)
      self << HeatPump.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump').each do |heat_pump|
        self << HeatPump.new(@hpxml_object, heat_pump)
      end
    end

    def total_fraction_heat_load_served
      map { |hp| hp.fraction_heat_load_served.to_f }.sum(0.0)
    end

    def total_fraction_cool_load_served
      map { |hp| hp.fraction_cool_load_served.to_f }.sum(0.0)
    end
  end

  class HeatPump < BaseElement
    ATTRS = [:id, :distribution_system_idref, :year_installed, :heat_pump_type, :heat_pump_fuel,
             :heating_capacity, :heating_capacity_17F, :cooling_capacity, :compressor_type,
             :cooling_shr, :backup_heating_fuel, :backup_heating_capacity,
             :backup_heating_efficiency_percent, :backup_heating_efficiency_afue,
             :backup_heating_switchover_temp, :fraction_heat_load_served, :fraction_cool_load_served,
             :cooling_efficiency_seer, :cooling_efficiency_eer, :heating_efficiency_hspf,
             :heating_efficiency_cop, :third_party_certification, :seed_id, :pump_watts_per_ton,
             :fan_watts_per_cfm, :is_shared_system, :number_of_units_served, :shared_loop_watts,
             :shared_loop_motor_efficiency, :airflow_defect_ratio, :charge_defect_ratio,
             :heating_airflow_cfm, :cooling_airflow_cfm, :location]
    attr_accessor(*ATTRS)

    def distribution_system
      return if @distribution_system_idref.nil?

      @hpxml_object.hvac_distributions.each do |hvac_distribution|
        next unless hvac_distribution.id == @distribution_system_idref

        return hvac_distribution
      end
      fail "Attached HVAC distribution system '#{@distribution_system_idref}' not found for HVAC system '#{@id}'."
    end

    def delete
      @hpxml_object.heat_pumps.delete(self)
      @hpxml_object.water_heating_systems.each do |water_heating_system|
        next unless water_heating_system.related_hvac_idref == @id

        water_heating_system.related_hvac_idref = nil
      end
    end

    def check_for_errors
      errors = []
      begin; distribution_system; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      hvac_plant = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'HVAC', 'HVACPlant'])
      heat_pump = XMLHelper.add_element(hvac_plant, 'HeatPump')
      sys_id = XMLHelper.add_element(heat_pump, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(heat_pump, 'UnitLocation', @location, :string) unless @location.nil?
      XMLHelper.add_element(heat_pump, 'YearInstalled', @year_installed, :integer) unless @year_installed.nil?
      XMLHelper.add_element(heat_pump, 'ThirdPartyCertification', @third_party_certification, :string) unless @third_party_certification.nil?
      if not @distribution_system_idref.nil?
        distribution_system = XMLHelper.add_element(heat_pump, 'DistributionSystem')
        XMLHelper.add_attribute(distribution_system, 'idref', @distribution_system_idref)
      end
      XMLHelper.add_element(heat_pump, 'IsSharedSystem', @is_shared_system, :boolean) unless @is_shared_system.nil?
      XMLHelper.add_element(heat_pump, 'NumberofUnitsServed', @number_of_units_served, :integer) unless @number_of_units_served.nil?
      XMLHelper.add_element(heat_pump, 'HeatPumpType', @heat_pump_type, :string) unless @heat_pump_type.nil?
      XMLHelper.add_element(heat_pump, 'HeatPumpFuel', @heat_pump_fuel, :string) unless @heat_pump_fuel.nil?
      XMLHelper.add_element(heat_pump, 'HeatingCapacity', @heating_capacity, :float, @heating_capacity_isdefaulted) unless @heating_capacity.nil?
      XMLHelper.add_element(heat_pump, 'HeatingCapacity17F', @heating_capacity_17F, :float) unless @heating_capacity_17F.nil?
      XMLHelper.add_element(heat_pump, 'CoolingCapacity', @cooling_capacity, :float, @cooling_capacity_isdefaulted) unless @cooling_capacity.nil?
      XMLHelper.add_element(heat_pump, 'CompressorType', @compressor_type, :string, @compressor_type_isdefaulted) unless @compressor_type.nil?
      XMLHelper.add_element(heat_pump, 'CoolingSensibleHeatFraction', @cooling_shr, :float, @cooling_shr_isdefaulted) unless @cooling_shr.nil?
      XMLHelper.add_element(heat_pump, 'BackupSystemFuel', @backup_heating_fuel, :string) unless @backup_heating_fuel.nil?
      efficiencies = { 'Percent' => @backup_heating_efficiency_percent,
                       UnitsAFUE => @backup_heating_efficiency_afue }
      efficiencies.each do |units, value|
        next if value.nil?

        backup_eff = XMLHelper.add_element(heat_pump, 'BackupAnnualHeatingEfficiency')
        XMLHelper.add_element(backup_eff, 'Units', units, :string)
        XMLHelper.add_element(backup_eff, 'Value', value, :float)
      end
      XMLHelper.add_element(heat_pump, 'BackupHeatingCapacity', @backup_heating_capacity, :float, @backup_heating_capacity_isdefaulted) unless @backup_heating_capacity.nil?
      XMLHelper.add_element(heat_pump, 'BackupHeatingSwitchoverTemperature', @backup_heating_switchover_temp, :float) unless @backup_heating_switchover_temp.nil?
      XMLHelper.add_element(heat_pump, 'FractionHeatLoadServed', @fraction_heat_load_served, :float, @fraction_heat_load_served_isdefaulted) unless @fraction_heat_load_served.nil?
      XMLHelper.add_element(heat_pump, 'FractionCoolLoadServed', @fraction_cool_load_served, :float, @fraction_cool_load_served_isdefaulted) unless @fraction_cool_load_served.nil?

      clg_efficiency_units = nil
      clg_efficiency_value = nil
      htg_efficiency_units = nil
      htg_efficiency_value = nil
      if [HVACTypeHeatPumpAirToAir, HVACTypeHeatPumpMiniSplit].include? @heat_pump_type
        clg_efficiency_units = UnitsSEER
        clg_efficiency_value = @cooling_efficiency_seer
        clg_efficiency_value_isdefaulted = @cooling_efficiency_seer_isdefaulted
        htg_efficiency_units = UnitsHSPF
        htg_efficiency_value = @heating_efficiency_hspf
        htg_efficiency_value_isdefaulted = @heating_efficiency_hspf_isdefaulted
      elsif [HVACTypeHeatPumpGroundToAir, HVACTypeHeatPumpWaterLoopToAir].include? @heat_pump_type
        clg_efficiency_units = UnitsEER
        clg_efficiency_value = @cooling_efficiency_eer
        clg_efficiency_value_isdefaulted = @cooling_efficiency_eer_isdefaulted
        htg_efficiency_units = UnitsCOP
        htg_efficiency_value = @heating_efficiency_cop
        htg_efficiency_value_isdefaulted = @heating_efficiency_cop_isdefaulted
      end
      if not clg_efficiency_value.nil?
        annual_efficiency = XMLHelper.add_element(heat_pump, 'AnnualCoolingEfficiency')
        XMLHelper.add_element(annual_efficiency, 'Units', clg_efficiency_units, :string)
        XMLHelper.add_element(annual_efficiency, 'Value', clg_efficiency_value, :float, clg_efficiency_value_isdefaulted)
      end
      if not htg_efficiency_value.nil?
        annual_efficiency = XMLHelper.add_element(heat_pump, 'AnnualHeatingEfficiency')
        XMLHelper.add_element(annual_efficiency, 'Units', htg_efficiency_units, :string)
        XMLHelper.add_element(annual_efficiency, 'Value', htg_efficiency_value, :float, htg_efficiency_value_isdefaulted)
      end
      XMLHelper.add_extension(heat_pump, 'AirflowDefectRatio', @airflow_defect_ratio, :float, @airflow_defect_ratio_isdefaulted) unless @airflow_defect_ratio.nil?
      XMLHelper.add_extension(heat_pump, 'ChargeDefectRatio', @charge_defect_ratio, :float, @charge_defect_ratio_isdefaulted) unless @charge_defect_ratio.nil?
      XMLHelper.add_extension(heat_pump, 'FanPowerWattsPerCFM', @fan_watts_per_cfm, :float, @fan_watts_per_cfm_isdefaulted) unless @fan_watts_per_cfm.nil?
      XMLHelper.add_extension(heat_pump, 'HeatingAirflowCFM', @heating_airflow_cfm, :float, @heating_airflow_cfm_isdefaulted) unless @heating_airflow_cfm.nil?
      XMLHelper.add_extension(heat_pump, 'CoolingAirflowCFM', @cooling_airflow_cfm, :float, @cooling_airflow_cfm_isdefaulted) unless @cooling_airflow_cfm.nil?
      XMLHelper.add_extension(heat_pump, 'PumpPowerWattsPerTon', @pump_watts_per_ton, :float, @pump_watts_per_ton_isdefaulted) unless @pump_watts_per_ton.nil?
      XMLHelper.add_extension(heat_pump, 'SharedLoopWatts', @shared_loop_watts, :float) unless @shared_loop_watts.nil?
      XMLHelper.add_extension(heat_pump, 'SharedLoopMotorEfficiency', @shared_loop_motor_efficiency, :float) unless @shared_loop_motor_efficiency.nil?
      XMLHelper.add_extension(heat_pump, 'SeedId', @seed_id, :string) unless @seed_id.nil?
    end

    def from_oga(heat_pump)
      return if heat_pump.nil?

      @id = HPXML::get_id(heat_pump)
      @location = XMLHelper.get_value(heat_pump, 'UnitLocation', :string)
      @year_installed = XMLHelper.get_value(heat_pump, 'YearInstalled', :integer)
      @third_party_certification = XMLHelper.get_value(heat_pump, 'ThirdPartyCertification', :string)
      @distribution_system_idref = HPXML::get_idref(XMLHelper.get_element(heat_pump, 'DistributionSystem'))
      @is_shared_system = XMLHelper.get_value(heat_pump, 'IsSharedSystem', :boolean)
      @number_of_units_served = XMLHelper.get_value(heat_pump, 'NumberofUnitsServed', :integer)
      @heat_pump_type = XMLHelper.get_value(heat_pump, 'HeatPumpType', :string)
      @heat_pump_fuel = XMLHelper.get_value(heat_pump, 'HeatPumpFuel', :string)
      @heating_capacity = XMLHelper.get_value(heat_pump, 'HeatingCapacity', :float)
      @heating_capacity_17F = XMLHelper.get_value(heat_pump, 'HeatingCapacity17F', :float)
      @cooling_capacity = XMLHelper.get_value(heat_pump, 'CoolingCapacity', :float)
      @compressor_type = XMLHelper.get_value(heat_pump, 'CompressorType', :string)
      @cooling_shr = XMLHelper.get_value(heat_pump, 'CoolingSensibleHeatFraction', :float)
      @backup_heating_fuel = XMLHelper.get_value(heat_pump, 'BackupSystemFuel', :string)
      @backup_heating_efficiency_percent = XMLHelper.get_value(heat_pump, "BackupAnnualHeatingEfficiency[Units='Percent']/Value", :float)
      @backup_heating_efficiency_afue = XMLHelper.get_value(heat_pump, "BackupAnnualHeatingEfficiency[Units='#{UnitsAFUE}']/Value", :float)
      @backup_heating_capacity = XMLHelper.get_value(heat_pump, 'BackupHeatingCapacity', :float)
      @backup_heating_switchover_temp = XMLHelper.get_value(heat_pump, 'BackupHeatingSwitchoverTemperature', :float)
      @fraction_heat_load_served = XMLHelper.get_value(heat_pump, 'FractionHeatLoadServed', :float)
      @fraction_cool_load_served = XMLHelper.get_value(heat_pump, 'FractionCoolLoadServed', :float)
      if [HVACTypeHeatPumpAirToAir, HVACTypeHeatPumpMiniSplit].include? @heat_pump_type
        @cooling_efficiency_seer = XMLHelper.get_value(heat_pump, "AnnualCoolingEfficiency[Units='#{UnitsSEER}']/Value", :float)
      elsif [HVACTypeHeatPumpGroundToAir, HVACTypeHeatPumpWaterLoopToAir].include? @heat_pump_type
        @cooling_efficiency_eer = XMLHelper.get_value(heat_pump, "AnnualCoolingEfficiency[Units='#{UnitsEER}']/Value", :float)
      end
      if [HVACTypeHeatPumpAirToAir, HVACTypeHeatPumpMiniSplit].include? @heat_pump_type
        @heating_efficiency_hspf = XMLHelper.get_value(heat_pump, "AnnualHeatingEfficiency[Units='#{UnitsHSPF}']/Value", :float)
      elsif [HVACTypeHeatPumpGroundToAir, HVACTypeHeatPumpWaterLoopToAir].include? @heat_pump_type
        @heating_efficiency_cop = XMLHelper.get_value(heat_pump, "AnnualHeatingEfficiency[Units='#{UnitsCOP}']/Value", :float)
      end
      @airflow_defect_ratio = XMLHelper.get_value(heat_pump, 'extension/AirflowDefectRatio', :float)
      @charge_defect_ratio = XMLHelper.get_value(heat_pump, 'extension/ChargeDefectRatio', :float)
      @fan_watts_per_cfm = XMLHelper.get_value(heat_pump, 'extension/FanPowerWattsPerCFM', :float)
      @heating_airflow_cfm = XMLHelper.get_value(heat_pump, 'extension/HeatingAirflowCFM', :float)
      @cooling_airflow_cfm = XMLHelper.get_value(heat_pump, 'extension/CoolingAirflowCFM', :float)
      @pump_watts_per_ton = XMLHelper.get_value(heat_pump, 'extension/PumpPowerWattsPerTon', :float)
      @shared_loop_watts = XMLHelper.get_value(heat_pump, 'extension/SharedLoopWatts', :float)
      @shared_loop_motor_efficiency = XMLHelper.get_value(heat_pump, 'extension/SharedLoopMotorEfficiency', :float)
      @seed_id = XMLHelper.get_value(heat_pump, 'extension/SeedId', :string)
    end
  end

  class HVACPlant < BaseElement
    HDL_ATTRS = { hdl_total: 'Total',
                  hdl_ducts: 'Ducts',
                  hdl_windows: 'Windows',
                  hdl_skylights: 'Skylights',
                  hdl_doors: 'Doors',
                  hdl_walls: 'Walls',
                  hdl_roofs: 'Roofs',
                  hdl_floors: 'Floors',
                  hdl_slabs: 'Slabs',
                  hdl_ceilings: 'Ceilings',
                  hdl_infilvent: 'InfilVent' }
    CDL_SENS_ATTRS = { cdl_sens_total: 'Total',
                       cdl_sens_ducts: 'Ducts',
                       cdl_sens_windows: 'Windows',
                       cdl_sens_skylights: 'Skylights',
                       cdl_sens_doors: 'Doors',
                       cdl_sens_walls: 'Walls',
                       cdl_sens_roofs: 'Roofs',
                       cdl_sens_floors: 'Floors',
                       cdl_sens_slabs: 'Slabs',
                       cdl_sens_ceilings: 'Ceilings',
                       cdl_sens_infilvent: 'InfilVent',
                       cdl_sens_intgains: 'InternalGains' }
    CDL_LAT_ATTRS = { cdl_lat_total: 'Total',
                      cdl_lat_ducts: 'Ducts',
                      cdl_lat_infilvent: 'InfilVent',
                      cdl_lat_intgains: 'InternalGains' }
    ATTRS = HDL_ATTRS.keys + CDL_SENS_ATTRS.keys + CDL_LAT_ATTRS.keys
    attr_accessor(*ATTRS)

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      hvac_plant = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'HVAC', 'HVACPlant'])
      if not @hdl_total.nil?
        dl_extension = XMLHelper.create_elements_as_needed(hvac_plant, ['extension', 'DesignLoads'])
        XMLHelper.add_attribute(dl_extension, 'dataSource', 'software')
        hdl = XMLHelper.add_element(dl_extension, 'Heating')
        HDL_ATTRS.each do |attr, element_name|
          XMLHelper.add_element(hdl, element_name, send(attr), :float)
        end
        cdl_sens = XMLHelper.add_element(dl_extension, 'CoolingSensible')
        CDL_SENS_ATTRS.each do |attr, element_name|
          XMLHelper.add_element(cdl_sens, element_name, send(attr), :float)
        end
        cdl_lat = XMLHelper.add_element(dl_extension, 'CoolingLatent')
        CDL_LAT_ATTRS.each do |attr, element_name|
          XMLHelper.add_element(cdl_lat, element_name, send(attr), :float)
        end
      end
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      hvac_plant = XMLHelper.get_element(hpxml, 'Building/BuildingDetails/Systems/HVAC/HVACPlant')
      return if hvac_plant.nil?

      HDL_ATTRS.each do |attr, element_name|
        send("#{attr}=", XMLHelper.get_value(hvac_plant, "extension/DesignLoads/Heating/#{element_name}", :float))
      end
      CDL_SENS_ATTRS.each do |attr, element_name|
        send("#{attr}=", XMLHelper.get_value(hvac_plant, "extension/DesignLoads/CoolingSensible/#{element_name}", :float))
      end
      CDL_LAT_ATTRS.each do |attr, element_name|
        send("#{attr}=", XMLHelper.get_value(hvac_plant, "extension/DesignLoads/CoolingLatent/#{element_name}", :float))
      end
    end
  end

  class HVACControls < BaseArrayElement
    def add(**kwargs)
      self << HVACControl.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Systems/HVAC/HVACControl').each do |hvac_control|
        self << HVACControl.new(@hpxml_object, hvac_control)
      end
    end
  end

  class HVACControl < BaseElement
    ATTRS = [:id, :control_type, :heating_setpoint_temp, :heating_setback_temp,
             :heating_setback_hours_per_week, :heating_setback_start_hour, :cooling_setpoint_temp,
             :cooling_setup_temp, :cooling_setup_hours_per_week, :cooling_setup_start_hour,
             :ceiling_fan_cooling_setpoint_temp_offset,
             :weekday_heating_setpoints, :weekend_heating_setpoints,
             :weekday_cooling_setpoints, :weekend_cooling_setpoints,
             :seasons_heating_begin_month, :seasons_heating_begin_day, :seasons_heating_end_month, :seasons_heating_end_day,
             :seasons_cooling_begin_month, :seasons_cooling_begin_day, :seasons_cooling_end_month, :seasons_cooling_end_day]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.hvac_controls.delete(self)
    end

    def check_for_errors
      errors = []

      errors += HPXML::check_dates('Heating Season', @seasons_heating_begin_month, @seasons_heating_begin_day, @seasons_heating_end_month, @seasons_heating_end_day)
      errors += HPXML::check_dates('Cooling Season', @seasons_cooling_begin_month, @seasons_cooling_begin_day, @seasons_cooling_end_month, @seasons_cooling_end_day)

      return errors
    end

    def to_oga(doc)
      return if nil?

      hvac = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'HVAC'])
      hvac_control = XMLHelper.add_element(hvac, 'HVACControl')
      sys_id = XMLHelper.add_element(hvac_control, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(hvac_control, 'ControlType', @control_type, :string) unless @control_type.nil?
      XMLHelper.add_element(hvac_control, 'SetpointTempHeatingSeason', @heating_setpoint_temp, :float) unless @heating_setpoint_temp.nil?
      XMLHelper.add_element(hvac_control, 'SetbackTempHeatingSeason', @heating_setback_temp, :float) unless @heating_setback_temp.nil?
      XMLHelper.add_element(hvac_control, 'TotalSetbackHoursperWeekHeating', @heating_setback_hours_per_week, :integer) unless @heating_setback_hours_per_week.nil?
      XMLHelper.add_element(hvac_control, 'SetupTempCoolingSeason', @cooling_setup_temp, :float) unless @cooling_setup_temp.nil?
      XMLHelper.add_element(hvac_control, 'SetpointTempCoolingSeason', @cooling_setpoint_temp, :float) unless @cooling_setpoint_temp.nil?
      XMLHelper.add_element(hvac_control, 'TotalSetupHoursperWeekCooling', @cooling_setup_hours_per_week, :integer) unless @cooling_setup_hours_per_week.nil?
      if (not @seasons_heating_begin_month.nil?) || (not @seasons_heating_begin_day.nil?) || (not @seasons_heating_end_month.nil?) || (not @seasons_heating_end_day.nil?)
        heating_season = XMLHelper.add_element(hvac_control, 'HeatingSeason')
        XMLHelper.add_element(heating_season, 'BeginMonth', @seasons_heating_begin_month, :integer, @seasons_heating_begin_month_isdefaulted) unless @seasons_heating_begin_month.nil?
        XMLHelper.add_element(heating_season, 'BeginDayOfMonth', @seasons_heating_begin_day, :integer, @seasons_heating_begin_day_isdefaulted) unless @seasons_heating_begin_day.nil?
        XMLHelper.add_element(heating_season, 'EndMonth', @seasons_heating_end_month, :integer, @seasons_heating_end_month_isdefaulted) unless @seasons_heating_end_month.nil?
        XMLHelper.add_element(heating_season, 'EndDayOfMonth', @seasons_heating_end_day, :integer, @seasons_heating_end_day_isdefaulted) unless @seasons_heating_end_day.nil?
      end
      if (not @seasons_cooling_begin_month.nil?) || (not @seasons_cooling_begin_day.nil?) || (not @seasons_cooling_end_month.nil?) || (not @seasons_cooling_end_day.nil?)
        cooling_season = XMLHelper.add_element(hvac_control, 'CoolingSeason')
        XMLHelper.add_element(cooling_season, 'BeginMonth', @seasons_cooling_begin_month, :integer, @seasons_cooling_begin_month_isdefaulted) unless @seasons_cooling_begin_month.nil?
        XMLHelper.add_element(cooling_season, 'BeginDayOfMonth', @seasons_cooling_begin_day, :integer, @seasons_cooling_begin_day_isdefaulted) unless @seasons_cooling_begin_day.nil?
        XMLHelper.add_element(cooling_season, 'EndMonth', @seasons_cooling_end_month, :integer, @seasons_cooling_end_month_isdefaulted) unless @seasons_cooling_end_month.nil?
        XMLHelper.add_element(cooling_season, 'EndDayOfMonth', @seasons_cooling_end_day, :integer, @seasons_cooling_end_day_isdefaulted) unless @seasons_cooling_end_day.nil?
      end
      XMLHelper.add_extension(hvac_control, 'SetbackStartHourHeating', @heating_setback_start_hour, :integer, @heating_setback_start_hour_isdefaulted) unless @heating_setback_start_hour.nil?
      XMLHelper.add_extension(hvac_control, 'SetupStartHourCooling', @cooling_setup_start_hour, :integer, @cooling_setup_start_hour_isdefaulted) unless @cooling_setup_start_hour.nil?
      XMLHelper.add_extension(hvac_control, 'CeilingFanSetpointTempCoolingSeasonOffset', @ceiling_fan_cooling_setpoint_temp_offset, :float) unless @ceiling_fan_cooling_setpoint_temp_offset.nil?
      XMLHelper.add_extension(hvac_control, 'WeekdaySetpointTempsHeatingSeason', @weekday_heating_setpoints, :string) unless @weekday_heating_setpoints.nil?
      XMLHelper.add_extension(hvac_control, 'WeekendSetpointTempsHeatingSeason', @weekend_heating_setpoints, :string) unless @weekend_heating_setpoints.nil?
      XMLHelper.add_extension(hvac_control, 'WeekdaySetpointTempsCoolingSeason', @weekday_cooling_setpoints, :string) unless @weekday_cooling_setpoints.nil?
      XMLHelper.add_extension(hvac_control, 'WeekendSetpointTempsCoolingSeason', @weekend_cooling_setpoints, :string) unless @weekend_cooling_setpoints.nil?
    end

    def from_oga(hvac_control)
      return if hvac_control.nil?

      @id = HPXML::get_id(hvac_control)
      @control_type = XMLHelper.get_value(hvac_control, 'ControlType', :string)
      @heating_setpoint_temp = XMLHelper.get_value(hvac_control, 'SetpointTempHeatingSeason', :float)
      @heating_setback_temp = XMLHelper.get_value(hvac_control, 'SetbackTempHeatingSeason', :float)
      @heating_setback_hours_per_week = XMLHelper.get_value(hvac_control, 'TotalSetbackHoursperWeekHeating', :integer)
      @cooling_setup_temp = XMLHelper.get_value(hvac_control, 'SetupTempCoolingSeason', :float)
      @cooling_setpoint_temp = XMLHelper.get_value(hvac_control, 'SetpointTempCoolingSeason', :float)
      @cooling_setup_hours_per_week = XMLHelper.get_value(hvac_control, 'TotalSetupHoursperWeekCooling', :integer)
      @seasons_heating_begin_month = XMLHelper.get_value(hvac_control, 'HeatingSeason/BeginMonth', :integer)
      @seasons_heating_begin_day = XMLHelper.get_value(hvac_control, 'HeatingSeason/BeginDayOfMonth', :integer)
      @seasons_heating_end_month = XMLHelper.get_value(hvac_control, 'HeatingSeason/EndMonth', :integer)
      @seasons_heating_end_day = XMLHelper.get_value(hvac_control, 'HeatingSeason/EndDayOfMonth', :integer)
      @seasons_cooling_begin_month = XMLHelper.get_value(hvac_control, 'CoolingSeason/BeginMonth', :integer)
      @seasons_cooling_begin_day = XMLHelper.get_value(hvac_control, 'CoolingSeason/BeginDayOfMonth', :integer)
      @seasons_cooling_end_month = XMLHelper.get_value(hvac_control, 'CoolingSeason/EndMonth', :integer)
      @seasons_cooling_end_day = XMLHelper.get_value(hvac_control, 'CoolingSeason/EndDayOfMonth', :integer)
      @heating_setback_start_hour = XMLHelper.get_value(hvac_control, 'extension/SetbackStartHourHeating', :integer)
      @cooling_setup_start_hour = XMLHelper.get_value(hvac_control, 'extension/SetupStartHourCooling', :integer)
      @ceiling_fan_cooling_setpoint_temp_offset = XMLHelper.get_value(hvac_control, 'extension/CeilingFanSetpointTempCoolingSeasonOffset', :float)
      @weekday_heating_setpoints = XMLHelper.get_value(hvac_control, 'extension/WeekdaySetpointTempsHeatingSeason', :string)
      @weekend_heating_setpoints = XMLHelper.get_value(hvac_control, 'extension/WeekendSetpointTempsHeatingSeason', :string)
      @weekday_cooling_setpoints = XMLHelper.get_value(hvac_control, 'extension/WeekdaySetpointTempsCoolingSeason', :string)
      @weekend_cooling_setpoints = XMLHelper.get_value(hvac_control, 'extension/WeekendSetpointTempsCoolingSeason', :string)
    end
  end

  class HVACDistributions < BaseArrayElement
    def add(**kwargs)
      self << HVACDistribution.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Systems/HVAC/HVACDistribution').each do |hvac_distribution|
        self << HVACDistribution.new(@hpxml_object, hvac_distribution)
      end
    end
  end

  class HVACDistribution < BaseElement
    def initialize(hpxml_object, *args)
      @duct_leakage_measurements = DuctLeakageMeasurements.new(hpxml_object)
      @ducts = Ducts.new(hpxml_object)
      super(hpxml_object, *args)
    end
    ATTRS = [:id, :distribution_system_type, :annual_heating_dse, :annual_cooling_dse,
             :duct_system_sealed, :duct_leakage_to_outside_testing_exemption, :conditioned_floor_area_served,
             :number_of_return_registers, :air_type, :hydronic_type]
    attr_accessor(*ATTRS)
    attr_reader(:duct_leakage_measurements, :ducts)

    def hvac_systems
      list = []
      @hpxml_object.hvac_systems.each do |hvac_system|
        next if hvac_system.distribution_system_idref.nil?
        next unless hvac_system.distribution_system_idref == @id

        list << hvac_system
      end

      if list.size == 0
        fail "Distribution system '#{@id}' found but no HVAC system attached to it."
      end

      num_htg = 0
      num_clg = 0
      list.each do |obj|
        if obj.respond_to? :fraction_heat_load_served
          num_htg += 1 if obj.fraction_heat_load_served.to_f > 0
        end
        if obj.respond_to? :fraction_cool_load_served
          num_clg += 1 if obj.fraction_cool_load_served.to_f > 0
        end
      end

      if num_clg > 1
        fail "Multiple cooling systems found attached to distribution system '#{@id}'."
      end
      if num_htg > 1
        fail "Multiple heating systems found attached to distribution system '#{@id}'."
      end

      return list
    end

    def total_unconditioned_duct_areas
      areas = { HPXML::DuctTypeSupply => 0,
                HPXML::DuctTypeReturn => 0 }
      @ducts.each do |duct|
        next if [HPXML::LocationLivingSpace, HPXML::LocationBasementConditioned].include? duct.duct_location
        next if duct.duct_type.nil?

        areas[duct.duct_type] += duct.duct_surface_area
      end
      return areas
    end

    def delete
      @hpxml_object.hvac_distributions.delete(self)
      @hpxml_object.hvac_systems.each do |hvac_system|
        next if hvac_system.distribution_system_idref.nil?
        next unless hvac_system.distribution_system_idref == @id

        hvac_system.distribution_system_idref = nil
      end
      @hpxml_object.ventilation_fans.each do |ventilation_fan|
        next unless ventilation_fan.distribution_system_idref == @id

        ventilation_fan.distribution_system_idref = nil
      end
    end

    def check_for_errors
      errors = []
      begin; hvac_systems; rescue StandardError => e; errors << e.message; end
      errors += @duct_leakage_measurements.check_for_errors
      errors += @ducts.check_for_errors
      return errors
    end

    def to_oga(doc)
      return if nil?

      hvac = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'HVAC'])
      hvac_distribution = XMLHelper.add_element(hvac, 'HVACDistribution')
      sys_id = XMLHelper.add_element(hvac_distribution, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      distribution_system_type_el = XMLHelper.add_element(hvac_distribution, 'DistributionSystemType')
      if [HVACDistributionTypeAir, HVACDistributionTypeHydronic].include? @distribution_system_type
        XMLHelper.add_element(distribution_system_type_el, @distribution_system_type)
        XMLHelper.add_element(hvac_distribution, 'ConditionedFloorAreaServed', @conditioned_floor_area_served, :float) unless @conditioned_floor_area_served.nil?
      elsif [HVACDistributionTypeDSE].include? @distribution_system_type
        XMLHelper.add_element(distribution_system_type_el, 'Other', @distribution_system_type, :string)
        XMLHelper.add_element(hvac_distribution, 'AnnualHeatingDistributionSystemEfficiency', @annual_heating_dse, :float) unless @annual_heating_dse.nil?
        XMLHelper.add_element(hvac_distribution, 'AnnualCoolingDistributionSystemEfficiency', @annual_cooling_dse, :float) unless @annual_cooling_dse.nil?
      else
        fail "Unexpected distribution_system_type '#{@distribution_system_type}'."
      end

      if [HPXML::HVACDistributionTypeHydronic].include? @distribution_system_type
        distribution = XMLHelper.get_element(hvac_distribution, 'DistributionSystemType/HydronicDistribution')
        XMLHelper.add_element(distribution, 'HydronicDistributionType', @hydronic_type, :string) unless @hydronic_type.nil?
      end
      if [HPXML::HVACDistributionTypeAir].include? @distribution_system_type
        distribution = XMLHelper.get_element(hvac_distribution, 'DistributionSystemType/AirDistribution')
        XMLHelper.add_element(distribution, 'AirDistributionType', @air_type, :string) unless @air_type.nil?
        @duct_leakage_measurements.to_oga(distribution)
        @ducts.to_oga(distribution)
        XMLHelper.add_element(distribution, 'NumberofReturnRegisters', @number_of_return_registers, :integer, @number_of_return_registers_isdefaulted) unless @number_of_return_registers.nil?
        XMLHelper.add_extension(distribution, 'DuctLeakageToOutsideTestingExemption', @duct_leakage_to_outside_testing_exemption, :boolean) unless @duct_leakage_to_outside_testing_exemption.nil?
      end

      if not @duct_system_sealed.nil?
        dist_impr_el = XMLHelper.add_element(hvac_distribution, 'HVACDistributionImprovement')
        XMLHelper.add_element(dist_impr_el, 'DuctSystemSealed', @duct_system_sealed, :boolean)
      end
    end

    def from_oga(hvac_distribution)
      return if hvac_distribution.nil?

      @id = HPXML::get_id(hvac_distribution)
      @distribution_system_type = XMLHelper.get_child_name(hvac_distribution, 'DistributionSystemType')
      if @distribution_system_type == 'Other'
        @distribution_system_type = XMLHelper.get_value(XMLHelper.get_element(hvac_distribution, 'DistributionSystemType'), 'Other', :string)
      end
      @annual_heating_dse = XMLHelper.get_value(hvac_distribution, 'AnnualHeatingDistributionSystemEfficiency', :float)
      @annual_cooling_dse = XMLHelper.get_value(hvac_distribution, 'AnnualCoolingDistributionSystemEfficiency', :float)
      @duct_system_sealed = XMLHelper.get_value(hvac_distribution, 'HVACDistributionImprovement/DuctSystemSealed', :boolean)
      @conditioned_floor_area_served = XMLHelper.get_value(hvac_distribution, 'ConditionedFloorAreaServed', :float)

      air_distribution = XMLHelper.get_element(hvac_distribution, 'DistributionSystemType/AirDistribution')
      hydronic_distribution = XMLHelper.get_element(hvac_distribution, 'DistributionSystemType/HydronicDistribution')

      if not hydronic_distribution.nil?
        @hydronic_type = XMLHelper.get_value(hydronic_distribution, 'HydronicDistributionType', :string)
      end
      if not air_distribution.nil?
        @air_type = XMLHelper.get_value(air_distribution, 'AirDistributionType', :string)
        @number_of_return_registers = XMLHelper.get_value(air_distribution, 'NumberofReturnRegisters', :integer)
        @duct_leakage_to_outside_testing_exemption = XMLHelper.get_value(air_distribution, 'extension/DuctLeakageToOutsideTestingExemption', :boolean)
        @duct_leakage_measurements.from_oga(air_distribution)
        @ducts.from_oga(air_distribution)
      end
    end
  end

  class DuctLeakageMeasurements < BaseArrayElement
    def add(**kwargs)
      self << DuctLeakageMeasurement.new(@hpxml_object, **kwargs)
    end

    def from_oga(hvac_distribution)
      return if hvac_distribution.nil?

      XMLHelper.get_elements(hvac_distribution, 'DuctLeakageMeasurement').each do |duct_leakage_measurement|
        self << DuctLeakageMeasurement.new(@hpxml_object, duct_leakage_measurement)
      end
    end
  end

  class DuctLeakageMeasurement < BaseElement
    ATTRS = [:duct_type, :duct_leakage_test_method, :duct_leakage_units, :duct_leakage_value,
             :duct_leakage_total_or_to_outside]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.hvac_distributions.each do |hvac_distribution|
        next unless hvac_distribution.duct_leakage_measurements.include? self

        hvac_distribution.duct_leakage_measurements.delete(self)
      end
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(air_distribution)
      duct_leakage_measurement_el = XMLHelper.add_element(air_distribution, 'DuctLeakageMeasurement')
      XMLHelper.add_element(duct_leakage_measurement_el, 'DuctType', @duct_type, :string) unless @duct_type.nil?
      XMLHelper.add_element(duct_leakage_measurement_el, 'DuctLeakageTestMethod', @duct_leakage_test_method, :string) unless @duct_leakage_test_method.nil?
      if not @duct_leakage_value.nil?
        duct_leakage_el = XMLHelper.add_element(duct_leakage_measurement_el, 'DuctLeakage')
        XMLHelper.add_element(duct_leakage_el, 'Units', @duct_leakage_units, :string) unless @duct_leakage_units.nil?
        XMLHelper.add_element(duct_leakage_el, 'Value', @duct_leakage_value, :float)
        XMLHelper.add_element(duct_leakage_el, 'TotalOrToOutside', @duct_leakage_total_or_to_outside, :string) unless @duct_leakage_total_or_to_outside.nil?
      end
    end

    def from_oga(duct_leakage_measurement)
      return if duct_leakage_measurement.nil?

      @duct_type = XMLHelper.get_value(duct_leakage_measurement, 'DuctType', :string)
      @duct_leakage_test_method = XMLHelper.get_value(duct_leakage_measurement, 'DuctLeakageTestMethod', :string)
      @duct_leakage_units = XMLHelper.get_value(duct_leakage_measurement, 'DuctLeakage/Units', :string)
      @duct_leakage_value = XMLHelper.get_value(duct_leakage_measurement, 'DuctLeakage/Value', :float)
      @duct_leakage_total_or_to_outside = XMLHelper.get_value(duct_leakage_measurement, 'DuctLeakage/TotalOrToOutside', :string)
    end
  end

  class Ducts < BaseArrayElement
    def add(**kwargs)
      self << Duct.new(@hpxml_object, **kwargs)
    end

    def from_oga(hvac_distribution)
      return if hvac_distribution.nil?

      XMLHelper.get_elements(hvac_distribution, 'Ducts').each do |duct|
        self << Duct.new(@hpxml_object, duct)
      end
    end
  end

  class Duct < BaseElement
    ATTRS = [:duct_type, :duct_insulation_r_value, :duct_insulation_material, :duct_location,
             :duct_fraction_area, :duct_surface_area]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.hvac_distributions.each do |hvac_distribution|
        next unless hvac_distribution.ducts.include? self

        hvac_distribution.ducts.delete(self)
      end
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(air_distribution)
      ducts_el = XMLHelper.add_element(air_distribution, 'Ducts')
      XMLHelper.add_element(ducts_el, 'DuctType', @duct_type, :string) unless @duct_type.nil?
      if not @duct_insulation_material.nil?
        ins_material_el = XMLHelper.add_element(ducts_el, 'DuctInsulationMaterial')
        XMLHelper.add_element(ins_material_el, @duct_insulation_material)
      end
      XMLHelper.add_element(ducts_el, 'DuctInsulationRValue', @duct_insulation_r_value, :float) unless @duct_insulation_r_value.nil?
      XMLHelper.add_element(ducts_el, 'DuctLocation', @duct_location, :string, @duct_location_isdefaulted) unless @duct_location.nil?
      XMLHelper.add_element(ducts_el, 'FractionDuctArea', @duct_fraction_area, :float, @duct_fraction_area_isdefaulted) unless @duct_fraction_area.nil?
      XMLHelper.add_element(ducts_el, 'DuctSurfaceArea', @duct_surface_area, :float, @duct_surface_area_isdefaulted) unless @duct_surface_area.nil?
    end

    def from_oga(duct)
      return if duct.nil?

      @duct_type = XMLHelper.get_value(duct, 'DuctType', :string)
      @duct_insulation_material = XMLHelper.get_child_name(duct, 'DuctInsulationMaterial')
      @duct_insulation_r_value = XMLHelper.get_value(duct, 'DuctInsulationRValue', :float)
      @duct_location = XMLHelper.get_value(duct, 'DuctLocation', :string)
      @duct_fraction_area = XMLHelper.get_value(duct, 'FractionDuctArea', :float)
      @duct_surface_area = XMLHelper.get_value(duct, 'DuctSurfaceArea', :float)
    end
  end

  class VentilationFans < BaseArrayElement
    def add(**kwargs)
      self << VentilationFan.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan').each do |ventilation_fan|
        self << VentilationFan.new(@hpxml_object, ventilation_fan)
      end
    end
  end

  class VentilationFan < BaseElement
    ATTRS = [:id, :fan_type, :rated_flow_rate, :tested_flow_rate, :hours_in_operation, :flow_rate_not_tested,
             :used_for_whole_building_ventilation, :used_for_seasonal_cooling_load_reduction,
             :used_for_local_ventilation, :total_recovery_efficiency, :total_recovery_efficiency_adjusted,
             :sensible_recovery_efficiency, :sensible_recovery_efficiency_adjusted,
             :fan_power, :fan_power_defaulted, :quantity, :fan_location, :distribution_system_idref, :start_hour,
             :is_shared_system, :in_unit_flow_rate, :fraction_recirculation,
             :preheating_fuel, :preheating_efficiency_cop, :preheating_fraction_load_served, :precooling_fuel,
             :precooling_efficiency_cop, :precooling_fraction_load_served]
    attr_accessor(*ATTRS)

    def distribution_system
      return if @distribution_system_idref.nil?
      return unless @fan_type == MechVentTypeCFIS

      @hpxml_object.hvac_distributions.each do |hvac_distribution|
        next unless hvac_distribution.id == @distribution_system_idref

        if hvac_distribution.distribution_system_type == HVACDistributionTypeHydronic
          fail "Attached HVAC distribution system '#{@distribution_system_idref}' cannot be hydronic for ventilation fan '#{@id}'."
        end

        return hvac_distribution
      end
      fail "Attached HVAC distribution system '#{@distribution_system_idref}' not found for ventilation fan '#{@id}'."
    end

    def total_unit_flow_rate
      if not @is_shared_system
        if not @tested_flow_rate.nil?
          return @tested_flow_rate
        else
          return @rated_flow_rate
        end
      else
        return @in_unit_flow_rate
      end
    end

    def oa_unit_flow_rate
      return if total_unit_flow_rate.nil?
      if not @is_shared_system
        return total_unit_flow_rate
      else
        if @fan_type == HPXML::MechVentTypeExhaust && @fraction_recirculation > 0.0
          fail "Exhaust fan '#{@id}' must have the fraction recirculation set to zero."
        else
          return total_unit_flow_rate * (1 - @fraction_recirculation)
        end
      end
    end

    def average_oa_unit_flow_rate
      # Daily-average outdoor air (cfm) associated with the unit
      return if oa_unit_flow_rate.nil?
      return if @hours_in_operation.nil?

      return oa_unit_flow_rate * (@hours_in_operation / 24.0)
    end

    def average_total_unit_flow_rate
      # Daily-average total air (cfm) associated with the unit
      return if total_unit_flow_rate.nil?
      return if @hours_in_operation.nil?

      return total_unit_flow_rate * (@hours_in_operation / 24.0)
    end

    def unit_flow_rate_ratio
      return 1.0 unless @is_shared_system
      return if @in_unit_flow_rate.nil?

      if not @tested_flow_rate.nil?
        ratio = @in_unit_flow_rate / @tested_flow_rate
      elsif not @rated_flow_rate.nil?
        ratio = @in_unit_flow_rate / @rated_flow_rate
      end
      return if ratio.nil?

      return ratio
    end

    def unit_fan_power
      return if @fan_power.nil?

      if @is_shared_system
        return if unit_flow_rate_ratio.nil?

        return @fan_power * unit_flow_rate_ratio
      else
        return @fan_power
      end
    end

    def average_unit_fan_power
      return if unit_fan_power.nil?
      return if @hours_in_operation.nil?

      return unit_fan_power * (@hours_in_operation / 24.0)
    end

    def includes_supply_air?
      if [MechVentTypeSupply, MechVentTypeCFIS, MechVentTypeBalanced, MechVentTypeERV, MechVentTypeHRV].include? @fan_type
        return true
      end

      return false
    end

    def includes_exhaust_air?
      if [MechVentTypeExhaust, MechVentTypeBalanced, MechVentTypeERV, MechVentTypeHRV].include? @fan_type
        return true
      end

      return false
    end

    def is_balanced?
      if includes_supply_air? && includes_exhaust_air?
        return true
      end

      return false
    end

    def delete
      @hpxml_object.ventilation_fans.delete(self)
    end

    def check_for_errors
      errors = []
      begin; distribution_system; rescue StandardError => e; errors << e.message; end
      begin; oa_unit_flow_rate; rescue StandardError => e; errors << e.message; end
      begin; unit_flow_rate_ratio; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      ventilation_fans = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'MechanicalVentilation', 'VentilationFans'])
      ventilation_fan = XMLHelper.add_element(ventilation_fans, 'VentilationFan')
      sys_id = XMLHelper.add_element(ventilation_fan, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(ventilation_fan, 'Quantity', @quantity, :integer, @quantity_isdefaulted) unless @quantity.nil?
      XMLHelper.add_element(ventilation_fan, 'FanType', @fan_type, :string) unless @fan_type.nil?
      XMLHelper.add_element(ventilation_fan, 'RatedFlowRate', @rated_flow_rate, :float, @rated_flow_rate_isdefaulted) unless @rated_flow_rate.nil?
      XMLHelper.add_element(ventilation_fan, 'TestedFlowRate', @tested_flow_rate, :float) unless @tested_flow_rate.nil?
      XMLHelper.add_element(ventilation_fan, 'HoursInOperation', @hours_in_operation, :float, @hours_in_operation_isdefaulted) unless @hours_in_operation.nil?
      XMLHelper.add_element(ventilation_fan, 'FanLocation', @fan_location, :string) unless @fan_location.nil?
      XMLHelper.add_element(ventilation_fan, 'UsedForLocalVentilation', @used_for_local_ventilation, :boolean) unless @used_for_local_ventilation.nil?
      XMLHelper.add_element(ventilation_fan, 'UsedForWholeBuildingVentilation', @used_for_whole_building_ventilation, :boolean) unless @used_for_whole_building_ventilation.nil?
      XMLHelper.add_element(ventilation_fan, 'UsedForSeasonalCoolingLoadReduction', @used_for_seasonal_cooling_load_reduction, :boolean) unless @used_for_seasonal_cooling_load_reduction.nil?
      XMLHelper.add_element(ventilation_fan, 'IsSharedSystem', @is_shared_system, :boolean, @is_shared_system_isdefaulted) unless @is_shared_system.nil?
      XMLHelper.add_element(ventilation_fan, 'FractionRecirculation', @fraction_recirculation, :float) unless @fraction_recirculation.nil?
      XMLHelper.add_element(ventilation_fan, 'TotalRecoveryEfficiency', @total_recovery_efficiency, :float) unless @total_recovery_efficiency.nil?
      XMLHelper.add_element(ventilation_fan, 'SensibleRecoveryEfficiency', @sensible_recovery_efficiency, :float) unless @sensible_recovery_efficiency.nil?
      XMLHelper.add_element(ventilation_fan, 'AdjustedTotalRecoveryEfficiency', @total_recovery_efficiency_adjusted, :float) unless @total_recovery_efficiency_adjusted.nil?
      XMLHelper.add_element(ventilation_fan, 'AdjustedSensibleRecoveryEfficiency', @sensible_recovery_efficiency_adjusted, :float) unless @sensible_recovery_efficiency_adjusted.nil?
      XMLHelper.add_element(ventilation_fan, 'FanPower', @fan_power, :float, @fan_power_isdefaulted) unless @fan_power.nil?
      if not @distribution_system_idref.nil?
        attached_to_hvac_distribution_system = XMLHelper.add_element(ventilation_fan, 'AttachedToHVACDistributionSystem')
        XMLHelper.add_attribute(attached_to_hvac_distribution_system, 'idref', @distribution_system_idref)
      end
      XMLHelper.add_extension(ventilation_fan, 'StartHour', @start_hour, :integer, @start_hour_isdefaulted) unless @start_hour.nil?
      XMLHelper.add_extension(ventilation_fan, 'InUnitFlowRate', @in_unit_flow_rate, :float) unless @in_unit_flow_rate.nil?
      if (not @preheating_fuel.nil?) && (not @preheating_efficiency_cop.nil?)
        precond_htg = XMLHelper.create_elements_as_needed(ventilation_fan, ['extension', 'PreHeating'])
        XMLHelper.add_element(precond_htg, 'Fuel', @preheating_fuel, :string) unless @preheating_fuel.nil?
        eff = XMLHelper.add_element(precond_htg, 'AnnualHeatingEfficiency') unless @preheating_efficiency_cop.nil?
        XMLHelper.add_element(eff, 'Value', @preheating_efficiency_cop, :float) unless eff.nil?
        XMLHelper.add_element(eff, 'Units', UnitsCOP, :string) unless eff.nil?
        XMLHelper.add_element(precond_htg, 'FractionVentilationHeatLoadServed', @preheating_fraction_load_served, :float) unless @preheating_fraction_load_served.nil?
      end
      if (not @precooling_fuel.nil?) && (not @precooling_efficiency_cop.nil?)
        precond_clg = XMLHelper.create_elements_as_needed(ventilation_fan, ['extension', 'PreCooling'])
        XMLHelper.add_element(precond_clg, 'Fuel', @precooling_fuel, :string) unless @precooling_fuel.nil?
        eff = XMLHelper.add_element(precond_clg, 'AnnualCoolingEfficiency') unless @precooling_efficiency_cop.nil?
        XMLHelper.add_element(eff, 'Value', @precooling_efficiency_cop, :float) unless eff.nil?
        XMLHelper.add_element(eff, 'Units', UnitsCOP, :string) unless eff.nil?
        XMLHelper.add_element(precond_clg, 'FractionVentilationCoolLoadServed', @precooling_fraction_load_served, :float) unless @precooling_fraction_load_served.nil?
      end
      XMLHelper.add_extension(ventilation_fan, 'FlowRateNotTested', @flow_rate_not_tested, :boolean) unless @flow_rate_not_tested.nil?
      XMLHelper.add_extension(ventilation_fan, 'FanPowerDefaulted', @fan_power_defaulted, :boolean) unless @fan_power_defaulted.nil?
    end

    def from_oga(ventilation_fan)
      return if ventilation_fan.nil?

      @id = HPXML::get_id(ventilation_fan)
      @quantity = XMLHelper.get_value(ventilation_fan, 'Quantity', :integer)
      @fan_type = XMLHelper.get_value(ventilation_fan, 'FanType', :string)
      @rated_flow_rate = XMLHelper.get_value(ventilation_fan, 'RatedFlowRate', :float)
      @tested_flow_rate = XMLHelper.get_value(ventilation_fan, 'TestedFlowRate', :float)
      @hours_in_operation = XMLHelper.get_value(ventilation_fan, 'HoursInOperation', :float)
      @fan_location = XMLHelper.get_value(ventilation_fan, 'FanLocation', :string)
      @used_for_local_ventilation = XMLHelper.get_value(ventilation_fan, 'UsedForLocalVentilation', :boolean)
      @used_for_whole_building_ventilation = XMLHelper.get_value(ventilation_fan, 'UsedForWholeBuildingVentilation', :boolean)
      @used_for_seasonal_cooling_load_reduction = XMLHelper.get_value(ventilation_fan, 'UsedForSeasonalCoolingLoadReduction', :boolean)
      @is_shared_system = XMLHelper.get_value(ventilation_fan, 'IsSharedSystem', :boolean)
      @fraction_recirculation = XMLHelper.get_value(ventilation_fan, 'FractionRecirculation', :float)
      @total_recovery_efficiency = XMLHelper.get_value(ventilation_fan, 'TotalRecoveryEfficiency', :float)
      @sensible_recovery_efficiency = XMLHelper.get_value(ventilation_fan, 'SensibleRecoveryEfficiency', :float)
      @total_recovery_efficiency_adjusted = XMLHelper.get_value(ventilation_fan, 'AdjustedTotalRecoveryEfficiency', :float)
      @sensible_recovery_efficiency_adjusted = XMLHelper.get_value(ventilation_fan, 'AdjustedSensibleRecoveryEfficiency', :float)
      @fan_power = XMLHelper.get_value(ventilation_fan, 'FanPower', :float)
      @distribution_system_idref = HPXML::get_idref(XMLHelper.get_element(ventilation_fan, 'AttachedToHVACDistributionSystem'))
      @start_hour = XMLHelper.get_value(ventilation_fan, 'extension/StartHour', :integer)
      @in_unit_flow_rate = XMLHelper.get_value(ventilation_fan, 'extension/InUnitFlowRate', :float)
      @preheating_fuel = XMLHelper.get_value(ventilation_fan, 'extension/PreHeating/Fuel', :string)
      @preheating_efficiency_cop = XMLHelper.get_value(ventilation_fan, "extension/PreHeating/AnnualHeatingEfficiency[Units='#{UnitsCOP}']/Value", :float)
      @preheating_fraction_load_served = XMLHelper.get_value(ventilation_fan, 'extension/PreHeating/FractionVentilationHeatLoadServed', :float)
      @precooling_fuel = XMLHelper.get_value(ventilation_fan, 'extension/PreCooling/Fuel', :string)
      @precooling_efficiency_cop = XMLHelper.get_value(ventilation_fan, "extension/PreCooling/AnnualCoolingEfficiency[Units='#{UnitsCOP}']/Value", :float)
      @precooling_fraction_load_served = XMLHelper.get_value(ventilation_fan, 'extension/PreCooling/FractionVentilationCoolLoadServed', :float)
      @flow_rate_not_tested = XMLHelper.get_value(ventilation_fan, 'extension/FlowRateNotTested', :boolean)
      @fan_power_defaulted = XMLHelper.get_value(ventilation_fan, 'extension/FanPowerDefaulted', :boolean)
    end
  end

  class WaterHeatingSystems < BaseArrayElement
    def add(**kwargs)
      self << WaterHeatingSystem.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem').each do |water_heating_system|
        self << WaterHeatingSystem.new(@hpxml_object, water_heating_system)
      end
    end
  end

  class WaterHeatingSystem < BaseElement
    ATTRS = [:id, :year_installed, :fuel_type, :water_heater_type, :location, :performance_adjustment,
             :tank_volume, :fraction_dhw_load_served, :heating_capacity, :energy_factor, :usage_bin,
             :uniform_energy_factor, :first_hour_rating, :recovery_efficiency, :uses_desuperheater, :jacket_r_value,
             :related_hvac_idref, :third_party_certification, :standby_loss, :temperature, :is_shared_system,
             :number_of_units_served]
    attr_accessor(*ATTRS)

    def related_hvac_system
      return if @related_hvac_idref.nil?

      @hpxml_object.hvac_systems.each do |hvac_system|
        next unless hvac_system.id == @related_hvac_idref

        return hvac_system
      end
      fail "RelatedHVACSystem '#{@related_hvac_idref}' not found for water heating system '#{@id}'."
    end

    def delete
      @hpxml_object.water_heating_systems.delete(self)
      @hpxml_object.solar_thermal_systems.each do |solar_thermal_system|
        next unless solar_thermal_system.water_heating_system_idref == @id

        solar_thermal_system.water_heating_system_idref = nil
      end
    end

    def check_for_errors
      errors = []
      begin; related_hvac_system; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      water_heating = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'WaterHeating'])
      water_heating_system = XMLHelper.add_element(water_heating, 'WaterHeatingSystem')
      sys_id = XMLHelper.add_element(water_heating_system, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(water_heating_system, 'FuelType', @fuel_type, :string) unless @fuel_type.nil?
      XMLHelper.add_element(water_heating_system, 'WaterHeaterType', @water_heater_type, :string) unless @water_heater_type.nil?
      XMLHelper.add_element(water_heating_system, 'Location', @location, :string, @location_isdefaulted) unless @location.nil?
      XMLHelper.add_element(water_heating_system, 'YearInstalled', @year_installed, :integer) unless @year_installed.nil?
      XMLHelper.add_element(water_heating_system, 'IsSharedSystem', @is_shared_system, :boolean, @is_shared_system_isdefaulted) unless @is_shared_system.nil?
      XMLHelper.add_element(water_heating_system, 'NumberofUnitsServed', @number_of_units_served, :integer) unless @number_of_units_served.nil?
      XMLHelper.add_element(water_heating_system, 'PerformanceAdjustment', @performance_adjustment, :float, @performance_adjustment_isdefaulted) unless @performance_adjustment.nil?
      XMLHelper.add_element(water_heating_system, 'ThirdPartyCertification', @third_party_certification, :string) unless @third_party_certification.nil?
      XMLHelper.add_element(water_heating_system, 'TankVolume', @tank_volume, :float, @tank_volume_isdefaulted) unless @tank_volume.nil?
      XMLHelper.add_element(water_heating_system, 'FractionDHWLoadServed', @fraction_dhw_load_served, :float) unless @fraction_dhw_load_served.nil?
      XMLHelper.add_element(water_heating_system, 'HeatingCapacity', @heating_capacity, :float, @heating_capacity_isdefaulted) unless @heating_capacity.nil?
      XMLHelper.add_element(water_heating_system, 'EnergyFactor', @energy_factor, :float, @energy_factor_isdefaulted) unless @energy_factor.nil?
      XMLHelper.add_element(water_heating_system, 'UniformEnergyFactor', @uniform_energy_factor, :float) unless @uniform_energy_factor.nil?
      XMLHelper.add_element(water_heating_system, 'FirstHourRating', @first_hour_rating, :float) unless @first_hour_rating.nil?
      XMLHelper.add_element(water_heating_system, 'UsageBin', @usage_bin, :string, @usage_bin_isdefaulted) unless @usage_bin.nil?
      XMLHelper.add_element(water_heating_system, 'RecoveryEfficiency', @recovery_efficiency, :float, @recovery_efficiency_isdefaulted) unless @recovery_efficiency.nil?
      if not @jacket_r_value.nil?
        water_heater_insulation = XMLHelper.add_element(water_heating_system, 'WaterHeaterInsulation')
        jacket = XMLHelper.add_element(water_heater_insulation, 'Jacket')
        XMLHelper.add_element(jacket, 'JacketRValue', @jacket_r_value, :float)
      end
      XMLHelper.add_element(water_heating_system, 'StandbyLoss', @standby_loss, :float, @standby_loss_isdefaulted) unless @standby_loss.nil?
      XMLHelper.add_element(water_heating_system, 'HotWaterTemperature', @temperature, :float, @temperature_isdefaulted) unless @temperature.nil?
      XMLHelper.add_element(water_heating_system, 'UsesDesuperheater', @uses_desuperheater, :boolean) unless @uses_desuperheater.nil?
      if not @related_hvac_idref.nil?
        related_hvac_idref_el = XMLHelper.add_element(water_heating_system, 'RelatedHVACSystem')
        XMLHelper.add_attribute(related_hvac_idref_el, 'idref', @related_hvac_idref)
      end
    end

    def from_oga(water_heating_system)
      return if water_heating_system.nil?

      @id = HPXML::get_id(water_heating_system)
      @fuel_type = XMLHelper.get_value(water_heating_system, 'FuelType', :string)
      @water_heater_type = XMLHelper.get_value(water_heating_system, 'WaterHeaterType', :string)
      @location = XMLHelper.get_value(water_heating_system, 'Location', :string)
      @year_installed = XMLHelper.get_value(water_heating_system, 'YearInstalled', :integer)
      @is_shared_system = XMLHelper.get_value(water_heating_system, 'IsSharedSystem', :boolean)
      @number_of_units_served = XMLHelper.get_value(water_heating_system, 'NumberofUnitsServed', :integer)
      @performance_adjustment = XMLHelper.get_value(water_heating_system, 'PerformanceAdjustment', :float)
      @third_party_certification = XMLHelper.get_value(water_heating_system, 'ThirdPartyCertification', :string)
      @tank_volume = XMLHelper.get_value(water_heating_system, 'TankVolume', :float)
      @fraction_dhw_load_served = XMLHelper.get_value(water_heating_system, 'FractionDHWLoadServed', :float)
      @heating_capacity = XMLHelper.get_value(water_heating_system, 'HeatingCapacity', :float)
      @energy_factor = XMLHelper.get_value(water_heating_system, 'EnergyFactor', :float)
      @uniform_energy_factor = XMLHelper.get_value(water_heating_system, 'UniformEnergyFactor', :float)
      @first_hour_rating = XMLHelper.get_value(water_heating_system, 'FirstHourRating', :float)
      @usage_bin = XMLHelper.get_value(water_heating_system, 'UsageBin', :string)
      @recovery_efficiency = XMLHelper.get_value(water_heating_system, 'RecoveryEfficiency', :float)
      @jacket_r_value = XMLHelper.get_value(water_heating_system, 'WaterHeaterInsulation/Jacket/JacketRValue', :float)
      @standby_loss = XMLHelper.get_value(water_heating_system, 'StandbyLoss', :float)
      @temperature = XMLHelper.get_value(water_heating_system, 'HotWaterTemperature', :float)
      @uses_desuperheater = XMLHelper.get_value(water_heating_system, 'UsesDesuperheater', :boolean)
      @related_hvac_idref = HPXML::get_idref(XMLHelper.get_element(water_heating_system, 'RelatedHVACSystem'))
    end
  end

  class HotWaterDistributions < BaseArrayElement
    def add(**kwargs)
      self << HotWaterDistribution.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Systems/WaterHeating/HotWaterDistribution').each do |hot_water_distribution|
        self << HotWaterDistribution.new(@hpxml_object, hot_water_distribution)
      end
    end
  end

  class HotWaterDistribution < BaseElement
    ATTRS = [:id, :system_type, :pipe_r_value, :standard_piping_length, :recirculation_control_type,
             :recirculation_piping_length, :recirculation_branch_piping_length,
             :recirculation_pump_power, :dwhr_facilities_connected, :dwhr_equal_flow,
             :dwhr_efficiency, :has_shared_recirculation, :shared_recirculation_number_of_units_served,
             :shared_recirculation_pump_power, :shared_recirculation_control_type,
             :shared_recirculation_motor_efficiency]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.hot_water_distributions.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      water_heating = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'WaterHeating'])
      hot_water_distribution = XMLHelper.add_element(water_heating, 'HotWaterDistribution')
      sys_id = XMLHelper.add_element(hot_water_distribution, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      if not @system_type.nil?
        system_type_el = XMLHelper.add_element(hot_water_distribution, 'SystemType')
        if @system_type == DHWDistTypeStandard
          standard = XMLHelper.add_element(system_type_el, @system_type)
          XMLHelper.add_element(standard, 'PipingLength', @standard_piping_length, :float, @standard_piping_length_isdefaulted) unless @standard_piping_length.nil?
        elsif system_type == DHWDistTypeRecirc
          recirculation = XMLHelper.add_element(system_type_el, @system_type)
          XMLHelper.add_element(recirculation, 'ControlType', @recirculation_control_type, :string) unless @recirculation_control_type.nil?
          XMLHelper.add_element(recirculation, 'RecirculationPipingLoopLength', @recirculation_piping_length, :float, @recirculation_piping_length_isdefaulted) unless @recirculation_piping_length.nil?
          XMLHelper.add_element(recirculation, 'BranchPipingLoopLength', @recirculation_branch_piping_length, :float, @recirculation_branch_piping_length_isdefaulted) unless @recirculation_branch_piping_length.nil?
          XMLHelper.add_element(recirculation, 'PumpPower', @recirculation_pump_power, :float, @recirculation_pump_power_isdefaulted) unless @recirculation_pump_power.nil?
        else
          fail "Unhandled hot water distribution type '#{@system_type}'."
        end
      end
      if not @pipe_r_value.nil?
        pipe_insulation = XMLHelper.add_element(hot_water_distribution, 'PipeInsulation')
        XMLHelper.add_element(pipe_insulation, 'PipeRValue', @pipe_r_value, :float, @pipe_r_value_isdefaulted)
      end
      if (not @dwhr_facilities_connected.nil?) || (not @dwhr_equal_flow.nil?) || (not @dwhr_efficiency.nil?)
        drain_water_heat_recovery = XMLHelper.add_element(hot_water_distribution, 'DrainWaterHeatRecovery')
        XMLHelper.add_element(drain_water_heat_recovery, 'FacilitiesConnected', @dwhr_facilities_connected, :string) unless @dwhr_facilities_connected.nil?
        XMLHelper.add_element(drain_water_heat_recovery, 'EqualFlow', @dwhr_equal_flow, :boolean) unless @dwhr_equal_flow.nil?
        XMLHelper.add_element(drain_water_heat_recovery, 'Efficiency', @dwhr_efficiency, :float) unless @dwhr_efficiency.nil?
      end
      if @has_shared_recirculation
        extension = XMLHelper.create_elements_as_needed(hot_water_distribution, ['extension'])
        shared_recirculation = XMLHelper.add_element(extension, 'SharedRecirculation')
        XMLHelper.add_element(shared_recirculation, 'NumberofUnitsServed', @shared_recirculation_number_of_units_served, :integer) unless @shared_recirculation_number_of_units_served.nil?
        XMLHelper.add_element(shared_recirculation, 'PumpPower', @shared_recirculation_pump_power, :float, @shared_recirculation_pump_power_isdefaulted) unless @shared_recirculation_pump_power.nil?
        XMLHelper.add_element(shared_recirculation, 'MotorEfficiency', @shared_recirculation_motor_efficiency, :float) unless @shared_recirculation_motor_efficiency.nil?
        XMLHelper.add_element(shared_recirculation, 'ControlType', @shared_recirculation_control_type, :string) unless @shared_recirculation_control_type.nil?
      end
    end

    def from_oga(hot_water_distribution)
      return if hot_water_distribution.nil?

      @id = HPXML::get_id(hot_water_distribution)
      @system_type = XMLHelper.get_child_name(hot_water_distribution, 'SystemType')
      if @system_type == 'Standard'
        @standard_piping_length = XMLHelper.get_value(hot_water_distribution, 'SystemType/Standard/PipingLength', :float)
      elsif @system_type == 'Recirculation'
        @recirculation_control_type = XMLHelper.get_value(hot_water_distribution, 'SystemType/Recirculation/ControlType', :string)
        @recirculation_piping_length = XMLHelper.get_value(hot_water_distribution, 'SystemType/Recirculation/RecirculationPipingLoopLength', :float)
        @recirculation_branch_piping_length = XMLHelper.get_value(hot_water_distribution, 'SystemType/Recirculation/BranchPipingLoopLength', :float)
        @recirculation_pump_power = XMLHelper.get_value(hot_water_distribution, 'SystemType/Recirculation/PumpPower', :float)
      end
      @pipe_r_value = XMLHelper.get_value(hot_water_distribution, 'PipeInsulation/PipeRValue', :float)
      @dwhr_facilities_connected = XMLHelper.get_value(hot_water_distribution, 'DrainWaterHeatRecovery/FacilitiesConnected', :string)
      @dwhr_equal_flow = XMLHelper.get_value(hot_water_distribution, 'DrainWaterHeatRecovery/EqualFlow', :boolean)
      @dwhr_efficiency = XMLHelper.get_value(hot_water_distribution, 'DrainWaterHeatRecovery/Efficiency', :float)
      @has_shared_recirculation = XMLHelper.has_element(hot_water_distribution, 'extension/SharedRecirculation')
      if @has_shared_recirculation
        @shared_recirculation_number_of_units_served = XMLHelper.get_value(hot_water_distribution, 'extension/SharedRecirculation/NumberofUnitsServed', :integer)
        @shared_recirculation_pump_power = XMLHelper.get_value(hot_water_distribution, 'extension/SharedRecirculation/PumpPower', :float)
        @shared_recirculation_motor_efficiency = XMLHelper.get_value(hot_water_distribution, 'extension/SharedRecirculation/MotorEfficiency', :float)
        @shared_recirculation_control_type = XMLHelper.get_value(hot_water_distribution, 'extension/SharedRecirculation/ControlType', :string)
      end
    end
  end

  class WaterFixtures < BaseArrayElement
    def add(**kwargs)
      self << WaterFixture.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Systems/WaterHeating/WaterFixture').each do |water_fixture|
        self << WaterFixture.new(@hpxml_object, water_fixture)
      end
    end
  end

  class WaterFixture < BaseElement
    ATTRS = [:id, :water_fixture_type, :low_flow]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.water_fixtures.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      water_heating = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'WaterHeating'])
      water_fixture = XMLHelper.add_element(water_heating, 'WaterFixture')
      sys_id = XMLHelper.add_element(water_fixture, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(water_fixture, 'WaterFixtureType', @water_fixture_type, :string) unless @water_fixture_type.nil?
      XMLHelper.add_element(water_fixture, 'LowFlow', @low_flow, :boolean) unless @low_flow.nil?
    end

    def from_oga(water_fixture)
      return if water_fixture.nil?

      @id = HPXML::get_id(water_fixture)
      @water_fixture_type = XMLHelper.get_value(water_fixture, 'WaterFixtureType', :string)
      @low_flow = XMLHelper.get_value(water_fixture, 'LowFlow', :boolean)
    end
  end

  class WaterHeating < BaseElement
    ATTRS = [:water_fixtures_usage_multiplier]
    attr_accessor(*ATTRS)

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      water_heating = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'WaterHeating'])
      XMLHelper.add_extension(water_heating, 'WaterFixturesUsageMultiplier', @water_fixtures_usage_multiplier, :float, @water_fixtures_usage_multiplier_isdefaulted) unless @water_fixtures_usage_multiplier.nil?
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      water_heating = XMLHelper.get_element(hpxml, 'Building/BuildingDetails/Systems/WaterHeating')
      return if water_heating.nil?

      @water_fixtures_usage_multiplier = XMLHelper.get_value(water_heating, 'extension/WaterFixturesUsageMultiplier', :float)
    end
  end

  class SolarThermalSystems < BaseArrayElement
    def add(**kwargs)
      self << SolarThermalSystem.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem').each do |solar_thermal_system|
        self << SolarThermalSystem.new(@hpxml_object, solar_thermal_system)
      end
    end
  end

  class SolarThermalSystem < BaseElement
    ATTRS = [:id, :system_type, :collector_area, :collector_loop_type, :collector_orientation, :collector_azimuth,
             :collector_type, :collector_tilt, :collector_frta, :collector_frul, :storage_volume,
             :water_heating_system_idref, :solar_fraction]
    attr_accessor(*ATTRS)

    def water_heating_system
      return if @water_heating_system_idref.nil?

      @hpxml_object.water_heating_systems.each do |water_heater|
        next unless water_heater.id == @water_heating_system_idref

        return water_heater
      end
      fail "Attached water heating system '#{@water_heating_system_idref}' not found for solar thermal system '#{@id}'."
    end

    def delete
      @hpxml_object.solar_thermal_systems.delete(self)
    end

    def check_for_errors
      errors = []
      begin; water_heating_system; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      solar_thermal = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'SolarThermal'])
      solar_thermal_system = XMLHelper.add_element(solar_thermal, 'SolarThermalSystem')
      sys_id = XMLHelper.add_element(solar_thermal_system, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(solar_thermal_system, 'SystemType', @system_type, :string) unless @system_type.nil?
      XMLHelper.add_element(solar_thermal_system, 'CollectorArea', @collector_area, :float) unless @collector_area.nil?
      XMLHelper.add_element(solar_thermal_system, 'CollectorLoopType', @collector_loop_type, :string) unless @collector_loop_type.nil?
      XMLHelper.add_element(solar_thermal_system, 'CollectorType', @collector_type, :string) unless @collector_type.nil?
      XMLHelper.add_element(solar_thermal_system, 'CollectorOrientation', @collector_orientation, :string, @collector_orientation_isdefaulted) unless @collector_orientation.nil?
      XMLHelper.add_element(solar_thermal_system, 'CollectorAzimuth', @collector_azimuth, :integer, @collector_azimuth_isdefaulted) unless @collector_azimuth.nil?
      XMLHelper.add_element(solar_thermal_system, 'CollectorTilt', @collector_tilt, :float) unless @collector_tilt.nil?
      XMLHelper.add_element(solar_thermal_system, 'CollectorRatedOpticalEfficiency', @collector_frta, :float) unless @collector_frta.nil?
      XMLHelper.add_element(solar_thermal_system, 'CollectorRatedThermalLosses', @collector_frul, :float) unless @collector_frul.nil?
      XMLHelper.add_element(solar_thermal_system, 'StorageVolume', @storage_volume, :float, @storage_volume_isdefaulted) unless @storage_volume.nil?
      if not @water_heating_system_idref.nil?
        connected_to = XMLHelper.add_element(solar_thermal_system, 'ConnectedTo')
        XMLHelper.add_attribute(connected_to, 'idref', @water_heating_system_idref)
      end
      XMLHelper.add_element(solar_thermal_system, 'SolarFraction', @solar_fraction, :float) unless @solar_fraction.nil?
    end

    def from_oga(solar_thermal_system)
      return if solar_thermal_system.nil?

      @id = HPXML::get_id(solar_thermal_system)
      @system_type = XMLHelper.get_value(solar_thermal_system, 'SystemType', :string)
      @collector_area = XMLHelper.get_value(solar_thermal_system, 'CollectorArea', :float)
      @collector_loop_type = XMLHelper.get_value(solar_thermal_system, 'CollectorLoopType', :string)
      @collector_type = XMLHelper.get_value(solar_thermal_system, 'CollectorType', :string)
      @collector_orientation = XMLHelper.get_value(solar_thermal_system, 'CollectorOrientation', :string)
      @collector_azimuth = XMLHelper.get_value(solar_thermal_system, 'CollectorAzimuth', :integer)
      @collector_tilt = XMLHelper.get_value(solar_thermal_system, 'CollectorTilt', :float)
      @collector_frta = XMLHelper.get_value(solar_thermal_system, 'CollectorRatedOpticalEfficiency', :float)
      @collector_frul = XMLHelper.get_value(solar_thermal_system, 'CollectorRatedThermalLosses', :float)
      @storage_volume = XMLHelper.get_value(solar_thermal_system, 'StorageVolume', :float)
      @water_heating_system_idref = HPXML::get_idref(XMLHelper.get_element(solar_thermal_system, 'ConnectedTo'))
      @solar_fraction = XMLHelper.get_value(solar_thermal_system, 'SolarFraction', :float)
    end
  end

  class PVSystems < BaseArrayElement
    def add(**kwargs)
      self << PVSystem.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Systems/Photovoltaics/PVSystem').each do |pv_system|
        self << PVSystem.new(@hpxml_object, pv_system)
      end
    end
  end

  class PVSystem < BaseElement
    ATTRS = [:id, :location, :module_type, :tracking, :array_orientation, :array_azimuth, :array_tilt,
             :max_power_output, :inverter_efficiency, :system_losses_fraction, :number_of_panels,
             :year_modules_manufactured, :is_shared_system, :number_of_bedrooms_served]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.pv_systems.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      photovoltaics = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'Photovoltaics'])
      pv_system = XMLHelper.add_element(photovoltaics, 'PVSystem')
      sys_id = XMLHelper.add_element(pv_system, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(pv_system, 'IsSharedSystem', @is_shared_system, :boolean, @is_shared_system_isdefaulted) unless @is_shared_system.nil?
      XMLHelper.add_element(pv_system, 'Location', @location, :string, @location_isdefaulted) unless @location.nil?
      XMLHelper.add_element(pv_system, 'ModuleType', @module_type, :string, @module_type_isdefaulted) unless @module_type.nil?
      XMLHelper.add_element(pv_system, 'Tracking', @tracking, :string, @tracking_isdefaulted) unless @tracking.nil?
      XMLHelper.add_element(pv_system, 'ArrayOrientation', @array_orientation, :string, @array_orientation_isdefaulted) unless @array_orientation.nil?
      XMLHelper.add_element(pv_system, 'ArrayAzimuth', @array_azimuth, :integer, @array_azimuth_isdefaulted) unless @array_azimuth.nil?
      XMLHelper.add_element(pv_system, 'ArrayTilt', @array_tilt, :float) unless @array_tilt.nil?
      XMLHelper.add_element(pv_system, 'MaxPowerOutput', @max_power_output, :float) unless @max_power_output.nil?
      XMLHelper.add_element(pv_system, 'NumberOfPanels', @number_of_panels, :integer) unless @number_of_panels.nil?
      XMLHelper.add_element(pv_system, 'InverterEfficiency', @inverter_efficiency, :float, @inverter_efficiency_isdefaulted) unless @inverter_efficiency.nil?
      XMLHelper.add_element(pv_system, 'SystemLossesFraction', @system_losses_fraction, :float, @system_losses_fraction_isdefaulted) unless @system_losses_fraction.nil?
      XMLHelper.add_element(pv_system, 'YearModulesManufactured', @year_modules_manufactured, :integer) unless @year_modules_manufactured.nil?
      XMLHelper.add_extension(pv_system, 'NumberofBedroomsServed', @number_of_bedrooms_served, :integer) unless @number_of_bedrooms_served.nil?
    end

    def from_oga(pv_system)
      return if pv_system.nil?

      @id = HPXML::get_id(pv_system)
      @is_shared_system = XMLHelper.get_value(pv_system, 'IsSharedSystem', :boolean)
      @location = XMLHelper.get_value(pv_system, 'Location', :string)
      @module_type = XMLHelper.get_value(pv_system, 'ModuleType', :string)
      @tracking = XMLHelper.get_value(pv_system, 'Tracking', :string)
      @array_orientation = XMLHelper.get_value(pv_system, 'ArrayOrientation', :string)
      @array_azimuth = XMLHelper.get_value(pv_system, 'ArrayAzimuth', :integer)
      @array_tilt = XMLHelper.get_value(pv_system, 'ArrayTilt', :float)
      @max_power_output = XMLHelper.get_value(pv_system, 'MaxPowerOutput', :float)
      @number_of_panels = XMLHelper.get_value(pv_system, 'NumberOfPanels', :integer)
      @inverter_efficiency = XMLHelper.get_value(pv_system, 'InverterEfficiency', :float)
      @system_losses_fraction = XMLHelper.get_value(pv_system, 'SystemLossesFraction', :float)
      @year_modules_manufactured = XMLHelper.get_value(pv_system, 'YearModulesManufactured', :integer)
      @number_of_bedrooms_served = XMLHelper.get_value(pv_system, 'extension/NumberofBedroomsServed', :integer)
    end
  end

  class Generators < BaseArrayElement
    def add(**kwargs)
      self << Generator.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Systems/extension/Generators/Generator').each do |generator|
        self << Generator.new(@hpxml_object, generator)
      end
    end
  end

  class Generator < BaseElement
    ATTRS = [:id, :fuel_type, :annual_consumption_kbtu, :annual_output_kwh, :is_shared_system, :number_of_bedrooms_served]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.generators.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      generators = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Systems', 'extension', 'Generators'])
      generator = XMLHelper.add_element(generators, 'Generator')
      sys_id = XMLHelper.add_element(generator, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(generator, 'IsSharedSystem', @is_shared_system, :boolean, @is_shared_system_isdefaulted) unless @is_shared_system.nil?
      XMLHelper.add_element(generator, 'FuelType', @fuel_type, :string) unless @fuel_type.nil?
      XMLHelper.add_element(generator, 'AnnualConsumptionkBtu', @annual_consumption_kbtu, :float) unless @annual_consumption_kbtu.nil?
      XMLHelper.add_element(generator, 'AnnualOutputkWh', @annual_output_kwh, :float) unless @annual_output_kwh.nil?
      XMLHelper.add_element(generator, 'NumberofBedroomsServed', @number_of_bedrooms_served, :integer) unless @number_of_bedrooms_served.nil?
    end

    def from_oga(generator)
      return if generator.nil?

      @id = HPXML::get_id(generator)
      @is_shared_system = XMLHelper.get_value(generator, 'IsSharedSystem', :boolean)
      @fuel_type = XMLHelper.get_value(generator, 'FuelType', :string)
      @annual_consumption_kbtu = XMLHelper.get_value(generator, 'AnnualConsumptionkBtu', :float)
      @annual_output_kwh = XMLHelper.get_value(generator, 'AnnualOutputkWh', :float)
      @number_of_bedrooms_served = XMLHelper.get_value(generator, 'NumberofBedroomsServed', :integer)
    end
  end

  class ClothesWashers < BaseArrayElement
    def add(**kwargs)
      self << ClothesWasher.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Appliances/ClothesWasher').each do |clothes_washer|
        self << ClothesWasher.new(@hpxml_object, clothes_washer)
      end
    end
  end

  class ClothesWasher < BaseElement
    ATTRS = [:id, :location, :modified_energy_factor, :integrated_modified_energy_factor,
             :rated_annual_kwh, :label_electric_rate, :label_gas_rate, :label_annual_gas_cost,
             :capacity, :label_usage, :usage_multiplier, :is_shared_appliance,
             :number_of_units, :number_of_units_served, :water_heating_system_idref]
    attr_accessor(*ATTRS)

    def water_heating_system
      return if @water_heating_system_idref.nil?

      @hpxml_object.water_heating_systems.each do |water_heater|
        next unless water_heater.id == @water_heating_system_idref

        return water_heater
      end
      fail "Attached water heating system '#{@water_heating_system_idref}' not found for clothes washer '#{@id}'."
    end

    def delete
      @hpxml_object.clothes_washers.delete(self)
    end

    def check_for_errors
      errors = []
      begin; water_heating_system; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      appliances = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Appliances'])
      clothes_washer = XMLHelper.add_element(appliances, 'ClothesWasher')
      sys_id = XMLHelper.add_element(clothes_washer, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(clothes_washer, 'NumberofUnits', @number_of_units, :integer) unless @number_of_units.nil?
      XMLHelper.add_element(clothes_washer, 'IsSharedAppliance', @is_shared_appliance, :boolean, @is_shared_appliance_isdefaulted) unless @is_shared_appliance.nil?
      XMLHelper.add_element(clothes_washer, 'NumberofUnitsServed', @number_of_units_served, :integer) unless @number_of_units_served.nil?
      if not @water_heating_system_idref.nil?
        attached_water_heater = XMLHelper.add_element(clothes_washer, 'AttachedToWaterHeatingSystem')
        XMLHelper.add_attribute(attached_water_heater, 'idref', @water_heating_system_idref)
      end
      XMLHelper.add_element(clothes_washer, 'Location', @location, :string, @location_isdefaulted) unless @location.nil?
      XMLHelper.add_element(clothes_washer, 'ModifiedEnergyFactor', @modified_energy_factor, :float) unless @modified_energy_factor.nil?
      XMLHelper.add_element(clothes_washer, 'IntegratedModifiedEnergyFactor', @integrated_modified_energy_factor, :float, @integrated_modified_energy_factor_isdefaulted) unless @integrated_modified_energy_factor.nil?
      XMLHelper.add_element(clothes_washer, 'RatedAnnualkWh', @rated_annual_kwh, :float, @rated_annual_kwh_isdefaulted) unless @rated_annual_kwh.nil?
      XMLHelper.add_element(clothes_washer, 'LabelElectricRate', @label_electric_rate, :float, @label_electric_rate_isdefaulted) unless @label_electric_rate.nil?
      XMLHelper.add_element(clothes_washer, 'LabelGasRate', @label_gas_rate, :float, @label_gas_rate_isdefaulted) unless @label_gas_rate.nil?
      XMLHelper.add_element(clothes_washer, 'LabelAnnualGasCost', @label_annual_gas_cost, :float, @label_annual_gas_cost_isdefaulted) unless @label_annual_gas_cost.nil?
      XMLHelper.add_element(clothes_washer, 'LabelUsage', @label_usage, :float, @label_usage_isdefaulted) unless @label_usage.nil?
      XMLHelper.add_element(clothes_washer, 'Capacity', @capacity, :float, @capacity_isdefaulted) unless @capacity.nil?
      XMLHelper.add_extension(clothes_washer, 'UsageMultiplier', @usage_multiplier, :float, @usage_multiplier_isdefaulted) unless @usage_multiplier.nil?
    end

    def from_oga(clothes_washer)
      return if clothes_washer.nil?

      @id = HPXML::get_id(clothes_washer)
      @number_of_units = XMLHelper.get_value(clothes_washer, 'NumberofUnits', :integer)
      @is_shared_appliance = XMLHelper.get_value(clothes_washer, 'IsSharedAppliance', :boolean)
      @number_of_units_served = XMLHelper.get_value(clothes_washer, 'NumberofUnitsServed', :integer)
      @water_heating_system_idref = HPXML::get_idref(XMLHelper.get_element(clothes_washer, 'AttachedToWaterHeatingSystem'))
      @location = XMLHelper.get_value(clothes_washer, 'Location', :string)
      @modified_energy_factor = XMLHelper.get_value(clothes_washer, 'ModifiedEnergyFactor', :float)
      @integrated_modified_energy_factor = XMLHelper.get_value(clothes_washer, 'IntegratedModifiedEnergyFactor', :float)
      @rated_annual_kwh = XMLHelper.get_value(clothes_washer, 'RatedAnnualkWh', :float)
      @label_electric_rate = XMLHelper.get_value(clothes_washer, 'LabelElectricRate', :float)
      @label_gas_rate = XMLHelper.get_value(clothes_washer, 'LabelGasRate', :float)
      @label_annual_gas_cost = XMLHelper.get_value(clothes_washer, 'LabelAnnualGasCost', :float)
      @label_usage = XMLHelper.get_value(clothes_washer, 'LabelUsage', :float)
      @capacity = XMLHelper.get_value(clothes_washer, 'Capacity', :float)
      @usage_multiplier = XMLHelper.get_value(clothes_washer, 'extension/UsageMultiplier', :float)
    end
  end

  class ClothesDryers < BaseArrayElement
    def add(**kwargs)
      self << ClothesDryer.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Appliances/ClothesDryer').each do |clothes_dryer|
        self << ClothesDryer.new(@hpxml_object, clothes_dryer)
      end
    end
  end

  class ClothesDryer < BaseElement
    ATTRS = [:id, :location, :fuel_type, :energy_factor, :combined_energy_factor, :control_type,
             :usage_multiplier, :is_shared_appliance, :number_of_units, :number_of_units_served,
             :is_vented, :vented_flow_rate]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.clothes_dryers.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      appliances = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Appliances'])
      clothes_dryer = XMLHelper.add_element(appliances, 'ClothesDryer')
      sys_id = XMLHelper.add_element(clothes_dryer, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(clothes_dryer, 'NumberofUnits', @number_of_units, :integer) unless @number_of_units.nil?
      XMLHelper.add_element(clothes_dryer, 'IsSharedAppliance', @is_shared_appliance, :boolean, @is_shared_appliance_isdefaulted) unless @is_shared_appliance.nil?
      XMLHelper.add_element(clothes_dryer, 'NumberofUnitsServed', @number_of_units_served, :integer) unless @number_of_units_served.nil?
      XMLHelper.add_element(clothes_dryer, 'Location', @location, :string, @location_isdefaulted) unless @location.nil?
      XMLHelper.add_element(clothes_dryer, 'FuelType', @fuel_type, :string) unless @fuel_type.nil?
      XMLHelper.add_element(clothes_dryer, 'EnergyFactor', @energy_factor, :float) unless @energy_factor.nil?
      XMLHelper.add_element(clothes_dryer, 'CombinedEnergyFactor', @combined_energy_factor, :float, @combined_energy_factor_isdefaulted) unless @combined_energy_factor.nil?
      XMLHelper.add_element(clothes_dryer, 'ControlType', @control_type, :string, @control_type_isdefaulted) unless @control_type.nil?
      XMLHelper.add_element(clothes_dryer, 'Vented', @is_vented, :boolean, @is_vented_isdefaulted) unless @is_vented.nil?
      XMLHelper.add_element(clothes_dryer, 'VentedFlowRate', @vented_flow_rate, :float, @vented_flow_rate_isdefaulted) unless @vented_flow_rate.nil?
      XMLHelper.add_extension(clothes_dryer, 'UsageMultiplier', @usage_multiplier, :float, @usage_multiplier_isdefaulted) unless @usage_multiplier.nil?
    end

    def from_oga(clothes_dryer)
      return if clothes_dryer.nil?

      @id = HPXML::get_id(clothes_dryer)
      @number_of_units = XMLHelper.get_value(clothes_dryer, 'NumberofUnits', :integer)
      @is_shared_appliance = XMLHelper.get_value(clothes_dryer, 'IsSharedAppliance', :boolean)
      @number_of_units_served = XMLHelper.get_value(clothes_dryer, 'NumberofUnitsServed', :integer)
      @location = XMLHelper.get_value(clothes_dryer, 'Location', :string)
      @fuel_type = XMLHelper.get_value(clothes_dryer, 'FuelType', :string)
      @energy_factor = XMLHelper.get_value(clothes_dryer, 'EnergyFactor', :float)
      @combined_energy_factor = XMLHelper.get_value(clothes_dryer, 'CombinedEnergyFactor', :float)
      @control_type = XMLHelper.get_value(clothes_dryer, 'ControlType', :string)
      @is_vented = XMLHelper.get_value(clothes_dryer, 'Vented', :boolean)
      @vented_flow_rate = XMLHelper.get_value(clothes_dryer, 'VentedFlowRate', :float)
      @usage_multiplier = XMLHelper.get_value(clothes_dryer, 'extension/UsageMultiplier', :float)
    end
  end

  class Dishwashers < BaseArrayElement
    def add(**kwargs)
      self << Dishwasher.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Appliances/Dishwasher').each do |dishwasher|
        self << Dishwasher.new(@hpxml_object, dishwasher)
      end
    end
  end

  class Dishwasher < BaseElement
    ATTRS = [:id, :location, :energy_factor, :rated_annual_kwh, :place_setting_capacity,
             :label_electric_rate, :label_gas_rate, :label_annual_gas_cost,
             :label_usage, :usage_multiplier, :is_shared_appliance, :water_heating_system_idref]
    attr_accessor(*ATTRS)

    def water_heating_system
      return if @water_heating_system_idref.nil?

      @hpxml_object.water_heating_systems.each do |water_heater|
        next unless water_heater.id == @water_heating_system_idref

        return water_heater
      end
      fail "Attached water heating system '#{@water_heating_system_idref}' not found for dishwasher '#{@id}'."
    end

    def delete
      @hpxml_object.dishwashers.delete(self)
    end

    def check_for_errors
      errors = []
      begin; water_heating_system; rescue StandardError => e; errors << e.message; end
      return errors
    end

    def to_oga(doc)
      return if nil?

      appliances = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Appliances'])
      dishwasher = XMLHelper.add_element(appliances, 'Dishwasher')
      sys_id = XMLHelper.add_element(dishwasher, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(dishwasher, 'IsSharedAppliance', @is_shared_appliance, :boolean, @is_shared_appliance_isdefaulted) unless @is_shared_appliance.nil?
      if not @water_heating_system_idref.nil?
        attached_water_heater = XMLHelper.add_element(dishwasher, 'AttachedToWaterHeatingSystem')
        XMLHelper.add_attribute(attached_water_heater, 'idref', @water_heating_system_idref)
      end
      XMLHelper.add_element(dishwasher, 'Location', @location, :string, @location_isdefaulted) unless @location.nil?
      XMLHelper.add_element(dishwasher, 'RatedAnnualkWh', @rated_annual_kwh, :float, @rated_annual_kwh_isdefaulted) unless @rated_annual_kwh.nil?
      XMLHelper.add_element(dishwasher, 'EnergyFactor', @energy_factor, :float) unless @energy_factor.nil?
      XMLHelper.add_element(dishwasher, 'PlaceSettingCapacity', @place_setting_capacity, :integer, @place_setting_capacity_isdefaulted) unless @place_setting_capacity.nil?
      XMLHelper.add_element(dishwasher, 'LabelElectricRate', @label_electric_rate, :float, @label_electric_rate_isdefaulted) unless @label_electric_rate.nil?
      XMLHelper.add_element(dishwasher, 'LabelGasRate', @label_gas_rate, :float, @label_gas_rate_isdefaulted) unless @label_gas_rate.nil?
      XMLHelper.add_element(dishwasher, 'LabelAnnualGasCost', @label_annual_gas_cost, :float, @label_annual_gas_cost_isdefaulted) unless @label_annual_gas_cost.nil?
      XMLHelper.add_element(dishwasher, 'LabelUsage', @label_usage, :float, @label_usage_isdefaulted) unless @label_usage.nil?
      XMLHelper.add_extension(dishwasher, 'UsageMultiplier', @usage_multiplier, :float, @usage_multiplier_isdefaulted) unless @usage_multiplier.nil?
    end

    def from_oga(dishwasher)
      return if dishwasher.nil?

      @id = HPXML::get_id(dishwasher)
      @is_shared_appliance = XMLHelper.get_value(dishwasher, 'IsSharedAppliance', :boolean)
      @water_heating_system_idref = HPXML::get_idref(XMLHelper.get_element(dishwasher, 'AttachedToWaterHeatingSystem'))
      @location = XMLHelper.get_value(dishwasher, 'Location', :string)
      @rated_annual_kwh = XMLHelper.get_value(dishwasher, 'RatedAnnualkWh', :float)
      @energy_factor = XMLHelper.get_value(dishwasher, 'EnergyFactor', :float)
      @place_setting_capacity = XMLHelper.get_value(dishwasher, 'PlaceSettingCapacity', :integer)
      @label_electric_rate = XMLHelper.get_value(dishwasher, 'LabelElectricRate', :float)
      @label_gas_rate = XMLHelper.get_value(dishwasher, 'LabelGasRate', :float)
      @label_annual_gas_cost = XMLHelper.get_value(dishwasher, 'LabelAnnualGasCost', :float)
      @label_usage = XMLHelper.get_value(dishwasher, 'LabelUsage', :float)
      @usage_multiplier = XMLHelper.get_value(dishwasher, 'extension/UsageMultiplier', :float)
    end
  end

  class Refrigerators < BaseArrayElement
    def add(**kwargs)
      self << Refrigerator.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Appliances/Refrigerator').each do |refrigerator|
        self << Refrigerator.new(@hpxml_object, refrigerator)
      end
    end
  end

  class Refrigerator < BaseElement
    ATTRS = [:id, :location, :rated_annual_kwh, :adjusted_annual_kwh, :usage_multiplier, :primary_indicator,
             :weekday_fractions, :weekend_fractions, :monthly_multipliers]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.refrigerators.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      appliances = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Appliances'])
      refrigerator = XMLHelper.add_element(appliances, 'Refrigerator')
      sys_id = XMLHelper.add_element(refrigerator, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(refrigerator, 'Location', @location, :string, @location_isdefaulted) unless @location.nil?
      XMLHelper.add_element(refrigerator, 'RatedAnnualkWh', @rated_annual_kwh, :float, @rated_annual_kwh_isdefaulted) unless @rated_annual_kwh.nil?
      XMLHelper.add_element(refrigerator, 'PrimaryIndicator', @primary_indicator, :boolean, @primary_indicator_isdefaulted) unless @primary_indicator.nil?
      XMLHelper.add_extension(refrigerator, 'AdjustedAnnualkWh', @adjusted_annual_kwh, :float) unless @adjusted_annual_kwh.nil?
      XMLHelper.add_extension(refrigerator, 'UsageMultiplier', @usage_multiplier, :float, @usage_multiplier_isdefaulted) unless @usage_multiplier.nil?
      XMLHelper.add_extension(refrigerator, 'WeekdayScheduleFractions', @weekday_fractions, :string, @weekday_fractions_isdefaulted) unless @weekday_fractions.nil?
      XMLHelper.add_extension(refrigerator, 'WeekendScheduleFractions', @weekend_fractions, :string, @weekend_fractions_isdefaulted) unless @weekend_fractions.nil?
      XMLHelper.add_extension(refrigerator, 'MonthlyScheduleMultipliers', @monthly_multipliers, :string, @monthly_multipliers_isdefaulted) unless @monthly_multipliers.nil?
    end

    def from_oga(refrigerator)
      return if refrigerator.nil?

      @id = HPXML::get_id(refrigerator)
      @location = XMLHelper.get_value(refrigerator, 'Location', :string)
      @rated_annual_kwh = XMLHelper.get_value(refrigerator, 'RatedAnnualkWh', :float)
      @primary_indicator = XMLHelper.get_value(refrigerator, 'PrimaryIndicator', :boolean)
      @adjusted_annual_kwh = XMLHelper.get_value(refrigerator, 'extension/AdjustedAnnualkWh', :float)
      @usage_multiplier = XMLHelper.get_value(refrigerator, 'extension/UsageMultiplier', :float)
      @weekday_fractions = XMLHelper.get_value(refrigerator, 'extension/WeekdayScheduleFractions', :string)
      @weekend_fractions = XMLHelper.get_value(refrigerator, 'extension/WeekendScheduleFractions', :string)
      @monthly_multipliers = XMLHelper.get_value(refrigerator, 'extension/MonthlyScheduleMultipliers', :string)
    end
  end

  class Freezers < BaseArrayElement
    def add(**kwargs)
      self << Freezer.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Appliances/Freezer').each do |freezer|
        self << Freezer.new(@hpxml_object, freezer)
      end
    end
  end

  class Freezer < BaseElement
    ATTRS = [:id, :location, :rated_annual_kwh, :adjusted_annual_kwh, :usage_multiplier,
             :weekday_fractions, :weekend_fractions, :monthly_multipliers]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.freezers.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      appliances = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Appliances'])
      freezer = XMLHelper.add_element(appliances, 'Freezer')
      sys_id = XMLHelper.add_element(freezer, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(freezer, 'Location', @location, :string, @location_isdefaulted) unless @location.nil?
      XMLHelper.add_element(freezer, 'RatedAnnualkWh', @rated_annual_kwh, :float, @rated_annual_kwh_isdefaulted) unless @rated_annual_kwh.nil?
      XMLHelper.add_extension(freezer, 'AdjustedAnnualkWh', @adjusted_annual_kwh, :float) unless @adjusted_annual_kwh.nil?
      XMLHelper.add_extension(freezer, 'UsageMultiplier', @usage_multiplier, :float, @usage_multiplier_isdefaulted) unless @usage_multiplier.nil?
      XMLHelper.add_extension(freezer, 'WeekdayScheduleFractions', @weekday_fractions, :string, @weekday_fractions_isdefaulted) unless @weekday_fractions.nil?
      XMLHelper.add_extension(freezer, 'WeekendScheduleFractions', @weekend_fractions, :string, @weekend_fractions_isdefaulted) unless @weekend_fractions.nil?
      XMLHelper.add_extension(freezer, 'MonthlyScheduleMultipliers', @monthly_multipliers, :string, @monthly_multipliers_isdefaulted) unless @monthly_multipliers.nil?
    end

    def from_oga(freezer)
      return if freezer.nil?

      @id = HPXML::get_id(freezer)
      @location = XMLHelper.get_value(freezer, 'Location', :string)
      @rated_annual_kwh = XMLHelper.get_value(freezer, 'RatedAnnualkWh', :float)
      @adjusted_annual_kwh = XMLHelper.get_value(freezer, 'extension/AdjustedAnnualkWh', :float)
      @usage_multiplier = XMLHelper.get_value(freezer, 'extension/UsageMultiplier', :float)
      @weekday_fractions = XMLHelper.get_value(freezer, 'extension/WeekdayScheduleFractions', :string)
      @weekend_fractions = XMLHelper.get_value(freezer, 'extension/WeekendScheduleFractions', :string)
      @monthly_multipliers = XMLHelper.get_value(freezer, 'extension/MonthlyScheduleMultipliers', :string)
    end
  end

  class Dehumidifiers < BaseArrayElement
    def add(**kwargs)
      self << Dehumidifier.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Appliances/Dehumidifier').each do |dehumidifier|
        self << Dehumidifier.new(@hpxml_object, dehumidifier)
      end
    end
  end

  class Dehumidifier < BaseElement
    ATTRS = [:id, :type, :capacity, :energy_factor, :integrated_energy_factor, :rh_setpoint, :fraction_served,
             :location]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.dehumidifiers.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      appliances = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Appliances'])
      dehumidifier = XMLHelper.add_element(appliances, 'Dehumidifier')
      sys_id = XMLHelper.add_element(dehumidifier, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(dehumidifier, 'Type', @type, :string) unless @type.nil?
      XMLHelper.add_element(dehumidifier, 'Location', @location, :string) unless @location.nil?
      XMLHelper.add_element(dehumidifier, 'Capacity', @capacity, :float) unless @capacity.nil?
      XMLHelper.add_element(dehumidifier, 'EnergyFactor', @energy_factor, :float) unless @energy_factor.nil?
      XMLHelper.add_element(dehumidifier, 'IntegratedEnergyFactor', @integrated_energy_factor, :float) unless @integrated_energy_factor.nil?
      XMLHelper.add_element(dehumidifier, 'DehumidistatSetpoint', @rh_setpoint, :float) unless @rh_setpoint.nil?
      XMLHelper.add_element(dehumidifier, 'FractionDehumidificationLoadServed', @fraction_served, :float) unless @fraction_served.nil?
    end

    def from_oga(dehumidifier)
      return if dehumidifier.nil?

      @id = HPXML::get_id(dehumidifier)
      @type = XMLHelper.get_value(dehumidifier, 'Type', :string)
      @location = XMLHelper.get_value(dehumidifier, 'Location', :string)
      @capacity = XMLHelper.get_value(dehumidifier, 'Capacity', :float)
      @energy_factor = XMLHelper.get_value(dehumidifier, 'EnergyFactor', :float)
      @integrated_energy_factor = XMLHelper.get_value(dehumidifier, 'IntegratedEnergyFactor', :float)
      @rh_setpoint = XMLHelper.get_value(dehumidifier, 'DehumidistatSetpoint', :float)
      @fraction_served = XMLHelper.get_value(dehumidifier, 'FractionDehumidificationLoadServed', :float)
    end
  end

  class CookingRanges < BaseArrayElement
    def add(**kwargs)
      self << CookingRange.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Appliances/CookingRange').each do |cooking_range|
        self << CookingRange.new(@hpxml_object, cooking_range)
      end
    end
  end

  class CookingRange < BaseElement
    ATTRS = [:id, :location, :fuel_type, :is_induction, :usage_multiplier,
             :weekday_fractions, :weekend_fractions, :monthly_multipliers]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.cooking_ranges.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      appliances = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Appliances'])
      cooking_range = XMLHelper.add_element(appliances, 'CookingRange')
      sys_id = XMLHelper.add_element(cooking_range, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(cooking_range, 'Location', @location, :string, @location_isdefaulted) unless @location.nil?
      XMLHelper.add_element(cooking_range, 'FuelType', @fuel_type, :string) unless @fuel_type.nil?
      XMLHelper.add_element(cooking_range, 'IsInduction', @is_induction, :boolean, @is_induction_isdefaulted) unless @is_induction.nil?
      XMLHelper.add_extension(cooking_range, 'UsageMultiplier', @usage_multiplier, :float, @usage_multiplier_isdefaulted) unless @usage_multiplier.nil?
      XMLHelper.add_extension(cooking_range, 'WeekdayScheduleFractions', @weekday_fractions, :string, @weekday_fractions_isdefaulted) unless @weekday_fractions.nil?
      XMLHelper.add_extension(cooking_range, 'WeekendScheduleFractions', @weekend_fractions, :string, @weekend_fractions_isdefaulted) unless @weekend_fractions.nil?
      XMLHelper.add_extension(cooking_range, 'MonthlyScheduleMultipliers', @monthly_multipliers, :string, @monthly_multipliers_isdefaulted) unless @monthly_multipliers.nil?
    end

    def from_oga(cooking_range)
      return if cooking_range.nil?

      @id = HPXML::get_id(cooking_range)
      @location = XMLHelper.get_value(cooking_range, 'Location', :string)
      @fuel_type = XMLHelper.get_value(cooking_range, 'FuelType', :string)
      @is_induction = XMLHelper.get_value(cooking_range, 'IsInduction', :boolean)
      @usage_multiplier = XMLHelper.get_value(cooking_range, 'extension/UsageMultiplier', :float)
      @weekday_fractions = XMLHelper.get_value(cooking_range, 'extension/WeekdayScheduleFractions', :string)
      @weekend_fractions = XMLHelper.get_value(cooking_range, 'extension/WeekendScheduleFractions', :string)
      @monthly_multipliers = XMLHelper.get_value(cooking_range, 'extension/MonthlyScheduleMultipliers', :string)
    end
  end

  class Ovens < BaseArrayElement
    def add(**kwargs)
      self << Oven.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Appliances/Oven').each do |oven|
        self << Oven.new(@hpxml_object, oven)
      end
    end
  end

  class Oven < BaseElement
    ATTRS = [:id, :is_convection]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.ovens.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      appliances = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Appliances'])
      oven = XMLHelper.add_element(appliances, 'Oven')
      sys_id = XMLHelper.add_element(oven, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(oven, 'IsConvection', @is_convection, :boolean, @is_convection_isdefaulted) unless @is_convection.nil?
    end

    def from_oga(oven)
      return if oven.nil?

      @id = HPXML::get_id(oven)
      @is_convection = XMLHelper.get_value(oven, 'IsConvection', :boolean)
    end
  end

  class LightingGroups < BaseArrayElement
    def add(**kwargs)
      self << LightingGroup.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Lighting/LightingGroup').each do |lighting_group|
        self << LightingGroup.new(@hpxml_object, lighting_group)
      end
    end
  end

  class LightingGroup < BaseElement
    ATTRS = [:id, :location, :fraction_of_units_in_location, :lighting_type]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.lighting_groups.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      lighting = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Lighting'])
      lighting_group = XMLHelper.add_element(lighting, 'LightingGroup')
      sys_id = XMLHelper.add_element(lighting_group, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(lighting_group, 'Location', @location, :string) unless @location.nil?
      XMLHelper.add_element(lighting_group, 'FractionofUnitsInLocation', @fraction_of_units_in_location, :float) unless @fraction_of_units_in_location.nil?
      if not @lighting_type.nil?
        lighting_type = XMLHelper.add_element(lighting_group, 'LightingType')
        XMLHelper.add_element(lighting_type, @lighting_type)
      end
    end

    def from_oga(lighting_group)
      return if lighting_group.nil?

      @id = HPXML::get_id(lighting_group)
      @location = XMLHelper.get_value(lighting_group, 'Location', :string)
      @fraction_of_units_in_location = XMLHelper.get_value(lighting_group, 'FractionofUnitsInLocation', :float)
      @lighting_type = XMLHelper.get_child_name(lighting_group, 'LightingType')
    end
  end

  class Lighting < BaseElement
    ATTRS = [:interior_usage_multiplier, :garage_usage_multiplier, :exterior_usage_multiplier,
             :interior_weekday_fractions, :interior_weekend_fractions, :interior_monthly_multipliers,
             :garage_weekday_fractions, :garage_weekend_fractions, :garage_monthly_multipliers,
             :exterior_weekday_fractions, :exterior_weekend_fractions, :exterior_monthly_multipliers,
             :holiday_exists, :holiday_kwh_per_day, :holiday_period_begin_month, :holiday_period_begin_day,
             :holiday_period_end_month, :holiday_period_end_day, :holiday_weekday_fractions, :holiday_weekend_fractions]
    attr_accessor(*ATTRS)

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      lighting = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Lighting'])
      XMLHelper.add_extension(lighting, 'InteriorUsageMultiplier', @interior_usage_multiplier, :float, @interior_usage_multiplier_isdefaulted) unless @interior_usage_multiplier.nil?
      XMLHelper.add_extension(lighting, 'GarageUsageMultiplier', @garage_usage_multiplier, :float, @garage_usage_multiplier_isdefaulted) unless @garage_usage_multiplier.nil?
      XMLHelper.add_extension(lighting, 'ExteriorUsageMultiplier', @exterior_usage_multiplier, :float, @exterior_usage_multiplier_isdefaulted) unless @exterior_usage_multiplier.nil?
      XMLHelper.add_extension(lighting, 'InteriorWeekdayScheduleFractions', @interior_weekday_fractions, :string, @interior_weekday_fractions_isdefaulted) unless @interior_weekday_fractions.nil?
      XMLHelper.add_extension(lighting, 'InteriorWeekendScheduleFractions', @interior_weekend_fractions, :string, @interior_weekend_fractions_isdefaulted) unless @interior_weekend_fractions.nil?
      XMLHelper.add_extension(lighting, 'InteriorMonthlyScheduleMultipliers', @interior_monthly_multipliers, :string, @interior_monthly_multipliers_isdefaulted) unless @interior_monthly_multipliers.nil?
      XMLHelper.add_extension(lighting, 'GarageWeekdayScheduleFractions', @garage_weekday_fractions, :string, @garage_weekday_fractions_isdefaulted) unless @garage_weekday_fractions.nil?
      XMLHelper.add_extension(lighting, 'GarageWeekendScheduleFractions', @garage_weekend_fractions, :string, @garage_weekend_fractions_isdefaulted) unless @garage_weekend_fractions.nil?
      XMLHelper.add_extension(lighting, 'GarageMonthlyScheduleMultipliers', @garage_monthly_multipliers, :string, @garage_monthly_multipliers_isdefaulted) unless @garage_monthly_multipliers.nil?
      XMLHelper.add_extension(lighting, 'ExteriorWeekdayScheduleFractions', @exterior_weekday_fractions, :string, @exterior_weekday_fractions_isdefaulted) unless @exterior_weekday_fractions.nil?
      XMLHelper.add_extension(lighting, 'ExteriorWeekendScheduleFractions', @exterior_weekend_fractions, :string, @exterior_weekend_fractions_isdefaulted) unless @exterior_weekend_fractions.nil?
      XMLHelper.add_extension(lighting, 'ExteriorMonthlyScheduleMultipliers', @exterior_monthly_multipliers, :string, @exterior_monthly_multipliers_isdefaulted) unless @exterior_monthly_multipliers.nil?
      if @holiday_exists
        exterior_holiday_lighting = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Lighting', 'extension', 'ExteriorHolidayLighting'])
        if not @holiday_kwh_per_day.nil?
          holiday_lighting_load = XMLHelper.add_element(exterior_holiday_lighting, 'Load')
          XMLHelper.add_element(holiday_lighting_load, 'Units', 'kWh/day', :string)
          XMLHelper.add_element(holiday_lighting_load, 'Value', @holiday_kwh_per_day, :float, @holiday_kwh_per_day_isdefaulted)
        end
        XMLHelper.add_element(exterior_holiday_lighting, 'PeriodBeginMonth', @holiday_period_begin_month, :integer, @holiday_period_begin_month_isdefaulted) unless @holiday_period_begin_month.nil?
        XMLHelper.add_element(exterior_holiday_lighting, 'PeriodBeginDayOfMonth', @holiday_period_begin_day, :integer, @holiday_period_begin_day_isdefaulted) unless @holiday_period_begin_day.nil?
        XMLHelper.add_element(exterior_holiday_lighting, 'PeriodEndMonth', @holiday_period_end_month, :integer, @holiday_period_end_month_isdefaulted) unless @holiday_period_end_month.nil?
        XMLHelper.add_element(exterior_holiday_lighting, 'PeriodEndDayOfMonth', @holiday_period_end_day, :integer, @holiday_period_end_day_isdefaulted) unless @holiday_period_end_day.nil?
        XMLHelper.add_element(exterior_holiday_lighting, 'WeekdayScheduleFractions', @holiday_weekday_fractions, :string, @holiday_weekday_fractions_isdefaulted) unless @holiday_weekday_fractions.nil?
        XMLHelper.add_element(exterior_holiday_lighting, 'WeekendScheduleFractions', @holiday_weekend_fractions, :string, @holiday_weekend_fractions_isdefaulted) unless @holiday_weekend_fractions.nil?
      end
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      lighting = XMLHelper.get_element(hpxml, 'Building/BuildingDetails/Lighting')
      return if lighting.nil?

      @interior_usage_multiplier = XMLHelper.get_value(lighting, 'extension/InteriorUsageMultiplier', :float)
      @garage_usage_multiplier = XMLHelper.get_value(lighting, 'extension/GarageUsageMultiplier', :float)
      @exterior_usage_multiplier = XMLHelper.get_value(lighting, 'extension/ExteriorUsageMultiplier', :float)
      @interior_weekday_fractions = XMLHelper.get_value(lighting, 'extension/InteriorWeekdayScheduleFractions', :string)
      @interior_weekend_fractions = XMLHelper.get_value(lighting, 'extension/InteriorWeekendScheduleFractions', :string)
      @interior_monthly_multipliers = XMLHelper.get_value(lighting, 'extension/InteriorMonthlyScheduleMultipliers', :string)
      @garage_weekday_fractions = XMLHelper.get_value(lighting, 'extension/GarageWeekdayScheduleFractions', :string)
      @garage_weekend_fractions = XMLHelper.get_value(lighting, 'extension/GarageWeekendScheduleFractions', :string)
      @garage_monthly_multipliers = XMLHelper.get_value(lighting, 'extension/GarageMonthlyScheduleMultipliers', :string)
      @exterior_weekday_fractions = XMLHelper.get_value(lighting, 'extension/ExteriorWeekdayScheduleFractions', :string)
      @exterior_weekend_fractions = XMLHelper.get_value(lighting, 'extension/ExteriorWeekendScheduleFractions', :string)
      @exterior_monthly_multipliers = XMLHelper.get_value(lighting, 'extension/ExteriorMonthlyScheduleMultipliers', :string)
      if not XMLHelper.get_element(hpxml, 'Building/BuildingDetails/Lighting/extension/ExteriorHolidayLighting').nil?
        @holiday_exists = true
        @holiday_kwh_per_day = XMLHelper.get_value(lighting, 'extension/ExteriorHolidayLighting/Load[Units="kWh/day"]/Value', :float)
        @holiday_period_begin_month = XMLHelper.get_value(lighting, 'extension/ExteriorHolidayLighting/PeriodBeginMonth', :integer)
        @holiday_period_begin_day = XMLHelper.get_value(lighting, 'extension/ExteriorHolidayLighting/PeriodBeginDayOfMonth', :integer)
        @holiday_period_end_month = XMLHelper.get_value(lighting, 'extension/ExteriorHolidayLighting/PeriodEndMonth', :integer)
        @holiday_period_end_day = XMLHelper.get_value(lighting, 'extension/ExteriorHolidayLighting/PeriodEndDayOfMonth', :integer)
        @holiday_weekday_fractions = XMLHelper.get_value(lighting, 'extension/ExteriorHolidayLighting/WeekdayScheduleFractions', :string)
        @holiday_weekend_fractions = XMLHelper.get_value(lighting, 'extension/ExteriorHolidayLighting/WeekendScheduleFractions', :string)
      else
        @holiday_exists = false
      end
    end
  end

  class CeilingFans < BaseArrayElement
    def add(**kwargs)
      self << CeilingFan.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Lighting/CeilingFan').each do |ceiling_fan|
        self << CeilingFan.new(@hpxml_object, ceiling_fan)
      end
    end
  end

  class CeilingFan < BaseElement
    ATTRS = [:id, :efficiency, :quantity]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.ceiling_fans.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      lighting = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Lighting'])
      ceiling_fan = XMLHelper.add_element(lighting, 'CeilingFan')
      sys_id = XMLHelper.add_element(ceiling_fan, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      if not @efficiency.nil?
        airflow = XMLHelper.add_element(ceiling_fan, 'Airflow')
        XMLHelper.add_element(airflow, 'FanSpeed', 'medium', :string)
        XMLHelper.add_element(airflow, 'Efficiency', @efficiency, :float, @efficiency_isdefaulted)
      end
      XMLHelper.add_element(ceiling_fan, 'Quantity', @quantity, :integer, @quantity_isdefaulted) unless @quantity.nil?
    end

    def from_oga(ceiling_fan)
      @id = HPXML::get_id(ceiling_fan)
      @efficiency = XMLHelper.get_value(ceiling_fan, "Airflow[FanSpeed='medium']/Efficiency", :float)
      @quantity = XMLHelper.get_value(ceiling_fan, 'Quantity', :integer)
    end
  end

  class Pools < BaseArrayElement
    def add(**kwargs)
      self << Pool.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/Pools/Pool').each do |pool|
        self << Pool.new(@hpxml_object, pool)
      end
    end
  end

  class Pool < BaseElement
    ATTRS = [:id, :type, :heater_id, :heater_type, :heater_load_units, :heater_load_value, :heater_usage_multiplier,
             :pump_id, :pump_type, :pump_kwh_per_year, :pump_usage_multiplier,
             :heater_weekday_fractions, :heater_weekend_fractions, :heater_monthly_multipliers,
             :pump_weekday_fractions, :pump_weekend_fractions, :pump_monthly_multipliers]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.pools.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      pools = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'Pools'])
      pool = XMLHelper.add_element(pools, 'Pool')
      sys_id = XMLHelper.add_element(pool, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(pool, 'Type', @type, :string) unless @type.nil?
      if @type != HPXML::TypeNone
        pumps = XMLHelper.add_element(pool, 'PoolPumps')
        pool_pump = XMLHelper.add_element(pumps, 'PoolPump')
        sys_id = XMLHelper.add_element(pool_pump, 'SystemIdentifier')
        if not @pump_id.nil?
          XMLHelper.add_attribute(sys_id, 'id', @pump_id)
        else
          XMLHelper.add_attribute(sys_id, 'id', @id + 'Pump')
        end
        XMLHelper.add_element(pool_pump, 'Type', @pump_type, :string)
        if @pump_type != HPXML::TypeNone
          if not @pump_kwh_per_year.nil?
            load = XMLHelper.add_element(pool_pump, 'Load')
            XMLHelper.add_element(load, 'Units', UnitsKwhPerYear, :string)
            XMLHelper.add_element(load, 'Value', @pump_kwh_per_year, :float, @pump_kwh_per_year_isdefaulted)
          end
          XMLHelper.add_extension(pool_pump, 'UsageMultiplier', @pump_usage_multiplier, :float, @pump_usage_multiplier_isdefaulted) unless @pump_usage_multiplier.nil?
          XMLHelper.add_extension(pool_pump, 'WeekdayScheduleFractions', @pump_weekday_fractions, :string, @pump_weekday_fractions_isdefaulted) unless @pump_weekday_fractions.nil?
          XMLHelper.add_extension(pool_pump, 'WeekendScheduleFractions', @pump_weekend_fractions, :string, @pump_weekend_fractions_isdefaulted) unless @pump_weekend_fractions.nil?
          XMLHelper.add_extension(pool_pump, 'MonthlyScheduleMultipliers', @pump_monthly_multipliers, :string, @pump_monthly_multipliers_isdefaulted) unless @pump_monthly_multipliers.nil?
        end
        heater = XMLHelper.add_element(pool, 'Heater')
        sys_id = XMLHelper.add_element(heater, 'SystemIdentifier')
        if not @heater_id.nil?
          XMLHelper.add_attribute(sys_id, 'id', @heater_id)
        else
          XMLHelper.add_attribute(sys_id, 'id', @id + 'Heater')
        end
        XMLHelper.add_element(heater, 'Type', @heater_type, :string)
        if @heater_type != HPXML::TypeNone
          if (not @heater_load_units.nil?) && (not @heater_load_value.nil?)
            load = XMLHelper.add_element(heater, 'Load')
            XMLHelper.add_element(load, 'Units', @heater_load_units, :string)
            XMLHelper.add_element(load, 'Value', @heater_load_value, :float, @heater_load_value_isdefaulted)
          end
          XMLHelper.add_extension(heater, 'UsageMultiplier', @heater_usage_multiplier, :float, @heater_usage_multiplier_isdefaulted) unless @heater_usage_multiplier.nil?
          XMLHelper.add_extension(heater, 'WeekdayScheduleFractions', @heater_weekday_fractions, :string, @heater_weekday_fractions_isdefaulted) unless @heater_weekday_fractions.nil?
          XMLHelper.add_extension(heater, 'WeekendScheduleFractions', @heater_weekend_fractions, :string, @heater_weekend_fractions_isdefaulted) unless @heater_weekend_fractions.nil?
          XMLHelper.add_extension(heater, 'MonthlyScheduleMultipliers', @heater_monthly_multipliers, :string, @heater_monthly_multipliers_isdefaulted) unless @heater_monthly_multipliers.nil?
        end
      end
    end

    def from_oga(pool)
      @id = HPXML::get_id(pool)
      @type = XMLHelper.get_value(pool, 'Type', :string)
      pool_pump = XMLHelper.get_element(pool, 'PoolPumps/PoolPump')
      if not pool_pump.nil?
        @pump_id = HPXML::get_id(pool_pump)
        @pump_type = XMLHelper.get_value(pool_pump, 'Type', :string)
        @pump_kwh_per_year = XMLHelper.get_value(pool_pump, "Load[Units='#{UnitsKwhPerYear}']/Value", :float)
        @pump_usage_multiplier = XMLHelper.get_value(pool_pump, 'extension/UsageMultiplier', :float)
        @pump_weekday_fractions = XMLHelper.get_value(pool_pump, 'extension/WeekdayScheduleFractions', :string)
        @pump_weekend_fractions = XMLHelper.get_value(pool_pump, 'extension/WeekendScheduleFractions', :string)
        @pump_monthly_multipliers = XMLHelper.get_value(pool_pump, 'extension/MonthlyScheduleMultipliers', :string)
      end
      heater = XMLHelper.get_element(pool, 'Heater')
      if not heater.nil?
        @heater_id = HPXML::get_id(heater)
        @heater_type = XMLHelper.get_value(heater, 'Type', :string)
        @heater_load_units = XMLHelper.get_value(heater, 'Load/Units', :string)
        @heater_load_value = XMLHelper.get_value(heater, 'Load/Value', :float)
        @heater_usage_multiplier = XMLHelper.get_value(heater, 'extension/UsageMultiplier', :float)
        @heater_weekday_fractions = XMLHelper.get_value(heater, 'extension/WeekdayScheduleFractions', :string)
        @heater_weekend_fractions = XMLHelper.get_value(heater, 'extension/WeekendScheduleFractions', :string)
        @heater_monthly_multipliers = XMLHelper.get_value(heater, 'extension/MonthlyScheduleMultipliers', :string)
      end
    end
  end

  class HotTubs < BaseArrayElement
    def add(**kwargs)
      self << HotTub.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/HotTubs/HotTub').each do |hot_tub|
        self << HotTub.new(@hpxml_object, hot_tub)
      end
    end
  end

  class HotTub < BaseElement
    ATTRS = [:id, :type, :heater_id, :heater_type, :heater_load_units, :heater_load_value, :heater_usage_multiplier,
             :pump_id, :pump_type, :pump_kwh_per_year, :pump_usage_multiplier,
             :heater_weekday_fractions, :heater_weekend_fractions, :heater_monthly_multipliers,
             :pump_weekday_fractions, :pump_weekend_fractions, :pump_monthly_multipliers]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.hot_tubs.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      hot_tubs = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'HotTubs'])
      hot_tub = XMLHelper.add_element(hot_tubs, 'HotTub')
      sys_id = XMLHelper.add_element(hot_tub, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(hot_tub, 'Type', @type, :string) unless @type.nil?
      if @type != HPXML::TypeNone
        pumps = XMLHelper.add_element(hot_tub, 'HotTubPumps')
        hot_tub_pump = XMLHelper.add_element(pumps, 'HotTubPump')
        sys_id = XMLHelper.add_element(hot_tub_pump, 'SystemIdentifier')
        if not @pump_id.nil?
          XMLHelper.add_attribute(sys_id, 'id', @pump_id)
        else
          XMLHelper.add_attribute(sys_id, 'id', @id + 'Pump')
        end
        XMLHelper.add_element(hot_tub_pump, 'Type', @pump_type, :string)
        if @pump_type != HPXML::TypeNone
          if not @pump_kwh_per_year.nil?
            load = XMLHelper.add_element(hot_tub_pump, 'Load')
            XMLHelper.add_element(load, 'Units', UnitsKwhPerYear, :string)
            XMLHelper.add_element(load, 'Value', @pump_kwh_per_year, :float, @pump_kwh_per_year_isdefaulted)
          end
          XMLHelper.add_extension(hot_tub_pump, 'UsageMultiplier', @pump_usage_multiplier, :float, @pump_usage_multiplier_isdefaulted) unless @pump_usage_multiplier.nil?
          XMLHelper.add_extension(hot_tub_pump, 'WeekdayScheduleFractions', @pump_weekday_fractions, :string, @pump_weekday_fractions_isdefaulted) unless @pump_weekday_fractions.nil?
          XMLHelper.add_extension(hot_tub_pump, 'WeekendScheduleFractions', @pump_weekend_fractions, :string, @pump_weekend_fractions_isdefaulted) unless @pump_weekend_fractions.nil?
          XMLHelper.add_extension(hot_tub_pump, 'MonthlyScheduleMultipliers', @pump_monthly_multipliers, :string, @pump_monthly_multipliers_isdefaulted) unless @pump_monthly_multipliers.nil?
        end
        heater = XMLHelper.add_element(hot_tub, 'Heater')
        sys_id = XMLHelper.add_element(heater, 'SystemIdentifier')
        if not @heater_id.nil?
          XMLHelper.add_attribute(sys_id, 'id', @heater_id)
        else
          XMLHelper.add_attribute(sys_id, 'id', @id + 'Heater')
        end
        XMLHelper.add_element(heater, 'Type', @heater_type, :string)
        if @heater_type != HPXML::TypeNone
          if (not @heater_load_units.nil?) && (not @heater_load_value.nil?)
            load = XMLHelper.add_element(heater, 'Load')
            XMLHelper.add_element(load, 'Units', @heater_load_units, :string)
            XMLHelper.add_element(load, 'Value', @heater_load_value, :float, @heater_load_value_isdefaulted)
          end
          XMLHelper.add_extension(heater, 'UsageMultiplier', @heater_usage_multiplier, :float, @heater_usage_multiplier_isdefaulted) unless @heater_usage_multiplier.nil?
          XMLHelper.add_extension(heater, 'WeekdayScheduleFractions', @heater_weekday_fractions, :string, @heater_weekday_fractions_isdefaulted) unless @heater_weekday_fractions.nil?
          XMLHelper.add_extension(heater, 'WeekendScheduleFractions', @heater_weekend_fractions, :string, @heater_weekend_fractions_isdefaulted) unless @heater_weekend_fractions.nil?
          XMLHelper.add_extension(heater, 'MonthlyScheduleMultipliers', @heater_monthly_multipliers, :string, @heater_monthly_multipliers_isdefaulted) unless @heater_monthly_multipliers.nil?
        end
      end
    end

    def from_oga(hot_tub)
      @id = HPXML::get_id(hot_tub)
      @type = XMLHelper.get_value(hot_tub, 'Type', :string)
      hot_tub_pump = XMLHelper.get_element(hot_tub, 'HotTubPumps/HotTubPump')
      if not hot_tub_pump.nil?
        @pump_id = HPXML::get_id(hot_tub_pump)
        @pump_type = XMLHelper.get_value(hot_tub_pump, 'Type', :string)
        @pump_kwh_per_year = XMLHelper.get_value(hot_tub_pump, "Load[Units='#{UnitsKwhPerYear}']/Value", :float)
        @pump_usage_multiplier = XMLHelper.get_value(hot_tub_pump, 'extension/UsageMultiplier', :float)
        @pump_weekday_fractions = XMLHelper.get_value(hot_tub_pump, 'extension/WeekdayScheduleFractions', :string)
        @pump_weekend_fractions = XMLHelper.get_value(hot_tub_pump, 'extension/WeekendScheduleFractions', :string)
        @pump_monthly_multipliers = XMLHelper.get_value(hot_tub_pump, 'extension/MonthlyScheduleMultipliers', :string)
      end
      heater = XMLHelper.get_element(hot_tub, 'Heater')
      if not heater.nil?
        @heater_id = HPXML::get_id(heater)
        @heater_type = XMLHelper.get_value(heater, 'Type', :string)
        @heater_load_units = XMLHelper.get_value(heater, 'Load/Units', :string)
        @heater_load_value = XMLHelper.get_value(heater, 'Load/Value', :float)
        @heater_usage_multiplier = XMLHelper.get_value(heater, 'extension/UsageMultiplier', :float)
        @heater_weekday_fractions = XMLHelper.get_value(heater, 'extension/WeekdayScheduleFractions', :string)
        @heater_weekend_fractions = XMLHelper.get_value(heater, 'extension/WeekendScheduleFractions', :string)
        @heater_monthly_multipliers = XMLHelper.get_value(heater, 'extension/MonthlyScheduleMultipliers', :string)
      end
    end
  end

  class PlugLoads < BaseArrayElement
    def add(**kwargs)
      self << PlugLoad.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/MiscLoads/PlugLoad').each do |plug_load|
        self << PlugLoad.new(@hpxml_object, plug_load)
      end
    end
  end

  class PlugLoad < BaseElement
    ATTRS = [:id, :plug_load_type, :kWh_per_year, :frac_sensible, :frac_latent, :usage_multiplier,
             :weekday_fractions, :weekend_fractions, :monthly_multipliers]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.plug_loads.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      misc_loads = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'MiscLoads'])
      plug_load = XMLHelper.add_element(misc_loads, 'PlugLoad')
      sys_id = XMLHelper.add_element(plug_load, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(plug_load, 'PlugLoadType', @plug_load_type, :string) unless @plug_load_type.nil?
      if not @kWh_per_year.nil?
        load = XMLHelper.add_element(plug_load, 'Load')
        XMLHelper.add_element(load, 'Units', UnitsKwhPerYear, :string)
        XMLHelper.add_element(load, 'Value', @kWh_per_year, :float, @kWh_per_year_isdefaulted)
      end
      XMLHelper.add_extension(plug_load, 'FracSensible', @frac_sensible, :float, @frac_sensible_isdefaulted) unless @frac_sensible.nil?
      XMLHelper.add_extension(plug_load, 'FracLatent', @frac_latent, :float, @frac_latent_isdefaulted) unless @frac_latent.nil?
      XMLHelper.add_extension(plug_load, 'UsageMultiplier', @usage_multiplier, :float, @usage_multiplier_isdefaulted) unless @usage_multiplier.nil?
      XMLHelper.add_extension(plug_load, 'WeekdayScheduleFractions', @weekday_fractions, :string, @weekday_fractions_isdefaulted) unless @weekday_fractions.nil?
      XMLHelper.add_extension(plug_load, 'WeekendScheduleFractions', @weekend_fractions, :string, @weekend_fractions_isdefaulted) unless @weekend_fractions.nil?
      XMLHelper.add_extension(plug_load, 'MonthlyScheduleMultipliers', @monthly_multipliers, :string, @monthly_multipliers_isdefaulted) unless @monthly_multipliers.nil?
    end

    def from_oga(plug_load)
      @id = HPXML::get_id(plug_load)
      @plug_load_type = XMLHelper.get_value(plug_load, 'PlugLoadType', :string)
      @kWh_per_year = XMLHelper.get_value(plug_load, "Load[Units='#{UnitsKwhPerYear}']/Value", :float)
      @frac_sensible = XMLHelper.get_value(plug_load, 'extension/FracSensible', :float)
      @frac_latent = XMLHelper.get_value(plug_load, 'extension/FracLatent', :float)
      @usage_multiplier = XMLHelper.get_value(plug_load, 'extension/UsageMultiplier', :float)
      @weekday_fractions = XMLHelper.get_value(plug_load, 'extension/WeekdayScheduleFractions', :string)
      @weekend_fractions = XMLHelper.get_value(plug_load, 'extension/WeekendScheduleFractions', :string)
      @monthly_multipliers = XMLHelper.get_value(plug_load, 'extension/MonthlyScheduleMultipliers', :string)
    end
  end

  class FuelLoads < BaseArrayElement
    def add(**kwargs)
      self << FuelLoad.new(@hpxml_object, **kwargs)
    end

    def from_oga(hpxml)
      return if hpxml.nil?

      XMLHelper.get_elements(hpxml, 'Building/BuildingDetails/MiscLoads/FuelLoad').each do |fuel_load|
        self << FuelLoad.new(@hpxml_object, fuel_load)
      end
    end
  end

  class FuelLoad < BaseElement
    ATTRS = [:id, :fuel_load_type, :fuel_type, :therm_per_year, :frac_sensible, :frac_latent, :usage_multiplier,
             :weekday_fractions, :weekend_fractions, :monthly_multipliers]
    attr_accessor(*ATTRS)

    def delete
      @hpxml_object.fuel_loads.delete(self)
    end

    def check_for_errors
      errors = []
      return errors
    end

    def to_oga(doc)
      return if nil?

      misc_loads = XMLHelper.create_elements_as_needed(doc, ['HPXML', 'Building', 'BuildingDetails', 'MiscLoads'])
      fuel_load = XMLHelper.add_element(misc_loads, 'FuelLoad')
      sys_id = XMLHelper.add_element(fuel_load, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', @id)
      XMLHelper.add_element(fuel_load, 'FuelLoadType', @fuel_load_type, :string) unless @fuel_load_type.nil?
      if not @therm_per_year.nil?
        load = XMLHelper.add_element(fuel_load, 'Load')
        XMLHelper.add_element(load, 'Units', UnitsThermPerYear, :string)
        XMLHelper.add_element(load, 'Value', @therm_per_year, :float, @therm_per_year_isdefaulted)
      end
      XMLHelper.add_element(fuel_load, 'FuelType', @fuel_type, :string) unless @fuel_type.nil?
      XMLHelper.add_extension(fuel_load, 'FracSensible', @frac_sensible, :float, @frac_sensible_isdefaulted) unless @frac_sensible.nil?
      XMLHelper.add_extension(fuel_load, 'FracLatent', @frac_latent, :float, @frac_latent_isdefaulted) unless @frac_latent.nil?
      XMLHelper.add_extension(fuel_load, 'UsageMultiplier', @usage_multiplier, :float, @usage_multiplier_isdefaulted) unless @usage_multiplier.nil?
      XMLHelper.add_extension(fuel_load, 'WeekdayScheduleFractions', @weekday_fractions, :string, @weekday_fractions_isdefaulted) unless @weekday_fractions.nil?
      XMLHelper.add_extension(fuel_load, 'WeekendScheduleFractions', @weekend_fractions, :string, @weekend_fractions_isdefaulted) unless @weekend_fractions.nil?
      XMLHelper.add_extension(fuel_load, 'MonthlyScheduleMultipliers', @monthly_multipliers, :string, @monthly_multipliers_isdefaulted) unless @monthly_multipliers.nil?
    end

    def from_oga(fuel_load)
      @id = HPXML::get_id(fuel_load)
      @fuel_load_type = XMLHelper.get_value(fuel_load, 'FuelLoadType', :string)
      @therm_per_year = XMLHelper.get_value(fuel_load, "Load[Units='#{UnitsThermPerYear}']/Value", :float)
      @fuel_type = XMLHelper.get_value(fuel_load, 'FuelType', :string)
      @frac_sensible = XMLHelper.get_value(fuel_load, 'extension/FracSensible', :float)
      @frac_latent = XMLHelper.get_value(fuel_load, 'extension/FracLatent', :float)
      @usage_multiplier = XMLHelper.get_value(fuel_load, 'extension/UsageMultiplier', :float)
      @weekday_fractions = XMLHelper.get_value(fuel_load, 'extension/WeekdayScheduleFractions', :string)
      @weekend_fractions = XMLHelper.get_value(fuel_load, 'extension/WeekendScheduleFractions', :string)
      @monthly_multipliers = XMLHelper.get_value(fuel_load, 'extension/MonthlyScheduleMultipliers', :string)
    end
  end

  def _create_oga_document()
    doc = XMLHelper.create_doc(version = '1.0', encoding = 'UTF-8')
    hpxml = XMLHelper.add_element(doc, 'HPXML')
    XMLHelper.add_attribute(hpxml, 'xmlns', 'http://hpxmlonline.com/2019/10')
    XMLHelper.add_attribute(hpxml, 'xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance')
    XMLHelper.add_attribute(hpxml, 'xsi:schemaLocation', 'http://hpxmlonline.com/2019/10')
    XMLHelper.add_attribute(hpxml, 'schemaVersion', '3.0')
    return doc
  end

  def collapse_enclosure_surfaces()
    # Collapses like surfaces into a single surface with, e.g., aggregate surface area.
    # This can significantly speed up performance for HPXML files with lots of individual
    # surfaces (e.g., windows).

    surf_types = { roofs: @roofs,
                   walls: @walls,
                   rim_joists: @rim_joists,
                   foundation_walls: @foundation_walls,
                   frame_floors: @frame_floors,
                   slabs: @slabs,
                   windows: @windows,
                   skylights: @skylights,
                   doors: @doors }

    attrs_to_ignore = [:id,
                       :insulation_id,
                       :perimeter_insulation_id,
                       :under_slab_insulation_id,
                       :area,
                       :exposed_perimeter]

    # Look for pairs of surfaces that can be collapsed
    surf_types.each do |surf_type, surfaces|
      for i in 0..surfaces.size - 1
        surf = surfaces[i]
        next if surf.nil?

        for j in (surfaces.size - 1).downto(i + 1)
          surf2 = surfaces[j]
          next if surf2.nil?

          match = true
          surf.class::ATTRS.each do |attribute|
            next if attribute.to_s.end_with? '_isdefaulted'
            next if attrs_to_ignore.include? attribute
            next if (surf_type == :foundation_walls) && (attribute == :azimuth) # Azimuth of foundation walls is irrelevant
            next if surf.send(attribute) == surf2.send(attribute)

            match = false
            break
          end
          next unless match

          # Update values
          if (not surf.area.nil?) && (not surf2.area.nil?)
            surf.area += surf2.area
          end
          if (surf_type == :slabs) && (not surf.exposed_perimeter.nil?) && (not surf2.exposed_perimeter.nil?)
            surf.exposed_perimeter += surf2.exposed_perimeter
          end

          # Update subsurface idrefs as appropriate
          (@windows + @doors).each do |subsurf|
            next unless subsurf.wall_idref == surf2.id

            subsurf.wall_idref = surf.id
          end
          @skylights.each do |subsurf|
            next unless subsurf.roof_idref == surf2.id

            subsurf.roof_idref = surf.id
          end

          # Remove old surface
          surfaces[j].delete
        end
      end
    end
  end

  def delete_tiny_surfaces()
    (@rim_joists + @walls + @foundation_walls + @frame_floors + @roofs + @windows + @skylights + @doors + @slabs).reverse_each do |surface|
      next if surface.area.nil? || (surface.area > 1.0)

      surface.delete
    end
  end

  def delete_adiabatic_subsurfaces()
    @doors.reverse_each do |door|
      next if door.wall.nil?
      next if door.wall.exterior_adjacent_to != HPXML::LocationOtherHousingUnit

      door.delete
    end
    @windows.reverse_each do |window|
      next if window.wall.nil?
      next if window.wall.exterior_adjacent_to != HPXML::LocationOtherHousingUnit

      window.delete
    end
  end

  def validate_against_schematron(schematron_validators: [])
    # ----------------------------- #
    # Perform Schematron validation #
    # ----------------------------- #

    if not schematron_validators.empty?
      errors, warnings = Validator.run_validators(@doc, schematron_validators)
    else
      errors = []
      warnings = []
    end

    errors.map! { |e| "#{@hpxml_path}: #{e}" }
    warnings.map! { |w| "#{@hpxml_path}: #{w}" }

    return errors, warnings
  end

  def check_for_errors()
    errors = []

    # ------------------------------- #
    # Check for errors within objects #
    # ------------------------------- #

    # Ask objects to check for errors
    self.class::HPXML_ATTRS.each do |attribute|
      hpxml_obj = send(attribute)
      if not hpxml_obj.respond_to? :check_for_errors
        fail "Need to add 'check_for_errors' method to #{hpxml_obj.class} class."
      end

      errors += hpxml_obj.check_for_errors
    end

    # ------------------------------- #
    # Check for errors across objects #
    # ------------------------------- #

    # FUTURE: Move these to EPvalidator.xml

    # Check for globally unique SystemIdentifier IDs and empty IDs
    sys_ids = {}
    self.class::HPXML_ATTRS.each do |attribute|
      hpxml_obj = send(attribute)
      next unless hpxml_obj.is_a? HPXML::BaseArrayElement

      hpxml_obj.each do |obj|
        next unless obj.respond_to? :id

        sys_ids[obj.id] = 0 if sys_ids[obj.id].nil?
        sys_ids[obj.id] += 1

        errors << "Empty SystemIdentifier ID ('#{obj.id}') detected for #{attribute}." if !obj.id || obj.id.size == 0
      end
    end
    sys_ids.each do |sys_id, cnt|
      errors << "Duplicate SystemIdentifier IDs detected for '#{sys_id}'." if cnt > 1
    end

    # Check sum of HVAC FractionCoolLoadServeds <= 1
    if total_fraction_cool_load_served > 1.01 # Use 1.01 in case of rounding
      errors << "Expected FractionCoolLoadServed to sum to <= 1, but calculated sum is #{total_fraction_cool_load_served.round(2)}."
    end

    # Check sum of HVAC FractionHeatLoadServeds <= 1
    if total_fraction_heat_load_served > 1.01 # Use 1.01 in case of rounding
      errors << "Expected FractionHeatLoadServed to sum to <= 1, but calculated sum is #{total_fraction_heat_load_served.round(2)}."
    end

    # Check sum of dehumidifier FractionDehumidificationLoadServed <= 1
    total_fraction_dehum_load_served = @dehumidifiers.map { |d| d.fraction_served }.sum(0.0)
    if total_fraction_dehum_load_served > 1.01 # Use 1.01 in case of rounding
      errors << "Expected FractionDehumidificationLoadServed to sum to <= 1, but calculated sum is #{total_fraction_dehum_load_served.round(2)}."
    end

    # Check sum of HVAC FractionDHWLoadServed == 1
    frac_dhw_load = @water_heating_systems.map { |dhw| dhw.fraction_dhw_load_served.to_f }.sum(0.0)
    if (frac_dhw_load > 0) && ((frac_dhw_load < 0.99) || (frac_dhw_load > 1.01)) # Use 0.99/1.01 in case of rounding
      errors << "Expected FractionDHWLoadServed to sum to 1, but calculated sum is #{frac_dhw_load.round(2)}."
    end

    # Check sum of Ducts FractionDuctArea == 1
    @hvac_distributions.each do |hvac_dist|
      [HPXML::DuctTypeSupply, HPXML::DuctTypeReturn].each do |duct_type|
        ducts_with_fractions = hvac_dist.ducts.select { |du| du.duct_type == duct_type && !du.duct_fraction_area.nil? }
        next unless ducts_with_fractions.size > 0

        ducts_frac_area = ducts_with_fractions.map { |du| Float(du.duct_fraction_area) }.sum()
        if (ducts_frac_area < 0.99) || (ducts_frac_area > 1.01) # Use 0.99/1.01 in case of rounding
          errors << "Expected FractionDuctArea for Ducts (of type #{duct_type}) to sum to 1, but calculated sum is #{ducts_frac_area.round(2)}."
        end
      end
    end

    # Check sum of lighting fractions in a location <= 1
    ltg_fracs = {}
    @lighting_groups.each do |lighting_group|
      next if lighting_group.location.nil? || lighting_group.fraction_of_units_in_location.nil?

      ltg_fracs[lighting_group.location] = 0 if ltg_fracs[lighting_group.location].nil?
      ltg_fracs[lighting_group.location] += lighting_group.fraction_of_units_in_location
    end
    ltg_fracs.each do |location, sum|
      next if sum <= 1.01 # Use 1.01 in case of rounding

      errors << "Sum of fractions of #{location} lighting (#{sum}) is greater than 1."
    end

    # Check for HVAC systems referenced by multiple water heating systems
    hvac_systems.each do |hvac_system|
      num_attached = 0
      @water_heating_systems.each do |water_heating_system|
        next if water_heating_system.related_hvac_idref.nil?
        next unless hvac_system.id == water_heating_system.related_hvac_idref

        num_attached += 1
      end
      next if num_attached <= 1

      errors << "RelatedHVACSystem '#{hvac_system.id}' is attached to multiple water heating systems."
    end

    # Check for the sum of CFA served by distribution systems <= CFA
    if not @building_construction.conditioned_floor_area.nil?
      air_distributions = @hvac_distributions.select { |dist| dist if HPXML::HVACDistributionTypeAir == dist.distribution_system_type }
      heating_dist = []
      cooling_dist = []
      air_distributions.each do |dist|
        heating_systems = dist.hvac_systems.select { |sys| sys if (sys.respond_to? :fraction_heat_load_served) && (sys.fraction_heat_load_served.to_f > 0) }
        cooling_systems = dist.hvac_systems.select { |sys| sys if (sys.respond_to? :fraction_cool_load_served) && (sys.fraction_cool_load_served.to_f > 0) }
        if heating_systems.size > 0
          heating_dist << dist
        end
        if cooling_systems.size > 0
          cooling_dist << dist
        end
      end
      heating_total_dist_cfa_served = heating_dist.map { |htg_dist| htg_dist.conditioned_floor_area_served.to_f }.sum(0.0)
      cooling_total_dist_cfa_served = cooling_dist.map { |clg_dist| clg_dist.conditioned_floor_area_served.to_f }.sum(0.0)
      if (heating_total_dist_cfa_served > @building_construction.conditioned_floor_area + 1.0) # Allow 1 ft2 of tolerance
        errors << 'The total conditioned floor area served by the HVAC distribution system(s) for heating is larger than the conditioned floor area of the building.'
      end
      if (cooling_total_dist_cfa_served > @building_construction.conditioned_floor_area + 1.0) # Allow 1 ft2 of tolerance
        errors << 'The total conditioned floor area served by the HVAC distribution system(s) for cooling is larger than the conditioned floor area of the building.'
      end
    end

    # Check for objects referencing SFA/MF spaces where the building type is not SFA/MF
    if [ResidentialTypeSFD, ResidentialTypeManufactured].include? @building_construction.residential_facility_type
      mf_spaces = [LocationOtherHeatedSpace, LocationOtherHousingUnit, LocationOtherMultifamilyBufferSpace, LocationOtherNonFreezingSpace]
      (@roofs + @rim_joists + @walls + @foundation_walls + @frame_floors + @slabs).each do |surface|
        if mf_spaces.include? surface.interior_adjacent_to
          errors << "The building is of type '#{@building_construction.residential_facility_type}' but the surface '#{surface.id}' is adjacent to Attached/Multifamily space '#{surface.interior_adjacent_to}'."
        end
        if mf_spaces.include? surface.exterior_adjacent_to
          errors << "The building is of type '#{@building_construction.residential_facility_type}' but the surface '#{surface.id}' is adjacent to Attached/Multifamily space '#{surface.exterior_adjacent_to}'."
        end
      end
      (@water_heating_systems + @clothes_washers + @clothes_dryers + @dishwashers + @refrigerators + @cooking_ranges).each do |object|
        if mf_spaces.include? object.location
          errors << "The building is of type '#{@building_construction.residential_facility_type}' but the object '#{object.id}' is located in Attached/Multifamily space '#{object.location}'."
        end
      end
      @hvac_distributions.each do |hvac_distribution|
        hvac_distribution.ducts.each do |duct|
          if mf_spaces.include? duct.duct_location
            errors << "The building is of type '#{@building_construction.residential_facility_type}' but the HVAC distribution '#{hvac_distribution.id}' has a duct located in Attached/Multifamily space '#{duct.duct_location}'."
          end
        end
      end
    end

    # Check for correct PrimaryIndicator values across all refrigerators
    if @refrigerators.size > 1
      primary_indicators = @refrigerators.select { |r| r.primary_indicator }.size
      if primary_indicators > 1
        errors << 'More than one refrigerator designated as the primary.'
      elsif primary_indicators == 0
        errors << 'Could not find a primary refrigerator.'
      end
    end

    # Check for at most 1 shared heating system and 1 shared cooling system
    num_htg_shared = 0
    num_clg_shared = 0
    (@heating_systems + @heat_pumps).each do |hvac_system|
      next unless hvac_system.is_shared_system

      num_htg_shared += 1
    end
    (@cooling_systems + @heat_pumps).each do |hvac_system|
      next unless hvac_system.is_shared_system

      num_clg_shared += 1
    end
    if num_htg_shared > 1
      errors << 'More than one shared heating system found.'
    end
    if num_clg_shared > 1
      errors << 'More than one shared cooling system found.'
    end

    errors.map! { |e| "#{@hpxml_path}: #{e}" }

    return errors
  end

  def self.conditioned_locations
    return [HPXML::LocationLivingSpace,
            HPXML::LocationBasementConditioned,
            HPXML::LocationOtherHousingUnit]
  end

  def self.is_conditioned(surface)
    return conditioned_locations.include?(surface.interior_adjacent_to)
  end

  def self.is_adiabatic(surface)
    if surface.exterior_adjacent_to == surface.interior_adjacent_to
      # E.g., wall between unit crawlspace and neighboring unit crawlspace
      return true
    elsif conditioned_locations.include?(surface.interior_adjacent_to) &&
          conditioned_locations.include?(surface.exterior_adjacent_to)
      # E.g., frame floor between living space and conditioned basement, or
      # wall between living space and "other housing unit"
      return true
    end

    return false
  end

  def self.is_thermal_boundary(surface)
    # Returns true if the surface is between conditioned space and outside/ground/unconditioned space.
    # Note: The location of insulation is not considered here, so an insulated foundation wall of an
    # unconditioned basement, for example, returns false.
    interior_conditioned = conditioned_locations.include? surface.interior_adjacent_to
    exterior_conditioned = conditioned_locations.include? surface.exterior_adjacent_to
    return (interior_conditioned != exterior_conditioned)
  end

  def self.get_id(parent, element_name = 'SystemIdentifier')
    return XMLHelper.get_attribute_value(XMLHelper.get_element(parent, element_name), 'id')
  end

  def self.get_idref(element)
    return XMLHelper.get_attribute_value(element, 'idref')
  end

  def self.check_dates(str, begin_month, begin_day, end_month, end_day)
    errors = []

    # Check for valid months
    valid_months = (1..12).to_a

    if not begin_month.nil?
      if not valid_months.include? begin_month
        errors << "#{str} Begin Month (#{begin_month}) must be one of: #{valid_months.join(', ')}."
      end
    end

    if not end_month.nil?
      if not valid_months.include? end_month
        errors << "#{str} End Month (#{end_month}) must be one of: #{valid_months.join(', ')}."
      end
    end

    # Check for valid days
    months_days = { [1, 3, 5, 7, 8, 10, 12] => (1..31).to_a, [4, 6, 9, 11] => (1..30).to_a, [2] => (1..28).to_a }
    months_days.each do |months, valid_days|
      if (not begin_day.nil?) && (months.include? begin_month)
        if not valid_days.include? begin_day
          errors << "#{str} Begin Day of Month (#{begin_day}) must be one of: #{valid_days.join(', ')}."
        end
      end
      next unless (not end_day.nil?) && (months.include? end_month)

      if not valid_days.include? end_day
        errors << "#{str} End Day of Month (#{end_day}) must be one of: #{valid_days.join(', ')}."
      end
    end

    return errors
  end
end
