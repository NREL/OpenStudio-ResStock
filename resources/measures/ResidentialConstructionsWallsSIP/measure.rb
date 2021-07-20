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
class ProcessConstructionsWallsSIP < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Set Residential Walls - SIP Construction'
  end

  # human readable description
  def description
    return "This measure assigns a SIP construction to above-grade walls.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Calculates and assigns material layer properties of SIP constructions for 1) exterior walls of finished spaces, 2) exterior walls (e.g. gable walls) of unfinished attics under roof insulation, and 3) interior walls (e.g., attic knee walls) between finished and unfinished spaces. Adds furniture & partition wall mass. Uninsulated constructions will also be assigned to 1) exterior walls of unfinished spaces, 2) interior walls between finished spaces, and 3) interior walls between unfinished spaces. Any existing constructions for these surfaces will be removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for nominal R-value of the sip insulation
    sip_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('sip_r', true)
    sip_r.setDisplayName('Nominal Insulation R-value')
    sip_r.setUnits('hr-ft^2-R/Btu')
    sip_r.setDescription("R-value is a measure of insulation's ability to resist heat traveling through it.")
    sip_r.setDefaultValue(17.5)
    args << sip_r

    # make a double argument for thickness of the sip insulation
    thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('thick_in', true)
    thick_in.setDisplayName('Insulation Thickness')
    thick_in.setUnits('in')
    thick_in.setDescription('Thickness of the insulating core of the SIP.')
    thick_in.setDefaultValue(3.625)
    args << thick_in

    # make a double argument for framing factor
    framing_factor = OpenStudio::Measure::OSArgument::makeDoubleArgument('framing_factor', true)
    framing_factor.setDisplayName('Framing Factor')
    framing_factor.setUnits('frac')
    framing_factor.setDescription('Total fraction of the wall that is framing for windows or doors.')
    framing_factor.setDefaultValue(0.156)
    args << framing_factor

    # make a string argument for interior sheathing type
    intsheathing_display_names = OpenStudio::StringVector.new
    intsheathing_display_names << Constants.MaterialOSB
    intsheathing_display_names << Constants.MaterialGypsum
    intsheathing_display_names << Constants.MaterialGypcrete
    sheathing_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('sheathing_type', intsheathing_display_names, true)
    sheathing_type.setDisplayName('Interior Sheathing Type')
    sheathing_type.setDescription('The interior sheathing type of the SIP wall.')
    sheathing_type.setDefaultValue(Constants.MaterialOSB)
    args << sheathing_type

    # make a double argument for thickness of the interior sheathing
    sheathing_thick_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('sheathing_thick_in', true)
    sheathing_thick_in.setDisplayName('Interior Sheathing Thickness')
    sheathing_thick_in.setUnits('in')
    sheathing_thick_in.setDescription('The thickness of the interior sheathing.')
    sheathing_thick_in.setDefaultValue(0.44)
    args << sheathing_thick_in

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
    sip_r = runner.getDoubleArgumentValue('sip_r', user_arguments)
    thick_in = runner.getDoubleArgumentValue('thick_in', user_arguments)
    framing_factor = runner.getDoubleArgumentValue('framing_factor', user_arguments)
    sheathing_type = runner.getStringArgumentValue('sheathing_type', user_arguments)
    sheathing_thick_in = runner.getDoubleArgumentValue('sheathing_thick_in', user_arguments)
    drywall_thick_in = runner.getDoubleArgumentValue('drywall_thick_in', user_arguments)
    osb_thick_in = runner.getDoubleArgumentValue('osb_thick_in', user_arguments)
    rigid_r = runner.getDoubleArgumentValue('rigid_r', user_arguments)
    mat_ext_finish = WallConstructions.get_exterior_finish_material(runner.getStringArgumentValue('exterior_finish', user_arguments))

    if mat_ext_finish.name.include?('None')
      runner.registerError("SIP walls cannot have a 'None' exterior finish")
      return false
    end

    # Apply constructions
    if not WallConstructions.apply_sip(runner, model,
                                       walls_by_type[Constants.SurfaceTypeWallExtInsFin],
                                       Constants.SurfaceTypeWallExtInsFin,
                                       sip_r, thick_in, framing_factor,
                                       sheathing_type, sheathing_thick_in,
                                       drywall_thick_in, osb_thick_in, rigid_r,
                                       mat_ext_finish)
      return false
    end

    if not WallConstructions.apply_sip(runner, model,
                                       walls_by_type[Constants.SurfaceTypeWallExtInsUnfin],
                                       Constants.SurfaceTypeWallExtInsUnfin,
                                       sip_r, thick_in, framing_factor,
                                       sheathing_type, sheathing_thick_in,
                                       0, osb_thick_in, rigid_r,
                                       mat_ext_finish)
      return false
    end

    if not WallConstructions.apply_sip(runner, model,
                                       walls_by_type[Constants.SurfaceTypeWallIntFinInsUnfin],
                                       Constants.SurfaceTypeWallIntFinInsUnfin,
                                       sip_r, thick_in, framing_factor,
                                       sheathing_type, sheathing_thick_in,
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
ProcessConstructionsWallsSIP.new.registerWithApplication
