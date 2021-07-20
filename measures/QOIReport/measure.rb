# frozen_string_literal: true

require 'openstudio'
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
require File.join(resources_path, 'unit_conversions')
require 'enumerator'

# start the measure
class QOIReport < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    return 'QOI Report'
  end

  # human readable description
  def description
    return 'Reports uncertainty quantification quantities of interest.'
  end

  # define the arguments that the user will input
  def arguments
    args = OpenStudio::Measure::OSArgumentVector.new

    return args
  end

  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  # Warning: Do not change the name of this method to be snake_case. The method must be lowerCamelCase.
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    return OpenStudio::IdfObjectVector.new if runner.halted

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    output_meters = OutputMeters.new(model, runner, 'Hourly')
    results = output_meters.create_custom_building_unit_meters

    results << OpenStudio::IdfObject.load('Output:Variable,*,Site Outdoor Air Drybulb Temperature,Hourly;').get

    return results
  end

  def seasons
    return {
      Constants.SeasonHeating => [-1e9, 55],
      Constants.SeasonCooling => [70, 1e9],
      Constants.SeasonOverlap => [55, 70]
    }
  end

  def peak_magnitude_use
    output_names = ['peak_magnitude_use_kw']
    return output_names
  end

  def peak_magnitude_timing
    output_names = ['peak_magnitude_timing_kw']
    return output_names
  end

  def average_daily_base_magnitude_by_season
    output_names = []
    seasons.each do |season, temperature_range|
      output_names << "average_minimum_daily_use_#{season.downcase}_kw"
    end
    return output_names
  end

  def average_daily_peak_magnitude_by_season
    output_names = []
    seasons.each do |season, temperature_range|
      output_names << "average_maximum_daily_use_#{season.downcase}_kw"
    end
    return output_names
  end

  def average_daily_peak_timing_by_season
    output_names = []
    seasons.each do |season, temperature_range|
      output_names << "average_maximum_daily_timing_#{season.downcase}_hour"
    end
    return output_names
  end

  def top_ten_daily_seasonal_peak_magnitude_by_season
    output_names = []
    seasons.each do |season, temperature_range|
      next if season == Constants.SeasonOverlap

      output_names << "average_of_top_ten_highest_peaks_use_#{season.downcase}_kw"
    end
    return output_names
  end

  def top_ten_seasonal_timing_of_peak_by_season
    output_names = []
    seasons.each do |season, temperature_range|
      next if season == Constants.SeasonOverlap

      output_names << "average_of_top_ten_highest_peaks_timing_#{season.downcase}_hour"
    end
    return output_names
  end

  def outputs
    output_names = []
    output_names += peak_magnitude_use
    output_names += peak_magnitude_timing
    output_names += average_daily_base_magnitude_by_season
    output_names += average_daily_peak_magnitude_by_season
    output_names += average_daily_peak_timing_by_season
    output_names += top_ten_daily_seasonal_peak_magnitude_by_season
    output_names += top_ten_seasonal_timing_of_peak_by_season

    result = OpenStudio::Measure::OSOutputVector.new
    output_names.each do |output|
      result << OpenStudio::Measure::OSOutput.makeDoubleOutput(output)
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

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)

    ann_env_pd = nil
    sqlFile.availableEnvPeriods.each do |env_pd|
      env_type = sqlFile.environmentType(env_pd)
      next unless env_type.is_initialized

      if env_type.get == OpenStudio::EnvironmentType.new('WeatherRunPeriod')
        ann_env_pd = env_pd
      end
    end
    if ann_env_pd == false
      runner.registerError("Can't find a weather runperiod, make sure you ran an annual simulation, not just the design days.")
      return false
    end

    # Initialize timeseries hash
    timeseries = { 'Temperature' => [] }

    env_period_ix_query = "SELECT EnvironmentPeriodIndex FROM EnvironmentPeriods WHERE EnvironmentName='#{ann_env_pd}'"
    env_period_ix = sqlFile.execAndReturnFirstInt(env_period_ix_query).get

    temperature_query = "SELECT VariableValue FROM ReportVariableData WHERE ReportVariableDataDictionaryIndex IN (SELECT ReportVariableDataDictionaryIndex FROM ReportVariableDataDictionary WHERE VariableType='Avg' AND VariableName IN ('Site Outdoor Air Drybulb Temperature') AND ReportingFrequency='Hourly' AND VariableUnits='C') AND TimeIndex IN (SELECT TimeIndex FROM Time WHERE EnvironmentPeriodIndex='#{env_period_ix}')"
    unless sqlFile.execAndReturnVectorOfDouble(temperature_query).get.empty?
      temperatures = sqlFile.execAndReturnVectorOfDouble(temperature_query).get
      temperatures.each do |val|
        timeseries['Temperature'] << UnitConversions.convert(val, 'C', 'F')
      end
    end

    output_meters = OutputMeters.new(model, runner, 'Hourly')

    electricity = output_meters.electricity(sqlFile, ann_env_pd)

    # ELECTRICITY

    timeseries['total_site_electricity_kw'] = electricity.total_end_uses.map { |x| UnitConversions.convert(x, 'GJ', 'kW', nil, false, output_meters.steps_per_hour) }

    # Peak magnitude (1)
    report_sim_output(runner, 'peak_magnitude_use_kw', use(timeseries, [-1e9, 1e9], 'max'), '', '')

    # Timing of peak magnitude (1)
    report_sim_output(runner, 'peak_magnitude_timing_kw', timing(timeseries, [-1e9, 1e9], 'max'), '', '')

    # Average daily base magnitude (by season) (3)
    seasons.each do |season, temperature_range|
      report_sim_output(runner, "average_minimum_daily_use_#{season.downcase}_kw", average_daily_use(timeseries, temperature_range, 'min'), '', '')
    end

    # Average daily peak magnitude (by season) (3)
    seasons.each do |season, temperature_range|
      report_sim_output(runner, "average_maximum_daily_use_#{season.downcase}_kw", average_daily_use(timeseries, temperature_range, 'max'), '', '')
    end

    # Average daily peak timing (by season) (3)
    seasons.each do |season, temperature_range|
      report_sim_output(runner, "average_maximum_daily_timing_#{season.downcase}_hour", average_daily_timing(timeseries, temperature_range, 'max'), '', '')
    end

    # Top 10 daily seasonal peak magnitude (2)
    seasons.each do |season, temperature_range|
      next if season == Constants.SeasonOverlap

      report_sim_output(runner, "average_of_top_ten_highest_peaks_use_#{season.downcase}_kw", average_daily_use(timeseries, temperature_range, 'max', 10), '', '')
    end

    # Top 10 seasonal timing of peak (2)
    seasons.each do |season, temperature_range|
      next if season == Constants.SeasonOverlap

      report_sim_output(runner, "average_of_top_ten_highest_peaks_timing_#{season.downcase}_hour", average_daily_timing(timeseries, temperature_range, 'max', 10), '', '')
    end

    sqlFile.close

    return true
  end

  def use(timeseries, temperature_range, min_or_max)
    ''"
    Determines the annual base or peak use value.
    Parameters:
      timeseries (hash): { 'Temperature' => [...], 'total_site_electricity_kw' => [...] }
      temperature_range (array): [lower, upper]
      min_or_max (str): 'min' or 'max'
    Returns:
      base_or_peak: float
    "''
    vals = []
    timeseries['total_site_electricity_kw'].each_with_index do |kw, i|
      temp = timeseries['Temperature'][i]
      if (temp > temperature_range[0]) && (temp < temperature_range[1])
        vals << kw
      end
    end
    if min_or_max == 'min'
      return vals.min
    elsif min_or_max == 'max'
      return vals.max
    end
  end

  def timing(timeseries, temperature_range, min_or_max)
    ''"
    Determines the hour of annual base or peak use value.
    Parameters:
      timeseries (hash): { 'Temperature' => [...], 'total_site_electricity_kw' => [...] }
      temperature_range (array): [lower, upper]
      min_or_max (str): 'min' or 'max'
    Returns:
      base_or_peak: float
    "''
    vals = []
    timeseries['total_site_electricity_kw'].each_with_index do |kw, i|
      temp = timeseries['Temperature'][i]
      if (temp > temperature_range[0]) && (temp < temperature_range[1])
        vals << kw
      end
    end
    if min_or_max == 'min'
      return vals.index(vals.min)
    elsif min_or_max == 'max'
      return vals.index(vals.max)
    end
  end

  def average_daily_use(timeseries, temperature_range, min_or_max, top = 'all')
    ''"
    Calculates the average of daily base or peak use values during heating, cooling, or overlap seasons.
    Parameters:
      timeseries (hash): { 'Temperature' => [...], 'total_site_electricity_kw' => [...] }
      temperature_range (array): [lower, upper]
      min_or_max (str): 'min' or 'max'
      top: integer or 'all'
    Returns:
      average_daily_use: float or nil
    "''
    daily_vals = []
    timeseries['total_site_electricity_kw'].each_slice(24).with_index do |kws, i|
      temps = timeseries['Temperature'][(24 * i)...(24 * i + 24)]
      avg_temp = temps.inject { |sum, el| sum + el }.to_f / temps.size
      if (avg_temp > temperature_range[0]) && (avg_temp < temperature_range[1]) # day is in this season
        if min_or_max == 'min'
          daily_vals << kws.min
        elsif min_or_max == 'max'
          daily_vals << kws.max
        end
      end
    end
    if daily_vals.empty?
      return
    end

    if top == 'all'
      top = daily_vals.length
    else
      top = [top, daily_vals.length].min # don't try to access indexes that don't exist
    end
    daily_vals = daily_vals.sort.reverse
    daily_vals = daily_vals[0..top]
    return daily_vals.inject { |sum, el| sum + el }.to_f / daily_vals.size
  end

  def average_daily_timing(timeseries, temperature_range, min_or_max, top = 'all')
    ''"
    Calculates the average hour of daily base or peak use values during heating, cooling, or overlap seasons.
    Parameters:
      timeseries (hash): { 'Temperature' => [...], 'total_site_electricity_kw' => [...] }
      temperature_range (array): [lower, upper]
      min_or_max (str): 'min' or 'max'
      top: integer or 'all'
    Returns:
      average_daily_use: float or nil
    "''
    daily_vals = { 'hour' => [], 'use' => [] }
    timeseries['total_site_electricity_kw'].each_slice(24).with_index do |kws, i|
      temps = timeseries['Temperature'][(24 * i)...(24 * i + 24)]
      avg_temp = temps.inject { |sum, el| sum + el }.to_f / temps.size
      if (avg_temp > temperature_range[0]) && (avg_temp < temperature_range[1]) # day is in this season
        if min_or_max == 'min'
          hour = kws.index(kws.min)
          daily_vals['hour'] << hour
          daily_vals['use'] << kws.min
        elsif min_or_max == 'max'
          hour = kws.index(kws.max)
          daily_vals['hour'] << hour
          daily_vals['use'] << kws.max
        end
      end
    end
    if daily_vals.empty?
      return
    end

    if top == 'all'
      top = daily_vals['hour'].length
    else
      top = [top, daily_vals['hour'].length].min # don't try to access indexes that don't exist
    end

    if top.zero?
      return
    end

    daily_vals['use'], daily_vals['hour'] = daily_vals['use'].zip(daily_vals['hour']).sort.reverse.transpose
    daily_vals = daily_vals['hour'][0..top]
    return daily_vals.inject { |sum, el| sum + el }.to_f / daily_vals.size
  end

  def report_sim_output(runner, name, total_val, os_units, desired_units, percent_of_val = 1.0)
    if total_val.nil?
      runner.registerInfo("Registering (blank) for #{name}.")
      return
    end
    total_val *= percent_of_val
    if os_units.nil? || desired_units.nil? || (os_units == desired_units)
      valInUnits = total_val
    else
      valInUnits = UnitConversions.convert(total_val, os_units, desired_units)
    end
    runner.registerValue(name, valInUnits)
    runner.registerInfo("Registering #{valInUnits.round(2)} for #{name}.")
  end
end

# register the measure to be used by the application
QOIReport.new.registerWithApplication
