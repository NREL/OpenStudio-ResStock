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
class ProcessConstructionsWallsCMU < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Set Residential Walls - CMU Construction'
  end

  # human readable description
  def description
    return "This measure assigns a CMU construction to above-grade walls.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Calculates and assigns material layer properties of CMU constructions for 1) exterior walls of finished spaces, 2) exterior walls (e.g. gable walls) of unfinished attics under roof insulation, and 3) interior walls (e.g., attic knee walls) between finished and unfinished spaces. Adds furniture & partition wall mass. Uninsulated constructions will also be assigned to 1) exterior walls of unfinished spaces, 2) interior walls between finished spaces, and 3) interior walls between unfinished spaces. Any existing constructions for these surfaces will be removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for thickness of the cmu block
    thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('thick_in', true)
    thick_in.setDisplayName('CMU Block Thickness')
    thick_in.setUnits('in')
    thick_in.setDescription('Thickness of the CMU portion of the wall.')
    thick_in.setDefaultValue(6.0)
    args << thick_in

    # make a double argument for conductivity of the cmu block
    conductivity = OpenStudio::Measure::OSArgument::makeDoubleArgument('conductivity', true)
    conductivity.setDisplayName('CMU Conductivity')
    conductivity.setUnits('Btu-in/hr-ft^2-R')
    conductivity.setDescription('Overall conductivity of the finished CMU block.')
    conductivity.setDefaultValue(5.33)
    args << conductivity

    # make a double argument for density of the cmu block
    density = OpenStudio::Measure::OSArgument::makeDoubleArgument('density', true)
    density.setDisplayName('CMU Density')
    density.setUnits('lb/ft^3')
    density.setDescription('The density of the finished CMU block.')
    density.setDefaultValue(119.0)
    args << density

    # make a double argument for framing factor
    framing_factor = OpenStudio::Measure::OSArgument::makeDoubleArgument('framing_factor', true)
    framing_factor.setDisplayName('Framing Factor')
    framing_factor.setUnits('frac')
    framing_factor.setDescription('Total fraction of the wall that is framing for windows or doors.')
    framing_factor.setDefaultValue(0.076)
    args << framing_factor

    # make a double argument for furring insulation R-value
    furring_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('furring_r', true)
    furring_r.setDisplayName('Furring Insulation R-value')
    furring_r.setUnits('hr-ft^2-R/Btu')
    furring_r.setDescription('R-value of the insulation filling the furring cavity. Enter zero for no furring strips.')
    furring_r.setDefaultValue(0.0)
    args << furring_r

    # make a double argument for furring cavity depth
    furring_cavity_depth_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('furring_cavity_depth_in', true)
    furring_cavity_depth_in.setDisplayName('Furring Cavity Depth')
    furring_cavity_depth_in.setUnits('in')
    furring_cavity_depth_in.setDescription('The depth of the interior furring cavity. Enter zero for no furring strips.')
    furring_cavity_depth_in.setDefaultValue(1.0)
    args << furring_cavity_depth_in

    # make a double argument for furring stud spacing
    furring_spacing = OpenStudio::Measure::OSArgument::makeDoubleArgument('furring_spacing', true)
    furring_spacing.setDisplayName('Furring Stud Spacing')
    furring_spacing.setUnits('in')
    furring_spacing.setDescription('Spacing of studs in the furring. Enter zero for no furring strips.')
    furring_spacing.setDefaultValue(24.0)
    args << furring_spacing

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
    thick_in = runner.getDoubleArgumentValue('thick_in', user_arguments)
    conductivity = runner.getDoubleArgumentValue('conductivity', user_arguments)
    density = runner.getDoubleArgumentValue('density', user_arguments)
    framing_factor = runner.getDoubleArgumentValue('framing_factor', user_arguments)
    furring_r = runner.getDoubleArgumentValue('furring_r', user_arguments)
    furring_cavity_depth_in = runner.getDoubleArgumentValue('furring_cavity_depth_in', user_arguments)
    furring_spacing = runner.getDoubleArgumentValue('furring_spacing', user_arguments)
    drywall_thick_in = runner.getDoubleArgumentValue('drywall_thick_in', user_arguments)
    osb_thick_in = runner.getDoubleArgumentValue('osb_thick_in', user_arguments)
    rigid_r = runner.getDoubleArgumentValue('rigid_r', user_arguments)
    mat_ext_finish = WallConstructions.get_exterior_finish_material(runner.getStringArgumentValue('exterior_finish', user_arguments))

    # Remove wall sheathing if no exterior finish
    if mat_ext_finish.name.include? 'None'
      osb_thick_in = 0.0
    end

    # Apply constructions
    if not WallConstructions.apply_cmu(runner, model,
                                       walls_by_type[Constants.SurfaceTypeWallExtInsFin],
                                       Constants.SurfaceTypeWallExtInsFin,
                                       thick_in, conductivity, density, framing_factor,
                                       furring_r, furring_cavity_depth_in, furring_spacing,
                                       drywall_thick_in, osb_thick_in, rigid_r,
                                       mat_ext_finish)
      return false
    end

    if not WallConstructions.apply_cmu(runner, model,
                                       walls_by_type[Constants.SurfaceTypeWallExtInsUnfin],
                                       Constants.SurfaceTypeWallExtInsUnfin,
                                       thick_in, conductivity, density, framing_factor,
                                       furring_r, furring_cavity_depth_in, furring_spacing,
                                       0, osb_thick_in, rigid_r,
                                       mat_ext_finish)
      return false
    end

    if not WallConstructions.apply_cmu(runner, model,
                                       walls_by_type[Constants.SurfaceTypeWallIntFinInsUnfin],
                                       Constants.SurfaceTypeWallIntFinInsUnfin,
                                       thick_in, conductivity, density, framing_factor,
                                       furring_r, furring_cavity_depth_in, furring_spacing,
                                       0, osb_thick_in, rigid_r,
                                       nil)
      return false
    end

    # Assume uninsulated wall properties (garage walls, gable walls, etc) if no exterior finish
    if mat_ext_finish.name.include? 'None'
      unins_ext_finish = WallConstructions.get_exterior_finish_material('Vinyl, Light')
      osb_thick_in = 0.5
    else
      unins_ext_finish = mat_ext_finish
    end

    if not WallConstructions.apply_uninsulated(runner, model, walls_by_type,
                                               osb_thick_in, drywall_thick_in, unins_ext_finish)
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
ProcessConstructionsWallsCMU.new.registerWithApplication
