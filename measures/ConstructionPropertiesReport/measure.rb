# frozen_string_literal: true

# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'erb'
if File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock on AWS
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock unit tests locally
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources')
else
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
end
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'unit_conversions')

# start the measure
class ConstructionPropertiesReport < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Construction Properties Report'
  end

  # human readable description
  def description
    return 'Calculate thermal capacitance and UA for surfaces, furniture, and spaces.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Calculate thermal capacitance and UA for surfaces, furniture, and spaces.'
  end

  # define the arguments that the user will input
  def arguments
    args = OpenStudio::Measure::OSArgumentVector.new

    # make an bool argument for whether to register to results csv or export to csv
    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('register_values', true)
    arg.setDisplayName('Register Values')
    arg.setDescription('Whether to register values to results csv or export to separate csv.')
    arg.setDefaultValue(true)
    args << arg

    return args
  end

  def metrics
    return ['thermal_mass', 'ua']
  end

  # define the outputs that the measure will create
  def outputs
    constructions = [
      'floor_fin_ins_unfin_attic', # unfinished attic floor
      'floor_fin_ins_unfin', # interzonal or cantilevered floor
      'floor_fin_unins_fin', # floor between 1st/2nd story living spaces
      'floor_unfin_unins_unfin', # floor between garage and attic
      'floor_fnd_grnd_fin_b', # finished basement floor
      'floor_fnd_grnd_unfin_b', # unfinished basement floor
      'floor_fnd_grnd_fin_slab', # finished slab
      'floor_fnd_grnd_unfin_slab', # garage slab
      'floor_unfin_b_ins_fin', # unfinished basement ceiling
      'floor_cs_ins_fin', # crawlspace ceiling
      'floor_pb_ins_fin', # pier beam ceiling
      'floor_fnd_grnd_cs', # crawlspace floor
      'roof_unfin_unins_ext', # garage roof
      'roof_unfin_ins_ext', # unfinished attic roof
      'roof_fin_ins_ext', # finished attic roof
      'wall_ext_ins_fin', # living exterior wall
      'wall_ext_ins_unfin', # attic gable wall under insulated roof
      'wall_ext_unins_unfin', # garage exterior wall or attic gable wall under uninsulated roof
      'wall_fnd_grnd_fin_b', # finished basement wall
      'wall_fnd_grnd_unfin_b', # unfinished basement wall
      'wall_fnd_grnd_cs', # crawlspace wall
      'wall_int_fin_ins_unfin', # interzonal wall
      'wall_int_fin_unins_fin', # wall between two finished spaces
      'wall_int_unfin_unins_unfin', # wall between two unfinished spaces
      'living_space_footing_construction', # living space footing construction
      'garage_space_footing_construction', # garage space footing construction
      # "window_construction", # exterior window
      'door', # exterior door
      'res_furniture_construction_living_space', # furniture in living
      'res_furniture_construction_living_space_story_2', # furniture in living, second floor
      'res_furniture_construction_unfinished_basement_space', # furniture in unfinished basement
      'res_furniture_construction_finished_basement_space', # furniture in finished basement
      'res_furniture_construction_garage_space', # furniture in garage
      'living_zone', # living space air
      'garage_zone', # garage space air
      'unfinished_basement_zone', # unfinished basement space air
      'finished_basement_zone', # finished basement space air
      'crawl_zone', # crawl space air
      'unfinished_attic_zone' # unfinished attic space air
    ]

    result = OpenStudio::Measure::OSOutputVector.new
    metrics.each do |metric|
      constructions.each do |construction|
        result << OpenStudio::Measure::OSOutput.makeDoubleOutput("#{metric}_#{construction}")
      end
    end
    return result
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments, user_arguments)
      return false
    end

    register_values = runner.getBoolArgumentValue('register_values', user_arguments)

    # get the last model and sql file

    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)

    areas = {}
    model.getConstructions.each do |construction|
      name = construction.name.to_s
      surface_area = get_surface_area(model, construction)
      sub_surface_area = get_sub_surface_area(model, construction)
      internal_mass_area = get_internal_mass_area(model, construction)
      area = surface_area + sub_surface_area + internal_mass_area
      next unless area > 0

      areas[name] = area
    end

    calculations = {}
    metrics.each do |metric|
      calculations[metric] = {}
      model.getConstructions.each do |construction|
        name = construction.name.to_s
        next unless areas.keys.include? name

        case metric
        when 'thermal_mass'
          calculations[metric][name] = get_thermal_capacitance(construction, areas[name])
        when 'ua'
          calculations[metric][name] = get_ua(construction, areas[name])
        end
      end
    end

    model.getThermalZones.each do |thermal_zone|
      name = thermal_zone.name.to_s
      vol = Geometry.get_zone_volume(thermal_zone)
      next unless vol > 0

      val = 1.004 * 1.225 # air specific heat and density
      calculations['thermal_mass'][name] = get_thermal_capacitance(nil, nil, val, UnitConversions.convert(vol, 'ft^3', 'm^3'))
    end

    if register_values
      metrics.each do |metric|
        desired_units = nil
        case metric
        when 'thermal_mass'
          desired_units = 'kj/k'
        when 'ua'
          desired_units = 'w/k'
        end
        values = calculations[metric]
        values.each do |name, val|
          next unless val > 0

          name = OpenStudio::toUnderscoreCase(name)
          report_output(runner, "#{metric}_#{name}", [OpenStudio::OptionalDouble.new(val)], desired_units, desired_units)
        end
      end
    else
      metrics.each do |metric|
        csv_path = File.expand_path("../#{metric}.csv")
        CSV.open(csv_path, 'wb') do |csv|
          values = calculations[metric]
          values.each do |name, val|
            next unless val > 0

            csv << [name, val]
          end
        end
      end
    end

    sqlFile.close()

    return true
  end

  def get_thermal_capacitance(construction, area, val = nil, vol = nil)
    if (not val.nil?) && (not vol.nil?)
      return val * vol
    else
      val = 0
      construction.layers.each do |layer|
        next unless layer.to_StandardOpaqueMaterial.is_initialized

        material = layer.to_StandardOpaqueMaterial.get
        val += material.thickness * (material.specificHeat / 1000.0) * material.density
      end
      return val * area
    end
  end

  def get_ua(construction, area)
    val = 0
    construction.layers.each do |layer|
      next unless layer.to_StandardOpaqueMaterial.is_initialized

      material = layer.to_StandardOpaqueMaterial.get
      val += material.thickness / (material.conductivity * area)
    end
    return val if val == 0

    return 1.0 / val
  end

  def get_surface_area(model, construction)
    area = 0
    model.getSurfaces.each do |surface|
      next if surface.construction.get.to_LayeredConstruction.get != construction

      area += surface.grossArea
    end
    return area
  end

  def get_sub_surface_area(model, construction)
    area = 0
    model.getSubSurfaces.each do |sub_surface|
      next if sub_surface.construction.get.to_LayeredConstruction.get != construction

      area += sub_surface.grossArea
    end
    return area
  end

  def get_internal_mass_area(model, construction)
    area = 0
    model.getInternalMassDefinitions.each do |internal_mass_def|
      next if internal_mass_def.construction.get.to_LayeredConstruction.get != construction

      surface_area = internal_mass_def.surfaceArea
      surface_area_per_space_floor_area = internal_mass_def.surfaceAreaperSpaceFloorArea
      if surface_area.is_initialized
        area += surface_area.get
      elsif surface_area_per_space_floor_area.is_initialized
        area += surface_area_per_space_floor_area.get * internal_mass_def.floorArea
      end
    end
    return area
  end

  def report_output(runner, name, vals, os_units, desired_units, percent_of_val = 1.0)
    total_val = 0.0
    vals.each do |val|
      next if val.empty?

      total_val += val.get * percent_of_val
    end
    if os_units.nil? || desired_units.nil? || (os_units == desired_units)
      valInUnits = total_val
    else
      valInUnits = OpenStudio::convert(total_val, os_units, desired_units).get
    end
    runner.registerValue(name, valInUnits)
    runner.registerInfo("Registering #{valInUnits.round(2)} for #{name}.")
  end
end

# register the measure to be used by the application
ConstructionPropertiesReport.new.registerWithApplication
