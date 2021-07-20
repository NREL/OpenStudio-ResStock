# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'unit_conversions')

# start the measure
class SetResidentialWindowSkylightArea < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Set Residential Window/Skylight Area'
  end

  # human readable description
  def description
    return "Sets the window/skylight area for the building. Doors with glazing should be set as window area. Also, sets presence/dimensions of overhangs for windows on the specified building facade(s).#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Automatically creates and positions standard residential windows/skylights based on the specified window/skylight area on each building facade. Windows are only added to surfaces between finished space and outside. Any existing windows are removed. Also, creates overhang shading surfaces for windows on the specified building facade(s) and specified depth/offset. Any existing overhang shading surfaces are removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for front wwr
    front_wwr = OpenStudio::Measure::OSArgument::makeDoubleArgument('front_wwr', true)
    front_wwr.setDisplayName('Windows: Front Window-to-Wall Ratio')
    front_wwr.setDescription("The ratio of window area to wall area for the building's front facade. Enter 0 if specifying Front Window Area instead.")
    front_wwr.setDefaultValue(0.18)
    args << front_wwr

    # make a double argument for back wwr
    back_wwr = OpenStudio::Measure::OSArgument::makeDoubleArgument('back_wwr', true)
    back_wwr.setDisplayName('Back Window-to-Wall Ratio')
    back_wwr.setDescription("The ratio of window area to wall area for the building's back facade. Enter 0 if specifying Back Window Area instead.")
    back_wwr.setDefaultValue(0.18)
    args << back_wwr

    # make a double argument for left wwr
    left_wwr = OpenStudio::Measure::OSArgument::makeDoubleArgument('left_wwr', true)
    left_wwr.setDisplayName('Windows: Left Window-to-Wall Ratio')
    left_wwr.setDescription("The ratio of window area to wall area for the building's left facade. Enter 0 if specifying Left Window Area instead.")
    left_wwr.setDefaultValue(0.18)
    args << left_wwr

    # make a double argument for right wwr
    right_wwr = OpenStudio::Measure::OSArgument::makeDoubleArgument('right_wwr', true)
    right_wwr.setDisplayName('Windows: Right Window-to-Wall Ratio')
    right_wwr.setDescription("The ratio of window area to wall area for the building's right facade. Enter 0 if specifying Right Window Area instead.")
    right_wwr.setDefaultValue(0.18)
    args << right_wwr

    # make a double argument for front area
    front_window_area = OpenStudio::Measure::OSArgument::makeDoubleArgument('front_window_area', true)
    front_window_area.setDisplayName('Windows: Front Window Area')
    front_window_area.setDescription("The amount of window area on the building's front facade. Enter 0 if specifying Front Window-to-Wall Ratio instead.")
    front_window_area.setDefaultValue(0)
    args << front_window_area

    # make a double argument for back area
    back_window_area = OpenStudio::Measure::OSArgument::makeDoubleArgument('back_window_area', true)
    back_window_area.setDisplayName('Windows: Back Window Area')
    back_window_area.setDescription("The amount of window area on the building's back facade. Enter 0 if specifying Back Window-to-Wall Ratio instead.")
    back_window_area.setDefaultValue(0)
    args << back_window_area

    # make a double argument for left area
    left_window_area = OpenStudio::Measure::OSArgument::makeDoubleArgument('left_window_area', true)
    left_window_area.setDisplayName('Windows: Left Window Area')
    left_window_area.setDescription("The amount of window area on the building's left facade. Enter 0 if specifying Left Window-to-Wall Ratio instead.")
    left_window_area.setDefaultValue(0)
    args << left_window_area

    # make a double argument for right area
    right_window_area = OpenStudio::Measure::OSArgument::makeDoubleArgument('right_window_area', true)
    right_window_area.setDisplayName('Windows: Right Window Area')
    right_window_area.setDescription("The amount of window area on the building's right facade. Enter 0 if specifying Right Window-to-Wall Ratio instead.")
    right_window_area.setDefaultValue(0)
    args << right_window_area

    # make a double argument for aspect ratio
    window_aspect_ratio = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_aspect_ratio', true)
    window_aspect_ratio.setDisplayName('Windows: Aspect Ratio')
    window_aspect_ratio.setDescription('Ratio of window height to width.')
    window_aspect_ratio.setDefaultValue(1.333)
    args << window_aspect_ratio

    overhang_depth = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhang_depth', true)
    overhang_depth.setDisplayName('Overhangs: Depth')
    overhang_depth.setUnits('ft')
    overhang_depth.setDescription('Depth of the overhang. The distance from the wall surface in the direction normal to the wall surface.')
    overhang_depth.setDefaultValue(2.0)
    args << overhang_depth

    overhang_offset = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhang_offset', true)
    overhang_offset.setDisplayName('Overhangs: Offset')
    overhang_offset.setUnits('ft')
    overhang_offset.setDescription('Height of the overhangs above windows, relative to the top of the window framing.')
    overhang_offset.setDefaultValue(0.5)
    args << overhang_offset

    # TODO: addOverhang() sets WidthExtension=Offset*2.
    # width_extension = OpenStudio::Measure::OSArgument::makeDoubleArgument("width_extension", true)
    # width_extension.setDisplayName("Width Extension")
    # width_extension.setUnits("ft")
    # width_extension.setDescription("Length that the overhang extends beyond the window width, relative to the outside of the window framing.")
    # width_extension.setDefaultValue(1.0)
    # args << width_extension

    overhang_facade_bools = OpenStudio::StringVector.new
    overhang_facade_bools << 'Front Facade'
    overhang_facade_bools << 'Back Facade'
    overhang_facade_bools << 'Left Facade'
    overhang_facade_bools << 'Right Facade'
    overhang_facade_bools.each do |overhang_facade_bool|
      facade = overhang_facade_bool.split(' ')[0]
      arg = OpenStudio::Measure::OSArgument::makeBoolArgument('overhang_' + overhang_facade_bool.downcase.gsub(' ', '_'), true)
      arg.setDisplayName(overhang_facade_bool)
      arg.setDescription("Overhangs: Specifies the presence of overhangs for windows on the #{facade.downcase} facade.")
      arg.setDefaultValue(true)
      args << arg
    end

    # make a double argument for front area
    front_skylight_area = OpenStudio::Measure::OSArgument::makeDoubleArgument('front_skylight_area', true)
    front_skylight_area.setDisplayName('Skylights: Front Roof Area')
    front_skylight_area.setDescription("The amount of skylight area on the building's front finished roof facade.")
    front_skylight_area.setDefaultValue(0)
    args << front_skylight_area

    # make a double argument for back area
    back_skylight_area = OpenStudio::Measure::OSArgument::makeDoubleArgument('back_skylight_area', true)
    back_skylight_area.setDisplayName('Skylights: Back Roof Area')
    back_skylight_area.setDescription("The amount of skylight area on the building's back finished roof facade.")
    back_skylight_area.setDefaultValue(0)
    args << back_skylight_area

    # make a double argument for left area
    left_skylight_area = OpenStudio::Measure::OSArgument::makeDoubleArgument('left_skylight_area', true)
    left_skylight_area.setDisplayName('Skylights: Left Roof Area')
    left_skylight_area.setDescription("The amount of skylight area on the building's left finished roof facade.")
    left_skylight_area.setDefaultValue(0)
    args << left_skylight_area

    # make a double argument for right area
    right_skylight_area = OpenStudio::Measure::OSArgument::makeDoubleArgument('right_skylight_area', true)
    right_skylight_area.setDisplayName('Skylights: Right Roof Area')
    right_skylight_area.setDescription("The amount of skylight area on the building's right finished roof facade.")
    right_skylight_area.setDefaultValue(0)
    args << right_skylight_area

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    facades = [Constants.FacadeFront, Constants.FacadeBack, Constants.FacadeLeft, Constants.FacadeRight]

    wwrs = {}
    wwrs[Constants.FacadeFront] = runner.getDoubleArgumentValue('front_wwr', user_arguments)
    wwrs[Constants.FacadeBack] = runner.getDoubleArgumentValue('back_wwr', user_arguments)
    wwrs[Constants.FacadeLeft] = runner.getDoubleArgumentValue('left_wwr', user_arguments)
    wwrs[Constants.FacadeRight] = runner.getDoubleArgumentValue('right_wwr', user_arguments)
    window_areas = {}
    window_areas[Constants.FacadeFront] = runner.getDoubleArgumentValue('front_window_area', user_arguments)
    window_areas[Constants.FacadeBack] = runner.getDoubleArgumentValue('back_window_area', user_arguments)
    window_areas[Constants.FacadeLeft] = runner.getDoubleArgumentValue('left_window_area', user_arguments)
    window_areas[Constants.FacadeRight] = runner.getDoubleArgumentValue('right_window_area', user_arguments)
    window_aspect_ratio = runner.getDoubleArgumentValue('window_aspect_ratio', user_arguments)
    overhang_depth = UnitConversions.convert(runner.getDoubleArgumentValue('overhang_depth', user_arguments), 'ft', 'm')
    overhang_offset = UnitConversions.convert(runner.getDoubleArgumentValue('overhang_offset', user_arguments), 'ft', 'm')
    # width_extension = UnitConversions.convert(runner.getDoubleArgumentValue("width_extension",user_arguments), "ft", "m")
    overhang_facade_bools = OpenStudio::StringVector.new
    overhang_facade_bools << "#{Constants.FacadeFront} Facade"
    overhang_facade_bools << "#{Constants.FacadeBack} Facade"
    overhang_facade_bools << "#{Constants.FacadeLeft} Facade"
    overhang_facade_bools << "#{Constants.FacadeRight} Facade"
    overhang_facade_bools_hash = Hash.new
    overhang_facade_bools.each do |facade_bool|
      overhang_facade_bools_hash[facade_bool] = runner.getBoolArgumentValue('overhang_' + facade_bool.downcase.gsub(' ', '_'), user_arguments)
    end
    skylight_areas = {}
    skylight_areas[Constants.FacadeFront] = runner.getDoubleArgumentValue('front_skylight_area', user_arguments)
    skylight_areas[Constants.FacadeBack] = runner.getDoubleArgumentValue('back_skylight_area', user_arguments)
    skylight_areas[Constants.FacadeLeft] = runner.getDoubleArgumentValue('left_skylight_area', user_arguments)
    skylight_areas[Constants.FacadeRight] = runner.getDoubleArgumentValue('right_skylight_area', user_arguments)
    skylight_areas[Constants.FacadeNone] = 0

    # Remove existing windows and store surfaces that should get windows by facade
    wall_surfaces = { Constants.FacadeFront => [], Constants.FacadeBack => [],
                      Constants.FacadeLeft => [], Constants.FacadeRight => [] }
    roof_surfaces = { Constants.FacadeFront => [], Constants.FacadeBack => [],
                      Constants.FacadeLeft => [], Constants.FacadeRight => [],
                      Constants.FacadeNone => [] }
    # flat_roof_surfaces = []
    constructions = {}
    window_warn_msg = nil
    skylight_warn_msg = nil
    Geometry.get_finished_spaces(model.getSpaces).each do |space|
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
          facade = Geometry.get_facade_for_surface(surface)
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
          facade = Geometry.get_facade_for_surface(surface)
          if facade.nil?
            if surface.tilt == 0 # flat roof
              roof_surfaces[Constants.FacadeNone] << surface
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
    unless roof_surfaces[Constants.FacadeNone].empty?
      tot_sky_area = 0
      skylight_areas.each do |facade, skylight_area|
        next if facade == Constants.FacadeNone

        skylight_area /= roof_surfaces[Constants.FacadeNone].length
        skylight_areas[Constants.FacadeNone] += skylight_area
        skylight_areas[facade] = 0
      end
    end

    tot_sky_area = 0
    skylight_areas.each do |facade, skylight_area|
      next if skylight_area == 0

      surfaces = roof_surfaces[facade]
      if surfaces.empty? && (not facade == Constants.FacadeNone)
        runner.registerError("There are no #{facade} roof surfaces, but #{skylight_area} ft^2 of skylights were specified.")
        return false
      end

      surfaces.each do |surface|
        if (UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2') / Geometry.get_surface_length(surface)) > Geometry.get_surface_length(surface)
          skylight_aspect_ratio = Geometry.get_surface_length(surface) / (UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2') / Geometry.get_surface_length(surface)) # aspect ratio of the roof surface
        else
          skylight_aspect_ratio = (UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2') / Geometry.get_surface_length(surface)) / Geometry.get_surface_length(surface) # aspect ratio of the roof surface
        end

        skylight_width = Math.sqrt(UnitConversions.convert(skylight_area, 'ft^2', 'm^2') / skylight_aspect_ratio)
        skylight_length = UnitConversions.convert(skylight_area, 'ft^2', 'm^2') / skylight_width

        skylight_bottom_left = OpenStudio::getCentroid(surface.vertices).get
        leftx = skylight_bottom_left.x
        lefty = skylight_bottom_left.y
        bottomz = skylight_bottom_left.z
        if (facade == Constants.FacadeFront) || (facade == Constants.FacadeNone)
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

        runner.registerInfo("Added a skylight, totaling #{skylight_area.round(1)} ft^2, to #{surface.name}.")

        if not constructions[facade].nil?
          sub_surface.setConstruction(constructions[facade])
        end

        tot_sky_area += skylight_area
      end
    end

    if (tot_win_area == 0) && (tot_sky_area == 0)
      runner.registerFinalCondition('No windows or skylights added.')
      return true
    end

    if tot_win_area > 0
      result = Geometry.process_overhangs(model, runner, overhang_depth, overhang_offset, overhang_facade_bools_hash)
      unless result
        return false
      end
    end

    runner.registerFinalCondition("The building has been assigned #{tot_win_area.round(1)} ft^2 total window area, and #{tot_sky_area.round(1)} ft^2 total skylight area.")

    return true
  end

  def get_wall_area_for_windows(surface, min_wall_height_for_window, min_window_width, runner)
    # Skip surfaces with doors
    if surface.subSurfaces.size > 0
      return 0.0
    end

    # Only allow on gable and rectangular walls
    if not (Geometry.is_rectangular_wall(surface) || Geometry.is_gable_wall(surface))
      return 0.0
    end

    # Can't fit the smallest window?
    if Geometry.get_surface_length(surface) < min_window_width
      return 0.0
    end

    # Wall too short?
    if min_wall_height_for_window > Geometry.get_surface_height(surface)
      return 0.0
    end

    # Gable too short?
    # TODO: super crude safety factor of 1.5
    if Geometry.is_gable_wall(surface) && (min_wall_height_for_window > Geometry.get_surface_height(surface) / 1.5)
      return 0.0
    end

    return UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2')
  end

  def add_windows_to_wall(surface, window_area, window_gap_y, window_gap_x, window_aspect_ratio, max_single_window_area, facade, constructions, model, runner)
    wall_width = Geometry.get_surface_length(surface)
    wall_height = Geometry.get_surface_height(surface)

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
    if Geometry.is_gable_wall(surface)
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
    runner.registerInfo("Added #{num_windows} window(s), totaling #{window_area.round(1)} ft^2, to #{surface.name}.")
    return true
  end

  def add_window_to_wall(surface, win_width, win_height, win_center_x, win_center_y, win_num, facade, constructions, model, runner)
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
      leftx = Geometry.getSurfaceXValues([surface]).max
      lefty = Geometry.getSurfaceYValues([surface]).max
    else
      leftx = Geometry.getSurfaceXValues([surface]).min
      lefty = Geometry.getSurfaceYValues([surface]).min
    end
    bottomz = Geometry.getSurfaceZValues([surface]).min
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
end

# register the measure to be used by the application
SetResidentialWindowSkylightArea.new.registerWithApplication
