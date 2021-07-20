# frozen_string_literal: true

require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
require_relative '../../HPXMLtoOpenStudio/resources/meta_measure'
require_relative '../../HPXMLtoOpenStudio/resources/hpxml'

class BuildResidentialHPXMLTest < MiniTest::Test
  def test_workflows
    require 'json'

    this_dir = File.dirname(__FILE__)

    test_dirs = [
      this_dir,
    ]

    test_base = true
    test_extra = true

    osws = []
    test_dirs.each do |test_dir|
      Dir["#{test_dir}/base*.osw"].sort.each do |osw|
        osws << File.absolute_path(osw) if test_base
      end
      Dir["#{test_dir}/extra*.osw"].sort.each do |osw|
        osws << File.absolute_path(osw) if test_extra
      end
    end

    workflow_dir = File.expand_path(File.join(File.dirname(__FILE__), '../../workflow/sample_files'))
    tests_dir = File.expand_path(File.join(File.dirname(__FILE__), '../../BuildResidentialHPXML/tests'))
    built_dir = File.join(tests_dir, 'built_residential_hpxml')
    unless Dir.exist?(built_dir)
      Dir.mkdir(built_dir)
    end

    puts "Running #{osws.size} OSW files..."
    measures = {}
    fail = false
    osws.each do |osw|
      puts "\nTesting #{File.basename(osw)}..."

      _setup(tests_dir)
      osw_hash = JSON.parse(File.read(osw))
      measures_dir = File.join(File.dirname(__FILE__), osw_hash['measure_paths'][0])
      osw_hash['steps'].each do |step|
        measures[step['measure_dir_name']] = [step['arguments']]
        model = OpenStudio::Model::Model.new
        runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

        # Apply measure
        success = apply_measures(measures_dir, measures, runner, model)

        # Report warnings/errors
        runner.result.stepWarnings.each do |s|
          puts "Warning: #{s}"
        end
        runner.result.stepErrors.each do |s|
          puts "Error: #{s}"
        end

        assert(success)

        if File.basename(osw).start_with? 'extra-'
          next # No corresponding sample file
        end

        # Compare the hpxml to the manually created one
        test_dir = File.basename(File.dirname(osw))
        hpxml_path = step['arguments']['hpxml_path']
        begin
          _check_hpxmls(workflow_dir, built_dir, test_dir, hpxml_path)
        rescue Exception => e
          puts "#{e}\n#{e.backtrace.join('\n')}"
          fail = true
        end
      end
      break if fail # FIXME: Temporary
    end

    assert false if fail
  end

  def test_invalid_workflows
    require 'json'

    this_dir = File.dirname(__FILE__)

    tests_dir = File.expand_path(File.join(File.dirname(__FILE__), '../../BuildResidentialHPXML/tests'))
    built_dir = File.join(tests_dir, 'built_residential_hpxml')
    unless Dir.exist?(built_dir)
      Dir.mkdir(built_dir)
    end

    expected_warning_msgs = {
      'non-electric-heat-pump-water-heater.osw' => 'water_heater_type=heat pump water heater and water_heater_fuel_type=natural gas',
      'single-family-detached-slab-non-zero-foundation-height.osw' => 'geometry_unit_type=single-family detached and geometry_foundation_type=SlabOnGrade and geometry_foundation_height=8.0',
      'multifamily-bottom-slab-non-zero-foundation-height.osw' => 'geometry_unit_type=apartment unit and geometry_level=Bottom and geometry_foundation_type=SlabOnGrade and geometry_foundation_height=8.0',
      'slab-non-zero-foundation-height-above-grade.osw' => 'geometry_foundation_type=SlabOnGrade and geometry_foundation_height_above_grade=1.0',
      'second-heating-system-serves-majority-heat.osw' => 'heating_system_type_2=Fireplace and heating_system_fraction_heat_load_served_2=0.6',
      'vented-crawlspace-with-wall-and-ceiling-insulation.osw' => 'geometry_foundation_type=VentedCrawlspace and foundation_wall_insulation_r=8.9 and foundation_wall_assembly_r=false and floor_assembly_r=10.0',
      'unvented-crawlspace-with-wall-and-ceiling-insulation.osw' => 'geometry_foundation_type=UnventedCrawlspace and foundation_wall_insulation_r=8.9 and foundation_wall_assembly_r=false and floor_assembly_r=10.0',
      'unconditioned-basement-with-wall-and-ceiling-insulation.osw' => 'geometry_foundation_type=UnconditionedBasement and foundation_wall_insulation_r=8.9 and foundation_wall_assembly_r=false and floor_assembly_r=10.0',
      'vented-attic-with-floor-and-roof-insulation.osw' => 'geometry_attic_type=VentedAttic and ceiling_assembly_r=39.3 and roof_assembly_r=10.0',
      'unvented-attic-with-floor-and-roof-insulation.osw' => 'geometry_attic_type=UnventedAttic and ceiling_assembly_r=39.3 and roof_assembly_r=10.0',
      'conditioned-basement-with-ceiling-insulation.osw' => 'geometry_foundation_type=ConditionedBasement and floor_assembly_r=10.0',
      'conditioned-attic-with-floor-insulation.osw' => 'geometry_attic_type=ConditionedAttic and ceiling_assembly_r=39.3',
      'multipliers-without-tv-plug-loads.osw' => 'plug_loads_television_annual_kwh=0.0 and plug_loads_television_usage_multiplier=1.0',
      'multipliers-without-other-plug-loads.osw' => 'plug_loads_other_annual_kwh=0.0 and plug_loads_other_usage_multiplier=1.0',
      'multipliers-without-well-pump-plug-loads.osw' => 'plug_loads_well_pump_annual_kwh=0.0 and plug_loads_well_pump_usage_multiplier=1.0',
      'multipliers-without-vehicle-plug-loads.osw' => 'plug_loads_vehicle_annual_kwh=0.0 and plug_loads_vehicle_usage_multiplier=1.0',
      'multipliers-without-fuel-loads.osw' => 'fuel_loads_grill_present=false and fuel_loads_grill_usage_multiplier=1.0 and fuel_loads_lighting_present=false and fuel_loads_lighting_usage_multiplier=1.0 and fuel_loads_fireplace_present=false and fuel_loads_fireplace_usage_multiplier=1.0'
    }

    expected_error_msgs = {
      'heating-system-and-heat-pump.osw' => 'heating_system_type=Furnace and heat_pump_type=air-to-air',
      'cooling-system-and-heat-pump.osw' => 'cooling_system_type=central air conditioner and heat_pump_type=air-to-air',
      'non-integer-geometry-num-bathrooms.osw' => 'geometry_num_bathrooms=1.5',
      'non-integer-ceiling-fan-quantity.osw' => 'ceiling_fan_quantity=0.5',
      'single-family-detached-finished-basement-zero-foundation-height.osw' => 'geometry_unit_type=single-family detached and geometry_foundation_type=ConditionedBasement and geometry_foundation_height=0.0',
      'single-family-attached-ambient.osw' => 'geometry_unit_type=single-family attached and geometry_foundation_type=Ambient',
      'multifamily-bottom-crawlspace-zero-foundation-height.osw' => 'geometry_unit_type=apartment unit and geometry_level=Bottom and geometry_foundation_type=UnventedCrawlspace and geometry_foundation_height=0.0',
      'ducts-location-and-areas-not-same-type.osw' => 'ducts_supply_location=auto and ducts_supply_surface_area=150.0 and ducts_return_location=attic - unvented and ducts_return_surface_area=50.0',
      'second-heating-system-serves-total-heat-load.osw' => 'heating_system_type_2=Fireplace and heating_system_fraction_heat_load_served_2=1.0',
      'second-heating-system-but-no-primary-heating.osw' => 'heating_system_type=none and heat_pump_type=none and heating_system_type_2=Fireplace',
      'single-family-attached-no-building-orientation.osw' => 'geometry_unit_type=single-family attached and geometry_building_num_units=false and geometry_horizontal_location=false',
      'multifamily-no-building-orientation.osw' => 'geometry_unit_type=apartment unit and geometry_building_num_units=false and geometry_level=false and geometry_horizontal_location=false',
      'dhw-indirect-without-boiler.osw' => 'water_heater_type=space-heating boiler with storage tank and heating_system_type=Furnace',
      'foundation-wall-insulation-greater-than-height.osw' => 'foundation_wall_insulation_distance_to_bottom=6.0 and geometry_foundation_height=4.0',
      'conditioned-attic-with-one-floor-above-grade.osw' => 'geometry_num_floors_above_grade=1 and geometry_attic_type=ConditionedAttic',
      'zero-number-of-bedrooms.osw' => 'geometry_num_bedrooms=0',
      'single-family-detached-with-shared-system.osw' => 'geometry_unit_type=single-family detached and heating_system_type=Shared Boiler w/ Baseboard',
      'hvac-seasons-incomplete-heating-season.osw' => 'season_heating_begin_month=true and season_heating_begin_day_of_month=false and season_heating_end_month=true and seasons_heating_end_day_of_month=false',
      'hvac-seasons-incomplete-cooling-season.osw' => 'season_cooling_begin_month=false and season_cooling_begin_day_of_month=true and season_cooling_end_month=false and season_cooling_end_day_of_month=true',
      'schedules-vacancy-incomplete.osw' => 'schedules_vacancy_begin_month=true and schedules_vacancy_begin_day_of_month=false and schedules_vacancy_end_month=true and schedules_vacancy_end_day_of_month=false',
      'schedules-vacancy-invalid.osw' => 'Vacancy Period End Day of Month (31) must be one of: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30.'
    }

    measures = {}
    Dir["#{this_dir}/invalid_files/*.osw"].sort.each do |osw|
      puts "\nTesting #{File.basename(osw)}..."

      _setup(this_dir)
      osw_hash = JSON.parse(File.read(osw))
      measures_dir = File.join(File.dirname(__FILE__), osw_hash['measure_paths'][0])
      osw_hash['steps'].each do |step|
        measures[step['measure_dir_name']] = [step['arguments']]
        model = OpenStudio::Model::Model.new
        runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

        # Apply measure
        success = apply_measures(measures_dir, measures, runner, model)

        # Report warnings/errors
        if Gem::Specification::find_all_by_name('nokogiri').any?
          assert(runner.result.stepWarnings.length > 0 || runner.result.stepErrors.length > 0)
        else
          assert(runner.result.stepWarnings.length > 1 || runner.result.stepErrors.length > 0)
        end
        runner.result.stepWarnings.each do |s|
          next if s.include? 'nokogiri'

          puts "Warning: #{s}"
          assert_equal(s, expected_warning_msgs[File.basename(osw)])
        end
        runner.result.stepErrors.each do |s|
          puts "Error: #{s}"
          assert_equal(s, expected_error_msgs[File.basename(osw)])
        end

        if expected_error_msgs.include? File.basename(osw)
          assert(!success)
        else
          assert(success)
        end
      end
    end
  end

  private

  def _check_hpxmls(workflow_dir, built_dir, test_dir, hpxml_path)
    if test_dir == 'tests'
      test_dir = ''
    end

    hpxml_path = {
      'Rakefile' => File.join(workflow_dir, test_dir, File.basename(hpxml_path)),
      'BuildResidentialHPXML' => File.join(built_dir, File.basename(hpxml_path))
    }

    hpxml_objs = {
      'BuildResidentialHPXML' => HPXML.new(hpxml_path: hpxml_path['BuildResidentialHPXML']),
      'Rakefile' => HPXML.new(hpxml_path: hpxml_path['Rakefile'])
    }

    hpxml_objs.each do |version, hpxml|
      # Sort elements so we can diff them
      hpxml.neighbor_buildings.sort_by! { |neighbor_building| neighbor_building.azimuth }
      hpxml.roofs.sort_by! { |roof| roof.area }
      hpxml.walls.sort_by! { |wall| [wall.exterior_adjacent_to, wall.insulation_assembly_r_value, wall.area] }
      hpxml.foundation_walls.sort_by! { |foundation_wall| foundation_wall.area }
      hpxml.rim_joists.sort_by! { |rim_joist| [rim_joist.exterior_adjacent_to, rim_joist.insulation_assembly_r_value, rim_joist.area] }
      hpxml.frame_floors.sort_by! { |frame_floor| [frame_floor.insulation_assembly_r_value, frame_floor.area] }
      hpxml.slabs.sort_by! { |slab| slab.area }
      hpxml.windows.sort_by! { |window| [window.azimuth, window.area] }
      hpxml.plug_loads.sort_by! { |plug_load| [plug_load.plug_load_type, plug_load.kWh_per_year] }

      # Ignore elements that we aren't going to diff
      hpxml.header.xml_type = nil
      hpxml.header.xml_generated_by = nil
      hpxml.header.created_date_and_time = Time.new(2000, 1, 1).strftime('%Y-%m-%dT%H:%M:%S%:z')
      hpxml.header.schedules_path = nil
      hpxml.site.fuels = [] # Not used by model
      hpxml.climate_and_risk_zones.weather_station_name = nil
      hpxml.building_construction.conditioned_building_volume = nil
      hpxml.building_construction.average_ceiling_height = nil # Comparing conditioned volume instead
      hpxml.air_infiltration_measurements[0].infiltration_volume = nil
      hpxml.foundations.clear
      hpxml.attics.clear
      hpxml.foundation_walls.each do |foundation_wall|
        foundation_wall.interior_finish_type = nil
        foundation_wall.length = nil
        foundation_wall.area = nil
        foundation_wall.insulation_interior_distance_to_top = nil
        foundation_wall.insulation_interior_distance_to_bottom = nil
        next if foundation_wall.insulation_assembly_r_value.nil?

        foundation_wall.insulation_assembly_r_value = foundation_wall.insulation_assembly_r_value.round(2)
      end
      if hpxml.rim_joists.length > 0
        (0...hpxml.rim_joists.length).to_a.reverse.each do |i|
          next unless [HPXML::LocationLivingSpace].include? hpxml.rim_joists[i].interior_adjacent_to

          hpxml.rim_joists.delete_at(i)
        end
      end
      hpxml.rim_joists.each do |rim_joist|
        rim_joist.area = rim_joist.area.round
        rim_joist.insulation_assembly_r_value = rim_joist.insulation_assembly_r_value.round(2)
        rim_joist.solar_absorptance = nil
        rim_joist.emittance = nil
        rim_joist.color = nil
      end
      hpxml.frame_floors.each do |frame_floor|
        frame_floor.interior_finish_type = nil
      end
      hpxml.roofs.each do |roof|
        roof.azimuth = nil
        roof.radiant_barrier = nil
        roof.solar_absorptance = nil
        roof.emittance = nil
        roof.roof_color = nil
        roof.interior_finish_type = nil
      end
      hpxml.walls.each do |wall|
        wall.azimuth = nil
        wall.solar_absorptance = nil
        wall.emittance = nil
        wall.color = nil
        wall.interior_finish_type = nil
        next if wall.exterior_adjacent_to != HPXML::LocationOutside
        next unless [HPXML::LocationAtticUnvented, HPXML::LocationAtticVented].include? wall.interior_adjacent_to

        wall.area = nil # TODO: Attic gable wall areas
      end
      hpxml.windows.each do |window|
        window.area = window.area.round
        window.overhangs_distance_to_bottom_of_window = nil # TODO: Height of windows
      end
      hpxml.doors.each do |door|
        door.azimuth = nil # Not important
        if door.id.include?('Garage')
          door.delete
        end
      end
      hpxml.heating_systems.each do |heating_system|
        heating_system.electric_auxiliary_energy = nil # Detailed input not offered
        heating_system.fan_watts = nil # Detailed input not offered
        heating_system.fan_watts_per_cfm = nil # Detailed input not offered
        heating_system.shared_loop_watts = nil # Always defaulted
        heating_system.fan_coil_watts = nil # Always defaulted
        unless hpxml_objs['Rakefile'].heating_systems[0].year_installed.nil?
          heating_system.heating_efficiency_afue = nil
          heating_system.year_installed = nil
        end
      end
      hpxml.cooling_systems.each do |cooling_system|
        cooling_system.fan_watts_per_cfm = nil # Detailed input not offered
        unless hpxml_objs['Rakefile'].cooling_systems[0].year_installed.nil?
          cooling_system.cooling_efficiency_seer = nil
          cooling_system.year_installed = nil
        end
      end
      hpxml.heat_pumps.each do |heat_pump|
        heat_pump.fan_watts_per_cfm = nil # Detailed input not offered
        heat_pump.pump_watts_per_ton = nil # Detailed input not offered
        next if heat_pump.backup_heating_efficiency_afue.nil?

        # These are treated the same in the model, so allow AFUE/percent comparison
        heat_pump.backup_heating_efficiency_percent = heat_pump.backup_heating_efficiency_afue
        heat_pump.backup_heating_efficiency_afue = nil
      end
      hpxml.ventilation_fans.each do |ventilation_fan|
        next unless ventilation_fan.used_for_whole_building_ventilation
        next if ventilation_fan.tested_flow_rate.nil?

        # These are treated the same in the model, so allow tested/rated comparison
        ventilation_fan.rated_flow_rate = ventilation_fan.tested_flow_rate
        ventilation_fan.tested_flow_rate = nil
      end
      hpxml.hvac_controls.each do |hvac_control|
        hvac_control.control_type = nil # Not used by model
      end
      if hpxml.hvac_distributions.length > 0
        (2..hpxml.hvac_distributions[0].ducts.length).to_a.reverse.each do |i|
          hpxml.hvac_distributions[0].ducts.delete_at(i) # Only compare first two ducts
        end
      end
      hpxml.water_heating_systems.each do |wh|
        wh.performance_adjustment = nil # Detailed input not exposed
        wh.heating_capacity = nil # Detailed input not exposed
        unless hpxml_objs['Rakefile'].water_heating_systems[0].year_installed.nil?
          wh.energy_factor = nil
          wh.year_installed = nil
        end
      end
      if hpxml.refrigerators.length > 0
        (2..hpxml.refrigerators.length).to_a.reverse.each do |i|
          hpxml.refrigerators.delete_at(i) # Only compare first two refrigerators
        end
      end
      hpxml.refrigerators.each do |refrigerator|
        refrigerator.primary_indicator = nil
        refrigerator.adjusted_annual_kwh = nil
        refrigerator.weekday_fractions = nil
        refrigerator.weekend_fractions = nil
        refrigerator.monthly_multipliers = nil
      end
      if hpxml.freezers.length > 0
        (1..hpxml.freezers.length).to_a.reverse.each do |i|
          hpxml.freezers.delete_at(i) # Only compare first freezer
        end
      end
      hpxml.freezers.each do |freezer|
        freezer.weekday_fractions = nil
        freezer.weekend_fractions = nil
        freezer.monthly_multipliers = nil
      end
      hpxml.cooking_ranges.each do |cooking_range|
        cooking_range.weekday_fractions = nil
        cooking_range.weekend_fractions = nil
        cooking_range.monthly_multipliers = nil
      end
      hpxml.pools.each do |pool|
        pool.pump_weekday_fractions = nil
        pool.pump_weekend_fractions = nil
        pool.pump_monthly_multipliers = nil
        pool.heater_weekday_fractions = nil
        pool.heater_weekend_fractions = nil
        pool.heater_monthly_multipliers = nil
      end
      hpxml.hot_tubs.each do |hot_tub|
        hot_tub.pump_weekday_fractions = nil
        hot_tub.pump_weekend_fractions = nil
        hot_tub.pump_monthly_multipliers = nil
        hot_tub.heater_weekday_fractions = nil
        hot_tub.heater_weekend_fractions = nil
        hot_tub.heater_monthly_multipliers = nil
      end
      hpxml.lighting.interior_weekday_fractions = nil
      hpxml.lighting.interior_weekend_fractions = nil
      hpxml.lighting.interior_monthly_multipliers = nil
      hpxml.lighting.exterior_weekday_fractions = nil
      hpxml.lighting.exterior_weekend_fractions = nil
      hpxml.lighting.exterior_monthly_multipliers = nil
      hpxml.lighting.garage_weekday_fractions = nil
      hpxml.lighting.garage_weekend_fractions = nil
      hpxml.lighting.garage_monthly_multipliers = nil
      hpxml.lighting.holiday_weekday_fractions = nil
      hpxml.lighting.holiday_weekend_fractions = nil
      hpxml.plug_loads.each do |plug_load|
        plug_load.weekday_fractions = nil
        plug_load.weekend_fractions = nil
        plug_load.monthly_multipliers = nil
      end
      hpxml.fuel_loads.each do |fuel_load|
        fuel_load.weekday_fractions = nil
        fuel_load.weekend_fractions = nil
        fuel_load.monthly_multipliers = nil
      end
      hpxml.pv_systems.each do |pv_system|
        pv_system.year_modules_manufactured = nil
      end
      hpxml.collapse_enclosure_surfaces()

      # Round values
      (hpxml.roofs + hpxml.rim_joists + hpxml.walls + hpxml.foundation_walls + hpxml.frame_floors + hpxml.slabs).each do |surface|
        next if surface.area.nil?

        surface.area = surface.area.round
      end
      hpxml.slabs.each do |slab|
        slab.exposed_perimeter = slab.exposed_perimeter.round
      end

      # Replace IDs/IDREFs with blank strings
      HPXML::HPXML_ATTRS.each do |attr|
        hpxml_obj = hpxml.send(attr)
        next unless hpxml_obj.is_a? HPXML::BaseArrayElement

        hpxml_obj.each do |obj|
          obj.class::ATTRS.each do |obj_attr|
            next unless obj_attr.to_s.end_with?('id') || obj_attr.to_s.end_with?('_idref')

            obj.send(obj_attr.to_s + '=', '')
          end
        end
      end
    end

    rakefile_doc = hpxml_objs['Rakefile'].to_oga()
    measure_doc = hpxml_objs['BuildResidentialHPXML'].to_oga()

    # Write files for inspection?
    if rakefile_doc.to_xml != measure_doc.to_xml
      rakefile_path = File.join(File.dirname(__FILE__), 'test_rakefile.xml')
      XMLHelper.write_file(rakefile_doc, rakefile_path)
      measure_path = File.join(File.dirname(__FILE__), 'test_measure.xml')
      XMLHelper.write_file(measure_doc, measure_path)
      flunk "ERROR: HPXML files don't match. Wrote #{rakefile_path} and #{measure_path} for inspection."
    end
  end

  def _setup(this_dir)
    rundir = File.join(this_dir, 'run')
    _rm_path(rundir)
    Dir.mkdir(rundir)
  end

  def _rm_path(path)
    if Dir.exist?(path)
      FileUtils.rm_r(path)
    end
    while true
      break if not Dir.exist?(path)

      sleep(0.01)
    end
  end
end
