# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'openstudio'
if File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/hpxml-measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock on AWS
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/hpxml-measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/hpxml-measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock unit tests locally
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/hpxml-measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources')
else
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
end
require File.join(resources_path, 'meta_measure')
require File.join(resources_path, 'unit_conversions')

require_relative '../ApplyUpgrade/resources/constants'

# start the measure
class UpgradeCosts < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Upgrade Costs'
  end

  # human readable description
  def description
    return 'Measure that calculates upgrade costs.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Multiplies cost value by cost multiplier.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    return args
  end

  def num_options
    return Constants.NumApplyUpgradeOptions # Synced with ApplyUpgrade measure
  end

  def num_costs_per_option
    return Constants.NumApplyUpgradesCostsPerOption # Synced with ApplyUpgrade measure
  end

  def cost_multiplier_choices
    return Constants.CostMultiplierChoices # Synced with ApplyUpgrade measure
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    # use the built-in error checking (need model)
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Retrieve the hpxml
    hpxml_path = File.expand_path('../in.xml') # this is the defaulted hpxml
    hpxml = HPXML.new(hpxml_path: hpxml_path)

    # Report cost multipliers
    cost_multiplier_choices.each do |cost_mult_type|
      next if cost_mult_type.empty?
      next if cost_mult_type.include?('Fixed')

      cost_mult_type_str = OpenStudio::toUnderscoreCase(cost_mult_type)
      cost_mult = get_cost_multiplier(cost_mult_type, hpxml, runner)
      cost_mult = cost_mult.round(2)
      register_value(runner, cost_mult_type_str, cost_mult)
    end

    # UPGRADE NAME
    upgrade_name = get_value_from_runner_past_results(runner, 'upgrade_name', 'apply_upgrade', false)
    if upgrade_name.nil?
      register_value(runner, 'upgrade_name', '')
      runner.registerInfo('Registering (blank) for upgrade_name.')
    else
      register_value(runner, 'upgrade_name', upgrade_name)
      runner.registerInfo("Registering #{upgrade_name} for upgrade_name.")
    end

    # UPGRADE COSTS

    upgrade_cost_name = 'upgrade_cost_usd'

    # Get upgrade cost value/multiplier pairs and lifetimes from the upgrade measure
    has_costs = false
    option_cost_pairs = {}
    option_lifetimes = {}
    for option_num in 1..num_options # Sync with ApplyUpgrade measure
      option_cost_pairs[option_num] = []
      option_lifetimes[option_num] = nil
      for cost_num in 1..num_costs_per_option # Sync with ApplyUpgrade measure
        cost_value = get_value_from_runner_past_results(runner, "option_%02d_cost_#{cost_num}_value_to_apply" % option_num, 'apply_upgrade', false)
        next if cost_value.nil?

        cost_mult_type = get_value_from_runner_past_results(runner, "option_%02d_cost_#{cost_num}_multiplier_to_apply" % option_num, 'apply_upgrade', false)
        next if cost_mult_type.nil?

        has_costs = true
        option_cost_pairs[option_num] << [cost_value.to_f, cost_mult_type]
      end
      lifetime = get_value_from_runner_past_results(runner, 'option_%02d_lifetime_to_apply' % option_num, 'apply_upgrade', false)
      next if lifetime.nil?

      option_lifetimes[option_num] = lifetime.to_f
    end

    if not has_costs
      register_value(runner, upgrade_cost_name, '')
      runner.registerInfo("Registering (blank) for #{upgrade_cost_name}.")
      return true
    end

    # Obtain cost multiplier values and calculate upgrade costs
    upgrade_cost = 0.0
    option_cost_pairs.keys.each do |option_num|
      option_cost = 0.0
      option_cost_pairs[option_num].each do |cost_value, cost_mult_type|
        cost_mult = get_cost_multiplier(cost_mult_type, hpxml, runner)
        total_cost = cost_value * cost_mult
        next if total_cost == 0

        option_cost += total_cost
        runner.registerInfo("Upgrade cost addition: $#{cost_value} x #{cost_mult} [#{cost_mult_type}] = #{total_cost}.")
      end
      upgrade_cost += option_cost

      # Save option cost/lifetime to results.csv
      next unless option_cost != 0

      option_cost = option_cost.round(2)
      option_cost_name = 'option_%02d_cost_usd' % option_num
      register_value(runner, option_cost_name, option_cost)
      runner.registerInfo("Registering #{option_cost} for #{option_cost_name}.")
      next unless (not option_lifetimes[option_num].nil?) && (option_lifetimes[option_num] != 0)

      lifetime = option_lifetimes[option_num].round(2)
      option_lifetime_name = 'option_%02d_lifetime_yrs' % option_num
      register_value(runner, option_lifetime_name, lifetime)
      runner.registerInfo("Registering #{lifetime} for #{option_lifetime_name}.")
    end
    upgrade_cost = upgrade_cost.round(2)
    register_value(runner, upgrade_cost_name, upgrade_cost)
    runner.registerInfo("Registering #{upgrade_cost} for #{upgrade_cost_name}.")

    return true
  end

  def get_cost_multiplier(cost_mult_type, hpxml, runner)
    cost_mult = 0.0
    if cost_mult_type == 'Fixed (1)'
      cost_mult += 1.0
    elsif cost_mult_type == 'Wall Area, Above-Grade, Conditioned (ft^2)'
      hpxml.walls.each do |wall|
        next unless wall.is_thermal_boundary

        cost_mult += wall.area
      end
    elsif cost_mult_type == 'Wall Area, Above-Grade, Exterior (ft^2)'
      hpxml.walls.each do |wall|
        next unless wall.is_exterior

        cost_mult += wall.area
      end
    elsif cost_mult_type == 'Wall Area, Below-Grade (ft^2)'
      hpxml.foundation_walls.each do |foundation_wall|
        next unless foundation_wall.is_exterior

        cost_mult += foundation_wall.area
      end
    elsif cost_mult_type == 'Floor Area, Conditioned (ft^2)'
      cost_mult += hpxml.building_construction.conditioned_floor_area
    elsif cost_mult_type == 'Floor Area, Attic (ft^2)'
      hpxml.frame_floors.each do |frame_floor|
        next unless frame_floor.is_thermal_boundary
        next unless frame_floor.is_interior
        next unless frame_floor.is_ceiling
        next unless [HPXML::LocationAtticVented, HPXML::LocationAtticUnvented].include?(frame_floor.exterior_adjacent_to)

        cost_mult += frame_floor.area
      end
    elsif cost_mult_type == 'Floor Area, Lighting (ft^2)'
      if hpxml.lighting.interior_usage_multiplier != 0
        cost_mult += hpxml.building_construction.conditioned_floor_area
      end
      hpxml.slabs.each do |slab|
        next unless [HPXML::LocationGarage].include?(slab.interior_adjacent_to)
        next if hpxml.lighting.garage_usage_multiplier == 0

        cost_mult += slab.area
      end
    elsif cost_mult_type == 'Roof Area (ft^2)'
      hpxml.roofs.each do |roof|
        cost_mult += roof.area
      end
    elsif cost_mult_type == 'Window Area (ft^2)'
      hpxml.windows.each do |window|
        cost_mult += window.area
      end
    elsif cost_mult_type == 'Door Area (ft^2)'
      hpxml.doors.each do |door|
        cost_mult += door.area
      end
    elsif cost_mult_type == 'Duct Unconditioned Surface Area (ft^2)'
      hpxml.hvac_distributions.each do |hvac_distribution|
        hvac_distribution.ducts.each do |duct|
          next if [HPXML::LocationLivingSpace, HPXML::LocationBasementConditioned].include?(duct.duct_location)

          cost_mult += duct.duct_surface_area
        end
      end
    elsif cost_mult_type == 'Size, Heating System (kBtu/h)'
      hpxml.heating_systems.each do |heating_system|
        next if heating_system.id != 'HeatingSystem'

        cost_mult += UnitConversions.convert(heating_system.heating_capacity, 'btu/hr', 'kbtu/hr')
      end

      hpxml.heat_pumps.each do |heat_pump|
        cost_mult += UnitConversions.convert(heat_pump.heating_capacity, 'btu/hr', 'kbtu/hr')
      end
    elsif cost_mult_type == 'Size, Secondary Heating System (kBtu/h)'
      hpxml.heating_systems.each do |heating_system|
        next if heating_system.id != 'SecondHeatingSystem'

        cost_mult += UnitConversions.convert(heating_system.heating_capacity, 'btu/hr', 'kbtu/hr')
      end
    elsif cost_mult_type == 'Size, Heat Pump Backup (kBtu/h)'
      hpxml.heat_pumps.each do |heat_pump|
        cost_mult += UnitConversions.convert(heat_pump.backup_heating_capacity, 'btu/hr', 'kbtu/hr')
      end
    elsif cost_mult_type == 'Size, Cooling System (kBtu/h)'
      hpxml.cooling_systems.each do |cooling_system|
        cost_mult += UnitConversions.convert(cooling_system.cooling_capacity, 'btu/hr', 'kbtu/hr')
      end

      hpxml.heat_pumps.each do |heat_pump|
        cost_mult += UnitConversions.convert(heat_pump.cooling_capacity, 'btu/hr', 'kbtu/hr')
      end
    elsif cost_mult_type == 'Size, Water Heater (gal)'
      hpxml.water_heating_systems.each do |water_heating_system|
        next if water_heating_system.tank_volume.nil?

        cost_mult += water_heating_system.tank_volume
      end
    elsif cost_mult_type == 'Flow Rate, Mechanical Ventilation (cfm)'
      hpxml.ventilation_fans.each do |ventilation_fan|
        next unless ventilation_fan.used_for_whole_building_ventilation

        cost_mult += ventilation_fan.rated_flow_rate
      end
    elsif cost_mult_type == 'Slab Perimeter, Exposed, Conditioned (ft)'
      hpxml.slabs.each do |slab|
        next unless slab.is_exterior_thermal_boundary

        cost_mult += slab.exposed_perimeter
      end
    elsif cost_mult_type == 'Rim Joist Area, Above-Grade, Exterior (ft^2)'
      hpxml.rim_joists.each do |rim_joist|
        cost_mult += rim_joist.area
      end
    end
    return cost_mult
  end # end get_cost_multiplier
end

# register the measure to be used by the application
UpgradeCosts.new.registerWithApplication
