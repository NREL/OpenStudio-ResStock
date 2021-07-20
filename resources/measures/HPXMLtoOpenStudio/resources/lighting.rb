# frozen_string_literal: true

require_relative 'schedules'
require_relative 'geometry'
require_relative 'unit_conversions'

class Lighting
  def self.apply_interior(model, unit, runner, weather, sch, interior_ann, schedules_file)
    # Get unit ffa and finished spaces
    unit_finished_spaces = Geometry.get_finished_spaces(unit.spaces)
    ffa = Geometry.get_finished_floor_area_from_spaces(unit.spaces, runner)
    if ffa.nil?
      return false
    end

    # Finished spaces for the unit
    unit_finished_spaces.each do |space|
      space_obj_name = "#{Constants.ObjectNameLightingInterior(unit.name.to_s)} #{space.name}"

      col_name = 'lighting_interior'
      if sch.nil?
        # Create schedule
        sch = schedules_file.create_schedule_file(col_name: col_name)
      end

      if unit_finished_spaces.include?(space)
        space_ltg_ann = interior_ann * UnitConversions.convert(space.floorArea, 'm^2', 'ft^2') / ffa
      end
      space_design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: space_ltg_ann)

      # Add lighting
      ltg_def = OpenStudio::Model::LightsDefinition.new(model)
      ltg = OpenStudio::Model::Lights.new(ltg_def)
      ltg.setName(space_obj_name)
      ltg.setSpace(space)
      ltg_def.setName(space_obj_name)
      ltg_def.setLightingLevel(space_design_level)
      ltg_def.setFractionRadiant(0.6)
      ltg_def.setFractionVisible(0.2)
      ltg_def.setReturnAirFraction(0.0)
      ltg.setSchedule(sch)
      ltg.setEndUseSubcategory(space_obj_name)
    end

    return true, sch
  end

  def self.apply_garage(model, runner, weather, garage_ann, schedules_file)
    sch = nil
    garage_spaces = Geometry.get_garage_spaces(model.getSpaces)
    gfa = Geometry.get_floor_area_from_spaces(garage_spaces)
    garage_spaces.each do |garage_space|
      space_obj_name = "#{Constants.ObjectNameLightingGarage} #{garage_space.name}"
      space_ltg_ann = garage_ann * UnitConversions.convert(garage_space.floorArea, 'm^2', 'ft^2') / gfa

      col_name = 'lighting_garage'
      if sch.nil?
        # Create schedule
        sch = schedules_file.create_schedule_file(col_name: col_name)
      end

      space_design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: space_ltg_ann)

      # Add lighting
      ltg_def = OpenStudio::Model::LightsDefinition.new(model)
      ltg = OpenStudio::Model::Lights.new(ltg_def)
      ltg.setName(space_obj_name)
      ltg.setSpace(garage_space)
      ltg_def.setName(space_obj_name)
      ltg_def.setLightingLevel(space_design_level)
      ltg_def.setFractionRadiant(0.6)
      ltg_def.setFractionVisible(0.2)
      ltg_def.setReturnAirFraction(0.0)
      ltg.setSchedule(sch)
      ltg.setEndUseSubcategory(space_obj_name)
    end

    return true
  end

  def self.apply_exterior(model, runner, weather, exterior_ann, schedules_file)
    col_name = 'lighting_exterior'

    obj_name = Constants.ObjectNameLightingExterior

    # Create schedule
    sch = schedules_file.create_schedule_file(col_name: col_name)

    design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: exterior_ann)

    # Add exterior lighting
    ltg_def = OpenStudio::Model::ExteriorLightsDefinition.new(model)
    ltg = OpenStudio::Model::ExteriorLights.new(ltg_def)
    ltg.setName(obj_name)
    ltg_def.setName(obj_name)
    ltg_def.setDesignLevel(design_level)
    ltg.setSchedule(sch)
    ltg.setEndUseSubcategory(obj_name)

    return true
  end

  def self.apply_exterior_holiday(model, runner, exterior_ann, schedules_file)
    col_name = 'lighting_exterior_holiday'

    obj_name = Constants.ObjectNameLightingExteriorHoliday

    # Create schedule
    sch = schedules_file.create_schedule_file(col_name: col_name)

    design_level = schedules_file.calc_design_level_from_annual_kwh(col_name: col_name, annual_kwh: exterior_ann)

    # Add exterior lighting
    ltg_def = OpenStudio::Model::ExteriorLightsDefinition.new(model)
    ltg = OpenStudio::Model::ExteriorLights.new(ltg_def)
    ltg.setName(obj_name)
    ltg_def.setName(obj_name)
    ltg_def.setDesignLevel(design_level)
    ltg.setSchedule(sch)
    ltg.setEndUseSubcategory(obj_name)

    return true
  end

  def self.remove_interior(model, runner)
    objects_to_remove = []
    model.getLightss.each do |light|
      next unless Geometry.space_is_finished(light.space.get)

      objects_to_remove << light
      objects_to_remove << light.lightsDefinition
      if light.schedule.is_initialized
        objects_to_remove << light.schedule.get
      end
    end
    if objects_to_remove.size > 0
      runner.registerInfo('Removed existing interior lighting from the model.')
    end
    objects_to_remove.uniq.each do |object|
      begin
        object.remove
      rescue
        # no op
      end
    end
  end

  def self.remove_other(model, runner)
    objects_to_remove = []
    model.getExteriorLightss.each do |exterior_light|
      objects_to_remove << exterior_light
      objects_to_remove << exterior_light.exteriorLightsDefinition
      if exterior_light.schedule.is_initialized
        objects_to_remove << exterior_light.schedule.get
      end
    end
    model.getLightss.each do |light|
      next if Geometry.space_is_finished(light.space.get)

      objects_to_remove << light
      objects_to_remove << light.lightsDefinition
      if light.schedule.is_initialized
        objects_to_remove << light.schedule.get
      end
    end
    if objects_to_remove.size > 0
      runner.registerInfo('Removed existing garage/exterior lighting from the model.')
    end
    objects_to_remove.uniq.each do |object|
      begin
        object.remove
      rescue
        # no op
      end
    end
  end

  def self.get_reference_fractions()
    fFI_int = 0.10
    fFI_ext = 0.0
    fFI_grg = 0.0
    fFII_int = 0.0
    fFII_ext = 0.0
    fFII_grg = 0.0
    return fFI_int, fFI_ext, fFI_grg, fFII_int, fFII_ext, fFII_grg
  end

  def self.get_iad_fractions()
    fFI_int = 0.75
    fFI_ext = 0.75
    fFI_grg = 0.75
    fFII_int = 0.0
    fFII_ext = 0.0
    fFII_grg = 0.0
    return fFI_int, fFI_ext, fFI_grg, fFII_int, fFII_ext, fFII_grg
  end

  def self.calc_lighting_energy(eri_version, cfa, garage_present, fFI_int, fFI_ext, fFI_grg, fFII_int, fFII_ext, fFII_grg)
    if eri_version.include? 'G'
      # ANSI/RESNET/ICC 301-2014 Addendum G-2018, Solid State Lighting
      int_kwh = 0.9 / 0.925 * (455.0 + 0.8 * cfa) * ((1.0 - fFII_int - fFI_int) + fFI_int * 15.0 / 60.0 + fFII_int * 15.0 / 90.0) + 0.1 * (455.0 + 0.8 * cfa) # Eq 4.2-2)
      ext_kwh = (100.0 + 0.05 * cfa) * (1.0 - fFI_ext - fFII_ext) + 15.0 / 60.0 * (100.0 + 0.05 * cfa) * fFI_ext + 15.0 / 90.0 * (100.0 + 0.05 * cfa) * fFII_ext # Eq 4.2-3
      grg_kwh = 0.0
      if garage_present
        grg_kwh = 100.0 * ((1.0 - fFI_grg - fFII_grg) + 15.0 / 60.0 * fFI_grg + 15.0 / 90.0 * fFII_grg) # Eq 4.2-4
      end
    else
      int_kwh = 0.8 * ((4.0 - 3.0 * (fFI_int + fFII_int)) / 3.7) * (455.0 + 0.8 * cfa) + 0.2 * (455.0 + 0.8 * cfa) # Eq 4.2-2
      ext_kwh = (100.0 + 0.05 * cfa) * (1.0 - (fFI_ext + fFII_ext)) + 0.25 * (100.0 + 0.05 * cfa) * (fFI_ext + fFII_ext) # Eq 4.2-3
      grg_kwh = 0.0
      if garage_present
        grg_kwh = 100.0 * (1.0 - (fFI_grg + fFII_grg)) + 25.0 * (fFI_grg + fFII_grg) # Eq 4.2-4
      end
    end
    return int_kwh, ext_kwh, grg_kwh
  end
end
