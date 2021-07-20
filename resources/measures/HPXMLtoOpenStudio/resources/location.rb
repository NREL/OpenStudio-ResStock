# frozen_string_literal: true

require_relative 'weather'
require_relative 'constants'
require_relative 'unit_conversions'

class Location
  def self.apply(model, runner, weather_file_path, dst_start_date, dst_end_date)
    success, weather, epw_file = apply_weather_file(model, runner, weather_file_path)
    return false if not success

    success = apply_year(model, epw_file)
    return false if not success

    success = apply_site(model, runner, epw_file)
    return false if not success

    success = apply_climate_zones(model, runner, epw_file)
    return false if not success

    success = apply_mains_temp(model, runner, weather)
    return false if not success

    success = apply_dst(model, runner, dst_start_date, dst_end_date)
    return false if not success

    success = apply_ground_temp(model, runner, weather)
    return false if not success

    return true, weather
  end

  private

  def self.apply_weather_file(model, runner, weather_file_path)
    if File.exist?(weather_file_path) && weather_file_path.downcase.end_with?('.epw')
      epw_file = OpenStudio::EpwFile.new(weather_file_path)
    else
      runner.registerError("'#{weather_file_path}' does not exist or is not an .epw file.")
      return false
    end

    OpenStudio::Model::WeatherFile.setWeatherFile(model, epw_file).get
    runner.registerInfo('Setting weather file.')

    # Obtain weather object
    # Load from cache file if exists, as this is faster and doesn't require
    # parsing the weather file.
    cache_file = weather_file_path.gsub('.epw', '.cache')
    if File.exist? cache_file
      weather = Marshal.load(File.binread(cache_file))
      weather.cache_weather(model)
    else
      weather = WeatherProcess.new(model, runner)
      if weather.error?
        return false
      end
    end

    return true, weather, epw_file
  end

  def self.apply_year(model, epw_file)
    year_description = model.getYearDescription
    if epw_file.startDateActualYear.is_initialized # AMY
      year_description.setCalendarYear(epw_file.startDateActualYear.get)
    end

    return true
  end

  def self.apply_site(model, runner, epw_file)
    site = model.getSite
    site.setName("#{epw_file.city}_#{epw_file.stateProvinceRegion}_#{epw_file.country}")
    site.setLatitude(epw_file.latitude)
    site.setLongitude(epw_file.longitude)
    site.setTimeZone(epw_file.timeZone)
    site.setElevation(epw_file.elevation)
    runner.registerInfo('Setting site data.')

    return true
  end

  def self.apply_climate_zones(model, runner, epw_file)
    ba_zone = get_climate_zone_ba(epw_file.wmoNumber)
    return true if ba_zone.nil?

    climateZones = model.getClimateZones
    climateZones.setClimateZone(Constants.BuildingAmericaClimateZone, ba_zone)
    runner.registerInfo("Setting #{Constants.BuildingAmericaClimateZone} climate zone to #{ba_zone}.")

    return true
  end

  def self.apply_mains_temp(model, runner, weather)
    avgOAT = UnitConversions.convert(weather.data.AnnualAvgDrybulb, 'F', 'C')
    monthlyOAT = weather.data.MonthlyAvgDrybulbs

    min_temp = monthlyOAT.min
    max_temp = monthlyOAT.max

    maxDiffOAT = UnitConversions.convert(max_temp, 'F', 'C') - UnitConversions.convert(min_temp, 'F', 'C')

    # Calc annual average mains temperature to report
    swmt = model.getSiteWaterMainsTemperature
    swmt.setCalculationMethod('Correlation')
    swmt.setAnnualAverageOutdoorAirTemperature(avgOAT)
    swmt.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(maxDiffOAT)

    runner.registerInfo('Setting mains water temperature profile.')

    return true
  end

  def self.apply_dst(model, runner, dst_start_date, dst_end_date)
    if not ((dst_start_date.downcase == 'na') && (dst_end_date.downcase == 'na'))
      begin
        dst_start_date_month = OpenStudio::monthOfYear(dst_start_date.split[0])
        dst_start_date_day = dst_start_date.split[1].to_i
        dst_end_date_month = OpenStudio::monthOfYear(dst_end_date.split[0])
        dst_end_date_day = dst_end_date.split[1].to_i

        dst = model.getRunPeriodControlDaylightSavingTime
        dst.setStartDate(dst_start_date_month, dst_start_date_day)
        dst.setEndDate(dst_end_date_month, dst_end_date_day)

        runner.registerInfo("Set daylight saving time from #{dst.startDate} to #{dst.endDate}.")
      rescue
        runner.registerError('Invalid daylight saving date(s) specified.')
        return false
      end
    else
      runner.registerInfo('No daylight saving time set.')
    end

    return true
  end

  def self.apply_ground_temp(model, runner, weather)
    annual_temps = Array.new(12, weather.data.AnnualAvgDrybulb)
    annual_temps = annual_temps.map { |i| UnitConversions.convert(i, 'F', 'C') }
    s_gt_d = model.getSiteGroundTemperatureDeep
    s_gt_d.resetAllMonths
    s_gt_d.setAllMonthlyTemperatures(annual_temps)

    return true
  end

  def self.get_climate_zones
    zones_csv = File.join(File.dirname(__FILE__), 'climate_zones.csv')
    if not File.exist?(zones_csv)
      return
    end

    return zones_csv
  end

  def self.get_climate_zone_ba(wmo)
    zones_csv = get_climate_zones
    return if zones_csv.nil?

    require 'csv'
    CSV.foreach(zones_csv) do |row|
      return row[5].to_s if row[0].to_s == wmo.to_s
    end

    return
  end

  def self.get_climate_zone_iecc(wmo)
    zones_csv = get_climate_zones
    return if zones_csv.nil?

    require 'csv'
    CSV.foreach(zones_csv) do |row|
      return row[6].to_s if row[0].to_s == wmo.to_s
    end

    return
  end
end
