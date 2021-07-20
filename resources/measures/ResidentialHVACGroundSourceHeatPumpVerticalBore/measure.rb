# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'hvac')
require File.join(resources_path, 'weather')

# start the measure
class ProcessGroundSourceHeatPumpVerticalBore < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Set Residential Ground Source Heat Pump Vertical Bore'
  end

  # human readable description
  def description
    return "This measure removes any existing HVAC components from the building and adds a ground heat exchanger along with variable speed pump and water to air heat pump coils to a condenser plant loop. For multifamily buildings, the supply components on the plant loop can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Any supply components or baseboard convective electrics/waters are removed from any existing air/plant loops or zones. A ground heat exchanger along with variable speed pump and water to air heat pump coils are added to a condenser plant loop.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for gshp vert bore cop
    cop = OpenStudio::Measure::OSArgument::makeDoubleArgument('cop', true)
    cop.setDisplayName('COP')
    cop.setUnits('W/W')
    cop.setDescription('User can use AHRI/ASHRAE ISO 13556-1 rated EER value and convert it to EIR here.')
    cop.setDefaultValue(3.6)
    args << cop

    # make a double argument for gshp vert bore eer
    eer = OpenStudio::Measure::OSArgument::makeDoubleArgument('eer', true)
    eer.setDisplayName('EER')
    eer.setUnits('Btu/W-h')
    eer.setDescription('This is a measure of the instantaneous energy efficiency of cooling equipment.')
    eer.setDefaultValue(16.6)
    args << eer

    # make a double argument for gshp vert bore rated shr
    shr = OpenStudio::Measure::OSArgument::makeDoubleArgument('shr', true)
    shr.setDisplayName('Rated SHR')
    shr.setDescription('The sensible heat ratio (ratio of the sensible portion of the load to the total load) at the nominal rated capacity.')
    shr.setDefaultValue(0.732)
    args << shr

    # make a double argument for gshp vert bore ground conductivity
    ground_conductivity = OpenStudio::Measure::OSArgument::makeDoubleArgument('ground_conductivity', true)
    ground_conductivity.setDisplayName('Ground Conductivity')
    ground_conductivity.setUnits('Btu/hr-ft-R')
    ground_conductivity.setDescription('Conductivity of the ground into which the ground heat exchangers are installed.')
    ground_conductivity.setDefaultValue(0.6)
    args << ground_conductivity

    # make a double argument for gshp vert bore grout conductivity
    grout_conductivity = OpenStudio::Measure::OSArgument::makeDoubleArgument('grout_conductivity', true)
    grout_conductivity.setDisplayName('Grout Conductivity')
    grout_conductivity.setUnits('Btu/hr-ft-R')
    grout_conductivity.setDescription('Grout is used to enhance heat transfer between the pipe and the ground.')
    grout_conductivity.setDefaultValue(0.4)
    args << grout_conductivity

    # make a string argument for gshp vert bore configuration
    config_display_names = OpenStudio::StringVector.new
    config_display_names << Constants.SizingAuto
    config_display_names << Constants.BoreConfigSingle
    config_display_names << Constants.BoreConfigLine
    config_display_names << Constants.BoreConfigRectangle
    config_display_names << Constants.BoreConfigLconfig
    config_display_names << Constants.BoreConfigL2config
    config_display_names << Constants.BoreConfigUconfig
    bore_config = OpenStudio::Measure::OSArgument::makeChoiceArgument('bore_config', config_display_names, true)
    bore_config.setDisplayName('Bore Configuration')
    bore_config.setDescription('Different types of vertical bore configuration results in different G-functions which captures the thermal response of a bore field.')
    bore_config.setDefaultValue(Constants.SizingAuto)
    args << bore_config

    # make a string argument for gshp vert bore holes
    holes_display_names = OpenStudio::StringVector.new
    holes_display_names << Constants.SizingAuto
    (1..10).to_a.each do |holes|
      holes_display_names << "#{holes}"
    end
    bore_holes = OpenStudio::Measure::OSArgument::makeChoiceArgument('bore_holes', holes_display_names, true)
    bore_holes.setDisplayName('Number of Bore Holes')
    bore_holes.setDescription('Number of vertical bores.')
    bore_holes.setDefaultValue(Constants.SizingAuto)
    args << bore_holes

    # make a string argument for gshp bore depth
    bore_depth = OpenStudio::Measure::OSArgument::makeStringArgument('bore_depth', true)
    bore_depth.setDisplayName('Bore Depth')
    bore_depth.setUnits('ft')
    bore_depth.setDescription('Vertical well bore depth typically range from 150 to 300 feet deep.')
    bore_depth.setDefaultValue(Constants.SizingAuto)
    args << bore_depth

    # make a double argument for gshp vert bore spacing
    bore_spacing = OpenStudio::Measure::OSArgument::makeDoubleArgument('bore_spacing', true)
    bore_spacing.setDisplayName('Bore Spacing')
    bore_spacing.setUnits('ft')
    bore_spacing.setDescription('Bore holes are typically spaced 15 to 20 feet apart.')
    bore_spacing.setDefaultValue(20.0)
    args << bore_spacing

    # make a double argument for gshp vert bore diameter
    bore_diameter = OpenStudio::Measure::OSArgument::makeDoubleArgument('bore_diameter', true)
    bore_diameter.setDisplayName('Bore Diameter')
    bore_diameter.setUnits('in')
    bore_diameter.setDescription('Bore hole diameter.')
    bore_diameter.setDefaultValue(5.0)
    args << bore_diameter

    # make a double argument for gshp vert bore nominal pipe size
    pipe_size = OpenStudio::Measure::OSArgument::makeDoubleArgument('pipe_size', true)
    pipe_size.setDisplayName('Nominal Pipe Size')
    pipe_size.setUnits('in')
    pipe_size.setDescription('Pipe nominal size.')
    pipe_size.setDefaultValue(0.75)
    args << pipe_size

    # make a double argument for gshp vert bore ground diffusivity
    ground_diffusivity = OpenStudio::Measure::OSArgument::makeDoubleArgument('ground_diffusivity', true)
    ground_diffusivity.setDisplayName('Ground Diffusivity')
    ground_diffusivity.setUnits('ft^2/hr')
    ground_diffusivity.setDescription('A measure of thermal inertia, the ground diffusivity is the thermal conductivity divided by density and specific heat capacity.')
    ground_diffusivity.setDefaultValue(0.0208)
    args << ground_diffusivity

    # make a string argument for gshp bore fluid type
    fluid_display_names = OpenStudio::StringVector.new
    fluid_display_names << Constants.FluidPropyleneGlycol
    fluid_display_names << Constants.FluidEthyleneGlycol
    fluid_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('fluid_type', fluid_display_names, true)
    fluid_type.setDisplayName('Heat Exchanger Fluid Type')
    fluid_type.setDescription('Fluid type.')
    fluid_type.setDefaultValue(Constants.FluidPropyleneGlycol)
    args << fluid_type

    # make a double argument for gshp vert bore frac glycol
    frac_glycol = OpenStudio::Measure::OSArgument::makeDoubleArgument('frac_glycol', true)
    frac_glycol.setDisplayName('Fraction Glycol')
    frac_glycol.setUnits('frac')
    frac_glycol.setDescription('Fraction of glycol, 0 indicates water.')
    frac_glycol.setDefaultValue(0.3)
    args << frac_glycol

    # make a double argument for gshp vert bore ground loop design delta temp
    design_delta_t = OpenStudio::Measure::OSArgument::makeDoubleArgument('design_delta_t', true)
    design_delta_t.setDisplayName('Ground Loop Design Delta Temp')
    design_delta_t.setUnits('deg F')
    design_delta_t.setDescription('Ground loop design temperature difference.')
    design_delta_t.setDefaultValue(10.0)
    args << design_delta_t

    # make a double argument for gshp vert bore pump head
    pump_head = OpenStudio::Measure::OSArgument::makeDoubleArgument('pump_head', true)
    pump_head.setDisplayName('Pump Head')
    pump_head.setUnits('ft of water')
    pump_head.setDescription('Feet of water column.')
    pump_head.setDefaultValue(50.0)
    args << pump_head

    # make a double argument for gshp vert bore u tube leg sep
    u_tube_leg_spacing = OpenStudio::Measure::OSArgument::makeDoubleArgument('u_tube_leg_spacing', true)
    u_tube_leg_spacing.setDisplayName('U Tube Leg Separation')
    u_tube_leg_spacing.setUnits('in')
    u_tube_leg_spacing.setDescription('U-tube leg spacing.')
    u_tube_leg_spacing.setDefaultValue(0.9661)
    args << u_tube_leg_spacing

    # make a choice argument for gshp vert bore u tube spacing type
    spacing_type_names = OpenStudio::StringVector.new
    spacing_type_names << 'as'
    spacing_type_names << 'b'
    spacing_type_names << 'c'
    u_tube_spacing_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('u_tube_spacing_type', spacing_type_names, true)
    u_tube_spacing_type.setDisplayName('U Tube Spacing Type')
    u_tube_spacing_type.setDescription('U-tube shank spacing type. Type B, for 5" bore is equivalent to 0.9661" shank spacing. Type C is the type where the U tube legs are furthest apart.')
    u_tube_spacing_type.setDefaultValue('b')
    args << u_tube_spacing_type

    # make a double argument for gshp vert bore supply fan power
    fan_power = OpenStudio::Measure::OSArgument::makeDoubleArgument('fan_power', true)
    fan_power.setDisplayName('Supply Fan Power')
    fan_power.setUnits('W/cfm')
    fan_power.setDescription('Fan power (in W) per delivered airflow rate (in cfm) of the indoor fan.')
    fan_power.setDefaultValue(0.5)
    args << fan_power

    # make a string argument for gshp heating/cooling output capacity
    heat_pump_capacity = OpenStudio::Measure::OSArgument::makeStringArgument('heat_pump_capacity', true)
    heat_pump_capacity.setDisplayName('Heat Pump Capacity')
    heat_pump_capacity.setDescription('The output heating/cooling capacity of the heat pump.')
    heat_pump_capacity.setUnits('tons')
    heat_pump_capacity.setDefaultValue(Constants.SizingAuto)
    args << heat_pump_capacity

    # make an argument for entering supplemental efficiency
    supplemental_efficiency = OpenStudio::Measure::OSArgument::makeDoubleArgument('supplemental_efficiency', true)
    supplemental_efficiency.setDisplayName('Supplemental Efficiency')
    supplemental_efficiency.setUnits('Btu/Btu')
    supplemental_efficiency.setDescription('The efficiency of the supplemental electric coil.')
    supplemental_efficiency.setDefaultValue(1.0)
    args << supplemental_efficiency

    # make a string argument for supplemental heating output capacity
    supplemental_capacity = OpenStudio::Measure::OSArgument::makeStringArgument('supplemental_capacity', true)
    supplemental_capacity.setDisplayName('Supplemental Heating Capacity')
    supplemental_capacity.setDescription('The output heating capacity of the supplemental heater.')
    supplemental_capacity.setUnits('kBtu/hr')
    supplemental_capacity.setDefaultValue(Constants.SizingAuto)
    args << supplemental_capacity

    # make a string argument for distribution system efficiency
    dse = OpenStudio::Measure::OSArgument::makeStringArgument('dse', true)
    dse.setDisplayName('Distribution System Efficiency')
    dse.setDescription('Defines the energy losses associated with the delivery of energy from the equipment to the source of the load.')
    dse.setDefaultValue('NA')
    args << dse

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    cop = runner.getDoubleArgumentValue('cop', user_arguments)
    eer = runner.getDoubleArgumentValue('eer', user_arguments)
    shr = runner.getDoubleArgumentValue('shr', user_arguments)
    ground_conductivity = runner.getDoubleArgumentValue('ground_conductivity', user_arguments)
    grout_conductivity = runner.getDoubleArgumentValue('grout_conductivity', user_arguments)
    bore_config = runner.getStringArgumentValue('bore_config', user_arguments)
    bore_holes = runner.getStringArgumentValue('bore_holes', user_arguments)
    bore_depth = runner.getStringArgumentValue('bore_depth', user_arguments)
    bore_spacing = runner.getDoubleArgumentValue('bore_spacing', user_arguments)
    bore_diameter = runner.getDoubleArgumentValue('bore_diameter', user_arguments)
    pipe_size = runner.getDoubleArgumentValue('pipe_size', user_arguments)
    ground_diffusivity = runner.getDoubleArgumentValue('ground_diffusivity', user_arguments)
    fluid_type = runner.getStringArgumentValue('fluid_type', user_arguments)
    frac_glycol = runner.getDoubleArgumentValue('frac_glycol', user_arguments)
    design_delta_t = runner.getDoubleArgumentValue('design_delta_t', user_arguments)
    pump_head = UnitConversions.convert(UnitConversions.convert(runner.getDoubleArgumentValue('pump_head', user_arguments), 'ft', 'in'), 'inH2O', 'Pa') # convert from ft H20 to Pascal
    u_tube_leg_spacing = runner.getDoubleArgumentValue('u_tube_leg_spacing', user_arguments)
    u_tube_spacing_type = runner.getStringArgumentValue('u_tube_spacing_type', user_arguments)
    fan_power = runner.getDoubleArgumentValue('fan_power', user_arguments)
    heat_pump_capacity = runner.getStringArgumentValue('heat_pump_capacity', user_arguments)
    unless heat_pump_capacity == Constants.SizingAuto
      heat_pump_capacity = UnitConversions.convert(heat_pump_capacity.to_f, 'ton', 'Btu/hr')
    end
    supplemental_efficiency = runner.getDoubleArgumentValue('supplemental_efficiency', user_arguments)
    supplemental_capacity = runner.getStringArgumentValue('supplemental_capacity', user_arguments)
    unless supplemental_capacity == Constants.SizingAuto
      supplemental_capacity = UnitConversions.convert(supplemental_capacity.to_f, 'kBtu/hr', 'Btu/hr')
    end
    dse = runner.getStringArgumentValue('dse', user_arguments)
    if dse.to_f > 0
      dse = dse.to_f
    else
      dse = 1.0
    end
    frac_heat_load_served = 1.0
    frac_cool_load_served = 1.0

    # Ground Loop And Loop Pump
    weather = WeatherProcess.new(model, runner)
    if weather.error?
      return false
    end

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    units.each do |unit|
      thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)
      HVAC.get_control_and_slave_zones(thermal_zones).each do |control_zone, slave_zones|
        ([control_zone] + slave_zones).each do |zone|
          HVAC.remove_heating(model, runner, zone, unit)
          HVAC.remove_cooling(model, runner, zone, unit)
        end
      end

      success = HVAC.apply_gshp(model, unit, runner, weather, cop, eer, shr,
                                ground_conductivity, grout_conductivity,
                                bore_config, bore_holes, bore_depth,
                                bore_spacing, bore_diameter, pipe_size,
                                ground_diffusivity, fluid_type, frac_glycol,
                                design_delta_t, pump_head,
                                u_tube_leg_spacing, u_tube_spacing_type,
                                fan_power, heat_pump_capacity, supplemental_efficiency,
                                supplemental_capacity, dse,
                                frac_heat_load_served, frac_cool_load_served)
      return false if not success
    end

    return true
  end
end

# register the measure to be used by the application
ProcessGroundSourceHeatPumpVerticalBore.new.registerWithApplication
