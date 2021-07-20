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
class ProcessConstructionsWallsICF < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Set Residential Walls - ICF Construction'
  end

  # human readable description
  def description
    return "This measure assigns an ICF construction to above-grade walls.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Calculates and assigns material layer properties of ICF constructions for 1) exterior walls of finished spaces, 2) exterior walls (e.g. gable walls) of unfinished attics under roof insulation, and 3) interior walls (e.g., attic knee walls) between finished and unfinished spaces. Adds furniture & partition wall mass. Uninsulated constructions will also be assigned to 1) exterior walls of unfinished spaces, 2) interior walls between finished spaces, and 3) interior walls between unfinished spaces. Any existing constructions for these surfaces will be removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for nominal R-value of the icf insulation
    icf_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('icf_r', true)
    icf_r.setDisplayName('Nominal Insulation R-value')
    icf_r.setUnits('hr-ft^2-R/Btu')
    icf_r.setDescription('R-value of each insulating layer of the form.')
    icf_r.setDefaultValue(10.0)
    args << icf_r

    # make a double argument for thickness of the icf insulation
    ins_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('ins_thick_in', true)
    ins_thick_in.setDisplayName('Insulation Thickness')
    ins_thick_in.setUnits('in')
    ins_thick_in.setDescription('Thickness of each insulating layer of the form.')
    ins_thick_in.setDefaultValue(2.0)
    args << ins_thick_in

    # make a double argument for thickness of the concrete
    concrete_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('concrete_thick_in', true)
    concrete_thick_in.setDisplayName('Concrete Thickness')
    concrete_thick_in.setUnits('in')
    concrete_thick_in.setDescription('The thickness of the concrete core of the ICF.')
    concrete_thick_in.setDefaultValue(4.0)
    args << concrete_thick_in

    # make a double argument for framing factor
    framing_factor = OpenStudio::Measure::OSArgument::makeDoubleArgument('framing_factor', true)
    framing_factor.setDisplayName('Framing Factor')
    framing_factor.setUnits('frac')
    framing_factor.setDescription('Total fraction of the wall that is framing for windows or doors.')
    framing_factor.setDefaultValue(0.076)
    args << framing_factor

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
    icf_r = runner.getDoubleArgumentValue('icf_r', user_arguments)
    ins_thick_in = runner.getDoubleArgumentValue('ins_thick_in', user_arguments)
    concrete_thick_in = runner.getDoubleArgumentValue('concrete_thick_in', user_arguments)
    framing_factor = runner.getDoubleArgumentValue('framing_factor', user_arguments)
    drywall_thick_in = runner.getDoubleArgumentValue('drywall_thick_in', user_arguments)
    osb_thick_in = runner.getDoubleArgumentValue('osb_thick_in', user_arguments)
    rigid_r = runner.getDoubleArgumentValue('rigid_r', user_arguments)
    mat_ext_finish = WallConstructions.get_exterior_finish_material(runner.getStringArgumentValue('exterior_finish', user_arguments))

    if mat_ext_finish.name.include?('None')
      runner.registerError("ICF walls cannot have a 'None' exterior finish")
      return false
    end

    # Apply constructions
    if not WallConstructions.apply_icf(runner, model,
                                       walls_by_type[Constants.SurfaceTypeWallExtInsFin],
                                       Constants.SurfaceTypeWallExtInsFin,
                                       icf_r, ins_thick_in, concrete_thick_in, framing_factor,
                                       drywall_thick_in, osb_thick_in, rigid_r,
                                       mat_ext_finish)
      return false
    end

    if not WallConstructions.apply_icf(runner, model,
                                       walls_by_type[Constants.SurfaceTypeWallExtInsUnfin],
                                       Constants.SurfaceTypeWallExtInsUnfin,
                                       icf_r, ins_thick_in, concrete_thick_in, framing_factor,
                                       0, osb_thick_in, rigid_r,
                                       mat_ext_finish)
      return false
    end

    if not WallConstructions.apply_icf(runner, model,
                                       walls_by_type[Constants.SurfaceTypeWallIntFinInsUnfin],
                                       Constants.SurfaceTypeWallIntFinInsUnfin,
                                       icf_r, ins_thick_in, concrete_thick_in, framing_factor,
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
ProcessConstructionsWallsICF.new.registerWithApplication
