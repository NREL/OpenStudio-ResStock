# frozen_string_literal: true

require_relative '../../../../test/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ProcessHVACSizingTest < MiniTest::Test
  def test_loads_2story_finished_basement_garage_finished_attic
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_2story_FB_GRG_FA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_loads_2story_finished_basement_garage_finished_attic_ducts_in_fininshed_basement
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_2story_FB_GRG_FA_ASHP_DuctsInFB.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_loads_2story_unfinished_basement_garage_finished_attic
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_2story_UB_GRG_FA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_loads_2story_unfinished_basement_garage_finished_attic_ducts_in_unfinished_basement
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_2story_UB_GRG_FA_ASHP_DuctsInUB.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_loads_2story_crawlspace_garage_finished_attic
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_2story_CS_GRG_FA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_loads_2story_crawlspace_garage_finished_attic_skylights
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_2story_CS_GRG_FA_Skylights.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_loads_2story_crawlspace_garage_flat_roof_skylights
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_2story_CS_GRG_FlatRoof_Skylights.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_loads_2story_crawlspace_garage_finished_attic_ducts_in_crawl
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_2story_CS_GRG_FA_ASHP_DuctsInCS.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_loads_2story_crawlspace_garage_finished_attic_ducts_in_living
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_2story_CS_GRG_FA_ASHP_DuctsInLiv.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_loads_2story_crawlspace_garage_finished_attic_ducts_in_garage
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_2story_CS_GRG_FA_ASHP_DuctsInGRG.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_loads_2story_slab_garage_finished_attic
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_2story_S_GRG_FA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_loads_1story_slab_unfinished_attic_vented
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_1story_S_UA_Vented.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, false)
  end

  def test_loads_1story_slab_unfinished_attic_unvented_roof_ins
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_1story_S_UA_Unvented_InsRoof.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, false)
  end

  def test_loads_1story_slab_unfinished_attic_unvented_no_overhangs_no_interior_shading_no_mech_vent
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_1story_S_UA_Unvented_NoOverhangs_NoIntShading_NoMechVent.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, false)
  end

  def test_loads_1story_slab_unfinished_attic_unvented_no_overhangs_no_interior_shading_supply_mech_vent
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_1story_S_UA_Unvented_NoOverhangs_NoIntShading_SupplyMechVent.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, false)
  end

  def test_loads_1story_slab_unfinished_attic_unvented_no_overhangs_no_interior_shading_erv
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_1story_S_UA_Unvented_NoOverhangs_NoIntShading_ERV.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, false)
  end

  def test_loads_1story_slab_unfinished_attic_unvented_no_overhangs_no_interior_shading_hrv
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_1story_S_UA_Unvented_NoOverhangs_NoIntShading_HRV.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, false)
  end

  def test_loads_1story_slab_unfinished_attic_vented_darkextfin
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_1story_S_UA_Vented_ExtFinDark.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, false)
  end

  def test_loads_1story_pierbeam_unfinished_attic_vented
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_1story_PB_UA_Vented.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, false)
  end

  def test_loads_1story_pierbeam_unfinished_attic_vented_ducts_in_pierbeam
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_1story_PB_UA_Vented_ASHP_DuctsInPB.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, false)
  end

  def test_loads_1story_pierbeam_unfinished_attic_vented_ducts_in_unfinished_attic
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Load_1story_PB_UA_Vented_ASHP_DuctsInUA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, false)
  end

  def test_loads_single_family_attached
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFA_HVACSizing_Load_4units_1story_FB_UA.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, false)
  end

  def test_loads_multifamily
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('MF_HVACSizing_Load_8units_1story_UB.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, false)
  end

  def test_equip_ASHP_one_speed_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_ASHP1_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_ASHP_one_speed_autosize_min_temp
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_ASHP1_Autosize_MinTemp.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_ASHP_one_speed_autosize_for_max_load_min_temp
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_ASHP1_AutosizeForMaxLoad_MinTemp.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_ASHP_one_speed_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_ASHP1_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_ASHP_two_speed_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_ASHP2_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_ASHP_two_speed_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_ASHP2_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_ASHP_variable_speed_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_ASHPV_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_ASHP_variable_speed_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_ASHPV_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_GSHP_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_GSHP_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_GSHP_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_GSHP_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_electric_baseboard_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_BB_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_electric_baseboard_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_BB_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_electric_boiler_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_ElecBoiler_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_electric_boiler_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_ElecBoiler_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_gas_boiler_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_GasBoiler_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_gas_boiler_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_GasBoiler_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_unit_heater_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_UnitHeater_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_unit_heater_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_UnitHeater_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_unit_heater_fixedsize_with_fan
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_UnitHeater_Fixed_wFan.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_unit_heater_ac_one_speed_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_UnitHeater_AC1_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_unit_heater_ac_one_speed_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_UnitHeater_AC1_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_gas_furnace_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_GF_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_gas_furnace_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_GF_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_gas_furnace_and_ac_one_speed_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_GF_AC1_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_gas_furnace_and_ac_one_speed_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_GF_AC1_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_electric_furnace_and_ac_two_speed_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_EF_AC2_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_electric_furnace_and_ac_two_speed_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_EF_AC2_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_gas_furnace_and_ac_variable_speed_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_GF_ACV_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_gas_furnace_and_ac_variable_speed_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_GF_ACV_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_gas_furnace_and_room_air_conditioner_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_GF_RAC_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_gas_furnace_and_room_air_conditioner_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_GF_RAC_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_mshp_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_MSHP_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_ducted_mshp_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_MSHPDucted_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_mshp_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_MSHP_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_mshp_autosize_for_max_load
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_MSHP_AutosizeForMaxLoad.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_mshp_and_electric_baseboard_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_MSHP_BB_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_mshp_and_electric_baseboard_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_MSHP_BB_Fixed.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_dehumidifier_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_Dehumidifier_Auto_Miami.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_dehumidifier_fixedsize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = {}
    expected_values = {
    }
    _test_measure('SFD_HVACSizing_Equip_Dehumidifier_Fixed_Miami.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_central_system_boiler_baseboards_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = { 'DesignDay' => 2 }
    expected_values = {}
    _test_measure('SFA_HVACSizing_Equip_Central_System_Boiler_Baseboards_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_central_system_fan_coil_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = { 'DesignDay' => 2 }
    expected_values = {
    }
    _test_measure('SFA_HVACSizing_Equip_Central_System_Fan_Coil_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_equip_central_system_ptac_autosize
    args_hash = {}
    args_hash['show_debug_info'] = true
    expected_num_del_objects = {}
    expected_num_new_objects = { 'DesignDay' => 2 }
    expected_values = {
    }
    _test_measure('SFA_HVACSizing_Equip_Central_System_PTAC_Autosize.osm', args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, true)
  end

  def test_error_missing_geometry
    args_hash = {}
    result = _test_error(nil, args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'No building geometry has been defined.')
  end

  def test_error_missing_weather
    args_hash = {}
    result = _test_error('SFD_2000sqft_2story_FB_UA.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], 'Model has not been assigned a weather file.')
  end

  def test_error_missing_construction
    args_hash = {}
    result = _test_error('SFD_2000sqft_2story_FB_UA_Denver.osm', args_hash)
    assert_equal(result.errors.map { |x| x.logMessage }[0], "Construction not assigned to 'Surface 13'.")
  end

  private

  def _test_error(osm_file_or_model, args_hash)
    print_debug_info = false # set to true for more detailed output

    # create an instance of the measure
    measure = ProcessHVACSizing.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    model = get_model(File.dirname(__FILE__), osm_file_or_model)

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    if print_debug_info
      show_output(result)
    end

    # assert that it didn't run
    assert_equal('Fail', result.value.valueName)
    assert(result.errors.size == 1)

    return result
  end

  def _test_measure(osm_file_or_model, args_hash, expected_num_del_objects, expected_num_new_objects, expected_values, apply_volume_adj = false)
    # create an instance of the measure
    measure = ProcessHVACSizing.new

    # check for standard methods
    assert(!measure.name.empty?)
    assert(!measure.description.empty?)
    assert(!measure.modeler_description.empty?)

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    model = get_model(File.dirname(__FILE__), osm_file_or_model)

    # get the initial objects in the model
    initial_objects = get_objects(model)

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)

    # get the final objects in the model
    final_objects = get_objects(model)

    # get new and deleted objects
    obj_type_exclusions = []
    all_new_objects = get_object_additions(initial_objects, final_objects, obj_type_exclusions)
    all_del_objects = get_object_additions(final_objects, initial_objects, obj_type_exclusions)

    # check we have the expected number of new/deleted objects
    check_num_objects(all_new_objects, expected_num_new_objects, 'added')
    check_num_objects(all_del_objects, expected_num_del_objects, 'deleted')

    all_new_objects.each do |obj_type, new_objects|
      new_objects.each do |new_object|
        next if not new_object.respond_to?("to_#{obj_type}")

        new_object = new_object.public_send("to_#{obj_type}").get
      end
    end

    return model
  end
end
