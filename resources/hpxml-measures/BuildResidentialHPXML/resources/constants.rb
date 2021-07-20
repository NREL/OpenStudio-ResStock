# frozen_string_literal: true

class Constants
  def self.Auto
    return 'auto'
  end

  def self.CoordRelative
    return 'relative'
  end

  def self.FacadeFront
    return 'front'
  end

  def self.FacadeBack
    return 'back'
  end

  def self.FacadeLeft
    return 'left'
  end

  def self.FacadeRight
    return 'right'
  end

  def self.OptionTypeLightingScheduleCalculated
    return 'Calculated Lighting Schedule'
  end

  # Numbers --------------------

  def self.NumDaysInMonths(is_leap_year = false)
    num_days_in_months = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    num_days_in_months[1] += 1 if is_leap_year
    return num_days_in_months
  end

  def self.NumDaysInYear(is_leap_year = false)
    num_days_in_months = NumDaysInMonths(is_leap_year)
    num_days_in_year = num_days_in_months.reduce(:+)
    return num_days_in_year.to_f
  end

  def self.NumHoursInYear(is_leap_year = false)
    num_days_in_year = NumDaysInYear(is_leap_year)
    num_hours_in_year = num_days_in_year * 24
    return num_hours_in_year.to_f
  end

  def self.PeakFlowRate
    return 500 # gal/min
  end

  def self.PeakPower
    return 100 # kWh
  end
end
