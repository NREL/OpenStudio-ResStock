# frozen_string_literal: true

# !/bin/env/ruby
# Extract the results.csv file from the openstudio-server web container by hand
# This file should be run within the rails console context
# To do this, run `rails c require_relative 'results_csv'`
# This file can be provisioned onto the server through use of scp and docker cp
# This file should be located within the web container at /opt/openstudio/server/
# Writen by Henry R Horsey III
# Authored December 26th 2017
# License BSD 3+1
# Copyright the Alliance for Sustainable Energy

# Save the results.csv file to the location specified in output_file for analysis_id
require 'csv'
output_file = '/opt/openstudio/server'
analysis_id = 'abc123'

# get variables from the variables object now instead of using the "superset_of_input_variables"
analysis = Analysis.find(analysis_id)
variables, data = AnalysesController.new.send(:get_analysis_data, analysis, nil, false, { export: true })
static_fields = %w(name _id run_start_time run_end_time status status_message)

filename = "#{analysis.name}.csv"
csv_string = CSV.generate do |csv|
  csv << static_fields + variables.map { |_k, v| v['output'] ? v['name'] : v['name'] }
  data.each do |dp|
    # this is really slow right now because it is iterating over each piece of data because i can't guarentee the existence of all the values
    arr = []
    (static_fields + variables.map { |_k, v| v['output'] ? v['name'] : v['name'] }).each do |v|
      arr << if dp[v].nil?
               nil
             else
               dp[v]
             end
    end
    csv << arr
  end
end

File.open(File.join(output_file, 'results.csv'), 'wb') do |f|
  f << csv_string
end
