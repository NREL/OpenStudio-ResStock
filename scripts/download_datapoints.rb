# frozen_string_literal: true

# !/usr/bin/env ruby

require 'optparse'
require 'net/http'
require 'openssl'
require 'csv'
require 'parallel'

# Download the results csv if it doesn't already exist
def retrieve_results_csv(local_results_dir, server_dns = nil, analysis_id = nil)
  # Verify localResults directory
  unless File.basename(local_results_dir) == 'localResults'
    fail "ERROR: input #{local_results_dir} does not point to localResults"
  end

  dest = nil
  Dir["#{local_results_dir}/*.csv"].each do |item|
    dest = item
  end

  return unless dest.nil?

  dest = File.join local_results_dir, 'results.csv'

  url = URI.parse("#{server_dns}/analyses/#{analysis_id}/download_data.csv?")
  http = Net::HTTP.new(url.host, url.port)
  http.read_timeout = 1000 # seconds

  params = { 'export' => 'true' }
  url.query = URI.encode_www_form(params)
  request = Net::HTTP::Get.new(url.request_uri)

  http.request request do |response|
    total = response.header['Content-Length'].to_i
    if total == 0
      fail "Did not successfully download #{dest}."
    end

    size = 0
    progress = 0
    open dest, 'wb' do |io|
      response.read_body do |chunk|
        io.write chunk
        size += chunk.size
        new_progress = (size * 100) / total
        unless new_progress == progress
          puts 'Downloading %s (%3d%%) ' % [dest, new_progress]
        end
        progress = new_progress
      end
    end
  end

  unless File.exist? dest
    fail "ERROR: Unable to download #{dest}."
  end
end

def unzip_archive(archive)
  filename = OpenStudio::toPath(archive)
  output_path = OpenStudio::toPath(archive.gsub('.zip', ''))
  unzip_file = OpenStudio::UnzipFile.new(filename)
  unzip_file.extractAllFiles(output_path)
end

def retrieve_dps(local_results_dir)
  dps = []
  Dir["#{local_results_dir}/*.csv"].each do |item|
    rows = CSV.read(item, encoding: 'ISO-8859-1')
    rows.each_with_index do |row, i|
      next if i == 0
      next unless row[4] == 'completed'

      dps << { _id: row[1] }
    end
  end
  return dps
end

# Download any datapoint that is not already in the localResults directory
def retrieve_dp_data(local_results_dir, server_dns = nil, unzip = false)
  # Verify localResults directory
  unless File.basename(local_results_dir) == 'localResults'
    fail "ERROR: input #{local_results_dir} does not point to localResults"
  end

  # Ensure there are datapoints to download
  dps = retrieve_dps(local_results_dir)
  if dps.empty?
    fail 'ERROR: No datapoints were found.'
  end

  # Only download datapoints which do not already exist
  interval = 1
  report_at = interval
  timestep = Time.now
  num_parallel = Etc.nprocessors
  Parallel.each_with_index(dps, in_threads: num_parallel) do |dp, i|
    dest = File.join local_results_dir, dp[:_id]
    dp[:file] = File.join(dest, 'data_point.zip')
    next if File.exist? dp[:file]

    url = URI.parse("#{server_dns}/data_points/#{dp[:_id]}/download_result_file?")
    http = Net::HTTP.new(url.host, url.port)

    params = { 'filename' => 'data_point.zip' }
    url.query = URI.encode_www_form(params)
    request = Net::HTTP::Get.new(url.request_uri)

    begin
      http.request request do |response|
        next unless response.kind_of? Net::HTTPSuccess

        unless File.exist? dest
          Dir.mkdir dest
        end
        open dp[:file], 'wb' do |io|
          response.read_body do |chunk|
            io.write chunk
          end
          puts "Worker #{Parallel.worker_number}, DOWNLOADED: #{dp[:file]}"
        end
        unzip_archive(dp[:file]) if unzip
      end
    rescue => error
      puts "Datapoint #{File.basename(File.dirname(dp[:file]))}, ERROR:"
      error.backtrace.each do |trace|
        puts "\t#{trace}"
      end
      next
    end

    # Report out progress
    next unless i.to_f * 100 / dps.length >= report_at

    puts "INFO: Completed #{report_at}%; #{(Time.now - timestep).round}s"
    report_at += interval
    timestep = Time.now
  end
end

# Initialize optionsParser ARGV hash
options = {}

# Define allowed ARGV input
# -p --project_dir [string]
# -s --server_dns [string]
# -a --analysis_id [string]
# -u --unzip [bool]
optparse = OptionParser.new do |opts|
  opts.banner = 'Usage:    download_datapoints [-p] <project_dir> [-s] <server_dns> [-a] <analysis_id> [-u] [-h]'

  options[:project_dir] = nil
  opts.on('-p', '--project_dir <dir>', 'specified project DIRECTORY') do |dir|
    options[:project_dir] = dir
  end

  options[:server_dns] = nil
  opts.on('-s', '--server_dns <DNS>', 'specified server DNS') do |dns|
    options[:server_dns] = dns
  end

  options[:analysis_id] = nil
  opts.on('-a', '--analysis_id <id>', 'specified analysis ID') do |id|
    options[:analysis_id] = id
  end

  options[:unzip] = false
  opts.on('-u', '--unzip', 'extract data_point.zip contents') do |zip|
    options[:unzip] = true
  end

  opts.on_tail('-h', '--help', 'display help') do
    puts opts
    exit
  end
end

# Execute ARGV parsing into options hash holding symbolized key values
optparse.parse!

# Check inputs for basic compliance criteria
unless Dir.exist?(options[:project_dir])
  fail "ERROR: Could not find #{options[:project_dir]}"
end

# Create the localResults directory should it not exist
local_results_dir = File.join(options[:project_dir], 'localResults')
unless Dir.exist? local_results_dir
  Dir.mkdir local_results_dir
end

# Retrieve the datapoints and indicate success
retrieve_results_csv(local_results_dir, options[:server_dns], options[:analysis_id])
retrieve_dp_data(local_results_dir, options[:server_dns], options[:unzip])
