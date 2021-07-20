# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'json'

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'constants')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'schedules')

# start the measure
class ResidentialGeometryFromFloorspaceJS < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Residential Geometry from FloorspaceJS'
  end

  # human readable description
  def description
    return "Imports a floorplan JSON file written by the FloorspaceJS tool. Sets the number of bedrooms, bathrooms, and occupants in the building.#{Constants.WorkflowDescription}"
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Currently this measure deletes the existing geometry and replaces it. Also, sets (or replaces) BuildingUnit objects that store the number of bedrooms and bathrooms associated with the model. Sets (or replaces) the People object for each finished space in the model.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # path to the floorplan JSON file to load
    arg = OpenStudio::Ruleset::OSArgument.makeStringArgument('floorplan_path', true)
    arg.setDisplayName('Floorplan Path')
    arg.setDescription('Path to the floorplan JSON.')
    arg.setDefaultValue(File.join(File.dirname(__FILE__), 'tests', 'SFD_Multizone.json'))
    args << arg

    # make a string argument for number of bedrooms
    num_br = OpenStudio::Measure::OSArgument::makeStringArgument('num_bedrooms', false)
    num_br.setDisplayName('Number of Bedrooms')
    num_br.setDescription('Specify the number of bedrooms. Used to determine the energy usage of appliances and plug loads, hot water usage, mechanical ventilation rate, etc.')
    num_br.setDefaultValue('3')
    args << num_br

    # make a string argument for number of bathrooms
    num_ba = OpenStudio::Measure::OSArgument::makeStringArgument('num_bathrooms', false)
    num_ba.setDisplayName('Number of Bathrooms')
    num_ba.setDescription('Specify the number of bathrooms. Used to determine the hot water usage, etc.')
    num_ba.setDefaultValue('2')
    args << num_ba

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    floorplan_path = runner.getStringArgumentValue('floorplan_path', user_arguments)
    num_br = runner.getStringArgumentValue('num_bedrooms', user_arguments).split(',').map(&:strip)
    num_ba = runner.getStringArgumentValue('num_bathrooms', user_arguments).split(',').map(&:strip)
    num_occupants = Constants.Auto
    if model.getBuilding.additionalProperties.getFeatureAsInteger('num_occupants').is_initialized
      num_occupants = "#{model.getBuilding.additionalProperties.getFeatureAsInteger('num_occupants').get}"
    end

    # check the floorplan_path for reasonableness
    if floorplan_path.empty?
      runner.registerError('Empty floorplan path was entered.')
      return false
    end

    path = runner.workflow.findFile(floorplan_path)
    if path.empty?
      runner.registerError("Cannot find floorplan path '#{floorplan_path}'.")
      return false
    end

    json = nil
    File.open(path.get.to_s, 'r') do |file|
      json = file.read
    end

    floorplan = OpenStudio::FloorplanJS::load(json)
    if floorplan.empty?
      runner.registerError("Cannot load floorplan from '#{floorplan_path}'.")
      return false
    end

    scene = floorplan.get.toThreeScene(true)
    rt = OpenStudio::Model::ThreeJSReverseTranslator.new
    new_model = rt.modelFromThreeJS(scene)

    unless new_model.is_initialized
      runner.registerError('Cannot convert floorplan to model.')
      return false
    end
    new_model = new_model.get

    runner.registerInitialCondition("Initial model has #{model.getPlanarSurfaceGroups.size} planar surface groups.")

    mm = OpenStudio::Model::ModelMerger.new
    mm.mergeModels(model, new_model, rt.handleMapping)

    mm.warnings.each do |warnings|
      runner.registerWarning(warnings.logMessage)
    end

    # put all of the spaces in the model into a vector
    spaces = OpenStudio::Model::SpaceVector.new
    model.getSpaces.each do |space|
      spaces << space
    end

    # intersect and match surfaces for each space in the vector
    OpenStudio::Model.intersectSurfaces(spaces)
    OpenStudio::Model.matchSurfaces(spaces)

    json = JSON.parse(json)

    # error checking
    unless json['space_types'].length > 0
      runner.registerError('No space types were created.')
      return false
    end

    # set the space type standards fields based on what user wrote in the editor
    json['space_types'].each do |st|
      model.getSpaceTypes.each do |space_type|
        next unless st['name'] == space_type.name.to_s

        space_type.setStandardsSpaceType(st['name'])
      end
    end

    # remove any unused space types
    model.getSpaceTypes.each do |space_type|
      if space_type.spaces.length == 0
        space_type.remove
      end
    end

    # permit only expected space type names
    model.getSpaceTypes.each do |space_type|
      next if Constants.ExpectedSpaceTypes.include? space_type.standardsSpaceType.get

      runner.registerError("Unexpected space type '#{space_type.standardsSpaceType.get}'. Supported space types are: '#{Constants.ExpectedSpaceTypes.join("', '")}'.")
      return false
    end

    # for any spaces with no assigned zone, create (unless another space of the same space type has an assigned zone) a thermal zone based on the space type
    model.getSpaceTypes.each do |space_type|
      space_type.spaces.each do |space|
        next if space.thermalZone.is_initialized

        thermal_zone = OpenStudio::Model::ThermalZone.new(model)
        thermal_zone.setName(space.name.to_s)
        space.setThermalZone(thermal_zone)
      end
    end

    # ensure that all spaces in a zone are either all finished or all unfinished
    model.getThermalZones.each do |thermal_zone|
      if thermal_zone.spaces.length == 0
        thermal_zone.remove
        next
      end
      unless thermal_zone.spaces.map { |space| Geometry.space_is_finished(space) }.uniq.size == 1
        runner.registerError("'#{thermal_zone.name}' has a mix of finished and unfinished spaces.")
        return false
      end
    end

    # set some required meta information
    if model.getBuildingUnits.length == 1
      model.getBuilding.setStandardsBuildingType(Constants.BuildingTypeSingleFamilyDetached)
    else # SFA or MF
      if model.getBuildingUnits.select { |building_unit| Geometry.get_building_stories(building_unit.spaces) > 1 }.any?
        model.getBuilding.setStandardsBuildingType(Constants.BuildingTypeSingleFamilyAttached)
      else
        model.getBuilding.setStandardsBuildingType(Constants.BuildingTypeMultifamily)
      end
    end
    model.getBuilding.setStandardsNumberOfAboveGroundStories(Geometry.get_building_stories(model.getSpaces)) # FIXME: how to count finished attics as well?

    # make all surfaces adjacent to corridor spaces into adiabatic surfaces
    model.getSpaces.each do |space|
      next unless Geometry.is_corridor(space)

      space.surfaces.each do |surface|
        if surface.adjacentSurface.is_initialized
          surface.adjacentSurface.get.setOutsideBoundaryCondition('Adiabatic')
        end
        surface.setOutsideBoundaryCondition('Adiabatic')
      end
    end

    model.getSurfaces.each do |surface|
      next unless surface.outsideBoundaryCondition.downcase == 'surface'
      next if surface.adjacentSurface.is_initialized

      surface.setOutsideBoundaryCondition('Adiabatic')
    end

    result = Geometry.process_beds_and_baths(model, runner, num_br, num_ba)
    unless result
      return false
    end

    schedules_file = SchedulesFile.new(runner: runner, model: model)
    if not schedules_file.validated?
      return false
    end

    result = Geometry.process_occupants(model, runner, num_occupants, occ_gain = 384.0, sens_frac = 0.573, lat_frac = 0.427, schedules_file)
    unless result
      return false
    end

    # reporting final condition of model
    runner.registerFinalCondition("Final model has #{model.getPlanarSurfaceGroups.size} planar surface groups.")

    return true
  end
end

# register the measure to be used by the application
ResidentialGeometryFromFloorspaceJS.new.registerWithApplication
