# frozen_string_literal: true

require 'json'

module OsLib_ReportingHeatGainLoss
  # setup - get model, sql, and setup web assets path
  def self.setup(runner)
    results = {}

    # get the last model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    # get the last idf
    workspace = runner.lastEnergyPlusWorkspace
    if workspace.empty?
      runner.registerError('Cannot find last idf file.')
      return false
    end
    workspace = workspace.get

    # get the last sql file
    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)

    # populate hash to pass to measure
    results[:model] = model
    # results[:workspace] = workspace
    results[:sqlFile] = sqlFile
    results[:web_asset_path] = OpenStudio.getSharedResourcesPath / OpenStudio::Path.new('web_assets')

    return results
  end

  def self.ann_env_pd(sqlFile)
    # get the weather file run period (as opposed to design day run period)
    ann_env_pd = nil
    sqlFile.availableEnvPeriods.each do |env_pd|
      env_type = sqlFile.environmentType(env_pd)
      next unless env_type.is_initialized

      if env_type.get == OpenStudio::EnvironmentType.new('WeatherRunPeriod')
        ann_env_pd = env_pd
      end
    end

    return ann_env_pd
  end

  # clean up unkown strings used for runner.registerValue names
  def self.reg_val_string_prep(string)
    # replace non alpha-numberic characters with an underscore
    string = string.gsub(/[^0-9a-z]/i, '_')

    # snake case string
    string = OpenStudio.toUnderscoreCase(string)

    return string
  end

  # section for heat_gains
  def self.heat_gains_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    tables = []

    # gather data for section
    @heat_gains = {}
    @heat_gains[:title] = 'Heat Gains By Month Detailed'
    @heat_gains[:tables] = tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @heat_gains
    end

    # using helper method that generates table for second example
    tables << @elec_equip_gain_table = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner, 'Electric Equipment Total Heating Energy', 'J', 'kBtu')
    tables << @gas_equip_gain_table = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner, 'Gas Equipment Total Heating Energy', 'J', 'kBtu')
    tables << @lights_gain_table = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner, 'Zone Lights Total Heating Energy', 'J', 'kBtu')
    tables << @people_gain_table = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner, 'Zone People Sensible Heating Energy', 'J', 'kBtu')
    tables << @vent_clg_increase_gain_table = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner, 'Zone Mechanical Ventilation Cooling Load Increase Energy', 'J', 'kBtu')
    tables << @vent_htg_decrease_gain_table = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner, 'Zone Mechanical Ventilation Heating Load Decrease Energy', 'J', 'kBtu')

=begin
    # use multiple variables for ventilation
    temp_vent_gain_ht = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner,'Zone Mechanical Ventilation Cooling Load Increase Energy','J','kBtu')
    temp_vent_no_load_gain = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner,'Zone Mechanical Ventilation No Load Heat Addition Energy','J','kBtu')
    temp_vent_gain_clg_over_ht = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner,'Zone Mechanical Ventilation Cooling Load Increase Due to Overheating Energy','J','kBtu')
    temp_vent_gain_ht_decr = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner,'Zone Mechanical Ventilation Heating Load Decrease Energy','J','kBtu')
    temp_heat_exch_clg = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner,'Air System Heat Exchanger Total Cooling Energy','J','kBtu')
    temp_vent_gain_ht[:title] = 'Mechanical Ventilation Heat Gain (kBtu)'
    temp_vent_gain_ht[:data].each_with_index do |row,i|
      row.each_with_index do |column,j|
        next if j == 0
        value = column.gsub(",","").to_f + temp_vent_gain_ht_decr[:data][i][j].gsub(",","").to_f + temp_vent_no_load_gain[:data][i][j].gsub(",","").to_f + temp_vent_gain_clg_over_ht[:data][i][j].gsub(",","").to_f
        temp_vent_gain_ht[:data][i][j] = OpenStudio::toNeatString(value,1,true)
      end
    end

    # deduct for heat exchangers
    temp_heat_exch_clg[:data].each_with_index do |row,i|
      new_row = []
      row.each_with_index do |column,j|
        if j == 0
          new_row <<  "Air System Heat Exchanger Total Cooling Energy - #{column}"
        else
          value = column.gsub(",","").to_f * -1.0
          if i + 1.0 == temp_heat_exch_clg[:data].size
            # update monthly total for column
            orig_value = temp_vent_gain_ht[:data].last[j].gsub(",","").to_f
            new_value = orig_value + value
            temp_vent_gain_ht[:data].last[j] =  OpenStudio::toNeatString(new_value,1,true)
          else
            new_row << OpenStudio::toNeatString(value,1,true)
          end
        end
      end
      # add new row before monthly totals adjusted for heat exchangers
      if new_row.size > 1
        temp_vent_gain_ht[:data].insert(temp_vent_gain_ht[:data].size - 1, new_row)
      end
    end
    tables << @ventilation_gain_table = temp_vent_gain_ht
=end

    tables << @infiltration_gain_table = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner, 'Zone Infiltration Sensible Heat Gain Energy', 'J', 'kBtu')
    tables << @window_gain_table = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner, 'Surface Window Heat Gain Energy', 'J', 'kBtu')
    tables << @surface_gain_table = OsLib_ReportingHeatGainLoss.monthly_surface_heat_gains_table(model, sqlFile, runner)

    return @heat_gains
  end

  # create heat_gains_summary_section
  def self.heat_gains_summary_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    summary_tables = []

    # gather data for section
    @template_section = {}
    @template_section[:title] = 'Heat Gains Summary'
    @template_section[:tables] = summary_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @template_section
    end

    # gather data from previous section
    source_tables = []
    source_tables << @elec_equip_gain_table
    source_tables << @gas_equip_gain_table
    source_tables << @lights_gain_table
    source_tables << @people_gain_table
    source_tables << @infiltration_gain_table
    source_tables << @vent_clg_increase_gain_table
    source_tables << @vent_htg_decrease_gain_table
    source_tables << @window_gain_table
    source_tables << @surface_gain_table

    # component order and color
    component_color = {}
    component_color['Zone Lights Total Heating Energy'] = '#F7DF10'
    component_color['Electric Equipment Total Heating Energy'] = '#4A4D4A'
    component_color['Gas Equipment Total Heating Energy'] = '#D6D6D6'
    component_color['Zone People Sensible Heating Energy'] = '#FFC0CB '
    component_color['Zone Infiltration Sensible Heat Gain Energy'] = '#5B9C31'
    component_color['Zone Mechanical Ventilation Cooling Load Increase Energy'] = '#E88412'
    component_color['Zone Mechanical Ventilation Heating Load Decrease Energy'] = '#E82F12'
    component_color['Ground Exposed Surfaces Heat Gain'] = '#7D8080'
    component_color['Exterior Wall Surfaces Heat Gain'] = '#CCB266' # was Surface Average Face Conduction Heat Gain
    component_color['Surface Window Heat Gain Energy'] = '#66B2CC'
    component_color['Roof Surfaces Heat Gain'] = '#994C4C'

    # create annual table
    summary_table_01 = {}
    summary_table_01[:title] = 'Heat Gains Annual Breakdown (kBtu)'
    summary_table_01[:header] = ['Type', 'Quantity']
    summary_table_01[:units] = ['', 'kBtu']
    summary_table_01[:data] = []

    # create annual chart
    summary_table_01[:chart_type] = 'simple_pie'
    summary_table_01[:chart] = []

    # loop through tables to get annual information
    source_tables.each do |table|
      title = table[:title].gsub(' (kBtu)', '')

      # use subtotal rows for surfaces, total row for everything else
      if title == 'Surface Average Face Conduction Heat Gain'

        # exterior walls subtotal
        display_value = table[:data][table[:data].size - 4].last
        sub_total_title = 'Exterior Wall Surfaces Heat Gain'
        summary_table_01[:data] << [sub_total_title, display_value]
        summary_table_01[:chart] << JSON.generate(label: sub_total_title, value: display_value.to_s.gsub(',', '').to_f, color: component_color[sub_total_title])

        # exterior roofs subtotal
        display_value = table[:data][table[:data].size - 3].last
        sub_total_title = 'Roof Surfaces Heat Gain'
        summary_table_01[:data] << [sub_total_title, display_value]
        summary_table_01[:chart] << JSON.generate(label: sub_total_title, value: display_value.to_s.gsub(',', '').to_f, color: component_color[sub_total_title])

        # ground subtotal
        display_value = table[:data][table[:data].size - 2].last
        sub_total_title = 'Ground Exposed Surfaces Heat Gain'
        summary_table_01[:data] << [sub_total_title, display_value]
        summary_table_01[:chart] << JSON.generate(label: sub_total_title, value: display_value.to_s.gsub(',', '').to_f, color: component_color[sub_total_title])
      else
        display_value = table[:data].last.last
        summary_table_01[:data] << [title, display_value]
        summary_table_01[:chart] << JSON.generate(label: title, value: display_value.to_s.gsub(',', '').to_f, color: component_color[title])
      end
    end

    # add table to array of tables
    summary_tables << summary_table_01

    # create monthly table
    summary_table_02 = {}
    summary_table_02[:title] = 'Heat Gains Monthly Breakdown (kBtu)'
    summary_table_02[:header] = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    summary_table_02[:units] = []
    summary_table_02[:data] = []

    # create monthly chart
    month_order = %w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
    summary_table_02[:chart_type] = 'vertical_stacked_bar'
    summary_table_02[:chart_attributes] = { value: summary_table_02[:title], label_x: 'Month', sort_yaxis: component_color.keys, sort_xaxis: month_order }
    summary_table_02[:chart] = []

    # loop through tables to get annual information
    source_tables.each do |table|
      title = table[:title].gsub(' (kBtu)', '')
      if title == 'Surface Average Face Conduction Heat Gain'

        # exterior walls subtotal
        row_data = []
        sub_title = 'Exterior Wall Surfaces Heat Gain'
        target_row = table[:data][table[:data].size - 4]
        row_data << sub_title
        target_row.each_with_index do |value, i|
          ''
          next if i < 3
          next if i == target_row.size - 1 # don't want to include annual total

          row_data << value
          # update chart
          month = summary_table_02[:header][i - 2] # shifted over because of extra columns
          clean_value = value.to_s.gsub(',', '').to_f
          summary_table_02[:chart] << JSON.generate(label: sub_title, label_x: month, value: clean_value, color: component_color[sub_title])
        end
        summary_table_02[:data] << row_data

        # exterior roofs subtotal
        row_data = []
        sub_title = 'Roof Surfaces Heat Gain'
        target_row = table[:data][table[:data].size - 3]
        row_data << sub_title
        target_row.each_with_index do |value, i|
          next if i < 3
          next if i == target_row.size - 1 # don't want to include annual total

          row_data << value
          # update chart
          month = summary_table_02[:header][i - 2] # shifted over because of extra columns
          clean_value = value.to_s.gsub(',', '').to_f
          summary_table_02[:chart] << JSON.generate(label: sub_title, label_x: month, value: clean_value, color: component_color[sub_title])
        end
        summary_table_02[:data] << row_data

        # ground subtotal
        row_data = []
        sub_title = 'Ground Exposed Surfaces Heat Gain'
        target_row = table[:data][table[:data].size - 2]
        row_data << sub_title
        target_row.each_with_index do |value, i|
          next if i < 3
          next if i == target_row.size - 1 # don't want to include annual total

          row_data << value
          # update chart
          month = summary_table_02[:header][i - 2] # shifted over because of extra columns
          clean_value = value.to_s.gsub(',', '').to_f
          summary_table_02[:chart] << JSON.generate(label: sub_title, label_x: month, value: clean_value, color: component_color[sub_title])
        end
        summary_table_02[:data] << row_data

      else

        row_data = []
        last_row = table[:data].last
        row_data << title
        last_row.each_with_index do |value, i|
          next if value == 'Monthly Totals'
          next if value == ''
          next if i == last_row.size - 1 # don't want to include annual total

          row_data << value

          # update chart
          month = summary_table_02[:header][i]
          clean_value = value.to_s.gsub(',', '').to_f
          summary_table_02[:chart] << JSON.generate(label: title, label_x: month, value: clean_value, color: component_color[title])
        end
        summary_table_02[:data] << row_data

      end
    end

    # add table to array of tables
    summary_tables << summary_table_02

    return @template_section
  end

  # section for heat_losses
  def self.heat_losses_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    tables = []

    # gather data for section
    @heat_losses = {}
    @heat_losses[:title] = 'Heat Losses By Month Detailed'
    @heat_losses[:tables] = tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @heat_losses
    end

=begin
    # using helper method that generates table for second example
    # use multiple variables for ventilation
    temp_vent_loss_ht = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner,'Zone Mechanical Ventilation Heating Load Increase Energy','J','kBtu')
    temp_vent_no_load_loss = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner,'Zone Mechanical Ventilation No Load Heat Removal Energy','J','kBtu')
    temp_vent_loss_ht_over_clg = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner,'Zone Mechanical Ventilation Heating Load Increase Due to Overcooling Energy','J','kBtu')
    temp_vent_loss_clg_decr = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner,'Zone Mechanical Ventilation Cooling Load Decrease Energy','J','kBtu')
    temp_heat_exch_htg = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner,'Air System Heat Exchanger Total Heating Energy','J','kBtu')
    temp_vent_loss_ht[:title] = 'Mechanical Ventilation Heat Loss (kBtu)'
    temp_vent_loss_ht[:data].each_with_index do |row,i|
      row.each_with_index do |column,j|
        next if j == 0
        value = column.gsub(",","").to_f + temp_vent_loss_clg_decr[:data][i][j].gsub(",","").to_f + temp_vent_no_load_loss[:data][i][j].gsub(",","").to_f + temp_vent_loss_ht_over_clg[:data][i][j].gsub(",","").to_f
        temp_vent_loss_ht[:data][i][j] = OpenStudio::toNeatString(value,1,true)
      end
    end

    # deduct for heat exchangers
    temp_heat_exch_htg[:data].each_with_index do |row,i|
      new_row = []
      row.each_with_index do |column,j|
        if j == 0
          new_row <<  "Air System Heat Exchanger Total Heating Energy - #{column}"
        else
          value = column.gsub(",","").to_f * -1.0
          if i + 1.0 == temp_heat_exch_htg[:data].size
            # update monthly total for column
            orig_value = temp_vent_loss_ht[:data].last[j].gsub(",","").to_f
            new_value = orig_value + value
            temp_vent_loss_ht[:data].last[j] =  OpenStudio::toNeatString(new_value,1,true)
          else
            new_row << OpenStudio::toNeatString(value,1,true)
          end
        end
      end
      # add new row before monthly totals adjusted for heat exchangers
      if new_row.size > 1
        temp_vent_loss_ht[:data].insert(temp_vent_loss_ht[:data].size - 1, new_row)
      end
    end
    tables << @ventilation_loss_table = temp_vent_loss_ht
=end

    tables << @vent_htg_increase_loss_table = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner, 'Zone Mechanical Ventilation Heating Load Increase Energy', 'J', 'kBtu')
    tables << @vent_clg_decrease_loss_table = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner, 'Zone Mechanical Ventilation Cooling Load Decrease Energy', 'J', 'kBtu')
    tables << @infiltration_loss_table = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner, 'Zone Infiltration Sensible Heat Loss Energy', 'J', 'kBtu')
    tables << @window_loss_table = OsLib_ReportingHeatGainLoss.monthly_table_with_totals(model, sqlFile, runner, 'Surface Window Heat Loss Energy', 'J', 'kBtu')
    tables << @surface_loss_table = OsLib_ReportingHeatGainLoss.monthly_surface_heat_losses_table(model, sqlFile, runner)

    return @heat_losses
  end

  # create heat_loss_summary_section
  def self.heat_loss_summary_section(model, sqlFile, runner, name_only = false)
    # array to hold tables
    summary_tables = []

    # gather data for section
    @template_section = {}
    @template_section[:title] = 'Heat Loss Summary'
    @template_section[:tables] = summary_tables

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @template_section
    end

    # gather data from previous section
    source_tables = []
    source_tables << @vent_htg_increase_loss_table
    source_tables << @vent_clg_decrease_loss_table
    source_tables << @infiltration_loss_table
    source_tables << @window_loss_table
    source_tables << @surface_loss_table

    # component order and color
    component_color = {}
    component_color['Zone Mechanical Ventilation Cooling Load Decrease Energy'] = '#E88412'
    component_color['Zone Mechanical Ventilation Heating Load Increase Energy'] = '#E82F12'
    component_color['Zone Infiltration Sensible Heat Loss Energy'] = '#5B9C31'
    component_color['Ground Exposed Surfaces Heat Loss'] = '#7D8080'
    component_color['Exterior Wall Surfaces Heat Loss'] = '#CCB266'
    component_color['Surface Window Heat Loss Energy'] = '#66B2CC'
    component_color['Roof Surfaces Heat Loss'] = '#994C4C'

    # create table
    summary_table_01 = {}
    summary_table_01[:title] = 'Heat Loss Annual Breakdown (kBtu)'
    summary_table_01[:header] = ['Type', 'Quantity']
    summary_table_01[:units] = ['', 'kBtu']
    summary_table_01[:data] = []

    # create annual chart
    summary_table_01[:chart_type] = 'simple_pie'
    summary_table_01[:chart] = []

    # loop through tables to get annual information
    source_tables.each do |table|
      title = table[:title].gsub(' (kBtu)', '')

      # use subtotal rows for surfaces, total row for everything else
      if title == 'Surface Average Face Conduction Heat Loss'

        # exterior walls subtotal
        display_value = table[:data][table[:data].size - 4].last
        sub_total_title = 'Exterior Wall Surfaces Heat Loss'
        summary_table_01[:data] << [sub_total_title, display_value]
        summary_table_01[:chart] << JSON.generate(label: sub_total_title, value: display_value.to_s.gsub(',', '').to_f, color: component_color[sub_total_title])

        # exterior roofs subtotal
        display_value = table[:data][table[:data].size - 3].last
        sub_total_title = 'Roof Surfaces Heat Loss'
        summary_table_01[:data] << [sub_total_title, display_value]
        summary_table_01[:chart] << JSON.generate(label: sub_total_title, value: display_value.to_s.gsub(',', '').to_f, color: component_color[sub_total_title])

        # ground subtotal
        display_value = table[:data][table[:data].size - 2].last
        sub_total_title = 'Ground Exposed Surfaces Heat Loss'
        summary_table_01[:data] << [sub_total_title, display_value]
        summary_table_01[:chart] << JSON.generate(label: sub_total_title, value: display_value.to_s.gsub(',', '').to_f, color: component_color[sub_total_title])
      else
        display_value = table[:data].last.last
        summary_table_01[:data] << [title, display_value]
        summary_table_01[:chart] << JSON.generate(label: title, value: display_value.to_s.gsub(',', '').to_f, color: component_color[title])
      end
    end

    # add table to array of tables
    summary_tables << summary_table_01

    # create monthly table
    summary_table_02 = {}
    summary_table_02[:title] = 'Heat Loss Monthly Breakdown (kBtu)'
    summary_table_02[:header] = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    summary_table_02[:units] = []
    summary_table_02[:data] = []

    # create annual chart
    month_order = %w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
    summary_table_02[:chart_type] = 'vertical_stacked_bar'
    summary_table_02[:chart_attributes] = { value: summary_table_02[:title], label_x: 'Month', sort_yaxis: component_color.keys, sort_xaxis: month_order }
    summary_table_02[:chart] = []

    # loop through tables to get annual information
    source_tables.each do |table|
      title = table[:title].gsub(' (kBtu)', '')
      if title == 'Surface Average Face Conduction Heat Loss'

        # exterior walls subtotal
        row_data = []
        sub_title = 'Exterior Wall Surfaces Heat Loss'
        target_row = table[:data][table[:data].size - 4]
        row_data << sub_title
        target_row.each_with_index do |value, i|
          next if i < 3
          next if i == target_row.size - 1 # don't want to include annual total

          row_data << value
          # update chart
          month = summary_table_02[:header][i - 2] # shifted over because of extra columns
          clean_value = value.to_s.gsub(',', '').to_f
          summary_table_02[:chart] << JSON.generate(label: sub_title, label_x: month, value: clean_value, color: component_color[sub_title])
        end
        summary_table_02[:data] << row_data

        # exterior roofs subtotal
        row_data = []
        sub_title = 'Roof Surfaces Heat Loss'
        target_row = table[:data][table[:data].size - 3]
        row_data << sub_title
        target_row.each_with_index do |value, i|
          next if i < 3
          next if i == target_row.size - 1 # don't want to include annual total

          row_data << value
          # update chart
          month = summary_table_02[:header][i - 2] # shifted over because of extra columns
          clean_value = value.to_s.gsub(',', '').to_f
          summary_table_02[:chart] << JSON.generate(label: sub_title, label_x: month, value: clean_value, color: component_color[sub_title])
        end
        summary_table_02[:data] << row_data

        # ground subtotal
        row_data = []
        sub_title = 'Ground Exposed Surfaces Heat Loss'
        target_row = table[:data][table[:data].size - 2]
        row_data << sub_title
        target_row.each_with_index do |value, i|
          next if i < 3
          next if i == target_row.size - 1 # don't want to include annual total

          row_data << value
          # update chart
          month = summary_table_02[:header][i - 2] # shifted over because of extra columns
          clean_value = value.to_s.gsub(',', '').to_f
          summary_table_02[:chart] << JSON.generate(label: sub_title, label_x: month, value: clean_value, color: component_color[sub_title])
        end
        summary_table_02[:data] << row_data

      else

        row_data = []
        last_row = table[:data].last
        row_data << title
        last_row.each_with_index do |value, i|
          next if value == 'Monthly Totals'
          next if value == ''
          next if i == last_row.size - 1 # don't want to include annual total

          row_data << value

          # update chart
          month = summary_table_02[:header][i]
          clean_value = value.to_s.gsub(',', '').to_f
          summary_table_02[:chart] << JSON.generate(label: title, label_x: month, value: clean_value, color: component_color[title])
        end
        summary_table_02[:data] << row_data

      end
    end

    # add table to array of tables
    summary_tables << summary_table_02

    return @template_section
  end

  # monthly monthly_table_with_totals
  def self.monthly_table_with_totals(model, sqlFile, runner, var, source_units, target_units)
    # variables
    frequency = 'Monthly'

    # create table
    monthly_table_with_totals = {}
    monthly_table_with_totals[:title] = "#{var} (#{target_units})"
    monthly_table_with_totals[:header] = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Total']
    monthly_table_with_totals[:units] = [] # in title since all columns the same
    monthly_table_with_totals[:data] = []

    # get time series monthly data
    ann_env_pd = OsLib_ReportingHeatGainLoss.ann_env_pd(sqlFile)
    if ann_env_pd
      # loop through keys for variable
      keys = sqlFile.availableKeyValues(ann_env_pd, frequency, var)
      monthly_totals = ['Monthly Totals', 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
      keys.each do |key|
        total = 0.0
        var_value_monthly = [key]
        output_timeseries = sqlFile.timeSeries(ann_env_pd, frequency, var, key)
        # loop through timeseries and move the data from an OpenStudio timeseries to a normal Ruby array (vector)
        if output_timeseries.is_initialized # checks to see if time_series exists

          # see if filler needed at start or end of table/chart
          num_blanks_start = output_timeseries.get.dateTimes[0].date.monthOfYear.value - 2
          num_blanks_end = 12 - output_timeseries.get.values.size - num_blanks_start

          # fill in blank data for partial year simulations
          for i in 0..(num_blanks_start - 1)
            month = monthly_table_with_totals[:header][i + 1]
            var_value_monthly << ''
          end

          # get values
          output_timeseries = output_timeseries.get.values
          for i in 0..(output_timeseries.size - 1)
            month = monthly_table_with_totals[:header][i + 1 + num_blanks_start]
            value = OpenStudio.convert(output_timeseries[i], source_units, target_units).get
            total += value
            monthly_totals[i + 1] += value
            value_neat = OpenStudio::toNeatString(value, 1, true)
            var_value_monthly << value_neat
          end

          # fill in blank data for partial year simulations
          for i in 0..(num_blanks_end - 1)
            month = monthly_table_with_totals[:header][i]
            var_value_monthly << ''
          end

          # populate total column and clean up values
          total_neat = OpenStudio::toNeatString(total, 1, true)
          var_value_monthly << total_neat
          monthly_totals[13] += total

        else
          runner.registerWarning("Didn't find data for #{var} #{key}")
        end

        # add each key to data
        monthly_table_with_totals[:data] << var_value_monthly
      end

    else
      runner.registerWarning('An annual simulation was not run. Cannot get annual timeseries data')
      return false
    end

    # add table totals
    monthly_totals_neat = []
    monthly_totals.each do |total|
      if total == 'Monthly Totals'
        monthly_totals_neat << total
      else
        monthly_totals_neat << OpenStudio::toNeatString(total, 1, true)
      end
    end
    monthly_table_with_totals[:data] << monthly_totals_neat
    reg_val_display_name = "#{var}_annual"
    runner.registerValue(reg_val_string_prep(reg_val_display_name), monthly_totals.last, 'kBtu')

    return monthly_table_with_totals
  end

  # monthly_surface_heat_gains_and_losses_table rolled up from hourly values
  def self.monthly_surface_heat_gains_table(model, sqlFile, runner)
    # variables
    frequency = 'Hourly'
    var = 'Surface Average Face Conduction Heat Transfer Energy'
    source_units = 'J'
    target_units = 'kBtu'

    # create table
    monthly_surface_heat_gains_table = {}
    monthly_surface_heat_gains_table[:title] = "Surface Average Face Conduction Heat Gain (#{target_units})" # heat losses will be in another table
    monthly_surface_heat_gains_table[:header] = ['', 'Surface Type', 'Ouside Boundary Condition', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Total']
    monthly_surface_heat_gains_table[:units] = [] # in title since all columns the same
    monthly_surface_heat_gains_table[:data] = []

    monthly_totals = {}
    model.getSurfaces.sort.each do |surface|
      next if surface.outsideBoundaryCondition == 'Surface'
      next if surface.outsideBoundaryCondition == 'Adiabatic'

      key = surface.name.to_s
      row_data = []
      row_data << surface.name.to_s
      row_data << surface.surfaceType
      row_data << surface.outsideBoundaryCondition

      # get time series hourly data
      ann_env_pd = OsLib_ReportingHeatGainLoss.ann_env_pd(sqlFile)
      if ann_env_pd

        # get timeseries data
        output_timeseries = sqlFile.timeSeries(ann_env_pd, frequency, var, key)
        if output_timeseries.is_initialized # checks to see if time_series exists
          values = output_timeseries.get.values
          date_times = output_timeseries.get.dateTimes

          # loop through hourly data
          surface_values_hash = {}
          values.size.times do |i|
            value = values[i]
            # if value negative then set to 0 (heat losses will be in their own table with reversed logic)
            if value < 0.0
              value = 0.0
            end
            month = date_times[i].date.monthOfYear.valueName
            if surface_values_hash.has_key?(month)
              surface_values_hash[month] += value
            else
              surface_values_hash[month] = value
            end
          end

          # loop through has to populate row for table
          annual_total_ip = 0.0
          surface_values_hash.each do |month, monthly_value_si|
            monthly_value_ip = OpenStudio.convert(monthly_value_si, source_units, target_units).get

            # update value for total column
            annual_total_ip += monthly_value_ip

            # update value for totals row
            if monthly_totals.has_key?(month)
              monthly_totals[month][:total] += monthly_value_ip
            else
              monthly_totals[month] = {}
              monthly_totals[month][:total] = monthly_value_ip
            end

            # add sub-totals
            if surface.outsideBoundaryCondition == 'Outdoors' && surface.surfaceType == 'Wall'
              if monthly_totals[month].has_key?(:ext_wall)
                monthly_totals[month][:ext_wall] += monthly_value_ip
              else
                monthly_totals[month][:ext_wall] = monthly_value_ip
              end
            elsif surface.outsideBoundaryCondition == 'Outdoors' && surface.surfaceType == 'RoofCeiling'
              if monthly_totals[month].has_key?(:ext_roof)
                monthly_totals[month][:ext_roof] += monthly_value_ip
              else
                monthly_totals[month][:ext_roof] = monthly_value_ip
              end
            else # assume others are ground, could also include OtherSideConditionsModel, could be floor or walls
              if monthly_totals[month].has_key?(:ground)
                monthly_totals[month][:ground] += monthly_value_ip
              else
                monthly_totals[month][:ground] = monthly_value_ip
              end
            end

            monthly_value_ip_neat = OpenStudio::toNeatString(monthly_value_ip, 1, true)
            row_data << monthly_value_ip_neat
          end

          # add annual total
          row_data << OpenStudio::toNeatString(annual_total_ip, 1, true)
          monthly_surface_heat_gains_table[:data] << row_data

        else
          runner.registerWarning("Didn't find data for #{var} #{key}")
        end

      else
        runner.registerWarning('An annual simulation was not run. Cannot get annual timeseries data')
        return false
      end
    end

    # add total and sub-total rows
    row_data_total = ['Monthly Totals', '', '']
    row_data_sub_ext_wall = ['Monthly SubTotals', 'Wall', 'Outdoors']
    row_data_sub_ext_roof = ['Monthly SubTotals', 'Roof', 'Outdoors']
    row_data_sub_ground = ['Monthly SubTotals', '', 'Ground']
    row_data_total_annual = 0.0
    row_data_sub_ext_wall_annual = 0.0
    row_data_sub_ext_roof_annual = 0.0
    row_data_sub_ground_annual = 0.0
    monthly_totals.each do |month, hash|
      # add 0 value if key doesn't exist for surface type
      if not hash.has_key?(:ext_wall) then hash[:ext_wall] = 0 end
      if not hash.has_key?(:ext_roof) then hash[:ext_roof] = 0 end
      if not hash.has_key?(:ground) then hash[:ground] = 0 end
      if not hash.has_key?(:total) then hash[:total] = 0 end

      row_data_sub_ext_wall << OpenStudio::toNeatString(hash[:ext_wall], 1, true)
      row_data_sub_ext_wall_annual += hash[:ext_wall]
      row_data_sub_ext_roof << OpenStudio::toNeatString(hash[:ext_roof], 1, true)
      row_data_sub_ext_roof_annual += hash[:ext_roof]
      row_data_sub_ground << OpenStudio::toNeatString(hash[:ground], 1, true)
      row_data_sub_ground_annual += hash[:ground]
      row_data_total << OpenStudio::toNeatString(hash[:total], 1, true)
      row_data_total_annual += hash[:total]
    end

    # add annual total column in total and subtotal rows
    row_data_sub_ext_wall << OpenStudio::toNeatString(row_data_sub_ext_wall_annual, 1, true)
    row_data_sub_ext_roof << OpenStudio::toNeatString(row_data_sub_ext_roof_annual, 1, true)
    row_data_sub_ground << OpenStudio::toNeatString(row_data_sub_ground_annual, 1, true)
    row_data_total << OpenStudio::toNeatString(row_data_total_annual, 1, true)

    # register values
    runner.registerValue('ext_wall_heat_gain', row_data_sub_ext_wall.last.gsub(',', '').to_f, 'kBtu')
    runner.registerValue('ext_roof_heat_gain', row_data_sub_ext_roof.last.gsub(',', '').to_f, 'kBtu')
    runner.registerValue('ground_heat_gain', row_data_sub_ground.last.gsub(',', '').to_f, 'kBtu')
    runner.registerValue('surface_heat_gain', row_data_total.last.gsub(',', '').to_f, 'kBtu')

    # add rows
    monthly_surface_heat_gains_table[:data] << row_data_sub_ext_wall
    monthly_surface_heat_gains_table[:data] << row_data_sub_ext_roof
    monthly_surface_heat_gains_table[:data] << row_data_sub_ground
    monthly_surface_heat_gains_table[:data] << row_data_total

    return monthly_surface_heat_gains_table
  end

  # monthly_surface_heat_losses_and_losses_table rolled up from hourly values
  def self.monthly_surface_heat_losses_table(model, sqlFile, runner)
    # variables
    frequency = 'Hourly'
    var = 'Surface Average Face Conduction Heat Transfer Energy'
    source_units = 'J'
    target_units = 'kBtu'

    # create table
    monthly_surface_heat_losses_table = {}
    monthly_surface_heat_losses_table[:title] = "Surface Average Face Conduction Heat Loss (#{target_units})" # heat losses will be in another table
    monthly_surface_heat_losses_table[:header] = ['', 'Surface Type', 'Ouside Boundary Condition', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Total']
    monthly_surface_heat_losses_table[:units] = [] # in title since all columns the same
    monthly_surface_heat_losses_table[:data] = []

    monthly_totals = {}
    model.getSurfaces.sort.each do |surface|
      next if surface.outsideBoundaryCondition == 'Surface'
      next if surface.outsideBoundaryCondition == 'Adiabatic'

      key = surface.name.to_s
      row_data = []
      row_data << surface.name.to_s
      row_data << surface.surfaceType
      row_data << surface.outsideBoundaryCondition

      # get time series hourly data
      ann_env_pd = OsLib_ReportingHeatGainLoss.ann_env_pd(sqlFile)
      if ann_env_pd

        # get timeseries data
        output_timeseries = sqlFile.timeSeries(ann_env_pd, frequency, var, key)
        if output_timeseries.is_initialized # checks to see if time_series exists
          values = output_timeseries.get.values
          date_times = output_timeseries.get.dateTimes

          # loop through hourly data
          surface_values_hash = {}
          values.size.times do |i|
            value = values[i]
            # if value positive then set to 0 (heat gains will be in their own table with reversed logic)
            if value > 0.0
              value = 0.0
            else
              value = value.abs
            end
            month = date_times[i].date.monthOfYear.valueName
            if surface_values_hash.has_key?(month)
              surface_values_hash[month] += value
            else
              surface_values_hash[month] = value
            end
          end

          # loop through has to populate row for table
          annual_total_ip = 0.0
          surface_values_hash.each do |month, monthly_value_si|
            monthly_value_ip = OpenStudio.convert(monthly_value_si, source_units, target_units).get

            # update value for total column
            annual_total_ip += monthly_value_ip

            # update value for totals row
            if monthly_totals.has_key?(month)
              monthly_totals[month][:total] += monthly_value_ip
            else
              monthly_totals[month] = {}
              monthly_totals[month][:total] = monthly_value_ip
            end

            # add sub-totals
            if surface.outsideBoundaryCondition == 'Outdoors' && surface.surfaceType == 'Wall'
              if monthly_totals[month].has_key?(:ext_wall)
                monthly_totals[month][:ext_wall] += monthly_value_ip
              else
                monthly_totals[month][:ext_wall] = monthly_value_ip
              end
            elsif surface.outsideBoundaryCondition == 'Outdoors' && surface.surfaceType == 'RoofCeiling'
              if monthly_totals[month].has_key?(:ext_roof)
                monthly_totals[month][:ext_roof] += monthly_value_ip
              else
                monthly_totals[month][:ext_roof] = monthly_value_ip
              end
            else # assume others are ground, could also include OtherSideConditionsModel, could be floor or walls
              if monthly_totals[month].has_key?(:ground)
                monthly_totals[month][:ground] += monthly_value_ip
              else
                monthly_totals[month][:ground] = monthly_value_ip
              end
            end

            monthly_value_ip_neat = OpenStudio::toNeatString(monthly_value_ip, 1, true)
            row_data << monthly_value_ip_neat
          end

          # add annual total
          row_data << OpenStudio::toNeatString(annual_total_ip, 1, true)
          monthly_surface_heat_losses_table[:data] << row_data

        else
          runner.registerWarning("Didn't find data for #{var} #{key}")
        end

      else
        runner.registerWarning('An annual simulation was not run. Cannot get annual timeseries data')
        return false
      end
    end

    # add total and sub-total rows
    row_data_total = ['Monthly Totals', '', '']
    row_data_sub_ext_wall = ['Monthly SubTotals', 'Wall', 'Outdoors']
    row_data_sub_ext_roof = ['Monthly SubTotals', 'Roof', 'Outdoors']
    row_data_sub_ground = ['Monthly SubTotals', '', 'Ground']
    row_data_total_annual = 0.0
    row_data_sub_ext_wall_annual = 0.0
    row_data_sub_ext_roof_annual = 0.0
    row_data_sub_ground_annual = 0.0
    monthly_totals.each do |month, hash|
      # add 0 value if key doesn't exist for surface type
      if not hash.has_key?(:ext_wall) then hash[:ext_wall] = 0 end
      if not hash.has_key?(:ext_roof) then hash[:ext_roof] = 0 end
      if not hash.has_key?(:ground) then hash[:ground] = 0 end
      if not hash.has_key?(:total) then hash[:total] = 0 end

      row_data_sub_ext_wall << OpenStudio::toNeatString(hash[:ext_wall], 1, true)
      row_data_sub_ext_wall_annual += hash[:ext_wall]
      row_data_sub_ext_roof << OpenStudio::toNeatString(hash[:ext_roof], 1, true)
      row_data_sub_ext_roof_annual += hash[:ext_roof]
      row_data_sub_ground << OpenStudio::toNeatString(hash[:ground], 1, true)
      row_data_sub_ground_annual += hash[:ground]
      row_data_total << OpenStudio::toNeatString(hash[:total], 1, true)
      row_data_total_annual += hash[:total]
    end

    # add annual total column in total and subtotal rows
    row_data_sub_ext_wall << OpenStudio::toNeatString(row_data_sub_ext_wall_annual, 1, true)
    row_data_sub_ext_roof << OpenStudio::toNeatString(row_data_sub_ext_roof_annual, 1, true)
    row_data_sub_ground << OpenStudio::toNeatString(row_data_sub_ground_annual, 1, true)
    row_data_total << OpenStudio::toNeatString(row_data_total_annual, 1, true)

    # register values
    runner.registerValue('ext_wall_heat_loss', row_data_sub_ext_wall.last.gsub(',', '').to_f, 'kBtu')
    runner.registerValue('ext_roof_heat_loss', row_data_sub_ext_roof.last.gsub(',', '').to_f, 'kBtu')
    runner.registerValue('ground_heat_loss', row_data_sub_ground.last.gsub(',', '').to_f, 'kBtu')
    runner.registerValue('surface_heat_loss', row_data_total.last.gsub(',', '').to_f, 'kBtu')

    # add rows
    monthly_surface_heat_losses_table[:data] << row_data_sub_ext_wall
    monthly_surface_heat_losses_table[:data] << row_data_sub_ext_roof
    monthly_surface_heat_losses_table[:data] << row_data_sub_ground
    monthly_surface_heat_losses_table[:data] << row_data_total

    return monthly_surface_heat_losses_table
  end
end
