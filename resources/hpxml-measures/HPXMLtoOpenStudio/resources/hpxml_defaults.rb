# frozen_string_literal: true

class HPXMLDefaults
  # Note: Each HPXML object (e.g., HPXML::Wall) has an additional_properties
  # child object where # custom information can be attached to the object without
  # being written to the HPXML file. This is useful to associate additional values
  # with the HPXML objects that will ultimately get passed around.

  def self.apply(hpxml, eri_version, weather, epw_file: nil, convert_shared_systems: true)
    cfa = hpxml.building_construction.conditioned_floor_area
    nbeds = hpxml.building_construction.number_of_bedrooms
    ncfl = hpxml.building_construction.number_of_conditioned_floors
    ncfl_ag = hpxml.building_construction.number_of_conditioned_floors_above_grade
    has_uncond_bsmnt = hpxml.has_space_type(HPXML::LocationBasementUnconditioned)

    apply_header(hpxml, epw_file)
    apply_site(hpxml)
    apply_neighbor_buildings(hpxml)
    apply_building_occupancy(hpxml, nbeds)
    apply_building_construction(hpxml, cfa, nbeds)
    apply_infiltration(hpxml)
    apply_attics(hpxml)
    apply_foundations(hpxml)
    apply_roofs(hpxml)
    apply_rim_joists(hpxml)
    apply_walls(hpxml)
    apply_foundation_walls(hpxml)
    apply_frame_floors(hpxml)
    apply_slabs(hpxml)
    apply_windows(hpxml)
    apply_skylights(hpxml)
    apply_doors(hpxml)
    apply_hvac(hpxml, weather, convert_shared_systems)
    apply_hvac_control(hpxml)
    apply_hvac_distribution(hpxml, ncfl, ncfl_ag)
    apply_ventilation_fans(hpxml)
    apply_water_heaters(hpxml, nbeds, eri_version)
    apply_hot_water_distribution(hpxml, cfa, ncfl, has_uncond_bsmnt)
    apply_water_fixtures(hpxml)
    apply_solar_thermal_systems(hpxml)
    apply_appliances(hpxml, nbeds, eri_version)
    apply_lighting(hpxml)
    apply_ceiling_fans(hpxml, nbeds)
    apply_pools_and_hot_tubs(hpxml, cfa, nbeds)
    apply_plug_loads(hpxml, cfa, nbeds)
    apply_fuel_loads(hpxml, cfa, nbeds)
    apply_pv_systems(hpxml)
    apply_generators(hpxml)

    # Do HVAC sizing after all other defaults have been applied
    apply_hvac_sizing(hpxml, weather, cfa, nbeds)
  end

  def self.get_default_azimuths(hpxml)
    def self.sanitize_azimuth(azimuth)
      # Ensure 0 <= orientation < 360
      while azimuth < 0
        azimuth += 360
      end
      while azimuth >= 360
        azimuth -= 360
      end
      return azimuth
    end

    # Returns a list of four azimuths (facing each direction). Determined based
    # on the primary azimuth, as defined by the azimuth with the largest surface
    # area, plus azimuths that are offset by 90/180/270 degrees. Used for
    # surfaces that may not have an azimuth defined (e.g., walls).
    azimuth_areas = {}
    (hpxml.roofs + hpxml.rim_joists + hpxml.walls + hpxml.foundation_walls +
     hpxml.windows + hpxml.skylights + hpxml.doors).each do |surface|
      az = surface.azimuth
      next if az.nil?

      azimuth_areas[az] = 0 if azimuth_areas[az].nil?
      azimuth_areas[az] += surface.area
    end
    if azimuth_areas.empty?
      primary_azimuth = 0
    else
      primary_azimuth = azimuth_areas.max_by { |k, v| v }[0]
    end
    return [primary_azimuth,
            sanitize_azimuth(primary_azimuth + 90),
            sanitize_azimuth(primary_azimuth + 180),
            sanitize_azimuth(primary_azimuth + 270)].sort
  end

  private

  def self.apply_header(hpxml, epw_file)
    if hpxml.header.timestep.nil?
      hpxml.header.timestep = 60
      hpxml.header.timestep_isdefaulted = true
    end

    if hpxml.header.sim_begin_month.nil?
      hpxml.header.sim_begin_month = 1
      hpxml.header.sim_begin_month_isdefaulted = true
    end
    if hpxml.header.sim_begin_day.nil?
      hpxml.header.sim_begin_day = 1
      hpxml.header.sim_begin_day_isdefaulted = true
    end
    if hpxml.header.sim_end_month.nil?
      hpxml.header.sim_end_month = 12
      hpxml.header.sim_end_month_isdefaulted = true
    end
    if hpxml.header.sim_end_day.nil?
      hpxml.header.sim_end_day = 31
      hpxml.header.sim_end_day_isdefaulted = true
    end

    if (not epw_file.nil?) && epw_file.startDateActualYear.is_initialized # AMY
      if not hpxml.header.sim_calendar_year.nil?
        if hpxml.header.sim_calendar_year != epw_file.startDateActualYear.get
          hpxml.header.sim_calendar_year = epw_file.startDateActualYear.get
          hpxml.header.sim_calendar_year_isdefaulted = true
        end
      else
        hpxml.header.sim_calendar_year = epw_file.startDateActualYear.get
        hpxml.header.sim_calendar_year_isdefaulted = true
      end
    else
      if hpxml.header.sim_calendar_year.nil?
        hpxml.header.sim_calendar_year = 2007 # For consistency with SAM utility bill calculations
        hpxml.header.sim_calendar_year_isdefaulted = true
      end
    end

    if hpxml.header.dst_enabled.nil?
      hpxml.header.dst_enabled = true # Assume DST since it occurs in most US locations
      hpxml.header.dst_enabled_isdefaulted = true
    end

    if hpxml.header.dst_enabled && (not epw_file.nil?)
      if hpxml.header.dst_begin_month.nil? || hpxml.header.dst_begin_day.nil? || hpxml.header.dst_end_month.nil? || hpxml.header.dst_end_day.nil?
        if epw_file.daylightSavingStartDate.is_initialized && epw_file.daylightSavingEndDate.is_initialized
          # Use weather file DST dates if available
          dst_start_date = epw_file.daylightSavingStartDate.get
          dst_end_date = epw_file.daylightSavingEndDate.get
          hpxml.header.dst_begin_month = dst_start_date.monthOfYear.value
          hpxml.header.dst_begin_day = dst_start_date.dayOfMonth
          hpxml.header.dst_end_month = dst_end_date.monthOfYear.value
          hpxml.header.dst_end_day = dst_end_date.dayOfMonth
        else
          # Roughly average US dates according to https://en.wikipedia.org/wiki/Daylight_saving_time_in_the_United_States
          hpxml.header.dst_begin_month = 3
          hpxml.header.dst_begin_day = 12
          hpxml.header.dst_end_month = 11
          hpxml.header.dst_end_day = 5
        end
        hpxml.header.dst_begin_month_isdefaulted = true
        hpxml.header.dst_begin_day_isdefaulted = true
        hpxml.header.dst_end_month_isdefaulted = true
        hpxml.header.dst_end_day_isdefaulted = true
      end
    end

    if hpxml.header.allow_increased_fixed_capacities.nil?
      hpxml.header.allow_increased_fixed_capacities = false
      hpxml.header.allow_increased_fixed_capacities_isdefaulted = true
    end
    if hpxml.header.use_max_load_for_heat_pumps.nil?
      hpxml.header.use_max_load_for_heat_pumps = true
      hpxml.header.use_max_load_for_heat_pumps_isdefaulted = true
    end
  end

  def self.apply_site(hpxml)
    if hpxml.site.site_type.nil?
      hpxml.site.site_type = HPXML::SiteTypeSuburban
      hpxml.site.site_type_isdefaulted = true
    end

    if hpxml.site.shielding_of_home.nil?
      hpxml.site.shielding_of_home = HPXML::ShieldingNormal
      hpxml.site.shielding_of_home_isdefaulted = true
    end
    hpxml.site.additional_properties.aim2_shelter_coeff = Airflow.get_aim2_shelter_coefficient(hpxml.site.shielding_of_home)
  end

  def self.apply_neighbor_buildings(hpxml)
    hpxml.neighbor_buildings.each do |neighbor_building|
      if neighbor_building.azimuth.nil?
        neighbor_building.azimuth = get_azimuth_from_orientation(neighbor_building.orientation)
        neighbor_building.azimuth_isdefaulted = true
      end
      if neighbor_building.orientation.nil?
        neighbor_building.orientation = get_orientation_from_azimuth(neighbor_building.azimuth)
        neighbor_building.orientation_isdefaulted = true
      end
    end
  end

  def self.apply_building_occupancy(hpxml, nbeds)
    if hpxml.building_occupancy.number_of_residents.nil?
      hpxml.building_occupancy.number_of_residents = Geometry.get_occupancy_default_num(nbeds)
      hpxml.building_occupancy.number_of_residents_isdefaulted = true
    end
  end

  def self.apply_building_construction(hpxml, cfa, nbeds)
    if hpxml.building_construction.conditioned_building_volume.nil? && hpxml.building_construction.average_ceiling_height.nil?
      hpxml.building_construction.average_ceiling_height = 8.0
      hpxml.building_construction.average_ceiling_height_isdefaulted = true
      hpxml.building_construction.conditioned_building_volume = cfa * hpxml.building_construction.average_ceiling_height
      hpxml.building_construction.conditioned_building_volume_isdefaulted = true
    elsif hpxml.building_construction.conditioned_building_volume.nil?
      hpxml.building_construction.conditioned_building_volume = cfa * hpxml.building_construction.average_ceiling_height
      hpxml.building_construction.conditioned_building_volume_isdefaulted = true
    elsif hpxml.building_construction.average_ceiling_height.nil?
      hpxml.building_construction.average_ceiling_height = hpxml.building_construction.conditioned_building_volume / cfa
      hpxml.building_construction.average_ceiling_height_isdefaulted = true
    end

    if hpxml.building_construction.number_of_bathrooms.nil?
      hpxml.building_construction.number_of_bathrooms = Float(Waterheater.get_default_num_bathrooms(nbeds)).to_i
      hpxml.building_construction.number_of_bathrooms_isdefaulted = true
    end

    if hpxml.building_construction.has_flue_or_chimney.nil?
      hpxml.building_construction.has_flue_or_chimney = false
      hpxml.building_construction.has_flue_or_chimney_isdefaulted = true
      hpxml.heating_systems.each do |heating_system|
        if [HPXML::HVACTypeFurnace, HPXML::HVACTypeBoiler, HPXML::HVACTypeWallFurnace, HPXML::HVACTypeFloorFurnace, HPXML::HVACTypeStove, HPXML::HVACTypeFixedHeater].include? heating_system.heating_system_type
          if not heating_system.heating_efficiency_afue.nil?
            next if heating_system.heating_efficiency_afue >= 0.89
          elsif not heating_system.heating_efficiency_percent.nil?
            next if heating_system.heating_efficiency_percent >= 0.89
          end

          hpxml.building_construction.has_flue_or_chimney = true
        elsif [HPXML::HVACTypeFireplace].include? heating_system.heating_system_type
          next if heating_system.heating_system_fuel == HPXML::FuelTypeElectricity

          hpxml.building_construction.has_flue_or_chimney = true
        end
      end
      hpxml.water_heating_systems.each do |water_heating_system|
        if not water_heating_system.energy_factor.nil?
          next if water_heating_system.energy_factor >= 0.63
        elsif not water_heating_system.uniform_energy_factor.nil?
          next if Waterheater.calc_ef_from_uef(water_heating_system) >= 0.63
        end

        hpxml.building_construction.has_flue_or_chimney = true
      end
    end
  end

  def self.apply_infiltration(hpxml)
    measurements = []
    infil_volume = nil
    hpxml.air_infiltration_measurements.each do |measurement|
      is_ach = ((measurement.unit_of_measure == HPXML::UnitsACH) && !measurement.house_pressure.nil?)
      is_cfm = ((measurement.unit_of_measure == HPXML::UnitsCFM) && !measurement.house_pressure.nil?)
      is_nach = (measurement.unit_of_measure == HPXML::UnitsACHNatural)
      next unless (is_ach || is_cfm || is_nach)

      measurements << measurement
      next if measurement.infiltration_volume.nil?

      infil_volume = measurement.infiltration_volume
    end
    if infil_volume.nil?
      infil_volume = hpxml.building_construction.conditioned_building_volume
      measurements.each do |measurement|
        measurement.infiltration_volume = infil_volume
        measurement.infiltration_volume_isdefaulted = true
      end
    end

    return infil_volume
  end

  def self.apply_attics(hpxml)
    return unless hpxml.has_space_type(HPXML::LocationAtticVented)

    vented_attics = []
    default_sla = Airflow.get_default_vented_attic_sla()
    default_ach = nil
    hpxml.attics.each do |attic|
      next unless attic.attic_type == HPXML::AtticTypeVented

      # check existing sla and ach
      default_sla = attic.vented_attic_sla unless attic.vented_attic_sla.nil?
      default_ach = attic.vented_attic_ach unless attic.vented_attic_ach.nil?

      vented_attics << attic
    end
    if vented_attics.empty?
      hpxml.attics.add(id: 'VentedAttic',
                       attic_type: HPXML::AtticTypeVented,
                       vented_attic_sla: default_sla)
      hpxml.attics[-1].vented_attic_sla_isdefaulted = true
    end
    vented_attics.each do |vented_attic|
      next unless (vented_attic.vented_attic_sla.nil? && vented_attic.vented_attic_ach.nil?)

      if not default_ach.nil? # ACH specified
        vented_attic.vented_attic_ach = default_ach
      else # Use SLA
        vented_attic.vented_attic_sla = default_sla
      end
      vented_attic.vented_attic_sla_isdefaulted = true
    end
  end

  def self.apply_foundations(hpxml)
    return unless hpxml.has_space_type(HPXML::LocationCrawlspaceVented)

    vented_crawls = []
    default_sla = Airflow.get_default_vented_crawl_sla()
    hpxml.foundations.each do |foundation|
      next unless foundation.foundation_type == HPXML::FoundationTypeCrawlspaceVented

      # check existing sla
      default_sla = foundation.vented_crawlspace_sla unless foundation.vented_crawlspace_sla.nil?

      vented_crawls << foundation
    end
    if vented_crawls.empty?
      hpxml.foundations.add(id: 'VentedCrawlspace',
                            foundation_type: HPXML::FoundationTypeCrawlspaceVented,
                            vented_crawlspace_sla: default_sla)
      hpxml.foundations[-1].vented_crawlspace_sla_isdefaulted = true
    end
    vented_crawls.each do |vented_crawl|
      next unless vented_crawl.vented_crawlspace_sla.nil?

      vented_crawl.vented_crawlspace_sla = default_sla
      vented_crawl.vented_crawlspace_sla_isdefaulted = true
    end
  end

  def self.apply_roofs(hpxml)
    hpxml.roofs.each do |roof|
      if roof.azimuth.nil?
        roof.azimuth = get_azimuth_from_orientation(roof.orientation)
        roof.azimuth_isdefaulted = true
      end
      if roof.orientation.nil?
        roof.orientation = get_orientation_from_azimuth(roof.azimuth)
        roof.orientation_isdefaulted = true
      end
      if roof.roof_type.nil?
        roof.roof_type = HPXML::RoofTypeAsphaltShingles
        roof.roof_type_isdefaulted = true
      end
      if roof.emittance.nil?
        roof.emittance = 0.90
        roof.emittance_isdefaulted = true
      end
      if roof.radiant_barrier.nil?
        roof.radiant_barrier = false
        roof.radiant_barrier_isdefaulted = true
      end
      if roof.radiant_barrier && roof.radiant_barrier_grade.nil?
        roof.radiant_barrier_grade = 1
        roof.radiant_barrier_grade_isdefaulted = true
      end
      if roof.roof_color.nil? && roof.solar_absorptance.nil?
        roof.roof_color = HPXML::ColorMedium
        roof.roof_color_isdefaulted = true
      end
      if roof.roof_color.nil?
        roof.roof_color = Constructions.get_default_roof_color(roof.roof_type, roof.solar_absorptance)
        roof.roof_color_isdefaulted = true
      elsif roof.solar_absorptance.nil?
        roof.solar_absorptance = Constructions.get_default_roof_solar_absorptance(roof.roof_type, roof.roof_color)
        roof.solar_absorptance_isdefaulted = true
      end
      if roof.interior_finish_type.nil?
        if [HPXML::LocationLivingSpace, HPXML::LocationBasementConditioned].include? roof.interior_adjacent_to
          roof.interior_finish_type = HPXML::InteriorFinishGypsumBoard
        else
          roof.interior_finish_type = HPXML::InteriorFinishNone
        end
        roof.interior_finish_type_isdefaulted = true
      end
      next unless roof.interior_finish_thickness.nil?

      if roof.interior_finish_type != HPXML::InteriorFinishNone
        roof.interior_finish_thickness = 0.5
        roof.interior_finish_thickness_isdefaulted = true
      end
    end
  end

  def self.apply_rim_joists(hpxml)
    hpxml.rim_joists.each do |rim_joist|
      if rim_joist.azimuth.nil?
        rim_joist.azimuth = get_azimuth_from_orientation(rim_joist.orientation)
        rim_joist.azimuth_isdefaulted = true
      end
      if rim_joist.orientation.nil?
        rim_joist.orientation = get_orientation_from_azimuth(rim_joist.azimuth)
        rim_joist.orientation_isdefaulted = true
      end

      next unless rim_joist.is_exterior

      if rim_joist.emittance.nil?
        rim_joist.emittance = 0.90
        rim_joist.emittance_isdefaulted = true
      end
      if rim_joist.siding.nil?
        rim_joist.siding = HPXML::SidingTypeWood
        rim_joist.siding_isdefaulted = true
      end
      if rim_joist.color.nil? && rim_joist.solar_absorptance.nil?
        rim_joist.color = HPXML::ColorMedium
        rim_joist.color_isdefaulted = true
      end
      if rim_joist.color.nil?
        rim_joist.color = Constructions.get_default_wall_color(rim_joist.solar_absorptance)
        rim_joist.color_isdefaulted = true
      elsif rim_joist.solar_absorptance.nil?
        rim_joist.solar_absorptance = Constructions.get_default_wall_solar_absorptance(rim_joist.color)
        rim_joist.solar_absorptance_isdefaulted = true
      end
    end
  end

  def self.apply_walls(hpxml)
    hpxml.walls.each do |wall|
      if wall.azimuth.nil?
        wall.azimuth = get_azimuth_from_orientation(wall.orientation)
        wall.azimuth_isdefaulted = true
      end
      if wall.orientation.nil?
        wall.orientation = get_orientation_from_azimuth(wall.azimuth)
        wall.orientation_isdefaulted = true
      end

      if wall.is_exterior
        if wall.emittance.nil?
          wall.emittance = 0.90
          wall.emittance_isdefaulted = true
        end
        if wall.siding.nil?
          wall.siding = HPXML::SidingTypeWood
          wall.siding_isdefaulted = true
        end
        if wall.color.nil? && wall.solar_absorptance.nil?
          wall.color = HPXML::ColorMedium
          wall.color_isdefaulted = true
        end
        if wall.color.nil?
          wall.color = Constructions.get_default_wall_color(wall.solar_absorptance)
          wall.color_isdefaulted = true
        elsif wall.solar_absorptance.nil?
          wall.solar_absorptance = Constructions.get_default_wall_solar_absorptance(wall.color)
          wall.solar_absorptance_isdefaulted = true
        end
      end
      if wall.interior_finish_type.nil?
        if [HPXML::LocationLivingSpace, HPXML::LocationBasementConditioned].include? wall.interior_adjacent_to
          wall.interior_finish_type = HPXML::InteriorFinishGypsumBoard
        else
          wall.interior_finish_type = HPXML::InteriorFinishNone
        end
        wall.interior_finish_type_isdefaulted = true
      end
      next unless wall.interior_finish_thickness.nil?

      if wall.interior_finish_type != HPXML::InteriorFinishNone
        wall.interior_finish_thickness = 0.5
        wall.interior_finish_thickness_isdefaulted = true
      end
    end
  end

  def self.apply_foundation_walls(hpxml)
    hpxml.foundation_walls.each do |foundation_wall|
      if foundation_wall.azimuth.nil?
        foundation_wall.azimuth = get_azimuth_from_orientation(foundation_wall.orientation)
        foundation_wall.azimuth_isdefaulted = true
      end
      if foundation_wall.orientation.nil?
        foundation_wall.orientation = get_orientation_from_azimuth(foundation_wall.azimuth)
        foundation_wall.orientation_isdefaulted = true
      end
      if foundation_wall.thickness.nil?
        foundation_wall.thickness = 8.0
        foundation_wall.thickness_isdefaulted = true
      end
      if foundation_wall.area.nil?
        foundation_wall.area = foundation_wall.length * foundation_wall.height
        foundation_wall.area_isdefaulted = true
      end
      if foundation_wall.interior_finish_type.nil?
        if [HPXML::LocationLivingSpace, HPXML::LocationBasementConditioned].include? foundation_wall.interior_adjacent_to
          foundation_wall.interior_finish_type = HPXML::InteriorFinishGypsumBoard
        else
          foundation_wall.interior_finish_type = HPXML::InteriorFinishNone
        end
        foundation_wall.interior_finish_type_isdefaulted = true
      end
      if foundation_wall.insulation_interior_distance_to_top.nil?
        foundation_wall.insulation_interior_distance_to_top = 0.0
        foundation_wall.insulation_interior_distance_to_top_isdefaulted = true
      end
      if foundation_wall.insulation_interior_distance_to_bottom.nil?
        foundation_wall.insulation_interior_distance_to_bottom = foundation_wall.height
        foundation_wall.insulation_interior_distance_to_bottom_isdefaulted = true
      end
      if foundation_wall.insulation_exterior_distance_to_top.nil?
        foundation_wall.insulation_exterior_distance_to_top = 0.0
        foundation_wall.insulation_exterior_distance_to_top_isdefaulted = true
      end
      if foundation_wall.insulation_exterior_distance_to_bottom.nil?
        foundation_wall.insulation_exterior_distance_to_bottom = foundation_wall.height
        foundation_wall.insulation_exterior_distance_to_bottom_isdefaulted = true
      end
      next unless foundation_wall.interior_finish_thickness.nil?

      if foundation_wall.interior_finish_type != HPXML::InteriorFinishNone
        foundation_wall.interior_finish_thickness = 0.5
        foundation_wall.interior_finish_thickness_isdefaulted = true
      end
    end
  end

  def self.apply_frame_floors(hpxml)
    hpxml.frame_floors.each do |frame_floor|
      if frame_floor.interior_finish_type.nil?
        if frame_floor.is_floor
          frame_floor.interior_finish_type = HPXML::InteriorFinishNone
        elsif [HPXML::LocationLivingSpace, HPXML::LocationBasementConditioned].include? frame_floor.interior_adjacent_to
          frame_floor.interior_finish_type = HPXML::InteriorFinishGypsumBoard
        else
          frame_floor.interior_finish_type = HPXML::InteriorFinishNone
        end
        frame_floor.interior_finish_type_isdefaulted = true
      end
      next unless frame_floor.interior_finish_thickness.nil?

      if frame_floor.interior_finish_type != HPXML::InteriorFinishNone
        frame_floor.interior_finish_thickness = 0.5
        frame_floor.interior_finish_thickness_isdefaulted = true
      end
    end
  end

  def self.apply_slabs(hpxml)
    hpxml.slabs.each do |slab|
      if slab.thickness.nil?
        crawl_slab = [HPXML::LocationCrawlspaceVented, HPXML::LocationCrawlspaceUnvented].include?(slab.interior_adjacent_to)
        slab.thickness = crawl_slab ? 0.0 : 4.0
        slab.thickness_isdefaulted = true
      end
      conditioned_slab = [HPXML::LocationLivingSpace,
                          HPXML::LocationBasementConditioned].include?(slab.interior_adjacent_to)
      if slab.carpet_r_value.nil?
        slab.carpet_r_value = conditioned_slab ? 2.0 : 0.0
        slab.carpet_r_value_isdefaulted = true
      end
      if slab.carpet_fraction.nil?
        slab.carpet_fraction = conditioned_slab ? 0.8 : 0.0
        slab.carpet_fraction_isdefaulted = true
      end
    end
  end

  def self.apply_windows(hpxml)
    default_shade_summer, default_shade_winter = Constructions.get_default_interior_shading_factors()
    hpxml.windows.each do |window|
      if window.azimuth.nil?
        window.azimuth = get_azimuth_from_orientation(window.orientation)
        window.azimuth_isdefaulted = true
      end
      if window.orientation.nil?
        window.orientation = get_orientation_from_azimuth(window.azimuth)
        window.orientation_isdefaulted = true
      end
      if window.interior_shading_factor_summer.nil?
        window.interior_shading_factor_summer = default_shade_summer
        window.interior_shading_factor_summer_isdefaulted = true
      end
      if window.interior_shading_factor_winter.nil?
        window.interior_shading_factor_winter = default_shade_winter
        window.interior_shading_factor_winter_isdefaulted = true
      end
      if window.exterior_shading_factor_summer.nil?
        window.exterior_shading_factor_summer = 1.0
        window.exterior_shading_factor_summer_isdefaulted = true
      end
      if window.exterior_shading_factor_winter.nil?
        window.exterior_shading_factor_winter = 1.0
        window.exterior_shading_factor_winter_isdefaulted = true
      end
      if window.fraction_operable.nil?
        window.fraction_operable = Airflow.get_default_fraction_of_windows_operable()
        window.fraction_operable_isdefaulted = true
      end
    end
  end

  def self.apply_skylights(hpxml)
    hpxml.skylights.each do |skylight|
      if skylight.azimuth.nil?
        skylight.azimuth = get_azimuth_from_orientation(skylight.orientation)
        skylight.azimuth_isdefaulted = true
      end
      if skylight.orientation.nil?
        skylight.orientation = get_orientation_from_azimuth(skylight.azimuth)
        skylight.orientation_isdefaulted = true
      end
      if skylight.interior_shading_factor_summer.nil?
        skylight.interior_shading_factor_summer = 1.0
        skylight.interior_shading_factor_summer_isdefaulted = true
      end
      if skylight.interior_shading_factor_winter.nil?
        skylight.interior_shading_factor_winter = 1.0
        skylight.interior_shading_factor_winter_isdefaulted = true
      end
      if skylight.exterior_shading_factor_summer.nil?
        skylight.exterior_shading_factor_summer = 1.0
        skylight.exterior_shading_factor_summer_isdefaulted = true
      end
      if skylight.exterior_shading_factor_winter.nil?
        skylight.exterior_shading_factor_winter = 1.0
        skylight.exterior_shading_factor_winter_isdefaulted = true
      end
    end
  end

  def self.apply_doors(hpxml)
    hpxml.doors.each do |door|
      if door.azimuth.nil?
        door.azimuth = get_azimuth_from_orientation(door.orientation)
        door.azimuth_isdefaulted = true
      end
      if door.orientation.nil?
        door.orientation = get_orientation_from_azimuth(door.azimuth)
        door.orientation_isdefaulted = true
      end

      next unless door.azimuth.nil?

      if (not door.wall.nil?) && (not door.wall.azimuth.nil?)
        door.azimuth = door.wall.azimuth
      else
        primary_azimuth = get_default_azimuths(hpxml)[0]
        door.azimuth = primary_azimuth
        door.azimuth_isdefaulted = true
      end
    end
  end

  def self.apply_hvac(hpxml, weather, convert_shared_systems)
    if convert_shared_systems
      HVAC.apply_shared_systems(hpxml)
    end

    # HVAC efficiencies (based on HEScore assumption)
    hpxml.heating_systems.each do |heating_system|
      year_installed = heating_system.year_installed
      heating_system_type = heating_system.heating_system_type
      heating_system_fuel = heating_system.heating_system_fuel

      if [HPXML::HVACTypeBoiler, HPXML::HVACTypeFurnace, HPXML::HVACTypeWallFurnace, HPXML::HVACTypeFloorFurnace].include? heating_system_type
        next unless heating_system.heating_efficiency_afue.nil?

        if heating_system_fuel == HPXML::FuelTypeElectricity
          heating_system.heating_efficiency_afue = 0.98
        else
          heating_system.heating_efficiency_afue = HVAC.get_default_hvac_efficiency_by_year_installed(year_installed, heating_system_type, heating_system_fuel, HPXML::UnitsAFUE)
        end
        heating_system.heating_efficiency_afue_isdefaulted = true
      elsif [HPXML::HVACTypeElectricResistance].include? heating_system_type
        next unless heating_system.heating_efficiency_percent.nil?

        heating_system.heating_efficiency_percent = 1.0
        heating_system.heating_efficiency_percent_isdefaulted = true
      elsif [HPXML::HVACTypeStove, HPXML::HVACTypeFireplace, HPXML::HVACTypePortableHeater, HPXML::HVACTypeFixedHeater].include? heating_system_type
        next unless heating_system.heating_efficiency_percent.nil?

        if heating_system_fuel == HPXML::FuelTypeElectricity
          heating_system.heating_efficiency_percent = 1.0
        elsif heating_system_fuel == HPXML::FuelTypeWoodCord
          heating_system.heating_efficiency_percent = 0.60  # HEScore assumption
        elsif heating_system_fuel == HPXML::FuelTypeWoodPellets
          heating_system.heating_efficiency_percent = 0.78  # HEScore assumption
        else
          heating_system.heating_efficiency_percent = 0.81  # https://www.lopistoves.com/products/ and https://www.kozyheat.com/products/
        end
        heating_system.heating_efficiency_percent_isdefaulted = true
      end
    end

    hpxml.cooling_systems.each do |cooling_system|
      year_installed = cooling_system.year_installed
      cooling_system_type = cooling_system.cooling_system_type
      cooling_system_fuel = HPXML::FuelTypeElectricity

      if cooling_system_type == HPXML::HVACTypeCentralAirConditioner
        next unless cooling_system.cooling_efficiency_seer.nil?

        cooling_system.cooling_efficiency_seer = HVAC.get_default_hvac_efficiency_by_year_installed(year_installed, cooling_system_type, cooling_system_fuel, HPXML::UnitsSEER)
        cooling_system.cooling_efficiency_seer_isdefaulted = true
      elsif cooling_system_type == HPXML::HVACTypeRoomAirConditioner
        next unless cooling_system.cooling_efficiency_eer.nil? && cooling_system.cooling_efficiency_ceer.nil?

        cooling_system.cooling_efficiency_eer = HVAC.get_default_hvac_efficiency_by_year_installed(year_installed, cooling_system_type, cooling_system_fuel, HPXML::UnitsEER)
        cooling_system.cooling_efficiency_eer_isdefaulted = true
      end
    end

    hpxml.heat_pumps.each do |heat_pump|
      year_installed = heat_pump.year_installed
      heat_pump_type = heat_pump.heat_pump_type
      heat_pump_fuel = HPXML::FuelTypeElectricity

      next unless [HPXML::HVACTypeHeatPumpAirToAir].include? heat_pump_type

      if heat_pump.cooling_efficiency_seer.nil?
        heat_pump.cooling_efficiency_seer = HVAC.get_default_hvac_efficiency_by_year_installed(year_installed, heat_pump_type, heat_pump_fuel, HPXML::UnitsSEER)
        heat_pump.cooling_efficiency_seer_isdefaulted = true
      end
      if heat_pump.heating_efficiency_hspf.nil?
        heat_pump.heating_efficiency_hspf = HVAC.get_default_hvac_efficiency_by_year_installed(year_installed, heat_pump_type, heat_pump_fuel, HPXML::UnitsHSPF)
        heat_pump.heating_efficiency_hspf_isdefaulted = true
      end
    end

    # Default AC/HP compressor type
    hpxml.cooling_systems.each do |cooling_system|
      next unless cooling_system.compressor_type.nil?

      cooling_system.compressor_type = HVAC.get_default_compressor_type(cooling_system.cooling_system_type, cooling_system.cooling_efficiency_seer)
      cooling_system.compressor_type_isdefaulted = true
    end
    hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.compressor_type.nil?

      heat_pump.compressor_type = HVAC.get_default_compressor_type(heat_pump.heat_pump_type, heat_pump.cooling_efficiency_seer)
      heat_pump.compressor_type_isdefaulted = true
    end

    # Default boiler EAE
    hpxml.heating_systems.each do |heating_system|
      next unless heating_system.electric_auxiliary_energy.nil?

      heating_system.electric_auxiliary_energy_isdefaulted = true
      heating_system.electric_auxiliary_energy = HVAC.get_default_boiler_eae(heating_system)
      heating_system.shared_loop_watts = nil
      heating_system.shared_loop_motor_efficiency = nil
      heating_system.fan_coil_watts = nil
    end

    # Default AC/HP sensible heat ratio
    hpxml.cooling_systems.each do |cooling_system|
      next unless cooling_system.cooling_shr.nil?

      if cooling_system.cooling_system_type == HPXML::HVACTypeCentralAirConditioner
        if cooling_system.compressor_type == HPXML::HVACCompressorTypeSingleStage
          cooling_system.cooling_shr = 0.73
        elsif cooling_system.compressor_type == HPXML::HVACCompressorTypeTwoStage
          cooling_system.cooling_shr = 0.73
        elsif cooling_system.compressor_type == HPXML::HVACCompressorTypeVariableSpeed
          cooling_system.cooling_shr = 0.78
        end
        cooling_system.cooling_shr_isdefaulted = true
      elsif cooling_system.cooling_system_type == HPXML::HVACTypeRoomAirConditioner
        cooling_system.cooling_shr = 0.65
        cooling_system.cooling_shr_isdefaulted = true
      elsif cooling_system.cooling_system_type == HPXML::HVACTypeMiniSplitAirConditioner
        cooling_system.cooling_shr = 0.73
        cooling_system.cooling_shr_isdefaulted = true
      end
    end
    hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.cooling_shr.nil?

      if heat_pump.heat_pump_type == HPXML::HVACTypeHeatPumpAirToAir
        if heat_pump.compressor_type == HPXML::HVACCompressorTypeSingleStage
          heat_pump.cooling_shr = 0.73
        elsif heat_pump.compressor_type == HPXML::HVACCompressorTypeTwoStage
          heat_pump.cooling_shr = 0.724
        elsif heat_pump.compressor_type == HPXML::HVACCompressorTypeVariableSpeed
          heat_pump.cooling_shr = 0.78
        end
        heat_pump.cooling_shr_isdefaulted = true
      elsif heat_pump.heat_pump_type == HPXML::HVACTypeHeatPumpMiniSplit
        heat_pump.cooling_shr = 0.73
        heat_pump.cooling_shr_isdefaulted = true
      elsif heat_pump.heat_pump_type == HPXML::HVACTypeHeatPumpGroundToAir
        heat_pump.cooling_shr = 0.732
        heat_pump.cooling_shr_isdefaulted = true
      end
    end

    # GSHP pump power
    hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.heat_pump_type == HPXML::HVACTypeHeatPumpGroundToAir
      next unless heat_pump.pump_watts_per_ton.nil?

      heat_pump.pump_watts_per_ton = HVAC.get_default_gshp_pump_power()
      heat_pump.pump_watts_per_ton_isdefaulted = true
    end

    # Charge defect ratio
    hpxml.cooling_systems.each do |cooling_system|
      next unless [HPXML::HVACTypeCentralAirConditioner,
                   HPXML::HVACTypeMiniSplitAirConditioner].include? cooling_system.cooling_system_type
      next unless cooling_system.charge_defect_ratio.nil?

      cooling_system.charge_defect_ratio = 0.0
      cooling_system.charge_defect_ratio_isdefaulted = true
    end
    hpxml.heat_pumps.each do |heat_pump|
      next unless [HPXML::HVACTypeHeatPumpAirToAir,
                   HPXML::HVACTypeHeatPumpMiniSplit,
                   HPXML::HVACTypeHeatPumpGroundToAir].include? heat_pump.heat_pump_type
      next unless heat_pump.charge_defect_ratio.nil?

      heat_pump.charge_defect_ratio = 0.0
      heat_pump.charge_defect_ratio_isdefaulted = true
    end

    # Airflow defect ratio
    hpxml.heating_systems.each do |heating_system|
      next unless [HPXML::HVACTypeFurnace].include? heating_system.heating_system_type
      next unless heating_system.airflow_defect_ratio.nil?

      heating_system.airflow_defect_ratio = 0.0
      heating_system.airflow_defect_ratio_isdefaulted = true
    end
    hpxml.cooling_systems.each do |cooling_system|
      next unless [HPXML::HVACTypeCentralAirConditioner,
                   HPXML::HVACTypeMiniSplitAirConditioner].include? cooling_system.cooling_system_type
      next unless cooling_system.airflow_defect_ratio.nil?

      cooling_system.airflow_defect_ratio = 0.0
      cooling_system.airflow_defect_ratio_isdefaulted = true
    end
    hpxml.heat_pumps.each do |heat_pump|
      next unless [HPXML::HVACTypeHeatPumpAirToAir,
                   HPXML::HVACTypeHeatPumpGroundToAir,
                   HPXML::HVACTypeHeatPumpMiniSplit].include? heat_pump.heat_pump_type
      next unless heat_pump.airflow_defect_ratio.nil?

      heat_pump.airflow_defect_ratio = 0.0
      heat_pump.airflow_defect_ratio_isdefaulted = true
    end

    # Fan power
    psc_watts_per_cfm = 0.5 # W/cfm, PSC fan
    ecm_watts_per_cfm = 0.375 # W/cfm, ECM fan
    mini_split_ductless_watts_per_cfm = 0.07 # W/cfm
    mini_split_ducted_watts_per_cfm = 0.18 # W/cfm
    hpxml.heating_systems.each do |heating_system|
      if [HPXML::HVACTypeFurnace].include? heating_system.heating_system_type
        if heating_system.fan_watts_per_cfm.nil?
          if heating_system.distribution_system.air_type == HPXML::AirTypeGravity
            heating_system.fan_watts_per_cfm = 0.0
          elsif heating_system.heating_efficiency_afue > 0.9 # HEScore assumption
            heating_system.fan_watts_per_cfm = ecm_watts_per_cfm
          else
            heating_system.fan_watts_per_cfm = psc_watts_per_cfm
          end
          heating_system.fan_watts_per_cfm_isdefaulted = true
        end
      elsif [HPXML::HVACTypeStove].include? heating_system.heating_system_type
        if heating_system.fan_watts.nil?
          heating_system.fan_watts = 40.0 # W
          heating_system.fan_watts_isdefaulted = true
        end
      elsif [HPXML::HVACTypeWallFurnace,
             HPXML::HVACTypeFloorFurnace,
             HPXML::HVACTypePortableHeater,
             HPXML::HVACTypeFixedHeater,
             HPXML::HVACTypeFireplace].include? heating_system.heating_system_type
        if heating_system.fan_watts.nil?
          heating_system.fan_watts = 0.0 # W/cfm, assume no fan power
          heating_system.fan_watts_isdefaulted = true
        end
      end
    end
    hpxml.cooling_systems.each do |cooling_system|
      next unless cooling_system.fan_watts_per_cfm.nil?

      if (not cooling_system.attached_heating_system.nil?) && (not cooling_system.attached_heating_system.fan_watts_per_cfm.nil?)
        cooling_system.fan_watts_per_cfm = cooling_system.attached_heating_system.fan_watts_per_cfm
        cooling_system.fan_watts_per_cfm_isdefaulted = true
      elsif [HPXML::HVACTypeCentralAirConditioner].include? cooling_system.cooling_system_type
        if cooling_system.cooling_efficiency_seer > 13.5 # HEScore assumption
          cooling_system.fan_watts_per_cfm = ecm_watts_per_cfm
        else
          cooling_system.fan_watts_per_cfm = psc_watts_per_cfm
        end
        cooling_system.fan_watts_per_cfm_isdefaulted = true
      elsif [HPXML::HVACTypeMiniSplitAirConditioner].include? cooling_system.cooling_system_type
        if not cooling_system.distribution_system.nil?
          cooling_system.fan_watts_per_cfm = mini_split_ducted_watts_per_cfm
        else
          cooling_system.fan_watts_per_cfm = mini_split_ductless_watts_per_cfm
        end
        cooling_system.fan_watts_per_cfm_isdefaulted = true
      elsif [HPXML::HVACTypeEvaporativeCooler].include? cooling_system.cooling_system_type
        # Depends on airflow rate, so defaulted in hvac_sizing.rb
      end
    end
    hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.fan_watts_per_cfm.nil?

      if [HPXML::HVACTypeHeatPumpAirToAir].include? heat_pump.heat_pump_type
        if heat_pump.heating_efficiency_hspf > 8.75 # HEScore assumption
          heat_pump.fan_watts_per_cfm = ecm_watts_per_cfm
        else
          heat_pump.fan_watts_per_cfm = psc_watts_per_cfm
        end
        heat_pump.fan_watts_per_cfm_isdefaulted = true
      elsif [HPXML::HVACTypeHeatPumpGroundToAir].include? heat_pump.heat_pump_type
        if heat_pump.heating_efficiency_cop > 8.75 / 3.2 # HEScore assumption
          heat_pump.fan_watts_per_cfm = ecm_watts_per_cfm
        else
          heat_pump.fan_watts_per_cfm = psc_watts_per_cfm
        end
        heat_pump.fan_watts_per_cfm_isdefaulted = true
      elsif [HPXML::HVACTypeHeatPumpMiniSplit].include? heat_pump.heat_pump_type
        if not heat_pump.distribution_system.nil?
          heat_pump.fan_watts_per_cfm = mini_split_ducted_watts_per_cfm
        else
          heat_pump.fan_watts_per_cfm = mini_split_ductless_watts_per_cfm
        end
        heat_pump.fan_watts_per_cfm_isdefaulted = true
      end
    end

    # Detailed HVAC performance
    hpxml.cooling_systems.each do |cooling_system|
      clg_ap = cooling_system.additional_properties
      if [HPXML::HVACTypeCentralAirConditioner].include? cooling_system.cooling_system_type
        # Note: We use HP cooling curve so that a central AC behaves the same.
        HVAC.set_num_speeds(cooling_system)
        HVAC.set_fan_power_rated(cooling_system)
        HVAC.set_crankcase_assumptions(cooling_system)

        HVAC.set_cool_c_d(cooling_system, clg_ap.num_speeds)
        HVAC.set_cool_curves_ashp(cooling_system)
        HVAC.set_cool_rated_cfm_per_ton(cooling_system)
        HVAC.set_cool_rated_shrs_gross(cooling_system)
        HVAC.set_cool_rated_eirs(cooling_system)

      elsif [HPXML::HVACTypeRoomAirConditioner].include? cooling_system.cooling_system_type
        HVAC.set_num_speeds(cooling_system)
        HVAC.set_cool_c_d(cooling_system, clg_ap.num_speeds)
        HVAC.set_cool_curves_room_ac(cooling_system)
        HVAC.set_cool_rated_cfm_per_ton(cooling_system)
        HVAC.set_cool_rated_shrs_gross(cooling_system)

      elsif [HPXML::HVACTypeMiniSplitAirConditioner].include? cooling_system.cooling_system_type
        num_speeds = 10
        HVAC.set_num_speeds(cooling_system)
        HVAC.set_crankcase_assumptions(cooling_system)
        HVAC.set_fan_power_rated(cooling_system)

        HVAC.set_cool_c_d(cooling_system, num_speeds)
        HVAC.set_cool_curves_mshp(cooling_system, num_speeds)
        HVAC.set_cool_rated_cfm_per_ton_mshp(cooling_system, num_speeds)
        HVAC.set_cool_rated_eirs_mshp(cooling_system, num_speeds)

        HVAC.set_mshp_downselected_speed_indices(cooling_system)

      elsif [HPXML::HVACTypeEvaporativeCooler].include? cooling_system.cooling_system_type
        clg_ap.effectiveness = 0.72 # Assumption from HEScore

      end
    end
    hpxml.heating_systems.each do |heating_system|
      htg_ap = heating_system.additional_properties
      next unless [HPXML::HVACTypeStove,
                   HPXML::HVACTypePortableHeater,
                   HPXML::HVACTypeFixedHeater,
                   HPXML::HVACTypeWallFurnace,
                   HPXML::HVACTypeFloorFurnace,
                   HPXML::HVACTypeFireplace].include? heating_system.heating_system_type

      HVAC.set_heat_rated_cfm_per_ton(heating_system)
    end
    hpxml.heat_pumps.each do |heat_pump|
      hp_ap = heat_pump.additional_properties
      if [HPXML::HVACTypeHeatPumpAirToAir].include? heat_pump.heat_pump_type
        HVAC.set_num_speeds(heat_pump)
        HVAC.set_fan_power_rated(heat_pump)
        HVAC.set_crankcase_assumptions(heat_pump)
        HVAC.set_heat_pump_temperatures(heat_pump)

        HVAC.set_cool_c_d(heat_pump, hp_ap.num_speeds)
        HVAC.set_cool_curves_ashp(heat_pump)
        HVAC.set_cool_rated_cfm_per_ton(heat_pump)
        HVAC.set_cool_rated_shrs_gross(heat_pump)
        HVAC.set_cool_rated_eirs(heat_pump)

        HVAC.set_heat_c_d(heat_pump, hp_ap.num_speeds)
        HVAC.set_ashp_htg_curves(heat_pump)
        HVAC.set_heat_rated_cfm_per_ton(heat_pump)
        HVAC.set_heat_rated_eirs(heat_pump)

      elsif [HPXML::HVACTypeHeatPumpMiniSplit].include? heat_pump.heat_pump_type
        num_speeds = 10
        HVAC.set_num_speeds(heat_pump)
        HVAC.set_crankcase_assumptions(heat_pump)
        HVAC.set_fan_power_rated(heat_pump)
        HVAC.set_heat_pump_temperatures(heat_pump)

        HVAC.set_cool_c_d(heat_pump, num_speeds)
        HVAC.set_cool_curves_mshp(heat_pump, num_speeds)
        HVAC.set_cool_rated_cfm_per_ton_mshp(heat_pump, num_speeds)
        HVAC.set_cool_rated_eirs_mshp(heat_pump, num_speeds)

        HVAC.set_heat_c_d(heat_pump, num_speeds)
        HVAC.set_heat_curves_mshp(heat_pump, num_speeds)
        HVAC.set_heat_rated_cfm_per_ton_mshp(heat_pump, num_speeds)
        HVAC.set_heat_rated_eirs_mshp(heat_pump, num_speeds)

        HVAC.set_mshp_downselected_speed_indices(heat_pump)

      elsif [HPXML::HVACTypeHeatPumpGroundToAir].include? heat_pump.heat_pump_type
        HVAC.set_gshp_assumptions(heat_pump, weather)
        HVAC.set_curves_gshp(heat_pump)

      elsif [HPXML::HVACTypeHeatPumpWaterLoopToAir].include? heat_pump.heat_pump_type
        HVAC.set_heat_pump_temperatures(heat_pump)

      end
    end
  end

  def self.apply_hvac_control(hpxml)
    hpxml.hvac_controls.each do |hvac_control|
      if not hvac_control.heating_setback_temp.nil?
        if hvac_control.heating_setback_start_hour.nil?
          hvac_control.heating_setback_start_hour = 23 # 11 pm
          hvac_control.heating_setback_start_hour_isdefaulted = true
        end
      end

      if not hvac_control.cooling_setup_temp.nil?
        if hvac_control.cooling_setup_start_hour.nil?
          hvac_control.cooling_setup_start_hour = 9 # 9 am
          hvac_control.cooling_setup_start_hour_isdefaulted = true
        end
      end

      if hvac_control.seasons_heating_begin_month.nil? || hvac_control.seasons_heating_begin_day.nil? || hvac_control.seasons_heating_end_month.nil? || hvac_control.seasons_heating_end_day.nil?
        hvac_control.seasons_heating_begin_month = 1
        hvac_control.seasons_heating_begin_day = 1
        hvac_control.seasons_heating_end_month = 12
        hvac_control.seasons_heating_end_day = 31
        hvac_control.seasons_heating_begin_month_isdefaulted = true
        hvac_control.seasons_heating_begin_day_isdefaulted = true
        hvac_control.seasons_heating_end_month_isdefaulted = true
        hvac_control.seasons_heating_end_day_isdefaulted = true
      end

      next unless hvac_control.seasons_cooling_begin_month.nil? || hvac_control.seasons_cooling_begin_day.nil? || hvac_control.seasons_cooling_end_month.nil? || hvac_control.seasons_cooling_end_day.nil?

      hvac_control.seasons_cooling_begin_month = 1
      hvac_control.seasons_cooling_begin_day = 1
      hvac_control.seasons_cooling_end_month = 12
      hvac_control.seasons_cooling_end_day = 31
      hvac_control.seasons_cooling_begin_month_isdefaulted = true
      hvac_control.seasons_cooling_begin_day_isdefaulted = true
      hvac_control.seasons_cooling_end_month_isdefaulted = true
      hvac_control.seasons_cooling_end_day_isdefaulted = true
    end
  end

  def self.apply_hvac_distribution(hpxml, ncfl, ncfl_ag)
    hpxml.hvac_distributions.each do |hvac_distribution|
      next unless [HPXML::HVACDistributionTypeAir].include? hvac_distribution.distribution_system_type

      # Default return registers
      if hvac_distribution.number_of_return_registers.nil?
        hvac_distribution.number_of_return_registers = ncfl.ceil # Add 1 return register per conditioned floor if not provided
        hvac_distribution.number_of_return_registers_isdefaulted = true
      end

      next if hvac_distribution.ducts.empty?

      # Default ducts

      cfa_served = hvac_distribution.conditioned_floor_area_served
      n_returns = hvac_distribution.number_of_return_registers
      supply_ducts = hvac_distribution.ducts.select { |duct| duct.duct_type == HPXML::DuctTypeSupply }
      return_ducts = hvac_distribution.ducts.select { |duct| duct.duct_type == HPXML::DuctTypeReturn }

      if hvac_distribution.ducts[0].duct_location.nil?
        # Default both duct location(s) and duct surface area(s)
        [supply_ducts, return_ducts].each do |ducts|
          ducts.each do |duct|
            primary_duct_area, secondary_duct_area = HVAC.get_default_duct_surface_area(duct.duct_type, ncfl_ag, cfa_served, n_returns).map { |area| area / ducts.size }
            primary_duct_location, secondary_duct_location = HVAC.get_default_duct_locations(hpxml)
            if primary_duct_location.nil? # If a home doesn't have any non-living spaces (outside living space), place all ducts in living space.
              duct.duct_surface_area = primary_duct_area + secondary_duct_area
              duct.duct_surface_area_isdefaulted = true
              duct.duct_location = secondary_duct_location
              duct.duct_location_isdefaulted = true
            else
              duct.duct_surface_area = primary_duct_area
              duct.duct_surface_area_isdefaulted = true
              duct.duct_location = primary_duct_location
              duct.duct_location_isdefaulted = true

              if secondary_duct_area > 0
                hvac_distribution.ducts.add(duct_type: duct.duct_type,
                                            duct_insulation_r_value: duct.duct_insulation_r_value,
                                            duct_location: secondary_duct_location,
                                            duct_location_isdefaulted: true,
                                            duct_surface_area: secondary_duct_area,
                                            duct_surface_area_isdefaulted: true)
              end
            end
          end
        end

      elsif hvac_distribution.ducts[0].duct_surface_area.nil?
        # Default duct surface area(s)
        [supply_ducts, return_ducts].each do |ducts|
          ducts.each do |duct|
            total_duct_area = HVAC.get_default_duct_surface_area(duct.duct_type, ncfl_ag, cfa_served, n_returns).sum()
            duct.duct_surface_area = total_duct_area * duct.duct_fraction_area
            duct.duct_surface_area_isdefaulted = true
          end
        end
      end

      # Calculate FractionDuctArea from DuctSurfaceArea
      supply_ducts = hvac_distribution.ducts.select { |duct| duct.duct_type == HPXML::DuctTypeSupply }
      return_ducts = hvac_distribution.ducts.select { |duct| duct.duct_type == HPXML::DuctTypeReturn }
      total_supply_area = supply_ducts.map { |d| d.duct_surface_area }.sum
      total_return_area = return_ducts.map { |d| d.duct_surface_area }.sum
      (supply_ducts + return_ducts).each do |duct|
        next unless duct.duct_fraction_area.nil?

        if duct.duct_type == HPXML::DuctTypeSupply
          duct.duct_fraction_area = (duct.duct_surface_area / total_supply_area).round(3)
          duct.duct_fraction_area_isdefaulted = true
        elsif duct.duct_type == HPXML::DuctTypeReturn
          duct.duct_fraction_area = (duct.duct_surface_area / total_return_area).round(3)
          duct.duct_fraction_area_isdefaulted = true
        end
      end
    end
  end

  def self.apply_ventilation_fans(hpxml)
    # Default mech vent systems
    hpxml.ventilation_fans.each do |vent_fan|
      next unless vent_fan.used_for_whole_building_ventilation

      if vent_fan.is_shared_system.nil?
        vent_fan.is_shared_system = false
        vent_fan.is_shared_system_isdefaulted = true
      end
      if vent_fan.hours_in_operation.nil?
        vent_fan.hours_in_operation = (vent_fan.fan_type == HPXML::MechVentTypeCFIS) ? 8.0 : 24.0
        vent_fan.hours_in_operation_isdefaulted = true
      end
      if vent_fan.fan_power.nil?
        flow_rate = [vent_fan.rated_flow_rate.to_f, vent_fan.tested_flow_rate.to_f].max
        vent_fan.fan_power = flow_rate * Airflow.get_default_mech_vent_fan_power(vent_fan)
      end
    end

    # Default kitchen fan
    hpxml.ventilation_fans.each do |vent_fan|
      next unless (vent_fan.used_for_local_ventilation && (vent_fan.fan_location == HPXML::LocationKitchen))

      if vent_fan.quantity.nil?
        vent_fan.quantity = 1
        vent_fan.quantity_isdefaulted = true
      end
      if vent_fan.rated_flow_rate.nil?
        vent_fan.rated_flow_rate = 100.0 # cfm, per BA HSP
        vent_fan.rated_flow_rate_isdefaulted = true
      end
      if vent_fan.hours_in_operation.nil?
        vent_fan.hours_in_operation = 1.0 # hrs/day, per BA HSP
        vent_fan.hours_in_operation_isdefaulted = true
      end
      if vent_fan.fan_power.nil?
        vent_fan.fan_power = 0.3 * vent_fan.rated_flow_rate # W, per BA HSP
        vent_fan.fan_power_isdefaulted = true
      end
      if vent_fan.start_hour.nil?
        vent_fan.start_hour = 18 # 6 pm, per BA HSP
        vent_fan.start_hour_isdefaulted = true
      end
    end

    # Default bath fans
    hpxml.ventilation_fans.each do |vent_fan|
      next unless (vent_fan.used_for_local_ventilation && (vent_fan.fan_location == HPXML::LocationBath))

      if vent_fan.quantity.nil?
        vent_fan.quantity = hpxml.building_construction.number_of_bathrooms
        vent_fan.quantity_isdefaulted = true
      end
      if vent_fan.rated_flow_rate.nil?
        vent_fan.rated_flow_rate = 50.0 # cfm, per BA HSP
        vent_fan.rated_flow_rate_isdefaulted = true
      end
      if vent_fan.hours_in_operation.nil?
        vent_fan.hours_in_operation = 1.0 # hrs/day, per BA HSP
        vent_fan.hours_in_operation_isdefaulted = true
      end
      if vent_fan.fan_power.nil?
        vent_fan.fan_power = 0.3 * vent_fan.rated_flow_rate # W, per BA HSP
        vent_fan.fan_power_isdefaulted = true
      end
      if vent_fan.start_hour.nil?
        vent_fan.start_hour = 7 # 7 am, per BA HSP
        vent_fan.start_hour_isdefaulted = true
      end
    end
  end

  def self.apply_water_heaters(hpxml, nbeds, eri_version)
    hpxml.water_heating_systems.each do |water_heating_system|
      if water_heating_system.is_shared_system.nil?
        water_heating_system.is_shared_system = false
        water_heating_system.is_shared_system_isdefaulted = true
      end
      if water_heating_system.temperature.nil?
        water_heating_system.temperature = Waterheater.get_default_hot_water_temperature(eri_version)
        water_heating_system.temperature_isdefaulted = true
      end
      if water_heating_system.performance_adjustment.nil?
        water_heating_system.performance_adjustment = Waterheater.get_default_performance_adjustment(water_heating_system)
        water_heating_system.performance_adjustment_isdefaulted = true
      end
      if (water_heating_system.water_heater_type == HPXML::WaterHeaterTypeCombiStorage) && water_heating_system.standby_loss.nil?
        # Use equation fit from AHRI database
        # calculate independent variable SurfaceArea/vol(physically linear to standby_loss/skin_u under test condition) to fit the linear equation from AHRI database
        act_vol = Waterheater.calc_storage_tank_actual_vol(water_heating_system.tank_volume, nil)
        surface_area = Waterheater.calc_tank_areas(act_vol)[0]
        sqft_by_gal = surface_area / act_vol # sqft/gal
        water_heating_system.standby_loss = (2.9721 * sqft_by_gal - 0.4732).round(3) # linear equation assuming a constant u, F/hr
        water_heating_system.standby_loss_isdefaulted = true
      end
      if (water_heating_system.water_heater_type == HPXML::WaterHeaterTypeStorage)
        if water_heating_system.heating_capacity.nil?
          water_heating_system.heating_capacity = (Waterheater.get_default_heating_capacity(water_heating_system.fuel_type, nbeds, hpxml.water_heating_systems.size, hpxml.building_construction.number_of_bathrooms) * 1000.0).round
          water_heating_system.heating_capacity_isdefaulted = true
        end
        if water_heating_system.tank_volume.nil?
          water_heating_system.tank_volume = Waterheater.get_default_tank_volume(water_heating_system.fuel_type, nbeds, hpxml.building_construction.number_of_bathrooms)
          water_heating_system.tank_volume_isdefaulted = true
        end
        if water_heating_system.energy_factor.nil? && water_heating_system.uniform_energy_factor.nil?
          water_heating_system.energy_factor = Waterheater.get_default_water_heater_efficiency_by_year_installed(water_heating_system.year_installed, water_heating_system.fuel_type)
          water_heating_system.energy_factor_isdefaulted = true
        end
        if water_heating_system.recovery_efficiency.nil?
          water_heating_system.recovery_efficiency = Waterheater.get_default_recovery_efficiency(water_heating_system)
          water_heating_system.recovery_efficiency_isdefaulted = true
        end
      end
      if water_heating_system.location.nil?
        water_heating_system.location = Waterheater.get_default_location(hpxml, hpxml.climate_and_risk_zones.iecc_zone)
        water_heating_system.location_isdefaulted = true
      end
      next unless water_heating_system.usage_bin.nil? && (not water_heating_system.uniform_energy_factor.nil?) # FHR & UsageBin only applies to UEF

      if not water_heating_system.first_hour_rating.nil?
        water_heating_system.usage_bin = Waterheater.get_usage_bin_from_first_hour_rating(water_heating_system.first_hour_rating)
      else
        water_heating_system.usage_bin = HPXML::WaterHeaterUsageBinMedium
      end
      water_heating_system.usage_bin_isdefaulted = true
    end
  end

  def self.apply_hot_water_distribution(hpxml, cfa, ncfl, has_uncond_bsmnt)
    return if hpxml.hot_water_distributions.size == 0

    hot_water_distribution = hpxml.hot_water_distributions[0]

    if hot_water_distribution.pipe_r_value.nil?
      hot_water_distribution.pipe_r_value = 0.0
      hot_water_distribution.pipe_r_value_isdefaulted = true
    end

    if hot_water_distribution.system_type == HPXML::DHWDistTypeStandard
      if hot_water_distribution.standard_piping_length.nil?
        hot_water_distribution.standard_piping_length = HotWaterAndAppliances.get_default_std_pipe_length(has_uncond_bsmnt, cfa, ncfl)
        hot_water_distribution.standard_piping_length_isdefaulted = true
      end
    elsif hot_water_distribution.system_type == HPXML::DHWDistTypeRecirc
      if hot_water_distribution.recirculation_piping_length.nil?
        hot_water_distribution.recirculation_piping_length = HotWaterAndAppliances.get_default_recirc_loop_length(HotWaterAndAppliances.get_default_std_pipe_length(has_uncond_bsmnt, cfa, ncfl))
        hot_water_distribution.recirculation_piping_length_isdefaulted = true
      end
      if hot_water_distribution.recirculation_branch_piping_length.nil?
        hot_water_distribution.recirculation_branch_piping_length = HotWaterAndAppliances.get_default_recirc_branch_loop_length()
        hot_water_distribution.recirculation_branch_piping_length_isdefaulted = true
      end
      if hot_water_distribution.recirculation_pump_power.nil?
        hot_water_distribution.recirculation_pump_power = HotWaterAndAppliances.get_default_recirc_pump_power()
        hot_water_distribution.recirculation_pump_power_isdefaulted = true
      end
    end

    if hot_water_distribution.has_shared_recirculation
      if hot_water_distribution.shared_recirculation_pump_power.nil?
        hot_water_distribution.shared_recirculation_pump_power = HotWaterAndAppliances.get_default_shared_recirc_pump_power()
        hot_water_distribution.shared_recirculation_pump_power_isdefaulted = true
      end
    end
  end

  def self.apply_water_fixtures(hpxml)
    return if hpxml.hot_water_distributions.size == 0

    if hpxml.water_heating.water_fixtures_usage_multiplier.nil?
      hpxml.water_heating.water_fixtures_usage_multiplier = 1.0
      hpxml.water_heating.water_fixtures_usage_multiplier_isdefaulted = true
    end
  end

  def self.apply_solar_thermal_systems(hpxml)
    hpxml.solar_thermal_systems.each do |solar_thermal_system|
      if solar_thermal_system.collector_azimuth.nil?
        solar_thermal_system.collector_azimuth = get_azimuth_from_orientation(solar_thermal_system.collector_orientation)
        solar_thermal_system.collector_azimuth_isdefaulted = true
      end
      if solar_thermal_system.collector_orientation.nil?
        solar_thermal_system.collector_orientation = get_orientation_from_azimuth(solar_thermal_system.collector_azimuth)
        solar_thermal_system.collector_orientation_isdefaulted = true
      end
      if solar_thermal_system.storage_volume.nil? && (not solar_thermal_system.collector_area.nil?) # Detailed solar water heater
        solar_thermal_system.storage_volume = Waterheater.calc_default_solar_thermal_system_storage_volume(solar_thermal_system.collector_area)
        solar_thermal_system.storage_volume_isdefaulted = true
      end
    end
  end

  def self.apply_pv_systems(hpxml)
    hpxml.pv_systems.each do |pv_system|
      if pv_system.array_azimuth.nil?
        pv_system.array_azimuth = get_azimuth_from_orientation(pv_system.array_orientation)
        pv_system.array_azimuth_isdefaulted = true
      end
      if pv_system.array_orientation.nil?
        pv_system.array_orientation = get_orientation_from_azimuth(pv_system.array_azimuth)
        pv_system.array_orientation_isdefaulted = true
      end
      if pv_system.is_shared_system.nil?
        pv_system.is_shared_system = false
        pv_system.is_shared_system_isdefaulted = true
      end
      if pv_system.location.nil?
        pv_system.location = HPXML::LocationRoof
        pv_system.location_isdefaulted = true
      end
      if pv_system.tracking.nil?
        pv_system.tracking = HPXML::PVTrackingTypeFixed
        pv_system.tracking_isdefaulted = true
      end
      if pv_system.module_type.nil?
        pv_system.module_type = HPXML::PVModuleTypeStandard
        pv_system.module_type_isdefaulted = true
      end
      if pv_system.inverter_efficiency.nil?
        pv_system.inverter_efficiency = PV.get_default_inv_eff()
        pv_system.inverter_efficiency_isdefaulted = true
      end
      if pv_system.system_losses_fraction.nil?
        pv_system.system_losses_fraction = PV.get_default_system_losses(pv_system.year_modules_manufactured)
        pv_system.system_losses_fraction_isdefaulted = true
      end
    end
  end

  def self.apply_generators(hpxml)
    hpxml.generators.each do |generator|
      if generator.is_shared_system.nil?
        generator.is_shared_system = false
        generator.is_shared_system_isdefaulted = true
      end
    end
  end

  def self.apply_appliances(hpxml, nbeds, eri_version)
    # Default clothes washer
    if hpxml.clothes_washers.size > 0
      clothes_washer = hpxml.clothes_washers[0]
      if clothes_washer.is_shared_appliance.nil?
        clothes_washer.is_shared_appliance = false
        clothes_washer.is_shared_appliance_isdefaulted = true
      end
      if clothes_washer.location.nil?
        clothes_washer.location = HPXML::LocationLivingSpace
        clothes_washer.location_isdefaulted = true
      end
      if clothes_washer.rated_annual_kwh.nil?
        default_values = HotWaterAndAppliances.get_clothes_washer_default_values(eri_version)
        clothes_washer.integrated_modified_energy_factor = default_values[:integrated_modified_energy_factor]
        clothes_washer.integrated_modified_energy_factor_isdefaulted = true
        clothes_washer.rated_annual_kwh = default_values[:rated_annual_kwh]
        clothes_washer.rated_annual_kwh_isdefaulted = true
        clothes_washer.label_electric_rate = default_values[:label_electric_rate]
        clothes_washer.label_electric_rate_isdefaulted = true
        clothes_washer.label_gas_rate = default_values[:label_gas_rate]
        clothes_washer.label_gas_rate_isdefaulted = true
        clothes_washer.label_annual_gas_cost = default_values[:label_annual_gas_cost]
        clothes_washer.label_annual_gas_cost_isdefaulted = true
        clothes_washer.capacity = default_values[:capacity]
        clothes_washer.capacity_isdefaulted = true
        clothes_washer.label_usage = default_values[:label_usage]
        clothes_washer.label_usage_isdefaulted = true
      end
      if clothes_washer.usage_multiplier.nil?
        clothes_washer.usage_multiplier = 1.0
        clothes_washer.usage_multiplier_isdefaulted = true
      end
    end

    # Default clothes dryer
    if hpxml.clothes_dryers.size > 0
      clothes_dryer = hpxml.clothes_dryers[0]
      if clothes_dryer.is_shared_appliance.nil?
        clothes_dryer.is_shared_appliance = false
        clothes_dryer.is_shared_appliance_isdefaulted = true
      end
      if clothes_dryer.location.nil?
        clothes_dryer.location = HPXML::LocationLivingSpace
        clothes_dryer.location_isdefaulted = true
      end
      if clothes_dryer.combined_energy_factor.nil? && clothes_dryer.energy_factor.nil?
        default_values = HotWaterAndAppliances.get_clothes_dryer_default_values(eri_version, clothes_dryer.fuel_type)
        clothes_dryer.combined_energy_factor = default_values[:combined_energy_factor]
        clothes_dryer.combined_energy_factor_isdefaulted = true
      end
      if clothes_dryer.control_type.nil?
        default_values = HotWaterAndAppliances.get_clothes_dryer_default_values(eri_version, clothes_dryer.fuel_type)
        clothes_dryer.control_type = default_values[:control_type]
        clothes_dryer.control_type_isdefaulted = true
      end
      if clothes_dryer.usage_multiplier.nil?
        clothes_dryer.usage_multiplier = 1.0
        clothes_dryer.usage_multiplier_isdefaulted = true
      end
      if clothes_dryer.is_vented.nil?
        clothes_dryer.is_vented = true
        clothes_dryer.is_vented_isdefaulted = true
      end
      if clothes_dryer.is_vented && clothes_dryer.vented_flow_rate.nil?
        clothes_dryer.vented_flow_rate = 100.0
        clothes_dryer.vented_flow_rate_isdefaulted = true
      end
    end

    # Default dishwasher
    if hpxml.dishwashers.size > 0
      dishwasher = hpxml.dishwashers[0]
      if dishwasher.is_shared_appliance.nil?
        dishwasher.is_shared_appliance = false
        dishwasher.is_shared_appliance_isdefaulted = true
      end
      if dishwasher.location.nil?
        dishwasher.location = HPXML::LocationLivingSpace
        dishwasher.location_isdefaulted = true
      end
      if dishwasher.place_setting_capacity.nil?
        default_values = HotWaterAndAppliances.get_dishwasher_default_values(eri_version)
        dishwasher.rated_annual_kwh = default_values[:rated_annual_kwh]
        dishwasher.rated_annual_kwh_isdefaulted = true
        dishwasher.label_electric_rate = default_values[:label_electric_rate]
        dishwasher.label_electric_rate_isdefaulted = true
        dishwasher.label_gas_rate = default_values[:label_gas_rate]
        dishwasher.label_gas_rate_isdefaulted = true
        dishwasher.label_annual_gas_cost = default_values[:label_annual_gas_cost]
        dishwasher.label_annual_gas_cost_isdefaulted = true
        dishwasher.label_usage = default_values[:label_usage]
        dishwasher.label_usage_isdefaulted = true
        dishwasher.place_setting_capacity = default_values[:place_setting_capacity]
        dishwasher.place_setting_capacity_isdefaulted = true
      end
      if dishwasher.usage_multiplier.nil?
        dishwasher.usage_multiplier = 1.0
        dishwasher.usage_multiplier_isdefaulted = true
      end
    end

    # Default refrigerators
    if hpxml.refrigerators.size == 1
      hpxml.refrigerators[0].primary_indicator = true
      hpxml.refrigerators[0].primary_indicator_isdefaulted = true
    end
    hpxml.refrigerators.each do |refrigerator|
      if not refrigerator.primary_indicator # extra refrigerator
        if refrigerator.location.nil?
          refrigerator.location = HotWaterAndAppliances.get_default_extra_refrigerator_and_freezer_locations(hpxml)
          refrigerator.location_isdefaulted = true
        end
        if refrigerator.adjusted_annual_kwh.nil? && refrigerator.rated_annual_kwh.nil?
          default_values = HotWaterAndAppliances.get_extra_refrigerator_default_values
          refrigerator.rated_annual_kwh = default_values[:rated_annual_kwh]
          refrigerator.rated_annual_kwh_isdefaulted = true
        end
        if refrigerator.weekday_fractions.nil?
          refrigerator.weekday_fractions = Schedule.ExtraRefrigeratorWeekdayFractions
          refrigerator.weekday_fractions_isdefaulted = true
        end
        if refrigerator.weekend_fractions.nil?
          refrigerator.weekend_fractions = Schedule.ExtraRefrigeratorWeekendFractions
          refrigerator.weekend_fractions_isdefaulted = true
        end
        if refrigerator.monthly_multipliers.nil?
          refrigerator.monthly_multipliers = Schedule.ExtraRefrigeratorMonthlyMultipliers
          refrigerator.monthly_multipliers_isdefaulted = true
        end
      else # primary refrigerator
        if refrigerator.location.nil?
          refrigerator.location = HPXML::LocationLivingSpace
          refrigerator.location_isdefaulted = true
        end
        if refrigerator.adjusted_annual_kwh.nil? && refrigerator.rated_annual_kwh.nil?
          default_values = HotWaterAndAppliances.get_refrigerator_default_values(nbeds)
          refrigerator.rated_annual_kwh = default_values[:rated_annual_kwh]
          refrigerator.rated_annual_kwh_isdefaulted = true
        end
        if refrigerator.weekday_fractions.nil?
          refrigerator.weekday_fractions = Schedule.RefrigeratorWeekdayFractions
          refrigerator.weekday_fractions_isdefaulted = true
        end
        if refrigerator.weekend_fractions.nil?
          refrigerator.weekend_fractions = Schedule.RefrigeratorWeekendFractions
          refrigerator.weekend_fractions_isdefaulted = true
        end
        if refrigerator.monthly_multipliers.nil?
          refrigerator.monthly_multipliers = Schedule.RefrigeratorMonthlyMultipliers
          refrigerator.monthly_multipliers_isdefaulted = true
        end
      end
      if refrigerator.usage_multiplier.nil?
        refrigerator.usage_multiplier = 1.0
        refrigerator.usage_multiplier_isdefaulted = true
      end
    end

    # Default freezer
    hpxml.freezers.each do |freezer|
      if freezer.location.nil?
        freezer.location = HotWaterAndAppliances.get_default_extra_refrigerator_and_freezer_locations(hpxml)
        freezer.location_isdefaulted = true
      end
      if freezer.adjusted_annual_kwh.nil? && freezer.rated_annual_kwh.nil?
        default_values = HotWaterAndAppliances.get_freezer_default_values
        freezer.rated_annual_kwh = default_values[:rated_annual_kwh]
        freezer.rated_annual_kwh_isdefaulted = true
      end
      if freezer.usage_multiplier.nil?
        freezer.usage_multiplier = 1.0
        freezer.usage_multiplier_isdefaulted = true
      end
      if freezer.weekday_fractions.nil?
        freezer.weekday_fractions = Schedule.FreezerWeekdayFractions
        freezer.weekday_fractions_isdefaulted = true
      end
      if freezer.weekend_fractions.nil?
        freezer.weekend_fractions = Schedule.FreezerWeekendFractions
        freezer.weekend_fractions_isdefaulted = true
      end
      if freezer.monthly_multipliers.nil?
        freezer.monthly_multipliers = Schedule.FreezerMonthlyMultipliers
        freezer.monthly_multipliers_isdefaulted = true
      end
    end

    # Default cooking range
    if hpxml.cooking_ranges.size > 0
      cooking_range = hpxml.cooking_ranges[0]
      if cooking_range.location.nil?
        cooking_range.location = HPXML::LocationLivingSpace
        cooking_range.location_isdefaulted = true
      end
      if cooking_range.is_induction.nil?
        default_values = HotWaterAndAppliances.get_range_oven_default_values()
        cooking_range.is_induction = default_values[:is_induction]
        cooking_range.is_induction_isdefaulted = true
      end
      if cooking_range.usage_multiplier.nil?
        cooking_range.usage_multiplier = 1.0
        cooking_range.usage_multiplier_isdefaulted = true
      end
      if cooking_range.weekday_fractions.nil?
        cooking_range.weekday_fractions = Schedule.CookingRangeWeekdayFractions
        cooking_range.weekday_fractions_isdefaulted = true
      end
      if cooking_range.weekend_fractions.nil?
        cooking_range.weekend_fractions = Schedule.CookingRangeWeekendFractions
        cooking_range.weekend_fractions_isdefaulted = true
      end
      if cooking_range.monthly_multipliers.nil?
        cooking_range.monthly_multipliers = Schedule.CookingRangeMonthlyMultipliers
        cooking_range.monthly_multipliers_isdefaulted = true
      end
    end

    # Default oven
    if hpxml.ovens.size > 0
      oven = hpxml.ovens[0]
      if oven.is_convection.nil?
        default_values = HotWaterAndAppliances.get_range_oven_default_values()
        oven.is_convection = default_values[:is_convection]
        oven.is_convection_isdefaulted = true
      end
    end
  end

  def self.apply_lighting(hpxml)
    return if hpxml.lighting_groups.empty?

    if hpxml.lighting.interior_usage_multiplier.nil?
      hpxml.lighting.interior_usage_multiplier = 1.0
      hpxml.lighting.interior_usage_multiplier_isdefaulted = true
    end
    if hpxml.lighting.garage_usage_multiplier.nil?
      hpxml.lighting.garage_usage_multiplier = 1.0
      hpxml.lighting.garage_usage_multiplier_isdefaulted = true
    end
    if hpxml.lighting.exterior_usage_multiplier.nil?
      hpxml.lighting.exterior_usage_multiplier = 1.0
      hpxml.lighting.exterior_usage_multiplier_isdefaulted = true
    end
    # Schedules from T24 2016 Residential ACM Appendix C Table 8 Exterior Lighting Hourly Multiplier (Weekdays and weekends)
    default_exterior_lighting_weekday_fractions = Schedule.LightingExteriorWeekdayFractions
    default_exterior_lighting_weekend_fractions = Schedule.LightingExteriorWeekendFractions
    default_exterior_lighting_monthly_multipliers = Schedule.LightingExteriorMonthlyMultipliers
    if hpxml.has_space_type(HPXML::LocationGarage)
      if hpxml.lighting.garage_weekday_fractions.nil?
        hpxml.lighting.garage_weekday_fractions = default_exterior_lighting_weekday_fractions
        hpxml.lighting.garage_weekday_fractions_isdefaulted = true
      end
      if hpxml.lighting.garage_weekend_fractions.nil?
        hpxml.lighting.garage_weekend_fractions = default_exterior_lighting_weekend_fractions
        hpxml.lighting.garage_weekend_fractions_isdefaulted = true
      end
      if hpxml.lighting.garage_monthly_multipliers.nil?
        hpxml.lighting.garage_monthly_multipliers = default_exterior_lighting_monthly_multipliers
        hpxml.lighting.garage_monthly_multipliers_isdefaulted = true
      end
    end
    if hpxml.lighting.exterior_weekday_fractions.nil?
      hpxml.lighting.exterior_weekday_fractions = default_exterior_lighting_weekday_fractions
      hpxml.lighting.exterior_weekday_fractions_isdefaulted = true
    end
    if hpxml.lighting.exterior_weekend_fractions.nil?
      hpxml.lighting.exterior_weekend_fractions = default_exterior_lighting_weekend_fractions
      hpxml.lighting.exterior_weekend_fractions_isdefaulted = true
    end
    if hpxml.lighting.exterior_monthly_multipliers.nil?
      hpxml.lighting.exterior_monthly_multipliers = default_exterior_lighting_monthly_multipliers
      hpxml.lighting.exterior_monthly_multipliers_isdefaulted = true
    end
    if hpxml.lighting.holiday_exists
      if hpxml.lighting.holiday_kwh_per_day.nil?
        # From LA100 repo (2017)
        if hpxml.building_construction.residential_facility_type == HPXML::ResidentialTypeSFD
          hpxml.lighting.holiday_kwh_per_day = 1.1
        else # Multifamily and others
          hpxml.lighting.holiday_kwh_per_day = 0.55
        end
        hpxml.lighting.holiday_kwh_per_day_isdefaulted = true
      end
      if hpxml.lighting.holiday_period_begin_month.nil?
        hpxml.lighting.holiday_period_begin_month = 11
        hpxml.lighting.holiday_period_begin_month_isdefaulted = true
        hpxml.lighting.holiday_period_begin_day = 24
        hpxml.lighting.holiday_period_begin_day_isdefaulted = true
      end
      if hpxml.lighting.holiday_period_end_day.nil?
        hpxml.lighting.holiday_period_end_month = 1
        hpxml.lighting.holiday_period_end_month_isdefaulted = true
        hpxml.lighting.holiday_period_end_day = 6
        hpxml.lighting.holiday_period_end_day_isdefaulted = true
      end
      if hpxml.lighting.holiday_weekday_fractions.nil?
        hpxml.lighting.holiday_weekday_fractions = Schedule.LightingExteriorHolidayWeekdayFractions
        hpxml.lighting.holiday_weekday_fractions_isdefaulted = true
      end
      if hpxml.lighting.holiday_weekend_fractions.nil?
        hpxml.lighting.holiday_weekend_fractions = Schedule.LightingExteriorHolidayWeekendFractions
        hpxml.lighting.holiday_weekend_fractions_isdefaulted = true
      end
    end
  end

  def self.apply_ceiling_fans(hpxml, nbeds)
    return if hpxml.ceiling_fans.size == 0

    ceiling_fan = hpxml.ceiling_fans[0]
    if ceiling_fan.efficiency.nil?
      medium_cfm = 3000.0
      ceiling_fan.efficiency = medium_cfm / HVAC.get_default_ceiling_fan_power()
      ceiling_fan.efficiency_isdefaulted = true
    end
    if ceiling_fan.quantity.nil?
      ceiling_fan.quantity = HVAC.get_default_ceiling_fan_quantity(nbeds)
      ceiling_fan.quantity_isdefaulted = true
    end
  end

  def self.apply_pools_and_hot_tubs(hpxml, cfa, nbeds)
    hpxml.pools.each do |pool|
      next if pool.type == HPXML::TypeNone

      if pool.pump_type != HPXML::TypeNone
        # Pump
        if pool.pump_kwh_per_year.nil?
          pool.pump_kwh_per_year = MiscLoads.get_pool_pump_default_values(cfa, nbeds)
          pool.pump_kwh_per_year_isdefaulted = true
        end
        if pool.pump_usage_multiplier.nil?
          pool.pump_usage_multiplier = 1.0
          pool.pump_usage_multiplier_isdefaulted = true
        end
        if pool.pump_weekday_fractions.nil?
          pool.pump_weekday_fractions = '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003'
          pool.pump_weekday_fractions_isdefaulted = true
        end
        if pool.pump_weekend_fractions.nil?
          pool.pump_weekend_fractions = '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003'
          pool.pump_weekend_fractions_isdefaulted = true
        end
        if pool.pump_monthly_multipliers.nil?
          pool.pump_monthly_multipliers = '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154'
          pool.pump_monthly_multipliers_isdefaulted = true
        end
      end

      next unless pool.heater_type != HPXML::TypeNone

      # Heater
      if pool.heater_load_value.nil?
        default_heater_load_units, default_heater_load_value = MiscLoads.get_pool_heater_default_values(cfa, nbeds, pool.heater_type)
        pool.heater_load_units = default_heater_load_units
        pool.heater_load_value = default_heater_load_value
        pool.heater_load_value_isdefaulted = true
      end
      if pool.heater_usage_multiplier.nil?
        pool.heater_usage_multiplier = 1.0
        pool.heater_usage_multiplier_isdefaulted = true
      end
      if pool.heater_weekday_fractions.nil?
        pool.heater_weekday_fractions = '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003'
        pool.heater_weekday_fractions_isdefaulted = true
      end
      if pool.heater_weekend_fractions.nil?
        pool.heater_weekend_fractions = '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003'
        pool.heater_weekend_fractions_isdefaulted = true
      end
      if pool.heater_monthly_multipliers.nil?
        pool.heater_monthly_multipliers = '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154'
        pool.heater_monthly_multipliers_isdefaulted = true
      end
    end

    hpxml.hot_tubs.each do |hot_tub|
      next if hot_tub.type == HPXML::TypeNone

      if hot_tub.pump_type != HPXML::TypeNone
        # Pump
        if hot_tub.pump_kwh_per_year.nil?
          hot_tub.pump_kwh_per_year = MiscLoads.get_hot_tub_pump_default_values(cfa, nbeds)
          hot_tub.pump_kwh_per_year_isdefaulted = true
        end
        if hot_tub.pump_usage_multiplier.nil?
          hot_tub.pump_usage_multiplier = 1.0
          hot_tub.pump_usage_multiplier_isdefaulted = true
        end
        if hot_tub.pump_weekday_fractions.nil?
          hot_tub.pump_weekday_fractions = '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024'
          hot_tub.pump_weekday_fractions_isdefaulted = true
        end
        if hot_tub.pump_weekend_fractions.nil?
          hot_tub.pump_weekend_fractions = '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024'
          hot_tub.pump_weekend_fractions_isdefaulted = true
        end
        if hot_tub.pump_monthly_multipliers.nil?
          hot_tub.pump_monthly_multipliers = '0.921, 0.928, 0.921, 0.915, 0.921, 1.160, 1.158, 1.158, 1.160, 0.921, 0.915, 0.921'
          hot_tub.pump_monthly_multipliers_isdefaulted = true
        end
      end

      next unless hot_tub.heater_type != HPXML::TypeNone

      # Heater
      if hot_tub.heater_load_value.nil?
        default_heater_load_units, default_heater_load_value = MiscLoads.get_hot_tub_heater_default_values(cfa, nbeds, hot_tub.heater_type)
        hot_tub.heater_load_units = default_heater_load_units
        hot_tub.heater_load_value = default_heater_load_value
        hot_tub.heater_load_value_isdefaulted = true
      end
      if hot_tub.heater_usage_multiplier.nil?
        hot_tub.heater_usage_multiplier = 1.0
        hot_tub.heater_usage_multiplier_isdefaulted = true
      end
      if hot_tub.heater_weekday_fractions.nil?
        hot_tub.heater_weekday_fractions = '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024'
        hot_tub.heater_weekday_fractions_isdefaulted = true
      end
      if hot_tub.heater_weekend_fractions.nil?
        hot_tub.heater_weekend_fractions = '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024'
        hot_tub.heater_weekend_fractions_isdefaulted = true
      end
      if hot_tub.heater_monthly_multipliers.nil?
        hot_tub.heater_monthly_multipliers = '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837'
        hot_tub.heater_monthly_multipliers_isdefaulted = true
      end
    end
  end

  def self.apply_plug_loads(hpxml, cfa, nbeds)
    hpxml.plug_loads.each do |plug_load|
      if plug_load.plug_load_type == HPXML::PlugLoadTypeOther
        default_annual_kwh, default_sens_frac, default_lat_frac = MiscLoads.get_residual_mels_default_values(cfa)
        if plug_load.kWh_per_year.nil?
          plug_load.kWh_per_year = default_annual_kwh
          plug_load.kWh_per_year_isdefaulted = true
        end
        if plug_load.frac_sensible.nil?
          plug_load.frac_sensible = default_sens_frac
          plug_load.frac_sensible_isdefaulted = true
        end
        if plug_load.frac_latent.nil?
          plug_load.frac_latent = default_lat_frac
          plug_load.frac_latent_isdefaulted = true
        end
        if plug_load.weekday_fractions.nil?
          plug_load.weekday_fractions = Schedule.PlugLoadsOtherWeekdayFractions
          plug_load.weekday_fractions_isdefaulted = true
        end
        if plug_load.weekend_fractions.nil?
          plug_load.weekend_fractions = Schedule.PlugLoadsOtherWeekendFractions
          plug_load.weekend_fractions_isdefaulted = true
        end
        if plug_load.monthly_multipliers.nil?
          plug_load.monthly_multipliers = Schedule.PlugLoadsOtherMonthlyMultipliers
          plug_load.monthly_multipliers_isdefaulted = true
        end
      elsif plug_load.plug_load_type == HPXML::PlugLoadTypeTelevision
        default_annual_kwh, default_sens_frac, default_lat_frac = MiscLoads.get_televisions_default_values(cfa, nbeds)
        if plug_load.kWh_per_year.nil?
          plug_load.kWh_per_year = default_annual_kwh
          plug_load.kWh_per_year_isdefaulted = true
        end
        if plug_load.frac_sensible.nil?
          plug_load.frac_sensible = default_sens_frac
          plug_load.frac_sensible_isdefaulted = true
        end
        if plug_load.frac_latent.nil?
          plug_load.frac_latent = default_lat_frac
          plug_load.frac_latent_isdefaulted = true
        end
        if plug_load.weekday_fractions.nil?
          plug_load.weekday_fractions = Schedule.PlugLoadsTVWeekdayFractions
          plug_load.weekday_fractions_isdefaulted = true
        end
        if plug_load.weekend_fractions.nil?
          plug_load.weekend_fractions = Schedule.PlugLoadsTVWeekendFractions
          plug_load.weekend_fractions_isdefaulted = true
        end
        if plug_load.monthly_multipliers.nil?
          plug_load.monthly_multipliers = Schedule.PlugLoadsTVMonthlyMultipliers
          plug_load.monthly_multipliers_isdefaulted = true
        end
      elsif plug_load.plug_load_type == HPXML::PlugLoadTypeElectricVehicleCharging
        default_annual_kwh = MiscLoads.get_electric_vehicle_charging_default_values
        if plug_load.kWh_per_year.nil?
          plug_load.kWh_per_year = default_annual_kwh
          plug_load.kWh_per_year_isdefaulted = true
        end
        if plug_load.frac_sensible.nil?
          plug_load.frac_sensible = 0.0
          plug_load.frac_sensible_isdefaulted = true
        end
        if plug_load.frac_latent.nil?
          plug_load.frac_latent = 0.0
          plug_load.frac_latent_isdefaulted = true
        end
        if plug_load.weekday_fractions.nil?
          plug_load.weekday_fractions = Schedule.PlugLoadsVehicleWeekdayFractions
          plug_load.weekday_fractions_isdefaulted = true
        end
        if plug_load.weekend_fractions.nil?
          plug_load.weekend_fractions = Schedule.PlugLoadsVehicleWeekendFractions
          plug_load.weekend_fractions_isdefaulted = true
        end
        if plug_load.monthly_multipliers.nil?
          plug_load.monthly_multipliers = Schedule.PlugLoadsVehicleMonthlyMultipliers
          plug_load.monthly_multipliers_isdefaulted = true
        end
      elsif plug_load.plug_load_type == HPXML::PlugLoadTypeWellPump
        default_annual_kwh = MiscLoads.get_well_pump_default_values(cfa, nbeds)
        if plug_load.kWh_per_year.nil?
          plug_load.kWh_per_year = default_annual_kwh
          plug_load.kWh_per_year_isdefaulted = true
        end
        if plug_load.frac_sensible.nil?
          plug_load.frac_sensible = 0.0
          plug_load.frac_sensible_isdefaulted = true
        end
        if plug_load.frac_latent.nil?
          plug_load.frac_latent = 0.0
          plug_load.frac_latent_isdefaulted = true
        end
        if plug_load.weekday_fractions.nil?
          plug_load.weekday_fractions = Schedule.PlugLoadsWellPumpWeekdayFractions
          plug_load.weekday_fractions_isdefaulted = true
        end
        if plug_load.weekend_fractions.nil?
          plug_load.weekend_fractions = Schedule.PlugLoadsWellPumpWeekendFractions
          plug_load.weekend_fractions_isdefaulted = true
        end
        if plug_load.monthly_multipliers.nil?
          plug_load.monthly_multipliers = Schedule.PlugLoadsWellPumpMonthlyMultipliers
          plug_load.monthly_multipliers_isdefaulted = true
        end
      end
      if plug_load.usage_multiplier.nil?
        plug_load.usage_multiplier = 1.0
        plug_load.usage_multiplier_isdefaulted = true
      end
    end
  end

  def self.apply_fuel_loads(hpxml, cfa, nbeds)
    hpxml.fuel_loads.each do |fuel_load|
      if fuel_load.fuel_load_type == HPXML::FuelLoadTypeGrill
        if fuel_load.therm_per_year.nil?
          fuel_load.therm_per_year = MiscLoads.get_gas_grill_default_values(cfa, nbeds)
          fuel_load.therm_per_year_isdefaulted = true
        end
        if fuel_load.frac_sensible.nil?
          fuel_load.frac_sensible = 0.0
          fuel_load.frac_sensible_isdefaulted = true
        end
        if fuel_load.frac_latent.nil?
          fuel_load.frac_latent = 0.0
          fuel_load.frac_latent_isdefaulted = true
        end
        if fuel_load.weekday_fractions.nil?
          fuel_load.weekday_fractions = Schedule.FuelLoadsGrillWeekdayFractions
          fuel_load.weekday_fractions_isdefaulted = true
        end
        if fuel_load.weekend_fractions.nil?
          fuel_load.weekend_fractions = Schedule.FuelLoadsGrillWeekendFractions
          fuel_load.weekend_fractions_isdefaulted = true
        end
        if fuel_load.monthly_multipliers.nil?
          fuel_load.monthly_multipliers = Schedule.FuelLoadsGrillMonthlyMultipliers
          fuel_load.monthly_multipliers_isdefaulted = true
        end
      elsif fuel_load.fuel_load_type == HPXML::FuelLoadTypeLighting
        if fuel_load.therm_per_year.nil?
          fuel_load.therm_per_year = MiscLoads.get_gas_lighting_default_values(cfa, nbeds)
          fuel_load.therm_per_year_isdefaulted = true
        end
        if fuel_load.frac_sensible.nil?
          fuel_load.frac_sensible = 0.0
          fuel_load.frac_sensible_isdefaulted = true
        end
        if fuel_load.frac_latent.nil?
          fuel_load.frac_latent = 0.0
          fuel_load.frac_latent_isdefaulted = true
        end
        if fuel_load.weekday_fractions.nil?
          fuel_load.weekday_fractions = Schedule.FuelLoadsLightingWeekdayFractions
          fuel_load.weekday_fractions_isdefaulted = true
        end
        if fuel_load.weekend_fractions.nil?
          fuel_load.weekend_fractions = Schedule.FuelLoadsLightingWeekendFractions
          fuel_load.weekend_fractions_isdefaulted = true
        end
        if fuel_load.monthly_multipliers.nil?
          fuel_load.monthly_multipliers = Schedule.FuelLoadsLightingMonthlyMultipliers
          fuel_load.monthly_multipliers_isdefaulted = true
        end
      elsif fuel_load.fuel_load_type == HPXML::FuelLoadTypeFireplace
        if fuel_load.therm_per_year.nil?
          fuel_load.therm_per_year = MiscLoads.get_gas_fireplace_default_values(cfa, nbeds)
          fuel_load.therm_per_year_isdefaulted = true
        end
        if fuel_load.frac_sensible.nil?
          fuel_load.frac_sensible = 0.5
          fuel_load.frac_sensible_isdefaulted = true
        end
        if fuel_load.frac_latent.nil?
          fuel_load.frac_latent = 0.1
          fuel_load.frac_latent_isdefaulted = true
        end
        if fuel_load.weekday_fractions.nil?
          fuel_load.weekday_fractions = Schedule.FuelLoadsFireplaceWeekdayFractions
          fuel_load.weekday_fractions_isdefaulted = true
        end
        if fuel_load.weekend_fractions.nil?
          fuel_load.weekend_fractions = Schedule.FuelLoadsFireplaceWeekendFractions
          fuel_load.weekend_fractions_isdefaulted = true
        end
        if fuel_load.monthly_multipliers.nil?
          fuel_load.monthly_multipliers = Schedule.FuelLoadsFireplaceMonthlyMultipliers
          fuel_load.monthly_multipliers_isdefaulted = true
        end
      end
      if fuel_load.usage_multiplier.nil?
        fuel_load.usage_multiplier = 1.0
        fuel_load.usage_multiplier_isdefaulted = true
      end
    end
  end

  def self.apply_hvac_sizing(hpxml, weather, cfa, nbeds)
    # Convert negative values (e.g., -1) to nil as appropriate
    hpxml.hvac_systems.each do |hvac_system|
      if hvac_system.respond_to?(:heating_capacity) && hvac_system.heating_capacity.to_f < 0
        hvac_system.heating_capacity = nil
      end
      if hvac_system.respond_to?(:cooling_capacity) && hvac_system.cooling_capacity.to_f < 0
        hvac_system.cooling_capacity = nil
      end
      if hvac_system.respond_to?(:heating_capacity_17F) && hvac_system.heating_capacity_17F.to_f < 0
        hvac_system.heating_capacity_17F = nil
      end
      if hvac_system.respond_to?(:backup_heating_capacity) && hvac_system.backup_heating_capacity.to_f < 0
        hvac_system.backup_heating_capacity = nil
      end
    end

    hvac_systems = HVAC.get_hpxml_hvac_systems(hpxml)

    # Calculate building design loads and equipment capacities/airflows
    bldg_design_loads, all_hvac_sizing_values = HVACSizing.calculate(weather, hpxml, cfa, nbeds, hvac_systems)

    hvacpl = hpxml.hvac_plant
    tol = 10 # Btuh

    # Assign heating design loads back to HPXML object
    hvacpl.hdl_total = bldg_design_loads.Heat_Tot.round
    hvacpl.hdl_walls = bldg_design_loads.Heat_Walls.round
    hvacpl.hdl_ceilings = bldg_design_loads.Heat_Ceilings.round
    hvacpl.hdl_roofs = bldg_design_loads.Heat_Roofs.round
    hvacpl.hdl_floors = bldg_design_loads.Heat_Floors.round
    hvacpl.hdl_slabs = bldg_design_loads.Heat_Slabs.round
    hvacpl.hdl_windows = bldg_design_loads.Heat_Windows.round
    hvacpl.hdl_skylights = bldg_design_loads.Heat_Skylights.round
    hvacpl.hdl_doors = bldg_design_loads.Heat_Doors.round
    hvacpl.hdl_infilvent = bldg_design_loads.Heat_InfilVent.round
    hvacpl.hdl_ducts = bldg_design_loads.Heat_Ducts.round
    hdl_sum = (hvacpl.hdl_walls + hvacpl.hdl_ceilings + hvacpl.hdl_roofs +
               hvacpl.hdl_floors + hvacpl.hdl_slabs + hvacpl.hdl_windows +
               hvacpl.hdl_skylights + hvacpl.hdl_doors + hvacpl.hdl_infilvent +
               hvacpl.hdl_ducts)
    if (hdl_sum - hvacpl.hdl_total).abs > tol
      fail 'Heating design loads do not sum to total.'
    end

    # Cooling sensible design loads back to HPXML object
    hvacpl.cdl_sens_total = bldg_design_loads.Cool_Sens.round
    hvacpl.cdl_sens_walls = bldg_design_loads.Cool_Walls.round
    hvacpl.cdl_sens_ceilings = bldg_design_loads.Cool_Ceilings.round
    hvacpl.cdl_sens_roofs = bldg_design_loads.Cool_Roofs.round
    hvacpl.cdl_sens_floors = bldg_design_loads.Cool_Floors.round
    hvacpl.cdl_sens_slabs = 0.0
    hvacpl.cdl_sens_windows = bldg_design_loads.Cool_Windows.round
    hvacpl.cdl_sens_skylights = bldg_design_loads.Cool_Skylights.round
    hvacpl.cdl_sens_doors = bldg_design_loads.Cool_Doors.round
    hvacpl.cdl_sens_infilvent = bldg_design_loads.Cool_Infil_Sens.round
    hvacpl.cdl_sens_ducts = bldg_design_loads.Cool_Ducts_Sens.round
    hvacpl.cdl_sens_intgains = bldg_design_loads.Cool_IntGains_Sens.round
    cdl_sens_sum = (hvacpl.cdl_sens_walls + hvacpl.cdl_sens_ceilings +
                    hvacpl.cdl_sens_roofs + hvacpl.cdl_sens_floors +
                    hvacpl.cdl_sens_slabs + hvacpl.cdl_sens_windows +
                    hvacpl.cdl_sens_skylights + hvacpl.cdl_sens_doors +
                    hvacpl.cdl_sens_infilvent + hvacpl.cdl_sens_ducts +
                    hvacpl.cdl_sens_intgains)
    if (cdl_sens_sum - hvacpl.cdl_sens_total).abs > tol
      fail 'Cooling sensible design loads do not sum to total.'
    end

    # Cooling latent design loads back to HPXML object
    hvacpl.cdl_lat_total = bldg_design_loads.Cool_Lat.round
    hvacpl.cdl_lat_ducts = bldg_design_loads.Cool_Ducts_Lat.round
    hvacpl.cdl_lat_infilvent = bldg_design_loads.Cool_Infil_Lat.round
    hvacpl.cdl_lat_intgains = bldg_design_loads.Cool_IntGains_Lat.round
    cdl_lat_sum = (hvacpl.cdl_lat_ducts + hvacpl.cdl_lat_infilvent +
                   hvacpl.cdl_lat_intgains)
    if (cdl_lat_sum - hvacpl.cdl_lat_total).abs > tol
      fail 'Cooling latent design loads do not sum to total.'
    end

    # Assign sizing values back to HPXML objects
    all_hvac_sizing_values.each do |hvac_system, hvac_sizing_values|
      htg_sys = hvac_system[:heating]
      clg_sys = hvac_system[:cooling]

      # Heating system
      if not htg_sys.nil?

        # Heating capacities
        if htg_sys.heating_capacity.nil? || ((htg_sys.heating_capacity - hvac_sizing_values.Heat_Capacity).abs >= 1.0)
          # Heating capacity @ 17F
          if htg_sys.respond_to? :heating_capacity_17F
            if (not htg_sys.heating_capacity.nil?) && (not htg_sys.heating_capacity_17F.nil?)
              # Fixed value entered; scale w/ heating_capacity in case allow_increased_fixed_capacities=true
              htg_cap_17f = htg_sys.heating_capacity_17F * hvac_sizing_values.Heat_Capacity.round / htg_sys.heating_capacity
              if (htg_sys.heating_capacity_17F - htg_cap_17f).abs >= 1.0
                htg_sys.heating_capacity_17F = htg_cap_17f.round
                htg_sys.heating_capacity_17F_isdefaulted = true
              end
            else
              # Autosized
              # FUTURE: Calculate HeatingCapacity17F from heat_cap_ft_spec? Might be confusing
              # since user would not be able to replicate the results using this value, as the
              # default curves are non-linear.
            end
          end
          htg_sys.heating_capacity = hvac_sizing_values.Heat_Capacity.round
          htg_sys.heating_capacity_isdefaulted = true
        end
        if htg_sys.respond_to? :backup_heating_capacity
          if not htg_sys.backup_heating_fuel.nil? # If there is a backup heating source
            if htg_sys.backup_heating_capacity.nil? || ((htg_sys.backup_heating_capacity - hvac_sizing_values.Heat_Capacity_Supp).abs >= 1.0)
              htg_sys.backup_heating_capacity = hvac_sizing_values.Heat_Capacity_Supp.round
              htg_sys.backup_heating_capacity_isdefaulted = true
            end
          else
            htg_sys.backup_heating_capacity = 0.0
          end
        end

        # Heating airflow
        htg_sys.heating_airflow_cfm = hvac_sizing_values.Heat_Airflow.round
        htg_sys.heating_airflow_cfm_isdefaulted = true

        # Heating GSHP loop
        if htg_sys.is_a? HPXML::HeatPump
          htg_sys.additional_properties.GSHP_Loop_flow = hvac_sizing_values.GSHP_Loop_flow
          htg_sys.additional_properties.GSHP_Bore_Depth = hvac_sizing_values.GSHP_Bore_Depth
          htg_sys.additional_properties.GSHP_Bore_Holes = hvac_sizing_values.GSHP_Bore_Holes
          htg_sys.additional_properties.GSHP_G_Functions = hvac_sizing_values.GSHP_G_Functions
        end
      end

      # Cooling system
      next unless not clg_sys.nil?

      # Cooling capacities
      if clg_sys.cooling_capacity.nil? || ((clg_sys.cooling_capacity - hvac_sizing_values.Cool_Capacity).abs >= 1.0)
        clg_sys.cooling_capacity = hvac_sizing_values.Cool_Capacity.round
        clg_sys.cooling_capacity_isdefaulted = true
      end
      clg_sys.additional_properties.cooling_capacity_sensible = hvac_sizing_values.Cool_Capacity_Sens.round

      # Cooling airflow
      clg_sys.cooling_airflow_cfm = hvac_sizing_values.Cool_Airflow.round
      clg_sys.cooling_airflow_cfm_isdefaulted = true
    end
  end

  def self.get_azimuth_from_orientation(orientation)
    return if orientation.nil?

    if orientation == HPXML::OrientationNorth
      return 0
    elsif orientation == HPXML::OrientationNortheast
      return 45
    elsif orientation == HPXML::OrientationEast
      return 90
    elsif orientation == HPXML::OrientationSoutheast
      return 135
    elsif orientation == HPXML::OrientationSouth
      return 180
    elsif orientation == HPXML::OrientationSouthwest
      return 225
    elsif orientation == HPXML::OrientationWest
      return 270
    elsif orientation == HPXML::OrientationNorthwest
      return 315
    end

    fail "Unexpected orientation: #{orientation}."
  end

  def self.get_orientation_from_azimuth(azimuth)
    return if azimuth.nil?

    if (azimuth >= 0.0 - 22.5 + 360.0) || (azimuth < 0.0 + 22.5)
      return HPXML::OrientationNorth
    elsif (azimuth >= 45.0 - 22.5) && (azimuth < 45.0 + 22.5)
      return HPXML::OrientationNortheast
    elsif (azimuth >= 90.0 - 22.5) && (azimuth < 90.0 + 22.5)
      return HPXML::OrientationEast
    elsif (azimuth >= 135.0 - 22.5) && (azimuth < 135.0 + 22.5)
      return HPXML::OrientationSoutheast
    elsif (azimuth >= 180.0 - 22.5) && (azimuth < 180.0 + 22.5)
      return HPXML::OrientationSouth
    elsif (azimuth >= 225.0 - 22.5) && (azimuth < 225.0 + 22.5)
      return HPXML::OrientationSouthwest
    elsif (azimuth >= 270.0 - 22.5) && (azimuth < 270.0 + 22.5)
      return HPXML::OrientationWest
    elsif (azimuth >= 315.0 - 22.5) && (azimuth < 315.0 + 22.5)
      return HPXML::OrientationNorthwest
    end
  end
end
