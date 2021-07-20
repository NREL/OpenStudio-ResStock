# frozen_string_literal: true

require 'csv'
require 'matrix'
resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'unit_conversions')
require File.join(resources_path, 'appliances')
require File.join(resources_path, 'weather')

# start the measure
class ResidentialScheduleGenerator < OpenStudio::Measure::ModelMeasure
  def name
    return 'Generate Appliance schedules'
  end

  def description
    return "Generates occupancy based schedules for various residential appliances.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'TODO'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Make a integer argument for occupants (integer or string of integers)
    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('num_occupants', true)
    arg.setDisplayName('Number of Occupants')
    arg.setDescription('Specify the number of occupants.')
    arg.setDefaultValue(2)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('state', true)
    arg.setDisplayName('State')
    arg.setDescription('Specify the state for which the schedule is to be generated')
    arg.setDefaultValue('')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('vacancy_start_date', true)
    arg.setDisplayName('Vacancy Start Date')
    arg.setDescription("Set to 'NA' if never vacant.")
    arg.setDefaultValue('NA')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('vacancy_end_date', true)
    arg.setDisplayName('Vacancy End Date')
    arg.setDescription("Set to 'NA' if never vacant.")
    arg.setDefaultValue('NA')
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

    # assign the user inputs to variables
    args = { num_occupants: runner.getIntegerArgumentValue('num_occupants', user_arguments),
             state: runner.getStringArgumentValue('state', user_arguments),
             vacancy_start_date: runner.getStringArgumentValue('vacancy_start_date', user_arguments),
             vacancy_end_date: runner.getStringArgumentValue('vacancy_end_date', user_arguments) }

    # error checking
    if not args[:num_occupants] > 0
      runner.registerError("Number of Occupants '#{args[:num_occupants]} must be greater than 0.")
      return false
    end

    model.getBuilding.additionalProperties.setFeature('num_occupants', args[:num_occupants])

    args[:schedules_path] = File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources/schedules')

    weather = WeatherProcess.new(model, runner) # required for lighting schedule generation
    if weather.error?
      return false
    end

    schedule_generator = ScheduleGenerator.new(runner: runner, model: model, weather: weather, **args)

    # create the schedule
    success = schedule_generator.create
    return false if not success

    # export the schedule
    output_csv_file = File.expand_path('../schedules.csv')
    success = schedule_generator.export(output_path: output_csv_file)
    return false if not success

    runner.registerInfo("Generated schedule file: #{output_csv_file}")
    model.getBuilding.additionalProperties.setFeature('Schedules Path', output_csv_file)

    return true
  end
end # end the measure

# this allows the measure to be use by the application
ResidentialScheduleGenerator.new.registerWithApplication
