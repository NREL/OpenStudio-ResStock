# frozen_string_literal: true

called_from_cli = true
begin
  OpenStudio.getOpenStudioCLI
rescue
  called_from_cli = false
end

if not called_from_cli
  require 'simplecov'

  if not ENV['CI']
    SimpleCov.coverage_dir('coverage')
  end
  SimpleCov.start

  require 'minitest/autorun'
  require 'minitest/reporters'

  Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new # spec-like progress
end

# Helper methods below for unit tests

def get_model(measure_dir, osm_file_or_model)
  if osm_file_or_model.is_a?(OpenStudio::Model::Model)
    # nothing to do
    model = osm_file_or_model
  elsif osm_file_or_model.nil?
    # make an empty model
    model = OpenStudio::Model::Model.new
  else
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    osm_path = File.join(measure_dir, '..', '..', '..', 'test', 'osm_files', osm_file_or_model)
    unless File.exist? osm_path
      osm_path = File.join(measure_dir, '..', '..', '..', '..', 'test', 'osm_files', osm_file_or_model)
    end
    path = OpenStudio::Path.new(osm_path)
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
  end
  return model
end

def get_objects(model)
  # Returns a list with [ObjectTypeString, ModelObject] items
  objects = []
  model.modelObjects.each do |obj|
    obj_type = get_model_object_type(obj)
    if ['AdditionalProperties', 'YearDescription', 'WaterHeaterSizing'].include? obj_type
      next # Remove this eventually?
    end

    objects << [obj_type, obj]
  end
  return objects
end

def get_object_additions(list1, list2, obj_type_exclusions = nil, obj_name_exclusions = nil)
  # Identifies all objects in list2 that aren't in list1.
  # Returns a hash with key=ObjectTypeString, value=[ModelObjects]
  additions = {}
  list2.each do |obj_type2, obj2|
    next if list1.include?([obj_type2, obj2])
    next if (not obj_type_exclusions.nil?) && obj_type_exclusions.include?(obj_type2)
    next if (not obj_name_exclusions.nil?) && obj_name_exclusions.include?(obj2.name.to_s)

    if not additions.keys.include?(obj_type2)
      additions[obj_type2] = []
    end
    additions[obj_type2] << obj2
  end
  return additions
end

def get_model_object_type(model_object)
  # Hacky; is there a better way to get this?
  obj_type = model_object.to_s.split(',')[0].gsub('OS:', '').gsub(':', '')
  if obj_type == 'MaterialNoMass'
    obj_type = 'Material'
  elsif obj_type == 'WindowMaterialSimpleGlazingSystem'
    obj_type = 'SimpleGlazing'
  elsif obj_type == 'SizingPeriodDesignDay'
    obj_type = 'DesignDay'
  end
  return obj_type
end

def check_num_objects(objects, expected_num_objects, mode)
  # Checks for the exact number of objects as defined in expected_num_objects
  list_of_expected_vs_actual = []
  objects.each do |obj_type, new_objects|
    next if not new_objects[0].respond_to?("to_#{obj_type}")

    if expected_num_objects.include?(obj_type)
      list_of_expected_vs_actual << [obj_type, expected_num_objects[obj_type], new_objects.size] if new_objects.size != expected_num_objects[obj_type]
    else
      list_of_expected_vs_actual << [obj_type, 0, new_objects.size] if new_objects.size != 0
    end
  end
  expected_num_objects.each do |obj_type, num_objects|
    next if objects.keys.include?(obj_type)

    list_of_expected_vs_actual << [obj_type, num_objects, 0] if num_objects.size != 0
  end
  list_of_expected_vs_actual.each do |obj_type, expected, actual|
    puts "Incorrect number of #{obj_type} objects #{mode}. Expected: #{expected}. Actual: #{actual}"
  end
  unless list_of_expected_vs_actual.empty?
    assert_equal(list_of_expected_vs_actual[0][1], list_of_expected_vs_actual[0][2])
  end
end

def check_ems(model)
  # check that all set variables are used somewhere (i.e., no typos)
  (model.getEnergyManagementSystemPrograms + model.getEnergyManagementSystemSubroutines).each do |ems|
    ems.to_s.each_line do |line|
      next unless line.downcase.strip.start_with?('set ')

      var = line.split('=')[0].strip.split(' ')[1]
      count = 0
      (model.getEnergyManagementSystemSensors + model.getEnergyManagementSystemActuators + model.getEnergyManagementSystemPrograms + model.getEnergyManagementSystemOutputVariables + model.getEnergyManagementSystemSubroutines + model.getEnergyManagementSystemGlobalVariables).each do |ems|
        count += ems.to_s.scan(/(?=#{var})/).count
      end
      if count <= 1
        puts "Unused EMS variable: #{var}"
      end
      assert(count > 1)
    end
  end

  # check that no lines exceed 100 characters
  model.to_s.each_line do |line|
    next unless line.strip.start_with?('Set', 'If', 'Else', 'EndIf')

    if line.include? '!-' # Remove comments
      line.slice!(line.index('!-')..line.length)
      line.gsub!(',', '')
    end
    line.strip!
    if line.length > 100
      puts "Line exceeds 100 characters: #{line} (#{line.length})"
    end
    assert(line.length <= 100)
  end
end

def check_hvac_priorities(model, priority_list)
  # check that any equipment in the list are in the correct order
  model.getThermalZones.each do |thermal_zone|
    heating_order = []
    cooling_order = []
    thermal_zone.equipmentInHeatingOrder.each do |equip|
      priority_list.each do |item|
        next unless equip.respond_to?("to_#{item}")
        next unless equip.public_send("to_#{item}").is_initialized

        heating_order << priority_list.index(item)
      end
    end
    thermal_zone.equipmentInCoolingOrder.each do |equip|
      priority_list.each do |item|
        next unless equip.respond_to?("to_#{item}")
        next unless equip.public_send("to_#{item}").is_initialized

        cooling_order << priority_list.index(item)
      end
    end
    assert_equal(heating_order.sort, heating_order)
    assert_equal(cooling_order.sort, cooling_order)
  end
end
