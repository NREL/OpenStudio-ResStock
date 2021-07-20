# frozen_string_literal: true

require_relative 'psychrometrics'
require_relative 'constants'
require_relative 'unit_conversions'

class WeatherHeader
  def initialize
  end
  ATTRS ||= [:City, :State, :Country, :DataSource, :Station, :Latitude, :Longitude, :Timezone, :Altitude, :LocalPressure, :RecordsPerHour]
  attr_accessor(*ATTRS)
end

class WeatherData
  def initialize
  end
  ATTRS ||= [:AnnualAvgDrybulb, :AnnualMinDrybulb, :AnnualMaxDrybulb, :CDD50F, :CDD65F, :HDD50F, :HDD65F, :AnnualAvgWindspeed, :MonthlyAvgDrybulbs, :GroundMonthlyTemps, :WSF, :MonthlyAvgDailyHighDrybulbs, :MonthlyAvgDailyLowDrybulbs]
  attr_accessor(*ATTRS)
end

class WeatherDesign
  def initialize
  end
  ATTRS ||= [:HeatingDrybulb, :HeatingWindspeed, :CoolingDrybulb, :CoolingWetbulb, :CoolingHumidityRatio, :CoolingWindspeed, :DailyTemperatureRange, :DehumidDrybulb, :DehumidHumidityRatio, :CoolingDirectNormal, :CoolingDiffuseHorizontal]
  attr_accessor(*ATTRS)
end

class WeatherProcess
  def initialize(model, runner)
    @error = false

    @model = model
    @runner = runner

    @header = WeatherHeader.new
    @data = WeatherData.new
    @design = WeatherDesign.new

    @epw_path = WeatherProcess.get_epw_path(@model, @runner)
    if @epw_path.nil?
      @error = true
      return
    end

    if not File.exist?(@epw_path)
      @runner.registerError("Cannot find weather file at #{epw_path}.")
      @error = true
      return
    end

    @epw_file = OpenStudio::EpwFile.new(@epw_path, true)

    cached = get_cached_weather(@model)
    return if cached || @error

    process_epw

    cache_weather(@model)
  end

  def epw_path
    return @epw_path
  end

  def add_design_days_for_autosizing
    heating_design_day = OpenStudio::Model::DesignDay.new(@model)
    heating_design_day.setName('Ann Htg 99% Condns DB')
    heating_design_day.setMaximumDryBulbTemperature(UnitConversions.convert(@design.HeatingDrybulb, 'F', 'C'))
    heating_design_day.setHumidityIndicatingConditionsAtMaximumDryBulb(UnitConversions.convert(@design.HeatingDrybulb, 'F', 'C'))
    heating_design_day.setBarometricPressure(UnitConversions.convert(Psychrometrics.Pstd_fZ(@header.Altitude), 'psi', 'pa'))
    heating_design_day.setWindSpeed(@design.HeatingWindspeed)
    heating_design_day.setDayOfMonth(21)
    heating_design_day.setMonth(1)
    heating_design_day.setDayType('WinterDesignDay')
    heating_design_day.setHumidityIndicatingType('Wetbulb')
    heating_design_day.setDryBulbTemperatureRangeModifierType('DefaultMultipliers')
    heating_design_day.setSolarModelIndicator('ASHRAEClearSky')

    cooling_design_day = OpenStudio::Model::DesignDay.new(@model)
    cooling_design_day.setName('Ann Clg 1% Condns DB=>MWB')
    cooling_design_day.setMaximumDryBulbTemperature(UnitConversions.convert(@design.CoolingDrybulb, 'F', 'C'))
    cooling_design_day.setDailyDryBulbTemperatureRange(UnitConversions.convert(@design.DailyTemperatureRange, 'R', 'K'))
    cooling_design_day.setHumidityIndicatingConditionsAtMaximumDryBulb(UnitConversions.convert(@design.CoolingWetbulb, 'F', 'C'))
    cooling_design_day.setBarometricPressure(UnitConversions.convert(Psychrometrics.Pstd_fZ(@header.Altitude), 'psi', 'pa'))
    cooling_design_day.setWindSpeed(@design.CoolingWindspeed)
    cooling_design_day.setDayOfMonth(21)
    cooling_design_day.setMonth(7)
    cooling_design_day.setDayType('SummerDesignDay')
    cooling_design_day.setHumidityIndicatingType('Wetbulb')
    cooling_design_day.setDryBulbTemperatureRangeModifierType('DefaultMultipliers')
    cooling_design_day.setSolarModelIndicator('ASHRAEClearSky')
  end

  def get_days_for_month(month, is_leap_year)
    if [1, 3, 5, 7, 8, 10, 12].include? month
      days = (1..31)
    elsif [4, 6, 9, 11].include? month
      days = (1..30)
    elsif [2].include? month
      days = (1..(28 + is_leap_year))
    end
  end

  def actual_year_timestamps(reporting_frequency, run_period_control_daylight_saving_time, dst_start_datetime,
                             dst_end_datetime, utc_offset_hr_float)
    start_actual_year = @epw_file.startDateActualYear
    end_actual_year = @epw_file.endDateActualYear
    utc_offset_sec = (utc_offset_hr_float * 60 * 60).to_i
    unless run_period_control_daylight_saving_time.nil?
      dst_start_date = dst_start_datetime.date
      dst_start_time = dst_start_datetime.time
      dst_end_date = dst_end_datetime.date
      dst_end_time = dst_end_datetime.time
    end

    timestamps = []
    dst_timestamps = []
    utc_timestamps = []
    if start_actual_year.is_initialized && end_actual_year.is_initialized
      start_actual_year = start_actual_year.get
      end_actual_year = end_actual_year.get
      is_leap_year = { true => 1, false => 0 }[@model.getYearDescription.isLeapYear]

      run_period = @model.getRunPeriod
      start_time = Time.utc(start_actual_year, run_period.getBeginMonth, run_period.getBeginDayOfMonth, 0, 1)
      end_time = Time.utc(end_actual_year, run_period.getEndMonth, run_period.getEndDayOfMonth, 24)

      if reporting_frequency == 'Timestep'
        tstep = @model.getTimestep.numberOfTimestepsPerHour

        unless run_period_control_daylight_saving_time.nil?
          dst_start_ts = Time.utc(dst_start_date.year, dst_start_date.monthOfYear.value, dst_start_date.dayOfMonth, dst_start_time.hours, dst_start_time.minutes)
          dst_end_ts = Time.utc(dst_end_date.year, dst_end_date.monthOfYear.value, dst_end_date.dayOfMonth, dst_end_time.hours, dst_end_time.minutes)
        end

        (start_actual_year..(end_actual_year + 1)).to_a.each do |year|
          (1..12).to_a.each do |month|
            days = get_days_for_month(month, is_leap_year)
            days.to_a.each do |day|
              (0..23).to_a.each do |hour|
                (0..60 - (60 / tstep)).step(60 / tstep).to_a.each do |minute|
                  ts = Time.utc(year, month, day, hour, minute)
                  next if (ts < start_time) || (ts > end_time)

                  timestamps << ts.strftime('%Y/%m/%d %H:%M:00')
                  utc_timestamps << (ts - utc_offset_sec).strftime('%Y/%m/%d %H:%M:00')
                  next if run_period_control_daylight_saving_time.nil?

                  if (ts >= dst_start_ts) && (ts < dst_end_ts)
                    dst_ts = ts + 60 * 60 # 1 hr shift forward
                    dst_timestamps << dst_ts.strftime('%Y/%m/%d %H:%M:00')
                  else
                    dst_timestamps << ts.strftime('%Y/%m/%d %H:%M:00')
                  end
                end
              end
            end
          end
        end
      elsif reporting_frequency == 'Hourly'
        unless run_period_control_daylight_saving_time.nil?
          dst_start_ts = Time.utc(dst_start_date.year, dst_start_date.monthOfYear.value, dst_start_date.dayOfMonth, dst_start_time.hours)
          dst_end_ts = Time.utc(dst_end_date.year, dst_end_date.monthOfYear.value, dst_end_date.dayOfMonth, dst_end_time.hours)
        end

        (start_actual_year..end_actual_year).to_a.each do |year|
          (1..12).to_a.each do |month|
            days = get_days_for_month(month, is_leap_year)
            days.to_a.each do |day|
              (1..24).to_a.each do |hour|
                ts = Time.utc(year, month, day, hour)

                next if (ts < start_time) || (ts > end_time)

                timestamps << ts.strftime('%Y/%m/%d %H:00:00')
                utc_timestamps << (ts - utc_offset_sec).strftime('%Y/%m/%d %H:%M:00')

                next if run_period_control_daylight_saving_time.nil?

                if (ts >= dst_start_ts) && (ts < dst_end_ts)
                  dst_ts = ts + 60 * 60 # 1 hr shift forward
                  dst_timestamps << dst_ts.strftime('%Y/%m/%d %H:00:00')
                else
                  dst_timestamps << ts.strftime('%Y/%m/%d %H:00:00')
                end
              end
            end
          end
        end
      elsif reporting_frequency == 'Daily'
        unless run_period_control_daylight_saving_time.nil?
          dst_start_ts = Time.utc(dst_start_date.year, dst_start_date.monthOfYear.value, dst_start_date.dayOfMonth)
          dst_end_ts = Time.utc(dst_end_date.year, dst_end_date.monthOfYear.value, dst_end_date.dayOfMonth)
        end

        (start_actual_year..end_actual_year + 1).to_a.each do |year|
          (1..12).to_a.each do |month|
            days = get_days_for_month(month, is_leap_year)
            days.to_a.each do |day|
              ts = Time.utc(year, month, day)
              next if (ts < start_time) || (ts > end_time)

              timestamps << ts.strftime('%Y/%m/%d 00:00:00')
              utc_timestamps << (ts - utc_offset_sec).strftime('%Y/%m/%d %H:%M:00')
              next if run_period_control_daylight_saving_time.nil?

              if (ts >= dst_start_ts) && (ts < dst_end_ts)
                dst_ts = ts + 60 * 60 # 1 hr shift forward
                dst_timestamps << dst_ts.strftime('%Y/%m/%d 00:00:00')
              else
                dst_timestamps << ts.strftime('%Y/%m/%d 00:00:00')
              end
            end
          end
        end
      elsif reporting_frequency == 'Monthly'
        unless run_period_control_daylight_saving_time.nil?
          dst_start_ts = Time.utc(dst_start_date.year, dst_start_date.monthOfYear.value)
          dst_end_ts = Time.utc(dst_end_date.year, dst_end_date.monthOfYear.value)
        end

        (start_actual_year..end_actual_year + 1).to_a.each do |year|
          (1..12).to_a.each do |month|
            ts = Time.utc(year, month)
            next if (ts < start_time) || (ts > end_time)

            timestamps << ts.strftime('%Y/%m/01 00:00:00')
            utc_timestamps << (ts - utc_offset_sec).strftime('%Y/%m/%d %H:%M:00')
            next if run_period_control_daylight_saving_time.nil?

            if (ts >= dst_start_ts) && (ts < dst_end_ts)
              dst_ts = ts + 60 * 60 # 1 hr shift forward
              dst_timestamps << dst_ts.strftime('%Y/%m/01 00:00:00')
            else
              dst_timestamps << ts.strftime('%Y/%m/01 00:00:00')
            end
          end
        end
      elsif reporting_frequency == 'Runperiod'
        unless run_period_control_daylight_saving_time.nil?
          dst_start_ts = Time.utc(dst_start_date.year)
          dst_end_ts = Time.utc(dst_end_date.year)
        end

        ts = Time.utc(end_actual_year + 1)
        timestamps << ts.strftime('%Y/01/01 00:00:00')
        utc_timestamps << (ts - utc_offset_sec).strftime('%Y/%m/%d %H:%M:00')
        unless run_period_control_daylight_saving_time.nil?
          if (ts >= dst_start_ts) && (ts < dst_end_ts)
            dst_ts = ts + 60 * 60 # 1 hr shift forward
            dst_timestamps << dst_ts.strftime('%Y/01/01 00:00:00')
          else
            dst_timestamps << ts.strftime('%Y/01/01 00:00:00')
          end
        end
      end
    end
    return timestamps, dst_timestamps, utc_timestamps
  end

  def error?
    return @error
  end

  def cache_weather(model)
    wf_ap = model.weatherFile.get.additionalProperties

    # Header
    WeatherHeader::ATTRS.each do |k|
      k = k.to_s
      # string
      if ['City', 'State', 'Country', 'DataSource', 'Station'].include? k
        wf_ap.setFeature("EPWHeader#{k}", @header.send(k).to_s)
      # double
      elsif ['Latitude', 'Longitude', 'Timezone', 'Altitude', 'LocalPressure', 'RecordsPerHour'].include? k
        wf_ap.setFeature("EPWHeader#{k}", @header.send(k).to_f)
      else
        @runner.registerError("Weather header key #{k} not handled.")
        @error = true
        return false
      end
    end

    # Data
    WeatherData::ATTRS.each do |k|
      k = k.to_s
      # double
      if ['AnnualAvgDrybulb', 'AnnualMinDrybulb', 'AnnualMaxDrybulb', 'CDD50F', 'CDD65F',
          'HDD50F', 'HDD65F', 'AnnualAvgWindspeed', 'WSF'].include? k
        wf_ap.setFeature("EPWData#{k}", @data.send(k).to_f)
      # array
      elsif ['MonthlyAvgDrybulbs', 'GroundMonthlyTemps',
             'MonthlyAvgDailyHighDrybulbs', 'MonthlyAvgDailyLowDrybulbs'].include? k
        wf_ap.setFeature("EPWData#{k}", @data.send(k).join(','))
      else
        @runner.registerError("Weather data key #{k} not handled.")
        @error = true
        return false
      end
    end

    # Design
    WeatherDesign::ATTRS.each do |k|
      k = k.to_s
      # double
      wf_ap.setFeature("EPWDesign#{k}", @design.send(k).to_f)
    end
  end

  def marshal_dump
    return [@header, @data, @design]
  end

  def marshal_load(array)
    @header, @data, @design = array
  end

  attr_accessor(:header, :data, :design)

  private

  def self.get_epw_path(model, runner)
    if model.weatherFile.is_initialized

      wf = model.weatherFile.get
      # Sometimes path is available, sometimes just url. Should be improved in OS 2.0.
      if wf.path.is_initialized
        epw_path = wf.path.get.to_s
      else
        epw_path = wf.url.to_s.sub('file:///', '').sub('file://', '').sub('file:', '')
      end
      if not File.exist? epw_path
        epw_path = File.absolute_path(File.join(File.dirname(__FILE__), epw_path))
      end
      return epw_path
    end

    runner.registerError('Model has not been assigned a weather file.')
    return
  end

  def get_cached_weather(model)
    wf_ap = model.weatherFile.get.additionalProperties

    # Header
    WeatherHeader::ATTRS.each do |k|
      k = k.to_s
      # string
      if ['City', 'State', 'Country', 'DataSource', 'Station'].include? k
        @header.send(k + '=', wf_ap.getFeatureAsString("EPWHeader#{k}"))
        return false if !@header.send(k).is_initialized

        @header.send(k + '=', @header.send(k).get)
      # double
      elsif ['Latitude', 'Longitude', 'Timezone', 'Altitude', 'LocalPressure', 'RecordsPerHour'].include? k
        @header.send(k + '=', wf_ap.getFeatureAsDouble("EPWHeader#{k}"))
        return false if !@header.send(k).is_initialized

        @header.send(k + '=', @header.send(k).get)
      else
        @runner.registerError("Weather header key #{k} not handled.")
        @error = true
        return false
      end
    end

    # Data
    WeatherData::ATTRS.each do |k|
      k = k.to_s
      # double
      if ['AnnualAvgDrybulb', 'AnnualMinDrybulb', 'AnnualMaxDrybulb', 'CDD50F', 'CDD65F',
          'HDD50F', 'HDD65F', 'AnnualAvgWindspeed', 'WSF'].include? k
        @data.send(k + '=', wf_ap.getFeatureAsDouble("EPWData#{k}"))
        return false if !@data.send(k).is_initialized

        @data.send(k + '=', @data.send(k).get)
      # array
      elsif ['MonthlyAvgDrybulbs', 'GroundMonthlyTemps',
             'MonthlyAvgDailyHighDrybulbs', 'MonthlyAvgDailyLowDrybulbs'].include? k
        @data.send(k + '=', wf_ap.getFeatureAsString("EPWData#{k}"))
        return false if !@data.send(k).is_initialized

        @data.send(k + '=', @data.send(k).get.split(',').map(&:to_f))
      else
        @runner.registerError("Weather data key #{k} not handled.")
        @error = true
        return false
      end
    end

    # Design
    WeatherDesign::ATTRS.each do |k|
      k = k.to_s
      # double
      @design.send(k + '=', wf_ap.getFeatureAsDouble("EPWDesign#{k}"))
      return false if !@design.send(k).is_initialized

      @design.send(k + '=', @design.send(k).get)
    end

    return true
  end

  def process_epw
    # Header info:
    @header.City = @epw_file.city
    @header.State = @epw_file.stateProvinceRegion
    @header.Country = @epw_file.country
    @header.DataSource = @epw_file.dataSource
    @header.Station = @epw_file.wmoNumber
    @header.Latitude = @epw_file.latitude
    @header.Longitude = @epw_file.longitude
    @header.Timezone = @epw_file.timeZone
    @header.Altitude = UnitConversions.convert(@epw_file.elevation, 'm', 'ft')
    @header.LocalPressure = Math::exp(-0.0000368 * @header.Altitude) # atm
    @header.RecordsPerHour = @epw_file.recordsPerHour

    epw_file_data = @epw_file.data

    epwHasDesignData = get_design_info_from_epw

    # Timeseries data:
    rowdata = []
    dailydbs = []
    dailyhighdbs = []
    dailylowdbs = []
    epw_file_data.each_with_index do |epwdata, rownum|
      rowdict = {}
      rowdict['month'] = epwdata.month
      rowdict['day'] = epwdata.day
      rowdict['hour'] = epwdata.hour
      if epwdata.dryBulbTemperature.is_initialized
        rowdict['db'] = epwdata.dryBulbTemperature.get
      else
        @runner.registerError("Cannot retrieve dryBulbTemperature from the EPW for hour #{rownum + 1}.")
        @error = true
      end
      if epwdata.dewPointTemperature.is_initialized
        rowdict['dp'] = epwdata.dewPointTemperature.get
      else
        @runner.registerError("Cannot retrieve dewPointTemperature from the EPW for hour #{rownum + 1}.")
        @error = true
      end
      if epwdata.relativeHumidity.is_initialized
        rowdict['rh'] = epwdata.relativeHumidity.get / 100.0
      else
        @runner.registerError("Cannot retrieve relativeHumidity from the EPW for hour #{rownum + 1}.")
        @error = true
      end
      if epwdata.directNormalRadiation.is_initialized
        rowdict['dirnormal'] = epwdata.directNormalRadiation.get # W/m^2
      else
        @runner.registerError("Cannot retrieve directNormalRadiation from the EPW for hour #{rownum + 1}.")
        @error = true
      end
      if epwdata.diffuseHorizontalRadiation.is_initialized
        rowdict['diffhoriz'] = epwdata.diffuseHorizontalRadiation.get # W/m^2
      else
        @runner.registerError("Cannot retrieve diffuseHorizontalRadiation from the EPW for hour #{rownum + 1}.")
        @error = true
      end
      if epwdata.windSpeed.is_initialized
        rowdict['ws'] = epwdata.windSpeed.get
      else
        @runner.registerError("Cannot retrieve windSpeed from the EPW for hour #{rownum + 1}.")
        @error = true
      end
      if @error
        return
      end

      rowdata << rowdict

      next unless (rownum + 1) % (24 * @header.RecordsPerHour) == 0

      db = []
      maxdb = rowdata[rowdata.length - (24 * @header.RecordsPerHour)]['db']
      mindb = rowdata[rowdata.length - (24 * @header.RecordsPerHour)]['db']
      rowdata[rowdata.length - (24 * @header.RecordsPerHour)..-1].each do |x|
        if x['db'] > maxdb
          maxdb = x['db']
        end
        if x['db'] < mindb
          mindb = x['db']
        end
        db << x['db']
      end

      dailydbs << db.inject { |sum, n| sum + n } / (24.0 * @header.RecordsPerHour)
      dailyhighdbs << maxdb
      dailylowdbs << mindb
    end

    year_description = @model.getYearDescription
    num_days_in_months = Constants.NumDaysInMonths(year_description.isLeapYear)

    calc_annual_drybulbs(rowdata)
    calc_monthly_drybulbs(rowdata)
    calc_heat_cool_degree_days(rowdata, dailydbs)
    calc_avg_highs_lows(dailyhighdbs, dailylowdbs, num_days_in_months)
    calc_avg_windspeed(rowdata)
    calc_ground_temperatures
    @data.WSF = get_ashrae_622_wsf

    if not epwHasDesignData
      @runner.registerWarning('No design condition info found; calculating design conditions from EPW weather data.')
      calc_design_info(rowdata)
      @design.DailyTemperatureRange = @data.MonthlyAvgDailyHighDrybulbs[7] - @data.MonthlyAvgDailyLowDrybulbs[7]
    end

    calc_design_solar_radiation(rowdata)
  end

  def calc_annual_drybulbs(hd)
    # Calculates and stores annual average, minimum, and maximum drybulbs
    db = []
    mindict = hd[0]
    maxdict = hd[0]
    hd.each do |x|
      if x['db'] > maxdict['db']
        maxdict = x
      end
      if x['db'] < mindict['db']
        mindict = x
      end
      db << x['db']
    end

    @data.AnnualAvgDrybulb = UnitConversions.convert(db.inject { |sum, n| sum + n } / db.length, 'C', 'F')

    # Peak temperatures:
    @data.AnnualMinDrybulb = UnitConversions.convert(mindict['db'], 'C', 'F')
    @data.AnnualMaxDrybulb = UnitConversions.convert(maxdict['db'], 'C', 'F')
  end

  def calc_monthly_drybulbs(hd)
    # Calculates and stores monthly average drybulbs
    @data.MonthlyAvgDrybulbs = []
    (1..12).to_a.each do |month|
      y = []
      hd.each do |x|
        if x['month'] == month
          y << x['db']
        end
      end
      month_dbtotal = y.inject { |sum, n| sum + n }
      month_hours = y.length
      @data.MonthlyAvgDrybulbs << UnitConversions.convert(month_dbtotal / month_hours, 'C', 'F')
    end
  end

  def calc_avg_windspeed(hd)
    # Calculates and stores annual average windspeed
    ws = []
    hd.each do |x|
      ws << x['ws']
    end
    avgws = ws.inject { |sum, n| sum + n } / ws.length
    @data.AnnualAvgWindspeed = avgws
  end

  def calc_heat_cool_degree_days(hd, dailydbs)
    # Calculates and stores heating/cooling degree days
    @data.HDD65F = calc_degree_days(dailydbs, 65, true)
    @data.HDD50F = calc_degree_days(dailydbs, 50, true)
    @data.CDD65F = calc_degree_days(dailydbs, 65, false)
    @data.CDD50F = calc_degree_days(dailydbs, 50, false)
  end

  def calc_degree_days(daily_dbs, base_temp_f, is_heating)
    # Calculates and returns degree days from a base temperature for either heating or cooling
    base_temp_c = UnitConversions.convert(base_temp_f, 'F', 'C')

    deg_days = []
    if is_heating
      daily_dbs.each do |x|
        if x < base_temp_c
          deg_days << base_temp_c - x
        end
      end
    else
      daily_dbs.each do |x|
        if x > base_temp_c
          deg_days << x - base_temp_c
        end
      end
    end
    if deg_days.size == 0
      return 0.0
    end

    deg_days = deg_days.inject { |sum, n| sum + n }
    return 1.8 * deg_days
  end

  def calc_avg_highs_lows(daily_high_dbs, daily_low_dbs, num_days_in_months)
    # Calculates and stores avg daily highs and lows for each month
    @data.MonthlyAvgDailyHighDrybulbs = []
    @data.MonthlyAvgDailyLowDrybulbs = []

    first_day = 0
    for month in 1..12
      ndays = num_days_in_months[month - 1] # Number of days in current month
      if month > 1
        first_day += num_days_in_months[month - 2] # Number of days in previous month
      end
      avg_high = daily_high_dbs[first_day, ndays].inject { |sum, n| sum + n } / ndays.to_f
      avg_low = daily_low_dbs[first_day, ndays].inject { |sum, n| sum + n } / ndays.to_f
      @data.MonthlyAvgDailyHighDrybulbs << UnitConversions.convert(avg_high, 'C', 'F')
      @data.MonthlyAvgDailyLowDrybulbs << UnitConversions.convert(avg_low, 'C', 'F')
    end
  end

  def calc_design_solar_radiation(rowdata)
    # Calculate cooling design day info, for roof surface sol air temperature, which is used for attic temperature calculation for Manual J/ASHRAE Std 152:
    # Max summer direct normal solar radiation
    # Diffuse horizontal solar radiation during hour with max direct normal
    summer_rowdata = []
    months = [6, 7, 8, 9]
    for hr in 0..(rowdata.size - 1)
      next if not months.include?(rowdata[hr]['month'])

      summer_rowdata << rowdata[hr]
    end

    r_d = (1 + Math::cos(26.565052 * Math::PI / 180)) / 2 # Correct diffuse horizontal for tilt. Assume 6:12 roof pitch for this calculation.
    max_solar_radiation_hour = summer_rowdata[0]
    for hr in 1..(summer_rowdata.size - 1)
      next if summer_rowdata[hr]['dirnormal'] + summer_rowdata[hr]['diffhoriz'] * r_d < max_solar_radiation_hour['dirnormal'] + max_solar_radiation_hour['diffhoriz'] * r_d

      max_solar_radiation_hour = summer_rowdata[hr]
    end

    @design.CoolingDirectNormal = max_solar_radiation_hour['dirnormal']
    @design.CoolingDiffuseHorizontal = max_solar_radiation_hour['diffhoriz']
  end

  def get_ashrae_622_wsf
    # Looks up the ASHRAE 62.2 weather and shielding factor from ASHRAE622WSF
    # for the specified WMO station number. If not found, uses the average value
    # in the file.

    # Sets the WSF value.

    ashrae_csv = File.join(File.dirname(__FILE__), 'ASHRAE622WSF.csv')
    if not File.exist?(ashrae_csv)
      return
    end

    ashrae_csvlines = []
    File.open(ashrae_csv) do |file|
      # if not os.path.exists(ashrae_csv):
      #    raise IOError("Cannot find file " + ashrae_csv)
      file.each do |line|
        line = line.strip.chomp.chomp(',').chomp # remove RHS whitespace and extra comma
        ashrae_csvlines << line
      end
    end

    keys = ashrae_csvlines.delete_at(0).split(',')
    ashrae_dict = []
    ashrae_csvlines.each do |line|
      line = line.split(',')
      ashrae_dict << Hash[keys.zip(line)]
    end

    wsfs = []
    ashrae_dict.each do |adict|
      if adict['TMY3'] == @header.Station
        return adict['wsf'].to_f
      end

      wsfs << adict['wsf'].to_f
    end

    # Value not found, use average
    wsf_avg = wsfs.inject { |sum, n| sum + n } / wsfs.length
    @runner.registerWarning("ASHRAE 62.2 WSF not found for station number #{@header.Station}, using the national average value of #{wsf_avg.round(3)} instead.")
    return wsf_avg
  end

  def get_design_info_from_epw
    epw_design_conditions = @epw_file.designConditions
    epwHasDesignData = false
    if epw_design_conditions.length > 0
      epwHasDesignData = true
      epw_design_conditions = epw_design_conditions[0]
      @design.HeatingDrybulb = UnitConversions.convert(epw_design_conditions.heatingDryBulb99, 'C', 'F')
      @design.HeatingWindspeed = epw_design_conditions.heatingColdestMonthWindSpeed1 # TODO: This field is consistent with BEopt, but should be heatingMeanCoincidentWindSpeed99pt6 instead?
      @design.CoolingDrybulb = UnitConversions.convert(epw_design_conditions.coolingDryBulb1, 'C', 'F')
      @design.CoolingWetbulb = UnitConversions.convert(epw_design_conditions.coolingMeanCoincidentWetBulb1, 'C', 'F')
      @design.CoolingWindspeed = epw_design_conditions.coolingMeanCoincidentWindSpeed0pt4
      @design.DailyTemperatureRange = UnitConversions.convert(epw_design_conditions.coolingDryBulbRange, 'K', 'R')
      @design.DehumidDrybulb = UnitConversions.convert(epw_design_conditions.coolingDehumidificationMeanCoincidentDryBulb2, 'C', 'F')
      dehum02per_dp = UnitConversions.convert(epw_design_conditions.coolingDehumidificationDewPoint2, 'C', 'F')
      std_press = Psychrometrics.Pstd_fZ(@header.Altitude)
      @design.CoolingHumidityRatio = Psychrometrics.w_fT_Twb_P(design.CoolingDrybulb, design.CoolingWetbulb, std_press)
      @design.DehumidHumidityRatio = Psychrometrics.w_fT_Twb_P(dehum02per_dp, dehum02per_dp, std_press)
    end
    return epwHasDesignData
  end

  def calc_design_info(rowdata)
    # Calculate design day info:
    # - Heating 99% drybulb
    # - Heating mean coincident windspeed
    # - Cooling 99% drybulb
    # - Cooling mean coincident windspeed
    # - Cooling mean coincident wetbulb
    # - Cooling mean coincident humidity ratio

    std_press = Psychrometrics.Pstd_fZ(@header.Altitude)
    annual_hd_sorted_by_db = rowdata.sort_by { |x| x['db'] }
    annual_hd_sorted_by_dp = rowdata.sort_by { |x| x['dp'] }

    # 1%/99%/2% values
    heat99per_db = annual_hd_sorted_by_db[88 * @header.RecordsPerHour]['db']
    cool01per_db = annual_hd_sorted_by_db[8673 * @header.RecordsPerHour]['db']
    dehum02per_dp = annual_hd_sorted_by_dp[8584 * @header.RecordsPerHour]['dp']

    # Mean coincident values for cooling
    cool_windspeed = []
    cool_wetbulb = []
    for i in 0..(annual_hd_sorted_by_db.size - 1)
      next unless (annual_hd_sorted_by_db[i]['db'] > cool01per_db - 0.5) && (annual_hd_sorted_by_db[i]['db'] < cool01per_db + 0.5)

      cool_windspeed << annual_hd_sorted_by_db[i]['ws']
      wb = Psychrometrics.Twb_fT_R_P(UnitConversions.convert(annual_hd_sorted_by_db[i]['db'], 'C', 'F'), annual_hd_sorted_by_db[i]['rh'], std_press)
      cool_wetbulb << wb
    end
    cool_design_wb = cool_wetbulb.inject { |sum, n| sum + n } / cool_wetbulb.size

    # Mean coincident values for heating
    heat_windspeed = []
    for i in 0..(annual_hd_sorted_by_db.size - 1)
      if (annual_hd_sorted_by_db[i]['db'] > heat99per_db - 0.5) && (annual_hd_sorted_by_db[i]['db'] < heat99per_db + 0.5)
        heat_windspeed << annual_hd_sorted_by_db[i]['ws']
      end
    end

    # Mean coincident values for dehumidification
    dehum_drybulb = []
    for i in 0..(annual_hd_sorted_by_dp.size - 1)
      if (annual_hd_sorted_by_dp[i]['dp'] > dehum02per_dp - 0.5) && (annual_hd_sorted_by_dp[i]['dp'] < dehum02per_dp + 0.5)
        dehum_drybulb << annual_hd_sorted_by_dp[i]['db']
      end
    end
    dehum_design_db = dehum_drybulb.inject { |sum, n| sum + n } / dehum_drybulb.size

    @design.CoolingDrybulb = UnitConversions.convert(cool01per_db, 'C', 'F')
    @design.CoolingWetbulb = cool_design_wb
    @design.CoolingHumidityRatio = Psychrometrics.w_fT_Twb_P(design.CoolingDrybulb, design.CoolingWetbulb, std_press)
    @design.CoolingWindspeed = cool_windspeed.inject { |sum, n| sum + n } / cool_windspeed.size

    @design.HeatingDrybulb = UnitConversions.convert(heat99per_db, 'C', 'F')
    @design.HeatingWindspeed = heat_windspeed.inject { |sum, n| sum + n } / heat_windspeed.size

    @design.DehumidDrybulb = UnitConversions.convert(dehum_design_db, 'C', 'F')
    @design.DehumidHumidityRatio = Psychrometrics.w_fT_Twb_P(UnitConversions.convert(dehum02per_dp, 'C', 'F'), UnitConversions.convert(dehum02per_dp, 'C', 'F'), std_press)
  end

  def calc_ground_temperatures
    # Return monthly ground temperatures. This correlation is the same that is used in DOE-2's src\WTH.f file, subroutine GTEMP.

    amon = [15.0, 46.0, 74.0, 95.0, 135.0, 166.0, 196.0, 227.0, 258.0, 288.0, 319.0, 349.0]
    po = 0.6
    dif = 0.025
    p = UnitConversions.convert(1.0, 'yr', 'hr')

    beta = Math::sqrt(Math::PI / (p * dif)) * 10.0
    x = Math::exp(-beta)
    x2 = x * x
    s = Math::sin(beta)
    c = Math::cos(beta)
    y = (x2 - 2.0 * x * c + 1.0) / (2.0 * beta**2.0)
    gm = Math::sqrt(y)
    z = (1.0 - x * (c + s)) / (1.0 - x * (c - s))
    phi = Math::atan(z)
    bo = (data.MonthlyAvgDrybulbs.max - data.MonthlyAvgDrybulbs.min) * 0.5

    @data.GroundMonthlyTemps = []
    (0..11).to_a.each do |i|
      theta = amon[i] * 24.0
      @data.GroundMonthlyTemps << UnitConversions.convert(data.AnnualAvgDrybulb - bo * Math::cos(2.0 * Math::PI / p * theta - po - phi) * gm + 460.0, 'R', 'F')
    end
  end

  def self.calc_mains_temperatures(avgOAT, maxDiffMonthlyAvgOAT, latitude, num_days_in_year)
    pi = Math::PI
    deg_rad = pi / 180
    mainsDailyTemps = Array.new(num_days_in_year, 0)
    mainsMonthlyTemps = Array.new(12, 0)
    mainsAvgTemp = 0

    tmains_ratio = 0.4 + 0.01 * (avgOAT - 44)
    tmains_lag = 35 - (avgOAT - 44)
    if latitude < 0
      sign = 1
    else
      sign = -1
    end

    # Calculate daily and annual
    for d in 1..num_days_in_year
      mainsDailyTemps[d - 1] = avgOAT + 6 + tmains_ratio * maxDiffMonthlyAvgOAT / 2 * Math.sin(deg_rad * (0.986 * (d - 15 - tmains_lag) + sign * 90))
      mainsAvgTemp += mainsDailyTemps[d - 1] / num_days_in_year
    end
    # Calculate monthly
    for m in 1..12
      mainsMonthlyTemps[m - 1] = avgOAT + 6 + tmains_ratio * maxDiffMonthlyAvgOAT / 2 * Math.sin(deg_rad * (0.986 * ((m * 30 - 15) - 15 - tmains_lag) + sign * 90))
    end
    return mainsAvgTemp, mainsMonthlyTemps, mainsDailyTemps
  end
end
