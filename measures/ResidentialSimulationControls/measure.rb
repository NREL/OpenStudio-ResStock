# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

if File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock on AWS
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock unit tests locally
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources')
else
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'simulation')

# start the measure
class ResidentialSimulationControls < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Set Residential Simulation Controls'
  end

  # human readable description
  def description
    return 'Set the simulation timesteps per hour, the run period begin month/day and end month/day, and the calendar year (for start day of week).'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Set the simulation timesteps per hour on the Timestep object, the run period begin month/day and end month/day on the RunPeriod object, and the calendar year on the YearDescription object.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make an argument for the simulation timesteps per hour
    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('timesteps_per_hr', true)
    arg.setDisplayName('Simulation Timesteps Per Hour')
    arg.setDescription('The value entered here is the number of (zone) timesteps to use within an hour. For example a value of 6 entered here directs the program to use a zone timestep of 10 minutes and a value of 60 means a 1 minute timestep.')
    arg.setDefaultValue(6)
    args << arg

    # make an argument for the run period begin month
    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('begin_month', true)
    arg.setDisplayName('Run Period Begin Month')
    arg.setDescription('This numeric field should contain the starting month number (1 = January, 2 = February, etc.) for the annual run period desired.')
    arg.setDefaultValue(1)
    args << arg

    # make an argument for the run period begin day of month
    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('begin_day_of_month', true)
    arg.setDisplayName('Run Period Begin Day of Month')
    arg.setDescription('This numeric field should contain the starting day of the starting month (must be valid for month) for the annual run period desired.')
    arg.setDefaultValue(1)
    args << arg

    # make an argument for the run period end month
    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('end_month', true)
    arg.setDisplayName('Run Period End Month')
    arg.setDescription('This numeric field should contain the ending month number (1 = January, 2 = February, etc.) for the annual run period desired.')
    arg.setDefaultValue(12)
    args << arg

    # make an argument for the run period end day of month
    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('end_day_of_month', true)
    arg.setDisplayName('Run Period End Day of Month')
    arg.setDescription('This numeric field should contain the ending day of the ending month (must be valid for month) for the annual run period desired.')
    arg.setDefaultValue(31)
    args << arg

    # make an argument for the calendar year; this determines the day of week for start day
    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('calendar_year', true)
    arg.setDisplayName('Calendar Year')
    arg.setDescription('This numeric field should contain the calendar year that determines the start day of week. If you are running simulations using AMY weather files, the value entered for calendar year will not be used; it will be overridden by the actual year found in the AMY weather file.')
    arg.setDefaultValue(2007)
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

    timesteps_per_hr = runner.getIntegerArgumentValue('timesteps_per_hr', user_arguments)
    begin_month = runner.getIntegerArgumentValue('begin_month', user_arguments)
    begin_day_of_month = runner.getIntegerArgumentValue('begin_day_of_month', user_arguments)
    end_month = runner.getIntegerArgumentValue('end_month', user_arguments)
    end_day_of_month = runner.getIntegerArgumentValue('end_day_of_month', user_arguments)
    calendar_year = runner.getIntegerArgumentValue('calendar_year', user_arguments)

    # Error checking
    if (timesteps_per_hr < 1) || (timesteps_per_hr > 60)
      runner.registerError("User-entered #{timesteps_per_hr} timesteps per hour must be between 1 and 60.")
      return false
    end

    if 60 % timesteps_per_hr != 0
      runner.registerError("User-entered #{timesteps_per_hr} timesteps per hour does not divide evenly into 60.")
      return false
    end

    if (not (1..12).to_a.include? begin_month) || (not (1..12).to_a.include? end_month)
      runner.registerError("Invalid begin month (#{begin_month}) and/or end month (#{end_month}) entered.")
      return false
    end

    { begin_month => begin_day_of_month, end_month => end_day_of_month }.each_with_index do |(month, day), i|
      leap_day = 0
      leap_day += 1 if month == 2 # february
      day_of_month_valid = (1..Constants.NumDaysInMonths[month - 1] + leap_day).to_a.include? day # accommodate leap day
      next if day_of_month_valid

      if i == 0
        runner.registerError("Invalid begin day of month (#{begin_day_of_month}) entered.")
      elsif i == 1
        runner.registerError("Invalid end day of month (#{end_day_of_month}) entered.")
      end
      return false
    end

    if (calendar_year < 1600) || (calendar_year > 9999)
      runner.registerError("Your calendar year value of #{calendar_year} is not in the range 1600-9999.")
      return false
    end

    success = Simulation.apply(model, runner, timesteps_per_hr, min_system_timestep_mins = nil, begin_month, begin_day_of_month, end_month, end_day_of_month, calendar_year)
    return false if not success

    runner.registerInfo("Set the simulation timesteps per hour to #{timesteps_per_hr}.")
    runner.registerInfo("Set the run period begin and end month/day to #{begin_month}/#{begin_day_of_month} and #{end_month}/#{end_day_of_month}, respectively.")
    runner.registerInfo("Set the calendar year to #{model.getYearDescription.calendarYear} and the start day of week to #{model.getYearDescription.dayofWeekforStartDay}; if you are running with AMY, this will be overridden by the AMY year.")

    return true
  end
end

# register the measure to be used by the application
ResidentialSimulationControls.new.registerWithApplication
