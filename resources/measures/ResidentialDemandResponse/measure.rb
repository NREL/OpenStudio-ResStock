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

require File.join(resources_path, 'constants')
require File.join(resources_path, 'weather')
require File.join(resources_path, 'hvac')
require File.join(resources_path, 'schedules')
require File.join(resources_path, 'geometry')

# start the measure
class DemandResponseSchedule < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Demand Response Schedule'
  end

  def description
    return "This measure alters the thermostat setpoints based on inputted offset magnitudes and schedules of demand-response signals.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'This measure applies hourly demand response controls to existing heating and cooling temperature setpoint schedules. Up to two user-defined DR schedules are inputted as csvs for heating and/or cooling to indicate specific hours of setup and setback. The csvs should contain a value of -1, 0, or 1 for every hour of the simulation period or for an entire year. Offset magnitudes for heating and cooling are also specified by the user, which is multiplied by each row of the DR schedules to generate an hourly offset schedule on-the-fly. The existing cooling and heating setpoint schedules are fetched from the model object, restructured as an hourly schedule for the simulation period, and summed with their respective hourly offset schedules. These new hourly setpoint schedules are assigned to the thermostat object in every zone. Future development of this measure may include on/off DR schedules for appliances or use with water heaters.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make an argument for hourly DR schedule directory
    dr_directory = OpenStudio::Measure::OSArgument::makeStringArgument('dr_directory', true)
    dr_directory.setDisplayName('Demand Response Schedule Directory')
    dr_directory.setDescription('Absolute or relative directory that contains the DR csv files')
    dr_directory.setDefaultValue('../HPXMLtoOpenStudio/resources')
    args << dr_directory

    # make an argument for hourly DR schedule csv file (must be same length as simulation period)
    dr_schedule_heat = OpenStudio::Measure::OSArgument::makeStringArgument('dr_schedule_heat', true)
    dr_schedule_heat.setDisplayName('Heating Setpoint DR Schedule File Name')
    dr_schedule_heat.setDescription('File name of the csv that contains hourly DR signals of -1, 0, or 1 for the heating setpoint schedule.')
    dr_schedule_heat.setDefaultValue('DR_ScheduleHeatSetback.csv')
    args << dr_schedule_heat

    # MAke a string argument for offset magnitude for temperature setpoint DR events
    offset_magnitude_heat = OpenStudio::Measure::OSArgument::makeDoubleArgument('offset_magnitude_heat', true)
    offset_magnitude_heat.setDisplayName('Heating DR Offset Magnitude')
    offset_magnitude_heat.setDescription('The magnitude of the heating setpoint offset, which is applied to non-zero hours specified in the DR schedule. The offset should be positive')
    offset_magnitude_heat.setUnits('degrees F')
    offset_magnitude_heat.setDefaultValue(0)
    args << offset_magnitude_heat

    # make an argument for hourly DR schedule csv file
    dr_schedule_cool = OpenStudio::Measure::OSArgument::makeStringArgument('dr_schedule_cool', true)
    dr_schedule_cool.setDisplayName('Cooling Setpoint DR Schedule File Name')
    dr_schedule_cool.setDescription('File name of the csv that contains hourly DR signals of -1, 0, or 1 for the cooling setpoint schedule.')
    dr_schedule_cool.setDefaultValue('DR_ScheduleCoolSetup.csv')
    args << dr_schedule_cool

    # MAke a string argument for offset magnitude for temperature setpoint DR events
    offset_magnitude_cool = OpenStudio::Measure::OSArgument::makeDoubleArgument('offset_magnitude_cool', true)
    offset_magnitude_cool.setDisplayName('Cooling DR Offset Magnitude')
    offset_magnitude_cool.setDescription('The magnitude of the heating setpoint offset, which is applied to non-zero hours specified in the DR schedule. The offset should be positive')
    offset_magnitude_cool.setUnits('degrees F')
    offset_magnitude_cool.setDefaultValue(0)
    args << offset_magnitude_cool
    return args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    weather = WeatherProcess.new(model, runner)
    if weather.error?
      return false
    end

    # Import data and create DR schedule
    dr_dir = runner.getStringArgumentValue('dr_directory', user_arguments)
    offset_heat = runner.getDoubleArgumentValue('offset_magnitude_heat', user_arguments)
    dr_sch_htg = runner.getStringArgumentValue('dr_schedule_heat', user_arguments)
    offset_cool = runner.getDoubleArgumentValue('offset_magnitude_cool', user_arguments)
    dr_sch_clg = runner.getStringArgumentValue('dr_schedule_cool', user_arguments)

    # Finished Zones
    finished_zones = []
    model.getThermalZones.each do |thermal_zone|
      if Geometry.zone_is_finished(thermal_zone)
        finished_zones << thermal_zone
      end
    end

    # Check for setpoint offset
    if (offset_heat == 0) && (offset_cool == 0)
      runner.registerInfo('DR offset magnitudes are set to zero, no thermostat DR applied')
      return true
    end

    # Check if thermostat exists
    finished_zones.each do |finished_zone|
      thermostat_setpoint = finished_zone.thermostatSetpointDualSetpoint
      next unless !thermostat_setpoint.is_initialized

      runner.registerInfo('No thermostat setpoint defined, skipping demand response applied')
      return true
      break
    end

    year_description = model.getYearDescription
    assumed_year = year_description.assumedYear
    run_period = model.getRunPeriod
    run_period_start = Time.new(assumed_year, run_period.getBeginMonth, run_period.getBeginDayOfMonth)
    run_period_end = Time.new(assumed_year, run_period.getEndMonth, run_period.getEndDayOfMonth, 24)
    sim_hours = (run_period_end - run_period_start) / 3600

    # Import DR Schedule
    def import_DR_sched(dr_dir, dr_sch, sch_name, offset, sim_hours, model, runner)
      path_err = dr_dir + '/' + dr_sch
      unless (Pathname.new dr_dir).absolute?
        dr_dir = File.expand_path(File.join(File.dirname(__FILE__), dr_dir))
      end

      year_description = model.getYearDescription
      assumed_year = year_description.assumedYear
      yr_hrs = Constants.NumHoursInYear(year_description.isLeapYear)
      run_period = model.getRunPeriod
      run_period_start = Time.new(assumed_year, run_period.getBeginMonth, run_period.getBeginDayOfMonth)
      run_period_end = Time.new(assumed_year, run_period.getEndMonth, run_period.getEndDayOfMonth, 24)
      sim_hours = (run_period_end - run_period_start) / 3600
      dr_schedule_file = File.join(dr_dir, dr_sch)

      if File.file?(dr_schedule_file)
        dr_hrly = HourlySchedule.new(model, runner, sch_name, dr_schedule_file, 0, false, [])
        runner.registerInfo("Imported hourly '#{sch_name}' schedule from #{dr_schedule_file}")
        dr_hrly_array = dr_hrly.schedule_array.map { |x| x.to_i }
        dr_hrly.schedule.remove

        if (dr_hrly_array.length == yr_hrs) & (sim_hours != yr_hrs)
          hr_start = run_period_start.yday * 24 - 24
          hr_end = (run_period_end.yday - 1) * 24 - 1
          dr_hrly_array = dr_hrly_array[hr_start..hr_end]
        end

        return dr_hrly_array

      elsif (offset == 0) || (dr_sch == 'none')
        return Array.new(sim_hours, 0)
      else
        err_msg = "File #{dr_sch} does not exist"
        runner.registerError(err_msg)
        return
      end
    end

    # Import user DR schedule and run checks
    dr_hrly_htg = []
    dr_hrly_clg = []
    dr_hrly_clg = import_DR_sched(dr_dir, dr_sch_clg, 'DR Cooling Schedule', offset_cool, sim_hours, model, runner)
    dr_hrly_htg = import_DR_sched(dr_dir, dr_sch_htg, 'DR Heating Schedule', offset_heat, sim_hours, model, runner)
    # Check if file exists (error message in import_DR_sched())
    if dr_hrly_htg.nil?
      return false
    elsif dr_hrly_clg.nil?
      return false
    end

    # Check attributes of imported DR schedules
    def check_DR_sched(dr_hrly, model, runner)
      # Check for invalid DR flags
      if (dr_hrly.to_a - (-1..1).to_a).any?
        runner.registerError('The DR schedule must have values of -1, 0, or 1.')
        return false
      end

      return true
    end

    # Check length of DR schedule
    def check_DR_length(dr_hrly, sim_hours, model, runner)
      year_description = model.getYearDescription
      n_days = Constants.NumDaysInYear(year_description.isLeapYear)
      if (dr_hrly.length != sim_hours) && (dr_hrly.length != n_days * 24)
        runner.registerInfo('Hourly DR schedule length must equal to simulation period or a full year, no thermostat DR applied')
        return false
      end
      return true
    end

    dr_list = []
    offset_list = [dr_hrly_htg, dr_hrly_clg]
    offset_list.each do |dr|
      next unless dr != []

      dr_list << dr
      if not check_DR_sched(dr, model, runner)
        return false
      end

      if not check_DR_length(dr, sim_hours, model, runner)
        return true
      end
    end

    # Check if DR schedules contain only zeros
    ct = 0
    dr_list.each do |dr_hrly|
      next unless ((dr_hrly.to_a.max() == 0) & (dr_hrly.to_a.min() == 0))

      ct += 1
      if ct == dr_list.length
        runner.registerInfo('DR schedules contain only zeros, no thermostat DR applied')
        return true
      end
    end

    # Generates existing hourly schedules
    def get_existing_sched(finished_zones, sched_type, model, runner)
      # Get monthly weekend/weekday 24-hour schedules prior to setpoint inversion fix
      thermostat_setpoint = nil
      wked_monthly, wkdy_monthly = nil, nil
      finished_zones.each do |finished_zone|
        thermostat_setpoint = finished_zone.thermostatSetpointDualSetpoint
        next unless thermostat_setpoint.is_initialized

        thermostat_setpoint = thermostat_setpoint.get
        runner.registerInfo("Found existing thermostat #{thermostat_setpoint.name} for #{finished_zone.name}.")

        if sched_type == 'heat'
          prefix = 'htg'
          thermostat_setpoint.heatingSetpointTemperatureSchedule.get.remove
        elsif sched_type == 'cool'
          prefix = 'clg'
          thermostat_setpoint.coolingSetpointTemperatureSchedule.get.remove
        end

        wked_monthly = [thermostat_setpoint.additionalProperties.getFeatureAsString(prefix + '_wked').get.split(',').map { |i| i.to_f }] * 12
        wkdy_monthly = [thermostat_setpoint.additionalProperties.getFeatureAsString(prefix + '_wkdy').get.split(',').map { |i| i.to_f }] * 12
        break # All zones assumed have same schedule
      end

      # Generate base hourly schedule
      year_description = model.getYearDescription
      day_startm = [0]
      day_endm = [0]
      total_days = 0
      for d in Constants.NumDaysInMonths(year_description.isLeapYear)
        total_days += d
        d_start = total_days - d + 1
        d_end = total_days
        day_startm.push(d_start)
        day_endm.push(d_end)
      end

      day_names = { 'Monday' => 1, 'Tuesday' => 2, 'Wednesday' => 3, 'Thursday' => 4, 'Friday' => 5, 'Saturday' => 6, 'Sunday' => 7 }
      start_day_of_week = model.getYearDescription.dayofWeekforStartDay
      day_num_start = day_names[start_day_of_week]
      day_num = day_num_start
      hr_strt = 0
      hrly_base = []
      for month in 1..12
        daystrt = day_startm[month]
        dayend = day_endm[month]
        for day in daystrt..dayend
          if (day_num == 6) || (day_num == 7)
            hrly_base += wked_monthly[month - 1]
          else
            hrly_base += wkdy_monthly[month - 1]
          end
          hr_strt += 24
          day_num = day_num % 7 + 1
        end
      end
      hrly_base = hrly_base.map { |i| UnitConversions.convert(i, 'C', 'F') }

      year_description = model.getYearDescription
      assumed_year = year_description.assumedYear
      run_period = model.getRunPeriod
      run_period_start = Time.new(assumed_year, run_period.getBeginMonth, run_period.getBeginDayOfMonth)
      run_period_end = Time.new(assumed_year, run_period.getEndMonth, run_period.getEndDayOfMonth, 24)
      hr_start = run_period_start.yday * 24 - 24
      hr_end = (run_period_end - 1).yday * 24 - 1
      hrly_base = hrly_base[hr_start..hr_end]

      return(hrly_base)
    end

    # Apply DR offset & schedule to existing
    def create_new_sched(dr_hrly, hrly_base, offset)
      offset_hrly = dr_hrly.map { |x| x * offset }
      sched_hrly = [hrly_base, offset_hrly].transpose.map { |x| x.reduce(:+) }
      sched_hrly = sched_hrly.map { |i| UnitConversions.convert(i, 'F', 'C') }
      return sched_hrly
    end

    # Adjust for inverted setpoint AFTER DR applied
    def fix_setpoint_inversion(htg_hrly, clg_hrly, hvac, weather, model, runner)
      cooling_season = hvac.get_season(model, weather, runner, Constants.ObjectNameCoolingSeason)
      heating_season = hvac.get_season(model, weather, runner, Constants.ObjectNameHeatingSeason)

      year_description = model.getYearDescription
      run_period = model.getRunPeriod
      start_month = run_period.getBeginMonth - 1
      end_month = run_period.getEndMonth - 1

      day_e = 0
      days_in_month = Constants.NumDaysInMonths(year_description.isLeapYear)
      (start_month..end_month).to_a.each do |i|
        day_s = day_e + 1
        day_e = day_s + days_in_month[i] - 1
        hr1 = (day_s - 1) * 24
        hr2 = day_e * 24 - 1

        htg_hrly_month = htg_hrly[hr1..hr2]
        clg_hrly_month = clg_hrly[hr1..hr2]

        if (heating_season[i] == 1) && (cooling_season[i] == 1)
          htg_hrly[hr1..hr2] = htg_hrly_month.zip(clg_hrly_month).map { |h, c| c < h ? (h + c) / 2.0 : h }
          clg_hrly[hr1..hr2] = htg_hrly_month.zip(clg_hrly_month).map { |h, c| c < h ? (h + c) / 2.0 : c }
        elsif heating_season[i] == 1 # heating only seasons; cooling has minimum of heating
          htg_hrly[hr1..hr2] = htg_hrly_month.zip(clg_hrly_month).map { |h, c| c < h ? h : h }
          clg_hrly[hr1..hr2] = htg_hrly_month.zip(clg_hrly_month).map { |h, c| c < h ? h : c }
        elsif cooling_season[i] == 1 # cooling only seasons; heating has maximum of cooling
          htg_hrly[hr1..hr2] = htg_hrly_month.zip(clg_hrly_month).map { |h, c| c < h ? c : h }
          clg_hrly[hr1..hr2] = htg_hrly_month.zip(clg_hrly_month).map { |h, c| c < h ? c : c }
        end
      end
    end

    def create_OS_sched(sched_hrly, var_name, model, runner)
      year_description = model.getYearDescription
      assumed_year = year_description.assumedYear
      run_period = model.getRunPeriod
      run_period_start = Time.new(assumed_year, run_period.getBeginMonth, run_period.getBeginDayOfMonth)
      start_date = year_description.makeDate(run_period_start.month, run_period_start.day)
      interval = OpenStudio::Time.new(0, 1, 0, 0)
      time_series = OpenStudio::TimeSeries.new(start_date, interval, OpenStudio::createVector(sched_hrly), '')
      schedule = OpenStudio::Model::ScheduleFixedInterval.new(model)
      schedule.setTimeSeries(time_series)
      schedule.setName(var_name)

      return schedule
    end

    # Run functions and apply new schedules
    htg_hrly_base = get_existing_sched(finished_zones, 'heat', model, runner)   # Existing schedule as 12x24
    clg_hrly_base = get_existing_sched(finished_zones, 'cool', model, runner)

    htg_hrly = create_new_sched(dr_hrly_htg, htg_hrly_base, offset_heat)        # New hourly schedule
    clg_hrly = create_new_sched(dr_hrly_clg, clg_hrly_base, offset_cool)

    fix_setpoint_inversion(htg_hrly, clg_hrly, HVAC, weather, model, runner)    # Fix setpoint inversions in new schedules

    htg_hrly = create_OS_sched(htg_hrly, 'HeatingTSP', model, runner)           # Create fixed interval schedule using new hourly schedules
    clg_hrly = create_OS_sched(clg_hrly, 'CoolingTSP', model, runner)

    # Convert back to ruleset and apply to dual thermostat
    winter_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    winter_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), UnitConversions.convert(70, 'F', 'C'))
    summer_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    summer_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), UnitConversions.convert(75, 'F', 'C'))
    rule_sched_h = []
    rule_sched_c = []

    finished_zones.each do |finished_zone|
      thermostat_setpoint = finished_zone.thermostatSetpointDualSetpoint
      next unless thermostat_setpoint.is_initialized

      thermostat_setpoint = thermostat_setpoint.get
      thermostat_setpoint.resetHeatingSetpointTemperatureSchedule()
      thermostat_setpoint.resetCoolingSetpointTemperatureSchedule()

      rule_sched_h = Schedule.ruleset_from_fixedinterval(model, htg_hrly, Constants.ObjectNameHeatingSetpoint, winter_design_day_sch, summer_design_day_sch)
      rule_sched_c = Schedule.ruleset_from_fixedinterval(model, clg_hrly, Constants.ObjectNameCoolingSetpoint, winter_design_day_sch, summer_design_day_sch)

      htg_hrly.remove
      clg_hrly.remove
      break
    end

    # Set heating/cooling setpoint schedules
    finished_zones.each do |finished_zone|
      thermostat_setpoint = finished_zone.thermostatSetpointDualSetpoint
      next unless thermostat_setpoint.is_initialized

      thermostat_setpoint = thermostat_setpoint.get
      thermostat_setpoint.setHeatingSetpointTemperatureSchedule(rule_sched_h)
      runner.registerInfo("Set the heating setpoint schedule for #{thermostat_setpoint.name}.")
      thermostat_setpoint.setCoolingSetpointTemperatureSchedule(rule_sched_c)
      runner.registerInfo("Set the cooling setpoint schedule for #{thermostat_setpoint.name}.")
    end
  end
end
