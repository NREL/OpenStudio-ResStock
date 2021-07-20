# frozen_string_literal: true

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'appliances')

# start the measure
class ResidentialCookingRange < OpenStudio::Measure::ModelMeasure
  def name
    return 'Set Residential Cooking Range'
  end

  def description
    return "Adds (or replaces) a residential cooking range with the specified efficiency, operation, and schedule. For multifamily buildings, the cooking range can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Since there is no Cooking Range object in OpenStudio/EnergyPlus, we look for an OtherEquipment or ElectricEquipment object with the name that denotes it is a residential cooking range. If one is found, it is replaced with the specified properties. Otherwise, a new such object is added to the model. Note: This measure requires the number of bedrooms/bathrooms to have already been assigned.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for Fuel Type
    fuel_display_names = OpenStudio::StringVector.new
    fuel_display_names << Constants.FuelTypeGas
    fuel_display_names << Constants.FuelTypePropane
    fuel_display_names << Constants.FuelTypeElectric
    fuel_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('fuel_type', fuel_display_names, true)
    fuel_type.setDisplayName('Fuel Type')
    fuel_type.setDescription('Type of fuel used by the cooking range.')
    fuel_type.setDefaultValue(Constants.FuelTypeGas)
    args << fuel_type

    # make a double argument for cooktop EF
    cooktop_ef = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooktop_ef', true)
    cooktop_ef.setDisplayName('Cooktop Energy Factor')
    cooktop_ef.setDescription('Cooktop energy factor determined by DOE test procedures for cooking appliances (DOE 1997).')
    cooktop_ef.setDefaultValue(0.4)
    args << cooktop_ef

    # make a double argument for oven EF
    oven_ef = OpenStudio::Measure::OSArgument::makeDoubleArgument('oven_ef', true)
    oven_ef.setDisplayName('Oven Energy Factor')
    oven_ef.setDescription('Oven energy factor determined by DOE test procedures for cooking appliances (DOE 1997).')
    oven_ef.setDefaultValue(0.058)
    args << oven_ef

    # make a boolean argument for has electric ignition
    has_elec_ignition = OpenStudio::Measure::OSArgument::makeBoolArgument('has_elec_ignition', true)
    has_elec_ignition.setDisplayName('Has Electronic Ignition')
    has_elec_ignition.setDescription('For fuel cooking ranges with electronic ignition, an extra (40 + 13.3x(#BR)) kWh/yr of electricity will be included. Only used for non-electric ranges.')
    has_elec_ignition.setDefaultValue(true)
    args << has_elec_ignition

    # make a double argument for Occupancy Energy Multiplier
    mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('mult', true)
    mult.setDisplayName('Occupancy Energy Multiplier')
    mult.setDescription('Appliance energy use is multiplied by this factor to account for occupancy usage that differs from the national average.')
    mult.setDefaultValue(1)
    args << mult

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
    fuel_type = runner.getStringArgumentValue('fuel_type', user_arguments)
    cooktop_ef = runner.getDoubleArgumentValue('cooktop_ef', user_arguments)
    oven_ef = runner.getDoubleArgumentValue('oven_ef', user_arguments)
    has_elec_ignition = runner.getBoolArgumentValue('has_elec_ignition', user_arguments)
    mult = runner.getDoubleArgumentValue('mult', user_arguments)
    location = runner.getStringArgumentValue('location', user_arguments)

    if fuel_type == Constants.FuelTypeElectric
      has_elec_ignition = false
    end

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    # Remove all existing objects
    obj_name = Constants.ObjectNameCookingRange(nil)
    model.getSpaces.each do |space|
      CookingRange.remove(runner, space, obj_name)
    end

    location_hierarchy = [Constants.SpaceTypeKitchen,
                          Constants.SpaceTypeLiving,
                          Constants.SpaceTypeFinishedBasement,
                          Constants.SpaceTypeUnfinishedBasement,
                          Constants.SpaceTypeGarage]

    schedules_file = SchedulesFile.new(runner: runner, model: model)
    if not schedules_file.validated?
      return false
    end

    tot_ann_e = 0
    tot_ann_f = 0
    tot_ann_i = 0
    msgs = []
    sch = nil
    units.each_with_index do |unit, unit_index|
      # Get space
      space = Geometry.get_space_from_location(unit, location, location_hierarchy)
      next if space.nil?

      success, ann_e, ann_f, ann_i, sch = CookingRange.apply(model, unit, runner, fuel_type, cooktop_ef, oven_ef,
                                                             has_elec_ignition, mult, sch, space, schedules_file)

      if not success
        return false
      end

      if ann_f > 0
        # Report each assignment plus final condition
        s_ann = ''
        if fuel_type == Constants.FuelTypeGas
          s_ann = "#{ann_f.round} therms"
        else
          s_ann = "#{UnitConversions.convert(UnitConversions.convert(ann_f, 'therm', 'Btu'), 'Btu', 'gal', fuel_type).round} gallons"
        end
        s_ignition = ''
        if has_elec_ignition
          s_ignition = " and #{ann_i.round} kWhs"
        end
        msgs << "A cooking range with #{s_ann}#{s_ignition} annual energy consumption has been assigned to space '#{space.name}'."
      else
        msgs << "A cooking range with #{ann_e.round} kWhs annual energy consumption has been assigned to space '#{space.name}'."
      end

      tot_ann_e += ann_e
      tot_ann_f += ann_f
      tot_ann_i += ann_i
    end

    schedules_file.set_vacancy(col_name: 'cooking_range')

    # Reporting
    if msgs.size > 1
      msgs.each do |msg|
        runner.registerInfo(msg)
      end
      if tot_ann_f > 0
        s_ann = ''
        if fuel_type == Constants.FuelTypeGas
          s_ann = "#{tot_ann_f.round} therms"
        else
          s_ann = "#{UnitConversions.convert(UnitConversions.convert(tot_ann_f, 'therm', 'Btu'), 'Btu', 'gal', fuel_type).round} gallons"
        end
        s_ignition = ''
        if has_elec_ignition
          s_ignition = " and #{tot_ann_i.round} kWhs"
        end
        runner.registerFinalCondition("The building has been assigned cooking ranges totaling #{s_ann}#{s_ignition} annual energy consumption across #{units.size} units.")
      elsif tot_ann_e > 0
        runner.registerFinalCondition("The building has been assigned cooking ranges totaling #{tot_ann_e.round} kWhs annual energy consumption across #{units.size} units.")
      end
    elsif msgs.size == 1
      runner.registerFinalCondition(msgs[0])
    else
      runner.registerFinalCondition('No cooking range has been assigned.')
    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ResidentialCookingRange.new.registerWithApplication
