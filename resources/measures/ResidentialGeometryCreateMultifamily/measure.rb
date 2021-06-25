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
class CreateResidentialMultifamilyGeometry < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'CreateResidentialMultifamilyGeometry'
  end

  # human readable description
  def description
    return "Sets the geometry for a single unit in a multifamily building based on the user-specified location of the unit. Sets the number of bedrooms, bathrooms, and occupants in the unit.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Creates multifamily geometry for a single unit. Also, sets (or replaces) BuildingUnit objects that store the number of bedrooms and bathrooms associated with the model. Sets (or replaces) the People object for each finished space in the model.'
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
    num_floors.setDisplayName('Building Number of Floors')
    num_floors.setUnits('#')
    num_floors.setDescription('The number of floors above grade.')
    num_floors.setDefaultValue(1)
    args << num_floors

    # make an argument for number of units
    num_units = OpenStudio::Measure::OSArgument::makeIntegerArgument('num_units', true)
    num_units.setDisplayName('Num Units')
    num_units.setUnits('#')
    num_units.setDescription('The number of units. This must be divisible by the number of floors.')
    num_units.setDefaultValue(2)
    args << num_units

    # make an argument for unit aspect ratio
    unit_aspect_ratio = OpenStudio::Measure::OSArgument::makeDoubleArgument('unit_aspect_ratio', true)
    unit_aspect_ratio.setDisplayName('Unit Aspect Ratio')
    unit_aspect_ratio.setUnits('FB/LR')
    unit_aspect_ratio.setDescription('The ratio of the front/back wall length to the left/right wall length.')
    unit_aspect_ratio.setDefaultValue(2.0)
    args << unit_aspect_ratio

    # make an argument for corridor position
    corridor_position_display_names = OpenStudio::StringVector.new
    corridor_position_display_names << 'Double-Loaded Interior'
    corridor_position_display_names << 'Single Exterior (Front)'
    corridor_position_display_names << 'Double Exterior'
    corridor_position_display_names << 'None'

    corridor_position = OpenStudio::Measure::OSArgument::makeChoiceArgument('corridor_position', corridor_position_display_names, true)
    corridor_position.setDisplayName('Corridor Position')
    corridor_position.setDescription('The position of the corridor.')
    corridor_position.setDefaultValue('Double-Loaded Interior')
    args << corridor_position

    # make an argument for corridor width
    corridor_width = OpenStudio::Measure::OSArgument::makeDoubleArgument('corridor_width', true)
    corridor_width.setDisplayName('Corridor Width')
    corridor_width.setUnits('ft')
    corridor_width.setDescription('The width of the corridor.')
    corridor_width.setDefaultValue(10.0)
    args << corridor_width

    # make an argument for inset width
    inset_width = OpenStudio::Measure::OSArgument::makeDoubleArgument('inset_width', true)
    inset_width.setDisplayName('Inset Width')
    inset_width.setUnits('ft')
    inset_width.setDescription('The width of the inset.')
    inset_width.setDefaultValue(0.0)
    args << inset_width

    # make an argument for inset depth
    inset_depth = OpenStudio::Measure::OSArgument::makeDoubleArgument('inset_depth', true)
    inset_depth.setDisplayName('Inset Depth')
    inset_depth.setUnits('ft')
    inset_depth.setDescription('The depth of the inset.')
    inset_depth.setDefaultValue(0.0)
    args << inset_depth

    # make an argument for inset position
    inset_position_display_names = OpenStudio::StringVector.new
    inset_position_display_names << 'Right'
    inset_position_display_names << 'Left'

    inset_position = OpenStudio::Measure::OSArgument::makeChoiceArgument('inset_position', inset_position_display_names, true)
    inset_position.setDisplayName('Inset Position')
    inset_position.setDescription('The position of the inset.')
    inset_position.setDefaultValue('Right')
    args << inset_position

    # make an argument for balcony depth
    balcony_depth = OpenStudio::Measure::OSArgument::makeDoubleArgument('balcony_depth', true)
    balcony_depth.setDisplayName('Balcony Depth')
    balcony_depth.setUnits('ft')
    balcony_depth.setDescription('The depth of the balcony.')
    balcony_depth.setDefaultValue(0.0)
    args << balcony_depth

    # make a choice argument for model objects
    foundation_display_names = OpenStudio::StringVector.new
    foundation_display_names << 'slab'
    foundation_display_names << 'crawlspace'
    foundation_display_names << 'unfinished basement'

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

    # make a choice argument for unit level
    level_display_names = OpenStudio::StringVector.new
    level_display_names << 'Bottom'
    level_display_names << 'Middle'
    level_display_names << 'Top'
    level_display_names << 'None'

    level = OpenStudio::Measure::OSArgument::makeChoiceArgument('level', level_display_names, true)
    level.setDisplayName('Unit Level')
    level.setDescription('The level of the unit (Top, Middle, Bottom)')
    level.setDefaultValue('Bottom')
    args << level

    # make a choice argument for unit horizontal location
    horz_location_names = OpenStudio::StringVector.new
    horz_location_names << 'Right'
    horz_location_names << 'Middle'
    horz_location_names << 'Left'
    horz_location_names << 'None'

    horz_location = OpenStudio::Measure::OSArgument::makeChoiceArgument('horz_location', horz_location_names, true)
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

    model_spaces = model.getSpaces

    unit_ffa = UnitConversions.convert(runner.getDoubleArgumentValue('unit_ffa', user_arguments), 'ft^2', 'm^2')
    wall_height = UnitConversions.convert(runner.getDoubleArgumentValue('wall_height', user_arguments), 'ft', 'm')
    num_floors = runner.getIntegerArgumentValue('num_floors', user_arguments)
    num_units = runner.getIntegerArgumentValue('num_units', user_arguments)
    unit_aspect_ratio = runner.getDoubleArgumentValue('unit_aspect_ratio', user_arguments)
    corridor_position = runner.getStringArgumentValue('corridor_position', user_arguments)
    corridor_width = UnitConversions.convert(runner.getDoubleArgumentValue('corridor_width', user_arguments), 'ft', 'm')
    inset_width = UnitConversions.convert(runner.getDoubleArgumentValue('inset_width', user_arguments), 'ft', 'm')
    inset_depth = UnitConversions.convert(runner.getDoubleArgumentValue('inset_depth', user_arguments), 'ft', 'm')
    inset_position = runner.getStringArgumentValue('inset_position', user_arguments)
    balcony_depth = UnitConversions.convert(runner.getDoubleArgumentValue('balcony_depth', user_arguments), 'ft', 'm')
    foundation_type = runner.getStringArgumentValue('foundation_type', user_arguments)
    foundation_height = runner.getDoubleArgumentValue('foundation_height', user_arguments)
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

    level = runner.getStringArgumentValue('level', user_arguments)
    horz_location = runner.getStringArgumentValue('horz_location', user_arguments)

    if foundation_type == 'slab'
      foundation_height = 0.0
    elsif foundation_type == 'unfinished basement'
      foundation_height = 8.0
    end
    num_units_per_floor = num_units.to_f / num_floors.to_f
    num_units_per_floor_actual = num_units_per_floor
    above_ground_floors = num_floors

    if (num_floors > 1) && (level != 'Bottom') && (foundation_height > 0.0)
      runner.registerWarning('Unit is not on the bottom floor, setting foundation height to 0.')
      foundation_height = 0
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
    if model_spaces.size > 0
      runner.registerError('Starting model is not empty.')
      return false
    end
    # Commented out to allow for 0ft crawlspace on non-ground floor units
    if (foundation_type == 'crawlspace') && ((foundation_height < 1.5) || (foundation_height > 5.0)) && (level == 'Bottom')
      runner.registerError('The crawlspace height can be set between 1.5 and 5 ft.')
      return false
    end
    if !has_rear_units && ((corridor_position == 'Double-Loaded Interior') || (corridor_position == 'Double Exterior'))
      runner.registerWarning("Specified incompatible corridor; setting corridor position to 'Single Exterior (Front)'.")
      corridor_position = 'Single Exterior (Front)'
    end
    if unit_aspect_ratio < 0
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
    if (unit_width <= 2) && (horz_location == 'Middle')
      runner.registerError('Invalid horizontal location entered, no middle location exists.')
      return false
    end
    if (num_floors != 1) && (level != 'Top')
      eaves_depth = 0
    end

    # Convert to SI
    foundation_height = UnitConversions.convert(foundation_height, 'ft', 'm')
    space_types_hash = {}

    # starting spaces
    runner.registerInitialCondition("The building started with #{model_spaces.size} spaces.")

    # calculate the dimensions of the unit
    footprint = unit_ffa + inset_width * inset_depth
    x = Math.sqrt(footprint / unit_aspect_ratio)
    y = footprint / x

    story_hash = { 'Bottom' => 0, 'Middle' => (num_floors - 1) / 2.0, 'Top' => num_floors - 1 }
    z = wall_height * story_hash[level]

    foundation_corr_polygon = nil
    foundation_front_polygon = nil
    foundation_back_polygon = nil

    # create the front prototype unit footprint
    nw_point = OpenStudio::Point3d.new(0, 0, z)
    ne_point = OpenStudio::Point3d.new(x, 0, z)
    sw_point = OpenStudio::Point3d.new(0, -y, z)
    se_point = OpenStudio::Point3d.new(x, -y, z)

    if inset_width * inset_depth > 0
      if inset_position == 'Right'
        # unit footprint
        inset_point = OpenStudio::Point3d.new(x - inset_width, inset_depth - y, 0)
        front_point = OpenStudio::Point3d.new(x - inset_width, -y, 0)
        side_point = OpenStudio::Point3d.new(x, inset_depth - y, 0)
        living_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, side_point, inset_point, front_point)
        # unit balcony
        if balcony_depth > 0
          inset_point = OpenStudio::Point3d.new(x - inset_width, inset_depth - y, wall_height)
          side_point = OpenStudio::Point3d.new(x, inset_depth - y, wall_height)
          se_point = OpenStudio::Point3d.new(x, inset_depth - y - balcony_depth, wall_height)
          front_point = OpenStudio::Point3d.new(x - inset_width, inset_depth - y - balcony_depth, wall_height)
          shading_surface = OpenStudio::Model::ShadingSurface.new(OpenStudio::Point3dVector.new([front_point, se_point, side_point, inset_point]), model)
        end
      else
        # unit footprint
        inset_point = OpenStudio::Point3d.new(inset_width, inset_depth - y, 0)
        front_point = OpenStudio::Point3d.new(inset_width, -y, 0)
        side_point = OpenStudio::Point3d.new(0, inset_depth - y, 0)
        living_polygon = Geometry.make_polygon(side_point, nw_point, ne_point, se_point, front_point, inset_point)
        # unit balcony
        if balcony_depth > 0
          inset_point = OpenStudio::Point3d.new(inset_width, inset_depth - y, wall_height)
          side_point = OpenStudio::Point3d.new(0, inset_depth - y, wall_height)
          sw_point = OpenStudio::Point3d.new(0, inset_depth - y - balcony_depth, wall_height)
          front_point = OpenStudio::Point3d.new(inset_width, inset_depth - y - balcony_depth, wall_height)
          shading_surface = OpenStudio::Model::ShadingSurface.new(OpenStudio::Point3dVector.new([front_point, sw_point, side_point, inset_point]), model)
        end
      end
    else
      living_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, se_point)
    end

    # foundation
    if (foundation_height > 0) && foundation_front_polygon.nil?
      foundation_front_polygon = living_polygon
    end

    # create living zone
    living_zone = OpenStudio::Model::ThermalZone.new(model)
    living_zone.setName('living zone')

    # living space
    living_spaces_front = []
    living_space = OpenStudio::Model::Space::fromFloorPrint(living_polygon, wall_height, model)
    living_space = living_space.get
    living_space.setName('living space')
    if space_types_hash.keys.include? Constants.SpaceTypeLiving
      living_space_type = space_types_hash[Constants.SpaceTypeLiving]
    else
      living_space_type = OpenStudio::Model::SpaceType.new(model)
      living_space_type.setStandardsSpaceType(Constants.SpaceTypeLiving)
      space_types_hash[Constants.SpaceTypeLiving] = living_space_type
    end
    living_space.setSpaceType(living_space_type)
    living_space.setThermalZone(living_zone)

    # add the balcony
    if balcony_depth > 0
      shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
      shading_surface_group.setSpace(living_space)
      shading_surface.setShadingSurfaceGroup(shading_surface_group)
    end
    living_spaces_front << living_space
    unit_spaces = []
    unit_spaces << living_spaces_front

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
        os_facade = Geometry.get_facade_for_surface(surface)
        if surface.surfaceType == 'Wall'
          if adb_facade.include? os_facade
            x_ft = UnitConversions.convert(x, 'm', 'ft')
            max_x = Geometry.getSurfaceXValues([surface]).max
            min_x = Geometry.getSurfaceXValues([surface]).min
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
        nw_point = OpenStudio::Point3d.new(0, interior_corridor_width, z)
        ne_point = OpenStudio::Point3d.new(x, interior_corridor_width, z)
        sw_point = OpenStudio::Point3d.new(0, 0, z)
        se_point = OpenStudio::Point3d.new(x, 0, z)
        corr_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, se_point)

        if (foundation_height > 0) && foundation_corr_polygon.nil?
          foundation_corr_polygon = corr_polygon
        end

        # create corridor zone
        corridor_zone = OpenStudio::Model::ThermalZone.new(model)
        corridor_zone.setName('corridor zone')
        corridor_space = OpenStudio::Model::Space::fromFloorPrint(corr_polygon, wall_height, model)
        corridor_space = corridor_space.get
        corridor_space_name = 'corridor space'
        corridor_space.setName(corridor_space_name)
        if space_types_hash.keys.include? Constants.SpaceTypeCorridor
          corridor_space_type = space_types_hash[Constants.SpaceTypeCorridor]
        else
          corridor_space_type = OpenStudio::Model::SpaceType.new(model)
          corridor_space_type.setStandardsSpaceType(Constants.SpaceTypeCorridor)
          space_types_hash[Constants.SpaceTypeCorridor] = corridor_space_type
        end

        corridor_space.setSpaceType(corridor_space_type)
        corridor_space.setThermalZone(corridor_zone)
      end

    elsif (corridor_position == 'Double Exterior') || (corridor_position == 'Single Exterior (Front)')
      interior_corridor_width = 0
      # front access
      nw_point = OpenStudio::Point3d.new(0, -y, wall_height + z)
      sw_point = OpenStudio::Point3d.new(0, -y - corridor_width, wall_height + z)
      ne_point = OpenStudio::Point3d.new(x, -y, wall_height + z)
      se_point = OpenStudio::Point3d.new(x, -y - corridor_width, wall_height + z)

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
        m = Geometry.initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
        m[2, 3] = foundation_height
        foundation_corridor_space.changeTransformation(OpenStudio::Transformation.new(m))
        foundation_corridor_space.setXOrigin(0)
        foundation_corridor_space.setYOrigin(0)
        foundation_corridor_space.setZOrigin(0)
        foundation_spaces << foundation_corridor_space
      end

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

      foundation_space_front << foundation_space
      foundation_spaces << foundation_space

      foundation_spaces.each do |foundation_space| # (corridor and foundation)
        next unless (['crawlspace', 'unfinished basement'].include? foundation_type)

        if foundation_type == 'crawlspace'
          foundation_zone = OpenStudio::Model::ThermalZone.new(model)
          if (not foundation_corridor_space.nil?) && (foundation_space == foundation_corridor_space)
            foundation_space.setName('crawl corridor space')
            foundation_zone.setName('crawl corridor zone')
          else
            foundation_space.setName('crawl space')
            foundation_zone.setName('crawl zone')
          end

          foundation_space.setThermalZone(foundation_zone)
          foundation_space_type_name = Constants.SpaceTypeCrawl

        elsif foundation_type == 'unfinished basement'
          foundation_zone = OpenStudio::Model::ThermalZone.new(model)
          if (not foundation_corridor_space.nil?) && (foundation_space == foundation_corridor_space)
            foundation_space.setName('unfinished basement corridor space')
            foundation_zone.setName('unfinished basement corridor zone')
          else
            foundation_space.setName('unfinished basement space')
            foundation_zone.setName('unfinished basement zone')
          end

          foundation_space_type_name = Constants.SpaceTypeUnfinishedBasement
          foundation_space.setThermalZone(foundation_zone)
        end
        if space_types_hash.keys.include? foundation_space_type_name
          foundation_space_type = space_types_hash[foundation_space_type_name]
        else
          foundation_space_type = OpenStudio::Model::SpaceType.new(model)
          foundation_space_type.setStandardsSpaceType(foundation_space_type_name)
          space_types_hash[foundation_space_type_name] = foundation_space_type
        end
        foundation_space.setSpaceType(foundation_space_type)
      end

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
        next unless Geometry.get_space_floor_z(space) + UnitConversions.convert(space.zOrigin, 'm', 'ft') < 0 # Foundation
        next if space.name.get.include? 'corridor'

        surfaces = space.surfaces
        surfaces.each do |surface|
          next unless surface.surfaceType.downcase == 'wall'

          os_facade = Geometry.get_facade_for_surface(surface)
          if adb_facade.include?(os_facade) && (os_facade != 'RoofCeiling') && (os_facade != 'Floor')
            surface.setOutsideBoundaryCondition('Adiabatic')
          elsif os_facade != 'RoofCeiling'
            surface.setOutsideBoundaryCondition('Foundation')
          end
        end
      end

      # Foundation corridor space boundary conditions
      foundation_corr_obcs = []
      if not foundation_corridor_space.nil?
        foundation_corridor_space.surfaces.each do |surface|
          next unless surface.surfaceType.downcase == 'wall'

          os_facade = Geometry.get_facade_for_surface(surface)
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
      next unless Geometry.is_corridor(space)

      space.surfaces.each do |surface|
        os_facade = Geometry.get_facade_for_surface(surface)
        if adb_facade.include? os_facade
          surface.setOutsideBoundaryCondition('Adiabatic')
        end

        if (adb_level.include? surface.surfaceType)
          surface.setOutsideBoundaryCondition('Adiabatic')
        end
      end
    end

    unit_spaces.each do |spaces|
      # store building unit information
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

      next if (obcs_hash[space_name] & exterior_obcs).any? # if there is an exterior wall

      space.surfaces.each do |surface|
        if (surface.surfaceType.downcase == 'roofceiling') && (not foundation_corridor_space.nil?) && (space == foundation_corridor_space)
          surface.setOutsideBoundaryCondition('Adiabatic')
        end

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
      next unless Geometry.is_corridor(space)

      space.surfaces.each do |surface|
        if surface.adjacentSurface.is_initialized && (surface.surfaceType.downcase == 'wall')
          surface.adjacentSurface.get.setOutsideBoundaryCondition('Adiabatic')
          surface.setOutsideBoundaryCondition('Adiabatic')
        end
      end
    end

    # Store mf data on model
    model.getBuilding.additionalProperties.setFeature('num_units', num_units)
    model.getBuilding.additionalProperties.setFeature('has_rear_units', has_rear_units)
    model.getBuilding.additionalProperties.setFeature('num_floors', above_ground_floors)
    model.getBuilding.additionalProperties.setFeature('horz_location', horz_location)
    model.getBuilding.additionalProperties.setFeature('level', level)
    model.getBuilding.additionalProperties.setFeature('found_type', foundation_type)
    model.getBuilding.additionalProperties.setFeature('corridor_width', corridor_width.to_f)
    model.getBuilding.additionalProperties.setFeature('corridor_position', corridor_position)

    # Store number of units
    model.getBuilding.setStandardsNumberOfLivingUnits(num_units)

    # Store number of stories
    model.getBuilding.setStandardsNumberOfAboveGroundStories(num_floors)
    if foundation_type == 'unfinished basement'
      num_floors += 1
    end
    model.getBuilding.setStandardsNumberOfStories(num_floors)

    # Store the building type
    model.getBuilding.setStandardsBuildingType(Constants.BuildingTypeMultifamily)

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

    result = Geometry.process_eaves(model, runner, eaves_depth, Constants.RoofStructureTrussCantilever)
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
    runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")

    return true
  end
end

# register the measure to be used by the application
CreateResidentialMultifamilyGeometry.new.registerWithApplication
