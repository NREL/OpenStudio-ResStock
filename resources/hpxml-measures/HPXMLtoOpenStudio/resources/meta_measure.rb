# frozen_string_literal: true

require 'fileutils'

def run_hpxml_workflow(rundir, measures, measures_dir, debug: false, output_vars: [],
                       output_meters: [], run_measures_only: false, print_prefix: '',
                       ep_input_format: 'idf')
  rm_path(rundir)
  FileUtils.mkdir_p(rundir)

  # Use print instead of puts in here in case running inside
  # a Parallel process (see https://stackoverflow.com/a/5044669)
  print "#{print_prefix}Creating input...\n"

  OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Fatal)
  os_log = OpenStudio::StringStreamLogSink.new
  os_log.setLogLevel(OpenStudio::Warn)

  model = OpenStudio::Model::Model.new
  runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

  # Apply measures
  success = apply_measures(measures_dir, measures, runner, model, false, 'OpenStudio::Measure::ModelMeasure')
  report_measure_errors_warnings(runner, rundir, debug)
  report_os_warnings(os_log, rundir)

  if run_measures_only
    return { success: success, runner: runner }
  end

  if not success
    print "#{print_prefix}Creating input unsuccessful.\n"
    print "#{print_prefix}See #{File.join(rundir, 'run.log')} for details.\n"
    return { success: false, runner: runner }
  end

  # Apply any additional output variables
  output_vars.each do |output_var|
    ov = OpenStudio::Model::OutputVariable.new(output_var[0], model)
    ov.setReportingFrequency(output_var[1])
    ov.setKeyValue(output_var[2])
  end

  # Apply any additional output meters
  output_meters.each do |output_meter|
    om = OpenStudio::Model::OutputMeter.new(model)
    om.setName(output_meter[0])
    om.setReportingFrequency(output_meter[1])
  end

  # Translate model to workspace
  forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
  forward_translator.setExcludeLCCObjects(true)
  workspace = forward_translator.translateModel(model)
  success = report_ft_errors_warnings(forward_translator, rundir)

  if not success
    print "#{print_prefix}Creating input unsuccessful.\n"
    print "#{print_prefix}See #{File.join(rundir, 'run.log')} for details.\n"
    return { success: false, runner: runner }
  end

  # Apply reporting measure output requests
  apply_energyplus_output_requests(measures_dir, measures, runner, model, workspace)

  # Write to file
  if ep_input_format == 'idf'
    ep_input_filename = 'in.idf'
    File.open(File.join(rundir, ep_input_filename), 'w') { |f| f << workspace.to_s }
  elsif ep_input_format == 'epjson'
    ep_input_filename = 'in.epJSON'
    json = OpenStudio::EPJSON::toJSONString(workspace.toIdfFile)
    File.open(File.join(rundir, ep_input_filename), 'w') { |f| f << json.to_s }
  else
    fail "Unexpected ep_input_format: #{ep_input_format}."
  end

  # Run simulation
  print "#{print_prefix}Running simulation...\n"
  ep_path = File.absolute_path(File.join(OpenStudio.getOpenStudioCLI.to_s, '..', '..', 'EnergyPlus', 'energyplus')) # getEnergyPlusDirectory can be unreliable, using getOpenStudioCLI instead
  simulation_start = Time.now
  command = "\"#{ep_path}\" -w \"#{model.getWeatherFile.path.get}\" #{ep_input_filename}"
  if debug
    File.open(File.join(rundir, 'run.log'), 'a') do |f|
      f << "Executing command '#{command}' from working directory '#{rundir}'.\n"
    end
  end
  pwd = Dir.pwd
  Dir.chdir(rundir) do
    system(command, out: [File.join(rundir, 'stdout-energyplus.log'), 'w'], err: [File.join(rundir, 'stderr-energyplus.log'), 'w'])
  end
  Dir.chdir(pwd) # Prevent OS "restoring original_directory" warning
  sim_time = (Time.now - simulation_start).round(1)

  # Check if simulation successful
  if File.exist? File.join(rundir, 'eplusout.err')
    sim_success = false
    File.readlines(File.join(rundir, 'eplusout.err')).map(&:strip).each do |stdout_line|
      next unless stdout_line.include? 'EnergyPlus Completed Successfully'

      sim_success = true
      break
    end
    if sim_success
      print "#{print_prefix}Completed simulation in #{sim_time}s.\n"
    else
      print "#{print_prefix}Simulation unsuccessful.\n"
      print "#{print_prefix}See #{File.join(rundir, 'eplusout.err')} for details.\n"
      return { success: false, runner: runner }
    end
  else
    print "#{print_prefix}Simulation unsuccessful.\n"
    return { success: false, runner: runner }
  end

  print "#{print_prefix}Processing output...\n"

  # Apply reporting measures
  runner.setLastEnergyPlusSqlFilePath(File.join(rundir, 'eplusout.sql'))
  success = apply_measures(measures_dir, measures, runner, model, false, 'OpenStudio::Measure::ReportingMeasure')
  report_measure_errors_warnings(runner, rundir, debug)
  report_os_warnings(os_log, rundir)
  runner.resetLastEnergyPlusSqlFilePath

  annual_csv_path = File.join(rundir, 'results_annual.csv')
  if File.exist? annual_csv_path
    print "#{print_prefix}Wrote output file: #{annual_csv_path}.\n"
  end

  timeseries_csv_path = File.join(rundir, 'results_timeseries.csv')
  if File.exist? timeseries_csv_path
    print "#{print_prefix}Wrote output file: #{timeseries_csv_path}.\n"
  end

  if not success
    print "#{print_prefix}Processing output unsuccessful.\n"
    print "#{print_prefix}See #{File.join(rundir, 'run.log')} for details.\n"
    return { success: false, runner: runner }
  else
    print "#{print_prefix}Wrote log file: #{File.join(rundir, 'run.log')}.\n"
  end

  print "#{print_prefix}Done.\n"

  return { success: true, runner: runner, sim_time: sim_time }
end

def apply_measures(measures_dir, measures, runner, model, show_measure_calls = true, measure_type = 'OpenStudio::Measure::ModelMeasure')
  # Call each measure in the specified order
  measures.keys.each do |measure_subdir|
    # Gather measure arguments and call measure
    full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
    check_file_exists(full_measure_path, runner)
    measure = get_measure_instance(full_measure_path)
    measures[measure_subdir].each do |args|
      next unless measure_type == measure.class.superclass.name.to_s

      argument_map = get_argument_map(model, measure, args, nil, measure_subdir, runner)
      if show_measure_calls
        print_measure_call(args, measure_subdir, runner)
      end

      if not run_measure(model, measure, argument_map, runner)
        return false
      end
    end
  end

  return true
end

def apply_energyplus_output_requests(measures_dir, measures, runner, model, workspace)
  # Call each measure in the specified order
  measures.keys.each do |measure_subdir|
    # Gather measure arguments and call measure
    full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
    check_file_exists(full_measure_path, runner)
    measure = get_measure_instance(full_measure_path)
    measures[measure_subdir].each do |args|
      next unless measure.class.superclass.name.to_s == 'OpenStudio::Measure::ReportingMeasure'

      argument_map = get_argument_map(model, measure, args, nil, measure_subdir, runner)
      runner.setLastOpenStudioModel(model)
      idf_objects = measure.energyPlusOutputRequests(runner, argument_map)
      idf_objects.each do |idf_object|
        workspace.addObject(idf_object)
      end
    end
  end

  return true
end

def print_measure_call(measure_args, measure_dir, runner)
  if measure_args.nil? || measure_dir.nil?
    return
  end

  args_s = hash_to_string(measure_args, delim = ' -> ', separator = " \n")
  if args_s.size > 0
    runner.registerInfo("Calling #{measure_dir} measure with arguments:\n#{args_s}")
  else
    runner.registerInfo("Calling #{measure_dir} measure with no arguments.")
  end
end

def get_measure_instance(measure_rb_path)
  # Parse XML file for class name
  # Avoid REXML for performance reasons
  measure_class = nil
  File.readlines(measure_rb_path.sub('.rb', '.xml')).each do |xml_line|
    next unless xml_line.include? '<class_name>'

    measure_class = xml_line.gsub('<class_name>', '').gsub('</class_name>', '').strip
    break
  end
  # Create new instance
  require File.absolute_path(measure_rb_path)
  measure = eval(measure_class).new
  return measure
end

def validate_measure_args(measure_args, provided_args, lookup_file, measure_name, runner = nil)
  measure_arg_names = measure_args.map { |arg| arg.name }
  lookup_file_str = ''
  if not lookup_file.nil?
    lookup_file_str = " in #{lookup_file}"
  end
  # Verify all arguments have been provided
  measure_args.each do |arg|
    next if provided_args.keys.include?(arg.name)
    next if not arg.required

    register_error("Required argument '#{arg.name}' not provided#{lookup_file_str} for measure '#{measure_name}'.", runner)
  end
  provided_args.keys.each do |k|
    next if measure_arg_names.include?(k)

    register_error("Extra argument '#{k}' specified#{lookup_file_str} for measure '#{measure_name}'.", runner)
  end
  # Check for valid argument values
  measure_args.each do |arg|
    # Get measure provided arg
    if provided_args[arg.name].nil?
      if arg.required
        register_error("Required argument '#{arg.name}' for measure '#{measure_name}' must have a value provided.", runner)
      else
        next
      end
    else
      provided_args[arg.name] = provided_args[arg.name].to_s
    end
    case arg.type.valueName.downcase
    when 'boolean'
      if not ['true', 'false'].include?(provided_args[arg.name])
        register_error("Value of '#{provided_args[arg.name]}' for argument '#{arg.name}' and measure '#{measure_name}' must be 'true' or 'false'.", runner)
      end
    when 'double'
      if not provided_args[arg.name].is_number?
        register_error("Value of '#{provided_args[arg.name]}' for argument '#{arg.name}' and measure '#{measure_name}' must be a number.", runner)
      end
    when 'integer'
      if not provided_args[arg.name].is_integer?
        register_error("Value of '#{provided_args[arg.name]}' for argument '#{arg.name}' and measure '#{measure_name}' must be an integer.", runner)
      end
    when 'string'
    # no op
    when 'choice'
      if (not arg.choiceValues.include?(provided_args[arg.name])) && (not arg.modelDependent)
        register_error("Value of '#{provided_args[arg.name]}' for argument '#{arg.name}' and measure '#{measure_name}' must be one of: #{arg.choiceValues}.", runner)
      end
    end
  end
  return provided_args
end

def get_argument_map(model, measure, provided_args, lookup_file, measure_name, runner = nil)
  measure_args = measure.arguments(model)
  provided_args = validate_measure_args(measure_args, provided_args, lookup_file, measure_name, runner)

  # Convert to argument map needed by OS
  argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(measure_args)
  measure_args.each do |arg|
    temp_arg_var = arg.clone
    if !provided_args[arg.name].nil?
      temp_arg_var.setValue(provided_args[arg.name])
    end
    argument_map[arg.name] = temp_arg_var
  end
  return argument_map
end

def get_value_from_workflow_step_value(step_value)
  variant_type = step_value.variantType
  if variant_type == 'Boolean'.to_VariantType
    return step_value.valueAsBoolean
  elsif variant_type == 'Double'.to_VariantType
    return step_value.valueAsDouble
  elsif variant_type == 'Integer'.to_VariantType
    return step_value.valueAsInteger
  elsif variant_type == 'String'.to_VariantType
    return step_value.valueAsString
  end
end

def run_measure(model, measure, argument_map, runner)
  begin
    # run the measure
    runner_child = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    if model.instance_of? OpenStudio::Workspace
      runner_child.setLastOpenStudioModel(runner.lastOpenStudioModel.get)
    end
    if measure.class.superclass.name.to_s == 'OpenStudio::Measure::ReportingMeasure'
      runner_child.setLastOpenStudioModel(model)
      runner_child.setLastEnergyPlusSqlFilePath(runner.lastEnergyPlusSqlFile.get.path)
      measure.run(runner_child, argument_map)
    else
      measure.run(model, runner_child, argument_map)
    end
    result_child = runner_child.result

    # get initial and final condition
    if result_child.initialCondition.is_initialized
      runner.registerInitialCondition(result_child.initialCondition.get.logMessage)
    end
    if result_child.finalCondition.is_initialized
      runner.registerFinalCondition(result_child.finalCondition.get.logMessage)
    end

    # re-register runner child registered values on the parent runner
    result_child.stepValues.each do |step_value|
      runner.registerValue(step_value.name, get_value_from_workflow_step_value(step_value))
    end

    # log messages
    result_child.warnings.each do |warning|
      runner.registerWarning(warning.logMessage)
    end
    result_child.info.each do |info|
      runner.registerInfo(info.logMessage)
    end
    result_child.errors.each do |error|
      runner.registerError(error.logMessage)
    end
    if result_child.errors.size > 0
      return false
    end

    # convert a return false in the measure to a return false and error here.
    if result_child.value.valueName == 'Fail'
      runner.registerError('The measure was not successful')
      return false
    end
  rescue => e
    runner.registerError("Measure Failed with Error: #{e}\n#{e.backtrace.join("\n")}")
    return false
  end
  return true
end

def hash_to_string(hash, delim = '=', separator = ',')
  hash_s = ''
  hash.each do |k, v|
    hash_s += "#{k}#{delim}#{v}#{separator}"
  end
  if hash_s.size > 0
    hash_s = hash_s.chomp(separator.to_s)
  end
  return hash_s
end

def register_error(msg, runner = nil)
  if not runner.nil?
    runner.registerError(msg)
    fail msg
  else
    raise "ERROR: #{msg}"
  end
end

def check_file_exists(full_path, runner = nil)
  if not File.exist?(full_path)
    register_error("Cannot find file #{full_path}.", runner)
  end
end

def check_dir_exists(full_path, runner = nil)
  if not Dir.exist?(full_path)
    register_error("Cannot find directory #{full_path}.", runner)
  end
end

def update_args_hash(hash, key, args, add_new = true)
  if not hash.keys.include? key
    hash[key] = [args]
  elsif add_new
    hash[key] << args
  else # merge new arguments into existing
    args.each do |k, v|
      hash[key][0][k] = v
    end
  end
end

def report_measure_errors_warnings(runner, rundir, debug)
  # Report warnings/errors
  File.open(File.join(rundir, 'run.log'), 'a') do |f|
    if debug
      runner.result.stepInfo.each do |s|
        f << "Info: #{s}\n"
      end
    end
    runner.result.stepWarnings.each do |s|
      f << "Warning: #{s}\n"
    end
    runner.result.stepErrors.each do |s|
      f << "Error: #{s}\n"
    end
  end
  runner.reset
end

def report_ft_errors_warnings(forward_translator, rundir)
  # Report warnings/errors
  success = true
  File.open(File.join(rundir, 'run.log'), 'a') do |f|
    forward_translator.warnings.each do |s|
      f << "FT Warning: #{s.logMessage}\n"
    end
    forward_translator.errors.each do |s|
      f << "FT Error: #{s.logMessage}\n"
      success = false
    end
  end
  return success
end

def report_os_warnings(os_log, rundir)
  File.open(File.join(rundir, 'run.log'), 'a') do |f|
    os_log.logMessages.each do |s|
      next if s.logMessage.include? 'Cannot find current Workflow Step'
      next if s.logMessage.include? 'Data will be treated as typical (TMY)'
      next if s.logMessage.include? 'WorkflowStepResult value called with undefined stepResult'
      next if s.logMessage.include?("Object of type 'Schedule:Constant' and named 'Always") && s.logMessage.include?('points to an object named') && s.logMessage.include?('but that object cannot be located')
      next if s.logMessage.include? 'Appears there are no design condition fields in the EPW file'

      f << "OS Message: #{s.logMessage}\n"
    end
  end
  os_log.resetStringStream
end

def rm_path(path)
  if Dir.exist?(path)
    FileUtils.rm_r(path)
  end
  while true
    break if not Dir.exist?(path)

    sleep(0.01)
  end
end

class String
  def is_number?
    true if Float(self) rescue false
  end

  def is_integer?
    if not is_number?
      return false
    end
    if Integer(Float(self)).to_f != Float(self)
      return false
    end

    return true
  end
end

def get_argument_values(runner, arguments, user_arguments)
  args = {}
  arguments.each do |argument|
    if argument.required
      case argument.type
      when 'Choice'.to_OSArgumentType
        args[argument.name] = runner.getStringArgumentValue(argument.name, user_arguments)
      when 'Boolean'.to_OSArgumentType
        args[argument.name] = runner.getBoolArgumentValue(argument.name, user_arguments)
      when 'Double'.to_OSArgumentType
        args[argument.name] = runner.getDoubleArgumentValue(argument.name, user_arguments)
      when 'Integer'.to_OSArgumentType
        args[argument.name] = runner.getIntegerArgumentValue(argument.name, user_arguments)
      when 'String'.to_OSArgumentType
        args[argument.name] = runner.getStringArgumentValue(argument.name, user_arguments)
      end
    else
      case argument.type
      when 'Choice'.to_OSArgumentType
        args[argument.name] = runner.getOptionalStringArgumentValue(argument.name, user_arguments)
      when 'Boolean'.to_OSArgumentType
        args[argument.name] = runner.getOptionalStringArgumentValue(argument.name, user_arguments)
      when 'Double'.to_OSArgumentType
        args[argument.name] = runner.getOptionalDoubleArgumentValue(argument.name, user_arguments)
      when 'Integer'.to_OSArgumentType
        args[argument.name] = runner.getOptionalIntegerArgumentValue(argument.name, user_arguments)
      when 'String'.to_OSArgumentType
        args[argument.name] = runner.getOptionalStringArgumentValue(argument.name, user_arguments)
      end
    end
  end
  return args
end
