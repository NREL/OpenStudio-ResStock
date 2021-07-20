# frozen_string_literal: true

$VERBOSE = nil # Prevents ruby warnings, see https://github.com/NREL/OpenStudio/issues/4301

require 'openstudio'
require 'parallel'

require_relative '../../resources/hpxml-measures/HPXMLtoOpenStudio/resources/minitest_helper'
require_relative '../../resources/buildstock'

class RegressionWorkflowTest < MiniTest::Test
  def before_setup
    @top_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..'))
  end

  def test_examples_osw
    all_results_output = []

    cli_path = OpenStudio.getOpenStudioCLI
    command = "cd #{@top_dir}/.. && \"#{cli_path}\" tasks.rb update_measures"
    system(command)

    Parallel.map(Dir["#{@top_dir}/example*.osw"], in_threads: Parallel.processor_count) do |workflow|
      worker_number = Parallel.worker_number
      puts "\nOSW: #{workflow}, Worker Number: #{worker_number} ...\n"

      worker_folder = "run#{worker_number}"
      worker_dir = File.join(File.dirname(workflow), worker_folder)
      Dir.mkdir(worker_dir) unless File.exist?(worker_dir)
      FileUtils.cp(workflow, worker_dir)
      osw = File.join(worker_dir, File.basename(workflow))

      update_paths(osw)
      RunOSWs.add_simulation_output_report(osw)

      finished_job, result_characteristics, result_output = RunOSWs.run_and_check(osw, File.join(@top_dir, worker_folder))
      result_output['OSW'] = File.basename(workflow)

      if osw.include?('single_family_detached')
        result_output['build_existing_model.geometry_building_type_recs'] = 'Single-Family Detached'
      elsif osw.include?('single_family_attached')
        result_output['build_existing_model.geometry_building_type_recs'] = 'Single-Family Attached'
      elsif osw.include?('multifamily')
        result_output['build_existing_model.geometry_building_type_recs'] = 'Multi-Family with 5+ Units'
      end
      result_output['build_existing_model.county'] = 'CO, Denver County'

      all_results_output << result_output

      # Check workflow was successful
      assert(File.exist?(finished_job))
    end

    results_dir = File.join(@top_dir, 'results')
    RunOSWs._rm_path(results_dir)
    RunOSWs.write_summary_results(results_dir, 'results.csv', all_results_output)
  end

  private

  def update_paths(osw)
    json = JSON.parse(File.read(osw), symbolize_names: true)
    measures = []
    json[:steps].each do |measure|
      measures << measure[:measure_dir_name]
    end

    json[:steps].each do |step|
      next unless (step[:measure_dir_name] == 'BuildResidentialHPXML') || (step[:measure_dir_name] == 'HPXMLtoOpenStudio')

      step[:arguments][:hpxml_path] = File.join(File.dirname(osw), 'existing.xml')
      step[:arguments][:output_dir] = File.dirname(osw) if step[:measure_dir_name] == 'HPXMLtoOpenStudio'
    end

    File.open(osw, 'w') do |f|
      f.write(JSON.pretty_generate(json))
    end
  end
end
