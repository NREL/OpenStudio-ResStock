# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'util')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'constructions')

# start the measure
class ProcessConstructionsDoors < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Door Construction'
  end

  def description
    return "This measure assigns a construction to exterior doors.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Calculates material layer properties of constructions for exterior door sub-surfaces. Any existing constructions for these sub-surfaces will be removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a string argument for door u-factor
    ufactor = OpenStudio::Measure::OSArgument::makeDoubleArgument('ufactor', true)
    ufactor.setDisplayName('U-Factor')
    ufactor.setUnits('Btu/hr-ft^2-R')
    ufactor.setDescription('The heat transfer coefficient of the doors adjacent to finished space.')
    ufactor.setDefaultValue(0.2)
    args << ufactor

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    ufactor = runner.getDoubleArgumentValue('ufactor', user_arguments)

    finished_subsurfaces = []
    unfinished_subsurfaces = []
    model.getSubSurfaces.each do |subsurface|
      next unless subsurface.subSurfaceType.downcase.include? 'door'

      if Geometry.space_is_finished(subsurface.surface.get.space.get)
        finished_subsurfaces << subsurface
      else
        unfinished_subsurfaces << subsurface
      end
    end

    # Apply constructions
    if not SubsurfaceConstructions.apply_door(runner, model,
                                              finished_subsurfaces,
                                              'Door', ufactor)
      return false
    end

    if not SubsurfaceConstructions.apply_door(runner, model,
                                              unfinished_subsurfaces,
                                              'UninsDoor', 0.2)
      return false
    end

    # Remove any constructions/materials that aren't used
    HelperMethods.remove_unused_constructions_and_materials(model, runner)

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ProcessConstructionsDoors.new.registerWithApplication
