# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'unit_conversions')
require File.join(resources_path, 'schedules')

# start the measure
class CreateResidentialSingleFamilyAttachedGeometry < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Create Residential Single-Family Attached Geometry'
  end

  # human readable description
  def description
    return "Sets the basic geometry for the single-family attached building, where all units span the building's number of stories and are not stacked. Sets the number of bedrooms, bathrooms, and occupants in the building.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Creates single-family attached geometry. Also, sets (or replaces) BuildingUnit objects that store the number of bedrooms and bathrooms associated with the model. Sets (or replaces) the People object for each finished space in the model.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make an argument for unit living space floor area
    unit_ffa = OpenStudio::Measure::OSArgument::makeDoubleArgument('unit_ffa', true)
    unit_ffa.setDisplayName('Unit Finished Floor Area')
    unit_ffa.setUnits('ft^2')
    unit_ffa.setDescription('Unit floor area of the finished space (including any finished basement floor area).')
    unit_ffa.setDefaultValue(900.0)
    args << unit_ffa

    # make an argument for living space height
    wall_height = OpenStudio::Measure::OSArgument::makeDoubleArgument('wall_height', true)
    wall_height.setDisplayName('Wall Height (Per Floor)')
    wall_height.setUnits('ft')
    wall_height.setDescription('The height of the living space walls.')
    wall_height.setDefaultValue(8.0)
    args << wall_height

    # make an argument for total number of floors
    num_floors = OpenStudio::Measure::OSArgument::makeIntegerArgument('num_floors', true)
    num_floors.setDisplayName('Building Num Floors')
    num_floors.setUnits('#')
    num_floors.setDescription('The number of floors above grade. Finished attics are included.')
    num_floors.setDefaultValue(1)
    args << num_floors

    # make an argument for number of units
    num_units = OpenStudio::Measure::OSArgument::makeIntegerArgument('num_units', true)
    num_units.setDisplayName('Num Units')
    num_units.setUnits('#')
    num_units.setDescription('The number of units.')
    num_units.setDefaultValue(2)
    args << num_units

    # make an argument for unit aspect ratio
    unit_aspect_ratio = OpenStudio::Measure::OSArgument::makeDoubleArgument('unit_aspect_ratio', true)
    unit_aspect_ratio.setDisplayName('Unit Aspect Ratio')
    unit_aspect_ratio.setUnits('FB/LR')
    unit_aspect_ratio.setDescription('The ratio of the front/back wall length to the left/right wall length.')
    unit_aspect_ratio.setDefaultValue(2.0)
    args << unit_aspect_ratio

    # make an argument for unit offset
    offset = OpenStudio::Measure::OSArgument::makeDoubleArgument('offset', true)
    offset.setDisplayName('Offset Depth')
    offset.setUnits('ft')
    offset.setDescription('The depth of the offset.')
    offset.setDefaultValue(0.0)
    args << offset

    # make an argument for units in back
    has_rear_units = OpenStudio::Measure::OSArgument::makeBoolArgument('has_rear_units', true)
    has_rear_units.setDisplayName('Has Rear Units?')
    has_rear_units.setDescription('Whether the building has rear adjacent units.')
    has_rear_units.setDefaultValue(false)
    args << has_rear_units

    # make a choice argument for model objects
    foundation_display_names = OpenStudio::StringVector.new
    foundation_display_names << 'slab'
    foundation_display_names << 'crawlspace'
    foundation_display_names << 'unfinished basement'
    foundation_display_names << 'finished basement'

    # make a choice argument for foundation type
    foundation_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('foundation_type', foundation_display_names, true)
    foundation_type.setDisplayName('Foundation Type')
    foundation_type.setDescription('The foundation type of the building.')
    foundation_type.setDefaultValue('slab')
    args << foundation_type

    # make an argument for crawlspace height
    foundation_height = OpenStudio::Measure::OSArgument::makeDoubleArgument('foundation_height', true)
    foundation_height.setDisplayName('Foundation Height')
    foundation_height.setUnits('ft')
    foundation_height.setDescription('The height of the foundation (e.g., 3ft for crawlspace, 8ft for basement).')
    foundation_height.setDefaultValue(3.0)
    args << foundation_height

    # make a choice argument for model objects
    attic_type_display_names = OpenStudio::StringVector.new
    attic_type_display_names << 'unfinished attic'
    attic_type_display_names << 'finished attic'

    # make a choice argument for attic type
    attic_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('attic_type', attic_type_display_names, true)
    attic_type.setDisplayName('Attic Type')
    attic_type.setDescription('The attic type of the building. Ignored if the building has a flat roof.')
    attic_type.setDefaultValue('unfinished attic')
    args << attic_type

    # make a choice argument for model objects
    roof_type_display_names = OpenStudio::StringVector.new
    roof_type_display_names << Constants.RoofTypeGable
    roof_type_display_names << Constants.RoofTypeHip
    roof_type_display_names << Constants.RoofTypeFlat

    # make a choice argument for roof type
    roof_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('roof_type', roof_type_display_names, true)
    roof_type.setDisplayName('Roof Type')
    roof_type.setDescription('The roof type of the building.')
    roof_type.setDefaultValue(Constants.RoofTypeGable)
    args << roof_type

    # make a choice argument for model objects
    roof_pitch_display_names = OpenStudio::StringVector.new
    roof_pitch_display_names << '1:12'
    roof_pitch_display_names << '2:12'
    roof_pitch_display_names << '3:12'
    roof_pitch_display_names << '4:12'
    roof_pitch_display_names << '5:12'
    roof_pitch_display_names << '6:12'
    roof_pitch_display_names << '7:12'
    roof_pitch_display_names << '8:12'
    roof_pitch_display_names << '9:12'
    roof_pitch_display_names << '10:12'
    roof_pitch_display_names << '11:12'
    roof_pitch_display_names << '12:12'

    # make a choice argument for roof pitch
    roof_pitch = OpenStudio::Measure::OSArgument::makeChoiceArgument('roof_pitch', roof_pitch_display_names, true)
    roof_pitch.setDisplayName('Roof Pitch')
    roof_pitch.setDescription('The roof pitch of the attic. Ignored if the building has a flat roof.')
    roof_pitch.setDefaultValue('6:12')
    args << roof_pitch

    # make a choice argument for model objects
    roof_structure_display_names = OpenStudio::StringVector.new
    roof_structure_display_names << Constants.RoofStructureTrussCantilever
    roof_structure_display_names << Constants.RoofStructureRafter

    # make a choice argument for roof type
    roof_structure = OpenStudio::Measure::OSArgument::makeChoiceArgument('roof_structure', roof_structure_display_names, true)
    roof_structure.setDisplayName('Roof Structure')
    roof_structure.setDescription('The roof structure of the building.')
    roof_structure.setDefaultValue(Constants.RoofStructureTrussCantilever)
    args << roof_structure

    # make a choice argument for eaves depth
    eaves_depth = OpenStudio::Measure::OSArgument::makeDoubleArgument('eaves_depth', true)
    eaves_depth.setDisplayName('Eaves Depth')
    eaves_depth.setUnits('ft')
    eaves_depth.setDescription('The eaves depth of the roof.')
    eaves_depth.setDefaultValue(2.0)
    args << eaves_depth

    # make a string argument for number of bedrooms
    num_br = OpenStudio::Measure::OSArgument::makeStringArgument('num_bedrooms', true)
    num_br.setDisplayName('Number of Bedrooms')
    num_br.setDescription('Specify the number of bedrooms. Used to determine the energy usage of appliances and plug loads, hot water usage, mechanical ventilation rate, etc.')
    num_br.setDefaultValue('3')
    args << num_br

    # make a string argument for number of bathrooms
    num_ba = OpenStudio::Measure::OSArgument::makeStringArgument('num_bathrooms', true)
    num_ba.setDisplayName('Number of Bathrooms')
    num_ba.setDescription('Specify the number of bathrooms. Used to determine the hot water usage, etc.')
    num_ba.setDefaultValue('2')
    args << num_ba

    # make a double argument for left neighbor offset
    left_neighbor_offset = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_left_offset', true)
    left_neighbor_offset.setDisplayName('Neighbor Left Offset')
    left_neighbor_offset.setUnits('ft')
    left_neighbor_offset.setDescription('The minimum distance between the simulated house and the neighboring house to the left (not including eaves). A value of zero indicates no neighbors.')
    left_neighbor_offset.setDefaultValue(10.0)
    args << left_neighbor_offset

    # make a double argument for right neighbor offset
    right_neighbor_offset = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_right_offset', true)
    right_neighbor_offset.setDisplayName('Neighbor Right Offset')
    right_neighbor_offset.setUnits('ft')
    right_neighbor_offset.setDescription('The minimum distance between the simulated house and the neighboring house to the right (not including eaves). A value of zero indicates no neighbors.')
    right_neighbor_offset.setDefaultValue(10.0)
    args << right_neighbor_offset

    # make a double argument for back neighbor offset
    back_neighbor_offset = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_back_offset', true)
    back_neighbor_offset.setDisplayName('Neighbor Back Offset')
    back_neighbor_offset.setUnits('ft')
    back_neighbor_offset.setDescription('The minimum distance between the simulated house and the neighboring house to the back (not including eaves). A value of zero indicates no neighbors.')
    back_neighbor_offset.setDefaultValue(0.0)
    args << back_neighbor_offset

    # make a double argument for front neighbor offset
    front_neighbor_offset = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_front_offset', true)
    front_neighbor_offset.setDisplayName('Neighbor Front Offset')
    front_neighbor_offset.setUnits('ft')
    front_neighbor_offset.setDescription('The minimum distance between the simulated house and the neighboring house to the front (not including eaves). A value of zero indicates no neighbors.')
    front_neighbor_offset.setDefaultValue(0.0)
    args << front_neighbor_offset

    # make a double argument for orientation
    orientation = OpenStudio::Measure::OSArgument::makeDoubleArgument('orientation', true)
    orientation.setDisplayName('Azimuth')
    orientation.setUnits('degrees')
    orientation.setDescription("The house's azimuth is measured clockwise from due south when viewed from above (e.g., South=0, West=90, North=180, East=270).")
    orientation.setDefaultValue(180.0)
    args << orientation

    # make a string argument for unit horizontal location
    horz_location = OpenStudio::Measure::OSArgument::makeStringArgument('horz_location', true)
    horz_location.setDisplayName('Horizontal Location of the Unit')
    horz_location.setDescription('The horizontal location of the unit when viewing the front of the building (Left, Middle, Right)')
    horz_location.setDefaultValue('Left')
    args << horz_location

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    unit_ffa = UnitConversions.convert(runner.getDoubleArgumentValue('unit_ffa', user_arguments), 'ft^2', 'm^2')
    wall_height = UnitConversions.convert(runner.getDoubleArgumentValue('wall_height', user_arguments), 'ft', 'm')
    num_floors = runner.getIntegerArgumentValue('num_floors', user_arguments)
    num_units = runner.getIntegerArgumentValue('num_units', user_arguments)
    unit_aspect_ratio = runner.getDoubleArgumentValue('unit_aspect_ratio', user_arguments)
    offset = UnitConversions.convert(runner.getDoubleArgumentValue('offset', user_arguments), 'ft', 'm')
    has_rear_units = runner.getBoolArgumentValue('has_rear_units', user_arguments)
    foundation_type = runner.getStringArgumentValue('foundation_type', user_arguments)
    foundation_height = runner.getDoubleArgumentValue('foundation_height', user_arguments)
    attic_type = runner.getStringArgumentValue('attic_type', user_arguments)
    if attic_type == 'finished attic'
      num_floors -= 1
    end
    roof_type = runner.getStringArgumentValue('roof_type', user_arguments)
    roof_pitch = { '1:12' => 1.0 / 12.0, '2:12' => 2.0 / 12.0, '3:12' => 3.0 / 12.0, '4:12' => 4.0 / 12.0, '5:12' => 5.0 / 12.0, '6:12' => 6.0 / 12.0, '7:12' => 7.0 / 12.0, '8:12' => 8.0 / 12.0, '9:12' => 9.0 / 12.0, '10:12' => 10.0 / 12.0, '11:12' => 11.0 / 12.0, '12:12' => 12.0 / 12.0 }[runner.getStringArgumentValue('roof_pitch', user_arguments)]
    roof_structure = runner.getStringArgumentValue('roof_structure', user_arguments)
    eaves_depth = UnitConversions.convert(runner.getDoubleArgumentValue('eaves_depth', user_arguments), 'ft', 'm')
    num_br = runner.getStringArgumentValue('num_bedrooms', user_arguments).split(',').map(&:strip)
    num_ba = runner.getStringArgumentValue('num_bathrooms', user_arguments).split(',').map(&:strip)
    num_occupants = Constants.Auto
    if model.getBuilding.additionalProperties.getFeatureAsInteger('num_occupants').is_initialized
      num_occupants = "#{model.getBuilding.additionalProperties.getFeatureAsInteger('num_occupants').get}"
    end
    left_neighbor_offset = UnitConversions.convert(runner.getDoubleArgumentValue('neighbor_left_offset', user_arguments), 'ft', 'm')
    right_neighbor_offset = UnitConversions.convert(runner.getDoubleArgumentValue('neighbor_right_offset', user_arguments), 'ft', 'm')
    back_neighbor_offset = UnitConversions.convert(runner.getDoubleArgumentValue('neighbor_back_offset', user_arguments), 'ft', 'm')
    front_neighbor_offset = UnitConversions.convert(runner.getDoubleArgumentValue('neighbor_front_offset', user_arguments), 'ft', 'm')
    orientation = runner.getDoubleArgumentValue('orientation', user_arguments)
    horz_location = runner.getStringArgumentValue('horz_location', user_arguments)

    num_units_actual = num_units
    num_floors_actual = num_floors
    if has_rear_units
      unit_width = num_units / 2
    else
      unit_width = num_units
    end

    if foundation_type == 'slab'
      foundation_height = 0.0
    elsif (foundation_type == 'unfinished basement') || (foundation_type == 'finished basement')
      foundation_height = 8.0
    end

    # error checking
    if model.getSpaces.size > 0
      runner.registerError('Starting model is not empty.')
      return false
    end
    if (foundation_type == 'crawlspace') && ((foundation_height < 1.5) || (foundation_height > 5.0))
      runner.registerError('The crawlspace height can be set between 1.5 and 5 ft.')
      return false
    end
    if (num_units == 1) && has_rear_units
      runner.registerError("Specified building as having rear units, but didn't specify enough units.")
      return false
    end
    if unit_aspect_ratio < 0
      runner.registerError('Invalid aspect ratio entered.')
      return false
    end
    if has_rear_units && (num_units % 2 != 0)
      runner.registerError('Specified a building with rear units and an odd number of units.')
      return false
    end
    if (unit_width < 3) && (horz_location == 'Middle')
      runner.registerError('Invalid horizontal location entered, no middle location exists.')
      return false
    end
    if (unit_width > 1) && (horz_location == 'None')
      runner.registerError('Invalid horizontal location entered.')
      return false
    end
    if (unit_width == 1) && (horz_location != 'None')
      runner.registerWarning("No #{horz_location} location exists, setting horz_location to 'None'")
      horz_location = 'None'
    end
    if (unit_width > 1) && (horz_location == 'None')
      runner.registerError('Specified incompatible horizontal location for the corridor and unit configuration.')
      return false
    end
    if (unit_width < 3) && (horz_location == 'Middle')
      runner.registerError('Invalid horizontal location entered, no middle location exists.')
      return false
    end

    # convert to si
    foundation_height = UnitConversions.convert(foundation_height, 'ft', 'm')

    # starting spaces
    runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

    if (foundation_type == 'finished basement') && (attic_type == 'finished attic')
      footprint = unit_ffa / (num_floors + 2)
    elsif (foundation_type == 'finished basement') || (attic_type == 'finished attic')
      footprint = unit_ffa / (num_floors + 1)
    else
      footprint = unit_ffa / num_floors
    end

    # calculate the dimensions of the unit
    x = Math.sqrt(footprint / unit_aspect_ratio)
    y = footprint / x

    foundation_front_polygon = nil
    foundation_back_polygon = nil

    # create the front prototype unit
    nw_point = OpenStudio::Point3d.new(0, 0, 0)
    ne_point = OpenStudio::Point3d.new(x, 0, 0)
    sw_point = OpenStudio::Point3d.new(0, -y, 0)
    se_point = OpenStudio::Point3d.new(x, -y, 0)
    living_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, se_point)

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
    living_space.setName('living space')
    living_space_type = OpenStudio::Model::SpaceType.new(model)
    living_space_type.setStandardsSpaceType(Constants.SpaceTypeLiving)
    living_space.setSpaceType(living_space_type)
    living_space.setThermalZone(living_zone)

    living_spaces_front << living_space

    # Adiabatic surfaces for walls
    # Map unit location to adiabatic surfaces (#if `key` unit then make `value(s)` adiabatic)
    horz_hash = { 'Left' => ['right'], 'Right' => ['left'], 'Middle' => ['left', 'right'], 'None' => [] }
    adb_facade = horz_hash[horz_location]
    if (has_rear_units == true)
      adb_facade += ['back']
    end

    adiabatic_surf = adb_facade
    # Make surfaces adiabatic
    model.getSpaces.each do |space|
      space.surfaces.each do |surface|
        os_facade = Geometry.get_facade_for_surface(surface)
        next unless surface.surfaceType == 'Wall'
        next unless adb_facade.include? os_facade

        x_ft = UnitConversions.convert(x, 'm', 'ft')
        max_x = Geometry.getSurfaceXValues([surface]).max
        min_x = Geometry.getSurfaceXValues([surface]).min
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

      m = Geometry.initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      m[2, 3] = wall_height * (story - 1)
      new_living_space.setTransformation(OpenStudio::Transformation.new(m))
      new_living_space.setThermalZone(living_zone)

      living_spaces_front << new_living_space
    end

    # attic
    if roof_type != Constants.RoofTypeFlat
      attic_space = get_attic_space(model, x, y, wall_height, num_floors, num_units, roof_pitch, roof_type)
      if attic_type == 'finished attic'
        attic_space.setName('finished attic space')
        attic_space.setThermalZone(living_zone)
        attic_space.setSpaceType(living_space_type)
        living_spaces_front << attic_space
      else
        attic_spaces << attic_space
        attic_space_front = attic_space
      end
    end

    # create the unit
    unit_spaces = []
    unit_spaces << living_spaces_front

    # foundation
    if foundation_height > 0
      foundation_spaces = []

      # foundation front
      foundation_space_front = []
      foundation_space = OpenStudio::Model::Space::fromFloorPrint(foundation_front_polygon, foundation_height, model)
      foundation_space = foundation_space.get
      m = Geometry.initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      m[2, 3] = foundation_height
      foundation_space.changeTransformation(OpenStudio::Transformation.new(m))
      foundation_space.setXOrigin(0)
      foundation_space.setYOrigin(0)
      foundation_space.setZOrigin(0)

      if foundation_type == 'finished basement'
        foundation_zone = OpenStudio::Model::ThermalZone.new(model)
        foundation_space.setName('finished basement space')
        foundation_zone.setName('finished basement zone')
        foundation_space.setThermalZone(foundation_zone)
        foundation_space_type = OpenStudio::Model::SpaceType.new(model)
        foundation_space_type.setStandardsSpaceType(Constants.SpaceTypeFinishedBasement)
        foundation_space.setSpaceType(foundation_space_type)
      end

      foundation_space_front << foundation_space
      foundation_spaces << foundation_space

      if foundation_type == 'finished basement'
        unit_spaces[0] << foundation_space
      end

      # put all of the spaces in the model into a vector
      spaces = OpenStudio::Model::SpaceVector.new
      model.getSpaces.each do |space|
        spaces << space
      end

      # intersect and match surfaces for each space in the vector
      OpenStudio::Model.intersectSurfaces(spaces)
      OpenStudio::Model.matchSurfaces(spaces)

      if ['crawlspace', 'unfinished basement'].include? foundation_type
        foundation_space = Geometry.make_one_space_from_multiple_spaces(model, foundation_spaces)
        if foundation_type == 'crawlspace'
          foundation_space.setName('crawl space')
          foundation_zone = OpenStudio::Model::ThermalZone.new(model)
          foundation_zone.setName('crawl zone')
          foundation_space.setThermalZone(foundation_zone)
          foundation_space_type = OpenStudio::Model::SpaceType.new(model)
          foundation_space_type.setStandardsSpaceType(Constants.SpaceTypeCrawl)
          foundation_space.setSpaceType(foundation_space_type)
        elsif foundation_type == 'unfinished basement'
          foundation_space.setName('unfinished basement space')
          foundation_zone = OpenStudio::Model::ThermalZone.new(model)
          foundation_zone.setName('unfinished basement zone')
          foundation_space.setThermalZone(foundation_zone)
          foundation_space_type = OpenStudio::Model::SpaceType.new(model)
          foundation_space_type.setStandardsSpaceType(Constants.SpaceTypeUnfinishedBasement)
          foundation_space.setSpaceType(foundation_space_type)
        end
      end

      # set foundation walls to ground
      spaces = model.getSpaces
      spaces.each do |space|
        next unless Geometry.get_space_floor_z(space) + UnitConversions.convert(space.zOrigin, 'm', 'ft') < 0

        surfaces = space.surfaces
        surfaces.each do |surface|
          next if surface.surfaceType.downcase != 'wall'

          os_facade = Geometry.get_facade_for_surface(surface)
          if adb_facade.include? os_facade
            surface.setOutsideBoundaryCondition('Adiabatic')
          else
            surface.setOutsideBoundaryCondition('Foundation')
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

    if (attic_type == 'unfinished attic') && (roof_type != Constants.RoofTypeFlat)
      if offset == 0
        attic_spaces.each do |attic_space|
          attic_space.remove
        end
        attic_space = get_attic_space(model, x, y, wall_height, num_floors, num_units, roof_pitch, roof_type, has_rear_units)
      else
        attic_space = Geometry.make_one_space_from_multiple_spaces(model, attic_spaces)
      end

      attic_space.setName('unfinished attic space')
      attic_zone = OpenStudio::Model::ThermalZone.new(model)
      attic_zone.setName('unfinished attic zone')
      attic_space.setThermalZone(attic_zone)
      attic_space_type = OpenStudio::Model::SpaceType.new(model)
      attic_space_type.setStandardsSpaceType(Constants.SpaceTypeUnfinishedAttic)
      attic_space.setSpaceType(attic_space_type)
    end

    # Adiabatic surfaces for attic walls
    attic_space.surfaces.each do |surface|
      os_facade = Geometry.get_facade_for_surface(surface)
      next unless surface.surfaceType == 'Wall'
      next unless adb_facade.include? os_facade

      x_ft = UnitConversions.convert(x, 'm', 'ft')
      max_x = Geometry.getSurfaceXValues([surface]).max
      min_x = Geometry.getSurfaceXValues([surface]).min
      next if ((max_x - x_ft).abs >= 0.01) && (min_x > 0)

      surface.setOutsideBoundaryCondition('Adiabatic')
    end

    unit_spaces.each do |spaces|
      # Store building unit information
      unit = OpenStudio::Model::BuildingUnit.new(model)
      unit.setBuildingUnitType(Constants.BuildingUnitTypeResidential)
      unit.setName(Constants.ObjectNameBuildingUnit(1))
      spaces.each do |space|
        space.setBuildingUnit(unit)
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

    # Store number of units
    model.getBuilding.setStandardsNumberOfLivingUnits(num_units)

    # Store number of stories
    above_ground_floors = num_floors
    if attic_type == 'finished attic'
      num_floors += 1
    end
    model.getBuilding.setStandardsNumberOfAboveGroundStories(num_floors)
    if (foundation_type == 'unfinished basement') || (foundation_type == 'finished basement')
      num_floors += 1
    end
    model.getBuilding.setStandardsNumberOfStories(num_floors)

    # Store the building type
    model.getBuilding.setStandardsBuildingType(Constants.BuildingTypeSingleFamilyAttached)

    # Store whole building variables
    model.getBuilding.additionalProperties.setFeature('num_units', num_units)
    model.getBuilding.additionalProperties.setFeature('has_rear_units', has_rear_units)
    model.getBuilding.additionalProperties.setFeature('horz_location', horz_location)
    model.getBuilding.additionalProperties.setFeature('num_floors', above_ground_floors)

    result = Geometry.process_beds_and_baths(model, runner, num_br, num_ba)
    unless result
      return false
    end

    schedules_file = SchedulesFile.new(runner: runner, model: model)
    if not schedules_file.validated?
      return false
    end

    result = Geometry.process_occupants(model, runner, num_occupants, occ_gain = 384.0, sens_frac = 0.573, lat_frac = 0.427, schedules_file)
    unless result
      return false
    end

    result = Geometry.process_eaves(model, runner, eaves_depth, roof_structure)
    unless result
      return false
    end

    result = Geometry.process_neighbors(model, runner, left_neighbor_offset, right_neighbor_offset, back_neighbor_offset, front_neighbor_offset)
    unless result
      return false
    end

    result = Geometry.process_orientation(model, runner, orientation)
    unless result
      return false
    end

    # reporting final condition of model
    return true
  end

  def get_attic_space(model, x, y, wall_height, num_floors, num_units, roof_pitch, roof_type, has_rear_units = false)
    y_rear = 0
    y_peak = -y / 2
    y_tot = y
    x_tot = x * num_units

    nw_point = OpenStudio::Point3d.new(0, 0, wall_height * num_floors)
    ne_point = OpenStudio::Point3d.new(x, 0, wall_height * num_floors)
    sw_point = OpenStudio::Point3d.new(0, -y, wall_height * num_floors)
    se_point = OpenStudio::Point3d.new(x, -y, wall_height * num_floors)
    attic_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, se_point)

    attic_height = (y_tot / 2.0) * roof_pitch # Roof always has same orientation

    side_type = nil
    if roof_type == Constants.RoofTypeGable
      roof_w_point = OpenStudio::Point3d.new(0, y_peak, wall_height * num_floors + attic_height)
      roof_e_point = OpenStudio::Point3d.new(x, y_peak, wall_height * num_floors + attic_height)
      polygon_w_roof = Geometry.make_polygon(roof_w_point, roof_e_point, ne_point, nw_point)
      polygon_e_roof = Geometry.make_polygon(roof_e_point, roof_w_point, sw_point, se_point)
      polygon_s_wall = Geometry.make_polygon(roof_w_point, nw_point, sw_point)
      polygon_n_wall = Geometry.make_polygon(roof_e_point, se_point, ne_point)
      side_type = 'Wall'
    elsif roof_type == Constants.RoofTypeHip
      if y > 0
        if x <= (y + y_rear)
          roof_n_point = OpenStudio::Point3d.new(x / 2.0, y_rear - x / 2.0, wall_height * num_floors + attic_height)
          roof_s_point = OpenStudio::Point3d.new(x / 2.0, -y + x / 2.0, wall_height * num_floors + attic_height)
          polygon_w_roof = Geometry.make_polygon(roof_n_point, nw_point, sw_point, roof_s_point)
          polygon_e_roof = Geometry.make_polygon(roof_s_point, se_point, ne_point, roof_n_point)
          polygon_s_wall = Geometry.make_polygon(roof_s_point, sw_point, se_point)
          polygon_n_wall = Geometry.make_polygon(roof_n_point, ne_point, nw_point)
        else
          roof_w_point = OpenStudio::Point3d.new((y + y_rear) / 2.0, (y_rear - y) / 2.0, wall_height * num_floors + attic_height)
          roof_e_point = OpenStudio::Point3d.new(x - (y + y_rear) / 2.0, (y_rear - y) / 2.0, wall_height * num_floors + attic_height)
          polygon_w_roof = Geometry.make_polygon(roof_w_point, sw_point, se_point, roof_e_point)
          polygon_e_roof = Geometry.make_polygon(roof_e_point, ne_point, nw_point, roof_w_point)
          polygon_s_wall = Geometry.make_polygon(roof_e_point, se_point, ne_point)
          polygon_n_wall = Geometry.make_polygon(roof_w_point, nw_point, sw_point)
        end
      else
        if x <= y.abs
          roof_n_point = OpenStudio::Point3d.new(x / 2.0, -y - x / 2.0, wall_height * num_floors + attic_height)
          roof_s_point = OpenStudio::Point3d.new(x / 2.0, x / 2.0, wall_height * num_floors + attic_height)
          polygon_w_roof = Geometry.make_polygon(roof_n_point, nw_point, sw_point, roof_s_point)
          polygon_e_roof = Geometry.make_polygon(roof_s_point, se_point, ne_point, roof_n_point)
          polygon_s_wall = Geometry.make_polygon(roof_s_point, sw_point, se_point)
          polygon_n_wall = Geometry.make_polygon(roof_n_point, ne_point, nw_point)
        else
          roof_w_point = OpenStudio::Point3d.new(-y / 2.0, -y / 2.0, wall_height * num_floors + attic_height)
          roof_e_point = OpenStudio::Point3d.new(x + y / 2.0, -y / 2.0, wall_height * num_floors + attic_height)
          polygon_w_roof = Geometry.make_polygon(roof_w_point, sw_point, se_point, roof_e_point)
          polygon_e_roof = Geometry.make_polygon(roof_e_point, ne_point, nw_point, roof_w_point)
          polygon_s_wall = Geometry.make_polygon(roof_e_point, se_point, ne_point)
          polygon_n_wall = Geometry.make_polygon(roof_w_point, nw_point, sw_point)
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
end

# register the measure to be used by the application
CreateResidentialSingleFamilyAttachedGeometry.new.registerWithApplication
