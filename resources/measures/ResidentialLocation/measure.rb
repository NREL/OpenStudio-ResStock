# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'location')

# start the measure
class SetResidentialEPWFile < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Set Residential Location'
  end

  # human readable description
  def description
    return "Sets the EPW weather file (EPW), supplemental data specific to the location, and daylight saving time start/end dates.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Sets the weather file, Building America climate zone, site information (e.g., latitude, longitude, elevation, timezone), design day information (from the DDY file), the mains water temperature using the correlation method, and the daylight saving time start/end dates.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('weather_directory', true)
    arg.setDisplayName('Weather Directory')
    arg.setDescription('Absolute (or relative) directory to weather files.')
    arg.setDefaultValue('../HPXMLtoOpenStudio/weather')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('weather_file_name', true)
    arg.setDisplayName('Weather File Name')
    arg.setDescription('Name of the EPW weather file to assign. The corresponding DDY file must also be in the same directory.')
    arg.setDefaultValue('USA_CO_Denver.Intl.AP.725650_TMY3.epw')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('dst_start_date', true)
    arg.setDisplayName('Daylight Saving Start Date')
    arg.setDescription("Set to 'NA' if no daylight saving.")
    arg.setDefaultValue('March 12')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('dst_end_date', true)
    arg.setDisplayName('Daylight Saving End Date')
    arg.setDescription("Set to 'NA' if no daylight saving.")
    arg.setDefaultValue('November 5')
    args << arg

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # grab the initial weather file
    weather_directory = runner.getStringArgumentValue('weather_directory', user_arguments)
    weather_file_name = runner.getStringArgumentValue('weather_file_name', user_arguments)
    dst_start_date = runner.getStringArgumentValue('dst_start_date', user_arguments)
    dst_end_date = runner.getStringArgumentValue('dst_end_date', user_arguments)

    unless (Pathname.new weather_directory).absolute?
      weather_directory = File.expand_path(File.join(File.dirname(__FILE__), weather_directory))
    end
    weather_file_path = File.join(weather_directory, weather_file_name)

    success, weather = Location.apply(model, runner, weather_file_path, dst_start_date, dst_end_date)
    return false if not success

    # report final condition
    site = model.getSite
    if site.weatherFile.is_initialized
      runner.registerFinalCondition("The weather file path is '#{site.weatherFile.get.path.get}'.")
    else
      runner.registerFinalCondition('The weather file has not been set.')
    end

    return true
  end
end

# register the measure to be used by the application
SetResidentialEPWFile.new.registerWithApplication
