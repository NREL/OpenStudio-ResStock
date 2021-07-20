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
class ProcessConstructionsWallsGeneric < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Walls - Generic Construction'
  end

  def description
    return "This measure assigns a generic layered construction to above-grade walls.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Calculates and assigns material layer properties of generic layered constructions for 1) exterior walls of finished spaces, 2) exterior walls (e.g. gable walls) of unfinished attics under roof insulation, and 3) interior walls (e.g., attic knee walls) between finished and unfinished spaces. Adds furniture & partition wall mass. Uninsulated constructions will also be assigned to 1) exterior walls of unfinished spaces, 2) interior walls between finished spaces, and 3) interior walls between unfinished spaces. Any existing constructions for these surfaces will be removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for layer 1: thickness
    thick_in1 = OpenStudio::Measure::OSArgument::makeDoubleArgument('thick_in_1', true)
    thick_in1.setDisplayName('Thickness 1')
    thick_in1.setUnits('in')
    thick_in1.setDescription('Thickness of the outside layer.')
    thick_in1.setDefaultValue(2.5)
    args << thick_in1

    # make a double argument for layer 2: thickness
    thick_in2 = OpenStudio::Measure::OSArgument::makeDoubleArgument('thick_in_2', false)
    thick_in2.setDisplayName('Thickness 2')
    thick_in2.setUnits('in')
    thick_in2.setDescription('Thickness of the second layer. Leave blank if no second layer.')
    args << thick_in2

    # make a double argument for layer 3: thickness
    thick_in3 = OpenStudio::Measure::OSArgument::makeDoubleArgument('thick_in_3', false)
    thick_in3.setDisplayName('Thickness 3')
    thick_in3.setUnits('in')
    thick_in3.setDescription('Thickness of the third layer. Leave blank if no third layer.')
    args << thick_in3

    # make a double argument for layer 4: thickness
    thick_in4 = OpenStudio::Measure::OSArgument::makeDoubleArgument('thick_in_4', false)
    thick_in4.setDisplayName('Thickness 4')
    thick_in4.setUnits('in')
    thick_in4.setDescription('Thickness of the fourth layer. Leave blank if no fourth layer.')
    args << thick_in4

    # make a double argument for layer 5: thickness
    thick_in5 = OpenStudio::Measure::OSArgument::makeDoubleArgument('thick_in_5', false)
    thick_in5.setDisplayName('Thickness 5')
    thick_in5.setUnits('in')
    thick_in5.setDescription('Thickness of the fifth layer. Leave blank if no fifth layer.')
    args << thick_in5

    # make a double argument for layer 1: conductivity
    cond1 = OpenStudio::Measure::OSArgument::makeDoubleArgument('conductivity_1', true)
    cond1.setDisplayName('Conductivity 1')
    cond1.setUnits('Btu-in/h-ft^2-R')
    cond1.setDescription('Conductivity of the outside layer.')
    cond1.setDefaultValue(9.211)
    args << cond1

    # make a double argument for layer 2: conductivity
    cond2 = OpenStudio::Measure::OSArgument::makeDoubleArgument('conductivity_2', false)
    cond2.setDisplayName('Conductivity 2')
    cond2.setUnits('Btu-in/h-ft^2-R')
    cond2.setDescription('Conductivity of the second layer. Leave blank if no second layer.')
    args << cond2

    # make a double argument for layer 3: conductivity
    cond3 = OpenStudio::Measure::OSArgument::makeDoubleArgument('conductivity_3', false)
    cond3.setDisplayName('Conductivity 3')
    cond3.setUnits('Btu-in/h-ft^2-R')
    cond3.setDescription('Conductivity of the third layer. Leave blank if no third layer.')
    args << cond3

    # make a double argument for layer 4: conductivity
    cond4 = OpenStudio::Measure::OSArgument::makeDoubleArgument('conductivity_4', false)
    cond4.setDisplayName('Conductivity 4')
    cond4.setUnits('Btu-in/h-ft^2-R')
    cond4.setDescription('Conductivity of the fourth layer. Leave blank if no fourth layer.')
    args << cond4

    # make a double argument for layer 5: conductivity
    cond5 = OpenStudio::Measure::OSArgument::makeDoubleArgument('conductivity_5', false)
    cond5.setDisplayName('Conductivity 5')
    cond5.setUnits('Btu-in/h-ft^2-R')
    cond5.setDescription('Conductivity of the fifth layer. Leave blank if no fifth layer.')
    args << cond5

    # make a double argument for layer 1: density
    dens1 = OpenStudio::Measure::OSArgument::makeDoubleArgument('density_1', true)
    dens1.setDisplayName('Density 1')
    dens1.setUnits('lb/ft^3')
    dens1.setDescription('Density of the outside layer.')
    dens1.setDefaultValue(138.33)
    args << dens1

    # make a double argument for layer 2: density
    dens2 = OpenStudio::Measure::OSArgument::makeDoubleArgument('density_2', false)
    dens2.setDisplayName('Density 2')
    dens2.setUnits('lb/ft^3')
    dens2.setDescription('Density of the second layer. Leave blank if no second layer.')
    args << dens2

    # make a double argument for layer 3: density
    dens3 = OpenStudio::Measure::OSArgument::makeDoubleArgument('density_3', false)
    dens3.setDisplayName('Density 3')
    dens3.setUnits('lb/ft^3')
    dens3.setDescription('Density of the third layer. Leave blank if no third layer.')
    args << dens3

    # make a double argument for layer 4: density
    dens4 = OpenStudio::Measure::OSArgument::makeDoubleArgument('density_4', false)
    dens4.setDisplayName('Density 4')
    dens4.setUnits('lb/ft^3')
    dens4.setDescription('Density of the fourth layer. Leave blank if no fourth layer.')
    args << dens4

    # make a double argument for layer 5: density
    dens5 = OpenStudio::Measure::OSArgument::makeDoubleArgument('density_5', false)
    dens5.setDisplayName('Density 5')
    dens5.setUnits('lb/ft^3')
    dens5.setDescription('Density of the fifth layer. Leave blank if no fifth layer.')
    args << dens5

    # make a double argument for layer 1: specific heat
    specheat1 = OpenStudio::Measure::OSArgument::makeDoubleArgument('specific_heat_1', true)
    specheat1.setDisplayName('Specific Heat 1')
    specheat1.setUnits('Btu/lb-R')
    specheat1.setDescription('Specific heat of the outside layer.')
    specheat1.setDefaultValue(0.23)
    args << specheat1

    # make a double argument for layer 2: specific heat
    specheat2 = OpenStudio::Measure::OSArgument::makeDoubleArgument('specific_heat_2', false)
    specheat2.setDisplayName('Specific Heat 2')
    specheat2.setUnits('Btu/lb-R')
    specheat2.setDescription('Specific heat of the second layer. Leave blank if no second layer.')
    args << specheat2

    # make a double argument for layer 3: specific heat
    specheat3 = OpenStudio::Measure::OSArgument::makeDoubleArgument('specific_heat_3', false)
    specheat3.setDisplayName('Specific Heat 3')
    specheat3.setUnits('Btu/lb-R')
    specheat3.setDescription('Specific heat of the third layer. Leave blank if no third layer.')
    args << specheat3

    # make a double argument for layer 4: specific heat
    specheat4 = OpenStudio::Measure::OSArgument::makeDoubleArgument('specific_heat_4', false)
    specheat4.setDisplayName('Specific Heat 4')
    specheat4.setUnits('Btu/lb-R')
    specheat4.setDescription('Specific heat of the fourth layer. Leave blank if no fourth layer.')
    args << specheat4

    # make a double argument for layer 5: specific heat
    specheat5 = OpenStudio::Measure::OSArgument::makeDoubleArgument('specific_heat_5', false)
    specheat5.setDisplayName('Specific Heat 5')
    specheat5.setUnits('Btu/lb-R')
    specheat5.setDescription('Specific heat of the fifth layer. Leave blank if no fifth layer.')
    args << specheat5

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
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    walls_by_type = SurfaceTypes.get_walls(model, runner)

    # Get inputs
    thick_in1 = runner.getDoubleArgumentValue('thick_in_1', user_arguments)
    thick_in2 = runner.getOptionalDoubleArgumentValue('thick_in_2', user_arguments)
    thick_in3 = runner.getOptionalDoubleArgumentValue('thick_in_3', user_arguments)
    thick_in4 = runner.getOptionalDoubleArgumentValue('thick_in_4', user_arguments)
    thick_in5 = runner.getOptionalDoubleArgumentValue('thick_in_5', user_arguments)
    cond1 = runner.getDoubleArgumentValue('conductivity_1', user_arguments)
    cond2 = runner.getOptionalDoubleArgumentValue('conductivity_2', user_arguments)
    cond3 = runner.getOptionalDoubleArgumentValue('conductivity_3', user_arguments)
    cond4 = runner.getOptionalDoubleArgumentValue('conductivity_4', user_arguments)
    cond5 = runner.getOptionalDoubleArgumentValue('conductivity_5', user_arguments)
    dens1 = runner.getDoubleArgumentValue('density_1', user_arguments)
    dens2 = runner.getOptionalDoubleArgumentValue('density_2', user_arguments)
    dens3 = runner.getOptionalDoubleArgumentValue('density_3', user_arguments)
    dens4 = runner.getOptionalDoubleArgumentValue('density_4', user_arguments)
    dens5 = runner.getOptionalDoubleArgumentValue('density_5', user_arguments)
    specheat1 = runner.getDoubleArgumentValue('specific_heat_1', user_arguments)
    specheat2 = runner.getOptionalDoubleArgumentValue('specific_heat_2', user_arguments)
    specheat3 = runner.getOptionalDoubleArgumentValue('specific_heat_3', user_arguments)
    specheat4 = runner.getOptionalDoubleArgumentValue('specific_heat_4', user_arguments)
    specheat5 = runner.getOptionalDoubleArgumentValue('specific_heat_5', user_arguments)
    drywall_thick_in = runner.getDoubleArgumentValue('drywall_thick_in', user_arguments)
    osb_thick_in = runner.getDoubleArgumentValue('osb_thick_in', user_arguments)
    rigid_r = runner.getDoubleArgumentValue('rigid_r', user_arguments)
    mat_ext_finish = WallConstructions.get_exterior_finish_material(runner.getStringArgumentValue('exterior_finish', user_arguments))

    if mat_ext_finish.name.include?('None')
      runner.registerError("Generic wall type cannot have a 'None' exterior finish")
      return false
    end

    if thick_in2.empty? then thick_in2 = nil else thick_in2 = thick_in2.get end
    if thick_in3.empty? then thick_in3 = nil else thick_in3 = thick_in3.get end
    if thick_in4.empty? then thick_in4 = nil else thick_in4 = thick_in4.get end
    if thick_in5.empty? then thick_in5 = nil else thick_in5 = thick_in5.get end
    thick_ins = [thick_in1, thick_in2, thick_in3, thick_in4, thick_in5]

    if cond2.empty? then cond2 = nil else cond2 = cond2.get end
    if cond3.empty? then cond3 = nil else cond3 = cond3.get end
    if cond4.empty? then cond4 = nil else cond4 = cond4.get end
    if cond5.empty? then cond5 = nil else cond5 = cond5.get end
    conds = [cond1, cond2, cond3, cond4, cond5]

    if dens2.empty? then dens2 = nil else dens2 = dens2.get end
    if dens3.empty? then dens3 = nil else dens3 = dens3.get end
    if dens4.empty? then dens4 = nil else dens4 = dens4.get end
    if dens5.empty? then dens5 = nil else dens5 = dens5.get end
    denss = [dens1, dens2, dens3, dens4, dens5]

    if specheat2.empty? then specheat2 = nil else specheat2 = specheat2.get end
    if specheat3.empty? then specheat3 = nil else specheat3 = specheat3.get end
    if specheat4.empty? then specheat4 = nil else specheat4 = specheat4.get end
    if specheat5.empty? then specheat5 = nil else specheat5 = specheat5.get end
    specheats = [specheat1, specheat2, specheat3, specheat4, specheat5]

    # Apply constructions
    if not WallConstructions.apply_generic(runner, model,
                                           walls_by_type[Constants.SurfaceTypeWallExtInsFin],
                                           Constants.SurfaceTypeWallExtInsFin,
                                           thick_ins, conds, denss, specheats,
                                           drywall_thick_in, osb_thick_in, rigid_r,
                                           mat_ext_finish)
      return false
    end

    if not WallConstructions.apply_generic(runner, model,
                                           walls_by_type[Constants.SurfaceTypeWallExtInsUnfin],
                                           Constants.SurfaceTypeWallExtInsUnfin,
                                           thick_ins, conds, denss, specheats,
                                           0, osb_thick_in, rigid_r,
                                           mat_ext_finish)
      return false
    end

    if not WallConstructions.apply_generic(runner, model,
                                           walls_by_type[Constants.SurfaceTypeWallIntFinInsUnfin],
                                           Constants.SurfaceTypeWallIntFinInsUnfin,
                                           thick_ins, conds, denss, specheats,
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
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ProcessConstructionsWallsGeneric.new.registerWithApplication
