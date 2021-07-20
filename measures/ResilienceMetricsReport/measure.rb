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
require File.join(resources_path, 'util')
require File.join(resources_path, 'unit_conversions')
require File.join(resources_path, 'psychrometrics')

# start the measure
class ResilienceMetricsReport < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Resilience Metrics Report'
  end

  # human readable description
  def description
    return 'Reports resilience metric(s) of interest.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Reports resilience metric(s) of interest.'
  end

  # define the arguments that the user will input
  def arguments
    args = OpenStudio::Measure::OSArgumentVector.new

    # make an argument for optional output variables
    arg = OpenStudio::Measure::OSArgument::makeStringArgument('output_vars', true)
    arg.setDisplayName('Output Variables')
    arg.setDescription('Output variables to request.')
    arg.setDefaultValue('Zone Mean Air Temperature, Wetbulb Globe Temperature')
    args << arg

    # make a double argument for minimum comfortable temperature
    arg = OpenStudio::Measure::OSArgument::makeStringArgument('min_vals', true)
    arg.setDisplayName('Minimum Value')
    arg.setDescription("Lower threshold. Use 'NA' if a lower threshold is not applicable.")
    arg.setDefaultValue('58, NA')
    args << arg

    # make a double argument for maximum comfortable temperature
    arg = OpenStudio::Measure::OSArgument::makeStringArgument('max_vals', true)
    arg.setDisplayName('Maximum Value')
    arg.setDescription("Upper threshold. Use 'NA' if an upper threshold is not applicable.")
    arg.setDefaultValue('NA, 88')
    args << arg

    return args
  end

  # define the outputs that the measure will create
  def outputs
    output_vars = ['Zone Mean Air Temperature', 'Wetbulb Globe Temperature'] # possible list that the user can enter limits for; should get blank column for ones that aren't entered into output_vars arg
    buildstock_outputs = []
    thermal_zones.each do |zone|
      output_vars.each do |output_var|
        buildstock_outputs << "#{OpenStudio::toUnderscoreCase(zone)}_#{OpenStudio::toUnderscoreCase(output_var)}_hours_below_lower_threshold" # hours below lower threshold
        buildstock_outputs << "#{OpenStudio::toUnderscoreCase(zone)}_#{OpenStudio::toUnderscoreCase(output_var)}_hours_above_upper_threshold" # hours above upper threshold
        buildstock_outputs << "#{OpenStudio::toUnderscoreCase(zone)}_#{OpenStudio::toUnderscoreCase(output_var)}_degree_hours_below_lower_threshold" # degree-hours below lower threshold
        buildstock_outputs << "#{OpenStudio::toUnderscoreCase(zone)}_#{OpenStudio::toUnderscoreCase(output_var)}_degree_hours_above_upper_threshold" # degree-hours above upper threshold
        buildstock_outputs << "#{OpenStudio::toUnderscoreCase(zone)}_#{OpenStudio::toUnderscoreCase(output_var)}_hours_until_lower_threshold" # hours until lower threshold
        buildstock_outputs << "#{OpenStudio::toUnderscoreCase(zone)}_#{OpenStudio::toUnderscoreCase(output_var)}_hours_until_upper_threshold" # hours until upper threshold
      end
      # buildstock_outputs << "#{OpenStudio::toUnderscoreCase(zone)}_#{OpenStudio::toUnderscoreCase("End Of Outage Indoor Drybulb Temperature")}"
      buildstock_outputs << "#{OpenStudio::toUnderscoreCase(zone)}_#{OpenStudio::toUnderscoreCase('Maximum Wetbulb Globe Temperature During Outage')}"
      buildstock_outputs << "#{OpenStudio::toUnderscoreCase(zone)}_#{OpenStudio::toUnderscoreCase('Minimum Indoor Drybulb Temperature During Outage')}"
      buildstock_outputs << "#{OpenStudio::toUnderscoreCase(zone)}_#{OpenStudio::toUnderscoreCase('Maximum Indoor Drybulb Temperature During Outage')}"
    end
    buildstock_outputs << 'outage_start_datetime'
    buildstock_outputs << 'outage_duration_hours'
    result = OpenStudio::Measure::OSOutputVector.new
    buildstock_outputs.each do |output|
      result << OpenStudio::Measure::OSOutput.makeDoubleOutput(output)
    end
    return result
  end

  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  # Warning: Do not change the name of this method to be snake_case. The method must be lowerCamelCase.
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    result = OpenStudio::IdfObjectVector.new

    # use the built-in error checking
    if !runner.validateUserArguments(arguments, user_arguments)
      return result
    end

    output_vars = runner.getStringArgumentValue('output_vars', user_arguments).split(',')

    output_vars.each do |output_var|
      output_var.strip!
      if output_var == 'Wetbulb Globe Temperature'
        requests = wbgt_vars
      else
        requests = [output_var]
      end
      requests.each do |request|
        result << OpenStudio::IdfObject.load("Output:Variable,*,#{request},Hourly;").get
      end
    end

    return result
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments, user_arguments)
      return false
    end

    # Assign the user inputs to variables
    output_vars = runner.getStringArgumentValue('output_vars', user_arguments).split(',')
    min_vals = runner.getStringArgumentValue('min_vals', user_arguments).split(',')
    max_vals = runner.getStringArgumentValue('max_vals', user_arguments).split(',')

    # Error checking
    if (output_vars.length != min_vals.length) || (output_vars.length != max_vals.length)
      runner.registerError('Number of output variable elements specified inconsistent with either number of minimum or maximum values.')
      return false
    end

    # Get the last model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    # Get the last sql file
    sql = runner.lastEnergyPlusSqlFile
    if sql.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sql = sql.get
    model.setSqlFile(sql)

    # Get the weather file run period (as opposed to design day run period)
    ann_env_pd = nil
    sql.availableEnvPeriods.each do |env_pd|
      env_type = sql.environmentType(env_pd)
      next unless env_type.is_initialized

      if env_type.get == OpenStudio::EnvironmentType.new('WeatherRunPeriod')
        ann_env_pd = env_pd
      end
    end
    if ann_env_pd == false
      runner.registerError("Can't find a weather runperiod, make sure you ran an annual simulation, not just the design days.")
      return false
    end

    # Get the outage start and end indexes
    ix_outage_start, ix_outage_end = get_outage_indexes(model, runner)
    if ix_outage_start.nil? && ix_outage_end.nil? # there is no outage
      return true
    end

    timeseries = {}
    key_values = []
    output_vars.each do |output_var|
      output_var.strip!
      if output_var == 'Wetbulb Globe Temperature'
        requests = wbgt_vars
      else
        requests = [output_var]
      end

      requests.each do |request|
        sql.availableKeyValues(ann_env_pd, 'Hourly', request).each do |key_value|
          if key_value != 'Environment'
            next unless thermal_zones.any? { |zone| zone.casecmp(key_value) == 0 }
          end

          timeserie = get_timeseries(sql, ann_env_pd, request, key_value)
          unless timeserie
            runner.registerError("No data found for #{key_value} #{request}.")
            return false
          end

          timeseries["#{request},#{key_value}"] = timeserie
          next if key_value == 'Environment'

          unless key_values.include? key_value
            key_values << key_value
          end
        end
      end
    end

    output_vars.each_with_index do |output_var, i|
      output_var.strip!
      key_values.each do |key_value|
        if output_var == 'Wetbulb Globe Temperature'
          tdb = timeseries["Zone Mean Air Temperature,#{key_value}"]
          w = timeseries["Zone Air Humidity Ratio,#{key_value}"]
          pr = timeseries['Site Outdoor Air Barometric Pressure,Environment']
          mrt = timeseries["Zone Mean Radiant Temperature,#{key_value}"]
          twb = OutputVariables.zone_indoor_air_wetbulb_temperature(tdb, w, pr)
          timeseries["#{output_var},#{key_value}"] = OutputVariables.wetbulb_globe_temperature(twb, mrt)
        end

        # Hours above or below threshold

        resilience_metric_below, resilience_metric_above = calc_resilience_metric(output_var, timeseries["#{output_var},#{key_value}"], min_vals[i].strip, max_vals[i].strip, ix_outage_start, ix_outage_end)

        unless resilience_metric_below.nil?
          report_output(runner, "#{key_value} #{output_var} hours below lower threshold", resilience_metric_below, 'hours')
        end

        unless resilience_metric_above.nil?
          report_output(runner, "#{key_value} #{output_var} hours above upper threshold", resilience_metric_above, 'hours')
        end

        # Degree-hours above or below threshold

        resilience_metric_below, resilience_metric_above = calc_resilience_metric(output_var, timeseries["#{output_var},#{key_value}"], min_vals[i].strip, max_vals[i].strip, ix_outage_start, ix_outage_end, true)

        unless resilience_metric_below.nil?
          report_output(runner, "#{key_value} #{output_var} degree hours below lower threshold", resilience_metric_below, 'degree-hours')
        end

        unless resilience_metric_above.nil?
          report_output(runner, "#{key_value} #{output_var} degree hours above upper threshold", resilience_metric_above, 'degree-hours')
        end

        # Coast times until outage

        coast_time_below, coast_time_above = calc_coast_time(output_var, timeseries["#{output_var},#{key_value}"], min_vals[i].strip, max_vals[i].strip, ix_outage_start, ix_outage_end)

        unless coast_time_below.nil?
          report_output(runner, "#{key_value} #{output_var} hours until lower threshold", coast_time_below, 'hours')
        end

        unless coast_time_above.nil?
          report_output(runner, "#{key_value} #{output_var} hours until upper threshold", coast_time_above, 'hours')
        end
      end
    end

    # Additional annual reporting variables
    key_values.each do |key_value|
      # End Of Outage Indoor Drybulb Temperature
      # values = timeseries["Zone Mean Air Temperature,#{key_value}"]
      # end_of_outage_indoor_drybulb_temperature = calc_end_of_outage_val("End Of Outage Indoor Drybulb Temperature", values, ix_outage_end)
      # report_output(runner, "#{key_value} End Of Outage Indoor Drybulb Temperature", end_of_outage_indoor_drybulb_temperature, "F")

      # Maximum Wetbulb Globe Temperature During Outage
      values = timeseries["Wetbulb Globe Temperature,#{key_value}"]
      maximum_wetbulb_globe_temperature_during_outage = calc_maximum_during_outage_val('Maximum Wetbulb Globe Temperature During Outage', values, ix_outage_start, ix_outage_end)
      report_output(runner, "#{key_value} Maximum Wetbulb Globe Temperature During Outage", maximum_wetbulb_globe_temperature_during_outage, 'F')

      # Minimum Indoor Drybulb Temperature During Outage
      values = timeseries["Zone Mean Air Temperature,#{key_value}"]
      minimum_indoor_drybulb_temperature_during_outage = calc_minimum_during_outage_val('Minimum Indoor Drybulb Temperature During Outage', values, ix_outage_start, ix_outage_end)
      report_output(runner, "#{key_value} Minimum Indoor Drybulb Temperature During Outage", minimum_indoor_drybulb_temperature_during_outage, 'F')

      # Maximum Indoor Drybulb Temperature During Outage
      values = timeseries["Zone Mean Air Temperature,#{key_value}"]
      maximum_indoor_drybulb_temperature_during_outage = calc_maximum_during_outage_val('Maximum Indoor Drybulb Temperature During Outage', values, ix_outage_start, ix_outage_end)
      report_output(runner, "#{key_value} Maximum Indoor Drybulb Temperature During Outage", maximum_indoor_drybulb_temperature_during_outage, 'F')
    end

    sql.close()

    return true
  end

  def get_outage_indexes(model, runner)
    year_description = model.getYearDescription
    additional_properties = year_description.additionalProperties
    power_outage_start_date = additional_properties.getFeatureAsString('PowerOutageStartDate')
    power_outage_start_hour = additional_properties.getFeatureAsInteger('PowerOutageStartHour')
    power_outage_duration = additional_properties.getFeatureAsInteger('PowerOutageDuration')

    unless power_outage_start_date.is_initialized
      runner.registerWarning("Could not find power outage start date on additional properties object. Need to apply the 'Outages' measure first.")
      return nil, nil
    end
    power_outage_start_date = power_outage_start_date.get

    unless power_outage_start_hour.is_initialized
      runner.registerWarning("Could not find power outage start hour on additional properties object. Need to apply the 'Outages' measure first.")
      return nil, nil
    end
    power_outage_start_hour = power_outage_start_hour.get

    unless power_outage_duration.is_initialized
      runner.registerWarning("Could not find power outage duration on additional properties object. Need to apply the 'Outages' measure first.")
      return nil, nil
    end
    power_outage_duration = power_outage_duration.get

    # Additional reporting metadata

    report_output(runner, 'Outage Start Datetime', "#{power_outage_start_date} #{power_outage_start_hour.to_i.to_s.rjust(2, '0')}:00:00", 'datetime')
    report_output(runner, 'Outage Duration Hours', power_outage_duration.to_i.to_s, 'hours')

    # Get outage start and end indexes

    otg_start_date_month, otg_start_date_day = power_outage_start_date.split
    otg_start_date_month = OpenStudio::monthOfYear(otg_start_date_month)
    otg_start_date_day = otg_start_date_day.to_i

    leap_offset = 0
    if year_description.isLeapYear
      leap_offset = 1
    end

    months = [OpenStudio::monthOfYear('January'), OpenStudio::monthOfYear('February'), OpenStudio::monthOfYear('March'), OpenStudio::monthOfYear('April'), OpenStudio::monthOfYear('May'), OpenStudio::monthOfYear('June'), OpenStudio::monthOfYear('July'), OpenStudio::monthOfYear('August'), OpenStudio::monthOfYear('September'), OpenStudio::monthOfYear('October'), OpenStudio::monthOfYear('November'), OpenStudio::monthOfYear('December')]
    startday_m = [0, 31, 59 + leap_offset, 90 + leap_offset, 120 + leap_offset, 151 + leap_offset, 181 + leap_offset, 212 + leap_offset, 243 + leap_offset, 273 + leap_offset, 304 + leap_offset, 334 + leap_offset, 365 + leap_offset]
    m_idx = 0
    for m in months
      if m == otg_start_date_month
        otg_start_date_day += startday_m[m_idx]
      end
      m_idx += 1
    end

    ix_outage_start = 24 * (otg_start_date_day - 1) + power_outage_start_hour.to_i
    ix_outage_end = ix_outage_start + power_outage_duration.to_i - 1

    runner.registerInfo("Found the outage start index to be #{ix_outage_start}.")
    runner.registerInfo("Found the outage end index to be #{ix_outage_end}.")

    return ix_outage_start, ix_outage_end
  end

  def thermal_zones
    return ['Living Zone', 'Finished Basement Zone']
  end

  def f_to_c_vars
    return ['Zone Mean Air Temperature', 'Wetbulb Globe Temperature']
  end

  def c_to_f_vars
    return ['End Of Outage Indoor Drybulb Temperature', 'Maximum Wetbulb Globe Temperature During Outage', 'Minimum Indoor Drybulb Temperature During Outage', 'Maximum Indoor Drybulb Temperature During Outage']
  end

  def wbgt_vars
    return ['Zone Mean Air Temperature', 'Zone Air Humidity Ratio', 'Site Outdoor Air Barometric Pressure', 'Zone Mean Radiant Temperature']
  end

  def convert_val(output_var, val)
    unless val == 'NA'
      val = val.to_f
      if f_to_c_vars.include? output_var
        val = UnitConversions.convert(val, 'F', 'C')
      elsif c_to_f_vars.include? output_var
        val = UnitConversions.convert(val, 'C', 'F')
      end
    end
    return val
  end

  def calc_resilience_metric(output_var, values, min_val, max_val, ix_outage_start, ix_outage_end, degree_hours = false) # hours spend below, above specified thresholds
    min_val = convert_val(output_var, min_val)
    max_val = convert_val(output_var, max_val)

    min_val == 'NA' ? resilience_metric_below = nil : resilience_metric_below = 0
    unless resilience_metric_below.nil?
      (ix_outage_start..ix_outage_end).to_a.each do |i|
        if values[i] < min_val
          if not degree_hours
            resilience_metric_below += 1
          else
            resilience_metric_below += min_val - values[i]
          end
        end
      end
    end

    max_val == 'NA' ? resilience_metric_above = nil : resilience_metric_above = 0
    unless resilience_metric_above.nil?
      (ix_outage_start..ix_outage_end).to_a.each do |i|
        if values[i] > max_val
          if not degree_hours
            resilience_metric_above += 1
          else
            resilience_metric_above += values[i] - max_val
          end
        end
      end
    end

    return resilience_metric_below, resilience_metric_above
  end

  def calc_coast_time(output_var, values, min_val, max_val, ix_outage_start, ix_outage_end) # hours until hitting below, above specified thresholds
    min_val = convert_val(output_var, min_val)
    max_val = convert_val(output_var, max_val)

    min_val == 'NA' ? coast_time_below = nil : coast_time_below = 0
    hit_below = false
    unless coast_time_below.nil?
      (ix_outage_start..ix_outage_end).to_a.each do |i|
        coast_time_below += 1
        if values[i] <= min_val
          hit_below = true
          break
        end
      end
    end

    unless hit_below
      coast_time_below = nil
    end

    max_val == 'NA' ? coast_time_above = nil : coast_time_above = 0
    hit_above = false
    unless coast_time_above.nil?
      (ix_outage_start..ix_outage_end).to_a.each do |i|
        coast_time_above += 1
        if values[i] >= max_val
          hit_above = true
          break
        end
      end
    end

    unless hit_above
      coast_time_above = nil
    end

    return coast_time_below, coast_time_above
  end

  def calc_end_of_outage_val(output_var, values, ix_outage_end)
    val = values[ix_outage_end]
    val = convert_val(output_var, val)
    return val
  end

  def calc_maximum_during_outage_val(output_var, values, ix_outage_start, ix_outage_end)
    values = values[ix_outage_start..ix_outage_end]
    val = convert_val(output_var, values.max)
    return val
  end

  def calc_minimum_during_outage_val(output_var, values, ix_outage_start, ix_outage_end)
    values = values[ix_outage_start..ix_outage_end]
    val = convert_val(output_var, values.min)
    return val
  end

  def get_timeseries(sql, ann_env_pd, request, key_value)
    timeseries = sql.timeSeries(ann_env_pd, 'Hourly', request, key_value)
    if timeseries.empty?
      return false
    else
      values = timeseries.get.values
    end

    timeseries = []
    (0...values.length).to_a.each do |i|
      timeseries << values[i]
    end
    return timeseries
  end

  def report_output(runner, name, val, units)
    runner.registerValue(name, val)
    runner.registerInfo("Registering #{val} #{units} for #{name}.")
  end
end

# register the measure to be used by the application
ResilienceMetricsReport.new.registerWithApplication
