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
class ProcessConstructionsUnfinishedAttic < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Unfinished Attic Constructions'
  end

  def description
    return "This measure assigns constructions to unfinished attic floors and roofs.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Calculates and assigns material layer properties of constructions for unfinished attic: 1) floors and 2) roofs. Uninsulated constructions will also be assigned to other roofs over unfinished space. Any existing constructions for these surfaces will be removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for ceiling R-value
    ceiling_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_r', true)
    ceiling_r.setDisplayName('Ceiling Insulation Nominal R-value')
    ceiling_r.setUnits('h-ft^2-R/Btu')
    ceiling_r.setDescription('Refers to the R-value of the insulation and not the overall R-value of the assembly.')
    ceiling_r.setDefaultValue(30)
    args << ceiling_r

    # make a choice argument for ceiling insulation installation grade
    installgrade_display_names = OpenStudio::StringVector.new
    installgrade_display_names << '1'
    installgrade_display_names << '2'
    installgrade_display_names << '3'
    ceiling_install_grade = OpenStudio::Measure::OSArgument::makeChoiceArgument('ceiling_install_grade', installgrade_display_names, true)
    ceiling_install_grade.setDisplayName('Ceiling Install Grade')
    ceiling_install_grade.setDescription('Installation grade as defined by RESNET standard. 5% of the cavity is considered missing insulation for Grade 3, 2% for Grade 2, and 0% for Grade 1.')
    ceiling_install_grade.setDefaultValue('1')
    args << ceiling_install_grade

    # make a choice argument for ceiling insulation thickness
    ceiling_ins_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_ins_thick_in', true)
    ceiling_ins_thick_in.setDisplayName('Ceiling Insulation Thickness')
    ceiling_ins_thick_in.setUnits('in')
    ceiling_ins_thick_in.setDescription('The thickness in inches of insulation required to obtain the specified R-value.')
    ceiling_ins_thick_in.setDefaultValue(8.55)
    args << ceiling_ins_thick_in

    # make a choice argument for ceiling framing factor
    ceiling_framing_factor = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_framing_factor', true)
    ceiling_framing_factor.setDisplayName('Ceiling Framing Factor')
    ceiling_framing_factor.setUnits('frac')
    ceiling_framing_factor.setDescription('Fraction of ceiling that is framing.')
    ceiling_framing_factor.setDefaultValue(0.07)
    args << ceiling_framing_factor

    # make a choice argument for ceiling joist height
    ceiling_joist_height_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_joist_height_in', true)
    ceiling_joist_height_in.setDisplayName('Ceiling Joist Height')
    ceiling_joist_height_in.setUnits('in')
    ceiling_joist_height_in.setDescription('Height of the joist member.')
    ceiling_joist_height_in.setDefaultValue(3.5)
    args << ceiling_joist_height_in

    # make a double argument for ceiling drywall thickness
    ceiling_drywall_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_drywall_thick_in', true)
    ceiling_drywall_thick_in.setDisplayName('Ceiling Drywall Thickness')
    ceiling_drywall_thick_in.setUnits('in')
    ceiling_drywall_thick_in.setDescription('Thickness of the ceiling drywall material.')
    ceiling_drywall_thick_in.setDefaultValue(0.5)
    args << ceiling_drywall_thick_in

    # make a double argument for roof cavity R-value
    roof_cavity_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('roof_cavity_r', true)
    roof_cavity_r.setDisplayName('Roof Cavity Insulation Nominal R-value')
    roof_cavity_r.setUnits('h-ft^2-R/Btu')
    roof_cavity_r.setDescription('Refers to the R-value of the cavity insulation and not the overall R-value of the assembly.')
    roof_cavity_r.setDefaultValue(0)
    args << roof_cavity_r

    # make a choice argument for roof cavity insulation installation grade
    roof_install_grade = OpenStudio::Measure::OSArgument::makeChoiceArgument('roof_install_grade', installgrade_display_names, true)
    roof_install_grade.setDisplayName('Roof Cavity Install Grade')
    roof_install_grade.setDescription('Installation grade as defined by RESNET standard. 5% of the cavity is considered missing insulation for Grade 3, 2% for Grade 2, and 0% for Grade 1.')
    roof_install_grade.setDefaultValue('1')
    args << roof_install_grade

    # make a choice argument for roof cavity insulation thickness
    roof_cavity_ins_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('roof_cavity_ins_thick_in', true)
    roof_cavity_ins_thick_in.setDisplayName('Roof Cavity Insulation Thickness')
    roof_cavity_ins_thick_in.setUnits('in')
    roof_cavity_ins_thick_in.setDescription('The thickness in inches of insulation required to obtain the specified R-value.')
    roof_cavity_ins_thick_in.setDefaultValue(0)
    args << roof_cavity_ins_thick_in

    # make a choice argument for roof framing factor
    roof_framing_factor = OpenStudio::Measure::OSArgument::makeDoubleArgument('roof_framing_factor', true)
    roof_framing_factor.setDisplayName('Roof Framing Factor')
    roof_framing_factor.setUnits('frac')
    roof_framing_factor.setDescription('Fraction of roof that is framing.')
    roof_framing_factor.setDefaultValue(0.07)
    args << roof_framing_factor

    # make a choice argument for roof framing thickness
    roof_framing_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('roof_framing_thick_in', true)
    roof_framing_thick_in.setDisplayName('Roof Framing Thickness')
    roof_framing_thick_in.setUnits('in')
    roof_framing_thick_in.setDescription('Thickness of roof framing.')
    roof_framing_thick_in.setDefaultValue(7.25)
    args << roof_framing_thick_in

    # make a double argument for roof osb/plywood thickness
    roof_osb_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('roof_osb_thick_in', true)
    roof_osb_thick_in.setDisplayName('Roof OSB/Plywood Thickness')
    roof_osb_thick_in.setUnits('in')
    roof_osb_thick_in.setDescription('Specifies the thickness of the roof OSB/plywood sheathing. Enter 0 for no sheathing.')
    roof_osb_thick_in.setDefaultValue(0.75)
    args << roof_osb_thick_in

    # make a double argument for roof rigid insulation r-value
    roof_rigid_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('roof_rigid_r', true)
    roof_rigid_r.setDisplayName('Roof Continuous Insulation Nominal R-value')
    roof_rigid_r.setUnits('h-ft^2-R/Btu')
    roof_rigid_r.setDescription('The R-value of the roof continuous insulation.')
    roof_rigid_r.setDefaultValue(0.0)
    args << roof_rigid_r

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

    # make a boolean argument for has radiant barrier
    has_radiant_barrier = OpenStudio::Measure::OSArgument::makeBoolArgument('has_radiant_barrier', true)
    has_radiant_barrier.setDescription('Specifies whether the attic has a radiant barrier.')
    has_radiant_barrier.setDisplayName('Has Radiant Barrier')
    has_radiant_barrier.setDefaultValue(false)
    args << has_radiant_barrier

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
    floors_by_type = SurfaceTypes.get_floors(model, runner)

    # Get Inputs
    ceiling_r = runner.getDoubleArgumentValue('ceiling_r', user_arguments)
    ceiling_install_grade = runner.getStringArgumentValue('ceiling_install_grade', user_arguments).to_i
    ceiling_ins_thick_in = runner.getDoubleArgumentValue('ceiling_ins_thick_in', user_arguments)
    ceiling_framing_factor = runner.getDoubleArgumentValue('ceiling_framing_factor', user_arguments)
    ceiling_joist_height_in = runner.getDoubleArgumentValue('ceiling_joist_height_in', user_arguments)
    ceiling_drywall_thick_in = runner.getDoubleArgumentValue('ceiling_drywall_thick_in', user_arguments)
    roof_cavity_r = runner.getDoubleArgumentValue('roof_cavity_r', user_arguments)
    roof_install_grade = runner.getStringArgumentValue('roof_install_grade', user_arguments).to_i
    roof_cavity_ins_thick_in = runner.getDoubleArgumentValue('roof_cavity_ins_thick_in', user_arguments)
    roof_framing_factor = runner.getDoubleArgumentValue('roof_framing_factor', user_arguments)
    roof_framing_thick_in = runner.getDoubleArgumentValue('roof_framing_thick_in', user_arguments)
    roof_osb_thick_in = runner.getDoubleArgumentValue('roof_osb_thick_in', user_arguments)
    roof_rigid_r = runner.getDoubleArgumentValue('roof_rigid_r', user_arguments)
    mat_roofing = RoofConstructions.get_roofing_material(runner.getStringArgumentValue('roofing_material', user_arguments))
    has_radiant_barrier = runner.getBoolArgumentValue('has_radiant_barrier', user_arguments)

    # Apply constructions
    if not FloorConstructions.apply_unfinished_attic(runner, model,
                                                     floors_by_type[Constants.SurfaceTypeFloorFinInsUnfinAttic],
                                                     Constants.SurfaceTypeFloorFinInsUnfinAttic,
                                                     ceiling_r, ceiling_install_grade, ceiling_ins_thick_in,
                                                     ceiling_framing_factor, ceiling_joist_height_in,
                                                     ceiling_drywall_thick_in)
      return false
    end

    if not RoofConstructions.apply_unfinished_attic(runner, model,
                                                    roofs_by_type[Constants.SurfaceTypeRoofUnfinInsExt],
                                                    Constants.SurfaceTypeRoofUnfinInsExt,
                                                    roof_cavity_r, roof_install_grade, roof_cavity_ins_thick_in,
                                                    roof_framing_factor, roof_framing_thick_in,
                                                    roof_osb_thick_in, roof_rigid_r,
                                                    mat_roofing, has_radiant_barrier)
      return false
    end

    if not RoofConstructions.apply_uninsulated_roofs(runner, model,
                                                     roofs_by_type[Constants.SurfaceTypeRoofUnfinUninsExt],
                                                     Constants.SurfaceTypeRoofUnfinUninsExt,
                                                     roof_framing_thick_in, roof_framing_factor,
                                                     roof_osb_thick_in, mat_roofing)
      return false
    end

    # Adiabatic roofs (shared surface with above floor)
    if not FloorConstructions.apply_uninsulated(runner, model,
                                                roofs_by_type[Constants.SurfaceTypeRoofAdiabatic],
                                                Constants.SurfaceTypeRoofAdiabatic,
                                                0.75, 0.5, Material.FloorWood, Material.CoveringBare)
      return false
    end

    # Remove any constructions/materials that aren't used
    HelperMethods.remove_unused_constructions_and_materials(model, runner)

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ProcessConstructionsUnfinishedAttic.new.registerWithApplication
