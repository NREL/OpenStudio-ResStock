# frozen_string_literal: true

require 'openstudio'

require_relative '../measure.rb'
require_relative '../../../resources/hpxml-measures/HPXMLtoOpenStudio/resources/minitest_helper'

class UpgradeCostsTest < MiniTest::Test
  def test_SFD_1story_FB_UA_GRG_MSHP_FuelTanklessWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 196.0 + 96.0 * 2 + 429.0 + 292.0 + 525.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 196.0 + 429.0 + 166.0 * 2 + 96.0 * 2 + 18.0 + 192.0 + 292.0 + 525.0,
      'Wall Area, Below-Grade (ft^2)' => 292.0 + 525.0 + 196.0 + 429.0 + 96.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 2250.0 * 2,
      'Floor Area, Attic (ft^2)' => 2250.0,
      'Floor Area, Lighting (ft^2)' => 2250.0 * 2 + 12.0 * 24.0,
      'Roof Area (ft^2)' => 1338.0 + 101.0 * 2 + 1237.0 + 61.0,
      'Window Area (ft^2)' => 0.12 * (196.0 + 96.0 * 2 + 429.0 + 292.0 + 525.0 - 96.0 * 2),
      'Door Area (ft^2)' => 30.0,
      'Duct Unconditioned Surface Area (ft^2)' => 0.0, # excludes ducts in conditioned space
      'Size, Heating System (kBtu/h)' => 60.0, # hp, not backup
      'Size, Heat Pump Backup (kBtu/h)' => 100.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 0.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 180.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 157.5
    }
    _test_cost_multipliers('SFD_1story_FB_UA_GRG_MSHP_FuelTanklessWH.osw', cost_multipliers)
  end

  def test_SFD_1story_FB_UA_GRG_RoomAC_ElecBoiler_FuelTanklessWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 106.0 + 96.0 * 2 + 267.0 + 202.0 + 363.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 106.0 + 267.0 + 79.0 * 2 + 96.0 * 2 + 18.0 + 192.0 + 202.0 + 363.0,
      'Wall Area, Below-Grade (ft^2)' => 202.0 + 363.0 + 106.0 + 267.0 + 96.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 1000.0 * 2,
      'Floor Area, Attic (ft^2)' => 1000.0,
      'Floor Area, Lighting (ft^2)' => 1000.0 * 2 + 12.0 * 24.0,
      'Roof Area (ft^2)' => 640.0 + 101.0 * 2 + 599.0,
      'Window Area (ft^2)' => 0.12 * (106.0 + 96.0 * 2 + 267.0 + 202.0 + 363.0 - 96.0 * 2),
      'Door Area (ft^2)' => 40.0,
      'Duct Unconditioned Surface Area (ft^2)' => 0.0, # excludes ducts in conditioned space
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 36.0,
      'Size, Water Heater (gal)' => 0.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 117.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 108.9
    }
    _test_cost_multipliers('SFD_1story_FB_UA_GRG_RoomAC_ElecBoiler_FuelTanklessWH.osw', cost_multipliers)
  end

  def test_SFD_1story_UB_UA_ASHP2_HPWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 327.0 * 2 + 588.0 * 2,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 327.0 * 2 + 588.0 * 2 + 208.0 * 2,
      'Wall Area, Below-Grade (ft^2)' => 327.0 * 2 + 588.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 3000.0,
      'Floor Area, Attic (ft^2)' => 3000.0,
      'Floor Area, Lighting (ft^2)' => 3000.0,
      'Roof Area (ft^2)' => 1677.0 * 2,
      'Window Area (ft^2)' => 0.12 * (327.0 * 2 + 588.0 * 2),
      'Door Area (ft^2)' => 40.0,
      'Duct Unconditioned Surface Area (ft^2)' => (0.27 * 3000.0) + (0.05 * 3000.0),
      'Size, Heating System (kBtu/h)' => 60.0, # hp, not backup
      'Size, Heat Pump Backup (kBtu/h)' => 100.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 50.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 176.2
    }
    _test_cost_multipliers('SFD_1story_UB_UA_ASHP2_HPWH.osw', cost_multipliers)
  end

  def test_SFD_1story_UB_UA_GRG_ACV_FuelFurnace_HPWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 310.0 + 96.0 * 2 + 635.0 + 406.0 + 731.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 310.0 + 635.0 + 323.0 * 2 + 96.0 * 2 + 18.0 + 192.0 + 406.0 + 731.0,
      'Wall Area, Below-Grade (ft^2)' => 406.0 + 731.0 + 310.0 + 635.0 + 96.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 4500.0,
      'Floor Area, Attic (ft^2)' => 4500.0,
      'Floor Area, Lighting (ft^2)' => 4500.0 + 12.0 * 24.0,
      'Roof Area (ft^2)' => 2596.0 + 101.0 * 2 + 2471.0 + 85.0,
      'Window Area (ft^2)' => 0.12 * (310.0 + 96.0 * 2 + 635.0 + 406.0 + 731.0 - 96.0 * 2),
      'Door Area (ft^2)' => 20.0,
      'Duct Unconditioned Surface Area (ft^2)' => (0.27 * 4500.0) + (0.05 * 4500.0),
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 50.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 219.4
    }
    _test_cost_multipliers('SFD_1story_UB_UA_GRG_ACV_FuelFurnace_HPWH.osw', cost_multipliers)
  end

  def test_SFD_1story_UB_UA_GRG_ACV_FuelFurnace_PortableHeater_HPWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 310.0 + 96.0 * 2 + 635.0 + 406.0 + 731.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 310.0 + 635.0 + 323.0 * 2 + 96.0 * 2 + 18.0 + 192.0 + 406.0 + 731.0,
      'Wall Area, Below-Grade (ft^2)' => 406.0 + 731.0 + 310.0 + 635.0 + 96.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 4500.0,
      'Floor Area, Attic (ft^2)' => 4500.0,
      'Floor Area, Lighting (ft^2)' => 4500.0 + 12.0 * 24.0,
      'Roof Area (ft^2)' => 2596.0 + 101.0 * 2 + 2471.0 + 85.0,
      'Window Area (ft^2)' => 0.12 * (310.0 + 96.0 * 2 + 635.0 + 406.0 + 731.0 - 96.0 * 2),
      'Door Area (ft^2)' => 20.0,
      'Duct Unconditioned Surface Area (ft^2)' => (0.27 * 4500.0) + (0.05 * 4500.0),
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 20.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 50.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 219.4
    }
    _test_cost_multipliers('SFD_1story_UB_UA_GRG_ACV_FuelFurnace_PortableHeater_HPWH.osw', cost_multipliers)
  end

  def test_SFD_2story_CS_UA_AC2_FuelBoiler_FuelTankWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 189.0 * 4 + 339.0 * 4,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 189.0 * 4 + 339.0 * 4 + 69.0 * 2,
      'Wall Area, Below-Grade (ft^2)' => 94.0 * 2 + 170.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 1000.0 * 2,
      'Floor Area, Attic (ft^2)' => 1000.0,
      'Floor Area, Lighting (ft^2)' => 1000.0 * 2,
      'Roof Area (ft^2)' => 559.0 * 2,
      'Window Area (ft^2)' => 0.12 * (189.0 * 4 + 339.0 * 4),
      'Door Area (ft^2)' => 20.0,
      'Duct Unconditioned Surface Area (ft^2)' => (0.75 * 0.27 * (1000.0 * 2)) + (0.75 * 0.05 * 2 * (1000.0 * 2)),
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 40.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 101.8
    }
    _test_cost_multipliers('SFD_2story_CS_UA_AC2_FuelBoiler_FuelTankWH.osw', cost_multipliers)
  end

  def test_SFD_2story_CS_UA_GRG_ASHPV_FuelTanklessWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 135.0 + 96.0 * 4 + 320.0 * 2 + 231.0 * 2 + 416.0 * 2 + 327.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 135.0 + 320.0 * 2 + 231.0 * 2 + 416.0 * 2 + 327.0 + 96.0 * 4 + 104.0 * 2 + 192.0 + 18.0,
      'Wall Area, Below-Grade (ft^2)' => 115.0 + 208.0 + 67.0 + 160.0 + 48.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 1500.0 * 2,
      'Floor Area, Attic (ft^2)' => 1500.0 + 144.0,
      'Floor Area, Lighting (ft^2)' => 1500.0 * 2 + 12.0 * 24.0,
      'Roof Area (ft^2)' => 839.0 + 101.0 * 2 + 798.0,
      'Window Area (ft^2)' => 0.12 * (135.0 + 96.0 * 4 + 320.0 * 2 + 231.0 * 2 + 416.0 * 2 + 327.0 - 96.0 * 2),
      'Door Area (ft^2)' => 20.0,
      'Duct Unconditioned Surface Area (ft^2)' => (0.75 * 0.27 * (1500.0 * 2)) + (0.75 * 0.05 * 2 * (1500.0 * 2)),
      'Size, Heating System (kBtu/h)' => 60.0, # hp, not backup
      'Size, Heat Pump Backup (kBtu/h)' => 100.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 0.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 124.8
    }
    _test_cost_multipliers('SFD_2story_CS_UA_GRG_ASHPV_FuelTanklessWH.osw', cost_multipliers)
  end

  def test_SFD_2story_FB_UA_GRG_AC1_ElecBaseboard_FuelTankWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 139.0 + 96.0 * 4 + 326.0 * 2 + 235.0 * 2 + 422.0 * 2 + 331.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 139.0 + 326.0 * 2 + 235.0 * 2 + 422.0 * 2 + 331.0 + 96.0 * 4 + 107.0 * 2 + 192.0 + 18.0,
      'Wall Area, Below-Grade (ft^2)' => 235.0 + 422.0 + 139.0 + 326.0 + 96.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 1500.0 * 3,
      'Floor Area, Attic (ft^2)' => 1548.0 + 144.0,
      'Floor Area, Lighting (ft^2)' => 1500.0 * 3 + 12.0 * 24.0,
      'Roof Area (ft^2)' => 865.0 + 101.0 * 2 + 825.0,
      'Window Area (ft^2)' => 0.12 * (2819.59 - 96.0 * 2),
      'Door Area (ft^2)' => 20.0,
      'Duct Unconditioned Surface Area (ft^2)' => 0.0, # excludes ducts in conditioned space
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 40.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 140.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 126.6
    }
    _test_cost_multipliers('SFD_2story_FB_UA_GRG_AC1_ElecBaseboard_FuelTankWH.osw', cost_multipliers)
  end

  def test_SFD_2story_FB_UA_GRG_AC1_UnitHeater_FuelTankWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 139.0 + 96.0 * 4 + 326.0 * 2 + 235.0 * 2 + 422.0 * 2 + 331.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 139.0 + 326.0 * 2 + 235.0 * 2 + 422.0 * 2 + 331.0 + 96.0 * 4 + 107.0 * 2 + 192.0 + 18.0,
      'Wall Area, Below-Grade (ft^2)' => 235.0 + 422.0 + 139.0 + 326.0 + 96.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 1500.0 * 3,
      'Floor Area, Attic (ft^2)' => 1548.0 + 144.0,
      'Floor Area, Lighting (ft^2)' => 1500.0 * 3 + 12.0 * 24.0,
      'Roof Area (ft^2)' => 865.0 + 101.0 * 2 + 825.0,
      'Window Area (ft^2)' => 0.12 * (2819.59 - 96.0 * 2),
      'Door Area (ft^2)' => 20.0,
      'Duct Unconditioned Surface Area (ft^2)' => 0.0, # excludes ducts in conditioned space
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 40.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 140.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 126.6
    }
    _test_cost_multipliers('SFD_2story_FB_UA_GRG_AC1_UnitHeater_FuelTankWH.osw', cost_multipliers)
  end

  def test_SFD_2story_FB_UA_GRG_GSHP_ElecTanklessWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 139.0 + 96.0 * 4 + 326.0 * 2 + 235.0 * 2 + 422.0 * 2 + 331.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 139.0 + 326.0 * 2 + 235.0 * 2 + 422.0 * 2 + 331.0 + 96.0 * 4 + 107.0 * 2 + 192.0 + 18.0,
      'Wall Area, Below-Grade (ft^2)' => 235.0 + 422.0 + 139.0 + 326.0 + 96.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 1500.0 * 3,
      'Floor Area, Attic (ft^2)' => 1548.0 + 144.0,
      'Floor Area, Lighting (ft^2)' => 1500.0 * 3 + 12.0 * 24.0,
      'Roof Area (ft^2)' => 865.0 + 101.0 * 2 + 825.0,
      'Window Area (ft^2)' => 0.12 * (2819.59 - 96.0 * 2),
      'Door Area (ft^2)' => 30.0,
      'Duct Unconditioned Surface Area (ft^2)' => 0.0, # excludes ducts in conditioned space
      'Size, Heating System (kBtu/h)' => 60.0, # hp, not backup
      'Size, Heat Pump Backup (kBtu/h)' => 100.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 0.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 140.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 126.6
    }
    _test_cost_multipliers('SFD_2story_FB_UA_GRG_GSHP_ElecTanklessWH.osw', cost_multipliers)
  end

  def test_SFD_2story_PB_UA_ElecFurnace_ElecTankWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 189.0 * 4 + 339.0 * 4,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 189.0 * 4 + 339.0 * 4 + 69.0 * 2,
      'Wall Area, Below-Grade (ft^2)' => 0.0,
      'Floor Area, Conditioned (ft^2)' => 1000.0 * 2,
      'Floor Area, Attic (ft^2)' => 1000.0,
      'Floor Area, Lighting (ft^2)' => 1000.0 * 2,
      'Roof Area (ft^2)' => 559.0 * 2,
      'Window Area (ft^2)' => 0.12 * (189.0 * 4 + 339.0 * 4),
      'Door Area (ft^2)' => 40.0,
      'Duct Unconditioned Surface Area (ft^2)' => 555.0,
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 0.0,
      'Size, Water Heater (gal)' => 66.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 0.0
    }
    _test_cost_multipliers('SFD_2story_PB_UA_ElecFurnace_ElecTankWH.osw', cost_multipliers)
  end

  def test_SFD_2story_S_UA_GRG_ASHP1_FuelTanklessWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 135.0 + 96.0 * 4 + 320.0 * 2 + 231.0 * 2 + 416.0 * 2 + 327.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 135.0 + 320.0 * 2 + 231.0 * 2 + 416.0 * 2 + 327.0 + 96.0 * 4 + 104.0 * 2 + 18.0 + 192.0,
      'Wall Area, Below-Grade (ft^2)' => 0.0,
      'Floor Area, Conditioned (ft^2)' => 1500.0 * 2,
      'Floor Area, Attic (ft^2)' => 1500.0 + 144.0,
      'Floor Area, Lighting (ft^2)' => 1500.0 * 2 + 12.0 * 24.0,
      'Roof Area (ft^2)' => 839.0 + 101.0 * 2 + 798.0,
      'Window Area (ft^2)' => 0.12 * (135.0 + 96.0 * 4 + 320.0 * 2 + 231.0 * 2 + 416.0 * 2 + 327.0 - 96.0 * 2),
      'Door Area (ft^2)' => 40.0,
      'Duct Unconditioned Surface Area (ft^2)' => (0.75 * 0.27 * (1500.0 * 2)) + (0.75 * 0.05 * 2 * (1500.0 * 2)),
      'Size, Heating System (kBtu/h)' => 60.0, # hp, not backup
      'Size, Heat Pump Backup (kBtu/h)' => 100.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 0.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 138.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 0.0
    }
    _test_cost_multipliers('SFD_2story_S_UA_GRG_ASHP1_FuelTanklessWH.osw', cost_multipliers)
  end

  def test_SFD_2story_S_UA_GRG_ASHP1_Fireplace_FuelTanklessWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 135.0 + 96.0 * 4 + 320.0 * 2 + 231.0 * 2 + 416.0 * 2 + 327.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 135.0 + 320.0 * 2 + 231.0 * 2 + 416.0 * 2 + 327.0 + 96.0 * 4 + 104.0 * 2 + 18.0 + 192.0,
      'Wall Area, Below-Grade (ft^2)' => 0.0,
      'Floor Area, Conditioned (ft^2)' => 1500.0 * 2,
      'Floor Area, Attic (ft^2)' => 1500.0 + 144.0,
      'Floor Area, Lighting (ft^2)' => 1500.0 * 2 + 12.0 * 24.0,
      'Roof Area (ft^2)' => 839.0 + 101.0 * 2 + 798.0,
      'Window Area (ft^2)' => 0.12 * (135.0 + 96.0 * 4 + 320.0 * 2 + 231.0 * 2 + 416.0 * 2 + 327.0 - 96.0 * 2),
      'Door Area (ft^2)' => 40.0,
      'Duct Unconditioned Surface Area (ft^2)' => (0.75 * 0.27 * (1500.0 * 2)) + (0.75 * 0.05 * 2 * (1500.0 * 2)),
      'Size, Heating System (kBtu/h)' => 60.0, # hp, not backup
      'Size, Heat Pump Backup (kBtu/h)' => 100.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 15.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 0.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 138.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 0.0
    }
    _test_cost_multipliers('SFD_2story_S_UA_GRG_ASHP1_Fireplace_FuelTanklessWH.osw', cost_multipliers)
  end

  def test_SFD_2story_S_UA_GRG_ASHP1_Fireplace_FuelTanklessWH_ERV
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 135.0 + 96.0 * 4 + 320.0 * 2 + 231.0 * 2 + 416.0 * 2 + 327.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 135.0 + 320.0 * 2 + 231.0 * 2 + 416.0 * 2 + 327.0 + 96.0 * 4 + 104.0 * 2 + 18.0 + 192.0,
      'Wall Area, Below-Grade (ft^2)' => 0.0,
      'Floor Area, Conditioned (ft^2)' => 1500.0 * 2,
      'Floor Area, Attic (ft^2)' => 1500.0 + 144.0,
      'Floor Area, Lighting (ft^2)' => 1500.0 * 2 + 12.0 * 24.0,
      'Roof Area (ft^2)' => 839.0 + 101.0 * 2 + 798.0,
      'Window Area (ft^2)' => 0.12 * (135.0 + 96.0 * 4 + 320.0 * 2 + 231.0 * 2 + 416.0 * 2 + 327.0 - 96.0 * 2),
      'Door Area (ft^2)' => 40.0,
      'Duct Unconditioned Surface Area (ft^2)' => (0.75 * 0.27 * (1500.0 * 2)) + (0.75 * 0.05 * 2 * (1500.0 * 2)),
      'Size, Heating System (kBtu/h)' => 60.0, # hp, not backup
      'Size, Heat Pump Backup (kBtu/h)' => 100.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 15.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 0.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 110.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 138.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 0.0
    }
    _test_cost_multipliers('SFD_2story_S_UA_GRG_ASHP1_Fireplace_FuelTanklessWH_ERV.osw', cost_multipliers)
  end

  def test_SFA_2story_UB_Furnace_RoomAC_FuelTankWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 94.0 * 4 + 170.0 * 2,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 94.0 * 4 + 170.0 * 2 + 56.0,
      'Wall Area, Below-Grade (ft^2)' => 170.0 + 94.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 250.0 * 2,
      'Floor Area, Attic (ft^2)' => 250.0,
      'Floor Area, Lighting (ft^2)' => 250.0 * 2,
      'Roof Area (ft^2)' => 140.0 * 2,
      'Window Area (ft^2)' => 0.18 * (94.28 * 4 + 169.7 * 2),
      'Door Area (ft^2)' => 20.0,
      'Duct Unconditioned Surface Area (ft^2)' => (0.75 * 0.27 * (250.0 * 2)) + (0.75 * 0.05 * 2 * (250.0 * 2)),
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 36.0,
      'Size, Water Heater (gal)' => 30.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 51.0
    }
    _test_cost_multipliers('SFA_2story_UB_Furnace_RoomAC_FuelTankWH.osw', cost_multipliers)
  end

  def test_SFA_2story_UB_FuelBoiler_RoomAC_FuelTankWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 94.0 * 4 + 170.0 * 2,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 94.0 * 4 + 170.0 * 2 + 56.0,
      'Wall Area, Below-Grade (ft^2)' => 170.0 + 94.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 250.0 * 2,
      'Floor Area, Attic (ft^2)' => 250.0,
      'Floor Area, Lighting (ft^2)' => 250.0 * 2,
      'Roof Area (ft^2)' => 140.0 * 2,
      'Window Area (ft^2)' => 0.18 * (94.28 * 4 + 169.7 * 2),
      'Door Area (ft^2)' => 20.0,
      'Duct Unconditioned Surface Area (ft^2)' => 0.0, # boiler and roomac don't have ducts
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 36.0,
      'Size, Water Heater (gal)' => 30.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 51.0
    }
    _test_cost_multipliers('SFA_2story_UB_FuelBoiler_RoomAC_FuelTankWH.osw', cost_multipliers)
  end

  def test_SFA_2story_UB_ASHP2_HPWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 94.0 * 4 + 170.0 * 2,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 94.0 * 4 + 170.0 * 2 + 56.0,
      'Wall Area, Below-Grade (ft^2)' => 170.0 + 94.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 250.0 * 2,
      'Floor Area, Attic (ft^2)' => 250.0,
      'Floor Area, Lighting (ft^2)' => 250.0 * 2,
      'Roof Area (ft^2)' => 140.0 * 2,
      'Window Area (ft^2)' => 0.18 * (94.28 * 4 + 169.7 * 2),
      'Door Area (ft^2)' => 20.0,
      'Duct Unconditioned Surface Area (ft^2)' => (0.75 * 0.27 * (250.0 * 2)) + (0.75 * 0.05 * 2 * (250.0 * 2)),
      'Size, Heating System (kBtu/h)' => 60.0,
      'Size, Heat Pump Backup (kBtu/h)' => 100.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 50.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 51.0
    }
    _test_cost_multipliers('SFA_2story_UB_ASHP2_HPWH.osw', cost_multipliers)
  end

  def test_SFA_2story_FB_FuelBoiler_RoomAC_FuelTankWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 139.0 * 2 + 77.0 * 4,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 139.0 * 2 + 77.0 * 4 + 37.0,
      'Wall Area, Below-Grade (ft^2)' => 139.0 + 77.0 * 2,
      'Floor Area, Conditioned (ft^2)' => 167.0 + 167.0 * 2,
      'Floor Area, Attic (ft^2)' => 167.0,
      'Floor Area, Lighting (ft^2)' => 167.0 + 167.0 * 2,
      'Roof Area (ft^2)' => 93.0 * 2,
      'Window Area (ft^2)' => 0.18 * (139.0 * 2 + 77.0 * 4),
      'Door Area (ft^2)' => 20.0,
      'Duct Unconditioned Surface Area (ft^2)' => 0.0, # boiler and roomac don't have ducts
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 36.0,
      'Size, Water Heater (gal)' => 30.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 37.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 41.6
    }
    _test_cost_multipliers('SFA_2story_FB_FuelBoiler_RoomAC_FuelTankWH.osw', cost_multipliers)
  end

  def test_MF_2story_UB_Furnace_AC1_FuelTankWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 240.0 + 133.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 240.0 + 133.0,
      'Wall Area, Below-Grade (ft^2)' => 240.0 + 133.0 + 40.0,
      'Floor Area, Conditioned (ft^2)' => 500.0,
      'Floor Area, Attic (ft^2)' => 0.0,
      'Floor Area, Lighting (ft^2)' => 500.0,
      'Roof Area (ft^2)' => 0.0,
      'Window Area (ft^2)' => 0.18 * (240.0 + 133.0),
      'Door Area (ft^2)' => 0.0, # door is in the corridor
      'Duct Unconditioned Surface Area (ft^2)' => (0.27 * 500.0) + (0.05 * 500.0),
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 30.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 75.7
    }
    _test_cost_multipliers('MF_2story_UB_Furnace_AC1_FuelTankWH.osw', cost_multipliers)
  end

  def test_MF_2story_UB_FuelBoiler_AC1_FuelTankWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 240.0 + 133.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 240.0 + 133.0,
      'Wall Area, Below-Grade (ft^2)' => 240.0 + 133.0 + 40.0,
      'Floor Area, Conditioned (ft^2)' => 500.0,
      'Floor Area, Attic (ft^2)' => 0.0,
      'Floor Area, Lighting (ft^2)' => 500.0,
      'Roof Area (ft^2)' => 0.0,
      'Window Area (ft^2)' => 0.18 * (240.0 + 133.0),
      'Door Area (ft^2)' => 0.0, # door is in the corridor
      'Duct Unconditioned Surface Area (ft^2)' => (0.27 * 500.0) + (0.05 * 500.0),
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 30.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 75.7
    }
    _test_cost_multipliers('MF_2story_UB_FuelBoiler_AC1_FuelTankWH.osw', cost_multipliers)
  end

  def test_MF_2story_UB_ASHP2_HPWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 240.0 + 133.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 240.0 + 133.0,
      'Wall Area, Below-Grade (ft^2)' => 240.0 + 133.0 + 40.0,
      'Floor Area, Conditioned (ft^2)' => 500.0,
      'Floor Area, Attic (ft^2)' => 0.0,
      'Floor Area, Lighting (ft^2)' => 500.0,
      'Roof Area (ft^2)' => 0.0,
      'Window Area (ft^2)' => 0.18 * (240.0 + 133.0),
      'Door Area (ft^2)' => 0.0, # door is in the corridor
      'Duct Unconditioned Surface Area (ft^2)' => (0.27 * 500.0) + (0.05 * 500.0),
      'Size, Heating System (kBtu/h)' => 60.0,
      'Size, Heat Pump Backup (kBtu/h)' => 100.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 50.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 75.7
    }
    _test_cost_multipliers('MF_2story_UB_ASHP2_HPWH.osw', cost_multipliers)
  end

  def test_MF_1story_UB_Furnace_AC1_FuelTankWH
    cost_multipliers = {
      'Fixed (1)' => 1,
      'Wall Area, Above-Grade, Conditioned (ft^2)' => 240.0 + 133.0,
      'Wall Area, Above-Grade, Exterior (ft^2)' => 240.0 + 133.0,
      'Wall Area, Below-Grade (ft^2)' => 240.0 + 133.0 + 40.0,
      'Floor Area, Conditioned (ft^2)' => 500.0,
      'Floor Area, Attic (ft^2)' => 0.0,
      'Floor Area, Lighting (ft^2)' => 500.0,
      'Roof Area (ft^2)' => 500.0,
      'Window Area (ft^2)' => 0.18 * (240.0 + 133.0),
      'Door Area (ft^2)' => 0.0, # door is in the corridor
      'Duct Unconditioned Surface Area (ft^2)' => (0.27 * 500.0) + (0.05 * 500.0),
      'Size, Heating System (kBtu/h)' => 100.0,
      'Size, Heat Pump Backup (kBtu/h)' => 0.0, # backup
      'Size, Secondary Heating System (kBtu/h)' => 0.0,
      'Size, Cooling System (kBtu/h)' => 60.0,
      'Size, Water Heater (gal)' => 30.0,
      'Flow Rate, Mechanical Ventilation (cfm)' => 0.0,
      'Slab Perimeter, Exposed, Conditioned (ft)' => 0.0,
      'Rim Joist Area, Above-Grade, Exterior (ft^2)' => 75.7
    }
    _test_cost_multipliers('MF_1story_UB_Furnace_AC1_FuelTankWH.osw', cost_multipliers)
  end

  private

  def _test_cost_multipliers(osw_file, cost_multipliers)
    require 'json'

    this_dir = File.dirname(__FILE__)
    osw = File.absolute_path("#{this_dir}/#{osw_file}")

    measures = {}
    puts "\nTesting #{File.basename(osw)}..."

    osw_hash = JSON.parse(File.read(osw))
    measures_dir = File.join(File.dirname(__FILE__), osw_hash['measure_paths'][0])
    osw_hash['steps'].each do |step|
      measures[step['measure_dir_name']] = [step['arguments']]
    end

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

    hpxml_path = File.join(this_dir, 'in.xml')
    hpxml = HPXML.new(hpxml_path: hpxml_path)

    # create an instance of the measure
    measure = UpgradeCosts.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # Check for correct cost multiplier values
    cost_multipliers.each do |mult_type, mult_value|
      value = measure.get_cost_multiplier(mult_type, hpxml, runner)
      assert(!value.nil?)
      if mult_type.include?('ft^2') || mult_type.include?('gal')
        assert_in_epsilon(mult_value, value, 0.005)
      else
        assert_in_epsilon(mult_value, value, 0.05)
      end
    end
  end
end
