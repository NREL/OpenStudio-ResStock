# frozen_string_literal: true

$VERBOSE = nil # Prevents ruby warnings, see https://github.com/NREL/OpenStudio/issues/4301

def generate_example_osws(data_hash, include_args, osw_filename, simplify = true)
  # This function will generate OpenStudio OSWs
  # with all the measures in it, in the order specified in /resources/measure-info.json

  require 'openstudio'
  require_relative 'resources/meta_measure'

  puts "Updating #{osw_filename}..."

  model = OpenStudio::Model::Model.new
  osw_path = "workflows/#{osw_filename}"

  if File.exist?(osw_path)
    File.delete(osw_path)
  end

  workflowJSON = OpenStudio::WorkflowJSON.new
  workflowJSON.setOswPath(osw_path)
  workflowJSON.addMeasurePath('../../measures')
  workflowJSON.addMeasurePath('../../resources/hpxml-measures')

  steps = OpenStudio::WorkflowStepVector.new

  # Check for invalid measure names
  all_measures = []
  data_hash.each do |group|
    group['group_steps'].each do |group_step|
      group_step['measures'].each do |measure|
        all_measures << measure
      end
    end
  end

  data_hash.each do |group|
    group['group_steps'].each do |group_step|
      # Default to first measure in step
      measure = group_step['measures'][0]
      if !['ResStockArguments'].include?(measure)
        measure_path = File.expand_path(File.join('../resources/hpxml-measures', measure), workflowJSON.oswDir.to_s)
      else
        measure_path = File.expand_path(File.join('../measures', measure), workflowJSON.oswDir.to_s)
      end
      measure_instance = get_measure_instance("#{measure_path}/measure.rb")
      measure_args = measure_instance.arguments(model).sort_by { |arg| arg.name }

      step = OpenStudio::MeasureStep.new(measure)
      if not simplify
        step.setName(measure_instance.name)
        step.setDescription(measure_instance.description)
        step.setModelerDescription(measure_instance.modeler_description)
      end

      # Loop on each argument
      measure_args.each do |arg|
        if arg.hasDefaultValue
          arg_value = arg.defaultValueAsString
          step.setArgument(arg.name, arg_value)
        elsif arg.required
          puts "No default value provided for #{measure} argument '#{arg.name}'."
        end
      end

      if include_args.keys.include? measure
        include_args[measure].each do |arg_name, arg_value|
          step.setArgument(arg_name, arg_value)
        end
      end

      # Push step in Steps
      steps.push(step)
    end
  end

  run_options = OpenStudio::RunOptions.new
  run_options.setFast(true)
  run_options.setSkipExpandObjects(true)
  run_options.setSkipEnergyPlusPreprocess(true)

  workflowJSON.setWorkflowSteps(steps)
  workflowJSON.setRunOptions(run_options)
  workflowJSON.save

  # Strip created_at/updated_at
  require 'json'
  file = File.read(osw_path)
  data_hash = JSON.parse(file)
  data_hash.delete('created_at')
  data_hash.delete('updated_at')
  File.write(osw_path, JSON.pretty_generate(data_hash))
end

def get_and_proof_measure_order_json()
  # This function will check that all measure folders (in measures/)
  # are listed in the /resources/measure-info.json and vice versa
  # and return the list of all measures used in the proper order
  #
  # @return {data_hash} of measure-info.json

  # List all measures in measures/ folders
  model_measure_folder = File.expand_path('../resources/hpxml-measures/', __FILE__)
  resstock_measure_folder = File.expand_path('../measures/', __FILE__)
  all_measures = Dir.entries(model_measure_folder).select { |entry| entry.include?('HPXML') } + Dir.entries(resstock_measure_folder).select { |entry| entry.start_with?('Residential') }

  # Load json, and get all measures in there
  json_file = 'resources/measure-info.json'
  json_path = File.expand_path("../#{json_file}", __FILE__)
  data_hash = JSON.parse(File.read(json_path))

  measures_json = []
  data_hash.each do |group|
    group['group_steps'].each do |group_step|
      measures_json += group_step['measures']
    end
  end

  # Check for missing in JSON file
  missing_in_json = all_measures - measures_json
  if missing_in_json.size > 0
    puts "Warning: There are #{missing_in_json.size} measures missing in '#{json_file}': #{missing_in_json.join(',')}"
  end

  # Check for measures in JSON that don't have a corresponding folder
  extra_in_json = measures_json - all_measures
  if extra_in_json.size > 0
    puts "Warning: There are #{extra_in_json.size} measures extra in '#{json_file}': #{extra_in_json.join(',')}"
  end

  return data_hash
end

def download_epws
  require_relative 'resources/hpxml-measures/HPXMLtoOpenStudio/resources/util'

  require 'tempfile'
  tmpfile = Tempfile.new('epw')

  UrlResolver.fetch('https://data.nrel.gov/system/files/156/BuildStock_TMY3_FIPS.zip', tmpfile)

  puts 'Extracting weather files...'
  weather_dir = File.join(File.dirname(__FILE__), 'weather')
  unzip_file = OpenStudio::UnzipFile.new(tmpfile.path.to_s)
  unzip_file.extractAllFiles(OpenStudio::toPath(weather_dir))

  num_epws_actual = Dir[File.join(weather_dir, '*.epw')].count
  puts "#{num_epws_actual} weather files are available in the weather directory."
  puts 'Completed.'
  exit!
end

command_list = [:update_measures, :integrity_check_national, :integrity_check_testing, :download_weather]

def display_usage(command_list)
  puts "Usage: openstudio #{File.basename(__FILE__)} [COMMAND]\nCommands:\n  " + command_list.join("\n  ")
end

if ARGV.size == 0
  puts 'ERROR: Missing command.'
  display_usage(command_list)
  exit!
elsif ARGV.size > 1
  puts 'ERROR: Too many commands.'
  display_usage(command_list)
  exit!
elsif not command_list.include? ARGV[0].to_sym
  puts "ERROR: Invalid command '#{ARGV[0]}'."
  display_usage(command_list)
  exit!
end

if ARGV[0].to_sym == :update_measures
  require 'openstudio'
  require 'json'
  require_relative 'resources/hpxml-measures/HPXMLtoOpenStudio/resources/hpxml'

  # Prevent NREL error regarding U: drive when not VPNed in
  ENV['HOME'] = 'C:' if !ENV['HOME'].nil? && ENV['HOME'].start_with?('U:')
  ENV['HOMEDRIVE'] = 'C:\\' if !ENV['HOMEDRIVE'].nil? && ENV['HOMEDRIVE'].start_with?('U:')

  # Apply rubocop
  cops = ['Layout',
          'Lint/DeprecatedClassMethods',
          'Lint/RedundantStringCoercion',
          'Style/AndOr',
          'Style/FrozenStringLiteralComment',
          'Style/HashSyntax',
          'Style/Next',
          'Style/NilComparison',
          'Style/RedundantParentheses',
          'Style/RedundantSelf',
          'Style/ReturnNil',
          'Style/SelfAssignment',
          'Style/StringLiterals',
          'Style/StringLiteralsInInterpolation']
  commands = ["\"require 'rubocop/rake_task'\"",
              "\"RuboCop::RakeTask.new(:rubocop) do |t| t.options = ['--auto-correct', '--format', 'simple', '--only', '#{cops.join(',')}'] end\"",
              '"Rake.application[:rubocop].invoke"']
  command = "#{OpenStudio.getOpenStudioCLI} -e #{commands.join(' -e ')}"
  puts 'Applying rubocop auto-correct to measures...'
  system(command)

  # Update measures XMLs
  command = "#{OpenStudio.getOpenStudioCLI} measure -t '#{File.join(File.dirname(__FILE__), 'measures')}'"
  puts 'Updating measure.xmls...'
  system(command, [:out, :err] => File::NULL)

  # Generate example OSWs

  # Check that there is no missing/extra measures in the measure-info.json
  # and get all_measures name (folders) in the correct order
  data_hash = get_and_proof_measure_order_json()

  example_osws = {
    'TMY' => {
      'weather_station_epw_filepath' => File.expand_path(File.join(File.dirname(__FILE__), 'weather/USA_CO_Denver.Intl.AP.725650_TMY3.epw'))
    },
    'AMY2012' => {
      'weather_station_epw_filepath' => File.expand_path(File.join(File.dirname(__FILE__), 'weather/0465925_US_CO_Boulder_8013_0-20000-0-72469_40.13_-105.22_NSRDB_2.0.1_AMY_2012.epw'))
    },
    'AMY2014' => {
      'weather_station_epw_filepath' => File.expand_path(File.join(File.dirname(__FILE__), 'weather/0465925_US_CO_Boulder_8013_0-20000-0-72469_40.13_-105.22_NSRDB_2.0.1_AMY_2014.epw'))
    }
  }
  example_osws.each do |weather_year, weather_station|
    include_args = {
      'BuildResidentialHPXML' => {
        'hpxml_path' => File.expand_path(File.join(File.dirname(__FILE__), 'workflows/run/existing.xml')),
        'schedules_type' => 'stochastic'
      },
      'HPXMLtoOpenStudio' => {
        'hpxml_path' => File.expand_path(File.join(File.dirname(__FILE__), 'workflows/run/existing.xml')),
        'output_dir' => File.expand_path(File.join(File.dirname(__FILE__), 'workflows/run'))
      }
    }

    # SFD
    include_args['BuildResidentialHPXML']['geometry_unit_type'] = HPXML::ResidentialTypeSFD
    include_args['BuildResidentialHPXML']['geometry_cfa'] = '2000'
    include_args['BuildResidentialHPXML'].update(weather_station)
    generate_example_osws(data_hash,
                          include_args,
                          "example_single_family_detached_#{weather_year}.osw")

    # SFA
    include_args['BuildResidentialHPXML']['geometry_unit_type'] = HPXML::ResidentialTypeSFA
    include_args['BuildResidentialHPXML']['geometry_cfa'] = '900'
    include_args['BuildResidentialHPXML']['geometry_horizontal_location'] = 'Left'
    include_args['BuildResidentialHPXML']['geometry_building_num_units'] = '2'
    include_args['BuildResidentialHPXML'].update(weather_station)
    generate_example_osws(data_hash,
                          include_args,
                          "example_single_family_attached_#{weather_year}.osw")

    # MF
    include_args['BuildResidentialHPXML']['geometry_unit_type'] = HPXML::ResidentialTypeApartment
    include_args['BuildResidentialHPXML']['geometry_cfa'] = '900'
    include_args['BuildResidentialHPXML']['geometry_level'] = 'Bottom'
    include_args['BuildResidentialHPXML']['geometry_horizontal_location'] = 'Left'
    include_args['BuildResidentialHPXML']['geometry_building_num_units'] = '2'
    include_args['BuildResidentialHPXML'].update(weather_station)
    generate_example_osws(data_hash,
                          include_args,
                          "example_multifamily_#{weather_year}.osw")
  end

  puts 'Done.'
end

if ARGV[0].to_sym == :integrity_check_national
  require_relative 'test/integrity_checks'

  project_dir_name = 'project_national'
  integrity_check(project_dir_name)
  integrity_check_options_lookup_tsv(project_dir_name)
end

if ARGV[0].to_sym == :integrity_check_testing
  require_relative 'test/integrity_checks'

  project_dir_name = 'project_testing'
  integrity_check(project_dir_name)
  integrity_check_options_lookup_tsv(project_dir_name)
end

if ARGV[0].to_sym == :download_weather
  download_epws
end
