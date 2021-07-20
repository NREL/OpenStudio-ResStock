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
require File.join(resources_path, 'hvac_sizing')
require File.join(resources_path, 'weather')
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')

# start the measure
class ProcessHVACSizing < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential HVAC Sizing'
  end

  def description
    return "This measure performs HVAC sizing calculations via ACCA Manual J/S, as well as sizing calculations for ground source heat pumps and dehumidifiers.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'This measure assigns HVAC heating/cooling capacities, airflow rates, etc.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a bool argument for showing debug information
    show_debug_info = OpenStudio::Measure::OSArgument::makeBoolArgument('show_debug_info', false)
    show_debug_info.setDisplayName('Show Debug Info')
    show_debug_info.setDescription('Displays various intermediate calculation results.')
    show_debug_info.setDefaultValue(false)
    args << show_debug_info

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    show_debug_info = runner.getBoolArgumentValue('show_debug_info', user_arguments)

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    # Get the weather data
    weather = WeatherProcess.new(model, runner)
    if weather.error?
      return false
    end

    # Determine e+ autosizing or not
    if model.getSimulationControl.runSimulationforSizingPeriods
      weather.add_design_days_for_autosizing
      runner.registerInfo('Added heating/cooling design days for autosizing.')
    end

    units.each do |unit|
      success = HVACSizing.apply(model, unit, runner, weather, show_debug_info)
      return false if not success
    end # unit

    runner.registerFinalCondition('HVAC objects updated as appropriate.')

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ProcessHVACSizing.new.registerWithApplication
