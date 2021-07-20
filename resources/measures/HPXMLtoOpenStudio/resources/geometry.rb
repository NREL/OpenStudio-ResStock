require_relative 'constants'
require_relative 'unit_conversions'
require_relative 'util'

class Geometry
  def self.has_rear_units(model, runner, units)
    units.each do |unit|
      unit.spaces.each do |space|
        facades = []
        space.surfaces.each do |surface|
          next if surface.surfaceType.downcase != 'wall'
          next if surface.outsideBoundaryCondition.downcase != 'outdoors'

          facade = Geometry.get_facade_for_surface(surface)
          unless facades.include? facade
            facades << facade
          end
        end
        next if facades.empty?

        if facades.include?(Constants.FacadeFront) && facades.include?(Constants.FacadeBack)
        elsif facades.include?(Constants.FacadeLeft) && facades.include?(Constants.FacadeRight)
        else
          return true
        end
      end
    end
    return false
  end

  def self.get_abs_azimuth(azimuth_type, relative_azimuth, building_orientation, offset = 180.0)
    azimuth = nil
    if azimuth_type == Constants.CoordRelative
      azimuth = relative_azimuth + building_orientation + offset
    elsif azimuth_type == Constants.CoordAbsolute
      azimuth = relative_azimuth + offset
    end

    # Ensure azimuth is >=0 and <=360
    while azimuth < 0.0
      azimuth += 360.0
    end

    while azimuth >= 360.0
      azimuth -= 360.0
    end

    return azimuth
  end

  def self.get_abs_tilt(tilt_type, relative_tilt, roof_tilt, latitude)
    if tilt_type == Constants.TiltPitch
      return relative_tilt + roof_tilt
    elsif tilt_type == Constants.TiltLatitude
      return relative_tilt + latitude
    elsif tilt_type == Constants.CoordAbsolute
      return relative_tilt
    end
  end

  def self.initialize_transformation_matrix(m)
    m[0, 0] = 1
    m[1, 1] = 1
    m[2, 2] = 1
    m[3, 3] = 1
    return m
  end

  def self.get_surface_dimensions(surface)
    least_x = 9e99
    greatest_x = -9e99
    least_y = 9e99
    greatest_y = -9e99
    least_z = 9e99
    greatest_z = -9e99
    surface.vertices.each do |vertex|
      least_x = [vertex.x, least_x].min
      greatest_x = [vertex.x, greatest_x].max
      least_y = [vertex.y, least_y].min
      greatest_y = [vertex.y, greatest_y].max
      least_z = [vertex.z, least_z].min
      greatest_z = [vertex.z, greatest_z].max
    end
    l = greatest_x - least_x
    w = greatest_y - least_y
    h = greatest_z - least_z
    return l, w, h
  end

  def self.get_building_stories(spaces)
    space_min_zs = []
    spaces.each do |space|
      next if not space_is_finished(space)

      surfaces_min_zs = []
      space.surfaces.each do |surface|
        zvalues = getSurfaceZValues([surface])
        surfaces_min_zs << zvalues.min + UnitConversions.convert(space.zOrigin, 'm', 'ft')
      end
      space_min_zs << surfaces_min_zs.min
    end
    return space_min_zs.uniq.length
  end

  def self.get_above_grade_building_stories(spaces)
    space_min_zs = []
    spaces.each do |space|
      next if not space_is_finished(space)
      next if not space_is_above_grade(space)

      surfaces_min_zs = []
      space.surfaces.each do |surface|
        zvalues = getSurfaceZValues([surface])
        surfaces_min_zs << zvalues.min + UnitConversions.convert(space.zOrigin, 'm', 'ft')
      end
      space_min_zs << surfaces_min_zs.min
    end
    return space_min_zs.uniq.length
  end

  def self.make_one_space_from_multiple_spaces(model, spaces)
    new_space = OpenStudio::Model::Space.new(model)
    spaces.each do |space|
      space.surfaces.each do |surface|
        if surface.adjacentSurface.is_initialized && (surface.surfaceType.downcase == 'wall')
          surface.adjacentSurface.get.remove
          surface.remove
        else
          surface.setSpace(new_space)
        end
      end
      space.remove
    end
    return new_space
  end

  def self.make_polygon(*pts)
    p = OpenStudio::Point3dVector.new
    pts.each do |pt|
      p << pt
    end
    return p
  end

  def self.get_building_units(model, runner = nil)
    if model.getSpaces.size == 0
      if !runner.nil?
        runner.registerError('No building geometry has been defined.')
      end
      return
    end

    return_units = []
    model.getBuildingUnits.each do |unit|
      # Remove any units from list that have no associated spaces or are not residential
      next if not ((unit.spaces.size > 0) && (unit.buildingUnitType == Constants.BuildingUnitTypeResidential))

      return_units << unit
    end

    if return_units.size == 0
      # Assume SFD; create single building unit for entire model
      if !runner.nil?
        runner.registerWarning('No building units defined; assuming single-family detached building.')
      end
      unit = OpenStudio::Model::BuildingUnit.new(model)
      unit.setBuildingUnitType(Constants.BuildingUnitTypeResidential)
      unit.setName(Constants.ObjectNameBuildingUnit)
      model.getSpaces.each do |space|
        space.setBuildingUnit(unit)
      end
      model.getBuildingUnits.each do |unit|
        return_units << unit
      end
    end

    # Sort the building units
    unit_numbers = {}
    return_units.each do |unit|
      unit_number = Float(unit.name.to_s.split(' ')[-1])
      unit_numbers[unit] = unit_number
    end

    unit_numbers = unit_numbers.sort_by { |k, v| v }
    return_units = []
    unit_numbers.each do |unit, number|
      return_units << unit
    end

    return return_units
  end

  def self.get_unit_beds_baths(model, unit, runner = nil)
    # Returns a list with #beds, #baths, a list of spaces, and the unit name
    nbeds = unit.additionalProperties.getFeatureAsInteger(Constants.BuildingUnitFeatureNumBedrooms)
    nbaths = unit.additionalProperties.getFeatureAsDouble(Constants.BuildingUnitFeatureNumBathrooms)
    if not (nbeds.is_initialized || nbaths.is_initialized)
      if !runner.nil?
        runner.registerError('Could not determine number of bedrooms or bathrooms.')
      end
      return [nil, nil]
    else
      nbeds = nbeds.get.to_f
      nbaths = nbaths.get
    end
    return [nbeds, nbaths]
  end

  def self.get_unit_occupants(model, unit, runner = nil)
    noccupants = unit.additionalProperties.getFeatureAsDouble(Constants.BuildingUnitFeatureNumOccupants)
    if not noccupants.is_initialized
      if !runner.nil?
        runner.registerError('Could not determine number of occupants.')
      end
      return
    else
      noccupants = noccupants.get.to_f
    end
    return noccupants
  end

  def self.get_unit_adjacent_common_spaces(unit)
    # Returns a list of spaces adjacent to the unit that are not assigned
    # to a building unit.
    spaces = []

    unit.spaces.each do |space|
      space.surfaces.each do |surface|
        next if not surface.adjacentSurface.is_initialized

        adjacent_surface = surface.adjacentSurface.get
        next if not adjacent_surface.space.is_initialized

        adjacent_space = adjacent_surface.space.get
        next if adjacent_space.buildingUnit.is_initialized

        spaces << adjacent_space
      end
    end

    return spaces.uniq
  end

  def self.get_common_spaces(model)
    spaces = []
    model.getSpaces.each do |space|
      next if space.buildingUnit.is_initialized

      spaces << space
    end
    return spaces
  end

  def self.get_floor_area_from_spaces(spaces, runner = nil)
    floor_area = 0
    spaces.each do |space|
      floor_area += UnitConversions.convert(space.floorArea, 'm^2', 'ft^2')
    end
    if (floor_area == 0) && (not runner.nil?)
      runner.registerError('Could not find any floor area.')
      return
    end
    return floor_area
  end

  def self.get_zone_volume(zone, runner = nil)
    if zone.isVolumeAutocalculated || (not zone.volume.is_initialized)
      # Calculate volume from spaces
      volume = 0
      zone.spaces.each do |space|
        volume += UnitConversions.convert(space.volume, 'm^3', 'ft^3')
      end
    else
      volume = UnitConversions.convert(zone.volume.get, 'm^3', 'ft^3')
    end
    if (volume <= 0) && (not runner.nil?)
      runner.registerError('Could not find any volume.')
      return
    end
    return volume
  end

  def self.get_finished_floor_area_from_spaces(spaces, runner = nil, apply_mult = false)
    floor_area = 0
    spaces.each do |space|
      next if not space_is_finished(space)

      mult = 1.0
      if apply_mult
        mult = space.multiplier.to_f
      end
      floor_area += UnitConversions.convert(space.floorArea * mult, 'm^2', 'ft^2')
    end
    if (floor_area == 0) && (not runner.nil?)
      runner.registerError('Could not find any finished floor area.')
      return
    end
    return floor_area
  end

  def self.get_above_grade_finished_floor_area_from_spaces(spaces, runner = nil)
    floor_area = 0
    spaces.each do |space|
      next if not (space_is_finished(space) && space_is_above_grade(space))

      floor_area += UnitConversions.convert(space.floorArea, 'm^2', 'ft^2')
    end
    if (floor_area == 0) && (not runner.nil?)
      runner.registerError('Could not find any above-grade finished floor area.')
      return
    end
    return floor_area
  end

  def self.get_above_grade_finished_volume(model, runner = nil)
    volume = 0
    model.getThermalZones.each do |zone|
      next if not (zone_is_finished(zone) && zone_is_above_grade(zone))

      volume += get_zone_volume(zone, runner)
    end
    if (volume == 0) && (not runner.nil?)
      runner.registerError('Could not find any above-grade finished volume.')
      return
    end
    return volume
  end

  def self.get_above_grade_finished_volume_from_spaces(spaces, runner = nil)
    volume = 0
    get_thermal_zones_from_spaces(spaces).each do |zone|
      next if not (zone_is_finished(zone) && zone_is_above_grade(zone))

      volume += get_zone_volume(zone, runner)
    end
    if (volume == 0) && (not runner.nil?)
      runner.registerError('Could not find any above-grade finished volume.')
      return
    end
    return volume
  end

  def self.get_window_area_from_spaces(spaces)
    window_area = 0
    spaces.each do |space|
      space.surfaces.each do |surface|
        surface.subSurfaces.each do |subsurface|
          next if subsurface.subSurfaceType.downcase != 'fixedwindow'

          window_area += UnitConversions.convert(subsurface.grossArea, 'm^2', 'ft^2')
        end
      end
    end
    return window_area
  end

  def self.space_height(space)
    return Geometry.get_height_of_spaces([space])
  end

  # Calculates space heights as the max z coordinate minus the min z coordinate
  def self.get_height_of_spaces(spaces)
    minzs = []
    maxzs = []
    spaces.each do |space|
      zvalues = getSurfaceZValues(space.surfaces)
      minzs << zvalues.min + UnitConversions.convert(space.zOrigin, 'm', 'ft')
      maxzs << zvalues.max + UnitConversions.convert(space.zOrigin, 'm', 'ft')
    end
    return maxzs.max - minzs.min
  end

  # Calculates the surface height as the max z coordinate minus the min z coordinate
  def self.surface_height(surface)
    zvalues = getSurfaceZValues([surface])
    minz = zvalues.min
    maxz = zvalues.max
    return maxz - minz
  end

  def self.zone_is_finished(zone)
    zone.spaces.each do |space|
      unless space_is_finished(space)
        return false
      end
    end
  end

  # Returns true if all spaces in zone are fully above grade
  def self.zone_is_above_grade(zone)
    spaces_are_above_grade = []
    zone.spaces.each do |space|
      spaces_are_above_grade << space_is_above_grade(space)
    end
    if spaces_are_above_grade.all?
      return true
    end

    return false
  end

  # Returns true if all spaces in zone are either fully or partially below grade
  def self.zone_is_below_grade(zone)
    return !zone_is_above_grade(zone)
  end

  def self.get_finished_above_and_below_grade_zones(thermal_zones)
    finished_living_zones = []
    finished_basement_zones = []
    thermal_zones.each do |thermal_zone|
      next unless zone_is_finished(thermal_zone)

      if zone_is_above_grade(thermal_zone)
        finished_living_zones << thermal_zone
      elsif zone_is_below_grade(thermal_zone)
        finished_basement_zones << thermal_zone
      end
    end
    return finished_living_zones, finished_basement_zones
  end

  def self.get_thermal_zones_from_spaces(spaces)
    thermal_zones = []
    spaces.each do |space|
      next unless space.thermalZone.is_initialized

      unless thermal_zones.include? space.thermalZone.get
        thermal_zones << space.thermalZone.get
      end
    end
    return thermal_zones
  end

  def self.get_building_type(model)
    building_type = nil
    unless model.getBuilding.standardsBuildingType.empty?
      building_type = model.getBuilding.standardsBuildingType.get.downcase
    end
    return building_type
  end

  def self.space_is_unfinished(space)
    return !space_is_finished(space)
  end

  def self.space_is_finished(space)
    unless space.isPlenum
      if space.spaceType.is_initialized
        if space.spaceType.get.standardsSpaceType.is_initialized
          return is_living_space_type(space.spaceType.get.standardsSpaceType.get)
        end
      end
    end
    return false
  end

  def self.is_living_space_type(space_type)
    if [Constants.SpaceTypeLiving, Constants.SpaceTypeFinishedBasement, Constants.SpaceTypeKitchen,
        Constants.SpaceTypeBedroom, Constants.SpaceTypeBathroom, Constants.SpaceTypeLaundryRoom].include? space_type
      return true
    end

    return false
  end

  # Returns true if space is fully above grade
  def self.space_is_above_grade(space)
    return !space_is_below_grade(space)
  end

  # Returns true if space is either fully or partially below grade
  def self.space_is_below_grade(space)
    space.surfaces.each do |surface|
      next if surface.surfaceType.downcase != 'wall'

      z_vertex = []
      surface.vertices.each do |vertex|
        z_vertex << vertex.z
      end
      if z_vertex.min < -1e-9
        return true
      end
      if surface.outsideBoundaryCondition.downcase == 'foundation'
        return true
      end
    end
    return false
  end

  def self.space_has_roof(space)
    space.surfaces.each do |surface|
      next if surface.surfaceType.downcase != 'roofceiling'
      next if surface.outsideBoundaryCondition.downcase != 'outdoors'
      next if surface.tilt == 0

      return true
    end
    return false
  end

  def self.space_below_is_finished(space)
    space.surfaces.each do |surface|
      next if surface.surfaceType.downcase != 'floor'
      next if not surface.adjacentSurface.is_initialized
      next if not surface.adjacentSurface.get.space.is_initialized

      adjacent_space = surface.adjacentSurface.get.space.get
      next if not space_is_finished(adjacent_space)

      return true
    end
    return false
  end

  def self.get_model_locations(model)
    locations = []
    model.getSpaceTypes.each do |spaceType|
      next if not spaceType.standardsSpaceType.is_initialized

      locations << spaceType.standardsSpaceType.get
    end
    return locations
  end

  def self.get_space_from_location(unit, location, location_hierarchy)
    spaces = unit.spaces + get_unit_adjacent_common_spaces(unit)
    if location == Constants.Auto
      location_hierarchy.each do |space_type|
        spaces.each do |space|
          next if not space_is_of_type(space, space_type)

          return space
        end
      end
    else
      spaces.each do |space|
        next if not space.spaceType.is_initialized
        next if not space.spaceType.get.standardsSpaceType.is_initialized
        next if space.spaceType.get.standardsSpaceType.get != location

        return space
      end
    end
    return
  end

  # Return an array of x values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
  def self.getSurfaceXValues(surfaceArray)
    xValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        xValueArray << UnitConversions.convert(vertex.x, 'm', 'ft').round(5)
      end
    end
    return xValueArray
  end

  # Return an array of y values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
  def self.getSurfaceYValues(surfaceArray)
    yValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        yValueArray << UnitConversions.convert(vertex.y, 'm', 'ft').round(5)
      end
    end
    return yValueArray
  end

  # Return an array of z values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
  def self.getSurfaceZValues(surfaceArray)
    zValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        zValueArray << UnitConversions.convert(vertex.z, 'm', 'ft').round(5)
      end
    end
    return zValueArray
  end

  def self.get_space_floor_z(space)
    space.surfaces.each do |surface|
      next unless surface.surfaceType.downcase == 'floor'

      return getSurfaceZValues([surface])[0]
    end
  end

  def self.get_z_origin_for_zone(zone)
    z_origins = []
    zone.spaces.each do |space|
      z_origins << UnitConversions.convert(space.zOrigin, 'm', 'ft')
    end
    return z_origins.min
  end

  # Takes in a list of spaces and returns the average space height
  def self.spaces_avg_height(spaces)
    return if spaces.size == 0

    sum_height = 0
    spaces.each do |space|
      sum_height += space_height(space)
    end
    return sum_height / spaces.size
  end

  # Takes in a list of surfaces and returns the total gross area
  def self.calculate_total_area_from_surfaces(surfaces)
    total_area = 0
    surfaces.each do |surface|
      total_area += UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2')
    end
    return total_area
  end

  # Takes in a list of spaces and returns the total above grade wall area
  def self.calculate_above_grade_wall_area(spaces)
    wall_area = 0
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != 'wall'
        next if surface.outsideBoundaryCondition.downcase == 'foundation'

        wall_area += UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2')
      end
    end
    return wall_area.round(5)
  end

  def self.calculate_above_grade_exterior_wall_area(spaces)
    wall_area = 0
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != 'wall'
        next if surface.outsideBoundaryCondition.downcase != 'outdoors'
        next if surface.outsideBoundaryCondition.downcase == 'foundation'
        next unless space_is_finished(surface.space.get)

        wall_area += UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2')
      end
    end
    return wall_area.round(5)
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

  # Checks if the surface is between finished space and outside
  def self.is_exterior_surface(surface)
    if (surface.outsideBoundaryCondition.downcase != 'outdoors') || (not surface.space.is_initialized)
      return false
    end
    if not space_is_finished(surface.space.get)
      return false
    end

    return true
  end

  # Checks if the surface is between finished and unfinished space
  def self.is_interzonal_surface(surface)
    if (surface.outsideBoundaryCondition.downcase != 'surface') || (not surface.space.is_initialized) || (not surface.adjacentSurface.is_initialized)
      return false
    end

    adjacent_surface = surface.adjacentSurface.get
    if not adjacent_surface.space.is_initialized
      return false
    end
    if space_is_finished(surface.space.get) == space_is_finished(adjacent_surface.space.get)
      return false
    end

    return true
  end

  def self.is_pier_beam_surface(surface)
    if not surface.space.is_initialized
      return false
    end
    if not Geometry.is_pier_beam(surface.space.get)
      return false
    end

    return true
  end

  # Takes in a list of floor surfaces for which to calculate the exposed perimeter.
  # Returns the total exposed perimeter.
  # NOTE: Does not work for buildings with non-orthogonal walls.
  def self.calculate_exposed_perimeter(model, ground_floor_surfaces, has_foundation_walls = false)
    perimeter = 0

    # Get ground edges
    if not has_foundation_walls
      # Use edges from floor surface
      ground_edges = get_edges_for_surfaces(ground_floor_surfaces, false)
    else
      # Use top edges from foundation walls instead
      surfaces = []
      ground_floor_surfaces.each do |ground_floor_surface|
        next if not ground_floor_surface.space.is_initialized

        foundation_space = ground_floor_surface.space.get
        wall_surfaces = []
        foundation_space.surfaces.each do |surface|
          next if not surface.surfaceType.downcase == 'wall'
          next if surface.adjacentSurface.is_initialized

          wall_surfaces << surface
        end
        get_walls_connected_to_floor(wall_surfaces, ground_floor_surface).each do |surface|
          next if surfaces.include? surface

          surfaces << surface
        end
      end
      ground_edges = get_edges_for_surfaces(surfaces, true)
    end
    # Get bottom edges of exterior walls (building footprint)
    surfaces = []
    model.getSurfaces.each do |surface|
      next if not surface.surfaceType.downcase == 'wall'
      next if surface.outsideBoundaryCondition.downcase != 'outdoors'

      surfaces << surface
    end
    model_edges = get_edges_for_surfaces(surfaces, false)

    # compare edges for overlap
    ground_edges.each do |e1|
      model_edges.each do |e2|
        next if not is_point_between(e2[0], e1[0], e1[1])
        next if not is_point_between(e2[1], e1[0], e1[1])

        point_one = OpenStudio::Point3d.new(e2[0][0], e2[0][1], e2[0][2])
        point_two = OpenStudio::Point3d.new(e2[1][0], e2[1][1], e2[1][2])
        length = OpenStudio::Vector3d.new(point_one - point_two).length
        perimeter += length
      end
    end

    return UnitConversions.convert(perimeter, 'm', 'ft')
  end

  def self.is_point_between(p, v1, v2)
    # Checks if point p is between points v1 and v2
    is_between = false
    tol = 0.001
    if ((p[2] - v1[2]).abs <= tol) && ((p[2] - v2[2]).abs <= tol) # equal z
      if ((p[0] - v1[0]).abs <= tol) && ((p[0] - v2[0]).abs <= tol) # equal x; vertical
        if (p[1] >= v1[1] - tol) && (p[1] <= v2[1] + tol)
          is_between = true
        elsif (p[1] <= v1[1] + tol) && (p[1] >= v2[1] - tol)
          is_between = true
        end
      elsif ((p[1] - v1[1]).abs <= tol) && ((p[1] - v2[1]).abs <= tol) # equal y; horizontal
        if (p[0] >= v1[0] - tol) && (p[0] <= v2[0] + tol)
          is_between = true
        elsif (p[0] <= v1[0] + tol) && (p[0] >= v2[0] - tol)
          is_between = true
        end
      end
    end
    return is_between
  end

  def self.get_edges_for_surfaces(surfaces, use_top_edge)
    top_z = -99999
    bottom_z = 99999
    surfaces.each do |surface|
      top_z = [getSurfaceZValues([surface]).max, top_z].max
      bottom_z = [getSurfaceZValues([surface]).min, bottom_z].min
    end
    edges = []
    edge_counter = 0
    surfaces.each do |surface|
      if use_top_edge
        matchz = top_z
      else
        matchz = bottom_z
      end

      # get vertices
      vertex_hash = {}
      vertex_counter = 0
      surface.vertices.each do |vertex|
        next if (UnitConversions.convert(vertex.z, 'm', 'ft') - matchz).abs > 0.0001 # ensure we only process bottom/top edge of wall surfaces

        vertex_counter += 1
        vertex_hash[vertex_counter] = [vertex.x + surface.space.get.xOrigin,
                                       vertex.y + surface.space.get.yOrigin,
                                       vertex.z + surface.space.get.zOrigin]
      end
      # make edges
      counter = 0
      vertex_hash.each do |k, v|
        edge_counter += 1
        counter += 1
        if vertex_hash.size != counter
          edges << [v, vertex_hash[counter + 1], get_facade_for_surface(surface)]
        elsif vertex_hash.size > 2 # different code for wrap around vertex (if > 2 vertices)
          edges << [v, vertex_hash[1], get_facade_for_surface(surface)]
        end
      end
    end

    return edges
  end

  def self.equal_vertices(v1, v2)
    tol = 0.001
    return false if (v1[0] - v2[0]).abs > tol
    return false if (v1[1] - v2[1]).abs > tol
    return false if (v1[2] - v2[2]).abs > tol

    return true
  end

  def self.get_walls_connected_to_floor(wall_surfaces, floor_surface, same_space = true)
    adjacent_wall_surfaces = []

    wall_surfaces.each do |wall_surface|
      if same_space
        next if wall_surface.space.get != floor_surface.space.get
      else
        next if wall_surface.space.get == floor_surface.space.get
      end

      wall_vertices = wall_surface.vertices
      wall_vertices.each_with_index do |wv1, widx|
        wv2 = wall_vertices[widx - 1]
        floor_vertices = floor_surface.vertices
        floor_vertices.each_with_index do |fv1, fidx|
          fv2 = floor_vertices[fidx - 1]
          # Wall within floor edge?
          next unless is_point_between([wv1.x, wv1.y, wv1.z], [fv1.x, fv1.y, fv1.z], [fv2.x, fv2.y, fv2.z]) && is_point_between([wv2.x, wv2.y, wv2.z], [fv1.x, fv1.y, fv1.z], [fv2.x, fv2.y, fv2.z])

          if not adjacent_wall_surfaces.include? wall_surface
            adjacent_wall_surfaces << wall_surface
          end
        end
      end
    end

    return adjacent_wall_surfaces
  end

  def self.is_living(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeLiving)
  end

  def self.is_pier_beam(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypePierBeam)
  end

  def self.is_crawl(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeCrawl)
  end

  def self.is_finished_basement(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeFinishedBasement)
  end

  def self.is_unfinished_basement(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeUnfinishedBasement)
  end

  def self.is_unfinished_attic(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeUnfinishedAttic)
  end

  def self.is_garage(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeGarage)
  end

  def self.is_corridor(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeCorridor)
  end

  def self.is_bedroom(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeBedroom)
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
    # if any spaces in zone are space_type
    result = false
    zone.spaces.each do |space|
      next unless space_is_of_type(space, space_type)

      result = true
    end
    return result
  end

  def self.is_basement(space_or_zone)
    if space_or_zone.is_a? OpenStudio::Model::Space
      return space_is_below_grade(space_or_zone)
    elsif space_or_zone.is_a? OpenStudio::Model::ThermalZone
      return zone_is_below_grade(space_or_zone)
    end
  end

  def self.is_attic(space_or_zone)
    if space_or_zone.is_a? OpenStudio::Model::Space
      space_or_zone.surfaces.each do |surface|
        next unless surface.surfaceType.downcase.to_s == 'roofceiling'
        unless surface.outsideBoundaryCondition.downcase.to_s == 'outdoors'
          return false
        end
      end
      space_or_zone.surfaces.each do |surface|
        next unless surface.surfaceType.downcase.to_s == 'floor'

        surface.vertices.each do |vertex|
          unless vertex.z + space_or_zone.zOrigin > 0 # not an attic if it isn't above grade
            return false
          end
        end
      end
    elsif space_or_zone.is_a? OpenStudio::Model::ThermalZone
      space_or_zone.spaces.each do |space|
        space.surfaces.each do |surface|
          next unless surface.surfaceType.downcase.to_s == 'roofceiling'
          if not surface.outsideBoundaryCondition.downcase.to_s == 'outdoors'
            return false
          end
        end
        space.surfaces.each do |surface|
          next unless surface.surfaceType.downcase.to_s == 'floor'

          surface.vertices.each do |vertex|
            unless vertex.z + space.zOrigin > 0 # not an attic if it isn't above grade
              return false
            end
          end
        end
      end
    end
  end

  def self.is_foundation(space_or_zone)
    return true if is_pier_beam(space_or_zone) || is_crawl(space_or_zone) || is_finished_basement(space_or_zone) || is_unfinished_basement(space_or_zone)
  end

  def self.get_crawl_spaces(spaces)
    crawl_spaces = []
    spaces.each do |space|
      next if not is_crawl(space)

      crawl_spaces << space
    end
    return crawl_spaces
  end

  def self.get_pier_beam_spaces(spaces)
    pb_spaces = []
    spaces.each do |space|
      next if not is_pier_beam(space)

      pb_spaces << space
    end
    return pb_spaces
  end

  def self.get_finished_spaces(spaces)
    finished_spaces = []
    spaces.each do |space|
      next if space_is_unfinished(space)

      finished_spaces << space
    end
    return finished_spaces
  end

  def self.get_bedroom_spaces(spaces)
    bedroom_spaces = []
    spaces.each do |space|
      next if not is_bedroom(space)
    end
    return bedroom_spaces
  end

  def self.get_finished_basement_spaces(spaces)
    finished_basement_spaces = []
    spaces.each do |space|
      next if not is_finished_basement(space)

      finished_basement_spaces << space
    end
    return finished_basement_spaces
  end

  def self.get_unfinished_basement_spaces(spaces)
    unfinished_basement_spaces = []
    spaces.each do |space|
      next if not is_unfinished_basement(space)

      unfinished_basement_spaces << space
    end
    return unfinished_basement_spaces
  end

  def self.get_unfinished_attic_spaces(spaces)
    unfinished_attic_spaces = []
    spaces.each do |space|
      next if not is_unfinished_attic(space)

      unfinished_attic_spaces << space
    end
    return unfinished_attic_spaces
  end

  def self.get_garage_spaces(spaces)
    garage_spaces = []
    spaces.each do |space|
      next if not is_garage(space)

      garage_spaces << space
    end
    return garage_spaces
  end

  def self.get_facade_for_surface(surface)
    tol = 0.001
    n = surface.outwardNormal
    facade = nil
    if n.z.abs < tol
      if (n.x.abs < tol) && ((n.y + 1).abs < tol)
        facade = Constants.FacadeFront
      elsif ((n.x - 1).abs < tol) && (n.y.abs < tol)
        facade = Constants.FacadeRight
      elsif (n.x.abs < tol) && ((n.y - 1).abs < tol)
        facade = Constants.FacadeBack
      elsif ((n.x + 1).abs < tol) && (n.y.abs < tol)
        facade = Constants.FacadeLeft
      end
    else
      if (n.x.abs < tol) && (n.y < 0)
        facade = Constants.FacadeFront
      elsif (n.x > 0) && (n.y.abs < tol)
        facade = Constants.FacadeRight
      elsif (n.x.abs < tol) && (n.y > 0)
        facade = Constants.FacadeBack
      elsif (n.x < 0) && (n.y.abs < tol)
        facade = Constants.FacadeLeft
      end
    end
    return facade
  end

  def self.get_surface_length(surface)
    xvalues = getSurfaceXValues([surface])
    yvalues = getSurfaceYValues([surface])
    xrange = xvalues.max - xvalues.min
    yrange = yvalues.max - yvalues.min
    if xrange > yrange
      return xrange
    end

    return yrange
  end

  def self.get_surface_height(surface)
    zvalues = getSurfaceZValues([surface])
    zrange = zvalues.max - zvalues.min
    return zrange
  end

  def self.is_gable_wall(surface)
    if ((surface.surfaceType.downcase != 'wall') || (surface.outsideBoundaryCondition.downcase != 'outdoors'))
      return false
    end
    if surface.vertices.size != 3
      return false
    end
    if not surface.space.is_initialized
      return false
    end

    space = surface.space.get
    if not space_has_roof(space)
      return false
    end

    return true
  end

  def self.is_rectangular_wall(surface)
    if ((surface.surfaceType.downcase != 'wall') || (surface.outsideBoundaryCondition.downcase != 'outdoors'))
      return false
    end
    if surface.vertices.size != 4
      return false
    end

    xvalues = getSurfaceXValues([surface])
    yvalues = getSurfaceYValues([surface])
    zvalues = getSurfaceZValues([surface])
    if not (((xvalues.uniq.size == 1) && (yvalues.uniq.size == 2)) ||
            ((xvalues.uniq.size == 2) && (yvalues.uniq.size == 1)))
      return false
    end
    if not zvalues.uniq.size == 2
      return false
    end

    return true
  end

  def self.get_closest_neighbor_distance(model)
    # House surfaces
    house_points = []
    model.getSurfaces.each do |surface|
      next unless surface.surfaceType.downcase == 'wall'

      surface.vertices.each do |vertex|
        house_points << OpenStudio::Point3d.new(vertex)
      end
    end

    # Neighbor surfaces
    neighbor_points = {}
    model.getShadingSurfaces.each do |shading_surface|
      next unless shading_surface.name.to_s.downcase.include? 'neighbor'

      xs, ys = [], []
      shading_surface.vertices.each do |vertex|
        xs << vertex.x
        ys << vertex.y
      end
      xs, ys = xs.uniq, ys.uniq
      neighbor_points[shading_surface.name.to_s] = {}
      if xs.length == 1 # Shading surface on x plane
        neighbor_points[shading_surface.name.to_s]['x'] = xs[0]
      elsif ys.length == 1 # Shading surface on y plane
        neighbor_points[shading_surface.name.to_s]['y'] = ys[0]
      end
    end

    # Calculate offset
    neighbor_offsets = []
    house_points.each do |house_point|
      neighbor_points.each_value do |neighbor_point|
        if neighbor_point['x'] # On x plane
          neighbor_offsets << (house_point.x - neighbor_point['x']).abs
        elsif neighbor_point['y'] # On y plane
          neighbor_offsets << (house_point.y - neighbor_point['y']).abs
        end
      end
    end

    if neighbor_offsets.empty?
      return 0
    end

    return UnitConversions.convert(neighbor_offsets.min, 'm', 'ft')
  end

  def self.get_spaces_above_grade_exterior_walls(spaces)
    above_grade_exterior_walls = []
    spaces.each do |space|
      next if not Geometry.space_is_finished(space)
      next if not Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if above_grade_exterior_walls.include?(surface)
        next if surface.surfaceType.downcase != 'wall'
        next if surface.outsideBoundaryCondition.downcase != 'outdoors'

        above_grade_exterior_walls << surface
      end
    end
    return above_grade_exterior_walls
  end

  def self.get_spaces_above_grade_exterior_floors(spaces)
    above_grade_exterior_floors = []
    spaces.each do |space|
      next if not Geometry.space_is_finished(space)
      next if not Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if above_grade_exterior_floors.include?(surface)
        next if surface.surfaceType.downcase != 'floor'
        next if surface.outsideBoundaryCondition.downcase != 'outdoors'

        above_grade_exterior_floors << surface
      end
    end
    return above_grade_exterior_floors
  end

  def self.get_spaces_above_grade_ground_floors(spaces)
    above_grade_ground_floors = []
    spaces.each do |space|
      next if not Geometry.space_is_finished(space)
      next if not Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if above_grade_ground_floors.include?(surface)
        next if surface.surfaceType.downcase != 'floor'
        next if surface.outsideBoundaryCondition.downcase != 'foundation'

        above_grade_ground_floors << surface
      end
    end
    return above_grade_ground_floors
  end

  def self.get_spaces_above_grade_exterior_roofs(spaces)
    above_grade_exterior_roofs = []
    spaces.each do |space|
      next if not Geometry.space_is_finished(space)
      next if not Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if above_grade_exterior_roofs.include?(surface)
        next if surface.surfaceType.downcase != 'roofceiling'
        next if surface.outsideBoundaryCondition.downcase != 'outdoors'

        above_grade_exterior_roofs << surface
      end
    end
    return above_grade_exterior_roofs
  end

  def self.get_spaces_interzonal_walls(spaces)
    interzonal_walls = []
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if interzonal_walls.include?(surface)
        next if surface.surfaceType.downcase != 'wall'
        next if not is_interzonal_surface(surface)

        interzonal_walls << surface
      end
    end
    return interzonal_walls
  end

  def self.get_spaces_interzonal_floors_and_ceilings(spaces)
    interzonal_floors = []
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if interzonal_floors.include?(surface)
        next if (surface.surfaceType.downcase != 'floor') && (surface.surfaceType.downcase != 'roofceiling')
        next if not is_interzonal_surface(surface)

        interzonal_floors << surface
      end
    end
    return interzonal_floors
  end

  def self.get_spaces_below_grade_exterior_walls(spaces)
    below_grade_exterior_walls = []
    spaces.each do |space|
      next if not Geometry.space_is_finished(space)
      next if not Geometry.space_is_below_grade(space)

      space.surfaces.each do |surface|
        next if below_grade_exterior_walls.include?(surface)
        next if surface.surfaceType.downcase != 'wall'
        next if surface.outsideBoundaryCondition.downcase != 'foundation'

        below_grade_exterior_walls << surface
      end
    end
    return below_grade_exterior_walls
  end

  def self.get_spaces_below_grade_exterior_floors(spaces)
    below_grade_exterior_floors = []
    spaces.each do |space|
      next if not Geometry.space_is_finished(space)
      next if not Geometry.space_is_below_grade(space)

      space.surfaces.each do |surface|
        next if below_grade_exterior_floors.include?(surface)
        next if surface.surfaceType.downcase != 'floor'
        next if surface.outsideBoundaryCondition.downcase != 'foundation'

        below_grade_exterior_floors << surface
      end
    end
    return below_grade_exterior_floors
  end

  def self.process_overhangs(model, runner, depth, offset, facade_bools_hash)
    # Error checking
    if depth < 0
      runner.registerError('Overhang depth must be greater than or equal to 0.')
      return false
    end
    if offset < 0
      runner.registerError('Overhang offset must be greater than or equal to 0.')
      return false
    end
    # if width_extension < 0
    # runner.registerError("Overhang width extension must be greater than or equal to 0.")
    # return false
    # end

    sub_surfaces = get_window_sub_surfaces(model)

    # Remove existing overhangs
    num_removed = 0
    model.getShadingSurfaceGroups.each do |shading_surface_group|
      remove_group = false
      shading_surface_group.shadingSurfaces.each do |shading_surface|
        next unless shading_surface.name.to_s.downcase.include? Constants.ObjectNameOverhangs

        num_removed += 1
        remove_group = true
      end
      if remove_group
        shading_surface_group.remove
      end
    end
    if num_removed > 0
      runner.registerInfo("Removed #{num_removed} #{Constants.ObjectNameOverhangs}.")
    end

    # No overhangs to add? Exit here.
    if depth == 0
      runner.registerInfo("No #{Constants.ObjectNameOverhangs} to be added.")
      return true
    end

    num_added = 0
    sub_surfaces.each do |sub_surface|
      facade = get_facade_for_surface(sub_surface)
      next if facade.nil?
      next if !facade_bools_hash["#{facade} Facade"]

      overhang = sub_surface.addOverhang(depth, offset)
      overhang.get.setName("#{sub_surface.name} - #{Constants.ObjectNameOverhangs}")
      num_added += 1

      sub_surface.additionalProperties.setFeature(Constants.SizingInfoWindowOverhangDepth, depth)
      sub_surface.additionalProperties.setFeature(Constants.SizingInfoWindowOverhangOffset, offset)
    end

    unless num_added > 0
      runner.registerInfo("No windows found for adding #{Constants.ObjectNameOverhangs}.")
      return true
    end

    runner.registerInfo("Added #{num_added} #{Constants.ObjectNameOverhangs}.")
    return true
  end

  def self.get_window_sub_surfaces(model)
    sub_surfaces = []
    model.getSubSurfaces.each do |sub_surface|
      next unless sub_surface.subSurfaceType.downcase.include? 'window'
      next if (90 - sub_surface.tilt * 180 / Math::PI).abs > 0.01 # not a vertical subsurface

      sub_surfaces << sub_surface
    end
    return sub_surfaces
  end

  def self.process_beds_and_baths(model, runner, num_br, num_ba)
    # Error checking
    if not num_br.all? { |x| MathTools.valid_float?(x) }
      runner.registerError('Number of bedrooms must be a numerical value.')
      return false
    else
      num_br = num_br.map(&:to_f)
    end
    if not num_ba.all? { |x| MathTools.valid_float?(x) }
      runner.registerError('Number of bathrooms must be a numerical value.')
      return false
    else
      num_ba = num_ba.map(&:to_f)
    end
    if num_br.any? { |x| (x < 0) || (x % 1 != 0) }
      runner.registerError('Number of bedrooms must be a non-negative integer.')
      return false
    end
    if num_ba.any? { |x| (x <= 0) || (x % 0.25 != 0) }
      runner.registerError('Number of bathrooms must be a positive multiple of 0.25.')
      return false
    end
    if (num_br.length > 1) && (num_ba.length > 1) && (num_br.length != num_ba.length)
      runner.registerError('Number of bedroom elements specified inconsistent with number of bathroom elements specified.')
      return false
    end

    # Get building units
    units = get_building_units(model, runner)
    if units.nil?
      return false
    end

    # error checking
    if (num_br.length > 1) && (num_br.length != units.size)
      runner.registerError('Number of bedroom elements specified inconsistent with number of multifamily units defined in the model.')
      return false
    end
    if (num_ba.length > 1) && (num_ba.length != units.size)
      runner.registerError('Number of bathroom elements specified inconsistent with number of multifamily units defined in the model.')
      return false
    end

    if units.size > 1
      if num_br.length == 1
        num_br = Array.new(units.size, num_br[0])
      end
      if num_ba.length == 1
        num_ba = Array.new(units.size, num_ba[0])
      end
    end

    # Update number of bedrooms/bathrooms
    total_num_br = 0
    total_num_ba = 0
    units.each_with_index do |unit, unit_index|
      num_br[unit_index] = num_br[unit_index].to_i
      num_ba[unit_index] = num_ba[unit_index].to_f

      unit.additionalProperties.setFeature(Constants.BuildingUnitFeatureNumBedrooms, num_br[unit_index])
      unit.additionalProperties.setFeature(Constants.BuildingUnitFeatureNumBathrooms, num_ba[unit_index])

      if units.size > 1
        runner.registerInfo("Unit '#{unit_index}' has been assigned #{num_br[unit_index].to_s} bedroom(s) and #{num_ba[unit_index].round(2).to_s} bathroom(s).")
      end

      total_num_br += num_br[unit_index]
      total_num_ba += num_ba[unit_index]
    end

    runner.registerInfo("The building has been assigned #{total_num_br.to_s} bedroom(s) and #{total_num_ba.round(2).to_s} bathroom(s) across #{units.size} unit(s).")
    return true
  end

  def self.process_occupants(model, runner, num_occ, occ_gain, sens_frac, lat_frac, schedules_file)
    num_occ = num_occ.split(',').map(&:strip)
    # Error checking
    if occ_gain < 0
      runner.registerError('Internal gains cannot be negative.')
      return false
    end

    if (sens_frac < 0) || (sens_frac > 1)
      runner.registerError('Sensible fraction must be greater than or equal to 0 and less than or equal to 1.')
      return false
    end
    if (lat_frac < 0) || (lat_frac > 1)
      runner.registerError('Latent fraction must be greater than or equal to 0 and less than or equal to 1.')
      return false
    end
    if lat_frac + sens_frac > 1
      runner.registerError('Sum of sensible and latent fractions must be less than or equal to 1.')
      return false
    end

    # Get building units
    units = get_building_units(model, runner)
    if units.nil?
      return false
    end

    # Error checking
    if (num_occ.length > 1) && (num_occ.length != units.size)
      runner.registerError('Number of occupant elements specified inconsistent with number of multifamily units defined in the model.')
      return false
    end

    if (units.size > 1) && (num_occ.length == 1)
      num_occ = Array.new(units.size, num_occ[0])
    end

    activity_per_person = UnitConversions.convert(occ_gain, 'Btu/hr', 'W')

    # Hard-coded convective, radiative, latent, and lost fractions
    occ_lat = lat_frac
    occ_sens = sens_frac
    occ_conv = 0.442 * occ_sens
    occ_rad = 0.558 * occ_sens
    occ_lost = 1 - occ_lat - occ_conv - occ_rad

    # Update number of occupants
    total_num_occ = 0
    people_sch = nil
    activity_sch = nil
    units.each_with_index do |unit, unit_index|
      unit_occ = num_occ[unit_index]

      if unit_occ != Constants.Auto
        if (not MathTools.valid_float?(unit_occ)) || (unit_occ.to_f < 0)
          runner.registerError("Number of Occupants must be either '#{Constants.Auto}' or a number greater than or equal to 0.")
          return false
        end
      end

      # Get number of beds
      nbeds, nbaths = get_unit_beds_baths(model, unit, runner)
      if nbeds.nil?
        return false
      end

      # Calculate number of occupants for this unit
      if unit_occ == Constants.Auto
        if [Constants.BuildingTypeMultifamily, Constants.BuildingTypeSingleFamilyAttached].include? get_building_type(model) # multifamily equation
          unit_occ = 0.63 + 0.92 * nbeds
          # nbeds = -0.68 + 1.09 * unit_occ
        elsif [Constants.BuildingTypeSingleFamilyDetached].include? get_building_type(model) # single-family equation
          unit_occ = 0.87 + 0.59 * nbeds
          # nbeds = -1.47 + 1.69 * unit_occ
        end
      else
        unit_occ = unit_occ.to_f
      end

      unit.additionalProperties.setFeature(Constants.BuildingUnitFeatureNumOccupants, unit_occ)

      # Get spaces
      bedroom_ffa_spaces = get_bedroom_spaces(unit.spaces)
      non_bedroom_ffa_spaces = get_finished_spaces(unit.spaces) - bedroom_ffa_spaces

      # Get FFA
      non_bedroom_ffa = get_finished_floor_area_from_spaces(non_bedroom_ffa_spaces, runner)
      bedroom_ffa = get_finished_floor_area_from_spaces(bedroom_ffa_spaces)
      bedroom_ffa = 0 if bedroom_ffa.nil?
      ffa = non_bedroom_ffa + bedroom_ffa

      # Design day schedules used when autosizing
      winter_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
      winter_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
      summer_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
      summer_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

      # Assign occupants to each space of the unit
      spaces = non_bedroom_ffa_spaces
      if not bedroom_ffa_spaces.empty?
        spaces = bedroom_ffa_spaces
      end
      spaces.each do |space|
        space_obj_name = "#{Constants.ObjectNameOccupants(unit.name.to_s)}|#{space.name.to_s}"

        # Remove any existing people
        objects_to_remove = []
        space.people.each do |people|
          objects_to_remove << people
          objects_to_remove << people.peopleDefinition
          if people.numberofPeopleSchedule.is_initialized
            objects_to_remove << people.numberofPeopleSchedule.get
          end
          if people.activityLevelSchedule.is_initialized
            objects_to_remove << people.activityLevelSchedule.get
          end
        end
        if objects_to_remove.size > 0
          runner.registerInfo("Removed existing people from space '#{space.name.to_s}'.")
        end
        objects_to_remove.uniq.each do |object|
          begin
            object.remove
          rescue
            # no op
          end
        end

        space_num_occ = unit_occ * UnitConversions.convert(space.floorArea, 'm^2', 'ft^2') / ffa

        next unless space_num_occ > 0

        if people_sch.nil?
          people_sch = schedules_file.create_schedule_file(col_name: 'occupants')
        end

        if activity_sch.nil?
          # Create schedule
          activity_sch = OpenStudio::Model::ScheduleRuleset.new(model, activity_per_person)
        end

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

        total_num_occ += space_num_occ

        runner.registerInfo("#{unit.name.to_s} has been assigned #{space_num_occ.round(2)} occupant(s) for space '#{space.name}'.")
      end
    end

    schedules_file.set_vacancy(col_name: 'occupants')

    runner.registerInfo("The building has been assigned #{total_num_occ.round(2)} occupant(s) across #{units.size} unit(s).")
    return true
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
    sens = sens_gains / tot_gains
    lat = lat_gains / tot_gains
    return heat_gain, hrs_per_day, sens, lat
  end

  def self.process_eaves(model, runner, eaves_depth, roof_structure)
    # Error checking
    if eaves_depth < 0
      runner.registerError('Eaves depth must be greater than or equal to 0.')
      return false
    end

    # Remove existing eaves
    num_removed = 0
    existing_eaves_depth = nil
    model.getShadingSurfaceGroups.each do |shading_surface_group|
      next unless shading_surface_group.name.to_s == Constants.ObjectNameEaves

      shading_surface_group.shadingSurfaces.each do |shading_surface|
        num_removed += 1
        next unless existing_eaves_depth.nil?

        existing_eaves_depth = get_existing_eaves_depth(shading_surface)
      end
      shading_surface_group.remove
    end
    if num_removed > 0
      runner.registerInfo("#{num_removed} #{Constants.ObjectNameEaves} removed.")
    end

    # No eaves to add? Exit here.
    if (eaves_depth == 0) &&
       runner.registerInfo("No #{Constants.ObjectNameEaves} were added.")
      return true
    end

    if existing_eaves_depth.nil?
      existing_eaves_depth = 0
    end

    surfaces_modified = false
    shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
    shading_surface_group.setName(Constants.ObjectNameEaves)

    model.getSurfaces.each do |roof_surface|
      next unless roof_surface.surfaceType.downcase == 'roofceiling'
      next unless roof_surface.outsideBoundaryCondition.downcase == 'outdoors'

      if roof_structure == Constants.RoofStructureTrussCantilever
        l, w, h = get_surface_dimensions(roof_surface)
        if get_building_type(model) == Constants.BuildingTypeSingleFamilyAttached
          lift = (h / w) * eaves_depth
        else
          lift = (h / [l, w].min) * eaves_depth
        end

        m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
        m[2, 3] = lift
        transformation = OpenStudio::Transformation.new(m)
        new_vertices = transformation * roof_surface.vertices
        roof_surface.setVertices(new_vertices)

      end

      surfaces_modified = true

      if roof_surface.vertices.length > 3

        vertex_dir_backup = roof_surface.vertices[-3]
        vertex_dir = roof_surface.vertices[-2]
        vertex_1 = roof_surface.vertices[-1]

        roof_surface.vertices[0..-1].each do |vertex|
          vertex_2 = vertex

          dir_vector = OpenStudio::Vector3d.new(vertex_1.x - vertex_dir.x, vertex_1.y - vertex_dir.y, vertex_1.z - vertex_dir.z) # works if angles are right angles

          if dir_vector.dot(OpenStudio::Vector3d.new(vertex_1.x - vertex_2.x, vertex_1.y - vertex_2.y, vertex_1.z - vertex_2.z)).abs > 0.0001 # ensure perpendicular
            dir_vector = OpenStudio::Vector3d.new(0, vertex_1.y - vertex_dir.y, vertex_1.z - vertex_dir.z)
          end

          if dir_vector.dot(OpenStudio::Vector3d.new(vertex_1.x - vertex_2.x, vertex_1.y - vertex_2.y, vertex_1.z - vertex_2.z)).abs > 0.0001 # ensure perpendicular
            dir_vector = OpenStudio::Vector3d.new(vertex_1.x - vertex_dir.x, 0, vertex_1.z - vertex_dir.z)
          end

          if dir_vector.dot(OpenStudio::Vector3d.new(vertex_1.x - vertex_2.x, vertex_1.y - vertex_2.y, vertex_1.z - vertex_2.z)).abs > 0.0001 # ensure perpendicular
            dir_vector = OpenStudio::Vector3d.new(0, vertex_1.y - vertex_dir.y, vertex_1.z - vertex_dir.z)
          end

          if dir_vector.dot(OpenStudio::Vector3d.new(vertex_1.x - vertex_2.x, vertex_1.y - vertex_2.y, vertex_1.z - vertex_2.z)).abs > 0.0001 # ensure perpendicular
            dir_vector = OpenStudio::Vector3d.new(vertex_1.x - vertex_dir_backup.x, vertex_1.y - vertex_dir_backup.y, vertex_1.z - vertex_dir_backup.z)
          end

          dir_vector_n = OpenStudio::Vector3d.new(dir_vector.x / dir_vector.length, dir_vector.y / dir_vector.length, dir_vector.z / dir_vector.length) # normalize

          l, w, h = get_surface_dimensions(roof_surface)
          tilt = Math.atan(h / [l, w].min)

          z = eaves_depth / Math.cos(tilt)
          if dir_vector_n.z == 0
            scale = 1
          else
            scale = z / eaves_depth
          end

          m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
          m[0, 3] = dir_vector_n.x * eaves_depth * scale
          m[1, 3] = dir_vector_n.y * eaves_depth * scale
          m[2, 3] = dir_vector_n.z * eaves_depth * scale

          new_vertices = OpenStudio::Point3dVector.new
          new_vertices << OpenStudio::Transformation.new(m) * vertex_1
          new_vertices << OpenStudio::Transformation.new(m) * vertex_2
          new_vertices << vertex_2
          new_vertices << vertex_1

          vertex_dir_backup = vertex_dir
          vertex_dir = vertex_1
          vertex_1 = vertex_2

          next if dir_vector.length == 0
          next if dir_vector_n.z > 0

          if OpenStudio::getOutwardNormal(new_vertices).get.z < 0
            transformation = OpenStudio::Transformation.rotation(new_vertices[2], OpenStudio::Vector3d.new(new_vertices[2].x - new_vertices[3].x, new_vertices[2].y - new_vertices[3].y, new_vertices[2].z - new_vertices[3].z), 3.14159)
            new_vertices = transformation * new_vertices
          end

          m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
          m[2, 3] = roof_surface.space.get.zOrigin
          new_vertices = OpenStudio::Transformation.new(m) * new_vertices

          shading_surface = OpenStudio::Model::ShadingSurface.new(new_vertices, model)
          shading_surface.setName("#{roof_surface.name} - #{Constants.ObjectNameEaves}")
          shading_surface.setShadingSurfaceGroup(shading_surface_group)
        end

      elsif roof_surface.vertices.length == 3

        zmin = 9e99
        roof_surface.vertices.each do |vertex|
          zmin = [vertex.z, zmin].min
        end

        vertex_1 = nil
        vertex_2 = nil
        vertex_dir = nil
        roof_surface.vertices.each do |vertex|
          if vertex.z == zmin
            if vertex_1.nil?
              vertex_1 = vertex
            end
          end
          if vertex.z == zmin
            vertex_2 = vertex
          end
          if vertex.z != zmin
            vertex_dir = vertex
          end
        end

        l, w, h = get_surface_dimensions(roof_surface)
        tilt = Math.atan(h / [l, w].min)

        z = eaves_depth / Math.cos(tilt)
        scale = z / eaves_depth

        dir_vector = OpenStudio::Vector3d.new(vertex_1.x - vertex_dir.x, vertex_1.y - vertex_dir.y, vertex_1.z - vertex_dir.z)

        if dir_vector.dot(OpenStudio::Vector3d.new(vertex_1.x - vertex_2.x, vertex_1.y - vertex_2.y, vertex_1.z - vertex_2.z)) != 0 # ensure perpendicular
          dir_vector = OpenStudio::Vector3d.new(vertex_1.x - vertex_dir.x, 0, vertex_1.z - vertex_dir.z)
        end

        if dir_vector.dot(OpenStudio::Vector3d.new(vertex_1.x - vertex_2.x, vertex_1.y - vertex_2.y, vertex_1.z - vertex_2.z)) != 0 # ensure perpendicular
          dir_vector = OpenStudio::Vector3d.new(0, vertex_1.y - vertex_dir.y, vertex_1.z - vertex_dir.z)
        end

        dir_vector_n = OpenStudio::Vector3d.new(dir_vector.x / dir_vector.length, dir_vector.y / dir_vector.length, dir_vector.z / dir_vector.length) # normalize

        m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
        m[0, 3] = dir_vector_n.x * eaves_depth * scale
        m[1, 3] = dir_vector_n.y * eaves_depth * scale
        m[2, 3] = dir_vector_n.z * eaves_depth * scale

        new_vertices = OpenStudio::Point3dVector.new
        new_vertices << OpenStudio::Transformation.new(m) * vertex_1
        new_vertices << OpenStudio::Transformation.new(m) * vertex_2
        new_vertices << vertex_2
        new_vertices << vertex_1

        next if dir_vector.length == 0
        next if dir_vector_n.z > 0

        if OpenStudio::getOutwardNormal(new_vertices).get.z < 0
          transformation = OpenStudio::Transformation.rotation(new_vertices[2], OpenStudio::Vector3d.new(new_vertices[2].x - new_vertices[3].x, new_vertices[2].y - new_vertices[3].y, new_vertices[2].z - new_vertices[3].z), 3.14159)
          new_vertices = transformation * new_vertices
        end

        m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
        m[2, 3] = roof_surface.space.get.zOrigin
        new_vertices = OpenStudio::Transformation.new(m) * new_vertices

        shading_surface = OpenStudio::Model::ShadingSurface.new(new_vertices, model)
        shading_surface.setName("#{roof_surface.name} - #{Constants.ObjectNameEaves}")
        shading_surface.setShadingSurfaceGroup(shading_surface_group)

      end
    end

    # Remove eaves overlapping roofceiling
    shading_surfaces_to_remove = []
    model.getShadingSurfaces.each do |shading_surface|
      next unless shading_surface.name.to_s.include? Constants.ObjectNameEaves

      new_shading_vertices = []
      shading_surface.vertices.reverse.each do |vertex|
        new_shading_vertices << OpenStudio::Point3d.new(vertex.x, vertex.y, 0)
      end

      model.getSurfaces.each do |roof_surface|
        next unless roof_surface.surfaceType.downcase == 'roofceiling'
        next unless (roof_surface.outsideBoundaryCondition.downcase == 'outdoors') || (roof_surface.outsideBoundaryCondition.downcase == 'adiabatic')

        roof_surface_vertices = []
        roof_surface.vertices.reverse.each do |vertex|
          roof_surface_vertices << OpenStudio::Point3d.new(vertex.x, vertex.y, 0)
        end

        polygon = OpenStudio::subtract(roof_surface_vertices, [new_shading_vertices], 0.001)[0]
        if (not polygon.nil?) && (OpenStudio::getArea(roof_surface_vertices).get - OpenStudio::getArea(polygon).get > 0.001)
          shading_surfaces_to_remove << shading_surface
        end
      end
    end

    shading_surfaces_to_remove.uniq.each do |shading_surface|
      shading_surface.remove
    end

    unless surfaces_modified
      runner.registerInfo("No surfaces found for adding #{Constants.ObjectNameEaves}.")
      return true
    end

    num_added = shading_surface_group.shadingSurfaces.length

    runner.registerInfo("Added #{num_added} #{Constants.ObjectNameEaves}.")
    return true
  end

  def self.get_existing_eaves_depth(shading_surface)
    existing_eaves_depth = 0
    min_xs = []
    (0..3).to_a.each do |i|
      if (shading_surface.vertices[0].x - shading_surface.vertices[i].x).abs > existing_eaves_depth
        min_xs << (shading_surface.vertices[0].x - shading_surface.vertices[i].x).abs
      end
    end
    unless min_xs.empty?
      return min_xs.min
    end

    return 0
  end

  def self.process_neighbors(model, runner, left_neighbor_offset, right_neighbor_offset, back_neighbor_offset, front_neighbor_offset)
    # Error checking
    if (left_neighbor_offset < 0) || (right_neighbor_offset < 0) || (back_neighbor_offset < 0) || (front_neighbor_offset < 0)
      runner.registerError('Neighbor offsets must be greater than or equal to 0.')
      return false
    end

    surfaces = model.getSurfaces
    if surfaces.size == 0
      runner.registerInfo('No surfaces found to copy for neighboring buildings.')
      return true
    end

    # Remove existing neighbors
    num_removed = 0
    model.getShadingSurfaceGroups.each do |shading_surface_group|
      next unless shading_surface_group.name.to_s == Constants.ObjectNameNeighbors

      shading_surface_group.remove
      num_removed += 1
    end
    if num_removed > 0
      runner.registerInfo("Removed #{num_removed} #{Constants.ObjectNameNeighbors} shading surfaces.")
    end

    # No neighbor shading surfaces to add? Exit here.
    if [left_neighbor_offset, right_neighbor_offset, back_neighbor_offset, front_neighbor_offset].all? { |offset| offset == 0 }
      runner.registerInfo("No #{Constants.ObjectNameNeighbors} shading surfaces to be added.")
      return true
    end

    # Get x, y, z minima and maxima of wall surfaces
    least_x = 9e99
    greatest_x = -9e99
    least_y = 9e99
    greatest_y = -9e99
    greatest_z = -9e99
    surfaces.each do |surface|
      next unless surface.surfaceType.downcase == 'wall'

      space = surface.space.get
      surface.vertices.each do |vertex|
        if vertex.x > greatest_x
          greatest_x = vertex.x
        end
        if vertex.x < least_x
          least_x = vertex.x
        end
        if vertex.y > greatest_y
          greatest_y = vertex.y
        end
        if vertex.y < least_y
          least_y = vertex.y
        end
        if vertex.z + space.zOrigin > greatest_z
          greatest_z = vertex.z + space.zOrigin
        end
      end
    end

    # Neighbors for multifamily buildings
    if get_building_type(model) == Constants.BuildingTypeMultifamily
      num_floors = model.getBuilding.additionalProperties.getFeatureAsInteger('num_floors').get
      level = model.getBuilding.additionalProperties.getFeatureAsString('level').get
      has_rear_units = model.getBuilding.additionalProperties.getFeatureAsBoolean('has_rear_units').get

      model_spaces = model.getSpaces
      spaces = []
      model_spaces.each do |space|
        next unless Geometry.space_is_above_grade(space)

        spaces << space
      end
      unit_height = UnitConversions.convert(Geometry.get_height_of_spaces(spaces), 'ft', 'm')
      floor_mults = { 'Bottom' => num_floors - 1, 'Middle' => (num_floors / 2).floor, 'Top' => 0 }
      greatest_z += unit_height * floor_mults[level]

      unit_length = greatest_y - least_y
      unit_width = greatest_x - least_x
      if has_rear_units
        greatest_y += unit_length
      end

      # FIXME: does not check where the unit is horizontally (for front and back neighbors)
      # greatest_x += unit_width
    end

    directions = [[Constants.FacadeLeft, left_neighbor_offset], [Constants.FacadeRight, right_neighbor_offset], [Constants.FacadeBack, back_neighbor_offset], [Constants.FacadeFront, front_neighbor_offset]]

    shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
    shading_surface_group.setName(Constants.ObjectNameNeighbors)

    num_added = 0
    directions.each do |facade, neighbor_offset|
      next unless neighbor_offset > 0

      vertices = OpenStudio::Point3dVector.new
      m = Geometry.initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      transformation = OpenStudio::Transformation.new(m)

      if facade == Constants.FacadeLeft
        vertices << OpenStudio::Point3d.new(least_x - neighbor_offset, least_y, 0)
        vertices << OpenStudio::Point3d.new(least_x - neighbor_offset, least_y, greatest_z)
        vertices << OpenStudio::Point3d.new(least_x - neighbor_offset, greatest_y, greatest_z)
        vertices << OpenStudio::Point3d.new(least_x - neighbor_offset, greatest_y, 0)
      elsif facade == Constants.FacadeRight
        vertices << OpenStudio::Point3d.new(greatest_x + neighbor_offset, greatest_y, 0)
        vertices << OpenStudio::Point3d.new(greatest_x + neighbor_offset, greatest_y, greatest_z)
        vertices << OpenStudio::Point3d.new(greatest_x + neighbor_offset, least_y, greatest_z)
        vertices << OpenStudio::Point3d.new(greatest_x + neighbor_offset, least_y, 0)
      elsif facade == Constants.FacadeFront
        vertices << OpenStudio::Point3d.new(greatest_x, least_y - neighbor_offset, 0)
        vertices << OpenStudio::Point3d.new(greatest_x, least_y - neighbor_offset, greatest_z)
        vertices << OpenStudio::Point3d.new(least_x, least_y - neighbor_offset, greatest_z)
        vertices << OpenStudio::Point3d.new(least_x, least_y - neighbor_offset, 0)
      elsif facade == Constants.FacadeBack
        vertices << OpenStudio::Point3d.new(least_x, greatest_y + neighbor_offset, 0)
        vertices << OpenStudio::Point3d.new(least_x, greatest_y + neighbor_offset, greatest_z)
        vertices << OpenStudio::Point3d.new(greatest_x, greatest_y + neighbor_offset, greatest_z)
        vertices << OpenStudio::Point3d.new(greatest_x, greatest_y + neighbor_offset, 0)
      end
      vertices = transformation * vertices
      shading_surface = OpenStudio::Model::ShadingSurface.new(vertices, model)
      shading_surface.setName(Constants.ObjectNameNeighbors(facade))
      shading_surface.setShadingSurfaceGroup(shading_surface_group)
      num_added += 1
    end

    runner.registerInfo("Added #{num_added} #{Constants.ObjectNameNeighbors} shading surfaces.")
    return true
  end

  def self.process_orientation(model, runner, orientation)
    if (orientation > 360) || (orientation < 0)
      runner.registerError('Invalid orientation entered.')
      return false
    end

    building = model.getBuilding
    unless building.northAxis == orientation
      runner.registerInfo("The building's initial orientation was #{building.northAxis} azimuth.")
    end
    building.setNorthAxis(orientation) # the shading surfaces representing neighbors have ShadingSurfaceType=Building, and so are oriented along with the building

    runner.registerInfo("The building's final orientation was #{building.northAxis} azimuth.")
    return true
  end
end
