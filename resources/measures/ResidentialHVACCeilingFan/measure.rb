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

# start the measure
class ProcessCeilingFan < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Set Residential Ceiling Fan'
  end

  # human readable description
  def description
    return "Adds (or replaces) residential ceiling fan(s) and schedule in all finished spaces. For multifamily buildings, the ceiling fan(s) can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Since there is no Ceiling Fan object in OpenStudio/EnergyPlus, we look for an ElectricEquipment object with the name that denotes it is residential ceiling fan. If one is found, it is replaced with the specified properties. Otherwise, a new such object is added to the model. Note: This measure requires the number of bedrooms/bathrooms to have already been assigned.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a string argument for coverage
    coverage = OpenStudio::Measure::OSArgument::makeStringArgument('coverage', true)
    coverage.setDisplayName('Coverage')
    coverage.setUnits('frac')
    coverage.setDescription('Fraction of house conditioned by fans where # fans = (above-grade finished floor area)/(% coverage)/300.')
    coverage.setDefaultValue('NA')
    args << coverage

    # make a string argument for specified number
    specified_num = OpenStudio::Measure::OSArgument::makeStringArgument('specified_num', true)
    specified_num.setDisplayName('Specified Number')
    specified_num.setUnits('#/unit')
    specified_num.setDescription('Total number of fans.')
    specified_num.setDefaultValue('1')
    args << specified_num

    # make a double argument for power
    power = OpenStudio::Measure::OSArgument::makeDoubleArgument('power', true)
    power.setDisplayName('Power')
    power.setUnits('W')
    power.setDescription('Power consumption per fan assuming it runs at medium speed.')
    power.setDefaultValue(45.0)
    args << power

    # make choice arguments for control
    control_names = OpenStudio::StringVector.new
    control_names << Constants.CeilingFanControlTypical
    control_names << Constants.CeilingFanControlSmart
    control = OpenStudio::Measure::OSArgument::makeChoiceArgument('control', control_names, true)
    control.setDisplayName('Control')
    control.setDescription("'typical' indicates half of the fans will be on whenever the interior temperature is above the cooling setpoint; 'smart' indicates 50% of the energy consumption of 'typical.'")
    control.setDefaultValue(Constants.CeilingFanControlTypical)
    args << control

    # make a bool argument for using benchmark energy
    use_benchmark_energy = OpenStudio::Measure::OSArgument::makeBoolArgument('use_benchmark_energy', true)
    use_benchmark_energy.setDisplayName('Use Benchmark Energy')
    use_benchmark_energy.setDescription('Use the energy value specified in the BA Benchmark: 77.3 + 0.0403 x FFA kWh/yr, where FFA is Finished Floor Area.')
    use_benchmark_energy.setDefaultValue(true)
    args << use_benchmark_energy

    # make a double argument for BA Benchamrk multiplier
    mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('mult')
    mult.setDisplayName('Building America Benchmark Multiplier')
    mult.setDefaultValue(1)
    mult.setDescription("A multiplier on the national average energy use. Only applies if 'Use Benchmark Energy' is set to True.")
    args << mult

    # make a double argument for cooling setpoint offset
    cooling_setpoint_offset = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_setpoint_offset', true)
    cooling_setpoint_offset.setDisplayName('Cooling Setpoint Offset')
    cooling_setpoint_offset.setUnits('degrees F')
    cooling_setpoint_offset.setDescription('Increase in cooling set point due to fan usage.')
    cooling_setpoint_offset.setDefaultValue(0)
    args << cooling_setpoint_offset

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    coverage = runner.getStringArgumentValue('coverage', user_arguments)
    unless coverage == 'NA'
      coverage = coverage.to_f
    else
      coverage = nil
    end
    specified_num = runner.getStringArgumentValue('specified_num', user_arguments)
    unless specified_num == 'NA'
      specified_num = specified_num.to_f
    else
      specified_num = nil
    end
    power = runner.getDoubleArgumentValue('power', user_arguments)
    control = runner.getStringArgumentValue('control', user_arguments)
    use_benchmark_energy = runner.getBoolArgumentValue('use_benchmark_energy', user_arguments)
    cooling_setpoint_offset = runner.getDoubleArgumentValue('cooling_setpoint_offset', user_arguments)
    mult = runner.getDoubleArgumentValue('mult', user_arguments)

    if use_benchmark_energy
      coverage = nil
      specified_num = nil
      power = nil
      control = nil
    end

    # get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    schedules_file = SchedulesFile.new(runner: runner, model: model)
    if not schedules_file.validated?
      return false
    end

    sch = nil
    units.each do |unit|
      HVAC.remove_ceiling_fans(runner, model, unit)

      success, sch = HVAC.apply_ceiling_fans(model, unit, runner, coverage, specified_num, power,
                                             control, use_benchmark_energy, cooling_setpoint_offset,
                                             mult, sch, schedules_file)
      return false if not success
    end # units

    schedules_file.set_vacancy(col_name: 'ceiling_fan')

    return true
  end
end

# register the measure to be used by the application
ProcessCeilingFan.new.registerWithApplication
