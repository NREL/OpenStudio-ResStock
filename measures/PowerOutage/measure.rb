# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

if File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock on AWS
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock unit tests locally
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources')
else
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
end
require File.join(resources_path, 'weather')
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'hvac')

# start the measure
class ProcessPowerOutage < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Power Outage'
  end

  def description
    return 'This measures allows building power outages to be modeled. The user specifies the start time of the outage and the duration of the outage. During an outage, all energy consumption is set to 0, although occupants are still simulated in the home.'
  end

  def modeler_description
    return 'This measure zeroes out the schedule for anything that consumes energy for the duration of the power outage.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a string argument for for the start date of the outage
    arg = OpenStudio::Measure::OSArgument.makeStringArgument('otg_date', true)
    arg.setDisplayName('Outage Start Date')
    arg.setDescription('Date of the start of the outage.')
    arg.setDefaultValue('January 1')
    args << arg

    # make a double argument for hour of outage start
    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('otg_hr', true)
    arg.setDisplayName('Outage Start Hour')
    arg.setUnits('hours')
    arg.setDescription('Hour of the day when the outage starts.')
    arg.setDefaultValue(0)
    args << arg

    # make a double argument for outage duration
    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('otg_len', true)
    arg.setDisplayName('Outage Duration')
    arg.setUnits('hours')
    arg.setDescription('Duration of the power outage in hours.')
    arg.setDefaultValue(24)
    args << arg

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    otg_date = runner.getStringArgumentValue('otg_date', user_arguments)
    otg_hr = runner.getIntegerArgumentValue('otg_hr', user_arguments)
    otg_len = runner.getIntegerArgumentValue('otg_len', user_arguments)

    # check for valid inputs
    if (otg_hr < 0) || (otg_hr > 23)
      runner.registerError('Start hour must be between 0 and 23.')
      return false
    end

    if otg_len == 0
      runner.registerError('Outage must last for at least one hour.')
      return false
    end

    # get daylight saving info to use to modify the schedules as appropriate
    dst = model.getRunPeriodControlDaylightSavingTime
    dst_start_day = dst.startDate.dayOfYear
    dst_end_day = dst.endDate.dayOfYear

    # get the run period
    year_description = model.getYearDescription
    assumed_year = year_description.assumedYear
    run_period = model.getRunPeriod
    run_period_start = Time.new(assumed_year, run_period.getBeginMonth, run_period.getBeginDayOfMonth)
    run_period_end = Time.new(assumed_year, run_period.getEndMonth, run_period.getEndDayOfMonth, 24)

    # get the outage period
    months = { 'January' => 1, 'February' => 2, 'March' => 3, 'April' => 4, 'May' => 5, 'June' => 6, 'July' => 7, 'August' => 8, 'September' => 9, 'October' => 10, 'November' => 11, 'December' => 12 }
    otg_start_date_month = months[otg_date.split[0]]
    otg_start_date_day = otg_date.split[1].to_i
    begin
      otg_period_start = Time.new(assumed_year, otg_start_date_month, otg_start_date_day, otg_hr)
    rescue
      runner.registerError('Invalid outage start date specified.')
      return false
    end
    otg_period_end = otg_period_start + otg_len * 3600.0

    # check that inputs make sense
    if otg_period_start < run_period_start
      runner.registerError('Outage period starts before the run period starts.')
      return false
    elsif otg_period_end > run_period_end
      runner.registerError('Outage period ends after the run period ends.')
      return false
    end

    # get outage start and end days of the year
    otg_start_date_day = ((otg_period_start - Time.new(assumed_year)) / 3600.0 / 24.0 + 1).floor
    otg_end_date_day = ((otg_period_end - Time.new(assumed_year)) / 3600.0 / 24.0 + 1).floor

    # get outage period duration days
    otg_period_num_days = (otg_period_end.to_date - otg_period_start.to_date).to_i + 1

    # make openstudio dates for outage period
    otg_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(otg_period_start.month), otg_period_start.day, otg_period_start.year)
    otg_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(otg_period_end.month), otg_period_end.day, otg_period_end.year)

    model.getScheduleRulesets.each do |schedule_ruleset|
      next if schedule_ruleset.name.to_s.include?('shading') || schedule_ruleset.name.to_s.include?('Schedule Ruleset') || schedule_ruleset.name.to_s.include?(Constants.ObjectNameOccupants) || schedule_ruleset.name.to_s.include?(Constants.ObjectNameHeatingSetpoint) || schedule_ruleset.name.to_s.include?(Constants.ObjectNameCoolingSetpoint)

      otg_val = 0
      if otg_period_num_days <= 1 # occurs within one calendar day
        otg_rule = OpenStudio::Model::ScheduleRule.new(schedule_ruleset)
        otg_rule.setName("#{schedule_ruleset.name} Outage Day #{otg_start_date_day}")
        otg_day = otg_rule.daySchedule
        unmod_sched = schedule_ruleset.getDaySchedules(otg_start_date, otg_start_date)
        unmod_sched = unmod_sched[0]
        for hour in 0..23
          time = OpenStudio::Time.new(0, hour + 1, 0, 0)
          if (hour < otg_hr) || (hour > ((otg_hr + otg_len) - 1))
            otg_day.addValue(time, unmod_sched.getValue(time))
          else
            otg_day.addValue(time, otg_val)
          end
        end
        set_rule_days_and_dates(otg_rule, otg_start_date, otg_start_date)
      else # does not occur within on calendar day
        (otg_start_date_day..otg_end_date_day).each do |day|
          day_date = OpenStudio::Date::fromDayOfYear(day, assumed_year)
          otg_rule = OpenStudio::Model::ScheduleRule.new(schedule_ruleset)
          otg_rule.setName("#{schedule_ruleset.name} Outage Day #{day}")
          otg_day = otg_rule.daySchedule
          unmod_sched = schedule_ruleset.getDaySchedules(day_date, day_date)
          unmod_sched = unmod_sched[0]
          if day == otg_start_date_day # first day of the outage
            if (day >= dst_start_day) && (day <= dst_end_day)
              for hour in 0..23
                time = OpenStudio::Time.new(0, hour + 1, 0, 0)
                if hour == 0
                  otg_day.addValue(time, otg_val)
                elsif (hour < otg_hr) || (hour > ((otg_hr + otg_len) - 1))
                  otg_day.addValue(time, unmod_sched.getValue(time))
                else
                  otg_day.addValue(time, otg_val)
                end
              end
            else
              for hour in 0..23
                time = OpenStudio::Time.new(0, hour + 1, 0, 0)
                if (hour < otg_hr) || (hour > ((otg_hr + otg_len) - 1))
                  otg_day.addValue(time, unmod_sched.getValue(time))
                else
                  otg_day.addValue(time, otg_val)
                end
              end
            end
            set_rule_days_and_dates(otg_rule, day_date, day_date)
          elsif day == otg_end_date_day # last day of the outage
            if (day >= dst_start_day) && (day <= dst_end_day)
              for hour in 0..23
                time = OpenStudio::Time.new(0, hour + 1, 0, 0)
                if hour == 0
                  otg_day.addValue(time, unmod_sched.getValue(time))
                elsif hour < otg_period_end.hour
                  otg_day.addValue(time, otg_val)
                else
                  otg_day.addValue(time, unmod_sched.getValue(time))
                end
              end
            else
              for hour in 0..23
                time = OpenStudio::Time.new(0, hour + 1, 0, 0)
                if hour < otg_period_end.hour
                  otg_day.addValue(time, otg_val)
                else
                  otg_day.addValue(time, unmod_sched.getValue(time))
                end
              end
            end
            set_rule_days_and_dates(otg_rule, day_date, day_date)
          else # any middle days of the outage
            for hour in 0..23
              time = OpenStudio::Time.new(0, hour + 1, 0, 0)
              otg_day.addValue(time, otg_val)
            end
            set_rule_days_and_dates(otg_rule, day_date, day_date)
          end
        end
      end
      runner.registerInfo("Modified the schedule '#{schedule_ruleset.name}'.")
    end

    # make an outage availability schedule
    annual_hrs = (Time.new(assumed_year + 1) - Time.new(assumed_year)) / 3600.0
    otg_availability = [1] * annual_hrs
    otg_start_hour_of_year = ((otg_period_start - Time.new(assumed_year)) / 3600.0).to_i
    otg_end_hour_of_year = ((otg_period_end - Time.new(assumed_year)) / 3600.0).to_i
    (otg_start_hour_of_year...otg_end_hour_of_year).each do |hour|
      otg_availability[hour] = 0
    end
    year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(1), 1, assumed_year)
    timeseries = OpenStudio::TimeSeries.new(year_start_date, OpenStudio::Time.new(0, 1, 0, 0), OpenStudio::createVector(otg_availability), '')
    otg_availability_schedule = OpenStudio::Model::ScheduleInterval.fromTimeSeries(timeseries, model)
    otg_availability_schedule = otg_availability_schedule.get
    otg_availability_schedule.setName('Outage Availability Schedule')

    # set outage availability schedule on all hvac objects
    model.getThermalZones.each do |thermal_zone|
      equipments = HVAC.existing_heating_equipment(model, runner, thermal_zone) + HVAC.existing_cooling_equipment(model, runner, thermal_zone)
      equipments.each do |equipment|
        equipment.setAvailabilitySchedule(otg_availability_schedule)
        runner.registerInfo("Modified the availability schedule for '#{equipment.name}'.")
      end
    end

    # set the outage availability schedule on res_infil_1_wh_sch_s (so house fan zeroes out)
    model.getEnergyManagementSystemSensors.each do |ems_sensor|
      next unless ems_sensor.name.to_s.include? '_wh_sch_s'

      ems_sensor.setKeyName('Outage Availability Schedule')
      runner.registerInfo("Modified the key name for '#{ems_sensor.name}'.")
    end

    # set the outage on schedules that are generated
    schedules_file = SchedulesFile.new(runner: runner, model: model)
    schedules = []
    ScheduleGenerator.col_names.each do |col_name, val|
      next if col_name == 'occupants'

      schedules << col_name unless val.nil?
    end

    schedules_path = model.getBuilding.additionalProperties.getFeatureAsString('Schedules Path')
    schedules.each do |col_name|
      if schedules_path.is_initialized # this is not a test
        schedules_file.import(col_name: col_name)
        schedules_file.set_outage(col_name: col_name, outage_start_date: otg_date, outage_start_hour: otg_hr, outage_length: otg_len)
      end
      runner.registerInfo("Modified the schedule '#{col_name}'.")
    end

    # add additional properties object with the date of the outage for use by reporting measures
    additional_properties = year_description.additionalProperties
    additional_properties.setFeature('PowerOutageStartDate', otg_date)
    additional_properties.setFeature('PowerOutageStartHour', otg_hr)
    additional_properties.setFeature('PowerOutageDuration', otg_len)

    runner.registerFinalCondition("A power outage has been added, starting on #{otg_date} at hour #{otg_hr.to_i} and lasting for #{otg_len.to_i} hours.")

    return true
  end # end the run method

  def set_rule_days_and_dates(rule, state_date, end_date)
    rule.setApplySunday(true)
    rule.setApplyMonday(true)
    rule.setApplyTuesday(true)
    rule.setApplyWednesday(true)
    rule.setApplyThursday(true)
    rule.setApplyFriday(true)
    rule.setApplySaturday(true)
    rule.setStartDate(state_date)
    rule.setEndDate(end_date)
  end
end # end the measure

# this allows the measure to be use by the application
ProcessPowerOutage.new.registerWithApplication
