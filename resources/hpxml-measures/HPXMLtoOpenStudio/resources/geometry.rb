# frozen_string_literal: true

class Geometry
  def self.create_space_and_zone(model, spaces, space_type)
    if not spaces.keys.include? space_type
      thermal_zone = OpenStudio::Model::ThermalZone.new(model)
      thermal_zone.setName(space_type)

      space = OpenStudio::Model::Space.new(model)
      space.setName(space_type)

      st = OpenStudio::Model::SpaceType.new(model)
      st.setStandardsSpaceType(space_type)
      space.setSpaceType(st)

      space.setThermalZone(thermal_zone)
      spaces[space_type] = space
    end
  end

  def self.get_surface_transformation(offset, x, y, z)
    x = UnitConversions.convert(x, 'ft', 'm')
    y = UnitConversions.convert(y, 'ft', 'm')
    z = UnitConversions.convert(z, 'ft', 'm')

    m = OpenStudio::Matrix.new(4, 4, 0)
    m[0, 0] = 1
    m[1, 1] = 1
    m[2, 2] = 1
    m[3, 3] = 1
    m[0, 3] = x * offset
    m[1, 3] = y * offset
    m[2, 3] = z.abs * offset

    return OpenStudio::Transformation.new(m)
  end

  def self.create_floor_vertices(length, width, z_origin, default_azimuths)
    length = UnitConversions.convert(length, 'ft', 'm')
    width = UnitConversions.convert(width, 'ft', 'm')
    z_origin = UnitConversions.convert(z_origin, 'ft', 'm')

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new(-length / 2, -width / 2, z_origin)
    vertices << OpenStudio::Point3d.new(-length / 2, width / 2, z_origin)
    vertices << OpenStudio::Point3d.new(length / 2, width / 2, z_origin)
    vertices << OpenStudio::Point3d.new(length / 2, -width / 2, z_origin)

    # Rotate about the z axis
    # This is not strictly needed, but will make the floor edges
    # parallel to the walls for a better geometry rendering.
    azimuth_rad = UnitConversions.convert(default_azimuths[0], 'deg', 'rad')
    m = OpenStudio::Matrix.new(4, 4, 0)
    m[0, 0] = Math::cos(-azimuth_rad)
    m[1, 1] = Math::cos(-azimuth_rad)
    m[0, 1] = -Math::sin(-azimuth_rad)
    m[1, 0] = Math::sin(-azimuth_rad)
    m[2, 2] = 1
    m[3, 3] = 1
    transformation = OpenStudio::Transformation.new(m)

    return transformation * vertices
  end

  def self.create_wall_vertices(length, height, z_origin, azimuth, add_buffer: false, subsurface_area: 0)
    length = UnitConversions.convert(length, 'ft', 'm')
    height = UnitConversions.convert(height, 'ft', 'm')
    z_origin = UnitConversions.convert(z_origin, 'ft', 'm')

    if add_buffer
      buffer = calculate_subsurface_parent_buffer(length, height)
      buffer /= 2.0 # Buffer on each side
    else
      buffer = 0
    end

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new(-length / 2 - buffer, 0, z_origin - buffer)
    vertices << OpenStudio::Point3d.new(-length / 2 - buffer, 0, z_origin + height + buffer)
    if subsurface_area > 0
      subsurface_area = UnitConversions.convert(subsurface_area, 'ft^2', 'm^2')
      sub_length = length / 10.0
      sub_height = subsurface_area / sub_length
      if sub_height >= height
        sub_height = height - 0.1
        sub_length = subsurface_area / sub_height
      end
      vertices << OpenStudio::Point3d.new(length / 2 - sub_length + buffer, 0, z_origin + height + buffer)
      vertices << OpenStudio::Point3d.new(length / 2 - sub_length + buffer, 0, z_origin + height - sub_height + buffer)
      vertices << OpenStudio::Point3d.new(length / 2 + buffer, 0, z_origin + height - sub_height + buffer)
    else
      vertices << OpenStudio::Point3d.new(length / 2 + buffer, 0, z_origin + height + buffer)
    end
    vertices << OpenStudio::Point3d.new(length / 2 + buffer, 0, z_origin - buffer)

    # Rotate about the z axis
    azimuth_rad = UnitConversions.convert(azimuth, 'deg', 'rad')
    m = OpenStudio::Matrix.new(4, 4, 0)
    m[0, 0] = Math::cos(-azimuth_rad)
    m[1, 1] = Math::cos(-azimuth_rad)
    m[0, 1] = -Math::sin(-azimuth_rad)
    m[1, 0] = Math::sin(-azimuth_rad)
    m[2, 2] = 1
    m[3, 3] = 1
    transformation = OpenStudio::Transformation.new(m)

    return transformation * vertices
  end

  def self.create_roof_vertices(length, width, z_origin, azimuth, tilt, add_buffer: false)
    length = UnitConversions.convert(length, 'ft', 'm')
    width = UnitConversions.convert(width, 'ft', 'm')
    z_origin = UnitConversions.convert(z_origin, 'ft', 'm')

    if add_buffer
      buffer = calculate_subsurface_parent_buffer(length, width)
      buffer /= 2.0 # Buffer on each side
    else
      buffer = 0
    end

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new(length / 2 + buffer, -width / 2 - buffer, 0)
    vertices << OpenStudio::Point3d.new(length / 2 + buffer, width / 2 + buffer, 0)
    vertices << OpenStudio::Point3d.new(-length / 2 - buffer, width / 2 + buffer, 0)
    vertices << OpenStudio::Point3d.new(-length / 2 - buffer, -width / 2 - buffer, 0)

    # Rotate about the x axis
    m = OpenStudio::Matrix.new(4, 4, 0)
    m[0, 0] = 1
    m[1, 1] = Math::cos(Math::atan(tilt))
    m[1, 2] = -Math::sin(Math::atan(tilt))
    m[2, 1] = Math::sin(Math::atan(tilt))
    m[2, 2] = Math::cos(Math::atan(tilt))
    m[3, 3] = 1
    transformation = OpenStudio::Transformation.new(m)
    vertices = transformation * vertices

    # Rotate about the z axis
    azimuth_rad = UnitConversions.convert(azimuth, 'deg', 'rad')
    rad180 = UnitConversions.convert(180, 'deg', 'rad')
    m = OpenStudio::Matrix.new(4, 4, 0)
    m[0, 0] = Math::cos(rad180 - azimuth_rad)
    m[1, 1] = Math::cos(rad180 - azimuth_rad)
    m[0, 1] = -Math::sin(rad180 - azimuth_rad)
    m[1, 0] = Math::sin(rad180 - azimuth_rad)
    m[2, 2] = 1
    m[3, 3] = 1
    transformation = OpenStudio::Transformation.new(m)
    vertices = transformation * vertices

    # Shift up by z
    new_vertices = OpenStudio::Point3dVector.new
    vertices.each do |vertex|
      new_vertices << OpenStudio::Point3d.new(vertex.x, vertex.y, vertex.z + z_origin)
    end

    return new_vertices
  end

  def self.create_ceiling_vertices(length, width, z_origin, default_azimuths)
    return OpenStudio::reverse(create_floor_vertices(length, width, z_origin, default_azimuths))
  end

  def self.explode_surfaces(runner, model, hpxml, walls_top)
    # Re-position surfaces so as to not shade each other and to make it easier to visualize the building.

    gap_distance = UnitConversions.convert(10.0, 'ft', 'm') # distance between surfaces of the same azimuth
    rad90 = UnitConversions.convert(90, 'deg', 'rad')

    # Determine surfaces to shift and distance with which to explode surfaces horizontally outward
    surfaces = []
    azimuth_lengths = {}
    model.getSurfaces.sort.each do |surface|
      next unless ['wall', 'roofceiling'].include? surface.surfaceType.downcase
      next unless ['outdoors', 'foundation', 'adiabatic'].include? surface.outsideBoundaryCondition.downcase
      next if surface.additionalProperties.getFeatureAsDouble('Tilt').get <= 0 # skip flat roofs

      surfaces << surface
      azimuth = surface.additionalProperties.getFeatureAsInteger('Azimuth').get
      if azimuth_lengths[azimuth].nil?
        azimuth_lengths[azimuth] = 0.0
      end
      azimuth_lengths[azimuth] += surface.additionalProperties.getFeatureAsDouble('Length').get + gap_distance
    end
    max_azimuth_length = azimuth_lengths.values.max

    # Using the max length for a given azimuth, calculate the apothem (radius of the incircle) of a regular
    # n-sided polygon to create the smallest polygon possible without self-shading. The number of polygon
    # sides is defined by the minimum difference between two azimuths.
    min_azimuth_diff = 360
    azimuths_sorted = azimuth_lengths.keys.sort
    azimuths_sorted.each_with_index do |az, idx|
      diff1 = (az - azimuths_sorted[(idx + 1) % azimuths_sorted.size]).abs
      diff2 = 360.0 - diff1 # opposite direction
      if diff1 < min_azimuth_diff
        min_azimuth_diff = diff1
      end
      if diff2 < min_azimuth_diff
        min_azimuth_diff = diff2
      end
    end
    if min_azimuth_diff > 0
      nsides = [(360.0 / min_azimuth_diff).ceil, 4].max # assume rectangle at the minimum
    else
      nsides = 4
    end
    explode_distance = max_azimuth_length / (2.0 * Math.tan(UnitConversions.convert(180.0 / nsides, 'deg', 'rad')))

    add_neighbor_shading(runner, model, max_azimuth_length, hpxml, walls_top)

    # Initial distance of shifts at 90-degrees to horizontal outward
    azimuth_side_shifts = {}
    azimuth_lengths.keys.each do |azimuth|
      azimuth_side_shifts[azimuth] = max_azimuth_length / 2.0
    end

    # Explode neighbors
    model.getShadingSurfaceGroups.each do |shading_group|
      next unless shading_group.name.to_s == Constants.ObjectNameNeighbors

      shading_group.shadingSurfaces.each do |shading_surface|
        azimuth = shading_surface.additionalProperties.getFeatureAsInteger('Azimuth').get
        azimuth_rad = UnitConversions.convert(azimuth, 'deg', 'rad')
        distance = shading_surface.additionalProperties.getFeatureAsDouble('Distance').get

        unless azimuth_lengths.keys.include? azimuth
          fail "A neighbor building has an azimuth (#{azimuth}) not equal to the azimuth of any wall."
        end

        # Push out horizontally
        distance += explode_distance
        transformation = get_surface_transformation(distance, Math::sin(azimuth_rad), Math::cos(azimuth_rad), 0)

        shading_surface.setVertices(transformation * shading_surface.vertices)
      end
    end

    # Explode walls, windows, doors, roofs, and skylights
    surfaces_moved = []

    surfaces.sort.each do |surface|
      next if surface.additionalProperties.getFeatureAsDouble('Tilt').get <= 0 # skip flat roofs

      if surface.adjacentSurface.is_initialized
        next if surfaces_moved.include? surface.adjacentSurface.get
      end

      azimuth = surface.additionalProperties.getFeatureAsInteger('Azimuth').get
      azimuth_rad = UnitConversions.convert(azimuth, 'deg', 'rad')

      # Get associated shading surfaces (e.g., overhangs, interior shading surfaces)
      overhang_surfaces = []
      shading_surfaces = []
      surface.subSurfaces.each do |subsurface|
        next unless subsurface.subSurfaceType.downcase == 'fixedwindow'

        subsurface.shadingSurfaceGroups.each do |overhang_group|
          overhang_group.shadingSurfaces.each do |overhang|
            overhang_surfaces << overhang
          end
        end
      end
      model.getShadingSurfaceGroups.each do |shading_group|
        next unless [Constants.ObjectNameSkylightShade, Constants.ObjectNameWindowShade].include? shading_group.name.to_s

        shading_group.shadingSurfaces.each do |window_shade|
          next unless window_shade.additionalProperties.getFeatureAsString('ParentSurface').get == surface.name.to_s

          shading_surfaces << window_shade
        end
      end

      # Push out horizontally
      distance = explode_distance

      if surface.surfaceType.downcase == 'roofceiling'
        # Ensure pitched surfaces are positioned outward justified with walls, etc.
        tilt = surface.additionalProperties.getFeatureAsDouble('Tilt').get
        width = surface.additionalProperties.getFeatureAsDouble('Width').get
        distance -= 0.5 * Math.cos(Math.atan(tilt)) * width
      end
      transformation = get_surface_transformation(distance, Math::sin(azimuth_rad), Math::cos(azimuth_rad), 0)
      transformation_shade = get_surface_transformation(distance + 0.001, Math::sin(azimuth_rad), Math::cos(azimuth_rad), 0) # Offset slightly from window

      ([surface] + surface.subSurfaces + overhang_surfaces).each do |s|
        s.setVertices(transformation * s.vertices)
      end
      shading_surfaces.each do |s|
        s.setVertices(transformation_shade * s.vertices)
      end
      if surface.adjacentSurface.is_initialized
        surface.adjacentSurface.get.setVertices(transformation * surface.adjacentSurface.get.vertices)
      end

      # Shift at 90-degrees to previous transformation, so surfaces don't overlap and shade each other
      azimuth_side_shifts[azimuth] -= surface.additionalProperties.getFeatureAsDouble('Length').get / 2.0
      transformation_shift = get_surface_transformation(azimuth_side_shifts[azimuth], Math::sin(azimuth_rad + rad90), Math::cos(azimuth_rad + rad90), 0)

      ([surface] + surface.subSurfaces + overhang_surfaces + shading_surfaces).each do |s|
        s.setVertices(transformation_shift * s.vertices)
      end
      if surface.adjacentSurface.is_initialized
        surface.adjacentSurface.get.setVertices(transformation_shift * surface.adjacentSurface.get.vertices)
      end

      azimuth_side_shifts[azimuth] -= (surface.additionalProperties.getFeatureAsDouble('Length').get / 2.0 + gap_distance)

      surfaces_moved << surface
    end
  end

  def self.add_neighbor_shading(runner, model, length, hpxml, walls_top)
    z_origin = 0 # shading surface always starts at grade

    shading_surfaces = []
    hpxml.neighbor_buildings.each do |neighbor_building|
      height = neighbor_building.height.nil? ? walls_top : neighbor_building.height

      vertices = Geometry.create_wall_vertices(length, height, z_origin, neighbor_building.azimuth)
      shading_surface = OpenStudio::Model::ShadingSurface.new(vertices, model)
      shading_surface.additionalProperties.setFeature('Azimuth', neighbor_building.azimuth)
      shading_surface.additionalProperties.setFeature('Distance', neighbor_building.distance)
      shading_surface.setName("Neighbor azimuth #{neighbor_building.azimuth} distance #{neighbor_building.distance}")

      shading_surfaces << shading_surface
    end

    unless shading_surfaces.empty?
      shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
      shading_surface_group.setName(Constants.ObjectNameNeighbors)
      shading_surfaces.each do |shading_surface|
        shading_surface.setShadingSurfaceGroup(shading_surface_group)
      end
    end
  end

  def self.calculate_zone_volume(hpxml, space_type)
    if [HPXML::LocationBasementUnconditioned, HPXML::LocationCrawlspaceUnvented, HPXML::LocationCrawlspaceVented, HPXML::LocationGarage].include? space_type
      floor_area = hpxml.slabs.select { |s| s.interior_adjacent_to == space_type }.map { |s| s.area }.sum(0.0)
      if space_type == HPXML::LocationGarage
        height = 8.0
      else
        height = hpxml.foundation_walls.select { |w| w.interior_adjacent_to == space_type }.map { |w| w.height }.max
      end
      return floor_area * height
    elsif [HPXML::LocationAtticUnvented, HPXML::LocationAtticVented].include? space_type
      floor_area = hpxml.frame_floors.select { |f| [f.interior_adjacent_to, f.exterior_adjacent_to].include? space_type }.map { |s| s.area }.sum(0.0)
      roofs = hpxml.roofs.select { |r| r.interior_adjacent_to == space_type }
      avg_pitch = roofs.map { |r| r.pitch }.sum(0.0) / roofs.size
      # Assume square hip roof for volume calculation
      length = floor_area**0.5
      height = 0.5 * Math.sin(Math.atan(avg_pitch / 12.0)) * length
      return [floor_area * height / 3.0, 0.01].max
    end
  end

  def self.set_zone_volumes(runner, model, spaces, hpxml, apply_ashrae140_assumptions)
    # Living space
    spaces[HPXML::LocationLivingSpace].thermalZone.get.setVolume(UnitConversions.convert(hpxml.building_construction.conditioned_building_volume, 'ft^3', 'm^3'))

    # Basement, crawlspace, garage
    spaces.keys.each do |space_type|
      next unless [HPXML::LocationBasementUnconditioned, HPXML::LocationCrawlspaceUnvented, HPXML::LocationCrawlspaceVented, HPXML::LocationGarage].include? space_type

      volume = calculate_zone_volume(hpxml, space_type)
      spaces[space_type].thermalZone.get.setVolume(UnitConversions.convert(volume, 'ft^3', 'm^3'))
    end

    # Attic
    spaces.keys.each do |space_type|
      next unless [HPXML::LocationAtticUnvented, HPXML::LocationAtticVented].include? space_type

      if apply_ashrae140_assumptions
        volume = 3463 # Hardcode the attic volume to match ASHRAE 140 Table 7-2 specification
      else
        volume = calculate_zone_volume(hpxml, space_type)
      end

      spaces[space_type].thermalZone.get.setVolume(UnitConversions.convert(volume, 'ft^3', 'm^3'))
    end
  end

  def self.get_temperature_scheduled_space_values(space_type)
    if space_type == HPXML::LocationOtherHeatedSpace
      # Average of indoor/outdoor temperatures with minimum of heating setpoint
      return { temp_min: 68,
               indoor_weight: 0.5,
               outdoor_weight: 0.5,
               ground_weight: 0.0,
               f_regain: 0.0 }
    elsif space_type == HPXML::LocationOtherMultifamilyBufferSpace
      # Average of indoor/outdoor temperatures with minimum of 50 deg-F
      return { temp_min: 50,
               indoor_weight: 0.5,
               outdoor_weight: 0.5,
               ground_weight: 0.0,
               f_regain: 0.0 }
    elsif space_type == HPXML::LocationOtherNonFreezingSpace
      # Floating with outdoor air temperature with minimum of 40 deg-F
      return { temp_min: 40,
               indoor_weight: 0.0,
               outdoor_weight: 1.0,
               ground_weight: 0.0,
               f_regain: 0.0 }
    elsif space_type == HPXML::LocationOtherHousingUnit
      # Indoor air temperature
      return { temp_min: nil,
               indoor_weight: 1.0,
               outdoor_weight: 0.0,
               ground_weight: 0.0,
               f_regain: 0.0 }
    elsif space_type == HPXML::LocationExteriorWall
      # Average of indoor/outdoor temperatures
      return { temp_min: nil,
               indoor_weight: 0.5,
               outdoor_weight: 0.5,
               ground_weight: 0.0,
               f_regain: 0.5 } # From LBNL's "Technical Background for default values used for Forced Air Systems in Proposed ASHRAE Standard 152P"
    elsif space_type == HPXML::LocationUnderSlab
      # Ground temperature
      return { temp_min: nil,
               indoor_weight: 0.0,
               outdoor_weight: 0.0,
               ground_weight: 1.0,
               f_regain: 0.83 } # From LBNL's "Technical Background for default values used for Forced Air Systems in Proposed ASHRAE Standard 152P"
    end
    fail "Unhandled space type: #{space_type}."
  end

  def self.get_height_of_spaces(spaces)
    # Calculates space heights as the max z coordinate minus the min z coordinate
    minzs = []
    maxzs = []
    spaces.each do |space|
      zvalues = getSurfaceZValues(space.surfaces)
      minzs << zvalues.min + UnitConversions.convert(space.zOrigin, 'm', 'ft')
      maxzs << zvalues.max + UnitConversions.convert(space.zOrigin, 'm', 'ft')
    end
    return maxzs.max - minzs.min
  end

  def self.getSurfaceZValues(surfaceArray)
    # Return an array of z values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
    zValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        zValueArray << UnitConversions.convert(vertex.z, 'm', 'ft').round(5)
      end
    end
    return zValueArray
  end

  def self.get_z_origin_for_zone(zone)
    z_origins = []
    zone.spaces.each do |space|
      z_origins << UnitConversions.convert(space.zOrigin, 'm', 'ft')
    end
    return z_origins.min
  end

  def self.get_roof_pitch(surfaces)
    tilts = []
    surfaces.each do |surface|
      next if surface.surfaceType.downcase != 'roofceiling'
      next if (surface.outsideBoundaryCondition.downcase != 'outdoors') && (surface.outsideBoundaryCondition.downcase != 'adiabatic')

      tilts << surface.tilt
    end
    return UnitConversions.convert(tilts.max, 'rad', 'deg')
  end

  # TODO: Remove this method
  def self.is_living(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, HPXML::LocationLivingSpace)
  end

  # TODO: Remove this method
  def self.is_unconditioned_basement(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, HPXML::LocationBasementUnconditioned)
  end

  # TODO: Remove this method
  def self.is_garage(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, HPXML::LocationGarage)
  end

  def self.space_or_zone_is_of_type(space_or_zone, space_type)
    if space_or_zone.is_a? OpenStudio::Model::Space
      return space_is_of_type(space_or_zone, space_type)
    elsif space_or_zone.is_a? OpenStudio::Model::ThermalZone
      return zone_is_of_type(space_or_zone, space_type)
    end
  end

  def self.space_is_of_type(space, space_type)
    unless space.isPlenum
      if space.spaceType.is_initialized
        if space.spaceType.get.standardsSpaceType.is_initialized
          return true if space.spaceType.get.standardsSpaceType.get == space_type
        end
      end
    end
    return false
  end

  def self.zone_is_of_type(zone, space_type)
    zone.spaces.each do |space|
      return space_is_of_type(space, space_type)
    end
  end

  def self.apply_occupants(model, num_occ, cfa, space, schedules_file)
    occ_gain, hrs_per_day, sens_frac, lat_frac = Geometry.get_occupancy_default_values()
    weekday_sch = Schedule.OccupantsWeekdayFractions
    weekday_sch_sum = weekday_sch.split(',').map(&:to_f).sum(0.0)
    if (weekday_sch_sum - hrs_per_day).abs > 0.1
      fail 'Occupancy schedule inconsistent with hrs_per_day.'
    end

    weekend_sch = Schedule.OccupantsWeekendFractions
    monthly_sch = Schedule.OccupantsMonthlyMultipliers

    # Error checking
    if (sens_frac < 0) || (sens_frac > 1)
      fail 'Sensible fraction must be greater than or equal to 0 and less than or equal to 1.'
    end
    if (lat_frac < 0) || (lat_frac > 1)
      fail 'Latent fraction must be greater than or equal to 0 and less than or equal to 1.'
    end
    if lat_frac + sens_frac > 1
      fail 'Sum of sensible and latent fractions must be less than or equal to 1.'
    end

    activity_per_person = UnitConversions.convert(occ_gain, 'Btu/hr', 'W')

    # Hard-coded convective, radiative, latent, and lost fractions
    occ_lat = lat_frac
    occ_sens = sens_frac
    occ_conv = 0.442 * occ_sens
    occ_rad = 0.558 * occ_sens
    occ_lost = 1 - occ_lat - occ_conv - occ_rad

    space_obj_name = "#{Constants.ObjectNameOccupants}"
    space_num_occ = num_occ * UnitConversions.convert(space.floorArea, 'm^2', 'ft^2') / cfa

    # Create schedule
    if not schedules_file.nil?
      people_sch = schedules_file.create_schedule_file(col_name: 'occupants')
    else
      people_sch = MonthWeekdayWeekendSchedule.new(model, Constants.ObjectNameOccupants + ' schedule', weekday_sch, weekend_sch, monthly_sch, Constants.ScheduleTypeLimitsFraction)
      people_sch = people_sch.schedule
    end

    # Create schedule
    activity_sch = OpenStudio::Model::ScheduleConstant.new(model)
    activity_sch.setValue(activity_per_person)
    activity_sch.setName(Constants.ObjectNameOccupants + ' activity schedule')

    # Add people definition for the occ
    occ_def = OpenStudio::Model::PeopleDefinition.new(model)
    occ = OpenStudio::Model::People.new(occ_def)
    occ.setName(space_obj_name)
    occ.setSpace(space)
    occ_def.setName(space_obj_name)
    occ_def.setNumberOfPeopleCalculationMethod('People', 1)
    occ_def.setNumberofPeople(space_num_occ)
    occ_def.setFractionRadiant(occ_rad)
    occ_def.setSensibleHeatFraction(occ_sens)
    occ_def.setMeanRadiantTemperatureCalculationType('ZoneAveraged')
    occ_def.setCarbonDioxideGenerationRate(0)
    occ_def.setEnableASHRAE55ComfortWarnings(false)
    occ.setActivityLevelSchedule(activity_sch)
    occ.setNumberofPeopleSchedule(people_sch)
  end

  def self.get_occupancy_default_num(nbeds)
    return Float(nbeds)
  end

  def self.get_occupancy_default_values()
    # Table 4.2.2(3). Internal Gains for Reference Homes
    hrs_per_day = 16.5 # hrs/day
    sens_gains = 3716.0 # Btu/person/day
    lat_gains = 2884.0 # Btu/person/day
    tot_gains = sens_gains + lat_gains
    heat_gain = tot_gains / hrs_per_day # Btu/person/hr
    sens_frac = sens_gains / tot_gains
    lat_frac = lat_gains / tot_gains
    return heat_gain, hrs_per_day, sens_frac, lat_frac
  end

  def self.tear_down_model(model, runner)
    # Tear down the existing model if it exists
    has_existing_objects = (model.getThermalZones.size > 0)
    handles = OpenStudio::UUIDVector.new
    model.objects.each do |obj|
      handles << obj.handle
    end
    model.removeObjects(handles)
    if has_existing_objects
      runner.registerWarning('The model contains existing objects and is being reset.')
    end
  end

  def self.calculate_subsurface_parent_buffer(length, width)
    # Calculates the minimum buffer distance that the parent surface
    # needs relative to the subsurface in order to prevent E+ warnings
    # about "Very small surface area".
    min_surface_area = 0.005 # m^2
    return 0.5 * (((length + width)**2 + 4.0 * min_surface_area)**0.5 - length - width)
  end
end
