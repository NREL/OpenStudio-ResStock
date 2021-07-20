# frozen_string_literal: true

class Geometry
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

  def self.add_rim_joist(model, polygon, space, rim_joist_height, z)
    if rim_joist_height > 0
      # make polygons
      p = OpenStudio::Point3dVector.new
      polygon.each do |point|
        p << OpenStudio::Point3d.new(point.x, point.y, z)
      end
      rim_joist_polygon = p

      # make space
      rim_joist_space = OpenStudio::Model::Space::fromFloorPrint(rim_joist_polygon, rim_joist_height, model)
      rim_joist_space = rim_joist_space.get

      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != 'roofceiling'

        surface.remove
      end

      rim_joist_space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != 'floor'

        surface.remove
      end

      rim_joist_space.surfaces.each do |surface|
        surface.setSpace(space)
      end

      rim_joist_space.remove
    end
  end

  def self.create_single_family_detached(runner:,
                                         model:,
                                         geometry_cfa:,
                                         geometry_wall_height:,
                                         geometry_num_floors_above_grade:,
                                         geometry_aspect_ratio:,
                                         geometry_garage_width:,
                                         geometry_garage_depth:,
                                         geometry_garage_protrusion:,
                                         geometry_garage_position:,
                                         geometry_foundation_type:,
                                         geometry_foundation_height:,
                                         geometry_rim_joist_height:,
                                         geometry_attic_type:,
                                         geometry_roof_type:,
                                         geometry_roof_pitch:,
                                         **remainder)
    cfa = geometry_cfa
    wall_height = geometry_wall_height
    num_floors = geometry_num_floors_above_grade
    aspect_ratio = geometry_aspect_ratio
    garage_width = geometry_garage_width
    garage_depth = geometry_garage_depth
    garage_protrusion = geometry_garage_protrusion
    garage_position = geometry_garage_position
    foundation_type = geometry_foundation_type
    foundation_height = geometry_foundation_height
    rim_joist_height = geometry_rim_joist_height
    attic_type = geometry_attic_type
    if attic_type == HPXML::AtticTypeConditioned
      num_floors -= 1
    end
    roof_type = geometry_roof_type
    roof_pitch = geometry_roof_pitch

    # error checking
    if model.getSpaces.size > 0
      runner.registerError('Starting model is not empty.')
      return false
    end
    if aspect_ratio < 0
      runner.registerError('Invalid aspect ratio entered.')
      return false
    end
    if (foundation_type == HPXML::FoundationTypeAmbient) && (foundation_height <= 0.0)
      runner.registerError('The ambient foundation height must be greater than 0 ft.')
      return false
    end
    if num_floors > 6
      runner.registerError('Too many floors.')
      return false
    end
    if (garage_protrusion < 0) || (garage_protrusion > 1)
      runner.registerError('Invalid garage protrusion value entered.')
      return false
    end

    # Convert to SI
    cfa = UnitConversions.convert(cfa, 'ft^2', 'm^2')
    wall_height = UnitConversions.convert(wall_height, 'ft', 'm')
    garage_width = UnitConversions.convert(garage_width, 'ft', 'm')
    garage_depth = UnitConversions.convert(garage_depth, 'ft', 'm')
    foundation_height = UnitConversions.convert(foundation_height, 'ft', 'm')
    rim_joist_height = UnitConversions.convert(rim_joist_height, 'ft', 'm')

    garage_area = garage_width * garage_depth
    has_garage = false
    if garage_area > 0
      has_garage = true
    end

    # error checking
    if (garage_protrusion > 0) && (roof_type == 'hip') && has_garage
      runner.registerError('Cannot handle protruding garage and hip roof.')
      return false
    end
    if (garage_protrusion > 0) && (aspect_ratio < 1) && has_garage && (roof_type == 'gable')
      runner.registerError('Cannot handle protruding garage and attic ridge running from front to back.')
      return false
    end
    if (foundation_type == HPXML::FoundationTypeAmbient) && has_garage
      runner.registerError('Cannot handle garages with an ambient foundation type.')
      return false
    end

    # calculate the footprint of the building
    garage_area_inside_footprint = 0
    if has_garage
      garage_area_inside_footprint = garage_area * (1.0 - garage_protrusion)
    end
    bonus_area_above_garage = garage_area * garage_protrusion
    if (foundation_type == HPXML::FoundationTypeBasementConditioned) && (attic_type == HPXML::AtticTypeConditioned)
      footprint = (cfa + 2 * garage_area_inside_footprint - num_floors * bonus_area_above_garage) / (num_floors + 2)
    elsif foundation_type == HPXML::FoundationTypeBasementConditioned
      footprint = (cfa + 2 * garage_area_inside_footprint - (num_floors - 1) * bonus_area_above_garage) / (num_floors + 1)
    elsif attic_type == HPXML::AtticTypeConditioned
      footprint = (cfa + garage_area_inside_footprint - num_floors * bonus_area_above_garage) / (num_floors + 1)
    else
      footprint = (cfa + garage_area_inside_footprint - (num_floors - 1) * bonus_area_above_garage) / num_floors
    end

    # calculate the dimensions of the building
    width = Math.sqrt(footprint / aspect_ratio)
    length = footprint / width

    # error checking
    if ((garage_width > length) && (garage_depth > 0)) || ((((1.0 - garage_protrusion) * garage_depth) > width) && (garage_width > 0)) || ((((1.0 - garage_protrusion) * garage_depth) == width) && (garage_width == length))
      runner.registerError('Invalid living space and garage dimensions.')
      return false
    end

    # create living zone
    living_zone = OpenStudio::Model::ThermalZone.new(model)
    living_zone.setName(HPXML::LocationLivingSpace)

    foundation_offset = 0.0
    if foundation_type == HPXML::FoundationTypeAmbient
      foundation_offset = foundation_height
    end

    # loop through the number of floors
    foundation_polygon_with_wrong_zs = nil
    for floor in (0..num_floors - 1)

      z = wall_height * floor + foundation_offset + rim_joist_height

      if has_garage && (z == foundation_offset + rim_joist_height) # first floor and has garage

        # create garage zone
        garage_space_name = HPXML::LocationGarage
        garage_zone = OpenStudio::Model::ThermalZone.new(model)
        garage_zone.setName(garage_space_name)

        # make points and polygons
        if garage_position == 'Right'
          garage_sw_point = OpenStudio::Point3d.new(length - garage_width, -garage_protrusion * garage_depth, z)
          garage_nw_point = OpenStudio::Point3d.new(length - garage_width, garage_depth - garage_protrusion * garage_depth, z)
          garage_ne_point = OpenStudio::Point3d.new(length, garage_depth - garage_protrusion * garage_depth, z)
          garage_se_point = OpenStudio::Point3d.new(length, -garage_protrusion * garage_depth, z)
          garage_polygon = make_polygon(garage_sw_point, garage_nw_point, garage_ne_point, garage_se_point)
        elsif garage_position == 'Left'
          garage_sw_point = OpenStudio::Point3d.new(0, -garage_protrusion * garage_depth, z)
          garage_nw_point = OpenStudio::Point3d.new(0, garage_depth - garage_protrusion * garage_depth, z)
          garage_ne_point = OpenStudio::Point3d.new(garage_width, garage_depth - garage_protrusion * garage_depth, z)
          garage_se_point = OpenStudio::Point3d.new(garage_width, -garage_protrusion * garage_depth, z)
          garage_polygon = make_polygon(garage_sw_point, garage_nw_point, garage_ne_point, garage_se_point)
        end

        # make space
        garage_space = OpenStudio::Model::Space::fromFloorPrint(garage_polygon, wall_height, model)
        garage_space = garage_space.get
        garage_space.setName(garage_space_name)
        garage_space_type = OpenStudio::Model::SpaceType.new(model)
        garage_space_type.setStandardsSpaceType(garage_space_name)
        garage_space.setSpaceType(garage_space_type)

        # set this to the garage zone
        garage_space.setThermalZone(garage_zone)

        m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
        m[0, 3] = 0
        m[1, 3] = 0
        m[2, 3] = z
        garage_space.changeTransformation(OpenStudio::Transformation.new(m))

        if garage_position == 'Right'
          sw_point = OpenStudio::Point3d.new(0, 0, z)
          nw_point = OpenStudio::Point3d.new(0, width, z)
          ne_point = OpenStudio::Point3d.new(length, width, z)
          se_point = OpenStudio::Point3d.new(length, 0, z)
          l_se_point = OpenStudio::Point3d.new(length - garage_width, 0, z)
          if ((garage_depth < width) || (garage_protrusion > 0)) && (garage_protrusion < 1) # garage protrudes but not fully
            living_polygon = make_polygon(sw_point, nw_point, ne_point, garage_ne_point, garage_nw_point, l_se_point)
          elsif garage_protrusion < 1 # garage fits perfectly within living space
            living_polygon = make_polygon(sw_point, nw_point, garage_nw_point, garage_sw_point)
          else # garage fully protrudes
            living_polygon = make_polygon(sw_point, nw_point, ne_point, se_point)
          end
        elsif garage_position == 'Left'
          sw_point = OpenStudio::Point3d.new(0, 0, z)
          nw_point = OpenStudio::Point3d.new(0, width, z)
          ne_point = OpenStudio::Point3d.new(length, width, z)
          se_point = OpenStudio::Point3d.new(length, 0, z)
          l_sw_point = OpenStudio::Point3d.new(garage_width, 0, z)
          if ((garage_depth < width) || (garage_protrusion > 0)) && (garage_protrusion < 1) # garage protrudes but not fully
            living_polygon = make_polygon(garage_nw_point, nw_point, ne_point, se_point, l_sw_point, garage_ne_point)
          elsif garage_protrusion < 1 # garage fits perfectly within living space
            living_polygon = make_polygon(garage_se_point, garage_ne_point, ne_point, se_point)
          else # garage fully protrudes
            living_polygon = make_polygon(sw_point, nw_point, ne_point, se_point)
          end
        end
        foundation_polygon_with_wrong_zs = living_polygon
      else # first floor without garage or above first floor

        if has_garage
          garage_se_point = OpenStudio::Point3d.new(garage_se_point.x, garage_se_point.y, z)
          garage_sw_point = OpenStudio::Point3d.new(garage_sw_point.x, garage_sw_point.y, z)
          garage_nw_point = OpenStudio::Point3d.new(garage_nw_point.x, garage_nw_point.y, z)
          garage_ne_point = OpenStudio::Point3d.new(garage_ne_point.x, garage_ne_point.y, z)
          if garage_position == 'Right'
            sw_point = OpenStudio::Point3d.new(0, 0, z)
            nw_point = OpenStudio::Point3d.new(0, width, z)
            ne_point = OpenStudio::Point3d.new(length, width, z)
            se_point = OpenStudio::Point3d.new(length, 0, z)
            l_se_point = OpenStudio::Point3d.new(length - garage_width, 0, z)
            if garage_protrusion > 0 # garage protrudes
              living_polygon = make_polygon(sw_point, nw_point, ne_point, garage_se_point, garage_sw_point, l_se_point)
            else # garage does not protrude
              living_polygon = make_polygon(sw_point, nw_point, ne_point, se_point)
            end
          elsif garage_position == 'Left'
            sw_point = OpenStudio::Point3d.new(0, 0, z)
            nw_point = OpenStudio::Point3d.new(0, width, z)
            ne_point = OpenStudio::Point3d.new(length, width, z)
            se_point = OpenStudio::Point3d.new(length, 0, z)
            l_sw_point = OpenStudio::Point3d.new(garage_width, 0, z)
            if garage_protrusion > 0 # garage protrudes
              living_polygon = make_polygon(garage_sw_point, nw_point, ne_point, se_point, l_sw_point, garage_se_point)
            else # garage does not protrude
              living_polygon = make_polygon(sw_point, nw_point, ne_point, se_point)
            end
          end

        else

          sw_point = OpenStudio::Point3d.new(0, 0, z)
          nw_point = OpenStudio::Point3d.new(0, width, z)
          ne_point = OpenStudio::Point3d.new(length, width, z)
          se_point = OpenStudio::Point3d.new(length, 0, z)
          living_polygon = make_polygon(sw_point, nw_point, ne_point, se_point)
          if z == foundation_offset + rim_joist_height
            foundation_polygon_with_wrong_zs = living_polygon
          end

        end

      end

      # make space
      living_space = OpenStudio::Model::Space::fromFloorPrint(living_polygon, wall_height, model)
      living_space = living_space.get
      if floor > 0
        living_space_name = "#{HPXML::LocationLivingSpace}|story #{floor + 1}"
      else
        living_space_name = HPXML::LocationLivingSpace
      end
      living_space.setName(living_space_name)
      living_space_type = OpenStudio::Model::SpaceType.new(model)
      living_space_type.setStandardsSpaceType(HPXML::LocationLivingSpace)
      living_space.setSpaceType(living_space_type)

      # set these to the living zone
      living_space.setThermalZone(living_zone)

      m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      m[0, 3] = 0
      m[1, 3] = 0
      m[2, 3] = z
      living_space.changeTransformation(OpenStudio::Transformation.new(m))
    end

    # Attic
    if roof_type != 'flat'

      z += wall_height

      # calculate the dimensions of the attic
      if length >= width
        attic_height = (width / 2.0) * roof_pitch
      else
        attic_height = (length / 2.0) * roof_pitch
      end

      # make points
      roof_nw_point = OpenStudio::Point3d.new(0, width, z)
      roof_ne_point = OpenStudio::Point3d.new(length, width, z)
      roof_se_point = OpenStudio::Point3d.new(length, 0, z)
      roof_sw_point = OpenStudio::Point3d.new(0, 0, z)

      # make polygons
      polygon_floor = make_polygon(roof_nw_point, roof_ne_point, roof_se_point, roof_sw_point)
      side_type = nil
      if roof_type == 'gable'
        if length >= width
          roof_w_point = OpenStudio::Point3d.new(0, width / 2.0, z + attic_height)
          roof_e_point = OpenStudio::Point3d.new(length, width / 2.0, z + attic_height)
          polygon_s_roof = make_polygon(roof_e_point, roof_w_point, roof_sw_point, roof_se_point)
          polygon_n_roof = make_polygon(roof_w_point, roof_e_point, roof_ne_point, roof_nw_point)
          polygon_w_wall = make_polygon(roof_w_point, roof_nw_point, roof_sw_point)
          polygon_e_wall = make_polygon(roof_e_point, roof_se_point, roof_ne_point)
        else
          roof_w_point = OpenStudio::Point3d.new(length / 2.0, 0, z + attic_height)
          roof_e_point = OpenStudio::Point3d.new(length / 2.0, width, z + attic_height)
          polygon_s_roof = make_polygon(roof_e_point, roof_w_point, roof_se_point, roof_ne_point)
          polygon_n_roof = make_polygon(roof_w_point, roof_e_point, roof_nw_point, roof_sw_point)
          polygon_w_wall = make_polygon(roof_w_point, roof_sw_point, roof_se_point)
          polygon_e_wall = make_polygon(roof_e_point, roof_ne_point, roof_nw_point)
        end
        side_type = 'Wall'
      elsif roof_type == 'hip'
        if length >= width
          roof_w_point = OpenStudio::Point3d.new(width / 2.0, width / 2.0, z + attic_height)
          roof_e_point = OpenStudio::Point3d.new(length - width / 2.0, width / 2.0, z + attic_height)
          polygon_s_roof = make_polygon(roof_e_point, roof_w_point, roof_sw_point, roof_se_point)
          polygon_n_roof = make_polygon(roof_w_point, roof_e_point, roof_ne_point, roof_nw_point)
          polygon_w_wall = make_polygon(roof_w_point, roof_nw_point, roof_sw_point)
          polygon_e_wall = make_polygon(roof_e_point, roof_se_point, roof_ne_point)
        else
          roof_w_point = OpenStudio::Point3d.new(length / 2.0, length / 2.0, z + attic_height)
          roof_e_point = OpenStudio::Point3d.new(length / 2.0, width - length / 2.0, z + attic_height)
          polygon_s_roof = make_polygon(roof_e_point, roof_w_point, roof_se_point, roof_ne_point)
          polygon_n_roof = make_polygon(roof_w_point, roof_e_point, roof_nw_point, roof_sw_point)
          polygon_w_wall = make_polygon(roof_w_point, roof_sw_point, roof_se_point)
          polygon_e_wall = make_polygon(roof_e_point, roof_ne_point, roof_nw_point)
        end
        side_type = 'RoofCeiling'
      end

      # make surfaces
      surface_floor = OpenStudio::Model::Surface.new(polygon_floor, model)
      surface_floor.setSurfaceType('Floor')
      surface_floor.setOutsideBoundaryCondition('Surface')
      surface_s_roof = OpenStudio::Model::Surface.new(polygon_s_roof, model)
      surface_s_roof.setSurfaceType('RoofCeiling')
      surface_s_roof.setOutsideBoundaryCondition('Outdoors')
      surface_n_roof = OpenStudio::Model::Surface.new(polygon_n_roof, model)
      surface_n_roof.setSurfaceType('RoofCeiling')
      surface_n_roof.setOutsideBoundaryCondition('Outdoors')
      surface_w_wall = OpenStudio::Model::Surface.new(polygon_w_wall, model)
      surface_w_wall.setSurfaceType(side_type)
      surface_w_wall.setOutsideBoundaryCondition('Outdoors')
      surface_e_wall = OpenStudio::Model::Surface.new(polygon_e_wall, model)
      surface_e_wall.setSurfaceType(side_type)
      surface_e_wall.setOutsideBoundaryCondition('Outdoors')

      # assign surfaces to the space
      attic_space = OpenStudio::Model::Space.new(model)
      surface_floor.setSpace(attic_space)
      surface_s_roof.setSpace(attic_space)
      surface_n_roof.setSpace(attic_space)
      surface_w_wall.setSpace(attic_space)
      surface_e_wall.setSpace(attic_space)

      # set these to the attic zone
      if (attic_type == HPXML::AtticTypeVented) || (attic_type == HPXML::AtticTypeUnvented)
        # create attic zone
        attic_zone = OpenStudio::Model::ThermalZone.new(model)
        attic_space.setThermalZone(attic_zone)
        if attic_type == HPXML::AtticTypeVented
          attic_space_name = HPXML::LocationAtticVented
        elsif attic_type == HPXML::AtticTypeUnvented
          attic_space_name = HPXML::LocationAtticUnvented
        end
        attic_zone.setName(attic_space_name)
      elsif attic_type == HPXML::AtticTypeConditioned
        attic_space.setThermalZone(living_zone)
        attic_space_name = HPXML::LocationLivingSpace
      end
      attic_space.setName(attic_space_name)
      attic_space_type = OpenStudio::Model::SpaceType.new(model)
      attic_space_type.setStandardsSpaceType(attic_space_name)
      attic_space.setSpaceType(attic_space_type)

      m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      m[0, 3] = 0
      m[1, 3] = 0
      m[2, 3] = z
      attic_space.changeTransformation(OpenStudio::Transformation.new(m))

    end

    # Foundation
    if [HPXML::FoundationTypeCrawlspaceVented, HPXML::FoundationTypeCrawlspaceUnvented, HPXML::FoundationTypeBasementUnconditioned, HPXML::FoundationTypeBasementConditioned, HPXML::FoundationTypeAmbient].include? foundation_type

      z = -foundation_height + foundation_offset

      # create foundation zone
      foundation_zone = OpenStudio::Model::ThermalZone.new(model)

      # make polygons
      p = OpenStudio::Point3dVector.new
      foundation_polygon_with_wrong_zs.each do |point|
        p << OpenStudio::Point3d.new(point.x, point.y, z)
      end
      foundation_polygon = p

      # make space
      foundation_space = OpenStudio::Model::Space::fromFloorPrint(foundation_polygon, foundation_height, model)
      foundation_space = foundation_space.get
      if foundation_type == HPXML::FoundationTypeCrawlspaceVented
        foundation_space_name = HPXML::LocationCrawlspaceVented
      elsif foundation_type == HPXML::FoundationTypeCrawlspaceUnvented
        foundation_space_name = HPXML::LocationCrawlspaceUnvented
      elsif foundation_type == HPXML::FoundationTypeBasementUnconditioned
        foundation_space_name = HPXML::LocationBasementUnconditioned
      elsif foundation_type == HPXML::FoundationTypeBasementConditioned
        foundation_space_name = HPXML::LocationBasementConditioned
      elsif foundation_type == HPXML::FoundationTypeAmbient
        foundation_space_name = HPXML::LocationOutside
      end
      foundation_zone.setName(foundation_space_name)
      foundation_space.setName(foundation_space_name)
      foundation_space_type = OpenStudio::Model::SpaceType.new(model)
      foundation_space_type.setStandardsSpaceType(foundation_space_name)
      foundation_space.setSpaceType(foundation_space_type)

      # set these to the foundation zone
      foundation_space.setThermalZone(foundation_zone)

      # set foundation walls outside boundary condition
      spaces = model.getSpaces
      spaces.each do |space|
        next unless get_space_floor_z(space) + UnitConversions.convert(space.zOrigin, 'm', 'ft') < 0

        surfaces = space.surfaces
        surfaces.each do |surface|
          next if surface.surfaceType.downcase != 'wall'

          surface.setOutsideBoundaryCondition('Ground')
        end
      end

      m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      m[0, 3] = 0
      m[1, 3] = 0
      m[2, 3] = z
      foundation_space.changeTransformation(OpenStudio::Transformation.new(m))

      # Rim Joist
      add_rim_joist(model, foundation_polygon_with_wrong_zs, foundation_space, rim_joist_height, foundation_height)
    end

    # put all of the spaces in the model into a vector
    spaces = OpenStudio::Model::SpaceVector.new
    model.getSpaces.each do |space|
      spaces << space
    end

    # intersect and match surfaces for each space in the vector
    OpenStudio::Model.intersectSurfaces(spaces)
    OpenStudio::Model.matchSurfaces(spaces)

    if has_garage && (roof_type != 'flat')
      if num_floors > 1
        space_with_roof_over_garage = living_space
      else
        space_with_roof_over_garage = garage_space
      end
      space_with_roof_over_garage.surfaces.each do |surface|
        next unless (surface.surfaceType.downcase == 'roofceiling') && (surface.outsideBoundaryCondition.downcase == 'outdoors')

        n_points = []
        s_points = []
        surface.vertices.each do |vertex|
          if vertex.y.abs < 0.00001
            n_points << vertex
          elsif vertex.y < 0
            s_points << vertex
          end
        end
        if n_points[0].x > n_points[1].x
          nw_point = n_points[1]
          ne_point = n_points[0]
        else
          nw_point = n_points[0]
          ne_point = n_points[1]
        end
        if s_points[0].x > s_points[1].x
          sw_point = s_points[1]
          se_point = s_points[0]
        else
          sw_point = s_points[0]
          se_point = s_points[1]
        end

        if num_floors == 1
          if not attic_type == HPXML::AtticTypeConditioned
            nw_point = OpenStudio::Point3d.new(nw_point.x, nw_point.y, living_space.zOrigin + nw_point.z)
            ne_point = OpenStudio::Point3d.new(ne_point.x, ne_point.y, living_space.zOrigin + ne_point.z)
            sw_point = OpenStudio::Point3d.new(sw_point.x, sw_point.y, living_space.zOrigin + sw_point.z)
            se_point = OpenStudio::Point3d.new(se_point.x, se_point.y, living_space.zOrigin + se_point.z)
          else
            nw_point = OpenStudio::Point3d.new(nw_point.x, nw_point.y, nw_point.z - living_space.zOrigin)
            ne_point = OpenStudio::Point3d.new(ne_point.x, ne_point.y, ne_point.z - living_space.zOrigin)
            sw_point = OpenStudio::Point3d.new(sw_point.x, sw_point.y, sw_point.z - living_space.zOrigin)
            se_point = OpenStudio::Point3d.new(se_point.x, se_point.y, se_point.z - living_space.zOrigin)
          end
        else
          nw_point = OpenStudio::Point3d.new(nw_point.x, nw_point.y, num_floors * nw_point.z + rim_joist_height)
          ne_point = OpenStudio::Point3d.new(ne_point.x, ne_point.y, num_floors * ne_point.z + rim_joist_height)
          sw_point = OpenStudio::Point3d.new(sw_point.x, sw_point.y, num_floors * sw_point.z + rim_joist_height)
          se_point = OpenStudio::Point3d.new(se_point.x, se_point.y, num_floors * se_point.z + rim_joist_height)
        end

        garage_attic_height = (ne_point.x - nw_point.x) / 2 * roof_pitch

        garage_roof_pitch = roof_pitch
        if garage_attic_height >= attic_height
          garage_attic_height = attic_height - 0.01 # garage attic height slightly below attic height so that we don't get any roof decks with only three vertices
          garage_roof_pitch = garage_attic_height / (garage_width / 2)
          runner.registerWarning("The garage pitch was changed to accommodate garage ridge >= house ridge (from #{roof_pitch.round(3)} to #{garage_roof_pitch.round(3)}).")
        end

        if num_floors == 1
          if not attic_type == HPXML::AtticTypeConditioned
            roof_n_point = OpenStudio::Point3d.new((nw_point.x + ne_point.x) / 2, nw_point.y + garage_attic_height / roof_pitch, living_space.zOrigin + wall_height + garage_attic_height)
            roof_s_point = OpenStudio::Point3d.new((sw_point.x + se_point.x) / 2, sw_point.y, living_space.zOrigin + wall_height + garage_attic_height)
          else
            roof_n_point = OpenStudio::Point3d.new((nw_point.x + ne_point.x) / 2, nw_point.y + garage_attic_height / roof_pitch, garage_attic_height + wall_height)
            roof_s_point = OpenStudio::Point3d.new((sw_point.x + se_point.x) / 2, sw_point.y, garage_attic_height + wall_height)
          end
        else
          roof_n_point = OpenStudio::Point3d.new((nw_point.x + ne_point.x) / 2, nw_point.y + garage_attic_height / roof_pitch, num_floors * wall_height + garage_attic_height + rim_joist_height)
          roof_s_point = OpenStudio::Point3d.new((sw_point.x + se_point.x) / 2, sw_point.y, num_floors * wall_height + garage_attic_height + rim_joist_height)
        end

        polygon_w_roof = make_polygon(nw_point, sw_point, roof_s_point, roof_n_point)
        polygon_e_roof = make_polygon(ne_point, roof_n_point, roof_s_point, se_point)
        polygon_n_wall = make_polygon(nw_point, roof_n_point, ne_point)
        polygon_s_wall = make_polygon(sw_point, se_point, roof_s_point)

        deck_w = OpenStudio::Model::Surface.new(polygon_w_roof, model)
        deck_w.setSurfaceType('RoofCeiling')
        deck_w.setOutsideBoundaryCondition('Outdoors')
        deck_e = OpenStudio::Model::Surface.new(polygon_e_roof, model)
        deck_e.setSurfaceType('RoofCeiling')
        deck_e.setOutsideBoundaryCondition('Outdoors')
        wall_n = OpenStudio::Model::Surface.new(polygon_n_wall, model)
        wall_n.setSurfaceType('Wall')
        wall_s = OpenStudio::Model::Surface.new(polygon_s_wall, model)
        wall_s.setSurfaceType('Wall')
        wall_s.setOutsideBoundaryCondition('Outdoors')

        garage_attic_space = OpenStudio::Model::Space.new(model)
        deck_w.setSpace(garage_attic_space)
        deck_e.setSpace(garage_attic_space)
        wall_n.setSpace(garage_attic_space)
        wall_s.setSpace(garage_attic_space)

        if attic_type == HPXML::AtticTypeConditioned
          garage_attic_space_name = attic_space_name
          garage_attic_space.setThermalZone(living_zone)
        else
          if num_floors > 1
            garage_attic_space_name = attic_space_name
            garage_attic_space.setThermalZone(attic_zone)
          else
            garage_attic_space_name = garage_space_name
            garage_attic_space.setThermalZone(garage_zone)
          end
        end

        surface.createAdjacentSurface(garage_attic_space) # garage attic floor
        garage_attic_space.setName(garage_attic_space_name)
        garage_attic_space_type = OpenStudio::Model::SpaceType.new(model)
        garage_attic_space_type.setStandardsSpaceType(garage_attic_space_name)
        garage_attic_space.setSpaceType(garage_attic_space_type)

        # put all of the spaces in the model into a vector
        spaces = OpenStudio::Model::SpaceVector.new
        model.getSpaces.each do |space|
          spaces << space
        end

        # intersect and match surfaces for each space in the vector
        OpenStudio::Model.intersectSurfaces(spaces)
        OpenStudio::Model.matchSurfaces(spaces)

        # remove triangular surface between unconditioned attic and garage attic
        unless attic_space.nil?
          attic_space.surfaces.each do |surface|
            next if roof_type == 'hip'
            next unless surface.vertices.length == 3
            next unless (90 - surface.tilt * 180 / Math::PI).abs > 0.01 # don't remove the vertical attic walls
            next unless surface.adjacentSurface.is_initialized

            surface.adjacentSurface.get.remove
            surface.remove
          end
        end

        garage_attic_space.surfaces.each do |surface|
          m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
          m[2, 3] = -attic_space.zOrigin
          transformation = OpenStudio::Transformation.new(m)
          new_vertices = transformation * surface.vertices
          surface.setVertices(new_vertices)
          surface.setSpace(attic_space)
        end

        garage_attic_space.remove

        # remove other unused surfaces
        # TODO: remove this once geometry methods are fixed in openstudio 3.x
        attic_space.surfaces.each do |surface1|
          next if surface1.surfaceType != 'RoofCeiling'

          attic_space.surfaces.each do |surface2|
            next if surface2.surfaceType != 'RoofCeiling'
            next if surface1 == surface2

            if has_same_vertices(surface1, surface2)
              surface1.remove
              surface2.remove
            end
          end
        end

        break
      end
    end

    garage_spaces = get_garage_spaces(model.getSpaces)

    # set foundation outside boundary condition to Kiva "foundation"
    model.getSurfaces.each do |surface|
      if surface.outsideBoundaryCondition.downcase == 'ground'
        surface.setOutsideBoundaryCondition('Foundation')
      elsif (UnitConversions.convert(rim_joist_height, 'm', 'ft') - get_surface_height(surface)).abs < 0.001
        next if surface.surfaceType.downcase != 'wall'

        garage_spaces.each do |garage_space|
          garage_space.surfaces.each do |garage_surface|
            next if garage_surface.surfaceType.downcase != 'floor'

            if get_walls_connected_to_floor([surface], garage_surface, false).include? surface
              surface.setOutsideBoundaryCondition('Foundation')
            end
          end
        end
      end
    end

    # set foundation walls adjacent to garage to adiabatic
    foundation_walls = []
    model.getSurfaces.each do |surface|
      next if surface.surfaceType.downcase != 'wall'
      next if surface.outsideBoundaryCondition.downcase != 'foundation'

      foundation_walls << surface
    end

    garage_spaces.each do |garage_space|
      garage_space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != 'floor'

        adjacent_wall_surfaces = get_walls_connected_to_floor(foundation_walls, surface, false)
        adjacent_wall_surfaces.each do |adjacent_wall_surface|
          adjacent_wall_surface.setOutsideBoundaryCondition('Adiabatic')
        end
      end
    end

    return true
  end

  def self.has_same_vertices(surface1, surface2)
    if getSurfaceXValues([surface1]) == getSurfaceXValues([surface2]) &&
       getSurfaceYValues([surface1]) == getSurfaceYValues([surface2]) &&
       getSurfaceZValues([surface1]) == getSurfaceZValues([surface2])
      return true
    end

    return false
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

  def self.initialize_transformation_matrix(m)
    m[0, 0] = 1
    m[1, 1] = 1
    m[2, 2] = 1
    m[3, 3] = 1
    return m
  end

  def self.get_garage_spaces(spaces)
    garage_spaces = []
    spaces.each do |space|
      next if not is_garage(space)

      garage_spaces << space
    end
    return garage_spaces
  end

  def self.get_space_floor_z(space)
    space.surfaces.each do |surface|
      next unless surface.surfaceType.downcase == 'floor'

      return getSurfaceZValues([surface])[0]
    end
  end

  def self.create_windows_and_skylights(runner:,
                                        model:,
                                        window_front_wwr:,
                                        window_back_wwr:,
                                        window_left_wwr:,
                                        window_right_wwr:,
                                        window_area_front:,
                                        window_area_back:,
                                        window_area_left:,
                                        window_area_right:,
                                        window_aspect_ratio:,
                                        skylight_area_front:,
                                        skylight_area_back:,
                                        skylight_area_left:,
                                        skylight_area_right:,
                                        **remainder)
    facades = [Constants.FacadeFront, Constants.FacadeBack, Constants.FacadeLeft, Constants.FacadeRight]

    wwrs = {}
    wwrs[Constants.FacadeFront] = window_front_wwr
    wwrs[Constants.FacadeBack] = window_back_wwr
    wwrs[Constants.FacadeLeft] = window_left_wwr
    wwrs[Constants.FacadeRight] = window_right_wwr
    window_areas = {}
    window_areas[Constants.FacadeFront] = window_area_front
    window_areas[Constants.FacadeBack] = window_area_back
    window_areas[Constants.FacadeLeft] = window_area_left
    window_areas[Constants.FacadeRight] = window_area_right
    # width_extension = UnitConversions.convert(runner.getDoubleArgumentValue("width_extension",user_arguments), "ft", "m")
    skylight_areas = {}
    skylight_areas[Constants.FacadeFront] = skylight_area_front
    skylight_areas[Constants.FacadeBack] = skylight_area_back
    skylight_areas[Constants.FacadeLeft] = skylight_area_left
    skylight_areas[Constants.FacadeRight] = skylight_area_right
    skylight_areas['none'] = 0

    # Remove existing windows and store surfaces that should get windows by facade
    wall_surfaces = { Constants.FacadeFront => [], Constants.FacadeBack => [],
                      Constants.FacadeLeft => [], Constants.FacadeRight => [] }
    roof_surfaces = { Constants.FacadeFront => [], Constants.FacadeBack => [],
                      Constants.FacadeLeft => [], Constants.FacadeRight => [],
                      'none' => [] }
    # flat_roof_surfaces = []
    constructions = {}
    window_warn_msg = nil
    skylight_warn_msg = nil
    get_conditioned_spaces(model.getSpaces).each do |space|
      space.surfaces.each do |surface|
        if (surface.surfaceType.downcase == 'wall') && (surface.outsideBoundaryCondition.downcase == 'outdoors')
          next if (90 - surface.tilt * 180 / Math::PI).abs > 0.01 # Not a vertical wall

          win_removed = false
          construction = nil
          surface.subSurfaces.each do |sub_surface|
            next if sub_surface.subSurfaceType.downcase != 'fixedwindow'

            if sub_surface.construction.is_initialized
              if (not construction.nil?) && (construction != sub_surface.construction.get)
                window_warn_msg = 'Multiple constructions found. An arbitrary construction may be assigned to new window(s).'
              end
              construction = sub_surface.construction.get
            end
            sub_surface.remove
            win_removed = true
          end
          if win_removed
            runner.registerInfo("Removed fixed window(s) from #{surface.name}.")
          end
          facade = get_facade_for_surface(surface)
          next if facade.nil?

          wall_surfaces[facade] << surface
          if (not construction.nil?) && (not constructions.keys.include? facade)
            constructions[facade] = construction
          end
        elsif (surface.surfaceType.downcase == 'roofceiling') && (surface.outsideBoundaryCondition.downcase == 'outdoors')
          sky_removed = false
          construction = nil
          surface.subSurfaces.each do |sub_surface|
            next if sub_surface.subSurfaceType.downcase != 'skylight'

            if sub_surface.construction.is_initialized
              if (not construction.nil?) && (construction != sub_surface.construction.get)
                skylight_warn_msg = 'Multiple constructions found. An arbitrary construction may be assigned to new skylight(s).'
              end
              construction = sub_surface.construction.get
            end
            sub_surface.remove
            sky_removed = true
          end
          if sky_removed
            runner.registerInfo("Removed fixed skylight(s) from #{surface.name}.")
          end
          facade = get_facade_for_surface(surface)
          if facade.nil?
            if surface.tilt == 0 # flat roof
              roof_surfaces['none'] << surface
            end
            next
          end
          roof_surfaces[facade] << surface
          if (not construction.nil?) && (not constructions.keys.include? facade)
            constructions[facade] = construction
          end
        end
      end
    end
    if not window_warn_msg.nil?
      runner.registerWarning(window_warn_msg)
    end
    if not skylight_warn_msg.nil?
      runner.registerWarning(skylight_warn_msg)
    end

    # error checking
    facades.each do |facade|
      if (wwrs[facade] > 0) && (window_areas[facade] > 0)
        runner.registerError("Both #{facade} window-to-wall ratio and #{facade} window area are specified.")
        return false
      elsif (wwrs[facade] < 0) || (wwrs[facade] >= 1)
        runner.registerError("#{facade.capitalize} window-to-wall ratio must be greater than or equal to 0 and less than 1.")
        return false
      elsif window_areas[facade] < 0
        runner.registerError("#{facade.capitalize} window area must be greater than or equal to 0.")
        return false
      elsif skylight_areas[facade] < 0
        runner.registerError("#{facade.capitalize} skylight area must be greater than or equal to 0.")
        return false
      end
    end
    if window_aspect_ratio <= 0
      runner.registerError('Window Aspect Ratio must be greater than 0.')
      return false
    end

    # Split any surfaces that have doors so that we can ignore them when adding windows
    facades.each do |facade|
      wall_surfaces[facade].each do |surface|
        next if surface.subSurfaces.size == 0

        new_surfaces = surface.splitSurfaceForSubSurfaces
        new_surfaces.each do |new_surface|
          wall_surfaces[facade] << new_surface
        end
      end
    end

    # Windows

    # Default assumptions
    min_single_window_area = 5.333 # sqft
    max_single_window_area = 12.0 # sqft
    window_gap_y = 1.0 # ft; distance from top of wall
    window_gap_x = 0.2 # ft; distance between windows in a two-window group
    min_wall_height_for_window = Math.sqrt(max_single_window_area * window_aspect_ratio) + window_gap_y * 1.05 # allow some wall area above/below
    min_window_width = Math.sqrt(min_single_window_area / window_aspect_ratio) * 1.05 # allow some wall area to the left/right

    # Calculate available area for each wall, facade
    surface_avail_area = {}
    facade_avail_area = {}
    facades.each do |facade|
      facade_avail_area[facade] = 0
      wall_surfaces[facade].each do |surface|
        if not surface_avail_area.include? surface
          surface_avail_area[surface] = 0
        end

        area = get_wall_area_for_windows(surface, min_wall_height_for_window, min_window_width, runner)
        surface_avail_area[surface] += area
        facade_avail_area[facade] += area
      end
    end

    # Initialize
    surface_window_area = {}
    target_facade_areas = {}
    facades.each do |facade|
      target_facade_areas[facade] = 0.0
      wall_surfaces[facade].each do |surface|
        surface_window_area[surface] = 0
      end
    end

    facades.each do |facade|
      # Calculate target window area for this facade
      if wwrs[facade] > 0
        wall_area = 0
        wall_surfaces[facade].each do |surface|
          wall_area += UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2')
        end
        target_facade_areas[facade] += wall_area * wwrs[facade]
      else
        target_facade_areas[facade] += window_areas[facade]
      end
    end

    facades.each do |facade|
      # Initial guess for wall of this facade
      next if facade_avail_area[facade] == 0

      wall_surfaces[facade].each do |surface|
        surface_window_area[surface] += surface_avail_area[surface] / facade_avail_area[facade] * target_facade_areas[facade]
      end

      # If window area for a surface is less than the minimum window area,
      # set the window area to zero and proportionally redistribute to the
      # other surfaces on that facade and unit.

      # Check wall surface areas (by unit/space)
      model.getBuildingUnits.each do |unit|
        wall_surfaces[facade].each_with_index do |surface, surface_num|
          next if surface_window_area[surface] == 0
          next unless unit.spaces.include? surface.space.get # surface belongs to this unit
          next unless surface_window_area[surface] < min_single_window_area

          # Future surfaces are those that have not yet been compared to min_single_window_area
          future_surfaces_area = 0
          wall_surfaces[facade].each_with_index do |future_surface, future_surface_num|
            next if future_surface_num <= surface_num
            next unless unit.spaces.include? future_surface.space.get

            future_surfaces_area += surface_avail_area[future_surface]
          end
          next if future_surfaces_area == 0

          removed_window_area = surface_window_area[surface]
          surface_window_area[surface] = 0

          wall_surfaces[facade].each_with_index do |future_surface, future_surface_num|
            next if future_surface_num <= surface_num
            next unless unit.spaces.include? future_surface.space.get

            surface_window_area[future_surface] += removed_window_area * surface_avail_area[future_surface] / future_surfaces_area
          end
        end
      end
    end

    # Calculate facade areas for each unit
    unit_facade_areas = {}
    unit_wall_surfaces = {}
    model.getBuildingUnits.each do |unit|
      unit_facade_areas[unit] = {}
      unit_wall_surfaces[unit] = {}
      facades.each do |facade|
        unit_facade_areas[unit][facade] = 0
        unit_wall_surfaces[unit][facade] = []
        wall_surfaces[facade].each do |surface|
          next unless unit.spaces.include? surface.space.get

          unit_facade_areas[unit][facade] += surface_window_area[surface]
          unit_wall_surfaces[unit][facade] << surface
        end
      end
    end

    # if the sum of the window areas on the facade are < minimum, move to different facade
    facades.each do |facade|
      model.getBuildingUnits.each do |unit|
        next if unit_facade_areas[unit][facade] == 0
        next unless unit_facade_areas[unit][facade] < min_single_window_area

        new_facade = unit_facade_areas[unit].max_by { |k, v| v }[0] # move to facade with largest window area
        next if new_facade == facade # can't move to same facade
        next if unit_facade_areas[unit][new_facade] <= unit_facade_areas[unit][facade] # only move to facade with >= window area

        area_moved = unit_facade_areas[unit][facade]
        unit_facade_areas[unit][facade] = 0
        wall_surfaces[facade].each do |surface|
          next unless unit.spaces.include? surface.space.get # surface is in this unit

          surface_window_area[surface] = 0
        end

        unit_facade_areas[unit][new_facade] += area_moved
        sum_window_area = 0
        wall_surfaces[new_facade].each do |surface|
          next unless unit.spaces.include? surface.space.get # surface is in this unit

          sum_window_area += UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2')
        end

        wall_surfaces[new_facade].each do |surface|
          next unless unit.spaces.include? surface.space.get # surface is in this unit

          split_window_area = area_moved * UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2') / sum_window_area
          surface_window_area[surface] += split_window_area
        end

        runner.registerWarning("The #{facade} facade window area (#{area_moved.round(2)} ft2) is less than the minimum window area allowed (#{min_single_window_area.round(2)} ft2), and has been added to the #{new_facade} facade.")
      end
    end

    facades.each do |facade|
      model.getBuildingUnits.each do |unit|
        # Because the above process is calculated based on the order of surfaces, it's possible
        # that we have less area for this facade than we should. If so, redistribute proportionally
        # to all surfaces that have window area.
        sum_window_area = 0
        wall_surfaces[facade].each do |surface|
          next unless unit.spaces.include? surface.space.get

          sum_window_area += surface_window_area[surface]
        end
        next if sum_window_area == 0
        next if unit_facade_areas[unit][facade] < sum_window_area # for cases where window area was added from different facade

        wall_surfaces[facade].each do |surface|
          next unless unit.spaces.include? surface.space.get

          surface_window_area[surface] += surface_window_area[surface] / sum_window_area * (unit_facade_areas[unit][facade] - sum_window_area)
        end
      end
    end

    tot_win_area = 0
    facades.each do |facade|
      facade_win_area = 0
      wall_surfaces[facade].each do |surface|
        next if surface_window_area[surface] == 0
        if not add_windows_to_wall(surface, surface_window_area[surface], window_gap_y, window_gap_x, window_aspect_ratio, max_single_window_area, facade, constructions, model, runner)
          return false
        end

        tot_win_area += surface_window_area[surface]
        facade_win_area += surface_window_area[surface]
      end
      if (facade_win_area - target_facade_areas[facade]).abs > 0.1
        runner.registerWarning("Unable to assign appropriate window area for #{facade} facade.")
      end
    end

    # Skylights
    unless roof_surfaces['none'].empty?
      tot_sky_area = 0
      skylight_areas.each do |facade, skylight_area|
        next if facade == 'none'

        skylight_area /= roof_surfaces['none'].length
        skylight_areas['none'] += skylight_area
        skylight_areas[facade] = 0
      end
    end

    tot_sky_area = 0
    skylight_areas.each do |facade, skylight_area|
      next if skylight_area == 0

      surfaces = roof_surfaces[facade]

      if surfaces.empty? && (not facade == 'none')
        runner.registerError("There are no #{facade} roof surfaces, but #{skylight_area} ft^2 of skylights were specified.")
        return false
      end

      surfaces.each do |surface|
        if (UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2') / get_surface_length(surface)) > get_surface_length(surface)
          skylight_aspect_ratio = get_surface_length(surface) / (UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2') / get_surface_length(surface)) # aspect ratio of the roof surface
        else
          skylight_aspect_ratio = (UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2') / get_surface_length(surface)) / get_surface_length(surface) # aspect ratio of the roof surface
        end

        skylight_width = Math.sqrt(UnitConversions.convert(skylight_area, 'ft^2', 'm^2') / skylight_aspect_ratio)
        skylight_length = UnitConversions.convert(skylight_area, 'ft^2', 'm^2') / skylight_width

        skylight_bottom_left = OpenStudio::getCentroid(surface.vertices).get
        leftx = skylight_bottom_left.x
        lefty = skylight_bottom_left.y
        bottomz = skylight_bottom_left.z
        if (facade == Constants.FacadeFront) || (facade == 'none')
          skylight_top_left = OpenStudio::Point3d.new(leftx, lefty + Math.cos(surface.tilt) * skylight_length, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_top_right = OpenStudio::Point3d.new(leftx + skylight_width, lefty + Math.cos(surface.tilt) * skylight_length, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_bottom_right = OpenStudio::Point3d.new(leftx + skylight_width, lefty, bottomz)
        elsif facade == Constants.FacadeBack
          skylight_top_left = OpenStudio::Point3d.new(leftx, lefty - Math.cos(surface.tilt) * skylight_length, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_top_right = OpenStudio::Point3d.new(leftx - skylight_width, lefty - Math.cos(surface.tilt) * skylight_length, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_bottom_right = OpenStudio::Point3d.new(leftx - skylight_width, lefty, bottomz)
        elsif facade == Constants.FacadeLeft
          skylight_top_left = OpenStudio::Point3d.new(leftx + Math.cos(surface.tilt) * skylight_length, lefty, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_top_right = OpenStudio::Point3d.new(leftx + Math.cos(surface.tilt) * skylight_length, lefty - skylight_width, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_bottom_right = OpenStudio::Point3d.new(leftx, lefty - skylight_width, bottomz)
        elsif facade == Constants.FacadeRight
          skylight_top_left = OpenStudio::Point3d.new(leftx - Math.cos(surface.tilt) * skylight_length, lefty, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_top_right = OpenStudio::Point3d.new(leftx - Math.cos(surface.tilt) * skylight_length, lefty + skylight_width, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_bottom_right = OpenStudio::Point3d.new(leftx, lefty + skylight_width, bottomz)
        end

        skylight_polygon = OpenStudio::Point3dVector.new
        [skylight_bottom_left, skylight_bottom_right, skylight_top_right, skylight_top_left].each do |skylight_vertex|
          skylight_polygon << skylight_vertex
        end

        sub_surface = OpenStudio::Model::SubSurface.new(skylight_polygon, model)
        sub_surface.setName("#{surface.name} - Skylight")
        sub_surface.setSurface(surface)

        if not constructions[facade].nil?
          sub_surface.setConstruction(constructions[facade])
        end

        tot_sky_area += skylight_area
      end
    end

    if (tot_win_area == 0) && (tot_sky_area == 0)
      runner.registerFinalCondition('No windows or skylights added.')
    end

    return true
  end

  def self.get_wall_area_for_windows(surface, min_wall_height_for_window, min_window_width, runner)
    # Skip surfaces with doors
    if surface.subSurfaces.size > 0
      return 0.0
    end

    # Only allow on gable and rectangular walls
    if not (is_rectangular_wall(surface) || is_gable_wall(surface))
      return 0.0
    end

    # Can't fit the smallest window?
    if get_surface_length(surface) < min_window_width
      return 0.0
    end

    # Wall too short?
    if min_wall_height_for_window > get_surface_height(surface)
      return 0.0
    end

    # Gable too short?
    # TODO: super crude safety factor of 1.5
    if is_gable_wall(surface) && (min_wall_height_for_window > get_surface_height(surface) / 1.5)
      return 0.0
    end

    return UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2')
  end

  def self.add_windows_to_wall(surface, window_area, window_gap_y, window_gap_x, window_aspect_ratio, max_single_window_area, facade, constructions, model, runner)
    wall_width = get_surface_length(surface)
    wall_height = get_surface_height(surface)

    # Calculate number of windows needed
    num_windows = (window_area / max_single_window_area).ceil
    num_window_groups = (num_windows / 2.0).ceil
    num_window_gaps = num_window_groups
    if num_windows % 2 == 1
      num_window_gaps -= 1
    end
    window_width = Math.sqrt((window_area / num_windows.to_f) / window_aspect_ratio)
    window_height = (window_area / num_windows.to_f) / window_width
    width_for_windows = window_width * num_windows.to_f + window_gap_x * num_window_gaps.to_f
    if width_for_windows > wall_width
      runner.registerError("Could not fit windows on #{surface.name}.")
      return false
    end

    # Position window from top of surface
    win_top = wall_height - window_gap_y
    if is_gable_wall(surface)
      # For gable surfaces, position windows from bottom of surface so they fit
      win_top = window_height + window_gap_y
    end

    # Groups of two windows
    win_num = 0
    for i in (1..num_window_groups)

      # Center vertex for group
      group_cx = wall_width * i / (num_window_groups + 1).to_f
      group_cy = win_top - window_height / 2.0

      if not ((i == num_window_groups) && (num_windows % 2 == 1))
        # Two windows in group
        win_num += 1
        add_window_to_wall(surface, window_width, window_height, group_cx - window_width / 2.0 - window_gap_x / 2.0, group_cy, win_num, facade, constructions, model, runner)
        win_num += 1
        add_window_to_wall(surface, window_width, window_height, group_cx + window_width / 2.0 + window_gap_x / 2.0, group_cy, win_num, facade, constructions, model, runner)
      else
        # One window in group
        win_num += 1
        add_window_to_wall(surface, window_width, window_height, group_cx, group_cy, win_num, facade, constructions, model, runner)
      end
    end

    return true
  end

  def self.add_window_to_wall(surface, win_width, win_height, win_center_x, win_center_y, win_num, facade, constructions, model, runner)
    # Create window vertices in relative coordinates, ft
    upperleft = [win_center_x - win_width / 2.0, win_center_y + win_height / 2.0]
    upperright = [win_center_x + win_width / 2.0, win_center_y + win_height / 2.0]
    lowerright = [win_center_x + win_width / 2.0, win_center_y - win_height / 2.0]
    lowerleft = [win_center_x - win_width / 2.0, win_center_y - win_height / 2.0]

    # Convert to 3D geometry; assign to surface
    window_polygon = OpenStudio::Point3dVector.new
    if facade == Constants.FacadeFront
      multx = 1
      multy = 0
    elsif facade == Constants.FacadeBack
      multx = -1
      multy = 0
    elsif facade == Constants.FacadeLeft
      multx = 0
      multy = -1
    elsif facade == Constants.FacadeRight
      multx = 0
      multy = 1
    end
    if (facade == Constants.FacadeBack) || (facade == Constants.FacadeLeft)
      leftx = getSurfaceXValues([surface]).max
      lefty = getSurfaceYValues([surface]).max
    else
      leftx = getSurfaceXValues([surface]).min
      lefty = getSurfaceYValues([surface]).min
    end
    bottomz = getSurfaceZValues([surface]).min
    [upperleft, lowerleft, lowerright, upperright].each do |coord|
      newx = UnitConversions.convert(leftx + multx * coord[0], 'ft', 'm')
      newy = UnitConversions.convert(lefty + multy * coord[0], 'ft', 'm')
      newz = UnitConversions.convert(bottomz + coord[1], 'ft', 'm')
      window_vertex = OpenStudio::Point3d.new(newx, newy, newz)
      window_polygon << window_vertex
    end
    sub_surface = OpenStudio::Model::SubSurface.new(window_polygon, model)
    sub_surface.setName("#{surface.name} - Window #{win_num}")
    sub_surface.setSurface(surface)
    sub_surface.setSubSurfaceType('FixedWindow')
    if not constructions[facade].nil?
      sub_surface.setConstruction(constructions[facade])
    end
  end

  def self.get_conditioned_spaces(spaces)
    conditioned_spaces = []
    spaces.each do |space|
      next if space_is_unconditioned(space)

      conditioned_spaces << space
    end
    return conditioned_spaces
  end

  def self.space_is_unconditioned(space)
    return !space_is_conditioned(space)
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

  def self.create_doors(runner:,
                        model:,
                        door_area:,
                        **remainder)
    construction = nil
    warn_msg = nil
    model.getSubSurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType.downcase != 'door'

      if sub_surface.construction.is_initialized
        if not construction.nil?
          warn_msg = 'Multiple constructions found. An arbitrary construction may be assigned to new door(s).'
        end
        construction = sub_surface.construction.get
      end
      runner.registerInfo("Removed door(s) from #{sub_surface.surface.get.name}.")
      sub_surface.remove
    end
    if not warn_msg.nil?
      runner.registerWarning(warn_msg)
    end

    # error checking
    if door_area < 0
      runner.registerError('Invalid door area.')
      return false
    elsif door_area == 0
      runner.registerFinalCondition('No doors added because door area was set to 0.')
      return true
    end

    door_height = 7 # ft
    door_width = door_area / door_height
    door_offset = 0.5 # ft

    # Get all exterior walls prioritized by front, then back, then left, then right
    facades = [Constants.FacadeFront, Constants.FacadeBack]
    avail_walls = []
    facades.each do |facade|
      get_conditioned_spaces(model.getSpaces).each do |space|
        next if space_is_below_grade(space)

        space.surfaces.each do |surface|
          next if get_facade_for_surface(surface) != facade
          next if surface.outsideBoundaryCondition.downcase != 'outdoors'
          next if (90 - surface.tilt * 180 / Math::PI).abs > 0.01 # Not a vertical wall

          avail_walls << surface
        end
      end
      break if avail_walls.size > 0
    end

    # Get subset of exterior walls on lowest story
    min_story_avail_walls = []
    min_story_avail_wall_minz = 99999
    avail_walls.each do |avail_wall|
      zvalues = getSurfaceZValues([avail_wall])
      minz = zvalues.min + avail_wall.space.get.zOrigin
      if minz < min_story_avail_wall_minz
        min_story_avail_walls.clear
        min_story_avail_walls << avail_wall
        min_story_avail_wall_minz = minz
      elsif (minz - min_story_avail_wall_minz).abs < 0.001
        min_story_avail_walls << avail_wall
      end
    end

    # Get all corridor walls
    corridor_walls = []
    get_conditioned_spaces(model.getSpaces).each do |space|
      space.surfaces.each do |surface|
        next unless surface.surfaceType.downcase == 'wall'
        next unless surface.outsideBoundaryCondition.downcase == 'adiabatic'

        model.getSpaces.each do |potential_corridor_space|
          next unless potential_corridor_space.spaceType.get.standardsSpaceType.get == HPXML::LocationOtherHousingUnit

          potential_corridor_space.surfaces.each do |potential_corridor_surface|
            next unless surface.reverseEqualVertices(potential_corridor_surface)

            corridor_walls << potential_corridor_surface
          end
        end
      end
    end

    # Get subset of corridor walls on lowest story
    min_story_corridor_walls = []
    min_story_corridor_wall_minz = 99999
    corridor_walls.each do |corridor_wall|
      zvalues = getSurfaceZValues([corridor_wall])
      minz = zvalues.min + corridor_wall.space.get.zOrigin
      if minz < min_story_corridor_wall_minz
        min_story_corridor_walls.clear
        min_story_corridor_walls << corridor_wall
        min_story_corridor_wall_minz = minz
      elsif (minz - min_story_corridor_wall_minz).abs < 0.001
        min_story_corridor_walls << corridor_wall
      end
    end

    # Prioritize corridor surfaces if available
    unless min_story_corridor_walls.size == 0
      min_story_avail_walls = min_story_corridor_walls
    end

    unit_has_door = true
    if min_story_avail_walls.size == 0
      runner.registerWarning('Could not find appropriate surface for the door. No door was added.')
      unit_has_door = false
    end

    door_sub_surface = nil
    min_story_avail_walls.each do |min_story_avail_wall|
      wall_gross_area = UnitConversions.convert(min_story_avail_wall.grossArea, 'm^2', 'ft^2')

      # Try to place door on any surface with enough area
      next if door_area >= wall_gross_area

      facade = get_facade_for_surface(min_story_avail_wall)

      if (door_offset + door_width) * door_height > wall_gross_area
        # Reduce door offset to fit door on surface
        door_offset = 0
      end

      num_existing_doors_on_this_surface = 0
      min_story_avail_wall.subSurfaces.each do |sub_surface|
        if sub_surface.subSurfaceType.downcase == 'door'
          num_existing_doors_on_this_surface += 1
        end
      end
      new_door_offset = door_offset + (door_offset + door_width) * num_existing_doors_on_this_surface

      # Create door vertices in relative coordinates
      upperleft = [new_door_offset, door_height]
      upperright = [new_door_offset + door_width, door_height]
      lowerright = [new_door_offset + door_width, 0]
      lowerleft = [new_door_offset, 0]

      # Convert to 3D geometry; assign to surface
      door_polygon = OpenStudio::Point3dVector.new
      if facade == Constants.FacadeFront
        multx = 1
        multy = 0
      elsif facade == Constants.FacadeBack
        multx = -1
        multy = 0
      elsif facade == Constants.FacadeLeft
        multx = 0
        multy = -1
      elsif facade == Constants.FacadeRight
        multx = 0
        multy = 1
      end
      if (facade == Constants.FacadeBack) || (facade == Constants.FacadeLeft)
        leftx = getSurfaceXValues([min_story_avail_wall]).max
        lefty = getSurfaceYValues([min_story_avail_wall]).max
      else
        leftx = getSurfaceXValues([min_story_avail_wall]).min
        lefty = getSurfaceYValues([min_story_avail_wall]).min
      end
      bottomz = getSurfaceZValues([min_story_avail_wall]).min

      [upperleft, lowerleft, lowerright, upperright].each do |coord|
        newx = UnitConversions.convert(leftx + multx * coord[0], 'ft', 'm')
        newy = UnitConversions.convert(lefty + multy * coord[0], 'ft', 'm')
        newz = UnitConversions.convert(bottomz + coord[1], 'ft', 'm')
        door_vertex = OpenStudio::Point3d.new(newx, newy, newz)
        door_polygon << door_vertex
      end

      door_sub_surface = OpenStudio::Model::SubSurface.new(door_polygon, model)
      door_sub_surface.setName("#{min_story_avail_wall.name} - Door")
      door_sub_surface.setSurface(min_story_avail_wall)
      door_sub_surface.setSubSurfaceType('Door')
      if not construction.nil?
        door_sub_surface.setConstruction(construction)
      end

      break
    end

    if door_sub_surface.nil? && unit_has_door
      runner.registerWarning('Could not find appropriate surface for the door. No door was added.')
    end

    return true
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

  def self.create_single_family_attached(runner:,
                                         model:,
                                         geometry_cfa:,
                                         geometry_wall_height:,
                                         geometry_building_num_units:,
                                         geometry_num_floors_above_grade:,
                                         geometry_aspect_ratio:,
                                         geometry_horizontal_location:,
                                         geometry_corridor_position:,
                                         geometry_foundation_type:,
                                         geometry_foundation_height:,
                                         geometry_rim_joist_height:,
                                         geometry_attic_type:,
                                         geometry_roof_type:,
                                         geometry_roof_pitch:,
                                         **remainder)

    cfa = geometry_cfa
    wall_height = geometry_wall_height
    num_units = geometry_building_num_units.get
    num_floors = geometry_num_floors_above_grade
    aspect_ratio = geometry_aspect_ratio
    horizontal_location = geometry_horizontal_location.get
    corridor_position = geometry_corridor_position
    foundation_type = geometry_foundation_type
    foundation_height = geometry_foundation_height
    rim_joist_height = geometry_rim_joist_height
    attic_type = geometry_attic_type
    if attic_type == HPXML::AtticTypeConditioned
      num_floors -= 1
    end
    roof_type = geometry_roof_type
    roof_pitch = geometry_roof_pitch

    has_rear_units = false
    if corridor_position == 'Double Exterior'
      has_rear_units = true
    end
    offset = 0

    num_units_actual = num_units
    num_floors_actual = num_floors
    if has_rear_units
      unit_width = num_units / 2
    else
      unit_width = num_units
    end

    # error checking
    if model.getSpaces.size > 0
      runner.registerError('Starting model is not empty.')
      return false
    end
    if foundation_type.downcase.include?('crawlspace') && ((foundation_height < 1.5) || (foundation_height > 5.0))
      runner.registerError('The crawlspace height can be set between 1.5 and 5 ft.')
      return false
    end
    if (num_units == 1) && has_rear_units
      runner.registerError("Specified building as having rear units, but didn't specify enough units.")
      return false
    end
    if aspect_ratio < 0
      runner.registerError('Invalid aspect ratio entered.')
      return false
    end
    if has_rear_units && (num_units % 2 != 0)
      runner.registerError('Specified a building with rear units and an odd number of units.')
      return false
    end
    if (unit_width < 3) && (horizontal_location == 'Middle')
      runner.registerError('Invalid horizontal location entered, no middle location exists.')
      return false
    end
    if (unit_width > 1) && (horizontal_location == 'None')
      runner.registerError('Invalid horizontal location entered.')
      return false
    end
    if (unit_width == 1) && (horizontal_location != 'None')
      runner.registerWarning("No #{horizontal_location} location exists, setting horizontal_location to 'None'")
      horizontal_location = 'None'
    end

    # Convert to SI
    cfa = UnitConversions.convert(cfa, 'ft^2', 'm^2')
    wall_height = UnitConversions.convert(wall_height, 'ft', 'm')
    foundation_height = UnitConversions.convert(foundation_height, 'ft', 'm')
    rim_joist_height = UnitConversions.convert(rim_joist_height, 'ft', 'm')

    if (foundation_type == HPXML::FoundationTypeBasementConditioned) && (attic_type == HPXML::AtticTypeConditioned)
      footprint = cfa / (num_floors + 2)
    elsif (foundation_type == HPXML::FoundationTypeBasementConditioned) || (attic_type == HPXML::AtticTypeConditioned)
      footprint = cfa / (num_floors + 1)
    else
      footprint = cfa / num_floors
    end

    # calculate the dimensions of the unit
    x = Math.sqrt(footprint / aspect_ratio)
    y = footprint / x

    foundation_front_polygon = nil
    foundation_back_polygon = nil

    # create the front prototype unit
    nw_point = OpenStudio::Point3d.new(0, 0, rim_joist_height)
    ne_point = OpenStudio::Point3d.new(x, 0, rim_joist_height)
    sw_point = OpenStudio::Point3d.new(0, -y, rim_joist_height)
    se_point = OpenStudio::Point3d.new(x, -y, rim_joist_height)
    living_polygon = make_polygon(sw_point, nw_point, ne_point, se_point)

    # foundation
    if (foundation_height > 0) && foundation_front_polygon.nil?
      foundation_front_polygon = living_polygon
    end

    # create living zone
    living_zone = OpenStudio::Model::ThermalZone.new(model)
    living_zone.setName('living zone')

    # first floor front
    living_spaces_front = []
    living_space = OpenStudio::Model::Space::fromFloorPrint(living_polygon, wall_height, model)
    living_space = living_space.get
    living_space.setName(HPXML::LocationLivingSpace)
    living_space_type = OpenStudio::Model::SpaceType.new(model)
    living_space_type.setStandardsSpaceType(HPXML::LocationLivingSpace)
    living_space.setSpaceType(living_space_type)
    living_space.setThermalZone(living_zone)

    living_spaces_front << living_space

    # Adiabatic surfaces for walls
    # Map unit location to adiabatic surfaces (#if `key` unit then make `value(s)` adiabatic)
    horz_hash = { 'Left' => ['right'], 'Right' => ['left'], 'Middle' => ['left', 'right'], 'None' => [] }
    adb_facade = horz_hash[horizontal_location]
    if (has_rear_units == true)
      adb_facade += ['back']
    end

    adiabatic_surf = adb_facade
    # Make surfaces adiabatic
    model.getSpaces.each do |space|
      space.surfaces.each do |surface|
        os_facade = get_facade_for_surface(surface)
        next unless surface.surfaceType == 'Wall'
        next unless adb_facade.include? os_facade

        x_ft = UnitConversions.convert(x, 'm', 'ft')
        max_x = getSurfaceXValues([surface]).max
        min_x = getSurfaceXValues([surface]).min
        next if ((max_x - x_ft).abs >= 0.01) && (min_x > 0)

        surface.setOutsideBoundaryCondition('Adiabatic')
      end
    end

    attic_space_front = nil
    attic_space_back = nil
    attic_spaces = []

    # additional floors
    (2..num_floors).to_a.each do |story|
      new_living_space = living_space.clone.to_Space.get
      new_living_space.setName("living space|story #{story}")
      new_living_space.setSpaceType(living_space_type)

      m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      m[2, 3] = wall_height * (story - 1)
      new_living_space.setTransformation(OpenStudio::Transformation.new(m))
      new_living_space.setThermalZone(living_zone)

      living_spaces_front << new_living_space
    end

    # attic
    if roof_type != 'flat'
      attic_space = get_attic_space(model, x, y, wall_height, num_floors, num_units, roof_pitch, roof_type, rim_joist_height)
      if attic_type == HPXML::AtticTypeConditioned
        attic_space.setName("#{attic_type} space")
        attic_space.setThermalZone(living_zone)
        attic_space.setSpaceType(living_space_type)
        living_spaces_front << attic_space
      else
        attic_spaces << attic_space
        attic_space_front = attic_space
      end
    end

    # foundation
    if foundation_height > 0
      foundation_spaces = []

      # foundation front
      foundation_space_front = []
      foundation_space = OpenStudio::Model::Space::fromFloorPrint(foundation_front_polygon, foundation_height, model)
      foundation_space = foundation_space.get
      m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      m[2, 3] = foundation_height
      foundation_space.changeTransformation(OpenStudio::Transformation.new(m))
      foundation_space.setXOrigin(0)
      foundation_space.setYOrigin(0)
      foundation_space.setZOrigin(0)

      if foundation_type == HPXML::FoundationTypeBasementConditioned
        foundation_zone = OpenStudio::Model::ThermalZone.new(model)
        foundation_space.setName(HPXML::FoundationTypeBasementConditioned)
        foundation_zone.setName(HPXML::FoundationTypeBasementConditioned)
        foundation_space.setThermalZone(foundation_zone)
        foundation_space_type = OpenStudio::Model::SpaceType.new(model)
        foundation_space_type.setStandardsSpaceType(HPXML::LocationBasementConditioned)
        foundation_space.setSpaceType(foundation_space_type)
      end

      foundation_space_front << foundation_space
      foundation_spaces << foundation_space

      # Rim Joist
      add_rim_joist(model, foundation_front_polygon, foundation_space, rim_joist_height, 0)

      # put all of the spaces in the model into a vector
      spaces = OpenStudio::Model::SpaceVector.new
      model.getSpaces.each do |space|
        spaces << space
      end

      # intersect and match surfaces for each space in the vector
      OpenStudio::Model.intersectSurfaces(spaces)
      OpenStudio::Model.matchSurfaces(spaces)

      if [HPXML::FoundationTypeCrawlspaceVented, HPXML::FoundationTypeCrawlspaceUnvented, HPXML::FoundationTypeBasementUnconditioned].include? foundation_type
        # create foundation zone
        foundation_zone = OpenStudio::Model::ThermalZone.new(model)

        foundation_space = make_one_space_from_multiple_spaces(model, foundation_spaces)
        if foundation_type == HPXML::FoundationTypeCrawlspaceVented
          foundation_space_name = HPXML::LocationCrawlspaceVented
        elsif foundation_type == HPXML::FoundationTypeCrawlspaceUnvented
          foundation_space_name = HPXML::LocationCrawlspaceUnvented
        elsif foundation_type == HPXML::FoundationTypeBasementUnconditioned
          foundation_space_name = HPXML::LocationBasementUnconditioned
        end
        foundation_zone.setName(foundation_space_name)
        foundation_space.setName(foundation_space_name)
        foundation_space_type = OpenStudio::Model::SpaceType.new(model)
        foundation_space_type.setStandardsSpaceType(foundation_space_name)
        foundation_space.setSpaceType(foundation_space_type)

        # set these to the foundation zone
        foundation_space.setThermalZone(foundation_zone)
      end

      # set foundation walls to ground
      spaces = model.getSpaces
      spaces.each do |space|
        next unless get_space_floor_z(space) + UnitConversions.convert(space.zOrigin, 'm', 'ft') < 0

        surfaces = space.surfaces
        surfaces.each do |surface|
          next if surface.surfaceType.downcase != 'wall'

          os_facade = get_facade_for_surface(surface)
          if adb_facade.include? os_facade
            surface.setOutsideBoundaryCondition('Adiabatic')
          elsif getSurfaceZValues([surface]).min < 0
            surface.setOutsideBoundaryCondition('Foundation')
          else
            surface.setOutsideBoundaryCondition('Outdoors')
          end
        end
      end

    end

    # put all of the spaces in the model into a vector
    spaces = OpenStudio::Model::SpaceVector.new
    model.getSpaces.each do |space|
      spaces << space
    end

    # intersect and match surfaces for each space in the vector
    OpenStudio::Model.intersectSurfaces(spaces)
    OpenStudio::Model.matchSurfaces(spaces)

    if [HPXML::AtticTypeVented, HPXML::AtticTypeUnvented].include?(attic_type) && (roof_type != 'flat')
      if offset == 0
        attic_spaces.each do |attic_space|
          attic_space.remove
        end
        attic_space = get_attic_space(model, x, y, wall_height, num_floors, num_units, roof_pitch, roof_type, rim_joist_height, has_rear_units)
      else
        attic_space = make_one_space_from_multiple_spaces(model, attic_spaces)
      end

      # set these to the attic zone
      if (attic_type == HPXML::AtticTypeVented) || (attic_type == HPXML::AtticTypeUnvented)
        # create attic zone
        attic_zone = OpenStudio::Model::ThermalZone.new(model)
        attic_space.setThermalZone(attic_zone)
        if attic_type == HPXML::AtticTypeVented
          attic_space_name = HPXML::LocationAtticVented
        elsif attic_type == HPXML::AtticTypeUnvented
          attic_space_name = HPXML::LocationAtticUnvented
        end
        attic_zone.setName(attic_space_name)
      elsif attic_type == HPXML::AtticTypeConditioned
        attic_space.setThermalZone(living_zone)
        attic_space_name = HPXML::LocationLivingSpace
      end
      attic_space.setName(attic_space_name)
      attic_space_type = OpenStudio::Model::SpaceType.new(model)
      attic_space_type.setStandardsSpaceType(attic_space_name)
      attic_space.setSpaceType(attic_space_type)

      # Adiabatic surfaces for attic walls
      attic_space.surfaces.each do |surface|
        os_facade = get_facade_for_surface(surface)
        next unless surface.surfaceType == 'Wall'
        next unless adb_facade.include? os_facade

        x_ft = UnitConversions.convert(x, 'm', 'ft')
        max_x = getSurfaceXValues([surface]).max
        min_x = getSurfaceXValues([surface]).min
        next if ((max_x - x_ft).abs >= 0.01) && (min_x > 0)

        surface.setOutsideBoundaryCondition('Adiabatic')
      end
    end

    # put all of the spaces in the model into a vector
    spaces = OpenStudio::Model::SpaceVector.new
    model.getSpaces.each do |space|
      spaces << space
    end

    # intersect and match surfaces for each space in the vector
    OpenStudio::Model.intersectSurfaces(spaces)
    OpenStudio::Model.matchSurfaces(spaces)

    # set foundation outside boundary condition to Kiva "foundation"
    model.getSurfaces.each do |surface|
      next if surface.outsideBoundaryCondition.downcase != 'ground'

      surface.setOutsideBoundaryCondition('Foundation')
    end

    return true
  end

  def self.get_attic_space(model, x, y, wall_height, num_floors, num_units, roof_pitch, roof_type, rim_joist_height, has_rear_units = false)
    y_rear = 0
    y_peak = -y / 2
    y_tot = y
    x_tot = x * num_units

    nw_point = OpenStudio::Point3d.new(0, 0, wall_height * num_floors + rim_joist_height)
    ne_point = OpenStudio::Point3d.new(x, 0, wall_height * num_floors + rim_joist_height)
    sw_point = OpenStudio::Point3d.new(0, -y, wall_height * num_floors + rim_joist_height)
    se_point = OpenStudio::Point3d.new(x, -y, wall_height * num_floors + rim_joist_height)
    attic_polygon = make_polygon(sw_point, nw_point, ne_point, se_point)

    attic_height = (y_tot / 2.0) * roof_pitch + rim_joist_height # Roof always has same orientation

    side_type = nil
    if roof_type == 'gable'
      roof_w_point = OpenStudio::Point3d.new(0, y_peak, wall_height * num_floors + attic_height)
      roof_e_point = OpenStudio::Point3d.new(x, y_peak, wall_height * num_floors + attic_height)
      polygon_w_roof = make_polygon(roof_w_point, roof_e_point, ne_point, nw_point)
      polygon_e_roof = make_polygon(roof_e_point, roof_w_point, sw_point, se_point)
      polygon_s_wall = make_polygon(roof_w_point, nw_point, sw_point)
      polygon_n_wall = make_polygon(roof_e_point, se_point, ne_point)
      side_type = 'Wall'
    elsif roof_type == 'hip'
      if y > 0
        if x <= (y + y_rear)
          roof_n_point = OpenStudio::Point3d.new(x / 2.0, y_rear - x / 2.0, wall_height * num_floors + attic_height)
          roof_s_point = OpenStudio::Point3d.new(x / 2.0, -y + x / 2.0, wall_height * num_floors + attic_height)
          polygon_w_roof = make_polygon(roof_n_point, nw_point, sw_point, roof_s_point)
          polygon_e_roof = make_polygon(roof_s_point, se_point, ne_point, roof_n_point)
          polygon_s_wall = make_polygon(roof_s_point, sw_point, se_point)
          polygon_n_wall = make_polygon(roof_n_point, ne_point, nw_point)
        else
          roof_w_point = OpenStudio::Point3d.new((y + y_rear) / 2.0, (y_rear - y) / 2.0, wall_height * num_floors + attic_height)
          roof_e_point = OpenStudio::Point3d.new(x - (y + y_rear) / 2.0, (y_rear - y) / 2.0, wall_height * num_floors + attic_height)
          polygon_w_roof = make_polygon(roof_w_point, sw_point, se_point, roof_e_point)
          polygon_e_roof = make_polygon(roof_e_point, ne_point, nw_point, roof_w_point)
          polygon_s_wall = make_polygon(roof_e_point, se_point, ne_point)
          polygon_n_wall = make_polygon(roof_w_point, nw_point, sw_point)
        end
      else
        if x <= y.abs
          roof_n_point = OpenStudio::Point3d.new(x / 2.0, -y - x / 2.0, wall_height * num_floors + attic_height)
          roof_s_point = OpenStudio::Point3d.new(x / 2.0, x / 2.0, wall_height * num_floors + attic_height)
          polygon_w_roof = make_polygon(roof_n_point, nw_point, sw_point, roof_s_point)
          polygon_e_roof = make_polygon(roof_s_point, se_point, ne_point, roof_n_point)
          polygon_s_wall = make_polygon(roof_s_point, sw_point, se_point)
          polygon_n_wall = make_polygon(roof_n_point, ne_point, nw_point)
        else
          roof_w_point = OpenStudio::Point3d.new(-y / 2.0, -y / 2.0, wall_height * num_floors + attic_height)
          roof_e_point = OpenStudio::Point3d.new(x + y / 2.0, -y / 2.0, wall_height * num_floors + attic_height)
          polygon_w_roof = make_polygon(roof_w_point, sw_point, se_point, roof_e_point)
          polygon_e_roof = make_polygon(roof_e_point, ne_point, nw_point, roof_w_point)
          polygon_s_wall = make_polygon(roof_e_point, se_point, ne_point)
          polygon_n_wall = make_polygon(roof_w_point, nw_point, sw_point)
        end
      end
      side_type = 'RoofCeiling'
    end

    surface_floor = OpenStudio::Model::Surface.new(attic_polygon, model)
    surface_floor.setSurfaceType('Floor')
    surface_floor.setOutsideBoundaryCondition('Surface')
    surface_w_roof = OpenStudio::Model::Surface.new(polygon_w_roof, model)
    surface_w_roof.setSurfaceType('RoofCeiling')
    surface_w_roof.setOutsideBoundaryCondition('Outdoors')
    surface_e_roof = OpenStudio::Model::Surface.new(polygon_e_roof, model)
    surface_e_roof.setSurfaceType('RoofCeiling')
    surface_e_roof.setOutsideBoundaryCondition('Outdoors')
    surface_s_wall = OpenStudio::Model::Surface.new(polygon_s_wall, model)
    surface_s_wall.setSurfaceType(side_type)
    surface_s_wall.setOutsideBoundaryCondition('Outdoors')
    surface_n_wall = OpenStudio::Model::Surface.new(polygon_n_wall, model)
    surface_n_wall.setSurfaceType(side_type)
    surface_n_wall.setOutsideBoundaryCondition('Outdoors')

    attic_space = OpenStudio::Model::Space.new(model)

    surface_floor.setSpace(attic_space)
    surface_w_roof.setSpace(attic_space)
    surface_e_roof.setSpace(attic_space)
    surface_s_wall.setSpace(attic_space)
    surface_n_wall.setSpace(attic_space)

    return attic_space
  end

  def self.create_multifamily(runner:,
                              model:,
                              geometry_cfa:,
                              geometry_wall_height:,
                              geometry_building_num_units:,
                              geometry_num_floors_above_grade:,
                              geometry_aspect_ratio:,
                              geometry_level:,
                              geometry_horizontal_location:,
                              geometry_corridor_position:,
                              geometry_corridor_width:,
                              geometry_inset_width:,
                              geometry_inset_depth:,
                              geometry_inset_position:,
                              geometry_balcony_depth:,
                              geometry_foundation_type:,
                              geometry_foundation_height:,
                              geometry_rim_joist_height:,
                              **remainder)

    cfa = geometry_cfa
    wall_height = geometry_wall_height
    num_units = geometry_building_num_units.get
    num_floors = geometry_num_floors_above_grade
    aspect_ratio = geometry_aspect_ratio
    level = geometry_level.get
    horz_location = geometry_horizontal_location.get
    corridor_position = geometry_corridor_position
    corridor_width = geometry_corridor_width
    inset_width = geometry_inset_width
    inset_depth = geometry_inset_depth
    inset_position = geometry_inset_position
    balcony_depth = geometry_balcony_depth
    foundation_type = geometry_foundation_type
    foundation_height = geometry_foundation_height
    rim_joist_height = geometry_rim_joist_height

    if level != 'Bottom'
      foundation_type = HPXML::LocationOtherHousingUnit
      foundation_height = 0.0
      rim_joist_height = 0.0
    end

    num_units_per_floor = num_units / num_floors
    num_units_per_floor_actual = num_units_per_floor
    above_ground_floors = num_floors

    if (num_floors > 1) && (level != 'Bottom') && (foundation_height > 0.0)
      runner.registerWarning('Unit is not on the bottom floor, setting foundation height to 0.')
      foundation_height = 0.0
    end

    if num_floors == 1
      level = 'Bottom'
    end

    if (num_floors <= 2) && (level == 'Middle')
      runner.registerError("Building is #{num_floors} stories and does not have middle units")
      return false
    end

    if (num_units_per_floor >= 4) && (corridor_position != 'Single Exterior (Front)') # assume double-loaded corridor
      unit_depth = 2
      unit_width = num_units_per_floor / 2.0
      has_rear_units = true
    elsif (num_units_per_floor == 2) && (horz_location == 'None') # double-loaded corridor for 2 units/story
      unit_depth = 2
      unit_width = 1.0
      has_rear_units = true
    else
      unit_depth = 1
      unit_width = num_units_per_floor
      has_rear_units = false
    end

    # error checking
    if model.getSpaces.size > 0
      runner.registerError('Starting model is not empty.')
      return false
    end
    if foundation_type.downcase.include?('crawlspace') && ((foundation_height < 1.5) || (foundation_height > 5.0)) && level == 'Bottom'
      runner.registerError('The crawlspace height can be set between 1.5 and 5 ft.')
      return false
    end
    if !has_rear_units && ((corridor_position == 'Double-Loaded Interior') || (corridor_position == 'Double Exterior'))
      runner.registerWarning("Specified incompatible corridor; setting corridor position to 'Single Exterior (Front)'.")
      corridor_position = 'Single Exterior (Front)'
    end
    if aspect_ratio < 0
      runner.registerError('Invalid aspect ratio entered.')
      return false
    end
    if (corridor_width == 0) && (corridor_position != 'None')
      corridor_position = 'None'
    end
    if corridor_position == 'None'
      corridor_width = 0
    end
    if corridor_width < 0
      runner.registerError('Invalid corridor width entered.')
      return false
    end
    if (balcony_depth > 0) && (inset_width * inset_depth == 0)
      runner.registerWarning('Specified a balcony, but there is no inset.')
      balcony_depth = 0
    end
    if (unit_width < 2) && (horz_location != 'None')
      runner.registerWarning("No #{horz_location} location exists, setting horz_location to 'None'")
      horz_location = 'None'
    end
    if (unit_width >= 2) && (horz_location == 'None')
      runner.registerError('Specified incompatible horizontal location for the corridor and unit configuration.')
      return false
    end
    if (unit_width > 1) && (horz_location == 'None')
      runner.registerError('Specified incompatible horizontal location for the corridor and unit configuration.')
      return false
    end
    if (unit_width <= 2) && (horz_location == 'Middle')
      runner.registerError('Invalid horizontal location entered, no middle location exists.')
      return false
    end

    # Convert to SI
    cfa = UnitConversions.convert(cfa, 'ft^2', 'm^2')
    wall_height = UnitConversions.convert(wall_height, 'ft', 'm')
    foundation_height = UnitConversions.convert(foundation_height, 'ft', 'm')
    corridor_width = UnitConversions.convert(corridor_width, 'ft', 'm')
    inset_width = UnitConversions.convert(inset_width, 'ft', 'm')
    inset_depth = UnitConversions.convert(inset_depth, 'ft', 'm')
    balcony_depth = UnitConversions.convert(balcony_depth, 'ft', 'm')
    rim_joist_height = UnitConversions.convert(rim_joist_height, 'ft', 'm')

    # calculate the dimensions of the unit
    footprint = cfa + inset_width * inset_depth
    x = Math.sqrt(footprint / aspect_ratio)
    y = footprint / x

    story_hash = { 'Bottom' => 0, 'Middle' => 1, 'Top' => num_floors - 1 }
    z = wall_height * story_hash[level]

    foundation_corr_polygon = nil
    foundation_front_polygon = nil
    foundation_back_polygon = nil

    # create the front prototype unit footprint
    nw_point = OpenStudio::Point3d.new(0, 0, rim_joist_height)
    ne_point = OpenStudio::Point3d.new(x, 0, rim_joist_height)
    sw_point = OpenStudio::Point3d.new(0, -y, rim_joist_height)
    se_point = OpenStudio::Point3d.new(x, -y, rim_joist_height)

    if inset_width * inset_depth > 0
      if inset_position == 'Right'
        # unit footprint
        inset_point = OpenStudio::Point3d.new(x - inset_width, inset_depth - y, rim_joist_height)
        front_point = OpenStudio::Point3d.new(x - inset_width, -y, rim_joist_height)
        side_point = OpenStudio::Point3d.new(x, inset_depth - y, rim_joist_height)
        living_polygon = make_polygon(sw_point, nw_point, ne_point, side_point, inset_point, front_point)
        # unit balcony
        if balcony_depth > 0
          inset_point = OpenStudio::Point3d.new(x - inset_width, inset_depth - y, wall_height + rim_joist_height)
          side_point = OpenStudio::Point3d.new(x, inset_depth - y, wall_height + rim_joist_height)
          se_point = OpenStudio::Point3d.new(x, inset_depth - y - balcony_depth, wall_height + rim_joist_height)
          front_point = OpenStudio::Point3d.new(x - inset_width, inset_depth - y - balcony_depth, wall_height + rim_joist_height)
          shading_surface = OpenStudio::Model::ShadingSurface.new(OpenStudio::Point3dVector.new([front_point, se_point, side_point, inset_point]), model)
        end
      else
        # unit footprint
        inset_point = OpenStudio::Point3d.new(inset_width, inset_depth - y, rim_joist_height)
        front_point = OpenStudio::Point3d.new(inset_width, -y, rim_joist_height)
        side_point = OpenStudio::Point3d.new(0, inset_depth - y, rim_joist_height)
        living_polygon = make_polygon(side_point, nw_point, ne_point, se_point, front_point, inset_point)
        # unit balcony
        if balcony_depth > 0
          inset_point = OpenStudio::Point3d.new(inset_width, inset_depth - y, wall_height + rim_joist_height)
          side_point = OpenStudio::Point3d.new(0, inset_depth - y, wall_height + rim_joist_height)
          sw_point = OpenStudio::Point3d.new(0, inset_depth - y - balcony_depth, wall_height + rim_joist_height)
          front_point = OpenStudio::Point3d.new(inset_width, inset_depth - y - balcony_depth, wall_height + rim_joist_height)
          shading_surface = OpenStudio::Model::ShadingSurface.new(OpenStudio::Point3dVector.new([front_point, sw_point, side_point, inset_point]), model)
        end
      end
    else
      living_polygon = make_polygon(sw_point, nw_point, ne_point, se_point)
    end

    # foundation
    if (foundation_height > 0) && foundation_front_polygon.nil?
      foundation_front_polygon = living_polygon
    end

    # create living zone
    living_zone = OpenStudio::Model::ThermalZone.new(model)
    living_zone.setName('living zone')

    # first floor front
    living_spaces_front = []
    living_space = OpenStudio::Model::Space::fromFloorPrint(living_polygon, wall_height, model)
    living_space = living_space.get
    living_space.setName(HPXML::LocationLivingSpace)
    living_space_type = OpenStudio::Model::SpaceType.new(model)
    living_space_type.setStandardsSpaceType(HPXML::LocationLivingSpace)
    living_space.setSpaceType(living_space_type)
    living_space.setThermalZone(living_zone)

    # add the balcony
    if balcony_depth > 0
      shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
      shading_surface_group.setSpace(living_space)
      shading_surface.setShadingSurfaceGroup(shading_surface_group)
    end
    living_spaces_front << living_space

    # Map unit location to adiabatic surfaces
    horz_hash = { 'Left' => ['right'], 'Right' => ['left'], 'Middle' => ['left', 'right'], 'None' => [] }
    level_hash = { 'Bottom' => ['RoofCeiling'], 'Top' => ['Floor'], 'Middle' => ['RoofCeiling', 'Floor'], 'None' => [] }
    adb_facade = horz_hash[horz_location]
    adb_level = level_hash[level]

    # Check levels
    if num_floors == 1
      adb_level = []
    end
    if (has_rear_units == true)
      adb_facade += ['back']
    end

    adiabatic_surf = adb_facade + adb_level
    # Make living space surfaces adiabatic
    model.getSpaces.each do |space|
      space.surfaces.each do |surface|
        os_facade = get_facade_for_surface(surface)
        if surface.surfaceType == 'Wall'
          if adb_facade.include? os_facade
            x_ft = UnitConversions.convert(x, 'm', 'ft')
            max_x = getSurfaceXValues([surface]).max
            min_x = getSurfaceXValues([surface]).min
            next if ((max_x - x_ft).abs >= 0.01) && (min_x > 0)

            surface.setOutsideBoundaryCondition('Adiabatic')
          end
        else
          if (adb_level.include? surface.surfaceType)
            surface.setOutsideBoundaryCondition('Adiabatic')
          end

        end
      end
    end

    if (corridor_position == 'Double-Loaded Interior')
      interior_corridor_width = corridor_width / 2 # Only half the corridor is attached to a unit
      # corridors
      if corridor_width > 0
        # create the prototype corridor
        nw_point = OpenStudio::Point3d.new(0, interior_corridor_width, rim_joist_height)
        ne_point = OpenStudio::Point3d.new(x, interior_corridor_width, rim_joist_height)
        sw_point = OpenStudio::Point3d.new(0, 0, rim_joist_height)
        se_point = OpenStudio::Point3d.new(x, 0, rim_joist_height)
        corr_polygon = make_polygon(sw_point, nw_point, ne_point, se_point)

        if (foundation_height > 0) && foundation_corr_polygon.nil?
          foundation_corr_polygon = corr_polygon
        end

        # create corridor zone
        corridor_zone = OpenStudio::Model::ThermalZone.new(model)
        corridor_zone.setName(HPXML::LocationOtherHousingUnit)
        corridor_space = OpenStudio::Model::Space::fromFloorPrint(corr_polygon, wall_height, model)
        corridor_space = corridor_space.get
        corridor_space.setName(HPXML::LocationOtherHousingUnit)
        corridor_space_type = OpenStudio::Model::SpaceType.new(model)
        corridor_space_type.setStandardsSpaceType(HPXML::LocationOtherHousingUnit)

        corridor_space.setSpaceType(corridor_space_type)
        corridor_space.setThermalZone(corridor_zone)
      end

    elsif (corridor_position == 'Double Exterior') || (corridor_position == 'Single Exterior (Front)')
      interior_corridor_width = 0
      # front access
      nw_point = OpenStudio::Point3d.new(0, -y, wall_height + rim_joist_height)
      sw_point = OpenStudio::Point3d.new(0, -y - corridor_width, wall_height + rim_joist_height)
      ne_point = OpenStudio::Point3d.new(x, -y, wall_height + rim_joist_height)
      se_point = OpenStudio::Point3d.new(x, -y - corridor_width, wall_height + rim_joist_height)

      shading_surface = OpenStudio::Model::ShadingSurface.new(OpenStudio::Point3dVector.new([sw_point, se_point, ne_point, nw_point]), model)
      shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
      shading_surface.setShadingSurfaceGroup(shading_surface_group)
      shading_surface.setName('Corridor shading')
    end

    # foundation
    if foundation_height > 0
      foundation_spaces = []

      # foundation corridor
      foundation_corridor_space = nil
      if (corridor_width > 0) && (corridor_position == 'Double-Loaded Interior')
        foundation_corridor_space = OpenStudio::Model::Space::fromFloorPrint(foundation_corr_polygon, foundation_height, model)
        foundation_corridor_space = foundation_corridor_space.get
        m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
        m[2, 3] = foundation_height + rim_joist_height
        foundation_corridor_space.changeTransformation(OpenStudio::Transformation.new(m))
        foundation_corridor_space.setXOrigin(0)
        foundation_corridor_space.setYOrigin(0)
        foundation_corridor_space.setZOrigin(0)
        foundation_spaces << foundation_corridor_space

        # Rim Joist
        add_rim_joist(model, foundation_corr_polygon, foundation_corridor_space, rim_joist_height, 0)
      end

      # foundation front
      foundation_space_front = []
      foundation_space = OpenStudio::Model::Space::fromFloorPrint(foundation_front_polygon, foundation_height, model)
      foundation_space = foundation_space.get
      m = initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      m[2, 3] = foundation_height + rim_joist_height
      foundation_space.changeTransformation(OpenStudio::Transformation.new(m))
      foundation_space.setXOrigin(0)
      foundation_space.setYOrigin(0)
      foundation_space.setZOrigin(0)

      foundation_space_front << foundation_space
      foundation_spaces << foundation_space

      foundation_spaces.each do |foundation_space| # (corridor and foundation)
        next unless [HPXML::FoundationTypeCrawlspaceVented, HPXML::FoundationTypeCrawlspaceUnvented, HPXML::FoundationTypeBasementUnconditioned].include?(foundation_type)

        # create foundation zone
        foundation_zone = OpenStudio::Model::ThermalZone.new(model)

        if foundation_type == HPXML::FoundationTypeCrawlspaceVented
          foundation_space_name = HPXML::LocationCrawlspaceVented
        elsif foundation_type == HPXML::FoundationTypeCrawlspaceUnvented
          foundation_space_name = HPXML::LocationCrawlspaceUnvented
        elsif foundation_type == HPXML::FoundationTypeBasementUnconditioned
          foundation_space_name = HPXML::LocationBasementUnconditioned
        end
        foundation_zone.setName(foundation_space_name)
        foundation_space.setName(foundation_space_name)
        foundation_space_type = OpenStudio::Model::SpaceType.new(model)
        foundation_space_type.setStandardsSpaceType(foundation_space_name)
        foundation_space.setSpaceType(foundation_space_type)

        # set these to the foundation zone
        foundation_space.setThermalZone(foundation_zone)
      end

      # Rim Joist
      add_rim_joist(model, foundation_front_polygon, foundation_space, rim_joist_height, 0)

      # put all of the spaces in the model into a vector
      spaces = OpenStudio::Model::SpaceVector.new
      model.getSpaces.each do |space|
        spaces << space
      end

      # intersect and match surfaces for each space in the vector
      OpenStudio::Model.intersectSurfaces(spaces)
      OpenStudio::Model.matchSurfaces(spaces)

      # Foundation space boundary conditions
      model.getSpaces.each do |space|
        next unless get_space_floor_z(space) + UnitConversions.convert(space.zOrigin, 'm', 'ft') < 0 # Foundation
        next if space.name.get.include? 'corridor'

        surfaces = space.surfaces
        surfaces.each do |surface|
          next unless surface.surfaceType.downcase == 'wall'

          os_facade = get_facade_for_surface(surface)
          if adb_facade.include?(os_facade) && (os_facade != 'RoofCeiling') && (os_facade != 'Floor')
            surface.setOutsideBoundaryCondition('Adiabatic')
          elsif getSurfaceZValues([surface]).min < 0
            surface.setOutsideBoundaryCondition('Foundation')
          else
            surface.setOutsideBoundaryCondition('Outdoors')
          end
        end
      end

      # Foundation corridor space boundary conditions
      foundation_corr_obcs = []
      if not foundation_corridor_space.nil?
        foundation_corridor_space.surfaces.each do |surface|
          next unless surface.surfaceType.downcase == 'wall'

          os_facade = get_facade_for_surface(surface)
          if adb_facade.include? os_facade
            surface.setOutsideBoundaryCondition('Adiabatic')
          else
            surface.setOutsideBoundaryCondition('Foundation')
          end
        end
      end
    end

    # Corridor space boundary conditions
    model.getSpaces.each do |space|
      next unless is_corridor(space)

      space.surfaces.each do |surface|
        os_facade = get_facade_for_surface(surface)
        if adb_facade.include? os_facade
          surface.setOutsideBoundaryCondition('Adiabatic')
        end

        if (adb_level.include? surface.surfaceType)
          surface.setOutsideBoundaryCondition('Adiabatic')
        end
      end
    end

    # put all of the spaces in the model into a vector
    spaces = OpenStudio::Model::SpaceVector.new
    model.getSpaces.each do |space|
      spaces << space
    end

    # intersect and match surfaces for each space in the vector
    OpenStudio::Model.intersectSurfaces(spaces)
    OpenStudio::Model.matchSurfaces(spaces)

    # make corridor floors adiabatic if no exterior walls to avoid exposed perimeter error
    exterior_obcs = ['Foundation', 'Ground', 'Outdoors']
    obcs_hash = {}
    model.getSpaces.each do |space|
      next unless space.name.get.include? 'corridor' # corridor and foundation corridor spaces

      space_name = space.name
      obcs_hash[space_name] = []
      space.surfaces.each do |surface|
        next unless surface.surfaceType.downcase == 'wall'

        obcs_hash[space_name] << surface.outsideBoundaryCondition
      end

      next if (obcs_hash[space_name] & exterior_obcs).any?

      space.surfaces.each do |surface|
        next unless surface.surfaceType.downcase == 'floor'

        surface.setOutsideBoundaryCondition('Adiabatic')
      end
    end

    # set foundation outside boundary condition to Kiva "foundation"
    model.getSurfaces.each do |surface|
      next if surface.outsideBoundaryCondition.downcase != 'ground'

      surface.setOutsideBoundaryCondition('Foundation')
    end

    # set adjacent corridor walls to adiabatic
    model.getSpaces.each do |space|
      next unless is_corridor(space)

      space.surfaces.each do |surface|
        if surface.adjacentSurface.is_initialized && (surface.surfaceType.downcase == 'wall')
          surface.adjacentSurface.get.setOutsideBoundaryCondition('Adiabatic')
          surface.setOutsideBoundaryCondition('Adiabatic')
        end
      end
    end

    return true
  end

  def self.is_corridor(space_or_zone)
    return space_or_zone_is_of_type(space_or_zone, HPXML::LocationOtherHousingUnit)
  end

  # Returns true if space is either fully or partially below grade
  def self.space_is_below_grade(space)
    space.surfaces.each do |surface|
      next if surface.surfaceType.downcase != 'wall'
      if surface.outsideBoundaryCondition.downcase == 'foundation'
        return true
      end
    end
    return false
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
          next unless is_point_between([wv1.x, wv1.y, wv1.z + wall_surface.space.get.zOrigin], [fv1.x, fv1.y, fv1.z + floor_surface.space.get.zOrigin], [fv2.x, fv2.y, fv2.z + floor_surface.space.get.zOrigin]) && is_point_between([wv2.x, wv2.y, wv2.z + wall_surface.space.get.zOrigin], [fv1.x, fv1.y, fv1.z + floor_surface.space.get.zOrigin], [fv2.x, fv2.y, fv2.z + floor_surface.space.get.zOrigin])

          if not adjacent_wall_surfaces.include? wall_surface
            adjacent_wall_surfaces << wall_surface
          end
        end
      end
    end

    return adjacent_wall_surfaces
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

  def self.get_edges_for_surfaces(surfaces, use_top_edge)
    edges = []
    edge_counter = 0
    surfaces.each do |surface|
      if use_top_edge
        matchz = getSurfaceZValues([surface]).max
      else
        matchz = getSurfaceZValues([surface]).min
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

  def self.space_is_conditioned(space)
    unless space.isPlenum
      if space.spaceType.is_initialized
        if space.spaceType.get.standardsSpaceType.is_initialized
          return is_conditioned_space_type(space.spaceType.get.standardsSpaceType.get)
        end
      end
    end
    return false
  end

  def self.is_conditioned_space_type(space_type)
    if [HPXML::LocationLivingSpace].include? space_type
      return true
    end

    return false
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

  def self.get_conditioned_attic_height(spaces)
    # gable roof type
    get_conditioned_spaces(spaces).each do |space|
      space.surfaces.each do |surface|
        next if surface.vertices.size != 3
        next if surface.outsideBoundaryCondition != 'Outdoors'
        next if surface.surfaceType != 'Wall'

        return get_height_of_spaces([space])
      end
    end

    # hip roof type
    get_conditioned_spaces(spaces).each do |space|
      space.surfaces.each do |surface|
        next if surface.outsideBoundaryCondition != 'Outdoors'
        next if surface.surfaceType != 'RoofCeiling'

        return get_height_of_spaces([space])
      end
    end

    return false
  end

  def self.surface_is_rim_joist(surface, height)
    return false unless (height - Geometry.get_surface_height(surface)).abs < 0.00001
    return false unless Geometry.getSurfaceZValues([surface]).max > 0

    return true
  end
end
