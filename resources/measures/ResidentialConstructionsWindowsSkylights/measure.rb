# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'util')
require File.join(resources_path, 'constants')
require File.join(resources_path, 'weather')
require File.join(resources_path, 'hvac')
require File.join(resources_path, 'constructions')

# start the measure
class ProcessConstructionsWindowsSkylights < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Window/Skylight Construction'
  end

  def description
    return "This measure assigns a construction to windows/skylights. This measure also creates the interior shading schedule, which is based on shade multipliers and the heating and cooling season logic defined in the Building America House Simulation Protocols.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Calculates material layer properties of constructions for windows/skylights. Finds sub-surfaces and sets applicable constructions. Using interior heating and cooling shading multipliers and the Building America heating and cooling season logic, creates schedule rulesets for window shade and shading control.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make an argument for entering front window u-factor
    window_ufactor = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_ufactor', true)
    window_ufactor.setDisplayName('Windows: U-Factor')
    window_ufactor.setUnits('Btu/hr-ft^2-R')
    window_ufactor.setDescription('The heat transfer coefficient of the windows.')
    window_ufactor.setDefaultValue(0.37)
    args << window_ufactor

    # make an argument for entering front window shgc
    window_shgc = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_shgc', true)
    window_shgc.setDisplayName('Windows: SHGC')
    window_shgc.setDescription('The ratio of solar heat gain through a glazing system compared to that of an unobstructed opening, for windows.')
    window_shgc.setDefaultValue(0.3)
    args << window_shgc

    # make an argument for entering heating shade multiplier
    window_heat_shade_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_heat_shade_mult', true)
    window_heat_shade_mult.setDisplayName('Windows: Heating Shade Multiplier')
    window_heat_shade_mult.setDescription('Interior shading multiplier for heating season. 1.0 indicates no reduction in solar gain, 0.85 indicates 15% reduction, etc.')
    window_heat_shade_mult.setDefaultValue(0.7)
    args << window_heat_shade_mult

    # make an argument for entering cooling shade multiplier
    window_cool_shade_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_cool_shade_mult', true)
    window_cool_shade_mult.setDisplayName('Windows: Cooling Shade Multiplier')
    window_cool_shade_mult.setDescription('Interior shading multiplier for cooling season. 1.0 indicates no reduction in solar gain, 0.85 indicates 15% reduction, etc.')
    window_cool_shade_mult.setDefaultValue(0.7)
    args << window_cool_shade_mult

    # make an argument for entering front window u-factor
    skylight_ufactor = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_ufactor', true)
    skylight_ufactor.setDisplayName('Skylights: U-Factor')
    skylight_ufactor.setUnits('Btu/hr-ft^2-R')
    skylight_ufactor.setDescription('The heat transfer coefficient of the skylights.')
    skylight_ufactor.setDefaultValue(0.33)
    args << skylight_ufactor

    # make an argument for entering front window shgc
    skylight_shgc = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_shgc', true)
    skylight_shgc.setDisplayName('Skylights: SHGC')
    skylight_shgc.setDescription('The ratio of solar heat gain through a glazing system compared to that of an unobstructed opening, for skylights.')
    skylight_shgc.setDefaultValue(0.45)
    args << skylight_shgc

    # make an argument for entering heating shade multiplier
    skylight_heat_shade_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_heat_shade_mult', true)
    skylight_heat_shade_mult.setDisplayName('Skylights: Heating Shade Multiplier')
    skylight_heat_shade_mult.setDescription('Interior shading multiplier for heating season. 1.0 indicates no reduction in solar gain, 0.85 indicates 15% reduction, etc.')
    skylight_heat_shade_mult.setDefaultValue(1.0)
    args << skylight_heat_shade_mult

    # make an argument for entering cooling shade multiplier
    skylight_cool_shade_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_cool_shade_mult', true)
    skylight_cool_shade_mult.setDisplayName('Skylights: Cooling Shade Multiplier')
    skylight_cool_shade_mult.setDescription('Interior shading multiplier for cooling season. 1.0 indicates no reduction in solar gain, 0.85 indicates 15% reduction, etc.')
    skylight_cool_shade_mult.setDefaultValue(1.0)
    args << skylight_cool_shade_mult

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    window_ufactor = runner.getDoubleArgumentValue('window_ufactor', user_arguments)
    window_shgc = runner.getDoubleArgumentValue('window_shgc', user_arguments)
    window_heat_shade_mult = runner.getDoubleArgumentValue('window_heat_shade_mult', user_arguments)
    window_cool_shade_mult = runner.getDoubleArgumentValue('window_cool_shade_mult', user_arguments)
    skylight_ufactor = runner.getDoubleArgumentValue('skylight_ufactor', user_arguments)
    skylight_shgc = runner.getDoubleArgumentValue('skylight_shgc', user_arguments)
    skylight_heat_shade_mult = runner.getDoubleArgumentValue('skylight_heat_shade_mult', user_arguments)
    skylight_cool_shade_mult = runner.getDoubleArgumentValue('skylight_cool_shade_mult', user_arguments)

    weather = WeatherProcess.new(model, runner)
    if weather.error?
      return false
    end

    heating_season, cooling_season = HVAC.calc_heating_and_cooling_seasons(model, weather, runner)
    if heating_season.nil? || cooling_season.nil?
      return false
    end

    if (window_heat_shade_mult < 0) || (window_heat_shade_mult > 1)
      runner.registerError('Window Heating Shade Multiplier must be greater than or equal to zero and less than or equal to one.')
      return false
    end
    if (window_cool_shade_mult < 0) || (window_cool_shade_mult > 1)
      runner.registerError('Window Cooling Shade Multiplier must be greater than or equal to zero and less than or equal to one.')
      return false
    end
    if (skylight_heat_shade_mult < 0) || (skylight_heat_shade_mult > 1)
      runner.registerError('Skylight Heating Shade Multiplier must be greater than or equal to zero and less than or equal to one.')
      return false
    end
    if (skylight_cool_shade_mult < 0) || (skylight_cool_shade_mult > 1)
      runner.registerError('Skylight Cooling Shade Multiplier must be greater than or equal to zero and less than or equal to one.')
      return false
    end

    window_subsurfaces = []
    skylight_subsurfaces = []
    model.getSubSurfaces.each do |subsurface|
      if subsurface.subSurfaceType.downcase.include? 'window'
        window_subsurfaces << subsurface
        subsurface.additionalProperties.setFeature(Constants.SizingInfoWindowSummerShadingFactor, window_cool_shade_mult.to_f)
      elsif subsurface.subSurfaceType.downcase.include? 'skylight'
        skylight_subsurfaces << subsurface
        subsurface.additionalProperties.setFeature(Constants.SizingInfoWindowSummerShadingFactor, skylight_cool_shade_mult.to_f)
      end
    end

    # Remove any existing window/skylight shading
    model.getShadingSurfaceGroups.each do |shading_group|
      next unless shading_group.name.to_s == 'window and skylight shading group'

      shading_group.remove
    end
    model.getSchedules.each do |schedule|
      next unless ['window shading schedule', 'skylight shading schedule'].include? schedule.name.to_s

      schedule.remove
    end

    shading_group = nil

    # Apply constructions
    if not SubsurfaceConstructions.apply_window(runner, model, window_subsurfaces, 'WindowConstruction', window_ufactor, window_shgc)
      return false
    end

    # Apply interior shading (as needed)
    if (window_cool_shade_mult < 1.0) || (window_heat_shade_mult < 1.0)
      window_schedule = nil
      window_subsurfaces.each do |sub_surface|
        trans_values = cooling_season.map { |c| c == 1 ? window_cool_shade_mult : window_heat_shade_mult }
        if window_schedule.nil?
          window_schedule = MonthWeekdayWeekendSchedule.new(model, runner, 'window shading schedule', Array.new(24, 1), Array.new(24, 1), trans_values, 1.0, 1.0, false)
        end
        shading_group = apply_interior_shading(model, sub_surface, shading_group, window_schedule, trans_values)
      end
    end

    # Apply constructions
    if not SubsurfaceConstructions.apply_skylight(runner, model, skylight_subsurfaces, 'SkylightConstruction', skylight_ufactor, skylight_shgc)
      return false
    end

    # Apply interior shading (as needed)
    if (skylight_cool_shade_mult < 1.0) || (skylight_heat_shade_mult < 1.0)
      skylight_schedule = nil
      skylight_subsurfaces.each do |sub_surface|
        trans_values = cooling_season.map { |c| c == 1 ? skylight_cool_shade_mult : skylight_heat_shade_mult }
        if skylight_schedule.nil?
          skylight_schedule = MonthWeekdayWeekendSchedule.new(model, runner, 'skylight shading schedule', Array.new(24, 1), Array.new(24, 1), trans_values, 1.0, 1.0, false)
        end
        shading_group = apply_interior_shading(model, sub_surface, shading_group, skylight_schedule, trans_values)
      end
    end

    # Remove any constructions/materials that aren't used
    HelperMethods.remove_unused_constructions_and_materials(model, runner)

    # Reporting
    runner.registerFinalCondition('All windows and skylights have been assigned constructions.')

    return true
  end # end the run method

  def apply_interior_shading(model, sub_surface, shading_group, shading_schedule, trans_values)
    # We use a ShadingSurface instead of a Shade so that we perfectly get the result we want.
    # The latter object is complex and it is essentially impossible to achieve the target reduction in transmitted
    # solar (due to, e.g., re-reflectance, absorptance, angle modifiers, effects on convection, etc.).

    # Shading surface is used to reduce beam solar and sky diffuse solar
    vertices = OpenStudio::Point3dVector.new
    space = sub_surface.surface.get.space.get
    sub_surface.vertices.each do |v|
      vertices << OpenStudio::Point3d.new(v.x + space.xOrigin, v.y + space.yOrigin, v.z + space.zOrigin)
    end
    shading_surface = OpenStudio::Model::ShadingSurface.new(vertices, model)
    shading_surface.setName("#{sub_surface.name} shading surface")

    # Create transmittance schedule for heating/cooling seasons
    shading_surface.setTransmittanceSchedule(shading_schedule.schedule)

    # Adjustment to default view factor is used to reduce ground diffuse solar
    parent_surface = sub_surface.surface.get
    avg_trans_value = trans_values.sum(0.0) / 12.0
    default_vf_to_ground = ((1.0 - Math::cos(parent_surface.tilt)) / 2.0).round(2)
    sub_surface.setViewFactortoGround(default_vf_to_ground * avg_trans_value)

    if shading_group.nil?
      shading_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
      shading_group.setName('window and skylight shading group')
    end
    shading_surface.setShadingSurfaceGroup(shading_group)
    return shading_group
  end
end # end the measure

# this allows the measure to be use by the application
ProcessConstructionsWindowsSkylights.new.registerWithApplication
