# frozen_string_literal: true

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'waterheater')
require File.join(resources_path, 'appliances')

# start the measure
class ResidentialClothesWasher < OpenStudio::Measure::ModelMeasure
  def name
    return 'Set Residential Clothes Washer'
  end

  def description
    return "Adds (or replaces) a residential clothes washer with the specified efficiency, operation, and schedule. For multifamily buildings, the clothes washer can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Since there is no Clothes Washer object in OpenStudio/EnergyPlus, we look for an ElectricEquipment object with the name that denotes it is a residential clothes washer. If one is found, it is replaced with the specified properties. Otherwise, a new such object is added to the model. Note: This measure requires the number of bedrooms/bathrooms to have already been assigned.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for Integrated Modified Energy Factor
    imef = OpenStudio::Measure::OSArgument::makeDoubleArgument('imef', true)
    imef.setDisplayName('Integrated Modified Energy Factor')
    imef.setUnits('ft^3/kWh-cycle')
    imef.setDescription('The Integrated Modified Energy Factor (IMEF) is the capacity of the clothes container divided by the total clothes washer energy consumption per cycle, where the energy consumption is the sum of the machine electrical energy consumption, the hot water energy consumption, the energy required for removal of the remaining moisture in the wash load, standby energy, and off-mode energy consumption. If only a Modified Energy Factor (MEF) is available, convert using the equation: IMEF = (MEF - 0.503) / 0.95.')
    imef.setDefaultValue(0.95)
    args << imef

    # make a double argument for Rated Annual Consumption
    rated_annual_energy = OpenStudio::Measure::OSArgument::makeDoubleArgument('rated_annual_energy', true)
    rated_annual_energy.setDisplayName('Rated Annual Consumption')
    rated_annual_energy.setUnits('kWh')
    rated_annual_energy.setDescription('The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating.')
    rated_annual_energy.setDefaultValue(387.0)
    args << rated_annual_energy

    # make a double argument for Annual Cost With Gas DHW
    annual_cost = OpenStudio::Measure::OSArgument::makeDoubleArgument('annual_cost', true)
    annual_cost.setDisplayName('Annual Cost with Gas DHW')
    annual_cost.setUnits('$')
    annual_cost.setDescription('The annual cost of using the system under test conditions.  Input is obtained from the EnergyGuide label.')
    annual_cost.setDefaultValue(24.0)
    args << annual_cost

    # make an integer argument for Test Date
    test_date = OpenStudio::Measure::OSArgument::makeIntegerArgument('test_date', true)
    test_date.setDisplayName('Test Date')
    test_date.setDefaultValue(2007)
    test_date.setDescription('Input obtained from EnergyGuide labels.  The new E-guide labels state that the test was performed under the 2004 DOE procedure, otherwise use year < 2004.')
    args << test_date

    # make a double argument for Drum Volume
    drum_volume = OpenStudio::Measure::OSArgument::makeDoubleArgument('drum_volume', true)
    drum_volume.setDisplayName('Drum Volume')
    drum_volume.setUnits('ft^3')
    drum_volume.setDescription("Volume of the washer drum.  Obtained from the EnergyStar website or the manufacturer's literature.")
    drum_volume.setDefaultValue(3.5)
    args << drum_volume

    # make a boolean argument for Use Cold Cycle Only
    cold_cycle = OpenStudio::Measure::OSArgument::makeBoolArgument('cold_cycle', true)
    cold_cycle.setDisplayName('Use Cold Cycle Only')
    cold_cycle.setDescription('The washer is operated using only the cold cycle.')
    cold_cycle.setDefaultValue(false)
    args << cold_cycle

    # make a boolean argument for Thermostatic Control
    thermostatic_control = OpenStudio::Measure::OSArgument::makeBoolArgument('thermostatic_control', true)
    thermostatic_control.setDisplayName('Thermostatic Control')
    thermostatic_control.setDescription("The clothes washer uses hot and cold water inlet valves to control temperature (varies hot water volume to control wash temperature).  Use this option for machines that use hot and cold inlet valves to control wash water temperature or machines that use both inlet valves AND internal electric heaters to control temperature of the wash water.  Input obtained from the manufacturer's literature.")
    thermostatic_control.setDefaultValue(true)
    args << thermostatic_control

    # make a boolean argument for Has Internal Heater Adjustment
    internal_heater = OpenStudio::Measure::OSArgument::makeBoolArgument('internal_heater', true)
    internal_heater.setDisplayName('Has Internal Heater Adjustment')
    internal_heater.setDescription("The washer uses an internal electric heater to adjust the temperature of wash water.  Use this option for washers that have hot and cold water connections but use an internal electric heater to adjust the wash water temperature.  Obtain the input from the manufacturer's literature.")
    internal_heater.setDefaultValue(false)
    args << internal_heater

    # make a boolean argument for Has Water Level Fill Sensor
    fill_sensor = OpenStudio::Measure::OSArgument::makeBoolArgument('fill_sensor', true)
    fill_sensor.setDisplayName('Has Water Level Fill Sensor')
    fill_sensor.setDescription("The washer has a vertical axis and water level fill sensor.  Input obtained from the manufacturer's literature.")
    fill_sensor.setDefaultValue(false)
    args << fill_sensor

    # make a double argument for occupancy energy multiplier
    mult_e = OpenStudio::Measure::OSArgument::makeDoubleArgument('mult_e', true)
    mult_e.setDisplayName('Occupancy Energy Multiplier')
    mult_e.setDescription('Appliance energy use is multiplied by this factor to account for occupancy usage that differs from the national average.')
    mult_e.setDefaultValue(1)
    args << mult_e

    # make a double argument for occupancy water multiplier
    mult_hw = OpenStudio::Measure::OSArgument::makeDoubleArgument('mult_hw', true)
    mult_hw.setDisplayName('Occupancy Hot Water Multiplier')
    mult_hw.setDescription('Appliance hot water use is multiplied by this factor to account for occupancy usage that differs from the national average. This should generally be equal to the Occupancy Energy Multiplier.')
    mult_hw.setDefaultValue(1)
    args << mult_hw

    # make a choice argument for location
    location_args = OpenStudio::StringVector.new
    location_args << Constants.Auto
    Geometry.get_model_locations(model).each do |loc|
      location_args << loc
    end
    location = OpenStudio::Measure::OSArgument::makeChoiceArgument('location', location_args, true, true)
    location.setDisplayName('Location')
    location.setDescription("The space type for the location. '#{Constants.Auto}' will automatically choose a space type based on the space types found in the model.")
    location.setDefaultValue(Constants.Auto)
    args << location

    # make a choice argument for plant loop
    plant_loops = model.getPlantLoops
    plant_loop_args = OpenStudio::StringVector.new
    plant_loop_args << Constants.Auto
    plant_loops.each do |plant_loop|
      plant_loop_args << plant_loop.name.to_s
    end
    plant_loop = OpenStudio::Measure::OSArgument::makeChoiceArgument('plant_loop', plant_loop_args, true, true)
    plant_loop.setDisplayName('Plant Loop')
    plant_loop.setDescription("Select the plant loop for the dishwasher. '#{Constants.Auto}' will try to choose the plant loop associated with the specified space. For multifamily buildings, '#{Constants.Auto}' will choose the plant loop for each unit of the building.")
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
    imef = runner.getDoubleArgumentValue('imef', user_arguments)
    rated_annual_energy = runner.getDoubleArgumentValue('rated_annual_energy', user_arguments)
    annual_cost = runner.getDoubleArgumentValue('annual_cost', user_arguments)
    test_date = runner.getIntegerArgumentValue('test_date', user_arguments)
    drum_volume = runner.getDoubleArgumentValue('drum_volume', user_arguments)
    cold_cycle = runner.getBoolArgumentValue('cold_cycle', user_arguments)
    thermostatic_control = runner.getBoolArgumentValue('thermostatic_control', user_arguments)
    internal_heater = runner.getBoolArgumentValue('internal_heater', user_arguments)
    fill_sensor = runner.getBoolArgumentValue('fill_sensor', user_arguments)
    mult_e = runner.getDoubleArgumentValue('mult_e', user_arguments)
    mult_hw = runner.getDoubleArgumentValue('mult_hw', user_arguments)
    location = runner.getStringArgumentValue('location', user_arguments)
    plant_loop_s = runner.getStringArgumentValue('plant_loop', user_arguments)

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    # Remove all existing objects
    obj_name = Constants.ObjectNameClothesWasher
    model.getSpaces.each do |space|
      ClothesWasher.remove(runner, space, obj_name)
    end

    location_hierarchy = [Constants.SpaceTypeLaundryRoom,
                          Constants.SpaceTypeLiving,
                          Constants.SpaceTypeFinishedBasement,
                          Constants.SpaceTypeUnfinishedBasement,
                          Constants.SpaceTypeGarage]

    schedules_file = SchedulesFile.new(runner: runner, model: model)
    if not schedules_file.validated?
      return false
    end

    tot_ann_e = 0
    msgs = []
    sch = nil
    cd_msgs = []
    cd_sch = nil
    mains_temps = nil
    units.each_with_index do |unit, unit_index|
      # Get space
      space = Geometry.get_space_from_location(unit, location, location_hierarchy)
      next if space.nil?

      # Get plant loop
      plant_loop = Waterheater.get_plant_loop_from_string(model, runner, plant_loop_s, unit)
      if plant_loop.nil?
        next
      end

      success, ann_e, cd_updated, cd_sch, mains_temps = ClothesWasher.apply(model, unit, runner, imef, rated_annual_energy, annual_cost,
                                                                            test_date, drum_volume, cold_cycle, thermostatic_control,
                                                                            internal_heater, fill_sensor, mult_e, mult_hw, cd_sch,
                                                                            space, plant_loop, mains_temps, sch, schedules_file)

      if not success
        return false
      end

      if ann_e > 0
        msgs << "A clothes washer with #{ann_e.round} kWhs annual energy consumption has been added to plant loop '#{plant_loop.name}' and assigned to space '#{space.name}'."
      end

      if cd_updated
        cd_msgs << "The clothes dryer assigned to space '#{space.name}' has been updated."
      end

      tot_ann_e += ann_e
    end

    schedules_file.set_vacancy(col_name: 'clothes_washer_power')

    # Reporting
    if (msgs.size + cd_msgs.size) > 1
      msgs.each do |msg|
        runner.registerInfo(msg)
      end
      cd_msgs.each do |cd_msg|
        runner.registerInfo(cd_msg)
      end
      runner.registerFinalCondition("The building has been assigned clothes washers totaling #{tot_ann_e.round} kWhs annual energy consumption across #{units.size} units.")
    elsif msgs.size == 1
      runner.registerFinalCondition(msgs[0])
    else
      runner.registerFinalCondition('No clothes washer has been assigned.')
    end

    return true
  end
end # end the measure

# this allows the measure to be use by the application
ResidentialClothesWasher.new.registerWithApplication
