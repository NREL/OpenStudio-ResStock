# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require_relative 'resources/constants.rb'
require_relative '../HPXMLtoOpenStudio/resources/constants.rb'
require_relative '../HPXMLtoOpenStudio/resources/energyplus.rb'
require_relative '../HPXMLtoOpenStudio/resources/hpxml.rb'
require_relative '../HPXMLtoOpenStudio/resources/unit_conversions.rb'

# start the measure
class SimulationOutputReport < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'HPXML Simulation Output Report'
  end

  # human readable description
  def description
    return 'Reports simulation outputs for residential HPXML-based models.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Processes EnergyPlus simulation outputs in order to generate an annual output file and an optional timeseries output file.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    format_chs = OpenStudio::StringVector.new
    format_chs << 'csv'
    format_chs << 'json'
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('output_format', format_chs, false)
    arg.setDisplayName('Output Format')
    arg.setDescription('The file format of the annual (and timeseries, if requested) outputs.')
    arg.setDefaultValue('csv')
    args << arg

    timeseries_frequency_chs = OpenStudio::StringVector.new
    timeseries_frequency_chs << 'none'
    reporting_frequency_map.keys.each do |freq|
      timeseries_frequency_chs << freq
    end
    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('timeseries_frequency', timeseries_frequency_chs, true)
    arg.setDisplayName('Timeseries Reporting Frequency')
    arg.setDescription("The frequency at which to report timeseries output data. Using 'none' will disable timeseries outputs.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_fuel_consumptions', true)
    arg.setDisplayName('Generate Timeseries Output: Fuel Consumptions')
    arg.setDescription('Generates timeseries energy consumptions for each fuel type.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_end_use_consumptions', true)
    arg.setDisplayName('Generate Timeseries Output: End Use Consumptions')
    arg.setDescription('Generates timeseries energy consumptions for each end use.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_hot_water_uses', true)
    arg.setDisplayName('Generate Timeseries Output: Hot Water Uses')
    arg.setDescription('Generates timeseries hot water usages for each end use.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_total_loads', true)
    arg.setDisplayName('Generate Timeseries Output: Total Loads')
    arg.setDescription('Generates timeseries total heating, cooling, and hot water loads.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_component_loads', true)
    arg.setDisplayName('Generate Timeseries Output: Component Loads')
    arg.setDescription('Generates timeseries heating and cooling loads disaggregated by component type.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_unmet_loads', true)
    arg.setDisplayName('Generate Timeseries Output: Unmet Loads')
    arg.setDescription('Generates timeseries unmet heating and cooling loads.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_zone_temperatures', true)
    arg.setDisplayName('Generate Timeseries Output: Zone Temperatures')
    arg.setDescription('Generates timeseries temperatures for each thermal zone.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_airflows', true)
    arg.setDisplayName('Generate Timeseries Output: Airflows')
    arg.setDescription('Generates timeseries airflows.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('include_timeseries_weather', true)
    arg.setDisplayName('Generate Timeseries Output: Weather')
    arg.setDescription('Generates timeseries weather data.')
    arg.setDefaultValue(false)
    args << arg

    return args
  end

  # define the outputs that the measure will create
  def outputs
    outs = OpenStudio::Measure::OSOutputVector.new

    setup_outputs

    all_outputs = []
    all_outputs << @fuels
    all_outputs << @end_uses
    all_outputs << @loads
    all_outputs << @unmet_loads
    all_outputs << @peak_fuels
    all_outputs << @peak_loads
    all_outputs << @component_loads
    all_outputs << @hot_water_uses

    output_names = []
    all_outputs.each do |outputs|
      outputs.each do |key, obj|
        output_names << get_runner_output_name(obj)
      end
    end

    output_names.each do |output_name|
      outs << OpenStudio::Measure::OSOutput.makeDoubleOutput(output_name)
    end

    return outs
  end

  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    result = OpenStudio::IdfObjectVector.new

    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return result
    end

    # get the last model and sql file
    @model = runner.lastOpenStudioModel.get

    setup_outputs

    # Get a few things from the model
    get_object_maps()

    total_loads_program = @model.getModelObjectByName(Constants.ObjectNameTotalLoadsProgram.gsub(' ', '_')).get.to_EnergyManagementSystemProgram.get
    comp_loads_program = @model.getModelObjectByName(Constants.ObjectNameComponentLoadsProgram.gsub(' ', '_'))
    if comp_loads_program.is_initialized
      comp_loads_program = comp_loads_program.get.to_EnergyManagementSystemProgram.get
    else
      comp_loads_program = nil
    end

    # Annual outputs

    # Add meters to increase precision of outputs relative to, e.g., ABUPS report
    meters = []
    meters << 'ElectricityProduced:Facility' # Used for error checking
    @fuels.each do |fuel_type, fuel|
      fuel.meters.each do |meter|
        meters << meter
      end
    end
    @end_uses.each do |key, end_use|
      next if end_use.meters.nil?

      end_use.meters.each do |meter|
        meters << meter
      end
    end
    meters.each do |meter|
      result << OpenStudio::IdfObject.load("Output:Meter,#{meter},runperiod;").get
    end

    # Add hot water use outputs
    @hot_water_uses.each do |hot_water_type, hot_water|
      result << OpenStudio::IdfObject.load("Output:Variable,*,#{hot_water.variable},runperiod;").get
      break
    end

    # Add unmet load outputs
    @unmet_loads.each do |load_type, unmet_load|
      result << OpenStudio::IdfObject.load("Output:Variable,#{unmet_load.key},#{unmet_load.variable},runperiod;").get
    end

    # Add ideal air system load outputs
    @ideal_system_loads.each do |load_type, ideal_load|
      result << OpenStudio::IdfObject.load("Output:Variable,#{ideal_load.key},#{ideal_load.variable},runperiod;").get
    end

    # Add peak electricity outputs
    @peak_fuels.each do |key, peak_fuel|
      peak_fuel.meters.each do |meter|
        result << OpenStudio::IdfObject.load("Output:Table:Monthly,#{peak_fuel.report},2,#{meter},HoursPositive,Electricity:Facility,MaximumDuringHoursShown;").get
      end
    end

    # Add component load outputs
    @component_loads.each do |key, comp_load|
      next if comp_loads_program.nil?

      result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{comp_load.ems_variable}_annual_outvar,#{comp_load.ems_variable},Summed,ZoneTimestep,#{comp_loads_program.name},J;").get
      result << OpenStudio::IdfObject.load("Output:Variable,*,#{comp_load.ems_variable}_annual_outvar,runperiod;").get
    end

    # Add total load outputs
    @loads.each do |load_type, load|
      next if load.ems_variable.nil?

      result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{load.ems_variable}_annual_outvar,#{load.ems_variable},Summed,ZoneTimestep,#{total_loads_program.name},J;").get
      result << OpenStudio::IdfObject.load("Output:Variable,*,#{load.ems_variable}_annual_outvar,runperiod;").get
    end

    # Add individual HVAC/DHW system variables
    add_object_output_variables('runperiod').each do |outvar|
      result << outvar
    end

    # Timeseries outputs

    timeseries_frequency = runner.getStringArgumentValue('timeseries_frequency', user_arguments)
    if timeseries_frequency != 'none'
      include_timeseries_fuel_consumptions = runner.getBoolArgumentValue('include_timeseries_fuel_consumptions', user_arguments)
      include_timeseries_end_use_consumptions = runner.getBoolArgumentValue('include_timeseries_end_use_consumptions', user_arguments)
      include_timeseries_hot_water_uses = runner.getBoolArgumentValue('include_timeseries_hot_water_uses', user_arguments)
      include_timeseries_total_loads = runner.getBoolArgumentValue('include_timeseries_total_loads', user_arguments)
      include_timeseries_component_loads = runner.getBoolArgumentValue('include_timeseries_component_loads', user_arguments)
      include_timeseries_unmet_loads = runner.getBoolArgumentValue('include_timeseries_unmet_loads', user_arguments)
      include_timeseries_zone_temperatures = runner.getBoolArgumentValue('include_timeseries_zone_temperatures', user_arguments)
      include_timeseries_airflows = runner.getBoolArgumentValue('include_timeseries_airflows', user_arguments)
      include_timeseries_weather = runner.getBoolArgumentValue('include_timeseries_weather', user_arguments)
    end

    if include_timeseries_fuel_consumptions
      # If fuel uses are selected, we also need to select end uses because
      # fuels may be adjusted by DSE.
      # TODO: This could be removed if we could account for DSE in E+ or used EMS.
      include_timeseries_end_use_consumptions = true
    end

    if include_timeseries_zone_temperatures
      result << OpenStudio::IdfObject.load("Output:Variable,*,Zone Mean Air Temperature,#{timeseries_frequency};").get
      # For reporting temperature-scheduled spaces timeseries temperatures.
      keys = [HPXML::LocationOtherHeatedSpace, HPXML::LocationOtherMultifamilyBufferSpace, HPXML::LocationOtherNonFreezingSpace,
              HPXML::LocationOtherHousingUnit, HPXML::LocationExteriorWall, HPXML::LocationUnderSlab]
      keys.each do |key|
        result << OpenStudio::IdfObject.load("Output:Variable,#{key},Schedule Value,#{timeseries_frequency};").get
      end
    end

    if include_timeseries_airflows
      @airflows.each do |airflow_type, airflow|
        ems_program = @model.getModelObjectByName(airflow.ems_program.gsub(' ', '_')).get.to_EnergyManagementSystemProgram.get
        airflow.ems_variables.each do |ems_variable|
          result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{ems_variable}_timeseries_outvar,#{ems_variable},Averaged,ZoneTimestep,#{ems_program.name},m^3/s;").get
          result << OpenStudio::IdfObject.load("Output:Variable,*,#{ems_variable}_timeseries_outvar,#{timeseries_frequency};").get
        end
      end
    end

    if include_timeseries_weather
      @weather.each do |weather_type, weather_data|
        result << OpenStudio::IdfObject.load("Output:Variable,*,#{weather_data.variable},#{timeseries_frequency};").get
      end
    end

    if include_timeseries_fuel_consumptions
      @fuels.each do |fuel_type, fuel|
        fuel.meters.each do |meter|
          result << OpenStudio::IdfObject.load("Output:Meter,#{meter},#{timeseries_frequency};").get
        end
      end
    end

    if include_timeseries_end_use_consumptions
      @end_uses.each do |key, end_use|
        next if end_use.meters.nil?

        end_use.meters.each do |meter|
          result << OpenStudio::IdfObject.load("Output:Meter,#{meter},#{timeseries_frequency};").get
        end
      end
      # Add output variables for individual HVAC/DHW systems
      add_object_output_variables(timeseries_frequency).each do |outvar|
        result << outvar
      end
    end

    if include_timeseries_hot_water_uses
      result << OpenStudio::IdfObject.load("Output:Variable,*,Water Use Equipment Hot Water Volume,#{timeseries_frequency};").get
    end

    if include_timeseries_total_loads
      @loads.each do |load_type, load|
        next if load.ems_variable.nil?

        result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{load.ems_variable}_timeseries_outvar,#{load.ems_variable},Summed,ZoneTimestep,#{total_loads_program.name},J;").get
        result << OpenStudio::IdfObject.load("Output:Variable,*,#{load.ems_variable}_timeseries_outvar,#{timeseries_frequency};").get
      end
      # And add HotWaterDelivered:
      result << OpenStudio::IdfObject.load("Output:Variable,*,Water Use Connections Plant Hot Water Energy,#{timeseries_frequency};").get
    end

    if include_timeseries_component_loads
      @component_loads.each do |key, comp_load|
        next if comp_loads_program.nil?

        result << OpenStudio::IdfObject.load("EnergyManagementSystem:OutputVariable,#{comp_load.ems_variable}_timeseries_outvar,#{comp_load.ems_variable},Summed,ZoneTimestep,#{comp_loads_program.name},J;").get
        result << OpenStudio::IdfObject.load("Output:Variable,*,#{comp_load.ems_variable}_timeseries_outvar,#{timeseries_frequency};").get
      end
    end

    if include_timeseries_unmet_loads
      @unmet_loads.each do |load_type, unmet_load|
        result << OpenStudio::IdfObject.load("Output:Variable,#{unmet_load.key},#{unmet_load.variable},#{timeseries_frequency};").get
      end
    end

    return result
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find OpenStudio model.')
      return false
    end
    @model = model.get

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(@model), user_arguments)
      return false
    end

    output_format = runner.getStringArgumentValue('output_format', user_arguments)
    timeseries_frequency = runner.getStringArgumentValue('timeseries_frequency', user_arguments)
    if timeseries_frequency != 'none'
      include_timeseries_fuel_consumptions = runner.getBoolArgumentValue('include_timeseries_fuel_consumptions', user_arguments)
      include_timeseries_end_use_consumptions = runner.getBoolArgumentValue('include_timeseries_end_use_consumptions', user_arguments)
      include_timeseries_hot_water_uses = runner.getBoolArgumentValue('include_timeseries_hot_water_uses', user_arguments)
      include_timeseries_total_loads = runner.getBoolArgumentValue('include_timeseries_total_loads', user_arguments)
      include_timeseries_component_loads = runner.getBoolArgumentValue('include_timeseries_component_loads', user_arguments)
      include_timeseries_unmet_loads = runner.getBoolArgumentValue('include_timeseries_unmet_loads', user_arguments)
      include_timeseries_zone_temperatures = runner.getBoolArgumentValue('include_timeseries_zone_temperatures', user_arguments)
      include_timeseries_airflows = runner.getBoolArgumentValue('include_timeseries_airflows', user_arguments)
      include_timeseries_weather = runner.getBoolArgumentValue('include_timeseries_weather', user_arguments)
    end

    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError('Cannot find EnergyPlus sql file.')
      return false
    end
    @sqlFile = sqlFile.get
    if not @sqlFile.connectionOpen
      runner.registerError('EnergyPlus simulation failed.')
      return false
    end
    @model.setSqlFile(@sqlFile)

    hpxml_path = @model.getBuilding.additionalProperties.getFeatureAsString('hpxml_path').get
    building_id = @model.getBuilding.additionalProperties.getFeatureAsString('building_id').get
    @hpxml = HPXML.new(hpxml_path: hpxml_path, building_id: building_id)
    HVAC.apply_shared_systems(@hpxml) # Needed for ERI shared HVAC systems
    get_object_maps()
    @eri_design = @hpxml.header.eri_design

    setup_outputs

    # Set paths
    if not @eri_design.nil?
      # ERI run, store files in a particular location
      output_dir = File.dirname(hpxml_path)
      hpxml_name = File.basename(hpxml_path).gsub('.xml', '')
      annual_output_path = File.join(output_dir, "#{hpxml_name}.#{output_format}")
      eri_output_path = File.join(output_dir, "#{hpxml_name}_ERI.csv")
      timeseries_output_path = File.join(output_dir, "#{hpxml_name}_#{timeseries_frequency.capitalize}.#{output_format}")
    else
      output_dir = File.dirname(@sqlFile.path.to_s)
      annual_output_path = File.join(output_dir, "results_annual.#{output_format}")
      eri_output_path = nil
      timeseries_output_path = File.join(output_dir, "results_timeseries.#{output_format}")
    end

    @timestamps = get_timestamps(timeseries_frequency)

    # Retrieve outputs
    outputs = get_outputs(timeseries_frequency,
                          include_timeseries_fuel_consumptions,
                          include_timeseries_end_use_consumptions,
                          include_timeseries_hot_water_uses,
                          include_timeseries_total_loads,
                          include_timeseries_component_loads,
                          include_timeseries_unmet_loads,
                          include_timeseries_zone_temperatures,
                          include_timeseries_airflows,
                          include_timeseries_weather)

    @sqlFile.close()

    # Ensure sql file is immediately freed; otherwise we can get
    # errors on Windows when trying to delete this file.
    GC.start()

    if not check_for_errors(runner, outputs)
      return false
    end

    # Write/report results
    write_annual_output_results(runner, outputs, output_format, annual_output_path)
    report_sim_outputs(runner)
    write_eri_output_results(outputs, eri_output_path)
    write_timeseries_output_results(runner, output_format,
                                    timeseries_output_path,
                                    timeseries_frequency,
                                    include_timeseries_fuel_consumptions,
                                    include_timeseries_end_use_consumptions,
                                    include_timeseries_hot_water_uses,
                                    include_timeseries_total_loads,
                                    include_timeseries_component_loads,
                                    include_timeseries_unmet_loads,
                                    include_timeseries_zone_temperatures,
                                    include_timeseries_airflows,
                                    include_timeseries_weather)

    return true
  end

  def get_timestamps(timeseries_frequency)
    if timeseries_frequency == 'hourly'
      interval_type = 1
    elsif timeseries_frequency == 'daily'
      interval_type = 2
    elsif timeseries_frequency == 'monthly'
      interval_type = 3
    elsif timeseries_frequency == 'timestep'
      interval_type = -1
    end

    query = "SELECT Year || ' ' || Month || ' ' || Day || ' ' || Hour || ' ' || Minute As Timestamp FROM Time WHERE IntervalType='#{interval_type}'"
    values = @sqlFile.execAndReturnVectorOfString(query)
    fail "Query error: #{query}" unless values.is_initialized

    timestamps = []
    values.get.each do |value|
      year, month, day, hour, minute = value.split(' ')
      ts = Time.new(year, month, day, hour, minute)
      timestamps << ts.strftime('%Y/%m/%d %H:%M:00')
    end

    return timestamps
  end

  def get_outputs(timeseries_frequency,
                  include_timeseries_fuel_consumptions,
                  include_timeseries_end_use_consumptions,
                  include_timeseries_hot_water_uses,
                  include_timeseries_total_loads,
                  include_timeseries_component_loads,
                  include_timeseries_unmet_loads,
                  include_timeseries_zone_temperatures,
                  include_timeseries_airflows,
                  include_timeseries_weather)
    outputs = {}

    if include_timeseries_fuel_consumptions
      # If fuel uses are selected, we also need to select end uses because
      # fuels may be adjusted by DSE.
      # TODO: This could be removed if we could account for DSE in E+ or used EMS.
      include_timeseries_end_use_consumptions = true
    end

    # HPXML Summary
    outputs[:hpxml_cfa] = @hpxml.building_construction.conditioned_floor_area
    outputs[:hpxml_nbr] = @hpxml.building_construction.number_of_bedrooms
    outputs[:hpxml_nst] = @hpxml.building_construction.number_of_conditioned_floors_above_grade
    outputs[:hpxml_residential_facility_type] = @hpxml.building_construction.residential_facility_type

    # HPXML Systems
    if not @eri_design.nil?
      outputs[:hpxml_eec_heats] = get_hpxml_eec_heats()
      outputs[:hpxml_eec_cools] = get_hpxml_eec_cools()
      outputs[:hpxml_eec_dhws] = get_hpxml_eec_dhws()
      outputs[:hpxml_eec_vent_preheats] = get_hpxml_eec_vent_preheats()
      outputs[:hpxml_eec_vent_precools] = get_hpxml_eec_vent_precools()
    end
    outputs[:hpxml_heat_sys_ids] = get_hpxml_heat_sys_ids()
    outputs[:hpxml_cool_sys_ids] = get_hpxml_cool_sys_ids()
    outputs[:hpxml_vent_preheat_sys_ids] = get_hpxml_vent_preheat_sys_ids()
    outputs[:hpxml_vent_precool_sys_ids] = get_hpxml_vent_precool_sys_ids()
    outputs[:hpxml_dehumidifier_id] = @hpxml.dehumidifiers[0].id if @hpxml.dehumidifiers.size > 0
    outputs[:hpxml_dhw_sys_ids] = get_hpxml_dhw_sys_ids()
    outputs[:hpxml_dse_heats] = get_hpxml_dse_heats(outputs[:hpxml_heat_sys_ids])
    outputs[:hpxml_dse_cools] = get_hpxml_dse_cools(outputs[:hpxml_cool_sys_ids])
    outputs[:hpxml_heat_fuels] = get_hpxml_heat_fuels()
    outputs[:hpxml_dwh_fuels] = get_hpxml_dhw_fuels()
    outputs[:hpxml_vent_preheat_fuels] = get_hpxml_vent_preheat_fuels()

    # Fuel Uses
    @fuels.each do |fuel_type, fuel|
      fuel.annual_output = get_report_meter_data_annual(fuel.meters)
      if include_timeseries_fuel_consumptions
        fuel.timeseries_output = get_report_meter_data_timeseries(fuel.meters, UnitConversions.convert(1.0, 'J', fuel.timeseries_units), 0, timeseries_frequency)
      end
    end

    # Electricity Produced (used for error checking)
    outputs[:total_elec_produced] = get_report_meter_data_annual(['ElectricityProduced:Facility'])

    # Peak Electricity Consumption
    @peak_fuels.each do |key, peak_fuel|
      peak_fuel.annual_output = get_tabular_data_value(peak_fuel.report.upcase, 'Meter', 'Custom Monthly Report', ['Maximum of Months'], 'ELECTRICITY:FACILITY {MAX FOR HOURS SHOWN', peak_fuel.annual_units)
    end

    # Total loads
    @loads.each do |load_type, load|
      next if load.ems_variable.nil?

      load.annual_output = get_report_variable_data_annual(['EMS'], ["#{load.ems_variable}_annual_outvar"])
      if include_timeseries_total_loads
        load.timeseries_output = get_report_variable_data_timeseries(['EMS'], ["#{load.ems_variable}_timeseries_outvar"], UnitConversions.convert(1.0, 'J', load.timeseries_units), 0, timeseries_frequency)
      end
    end

    # Component Loads
    @component_loads.each do |key, comp_load|
      comp_load.annual_output = get_report_variable_data_annual(['EMS'], ["#{comp_load.ems_variable}_annual_outvar"])
      if include_timeseries_component_loads
        comp_load.timeseries_output = get_report_variable_data_timeseries(['EMS'], ["#{comp_load.ems_variable}_timeseries_outvar"], UnitConversions.convert(1.0, 'J', comp_load.timeseries_units), 0, timeseries_frequency)
      end
    end

    # Unmet loads (heating/cooling energy delivered by backup ideal air system)
    @unmet_loads.each do |load_type, unmet_load|
      unmet_load.annual_output = get_report_variable_data_annual([unmet_load.key.upcase], [unmet_load.variable])
      if include_timeseries_unmet_loads
        unmet_load.timeseries_output = get_report_variable_data_timeseries([unmet_load.key.upcase], [unmet_load.variable], UnitConversions.convert(1.0, 'J', unmet_load.timeseries_units), 0, timeseries_frequency)
      end
    end

    # Ideal system loads (expected fraction of loads that are not met by partial HVAC (e.g., room AC that meets 30% of load))
    @ideal_system_loads.each do |load_type, ideal_load|
      ideal_load.annual_output = get_report_variable_data_annual([ideal_load.key.upcase], [ideal_load.variable])
    end

    # Peak Building Space Heating/Cooling Loads (total heating/cooling energy delivered including backup ideal air system)
    @peak_loads.each do |load_type, peak_load|
      peak_load.annual_output = UnitConversions.convert(get_tabular_data_value('EnergyMeters', 'Entire Facility', 'Annual and Peak Values - Other', peak_load.meters, 'Maximum Value', 'W'), 'Wh', peak_load.annual_units)
    end

    # End Uses (derived from meters)
    @end_uses.each do |key, end_use|
      next if end_use.meters.nil?

      fuel_type, end_use_type = key

      use_negative = false
      if end_use_type == EUT::PV
        use_negative = true
      elsif (end_use_type == EUT::Generator) && (fuel_type == FT::Elec)
        use_negative = true
      end

      end_use.annual_output = get_report_meter_data_annual(end_use.meters)
      if use_negative && (@end_uses[key].annual_output > 0)
        end_use.annual_output *= -1.0
      end
      next unless include_timeseries_end_use_consumptions

      timeseries_unit_conv = UnitConversions.convert(1.0, 'J', end_use.timeseries_units)
      if use_negative
        timeseries_unit_conv *= -1.0
      end
      end_use.timeseries_output = get_report_meter_data_timeseries(end_use.meters, timeseries_unit_conv, 0, timeseries_frequency)
    end

    # Hot Water Uses
    @hot_water_uses.each do |hot_water_type, hot_water|
      keys = @model.getWaterUseEquipments.select { |wue| wue.waterUseEquipmentDefinition.endUseSubcategory == hot_water.subcat }.map { |d| d.name.to_s.upcase }
      hot_water.annual_output = get_report_variable_data_annual(keys, [hot_water.variable], UnitConversions.convert(1.0, 'm^3', hot_water.annual_units))
      if include_timeseries_hot_water_uses
        hot_water.timeseries_output = get_report_variable_data_timeseries(keys, [hot_water.variable], UnitConversions.convert(1.0, 'm^3', hot_water.timeseries_units), 0, timeseries_frequency)
      end
    end

    # Space Heating (by System)
    dfhp_loads = get_dfhp_loads(outputs) # Calculate dual-fuel heat pump load
    outputs[:hpxml_heat_sys_ids].each do |sys_id|
      ep_output_names, dfhp_primary, dfhp_backup = get_ep_output_names_for_hvac_heating(sys_id)
      keys = ep_output_names.map(&:upcase)

      # End Use
      @fuels.each do |fuel_type, fuel|
        end_use = @end_uses[[fuel_type, EUT::Heating]]
        end_use.annual_output_by_system[sys_id] = get_report_variable_data_annual(keys, end_use.variable_names)
        if include_timeseries_end_use_consumptions
          end_use.timeseries_output_by_system[sys_id] = get_report_variable_data_timeseries(keys, end_use.variable_names, UnitConversions.convert(1.0, 'J', end_use.timeseries_units), 0, timeseries_frequency)
        end
      end

      # Disaggregated Fan/Pump Energy Use
      end_use = @end_uses[[FT::Elec, EUT::HeatingFanPump]]
      end_use.annual_output_by_system[sys_id] = get_report_variable_data_annual(['EMS'], ep_output_names.select { |name| name.end_with?(Constants.ObjectNameFanPumpDisaggregatePrimaryHeat) || name.end_with?(Constants.ObjectNameFanPumpDisaggregateBackupHeat) })
      if include_timeseries_end_use_consumptions
        end_use.timeseries_output_by_system[sys_id] = get_report_variable_data_timeseries(['EMS'], ep_output_names.select { |name| name.end_with?(Constants.ObjectNameFanPumpDisaggregatePrimaryHeat) || name.end_with?(Constants.ObjectNameFanPumpDisaggregateBackupHeat) }, UnitConversions.convert(1.0, 'J', end_use.timeseries_units), 0, timeseries_frequency)
      end

      # Reference Load
      if [Constants.CalcTypeERIReferenceHome, Constants.CalcTypeERIIndexAdjustmentReferenceHome].include? @eri_design
        @loads[LT::Heating].annual_output_by_system[sys_id] = split_htg_load_to_system_by_fraction(sys_id, @loads[LT::Heating].annual_output, dfhp_loads)
      end
    end

    # Space Cooling (by System)
    outputs[:hpxml_cool_sys_ids].each do |sys_id|
      ep_output_names = get_ep_output_names_for_hvac_cooling(sys_id)
      keys = ep_output_names.map(&:upcase)

      # End Uses
      end_use = @end_uses[[FT::Elec, EUT::Cooling]]
      end_use.annual_output_by_system[sys_id] = get_report_variable_data_annual(keys, end_use.variable_names)
      if include_timeseries_end_use_consumptions
        end_use.timeseries_output_by_system[sys_id] = get_report_variable_data_timeseries(keys, end_use.variable_names, UnitConversions.convert(1.0, 'J', end_use.timeseries_units), 0, timeseries_frequency)
      end

      # Disaggregated Fan/Pump Energy Use
      end_use = @end_uses[[FT::Elec, EUT::CoolingFanPump]]
      end_use.annual_output_by_system[sys_id] = get_report_variable_data_annual(['EMS'], ep_output_names.select { |name| name.end_with? Constants.ObjectNameFanPumpDisaggregateCool })
      if include_timeseries_end_use_consumptions
        end_use.timeseries_output_by_system[sys_id] = get_report_variable_data_timeseries(['EMS'], ep_output_names.select { |name| name.end_with? Constants.ObjectNameFanPumpDisaggregateCool }, UnitConversions.convert(1.0, 'J', end_use.timeseries_units), 0, timeseries_frequency)
      end

      # Reference Load
      if [Constants.CalcTypeERIReferenceHome, Constants.CalcTypeERIIndexAdjustmentReferenceHome].include? @eri_design
        @loads[LT::Cooling].annual_output_by_system[sys_id] = split_clg_load_to_system_by_fraction(sys_id, @loads[LT::Cooling].annual_output)
      end
    end

    # Mech Vent Preheating (by System)
    outputs[:hpxml_vent_preheat_sys_ids].each do |sys_id|
      ep_output_names = get_ep_output_names_for_vent_preconditioning(sys_id)
      keys = ep_output_names.map(&:upcase)

      @fuels.each do |fuel_type, fuel|
        end_use = @end_uses[[fuel_type, EUT::MechVentPreheat]]
        end_use.annual_output_by_system[sys_id] = get_report_variable_data_annual(keys, end_use.variable_names)
        if include_timeseries_end_use_consumptions
          end_use.timeseries_output_by_system[sys_id] = get_report_variable_data_timeseries(keys, end_use.variable_names, UnitConversions.convert(1.0, 'J', end_use.timeseries_units), 0, timeseries_frequency)
        end
      end
    end

    # Mech Vent Precooling (by System)
    outputs[:hpxml_vent_precool_sys_ids].each do |sys_id|
      ep_output_names = get_ep_output_names_for_vent_preconditioning(sys_id)
      keys = ep_output_names.map(&:upcase)

      end_use = @end_uses[[FT::Elec, EUT::MechVentPrecool]]
      end_use.annual_output_by_system[sys_id] = get_report_variable_data_annual(keys, end_use.variable_names)
      if include_timeseries_end_use_consumptions
        end_use.timeseries_output_by_system[sys_id] = get_report_variable_data_timeseries(keys, end_use.variable_names, UnitConversions.convert(1.0, 'J', end_use.timeseries_units), 0, timeseries_frequency)
      end
    end

    # Dehumidifier
    end_use = @end_uses[[FT::Elec, EUT::Dehumidifier]]
    ep_output_name = @hvac_map[outputs[:hpxml_dehumidifier_id]]
    if not ep_output_name.nil?
      keys = ep_output_name.map(&:upcase)
      end_use.annual_output = get_report_variable_data_annual(keys, end_use.variable_names)
      if include_timeseries_end_use_consumptions
        end_use.timeseries_output = get_report_variable_data_timeseries(keys, end_use.variable_names, UnitConversions.convert(1.0, 'J', end_use.timeseries_units), 0, timeseries_frequency)
      end
    else
      end_use.annual_output = 0
      end_use.timeseries_output = [0.0] * @timestamps.size
    end

    # Water Heating (by System)
    solar_keys = []
    dsh_keys = []
    outputs[:hpxml_dhw_sys_ids].each do |sys_id|
      ep_output_names = get_ep_output_names_for_water_heating(sys_id)
      keys = ep_output_names.map(&:upcase)

      # End Use
      @fuels.each do |fuel_type, fuel|
        [EUT::HotWater, EUT::HotWaterRecircPump, EUT::HotWaterSolarThermalPump].each do |end_use_type|
          end_use = @end_uses[[fuel_type, end_use_type]]
          next if end_use.nil?

          end_use.annual_output_by_system[sys_id] = get_report_variable_data_annual(keys, end_use.variable_names)
          if include_timeseries_end_use_consumptions
            end_use.timeseries_output_by_system[sys_id] = get_report_variable_data_timeseries(keys, end_use.variable_names, UnitConversions.convert(1.0, 'J', end_use.timeseries_units), 0, timeseries_frequency)
          end
        end
      end

      # Loads
      load = @loads[LT::HotWaterDelivered]
      load.annual_output_by_system[sys_id] = get_report_variable_data_annual(keys, load.variable_names)
      if include_timeseries_total_loads
        load.timeseries_output_by_system[sys_id] = get_report_variable_data_timeseries(keys, load.variable_names, UnitConversions.convert(1.0, 'J', load.timeseries_units), 0, timeseries_frequency)
      end

      # Combi boiler water system
      hvac_id = get_combi_hvac_id(sys_id)
      if not hvac_id.nil?
        @fuels.keys.reverse.each do |fuel_type| # Reverse so that FT::Elec is considered last
          htg_end_use = @end_uses[[fuel_type, EUT::Heating]]
          next unless htg_end_use.annual_output_by_system[hvac_id] > 0

          hw_end_use = @end_uses[[fuel_type, EUT::HotWater]]
          fuel = @fuels[fuel_type]

          combi_hw_vars = ep_output_names.select { |name| name.include? Constants.ObjectNameCombiWaterHeatingEnergy(nil) }

          hw_energy = get_report_variable_data_annual(['EMS'], combi_hw_vars)
          hw_end_use.annual_output_by_system[sys_id] += hw_energy
          htg_end_use.annual_output_by_system[hvac_id] -= hw_energy
          if include_timeseries_end_use_consumptions
            hw_energy_timeseries = get_report_variable_data_timeseries(['EMS'], combi_hw_vars, UnitConversions.convert(1.0, 'J', hw_end_use.timeseries_units), 0, timeseries_frequency)
            hw_end_use.timeseries_output_by_system[sys_id] = hw_end_use.timeseries_output_by_system[sys_id].zip(hw_energy_timeseries).map { |x, y| x + y }
            htg_end_use.timeseries_output_by_system[hvac_id] = htg_end_use.timeseries_output_by_system[hvac_id].zip(hw_energy_timeseries).map { |x, y| x - y }
          end
          break # only apply once
        end
      end

      # Adjust water heater/appliances energy consumptions
      @fuels.keys.reverse.each do |fuel_type| # Reverse so that FT::Elec is considered last
        end_use = @end_uses[[fuel_type, EUT::HotWater]]
        next if end_use.nil?
        next if end_use.variables.nil?
        next unless end_use.annual_output_by_system[sys_id] > 0

        ec_vars = ep_output_names.select { |name| name.include? Constants.ObjectNameWaterHeaterAdjustment(nil) }

        ec_adj = get_report_variable_data_annual(['EMS'], ec_vars)
        break if ec_adj == 0 # No adjustment

        end_use.annual_output_by_system[sys_id] += ec_adj
        if include_timeseries_end_use_consumptions
          ec_adj_timeseries = get_report_variable_data_timeseries(['EMS'], ec_vars, UnitConversions.convert(1.0, 'J', end_use.timeseries_units), 0, timeseries_frequency)
          end_use.timeseries_output_by_system[sys_id] = end_use.timeseries_output_by_system[sys_id].zip(ec_adj_timeseries).map { |x, y| x + y }
        end
        break # only apply once
      end

      # Can only be one solar thermal system
      if solar_keys.empty?
        solar_keys = ep_output_names.select { |name| name.include? Constants.ObjectNameSolarHotWater }.map(&:upcase)
      end
      dsh_keys << ep_output_names.select { |name| name.include? Constants.ObjectNameDesuperheater(nil) }.map(&:upcase)
    end

    # Apply Heating/Cooling DSEs
    outputs[:hpxml_heat_sys_ids].each do |sys_id|
      @fuels.each do |fuel_type, fuel|
        [EUT::Heating, EUT::HeatingFanPump].each do |end_use_type|
          end_use = @end_uses[[fuel_type, end_use_type]]
          next if end_use.nil?

          apply_multiplier_to_output(end_use, fuel, sys_id, 1.0 / outputs[:hpxml_dse_heats][sys_id])
        end
      end
    end
    outputs[:hpxml_cool_sys_ids].each do |sys_id|
      @fuels.each do |fuel_type, fuel|
        [EUT::Cooling, EUT::CoolingFanPump].each do |end_use_type|
          end_use = @end_uses[[fuel_type, end_use_type]]
          next if end_use.nil?

          apply_multiplier_to_output(end_use, fuel, sys_id, 1.0 / outputs[:hpxml_dse_cools][sys_id])
        end
      end
    end

    # Hot Water Load - Solar Thermal
    @loads[LT::HotWaterSolarThermal].annual_output = get_report_variable_data_annual(solar_keys, get_all_variable_keys(OutputVars.WaterHeaterLoadSolarThermal))
    @loads[LT::HotWaterSolarThermal].annual_output *= -1 if @loads[LT::HotWaterSolarThermal].annual_output != 0

    # Hot Water Load - Desuperheater
    @loads[LT::HotWaterDesuperheater].annual_output = get_report_variable_data_annual(dsh_keys, @loads[LT::HotWaterDesuperheater].variable_names)

    # Hot Water Load - Tank Losses (excluding solar storage tank)
    @loads[LT::HotWaterTankLosses].annual_output = get_report_variable_data_annual(solar_keys, ['Water Heater Heat Loss Energy'], not_key: true)
    @loads[LT::HotWaterTankLosses].annual_output *= -1.0 if @loads[LT::HotWaterTankLosses].annual_output < 0

    # Apply solar fraction to load for simple solar water heating systems
    outputs[:hpxml_dhw_sys_ids].each do |sys_id|
      solar_fraction = get_dhw_solar_fraction(sys_id)
      if solar_fraction > 0
        apply_multiplier_to_output(@loads[LT::HotWaterDelivered], @loads[LT::HotWaterSolarThermal], sys_id, 1.0 / (1.0 - solar_fraction))
      end
    end

    # Calculate aggregated values from per-system values as needed
    (@end_uses.values + @loads.values).each do |obj|
      if obj.annual_output.nil?
        if not obj.annual_output_by_system.empty?
          obj.annual_output = obj.annual_output_by_system.values.sum(0.0)
        else
          obj.annual_output = 0.0
        end
      end
      next unless obj.timeseries_output.empty? && (not obj.timeseries_output_by_system.empty?)

      obj.timeseries_output = obj.timeseries_output_by_system.values[0]
      obj.timeseries_output_by_system.values[1..-1].each do |values|
        obj.timeseries_output = obj.timeseries_output.zip(values).map { |x, y| x + y }
      end
    end

    # Get zone temperatures
    if include_timeseries_zone_temperatures
      zone_names = []
      scheduled_temperature_names = []
      @model.getThermalZones.each do |zone|
        if zone.floorArea > 1
          zone_names << zone.name.to_s.upcase
        end
      end
      @model.getScheduleConstants.each do |schedule|
        next unless [HPXML::LocationOtherHeatedSpace, HPXML::LocationOtherMultifamilyBufferSpace, HPXML::LocationOtherNonFreezingSpace,
                     HPXML::LocationOtherHousingUnit, HPXML::LocationExteriorWall, HPXML::LocationUnderSlab].include? schedule.name.to_s

        scheduled_temperature_names << schedule.name.to_s.upcase
      end
      zone_names.sort.each do |zone_name|
        @zone_temps[zone_name] = ZoneTemp.new
        @zone_temps[zone_name].name = "Temperature: #{zone_name.split.map(&:capitalize).join(' ')}"
        @zone_temps[zone_name].timeseries_units = 'F'
        @zone_temps[zone_name].timeseries_output = get_report_variable_data_timeseries([zone_name], ['Zone Mean Air Temperature'], 9.0 / 5.0, 32.0, timeseries_frequency)
      end
      scheduled_temperature_names.sort.each do |scheduled_temperature_name|
        @zone_temps[scheduled_temperature_name] = ZoneTemp.new
        @zone_temps[scheduled_temperature_name].name = "Temperature: #{scheduled_temperature_name.split.map(&:capitalize).join(' ')}"
        @zone_temps[scheduled_temperature_name].timeseries_units = 'F'
        @zone_temps[scheduled_temperature_name].timeseries_output = get_report_variable_data_timeseries([scheduled_temperature_name], ['Schedule Value'], 9.0 / 5.0, 32.0, timeseries_frequency)
      end
    end

    if include_timeseries_airflows
      @airflows.each do |airflow_type, airflow|
        airflow.timeseries_output = get_report_variable_data_timeseries(['EMS'], airflow.ems_variables.map { |var| "#{var}_timeseries_outvar" }, UnitConversions.convert(1.0, 'm^3/s', 'cfm'), 0, timeseries_frequency, true)
      end
    end

    if include_timeseries_weather
      @weather.each do |weather_type, weather_data|
        if weather_data.timeseries_units == 'F'
          unit_conv = 9.0 / 5.0
          unit_adder = 32.0
        else
          unit_conv = UnitConversions.convert(1.0, weather_data.variable_units, weather_data.timeseries_units)
          unit_adder = 0
        end
        weather_data.timeseries_output = get_report_variable_data_timeseries(['Environment'], [weather_data.variable], unit_conv, unit_adder, timeseries_frequency)
      end
    end

    return outputs
  end

  def check_for_errors(runner, outputs)
    all_total = @fuels.values.map { |x| x.annual_output }.sum(0.0)
    all_total += @unmet_loads.values.map { |x| x.annual_output }.sum(0.0)
    all_total += @ideal_system_loads.values.map { |x| x.annual_output }.sum(0.0)
    if all_total == 0
      runner.registerError('Simulation unsuccessful.')
      return false
    end

    # Check sum of electricity produced end use outputs match total
    sum_elec_produced = -1 * (@end_uses[[FT::Elec, EUT::PV]].annual_output + @end_uses[[FT::Elec, EUT::Generator]].annual_output)
    total_elec_produced = outputs[:total_elec_produced]
    if (sum_elec_produced - total_elec_produced).abs > 0.1
      runner.registerError("#{FT::Elec} produced category end uses (#{sum_elec_produced}) do not sum to total (#{total_elec_produced}).")
      return false
    end

    # Check sum of end use outputs match fuel outputs
    @fuels.keys.each do |fuel_type|
      sum_categories = @end_uses.select { |k, eu| k[0] == fuel_type }.map { |k, eu| eu.annual_output }.sum(0.0)
      fuel_total = @fuels[fuel_type].annual_output
      if fuel_type == FT::Elec
        fuel_total -= sum_elec_produced
      end
      if (fuel_total - sum_categories).abs > 0.1
        runner.registerError("#{fuel_type} category end uses (#{sum_categories}) do not sum to total (#{fuel_total}).")
        return false
      end
    end

    # Check sum of timeseries outputs match annual outputs
    { @end_uses => 'End Use',
      @fuels => 'Fuel',
      @loads => 'Load',
      @component_loads => 'Component Load',
      @unmet_loads => 'Unmet Load' }.each do |outputs, output_type|
      outputs.each do |key, obj|
        next if obj.timeseries_output.empty?

        sum_timeseries = UnitConversions.convert(obj.timeseries_output.sum(0.0), obj.timeseries_units, obj.annual_units)
        annual_total = obj.annual_output
        if (annual_total - sum_timeseries).abs > 0.1
          runner.registerError("Timeseries outputs (#{sum_timeseries}) do not sum to annual output (#{annual_total}) for #{output_type}: #{key}.")
          return false
        end
      end
    end

    return true
  end

  def write_annual_output_results(runner, outputs, output_format, annual_output_path)
    line_break = nil
    elec_pv_produced = @end_uses[[FT::Elec, EUT::PV]]
    elec_generator_produced = @end_uses[[FT::Elec, EUT::Generator]]

    results_out = []
    @fuels.each do |fuel_type, fuel|
      results_out << ["#{fuel.name} (#{fuel.annual_units})", fuel.annual_output.round(2)]
      if fuel_type == FT::Elec
        results_out << ['Fuel Use: Electricity: Net (MBtu)', (fuel.annual_output + elec_pv_produced.annual_output + elec_generator_produced.annual_output).round(2)]
      end
    end
    results_out << [line_break]
    @end_uses.each do |key, end_use|
      results_out << ["#{end_use.name} (#{end_use.annual_units})", end_use.annual_output.round(2)]
    end
    results_out << [line_break]
    @loads.each do |load_type, load|
      results_out << ["#{load.name} (#{load.annual_units})", load.annual_output.round(2)]
    end
    results_out << [line_break]
    @unmet_loads.each do |load_type, unmet_load|
      results_out << ["#{unmet_load.name} (#{unmet_load.annual_units})", unmet_load.annual_output.round(2)]
    end
    results_out << [line_break]
    @peak_fuels.each do |key, peak_fuel|
      results_out << ["#{peak_fuel.name} (#{peak_fuel.annual_units})", peak_fuel.annual_output.round(0)]
    end
    results_out << [line_break]
    @peak_loads.each do |load_type, peak_load|
      results_out << ["#{peak_load.name} (#{peak_load.annual_units})", peak_load.annual_output.round(2)]
    end
    if @component_loads.values.map { |load| load.annual_output }.sum != 0 # Skip if component loads not calculated
      results_out << [line_break]
      @component_loads.each do |load_type, load|
        results_out << ["#{load.name} (#{load.annual_units})", load.annual_output.round(2)]
      end
    end
    results_out << [line_break]
    @hot_water_uses.each do |hot_water_type, hot_water|
      results_out << ["#{hot_water.name} (#{hot_water.annual_units})", hot_water.annual_output.round(0)]
    end

    if output_format == 'csv'
      CSV.open(annual_output_path, 'wb') { |csv| results_out.to_a.each { |elem| csv << elem } }
    elsif output_format == 'json'
      h = {}
      results_out.each do |out|
        next if out == [line_break]

        grp, name = out[0].split(':', 2)
        h[grp] = {} if h[grp].nil?
        h[grp][name.strip] = out[1]
      end

      require 'json'
      File.open(annual_output_path, 'w') { |json| json.write(JSON.pretty_generate(h)) }
    end
    runner.registerInfo("Wrote annual output results to #{annual_output_path}.")
  end

  def report_sim_outputs(runner)
    all_outputs = []
    all_outputs << @fuels
    all_outputs << @end_uses
    all_outputs << @loads
    all_outputs << @unmet_loads
    all_outputs << @peak_fuels
    all_outputs << @peak_loads
    if @component_loads.values.map { |load| load.annual_output }.sum != 0 # Skip if component loads not calculated
      all_outputs << @component_loads
    end
    all_outputs << @hot_water_uses

    all_outputs.each do |outputs|
      outputs.each do |key, obj|
        output_name = get_runner_output_name(obj)
        output_val = obj.annual_output.round(2)
        runner.registerValue(output_name, output_val)
        runner.registerInfo("Registering #{output_val} for #{output_name}.")
        next unless key == FT::Elec && obj.is_a?(Fuel)

        # Also add Net Electricity
        elec_total = @fuels[FT::Elec]
        elec_pv_produced = @end_uses[[FT::Elec, EUT::PV]]
        elec_generator_produced = @end_uses[[FT::Elec, EUT::Generator]]
        output_name = 'Fuel Use: Electricity: Net (MBtu)'
        output_val = (elec_total.annual_output + elec_pv_produced.annual_output + elec_generator_produced.annual_output).round(2)
        runner.registerValue(output_name, output_val)
        runner.registerInfo("Registering #{output_val} for #{output_name}.")
      end
    end
  end

  def get_runner_output_name(obj)
    return "#{obj.name} #{obj.annual_units}"
  end

  def write_eri_output_results(outputs, csv_path)
    return true if csv_path.nil?

    line_break = nil

    def sanitize_string(s)
      [' ', ':', '/'].each do |c|
        next unless s.include? c

        s = s.gsub(c, '')
      end
      return s
    end

    def ordered_values(hash, sys_ids)
      vals = []
      sys_ids.each do |sys_id|
        vals << hash[sys_id]
        fail 'Could not look up data.' if vals[-1].nil?
      end
      return vals
    end

    def get_sys_ids(type, heat_sys_ids, cool_sys_ids, dhw_sys_ids, vent_preheat_sys_ids, vent_precool_sys_ids)
      if type.downcase.include? 'hot water'
        return dhw_sys_ids
      elsif type.downcase.include? 'mech vent preheating'
        return vent_preheat_sys_ids
      elsif type.downcase.include? 'mech vent precooling'
        return vent_precool_sys_ids
      elsif type.downcase.include? 'heating'
        return heat_sys_ids
      elsif type.downcase.include? 'cooling'
        return cool_sys_ids
      end

      fail "Unhandled type: '#{type}'."
    end

    results_out = []

    heat_sys_ids = outputs[:hpxml_heat_sys_ids]
    cool_sys_ids = outputs[:hpxml_cool_sys_ids]
    dhw_sys_ids = outputs[:hpxml_dhw_sys_ids]
    vent_preheat_sys_ids = outputs[:hpxml_vent_preheat_sys_ids]
    vent_precool_sys_ids = outputs[:hpxml_vent_precool_sys_ids]

    # Sys IDS
    results_out << ['hpxml_heat_sys_ids', heat_sys_ids.to_s]
    results_out << ['hpxml_cool_sys_ids', cool_sys_ids.to_s]
    results_out << ['hpxml_dhw_sys_ids', dhw_sys_ids.to_s]
    results_out << ['hpxml_vent_preheat_sys_ids', vent_preheat_sys_ids.to_s]
    results_out << ['hpxml_vent_precool_sys_ids', vent_precool_sys_ids.to_s]
    results_out << [line_break]

    # EECs
    results_out << ['hpxml_eec_heats', ordered_values(outputs[:hpxml_eec_heats], heat_sys_ids).to_s]
    results_out << ['hpxml_eec_cools', ordered_values(outputs[:hpxml_eec_cools], cool_sys_ids).to_s]
    results_out << ['hpxml_eec_dhws', ordered_values(outputs[:hpxml_eec_dhws], dhw_sys_ids).to_s]
    results_out << ['hpxml_eec_vent_preheats', ordered_values(outputs[:hpxml_eec_vent_preheats], vent_preheat_sys_ids).to_s]
    results_out << ['hpxml_eec_vent_precools', ordered_values(outputs[:hpxml_eec_vent_precools], vent_precool_sys_ids).to_s]
    results_out << [line_break]

    # Fuel types
    results_out << ['hpxml_heat_fuels', ordered_values(outputs[:hpxml_heat_fuels], heat_sys_ids).to_s]
    results_out << ['hpxml_dwh_fuels', ordered_values(outputs[:hpxml_dwh_fuels], dhw_sys_ids).to_s]
    results_out << ['hpxml_vent_preheat_fuels', ordered_values(outputs[:hpxml_vent_preheat_fuels], vent_preheat_sys_ids).to_s]
    results_out << [line_break]

    # Fuel uses
    @fuels.each do |fuel_type, fuel|
      key_name = sanitize_string("fuel#{fuel_type}")
      results_out << [key_name, fuel.annual_output.to_s]
    end
    results_out << [line_break]

    # End Uses
    @end_uses.each do |key, end_use|
      fuel_type, end_use_type = key
      key_name = sanitize_string("enduse#{fuel_type}#{end_use_type}")
      if not end_use.annual_output_by_system.empty?
        sys_ids = get_sys_ids(end_use_type, heat_sys_ids, cool_sys_ids, dhw_sys_ids, vent_preheat_sys_ids, vent_precool_sys_ids)
        results_out << [key_name, ordered_values(end_use.annual_output_by_system, sys_ids).to_s]
      else
        results_out << [key_name, end_use.annual_output.to_s]
      end
    end
    results_out << [line_break]

    # Loads by System
    @loads.each do |load_type, load|
      key_name = sanitize_string("load#{load_type}")
      if not load.annual_output_by_system.empty?
        sys_ids = get_sys_ids(load_type, heat_sys_ids, cool_sys_ids, dhw_sys_ids, vent_preheat_sys_ids, vent_precool_sys_ids)
        results_out << [key_name, ordered_values(load.annual_output_by_system, sys_ids).to_s]
      end
    end
    results_out << [line_break]

    # Misc
    results_out << ['hpxml_cfa', outputs[:hpxml_cfa].to_s]
    results_out << ['hpxml_nbr', outputs[:hpxml_nbr].to_s]
    results_out << ['hpxml_nst', outputs[:hpxml_nst].to_s]
    results_out << ['hpxml_residential_facility_type', '"' + outputs[:hpxml_residential_facility_type] + '"']

    CSV.open(csv_path, 'wb') { |csv| results_out.to_a.each { |elem| csv << elem } }
  end

  def write_timeseries_output_results(runner, output_format,
                                      timeseries_output_path,
                                      timeseries_frequency,
                                      include_timeseries_fuel_consumptions,
                                      include_timeseries_end_use_consumptions,
                                      include_timeseries_hot_water_uses,
                                      include_timeseries_total_loads,
                                      include_timeseries_component_loads,
                                      include_timeseries_unmet_loads,
                                      include_timeseries_zone_temperatures,
                                      include_timeseries_airflows,
                                      include_timeseries_weather)
    return if timeseries_frequency == 'none'

    # Time column
    if ['timestep', 'hourly', 'daily', 'monthly'].include? timeseries_frequency
      data = ['Time', nil]
    else
      fail "Unexpected timeseries_frequency: #{timeseries_frequency}."
    end
    @timestamps.each do |timestamp|
      data << timestamp
    end

    if include_timeseries_fuel_consumptions
      fuel_data = @fuels.values.select { |x| !x.timeseries_output.empty? }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(2) } }
    else
      fuel_data = []
    end
    if include_timeseries_end_use_consumptions
      end_use_data = @end_uses.values.select { |x| !x.timeseries_output.empty? }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(2) } }
    else
      end_use_data = []
    end
    if include_timeseries_hot_water_uses
      hot_water_use_data = @hot_water_uses.values.select { |x| !x.timeseries_output.empty? }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(2) } }
    else
      hot_water_use_data = []
    end
    if include_timeseries_total_loads
      total_loads_data = @loads.values.select { |x| !x.timeseries_output.empty? }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(2) } }
    else
      total_loads_data = {}
    end
    if include_timeseries_component_loads
      comp_loads_data = @component_loads.values.select { |x| !x.timeseries_output.empty? }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(2) } }
    else
      comp_loads_data = []
    end
    if include_timeseries_unmet_loads
      unmet_loads_data = @unmet_loads.values.select { |x| !x.timeseries_output.empty? }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(2) } }
    else
      unmet_loads_data = []
    end
    if include_timeseries_zone_temperatures
      zone_temps_data = @zone_temps.values.select { |x| !x.timeseries_output.empty? }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(2) } }
    else
      zone_temps_data = []
    end
    if include_timeseries_airflows
      airflows_data = @airflows.values.select { |x| !x.timeseries_output.empty? }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(2) } }
    else
      airflows_data = []
    end
    if include_timeseries_weather
      weather_data = @weather.values.select { |x| !x.timeseries_output.empty? }.map { |x| [x.name, x.timeseries_units] + x.timeseries_output.map { |v| v.round(2) } }
    else
      weather_data = []
    end

    return if fuel_data.size + end_use_data.size + hot_water_use_data.size + total_loads_data.size + comp_loads_data.size + unmet_loads_data.size + zone_temps_data.size + airflows_data.size + weather_data.size == 0

    fail 'Unable to obtain timestamps.' if @timestamps.empty?

    if output_format == 'csv'
      # Assemble data
      data = data.zip(*fuel_data, *end_use_data, *hot_water_use_data, *total_loads_data, *comp_loads_data, *unmet_loads_data, *zone_temps_data, *airflows_data, *weather_data)

      # Error-check
      n_elements = []
      data.each do |data_array|
        n_elements << data_array.size
      end
      if n_elements.uniq.size > 1
        fail "Inconsistent number of array elements: #{n_elements.uniq}."
      end

      # Write file
      CSV.open(timeseries_output_path, 'wb') { |csv| data.to_a.each { |elem| csv << elem } }
    elsif output_format == 'json'
      # Assemble data
      h = {}
      h['Time'] = data[2..-1]
      [fuel_data, end_use_data, hot_water_use_data, total_loads_data, comp_loads_data, unmet_loads_data, zone_temps_data, airflows_data, weather_data].each do |d|
        d.each do |o|
          grp, name = o[0].split(':', 2)
          h[grp] = {} if h[grp].nil?
          h[grp]["#{name.strip} (#{o[1]})"] = o[2..-1]
        end
      end

      # Write file
      require 'json'
      File.open(timeseries_output_path, 'w') { |json| json.write(JSON.pretty_generate(h)) }
    end
    runner.registerInfo("Wrote timeseries output results to #{timeseries_output_path}.")
  end

  def get_hpxml_dse_heats(heat_sys_ids)
    dse_heats = {}

    heat_sys_ids.each do |sys_id|
      dse_heats[sys_id] = 1.0 # Init
    end

    @hpxml.hvac_distributions.each do |hvac_dist|
      dist_id = hvac_dist.id
      next if hvac_dist.annual_heating_dse.nil?

      dse_heat = hvac_dist.annual_heating_dse

      # Get all HVAC systems attached to it
      @hpxml.heating_systems.each do |htg_system|
        next unless htg_system.fraction_heat_load_served > 0
        next if htg_system.distribution_system_idref.nil?
        next unless dist_id == htg_system.distribution_system_idref

        sys_id = get_system_or_seed_id(htg_system)
        dse_heats[sys_id] = dse_heat
      end
      @hpxml.heat_pumps.each do |heat_pump|
        next unless heat_pump.fraction_heat_load_served > 0
        next if heat_pump.distribution_system_idref.nil?
        next unless dist_id == heat_pump.distribution_system_idref

        sys_id = get_system_or_seed_id(heat_pump)
        dse_heats[sys_id] = dse_heat

        if is_dfhp(heat_pump)
          # Also apply to dual-fuel heat pump backup system
          dse_heats[dfhp_backup_sys_id(sys_id)] = dse_heat
        end
      end
    end

    return dse_heats
  end

  def get_hpxml_dse_cools(cool_sys_ids)
    dse_cools = {}

    # Init
    cool_sys_ids.each do |sys_id|
      dse_cools[sys_id] = 1.0
    end

    @hpxml.hvac_distributions.each do |hvac_dist|
      dist_id = hvac_dist.id
      next if hvac_dist.annual_cooling_dse.nil?

      dse_cool = hvac_dist.annual_cooling_dse

      # Get all HVAC systems attached to it
      @hpxml.cooling_systems.each do |clg_system|
        next unless clg_system.fraction_cool_load_served > 0
        next if clg_system.distribution_system_idref.nil?
        next unless dist_id == clg_system.distribution_system_idref

        sys_id = get_system_or_seed_id(clg_system)
        dse_cools[sys_id] = dse_cool
      end
      @hpxml.heat_pumps.each do |heat_pump|
        next unless heat_pump.fraction_cool_load_served > 0
        next if heat_pump.distribution_system_idref.nil?
        next unless dist_id == heat_pump.distribution_system_idref

        sys_id = get_system_or_seed_id(heat_pump)
        dse_cools[sys_id] = dse_cool
      end
    end

    return dse_cools
  end

  def get_hpxml_heat_fuels()
    heat_fuels = {}

    @hpxml.heating_systems.each do |htg_system|
      next unless htg_system.fraction_heat_load_served > 0

      sys_id = get_system_or_seed_id(htg_system)
      heat_fuels[sys_id] = htg_system.heating_system_fuel
    end
    @hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.fraction_heat_load_served > 0

      sys_id = get_system_or_seed_id(heat_pump)
      heat_fuels[sys_id] = heat_pump.heat_pump_fuel
      if is_dfhp(heat_pump)
        heat_fuels[dfhp_backup_sys_id(sys_id)] = heat_pump.backup_heating_fuel
      end
    end

    return heat_fuels
  end

  def get_hpxml_dhw_fuels()
    dhw_fuels = {}

    @hpxml.water_heating_systems.each do |dhw_system|
      sys_id = dhw_system.id
      if [HPXML::WaterHeaterTypeCombiTankless, HPXML::WaterHeaterTypeCombiStorage].include? dhw_system.water_heater_type
        @hpxml.heating_systems.each do |heating_system|
          next unless dhw_system.related_hvac_idref == heating_system.id

          dhw_fuels[sys_id] = heating_system.heating_system_fuel
        end
      else
        dhw_fuels[sys_id] = dhw_system.fuel_type
      end
    end

    return dhw_fuels
  end

  def get_hpxml_vent_preheat_fuels()
    vent_preheat_fuels = {}

    @hpxml.ventilation_fans.each do |vent_fan|
      next unless vent_fan.used_for_whole_building_ventilation
      next if vent_fan.preheating_fuel.nil?

      sys_id = "#{vent_fan.id}_preheat"
      vent_preheat_fuels[sys_id] = vent_fan.preheating_fuel
    end

    return vent_preheat_fuels
  end

  def get_hpxml_heat_sys_ids()
    sys_ids = []

    @hpxml.heating_systems.each do |htg_system|
      next unless htg_system.fraction_heat_load_served > 0

      sys_ids << get_system_or_seed_id(htg_system)
    end
    @hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.fraction_heat_load_served > 0

      sys_ids << get_system_or_seed_id(heat_pump)
      if is_dfhp(heat_pump)
        sys_ids << dfhp_backup_sys_id(sys_ids[-1])
      end
    end

    return sys_ids
  end

  def get_hpxml_cool_sys_ids()
    sys_ids = []

    @hpxml.cooling_systems.each do |clg_system|
      next unless clg_system.fraction_cool_load_served > 0

      sys_ids << get_system_or_seed_id(clg_system)
    end
    @hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.fraction_cool_load_served > 0

      sys_ids << get_system_or_seed_id(heat_pump)
    end

    return sys_ids
  end

  def get_hpxml_vent_preheat_sys_ids()
    sys_ids = []

    @hpxml.ventilation_fans.each do |vent_fan|
      next unless vent_fan.used_for_whole_building_ventilation
      next if vent_fan.preheating_fuel.nil?

      sys_ids << "#{vent_fan.id}_preheat"
    end

    return sys_ids
  end

  def get_hpxml_vent_precool_sys_ids()
    sys_ids = []

    @hpxml.ventilation_fans.each do |vent_fan|
      next unless vent_fan.used_for_whole_building_ventilation
      next if vent_fan.precooling_fuel.nil?

      sys_ids << "#{vent_fan.id}_precool"
    end

    return sys_ids
  end

  def get_hpxml_dhw_sys_ids()
    sys_ids = []

    @hpxml.water_heating_systems.each do |dhw_system|
      sys_ids << dhw_system.id
    end

    return sys_ids
  end

  def get_hpxml_eec_heats()
    eec_heats = {}

    @hpxml.heating_systems.each do |htg_system|
      next unless htg_system.fraction_heat_load_served > 0

      sys_id = get_system_or_seed_id(htg_system)
      if not htg_system.heating_efficiency_afue.nil?
        eec_heats[sys_id] = get_eri_eec_value_numerator('AFUE') / htg_system.heating_efficiency_afue
      elsif not htg_system.heating_efficiency_percent.nil?
        eec_heats[sys_id] = get_eri_eec_value_numerator('Percent') / htg_system.heating_efficiency_percent
      end
    end
    @hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.fraction_heat_load_served > 0

      sys_id = get_system_or_seed_id(heat_pump)
      if not heat_pump.heating_efficiency_hspf.nil?
        eec_heats[sys_id] = get_eri_eec_value_numerator('HSPF') / heat_pump.heating_efficiency_hspf
      elsif not heat_pump.heating_efficiency_cop.nil?
        eec_heats[sys_id] = get_eri_eec_value_numerator('COP') / heat_pump.heating_efficiency_cop
      end
      if is_dfhp(heat_pump)
        if not heat_pump.backup_heating_efficiency_afue.nil?
          eec_heats[dfhp_backup_sys_id(sys_id)] = get_eri_eec_value_numerator('AFUE') / heat_pump.backup_heating_efficiency_afue
        elsif not heat_pump.backup_heating_efficiency_percent.nil?
          eec_heats[dfhp_backup_sys_id(sys_id)] = get_eri_eec_value_numerator('Percent') / heat_pump.backup_heating_efficiency_percent
        end
      end
    end

    return eec_heats
  end

  def get_hpxml_eec_cools()
    eec_cools = {}

    @hpxml.cooling_systems.each do |clg_system|
      next unless clg_system.fraction_cool_load_served > 0

      sys_id = get_system_or_seed_id(clg_system)
      if not clg_system.cooling_efficiency_seer.nil?
        eec_cools[sys_id] = get_eri_eec_value_numerator('SEER') / clg_system.cooling_efficiency_seer
      elsif not clg_system.cooling_efficiency_eer.nil?
        eec_cools[sys_id] = get_eri_eec_value_numerator('EER') / clg_system.cooling_efficiency_eer
      elsif not clg_system.cooling_efficiency_ceer.nil?
        eec_cools[sys_id] = get_eri_eec_value_numerator('CEER') / clg_system.cooling_efficiency_ceer
      end

      if clg_system.cooling_system_type == HPXML::HVACTypeEvaporativeCooler
        eec_cools[sys_id] = get_eri_eec_value_numerator('SEER') / 15.0 # Arbitrary
      end
    end
    @hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.fraction_cool_load_served > 0

      sys_id = get_system_or_seed_id(heat_pump)
      if not heat_pump.cooling_efficiency_seer.nil?
        eec_cools[sys_id] = get_eri_eec_value_numerator('SEER') / heat_pump.cooling_efficiency_seer
      elsif not heat_pump.cooling_efficiency_eer.nil?
        eec_cools[sys_id] = get_eri_eec_value_numerator('EER') / heat_pump.cooling_efficiency_eer
      end
    end

    return eec_cools
  end

  def get_hpxml_eec_dhws()
    eec_dhws = {}

    @hpxml.water_heating_systems.each do |dhw_system|
      sys_id = dhw_system.id
      value = dhw_system.energy_factor
      value = dhw_system.uniform_energy_factor if value.nil?
      wh_type = dhw_system.water_heater_type
      if wh_type == HPXML::WaterHeaterTypeTankless
        value_adj = dhw_system.performance_adjustment
      else
        value_adj = 1.0
      end

      if value.nil?
        # Get assumed EF for combi system
        @model.getWaterHeaterMixeds.each do |wh|
          next unless @dhw_map[sys_id].include? wh.name.to_s

          value = wh.additionalProperties.getFeatureAsDouble('EnergyFactor').get
        end
      end

      if (not value.nil?) && (not value_adj.nil?)
        eec_dhws[sys_id] = get_eri_eec_value_numerator('EF') / (Float(value) * Float(value_adj))
      end
    end

    return eec_dhws
  end

  def get_hpxml_eec_vent_preheats()
    eec_vent_preheats = {}

    @hpxml.ventilation_fans.each do |vent_fan|
      next unless vent_fan.used_for_whole_building_ventilation
      next if vent_fan.preheating_fuel.nil?

      sys_id = "#{vent_fan.id}_preheat"
      eec_vent_preheats[sys_id] = get_eri_eec_value_numerator('COP') / vent_fan.preheating_efficiency_cop
    end

    return eec_vent_preheats
  end

  def get_hpxml_eec_vent_precools()
    eec_vent_precools = {}

    @hpxml.ventilation_fans.each do |vent_fan|
      next unless vent_fan.used_for_whole_building_ventilation
      next if vent_fan.precooling_fuel.nil?

      sys_id = "#{vent_fan.id}_precool"
      eec_vent_precools[sys_id] = get_eri_eec_value_numerator('COP') / vent_fan.precooling_efficiency_cop
    end

    return eec_vent_precools
  end

  def get_eri_eec_value_numerator(unit)
    if ['HSPF', 'SEER', 'EER', 'CEER'].include? unit
      return 3.413
    elsif ['AFUE', 'COP', 'Percent', 'EF'].include? unit
      return 1.0
    end
  end

  def get_system_or_seed_id(sys)
    if not sys.seed_id.nil?
      return sys.seed_id
    end

    return sys.id
  end

  def get_report_meter_data_annual(meter_names, unit_conv = UnitConversions.convert(1.0, 'J', 'MBtu'))
    vars = "'" + meter_names.join("','") + "'"
    query = "SELECT SUM(VariableValue*#{unit_conv}) FROM ReportMeterData WHERE ReportMeterDataDictionaryIndex IN (SELECT ReportMeterDataDictionaryIndex FROM ReportMeterDataDictionary WHERE VariableName IN (#{vars}) AND ReportingFrequency='Run Period' AND VariableUnits='J')"
    value = @sqlFile.execAndReturnFirstDouble(query)
    fail "Query error: #{query}" unless value.is_initialized

    return value.get
  end

  def get_report_variable_data_annual(key_values, variable_names, unit_conv = UnitConversions.convert(1.0, 'J', 'MBtu'), not_key: false)
    keys = "'" + key_values.join("','") + "'"
    vars = "'" + variable_names.join("','") + "'"
    if not_key
      s_not = 'NOT '
    else
      s_not = ''
    end
    query = "SELECT SUM(VariableValue*#{unit_conv}) FROM ReportVariableData WHERE ReportVariableDataDictionaryIndex IN (SELECT ReportVariableDataDictionaryIndex FROM ReportVariableDataDictionary WHERE KeyValue #{s_not}IN (#{keys}) AND VariableName IN (#{vars}) AND ReportingFrequency='Run Period')"
    value = @sqlFile.execAndReturnFirstDouble(query)
    fail "Query error: #{query}" unless value.is_initialized

    return value.get
  end

  def get_report_meter_data_timeseries(meter_names, unit_conv, unit_adder, timeseries_frequency)
    vars = "'" + meter_names.join("','") + "'"
    query = "SELECT SUM(VariableValue*#{unit_conv}+#{unit_adder}) FROM ReportMeterData WHERE ReportMeterDataDictionaryIndex IN (SELECT ReportMeterDataDictionaryIndex FROM ReportMeterDataDictionary WHERE VariableName IN (#{vars}) AND ReportingFrequency='#{reporting_frequency_map[timeseries_frequency]}' AND VariableUnits='J') GROUP BY TimeIndex ORDER BY TimeIndex"
    values = @sqlFile.execAndReturnVectorOfDouble(query)
    fail "Query error: #{query}" unless values.is_initialized

    values = values.get
    values += [0.0] * @timestamps.size if values.size == 0
    return values
  end

  def get_report_variable_data_timeseries(key_values, variable_names, unit_conv, unit_adder, timeseries_frequency, disable_ems_shift = false)
    keys = "'" + key_values.join("','") + "'"
    vars = "'" + variable_names.join("','") + "'"
    query = "SELECT SUM(VariableValue*#{unit_conv}+#{unit_adder}) FROM ReportVariableData WHERE ReportVariableDataDictionaryIndex IN (SELECT ReportVariableDataDictionaryIndex FROM ReportVariableDataDictionary WHERE KeyValue IN (#{keys}) AND VariableName IN (#{vars}) AND ReportingFrequency='#{reporting_frequency_map[timeseries_frequency]}') GROUP BY TimeIndex ORDER BY TimeIndex"
    values = @sqlFile.execAndReturnVectorOfDouble(query)
    fail "Query error: #{query}" unless values.is_initialized

    values = values.get
    values += [0.0] * @timestamps.size if values.size == 0

    return values if disable_ems_shift

    if (key_values.size == 1) && (key_values[0] == 'EMS') && (@timestamps.size > 0)
      if (timeseries_frequency.downcase == 'timestep' || (timeseries_frequency.downcase == 'hourly' && @model.getTimestep.numberOfTimestepsPerHour == 1))
        # Shift all values by 1 timestep due to EMS reporting lag
        return values[1..-1] + [values[-1]]
      end
    end

    return values
  end

  def get_tabular_data_value(report_name, report_for_string, table_name, row_names, col_name, units)
    rows = "'" + row_names.join("','") + "'"
    query = "SELECT SUM(Value) FROM TabularDataWithStrings WHERE ReportName='#{report_name}' AND ReportForString='#{report_for_string}' AND TableName='#{table_name}' AND RowName IN (#{rows}) AND ColumnName='#{col_name}' AND Units='#{units}'"
    result = @sqlFile.execAndReturnFirstDouble(query)
    return result.get
  end

  def apply_multiplier_to_output(obj, sync_obj, sys_id, mult)
    # Annual
    orig_value = obj.annual_output_by_system[sys_id]
    obj.annual_output_by_system[sys_id] = orig_value * mult
    sync_obj.annual_output += (orig_value * mult - orig_value)

    # Timeseries
    if not obj.timeseries_output_by_system.empty?
      orig_values = obj.timeseries_output_by_system[sys_id]
      obj.timeseries_output_by_system[sys_id] = obj.timeseries_output_by_system[sys_id].map { |x| x * mult }
      diffs = obj.timeseries_output_by_system[sys_id].zip(orig_values).map { |x, y| x - y }
      sync_obj.timeseries_output = sync_obj.timeseries_output.zip(diffs).map { |x, y| x + y }
    end
  end

  def get_combi_hvac_id(sys_id)
    @hpxml.water_heating_systems.each do |dhw_system|
      next unless sys_id == dhw_system.id
      next unless [HPXML::WaterHeaterTypeCombiTankless, HPXML::WaterHeaterTypeCombiStorage].include? dhw_system.water_heater_type

      return dhw_system.related_hvac_idref
    end

    return
  end

  def get_combi_water_system_ec(hx_load, htg_load, htg_energy)
    water_sys_frac = hx_load / htg_load
    return htg_energy * water_sys_frac
  end

  def get_dfhp_loads(outputs)
    dfhp_loads = {}
    outputs[:hpxml_heat_sys_ids].each do |sys_id|
      ep_output_names, dfhp_primary, dfhp_backup = get_ep_output_names_for_hvac_heating(sys_id)
      keys = ep_output_names.map(&:upcase)
      next unless dfhp_primary || dfhp_backup

      if dfhp_primary
        vars = get_all_variable_keys(OutputVars.SpaceHeatingDFHPPrimaryLoad)
      else
        vars = get_all_variable_keys(OutputVars.SpaceHeatingDFHPBackupLoad)
        sys_id = dfhp_primary_sys_id(sys_id)
      end
      dfhp_loads[[sys_id, dfhp_primary]] = get_report_variable_data_annual(keys, vars)
    end
    return dfhp_loads
  end

  def split_htg_load_to_system_by_fraction(sys_id, bldg_load, dfhp_loads)
    @hpxml.heating_systems.each do |htg_system|
      next unless htg_system.fraction_heat_load_served > 0
      next unless get_system_or_seed_id(htg_system) == sys_id

      return bldg_load * htg_system.fraction_heat_load_served
    end
    @hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.fraction_heat_load_served > 0

      load_fraction = 1.0
      if is_dfhp(heat_pump)
        if dfhp_primary_sys_id(sys_id) == sys_id
          load_fraction = dfhp_loads[[sys_id, true]] / (dfhp_loads[[sys_id, true]] + dfhp_loads[[sys_id, false]]) unless dfhp_loads[[sys_id, true]].nil?
        else
          sys_id = dfhp_primary_sys_id(sys_id)
          load_fraction = dfhp_loads[[sys_id, false]] / (dfhp_loads[[sys_id, true]] + dfhp_loads[[sys_id, false]]) unless dfhp_loads[[sys_id, true]].nil?
        end
        load_fraction = 1.0 if load_fraction.nan?
      end
      next unless get_system_or_seed_id(heat_pump) == sys_id

      return bldg_load * heat_pump.fraction_heat_load_served * load_fraction
    end
  end

  def split_clg_load_to_system_by_fraction(sys_id, bldg_load)
    @hpxml.cooling_systems.each do |clg_system|
      next unless clg_system.fraction_cool_load_served > 0
      next unless get_system_or_seed_id(clg_system) == sys_id

      return bldg_load * clg_system.fraction_cool_load_served
    end
    @hpxml.heat_pumps.each do |heat_pump|
      next unless heat_pump.fraction_cool_load_served > 0
      next unless get_system_or_seed_id(heat_pump) == sys_id

      return bldg_load * heat_pump.fraction_cool_load_served
    end
  end

  def dfhp_backup_sys_id(primary_sys_id)
    return primary_sys_id + '_dfhp_backup_system'
  end

  def dfhp_primary_sys_id(backup_sys_id)
    return backup_sys_id.gsub('_dfhp_backup_system', '')
  end

  def is_dfhp(system)
    if system.class != HPXML::HeatPump
      return false
    end
    if (not system.backup_heating_switchover_temp.nil?) && (system.backup_heating_fuel != HPXML::FuelTypeElectricity)
      return true
    end

    return false
  end

  def get_dhw_solar_fraction(sys_id)
    solar_fraction = 0.0
    if @hpxml.solar_thermal_systems.size > 0
      solar_thermal_system = @hpxml.solar_thermal_systems[0]
      water_heater_idref = solar_thermal_system.water_heating_system_idref
      if water_heater_idref.nil? || (water_heater_idref == sys_id)
        solar_fraction = solar_thermal_system.solar_fraction.to_f
      end
    end
    return solar_fraction
  end

  def get_ep_output_names_for_hvac_heating(sys_id)
    dfhp_primary = false
    dfhp_backup = false
    (@hpxml.heating_systems + @hpxml.heat_pumps).each do |system|
      # This is super ugly. Can we simplify it?
      if is_dfhp(system)
        if (dfhp_primary_sys_id(sys_id) == sys_id) && [system.seed_id, system.id].include?(sys_id)
          dfhp_primary = true
        elsif [system.seed_id, system.id].include? dfhp_primary_sys_id(sys_id)
          dfhp_backup = true
          sys_id = dfhp_primary_sys_id(sys_id)
        end
      end
      next unless system.seed_id == sys_id

      sys_id = system.id
      break
    end

    fail 'Unexpected result.' if dfhp_primary && dfhp_backup

    output_names = @hvac_map[sys_id].dup

    if dfhp_primary || dfhp_backup
      # Exclude output names associated with primary/backup system as appropriate
      output_names.reverse.each do |o|
        is_backup_obj = (o.include?(Constants.ObjectNameFanPumpDisaggregateBackupHeat) || o.include?(Constants.ObjectNameBackupHeatingCoil))
        if dfhp_primary && is_backup_obj
          output_names.delete(o)
        elsif dfhp_backup && (not is_backup_obj)
          output_names.delete(o)
        end
      end
    end

    return output_names, dfhp_primary, dfhp_backup
  end

  def get_ep_output_names_for_hvac_cooling(sys_id)
    (@hpxml.cooling_systems + @hpxml.heat_pumps).each do |system|
      next unless system.seed_id == sys_id

      sys_id = system.id
      break
    end

    return @hvac_map[sys_id]
  end

  def get_ep_output_names_for_water_heating(sys_id)
    return @dhw_map[sys_id]
  end

  def get_ep_output_names_for_vent_preconditioning(sys_id)
    return @hvac_map[sys_id]
  end

  def get_object_maps()
    # Retrieve HPXML->E+ object name maps
    @hvac_map = eval(@model.getBuilding.additionalProperties.getFeatureAsString('hvac_map').get)
    @dhw_map = eval(@model.getBuilding.additionalProperties.getFeatureAsString('dhw_map').get)
  end

  def add_object_output_variables(timeseries_frequency)
    hvac_output_vars = [OutputVars.SpaceHeating(EPlus::FuelTypeElectricity),
                        OutputVars.SpaceHeating(EPlus::FuelTypeNaturalGas),
                        OutputVars.SpaceHeating(EPlus::FuelTypeOil),
                        OutputVars.SpaceHeating(EPlus::FuelTypePropane),
                        OutputVars.SpaceHeating(EPlus::FuelTypeWoodCord),
                        OutputVars.SpaceHeating(EPlus::FuelTypeWoodPellets),
                        OutputVars.SpaceHeating(EPlus::FuelTypeCoal),
                        OutputVars.SpaceHeatingDFHPPrimaryLoad,
                        OutputVars.SpaceHeatingDFHPBackupLoad,
                        OutputVars.SpaceCoolingElectricity,
                        OutputVars.DehumidifierElectricity,
                        OutputVars.MechVentPreconditioning(EPlus::FuelTypeElectricity),
                        OutputVars.MechVentPreconditioning(EPlus::FuelTypeNaturalGas),
                        OutputVars.MechVentPreconditioning(EPlus::FuelTypeOil),
                        OutputVars.MechVentPreconditioning(EPlus::FuelTypePropane),
                        OutputVars.MechVentPreconditioning(EPlus::FuelTypeWoodCord),
                        OutputVars.MechVentPreconditioning(EPlus::FuelTypeWoodPellets),
                        OutputVars.MechVentPreconditioning(EPlus::FuelTypeCoal)]

    dhw_output_vars = [OutputVars.WaterHeating(EPlus::FuelTypeElectricity),
                       OutputVars.WaterHeating(EPlus::FuelTypeNaturalGas),
                       OutputVars.WaterHeating(EPlus::FuelTypeOil),
                       OutputVars.WaterHeating(EPlus::FuelTypePropane),
                       OutputVars.WaterHeating(EPlus::FuelTypeWoodCord),
                       OutputVars.WaterHeating(EPlus::FuelTypeWoodPellets),
                       OutputVars.WaterHeating(EPlus::FuelTypeCoal),
                       OutputVars.WaterHeatingElectricityRecircPump,
                       OutputVars.WaterHeatingElectricitySolarThermalPump,
                       OutputVars.WaterHeatingLoad,
                       OutputVars.WaterHeatingLoadTankLosses,
                       OutputVars.WaterHeaterLoadDesuperheater,
                       OutputVars.WaterHeaterLoadSolarThermal]

    names_to_objs = {}
    [@hvac_map, @dhw_map].each do |map|
      map.each do |sys_id, object_names|
        object_names.each do |object_name|
          names_to_objs[object_name] = @model.getModelObjectsByName(object_name, true)
        end
      end
    end

    # Remove objects that are not referenced by output vars and are not
    # EMS output vars.
    { @hvac_map => hvac_output_vars,
      @dhw_map => dhw_output_vars }.each do |map, vars|
      all_vars = vars.reduce({}, :merge)
      map.each do |sys_id, object_names|
        objects_to_delete = []
        object_names.each do |object_name|
          names_to_objs[object_name].each do |object|
            next if object.to_EnergyManagementSystemOutputVariable.is_initialized
            next unless all_vars[object.class.to_s].nil? # Referenced?

            objects_to_delete << object
          end
        end
        objects_to_delete.uniq.each do |object|
          map[sys_id].delete object
        end
      end
    end

    def add_output_variables(vars, object, timeseries_frequency)
      if object.to_EnergyManagementSystemOutputVariable.is_initialized
        return [OpenStudio::IdfObject.load("Output:Variable,*,#{object.name},#{timeseries_frequency};").get]
      else
        obj_class = nil
        vars.keys.each do |k|
          method_name = "to_#{k.gsub('OpenStudio::Model::', '')}"
          tmp = object.public_send(method_name) if object.respond_to? method_name
          if (not tmp.nil?) && tmp.is_initialized
            obj_class = tmp.get.class.to_s
          end
        end
        return [] if vars[obj_class].nil?

        results = []
        vars[obj_class].each do |object_var|
          results << OpenStudio::IdfObject.load("Output:Variable,#{object.name},#{object_var},#{timeseries_frequency};").get
        end
        return results
      end
    end

    results = []

    # Add output variables to model
    ems_objects = []
    @hvac_map.each do |sys_id, hvac_names|
      hvac_names.each do |hvac_name|
        names_to_objs[hvac_name].each do |hvac_object|
          if hvac_object.to_EnergyManagementSystemOutputVariable.is_initialized
            ems_objects << hvac_object
          else
            hvac_output_vars.each do |hvac_output_var|
              add_output_variables(hvac_output_var, hvac_object, timeseries_frequency).each do |outvar|
                results << outvar
              end
            end
          end
        end
      end
    end
    @dhw_map.each do |sys_id, dhw_names|
      dhw_names.each do |dhw_name|
        names_to_objs[dhw_name].each do |dhw_object|
          if dhw_object.to_EnergyManagementSystemOutputVariable.is_initialized
            ems_objects << dhw_object
          else
            dhw_output_vars.each do |dhw_output_var|
              add_output_variables(dhw_output_var, dhw_object, timeseries_frequency).each do |outvar|
                results << outvar
              end
            end
          end
        end
      end
    end

    # Add EMS output variables to model
    ems_objects.uniq.each do |ems_object|
      add_output_variables(nil, ems_object, timeseries_frequency).each do |outvar|
        results << outvar
      end
    end

    return results
  end

  class BaseOutput
    def initialize()
      @timeseries_output = []
    end
    attr_accessor(:name, :annual_output, :timeseries_output, :annual_units, :timeseries_units)
  end

  class Fuel < BaseOutput
    def initialize(meters: nil)
      super()
      @meters = meters
      @timeseries_output_by_system = {}
    end
    attr_accessor(:meters, :timeseries_output_by_system)
  end

  class EndUse < BaseOutput
    def initialize(meters: nil, variables: nil)
      super()
      @meters = meters
      @variables = variables
      @timeseries_output_by_system = {}
      @annual_output_by_system = {}
      if not variables.nil?
        @variable_names = get_all_variable_keys(variables)
      end
    end
    attr_accessor(:meters, :variables, :annual_output_by_system, :timeseries_output_by_system, :variable_names)
  end

  class HotWater < BaseOutput
    def initialize(subcat:)
      super()
      @subcat = subcat
    end
    attr_accessor(:subcat, :keys, :variable)
  end

  class PeakFuel < BaseOutput
    def initialize(meters:, report:)
      super()
      @meters = meters
      @report = report
    end
    attr_accessor(:meters, :report)
  end

  class Load < BaseOutput
    def initialize(variables: nil, ems_variable: nil)
      super()
      @variables = variables
      @ems_variable = ems_variable
      @timeseries_output_by_system = {}
      @annual_output_by_system = {}
      if not variables.nil?
        @variable_names = get_all_variable_keys(variables)
      end
    end
    attr_accessor(:variables, :ems_variable, :annual_output_by_system, :timeseries_output_by_system, :variable_names)
  end

  class ComponentLoad < BaseOutput
    def initialize(ems_variable:)
      super()
      @ems_variable = ems_variable
    end
    attr_accessor(:ems_variable)
  end

  class UnmetLoad < BaseOutput
    def initialize(key:, variable:)
      super()
      @key = key
      @variable = variable
    end
    attr_accessor(:key, :variable)
  end

  class PeakLoad < BaseOutput
    def initialize(meters:)
      super()
      @meters = meters
    end
    attr_accessor(:meters)
  end

  class ZoneTemp < BaseOutput
    def initialize
      super()
    end
    attr_accessor()
  end

  class Airflow < BaseOutput
    def initialize(ems_program:, ems_variables:)
      super()
      @ems_program = ems_program
      @ems_variables = ems_variables
    end
    attr_accessor(:ems_program, :ems_variables)
  end

  class Weather < BaseOutput
    def initialize(variable:, variable_units:, timeseries_units:)
      super()
      @variable = variable
      @variable_units = variable_units
      @timeseries_units = timeseries_units
    end
    attr_accessor(:variable, :variable_units)
  end

  def setup_outputs
    def get_timeseries_units_from_fuel_type(fuel_type)
      if fuel_type == FT::Elec
        return 'kWh'
      end

      return 'kBtu'
    end

    # Fuels

    @fuels = {}
    @fuels[FT::Elec] = Fuel.new(meters: ["#{EPlus::FuelTypeElectricity}:Facility"])
    @fuels[FT::Gas] = Fuel.new(meters: ["#{EPlus::FuelTypeNaturalGas}:Facility"])
    @fuels[FT::Oil] = Fuel.new(meters: ["#{EPlus::FuelTypeOil}:Facility"])
    @fuels[FT::Propane] = Fuel.new(meters: ["#{EPlus::FuelTypePropane}:Facility"])
    @fuels[FT::WoodCord] = Fuel.new(meters: ["#{EPlus::FuelTypeWoodCord}:Facility"])
    @fuels[FT::WoodPellets] = Fuel.new(meters: ["#{EPlus::FuelTypeWoodPellets}:Facility"])
    @fuels[FT::Coal] = Fuel.new(meters: ["#{EPlus::FuelTypeCoal}:Facility"])

    @fuels.each do |fuel_type, fuel|
      fuel.name = "Fuel Use: #{fuel_type}: Total"
      fuel.annual_units = 'MBtu'
      fuel.timeseries_units = get_timeseries_units_from_fuel_type(fuel_type)
    end

    # End Uses

    # NOTE: Some end uses are obtained from meters, others are rolled up from
    # output variables so that we can have more control.
    @end_uses = {}
    @end_uses[[FT::Elec, EUT::Heating]] = EndUse.new(variables: OutputVars.SpaceHeating(EPlus::FuelTypeElectricity))
    @end_uses[[FT::Elec, EUT::HeatingFanPump]] = EndUse.new()
    @end_uses[[FT::Elec, EUT::Cooling]] = EndUse.new(variables: OutputVars.SpaceCoolingElectricity)
    @end_uses[[FT::Elec, EUT::CoolingFanPump]] = EndUse.new()
    @end_uses[[FT::Elec, EUT::HotWater]] = EndUse.new(variables: OutputVars.WaterHeating(EPlus::FuelTypeElectricity))
    @end_uses[[FT::Elec, EUT::HotWaterRecircPump]] = EndUse.new(variables: OutputVars.WaterHeatingElectricityRecircPump)
    @end_uses[[FT::Elec, EUT::HotWaterSolarThermalPump]] = EndUse.new(variables: OutputVars.WaterHeatingElectricitySolarThermalPump)
    @end_uses[[FT::Elec, EUT::LightsInterior]] = EndUse.new(meters: ["#{Constants.ObjectNameInteriorLighting}:InteriorLights:#{EPlus::FuelTypeElectricity}"])
    @end_uses[[FT::Elec, EUT::LightsGarage]] = EndUse.new(meters: ["#{Constants.ObjectNameGarageLighting}:InteriorLights:#{EPlus::FuelTypeElectricity}"])
    @end_uses[[FT::Elec, EUT::LightsExterior]] = EndUse.new(meters: ["ExteriorLights:#{EPlus::FuelTypeElectricity}"])
    @end_uses[[FT::Elec, EUT::MechVent]] = EndUse.new(meters: ["#{Constants.ObjectNameMechanicalVentilation}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
    @end_uses[[FT::Elec, EUT::MechVentPreheat]] = EndUse.new(variables: OutputVars.MechVentPreconditioning(EPlus::FuelTypeElectricity))
    @end_uses[[FT::Elec, EUT::MechVentPrecool]] = EndUse.new(variables: OutputVars.MechVentPreconditioning(EPlus::FuelTypeElectricity))
    @end_uses[[FT::Elec, EUT::WholeHouseFan]] = EndUse.new(meters: ["#{Constants.ObjectNameWholeHouseFan}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
    @end_uses[[FT::Elec, EUT::Refrigerator]] = EndUse.new(meters: ["#{Constants.ObjectNameRefrigerator}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
    if @eri_design.nil? # Skip end uses not used by ERI
      @end_uses[[FT::Elec, EUT::Freezer]] = EndUse.new(meters: ["#{Constants.ObjectNameFreezer}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
    end
    @end_uses[[FT::Elec, EUT::Dehumidifier]] = EndUse.new(variables: OutputVars.DehumidifierElectricity)
    @end_uses[[FT::Elec, EUT::Dishwasher]] = EndUse.new(meters: ["#{Constants.ObjectNameDishwasher}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
    @end_uses[[FT::Elec, EUT::ClothesWasher]] = EndUse.new(meters: ["#{Constants.ObjectNameClothesWasher}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
    @end_uses[[FT::Elec, EUT::ClothesDryer]] = EndUse.new(meters: ["#{Constants.ObjectNameClothesDryer}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
    @end_uses[[FT::Elec, EUT::RangeOven]] = EndUse.new(meters: ["#{Constants.ObjectNameCookingRange}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
    @end_uses[[FT::Elec, EUT::CeilingFan]] = EndUse.new(meters: ["#{Constants.ObjectNameCeilingFan}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
    @end_uses[[FT::Elec, EUT::Television]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscTelevision}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
    @end_uses[[FT::Elec, EUT::PlugLoads]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscPlugLoads}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
    if @eri_design.nil? # Skip end uses not used by ERI
      @end_uses[[FT::Elec, EUT::Vehicle]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscElectricVehicleCharging}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
      @end_uses[[FT::Elec, EUT::WellPump]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscWellPump}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
      @end_uses[[FT::Elec, EUT::PoolHeater]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscPoolHeater}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
      @end_uses[[FT::Elec, EUT::PoolPump]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscPoolPump}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
      @end_uses[[FT::Elec, EUT::HotTubHeater]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscHotTubHeater}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
      @end_uses[[FT::Elec, EUT::HotTubPump]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscHotTubPump}:InteriorEquipment:#{EPlus::FuelTypeElectricity}"])
    end
    @end_uses[[FT::Elec, EUT::PV]] = EndUse.new(meters: ['Photovoltaic:ElectricityProduced', 'PowerConversion:ElectricityProduced'])
    @end_uses[[FT::Elec, EUT::Generator]] = EndUse.new(meters: ['Cogeneration:ElectricityProduced'])
    @end_uses[[FT::Gas, EUT::Heating]] = EndUse.new(variables: OutputVars.SpaceHeating(EPlus::FuelTypeNaturalGas))
    @end_uses[[FT::Gas, EUT::HotWater]] = EndUse.new(variables: OutputVars.WaterHeating(EPlus::FuelTypeNaturalGas))
    @end_uses[[FT::Gas, EUT::ClothesDryer]] = EndUse.new(meters: ["#{Constants.ObjectNameClothesDryer}:InteriorEquipment:#{EPlus::FuelTypeNaturalGas}"])
    @end_uses[[FT::Gas, EUT::RangeOven]] = EndUse.new(meters: ["#{Constants.ObjectNameCookingRange}:InteriorEquipment:#{EPlus::FuelTypeNaturalGas}"])
    @end_uses[[FT::Gas, EUT::MechVentPreheat]] = EndUse.new(variables: OutputVars.MechVentPreconditioning(EPlus::FuelTypeNaturalGas))
    if @eri_design.nil? # Skip end uses not used by ERI
      @end_uses[[FT::Gas, EUT::PoolHeater]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscPoolHeater}:InteriorEquipment:#{EPlus::FuelTypeNaturalGas}"])
      @end_uses[[FT::Gas, EUT::HotTubHeater]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscHotTubHeater}:InteriorEquipment:#{EPlus::FuelTypeNaturalGas}"])
      @end_uses[[FT::Gas, EUT::Grill]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscGrill}:InteriorEquipment:#{EPlus::FuelTypeNaturalGas}"])
      @end_uses[[FT::Gas, EUT::Lighting]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscLighting}:InteriorEquipment:#{EPlus::FuelTypeNaturalGas}"])
      @end_uses[[FT::Gas, EUT::Fireplace]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscFireplace}:InteriorEquipment:#{EPlus::FuelTypeNaturalGas}"])
    end
    @end_uses[[FT::Gas, EUT::Generator]] = EndUse.new(meters: ["Cogeneration:#{EPlus::FuelTypeNaturalGas}"])
    @end_uses[[FT::Oil, EUT::Heating]] = EndUse.new(variables: OutputVars.SpaceHeating(EPlus::FuelTypeOil))
    @end_uses[[FT::Oil, EUT::HotWater]] = EndUse.new(variables: OutputVars.WaterHeating(EPlus::FuelTypeOil))
    @end_uses[[FT::Oil, EUT::ClothesDryer]] = EndUse.new(meters: ["#{Constants.ObjectNameClothesDryer}:InteriorEquipment:#{EPlus::FuelTypeOil}"])
    @end_uses[[FT::Oil, EUT::RangeOven]] = EndUse.new(meters: ["#{Constants.ObjectNameCookingRange}:InteriorEquipment:#{EPlus::FuelTypeOil}"])
    @end_uses[[FT::Oil, EUT::MechVentPreheat]] = EndUse.new(variables: OutputVars.MechVentPreconditioning(EPlus::FuelTypeOil))
    if @eri_design.nil? # Skip end uses not used by ERI
      @end_uses[[FT::Oil, EUT::Grill]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscGrill}:InteriorEquipment:#{EPlus::FuelTypeOil}"])
      @end_uses[[FT::Oil, EUT::Lighting]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscLighting}:InteriorEquipment:#{EPlus::FuelTypeOil}"])
      @end_uses[[FT::Oil, EUT::Fireplace]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscFireplace}:InteriorEquipment:#{EPlus::FuelTypeOil}"])
    end
    @end_uses[[FT::Oil, EUT::Generator]] = EndUse.new(meters: ["Cogeneration:#{EPlus::FuelTypeOil}"])
    @end_uses[[FT::Propane, EUT::Heating]] = EndUse.new(variables: OutputVars.SpaceHeating(EPlus::FuelTypePropane))
    @end_uses[[FT::Propane, EUT::HotWater]] = EndUse.new(variables: OutputVars.WaterHeating(EPlus::FuelTypePropane))
    @end_uses[[FT::Propane, EUT::ClothesDryer]] = EndUse.new(meters: ["#{Constants.ObjectNameClothesDryer}:InteriorEquipment:#{EPlus::FuelTypePropane}"])
    @end_uses[[FT::Propane, EUT::RangeOven]] = EndUse.new(meters: ["#{Constants.ObjectNameCookingRange}:InteriorEquipment:#{EPlus::FuelTypePropane}"])
    @end_uses[[FT::Propane, EUT::MechVentPreheat]] = EndUse.new(variables: OutputVars.MechVentPreconditioning(EPlus::FuelTypePropane))
    if @eri_design.nil? # Skip end uses not used by ERI
      @end_uses[[FT::Propane, EUT::Grill]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscGrill}:InteriorEquipment:#{EPlus::FuelTypePropane}"])
      @end_uses[[FT::Propane, EUT::Lighting]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscLighting}:InteriorEquipment:#{EPlus::FuelTypePropane}"])
      @end_uses[[FT::Propane, EUT::Fireplace]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscFireplace}:InteriorEquipment:#{EPlus::FuelTypePropane}"])
    end
    @end_uses[[FT::Propane, EUT::Generator]] = EndUse.new(meters: ["Cogeneration:#{EPlus::FuelTypePropane}"])
    @end_uses[[FT::WoodCord, EUT::Heating]] = EndUse.new(variables: OutputVars.SpaceHeating(EPlus::FuelTypeWoodCord))
    @end_uses[[FT::WoodCord, EUT::HotWater]] = EndUse.new(variables: OutputVars.WaterHeating(EPlus::FuelTypeWoodCord))
    @end_uses[[FT::WoodCord, EUT::ClothesDryer]] = EndUse.new(meters: ["#{Constants.ObjectNameClothesDryer}:InteriorEquipment:#{EPlus::FuelTypeWoodCord}"])
    @end_uses[[FT::WoodCord, EUT::RangeOven]] = EndUse.new(meters: ["#{Constants.ObjectNameCookingRange}:InteriorEquipment:#{EPlus::FuelTypeWoodCord}"])
    @end_uses[[FT::WoodCord, EUT::MechVentPreheat]] = EndUse.new(variables: OutputVars.MechVentPreconditioning(EPlus::FuelTypeWoodCord))
    if @eri_design.nil? # Skip end uses not used by ERI
      @end_uses[[FT::WoodCord, EUT::Grill]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscGrill}:InteriorEquipment:#{EPlus::FuelTypeWoodCord}"])
      @end_uses[[FT::WoodCord, EUT::Lighting]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscLighting}:InteriorEquipment:#{EPlus::FuelTypeWoodCord}"])
      @end_uses[[FT::WoodCord, EUT::Fireplace]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscFireplace}:InteriorEquipment:#{EPlus::FuelTypeWoodCord}"])
    end
    @end_uses[[FT::WoodCord, EUT::Generator]] = EndUse.new(meters: ["Cogeneration:#{EPlus::FuelTypeWoodCord}"])
    @end_uses[[FT::WoodPellets, EUT::Heating]] = EndUse.new(variables: OutputVars.SpaceHeating(EPlus::FuelTypeWoodPellets))
    @end_uses[[FT::WoodPellets, EUT::HotWater]] = EndUse.new(variables: OutputVars.WaterHeating(EPlus::FuelTypeWoodPellets))
    @end_uses[[FT::WoodPellets, EUT::ClothesDryer]] = EndUse.new(meters: ["#{Constants.ObjectNameClothesDryer}:InteriorEquipment:#{EPlus::FuelTypeWoodPellets}"])
    @end_uses[[FT::WoodPellets, EUT::RangeOven]] = EndUse.new(meters: ["#{Constants.ObjectNameCookingRange}:InteriorEquipment:#{EPlus::FuelTypeWoodPellets}"])
    @end_uses[[FT::WoodPellets, EUT::MechVentPreheat]] = EndUse.new(variables: OutputVars.MechVentPreconditioning(EPlus::FuelTypeWoodPellets))
    if @eri_design.nil? # Skip end uses not used by ERI
      @end_uses[[FT::WoodPellets, EUT::Grill]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscGrill}:InteriorEquipment:#{EPlus::FuelTypeWoodPellets}"])
      @end_uses[[FT::WoodPellets, EUT::Lighting]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscLighting}:InteriorEquipment:#{EPlus::FuelTypeWoodPellets}"])
      @end_uses[[FT::WoodPellets, EUT::Fireplace]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscFireplace}:InteriorEquipment:#{EPlus::FuelTypeWoodPellets}"])
    end
    @end_uses[[FT::WoodPellets, EUT::Generator]] = EndUse.new(meters: ["Cogeneration:#{EPlus::FuelTypeWoodPellets}"])
    @end_uses[[FT::Coal, EUT::Heating]] = EndUse.new(variables: OutputVars.SpaceHeating(EPlus::FuelTypeCoal))
    @end_uses[[FT::Coal, EUT::HotWater]] = EndUse.new(variables: OutputVars.WaterHeating(EPlus::FuelTypeCoal))
    @end_uses[[FT::Coal, EUT::ClothesDryer]] = EndUse.new(meters: ["#{Constants.ObjectNameClothesDryer}:InteriorEquipment:#{EPlus::FuelTypeCoal}"])
    @end_uses[[FT::Coal, EUT::RangeOven]] = EndUse.new(meters: ["#{Constants.ObjectNameCookingRange}:InteriorEquipment:#{EPlus::FuelTypeCoal}"])
    @end_uses[[FT::Coal, EUT::MechVentPreheat]] = EndUse.new(variables: OutputVars.MechVentPreconditioning(EPlus::FuelTypeCoal))
    if @eri_design.nil? # Skip end uses not used by ERI
      @end_uses[[FT::Coal, EUT::Grill]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscGrill}:InteriorEquipment:#{EPlus::FuelTypeCoal}"])
      @end_uses[[FT::Coal, EUT::Lighting]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscLighting}:InteriorEquipment:#{EPlus::FuelTypeCoal}"])
      @end_uses[[FT::Coal, EUT::Fireplace]] = EndUse.new(meters: ["#{Constants.ObjectNameMiscFireplace}:InteriorEquipment:#{EPlus::FuelTypeCoal}"])
    end
    @end_uses[[FT::Coal, EUT::Generator]] = EndUse.new(meters: ["Cogeneration:#{EPlus::FuelTypeCoal}"])

    @end_uses.each do |key, end_use|
      fuel_type, end_use_type = key
      end_use.name = "End Use: #{fuel_type}: #{end_use_type}"
      end_use.annual_units = 'MBtu'
      end_use.timeseries_units = get_timeseries_units_from_fuel_type(fuel_type)
    end

    # Hot Water Uses
    @hot_water_uses = {}
    @hot_water_uses[HWT::ClothesWasher] = HotWater.new(subcat: Constants.ObjectNameClothesWasher)
    @hot_water_uses[HWT::Dishwasher] = HotWater.new(subcat: Constants.ObjectNameDishwasher)
    @hot_water_uses[HWT::Fixtures] = HotWater.new(subcat: Constants.ObjectNameFixtures)
    @hot_water_uses[HWT::DistributionWaste] = HotWater.new(subcat: Constants.ObjectNameDistributionWaste)

    @hot_water_uses.each do |hot_water_type, hot_water|
      hot_water.variable = 'Water Use Equipment Hot Water Volume'
      hot_water.name = "Hot Water: #{hot_water_type}"
      hot_water.annual_units = 'gal'
      hot_water.timeseries_units = 'gal'
    end

    # Peak Fuels
    @peak_fuels = {}
    @peak_fuels[[FT::Elec, PFT::Winter]] = PeakFuel.new(meters: ['Heating:EnergyTransfer'], report: 'Peak Electricity Winter Total')
    @peak_fuels[[FT::Elec, PFT::Summer]] = PeakFuel.new(meters: ['Cooling:EnergyTransfer'], report: 'Peak Electricity Summer Total')

    @peak_fuels.each do |key, peak_fuel|
      fuel_type, peak_fuel_type = key
      peak_fuel.name = "Peak #{fuel_type}: #{peak_fuel_type} Total"
      peak_fuel.annual_units = 'W'
    end

    # Loads

    @loads = {}
    @loads[LT::Heating] = Load.new(ems_variable: 'loads_htg_tot')
    @loads[LT::Cooling] = Load.new(ems_variable: 'loads_clg_tot')
    @loads[LT::HotWaterDelivered] = Load.new(variables: OutputVars.WaterHeatingLoad)
    @loads[LT::HotWaterTankLosses] = Load.new()
    @loads[LT::HotWaterDesuperheater] = Load.new(variables: OutputVars.WaterHeaterLoadDesuperheater)
    @loads[LT::HotWaterSolarThermal] = Load.new()

    @loads.each do |load_type, load|
      load.name = "Load: #{load_type}"
      load.annual_units = 'MBtu'
      load.timeseries_units = 'kBtu'
    end

    # Component Loads

    @component_loads = {}
    @component_loads[[LT::Heating, CLT::Roofs]] = ComponentLoad.new(ems_variable: 'loads_htg_roofs')
    @component_loads[[LT::Heating, CLT::Ceilings]] = ComponentLoad.new(ems_variable: 'loads_htg_ceilings')
    @component_loads[[LT::Heating, CLT::Walls]] = ComponentLoad.new(ems_variable: 'loads_htg_walls')
    @component_loads[[LT::Heating, CLT::RimJoists]] = ComponentLoad.new(ems_variable: 'loads_htg_rim_joists')
    @component_loads[[LT::Heating, CLT::FoundationWalls]] = ComponentLoad.new(ems_variable: 'loads_htg_foundation_walls')
    @component_loads[[LT::Heating, CLT::Doors]] = ComponentLoad.new(ems_variable: 'loads_htg_doors')
    @component_loads[[LT::Heating, CLT::Windows]] = ComponentLoad.new(ems_variable: 'loads_htg_windows')
    @component_loads[[LT::Heating, CLT::Skylights]] = ComponentLoad.new(ems_variable: 'loads_htg_skylights')
    @component_loads[[LT::Heating, CLT::Floors]] = ComponentLoad.new(ems_variable: 'loads_htg_floors')
    @component_loads[[LT::Heating, CLT::Slabs]] = ComponentLoad.new(ems_variable: 'loads_htg_slabs')
    @component_loads[[LT::Heating, CLT::InternalMass]] = ComponentLoad.new(ems_variable: 'loads_htg_internal_mass')
    @component_loads[[LT::Heating, CLT::Infiltration]] = ComponentLoad.new(ems_variable: 'loads_htg_infil')
    @component_loads[[LT::Heating, CLT::NaturalVentilation]] = ComponentLoad.new(ems_variable: 'loads_htg_natvent')
    @component_loads[[LT::Heating, CLT::MechanicalVentilation]] = ComponentLoad.new(ems_variable: 'loads_htg_mechvent')
    @component_loads[[LT::Heating, CLT::WholeHouseFan]] = ComponentLoad.new(ems_variable: 'loads_htg_whf')
    @component_loads[[LT::Heating, CLT::Ducts]] = ComponentLoad.new(ems_variable: 'loads_htg_ducts')
    @component_loads[[LT::Heating, CLT::InternalGains]] = ComponentLoad.new(ems_variable: 'loads_htg_intgains')
    @component_loads[[LT::Cooling, CLT::Roofs]] = ComponentLoad.new(ems_variable: 'loads_clg_roofs')
    @component_loads[[LT::Cooling, CLT::Ceilings]] = ComponentLoad.new(ems_variable: 'loads_clg_ceilings')
    @component_loads[[LT::Cooling, CLT::Walls]] = ComponentLoad.new(ems_variable: 'loads_clg_walls')
    @component_loads[[LT::Cooling, CLT::RimJoists]] = ComponentLoad.new(ems_variable: 'loads_clg_rim_joists')
    @component_loads[[LT::Cooling, CLT::FoundationWalls]] = ComponentLoad.new(ems_variable: 'loads_clg_foundation_walls')
    @component_loads[[LT::Cooling, CLT::Doors]] = ComponentLoad.new(ems_variable: 'loads_clg_doors')
    @component_loads[[LT::Cooling, CLT::Windows]] = ComponentLoad.new(ems_variable: 'loads_clg_windows')
    @component_loads[[LT::Cooling, CLT::Skylights]] = ComponentLoad.new(ems_variable: 'loads_clg_skylights')
    @component_loads[[LT::Cooling, CLT::Floors]] = ComponentLoad.new(ems_variable: 'loads_clg_floors')
    @component_loads[[LT::Cooling, CLT::Slabs]] = ComponentLoad.new(ems_variable: 'loads_clg_slabs')
    @component_loads[[LT::Cooling, CLT::InternalMass]] = ComponentLoad.new(ems_variable: 'loads_clg_internal_mass')
    @component_loads[[LT::Cooling, CLT::Infiltration]] = ComponentLoad.new(ems_variable: 'loads_clg_infil')
    @component_loads[[LT::Cooling, CLT::NaturalVentilation]] = ComponentLoad.new(ems_variable: 'loads_clg_natvent')
    @component_loads[[LT::Cooling, CLT::MechanicalVentilation]] = ComponentLoad.new(ems_variable: 'loads_clg_mechvent')
    @component_loads[[LT::Cooling, CLT::WholeHouseFan]] = ComponentLoad.new(ems_variable: 'loads_clg_whf')
    @component_loads[[LT::Cooling, CLT::Ducts]] = ComponentLoad.new(ems_variable: 'loads_clg_ducts')
    @component_loads[[LT::Cooling, CLT::InternalGains]] = ComponentLoad.new(ems_variable: 'loads_clg_intgains')

    @component_loads.each do |key, comp_load|
      load_type, comp_load_type = key
      comp_load.name = "Component Load: #{load_type}: #{comp_load_type}"
      comp_load.annual_units = 'MBtu'
      comp_load.timeseries_units = 'kBtu'
    end

    # Unmet Loads (unexpected load that should have been met by HVAC)
    @unmet_loads = {}
    @unmet_loads[LT::Heating] = UnmetLoad.new(key: Constants.ObjectNameIdealAirSystemResidual, variable: 'Zone Ideal Loads Zone Sensible Heating Energy')
    @unmet_loads[LT::Cooling] = UnmetLoad.new(key: Constants.ObjectNameIdealAirSystemResidual, variable: 'Zone Ideal Loads Zone Sensible Cooling Energy')

    @unmet_loads.each do |load_type, unmet_load|
      unmet_load.name = "Unmet Load: #{load_type}"
      unmet_load.annual_units = 'MBtu'
      unmet_load.timeseries_units = 'kBtu'
    end

    # Ideal System Loads (expected load that is not met by HVAC)
    @ideal_system_loads = {}
    @ideal_system_loads[LT::Heating] = UnmetLoad.new(key: Constants.ObjectNameIdealAirSystem, variable: 'Zone Ideal Loads Zone Sensible Heating Energy')
    @ideal_system_loads[LT::Cooling] = UnmetLoad.new(key: Constants.ObjectNameIdealAirSystem, variable: 'Zone Ideal Loads Zone Sensible Cooling Energy')

    @ideal_system_loads.each do |load_type, ideal_load|
      ideal_load.name = "Ideal System Load: #{load_type}"
      ideal_load.annual_units = 'MBtu'
    end

    # Peak Loads
    @peak_loads = {}
    @peak_loads[LT::Heating] = PeakLoad.new(meters: ['Heating:EnergyTransfer'])
    @peak_loads[LT::Cooling] = PeakLoad.new(meters: ['Cooling:EnergyTransfer'])

    @peak_loads.each do |load_type, peak_load|
      peak_load.name = "Peak Load: #{load_type}"
      peak_load.annual_units = 'kBtu'
    end

    # Zone Temperatures

    @zone_temps = {}

    # Airflows
    @airflows = {}
    @airflows[AFT::Infiltration] = Airflow.new(ems_program: Constants.ObjectNameInfiltration + ' program', ems_variables: [(Constants.ObjectNameInfiltration + ' flow act').gsub(' ', '_')])
    @airflows[AFT::MechanicalVentilation] = Airflow.new(ems_program: Constants.ObjectNameInfiltration + ' program', ems_variables: ['Qfan'])
    @airflows[AFT::NaturalVentilation] = Airflow.new(ems_program: Constants.ObjectNameNaturalVentilation + ' program', ems_variables: [(Constants.ObjectNameNaturalVentilation + ' flow act').gsub(' ', '_')])
    @airflows[AFT::WholeHouseFan] = Airflow.new(ems_program: Constants.ObjectNameNaturalVentilation + ' program', ems_variables: [(Constants.ObjectNameWholeHouseFan + ' flow act').gsub(' ', '_')])

    @airflows.each do |airflow_type, airflow|
      airflow.name = "Airflow: #{airflow_type}"
      airflow.timeseries_units = 'cfm'
    end

    # Weather
    @weather = {}
    @weather[WT::DrybulbTemp] = Weather.new(variable: 'Site Outdoor Air Drybulb Temperature', variable_units: 'C', timeseries_units: 'F')
    @weather[WT::WetbulbTemp] = Weather.new(variable: 'Site Outdoor Air Wetbulb Temperature', variable_units: 'C', timeseries_units: 'F')
    @weather[WT::RelativeHumidity] = Weather.new(variable: 'Site Outdoor Air Relative Humidity', variable_units: '%', timeseries_units: '%')
    @weather[WT::WindSpeed] = Weather.new(variable: 'Site Wind Speed', variable_units: 'm/s', timeseries_units: 'mph')
    @weather[WT::DiffuseSolar] = Weather.new(variable: 'Site Diffuse Solar Radiation Rate per Area', variable_units: 'W/m^2', timeseries_units: 'Btu/(hr*ft^2)')
    @weather[WT::DirectSolar] = Weather.new(variable: 'Site Direct Solar Radiation Rate per Area', variable_units: 'W/m^2', timeseries_units: 'Btu/(hr*ft^2)')

    @weather.each do |weather_type, weather_data|
      weather_data.name = "Weather: #{weather_type}"
    end
  end

  def reporting_frequency_map
    return {
      'timestep' => 'Zone Timestep',
      'hourly' => 'Hourly',
      'daily' => 'Daily',
      'monthly' => 'Monthly',
    }
  end

  class OutputVars
    def self.SpaceHeating(fuel)
      return { 'OpenStudio::Model::AirLoopHVACUnitarySystem' => ["Unitary System Heating Ancillary #{fuel} Energy"],
               'OpenStudio::Model::CoilHeatingDXSingleSpeed' => ["Heating Coil #{fuel} Energy", "Heating Coil Crankcase Heater #{fuel} Energy", "Heating Coil Defrost #{fuel} Energy"],
               'OpenStudio::Model::CoilHeatingDXMultiSpeed' => ["Heating Coil #{fuel} Energy", "Heating Coil Crankcase Heater #{fuel} Energy", "Heating Coil Defrost #{fuel} Energy"],
               'OpenStudio::Model::CoilHeatingElectric' => ["Heating Coil #{fuel} Energy", "Heating Coil Crankcase Heater #{fuel} Energy", "Heating Coil Defrost #{fuel} Energy"],
               'OpenStudio::Model::CoilHeatingGas' => ["Heating Coil #{fuel} Energy"],
               'OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit' => ["Heating Coil #{fuel} Energy", "Heating Coil Crankcase Heater #{fuel} Energy", "Heating Coil Defrost #{fuel} Energy"],
               'OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric' => ["Baseboard #{fuel} Energy"],
               'OpenStudio::Model::BoilerHotWater' => ["Boiler #{fuel} Energy"] }
    end

    def self.SpaceHeatingDFHPPrimaryLoad
      return { 'OpenStudio::Model::CoilHeatingDXSingleSpeed' => ['Heating Coil Heating Energy'],
               'OpenStudio::Model::CoilHeatingDXMultiSpeed' => ['Heating Coil Heating Energy'] }
    end

    def self.SpaceHeatingDFHPBackupLoad
      return { 'OpenStudio::Model::CoilHeatingElectric' => ['Heating Coil Heating Energy'],
               'OpenStudio::Model::CoilHeatingGas' => ['Heating Coil Heating Energy'] }
    end

    def self.SpaceCoolingElectricity
      fuel = EPlus::FuelTypeElectricity
      return { 'OpenStudio::Model::CoilCoolingDXSingleSpeed' => ["Cooling Coil #{fuel} Energy", "Cooling Coil Crankcase Heater #{fuel} Energy"],
               'OpenStudio::Model::CoilCoolingDXMultiSpeed' => ["Cooling Coil #{fuel} Energy", "Cooling Coil Crankcase Heater #{fuel} Energy"],
               'OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit' => ["Cooling Coil #{fuel} Energy", "Cooling Coil Crankcase Heater #{fuel} Energy"],
               'OpenStudio::Model::EvaporativeCoolerDirectResearchSpecial' => ["Evaporative Cooler #{fuel} Energy"] }
    end

    def self.DehumidifierElectricity
      fuel = EPlus::FuelTypeElectricity
      return { 'OpenStudio::Model::ZoneHVACDehumidifierDX' => ["Zone Dehumidifier #{fuel} Energy"] }
    end

    def self.WaterHeatingElectricitySolarThermalPump
      fuel = EPlus::FuelTypeElectricity
      return { 'OpenStudio::Model::PumpConstantSpeed' => ["Pump #{fuel} Energy"] }
    end

    def self.WaterHeatingElectricityRecircPump
      fuel = EPlus::FuelTypeElectricity
      return { 'OpenStudio::Model::ElectricEquipment' => ["Electric Equipment #{fuel} Energy"] }
    end

    def self.WaterHeating(fuel)
      return { 'OpenStudio::Model::WaterHeaterMixed' => ["Water Heater #{fuel} Energy", "Water Heater Off Cycle Parasitic #{fuel} Energy", "Water Heater On Cycle Parasitic #{fuel} Energy"],
               'OpenStudio::Model::WaterHeaterStratified' => ["Water Heater #{fuel} Energy", "Water Heater Off Cycle Parasitic #{fuel} Energy", "Water Heater On Cycle Parasitic #{fuel} Energy"],
               'OpenStudio::Model::CoilWaterHeatingAirToWaterHeatPumpWrapped' => ["Cooling Coil Water Heating #{fuel} Energy"],
               'OpenStudio::Model::FanOnOff' => ["Fan #{fuel} Energy"] } # TOOD: Update if this changes to FanSystemModel per https://github.com/NREL/OpenStudio/issues/4334
    end

    def self.WaterHeatingLoad
      return { 'OpenStudio::Model::WaterUseConnections' => ['Water Use Connections Plant Hot Water Energy'] }
    end

    def self.WaterHeatingLoadTankLosses
      return { 'OpenStudio::Model::WaterHeaterMixed' => ['Water Heater Heat Loss Energy'],
               'OpenStudio::Model::WaterHeaterStratified' => ['Water Heater Heat Loss Energy'] }
    end

    def self.WaterHeaterLoadDesuperheater
      return { 'OpenStudio::Model::CoilWaterHeatingDesuperheater' => ['Water Heater Heating Energy'] }
    end

    def self.WaterHeaterLoadSolarThermal
      return { 'OpenStudio::Model::WaterHeaterStratified' => ['Water Heater Use Side Heat Transfer Energy'] }
    end

    def self.MechVentPreconditioning(fuel)
      return { 'OpenStudio::Model::OtherEquipment' => ["Other Equipment #{fuel} Energy"] }
    end
  end
end

def get_all_variable_keys(vars)
  var_keys = []
  vars.keys.each do |key|
    vars[key].each do |var_key|
      var_keys << var_key
    end
  end
  return var_keys
end

# register the measure to be used by the application
SimulationOutputReport.new.registerWithApplication
