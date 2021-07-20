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
class ProcessConstructionsFloors < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Floor Construction'
  end

  def description
    return "This measure assigns a wood stud construction to floors between finished space and unfinished space or floors below cantilevered finished space.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Calculates and assigns material layer properties of wood stud constructions for floors 1) between finished and unfinished spaces not covered by other measures or 2) between finished spaces and outside. Any existing constructions for these surfaces will be removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for nominal R-value of cavity insulation
    cavity_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('cavity_r', true)
    cavity_r.setDisplayName('Cavity Insulation Nominal R-value')
    cavity_r.setUnits('hr-ft^2-R/Btu')
    cavity_r.setDescription('Refers to the R-value of the cavity insulation and not the overall R-value of the assembly.')
    cavity_r.setDefaultValue(19.0)
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

    # make a choice argument for ceiling framing factor
    framing_factor = OpenStudio::Measure::OSArgument::makeDoubleArgument('framing_factor', true)
    framing_factor.setDisplayName('Framing Factor')
    framing_factor.setUnits('frac')
    framing_factor.setDescription('The fraction of a floor assembly that is comprised of structural framing.')
    framing_factor.setDefaultValue(0.13)
    args << framing_factor

    # make a choice argument for joist height
    joist_height_in = OpenStudio::Measure::OSArgument::makeDoubleArgument('joist_height_in', true)
    joist_height_in.setDisplayName('Joist Height')
    joist_height_in.setUnits('in')
    joist_height_in.setDescription('Height of the joist member.')
    joist_height_in.setDefaultValue(5.5)
    args << joist_height_in

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    floors_by_type = SurfaceTypes.get_floors(model, runner)

    # Get Inputs
    cavity_r = runner.getDoubleArgumentValue('cavity_r', user_arguments)
    install_grade = runner.getStringArgumentValue('install_grade', user_arguments).to_i
    framing_factor = runner.getDoubleArgumentValue('framing_factor', user_arguments)
    joist_height_in = runner.getDoubleArgumentValue('joist_height_in', user_arguments)

    # Apply constructions
    if not FloorConstructions.apply_foundation_ceiling(runner, model,
                                                       floors_by_type[Constants.SurfaceTypeFloorFinInsUnfin],
                                                       Constants.SurfaceTypeFloorFinInsUnfin,
                                                       cavity_r, install_grade, framing_factor, joist_height_in,
                                                       0.75, Material.FloorWood, Material.CoveringBare)
      return false
    end

    if not FloorConstructions.apply_uninsulated(runner, model,
                                                floors_by_type[Constants.SurfaceTypeFloorFinUninsFin],
                                                Constants.SurfaceTypeFloorFinUninsFin,
                                                0.75, 0.5, Material.FloorWood, Material.CoveringBare)
      return false
    end

    if not FloorConstructions.apply_uninsulated(runner, model,
                                                floors_by_type[Constants.SurfaceTypeFloorUnfinUninsUnfin],
                                                Constants.SurfaceTypeFloorUnfinUninsUnfin,
                                                0.75, 0, nil, nil)
      return false
    end

    # Remove any constructions/materials that aren't used
    HelperMethods.remove_unused_constructions_and_materials(model, runner)

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ProcessConstructionsFloors.new.registerWithApplication
