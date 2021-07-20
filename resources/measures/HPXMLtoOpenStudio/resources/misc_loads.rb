# frozen_string_literal: true

require_relative 'constants'
require_relative 'unit_conversions'
require_relative 'schedules'

class MiscLoads
  def self.apply_plug(model, unit, runner, annual_energy, sens_frac, lat_frac, sch, schedules_file)
    # check for valid inputs
    if annual_energy < 0
      runner.registerError('Annual energy use must be greater than or equal to 0.')
      return false
    end
    if (sens_frac < 0) || (sens_frac > 1)
      runner.registerError('Sensible fraction must be greater than or equal to 0 and less than or equal to 1.')
      return false
    end
    if (lat_frac < 0) || (lat_frac > 1)
      runner.registerError('Latent fraction must be greater than or equal to 0 and less than or equal to 1.')
      return false
    end
    if lat_frac + sens_frac > 1
      runner.registerError('Sum of sensible and latent fractions must be less than or equal to 1.')
      return false
    end

    # Get unit ffa
    ffa = Geometry.get_finished_floor_area_from_spaces(unit.spaces, runner)
    if ffa.nil?
      return false
    end

    col_name = 'plug_loads'
    unit.spaces.each do |space|
      next if Geometry.space_is_unfinished(space)

      obj_name = Constants.ObjectNameMiscPlugLoads(unit.name.to_s)
      space_obj_name = "#{obj_name}|#{space.name}"

      # Remove any existing mels
      objects_to_remove = []
      space.electricEquipment.each do |space_equipment|
        next if space_equipment.name.to_s != space_obj_name

        objects_to_remove << space_equipment
        objects_to_remove << space_equipment.electricEquipmentDefinition
        if space_equipment.schedule.is_initialized
          objects_to_remove << space_equipment.schedule.get
        end
      end
      if objects_to_remove.size > 0
        runner.registerInfo("Removed existing plug loads from space '#{space.name}'.")
      end
      objects_to_remove.uniq.each do |object|
        begin
          object.remove
        rescue
          # no op
        end
      end

      next unless annual_energy > 0

      if sch.nil?
        # Create schedule
        sch = schedules_file.create_schedule_file(col_name: col_name)
      end

      space_mel_ann = annual_energy * UnitConversions.convert(space.floorArea, 'm^2', 'ft^2') / ffa
      space_design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: space_mel_ann)

      # Add electric equipment for the mel
      mel_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      mel = OpenStudio::Model::ElectricEquipment.new(mel_def)
      mel.setName(space_obj_name)
      mel.setEndUseSubcategory(obj_name)
      mel.setSpace(space)
      mel_def.setName(space_obj_name)
      mel_def.setDesignLevel(space_design_level)
      mel_def.setFractionRadiant(0.6 * sens_frac)
      mel_def.setFractionLatent(lat_frac)
      mel_def.setFractionLost(1 - sens_frac - lat_frac)
      mel.setSchedule(sch)
    end

    return true, sch
  end

  def self.apply_electric(model, unit, runner, annual_energy, mult,
                          weekday_sch, weekend_sch, monthly_sch, sch, space,
                          unit_obj_name, scale_energy, schedules_file)

    # check for valid inputs
    if annual_energy < 0
      runner.registerError('Annual energy must be greater than or equal to 0.')
      return false
    end
    if mult < 0
      runner.registerError('Energy multiplier must be greater than or equal to 0.')
      return false
    end

    # Calculate annual energy use
    ann_e = annual_energy * mult # kWh/yr

    if scale_energy
      # Get unit beds/baths/occupants
      nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
      if nbeds.nil? || nbaths.nil?
        return false
      end

      noccupants = Geometry.get_unit_occupants(model, unit, runner)

      # Get unit ffa
      ffa = Geometry.get_finished_floor_area_from_spaces(unit.spaces, runner)
      if ffa.nil?
        return false
      end

      # Scale energy use by num beds and floor area
      constant = 1.0 / 2
      nbr_coef = 1.0 / 4 / 3
      ffa_coef = 1.0 / 4 / 1920
      if [Constants.BuildingTypeMultifamily, Constants.BuildingTypeSingleFamilyAttached].include? Geometry.get_building_type(model) # multifamily equation
        ann_e *= (constant + nbr_coef * (-0.68 + 1.09 * noccupants) + ffa_coef * ffa) # kWh/yr
      elsif [Constants.BuildingTypeSingleFamilyDetached].include? Geometry.get_building_type(model) # single-family equation
        ann_e *= (constant + nbr_coef * (-1.47 + 1.69 * noccupants) + ffa_coef * ffa) # kWh/yr
      end
    end

    # Design day schedules used when autosizing
    winter_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    winter_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    summer_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    summer_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

    year_description = model.getYearDescription
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)

    if ann_e > 0

      if sch.nil?
        # Create schedule
        if unit_obj_name.include? Constants.ObjectNameElectricVehicle
          col_name = 'plug_loads_vehicle'
        elsif unit_obj_name.include? Constants.ObjectNameWellPump
          col_name = 'plug_loads_well_pump'
        else
          sch = MonthWeekdayWeekendSchedule.new(model, runner, unit_obj_name + ' schedule', weekday_sch, weekend_sch, monthly_sch, mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = true, create_sch_object = true, winter_design_day_sch, summer_design_day_sch)
          if not sch.validated?
            return false
          end
        end
      end

      if schedules_file.nil?
        design_level = sch.calcDesignLevelFromDailykWh(ann_e / num_days_in_year)
        schedule = sch.schedule
      else
        design_level = schedules_file.calc_design_level_from_daily_kwh(col_name: col_name, daily_kwh: ann_e / num_days_in_year)
        schedule = schedules_file.create_schedule_file(col_name: col_name)
      end

      # Add electric equipment for the load
      load_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      load = OpenStudio::Model::ElectricEquipment.new(load_def)
      load.setName(unit_obj_name)
      load.setEndUseSubcategory(unit_obj_name)
      if space.nil?
        # Use arbitrary space with FractionLost=1
        unit.spaces.each do |space|
          next unless Geometry.is_living(space)

          load.setSpace(space)
        end
        load_def.setFractionLost(1)
      else
        load.setSpace(space)
        load_def.setFractionLost(0)
      end
      load_def.setFractionRadiant(0)
      load_def.setFractionLatent(0)
      load_def.setName(unit_obj_name)
      load_def.setDesignLevel(design_level)
      load.setSchedule(schedule)

    end

    return true, ann_e, sch
  end

  def self.apply_gas(model, unit, runner, annual_energy, mult,
                     weekday_sch, weekend_sch, monthly_sch, sch, space,
                     unit_obj_name, scale_energy, schedules_file)

    # check for valid inputs
    if annual_energy < 0
      runner.registerError('Annual energy must be greater than or equal to 0.')
      return false
    end
    if mult < 0
      runner.registerError('Energy multiplier must be greater than or equal to 0.')
      return false
    end

    # Calculate annual energy use
    ann_g = annual_energy * mult # therm/yr

    if scale_energy
      # Get unit beds/baths/occupants
      nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
      if nbeds.nil? || nbaths.nil?
        return false
      end

      noccupants = Geometry.get_unit_occupants(model, unit, runner)

      # Get unit ffa
      ffa = Geometry.get_finished_floor_area_from_spaces(unit.spaces, runner)
      if ffa.nil?
        return false
      end

      # Scale energy use by num beds and floor area
      constant = 1.0 / 2
      nbr_coef = 1.0 / 4 / 3
      ffa_coef = 1.0 / 4 / 1920
      if [Constants.BuildingTypeMultifamily, Constants.BuildingTypeSingleFamilyAttached].include? Geometry.get_building_type(model) # multifamily equation
        ann_g *= (constant + nbr_coef * (-0.68 + 1.09 * noccupants) + ffa_coef * ffa) # therm/yr
      elsif [Constants.BuildingTypeSingleFamilyDetached].include? Geometry.get_building_type(model) # single-family equation
        ann_g *= (constant + nbr_coef * (-1.47 + 1.69 * noccupants) + ffa_coef * ffa) # therm/yr
      end
    end

    # Design day schedules used when autosizing
    winter_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    winter_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    summer_design_day_sch = OpenStudio::Model::ScheduleDay.new(model)
    summer_design_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

    year_description = model.getYearDescription
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)

    if ann_g > 0

      if sch.nil?
        # Create schedule
        if unit_obj_name.include? Constants.ObjectNameGasGrill
          col_name = 'fuel_loads_grill'
        elsif unit_obj_name.include? Constants.ObjectNameGasLighting
          col_name = 'fuel_loads_lighting'
        elsif unit_obj_name.include? Constants.ObjectNameGasFireplace
          col_name = 'fuel_loads_fireplace'
        else
          sch = MonthWeekdayWeekendSchedule.new(model, runner, unit_obj_name + ' schedule', weekday_sch, weekend_sch, monthly_sch, mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = true, create_sch_object = true, winter_design_day_sch, summer_design_day_sch)
          if not sch.validated?
            return false
          end
        end
      end

      if schedules_file.nil?
        design_level = sch.calcDesignLevelFromDailyTherm(ann_g / num_days_in_year)
        schedule = sch.schedule
      else
        design_level = schedules_file.calc_design_level_from_daily_therm(col_name: col_name, daily_therm: ann_g / num_days_in_year)
        schedule = schedules_file.create_schedule_file(col_name: col_name)
      end

      # Add gas equipment for the load
      load_def = OpenStudio::Model::GasEquipmentDefinition.new(model)
      load = OpenStudio::Model::GasEquipment.new(load_def)
      load.setName(unit_obj_name)
      load.setEndUseSubcategory(unit_obj_name)
      if space.nil?
        # Use arbitrary space with FractionLost=1
        unit.spaces.each do |space|
          next unless Geometry.is_living(space)

          load.setSpace(space)
        end
        load_def.setFractionLost(1)
      else
        load.setSpace(space)
        load_def.setFractionLost(0)
      end
      load_def.setFractionRadiant(0)
      load_def.setFractionLatent(0)
      load_def.setName(unit_obj_name)
      load_def.setDesignLevel(design_level)
      load.setSchedule(schedule)

    end

    return true, ann_g, sch
  end

  def self.remove(runner, space, obj_names)
    # Remove any existing large, uncommon loads
    objects_to_remove = []
    space.electricEquipment.each do |space_equipment|
      found = false
      obj_names.each do |obj_name|
        next if not space_equipment.name.to_s.start_with? obj_name

        found = true
      end
      next if not found

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.electricEquipmentDefinition
      if space_equipment.schedule.is_initialized
        objects_to_remove << space_equipment.schedule.get
      end
    end
    space.gasEquipment.each do |space_equipment|
      found = false
      obj_names.each do |obj_name|
        next if not space_equipment.name.to_s.start_with? obj_name

        found = true
      end
      next if not found

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.gasEquipmentDefinition
      if space_equipment.schedule.is_initialized
        objects_to_remove << space_equipment.schedule.get
      end
    end
    if objects_to_remove.size > 0
      runner.registerInfo("Removed existing large, uncommon loads from space '#{space.name}'.")
    end
    objects_to_remove.uniq.each do |object|
      begin
        object.remove
      rescue
        # no op
      end
    end
  end

  def self.apply_tv(model, unit, runner, annual_energy, sch, space)
    year_description = model.getYearDescription
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)

    name = Constants.ObjectNameMiscTelevision(unit.name.to_s)
    design_level = sch.calcDesignLevelFromDailykWh(annual_energy / num_days_in_year)
    sens_frac = 1.0
    lat_frac = 0.0

    # Add electric equipment for the mel
    mel_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    mel = OpenStudio::Model::ElectricEquipment.new(mel_def)
    mel.setName(name)
    mel.setEndUseSubcategory(name)
    mel.setSpace(space)
    mel_def.setName(name)
    mel_def.setDesignLevel(design_level)
    mel_def.setFractionRadiant(0.6 * sens_frac)
    mel_def.setFractionLatent(lat_frac)
    mel_def.setFractionLost(1 - sens_frac - lat_frac)
    mel.setSchedule(sch.schedule)

    return true
  end
end
