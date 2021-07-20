# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'util')
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'constructions')

# start the measure
class ProcessConstructionsCrawlspace < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Crawlspace Constructions'
  end

  def description
    return "This measure assigns constructions to the crawlspace ceilings, walls, and floors.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Calculates and assigns material layer properties of constructions for crawlspace: 1) ceilings, 2) walls, and 3) floors. Any existing constructions for these surfaces will be removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for wall continuous insulation R-value
    wall_rigid_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('wall_rigid_r', true)
    wall_rigid_r.setDisplayName('Wall Continuous Insulation Nominal R-value')
    wall_rigid_r.setUnits('hr-ft^2-R/Btu')
    wall_rigid_r.setDescription('The R-value of the continuous insulation.')
    wall_rigid_r.setDefaultValue(10.0)
    args << wall_rigid_r

    # make a double argument for ceiling cavity R-value
    ceiling_cavity_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_cavity_r', true)
    ceiling_cavity_r.setDisplayName('Ceiling Cavity Insulation Nominal R-value')
    ceiling_cavity_r.setUnits('h-ft^2-R/Btu')
    ceiling_cavity_r.setDescription('Refers to the R-value of the cavity insulation and not the overall R-value of the assembly.')
    ceiling_cavity_r.setDefaultValue(0)
    args << ceiling_cavity_r

    # make a choice argument for ceiling cavity insulation installation grade
    installgrade_display_names = OpenStudio::StringVector.new
    installgrade_display_names << '1'
    installgrade_display_names << '2'
    installgrade_display_names << '3'
    ceiling_install_grade = OpenStudio::Measure::OSArgument::makeChoiceArgument('ceiling_install_grade', installgrade_display_names, true)
    ceiling_install_grade.setDisplayName('Ceiling Cavity Install Grade')
    ceiling_install_grade.setDescription('Installation grade as defined by RESNET standard. 5% of the cavity is considered missing insulation for Grade 3, 2% for Grade 2, and 0% for Grade 1.')
    ceiling_install_grade.setDefaultValue('1')
    args << ceiling_install_grade

    # make a choice argument for ceiling framing factor
    ceiling_framing_factor = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_framing_factor', true)
    ceiling_framing_factor.setDisplayName('Ceiling Framing Factor')
    ceiling_framing_factor.setUnits('frac')
    ceiling_framing_factor.setDescription('Fraction of ceiling that is framing.')
    ceiling_framing_factor.setDefaultValue(0.13)
    args << ceiling_framing_factor

    # make a choice argument for ceiling joist height
    ceiling_joist_height_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_joist_height_in', true)
    ceiling_joist_height_in.setDisplayName('Ceiling Joist Height')
    ceiling_joist_height_in.setUnits('in')
    ceiling_joist_height_in.setDescription('Height of the joist member.')
    ceiling_joist_height_in.setDefaultValue(9.25)
    args << ceiling_joist_height_in

    # make a double argument for slab insulation R-value
    slab_whole_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('slab_whole_r', true)
    slab_whole_r.setDisplayName('Whole Slab Insulation Nominal R-value')
    slab_whole_r.setUnits('h-ft^2-R/Btu')
    slab_whole_r.setDescription('The R-value of the continuous insulation.')
    slab_whole_r.setDefaultValue(0)
    args << slab_whole_r

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    walls_by_type = SurfaceTypes.get_walls(model, runner)
    floors_by_type = SurfaceTypes.get_floors(model, runner)

    # Get Inputs
    wall_rigid_r = runner.getDoubleArgumentValue('wall_rigid_r', user_arguments)
    ceiling_cavity_r = runner.getDoubleArgumentValue('ceiling_cavity_r', user_arguments)
    ceiling_install_grade = runner.getStringArgumentValue('ceiling_install_grade', user_arguments).to_i
    ceiling_framing_factor = runner.getDoubleArgumentValue('ceiling_framing_factor', user_arguments)
    ceiling_joist_height_in = runner.getDoubleArgumentValue('ceiling_joist_height_in', user_arguments)
    slab_whole_r = runner.getDoubleArgumentValue('slab_whole_r', user_arguments)

    spaces = Geometry.get_crawl_spaces(model.getSpaces)
    crawl_height = Geometry.spaces_avg_height(spaces)

    # Apply constructions
    floors_by_type[Constants.SurfaceTypeFloorFndGrndCS].each do |floor_surface|
      wall_surfaces = Geometry.get_walls_connected_to_floor(walls_by_type[Constants.SurfaceTypeWallFndGrndCS],
                                                            floor_surface)
      if not FoundationConstructions.apply_walls_and_slab(runner, model,
                                                          wall_surfaces,
                                                          Constants.SurfaceTypeWallFndGrndCS,
                                                          crawl_height, 0, 1, 0, true, 0,
                                                          wall_rigid_r, 0, 8.0, crawl_height,
                                                          floor_surface,
                                                          Constants.SurfaceTypeFloorFndGrndCS,
                                                          slab_whole_r, 4.0)
        return false
      end
    end

    if not FloorConstructions.apply_foundation_ceiling(runner, model,
                                                       floors_by_type[Constants.SurfaceTypeFloorCSInsFin],
                                                       Constants.SurfaceTypeFloorCSInsFin,
                                                       ceiling_cavity_r, ceiling_install_grade,
                                                       ceiling_framing_factor, ceiling_joist_height_in,
                                                       0.75, Material.FloorWood, Material.CoveringBare)
      return false
    end

    floors_by_type[Constants.SurfaceTypeFloorFndGrndUnfinSlab].each do |surface|
      if not FoundationConstructions.apply_slab(runner, model,
                                                surface,
                                                Constants.SurfaceTypeFloorFndGrndUnfinSlab,
                                                0, 0, 0, 0, 0, 0, 4.0, nil, false, nil, nil)
        return false
      end
    end

    # Remove any constructions/materials that aren't used
    HelperMethods.remove_unused_constructions_and_materials(model, runner)

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ProcessConstructionsCrawlspace.new.registerWithApplication
