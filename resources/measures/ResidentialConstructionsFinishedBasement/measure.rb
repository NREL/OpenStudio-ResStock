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
class ProcessConstructionsFinishedBasement < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Finished Basement Constructions'
  end

  def description
    return "This measure assigns constructions to finished basement walls and floors.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Calculates and assigns material layer properties of constructions for finished basement: 1) walls, and 2) floors. Any existing constructions for these surfaces will be removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for wall insulation height
    wall_ins_height = OpenStudio::Measure::OSArgument::makeDoubleArgument('wall_ins_height', true)
    wall_ins_height.setDisplayName('Wall Insulation Height')
    wall_ins_height.setUnits('ft')
    wall_ins_height.setDescription('Height of the insulation on the basement wall.')
    wall_ins_height.setDefaultValue(8)
    args << wall_ins_height

    # make a double argument for wall cavity R-value
    wall_cavity_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('wall_cavity_r', true)
    wall_cavity_r.setDisplayName('Wall Cavity Insulation Installed R-value')
    wall_cavity_r.setUnits('h-ft^2-R/Btu')
    wall_cavity_r.setDescription('Refers to the R-value of the cavity insulation as installed and not the overall R-value of the assembly. If batt insulation must be compressed to fit within the cavity (e.g. R19 in a 5.5" 2x6 cavity), use an R-value that accounts for this effect (see HUD Mobile Home Construction and Safety Standards 3280.509 for reference).')
    wall_cavity_r.setDefaultValue(0)
    args << wall_cavity_r

    # make a choice argument for wall cavity insulation installation grade
    installgrade_display_names = OpenStudio::StringVector.new
    installgrade_display_names << '1'
    installgrade_display_names << '2'
    installgrade_display_names << '3'
    wall_install_grade = OpenStudio::Measure::OSArgument::makeChoiceArgument('wall_install_grade', installgrade_display_names, true)
    wall_install_grade.setDisplayName('Wall Cavity Install Grade')
    wall_install_grade.setDescription('Installation grade as defined by RESNET standard. 5% of the cavity is considered missing insulation for Grade 3, 2% for Grade 2, and 0% for Grade 1.')
    wall_install_grade.setDefaultValue('1')
    args << wall_install_grade

    # make a double argument for wall cavity depth
    wall_cavity_depth_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('wall_cavity_depth_in', true)
    wall_cavity_depth_in.setDisplayName('Wall Cavity Depth')
    wall_cavity_depth_in.setUnits('in')
    wall_cavity_depth_in.setDescription('Depth of the stud cavity. 3.5" for 2x4s, 5.5" for 2x6s, etc.')
    wall_cavity_depth_in.setDefaultValue(0)
    args << wall_cavity_depth_in

    # make a bool argument for whether the cavity insulation fills the wall cavity
    wall_filled_cavity = OpenStudio::Measure::OSArgument::makeBoolArgument('wall_filled_cavity', true)
    wall_filled_cavity.setDisplayName('Wall Insulation Fills Cavity')
    wall_filled_cavity.setDescription('When the insulation does not completely fill the depth of the cavity, air film resistances are added to the insulation R-value.')
    wall_filled_cavity.setDefaultValue(false)
    args << wall_filled_cavity

    # make a double argument for wall framing factor
    wall_framing_factor = OpenStudio::Measure::OSArgument::makeDoubleArgument('wall_framing_factor', true)
    wall_framing_factor.setDisplayName('Wall Framing Factor')
    wall_framing_factor.setUnits('frac')
    wall_framing_factor.setDescription('The fraction of a basement wall assembly that is comprised of structural framing.')
    wall_framing_factor.setDefaultValue(0)
    args << wall_framing_factor

    # make a double argument for wall continuous insulation R-value
    wall_rigid_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('wall_rigid_r', true)
    wall_rigid_r.setDisplayName('Wall Continuous Insulation Nominal R-value')
    wall_rigid_r.setUnits('hr-ft^2-R/Btu')
    wall_rigid_r.setDescription('The R-value of the continuous insulation.')
    wall_rigid_r.setDefaultValue(10.0)
    args << wall_rigid_r

    # make a double argument for wall drywall thickness
    wall_drywall_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('wall_drywall_thick_in', true)
    wall_drywall_thick_in.setDisplayName('Wall Drywall Thickness')
    wall_drywall_thick_in.setUnits('in')
    wall_drywall_thick_in.setDescription('Thickness of the wall drywall material.')
    wall_drywall_thick_in.setDefaultValue(0.5)
    args << wall_drywall_thick_in

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
    wall_ins_height = runner.getDoubleArgumentValue('wall_ins_height', user_arguments)
    wall_cavity_r = runner.getDoubleArgumentValue('wall_cavity_r', user_arguments)
    wall_install_grade = runner.getStringArgumentValue('wall_install_grade', user_arguments).to_i
    wall_cavity_depth_in = runner.getDoubleArgumentValue('wall_cavity_depth_in', user_arguments)
    wall_filled_cavity = runner.getBoolArgumentValue('wall_filled_cavity', user_arguments)
    wall_framing_factor = runner.getDoubleArgumentValue('wall_framing_factor', user_arguments)
    wall_rigid_r = runner.getDoubleArgumentValue('wall_rigid_r', user_arguments)
    wall_drywall_thick_in = runner.getDoubleArgumentValue('wall_drywall_thick_in', user_arguments)
    slab_whole_r = runner.getDoubleArgumentValue('slab_whole_r', user_arguments)

    spaces = Geometry.get_finished_basement_spaces(model.getSpaces)
    basement_height = Geometry.spaces_avg_height(spaces)

    # Apply constructions
    floors_by_type[Constants.SurfaceTypeFloorFndGrndFinB].each do |floor_surface|
      wall_surfaces = Geometry.get_walls_connected_to_floor(walls_by_type[Constants.SurfaceTypeWallFndGrndFinB],
                                                            floor_surface)
      if not FoundationConstructions.apply_walls_and_slab(runner, model,
                                                          wall_surfaces,
                                                          Constants.SurfaceTypeWallFndGrndFinB,
                                                          wall_ins_height, wall_cavity_r, wall_install_grade,
                                                          wall_cavity_depth_in, wall_filled_cavity,
                                                          wall_framing_factor, wall_rigid_r, wall_drywall_thick_in,
                                                          8.0, basement_height,
                                                          floor_surface,
                                                          Constants.SurfaceTypeFloorFndGrndFinB,
                                                          slab_whole_r, 4.0)
        return false
      end
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
ProcessConstructionsFinishedBasement.new.registerWithApplication
