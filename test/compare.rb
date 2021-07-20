# frozen_string_literal: true

require 'csv'

base = 'base'
feature = 'feature'
folder = 'comparisons' # comparison csv files will be exported to this folder
files = Dir[File.join(Dir.getwd, 'test/test_samples_osw/base/results*.csv')].map { |x| File.basename(x) }

dir = File.join(Dir.getwd, "test/test_samples_osw/#{folder}")
unless Dir.exist?(dir)
  Dir.mkdir(dir)
end

files.each do |file|
  results = { base => {}, feature => {} }

  # load files
  results.keys.each do |key|
    if key == base
      results[key]['file'] = "test/test_samples_osw/base/#{file}"
    elsif key == feature
      results[key]['file'] = "test/test_samples_osw/results/#{file}"
    end

    filepath = File.join(Dir.getwd, results[key]['file'])
    if File.exist?(filepath)
      results[key]['rows'] = CSV.read(filepath)
    else
      puts "Could not find #{filepath}."
    end
  end

  if (not results[base].keys.include?('rows')) || (not results[feature].keys.include?('rows'))
    next
  end

  # get columns
  results.keys.each do |key|
    results[key]['cols'] = results[key]['rows'][0][1..-1] # exclude index column
  end

  # get data
  results.keys.each do |key|
    results[key]['rows'][1..-1].each do |row|
      hpxml = row[0]
      results[key][hpxml] = {}
      row[1..-1].each_with_index do |field, i|
        col = results[key]['cols'][i]

        if field.nil?
          vals = [''] # string
        elsif field.include?(',')
          begin
            vals = field.split(',').map { |x| Float(x) } # float
          rescue ArgumentError
            vals = [field] # string
          end
        else
          begin
            vals = [Float(field)] # float
          rescue ArgumentError
            vals = [field] # string
          end
        end

        results[key][hpxml][col] = vals
      end
    end
  end

  # get hpxml union
  base_hpxmls = results[base]['rows'].transpose[0][1..-1]
  feature_hpxmls = results[feature]['rows'].transpose[0][1..-1]
  hpxmls = base_hpxmls | feature_hpxmls

  # get column union
  base_cols = results[base]['cols']
  feature_cols = results[feature]['cols']
  cols = base_cols | feature_cols

  # create comparison table
  rows = [[results[base]['rows'][0][0]] + cols] # index column + union of all other columns

  # populate the rows hash
  hpxmls.sort.each do |hpxml|
    row = [hpxml]
    cols.each_with_index do |col, i|
      if results[base].keys.include?(hpxml) && (not results[feature].keys.include?(hpxml)) # feature removed an xml
        m = 'N/A'
      elsif (not results[base].keys.include?(hpxml)) && results[feature].keys.include?(hpxml) # feature added an xml
        m = 'N/A'
      elsif results[base][hpxml].keys.include?(col) && (not results[feature][hpxml].keys.include?(col)) # feature removed a column
        m = 'N/A'
      elsif (not results[base][hpxml].keys.include?(col)) && results[feature][hpxml].keys.include?(col) # feature added a column
        m = 'N/A'
      else
        base_field = results[base][hpxml][col]
        feature_field = results[feature][hpxml][col]

        begin
          # float comparisons
          m = []
          base_field.zip(feature_field).each do |b, f|
            m << (f - b).round(1)
          end
        rescue *[NoMethodError, TypeError]
          # string comparisons
          m = []
          base_field.zip(feature_field).each do |b, f|
            if b != f
              m << 1
            else
              m << 0
            end
          end
        end
        m = m.reduce(:+)
      end

      row << m
    end

    rows << row
  end

  # export comparison table
  CSV.open(File.join(dir, file), 'wb') do |csv|
    rows.each do |row|
      csv << row
    end
  end
end
