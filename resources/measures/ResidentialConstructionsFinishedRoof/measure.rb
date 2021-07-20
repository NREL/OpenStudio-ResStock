# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'util')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'constructions')

# start the measure
class ProcessConstructionsFinishedRoof < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Finished Roof Construction'
  end

  def description
    return "This measure assigns a construction to finished roofs.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Calculates and assigns material layer properties of constructions for roofs above finished space. Any existing constructions for these surfaces will be removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for finished roof insulation R-value
    cavity_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('cavity_r', true)
    cavity_r.setDisplayName('Cavity Insulation Installed R-value')
    cavity_r.setUnits('hr-ft^2-R/Btu')
    cavity_r.setDescription('Refers to the R-value of the cavity insulation and not the overall R-value of the assembly. If batt insulation must be compressed to fit within the cavity (e.g., R19 in a 5.5" 2x6 cavity), use an R-value that accounts for this effect (see HUD Mobile Home Construction and Safety Standards 3280.509 for reference).')
    cavity_r.setDefaultValue(30.0)
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
    cavity_depth = OpenStudio::Measure::OSArgument::makeDoubleArgument('cavity_depth', true)
    cavity_depth.setDisplayName('Cavity Depth')
    cavity_depth.setUnits('in')
    cavity_depth.setDescription('Depth of the roof cavity. 3.5" for 2x4s, 5.5" for 2x6s, etc.')
    cavity_depth.setDefaultValue(9.25)
    args << cavity_depth

    # make a bool argument for whether the cavity insulation fills the cavity
    filled_cavity = OpenStudio::Measure::OSArgument::makeBoolArgument('filled_cavity', true)
    filled_cavity.setDisplayName('Insulation Fills Cavity')
    filled_cavity.setDescription('When the insulation does not completely fill the depth of the cavity, air film resistances are added to the insulation R-value.')
    filled_cavity.setDefaultValue(false)
    args << filled_cavity

    # make a choice argument for finished roof framing factor
    framing_factor = OpenStudio::Measure::OSArgument::makeDoubleArgument('framing_factor', true)
    framing_factor.setDisplayName('Framing Factor')
    framing_factor.setUnits('frac')
    framing_factor.setDescription('The framing factor of the finished roof.')
    framing_factor.setDefaultValue(0.07)
    args << framing_factor

    # make a double argument for roof drywall thickness
    drywall_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('drywall_thick_in', true)
    drywall_thick_in.setDisplayName('Drywall Thickness')
    drywall_thick_in.setUnits('in')
    drywall_thick_in.setDescription('Thickness of the drywall material.')
    drywall_thick_in.setDefaultValue(0.5)
    args << drywall_thick_in

    # make a double argument for roof osb/plywood thickness
    osb_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('osb_thick_in', true)
    osb_thick_in.setDisplayName('Roof OSB/Plywood Thickness')
    osb_thick_in.setUnits('in')
    osb_thick_in.setDescription('Specifies the thickness of the roof OSB/plywood sheathing. Enter 0 for no sheathing.')
    osb_thick_in.setDefaultValue(0.75)
    args << osb_thick_in

    # make a double argument for roof rigid insulation r-value
    rigid_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('rigid_r', true)
    rigid_r.setDisplayName('Roof Continuous Insulation Nominal R-value')
    rigid_r.setUnits('h-ft^2-R/Btu')
    rigid_r.setDescription('The R-value of the roof continuous insulation.')
    rigid_r.setDefaultValue(0.0)
    args << rigid_r

    # make a choice argument for roofing material
    roofings = OpenStudio::StringVector.new
    RoofConstructions.get_roofing_materials.each do |mat|
      roofings << mat.name
    end
    roofing_material = OpenStudio::Measure::OSArgument::makeChoiceArgument('roofing_material', roofings, true)
    roofing_material.setDisplayName('Roofing Material')
    roofing_material.setDescription('The roofing material.')
    roofing_material.setDefaultValue(Material.RoofingAsphaltShinglesMed.name)
    args << roofing_material

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    roofs_by_type = SurfaceTypes.get_roofs(model, runner)

    # Get Inputs
    cavity_r = runner.getDoubleArgumentValue('cavity_r', user_arguments)
    install_grade = runner.getStringArgumentValue('install_grade', user_arguments).to_i
    cavity_depth = runner.getDoubleArgumentValue('cavity_depth', user_arguments)
    filled_cavity = runner.getBoolArgumentValue('filled_cavity', user_arguments)
    framing_factor = runner.getDoubleArgumentValue('framing_factor', user_arguments)
    drywall_thick_in = runner.getDoubleArgumentValue('drywall_thick_in', user_arguments)
    osb_thick_in = runner.getDoubleArgumentValue('osb_thick_in', user_arguments)
    rigid_r = runner.getDoubleArgumentValue('rigid_r', user_arguments)
    mat_roofing = RoofConstructions.get_roofing_material(runner.getStringArgumentValue('roofing_material', user_arguments))

    # Apply constructions
    if not RoofConstructions.apply_finished_roof(runner, model,
                                                 roofs_by_type[Constants.SurfaceTypeRoofFinInsExt],
                                                 Constants.SurfaceTypeRoofFinInsExt,
                                                 cavity_r, install_grade, cavity_depth,
                                                 filled_cavity, framing_factor, drywall_thick_in,
                                                 osb_thick_in, rigid_r, mat_roofing)
      return false
    end

    if not RoofConstructions.apply_uninsulated_roofs(runner, model,
                                                     roofs_by_type[Constants.SurfaceTypeRoofUnfinUninsExt],
                                                     Constants.SurfaceTypeRoofUnfinUninsExt,
                                                     cavity_depth, framing_factor,
                                                     osb_thick_in, mat_roofing)
      return false
    end

    # Adiabatic roofs (shared surface with above floor)
    if not FloorConstructions.apply_uninsulated(runner, model,
                                                roofs_by_type[Constants.SurfaceTypeRoofAdiabatic],
                                                Constants.SurfaceTypeRoofAdiabatic,
                                                0.75, 0.5, Material.FloorWood, Material.CoveringBare)
      return false
    end

    # end

    # Remove any constructions/materials that aren't used
    HelperMethods.remove_unused_constructions_and_materials(model, runner)

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ProcessConstructionsFinishedRoof.new.registerWithApplication
