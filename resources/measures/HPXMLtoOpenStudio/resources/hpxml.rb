# frozen_string_literal: true

require_relative 'xmlhelper'

class HPXML
  def self.create_hpxml(xml_type:,
                        xml_generated_by:,
                        transaction:,
                        software_program_used:,
                        software_program_version:,
                        eri_calculation_version:,
                        building_id:,
                        event_type:,
                        **remainder)
    doc = XMLHelper.create_doc(version = '1.0', encoding = 'UTF-8')
    hpxml = XMLHelper.add_element(doc, 'HPXML')
    XMLHelper.add_attribute(hpxml, 'xmlns', 'http://hpxmlonline.com/2014/6')
    XMLHelper.add_attribute(hpxml, 'xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance')
    XMLHelper.add_attribute(hpxml, 'xsi:schemaLocation', 'http://hpxmlonline.com/2014/6')
    XMLHelper.add_attribute(hpxml, 'schemaVersion', '3.0')

    header = XMLHelper.add_element(hpxml, 'XMLTransactionHeaderInformation')
    XMLHelper.add_element(header, 'XMLType', xml_type)
    XMLHelper.add_element(header, 'XMLGeneratedBy', xml_generated_by)
    XMLHelper.add_element(header, 'CreatedDateAndTime', Time.now.strftime('%Y-%m-%dT%H:%M:%S%:z'))
    XMLHelper.add_element(header, 'Transaction', transaction)

    software_info = XMLHelper.add_element(hpxml, 'SoftwareInfo')
    XMLHelper.add_element(software_info, 'SoftwareProgramUsed', software_program_used)
    XMLHelper.add_element(software_info, 'SoftwareProgramVersion', software_program_version)
    eri_calculation = XMLHelper.add_element(software_info, 'extension/ERICalculation')
    XMLHelper.add_element(eri_calculation, 'Version', eri_calculation_version)

    building = XMLHelper.add_element(hpxml, 'Building')
    building_building_id = XMLHelper.add_element(building, 'BuildingID')
    XMLHelper.add_attribute(building_building_id, 'id', building_id)
    project_status = XMLHelper.add_element(building, 'ProjectStatus')
    XMLHelper.add_element(project_status, 'EventType', event_type)

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:schema_version, :created_date_and_time])

    return doc
  end

  def self.get_hpxml_values(hpxml:)
    return if hpxml.nil?

    return { schema_version: hpxml.attributes['schemaVersion'],
             xml_type: XMLHelper.get_value(hpxml, 'XMLTransactionHeaderInformation/XMLType'),
             xml_generated_by: XMLHelper.get_value(hpxml, 'XMLTransactionHeaderInformation/XMLGeneratedBy'),
             created_date_and_time: XMLHelper.get_value(hpxml, 'XMLTransactionHeaderInformation/CreatedDateAndTime'),
             transaction: XMLHelper.get_value(hpxml, 'XMLTransactionHeaderInformation/Transaction'),
             software_program_used: XMLHelper.get_value(hpxml, 'SoftwareInfo/SoftwareProgramUsed'),
             software_program_version: XMLHelper.get_value(hpxml, 'SoftwareInfo/SoftwareProgramVersion'),
             eri_calculation_version: XMLHelper.get_value(hpxml, 'SoftwareInfo/extension/ERICalculation/Version'),
             building_id: HPXML.get_id(hpxml, 'Building/BuildingID'),
             event_type: XMLHelper.get_value(hpxml, 'Building/ProjectStatus/EventType') }
  end

  def self.add_site(hpxml:,
                    fuels: [],
                    shelter_coefficient: nil,
                    **remainder)
    site = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'BuildingSummary', 'Site'])
    unless fuels.empty?
      fuel_types_available = XMLHelper.add_element(site, 'FuelTypesAvailable')
      fuels.each do |fuel|
        XMLHelper.add_element(fuel_types_available, 'Fuel', fuel)
      end
    end
    HPXML.add_extension(parent: site,
                        extensions: { 'ShelterCoefficient' => to_float(shelter_coefficient) })

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:surroundings, :orientation_of_front_of_home])

    return site
  end

  def self.get_site_values(site:)
    return if site.nil?

    return { surroundings: XMLHelper.get_value(site, 'Surroundings'),
             orientation_of_front_of_home: XMLHelper.get_value(site, 'OrientationOfFrontOfHome'),
             fuels: XMLHelper.get_values(site, 'FuelTypesAvailable/Fuel'),
             shelter_coefficient: to_float(XMLHelper.get_value(site, 'extension/ShelterCoefficient')) }
  end

  def self.add_building_occupancy(hpxml:,
                                  number_of_residents: nil,
                                  **remainder)
    building_occupancy = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'BuildingSummary', 'BuildingOccupancy'])
    XMLHelper.add_element(building_occupancy, 'NumberofResidents', to_float(number_of_residents)) unless number_of_residents.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return building_occupancy
  end

  def self.get_building_occupancy_values(building_occupancy:)
    return if building_occupancy.nil?

    return { number_of_residents: to_float(XMLHelper.get_value(building_occupancy, 'NumberofResidents')) }
  end

  def self.add_building_construction(hpxml:,
                                     number_of_conditioned_floors: nil,
                                     number_of_conditioned_floors_above_grade: nil,
                                     average_ceiling_height: nil,
                                     number_of_bedrooms: nil,
                                     conditioned_floor_area: nil,
                                     conditioned_building_volume: nil,
                                     garage_present: nil,
                                     **remainder)
    building_construction = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'BuildingSummary', 'BuildingConstruction'])
    XMLHelper.add_element(building_construction, 'NumberofConditionedFloors', to_integer(number_of_conditioned_floors)) unless number_of_conditioned_floors.nil?
    XMLHelper.add_element(building_construction, 'NumberofConditionedFloorsAboveGrade', to_integer(number_of_conditioned_floors_above_grade)) unless number_of_conditioned_floors_above_grade.nil?
    XMLHelper.add_element(building_construction, 'AverageCeilingHeight', to_float(average_ceiling_height)) unless average_ceiling_height.nil?
    XMLHelper.add_element(building_construction, 'NumberofBedrooms', to_integer(number_of_bedrooms)) unless number_of_bedrooms.nil?
    XMLHelper.add_element(building_construction, 'ConditionedFloorArea', to_float(conditioned_floor_area)) unless conditioned_floor_area.nil?
    XMLHelper.add_element(building_construction, 'ConditionedBuildingVolume', to_float(conditioned_building_volume)) unless conditioned_building_volume.nil?
    XMLHelper.add_element(building_construction, 'GaragePresent', to_bool(garage_present)) unless garage_present.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return building_construction
  end

  def self.get_building_construction_values(building_construction:)
    return if building_construction.nil?

    return { number_of_conditioned_floors: to_integer(XMLHelper.get_value(building_construction, 'NumberofConditionedFloors')),
             number_of_conditioned_floors_above_grade: to_integer(XMLHelper.get_value(building_construction, 'NumberofConditionedFloorsAboveGrade')),
             average_ceiling_height: to_float(XMLHelper.get_value(building_construction, 'AverageCeilingHeight')),
             number_of_bedrooms: to_integer(XMLHelper.get_value(building_construction, 'NumberofBedrooms')),
             conditioned_floor_area: to_float(XMLHelper.get_value(building_construction, 'ConditionedFloorArea')),
             conditioned_building_volume: to_float(XMLHelper.get_value(building_construction, 'ConditionedBuildingVolume')),
             garage_present: to_bool(XMLHelper.get_value(building_construction, 'GaragePresent')) }
  end

  def self.add_climate_zone_iecc(hpxml:,
                                 year: nil,
                                 climate_zone: nil,
                                 **remainder)
    zones = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'ClimateandRiskZones'])
    climate_zone_iecc = XMLHelper.add_element(zones, 'ClimateZoneIECC')
    XMLHelper.add_element(climate_zone_iecc, 'Year', to_integer(year)) unless year.nil?
    XMLHelper.add_element(climate_zone_iecc, 'ClimateZone', climate_zone) unless climate_zone.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return climate_zone_iecc
  end

  def self.get_climate_zone_iecc_values(climate_zone_iecc:)
    return if climate_zone_iecc.nil?

    return { year: to_integer(XMLHelper.get_value(climate_zone_iecc, 'Year')),
             climate_zone: XMLHelper.get_value(climate_zone_iecc, 'ClimateZone') }
  end

  def self.add_weather_station(hpxml:,
                               id:,
                               name: nil,
                               wmo: nil,
                               **remainder)
    zones = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'ClimateandRiskZones'])
    weather_station = XMLHelper.add_element(zones, 'WeatherStation')
    sys_id = XMLHelper.add_element(weather_station, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(weather_station, 'Name', name) unless name.nil?
    XMLHelper.add_element(weather_station, 'WMO', wmo) unless wmo.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return weather_station
  end

  def self.get_weather_station_values(weather_station:)
    return if weather_station.nil?

    return { id: HPXML.get_id(weather_station),
             name: XMLHelper.get_value(weather_station, 'Name'),
             wmo: XMLHelper.get_value(weather_station, 'WMO') }
  end

  def self.add_air_infiltration_measurement(hpxml:,
                                            id:,
                                            house_pressure: nil,
                                            unit_of_measure: nil,
                                            air_leakage: nil,
                                            effective_leakage_area: nil,
                                            constant_ach_natural: nil,
                                            infiltration_volume: nil,
                                            **remainder)
    air_infiltration = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Enclosure', 'AirInfiltration'])
    air_infiltration_measurement = XMLHelper.add_element(air_infiltration, 'AirInfiltrationMeasurement')
    sys_id = XMLHelper.add_element(air_infiltration_measurement, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(air_infiltration_measurement, 'HousePressure', to_float(house_pressure)) unless house_pressure.nil?
    if (not unit_of_measure.nil?) && (not air_leakage.nil?)
      building_air_leakage = XMLHelper.add_element(air_infiltration_measurement, 'BuildingAirLeakage')
      XMLHelper.add_element(building_air_leakage, 'UnitofMeasure', unit_of_measure)
      XMLHelper.add_element(building_air_leakage, 'AirLeakage', to_float(air_leakage))
    end
    XMLHelper.add_element(air_infiltration_measurement, 'EffectiveLeakageArea', to_float(effective_leakage_area)) unless effective_leakage_area.nil?
    XMLHelper.add_element(air_infiltration_measurement, 'InfiltrationVolume', to_float(infiltration_volume)) unless infiltration_volume.nil?
    HPXML.add_extension(parent: air_infiltration_measurement,
                        extensions: { 'ConstantACHnatural' => to_float(constant_ach_natural) })

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return air_infiltration_measurement
  end

  def self.get_air_infiltration_measurement_values(air_infiltration_measurement:)
    return if air_infiltration_measurement.nil?

    return { id: HPXML.get_id(air_infiltration_measurement),
             house_pressure: to_float(XMLHelper.get_value(air_infiltration_measurement, 'HousePressure')),
             unit_of_measure: XMLHelper.get_value(air_infiltration_measurement, 'BuildingAirLeakage/UnitofMeasure'),
             air_leakage: to_float(XMLHelper.get_value(air_infiltration_measurement, 'BuildingAirLeakage/AirLeakage')),
             effective_leakage_area: to_float(XMLHelper.get_value(air_infiltration_measurement, 'EffectiveLeakageArea')),
             infiltration_volume: to_float(XMLHelper.get_value(air_infiltration_measurement, 'InfiltrationVolume')),
             constant_ach_natural: to_float(XMLHelper.get_value(air_infiltration_measurement, 'extension/ConstantACHnatural')) }
  end

  def self.add_attic(hpxml:,
                     id:,
                     attic_type: nil,
                     specific_leakage_area: nil,
                     **remainder)
    attics = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Enclosure', 'Attics'])
    attic = XMLHelper.add_element(attics, 'Attic')
    sys_id = XMLHelper.add_element(attic, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    unless attic_type.nil?
      attic_type_e = XMLHelper.add_element(attic, 'AtticType')
      if attic_type == 'UnventedAttic'
        attic_type_attic = XMLHelper.add_element(attic_type_e, 'Attic')
        XMLHelper.add_element(attic_type_attic, 'Vented', false)
      elsif attic_type == 'VentedAttic'
        attic_type_attic = XMLHelper.add_element(attic_type_e, 'Attic')
        XMLHelper.add_element(attic_type_attic, 'Vented', true)
        XMLHelper.add_element(attic_type_attic, 'SpecificLeakageArea', to_float(specific_leakage_area)) unless specific_leakage_area.nil?
      elsif attic_type == 'ConditionedAttic'
        attic_type_attic = XMLHelper.add_element(attic_type_e, 'Attic')
        XMLHelper.add_element(attic_type_attic, 'Conditioned', true)
      elsif (attic_type == 'FlatRoof') || (attic_type == 'CathedralCeiling')
        XMLHelper.add_element(attic_type_e, attic_type)
      else
        fail "Unhandled attic type '#{attic_type}'."
      end
    end

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:attic_constant_ach_natural])

    return attic
  end

  def self.get_attic_values(attic:)
    return if attic.nil?

    attic_type = nil
    if XMLHelper.has_element(attic, "AtticType/Attic[Vented='false']")
      attic_type = 'UnventedAttic'
    elsif XMLHelper.has_element(attic, "AtticType/Attic[Vented='true']")
      attic_type = 'VentedAttic'
    elsif XMLHelper.has_element(attic, "AtticType/Attic[Conditioned='true']")
      attic_type = 'ConditionedAttic'
    elsif XMLHelper.has_element(attic, 'AtticType/FlatRoof')
      attic_type = 'FlatRoof'
    elsif XMLHelper.has_element(attic, 'AtticType/CathedralCeiling')
      attic_type = 'CathedralCeiling'
    end

    return { id: HPXML.get_id(attic),
             attic_type: attic_type,
             specific_leakage_area: to_float(XMLHelper.get_value(attic, "AtticType/Attic[Vented='true']/SpecificLeakageArea")),
             attic_constant_ach_natural: to_float(XMLHelper.get_value(attic, 'extension/AtticConstantACHnatural')) }
  end

  def self.add_attic_roof(attic:,
                          id:,
                          area: nil,
                          azimuth: nil,
                          solar_absorptance: nil,
                          emittance: nil,
                          pitch: nil,
                          radiant_barrier: nil,
                          insulation_id: nil,
                          insulation_assembly_r_value: nil,
                          **remainder)
    roofs = XMLHelper.create_elements_as_needed(attic, ['Roofs'])
    roof = XMLHelper.add_element(roofs, 'Roof')
    sys_id = XMLHelper.add_element(roof, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(roof, 'Area', to_float(area)) unless area.nil?
    XMLHelper.add_element(roof, 'Azimuth', to_integer(azimuth)) unless azimuth.nil?
    XMLHelper.add_element(roof, 'SolarAbsorptance', to_float(solar_absorptance)) unless solar_absorptance.nil?
    XMLHelper.add_element(roof, 'Emittance', to_float(emittance)) unless emittance.nil?
    XMLHelper.add_element(roof, 'Pitch', to_float(pitch)) unless pitch.nil?
    XMLHelper.add_element(roof, 'RadiantBarrier', to_bool(radiant_barrier)) unless radiant_barrier.nil?
    add_assembly_insulation(parent: roof,
                            id: insulation_id,
                            assembly_r_value: to_float(insulation_assembly_r_value))

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:roof_type, :roof_color])

    return roof
  end

  def self.get_attic_roof_values(roof:)
    return if roof.nil?

    insulation_values = get_assembly_insulation_values(insulation: roof.elements['Insulation'])

    return { id: HPXML.get_id(roof),
             area: to_float(XMLHelper.get_value(roof, 'Area')),
             azimuth: to_integer(XMLHelper.get_value(roof, 'Azimuth')),
             roof_type: XMLHelper.get_value(roof, 'RoofType'),
             roof_color: XMLHelper.get_value(roof, 'RoofColor'),
             solar_absorptance: to_float(XMLHelper.get_value(roof, 'SolarAbsorptance')),
             emittance: to_float(XMLHelper.get_value(roof, 'Emittance')),
             pitch: to_float(XMLHelper.get_value(roof, 'Pitch')),
             radiant_barrier: to_bool(XMLHelper.get_value(roof, 'RadiantBarrier')),
             insulation_id: insulation_values[:id],
             insulation_assembly_r_value: to_float(insulation_values[:assembly_r_value]) }
  end

  def self.add_attic_floor(attic:,
                           id:,
                           adjacent_to: nil,
                           area: nil,
                           insulation_id: nil,
                           insulation_assembly_r_value: nil,
                           **remainder)
    floors = XMLHelper.create_elements_as_needed(attic, ['Floors'])
    floor = XMLHelper.add_element(floors, 'Floor')
    sys_id = XMLHelper.add_element(floor, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(floor, 'AdjacentTo', adjacent_to) unless adjacent_to.nil?
    XMLHelper.add_element(floor, 'Area', to_float(area)) unless area.nil?
    add_assembly_insulation(parent: floor,
                            id: insulation_id,
                            assembly_r_value: to_float(insulation_assembly_r_value))

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return floor
  end

  def self.get_attic_floor_values(floor:)
    return if floor.nil?

    insulation_values = get_assembly_insulation_values(insulation: floor.elements['Insulation'])

    return { id: HPXML.get_id(floor),
             adjacent_to: XMLHelper.get_value(floor, 'AdjacentTo'),
             area: to_float(XMLHelper.get_value(floor, 'Area')),
             insulation_id: insulation_values[:id],
             insulation_assembly_r_value: to_float(insulation_values[:assembly_r_value]) }
  end

  def self.add_attic_wall(attic:,
                          id:,
                          adjacent_to: nil,
                          wall_type: nil,
                          area: nil,
                          azimuth: nil,
                          solar_absorptance: nil,
                          emittance: nil,
                          insulation_id: nil,
                          insulation_assembly_r_value: nil,
                          **remainder)
    walls = XMLHelper.create_elements_as_needed(attic, ['Walls'])
    wall = XMLHelper.add_element(walls, 'Wall')
    sys_id = XMLHelper.add_element(wall, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(wall, 'AdjacentTo', adjacent_to) unless adjacent_to.nil?
    unless wall_type.nil?
      wall_type_e = XMLHelper.add_element(wall, 'WallType')
      XMLHelper.add_element(wall_type_e, wall_type)
    end
    XMLHelper.add_element(wall, 'Area', to_float(area)) unless area.nil?
    XMLHelper.add_element(wall, 'Azimuth', to_integer(azimuth)) unless azimuth.nil?
    XMLHelper.add_element(wall, 'SolarAbsorptance', to_float(solar_absorptance)) unless solar_absorptance.nil?
    XMLHelper.add_element(wall, 'Emittance', to_float(emittance)) unless emittance.nil?
    add_assembly_insulation(parent: wall,
                            id: insulation_id,
                            assembly_r_value: to_float(insulation_assembly_r_value))

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:orientation, :siding])

    return wall
  end

  def self.get_attic_wall_values(wall:)
    return if wall.nil?

    insulation_values = get_assembly_insulation_values(insulation: wall.elements['Insulation'])

    return { id: HPXML.get_id(wall),
             adjacent_to: XMLHelper.get_value(wall, 'AdjacentTo'),
             wall_type: XMLHelper.get_child_name(wall, 'WallType'),
             area: to_float(XMLHelper.get_value(wall, 'Area')),
             orientation: XMLHelper.get_value(wall, 'Orientation'),
             azimuth: to_integer(XMLHelper.get_value(wall, 'Azimuth')),
             siding: XMLHelper.get_value(wall, 'Siding'),
             solar_absorptance: to_float(XMLHelper.get_value(wall, 'SolarAbsorptance')),
             emittance: to_float(XMLHelper.get_value(wall, 'Emittance')),
             insulation_id: insulation_values[:id],
             insulation_assembly_r_value: to_float(insulation_values[:assembly_r_value]) }
  end

  def self.add_foundation(hpxml:,
                          id:,
                          foundation_type: nil,
                          specific_leakage_area: nil,
                          **remainder)
    foundations = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Enclosure', 'Foundations'])
    foundation = XMLHelper.add_element(foundations, 'Foundation')
    sys_id = XMLHelper.add_element(foundation, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    unless foundation_type.nil?
      foundation_type_e = XMLHelper.add_element(foundation, 'FoundationType')
      if ['SlabOnGrade', 'Ambient'].include? foundation_type
        XMLHelper.add_element(foundation_type_e, foundation_type)
      elsif foundation_type == 'ConditionedBasement'
        basement = XMLHelper.add_element(foundation_type_e, 'Basement')
        XMLHelper.add_element(basement, 'Conditioned', true)
      elsif foundation_type == 'UnconditionedBasement'
        basement = XMLHelper.add_element(foundation_type_e, 'Basement')
        XMLHelper.add_element(basement, 'Conditioned', false)
      elsif foundation_type == 'VentedCrawlspace'
        crawlspace = XMLHelper.add_element(foundation_type_e, 'Crawlspace')
        XMLHelper.add_element(crawlspace, 'Vented', true)
        XMLHelper.add_element(crawlspace, 'SpecificLeakageArea', to_float(specific_leakage_area)) unless specific_leakage_area.nil?
      elsif foundation_type == 'UnventedCrawlspace'
        crawlspace = XMLHelper.add_element(foundation_type_e, 'Crawlspace')
        XMLHelper.add_element(crawlspace, 'Vented', false)
      else
        fail "Unhandled foundation type '#{foundation_type}'."
      end
    end

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return foundation
  end

  def self.get_foundation_values(foundation:)
    return if foundation.nil?

    foundation_type = nil
    if XMLHelper.has_element(foundation, 'FoundationType/SlabOnGrade')
      foundation_type = 'SlabOnGrade'
    elsif XMLHelper.has_element(foundation, "FoundationType/Basement[Conditioned='false']")
      foundation_type = 'UnconditionedBasement'
    elsif XMLHelper.has_element(foundation, "FoundationType/Basement[Conditioned='true']")
      foundation_type = 'ConditionedBasement'
    elsif XMLHelper.has_element(foundation, "FoundationType/Crawlspace[Vented='false']")
      foundation_type = 'UnventedCrawlspace'
    elsif XMLHelper.has_element(foundation, "FoundationType/Crawlspace[Vented='true']")
      foundation_type = 'VentedCrawlspace'
    elsif XMLHelper.has_element(foundation, 'FoundationType/Ambient')
      foundation_type = 'Ambient'
    end

    return { id: HPXML.get_id(foundation),
             foundation_type: foundation_type,
             specific_leakage_area: to_float(XMLHelper.get_value(foundation, "FoundationType/Crawlspace[Vented='true']/SpecificLeakageArea")) }
  end

  def self.add_frame_floor(foundation:,
                           id:,
                           adjacent_to: nil,
                           area: nil,
                           insulation_id: nil,
                           insulation_assembly_r_value: nil,
                           **remainder)
    frame_floor = XMLHelper.add_element(foundation, 'FrameFloor')
    sys_id = XMLHelper.add_element(frame_floor, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(frame_floor, 'AdjacentTo', adjacent_to) unless adjacent_to.nil?
    XMLHelper.add_element(frame_floor, 'Area', to_float(area)) unless area.nil?
    add_assembly_insulation(parent: frame_floor,
                            id: insulation_id,
                            assembly_r_value: to_float(insulation_assembly_r_value))

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return frame_floor
  end

  def self.get_frame_floor_values(floor:)
    return if floor.nil?

    insulation_values = get_assembly_insulation_values(insulation: floor.elements['Insulation'])

    return { id: HPXML.get_id(floor),
             adjacent_to: XMLHelper.get_value(floor, 'AdjacentTo'),
             area: to_float(XMLHelper.get_value(floor, 'Area')),
             insulation_id: insulation_values[:id],
             insulation_assembly_r_value: to_float(insulation_values[:assembly_r_value]) }
  end

  def self.add_foundation_wall(foundation:,
                               id:,
                               height: nil,
                               area: nil,
                               thickness: nil,
                               depth_below_grade: nil,
                               adjacent_to: nil,
                               insulation_id: nil,
                               insulation_assembly_r_value: nil,
                               **remainder)
    foundation_wall = XMLHelper.add_element(foundation, 'FoundationWall')
    sys_id = XMLHelper.add_element(foundation_wall, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(foundation_wall, 'Height', to_float(height)) unless height.nil?
    XMLHelper.add_element(foundation_wall, 'Area', to_float(area)) unless area.nil?
    XMLHelper.add_element(foundation_wall, 'Thickness', to_float(thickness)) unless thickness.nil?
    XMLHelper.add_element(foundation_wall, 'DepthBelowGrade', to_float(depth_below_grade)) unless depth_below_grade.nil?
    XMLHelper.add_element(foundation_wall, 'AdjacentTo', adjacent_to) unless adjacent_to.nil?
    add_assembly_insulation(parent: foundation_wall,
                            id: insulation_id,
                            assembly_r_value: to_float(insulation_assembly_r_value))

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return foundation_wall
  end

  def self.get_foundation_wall_values(foundation_wall:)
    return if foundation_wall.nil?

    insulation_values = get_assembly_insulation_values(insulation: foundation_wall.elements['Insulation'])

    return { id: HPXML.get_id(foundation_wall),
             height: to_float(XMLHelper.get_value(foundation_wall, 'Height')),
             area: to_float(XMLHelper.get_value(foundation_wall, 'Area')),
             thickness: to_float(XMLHelper.get_value(foundation_wall, 'Thickness')),
             depth_below_grade: to_float(XMLHelper.get_value(foundation_wall, 'DepthBelowGrade')),
             adjacent_to: XMLHelper.get_value(foundation_wall, 'AdjacentTo'),
             insulation_id: insulation_values[:id],
             insulation_assembly_r_value: to_float(insulation_values[:assembly_r_value]) }
  end

  def self.add_slab(foundation:,
                    id:,
                    area: nil,
                    thickness: nil,
                    exposed_perimeter: nil,
                    perimeter_insulation_depth: nil,
                    under_slab_insulation_width: nil,
                    depth_below_grade: nil,
                    carpet_fraction: nil,
                    carpet_r_value: nil,
                    perimeter_insulation_id: nil,
                    perimeter_insulation_r_value: nil,
                    under_slab_insulation_id: nil,
                    under_slab_insulation_r_value: nil,
                    **remainder)
    slab = XMLHelper.add_element(foundation, 'Slab')
    sys_id = XMLHelper.add_element(slab, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(slab, 'Area', to_float(area)) unless area.nil?
    XMLHelper.add_element(slab, 'Thickness', to_float(thickness)) unless thickness.nil?
    XMLHelper.add_element(slab, 'ExposedPerimeter', to_float(exposed_perimeter)) unless exposed_perimeter.nil?
    XMLHelper.add_element(slab, 'PerimeterInsulationDepth', to_float(perimeter_insulation_depth)) unless perimeter_insulation_depth.nil?
    XMLHelper.add_element(slab, 'UnderSlabInsulationWidth', to_float(under_slab_insulation_width)) unless under_slab_insulation_width.nil?
    XMLHelper.add_element(slab, 'DepthBelowGrade', to_float(depth_below_grade)) unless depth_below_grade.nil?
    add_layer_insulation(parent: slab,
                         element_name: 'PerimeterInsulation',
                         id: perimeter_insulation_id,
                         continuous_nominal_r_value: to_float(perimeter_insulation_r_value))
    add_layer_insulation(parent: slab,
                         element_name: 'UnderSlabInsulation',
                         id: under_slab_insulation_id,
                         continuous_nominal_r_value: to_float(under_slab_insulation_r_value))
    HPXML.add_extension(parent: slab,
                        extensions: { 'CarpetFraction' => to_float(carpet_fraction),
                                      'CarpetRValue' => to_float(carpet_r_value) })

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return slab
  end

  def self.get_slab_values(slab:)
    return if slab.nil?

    perimeter_insulation_values = get_layer_insulation_values(insulation: slab.elements['PerimeterInsulation'])
    under_slab_insulation_values = get_layer_insulation_values(insulation: slab.elements['UnderSlabInsulation'])

    return { id: HPXML.get_id(slab),
             area: to_float(XMLHelper.get_value(slab, 'Area')),
             thickness: to_float(XMLHelper.get_value(slab, 'Thickness')),
             exposed_perimeter: to_float(XMLHelper.get_value(slab, 'ExposedPerimeter')),
             perimeter_insulation_depth: to_float(XMLHelper.get_value(slab, 'PerimeterInsulationDepth')),
             under_slab_insulation_width: to_float(XMLHelper.get_value(slab, 'UnderSlabInsulationWidth')),
             depth_below_grade: to_float(XMLHelper.get_value(slab, 'DepthBelowGrade')),
             carpet_fraction: to_float(XMLHelper.get_value(slab, 'extension/CarpetFraction')),
             carpet_r_value: to_float(XMLHelper.get_value(slab, 'extension/CarpetRValue')),
             perimeter_insulation_id: perimeter_insulation_values[:id],
             perimeter_insulation_r_value: to_float(perimeter_insulation_values[:continuous_nominal_r_value]),
             under_slab_insulation_id: under_slab_insulation_values[:id],
             under_slab_insulation_r_value: to_float(under_slab_insulation_values[:continuous_nominal_r_value]) }
  end

  def self.add_rim_joist(hpxml:,
                         id:,
                         exterior_adjacent_to: nil,
                         interior_adjacent_to: nil,
                         area: nil,
                         azimuth: nil,
                         insulation_id: nil,
                         insulation_assembly_r_value: nil,
                         **remainder)
    rim_joists = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Enclosure', 'RimJoists'])
    rim_joist = XMLHelper.add_element(rim_joists, 'RimJoist')
    sys_id = XMLHelper.add_element(rim_joist, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(rim_joist, 'ExteriorAdjacentTo', exterior_adjacent_to) unless exterior_adjacent_to.nil?
    XMLHelper.add_element(rim_joist, 'InteriorAdjacentTo', interior_adjacent_to) unless interior_adjacent_to.nil?
    XMLHelper.add_element(rim_joist, 'Area', to_float(area)) unless area.nil?
    XMLHelper.add_element(rim_joist, 'Azimuth', to_integer(azimuth)) unless azimuth.nil?
    add_assembly_insulation(parent: rim_joist,
                            id: insulation_id,
                            assembly_r_value: to_float(insulation_assembly_r_value))

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return rim_joist
  end

  def self.get_rim_joist_values(rim_joist:)
    return if rim_joist.nil?

    insulation_values = get_assembly_insulation_values(insulation: rim_joist.elements['Insulation'])

    return { id: HPXML.get_id(rim_joist),
             exterior_adjacent_to: XMLHelper.get_value(rim_joist, 'ExteriorAdjacentTo'),
             interior_adjacent_to: XMLHelper.get_value(rim_joist, 'InteriorAdjacentTo'),
             area: to_float(XMLHelper.get_value(rim_joist, 'Area')),
             azimuth: to_integer(XMLHelper.get_value(rim_joist, 'Azimuth')),
             insulation_id: insulation_values[:id],
             insulation_assembly_r_value: to_float(insulation_values[:assembly_r_value]) }
  end

  def self.add_wall(hpxml:,
                    id:,
                    exterior_adjacent_to: nil,
                    interior_adjacent_to: nil,
                    wall_type: nil,
                    area: nil,
                    azimuth: nil,
                    solar_absorptance: nil,
                    emittance: nil,
                    insulation_id: nil,
                    insulation_assembly_r_value: nil,
                    **remainder)
    walls = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Enclosure', 'Walls'])
    wall = XMLHelper.add_element(walls, 'Wall')
    sys_id = XMLHelper.add_element(wall, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(wall, 'ExteriorAdjacentTo', exterior_adjacent_to) unless exterior_adjacent_to.nil?
    XMLHelper.add_element(wall, 'InteriorAdjacentTo', interior_adjacent_to) unless interior_adjacent_to.nil?
    unless wall_type.nil?
      wall_type_e = XMLHelper.add_element(wall, 'WallType')
      XMLHelper.add_element(wall_type_e, wall_type)
    end
    XMLHelper.add_element(wall, 'Area', to_float(area)) unless area.nil?
    XMLHelper.add_element(wall, 'Azimuth', to_integer(azimuth)) unless azimuth.nil?
    XMLHelper.add_element(wall, 'SolarAbsorptance', to_float(solar_absorptance)) unless solar_absorptance.nil?
    XMLHelper.add_element(wall, 'Emittance', to_float(emittance)) unless emittance.nil?
    add_assembly_insulation(parent: wall,
                            id: insulation_id,
                            assembly_r_value: to_float(insulation_assembly_r_value))

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:orientation, :siding])

    return wall
  end

  def self.get_wall_values(wall:)
    return if wall.nil?

    insulation_values = get_assembly_insulation_values(insulation: wall.elements['Insulation'])

    return { id: HPXML.get_id(wall),
             exterior_adjacent_to: XMLHelper.get_value(wall, 'ExteriorAdjacentTo'),
             interior_adjacent_to: XMLHelper.get_value(wall, 'InteriorAdjacentTo'),
             wall_type: XMLHelper.get_child_name(wall, 'WallType'),
             area: to_float(XMLHelper.get_value(wall, 'Area')),
             orientation: XMLHelper.get_value(wall, 'Orientation'),
             azimuth: to_integer(XMLHelper.get_value(wall, 'Azimuth')),
             siding: XMLHelper.get_value(wall, 'Siding'),
             solar_absorptance: to_float(XMLHelper.get_value(wall, 'SolarAbsorptance')),
             emittance: to_float(XMLHelper.get_value(wall, 'Emittance')),
             insulation_id: insulation_values[:id],
             insulation_assembly_r_value: to_float(insulation_values[:assembly_r_value]) }
  end

  def self.add_window(hpxml:,
                      id:,
                      area: nil,
                      azimuth: nil,
                      ufactor: nil,
                      shgc: nil,
                      overhangs_depth: nil,
                      overhangs_distance_to_top_of_window: nil,
                      overhangs_distance_to_bottom_of_window: nil,
                      wall_idref: nil,
                      interior_shading_factor_summer: nil,
                      interior_shading_factor_winter: nil,
                      **remainder)
    windows = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Enclosure', 'Windows'])
    window = XMLHelper.add_element(windows, 'Window')
    sys_id = XMLHelper.add_element(window, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(window, 'Area', to_float(area)) unless area.nil?
    XMLHelper.add_element(window, 'Azimuth', to_integer(azimuth)) unless azimuth.nil?
    XMLHelper.add_element(window, 'UFactor', to_float(ufactor)) unless ufactor.nil?
    XMLHelper.add_element(window, 'SHGC', to_float(shgc)) unless shgc.nil?
    if (not overhangs_depth.nil?) || (not overhangs_distance_to_top_of_window.nil?) || (not overhangs_distance_to_bottom_of_window.nil?)
      overhangs = XMLHelper.add_element(window, 'Overhangs')
      XMLHelper.add_element(overhangs, 'Depth', to_float(overhangs_depth)) unless overhangs_depth.nil?
      XMLHelper.add_element(overhangs, 'DistanceToTopOfWindow', to_float(overhangs_distance_to_top_of_window)) unless overhangs_distance_to_top_of_window.nil?
      XMLHelper.add_element(overhangs, 'DistanceToBottomOfWindow', to_float(overhangs_distance_to_bottom_of_window)) unless overhangs_distance_to_bottom_of_window.nil?
    end
    unless wall_idref.nil?
      attached_to_wall = XMLHelper.add_element(window, 'AttachedToWall')
      XMLHelper.add_attribute(attached_to_wall, 'idref', wall_idref)
    end
    HPXML.add_extension(parent: window,
                        extensions: { 'InteriorShadingFactorSummer' => to_float(interior_shading_factor_summer),
                                      'InteriorShadingFactorWinter' => to_float(interior_shading_factor_winter) })
    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:orientation, :frame_type, :glass_layers, :glass_type, :gas_fill])

    return window
  end

  def self.get_window_values(window:)
    return if window.nil?

    frame_type = window.elements['FrameType']
    unless frame_type.nil?
      frame_type = XMLHelper.get_child_name(window, 'FrameType')
    end

    return { id: HPXML.get_id(window),
             area: to_float(XMLHelper.get_value(window, 'Area')),
             azimuth: to_integer(XMLHelper.get_value(window, 'Azimuth')),
             orientation: XMLHelper.get_value(window, 'Orientation'),
             frame_type: frame_type,
             glass_layers: XMLHelper.get_value(window, 'GlassLayers'),
             glass_type: XMLHelper.get_value(window, 'GlassType'),
             gas_fill: XMLHelper.get_value(window, 'GasFill'),
             ufactor: to_float(XMLHelper.get_value(window, 'UFactor')),
             shgc: to_float(XMLHelper.get_value(window, 'SHGC')),
             overhangs_depth: to_float(XMLHelper.get_value(window, 'Overhangs/Depth')),
             overhangs_distance_to_top_of_window: to_float(XMLHelper.get_value(window, 'Overhangs/DistanceToTopOfWindow')),
             overhangs_distance_to_bottom_of_window: to_float(XMLHelper.get_value(window, 'Overhangs/DistanceToBottomOfWindow')),
             wall_idref: HPXML.get_idref(window, 'AttachedToWall'),
             interior_shading_factor_summer: to_float(XMLHelper.get_value(window, 'extension/InteriorShadingFactorSummer')),
             interior_shading_factor_winter: to_float(XMLHelper.get_value(window, 'extension/InteriorShadingFactorWinter')) }
  end

  def self.add_skylight(hpxml:,
                        id:,
                        area: nil,
                        azimuth: nil,
                        ufactor: nil,
                        shgc: nil,
                        roof_idref: nil,
                        **remainder)
    skylights = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Enclosure', 'Skylights'])
    skylight = XMLHelper.add_element(skylights, 'Skylight')
    sys_id = XMLHelper.add_element(skylight, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(skylight, 'Area', to_float(area)) unless area.nil?
    XMLHelper.add_element(skylight, 'Azimuth', to_integer(azimuth)) unless azimuth.nil?
    XMLHelper.add_element(skylight, 'UFactor', to_float(ufactor)) unless ufactor.nil?
    XMLHelper.add_element(skylight, 'SHGC', to_float(shgc)) unless shgc.nil?
    unless roof_idref.nil?
      attached_to_roof = XMLHelper.add_element(skylight, 'AttachedToRoof')
      XMLHelper.add_attribute(attached_to_roof, 'idref', roof_idref)
    end

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:orientation, :frame_type, :glass_layers, :glass_type, :gas_fill])

    return skylight
  end

  def self.get_skylight_values(skylight:)
    return if skylight.nil?

    frame_type = skylight.elements['FrameType']
    unless frame_type.nil?
      frame_type = XMLHelper.get_child_name(skylight, 'FrameType')
    end

    return { id: HPXML.get_id(skylight),
             area: to_float(XMLHelper.get_value(skylight, 'Area')),
             azimuth: to_integer(XMLHelper.get_value(skylight, 'Azimuth')),
             orientation: XMLHelper.get_value(skylight, 'Orientation'),
             frame_type: frame_type,
             glass_layers: XMLHelper.get_value(skylight, 'GlassLayers'),
             glass_type: XMLHelper.get_value(skylight, 'GlassType'),
             gas_fill: XMLHelper.get_value(skylight, 'GasFill'),
             ufactor: to_float(XMLHelper.get_value(skylight, 'UFactor')),
             shgc: to_float(XMLHelper.get_value(skylight, 'SHGC')),
             roof_idref: HPXML.get_idref(skylight, 'AttachedToRoof') }
  end

  def self.add_door(hpxml:,
                    id:,
                    wall_idref: nil,
                    area: nil,
                    azimuth: nil,
                    r_value: nil,
                    **remainder)
    doors = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Enclosure', 'Doors'])
    door = XMLHelper.add_element(doors, 'Door')
    sys_id = XMLHelper.add_element(door, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    unless wall_idref.nil?
      attached_to_wall = XMLHelper.add_element(door, 'AttachedToWall')
      XMLHelper.add_attribute(attached_to_wall, 'idref', wall_idref)
    end
    XMLHelper.add_element(door, 'Area', to_float(area)) unless area.nil?
    XMLHelper.add_element(door, 'Azimuth', to_integer(azimuth)) unless azimuth.nil?
    XMLHelper.add_element(door, 'RValue', to_float(r_value)) unless r_value.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return door
  end

  def self.get_door_values(door:)
    return if door.nil?

    return { id: HPXML.get_id(door),
             wall_idref: HPXML.get_idref(door, 'AttachedToWall'),
             area: to_float(XMLHelper.get_value(door, 'Area')),
             azimuth: to_integer(XMLHelper.get_value(door, 'Azimuth')),
             r_value: to_float(XMLHelper.get_value(door, 'RValue')) }
  end

  def self.add_heating_system(hpxml:,
                              id:,
                              distribution_system_idref: nil,
                              heating_system_type: nil,
                              heating_system_fuel: nil,
                              heating_capacity: nil,
                              heating_efficiency_units: nil,
                              heating_efficiency_value: nil,
                              fraction_heat_load_served: nil,
                              electric_auxiliary_energy: nil,
                              **remainder)
    hvac_plant = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Systems', 'HVAC', 'HVACPlant'])
    heating_system = XMLHelper.add_element(hvac_plant, 'HeatingSystem')
    sys_id = XMLHelper.add_element(heating_system, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    unless distribution_system_idref.nil?
      distribution_system = XMLHelper.add_element(heating_system, 'DistributionSystem')
      XMLHelper.add_attribute(distribution_system, 'idref', distribution_system_idref)
    end
    unless heating_system_type.nil?
      heating_system_type_e = XMLHelper.add_element(heating_system, 'HeatingSystemType')
      XMLHelper.add_element(heating_system_type_e, heating_system_type)
    end
    XMLHelper.add_element(heating_system, 'HeatingSystemFuel', heating_system_fuel) unless heating_system_fuel.nil?
    XMLHelper.add_element(heating_system, 'HeatingCapacity', to_float(heating_capacity)) unless heating_capacity.nil?
    if (not heating_efficiency_units.nil?) && (not heating_efficiency_value.nil?)
      annual_heating_efficiency = XMLHelper.add_element(heating_system, 'AnnualHeatingEfficiency')
      XMLHelper.add_element(annual_heating_efficiency, 'Units', heating_efficiency_units)
      XMLHelper.add_element(annual_heating_efficiency, 'Value', to_float(heating_efficiency_value))
    end
    XMLHelper.add_element(heating_system, 'FractionHeatLoadServed', to_float(fraction_heat_load_served)) unless fraction_heat_load_served.nil?
    XMLHelper.add_element(heating_system, 'ElectricAuxiliaryEnergy', to_float(electric_auxiliary_energy)) unless electric_auxiliary_energy.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:year_installed])

    return heating_system
  end

  def self.get_heating_system_values(heating_system:)
    return if heating_system.nil?

    return { id: HPXML.get_id(heating_system),
             distribution_system_idref: HPXML.get_idref(heating_system, 'DistributionSystem'),
             year_installed: to_integer(XMLHelper.get_value(heating_system, 'YearInstalled')),
             heating_system_type: XMLHelper.get_child_name(heating_system, 'HeatingSystemType'),
             heating_system_fuel: XMLHelper.get_value(heating_system, 'HeatingSystemFuel'),
             heating_capacity: to_float(XMLHelper.get_value(heating_system, 'HeatingCapacity')),
             heating_efficiency_units: XMLHelper.get_value(heating_system, 'AnnualHeatingEfficiency/Units'),
             heating_efficiency_value: to_float(XMLHelper.get_value(heating_system, 'AnnualHeatingEfficiency/Value')),
             fraction_heat_load_served: to_float(XMLHelper.get_value(heating_system, 'FractionHeatLoadServed')),
             electric_auxiliary_energy: to_float(XMLHelper.get_value(heating_system, 'ElectricAuxiliaryEnergy')) }
  end

  def self.add_cooling_system(hpxml:,
                              id:,
                              distribution_system_idref: nil,
                              cooling_system_type: nil,
                              cooling_system_fuel: nil,
                              cooling_capacity: nil,
                              fraction_cool_load_served: nil,
                              cooling_efficiency_units: nil,
                              cooling_efficiency_value: nil,
                              **remainder)
    hvac_plant = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Systems', 'HVAC', 'HVACPlant'])
    cooling_system = XMLHelper.add_element(hvac_plant, 'CoolingSystem')
    sys_id = XMLHelper.add_element(cooling_system, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    unless distribution_system_idref.nil?
      distribution_system = XMLHelper.add_element(cooling_system, 'DistributionSystem')
      XMLHelper.add_attribute(distribution_system, 'idref', distribution_system_idref)
    end
    XMLHelper.add_element(cooling_system, 'CoolingSystemType', cooling_system_type) unless cooling_system_type.nil?
    XMLHelper.add_element(cooling_system, 'CoolingSystemFuel', cooling_system_fuel) unless cooling_system_fuel.nil?
    XMLHelper.add_element(cooling_system, 'CoolingCapacity', to_float(cooling_capacity)) unless cooling_capacity.nil?
    XMLHelper.add_element(cooling_system, 'FractionCoolLoadServed', to_float(fraction_cool_load_served)) unless fraction_cool_load_served.nil?
    if (not cooling_efficiency_units.nil?) && (not cooling_efficiency_value.nil?)
      annual_cooling_efficiency = XMLHelper.add_element(cooling_system, 'AnnualCoolingEfficiency')
      XMLHelper.add_element(annual_cooling_efficiency, 'Units', cooling_efficiency_units)
      XMLHelper.add_element(annual_cooling_efficiency, 'Value', to_float(cooling_efficiency_value))
    end

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:year_installed])

    return cooling_system
  end

  def self.get_cooling_system_values(cooling_system:)
    return if cooling_system.nil?

    return { id: HPXML.get_id(cooling_system),
             distribution_system_idref: HPXML.get_idref(cooling_system, 'DistributionSystem'),
             year_installed: to_integer(XMLHelper.get_value(cooling_system, 'YearInstalled')),
             cooling_system_type: XMLHelper.get_value(cooling_system, 'CoolingSystemType'),
             cooling_system_fuel: XMLHelper.get_value(cooling_system, 'CoolingSystemFuel'),
             cooling_capacity: to_float(XMLHelper.get_value(cooling_system, 'CoolingCapacity')),
             fraction_cool_load_served: to_float(XMLHelper.get_value(cooling_system, 'FractionCoolLoadServed')),
             cooling_efficiency_units: XMLHelper.get_value(cooling_system, 'AnnualCoolingEfficiency/Units'),
             cooling_efficiency_value: to_float(XMLHelper.get_value(cooling_system, 'AnnualCoolingEfficiency/Value')) }
  end

  def self.add_heat_pump(hpxml:,
                         id:,
                         distribution_system_idref: nil,
                         heat_pump_type: nil,
                         heat_pump_fuel: nil,
                         heating_capacity: nil,
                         cooling_capacity: nil,
                         backup_heating_capacity: nil,
                         fraction_heat_load_served: nil,
                         fraction_cool_load_served: nil,
                         heating_efficiency_units: nil,
                         heating_efficiency_value: nil,
                         cooling_efficiency_units: nil,
                         cooling_efficiency_value: nil,
                         **remainder)
    hvac_plant = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Systems', 'HVAC', 'HVACPlant'])
    heat_pump = XMLHelper.add_element(hvac_plant, 'HeatPump')
    sys_id = XMLHelper.add_element(heat_pump, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    unless distribution_system_idref.nil?
      distribution_system = XMLHelper.add_element(heat_pump, 'DistributionSystem')
      XMLHelper.add_attribute(distribution_system, 'idref', distribution_system_idref)
    end
    XMLHelper.add_element(heat_pump, 'HeatPumpType', heat_pump_type) unless heat_pump_type.nil?
    XMLHelper.add_element(heat_pump, 'HeatPumpFuel', heat_pump_fuel) unless heat_pump_fuel.nil?
    XMLHelper.add_element(heat_pump, 'HeatingCapacity', to_float(heating_capacity)) unless heating_capacity.nil?
    XMLHelper.add_element(heat_pump, 'CoolingCapacity', to_float(cooling_capacity)) unless cooling_capacity.nil?
    XMLHelper.add_element(heat_pump, 'BackupHeatingCapacity', to_float(backup_heating_capacity)) unless backup_heating_capacity.nil?
    XMLHelper.add_element(heat_pump, 'FractionHeatLoadServed', to_float(fraction_heat_load_served)) unless fraction_heat_load_served.nil?
    XMLHelper.add_element(heat_pump, 'FractionCoolLoadServed', to_float(fraction_cool_load_served)) unless fraction_cool_load_served.nil?
    if (not cooling_efficiency_units.nil?) && (not cooling_efficiency_value.nil?)
      annual_cooling_efficiency = XMLHelper.add_element(heat_pump, 'AnnualCoolingEfficiency')
      XMLHelper.add_element(annual_cooling_efficiency, 'Units', cooling_efficiency_units)
      XMLHelper.add_element(annual_cooling_efficiency, 'Value', to_float(cooling_efficiency_value))
    end
    if (not heating_efficiency_units.nil?) && (not heating_efficiency_value.nil?)
      annual_heating_efficiency = XMLHelper.add_element(heat_pump, 'AnnualHeatingEfficiency')
      XMLHelper.add_element(annual_heating_efficiency, 'Units', heating_efficiency_units)
      XMLHelper.add_element(annual_heating_efficiency, 'Value', to_float(heating_efficiency_value))
    end

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:year_installed])

    return heat_pump
  end

  def self.get_heat_pump_values(heat_pump:)
    return if heat_pump.nil?

    return { id: HPXML.get_id(heat_pump),
             distribution_system_idref: HPXML.get_idref(heat_pump, 'DistributionSystem'),
             year_installed: to_integer(XMLHelper.get_value(heat_pump, 'YearInstalled')),
             heat_pump_type: XMLHelper.get_value(heat_pump, 'HeatPumpType'),
             heat_pump_fuel: XMLHelper.get_value(heat_pump, 'HeatPumpFuel'),
             heating_capacity: to_float(XMLHelper.get_value(heat_pump, 'HeatingCapacity')),
             cooling_capacity: to_float(XMLHelper.get_value(heat_pump, 'CoolingCapacity')),
             backup_heating_capacity: to_float(XMLHelper.get_value(heat_pump, 'BackupHeatingCapacity')),
             fraction_heat_load_served: to_float(XMLHelper.get_value(heat_pump, 'FractionHeatLoadServed')),
             fraction_cool_load_served: to_float(XMLHelper.get_value(heat_pump, 'FractionCoolLoadServed')),
             heating_efficiency_units: XMLHelper.get_value(heat_pump, 'AnnualHeatingEfficiency/Units'),
             heating_efficiency_value: to_float(XMLHelper.get_value(heat_pump, 'AnnualHeatingEfficiency/Value')),
             cooling_efficiency_units: XMLHelper.get_value(heat_pump, 'AnnualCoolingEfficiency/Units'),
             cooling_efficiency_value: to_float(XMLHelper.get_value(heat_pump, 'AnnualCoolingEfficiency/Value')) }
  end

  def self.add_hvac_control(hpxml:,
                            id:,
                            control_type: nil,
                            setpoint_temp_heating_season: nil,
                            setpoint_temp_cooling_season: nil,
                            **remainder)
    hvac = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Systems', 'HVAC'])
    hvac_control = XMLHelper.add_element(hvac, 'HVACControl')
    sys_id = XMLHelper.add_element(hvac_control, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(hvac_control, 'ControlType', control_type) unless control_type.nil?
    XMLHelper.add_element(hvac_control, 'SetpointTempHeatingSeason', to_float(setpoint_temp_heating_season)) unless setpoint_temp_heating_season.nil?
    XMLHelper.add_element(hvac_control, 'SetpointTempCoolingSeason', to_float(setpoint_temp_cooling_season)) unless setpoint_temp_cooling_season.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return hvac_control
  end

  def self.get_hvac_control_values(hvac_control:)
    return if hvac_control.nil?

    return { id: HPXML.get_id(hvac_control),
             control_type: XMLHelper.get_value(hvac_control, 'ControlType'),
             setpoint_temp_heating_season: to_float(XMLHelper.get_value(hvac_control, 'SetpointTempHeatingSeason')),
             setpoint_temp_cooling_season: to_float(XMLHelper.get_value(hvac_control, 'SetpointTempCoolingSeason')) }
  end

  def self.add_hvac_distribution(hpxml:,
                                 id:,
                                 distribution_system_type: nil,
                                 annual_heating_dse: nil,
                                 annual_cooling_dse: nil,
                                 **remainder)
    hvac = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Systems', 'HVAC'])
    hvac_distribution = XMLHelper.add_element(hvac, 'HVACDistribution')
    sys_id = XMLHelper.add_element(hvac_distribution, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    unless distribution_system_type.nil?
      distribution_system_type_e = XMLHelper.add_element(hvac_distribution, 'DistributionSystemType')
      if ['AirDistribution', 'HydronicDistribution'].include? distribution_system_type
        XMLHelper.add_element(distribution_system_type_e, distribution_system_type)
      else
        XMLHelper.add_element(distribution_system_type_e, 'Other', distribution_system_type)
      end
    end
    XMLHelper.add_element(hvac_distribution, 'AnnualHeatingDistributionSystemEfficiency', to_float(annual_heating_dse)) unless annual_heating_dse.nil?
    XMLHelper.add_element(hvac_distribution, 'AnnualCoolingDistributionSystemEfficiency', to_float(annual_cooling_dse)) unless annual_cooling_dse.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:duct_system_sealed])

    return hvac_distribution
  end

  def self.get_hvac_distribution_values(hvac_distribution:)
    return if hvac_distribution.nil?

    distribution_system_type = XMLHelper.get_child_name(hvac_distribution, 'DistributionSystemType')
    if distribution_system_type == 'Other'
      distribution_system_type = XMLHelper.get_value(hvac_distribution.elements['DistributionSystemType'], 'Other')
    end

    return { id: HPXML.get_id(hvac_distribution),
             distribution_system_type: distribution_system_type,
             annual_heating_dse: to_float(XMLHelper.get_value(hvac_distribution, 'AnnualHeatingDistributionSystemEfficiency')),
             annual_cooling_dse: to_float(XMLHelper.get_value(hvac_distribution, 'AnnualCoolingDistributionSystemEfficiency')),
             duct_system_sealed: to_bool(XMLHelper.get_value(hvac_distribution, 'HVACDistributionImprovement/DuctSystemSealed')) }
  end

  def self.add_duct_leakage_measurement(air_distribution:,
                                        duct_type: nil,
                                        duct_leakage_value: nil,
                                        **remainder)
    duct_leakage_measurement = XMLHelper.add_element(air_distribution, 'DuctLeakageMeasurement')
    XMLHelper.add_element(duct_leakage_measurement, 'DuctType', duct_type) unless duct_type.nil?
    if not duct_leakage_value.nil?
      duct_leakage = XMLHelper.add_element(duct_leakage_measurement, 'DuctLeakage')
      XMLHelper.add_element(duct_leakage, 'Units', 'CFM25')
      XMLHelper.add_element(duct_leakage, 'Value', to_float(duct_leakage_value)) unless duct_leakage_value.nil?
      XMLHelper.add_element(duct_leakage, 'TotalOrToOutside', 'to outside')
    end

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return duct_leakage_measurement
  end

  def self.get_duct_leakage_measurement_values(duct_leakage_measurement:)
    return if duct_leakage_measurement.nil?

    return { duct_type: XMLHelper.get_value(duct_leakage_measurement, 'DuctType'),
             duct_leakage_value: to_float(XMLHelper.get_value(duct_leakage_measurement, 'DuctLeakage/Value')) }
  end

  def self.add_ducts(air_distribution:,
                     duct_type: nil,
                     duct_insulation_r_value: nil,
                     duct_location: nil,
                     duct_surface_area: nil,
                     **remainder)
    ducts = XMLHelper.add_element(air_distribution, 'Ducts')
    XMLHelper.add_element(ducts, 'DuctType', duct_type) unless duct_type.nil?
    XMLHelper.add_element(ducts, 'DuctInsulationRValue', to_float(duct_insulation_r_value)) unless duct_insulation_r_value.nil?
    XMLHelper.add_element(ducts, 'DuctLocation', duct_location) unless duct_location.nil?
    XMLHelper.add_element(ducts, 'DuctSurfaceArea', to_float(duct_surface_area)) unless duct_surface_area.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:duct_fraction_area, :hescore_ducts_insulated])

    return ducts
  end

  def self.get_ducts_values(ducts:)
    return if ducts.nil?

    return { duct_type: XMLHelper.get_value(ducts, 'DuctType'),
             duct_insulation_r_value: to_float(XMLHelper.get_value(ducts, 'DuctInsulationRValue')),
             duct_location: XMLHelper.get_value(ducts, 'DuctLocation'),
             duct_fraction_area: to_float(XMLHelper.get_value(ducts, 'FractionDuctArea')),
             duct_surface_area: to_float(XMLHelper.get_value(ducts, 'DuctSurfaceArea')),
             hescore_ducts_insulated: to_bool(XMLHelper.get_value(ducts, 'extension/hescore_ducts_insulated')) }
  end

  def self.add_ventilation_fan(hpxml:,
                               id:,
                               fan_type: nil,
                               rated_flow_rate: nil,
                               hours_in_operation: nil,
                               total_recovery_efficiency: nil,
                               sensible_recovery_efficiency: nil,
                               fan_power: nil,
                               distribution_system_idref: nil,
                               **remainder)
    ventilation_fans = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Systems', 'MechanicalVentilation', 'VentilationFans'])
    ventilation_fan = XMLHelper.add_element(ventilation_fans, 'VentilationFan')
    sys_id = XMLHelper.add_element(ventilation_fan, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(ventilation_fan, 'FanType', fan_type) unless fan_type.nil?
    XMLHelper.add_element(ventilation_fan, 'RatedFlowRate', to_float(rated_flow_rate)) unless rated_flow_rate.nil?
    XMLHelper.add_element(ventilation_fan, 'HoursInOperation', to_float(hours_in_operation)) unless hours_in_operation.nil?
    XMLHelper.add_element(ventilation_fan, 'UsedForWholeBuildingVentilation', true)
    XMLHelper.add_element(ventilation_fan, 'TotalRecoveryEfficiency', to_float(total_recovery_efficiency)) unless total_recovery_efficiency.nil?
    XMLHelper.add_element(ventilation_fan, 'SensibleRecoveryEfficiency', to_float(sensible_recovery_efficiency)) unless sensible_recovery_efficiency.nil?
    XMLHelper.add_element(ventilation_fan, 'FanPower', to_float(fan_power)) unless fan_power.nil?
    unless distribution_system_idref.nil?
      attached_to_hvac_distribution_system = XMLHelper.add_element(ventilation_fan, 'AttachedToHVACDistributionSystem')
      XMLHelper.add_attribute(attached_to_hvac_distribution_system, 'idref', distribution_system_idref)
    end

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return ventilation_fan
  end

  def self.get_ventilation_fan_values(ventilation_fan:)
    return if ventilation_fan.nil?

    return { id: HPXML.get_id(ventilation_fan),
             fan_type: XMLHelper.get_value(ventilation_fan, 'FanType'),
             rated_flow_rate: to_float(XMLHelper.get_value(ventilation_fan, 'RatedFlowRate')),
             hours_in_operation: to_float(XMLHelper.get_value(ventilation_fan, 'HoursInOperation')),
             total_recovery_efficiency: to_float(XMLHelper.get_value(ventilation_fan, 'TotalRecoveryEfficiency')),
             sensible_recovery_efficiency: to_float(XMLHelper.get_value(ventilation_fan, 'SensibleRecoveryEfficiency')),
             fan_power: to_float(XMLHelper.get_value(ventilation_fan, 'FanPower')),
             distribution_system_idref: HPXML.get_idref(ventilation_fan, 'AttachedToHVACDistributionSystem') }
  end

  def self.add_water_heating_system(hpxml:,
                                    id:,
                                    fuel_type: nil,
                                    water_heater_type: nil,
                                    location: nil,
                                    tank_volume: nil,
                                    fraction_dhw_load_served: nil,
                                    heating_capacity: nil,
                                    energy_factor: nil,
                                    uniform_energy_factor: nil,
                                    recovery_efficiency: nil,
                                    energy_factor_multiplier: nil,
                                    **remainder)
    water_heating = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Systems', 'WaterHeating'])
    water_heating_system = XMLHelper.add_element(water_heating, 'WaterHeatingSystem')
    sys_id = XMLHelper.add_element(water_heating_system, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(water_heating_system, 'FuelType', fuel_type) unless fuel_type.nil?
    XMLHelper.add_element(water_heating_system, 'WaterHeaterType', water_heater_type) unless water_heater_type.nil?
    XMLHelper.add_element(water_heating_system, 'Location', location) unless location.nil?
    XMLHelper.add_element(water_heating_system, 'TankVolume', to_float(tank_volume)) unless tank_volume.nil?
    XMLHelper.add_element(water_heating_system, 'FractionDHWLoadServed', to_float(fraction_dhw_load_served)) unless fraction_dhw_load_served.nil?
    XMLHelper.add_element(water_heating_system, 'HeatingCapacity', to_float(heating_capacity)) unless heating_capacity.nil?
    XMLHelper.add_element(water_heating_system, 'EnergyFactor', to_float(energy_factor)) unless energy_factor.nil?
    XMLHelper.add_element(water_heating_system, 'UniformEnergyFactor', to_float(uniform_energy_factor)) unless uniform_energy_factor.nil?
    XMLHelper.add_element(water_heating_system, 'RecoveryEfficiency', to_float(recovery_efficiency)) unless recovery_efficiency.nil?
    HPXML.add_extension(parent: water_heating_system,
                        extensions: { 'EnergyFactorMultiplier' => to_float(energy_factor_multiplier) })

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:year_installed])

    return water_heating_system
  end

  def self.get_water_heating_system_values(water_heating_system:)
    return if water_heating_system.nil?

    return { id: HPXML.get_id(water_heating_system),
             year_installed: to_integer(XMLHelper.get_value(water_heating_system, 'YearInstalled')),
             fuel_type: XMLHelper.get_value(water_heating_system, 'FuelType'),
             water_heater_type: XMLHelper.get_value(water_heating_system, 'WaterHeaterType'),
             location: XMLHelper.get_value(water_heating_system, 'Location'),
             tank_volume: to_float(XMLHelper.get_value(water_heating_system, 'TankVolume')),
             fraction_dhw_load_served: to_float(XMLHelper.get_value(water_heating_system, 'FractionDHWLoadServed')),
             heating_capacity: to_float(XMLHelper.get_value(water_heating_system, 'HeatingCapacity')),
             energy_factor: to_float(XMLHelper.get_value(water_heating_system, 'EnergyFactor')),
             uniform_energy_factor: to_float(XMLHelper.get_value(water_heating_system, 'UniformEnergyFactor')),
             recovery_efficiency: to_float(XMLHelper.get_value(water_heating_system, 'RecoveryEfficiency')),
             energy_factor_multiplier: to_float(XMLHelper.get_value(water_heating_system, 'extension/EnergyFactorMultiplier')) }
  end

  def self.add_hot_water_distribution(hpxml:,
                                      id:,
                                      system_type: nil,
                                      pipe_r_value: nil,
                                      standard_piping_length: nil,
                                      recirculation_control_type: nil,
                                      recirculation_piping_length: nil,
                                      recirculation_branch_piping_length: nil,
                                      recirculation_pump_power: nil,
                                      dwhr_facilities_connected: nil,
                                      dwhr_equal_flow: nil,
                                      dwhr_efficiency: nil,
                                      **remainder)
    water_heating = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Systems', 'WaterHeating'])
    hot_water_distribution = XMLHelper.add_element(water_heating, 'HotWaterDistribution')
    sys_id = XMLHelper.add_element(hot_water_distribution, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    unless system_type.nil?
      system_type_e = XMLHelper.add_element(hot_water_distribution, 'SystemType')
      if system_type == 'Standard'
        standard = XMLHelper.add_element(system_type_e, system_type)
        XMLHelper.add_element(standard, 'PipingLength', to_float(standard_piping_length)) unless standard_piping_length.nil?
      elsif system_type == 'Recirculation'
        recirculation = XMLHelper.add_element(system_type_e, system_type)
        XMLHelper.add_element(recirculation, 'ControlType', recirculation_control_type) unless recirculation_control_type.nil?
        XMLHelper.add_element(recirculation, 'RecirculationPipingLoopLength', to_float(recirculation_piping_length)) unless recirculation_piping_length.nil?
        XMLHelper.add_element(recirculation, 'BranchPipingLoopLength', to_float(recirculation_branch_piping_length)) unless recirculation_branch_piping_length.nil?
        XMLHelper.add_element(recirculation, 'PumpPower', to_float(recirculation_pump_power)) unless recirculation_pump_power.nil?
      else
        fail "Unhandled hot water system type '#{system_type}'."
      end
    end
    unless pipe_r_value.nil?
      pipe_insulation = XMLHelper.add_element(hot_water_distribution, 'PipeInsulation')
      XMLHelper.add_element(pipe_insulation, 'PipeRValue', to_float(pipe_r_value))
    end
    if (not dwhr_facilities_connected.nil?) || (not dwhr_equal_flow.nil?) || (not dwhr_efficiency.nil?)
      drain_water_heat_recovery = XMLHelper.add_element(hot_water_distribution, 'DrainWaterHeatRecovery')
      XMLHelper.add_element(drain_water_heat_recovery, 'FacilitiesConnected', dwhr_facilities_connected) unless dwhr_facilities_connected.nil?
      XMLHelper.add_element(drain_water_heat_recovery, 'EqualFlow', to_bool(dwhr_equal_flow)) unless dwhr_equal_flow.nil?
      XMLHelper.add_element(drain_water_heat_recovery, 'Efficiency', to_float(dwhr_efficiency)) unless dwhr_efficiency.nil?
    end

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return hot_water_distribution
  end

  def self.get_hot_water_distribution_values(hot_water_distribution:)
    return if hot_water_distribution.nil?

    return { id: HPXML.get_id(hot_water_distribution),
             system_type: XMLHelper.get_child_name(hot_water_distribution, 'SystemType'),
             pipe_r_value: to_float(XMLHelper.get_value(hot_water_distribution, 'PipeInsulation/PipeRValue')),
             standard_piping_length: to_float(XMLHelper.get_value(hot_water_distribution, 'SystemType/Standard/PipingLength')),
             recirculation_control_type: XMLHelper.get_value(hot_water_distribution, 'SystemType/Recirculation/ControlType'),
             recirculation_piping_length: to_float(XMLHelper.get_value(hot_water_distribution, 'SystemType/Recirculation/RecirculationPipingLoopLength')),
             recirculation_branch_piping_length: to_float(XMLHelper.get_value(hot_water_distribution, 'SystemType/Recirculation/BranchPipingLoopLength')),
             recirculation_pump_power: to_float(XMLHelper.get_value(hot_water_distribution, 'SystemType/Recirculation/PumpPower')),
             dwhr_facilities_connected: XMLHelper.get_value(hot_water_distribution, 'DrainWaterHeatRecovery/FacilitiesConnected'),
             dwhr_equal_flow: to_bool(XMLHelper.get_value(hot_water_distribution, 'DrainWaterHeatRecovery/EqualFlow')),
             dwhr_efficiency: to_float(XMLHelper.get_value(hot_water_distribution, 'DrainWaterHeatRecovery/Efficiency')) }
  end

  def self.add_water_fixture(hpxml:,
                             id:,
                             water_fixture_type: nil,
                             low_flow: nil,
                             **remainder)
    water_heating = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Systems', 'WaterHeating'])
    water_fixture = XMLHelper.add_element(water_heating, 'WaterFixture')
    sys_id = XMLHelper.add_element(water_fixture, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(water_fixture, 'WaterFixtureType', water_fixture_type) unless water_fixture_type.nil?
    XMLHelper.add_element(water_fixture, 'LowFlow', to_bool(low_flow)) unless low_flow.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return water_fixture
  end

  def self.get_water_fixture_values(water_fixture:)
    return if water_fixture.nil?

    return { id: HPXML.get_id(water_fixture),
             water_fixture_type: XMLHelper.get_value(water_fixture, 'WaterFixtureType'),
             low_flow: to_bool(XMLHelper.get_value(water_fixture, 'LowFlow')) }
  end

  def self.add_pv_system(hpxml:,
                         id:,
                         module_type: nil,
                         array_type: nil,
                         array_azimuth: nil,
                         array_tilt: nil,
                         max_power_output: nil,
                         inverter_efficiency: nil,
                         system_losses_fraction: nil,
                         **remainder)
    photovoltaics = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Systems', 'Photovoltaics'])
    pv_system = XMLHelper.add_element(photovoltaics, 'PVSystem')
    sys_id = XMLHelper.add_element(pv_system, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(pv_system, 'ModuleType', module_type) unless module_type.nil?
    XMLHelper.add_element(pv_system, 'ArrayType', array_type) unless array_type.nil?
    XMLHelper.add_element(pv_system, 'ArrayAzimuth', to_integer(array_azimuth)) unless array_azimuth.nil?
    XMLHelper.add_element(pv_system, 'ArrayTilt', to_float(array_tilt)) unless array_tilt.nil?
    XMLHelper.add_element(pv_system, 'MaxPowerOutput', to_float(max_power_output)) unless max_power_output.nil?
    XMLHelper.add_element(pv_system, 'InverterEfficiency', to_float(inverter_efficiency)) unless inverter_efficiency.nil?
    XMLHelper.add_element(pv_system, 'SystemLossesFraction', to_float(system_losses_fraction)) unless system_losses_fraction.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [:array_orientation, :hescore_num_panels])

    return pv_system
  end

  def self.get_pv_system_values(pv_system:)
    return if pv_system.nil?

    return { id: HPXML.get_id(pv_system),
             module_type: XMLHelper.get_value(pv_system, 'ModuleType'),
             array_type: XMLHelper.get_value(pv_system, 'ArrayType'),
             array_orientation: XMLHelper.get_value(pv_system, 'ArrayOrientation'),
             array_azimuth: to_integer(XMLHelper.get_value(pv_system, 'ArrayAzimuth')),
             array_tilt: to_float(XMLHelper.get_value(pv_system, 'ArrayTilt')),
             max_power_output: to_float(XMLHelper.get_value(pv_system, 'MaxPowerOutput')),
             inverter_efficiency: to_float(XMLHelper.get_value(pv_system, 'InverterEfficiency')),
             system_losses_fraction: to_float(XMLHelper.get_value(pv_system, 'SystemLossesFraction')),
             hescore_num_panels: to_integer(XMLHelper.get_value(pv_system, 'extension/hescore_num_panels')) }
  end

  def self.add_clothes_washer(hpxml:,
                              id:,
                              location: nil,
                              modified_energy_factor: nil,
                              integrated_modified_energy_factor: nil,
                              rated_annual_kwh: nil,
                              label_electric_rate: nil,
                              label_gas_rate: nil,
                              label_annual_gas_cost: nil,
                              capacity: nil,
                              **remainder)
    appliances = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Appliances'])
    clothes_washer = XMLHelper.add_element(appliances, 'ClothesWasher')
    sys_id = XMLHelper.add_element(clothes_washer, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(clothes_washer, 'Location', location) unless location.nil?
    XMLHelper.add_element(clothes_washer, 'ModifiedEnergyFactor', to_float(modified_energy_factor)) unless modified_energy_factor.nil?
    XMLHelper.add_element(clothes_washer, 'IntegratedModifiedEnergyFactor', to_float(integrated_modified_energy_factor)) unless integrated_modified_energy_factor.nil?
    XMLHelper.add_element(clothes_washer, 'RatedAnnualkWh', to_float(rated_annual_kwh)) unless rated_annual_kwh.nil?
    XMLHelper.add_element(clothes_washer, 'LabelElectricRate', to_float(label_electric_rate)) unless label_electric_rate.nil?
    XMLHelper.add_element(clothes_washer, 'LabelGasRate', to_float(label_gas_rate)) unless label_gas_rate.nil?
    XMLHelper.add_element(clothes_washer, 'LabelAnnualGasCost', to_float(label_annual_gas_cost)) unless label_annual_gas_cost.nil?
    XMLHelper.add_element(clothes_washer, 'Capacity', to_float(capacity)) unless capacity.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return clothes_washer
  end

  def self.get_clothes_washer_values(clothes_washer:)
    return if clothes_washer.nil?

    return { id: HPXML.get_id(clothes_washer),
             location: XMLHelper.get_value(clothes_washer, 'Location'),
             modified_energy_factor: to_float(XMLHelper.get_value(clothes_washer, 'ModifiedEnergyFactor')),
             integrated_modified_energy_factor: to_float(XMLHelper.get_value(clothes_washer, 'IntegratedModifiedEnergyFactor')),
             rated_annual_kwh: to_float(XMLHelper.get_value(clothes_washer, 'RatedAnnualkWh')),
             label_electric_rate: to_float(XMLHelper.get_value(clothes_washer, 'LabelElectricRate')),
             label_gas_rate: to_float(XMLHelper.get_value(clothes_washer, 'LabelGasRate')),
             label_annual_gas_cost: to_float(XMLHelper.get_value(clothes_washer, 'LabelAnnualGasCost')),
             capacity: to_float(XMLHelper.get_value(clothes_washer, 'Capacity')) }
  end

  def self.add_clothes_dryer(hpxml:,
                             id:,
                             location: nil,
                             fuel_type: nil,
                             energy_factor: nil,
                             combined_energy_factor: nil,
                             control_type: nil,
                             **remainder)
    appliances = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Appliances'])
    clothes_dryer = XMLHelper.add_element(appliances, 'ClothesDryer')
    sys_id = XMLHelper.add_element(clothes_dryer, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(clothes_dryer, 'Location', location) unless location.nil?
    XMLHelper.add_element(clothes_dryer, 'FuelType', fuel_type) unless fuel_type.nil?
    XMLHelper.add_element(clothes_dryer, 'EnergyFactor', to_float(energy_factor)) unless energy_factor.nil?
    XMLHelper.add_element(clothes_dryer, 'CombinedEnergyFactor', to_float(combined_energy_factor)) unless combined_energy_factor.nil?
    XMLHelper.add_element(clothes_dryer, 'ControlType', control_type) unless control_type.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return clothes_dryer
  end

  def self.get_clothes_dryer_values(clothes_dryer:)
    return if clothes_dryer.nil?

    return { id: HPXML.get_id(clothes_dryer),
             location: XMLHelper.get_value(clothes_dryer, 'Location'),
             fuel_type: XMLHelper.get_value(clothes_dryer, 'FuelType'),
             energy_factor: to_float(XMLHelper.get_value(clothes_dryer, 'EnergyFactor')),
             combined_energy_factor: to_float(XMLHelper.get_value(clothes_dryer, 'CombinedEnergyFactor')),
             control_type: XMLHelper.get_value(clothes_dryer, 'ControlType') }
  end

  def self.add_dishwasher(hpxml:,
                          id:,
                          energy_factor: nil,
                          rated_annual_kwh: nil,
                          place_setting_capacity: nil,
                          **remainder)
    appliances = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Appliances'])
    dishwasher = XMLHelper.add_element(appliances, 'Dishwasher')
    sys_id = XMLHelper.add_element(dishwasher, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(dishwasher, 'EnergyFactor', to_float(energy_factor)) unless energy_factor.nil?
    XMLHelper.add_element(dishwasher, 'RatedAnnualkWh', to_float(rated_annual_kwh)) unless rated_annual_kwh.nil?
    XMLHelper.add_element(dishwasher, 'PlaceSettingCapacity', to_integer(place_setting_capacity)) unless place_setting_capacity.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return dishwasher
  end

  def self.get_dishwasher_values(dishwasher:)
    return if dishwasher.nil?

    return { id: HPXML.get_id(dishwasher),
             energy_factor: to_float(XMLHelper.get_value(dishwasher, 'EnergyFactor')),
             rated_annual_kwh: to_float(XMLHelper.get_value(dishwasher, 'RatedAnnualkWh')),
             place_setting_capacity: to_integer(XMLHelper.get_value(dishwasher, 'PlaceSettingCapacity')) }
  end

  def self.add_refrigerator(hpxml:,
                            id:,
                            location: nil,
                            rated_annual_kwh: nil,
                            **remainder)
    appliances = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Appliances'])
    refrigerator = XMLHelper.add_element(appliances, 'Refrigerator')
    sys_id = XMLHelper.add_element(refrigerator, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(refrigerator, 'Location', location) unless location.nil?
    XMLHelper.add_element(refrigerator, 'RatedAnnualkWh', to_float(rated_annual_kwh)) unless rated_annual_kwh.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return refrigerator
  end

  def self.get_refrigerator_values(refrigerator:)
    return if refrigerator.nil?

    return { id: HPXML.get_id(refrigerator),
             location: XMLHelper.get_value(refrigerator, 'Location'),
             rated_annual_kwh: to_float(XMLHelper.get_value(refrigerator, 'RatedAnnualkWh')) }
  end

  def self.add_cooking_range(hpxml:,
                             id:,
                             fuel_type: nil,
                             is_induction: nil,
                             **remainder)
    appliances = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Appliances'])
    cooking_range = XMLHelper.add_element(appliances, 'CookingRange')
    sys_id = XMLHelper.add_element(cooking_range, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(cooking_range, 'FuelType', fuel_type)
    XMLHelper.add_element(cooking_range, 'IsInduction', to_bool(is_induction)) unless is_induction.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return cooking_range
  end

  def self.get_cooking_range_values(cooking_range:)
    return if cooking_range.nil?

    return { id: HPXML.get_id(cooking_range),
             fuel_type: XMLHelper.get_value(cooking_range, 'FuelType'),
             is_induction: to_bool(XMLHelper.get_value(cooking_range, 'IsInduction')) }
  end

  def self.add_oven(hpxml:,
                    id:,
                    is_convection: nil,
                    **remainder)
    appliances = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Appliances'])
    oven = XMLHelper.add_element(appliances, 'Oven')
    sys_id = XMLHelper.add_element(oven, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(oven, 'IsConvection', to_bool(is_convection)) unless is_convection.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return oven
  end

  def self.get_oven_values(oven:)
    return if oven.nil?

    return { id: HPXML.get_id(oven),
             is_convection: to_bool(XMLHelper.get_value(oven, 'IsConvection')) }
  end

  def self.add_lighting(hpxml:,
                        fraction_tier_i_interior: nil,
                        fraction_tier_i_exterior: nil,
                        fraction_tier_i_garage: nil,
                        fraction_tier_ii_interior: nil,
                        fraction_tier_ii_exterior: nil,
                        fraction_tier_ii_garage: nil,
                        **remainder)
    lighting = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Lighting'])
    if not fraction_tier_i_interior.nil?
      lighting_group = XMLHelper.add_element(lighting, 'LightingGroup')
      sys_id = XMLHelper.add_element(lighting_group, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', 'Lighting_TierI_Interior')
      XMLHelper.add_element(lighting_group, 'Location', 'interior')
      XMLHelper.add_element(lighting_group, 'FractionofUnitsInLocation', fraction_tier_i_interior)
      XMLHelper.add_element(lighting_group, 'ThirdPartyCertification', 'ERI Tier I')
    end
    if not fraction_tier_i_exterior.nil?
      lighting_group = XMLHelper.add_element(lighting, 'LightingGroup')
      sys_id = XMLHelper.add_element(lighting_group, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', 'Lighting_TierI_Exterior')
      XMLHelper.add_element(lighting_group, 'Location', 'exterior')
      XMLHelper.add_element(lighting_group, 'FractionofUnitsInLocation', fraction_tier_i_exterior)
      XMLHelper.add_element(lighting_group, 'ThirdPartyCertification', 'ERI Tier I')
    end
    if not fraction_tier_i_garage.nil?
      lighting_group = XMLHelper.add_element(lighting, 'LightingGroup')
      sys_id = XMLHelper.add_element(lighting_group, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', 'Lighting_TierI_Garage')
      XMLHelper.add_element(lighting_group, 'Location', 'garage')
      XMLHelper.add_element(lighting_group, 'FractionofUnitsInLocation', fraction_tier_i_garage)
      XMLHelper.add_element(lighting_group, 'ThirdPartyCertification', 'ERI Tier I')
    end
    if not fraction_tier_ii_interior.nil?
      lighting_group = XMLHelper.add_element(lighting, 'LightingGroup')
      sys_id = XMLHelper.add_element(lighting_group, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', 'Lighting_TierII_Interior')
      XMLHelper.add_element(lighting_group, 'Location', 'interior')
      XMLHelper.add_element(lighting_group, 'FractionofUnitsInLocation', fraction_tier_ii_interior)
      XMLHelper.add_element(lighting_group, 'ThirdPartyCertification', 'ERI Tier II')
    end
    if not fraction_tier_ii_exterior.nil?
      lighting_group = XMLHelper.add_element(lighting, 'LightingGroup')
      sys_id = XMLHelper.add_element(lighting_group, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', 'Lighting_TierII_Exterior')
      XMLHelper.add_element(lighting_group, 'Location', 'exterior')
      XMLHelper.add_element(lighting_group, 'FractionofUnitsInLocation', fraction_tier_ii_exterior)
      XMLHelper.add_element(lighting_group, 'ThirdPartyCertification', 'ERI Tier II')
    end
    if not fraction_tier_ii_garage.nil?
      lighting_group = XMLHelper.add_element(lighting, 'LightingGroup')
      sys_id = XMLHelper.add_element(lighting_group, 'SystemIdentifier')
      XMLHelper.add_attribute(sys_id, 'id', 'Lighting_TierII_Garage')
      XMLHelper.add_element(lighting_group, 'Location', 'garage')
      XMLHelper.add_element(lighting_group, 'FractionofUnitsInLocation', fraction_tier_ii_garage)
      XMLHelper.add_element(lighting_group, 'ThirdPartyCertification', 'ERI Tier II')
    end

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return lighting_group
  end

  def self.get_lighting_values(lighting:)
    return if lighting.nil?

    return { fraction_tier_i_interior: to_float(XMLHelper.get_value(lighting, "LightingGroup[ThirdPartyCertification='ERI Tier I' and Location='interior']/FractionofUnitsInLocation")),
             fraction_tier_i_exterior: to_float(XMLHelper.get_value(lighting, "LightingGroup[ThirdPartyCertification='ERI Tier I' and Location='exterior']/FractionofUnitsInLocation")),
             fraction_tier_i_garage: to_float(XMLHelper.get_value(lighting, "LightingGroup[ThirdPartyCertification='ERI Tier I' and Location='garage']/FractionofUnitsInLocation")),
             fraction_tier_ii_interior: to_float(XMLHelper.get_value(lighting, "LightingGroup[ThirdPartyCertification='ERI Tier II' and Location='interior']/FractionofUnitsInLocation")),
             fraction_tier_ii_exterior: to_float(XMLHelper.get_value(lighting, "LightingGroup[ThirdPartyCertification='ERI Tier II' and Location='exterior']/FractionofUnitsInLocation")),
             fraction_tier_ii_garage: to_float(XMLHelper.get_value(lighting, "LightingGroup[ThirdPartyCertification='ERI Tier II' and Location='garage']/FractionofUnitsInLocation")) }
  end

  def self.add_ceiling_fan(hpxml:,
                           id:,
                           efficiency: nil,
                           quantity: nil,
                           **remainder)
    lighting = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'Lighting'])
    ceiling_fan = XMLHelper.add_element(lighting, 'CeilingFan')
    sys_id = XMLHelper.add_element(ceiling_fan, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    if not efficiency.nil?
      airflow = XMLHelper.add_element(ceiling_fan, 'Airflow')
      XMLHelper.add_element(airflow, 'FanSpeed', 'medium')
      XMLHelper.add_element(airflow, 'Efficiency', to_float(efficiency))
    end
    XMLHelper.add_element(ceiling_fan, 'Quantity', to_integer(quantity)) unless quantity.nil?

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return ceiling_fan
  end

  def self.get_ceiling_fan_values(ceiling_fan:)
    return if ceiling_fan.nil?

    return { id: HPXML.get_id(ceiling_fan),
             efficiency: to_float(XMLHelper.get_value(ceiling_fan, "Airflow[FanSpeed='medium']/Efficiency")),
             quantity: to_integer(XMLHelper.get_value(ceiling_fan, 'Quantity')) }
  end

  def self.add_plug_load(hpxml:,
                         id:,
                         plug_load_type: nil,
                         kWh_per_year: nil,
                         frac_sensible: nil,
                         frac_latent: nil,
                         **remainder)
    misc_loads = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'MiscLoads'])
    plug_load = XMLHelper.add_element(misc_loads, 'PlugLoad')
    sys_id = XMLHelper.add_element(plug_load, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(plug_load, 'PlugLoadType', plug_load_type) unless plug_load_type.nil?
    if not kWh_per_year.nil?
      load = XMLHelper.add_element(plug_load, 'Load')
      XMLHelper.add_element(load, 'Units', 'kWh/year')
      XMLHelper.add_element(load, 'Value', to_float(kWh_per_year))
    end
    HPXML.add_extension(parent: plug_load,
                        extensions: { 'FracSensible' => to_float(frac_sensible),
                                      'FracLatent' => to_float(frac_latent) })

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return plug_load
  end

  def self.get_plug_load_values(plug_load:)
    return if plug_load.nil?

    return { id: HPXML.get_id(plug_load),
             plug_load_type: XMLHelper.get_value(plug_load, 'PlugLoadType'),
             kWh_per_year: to_float(XMLHelper.get_value(plug_load, "Load[Units='kWh/year']/Value")),
             frac_sensible: to_float(XMLHelper.get_value(plug_load, 'extension/FracSensible')),
             frac_latent: to_float(XMLHelper.get_value(plug_load, 'extension/FracLatent')) }
  end

  def self.add_misc_loads_schedule(hpxml:,
                                   weekday_fractions: nil,
                                   weekend_fractions: nil,
                                   monthly_multipliers: nil,
                                   **remainder)
    misc_loads = XMLHelper.create_elements_as_needed(hpxml, ['Building', 'BuildingDetails', 'MiscLoads'])
    HPXML.add_extension(parent: misc_loads,
                        extensions: { 'WeekdayScheduleFractions' => weekday_fractions,
                                      'WeekendScheduleFractions' => weekend_fractions,
                                      'MonthlyScheduleMultipliers' => monthly_multipliers })

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return misc_loads
  end

  def self.get_misc_loads_schedule_values(misc_loads:)
    return if misc_loads.nil?

    return { weekday_fractions: XMLHelper.get_value(misc_loads, 'extension/WeekdayScheduleFractions'),
             weekend_fractions: XMLHelper.get_value(misc_loads, 'extension/WeekendScheduleFractions'),
             monthly_multipliers: XMLHelper.get_value(misc_loads, 'extension/MonthlyScheduleMultipliers') }
  end

  def self.add_assembly_insulation(parent:,
                                   id:,
                                   assembly_r_value: nil,
                                   **remainder)
    return if assembly_r_value.nil?

    insulation = XMLHelper.add_element(parent, 'Insulation')
    sys_id = XMLHelper.add_element(insulation, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    XMLHelper.add_element(insulation, 'AssemblyEffectiveRValue', to_float(assembly_r_value))

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return insulation
  end

  def self.get_assembly_insulation_values(insulation:)
    return {} if insulation.nil?

    return { id: HPXML.get_id(insulation),
             assembly_r_value: to_float(XMLHelper.get_value(insulation, 'AssemblyEffectiveRValue')) }
  end

  def self.add_layer_insulation(parent:,
                                element_name:,
                                id:,
                                cavity_nominal_r_value: nil,
                                continuous_nominal_r_value: nil,
                                **remainder)
    return if cavity_nominal_r_value.nil? && continuous_nominal_r_value.nil?

    insulation = XMLHelper.add_element(parent, element_name)
    sys_id = XMLHelper.add_element(insulation, 'SystemIdentifier')
    XMLHelper.add_attribute(sys_id, 'id', id)
    unless cavity_nominal_r_value.nil?
      layer = XMLHelper.add_element(insulation, 'Layer')
      XMLHelper.add_element(layer, 'InstallationType', 'cavity')
      XMLHelper.add_element(layer, 'NominalRValue', to_float(cavity_nominal_r_value))
    end
    unless continuous_nominal_r_value.nil?
      layer = XMLHelper.add_element(insulation, 'Layer')
      XMLHelper.add_element(layer, 'InstallationType', 'continuous')
      XMLHelper.add_element(layer, 'NominalRValue', to_float(continuous_nominal_r_value))
    end

    check_remainder(remainder,
                    calling_method: __method__.to_s,
                    expected_kwargs: [])

    return insulation
  end

  def self.get_layer_insulation_values(insulation:)
    return {} if insulation.nil?

    return { id: HPXML.get_id(insulation),
             cavity_nominal_r_value: to_float(XMLHelper.get_value(insulation, "Layer[InstallationType='cavity']/NominalRValue")),
             continuous_nominal_r_value: to_float(XMLHelper.get_value(insulation, "Layer[InstallationType='continuous']/NominalRValue")) }
  end

  def self.add_extension(parent:,
                         extensions: {})
    extension = nil
    unless extensions.empty?
      extensions.each do |name, value|
        next if value.nil?

        extension = parent.elements['extension']
        if extension.nil?
          extension = XMLHelper.add_element(parent, 'extension')
        end
        XMLHelper.add_element(extension, "#{name}", value) unless value.nil?
      end
    end

    return extension
  end

  def self.get_extension_values(parent:)
    return {} if parent.nil?

    return { use_only_ideal_air_system: to_bool(XMLHelper.get_value(parent, 'extension/UseOnlyIdealAirSystem')),
             load_distribution_scheme: XMLHelper.get_value(parent, 'extension/LoadDistributionScheme'),
             disable_natural_ventilation: to_bool(XMLHelper.get_value(parent, 'extension/DisableNaturalVentilation')) }
  end

  private

  def self.get_id(parent, element_name = 'SystemIdentifier')
    return parent.elements[element_name].attributes['id']
  end

  def self.get_idref(parent, element_name)
    element = parent.elements[element_name]
    return if element.nil?

    return element.attributes['idref']
  end

  def self.to_float(value)
    return if value.nil?

    return Float(value)
  end

  def self.to_integer(value)
    return if value.nil?

    return Integer(Float(value))
  end

  def self.to_bool(value)
    return if value.nil?

    return Boolean(value)
  end

  def self.check_remainder(remainder, calling_method:, expected_kwargs:)
    remainder.keys.each do |k|
      next if expected_kwargs.include? k

      fail "Unexpected keyword '#{k}' passed to #{calling_method}."
    end
  end
end
