# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'weather')
require File.join(resources_path, 'hvac')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'waterheater')
require File.join(resources_path, 'unit_conversions')

# start the measure
class ResidentialHotWaterSolar < OpenStudio::Measure::ModelMeasure
  class SHWSystem
    def initialize
    end
    attr_accessor(:collector_area, :pump_power, :storage_vol, :test_flow, :coll_flow, :storage_diam, :storage_ht, :tank_a, :storage_Uvalue)
  end

  class SHWAzimuth
    def initialize
    end
    attr_accessor(:abs)
  end

  class SHWTilt
    def initialize
    end
    attr_accessor(:abs)
  end

  # human readable name
  def name
    return 'Set Residential Solar Water Heating'
  end

  # human readable description
  def description
    return "Adds (or replaces) residential solar water heating to the model based on user inputs. For both single-family detached and multifamily buildings, the added storage tank and collector plate provide pre-heated water to the (existing) conventional water heater.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Any supply or demand components, including collector plate surface, are removed along with corresponding plant loop. A stratified storage tank demand branch, flat plate collector supply branch, and constant speed pump are added to a new plant loop. The existing water heater is added to the outlet node of the storage tank. A differential thermostat, with collector plate outlet as the hot node and storage tank outlet as the cold node, represents the availability manager on the plant loop.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for shw collector area
    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('collector_area', true)
    arg.setDisplayName('Collector Area')
    arg.setUnits('ft^2/unit')
    arg.setDescription('Area of the collector array for each unit of the building.')
    arg.setDefaultValue(40.0)
    args << arg

    # make a double argument for shw FRta
    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('frta', true)
    arg.setDisplayName('FRta')
    arg.setDescription('Optical gain coefficient in Hottel-Willier-Bliss (HWB) equation.')
    arg.setDefaultValue(0.77)
    args << arg

    # make a double argument for shw FRUL
    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('frul', true)
    arg.setDisplayName('FRUL')
    arg.setUnits('Btu/hr-ft^2-R')
    arg.setDescription('Thermal loss coefficient in the Hottel-Willier-Bliss (HWB) equation.')
    arg.setDefaultValue(0.793)
    args << arg

    # make a double argument for shw IAM
    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('iam', true)
    arg.setDisplayName('IAM')
    arg.setDescription('The incident angle modifier coefficient.')
    arg.setDefaultValue(0.1)
    args << arg

    # make a string argument for shw tank storage volume
    arg = OpenStudio::Measure::OSArgument::makeStringArgument('storage_vol', true)
    arg.setDisplayName('Tank Storage Volume')
    arg.setUnits('gal')
    arg.setDescription("The volume of the solar storage tank. If set to 'auto', the tank storage volume will be 1.5 gal for every sqft of collector area.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    # make a double argument for shw tank r-value
    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('tank_r', true)
    arg.setDisplayName('Tank R-Value')
    arg.setUnits('hr-ft^2-R/Btu')
    arg.setDescription('The insulation level of the solar storage tank.')
    arg.setDefaultValue(10.0)
    args << arg

    # make a choice argument for shw fluid type
    fluid_display_names = OpenStudio::StringVector.new
    fluid_display_names << Constants.FluidPropyleneGlycol
    fluid_display_names << Constants.FluidWater
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('fluid_type', fluid_display_names, true)
    arg.setDisplayName('Fluid Type')
    arg.setDescription("The solar system's heat transfer fluid.")
    arg.setDefaultValue(Constants.FluidPropyleneGlycol)
    args << arg

    # make a double argument for shw heat exchanger effectiveness
    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_ex_eff', true)
    arg.setDisplayName('Heat Exchanger Effectiveness')
    arg.setDescription('Heat exchanger effectiveness, where the effectiveness e, is defined as e = (Tcold-out - Tcold-in) / (Thot-in - Tcold-in).')
    arg.setDefaultValue(0.7)
    args << arg

    # make a double argument for shw pump power
    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pump_power', true)
    arg.setDisplayName('Pump Power')
    arg.setUnits('W/ft^2')
    arg.setDescription('Total pump energy consumption in Watts per sqft of collector area.')
    arg.setDefaultValue(0.8)
    args << arg

    # make a choice arguments for azimuth type
    azimuth_types_names = OpenStudio::StringVector.new
    azimuth_types_names << Constants.CoordRelative
    azimuth_types_names << Constants.CoordAbsolute
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('azimuth_type', azimuth_types_names, true)
    arg.setDisplayName('Azimuth Type')
    arg.setDescription('Relative azimuth angle is measured clockwise from the front of the house. Absolute azimuth angle is measured clockwise from due south.')
    arg.setDefaultValue(Constants.CoordRelative)
    args << arg

    # make a double argument for azimuth
    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('azimuth', true)
    arg.setDisplayName('Azimuth')
    arg.setUnits('degrees')
    arg.setDescription('The azimuth angle is measured clockwise.')
    arg.setDefaultValue(180.0)
    args << arg

    # make a choice arguments for tilt type
    tilt_types_names = OpenStudio::StringVector.new
    tilt_types_names << Constants.TiltPitch
    tilt_types_names << Constants.CoordAbsolute
    tilt_types_names << Constants.TiltLatitude
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('tilt_type', tilt_types_names, true)
    arg.setDisplayName('Tilt Type')
    arg.setDescription('Type of tilt angle referenced.')
    arg.setDefaultValue(Constants.TiltPitch)
    args << arg

    # make a double argument for tilt
    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('tilt', true)
    arg.setDisplayName('Tilt')
    arg.setUnits('degrees')
    arg.setDescription('Angle of the tilt.')
    arg.setDefaultValue(0)
    args << arg

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    collector_area = runner.getDoubleArgumentValue('collector_area', user_arguments)
    frta = runner.getDoubleArgumentValue('frta', user_arguments)
    frul = runner.getDoubleArgumentValue('frul', user_arguments)
    iam = runner.getDoubleArgumentValue('iam', user_arguments)
    storage_vol = runner.getStringArgumentValue('storage_vol', user_arguments)
    tank_r = runner.getDoubleArgumentValue('tank_r', user_arguments)
    fluid_type = runner.getStringArgumentValue('fluid_type', user_arguments)
    heat_ex_eff = runner.getDoubleArgumentValue('heat_ex_eff', user_arguments)
    pump_power = runner.getDoubleArgumentValue('pump_power', user_arguments)
    azimuth_type = runner.getStringArgumentValue('azimuth_type', user_arguments)
    azimuth = runner.getDoubleArgumentValue('azimuth', user_arguments)
    tilt_type = runner.getStringArgumentValue('tilt_type', user_arguments)
    tilt = runner.getDoubleArgumentValue('tilt', user_arguments)

    if (azimuth > 360) || (azimuth < 0)
      runner.registerError('Invalid azimuth entered.')
      return false
    end

    shw_system = SHWSystem.new
    shw_azimuth = SHWAzimuth.new
    shw_tilt = SHWTilt.new

    weather = WeatherProcess.new(model, runner)
    if weather.error?
      return false
    end

    roof_tilt = Geometry.get_roof_pitch(model.getSurfaces)

    if azimuth_type == Constants.CoordRelative
      shw_azimuth.abs = Geometry.get_abs_azimuth(azimuth_type, azimuth, 0, 0)
    else
      shw_azimuth.abs = Geometry.get_abs_azimuth(azimuth_type, azimuth, 0, -model.getBuilding.northAxis)
    end
    shw_tilt.abs = Geometry.get_abs_tilt(tilt_type, tilt, roof_tilt, weather.header.Latitude)

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    model_plant_loops = model.getPlantLoops

    shw_system.collector_area = calc_shw_collector_area(collector_area, units.size)
    shw_system.pump_power = calc_shw_pump_power(collector_area, pump_power)
    shw_system.storage_vol = UnitConversions.convert(calc_shw_storage_volume(shw_system.collector_area, storage_vol), 'gal', 'ft^3')
    shw_system.test_flow = 55.0 / UnitConversions.convert(1.0, 'lbm/min', 'kg/hr') / Liquid.H2O_l.rho * UnitConversions.convert(1.0, 'ft^2', 'm^2') # cfm/ft^2
    shw_system.coll_flow = shw_system.test_flow * shw_system.collector_area # cfm
    shw_system.storage_diam = (4.0 * shw_system.storage_vol / 3 / Math::PI)**(1.0 / 3.0) # ft
    shw_system.storage_ht = 3.0 * shw_system.storage_diam # ft
    shw_system.tank_a = shw_system.storage_ht * Math::PI * shw_system.storage_diam + 2.0 * Math::PI * shw_system.storage_diam**2.0 / 4.0 # ft^2
    shw_system.storage_Uvalue = 1.0 / tank_r # Btu/hr-ft^2-R

    units.each do |unit|
      obj_name = Constants.ObjectNameSolarHotWater(unit.name.to_s)

      thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

      control_slave_zones_hash = HVAC.get_control_and_slave_zones(thermal_zones)
      control_slave_zones_hash.each do |control_zone, slave_zones|
        # Remove existing equipment
        model_plant_loops.each do |plant_loop|
          next unless plant_loop.name.to_s == Constants.PlantLoopSolarHotWater(unit.name.to_s)

          components_to_remove = []
          (plant_loop.supplyComponents + plant_loop.demandComponents).each do |component|
            if component.to_WaterHeaterStratified.is_initialized || component.to_SolarCollectorFlatPlateWater.is_initialized || component.to_PumpConstantSpeed.is_initialized
              components_to_remove << component
            end
          end
          components_to_remove.each do |component|
            if component.to_SolarCollectorFlatPlateWater.is_initialized
              component.to_SolarCollectorFlatPlateWater.get.surface.get.to_ShadingSurface.get.shadingSurfaceGroup.get.remove
            end
            component.remove
          end
          plant_loop.availabilityManagers.each do |am|
            am.remove
          end
          plant_loop.remove
        end

        dhw_loop = nil
        water_heater = nil
        setpoint_schedule_one = nil
        setpoint_schedule_two = nil
        model_plant_loops.each do |plant_loop|
          next if plant_loop.name.to_s != Constants.PlantLoopDomesticWater(unit.name.to_s)

          dhw_loop = plant_loop
          dhw_loop.supplyComponents.each do |supply_component|
            if supply_component.to_WaterHeaterMixed.is_initialized
              water_heater = supply_component.to_WaterHeaterMixed.get
              setpoint_schedule_one = water_heater.setpointTemperatureSchedule.get
              setpoint_schedule_two = water_heater.setpointTemperatureSchedule.get
            elsif supply_component.to_WaterHeaterStratified.is_initialized
              water_heater = supply_component.to_WaterHeaterStratified.get
              setpoint_schedule_one = water_heater.heater1SetpointTemperatureSchedule
              setpoint_schedule_two = water_heater.heater2SetpointTemperatureSchedule
            end
          end
          break
        end

        if dhw_loop.nil? || water_heater.nil?
          runner.registerWarning('Model must have a water heater.')
          next
        end

        dhw_setpoint_manager = nil
        dhw_loop.supplyOutletNode.setpointManagers.each do |setpoint_manager|
          if setpoint_manager.to_SetpointManagerScheduled.is_initialized
            dhw_setpoint_manager = setpoint_manager.to_SetpointManagerScheduled.get
          end
        end

        plant_loop = OpenStudio::Model::PlantLoop.new(model)
        plant_loop.setName(Constants.PlantLoopSolarHotWater(unit.name.to_s))
        if fluid_type == Constants.FluidWater
          plant_loop.setFluidType('Water')
        else
          plant_loop.setFluidType('PropyleneGlycol')
          plant_loop.setGlycolConcentration(50)
        end
        plant_loop.setMaximumLoopTemperature(100)
        plant_loop.setMinimumLoopTemperature(0)
        plant_loop.setMinimumLoopFlowRate(0)
        plant_loop.setLoadDistributionScheme('Optimal')
        plant_loop.setPlantEquipmentOperationHeatingLoadSchedule(model.alwaysOnDiscreteSchedule)

        sizing_plant = plant_loop.sizingPlant
        sizing_plant.setLoopType('Heating')
        sizing_plant.setDesignLoopExitTemperature(dhw_loop.sizingPlant.designLoopExitTemperature)
        sizing_plant.setLoopDesignTemperatureDifference(UnitConversions.convert(10.0, 'R', 'K'))

        setpoint_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, dhw_setpoint_manager.schedule)
        setpoint_manager.setName(obj_name + ' setpoint mgr')
        setpoint_manager.setControlVariable('Temperature')

        pump = OpenStudio::Model::PumpConstantSpeed.new(model)
        pump.setName(obj_name + ' pump')
        pump.setRatedPumpHead(90000)
        pump.setRatedPowerConsumption(shw_system.pump_power)
        pump.setMotorEfficiency(0.3)
        pump.setFractionofMotorInefficienciestoFluidStream(0.2)
        pump.setPumpControlType('Intermittent')
        pump.setRatedFlowRate(UnitConversions.convert(shw_system.coll_flow, 'cfm', 'm^3/s'))
        pump.addToNode(plant_loop.supplyInletNode)

        panel_length = UnitConversions.convert(shw_system.collector_area, 'ft^2', 'm^2')**0.5
        run = Math::cos(shw_tilt.abs * Math::PI / 180) * panel_length

        vertices = OpenStudio::Point3dVector.new
        vertices << OpenStudio::Point3d.new(UnitConversions.convert(100.0, 'ft', 'm'), UnitConversions.convert(100.0, 'ft', 'm'), 0)
        vertices << OpenStudio::Point3d.new(UnitConversions.convert(100.0, 'ft', 'm') + panel_length, UnitConversions.convert(100.0, 'ft', 'm'), 0)
        vertices << OpenStudio::Point3d.new(UnitConversions.convert(100.0, 'ft', 'm') + panel_length, UnitConversions.convert(100.0, 'ft', 'm') + run, (panel_length**2 - run**2)**0.5)
        vertices << OpenStudio::Point3d.new(UnitConversions.convert(100.0, 'ft', 'm'), UnitConversions.convert(100.0, 'ft', 'm') + run, (panel_length**2 - run**2)**0.5)

        m = OpenStudio::Matrix.new(4, 4, 0)
        m[0, 0] = Math::cos(-shw_azimuth.abs * Math::PI / 180)
        m[1, 1] = Math::cos(-shw_azimuth.abs * Math::PI / 180)
        m[0, 1] = -Math::sin(-shw_azimuth.abs * Math::PI / 180)
        m[1, 0] = Math::sin(-shw_azimuth.abs * Math::PI / 180)
        m[2, 2] = 1
        m[3, 3] = 1
        transformation = OpenStudio::Transformation.new(m)
        vertices = transformation * vertices

        shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
        shading_surface_group.setName(obj_name + ' shading group')

        shading_surface = OpenStudio::Model::ShadingSurface.new(vertices, model)
        shading_surface.setName(obj_name + ' shading surface')
        shading_surface.setShadingSurfaceGroup(shading_surface_group)

        collector_plate = OpenStudio::Model::SolarCollectorFlatPlateWater.new(model)
        collector_plate.setName(obj_name + ' coll plate')
        collector_plate.setSurface(shading_surface)
        collector_plate.setMaximumFlowRate(UnitConversions.convert(shw_system.coll_flow, 'cfm', 'm^3/s'))
        collector_performance = collector_plate.solarCollectorPerformance
        collector_performance.setName(obj_name + ' coll perf')
        collector_performance.setGrossArea(UnitConversions.convert(shw_system.collector_area, 'ft^2', 'm^2'))
        collector_performance.setTestFluid('Water')
        collector_performance.setTestFlowRate(UnitConversions.convert(shw_system.coll_flow, 'cfm', 'm^3/s'))
        collector_performance.setTestCorrelationType('Inlet')
        collector_performance.setCoefficient1ofEfficiencyEquation(frta)
        collector_performance.setCoefficient2ofEfficiencyEquation(-UnitConversions.convert(frul, 'Btu/(hr*ft^2*F)', 'W/(m^2*K)'))
        collector_performance.setCoefficient2ofIncidentAngleModifier(-iam)

        plant_loop.addSupplyBranchForComponent(collector_plate)
        runner.registerInfo("Added '#{collector_plate.name}' to supply branch of '#{plant_loop.name}'.")

        pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
        pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
        pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
        pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
        pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)

        plant_loop.addSupplyBranchForComponent(pipe_supply_bypass)
        pump.addToNode(plant_loop.supplyInletNode)
        pipe_supply_outlet.addToNode(plant_loop.supplyOutletNode)
        setpoint_manager.addToNode(plant_loop.supplyOutletNode)
        plant_loop.addDemandBranchForComponent(pipe_demand_bypass)
        pipe_demand_inlet.addToNode(plant_loop.demandInletNode)
        pipe_demand_outlet.addToNode(plant_loop.demandOutletNode)

        storage_tank = OpenStudio::Model::WaterHeaterStratified.new(model)
        storage_tank.setName(obj_name + ' storage tank')
        storage_tank.setTankVolume(UnitConversions.convert(shw_system.storage_vol, 'ft^3', 'm^3'))
        storage_tank.setTankHeight(UnitConversions.convert(shw_system.storage_ht, 'in', 'm'))
        storage_tank.setTankShape('VerticalCylinder')
        storage_tank.setTankPerimeter(Math::PI * UnitConversions.convert(shw_system.storage_diam, 'in', 'm'))
        storage_tank.setMaximumTemperatureLimit(99)
        storage_tank.heater1SetpointTemperatureSchedule.remove
        storage_tank.setHeater1SetpointTemperatureSchedule(setpoint_schedule_one)
        storage_tank.setHeater1Capacity(0)
        storage_tank.setHeater1Height(0)
        storage_tank.heater2SetpointTemperatureSchedule.remove
        storage_tank.setHeater2SetpointTemperatureSchedule(setpoint_schedule_two)
        storage_tank.setHeater2Capacity(0)
        storage_tank.setHeater2Height(0)
        storage_tank.setHeaterFuelType('Electricity')
        storage_tank.setHeaterThermalEfficiency(1)
        storage_tank.ambientTemperatureSchedule.get.remove
        storage_tank.setAmbientTemperatureThermalZone(control_zone)
        storage_tank.setAmbientTemperatureIndicator('ThermalZone')
        storage_tank.setUniformSkinLossCoefficientperUnitAreatoAmbientTemperature(UnitConversions.convert(shw_system.storage_Uvalue, 'Btu/(hr*ft^2*F)', 'W/(m^2*K)'))
        storage_tank.setSkinLossFractiontoZone(1)
        storage_tank.setOffCycleFlueLossFractiontoZone(1)
        storage_tank.setUseSideEffectiveness(1)
        storage_tank.setUseSideInletHeight(0)
        storage_tank.setUseSideOutletHeight(UnitConversions.convert(shw_system.storage_ht, 'in', 'm'))
        storage_tank.setSourceSideEffectiveness(heat_ex_eff)
        storage_tank.setSourceSideInletHeight(UnitConversions.convert(shw_system.storage_ht, 'in', 'm') / 3.0)
        storage_tank.setSourceSideOutletHeight(0)
        storage_tank.setInletMode('Fixed')
        storage_tank.setIndirectWaterHeatingRecoveryTime(1.5)
        storage_tank.setNumberofNodes(8)
        storage_tank.setAdditionalDestratificationConductivity(0)
        storage_tank.setNode1AdditionalLossCoefficient(0)
        storage_tank.setNode6AdditionalLossCoefficient(0)
        storage_tank.setSourceSideDesignFlowRate(UnitConversions.convert(shw_system.coll_flow, 'cfm', 'm^3/s'))
        storage_tank.setUseSideDesignFlowRate(UnitConversions.convert(shw_system.storage_vol, 'ft^3', 'm^3') / 60.1) # 60.1 (seconds) ensures that the autosizing doesn't draw the whole tank volume in one minute

        plant_loop.addDemandBranchForComponent(storage_tank)
        runner.registerInfo("Added '#{storage_tank.name}' to demand branch of '#{plant_loop.name}'.")

        dhw_loop.addSupplyBranchForComponent(storage_tank)
        runner.registerInfo("Added '#{storage_tank.name}' to supply branch of '#{dhw_loop.name}'.")

        water_heater.addToNode(storage_tank.supplyOutletModelObject.get.to_Node.get)
        runner.registerInfo("Moved '#{water_heater.name}' to supply outlet node of '#{storage_tank.name}'.")

        availability_manager = OpenStudio::Model::AvailabilityManagerDifferentialThermostat.new(model)
        availability_manager.setName(obj_name + ' useful energy')
        availability_manager.setHotNode(collector_plate.outletModelObject.get.to_Node.get)
        availability_manager.setColdNode(storage_tank.demandOutletModelObject.get.to_Node.get)
        availability_manager.setTemperatureDifferenceOnLimit(0)
        availability_manager.setTemperatureDifferenceOffLimit(0)
        plant_loop.setAvailabilityManager(availability_manager)
      end
    end

    return true
  end

  def calc_shw_collector_area(total_collector_area, num_units, has_central_water_heating = false)
    if has_central_water_heating
      return num_units * total_collector_area
    end

    return total_collector_area
  end

  def calc_shw_pump_power(total_collector_area, pump_power_per_area)
    return pump_power_per_area * total_collector_area
  end

  def calc_shw_storage_volume(total_collector_area, storage_volume)
    if storage_volume == Constants.Auto
      volume_factor = 1.5 # gal/ft^2 (of collector area)
      return volume_factor * total_collector_area # gal
    else
      return storage_volume.to_f # gal
    end
  end
end

# register the measure to be used by the application
ResidentialHotWaterSolar.new.registerWithApplication
