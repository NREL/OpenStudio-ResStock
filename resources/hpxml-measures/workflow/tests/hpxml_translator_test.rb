# frozen_string_literal: true

require_relative '../../HPXMLtoOpenStudio/resources/minitest_helper'
require 'openstudio'
require 'fileutils'
require 'parallel'
require_relative '../../HPXMLtoOpenStudio/measure.rb'
require_relative '../../HPXMLtoOpenStudio/resources/constants'
require_relative '../../HPXMLtoOpenStudio/resources/meta_measure'
require_relative '../../HPXMLtoOpenStudio/resources/unit_conversions'
require_relative '../../HPXMLtoOpenStudio/resources/xmlhelper'

class HPXMLTest < MiniTest::Test
  def setup
    @this_dir = File.dirname(__FILE__)
    @results_dir = File.join(@this_dir, 'results')
    FileUtils.mkdir_p @results_dir
  end

  def test_simulations
    results_out = File.join(@results_dir, 'results.csv')
    File.delete(results_out) if File.exist? results_out
    sizing_out = File.join(@results_dir, 'results_hvac_sizing.csv')
    File.delete(sizing_out) if File.exist? sizing_out

    xmls = []
    sample_files_dir = File.absolute_path(File.join(@this_dir, '..', 'sample_files'))
    Dir["#{sample_files_dir}/*.xml"].sort.each do |xml|
      xmls << File.absolute_path(xml)
    end

    # Test simulations
    puts "Running #{xmls.size} HPXML files..."
    all_results = {}
    all_sizing_results = {}
    Parallel.map(xmls, in_threads: Parallel.processor_count) do |xml|
      _test_schema_validation(xml)
      xml_name = File.basename(xml)
      all_results[xml_name], all_sizing_results[xml_name] = _run_xml(xml, Parallel.worker_number)
    end

    _write_summary_results(all_results.sort_by { |k, v| k.downcase }.to_h, results_out)
    _write_hvac_sizing_results(all_sizing_results.sort_by { |k, v| k.downcase }.to_h, sizing_out)
  end

  def test_ashrae_140
    ashrae140_out = File.join(@results_dir, 'results_ashrae_140.csv')
    File.delete(ashrae140_out) if File.exist? ashrae140_out

    xmls = []
    ashrae_140_dir = File.absolute_path(File.join(@this_dir, 'ASHRAE_Standard_140'))
    Dir["#{ashrae_140_dir}/*.xml"].sort.each do |xml|
      xmls << File.absolute_path(xml)
    end

    # Test simulations
    puts "Running #{xmls.size} HPXML files..."
    all_results = {}
    all_sizing_results = {}
    Parallel.map(xmls, in_threads: Parallel.processor_count) do |xml|
      xml_name = File.basename(xml)
      all_results[xml_name], all_sizing_results[xml_name] = _run_xml(xml, Parallel.worker_number)
    end

    _write_ashrae_140_results(all_results.sort_by { |k, v| k.downcase }.to_h, ashrae140_out)
  end

  def test_run_simulation_json_output
    # Check that the simulation produces JSON outputs (instead of CSV outputs) if requested
    os_cli = OpenStudio.getOpenStudioCLI
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "#{os_cli} #{rb_path} -x #{xml} --debug --hourly ALL --output-format json"
    system(command, err: File::NULL)

    # Check for output files
    sql_path = File.join(File.dirname(xml), 'run', 'eplusout.sql')
    assert(File.exist? sql_path)
    json_output_path = File.join(File.dirname(xml), 'run', 'results_annual.json')
    assert(File.exist? json_output_path)
    json_output_path = File.join(File.dirname(xml), 'run', 'results_timeseries.json')
    assert(File.exist? json_output_path)

    # Check for debug files
    osm_path = File.join(File.dirname(xml), 'run', 'in.osm')
    assert(File.exist? osm_path)
    hpxml_defaults_path = File.join(File.dirname(xml), 'run', 'in.xml')
    assert(File.exist? hpxml_defaults_path)
    _test_schema_validation(hpxml_defaults_path)
  end

  def test_run_simulation_epjson_input
    # Check that we can run a simulation using epJSON (instead of IDF) if requested
    os_cli = OpenStudio.getOpenStudioCLI
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "#{os_cli} #{rb_path} -x #{xml} --ep-input-format epjson"
    system(command, err: File::NULL)

    # Check for epjson file
    epjson = File.join(File.dirname(xml), 'run', 'in.epJSON')
    assert(File.exist? epjson)

    # Check for output files
    sql_path = File.join(File.dirname(xml), 'run', 'eplusout.sql')
    assert(File.exist? sql_path)
    csv_output_path = File.join(File.dirname(xml), 'run', 'results_annual.csv')
    assert(File.exist? csv_output_path)
  end

  def test_run_simulation_idf_input
    # Check that we can run a simulation using IDF (instead of epJSON) if requested
    os_cli = OpenStudio.getOpenStudioCLI
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "#{os_cli} #{rb_path} -x #{xml} --ep-input-format idf"
    system(command, err: File::NULL)

    # Check for idf file
    idf = File.join(File.dirname(xml), 'run', 'in.idf')
    assert(File.exist? idf)

    # Check for output files
    sql_path = File.join(File.dirname(xml), 'run', 'eplusout.sql')
    assert(File.exist? sql_path)
    csv_output_path = File.join(File.dirname(xml), 'run', 'results_annual.csv')
    assert(File.exist? csv_output_path)
  end

  def test_run_simulation_faster_performance
    # Run w/ --skip-validation and w/o --add-component-loads arguments
    os_cli = OpenStudio.getOpenStudioCLI
    rb_path = File.join(File.dirname(__FILE__), '..', 'run_simulation.rb')
    xml = File.join(File.dirname(__FILE__), '..', 'sample_files', 'base.xml')
    command = "#{os_cli} #{rb_path} -x #{xml} --skip-validation"
    system(command, err: File::NULL)

    # Check for output files
    sql_path = File.join(File.dirname(xml), 'run', 'eplusout.sql')
    assert(File.exist? sql_path)
    csv_output_path = File.join(File.dirname(xml), 'run', 'results_annual.csv')
    assert(File.exist? csv_output_path)

    # Check component loads don't exist
    component_loads = {}
    CSV.read(csv_output_path, headers: false).each do |data|
      next unless data[0].to_s.start_with? 'Component Load'

      component_loads[data[0]] = Float(data[1])
    end
    assert_equal(0, component_loads.size)
  end

  def test_template_osw
    # Check that simulation works using template.osw
    require 'json'

    os_cli = OpenStudio.getOpenStudioCLI
    osw_path = File.join(File.dirname(__FILE__), '..', 'template.osw')

    # Create derivative OSW for testing
    osw_path_test = osw_path.gsub('.osw', '_test.osw')
    FileUtils.cp(osw_path, osw_path_test)

    # Turn on debug mode
    json = JSON.parse(File.read(osw_path_test), symbolize_names: true)
    json[:steps][0][:arguments][:debug] = true

    if Dir.exist? File.join(File.dirname(__FILE__), '..', '..', 'project')
      # CI checks out the repo as "project", so update dir name
      json[:steps][0][:measure_dir_name] = 'project'
    end

    File.open(osw_path_test, 'w') do |f|
      f.write(JSON.pretty_generate(json))
    end

    command = "#{os_cli} run -w #{osw_path_test}"
    system(command, err: File::NULL)

    # Check for output files
    sql_path = File.join(File.dirname(osw_path_test), 'run', 'eplusout.sql')
    assert(File.exist? sql_path)
    csv_output_path = File.join(File.dirname(osw_path_test), 'run', 'results_annual.csv')
    assert(File.exist? csv_output_path)

    # Check for debug files
    osm_path = File.join(File.dirname(osw_path_test), 'run', 'in.osm')
    assert(File.exist? osm_path)
    hpxml_defaults_path = File.join(File.dirname(osw_path_test), 'run', 'in.xml')
    assert(File.exist? hpxml_defaults_path)

    # Cleanup
    File.delete(osw_path_test)
  end

  def test_weather_cache
    cache_orig = File.join(@this_dir, '..', '..', 'weather', 'USA_CO_Denver.Intl.AP.725650_TMY3-cache.csv')
    cache_bak = cache_orig + '.bak'
    File.rename(cache_orig, cache_bak)
    _run_xml(File.absolute_path(File.join(@this_dir, '..', 'sample_files', 'base.xml')))
    File.rename(cache_bak, cache_orig) # Put original file back
  end

  def test_invalid
    sample_files_dir = File.join(@this_dir, '..', 'sample_files')

    expected_error_msgs = { 'boiler-invalid-afue.xml' => ['Expected AnnualHeatingEfficiency[Units="AFUE"]/Value to be less than or equal to 1'],
                            'cfis-with-hydronic-distribution.xml' => ["Attached HVAC distribution system 'HVACDistribution' cannot be hydronic for ventilation fan 'MechanicalVentilation'."],
                            'clothes-dryer-location.xml' => ['A location is specified as "garage" but no surfaces were found adjacent to this space type.'],
                            'clothes-washer-location.xml' => ['A location is specified as "garage" but no surfaces were found adjacent to this space type.'],
                            'cooking-range-location.xml' => ['A location is specified as "garage" but no surfaces were found adjacent to this space type.'],
                            'dehumidifier-fraction-served.xml' => ['Expected FractionDehumidificationLoadServed to sum to <= 1, but calculated sum is 1.1.'],
                            'dehumidifier-setpoints.xml' => ['All dehumidifiers must have the same setpoint but multiple setpoints were specified.'],
                            'dishwasher-location.xml' => ['A location is specified as "garage" but no surfaces were found adjacent to this space type.'],
                            'dhw-frac-load-served.xml' => ['Expected FractionDHWLoadServed to sum to 1, but calculated sum is 1.15.'],
                            'dhw-invalid-ef-tank.xml' => ['Expected EnergyFactor to be less than 1 [context: /HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="storage water heater"], id: "WaterHeater"]'],
                            'dhw-invalid-uef-tank-heat-pump.xml' => ['Expected UniformEnergyFactor to be greater than 1 [context: /HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="heat pump water heater"], id: "WaterHeater"]'],
                            'duct-leakage-cfm25.xml' => ['Expected Value to be greater than or equal to 0 [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/DuctLeakageMeasurement/DuctLeakage[Units="CFM25"], id: "HVACDistribution"]'],
                            'duct-leakage-percent.xml' => ['Expected Value to be less than 1 [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/DuctLeakageMeasurement/DuctLeakage[Units="Percent"], id: "HVACDistribution"]'],
                            'duct-location.xml' => ['A location is specified as "garage" but no surfaces were found adjacent to this space type.'],
                            'duct-location-unconditioned-space.xml' => ["Expected DuctLocation to be 'living space' or 'basement - conditioned' or 'basement - unconditioned' or 'crawlspace - vented' or 'crawlspace - unvented' or 'attic - vented' or 'attic - unvented' or 'garage' or 'exterior wall' or 'under slab' or 'roof deck' or 'outside' or 'other housing unit' or 'other heated space' or 'other multifamily buffer space' or 'other non-freezing space' [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts, id: \"HVACDistribution\"]"],
                            'duplicate-id.xml' => ["Duplicate SystemIdentifier IDs detected for 'WindowNorth'."],
                            'enclosure-attic-missing-roof.xml' => ['There must be at least one roof adjacent to "attic - unvented". [context: /HPXML/Building/BuildingDetails/Enclosure[*/*[InteriorAdjacentTo="attic - unvented" or ExteriorAdjacentTo="attic - unvented"]]]'],
                            'enclosure-basement-missing-exterior-foundation-wall.xml' => ['There must be at least one exterior foundation wall adjacent to "basement - unconditioned". [context: /HPXML/Building/BuildingDetails/Enclosure[*/*[InteriorAdjacentTo="basement - unconditioned" or ExteriorAdjacentTo="basement - unconditioned"]]]'],
                            'enclosure-basement-missing-slab.xml' => ['There must be at least one slab adjacent to "basement - unconditioned". [context: /HPXML/Building/BuildingDetails/Enclosure[*/*[InteriorAdjacentTo="basement - unconditioned" or ExteriorAdjacentTo="basement - unconditioned"]]]'],
                            'enclosure-floor-area-exceeds-cfa.xml' => ['Expected ConditionedFloorArea to be greater than or equal to the sum of conditioned slab/floor areas. [context: /HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction]'],
                            'enclosure-floor-area-exceeds-cfa2.xml' => ['Expected ConditionedFloorArea to be greater than or equal to the sum of conditioned slab/floor areas. [context: /HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction]'],
                            'enclosure-garage-missing-exterior-wall.xml' => ['There must be at least one exterior wall/foundation wall adjacent to "garage". [context: /HPXML/Building/BuildingDetails/Enclosure[*/*[InteriorAdjacentTo="garage" or ExteriorAdjacentTo="garage"]]]'],
                            'enclosure-garage-missing-roof-ceiling.xml' => ['There must be at least one roof/ceiling adjacent to "garage". [context: /HPXML/Building/BuildingDetails/Enclosure[*/*[InteriorAdjacentTo="garage" or ExteriorAdjacentTo="garage"]]]'],
                            'enclosure-garage-missing-slab.xml' => ['There must be at least one slab adjacent to "garage". [context: /HPXML/Building/BuildingDetails/Enclosure[*/*[InteriorAdjacentTo="garage" or ExteriorAdjacentTo="garage"]]]'],
                            'enclosure-living-missing-ceiling-roof.xml' => ['There must be at least one ceiling/roof adjacent to conditioned space. [context: /HPXML/Building/BuildingDetails/Enclosure[*/*[InteriorAdjacentTo="living space"]]]',
                                                                            'There must be at least one floor adjacent to "attic - unvented". [context: /HPXML/Building/BuildingDetails/Enclosure[*/*[InteriorAdjacentTo="attic - unvented" or ExteriorAdjacentTo="attic - unvented"]]]'],
                            'enclosure-living-missing-exterior-wall.xml' => ['There must be at least one exterior wall adjacent to conditioned space. [context: /HPXML/Building/BuildingDetails/Enclosure[*/*[InteriorAdjacentTo="living space"]]]'],
                            'enclosure-living-missing-floor-slab.xml' => ['There must be at least one floor/slab adjacent to conditioned space. [context: /HPXML/Building/BuildingDetails/Enclosure[*/*[InteriorAdjacentTo="living space"]]]'],
                            'frac-sensible-fuel-load.xml' => ['Expected extension/FracSensible to be greater than or equal to 0 [context: /HPXML/Building/BuildingDetails/MiscLoads/FuelLoad[FuelLoadType="grill" or FuelLoadType="lighting" or FuelLoadType="fireplace"], id: "FuelLoadMisc"]'],
                            'frac-sensible-plug-load.xml' => ['Expected extension/FracSensible to be greater than or equal to 0 [context: /HPXML/Building/BuildingDetails/MiscLoads/PlugLoad[PlugLoadType="other" or PlugLoadType="TV other" or PlugLoadType="electric vehicle charging" or PlugLoadType="well pump"], id: "PlugLoadMisc"]'],
                            'frac-total-fuel-load.xml' => ['Expected sum of extension/FracSensible and extension/FracLatent to be less than or equal to 1 [context: /HPXML/Building/BuildingDetails/MiscLoads/FuelLoad[FuelLoadType="grill" or FuelLoadType="lighting" or FuelLoadType="fireplace"], id: "FuelLoadMisc"]'],
                            'frac-total-plug-load.xml' => ['Expected sum of extension/FracSensible and extension/FracLatent to be less than or equal to 1 [context: /HPXML/Building/BuildingDetails/MiscLoads/PlugLoad[PlugLoadType="other" or PlugLoadType="TV other" or PlugLoadType="electric vehicle charging" or PlugLoadType="well pump"], id: "PlugLoadMisc"]'],
                            'furnace-invalid-afue.xml' => ['Expected AnnualHeatingEfficiency[Units="AFUE"]/Value to be less than or equal to 1'],
                            'generator-number-of-bedrooms-served.xml' => ['Expected NumberofBedroomsServed to be greater than ../../../../BuildingSummary/BuildingConstruction/NumberofBedrooms [context: /HPXML/Building/BuildingDetails/Systems/extension/Generators/Generator[IsSharedSystem="true"], id: "Generator"]'],
                            'generator-output-greater-than-consumption.xml' => ['Expected AnnualConsumptionkBtu to be greater than AnnualOutputkWh*3412 [context: /HPXML/Building/BuildingDetails/Systems/extension/Generators/Generator, id: "Generator"]'],
                            'heat-pump-mixed-fixed-and-autosize-capacities.xml' => ['Expected 0 or 2 element(s) for xpath: HeatingCapacity | BackupHeatingCapacity [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[BackupSystemFuel], id: "HeatPump"]'],
                            'hvac-distribution-multiple-attached-cooling.xml' => ["Multiple cooling systems found attached to distribution system 'HVACDistribution2'."],
                            'hvac-distribution-multiple-attached-heating.xml' => ["Multiple heating systems found attached to distribution system 'HVACDistribution'."],
                            'hvac-distribution-return-duct-leakage-missing.xml' => ['Expected 1 element(s) for xpath: DuctLeakageMeasurement[DuctType="return"]/DuctLeakage[(Units="CFM25" or Units="Percent") and TotalOrToOutside="to outside"] [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution[AirDistributionType[text()="regular velocity" or text()="gravity"]], id: "HVACDistribution"]'],
                            'hvac-dse-multiple-attached-cooling.xml' => ["Multiple cooling systems found attached to distribution system 'HVACDistribution'."],
                            'hvac-dse-multiple-attached-heating.xml' => ["Multiple heating systems found attached to distribution system 'HVACDistribution'."],
                            'hvac-frac-load-served.xml' => ['Expected FractionCoolLoadServed to sum to <= 1, but calculated sum is 1.2.',
                                                            'Expected FractionHeatLoadServed to sum to <= 1, but calculated sum is 1.1.'],
                            'hvac-inconsistent-fan-powers.xml' => ["Fan powers for heating system 'HeatingSystem' and cooling system 'CoolingSystem' are attached to a single distribution system and therefore must be the same."],
                            'hvac-invalid-distribution-system-type.xml' => ["Incorrect HVAC distribution system type for HVAC type: 'Furnace'. Should be one of: ["],
                            'hvac-seasons-less-than-a-year.xml' => ['HeatingSeason and CoolingSeason, when combined, must span the entire year.'],
                            'hvac-shared-negative-seer-eq.xml' => ["Negative SEER equivalent calculated for cooling system 'CoolingSystem', double check inputs."],
                            'invalid-assembly-effective-rvalue.xml' => ['Expected AssemblyEffectiveRValue to be greater than 0 [context: /HPXML/Building/BuildingDetails/Enclosure/Walls/Wall/Insulation, id: "WallInsulation"]'],
                            'invalid-datatype-boolean.xml' => ["Cannot convert 'FOOBAR' to boolean for Roof/RadiantBarrier."],
                            'invalid-datatype-integer.xml' => ["Cannot convert '2.5' to integer for BuildingConstruction/NumberofBedrooms."],
                            'invalid-datatype-float.xml' => ["Cannot convert 'FOOBAR' to float for Slab/extension/CarpetFraction."],
                            'invalid-daylight-saving.xml' => ['Daylight Saving End Day of Month (31) must be one of: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30.'],
                            'invalid-distribution-cfa-served.xml' => ['The total conditioned floor area served by the HVAC distribution system(s) for heating is larger than the conditioned floor area of the building.',
                                                                      'The total conditioned floor area served by the HVAC distribution system(s) for cooling is larger than the conditioned floor area of the building.'],
                            'invalid-duct-area-fractions.xml' => ['Expected FractionDuctArea for Ducts (of type supply) to sum to 1, but calculated sum is 0.8.',
                                                                  'Expected FractionDuctArea for Ducts (of type return) to sum to 1, but calculated sum is 0.8.'],
                            'invalid-epw-filepath.xml' => ["foo.epw' could not be found."],
                            'invalid-facility-type-equipment.xml' => ['Expected 1 element(s) for xpath: ../../../BuildingSummary/BuildingConstruction[ResidentialFacilityType[text()="single-family attached" or text()="apartment unit"]] [context: /HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[IsSharedSystem="true"], id: "SharedWaterHeater"]',
                                                                      'Expected 1 element(s) for xpath: ../../BuildingSummary/BuildingConstruction[ResidentialFacilityType[text()="single-family attached" or text()="apartment unit"]] [context: /HPXML/Building/BuildingDetails/Appliances/ClothesWasher[IsSharedAppliance="true"], id: "SharedClothesWasher"]',
                                                                      'Expected 1 element(s) for xpath: ../../BuildingSummary/BuildingConstruction[ResidentialFacilityType[text()="single-family attached" or text()="apartment unit"]] [context: /HPXML/Building/BuildingDetails/Appliances/ClothesDryer[IsSharedAppliance="true"], id: "SharedClothesDryer"]',
                                                                      'Expected 1 element(s) for xpath: ../../BuildingSummary/BuildingConstruction[ResidentialFacilityType[text()="single-family attached" or text()="apartment unit"]] [context: /HPXML/Building/BuildingDetails/Appliances/Dishwasher[IsSharedAppliance="true"], id: "SharedDishwasher"]'],
                            'invalid-facility-type-surfaces.xml' => ["The building is of type 'single-family detached' but the surface 'RimJoistOther' is adjacent to Attached/Multifamily space 'other housing unit'.",
                                                                     "The building is of type 'single-family detached' but the surface 'WallOther' is adjacent to Attached/Multifamily space 'other housing unit'.",
                                                                     "The building is of type 'single-family detached' but the surface 'FoundationWallOther' is adjacent to Attached/Multifamily space 'other housing unit'.",
                                                                     "The building is of type 'single-family detached' but the surface 'FloorAboveOther' is adjacent to Attached/Multifamily space 'other housing unit'.",
                                                                     "The building is of type 'single-family detached' but the surface 'CeilingBelowOther' is adjacent to Attached/Multifamily space 'other housing unit'."],
                            'invalid-foundation-wall-properties.xml' => ['Expected DepthBelowGrade to be less than or equal to Height [context: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall, id: "FoundationWall"]',
                                                                         'Expected extension/DistanceToBottomOfInsulation to be greater than or equal to extension/DistanceToTopOfInsulation [context: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - exterior" or InstallationType="continuous - interior"], id: "FoundationWallInsulation"]',
                                                                         'Expected extension/DistanceToBottomOfInsulation to be less than or equal to ../../Height [context: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - exterior" or InstallationType="continuous - interior"], id: "FoundationWallInsulation"]'],
                            'invalid-id.xml' => ["Empty SystemIdentifier ID ('') detected for skylights."],
                            'invalid-id2.xml' => ['Expected id attribute for SystemIdentifier [context: /HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight]'],
                            'invalid-infiltration-volume.xml' => ['Expected InfiltrationVolume to be greater than or equal to ../../../BuildingSummary/BuildingConstruction/ConditionedBuildingVolume [context: /HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement[BuildingAirLeakage/UnitofMeasure[text()="ACH" or text()="CFM"]], id: "InfiltrationMeasurement"]'],
                            'invalid-input-parameters.xml' => ["Expected Transaction to be 'create' or 'update' [context: /HPXML/XMLTransactionHeaderInformation]",
                                                               "Expected SiteType to be 'rural' or 'suburban' or 'urban' [context: /HPXML/Building/BuildingDetails/BuildingSummary/Site]",
                                                               "Expected Year to be '2012' or '2009' or '2006' or '2003' [context: /HPXML/Building/BuildingDetails/ClimateandRiskZones/ClimateZoneIECC]",
                                                               'Expected Azimuth to be less than 360 [context: /HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof, id: "Roof"]',
                                                               'Expected RadiantBarrierGrade to be less than or equal to 3 [context: /HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof, id: "Roof"]',
                                                               'Expected EnergyFactor to be less than or equal to 5 [context: /HPXML/Building/BuildingDetails/Appliances/Dishwasher, id: "Dishwasher"]'],
                            'invalid-insulation-top.xml' => ['Expected extension/DistanceToTopOfInsulation to be greater than or equal to 0 [context: /HPXML/Building/BuildingDetails/Enclosure/FoundationWalls/FoundationWall/Insulation/Layer[InstallationType="continuous - exterior" or InstallationType="continuous - interior"], id: "FoundationWallInsulation"]'],
                            'invalid-neighbor-shading-azimuth.xml' => ['A neighbor building has an azimuth (145) not equal to the azimuth of any wall.'],
                            'invalid-number-of-bedrooms-served.xml' => ['Expected extension/NumberofBedroomsServed to be greater than ../../../BuildingSummary/BuildingConstruction/NumberofBedrooms [context: /HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem[IsSharedSystem="true"], id: "PVSystem"]'],
                            'invalid-number-of-conditioned-floors.xml' => ['Expected NumberofConditionedFloors to be greater than or equal to NumberofConditionedFloorsAboveGrade [context: /HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction]'],
                            'invalid-number-of-units-served.xml' => ['Expected NumberofUnitsServed to be greater than 1 [context: /HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[IsSharedSystem="true"], id: "SharedWaterHeater"]'],
                            'invalid-relatedhvac-dhw-indirect.xml' => ["RelatedHVACSystem 'HeatingSystem_bad' not found for water heating system 'WaterHeater'"],
                            'invalid-relatedhvac-desuperheater.xml' => ["RelatedHVACSystem 'CoolingSystem_bad' not found for water heating system 'WaterHeater'."],
                            'invalid-schema-version.xml' => ['HPXML version 3.0 is required.'],
                            'invalid-shared-vent-in-unit-flowrate.xml' => ['Expected extension/InUnitFlowRate to be less than RatedFlowRate [context: /HPXML/Building/BuildingDetails/Systems/MechanicalVentilation/VentilationFans/VentilationFan[UsedForWholeBuildingVentilation="true" and IsSharedSystem="true"], id: "SharedSupplyFan"]'],
                            'invalid-timestep.xml' => ['Timestep (45) must be one of: 60, 30, 20, 15, 12, 10, 6, 5, 4, 3, 2, 1.'],
                            'invalid-runperiod.xml' => ['Run Period End Day of Month (31) must be one of: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30.'],
                            'invalid-window-height.xml' => ['Expected DistanceToBottomOfWindow to be greater than DistanceToTopOfWindow [context: /HPXML/Building/BuildingDetails/Enclosure/Windows/Window/Overhangs, id: "WindowEast"]'],
                            'lighting-fractions.xml' => ['Sum of fractions of interior lighting (1.15) is greater than 1.'],
                            'missing-elements.xml' => ['Expected 1 element(s) for xpath: NumberofConditionedFloors [context: /HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction]',
                                                       'Expected 1 element(s) for xpath: ConditionedFloorArea [context: /HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction]'],
                            'missing-duct-area.xml' => ['Expected 1 or more element(s) for xpath: FractionDuctArea | DuctSurfaceArea [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts[DuctLocation], id: "HVACDistribution"]',
                                                        'Expected 1 or more element(s) for xpath: FractionDuctArea | DuctSurfaceArea [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts[DuctLocation], id: "HVACDistribution2"]',
                                                        'Expected 1 or more element(s) for xpath: FractionDuctArea | DuctSurfaceArea [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts[DuctLocation], id: "HVACDistribution5"]',
                                                        'Expected 1 or more element(s) for xpath: FractionDuctArea | DuctSurfaceArea [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts[DuctLocation], id: "HVACDistribution6"]'],
                            'missing-duct-location.xml' => ['Expected 0 element(s) for xpath: FractionDuctArea | DuctSurfaceArea [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts[not(DuctLocation)], id: "HVACDistribution"]',
                                                            'Expected 0 element(s) for xpath: FractionDuctArea | DuctSurfaceArea [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts[not(DuctLocation)], id: "HVACDistribution2"]',
                                                            'Expected 0 element(s) for xpath: FractionDuctArea | DuctSurfaceArea [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts[not(DuctLocation)], id: "HVACDistribution5"]',
                                                            'Expected 0 element(s) for xpath: FractionDuctArea | DuctSurfaceArea [context: /HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts[not(DuctLocation)], id: "HVACDistribution6"]'],
                            'multifamily-reference-appliance.xml' => ["The building is of type 'single-family detached' but"],
                            'multifamily-reference-duct.xml' => ["The building is of type 'single-family detached' but"],
                            'multifamily-reference-surface.xml' => ["The building is of type 'single-family detached' but"],
                            'multifamily-reference-water-heater.xml' => ["The building is of type 'single-family detached' but"],
                            'multiple-buildings-without-building-id.xml' => ['Multiple Building elements defined in HPXML file; Building ID argument must be provided.'],
                            'multiple-buildings-wrong-building-id.xml' => ["Could not find Building element with ID 'MyFoo'."],
                            'multiple-shared-cooling-systems.xml' => ['More than one shared cooling system found.'],
                            'multiple-shared-heating-systems.xml' => ['More than one shared heating system found.'],
                            'net-area-negative-wall.xml' => ["Calculated a negative net surface area for surface 'Wall'."],
                            'net-area-negative-roof.xml' => ["Calculated a negative net surface area for surface 'Roof'."],
                            'orphaned-hvac-distribution.xml' => ["Distribution system 'HVACDistribution' found but no HVAC system attached to it."],
                            'refrigerator-location.xml' => ['A location is specified as "garage" but no surfaces were found adjacent to this space type.'],
                            'refrigerators-multiple-primary.xml' => ['More than one refrigerator designated as the primary.'],
                            'refrigerators-no-primary.xml' => ['Could not find a primary refrigerator.'],
                            'repeated-relatedhvac-dhw-indirect.xml' => ["RelatedHVACSystem 'HeatingSystem' is attached to multiple water heating systems."],
                            'repeated-relatedhvac-desuperheater.xml' => ["RelatedHVACSystem 'CoolingSystem' is attached to multiple water heating systems."],
                            'solar-fraction-one.xml' => ['Expected SolarFraction to be less than 1 [context: /HPXML/Building/BuildingDetails/Systems/SolarThermal/SolarThermalSystem, id: "SolarThermalSystem"]'],
                            'solar-thermal-system-with-combi-tankless.xml' => ["Water heating system 'WaterHeater' connected to solar thermal system 'SolarThermalSystem' cannot be a space-heating boiler."],
                            'solar-thermal-system-with-desuperheater.xml' => ["Water heating system 'WaterHeater' connected to solar thermal system 'SolarThermalSystem' cannot be attached to a desuperheater."],
                            'solar-thermal-system-with-dhw-indirect.xml' => ["Water heating system 'WaterHeater' connected to solar thermal system 'SolarThermalSystem' cannot be a space-heating boiler."],
                            'unattached-cfis.xml' => ["Attached HVAC distribution system 'foobar' not found for ventilation fan 'MechanicalVentilation'."],
                            'unattached-door.xml' => ["Attached wall 'foobar' not found for door 'DoorNorth'."],
                            'unattached-hvac-distribution.xml' => ["Attached HVAC distribution system 'foobar' not found for HVAC system 'HeatingSystem'."],
                            'unattached-skylight.xml' => ["Attached roof 'foobar' not found for skylight 'SkylightNorth'."],
                            'unattached-solar-thermal-system.xml' => ["Attached water heating system 'foobar' not found for solar thermal system 'SolarThermalSystem'."],
                            'unattached-shared-clothes-washer-water-heater.xml' => ["Attached water heating system 'foobar' not found for clothes washer"],
                            'unattached-shared-dishwasher-water-heater.xml' => ["Attached water heating system 'foobar' not found for dishwasher"],
                            'unattached-window.xml' => ["Attached wall 'foobar' not found for window 'WindowNorth'."],
                            'water-heater-location.xml' => ['A location is specified as "crawlspace - vented" but no surfaces were found adjacent to this space type.'],
                            'water-heater-location-other.xml' => ["Expected Location to be 'living space' or 'basement - unconditioned' or 'basement - conditioned' or 'attic - unvented' or 'attic - vented' or 'garage' or 'crawlspace - unvented' or 'crawlspace - vented' or 'other exterior' or 'other housing unit' or 'other heated space' or 'other multifamily buffer space' or 'other non-freezing space' [context: /HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem, id: \"WaterHeater\"]"] }

    # Test simulations
    xmls = Dir["#{sample_files_dir}/invalid_files/*.xml"].sort
    Parallel.map(xmls, in_threads: Parallel.processor_count) do |xml|
      _run_xml(File.absolute_path(xml), Parallel.worker_number, true, expected_error_msgs[File.basename(xml)])
    end
  end

  def test_release_zips
    # Check release zips successfully created
    top_dir = File.join(@this_dir, '..', '..')
    command = "#{OpenStudio.getOpenStudioCLI} #{File.join(top_dir, 'tasks.rb')} create_release_zips"
    system(command)
    assert_equal(2, Dir["#{top_dir}/*.zip"].size)

    # Check successful running of simulation from release zips
    Dir["#{top_dir}/OpenStudio-HPXML*.zip"].each do |zip|
      unzip_file = OpenStudio::UnzipFile.new(zip)
      unzip_file.extractAllFiles(OpenStudio::toPath(top_dir))
      command = "#{OpenStudio.getOpenStudioCLI} OpenStudio-HPXML/workflow/run_simulation.rb -x OpenStudio-HPXML/workflow/sample_files/base.xml"
      system(command)
      assert(File.exist? 'OpenStudio-HPXML/workflow/sample_files/run/results_annual.csv')
      File.delete(zip)
      rm_path('OpenStudio-HPXML')
    end
  end

  private

  def _run_xml(xml, worker_num = nil, expect_error = false, expect_error_msgs = nil)
    print "Testing #{File.basename(xml)}...\n"
    rundir = File.join(@this_dir, "test#{worker_num}")

    # Uses 'monthly' to verify timeseries results match annual results via error-checking
    # inside the SimulationOutputReport measure.
    cli_path = OpenStudio.getOpenStudioCLI
    building_id = ''
    if xml.include? 'base-multiple-buildings.xml'
      building_id = '--building-id MyBuilding'
    elsif xml.include? 'multiple-buildings-wrong-building-id.xml'
      building_id = '--building-id MyFoo'
    end
    command = "\"#{cli_path}\" \"#{File.join(File.dirname(__FILE__), '../run_simulation.rb')}\" -x #{xml} --add-component-loads -o #{rundir} --debug --monthly ALL #{building_id}"
    workflow_start = Time.now
    success = system(command)
    workflow_time = Time.now - workflow_start

    rundir = File.join(rundir, 'run')

    # Check results
    if expect_error
      assert_equal(false, success)

      if expect_error_msgs.nil?
        flunk "No error message defined for #{File.basename(xml)}."
      else
        run_log = File.readlines(File.join(rundir, 'run.log')).map(&:strip)
        n_errors = 0
        expect_error_msgs.each_with_index do |error_msg, i|
          found_error_msg = false
          run_log.each do |run_line|
            next unless run_line.start_with? 'Error: '

            n_errors += 1 if i == 0

            next unless run_line.include? error_msg

            found_error_msg = true
          end
          assert(found_error_msg)
        end
        assert_equal(n_errors, expect_error_msgs.size)
      end

      return
    end

    assert_equal(true, success)

    # Check for output files
    annual_csv_path = File.join(rundir, 'results_annual.csv')
    timeseries_csv_path = File.join(rundir, 'results_timeseries.csv')
    assert(File.exist? annual_csv_path)
    assert(File.exist? timeseries_csv_path)

    # Get results
    results = _get_simulation_results(annual_csv_path, xml)

    # Check outputs
    hpxml_defaults_path = File.join(rundir, 'in.xml')
    stron_paths = [File.join(File.dirname(__FILE__), '..', '..', 'HPXMLtoOpenStudio', 'resources', 'EPvalidator.xml')]
    hpxml = HPXML.new(hpxml_path: hpxml_defaults_path, schematron_validators: stron_paths) # Validate in.xml to ensure it can be run back through OS-HPXML
    if not hpxml.errors.empty?
      puts 'ERRORS:'
      hpxml.errors.each do |error|
        puts error
      end
      flunk "EPvalidator.xml error in #{hpxml_defaults_path}."
    end
    sizing_results = _get_hvac_sizing_results(hpxml, xml)
    _verify_outputs(rundir, xml, results, hpxml)

    return results, sizing_results
  end

  def _get_simulation_results(annual_csv_path, xml)
    # Grab all outputs from reporting measure CSV annual results
    results = {}
    CSV.foreach(annual_csv_path) do |row|
      next if row.nil? || (row.size < 2)

      results[row[0]] = Float(row[1])
    end

    # Check discrepancy between total load and sum of component loads
    if not xml.include? 'ASHRAE_Standard_140'
      sum_component_htg_loads = results.select { |k, v| k.start_with? 'Component Load: Heating:' }.map { |k, v| v }.sum(0.0)
      sum_component_clg_loads = results.select { |k, v| k.start_with? 'Component Load: Cooling:' }.map { |k, v| v }.sum(0.0)
      residual_htg_load = results['Load: Heating (MBtu)'] - sum_component_htg_loads
      residual_clg_load = results['Load: Cooling (MBtu)'] - sum_component_clg_loads
      assert_operator(residual_htg_load.abs, :<, 0.5)
      assert_operator(residual_clg_load.abs, :<, 0.5)
    end

    return results
  end

  def _get_hvac_sizing_results(hpxml, xml)
    results = {}
    return if xml.include? 'ASHRAE_Standard_140'

    # Heating design loads
    hpxml.hvac_plant.class::HDL_ATTRS.each do |attr, element_name|
      results["heating_load_#{attr.to_s.gsub('hdl_', '')} [Btuh]"] = hpxml.hvac_plant.send(attr.to_s)
    end

    # Cooling sensible design loads
    hpxml.hvac_plant.class::CDL_SENS_ATTRS.each do |attr, element_name|
      results["cooling_load_#{attr.to_s.gsub('cdl_', '')} [Btuh]"] = hpxml.hvac_plant.send(attr.to_s)
    end

    # Cooling latent design loads
    hpxml.hvac_plant.class::CDL_LAT_ATTRS.each do |attr, element_name|
      results["cooling_load_#{attr.to_s.gsub('cdl_', '')} [Btuh]"] = hpxml.hvac_plant.send(attr.to_s)
    end

    # Heating capacities/airflows
    results['heating_capacity [Btuh]'] = 0.0
    results['heating_backup_capacity [Btuh]'] = 0.0
    results['heating_airflow [cfm]'] = 0.0
    (hpxml.heating_systems + hpxml.heat_pumps).each do |htg_sys|
      results['heating_capacity [Btuh]'] += htg_sys.heating_capacity
      if htg_sys.respond_to? :backup_heating_capacity
        results['heating_backup_capacity [Btuh]'] += htg_sys.backup_heating_capacity
      end
      results['heating_airflow [cfm]'] += htg_sys.heating_airflow_cfm
    end

    # Cooling capacity/airflows
    results['cooling_capacity [Btuh]'] = 0.0
    results['cooling_airflow [cfm]'] = 0.0
    (hpxml.cooling_systems + hpxml.heat_pumps).each do |clg_sys|
      results['cooling_capacity [Btuh]'] += clg_sys.cooling_capacity
      results['cooling_airflow [cfm]'] += clg_sys.cooling_airflow_cfm
    end

    assert(!results.empty?)

    if (hpxml.heating_systems + hpxml.heat_pumps).select { |h| h.fraction_heat_load_served.to_f > 0 }.empty?
      # No heating equipment; check for zero heating capacities/airflows/duct loads
      assert_equal(0.0, results['heating_capacity [Btuh]'])
      assert_equal(0.0, results['heating_backup_capacity [Btuh]'])
      assert_equal(0.0, results['heating_airflow [cfm]'])
      assert_equal(0.0, results['heating_load_ducts [Btuh]'])
    end
    if (hpxml.cooling_systems + hpxml.heat_pumps).select { |c| c.fraction_cool_load_served.to_f > 0 }.empty?
      # No cooling equipment; check for zero cooling capacities/airflows/duct loads
      assert_equal(0.0, results['cooling_capacity [Btuh]'])
      assert_equal(0.0, results['cooling_airflow [cfm]'])
      assert_equal(0.0, results['cooling_load_sens_ducts [Btuh]'])
      assert_equal(0.0, results['cooling_load_lat_ducts [Btuh]'])
    end
    if hpxml.hvac_distributions.map { |dist| dist.ducts.size }.empty?
      # No ducts; check for zero duct loads
      assert_equal(0.0, results['heating_load_ducts [Btuh]'])
      assert_equal(0.0, results['cooling_load_sens_ducts [Btuh]'])
      assert_equal(0.0, results['cooling_load_lat_ducts [Btuh]'])
    end

    return results
  end

  def _test_schema_validation(xml)
    # TODO: Remove this when schema validation is included with CLI calls
    schemas_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', 'HPXMLtoOpenStudio', 'resources'))
    hpxml_doc = XMLHelper.parse_file(xml)
    errors = XMLHelper.validate(hpxml_doc.to_xml, File.join(schemas_dir, 'HPXML.xsd'), nil)
    if errors.size > 0
      puts "#{xml}: #{errors}"
    end
    assert_equal(0, errors.size)
  end

  def _verify_outputs(rundir, hpxml_path, results, hpxml)
    sql_path = File.join(rundir, 'eplusout.sql')
    assert(File.exist? sql_path)

    sqlFile = OpenStudio::SqlFile.new(sql_path, false)

    # Collapse windows further using same logic as measure.rb
    hpxml.windows.each do |window|
      window.fraction_operable = nil
    end
    hpxml.collapse_enclosure_surfaces()

    # Check run.log warnings
    File.readlines(File.join(rundir, 'run.log')).each do |log_line|
      next if log_line.strip.empty?
      next if log_line.include? 'Warning: Could not load nokogiri, no HPXML validation performed.'
      next if log_line.start_with? 'Info: '
      next if log_line.start_with? 'Executing command'
      next if log_line.include? "-cache.csv' could not be found; regenerating it."

      if hpxml_path.include? 'base-atticroof-conditioned.xml'
        next if log_line.include?('Ducts are entirely within conditioned space but there is moderate leakage to the outside. Leakage to the outside is typically zero or near-zero in these situations, consider revising leakage values. Leakage will be modeled as heat lost to the ambient environment.')
      end
      if hpxml.clothes_washers.empty?
        next if log_line.include? 'No clothes washer specified, the model will not include clothes washer energy use.'
      end
      if hpxml.clothes_dryers.empty?
        next if log_line.include? 'No clothes dryer specified, the model will not include clothes dryer energy use.'
      end
      if hpxml.dishwashers.empty?
        next if log_line.include? 'No dishwasher specified, the model will not include dishwasher energy use.'
      end
      if hpxml.refrigerators.empty?
        next if log_line.include? 'No refrigerator specified, the model will not include refrigerator energy use.'
      end
      if hpxml.cooking_ranges.empty?
        next if log_line.include? 'No cooking range specified, the model will not include cooking range/oven energy use.'
      end
      if hpxml.water_heating_systems.empty?
        next if log_line.include? 'No water heating specified, the model will not include water heating energy use.'
      end
      if (hpxml.heating_systems + hpxml.heat_pumps).select { |h| h.fraction_heat_load_served.to_f > 0 }.empty?
        next if log_line.include? 'No space heating specified, the model will not include space heating energy use.'
      end
      if (hpxml.cooling_systems + hpxml.heat_pumps).select { |c| c.fraction_cool_load_served.to_f > 0 }.empty?
        next if log_line.include? 'No space cooling specified, the model will not include space cooling energy use.'
      end
      if hpxml.plug_loads.select { |p| p.plug_load_type == HPXML::PlugLoadTypeOther }.empty?
        next if log_line.include? "No '#{HPXML::PlugLoadTypeOther}' plug loads specified, the model will not include misc plug load energy use."
      end
      if hpxml.plug_loads.select { |p| p.plug_load_type == HPXML::PlugLoadTypeTelevision }.empty?
        next if log_line.include? "No '#{HPXML::PlugLoadTypeTelevision}' plug loads specified, the model will not include television plug load energy use."
      end
      if hpxml.lighting_groups.empty?
        next if log_line.include? 'No lighting specified, the model will not include lighting energy use.'
      end
      if hpxml.windows.empty?
        next if log_line.include? 'No windows specified, the model will not include window heat transfer.'
      end

      flunk "Unexpected warning found in run.log: #{log_line}"
    end

    # Check for unexpected warnings
    File.readlines(File.join(rundir, 'eplusout.err')).each do |err_line|
      next unless err_line.include? '** Warning **'

      # General
      next if err_line.include? 'Schedule:Constant="ALWAYS ON CONTINUOUS", Blank Schedule Type Limits Name input'
      next if err_line.include? 'Schedule:Constant="ALWAYS OFF DISCRETE", Blank Schedule Type Limits Name input'
      next if err_line.include? 'Output:Meter: invalid Key Name'
      next if err_line.include? 'Entered Zone Volumes differ from calculated zone volume'
      next if err_line.include?('CalculateZoneVolume') && err_line.include?('not fully enclosed')
      next if err_line.include?('GetInputViewFactors') && err_line.include?('not enough values')
      next if err_line.include? 'Pump nominal power or motor efficiency is set to 0'
      next if err_line.include? 'volume flow rate per watt of rated total cooling capacity is out of range'
      next if err_line.include? 'volume flow rate per watt of rated total heating capacity is out of range'
      next if err_line.include? 'The following Report Variables were requested but not generated'
      next if err_line.include? 'Timestep: Requested number'
      next if err_line.include? 'The Standard Ratings is calculated for'
      next if err_line.include?('CheckUsedConstructions') && err_line.include?('nominally unused constructions')
      next if err_line.include?('WetBulb not converged after') && err_line.include?('iterations(PsyTwbFnTdbWPb)')
      next if err_line.include? 'Inside surface heat balance did not converge with Max Temp Difference'
      next if err_line.include? 'Missing temperature setpoint for LeavingSetpointModulated mode' # These warnings are fine, simulation continues with assigning plant loop setpoint to boiler, which is the expected one
      next if err_line.include?('Glycol: Temperature') && err_line.include?('out of range (too low) for fluid')
      next if err_line.include?('Glycol: Temperature') && err_line.include?('out of range (too high) for fluid')
      next if err_line.include? 'Plant loop exceeding upper temperature limit'
      next if err_line.include? 'Plant loop falling below lower temperature limit'
      next if err_line.include?('Foundation:Kiva') && err_line.include?('wall surfaces with more than four vertices') # TODO: Check alternative approach
      next if err_line.include? 'Temperature out of range [-100. to 200.] (PsyPsatFnTemp)'
      next if err_line.include? 'Enthalpy out of range (PsyTsatFnHPb)'
      next if err_line.include? 'Full load outlet air dry-bulb temperature < 2C. This indicates the possibility of coil frost/freeze.'
      next if err_line.include? 'Full load outlet temperature indicates a possibility of frost/freeze error continues.'
      next if err_line.include? 'Air-cooled condenser inlet dry-bulb temperature below 0 C.'
      next if err_line.include? 'Low condenser dry-bulb temperature error continues.'
      next if err_line.include? 'Coil control failed to converge for AirLoopHVAC:UnitarySystem'
      next if err_line.include? 'Coil control failed for AirLoopHVAC:UnitarySystem'
      next if err_line.include? 'sensible part-load ratio out of range error continues'
      next if err_line.include? 'Iteration limit exceeded in calculating sensible part-load ratio error continues'

      # HPWHs
      if hpxml.water_heating_systems.select { |wh| wh.water_heater_type == HPXML::WaterHeaterTypeHeatPump }.size > 0
        next if err_line.include? 'Recovery Efficiency and Energy Factor could not be calculated during the test for standard ratings'
        next if err_line.include? 'SimHVAC: Maximum iterations (20) exceeded for all HVAC loops'
        next if err_line.include? 'Rated air volume flow rate per watt of rated total water heating capacity is out of range'
        next if err_line.include? 'For object = Coil:WaterHeating:AirToWaterHeatPump:Wrapped'
        next if err_line.include? 'Enthalpy out of range (PsyTsatFnHPb)'
      end
      # HP defrost curves
      if hpxml.heat_pumps.select { |hp| [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpMiniSplit].include? hp.heat_pump_type }.size > 0
        next if err_line.include?('GetDXCoils: Coil:Heating:DX') && err_line.include?('curve values')
      end
      if hpxml.cooling_systems.select { |c| c.cooling_system_type == HPXML::HVACTypeEvaporativeCooler }.size > 0
        # Evap cooler model is not really using Controller:MechanicalVentilation object, so these warnings of ignoring some features are fine.
        # OS requires a Controller:MechanicalVentilation to be attached to the oa controller, however it's not required by E+.
        # Manually removing Controller:MechanicalVentilation from idf eliminates these two warnings.
        # FUTURE: Can we update OS to allow removing it?
        next if err_line.include?('Zone') && err_line.include?('is not accounted for by Controller:MechanicalVentilation object')
        next if err_line.include?('PEOPLE object for zone') && err_line.include?('is not accounted for by Controller:MechanicalVentilation object')
        # "The only valid controller type for an AirLoopHVAC is Controller:WaterCoil.", evap cooler doesn't need one.
        next if err_line.include?('GetAirPathData: AirLoopHVAC') && err_line.include?('has no Controllers')
        # input "Autosize" for Fixed Minimum Air Flow Rate is added by OS translation, now set it to 0 to skip potential sizing process, though no way to prevent this warning.
        next if err_line.include? 'Since Zone Minimum Air Flow Input Method = CONSTANT, input for Fixed Minimum Air Flow Rate will be ignored'
      end
      if hpxml.hvac_distributions.select { |d| d.air_type.to_s == HPXML::AirTypeFanCoil }.size > 0
        next if err_line.include? 'In calculating the design coil UA for Coil:Cooling:Water' # Warning for unused cooling coil for fan coil
      end
      if hpxml_path.include?('ground-to-air-heat-pump-cooling-only.xml') || hpxml_path.include?('ground-to-air-heat-pump-heating-only.xml')
        next if err_line.include? 'COIL:HEATING:WATERTOAIRHEATPUMP:EQUATIONFIT' # heating capacity is > 20% different than cooling capacity; safe to ignore
      end
      if hpxml.solar_thermal_systems.size > 0
        next if err_line.include? 'Supply Side is storing excess heat the majority of the time.'
      end
      if hpxml_path.include?('base-schedules-stochastic.xml') || hpxml_path.include?('base-schedules-stochastic-vacant.xml') || hpxml_path.include?('base-schedules-user-specified.xml')
        next if err_line.include?('GetCurrentScheduleValue: Schedule=') && err_line.include?('is a Schedule:File')
      end

      flunk "Unexpected warning found: #{err_line}"
    end

    # Timestep
    timestep = hpxml.header.timestep
    if timestep.nil?
      timestep = 60
    end
    query = 'SELECT NumTimestepsPerHour FROM Simulations'
    sql_value = sqlFile.execAndReturnFirstDouble(query).get
    assert_equal(60 / timestep, sql_value)

    # Conditioned Floor Area
    if (hpxml.total_fraction_cool_load_served > 0) || (hpxml.total_fraction_heat_load_served > 0) # EnergyPlus will only report conditioned floor area if there is an HVAC system
      hpxml_value = hpxml.building_construction.conditioned_floor_area
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='InputVerificationandResultsSummary' AND ReportForString='Entire Facility' AND TableName='Zone Summary' AND RowName='Conditioned Total' AND ColumnName='Area' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_in_epsilon(hpxml_value, sql_value, 0.1)
    end

    # Enclosure Roofs
    hpxml.roofs.each do |roof|
      roof_id = roof.id.upcase

      # R-value
      hpxml_value = roof.insulation_assembly_r_value
      if hpxml_path.include? 'ASHRAE_Standard_140'
        # Compare R-value w/o film
        hpxml_value -= Material.AirFilmRoofASHRAE140.rvalue
        hpxml_value -= Material.AirFilmOutsideASHRAE140.rvalue
        query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND (RowName='#{roof_id}' OR RowName LIKE '#{roof_id}:%') AND ColumnName='U-Factor no Film' AND Units='W/m2-K'"
      else
        # Compare R-value w/ film
        query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND (RowName='#{roof_id}' OR RowName LIKE '#{roof_id}:%') AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
      end
      sql_value = 1.0 / UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.1)

      # Net area
      hpxml_value = roof.area
      hpxml.skylights.each do |subsurface|
        next if subsurface.roof_idref.upcase != roof_id

        hpxml_value -= subsurface.area
      end
      query = "SELECT SUM(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND (RowName='#{roof_id}' OR RowName LIKE '#{roof_id}:%') AND ColumnName='Net Area' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_operator(sql_value, :>, 0.01)
      assert_in_epsilon(hpxml_value, sql_value, 0.1)

      # Solar absorptance
      hpxml_value = roof.solar_absorptance
      query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND (RowName='#{roof_id}' OR RowName LIKE '#{roof_id}:%') AND ColumnName='Reflectance'"
      sql_value = 1.0 - sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Tilt
      hpxml_value = UnitConversions.convert(Math.atan(roof.pitch / 12.0), 'rad', 'deg')
      query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND (RowName='#{roof_id}' OR RowName LIKE '#{roof_id}:%') AND ColumnName='Tilt' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Azimuth
      next unless (not roof.azimuth.nil?) && (Float(roof.pitch) > 0)

      hpxml_value = roof.azimuth
      query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND (RowName='#{roof_id}' OR RowName LIKE '#{roof_id}:%') AND ColumnName='Azimuth' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end

    # Enclosure Foundations
    # Ensure Kiva instances have perimeter fraction of 1.0 as we explicitly define them to end up this way.
    num_kiva_instances = 0
    File.readlines(File.join(rundir, 'eplusout.eio')).each do |eio_line|
      next unless eio_line.downcase.start_with? 'foundation kiva'

      kiva_perim_frac = Float(eio_line.split(',')[5])
      assert_equal(1.0, kiva_perim_frac)

      num_kiva_instances += 1
    end

    if hpxml_path.include? 'ASHRAE_Standard_140'
      # nop
    elsif hpxml_path.include? 'base-bldgtype-multifamily'
      assert_equal(0, num_kiva_instances)                                                # no foundation, above dwelling unit
    else
      num_expected_kiva_instances = { 'base-foundation-ambient.xml' => 0,                # no foundation in contact w/ ground
                                      'base-foundation-multiple.xml' => 2,               # additional instance for 2nd foundation type
                                      'base-enclosure-2stories-garage.xml' => 2,         # additional instance for garage
                                      'base-foundation-basement-garage.xml' => 2,        # additional instance for garage
                                      'base-enclosure-garage.xml' => 2,                  # additional instance for garage
                                      'base-foundation-walkout-basement.xml' => 4,       # 3 foundation walls plus a no-wall exposed perimeter
                                      'base-foundation-complex.xml' => 10,               # lots of foundations for testing
                                      'base-enclosure-split-surfaces2.xml' => 81 }       # lots of foundations for testing

      if not num_expected_kiva_instances[File.basename(hpxml_path)].nil?
        assert_equal(num_expected_kiva_instances[File.basename(hpxml_path)], num_kiva_instances)
      else
        assert_equal(1, num_kiva_instances)
      end
    end

    # Enclosure Foundation Slabs
    num_slabs = hpxml.slabs.size
    if (num_slabs <= 1) && (num_kiva_instances <= 1) # The slab surfaces may be combined in these situations, so skip tests
      hpxml.slabs.each do |slab|
        slab_id = slab.id.upcase

        # Exposed Area
        hpxml_value = Float(slab.area)
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{slab_id}' AND ColumnName='Gross Area' AND Units='m2'"
        sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
        assert_operator(sql_value, :>, 0.01)
        assert_in_epsilon(hpxml_value, sql_value, 0.1)

        # Tilt
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='Opaque Exterior' AND RowName='#{slab_id}' AND ColumnName='Tilt' AND Units='deg'"
        sql_value = sqlFile.execAndReturnFirstDouble(query).get
        assert_in_epsilon(180.0, sql_value, 0.01)
      end
    end

    # Enclosure Walls/RimJoists/FoundationWalls
    (hpxml.walls + hpxml.rim_joists + hpxml.foundation_walls).each do |wall|
      wall_id = wall.id.upcase

      if wall.is_adiabatic
        # Adiabatic surfaces have their "BaseSurfaceIndex" as their "ExtBoundCond" in "Surfaces" table in SQL simulation results
        query_base_surf_idx = "SELECT BaseSurfaceIndex FROM Surfaces WHERE SurfaceName='#{wall_id}'"
        query_ext_bound = "SELECT ExtBoundCond FROM Surfaces WHERE SurfaceName='#{wall_id}'"
        sql_value_base_surf_idx = sqlFile.execAndReturnFirstDouble(query_base_surf_idx).get
        sql_value_ext_bound_cond = sqlFile.execAndReturnFirstDouble(query_ext_bound).get
        assert_equal(sql_value_base_surf_idx, sql_value_ext_bound_cond)
      end

      if wall.is_exterior
        table_name = 'Opaque Exterior'
      else
        table_name = 'Opaque Interior'
      end

      # R-value
      if (not wall.insulation_assembly_r_value.nil?) && (not hpxml_path.include? 'base-foundation-unconditioned-basement-assembly-r.xml') # This file uses Foundation:Kiva for insulation, so skip it
        hpxml_value = wall.insulation_assembly_r_value
        if hpxml_path.include? 'ASHRAE_Standard_140'
          # Compare R-value w/o film
          hpxml_value -= Material.AirFilmVerticalASHRAE140.rvalue
          if wall.is_exterior
            hpxml_value -= Material.AirFilmOutsideASHRAE140.rvalue
          else
            hpxml_value -= Material.AirFilmVerticalASHRAE140.rvalue
          end
          query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='U-Factor no Film' AND Units='W/m2-K'"
        elsif wall.is_interior
          # Compare R-value w/o film
          hpxml_value -= Material.AirFilmVertical.rvalue
          hpxml_value -= Material.AirFilmVertical.rvalue
          query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='U-Factor no Film' AND Units='W/m2-K'"
        else
          # Compare R-value w/ film
          query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
        end
        sql_value = 1.0 / UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
        assert_in_epsilon(hpxml_value, sql_value, 0.1)
      end

      # Net area
      hpxml_value = wall.area
      (hpxml.windows + hpxml.doors).each do |subsurface|
        next if subsurface.wall_idref.upcase != wall_id

        hpxml_value -= subsurface.area
      end
      if wall.exterior_adjacent_to == HPXML::LocationGround
        # Calculate total length of walls
        wall_total_length = 0
        hpxml.foundation_walls.each do |foundation_wall|
          next unless foundation_wall.exterior_adjacent_to == HPXML::LocationGround
          next unless wall.interior_adjacent_to == foundation_wall.interior_adjacent_to

          wall_total_length += foundation_wall.area / foundation_wall.height
        end

        # Calculate total slab exposed perimeter
        slab_exposed_length = 0
        hpxml.slabs.each do |slab|
          next unless wall.interior_adjacent_to == slab.interior_adjacent_to

          slab_exposed_length += slab.exposed_perimeter
        end

        # Calculate exposed foundation wall area
        if slab_exposed_length < wall_total_length
          hpxml_value *= (slab_exposed_length / wall_total_length)
        end
      end
      if (hpxml.foundation_walls.include? wall) && (not wall.is_exterior)
        # interzonal foundation walls: only above-grade portion modeled
        hpxml_value *= (wall.height - wall.depth_below_grade) / wall.height
      end
      if wall.is_exterior
        query = "SELECT SUM(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%' OR RowName LIKE '#{wall_id} %') AND ColumnName='Net Area' AND Units='m2'"
      else
        query = "SELECT SUM(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='Net Area' AND Units='m2'"
      end
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_operator(sql_value, :>, 0.01)
      assert_in_epsilon(hpxml_value, sql_value, 0.1)

      # Solar absorptance
      if wall.respond_to? :solar_absorptance
        hpxml_value = wall.solar_absorptance
        query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='Reflectance'"
        sql_value = 1.0 - sqlFile.execAndReturnFirstDouble(query).get
        assert_in_epsilon(hpxml_value, sql_value, 0.01)
      end

      # Tilt
      query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='Tilt' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(90.0, sql_value, 0.01)

      # Azimuth
      next if wall.azimuth.nil?

      hpxml_value = wall.azimuth
      query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND (RowName='#{wall_id}' OR RowName LIKE '#{wall_id}:%') AND ColumnName='Azimuth' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end

    # Enclosure FrameFloors
    hpxml.frame_floors.each do |frame_floor|
      frame_floor_id = frame_floor.id.upcase

      if frame_floor.is_adiabatic
        # Adiabatic surfaces have their "BaseSurfaceIndex" as their "ExtBoundCond" in "Surfaces" table in SQL simulation results
        query_base_surf_idx = "SELECT BaseSurfaceIndex FROM Surfaces WHERE SurfaceName='#{frame_floor_id}'"
        query_ext_bound = "SELECT ExtBoundCond FROM Surfaces WHERE SurfaceName='#{frame_floor_id}'"
        sql_value_base_surf_idx = sqlFile.execAndReturnFirstDouble(query_base_surf_idx).get
        sql_value_ext_bound_cond = sqlFile.execAndReturnFirstDouble(query_ext_bound).get
        assert_equal(sql_value_base_surf_idx, sql_value_ext_bound_cond)
      end

      if frame_floor.is_exterior
        table_name = 'Opaque Exterior'
      else
        table_name = 'Opaque Interior'
      end

      # R-value
      hpxml_value = frame_floor.insulation_assembly_r_value
      if hpxml_path.include? 'ASHRAE_Standard_140'
        # Compare R-value w/o film
        if frame_floor.is_exterior # Raised floor
          hpxml_value -= Material.AirFilmFloorASHRAE140.rvalue
          hpxml_value -= Material.AirFilmFloorZeroWindASHRAE140.rvalue
        elsif frame_floor.is_ceiling # Attic floor
          hpxml_value -= Material.AirFilmFloorASHRAE140.rvalue
          hpxml_value -= Material.AirFilmFloorASHRAE140.rvalue
        end
        query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{frame_floor_id}' AND ColumnName='U-Factor no Film' AND Units='W/m2-K'"
      elsif frame_floor.is_interior
        # Compare R-value w/o film
        if frame_floor.is_ceiling
          hpxml_value -= Material.AirFilmFloorAverage.rvalue
          hpxml_value -= Material.AirFilmFloorAverage.rvalue
        else
          hpxml_value -= Material.AirFilmFloorReduced.rvalue
          hpxml_value -= Material.AirFilmFloorReduced.rvalue
        end
        query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{frame_floor_id}' AND ColumnName='U-Factor no Film' AND Units='W/m2-K'"
      else
        # Compare R-value w/ film
        query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{frame_floor_id}' AND ColumnName='U-Factor with Film' AND Units='W/m2-K'"
      end
      sql_value = 1.0 / UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.1)

      # Area
      hpxml_value = frame_floor.area
      query = "SELECT SUM(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{frame_floor_id}' AND ColumnName='Net Area' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_operator(sql_value, :>, 0.01)
      assert_in_epsilon(hpxml_value, sql_value, 0.1)

      # Tilt
      if frame_floor.is_ceiling
        hpxml_value = 0
      else
        hpxml_value = 180
      end
      query = "SELECT AVG(Value) FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{frame_floor_id}' AND ColumnName='Tilt' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)
    end

    # Enclosure Windows/Skylights
    (hpxml.windows + hpxml.skylights).each do |subsurface|
      subsurface_id = subsurface.id.upcase

      if subsurface.is_exterior
        table_name = 'Exterior Fenestration'
      else
        table_name = 'Interior Door'
      end

      # Area
      if subsurface.is_exterior
        col_name = 'Area of Multiplied Openings'
      else
        col_name = 'Gross Area'
      end
      hpxml_value = subsurface.area
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{subsurface_id}' AND ColumnName='#{col_name}' AND Units='m2'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
      assert_operator(sql_value, :>, 0.01)
      assert_in_epsilon(hpxml_value, sql_value, 0.1)

      # U-Factor
      if subsurface.is_exterior
        col_name = 'Glass U-Factor'
      else
        col_name = 'U-Factor no Film'
      end
      hpxml_value = subsurface.ufactor
      if subsurface.is_interior
        hpxml_value = 1.0 / (1.0 / hpxml_value - Material.AirFilmVertical.rvalue)
        hpxml_value = 1.0 / (1.0 / hpxml_value - Material.AirFilmVertical.rvalue)
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{subsurface_id}' AND ColumnName='#{col_name}' AND Units='W/m2-K'"
      sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      if subsurface.is_a? HPXML::Skylight
        sql_value *= 1.2 # Convert back from vertical position to NFRC 20-degree slope
      end
      assert_in_epsilon(hpxml_value, sql_value, 0.02)

      next unless subsurface.is_exterior

      # SHGC
      hpxml_value = subsurface.shgc
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{subsurface_id}' AND ColumnName='Glass SHGC'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_delta(hpxml_value, sql_value, 0.01)

      # Azimuth
      hpxml_value = subsurface.azimuth
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{subsurface_id}' AND ColumnName='Azimuth' AND Units='deg'"
      sql_value = sqlFile.execAndReturnFirstDouble(query).get
      assert_in_epsilon(hpxml_value, sql_value, 0.01)

      # Tilt
      if subsurface.respond_to? :wall_idref
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{subsurface_id}' AND ColumnName='Tilt' AND Units='deg'"
        sql_value = sqlFile.execAndReturnFirstDouble(query).get
        assert_in_epsilon(90.0, sql_value, 0.01)
      elsif subsurface.respond_to? :roof_idref
        hpxml_value = nil
        hpxml.roofs.each do |roof|
          next if roof.id != subsurface.roof_idref

          hpxml_value = UnitConversions.convert(Math.atan(roof.pitch / 12.0), 'rad', 'deg')
        end
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{subsurface_id}' AND ColumnName='Tilt' AND Units='deg'"
        sql_value = sqlFile.execAndReturnFirstDouble(query).get
        assert_in_epsilon(hpxml_value, sql_value, 0.01)
      else
        flunk "Subsurface '#{subsurface_id}' should have either AttachedToWall or AttachedToRoof element."
      end
    end

    # Enclosure Doors
    hpxml.doors.each do |door|
      door_id = door.id.upcase

      if door.wall.is_exterior
        table_name = 'Exterior Door'
      else
        table_name = 'Interior Door'
      end

      # Area
      if not door.area.nil?
        hpxml_value = door.area
        query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{door_id}' AND ColumnName='Gross Area' AND Units='m2'"
        sql_value = UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'm^2', 'ft^2')
        assert_operator(sql_value, :>, 0.01)
        assert_in_epsilon(hpxml_value, sql_value, 0.1)
      end

      # R-Value
      next if door.r_value.nil?

      if door.is_exterior
        col_name = 'U-Factor with Film'
      else
        col_name = 'U-Factor no Film'
      end
      hpxml_value = door.r_value
      if door.is_interior
        hpxml_value -= Material.AirFilmVertical.rvalue
        hpxml_value -= Material.AirFilmVertical.rvalue
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName='EnvelopeSummary' AND ReportForString='Entire Facility' AND TableName='#{table_name}' AND RowName='#{door_id}' AND ColumnName='#{col_name}' AND Units='W/m2-K'"
      sql_value = 1.0 / UnitConversions.convert(sqlFile.execAndReturnFirstDouble(query).get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      assert_in_epsilon(hpxml_value, sql_value, 0.1)
    end

    # HVAC Load Fractions
    if (not hpxml_path.include? 'location-miami') && (not hpxml_path.include? 'location-honolulu') && (not hpxml_path.include? 'location-phoenix')
      htg_energy = results.select { |k, v| (k.include?(': Heating (MBtu)') || k.include?(': Heating Fans/Pumps (MBtu)')) && !k.include?('Load') }.map { |k, v| v }.sum(0.0)
      assert_equal(hpxml.total_fraction_heat_load_served > 0, htg_energy > 0)
    end
    clg_energy = results.select { |k, v| (k.include?(': Cooling (MBtu)') || k.include?(': Cooling Fans/Pumps (MBtu)')) && !k.include?('Load') }.map { |k, v| v }.sum(0.0)
    assert_equal(hpxml.total_fraction_cool_load_served > 0, clg_energy > 0)

    # Mechanical Ventilation
    fan_cfis = hpxml.ventilation_fans.select { |vent_mech| vent_mech.used_for_whole_building_ventilation && (vent_mech.fan_type == HPXML::MechVentTypeCFIS) }
    fan_sup = hpxml.ventilation_fans.select { |vent_mech| vent_mech.used_for_whole_building_ventilation && (vent_mech.fan_type == HPXML::MechVentTypeSupply) }
    fan_exh = hpxml.ventilation_fans.select { |vent_mech| vent_mech.used_for_whole_building_ventilation && (vent_mech.fan_type == HPXML::MechVentTypeExhaust) }
    fan_bal = hpxml.ventilation_fans.select { |vent_mech| vent_mech.used_for_whole_building_ventilation && [HPXML::MechVentTypeBalanced, HPXML::MechVentTypeERV, HPXML::MechVentTypeHRV].include?(vent_mech.fan_type) }
    vent_fan_kitchen = hpxml.ventilation_fans.select { |vent_mech| vent_mech.used_for_local_ventilation && (vent_mech.fan_location == HPXML::LocationKitchen) }
    vent_fan_bath = hpxml.ventilation_fans.select { |vent_mech| vent_mech.used_for_local_ventilation && (vent_mech.fan_location == HPXML::LocationBath) }

    if not (fan_cfis + fan_sup + fan_exh + fan_bal + vent_fan_kitchen + vent_fan_bath).empty?
      mv_energy = UnitConversions.convert(results['End Use: Electricity: Mech Vent (MBtu)'], 'MBtu', 'GJ')

      if not fan_cfis.empty?
        if (fan_sup + fan_exh + fan_bal + vent_fan_kitchen + vent_fan_bath).empty?
          # CFIS only, check for positive mech vent energy that is less than the energy if it had run 24/7
          fan_gj = fan_cfis.map { |vent_mech| UnitConversions.convert(vent_mech.unit_fan_power * vent_mech.hours_in_operation * 365.0, 'Wh', 'GJ') }.sum(0.0)
          assert_operator(mv_energy, :>, 0)
          assert_operator(mv_energy, :<, fan_gj)
        end
      else
        # Supply, exhaust, ERV, HRV, etc., check for appropriate mech vent energy
        fan_gj = 0
        if not fan_sup.empty?
          fan_gj += fan_sup.map { |vent_mech| UnitConversions.convert(vent_mech.unit_fan_power * vent_mech.hours_in_operation * 365.0, 'Wh', 'GJ') }.sum(0.0)
        end
        if not fan_exh.empty?
          fan_gj += fan_exh.map { |vent_mech| UnitConversions.convert(vent_mech.unit_fan_power * vent_mech.hours_in_operation * 365.0, 'Wh', 'GJ') }.sum(0.0)
        end
        if not fan_bal.empty?
          fan_gj += fan_bal.map { |vent_mech| UnitConversions.convert(vent_mech.unit_fan_power * vent_mech.hours_in_operation * 365.0, 'Wh', 'GJ') }.sum(0.0)
        end
        if not vent_fan_kitchen.empty?
          fan_gj += vent_fan_kitchen.map { |vent_kitchen| UnitConversions.convert(vent_kitchen.unit_fan_power * vent_kitchen.hours_in_operation * vent_kitchen.quantity * 365.0, 'Wh', 'GJ') }.sum(0.0)
        end
        if not vent_fan_bath.empty?
          fan_gj += vent_fan_bath.map { |vent_bath| UnitConversions.convert(vent_bath.unit_fan_power * vent_bath.hours_in_operation * vent_bath.quantity * 365.0, 'Wh', 'GJ') }.sum(0.0)
        end
        # Maximum error that can be caused by rounding
        assert_in_delta(mv_energy, fan_gj, 0.006)
      end
    end

    # Clothes Washer
    if (hpxml.clothes_washers.size > 0) && (hpxml.water_heating_systems.size > 0)
      # Location
      hpxml_value = hpxml.clothes_washers[0].location
      if hpxml_value.nil? || [HPXML::LocationBasementConditioned, HPXML::LocationOtherHousingUnit, HPXML::LocationOtherHeatedSpace, HPXML::LocationOtherMultifamilyBufferSpace, HPXML::LocationOtherNonFreezingSpace].include?(hpxml_value)
        hpxml_value = HPXML::LocationLivingSpace
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Zone Name' AND RowName=(SELECT RowName FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Name' AND Value='#{Constants.ObjectNameClothesWasher.upcase}')"
      sql_value = sqlFile.execAndReturnFirstString(query).get
      assert_equal(hpxml_value.upcase, sql_value)
    end

    # Clothes Dryer
    if (hpxml.clothes_dryers.size > 0) && (hpxml.water_heating_systems.size > 0)
      # Location
      hpxml_value = hpxml.clothes_dryers[0].location
      if hpxml_value.nil? || [HPXML::LocationBasementConditioned, HPXML::LocationOtherHousingUnit, HPXML::LocationOtherHeatedSpace, HPXML::LocationOtherMultifamilyBufferSpace, HPXML::LocationOtherNonFreezingSpace].include?(hpxml_value)
        hpxml_value = HPXML::LocationLivingSpace
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Zone Name' AND RowName=(SELECT RowName FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Name' AND Value='#{Constants.ObjectNameClothesDryer.upcase}')"
      sql_value = sqlFile.execAndReturnFirstString(query).get
      assert_equal(hpxml_value.upcase, sql_value)
    end

    # Refrigerator
    if hpxml.refrigerators.size > 0
      # Location
      hpxml_value = hpxml.refrigerators[0].location
      if hpxml_value.nil? || [HPXML::LocationBasementConditioned, HPXML::LocationOtherHousingUnit, HPXML::LocationOtherHeatedSpace, HPXML::LocationOtherMultifamilyBufferSpace, HPXML::LocationOtherNonFreezingSpace].include?(hpxml_value)
        hpxml_value = HPXML::LocationLivingSpace
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Zone Name' AND RowName=(SELECT RowName FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Name' AND Value='#{Constants.ObjectNameRefrigerator.upcase}')"
      sql_value = sqlFile.execAndReturnFirstString(query).get
      assert_equal(hpxml_value.upcase, sql_value)
    end

    # DishWasher
    if (hpxml.dishwashers.size > 0) && (hpxml.water_heating_systems.size > 0)
      # Location
      hpxml_value = hpxml.dishwashers[0].location
      if hpxml_value.nil? || [HPXML::LocationBasementConditioned, HPXML::LocationOtherHousingUnit, HPXML::LocationOtherHeatedSpace, HPXML::LocationOtherMultifamilyBufferSpace, HPXML::LocationOtherNonFreezingSpace].include?(hpxml_value)
        hpxml_value = HPXML::LocationLivingSpace
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Zone Name' AND RowName=(SELECT RowName FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Name' AND Value='#{Constants.ObjectNameDishwasher.upcase}')"
      sql_value = sqlFile.execAndReturnFirstString(query).get
      assert_equal(hpxml_value.upcase, sql_value)
    end

    # Cooking Range
    if hpxml.cooking_ranges.size > 0
      # Location
      hpxml_value = hpxml.cooking_ranges[0].location
      if hpxml_value.nil? || [HPXML::LocationBasementConditioned, HPXML::LocationOtherHousingUnit, HPXML::LocationOtherHeatedSpace, HPXML::LocationOtherMultifamilyBufferSpace, HPXML::LocationOtherNonFreezingSpace].include?(hpxml_value)
        hpxml_value = HPXML::LocationLivingSpace
      end
      query = "SELECT Value FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Zone Name' AND RowName=(SELECT RowName FROM TabularDataWithStrings WHERE TableName='ElectricEquipment Internal Gains Nominal' AND ColumnName='Name' AND Value='#{Constants.ObjectNameCookingRange.upcase}')"
      sql_value = sqlFile.execAndReturnFirstString(query).get
      assert_equal(hpxml_value.upcase, sql_value)
    end

    # Lighting
    ltg_energy = results.select { |k, v| k.include? 'End Use: Electricity: Lighting' }.map { |k, v| v }.sum(0.0)
    if hpxml.header.schedules_path.nil?
      assert_equal(hpxml.lighting_groups.size > 0, ltg_energy > 0)
    end

    # Get fuels
    htg_fuels = []
    hpxml.heating_systems.each do |heating_system|
      htg_fuels << heating_system.heating_system_fuel
    end
    hpxml.heat_pumps.each do |heat_pump|
      htg_fuels << heat_pump.backup_heating_fuel
    end
    wh_fuels = []
    hpxml.water_heating_systems.each do |water_heating_system|
      related_hvac = water_heating_system.related_hvac_system
      if related_hvac.nil?
        wh_fuels << water_heating_system.fuel_type
      elsif related_hvac.respond_to? :heating_system_fuel
        wh_fuels << related_hvac.heating_system_fuel
      end
    end

    # Fuel consumption checks
    [HPXML::FuelTypeNaturalGas,
     HPXML::FuelTypeOil,
     HPXML::FuelTypeKerosene,
     HPXML::FuelTypePropane,
     HPXML::FuelTypeWoodCord,
     HPXML::FuelTypeWoodPellets,
     HPXML::FuelTypeCoal].each do |fuel|
      fuel_name = fuel.split.map(&:capitalize).join(' ')
      fuel_name += ' Cord' if fuel_name == 'Wood'
      energy_htg = results.fetch("End Use: #{fuel_name}: Heating (MBtu)", 0)
      energy_dhw = results.fetch("End Use: #{fuel_name}: Hot Water (MBtu)", 0)
      energy_cd = results.fetch("End Use: #{fuel_name}: Clothes Dryer (MBtu)", 0)
      energy_cr = results.fetch("End Use: #{fuel_name}: Range/Oven (MBtu)", 0)
      if htg_fuels.include?(fuel) && (not hpxml_path.include? 'location-miami') && (not hpxml_path.include? 'location-honolulu') && (not hpxml_path.include? 'location-phoenix')
        assert_operator(energy_htg, :>, 0)
      else
        assert_equal(0, energy_htg)
      end
      if wh_fuels.include? fuel
        assert_operator(energy_dhw, :>, 0)
      else
        assert_equal(0, energy_dhw)
      end
      if (hpxml.clothes_dryers.size > 0) && (hpxml.clothes_dryers[0].fuel_type == fuel)
        assert_operator(energy_cd, :>, 0)
      else
        assert_equal(0, energy_cd)
      end
      if (hpxml.cooking_ranges.size > 0) && (hpxml.cooking_ranges[0].fuel_type == fuel)
        assert_operator(energy_cr, :>, 0)
      else
        assert_equal(0, energy_cr)
      end
    end

    # Check unmet loads
    unmet_htg_load = results.select { |k, v| k.include? 'Unmet Load: Heating' }.map { |k, v| v }.sum(0.0)
    unmet_clg_load = results.select { |k, v| k.include? 'Unmet Load: Cooling' }.map { |k, v| v }.sum(0.0)
    if hpxml_path.include? 'base-hvac-undersized.xml'
      assert_operator(unmet_htg_load, :>, 0.5)
      assert_operator(unmet_clg_load, :>, 0.5)
    else
      assert_operator(unmet_htg_load, :<, 0.5)
      assert_operator(unmet_clg_load, :<, 0.5)
    end

    sqlFile.close
  end

  def _write_summary_results(results, csv_out)
    require 'csv'

    output_keys = []
    results.each do |xml, xml_results|
      output_keys = xml_results.keys
      break
    end

    column_headers = ['HPXML']
    output_keys.each do |key|
      column_headers << key
    end

    CSV.open(csv_out, 'w') do |csv|
      csv << column_headers
      results.sort.each do |xml, xml_results|
        csv_row = [xml]
        output_keys.each do |key|
          if xml_results[key].nil?
            csv_row << 0
          else
            csv_row << xml_results[key]
          end
        end
        csv << csv_row
      end
    end

    puts "Wrote summary results to #{csv_out}."
  end

  def _write_hvac_sizing_results(all_sizing_results, csv_out)
    require 'csv'

    output_keys = nil
    all_sizing_results.each do |xml, xml_results|
      output_keys = xml_results.keys
      break
    end
    return if output_keys.nil?

    CSV.open(csv_out, 'w') do |csv|
      csv << ['HPXML'] + output_keys
      all_sizing_results.sort.each do |xml, xml_results|
        csv_row = [xml]
        output_keys.each do |key|
          csv_row << xml_results[key]
        end
        csv << csv_row
      end
    end

    puts "Wrote HVAC sizing results to #{csv_out}."
  end

  def _write_ashrae_140_results(all_results, csv_out)
    require 'csv'

    htg_loads = {}
    clg_loads = {}
    CSV.open(csv_out, 'w') do |csv|
      csv << ['Test Case', 'Annual Heating Load [MMBtu]', 'Annual Cooling Load [MMBtu]']
      all_results.sort.each do |xml, xml_results|
        next unless xml.include? 'C.xml'

        htg_load = xml_results['Load: Heating (MBtu)'].round(2)
        csv << [File.basename(xml), htg_load, 'N/A']
        test_name = File.basename(xml, File.extname(xml))
        htg_loads[test_name] = htg_load
      end
      all_results.sort.each do |xml, xml_results|
        next unless xml.include? 'L.xml'

        clg_load = xml_results['Load: Cooling (MBtu)'].round(2)
        csv << [File.basename(xml), 'N/A', clg_load]
        test_name = File.basename(xml, File.extname(xml))
        clg_loads[test_name] = clg_load
      end
    end

    puts "Wrote ASHRAE 140 results to #{csv_out}."
  end
end
