# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'util')
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'constructions')

# start the measure
class ProcessConstructionsWallsSteelStud < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Set Residential Walls - Steel Stud Construction'
  end

  # human readable description
  def description
    return "This measure assigns a steel stud construction to above-grade walls.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Calculates and assigns material layer properties of steel stud constructions for 1) exterior walls of finished spaces, 2) exterior walls (e.g. gable walls) of unfinished attics under roof insulation, and 3) interior walls (e.g., attic knee walls) between finished and unfinished spaces. Adds furniture & partition wall mass. Uninsulated constructions will also be assigned to 1) exterior walls of unfinished spaces, 2) interior walls between finished spaces, and 3) interior walls between unfinished spaces. Any existing constructions for these surfaces will be removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for nominal R-value of nominal cavity insulation
    cavity_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('cavity_r', true)
    cavity_r.setDisplayName('Cavity Insulation Nominal R-value')
    cavity_r.setUnits('hr-ft^2-R/Btu')
    cavity_r.setDescription('Refers to the R-value of the cavity insulation and not the overall R-value of the assembly.')
    cavity_r.setDefaultValue(13.0)
    args << cavity_r

    # make a choice argument for wall cavity insulation installation grade
    installgrade_display_names = OpenStudio::StringVector.new
    installgrade_display_names << '1'
    installgrade_display_names << '2'
    installgrade_display_names << '3'
    install_grade = OpenStudio::Measure::OSArgument::makeChoiceArgument('install_grade', installgrade_display_names, true)
    install_grade.setDisplayName('Cavity Install Grade')
    install_grade.setDescription('Installation grade as defined by RESNET standard. 5% of the cavity is considered missing insulation for Grade 3, 2% for Grade 2, and 0% for Grade 1.')
    install_grade.setDefaultValue('1')
    args << install_grade

    # make a double argument for wall cavity depth
    cavity_depth_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('cavity_depth_in', true)
    cavity_depth_in.setDisplayName('Cavity Depth')
    cavity_depth_in.setUnits('in')
    cavity_depth_in.setDescription('Depth of the stud cavity. 3.5" for 2x4s, 5.5" for 2x6s, etc.')
    cavity_depth_in.setDefaultValue('3.5')
    args << cavity_depth_in

    # make a bool argument for whether the cavity insulation fills the cavity
    cavity_filled = OpenStudio::Measure::OSArgument::makeBoolArgument('cavity_filled', true)
    cavity_filled.setDisplayName('Insulation Fills Cavity')
    cavity_filled.setDescription('When the insulation does not completely fill the depth of the cavity, air film resistances are added to the insulation R-value.')
    cavity_filled.setDefaultValue(true)
    args << cavity_filled

    # make a double argument for framing factor
    framing_factor = OpenStudio::Measure::OSArgument::makeDoubleArgument('framing_factor', true)
    framing_factor.setDisplayName('Framing Factor')
    framing_factor.setUnits('frac')
    framing_factor.setDescription('The fraction of a wall assembly that is comprised of structural framing.')
    framing_factor.setDefaultValue('0.25')
    args << framing_factor

    # make a double argument for correction factor
    correction_factor = OpenStudio::Measure::OSArgument::makeDoubleArgument('correction_factor', true)
    correction_factor.setDisplayName('Correction Factor')
    correction_factor.setDescription('The parallel path correction factor, as specified in Table C402.1.4.1 of the 2015 IECC as well as ASHRAE Standard 90.1, is used to determine the thermal resistance of wall assemblies containing metal framing.')
    correction_factor.setDefaultValue(0.46)
    args << correction_factor

    # make a double argument for drywall thickness
    drywall_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('drywall_thick_in', true)
    drywall_thick_in.setDisplayName('Drywall Thickness')
    drywall_thick_in.setUnits('in')
    drywall_thick_in.setDescription('Thickness of the drywall material.')
    drywall_thick_in.setDefaultValue(0.5)
    args << drywall_thick_in

    # make a double argument for OSB/Plywood Thickness
    osb_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('osb_thick_in', true)
    osb_thick_in.setDisplayName('OSB/Plywood Thickness')
    osb_thick_in.setUnits('in')
    osb_thick_in.setDescription("Specifies the thickness of the walls' OSB/plywood sheathing. Enter 0 for no sheathing (if the wall has other means to handle the shear load on the wall such as cross-bracing).")
    osb_thick_in.setDefaultValue(0.5)
    args << osb_thick_in

    # make a double argument for Rigid Insulation R-value
    rigid_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('rigid_r', true)
    rigid_r.setDisplayName('Continuous Insulation Nominal R-value')
    rigid_r.setUnits('h-ft^2-R/Btu')
    rigid_r.setDescription('The R-value of the continuous insulation.')
    rigid_r.setDefaultValue(0.0)
    args << rigid_r

    # make a choice argument for exterior finish material
    finishes = OpenStudio::StringVector.new
    WallConstructions.get_exterior_finish_materials.each do |mat|
      finishes << mat.name
    end
    exterior_finish = OpenStudio::Measure::OSArgument::makeChoiceArgument('exterior_finish', finishes, true)
    exterior_finish.setDisplayName('Exterior Finish')
    exterior_finish.setDescription('The exterior finish material.')
    exterior_finish.setDefaultValue(Material.ExtFinishVinylLight.name)
    args << exterior_finish

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    walls_by_type = SurfaceTypes.get_walls(model, runner)

    # Get inputs
    cavity_r = runner.getDoubleArgumentValue('cavity_r', user_arguments)
    install_grade = runner.getStringArgumentValue('install_grade', user_arguments).to_i
    cavity_depth_in = runner.getDoubleArgumentValue('cavity_depth_in', user_arguments)
    cavity_filled = runner.getBoolArgumentValue('cavity_filled', user_arguments)
    framing_factor = runner.getDoubleArgumentValue('framing_factor', user_arguments)
    correction_factor = runner.getDoubleArgumentValue('correction_factor', user_arguments)
    drywall_thick_in = runner.getDoubleArgumentValue('drywall_thick_in', user_arguments)
    osb_thick_in = runner.getDoubleArgumentValue('osb_thick_in', user_arguments)
    rigid_r = runner.getDoubleArgumentValue('rigid_r', user_arguments)
    mat_ext_finish = WallConstructions.get_exterior_finish_material(runner.getStringArgumentValue('exterior_finish', user_arguments))

    if mat_ext_finish.name.include?('None')
      runner.registerError("Steel stud walls cannot have a 'None' exterior finish")
      return false
    end

    # Apply constructions
    if not WallConstructions.apply_steel_stud(runner, model,
                                              walls_by_type[Constants.SurfaceTypeWallExtInsFin],
                                              Constants.SurfaceTypeWallExtInsFin,
                                              cavity_r, install_grade, cavity_depth_in,
                                              cavity_filled, framing_factor, correction_factor,
                                              drywall_thick_in, osb_thick_in, rigid_r,
                                              mat_ext_finish)
      return false
    end

    if not WallConstructions.apply_steel_stud(runner, model,
                                              walls_by_type[Constants.SurfaceTypeWallExtInsUnfin],
                                              Constants.SurfaceTypeWallExtInsUnfin,
                                              cavity_r, install_grade, cavity_depth_in,
                                              cavity_filled, framing_factor, correction_factor,
                                              0, osb_thick_in, rigid_r,
                                              mat_ext_finish)
      return false
    end

    if not WallConstructions.apply_steel_stud(runner, model,
                                              walls_by_type[Constants.SurfaceTypeWallIntFinInsUnfin],
                                              Constants.SurfaceTypeWallIntFinInsUnfin,
                                              cavity_r, install_grade, cavity_depth_in,
                                              cavity_filled, framing_factor, correction_factor,
                                              0, osb_thick_in, rigid_r,
                                              nil)
      return false
    end

    if not WallConstructions.apply_uninsulated(runner, model, walls_by_type,
                                               osb_thick_in, drywall_thick_in, mat_ext_finish)
      return false
    end

    if not ThermalMassConstructions.apply(runner, model, walls_by_type,
                                          drywall_thick_in)
      return false
    end

    # Remove any constructions/materials that aren't used
    HelperMethods.remove_unused_constructions_and_materials(model, runner)

    return true
  end
end

# register the measure to be used by the application
ProcessConstructionsWallsSteelStud.new.registerWithApplication
