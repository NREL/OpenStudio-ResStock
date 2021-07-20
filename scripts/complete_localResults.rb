# frozen_string_literal: true

# !/usr/bin/env ruby
# CLI tool to allow for recreate the localResults directory
# This provides a critical workaround for BuildStock PAT projects
# Written by Henry R Horsey III (henry.horsey@nrel.gov)
# Created September 8th, 2017
# Last updated on September 8th, 2017
# Copywrite the Alliance for Sustainable Energy LLC
# License: BSD3+1

require 'optparse'
require 'openstudio-analysis'
require 'fileutils'
require 'zip'

# Unzip an archive to a destination directory using Rubyzip gem
#
# @param archive [:string] archive path for extraction
# @param dest [:string] path for archived file to be extracted to
def unzip_archive(archive, dest)
  # Adapted from examples at...
  # https://github.com/rubyzip/rubyzip
  # http://seenuvasan.wordpress.com/2010/09/21/unzip-files-using-ruby/
  Zip::File.open(archive) do |zf|
    zf.each do |f|
      f_path = File.join(dest, f.name)
      FileUtils.mkdir_p(File.dirname(f_path))
      zf.extract(f, f_path) unless File.exist?(f_path) # No overwrite
    end
  end
end

# Download any datapoint that is not already in the localResults directory
#
# @param local_result_dir [::String] path to the localResults directory
# @param server_api [::OpenStudio::Analysis::ServerApi] API to serve zips
# @param interval [::Fixnum] Percent interval to report progress to STDOUT
# @return [logical] Indicates if any errors were caught
def retrieve_dp_data(local_results_dir, server_api, interval = 5, analysis_id = nil, unzip = false)
  # Verify localResults directory
  unless File.basename(local_results_dir) == 'localResults'
    fail "ERROR: input #{local_results_dir} does not point to localResults"
  end

  # Ensure there are datapoints to download
  dps = server_api.get_datapoint_status analysis_id
  dps_error_count = 0
  if dps.nil? || dps.empty?
    fail 'ERROR: No datapoints found. Analysis completed with no datapoints'
  end

  # Only download datapoints which do not already exist
  exclusion_list = Dir.entries local_results_dir
  report_at = interval
  timestep = Time.now
  dps.each_with_index do |dp, count|
    next if exclusion_list.include? dp[:_id]

    # Download datapoint; in case of failure document and continue
    ok, f = server_api.download_datapoint dp[:_id], local_results_dir
    if ok
      dest = File.join local_results_dir, dp[:_id]
      if unzip
        unzip_archive f, dest
        File.delete(File.join(local_results_dir, 'data_point.zip'))
      else
        Dir.mkdir dest
        FileUtils.mv File.join(local_results_dir, 'data_point.zip'), dest
      end
    else
      puts "ERROR: Failed to download data point #{dp[:_id]}"
      dps_error_count += 1
    end

    # Report out progress
    next unless count.to_f * 100 / dps.length >= report_at

    puts "INFO: Completed #{report_at}%; #{(Time.now - timestep).round}s"
    report_at += interval
    timestep = Time.now
  end

  dps_error_count
end

# Initialize optionsParser ARGV hash
options = {}

# Define allowed ARGV input
# -s --server_dns [string]
# -p --project_dir [string]
optparse = OptionParser.new do |opts|
  opts.banner = 'Usage:    complete_localResults [-s] <server_dns> [-p] <project_dir> -a <analysis_id> [-u] [-h]'

  options[:project_dir] = nil
  opts.on('-p', '--project_dir <dir>', 'specified project DIRECTORY') do |dir|
    options[:project_dir] = dir
  end

  options[:dns] = nil
  opts.on('-s', '--server_dns <DNS>', 'specified server DNS') do |dns|
    options[:dns] = dns
  end

  options[:a_id] = nil
  opts.on('-a', '--analysis_id <ID>', 'analysis UUID') do |id|
    options[:a_id] = id
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
unless Dir.entries(options[:project_dir]).include? 'pat.json'
  fail "ERROR: pat.json file not found in #{options[:project_dir]}"
end

# Create the localResults directory should it not exist
local_results_dir = File.join(options[:project_dir], 'localResults')
unless Dir.exist? local_results_dir
  Dir.mkdir local_results_dir
end

# Get OpenStudioServerApi object and ensure the instance is running
server_api = OpenStudio::Analysis::ServerApi.new(hostname: options[:dns])
unless server_api.machine_status
  fail "ERROR: Server #{server_api.hostname} not responding to ServerApi"
end

# Retrieve the datapoints and indicate success
Zip.warn_invalid_date = false
failed_dps = retrieve_dp_data(local_results_dir, server_api, 1, options[:a_id], options[:unzip])
fail "ERROR: Retrieval failed #{failed_dps} times" if failed_dps != 0

puts 'SUCCESS: Exiting'
exit 0
