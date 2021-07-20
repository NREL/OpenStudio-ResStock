# frozen_string_literal: true

require 'openstudio'
require 'parallel'

require_relative '../resources/hpxml-measures/HPXMLtoOpenStudio/resources/minitest_helper'
require_relative '../resources/run_sampling'
require_relative '../resources/buildstock'

class IntegrationWorkflowTest < MiniTest::Test
  def before_setup
    @project_dir_baseline = { 'project_testing' => 1, 'project_national' => 3000 }
    @project_dir_upgrades = { 'project_testing' => 1, 'project_national' => 1 }

    @top_dir = File.absolute_path(File.join(File.dirname(__FILE__), 'test_samples_osw'))
    @lib_dir = File.join(@top_dir, '..', '..', 'lib')
    @resources_dir = File.join(@top_dir, '..', '..', 'resources')
    @outfile = File.join('..', 'lib', 'housing_characteristics', 'buildstock.csv')
  end

  def after_teardown
    FileUtils.rm_rf(@lib_dir) if File.exist?(@lib_dir)

    Dir["#{@top_dir}/workflow*.osw"].each do |osw|
      change_building_id(osw, 1)
    end
  end

  def test_baseline
    scenario_dir = File.join(@top_dir, 'baseline')
    Dir.mkdir(scenario_dir) unless File.exist?(scenario_dir)

    all_results_characteristics = []
    all_results_output = []
    @project_dir_baseline.each do |project_dir, num_samples|
      next unless num_samples > 0

      samples_osw(scenario_dir, project_dir, num_samples, all_results_characteristics, all_results_output)
    end

    results_dir = File.join(scenario_dir, 'results')
    RunOSWs._rm_path(results_dir)
    results_csv_characteristics = RunOSWs.write_summary_results(results_dir, 'results_characteristics.csv', all_results_characteristics)
    results_csv_output = RunOSWs.write_summary_results(results_dir, 'results_output.csv', all_results_output)

    [results_csv_characteristics, results_csv_output].each do |results_csv|
      rows = CSV.read(results_csv)

      cols = rows.transpose
      cols.each do |col|
        next if col[0] != 'completed_status'

        assert(col[1..-1].all? { |x| x == 'Success' })
      end
    end
  end

  def test_upgrades
    scenario_dir = File.join(@top_dir, 'upgrades')
    Dir.mkdir(scenario_dir) unless File.exist?(scenario_dir)

    all_results_characteristics = []
    all_results_output = []
    @project_dir_upgrades.each do |project_dir, num_samples|
      next unless num_samples > 0

      samples_osw(scenario_dir, project_dir, num_samples, all_results_characteristics, all_results_output)
    end

    results_dir = File.join(scenario_dir, 'results')
    RunOSWs._rm_path(results_dir)
    results_csv_characteristics = RunOSWs.write_summary_results(results_dir, 'results_characteristics.csv', all_results_characteristics)
    results_csv_output = RunOSWs.write_summary_results(results_dir, 'results_output.csv', all_results_output)

    [results_csv_characteristics, results_csv_output].each do |results_csv|
      rows = CSV.read(results_csv)

      cols = rows.transpose
      cols.each do |col|
        next if col[0] != 'completed_status'

        assert(col[1..-1].all? { |x| x != 'Fail' })
      end
    end
  end

  private

  def samples_osw(scenario_dir, project_dir, num_samples, all_results_characteristics, all_results_output)
    parent_dir = File.join(scenario_dir, project_dir)
    Dir.mkdir(parent_dir) unless File.exist?(parent_dir)

    osw_dir = File.join(parent_dir, 'osw')
    Dir.mkdir(osw_dir) unless File.exist?(osw_dir)

    xml_dir = File.join(parent_dir, 'xml')
    Dir.mkdir(xml_dir) unless File.exist?(xml_dir)

    create_lib_folder(project_dir)
    create_buildstock_csv(parent_dir, project_dir, num_samples)

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    workflow_and_building_ids = []
    buildstock_csv_data = CSV.open(File.join(@lib_dir, 'housing_characteristics/buildstock.csv'), headers: true).map(&:to_hash)
    Dir["#{@top_dir}/workflow*.osw"].each do |workflow|
      next unless workflow.include?(File.basename(scenario_dir))

      (1..num_samples).to_a.each do |building_id|
        bldg_data = get_data_for_sample(buildstock_csv_data, building_id, runner)
        next unless counties.include? bldg_data['County']

        workflow_and_building_ids << [workflow, building_id]
      end
    end

    Parallel.map(workflow_and_building_ids, in_threads: Parallel.processor_count) do |workflow, building_id|
      worker_number = Parallel.worker_number
      osw_basename = File.basename(workflow)
      puts "\nWorkflow: #{osw_basename}, Building ID: #{building_id} (#{workflow_and_building_ids.index([workflow, building_id]) + 1} / #{workflow_and_building_ids.size}), Worker Number: #{worker_number} ...\n"

      worker_folder = "run#{worker_number}"
      worker_dir = File.join(File.dirname(workflow), worker_folder)
      Dir.mkdir(worker_dir) unless File.exist?(worker_dir)
      FileUtils.cp(workflow, worker_dir)
      osw = File.join(worker_dir, File.basename(workflow))

      change_building_id(osw, building_id)

      finished_job, result_characteristics, result_output = RunOSWs.run_and_check(osw, File.join(@top_dir, worker_folder))

      osw = "#{project_dir}-#{building_id.to_s.rjust(4, '0')}.osw"
      result_characteristics['OSW'] = osw
      result_output['OSW'] = osw

      check_finished_job(result_characteristics, finished_job)
      check_finished_job(result_output, finished_job)

      all_results_characteristics << result_characteristics
      all_results_output << result_output

      # Save existing/upgraded osws and xmls
      ['existing', 'upgraded'].each do |scen|
        ['osw', 'xml'].each do |type|
          from = File.join(@top_dir, worker_folder, 'run', "#{scen}.#{type}")

          dir = osw_dir
          dir = xml_dir if type == 'xml'
          to = File.join(dir, "#{building_id}-#{osw_basename.gsub('.osw', '')}-#{scen}.#{type}")

          FileUtils.mv(from, to) if File.exist?(from)
        end
      end
    end
  end

  def create_lib_folder(project_dir)
    Dir.mkdir(@lib_dir) unless File.exist?(@lib_dir)
    FileUtils.cp_r(@resources_dir, @lib_dir)
    housing_characteristics_dir = File.join(@top_dir, '..', '..', project_dir, 'housing_characteristics')
    FileUtils.cp_r(housing_characteristics_dir, @lib_dir)
  end

  def create_buildstock_csv(parent_dir, project_dir, num_samples)
    r = RunSampling.new
    r.run(project_dir, num_samples, @outfile)
    FileUtils.cp(File.join(@lib_dir, 'housing_characteristics', 'buildstock.csv'), parent_dir)
  end

  def change_building_id(osw, building_id)
    json = JSON.parse(File.read(osw), symbolize_names: true)
    json[:steps].each do |measure|
      next if measure[:measure_dir_name] != 'BuildExistingModel'

      measure[:arguments][:building_id] = "#{building_id}"
    end
    File.open(osw, 'w') do |f|
      f.write(JSON.pretty_generate(json))
    end
  end

  def check_finished_job(result, finished_job)
    result['completed_status'] = 'Fail'
    if File.exist?(finished_job)
      result['completed_status'] = 'Success'
    end

    return result
  end

  def counties
    return [
      'AZ, Maricopa County',
      'CA, Los Angeles County',
      'GA, Fulton County',
      'IL, Cook County',
      'TX, Harris County',
      'WA, King County'
    ]
  end
end
