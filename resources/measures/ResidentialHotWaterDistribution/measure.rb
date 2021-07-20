# frozen_string_literal: true

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'schedules')
require File.join(resources_path, 'constants')
require File.join(resources_path, 'util')
require File.join(resources_path, 'weather')
require File.join(resources_path, 'unit_conversions')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'waterheater')

# start the measure
class ResidentialHotWaterDistribution < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Hot Water Distribution'
  end

  def description
    return "Adds a hot water distribution system, including pipes and any recirculation pumps, into the home. This measure must be run after hot water fixtures have been added to the home. For multifamily buildings, the hot water fixtures can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Modifies the existing HotWater:Equipment Objects for showers, sinks, and baths to take into account the additional water drawn due to distribution system inefficiencies. Also adds an internal gain to the space due to heat loss from the pipes and an ElectricEquipment object for the pump if recirculation is included.'
  end

  def arguments(model)
    ruleset = OpenStudio::Measure
    osargument = ruleset::OSArgument

    args = ruleset::OSArgumentVector.new

    # Distribution pipe material
    pipe_mat_display_name = OpenStudio::StringVector.new
    pipe_mat_display_name << Constants.MaterialCopper
    pipe_mat_display_name << Constants.MaterialPEX
    pipe_mat = OpenStudio::Measure::OSArgument::makeChoiceArgument('pipe_mat', pipe_mat_display_name, true)
    pipe_mat.setDisplayName('Pipe Material')
    pipe_mat.setDescription('The plumbing material.')
    pipe_mat.setDefaultValue(Constants.MaterialCopper)
    args << pipe_mat

    # Distribution system layout
    dist_layout_display_name = OpenStudio::StringVector.new
    dist_layout_display_name << Constants.PipeTypeHomeRun
    dist_layout_display_name << Constants.PipeTypeTrunkBranch
    dist_layout = OpenStudio::Measure::OSArgument::makeChoiceArgument('dist_layout', dist_layout_display_name, true)
    dist_layout.setDisplayName('Distribution system layout')
    dist_layout.setDescription('The plumbing layout of the hot water distribution system. Trunk and branch uses a main trunk line to supply various branch take-offs to specific fixtures. In the home run layout, all fixtures are fed from dedicated piping that runs directly from central manifolds.')
    dist_layout.setDefaultValue(Constants.PipeTypeTrunkBranch)
    args << dist_layout

    # make a choice argument for space
    space_display_name = OpenStudio::StringVector.new
    space_display_name << Constants.LocationInterior
    space_display_name << Constants.LocationExterior
    space = OpenStudio::Measure::OSArgument::makeChoiceArgument('space', space_display_name, true)
    space.setDescription('Select the primary space where the DHW distribution system is located.')
    space.setDefaultValue(Constants.LocationInterior)
    args << space

    # Recirculation Type
    recirc_type_display_name = OpenStudio::StringVector.new
    recirc_type_display_name << Constants.RecircTypeNone
    recirc_type_display_name << Constants.RecircTypeTimer
    recirc_type_display_name << Constants.RecircTypeDemand
    recirc_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('recirc_type', recirc_type_display_name, true)
    recirc_type.setDisplayName('Recirculation Type')
    recirc_type.setDescription('The type of hot water recirculation control, if any. Timer recirculation control assumes 16 hours of daily pump operation from 6am to 10pm. Demand recirculation controls assume push button control at all non-appliance fistures with 100% ideal control.')
    recirc_type.setDefaultValue(Constants.RecircTypeNone)
    args << recirc_type

    # Insulation
    dist_ins = OpenStudio::Measure::OSArgument::makeDoubleArgument('dist_ins', true)
    dist_ins.setDisplayName('Insulation Nominal R-Value')
    dist_ins.setUnits('h-ft^2-R/Btu')
    dist_ins.setDescription('Nominal R-value of the insulation on the DHW distribution system.')
    dist_ins.setDefaultValue(0.0)
    args << dist_ins

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    pipe_mat = runner.getStringArgumentValue('pipe_mat', user_arguments)
    dist_layout = runner.getStringArgumentValue('dist_layout', user_arguments)
    dist_ins = runner.getDoubleArgumentValue('dist_ins', user_arguments)
    recirc_type = runner.getStringArgumentValue('recirc_type', user_arguments)
    dist_loc = runner.getStringArgumentValue('space', user_arguments)

    # Check for valid and reasonable inputs
    if dist_ins < 0
      runner.registerError('Insulation Nominal R-Value must be greater than or equal to 0.')
    end

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    # Get mains monthly temperatures
    site = model.getSite
    if !site.siteWaterMainsTemperature.is_initialized
      runner.registerError('Mains water temperature has not been set.')
      return false
    end

    year_description = model.getYearDescription
    num_days_in_months = Constants.NumDaysInMonths(year_description.isLeapYear)
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)

    waterMainsTemperature = site.siteWaterMainsTemperature.get
    avgOAT = UnitConversions.convert(waterMainsTemperature.annualAverageOutdoorAirTemperature.get, 'C', 'F')
    maxDiffMonthlyAvgOAT = UnitConversions.convert(waterMainsTemperature.maximumDifferenceInMonthlyAverageOutdoorAirTemperatures.get, 'K', 'R')
    mainsMonthlyTemps = WeatherProcess.calc_mains_temperatures(avgOAT, maxDiffMonthlyAvgOAT, site.latitude, num_days_in_year)[1]

    schedules_file = SchedulesFile.new(runner: runner, model: model)
    if not schedules_file.validated?
      return false
    end

    tot_pump_e_ann = 0
    msgs = []
    units.each do |unit|
      # Get unit beds/baths
      nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
      if nbeds.nil? || nbaths.nil?
        return false
      end

      # Get plant loop
      plant_loop = Waterheater.get_plant_loop_from_string(model, runner, Constants.Auto, unit)
      if plant_loop.nil?
        next
      end

      # Get water heater setpoint
      wh_setpoint = Waterheater.get_water_heater_setpoint(model, plant_loop, runner)
      if wh_setpoint.nil?
        return false
      end

      obj_name_sh = Constants.ObjectNameShower(unit.name.to_s)
      obj_name_s = Constants.ObjectNameSink(unit.name.to_s)
      obj_name_b = Constants.ObjectNameBath(unit.name.to_s)
      obj_name_sh_dist = Constants.ObjectNameShowerDist(unit.name.to_s)
      obj_name_s_dist = Constants.ObjectNameSinkDist(unit.name.to_s)
      obj_name_b_dist = Constants.ObjectNameBathDist(unit.name.to_s)
      obj_name_recirc_pump = Constants.ObjectNameHotWaterRecircPump(unit.name.to_s)
      obj_name_dist = Constants.ObjectNameHotWaterDistribution(unit.name.to_s)

      # Remove any existing distribution objects (and read existing hot water gal/day values)
      dist_removed = false
      dist_space = nil
      sh_prev_dist = 0
      s_prev_dist = 0
      b_prev_dist = 0
      unit.spaces.each do |space|
        space.waterUseEquipment.each do |wue|
          next if (not wue.name.to_s.start_with?(obj_name_sh_dist)) && (not wue.name.to_s.start_with?(obj_name_s_dist)) && (not wue.name.to_s.start_with?(obj_name_b_dist))

          dist_hw = wue.additionalProperties.getFeatureAsDouble('dist_hw').get
          if wue.name.to_s.start_with?(obj_name_sh_dist)
            sh_prev_dist = dist_hw
          elsif wue.name.to_s.start_with?(obj_name_s_dist)
            s_prev_dist = dist_hw
          elsif wue.name.to_s.start_with?(obj_name_b_dist)
            b_prev_dist = dist_hw
          end
          wue.remove
          dist_removed = true
          dist_space = space
        end
        space.otherEquipment.each do |oe|
          next if oe.name.to_s != obj_name_dist

          oe.remove
          dist_removed = true
        end
        space.electricEquipment.each do |ee|
          next if ee.name.to_s != obj_name_recirc_pump

          ee.remove
          dist_removed = true
        end
      end
      if dist_removed
        runner.registerInfo("Removed existing hot water distribution from space '#{dist_space.name}'.")
      end

      # Find which space the showers, sinks, and baths were previously assigned to and get the peak flow rates
      shower_max = nil
      sink_max = nil
      bath_max = nil
      shower_wu_def = nil
      sink_wu_def = nil
      bath_wu_def = nil
      dist_space = nil
      unit.spaces.each do |space|
        space.waterUseEquipment.each do |space_equipment|
          if space_equipment.name.to_s == obj_name_sh
            shower_max = space_equipment.waterUseEquipmentDefinition.peakFlowRate
            shower_wu_def = space_equipment.waterUseEquipmentDefinition
            dist_space = space
          elsif space_equipment.name.to_s == obj_name_s
            sink_max = space_equipment.waterUseEquipmentDefinition.peakFlowRate
            sink_wu_def = space_equipment.waterUseEquipmentDefinition
          elsif space_equipment.name.to_s == obj_name_b
            bath_max = space_equipment.waterUseEquipmentDefinition.peakFlowRate
            bath_wu_def = space_equipment.waterUseEquipmentDefinition
          end
        end
      end

      if shower_max.nil? || sink_max.nil? || bath_max.nil?
        runner.registerError('Residential Hot Water Fixture measure must be run prior to running this measure.')
        return false
      end

      shower_daily = schedules_file.calc_daily_gpm_from_peak_flow(col_name: 'showers', peak_flow: shower_max)
      sink_daily = schedules_file.calc_daily_gpm_from_peak_flow(col_name: 'sinks', peak_flow: sink_max)
      bath_daily = schedules_file.calc_daily_gpm_from_peak_flow(col_name: 'baths', peak_flow: bath_max)

      # Calculate the pump energy consumption (in kWh/day)
      daily_recovery_load = Array.new(12, 0)
      pump_e_ann = 0
      if recirc_type == Constants.RecircTypeTimer
        for m in 0..11
          daily_recovery_load[m] = [(18135.0 + 2538.0 * nbeds + (-12265.0 - 1495.0 * nbeds) * dist_ins / 2.0) / \
            (8.33 * (120.0 - mainsMonthlyTemps[m]) * 4184.0 * 0.00023886), 0].max
        end
        pump_e_ann = 193.0
      elsif recirc_type == Constants.RecircTypeDemand
        for m in 0..11
          daily_recovery_load[m] = [(-3648.0 + 2344.0 * nbeds + (-1328.0 - 761.0 * nbeds) * dist_ins / 2.0) / \
            (8.33 * (120.0 - mainsMonthlyTemps[m]) * 4184.0 * 0.00023886), 0].max
        end
        pump_e_ann = (-0.13 + 0.72 * nbeds + (0.13 - 0.17 * nbeds) * dist_ins / 2.0)
      end

      water_mix_to_h = Array.new(12, 0)
      for m in 0..11
        water_mix_to_h[m] = [(Constants.MixedUseT - mainsMonthlyTemps[m]) / (wh_setpoint - mainsMonthlyTemps[m]), 0].max
      end

      daily_shower_increase = Array.new(12, 0)
      daily_sink_increase = Array.new(12, 0)
      daily_bath_increase = Array.new(12, 0)
      monthly_internal_gain = Array.new(12, 0)
      deg_rad = Math::PI / 180.0
      if (dist_layout == Constants.PipeTypeTrunkBranch) && (pipe_mat == Constants.MaterialCopper) && \
         (dist_loc == Constants.LocationInterior) && (recirc_type == Constants.RecircTypeNone)
        # Case 1: Trunk & Branch, Copper, Interior, No Recirc
        for m in 0..11
          daily_shower_increase[m] = [(-0.305 - 0.075 * nbeds) * dist_ins / 2.0, 0].min # gal/day
          daily_bath_increase[m] = [(0.03 - 0.03 * nbeds) * dist_ins / 2.0, 0].min # gal/day
          daily_sink_increase[m] = [(-0.755 - 0.245 * nbeds) * dist_ins / 2.0, 0].min # gal/day
          monthly_internal_gain[m] = [num_days_in_months[m] * (4257.0 + 735.0 * (nbeds - 3) - \
                                     (948.0 + 158.0 * (nbeds - 3)) * dist_ins / 2.0) * (1 + 1.0 / 4257.0 * \
                                     (362.0 + (63.0 * (nbeds - 3))) * Math.sin(deg_rad * (360.0 * ((m + 1.0) / 12.0) + 0.3))), 0].max # Btu/month
        end
      elsif (dist_layout == Constants.PipeTypeTrunkBranch) && (pipe_mat == Constants.MaterialPEX) && \
            (dist_loc == Constants.LocationInterior) && (recirc_type == Constants.RecircTypeNone)
        # Case 2: Trunk & Branch, PEX, Interior, No Recirc
        for m in 0..11
          daily_shower_increase[m] = [-0.85 - 0.44 * dist_ins / 2.0, 0].min # gal/day
          daily_bath_increase[m] = [-0.12 - 0.06 * dist_ins / 2.0, 0].min # gal/day
          daily_sink_increase[m] = [-1.69 - 1.74 * dist_ins / 2.0, 0].min # gal/day
          monthly_internal_gain[m] = [num_days_in_months[m] * (4257.0 - 1047.0 - 732.0 * dist_ins / 2.0) * \
            (1 + 1.0 / 4257.0 * 735.0 * (nbeds - 3) + 1.0 / 4257.0 * (362.0 + (63.0 * (nbeds - 3))) * \
              Math.sin(deg_rad * (360.0 * ((m + 1.0) / 12.0) + 0.3))), 0].max # Btu/month
        end
      elsif (dist_layout == Constants.PipeTypeTrunkBranch) && (pipe_mat == Constants.MaterialCopper) && \
            (dist_loc == Constants.LocationExterior) && (recirc_type == Constants.RecircTypeNone)
        # Case 3: Trunk & Branch, Copper, Exterior, No Recirc
        for m in 0..11
          daily_shower_increase[m] = [((-1.14 - 0.36 * nbeds) + (-0.34 - 0.08 * nbeds) * dist_ins / 2.0) * \
            (1 + 0.11 * Math.sin(deg_rad * (360.0 * ((m + 1.0) / 12.0) + 0.3))), 0].min # gal/day
          daily_bath_increase[m] = [((-0.28 - 0.11 * nbeds) + (0.06 - 0.04 * nbeds) * dist_ins / 2.0) * \
            (1 + 0.13 * Math.sin(deg_rad * (360.0 * ((m + 1.0) / 12.0)) + 0.3)), 0].min # gal/day
          daily_sink_increase[m] = [((-0.89 - 0.32 * nbeds) + (-1.86 + 0.31 * nbeds) * dist_ins / 2.0) * \
            (1 + 0.16 * Math.sin(deg_rad * (360.0 * ((m + 1.0) / 12.0)) + 0.3)), 0].min # gal/day
          monthly_internal_gain[m] = 0 # Btu/month
        end
      elsif (dist_layout == Constants.PipeTypeTrunkBranch) && (pipe_mat == Constants.MaterialPEX) && \
            (dist_loc == Constants.LocationExterior) && (recirc_type == Constants.RecircTypeNone)
        # Case 4: Trunk & Branch, PEX, Exterior, No Recirc
        for m in 0..11
          daily_shower_increase[m] = [-0.85 + (shower_daily * water_mix_to_h[m] - 0.85) / \
                                              (shower_daily * water_mix_to_h[m]) * ((-1.14 - 0.36 * nbeds) + \
                                       (-0.34 - 0.08 * nbeds) * dist_ins / 2.0) * (1.0 + 0.11 * Math.sin(deg_rad * (360.0 * \
                                       (m / 12.0) + 0.3))), 0].min # gal/day
          daily_bath_increase[m] = [-0.12 + (bath_daily * water_mix_to_h[m] - 0.85) / \
                                            (bath_daily * water_mix_to_h[m]) * ((-0.28 - 0.11 * nbeds) + \
                                   (0.06 - 0.04 * nbeds) * dist_ins / 2.0) * \
                                            (1.0 + 0.13 * Math.sin(deg_rad * (360.0 * (m / 12.0) + 0.3))), 0].min # gal/day
          daily_sink_increase[m] = [-1.69 + (sink_daily * water_mix_to_h[m] - 1.69) / \
                                            (sink_daily * water_mix_to_h[m]) * ((-0.89 - 0.32 * nbeds) + \
                                   (-1.86 + 0.31 * nbeds) * dist_ins / 2.0) * (1.0 + 0.16 * \
                                   Math.sin(deg_rad * (360.0 * ((m + 1.0) / 12.0) + 0.3))), 0].min # gal/day
          monthly_internal_gain[m] = 0 # Btu/month
        end
      elsif (dist_layout == Constants.PipeTypeHomeRun) && (pipe_mat == Constants.MaterialPEX) && \
            (dist_loc == Constants.LocationInterior) && (recirc_type == Constants.RecircTypeNone)
        # Case 5: Home Run, PEX, Interior, No Recirc
        for m in 0..11
          daily_shower_increase[m] = [(-0.52 - 0.23 * nbeds) + (-0.35 + 0.02 * nbeds) * dist_ins / 2.0, 0].min # gal/day
          daily_bath_increase[m] = [(-0.06 - 0.05 * nbeds) + (-0.11 + 0.03 * nbeds) * dist_ins / 2.0, 0].min # gal/day
          daily_sink_increase[m] = [(0.21 - 0.72 * nbeds) + (-0.75 - 0.15 * nbeds) * dist_ins / 2.0, 0].min # gal/day
          monthly_internal_gain[m] = [num_days_in_months[m] * (4257.0 + 735.0 * (nbeds - 3) - (1142.0 + 378.0 * (nbeds - 3)) - \
                                     ((649.0 + 73.0 * (nbeds - 3)) * dist_ins / 2.0)) * (1.0 + 1.0 / 4257.0 * (362.0 + (63.0 * (nbeds - 3))) * \
                                     Math.sin(deg_rad * (360.0 * ((m + 1.0) / 12.0)) + 0.3)), 0].max # Btu/month
        end
      elsif (dist_layout == Constants.PipeTypeHomeRun) && (pipe_mat == Constants.MaterialPEX) && \
            (dist_loc == Constants.LocationExterior) && (recirc_type == Constants.RecircTypeNone)
        # Case 6: Homerun, PEX, Exterior, No Recirc
        for m in 0..11
          daily_shower_increase[m] = [-0.52 - 0.23 * nbeds + (shower_daily * water_mix_to_h[m] - 0.52 - 0.23 * nbeds) / \
                                                             (shower_daily * water_mix_to_h[m]) * ((-1.14 - 0.36 * nbeds) + \
                                       (-0.34 - 0.08 * nbeds) * dist_ins / 2.0) * (1 + 0.11 * \
                                       Math.sin(deg_rad * (360.0 * (m / 12.0) + 0.3))), 0].min # gal/day
          daily_bath_increase[m] = [-0.06 - 0.05 * nbeds + (bath_daily * water_mix_to_h[m] - 0.06 - 0.05 * nbeds) / \
                                                           (bath_daily * water_mix_to_h[m]) * ((-0.28 - 0.11 * nbeds) + \
                                   (0.06 - 0.04 * nbeds) * dist_ins / 2.0) * (1 + 0.13 * \
                                   Math.sin(deg_rad * (360.0 * (m / 12.0)) + 0.3)), 0].min # gal/day
          daily_sink_increase[m] = [0.21 - 0.72 * nbeds + (sink_daily * water_mix_to_h[m] + 0.21 - 0.72 * nbeds) / \
                                                          (sink_daily * water_mix_to_h[m]) * ((-0.89 - 0.32 * nbeds) + \
                                   (-1.86 + 0.31 * nbeds) * dist_ins / 2.0) * (1 + 0.16 * \
                                   Math.sin(deg_rad * (360.0 * ((m + 1.0) / 12.0)) + 0.3)), 0].min # gal/day
          monthly_internal_gain[m] = 0 # Btu/month
        end
      elsif (dist_layout == Constants.PipeTypeTrunkBranch) && (pipe_mat == Constants.MaterialCopper) && \
            (dist_loc == Constants.LocationInterior) && (recirc_type == Constants.RecircTypeTimer)
        # Case 7: Trunk & Branch, Copper, Interior, Timer
        for m in 0..11
          daily_shower_increase[m] = [(-2.15 + 0.25 * nbeds) + (-0.16 - 0.08 * nbeds) * dist_ins / 2.0, 0].min # gal/day
          daily_bath_increase[m] = [(-0.27 + 0.04 * nbeds) + (-0.01 - 0.03 * nbeds) * dist_ins / 2.0, 0].min # gal/day
          daily_sink_increase[m] = [(-2.01 - 0.95 * nbeds) + (-0.36 - 0.13 * nbeds) * dist_ins / 2.0, 0].min # gal/day
          monthly_internal_gain[m] = [num_days_in_months[m] * (4257.0 + 735.0 * (nbeds - 3) + (20148.0 + 2140.0 * (nbeds - 3)) - \
                                      ((11956.0 + 1355.0 * (nbeds - 3)) * dist_ins / 2.0)) * (1.0 + 1.0 / 4257.0 * (362.0 + (63.0 * \
                                      (nbeds - 3))) * Math.sin(deg_rad * (360.0 * ((m + 1.0) / 12.0) + 0.3))), 0].max # Btu/month
        end
      elsif (dist_layout == Constants.PipeTypeTrunkBranch) && (pipe_mat == Constants.MaterialCopper) && \
            (dist_loc == Constants.LocationInterior) && (recirc_type == Constants.RecircTypeDemand)
        # Case 8: Trunk & Branch, Copper, Interior, Demand
        for m in 0..11
          daily_shower_increase[m] = [(-2.61 + 0.35 * nbeds) + (0.05 - 0.13 * nbeds) * dist_ins / 2.0, 0].min # gal/day
          daily_bath_increase[m] = [(-0.26 + 0.01 * nbeds) - 0.03 * dist_ins / 2.0, 0].min # gal/day
          daily_sink_increase[m] = [(-1.34 - 0.91 * nbeds) + (-0.64 - 0.07 * nbeds) * dist_ins / 2.0, 0].min # gal/day
          monthly_internal_gain[m] = [num_days_in_months[m] * (4257.0 + 735.0 * (nbeds - 3) + (1458.0 + 1066.0 * (nbeds - 3)) - \
                                     ((1332.0 + 545.0 * (nbeds - 3)) * dist_ins / 2.0)) * \
            (1.0 + 1.0 / 4257.0 * (362.0 + (63.0 * (nbeds - 3))) * \
              Math.sin(deg_rad * (360.0 * ((m + 1.0) / 12.0) + 0.3))), 0].max # Btu/month
        end
      elsif (dist_layout == Constants.PipeTypeTrunkBranch) && (pipe_mat == Constants.MaterialPEX) && \
            (dist_loc == Constants.LocationInterior) && (recirc_type == Constants.RecircTypeTimer)
        # Case 9: Trunk & Branch, PEX, Interior, Timer
        for m in 0..11
          daily_shower_increase[m] = [-0.85 + (shower_daily * water_mix_to_h[m] - 0.85) / \
                                              (shower_daily * water_mix_to_h[m]) * ((-2.15 + 0.25 * nbeds) + \
                                       (-0.16 - 0.08 * nbeds) * dist_ins / 2.0), 0].min # gal/day
          daily_bath_increase[m] = [-0.12 + (bath_daily * water_mix_to_h[m] - 0.12) / \
                                            (bath_daily * water_mix_to_h[m]) * ((-0.27 + 0.04 * nbeds) + \
                                   (-0.01 - 0.03 * nbeds) * dist_ins / 2.0), 0].min # gal/day
          daily_sink_increase[m] = [-1.69 + (sink_daily * water_mix_to_h[m] - 1.69) / \
                                            (sink_daily * water_mix_to_h[m]) * ((-2.01 - 0.95 * nbeds) + \
                                   (-0.36 - 0.13 * nbeds) * dist_ins / 2.0), 0].min # gal/day
          monthly_internal_gain[m] = [num_days_in_months[m] * ((4257.0 - 1047.0) * (1.0 + 1.0 / 4257.0 * 735.0 * (nbeds - 3.0) + \
                                     1.0 / 4257.0 * (20148.0 + 2140.0 * (nbeds - 3.0)) - 1.0 / 4257.0 * ((11956.0 + 1355.0 * \
                                     (nbeds - 3.0)) * dist_ins / 2.0)) * (1.0 + 1.0 / 4257.0 * (362.0 + (63.0 * (nbeds - 3.0))) * \
                                     Math.sin(deg_rad * (360.0 * ((m + 1.0) / 12.0) + 0.3)))), 0.0].max # Btu/month
        end
      elsif (dist_layout == Constants.PipeTypeTrunkBranch) && (pipe_mat == Constants.MaterialPEX) && \
            (dist_loc == Constants.LocationInterior) && (recirc_type == Constants.RecircTypeDemand)
        # Case 10: Trunk & Branch, PEX, Interior, Demand
        for m in 0..11
          daily_shower_increase[m] = [-0.85 + (shower_daily * water_mix_to_h[m] - 0.85) / \
                                              (shower_daily * water_mix_to_h[m]) * ((-2.61 + 0.35 * nbeds) + \
                                       (0.05 - 0.13 * nbeds) * dist_ins / 2.0), 0].min # gal/day
          daily_bath_increase[m] = [-0.12 + (bath_daily * water_mix_to_h[m] - 0.12) / \
                                            (bath_daily * water_mix_to_h[m]) * ((-0.26 + 0.01 * nbeds) - \
                                   0.03 * dist_ins / 2.0), 0].min # gal/day
          daily_sink_increase[m] = [-1.69 + (sink_daily * water_mix_to_h[m] - 1.69) / \
                                            (sink_daily * water_mix_to_h[m]) * ((-1.34 - 0.91 * nbeds) + \
                                   (-0.64 - 0.07 * nbeds) * dist_ins / 2.0), 0].min # gal/day
          monthly_internal_gain[m] = [num_days_in_months[m] * ((4257.0 - 1047.0) * (1.0 + 1.0 / 4257.0 * 735.0 * (nbeds - 3) + \
                                     1.0 / 4257.0 * (1458.0 + 1066.0 * (nbeds - 3)) - 1.0 / 4257.0 * ((1332.0 + 545.0 * (nbeds - 3)) * \
                                     dist_ins / 2.0)) * (1.0 + 1.0 / 4257.0 * (362.0 + (63.0 * (nbeds - 3))) * \
                                     Math.sin(deg_rad * (360.0 * ((m + 1.0) / 12.0) + 0.3)))), 0].max # Btu/month
        end
      else
        # Case 11: Doesn't match any of the specified configurations (no HWsim runs were ever done for this situation)
        runner.registerWarning('Unexpected DHW distribution configuration, defaulting to BA Benchmark configuration.')
        for m in 0..11
          daily_shower_increase[m] = 0 # gal/day
          daily_bath_increase[m] = 0 # gal/day
          daily_sink_increase[m] = 0 # gal/day
          if dist_loc == Constants.LocationInterior
            monthly_internal_gain[m] = [num_days_in_months[m] * (4257.0 + 735.0 * (nbeds - 3)) *
              (1.0 + 1.0 / 4257.0 * (362.0 + (63.0 * (nbeds - 3))) *
                Math.sin(deg_rad * (360.0 * (m / 12.0) + 0.3))), 0].max # Btu/month
          else
            monthly_internal_gain[m] = 0 # Btu/month
          end
          daily_recovery_load[m] = 0 # gal/day
        end
        pump_e_ann = 0
      end

      # Sum the monthly values and calculate the new max flow rate
      recovery_load_inc = 0
      daily_shower_inc = 0
      daily_sink_inc = 0
      daily_bath_inc = 0
      ann_int_gain = 0
      for m in 0..11
        recovery_load_inc += num_days_in_months[m] * daily_recovery_load[m] / water_mix_to_h[m] / (num_days_in_year * 3.0) # Split evenly across all end uses
        daily_shower_inc += num_days_in_months[m] * daily_shower_increase[m] / water_mix_to_h[m] / num_days_in_year
        daily_sink_inc += num_days_in_months[m] * daily_sink_increase[m] / water_mix_to_h[m] / num_days_in_year
        daily_bath_inc += num_days_in_months[m] * daily_bath_increase[m] / water_mix_to_h[m] / num_days_in_year
        ann_int_gain += UnitConversions.convert(monthly_internal_gain[m], 'Btu', 'kWh')
      end
      shower_dist_hw = recovery_load_inc + daily_shower_inc
      sink_dist_hw = recovery_load_inc + daily_sink_inc
      bath_dist_hw = recovery_load_inc + daily_bath_inc

      # Get existing hot water fixture schedule objects
      sch_sh_schedule = nil
      sch_s_schedule = nil
      sch_b_schedule = nil
      sch_sh_temperatureSchedule = nil
      sch_s_temperatureSchedule = nil
      sch_b_temperatureSchedule = nil
      model.getWaterUseEquipments.each do |space_equipment|
        if space_equipment.name.to_s == obj_name_sh
          sch_sh_schedule = space_equipment.flowRateFractionSchedule.get
          sch_sh_temperatureSchedule = space_equipment.waterUseEquipmentDefinition.targetTemperatureSchedule.get
        elsif space_equipment.name.to_s == obj_name_s
          sch_s_schedule = space_equipment.flowRateFractionSchedule.get
          sch_s_temperatureSchedule = space_equipment.waterUseEquipmentDefinition.targetTemperatureSchedule.get
        elsif space_equipment.name.to_s == obj_name_b
          sch_b_schedule = space_equipment.flowRateFractionSchedule.get
          sch_b_temperatureSchedule = space_equipment.waterUseEquipmentDefinition.targetTemperatureSchedule.get
        end
      end

      # Add new water use objects for the distribution system hot water increase.
      # These are dummy objects that simply store the increase value; the actual
      # increase will be incorporated in the hot water fixture water use objects.
      sh_dist_wu_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
      sh_dist_wu = OpenStudio::Model::WaterUseEquipment.new(sh_dist_wu_def)
      sh_dist_wu.setName("#{obj_name_sh_dist}")
      sh_dist_wu.additionalProperties.setFeature('dist_hw', shower_dist_hw)
      sh_dist_wu.setSpace(dist_space)
      sh_dist_wu_def.setName("#{obj_name_sh_dist}")
      sh_dist_wu_def.setPeakFlowRate(0)
      sh_dist_wu.setFlowRateFractionSchedule(sch_sh_schedule)
      sh_dist_wu_def.setTargetTemperatureSchedule(sch_sh_temperatureSchedule)

      s_dist_wu_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
      s_dist_wu = OpenStudio::Model::WaterUseEquipment.new(s_dist_wu_def)
      s_dist_wu.setName("#{obj_name_s_dist}")
      s_dist_wu.additionalProperties.setFeature('dist_hw', sink_dist_hw)
      s_dist_wu.setSpace(dist_space)
      s_dist_wu_def.setName("#{obj_name_s_dist}")
      s_dist_wu_def.setPeakFlowRate(0)
      s_dist_wu.setFlowRateFractionSchedule(sch_s_schedule)
      s_dist_wu_def.setTargetTemperatureSchedule(sch_s_temperatureSchedule)

      b_dist_wu_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
      b_dist_wu = OpenStudio::Model::WaterUseEquipment.new(b_dist_wu_def)
      b_dist_wu.setName("#{obj_name_b_dist}")
      b_dist_wu.additionalProperties.setFeature('dist_hw', bath_dist_hw)
      b_dist_wu.setSpace(dist_space)
      b_dist_wu_def.setName("#{obj_name_b_dist}")
      b_dist_wu_def.setPeakFlowRate(0)
      b_dist_wu.setFlowRateFractionSchedule(sch_b_schedule)
      b_dist_wu_def.setTargetTemperatureSchedule(sch_b_temperatureSchedule)

      plant_loop.demandComponents.each do |component|
        next unless component.to_WaterUseConnections.is_initialized

        connection = component.to_WaterUseConnections.get
        connection.addWaterUseEquipment(sh_dist_wu)
        connection.addWaterUseEquipment(s_dist_wu)
        connection.addWaterUseEquipment(b_dist_wu)
        break
      end

      # calculate the new gal/day for ssb
      new_shower_daily = shower_daily + recovery_load_inc + daily_shower_inc - sh_prev_dist
      new_sink_daily = sink_daily + recovery_load_inc + daily_sink_inc - s_prev_dist
      new_bath_daily = bath_daily + recovery_load_inc + daily_bath_inc - b_prev_dist

      sh_new_peak_flow = schedules_file.calc_peak_flow_from_daily_gpm(col_name: 'showers', daily_water: new_shower_daily)
      s_new_peak_flow = schedules_file.calc_peak_flow_from_daily_gpm(col_name: 'sinks', daily_water: new_sink_daily)
      b_new_peak_flow = schedules_file.calc_peak_flow_from_daily_gpm(col_name: 'baths', daily_water: new_bath_daily)

      shower_wu_def.setPeakFlowRate(sh_new_peak_flow)
      sink_wu_def.setPeakFlowRate(s_new_peak_flow)
      bath_wu_def.setPeakFlowRate(b_new_peak_flow)

      # Add in an otherEquipment object for the monthly internal gain
      if ann_int_gain > 0
        gain_hourly_sch = '0.00623, 0.00312, 0.00078, 0.00078, 0.00312, 0.02181, 0.07477, 0.07944, 0.07632, 0.06698, 0.06075, 0.04829, 0.04206, 0.03738, 0.03738, 0.03271, 0.04361, 0.05763, 0.06854, 0.06542, 0.05919, 0.04829, 0.04206, 0.02336'
        gain_monthly_sch = '1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0'
        gain_sch = MonthWeekdayWeekendSchedule.new(model, runner, obj_name_dist + ' schedule', gain_hourly_sch, gain_hourly_sch, gain_monthly_sch)
        if not gain_sch.validated?
          return false
        end

        dist_design_level = gain_sch.calcDesignLevelFromDailykWh(ann_int_gain / num_days_in_year)
        dist_oe_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
        dist_oe = OpenStudio::Model::OtherEquipment.new(dist_oe_def)
        dist_oe.setName(obj_name_dist)
        dist_oe.setSpace(dist_space)
        dist_oe_def.setName(obj_name_dist)
        dist_oe_def.setDesignLevel(dist_design_level)
        dist_oe_def.setFractionRadiant(0)
        dist_oe_def.setFractionLatent(0)
        dist_oe_def.setFractionLost(0)
        dist_oe.setSchedule(gain_sch.schedule)
      end

      # Add in an electricEquipment object for the recirculation pump
      if pump_e_ann > 0
        recirc_pump_design_level = schedules_file.calc_design_level_from_daily_kwh(col_name: 'showers', daily_kwh: pump_e_ann / num_days_in_year)
        recirc_pump_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
        recirc_pump = OpenStudio::Model::ElectricEquipment.new(recirc_pump_def)
        recirc_pump.setName(obj_name_recirc_pump)
        recirc_pump.setEndUseSubcategory(obj_name_recirc_pump)
        recirc_pump.setSpace(dist_space)
        recirc_pump_def.setName(obj_name_recirc_pump)
        recirc_pump_def.setDesignLevel(recirc_pump_design_level)
        if dist_loc == Constants.LocationInterior
          recirc_pump_def.setFractionRadiant(0.5)
          recirc_pump_def.setFractionLatent(0)
          recirc_pump_def.setFractionLost(0)
        else
          recirc_pump_def.setFractionRadiant(0)
          recirc_pump_def.setFractionLatent(0)
          recirc_pump_def.setFractionLost(1)
        end
        recirc_pump.setSchedule(sch_sh_schedule)
      end

      pump_s = ''
      if pump_e_ann > 0
        pump_s = ", with a recirculation pump energy consumption of #{tot_pump_e_ann.round(2)} kWhs/yr,"
      end
      msgs << "A new #{pipe_mat}, #{dist_layout} DHW distribution system#{pump_s} has been assigned to the location #{dist_loc} of the home."

      tot_pump_e_ann += pump_e_ann
    end

    # Reporting
    if msgs.size > 1
      msgs.each do |msg|
        runner.registerInfo(msg)
      end
      runner.registerFinalCondition("The building has been assigned DHW distribution systems across #{units.size} units.")
    elsif msgs.size == 1
      runner.registerFinalCondition(msgs[0])
    else
      runner.registerFinalCondition('No DHW distribution system has been assigned.')
    end

    return true
  end
end # end the measure

# this allows the measure to be use by the application
ResidentialHotWaterDistribution.new.registerWithApplication
