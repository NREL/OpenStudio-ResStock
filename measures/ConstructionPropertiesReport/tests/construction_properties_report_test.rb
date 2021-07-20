# frozen_string_literal: true

require_relative '../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ConstructionPropertiesReportTest < MiniTest::Test
  def test_thermal_mass
    thermal_capacitances = {
      'floor_fin_ins_unfin_attic' => 1480, # unfinished attic floor
      # "floor_fin_ins_unfin"=>0, # interzonal or cantilevered floor
      'floor_fin_unins_fin' => 4018, # floor between 1st/2nd story living spaces
      # "floor_unfin_unins_unfin"=>0, # floor between garage and attic
      # "floor_fnd_grnd_fin_b"=>0, # finished basement floor
      # "floor_fnd_grnd_unfin_b"=>0, # unfinished basement floor
      'floor_fnd_grnd_fin_slab' => 17814, # finished slab
      # "floor_fnd_grnd_unfin_slab"=>0, # garage slab
      # "floor_unfin_b_ins_fin"=>0, # unfinished basement ceiling
      # "floor_cs_ins_fin"=>0, # crawlspace ceiling
      # "floor_pb_ins_fin"=>0, # pier beam ceiling
      # "floor_fnd_grnd_cs"=>0, # crawlspace floor
      # "roof_unfin_unins_ext"=>0, # garage roof
      'roof_unfin_ins_ext' => 3712, # unfinished attic roof
      # "roof_fin_ins_ext"=>0, # finished attic roof
      'wall_ext_ins_fin' => 7023, # living exterior wall
      # "wall_ext_ins_unfin"=>0, # attic gable wall under insulated roof
      'wall_ext_unins_unfin' => 216, # garage exterior wall or attic gable wall under uninsulated roof
      # "wall_fnd_grnd_fin_b"=>0, # finished basement wall
      # "wall_fnd_grnd_unfin_b"=>0, # unfinished basement wall
      # "wall_fnd_grnd_cs"=>0, # crawlspace wall
      # "wall_int_fin_ins_unfin"=>0, # interzonal wall
      'wall_int_fin_unins_fin' => 3245, # wall between two finished spaces
      # "wall_int_unfin_unins_unfin"=>0, # wall between two unfinished spaces
      # "living_space_footing_construction"=>0, # living space footing construction
      # "garage_space_footing_construction"=>0, # garage space footing construction
      'door' => 51, # exterior door
      'res_furniture_construction_living_space' => 4407, # furniture in living
      'res_furniture_construction_living_space_story_2' => 4407, # furniture in living, second floor
      # "res_furniture_construction_unfinished_basement_space"=>0, # furniture in unfinished basement
      # "res_furniture_construction_finished_basement_space"=>0, # furniture in finished basement
      # "res_furniture_construction_garage_space"=>0, # furniture in garage
      'living_zone' => 557, # living space air
      # "garage_zone"=>0, # garage space air
      # "unfinished_basement_zone"=>0, # unfinished basement space air
      # "finished_basement_zone"=>0, # finished basement space air
      # "crawl_zone"=>0, # crawl space air
      'unfinished_attic_zone' => 132 # unfinished attic space air
    }
    _test_thermal_capacitances('SFD_Successful_EnergyPlus_Run_TMY.osm', thermal_capacitances)
  end

  def test_ua
    uas = {
      'floor_fin_ins_unfin_attic' => 18, # unfinished attic floor
      # "floor_fin_ins_unfin"=>0, # interzonal or cantilevered floor
      'floor_fin_unins_fin' => 100, # floor between 1st/2nd story living spaces
      # "floor_unfin_unins_unfin"=>0, # floor between garage and attic
      # "floor_fnd_grnd_fin_b"=>0, # finished basement floor
      # "floor_fnd_grnd_unfin_b"=>0, # unfinished basement floor
      'floor_fnd_grnd_fin_slab' => 266, # finished slab
      # "floor_fnd_grnd_unfin_slab"=>0, # garage slab
      # "floor_unfin_b_ins_fin"=>0, # unfinished basement ceiling
      # "floor_cs_ins_fin"=>0, # crawlspace ceiling
      # "floor_pb_ins_fin"=>0, # pier beam ceiling
      # "floor_fnd_grnd_cs"=>0, # crawlspace floor
      # "roof_unfin_unins_ext"=>0, # garage roof
      'roof_unfin_ins_ext' => 421, # unfinished attic roof
      # "roof_fin_ins_ext"=>0, # finished attic roof
      'wall_ext_ins_fin' => 103, # living exterior wall
      # "wall_ext_ins_unfin"=>0, # attic gable wall under insulated roof
      'wall_ext_unins_unfin' => 26, # garage exterior wall or attic gable wall under uninsulated roof
      # "wall_fnd_grnd_fin_b"=>0, # finished basement wall
      # "wall_fnd_grnd_unfin_b"=>0, # unfinished basement wall
      # "wall_fnd_grnd_cs"=>0, # crawlspace wall
      # "wall_int_fin_ins_unfin"=>0, # interzonal wall
      'wall_int_fin_unins_fin' => 614, # wall between two finished spaces
      # "wall_int_unfin_unins_unfin"=>0, # wall between two unfinished spaces
      # "living_space_footing_construction"=>0, # living space footing construction
      # "garage_space_footing_construction"=>0, # garage space footing construction
      'door' => 2.6, # exterior door
      'res_furniture_construction_living_space' => 28, # furniture in living
      'res_furniture_construction_living_space_story_2' => 28, # furniture in living, second floor
      # "res_furniture_construction_unfinished_basement_space"=>0, # furniture in unfinished basement
      # "res_furniture_construction_finished_basement_space"=>0, # furniture in finished basement
      # "res_furniture_construction_garage_space"=>0 # furniture in garage
    }
    _test_uas('SFD_Successful_EnergyPlus_Run_TMY.osm', uas)
  end

  private

  def _test_thermal_capacitances(osm_file, thermal_capacitances)
    model = get_model(File.dirname(__FILE__), osm_file)

    # create an instance of the measure
    measure = ConstructionPropertiesReport.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # Check for correct thermal capacitance values
    thermal_capacitances.each do |name, thermal_capacitance|
      constr = nil
      area = nil
      zone = nil
      val = nil
      vol = nil
      model.getConstructions.each do |construction|
        next if OpenStudio::toUnderscoreCase(construction.name.to_s) != name

        constr = construction
      end
      model.getThermalZones.each do |thermal_zone|
        next if OpenStudio::toUnderscoreCase(thermal_zone.name.to_s) != name

        zone = thermal_zone
      end
      if not constr.nil?
        surface_area, name = measure.get_surface_area(model, constr)
        sub_surface_area, name = measure.get_sub_surface_area(model, constr)
        internal_mass_area, name = measure.get_internal_mass_area(model, constr)
        area = surface_area + sub_surface_area + internal_mass_area
      else
        vol = UnitConversions.convert(Geometry.get_zone_volume(zone, runner), 'ft^3', 'm^3')
        val = 1.004 * 1.225 # air specific heat and density
      end
      value = measure.get_thermal_capacitance(constr, area, val = val, vol = vol)
      assert(!value.nil?)
      assert_in_epsilon(thermal_capacitance, value, 0.05)
    end
  end

  def _test_uas(osm_file, uas)
    model = get_model(File.dirname(__FILE__), osm_file)

    # create an instance of the measure
    measure = ConstructionPropertiesReport.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # Check for correct construction property values
    uas.each do |constr_name, ua|
      constr = nil
      model.getConstructions.each do |construction|
        next if OpenStudio::toUnderscoreCase(construction.name.to_s) != constr_name

        constr = construction
      end
      assert(!constr.nil?)
      surface_area, name = measure.get_surface_area(model, constr)
      sub_surface_area, name = measure.get_sub_surface_area(model, constr)
      internal_mass_area, name = measure.get_internal_mass_area(model, constr)
      area = surface_area + sub_surface_area + internal_mass_area
      value = measure.get_ua(constr, area)
      assert(!value.nil?)
      assert_in_epsilon(ua, value, 0.05)
    end
  end
end
