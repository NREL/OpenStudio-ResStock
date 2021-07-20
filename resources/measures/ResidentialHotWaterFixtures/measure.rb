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
class ResidentialHotWaterFixtures < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Hot Water Fixtures'
  end

  def description
    return "Adds (or replaces) residential hot water fixtures -- showers, sinks, and baths. For multifamily buildings, the hot water fixtures can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Creates three new WaterUse:Equipment objects to represent showers, sinks, and baths in a home. OtherEquipment objects are also added to take into account the heat gain in the space due to hot water use.'
  end

  def arguments(model)
    ruleset = OpenStudio::Measure
    osargument = ruleset::OSArgument

    args = ruleset::OSArgumentVector.new

    # Shower hot water use multiplier
    shower_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('shower_mult', true)
    shower_mult.setDisplayName('Multiplier on shower hot water use')
    shower_mult.setDescription('Multiplier on Building America HSP shower hot water consumption. HSP prescribes shower hot water consumption of 14 + 4.67 * n_bedrooms gal/day at 110 F.')
    shower_mult.setDefaultValue(1.0)
    args << shower_mult

    # Sink hot water use multiplier
    sink_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('sink_mult', true)
    sink_mult.setDisplayName('Multiplier on sink hot water use')
    sink_mult.setDescription('Multiplier on Building America HSP sink hot water consumption. HSP prescribes sink hot water consumption of 12.5 + 4.16 * n_bedrooms gal/day at 110 F.')
    sink_mult.setDefaultValue(1.0)
    args << sink_mult

    # Bath hot water use multiplier
    bath_mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('bath_mult', true)
    bath_mult.setDisplayName('Multiplier on bath hot water use')
    bath_mult.setDescription('Multiplier on Building America HSP bath hot water consumption. HSP prescribes bath hot water consumption of 3.5 + 1.17 * n_bedrooms gal/day at 110 F.')
    bath_mult.setDefaultValue(1.0)
    args << bath_mult

    # make a choice argument for plant loop
    plant_loops = model.getPlantLoops
    plant_loop_args = OpenStudio::StringVector.new
    plant_loop_args << Constants.Auto
    plant_loops.each do |plant_loop|
      plant_loop_args << plant_loop.name.to_s
    end
    plant_loop = OpenStudio::Measure::OSArgument::makeChoiceArgument('plant_loop', plant_loop_args, true, true)
    plant_loop.setDisplayName('Plant Loop')
    plant_loop.setDescription("Select the plant loop for the hot water fixtures. '#{Constants.Auto}' will try to choose the plant loop associated with the specified space. For multifamily buildings, '#{Constants.Auto}' will choose the plant loop for each unit of the building.")
    plant_loop.setDefaultValue(Constants.Auto)
    args << plant_loop

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
    sh_mult = runner.getDoubleArgumentValue('shower_mult', user_arguments)
    s_mult = runner.getDoubleArgumentValue('sink_mult', user_arguments)
    b_mult = runner.getDoubleArgumentValue('bath_mult', user_arguments)
    plant_loop_s = runner.getStringArgumentValue('plant_loop', user_arguments)

    # Check for valid and reasonable inputs
    if sh_mult < 0
      runner.registerError('Shower hot water usage multiplier must be greater than or equal to 0.')
      return false
    end
    if s_mult < 0
      runner.registerError('Sink hot water usage multiplier must be greater than or equal to 0.')
      return false
    end
    if b_mult < 0
      runner.registerError('Bath hot water usage multiplier must be greater than or equal to 0.')
      return false
    end

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    # Remove all existing objects
    obj_names = [Constants.ObjectNameShower,
                 Constants.ObjectNameSink,
                 Constants.ObjectNameBath]
    model.getSpaces.each do |space|
      remove_existing(model, runner, space, obj_names)
    end

    location_hierarchy = [Constants.SpaceTypeBathroom,
                          Constants.SpaceTypeLiving,
                          Constants.SpaceTypeFinishedBasement]

    year_description = model.getYearDescription
    num_days_in_year = Constants.NumDaysInYear(year_description.isLeapYear)
    # @type [SchedulesFile]
    schedules_file = SchedulesFile.new(runner: runner, model: model)
    if not schedules_file.validated?
      return false
    end

    mixed_use_t = Constants.MixedUseT # F

    if (sh_mult > 0) || (s_mult > 0) || (b_mult > 0)
      temperature_sch = OpenStudio::Model::ScheduleConstant.new(model)
      temperature_sch.setValue(UnitConversions.convert(mixed_use_t, 'F', 'C'))
      temperature_sch.setName('fixtures temperature schedule')
      Schedule.set_schedule_type_limits(model, temperature_sch, Constants.ScheduleTypeLimitsTemperature)
    end

    tot_sh_gpd = 0
    tot_s_gpd = 0
    tot_b_gpd = 0
    msgs = []
    sch_sh = nil
    sch_s = nil
    sch_b = nil
    units.each_with_index do |unit, unit_index|
      # Get unit beds/baths/occupants
      nbeds, nbaths = Geometry.get_unit_beds_baths(model, unit, runner)
      if nbeds.nil? || nbaths.nil?
        return false
      end

      noccupants = Geometry.get_unit_occupants(model, unit, runner)

      # Get space
      space = Geometry.get_space_from_location(unit, Constants.Auto, location_hierarchy)
      next if space.nil?

      # Get plant loop
      plant_loop = Waterheater.get_plant_loop_from_string(model, runner, plant_loop_s, unit)
      if plant_loop.nil?
        next
      end

      obj_name_sh = Constants.ObjectNameShower(unit.name.to_s)
      obj_name_s = Constants.ObjectNameSink(unit.name.to_s)
      obj_name_b = Constants.ObjectNameBath(unit.name.to_s)
      obj_name_recirc_pump = Constants.ObjectNameHotWaterRecircPump(unit.name.to_s)

      if [Constants.BuildingTypeMultifamily, Constants.BuildingTypeSingleFamilyAttached].include? Geometry.get_building_type(model) # multifamily equation
        # Calc daily gpm and annual gain of each end use
        sh_gpd = (14.0 + 4.67 * (-0.68 + 1.09 * noccupants)) * sh_mult
        s_gpd = (12.5 + 4.16 * (-0.68 + 1.09 * noccupants)) * s_mult
        b_gpd = (3.5 + 1.17 * (-0.68 + 1.09 * noccupants)) * b_mult

        # Shower internal gains
        sh_sens_load = (741 + 247 * (-0.68 + 1.09 * noccupants)) * sh_mult # Btu/day
        sh_lat_load = (703 + 235 * (-0.68 + 1.09 * noccupants)) * sh_mult # Btu/day
        sh_tot_load = UnitConversions.convert(sh_sens_load + sh_lat_load, 'Btu', 'kWh') # kWh/day
        sh_lat = sh_lat_load / (sh_lat_load + sh_sens_load)

        # Sink internal gains
        s_sens_load = (310 + 103 * (-0.68 + 1.09 * noccupants)) * s_mult # Btu/day
        s_lat_load = (140 + 47 * (-0.68 + 1.09 * noccupants)) * s_mult # Btu/day
        s_tot_load = UnitConversions.convert(s_sens_load + s_lat_load, 'Btu', 'kWh') # kWh/day
        s_lat = s_lat_load / (s_lat_load + s_sens_load)

        # Bath internal gains
        b_sens_load = (185 + 62 * (-0.68 + 1.09 * noccupants)) * b_mult # Btu/day
        b_lat_load = 0 # Btu/day
        b_tot_load = UnitConversions.convert(b_sens_load + b_lat_load, 'Btu', 'kWh') # kWh/day
        b_lat = b_lat_load / (b_lat_load + b_sens_load)
      elsif [Constants.BuildingTypeSingleFamilyDetached].include? Geometry.get_building_type(model) # single-family equation
        # Calc daily gpm and annual gain of each end use
        sh_gpd = (14.0 + 4.67 * (-1.47 + 1.69 * noccupants)) * sh_mult
        s_gpd = (12.5 + 4.16 * (-1.47 + 1.69 * noccupants)) * s_mult
        b_gpd = (3.5 + 1.17 * (-1.47 + 1.69 * noccupants)) * b_mult

        # Shower internal gains
        sh_sens_load = (741 + 247 * (-1.47 + 1.69 * noccupants)) * sh_mult # Btu/day
        sh_lat_load = (703 + 235 * (-1.47 + 1.69 * noccupants)) * sh_mult # Btu/day
        sh_tot_load = UnitConversions.convert(sh_sens_load + sh_lat_load, 'Btu', 'kWh') # kWh/day
        sh_lat = sh_lat_load / (sh_lat_load + sh_sens_load)

        # Sink internal gains
        s_sens_load = (310 + 103 * (-1.47 + 1.69 * noccupants)) * s_mult # Btu/day
        s_lat_load = (140 + 47 * (-1.47 + 1.69 * noccupants)) * s_mult # Btu/day
        s_tot_load = UnitConversions.convert(s_sens_load + s_lat_load, 'Btu', 'kWh') # kWh/day
        s_lat = s_lat_load / (s_lat_load + s_sens_load)

        # Bath internal gains
        b_sens_load = (185 + 62 * (-1.47 + 1.69 * noccupants)) * b_mult # Btu/day
        b_lat_load = 0 # Btu/day
        b_tot_load = UnitConversions.convert(b_sens_load + b_lat_load, 'Btu', 'kWh') # kWh/day
        b_lat = b_lat_load / (b_lat_load + b_sens_load)
      end

      if (sh_gpd > 0) || (s_gpd > 0) || (b_gpd > 0)

        # Reuse existing water use connection if possible
        water_use_connection = nil
        plant_loop.demandComponents.each do |component|
          next unless component.to_WaterUseConnections.is_initialized

          water_use_connection = component.to_WaterUseConnections.get
          break
        end
        if water_use_connection.nil?
          # Need new water heater connection
          water_use_connection = OpenStudio::Model::WaterUseConnections.new(model)
          plant_loop.addDemandBranchForComponent(water_use_connection)
        end

      end

      # Showers
      if sh_gpd > 0

        col_name = 'showers'
        if sch_sh.nil?
          # Create schedule
          sch_sh = schedules_file.create_schedule_file(col_name: col_name)
        end

        sh_peak_flow = schedules_file.calc_peak_flow_from_daily_gpm(col_name: col_name, daily_water: sh_gpd)
        sh_design_level = schedules_file.calc_design_level_from_daily_kwh(col_name: col_name, daily_kwh: sh_tot_load)

        # Add water use equipment objects
        sh_wu_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
        sh_wu = OpenStudio::Model::WaterUseEquipment.new(sh_wu_def)
        sh_wu.setName(obj_name_sh)
        sh_wu.setSpace(space)
        sh_wu_def.setName(obj_name_sh)
        sh_wu_def.setPeakFlowRate(sh_peak_flow)
        sh_wu_def.setEndUseSubcategory(obj_name_sh)
        sh_wu.setFlowRateFractionSchedule(sch_sh)
        sh_wu_def.setTargetTemperatureSchedule(temperature_sch)
        water_use_connection.addWaterUseEquipment(sh_wu)

        # Add other equipment
        sh_oe_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
        sh_oe = OpenStudio::Model::OtherEquipment.new(sh_oe_def)
        sh_oe.setName(obj_name_sh)
        sh_oe.setSpace(space)
        sh_oe_def.setName(obj_name_sh)
        sh_oe_def.setDesignLevel(sh_design_level)
        sh_oe_def.setFractionRadiant(0)
        sh_oe_def.setFractionLatent(sh_lat)
        sh_oe_def.setFractionLost(0)
        sh_oe.setSchedule(sch_sh)

        # Re-assign recirc pump schedule if needed
        recirc_pump = nil
        space.otherEquipment.each do |space_equipment|
          next if not space_equipment.name.to_s.start_with? Constants.ObjectNameShower

          next unless space_equipment.schedule.is_initialized

          # Check if there is a recirc pump referencing this schedule
          model.getElectricEquipments.each do |ee|
            next if ee.name.to_s != obj_name_recirc_pump
            next if not ee.schedule.is_initialized
            next if ee.schedule.get.handle.to_s != space_equipment.schedule.get.handle.to_s

            recirc_pump = ee
          end
        end
        if not recirc_pump.nil?
          recirc_pump.setSchedule(sch_sh.schedule)
        end

        tot_sh_gpd += sh_gpd
        # Unmet Shower Energy
        obj_name_sh = obj_name_sh.gsub('unit ', '').gsub('|', '_')

        vol_shower = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Water Use Equipment Hot Water Volume')
        vol_shower.setName("#{obj_name_sh} vol")
        vol_shower.setKeyName(sh_wu.name.to_s)

        t_out_wh = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Water Heater Use Side Outlet Temperature')
        t_out_wh.setName("#{obj_name_sh} tout")
        model.getPlantLoops.each do |pl|
          next if not pl.name.to_s.start_with? Constants.PlantLoopDomesticWater

          wh = Waterheater.get_water_heater(model, pl, runner)
          if wh.is_a? OpenStudio::Model::WaterHeaterHeatPumpWrappedCondenser
            wh = wh.tank
          end
          t_out_wh.setKeyName(wh.name.to_s)
        end

        mix_sp_hw = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
        mix_sp_hw.setName("#{obj_name_sh} mixsp")
        mix_sp_hw.setKeyName(sh_wu_def.targetTemperatureSchedule.get.name.to_s)

        program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
        program.setName("#{obj_name_sh} sag")
        program.addLine("If #{vol_shower.name} > 0")
        program.addLine('Set ShowerTime=SystemTimeStep')
        program.addLine('Else')
        program.addLine('Set ShowerTime=0')
        program.addLine('EndIf')
        program.addLine("If (#{vol_shower.name} > 0) && (#{mix_sp_hw.name} > #{t_out_wh.name})")
        program.addLine('Set ShowerSag=SystemTimeStep')
        program.addLine("Set ShowerE=#{vol_shower.name}*4141170*(#{mix_sp_hw.name}-#{t_out_wh.name})")
        program.addLine('Else')
        program.addLine('Set ShowerSag=0')
        program.addLine('Set ShowerE=0')
        program.addLine('EndIf')

        program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
        program_calling_manager.setName("#{obj_name_sh} sag")
        program_calling_manager.setCallingPoint('EndOfSystemTimestepAfterHVACReporting')
        program_calling_manager.addProgram(program)

        ems_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, 'ShowerE')
        ems_output_var.setName("Unmet Shower Energy|#{unit.name}")
        ems_output_var.setTypeOfDataInVariable('Summed')
        ems_output_var.setUpdateFrequency('SystemTimestep')
        ems_output_var.setEMSProgramOrSubroutineName(program)
        ems_output_var.setUnits('J')

        ems_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, 'ShowerSag')
        ems_output_var.setName("Unmet Shower Time|#{unit.name}")
        ems_output_var.setTypeOfDataInVariable('Summed')
        ems_output_var.setUpdateFrequency('SystemTimestep')
        ems_output_var.setEMSProgramOrSubroutineName(program)
        ems_output_var.setUnits('hr')

        ems_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, 'ShowerTime')
        ems_output_var.setName("Shower Draw Time|#{unit.name}")
        ems_output_var.setTypeOfDataInVariable('Summed')
        ems_output_var.setUpdateFrequency('SystemTimestep')
        ems_output_var.setEMSProgramOrSubroutineName(program)
        ems_output_var.setUnits('hr')
      end

      # Sinks
      if s_gpd > 0

        col_name = 'sinks'
        if sch_s.nil?
          # Create schedule
          sch_s = schedules_file.create_schedule_file(col_name: col_name)
        end

        s_peak_flow = schedules_file.calc_peak_flow_from_daily_gpm(col_name: col_name, daily_water: s_gpd)
        s_design_level = schedules_file.calc_design_level_from_daily_kwh(col_name: col_name, daily_kwh: s_tot_load)

        # Add water use equipment objects
        s_wu_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
        s_wu = OpenStudio::Model::WaterUseEquipment.new(s_wu_def)
        s_wu.setName(obj_name_s)
        s_wu.setSpace(space)
        s_wu_def.setName(obj_name_s)
        s_wu_def.setPeakFlowRate(s_peak_flow)
        s_wu_def.setEndUseSubcategory(obj_name_s)
        s_wu.setFlowRateFractionSchedule(sch_s)
        s_wu_def.setTargetTemperatureSchedule(temperature_sch)
        water_use_connection.addWaterUseEquipment(s_wu)

        # Add other equipment
        s_oe_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
        s_oe = OpenStudio::Model::OtherEquipment.new(s_oe_def)
        s_oe.setName(obj_name_s)
        s_oe.setSpace(space)
        s_oe_def.setName(obj_name_s)
        s_oe_def.setDesignLevel(s_design_level)
        s_oe_def.setFractionRadiant(0)
        s_oe_def.setFractionLatent(s_lat)
        s_oe_def.setFractionLost(0)
        s_oe.setSchedule(sch_s)

        tot_s_gpd += s_gpd
      end

      # Baths
      if b_gpd > 0

        col_name = 'baths'
        if sch_b.nil?
          # Create schedule
          sch_b = schedules_file.create_schedule_file(col_name: col_name)
        end

        b_peak_flow = schedules_file.calc_peak_flow_from_daily_gpm(col_name: col_name, daily_water: b_gpd)
        b_design_level = schedules_file.calc_design_level_from_daily_kwh(col_name: col_name, daily_kwh: b_tot_load)

        # Add water use equipment objects
        b_wu_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
        b_wu = OpenStudio::Model::WaterUseEquipment.new(b_wu_def)
        b_wu.setName(obj_name_b)
        b_wu.setSpace(space)
        b_wu_def.setName(obj_name_b)
        b_wu_def.setPeakFlowRate(b_peak_flow)
        b_wu_def.setEndUseSubcategory(obj_name_b)
        b_wu.setFlowRateFractionSchedule(sch_b)
        b_wu_def.setTargetTemperatureSchedule(temperature_sch)
        water_use_connection.addWaterUseEquipment(b_wu)

        # Add other equipment
        b_oe_def = OpenStudio::Model::OtherEquipmentDefinition.new(model)
        b_oe = OpenStudio::Model::OtherEquipment.new(b_oe_def)
        b_oe.setName(obj_name_b)
        b_oe.setSpace(space)
        b_oe_def.setName(obj_name_b)
        b_oe_def.setDesignLevel(b_design_level)
        b_oe_def.setFractionRadiant(0)
        b_oe_def.setFractionLatent(b_lat)
        b_oe_def.setFractionLost(0)
        b_oe.setSchedule(sch_b)

        tot_b_gpd += b_gpd
      end

      if (sh_gpd > 0) || (s_gpd > 0) || (b_gpd > 0)
        msgs << "Shower, sinks, and bath fixtures drawing #{sh_gpd.round(1)}, #{s_gpd.round(1)}, and #{b_gpd.round(1)} gal/day respectively have been added to plant loop '#{plant_loop.name}' and assigned to space '#{space.name.to_s}'."
      end
    end

    schedules_file.set_vacancy(col_name: 'showers')
    schedules_file.set_vacancy(col_name: 'sinks')
    schedules_file.set_vacancy(col_name: 'baths')

    # Reporting
    if msgs.size > 1
      msgs.each do |msg|
        runner.registerInfo(msg)
      end
      runner.registerFinalCondition("The building has been assigned shower, sink, and bath fixtures drawing a total of #{(tot_sh_gpd + tot_s_gpd + tot_b_gpd).round(1)} gal/day across #{units.size} units.")
    elsif msgs.size == 1
      runner.registerFinalCondition(msgs[0])
    else
      runner.registerFinalCondition('No shower, sink, or bath fixtures have been assigned.')
    end

    return true
  end

  def remove_existing(model, runner, space, obj_names)
    # Remove existing EMS
    obj_name_sh = Constants.ObjectNameShower
    model.getEnergyManagementSystemProgramCallingManagers.each do |pcm|
      if pcm.name.to_s.start_with? obj_name_sh
        pcm.remove
      end
    end

    model.getEnergyManagementSystemSensors.each do |sensor|
      if sensor.name.to_s.start_with? obj_name_sh.gsub(' ', '_')
        sensor.remove
      end
    end

    model.getEnergyManagementSystemPrograms.each do |program|
      if program.name.to_s.start_with? obj_name_sh.gsub(' ', '_')
        program.remove
      end
    end

    unmet_sh_outputs = ['Unmet Shower Energy', 'Unmet Shower Time', 'Shower Draw Time']
    model.getEnergyManagementSystemOutputVariables.each do |ems_output_var|
      unmet_sh_outputs.each do |unmet_sh_output|
        if ems_output_var.name.to_s.start_with? unmet_sh_output
          ems_output_var.remove
        end
      end
    end

    # Remove any existing ssb
    objects_to_remove = []
    space.otherEquipment.each do |space_equipment|
      found = false
      obj_names.each do |obj_name|
        next if not space_equipment.name.to_s.start_with? obj_name
        next if space_equipment.name.to_s.include? '=' # TODO: Skip dummy distribution objects; can remove once we are using AdditionalProperties

        found = true
      end
      next if not found

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.otherEquipmentDefinition
      if space_equipment.schedule.is_initialized
        objects_to_remove << space_equipment.schedule.get
      end
    end
    space.waterUseEquipment.each do |space_equipment|
      found = false
      obj_names.each do |obj_name|
        next if not space_equipment.name.to_s.start_with? obj_name
        next if space_equipment.additionalProperties.getFeatureAsDouble('dist_hw').is_initialized # TODO: Skip dummy distribution objects; can remove once we are using AdditionalProperties instead of the objects

        found = true
      end
      next if not found

      objects_to_remove << space_equipment
      objects_to_remove << space_equipment.waterUseEquipmentDefinition
      if space_equipment.flowRateFractionSchedule.is_initialized
        objects_to_remove << space_equipment.flowRateFractionSchedule.get
      end
      if space_equipment.waterUseEquipmentDefinition.targetTemperatureSchedule.is_initialized
        objects_to_remove << space_equipment.waterUseEquipmentDefinition.targetTemperatureSchedule.get
      end
    end
    if objects_to_remove.size > 0
      runner.registerInfo("Removed existing showers, sinks, and baths from space '#{space.name.to_s}'.")
    end
    objects_to_remove.uniq.each do |object|
      begin
        object.remove
      rescue
        # no op
      end
    end
  end
end # end the measure

# this allows the measure to be use by the application
ResidentialHotWaterFixtures.new.registerWithApplication
