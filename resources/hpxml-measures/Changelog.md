## OpenStudio-HPXML v1.3.0 (Pending)

__New Features__
- Updates to OpenStudio 3.2.1/EnergyPlus 9.5.0.
- **Breaking change**: Replaces ClothesDryer `extension/IsVented` and `extension/VentedFlowRate` with `Vented` and `VentedFlowRate`.
- Adds an `--ep-input-format` argument to run_simulation.rb to choose epJSON as the EnergyPlus input file format instead of IDF.
- Allows non-zero refrigerant charge defect ratios for ground source heat pumps.
- Allows `HeatingSeason` & `CoolingSeason` to be specified for defining heating and cooling equipment availability.
- Revises shared mechanical ventilation preconditioning control logic to operate less often.
- Expands choices allowed for `Siding` (Wall/RimJoist) and `RoofType` (Roof) elements.
- Allows `Ducts/FractionDuctArea` to be provided instead of `Ducts/DuctSurfaceArea`.
- Allows CEER (Combined Energy Efficiency Ratio) efficiency unit for room AC.
- Allows "none" for wall/rim joist siding.
- Allows interior finish inputs (e.g., 0.5" drywall) for walls, ceilings, and roofs.
- Allows `Orientation` to be provided instead of `Azimuth` for all applicable surfaces, PV systems, and solar thermal systems.
- Allows `Length` to be provided instead of `Area` for foundation walls.
- Allows additional fuel types for generators.
- Allows more defaulting (optional inputs):
  - HVAC/DHW system efficiency (by age).
  - Mechanical ventilation fan power (by type).
  - Color (solar absorptance) for walls, roofs, and rim joists.
  - Foundation wall distance to top/bottom of insulation.
  - Door azimuth.
  - Radiant barrier grade.
- For water heaters w/ UEF, allows `UsageBin` instead of `FirstHourRating` (or defaults if neither provided).
- Switches to the EnergyPlus Fan:SystemModel object for all HVAC systems.
- Introduces a small amount of infiltration for unvented spaces.
- Removes error-check for number of bedrooms based on conditioned floor area, per RESNET guidance.
- Updates the reporting measure to register all outputs from the annual CSV with the OS runner (for use in, e.g., PAT).

__Bugfixes__
- Improves ground reflectance when there is shading of windows/skylights.
- Fixes heating fan power for single-stage systems that have different heating/cooling airflow rates.
- Negative `DistanceToTopOfInsulation` values are now disallowed in the EPvalidator schematron doc.

## OpenStudio-HPXML v1.2.0

__New Features__
- **Breaking change**: Heating/cooling component loads no longer calculated by default for faster performance; use `--add-component-loads` argument if desired.
- **Breaking change**: Replaces `Site/extension/ShelterCoefficient` with `Site/ShieldingofHome`.
- Allows `DuctLeakageMeasurement` & `ConditionedFloorAreaServed` to not be specified for ductless fan coil systems; **Breaking change**: `AirDistributionType` is now required for all air distribution systems.
- Allows `Slab/ExposedPerimeter` to be zero.
- Removes `ClothesDryer/ControlType` from being a required input, it is not used.
- Switches room air conditioner model to use Cutler performance curves.
- Relaxes tolerance for duct leakage to outside warning when ducts solely in conditioned space.
- Removes limitation that a shared water heater serving a shared laundry room can't also serve dwelling unit fixtures (i.e., FractionDHWLoadServed is no longer required to be zero).
- Adds IDs to schematron validation errors/warnings when possible.
- Moves additional error-checking from the ruby measure to the schematron validator. 

__Bugfixes__
- Fixes room air conditioner performance curve.
- Fixes ruby error if elements (e.g., `SystemIdentifier`) exist without the proper 'id'/'idref' attribute.
- Fixes error if boiler/GSHP pump power is zero
- Fixes possible "Electricity category end uses do not sum to total" error due to boiler pump energy.
- Fixes possible "Construction R-value ... does not match Assembly R-value" error for highly insulated enclosure elements.
- Adds error-checking for negative SEEReq results for shared cooling systems.
- Adds more detail to error messages regarding the wrong data type in the HPXML file.
- Prevents a solar hot water system w/ SolarFraction=1.

## OpenStudio-HPXML v1.1.0

__New Features__
- **Breaking change**: `Type` is now a required input for dehumidifiers; can be "portable" or "whole-home".
- **Breaking change**: `Location` is now a required input for dehumidifiers; must be "living space" as dehumidifiers are currently modeled as located in living space.
- **Breaking change**: `Type` is now a required input for Pool, PoolPump, HotTub, and HotTubPump.
- **Breaking change**: Both supply and return duct leakage to outside are now required inputs for AirDistribution systems.
- **Breaking change**: Simplifies inputs for fan coils and water loop heat pumps by A) removing HydronicAndAirDistribution element and B) moving WLHP inputs from extension elements to HeatPump element.
- Allows modeling airflow/charge defects for air conditioners, heat pumps, and furnaces (RESNET Standard 310).
- Allows modeling *multiple* dehumidifiers (previously only one allowed).
- Allows modeling generators (generic on-site power production).
- Allows detailed heating/cooling setpoints to be specified: 24-hour weekday & weekend values.
- Allows modeling window/skylight *exterior* shading via summer/winter shading coefficients.
- Allows JSON annual/timeseries output files to be generated instead of CSV. **Breaking change**: For CSV outputs, the first two sections in the results_annual.csv file are now prefixed with "Fuel Use:" and "End Use:", respectively.
- Allows more defaulting (optional inputs) for a variety of HPXML elements.
- Allows requesting timeseries unmet heating/cooling loads.
- Allows skipping schema/schematron validation (for speed); should only be used if the HPXML was already validated upstream.
- Allows HPXML files w/ multiple `Building` elements; requires providing the ID of the single building to be simulated.
- Includes hot water loads (in addition to heating/cooling loads) when timeseries total loads are requested.
- The `in.xml` HPXML file is now always produced for inspection of default values (e.g., autosized HVAC capacities). **Breaking change**: The `output_dir` HPXMLtoOpenStudio measure argument is now required.
- Overhauls documentation to be more comprehensive and standardized.
- `run_simulation.rb` now returns exit code 1 if not successful (i.e., either invalid inputs or simulation fails).

__Bugfixes__
- Improved modeling of window/skylight interior shading -- better reflects shading coefficient inputs.
- Adds error-checking on the HPXML schemaVersion.
- Adds various error-checking to the schematron validator.
- Adds error-checking for empty IDs in the HPXML file.
- Fixes heat pump water heater fan energy not included in SimulationOutputReport outputs.
- Fixes possibility of incorrect "A neighbor building has an azimuth (XXX) not equal to the azimuth of any wall" error.
- Fixes possibility of errors encountered before schematron validation has occurred.
- Small bugfixes related to basement interior surface solar absorptances.
- Allows NumberofConditionedFloors/NumberofConditionedFloorsAboveGrade to be non-integer values per the HPXML schema.
- HVAC sizing design load improvements for floors above crawlspaces/basements, walls, ducts, and heat pumps.
- Now recognizes Type="none" to prevent modeling of pools and hot tubs (pumps and heaters).
- Fixes error for overhangs with zero depth.
- Fixes possible error where the normalized flue height for the AIM-2 infiltration model is negative.
- Slight adjustment of default water heater recovery efficiency equation to prevent errors from values being too high.
- Fixes schematron file not being valid per ISO Schematron standard.

## OpenStudio-HPXML v1.0.0

__New Features__
- Updates to OpenStudio 3.1.0/EnergyPlus 9.4.0.
- **Breaking change**: Deprecates `WeatherStation/WMO` HPXML input, use `WeatherStation/extension/EPWFilePath` instead; also removes `weather_dir` argument from HPXMLtoOpenStudio measure.
- Implements water heater Uniform Energy Factor (UEF) model; replaces RESNET UEF->EF regression. **Breaking change**: `FirstHourRating` is now a required input for storage water heaters when UEF is provided.
- Adds optional HPXML fan power inputs for most HVAC system types. **Breaking change**: Removes ElectricAuxiliaryEnergy input for non-boiler heating systems.
- Uses air-source heat pump cooling performance curves for central air conditioners.
- Updates rated fan power assumption for mini-split heat pump models.
- Allows coal fuel type for non-boiler heating systems.
- Accommodates common walls adjacent to unconditioned space by using HPXML surfaces where InteriorAdjacentTo == ExteriorAdjacentTo.
- Adds optional HPXML inputs to define whether a clothes dryer is vented and its ventilation rate.
- Adds optional HPXML input for `SimulationControl/CalendarYear` for TMY weather files.
- Schematron validation improvements.
- Adds some HPXML XSD schema validation and additional error-checking.
- Various small updates to ASHRAE 140 test files.
- Reduces number of EnergyPlus output files produced by using new OutputControlFiles object.
- Release packages now include ASHRAE 140 test files/results.

__Bugfixes__
- EnergyPlus 9.4.0 fix for negative window solar absorptances at certain hours.
- Fixes airflow timeseries outputs to be averaged instead of summed.
- Updates HVAC sizing methodology for slab-on-grade foundation types.
- Fixes an error that could prevent schematron validation errors from being produced.
- Skips weather caching if filesystem is read only.

## OpenStudio-HPXML v0.11.0 Beta

__New Features__
- New [Schematron](http://schematron.com) validation (EPvalidator.xml) replaces custom ruby validation (EPvalidator.rb)
- **[Breaking Change]** `BuildingConstruction/ResidentialFacilityType` ("single-family detached", "single-family attached", "apartment unit", or "manufactured home") is a required input
- Ability to model shared systems for Attached/Multifamily dwelling units
  - Shared HVAC systems (cooling towers, chillers, central boilers, water loop heat pumps, fan coils, ground source heat pumps on shared hydronic circulation loops)
  - Shared water heaters serving either A) multiple dwelling units' service hot water or B) a shared laundry/equipment room, as well as hot water recirculation systems
  - Shared appliances (e.g., clothes dryer in a shared laundry room)
  - Shared hot water recirculation systems
  - Shared ventilation systems (optionally with preconditioning equipment and recirculation)
  - Shared PV systems
  - **[Breaking Change]** Appliances located in MF spaces (i.e., "other") must now be specified in more detail (i.e., "other heated space", "other non-freezing space", "other multifamily buffer space", or "other housing unit")
- Enclosure
  - New optional inputs: `Roof/RoofType`, `Wall/Siding`, and `RimJoist/Siding`
  - New optional inputs: `Skylight/InteriorShading/SummerShadingCoefficient` and `Skylight/InteriorShading/SummerShadingCoefficient`
  - New optional inputs: `Roof/RoofColor`, `Wall/Color`, and `RimJoist/Color` can be provided instead of `SolarAbsorptance`
  - New optional input to specify presence of flue/chimney, which results in increased infiltration
  - Allows adobe wall type
  - Allows `AirInfiltrationMeasurement/HousePressure` to be any value (previously required to be 50 Pa)
  - **[Breaking Change]** `Roof/RadiantBarrierGrade` input now required when there is a radiant barrier
- HVAC
  - Adds optional high-level HVAC autosizing controls
    - `AllowIncreasedFixedCapacities`: Describes how HVAC equipment with fixed capacities are handled. If true, the maximum of the user-specified fixed capacity and the heating/cooling design load will be used to reduce potential for unmet loads. Defaults to false.
    - `UseMaxLoadForHeatPumps`: Describes how autosized heat pumps are handled. If true, heat pumps are sized based on the maximum of heating and cooling design loads. If false, heat pumps are sized per ACCA Manual J/S based on cooling design loads with some oversizing allowances for heating design loads. Defaults to true.
  - Additional HVAC types: mini-split air conditioners and fixed (non-portable) space heaters
  - Adds optional inputs for ground-to-air heat pumps: `extension/PumpPowerWattsPerTon` and `extension/FanPowerWattsPerCFM`
- Ventilation
  - Allows _multiple_ whole-home ventilation, spot ventilation, and/or whole house fans
- Appliances & Plug Loads
  - Allows _multiple_ `Refrigerator` and `Freezer`
  - Allows `Pool`, `HotTub`, `PlugLoad` of type "electric vehicle charging" and "well pump", and `FuelLoad` of type "grill", "lighting", and "fireplace"
  - **[Breaking Change]** "other" and "TV other" plug loads now required
- Lighting
  - Allows lighting schedules and holiday lighting
- **[Breaking Change]** For hydronic distributions, `HydronicDistributionType` is now required
- **[Breaking Change]** For DSE distributions, `AnnualHeatingDistributionSystemEfficiency` and `AnnualCoolingDistributionSystemEfficiency` are both always required
- Allows more HPXML fuel types to be used for HVAC, water heating, appliances, etc.
- New inputs to define Daylight Saving period; defaults to enabled
- Adds more reporting of warnings/errors to run.log

__Bugfixes__
- Fixes pump energy for boilers and ground source heat pumps
- Fixes incorrect gallons of hot water use reported when there are multiple water heaters
- No longer report unmet load for buildings where the HVAC system only meets part of the load (e.g., room AC serving 33% of the load)
- Schedule bugfix for leap years

## OpenStudio-HPXML v0.10.0 Beta

__New Features__
- Dwelling units of single-family attached/multifamily buildings:
  - Adds new generic space types "other heated space", "other multifamily buffer space", and "other non-freezing space" for surface `ExteriorAdjacentTo` elements. "other housing unit", i.e. adiabatic surfaces, was already supported.
  - **[Breaking Change]** For `FrameFloors`, replaces "other housing unit above" and "other housing unit below" enumerations with "other housing unit". All four "other ..." spaces must have an `extension/OtherSpaceAboveOrBelow` property set to either "above" or "below".
  - Allows ducts and water heaters to be located in all "other ..." spaces.
  - Allows all appliances to be located in "other", in which internal gains are neglected.
- Allows `Fireplace` and `FloorFurnace` for heating system types.
- Allows "exterior wall", "under slab", and "roof deck" for `DuctLocation`.
- Allows "wood" and "wood pellets" as fuel types for additional HVAC systems, water heaters, and appliances.
- Allows `Location` to be provided for `Dishwasher` and `CookingRange`.
- Allows `BuildingSummary/Site/SiteType` ("urban", "suburban", or "rural") to be provided.
- Allows user-specified `Refrigerator` and `CookingRange` schedules to be provided.
- HVAC capacity elements are no longer required; if not provided, ACCA Manual J autosizing calculations will be used (-1 can continue to be used for capacity elements but is discouraged).
- Duct locations/areas can be defaulted by specifying supply/return `Duct` elements without `DuctSurfaceArea` and `DuctLocation`. `HVACDistribution/DistributionSystemType/AirDistribution/NumberofReturnRegisters` can be optionally provided to inform the default duct area calculations.
- **[Breaking Change]** Lighting inputs now use `LightingType[LightEmittingDiode | CompactFluorescent | FluorescentTube]` instead of `ThirdPartyCertification="ERI Tier I" or ThirdPartyCertification="ERI Tier II"`.
- **[Breaking Change]** `HVACDistribution/ConditionedFloorAreaServed` is now required for air distribution systems.
- **[Breaking Change]** Infiltration and attic ventilation specified using natural air changes per hour now uses `ACHnatural` instead of `extension/ConstantACHnatural`.
- **[Breaking Change]** The optional `PerformanceAdjustment` input for instantaneous water heaters is now treated as a performance multiplier (e.g., 0.92) instead of derate (e.g., 0.08).
- Adds ASHRAE 140 Class II test files.
- SimulationOutputReport reporting measure:
  - New optional timeseries outputs:  airflows (e.g., infiltration, mechanical ventilation, natural ventilation, whole house fan) and weather (e.g., temperatures, wind speed, solar).
  - Timeseries frequency can now be set to 'none' as an alternative to setting all include_timeseries_foo variables to false.
  - **[Breaking Change]** Renames "Wood" to "Wood Cord" to better distinguish from "Wood Pellets".
- Modeling improvements:
  - Improved calculation for infiltration height
  - Infiltration & mechanical ventilation now combined using ASHRAE 62.2 Normative Appendix C.
- Runtime improvements: 
  - Optimized ruby require calls.
  - Skip ViewFactor calculations when not needed (i.e., no conditioned basement).
- Error-checking:
  - Adds more space type-specific error checking of adjacent surfaces.
  - Adds additional HPXML datatype checks.
  - Adds a warning if a `HVACDistribution` system has ducts entirely within conditioned space and non-zero leakage to the outside.
  - Adds warnings if appliance inputs may be inappropriate and result in negative energy or hot water use.

__Bugfixes__
- Fixes error if there's a `FoundationWall` whose height is less than 0.5 ft.
- Fixes HVAC defrost control in EnergyPlus model to use "Timed" instead of "OnDemand".
- Fixes exterior air film and wind exposure for a `FrameFloor` over ambient conditions.
- Fixes air films for a `FrameFloor` ceiling.
- Fixes error if there are additional `LightingGroup` elements beyond the ones required.
- Fixes vented attic ventilation rate.
- Reported unmet heating/cooling load now correctly excludes latent energy.
- Ground-source heat pump backup fuel is now correctly honored instead of always using electricity.

## OpenStudio-HPXML v0.9.0 Beta

__New Features__
- **[Breaking Change]** Updates to OpenStudio v3.0.0 and EnergyPlus 9.3
- Numerous HPXML inputs are now optional with built-in defaulting, particularly for water heating, appliances, and PV. Set the `debug` argument to true to output a in.xml HPXML file with defaults applied for inspection. See the documentation for defaulting equations/assumptions/references.
- **[Breaking Change]** If clothes washer efficiency inputs are provided, `LabelUsage` is now required.
- **[Breaking Change]** If dishwasher efficiency inputs are provided, `LabelElectricRate`, `LabelGasRate`, `LabelAnnualGasCost`, and `LabelUsage` are now required.
- Adds optional specification of simulation controls including timestep and begin/end dates.
- Adds optional `extension/UsageMultiplier` inputs for appliances, plug loads, lighting, and water fixtures. Can be used to, e.g., reflect high/low usage occupants.
- Adds ability to model a dehumidifier.
- Adds ability to model kitchen/bath fans (spot ventilation).
- Improved desuperheater model; desuperheater can now be connected to heat pump water heaters.
- Updated clothes washer/dryer and dishwasher models per ANSI/RESNET/ICC 301-2019 Addendum A.
- Solar thermal systems modeled with `SolarFraction` can now be connected to combi water heating systems.
- **[Breaking Change]** Replaces optional `epw_output_path` and `osm_output_path` arguments with a single optional `output_dir` argument; adds an optional `debug` argument.
- **[Breaking Change]** Replaces optional `BuildingConstruction/extension/FractionofOperableWindowArea` with optional `Window/FractionOperable`.
- **[Breaking Change]** Replaces optional `extension/EPWFileName` with optional `extension/EPWFilePath` to allow absolute paths to be provided as an alternative to just the file name.
- Replaces REXML xml library with Oga for better runtime performance.
- Additional error-checking.
- SimulationOutputReport reporting measure:
  - Now reports wood and wood pellets
  - Can report monthly timeseries values if requested
  - Adds hot water outputs (gallons) for clothes washer, dishwasher, fixtures, and distribution waste.
  - Small improvement to calculation of component loads

__Bugfixes__
- Fixes possible simulation error for buildings with complex HVAC/duct systems.
- Fixes handling of infiltration induced by duct leakage imbalance (i.e., supply leakage != return leakage). Only affects ducts located in a vented crawlspace or vented attic.
- Fixes an unsuccessful simulation for buildings where the sum of multiple HVAC systems' fraction load served was slightly above 1 due to rounding.
- Small fix for interior partition wall thermal mass model.
- Skip building surfaces with areas that are extremely small.

## OpenStudio-HPXML v0.8.0 Beta

__Breaking Changes__
- Weather cache files are now in .csv instead of .cache format.
- `extension/StandbyLoss` changed to `StandbyLoss` for indirect water heaters.
- `Site/extension/DisableNaturalVentilation` changed to `BuildingConstruction/extension/FractionofOperableWindowArea` for more granularity.

__New Features__
- Adds a SimulationOutputReport reporting measure that provides a variety of annual/timeseries outputs in CSV format.
- Allows modeling of whole-house fans to address cooling.
- Improved natural ventilation algorithm that reduces the potential for incurring additional heating energy.
- Optional `HotWaterTemperature` input for water heaters.
- Optional `CompressorType` input for air conditioners and air-source heat pumps.
- Allows specifying the EnergyPlus simulation timestep.
- Runtime performance improvements.
- Additional HPXML error-checking.

__Bugfixes__
- Fix for central fan integrated supply (CFIS) fan energy.
- Fix simulation error when `FractionHeatLoadServed` (or `FractionCoolLoadServed`) sums to slightly greater than 1.
- Fix for running simulations on a different drive (either local or remote network).
- Fix for HVAC sizing error when latitude is exactly 64 (Big Delta, Alaska).
- Fixes running simulations when there is no weather cache file.
- Fixes view factors when conditioned basement foundation walls have a window/door.
- Fixes weather file download.
- Allow a building with ceiling fans and without lighting.

## OpenStudio-HPXML v0.7.0 Beta

- Initial beta release
