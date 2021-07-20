# frozen_string_literal: true

require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require_relative '../../test/minitest_helper'
require_relative '../../resources/buildstock'
require 'minitest/autorun'
require 'parallel'

class WorkflowTest < MiniTest::Test
  def test_examples_osw
    all_results_output = []
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..'))

    create_lib_folder(parent_dir)

    Parallel.map(Dir["#{parent_dir}/example*.osw"], in_threads: Parallel.processor_count) do |workflow|
      worker_number = Parallel.worker_number
      puts "\nOSW: #{workflow}, Worker Number: #{worker_number} ...\n"

      worker_folder = "run#{worker_number}"
      worker_dir = File.join(File.dirname(workflow), worker_folder)
      Dir.mkdir(worker_dir) unless File.exist?(worker_dir)
      FileUtils.cp(workflow, worker_dir)
      osw = File.join(worker_dir, File.basename(workflow))

      RunOSWs.add_simulation_output_report(osw)

      out_osw, result_characteristics, result_output = RunOSWs.run_and_check(osw, File.join(parent_dir, worker_folder))
      result_output['OSW'] = File.basename(workflow)
      all_results_output << result_output

      # Check workflow was successful
      assert(File.exist?(out_osw))
      data_hash = JSON.parse(File.read(out_osw))
      assert_equal(data_hash['completed_status'], 'Success')
    end

    results_dir = File.join(parent_dir, 'results')
    RunOSWs._rm_path(results_dir)
    RunOSWs.write_summary_results(results_dir, 'results.csv', all_results_output)
  end

  private

  def create_lib_folder(parent_dir)
    lib_dir = File.join(parent_dir, '../lib') # at top level
    resources_dir = File.join(parent_dir, '../resources')
    Dir.mkdir(lib_dir) unless File.exist?(lib_dir)
    FileUtils.cp_r(resources_dir, lib_dir)
  end
end
