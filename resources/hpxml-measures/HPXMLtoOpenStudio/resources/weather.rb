# frozen_string_literal: true

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
  def initialize(model, runner, csv_path = nil)
    @header = WeatherHeader.new
    @data = WeatherData.new
    @design = WeatherDesign.new

    if not csv_path.nil?
      load_from_csv(csv_path)
      return
    end

    @model = model
    @runner = runner

    @epw_path = WeatherProcess.get_epw_path(@model)

    if not File.exist?(@epw_path)
      fail "Cannot find weather file at #{epw_path}."
    end

    @epw_file = OpenStudio::EpwFile.new(@epw_path, true)

    process_epw
  end

  def epw_path
    return @epw_path
  end

  def dump_to_csv(csv_path)
    require 'csv'

    def to_columns(data)
      if not data.is_a? Array
        return [data.class, data]
      end

      return [data.class] + data
    end

    results_out = []
    WeatherHeader::ATTRS.each do |k|
      results_out << ["WeatherHeader.#{k}"] + to_columns(@header.send(k))
    end
    WeatherData::ATTRS.each do |k|
      results_out << ["WeatherData.#{k}"] + to_columns(@data.send(k))
    end
    WeatherDesign::ATTRS.each do |k|
      results_out << ["WeatherDesign.#{k}"] + to_columns(@design.send(k))
    end

    CSV.open(csv_path, 'wb') { |csv| results_out.to_a.each { |elem| csv << elem } }
  end

  def load_from_csv(csv_path)
    csv_data = CSV.read(csv_path, headers: false)

    def to_datatype(data, dataclass)
      if dataclass == 'String'
        return data[0].to_s
      elsif dataclass == 'Float'
        return data[0].to_f
      elsif dataclass == 'Fixnum'
        return data[0].to_i
      elsif dataclass == 'Array'
        return data.map(&:to_f)
      end
    end

    csv_data.each do |data|
      dataname = data[0].split('.')[1]
      if data[0].start_with? 'WeatherHeader'
        @header.send(dataname + '=', to_datatype(data[2..-1], data[1]))
      elsif data[0].start_with? 'WeatherData'
        @data.send(dataname + '=', to_datatype(data[2..-1], data[1]))
      elsif data[0].start_with? 'WeatherDesign'
        @design.send(dataname + '=', to_datatype(data[2..-1], data[1]))
      end
    end
  end

  attr_accessor(:header, :data, :design)

  private

  def self.get_epw_path(model)
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

    fail 'Model has not been assigned a weather file.'
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
        fail "Cannot retrieve dryBulbTemperature from the EPW for hour #{rownum + 1}."
      end
      if epwdata.dewPointTemperature.is_initialized
        rowdict['dp'] = epwdata.dewPointTemperature.get
      else
        fail "Cannot retrieve dewPointTemperature from the EPW for hour #{rownum + 1}."
      end
      if epwdata.relativeHumidity.is_initialized
        rowdict['rh'] = epwdata.relativeHumidity.get / 100.0
      else
        fail "Cannot retrieve relativeHumidity from the EPW for hour #{rownum + 1}."
      end
      if epwdata.directNormalRadiation.is_initialized
        rowdict['dirnormal'] = epwdata.directNormalRadiation.get # W/m^2
      else
        fail "Cannot retrieve directNormalRadiation from the EPW for hour #{rownum + 1}."
      end
      if epwdata.diffuseHorizontalRadiation.is_initialized
        rowdict['diffhoriz'] = epwdata.diffuseHorizontalRadiation.get # W/m^2
      else
        fail "Cannot retrieve diffuseHorizontalRadiation from the EPW for hour #{rownum + 1}."
      end
      if epwdata.windSpeed.is_initialized
        rowdict['ws'] = epwdata.windSpeed.get
      else
        fail "Cannot retrieve windSpeed from the EPW for hour #{rownum + 1}."
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

      dailydbs << db.sum(0.0) / (24.0 * @header.RecordsPerHour)
      dailyhighdbs << maxdb
      dailylowdbs << mindb
    end

    calc_annual_drybulbs(rowdata)
    calc_monthly_drybulbs(rowdata)
    calc_heat_cool_degree_days(rowdata, dailydbs)
    calc_avg_monthly_highs_lows(dailyhighdbs, dailylowdbs)
    calc_avg_windspeed(rowdata)
    calc_ground_temperatures
    @data.WSF = calc_ashrae_622_wsf(rowdata)

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

    @data.AnnualAvgDrybulb = UnitConversions.convert(db.sum(0.0) / db.length, 'C', 'F')

    # Peak temperatures:
    @data.AnnualMinDrybulb = UnitConversions.convert(mindict['db'], 'C', 'F')
    @data.AnnualMaxDrybulb = UnitConversions.convert(maxdict['db'], 'C', 'F')
  end

  def calc_monthly_drybulbs(hd)
    # Calculates and stores monthly average drybulbs
    @data.MonthlyAvgDrybulbs = []
    (1...13).to_a.each do |month|
      y = []
      hd.each do |x|
        if x['month'] == month
          y << x['db']
        end
      end
      month_dbtotal = y.sum(0.0)
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
    avgws = ws.sum(0.0) / ws.length
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

    deg_days = deg_days.sum(0.0)
    return 1.8 * deg_days
  end

  def calc_avg_monthly_highs_lows(daily_high_dbs, daily_low_dbs)
    # Calculates and stores avg daily highs and lows for each month
    @data.MonthlyAvgDailyHighDrybulbs = []
    @data.MonthlyAvgDailyLowDrybulbs = []

    first_day = 0
    for month in 1..12
      month_num_days = Schedule.get_num_days_per_month(@model)
      ndays = month_num_days[month - 1] # Number of days in current month
      if month > 1
        first_day += month_num_days[month - 2] # Number of days in previous month
      end
      avg_high = daily_high_dbs[first_day, ndays].sum(0.0) / ndays.to_f
      avg_low = daily_low_dbs[first_day, ndays].sum(0.0) / ndays.to_f
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

  def calc_ashrae_622_wsf(rowdata)
    require 'csv'
    ashrae_csv = File.join(File.dirname(__FILE__), 'data_ashrae_622_wsf.csv')

    wsf = nil
    CSV.read(ashrae_csv, headers: false).each do |data|
      next unless data[0] == @header.Station

      wsf = Float(data[1]).round(2)
    end
    return wsf unless wsf.nil?

    # If not available in data_ashrae_622_wsf.csv...
    # Calculates the wSF value per report LBNL-5795E "Infiltration as Ventilation: Weather-Induced Dilution"

    # Constants
    c_d = 1.0       # unitless, discharge coefficient for ELA (at 4 Pa)
    t_indoor = 22.0 # C, indoor setpoint year-round
    n = 0.67        # unitless, pressure exponent
    s = 0.7         # unitless, shelter class 4 for 1-story with flue, enhanced model
    delta_p = 4.0   # Pa, pressure difference indoor-outdoor
    u_min = 1.0     # m/s, minimum windspeed per hour
    ela = 0.074     # m^2, effective leakage area (assumed)
    cfa = 185.0     # m^2, conditioned floor area
    h = 2.5         # m, single story height
    g = 0.48        # unitless, wind speed multiplier for 1-story, enhanced model
    c_s = 0.069     # (Pa/K)^n, stack coefficient, 1-story with flue, enhanced model
    c_w = 0.142     # (Pa*s^2/m^2)^n, wind coefficient, bsmt slab 1-story with flue, enhanced model
    roe = 1.2       # kg/m^3, air density (assumed at sea level)

    c = c_d * ela * (2 / roe)**0.5 * delta_p**(0.5 - n) # m^3/(s*Pa^n), flow coefficient

    taus = []
    prev_tau = 0.0
    for hr in 0..rowdata.size - 1
      q_s = c * c_s * (t_indoor - rowdata[hr]['db']).abs**n
      q_w = c * c_w * (s * g * [rowdata[hr]['ws'], u_min].max)**(2 * n)
      q_tot = (q_s**2 + q_w**2)**0.5
      ach = 3600.0 * q_tot / (h * cfa)
      taus << (1 - Math.exp(-ach)) / ach + prev_tau * Math.exp(-ach)
      prev_tau = taus[-1]
    end

    tau = taus.sum(0.0) / taus.size.to_f # Mean annual turnover time (hours)
    wsf = (cfa / ela) / (1000.0 * tau)

    return wsf.round(2)
  end

  def get_design_info_from_epw
    epw_design_conditions = @epw_file.designConditions
    epwHasDesignData = false
    if epw_design_conditions.length > 0
      epwHasDesignData = true
      epw_design_conditions = epw_design_conditions[0]
      @design.HeatingDrybulb = UnitConversions.convert(epw_design_conditions.heatingDryBulb99, 'C', 'F')
      @design.HeatingWindspeed = epw_design_conditions.heatingColdestMonthWindSpeed1
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
    cool_design_wb = cool_wetbulb.sum(0.0) / cool_wetbulb.size

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
    dehum_design_db = dehum_drybulb.sum(0.0) / dehum_drybulb.size

    @design.CoolingDrybulb = UnitConversions.convert(cool01per_db, 'C', 'F')
    @design.CoolingWetbulb = cool_design_wb
    @design.CoolingHumidityRatio = Psychrometrics.w_fT_Twb_P(design.CoolingDrybulb, design.CoolingWetbulb, std_press)
    @design.CoolingWindspeed = cool_windspeed.sum(0.0) / cool_windspeed.size

    @design.HeatingDrybulb = UnitConversions.convert(heat99per_db, 'C', 'F')
    @design.HeatingWindspeed = heat_windspeed.sum(0.0) / heat_windspeed.size

    @design.DehumidDrybulb = UnitConversions.convert(dehum_design_db, 'C', 'F')
    @design.DehumidHumidityRatio = Psychrometrics.w_fT_Twb_P(UnitConversions.convert(dehum02per_dp, 'C', 'F'), UnitConversions.convert(dehum02per_dp, 'C', 'F'), std_press)
  end

  def calc_ground_temperatures
    # Return monthly ground temperatures.

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
    (0...12).to_a.each do |i|
      theta = amon[i] * 24.0
      @data.GroundMonthlyTemps << UnitConversions.convert(data.AnnualAvgDrybulb - bo * Math::cos(2.0 * Math::PI / p * theta - po - phi) * gm + 460.0, 'R', 'F')
    end
  end

  def self.calc_mains_temperatures(avgOAT, maxDiffMonthlyAvgOAT, latitude)
    pi = Math::PI
    deg_rad = pi / 180
    mainsDailyTemps = Array.new(365, 0)
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
    for d in 1..365
      mainsDailyTemps[d - 1] = avgOAT + 6 + tmains_ratio * maxDiffMonthlyAvgOAT / 2 * Math.sin(deg_rad * (0.986 * (d - 15 - tmains_lag) + sign * 90))
      mainsAvgTemp += mainsDailyTemps[d - 1] / 365.0
    end
    # Calculate monthly
    for m in 1..12
      mainsMonthlyTemps[m - 1] = avgOAT + 6 + tmains_ratio * maxDiffMonthlyAvgOAT / 2 * Math.sin(deg_rad * (0.986 * ((m * 30 - 15) - 15 - tmains_lag) + sign * 90))
    end
    return mainsAvgTemp, mainsMonthlyTemps, mainsDailyTemps
  end
end
