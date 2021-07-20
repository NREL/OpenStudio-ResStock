# frozen_string_literal: true

def create_osws
  require 'json'
  require_relative 'BuildResidentialHPXML/resources/constants'
  require_relative 'HPXMLtoOpenStudio/resources/hpxml'

  this_dir = File.dirname(__FILE__)
  tests_dir = File.join(this_dir, 'BuildResidentialHPXML/tests')
  File.delete(*Dir.glob("#{tests_dir}/*.osw"))

  # Hash of OSW -> Parent OSW
  osws_files = {
    'base.osw' => nil, # single-family detached
    'base-appliances-coal.osw' => 'base.osw',
    'base-appliances-dehumidifier.osw' => 'base-location-dallas-tx.osw',
    'base-appliances-dehumidifier-ief-portable.osw' => 'base-appliances-dehumidifier.osw',
    'base-appliances-dehumidifier-ief-whole-home.osw' => 'base-appliances-dehumidifier-ief-portable.osw',
    # 'base-appliances-dehumidifier-multiple.osw' => 'base-appliances-dehumidifier.osw',
    'base-appliances-gas.osw' => 'base.osw',
    'base-appliances-modified.osw' => 'base.osw',
    'base-appliances-none.osw' => 'base.osw',
    'base-appliances-oil.osw' => 'base.osw',
    'base-appliances-propane.osw' => 'base.osw',
    'base-appliances-wood.osw' => 'base.osw',
    # 'base-atticroof-cathedral.osw' => 'base.osw', # TODO: conditioned attic ceiling heights are greater than wall height
    # 'base-atticroof-conditioned.osw' => 'base.osw', # Not supporting attic kneewalls for now
    'base-atticroof-flat.osw' => 'base.osw',
    'base-atticroof-radiant-barrier.osw' => 'base-location-dallas-tx.osw',
    'base-atticroof-unvented-insulated-roof.osw' => 'base.osw',
    'base-atticroof-vented.osw' => 'base.osw',
    'base-bldgtype-multifamily.osw' => 'base.osw',
    # 'base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.osw' => 'base.osw', # Not supporting units adjacent to other MF spaces for now
    # 'base-bldgtype-multifamily-adjacent-to-multiple.osw' => 'base.osw', # Not supporting units adjacent to other MF spaces for now
    # 'base-bldgtype-multifamily-adjacent-to-non-freezing-space.osw' => 'base.osw', # Not supporting units adjacent to other MF spaces for now
    # 'base-bldgtype-multifamily-adjacent-to-other-heated-space.osw' => 'base.osw', # Not supporting units adjacent to other MF spaces for now
    # 'base-bldgtype-multifamily-adjacent-to-other-housing-unit.osw' => 'base.osw', # Not supporting units adjacent to other MF spaces for now
    # 'base-bldgtype-multifamily-shared-boiler-chiller-baseboard.osw' => 'base-bldgtype-multifamily.osw',
    # 'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil.osw' => 'base-bldgtype-multifamily-shared-boiler-chiller-baseboard.osw',
    # 'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil-ducted.osw' => 'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil.osw',
    # 'base-bldgtype-multifamily-shared-boiler-chiller-water-loop-heat-pump.osw' => 'base-bldgtype-multifamily-shared-boiler-chiller-baseboard.osw',
    # 'base-bldgtype-multifamily-shared-boiler-cooling-tower-water-loop-heat-pump.osw' => 'base-bldgtype-multifamily-shared-boiler-chiller-water-loop-heat-pump.osw',
    'base-bldgtype-multifamily-shared-boiler-only-baseboard.osw' => 'base-bldgtype-multifamily.osw',
    'base-bldgtype-multifamily-shared-boiler-only-fan-coil.osw' => 'base-bldgtype-multifamily-shared-boiler-only-baseboard.osw',
    # 'base-bldgtype-multifamily-shared-boiler-only-fan-coil-ducted.osw' => 'base-bldgtype-multifamily-shared-boiler-only-fan-coil.osw',
    # 'base-bldgtype-multifamily-shared-boiler-only-fan-coil-eae.osw' => 'base-bldgtype-multifamily-shared-boiler-only-fan-coil.osw',
    # 'base-bldgtype-multifamily-shared-boiler-only-water-loop-heat-pump.osw' => 'base-bldgtype-multifamily-shared-boiler-only-baseboard.osw',
    # 'base-bldgtype-multifamily-shared-chiller-only-baseboard.osw' => 'base-bldgtype-multifamily.osw',
    # 'base-bldgtype-multifamily-shared-chiller-only-fan-coil.osw' => 'base-bldgtype-multifamily-shared-chiller-only-baseboard.osw',
    # 'base-bldgtype-multifamily-shared-chiller-only-fan-coil-ducted.osw' => 'base-bldgtype-multifamily-shared-chiller-only-fan-coil.osw',
    # 'base-bldgtype-multifamily-shared-chiller-only-water-loop-heat-pump.osw' => 'base-bldgtype-multifamily-shared-chiller-only-baseboard.osw',
    # 'base-bldgtype-multifamily-shared-cooling-tower-only-water-loop-heat-pump.osw' => 'base-bldgtype-multifamily-shared-chiller-only-water-loop-heat-pump.osw',
    # 'base-bldgtype-multifamily-shared-generator.osw' => 'base-bldgtype-multifamily.osw',
    # 'base-bldgtype-multifamily-shared-ground-loop-ground-to-air-heat-pump.osw' => 'base-bldgtype-multifamily.osw',
    # 'base-bldgtype-multifamily-shared-laundry-room.osw' => 'base-bldgtype-multifamily.osw', # Not going to support shared laundry room
    'base-bldgtype-multifamily-shared-mechvent.osw' => 'base-bldgtype-multifamily.osw',
    # 'base-bldgtype-multifamily-shared-mechvent-multiple.osw' => 'base.osw', # Not going to support > 2 MV systems
    'base-bldgtype-multifamily-shared-mechvent-preconditioning.osw' => 'base-bldgtype-multifamily-shared-mechvent.osw',
    'base-bldgtype-multifamily-shared-pv.osw' => 'base-bldgtype-multifamily.osw',
    'base-bldgtype-multifamily-shared-water-heater.osw' => 'base-bldgtype-multifamily.osw',
    # 'base-bldgtype-multifamily-shared-water-heater-recirc.osw' => 'base.osw', $ Not supporting shared recirculation for now
    'base-bldgtype-single-family-attached.osw' => 'base.osw',
    'base-dhw-combi-tankless.osw' => 'base-dhw-indirect.osw',
    'base-dhw-combi-tankless-outside.osw' => 'base-dhw-combi-tankless.osw',
    # 'base-dhw-desuperheater.osw' => 'base.osw', # Not supporting desuperheater for now
    # 'base-dhw-desuperheater-2-speed.osw' => 'base.osw', # Not supporting desuperheater for now
    # 'base-dhw-desuperheater-gshp.osw' => 'base.osw', # Not supporting desuperheater for now
    # 'base-dhw-desuperheater-hpwh.osw' => 'base.osw', # Not supporting desuperheater for now
    # 'base-dhw-desuperheater-tankless.osw' => 'base.osw', # Not supporting desuperheater for now
    # 'base-dhw-desuperheater-var-speed.osw' => 'base.osw', # Not supporting desuperheater for now
    'base-dhw-dwhr.osw' => 'base.osw',
    'base-dhw-indirect.osw' => 'base-hvac-boiler-gas-only.osw',
    # 'base-dhw-indirect-dse.osw' => 'base.osw', # Not going to support DSE
    'base-dhw-indirect-outside.osw' => 'base-dhw-indirect.osw',
    'base-dhw-indirect-standbyloss.osw' => 'base-dhw-indirect.osw',
    'base-dhw-indirect-with-solar-fraction.osw' => 'base-dhw-indirect.osw',
    'base-dhw-jacket-electric.osw' => 'base.osw',
    'base-dhw-jacket-gas.osw' => 'base-dhw-tank-gas.osw',
    'base-dhw-jacket-hpwh.osw' => 'base-dhw-tank-heat-pump.osw',
    'base-dhw-jacket-indirect.osw' => 'base-dhw-indirect.osw',
    'base-dhw-low-flow-fixtures.osw' => 'base.osw',
    # 'base-dhw-multiple.osw' => 'base.osw', # Not supporting multiple water heaters for now
    'base-dhw-none.osw' => 'base.osw',
    'base-dhw-recirc-demand.osw' => 'base.osw',
    'base-dhw-recirc-manual.osw' => 'base.osw',
    'base-dhw-recirc-nocontrol.osw' => 'base.osw',
    'base-dhw-recirc-temperature.osw' => 'base.osw',
    'base-dhw-recirc-timer.osw' => 'base.osw',
    'base-dhw-solar-direct-evacuated-tube.osw' => 'base.osw',
    'base-dhw-solar-direct-flat-plate.osw' => 'base.osw',
    'base-dhw-solar-direct-ics.osw' => 'base.osw',
    'base-dhw-solar-fraction.osw' => 'base.osw',
    'base-dhw-solar-indirect-flat-plate.osw' => 'base.osw',
    'base-dhw-solar-thermosyphon-flat-plate.osw' => 'base.osw',
    'base-dhw-tank-coal.osw' => 'base.osw',
    'base-dhw-tank-elec-uef.osw' => 'base.osw',
    'base-dhw-tank-gas.osw' => 'base.osw',
    'base-dhw-tank-gas-uef.osw' => 'base.osw',
    # 'base-dhw-tank-gas-uef-fhr.osw' => 'base-dhw-tank-gas-uef.osw',
    'base-dhw-tank-gas-outside.osw' => 'base-dhw-tank-gas.osw',
    'base-dhw-tank-heat-pump.osw' => 'base.osw',
    'base-dhw-tank-heat-pump-outside.osw' => 'base.osw',
    'base-dhw-tank-heat-pump-uef.osw' => 'base-dhw-tank-heat-pump.osw',
    'base-dhw-tank-heat-pump-with-solar.osw' => 'base.osw',
    'base-dhw-tank-heat-pump-with-solar-fraction.osw' => 'base.osw',
    'base-dhw-tankless-electric.osw' => 'base.osw',
    'base-dhw-tankless-electric-outside.osw' => 'base.osw',
    'base-dhw-tankless-electric-uef.osw' => 'base-dhw-tankless-electric.osw',
    'base-dhw-tankless-gas.osw' => 'base.osw',
    'base-dhw-tankless-gas-uef.osw' => 'base-dhw-tankless-gas.osw',
    'base-dhw-tankless-gas-with-solar.osw' => 'base.osw',
    'base-dhw-tankless-gas-with-solar-fraction.osw' => 'base.osw',
    'base-dhw-tankless-propane.osw' => 'base.osw',
    'base-dhw-tank-oil.osw' => 'base.osw',
    'base-dhw-tank-wood.osw' => 'base.osw',
    'base-enclosure-2stories.osw' => 'base.osw',
    'base-enclosure-2stories-garage.osw' => 'base-enclosure-2stories.osw',
    'base-enclosure-beds-1.osw' => 'base.osw',
    'base-enclosure-beds-2.osw' => 'base.osw',
    'base-enclosure-beds-4.osw' => 'base.osw',
    'base-enclosure-beds-5.osw' => 'base.osw',
    'base-enclosure-garage.osw' => 'base.osw',
    'base-enclosure-infil-ach-house-pressure.osw' => 'base.osw',
    'base-enclosure-infil-cfm-house-pressure.osw' => 'base-enclosure-infil-cfm50.osw',
    'base-enclosure-infil-cfm50.osw' => 'base.osw',
    'base-enclosure-infil-flue.osw' => 'base.osw',
    'base-enclosure-infil-natural-ach.osw' => 'base.osw',
    # 'base-enclosure-orientations.osw' => 'base.osw',
    'base-enclosure-overhangs.osw' => 'base.osw',
    # 'base-enclosure-rooftypes.osw' => 'base.osw',
    # 'base-enclosure-skylights.osw' => 'base.osw', # There are no front roof surfaces, but 15.0 ft^2 of skylights were specified.
    # 'base-enclosure-skylights-shading.osw' => 'base-enclosure-skylights.osw", # Not going to support interior/exterior shading by facade
    # 'base-enclosure-split-surfaces.osw' => 'base.osw',
    # 'base-enclosure-split-surfaces2.osw' => 'base.osw',
    # 'base-enclosure-walltypes.osw' => 'base.osw',
    # 'base-enclosure-windows-shading.osw' => 'base.osw', # Not going to support interior/exterior shading by facade
    'base-enclosure-windows-none.osw' => 'base.osw',
    'base-foundation-ambient.osw' => 'base.osw',
    # 'base-foundation-basement-garage.osw' => 'base.osw',
    # 'base-foundation-complex.osw' => 'base.osw', # Not going to support multiple foundation types
    'base-foundation-conditioned-basement-slab-insulation.osw' => 'base.osw',
    # 'base-foundation-conditioned-basement-wall-interior-insulation.osw' => 'base.osw',
    # 'base-foundation-multiple.osw' => 'base.osw', # Not going to support multiple foundation types
    'base-foundation-slab.osw' => 'base.osw',
    'base-foundation-unconditioned-basement.osw' => 'base.osw',
    # 'base-foundation-unconditioned-basement-above-grade.osw' => 'base.osw', # TODO: add foundation wall windows
    'base-foundation-unconditioned-basement-assembly-r.osw' => 'base-foundation-unconditioned-basement.osw',
    'base-foundation-unconditioned-basement-wall-insulation.osw' => 'base-foundation-unconditioned-basement.osw',
    'base-foundation-unvented-crawlspace.osw' => 'base.osw',
    'base-foundation-vented-crawlspace.osw' => 'base.osw',
    # 'base-foundation-walkout-basement.osw' => 'base.osw', # 1 kiva object instead of 4
    'base-hvac-air-to-air-heat-pump-1-speed.osw' => 'base.osw',
    'base-hvac-air-to-air-heat-pump-1-speed-cooling-only.osw' => 'base-hvac-air-to-air-heat-pump-1-speed.osw',
    'base-hvac-air-to-air-heat-pump-1-speed-heating-only.osw' => 'base-hvac-air-to-air-heat-pump-1-speed.osw',
    'base-hvac-air-to-air-heat-pump-2-speed.osw' => 'base.osw',
    'base-hvac-air-to-air-heat-pump-var-speed.osw' => 'base.osw',
    'base-hvac-autosize.osw' => 'base.osw',
    'base-hvac-autosize-air-to-air-heat-pump-1-speed.osw' => 'base-hvac-air-to-air-heat-pump-1-speed.osw',
    'base-hvac-autosize-air-to-air-heat-pump-1-speed-cooling-only.osw' => 'base-hvac-air-to-air-heat-pump-1-speed-cooling-only.osw',
    'base-hvac-autosize-air-to-air-heat-pump-1-speed-heating-only.osw' => 'base-hvac-air-to-air-heat-pump-1-speed-heating-only.osw',
    # 'base-hvac-autosize-air-to-air-heat-pump-1-speed-manual-s-oversize-allowances.osw' => 'base-hvac-autosize-air-to-air-heat-pump-1-speed.osw',
    'base-hvac-autosize-air-to-air-heat-pump-2-speed.osw' => 'base-hvac-air-to-air-heat-pump-2-speed.osw',
    # 'base-hvac-autosize-air-to-air-heat-pump-2-speed-manual-s-oversize-allowances.osw' => 'base-hvac-autosize-air-to-air-heat-pump-2-speed.osw',
    'base-hvac-autosize-air-to-air-heat-pump-var-speed.osw' => 'base-hvac-air-to-air-heat-pump-var-speed.osw',
    # 'base-hvac-autosize-air-to-air-heat-pump-var-speed-manual-s-oversize-allowances.osw' => 'base-hvac-autosize-air-to-air-heat-pump-var-speed.osw',
    'base-hvac-autosize-boiler-elec-only.osw' => 'base-hvac-boiler-elec-only.osw',
    'base-hvac-autosize-boiler-gas-central-ac-1-speed.osw' => 'base-hvac-boiler-gas-central-ac-1-speed.osw',
    'base-hvac-autosize-boiler-gas-only.osw' => 'base-hvac-boiler-gas-only.osw',
    'base-hvac-autosize-central-ac-only-1-speed.osw' => 'base-hvac-central-ac-only-1-speed.osw',
    'base-hvac-autosize-central-ac-only-2-speed.osw' => 'base-hvac-central-ac-only-2-speed.osw',
    'base-hvac-autosize-central-ac-only-var-speed.osw' => 'base-hvac-central-ac-only-var-speed.osw',
    'base-hvac-autosize-central-ac-plus-air-to-air-heat-pump-heating.osw' => 'base-hvac-central-ac-plus-air-to-air-heat-pump-heating.osw',
    'base-hvac-autosize-dual-fuel-air-to-air-heat-pump-1-speed.osw' => 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.osw',
    'base-hvac-autosize-dual-fuel-mini-split-heat-pump-ducted.osw' => 'base-hvac-dual-fuel-mini-split-heat-pump-ducted.osw',
    'base-hvac-autosize-elec-resistance-only.osw' => 'base-hvac-elec-resistance-only.osw',
    'base-hvac-autosize-evap-cooler-furnace-gas.osw' => 'base-hvac-evap-cooler-furnace-gas.osw',
    'base-hvac-autosize-floor-furnace-propane-only.osw' => 'base-hvac-floor-furnace-propane-only.osw',
    'base-hvac-autosize-furnace-elec-only.osw' => 'base-hvac-furnace-elec-only.osw',
    'base-hvac-autosize-furnace-gas-central-ac-2-speed.osw' => 'base-hvac-furnace-gas-central-ac-2-speed.osw',
    'base-hvac-autosize-furnace-gas-central-ac-var-speed.osw' => 'base-hvac-furnace-gas-central-ac-var-speed.osw',
    'base-hvac-autosize-furnace-gas-only.osw' => 'base-hvac-furnace-gas-only.osw',
    'base-hvac-autosize-furnace-gas-room-ac.osw' => 'base-hvac-furnace-gas-room-ac.osw',
    'base-hvac-autosize-ground-to-air-heat-pump.osw' => 'base-hvac-ground-to-air-heat-pump.osw',
    'base-hvac-autosize-ground-to-air-heat-pump-cooling-only.osw' => 'base-hvac-ground-to-air-heat-pump-cooling-only.osw',
    'base-hvac-autosize-ground-to-air-heat-pump-heating-only.osw' => 'base-hvac-ground-to-air-heat-pump-heating-only.osw',
    # 'base-hvac-autosize-ground-to-air-heat-pump-manual-s-oversize-allowances.osw' => 'base-hvac-autosize-ground-to-air-heat-pump.osw',
    'base-hvac-autosize-mini-split-heat-pump-ducted.osw' => 'base-hvac-mini-split-heat-pump-ducted.osw',
    'base-hvac-autosize-mini-split-heat-pump-ducted-cooling-only.osw' => 'base-hvac-mini-split-heat-pump-ducted-cooling-only.osw',
    'base-hvac-autosize-mini-split-heat-pump-ducted-heating-only.osw' => 'base-hvac-mini-split-heat-pump-ducted-heating-only.osw',
    # 'base-hvac-autosize-mini-split-heat-pump-ducted-manual-s-oversize-allowances.osw' => 'base-hvac-autosize-mini-split-heat-pump-ducted.osw',
    'base-hvac-autosize-mini-split-air-conditioner-only-ducted.osw' => 'base-hvac-mini-split-air-conditioner-only-ducted.osw',
    'base-hvac-autosize-room-ac-only.osw' => 'base-hvac-room-ac-only.osw',
    'base-hvac-autosize-stove-oil-only.osw' => 'base-hvac-stove-oil-only.osw',
    'base-hvac-autosize-wall-furnace-elec-only.osw' => 'base-hvac-wall-furnace-elec-only.osw',
    'base-hvac-boiler-coal-only.osw' => 'base.osw',
    'base-hvac-boiler-elec-only.osw' => 'base.osw',
    'base-hvac-boiler-gas-central-ac-1-speed.osw' => 'base.osw',
    'base-hvac-boiler-gas-only.osw' => 'base.osw',
    'base-hvac-boiler-oil-only.osw' => 'base.osw',
    'base-hvac-boiler-propane-only.osw' => 'base.osw',
    'base-hvac-boiler-wood-only.osw' => 'base.osw',
    'base-hvac-central-ac-only-1-speed.osw' => 'base.osw',
    'base-hvac-central-ac-only-2-speed.osw' => 'base.osw',
    'base-hvac-central-ac-only-var-speed.osw' => 'base.osw',
    'base-hvac-central-ac-plus-air-to-air-heat-pump-heating.osw' => 'base-hvac-central-ac-only-1-speed.osw',
    # 'base-hvac-dse.osw' => 'base.osw', # Not going to support DSE
    'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.osw' => 'base-hvac-air-to-air-heat-pump-1-speed.osw',
    'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed-electric.osw' => 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.osw',
    'base-hvac-dual-fuel-air-to-air-heat-pump-2-speed.osw' => 'base-hvac-air-to-air-heat-pump-2-speed.osw',
    'base-hvac-dual-fuel-air-to-air-heat-pump-var-speed.osw' => 'base-hvac-air-to-air-heat-pump-var-speed.osw',
    'base-hvac-dual-fuel-mini-split-heat-pump-ducted.osw' => 'base-hvac-mini-split-heat-pump-ducted.osw',
    'base-hvac-ducts-leakage-percent.osw' => 'base.osw',
    # 'base-hvac-ducts-area-fractions.osw' => 'base-enclosure-2stories.osw',
    'base-hvac-elec-resistance-only.osw' => 'base.osw',
    'base-hvac-evap-cooler-furnace-gas.osw' => 'base.osw',
    'base-hvac-evap-cooler-only.osw' => 'base.osw',
    'base-hvac-evap-cooler-only-ducted.osw' => 'base.osw',
    'base-hvac-fireplace-wood-only.osw' => 'base.osw',
    'base-hvac-fixed-heater-gas-only.osw' => 'base.osw',
    'base-hvac-floor-furnace-propane-only.osw' => 'base.osw',
    'base-hvac-furnace-coal-only.osw' => 'base.osw',
    'base-hvac-furnace-elec-central-ac-1-speed.osw' => 'base.osw',
    'base-hvac-furnace-elec-only.osw' => 'base.osw',
    'base-hvac-furnace-gas-central-ac-2-speed.osw' => 'base.osw',
    'base-hvac-furnace-gas-central-ac-var-speed.osw' => 'base.osw',
    'base-hvac-furnace-gas-only.osw' => 'base.osw',
    'base-hvac-furnace-gas-room-ac.osw' => 'base.osw',
    'base-hvac-furnace-oil-only.osw' => 'base.osw',
    'base-hvac-furnace-propane-only.osw' => 'base.osw',
    'base-hvac-furnace-wood-only.osw' => 'base.osw',
    # 'base-hvac-furnace-x3-dse.osw' => 'base.osw', # Not going to support DSE
    'base-hvac-ground-to-air-heat-pump.osw' => 'base.osw',
    'base-hvac-ground-to-air-heat-pump-cooling-only.osw' => 'base-hvac-ground-to-air-heat-pump.osw',
    'base-hvac-ground-to-air-heat-pump-heating-only.osw' => 'base-hvac-ground-to-air-heat-pump.osw',
    'base-hvac-seasons.osw' => 'base.osw',
    'base-hvac-install-quality-air-to-air-heat-pump-1-speed.osw' => 'base-hvac-air-to-air-heat-pump-1-speed.osw',
    'base-hvac-install-quality-air-to-air-heat-pump-2-speed.osw' => 'base-hvac-air-to-air-heat-pump-2-speed.osw',
    'base-hvac-install-quality-air-to-air-heat-pump-var-speed.osw' => 'base-hvac-air-to-air-heat-pump-var-speed.osw',
    'base-hvac-install-quality-furnace-gas-central-ac-1-speed.osw' => 'base.osw',
    'base-hvac-install-quality-furnace-gas-central-ac-2-speed.osw' => 'base-hvac-furnace-gas-central-ac-2-speed.osw',
    'base-hvac-install-quality-furnace-gas-central-ac-var-speed.osw' => 'base-hvac-furnace-gas-central-ac-var-speed.osw',
    'base-hvac-install-quality-furnace-gas-only.osw' => 'base-hvac-furnace-gas-only.osw',
    'base-hvac-install-quality-ground-to-air-heat-pump.osw' => 'base-hvac-ground-to-air-heat-pump.osw',
    'base-hvac-install-quality-mini-split-heat-pump-ducted.osw' => 'base-hvac-mini-split-heat-pump-ducted.osw',
    'base-hvac-install-quality-mini-split-air-conditioner-only-ducted.osw' => 'base-hvac-mini-split-air-conditioner-only-ducted.osw',
    'base-hvac-mini-split-air-conditioner-only-ducted.osw' => 'base.osw',
    'base-hvac-mini-split-air-conditioner-only-ductless.osw' => 'base-hvac-mini-split-air-conditioner-only-ducted.osw',
    'base-hvac-mini-split-heat-pump-ducted.osw' => 'base.osw',
    'base-hvac-mini-split-heat-pump-ducted-cooling-only.osw' => 'base-hvac-mini-split-heat-pump-ducted.osw',
    'base-hvac-mini-split-heat-pump-ducted-heating-only.osw' => 'base-hvac-mini-split-heat-pump-ducted.osw',
    'base-hvac-mini-split-heat-pump-ductless.osw' => 'base-hvac-mini-split-heat-pump-ducted.osw',
    # 'base-hvac-multiple.osw' => 'base.osw', # Not supporting multiple heating/cooling systems for now
    'base-hvac-none.osw' => 'base.osw',
    'base-hvac-portable-heater-gas-only.osw' => 'base.osw',
    # 'base-hvac-programmable-thermostat.osw' => 'base.osw',
    'base-hvac-programmable-thermostat-detailed.osw' => 'base.osw',
    'base-hvac-room-ac-only.osw' => 'base.osw',
    'base-hvac-room-ac-only-33percent.osw' => 'base.osw',
    # 'base-hvac-room-ac-only-ceer.osw' => 'base-hvac-room-ac-only.osw',
    'base-hvac-setpoints.osw' => 'base.osw',
    'base-hvac-stove-oil-only.osw' => 'base.osw',
    'base-hvac-stove-wood-pellets-only.osw' => 'base.osw',
    'base-hvac-undersized.osw' => 'base.osw',
    # 'base-hvac-undersized-allow-increased-fixed-capacities.osw' => 'base-hvac-undersized.osw',
    'base-hvac-wall-furnace-elec-only.osw' => 'base.osw',
    'base-lighting-ceiling-fans.osw' => 'base.osw',
    'base-lighting-detailed.osw' => 'base.osw',
    # 'base-lighting-none.osw' => 'base.osw',
    'base-location-AMY-2012.osw' => 'base.osw',
    'base-location-baltimore-md.osw' => 'base-foundation-unvented-crawlspace.osw',
    'base-location-dallas-tx.osw' => 'base-foundation-slab.osw',
    'base-location-duluth-mn.osw' => 'base-foundation-unconditioned-basement.osw',
    'base-location-helena-mt.osw' => 'base.osw',
    'base-location-honolulu-hi.osw' => 'base-foundation-slab.osw',
    'base-location-miami-fl.osw' => 'base-foundation-slab.osw',
    'base-location-phoenix-az.osw' => 'base-foundation-slab.osw',
    'base-location-portland-or.osw' => 'base-foundation-vented-crawlspace.osw',
    'base-mechvent-balanced.osw' => 'base.osw',
    'base-mechvent-bath-kitchen-fans.osw' => 'base.osw',
    'base-mechvent-cfis.osw' => 'base.osw',
    # 'base-mechvent-cfis-dse.osw' => 'base.osw', # Not going to support DSE
    'base-mechvent-cfis-evap-cooler-only-ducted.osw' => 'base-hvac-evap-cooler-only-ducted.osw',
    'base-mechvent-erv.osw' => 'base.osw',
    'base-mechvent-erv-atre-asre.osw' => 'base.osw',
    'base-mechvent-exhaust.osw' => 'base.osw',
    'base-mechvent-exhaust-rated-flow-rate.osw' => 'base.osw',
    'base-mechvent-hrv.osw' => 'base.osw',
    'base-mechvent-hrv-asre.osw' => 'base.osw',
    # 'base-mechvent-multiple.osw' => 'base.osw', # Not going to support > 2 MV systems
    'base-mechvent-supply.osw' => 'base.osw',
    'base-mechvent-whole-house-fan.osw' => 'base.osw',
    'base-misc-defaults.osw' => 'base.osw',
    # 'base-misc-generators.osw' => 'base.osw',
    'base-misc-loads-large-uncommon.osw' => 'base.osw',
    'base-misc-loads-large-uncommon2.osw' => 'base-misc-loads-large-uncommon.osw',
    # 'base-misc-loads-none.osw' => 'base.osw',
    'base-misc-neighbor-shading.osw' => 'base.osw',
    'base-misc-shielding-of-home.osw' => 'base.osw',
    'base-misc-usage-multiplier.osw' => 'base.osw',
    # 'base-multiple-buildings.osw' => 'base.osw',
    'base-pv.osw' => 'base.osw',
    'base-simcontrol-calendar-year-custom.osw' => 'base.osw',
    'base-simcontrol-daylight-saving-custom.osw' => 'base.osw',
    'base-simcontrol-daylight-saving-disabled.osw' => 'base.osw',
    'base-simcontrol-runperiod-1-month.osw' => 'base.osw',
    'base-simcontrol-timestep-10-mins.osw' => 'base.osw',
    'base-schedules-stochastic.osw' => 'base.osw',
    'base-schedules-stochastic-vacant.osw' => 'base-schedules-stochastic.osw',
    'base-schedules-user-specified.osw' => 'base.osw',

    # Extra test files that don't correspond with sample files
    'extra-auto.osw' => 'base.osw',
    'extra-pv-roofpitch.osw' => 'base.osw',
    'extra-dhw-solar-latitude.osw' => 'base.osw',
    'extra-second-refrigerator.osw' => 'base.osw',
    'extra-second-heating-system-portable-heater-to-heating-system.osw' => 'base.osw',
    'extra-second-heating-system-fireplace-to-heating-system.osw' => 'base-hvac-elec-resistance-only.osw',
    'extra-second-heating-system-boiler-to-heating-system.osw' => 'base-hvac-boiler-gas-central-ac-1-speed.osw',
    'extra-second-heating-system-portable-heater-to-heat-pump.osw' => 'base-hvac-air-to-air-heat-pump-1-speed.osw',
    'extra-second-heating-system-fireplace-to-heat-pump.osw' => 'base-hvac-mini-split-heat-pump-ducted.osw',
    'extra-second-heating-system-boiler-to-heat-pump.osw' => 'base-hvac-ground-to-air-heat-pump.osw',
    'extra-enclosure-windows-shading.osw' => 'base.osw',
    'extra-enclosure-garage-partially-protruded.osw' => 'base.osw',
    'extra-enclosure-garage-atticroof-conditioned.osw' => 'base-enclosure-garage.osw',
    'extra-enclosure-atticroof-conditioned-eaves-gable.osw' => 'base-foundation-slab.osw',
    'extra-enclosure-atticroof-conditioned-eaves-hip.osw' => 'extra-enclosure-atticroof-conditioned-eaves-gable.osw',
    'extra-schedules-random-seed.osw' => 'base-schedules-stochastic.osw',
    'extra-zero-refrigerator-kwh.osw' => 'base.osw',
    'extra-zero-extra-refrigerator-kwh.osw' => 'base.osw',
    'extra-zero-freezer-kwh.osw' => 'base.osw',
    'extra-zero-clothes-washer-kwh.osw' => 'base.osw',
    'extra-zero-dishwasher-kwh.osw' => 'base.osw',
    'extra-bldgtype-single-family-attached-atticroof-flat.osw' => 'base-bldgtype-single-family-attached.osw',
    'extra-gas-pool-heater-with-zero-kwh.osw' => 'base.osw',
    'extra-gas-hot-tub-heater-with-zero-kwh.osw' => 'base.osw',

    'extra-bldgtype-single-family-attached-atticroof-conditioned-eaves-gable.osw' => 'extra-bldgtype-single-family-attached-slab.osw',
    'extra-bldgtype-single-family-attached-atticroof-conditioned-eaves-hip.osw' => 'extra-bldgtype-single-family-attached-atticroof-conditioned-eaves-gable.osw',
    'extra-bldgtype-multifamily-eaves.osw' => 'extra-bldgtype-multifamily-slab.osw',

    'extra-bldgtype-single-family-attached-slab.osw' => 'base-bldgtype-single-family-attached.osw',
    'extra-bldgtype-single-family-attached-vented-crawlspace.osw' => 'base-bldgtype-single-family-attached.osw',
    'extra-bldgtype-single-family-attached-unvented-crawlspace.osw' => 'base-bldgtype-single-family-attached.osw',
    'extra-bldgtype-single-family-attached-unconditioned-basement.osw' => 'base-bldgtype-single-family-attached.osw',

    'extra-bldgtype-single-family-attached-double-loaded-interior.osw' => 'base-bldgtype-single-family-attached.osw',
    'extra-bldgtype-single-family-attached-single-exterior-front.osw' => 'base-bldgtype-single-family-attached.osw',
    'extra-bldgtype-single-family-attached-double-exterior.osw' => 'base-bldgtype-single-family-attached.osw',

    'extra-bldgtype-single-family-attached-slab-middle.osw' => 'extra-bldgtype-single-family-attached-slab.osw',
    'extra-bldgtype-single-family-attached-slab-right.osw' => 'extra-bldgtype-single-family-attached-slab.osw',
    'extra-bldgtype-single-family-attached-vented-crawlspace-middle.osw' => 'extra-bldgtype-single-family-attached-vented-crawlspace.osw',
    'extra-bldgtype-single-family-attached-vented-crawlspace-right.osw' => 'extra-bldgtype-single-family-attached-vented-crawlspace.osw',
    'extra-bldgtype-single-family-attached-unvented-crawlspace-middle.osw' => 'extra-bldgtype-single-family-attached-unvented-crawlspace.osw',
    'extra-bldgtype-single-family-attached-unvented-crawlspace-right.osw' => 'extra-bldgtype-single-family-attached-unvented-crawlspace.osw',
    'extra-bldgtype-single-family-attached-unconditioned-basement-middle.osw' => 'extra-bldgtype-single-family-attached-unconditioned-basement.osw',
    'extra-bldgtype-single-family-attached-unconditioned-basement-right.osw' => 'extra-bldgtype-single-family-attached-unconditioned-basement.osw',

    'extra-bldgtype-multifamily-slab.osw' => 'base-bldgtype-multifamily.osw',
    'extra-bldgtype-multifamily-vented-crawlspace.osw' => 'base-bldgtype-multifamily.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace.osw' => 'base-bldgtype-multifamily.osw',

    'extra-bldgtype-multifamily-double-loaded-interior.osw' => 'base-bldgtype-multifamily.osw',
    'extra-bldgtype-multifamily-single-exterior-front.osw' => 'base-bldgtype-multifamily.osw',
    'extra-bldgtype-multifamily-double-exterior.osw' => 'base-bldgtype-multifamily.osw',

    'extra-bldgtype-multifamily-slab-left-bottom.osw' => 'extra-bldgtype-multifamily-slab.osw',
    'extra-bldgtype-multifamily-slab-left-middle.osw' => 'extra-bldgtype-multifamily-slab.osw',
    'extra-bldgtype-multifamily-slab-left-top.osw' => 'extra-bldgtype-multifamily-slab.osw',
    'extra-bldgtype-multifamily-slab-middle-bottom.osw' => 'extra-bldgtype-multifamily-slab.osw',
    'extra-bldgtype-multifamily-slab-middle-middle.osw' => 'extra-bldgtype-multifamily-slab.osw',
    'extra-bldgtype-multifamily-slab-middle-top.osw' => 'extra-bldgtype-multifamily-slab.osw',
    'extra-bldgtype-multifamily-slab-right-bottom.osw' => 'extra-bldgtype-multifamily-slab.osw',
    'extra-bldgtype-multifamily-slab-right-middle.osw' => 'extra-bldgtype-multifamily-slab.osw',
    'extra-bldgtype-multifamily-slab-right-top.osw' => 'extra-bldgtype-multifamily-slab.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-left-bottom.osw' => 'extra-bldgtype-multifamily-vented-crawlspace.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-left-middle.osw' => 'extra-bldgtype-multifamily-vented-crawlspace.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-left-top.osw' => 'extra-bldgtype-multifamily-vented-crawlspace.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-middle-bottom.osw' => 'extra-bldgtype-multifamily-vented-crawlspace.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-middle-middle.osw' => 'extra-bldgtype-multifamily-vented-crawlspace.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-middle-top.osw' => 'extra-bldgtype-multifamily-vented-crawlspace.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-right-bottom.osw' => 'extra-bldgtype-multifamily-vented-crawlspace.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-right-middle.osw' => 'extra-bldgtype-multifamily-vented-crawlspace.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-right-top.osw' => 'extra-bldgtype-multifamily-vented-crawlspace.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-left-bottom.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-left-middle.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-left-top.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-middle-bottom.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-middle-middle.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-middle-top.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-right-bottom.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-right-middle.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-right-top.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace.osw',

    'extra-bldgtype-multifamily-slab-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-slab.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-vented-crawlspace.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace.osw',
    'extra-bldgtype-multifamily-slab-left-bottom-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-slab-left-bottom.osw',
    'extra-bldgtype-multifamily-slab-left-middle-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-slab-left-middle.osw',
    'extra-bldgtype-multifamily-slab-left-top-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-slab-left-top.osw',
    'extra-bldgtype-multifamily-slab-middle-bottom-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-slab-middle-bottom.osw',
    'extra-bldgtype-multifamily-slab-middle-middle-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-slab-middle-middle.osw',
    'extra-bldgtype-multifamily-slab-middle-top-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-slab-middle-top.osw',
    'extra-bldgtype-multifamily-slab-right-bottom-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-slab-right-bottom.osw',
    'extra-bldgtype-multifamily-slab-right-middle-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-slab-right-middle.osw',
    'extra-bldgtype-multifamily-slab-right-top-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-slab-right-top.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-left-bottom-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-vented-crawlspace-left-bottom.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-left-middle-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-vented-crawlspace-left-middle.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-left-top-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-vented-crawlspace-left-top.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-middle-bottom-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-vented-crawlspace-middle-bottom.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-middle-middle-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-vented-crawlspace-middle-middle.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-middle-top-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-vented-crawlspace-middle-top.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-right-bottom-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-vented-crawlspace-right-bottom.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-right-middle-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-vented-crawlspace-right-middle.osw',
    'extra-bldgtype-multifamily-vented-crawlspace-right-top-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-vented-crawlspace-right-top.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-left-bottom-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace-left-bottom.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-left-middle-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace-left-middle.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-left-top-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace-left-top.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-middle-bottom-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace-middle-bottom.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-middle-middle-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace-middle-middle.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-middle-top-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace-middle-top.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-right-bottom-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace-right-bottom.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-right-middle-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace-right-middle.osw',
    'extra-bldgtype-multifamily-unvented-crawlspace-right-top-double-loaded-interior.osw' => 'extra-bldgtype-multifamily-unvented-crawlspace-right-top.osw',

    'invalid_files/non-electric-heat-pump-water-heater.osw' => 'base.osw',
    'invalid_files/heating-system-and-heat-pump.osw' => 'base.osw',
    'invalid_files/cooling-system-and-heat-pump.osw' => 'base.osw',
    'invalid_files/non-integer-geometry-num-bathrooms.osw' => 'base.osw',
    'invalid_files/non-integer-ceiling-fan-quantity.osw' => 'base.osw',
    'invalid_files/single-family-detached-slab-non-zero-foundation-height.osw' => 'base.osw',
    'invalid_files/single-family-detached-finished-basement-zero-foundation-height.osw' => 'base.osw',
    'invalid_files/single-family-attached-ambient.osw' => 'base-bldgtype-single-family-attached.osw',
    'invalid_files/multifamily-bottom-slab-non-zero-foundation-height.osw' => 'base-bldgtype-multifamily.osw',
    'invalid_files/multifamily-bottom-crawlspace-zero-foundation-height.osw' => 'base-bldgtype-multifamily.osw',
    'invalid_files/slab-non-zero-foundation-height-above-grade.osw' => 'base.osw',
    'invalid_files/ducts-location-and-areas-not-same-type.osw' => 'base.osw',
    'invalid_files/second-heating-system-serves-majority-heat.osw' => 'base.osw',
    'invalid_files/second-heating-system-serves-total-heat-load.osw' => 'base.osw',
    'invalid_files/second-heating-system-but-no-primary-heating.osw' => 'base.osw',
    'invalid_files/single-family-attached-no-building-orientation.osw' => 'base-bldgtype-single-family-attached.osw',
    'invalid_files/multifamily-no-building-orientation.osw' => 'base-bldgtype-multifamily.osw',
    'invalid_files/vented-crawlspace-with-wall-and-ceiling-insulation.osw' => 'base.osw',
    'invalid_files/unvented-crawlspace-with-wall-and-ceiling-insulation.osw' => 'base.osw',
    'invalid_files/unconditioned-basement-with-wall-and-ceiling-insulation.osw' => 'base.osw',
    'invalid_files/vented-attic-with-floor-and-roof-insulation.osw' => 'base.osw',
    'invalid_files/unvented-attic-with-floor-and-roof-insulation.osw' => 'base.osw',
    'invalid_files/conditioned-basement-with-ceiling-insulation.osw' => 'base.osw',
    'invalid_files/conditioned-attic-with-floor-insulation.osw' => 'base.osw',
    'invalid_files/dhw-indirect-without-boiler.osw' => 'base.osw',
    'invalid_files/multipliers-without-tv-plug-loads.osw' => 'base.osw',
    'invalid_files/multipliers-without-other-plug-loads.osw' => 'base.osw',
    'invalid_files/multipliers-without-well-pump-plug-loads.osw' => 'base.osw',
    'invalid_files/multipliers-without-vehicle-plug-loads.osw' => 'base.osw',
    'invalid_files/multipliers-without-fuel-loads.osw' => 'base.osw',
    'invalid_files/foundation-wall-insulation-greater-than-height.osw' => 'base-foundation-vented-crawlspace.osw',
    'invalid_files/conditioned-attic-with-one-floor-above-grade.osw' => 'base.osw',
    'invalid_files/zero-number-of-bedrooms.osw' => 'base.osw',
    'invalid_files/single-family-detached-with-shared-system.osw' => 'base.osw',
    'invalid_files/hvac-seasons-incomplete-heating-season.osw' => 'base.osw',
    'invalid_files/hvac-seasons-incomplete-cooling-season.osw' => 'base.osw',
    'invalid_files/schedules-vacancy-incomplete.osw' => 'base.osw',
    'invalid_files/schedules-vacancy-invalid.osw' => 'base.osw'
  }

  puts "Generating #{osws_files.size} OSW files..."

  osws_files.each do |derivative, parent|
    print '.'

    osw_path = File.absolute_path(File.join(tests_dir, derivative))

    begin
      osw_files = [derivative]
      unless parent.nil?
        osw_files.unshift(parent)
      end
      while not parent.nil?
        next unless osws_files.keys.include? parent

        unless osws_files[parent].nil?
          osw_files.unshift(osws_files[parent])
        end
        parent = osws_files[parent]
      end

      workflow = OpenStudio::WorkflowJSON.new
      workflow.setOswPath(osw_path)
      workflow.addMeasurePath('../..')
      steps = OpenStudio::WorkflowStepVector.new
      step = OpenStudio::MeasureStep.new('BuildResidentialHPXML')

      osw_files.each do |osw_file|
        step = get_values(osw_file, step)
      end

      steps.push(step)
      workflow.setWorkflowSteps(steps)
      workflow.save

      workflow_hash = JSON.parse(File.read(osw_path))
      workflow_hash.delete('created_at')
      workflow_hash.delete('updated_at')

      File.open(osw_path, 'w') do |f|
        f.write(JSON.pretty_generate(workflow_hash))
      end
    rescue Exception => e
      puts "\n#{e}\n#{e.backtrace.join('\n')}"
      puts "\nError: Did not successfully generate #{derivative}."
      exit!
    end
  end

  puts "\n"

  # Print warnings about extra files
  abs_osw_files = []
  dirs = [nil]
  osws_files.keys.each do |osw_file|
    abs_osw_files << File.absolute_path(File.join(tests_dir, osw_file))
    next unless osw_file.include? '/'

    dirs << osw_file.split('/')[0] + '/'
  end
  dirs.uniq.each do |dir|
    Dir["#{tests_dir}/#{dir}*.osw"].each do |osw|
      next if abs_osw_files.include? File.absolute_path(osw)

      puts "Warning: Extra OSW file found at #{File.absolute_path(osw)}"
    end
  end
end

def get_values(osw_file, step)
  step.setArgument('hpxml_path', "../BuildResidentialHPXML/tests/built_residential_hpxml/#{File.basename(osw_file, '.*')}.xml")

  if ['base.osw'].include? osw_file
    step.setArgument('simulation_control_timestep', '60')
    step.setArgument('schedules_type', 'default')
    step.setArgument('weather_station_epw_filepath', 'USA_CO_Denver.Intl.AP.725650_TMY3.epw')
    step.setArgument('site_type', HPXML::SiteTypeSuburban)
    step.setArgument('geometry_unit_type', HPXML::ResidentialTypeSFD)
    step.setArgument('geometry_cfa', 2700.0)
    step.setArgument('geometry_num_floors_above_grade', 1)
    step.setArgument('geometry_wall_height', 8.0)
    step.setArgument('geometry_orientation', 180.0)
    step.setArgument('geometry_aspect_ratio', 1.5)
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
    step.setArgument('geometry_corridor_width', 10.0)
    step.setArgument('geometry_inset_width', 0.0)
    step.setArgument('geometry_inset_depth', 0.0)
    step.setArgument('geometry_inset_position', 'Right')
    step.setArgument('geometry_balcony_depth', 0.0)
    step.setArgument('geometry_garage_width', 0.0)
    step.setArgument('geometry_garage_depth', 20.0)
    step.setArgument('geometry_garage_protrusion', 0.0)
    step.setArgument('geometry_garage_position', 'Right')
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeBasementConditioned)
    step.setArgument('geometry_foundation_height', 8.0)
    step.setArgument('geometry_foundation_height_above_grade', 1.0)
    step.setArgument('geometry_rim_joist_height', 9.25)
    step.setArgument('geometry_roof_type', 'gable')
    step.setArgument('geometry_roof_pitch', '6:12')
    step.setArgument('geometry_attic_type', HPXML::AtticTypeUnvented)
    step.setArgument('geometry_eaves_depth', 0)
    step.setArgument('geometry_num_bedrooms', 3)
    step.setArgument('geometry_num_bathrooms', '2')
    step.setArgument('geometry_num_occupants', '3')
    step.setArgument('geometry_has_flue_or_chimney', Constants.Auto)
    step.setArgument('floor_assembly_r', 0)
    step.setArgument('foundation_wall_insulation_r', 8.9)
    step.setArgument('foundation_wall_insulation_distance_to_top', '0.0')
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '8.0')
    step.setArgument('foundation_wall_thickness', '8.0')
    step.setArgument('rim_joist_assembly_r', 23.0)
    step.setArgument('slab_perimeter_insulation_r', 0)
    step.setArgument('slab_perimeter_depth', 0)
    step.setArgument('slab_under_insulation_r', 0)
    step.setArgument('slab_under_width', 0)
    step.setArgument('slab_thickness', '4.0')
    step.setArgument('slab_carpet_fraction', '0.0')
    step.setArgument('slab_carpet_r', '0.0')
    step.setArgument('ceiling_assembly_r', 39.3)
    step.setArgument('roof_material_type', HPXML::RoofTypeAsphaltShingles)
    step.setArgument('roof_color', HPXML::ColorMedium)
    step.setArgument('roof_assembly_r', 2.3)
    step.setArgument('roof_radiant_barrier', false)
    step.setArgument('roof_radiant_barrier_grade', '1')
    step.setArgument('neighbor_front_distance', 0)
    step.setArgument('neighbor_back_distance', 0)
    step.setArgument('neighbor_left_distance', 0)
    step.setArgument('neighbor_right_distance', 0)
    step.setArgument('neighbor_front_height', Constants.Auto)
    step.setArgument('neighbor_back_height', Constants.Auto)
    step.setArgument('neighbor_left_height', Constants.Auto)
    step.setArgument('neighbor_right_height', Constants.Auto)
    step.setArgument('wall_type', HPXML::WallTypeWoodStud)
    step.setArgument('wall_siding_type', HPXML::SidingTypeWood)
    step.setArgument('wall_color', HPXML::ColorMedium)
    step.setArgument('wall_assembly_r', 23)
    step.setArgument('window_front_wwr', 0)
    step.setArgument('window_back_wwr', 0)
    step.setArgument('window_left_wwr', 0)
    step.setArgument('window_right_wwr', 0)
    step.setArgument('window_area_front', 108.0)
    step.setArgument('window_area_back', 108.0)
    step.setArgument('window_area_left', 72.0)
    step.setArgument('window_area_right', 72.0)
    step.setArgument('window_aspect_ratio', 1.333)
    step.setArgument('window_fraction_operable', 0.67)
    step.setArgument('window_ufactor', 0.33)
    step.setArgument('window_shgc', 0.45)
    step.setArgument('window_interior_shading_winter', 0.85)
    step.setArgument('window_interior_shading_summer', 0.7)
    step.setArgument('overhangs_front_depth', 0)
    step.setArgument('overhangs_front_distance_to_top_of_window', 0)
    step.setArgument('overhangs_back_depth', 0)
    step.setArgument('overhangs_back_distance_to_top_of_window', 0)
    step.setArgument('overhangs_left_depth', 0)
    step.setArgument('overhangs_left_distance_to_top_of_window', 0)
    step.setArgument('overhangs_right_depth', 0)
    step.setArgument('overhangs_right_distance_to_top_of_window', 0)
    step.setArgument('skylight_area_front', 0)
    step.setArgument('skylight_area_back', 0)
    step.setArgument('skylight_area_left', 0)
    step.setArgument('skylight_area_right', 0)
    step.setArgument('skylight_ufactor', 0.33)
    step.setArgument('skylight_shgc', 0.45)
    step.setArgument('door_area', 40.0)
    step.setArgument('door_rvalue', 4.4)
    step.setArgument('air_leakage_units', HPXML::UnitsACH)
    step.setArgument('air_leakage_house_pressure', 50)
    step.setArgument('air_leakage_value', 3)
    step.setArgument('air_leakage_shielding_of_home', Constants.Auto)
    step.setArgument('heating_system_type', HPXML::HVACTypeFurnace)
    step.setArgument('heating_system_fuel', HPXML::FuelTypeNaturalGas)
    step.setArgument('heating_system_heating_efficiency', 0.92)
    step.setArgument('heating_system_heating_capacity', '36000.0')
    step.setArgument('heating_system_fraction_heat_load_served', 1)
    step.setArgument('cooling_system_type', HPXML::HVACTypeCentralAirConditioner)
    step.setArgument('cooling_system_cooling_efficiency_type', HPXML::UnitsSEER)
    step.setArgument('cooling_system_cooling_efficiency', 13.0)
    step.setArgument('cooling_system_cooling_compressor_type', HPXML::HVACCompressorTypeSingleStage)
    step.setArgument('cooling_system_cooling_sensible_heat_fraction', 0.73)
    step.setArgument('cooling_system_cooling_capacity', '24000.0')
    step.setArgument('cooling_system_fraction_cool_load_served', 1)
    step.setArgument('cooling_system_is_ducted', false)
    step.setArgument('heat_pump_type', 'none')
    step.setArgument('heat_pump_heating_efficiency_type', HPXML::UnitsHSPF)
    step.setArgument('heat_pump_heating_efficiency', 7.7)
    step.setArgument('heat_pump_cooling_efficiency_type', HPXML::UnitsSEER)
    step.setArgument('heat_pump_cooling_efficiency', 13.0)
    step.setArgument('heat_pump_cooling_compressor_type', HPXML::HVACCompressorTypeSingleStage)
    step.setArgument('heat_pump_cooling_sensible_heat_fraction', 0.73)
    step.setArgument('heat_pump_heating_capacity', '36000.0')
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', '36000.0')
    step.setArgument('heat_pump_fraction_heat_load_served', 1)
    step.setArgument('heat_pump_fraction_cool_load_served', 1)
    step.setArgument('heat_pump_backup_fuel', 'none')
    step.setArgument('heat_pump_backup_heating_efficiency', 1)
    step.setArgument('heat_pump_backup_heating_capacity', '36000.0')
    step.setArgument('setpoint_heating_weekday', '68')
    step.setArgument('setpoint_heating_weekend', '68')
    step.setArgument('setpoint_cooling_weekday', '78')
    step.setArgument('setpoint_cooling_weekend', '78')
    step.setArgument('ducts_supply_leakage_units', HPXML::UnitsCFM25)
    step.setArgument('ducts_return_leakage_units', HPXML::UnitsCFM25)
    step.setArgument('ducts_supply_leakage_value', 75.0)
    step.setArgument('ducts_return_leakage_value', 25.0)
    step.setArgument('ducts_supply_insulation_r', 4.0)
    step.setArgument('ducts_return_insulation_r', 0.0)
    step.setArgument('ducts_supply_location', HPXML::LocationAtticUnvented)
    step.setArgument('ducts_return_location', HPXML::LocationAtticUnvented)
    step.setArgument('ducts_supply_surface_area', '150.0')
    step.setArgument('ducts_return_surface_area', '50.0')
    step.setArgument('ducts_number_of_return_registers', '2')
    step.setArgument('heating_system_type_2', 'none')
    step.setArgument('heating_system_fuel_2', HPXML::FuelTypeElectricity)
    step.setArgument('heating_system_heating_efficiency_2', 1.0)
    step.setArgument('heating_system_heating_capacity_2', Constants.Auto)
    step.setArgument('heating_system_fraction_heat_load_served_2', 0.25)
    step.setArgument('mech_vent_fan_type', 'none')
    step.setArgument('mech_vent_flow_rate', 110)
    step.setArgument('mech_vent_hours_in_operation', '24')
    step.setArgument('mech_vent_recovery_efficiency_type', 'Unadjusted')
    step.setArgument('mech_vent_total_recovery_efficiency', 0.48)
    step.setArgument('mech_vent_sensible_recovery_efficiency', 0.72)
    step.setArgument('mech_vent_fan_power', '30')
    step.setArgument('mech_vent_num_units_served', 1)
    step.setArgument('mech_vent_fan_type_2', 'none')
    step.setArgument('mech_vent_flow_rate_2', 110)
    step.setArgument('mech_vent_hours_in_operation_2', '24')
    step.setArgument('mech_vent_recovery_efficiency_type_2', 'Unadjusted')
    step.setArgument('mech_vent_total_recovery_efficiency_2', 0.48)
    step.setArgument('mech_vent_sensible_recovery_efficiency_2', 0.72)
    step.setArgument('mech_vent_fan_power_2', '30')
    step.setArgument('kitchen_fans_quantity', '0')
    step.setArgument('bathroom_fans_quantity', '0')
    step.setArgument('whole_house_fan_present', false)
    step.setArgument('whole_house_fan_flow_rate', 4500)
    step.setArgument('whole_house_fan_power', 300)
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeStorage)
    step.setArgument('water_heater_fuel_type', HPXML::FuelTypeElectricity)
    step.setArgument('water_heater_location', HPXML::LocationLivingSpace)
    step.setArgument('water_heater_tank_volume', '40')
    step.setArgument('water_heater_efficiency_type', 'EnergyFactor')
    step.setArgument('water_heater_efficiency', 0.95)
    step.setArgument('water_heater_recovery_efficiency', '0.76')
    step.setArgument('water_heater_standby_loss', 0)
    step.setArgument('water_heater_jacket_rvalue', 0)
    step.setArgument('water_heater_setpoint_temperature', '125')
    step.setArgument('water_heater_num_units_served', 1)
    step.setArgument('dhw_distribution_system_type', HPXML::DHWDistTypeStandard)
    step.setArgument('dhw_distribution_standard_piping_length', '50')
    step.setArgument('dhw_distribution_recirc_control_type', HPXML::DHWRecirControlTypeNone)
    step.setArgument('dhw_distribution_recirc_piping_length', '50')
    step.setArgument('dhw_distribution_recirc_branch_piping_length', '50')
    step.setArgument('dhw_distribution_recirc_pump_power', '50')
    step.setArgument('dhw_distribution_pipe_r', '0.0')
    step.setArgument('dwhr_facilities_connected', 'none')
    step.setArgument('dwhr_equal_flow', true)
    step.setArgument('dwhr_efficiency', 0.55)
    step.setArgument('water_fixtures_shower_low_flow', true)
    step.setArgument('water_fixtures_sink_low_flow', false)
    step.setArgument('water_fixtures_usage_multiplier', 1.0)
    step.setArgument('solar_thermal_system_type', 'none')
    step.setArgument('solar_thermal_collector_area', 40.0)
    step.setArgument('solar_thermal_collector_loop_type', HPXML::SolarThermalLoopTypeDirect)
    step.setArgument('solar_thermal_collector_type', HPXML::SolarThermalTypeEvacuatedTube)
    step.setArgument('solar_thermal_collector_azimuth', 180)
    step.setArgument('solar_thermal_collector_tilt', '20')
    step.setArgument('solar_thermal_collector_rated_optical_efficiency', 0.5)
    step.setArgument('solar_thermal_collector_rated_thermal_losses', 0.2799)
    step.setArgument('solar_thermal_storage_volume', Constants.Auto)
    step.setArgument('solar_thermal_solar_fraction', 0)
    step.setArgument('pv_system_module_type_1', 'none')
    step.setArgument('pv_system_location_1', Constants.Auto)
    step.setArgument('pv_system_tracking_1', Constants.Auto)
    step.setArgument('pv_system_array_azimuth_1', 180)
    step.setArgument('pv_system_array_tilt_1', '20')
    step.setArgument('pv_system_max_power_output_1', 4000)
    step.setArgument('pv_system_inverter_efficiency_1', 0.96)
    step.setArgument('pv_system_system_losses_fraction_1', 0.14)
    step.setArgument('pv_system_num_units_served_1', 1)
    step.setArgument('pv_system_module_type_2', 'none')
    step.setArgument('pv_system_location_2', Constants.Auto)
    step.setArgument('pv_system_tracking_2', Constants.Auto)
    step.setArgument('pv_system_array_azimuth_2', 180)
    step.setArgument('pv_system_array_tilt_2', '20')
    step.setArgument('pv_system_max_power_output_2', 4000)
    step.setArgument('pv_system_inverter_efficiency_2', 0.96)
    step.setArgument('pv_system_system_losses_fraction_2', 0.14)
    step.setArgument('pv_system_num_units_served_2', 1)
    step.setArgument('lighting_fraction_cfl_interior', 0.4)
    step.setArgument('lighting_fraction_lfl_interior', 0.1)
    step.setArgument('lighting_fraction_led_interior', 0.25)
    step.setArgument('lighting_usage_multiplier_interior', 1.0)
    step.setArgument('lighting_fraction_cfl_exterior', 0.4)
    step.setArgument('lighting_fraction_lfl_exterior', 0.1)
    step.setArgument('lighting_fraction_led_exterior', 0.25)
    step.setArgument('lighting_usage_multiplier_exterior', 1.0)
    step.setArgument('lighting_fraction_cfl_garage', 0.4)
    step.setArgument('lighting_fraction_lfl_garage', 0.1)
    step.setArgument('lighting_fraction_led_garage', 0.25)
    step.setArgument('lighting_usage_multiplier_garage', 1.0)
    step.setArgument('holiday_lighting_present', false)
    step.setArgument('holiday_lighting_daily_kwh', Constants.Auto)
    step.setArgument('holiday_lighting_period_begin_month', Constants.Auto)
    step.setArgument('holiday_lighting_period_begin_day_of_month', Constants.Auto)
    step.setArgument('holiday_lighting_period_end_month', Constants.Auto)
    step.setArgument('holiday_lighting_period_end_day_of_month', Constants.Auto)
    step.setArgument('dehumidifier_type', 'none')
    step.setArgument('dehumidifier_efficiency_type', 'EnergyFactor')
    step.setArgument('dehumidifier_efficiency', 1.8)
    step.setArgument('dehumidifier_capacity', 40)
    step.setArgument('dehumidifier_rh_setpoint', 0.5)
    step.setArgument('dehumidifier_fraction_dehumidification_load_served', 1)
    step.setArgument('clothes_washer_location', HPXML::LocationLivingSpace)
    step.setArgument('clothes_washer_efficiency_type', 'IntegratedModifiedEnergyFactor')
    step.setArgument('clothes_washer_efficiency', '1.21')
    step.setArgument('clothes_washer_rated_annual_kwh', '380.0')
    step.setArgument('clothes_washer_label_electric_rate', '0.12')
    step.setArgument('clothes_washer_label_gas_rate', '1.09')
    step.setArgument('clothes_washer_label_annual_gas_cost', '27.0')
    step.setArgument('clothes_washer_label_usage', '6.0')
    step.setArgument('clothes_washer_capacity', '3.2')
    step.setArgument('clothes_washer_usage_multiplier', 1.0)
    step.setArgument('clothes_dryer_location', HPXML::LocationLivingSpace)
    step.setArgument('clothes_dryer_fuel_type', HPXML::FuelTypeElectricity)
    step.setArgument('clothes_dryer_efficiency_type', 'CombinedEnergyFactor')
    step.setArgument('clothes_dryer_efficiency', '3.73')
    step.setArgument('clothes_dryer_vented_flow_rate', '150.0')
    step.setArgument('clothes_dryer_usage_multiplier', 1.0)
    step.setArgument('dishwasher_location', HPXML::LocationLivingSpace)
    step.setArgument('dishwasher_efficiency_type', 'RatedAnnualkWh')
    step.setArgument('dishwasher_efficiency', '307')
    step.setArgument('dishwasher_label_electric_rate', '0.12')
    step.setArgument('dishwasher_label_gas_rate', '1.09')
    step.setArgument('dishwasher_label_annual_gas_cost', '22.32')
    step.setArgument('dishwasher_label_usage', '4.0')
    step.setArgument('dishwasher_place_setting_capacity', '12')
    step.setArgument('dishwasher_usage_multiplier', 1.0)
    step.setArgument('refrigerator_location', HPXML::LocationLivingSpace)
    step.setArgument('refrigerator_rated_annual_kwh', '650.0')
    step.setArgument('refrigerator_usage_multiplier', 1.0)
    step.setArgument('extra_refrigerator_location', 'none')
    step.setArgument('extra_refrigerator_rated_annual_kwh', Constants.Auto)
    step.setArgument('extra_refrigerator_usage_multiplier', 1.0)
    step.setArgument('freezer_location', 'none')
    step.setArgument('freezer_rated_annual_kwh', Constants.Auto)
    step.setArgument('freezer_usage_multiplier', 1.0)
    step.setArgument('cooking_range_oven_location', HPXML::LocationLivingSpace)
    step.setArgument('cooking_range_oven_fuel_type', HPXML::FuelTypeElectricity)
    step.setArgument('cooking_range_oven_is_induction', false)
    step.setArgument('cooking_range_oven_is_convection', false)
    step.setArgument('cooking_range_oven_usage_multiplier', 1.0)
    step.setArgument('ceiling_fan_present', false)
    step.setArgument('ceiling_fan_efficiency', Constants.Auto)
    step.setArgument('ceiling_fan_quantity', Constants.Auto)
    step.setArgument('ceiling_fan_cooling_setpoint_temp_offset', 0)
    step.setArgument('plug_loads_television_annual_kwh', '620.0')
    step.setArgument('plug_loads_television_usage_multiplier', 1.0)
    step.setArgument('plug_loads_other_annual_kwh', '2457.0')
    step.setArgument('plug_loads_other_frac_sensible', '0.855')
    step.setArgument('plug_loads_other_frac_latent', '0.045')
    step.setArgument('plug_loads_other_usage_multiplier', 1.0)
    step.setArgument('plug_loads_well_pump_present', false)
    step.setArgument('plug_loads_well_pump_annual_kwh', Constants.Auto)
    step.setArgument('plug_loads_well_pump_usage_multiplier', 0.0)
    step.setArgument('plug_loads_vehicle_present', false)
    step.setArgument('plug_loads_vehicle_annual_kwh', Constants.Auto)
    step.setArgument('plug_loads_vehicle_usage_multiplier', 0.0)
    step.setArgument('fuel_loads_grill_present', false)
    step.setArgument('fuel_loads_grill_fuel_type', HPXML::FuelTypeNaturalGas)
    step.setArgument('fuel_loads_grill_annual_therm', Constants.Auto)
    step.setArgument('fuel_loads_grill_usage_multiplier', 0.0)
    step.setArgument('fuel_loads_lighting_present', false)
    step.setArgument('fuel_loads_lighting_fuel_type', HPXML::FuelTypeNaturalGas)
    step.setArgument('fuel_loads_lighting_annual_therm', Constants.Auto)
    step.setArgument('fuel_loads_lighting_usage_multiplier', 0.0)
    step.setArgument('fuel_loads_fireplace_present', false)
    step.setArgument('fuel_loads_fireplace_fuel_type', HPXML::FuelTypeNaturalGas)
    step.setArgument('fuel_loads_fireplace_annual_therm', Constants.Auto)
    step.setArgument('fuel_loads_fireplace_frac_sensible', Constants.Auto)
    step.setArgument('fuel_loads_fireplace_frac_latent', Constants.Auto)
    step.setArgument('fuel_loads_fireplace_usage_multiplier', 0.0)
    step.setArgument('pool_present', false)
    step.setArgument('pool_pump_annual_kwh', Constants.Auto)
    step.setArgument('pool_pump_usage_multiplier', 1.0)
    step.setArgument('pool_heater_type', HPXML::HeaterTypeElectricResistance)
    step.setArgument('pool_heater_annual_kwh', Constants.Auto)
    step.setArgument('pool_heater_annual_therm', Constants.Auto)
    step.setArgument('pool_heater_usage_multiplier', 1.0)
    step.setArgument('hot_tub_present', false)
    step.setArgument('hot_tub_pump_annual_kwh', Constants.Auto)
    step.setArgument('hot_tub_pump_usage_multiplier', 1.0)
    step.setArgument('hot_tub_heater_type', HPXML::HeaterTypeElectricResistance)
    step.setArgument('hot_tub_heater_annual_kwh', Constants.Auto)
    step.setArgument('hot_tub_heater_annual_therm', Constants.Auto)
    step.setArgument('hot_tub_heater_usage_multiplier', 1.0)
  end

  # Appliances
  if ['base-appliances-coal.osw'].include? osw_file
    step.setArgument('clothes_dryer_fuel_type', HPXML::FuelTypeCoal)
    step.setArgument('clothes_dryer_efficiency', '3.3')
    step.setArgument('clothes_dryer_vented_flow_rate', Constants.Auto)
    step.setArgument('cooking_range_oven_fuel_type', HPXML::FuelTypeCoal)
  elsif ['base-appliances-dehumidifier.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', '24000.0')
    step.setArgument('dehumidifier_type', HPXML::DehumidifierTypePortable)
  elsif ['base-appliances-dehumidifier-ief-portable.osw'].include? osw_file
    step.setArgument('dehumidifier_efficiency_type', 'IntegratedEnergyFactor')
    step.setArgument('dehumidifier_efficiency', '1.5')
  elsif ['base-appliances-dehumidifier-ief-whole-home.osw'].include? osw_file
    step.setArgument('dehumidifier_type', HPXML::DehumidifierTypeWholeHome)
  elsif ['base-appliances-gas.osw'].include? osw_file
    step.setArgument('clothes_dryer_fuel_type', HPXML::FuelTypeNaturalGas)
    step.setArgument('clothes_dryer_efficiency', '3.3')
    step.setArgument('clothes_dryer_vented_flow_rate', Constants.Auto)
    step.setArgument('cooking_range_oven_fuel_type', HPXML::FuelTypeNaturalGas)
  elsif ['base-appliances-modified.osw'].include? osw_file
    step.setArgument('clothes_washer_efficiency_type', 'ModifiedEnergyFactor')
    step.setArgument('clothes_washer_efficiency', '1.65')
    step.setArgument('clothes_dryer_efficiency_type', 'EnergyFactor')
    step.setArgument('clothes_dryer_efficiency', '4.29')
    step.setArgument('clothes_dryer_vented_flow_rate', '0.0')
    step.setArgument('dishwasher_efficiency_type', 'EnergyFactor')
    step.setArgument('dishwasher_efficiency', 0.7)
    step.setArgument('dishwasher_place_setting_capacity', '6')
  elsif ['base-appliances-none.osw'].include? osw_file
    step.setArgument('clothes_washer_location', 'none')
    step.setArgument('clothes_dryer_location', 'none')
    step.setArgument('dishwasher_location', 'none')
    step.setArgument('refrigerator_location', 'none')
    step.setArgument('cooking_range_oven_location', 'none')
  elsif ['base-appliances-oil.osw'].include? osw_file
    step.setArgument('clothes_dryer_fuel_type', HPXML::FuelTypeOil)
    step.setArgument('clothes_dryer_efficiency', '3.3')
    step.setArgument('clothes_dryer_vented_flow_rate', Constants.Auto)
    step.setArgument('cooking_range_oven_fuel_type', HPXML::FuelTypeOil)
  elsif ['base-appliances-propane.osw'].include? osw_file
    step.setArgument('clothes_dryer_fuel_type', HPXML::FuelTypePropane)
    step.setArgument('clothes_dryer_efficiency', '3.3')
    step.setArgument('clothes_dryer_vented_flow_rate', Constants.Auto)
    step.setArgument('cooking_range_oven_fuel_type', HPXML::FuelTypePropane)
  elsif ['base-appliances-wood.osw'].include? osw_file
    step.setArgument('clothes_dryer_fuel_type', HPXML::FuelTypeWoodCord)
    step.setArgument('clothes_dryer_efficiency', '3.3')
    step.setArgument('clothes_dryer_vented_flow_rate', Constants.Auto)
    step.setArgument('cooking_range_oven_fuel_type', HPXML::FuelTypeWoodCord)
  elsif ['base-atticroof-flat.osw'].include? osw_file
    step.setArgument('geometry_roof_type', 'flat')
    step.setArgument('roof_assembly_r', 25.8)
    step.setArgument('ducts_supply_leakage_value', 0.0)
    step.setArgument('ducts_return_leakage_value', 0.0)
    step.setArgument('ducts_supply_location', HPXML::LocationBasementConditioned)
    step.setArgument('ducts_return_location', HPXML::LocationBasementConditioned)
  elsif ['base-atticroof-radiant-barrier.osw'].include? osw_file
    step.setArgument('roof_radiant_barrier', true)
    step.setArgument('roof_radiant_barrier_grade', '2')
  elsif ['base-atticroof-unvented-insulated-roof.osw'].include? osw_file
    step.setArgument('ceiling_assembly_r', 2.1)
    step.setArgument('roof_assembly_r', 25.8)
  elsif ['base-atticroof-vented.osw'].include? osw_file
    step.setArgument('geometry_attic_type', HPXML::AtticTypeVented)
    step.setArgument('water_heater_location', HPXML::LocationAtticVented)
    step.setArgument('ducts_supply_location', HPXML::LocationAtticVented)
    step.setArgument('ducts_return_location', HPXML::LocationAtticVented)
  elsif ['base-bldgtype-single-family-attached.osw'].include? osw_file
    step.setArgument('geometry_unit_type', HPXML::ResidentialTypeSFA)
    step.setArgument('geometry_cfa', 1800.0)
    step.setArgument('geometry_corridor_position', 'None')
    step.setArgument('geometry_building_num_units', 3)
    step.setArgument('geometry_horizontal_location', 'Left')
    step.setArgument('window_front_wwr', 0.18)
    step.setArgument('window_back_wwr', 0.18)
    step.setArgument('window_left_wwr', 0.18)
    step.setArgument('window_right_wwr', 0.18)
    step.setArgument('window_area_front', 0)
    step.setArgument('window_area_back', 0)
    step.setArgument('window_area_left', 0)
    step.setArgument('window_area_right', 0)
    step.setArgument('heating_system_heating_capacity', '24000.0')
    step.setArgument('plug_loads_other_annual_kwh', '1638.0')
  elsif ['base-bldgtype-multifamily.osw'].include? osw_file
    step.setArgument('geometry_unit_type', HPXML::ResidentialTypeApartment)
    step.setArgument('geometry_cfa', 900.0)
    step.setArgument('geometry_corridor_position', 'None')
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeBasementUnconditioned)
    step.setArgument('geometry_level', 'Middle')
    step.setArgument('geometry_horizontal_location', 'Left')
    step.setArgument('geometry_building_num_units', 6)
    step.setArgument('geometry_building_num_bedrooms', 6 * 3)
    step.setArgument('geometry_num_floors_above_grade', 3)
    step.setArgument('window_front_wwr', 0.18)
    step.setArgument('window_back_wwr', 0.18)
    step.setArgument('window_left_wwr', 0.18)
    step.setArgument('window_right_wwr', 0.18)
    step.setArgument('window_area_front', 0)
    step.setArgument('window_area_back', 0)
    step.setArgument('window_area_left', 0)
    step.setArgument('window_area_right', 0)
    step.setArgument('heating_system_heating_capacity', '12000.0')
    step.setArgument('cooling_system_cooling_capacity', '12000.0')
    step.setArgument('ducts_supply_leakage_value', 0.0)
    step.setArgument('ducts_return_leakage_value', 0.0)
    step.setArgument('ducts_supply_location', HPXML::LocationLivingSpace)
    step.setArgument('ducts_return_location', HPXML::LocationLivingSpace)
    step.setArgument('ducts_supply_insulation_r', 0.0)
    step.setArgument('ducts_return_insulation_r', 0.0)
    step.setArgument('ducts_number_of_return_registers', '1')
    step.setArgument('door_area', 20.0)
    step.setArgument('plug_loads_other_annual_kwh', '819.0')
  elsif ['base-bldgtype-multifamily-shared-boiler-only-baseboard.osw'].include? osw_file
    step.setArgument('heating_system_type', "Shared #{HPXML::HVACTypeBoiler} w/ Baseboard")
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-bldgtype-multifamily-shared-boiler-only-fan-coil.osw'].include? osw_file
    step.setArgument('heating_system_type', "Shared #{HPXML::HVACTypeBoiler} w/ Ductless Fan Coil")
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-bldgtype-multifamily-shared-mechvent.osw'].include? osw_file
    step.setArgument('mech_vent_fan_type', HPXML::MechVentTypeSupply)
    step.setArgument('mech_vent_flow_rate', 800)
    step.setArgument('mech_vent_fan_power', '240')
    step.setArgument('mech_vent_num_units_served', 10)
    step.setArgument('shared_mech_vent_frac_recirculation', 0.5)
    step.setArgument('mech_vent_fan_type_2', HPXML::MechVentTypeExhaust)
    step.setArgument('mech_vent_flow_rate_2', 72)
    step.setArgument('mech_vent_fan_power_2', '26')
  elsif ['base-bldgtype-multifamily-shared-mechvent-preconditioning.osw'].include? osw_file
    step.setArgument('shared_mech_vent_preheating_fuel', HPXML::FuelTypeNaturalGas)
    step.setArgument('shared_mech_vent_preheating_efficiency', 0.92)
    step.setArgument('shared_mech_vent_preheating_fraction_heat_load_served', 0.7)
    step.setArgument('shared_mech_vent_precooling_fuel', HPXML::FuelTypeElectricity)
    step.setArgument('shared_mech_vent_precooling_efficiency', 4.0)
    step.setArgument('shared_mech_vent_precooling_fraction_cool_load_served', 0.8)
  elsif ['base-bldgtype-multifamily-shared-pv.osw'].include? osw_file
    step.setArgument('pv_system_num_units_served_1', 6)
    step.setArgument('pv_system_location_1', HPXML::LocationGround)
    step.setArgument('pv_system_module_type_1', HPXML::PVModuleTypeStandard)
    step.setArgument('pv_system_tracking_1', HPXML::PVTrackingTypeFixed)
    step.setArgument('pv_system_array_azimuth_1', 225)
    step.setArgument('pv_system_array_tilt_1', '30')
    step.setArgument('pv_system_max_power_output_1', 30000)
    step.setArgument('pv_system_inverter_efficiency_1', 0.96)
    step.setArgument('pv_system_system_losses_fraction_1', 0.14)
  elsif ['base-bldgtype-multifamily-shared-water-heater.osw'].include? osw_file
    step.setArgument('water_heater_fuel_type', HPXML::FuelTypeNaturalGas)
    step.setArgument('water_heater_num_units_served', 6)
    step.setArgument('water_heater_tank_volume', '120')
    step.setArgument('water_heater_efficiency', 0.59)
    step.setArgument('water_heater_recovery_efficiency', '0.76')
  end

  # DHW
  if ['base-dhw-combi-tankless.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeCombiTankless)
    step.setArgument('water_heater_tank_volume', Constants.Auto)
  elsif ['base-dhw-combi-tankless-outside.osw'].include? osw_file
    step.setArgument('water_heater_location', HPXML::LocationOtherExterior)
  elsif ['base-dhw-dwhr.osw'].include? osw_file
    step.setArgument('dwhr_facilities_connected', HPXML::DWHRFacilitiesConnectedAll)
  elsif ['base-dhw-indirect.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeCombiStorage)
    step.setArgument('water_heater_tank_volume', '50')
  elsif ['base-dhw-indirect-outside.osw'].include? osw_file
    step.setArgument('water_heater_location', HPXML::LocationOtherExterior)
  elsif ['base-dhw-indirect-standbyloss.osw'].include? osw_file
    step.setArgument('water_heater_standby_loss', 1.0)
  elsif ['base-dhw-indirect-with-solar-fraction.osw'].include? osw_file
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_solar_fraction', 0.65)
  elsif ['base-dhw-jacket-electric.osw'].include? osw_file
    step.setArgument('water_heater_jacket_rvalue', 10.0)
  elsif ['base-dhw-jacket-gas.osw'].include? osw_file
    step.setArgument('water_heater_jacket_rvalue', 10.0)
  elsif ['base-dhw-jacket-hpwh.osw'].include? osw_file
    step.setArgument('water_heater_jacket_rvalue', 10.0)
  elsif ['base-dhw-jacket-indirect.osw'].include? osw_file
    step.setArgument('water_heater_jacket_rvalue', 10.0)
  elsif ['base-dhw-low-flow-fixtures.osw'].include? osw_file
    step.setArgument('water_fixtures_sink_low_flow', true)
  elsif ['base-dhw-none.osw'].include? osw_file
    step.setArgument('water_heater_type', 'none')
    step.setArgument('dishwasher_location', 'none')
  elsif ['base-dhw-recirc-demand.osw'].include? osw_file
    step.setArgument('dhw_distribution_system_type', HPXML::DHWDistTypeRecirc)
    step.setArgument('dhw_distribution_recirc_control_type', HPXML::DHWRecirControlTypeSensor)
    step.setArgument('dhw_distribution_pipe_r', '3.0')
  elsif ['base-dhw-recirc-manual.osw'].include? osw_file
    step.setArgument('dhw_distribution_system_type', HPXML::DHWDistTypeRecirc)
    step.setArgument('dhw_distribution_recirc_control_type', HPXML::DHWRecirControlTypeManual)
    step.setArgument('dhw_distribution_pipe_r', '3.0')
  elsif ['base-dhw-recirc-nocontrol.osw'].include? osw_file
    step.setArgument('dhw_distribution_system_type', HPXML::DHWDistTypeRecirc)
  elsif ['base-dhw-recirc-temperature.osw'].include? osw_file
    step.setArgument('dhw_distribution_system_type', HPXML::DHWDistTypeRecirc)
    step.setArgument('dhw_distribution_recirc_control_type', HPXML::DHWRecirControlTypeTemperature)
  elsif ['base-dhw-recirc-timer.osw'].include? osw_file
    step.setArgument('dhw_distribution_system_type', HPXML::DHWDistTypeRecirc)
    step.setArgument('dhw_distribution_recirc_control_type', HPXML::DHWRecirControlTypeTimer)
  elsif ['base-dhw-solar-direct-evacuated-tube.osw'].include? osw_file
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_storage_volume', '60')
  elsif ['base-dhw-solar-direct-flat-plate.osw'].include? osw_file
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_collector_type', HPXML::SolarThermalTypeSingleGlazing)
    step.setArgument('solar_thermal_collector_rated_optical_efficiency', 0.77)
    step.setArgument('solar_thermal_collector_rated_thermal_losses', 0.793)
    step.setArgument('solar_thermal_storage_volume', '60')
  elsif ['base-dhw-solar-direct-ics.osw'].include? osw_file
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_collector_type', HPXML::SolarThermalTypeICS)
    step.setArgument('solar_thermal_collector_rated_optical_efficiency', 0.77)
    step.setArgument('solar_thermal_collector_rated_thermal_losses', 0.793)
    step.setArgument('solar_thermal_storage_volume', '60')
  elsif ['base-dhw-solar-fraction.osw'].include? osw_file
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_solar_fraction', 0.65)
  elsif ['base-dhw-solar-indirect-flat-plate.osw'].include? osw_file
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_collector_loop_type', HPXML::SolarThermalLoopTypeIndirect)
    step.setArgument('solar_thermal_collector_type', HPXML::SolarThermalTypeSingleGlazing)
    step.setArgument('solar_thermal_collector_rated_optical_efficiency', 0.77)
    step.setArgument('solar_thermal_collector_rated_thermal_losses', 0.793)
    step.setArgument('solar_thermal_storage_volume', '60')
  elsif ['base-dhw-solar-thermosyphon-flat-plate.osw'].include? osw_file
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_collector_loop_type', HPXML::SolarThermalLoopTypeThermosyphon)
    step.setArgument('solar_thermal_collector_type', HPXML::SolarThermalTypeSingleGlazing)
    step.setArgument('solar_thermal_collector_rated_optical_efficiency', 0.77)
    step.setArgument('solar_thermal_collector_rated_thermal_losses', 0.793)
    step.setArgument('solar_thermal_storage_volume', '60')
  elsif ['base-dhw-tank-coal.osw'].include? osw_file
    step.setArgument('water_heater_fuel_type', HPXML::FuelTypeCoal)
    step.setArgument('water_heater_tank_volume', '50')
    step.setArgument('water_heater_efficiency', 0.59)
  elsif ['base-dhw-tank-elec-uef.osw'].include? osw_file
    step.setArgument('water_heater_tank_volume', '30')
    step.setArgument('water_heater_efficiency_type', 'UniformEnergyFactor')
    step.setArgument('water_heater_efficiency', 0.93)
    step.setArgument('water_heater_usage_bin', HPXML::WaterHeaterUsageBinLow)
    step.setArgument('water_heater_recovery_efficiency', 0.98)
  elsif ['base-dhw-tank-gas.osw'].include? osw_file
    step.setArgument('water_heater_fuel_type', HPXML::FuelTypeNaturalGas)
    step.setArgument('water_heater_tank_volume', '50')
    step.setArgument('water_heater_efficiency', 0.59)
  elsif ['base-dhw-tank-gas-uef.osw'].include? osw_file
    step.setArgument('water_heater_fuel_type', HPXML::FuelTypeNaturalGas)
    step.setArgument('water_heater_tank_volume', '30')
    step.setArgument('water_heater_efficiency_type', 'UniformEnergyFactor')
    step.setArgument('water_heater_efficiency', 0.59)
    step.setArgument('water_heater_usage_bin', HPXML::WaterHeaterUsageBinMedium)
    step.setArgument('water_heater_recovery_efficiency', 0.75)
  elsif ['base-dhw-tank-gas-outside.osw'].include? osw_file
    step.setArgument('water_heater_location', HPXML::LocationOtherExterior)
  elsif ['base-dhw-tank-heat-pump.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeHeatPump)
    step.setArgument('water_heater_tank_volume', '80')
    step.setArgument('water_heater_efficiency', 2.3)
  elsif ['base-dhw-tank-heat-pump-outside.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeHeatPump)
    step.setArgument('water_heater_location', HPXML::LocationOtherExterior)
    step.setArgument('water_heater_tank_volume', '80')
    step.setArgument('water_heater_efficiency', 2.3)
  elsif ['base-dhw-tank-heat-pump-uef.osw'].include? osw_file
    step.setArgument('water_heater_tank_volume', '50')
    step.setArgument('water_heater_efficiency_type', 'UniformEnergyFactor')
    step.setArgument('water_heater_efficiency', 3.75)
    step.setArgument('water_heater_usage_bin', HPXML::WaterHeaterUsageBinMedium)
  elsif ['base-dhw-tank-heat-pump-with-solar.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeHeatPump)
    step.setArgument('water_heater_tank_volume', '80')
    step.setArgument('water_heater_efficiency', 2.3)
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_collector_loop_type', HPXML::SolarThermalLoopTypeIndirect)
    step.setArgument('solar_thermal_collector_type', HPXML::SolarThermalTypeSingleGlazing)
    step.setArgument('solar_thermal_collector_rated_optical_efficiency', 0.77)
    step.setArgument('solar_thermal_collector_rated_thermal_losses', 0.793)
    step.setArgument('solar_thermal_storage_volume', '60')
  elsif ['base-dhw-tank-heat-pump-with-solar-fraction.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeHeatPump)
    step.setArgument('water_heater_tank_volume', '80')
    step.setArgument('water_heater_efficiency', 2.3)
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_solar_fraction', 0.65)
  elsif ['base-dhw-tankless-electric.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeTankless)
    step.setArgument('water_heater_tank_volume', Constants.Auto)
    step.setArgument('water_heater_efficiency', 0.99)
  elsif ['base-dhw-tankless-electric-outside.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeTankless)
    step.setArgument('water_heater_location', HPXML::LocationOtherExterior)
    step.setArgument('water_heater_tank_volume', Constants.Auto)
    step.setArgument('water_heater_efficiency', 0.99)
  elsif ['base-dhw-tankless-electric-uef.osw'].include? osw_file
    step.setArgument('water_heater_efficiency_type', 'UniformEnergyFactor')
    step.setArgument('water_heater_efficiency', 0.98)
  elsif ['base-dhw-tankless-gas.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeTankless)
    step.setArgument('water_heater_fuel_type', HPXML::FuelTypeNaturalGas)
    step.setArgument('water_heater_tank_volume', Constants.Auto)
    step.setArgument('water_heater_efficiency', 0.82)
  elsif ['base-dhw-tankless-gas-uef.osw'].include? osw_file
    step.setArgument('water_heater_efficiency_type', 'UniformEnergyFactor')
    step.setArgument('water_heater_efficiency', 0.93)
  elsif ['base-dhw-tankless-gas-with-solar.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeTankless)
    step.setArgument('water_heater_fuel_type', HPXML::FuelTypeNaturalGas)
    step.setArgument('water_heater_tank_volume', Constants.Auto)
    step.setArgument('water_heater_efficiency', 0.82)
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_collector_loop_type', HPXML::SolarThermalLoopTypeIndirect)
    step.setArgument('solar_thermal_collector_type', HPXML::SolarThermalTypeSingleGlazing)
    step.setArgument('solar_thermal_collector_rated_optical_efficiency', 0.77)
    step.setArgument('solar_thermal_collector_rated_thermal_losses', 0.793)
    step.setArgument('solar_thermal_storage_volume', '60')
  elsif ['base-dhw-tankless-gas-with-solar-fraction.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeTankless)
    step.setArgument('water_heater_fuel_type', HPXML::FuelTypeNaturalGas)
    step.setArgument('water_heater_tank_volume', Constants.Auto)
    step.setArgument('water_heater_efficiency', 0.82)
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_solar_fraction', 0.65)
  elsif ['base-dhw-tankless-propane.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeTankless)
    step.setArgument('water_heater_fuel_type', HPXML::FuelTypePropane)
    step.setArgument('water_heater_tank_volume', Constants.Auto)
    step.setArgument('water_heater_efficiency', 0.82)
  elsif ['base-dhw-tank-oil.osw'].include? osw_file
    step.setArgument('water_heater_fuel_type', HPXML::FuelTypeOil)
    step.setArgument('water_heater_tank_volume', '50')
    step.setArgument('water_heater_efficiency', 0.59)
  elsif ['base-dhw-tank-wood.osw'].include? osw_file
    step.setArgument('water_heater_fuel_type', HPXML::FuelTypeWoodCord)
    step.setArgument('water_heater_tank_volume', '50')
    step.setArgument('water_heater_efficiency', 0.59)
  end

  # Enclosure
  if ['base-enclosure-2stories.osw'].include? osw_file
    step.setArgument('geometry_cfa', 4050.0)
    step.setArgument('geometry_num_floors_above_grade', 2)
    step.setArgument('window_area_front', 216.0)
    step.setArgument('window_area_back', 216.0)
    step.setArgument('window_area_left', 144.0)
    step.setArgument('window_area_right', 144.0)
    step.setArgument('heating_system_heating_capacity', '48000.0')
    step.setArgument('cooling_system_cooling_capacity', '36000.0')
    step.setArgument('ducts_supply_surface_area', '112.5')
    step.setArgument('ducts_return_surface_area', '37.5')
    step.setArgument('ducts_number_of_return_registers', '3')
    step.setArgument('plug_loads_other_annual_kwh', '3685.5')
  elsif ['base-enclosure-2stories-garage.osw'].include? osw_file
    step.setArgument('geometry_cfa', 3250.0)
    step.setArgument('geometry_garage_width', 20.0)
    step.setArgument('ducts_supply_surface_area', '112.5')
    step.setArgument('ducts_return_surface_area', '37.5')
    step.setArgument('plug_loads_other_annual_kwh', '2957.5')
  elsif ['base-enclosure-beds-1.osw'].include? osw_file
    step.setArgument('geometry_num_bedrooms', 1)
    step.setArgument('geometry_num_bathrooms', '1')
    step.setArgument('geometry_num_occupants', '1')
    step.setArgument('plug_loads_television_annual_kwh', '482.0')
  elsif ['base-enclosure-beds-2.osw'].include? osw_file
    step.setArgument('geometry_num_bedrooms', 2)
    step.setArgument('geometry_num_bathrooms', '1')
    step.setArgument('geometry_num_occupants', '2')
    step.setArgument('plug_loads_television_annual_kwh', '551.0')
  elsif ['base-enclosure-beds-4.osw'].include? osw_file
    step.setArgument('geometry_num_bedrooms', 4)
    step.setArgument('geometry_num_occupants', '4')
    step.setArgument('plug_loads_television_annual_kwh', '689.0')
  elsif ['base-enclosure-beds-5.osw'].include? osw_file
    step.setArgument('geometry_num_bedrooms', 5)
    step.setArgument('geometry_num_bathrooms', '3')
    step.setArgument('geometry_num_occupants', '5')
    step.setArgument('plug_loads_television_annual_kwh', '758.0')
  elsif ['base-enclosure-garage.osw'].include? osw_file
    step.setArgument('geometry_garage_width', 30.0)
    step.setArgument('geometry_garage_protrusion', 1.0)
    step.setArgument('window_area_front', 12.0)
    step.setArgument('ducts_supply_location', HPXML::LocationGarage)
    step.setArgument('ducts_return_location', HPXML::LocationGarage)
    step.setArgument('water_heater_location', HPXML::LocationGarage)
    step.setArgument('clothes_washer_location', HPXML::LocationGarage)
    step.setArgument('clothes_dryer_location', HPXML::LocationGarage)
    step.setArgument('dishwasher_location', HPXML::LocationGarage)
    step.setArgument('refrigerator_location', HPXML::LocationGarage)
    step.setArgument('cooking_range_oven_location', HPXML::LocationGarage)
  elsif ['base-enclosure-infil-ach-house-pressure.osw'].include? osw_file
    step.setArgument('air_leakage_house_pressure', 45)
    step.setArgument('air_leakage_value', 2.8014)
  elsif ['base-enclosure-infil-cfm-house-pressure.osw'].include? osw_file
    step.setArgument('air_leakage_house_pressure', 45)
    step.setArgument('air_leakage_value', 1008.5039999999999)
  elsif ['base-enclosure-infil-cfm50.osw'].include? osw_file
    step.setArgument('air_leakage_units', HPXML::UnitsCFM)
    step.setArgument('air_leakage_value', 1080)
  elsif ['base-enclosure-infil-flue.osw'].include? osw_file
    step.setArgument('geometry_has_flue_or_chimney', 'true')
  elsif ['base-enclosure-infil-natural-ach.osw'].include? osw_file
    step.setArgument('air_leakage_units', HPXML::UnitsACHNatural)
    step.setArgument('air_leakage_value', 0.2)
  elsif ['base-enclosure-other-heated-space.osw'].include? osw_file
    step.setArgument('geometry_unit_type', HPXML::ResidentialTypeApartment)
    step.setArgument('ducts_supply_location', HPXML::LocationOtherHeatedSpace)
    step.setArgument('ducts_return_location', HPXML::LocationOtherHeatedSpace)
    step.setArgument('water_heater_location', HPXML::LocationOtherHeatedSpace)
    step.setArgument('clothes_washer_location', HPXML::LocationOtherHeatedSpace)
    step.setArgument('clothes_dryer_location', HPXML::LocationOtherHeatedSpace)
    step.setArgument('dishwasher_location', HPXML::LocationOtherHeatedSpace)
    step.setArgument('refrigerator_location', HPXML::LocationOtherHeatedSpace)
    step.setArgument('cooking_range_oven_location', HPXML::LocationOtherHeatedSpace)
  elsif ['base-enclosure-other-housing-unit.osw'].include? osw_file
    step.setArgument('geometry_unit_type', HPXML::ResidentialTypeApartment)
    step.setArgument('ducts_supply_location', HPXML::LocationOtherHousingUnit)
    step.setArgument('ducts_return_location', HPXML::LocationOtherHousingUnit)
    step.setArgument('water_heater_location', HPXML::LocationOtherHousingUnit)
    step.setArgument('clothes_washer_location', HPXML::LocationOtherHousingUnit)
    step.setArgument('clothes_dryer_location', HPXML::LocationOtherHousingUnit)
    step.setArgument('dishwasher_location', HPXML::LocationOtherHousingUnit)
    step.setArgument('refrigerator_location', HPXML::LocationOtherHousingUnit)
    step.setArgument('cooking_range_oven_location', HPXML::LocationOtherHousingUnit)
  elsif ['base-enclosure-other-multifamily-buffer-space.osw'].include? osw_file
    step.setArgument('geometry_unit_type', HPXML::ResidentialTypeApartment)
    step.setArgument('ducts_supply_location', HPXML::LocationOtherMultifamilyBufferSpace)
    step.setArgument('ducts_return_location', HPXML::LocationOtherMultifamilyBufferSpace)
    step.setArgument('water_heater_location', HPXML::LocationOtherMultifamilyBufferSpace)
    step.setArgument('clothes_washer_location', HPXML::LocationOtherMultifamilyBufferSpace)
    step.setArgument('clothes_dryer_location', HPXML::LocationOtherMultifamilyBufferSpace)
    step.setArgument('dishwasher_location', HPXML::LocationOtherMultifamilyBufferSpace)
    step.setArgument('refrigerator_location', HPXML::LocationOtherMultifamilyBufferSpace)
    step.setArgument('cooking_range_oven_location', HPXML::LocationOtherMultifamilyBufferSpace)
  elsif ['base-enclosure-other-non-freezing-space.osw'].include? osw_file
    step.setArgument('geometry_unit_type', HPXML::ResidentialTypeApartment)
    step.setArgument('ducts_supply_location', HPXML::LocationOtherNonFreezingSpace)
    step.setArgument('ducts_return_location', HPXML::LocationOtherNonFreezingSpace)
    step.setArgument('water_heater_location', HPXML::LocationOtherNonFreezingSpace)
    step.setArgument('clothes_washer_location', HPXML::LocationOtherNonFreezingSpace)
    step.setArgument('clothes_dryer_location', HPXML::LocationOtherNonFreezingSpace)
    step.setArgument('dishwasher_location', HPXML::LocationOtherNonFreezingSpace)
    step.setArgument('refrigerator_location', HPXML::LocationOtherNonFreezingSpace)
    step.setArgument('cooking_range_oven_location', HPXML::LocationOtherNonFreezingSpace)
  elsif ['base-enclosure-overhangs.osw'].include? osw_file
    step.setArgument('overhangs_front_distance_to_top_of_window', 1.0)
    step.setArgument('overhangs_back_depth', 2.5)
    step.setArgument('overhangs_left_depth', 1.5)
    step.setArgument('overhangs_left_distance_to_top_of_window', 2.0)
    step.setArgument('overhangs_right_depth', 1.5)
    step.setArgument('overhangs_right_distance_to_top_of_window', 2.0)
  elsif ['base-enclosure-windows-none.osw'].include? osw_file
    step.setArgument('window_area_front', 0)
    step.setArgument('window_area_back', 0)
    step.setArgument('window_area_left', 0)
    step.setArgument('window_area_right', 0)
  end

  # Foundation
  if ['base-foundation-ambient.osw'].include? osw_file
    step.setArgument('geometry_cfa', 1350.0)
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeAmbient)
    step.setArgument('geometry_rim_joist_height', 0)
    step.setArgument('floor_assembly_r', 18.7)
    step.setArgument('ducts_number_of_return_registers', '1')
    step.setArgument('plug_loads_other_annual_kwh', '1228.5')
  elsif ['base-foundation-conditioned-basement-slab-insulation.osw'].include? osw_file
    step.setArgument('slab_under_insulation_r', 10)
    step.setArgument('slab_under_width', 4)
  elsif ['base-foundation-conditioned-basement-wall-interior-insulation.osw'].include? osw_file
    step.setArgument('foundation_wall_insulation_r', 18.9)
    step.setArgument('foundation_wall_insulation_distance_to_top', '1.0')
  elsif ['base-foundation-slab.osw'].include? osw_file
    step.setArgument('geometry_cfa', 1350.0)
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeSlab)
    step.setArgument('geometry_foundation_height', 0.0)
    step.setArgument('geometry_foundation_height_above_grade', 0.0)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', Constants.Auto)
    step.setArgument('slab_under_insulation_r', 5)
    step.setArgument('slab_under_width', 999)
    step.setArgument('slab_carpet_fraction', '1.0')
    step.setArgument('slab_carpet_r', '2.5')
    step.setArgument('ducts_supply_location', HPXML::LocationUnderSlab)
    step.setArgument('ducts_return_location', HPXML::LocationUnderSlab)
    step.setArgument('ducts_number_of_return_registers', '1')
    step.setArgument('plug_loads_other_annual_kwh', '1228.5')
  elsif ['base-foundation-unconditioned-basement.osw'].include? osw_file
    step.setArgument('geometry_cfa', 1350.0)
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeBasementUnconditioned)
    step.setArgument('floor_assembly_r', 18.7)
    step.setArgument('foundation_wall_insulation_r', 0)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '0.0')
    step.setArgument('rim_joist_assembly_r', 4.0)
    step.setArgument('ducts_supply_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('ducts_return_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('ducts_number_of_return_registers', '1')
    step.setArgument('water_heater_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('clothes_washer_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('clothes_dryer_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('dishwasher_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('refrigerator_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('cooking_range_oven_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('plug_loads_other_annual_kwh', '1228.5')
  elsif ['base-foundation-unconditioned-basement-above-grade.osw'].include? osw_file
    step.setArgument('geometry_cfa', 1350.0)
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeBasementUnconditioned)
    step.setArgument('geometry_foundation_height_above_grade', 4.0)
    step.setArgument('foundation_wall_insulation_r', 0)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '0.0')
    step.setArgument('ducts_supply_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('ducts_return_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('water_heater_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('clothes_washer_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('clothes_dryer_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('dishwasher_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('refrigerator_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('cooking_range_oven_location', HPXML::LocationBasementUnconditioned)
    step.setArgument('plug_loads_other_annual_kwh', '1228.5')
  elsif ['base-foundation-unconditioned-basement-assembly-r.osw'].include? osw_file
    step.setArgument('foundation_wall_assembly_r', 10.69)
  elsif ['base-foundation-unconditioned-basement-wall-insulation.osw'].include? osw_file
    step.setArgument('floor_assembly_r', 2.1)
    step.setArgument('foundation_wall_insulation_r', 8.9)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '4.0')
    step.setArgument('rim_joist_assembly_r', 23.0)
  elsif ['base-foundation-unvented-crawlspace.osw'].include? osw_file
    step.setArgument('geometry_cfa', 1350.0)
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeCrawlspaceUnvented)
    step.setArgument('geometry_foundation_height', 4.0)
    step.setArgument('floor_assembly_r', 18.7)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '4.0')
    step.setArgument('slab_carpet_r', '2.5')
    step.setArgument('ducts_supply_location', HPXML::LocationCrawlspaceUnvented)
    step.setArgument('ducts_return_location', HPXML::LocationCrawlspaceUnvented)
    step.setArgument('ducts_number_of_return_registers', '1')
    step.setArgument('water_heater_location', HPXML::LocationCrawlspaceUnvented)
    step.setArgument('plug_loads_other_annual_kwh', '1228.5')
  elsif ['base-foundation-vented-crawlspace.osw'].include? osw_file
    step.setArgument('geometry_cfa', 1350.0)
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeCrawlspaceVented)
    step.setArgument('geometry_foundation_height', 4.0)
    step.setArgument('floor_assembly_r', 18.7)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '4.0')
    step.setArgument('slab_carpet_r', '2.5')
    step.setArgument('ducts_supply_location', HPXML::LocationCrawlspaceVented)
    step.setArgument('ducts_return_location', HPXML::LocationCrawlspaceVented)
    step.setArgument('ducts_number_of_return_registers', '1')
    step.setArgument('water_heater_location', HPXML::LocationCrawlspaceVented)
    step.setArgument('plug_loads_other_annual_kwh', '1228.5')
  elsif ['base-foundation-walkout-basement.osw'].include? osw_file
    step.setArgument('geometry_foundation_height_above_grade', 5.0)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '4.0')
  end

  # HVAC
  if ['base-hvac-air-to-air-heat-pump-1-speed.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_type', 'none')
    step.setArgument('heat_pump_type', HPXML::HVACTypeHeatPumpAirToAir)
    step.setArgument('heat_pump_heating_capacity_17_f', '22680.0')
    step.setArgument('heat_pump_backup_fuel', HPXML::FuelTypeElectricity)
  elsif ['base-hvac-air-to-air-heat-pump-1-speed-cooling-only.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', '0.0')
    step.setArgument('heat_pump_heating_capacity_17_f', '0.0')
    step.setArgument('heat_pump_fraction_heat_load_served', 0)
    step.setArgument('heat_pump_backup_fuel', 'none')
  elsif ['base-hvac-air-to-air-heat-pump-1-speed-heating-only.osw'].include? osw_file
    step.setArgument('heat_pump_cooling_capacity', '0.0')
    step.setArgument('heat_pump_fraction_cool_load_served', 0)
  elsif ['base-hvac-air-to-air-heat-pump-2-speed.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_type', 'none')
    step.setArgument('heat_pump_type', HPXML::HVACTypeHeatPumpAirToAir)
    step.setArgument('heat_pump_heating_efficiency', 9.3)
    step.setArgument('heat_pump_cooling_compressor_type', HPXML::HVACCompressorTypeTwoStage)
    step.setArgument('heat_pump_heating_capacity_17_f', '21240.0')
    step.setArgument('heat_pump_cooling_efficiency', 18.0)
    step.setArgument('heat_pump_backup_fuel', HPXML::FuelTypeElectricity)
  elsif ['base-hvac-air-to-air-heat-pump-var-speed.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_type', 'none')
    step.setArgument('heat_pump_type', HPXML::HVACTypeHeatPumpAirToAir)
    step.setArgument('heat_pump_heating_efficiency', 10.0)
    step.setArgument('heat_pump_cooling_compressor_type', HPXML::HVACCompressorTypeVariableSpeed)
    step.setArgument('heat_pump_cooling_sensible_heat_fraction', 0.78)
    step.setArgument('heat_pump_heating_capacity_17_f', '23040.0')
    step.setArgument('heat_pump_cooling_efficiency', 22.0)
    step.setArgument('heat_pump_backup_fuel', HPXML::FuelTypeElectricity)
  elsif ['base-hvac-autosize.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-air-to-air-heat-pump-1-speed.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-air-to-air-heat-pump-1-speed-cooling-only.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-air-to-air-heat-pump-1-speed-heating-only.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-air-to-air-heat-pump-1-speed-manual-s-oversize-allowances.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-air-to-air-heat-pump-2-speed.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-air-to-air-heat-pump-2-speed-manual-s-oversize-allowances.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-air-to-air-heat-pump-var-speed.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-air-to-air-heat-pump-var-speed-manual-s-oversize-allowances.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-boiler-elec-only.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-boiler-gas-central-ac-1-speed.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-boiler-gas-only.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-central-ac-only-1-speed.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-central-ac-only-2-speed.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-central-ac-only-var-speed.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-central-ac-plus-air-to-air-heat-pump-heating.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-dual-fuel-air-to-air-heat-pump-1-speed.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-dual-fuel-mini-split-heat-pump-ducted.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-elec-resistance-only.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-evap-cooler-furnace-gas.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-floor-furnace-propane-only.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-furnace-elec-only.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-furnace-gas-central-ac-2-speed.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-furnace-gas-central-ac-var-speed.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-furnace-gas-only.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-furnace-gas-room-ac.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-ground-to-air-heat-pump.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-ground-to-air-heat-pump-cooling-only.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-ground-to-air-heat-pump-heating-only.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-ground-to-air-heat-pump-s-oversize-allowances.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-mini-split-heat-pump-ducted.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-mini-split-heat-pump-ducted-cooling-only.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-mini-split-heat-pump-ducted-heating-only.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-mini-split-heat-pump-ducted-manual-s-oversize-allowances.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_heating_capacity_17_f', Constants.Auto)
    step.setArgument('heat_pump_backup_heating_capacity', Constants.Auto)
    step.setArgument('heat_pump_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-mini-split-air-conditioner-only-ducted.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-room-ac-only.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-stove-oil-only.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-autosize-wall-furnace-elec-only.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', Constants.Auto)
    step.setArgument('cooling_system_cooling_capacity', Constants.Auto)
  elsif ['base-hvac-boiler-coal-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeBoiler)
    step.setArgument('heating_system_fuel', HPXML::FuelTypeCoal)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-boiler-elec-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeBoiler)
    step.setArgument('heating_system_fuel', HPXML::FuelTypeElectricity)
    step.setArgument('heating_system_heating_efficiency', 0.98)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeBoiler)
  elsif ['base-hvac-boiler-gas-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeBoiler)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-boiler-oil-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeBoiler)
    step.setArgument('heating_system_fuel', HPXML::FuelTypeOil)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-boiler-propane-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeBoiler)
    step.setArgument('heating_system_fuel', HPXML::FuelTypePropane)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-boiler-wood-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeBoiler)
    step.setArgument('heating_system_fuel', HPXML::FuelTypeWoodCord)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-central-ac-only-1-speed.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
  elsif ['base-hvac-central-ac-only-2-speed.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_cooling_efficiency', 18.0)
    step.setArgument('cooling_system_cooling_compressor_type', HPXML::HVACCompressorTypeTwoStage)
  elsif ['base-hvac-central-ac-only-var-speed.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_cooling_efficiency', 24.0)
    step.setArgument('cooling_system_cooling_compressor_type', HPXML::HVACCompressorTypeVariableSpeed)
    step.setArgument('cooling_system_cooling_sensible_heat_fraction', 0.78)
  elsif ['base-hvac-central-ac-plus-air-to-air-heat-pump-heating.osw'].include? osw_file
    step.setArgument('heat_pump_type', HPXML::HVACTypeHeatPumpAirToAir)
    step.setArgument('heat_pump_heating_efficiency', 7.7)
    step.setArgument('heat_pump_heating_capacity_17_f', '22680.0')
    step.setArgument('heat_pump_fraction_cool_load_served', 0)
    step.setArgument('heat_pump_backup_fuel', HPXML::FuelTypeElectricity)
  elsif ['base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.osw'].include? osw_file
    step.setArgument('cooling_system_type', 'none')
    step.setArgument('heat_pump_heating_efficiency', 7.7)
    step.setArgument('heat_pump_heating_capacity_17_f', '22680.0')
    step.setArgument('heat_pump_backup_fuel', HPXML::FuelTypeNaturalGas)
    step.setArgument('heat_pump_backup_heating_efficiency', 0.95)
    step.setArgument('heat_pump_backup_heating_switchover_temp', 25)
  elsif ['base-hvac-dual-fuel-air-to-air-heat-pump-1-speed-electric.osw'].include? osw_file
    step.setArgument('heat_pump_backup_fuel', HPXML::FuelTypeElectricity)
    step.setArgument('heat_pump_backup_heating_efficiency', 1.0)
  elsif ['base-hvac-dual-fuel-air-to-air-heat-pump-2-speed.osw'].include? osw_file
    step.setArgument('heat_pump_backup_fuel', HPXML::FuelTypeNaturalGas)
    step.setArgument('heat_pump_backup_heating_efficiency', 0.95)
    step.setArgument('heat_pump_backup_heating_switchover_temp', 25)
  elsif ['base-hvac-dual-fuel-air-to-air-heat-pump-var-speed.osw'].include? osw_file
    step.setArgument('heat_pump_backup_fuel', HPXML::FuelTypeNaturalGas)
    step.setArgument('heat_pump_backup_heating_efficiency', 0.95)
    step.setArgument('heat_pump_backup_heating_switchover_temp', 25)
  elsif ['base-hvac-dual-fuel-mini-split-heat-pump-ducted.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', '36000.0')
    step.setArgument('heat_pump_heating_capacity_17_f', '20423.0')
    step.setArgument('heat_pump_backup_fuel', HPXML::FuelTypeNaturalGas)
    step.setArgument('heat_pump_backup_heating_efficiency', 0.95)
    step.setArgument('heat_pump_backup_heating_switchover_temp', 25)
  elsif ['base-hvac-ducts-leakage-percent.osw'].include? osw_file
    step.setArgument('ducts_supply_leakage_units', HPXML::UnitsPercent)
    step.setArgument('ducts_return_leakage_units', HPXML::UnitsPercent)
    step.setArgument('ducts_supply_leakage_value', 0.1)
    step.setArgument('ducts_return_leakage_value', 0.05)
  elsif ['base-hvac-elec-resistance-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeElectricResistance)
    step.setArgument('heating_system_fuel', HPXML::FuelTypeElectricity)
    step.setArgument('heating_system_heating_efficiency', 1.0)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-evap-cooler-furnace-gas.osw'].include? osw_file
    step.setArgument('cooling_system_type', HPXML::HVACTypeEvaporativeCooler)
    step.removeArgument('cooling_system_cooling_compressor_type')
    step.removeArgument('cooling_system_cooling_sensible_heat_fraction')
  elsif ['base-hvac-evap-cooler-only.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_type', HPXML::HVACTypeEvaporativeCooler)
    step.removeArgument('cooling_system_cooling_compressor_type')
    step.removeArgument('cooling_system_cooling_sensible_heat_fraction')
  elsif ['base-hvac-evap-cooler-only-ducted.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_type', HPXML::HVACTypeEvaporativeCooler)
    step.removeArgument('cooling_system_cooling_compressor_type')
    step.removeArgument('cooling_system_cooling_sensible_heat_fraction')
    step.setArgument('cooling_system_is_ducted', true)
    step.setArgument('ducts_return_leakage_value', 0.0)
  elsif ['base-hvac-fireplace-wood-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeFireplace)
    step.setArgument('heating_system_fuel', HPXML::FuelTypeWoodCord)
    step.setArgument('heating_system_heating_efficiency', 0.8)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-fixed-heater-gas-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeFixedHeater)
    step.setArgument('heating_system_heating_efficiency', 1.0)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-floor-furnace-propane-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeFloorFurnace)
    step.setArgument('heating_system_fuel', HPXML::FuelTypePropane)
    step.setArgument('heating_system_heating_efficiency', 0.8)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-furnace-coal-only.osw'].include? osw_file
    step.setArgument('heating_system_fuel', HPXML::FuelTypeCoal)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-furnace-elec-central-ac-1-speed.osw'].include? osw_file
    step.setArgument('heating_system_fuel', HPXML::FuelTypeElectricity)
    step.setArgument('heating_system_heating_efficiency', 1.0)
  elsif ['base-hvac-furnace-elec-only.osw'].include? osw_file
    step.setArgument('heating_system_fuel', HPXML::FuelTypeElectricity)
    step.setArgument('heating_system_heating_efficiency', 0.98)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-furnace-gas-central-ac-2-speed.osw'].include? osw_file
    step.setArgument('cooling_system_cooling_efficiency', 18.0)
    step.setArgument('cooling_system_cooling_compressor_type', HPXML::HVACCompressorTypeTwoStage)
  elsif ['base-hvac-furnace-gas-central-ac-var-speed.osw'].include? osw_file
    step.setArgument('cooling_system_cooling_efficiency', 24.0)
    step.setArgument('cooling_system_cooling_compressor_type', HPXML::HVACCompressorTypeVariableSpeed)
    step.setArgument('cooling_system_cooling_sensible_heat_fraction', 0.78)
  elsif ['base-hvac-furnace-gas-only.osw'].include? osw_file
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-furnace-gas-room-ac.osw'].include? osw_file
    step.setArgument('cooling_system_type', HPXML::HVACTypeRoomAirConditioner)
    step.setArgument('cooling_system_cooling_efficiency_type', HPXML::UnitsEER)
    step.setArgument('cooling_system_cooling_efficiency', 8.5)
    step.removeArgument('cooling_system_cooling_compressor_type')
    step.setArgument('cooling_system_cooling_sensible_heat_fraction', 0.65)
  elsif ['base-hvac-furnace-oil-only.osw'].include? osw_file
    step.setArgument('heating_system_fuel', HPXML::FuelTypeOil)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-furnace-propane-only.osw'].include? osw_file
    step.setArgument('heating_system_fuel', HPXML::FuelTypePropane)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-furnace-wood-only.osw'].include? osw_file
    step.setArgument('heating_system_fuel', HPXML::FuelTypeWoodCord)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-mini-split-air-conditioner-only-ducted.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_type', HPXML::HVACTypeMiniSplitAirConditioner)
    step.setArgument('cooling_system_cooling_efficiency', 19.0)
    step.removeArgument('cooling_system_cooling_compressor_type')
    step.setArgument('cooling_system_is_ducted', true)
    step.setArgument('ducts_supply_leakage_value', 15.0)
    step.setArgument('ducts_return_leakage_value', 5.0)
    step.setArgument('ducts_supply_insulation_r', 0.0)
    step.setArgument('ducts_supply_surface_area', '30.0')
    step.setArgument('ducts_return_surface_area', '10.0')
  elsif ['base-hvac-mini-split-air-conditioner-only-ductless.osw'].include? osw_file
    step.setArgument('cooling_system_is_ducted', false)
  elsif ['base-hvac-ground-to-air-heat-pump.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_type', 'none')
    step.setArgument('heat_pump_type', HPXML::HVACTypeHeatPumpGroundToAir)
    step.setArgument('heat_pump_heating_efficiency_type', HPXML::UnitsCOP)
    step.setArgument('heat_pump_heating_efficiency', 3.6)
    step.setArgument('heat_pump_cooling_efficiency_type', HPXML::UnitsEER)
    step.setArgument('heat_pump_cooling_efficiency', 16.6)
    step.removeArgument('heat_pump_cooling_compressor_type')
    step.setArgument('heat_pump_backup_fuel', HPXML::FuelTypeElectricity)
  elsif ['base-hvac-ground-to-air-heat-pump-cooling-only.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', '0.0')
    step.setArgument('heat_pump_fraction_heat_load_served', 0)
    step.setArgument('heat_pump_backup_fuel', 'none')
  elsif ['base-hvac-ground-to-air-heat-pump-heating-only.osw'].include? osw_file
    step.setArgument('heat_pump_cooling_capacity', '0.0')
    step.setArgument('heat_pump_fraction_cool_load_served', 0)
  elsif ['base-hvac-seasons.osw'].include? osw_file
    step.setArgument('season_heating_begin_month', 11)
    step.setArgument('season_heating_begin_day_of_month', 1)
    step.setArgument('season_heating_end_month', 6)
    step.setArgument('season_heating_end_day_of_month', 30)
    step.setArgument('season_cooling_begin_month', 6)
    step.setArgument('season_cooling_begin_day_of_month', 1)
    step.setArgument('season_cooling_end_month', 10)
    step.setArgument('season_cooling_end_day_of_month', 31)
  elsif ['base-hvac-install-quality-air-to-air-heat-pump-1-speed.osw'].include? osw_file
    step.setArgument('heat_pump_airflow_defect_ratio', -0.25)
    step.setArgument('heat_pump_charge_defect_ratio', -0.25)
  elsif ['base-hvac-install-quality-air-to-air-heat-pump-2-speed.osw'].include? osw_file
    step.setArgument('heat_pump_airflow_defect_ratio', -0.25)
    step.setArgument('heat_pump_charge_defect_ratio', -0.25)
  elsif ['base-hvac-install-quality-air-to-air-heat-pump-var-speed.osw'].include? osw_file
    step.setArgument('heat_pump_airflow_defect_ratio', -0.25)
    step.setArgument('heat_pump_charge_defect_ratio', -0.25)
  elsif ['base-hvac-install-quality-furnace-gas-central-ac-1-speed.osw'].include? osw_file
    step.setArgument('heating_system_airflow_defect_ratio', -0.25)
    step.setArgument('cooling_system_airflow_defect_ratio', -0.25)
    step.setArgument('cooling_system_charge_defect_ratio', -0.25)
  elsif ['base-hvac-install-quality-furnace-gas-central-ac-2-speed.osw'].include? osw_file
    step.setArgument('heating_system_airflow_defect_ratio', -0.25)
    step.setArgument('cooling_system_airflow_defect_ratio', -0.25)
    step.setArgument('cooling_system_charge_defect_ratio', -0.25)
  elsif ['base-hvac-install-quality-furnace-gas-central-ac-var-speed.osw'].include? osw_file
    step.setArgument('heating_system_airflow_defect_ratio', -0.25)
    step.setArgument('cooling_system_airflow_defect_ratio', -0.25)
    step.setArgument('cooling_system_charge_defect_ratio', -0.25)
  elsif ['base-hvac-install-quality-furnace-gas-only.osw'].include? osw_file
    step.setArgument('heating_system_airflow_defect_ratio', -0.25)
  elsif ['base-hvac-install-quality-ground-to-air-heat-pump.osw'].include? osw_file
    step.setArgument('heat_pump_airflow_defect_ratio', -0.25)
    step.setArgument('heat_pump_charge_defect_ratio', -0.25)
  elsif ['base-hvac-install-quality-mini-split-heat-pump-ducted.osw'].include? osw_file
    step.setArgument('heat_pump_airflow_defect_ratio', -0.25)
    step.setArgument('heat_pump_charge_defect_ratio', -0.25)
  elsif ['base-hvac-install-quality-mini-split-air-conditioner-only-ducted.osw'].include? osw_file
    step.setArgument('cooling_system_airflow_defect_ratio', -0.25)
    step.setArgument('cooling_system_charge_defect_ratio', -0.25)
  elsif ['base-hvac-mini-split-heat-pump-ducted.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_type', 'none')
    step.setArgument('heat_pump_type', HPXML::HVACTypeHeatPumpMiniSplit)
    step.setArgument('heat_pump_heating_capacity_17_f', '20423.0')
    step.setArgument('heat_pump_heating_efficiency', 10.0)
    step.setArgument('heat_pump_cooling_efficiency', 19.0)
    step.removeArgument('heat_pump_cooling_compressor_type')
    step.setArgument('heat_pump_backup_fuel', HPXML::FuelTypeElectricity)
    step.setArgument('heat_pump_is_ducted', true)
    step.setArgument('ducts_supply_leakage_value', 15.0)
    step.setArgument('ducts_return_leakage_value', 5.0)
    step.setArgument('ducts_supply_insulation_r', 0.0)
    step.setArgument('ducts_supply_surface_area', '30.0')
    step.setArgument('ducts_return_surface_area', '10.0')
  elsif ['base-hvac-mini-split-heat-pump-ducted-cooling-only.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', '0')
    step.setArgument('heat_pump_heating_capacity_17_f', '0')
    step.setArgument('heat_pump_fraction_heat_load_served', 0)
    step.setArgument('heat_pump_backup_fuel', 'none')
  elsif ['base-hvac-mini-split-heat-pump-ducted-heating-only.osw'].include? osw_file
    step.setArgument('heat_pump_cooling_capacity', '0')
    step.setArgument('heat_pump_fraction_cool_load_served', 0)
    step.setArgument('heat_pump_backup_fuel', HPXML::FuelTypeElectricity)
  elsif ['base-hvac-mini-split-heat-pump-ductless.osw'].include? osw_file
    step.setArgument('heat_pump_backup_fuel', 'none')
    step.setArgument('heat_pump_is_ducted', false)
  elsif ['base-hvac-none.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-portable-heater-gas-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypePortableHeater)
    step.setArgument('heating_system_heating_efficiency', 1.0)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-programmable-thermostat-detailed.osw'].include? osw_file
    step.setArgument('setpoint_heating_weekday', '64, 64, 64, 64, 64, 64, 64, 70, 70, 66, 66, 66, 66, 66, 66, 66, 66, 68, 68, 68, 68, 68, 64, 64')
    step.setArgument('setpoint_heating_weekend', '68, 68, 68, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70')
    step.setArgument('setpoint_cooling_weekday', '80, 80, 80, 80, 80, 80, 80, 75, 75, 80, 80, 80, 80, 80, 80, 80, 80, 78, 78, 78, 78, 78, 80, 80')
    step.setArgument('setpoint_cooling_weekend', '78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78')
  elsif ['base-hvac-room-ac-only.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_type', HPXML::HVACTypeRoomAirConditioner)
    step.setArgument('cooling_system_cooling_efficiency_type', HPXML::UnitsEER)
    step.setArgument('cooling_system_cooling_efficiency', 8.5)
    step.removeArgument('cooling_system_cooling_compressor_type')
    step.setArgument('cooling_system_cooling_sensible_heat_fraction', 0.65)
  elsif ['base-hvac-room-ac-only-33percent.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('cooling_system_type', HPXML::HVACTypeRoomAirConditioner)
    step.setArgument('cooling_system_cooling_efficiency_type', HPXML::UnitsEER)
    step.setArgument('cooling_system_cooling_efficiency', 8.5)
    step.removeArgument('cooling_system_cooling_compressor_type')
    step.setArgument('cooling_system_cooling_sensible_heat_fraction', 0.65)
    step.setArgument('cooling_system_fraction_cool_load_served', 0.33)
    step.setArgument('cooling_system_cooling_capacity', '8000.0')
  elsif ['base-hvac-setpoints.osw'].include? osw_file
    step.setArgument('setpoint_heating_weekday', '60')
    step.setArgument('setpoint_heating_weekend', '60')
    step.setArgument('setpoint_cooling_weekday', '80')
    step.setArgument('setpoint_cooling_weekend', '80')
  elsif ['base-hvac-stove-oil-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeStove)
    step.setArgument('heating_system_fuel', HPXML::FuelTypeOil)
    step.setArgument('heating_system_heating_efficiency', 0.8)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-stove-wood-pellets-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeStove)
    step.setArgument('heating_system_fuel', HPXML::FuelTypeWoodPellets)
    step.setArgument('heating_system_heating_efficiency', 0.8)
    step.setArgument('cooling_system_type', 'none')
  elsif ['base-hvac-undersized.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', '3600.0')
    step.setArgument('cooling_system_cooling_capacity', '2400.0')
    step.setArgument('ducts_supply_leakage_value', 7.5)
    step.setArgument('ducts_return_leakage_value', 2.5)
  elsif ['base-hvac-wall-furnace-elec-only.osw'].include? osw_file
    step.setArgument('heating_system_type', HPXML::HVACTypeWallFurnace)
    step.setArgument('heating_system_fuel', HPXML::FuelTypeElectricity)
    step.setArgument('heating_system_heating_efficiency', 0.98)
    step.setArgument('cooling_system_type', 'none')
  end

  # Lighting
  if ['base-lighting-ceiling-fans.osw'].include? osw_file
    step.setArgument('ceiling_fan_present', true)
    step.setArgument('ceiling_fan_efficiency', '100.0')
    step.setArgument('ceiling_fan_quantity', '4')
    step.setArgument('ceiling_fan_cooling_setpoint_temp_offset', 0.5)
  elsif ['base-lighting-detailed.osw'].include? osw_file
    step.setArgument('holiday_lighting_present', true)
    step.setArgument('holiday_lighting_daily_kwh', '1.1')
    step.setArgument('holiday_lighting_period_begin_month', '11')
    step.setArgument('holiday_lighting_period_begin_day_of_month', '24')
    step.setArgument('holiday_lighting_period_end_month', '1')
    step.setArgument('holiday_lighting_period_end_day_of_month', '6')
  end

  # Location
  if ['base-location-AMY-2012.osw'].include? osw_file
    step.setArgument('weather_station_epw_filepath', 'US_CO_Boulder_AMY_2012.epw')
  elsif ['base-location-baltimore-md.osw'].include? osw_file
    step.setArgument('weather_station_epw_filepath', 'USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw')
    step.setArgument('heating_system_heating_capacity', '24000.0')
  elsif ['base-location-dallas-tx.osw'].include? osw_file
    step.setArgument('weather_station_epw_filepath', 'USA_TX_Dallas-Fort.Worth.Intl.AP.722590_TMY3.epw')
    step.setArgument('heating_system_heating_capacity', '24000.0')
  elsif ['base-location-duluth-mn.osw'].include? osw_file
    step.setArgument('weather_station_epw_filepath', 'USA_MN_Duluth.Intl.AP.727450_TMY3.epw')
  elsif ['base-location-helena-mt.osw'].include? osw_file
    step.setArgument('weather_station_epw_filepath', 'USA_MT_Helena.Rgnl.AP.727720_TMY3.epw')
    step.setArgument('heating_system_heating_capacity', '48000.0')
  elsif ['base-location-honolulu-hi.osw'].include? osw_file
    step.setArgument('weather_station_epw_filepath', 'USA_HI_Honolulu.Intl.AP.911820_TMY3.epw')
    step.setArgument('heating_system_heating_capacity', '12000.0')
  elsif ['base-location-miami-fl.osw'].include? osw_file
    step.setArgument('weather_station_epw_filepath', 'USA_FL_Miami.Intl.AP.722020_TMY3.epw')
    step.setArgument('heating_system_heating_capacity', '12000.0')
  elsif ['base-location-phoenix-az.osw'].include? osw_file
    step.setArgument('weather_station_epw_filepath', 'USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw')
    step.setArgument('heating_system_heating_capacity', '24000.0')
  elsif ['base-location-portland-or.osw'].include? osw_file
    step.setArgument('weather_station_epw_filepath', 'USA_OR_Portland.Intl.AP.726980_TMY3.epw')
    step.setArgument('heating_system_heating_capacity', '24000.0')
  end

  # Mechanical Ventilation
  if ['base-mechvent-balanced.osw'].include? osw_file
    step.setArgument('mech_vent_fan_type', HPXML::MechVentTypeBalanced)
    step.setArgument('mech_vent_fan_power', '60')
  elsif ['base-mechvent-bath-kitchen-fans.osw'].include? osw_file
    step.setArgument('kitchen_fans_quantity', '1')
    step.setArgument('kitchen_fans_flow_rate', '100.0')
    step.setArgument('kitchen_fans_hours_in_operation', '1.5')
    step.setArgument('kitchen_fans_power', '30.0')
    step.setArgument('kitchen_fans_start_hour', '18')
    step.setArgument('bathroom_fans_quantity', '2')
    step.setArgument('bathroom_fans_flow_rate', '50.0')
    step.setArgument('bathroom_fans_hours_in_operation', '1.5')
    step.setArgument('bathroom_fans_power', '15.0')
    step.setArgument('bathroom_fans_start_hour', '7')
  elsif ['base-mechvent-cfis.osw'].include? osw_file
    step.setArgument('mech_vent_fan_type', HPXML::MechVentTypeCFIS)
    step.setArgument('mech_vent_flow_rate', 330)
    step.setArgument('mech_vent_hours_in_operation', '8')
    step.setArgument('mech_vent_fan_power', '300')
  elsif ['base-mechvent-cfis-evap-cooler-only-ducted.osw'].include? osw_file
    step.setArgument('mech_vent_fan_type', HPXML::MechVentTypeCFIS)
    step.setArgument('mech_vent_flow_rate', 330)
    step.setArgument('mech_vent_hours_in_operation', '8')
    step.setArgument('mech_vent_fan_power', '300')
  elsif ['base-mechvent-erv.osw'].include? osw_file
    step.setArgument('mech_vent_fan_type', HPXML::MechVentTypeERV)
    step.setArgument('mech_vent_fan_power', '60')
  elsif ['base-mechvent-erv-atre-asre.osw'].include? osw_file
    step.setArgument('mech_vent_fan_type', HPXML::MechVentTypeERV)
    step.setArgument('mech_vent_recovery_efficiency_type', 'Adjusted')
    step.setArgument('mech_vent_total_recovery_efficiency', 0.526)
    step.setArgument('mech_vent_sensible_recovery_efficiency', 0.79)
    step.setArgument('mech_vent_fan_power', '60')
  elsif ['base-mechvent-exhaust.osw'].include? osw_file
    step.setArgument('mech_vent_fan_type', HPXML::MechVentTypeExhaust)
  elsif ['base-mechvent-exhaust-rated-flow-rate.osw'].include? osw_file
    step.setArgument('mech_vent_fan_type', HPXML::MechVentTypeExhaust)
  elsif ['base-mechvent-hrv.osw'].include? osw_file
    step.setArgument('mech_vent_fan_type', HPXML::MechVentTypeHRV)
    step.setArgument('mech_vent_fan_power', '60')
  elsif ['base-mechvent-hrv-asre.osw'].include? osw_file
    step.setArgument('mech_vent_fan_type', HPXML::MechVentTypeHRV)
    step.setArgument('mech_vent_recovery_efficiency_type', 'Adjusted')
    step.setArgument('mech_vent_sensible_recovery_efficiency', 0.79)
    step.setArgument('mech_vent_fan_power', '60')
  elsif ['base-mechvent-supply.osw'].include? osw_file
    step.setArgument('mech_vent_fan_type', HPXML::MechVentTypeSupply)
  elsif ['base-mechvent-whole-house-fan.osw'].include? osw_file
    step.setArgument('whole_house_fan_present', true)
  end

  # Misc
  if ['base-misc-defaults.osw'].include? osw_file
    step.removeArgument('simulation_control_timestep')
    step.removeArgument('site_type')
    step.setArgument('geometry_num_bathrooms', Constants.Auto)
    step.setArgument('geometry_num_occupants', Constants.Auto)
    step.setArgument('foundation_wall_insulation_distance_to_top', Constants.Auto)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', Constants.Auto)
    step.setArgument('foundation_wall_thickness', Constants.Auto)
    step.setArgument('slab_thickness', Constants.Auto)
    step.setArgument('slab_carpet_fraction', Constants.Auto)
    step.removeArgument('roof_material_type')
    step.setArgument('roof_color', HPXML::ColorLight)
    step.removeArgument('roof_material_type')
    step.setArgument('roof_radiant_barrier', false)
    step.removeArgument('wall_siding_type')
    step.setArgument('wall_color', HPXML::ColorMedium)
    step.removeArgument('window_fraction_operable')
    step.removeArgument('window_interior_shading_winter')
    step.removeArgument('window_interior_shading_summer')
    step.removeArgument('cooling_system_cooling_compressor_type')
    step.removeArgument('cooling_system_cooling_sensible_heat_fraction')
    step.setArgument('mech_vent_fan_type', HPXML::MechVentTypeExhaust)
    step.setArgument('mech_vent_hours_in_operation', Constants.Auto)
    step.setArgument('mech_vent_fan_power', Constants.Auto)
    step.setArgument('ducts_supply_location', Constants.Auto)
    step.setArgument('ducts_return_location', Constants.Auto)
    step.setArgument('ducts_supply_surface_area', Constants.Auto)
    step.setArgument('ducts_return_surface_area', Constants.Auto)
    step.setArgument('kitchen_fans_quantity', Constants.Auto)
    step.setArgument('bathroom_fans_quantity', Constants.Auto)
    step.setArgument('water_heater_location', Constants.Auto)
    step.setArgument('water_heater_tank_volume', Constants.Auto)
    step.setArgument('water_heater_setpoint_temperature', Constants.Auto)
    step.setArgument('dhw_distribution_standard_piping_length', Constants.Auto)
    step.setArgument('dhw_distribution_pipe_r', Constants.Auto)
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_collector_type', HPXML::SolarThermalTypeSingleGlazing)
    step.setArgument('solar_thermal_collector_rated_optical_efficiency', 0.77)
    step.setArgument('solar_thermal_collector_rated_thermal_losses', 0.793)
    step.setArgument('pv_system_module_type_1', Constants.Auto)
    step.removeArgument('pv_system_inverter_efficiency_1')
    step.removeArgument('pv_system_system_losses_fraction_1')
    step.setArgument('clothes_washer_location', Constants.Auto)
    step.setArgument('clothes_washer_efficiency', Constants.Auto)
    step.setArgument('clothes_washer_rated_annual_kwh', Constants.Auto)
    step.setArgument('clothes_washer_label_electric_rate', Constants.Auto)
    step.setArgument('clothes_washer_label_gas_rate', Constants.Auto)
    step.setArgument('clothes_washer_label_annual_gas_cost', Constants.Auto)
    step.setArgument('clothes_washer_label_usage', Constants.Auto)
    step.setArgument('clothes_washer_capacity', Constants.Auto)
    step.setArgument('clothes_dryer_location', Constants.Auto)
    step.setArgument('clothes_dryer_efficiency', Constants.Auto)
    step.setArgument('clothes_dryer_vented_flow_rate', Constants.Auto)
    step.setArgument('dishwasher_location', Constants.Auto)
    step.setArgument('dishwasher_efficiency', Constants.Auto)
    step.setArgument('dishwasher_label_electric_rate', Constants.Auto)
    step.setArgument('dishwasher_label_gas_rate', Constants.Auto)
    step.setArgument('dishwasher_label_annual_gas_cost', Constants.Auto)
    step.setArgument('dishwasher_label_usage', Constants.Auto)
    step.setArgument('dishwasher_place_setting_capacity', Constants.Auto)
    step.setArgument('refrigerator_location', Constants.Auto)
    step.setArgument('refrigerator_rated_annual_kwh', Constants.Auto)
    step.setArgument('cooking_range_oven_location', Constants.Auto)
    step.removeArgument('cooking_range_oven_is_induction')
    step.removeArgument('cooking_range_oven_is_convection')
    step.setArgument('ceiling_fan_present', true)
    step.setArgument('plug_loads_television_annual_kwh', Constants.Auto)
    step.setArgument('plug_loads_other_annual_kwh', Constants.Auto)
    step.setArgument('plug_loads_other_frac_sensible', Constants.Auto)
    step.setArgument('plug_loads_other_frac_latent', Constants.Auto)
  elsif ['base-misc-loads-large-uncommon.osw'].include? osw_file
    step.setArgument('extra_refrigerator_location', Constants.Auto)
    step.setArgument('extra_refrigerator_rated_annual_kwh', '700.0')
    step.setArgument('freezer_location', HPXML::LocationLivingSpace)
    step.setArgument('freezer_rated_annual_kwh', '300.0')
    step.setArgument('plug_loads_well_pump_present', true)
    step.setArgument('plug_loads_well_pump_annual_kwh', '475.0')
    step.setArgument('plug_loads_well_pump_usage_multiplier', 1.0)
    step.setArgument('plug_loads_vehicle_present', true)
    step.setArgument('plug_loads_vehicle_annual_kwh', '1500.0')
    step.setArgument('plug_loads_vehicle_usage_multiplier', 1.0)
    step.setArgument('fuel_loads_grill_present', true)
    step.setArgument('fuel_loads_grill_fuel_type', HPXML::FuelTypePropane)
    step.setArgument('fuel_loads_grill_annual_therm', '25.0')
    step.setArgument('fuel_loads_grill_usage_multiplier', 1.0)
    step.setArgument('fuel_loads_lighting_present', true)
    step.setArgument('fuel_loads_lighting_annual_therm', '28.0')
    step.setArgument('fuel_loads_lighting_usage_multiplier', 1.0)
    step.setArgument('fuel_loads_fireplace_present', true)
    step.setArgument('fuel_loads_fireplace_fuel_type', HPXML::FuelTypeWoodCord)
    step.setArgument('fuel_loads_fireplace_annual_therm', '55.0')
    step.setArgument('fuel_loads_fireplace_frac_sensible', '0.5')
    step.setArgument('fuel_loads_fireplace_frac_latent', '0.1')
    step.setArgument('fuel_loads_fireplace_usage_multiplier', 1.0)
    step.setArgument('pool_present', true)
    step.setArgument('pool_heater_type', HPXML::HeaterTypeGas)
    step.setArgument('pool_pump_annual_kwh', '2700.0')
    step.setArgument('pool_heater_annual_therm', '500.0')
    step.setArgument('hot_tub_present', true)
    step.setArgument('hot_tub_pump_annual_kwh', '1000.0')
    step.setArgument('hot_tub_heater_annual_kwh', '1300.0')
  elsif ['base-misc-loads-large-uncommon2.osw'].include? osw_file
    step.setArgument('pool_heater_type', HPXML::TypeNone)
    step.setArgument('hot_tub_heater_type', HPXML::HeaterTypeHeatPump)
    step.setArgument('hot_tub_heater_annual_kwh', '260.0')
    step.setArgument('fuel_loads_grill_fuel_type', HPXML::FuelTypeOil)
    step.setArgument('fuel_loads_fireplace_fuel_type', HPXML::FuelTypeWoodPellets)
  elsif ['base-misc-neighbor-shading.osw'].include? osw_file
    step.setArgument('neighbor_back_distance', 10)
    step.setArgument('neighbor_front_distance', 15)
    step.setArgument('neighbor_front_height', '12')
  elsif ['base-misc-shielding-of-home.osw'].include? osw_file
    step.setArgument('air_leakage_shielding_of_home', HPXML::ShieldingWellShielded)
  elsif ['base-misc-usage-multiplier.osw'].include? osw_file
    step.setArgument('water_fixtures_usage_multiplier', 0.9)
    step.setArgument('lighting_usage_multiplier_interior', 0.9)
    step.setArgument('lighting_usage_multiplier_exterior', 0.9)
    step.setArgument('lighting_usage_multiplier_garage', 0.9)
    step.setArgument('clothes_washer_usage_multiplier', 0.9)
    step.setArgument('clothes_dryer_usage_multiplier', 0.9)
    step.setArgument('dishwasher_usage_multiplier', 0.9)
    step.setArgument('refrigerator_usage_multiplier', 0.9)
    step.setArgument('freezer_location', HPXML::LocationLivingSpace)
    step.setArgument('freezer_rated_annual_kwh', '300.0')
    step.setArgument('freezer_usage_multiplier', 0.9)
    step.setArgument('cooking_range_oven_usage_multiplier', 0.9)
    step.setArgument('plug_loads_television_usage_multiplier', 0.9)
    step.setArgument('plug_loads_other_usage_multiplier', 0.9)
    step.setArgument('pool_present', true)
    step.setArgument('pool_pump_annual_kwh', '2700.0')
    step.setArgument('pool_pump_usage_multiplier', 0.9)
    step.setArgument('pool_heater_type', HPXML::HeaterTypeGas)
    step.setArgument('pool_heater_annual_therm', '500.0')
    step.setArgument('pool_heater_usage_multiplier', 0.9)
    step.setArgument('hot_tub_present', true)
    step.setArgument('hot_tub_pump_annual_kwh', '1000.0')
    step.setArgument('hot_tub_pump_usage_multiplier', 0.9)
    step.setArgument('hot_tub_heater_type', HPXML::HeaterTypeElectricResistance)
    step.setArgument('hot_tub_heater_annual_kwh', '1300.0')
    step.setArgument('hot_tub_heater_usage_multiplier', 0.9)
    step.setArgument('fuel_loads_grill_present', true)
    step.setArgument('fuel_loads_grill_fuel_type', HPXML::FuelTypePropane)
    step.setArgument('fuel_loads_grill_annual_therm', '25.0')
    step.setArgument('fuel_loads_grill_usage_multiplier', 0.9)
    step.setArgument('fuel_loads_lighting_present', true)
    step.setArgument('fuel_loads_lighting_annual_therm', '28.0')
    step.setArgument('fuel_loads_lighting_usage_multiplier', 0.9)
    step.setArgument('fuel_loads_fireplace_present', true)
    step.setArgument('fuel_loads_fireplace_fuel_type', HPXML::FuelTypeWoodCord)
    step.setArgument('fuel_loads_fireplace_annual_therm', '55.0')
    step.setArgument('fuel_loads_fireplace_frac_sensible', '0.5')
    step.setArgument('fuel_loads_fireplace_frac_latent', '0.1')
    step.setArgument('fuel_loads_fireplace_usage_multiplier', 0.9)
  end

  # PV
  if ['base-pv.osw'].include? osw_file
    step.setArgument('pv_system_module_type_1', HPXML::PVModuleTypeStandard)
    step.setArgument('pv_system_location_1', HPXML::LocationRoof)
    step.setArgument('pv_system_tracking_1', HPXML::PVTrackingTypeFixed)
    step.setArgument('pv_system_module_type_2', HPXML::PVModuleTypePremium)
    step.setArgument('pv_system_location_2', HPXML::LocationRoof)
    step.setArgument('pv_system_tracking_2', HPXML::PVTrackingTypeFixed)
    step.setArgument('pv_system_array_azimuth_2', 90)
    step.setArgument('pv_system_max_power_output_2', 1500)
  end

  # Simulation Control
  if ['base-simcontrol-calendar-year-custom.osw'].include? osw_file
    step.setArgument('simulation_control_run_period_calendar_year', 2008)
  elsif ['base-simcontrol-daylight-saving-custom.osw'].include? osw_file
    step.setArgument('simulation_control_daylight_saving_enabled', true)
    step.setArgument('simulation_control_daylight_saving_begin_month', 3)
    step.setArgument('simulation_control_daylight_saving_begin_day_of_month', 10)
    step.setArgument('simulation_control_daylight_saving_end_month', 11)
    step.setArgument('simulation_control_daylight_saving_end_day_of_month', 6)
  elsif ['base-simcontrol-daylight-saving-disabled.osw'].include? osw_file
    step.setArgument('simulation_control_daylight_saving_enabled', false)
  elsif ['base-simcontrol-runperiod-1-month.osw'].include? osw_file
    step.setArgument('simulation_control_run_period_begin_month', 1)
    step.setArgument('simulation_control_run_period_begin_day_of_month', 1)
    step.setArgument('simulation_control_run_period_end_month', 1)
    step.setArgument('simulation_control_run_period_end_day_of_month', 31)
  elsif ['base-simcontrol-timestep-10-mins.osw'].include? osw_file
    step.setArgument('simulation_control_timestep', '10')
  end

  # Schedules
  if ['base-schedules-stochastic.osw'].include? osw_file
    step.setArgument('schedules_type', 'stochastic')
  elsif ['base-schedules-stochastic-vacant.osw'].include? osw_file
    step.setArgument('schedules_vacancy_begin_month', 12)
    step.setArgument('schedules_vacancy_begin_day_of_month', 1)
    step.setArgument('schedules_vacancy_end_month', 1)
    step.setArgument('schedules_vacancy_end_day_of_month', 31)
  elsif ['base-schedules-user-specified.osw'].include? osw_file
    step.setArgument('schedules_type', 'user-specified')
    step.setArgument('schedules_path', 'BuildResidentialHPXML/tests/schedules/user-specified.csv')
  end

  # Extras
  if ['extra-auto.osw'].include? osw_file
    step.setArgument('geometry_num_occupants', Constants.Auto)
    step.setArgument('ducts_supply_location', Constants.Auto)
    step.setArgument('ducts_return_location', Constants.Auto)
    step.setArgument('ducts_supply_surface_area', Constants.Auto)
    step.setArgument('ducts_return_surface_area', Constants.Auto)
    step.setArgument('water_heater_location', Constants.Auto)
    step.setArgument('water_heater_tank_volume', Constants.Auto)
    step.setArgument('dhw_distribution_standard_piping_length', Constants.Auto)
    step.setArgument('clothes_washer_location', Constants.Auto)
    step.setArgument('clothes_dryer_location', Constants.Auto)
    step.setArgument('refrigerator_location', Constants.Auto)
  elsif ['extra-pv-roofpitch.osw'].include? osw_file
    step.setArgument('pv_system_module_type_1', HPXML::PVModuleTypeStandard)
    step.setArgument('pv_system_module_type_2', HPXML::PVModuleTypeStandard)
    step.setArgument('pv_system_array_tilt_1', 'roofpitch')
    step.setArgument('pv_system_array_tilt_2', 'roofpitch+15')
  elsif ['extra-dhw-solar-latitude.osw'].include? osw_file
    step.setArgument('solar_thermal_system_type', 'hot water')
    step.setArgument('solar_thermal_collector_tilt', 'latitude-15')
  elsif ['extra-second-refrigerator.osw'].include? osw_file
    step.setArgument('extra_refrigerator_location', HPXML::LocationLivingSpace)
  elsif ['extra-second-heating-system-portable-heater-to-heating-system.osw'].include? osw_file
    step.setArgument('heating_system_fuel', HPXML::FuelTypeElectricity)
    step.setArgument('heating_system_heating_capacity', '48000.0')
    step.setArgument('heating_system_fraction_heat_load_served', 0.75)
    step.setArgument('ducts_supply_leakage_value', 0.0)
    step.setArgument('ducts_return_leakage_value', 0.0)
    step.setArgument('ducts_supply_location', HPXML::LocationLivingSpace)
    step.setArgument('ducts_return_location', HPXML::LocationLivingSpace)
    step.setArgument('heating_system_type_2', HPXML::HVACTypePortableHeater)
    step.setArgument('heating_system_heating_capacity_2', '16000.0')
  elsif ['extra-second-heating-system-fireplace-to-heating-system.osw'].include? osw_file
    step.setArgument('heating_system_heating_capacity', '48000.0')
    step.setArgument('heating_system_fraction_heat_load_served', 0.75)
    step.setArgument('heating_system_type_2', HPXML::HVACTypeFireplace)
    step.setArgument('heating_system_heating_capacity_2', '16000.0')
  elsif ['extra-second-heating-system-boiler-to-heating-system.osw'].include? osw_file
    step.setArgument('heating_system_fraction_heat_load_served', 0.75)
    step.setArgument('heating_system_type_2', HPXML::HVACTypeBoiler)
  elsif ['extra-second-heating-system-portable-heater-to-heat-pump.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', '48000.0')
    step.setArgument('heat_pump_fraction_heat_load_served', 0.75)
    step.setArgument('ducts_supply_leakage_value', 0.0)
    step.setArgument('ducts_return_leakage_value', 0.0)
    step.setArgument('ducts_supply_location', HPXML::LocationLivingSpace)
    step.setArgument('ducts_return_location', HPXML::LocationLivingSpace)
    step.setArgument('heating_system_type_2', HPXML::HVACTypePortableHeater)
    step.setArgument('heating_system_heating_capacity_2', '16000.0')
  elsif ['extra-second-heating-system-fireplace-to-heat-pump.osw'].include? osw_file
    step.setArgument('heat_pump_heating_capacity', '48000.0')
    step.setArgument('heat_pump_fraction_heat_load_served', 0.75)
    step.setArgument('heating_system_type_2', HPXML::HVACTypeFireplace)
    step.setArgument('heating_system_heating_capacity_2', '16000.0')
  elsif ['extra-second-heating-system-boiler-to-heat-pump.osw'].include? osw_file
    step.setArgument('heat_pump_fraction_heat_load_served', 0.75)
    step.setArgument('heating_system_type_2', HPXML::HVACTypeBoiler)
  elsif ['extra-enclosure-windows-shading.osw'].include? osw_file
    step.setArgument('window_interior_shading_winter', 0.99)
    step.setArgument('window_interior_shading_summer', 0.01)
    step.setArgument('window_exterior_shading_winter', 0.9)
    step.setArgument('window_exterior_shading_summer', 0.1)
  elsif ['extra-enclosure-garage-partially-protruded.osw'].include? osw_file
    step.setArgument('geometry_garage_width', 12)
    step.setArgument('geometry_garage_protrusion', 0.5)
  elsif ['extra-enclosure-garage-atticroof-conditioned.osw'].include? osw_file
    step.setArgument('geometry_cfa', 4500.0)
    step.setArgument('geometry_num_floors_above_grade', 2)
    step.setArgument('geometry_attic_type', HPXML::AtticTypeConditioned)
  elsif ['extra-enclosure-atticroof-conditioned-eaves-gable.osw'].include? osw_file
    step.setArgument('geometry_cfa', 4500.0)
    step.setArgument('geometry_num_floors_above_grade', 2)
    step.setArgument('geometry_attic_type', HPXML::AtticTypeConditioned)
    step.setArgument('geometry_eaves_depth', 2)
  elsif ['extra-enclosure-atticroof-conditioned-eaves-hip.osw'].include? osw_file
    step.setArgument('geometry_roof_type', 'hip')
  elsif ['extra-schedules-random-seed.osw'].include? osw_file
    step.setArgument('schedules_random_seed', 123)
  elsif ['extra-zero-refrigerator-kwh.osw'].include? osw_file
    step.setArgument('refrigerator_rated_annual_kwh', '0')
  elsif ['extra-zero-extra-refrigerator-kwh.osw'].include? osw_file
    step.setArgument('extra_refrigerator_rated_annual_kwh', '0')
  elsif ['extra-zero-freezer-kwh.osw'].include? osw_file
    step.setArgument('freezer_rated_annual_kwh', '0')
  elsif ['extra-zero-clothes-washer-kwh.osw'].include? osw_file
    step.setArgument('clothes_washer_rated_annual_kwh', '0')
    step.setArgument('clothes_dryer_location', 'none')
  elsif ['extra-zero-dishwasher-kwh.osw'].include? osw_file
    step.setArgument('dishwasher_efficiency', '0')
  elsif ['extra-bldgtype-single-family-attached-atticroof-flat.osw'].include? osw_file
    step.setArgument('geometry_roof_type', 'flat')
    step.setArgument('ducts_supply_leakage_value', 0.0)
    step.setArgument('ducts_return_leakage_value', 0.0)
    step.setArgument('ducts_supply_location', HPXML::LocationBasementConditioned)
    step.setArgument('ducts_return_location', HPXML::LocationBasementConditioned)
  elsif ['extra-gas-pool-heater-with-zero-kwh.osw'].include? osw_file
    step.setArgument('pool_present', true)
    step.setArgument('pool_heater_type', HPXML::HeaterTypeGas)
    step.setArgument('pool_heater_annual_kwh', 0)
  elsif ['extra-gas-hot-tub-heater-with-zero-kwh.osw'].include? osw_file
    step.setArgument('hot_tub_present', true)
    step.setArgument('hot_tub_heater_type', HPXML::HeaterTypeGas)
    step.setArgument('hot_tub_heater_annual_kwh', 0)

  elsif ['extra-bldgtype-single-family-attached-atticroof-conditioned-eaves-gable.osw'].include? osw_file
    step.setArgument('geometry_num_floors_above_grade', 2)
    step.setArgument('geometry_attic_type', HPXML::AtticTypeConditioned)
    step.setArgument('geometry_eaves_depth', 2)
    step.setArgument('ducts_supply_location', HPXML::LocationLivingSpace)
    step.setArgument('ducts_return_location', HPXML::LocationLivingSpace)
  elsif ['extra-bldgtype-single-family-attached-atticroof-conditioned-eaves-hip.osw'].include? osw_file
    step.setArgument('geometry_roof_type', 'hip')
  elsif ['extra-bldgtype-multifamily-eaves.osw'].include? osw_file
    step.setArgument('geometry_eaves_depth', 2)

  elsif ['extra-bldgtype-single-family-attached-slab.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeSlab)
    step.setArgument('geometry_foundation_height', 0.0)
    step.setArgument('geometry_foundation_height_above_grade', 0.0)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', Constants.Auto)
  elsif ['extra-bldgtype-single-family-attached-vented-crawlspace.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeCrawlspaceVented)
    step.setArgument('geometry_foundation_height', 4.0)
    step.setArgument('floor_assembly_r', 18.7)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '4.0')
  elsif ['extra-bldgtype-single-family-attached-unvented-crawlspace.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeCrawlspaceUnvented)
    step.setArgument('geometry_foundation_height', 4.0)
    step.setArgument('floor_assembly_r', 18.7)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '4.0')
  elsif ['extra-bldgtype-single-family-attached-unconditioned-basement.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeBasementUnconditioned)
    step.setArgument('floor_assembly_r', 18.7)
    step.setArgument('foundation_wall_insulation_r', 0)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '0.0')

  elsif ['extra-bldgtype-single-family-attached-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_building_num_units', 4)
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-single-family-attached-single-exterior-front.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Single Exterior (Front)')
  elsif ['extra-bldgtype-single-family-attached-double-exterior.osw'].include? osw_file
    step.setArgument('geometry_building_num_units', 4)
    step.setArgument('geometry_corridor_position', 'Double Exterior')

  elsif ['extra-bldgtype-single-family-attached-slab-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
  elsif ['extra-bldgtype-single-family-attached-slab-right.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')
  elsif ['extra-bldgtype-single-family-attached-vented-crawlspace-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
  elsif ['extra-bldgtype-single-family-attached-vented-crawlspace-right.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')
  elsif ['extra-bldgtype-single-family-attached-unvented-crawlspace-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
  elsif ['extra-bldgtype-single-family-attached-unvented-crawlspace-right.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')
  elsif ['extra-bldgtype-single-family-attached-unconditioned-basement-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
  elsif ['extra-bldgtype-single-family-attached-unconditioned-basement-right.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')

  elsif ['extra-bldgtype-multifamily-slab.osw'].include? osw_file
    step.setArgument('geometry_building_num_units', 9)
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeSlab)
    step.setArgument('geometry_foundation_height', 0.0)
    step.setArgument('geometry_foundation_height_above_grade', 0.0)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', Constants.Auto)
  elsif ['extra-bldgtype-multifamily-vented-crawlspace.osw'].include? osw_file
    step.setArgument('geometry_building_num_units', 9)
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeCrawlspaceVented)
    step.setArgument('geometry_foundation_height', 4.0)
    step.setArgument('floor_assembly_r', 18.7)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '4.0')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace.osw'].include? osw_file
    step.setArgument('geometry_building_num_units', 9)
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeCrawlspaceUnvented)
    step.setArgument('geometry_foundation_height', 4.0)
    step.setArgument('floor_assembly_r', 18.7)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '4.0')

  elsif ['extra-bldgtype-multifamily-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-single-exterior-front.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Single Exterior (Front)')
  elsif ['extra-bldgtype-multifamily-double-exterior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double Exterior')

  elsif ['extra-bldgtype-multifamily-slab-left-bottom.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Left')
    step.setArgument('geometry_level', 'Bottom')
  elsif ['extra-bldgtype-multifamily-slab-left-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Left')
    step.setArgument('geometry_level', 'Middle')
  elsif ['extra-bldgtype-multifamily-slab-left-top.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Left')
    step.setArgument('geometry_level', 'Top')
  elsif ['extra-bldgtype-multifamily-slab-middle-bottom.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
    step.setArgument('geometry_level', 'Bottom')
  elsif ['extra-bldgtype-multifamily-slab-middle-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
    step.setArgument('geometry_level', 'Middle')
  elsif ['extra-bldgtype-multifamily-slab-middle-top.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
    step.setArgument('geometry_level', 'Top')
  elsif ['extra-bldgtype-multifamily-slab-right-bottom.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')
    step.setArgument('geometry_level', 'Bottom')
  elsif ['extra-bldgtype-multifamily-slab-right-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')
    step.setArgument('geometry_level', 'Middle')
  elsif ['extra-bldgtype-multifamily-slab-right-top.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')
    step.setArgument('geometry_level', 'Top')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-left-bottom.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Left')
    step.setArgument('geometry_level', 'Bottom')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-left-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Left')
    step.setArgument('geometry_level', 'Middle')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-left-top.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Left')
    step.setArgument('geometry_level', 'Top')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-middle-bottom.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
    step.setArgument('geometry_level', 'Bottom')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-middle-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
    step.setArgument('geometry_level', 'Middle')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-middle-top.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
    step.setArgument('geometry_level', 'Top')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-right-bottom.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')
    step.setArgument('geometry_level', 'Bottom')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-right-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')
    step.setArgument('geometry_level', 'Middle')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-right-top.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')
    step.setArgument('geometry_level', 'Top')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-left-bottom.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Left')
    step.setArgument('geometry_level', 'Bottom')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-left-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Left')
    step.setArgument('geometry_level', 'Middle')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-left-top.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Left')
    step.setArgument('geometry_level', 'Top')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-middle-bottom.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
    step.setArgument('geometry_level', 'Bottom')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-middle-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
    step.setArgument('geometry_level', 'Middle')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-middle-top.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Middle')
    step.setArgument('geometry_level', 'Top')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-right-bottom.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')
    step.setArgument('geometry_level', 'Bottom')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-right-middle.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')
    step.setArgument('geometry_level', 'Middle')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-right-top.osw'].include? osw_file
    step.setArgument('geometry_horizontal_location', 'Right')
    step.setArgument('geometry_level', 'Top')

  elsif ['extra-bldgtype-multifamily-slab-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-slab-left-bottom-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-slab-left-middle-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-slab-left-top-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-slab-middle-bottom-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-slab-middle-middle-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-slab-middle-top-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-slab-right-bottom-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-slab-right-middle-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-slab-right-top-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-left-bottom-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-left-middle-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-left-top-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-middle-bottom-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-middle-middle-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-middle-top-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-right-bottom-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-right-middle-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-vented-crawlspace-right-top-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-left-bottom-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-left-middle-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-left-top-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-middle-bottom-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-middle-middle-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-middle-top-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-right-bottom-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-right-middle-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace-right-top-double-loaded-interior.osw'].include? osw_file
    step.setArgument('geometry_corridor_position', 'Double-Loaded Interior')
  end

  # Warnings/Errors
  if ['invalid_files/non-electric-heat-pump-water-heater.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeHeatPump)
    step.setArgument('water_heater_fuel_type', HPXML::FuelTypeNaturalGas)
    step.setArgument('water_heater_efficiency', 2.3)
  elsif ['invalid_files/heating-system-and-heat-pump.osw'].include? osw_file
    step.setArgument('cooling_system_type', 'none')
    step.setArgument('heat_pump_type', HPXML::HVACTypeHeatPumpAirToAir)
  elsif ['invalid_files/cooling-system-and-heat-pump.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('heat_pump_type', HPXML::HVACTypeHeatPumpAirToAir)
  elsif ['invalid_files/non-integer-geometry-num-bathrooms.osw'].include? osw_file
    step.setArgument('geometry_num_bathrooms', '1.5')
  elsif ['invalid_files/non-integer-ceiling-fan-quantity.osw'].include? osw_file
    step.setArgument('ceiling_fan_quantity', '0.5')
  elsif ['invalid_files/single-family-detached-slab-non-zero-foundation-height.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeSlab)
    step.setArgument('geometry_foundation_height_above_grade', 0.0)
  elsif ['invalid_files/single-family-detached-finished-basement-zero-foundation-height.osw'].include? osw_file
    step.setArgument('geometry_foundation_height', 0.0)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', Constants.Auto)
  elsif ['invalid_files/single-family-attached-ambient.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeAmbient)
    step.setArgument('geometry_rim_joist_height', 0)
  elsif ['invalid_files/multifamily-bottom-slab-non-zero-foundation-height.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeSlab)
    step.setArgument('geometry_foundation_height_above_grade', 0.0)
    step.setArgument('geometry_level', 'Bottom')
  elsif ['invalid_files/multifamily-bottom-crawlspace-zero-foundation-height.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeCrawlspaceUnvented)
    step.setArgument('geometry_foundation_height', 0.0)
    step.setArgument('geometry_level', 'Bottom')
    step.setArgument('foundation_wall_insulation_distance_to_bottom', Constants.Auto)
  elsif ['invalid_files/slab-non-zero-foundation-height-above-grade.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeSlab)
    step.setArgument('geometry_foundation_height', 0.0)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', Constants.Auto)
  elsif ['invalid_files/ducts-location-and-areas-not-same-type.osw'].include? osw_file
    step.setArgument('ducts_supply_location', Constants.Auto)
  elsif ['invalid_files/second-heating-system-serves-majority-heat.osw'].include? osw_file
    step.setArgument('heating_system_fraction_heat_load_served', 0.4)
    step.setArgument('heating_system_type_2', HPXML::HVACTypeFireplace)
    step.setArgument('heating_system_fraction_heat_load_served_2', 0.6)
  elsif ['invalid_files/second-heating-system-serves-total-heat-load.osw'].include? osw_file
    step.setArgument('heating_system_type_2', HPXML::HVACTypeFireplace)
    step.setArgument('heating_system_fraction_heat_load_served_2', 1.0)
  elsif ['invalid_files/second-heating-system-but-no-primary-heating.osw'].include? osw_file
    step.setArgument('heating_system_type', 'none')
    step.setArgument('heating_system_type_2', HPXML::HVACTypeFireplace)
  elsif ['invalid_files/single-family-attached-no-building-orientation.osw'].include? osw_file
    step.removeArgument('geometry_building_num_units')
    step.removeArgument('geometry_horizontal_location')
  elsif ['invalid_files/multifamily-no-building-orientation.osw'].include? osw_file
    step.removeArgument('geometry_building_num_units')
    step.removeArgument('geometry_level')
    step.removeArgument('geometry_horizontal_location')
  elsif ['invalid_files/vented-crawlspace-with-wall-and-ceiling-insulation.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeCrawlspaceVented)
    step.setArgument('geometry_foundation_height', 3.0)
    step.setArgument('floor_assembly_r', 10)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '0.0')
  elsif ['invalid_files/unvented-crawlspace-with-wall-and-ceiling-insulation.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeCrawlspaceUnvented)
    step.setArgument('geometry_foundation_height', 3.0)
    step.setArgument('floor_assembly_r', 10)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '0.0')
  elsif ['invalid_files/unconditioned-basement-with-wall-and-ceiling-insulation.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeBasementUnconditioned)
    step.setArgument('floor_assembly_r', 10)
  elsif ['invalid_files/vented-attic-with-floor-and-roof-insulation.osw'].include? osw_file
    step.setArgument('geometry_attic_type', HPXML::AtticTypeVented)
    step.setArgument('roof_assembly_r', 10)
    step.setArgument('ducts_supply_location', HPXML::LocationAtticVented)
    step.setArgument('ducts_return_location', HPXML::LocationAtticVented)
  elsif ['invalid_files/unvented-attic-with-floor-and-roof-insulation.osw'].include? osw_file
    step.setArgument('geometry_attic_type', HPXML::AtticTypeUnvented)
    step.setArgument('roof_assembly_r', 10)
  elsif ['invalid_files/conditioned-basement-with-ceiling-insulation.osw'].include? osw_file
    step.setArgument('geometry_foundation_type', HPXML::FoundationTypeBasementConditioned)
    step.setArgument('floor_assembly_r', 10)
  elsif ['invalid_files/conditioned-attic-with-floor-insulation.osw'].include? osw_file
    step.setArgument('geometry_num_floors_above_grade', 2)
    step.setArgument('geometry_attic_type', HPXML::AtticTypeConditioned)
    step.setArgument('ducts_supply_location', HPXML::LocationLivingSpace)
    step.setArgument('ducts_return_location', HPXML::LocationLivingSpace)
  elsif ['invalid_files/dhw-indirect-without-boiler.osw'].include? osw_file
    step.setArgument('water_heater_type', HPXML::WaterHeaterTypeCombiStorage)
  elsif ['invalid_files/multipliers-without-tv-plug-loads.osw'].include? osw_file
    step.setArgument('plug_loads_television_annual_kwh', '0.0')
  elsif ['invalid_files/multipliers-without-other-plug-loads.osw'].include? osw_file
    step.setArgument('plug_loads_other_annual_kwh', '0.0')
  elsif ['invalid_files/multipliers-without-well-pump-plug-loads.osw'].include? osw_file
    step.setArgument('plug_loads_well_pump_annual_kwh', '0.0')
    step.setArgument('plug_loads_well_pump_usage_multiplier', 1.0)
  elsif ['invalid_files/multipliers-without-vehicle-plug-loads.osw'].include? osw_file
    step.setArgument('plug_loads_vehicle_annual_kwh', '0.0')
    step.setArgument('plug_loads_vehicle_usage_multiplier', 1.0)
  elsif ['invalid_files/multipliers-without-fuel-loads.osw'].include? osw_file
    step.setArgument('fuel_loads_grill_usage_multiplier', 1.0)
    step.setArgument('fuel_loads_lighting_usage_multiplier', 1.0)
    step.setArgument('fuel_loads_fireplace_usage_multiplier', 1.0)
  elsif ['invalid_files/foundation-wall-insulation-greater-than-height.osw'].include? osw_file
    step.setArgument('floor_assembly_r', 0)
    step.setArgument('foundation_wall_insulation_distance_to_bottom', '6.0')
  elsif ['invalid_files/conditioned-attic-with-one-floor-above-grade.osw'].include? osw_file
    step.setArgument('geometry_attic_type', HPXML::AtticTypeConditioned)
    step.setArgument('ceiling_assembly_r', 0.0)
  elsif ['invalid_files/zero-number-of-bedrooms.osw'].include? osw_file
    step.setArgument('geometry_num_bedrooms', 0)
  elsif ['invalid_files/single-family-detached-with-shared-system.osw'].include? osw_file
    step.setArgument('heating_system_type', "Shared #{HPXML::HVACTypeBoiler} w/ Baseboard")
  elsif ['invalid_files/hvac-seasons-incomplete-heating-season.osw'].include? osw_file
    step.setArgument('season_heating_begin_month', 11)
    step.setArgument('season_heating_end_month', 6)
  elsif ['invalid_files/hvac-seasons-incomplete-cooling-season.osw'].include? osw_file
    step.setArgument('season_cooling_begin_day_of_month', 1)
    step.setArgument('season_cooling_end_day_of_month', 31)
  elsif ['invalid_files/schedules-vacancy-incomplete.osw'].include? osw_file
    step.setArgument('schedules_vacancy_begin_month', 1)
    step.setArgument('schedules_vacancy_end_month', 2)
  elsif ['invalid_files/schedules-vacancy-invalid.osw'].include? osw_file
    step.setArgument('schedules_vacancy_begin_month', 1)
    step.setArgument('schedules_vacancy_begin_day_of_month', 1)
    step.setArgument('schedules_vacancy_end_month', 4)
    step.setArgument('schedules_vacancy_end_day_of_month', 31)
  end
  return step
end

def create_hpxmls
  require_relative 'HPXMLtoOpenStudio/resources/constants'
  require_relative 'HPXMLtoOpenStudio/resources/hotwater_appliances'
  require_relative 'HPXMLtoOpenStudio/resources/hpxml'
  require_relative 'HPXMLtoOpenStudio/resources/location'
  require_relative 'HPXMLtoOpenStudio/resources/misc_loads'
  require_relative 'HPXMLtoOpenStudio/resources/schedules'
  require_relative 'HPXMLtoOpenStudio/resources/waterheater'

  this_dir = File.dirname(__FILE__)
  sample_files_dir = File.join(this_dir, 'workflow/sample_files')
  hpxml_docs = {}

  # Hash of HPXML -> Parent HPXML
  hpxmls_files = {
    'base.xml' => nil,

    'ASHRAE_Standard_140/L100AC.xml' => nil,
    'ASHRAE_Standard_140/L100AL.xml' => nil,
    'ASHRAE_Standard_140/L110AC.xml' => 'ASHRAE_Standard_140/L100AC.xml',
    'ASHRAE_Standard_140/L110AL.xml' => 'ASHRAE_Standard_140/L100AL.xml',
    'ASHRAE_Standard_140/L120AC.xml' => 'ASHRAE_Standard_140/L100AC.xml',
    'ASHRAE_Standard_140/L120AL.xml' => 'ASHRAE_Standard_140/L100AL.xml',
    'ASHRAE_Standard_140/L130AC.xml' => 'ASHRAE_Standard_140/L100AC.xml',
    'ASHRAE_Standard_140/L130AL.xml' => 'ASHRAE_Standard_140/L100AL.xml',
    'ASHRAE_Standard_140/L140AC.xml' => 'ASHRAE_Standard_140/L100AC.xml',
    'ASHRAE_Standard_140/L140AL.xml' => 'ASHRAE_Standard_140/L100AL.xml',
    'ASHRAE_Standard_140/L150AC.xml' => 'ASHRAE_Standard_140/L100AC.xml',
    'ASHRAE_Standard_140/L150AL.xml' => 'ASHRAE_Standard_140/L100AL.xml',
    'ASHRAE_Standard_140/L160AC.xml' => 'ASHRAE_Standard_140/L100AC.xml',
    'ASHRAE_Standard_140/L160AL.xml' => 'ASHRAE_Standard_140/L100AL.xml',
    'ASHRAE_Standard_140/L170AC.xml' => 'ASHRAE_Standard_140/L100AC.xml',
    'ASHRAE_Standard_140/L170AL.xml' => 'ASHRAE_Standard_140/L100AL.xml',
    'ASHRAE_Standard_140/L200AC.xml' => 'ASHRAE_Standard_140/L100AC.xml',
    'ASHRAE_Standard_140/L200AL.xml' => 'ASHRAE_Standard_140/L100AL.xml',
    'ASHRAE_Standard_140/L302XC.xml' => 'ASHRAE_Standard_140/L100AC.xml',
    'ASHRAE_Standard_140/L322XC.xml' => 'ASHRAE_Standard_140/L100AC.xml',
    'ASHRAE_Standard_140/L155AC.xml' => 'ASHRAE_Standard_140/L150AC.xml',
    'ASHRAE_Standard_140/L155AL.xml' => 'ASHRAE_Standard_140/L150AL.xml',
    'ASHRAE_Standard_140/L202AC.xml' => 'ASHRAE_Standard_140/L200AC.xml',
    'ASHRAE_Standard_140/L202AL.xml' => 'ASHRAE_Standard_140/L200AL.xml',
    'ASHRAE_Standard_140/L304XC.xml' => 'ASHRAE_Standard_140/L302XC.xml',
    'ASHRAE_Standard_140/L324XC.xml' => 'ASHRAE_Standard_140/L322XC.xml',

    'invalid_files/boiler-invalid-afue.xml' => 'base-hvac-boiler-oil-only.xml',
    'invalid_files/cfis-with-hydronic-distribution.xml' => 'base-hvac-boiler-gas-only.xml',
    'invalid_files/clothes-washer-location.xml' => 'base.xml',
    'invalid_files/clothes-dryer-location.xml' => 'base.xml',
    'invalid_files/cooking-range-location.xml' => 'base.xml',
    'invalid_files/dehumidifier-fraction-served.xml' => 'base-appliances-dehumidifier-multiple.xml',
    'invalid_files/dehumidifier-setpoints.xml' => 'base-appliances-dehumidifier-multiple.xml',
    'invalid_files/dhw-frac-load-served.xml' => 'base-dhw-multiple.xml',
    'invalid_files/dhw-invalid-ef-tank.xml' => 'base.xml',
    'invalid_files/dhw-invalid-uef-tank-heat-pump.xml' => 'base-dhw-tank-heat-pump-uef.xml',
    'invalid_files/dishwasher-location.xml' => 'base.xml',
    'invalid_files/duct-leakage-cfm25.xml' => 'base.xml',
    'invalid_files/duct-leakage-percent.xml' => 'base.xml',
    'invalid_files/duct-location.xml' => 'base.xml',
    'invalid_files/duct-location-unconditioned-space.xml' => 'base.xml',
    'invalid_files/duplicate-id.xml' => 'base.xml',
    'invalid_files/enclosure-attic-missing-roof.xml' => 'base.xml',
    'invalid_files/enclosure-basement-missing-exterior-foundation-wall.xml' => 'base-foundation-unconditioned-basement.xml',
    'invalid_files/enclosure-basement-missing-slab.xml' => 'base-foundation-unconditioned-basement.xml',
    'invalid_files/enclosure-floor-area-exceeds-cfa.xml' => 'base.xml',
    'invalid_files/enclosure-floor-area-exceeds-cfa2.xml' => 'base-bldgtype-multifamily.xml',
    'invalid_files/enclosure-garage-missing-exterior-wall.xml' => 'base-enclosure-garage.xml',
    'invalid_files/enclosure-garage-missing-roof-ceiling.xml' => 'base-enclosure-garage.xml',
    'invalid_files/enclosure-garage-missing-slab.xml' => 'base-enclosure-garage.xml',
    'invalid_files/enclosure-living-missing-ceiling-roof.xml' => 'base.xml',
    'invalid_files/enclosure-living-missing-exterior-wall.xml' => 'base.xml',
    'invalid_files/enclosure-living-missing-floor-slab.xml' => 'base-foundation-slab.xml',
    'invalid_files/frac-sensible-fuel-load.xml' => 'base-misc-loads-large-uncommon.xml',
    'invalid_files/frac-sensible-plug-load.xml' => 'base-misc-loads-large-uncommon.xml',
    'invalid_files/frac-total-fuel-load.xml' => 'base-misc-loads-large-uncommon.xml',
    'invalid_files/frac-total-plug-load.xml' => 'base-misc-loads-large-uncommon.xml',
    'invalid_files/furnace-invalid-afue.xml' => 'base.xml',
    'invalid_files/heat-pump-mixed-fixed-and-autosize-capacities.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'invalid_files/hvac-invalid-distribution-system-type.xml' => 'base.xml',
    'invalid_files/hvac-distribution-multiple-attached-cooling.xml' => 'base-hvac-multiple.xml',
    'invalid_files/hvac-distribution-multiple-attached-heating.xml' => 'base-hvac-multiple.xml',
    'invalid_files/hvac-distribution-return-duct-leakage-missing.xml' => 'base-hvac-evap-cooler-only-ducted.xml',
    'invalid_files/hvac-dse-multiple-attached-cooling.xml' => 'base-hvac-dse.xml',
    'invalid_files/hvac-dse-multiple-attached-heating.xml' => 'base-hvac-dse.xml',
    'invalid_files/hvac-frac-load-served.xml' => 'base-hvac-multiple.xml',
    'invalid_files/hvac-inconsistent-fan-powers.xml' => 'base.xml',
    'invalid_files/hvac-seasons-less-than-a-year.xml' => 'base.xml',
    'invalid_files/hvac-shared-negative-seer-eq.xml' => 'base-bldgtype-multifamily-shared-chiller-only-baseboard.xml',
    'invalid_files/generator-number-of-bedrooms-served.xml' => 'base-bldgtype-multifamily-shared-generator.xml',
    'invalid_files/generator-output-greater-than-consumption.xml' => 'base-misc-generators.xml',
    'invalid_files/invalid-assembly-effective-rvalue.xml' => 'base.xml',
    'invalid_files/invalid-datatype-boolean.xml' => 'base.xml',
    'invalid_files/invalid-datatype-float.xml' => 'base.xml',
    'invalid_files/invalid-datatype-integer.xml' => 'base.xml',
    'invalid_files/invalid-daylight-saving.xml' => 'base-simcontrol-daylight-saving-custom.xml',
    'invalid_files/invalid-distribution-cfa-served.xml' => 'base.xml',
    'invalid_files/invalid-duct-area-fractions.xml' => 'base-hvac-ducts-area-fractions.xml',
    'invalid_files/invalid-epw-filepath.xml' => 'base.xml',
    'invalid_files/invalid-facility-type-equipment.xml' => 'base-bldgtype-multifamily-shared-laundry-room.xml',
    'invalid_files/invalid-facility-type-surfaces.xml' => 'base.xml',
    'invalid_files/invalid-foundation-wall-properties.xml' => 'base-foundation-unconditioned-basement-wall-insulation.xml',
    'invalid_files/invalid-id.xml' => 'base-enclosure-skylights.xml',
    'invalid_files/invalid-id2.xml' => 'base-enclosure-skylights.xml',
    'invalid_files/invalid-infiltration-volume.xml' => 'base.xml',
    'invalid_files/invalid-input-parameters.xml' => 'base.xml',
    'invalid_files/invalid-insulation-top.xml' => 'base.xml',
    'invalid_files/invalid-neighbor-shading-azimuth.xml' => 'base-misc-neighbor-shading.xml',
    'invalid_files/invalid-number-of-bedrooms-served.xml' => 'base-bldgtype-multifamily-shared-pv.xml',
    'invalid_files/invalid-number-of-conditioned-floors.xml' => 'base.xml',
    'invalid_files/invalid-number-of-units-served.xml' => 'base-bldgtype-multifamily-shared-water-heater.xml',
    'invalid_files/invalid-relatedhvac-dhw-indirect.xml' => 'base-dhw-indirect.xml',
    'invalid_files/invalid-relatedhvac-desuperheater.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'invalid_files/invalid-runperiod.xml' => 'base.xml',
    'invalid_files/invalid-schema-version.xml' => 'base.xml',
    'invalid_files/invalid-shared-vent-in-unit-flowrate.xml' => 'base-bldgtype-multifamily-shared-mechvent.xml',
    'invalid_files/invalid-timestep.xml' => 'base.xml',
    'invalid_files/invalid-window-height.xml' => 'base-enclosure-overhangs.xml',
    'invalid_files/lighting-fractions.xml' => 'base.xml',
    'invalid_files/missing-duct-area.xml' => 'base-hvac-multiple.xml',
    'invalid_files/missing-duct-location.xml' => 'base-hvac-multiple.xml',
    'invalid_files/missing-elements.xml' => 'base.xml',
    'invalid_files/multifamily-reference-appliance.xml' => 'base.xml',
    'invalid_files/multifamily-reference-duct.xml' => 'base.xml',
    'invalid_files/multifamily-reference-surface.xml' => 'base.xml',
    'invalid_files/multifamily-reference-water-heater.xml' => 'base.xml',
    'invalid_files/multiple-buildings-without-building-id.xml' => 'base.xml',
    'invalid_files/multiple-buildings-wrong-building-id.xml' => 'base.xml',
    'invalid_files/multiple-shared-cooling-systems.xml' => 'base-bldgtype-multifamily-shared-chiller-only-baseboard.xml',
    'invalid_files/multiple-shared-heating-systems.xml' => 'base-bldgtype-multifamily-shared-boiler-only-baseboard.xml',
    'invalid_files/net-area-negative-roof.xml' => 'base-enclosure-skylights.xml',
    'invalid_files/net-area-negative-wall.xml' => 'base.xml',
    'invalid_files/orphaned-hvac-distribution.xml' => 'base-hvac-furnace-gas-room-ac.xml',
    'invalid_files/refrigerator-location.xml' => 'base.xml',
    'invalid_files/refrigerators-multiple-primary.xml' => 'base.xml',
    'invalid_files/refrigerators-no-primary.xml' => 'base.xml',
    'invalid_files/repeated-relatedhvac-dhw-indirect.xml' => 'base-dhw-indirect.xml',
    'invalid_files/repeated-relatedhvac-desuperheater.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'invalid_files/solar-fraction-one.xml' => 'base-dhw-solar-fraction.xml',
    'invalid_files/solar-thermal-system-with-combi-tankless.xml' => 'base-dhw-combi-tankless.xml',
    'invalid_files/solar-thermal-system-with-desuperheater.xml' => 'base-dhw-desuperheater.xml',
    'invalid_files/solar-thermal-system-with-dhw-indirect.xml' => 'base-dhw-combi-tankless.xml',
    'invalid_files/unattached-cfis.xml' => 'base.xml',
    'invalid_files/unattached-door.xml' => 'base.xml',
    'invalid_files/unattached-hvac-distribution.xml' => 'base.xml',
    'invalid_files/unattached-skylight.xml' => 'base-enclosure-skylights.xml',
    'invalid_files/unattached-solar-thermal-system.xml' => 'base-dhw-solar-indirect-flat-plate.xml',
    'invalid_files/unattached-shared-clothes-washer-water-heater.xml' => 'base-bldgtype-multifamily-shared-laundry-room.xml',
    'invalid_files/unattached-shared-dishwasher-water-heater.xml' => 'base-bldgtype-multifamily-shared-laundry-room.xml',
    'invalid_files/unattached-window.xml' => 'base.xml',
    'invalid_files/water-heater-location.xml' => 'base.xml',
    'invalid_files/water-heater-location-other.xml' => 'base.xml',
    'base-appliances-coal.xml' => 'base.xml',
    'base-appliances-dehumidifier.xml' => 'base-location-dallas-tx.xml',
    'base-appliances-dehumidifier-ief-portable.xml' => 'base-appliances-dehumidifier.xml',
    'base-appliances-dehumidifier-ief-whole-home.xml' => 'base-appliances-dehumidifier-ief-portable.xml',
    'base-appliances-dehumidifier-multiple.xml' => 'base-appliances-dehumidifier.xml',
    'base-appliances-gas.xml' => 'base.xml',
    'base-appliances-modified.xml' => 'base.xml',
    'base-appliances-none.xml' => 'base.xml',
    'base-appliances-oil.xml' => 'base.xml',
    'base-appliances-propane.xml' => 'base.xml',
    'base-appliances-wood.xml' => 'base.xml',
    'base-atticroof-cathedral.xml' => 'base.xml',
    'base-atticroof-conditioned.xml' => 'base.xml',
    'base-atticroof-flat.xml' => 'base.xml',
    'base-atticroof-radiant-barrier.xml' => 'base-location-dallas-tx.xml',
    'base-atticroof-vented.xml' => 'base.xml',
    'base-atticroof-unvented-insulated-roof.xml' => 'base.xml',
    'base-bldgtype-multifamily.xml' => 'base.xml',
    'base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-adjacent-to-other-heated-space.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-adjacent-to-multiple.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-boiler-chiller-baseboard.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil.xml' => 'base-bldgtype-multifamily-shared-boiler-chiller-baseboard.xml',
    'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil-ducted.xml' => 'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil.xml',
    'base-bldgtype-multifamily-shared-boiler-chiller-water-loop-heat-pump.xml' => 'base-bldgtype-multifamily-shared-boiler-chiller-baseboard.xml',
    'base-bldgtype-multifamily-shared-boiler-cooling-tower-water-loop-heat-pump.xml' => 'base-bldgtype-multifamily-shared-boiler-chiller-water-loop-heat-pump.xml',
    'base-bldgtype-multifamily-shared-boiler-only-baseboard.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-boiler-only-fan-coil.xml' => 'base-bldgtype-multifamily-shared-boiler-only-baseboard.xml',
    'base-bldgtype-multifamily-shared-boiler-only-fan-coil-ducted.xml' => 'base-bldgtype-multifamily-shared-boiler-only-fan-coil.xml',
    'base-bldgtype-multifamily-shared-boiler-only-fan-coil-eae.xml' => 'base-bldgtype-multifamily-shared-boiler-only-fan-coil.xml',
    'base-bldgtype-multifamily-shared-boiler-only-water-loop-heat-pump.xml' => 'base-bldgtype-multifamily-shared-boiler-only-baseboard.xml',
    'base-bldgtype-multifamily-shared-chiller-only-baseboard.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-chiller-only-fan-coil.xml' => 'base-bldgtype-multifamily-shared-chiller-only-baseboard.xml',
    'base-bldgtype-multifamily-shared-chiller-only-fan-coil-ducted.xml' => 'base-bldgtype-multifamily-shared-chiller-only-fan-coil.xml',
    'base-bldgtype-multifamily-shared-chiller-only-water-loop-heat-pump.xml' => 'base-bldgtype-multifamily-shared-chiller-only-baseboard.xml',
    'base-bldgtype-multifamily-shared-cooling-tower-only-water-loop-heat-pump.xml' => 'base-bldgtype-multifamily-shared-chiller-only-water-loop-heat-pump.xml',
    'base-bldgtype-multifamily-shared-generator.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-ground-loop-ground-to-air-heat-pump.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-laundry-room.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-mechvent.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-mechvent-preconditioning.xml' => 'base-bldgtype-multifamily-shared-mechvent.xml',
    'base-bldgtype-multifamily-shared-mechvent-multiple.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-pv.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-water-heater.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-water-heater-recirc.xml' => 'base-bldgtype-multifamily-shared-water-heater.xml',
    'base-bldgtype-single-family-attached.xml' => 'base.xml',
    'base-dhw-combi-tankless.xml' => 'base-dhw-indirect.xml',
    'base-dhw-combi-tankless-outside.xml' => 'base-dhw-combi-tankless.xml',
    'base-dhw-desuperheater.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'base-dhw-desuperheater-hpwh.xml' => 'base-dhw-tank-heat-pump.xml',
    'base-dhw-desuperheater-tankless.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'base-dhw-desuperheater-2-speed.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'base-dhw-desuperheater-var-speed.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'base-dhw-desuperheater-gshp.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'base-dhw-dwhr.xml' => 'base.xml',
    'base-dhw-indirect.xml' => 'base-hvac-boiler-gas-only.xml',
    'base-dhw-indirect-dse.xml' => 'base-dhw-indirect.xml',
    'base-dhw-indirect-outside.xml' => 'base-dhw-indirect.xml',
    'base-dhw-indirect-standbyloss.xml' => 'base-dhw-indirect.xml',
    'base-dhw-indirect-with-solar-fraction.xml' => 'base-dhw-indirect.xml',
    'base-dhw-low-flow-fixtures.xml' => 'base.xml',
    'base-dhw-multiple.xml' => 'base-hvac-boiler-gas-only.xml',
    'base-dhw-none.xml' => 'base.xml',
    'base-dhw-recirc-demand.xml' => 'base.xml',
    'base-dhw-recirc-manual.xml' => 'base.xml',
    'base-dhw-recirc-nocontrol.xml' => 'base.xml',
    'base-dhw-recirc-temperature.xml' => 'base.xml',
    'base-dhw-recirc-timer.xml' => 'base.xml',
    'base-dhw-solar-direct-evacuated-tube.xml' => 'base.xml',
    'base-dhw-solar-direct-flat-plate.xml' => 'base.xml',
    'base-dhw-solar-direct-ics.xml' => 'base.xml',
    'base-dhw-solar-fraction.xml' => 'base.xml',
    'base-dhw-solar-indirect-flat-plate.xml' => 'base.xml',
    'base-dhw-solar-thermosyphon-flat-plate.xml' => 'base.xml',
    'base-dhw-tank-coal.xml' => 'base.xml',
    'base-dhw-tank-elec-uef.xml' => 'base.xml',
    'base-dhw-tank-gas.xml' => 'base.xml',
    'base-dhw-tank-gas-uef.xml' => 'base.xml',
    'base-dhw-tank-gas-uef-fhr.xml' => 'base-dhw-tank-gas-uef.xml',
    'base-dhw-tank-gas-outside.xml' => 'base-dhw-tank-gas.xml',
    'base-dhw-tank-heat-pump.xml' => 'base.xml',
    'base-dhw-tank-heat-pump-outside.xml' => 'base-dhw-tank-heat-pump.xml',
    'base-dhw-tank-heat-pump-uef.xml' => 'base.xml',
    'base-dhw-tank-heat-pump-with-solar.xml' => 'base-dhw-tank-heat-pump.xml',
    'base-dhw-tank-heat-pump-with-solar-fraction.xml' => 'base-dhw-tank-heat-pump.xml',
    'base-dhw-tank-oil.xml' => 'base.xml',
    'base-dhw-tank-wood.xml' => 'base.xml',
    'base-dhw-tankless-electric.xml' => 'base.xml',
    'base-dhw-tankless-electric-uef.xml' => 'base.xml',
    'base-dhw-tankless-electric-outside.xml' => 'base-dhw-tankless-electric.xml',
    'base-dhw-tankless-gas.xml' => 'base.xml',
    'base-dhw-tankless-gas-uef.xml' => 'base.xml',
    'base-dhw-tankless-gas-with-solar.xml' => 'base-dhw-tankless-gas.xml',
    'base-dhw-tankless-gas-with-solar-fraction.xml' => 'base-dhw-tankless-gas.xml',
    'base-dhw-tankless-propane.xml' => 'base.xml',
    'base-dhw-jacket-electric.xml' => 'base.xml',
    'base-dhw-jacket-gas.xml' => 'base-dhw-tank-gas.xml',
    'base-dhw-jacket-indirect.xml' => 'base-dhw-indirect.xml',
    'base-dhw-jacket-hpwh.xml' => 'base-dhw-tank-heat-pump.xml',
    'base-enclosure-2stories.xml' => 'base.xml',
    'base-enclosure-2stories-garage.xml' => 'base-enclosure-2stories.xml',
    'base-enclosure-beds-1.xml' => 'base.xml',
    'base-enclosure-beds-2.xml' => 'base.xml',
    'base-enclosure-beds-4.xml' => 'base.xml',
    'base-enclosure-beds-5.xml' => 'base.xml',
    'base-enclosure-garage.xml' => 'base.xml',
    'base-enclosure-infil-ach-house-pressure.xml' => 'base.xml',
    'base-enclosure-infil-cfm-house-pressure.xml' => 'base-enclosure-infil-cfm50.xml',
    'base-enclosure-infil-cfm50.xml' => 'base.xml',
    'base-enclosure-infil-flue.xml' => 'base.xml',
    'base-enclosure-infil-natural-ach.xml' => 'base.xml',
    'base-enclosure-orientations.xml' => 'base.xml',
    'base-enclosure-overhangs.xml' => 'base.xml',
    'base-enclosure-rooftypes.xml' => 'base.xml',
    'base-enclosure-skylights.xml' => 'base.xml',
    'base-enclosure-skylights-shading.xml' => 'base-enclosure-skylights.xml',
    'base-enclosure-split-level.xml' => 'base-foundation-slab.xml',
    'base-enclosure-split-surfaces.xml' => 'base-enclosure-skylights.xml', # Surfaces should collapse via HPXML.collapse_enclosure_surfaces()
    'base-enclosure-split-surfaces2.xml' => 'base-enclosure-skylights.xml', # Surfaces should NOT collapse via HPXML.collapse_enclosure_surfaces()
    'base-enclosure-walltypes.xml' => 'base.xml',
    'base-enclosure-windows-shading.xml' => 'base.xml',
    'base-enclosure-windows-none.xml' => 'base.xml',
    'base-foundation-multiple.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-ambient.xml' => 'base.xml',
    'base-foundation-conditioned-basement-slab-insulation.xml' => 'base.xml',
    'base-foundation-conditioned-basement-wall-interior-insulation.xml' => 'base.xml',
    'base-foundation-slab.xml' => 'base.xml',
    'base-foundation-unconditioned-basement.xml' => 'base.xml',
    'base-foundation-unconditioned-basement-assembly-r.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-unconditioned-basement-above-grade.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-unconditioned-basement-wall-insulation.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-unvented-crawlspace.xml' => 'base.xml',
    'base-foundation-vented-crawlspace.xml' => 'base.xml',
    'base-foundation-walkout-basement.xml' => 'base.xml',
    'base-foundation-complex.xml' => 'base.xml',
    'base-foundation-basement-garage.xml' => 'base.xml',
    'base-hvac-air-to-air-heat-pump-1-speed.xml' => 'base.xml',
    'base-hvac-air-to-air-heat-pump-1-speed-cooling-only.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-air-to-air-heat-pump-1-speed-heating-only.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-air-to-air-heat-pump-2-speed.xml' => 'base.xml',
    'base-hvac-air-to-air-heat-pump-var-speed.xml' => 'base.xml',
    'base-hvac-autosize.xml' => 'base.xml',
    'base-hvac-autosize-air-to-air-heat-pump-1-speed.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-autosize-air-to-air-heat-pump-1-speed-cooling-only.xml' => 'base-hvac-air-to-air-heat-pump-1-speed-cooling-only.xml',
    'base-hvac-autosize-air-to-air-heat-pump-1-speed-heating-only.xml' => 'base-hvac-air-to-air-heat-pump-1-speed-heating-only.xml',
    'base-hvac-autosize-air-to-air-heat-pump-1-speed-manual-s-oversize-allowances.xml' => 'base-hvac-autosize-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-autosize-air-to-air-heat-pump-2-speed.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'base-hvac-autosize-air-to-air-heat-pump-2-speed-manual-s-oversize-allowances.xml' => 'base-hvac-autosize-air-to-air-heat-pump-2-speed.xml',
    'base-hvac-autosize-air-to-air-heat-pump-var-speed.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'base-hvac-autosize-air-to-air-heat-pump-var-speed-manual-s-oversize-allowances.xml' => 'base-hvac-autosize-air-to-air-heat-pump-var-speed.xml',
    'base-hvac-autosize-boiler-elec-only.xml' => 'base-hvac-boiler-elec-only.xml',
    'base-hvac-autosize-boiler-gas-central-ac-1-speed.xml' => 'base-hvac-boiler-gas-central-ac-1-speed.xml',
    'base-hvac-autosize-boiler-gas-only.xml' => 'base-hvac-boiler-gas-only.xml',
    'base-hvac-autosize-central-ac-only-1-speed.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'base-hvac-autosize-central-ac-only-2-speed.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'base-hvac-autosize-central-ac-only-var-speed.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'base-hvac-autosize-central-ac-plus-air-to-air-heat-pump-heating.xml' => 'base-hvac-central-ac-plus-air-to-air-heat-pump-heating.xml',
    'base-hvac-autosize-dual-fuel-air-to-air-heat-pump-1-speed.xml' => 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-autosize-dual-fuel-mini-split-heat-pump-ducted.xml' => 'base-hvac-dual-fuel-mini-split-heat-pump-ducted.xml',
    'base-hvac-autosize-elec-resistance-only.xml' => 'base-hvac-elec-resistance-only.xml',
    'base-hvac-autosize-evap-cooler-furnace-gas.xml' => 'base-hvac-evap-cooler-furnace-gas.xml',
    'base-hvac-autosize-floor-furnace-propane-only.xml' => 'base-hvac-floor-furnace-propane-only.xml',
    'base-hvac-autosize-furnace-elec-only.xml' => 'base-hvac-furnace-elec-only.xml',
    'base-hvac-autosize-furnace-gas-central-ac-2-speed.xml' => 'base-hvac-furnace-gas-central-ac-2-speed.xml',
    'base-hvac-autosize-furnace-gas-central-ac-var-speed.xml' => 'base-hvac-furnace-gas-central-ac-var-speed.xml',
    'base-hvac-autosize-furnace-gas-only.xml' => 'base-hvac-furnace-gas-only.xml',
    'base-hvac-autosize-furnace-gas-room-ac.xml' => 'base-hvac-furnace-gas-room-ac.xml',
    'base-hvac-autosize-ground-to-air-heat-pump.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'base-hvac-autosize-ground-to-air-heat-pump-cooling-only.xml' => 'base-hvac-ground-to-air-heat-pump-cooling-only.xml',
    'base-hvac-autosize-ground-to-air-heat-pump-heating-only.xml' => 'base-hvac-ground-to-air-heat-pump-heating-only.xml',
    'base-hvac-autosize-ground-to-air-heat-pump-manual-s-oversize-allowances.xml' => 'base-hvac-autosize-ground-to-air-heat-pump.xml',
    'base-hvac-autosize-mini-split-heat-pump-ducted.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-autosize-mini-split-heat-pump-ducted-cooling-only.xml' => 'base-hvac-mini-split-heat-pump-ducted-cooling-only.xml',
    'base-hvac-autosize-mini-split-heat-pump-ducted-heating-only.xml' => 'base-hvac-mini-split-heat-pump-ducted-heating-only.xml',
    'base-hvac-autosize-mini-split-heat-pump-ducted-manual-s-oversize-allowances.xml' => 'base-hvac-autosize-mini-split-heat-pump-ducted.xml',
    'base-hvac-autosize-mini-split-air-conditioner-only-ducted.xml' => 'base-hvac-mini-split-air-conditioner-only-ducted.xml',
    'base-hvac-autosize-room-ac-only.xml' => 'base-hvac-room-ac-only.xml',
    'base-hvac-autosize-stove-oil-only.xml' => 'base-hvac-stove-oil-only.xml',
    'base-hvac-autosize-wall-furnace-elec-only.xml' => 'base-hvac-wall-furnace-elec-only.xml',
    'base-hvac-boiler-coal-only.xml' => 'base.xml',
    'base-hvac-boiler-elec-only.xml' => 'base.xml',
    'base-hvac-boiler-gas-central-ac-1-speed.xml' => 'base.xml',
    'base-hvac-boiler-gas-only.xml' => 'base.xml',
    'base-hvac-boiler-oil-only.xml' => 'base.xml',
    'base-hvac-boiler-propane-only.xml' => 'base.xml',
    'base-hvac-boiler-wood-only.xml' => 'base.xml',
    'base-hvac-central-ac-only-1-speed.xml' => 'base.xml',
    'base-hvac-central-ac-only-2-speed.xml' => 'base.xml',
    'base-hvac-central-ac-only-var-speed.xml' => 'base.xml',
    'base-hvac-central-ac-plus-air-to-air-heat-pump-heating.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'base-hvac-dse.xml' => 'base.xml',
    'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed-electric.xml' => 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-dual-fuel-air-to-air-heat-pump-2-speed.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'base-hvac-dual-fuel-air-to-air-heat-pump-var-speed.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'base-hvac-dual-fuel-mini-split-heat-pump-ducted.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-ducts-leakage-percent.xml' => 'base.xml',
    'base-hvac-ducts-area-fractions.xml' => 'base-enclosure-2stories.xml',
    'base-hvac-elec-resistance-only.xml' => 'base.xml',
    'base-hvac-evap-cooler-furnace-gas.xml' => 'base.xml',
    'base-hvac-evap-cooler-only.xml' => 'base.xml',
    'base-hvac-evap-cooler-only-ducted.xml' => 'base.xml',
    'base-hvac-fireplace-wood-only.xml' => 'base.xml',
    'base-hvac-fixed-heater-gas-only.xml' => 'base.xml',
    'base-hvac-floor-furnace-propane-only.xml' => 'base.xml',
    'base-hvac-furnace-coal-only.xml' => 'base.xml',
    'base-hvac-furnace-elec-central-ac-1-speed.xml' => 'base.xml',
    'base-hvac-furnace-elec-only.xml' => 'base.xml',
    'base-hvac-furnace-gas-central-ac-2-speed.xml' => 'base.xml',
    'base-hvac-furnace-gas-central-ac-var-speed.xml' => 'base.xml',
    'base-hvac-furnace-gas-only.xml' => 'base.xml',
    'base-hvac-furnace-gas-room-ac.xml' => 'base.xml',
    'base-hvac-furnace-oil-only.xml' => 'base.xml',
    'base-hvac-furnace-propane-only.xml' => 'base.xml',
    'base-hvac-furnace-wood-only.xml' => 'base.xml',
    'base-hvac-furnace-x3-dse.xml' => 'base.xml',
    'base-hvac-ground-to-air-heat-pump.xml' => 'base.xml',
    'base-hvac-ground-to-air-heat-pump-cooling-only.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'base-hvac-ground-to-air-heat-pump-heating-only.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'base-hvac-seasons.xml' => 'base.xml',
    'base-hvac-install-quality-air-to-air-heat-pump-1-speed.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-install-quality-air-to-air-heat-pump-2-speed.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'base-hvac-install-quality-air-to-air-heat-pump-var-speed.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'base-hvac-install-quality-furnace-gas-central-ac-1-speed.xml' => 'base.xml',
    'base-hvac-install-quality-furnace-gas-central-ac-2-speed.xml' => 'base-hvac-furnace-gas-central-ac-2-speed.xml',
    'base-hvac-install-quality-furnace-gas-central-ac-var-speed.xml' => 'base-hvac-furnace-gas-central-ac-var-speed.xml',
    'base-hvac-install-quality-furnace-gas-only.xml' => 'base-hvac-furnace-gas-only.xml',
    'base-hvac-install-quality-ground-to-air-heat-pump.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'base-hvac-install-quality-mini-split-heat-pump-ducted.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-install-quality-mini-split-air-conditioner-only-ducted.xml' => 'base-hvac-mini-split-air-conditioner-only-ducted.xml',
    'base-hvac-mini-split-air-conditioner-only-ducted.xml' => 'base.xml',
    'base-hvac-mini-split-air-conditioner-only-ductless.xml' => 'base-hvac-mini-split-air-conditioner-only-ducted.xml',
    'base-hvac-mini-split-heat-pump-ducted.xml' => 'base.xml',
    'base-hvac-mini-split-heat-pump-ducted-cooling-only.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-mini-split-heat-pump-ducted-heating-only.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-mini-split-heat-pump-ductless.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-multiple.xml' => 'base.xml',
    'base-hvac-none.xml' => 'base.xml',
    'base-hvac-portable-heater-gas-only.xml' => 'base.xml',
    'base-hvac-programmable-thermostat.xml' => 'base.xml',
    'base-hvac-programmable-thermostat-detailed.xml' => 'base.xml',
    'base-hvac-room-ac-only.xml' => 'base.xml',
    'base-hvac-room-ac-only-33percent.xml' => 'base-hvac-room-ac-only.xml',
    'base-hvac-room-ac-only-ceer.xml' => 'base-hvac-room-ac-only.xml',
    'base-hvac-setpoints.xml' => 'base.xml',
    'base-hvac-stove-oil-only.xml' => 'base.xml',
    'base-hvac-stove-wood-pellets-only.xml' => 'base.xml',
    'base-hvac-undersized.xml' => 'base.xml',
    'base-hvac-undersized-allow-increased-fixed-capacities.xml' => 'base-hvac-undersized.xml',
    'base-hvac-wall-furnace-elec-only.xml' => 'base.xml',
    'base-lighting-ceiling-fans.xml' => 'base.xml',
    'base-lighting-detailed.xml' => 'base.xml',
    'base-lighting-none.xml' => 'base.xml',
    'base-location-AMY-2012.xml' => 'base.xml',
    'base-location-baltimore-md.xml' => 'base-foundation-unvented-crawlspace.xml',
    'base-location-dallas-tx.xml' => 'base-foundation-slab.xml',
    'base-location-duluth-mn.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-location-helena-mt.xml' => 'base.xml',
    'base-location-honolulu-hi.xml' => 'base-foundation-slab.xml',
    'base-location-miami-fl.xml' => 'base-foundation-slab.xml',
    'base-location-phoenix-az.xml' => 'base-foundation-slab.xml',
    'base-location-portland-or.xml' => 'base-foundation-vented-crawlspace.xml',
    'base-mechvent-balanced.xml' => 'base.xml',
    'base-mechvent-bath-kitchen-fans.xml' => 'base.xml',
    'base-mechvent-cfis.xml' => 'base.xml',
    'base-mechvent-cfis-dse.xml' => 'base-hvac-dse.xml',
    'base-mechvent-cfis-evap-cooler-only-ducted.xml' => 'base-hvac-evap-cooler-only-ducted.xml',
    'base-mechvent-erv.xml' => 'base.xml',
    'base-mechvent-erv-atre-asre.xml' => 'base.xml',
    'base-mechvent-exhaust.xml' => 'base.xml',
    'base-mechvent-exhaust-rated-flow-rate.xml' => 'base.xml',
    'base-mechvent-hrv.xml' => 'base.xml',
    'base-mechvent-hrv-asre.xml' => 'base.xml',
    'base-mechvent-multiple.xml' => 'base-mechvent-bath-kitchen-fans.xml',
    'base-mechvent-supply.xml' => 'base.xml',
    'base-mechvent-whole-house-fan.xml' => 'base.xml',
    'base-misc-defaults.xml' => 'base.xml',
    'base-misc-generators.xml' => 'base.xml',
    'base-misc-loads-large-uncommon.xml' => 'base.xml',
    'base-misc-loads-large-uncommon2.xml' => 'base-misc-loads-large-uncommon.xml',
    'base-misc-loads-none.xml' => 'base.xml',
    'base-misc-neighbor-shading.xml' => 'base.xml',
    'base-misc-shielding-of-home.xml' => 'base.xml',
    'base-misc-usage-multiplier.xml' => 'base.xml',
    'base-multiple-buildings.xml' => 'base.xml',
    'base-pv.xml' => 'base.xml',
    'base-simcontrol-calendar-year-custom.xml' => 'base.xml',
    'base-simcontrol-daylight-saving-custom.xml' => 'base.xml',
    'base-simcontrol-daylight-saving-disabled.xml' => 'base.xml',
    'base-simcontrol-runperiod-1-month.xml' => 'base.xml',
    'base-simcontrol-timestep-10-mins.xml' => 'base.xml',
    'base-schedules-stochastic.xml' => 'base.xml',
    'base-schedules-stochastic-vacant.xml' => 'base-schedules-stochastic.xml',
    'base-schedules-user-specified.xml' => 'base.xml',
  }

  puts "Generating #{hpxmls_files.size} HPXML files..."

  hpxmls_files.each do |derivative, parent|
    print '.'

    begin
      hpxml_files = [derivative]
      unless parent.nil?
        hpxml_files.unshift(parent)
      end
      while not parent.nil?
        next unless hpxmls_files.keys.include? parent

        unless hpxmls_files[parent].nil?
          hpxml_files.unshift(hpxmls_files[parent])
        end
        parent = hpxmls_files[parent]
      end

      hpxml = HPXML.new
      hpxml_files.each do |hpxml_file|
        set_hpxml_header(hpxml_file, hpxml)
        set_hpxml_site(hpxml_file, hpxml)
        set_hpxml_neighbor_buildings(hpxml_file, hpxml)
        set_hpxml_building_construction(hpxml_file, hpxml)
        set_hpxml_building_occupancy(hpxml_file, hpxml)
        set_hpxml_climate_and_risk_zones(hpxml_file, hpxml)
        set_hpxml_air_infiltration_measurements(hpxml_file, hpxml)
        set_hpxml_attics(hpxml_file, hpxml)
        set_hpxml_foundations(hpxml_file, hpxml)
        set_hpxml_roofs(hpxml_file, hpxml)
        set_hpxml_rim_joists(hpxml_file, hpxml)
        set_hpxml_walls(hpxml_file, hpxml)
        set_hpxml_foundation_walls(hpxml_file, hpxml)
        set_hpxml_frame_floors(hpxml_file, hpxml)
        set_hpxml_slabs(hpxml_file, hpxml)
        set_hpxml_windows(hpxml_file, hpxml)
        set_hpxml_skylights(hpxml_file, hpxml)
        set_hpxml_doors(hpxml_file, hpxml)
        set_hpxml_heating_systems(hpxml_file, hpxml)
        set_hpxml_cooling_systems(hpxml_file, hpxml)
        set_hpxml_heat_pumps(hpxml_file, hpxml)
        set_hpxml_hvac_control(hpxml_file, hpxml)
        set_hpxml_hvac_distributions(hpxml_file, hpxml)
        set_hpxml_ventilation_fans(hpxml_file, hpxml)
        set_hpxml_water_heating_systems(hpxml_file, hpxml)
        set_hpxml_hot_water_distribution(hpxml_file, hpxml)
        set_hpxml_water_fixtures(hpxml_file, hpxml)
        set_hpxml_solar_thermal_system(hpxml_file, hpxml)
        set_hpxml_pv_systems(hpxml_file, hpxml)
        set_hpxml_generators(hpxml_file, hpxml)
        set_hpxml_clothes_washer(hpxml_file, hpxml)
        set_hpxml_clothes_dryer(hpxml_file, hpxml)
        set_hpxml_dishwasher(hpxml_file, hpxml)
        set_hpxml_refrigerator(hpxml_file, hpxml)
        set_hpxml_freezer(hpxml_file, hpxml)
        set_hpxml_dehumidifier(hpxml_file, hpxml)
        set_hpxml_cooking_range(hpxml_file, hpxml)
        set_hpxml_oven(hpxml_file, hpxml)
        set_hpxml_lighting(hpxml_file, hpxml)
        set_hpxml_ceiling_fans(hpxml_file, hpxml)
        set_hpxml_lighting_schedule(hpxml_file, hpxml)
        set_hpxml_pools(hpxml_file, hpxml)
        set_hpxml_hot_tubs(hpxml_file, hpxml)
        set_hpxml_plug_loads(hpxml_file, hpxml)
        set_hpxml_fuel_loads(hpxml_file, hpxml)
      end

      hpxml_doc = hpxml.to_oga()
      hpxml_docs[File.basename(derivative)] = hpxml_doc

      if ['invalid_files/missing-elements.xml'].include? derivative
        XMLHelper.delete_element(hpxml_doc, '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloors')
        XMLHelper.delete_element(hpxml_doc, '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedFloorArea')
      elsif ['invalid_files/invalid-datatype-boolean.xml'].include? derivative
        XMLHelper.get_element(hpxml_doc, '/HPXML/Building/BuildingDetails/Enclosure/Roofs/Roof/RadiantBarrier').inner_text = 'FOOBAR'
      elsif ['invalid_files/invalid-datatype-float.xml'].include? derivative
        XMLHelper.get_element(hpxml_doc, '/HPXML/Building/BuildingDetails/Enclosure/Slabs/Slab/extension/CarpetFraction').inner_text = 'FOOBAR'
      elsif ['invalid_files/invalid-datatype-integer.xml'].include? derivative
        XMLHelper.get_element(hpxml_doc, '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofBedrooms').inner_text = '2.5'
      elsif ['invalid_files/invalid-schema-version.xml'].include? derivative
        root = XMLHelper.get_element(hpxml_doc, '/HPXML')
        XMLHelper.add_attribute(root, 'schemaVersion', '2.3')
      elsif ['invalid_files/invalid-id2.xml'].include? derivative
        element = XMLHelper.get_element(hpxml_doc, '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight/SystemIdentifier')
        XMLHelper.delete_attribute(element, 'id')
      end

      if derivative.include? 'ASHRAE_Standard_140'
        hpxml_path = File.join(sample_files_dir, '../tests', derivative)
      else
        hpxml_path = File.join(sample_files_dir, derivative)
      end

      XMLHelper.write_file(hpxml_doc, hpxml_path)

      if ['base-multiple-buildings.xml',
          'invalid_files/multiple-buildings-without-building-id.xml',
          'invalid_files/multiple-buildings-wrong-building-id.xml'].include? derivative
        # HPXML class doesn't support multiple buildings, so we'll stitch together manually.
        hpxml_element = XMLHelper.get_element(hpxml_doc, '/HPXML')
        building_element = XMLHelper.get_element(hpxml_element, 'Building')
        for i in 2..3
          new_building_element = Marshal.load(Marshal.dump(building_element))

          # Make all IDs unique so the HPXML is valid
          new_building_element.each_node do |node|
            next unless node.is_a?(Oga::XML::Element)

            id = XMLHelper.get_attribute_value(node, 'id')
            next if id.nil?

            XMLHelper.add_attribute(node, 'id', "#{id}_#{i}")
          end

          hpxml_element.children << new_building_element
        end
        XMLHelper.write_file(hpxml_doc, hpxml_path)
      end

      if not hpxml_path.include? 'invalid_files'
        # Validate file against HPXML schema
        schemas_dir = File.absolute_path(File.join(File.dirname(__FILE__), 'HPXMLtoOpenStudio/resources'))
        errors = XMLHelper.validate(hpxml_doc.to_s, File.join(schemas_dir, 'HPXML.xsd'), nil)
        if errors.size > 0
          fail "ERRORS: #{errors}"
        end

        # Check for errors
        errors = hpxml.check_for_errors()
        if errors.size > 0
          fail "ERRORS: #{errors}"
        end
      end
    rescue Exception => e
      puts "\n#{e}\n#{e.backtrace.join('\n')}"
      puts "\nError: Did not successfully generate #{derivative}."
      exit!
    end
  end

  puts "\n"

  # Print warnings about extra files
  abs_hpxml_files = []
  dirs = [nil]
  hpxmls_files.keys.each do |hpxml_file|
    abs_hpxml_files << File.absolute_path(File.join(sample_files_dir, hpxml_file))
    next unless hpxml_file.include? '/'

    dirs << hpxml_file.split('/')[0] + '/'
  end
  dirs.uniq.each do |dir|
    Dir["#{sample_files_dir}/#{dir}*.xml"].each do |xml|
      next if abs_hpxml_files.include? File.absolute_path(xml)

      puts "Warning: Extra HPXML file found at #{File.absolute_path(xml)}"
    end
  end

  return hpxml_docs
end

def set_hpxml_header(hpxml_file, hpxml)
  if ['base.xml',
      'ASHRAE_Standard_140/L100AC.xml',
      'ASHRAE_Standard_140/L100AL.xml'].include? hpxml_file
    hpxml.header.xml_type = 'HPXML'
    hpxml.header.xml_generated_by = 'tasks.rb'
    hpxml.header.transaction = 'create'
    hpxml.header.building_id = 'MyBuilding'
    hpxml.header.event_type = 'proposed workscope'
    hpxml.header.created_date_and_time = Time.new(2000, 1, 1).strftime('%Y-%m-%dT%H:%M:%S%:z') # Hard-code to prevent diffs
    if hpxml_file == 'base.xml'
      hpxml.header.timestep = 60
    else
      hpxml.header.apply_ashrae140_assumptions = true
    end
  elsif ['base-simcontrol-calendar-year-custom.xml'].include? hpxml_file
    hpxml.header.sim_calendar_year = 2008
  elsif ['base-simcontrol-daylight-saving-custom.xml'].include? hpxml_file
    hpxml.header.dst_enabled = true
    hpxml.header.dst_begin_month = 3
    hpxml.header.dst_begin_day = 10
    hpxml.header.dst_end_month = 11
    hpxml.header.dst_end_day = 6
  elsif ['base-simcontrol-daylight-saving-disabled.xml'].include? hpxml_file
    hpxml.header.dst_enabled = false
  elsif ['base-simcontrol-timestep-10-mins.xml'].include? hpxml_file
    hpxml.header.timestep = 10
  elsif ['base-simcontrol-runperiod-1-month.xml'].include? hpxml_file
    hpxml.header.sim_begin_month = 1
    hpxml.header.sim_begin_day = 1
    hpxml.header.sim_end_month = 1
    hpxml.header.sim_end_day = 31
  elsif ['base-hvac-undersized-allow-increased-fixed-capacities.xml'].include? hpxml_file
    hpxml.header.allow_increased_fixed_capacities = true
  elsif hpxml_file.include? 'manual-s-oversize-allowances.xml'
    hpxml.header.use_max_load_for_heat_pumps = false
  elsif ['invalid_files/invalid-timestep.xml'].include? hpxml_file
    hpxml.header.timestep = 45
  elsif ['invalid_files/invalid-runperiod.xml'].include? hpxml_file
    hpxml.header.sim_end_month = 4
    hpxml.header.sim_end_day = 31
  elsif ['invalid_files/invalid-daylight-saving.xml'].include? hpxml_file
    hpxml.header.dst_end_month = 4
    hpxml.header.dst_end_day = 31
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.header.timestep = nil
  elsif ['base-schedules-stochastic.xml'].include? hpxml_file
    hpxml.header.schedules_path = 'BuildResidentialHPXML/tests/schedules/stochastic.csv'
  elsif ['base-schedules-stochastic-vacant.xml'].include? hpxml_file
    hpxml.header.schedules_path = 'BuildResidentialHPXML/tests/schedules/vacant.csv'
  elsif ['base-schedules-user-specified.xml'].include? hpxml_file
    hpxml.header.schedules_path = 'BuildResidentialHPXML/tests/schedules/user-specified.csv'
  elsif ['invalid_files/invalid-input-parameters.xml'].include? hpxml_file
    hpxml.header.transaction = 'modify'
  end
end

def set_hpxml_site(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.site.fuels = [HPXML::FuelTypeElectricity, HPXML::FuelTypeNaturalGas]
    hpxml.site.site_type = HPXML::SiteTypeSuburban
  elsif ['base-misc-shielding-of-home.xml'].include? hpxml_file
    hpxml.site.shielding_of_home = HPXML::ShieldingWellShielded
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.site.site_type = nil
  elsif ['invalid_files/invalid-input-parameters.xml'].include? hpxml_file
    hpxml.site.site_type = 'mountain'
  end
end

def set_hpxml_neighbor_buildings(hpxml_file, hpxml)
  if ['base-misc-neighbor-shading.xml'].include? hpxml_file
    hpxml.neighbor_buildings.add(azimuth: 0,
                                 distance: 10)
    hpxml.neighbor_buildings.add(azimuth: 180,
                                 distance: 15,
                                 height: 12)
  elsif ['invalid_files/invalid-neighbor-shading-azimuth.xml'].include? hpxml_file
    hpxml.neighbor_buildings[0].azimuth = 145
  end
end

def set_hpxml_building_construction(hpxml_file, hpxml)
  if ['ASHRAE_Standard_140/L100AC.xml',
      'ASHRAE_Standard_140/L100AL.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors = 1
    hpxml.building_construction.number_of_conditioned_floors_above_grade = 1
    hpxml.building_construction.number_of_bedrooms = 3
    hpxml.building_construction.conditioned_floor_area = 1539
    hpxml.building_construction.conditioned_building_volume = 12312
    hpxml.building_construction.residential_facility_type = HPXML::ResidentialTypeSFD
  elsif ['ASHRAE_Standard_140/L322XC.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors = 2
    hpxml.building_construction.conditioned_floor_area = 3078
    hpxml.building_construction.conditioned_building_volume = 24624
  elsif ['base.xml'].include? hpxml_file
    hpxml.building_construction.residential_facility_type = HPXML::ResidentialTypeSFD
    hpxml.building_construction.number_of_conditioned_floors = 2
    hpxml.building_construction.number_of_conditioned_floors_above_grade = 1
    hpxml.building_construction.number_of_bedrooms = 3
    hpxml.building_construction.number_of_bathrooms = 2
    hpxml.building_construction.conditioned_floor_area = 2700
    hpxml.building_construction.conditioned_building_volume = 2700 * 8
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.building_construction.residential_facility_type = HPXML::ResidentialTypeApartment
    hpxml.building_construction.number_of_conditioned_floors = 1
    hpxml.building_construction.conditioned_floor_area = 900
    hpxml.building_construction.conditioned_building_volume = 900 * 8
  elsif ['base-bldgtype-single-family-attached.xml'].include? hpxml_file
    hpxml.building_construction.residential_facility_type = HPXML::ResidentialTypeSFA
    hpxml.building_construction.conditioned_floor_area = 1800
    hpxml.building_construction.conditioned_building_volume = 1800 * 8
  elsif ['base-enclosure-beds-1.xml'].include? hpxml_file
    hpxml.building_construction.number_of_bedrooms = 1
    hpxml.building_construction.number_of_bathrooms = 1
  elsif ['base-enclosure-beds-2.xml'].include? hpxml_file
    hpxml.building_construction.number_of_bedrooms = 2
    hpxml.building_construction.number_of_bathrooms = 1
  elsif ['base-enclosure-beds-4.xml'].include? hpxml_file
    hpxml.building_construction.number_of_bedrooms = 4
    hpxml.building_construction.number_of_bathrooms = 2
  elsif ['base-enclosure-beds-5.xml'].include? hpxml_file
    hpxml.building_construction.number_of_bedrooms = 5
    hpxml.building_construction.number_of_bathrooms = 3
  elsif ['base-foundation-ambient.xml',
         'base-foundation-slab.xml',
         'base-foundation-unconditioned-basement.xml',
         'base-foundation-unvented-crawlspace.xml',
         'base-foundation-vented-crawlspace.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors -= 1
    hpxml.building_construction.conditioned_floor_area -= 1350
    hpxml.building_construction.conditioned_building_volume -= 1350 * 8
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors += 1
    hpxml.building_construction.number_of_conditioned_floors_above_grade += 1
    hpxml.building_construction.conditioned_floor_area += 900
    hpxml.building_construction.conditioned_building_volume += 2250
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.building_construction.conditioned_building_volume += 10800
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors += 1
    hpxml.building_construction.number_of_conditioned_floors_above_grade += 1
    hpxml.building_construction.conditioned_floor_area += 1350
    hpxml.building_construction.conditioned_building_volume += 1350 * 8
  elsif ['base-enclosure-2stories-garage.xml',
         'base-foundation-basement-garage.xml'].include? hpxml_file
    hpxml.building_construction.conditioned_floor_area -= 400 * 2
    hpxml.building_construction.conditioned_building_volume -= 400 * 2 * 8
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.building_construction.conditioned_building_volume = nil
    hpxml.building_construction.average_ceiling_height = nil
    hpxml.building_construction.number_of_bathrooms = nil
  elsif ['base-foundation-walkout-basement.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors_above_grade += 1
  elsif ['base-enclosure-split-level.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors = 1.5
    hpxml.building_construction.number_of_conditioned_floors_above_grade = 1.5
  elsif ['invalid_files/enclosure-floor-area-exceeds-cfa.xml'].include? hpxml_file
    hpxml.building_construction.conditioned_floor_area = 1348.8
  elsif ['invalid_files/enclosure-floor-area-exceeds-cfa2.xml'].include? hpxml_file
    hpxml.building_construction.conditioned_floor_area = 898.8
  elsif ['invalid_files/invalid-facility-type-equipment.xml',
         'invalid_files/invalid-facility-type-surfaces.xml'].include? hpxml_file
    hpxml.building_construction.residential_facility_type = HPXML::ResidentialTypeSFD
  elsif ['invalid_files/invalid-number-of-conditioned-floors.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors_above_grade = hpxml.building_construction.number_of_conditioned_floors + 1
  end
end

def set_hpxml_building_occupancy(hpxml_file, hpxml)
  if hpxml_file.include?('ASHRAE_Standard_140')
    hpxml.building_occupancy.number_of_residents = 0
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.building_occupancy.number_of_residents = nil
  else
    hpxml.building_occupancy.number_of_residents = hpxml.building_construction.number_of_bedrooms
  end
end

def set_hpxml_climate_and_risk_zones(hpxml_file, hpxml)
  hpxml.climate_and_risk_zones.weather_station_id = 'WeatherStation'
  hpxml.climate_and_risk_zones.iecc_year = 2006
  if hpxml_file == 'ASHRAE_Standard_140/L100AC.xml'
    hpxml.climate_and_risk_zones.weather_station_name = 'Colorado Springs, CO'
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'USA_CO_Colorado.Springs-Peterson.Field.724660_TMY3.epw'
  elsif hpxml_file == 'ASHRAE_Standard_140/L100AL.xml'
    hpxml.climate_and_risk_zones.weather_station_name = 'Las Vegas, NV'
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'USA_NV_Las.Vegas-McCarran.Intl.AP.723860_TMY3.epw'
  elsif ['base.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.iecc_zone = Location.get_climate_zone_iecc(725650)
    hpxml.climate_and_risk_zones.weather_station_name = 'Denver, CO'
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'USA_CO_Denver.Intl.AP.725650_TMY3.epw'
    hpxml.header.state_code = 'CO'
  elsif ['base-location-baltimore-md.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.iecc_zone = Location.get_climate_zone_iecc(724060)
    hpxml.climate_and_risk_zones.weather_station_name = 'Baltimore, MD'
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw'
    hpxml.header.state_code = 'MD'
  elsif ['base-location-dallas-tx.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.iecc_zone = Location.get_climate_zone_iecc(722590)
    hpxml.climate_and_risk_zones.weather_station_name = 'Dallas, TX'
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'USA_TX_Dallas-Fort.Worth.Intl.AP.722590_TMY3.epw'
    hpxml.header.state_code = 'TX'
  elsif ['base-location-duluth-mn.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.iecc_zone = Location.get_climate_zone_iecc(727450)
    hpxml.climate_and_risk_zones.weather_station_name = 'Duluth, MN'
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'USA_MN_Duluth.Intl.AP.727450_TMY3.epw'
    hpxml.header.state_code = 'MN'
  elsif ['base-location-helena-mt.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.iecc_zone = Location.get_climate_zone_iecc(727720)
    hpxml.climate_and_risk_zones.weather_station_name = 'Helena, MT'
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'USA_MT_Helena.Rgnl.AP.727720_TMY3.epw'
    hpxml.header.state_code = 'MT'
  elsif ['base-location-honolulu-hi.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.iecc_zone = Location.get_climate_zone_iecc(911820)
    hpxml.climate_and_risk_zones.weather_station_name = 'Honolulu, HI'
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'USA_HI_Honolulu.Intl.AP.911820_TMY3.epw'
    hpxml.header.state_code = 'HI'
  elsif ['base-location-miami-fl.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.iecc_zone = Location.get_climate_zone_iecc(722020)
    hpxml.climate_and_risk_zones.weather_station_name = 'Miami, FL'
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'
    hpxml.header.state_code = 'FL'
  elsif ['base-location-phoenix-az.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.iecc_zone = Location.get_climate_zone_iecc(722780)
    hpxml.climate_and_risk_zones.weather_station_name = 'Phoenix, AZ'
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw'
    hpxml.header.state_code = 'AZ'
  elsif ['base-location-portland-or.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.iecc_zone = Location.get_climate_zone_iecc(726980)
    hpxml.climate_and_risk_zones.weather_station_name = 'Portland, OR'
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'USA_OR_Portland.Intl.AP.726980_TMY3.epw'
    hpxml.header.state_code = 'OR'
  elsif ['base-location-AMY-2012.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.weather_station_name = 'Boulder, CO'
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'US_CO_Boulder_AMY_2012.epw'
  elsif ['invalid_files/invalid-epw-filepath.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = 'foo.epw'
  elsif ['invalid_files/invalid-input-parameters.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.iecc_year = 2020
  end
end

def set_hpxml_air_infiltration_measurements(hpxml_file, hpxml)
  infil_volume = hpxml.building_construction.conditioned_building_volume
  if ['ASHRAE_Standard_140/L100AC.xml',
      'ASHRAE_Standard_140/L100AL.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements.clear
    hpxml.air_infiltration_measurements.add(id: 'InfiltrationMeasurement',
                                            unit_of_measure: HPXML::UnitsACHNatural,
                                            air_leakage: 0.67)
  elsif ['base-enclosure-infil-natural-ach.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements.clear
    hpxml.air_infiltration_measurements.add(id: 'InfiltrationMeasurement',
                                            unit_of_measure: HPXML::UnitsACHNatural,
                                            air_leakage: 0.2)
  elsif ['ASHRAE_Standard_140/L322XC.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements[0].air_leakage = 0.335
  elsif ['ASHRAE_Standard_140/L110AC.xml',
         'ASHRAE_Standard_140/L110AL.xml',
         'ASHRAE_Standard_140/L200AC.xml',
         'ASHRAE_Standard_140/L200AL.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements[0].air_leakage = 1.5
  elsif ['base.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements.add(id: 'InfiltrationMeasurement',
                                            house_pressure: 50,
                                            unit_of_measure: HPXML::UnitsACH,
                                            air_leakage: 3.0)
  elsif ['base-enclosure-infil-cfm50.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements.clear
    hpxml.air_infiltration_measurements.add(id: 'InfiltrationMeasurement',
                                            house_pressure: 50,
                                            unit_of_measure: HPXML::UnitsCFM,
                                            air_leakage: 3.0 / 60.0 * infil_volume)
  elsif ['base-enclosure-infil-ach-house-pressure.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements[0].house_pressure = 45
    hpxml.air_infiltration_measurements[0].air_leakage *= 0.9338
  elsif ['base-enclosure-infil-cfm-house-pressure.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements[0].house_pressure = 45
    hpxml.air_infiltration_measurements[0].air_leakage *= 0.9338
  elsif ['base-enclosure-infil-flue.xml'].include? hpxml_file
    hpxml.building_construction.has_flue_or_chimney = true
  end
  if ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements[0].infiltration_volume = nil
  elsif ['invalid_files/invalid-infiltration-volume.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements[0].infiltration_volume = infil_volume * 0.25
  else
    hpxml.air_infiltration_measurements[0].infiltration_volume = infil_volume
  end
end

def set_hpxml_attics(hpxml_file, hpxml)
  if ['ASHRAE_Standard_140/L100AC.xml',
      'ASHRAE_Standard_140/L100AL.xml'].include? hpxml_file
    hpxml.attics.add(id: 'VentedAttic',
                     attic_type: HPXML::AtticTypeVented,
                     vented_attic_ach: 2.4)
  elsif ['base.xml'].include? hpxml_file
    hpxml.attics.add(id: 'UnventedAttic',
                     attic_type: HPXML::AtticTypeUnvented,
                     within_infiltration_volume: false)
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.attics.clear
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.attics.clear
    hpxml.attics.add(id: 'CathedralCeiling',
                     attic_type: HPXML::AtticTypeCathedral)
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.attics.add(id: 'ConditionedAttic',
                     attic_type: HPXML::AtticTypeConditioned)
  elsif ['base-atticroof-flat.xml'].include? hpxml_file
    hpxml.attics.clear
    hpxml.attics.add(id: 'FlatRoof',
                     attic_type: HPXML::AtticTypeFlatRoof)
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    hpxml.attics.clear
    hpxml.attics.add(id: 'VentedAttic',
                     attic_type: HPXML::AtticTypeVented,
                     vented_attic_sla: 0.003)
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.attics.clear
  end
end

def set_hpxml_foundations(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.foundations.add(id: 'ConditionedBasement',
                          foundation_type: HPXML::FoundationTypeBasementConditioned)
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.foundations.clear
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    hpxml.foundations.clear
    hpxml.foundations.add(id: 'VentedCrawlspace',
                          foundation_type: HPXML::FoundationTypeCrawlspaceVented,
                          vented_crawlspace_sla: 0.00667)
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    hpxml.foundations.clear
    hpxml.foundations.add(id: 'UnventedCrawlspace',
                          foundation_type: HPXML::FoundationTypeCrawlspaceUnvented,
                          within_infiltration_volume: false)
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.foundations.clear
    hpxml.foundations.add(id: 'UnconditionedBasement',
                          foundation_type: HPXML::FoundationTypeBasementUnconditioned,
                          within_infiltration_volume: false)
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    hpxml.foundations.add(id: 'UnventedCrawlspace',
                          foundation_type: HPXML::FoundationTypeCrawlspaceUnvented,
                          within_infiltration_volume: false)
  elsif ['base-foundation-ambient.xml'].include? hpxml_file
    hpxml.foundations.clear
    hpxml.foundations.add(id: 'AmbientFoundation',
                          foundation_type: HPXML::FoundationTypeAmbient)
  elsif ['base-foundation-slab.xml'].include? hpxml_file
    hpxml.foundations.clear
    hpxml.foundations.add(id: 'SlabFoundation',
                          foundation_type: HPXML::FoundationTypeSlab)
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.foundations.clear
  end
end

def set_hpxml_roofs(hpxml_file, hpxml)
  if ['ASHRAE_Standard_140/L100AC.xml',
      'ASHRAE_Standard_140/L100AL.xml'].include? hpxml_file
    hpxml.roofs.add(id: 'AtticRoofNorth',
                    interior_adjacent_to: HPXML::LocationAtticVented,
                    area: 811.1,
                    azimuth: 0,
                    roof_type: HPXML::RoofTypeAsphaltShingles,
                    solar_absorptance: 0.6,
                    emittance: 0.9,
                    pitch: 4,
                    radiant_barrier: false,
                    insulation_assembly_r_value: 1.99)
    hpxml.roofs.add(id: 'AtticRoofSouth',
                    interior_adjacent_to: HPXML::LocationAtticVented,
                    area: 811.1,
                    azimuth: 180,
                    roof_type: HPXML::RoofTypeAsphaltShingles,
                    solar_absorptance: 0.6,
                    emittance: 0.9,
                    pitch: 4,
                    radiant_barrier: false,
                    insulation_assembly_r_value: 1.99)
  elsif ['ASHRAE_Standard_140/L202AC.xml',
         'ASHRAE_Standard_140/L202AL.xml'].include? hpxml_file
    for i in 0..hpxml.roofs.size - 1
      hpxml.roofs[i].solar_absorptance = 0.2
    end
  elsif ['base.xml'].include? hpxml_file
    hpxml.roofs.add(id: 'Roof',
                    interior_adjacent_to: HPXML::LocationAtticUnvented,
                    area: 1509.3,
                    roof_type: HPXML::RoofTypeAsphaltShingles,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    pitch: 6,
                    radiant_barrier: false,
                    insulation_assembly_r_value: 2.3)
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.roofs.clear
  elsif ['base-bldgtype-single-family-attached.xml'].include? hpxml_file
    hpxml.roofs[0].area = 1006
  elsif ['base-enclosure-rooftypes.xml'].include? hpxml_file
    roof_types = [[HPXML::RoofTypeClayTile, HPXML::ColorLight],
                  [HPXML::RoofTypeMetal, HPXML::ColorReflective],
                  [HPXML::RoofTypeWoodShingles, HPXML::ColorDark],
                  [HPXML::RoofTypeShingles, HPXML::ColorMediumDark],
                  [HPXML::RoofTypePlasticRubber, HPXML::ColorLight],
                  [HPXML::RoofTypeEPS, HPXML::ColorMedium],
                  [HPXML::RoofTypeConcrete, HPXML::ColorLight],
                  [HPXML::RoofTypeCool, HPXML::ColorReflective]]
    int_finish_types = [[HPXML::InteriorFinishGypsumBoard, 0.5],
                        [HPXML::InteriorFinishPlaster, 0.5],
                        [HPXML::InteriorFinishWood, 0.5]]
    hpxml.roofs.clear
    roof_types.each_with_index do |roof_type, i|
      hpxml.roofs.add(id: "Roof#{i + 1}",
                      interior_adjacent_to: HPXML::LocationAtticUnvented,
                      area: 1509.3 / roof_types.size,
                      roof_type: roof_type[0],
                      roof_color: roof_type[1],
                      emittance: 0.92,
                      pitch: 6,
                      radiant_barrier: false,
                      interior_finish_type: int_finish_types[i % int_finish_types.size][0],
                      interior_finish_thickness: int_finish_types[i % int_finish_types.size][1],
                      insulation_assembly_r_value: roof_type[0] == HPXML::RoofTypeEPS ? 7.0 : 2.3)
    end
  elsif ['base-atticroof-flat.xml'].include? hpxml_file
    hpxml.roofs.clear
    hpxml.roofs.add(id: 'Roof',
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    area: 1350,
                    roof_type: HPXML::RoofTypeAsphaltShingles,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    pitch: 0,
                    radiant_barrier: false,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 25.8)
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.roofs.clear
    hpxml.roofs.add(id: 'RoofCond',
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    area: 1006,
                    roof_type: HPXML::RoofTypeAsphaltShingles,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    pitch: 6,
                    radiant_barrier: false,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 25.8)
    hpxml.roofs.add(id: 'RoofUncond',
                    interior_adjacent_to: HPXML::LocationAtticUnvented,
                    area: 504,
                    roof_type: HPXML::RoofTypeAsphaltShingles,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    pitch: 6,
                    radiant_barrier: false,
                    insulation_assembly_r_value: 2.3)
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    hpxml.roofs[0].interior_adjacent_to = HPXML::LocationAtticVented
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.roofs[0].interior_adjacent_to = HPXML::LocationLivingSpace
    hpxml.roofs[0].insulation_assembly_r_value = 25.8
    hpxml.roofs[0].interior_finish_type = HPXML::InteriorFinishGypsumBoard
  elsif ['base-enclosure-garage.xml',
         'base-foundation-basement-garage.xml'].include? hpxml_file
    hpxml.roofs[0].area += 671
  elsif ['base-atticroof-unvented-insulated-roof.xml'].include? hpxml_file
    hpxml.roofs[0].insulation_assembly_r_value = 25.8
  elsif ['base-enclosure-split-surfaces.xml',
         'base-enclosure-split-surfaces2.xml'].include? hpxml_file
    for n in 1..hpxml.roofs.size
      hpxml.roofs[n - 1].area /= 9.0
      for i in 2..9
        hpxml.roofs << hpxml.roofs[n - 1].dup
        hpxml.roofs[-1].id += i.to_s
        if hpxml_file == 'base-enclosure-split-surfaces2.xml'
          hpxml.roofs[-1].insulation_assembly_r_value += 0.01 * i
        end
      end
    end
    hpxml.roofs << hpxml.roofs[-1].dup
    hpxml.roofs[-1].id = 'TinyRoof'
    hpxml.roofs[-1].area = 0.05
  elsif ['base-atticroof-radiant-barrier.xml'].include? hpxml_file
    hpxml.roofs[0].radiant_barrier = true
    hpxml.roofs[0].radiant_barrier_grade = 2
  elsif ['invalid_files/enclosure-attic-missing-roof.xml'].include? hpxml_file
    hpxml.roofs[0].delete
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.roofs.each do |roof|
      roof.roof_type = nil
      roof.solar_absorptance = nil
      roof.roof_color = nil
      roof.emittance = nil
      roof.radiant_barrier = nil
      roof.interior_finish_type = nil
      roof.interior_finish_thickness = nil
    end
  elsif ['invalid_files/invalid-input-parameters.xml'].include? hpxml_file
    hpxml.roofs[0].radiant_barrier_grade = 4
    hpxml.roofs[0].azimuth = 365
  end
end

def set_hpxml_rim_joists(hpxml_file, hpxml)
  if ['ASHRAE_Standard_140/L322XC.xml'].include? hpxml_file
    hpxml.rim_joists.add(id: 'RimJoistNorth',
                         exterior_adjacent_to: HPXML::LocationOutside,
                         interior_adjacent_to: HPXML::LocationBasementConditioned,
                         siding: HPXML::SidingTypeWood,
                         area: 42.75,
                         azimuth: 0,
                         solar_absorptance: 0.6,
                         emittance: 0.9,
                         insulation_assembly_r_value: 5.01)
    hpxml.rim_joists.add(id: 'RimJoistEast',
                         exterior_adjacent_to: HPXML::LocationOutside,
                         interior_adjacent_to: HPXML::LocationBasementConditioned,
                         siding: HPXML::SidingTypeWood,
                         area: 20.25,
                         azimuth: 90,
                         solar_absorptance: 0.6,
                         emittance: 0.9,
                         insulation_assembly_r_value: 5.01)
    hpxml.rim_joists.add(id: 'RimJoistSouth',
                         exterior_adjacent_to: HPXML::LocationOutside,
                         interior_adjacent_to: HPXML::LocationBasementConditioned,
                         siding: HPXML::SidingTypeWood,
                         area: 42.75,
                         azimuth: 180,
                         solar_absorptance: 0.6,
                         emittance: 0.9,
                         insulation_assembly_r_value: 5.01)
    hpxml.rim_joists.add(id: 'RimJoistWest',
                         exterior_adjacent_to: HPXML::LocationOutside,
                         interior_adjacent_to: HPXML::LocationBasementConditioned,
                         siding: HPXML::SidingTypeWood,
                         area: 20.25,
                         azimuth: 270,
                         solar_absorptance: 0.6,
                         emittance: 0.9,
                         insulation_assembly_r_value: 5.01)
  elsif ['ASHRAE_Standard_140/L324XC.xml'].include? hpxml_file
    for i in 0..hpxml.rim_joists.size - 1
      hpxml.rim_joists[i].insulation_assembly_r_value = 13.14
    end
  elsif ['base.xml'].include? hpxml_file
    # TODO: Other geometry values (e.g., building volume) assume
    # no rim joists.
    hpxml.rim_joists.add(id: 'RimJoistFoundation',
                         exterior_adjacent_to: HPXML::LocationOutside,
                         interior_adjacent_to: HPXML::LocationBasementConditioned,
                         siding: HPXML::SidingTypeWood,
                         area: 116,
                         solar_absorptance: 0.7,
                         emittance: 0.92,
                         insulation_assembly_r_value: 23.0)
  elsif ['base-bldgtype-single-family-attached.xml'].include? hpxml_file
    hpxml.rim_joists[-1].area = 66
    hpxml.rim_joists.add(id: 'RimJoistOther',
                         exterior_adjacent_to: HPXML::LocationBasementConditioned,
                         interior_adjacent_to: HPXML::LocationBasementConditioned,
                         area: 28,
                         solar_absorptance: 0.7,
                         emittance: 0.92,
                         insulation_assembly_r_value: 4.0)
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.rim_joists.clear
  elsif ['base-enclosure-walltypes.xml'].include? hpxml_file
    siding_types = [[HPXML::SidingTypeAluminum, HPXML::ColorDark],
                    [HPXML::SidingTypeAsbestos, HPXML::ColorMedium],
                    [HPXML::SidingTypeBrick, HPXML::ColorReflective],
                    [HPXML::SidingTypeCompositeShingle, HPXML::ColorDark],
                    [HPXML::SidingTypeFiberCement, HPXML::ColorMediumDark],
                    [HPXML::SidingTypeMasonite, HPXML::ColorLight],
                    [HPXML::SidingTypeStucco, HPXML::ColorMedium],
                    [HPXML::SidingTypeSyntheticStucco, HPXML::ColorMediumDark],
                    [HPXML::SidingTypeVinyl, HPXML::ColorLight],
                    [HPXML::SidingTypeNone, HPXML::ColorMedium]]
    hpxml.rim_joists.clear
    siding_types.each_with_index do |siding_type, i|
      hpxml.rim_joists.add(id: "RimJoistFoundation#{i + 1}",
                           exterior_adjacent_to: HPXML::LocationOutside,
                           interior_adjacent_to: HPXML::LocationBasementConditioned,
                           siding: siding_type[0],
                           color: siding_type[1],
                           area: 116 / siding_types.size,
                           emittance: 0.92,
                           insulation_assembly_r_value: 23.0)
    end
  elsif ['base-foundation-ambient.xml',
         'base-foundation-slab.xml'].include? hpxml_file
    hpxml.rim_joists.clear
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    for i in 0..hpxml.rim_joists.size - 1
      hpxml.rim_joists[i].interior_adjacent_to = HPXML::LocationBasementUnconditioned
      hpxml.rim_joists[i].insulation_assembly_r_value = 4.0
    end
  elsif ['base-foundation-unconditioned-basement-wall-insulation.xml'].include? hpxml_file
    for i in 0..hpxml.rim_joists.size - 1
      hpxml.rim_joists[i].insulation_assembly_r_value = 23.0
    end
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    for i in 0..hpxml.rim_joists.size - 1
      hpxml.rim_joists[i].interior_adjacent_to = HPXML::LocationCrawlspaceUnvented
    end
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    for i in 0..hpxml.rim_joists.size - 1
      hpxml.rim_joists[i].interior_adjacent_to = HPXML::LocationCrawlspaceVented
    end
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    hpxml.rim_joists[0].exterior_adjacent_to = HPXML::LocationCrawlspaceUnvented
    hpxml.rim_joists[0].siding = nil
    hpxml.rim_joists.add(id: 'RimJoistCrawlspace',
                         exterior_adjacent_to: HPXML::LocationOutside,
                         interior_adjacent_to: HPXML::LocationCrawlspaceUnvented,
                         siding: HPXML::SidingTypeWood,
                         area: 81,
                         solar_absorptance: 0.7,
                         emittance: 0.92,
                         insulation_assembly_r_value: 4.0)
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    hpxml.rim_joists[-1].area = 116
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    hpxml.rim_joists.add(id: 'RimJoist2ndStory',
                         exterior_adjacent_to: HPXML::LocationOutside,
                         interior_adjacent_to: HPXML::LocationLivingSpace,
                         siding: HPXML::SidingTypeWood,
                         area: 116,
                         solar_absorptance: 0.7,
                         emittance: 0.92,
                         insulation_assembly_r_value: 23.0)
  elsif ['base-enclosure-split-surfaces.xml',
         'base-enclosure-split-surfaces2.xml'].include? hpxml_file
    for n in 1..hpxml.rim_joists.size
      hpxml.rim_joists[n - 1].area /= 9.0
      for i in 2..9
        hpxml.rim_joists << hpxml.rim_joists[n - 1].dup
        hpxml.rim_joists[-1].id += i.to_s
        if hpxml_file == 'base-enclosure-split-surfaces2.xml'
          hpxml.rim_joists[-1].insulation_assembly_r_value += 0.01 * i
        end
      end
    end
    hpxml.rim_joists << hpxml.rim_joists[-1].dup
    hpxml.rim_joists[-1].id = 'TinyRimJoist'
    hpxml.rim_joists[-1].area = 0.05
  elsif ['invalid_files/invalid-facility-type-surfaces.xml'].include? hpxml_file
    hpxml.rim_joists.add(id: 'RimJoistOther',
                         exterior_adjacent_to: HPXML::LocationOtherHousingUnit,
                         interior_adjacent_to: HPXML::LocationLivingSpace,
                         area: 116,
                         solar_absorptance: 0.7,
                         emittance: 0.92,
                         insulation_assembly_r_value: 23.0)
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.rim_joists.each do |rim_joist|
      rim_joist.siding = nil
      rim_joist.solar_absorptance = nil
      rim_joist.color = nil
      rim_joist.emittance = nil
    end
  end
  hpxml.rim_joists.each do |rim_joist|
    next unless rim_joist.is_interior

    fail "Interior rim joist '#{rim_joist.id}' in #{hpxml_file} should not have siding." unless rim_joist.siding.nil?
  end
end

def set_hpxml_walls(hpxml_file, hpxml)
  if ['ASHRAE_Standard_140/L100AC.xml',
      'ASHRAE_Standard_140/L100AL.xml'].include? hpxml_file
    hpxml.walls.add(id: 'WallNorth',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 456,
                    azimuth: 0,
                    solar_absorptance: 0.6,
                    emittance: 0.9,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    interior_finish_thickness: 0.5,
                    insulation_assembly_r_value: 11.76)
    hpxml.walls.add(id: 'WallEast',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 216,
                    azimuth: 90,
                    solar_absorptance: 0.6,
                    emittance: 0.9,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    interior_finish_thickness: 0.5,
                    insulation_assembly_r_value: 11.76)
    hpxml.walls.add(id: 'WallSouth',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 456,
                    azimuth: 180,
                    solar_absorptance: 0.6,
                    emittance: 0.9,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    interior_finish_thickness: 0.5,
                    insulation_assembly_r_value: 11.76)
    hpxml.walls.add(id: 'WallWest',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 216,
                    azimuth: 270,
                    solar_absorptance: 0.6,
                    emittance: 0.9,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    interior_finish_thickness: 0.5,
                    insulation_assembly_r_value: 11.76)
    hpxml.walls.add(id: 'WallAtticGableEast',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationAtticVented,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 60.75,
                    azimuth: 90,
                    solar_absorptance: 0.6,
                    emittance: 0.9,
                    insulation_assembly_r_value: 2.15)
    hpxml.walls.add(id: 'WallAtticGableWest',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationAtticVented,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 60.75,
                    azimuth: 270,
                    solar_absorptance: 0.6,
                    emittance: 0.9,
                    insulation_assembly_r_value: 2.15)
  elsif ['ASHRAE_Standard_140/L120AC.xml',
         'ASHRAE_Standard_140/L120AL.xml'].include? hpxml_file
    for i in 0..hpxml.walls.size - 3
      hpxml.walls[i].insulation_assembly_r_value = 23.58
    end
  elsif ['ASHRAE_Standard_140/L200AC.xml',
         'ASHRAE_Standard_140/L200AL.xml'].include? hpxml_file
    for i in 0..hpxml.walls.size - 3
      hpxml.walls[i].insulation_assembly_r_value = 4.84
    end
  elsif ['ASHRAE_Standard_140/L202AC.xml',
         'ASHRAE_Standard_140/L202AL.xml'].include? hpxml_file
    for i in 0..hpxml.walls.size - 1
      hpxml.walls[i].solar_absorptance = 0.2
    end
  elsif ['base.xml'].include? hpxml_file
    hpxml.walls.add(id: 'Wall',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 1200,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23.0)
    hpxml.walls.add(id: 'WallAtticGable',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationAtticUnvented,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 290,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    insulation_assembly_r_value: 4.0)
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.walls.clear
    hpxml.walls.add(id: 'Wall',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 686,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23.0)
    hpxml.walls.add(id: 'WallOther',
                    exterior_adjacent_to: HPXML::LocationOtherHousingUnit,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 294,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 4.0)
  elsif ['base-bldgtype-single-family-attached.xml'].include? hpxml_file
    hpxml.walls.clear
    hpxml.walls.add(id: 'Wall',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 686,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23.0)
    hpxml.walls.add(id: 'WallOther',
                    exterior_adjacent_to: HPXML::LocationOtherHousingUnit,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 294,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 4.0)
    hpxml.walls.add(id: 'WallAtticGable',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationAtticUnvented,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 169,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    insulation_assembly_r_value: 4.0)
    hpxml.walls.add(id: 'WallAtticOther',
                    exterior_adjacent_to: HPXML::LocationAtticUnvented,
                    interior_adjacent_to: HPXML::LocationAtticUnvented,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 169,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    insulation_assembly_r_value: 4.0)
  elsif ['base-atticroof-flat.xml'].include? hpxml_file
    hpxml.walls.delete_at(1)
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    hpxml.walls[1].interior_adjacent_to = HPXML::LocationAtticVented
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.walls[1].interior_adjacent_to = HPXML::LocationLivingSpace
    hpxml.walls[1].insulation_assembly_r_value = 23.0
    hpxml.walls[1].interior_finish_type = HPXML::InteriorFinishGypsumBoard
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.walls.delete_at(1)
    hpxml.walls.add(id: 'WallAtticKneeWall',
                    exterior_adjacent_to: HPXML::LocationAtticUnvented,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 316,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23.0)
    hpxml.walls.add(id: 'WallAtticGableCond',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 240,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 22.3)
    hpxml.walls.add(id: 'WallAtticGableUncond',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationAtticUnvented,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 50,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    insulation_assembly_r_value: 4.0)
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    hpxml.walls[1].delete
    hpxml.walls.add(id: 'WallOtherHeatedSpace',
                    exterior_adjacent_to: HPXML::LocationOtherHeatedSpace,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 100,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23.0)
    hpxml.walls.add(id: 'WallOtherMultifamilyBufferSpace',
                    exterior_adjacent_to: HPXML::LocationOtherMultifamilyBufferSpace,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 100,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23.0)
    hpxml.walls.add(id: 'WallOtherNonFreezingSpace',
                    exterior_adjacent_to: HPXML::LocationOtherNonFreezingSpace,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 100,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23.0)
    hpxml.walls.add(id: 'WallOtherHousingUnit',
                    exterior_adjacent_to: HPXML::LocationOtherHousingUnit,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 100,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 4.0)
  elsif ['base-enclosure-walltypes.xml'].include? hpxml_file
    walls_map = { HPXML::WallTypeCMU => 12,
                  HPXML::WallTypeDoubleWoodStud => 28.7,
                  HPXML::WallTypeICF => 21,
                  HPXML::WallTypeLog => 7.1,
                  HPXML::WallTypeSIP => 16.1,
                  HPXML::WallTypeConcrete => 1.35,
                  HPXML::WallTypeSteelStud => 8.1,
                  HPXML::WallTypeStone => 5.4,
                  HPXML::WallTypeStrawBale => 58.8,
                  HPXML::WallTypeBrick => 7.9,
                  HPXML::WallTypeAdobe => 5.0 }
    siding_types = [[HPXML::SidingTypeAluminum, HPXML::ColorReflective],
                    [HPXML::SidingTypeAsbestos, HPXML::ColorLight],
                    [HPXML::SidingTypeBrick, HPXML::ColorMediumDark],
                    [HPXML::SidingTypeCompositeShingle, HPXML::ColorReflective],
                    [HPXML::SidingTypeFiberCement, HPXML::ColorMedium],
                    [HPXML::SidingTypeMasonite, HPXML::ColorDark],
                    [HPXML::SidingTypeStucco, HPXML::ColorLight],
                    [HPXML::SidingTypeSyntheticStucco, HPXML::ColorMedium],
                    [HPXML::SidingTypeVinyl, HPXML::ColorDark],
                    [HPXML::SidingTypeNone, HPXML::ColorMedium]]
    int_finish_types = [[HPXML::InteriorFinishGypsumBoard, 0.5],
                        [HPXML::InteriorFinishGypsumBoard, 1.0],
                        [HPXML::InteriorFinishGypsumCompositeBoard, 0.5],
                        [HPXML::InteriorFinishPlaster, 0.5],
                        [HPXML::InteriorFinishWood, 0.5],
                        [HPXML::InteriorFinishNone, nil]]
    last_wall = hpxml.walls[-1]
    hpxml.walls.clear
    walls_map.each_with_index do |(wall_type, assembly_r), i|
      hpxml.walls.add(id: "Wall#{i + 1}",
                      exterior_adjacent_to: HPXML::LocationOutside,
                      interior_adjacent_to: HPXML::LocationLivingSpace,
                      wall_type: wall_type,
                      siding: siding_types[i % siding_types.size][0],
                      color: siding_types[i % siding_types.size][1],
                      area: 1200 / walls_map.size,
                      emittance: 0.92,
                      interior_finish_type: int_finish_types[i % int_finish_types.size][0],
                      interior_finish_thickness: int_finish_types[i % int_finish_types.size][1],
                      insulation_assembly_r_value: assembly_r)
    end
    hpxml.walls << last_wall
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    hpxml.walls[0].area *= 2.0
  elsif ['base-enclosure-2stories-garage.xml'].include? hpxml_file
    hpxml.walls.clear
    hpxml.walls.add(id: 'Wall',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 2080,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23)
    hpxml.walls.add(id: 'WallGarageInterior',
                    exterior_adjacent_to: HPXML::LocationGarage,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 320,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23)
    hpxml.walls.add(id: 'WallGarageExterior',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationGarage,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 320,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    insulation_assembly_r_value: 4)
    hpxml.walls.add(id: 'WallAtticGable',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationAtticUnvented,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 113,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    insulation_assembly_r_value: 4)
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    hpxml.walls.clear
    hpxml.walls.add(id: 'Wall',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 960,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23)
    hpxml.walls.add(id: 'WallGarageInterior',
                    exterior_adjacent_to: HPXML::LocationGarage,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 240,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23)
    hpxml.walls.add(id: 'WallGarageExterior',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationGarage,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 560,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    insulation_assembly_r_value: 4)
    hpxml.walls.add(id: 'WallAtticGable',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationAtticUnvented,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 113,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    insulation_assembly_r_value: 4)
  elsif ['base-atticroof-unvented-insulated-roof.xml'].include? hpxml_file
    hpxml.walls[1].insulation_assembly_r_value = 23
  elsif ['base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml'].include? hpxml_file
    hpxml.walls[-1].exterior_adjacent_to = HPXML::LocationOtherHousingUnit
    hpxml.walls[-1].insulation_assembly_r_value = 4
  elsif ['base-bldgtype-multifamily-adjacent-to-other-heated-space.xml'].include? hpxml_file
    hpxml.walls[-1].exterior_adjacent_to = HPXML::LocationOtherHeatedSpace
    hpxml.walls[-1].insulation_assembly_r_value = 23
  elsif ['base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml'].include? hpxml_file
    hpxml.walls[-1].exterior_adjacent_to = HPXML::LocationOtherMultifamilyBufferSpace
    hpxml.walls[-1].insulation_assembly_r_value = 23
  elsif ['base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml'].include? hpxml_file
    hpxml.walls[-1].exterior_adjacent_to = HPXML::LocationOtherNonFreezingSpace
    hpxml.walls[-1].insulation_assembly_r_value = 23
  elsif ['base-enclosure-split-surfaces.xml',
         'base-enclosure-split-surfaces2.xml'].include? hpxml_file
    for n in 1..hpxml.walls.size
      hpxml.walls[n - 1].area /= 9.0
      for i in 2..9
        hpxml.walls << hpxml.walls[n - 1].dup
        hpxml.walls[-1].id += i.to_s
        if hpxml_file == 'base-enclosure-split-surfaces2.xml'
          hpxml.walls[-1].insulation_assembly_r_value += 0.01 * i
        end
      end
    end
    hpxml.walls << hpxml.walls[-1].dup
    hpxml.walls[-1].id = 'TinyWall'
    hpxml.walls[-1].area = 0.05
  elsif ['invalid_files/enclosure-living-missing-exterior-wall.xml'].include? hpxml_file
    hpxml.walls[0].delete
  elsif ['invalid_files/enclosure-garage-missing-exterior-wall.xml'].include? hpxml_file
    hpxml.walls[-2].delete
  elsif ['invalid_files/invalid-facility-type-surfaces.xml'].include? hpxml_file
    hpxml.walls.add(id: 'WallOther',
                    exterior_adjacent_to: HPXML::LocationOtherHousingUnit,
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 294,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 4.0)
  elsif ['invalid_files/invalid-assembly-effective-rvalue.xml'].include? hpxml_file
    hpxml.walls[0].insulation_assembly_r_value = 0
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.walls.each do |wall|
      wall.siding = nil
      wall.solar_absorptance = nil
      wall.color = nil
      wall.emittance = nil
      wall.interior_finish_type = nil
      wall.interior_finish_thickness = nil
    end
  elsif ['base-foundation-basement-garage.xml'].include? hpxml_file
    hpxml.walls.add(id: 'WallGarageBasement',
                    exterior_adjacent_to: HPXML::LocationGarage,
                    interior_adjacent_to: HPXML::LocationBasementConditioned,
                    wall_type: HPXML::WallTypeWoodStud,
                    area: 320,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                    insulation_assembly_r_value: 23)
    hpxml.walls.add(id: 'WallGarageExterior',
                    exterior_adjacent_to: HPXML::LocationOutside,
                    interior_adjacent_to: HPXML::LocationGarage,
                    wall_type: HPXML::WallTypeWoodStud,
                    siding: HPXML::SidingTypeWood,
                    area: 320,
                    solar_absorptance: 0.7,
                    emittance: 0.92,
                    insulation_assembly_r_value: 4)
  end
  hpxml.walls.each do |wall|
    next unless wall.is_interior

    fail "Interior wall '#{wall.id}' in #{hpxml_file} should not have siding." unless wall.siding.nil?
  end
end

def set_hpxml_foundation_walls(hpxml_file, hpxml)
  if ['ASHRAE_Standard_140/L322XC.xml'].include? hpxml_file
    hpxml.foundation_walls.add(id: 'FoundationWallNorth',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 7.25,
                               area: 413.25,
                               azimuth: 0,
                               thickness: 6,
                               depth_below_grade: 6.583,
                               interior_finish_type: HPXML::InteriorFinishNone,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_r_value: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 0)
    hpxml.foundation_walls.add(id: 'FoundationWallEast',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 7.25,
                               area: 195.75,
                               azimuth: 90,
                               thickness: 6,
                               depth_below_grade: 6.583,
                               interior_finish_type: HPXML::InteriorFinishNone,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_r_value: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 0)
    hpxml.foundation_walls.add(id: 'FoundationWallSouth',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 7.25,
                               area: 413.25,
                               azimuth: 180,
                               thickness: 6,
                               depth_below_grade: 6.583,
                               interior_finish_type: HPXML::InteriorFinishNone,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_r_value: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 0)
    hpxml.foundation_walls.add(id: 'FoundationWallWest',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 7.25,
                               area: 195.75,
                               azimuth: 270,
                               thickness: 6,
                               depth_below_grade: 6.583,
                               interior_finish_type: HPXML::InteriorFinishNone,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_r_value: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 0)
  elsif ['ASHRAE_Standard_140/L324XC.xml'].include? hpxml_file
    for i in 0..hpxml.foundation_walls.size - 1
      hpxml.foundation_walls[i].insulation_interior_r_value = 10.2
      hpxml.foundation_walls[i].insulation_interior_distance_to_top = 0.0
      hpxml.foundation_walls[i].insulation_interior_distance_to_bottom = 7.25
      hpxml.foundation_walls[i].interior_finish_type = HPXML::InteriorFinishGypsumBoard
      hpxml.foundation_walls[i].interior_finish_thickness = 0.5
    end
  elsif ['base.xml'].include? hpxml_file
    hpxml.foundation_walls.add(id: 'FoundationWall',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 8,
                               area: 1200,
                               thickness: 8,
                               depth_below_grade: 7,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 8,
                               insulation_exterior_r_value: 8.9)
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.foundation_walls.clear
  elsif ['base-bldgtype-single-family-attached.xml'].include? hpxml_file
    hpxml.foundation_walls.clear
    hpxml.foundation_walls.add(id: 'FoundationWall',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 8,
                               area: 686,
                               thickness: 8,
                               depth_below_grade: 7,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 8,
                               insulation_exterior_r_value: 8.9)
    hpxml.foundation_walls.add(id: 'FoundationWallOther',
                               exterior_adjacent_to: HPXML::LocationBasementConditioned,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 8,
                               area: 294,
                               thickness: 8,
                               depth_below_grade: 7,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 0,
                               insulation_exterior_r_value: 0)
  elsif ['base-foundation-conditioned-basement-wall-interior-insulation.xml'].include? hpxml_file
    hpxml.foundation_walls[0].insulation_interior_distance_to_top = 0
    hpxml.foundation_walls[0].insulation_interior_distance_to_bottom = 8
    hpxml.foundation_walls[0].insulation_interior_r_value = 10
    hpxml.foundation_walls[0].insulation_exterior_distance_to_top = 1
    hpxml.foundation_walls[0].insulation_exterior_distance_to_bottom = 8
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.foundation_walls[0].interior_adjacent_to = HPXML::LocationBasementUnconditioned
    hpxml.foundation_walls[0].insulation_exterior_distance_to_bottom = 0
    hpxml.foundation_walls[0].insulation_exterior_r_value = 0
    hpxml.foundation_walls[0].interior_finish_type = HPXML::InteriorFinishNone
  elsif ['base-foundation-unconditioned-basement-wall-insulation.xml'].include? hpxml_file
    hpxml.foundation_walls[0].insulation_exterior_distance_to_bottom = 4
    hpxml.foundation_walls[0].insulation_exterior_r_value = 8.9
  elsif ['base-foundation-unconditioned-basement-assembly-r.xml'].include? hpxml_file
    hpxml.foundation_walls[0].insulation_exterior_distance_to_top = nil
    hpxml.foundation_walls[0].insulation_exterior_distance_to_bottom = nil
    hpxml.foundation_walls[0].insulation_exterior_r_value = nil
    hpxml.foundation_walls[0].insulation_interior_distance_to_top = nil
    hpxml.foundation_walls[0].insulation_interior_distance_to_bottom = nil
    hpxml.foundation_walls[0].insulation_interior_r_value = nil
    hpxml.foundation_walls[0].insulation_assembly_r_value = 10.69
  elsif ['base-foundation-unconditioned-basement-above-grade.xml'].include? hpxml_file
    hpxml.foundation_walls[0].depth_below_grade = 4
  elsif ['base-foundation-unvented-crawlspace.xml',
         'base-foundation-vented-crawlspace.xml'].include? hpxml_file
    if ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
      hpxml.foundation_walls[0].interior_adjacent_to = HPXML::LocationCrawlspaceUnvented
    else
      hpxml.foundation_walls[0].interior_adjacent_to = HPXML::LocationCrawlspaceVented
    end
    hpxml.foundation_walls[0].height -= 4
    hpxml.foundation_walls[0].area /= 2.0
    hpxml.foundation_walls[0].depth_below_grade -= 4
    hpxml.foundation_walls[0].insulation_exterior_distance_to_bottom -= 4
    hpxml.foundation_walls[0].interior_finish_type = HPXML::InteriorFinishNone
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    hpxml.foundation_walls[0].area = 600
    hpxml.foundation_walls.add(id: 'FoundationWallInterior',
                               exterior_adjacent_to: HPXML::LocationCrawlspaceUnvented,
                               interior_adjacent_to: HPXML::LocationBasementUnconditioned,
                               height: 8,
                               area: 360,
                               thickness: 8,
                               depth_below_grade: 4,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 0,
                               insulation_exterior_r_value: 0)
    hpxml.foundation_walls.add(id: 'FoundationWallCrawlspace',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationCrawlspaceUnvented,
                               height: 4,
                               area: 600,
                               thickness: 8,
                               depth_below_grade: 3,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 0,
                               insulation_exterior_r_value: 0)
  elsif ['base-foundation-ambient.xml',
         'base-foundation-slab.xml'].include? hpxml_file
    hpxml.foundation_walls.clear
  elsif ['base-foundation-walkout-basement.xml'].include? hpxml_file
    hpxml.foundation_walls.clear
    hpxml.foundation_walls.add(id: 'FoundationWall1',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 8,
                               area: 480,
                               thickness: 8,
                               depth_below_grade: 7,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 8,
                               insulation_exterior_r_value: 8.9)
    hpxml.foundation_walls.add(id: 'FoundationWall2',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 4,
                               area: 120,
                               thickness: 8,
                               depth_below_grade: 3,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 4,
                               insulation_exterior_r_value: 8.9)
    hpxml.foundation_walls.add(id: 'FoundationWall3',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 2,
                               area: 60,
                               thickness: 8,
                               depth_below_grade: 1,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 2,
                               insulation_exterior_r_value: 8.9)
  elsif ['base-foundation-complex.xml'].include? hpxml_file
    hpxml.foundation_walls.clear
    hpxml.foundation_walls.add(id: 'FoundationWall1',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 8,
                               area: 160,
                               thickness: 8,
                               depth_below_grade: 7,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 0,
                               insulation_exterior_r_value: 0.0)
    hpxml.foundation_walls.add(id: 'FoundationWall2',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 8,
                               area: 240,
                               thickness: 8,
                               depth_below_grade: 7,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 8,
                               insulation_exterior_r_value: 8.9)
    hpxml.foundation_walls.add(id: 'FoundationWall3',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 4,
                               area: 160,
                               thickness: 8,
                               depth_below_grade: 3,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 0,
                               insulation_exterior_r_value: 0.0)
    hpxml.foundation_walls.add(id: 'FoundationWall4',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 4,
                               area: 120,
                               thickness: 8,
                               depth_below_grade: 3,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 4,
                               insulation_exterior_r_value: 8.9)
    hpxml.foundation_walls.add(id: 'FoundationWall5',
                               exterior_adjacent_to: HPXML::LocationGround,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 4,
                               area: 80,
                               thickness: 8,
                               depth_below_grade: 3,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 4,
                               insulation_exterior_r_value: 8.9)
  elsif ['base-enclosure-split-surfaces.xml',
         'base-enclosure-split-surfaces2.xml'].include? hpxml_file
    for n in 1..hpxml.foundation_walls.size
      hpxml.foundation_walls[n - 1].area /= 9.0
      for i in 2..9
        hpxml.foundation_walls << hpxml.foundation_walls[n - 1].dup
        hpxml.foundation_walls[-1].id += i.to_s
        if hpxml_file == 'base-enclosure-split-surfaces2.xml'
          hpxml.foundation_walls[-1].insulation_exterior_r_value += 0.01 * i
        end
      end
    end
    hpxml.foundation_walls << hpxml.foundation_walls[-1].dup
    hpxml.foundation_walls[-1].id = 'TinyFoundationWall'
    hpxml.foundation_walls[-1].area = 0.05
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.foundation_walls.each do |fwall|
      fwall.thickness = nil
      fwall.interior_finish_type = nil
      fwall.interior_finish_thickness = nil
      fwall.insulation_interior_distance_to_top = nil
      fwall.insulation_interior_distance_to_bottom = nil
      fwall.insulation_exterior_distance_to_top = nil
      fwall.insulation_exterior_distance_to_bottom = nil
      fwall.length = (fwall.area / fwall.height).round(2)
      fwall.area = nil
    end
  elsif ['invalid_files/invalid-facility-type-surfaces.xml'].include? hpxml_file
    hpxml.foundation_walls.add(id: 'FoundationWallOther',
                               exterior_adjacent_to: HPXML::LocationOtherHousingUnit,
                               interior_adjacent_to: HPXML::LocationBasementConditioned,
                               height: 8,
                               area: 294,
                               thickness: 8,
                               depth_below_grade: 7,
                               interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                               insulation_interior_r_value: 0,
                               insulation_interior_distance_to_top: 0,
                               insulation_interior_distance_to_bottom: 0,
                               insulation_exterior_distance_to_top: 0,
                               insulation_exterior_distance_to_bottom: 0,
                               insulation_exterior_r_value: 0)
  elsif ['invalid_files/enclosure-basement-missing-exterior-foundation-wall.xml'].include? hpxml_file
    hpxml.foundation_walls[0].delete
  elsif ['invalid_files/invalid-foundation-wall-properties.xml'].include? hpxml_file
    hpxml.foundation_walls[0].insulation_interior_distance_to_top = 12
    hpxml.foundation_walls[0].insulation_interior_distance_to_bottom = 10
    hpxml.foundation_walls[0].depth_below_grade = 9
  elsif ['invalid_files/invalid-insulation-top.xml'].include? hpxml_file
    hpxml.foundation_walls[0].insulation_exterior_distance_to_top = -0.5
  end
end

def set_hpxml_frame_floors(hpxml_file, hpxml)
  if ['ASHRAE_Standard_140/L100AC.xml',
      'ASHRAE_Standard_140/L100AL.xml'].include? hpxml_file
    hpxml.frame_floors.add(id: 'CeilingBelowAttic',
                           exterior_adjacent_to: HPXML::LocationAtticVented,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 1539,
                           interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                           interior_finish_thickness: 0.5,
                           insulation_assembly_r_value: 18.45)
    hpxml.frame_floors.add(id: 'FloorAboveFoundation',
                           exterior_adjacent_to: HPXML::LocationOutside,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 1539,
                           insulation_assembly_r_value: 14.15)
  elsif ['ASHRAE_Standard_140/L120AC.xml',
         'ASHRAE_Standard_140/L120AL.xml'].include? hpxml_file
    hpxml.frame_floors[0].insulation_assembly_r_value = 57.49
  elsif ['ASHRAE_Standard_140/L200AC.xml',
         'ASHRAE_Standard_140/L200AL.xml'].include? hpxml_file
    hpxml.frame_floors[0].insulation_assembly_r_value = 11.75
    hpxml.frame_floors[1].insulation_assembly_r_value = 4.24
  elsif ['ASHRAE_Standard_140/L302XC.xml',
         'ASHRAE_Standard_140/L322XC.xml',
         'ASHRAE_Standard_140/L324XC.xml'].include? hpxml_file
    hpxml.frame_floors.delete_at(1)
  elsif ['base.xml'].include? hpxml_file
    hpxml.frame_floors.add(id: 'CeilingBelowAttic',
                           exterior_adjacent_to: HPXML::LocationAtticUnvented,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 1350,
                           interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                           insulation_assembly_r_value: 39.3)
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.frame_floors.clear
    hpxml.frame_floors.add(id: 'FloorAboveOther',
                           exterior_adjacent_to: HPXML::LocationOtherHousingUnit,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 900,
                           insulation_assembly_r_value: 2.1,
                           other_space_above_or_below: HPXML::FrameFloorOtherSpaceBelow)
    hpxml.frame_floors.add(id: 'CeilingBelowOther',
                           exterior_adjacent_to: HPXML::LocationOtherHousingUnit,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 900,
                           interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                           insulation_assembly_r_value: 2.1,
                           other_space_above_or_below: HPXML::FrameFloorOtherSpaceAbove)
  elsif ['base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml'].include? hpxml_file
    hpxml.frame_floors[0].exterior_adjacent_to = HPXML::LocationOtherHousingUnit
    hpxml.frame_floors[1].exterior_adjacent_to = HPXML::LocationOtherHousingUnit
  elsif ['base-bldgtype-multifamily-adjacent-to-other-heated-space.xml'].include? hpxml_file
    hpxml.frame_floors[0].exterior_adjacent_to = HPXML::LocationOtherHeatedSpace
    hpxml.frame_floors[0].insulation_assembly_r_value = 18.7
    hpxml.frame_floors[1].exterior_adjacent_to = HPXML::LocationOtherHeatedSpace
    hpxml.frame_floors[1].insulation_assembly_r_value = 18.7
  elsif ['base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml'].include? hpxml_file
    hpxml.frame_floors[0].exterior_adjacent_to = HPXML::LocationOtherNonFreezingSpace
    hpxml.frame_floors[0].insulation_assembly_r_value = 18.7
    hpxml.frame_floors[1].exterior_adjacent_to = HPXML::LocationOtherNonFreezingSpace
    hpxml.frame_floors[1].insulation_assembly_r_value = 18.7
  elsif ['base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml'].include? hpxml_file
    hpxml.frame_floors[0].exterior_adjacent_to = HPXML::LocationOtherMultifamilyBufferSpace
    hpxml.frame_floors[0].insulation_assembly_r_value = 18.7
    hpxml.frame_floors[1].exterior_adjacent_to = HPXML::LocationOtherMultifamilyBufferSpace
    hpxml.frame_floors[1].insulation_assembly_r_value = 18.7
  elsif ['base-bldgtype-single-family-attached.xml'].include? hpxml_file
    hpxml.frame_floors[0].area = 900
  elsif ['base-atticroof-flat.xml',
         'base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.frame_floors.delete_at(0)
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    hpxml.frame_floors[0].exterior_adjacent_to = HPXML::LocationAtticVented
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.frame_floors[0].area = 450
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    hpxml.frame_floors.add(id: 'FloorBetweenAtticGarage',
                           exterior_adjacent_to: HPXML::LocationAtticUnvented,
                           interior_adjacent_to: HPXML::LocationGarage,
                           area: 600,
                           insulation_assembly_r_value: 2.1)
  elsif ['base-foundation-ambient.xml'].include? hpxml_file
    hpxml.frame_floors.add(id: 'FloorAboveAmbient',
                           exterior_adjacent_to: HPXML::LocationOutside,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 1350,
                           insulation_assembly_r_value: 18.7)
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.frame_floors.add(id: 'FloorAboveUncondBasement',
                           exterior_adjacent_to: HPXML::LocationBasementUnconditioned,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 1350,
                           insulation_assembly_r_value: 18.7)
  elsif ['base-foundation-unconditioned-basement-wall-insulation.xml'].include? hpxml_file
    hpxml.frame_floors[1].insulation_assembly_r_value = 2.1
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    hpxml.frame_floors.add(id: 'FloorAboveUnventedCrawl',
                           exterior_adjacent_to: HPXML::LocationCrawlspaceUnvented,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 1350,
                           insulation_assembly_r_value: 18.7)
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    hpxml.frame_floors.add(id: 'FloorAboveVentedCrawl',
                           exterior_adjacent_to: HPXML::LocationCrawlspaceVented,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 1350,
                           insulation_assembly_r_value: 18.7)
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    hpxml.frame_floors[1].area = 675
    hpxml.frame_floors.add(id: 'FloorAboveUnventedCrawlspace',
                           exterior_adjacent_to: HPXML::LocationCrawlspaceUnvented,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 675,
                           insulation_assembly_r_value: 18.7)
  elsif ['base-enclosure-2stories-garage.xml'].include? hpxml_file
    hpxml.frame_floors.add(id: 'FloorAboveGarage',
                           exterior_adjacent_to: HPXML::LocationGarage,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 400,
                           insulation_assembly_r_value: 39.3)
  elsif ['base-foundation-basement-garage.xml'].include? hpxml_file
    hpxml.frame_floors.add(id: 'FloorAbovegarage',
                           exterior_adjacent_to: HPXML::LocationGarage,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 400,
                           insulation_assembly_r_value: 39.3)
  elsif ['base-atticroof-unvented-insulated-roof.xml'].include? hpxml_file
    hpxml.frame_floors[0].insulation_assembly_r_value = 2.1
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    hpxml.frame_floors[0].delete
    hpxml.frame_floors.add(id: 'FloorAboveNonFreezingSpace',
                           exterior_adjacent_to: HPXML::LocationOtherNonFreezingSpace,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 550,
                           insulation_assembly_r_value: 18.7,
                           other_space_above_or_below: HPXML::FrameFloorOtherSpaceBelow)
    hpxml.frame_floors.add(id: 'FloorAboveMultifamilyBuffer',
                           exterior_adjacent_to: HPXML::LocationOtherMultifamilyBufferSpace,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 200,
                           insulation_assembly_r_value: 18.7,
                           other_space_above_or_below: HPXML::FrameFloorOtherSpaceBelow)
    hpxml.frame_floors.add(id: 'FloorAboveOtherHeatedSpace',
                           exterior_adjacent_to: HPXML::LocationOtherHeatedSpace,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 150,
                           insulation_assembly_r_value: 2.1,
                           other_space_above_or_below: HPXML::FrameFloorOtherSpaceBelow)
  elsif ['base-enclosure-split-surfaces.xml',
         'base-enclosure-split-surfaces2.xml'].include? hpxml_file
    for n in 1..hpxml.frame_floors.size
      hpxml.frame_floors[n - 1].area /= 9.0
      for i in 2..9
        hpxml.frame_floors << hpxml.frame_floors[n - 1].dup
        hpxml.frame_floors[-1].id += i.to_s
        if hpxml_file == 'base-enclosure-split-surfaces2.xml'
          hpxml.frame_floors[-1].insulation_assembly_r_value += 0.01 * i
        end
      end
    end
    hpxml.frame_floors << hpxml.frame_floors[-1].dup
    hpxml.frame_floors[-1].id = 'TinyFloor'
    hpxml.frame_floors[-1].area = 0.05
  elsif ['invalid_files/base-enclosure-conditioned-basement-slab-insulation.xml'].include? hpxml_file
    hpxml.frame_floors.add(id: 'FloorAboveCondBasement',
                           exterior_adjacent_to: HPXML::LocationBasementConditioned,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 1350,
                           insulation_assembly_r_value: 3.9)
  elsif ['invalid_files/enclosure-living-missing-ceiling-roof.xml'].include? hpxml_file
    hpxml.frame_floors[0].delete
  elsif ['invalid_files/enclosure-basement-missing-ceiling.xml',
         'invalid_files/enclosure-garage-missing-roof-ceiling.xml'].include? hpxml_file
    hpxml.frame_floors[1].delete
  elsif ['invalid_files/multifamily-reference-surface.xml'].include? hpxml_file
    hpxml.frame_floors << hpxml.frame_floors[0].dup
    hpxml.frame_floors[1].id += '2'
    hpxml.frame_floors[1].exterior_adjacent_to = HPXML::LocationOtherHeatedSpace
    hpxml.frame_floors[1].other_space_above_or_below = HPXML::FrameFloorOtherSpaceAbove
  elsif ['invalid_files/invalid-facility-type-surfaces.xml'].include? hpxml_file
    hpxml.frame_floors.add(id: 'FloorAboveOther',
                           exterior_adjacent_to: HPXML::LocationOtherHousingUnit,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 900,
                           insulation_assembly_r_value: 2.1,
                           other_space_above_or_below: HPXML::FrameFloorOtherSpaceBelow)
    hpxml.frame_floors.add(id: 'CeilingBelowOther',
                           exterior_adjacent_to: HPXML::LocationOtherHousingUnit,
                           interior_adjacent_to: HPXML::LocationLivingSpace,
                           area: 900,
                           interior_finish_type: HPXML::InteriorFinishGypsumBoard,
                           insulation_assembly_r_value: 2.1,
                           other_space_above_or_below: HPXML::FrameFloorOtherSpaceAbove)
  end
end

def set_hpxml_slabs(hpxml_file, hpxml)
  if ['ASHRAE_Standard_140/L302XC.xml'].include? hpxml_file
    hpxml.slabs.add(id: 'Slab',
                    interior_adjacent_to: HPXML::LocationLivingSpace,
                    area: 1539,
                    thickness: 4,
                    exposed_perimeter: 168,
                    perimeter_insulation_depth: 0,
                    under_slab_insulation_width: 0,
                    under_slab_insulation_spans_entire_slab: nil,
                    depth_below_grade: 0,
                    perimeter_insulation_r_value: 0,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 1,
                    carpet_r_value: 2.08)
  elsif ['ASHRAE_Standard_140/L304XC.xml'].include? hpxml_file
    hpxml.slabs[0].perimeter_insulation_depth = 2.5
    hpxml.slabs[0].perimeter_insulation_r_value = 5.4
  elsif ['ASHRAE_Standard_140/L322XC.xml'].include? hpxml_file
    hpxml.slabs.add(id: 'Slab',
                    interior_adjacent_to: HPXML::LocationBasementConditioned,
                    area: 1539,
                    thickness: 4,
                    exposed_perimeter: 168,
                    perimeter_insulation_depth: 0,
                    under_slab_insulation_width: 0,
                    under_slab_insulation_spans_entire_slab: nil,
                    perimeter_insulation_r_value: 0,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 0,
                    carpet_r_value: 0)
  elsif ['base.xml'].include? hpxml_file
    hpxml.slabs.add(id: 'Slab',
                    interior_adjacent_to: HPXML::LocationBasementConditioned,
                    area: 1350,
                    thickness: 4,
                    exposed_perimeter: 150,
                    perimeter_insulation_depth: 0,
                    under_slab_insulation_width: 0,
                    perimeter_insulation_r_value: 0,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 0,
                    carpet_r_value: 0)
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.slabs.clear
  elsif ['base-bldgtype-single-family-attached.xml'].include? hpxml_file
    hpxml.slabs[0].area = 900
    hpxml.slabs[0].exposed_perimeter = 86
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.slabs[0].interior_adjacent_to = HPXML::LocationBasementUnconditioned
  elsif ['base-foundation-conditioned-basement-slab-insulation.xml'].include? hpxml_file
    hpxml.slabs[0].under_slab_insulation_width = 4
    hpxml.slabs[0].under_slab_insulation_r_value = 10
  elsif ['base-foundation-slab.xml'].include? hpxml_file
    hpxml.slabs[0].interior_adjacent_to = HPXML::LocationLivingSpace
    hpxml.slabs[0].under_slab_insulation_width = nil
    hpxml.slabs[0].under_slab_insulation_spans_entire_slab = true
    hpxml.slabs[0].depth_below_grade = 0
    hpxml.slabs[0].under_slab_insulation_r_value = 5
    hpxml.slabs[0].carpet_fraction = 1
    hpxml.slabs[0].carpet_r_value = 2.5
  elsif ['base-foundation-unvented-crawlspace.xml',
         'base-foundation-vented-crawlspace.xml'].include? hpxml_file
    if ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
      hpxml.slabs[0].interior_adjacent_to = HPXML::LocationCrawlspaceUnvented
    else
      hpxml.slabs[0].interior_adjacent_to = HPXML::LocationCrawlspaceVented
    end
    hpxml.slabs[0].thickness = 0
    hpxml.slabs[0].carpet_r_value = 2.5
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    hpxml.slabs[0].area = 675
    hpxml.slabs[0].exposed_perimeter = 75
    hpxml.slabs.add(id: 'SlabUnderCrawlspace',
                    interior_adjacent_to: HPXML::LocationCrawlspaceUnvented,
                    area: 675,
                    thickness: 0,
                    exposed_perimeter: 75,
                    perimeter_insulation_depth: 0,
                    under_slab_insulation_width: 0,
                    perimeter_insulation_r_value: 0,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 0,
                    carpet_r_value: 0)
  elsif ['base-foundation-ambient.xml'].include? hpxml_file
    hpxml.slabs.clear
  elsif ['base-enclosure-2stories-garage.xml',
         'base-foundation-basement-garage.xml'].include? hpxml_file
    hpxml.slabs[0].area -= 400
    hpxml.slabs[0].exposed_perimeter -= 40
    hpxml.slabs.add(id: 'SlabUnderGarage',
                    interior_adjacent_to: HPXML::LocationGarage,
                    area: 400,
                    thickness: 4,
                    exposed_perimeter: 40,
                    perimeter_insulation_depth: 0,
                    under_slab_insulation_width: 0,
                    depth_below_grade: 0,
                    perimeter_insulation_r_value: 0,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 0,
                    carpet_r_value: 0)
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    hpxml.slabs[0].exposed_perimeter -= 30
    hpxml.slabs.add(id: 'SlabUnderGarage',
                    interior_adjacent_to: HPXML::LocationGarage,
                    area: 600,
                    thickness: 4,
                    exposed_perimeter: 70,
                    perimeter_insulation_depth: 0,
                    under_slab_insulation_width: 0,
                    depth_below_grade: 0,
                    perimeter_insulation_r_value: 0,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 0,
                    carpet_r_value: 0)
  elsif ['base-foundation-complex.xml'].include? hpxml_file
    hpxml.slabs.clear
    hpxml.slabs.add(id: 'Slab1',
                    interior_adjacent_to: HPXML::LocationBasementConditioned,
                    area: 675,
                    thickness: 4,
                    exposed_perimeter: 75,
                    perimeter_insulation_depth: 0,
                    under_slab_insulation_width: 0,
                    perimeter_insulation_r_value: 0,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 0,
                    carpet_r_value: 0)
    hpxml.slabs.add(id: 'Slab2',
                    interior_adjacent_to: HPXML::LocationBasementConditioned,
                    area: 405,
                    thickness: 4,
                    exposed_perimeter: 45,
                    perimeter_insulation_depth: 1,
                    under_slab_insulation_width: 0,
                    perimeter_insulation_r_value: 5,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 0,
                    carpet_r_value: 0)
    hpxml.slabs.add(id: 'Slab3',
                    interior_adjacent_to: HPXML::LocationBasementConditioned,
                    area: 270,
                    thickness: 4,
                    exposed_perimeter: 30,
                    perimeter_insulation_depth: 1,
                    under_slab_insulation_width: 0,
                    perimeter_insulation_r_value: 5,
                    under_slab_insulation_r_value: 0,
                    carpet_fraction: 0,
                    carpet_r_value: 0)
  elsif ['base-enclosure-split-surfaces.xml',
         'base-enclosure-split-surfaces2.xml'].include? hpxml_file
    for n in 1..hpxml.slabs.size
      hpxml.slabs[n - 1].area /= 9.0
      hpxml.slabs[n - 1].exposed_perimeter /= 9.0
      for i in 2..9
        hpxml.slabs << hpxml.slabs[n - 1].dup
        hpxml.slabs[-1].id += i.to_s
        if hpxml_file == 'base-enclosure-split-surfaces2.xml'
          hpxml.slabs[-1].perimeter_insulation_depth += 0.01 * i
          hpxml.slabs[-1].perimeter_insulation_r_value += 0.01 * i
        end
      end
    end
    hpxml.slabs << hpxml.slabs[-1].dup
    hpxml.slabs[-1].id = 'TinySlab'
    hpxml.slabs[-1].area = 0.05
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.slabs.each do |slab|
      slab.thickness = nil
      slab.carpet_fraction = nil
      slab.carpet_fraction = nil
    end
  elsif ['invalid_files/enclosure-living-missing-floor-slab.xml',
         'invalid_files/enclosure-basement-missing-slab.xml'].include? hpxml_file
    hpxml.slabs[0].delete
  elsif ['invalid_files/enclosure-garage-missing-slab.xml'].include? hpxml_file
    hpxml.slabs[1].delete
  end
end

def set_hpxml_windows(hpxml_file, hpxml)
  if ['ASHRAE_Standard_140/L100AC.xml',
      'ASHRAE_Standard_140/L100AL.xml'].include? hpxml_file
    windows = { 'WindowNorth' => [0, 90, 'WallNorth'],
                'WindowEast' => [90, 45, 'WallEast'],
                'WindowSouth' => [180, 90, 'WallSouth'],
                'WindowWest' => [270, 45, 'WallWest'] }
    windows.each do |window_name, window_values|
      azimuth, area, wall = window_values
      hpxml.windows.add(id: window_name,
                        area: area,
                        azimuth: azimuth,
                        ufactor: 1.039,
                        shgc: 0.67,
                        fraction_operable: 0.0,
                        wall_idref: wall,
                        interior_shading_factor_summer: 1,
                        interior_shading_factor_winter: 1)
    end
  elsif ['ASHRAE_Standard_140/L130AC.xml',
         'ASHRAE_Standard_140/L130AL.xml'].include? hpxml_file
    for i in 0..hpxml.windows.size - 1
      hpxml.windows[i].ufactor = 0.3
      hpxml.windows[i].shgc = 0.335
    end
  elsif ['ASHRAE_Standard_140/L140AC.xml',
         'ASHRAE_Standard_140/L140AL.xml'].include? hpxml_file
    hpxml.windows.clear
  elsif ['ASHRAE_Standard_140/L150AC.xml',
         'ASHRAE_Standard_140/L150AL.xml'].include? hpxml_file
    hpxml.windows.clear
    hpxml.windows.add(id: 'WindowSouth',
                      area: 270,
                      azimuth: 180,
                      ufactor: 1.039,
                      shgc: 0.67,
                      fraction_operable: 0.0,
                      wall_idref: 'WallSouth',
                      interior_shading_factor_summer: 1,
                      interior_shading_factor_winter: 1)
  elsif ['ASHRAE_Standard_140/L155AC.xml',
         'ASHRAE_Standard_140/L155AL.xml'].include? hpxml_file
    hpxml.windows[0].overhangs_depth = 2.5
    hpxml.windows[0].overhangs_distance_to_top_of_window = 1
    hpxml.windows[0].overhangs_distance_to_bottom_of_window = 6
  elsif ['ASHRAE_Standard_140/L160AC.xml',
         'ASHRAE_Standard_140/L160AL.xml'].include? hpxml_file
    hpxml.windows.clear
    windows = { 'WindowEast' => [90, 135, 'WallEast'],
                'WindowWest' => [270, 135, 'WallWest'] }
    windows.each do |window_name, window_values|
      azimuth, area, wall = window_values
      hpxml.windows.add(id: window_name,
                        area: area,
                        azimuth: azimuth,
                        ufactor: 1.039,
                        shgc: 0.67,
                        fraction_operable: 0.0,
                        wall_idref: wall,
                        interior_shading_factor_summer: 1,
                        interior_shading_factor_winter: 1)
    end
  elsif ['base.xml'].include? hpxml_file
    hpxml.windows.add(id: 'WindowNorth',
                      area: 108,
                      azimuth: 0,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      interior_shading_factor_summer: 0.7,
                      interior_shading_factor_winter: 0.85,
                      wall_idref: 'Wall')
    hpxml.windows.add(id: 'WindowSouth',
                      area: 108,
                      azimuth: 180,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      interior_shading_factor_summer: 0.7,
                      interior_shading_factor_winter: 0.85,
                      wall_idref: 'Wall')
    hpxml.windows.add(id: 'WindowEast',
                      area: 72,
                      azimuth: 90,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      interior_shading_factor_summer: 0.7,
                      interior_shading_factor_winter: 0.85,
                      wall_idref: 'Wall')
    hpxml.windows.add(id: 'WindowWest',
                      area: 72,
                      azimuth: 270,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      interior_shading_factor_summer: 0.7,
                      interior_shading_factor_winter: 0.85,
                      wall_idref: 'Wall')
  elsif ['base-enclosure-orientations.xml'].include? hpxml_file
    hpxml.windows[0].azimuth = nil
    hpxml.windows[0].orientation = HPXML::OrientationNorth
    hpxml.windows[1].azimuth = nil
    hpxml.windows[1].orientation = HPXML::OrientationSouth
    hpxml.windows[2].azimuth = nil
    hpxml.windows[2].orientation = HPXML::OrientationEast
    hpxml.windows[3].azimuth = nil
    hpxml.windows[3].orientation = HPXML::OrientationWest
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.windows.clear
    hpxml.windows.add(id: 'WindowNorth',
                      area: 35.0,
                      azimuth: 0,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      interior_shading_factor_summer: 0.7,
                      interior_shading_factor_winter: 0.85,
                      wall_idref: 'Wall')
    hpxml.windows.add(id: 'WindowSouth',
                      area: 35.0,
                      azimuth: 180,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      interior_shading_factor_summer: 0.7,
                      interior_shading_factor_winter: 0.85,
                      wall_idref: 'Wall')
    hpxml.windows.add(id: 'WindowWest',
                      area: 53.0,
                      azimuth: 270,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      interior_shading_factor_summer: 0.7,
                      interior_shading_factor_winter: 0.85,
                      wall_idref: 'Wall')
  elsif ['base-bldgtype-single-family-attached.xml'].include? hpxml_file
    hpxml.windows.clear
    hpxml.windows.add(id: 'WindowNorth',
                      area: 35.4,
                      azimuth: 0,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      interior_shading_factor_summer: 0.7,
                      interior_shading_factor_winter: 0.85,
                      wall_idref: 'Wall')
    hpxml.windows.add(id: 'WindowSouth',
                      area: 35.4,
                      azimuth: 180,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      interior_shading_factor_summer: 0.7,
                      interior_shading_factor_winter: 0.85,
                      wall_idref: 'Wall')
    hpxml.windows.add(id: 'WindowWest',
                      area: 53.0,
                      azimuth: 270,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      interior_shading_factor_summer: 0.7,
                      interior_shading_factor_winter: 0.85,
                      wall_idref: 'Wall')
  elsif ['base-enclosure-overhangs.xml'].include? hpxml_file
    hpxml.windows[0].overhangs_depth = 2.5
    hpxml.windows[0].overhangs_distance_to_top_of_window = 0
    hpxml.windows[0].overhangs_distance_to_bottom_of_window = 4
    hpxml.windows[1].overhangs_depth = 0
    hpxml.windows[1].overhangs_distance_to_top_of_window = 1
    hpxml.windows[1].overhangs_distance_to_bottom_of_window = 5
    hpxml.windows[2].overhangs_depth = 1.5
    hpxml.windows[2].overhangs_distance_to_top_of_window = 2
    hpxml.windows[2].overhangs_distance_to_bottom_of_window = 6
    hpxml.windows[3].overhangs_depth = 1.5
    hpxml.windows[3].overhangs_distance_to_top_of_window = 2
    hpxml.windows[3].overhangs_distance_to_bottom_of_window = 7
  elsif ['base-enclosure-windows-shading.xml'].include? hpxml_file
    hpxml.windows[1].exterior_shading_factor_summer = 0.1
    hpxml.windows[1].exterior_shading_factor_winter = 0.9
    hpxml.windows[1].interior_shading_factor_summer = 0.01
    hpxml.windows[1].interior_shading_factor_winter = 0.99
    hpxml.windows[2].exterior_shading_factor_summer = 0.5
    hpxml.windows[2].exterior_shading_factor_winter = 0.5
    hpxml.windows[2].interior_shading_factor_summer = 0.5
    hpxml.windows[2].interior_shading_factor_winter = 0.5
    hpxml.windows[3].exterior_shading_factor_summer = 0.0
    hpxml.windows[3].exterior_shading_factor_winter = 1.0
    hpxml.windows[3].interior_shading_factor_summer = 0.0
    hpxml.windows[3].interior_shading_factor_winter = 1.0
  elsif ['base-enclosure-windows-none.xml'].include? hpxml_file
    hpxml.windows.clear
  elsif ['invalid_files/net-area-negative-wall.xml'].include? hpxml_file
    hpxml.windows[0].area = 1000
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.windows[0].area = 108
    hpxml.windows[1].area = 108
    hpxml.windows[2].area = 108
    hpxml.windows[3].area = 108
    hpxml.windows.add(id: 'AtticGableWindowEast',
                      area: 12,
                      azimuth: 90,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: 'WallAtticGableCond')
    hpxml.windows.add(id: 'AtticGableWindowWest',
                      area: 62,
                      azimuth: 270,
                      ufactor: 0.3,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: 'WallAtticGableCond')
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.windows[0].area = 108
    hpxml.windows[1].area = 108
    hpxml.windows[2].area = 108
    hpxml.windows[3].area = 108
    hpxml.windows.add(id: 'AtticGableWindowEast',
                      area: 12,
                      azimuth: 90,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: 'WallAtticGable')
    hpxml.windows.add(id: 'AtticGableWindowWest',
                      area: 12,
                      azimuth: 270,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: 'WallAtticGable')
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    hpxml.windows[1].area = 12
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    hpxml.windows[0].area = 216
    hpxml.windows[1].area = 216
    hpxml.windows[2].area = 144
    hpxml.windows[3].area = 144
  elsif ['base-enclosure-2stories-garage'].include? hpxml_file
    hpxml.windows[0].area = 168
    hpxml.windows[1].area = 216
    hpxml.windows[2].area = 144
    hpxml.windows[3].area = 96
  elsif ['base-foundation-unconditioned-basement-above-grade.xml'].include? hpxml_file
    hpxml.windows.add(id: 'FoundationWindowNorth',
                      area: 20,
                      azimuth: 0,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: 'FoundationWall')
    hpxml.windows.add(id: 'FoundationWindowSouth',
                      area: 20,
                      azimuth: 180,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: 'FoundationWall')
    hpxml.windows.add(id: 'FoundationWindowEast',
                      area: 10,
                      azimuth: 90,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: 'FoundationWall')
    hpxml.windows.add(id: 'FoundationWindowWest',
                      area: 10,
                      azimuth: 270,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: 'FoundationWall')
  elsif ['base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml',
         'base-bldgtype-multifamily-adjacent-to-other-heated-space.xml',
         'base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml',
         'base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml'].include? hpxml_file
    hpxml.windows.each do |window|
      window.area *= 0.35
    end
  elsif ['invalid_files/unattached-window.xml'].include? hpxml_file
    hpxml.windows[0].wall_idref = 'foobar'
  elsif ['base-enclosure-split-surfaces.xml',
         'base-enclosure-split-surfaces2.xml'].include? hpxml_file
    area_adjustments = []
    for n in 1..hpxml.windows.size
      hpxml.windows[n - 1].area /= 9.0
      hpxml.windows[n - 1].fraction_operable = 0.0
      for i in 2..9
        hpxml.windows << hpxml.windows[n - 1].dup
        hpxml.windows[-1].id += i.to_s
        hpxml.windows[-1].wall_idref += i.to_s
        if i >= 4
          hpxml.windows[-1].fraction_operable = 1.0
        end
        next unless hpxml_file == 'base-enclosure-split-surfaces2.xml'

        hpxml.windows[-1].ufactor += 0.01 * i
        hpxml.windows[-1].interior_shading_factor_summer -= 0.02 * i
        hpxml.windows[-1].interior_shading_factor_winter -= 0.01 * i
      end
    end
    hpxml.windows << hpxml.windows[-1].dup
    hpxml.windows[-1].id = 'TinyWindow'
    hpxml.windows[-1].area = 0.05
  elsif ['base-foundation-walkout-basement.xml'].include? hpxml_file
    hpxml.windows.add(id: 'FoundationWindow',
                      area: 20,
                      azimuth: 0,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.0,
                      wall_idref: 'FoundationWall3')
  elsif ['invalid_files/invalid-window-height.xml'].include? hpxml_file
    hpxml.windows[2].overhangs_distance_to_bottom_of_window = hpxml.windows[2].overhangs_distance_to_top_of_window
  elsif ['base-enclosure-walltypes.xml'].include? hpxml_file
    hpxml.windows.clear
    hpxml.windows.add(id: 'WindowNorth',
                      area: 108 / 8,
                      azimuth: 0,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      wall_idref: 'Wall1')
    hpxml.windows.add(id: 'WindowSouth',
                      area: 108 / 8,
                      azimuth: 180,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      wall_idref: 'Wall2')
    hpxml.windows.add(id: 'WindowEast',
                      area: 72 / 8,
                      azimuth: 90,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      wall_idref: 'Wall3')
    hpxml.windows.add(id: 'WindowWest',
                      area: 72 / 8,
                      azimuth: 270,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      wall_idref: 'Wall4')
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.windows.each do |window|
      window.interior_shading_factor_summer = nil
      window.interior_shading_factor_winter = nil
      window.fraction_operable = nil
    end
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    hpxml.windows.add(id: 'WindowOtherMultifamilyBufferSpace',
                      area: 50,
                      azimuth: 270,
                      ufactor: 0.33,
                      shgc: 0.45,
                      fraction_operable: 0.67,
                      wall_idref: 'WallOtherMultifamilyBufferSpace')
  elsif ['invalid_files/duplicate-id.xml'].include? hpxml_file
    hpxml.windows[-1].id = hpxml.windows[0].id
  end
end

def set_hpxml_skylights(hpxml_file, hpxml)
  if ['base-enclosure-skylights.xml'].include? hpxml_file
    hpxml.skylights.add(id: 'SkylightNorth',
                        area: 15,
                        azimuth: 0,
                        ufactor: 0.33,
                        shgc: 0.45,
                        interior_shading_factor_summer: 1.0,
                        interior_shading_factor_winter: 1.0,
                        roof_idref: 'Roof')
    hpxml.skylights.add(id: 'SkylightSouth',
                        area: 15,
                        azimuth: 180,
                        ufactor: 0.35,
                        shgc: 0.47,
                        interior_shading_factor_summer: 1.0,
                        interior_shading_factor_winter: 1.0,
                        roof_idref: 'Roof')
  elsif ['base-enclosure-skylights-shading.xml'].include? hpxml_file
    hpxml.skylights[0].exterior_shading_factor_summer = 0.1
    hpxml.skylights[0].exterior_shading_factor_winter = 0.9
    hpxml.skylights[0].interior_shading_factor_summer = 0.01
    hpxml.skylights[0].interior_shading_factor_winter = 0.99
    hpxml.skylights[1].exterior_shading_factor_summer = 0.5
    hpxml.skylights[1].exterior_shading_factor_winter = 0.0
    hpxml.skylights[1].interior_shading_factor_summer = 0.5
    hpxml.skylights[1].interior_shading_factor_winter = 1.0
  elsif ['invalid_files/net-area-negative-roof.xml'].include? hpxml_file
    hpxml.skylights[0].area = 4000
  elsif ['invalid_files/unattached-skylight.xml'].include? hpxml_file
    hpxml.skylights[0].roof_idref = 'foobar'
  elsif ['invalid_files/invalid-id.xml'].include? hpxml_file
    hpxml.skylights[0].id = ''
  elsif ['base-enclosure-split-surfaces.xml',
         'base-enclosure-split-surfaces2.xml'].include? hpxml_file
    for n in 1..hpxml.skylights.size
      hpxml.skylights[n - 1].area /= 9.0
      for i in 2..9
        hpxml.skylights << hpxml.skylights[n - 1].dup
        hpxml.skylights[-1].id += i.to_s
        hpxml.skylights[-1].roof_idref += i.to_s if i % 2 == 0
        next unless hpxml_file == 'base-enclosure-split-surfaces2.xml'

        hpxml.skylights[-1].ufactor += 0.01 * i
        hpxml.skylights[-1].interior_shading_factor_summer -= 0.02 * i
        hpxml.skylights[-1].interior_shading_factor_winter -= 0.01 * i
      end
    end
    hpxml.skylights << hpxml.skylights[-1].dup
    hpxml.skylights[-1].id = 'TinySkylight'
    hpxml.skylights[-1].area = 0.05
  end
end

def set_hpxml_doors(hpxml_file, hpxml)
  if ['ASHRAE_Standard_140/L100AC.xml',
      'ASHRAE_Standard_140/L100AL.xml'].include? hpxml_file
    doors = { 'DoorSouth' => [180, 20, 'WallSouth'],
              'DoorNorth' => [0, 20, 'WallNorth'] }
    doors.each do |door_name, door_values|
      azimuth, area, wall = door_values
      hpxml.doors.add(id: door_name,
                      wall_idref: wall,
                      area: area,
                      azimuth: azimuth,
                      r_value: 3.04)
    end
  elsif ['base.xml'].include? hpxml_file
    hpxml.doors.add(id: 'DoorNorth',
                    wall_idref: 'Wall',
                    area: 20,
                    azimuth: 0,
                    r_value: 4.4)
    hpxml.doors.add(id: 'DoorSouth',
                    wall_idref: 'Wall',
                    area: 20,
                    azimuth: 180,
                    r_value: 4.4)
  elsif ['base-enclosure-orientations.xml'].include? hpxml_file
    hpxml.doors[0].azimuth = nil
    hpxml.doors[0].orientation = HPXML::OrientationNorth
    hpxml.doors[1].azimuth = nil
    hpxml.doors[1].orientation = HPXML::OrientationSouth
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.doors.clear
    hpxml.doors.add(id: 'Door',
                    wall_idref: 'Wall',
                    area: 20,
                    azimuth: 180,
                    r_value: 4.4)
  elsif ['base-enclosure-garage.xml',
         'base-enclosure-2stories-garage.xml'].include? hpxml_file
    hpxml.doors.add(id: 'GarageDoorSouth',
                    wall_idref: 'WallGarageExterior',
                    area: 70,
                    azimuth: 180,
                    r_value: 4.4)
  elsif ['base-foundation-basement-garage.xml'].include? hpxml_file
    hpxml.doors.add(id: 'GarageDoorSouth',
                    wall_idref: 'WallGarageExterior',
                    area: 70,
                    azimuth: 180,
                    r_value: 4.4)
    hpxml.doors.add(id: 'GarageDoorBasement',
                    wall_idref: 'WallGarageBasement',
                    area: 4,
                    azimuth: 0,
                    r_value: 4.4)
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    hpxml.doors.add(id: 'DoorOtherHeatedSpace',
                    wall_idref: 'WallOtherHeatedSpace',
                    area: 20,
                    azimuth: 0,
                    r_value: 4.4)
    hpxml.doors.add(id: 'DoorOtherHousingUnit',
                    wall_idref: 'WallOtherHousingUnit',
                    area: 20,
                    azimuth: 0,
                    r_value: 4.4)
  elsif ['base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml',
         'base-bldgtype-multifamily-adjacent-to-other-heated-space.xml',
         'base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml',
         'base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml'].include? hpxml_file
    hpxml.doors.add(id: 'DoorOther',
                    wall_idref: 'WallOther',
                    area: 20,
                    azimuth: 0,
                    r_value: 4.4)
  elsif ['invalid_files/unattached-door.xml'].include? hpxml_file
    hpxml.doors[0].wall_idref = 'foobar'
  elsif ['base-enclosure-split-surfaces.xml',
         'base-enclosure-split-surfaces2.xml'].include? hpxml_file
    area_adjustments = []
    for n in 1..hpxml.doors.size
      hpxml.doors[n - 1].area /= 9.0
      for i in 2..9
        hpxml.doors << hpxml.doors[n - 1].dup
        hpxml.doors[-1].id += i.to_s
        hpxml.doors[-1].wall_idref += i.to_s
        if hpxml_file == 'base-enclosure-split-surfaces2.xml'
          hpxml.doors[-1].r_value += 0.01 * i
        end
      end
    end
    hpxml.doors << hpxml.doors[-1].dup
    hpxml.doors[-1].id = 'TinyDoor'
    hpxml.doors[-1].area = 0.05
  elsif ['base-enclosure-walltypes.xml'].include? hpxml_file
    hpxml.doors.clear
    hpxml.doors.add(id: 'DoorNorth',
                    wall_idref: 'Wall9',
                    area: 20,
                    azimuth: 0,
                    r_value: 4.4)
    hpxml.doors.add(id: 'DoorSouth',
                    wall_idref: 'Wall10',
                    area: 20,
                    azimuth: 180,
                    r_value: 4.4)
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.doors.each do |door|
      door.azimuth = nil
    end
  end
end

def set_hpxml_heating_systems(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.heating_systems.add(id: 'HeatingSystem',
                              distribution_system_idref: 'HVACDistribution',
                              heating_system_type: HPXML::HVACTypeFurnace,
                              heating_system_fuel: HPXML::FuelTypeNaturalGas,
                              heating_capacity: 36000,
                              heating_efficiency_afue: 0.92,
                              fraction_heat_load_served: 1)
  elsif ['base-hvac-air-to-air-heat-pump-1-speed.xml',
         'base-hvac-air-to-air-heat-pump-2-speed.xml',
         'base-hvac-air-to-air-heat-pump-var-speed.xml',
         'base-hvac-central-ac-only-1-speed.xml',
         'base-hvac-central-ac-only-2-speed.xml',
         'base-hvac-central-ac-only-var-speed.xml',
         'base-hvac-evap-cooler-only.xml',
         'base-hvac-evap-cooler-only-ducted.xml',
         'base-hvac-ground-to-air-heat-pump.xml',
         'base-hvac-mini-split-heat-pump-ducted.xml',
         'base-hvac-mini-split-air-conditioner-only-ducted.xml',
         'base-hvac-none.xml',
         'base-hvac-room-ac-only.xml',
         'base-bldgtype-multifamily-shared-chiller-only-baseboard.xml',
         'base-bldgtype-multifamily-shared-ground-loop-ground-to-air-heat-pump.xml',
         'invalid_files/orphaned-hvac-distribution.xml'].include? hpxml_file
    hpxml.heating_systems.clear
  elsif ['base-hvac-boiler-elec-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeBoiler
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeElectricity
    hpxml.heating_systems[0].heating_efficiency_afue = 0.98
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.xml',
         'base-hvac-boiler-gas-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeBoiler
    hpxml.heating_systems[0].electric_auxiliary_energy = 200
  elsif ['base-hvac-boiler-oil-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeBoiler
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeOil
  elsif ['base-hvac-boiler-propane-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeBoiler
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypePropane
  elsif ['base-hvac-boiler-coal-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeBoiler
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeCoal
  elsif ['base-hvac-boiler-wood-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeBoiler
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeWoodCord
  elsif ['base-hvac-elec-resistance-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeElectricResistance
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeElectricity
    hpxml.heating_systems[0].heating_efficiency_afue = nil
    hpxml.heating_systems[0].heating_efficiency_percent = 1
  elsif ['base-hvac-furnace-elec-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeElectricity
    hpxml.heating_systems[0].heating_efficiency_afue = 0.98
  elsif ['base-hvac-furnace-oil-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeOil
  elsif ['base-hvac-furnace-propane-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypePropane
  elsif ['base-hvac-furnace-coal-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeCoal
  elsif ['base-hvac-furnace-wood-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeWoodCord
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    hpxml.heating_systems.clear
    hpxml.heating_systems.add(id: 'HeatingSystem',
                              distribution_system_idref: 'HVACDistribution',
                              heating_system_type: HPXML::HVACTypeFurnace,
                              heating_system_fuel: HPXML::FuelTypeElectricity,
                              heating_capacity: 6400,
                              heating_efficiency_afue: 1,
                              fraction_heat_load_served: 0.1)
    hpxml.heating_systems.add(id: 'HeatingSystem2',
                              distribution_system_idref: 'HVACDistribution2',
                              heating_system_type: HPXML::HVACTypeFurnace,
                              heating_system_fuel: HPXML::FuelTypeNaturalGas,
                              heating_capacity: 6400,
                              heating_efficiency_afue: 0.92,
                              fraction_heat_load_served: 0.1)
    hpxml.heating_systems.add(id: 'HeatingSystem3',
                              distribution_system_idref: 'HVACDistribution3',
                              heating_system_type: HPXML::HVACTypeBoiler,
                              heating_system_fuel: HPXML::FuelTypeElectricity,
                              heating_capacity: 6400,
                              heating_efficiency_afue: 1,
                              fraction_heat_load_served: 0.1)
    hpxml.heating_systems.add(id: 'HeatingSystem4',
                              distribution_system_idref: 'HVACDistribution4',
                              heating_system_type: HPXML::HVACTypeBoiler,
                              heating_system_fuel: HPXML::FuelTypeNaturalGas,
                              heating_capacity: 6400,
                              heating_efficiency_afue: 0.92,
                              fraction_heat_load_served: 0.1,
                              electric_auxiliary_energy: 200)
    hpxml.heating_systems.add(id: 'HeatingSystem5',
                              heating_system_type: HPXML::HVACTypeElectricResistance,
                              heating_system_fuel: HPXML::FuelTypeElectricity,
                              heating_capacity: 6400,
                              heating_efficiency_percent: 1,
                              fraction_heat_load_served: 0.1)
    hpxml.heating_systems.add(id: 'HeatingSystem6',
                              heating_system_type: HPXML::HVACTypeStove,
                              heating_system_fuel: HPXML::FuelTypeOil,
                              heating_capacity: 6400,
                              heating_efficiency_percent: 0.8,
                              fraction_heat_load_served: 0.1,
                              fan_watts: 40.0)
    hpxml.heating_systems.add(id: 'HeatingSystem7',
                              heating_system_type: HPXML::HVACTypeWallFurnace,
                              heating_system_fuel: HPXML::FuelTypePropane,
                              heating_capacity: 6400,
                              heating_efficiency_afue: 0.8,
                              fraction_heat_load_served: 0.1,
                              fan_watts: 0.0)
  elsif ['base-mechvent-multiple.xml',
         'base-bldgtype-multifamily-shared-mechvent-multiple.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_capacity /= 2.0
    hpxml.heating_systems[0].fraction_heat_load_served /= 2.0
    hpxml.heating_systems << hpxml.heating_systems[0].dup
    hpxml.heating_systems[1].id = 'HeatingSystem2'
    hpxml.heating_systems[1].distribution_system_idref = 'HVACDistribution2'
  elsif ['invalid_files/hvac-frac-load-served.xml'].include? hpxml_file
    hpxml.heating_systems[0].fraction_heat_load_served += 0.1
  elsif ['base-hvac-fireplace-wood-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeFireplace
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeWoodCord
    hpxml.heating_systems[0].heating_efficiency_afue = nil
    hpxml.heating_systems[0].heating_efficiency_percent = 0.8
    hpxml.heating_systems[0].fan_watts = 0.0
  elsif ['base-hvac-floor-furnace-propane-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeFloorFurnace
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypePropane
    hpxml.heating_systems[0].heating_efficiency_afue = 0.8
    hpxml.heating_systems[0].fan_watts = 0.0
  elsif ['base-hvac-portable-heater-gas-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypePortableHeater
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeNaturalGas
    hpxml.heating_systems[0].heating_efficiency_afue = nil
    hpxml.heating_systems[0].heating_efficiency_percent = 1.0
    hpxml.heating_systems[0].fan_watts = 0.0
  elsif ['base-hvac-fixed-heater-gas-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeFixedHeater
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeNaturalGas
    hpxml.heating_systems[0].heating_efficiency_afue = nil
    hpxml.heating_systems[0].heating_efficiency_percent = 1.0
    hpxml.heating_systems[0].fan_watts = 0.0
  elsif ['base-hvac-stove-oil-only.xml',
         'base-hvac-stove-wood-pellets-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeStove
    hpxml.heating_systems[0].heating_efficiency_afue = nil
    hpxml.heating_systems[0].heating_efficiency_percent = 0.8
    hpxml.heating_systems[0].fan_watts = 40.0
    if hpxml_file == 'base-hvac-stove-oil-only.xml'
      hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeOil
    elsif hpxml_file == 'base-hvac-stove-wood-pellets-only.xml'
      hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeWoodPellets
    end
  elsif ['base-hvac-wall-furnace-elec-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeWallFurnace
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeElectricity
    hpxml.heating_systems[0].heating_efficiency_afue = 0.98
    hpxml.heating_systems[0].fan_watts = 0.0
  elsif ['base-hvac-furnace-x3-dse.xml'].include? hpxml_file
    hpxml.heating_systems << hpxml.heating_systems[0].dup
    hpxml.heating_systems << hpxml.heating_systems[1].dup
    hpxml.heating_systems[1].id = 'HeatingSystem2'
    hpxml.heating_systems[1].distribution_system_idref = 'HVACDistribution2'
    hpxml.heating_systems[2].id = 'HeatingSystem3'
    hpxml.heating_systems[2].distribution_system_idref = 'HVACDistribution3'
    for i in 0..2
      hpxml.heating_systems[i].heating_capacity /= 3.0
      # Test a file where sum is slightly greater than 1
      if i < 2
        hpxml.heating_systems[i].fraction_heat_load_served = 0.33
      else
        hpxml.heating_systems[i].fraction_heat_load_served = 0.35
      end
    end
  elsif ['base-hvac-furnace-elec-central-ac-1-speed.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_fuel = HPXML::FuelTypeElectricity
    hpxml.heating_systems[0].heating_efficiency_afue = 1.0
  elsif ['invalid_files/unattached-hvac-distribution.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = 'foobar'
  elsif ['invalid_files/hvac-invalid-distribution-system-type.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = 'HVACDistribution2'
  elsif ['invalid_files/hvac-dse-multiple-attached-heating.xml'].include? hpxml_file
    hpxml.heating_systems[0].fraction_heat_load_served = 0.5
    hpxml.heating_systems << hpxml.heating_systems[0].dup
    hpxml.heating_systems[1].id += '2'
  elsif ['invalid_files/hvac-inconsistent-fan-powers.xml'].include? hpxml_file
    hpxml.heating_systems[0].fan_watts_per_cfm = 0.45
  elsif ['base-hvac-undersized.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_capacity /= 10.0
  elsif ['base-bldgtype-multifamily-shared-boiler-only-baseboard.xml',
         'base-bldgtype-multifamily-shared-boiler-chiller-baseboard.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = HPXML::HVACTypeBoiler
    hpxml.heating_systems[0].is_shared_system = true
    hpxml.heating_systems[0].number_of_units_served = 6
    hpxml.heating_systems[0].heating_capacity = nil
    hpxml.heating_systems[0].shared_loop_watts = 600
  elsif ['base-bldgtype-multifamily-shared-boiler-only-fan-coil.xml',
         'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil.xml'].include? hpxml_file
    hpxml.heating_systems[0].fan_coil_watts = 150
  elsif ['base-bldgtype-multifamily-shared-boiler-only-fan-coil-eae.xml'].include? hpxml_file
    hpxml.heating_systems[0].fan_coil_watts = nil
    hpxml.heating_systems[0].shared_loop_watts = nil
    hpxml.heating_systems[0].electric_auxiliary_energy = 500.0
  elsif ['base-hvac-install-quality-furnace-gas-only.xml',
         'base-hvac-install-quality-furnace-gas-central-ac-1-speed.xml',
         'base-hvac-install-quality-furnace-gas-central-ac-2-speed.xml',
         'base-hvac-install-quality-furnace-gas-central-ac-var-speed.xml'].include? hpxml_file
    hpxml.heating_systems[0].fan_watts_per_cfm = 0.365
    hpxml.heating_systems[0].airflow_defect_ratio = -0.25
  elsif ['invalid_files/multiple-shared-heating-systems.xml'].include? hpxml_file
    hpxml.heating_systems[0].fraction_heat_load_served = 0.5
    hpxml.heating_systems << hpxml.heating_systems[0].dup
    hpxml.heating_systems[1].id += '2'
    hpxml.heating_systems[1].distribution_system_idref += '2'
  elsif ['invalid_files/boiler-invalid-afue.xml',
         'invalid_files/furnace-invalid-afue.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_efficiency_afue *= 100.0
  elsif ['base-location-honolulu-hi.xml',
         'base-location-miami-fl.xml',
         'base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_capacity = 12000
  elsif ['base-location-dallas-tx.xml',
         'base-location-baltimore-md.xml',
         'base-location-phoenix-az.xml',
         'base-location-portland-or.xml',
         'base-bldgtype-single-family-attached.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_capacity = 24000
  elsif ['base-location-helena-mt.xml',
         'base-enclosure-2stories.xml',
         'base-enclosure-2stories-garage.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_capacity = 48000
  elsif hpxml_file.include?('base-hvac-autosize') && (not hpxml.heating_systems.nil?) && (hpxml.heating_systems.size > 0)
    hpxml.heating_systems[0].heating_capacity = nil
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_efficiency_afue = nil
    hpxml.heating_systems[0].year_installed = 2009
  end
end

def set_hpxml_cooling_systems(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.cooling_systems.add(id: 'CoolingSystem',
                              distribution_system_idref: 'HVACDistribution',
                              cooling_system_type: HPXML::HVACTypeCentralAirConditioner,
                              cooling_system_fuel: HPXML::FuelTypeElectricity,
                              cooling_capacity: 24000,
                              fraction_cool_load_served: 1,
                              cooling_efficiency_seer: 13,
                              cooling_shr: 0.73,
                              compressor_type: HPXML::HVACCompressorTypeSingleStage)
  elsif ['base-hvac-air-to-air-heat-pump-1-speed.xml',
         'base-hvac-air-to-air-heat-pump-2-speed.xml',
         'base-hvac-air-to-air-heat-pump-var-speed.xml',
         'base-hvac-boiler-coal-only.xml',
         'base-hvac-boiler-elec-only.xml',
         'base-hvac-boiler-gas-only.xml',
         'base-hvac-boiler-oil-only.xml',
         'base-hvac-boiler-propane-only.xml',
         'base-hvac-boiler-wood-only.xml',
         'base-hvac-elec-resistance-only.xml',
         'base-hvac-fireplace-wood-only.xml',
         'base-hvac-fixed-heater-gas-only.xml',
         'base-hvac-floor-furnace-propane-only.xml',
         'base-hvac-furnace-coal-only.xml',
         'base-hvac-furnace-elec-only.xml',
         'base-hvac-furnace-gas-only.xml',
         'base-hvac-furnace-oil-only.xml',
         'base-hvac-furnace-propane-only.xml',
         'base-hvac-furnace-wood-only.xml',
         'base-hvac-ground-to-air-heat-pump.xml',
         'base-hvac-mini-split-heat-pump-ducted.xml',
         'base-hvac-none.xml',
         'base-hvac-portable-heater-gas-only.xml',
         'base-hvac-stove-oil-only.xml',
         'base-hvac-stove-wood-pellets-only.xml',
         'base-hvac-wall-furnace-elec-only.xml',
         'base-bldgtype-multifamily-shared-boiler-only-baseboard.xml',
         'base-bldgtype-multifamily-shared-ground-loop-ground-to-air-heat-pump.xml'].include? hpxml_file
    hpxml.cooling_systems.clear
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    hpxml.cooling_systems[0].distribution_system_idref = 'HVACDistribution2'
  elsif ['base-hvac-furnace-gas-central-ac-2-speed.xml',
         'base-hvac-central-ac-only-2-speed.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_efficiency_seer = 18
    hpxml.cooling_systems[0].cooling_shr = 0.73
    hpxml.cooling_systems[0].compressor_type = HPXML::HVACCompressorTypeTwoStage
  elsif ['base-hvac-furnace-gas-central-ac-var-speed.xml',
         'base-hvac-central-ac-only-var-speed.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_efficiency_seer = 24
    hpxml.cooling_systems[0].cooling_shr = 0.78
    hpxml.cooling_systems[0].compressor_type = HPXML::HVACCompressorTypeVariableSpeed
  elsif ['base-hvac-mini-split-air-conditioner-only-ducted.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_system_type = HPXML::HVACTypeMiniSplitAirConditioner
    hpxml.cooling_systems[0].cooling_efficiency_seer = 19
    hpxml.cooling_systems[0].cooling_shr = 0.73
    hpxml.cooling_systems[0].compressor_type = nil
  elsif ['base-hvac-mini-split-air-conditioner-only-ductless.xml'].include? hpxml_file
    hpxml.cooling_systems[0].distribution_system_idref = nil
  elsif ['base-hvac-furnace-gas-room-ac.xml',
         'base-hvac-room-ac-only.xml'].include? hpxml_file
    hpxml.cooling_systems[0].distribution_system_idref = nil
    hpxml.cooling_systems[0].cooling_system_type = HPXML::HVACTypeRoomAirConditioner
    hpxml.cooling_systems[0].cooling_efficiency_seer = nil
    hpxml.cooling_systems[0].cooling_efficiency_eer = 8.5
    hpxml.cooling_systems[0].cooling_shr = 0.65
    hpxml.cooling_systems[0].compressor_type = nil
  elsif ['base-hvac-room-ac-only-33percent.xml'].include? hpxml_file
    hpxml.cooling_systems[0].fraction_cool_load_served = 0.33
    hpxml.cooling_systems[0].cooling_capacity /= 3.0
  elsif ['base-hvac-room-ac-only-ceer.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_efficiency_eer = nil
    hpxml.cooling_systems[0].cooling_efficiency_ceer = 8.4
  elsif ['base-hvac-evap-cooler-only-ducted.xml',
         'base-hvac-evap-cooler-furnace-gas.xml',
         'base-hvac-evap-cooler-only.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_system_type = HPXML::HVACTypeEvaporativeCooler
    hpxml.cooling_systems[0].cooling_efficiency_seer = nil
    hpxml.cooling_systems[0].cooling_efficiency_eer = nil
    hpxml.cooling_systems[0].cooling_shr = nil
    hpxml.cooling_systems[0].compressor_type = nil
    if ['base-hvac-evap-cooler-furnace-gas.xml',
        'base-hvac-evap-cooler-only.xml'].include? hpxml_file
      hpxml.cooling_systems[0].distribution_system_idref = nil
    end
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    hpxml.cooling_systems[0].distribution_system_idref = 'HVACDistribution2'
    hpxml.cooling_systems[0].fraction_cool_load_served = 0.2
    hpxml.cooling_systems[0].cooling_capacity *= 0.2
    hpxml.cooling_systems.add(id: 'CoolingSystem2',
                              cooling_system_type: HPXML::HVACTypeRoomAirConditioner,
                              cooling_system_fuel: HPXML::FuelTypeElectricity,
                              cooling_capacity: 9600,
                              fraction_cool_load_served: 0.2,
                              cooling_efficiency_eer: 8.5,
                              cooling_shr: 0.65)
  elsif ['base-mechvent-multiple.xml',
         'base-bldgtype-multifamily-shared-mechvent-multiple.xml'].include? hpxml_file
    hpxml.cooling_systems[0].fraction_cool_load_served /= 2.0
    hpxml.cooling_systems[0].cooling_capacity /= 2.0
    hpxml.cooling_systems << hpxml.cooling_systems[0].dup
    hpxml.cooling_systems[1].id += '2'
    hpxml.cooling_systems[1].distribution_system_idref = 'HVACDistribution2'
  elsif ['invalid_files/hvac-frac-load-served.xml'].include? hpxml_file
    hpxml.cooling_systems[0].fraction_cool_load_served += 0.2
  elsif ['invalid_files/hvac-dse-multiple-attached-cooling.xml'].include? hpxml_file
    hpxml.cooling_systems[0].fraction_cool_load_served = 0.5
    hpxml.cooling_systems << hpxml.cooling_systems[0].dup
    hpxml.cooling_systems[1].id += '2'
  elsif ['invalid_files/hvac-inconsistent-fan-powers.xml'].include? hpxml_file
    hpxml.cooling_systems[0].fan_watts_per_cfm = 0.55
  elsif ['base-hvac-undersized.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_capacity /= 10.0
  elsif ['base-hvac-install-quality-mini-split-air-conditioner-only-ducted.xml',
         'base-hvac-install-quality-furnace-gas-central-ac-1-speed.xml',
         'base-hvac-install-quality-furnace-gas-central-ac-2-speed.xml',
         'base-hvac-install-quality-furnace-gas-central-ac-var-speed.xml'].include? hpxml_file
    hpxml.cooling_systems[0].charge_defect_ratio = -0.25
    hpxml.cooling_systems[0].fan_watts_per_cfm = 0.365
    hpxml.cooling_systems[0].airflow_defect_ratio = -0.25
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_shr = nil
    hpxml.cooling_systems[0].compressor_type = nil
    hpxml.cooling_systems[0].cooling_efficiency_seer = nil
    hpxml.cooling_systems[0].year_installed = 2009
  elsif ['base-bldgtype-multifamily-shared-chiller-only-baseboard.xml',
         'base-bldgtype-multifamily-shared-boiler-chiller-baseboard.xml',
         'base-bldgtype-multifamily-shared-chiller-only-water-loop-heat-pump.xml',
         'base-bldgtype-multifamily-shared-boiler-chiller-water-loop-heat-pump.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_system_type = HPXML::HVACTypeChiller
    hpxml.cooling_systems[0].is_shared_system = true
    hpxml.cooling_systems[0].number_of_units_served = 6
    hpxml.cooling_systems[0].cooling_capacity = 24000 * 6
    hpxml.cooling_systems[0].compressor_type = nil
    hpxml.cooling_systems[0].cooling_efficiency_kw_per_ton = 0.9
    hpxml.cooling_systems[0].cooling_shr = nil
    hpxml.cooling_systems[0].shared_loop_watts = 600
  elsif ['base-bldgtype-multifamily-shared-cooling-tower-only-water-loop-heat-pump.xml',
         'base-bldgtype-multifamily-shared-boiler-cooling-tower-water-loop-heat-pump.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_system_type = HPXML::HVACTypeCoolingTower
    hpxml.cooling_systems[0].cooling_capacity = nil
    hpxml.cooling_systems[0].cooling_efficiency_kw_per_ton = nil
  elsif ['base-bldgtype-multifamily-shared-chiller-only-fan-coil.xml',
         'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil.xml'].include? hpxml_file
    hpxml.cooling_systems[0].fan_coil_watts = 150
  elsif ['invalid_files/multiple-shared-cooling-systems.xml'].include? hpxml_file
    hpxml.cooling_systems[0].fraction_cool_load_served = 0.5
    hpxml.cooling_systems << hpxml.cooling_systems[0].dup
    hpxml.cooling_systems[1].id += '2'
    hpxml.cooling_systems[1].distribution_system_idref += '2'
  elsif ['invalid_files/hvac-shared-negative-seer-eq.xml'].include? hpxml_file
    hpxml.cooling_systems[0].shared_loop_watts *= 100.0
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_capacity = 12000
  elsif ['base-enclosure-2stories.xml',
         'base-enclosure-2stories-garage.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_capacity = 36000
  elsif hpxml_file.include?('base-hvac-autosize') && (not hpxml.cooling_systems.nil?) && (hpxml.cooling_systems.size > 0)
    hpxml.cooling_systems[0].cooling_capacity = nil
  end
end

def set_hpxml_heat_pumps(hpxml_file, hpxml)
  if ['base-hvac-air-to-air-heat-pump-1-speed.xml',
      'base-hvac-central-ac-plus-air-to-air-heat-pump-heating.xml'].include? hpxml_file
    hpxml.heat_pumps.add(id: 'HeatPump',
                         distribution_system_idref: 'HVACDistribution',
                         heat_pump_type: HPXML::HVACTypeHeatPumpAirToAir,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         heating_capacity: 36000,
                         cooling_capacity: 36000,
                         backup_heating_fuel: HPXML::FuelTypeElectricity,
                         backup_heating_capacity: 36000,
                         backup_heating_efficiency_percent: 1.0,
                         fraction_heat_load_served: 1,
                         fraction_cool_load_served: 1,
                         heating_efficiency_hspf: 7.7,
                         cooling_efficiency_seer: 13,
                         heating_capacity_17F: 36000 * 0.630, # Based on OAT slope of default curves
                         cooling_shr: 0.73,
                         compressor_type: HPXML::HVACCompressorTypeSingleStage)
    if hpxml_file == 'base-hvac-central-ac-plus-air-to-air-heat-pump-heating.xml'
      hpxml.heat_pumps[0].fraction_cool_load_served = 0
    end
  elsif ['base-hvac-air-to-air-heat-pump-2-speed.xml'].include? hpxml_file
    hpxml.heat_pumps.add(id: 'HeatPump',
                         distribution_system_idref: 'HVACDistribution',
                         heat_pump_type: HPXML::HVACTypeHeatPumpAirToAir,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         heating_capacity: 36000,
                         cooling_capacity: 36000,
                         backup_heating_fuel: HPXML::FuelTypeElectricity,
                         backup_heating_capacity: 36000,
                         backup_heating_efficiency_percent: 1.0,
                         fraction_heat_load_served: 1,
                         fraction_cool_load_served: 1,
                         heating_efficiency_hspf: 9.3,
                         cooling_efficiency_seer: 18,
                         heating_capacity_17F: 36000 * 0.590, # Based on OAT slope of default curves
                         cooling_shr: 0.73,
                         compressor_type: HPXML::HVACCompressorTypeTwoStage)
  elsif ['base-hvac-air-to-air-heat-pump-var-speed.xml'].include? hpxml_file
    hpxml.heat_pumps.add(id: 'HeatPump',
                         distribution_system_idref: 'HVACDistribution',
                         heat_pump_type: HPXML::HVACTypeHeatPumpAirToAir,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         heating_capacity: 36000,
                         cooling_capacity: 36000,
                         backup_heating_fuel: HPXML::FuelTypeElectricity,
                         backup_heating_capacity: 36000,
                         backup_heating_efficiency_percent: 1.0,
                         fraction_heat_load_served: 1,
                         fraction_cool_load_served: 1,
                         heating_efficiency_hspf: 10,
                         cooling_efficiency_seer: 22,
                         heating_capacity_17F: 36000 * 0.640, # Based on OAT slope of default curves
                         cooling_shr: 0.78,
                         compressor_type: HPXML::HVACCompressorTypeVariableSpeed)
  elsif ['base-hvac-ground-to-air-heat-pump.xml',
         'base-bldgtype-multifamily-shared-ground-loop-ground-to-air-heat-pump.xml'].include? hpxml_file
    hpxml.heat_pumps.add(id: 'HeatPump',
                         distribution_system_idref: 'HVACDistribution',
                         heat_pump_type: HPXML::HVACTypeHeatPumpGroundToAir,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         backup_heating_fuel: HPXML::FuelTypeElectricity,
                         backup_heating_efficiency_percent: 1.0,
                         fraction_heat_load_served: 1,
                         fraction_cool_load_served: 1,
                         heating_efficiency_cop: 3.6,
                         cooling_efficiency_eer: 16.6,
                         cooling_shr: 0.73,
                         pump_watts_per_ton: 30.0)
    if hpxml_file == 'base-bldgtype-multifamily-shared-ground-loop-ground-to-air-heat-pump.xml'
      hpxml.heat_pumps[-1].is_shared_system = true
      hpxml.heat_pumps[-1].number_of_units_served = 6
      hpxml.heat_pumps[-1].shared_loop_watts = 600
      hpxml.heat_pumps[-1].pump_watts_per_ton = 0.0
      hpxml.heat_pumps[-1].heating_capacity = 12000
      hpxml.heat_pumps[-1].cooling_capacity = 12000
      hpxml.heat_pumps[-1].backup_heating_capacity = 12000
    else
      hpxml.heat_pumps[-1].heating_capacity = 36000
      hpxml.heat_pumps[-1].cooling_capacity = 36000
      hpxml.heat_pumps[-1].backup_heating_capacity = 36000
    end
  elsif ['base-hvac-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    f = 1.0 - (1.0 - 0.25) / (47.0 + 5.0) * (47.0 - 17.0)
    hpxml.heat_pumps.add(id: 'HeatPump',
                         distribution_system_idref: 'HVACDistribution',
                         heat_pump_type: HPXML::HVACTypeHeatPumpMiniSplit,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         heating_capacity: 36000,
                         cooling_capacity: 36000,
                         backup_heating_fuel: HPXML::FuelTypeElectricity,
                         backup_heating_capacity: 36000,
                         backup_heating_efficiency_percent: 1.0,
                         fraction_heat_load_served: 1,
                         fraction_cool_load_served: 1,
                         heating_efficiency_hspf: 10,
                         cooling_efficiency_seer: 19,
                         heating_capacity_17F: (36000 * f).round(0),
                         cooling_shr: 0.73)
  elsif ['base-hvac-air-to-air-heat-pump-1-speed-heating-only.xml',
         'base-hvac-ground-to-air-heat-pump-heating-only.xml',
         'base-hvac-mini-split-heat-pump-ducted-heating-only.xml'].include? hpxml_file
    hpxml.heat_pumps[0].cooling_capacity = 0
    hpxml.heat_pumps[0].fraction_cool_load_served = 0
  elsif ['base-hvac-air-to-air-heat-pump-1-speed-cooling-only.xml',
         'base-hvac-ground-to-air-heat-pump-cooling-only.xml',
         'base-hvac-mini-split-heat-pump-ducted-cooling-only.xml'].include? hpxml_file
    hpxml.heat_pumps[0].heating_capacity = 0
    if hpxml_file != 'base-hvac-ground-to-air-heat-pump-cooling-only.xml'
      hpxml.heat_pumps[0].heating_capacity_17F = 0
    end
    hpxml.heat_pumps[0].fraction_heat_load_served = 0
    hpxml.heat_pumps[0].backup_heating_fuel = nil
    hpxml.heat_pumps[0].backup_heating_capacity = nil
    hpxml.heat_pumps[0].backup_heating_efficiency_percent = nil
  elsif ['base-hvac-mini-split-heat-pump-ductless.xml'].include? hpxml_file
    hpxml.heat_pumps[0].distribution_system_idref = nil
    hpxml.heat_pumps[0].backup_heating_fuel = nil
    hpxml.heat_pumps[0].backup_heating_capacity = nil
    hpxml.heat_pumps[0].backup_heating_efficiency_percent = nil
  elsif ['invalid_files/heat-pump-mixed-fixed-and-autosize-capacities.xml'].include? hpxml_file
    hpxml.heat_pumps[0].cooling_capacity = nil
    hpxml.heat_pumps[0].heating_capacity = nil
    hpxml.heat_pumps[0].heating_capacity_17F = 25000
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    hpxml.heat_pumps.add(id: 'HeatPump',
                         distribution_system_idref: 'HVACDistribution5',
                         heat_pump_type: HPXML::HVACTypeHeatPumpAirToAir,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         heating_capacity: 4800,
                         cooling_capacity: 4800,
                         backup_heating_fuel: HPXML::FuelTypeElectricity,
                         backup_heating_capacity: 3412,
                         backup_heating_efficiency_percent: 1.0,
                         fraction_heat_load_served: 0.1,
                         fraction_cool_load_served: 0.2,
                         heating_efficiency_hspf: 7.7,
                         cooling_efficiency_seer: 13,
                         heating_capacity_17F: 4800 * 0.630, # Based on OAT slope of default curves
                         cooling_shr: 0.73,
                         compressor_type: HPXML::HVACCompressorTypeSingleStage)
    hpxml.heat_pumps.add(id: 'HeatPump2',
                         distribution_system_idref: 'HVACDistribution6',
                         heat_pump_type: HPXML::HVACTypeHeatPumpGroundToAir,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         heating_capacity: 4800,
                         cooling_capacity: 4800,
                         backup_heating_fuel: HPXML::FuelTypeElectricity,
                         backup_heating_capacity: 3412,
                         backup_heating_efficiency_percent: 1.0,
                         fraction_heat_load_served: 0.1,
                         fraction_cool_load_served: 0.2,
                         heating_efficiency_cop: 3.6,
                         cooling_efficiency_eer: 16.6,
                         cooling_shr: 0.73,
                         pump_watts_per_ton: 30.0)
    f = 1.0 - (1.0 - 0.25) / (47.0 + 5.0) * (47.0 - 17.0)
    hpxml.heat_pumps.add(id: 'HeatPump3',
                         heat_pump_type: HPXML::HVACTypeHeatPumpMiniSplit,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         heating_capacity: 4800,
                         cooling_capacity: 4800,
                         backup_heating_fuel: HPXML::FuelTypeElectricity,
                         backup_heating_capacity: 3412,
                         backup_heating_efficiency_percent: 1.0,
                         fraction_heat_load_served: 0.1,
                         fraction_cool_load_served: 0.2,
                         heating_efficiency_hspf: 10,
                         cooling_efficiency_seer: 19,
                         heating_capacity_17F: 4800 * f,
                         cooling_shr: 0.73)
  elsif ['base-bldgtype-multifamily-shared-boiler-only-water-loop-heat-pump.xml',
         'base-bldgtype-multifamily-shared-chiller-only-water-loop-heat-pump.xml',
         'base-bldgtype-multifamily-shared-boiler-chiller-water-loop-heat-pump.xml'].include? hpxml_file
    hpxml.heat_pumps.add(id: 'WLHP',
                         distribution_system_idref: 'HVACDistributionWLHP',
                         heat_pump_type: HPXML::HVACTypeHeatPumpWaterLoopToAir,
                         heat_pump_fuel: HPXML::FuelTypeElectricity)
    if hpxml_file.include? 'boiler'
      hpxml.heat_pumps[-1].heating_capacity = 24000
      hpxml.heat_pumps[-1].heating_efficiency_cop = 4.4
    end
    if hpxml_file.include? 'chiller'
      hpxml.heat_pumps[-1].cooling_capacity = 24000
      hpxml.heat_pumps[-1].cooling_efficiency_eer = 12.8
    end
  elsif ['invalid_files/hvac-distribution-multiple-attached-heating.xml'].include? hpxml_file
    hpxml.heat_pumps[0].distribution_system_idref = 'HVACDistribution'
  elsif ['invalid_files/hvac-distribution-multiple-attached-cooling.xml'].include? hpxml_file
    hpxml.heat_pumps[0].distribution_system_idref = 'HVACDistribution2'
  elsif ['base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml',
         'base-hvac-dual-fuel-air-to-air-heat-pump-2-speed.xml',
         'base-hvac-dual-fuel-air-to-air-heat-pump-var-speed.xml',
         'base-hvac-dual-fuel-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    hpxml.heat_pumps[0].backup_heating_fuel = HPXML::FuelTypeNaturalGas
    hpxml.heat_pumps[0].backup_heating_capacity = 36000
    hpxml.heat_pumps[0].backup_heating_efficiency_percent = nil
    hpxml.heat_pumps[0].backup_heating_efficiency_afue = 0.95
    hpxml.heat_pumps[0].backup_heating_switchover_temp = 25
  elsif ['base-hvac-dual-fuel-air-to-air-heat-pump-1-speed-electric.xml'].include? hpxml_file
    hpxml.heat_pumps[0].backup_heating_fuel = HPXML::FuelTypeElectricity
    hpxml.heat_pumps[0].backup_heating_efficiency_afue = 1.0
  elsif ['base-hvac-install-quality-air-to-air-heat-pump-1-speed.xml',
         'base-hvac-install-quality-air-to-air-heat-pump-2-speed.xml',
         'base-hvac-install-quality-air-to-air-heat-pump-var-speed.xml',
         'base-hvac-install-quality-mini-split-heat-pump-ducted.xml',
         'base-hvac-install-quality-ground-to-air-heat-pump.xml'].include? hpxml_file
    hpxml.heat_pumps[0].airflow_defect_ratio = -0.25
    hpxml.heat_pumps[0].fan_watts_per_cfm = 0.365
    hpxml.heat_pumps[0].charge_defect_ratio = -0.25
  elsif hpxml_file.include?('base-hvac-autosize') && (not hpxml.heat_pumps.nil?) && (hpxml.heat_pumps.size > 0)
    hpxml.heat_pumps[0].cooling_capacity = nil
    hpxml.heat_pumps[0].heating_capacity = nil
    hpxml.heat_pumps[0].heating_capacity_17F = nil
    hpxml.heat_pumps[0].backup_heating_capacity = nil
  end
end

def set_hpxml_hvac_control(hpxml_file, hpxml)
  if ['ASHRAE_Standard_140/L100AC.xml',
      'ASHRAE_Standard_140/L100AL.xml'].include? hpxml_file
    hpxml.hvac_controls.add(id: 'HVACControl',
                            heating_setpoint_temp: 68,
                            cooling_setpoint_temp: 78)
  elsif ['base.xml'].include? hpxml_file
    hpxml.hvac_controls.add(id: 'HVACControl',
                            control_type: HPXML::HVACControlTypeManual,
                            heating_setpoint_temp: 68,
                            cooling_setpoint_temp: 78)
  elsif ['base-hvac-seasons.xml'].include? hpxml_file
    hpxml.hvac_controls[0].seasons_heating_begin_month = 11
    hpxml.hvac_controls[0].seasons_heating_begin_day = 1
    hpxml.hvac_controls[0].seasons_heating_end_month = 6
    hpxml.hvac_controls[0].seasons_heating_end_day = 30
    hpxml.hvac_controls[0].seasons_cooling_begin_month = 6
    hpxml.hvac_controls[0].seasons_cooling_begin_day = 1
    hpxml.hvac_controls[0].seasons_cooling_end_month = 10
    hpxml.hvac_controls[0].seasons_cooling_end_day = 31
  elsif ['base-hvac-none.xml'].include? hpxml_file
    hpxml.hvac_controls.clear
  elsif ['base-hvac-programmable-thermostat.xml'].include? hpxml_file
    hpxml.hvac_controls[0].control_type = HPXML::HVACControlTypeProgrammable
    hpxml.hvac_controls[0].heating_setback_temp = 66
    hpxml.hvac_controls[0].heating_setback_hours_per_week = 7 * 7
    hpxml.hvac_controls[0].heating_setback_start_hour = 23 # 11pm
    hpxml.hvac_controls[0].cooling_setup_temp = 80
    hpxml.hvac_controls[0].cooling_setup_hours_per_week = 6 * 7
    hpxml.hvac_controls[0].cooling_setup_start_hour = 9 # 9am
  elsif ['base-hvac-programmable-thermostat-detailed.xml'].include? hpxml_file
    hpxml.hvac_controls[0].control_type = HPXML::HVACControlTypeProgrammable
    hpxml.hvac_controls[0].heating_setpoint_temp = nil
    hpxml.hvac_controls[0].cooling_setpoint_temp = nil
    hpxml.hvac_controls[0].weekday_heating_setpoints = '64, 64, 64, 64, 64, 64, 64, 70, 70, 66, 66, 66, 66, 66, 66, 66, 66, 68, 68, 68, 68, 68, 64, 64'
    hpxml.hvac_controls[0].weekend_heating_setpoints = '68, 68, 68, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70'
    hpxml.hvac_controls[0].weekday_cooling_setpoints = '80, 80, 80, 80, 80, 80, 80, 75, 75, 80, 80, 80, 80, 80, 80, 80, 80, 78, 78, 78, 78, 78, 80, 80'
    hpxml.hvac_controls[0].weekend_cooling_setpoints = '78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78'
  elsif ['base-hvac-setpoints.xml'].include? hpxml_file
    hpxml.hvac_controls[0].heating_setpoint_temp = 60
    hpxml.hvac_controls[0].cooling_setpoint_temp = 80
  elsif ['base-lighting-ceiling-fans.xml'].include? hpxml_file
    hpxml.hvac_controls[0].ceiling_fan_cooling_setpoint_temp_offset = 0.5
  elsif ['invalid_files/hvac-seasons-less-than-a-year.xml'].include? hpxml_file
    hpxml.hvac_controls[0].seasons_heating_begin_month = 10
    hpxml.hvac_controls[0].seasons_heating_begin_day = 1
    hpxml.hvac_controls[0].seasons_heating_end_month = 5
    hpxml.hvac_controls[0].seasons_heating_end_day = 31
    hpxml.hvac_controls[0].seasons_cooling_begin_month = 7
    hpxml.hvac_controls[0].seasons_cooling_begin_day = 1
    hpxml.hvac_controls[0].seasons_cooling_end_month = 9
    hpxml.hvac_controls[0].seasons_cooling_end_day = 30
  end
end

def set_hpxml_hvac_distributions(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.hvac_distributions.add(id: 'HVACDistribution',
                                 distribution_system_type: HPXML::HVACDistributionTypeAir,
                                 air_type: HPXML::AirTypeRegularVelocity)
    hpxml.hvac_distributions[0].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                              duct_leakage_units: HPXML::UnitsCFM25,
                                                              duct_leakage_value: 75,
                                                              duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
    hpxml.hvac_distributions[0].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                              duct_leakage_units: HPXML::UnitsCFM25,
                                                              duct_leakage_value: 25,
                                                              duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
    hpxml.hvac_distributions[0].ducts.add(duct_type: HPXML::DuctTypeSupply,
                                          duct_insulation_r_value: 4,
                                          duct_location: HPXML::LocationAtticUnvented,
                                          duct_surface_area: 150)
    hpxml.hvac_distributions[0].ducts.add(duct_type: HPXML::DuctTypeReturn,
                                          duct_insulation_r_value: 0,
                                          duct_location: HPXML::LocationAtticUnvented,
                                          duct_surface_area: 50)
  elsif ['base-bldgtype-multifamily.xml'].include? hpxml_file
    hpxml.hvac_distributions.each do |hvac_distribution|
      hvac_distribution.duct_leakage_measurements.each do |duct_leakage_measurement|
        duct_leakage_measurement.duct_leakage_value = 0
      end
      hvac_distribution.ducts.each do |duct|
        duct.duct_location = HPXML::LocationLivingSpace
        duct.duct_insulation_r_value = 0
      end
    end
  elsif ['base-hvac-boiler-coal-only.xml',
         'base-hvac-boiler-elec-only.xml',
         'base-hvac-boiler-gas-only.xml',
         'base-hvac-boiler-oil-only.xml',
         'base-hvac-boiler-propane-only.xml',
         'base-hvac-boiler-wood-only.xml',
         'base-bldgtype-multifamily-shared-boiler-only-baseboard.xml',
         'base-bldgtype-multifamily-shared-chiller-only-baseboard.xml',
         'base-bldgtype-multifamily-shared-boiler-chiller-baseboard.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].distribution_system_type = HPXML::HVACDistributionTypeHydronic
    hpxml.hvac_distributions[0].duct_leakage_measurements.clear
    hpxml.hvac_distributions[0].ducts.clear
    hpxml.hvac_distributions[0].hydronic_type = HPXML::HydronicTypeBaseboard
  elsif ['base-bldgtype-multifamily-shared-boiler-only-fan-coil.xml',
         'base-bldgtype-multifamily-shared-chiller-only-fan-coil.xml',
         'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].distribution_system_type = HPXML::HVACDistributionTypeAir
    hpxml.hvac_distributions[0].air_type = HPXML::AirTypeFanCoil
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].distribution_system_type = HPXML::HVACDistributionTypeHydronic
    hpxml.hvac_distributions[0].hydronic_type = HPXML::HydronicTypeBaseboard
    hpxml.hvac_distributions[0].duct_leakage_measurements.clear
    hpxml.hvac_distributions[0].ducts.clear
    hpxml.hvac_distributions.add(id: 'HVACDistribution2',
                                 distribution_system_type: HPXML::HVACDistributionTypeAir,
                                 air_type: HPXML::AirTypeRegularVelocity)
    hpxml.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                               duct_leakage_units: HPXML::UnitsCFM25,
                                                               duct_leakage_value: 75,
                                                               duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
    hpxml.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                               duct_leakage_units: HPXML::UnitsCFM25,
                                                               duct_leakage_value: 25,
                                                               duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
    hpxml.hvac_distributions[-1].ducts.add(duct_type: HPXML::DuctTypeSupply,
                                           duct_insulation_r_value: 4,
                                           duct_location: HPXML::LocationAtticUnvented,
                                           duct_surface_area: 150)
    hpxml.hvac_distributions[-1].ducts.add(duct_type: HPXML::DuctTypeReturn,
                                           duct_insulation_r_value: 0,
                                           duct_location: HPXML::LocationAtticUnvented,
                                           duct_surface_area: 50)
  elsif ['base-hvac-none.xml',
         'base-hvac-elec-resistance-only.xml',
         'base-hvac-evap-cooler-only.xml',
         'base-hvac-fireplace-wood-only.xml',
         'base-hvac-floor-furnace-propane-only.xml',
         'base-hvac-fixed-heater-gas-only.xml',
         'base-hvac-mini-split-heat-pump-ductless.xml',
         'base-hvac-mini-split-air-conditioner-only-ductless.xml',
         'base-hvac-portable-heater-gas-only.xml',
         'base-hvac-room-ac-only.xml',
         'base-hvac-stove-oil-only.xml',
         'base-hvac-stove-wood-pellets-only.xml',
         'base-hvac-wall-furnace-elec-only.xml'].include? hpxml_file
    hpxml.hvac_distributions.clear
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    hpxml.hvac_distributions.clear
    hpxml.hvac_distributions.add(id: 'HVACDistribution',
                                 distribution_system_type: HPXML::HVACDistributionTypeAir,
                                 air_type: HPXML::AirTypeRegularVelocity)
    hpxml.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                               duct_leakage_units: HPXML::UnitsCFM25,
                                                               duct_leakage_value: 75,
                                                               duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
    hpxml.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                               duct_leakage_units: HPXML::UnitsCFM25,
                                                               duct_leakage_value: 25,
                                                               duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
    hpxml.hvac_distributions[0].ducts.add(duct_type: HPXML::DuctTypeSupply,
                                          duct_insulation_r_value: 8,
                                          duct_location: HPXML::LocationAtticUnvented,
                                          duct_surface_area: 75)
    hpxml.hvac_distributions[0].ducts.add(duct_type: HPXML::DuctTypeSupply,
                                          duct_insulation_r_value: 8,
                                          duct_location: HPXML::LocationOutside,
                                          duct_surface_area: 75)
    hpxml.hvac_distributions[0].ducts.add(duct_type: HPXML::DuctTypeReturn,
                                          duct_insulation_r_value: 4,
                                          duct_location: HPXML::LocationAtticUnvented,
                                          duct_surface_area: 25)
    hpxml.hvac_distributions[0].ducts.add(duct_type: HPXML::DuctTypeReturn,
                                          duct_insulation_r_value: 4,
                                          duct_location: HPXML::LocationOutside,
                                          duct_surface_area: 25)
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[-1].id = 'HVACDistribution2'
    hpxml.hvac_distributions.add(id: 'HVACDistribution3',
                                 distribution_system_type: HPXML::HVACDistributionTypeHydronic,
                                 hydronic_type: HPXML::HydronicTypeBaseboard)
    hpxml.hvac_distributions.add(id: 'HVACDistribution4',
                                 distribution_system_type: HPXML::HVACDistributionTypeHydronic,
                                 hydronic_type: HPXML::HydronicTypeBaseboard)
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[-1].id = 'HVACDistribution5'
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[-1].id = 'HVACDistribution6'
  elsif ['base-mechvent-multiple.xml',
         'base-bldgtype-multifamily-shared-mechvent-multiple.xml'].include? hpxml_file
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[1].id = 'HVACDistribution2'
  elsif ['base-hvac-dse.xml',
         'base-dhw-indirect-dse.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].distribution_system_type = HPXML::HVACDistributionTypeDSE
    hpxml.hvac_distributions[0].annual_heating_dse = 0.8
    hpxml.hvac_distributions[0].annual_cooling_dse = 0.7
  elsif ['base-hvac-furnace-x3-dse.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].distribution_system_type = HPXML::HVACDistributionTypeDSE
    hpxml.hvac_distributions[0].annual_heating_dse = 0.8
    hpxml.hvac_distributions[0].annual_cooling_dse = 0.7
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[1].id = 'HVACDistribution2'
    hpxml.hvac_distributions[1].annual_cooling_dse = 1.0
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[2].id = 'HVACDistribution3'
    hpxml.hvac_distributions[2].annual_cooling_dse = 1.0
  elsif ['base-hvac-mini-split-heat-pump-ducted.xml',
         'base-hvac-mini-split-air-conditioner-only-ducted.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value = 15
    hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value = 5
    hpxml.hvac_distributions[0].ducts[0].duct_insulation_r_value = 0
    hpxml.hvac_distributions[0].ducts[0].duct_surface_area = 30
    hpxml.hvac_distributions[0].ducts[1].duct_surface_area = 10
  elsif ['base-hvac-evap-cooler-only-ducted.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements[-1].duct_leakage_value = 0.0
    hpxml.hvac_distributions[0].ducts.pop
  elsif ['invalid_files/hvac-distribution-return-duct-leakage-missing.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements.pop
  elsif ['base-hvac-ducts-leakage-percent.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements.clear
    hpxml.hvac_distributions[0].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                              duct_leakage_units: HPXML::UnitsPercent,
                                                              duct_leakage_value: 0.1,
                                                              duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
    hpxml.hvac_distributions[0].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                              duct_leakage_units: HPXML::UnitsPercent,
                                                              duct_leakage_value: 0.05,
                                                              duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
  elsif ['base-hvac-undersized.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value /= 10.0
    hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value /= 10.0
  elsif ['base-foundation-ambient.xml',
         'base-foundation-multiple.xml',
         'base-foundation-slab.xml'].include? hpxml_file
    if hpxml_file == 'base-foundation-slab.xml'
      hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationUnderSlab
      hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationUnderSlab
    end
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationBasementUnconditioned
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationBasementUnconditioned
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationCrawlspaceUnvented
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationCrawlspaceUnvented
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationCrawlspaceVented
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationCrawlspaceVented
  elsif ['base-atticroof-flat.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value = 0.0
    hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value = 0.0
    hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationBasementConditioned
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationBasementConditioned
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationAtticVented
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationAtticVented
  elsif ['base-enclosure-garage.xml',
         'invalid_files/duct-location.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationGarage
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationGarage
  elsif ['invalid_files/duct-location-unconditioned-space.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = 'unconditioned space'
    hpxml.hvac_distributions[0].ducts[1].duct_location = 'unconditioned space'
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationOtherHousingUnit
    hpxml.hvac_distributions[0].ducts.add(duct_type: HPXML::DuctTypeSupply,
                                          duct_insulation_r_value: 4,
                                          duct_location: HPXML::LocationRoofDeck,
                                          duct_surface_area: 150)
    hpxml.hvac_distributions[0].ducts.add(duct_type: HPXML::DuctTypeReturn,
                                          duct_insulation_r_value: 0,
                                          duct_location: HPXML::LocationRoofDeck,
                                          duct_surface_area: 50)
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts << hpxml.hvac_distributions[0].ducts[0].dup
    hpxml.hvac_distributions[0].ducts << hpxml.hvac_distributions[0].ducts[1].dup
    hpxml.hvac_distributions[0].ducts[0].duct_surface_area *= 0.75
    hpxml.hvac_distributions[0].ducts[1].duct_surface_area *= 0.75
    hpxml.hvac_distributions[0].ducts[2].duct_location = HPXML::LocationExteriorWall
    hpxml.hvac_distributions[0].ducts[2].duct_surface_area *= 0.25
    hpxml.hvac_distributions[0].ducts[3].duct_location = HPXML::LocationLivingSpace
    hpxml.hvac_distributions[0].ducts[3].duct_surface_area *= 0.25
  elsif ['base-atticroof-conditioned.xml',
         'base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationLivingSpace
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationLivingSpace
    hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value = 0.0
    hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value = 0.0
    if hpxml_file == 'base-atticroof-conditioned.xml'
      # Test leakage to outside when all ducts in conditioned space
      # (e.g., ducts may be in floor cavities which have leaky rims)
      hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value = 50.0
      hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value = 100.0
    end
  elsif ['base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationOtherHousingUnit
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationOtherHousingUnit
  elsif ['base-bldgtype-multifamily-adjacent-to-other-heated-space.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationOtherHeatedSpace
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationOtherHeatedSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationOtherMultifamilyBufferSpace
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationOtherMultifamilyBufferSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationOtherNonFreezingSpace
    hpxml.hvac_distributions[0].ducts[1].duct_location = HPXML::LocationOtherNonFreezingSpace
  elsif ['base-bldgtype-multifamily-shared-boiler-only-water-loop-heat-pump.xml',
         'base-bldgtype-multifamily-shared-chiller-only-water-loop-heat-pump.xml',
         'base-bldgtype-multifamily-shared-boiler-chiller-water-loop-heat-pump.xml',
         'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil-ducted.xml',
         'base-bldgtype-multifamily-shared-boiler-only-fan-coil-ducted.xml',
         'base-bldgtype-multifamily-shared-chiller-only-fan-coil-ducted.xml'].include? hpxml_file
    if hpxml_file.include? 'fan-coil'
      hpxml.hvac_distributions[0].distribution_system_type = HPXML::HVACDistributionTypeAir
      hpxml.hvac_distributions[0].air_type = HPXML::AirTypeFanCoil
    elsif hpxml_file.include? 'water-loop-heat-pump'
      hpxml.hvac_distributions[0].distribution_system_type = HPXML::HVACDistributionTypeHydronic
      hpxml.hvac_distributions[0].hydronic_type = HPXML::HydronicTypeWaterLoop
      hpxml.hvac_distributions.add(id: 'HVACDistributionWLHP',
                                   distribution_system_type: HPXML::HVACDistributionTypeAir,
                                   air_type: HPXML::AirTypeRegularVelocity)
    end
    hpxml.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                               duct_leakage_units: HPXML::UnitsCFM25,
                                                               duct_leakage_value: 15,
                                                               duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
    hpxml.hvac_distributions[-1].duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                               duct_leakage_units: HPXML::UnitsCFM25,
                                                               duct_leakage_value: 10,
                                                               duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
    hpxml.hvac_distributions[-1].ducts.add(duct_type: HPXML::DuctTypeSupply,
                                           duct_insulation_r_value: 0,
                                           duct_location: HPXML::LocationOtherMultifamilyBufferSpace,
                                           duct_surface_area: 50)
    hpxml.hvac_distributions[-1].ducts.add(duct_type: HPXML::DuctTypeReturn,
                                           duct_insulation_r_value: 0,
                                           duct_location: HPXML::LocationOtherMultifamilyBufferSpace,
                                           duct_surface_area: 20)
  elsif ['invalid_files/hvac-invalid-distribution-system-type.xml'].include? hpxml_file
    hpxml.hvac_distributions.add(id: 'HVACDistribution2',
                                 distribution_system_type: HPXML::HVACDistributionTypeHydronic,
                                 hydronic_type: HPXML::HydronicTypeBaseboard)
  elsif ['invalid_files/hvac-distribution-return-duct-leakage-missing.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts.add(duct_type: HPXML::DuctTypeReturn,
                                          duct_insulation_r_value: 0,
                                          duct_location: HPXML::LocationAtticUnvented,
                                          duct_surface_area: 50)
  elsif ['base-hvac-ducts-area-fractions.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts.each do |d|
      d.duct_fraction_area = d.duct_surface_area / hpxml.hvac_distributions[0].ducts.select { |du| du.duct_type == d.duct_type }.map { |du| du.duct_surface_area }.sum
    end
    hpxml.hvac_distributions[0].ducts.each do |d|
      d.duct_surface_area = nil
    end
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.hvac_distributions.each do |hvac_distribution|
      next unless hvac_distribution.distribution_system_type == HPXML::HVACDistributionTypeAir

      hvac_distribution.ducts.each do |duct|
        duct.duct_surface_area = nil
        duct.duct_location = nil
      end
    end
  elsif ['invalid_files/invalid-duct-area-fractions.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts.each do |d|
      d.duct_fraction_area -= 0.1
    end
  elsif ['invalid_files/missing-duct-location.xml'].include? hpxml_file
    hpxml.hvac_distributions.each do |hvac_distribution|
      next unless hvac_distribution.distribution_system_type == HPXML::HVACDistributionTypeAir

      hvac_distribution.ducts[1].duct_location = nil
    end
  elsif ['invalid_files/missing-duct-area.xml'].include? hpxml_file
    hpxml.hvac_distributions.each do |hvac_distribution|
      next unless hvac_distribution.distribution_system_type == HPXML::HVACDistributionTypeAir

      hvac_distribution.ducts[1].duct_surface_area = nil
    end
  elsif ['invalid_files/multifamily-reference-duct.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = HPXML::LocationOtherMultifamilyBufferSpace
  elsif ['invalid_files/multiple-shared-cooling-systems.xml',
         'invalid_files/multiple-shared-heating-systems.xml'].include? hpxml_file
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[-1].id += '2'
  elsif ['invalid_files/duct-leakage-cfm25.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value = -2.0
    hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value = -2.0
  elsif ['invalid_files/duct-leakage-percent.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_units = HPXML::UnitsPercent
    hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_units = HPXML::UnitsPercent
  end

  # Set ConditionedFloorAreaServed
  if not hpxml_file.include?('invalid_files')
    n_htg_systems = (hpxml.heating_systems + hpxml.heat_pumps).select { |h| h.fraction_heat_load_served.to_f > 0 }.size
    n_clg_systems = (hpxml.cooling_systems + hpxml.heat_pumps).select { |h| h.fraction_cool_load_served.to_f > 0 }.size
    hpxml.hvac_distributions.each do |hvac_distribution|
      if [HPXML::HVACDistributionTypeAir].include?(hvac_distribution.distribution_system_type) && (hvac_distribution.ducts.size > 0)
        n_hvac_systems = [n_htg_systems, n_clg_systems].max
        hvac_distribution.conditioned_floor_area_served = hpxml.building_construction.conditioned_floor_area / n_hvac_systems
      else
        hvac_distribution.conditioned_floor_area_served = nil
      end
    end
  elsif ['invalid_files/invalid-distribution-cfa-served.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].conditioned_floor_area_served = hpxml.building_construction.conditioned_floor_area + 1.1
  end

  # Set number of return registers
  if not ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.hvac_distributions.each do |hvac_distribution|
      hvac_distribution.number_of_return_registers = nil
      next unless hvac_distribution.distribution_system_type == HPXML::HVACDistributionTypeAir

      if hvac_distribution.ducts.select { |d| d.duct_type == HPXML::DuctTypeReturn }.size > 0
        hvac_distribution.number_of_return_registers = hpxml.building_construction.number_of_conditioned_floors.ceil
      elsif hvac_distribution.ducts.select { |d| d.duct_type == HPXML::DuctTypeSupply }.size > 0
        # E.g., evap cooler w/ only supply ducts
        hvac_distribution.number_of_return_registers = 0
      end
    end
  end
end

def set_hpxml_ventilation_fans(hpxml_file, hpxml)
  if ['base-mechvent-balanced.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'MechanicalVentilation',
                               fan_type: HPXML::MechVentTypeBalanced,
                               tested_flow_rate: 110,
                               hours_in_operation: 24,
                               fan_power: 60,
                               used_for_whole_building_ventilation: true)
  elsif ['invalid_files/unattached-cfis.xml',
         'invalid_files/cfis-with-hydronic-distribution.xml',
         'base-mechvent-cfis.xml',
         'base-mechvent-cfis-dse.xml',
         'base-mechvent-cfis-evap-cooler-only-ducted.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'MechanicalVentilation',
                               fan_type: HPXML::MechVentTypeCFIS,
                               tested_flow_rate: 330,
                               hours_in_operation: 8,
                               fan_power: 300,
                               used_for_whole_building_ventilation: true,
                               distribution_system_idref: 'HVACDistribution')
    if ['invalid_files/unattached-cfis.xml'].include? hpxml_file
      hpxml.ventilation_fans[0].distribution_system_idref = 'foobar'
    end
  elsif ['base-mechvent-erv.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'MechanicalVentilation',
                               fan_type: HPXML::MechVentTypeERV,
                               tested_flow_rate: 110,
                               hours_in_operation: 24,
                               total_recovery_efficiency: 0.48,
                               sensible_recovery_efficiency: 0.72,
                               fan_power: 60,
                               used_for_whole_building_ventilation: true)
  elsif ['base-mechvent-erv-atre-asre.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'MechanicalVentilation',
                               fan_type: HPXML::MechVentTypeERV,
                               tested_flow_rate: 110,
                               hours_in_operation: 24,
                               total_recovery_efficiency_adjusted: 0.526,
                               sensible_recovery_efficiency_adjusted: 0.79,
                               fan_power: 60,
                               used_for_whole_building_ventilation: true)
  elsif ['base-mechvent-exhaust.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'MechanicalVentilation',
                               fan_type: HPXML::MechVentTypeExhaust,
                               tested_flow_rate: 110,
                               hours_in_operation: 24,
                               fan_power: 30,
                               used_for_whole_building_ventilation: true)
  elsif ['base-mechvent-exhaust-rated-flow-rate.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'MechanicalVentilation',
                               fan_type: HPXML::MechVentTypeExhaust,
                               rated_flow_rate: 110,
                               hours_in_operation: 24,
                               fan_power: 30,
                               used_for_whole_building_ventilation: true)
  elsif ['base-mechvent-hrv.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'MechanicalVentilation',
                               fan_type: HPXML::MechVentTypeHRV,
                               tested_flow_rate: 110,
                               hours_in_operation: 24,
                               sensible_recovery_efficiency: 0.72,
                               fan_power: 60,
                               used_for_whole_building_ventilation: true)
  elsif ['base-mechvent-hrv-asre.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'MechanicalVentilation',
                               fan_type: HPXML::MechVentTypeHRV,
                               tested_flow_rate: 110,
                               hours_in_operation: 24,
                               sensible_recovery_efficiency_adjusted: 0.790,
                               fan_power: 60,
                               used_for_whole_building_ventilation: true)
  elsif ['base-mechvent-supply.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'MechanicalVentilation',
                               fan_type: HPXML::MechVentTypeSupply,
                               tested_flow_rate: 110,
                               hours_in_operation: 24,
                               fan_power: 30,
                               used_for_whole_building_ventilation: true)
  elsif ['base-mechvent-whole-house-fan.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'WholeHouseFan',
                               rated_flow_rate: 4500,
                               fan_power: 300,
                               used_for_seasonal_cooling_load_reduction: true)
  elsif ['base-mechvent-bath-kitchen-fans.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'KitchenRangeFan',
                               quantity: 1,
                               fan_location: HPXML::LocationKitchen,
                               rated_flow_rate: 100,
                               fan_power: 30,
                               hours_in_operation: 1.5,
                               start_hour: 18,
                               used_for_local_ventilation: true)
    hpxml.ventilation_fans.add(id: 'BathFans',
                               fan_location: HPXML::LocationBath,
                               quantity: 2,
                               rated_flow_rate: 50,
                               fan_power: 15,
                               hours_in_operation: 1.5,
                               start_hour: 7,
                               used_for_local_ventilation: true)
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'MechanicalVentilation',
                               fan_type: HPXML::MechVentTypeExhaust,
                               tested_flow_rate: 110,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.add(id: 'KitchenRangeFan',
                               fan_location: HPXML::LocationKitchen,
                               used_for_local_ventilation: true)
    hpxml.ventilation_fans.add(id: 'BathFans',
                               fan_location: HPXML::LocationBath,
                               used_for_local_ventilation: true)
  elsif ['base-bldgtype-multifamily-shared-mechvent.xml'].include? hpxml_file
    # Shared supply + in-unit exhaust (roughly balanced)
    hpxml.ventilation_fans.add(id: 'SharedSupplyFan',
                               fan_type: HPXML::MechVentTypeSupply,
                               is_shared_system: true,
                               in_unit_flow_rate: 80,
                               rated_flow_rate: 800,
                               hours_in_operation: 24,
                               fan_power: 240,
                               used_for_whole_building_ventilation: true,
                               fraction_recirculation: 0.5)
    hpxml.ventilation_fans.add(id: 'ExhaustFan',
                               fan_type: HPXML::MechVentTypeExhaust,
                               tested_flow_rate: 72,
                               hours_in_operation: 24,
                               fan_power: 26,
                               used_for_whole_building_ventilation: true)
  elsif ['invalid_files/invalid-shared-vent-in-unit-flowrate.xml'].include? hpxml_file
    hpxml.ventilation_fans[0].in_unit_flow_rate = 80
    hpxml.ventilation_fans[0].rated_flow_rate = 80
  elsif ['base-bldgtype-multifamily-shared-mechvent-preconditioning.xml'].include? hpxml_file
    hpxml.ventilation_fans[0].preheating_fuel = HPXML::FuelTypeNaturalGas
    hpxml.ventilation_fans[0].preheating_efficiency_cop = 0.92
    hpxml.ventilation_fans[0].preheating_fraction_load_served = 0.7
    hpxml.ventilation_fans[0].precooling_fuel = HPXML::FuelTypeElectricity
    hpxml.ventilation_fans[0].precooling_efficiency_cop = 4.0
    hpxml.ventilation_fans[0].precooling_fraction_load_served = 0.8
  elsif ['base-bldgtype-multifamily-shared-mechvent-multiple.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'SharedSupplyPreconditioned',
                               fan_type: HPXML::MechVentTypeSupply,
                               is_shared_system: true,
                               in_unit_flow_rate: 100,
                               rated_flow_rate: 1000,
                               hours_in_operation: 24,
                               fan_power: 300,
                               used_for_whole_building_ventilation: true,
                               fraction_recirculation: 0.0,
                               preheating_fuel: HPXML::FuelTypeNaturalGas,
                               preheating_efficiency_cop: 0.92,
                               preheating_fraction_load_served: 0.8,
                               precooling_fuel: HPXML::FuelTypeElectricity,
                               precooling_efficiency_cop: 4.0,
                               precooling_fraction_load_served: 0.8)
    hpxml.ventilation_fans.add(id: 'SharedERVPreconditioned',
                               fan_type: HPXML::MechVentTypeERV,
                               is_shared_system: true,
                               in_unit_flow_rate: 50,
                               rated_flow_rate: 500,
                               hours_in_operation: 24,
                               total_recovery_efficiency: 0.48,
                               sensible_recovery_efficiency: 0.72,
                               fan_power: 150,
                               used_for_whole_building_ventilation: true,
                               fraction_recirculation: 0.4,
                               preheating_fuel: HPXML::FuelTypeNaturalGas,
                               preheating_efficiency_cop: 0.87,
                               preheating_fraction_load_served: 1.0,
                               precooling_fuel: HPXML::FuelTypeElectricity,
                               precooling_efficiency_cop: 3.5,
                               precooling_fraction_load_served: 1.0)
    hpxml.ventilation_fans.add(id: 'SharedHRVPreconditioned',
                               fan_type: HPXML::MechVentTypeHRV,
                               is_shared_system: true,
                               in_unit_flow_rate: 50,
                               rated_flow_rate: 500,
                               hours_in_operation: 24,
                               sensible_recovery_efficiency: 0.72,
                               fan_power: 150,
                               used_for_whole_building_ventilation: true,
                               fraction_recirculation: 0.3,
                               preheating_fuel: HPXML::FuelTypeElectricity,
                               preheating_efficiency_cop: 4.0,
                               precooling_fuel: HPXML::FuelTypeElectricity,
                               precooling_efficiency_cop: 4.5,
                               preheating_fraction_load_served: 1.0,
                               precooling_fraction_load_served: 1.0)
    hpxml.ventilation_fans.add(id: 'SharedBalancedPreconditioned',
                               fan_type: HPXML::MechVentTypeBalanced,
                               is_shared_system: true,
                               in_unit_flow_rate: 30,
                               rated_flow_rate: 300,
                               hours_in_operation: 24,
                               fan_power: 150,
                               used_for_whole_building_ventilation: true,
                               fraction_recirculation: 0.3,
                               preheating_fuel: HPXML::FuelTypeElectricity,
                               preheating_efficiency_cop: 3.5,
                               precooling_fuel: HPXML::FuelTypeElectricity,
                               precooling_efficiency_cop: 4.0,
                               preheating_fraction_load_served: 0.9,
                               precooling_fraction_load_served: 1.0)
    hpxml.ventilation_fans.add(id: 'SharedExhaust',
                               fan_type: HPXML::MechVentTypeExhaust,
                               is_shared_system: true,
                               in_unit_flow_rate: 70,
                               rated_flow_rate: 700,
                               hours_in_operation: 8,
                               fan_power: 300,
                               used_for_whole_building_ventilation: true,
                               fraction_recirculation: 0.0)
    hpxml.ventilation_fans.add(id: 'Exhaust',
                               fan_type: HPXML::MechVentTypeExhaust,
                               tested_flow_rate: 50,
                               hours_in_operation: 14,
                               fan_power: 10,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.add(id: 'CFIS',
                               fan_type: HPXML::MechVentTypeCFIS,
                               tested_flow_rate: 160,
                               hours_in_operation: 8,
                               fan_power: 150,
                               used_for_whole_building_ventilation: true,
                               distribution_system_idref: 'HVACDistribution')
  elsif ['base-mechvent-multiple.xml'].include? hpxml_file
    hpxml.ventilation_fans.add(id: 'WholeHouseFan',
                               rated_flow_rate: 2000,
                               fan_power: 150,
                               used_for_seasonal_cooling_load_reduction: true)
    hpxml.ventilation_fans.add(id: 'Supply',
                               fan_type: HPXML::MechVentTypeSupply,
                               tested_flow_rate: 27.5,
                               hours_in_operation: 24,
                               fan_power: 7.5,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.add(id: 'Exhaust',
                               fan_type: HPXML::MechVentTypeExhaust,
                               tested_flow_rate: 12.5,
                               hours_in_operation: 14,
                               fan_power: 2.5,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.add(id: 'Balanced',
                               fan_type: HPXML::MechVentTypeBalanced,
                               tested_flow_rate: 27.5,
                               hours_in_operation: 24,
                               fan_power: 15,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.add(id: 'ERV',
                               fan_type: HPXML::MechVentTypeERV,
                               tested_flow_rate: 12.5,
                               hours_in_operation: 24,
                               total_recovery_efficiency: 0.48,
                               sensible_recovery_efficiency: 0.72,
                               fan_power: 6.25,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.add(id: 'HRV',
                               fan_type: HPXML::MechVentTypeHRV,
                               tested_flow_rate: 15,
                               hours_in_operation: 24,
                               sensible_recovery_efficiency: 0.72,
                               fan_power: 7.5,
                               used_for_whole_building_ventilation: true)
    hpxml.ventilation_fans.reverse_each do |vent_fan|
      vent_fan.fan_power /= 2.0
      vent_fan.rated_flow_rate /= 2.0 unless vent_fan.rated_flow_rate.nil?
      vent_fan.tested_flow_rate /= 2.0 unless vent_fan.tested_flow_rate.nil?
      hpxml.ventilation_fans << vent_fan.dup
      hpxml.ventilation_fans[-1].id = "#{vent_fan.id}_2"
      hpxml.ventilation_fans[-1].start_hour = vent_fan.start_hour - 1 unless vent_fan.start_hour.nil?
      hpxml.ventilation_fans[-1].hours_in_operation = vent_fan.hours_in_operation - 1 unless vent_fan.hours_in_operation.nil?
    end
    hpxml.ventilation_fans.add(id: 'CFIS',
                               fan_type: HPXML::MechVentTypeCFIS,
                               tested_flow_rate: 40,
                               hours_in_operation: 8,
                               fan_power: 37.5,
                               used_for_whole_building_ventilation: true,
                               distribution_system_idref: 'HVACDistribution')
    hpxml.ventilation_fans.add(id: 'CFIS_2',
                               fan_type: HPXML::MechVentTypeCFIS,
                               tested_flow_rate: 42.5,
                               hours_in_operation: 8,
                               fan_power: 37.5,
                               used_for_whole_building_ventilation: true,
                               distribution_system_idref: 'HVACDistribution2')
  end
end

def set_hpxml_water_heating_systems(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.water_heating_systems.add(id: 'WaterHeater',
                                    fuel_type: HPXML::FuelTypeElectricity,
                                    water_heater_type: HPXML::WaterHeaterTypeStorage,
                                    location: HPXML::LocationLivingSpace,
                                    tank_volume: 40,
                                    fraction_dhw_load_served: 1,
                                    heating_capacity: 18767,
                                    energy_factor: 0.95,
                                    temperature: Waterheater.get_default_hot_water_temperature(Constants.ERIVersions[-1]))
  elsif ['base-dhw-multiple.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fraction_dhw_load_served = 0.2
    hpxml.water_heating_systems.add(id: 'WaterHeater2',
                                    fuel_type: HPXML::FuelTypeNaturalGas,
                                    water_heater_type: HPXML::WaterHeaterTypeStorage,
                                    location: HPXML::LocationLivingSpace,
                                    tank_volume: 50,
                                    fraction_dhw_load_served: 0.2,
                                    heating_capacity: 40000,
                                    energy_factor: 0.59,
                                    recovery_efficiency: 0.76,
                                    temperature: Waterheater.get_default_hot_water_temperature(Constants.ERIVersions[-1]))
    hpxml.water_heating_systems.add(id: 'WaterHeater3',
                                    fuel_type: HPXML::FuelTypeElectricity,
                                    water_heater_type: HPXML::WaterHeaterTypeHeatPump,
                                    location: HPXML::LocationLivingSpace,
                                    tank_volume: 80,
                                    fraction_dhw_load_served: 0.2,
                                    energy_factor: 2.3,
                                    temperature: Waterheater.get_default_hot_water_temperature(Constants.ERIVersions[-1]))
    hpxml.water_heating_systems.add(id: 'WaterHeater4',
                                    fuel_type: HPXML::FuelTypeElectricity,
                                    water_heater_type: HPXML::WaterHeaterTypeTankless,
                                    location: HPXML::LocationLivingSpace,
                                    fraction_dhw_load_served: 0.2,
                                    energy_factor: 0.99,
                                    temperature: Waterheater.get_default_hot_water_temperature(Constants.ERIVersions[-1]))
    hpxml.water_heating_systems.add(id: 'WaterHeater5',
                                    fuel_type: HPXML::FuelTypeNaturalGas,
                                    water_heater_type: HPXML::WaterHeaterTypeTankless,
                                    location: HPXML::LocationLivingSpace,
                                    fraction_dhw_load_served: 0.1,
                                    energy_factor: 0.82,
                                    temperature: Waterheater.get_default_hot_water_temperature(Constants.ERIVersions[-1]))
    hpxml.water_heating_systems.add(id: 'WaterHeater6',
                                    water_heater_type: HPXML::WaterHeaterTypeCombiStorage,
                                    location: HPXML::LocationLivingSpace,
                                    tank_volume: 50,
                                    fraction_dhw_load_served: 0.1,
                                    related_hvac_idref: 'HeatingSystem',
                                    temperature: Waterheater.get_default_hot_water_temperature(Constants.ERIVersions[-1]))
  elsif ['invalid_files/dhw-frac-load-served.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fraction_dhw_load_served += 0.15
  elsif ['base-dhw-tank-coal.xml',
         'base-dhw-tank-gas.xml',
         'base-dhw-tank-gas-outside.xml',
         'base-dhw-tank-oil.xml',
         'base-dhw-tank-wood.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].tank_volume = 50
    hpxml.water_heating_systems[0].heating_capacity = 40000
    hpxml.water_heating_systems[0].energy_factor = 0.59
    hpxml.water_heating_systems[0].recovery_efficiency = 0.76
    if hpxml_file == 'base-dhw-tank-gas-outside.xml'
      hpxml.water_heating_systems[0].location = HPXML::LocationOtherExterior
    end
    if hpxml_file == 'base-dhw-tank-coal.xml'
      hpxml.water_heating_systems[0].fuel_type = HPXML::FuelTypeCoal
    elsif hpxml_file == 'base-dhw-tank-oil.xml'
      hpxml.water_heating_systems[0].fuel_type = HPXML::FuelTypeOil
    elsif hpxml_file == 'base-dhw-tank-wood.xml'
      hpxml.water_heating_systems[0].fuel_type = HPXML::FuelTypeWoodCord
    else
      hpxml.water_heating_systems[0].fuel_type = HPXML::FuelTypeNaturalGas
    end
  elsif ['base-dhw-tank-heat-pump.xml',
         'base-dhw-tank-heat-pump-outside.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = HPXML::WaterHeaterTypeHeatPump
    hpxml.water_heating_systems[0].tank_volume = 80
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = 2.3
    if hpxml_file == 'base-dhw-tank-heat-pump-outside.xml'
      hpxml.water_heating_systems[0].location = HPXML::LocationOtherExterior
    end
  elsif ['base-dhw-tankless-electric.xml',
         'base-dhw-tankless-electric-outside.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = HPXML::WaterHeaterTypeTankless
    hpxml.water_heating_systems[0].tank_volume = nil
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = 0.99
    if hpxml_file == 'base-dhw-tankless-electric-outside.xml'
      hpxml.water_heating_systems[0].location = HPXML::LocationOtherExterior
      hpxml.water_heating_systems[0].performance_adjustment = 0.92
    end
  elsif ['base-dhw-tankless-gas.xml',
         'base-dhw-tankless-propane.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = HPXML::WaterHeaterTypeTankless
    hpxml.water_heating_systems[0].tank_volume = nil
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = 0.82
    if hpxml_file == 'base-dhw-tankless-gas.xml'
      hpxml.water_heating_systems[0].fuel_type = HPXML::FuelTypeNaturalGas
    elsif hpxml_file == 'base-dhw-tankless-propane.xml'
      hpxml.water_heating_systems[0].fuel_type = HPXML::FuelTypePropane
    end
  elsif ['base-dhw-tank-elec-uef.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].energy_factor = nil
    hpxml.water_heating_systems[0].uniform_energy_factor = 0.93
    hpxml.water_heating_systems[0].usage_bin = HPXML::WaterHeaterUsageBinLow
    hpxml.water_heating_systems[0].tank_volume = 30.0
    hpxml.water_heating_systems[0].heating_capacity = 15354.0 # 4.5 kW
  elsif ['base-dhw-tank-gas-uef.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fuel_type = HPXML::FuelTypeNaturalGas
    hpxml.water_heating_systems[0].energy_factor = nil
    hpxml.water_heating_systems[0].uniform_energy_factor = 0.59
    hpxml.water_heating_systems[0].usage_bin = HPXML::WaterHeaterUsageBinMedium
    hpxml.water_heating_systems[0].tank_volume = 30.0
    hpxml.water_heating_systems[0].heating_capacity = 30000.0
    hpxml.water_heating_systems[0].recovery_efficiency = 0.75
  elsif ['base-dhw-tank-gas-uef-fhr.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].first_hour_rating = 56.0
    hpxml.water_heating_systems[0].usage_bin = nil
  elsif ['base-dhw-tank-heat-pump-uef.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = HPXML::WaterHeaterTypeHeatPump
    hpxml.water_heating_systems[0].energy_factor = nil
    hpxml.water_heating_systems[0].uniform_energy_factor = 3.75
    hpxml.water_heating_systems[0].usage_bin = HPXML::WaterHeaterUsageBinMedium
    hpxml.water_heating_systems[0].tank_volume = 50.0
  elsif ['base-dhw-tankless-gas-uef.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = HPXML::WaterHeaterTypeTankless
    hpxml.water_heating_systems[0].fuel_type = HPXML::FuelTypeNaturalGas
    hpxml.water_heating_systems[0].tank_volume = nil
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = nil
    hpxml.water_heating_systems[0].uniform_energy_factor = 0.93
  elsif ['base-dhw-tankless-electric-uef.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = HPXML::WaterHeaterTypeTankless
    hpxml.water_heating_systems[0].tank_volume = nil
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = nil
    hpxml.water_heating_systems[0].uniform_energy_factor = 0.98
  elsif ['base-dhw-desuperheater.xml',
         'base-dhw-desuperheater-2-speed.xml',
         'base-dhw-desuperheater-var-speed.xml',
         'base-dhw-desuperheater-hpwh.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].uses_desuperheater = true
    hpxml.water_heating_systems[0].related_hvac_idref = 'CoolingSystem'
  elsif ['base-dhw-desuperheater-tankless.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = HPXML::WaterHeaterTypeTankless
    hpxml.water_heating_systems[0].tank_volume = nil
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = 0.99
    hpxml.water_heating_systems[0].uses_desuperheater = true
    hpxml.water_heating_systems[0].related_hvac_idref = 'CoolingSystem'
  elsif ['base-dhw-desuperheater-gshp.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].uses_desuperheater = true
    hpxml.water_heating_systems[0].related_hvac_idref = 'HeatPump'
  elsif ['base-dhw-jacket-electric.xml',
         'base-dhw-jacket-indirect.xml',
         'base-dhw-jacket-gas.xml',
         'base-dhw-jacket-hpwh.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].jacket_r_value = 10.0
  elsif ['base-dhw-indirect.xml',
         'base-dhw-indirect-outside.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = HPXML::WaterHeaterTypeCombiStorage
    hpxml.water_heating_systems[0].tank_volume = 50
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = nil
    hpxml.water_heating_systems[0].fuel_type = nil
    hpxml.water_heating_systems[0].related_hvac_idref = 'HeatingSystem'
    if hpxml_file == 'base-dhw-indirect-outside.xml'
      hpxml.water_heating_systems[0].location = HPXML::LocationOtherExterior
    end
  elsif ['base-dhw-indirect-standbyloss.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].standby_loss = 1.0
  elsif ['base-dhw-combi-tankless.xml',
         'base-dhw-combi-tankless-outside.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = HPXML::WaterHeaterTypeCombiTankless
    hpxml.water_heating_systems[0].tank_volume = nil
    if hpxml_file == 'base-dhw-combi-tankless-outside.xml'
      hpxml.water_heating_systems[0].location = HPXML::LocationOtherExterior
    end
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationBasementUnconditioned
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationCrawlspaceUnvented
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationCrawlspaceVented
  elsif ['base-foundation-slab.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationLivingSpace
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationAtticVented
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationBasementConditioned
  elsif ['invalid_files/water-heater-location.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationCrawlspaceVented
  elsif ['invalid_files/water-heater-location-other.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = 'unconditioned space'
  elsif ['invalid_files/invalid-relatedhvac-desuperheater.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].uses_desuperheater = true
    hpxml.water_heating_systems[0].related_hvac_idref = 'CoolingSystem_bad'
  elsif ['invalid_files/repeated-relatedhvac-desuperheater.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fraction_dhw_load_served = 0.5
    hpxml.water_heating_systems[0].uses_desuperheater = true
    hpxml.water_heating_systems[0].related_hvac_idref = 'CoolingSystem'
    hpxml.water_heating_systems << hpxml.water_heating_systems[0].dup
    hpxml.water_heating_systems[1].id = 'WaterHeater2'
  elsif ['invalid_files/invalid-relatedhvac-dhw-indirect.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].related_hvac_idref = 'HeatingSystem_bad'
  elsif ['invalid_files/repeated-relatedhvac-dhw-indirect.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fraction_dhw_load_served = 0.5
    hpxml.water_heating_systems << hpxml.water_heating_systems[0].dup
    hpxml.water_heating_systems[1].id = 'WaterHeater2'
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationGarage
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationLivingSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationOtherHousingUnit
  elsif ['base-bldgtype-multifamily-adjacent-to-other-heated-space.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationOtherHeatedSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationOtherMultifamilyBufferSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationOtherNonFreezingSpace
  elsif ['base-dhw-none.xml'].include? hpxml_file
    hpxml.water_heating_systems.clear
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].temperature = nil
    hpxml.water_heating_systems[0].location = nil
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].tank_volume = nil
    hpxml.water_heating_systems[0].recovery_efficiency = nil
    hpxml.water_heating_systems[0].energy_factor = nil
    hpxml.water_heating_systems[0].year_installed = 2009
    hpxml.water_heating_systems[0].usage_bin = nil
    hpxml.water_heating_systems[0].first_hour_rating = nil
  elsif ['base-bldgtype-multifamily-shared-water-heater.xml',
         'base-bldgtype-multifamily-shared-laundry-room.xml'].include? hpxml_file
    hpxml.water_heating_systems.clear
    hpxml.water_heating_systems.add(id: 'SharedWaterHeater',
                                    is_shared_system: true,
                                    number_of_units_served: 6,
                                    fuel_type: HPXML::FuelTypeNaturalGas,
                                    water_heater_type: HPXML::WaterHeaterTypeStorage,
                                    location: HPXML::LocationLivingSpace,
                                    tank_volume: 120,
                                    fraction_dhw_load_served: 1.0,
                                    heating_capacity: 40000,
                                    energy_factor: 0.59,
                                    recovery_efficiency: 0.76,
                                    temperature: Waterheater.get_default_hot_water_temperature(Constants.ERIVersions[-1]))
  elsif ['invalid_files/multifamily-reference-water-heater.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = HPXML::LocationOtherNonFreezingSpace
  elsif ['invalid_files/dhw-invalid-ef-tank.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].energy_factor = 1.0
  elsif ['invalid_files/dhw-invalid-uef-tank-heat-pump.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].uniform_energy_factor = 1.0
  elsif ['invalid_files/invalid-number-of-units-served.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].number_of_units_served = 1
  end
end

def set_hpxml_hot_water_distribution(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.hot_water_distributions.add(id: 'HotWaterDistribution',
                                      system_type: HPXML::DHWDistTypeStandard,
                                      standard_piping_length: 50, # Chosen to test a negative EC_adj
                                      pipe_r_value: 0.0)
  elsif ['base-dhw-dwhr.xml'].include? hpxml_file
    hpxml.hot_water_distributions[0].dwhr_facilities_connected = HPXML::DWHRFacilitiesConnectedAll
    hpxml.hot_water_distributions[0].dwhr_equal_flow = true
    hpxml.hot_water_distributions[0].dwhr_efficiency = 0.55
  elsif ['base-dhw-recirc-demand.xml'].include? hpxml_file
    hpxml.hot_water_distributions[0].system_type = HPXML::DHWDistTypeRecirc
    hpxml.hot_water_distributions[0].recirculation_control_type = HPXML::DHWRecirControlTypeSensor
    hpxml.hot_water_distributions[0].recirculation_piping_length = 50
    hpxml.hot_water_distributions[0].recirculation_branch_piping_length = 50
    hpxml.hot_water_distributions[0].recirculation_pump_power = 50
    hpxml.hot_water_distributions[0].pipe_r_value = 3
  elsif ['base-dhw-recirc-manual.xml'].include? hpxml_file
    hpxml.hot_water_distributions[0].system_type = HPXML::DHWDistTypeRecirc
    hpxml.hot_water_distributions[0].recirculation_control_type = HPXML::DHWRecirControlTypeManual
    hpxml.hot_water_distributions[0].recirculation_piping_length = 50
    hpxml.hot_water_distributions[0].recirculation_branch_piping_length = 50
    hpxml.hot_water_distributions[0].recirculation_pump_power = 50
    hpxml.hot_water_distributions[0].pipe_r_value = 3
  elsif ['base-dhw-recirc-nocontrol.xml'].include? hpxml_file
    hpxml.hot_water_distributions[0].system_type = HPXML::DHWDistTypeRecirc
    hpxml.hot_water_distributions[0].recirculation_control_type = HPXML::DHWRecirControlTypeNone
    hpxml.hot_water_distributions[0].recirculation_piping_length = 50
    hpxml.hot_water_distributions[0].recirculation_branch_piping_length = 50
    hpxml.hot_water_distributions[0].recirculation_pump_power = 50
  elsif ['base-dhw-recirc-temperature.xml'].include? hpxml_file
    hpxml.hot_water_distributions[0].system_type = HPXML::DHWDistTypeRecirc
    hpxml.hot_water_distributions[0].recirculation_control_type = HPXML::DHWRecirControlTypeTemperature
    hpxml.hot_water_distributions[0].recirculation_piping_length = 50
    hpxml.hot_water_distributions[0].recirculation_branch_piping_length = 50
    hpxml.hot_water_distributions[0].recirculation_pump_power = 50
  elsif ['base-dhw-recirc-timer.xml'].include? hpxml_file
    hpxml.hot_water_distributions[0].system_type = HPXML::DHWDistTypeRecirc
    hpxml.hot_water_distributions[0].recirculation_control_type = HPXML::DHWRecirControlTypeTimer
    hpxml.hot_water_distributions[0].recirculation_piping_length = 50
    hpxml.hot_water_distributions[0].recirculation_branch_piping_length = 50
    hpxml.hot_water_distributions[0].recirculation_pump_power = 50
  elsif ['base-bldgtype-multifamily-shared-water-heater.xml'].include? hpxml_file
    hpxml.hot_water_distributions[0].id = 'SharedHotWaterDistribution'
  elsif ['base-bldgtype-multifamily-shared-water-heater-recirc.xml'].include? hpxml_file
    hpxml.hot_water_distributions[0].has_shared_recirculation = true
    hpxml.hot_water_distributions[0].shared_recirculation_number_of_units_served = 6
    hpxml.hot_water_distributions[0].shared_recirculation_pump_power = 220
    hpxml.hot_water_distributions[0].shared_recirculation_control_type = HPXML::DHWRecirControlTypeTimer
  elsif ['base-dhw-none.xml'].include? hpxml_file
    hpxml.hot_water_distributions.clear
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.hot_water_distributions[0].pipe_r_value = nil
    hpxml.hot_water_distributions[0].standard_piping_length = nil
  end
end

def set_hpxml_water_fixtures(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.water_fixtures.add(id: 'WaterFixture',
                             water_fixture_type: HPXML::WaterFixtureTypeShowerhead,
                             low_flow: true)
    hpxml.water_fixtures.add(id: 'WaterFixture2',
                             water_fixture_type: HPXML::WaterFixtureTypeFaucet,
                             low_flow: false)
  elsif ['base-dhw-low-flow-fixtures.xml'].include? hpxml_file
    hpxml.water_fixtures[1].low_flow = true
  elsif ['base-dhw-none.xml'].include? hpxml_file
    hpxml.water_fixtures.clear
  elsif ['base-misc-usage-multiplier.xml'].include? hpxml_file
    hpxml.water_heating.water_fixtures_usage_multiplier = 0.9
  end
end

def set_hpxml_solar_thermal_system(hpxml_file, hpxml)
  if ['base-dhw-solar-fraction.xml',
      'base-dhw-indirect-with-solar-fraction.xml',
      'base-dhw-tank-heat-pump-with-solar-fraction.xml',
      'base-dhw-tankless-gas-with-solar-fraction.xml'].include? hpxml_file
    hpxml.solar_thermal_systems.add(id: 'SolarThermalSystem',
                                    system_type: 'hot water',
                                    water_heating_system_idref: 'WaterHeater',
                                    solar_fraction: 0.65)
  elsif ['base-dhw-multiple.xml'].include? hpxml_file
    hpxml.solar_thermal_systems.add(id: 'SolarThermalSystem',
                                    system_type: 'hot water',
                                    water_heating_system_idref: nil, # Apply to all water heaters
                                    solar_fraction: 0.65)
  elsif ['base-dhw-solar-direct-flat-plate.xml',
         'base-dhw-solar-indirect-flat-plate.xml',
         'base-dhw-solar-thermosyphon-flat-plate.xml',
         'base-dhw-tank-heat-pump-with-solar.xml',
         'base-dhw-tankless-gas-with-solar.xml',
         'base-misc-defaults.xml',
         'invalid_files/solar-thermal-system-with-combi-tankless.xml',
         'invalid_files/solar-thermal-system-with-desuperheater.xml',
         'invalid_files/solar-thermal-system-with-dhw-indirect.xml'].include? hpxml_file
    hpxml.solar_thermal_systems.add(id: 'SolarThermalSystem',
                                    system_type: 'hot water',
                                    collector_area: 40,
                                    collector_type: HPXML::SolarThermalTypeSingleGlazing,
                                    collector_azimuth: 180,
                                    collector_tilt: 20,
                                    collector_frta: 0.77,
                                    collector_frul: 0.793,
                                    storage_volume: 60,
                                    water_heating_system_idref: 'WaterHeater')
    if hpxml_file == 'base-dhw-solar-direct-flat-plate.xml'
      hpxml.solar_thermal_systems[0].collector_loop_type = HPXML::SolarThermalLoopTypeDirect
    elsif hpxml_file == 'base-dhw-solar-thermosyphon-flat-plate.xml'
      hpxml.solar_thermal_systems[0].collector_loop_type = HPXML::SolarThermalLoopTypeThermosyphon
    elsif hpxml_file == 'base-misc-defaults.xml'
      hpxml.solar_thermal_systems[0].collector_loop_type = HPXML::SolarThermalLoopTypeDirect
      hpxml.solar_thermal_systems[0].storage_volume = nil
    else
      hpxml.solar_thermal_systems[0].collector_loop_type = HPXML::SolarThermalLoopTypeIndirect
    end
  elsif ['base-dhw-solar-direct-evacuated-tube.xml'].include? hpxml_file
    hpxml.solar_thermal_systems.add(id: 'SolarThermalSystem',
                                    system_type: 'hot water',
                                    collector_area: 40,
                                    collector_type: HPXML::SolarThermalTypeEvacuatedTube,
                                    collector_azimuth: 180,
                                    collector_tilt: 20,
                                    collector_frta: 0.50,
                                    collector_frul: 0.2799,
                                    storage_volume: 60,
                                    water_heating_system_idref: 'WaterHeater')
    if hpxml_file == 'base-dhw-solar-direct-evacuated-tube.xml'
      hpxml.solar_thermal_systems[0].collector_loop_type = HPXML::SolarThermalLoopTypeDirect
    else
      hpxml.solar_thermal_systems[0].collector_loop_type = HPXML::SolarThermalLoopTypeIndirect
    end
  elsif ['base-dhw-solar-direct-ics.xml'].include? hpxml_file
    hpxml.solar_thermal_systems.add(id: 'SolarThermalSystem',
                                    system_type: 'hot water',
                                    collector_area: 40,
                                    collector_loop_type: HPXML::SolarThermalLoopTypeDirect,
                                    collector_type: HPXML::SolarThermalTypeICS,
                                    collector_azimuth: 180,
                                    collector_tilt: 20,
                                    collector_frta: 0.77,
                                    collector_frul: 0.793,
                                    storage_volume: 60,
                                    water_heating_system_idref: 'WaterHeater')
  elsif ['invalid_files/unattached-solar-thermal-system.xml'].include? hpxml_file
    hpxml.solar_thermal_systems[0].water_heating_system_idref = 'foobar'
  elsif ['invalid_files/solar-fraction-one.xml'].include? hpxml_file
    hpxml.solar_thermal_systems[0].solar_fraction = 1.0
  end
end

def set_hpxml_pv_systems(hpxml_file, hpxml)
  if ['base-pv.xml'].include? hpxml_file
    hpxml.pv_systems.add(id: 'PVSystem',
                         module_type: HPXML::PVModuleTypeStandard,
                         location: HPXML::LocationRoof,
                         tracking: HPXML::PVTrackingTypeFixed,
                         array_azimuth: 180,
                         array_tilt: 20,
                         max_power_output: 4000,
                         inverter_efficiency: 0.96,
                         system_losses_fraction: 0.14)
    hpxml.pv_systems.add(id: 'PVSystem2',
                         module_type: HPXML::PVModuleTypePremium,
                         location: HPXML::LocationRoof,
                         tracking: HPXML::PVTrackingTypeFixed,
                         array_azimuth: 90,
                         array_tilt: 20,
                         max_power_output: 1500,
                         inverter_efficiency: 0.96,
                         system_losses_fraction: 0.14)
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.pv_systems.add(id: 'PVSystem',
                         array_azimuth: 180,
                         array_tilt: 20,
                         max_power_output: 4000,
                         year_modules_manufactured: 2015)
  elsif ['base-bldgtype-multifamily-shared-pv.xml'].include? hpxml_file
    hpxml.pv_systems.add(id: 'PVSystem',
                         is_shared_system: true,
                         module_type: HPXML::PVModuleTypeStandard,
                         location: HPXML::LocationGround,
                         tracking: HPXML::PVTrackingTypeFixed,
                         array_azimuth: 225,
                         array_tilt: 30,
                         max_power_output: 30000,
                         inverter_efficiency: 0.96,
                         system_losses_fraction: 0.14,
                         number_of_bedrooms_served: 18)
  elsif ['invalid_files/invalid-number-of-bedrooms-served.xml'].include? hpxml_file
    hpxml.pv_systems[0].number_of_bedrooms_served = hpxml.building_construction.number_of_bedrooms
  end
end

def set_hpxml_generators(hpxml_file, hpxml)
  if ['base-misc-generators.xml'].include? hpxml_file
    hpxml.generators.add(id: 'Generator',
                         fuel_type: HPXML::FuelTypeNaturalGas,
                         annual_consumption_kbtu: 8500,
                         annual_output_kwh: 500)
    hpxml.generators.add(id: 'Generator2',
                         fuel_type: HPXML::FuelTypeOil,
                         annual_consumption_kbtu: 8500,
                         annual_output_kwh: 500)
  elsif ['base-bldgtype-multifamily-shared-generator.xml'].include? hpxml_file
    hpxml.generators.add(id: 'Generator',
                         is_shared_system: true,
                         fuel_type: HPXML::FuelTypePropane,
                         annual_consumption_kbtu: 85000,
                         annual_output_kwh: 5000,
                         number_of_bedrooms_served: 18)
  elsif ['invalid_files/generator-output-greater-than-consumption.xml'].include? hpxml_file
    hpxml.generators[0].annual_consumption_kbtu = 1500
  elsif ['invalid_files/generator-number-of-bedrooms-served.xml'].include? hpxml_file
    hpxml.generators[0].number_of_bedrooms_served = hpxml.building_construction.number_of_bedrooms
  end
end

def set_hpxml_clothes_washer(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.clothes_washers.add(id: 'ClothesWasher',
                              location: HPXML::LocationLivingSpace,
                              integrated_modified_energy_factor: 1.21,
                              rated_annual_kwh: 380,
                              label_electric_rate: 0.12,
                              label_gas_rate: 1.09,
                              label_annual_gas_cost: 27,
                              capacity: 3.2,
                              label_usage: 6)
  elsif ['base-appliances-none.xml',
         'base-dhw-none.xml'].include? hpxml_file
    hpxml.clothes_washers.clear
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    hpxml.clothes_washers[0].location = HPXML::LocationLivingSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml'].include? hpxml_file
    hpxml.clothes_washers[0].location = HPXML::LocationOtherHousingUnit
  elsif ['base-bldgtype-multifamily-adjacent-to-other-heated-space.xml'].include? hpxml_file
    hpxml.clothes_washers[0].location = HPXML::LocationOtherHeatedSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml'].include? hpxml_file
    hpxml.clothes_washers[0].location = HPXML::LocationOtherMultifamilyBufferSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml'].include? hpxml_file
    hpxml.clothes_washers[0].location = HPXML::LocationOtherNonFreezingSpace
  elsif ['base-appliances-modified.xml'].include? hpxml_file
    imef = hpxml.clothes_washers[0].integrated_modified_energy_factor
    hpxml.clothes_washers[0].integrated_modified_energy_factor = nil
    hpxml.clothes_washers[0].modified_energy_factor = HotWaterAndAppliances.calc_clothes_washer_mef_from_imef(imef).round(2)
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.clothes_washers[0].location = HPXML::LocationBasementUnconditioned
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.clothes_washers[0].location = HPXML::LocationBasementConditioned
  elsif ['base-enclosure-garage.xml',
         'invalid_files/clothes-washer-location.xml'].include? hpxml_file
    hpxml.clothes_washers[0].location = HPXML::LocationGarage
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.clothes_washers[0].location = nil
    hpxml.clothes_washers[0].modified_energy_factor = nil
    hpxml.clothes_washers[0].integrated_modified_energy_factor = nil
    hpxml.clothes_washers[0].rated_annual_kwh = nil
    hpxml.clothes_washers[0].label_electric_rate = nil
    hpxml.clothes_washers[0].label_gas_rate = nil
    hpxml.clothes_washers[0].label_annual_gas_cost = nil
    hpxml.clothes_washers[0].capacity = nil
    hpxml.clothes_washers[0].label_usage = nil
  elsif ['base-misc-usage-multiplier.xml'].include? hpxml_file
    hpxml.clothes_washers[0].usage_multiplier = 0.9
  elsif ['base-bldgtype-multifamily-shared-laundry-room.xml'].include? hpxml_file
    hpxml.clothes_washers[0].is_shared_appliance = true
    hpxml.clothes_washers[0].id = 'SharedClothesWasher'
    hpxml.clothes_washers[0].location = HPXML::LocationOtherHeatedSpace
    hpxml.clothes_washers[0].water_heating_system_idref = 'SharedWaterHeater'
  elsif ['invalid_files/unattached-shared-clothes-washer-water-heater.xml'].include? hpxml_file
    hpxml.clothes_washers[0].water_heating_system_idref = 'foobar'
  elsif ['invalid_files/multifamily-reference-appliance.xml'].include? hpxml_file
    hpxml.clothes_washers[0].location = HPXML::LocationOtherHousingUnit
  end
end

def set_hpxml_clothes_dryer(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.clothes_dryers.add(id: 'ClothesDryer',
                             location: HPXML::LocationLivingSpace,
                             fuel_type: HPXML::FuelTypeElectricity,
                             combined_energy_factor: 3.73,
                             is_vented: true,
                             vented_flow_rate: 150)
  elsif ['base-appliances-none.xml',
         'base-dhw-none.xml'].include? hpxml_file
    hpxml.clothes_dryers.clear
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    hpxml.clothes_dryers[0].location = HPXML::LocationLivingSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml'].include? hpxml_file
    hpxml.clothes_dryers[0].location = HPXML::LocationOtherHousingUnit
  elsif ['base-bldgtype-multifamily-adjacent-to-other-heated-space.xml'].include? hpxml_file
    hpxml.clothes_dryers[0].location = HPXML::LocationOtherHeatedSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml'].include? hpxml_file
    hpxml.clothes_dryers[0].location = HPXML::LocationOtherMultifamilyBufferSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml'].include? hpxml_file
    hpxml.clothes_dryers[0].location = HPXML::LocationOtherNonFreezingSpace
  elsif ['base-appliances-modified.xml'].include? hpxml_file
    cef = hpxml.clothes_dryers[-1].combined_energy_factor
    hpxml.clothes_dryers.clear
    hpxml.clothes_dryers.add(id: 'ClothesDryer',
                             location: HPXML::LocationLivingSpace,
                             fuel_type: HPXML::FuelTypeElectricity,
                             energy_factor: HotWaterAndAppliances.calc_clothes_dryer_ef_from_cef(cef).round(2),
                             is_vented: false)
  elsif ['base-appliances-coal.xml',
         'base-appliances-gas.xml',
         'base-appliances-propane.xml',
         'base-appliances-oil.xml',
         'base-appliances-wood.xml'].include? hpxml_file
    hpxml.clothes_dryers.clear
    hpxml.clothes_dryers.add(id: 'ClothesDryer',
                             location: HPXML::LocationLivingSpace,
                             combined_energy_factor: 3.30)
    if hpxml_file == 'base-appliances-coal.xml'
      hpxml.clothes_dryers[0].fuel_type = HPXML::FuelTypeCoal
    elsif hpxml_file == 'base-appliances-gas.xml'
      hpxml.clothes_dryers[0].fuel_type = HPXML::FuelTypeNaturalGas
    elsif hpxml_file == 'base-appliances-propane.xml'
      hpxml.clothes_dryers[0].fuel_type = HPXML::FuelTypePropane
    elsif hpxml_file == 'base-appliances-oil.xml'
      hpxml.clothes_dryers[0].fuel_type = HPXML::FuelTypeOil
    elsif hpxml_file == 'base-appliances-wood.xml'
      hpxml.clothes_dryers[0].fuel_type = HPXML::FuelTypeWoodCord
    end
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.clothes_dryers[0].location = HPXML::LocationBasementUnconditioned
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.clothes_dryers[0].location = HPXML::LocationBasementConditioned
  elsif ['base-enclosure-garage.xml',
         'invalid_files/clothes-dryer-location.xml'].include? hpxml_file
    hpxml.clothes_dryers[0].location = HPXML::LocationGarage
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.clothes_dryers[0].location = nil
    hpxml.clothes_dryers[0].energy_factor = nil
    hpxml.clothes_dryers[0].combined_energy_factor = nil
    hpxml.clothes_dryers[0].is_vented = nil
    hpxml.clothes_dryers[0].vented_flow_rate = nil
  elsif ['base-bldgtype-multifamily-shared-laundry-room.xml'].include? hpxml_file
    hpxml.clothes_dryers[0].id = 'SharedClothesDryer'
    hpxml.clothes_dryers[0].location = HPXML::LocationOtherHeatedSpace
    hpxml.clothes_dryers[0].is_shared_appliance = true
  elsif ['base-misc-usage-multiplier.xml'].include? hpxml_file
    hpxml.clothes_dryers[0].usage_multiplier = 0.9
  end
end

def set_hpxml_dishwasher(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.dishwashers.add(id: 'Dishwasher',
                          location: HPXML::LocationLivingSpace,
                          rated_annual_kwh: 307,
                          label_electric_rate: 0.12,
                          label_gas_rate: 1.09,
                          label_annual_gas_cost: 22.32,
                          label_usage: 4,
                          place_setting_capacity: 12)
  elsif ['base-appliances-modified.xml'].include? hpxml_file
    rated_annual_kwh = hpxml.dishwashers[0].rated_annual_kwh
    hpxml.dishwashers[0].rated_annual_kwh = nil
    hpxml.dishwashers[0].energy_factor = HotWaterAndAppliances.calc_dishwasher_ef_from_annual_kwh(rated_annual_kwh).round(2)
    hpxml.dishwashers[0].place_setting_capacity = 6 # Compact
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    hpxml.dishwashers[0].location = HPXML::LocationLivingSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml'].include? hpxml_file
    hpxml.dishwashers[0].location = HPXML::LocationOtherHousingUnit
  elsif ['base-bldgtype-multifamily-adjacent-to-other-heated-space.xml'].include? hpxml_file
    hpxml.dishwashers[0].location = HPXML::LocationOtherHeatedSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml'].include? hpxml_file
    hpxml.dishwashers[0].location = HPXML::LocationOtherMultifamilyBufferSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml'].include? hpxml_file
    hpxml.dishwashers[0].location = HPXML::LocationOtherNonFreezingSpace
  elsif ['base-appliances-none.xml',
         'base-dhw-none.xml'].include? hpxml_file
    hpxml.dishwashers.clear
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.dishwashers[0].location = HPXML::LocationBasementUnconditioned
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.dishwashers[0].location = HPXML::LocationBasementConditioned
  elsif ['base-enclosure-garage.xml',
         'invalid_files/dishwasher-location.xml'].include? hpxml_file
    hpxml.dishwashers[0].location = HPXML::LocationGarage
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.dishwashers[0].rated_annual_kwh = nil
    hpxml.dishwashers[0].label_electric_rate = nil
    hpxml.dishwashers[0].label_gas_rate = nil
    hpxml.dishwashers[0].label_annual_gas_cost = nil
    hpxml.dishwashers[0].place_setting_capacity = nil
    hpxml.dishwashers[0].label_usage = nil
    hpxml.dishwashers[0].location = nil
  elsif ['base-misc-usage-multiplier.xml'].include? hpxml_file
    hpxml.dishwashers[0].usage_multiplier = 0.9
  elsif ['base-bldgtype-multifamily-shared-laundry-room.xml'].include? hpxml_file
    hpxml.dishwashers[0].is_shared_appliance = true
    hpxml.dishwashers[0].id = 'SharedDishwasher'
    hpxml.dishwashers[0].location = HPXML::LocationOtherHeatedSpace
    hpxml.dishwashers[0].water_heating_system_idref = 'SharedWaterHeater'
  elsif ['invalid_files/unattached-shared-dishwasher-water-heater.xml'].include? hpxml_file
    hpxml.dishwashers[0].water_heating_system_idref = 'foobar'
  elsif ['invalid_files/invalid-input-parameters.xml'].include? hpxml_file
    hpxml.dishwashers[0].rated_annual_kwh = nil
    hpxml.dishwashers[0].energy_factor = 5.1
  end
end

def set_hpxml_refrigerator(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.refrigerators.add(id: 'Refrigerator',
                            location: HPXML::LocationLivingSpace,
                            rated_annual_kwh: 650,
                            primary_indicator: true)
  elsif ['base-appliances-modified.xml'].include? hpxml_file
    hpxml.refrigerators[0].adjusted_annual_kwh = 600
  elsif ['base-appliances-none.xml'].include? hpxml_file
    hpxml.refrigerators.clear
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    hpxml.refrigerators[0].location = HPXML::LocationLivingSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml'].include? hpxml_file
    hpxml.refrigerators[0].location = HPXML::LocationOtherHousingUnit
  elsif ['base-bldgtype-multifamily-adjacent-to-other-heated-space.xml'].include? hpxml_file
    hpxml.refrigerators[0].location = HPXML::LocationOtherHeatedSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml'].include? hpxml_file
    hpxml.refrigerators[0].location = HPXML::LocationOtherMultifamilyBufferSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml'].include? hpxml_file
    hpxml.refrigerators[0].location = HPXML::LocationOtherNonFreezingSpace
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.refrigerators[0].location = HPXML::LocationBasementUnconditioned
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.refrigerators[0].location = HPXML::LocationBasementConditioned
  elsif ['base-enclosure-garage.xml',
         'invalid_files/refrigerator-location.xml'].include? hpxml_file
    hpxml.refrigerators[0].location = HPXML::LocationGarage
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.refrigerators[0].primary_indicator = nil
    hpxml.refrigerators[0].location = nil
    hpxml.refrigerators[0].rated_annual_kwh = nil
    hpxml.refrigerators[0].adjusted_annual_kwh = nil
  elsif ['base-misc-usage-multiplier.xml'].include? hpxml_file
    hpxml.refrigerators[0].usage_multiplier = 0.9
  elsif ['base-misc-loads-large-uncommon.xml'].include? hpxml_file
    hpxml.refrigerators[0].weekday_fractions = '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
    hpxml.refrigerators[0].weekend_fractions = '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041'
    hpxml.refrigerators[0].monthly_multipliers = '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837'
    hpxml.refrigerators.add(id: 'ExtraRefrigerator',
                            rated_annual_kwh: 700,
                            primary_indicator: false,
                            weekday_fractions: '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041',
                            weekend_fractions: '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041',
                            monthly_multipliers: '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837')
    hpxml.refrigerators.add(id: 'ExtraRefrigerator2',
                            rated_annual_kwh: 800,
                            primary_indicator: false,
                            weekday_fractions: '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041',
                            weekend_fractions: '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041',
                            monthly_multipliers: '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837')
  elsif ['invalid_files/refrigerators-multiple-primary.xml'].include? hpxml_file
    hpxml.refrigerators.add(id: 'Refrigerator2',
                            location: HPXML::LocationLivingSpace,
                            rated_annual_kwh: 650,
                            primary_indicator: true)
  elsif ['invalid_files/refrigerators-no-primary.xml'].include? hpxml_file
    hpxml.refrigerators[0].primary_indicator = false
    hpxml.refrigerators.add(id: 'Refrigerator2',
                            location: HPXML::LocationLivingSpace,
                            rated_annual_kwh: 650,
                            primary_indicator: false)
  end
end

def set_hpxml_freezer(hpxml_file, hpxml)
  if ['base-misc-loads-large-uncommon.xml',
      'base-misc-usage-multiplier.xml'].include? hpxml_file
    hpxml.freezers.add(id: 'Freezer',
                       location: HPXML::LocationLivingSpace,
                       rated_annual_kwh: 300,
                       weekday_fractions: '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041',
                       weekend_fractions: '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041',
                       monthly_multipliers: '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837')
    hpxml.freezers.add(id: 'Freezer2',
                       location: HPXML::LocationLivingSpace,
                       rated_annual_kwh: 400,
                       weekday_fractions: '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041',
                       weekend_fractions: '0.040, 0.039, 0.038, 0.037, 0.036, 0.036, 0.038, 0.040, 0.041, 0.041, 0.040, 0.040, 0.042, 0.042, 0.042, 0.041, 0.044, 0.048, 0.050, 0.048, 0.047, 0.046, 0.044, 0.041',
                       monthly_multipliers: '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837')
    if hpxml_file == 'base-misc-usage-multiplier.xml'
      hpxml.freezers.each do |freezer|
        freezer.usage_multiplier = 0.9
      end
    end
  end
end

def set_hpxml_dehumidifier(hpxml_file, hpxml)
  if ['base-appliances-dehumidifier.xml'].include? hpxml_file
    hpxml.dehumidifiers.add(id: 'Dehumidifier',
                            type: HPXML::DehumidifierTypePortable,
                            capacity: 40,
                            energy_factor: 1.8,
                            rh_setpoint: 0.5,
                            fraction_served: 1.0,
                            location: HPXML::LocationLivingSpace)
  elsif ['base-appliances-dehumidifier-ief-portable.xml'].include? hpxml_file
    hpxml.dehumidifiers[0].energy_factor = nil
    hpxml.dehumidifiers[0].integrated_energy_factor = 1.5
  elsif ['base-appliances-dehumidifier-ief-whole-home.xml'].include? hpxml_file
    hpxml.dehumidifiers[0].type = HPXML::DehumidifierTypeWholeHome
  elsif ['base-appliances-dehumidifier-multiple.xml'].include? hpxml_file
    hpxml.dehumidifiers[0].fraction_served = 0.5
    hpxml.dehumidifiers.add(id: 'Dehumidifier2',
                            type: HPXML::DehumidifierTypePortable,
                            capacity: 30,
                            energy_factor: 1.6,
                            rh_setpoint: 0.5,
                            fraction_served: 0.25,
                            location: HPXML::LocationLivingSpace)
  elsif ['invalid_files/dehumidifier-setpoints.xml'].include? hpxml_file
    hpxml.dehumidifiers[1].rh_setpoint = 0.55
  elsif ['invalid_files/dehumidifier-fraction-served.xml'].include? hpxml_file
    hpxml.dehumidifiers[1].fraction_served = 0.6
  end
end

def set_hpxml_cooking_range(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.cooking_ranges.add(id: 'Range',
                             location: HPXML::LocationLivingSpace,
                             fuel_type: HPXML::FuelTypeElectricity,
                             is_induction: false)
  elsif ['base-appliances-none.xml'].include? hpxml_file
    hpxml.cooking_ranges.clear
  elsif ['base-bldgtype-multifamily-adjacent-to-multiple.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].location = HPXML::LocationLivingSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].location = HPXML::LocationOtherHousingUnit
  elsif ['base-bldgtype-multifamily-adjacent-to-other-heated-space.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].location = HPXML::LocationOtherHeatedSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].location = HPXML::LocationOtherMultifamilyBufferSpace
  elsif ['base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].location = HPXML::LocationOtherNonFreezingSpace
  elsif ['base-appliances-gas.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].fuel_type = HPXML::FuelTypeNaturalGas
    hpxml.cooking_ranges[0].is_induction = false
  elsif ['base-appliances-propane.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].fuel_type = HPXML::FuelTypePropane
    hpxml.cooking_ranges[0].is_induction = false
  elsif ['base-appliances-oil.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].fuel_type = HPXML::FuelTypeOil
  elsif ['base-appliances-coal.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].fuel_type = HPXML::FuelTypeCoal
  elsif ['base-appliances-wood.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].fuel_type = HPXML::FuelTypeWoodCord
    hpxml.cooking_ranges[0].is_induction = false
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].location = HPXML::LocationBasementUnconditioned
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].location = HPXML::LocationBasementConditioned
  elsif ['base-enclosure-garage.xml',
         'invalid_files/cooking-range-location.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].location = HPXML::LocationGarage
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].is_induction = nil
    hpxml.cooking_ranges[0].location = nil
  elsif ['base-misc-usage-multiplier.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].usage_multiplier = 0.9
  elsif ['base-misc-loads-large-uncommon.xml'].include? hpxml_file
    hpxml.cooking_ranges[0].weekday_fractions = '0.007, 0.007, 0.004, 0.004, 0.007, 0.011, 0.025, 0.042, 0.046, 0.048, 0.042, 0.050, 0.057, 0.046, 0.057, 0.044, 0.092, 0.150, 0.117, 0.060, 0.035, 0.025, 0.016, 0.011'
    hpxml.cooking_ranges[0].weekend_fractions = '0.007, 0.007, 0.004, 0.004, 0.007, 0.011, 0.025, 0.042, 0.046, 0.048, 0.042, 0.050, 0.057, 0.046, 0.057, 0.044, 0.092, 0.150, 0.117, 0.060, 0.035, 0.025, 0.016, 0.011'
    hpxml.cooking_ranges[0].monthly_multipliers = '1.097, 1.097, 0.991, 0.987, 0.991, 0.890, 0.896, 0.896, 0.890, 1.085, 1.085, 1.097'
  end
end

def set_hpxml_oven(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.ovens.add(id: 'Oven',
                    is_convection: false)
  elsif ['base-appliances-none.xml'].include? hpxml_file
    hpxml.ovens.clear
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.ovens[0].is_convection = nil
  end
end

def set_hpxml_lighting(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.lighting_groups.add(id: 'Lighting_CFL_Interior',
                              location: HPXML::LocationInterior,
                              fraction_of_units_in_location: 0.4,
                              lighting_type: HPXML::LightingTypeCFL)
    hpxml.lighting_groups.add(id: 'Lighting_CFL_Exterior',
                              location: HPXML::LocationExterior,
                              fraction_of_units_in_location: 0.4,
                              lighting_type: HPXML::LightingTypeCFL)
    hpxml.lighting_groups.add(id: 'Lighting_CFL_Garage',
                              location: HPXML::LocationGarage,
                              fraction_of_units_in_location: 0.4,
                              lighting_type: HPXML::LightingTypeCFL)
    hpxml.lighting_groups.add(id: 'Lighting_LFL_Interior',
                              location: HPXML::LocationInterior,
                              fraction_of_units_in_location: 0.1,
                              lighting_type: HPXML::LightingTypeLFL)
    hpxml.lighting_groups.add(id: 'Lighting_LFL_Exterior',
                              location: HPXML::LocationExterior,
                              fraction_of_units_in_location: 0.1,
                              lighting_type: HPXML::LightingTypeLFL)
    hpxml.lighting_groups.add(id: 'Lighting_LFL_Garage',
                              location: HPXML::LocationGarage,
                              fraction_of_units_in_location: 0.1,
                              lighting_type: HPXML::LightingTypeLFL)
    hpxml.lighting_groups.add(id: 'Lighting_LED_Interior',
                              location: HPXML::LocationInterior,
                              fraction_of_units_in_location: 0.25,
                              lighting_type: HPXML::LightingTypeLED)
    hpxml.lighting_groups.add(id: 'Lighting_LED_Exterior',
                              location: HPXML::LocationExterior,
                              fraction_of_units_in_location: 0.25,
                              lighting_type: HPXML::LightingTypeLED)
    hpxml.lighting_groups.add(id: 'Lighting_LED_Garage',
                              location: HPXML::LocationGarage,
                              fraction_of_units_in_location: 0.25,
                              lighting_type: HPXML::LightingTypeLED)
  elsif ['invalid_files/lighting-fractions.xml'].include? hpxml_file
    hpxml.lighting_groups[0].fraction_of_units_in_location = 0.8
  elsif ['base-misc-usage-multiplier.xml'].include? hpxml_file
    hpxml.lighting.interior_usage_multiplier = 0.9
    hpxml.lighting.garage_usage_multiplier = 0.9
    hpxml.lighting.exterior_usage_multiplier = 0.9
  elsif ['base-lighting-none.xml'].include? hpxml_file
    hpxml.lighting_groups.clear
  end
end

def set_hpxml_ceiling_fans(hpxml_file, hpxml)
  if ['base-lighting-ceiling-fans.xml'].include? hpxml_file
    hpxml.ceiling_fans.add(id: 'CeilingFan',
                           efficiency: 100,
                           quantity: 4)
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.ceiling_fans.add(id: 'CeilingFan',
                           efficiency: nil,
                           quantity: nil)
  end
end

def set_hpxml_pools(hpxml_file, hpxml)
  if ['base-misc-loads-large-uncommon.xml',
      'base-misc-usage-multiplier.xml'].include? hpxml_file
    hpxml.pools.add(id: 'Pool',
                    type: HPXML::TypeUnknown,
                    pump_type: HPXML::TypeUnknown,
                    pump_kwh_per_year: 2700,
                    pump_weekday_fractions: '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003',
                    pump_weekend_fractions: '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003',
                    pump_monthly_multipliers: '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154',
                    heater_type: HPXML::HeaterTypeGas,
                    heater_load_units: HPXML::UnitsThermPerYear,
                    heater_load_value: 500,
                    heater_weekday_fractions: '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003',
                    heater_weekend_fractions: '0.003, 0.003, 0.003, 0.004, 0.008, 0.015, 0.026, 0.044, 0.084, 0.121, 0.127, 0.121, 0.120, 0.090, 0.075, 0.061, 0.037, 0.023, 0.013, 0.008, 0.004, 0.003, 0.003, 0.003',
                    heater_monthly_multipliers: '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154')
    if hpxml_file == 'base-misc-usage-multiplier.xml'
      hpxml.pools.each do |pool|
        pool.pump_usage_multiplier = 0.9
        pool.heater_usage_multiplier = 0.9
      end
    end
  elsif ['base-misc-loads-large-uncommon2.xml'].include? hpxml_file
    hpxml.pools[0].heater_type = HPXML::TypeNone
  end
end

def set_hpxml_hot_tubs(hpxml_file, hpxml)
  if ['base-misc-loads-large-uncommon.xml',
      'base-misc-usage-multiplier.xml'].include? hpxml_file
    hpxml.hot_tubs.add(id: 'HotTub',
                       type: HPXML::TypeUnknown,
                       pump_type: HPXML::TypeUnknown,
                       pump_kwh_per_year: 1000,
                       pump_weekday_fractions: '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024',
                       pump_weekend_fractions: '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024',
                       pump_monthly_multipliers: '0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837',
                       heater_type: HPXML::HeaterTypeElectricResistance,
                       heater_load_units: HPXML::UnitsKwhPerYear,
                       heater_load_value: 1300,
                       heater_weekday_fractions: '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024',
                       heater_weekend_fractions: '0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024',
                       heater_monthly_multipliers: '0.921, 0.928, 0.921, 0.915, 0.921, 1.160, 1.158, 1.158, 1.160, 0.921, 0.915, 0.921')
    if hpxml_file == 'base-misc-usage-multiplier.xml'
      hpxml.hot_tubs.each do |hot_tub|
        hot_tub.pump_usage_multiplier = 0.9
        hot_tub.heater_usage_multiplier = 0.9
      end
    end
  elsif ['base-misc-loads-large-uncommon2.xml'].include? hpxml_file
    hpxml.hot_tubs[0].heater_type = HPXML::HeaterTypeHeatPump
    hpxml.hot_tubs[0].heater_load_value /= 5.0
  end
end

def set_hpxml_lighting_schedule(hpxml_file, hpxml)
  if ['base-lighting-detailed.xml'].include? hpxml_file
    hpxml.lighting.interior_weekday_fractions = '0.124, 0.074, 0.050, 0.050, 0.053, 0.140, 0.330, 0.420, 0.430, 0.424, 0.411, 0.394, 0.382, 0.378, 0.378, 0.379, 0.386, 0.412, 0.484, 0.619, 0.783, 0.880, 0.597, 0.249'
    hpxml.lighting.interior_weekend_fractions = '0.124, 0.074, 0.050, 0.050, 0.053, 0.140, 0.330, 0.420, 0.430, 0.424, 0.411, 0.394, 0.382, 0.378, 0.378, 0.379, 0.386, 0.412, 0.484, 0.619, 0.783, 0.880, 0.597, 0.249'
    hpxml.lighting.interior_monthly_multipliers = '1.075, 1.064951905, 1.0375, 1.0, 0.9625, 0.935048095, 0.925, 0.935048095, 0.9625, 1.0, 1.0375, 1.064951905'
    hpxml.lighting.exterior_weekday_fractions = '0.046, 0.046, 0.046, 0.046, 0.046, 0.037, 0.035, 0.034, 0.033, 0.028, 0.022, 0.015, 0.012, 0.011, 0.011, 0.012, 0.019, 0.037, 0.049, 0.065, 0.091, 0.105, 0.091, 0.063'
    hpxml.lighting.exterior_weekend_fractions = '0.046, 0.046, 0.045, 0.045, 0.046, 0.045, 0.044, 0.041, 0.036, 0.03, 0.024, 0.016, 0.012, 0.011, 0.011, 0.012, 0.019, 0.038, 0.048, 0.06, 0.083, 0.098, 0.085, 0.059'
    hpxml.lighting.exterior_monthly_multipliers = '1.248, 1.257, 0.993, 0.989, 0.993, 0.827, 0.821, 0.821, 0.827, 0.99, 0.987, 1.248'
    hpxml.lighting.garage_weekday_fractions = '0.046, 0.046, 0.046, 0.046, 0.046, 0.037, 0.035, 0.034, 0.033, 0.028, 0.022, 0.015, 0.012, 0.011, 0.011, 0.012, 0.019, 0.037, 0.049, 0.065, 0.091, 0.105, 0.091, 0.063'
    hpxml.lighting.garage_weekend_fractions = '0.046, 0.046, 0.045, 0.045, 0.046, 0.045, 0.044, 0.041, 0.036, 0.03, 0.024, 0.016, 0.012, 0.011, 0.011, 0.012, 0.019, 0.038, 0.048, 0.06, 0.083, 0.098, 0.085, 0.059'
    hpxml.lighting.garage_monthly_multipliers = '1.248, 1.257, 0.993, 0.989, 0.993, 0.827, 0.821, 0.821, 0.827, 0.99, 0.987, 1.248'
    hpxml.lighting.holiday_exists = true
    hpxml.lighting.holiday_kwh_per_day = 1.1
    hpxml.lighting.holiday_period_begin_month = 11
    hpxml.lighting.holiday_period_begin_day = 24
    hpxml.lighting.holiday_period_end_month = 1
    hpxml.lighting.holiday_period_end_day = 6
    hpxml.lighting.holiday_weekday_fractions = '0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.008, 0.098, 0.168, 0.194, 0.284, 0.192, 0.037, 0.019'
    hpxml.lighting.holiday_weekend_fractions = '0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.008, 0.098, 0.168, 0.194, 0.284, 0.192, 0.037, 0.019'
  end
end

def set_hpxml_plug_loads(hpxml_file, hpxml)
  if ['ASHRAE_Standard_140/L100AC.xml',
      'ASHRAE_Standard_140/L100AL.xml'].include? hpxml_file
    hpxml.plug_loads.add(id: 'PlugLoadMisc',
                         plug_load_type: HPXML::PlugLoadTypeOther,
                         kWh_per_year: 7302,
                         frac_sensible: 0.822,
                         frac_latent: 0.178)
  elsif ['ASHRAE_Standard_140/L170AC.xml',
         'ASHRAE_Standard_140/L170AL.xml'].include? hpxml_file
    hpxml.plug_loads[0].kWh_per_year = 0
  elsif not hpxml_file.include?('ASHRAE_Standard_140')
    if ['base.xml'].include? hpxml_file
      hpxml.plug_loads.add(id: 'PlugLoadMisc',
                           plug_load_type: HPXML::PlugLoadTypeOther)
      hpxml.plug_loads.add(id: 'PlugLoadMisc2',
                           plug_load_type: HPXML::PlugLoadTypeTelevision)
    elsif ['base-misc-usage-multiplier.xml'].include? hpxml_file
      hpxml.plug_loads.each do |plug_load|
        plug_load.usage_multiplier = 0.9
      end
    end
    if ['base-misc-defaults.xml'].include? hpxml_file
      hpxml.plug_loads.each do |plug_load|
        plug_load.kWh_per_year = nil
        plug_load.frac_sensible = nil
        plug_load.frac_latent = nil
      end
    elsif ['base-misc-loads-none.xml'].include? hpxml_file
      hpxml.plug_loads.clear
      hpxml.plug_loads.add(id: 'PlugLoadMisc',
                           plug_load_type: HPXML::PlugLoadTypeOther,
                           kWh_per_year: 0)
    elsif ['base-misc-loads-large-uncommon.xml'].include? hpxml_file
      hpxml.plug_loads[0].weekday_fractions = '0.035, 0.033, 0.032, 0.031, 0.032, 0.033, 0.037, 0.042, 0.043, 0.043, 0.043, 0.044, 0.045, 0.045, 0.044, 0.046, 0.048, 0.052, 0.053, 0.05, 0.047, 0.045, 0.04, 0.036'
      hpxml.plug_loads[0].weekend_fractions = '0.035, 0.033, 0.032, 0.031, 0.032, 0.033, 0.037, 0.042, 0.043, 0.043, 0.043, 0.044, 0.045, 0.045, 0.044, 0.046, 0.048, 0.052, 0.053, 0.05, 0.047, 0.045, 0.04, 0.036'
      hpxml.plug_loads[0].monthly_multipliers = '1.248, 1.257, 0.993, 0.989, 0.993, 0.827, 0.821, 0.821, 0.827, 0.99, 0.987, 1.248'
      hpxml.plug_loads[1].weekday_fractions = '0.045, 0.019, 0.01, 0.001, 0.001, 0.001, 0.005, 0.009, 0.018, 0.026, 0.032, 0.038, 0.04, 0.041, 0.043, 0.045, 0.05, 0.055, 0.07, 0.085, 0.097, 0.108, 0.089, 0.07'
      hpxml.plug_loads[1].weekend_fractions = '0.045, 0.019, 0.01, 0.001, 0.001, 0.001, 0.005, 0.009, 0.018, 0.026, 0.032, 0.038, 0.04, 0.041, 0.043, 0.045, 0.05, 0.055, 0.07, 0.085, 0.097, 0.108, 0.089, 0.07'
      hpxml.plug_loads[1].monthly_multipliers = '1.137, 1.129, 0.961, 0.969, 0.961, 0.993, 0.996, 0.96, 0.993, 0.867, 0.86, 1.137'
      hpxml.plug_loads.add(id: 'PlugLoadMisc3',
                           plug_load_type: HPXML::PlugLoadTypeElectricVehicleCharging,
                           kWh_per_year: 1500,
                           weekday_fractions: '0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042',
                           weekend_fractions: '0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042, 0.042',
                           monthly_multipliers: '1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1')
      hpxml.plug_loads.add(id: 'PlugLoadMisc4',
                           plug_load_type: HPXML::PlugLoadTypeWellPump,
                           kWh_per_year: 475,
                           weekday_fractions: '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065',
                           weekend_fractions: '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065',
                           monthly_multipliers: '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154')
    elsif ['invalid_files/frac-sensible-plug-load.xml'].include? hpxml_file
      hpxml.plug_loads[0].frac_sensible = -0.1
    elsif ['invalid_files/frac-total-plug-load.xml'].include? hpxml_file
      hpxml.plug_loads[0].frac_latent = 1.0 - hpxml.plug_loads[0].frac_sensible + 0.1
    else
      cfa = hpxml.building_construction.conditioned_floor_area
      nbeds = hpxml.building_construction.number_of_bedrooms

      kWh_per_year, frac_sensible, frac_latent = MiscLoads.get_residual_mels_default_values(cfa)
      hpxml.plug_loads[0].kWh_per_year = kWh_per_year
      hpxml.plug_loads[0].frac_sensible = frac_sensible.round(3)
      hpxml.plug_loads[0].frac_latent = frac_latent.round(3)

      kWh_per_year, frac_sensible, frac_latent = MiscLoads.get_televisions_default_values(cfa, nbeds)
      hpxml.plug_loads[1].kWh_per_year = kWh_per_year
    end
  end
  if hpxml_file.include?('ASHRAE_Standard_140')
    hpxml.plug_loads[0].weekday_fractions = '0.0203, 0.0203, 0.0203, 0.0203, 0.0203, 0.0339, 0.0426, 0.0852, 0.0497, 0.0304, 0.0304, 0.0406, 0.0304, 0.0254, 0.0264, 0.0264, 0.0386, 0.0416, 0.0447, 0.0700, 0.0700, 0.0731, 0.0731, 0.0660'
    hpxml.plug_loads[0].weekend_fractions = '0.0203, 0.0203, 0.0203, 0.0203, 0.0203, 0.0339, 0.0426, 0.0852, 0.0497, 0.0304, 0.0304, 0.0406, 0.0304, 0.0254, 0.0264, 0.0264, 0.0386, 0.0416, 0.0447, 0.0700, 0.0700, 0.0731, 0.0731, 0.0660'
    hpxml.plug_loads[0].monthly_multipliers = '1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0'
  elsif ['base-misc-defaults.xml'].include? hpxml_file
    hpxml.plug_loads[0].weekday_fractions = nil
    hpxml.plug_loads[0].weekend_fractions = nil
    hpxml.plug_loads[0].monthly_multipliers = nil
  end
end

def set_hpxml_fuel_loads(hpxml_file, hpxml)
  if ['base-misc-loads-large-uncommon.xml',
      'base-misc-usage-multiplier.xml'].include? hpxml_file
    hpxml.fuel_loads.add(id: 'FuelLoadMisc',
                         fuel_load_type: HPXML::FuelLoadTypeGrill,
                         fuel_type: HPXML::FuelTypePropane,
                         therm_per_year: 25,
                         weekday_fractions: '0.004, 0.001, 0.001, 0.002, 0.007, 0.012, 0.029, 0.046, 0.044, 0.041, 0.044, 0.046, 0.042, 0.038, 0.049, 0.059, 0.110, 0.161, 0.115, 0.070, 0.044, 0.019, 0.013, 0.007',
                         weekend_fractions: '0.004, 0.001, 0.001, 0.002, 0.007, 0.012, 0.029, 0.046, 0.044, 0.041, 0.044, 0.046, 0.042, 0.038, 0.049, 0.059, 0.110, 0.161, 0.115, 0.070, 0.044, 0.019, 0.013, 0.007',
                         monthly_multipliers: '1.097, 1.097, 0.991, 0.987, 0.991, 0.890, 0.896, 0.896, 0.890, 1.085, 1.085, 1.097')
    hpxml.fuel_loads.add(id: 'FuelLoadMisc2',
                         fuel_load_type: HPXML::FuelLoadTypeLighting,
                         fuel_type: HPXML::FuelTypeNaturalGas,
                         therm_per_year: 28,
                         weekday_fractions: '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065',
                         weekend_fractions: '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065',
                         monthly_multipliers: '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154')
    hpxml.fuel_loads.add(id: 'FuelLoadMisc3',
                         fuel_load_type: HPXML::FuelLoadTypeFireplace,
                         fuel_type: HPXML::FuelTypeWoodCord,
                         frac_sensible: 0.5,
                         frac_latent: 0.1,
                         therm_per_year: 55,
                         weekday_fractions: '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065',
                         weekend_fractions: '0.044, 0.023, 0.019, 0.015, 0.016, 0.018, 0.026, 0.033, 0.033, 0.032, 0.033, 0.033, 0.032, 0.032, 0.032, 0.033, 0.045, 0.057, 0.066, 0.076, 0.081, 0.086, 0.075, 0.065',
                         monthly_multipliers: '1.154, 1.161, 1.013, 1.010, 1.013, 0.888, 0.883, 0.883, 0.888, 0.978, 0.974, 1.154')
    if hpxml_file == 'base-misc-usage-multiplier.xml'
      hpxml.fuel_loads.each do |fuel_load|
        fuel_load.usage_multiplier = 0.9
      end
    end
  elsif ['base-misc-loads-large-uncommon2.xml'].include? hpxml_file
    hpxml.fuel_loads[0].fuel_type = HPXML::FuelTypeOil
    hpxml.fuel_loads[2].fuel_type = HPXML::FuelTypeWoodPellets
  elsif ['invalid_files/frac-sensible-fuel-load.xml'].include? hpxml_file
    hpxml.fuel_loads[0].frac_sensible = -0.1
  elsif ['invalid_files/frac-total-fuel-load.xml'].include? hpxml_file
    hpxml.fuel_loads[0].frac_sensible = 0.8
    hpxml.fuel_loads[0].frac_latent = 1.0 - hpxml.fuel_loads[0].frac_sensible + 0.1
  end
end

def download_epws
  require_relative 'HPXMLtoOpenStudio/resources/util'

  require 'tempfile'
  tmpfile = Tempfile.new('epw')

  UrlResolver.fetch('https://data.nrel.gov/system/files/128/tmy3s-cache-csv.zip', tmpfile)

  puts 'Extracting weather files...'
  weather_dir = File.join(File.dirname(__FILE__), 'weather')
  unzip_file = OpenStudio::UnzipFile.new(tmpfile.path.to_s)
  unzip_file.extractAllFiles(OpenStudio::toPath(weather_dir))

  num_epws_actual = Dir[File.join(weather_dir, '*.epw')].count
  puts "#{num_epws_actual} weather files are available in the weather directory."
  puts 'Completed.'
  exit!
end

def get_elements_from_sample_files(hpxml_docs)
  elements_being_used = []
  hpxml_docs.each do |xml, hpxml_doc|
    root = XMLHelper.get_element(hpxml_doc, '/HPXML')
    root.each_node do |node|
      next unless node.is_a?(Oga::XML::Element)

      ancestors = []
      node.each_ancestor do |parent_node|
        ancestors << ['h:', parent_node.name].join()
      end
      parent_element_xpath = ancestors.reverse
      child_element_xpath = ['h:', node.name].join()
      element_xpath = [parent_element_xpath, child_element_xpath].join('/')

      next if element_xpath.include? 'extension'

      elements_being_used << element_xpath if not elements_being_used.include? element_xpath
    end
  end

  return elements_being_used
end

def create_schematron_hpxml_validator(hpxml_docs)
  elements_in_sample_files = get_elements_from_sample_files(hpxml_docs)

  base_elements_xsd = File.read(File.join(File.dirname(__FILE__), 'HPXMLtoOpenStudio', 'resources', 'BaseElements.xsd'))
  base_elements_xsd_doc = Oga.parse_xml(base_elements_xsd)

  # construct dictionary for enumerations and min/max values of HPXML data types
  hpxml_data_types_xsd = File.read(File.join(File.dirname(__FILE__), 'HPXMLtoOpenStudio', 'resources', 'HPXMLDataTypes.xsd'))
  hpxml_data_types_xsd_doc = Oga.parse_xml(hpxml_data_types_xsd)
  hpxml_data_types_dict = {}
  hpxml_data_types_xsd_doc.xpath('//xs:simpleType | //xs:complexType').each do |simple_type_element|
    enums = []
    simple_type_element.xpath('xs:restriction/xs:enumeration').each do |enum|
      enums << enum.get('value')
    end
    minInclusive_element = simple_type_element.at_xpath('xs:restriction/xs:minInclusive')
    min_inclusive = minInclusive_element.get('value') if not minInclusive_element.nil?
    maxInclusive_element = simple_type_element.at_xpath('xs:restriction/xs:maxInclusive')
    max_inclusive = maxInclusive_element.get('value') if not maxInclusive_element.nil?
    minExclusive_element = simple_type_element.at_xpath('xs:restriction/xs:minExclusive')
    min_exclusive = minExclusive_element.get('value') if not minExclusive_element.nil?
    maxExclusive_element = simple_type_element.at_xpath('xs:restriction/xs:maxExclusive')
    max_exclusive = maxExclusive_element.get('value') if not maxExclusive_element.nil?

    simple_type_element_name = simple_type_element.get('name')
    hpxml_data_types_dict[simple_type_element_name] = {}
    hpxml_data_types_dict[simple_type_element_name][:enums] = enums
    hpxml_data_types_dict[simple_type_element_name][:min_inclusive] = min_inclusive
    hpxml_data_types_dict[simple_type_element_name][:max_inclusive] = max_inclusive
    hpxml_data_types_dict[simple_type_element_name][:min_exclusive] = min_exclusive
    hpxml_data_types_dict[simple_type_element_name][:max_exclusive] = max_exclusive
  end

  # construct HPXMLvalidator.xml
  hpxml_validator = XMLHelper.create_doc(version = '1.0', encoding = 'UTF-8')
  root = XMLHelper.add_element(hpxml_validator, 'sch:schema')
  XMLHelper.add_attribute(root, 'xmlns:sch', 'http://purl.oclc.org/dsdl/schematron')
  XMLHelper.add_element(root, 'sch:title', 'HPXML Schematron Validator: HPXML.xsd', :string)
  name_space = XMLHelper.add_element(root, 'sch:ns')
  XMLHelper.add_attribute(name_space, 'uri', 'http://hpxmlonline.com/2019/10')
  XMLHelper.add_attribute(name_space, 'prefix', 'h')
  pattern = XMLHelper.add_element(root, 'sch:pattern')

  # construct complexType and group elements dictionary
  complex_type_or_group_dict = {}
  ['//xs:complexType', '//xs:group', '//xs:element'].each do |param|
    base_elements_xsd_doc.xpath(param).each do |param_type|
      next if param_type.name == 'element' && (not ['XMLTransactionHeaderInformation', 'ProjectStatus', 'SoftwareInfo'].include?(param_type.get('name')))
      next if param_type.get('name').nil?

      param_type_name = param_type.get('name')
      complex_type_or_group_dict[param_type_name] = {}

      param_type.each_node do |element|
        next unless element.is_a? Oga::XML::Element
        next unless (element.name == 'element' || element.name == 'group')
        next if element.name == 'element' && (element.get('name').nil? && element.get('ref').nil?)
        next if element.name == 'group' && element.get('ref').nil?

        ancestors = []
        element.each_ancestor do |node|
          next if node.get('name').nil?
          next if node.get('name') == param_type.get('name') # exclude complexType name from element xpath

          ancestors << node.get('name')
        end

        parent_element_names = ancestors.reverse
        if element.name == 'element'
          child_element_name = element.get('name')
          child_element_name = element.get('ref') if child_element_name.nil? # Backup
          element_type = element.get('type')
          element_type = element.get('ref') if element_type.nil? # Backup
        elsif element.name == 'group'
          child_element_name = nil # exclude group name from the element's xpath
          element_type = element.get('ref')
        end
        element_xpath = parent_element_names.push(child_element_name)
        complex_type_or_group_dict[param_type_name][element_xpath] = element_type
      end
    end
  end

  element_xpaths = {}
  top_level_elements_of_interest = elements_in_sample_files.map { |e| e.split('/')[1].gsub('h:', '') }.uniq
  top_level_elements_of_interest.each do |element|
    top_level_element = []
    top_level_element << element
    top_level_element_type = element
    get_element_full_xpaths(element_xpaths, complex_type_or_group_dict, top_level_element, top_level_element_type)
  end

  # Add enumeration and min/max numeric values
  rules = {}
  element_xpaths.each do |element_xpath, element_type|
    next if element_type.nil?

    # Skip element xpaths not being used in sample files
    element_xpath_with_prefix = element_xpath.compact.map { |e| "h:#{e}" }
    context_xpath = element_xpath_with_prefix.join('/').chomp('/')
    next unless elements_in_sample_files.any? { |item| item.include? context_xpath }

    hpxml_data_type_name = [element_type, '_simple'].join() # FUTURE: This may need to be improved later since enumeration and minimum/maximum values cannot be guaranteed to always be placed within simpleType.
    hpxml_data_type = hpxml_data_types_dict[hpxml_data_type_name]
    hpxml_data_type = hpxml_data_types_dict[element_type] if hpxml_data_type.nil? # Backup
    if hpxml_data_type.nil?
      fail "Could not find data type name for '#{element_type}'."
    end

    next if hpxml_data_type[:enums].empty? && hpxml_data_type[:min_inclusive].nil? && hpxml_data_type[:max_inclusive].nil? && hpxml_data_type[:min_exclusive].nil? && hpxml_data_type[:max_exclusive].nil?

    element_name = context_xpath.split('/')[-1]
    context_xpath = context_xpath.split('/')[0..-2].join('/').chomp('/').prepend('/h:HPXML/')
    rule = rules[context_xpath]
    if rule.nil?
      # Need new rule
      rule = XMLHelper.add_element(pattern, 'sch:rule')
      XMLHelper.add_attribute(rule, 'context', context_xpath)
      rules[context_xpath] = rule
    end

    if not hpxml_data_type[:enums].empty?
      assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected #{element_name.gsub('h:', '')} to be \"#{hpxml_data_type[:enums].join('" or "')}\"", :string)
      XMLHelper.add_attribute(assertion, 'role', 'ERROR')
      XMLHelper.add_attribute(assertion, 'test', "#{element_name}[#{hpxml_data_type[:enums].map { |e| "text()=\"#{e}\"" }.join(' or ')}] or not(#{element_name})")
    else
      if hpxml_data_type[:min_inclusive]
        assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected #{element_name.gsub('h:', '')} to be greater than or equal to #{hpxml_data_type[:min_inclusive]}", :string)
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "number(#{element_name}) &gt;= #{hpxml_data_type[:min_inclusive]} or not(#{element_name})")
      end
      if hpxml_data_type[:max_inclusive]
        assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected #{element_name.gsub('h:', '')} to be less than or equal to #{hpxml_data_type[:max_inclusive]}", :string)
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "number(#{element_name}) &lt;= #{hpxml_data_type[:max_inclusive]} or not(#{element_name})")
      end
      if hpxml_data_type[:min_exclusive]
        assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected #{element_name.gsub('h:', '')} to be greater than #{hpxml_data_type[:min_exclusive]}", :string)
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "number(#{element_name}) &gt; #{hpxml_data_type[:min_exclusive]} or not(#{element_name})")
      end
      if hpxml_data_type[:max_exclusive]
        assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected #{element_name.gsub('h:', '')} to be less than #{hpxml_data_type[:max_exclusive]}", :string)
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "number(#{element_name}) &lt; #{hpxml_data_type[:max_exclusive]} or not(#{element_name})")
      end
    end
  end

  # Add ID/IDref checks
  # TODO: Dynamically obtain these lists
  id_names = ['SystemIdentifier',
              'BuildingID']
  idref_names = ['AttachedToRoof',
                 'AttachedToFrameFloor',
                 'AttachedToSlab',
                 'AttachedToFoundationWall',
                 'AttachedToWall',
                 'DistributionSystem',
                 'AttachedToHVACDistributionSystem',
                 'RelatedHVACSystem',
                 'ConnectedTo']
  elements_in_sample_files.each do |element_xpath|
    element_name = element_xpath.split('/')[-1].gsub('h:', '')
    context_xpath = "/#{element_xpath.split('/')[0..-2].join('/')}"
    if id_names.include? element_name
      rule = rules[context_xpath]
      if rule.nil?
        # Need new rule
        rule = XMLHelper.add_element(pattern, 'sch:rule')
        XMLHelper.add_attribute(rule, 'context', context_xpath)
        rules[context_xpath] = rule
      end
      assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected id attribute for #{element_name}", :string)
      XMLHelper.add_attribute(assertion, 'role', 'ERROR')
      XMLHelper.add_attribute(assertion, 'test', "count(h:#{element_name}[@id]) = 1 or not (h:#{element_name})")
    elsif idref_names.include? element_name
      rule = rules[context_xpath]
      if rule.nil?
        # Need new rule
        rule = XMLHelper.add_element(pattern, 'sch:rule')
        XMLHelper.add_attribute(rule, 'context', context_xpath)
        rules[context_xpath] = rule
      end
      assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected idref attribute for #{element_name}", :string)
      XMLHelper.add_attribute(assertion, 'role', 'ERROR')
      XMLHelper.add_attribute(assertion, 'test', "count(h:#{element_name}[@idref]) = 1 or not(h:#{element_name})")
    end
  end

  XMLHelper.write_file(hpxml_validator, File.join(File.dirname(__FILE__), 'HPXMLtoOpenStudio', 'resources', 'HPXMLvalidator.xml'))
end

def get_element_full_xpaths(element_xpaths, complex_type_or_group_dict, element_xpath, element_type)
  if not complex_type_or_group_dict.keys.include? element_type
    element_xpaths[element_xpath] = element_type
  else
    complex_type_or_group = deep_copy_object(complex_type_or_group_dict[element_type])
    complex_type_or_group.each do |k, v|
      child_element_xpath = k.unshift(element_xpath).flatten!
      child_element_type = v

      if not complex_type_or_group_dict.keys.include? child_element_type
        element_xpaths[child_element_xpath] = child_element_type
        next
      end

      get_element_full_xpaths(element_xpaths, complex_type_or_group_dict, child_element_xpath, child_element_type)
    end
  end
end

def deep_copy_object(obj)
  return Marshal.load(Marshal.dump(obj))
end

command_list = [:update_measures, :cache_weather, :create_release_zips, :download_weather]

def display_usage(command_list)
  puts "Usage: openstudio #{File.basename(__FILE__)} [COMMAND]\nCommands:\n  " + command_list.join("\n  ")
end

if ARGV.size == 0
  puts 'ERROR: Missing command.'
  display_usage(command_list)
  exit!
elsif ARGV.size > 1
  puts 'ERROR: Too many commands.'
  display_usage(command_list)
  exit!
elsif not command_list.include? ARGV[0].to_sym
  puts "ERROR: Invalid command '#{ARGV[0]}'."
  display_usage(command_list)
  exit!
end

if ARGV[0].to_sym == :update_measures
  # Prevent NREL error regarding U: drive when not VPNed in
  ENV['HOME'] = 'C:' if !ENV['HOME'].nil? && ENV['HOME'].start_with?('U:')
  ENV['HOMEDRIVE'] = 'C:\\' if !ENV['HOMEDRIVE'].nil? && ENV['HOMEDRIVE'].start_with?('U:')

  require 'oga'
  require_relative 'HPXMLtoOpenStudio/resources/xmlhelper'

  # Create sample/test OSWs
  create_osws()

  # Create sample/test HPXMLs
  hpxml_docs = create_hpxmls()

  # Create Schematron file that reflects HPXML schema
  puts 'Generating HPXMLvalidator.xml...'
  create_schematron_hpxml_validator(hpxml_docs)

  # Apply rubocop
  cops = ['Layout',
          'Lint/DeprecatedClassMethods',
          'Lint/RedundantStringCoercion',
          'Style/AndOr',
          'Style/FrozenStringLiteralComment',
          'Style/HashSyntax',
          'Style/Next',
          'Style/NilComparison',
          'Style/RedundantParentheses',
          'Style/RedundantSelf',
          'Style/ReturnNil',
          'Style/SelfAssignment',
          'Style/StringLiterals',
          'Style/StringLiteralsInInterpolation']
  commands = ["\"require 'rubocop/rake_task'\"",
              "\"RuboCop::RakeTask.new(:rubocop) do |t| t.options = ['--auto-correct', '--format', 'simple', '--only', '#{cops.join(',')}'] end\"",
              '"Rake.application[:rubocop].invoke"']
  command = "#{OpenStudio.getOpenStudioCLI} -e #{commands.join(' -e ')}"
  puts 'Applying rubocop auto-correct to measures...'
  system(command)

  # Update measures XMLs
  puts 'Updating measure.xmls...'
  Dir['**/measure.xml'].each do |measure_xml|
    for n_attempt in 1..5 # For some reason CLI randomly generates errors, so try multiple times; FIXME: Fix CLI so this doesn't happen
      measure_dir = File.dirname(measure_xml)
      command = "#{OpenStudio.getOpenStudioCLI} measure -u '#{measure_dir}'"
      system(command, [:out, :err] => File::NULL)

      # Check for error
      xml_doc = XMLHelper.parse_file(measure_xml)
      err_val = XMLHelper.get_value(xml_doc, '/measure/error', :string)
      if err_val.nil?
        err_val = XMLHelper.get_value(xml_doc, '/error', :string)
      end
      if err_val.nil?
        break # Successfully updated
      else
        if n_attempt == 5
          fail "#{measure_xml}: #{err_val}" # Error generated all 5 times, fail
        else
          # Remove error from measure XML, try again
          new_lines = File.readlines(measure_xml).select { |l| !l.include?('<error>') }
          File.open(measure_xml, 'w') do |file|
            file.puts new_lines
          end
        end
      end
    end
  end

  puts 'Done.'
end

if ARGV[0].to_sym == :cache_weather
  require_relative 'HPXMLtoOpenStudio/resources/weather'

  OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Fatal)
  runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
  puts 'Creating cache *.csv for weather files...'

  Dir['weather/*.epw'].each do |epw|
    next if File.exist? epw.gsub('.epw', '.cache')

    puts "Processing #{epw}..."
    model = OpenStudio::Model::Model.new
    epw_file = OpenStudio::EpwFile.new(epw)
    OpenStudio::Model::WeatherFile.setWeatherFile(model, epw_file).get
    weather = WeatherProcess.new(model, runner)
    File.open(epw.gsub('.epw', '-cache.csv'), 'wb') do |file|
      weather.dump_to_csv(file)
    end
  end
end

if ARGV[0].to_sym == :download_weather
  download_epws
end

if ARGV[0].to_sym == :create_release_zips
  require_relative 'HPXMLtoOpenStudio/resources/version'

  release_map = { File.join(File.dirname(__FILE__), "OpenStudio-HPXML-v#{Version::OS_HPXML_Version}-minimal.zip") => false,
                  File.join(File.dirname(__FILE__), "OpenStudio-HPXML-v#{Version::OS_HPXML_Version}-full.zip") => true }

  release_map.keys.each do |zip_path|
    File.delete(zip_path) if File.exist? zip_path
  end

  if ENV['CI']
    # CI doesn't have git, so default to everything
    git_files = Dir['**/*.*']
  else
    # Only include files under git version control
    command = 'git ls-files'
    begin
      git_files = `#{command}`
    rescue
      puts "Command failed: '#{command}'. Perhaps git needs to be installed?"
      exit!
    end
  end

  files = ['Changelog.md',
           'LICENSE.md',
           'HPXMLtoOpenStudio/measure.*',
           'HPXMLtoOpenStudio/resources/*.*',
           'SimulationOutputReport/measure.*',
           'SimulationOutputReport/resources/*.*',
           'BuildResidentialHPXML/measure.*',
           'BuildResidentialHPXML/resources/*.*',
           'weather/*.*',
           'workflow/*.*',
           'workflow/sample_files/*.xml',
           'workflow/tests/*test*.rb',
           'workflow/tests/ASHRAE_Standard_140/*.xml',
           'workflow/tests/base_results/*.csv',
           'documentation/index.html',
           'documentation/_static/**/*.*']

  if not ENV['CI']
    # Generate documentation
    puts 'Generating documentation...'
    command = 'sphinx-build -b singlehtml docs/source documentation'
    begin
      `#{command}`
      if not File.exist? File.join(File.dirname(__FILE__), 'documentation', 'index.html')
        puts 'Documentation was not successfully generated. Aborting...'
        exit!
      end
    rescue
      puts "Command failed: '#{command}'. Perhaps sphinx needs to be installed?"
      exit!
    end
    FileUtils.rm_r(File.join(File.dirname(__FILE__), 'documentation', '_static', 'fonts'))

    # Check if we need to download weather files for the full release zip
    num_epws_expected = 1011
    num_epws_local = 0
    files.each do |f|
      Dir[f].each do |file|
        next unless file.end_with? '.epw'

        num_epws_local += 1
      end
    end

    # Make sure we have the full set of weather files
    if num_epws_local < num_epws_expected
      puts 'Fetching all weather files...'
      command = "#{OpenStudio.getOpenStudioCLI} #{__FILE__} download_weather"
      log = `#{command}`
    end
  end

  # Create zip files
  release_map.each do |zip_path, include_all_epws|
    puts "Creating #{zip_path}..."
    zip = OpenStudio::ZipFile.new(zip_path, false)
    files.each do |f|
      Dir[f].each do |file|
        if file.start_with? 'documentation'
          # always include
        elsif include_all_epws
          if (not git_files.include? file) && (not file.start_with? 'weather')
            next
          end
        else
          if not git_files.include? file
            next
          end
        end

        zip.addFile(file, File.join('OpenStudio-HPXML', file))
      end
    end
    puts "Wrote file at #{zip_path}."
  end

  # Cleanup
  if not ENV['CI']
    FileUtils.rm_r(File.join(File.dirname(__FILE__), 'documentation'))
  end

  puts 'Done.'
end
