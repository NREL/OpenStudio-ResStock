# frozen_string_literal: true

# Annual schedule defined by 12 24-hour values for weekdays and weekends.
class HourlyByMonthSchedule
  # weekday_month_by_hour_values must be a 12-element array of 24-element arrays of numbers.
  # weekend_month_by_hour_values must be a 12-element array of 24-element arrays of numbers.
  def initialize(model, sch_name, weekday_month_by_hour_values, weekend_month_by_hour_values,
                 schedule_type_limits_name = nil, normalize_values = true)
    @model = model
    @sch_name = sch_name
    @schedule = nil
    @weekday_month_by_hour_values = validateValues(weekday_month_by_hour_values, 12, 24)
    @weekend_month_by_hour_values = validateValues(weekend_month_by_hour_values, 12, 24)
    @schedule_type_limits_name = schedule_type_limits_name

    if normalize_values
      @maxval = calcMaxval()
    else
      @maxval = 1.0
    end
    @schedule = createSchedule()
  end

  def calcDesignLevel(val)
    return val * 1000
  end

  def schedule
    return @schedule
  end

  def maxval
    return @maxval
  end

  private

  def validateValues(vals, num_outter_values, num_inner_values)
    err_msg = "A #{num_outter_values}-element array with #{num_inner_values}-element arrays of numbers must be entered for the schedule."
    if not vals.is_a?(Array)
      fail err_msg
    end

    begin
      if vals.length != num_outter_values
        fail err_msg
      end

      vals.each do |val|
        if not val.is_a?(Array)
          fail err_msg
        end
        if val.length != num_inner_values
          fail err_msg
        end
      end
    rescue
      fail err_msg
    end
    return vals
  end

  def calcMaxval()
    maxval = [@weekday_month_by_hour_values.flatten.max, @weekend_month_by_hour_values.flatten.max].max
    if maxval == 0.0
      maxval = 1.0 # Prevent divide by zero
    end
    return maxval
  end

  def createSchedule()
    day_startm = Schedule.day_start_months(@model)
    day_endm = Schedule.day_end_months(@model)

    time = []
    for h in 1..24
      time[h] = OpenStudio::Time.new(0, h, 0, 0)
    end

    schedule = OpenStudio::Model::ScheduleRuleset.new(@model)
    schedule.setName(@sch_name)

    assumedYear = @model.getYearDescription.assumedYear # prevent excessive OS warnings about 'UseWeatherFile'

    prev_wkdy_vals = nil
    prev_wkdy_rule = nil
    prev_wknd_vals = nil
    prev_wknd_rule = nil
    for m in 1..12
      date_s = OpenStudio::Date::fromDayOfYear(day_startm[m - 1], assumedYear)
      date_e = OpenStudio::Date::fromDayOfYear(day_endm[m - 1], assumedYear)

      wkdy_vals = []
      wknd_vals = []
      for h in 1..24
        wkdy_vals[h] = (@weekday_month_by_hour_values[m - 1][h - 1]) / @maxval
        wknd_vals[h] = (@weekend_month_by_hour_values[m - 1][h - 1]) / @maxval
      end

      if (wkdy_vals == prev_wkdy_vals) && (wknd_vals == prev_wknd_vals)
        # Extend end date of current rule(s)
        prev_wkdy_rule.setEndDate(date_e) unless prev_wkdy_rule.nil?
        prev_wknd_rule.setEndDate(date_e) unless prev_wknd_rule.nil?
      elsif wkdy_vals == wknd_vals
        # Alldays
        wkdy_rule = OpenStudio::Model::ScheduleRule.new(schedule)
        wkdy_rule.setName(@sch_name + " #{Schedule.allday_name} ruleset#{m}")
        wkdy = wkdy_rule.daySchedule
        wkdy.setName(@sch_name + " #{Schedule.allday_name}#{m}")
        previous_value = wkdy_vals[1]
        for h in 1..24
          next if (h != 24) && (wkdy_vals[h + 1] == previous_value)

          wkdy.addValue(time[h], previous_value)
          previous_value = wkdy_vals[h + 1]
        end
        Schedule.set_weekday_rule(wkdy_rule)
        Schedule.set_weekend_rule(wkdy_rule)
        wkdy_rule.setStartDate(date_s)
        wkdy_rule.setEndDate(date_e)
        prev_wkdy_rule = wkdy_rule
        prev_wknd_rule = nil
      else
        # Weekdays
        wkdy_rule = OpenStudio::Model::ScheduleRule.new(schedule)
        wkdy_rule.setName(@sch_name + " #{Schedule.weekday_name} ruleset#{m}")
        wkdy = wkdy_rule.daySchedule
        wkdy.setName(@sch_name + " #{Schedule.weekday_name}#{m}")
        previous_value = wkdy_vals[1]
        for h in 1..24
          next if (h != 24) && (wkdy_vals[h + 1] == previous_value)

          wkdy.addValue(time[h], previous_value)
          previous_value = wkdy_vals[h + 1]
        end
        Schedule.set_weekday_rule(wkdy_rule)
        wkdy_rule.setStartDate(date_s)
        wkdy_rule.setEndDate(date_e)
        prev_wkdy_rule = wkdy_rule

        # Weekends
        wknd_rule = OpenStudio::Model::ScheduleRule.new(schedule)
        wknd_rule.setName(@sch_name + " #{Schedule.weekend_name} ruleset#{m}")
        wknd = wknd_rule.daySchedule
        wknd.setName(@sch_name + " #{Schedule.weekend_name}#{m}")
        previous_value = wknd_vals[1]
        for h in 1..24
          next if (h != 24) && (wknd_vals[h + 1] == previous_value)

          wknd.addValue(time[h], previous_value)
          previous_value = wknd_vals[h + 1]
        end
        Schedule.set_weekend_rule(wknd_rule)
        wknd_rule.setStartDate(date_s)
        wknd_rule.setEndDate(date_e)
        prev_wknd_rule = wknd_rule
      end

      prev_wkdy_vals = wkdy_vals
      prev_wknd_vals = wknd_vals
    end

    Schedule.set_schedule_type_limits(@model, schedule, @schedule_type_limits_name)

    return schedule
  end
end

# Annual schedule defined by 365 24-hour values for weekdays and weekends.
class HourlyByDaySchedule
  # weekday_day_by_hour_values must be a 365-element array of 24-element arrays of numbers.
  # weekend_day_by_hour_values must be a 365-element array of 24-element arrays of numbers.
  def initialize(model, sch_name, weekday_day_by_hour_values, weekend_day_by_hour_values,
                 schedule_type_limits_name = nil, normalize_values = true)
    @model = model
    @sch_name = sch_name
    @schedule = nil
    @num_days = Schedule.get_num_days_in_year(model)
    @weekday_day_by_hour_values = validateValues(weekday_day_by_hour_values, @num_days, 24)
    @weekend_day_by_hour_values = validateValues(weekend_day_by_hour_values, @num_days, 24)
    @schedule_type_limits_name = schedule_type_limits_name

    if normalize_values
      @maxval = calcMaxval()
    else
      @maxval = 1.0
    end
    @schedule = createSchedule()
  end

  def calcDesignLevel(val)
    return val * 1000
  end

  def schedule
    return @schedule
  end

  def maxval
    return @maxval
  end

  private

  def validateValues(vals, num_outter_values, num_inner_values)
    err_msg = "A #{num_outter_values}-element array with #{num_inner_values}-element arrays of numbers must be entered for the schedule."
    if not vals.is_a?(Array)
      fail err_msg
    end

    begin
      if vals.length != num_outter_values
        fail err_msg
      end

      vals.each do |val|
        if not val.is_a?(Array)
          fail err_msg
        end
        if val.length != num_inner_values
          fail err_msg
        end
      end
    rescue
      fail err_msg
    end
    return vals
  end

  def calcMaxval()
    maxval = [@weekday_month_by_hour_values.flatten.max, @weekend_month_by_hour_values.flatten.max].max
    if maxval == 0.0
      maxval = 1.0 # Prevent divide by zero
    end
    return maxval
  end

  def createSchedule()
    year_description = @model.getYearDescription

    time = []
    for h in 1..24
      time[h] = OpenStudio::Time.new(0, h, 0, 0)
    end

    schedule = OpenStudio::Model::ScheduleRuleset.new(@model)
    schedule.setName(@sch_name)

    assumedYear = year_description.assumedYear # prevent excessive OS warnings about 'UseWeatherFile'

    prev_wkdy_vals = nil
    prev_wkdy_rule = nil
    prev_wknd_vals = nil
    prev_wknd_rule = nil
    for d in 1..@num_days
      date_s = OpenStudio::Date::fromDayOfYear(d, assumedYear)
      date_e = OpenStudio::Date::fromDayOfYear(d, assumedYear)

      wkdy_vals = []
      wknd_vals = []
      for h in 1..24
        wkdy_vals[h] = (@weekday_day_by_hour_values[d - 1][h - 1]) / @maxval
        wknd_vals[h] = (@weekend_day_by_hour_values[d - 1][h - 1]) / @maxval
      end

      if (wkdy_vals == prev_wkdy_vals) && (wknd_vals == prev_wknd_vals)
        # Extend end date of current rule(s)
        prev_wkdy_rule.setEndDate(date_e) unless prev_wkdy_rule.nil?
        prev_wknd_rule.setEndDate(date_e) unless prev_wknd_rule.nil?
      elsif wkdy_vals == wknd_vals
        # Alldays
        wkdy_rule = OpenStudio::Model::ScheduleRule.new(schedule)
        wkdy_rule.setName(@sch_name + " #{Schedule.allday_name} ruleset#{d}")
        wkdy = wkdy_rule.daySchedule
        wkdy.setName(@sch_name + " #{Schedule.allday_name}#{d}")
        previous_value = wkdy_vals[1]
        for h in 1..24
          next if (h != 24) && (wkdy_vals[h + 1] == previous_value)

          wkdy.addValue(time[h], previous_value)
          previous_value = wkdy_vals[h + 1]
        end
        Schedule.set_weekday_rule(wkdy_rule)
        Schedule.set_weekend_rule(wkdy_rule)
        wkdy_rule.setStartDate(date_s)
        wkdy_rule.setEndDate(date_e)
        prev_wkdy_rule = wkdy_rule
        prev_wknd_rule = nil
      else
        # Weekdays
        wkdy_rule = OpenStudio::Model::ScheduleRule.new(schedule)
        wkdy_rule.setName(@sch_name + " #{Schedule.weekday_name} ruleset#{d}")
        wkdy = wkdy_rule.daySchedule
        wkdy.setName(@sch_name + " #{Schedule.weekday_name}#{d}")
        previous_value = wkdy_vals[1]
        for h in 1..24
          next if (h != 24) && (wkdy_vals[h + 1] == previous_value)

          wkdy.addValue(time[h], previous_value)
          previous_value = wkdy_vals[h + 1]
        end
        Schedule.set_weekday_rule(wkdy_rule)
        wkdy_rule.setStartDate(date_s)
        wkdy_rule.setEndDate(date_e)
        prev_wkdy_rule = wkdy_rule

        # Weekends
        wknd_rule = OpenStudio::Model::ScheduleRule.new(schedule)
        wknd_rule.setName(@sch_name + " #{Schedule.weekend_name} ruleset#{d}")
        wknd = wknd_rule.daySchedule
        wknd.setName(@sch_name + " #{Schedule.weekend_name}#{d}")
        previous_value = wknd_vals[1]
        for h in 1..24
          next if (h != 24) && (wknd_vals[h + 1] == previous_value)

          wknd.addValue(time[h], previous_value)
          previous_value = wknd_vals[h + 1]
        end
        Schedule.set_weekend_rule(wknd_rule)
        wknd_rule.setStartDate(date_s)
        wknd_rule.setEndDate(date_e)
        prev_wknd_rule = wknd_rule
      end

      prev_wkdy_vals = wkdy_vals
      prev_wknd_vals = wknd_vals
    end

    Schedule.set_schedule_type_limits(@model, schedule, @schedule_type_limits_name)

    return schedule
  end
end

# Annual schedule defined by 24 weekday hourly values, 24 weekend hourly values, and 12 monthly values
class MonthWeekdayWeekendSchedule
  # weekday_hourly_values can either be a comma-separated string of 24 numbers or a 24-element array of numbers.
  # weekend_hourly_values can either be a comma-separated string of 24 numbers or a 24-element array of numbers.
  # monthly_values can either be a comma-separated string of 12 numbers or a 12-element array of numbers.
  def initialize(model, sch_name, weekday_hourly_values, weekend_hourly_values, monthly_values,
                 schedule_type_limits_name = nil, normalize_values = true, begin_month = 1,
                 begin_day = 1, end_month = 12, end_day = 31)
    @model = model
    @sch_name = sch_name
    @schedule = nil
    @weekday_hourly_values = validateValues(weekday_hourly_values, 24, 'weekday')
    @weekend_hourly_values = validateValues(weekend_hourly_values, 24, 'weekend')
    @monthly_values = validateValues(monthly_values, 12, 'monthly')
    @schedule_type_limits_name = schedule_type_limits_name
    @begin_month = begin_month
    @begin_day = begin_day
    @end_month = end_month
    @end_day = end_day

    if normalize_values
      @weekday_hourly_values = normalizeSumToOne(@weekday_hourly_values)
      @weekend_hourly_values = normalizeSumToOne(@weekend_hourly_values)
      @monthly_values = normalizeAvgToOne(@monthly_values)
      @maxval = calcMaxval()
      @schadjust = calcSchadjust()
    else
      @maxval = 1.0
      @schadjust = 1.0
    end
    @schedule = createSchedule()
  end

  def calcDesignLevelFromDailykWh(daily_kwh)
    return daily_kwh * @maxval * 1000 * @schadjust
  end

  def calcDesignLevelFromDailyTherm(daily_therm)
    return calcDesignLevelFromDailykWh(UnitConversions.convert(daily_therm, 'therm', 'kWh'))
  end

  def schedule
    return @schedule
  end

  private

  def validateValues(values, num_values, sch_name)
    err_msg = "A comma-separated string of #{num_values} numbers must be entered for the #{sch_name} schedule."
    if values.is_a?(Array)
      if values.length != num_values
        fail err_msg
      end

      values.each do |val|
        if not valid_float?(val)
          fail err_msg
        end
      end
      floats = values.map { |i| i.to_f }
    elsif values.is_a?(String)
      begin
        vals = values.split(',')
        vals.each do |val|
          if not valid_float?(val)
            fail err_msg
          end
        end
        floats = vals.map { |i| i.to_f }
        if floats.length != num_values
          fail err_msg
        end
      rescue
        fail err_msg
      end
    else
      fail err_msg
    end
    return floats
  end

  def valid_float?(str)
    !!Float(str) rescue false
  end

  def normalizeSumToOne(values)
    sum = values.reduce(:+).to_f
    if sum == 0.0
      return values
    end

    return values.map { |val| val / sum }
  end

  def normalizeAvgToOne(values)
    avg = values.reduce(:+).to_f / values.size
    if avg == 0.0
      return values
    end

    return values.map { |val| val / avg }
  end

  def calcMaxval()
    if @weekday_hourly_values.max > @weekend_hourly_values.max
      maxval = @monthly_values.max * @weekday_hourly_values.max
    else
      maxval = @monthly_values.max * @weekend_hourly_values.max
    end
    if maxval == 0.0
      maxval = 1.0 # Prevent divide by zero
    end
    return maxval
  end

  def calcSchadjust()
    # if sum != 1, normalize to get correct max val
    sum_wkdy = 0
    sum_wknd = 0
    @weekday_hourly_values.each do |v|
      sum_wkdy += v
    end
    @weekend_hourly_values.each do |v|
      sum_wknd += v
    end
    if sum_wkdy < sum_wknd
      return 1 / sum_wknd
    end

    return 1 / sum_wkdy
  end

  def createSchedule()
    month_num_days = Schedule.get_num_days_per_month(@model)
    month_num_days[@end_month - 1] = @end_day

    day_startm = Schedule.day_start_months(@model)
    day_startm[@begin_month - 1] += @begin_day - 1
    day_endm = [Schedule.day_start_months(@model), month_num_days].transpose.map { |i| i.reduce(:+) - 1 }

    time = []
    for h in 1..24
      time[h] = OpenStudio::Time.new(0, h, 0, 0)
    end

    schedule = OpenStudio::Model::ScheduleRuleset.new(@model)
    schedule.setName(@sch_name)

    assumedYear = @model.getYearDescription.assumedYear # prevent excessive OS warnings about 'UseWeatherFile'

    prev_wkdy_vals = nil
    prev_wkdy_rule = nil
    prev_wknd_vals = nil
    prev_wknd_rule = nil
    periods = []
    if @begin_month <= @end_month # contiguous period
      periods << [@begin_month, @end_month]
    else # non-contiguous period
      periods << [1, @end_month]
      periods << [@begin_month, 12]
    end

    periods.each do |period|
      for m in period[0]..period[1]
        date_s = OpenStudio::Date::fromDayOfYear(day_startm[m - 1], assumedYear)
        date_e = OpenStudio::Date::fromDayOfYear(day_endm[m - 1], assumedYear)

        wkdy_vals = []
        wknd_vals = []
        for h in 1..24
          wkdy_vals[h] = (@monthly_values[m - 1] * @weekday_hourly_values[h - 1]) / @maxval
          wknd_vals[h] = (@monthly_values[m - 1] * @weekend_hourly_values[h - 1]) / @maxval
        end

        if (wkdy_vals == prev_wkdy_vals) && (wknd_vals == prev_wknd_vals)
          # Extend end date of current rule(s)
          prev_wkdy_rule.setEndDate(date_e) unless prev_wkdy_rule.nil?
          prev_wknd_rule.setEndDate(date_e) unless prev_wknd_rule.nil?
        elsif wkdy_vals == wknd_vals
          # Alldays
          wkdy_rule = OpenStudio::Model::ScheduleRule.new(schedule)
          wkdy_rule.setName(@sch_name + " #{Schedule.allday_name} ruleset#{m}")
          wkdy = wkdy_rule.daySchedule
          wkdy.setName(@sch_name + " #{Schedule.allday_name}#{m}")
          previous_value = wkdy_vals[1]
          for h in 1..24
            next if (h != 24) && (wkdy_vals[h + 1] == previous_value)

            wkdy.addValue(time[h], previous_value)
            previous_value = wkdy_vals[h + 1]
          end
          Schedule.set_weekday_rule(wkdy_rule)
          Schedule.set_weekend_rule(wkdy_rule)
          wkdy_rule.setStartDate(date_s)
          wkdy_rule.setEndDate(date_e)
          prev_wkdy_rule = wkdy_rule
          prev_wknd_rule = nil
        else
          # Weekdays
          wkdy_rule = OpenStudio::Model::ScheduleRule.new(schedule)
          wkdy_rule.setName(@sch_name + " #{Schedule.weekday_name} ruleset#{m}")
          wkdy = wkdy_rule.daySchedule
          wkdy.setName(@sch_name + " #{Schedule.weekday_name}#{m}")
          previous_value = wkdy_vals[1]
          for h in 1..24
            next if (h != 24) && (wkdy_vals[h + 1] == previous_value)

            wkdy.addValue(time[h], previous_value)
            previous_value = wkdy_vals[h + 1]
          end
          Schedule.set_weekday_rule(wkdy_rule)
          wkdy_rule.setStartDate(date_s)
          wkdy_rule.setEndDate(date_e)
          prev_wkdy_rule = wkdy_rule

          # Weekends
          wknd_rule = OpenStudio::Model::ScheduleRule.new(schedule)
          wknd_rule.setName(@sch_name + " #{Schedule.weekend_name} ruleset#{m}")
          wknd = wknd_rule.daySchedule
          wknd.setName(@sch_name + " #{Schedule.weekend_name}#{m}")
          previous_value = wknd_vals[1]
          for h in 1..24
            next if (h != 24) && (wknd_vals[h + 1] == previous_value)

            wknd.addValue(time[h], previous_value)
            previous_value = wknd_vals[h + 1]
          end
          Schedule.set_weekend_rule(wknd_rule)
          wknd_rule.setStartDate(date_s)
          wknd_rule.setEndDate(date_e)
          prev_wknd_rule = wknd_rule
        end

        prev_wkdy_vals = wkdy_vals
        prev_wknd_vals = wknd_vals
      end
    end

    Schedule.set_schedule_type_limits(@model, schedule, @schedule_type_limits_name)

    return schedule
  end
end

class HotWaterSchedule
  def initialize(model, obj_name, nbeds, days_shift = 0, dryer_exhaust_min_runtime = 0, create_sch_object = true)
    @model = model
    @sch_name = "#{obj_name} schedule"
    @schedule = nil
    if nbeds < 1
      @nbeds = 1
    elsif nbeds > 5
      @nbeds = 5
    else
      @nbeds = nbeds
    end
    file_prefixes = { Constants.ObjectNameClothesWasher => 'ClothesWasher',
                      Constants.ObjectNameClothesDryer => 'ClothesWasher',
                      Constants.ObjectNameClothesDryerExhaust => 'ClothesWasher',
                      Constants.ObjectNameDishwasher => 'Dishwasher',
                      Constants.ObjectNameFixtures => 'Fixtures' }
    @file_prefix = file_prefixes[obj_name]

    timestep_minutes = (60 / @model.getTimestep.numberOfTimestepsPerHour).to_i
    weeks = 1 # use a single week that repeats

    @data = loadMinuteDrawProfileFromFile(timestep_minutes, days_shift, weeks, dryer_exhaust_min_runtime)
    @totflow, @maxflow, @ontime = loadDrawProfileStatsFromFile()
    if create_sch_object
      @schedule = createSchedule(@data, timestep_minutes, weeks)
    end
  end

  def data
    return @data
  end

  def calcDesignLevelFromDailykWh(daily_kWh)
    return UnitConversions.convert(daily_kWh * 365 * 60 / (365 * @totflow / @maxflow), 'kW', 'W')
  end

  def calcPeakFlowFromDailygpm(daily_water)
    return UnitConversions.convert(@maxflow * daily_water / @totflow, 'gal/min', 'm^3/s')
  end

  def calcDailyGpmFromPeakFlow(peak_flow)
    return UnitConversions.convert(@totflow * peak_flow / @maxflow, 'm^3/s', 'gal/min')
  end

  def calcDesignLevelFromDailyTherm(daily_therm)
    return calcDesignLevelFromDailykWh(UnitConversions.convert(daily_therm, 'therm', 'kWh'))
  end

  def schedule
    return @schedule
  end

  def totalFlow
    return @totflow
  end

  private

  def loadMinuteDrawProfileFromFile(timestep_minutes, days_shift, weeks, dryer_exhaust_min_runtime)
    data = []
    if @file_prefix.nil?
      return data
    end

    # Get appropriate file
    minute_draw_profile = File.join(File.dirname(__FILE__), "data_hot_water_#{@file_prefix.downcase}_schedule_#{@nbeds}bed.csv")
    if not File.file?(minute_draw_profile)
      fail "Unable to find file: #{minute_draw_profile}"
    end

    minutes_in_year = 8760 * 60
    weeks_in_minutes = weeks * 7 * 24 * 60

    # Read data into minute array
    skippedheader = false
    min_shift = 24 * 60 * (days_shift % 365) # For MF homes, shift each unit by an additional week
    items = [0] * minutes_in_year
    File.open(minute_draw_profile).each do |line|
      linedata = line.strip.split(',')
      if not skippedheader
        skippedheader = true
        next
      end
      shifted_minute = linedata[0].to_i - min_shift
      if shifted_minute < 0
        stored_minute = shifted_minute + minutes_in_year
      else
        stored_minute = shifted_minute
      end
      value = linedata[1].to_f
      items[stored_minute.to_i] = value
      if shifted_minute >= weeks_in_minutes
        break # no need to process more data
      end
    end

    if dryer_exhaust_min_runtime > 0
      # Clothes dryer exhaust vent should operate whenever the dryer is operating,
      # with a minimum runtime in minutes.
      items.reverse.each_with_index do |val, i|
        next unless val > 0

        place = (items.length - 1) - i
        last = place + dryer_exhaust_min_runtime
        items.fill(1, place...last)
      end
    end

    # Aggregate minute schedule up to the timestep level to reduce the size
    # and speed of processing.
    for tstep in 0..(minutes_in_year / timestep_minutes).to_i - 1
      timestep_items = items[tstep * timestep_minutes, timestep_minutes]
      avgitem = timestep_items.reduce(:+).to_f / timestep_items.size
      data.push(avgitem)
      if (tstep + 1) * timestep_minutes > weeks_in_minutes
        break # no need to process more data
      end
    end

    return data
  end

  def loadDrawProfileStatsFromFile()
    totflow = 0 # daily gal/day
    maxflow = 0
    ontime = 0

    column_header = @file_prefix

    totflow_column_header = "#{column_header} Sum"
    maxflow_column_header = "#{column_header} Max"
    ontime_column_header = 'On-time Fraction'

    draw_file = File.join(File.dirname(__FILE__), 'data_hot_water_max_flows.csv')

    datafound = false
    skippedheader = false
    totflow_col_num = nil
    maxflow_col_num = nil
    ontime_col_num = nil
    File.open(draw_file).each do |line|
      linedata = line.strip.split(',')
      if not skippedheader
        skippedheader = true
        # Which columns to read?
        totflow_col_num = linedata.index(totflow_column_header)
        maxflow_col_num = linedata.index(maxflow_column_header)
        ontime_col_num = linedata.index(ontime_column_header)
        next
      end
      next unless linedata[0].to_i == @nbeds

      datafound = true
      if not totflow_col_num.nil?
        totflow = linedata[totflow_col_num].to_f
      end
      if not maxflow_col_num.nil?
        maxflow = linedata[maxflow_col_num].to_f
      end
      if not ontime_col_num.nil?
        ontime = linedata[ontime_col_num].to_f
      end
      break
    end

    if not datafound
      fail "Unable to find data for bedrooms = #{@nbeds}."
    end

    return totflow, maxflow, ontime
  end

  def createSchedule(data, timestep_minutes, weeks)
    data_size = data.size
    if data_size == 0
      return
    end

    assumed_year = @model.getYearDescription.assumedYear

    last_day_of_year = Schedule.get_num_days_in_year(@model)

    # Create ScheduleRuleset with repeating weeks

    time = []
    (timestep_minutes..24 * 60).step(timestep_minutes).to_a.each_with_index do |m, i|
      time[i] = OpenStudio::Time.new(0, 0, m, 0)
    end

    schedule = OpenStudio::Model::ScheduleRuleset.new(@model)

    schedule_rules = []
    for d in 1..7 * weeks # how many unique day schedules
      next if d > last_day_of_year

      rule = OpenStudio::Model::ScheduleRule.new(schedule)
      rule.setName(@sch_name + " #{Schedule.allday_name} ruleset#{d}")
      day_schedule = rule.daySchedule
      day_schedule.setName(@sch_name + " #{Schedule.allday_name}#{d}")
      previous_value = data[(d - 1) * 24 * 60 / timestep_minutes]
      time.each_with_index do |m, i|
        if i != time.length - 1
          next if data[i + 1 + (d - 1) * 24 * 60 / timestep_minutes] == previous_value
        end
        day_schedule.addValue(m, previous_value)
        previous_value = data[i + 1 + (d - 1) * 24 * 60 / timestep_minutes]
      end
      Schedule.set_weekday_rule(rule)
      Schedule.set_weekend_rule(rule)
      for w in 0..52 # max num of weeks
        next if d + (w * 7 * weeks) > last_day_of_year

        date_s = OpenStudio::Date::fromDayOfYear(d + (w * 7 * weeks), assumed_year)
        rule.addSpecificDate(date_s)
      end
    end

    schedule.setName(@sch_name)

    return schedule
  end
end

class Schedule
  def self.allday_name
    return 'allday'
  end

  def self.weekday_name
    return 'weekday'
  end

  def self.weekend_name
    return 'weekend'
  end

  # return [Double] The total number of full load hours for this schedule.
  def self.annual_equivalent_full_load_hrs(modelYear, schedule)
    if schedule.to_ScheduleInterval.is_initialized
      timeSeries = schedule.to_ScheduleInterval.get.timeSeries
      annual_flh = timeSeries.averageValue * 8760
      return annual_flh
    end

    if not schedule.to_ScheduleRuleset.is_initialized
      return
    end

    schedule = schedule.to_ScheduleRuleset.get

    # Define the start and end date
    year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, modelYear)
    year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, modelYear)

    # Get the ordered list of all the day schedules
    # that are used by this schedule ruleset
    day_schs = schedule.getDaySchedules(year_start_date, year_end_date)

    # Get a 365-value array of which schedule is used on each day of the year,
    day_schs_used_each_day = schedule.getActiveRuleIndices(year_start_date, year_end_date)
    if !day_schs_used_each_day.length == 365
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.ScheduleRuleset', "#{schedule.name} does not have 365 daily schedules accounted for, cannot accurately calculate annual EFLH.")
      return 0
    end

    # Create a map that shows how many days each schedule is used
    day_sch_freq = day_schs_used_each_day.group_by { |n| n }

    # Build a hash that maps schedule day index to schedule day
    schedule_index_to_day = {}
    for i in 0..(day_schs.length - 1)
      schedule_index_to_day[day_schs_used_each_day[i]] = day_schs[i]
    end

    # Loop through each of the schedules that is used, figure out the
    # full load hours for that day, then multiply this by the number
    # of days that day schedule applies and add this to the total.
    annual_flh = 0
    max_daily_flh = 0
    default_day_sch = schedule.defaultDaySchedule
    day_sch_freq.each do |freq|
      sch_index = freq[0]
      number_of_days_sch_used = freq[1].size

      # Get the day schedule at this index
      day_sch = nil
      if sch_index == -1 # If index = -1, this day uses the default day schedule (not a rule)
        day_sch = default_day_sch
      else
        day_sch = schedule_index_to_day[sch_index]
      end

      # Determine the full load hours for just one day
      daily_flh = 0
      values = day_sch.values
      times = day_sch.times

      previous_time_decimal = 0
      for i in 0..(times.length - 1)
        time_days = times[i].days
        time_hours = times[i].hours
        time_minutes = times[i].minutes
        time_seconds = times[i].seconds
        time_decimal = (time_days * 24.0) + time_hours + (time_minutes / 60.0) + (time_seconds / 3600.0)
        duration_of_value = time_decimal - previous_time_decimal
        daily_flh += values[i] * duration_of_value
        previous_time_decimal = time_decimal
      end

      # Multiply the daily EFLH by the number
      # of days this schedule is used per year
      # and add this to the overall total
      annual_flh += daily_flh * number_of_days_sch_used
    end

    # Warn if the max daily EFLH is more than 24,
    # which would indicate that this isn't a
    # fractional schedule.
    if max_daily_flh > 24
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.ScheduleRuleset', "#{schedule.name} has more than 24 EFLH in one day schedule, indicating that it is not a fractional schedule.")
    end

    return annual_flh
  end

  def self.set_schedule_type_limits(model, schedule, schedule_type_limits_name)
    return if schedule_type_limits_name.nil?

    schedule_type_limits = nil
    model.getScheduleTypeLimitss.each do |stl|
      next if stl.name.to_s != schedule_type_limits_name

      schedule_type_limits = stl
      break
    end

    if schedule_type_limits.nil?
      schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
      schedule_type_limits.setName(schedule_type_limits_name)
      if schedule_type_limits_name == Constants.ScheduleTypeLimitsFraction
        schedule_type_limits.setLowerLimitValue(0)
        schedule_type_limits.setUpperLimitValue(1)
        schedule_type_limits.setNumericType('Continuous')
      elsif schedule_type_limits_name == Constants.ScheduleTypeLimitsOnOff
        schedule_type_limits.setLowerLimitValue(0)
        schedule_type_limits.setUpperLimitValue(1)
        schedule_type_limits.setNumericType('Discrete')
      elsif schedule_type_limits_name == Constants.ScheduleTypeLimitsTemperature
        schedule_type_limits.setNumericType('Continuous')
      end
    end

    schedule.setScheduleTypeLimits(schedule_type_limits)
  end

  def self.set_weekday_rule(rule)
    rule.setApplyMonday(true)
    rule.setApplyTuesday(true)
    rule.setApplyWednesday(true)
    rule.setApplyThursday(true)
    rule.setApplyFriday(true)
  end

  def self.set_weekend_rule(rule)
    rule.setApplySaturday(true)
    rule.setApplySunday(true)
  end

  def self.OccupantsWeekdayFractions
    return '1.00000, 1.00000, 1.00000, 1.00000, 1.00000, 1.00000, 1.00000, 0.88310, 0.40861, 0.24189, 0.24189, 0.24189, 0.24189, 0.24189, 0.24189, 0.24189, 0.29498, 0.55310, 0.89693, 0.89693, 0.89693, 1.00000, 1.00000, 1.00000'
  end

  def self.OccupantsWeekendFractions
    return '1.00000, 1.00000, 1.00000, 1.00000, 1.00000, 1.00000, 1.00000, 0.88310, 0.40861, 0.24189, 0.24189, 0.24189, 0.24189, 0.24189, 0.24189, 0.24189, 0.29498, 0.55310, 0.89693, 0.89693, 0.89693, 1.00000, 1.00000, 1.00000'
  end

  def self.OccupantsMonthlyMultipliers
    return '1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0'
  end

  def self.LightingExteriorWeekdayFractions
    # Schedules from T24 2016 Residential ACM Appendix C Table 8 Exterior Lighting Hourly Multiplier (Weekdays and weekends)
    return '0.046, 0.046, 0.046, 0.046, 0.046, 0.037, 0.035, 0.034, 0.033, 0.028, 0.022, 0.015, 0.012, 0.011, 0.011, 0.012, 0.019, 0.037, 0.049, 0.065, 0.091, 0.105, 0.091, 0.063'
  end

  def self.LightingExteriorWeekendFractions
    return '0.046, 0.046, 0.045, 0.045, 0.046, 0.045, 0.044, 0.041, 0.036, 0.03, 0.024, 0.016, 0.012, 0.011, 0.011, 0.012, 0.019, 0.038, 0.048, 0.06, 0.083, 0.098, 0.085, 0.059'
  end

  def self.LightingExteriorMonthlyMultipliers
    return '1.248, 1.257, 0.993, 0.989, 0.993, 0.827, 0.821, 0.821, 0.827, 0.99, 0.987, 1.248'
  end

  def self.LightingExteriorHolidayWeekdayFractions
    return '0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.008, 0.098, 0.168, 0.194, 0.284, 0.192, 0.037, 0.019'
  end

  def self.LightingExteriorHolidayWeekendFractions
    return '0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.008, 0.098, 0.168, 0.194, 0.284, 0.192, 0.037, 0.019'
  end

  def self.LightingExteriorHolidayMonthlyMultipliers
    return '1.248, 1.257, 0.993, 0.989, 0.993, 0.827, 0.821, 0.821, 0.827, 0.99, 0.987, 1.248'
  end

  def self.CookingRangeWeekdayFractions
    return '0.007, 0.007, 0.004, 0.004, 0.007, 0.011, 0.025, 0.042, 0.046, 0.048, 0.042, 0.050, 0.057, 0.046, 0.057, 0.044, 0.092, 0.150, 0.117, 0.060, 0.035, 0.025, 0.016, 0.011'
  end

  def self.CookingRangeWeekendFractions
    return '0.007, 0.007, 0.004, 0.004, 0.007, 0.011, 0.025, 0.042, 0.046, 0.048, 0.042, 0.050, 0.057, 0.046, 0.057, 0.044, 0.092, 0.150, 0.117, 0.060, 0.035, 0.025, 0.016, 0.011'
  end

  def self.CookingRangeMonthlyMultipliers
    return '1.097, 1.097, 0.991, 0.987, 0.991, 0.890, 0.896, 0.896, 0.890, 1.085, 1.085, 1.097'
  end

  def self.RefrigeratorWeekdayFractions
    return '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
  end

  def self.RefrigeratorWeekendFractions
    return '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
  end

  def self.RefrigeratorMonthlyMultipliers
    return '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837'
  end

  def self.ExtraRefrigeratorWeekdayFractions
    return '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
  end

  def self.ExtraRefrigeratorWeekendFractions
    return '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
  end

  def self.ExtraRefrigeratorMonthlyMultipliers
    return '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837'
  end

  def self.FreezerWeekdayFractions
    return '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
  end

  def self.FreezerWeekendFractions
    return '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
  end

  def self.FreezerMonthlyMultipliers
    return '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837'
  end

  def self.CeilingFanWeekdayFractions
    return '0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0'
  end

  def self.CeilingFanWeekendFractions
    return '0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0'
  end

  def self.CeilingFanMonthlyMultipliers(weather:)
    return HVAC.get_default_ceiling_fan_months(weather).join(', ')
  end

  def self.PlugLoadsOtherWeekdayFractions
    return '0.035, 0.033, 0.032, 0.031, 0.032, 0.033, 0.037, 0.042, 0.043, 0.043, 0.043, 0.044, 0.045, 0.045, 0.044, 0.046, 0.048, 0.052, 0.053, 0.05, 0.047, 0.045, 0.04, 0.036'
  end

  def self.PlugLoadsOtherWeekendFractions
    return '0.035, 0.033, 0.032, 0.031, 0.032, 0.033, 0.037, 0.042, 0.043, 0.043, 0.043, 0.044, 0.045, 0.045, 0.044, 0.046, 0.048, 0.052, 0.053, 0.05, 0.047, 0.045, 0.04, 0.036'
  end

  def self.PlugLoadsOtherMonthlyMultipliers
    return '1.248, 1.257, 0.993, 0.989, 0.993, 0.827, 0.821, 0.821, 0.827, 0.99, 0.987, 1.248'
  end

  def self.PlugLoadsTVWeekdayFractions
    return '0.037, 0.018, 0.009, 0.007, 0.011, 0.018, 0.029, 0.040, 0.049, 0.058, 0.065, 0.072, 0.076, 0.086, 0.091, 0.102, 0.127, 0.156, 0.210, 0.294, 0.363, 0.344, 0.208, 0.090'
  end

  def self.PlugLoadsTVWeekendFractions
    return '0.044, 0.022, 0.012, 0.008, 0.011, 0.014, 0.024, 0.043, 0.071, 0.094, 0.112, 0.123, 0.132, 0.156, 0.178, 0.196, 0.206, 0.213, 0.251, 0.330, 0.388, 0.358, 0.226, 0.103'
  end

  def self.PlugLoadsTVMonthlyMultipliers
    return '1.137, 1.129, 0.961, 0.969, 0.961, 0.993, 0.996, 0.96, 0.993, 0.867, 0.86, 1.137'
  end

  def self.PlugLoadsVehicleWeekdayFractions
    return '0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042'
  end

  def self.PlugLoadsVehicleWeekendFractions
    return '0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042'
  end

  def self.PlugLoadsVehicleMonthlyMultipliers
    return '1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1'
  end

  def self.PlugLoadsWellPumpWeekdayFractions
    return '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065'
  end

  def self.PlugLoadsWellPumpWeekendFractions
    return '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065'
  end

  def self.PlugLoadsWellPumpMonthlyMultipliers
    return '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154'
  end

  def self.FuelLoadsGrillWeekdayFractions
    return '0.004, 0.001, 0.001, 0.002, 0.007, 0.012, 0.029, 0.046, 0.044, 0.041, 0.044, 0.046, 0.042, 0.038, 0.049, 0.059, 0.110, 0.161, 0.115, 0.070, 0.044, 0.019, 0.013, 0.007'
  end

  def self.FuelLoadsGrillWeekendFractions
    return '0.004, 0.001, 0.001, 0.002, 0.007, 0.012, 0.029, 0.046, 0.044, 0.041, 0.044, 0.046, 0.042, 0.038, 0.049, 0.059, 0.110, 0.161, 0.115, 0.070, 0.044, 0.019, 0.013, 0.007'
  end

  def self.FuelLoadsGrillMonthlyMultipliers
    return '1.097, 1.097, 0.991, 0.987, 0.991, 0.890, 0.896, 0.896, 0.890, 1.085, 1.085, 1.097'
  end

  def self.FuelLoadsLightingWeekdayFractions
    return '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065'
  end

  def self.FuelLoadsLightingWeekendFractions
    return '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065'
  end

  def self.FuelLoadsLightingMonthlyMultipliers
    return '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154'
  end

  def self.FuelLoadsFireplaceWeekdayFractions
    return '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065'
  end

  def self.FuelLoadsFireplaceWeekendFractions
    return '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065'
  end

  def self.FuelLoadsFireplaceMonthlyMultipliers
    return '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154'
  end

  def self.PoolPumpWeekdayFractions
    return '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003'
  end

  def self.PoolPumpWeekendFractions
    return '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003'
  end

  def self.PoolPumpMonthlyMultipliers
    return '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154'
  end

  def self.PoolHeaterWeekdayFractions
    return '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003'
  end

  def self.PoolHeaterWeekendFractions
    return '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003'
  end

  def self.PoolHeaterMonthlyMultipliers
    return '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154'
  end

  def self.HotTubPumpWeekdayFractions
    return '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024'
  end

  def self.HotTubPumpWeekendFractions
    return '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024'
  end

  def self.HotTubPumpMonthlyMultipliers
    return '0.921, 0.928, 0.921, 0.915, 0.921, 1.160, 1.158, 1.158, 1.160, 0.921, 0.915, 0.921'
  end

  def self.HotTubHeaterWeekdayFractions
    return '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024'
  end

  def self.HotTubHeaterWeekendFractions
    return '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024'
  end

  def self.HotTubHeaterMonthlyMultipliers
    return '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837'
  end

  def self.get_num_days_per_month(model)
    month_num_days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    month_num_days[1] += 1 if (!model.nil? && model.getYearDescription.isLeapYear)
    return month_num_days
  end

  def self.get_num_days_in_year(model)
    return get_num_days_per_month(model).sum
  end

  def self.get_day_num_from_month_day(model, month, day)
    # Returns a value between 1 and 365 (or 366 for a leap year)
    # Returns e.g. 32 for month=2 and day=1 (Feb 1)
    month_num_days = get_num_days_per_month(model)
    day_num = day
    for m in 0..month - 2
      day_num += month_num_days[m]
    end
    return day_num
  end

  def self.get_daily_season(model, start_month, start_day, end_month, end_day)
    start_day_num = get_day_num_from_month_day(model, start_month, start_day)
    end_day_num = get_day_num_from_month_day(model, end_month, end_day)

    season = Array.new(get_num_days_in_year(model), 0)
    if end_day_num >= start_day_num
      season.fill(1, start_day_num - 1, end_day_num - start_day_num + 1) # Fill between start/end days
    else # Wrap around year
      season.fill(1, start_day_num - 1) # Fill between start day and end of year
      season.fill(1, 0, end_day_num) # Fill between start of year and end day
    end
    return season
  end

  def self.months_to_days(model, months)
    month_num_days = get_num_days_per_month(model)
    days = []
    for m in 0..11
      days.concat([months[m]] * month_num_days[m])
    end
    return days
  end

  def self.day_start_months(model)
    month_num_days = get_num_days_per_month(model)
    return month_num_days.each_with_index.map { |n, i| get_day_num_from_month_day(model, i + 1, 1) }
  end

  def self.day_end_months(model)
    month_num_days = get_num_days_per_month(model)
    return month_num_days.each_with_index.map { |n, i| get_day_num_from_month_day(model, i + 1, n) }
  end

  def self.create_ruleset_from_daily_season(model, values)
    s = OpenStudio::Model::ScheduleRuleset.new(model)
    year = model.getYearDescription.assumedYear
    start_value = values[0]
    start_date = OpenStudio::Date::fromDayOfYear(1, year)
    values.each_with_index do |value, i|
      i += 1
      next unless value != start_value || i == values.length

      rule = OpenStudio::Model::ScheduleRule.new(s)
      set_weekday_rule(rule)
      set_weekend_rule(rule)
      i += 1 if i == values.length
      end_date = OpenStudio::Date::fromDayOfYear(i - 1, year)
      rule.setStartDate(start_date)
      rule.setEndDate(end_date)
      day_schedule = rule.daySchedule
      day_schedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), start_value)
      break if i == values.length + 1

      start_date = OpenStudio::Date::fromDayOfYear(i, year)
      start_value = value
    end
    return s
  end
end

class SchedulesFile
  def initialize(runner:,
                 model:,
                 schedules_path:,
                 col_names:,
                 **remainder)

    @validated = true
    @runner = runner
    @model = model
    @schedules_path = schedules_path
    @external_file = get_external_file
    import(col_names: col_names)
  end

  def validated?
    return @validated
  end

  def schedules
    return @schedules
  end

  def get_col_index(col_name:)
    headers = CSV.open(@schedules_path, 'r') { |csv| csv.first }
    col_num = headers.index(col_name)
    return col_num
  end

  def get_col_name(col_index:)
    headers = CSV.open(@schedules_path, 'r') { |csv| csv.first }
    col_name = headers[col_index]
    return col_name
  end

  def create_schedule_file(col_name:,
                           rows_to_skip: 1)
    @model.getScheduleFiles.each do |schedule_file|
      next if schedule_file.name.to_s != col_name

      return schedule_file
    end

    if @schedules[col_name].nil?
      @runner.registerError("Could not find the '#{col_name}' schedule.")
      return false
    end

    col_index = get_col_index(col_name: col_name)
    year_description = @model.getYearDescription
    num_hrs_in_year = Constants.NumHoursInYear(year_description.isLeapYear)
    schedule_length = @schedules[col_name].length
    min_per_item = 60.0 / (schedule_length / num_hrs_in_year)

    schedule_file = OpenStudio::Model::ScheduleFile.new(@external_file)
    schedule_file.setName(col_name)
    schedule_file.setColumnNumber(col_index + 1)
    schedule_file.setRowstoSkipatTop(rows_to_skip)
    schedule_file.setNumberofHoursofData(num_hrs_in_year.to_i)
    schedule_file.setMinutesperItem(min_per_item.to_i)

    return schedule_file
  end

  # the equivalent number of hours in the year, if the schedule was at full load (1.0)
  def annual_equivalent_full_load_hrs(col_name:)
    # import(col_names: [col_name])

    year_description = @model.getYearDescription
    num_hrs_in_year = Constants.NumHoursInYear(year_description.isLeapYear)
    schedule_length = @schedules[col_name].length
    min_per_item = 60.0 / (schedule_length / num_hrs_in_year)

    ann_equiv_full_load_hrs = @schedules[col_name].reduce(:+) / (60.0 / min_per_item)

    return ann_equiv_full_load_hrs
  end

  # the power in watts the equipment needs to consume so that, if it were to run annual_equivalent_full_load_hrs hours,
  # it would consume the annual_kwh energy in the year. Essentially, returns the watts for the equipment when schedule
  # is at 1.0, so that, for the given schedule values, the equipment will consume annual_kwh energy in a year.
  def calc_design_level_from_annual_kwh(col_name:,
                                        annual_kwh:)

    ann_equiv_full_load_hrs = annual_equivalent_full_load_hrs(col_name: col_name)
    design_level = annual_kwh * 1000.0 / ann_equiv_full_load_hrs # W

    return design_level
  end

  # Similar to ann_equiv_full_load_hrs, but for thermal energy
  def calc_design_level_from_annual_therm(col_name:,
                                          annual_therm:)

    annual_kwh = UnitConversions.convert(annual_therm, 'therm', 'kWh')
    design_level = calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: annual_kwh)

    return design_level
  end

  # similar to the calc_design_level_from_annual_kwh, but use daily_kwh instead of annual_kwh to calculate the design
  # level
  def calc_design_level_from_daily_kwh(col_name:,
                                       daily_kwh:)
    full_load_hrs = annual_equivalent_full_load_hrs(col_name: col_name)
    year_description = @model.getYearDescription
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)
    daily_full_load_hrs = full_load_hrs / num_days_in_year
    design_level = UnitConversions.convert(daily_kwh / daily_full_load_hrs, 'kW', 'W')

    return design_level
  end

  # thermal equivalent of calc_design_level_from_daily_kwh
  def calc_design_level_from_daily_therm(col_name:,
                                         daily_therm:)
    daily_kwh = UnitConversions.convert(daily_therm, 'therm', 'kWh')
    design_level = calc_design_level_from_daily_kwh(col_name: col_name, daily_kwh: daily_kwh)
    return design_level
  end

  # similar to calc_design_level_from_daily_kwh but for water usage
  def calc_peak_flow_from_daily_gpm(col_name:, daily_water:)
    ann_equiv_full_load_hrs = annual_equivalent_full_load_hrs(col_name: col_name)
    year_description = @model.getYearDescription
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)
    daily_full_load_hrs = ann_equiv_full_load_hrs / num_days_in_year
    peak_flow = daily_water / daily_full_load_hrs # gallons_per_hour
    peak_flow /= 60 # convert to gallons per minute
    peak_flow = UnitConversions.convert(peak_flow, 'gal/min', 'm^3/s') # convert to m^3/s
    return peak_flow
  end

  # get daily gallons from the peak flow rate
  def calc_daily_gpm_from_peak_flow(col_name:, peak_flow:)
    ann_equiv_full_load_hrs = annual_equivalent_full_load_hrs(col_name: col_name)
    year_description = @model.getYearDescription
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)
    peak_flow = UnitConversions.convert(peak_flow, 'm^3/s', 'gal/min')
    daily_gallons = (ann_equiv_full_load_hrs * 60 * peak_flow) / num_days_in_year
    return daily_gallons
  end

  def validate_schedule(col_name:,
                        values:)

    year_description = @model.getYearDescription
    num_hrs_in_year = Constants.NumHoursInYear(year_description.isLeapYear)
    schedule_length = values.length

    if values.max > 1
      @runner.registerError("The max value of schedule '#{col_name}' is greater than 1.")
      @validated = false
    end

    min_per_item = 60.0 / (schedule_length / num_hrs_in_year)
    unless [1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30, 60].include? min_per_item
      @runner.registerError("Calculated an invalid schedule min_per_item=#{min_per_item}.")
      @validated = false
    end
  end

  def external_file
    return @external_file
  end

  def get_external_file
    if File.exist? @schedules_path
      external_file = OpenStudio::Model::ExternalFile::getExternalFile(@model, @schedules_path)
      if external_file.is_initialized
        external_file = external_file.get
      end
    end
    return external_file
  end

  def set_vacancy
    return unless @schedules.keys.include? 'vacancy'
    return if @schedules['vacancy'].all? { |i| i == 0 }

    col_names = ScheduleGenerator.col_names

    @schedules[col_names.keys[0]].each_with_index do |ts, i|
      col_names.keys.each do |col_name|
        next unless col_names[col_name] # skip those unaffected by vacancy

        @schedules[col_name][i] *= (1.0 - @schedules['vacancy'][i])
      end
    end

    update(col_names: col_names.keys)
  end

  def set_outage(outage_start_date:,
                 outage_end_date:)

    minutes_per_step = 60
    if @model.getSimulationControl.timestep.is_initialized
      minutes_per_step = 60 / @model.getSimulationControl.timestep.get.numberOfTimestepsPerHour
    end

    col_names = ScheduleGenerator.col_names

    sec_per_step = minutes_per_step * 60.0
    col_names.each do |col_name, val|
      next if col_name == 'occupants'
      next if val.nil?

      ts = Time.new(outage_start_date.year, 'Jan', 1)
      @schedules[col_name].each_with_index do |step, i|
        if outage_start_date <= ts && ts < outage_end_date # in the outage period
          @schedules[col_name][i] = 0.0
        end
        ts += sec_per_step
      end
    end

    update(col_names: col_names.keys)
  end

  def import(col_names:)
    @schedules = {}
    col_names += ['vacancy']
    columns = CSV.read(@schedules_path).transpose
    columns.each do |col|
      next if not col_names.include? col[0]

      values = col[1..-1].reject { |v| v.nil? }
      values = values.map { |v| v.to_f }
      validate_schedule(col_name: col[0], values: values)
      @schedules[col[0]] = values
    end
  end

  def export
    return false if @schedules_path.nil?

    CSV.open(@schedules_path, 'wb') do |csv|
      csv << @schedules.keys
      rows = @schedules.values.transpose
      rows.each do |row|
        csv << row
      end
    end

    return true
  end

  def update(col_names:)
    return false if @schedules_path.nil?

    # need to update schedules csv in generated_files folder (alongside run folder) since this is what the simulation points to
    begin
      schedules_path = File.expand_path(File.join(File.dirname(@schedules_path), '../generated_files', File.basename(@schedules_path))) # called from cli
      columns = CSV.read(schedules_path).transpose
    rescue
      schedules_path = File.expand_path(File.join(File.dirname(@schedules_path), '../../../files', File.basename(@schedules_path))) # testing
      columns = CSV.read(schedules_path).transpose
    end

    col_names.each do |col_name|
      col_num = get_col_index(col_name: col_name)
      columns.each_with_index do |col, i|
        next unless i == col_num

        columns[i][1..-1] = @schedules[col_name]
      end
    end

    rows = columns.transpose
    CSV.open(schedules_path, 'wb') do |csv|
      rows.each do |row|
        csv << row
      end
    end
  end
end
