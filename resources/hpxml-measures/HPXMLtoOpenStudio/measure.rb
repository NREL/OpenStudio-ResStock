# frozen_string_literal: true

# Require all gems up front; this is much faster than multiple resource
# files lazy loading as needed, as it prevents multiple lookups for the
# same gem.
require 'pathname'
require 'csv'
require 'oga'
require_relative 'resources/airflow'
require_relative 'resources/constants'
require_relative 'resources/constructions'
require_relative 'resources/energyplus'
require_relative 'resources/generator'
require_relative 'resources/geometry'
require_relative 'resources/hotwater_appliances'
require_relative 'resources/hpxml'
require_relative 'resources/hpxml_defaults'
require_relative 'resources/hvac'
require_relative 'resources/hvac_sizing'
require_relative 'resources/lighting'
require_relative 'resources/location'
require_relative 'resources/materials'
require_relative 'resources/misc_loads'
require_relative 'resources/psychrometrics'
require_relative 'resources/pv'
require_relative 'resources/schedules'
require_relative 'resources/simcontrols'
require_relative 'resources/unit_conversions'
require_relative 'resources/util'
require_relative 'resources/validator'
require_relative 'resources/version'
require_relative 'resources/waterheater'
require_relative 'resources/weather'
require_relative 'resources/xmlhelper'
require_relative '../BuildResidentialHPXML/resources/constants'
require_relative '../BuildResidentialHPXML/resources/schedules'

# start the measure
class HPXMLtoOpenStudio < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'HPXML to OpenStudio Translator'
  end

  # human readable description
  def description
    return 'Translates HPXML file to OpenStudio Model'
  end

  # human readable description of modeling approach
  def modeler_description
    return ''
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hpxml_path', true)
    arg.setDisplayName('HPXML File Path')
    arg.setDescription('Absolute/relative path of the HPXML file.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('output_dir', true)
    arg.setDisplayName('Directory for Output Files')
    arg.setDescription('Absolute/relative path for the output files directory.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('debug', false)
    arg.setDisplayName('Debug Mode?')
    arg.setDescription('If true: 1) Writes in.osm file, 2) Generates additional log output, and 3) Creates all EnergyPlus output files.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('add_component_loads', false)
    arg.setDisplayName('Add component loads?')
    arg.setDescription('If true, adds the calculation of heating/cooling component loads (not enabled by default for faster performance).')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeBoolArgument('skip_validation', false)
    arg.setDisplayName('Skip Validation?')
    arg.setDescription('If true, bypasses HPXML input validation for faster performance. WARNING: This should only be used if the supplied HPXML file has already been validated against the Schema & Schematron documents.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('building_id', false)
    arg.setDisplayName('BuildingID')
    arg.setDescription('The ID of the HPXML Building. Only required if there are multiple Building elements in the HPXML file.')
    args << arg

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    Geometry.tear_down_model(model, runner)

    Version.check_openstudio_version()

    # assign the user inputs to variables
    hpxml_path = runner.getStringArgumentValue('hpxml_path', user_arguments)
    output_dir = runner.getStringArgumentValue('output_dir', user_arguments)
    add_component_loads = runner.getBoolArgumentValue('add_component_loads', user_arguments)
    debug = runner.getBoolArgumentValue('debug', user_arguments)
    skip_validation = runner.getBoolArgumentValue('skip_validation', user_arguments)
    building_id = runner.getOptionalStringArgumentValue('building_id', user_arguments)

    unless (Pathname.new hpxml_path).absolute?
      hpxml_path = File.expand_path(File.join(File.dirname(__FILE__), hpxml_path))
    end
    unless File.exist?(hpxml_path) && hpxml_path.downcase.end_with?('.xml')
      fail "'#{hpxml_path}' does not exist or is not an .xml file."
    end

    unless (Pathname.new output_dir).absolute?
      output_dir = File.expand_path(File.join(File.dirname(__FILE__), output_dir))
    end

    if building_id.is_initialized
      building_id = building_id.get
    else
      building_id = nil
    end

    begin
      if skip_validation
        stron_paths = []
      else
        stron_paths = [File.join(File.dirname(__FILE__), 'resources', 'HPXMLvalidator.xml'),
                       File.join(File.dirname(__FILE__), 'resources', 'EPvalidator.xml')]
      end
      hpxml = HPXML.new(hpxml_path: hpxml_path, schematron_validators: stron_paths, building_id: building_id)
      hpxml.errors.each do |error|
        runner.registerError(error)
      end
      hpxml.warnings.each do |warning|
        runner.registerWarning(warning)
      end
      return false unless hpxml.errors.empty?

      epw_path, cache_path = process_weather(hpxml, runner, model, hpxml_path)

      if debug
        epw_output_path = File.join(output_dir, 'in.epw')
        FileUtils.cp(epw_path, epw_output_path)
      end

      OSModel.create(hpxml, runner, model, hpxml_path, epw_path, cache_path, output_dir,
                     add_component_loads, building_id, debug)
    rescue Exception => e
      runner.registerError("#{e.message}\n#{e.backtrace.join("\n")}")
      return false
    end

    return true
  end

  def process_weather(hpxml, runner, model, hpxml_path)
    epw_path = hpxml.climate_and_risk_zones.weather_station_epw_filepath

    if not File.exist? epw_path
      test_epw_path = File.join(File.dirname(hpxml_path), epw_path)
      epw_path = test_epw_path if File.exist? test_epw_path
    end
    if not File.exist? epw_path
      test_epw_path = File.join(File.dirname(__FILE__), '..', 'weather', epw_path)
      epw_path = test_epw_path if File.exist? test_epw_path
    end
    if not File.exist? epw_path
      test_epw_path = File.join(File.dirname(__FILE__), '..', '..', 'weather', epw_path)
      epw_path = test_epw_path if File.exist? test_epw_path
    end
    if not File.exist?(epw_path)
      fail "'#{epw_path}' could not be found."
    end

    cache_path = epw_path.gsub('.epw', '-cache.csv')
    if not File.exist?(cache_path)
      # Process weather file to create cache .csv
      runner.registerWarning("'#{cache_path}' could not be found; regenerating it.")
      epw_file = OpenStudio::EpwFile.new(epw_path)
      OpenStudio::Model::WeatherFile.setWeatherFile(model, epw_file)
      weather = WeatherProcess.new(model, runner)
      begin
        File.open(cache_path, 'wb') do |file|
          weather.dump_to_csv(file)
        end
      rescue SystemCallError
        runner.registerWarning("#{cache_path} could not be written, skipping.")
      end
    end

    return epw_path, cache_path
  end
end

class OSModel
  def self.create(hpxml, runner, model, hpxml_path, epw_path, cache_path, output_dir,
                  add_component_loads, building_id, debug)
    @hpxml = hpxml
    @debug = debug

    @eri_version = @hpxml.header.eri_calculation_version # Hidden feature
    @eri_version = 'latest' if @eri_version.nil?
    @eri_version = Constants.ERIVersions[-1] if @eri_version == 'latest'

    @apply_ashrae140_assumptions = @hpxml.header.apply_ashrae140_assumptions # Hidden feature
    @apply_ashrae140_assumptions = false if @apply_ashrae140_assumptions.nil?

    # Init

    weather, epw_file = Location.apply_weather_file(model, runner, epw_path, cache_path)
    set_defaults_and_globals(runner, output_dir, epw_file, weather)
    Location.apply(model, runner, weather, epw_file, @hpxml)
    add_simulation_params(model)

    @schedules_file = nil
    unless @hpxml.header.schedules_path.nil?
      @schedules_file = SchedulesFile.new(runner: runner, model: model, schedules_path: @hpxml.header.schedules_path, col_names: ScheduleGenerator.col_names.keys)
    end

    # Conditioned space/zone

    spaces = {}
    create_or_get_space(model, spaces, HPXML::LocationLivingSpace)
    set_foundation_and_walls_top()
    set_heating_and_cooling_seasons(model)
    add_setpoints(runner, model, weather, spaces)

    # Geometry/Envelope
    add_roofs(runner, model, spaces)
    add_walls(runner, model, spaces)
    add_rim_joists(runner, model, spaces)
    add_frame_floors(runner, model, spaces)
    add_foundation_walls_slabs(runner, model, spaces)
    add_shading_schedule(runner, model, weather)
    add_windows(runner, model, spaces, weather)
    add_doors(runner, model, spaces)
    add_skylights(runner, model, spaces, weather)
    add_conditioned_floor_area(runner, model, spaces)
    add_thermal_mass(runner, model, spaces)
    update_conditioned_basement(runner, model, spaces)
    Geometry.set_zone_volumes(runner, model, spaces, @hpxml, @apply_ashrae140_assumptions)
    Geometry.explode_surfaces(runner, model, @hpxml, @walls_top)
    add_num_occupants(model, runner, spaces)

    # HVAC

    add_ideal_system(runner, model, spaces, epw_path)
    add_cooling_system(runner, model, spaces)
    add_heating_system(runner, model, spaces)
    add_heat_pump(runner, model, weather, spaces)
    add_dehumidifiers(runner, model, spaces)
    add_residual_ideal_system(runner, model, spaces)
    add_ceiling_fans(runner, model, weather, spaces)

    # Hot Water

    add_hot_water_and_appliances(runner, model, weather, spaces)

    # Plug Loads & Fuel Loads & Lighting

    add_mels(runner, model, spaces)
    add_mfls(runner, model, spaces)
    add_lighting(runner, model, epw_file, spaces)

    # Pools & Hot Tubs
    add_pools_and_hot_tubs(runner, model, spaces)

    # Other

    add_airflow(runner, model, weather, spaces)
    add_photovoltaics(runner, model)
    add_generators(runner, model)
    add_additional_properties(runner, model, hpxml_path, building_id)

    # Output

    add_loads_output(runner, model, spaces, add_component_loads)
    add_output_control_files(runner, model)
    # Uncomment to debug EMS
    # add_ems_debug_output(runner, model)

    # Vacancy
    unless @schedules_file.nil?
      @schedules_file.set_vacancy
    end

    if debug
      osm_output_path = File.join(output_dir, 'in.osm')
      File.write(osm_output_path, model.to_s)
      runner.registerInfo("Wrote file: #{osm_output_path}")
    end
  end

  private

  def self.set_defaults_and_globals(runner, output_dir, epw_file, weather)
    # Initialize
    @remaining_heat_load_frac = 1.0
    @remaining_cool_load_frac = 1.0
    @hvac_map = {} # mapping between HPXML HVAC systems and model objects
    @dhw_map = {}  # mapping between HPXML Water Heating systems and model objects
    @cond_bsmnt_surfaces = [] # list of surfaces in conditioned basement, used for modification of some surface properties, eg. solar absorptance, view factor, etc.

    # Set globals
    @cfa = @hpxml.building_construction.conditioned_floor_area
    @ncfl = @hpxml.building_construction.number_of_conditioned_floors
    @ncfl_ag = @hpxml.building_construction.number_of_conditioned_floors_above_grade
    @nbeds = @hpxml.building_construction.number_of_bedrooms
    @default_azimuths = HPXMLDefaults.get_default_azimuths(@hpxml)

    # Apply defaults to HPXML object
    HPXMLDefaults.apply(@hpxml, @eri_version, weather, epw_file: epw_file)

    @frac_windows_operable = @hpxml.fraction_of_windows_operable()

    # Write updated HPXML object (w/ defaults) to file for inspection
    hpxml_defaults_path = File.join(output_dir, 'in.xml')
    XMLHelper.write_file(@hpxml.to_oga, hpxml_defaults_path)

    # Now that we've written in.xml, ensure that no capacities/airflows
    # are zero in order to prevent potential E+ errors.
    HVAC.ensure_nonzero_sizing_values(@hpxml)
  end

  def self.add_simulation_params(model)
    SimControls.apply(model, @hpxml)
  end

  def self.update_conditioned_basement(runner, model, spaces)
    return if @cond_bsmnt_surfaces.empty?

    # Update @cond_bsmnt_surfaces to include subsurfaces
    new_cond_bsmnt_surfaces = @cond_bsmnt_surfaces.dup
    @cond_bsmnt_surfaces.each do |cond_bsmnt_surface|
      next if cond_bsmnt_surface.is_a? OpenStudio::Model::InternalMassDefinition
      next if cond_bsmnt_surface.subSurfaces.empty?

      cond_bsmnt_surface.subSurfaces.each do |ss|
        new_cond_bsmnt_surfaces << ss
      end
    end
    @cond_bsmnt_surfaces = new_cond_bsmnt_surfaces.dup

    update_solar_absorptances(runner, model)
    assign_view_factors(runner, model, spaces)
  end

  def self.update_solar_absorptances(runner, model)
    # modify conditioned basement surface properties
    # zero out interior solar absorptance in conditioned basement

    @cond_bsmnt_surfaces.each do |cond_bsmnt_surface|
      # skip windows because windows don't have such property to change.
      next if cond_bsmnt_surface.is_a?(OpenStudio::Model::SubSurface) && (cond_bsmnt_surface.subSurfaceType.downcase == 'fixedwindow')

      adj_surface = nil
      if not cond_bsmnt_surface.is_a? OpenStudio::Model::InternalMassDefinition
        if not cond_bsmnt_surface.is_a? OpenStudio::Model::SubSurface
          adj_surface = cond_bsmnt_surface.adjacentSurface.get if cond_bsmnt_surface.adjacentSurface.is_initialized
        else
          adj_surface = cond_bsmnt_surface.adjacentSubSurface.get if cond_bsmnt_surface.adjacentSubSurface.is_initialized
        end
      end
      const = cond_bsmnt_surface.construction.get
      layered_const = const.to_LayeredConstruction.get
      innermost_material = layered_const.layers[layered_const.numLayers() - 1].to_StandardOpaqueMaterial.get
      # check if target surface is sharing its interior material/construction object with other surfaces
      # if so, need to clone the material/construction and make changes there, then reassign it to target surface
      mat_share = (innermost_material.directUseCount != 1)
      const_share = (const.directUseCount != 1)
      if const_share
        # create new construction + new material for these surfaces
        new_const = const.clone.to_Construction.get
        cond_bsmnt_surface.setConstruction(new_const)
        new_material = innermost_material.clone.to_StandardOpaqueMaterial.get
        layered_const = new_const.to_LayeredConstruction.get
        layered_const.setLayer(layered_const.numLayers() - 1, new_material)
      elsif mat_share
        # create new material for existing unique construction
        new_material = innermost_material.clone.to_StandardOpaqueMaterial.get
        layered_const.setLayer(layered_const.numLayers() - 1, new_material)
      end
      if layered_const.numLayers() == 1
        # split single layer into two to only change its inside facing property
        layer_mat = layered_const.layers[0].to_StandardOpaqueMaterial.get
        layer_mat.setThickness(layer_mat.thickness / 2)
        layered_const.insertLayer(1, layer_mat.clone.to_StandardOpaqueMaterial.get)
      end
      # Re-read innermost material and assign properties after adjustment
      innermost_material = layered_const.layers[layered_const.numLayers() - 1].to_StandardOpaqueMaterial.get
      innermost_material.setSolarAbsorptance(0.0)
      innermost_material.setVisibleAbsorptance(0.0)
      next if adj_surface.nil?

      # Create new construction in case of shared construction.
      layered_const_adj = OpenStudio::Model::Construction.new(model)
      layered_const_adj.setName(cond_bsmnt_surface.construction.get.name.get + ' Reversed Bsmnt')
      adj_surface.setConstruction(layered_const_adj)
      layered_const_adj.setLayers(cond_bsmnt_surface.construction.get.to_LayeredConstruction.get.layers.reverse())
    end
  end

  def self.assign_view_factors(runner, model, spaces)
    # zero out view factors between conditioned basement surfaces and living zone surfaces
    all_surfaces = [] # all surfaces in single conditioned space
    lv_surfaces = []  # surfaces in living
    cond_base_surfaces = [] # surfaces in conditioned basement

    spaces[HPXML::LocationLivingSpace].surfaces.each do |surface|
      surface.subSurfaces.each do |sub_surface|
        all_surfaces << sub_surface
      end
      all_surfaces << surface
    end
    spaces[HPXML::LocationLivingSpace].internalMass.each do |im|
      all_surfaces << im
    end

    all_surfaces.each do |surface|
      if @cond_bsmnt_surfaces.include?(surface) ||
         ((@cond_bsmnt_surfaces.include? surface.internalMassDefinition) if surface.is_a? OpenStudio::Model::InternalMass)
        cond_base_surfaces << surface
      else
        lv_surfaces << surface
      end
    end

    all_surfaces.sort!

    # calculate view factors separately for living and conditioned basement
    vf_map_lv = calc_approximate_view_factor(runner, model, lv_surfaces)
    vf_map_cb = calc_approximate_view_factor(runner, model, cond_base_surfaces)

    zone_prop = spaces[HPXML::LocationLivingSpace].thermalZone.get.getZonePropertyUserViewFactorsBySurfaceName

    all_surfaces.each do |from_surface|
      all_surfaces.each do |to_surface|
        next if (vf_map_lv[from_surface].nil? || vf_map_lv[from_surface][to_surface].nil?) &&
                (vf_map_cb[from_surface].nil? || vf_map_cb[from_surface][to_surface].nil?)

        if lv_surfaces.include? from_surface
          vf = vf_map_lv[from_surface][to_surface]
        else
          vf = vf_map_cb[from_surface][to_surface]
        end
        next if vf < 0.05 # Skip small view factors to reduce runtime

        os_vf = OpenStudio::Model::ViewFactor.new(from_surface, to_surface, vf.round(10))
        zone_prop.addViewFactor(os_vf)
      end
    end
  end

  def self.calc_approximate_view_factor(runner, model, all_surfaces)
    # calculate approximate view factor using E+ approach
    # used for recalculating single thermal zone view factor matrix
    return {} if all_surfaces.size == 0
    if all_surfaces.size <= 3
      fail 'less than three surfaces in conditioned space. Please double check.'
    end

    s_azimuths = {}
    s_tilts = {}
    s_types = {}
    all_surfaces.each do |surface|
      if surface.is_a? OpenStudio::Model::InternalMass
        # Assumed values consistent with EnergyPlus source code
        s_azimuths[surface] = 0.0
        s_tilts[surface] = 90.0
      else
        s_azimuths[surface] = UnitConversions.convert(surface.azimuth, 'rad', 'deg')
        s_tilts[surface] = UnitConversions.convert(surface.tilt, 'rad', 'deg')
        if surface.is_a? OpenStudio::Model::SubSurface
          s_types[surface] = surface.surface.get.surfaceType.downcase
        else
          s_types[surface] = surface.surfaceType.downcase
        end
      end
    end

    same_ang_limit = 10.0
    vf_map = {}
    all_surfaces.each do |surface| # surface, subsurface, and internal mass
      surface_vf_map = {}

      # sum all the surface area that could be seen by surface1 up
      zone_seen_area = 0.0
      seen_surface = {}
      all_surfaces.each do |surface2|
        next if surface2 == surface
        next if surface2.is_a? OpenStudio::Model::SubSurface

        seen_surface[surface2] = false
        if surface2.is_a? OpenStudio::Model::InternalMass
          # all surfaces see internal mass
          zone_seen_area += surface2.surfaceArea.get
          seen_surface[surface2] = true
        else
          if (s_types[surface2] == 'floor') ||
             ((s_types[surface] == 'floor') && (s_types[surface2] == 'roofceiling')) ||
             ((s_azimuths[surface] - s_azimuths[surface2]).abs > same_ang_limit) ||
             ((s_tilts[surface] - s_tilts[surface2]).abs > same_ang_limit)
            zone_seen_area += surface2.grossArea # include subsurface area
            seen_surface[surface2] = true
          end
        end
      end

      all_surfaces.each do |surface2|
        next if surface2 == surface
        next if surface2.is_a? OpenStudio::Model::SubSurface # handled together with its parent surface
        next unless seen_surface[surface2]

        if surface2.is_a? OpenStudio::Model::InternalMass
          surface_vf_map[surface2] = surface2.surfaceArea.get / zone_seen_area
        else # surfaces
          if surface2.subSurfaces.size > 0
            # calculate surface and its sub surfaces view factors
            if surface2.netArea > 0.1 # base surface of a sub surface: window/door etc.
              fail "Unexpected net area for surface '#{surface2.name}'."
            end

            surface2.subSurfaces.each do |sub_surface|
              surface_vf_map[sub_surface] = sub_surface.grossArea / zone_seen_area
            end
          else # no subsurface
            surface_vf_map[surface2] = surface2.grossArea / zone_seen_area
          end
        end
      end
      vf_map[surface] = surface_vf_map
    end
    return vf_map
  end

  def self.add_num_occupants(model, runner, spaces)
    # Occupants
    num_occ = @hpxml.building_occupancy.number_of_residents
    return if num_occ <= 0

    Geometry.apply_occupants(model, num_occ, @cfa, spaces[HPXML::LocationLivingSpace], @schedules_file)
  end

  def self.create_or_get_space(model, spaces, spacetype)
    if spaces[spacetype].nil?
      Geometry.create_space_and_zone(model, spaces, spacetype)
    end
    return spaces[spacetype]
  end

  def self.add_roofs(runner, model, spaces)
    @hpxml.roofs.each do |roof|
      next if roof.net_area < 1.0 # skip modeling net surface area for surfaces comprised entirely of subsurface area

      if roof.azimuth.nil?
        if roof.pitch > 0
          azimuths = @default_azimuths # Model as four directions for average exterior incident solar
        else
          azimuths = [@default_azimuths[0]] # Arbitrary azimuth for flat roof
        end
      else
        azimuths = [roof.azimuth]
      end

      surfaces = []

      azimuths.each do |azimuth|
        width = Math::sqrt(roof.net_area)
        length = (roof.net_area / width) / azimuths.size
        tilt = roof.pitch / 12.0
        z_origin = @walls_top + 0.5 * Math.sin(Math.atan(tilt)) * width

        vertices = Geometry.create_roof_vertices(length, width, z_origin, azimuth, tilt)
        surface = OpenStudio::Model::Surface.new(vertices, model)
        surfaces << surface
        surface.additionalProperties.setFeature('Length', length)
        surface.additionalProperties.setFeature('Width', width)
        surface.additionalProperties.setFeature('Azimuth', azimuth)
        surface.additionalProperties.setFeature('Tilt', tilt)
        surface.additionalProperties.setFeature('SurfaceType', 'Roof')
        if azimuths.size > 1
          surface.setName("#{roof.id}:#{azimuth}")
        else
          surface.setName(roof.id)
        end
        surface.setSurfaceType('RoofCeiling')
        surface.setOutsideBoundaryCondition('Outdoors')
        set_surface_interior(model, spaces, surface, roof)
      end

      next if surfaces.empty?

      # Apply construction
      has_radiant_barrier = roof.radiant_barrier
      if has_radiant_barrier
        radiant_barrier_grade = roof.radiant_barrier_grade
      end
      # FUTURE: Create Constructions.get_air_film(surface) method; use in measure.rb and hpxml_translator_test.rb
      inside_film = Material.AirFilmRoof(Geometry.get_roof_pitch([surfaces[0]]))
      outside_film = Material.AirFilmOutside
      mat_roofing = Material.RoofMaterial(roof.roof_type)
      if @apply_ashrae140_assumptions
        inside_film = Material.AirFilmRoofASHRAE140
        outside_film = Material.AirFilmOutsideASHRAE140
      end
      mat_int_finish = Material.InteriorFinishMaterial(roof.interior_finish_type, roof.interior_finish_thickness)
      if mat_int_finish.nil?
        fallback_mat_int_finish = nil
      else
        fallback_mat_int_finish = Material.InteriorFinishMaterial(mat_int_finish.name, 0.1) # Try thin material
      end

      install_grade = 1
      assembly_r = roof.insulation_assembly_r_value

      if not mat_int_finish.nil?
        # Closed cavity
        constr_sets = [
          WoodStudConstructionSet.new(Material.Stud2x(8.0), 0.07, 20.0, 0.75, mat_int_finish, mat_roofing),    # 2x8, 24" o.c. + R20
          WoodStudConstructionSet.new(Material.Stud2x(8.0), 0.07, 10.0, 0.75, mat_int_finish, mat_roofing),    # 2x8, 24" o.c. + R10
          WoodStudConstructionSet.new(Material.Stud2x(8.0), 0.07, 0.0, 0.75, mat_int_finish, mat_roofing),     # 2x8, 24" o.c.
          WoodStudConstructionSet.new(Material.Stud2x6, 0.07, 0.0, 0.75, mat_int_finish, mat_roofing),         # 2x6, 24" o.c.
          WoodStudConstructionSet.new(Material.Stud2x4, 0.07, 0.0, 0.5, mat_int_finish, mat_roofing),          # 2x4, 16" o.c.
          WoodStudConstructionSet.new(Material.Stud2x4, 0.01, 0.0, 0.0, fallback_mat_int_finish, mat_roofing), # Fallback
        ]
        match, constr_set, cavity_r = Constructions.pick_wood_stud_construction_set(assembly_r, constr_sets, inside_film, outside_film, roof.id)

        Constructions.apply_closed_cavity_roof(runner, model, surfaces, "#{roof.id} construction",
                                               cavity_r, install_grade,
                                               constr_set.stud.thick_in,
                                               true, constr_set.framing_factor,
                                               constr_set.mat_int_finish,
                                               constr_set.osb_thick_in, constr_set.rigid_r,
                                               constr_set.mat_ext_finish, has_radiant_barrier,
                                               inside_film, outside_film, radiant_barrier_grade,
                                               roof.solar_absorptance, roof.emittance)
      else
        # Open cavity
        constr_sets = [
          GenericConstructionSet.new(10.0, 0.5, nil, mat_roofing), # w/R-10 rigid
          GenericConstructionSet.new(0.0, 0.5, nil, mat_roofing),  # Standard
          GenericConstructionSet.new(0.0, 0.0, nil, mat_roofing),  # Fallback
        ]
        match, constr_set, layer_r = Constructions.pick_generic_construction_set(assembly_r, constr_sets, inside_film, outside_film, roof.id)

        cavity_r = 0
        cavity_ins_thick_in = 0
        framing_factor = 0
        framing_thick_in = 0

        Constructions.apply_open_cavity_roof(runner, model, surfaces, "#{roof.id} construction",
                                             cavity_r, install_grade, cavity_ins_thick_in,
                                             framing_factor, framing_thick_in,
                                             constr_set.osb_thick_in, layer_r + constr_set.rigid_r,
                                             constr_set.mat_ext_finish, has_radiant_barrier,
                                             inside_film, outside_film, radiant_barrier_grade,
                                             roof.solar_absorptance, roof.emittance)
      end
      Constructions.check_surface_assembly_rvalue(runner, surfaces, inside_film, outside_film, assembly_r, match)
    end
  end

  def self.add_walls(runner, model, spaces)
    @hpxml.walls.each do |wall|
      next if wall.net_area < 1.0 # skip modeling net surface area for surfaces comprised entirely of subsurface area

      if wall.azimuth.nil?
        if wall.is_exterior
          azimuths = @default_azimuths # Model as four directions for average exterior incident solar
        else
          azimuths = [@default_azimuths[0]] # Arbitrary direction, doesn't receive exterior incident solar
        end
      else
        azimuths = [wall.azimuth]
      end

      surfaces = []

      azimuths.each do |azimuth|
        height = 8.0 * @ncfl_ag
        length = (wall.net_area / height) / azimuths.size
        z_origin = @foundation_top

        vertices = Geometry.create_wall_vertices(length, height, z_origin, azimuth)
        surface = OpenStudio::Model::Surface.new(vertices, model)
        surfaces << surface
        surface.additionalProperties.setFeature('Length', length)
        surface.additionalProperties.setFeature('Azimuth', azimuth)
        surface.additionalProperties.setFeature('Tilt', 90.0)
        surface.additionalProperties.setFeature('SurfaceType', 'Wall')
        if azimuths.size > 1
          surface.setName("#{wall.id}:#{azimuth}")
        else
          surface.setName(wall.id)
        end
        surface.setSurfaceType('Wall')
        set_surface_interior(model, spaces, surface, wall)
        set_surface_exterior(model, spaces, surface, wall)
        if wall.is_interior
          surface.setSunExposure('NoSun')
          surface.setWindExposure('NoWind')
        end
      end

      next if surfaces.empty?

      # Apply construction
      # The code below constructs a reasonable wall construction based on the
      # wall type while ensuring the correct assembly R-value.

      inside_film = Material.AirFilmVertical
      if wall.is_exterior
        outside_film = Material.AirFilmOutside
        mat_ext_finish = Material.ExteriorFinishMaterial(wall.siding)
      else
        outside_film = Material.AirFilmVertical
        mat_ext_finish = nil
      end
      if @apply_ashrae140_assumptions
        inside_film = Material.AirFilmVerticalASHRAE140
        outside_film = Material.AirFilmOutsideASHRAE140
      end
      mat_int_finish = Material.InteriorFinishMaterial(wall.interior_finish_type, wall.interior_finish_thickness)

      Constructions.apply_wall_construction(runner, model, surfaces, wall.id, wall.wall_type, wall.insulation_assembly_r_value,
                                            mat_int_finish, inside_film, outside_film, mat_ext_finish, wall.solar_absorptance,
                                            wall.emittance)
    end
  end

  def self.add_rim_joists(runner, model, spaces)
    @hpxml.rim_joists.each do |rim_joist|
      if rim_joist.azimuth.nil?
        if rim_joist.is_exterior
          azimuths = @default_azimuths # Model as four directions for average exterior incident solar
        else
          azimuths = [@default_azimuths[0]] # Arbitrary direction, doesn't receive exterior incident solar
        end
      else
        azimuths = [rim_joist.azimuth]
      end

      surfaces = []

      azimuths.each do |azimuth|
        height = 1.0
        length = (rim_joist.area / height) / azimuths.size
        z_origin = @foundation_top

        vertices = Geometry.create_wall_vertices(length, height, z_origin, azimuth)
        surface = OpenStudio::Model::Surface.new(vertices, model)
        surfaces << surface
        surface.additionalProperties.setFeature('Length', length)
        surface.additionalProperties.setFeature('Azimuth', azimuth)
        surface.additionalProperties.setFeature('Tilt', 90.0)
        surface.additionalProperties.setFeature('SurfaceType', 'RimJoist')
        if azimuths.size > 1
          surface.setName("#{rim_joist.id}:#{azimuth}")
        else
          surface.setName(rim_joist.id)
        end
        surface.setSurfaceType('Wall')
        set_surface_interior(model, spaces, surface, rim_joist)
        set_surface_exterior(model, spaces, surface, rim_joist)
        if rim_joist.is_interior
          surface.setSunExposure('NoSun')
          surface.setWindExposure('NoWind')
        end
      end

      # Apply construction

      inside_film = Material.AirFilmVertical
      if rim_joist.is_exterior
        outside_film = Material.AirFilmOutside
        mat_ext_finish = Material.ExteriorFinishMaterial(rim_joist.siding)
      else
        outside_film = Material.AirFilmVertical
        mat_ext_finish = nil
      end

      assembly_r = rim_joist.insulation_assembly_r_value

      constr_sets = [
        WoodStudConstructionSet.new(Material.Stud2x(2.0), 0.17, 20.0, 2.0, nil, mat_ext_finish),  # 2x4 + R20
        WoodStudConstructionSet.new(Material.Stud2x(2.0), 0.17, 10.0, 2.0, nil, mat_ext_finish),  # 2x4 + R10
        WoodStudConstructionSet.new(Material.Stud2x(2.0), 0.17, 0.0, 2.0, nil, mat_ext_finish),   # 2x4
        WoodStudConstructionSet.new(Material.Stud2x(2.0), 0.01, 0.0, 0.0, nil, mat_ext_finish),   # Fallback
      ]
      match, constr_set, cavity_r = Constructions.pick_wood_stud_construction_set(assembly_r, constr_sets, inside_film, outside_film, rim_joist.id)
      install_grade = 1

      Constructions.apply_rim_joist(runner, model, surfaces, "#{rim_joist.id} construction",
                                    cavity_r, install_grade, constr_set.framing_factor,
                                    constr_set.mat_int_finish, constr_set.osb_thick_in,
                                    constr_set.rigid_r, constr_set.mat_ext_finish,
                                    inside_film, outside_film, rim_joist.solar_absorptance,
                                    rim_joist.emittance)
      Constructions.check_surface_assembly_rvalue(runner, surfaces, inside_film, outside_film, assembly_r, match)
    end
  end

  def self.add_frame_floors(runner, model, spaces)
    @hpxml.frame_floors.each do |frame_floor|
      area = frame_floor.area
      width = Math::sqrt(area)
      length = area / width
      if frame_floor.interior_adjacent_to.include?('attic') || frame_floor.exterior_adjacent_to.include?('attic')
        z_origin = @walls_top
      else
        z_origin = @foundation_top
      end

      if frame_floor.is_ceiling
        vertices = Geometry.create_ceiling_vertices(length, width, z_origin, @default_azimuths)
        surface = OpenStudio::Model::Surface.new(vertices, model)
        surface.additionalProperties.setFeature('SurfaceType', 'Ceiling')
      else
        vertices = Geometry.create_floor_vertices(length, width, z_origin, @default_azimuths)
        surface = OpenStudio::Model::Surface.new(vertices, model)
        surface.additionalProperties.setFeature('SurfaceType', 'Floor')
      end
      surface.additionalProperties.setFeature('Tilt', 0.0)
      set_surface_interior(model, spaces, surface, frame_floor)
      set_surface_exterior(model, spaces, surface, frame_floor)
      surface.setName(frame_floor.id)
      if frame_floor.is_interior
        surface.setSunExposure('NoSun')
        surface.setWindExposure('NoWind')
      elsif frame_floor.is_floor
        surface.setSunExposure('NoSun')
      end

      # Apply construction

      if frame_floor.is_ceiling
        if @apply_ashrae140_assumptions
          # Attic floor
          inside_film = Material.AirFilmFloorASHRAE140
          outside_film = Material.AirFilmFloorASHRAE140
        else
          inside_film = Material.AirFilmFloorAverage
          outside_film = Material.AirFilmFloorAverage
        end
        mat_int_finish = Material.InteriorFinishMaterial(frame_floor.interior_finish_type, frame_floor.interior_finish_thickness)
        if mat_int_finish.nil?
          fallback_mat_int_finish = nil
        else
          fallback_mat_int_finish = Material.InteriorFinishMaterial(mat_int_finish.name, 0.1) # Try thin material
        end
        constr_sets = [
          WoodStudConstructionSet.new(Material.Stud2x6, 0.10, 50.0, 0.0, mat_int_finish, nil),         # 2x6, 24" o.c. + R50
          WoodStudConstructionSet.new(Material.Stud2x6, 0.10, 40.0, 0.0, mat_int_finish, nil),         # 2x6, 24" o.c. + R40
          WoodStudConstructionSet.new(Material.Stud2x6, 0.10, 30.0, 0.0, mat_int_finish, nil),         # 2x6, 24" o.c. + R30
          WoodStudConstructionSet.new(Material.Stud2x6, 0.10, 20.0, 0.0, mat_int_finish, nil),         # 2x6, 24" o.c. + R20
          WoodStudConstructionSet.new(Material.Stud2x6, 0.10, 10.0, 0.0, mat_int_finish, nil),         # 2x6, 24" o.c. + R10
          WoodStudConstructionSet.new(Material.Stud2x4, 0.13, 0.0, 0.0, mat_int_finish, nil),          # 2x4, 16" o.c.
          WoodStudConstructionSet.new(Material.Stud2x4, 0.01, 0.0, 0.0, fallback_mat_int_finish, nil), # Fallback
        ]
      else # Floor
        if @apply_ashrae140_assumptions
          # Raised floor
          inside_film = Material.AirFilmFloorASHRAE140
          outside_film = Material.AirFilmFloorZeroWindASHRAE140
          surface.setWindExposure('NoWind')
          covering = Material.CoveringBare(1.0)
        else
          inside_film = Material.AirFilmFloorReduced
          if frame_floor.is_exterior
            outside_film = Material.AirFilmOutside
          else
            outside_film = Material.AirFilmFloorReduced
          end
          if frame_floor.interior_adjacent_to == HPXML::LocationLivingSpace
            covering = Material.CoveringBare
          end
        end
        if covering.nil?
          fallback_covering = nil
        else
          fallback_covering = Material.CoveringBare(0.8, 0.01) # Try thin material
        end
        constr_sets = [
          WoodStudConstructionSet.new(Material.Stud2x6, 0.10, 20.0, 0.75, nil, covering),        # 2x6, 24" o.c. + R20
          WoodStudConstructionSet.new(Material.Stud2x6, 0.10, 10.0, 0.75, nil, covering),        # 2x6, 24" o.c. + R10
          WoodStudConstructionSet.new(Material.Stud2x6, 0.10, 0.0, 0.75, nil, covering),         # 2x6, 24" o.c.
          WoodStudConstructionSet.new(Material.Stud2x4, 0.13, 0.0, 0.5, nil, covering),          # 2x4, 16" o.c.
          WoodStudConstructionSet.new(Material.Stud2x4, 0.01, 0.0, 0.0, nil, fallback_covering), # Fallback
        ]
      end
      assembly_r = frame_floor.insulation_assembly_r_value

      match, constr_set, cavity_r = Constructions.pick_wood_stud_construction_set(assembly_r, constr_sets, inside_film, outside_film, frame_floor.id)

      install_grade = 1
      if frame_floor.is_ceiling

        Constructions.apply_ceiling(runner, model, [surface], "#{frame_floor.id} construction",
                                    cavity_r, install_grade,
                                    constr_set.rigid_r, constr_set.framing_factor,
                                    constr_set.stud.thick_in, constr_set.mat_int_finish,
                                    inside_film, outside_film)

      else # Floor
        Constructions.apply_floor(runner, model, [surface], "#{frame_floor.id} construction",
                                  cavity_r, install_grade,
                                  constr_set.framing_factor, constr_set.stud.thick_in,
                                  constr_set.osb_thick_in, constr_set.rigid_r,
                                  constr_set.mat_ext_finish, inside_film, outside_film)
      end

      Constructions.check_surface_assembly_rvalue(runner, [surface], inside_film, outside_film, assembly_r, match)
    end
  end

  def self.add_foundation_walls_slabs(runner, model, spaces)
    foundation_types = @hpxml.slabs.map { |s| s.interior_adjacent_to }.uniq

    foundation_types.each do |foundation_type|
      # Get attached foundation walls/slabs
      fnd_walls = []
      slabs = []
      @hpxml.foundation_walls.each do |foundation_wall|
        next unless foundation_wall.interior_adjacent_to == foundation_type
        next if foundation_wall.net_area < 1.0 # skip modeling net surface area for surfaces comprised entirely of subsurface area

        fnd_walls << foundation_wall
      end
      @hpxml.slabs.each do |slab|
        next unless slab.interior_adjacent_to == foundation_type

        slabs << slab
        slab.exposed_perimeter = [slab.exposed_perimeter, 1.0].max # minimum value to prevent error if no exposed slab
      end

      # Calculate combinations of slabs/walls for each Kiva instance
      kiva_instances = get_kiva_instances(fnd_walls, slabs)

      # Obtain some wall/slab information
      fnd_wall_lengths = {}
      fnd_walls.each do |foundation_wall|
        next unless foundation_wall.is_exterior

        fnd_wall_lengths[foundation_wall] = foundation_wall.area / foundation_wall.height
      end
      slab_exp_perims = {}
      slab_areas = {}
      slabs.each do |slab|
        slab_exp_perims[slab] = slab.exposed_perimeter
        slab_areas[slab] = slab.area
      end
      total_slab_exp_perim = slab_exp_perims.values.sum(0.0)
      total_slab_area = slab_areas.values.sum(0.0)
      total_fnd_wall_length = fnd_wall_lengths.values.sum(0.0)

      no_wall_slab_exp_perim = {}

      kiva_instances.each do |foundation_wall, slab|
        # Apportion referenced walls/slabs for this Kiva instance
        slab_frac = slab_exp_perims[slab] / total_slab_exp_perim
        if total_fnd_wall_length > 0
          fnd_wall_frac = fnd_wall_lengths[foundation_wall] / total_fnd_wall_length
        else
          fnd_wall_frac = 1.0 # Handle slab foundation type
        end

        kiva_foundation = nil
        if not foundation_wall.nil?
          # Add exterior foundation wall surface
          kiva_foundation = add_foundation_wall(runner, model, spaces, foundation_wall, slab_frac,
                                                total_fnd_wall_length, total_slab_exp_perim)
        end

        # Add single combined foundation slab surface (for similar surfaces)
        slab_exp_perim = slab_exp_perims[slab] * fnd_wall_frac
        slab_area = slab_areas[slab] * fnd_wall_frac
        no_wall_slab_exp_perim[slab] = 0.0 if no_wall_slab_exp_perim[slab].nil?
        if (not foundation_wall.nil?) && (slab_exp_perim > fnd_wall_lengths[foundation_wall] * slab_frac)
          # Keep track of no-wall slab exposed perimeter
          no_wall_slab_exp_perim[slab] += (slab_exp_perim - fnd_wall_lengths[foundation_wall] * slab_frac)

          # Reduce this slab's exposed perimeter so that EnergyPlus does not automatically
          # create a second no-wall Kiva instance for each of our Kiva instances.
          # Instead, we will later create our own Kiva instance to account for it.
          # This reduces the number of Kiva instances we end up with.
          exp_perim_frac = (fnd_wall_lengths[foundation_wall] * slab_frac) / slab_exp_perim
          slab_exp_perim *= exp_perim_frac
          slab_area *= exp_perim_frac
        end
        if not foundation_wall.nil?
          z_origin = -1 * foundation_wall.depth_below_grade # Position based on adjacent foundation walls
        else
          z_origin = -1 * slab.depth_below_grade
        end
        kiva_foundation = add_foundation_slab(runner, model, spaces, slab, slab_exp_perim,
                                              slab_area, z_origin, kiva_foundation)
      end

      # For each slab, create a no-wall Kiva slab instance if needed.
      slabs.each do |slab|
        next unless no_wall_slab_exp_perim[slab] > 1.0

        z_origin = 0
        slab_area = total_slab_area * no_wall_slab_exp_perim[slab] / total_slab_exp_perim
        kiva_foundation = add_foundation_slab(runner, model, spaces, slab, no_wall_slab_exp_perim[slab],
                                              slab_area, z_origin, nil)
      end

      # Interzonal foundation wall surfaces
      # The above-grade portion of these walls are modeled as EnergyPlus surfaces with standard adjacency.
      # The below-grade portion of these walls (in contact with ground) are not modeled, as Kiva does not
      # calculate heat flow between two zones through the ground.
      fnd_walls.each do |foundation_wall|
        next unless foundation_wall.is_interior

        ag_height = foundation_wall.height - foundation_wall.depth_below_grade
        ag_net_area = foundation_wall.net_area * ag_height / foundation_wall.height
        next if ag_net_area < 1.0

        length = ag_net_area / ag_height
        z_origin = -1 * ag_height
        if foundation_wall.azimuth.nil?
          azimuth = @default_azimuths[0] # Arbitrary direction, doesn't receive exterior incident solar
        else
          azimuth = foundation_wall.azimuth
        end

        vertices = Geometry.create_wall_vertices(length, ag_height, z_origin, azimuth)
        surface = OpenStudio::Model::Surface.new(vertices, model)
        surface.additionalProperties.setFeature('Length', length)
        surface.additionalProperties.setFeature('Azimuth', azimuth)
        surface.additionalProperties.setFeature('Tilt', 90.0)
        surface.additionalProperties.setFeature('SurfaceType', 'FoundationWall')
        surface.setName(foundation_wall.id)
        surface.setSurfaceType('Wall')
        set_surface_interior(model, spaces, surface, foundation_wall)
        set_surface_exterior(model, spaces, surface, foundation_wall)
        surface.setSunExposure('NoSun')
        surface.setWindExposure('NoWind')

        # Apply construction

        wall_type = HPXML::WallTypeConcrete
        inside_film = Material.AirFilmVertical
        outside_film = Material.AirFilmVertical
        assembly_r = foundation_wall.insulation_assembly_r_value
        mat_int_finish = Material.InteriorFinishMaterial(foundation_wall.interior_finish_type, foundation_wall.interior_finish_thickness)
        if assembly_r.nil?
          concrete_thick_in = foundation_wall.thickness
          int_r = foundation_wall.insulation_interior_r_value
          ext_r = foundation_wall.insulation_exterior_r_value
          mat_concrete = Material.Concrete(concrete_thick_in)
          mat_int_finish_rvalue = mat_int_finish.nil? ? 0.0 : mat_int_finish.rvalue
          assembly_r = int_r + ext_r + mat_concrete.rvalue + mat_int_finish_rvalue + inside_film.rvalue + outside_film.rvalue
        end
        mat_ext_finish = nil

        Constructions.apply_wall_construction(runner, model, [surface], foundation_wall.id, wall_type, assembly_r,
                                              mat_int_finish, inside_film, outside_film, mat_ext_finish, nil, nil)
      end
    end
  end

  def self.add_foundation_wall(runner, model, spaces, foundation_wall, slab_frac,
                               total_fnd_wall_length, total_slab_exp_perim)

    net_area = foundation_wall.net_area * slab_frac
    gross_area = foundation_wall.area * slab_frac
    height = foundation_wall.height
    height_ag = height - foundation_wall.depth_below_grade
    z_origin = -1 * foundation_wall.depth_below_grade
    length = gross_area / height
    if foundation_wall.azimuth.nil?
      azimuth = @default_azimuths[0] # Arbitrary; solar incidence in Kiva is applied as an orientation average (to the above grade portion of the wall)
    else
      azimuth = foundation_wall.azimuth
    end

    if total_fnd_wall_length > total_slab_exp_perim
      # Calculate exposed section of wall based on slab's total exposed perimeter.
      length *= total_slab_exp_perim / total_fnd_wall_length
    end

    if gross_area > net_area
      # Create a "notch" in the wall to account for the subsurfaces. This ensures that
      # we preserve the appropriate wall height, length, and area for Kiva.
      subsurface_area = gross_area - net_area
    else
      subsurface_area = 0
    end

    vertices = Geometry.create_wall_vertices(length, height, z_origin, azimuth, subsurface_area: subsurface_area)
    surface = OpenStudio::Model::Surface.new(vertices, model)
    surface.additionalProperties.setFeature('Length', length)
    surface.additionalProperties.setFeature('Azimuth', azimuth)
    surface.additionalProperties.setFeature('Tilt', 90.0)
    surface.additionalProperties.setFeature('SurfaceType', 'FoundationWall')
    surface.setName(foundation_wall.id)
    surface.setSurfaceType('Wall')
    set_surface_interior(model, spaces, surface, foundation_wall)
    set_surface_exterior(model, spaces, surface, foundation_wall)

    concrete_thick_in = foundation_wall.thickness
    assembly_r = foundation_wall.insulation_assembly_r_value
    mat_int_finish = Material.InteriorFinishMaterial(foundation_wall.interior_finish_type, foundation_wall.interior_finish_thickness)
    if not assembly_r.nil?
      ext_rigid_height = height
      ext_rigid_offset = 0.0
      inside_film = Material.AirFilmVertical
      mat_concrete = Material.Concrete(concrete_thick_in)
      mat_int_finish_rvalue = mat_int_finish.nil? ? 0.0 : mat_int_finish.rvalue
      ext_rigid_r = assembly_r - mat_concrete.rvalue - mat_int_finish_rvalue - inside_film.rvalue
      int_rigid_r = 0.0
      if ext_rigid_r < 0 # Try without interior finish
        mat_int_finish = nil
        ext_rigid_r = assembly_r - mat_concrete.rvalue - inside_film.rvalue
      end
      if (ext_rigid_r > 0) && (ext_rigid_r < 0.1)
        ext_rigid_r = 0.0 # Prevent tiny strip of insulation
      end
      if ext_rigid_r < 0
        ext_rigid_r = 0.0
        match = false
      else
        match = true
      end
    else
      ext_rigid_offset = foundation_wall.insulation_exterior_distance_to_top
      ext_rigid_height = foundation_wall.insulation_exterior_distance_to_bottom - ext_rigid_offset
      ext_rigid_r = foundation_wall.insulation_exterior_r_value
      int_rigid_offset = foundation_wall.insulation_interior_distance_to_top
      int_rigid_height = foundation_wall.insulation_interior_distance_to_bottom - int_rigid_offset
      int_rigid_r = foundation_wall.insulation_interior_r_value
    end

    Constructions.apply_foundation_wall(runner, model, [surface], "#{foundation_wall.id} construction",
                                        ext_rigid_offset, int_rigid_offset, ext_rigid_height, int_rigid_height,
                                        ext_rigid_r, int_rigid_r, mat_int_finish, concrete_thick_in, height_ag)

    if not assembly_r.nil?
      Constructions.check_surface_assembly_rvalue(runner, [surface], inside_film, nil, assembly_r, match)
    end

    return surface.adjacentFoundation.get
  end

  def self.add_foundation_slab(runner, model, spaces, slab, slab_exp_perim,
                               slab_area, z_origin, kiva_foundation)

    slab_tot_perim = slab_exp_perim
    if slab_tot_perim**2 - 16.0 * slab_area <= 0
      # Cannot construct rectangle with this perimeter/area. Some of the
      # perimeter is presumably not exposed, so bump up perimeter value.
      slab_tot_perim = Math.sqrt(16.0 * slab_area)
    end
    sqrt_term = [slab_tot_perim**2 - 16.0 * slab_area, 0.0].max
    slab_length = slab_tot_perim / 4.0 + Math.sqrt(sqrt_term) / 4.0
    slab_width = slab_tot_perim / 4.0 - Math.sqrt(sqrt_term) / 4.0

    vertices = Geometry.create_floor_vertices(slab_length, slab_width, z_origin, @default_azimuths)
    surface = OpenStudio::Model::Surface.new(vertices, model)
    surface.setName(slab.id)
    surface.setSurfaceType('Floor')
    surface.setOutsideBoundaryCondition('Foundation')
    surface.additionalProperties.setFeature('SurfaceType', 'Slab')
    set_surface_interior(model, spaces, surface, slab)
    surface.setSunExposure('NoSun')
    surface.setWindExposure('NoWind')

    slab_perim_r = slab.perimeter_insulation_r_value
    slab_perim_depth = slab.perimeter_insulation_depth
    if (slab_perim_r == 0) || (slab_perim_depth == 0)
      slab_perim_r = 0
      slab_perim_depth = 0
    end

    if slab.under_slab_insulation_spans_entire_slab
      slab_whole_r = slab.under_slab_insulation_r_value
      slab_under_r = 0
      slab_under_width = 0
    else
      slab_under_r = slab.under_slab_insulation_r_value
      slab_under_width = slab.under_slab_insulation_width
      if (slab_under_r == 0) || (slab_under_width == 0)
        slab_under_r = 0
        slab_under_width = 0
      end
      slab_whole_r = 0
    end
    if slab_under_r + slab_whole_r > 0
      slab_gap_r = 5.0 # Assume gap insulation when insulation under slab is present
    else
      slab_gap_r = 0
    end

    mat_carpet = nil
    if (slab.carpet_fraction > 0) && (slab.carpet_r_value > 0)
      mat_carpet = Material.CoveringBare(slab.carpet_fraction,
                                         slab.carpet_r_value)
    end

    Constructions.apply_foundation_slab(runner, model, surface, "#{slab.id} construction",
                                        slab_under_r, slab_under_width, slab_gap_r, slab_perim_r,
                                        slab_perim_depth, slab_whole_r, slab.thickness,
                                        slab_exp_perim, mat_carpet, kiva_foundation)

    return surface.adjacentFoundation.get
  end

  def self.add_conditioned_floor_area(runner, model, spaces)
    # Check if we need to add floors between conditioned spaces (e.g., between first
    # and second story or conditioned basement ceiling).
    # This ensures that the E+ reported Conditioned Floor Area is correct.

    sum_cfa = 0.0
    @hpxml.frame_floors.each do |frame_floor|
      next unless frame_floor.is_floor
      next unless [HPXML::LocationLivingSpace, HPXML::LocationBasementConditioned].include?(frame_floor.interior_adjacent_to) ||
                  [HPXML::LocationLivingSpace, HPXML::LocationBasementConditioned].include?(frame_floor.exterior_adjacent_to)

      sum_cfa += frame_floor.area
    end
    @hpxml.slabs.each do |slab|
      next unless [HPXML::LocationLivingSpace, HPXML::LocationBasementConditioned].include? slab.interior_adjacent_to

      sum_cfa += slab.area
    end

    addtl_cfa = @cfa - sum_cfa

    fail if addtl_cfa < -1.0 # Allow some rounding; EPvalidator.xml should prevent this

    return unless addtl_cfa > 1.0 # Allow some rounding

    floor_width = Math::sqrt(addtl_cfa)
    floor_length = addtl_cfa / floor_width
    z_origin = @foundation_top + 8.0 * (@ncfl_ag - 1)

    # Add floor surface
    vertices = Geometry.create_floor_vertices(floor_length, floor_width, z_origin, @default_azimuths)
    floor_surface = OpenStudio::Model::Surface.new(vertices, model)

    floor_surface.setSunExposure('NoSun')
    floor_surface.setWindExposure('NoWind')
    floor_surface.setName('inferred conditioned floor')
    floor_surface.setSurfaceType('Floor')
    floor_surface.setSpace(create_or_get_space(model, spaces, HPXML::LocationLivingSpace))
    floor_surface.setOutsideBoundaryCondition('Adiabatic')
    floor_surface.additionalProperties.setFeature('SurfaceType', 'InferredFloor')
    floor_surface.additionalProperties.setFeature('Tilt', 0.0)

    # Add ceiling surface
    vertices = Geometry.create_ceiling_vertices(floor_length, floor_width, z_origin, @default_azimuths)
    ceiling_surface = OpenStudio::Model::Surface.new(vertices, model)

    ceiling_surface.setSunExposure('NoSun')
    ceiling_surface.setWindExposure('NoWind')
    ceiling_surface.setName('inferred conditioned ceiling')
    ceiling_surface.setSurfaceType('RoofCeiling')
    ceiling_surface.setSpace(create_or_get_space(model, spaces, HPXML::LocationLivingSpace))
    ceiling_surface.setOutsideBoundaryCondition('Adiabatic')
    ceiling_surface.additionalProperties.setFeature('SurfaceType', 'InferredCeiling')
    ceiling_surface.additionalProperties.setFeature('Tilt', 0.0)

    if not @cond_bsmnt_surfaces.empty?
      # assuming added ceiling is in conditioned basement
      @cond_bsmnt_surfaces << ceiling_surface
    end

    # Apply Construction
    apply_adiabatic_construction(runner, model, [floor_surface, ceiling_surface], 'floor')
  end

  def self.add_thermal_mass(runner, model, spaces)
    cfa_basement = @hpxml.slabs.select { |s| s.interior_adjacent_to == HPXML::LocationBasementConditioned }.map { |s| s.area }.sum(0.0)
    if @apply_ashrae140_assumptions
      # 1024 ft2 of interior partition wall mass, no furniture mass
      mat_int_finish = Material.InteriorFinishMaterial(HPXML::InteriorFinishGypsumBoard, 0.5)
      partition_frac_of_cfa = (1024.0 * 2) / @cfa # Ratio of exposed partition wall area (both sides) to conditioned floor area
      basement_frac_of_cfa = cfa_basement / @cfa
      Constructions.apply_partition_walls(runner, model, 'PartitionWallConstruction', mat_int_finish, partition_frac_of_cfa,
                                          basement_frac_of_cfa, @cond_bsmnt_surfaces, spaces[HPXML::LocationLivingSpace])
    else
      mat_int_finish = Material.InteriorFinishMaterial(HPXML::InteriorFinishGypsumBoard, 0.5)
      partition_frac_of_cfa = 1.0 # Ratio of exposed partition wall area (both sides) to conditioned floor area
      basement_frac_of_cfa = cfa_basement / @cfa
      Constructions.apply_partition_walls(runner, model, 'PartitionWallConstruction', mat_int_finish, partition_frac_of_cfa,
                                          basement_frac_of_cfa, @cond_bsmnt_surfaces, spaces[HPXML::LocationLivingSpace])

      mass_lb_per_sqft = 8.0
      density_lb_per_cuft = 40.0
      mat = BaseMaterial.Wood
      Constructions.apply_furniture(runner, model, mass_lb_per_sqft, density_lb_per_cuft, mat,
                                    basement_frac_of_cfa, @cond_bsmnt_surfaces, spaces[HPXML::LocationLivingSpace])
    end
  end

  def self.add_shading_schedule(runner, model, weather)
    # Use BAHSP cooling season, and not year-round or user-specified cooling season, to ensure windows use appropriate interior shading factors
    default_heating_months, @default_cooling_months = HVAC.get_default_heating_and_cooling_seasons(weather)

    # Create cooling season schedule
    clg_season_sch = MonthWeekdayWeekendSchedule.new(model, 'cooling season schedule', Array.new(24, 1), Array.new(24, 1), @default_cooling_months, Constants.ScheduleTypeLimitsFraction)
    @clg_ssn_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
    @clg_ssn_sensor.setName('cool_season')
    @clg_ssn_sensor.setKeyName(clg_season_sch.schedule.name.to_s)
  end

  def self.add_windows(runner, model, spaces, weather)
    # We already stored @fraction_of_windows_operable, so lets remove the
    # fraction_operable properties from windows and re-collapse the enclosure
    # so as to prevent potentially modeling multiple identical windows in E+,
    # which can increase simulation runtime.
    @hpxml.windows.each do |window|
      window.fraction_operable = nil
    end
    @hpxml.collapse_enclosure_surfaces()

    shading_group = nil
    shading_schedules = {}
    shading_ems = { sensors: {}, program: nil }

    surfaces = []
    @hpxml.windows.each_with_index do |window, i|
      window_height = 4.0 # ft, default

      overhang_depth = nil
      if (not window.overhangs_depth.nil?) && (window.overhangs_depth > 0)
        overhang_depth = window.overhangs_depth
        overhang_distance_to_top = window.overhangs_distance_to_top_of_window
        overhang_distance_to_bottom = window.overhangs_distance_to_bottom_of_window
        window_height = overhang_distance_to_bottom - overhang_distance_to_top
      end

      window_length = window.area / window_height
      z_origin = @foundation_top

      if window.is_exterior

        # Create parent surface slightly bigger than window
        vertices = Geometry.create_wall_vertices(window_length, window_height, z_origin, window.azimuth, add_buffer: true)
        surface = OpenStudio::Model::Surface.new(vertices, model)

        surface.additionalProperties.setFeature('Length', window_length)
        surface.additionalProperties.setFeature('Azimuth', window.azimuth)
        surface.additionalProperties.setFeature('Tilt', 90.0)
        surface.additionalProperties.setFeature('SurfaceType', 'Window')
        surface.setName("surface #{window.id}")
        surface.setSurfaceType('Wall')
        set_surface_interior(model, spaces, surface, window.wall)

        vertices = Geometry.create_wall_vertices(window_length, window_height, z_origin, window.azimuth)
        sub_surface = OpenStudio::Model::SubSurface.new(vertices, model)
        sub_surface.setName(window.id)
        sub_surface.setSurface(surface)
        sub_surface.setSubSurfaceType('FixedWindow')

        set_subsurface_exterior(surface, spaces, model, window.wall)
        surfaces << surface

        if not overhang_depth.nil?
          overhang = sub_surface.addOverhang(UnitConversions.convert(overhang_depth, 'ft', 'm'), UnitConversions.convert(overhang_distance_to_top, 'ft', 'm'))
          overhang.get.setName("#{sub_surface.name} - #{Constants.ObjectNameOverhangs}")
        end

        # Apply construction
        Constructions.apply_window(runner, model, sub_surface, 'WindowConstruction', window.ufactor, window.shgc)

        # Apply interior/exterior shading (as needed)
        shading_vertices = Geometry.create_wall_vertices(window_length, window_height, z_origin, window.azimuth)
        shading_group = Constructions.apply_window_skylight_shading(model, window, i, shading_vertices, surface, sub_surface, shading_group,
                                                                    shading_schedules, shading_ems, Constants.ObjectNameWindowShade, @default_cooling_months)
      else
        # Window is on an interior surface, which E+ does not allow. Model
        # as a door instead so that we can get the appropriate conduction
        # heat transfer; there is no solar gains anyway.

        # Create parent surface slightly bigger than window
        vertices = Geometry.create_wall_vertices(window_length, window_height, z_origin, window.azimuth, add_buffer: true)
        surface = OpenStudio::Model::Surface.new(vertices, model)

        surface.additionalProperties.setFeature('Length', window_length)
        surface.additionalProperties.setFeature('Azimuth', window.azimuth)
        surface.additionalProperties.setFeature('Tilt', 90.0)
        surface.additionalProperties.setFeature('SurfaceType', 'Door')
        surface.setName("surface #{window.id}")
        surface.setSurfaceType('Wall')
        set_surface_interior(model, spaces, surface, window.wall)

        vertices = Geometry.create_wall_vertices(window_length, window_height, z_origin, window.azimuth)
        sub_surface = OpenStudio::Model::SubSurface.new(vertices, model)
        sub_surface.setName(window.id)
        sub_surface.setSurface(surface)
        sub_surface.setSubSurfaceType('Door')

        set_subsurface_exterior(surface, spaces, model, window.wall)
        surfaces << surface

        # Apply construction
        inside_film = Material.AirFilmVertical
        outside_film = Material.AirFilmVertical
        Constructions.apply_door(runner, model, [sub_surface], 'Window', window.ufactor, inside_film, outside_film)
      end
    end

    apply_adiabatic_construction(runner, model, surfaces, 'wall')
  end

  def self.add_skylights(runner, model, spaces, weather)
    surfaces = []

    shading_group = nil
    shading_schedules = {}
    shading_ems = { sensors: {}, program: nil }

    @hpxml.skylights.each_with_index do |skylight, i|
      tilt = skylight.roof.pitch / 12.0
      width = Math::sqrt(skylight.area)
      length = skylight.area / width
      z_origin = @walls_top + 0.5 * Math.sin(Math.atan(tilt)) * width

      # Create parent surface slightly bigger than skylight
      vertices = Geometry.create_roof_vertices(length, width, z_origin, skylight.azimuth, tilt, add_buffer: true)
      surface = OpenStudio::Model::Surface.new(vertices, model)
      surface.additionalProperties.setFeature('Length', length)
      surface.additionalProperties.setFeature('Width', width)
      surface.additionalProperties.setFeature('Azimuth', skylight.azimuth)
      surface.additionalProperties.setFeature('Tilt', tilt)
      surface.additionalProperties.setFeature('SurfaceType', 'Skylight')
      surface.setName("surface #{skylight.id}")
      surface.setSurfaceType('RoofCeiling')
      surface.setSpace(create_or_get_space(model, spaces, HPXML::LocationLivingSpace)) # Ensures it is included in Manual J sizing
      surface.setOutsideBoundaryCondition('Outdoors') # cannot be adiabatic because subsurfaces won't be created
      surfaces << surface

      vertices = Geometry.create_roof_vertices(length, width, z_origin, skylight.azimuth, tilt)
      sub_surface = OpenStudio::Model::SubSurface.new(vertices, model)
      sub_surface.setName(skylight.id)
      sub_surface.setSurface(surface)
      sub_surface.setSubSurfaceType('Skylight')

      # Apply construction
      Constructions.apply_skylight(runner, model, sub_surface, 'SkylightConstruction', skylight.ufactor, skylight.shgc)

      # Apply interior/exterior shading (as needed)
      shading_vertices = Geometry.create_roof_vertices(length, width, z_origin, skylight.azimuth, tilt)
      shading_group = Constructions.apply_window_skylight_shading(model, skylight, i, shading_vertices, surface, sub_surface, shading_group,
                                                                  shading_schedules, shading_ems, Constants.ObjectNameSkylightShade, @default_cooling_months)
    end

    apply_adiabatic_construction(runner, model, surfaces, 'roof')
  end

  def self.add_doors(runner, model, spaces)
    surfaces = []
    @hpxml.doors.each do |door|
      door_height = 6.67 # ft
      door_length = door.area / door_height
      z_origin = @foundation_top

      # Create parent surface slightly bigger than door
      vertices = Geometry.create_wall_vertices(door_length, door_height, z_origin, door.azimuth, add_buffer: true)
      surface = OpenStudio::Model::Surface.new(vertices, model)

      surface.additionalProperties.setFeature('Length', door_length)
      surface.additionalProperties.setFeature('Azimuth', door.azimuth)
      surface.additionalProperties.setFeature('Tilt', 90.0)
      surface.additionalProperties.setFeature('SurfaceType', 'Door')
      surface.setName("surface #{door.id}")
      surface.setSurfaceType('Wall')
      set_surface_interior(model, spaces, surface, door.wall)

      vertices = Geometry.create_wall_vertices(door_length, door_height, z_origin, door.azimuth)
      sub_surface = OpenStudio::Model::SubSurface.new(vertices, model)
      sub_surface.setName(door.id)
      sub_surface.setSurface(surface)
      sub_surface.setSubSurfaceType('Door')

      set_subsurface_exterior(surface, spaces, model, door.wall)
      surfaces << surface

      # Apply construction
      ufactor = 1.0 / door.r_value
      inside_film = Material.AirFilmVertical
      if door.wall.is_exterior
        outside_film = Material.AirFilmOutside
      else
        outside_film = Material.AirFilmVertical
      end
      Constructions.apply_door(runner, model, [sub_surface], 'Door', ufactor, inside_film, outside_film)
    end

    apply_adiabatic_construction(runner, model, surfaces, 'wall')
  end

  def self.apply_adiabatic_construction(runner, model, surfaces, type)
    # Arbitrary construction for heat capacitance.
    # Only applies to surfaces where outside boundary conditioned is
    # adiabatic or surface net area is near zero.
    return if surfaces.empty?

    if type == 'wall'
      mat_int_finish = Material.InteriorFinishMaterial(HPXML::InteriorFinishGypsumBoard, 0.5)
      mat_ext_finish = Material.ExteriorFinishMaterial(HPXML::SidingTypeWood)
      Constructions.apply_wood_stud_wall(runner, model, surfaces, 'AdiabaticWallConstruction',
                                         0, 1, 3.5, true, 0.1, mat_int_finish, 0, 99, mat_ext_finish,
                                         Material.AirFilmVertical, Material.AirFilmVertical)
    elsif type == 'floor'
      Constructions.apply_floor(runner, model, surfaces, 'AdiabaticFloorConstruction',
                                0, 1, 0.07, 5.5, 0.75, 99, Material.CoveringBare,
                                Material.AirFilmFloorReduced, Material.AirFilmFloorReduced)
    elsif type == 'roof'
      Constructions.apply_open_cavity_roof(runner, model, surfaces, 'AdiabaticRoofConstruction',
                                           0, 1, 7.25, 0.07, 7.25, 0.75, 99,
                                           Material.RoofMaterial(HPXML::RoofTypeAsphaltShingles),
                                           false, Material.AirFilmOutside,
                                           Material.AirFilmRoof(Geometry.get_roof_pitch(surfaces)), nil)
    end
  end

  def self.add_hot_water_and_appliances(runner, model, weather, spaces)
    # Assign spaces
    @hpxml.clothes_washers.each do |clothes_washer|
      clothes_washer.additional_properties.space = get_space_from_location(clothes_washer.location, 'ClothesWasher', model, spaces)
    end
    @hpxml.clothes_dryers.each do |clothes_dryer|
      clothes_dryer.additional_properties.space = get_space_from_location(clothes_dryer.location, 'ClothesDryer', model, spaces)
    end
    @hpxml.dishwashers.each do |dishwasher|
      dishwasher.additional_properties.space = get_space_from_location(dishwasher.location, 'Dishwasher', model, spaces)
    end
    @hpxml.refrigerators.each do |refrigerator|
      refrigerator.additional_properties.space = get_space_from_location(refrigerator.location, 'Refrigerator', model, spaces)
    end
    @hpxml.freezers.each do |freezer|
      freezer.additional_properties.space = get_space_from_location(freezer.location, 'Freezer', model, spaces)
    end
    @hpxml.cooking_ranges.each do |cooking_range|
      cooking_range.additional_properties.space = get_space_from_location(cooking_range.location, 'CookingRange', model, spaces)
    end

    # Distribution
    if @hpxml.water_heating_systems.size > 0
      hot_water_distribution = @hpxml.hot_water_distributions[0]
    end

    # Solar thermal system
    solar_thermal_system = nil
    if @hpxml.solar_thermal_systems.size > 0
      solar_thermal_system = @hpxml.solar_thermal_systems[0]
    end

    # Water Heater
    has_uncond_bsmnt = @hpxml.has_space_type(HPXML::LocationBasementUnconditioned)
    @hpxml.water_heating_systems.each do |water_heating_system|
      loc_space, loc_schedule = get_space_or_schedule_from_location(water_heating_system.location, 'WaterHeatingSystem', model, spaces)

      ec_adj = HotWaterAndAppliances.get_dist_energy_consumption_adjustment(has_uncond_bsmnt, @cfa, @ncfl, water_heating_system, hot_water_distribution)

      if water_heating_system.water_heater_type == HPXML::WaterHeaterTypeStorage

        Waterheater.apply_tank(model, loc_space, loc_schedule, water_heating_system, ec_adj,
                               @dhw_map, @hvac_map, solar_thermal_system)

      elsif water_heating_system.water_heater_type == HPXML::WaterHeaterTypeTankless

        Waterheater.apply_tankless(model, loc_space, loc_schedule, water_heating_system, ec_adj,
                                   @nbeds, @dhw_map, @hvac_map, solar_thermal_system)

      elsif water_heating_system.water_heater_type == HPXML::WaterHeaterTypeHeatPump

        living_zone = spaces[HPXML::LocationLivingSpace].thermalZone.get

        Waterheater.apply_heatpump(model, runner, loc_space, loc_schedule, weather, water_heating_system, ec_adj,
                                   @dhw_map, @hvac_map, solar_thermal_system, living_zone)

      elsif [HPXML::WaterHeaterTypeCombiStorage, HPXML::WaterHeaterTypeCombiTankless].include? water_heating_system.water_heater_type

        Waterheater.apply_combi(model, runner, loc_space, loc_schedule, water_heating_system, ec_adj,
                                @dhw_map, @hvac_map, solar_thermal_system)

      else

        fail "Unhandled water heater (#{water_heating_system.water_heater_type})."

      end
    end

    # Hot water fixtures and appliances
    HotWaterAndAppliances.apply(model, runner, @hpxml, weather, spaces, hot_water_distribution,
                                solar_thermal_system, @eri_version, @dhw_map, @schedules_file)

    if (not solar_thermal_system.nil?) && (not solar_thermal_system.collector_area.nil?) # Detailed solar water heater
      loc_space, loc_schedule = get_space_or_schedule_from_location(solar_thermal_system.water_heating_system.location, 'WaterHeatingSystem', model, spaces)
      Waterheater.apply_solar_thermal(model, loc_space, loc_schedule, solar_thermal_system, @dhw_map)
    end

    # Add combi-system EMS program with water use equipment information
    Waterheater.apply_combi_system_EMS(model, @dhw_map, @hpxml.water_heating_systems)
  end

  def self.add_cooling_system(runner, model, spaces)
    living_zone = spaces[HPXML::LocationLivingSpace].thermalZone.get

    HVAC.get_hpxml_hvac_systems(@hpxml).each do |hvac_system|
      next if hvac_system[:cooling].nil?
      next unless hvac_system[:cooling].is_a? HPXML::CoolingSystem

      cooling_system = hvac_system[:cooling]
      heating_system = hvac_system[:heating]

      check_distribution_system(cooling_system.distribution_system, cooling_system.cooling_system_type)

      # Calculate cooling sequential load fractions
      sequential_cool_load_fracs = HVAC.calc_sequential_load_fractions(cooling_system.fraction_cool_load_served.to_f, @remaining_cool_load_frac, @cooling_days)
      @remaining_cool_load_frac -= cooling_system.fraction_cool_load_served.to_f

      # Calculate heating sequential load fractions
      if not heating_system.nil?
        sequential_heat_load_fracs = HVAC.calc_sequential_load_fractions(heating_system.fraction_heat_load_served, @remaining_heat_load_frac, @heating_days)
        @remaining_heat_load_frac -= heating_system.fraction_heat_load_served
      else
        sequential_heat_load_fracs = [0]
      end

      if [HPXML::HVACTypeCentralAirConditioner].include? cooling_system.cooling_system_type

        HVAC.apply_central_air_conditioner_furnace(model, runner, cooling_system, heating_system,
                                                   sequential_cool_load_fracs, sequential_heat_load_fracs,
                                                   living_zone, @hvac_map)

      elsif [HPXML::HVACTypeRoomAirConditioner].include? cooling_system.cooling_system_type

        HVAC.apply_room_air_conditioner(model, runner, cooling_system,
                                        sequential_cool_load_fracs, living_zone,
                                        @hvac_map)

      elsif [HPXML::HVACTypeEvaporativeCooler].include? cooling_system.cooling_system_type

        HVAC.apply_evaporative_cooler(model, runner, cooling_system,
                                      sequential_cool_load_fracs, living_zone,
                                      @hvac_map)

      elsif [HPXML::HVACTypeMiniSplitAirConditioner].include? cooling_system.cooling_system_type

        HVAC.apply_mini_split_air_conditioner(model, runner, cooling_system,
                                              sequential_cool_load_fracs,
                                              living_zone, @hvac_map)
      end
    end
  end

  def self.add_heating_system(runner, model, spaces)
    living_zone = spaces[HPXML::LocationLivingSpace].thermalZone.get

    HVAC.get_hpxml_hvac_systems(@hpxml).each do |hvac_system|
      next if hvac_system[:heating].nil?
      next unless hvac_system[:heating].is_a? HPXML::HeatingSystem

      cooling_system = hvac_system[:cooling]
      heating_system = hvac_system[:heating]

      check_distribution_system(heating_system.distribution_system, heating_system.heating_system_type)

      if (heating_system.heating_system_type == HPXML::HVACTypeFurnace) && (not cooling_system.nil?)
        next # Already processed combined AC+furnace
      end

      # Calculate heating sequential load fractions
      sequential_heat_load_fracs = HVAC.calc_sequential_load_fractions(heating_system.fraction_heat_load_served, @remaining_heat_load_frac, @heating_days)
      @remaining_heat_load_frac -= heating_system.fraction_heat_load_served

      if [HPXML::HVACTypeFurnace].include? heating_system.heating_system_type

        HVAC.apply_central_air_conditioner_furnace(model, runner, nil, heating_system,
                                                   [0], sequential_heat_load_fracs,
                                                   living_zone, @hvac_map)

      elsif [HPXML::HVACTypeBoiler].include? heating_system.heating_system_type

        HVAC.apply_boiler(model, runner, heating_system,
                          sequential_heat_load_fracs, living_zone, @hvac_map)

      elsif [HPXML::HVACTypeElectricResistance].include? heating_system.heating_system_type

        HVAC.apply_electric_baseboard(model, runner, heating_system,
                                      sequential_heat_load_fracs, living_zone, @hvac_map)

      elsif [HPXML::HVACTypeStove,
             HPXML::HVACTypePortableHeater,
             HPXML::HVACTypeFixedHeater,
             HPXML::HVACTypeWallFurnace,
             HPXML::HVACTypeFloorFurnace,
             HPXML::HVACTypeFireplace].include? heating_system.heating_system_type

        HVAC.apply_unit_heater(model, runner, heating_system,
                               sequential_heat_load_fracs, living_zone, @hvac_map)
      end
    end
  end

  def self.add_heat_pump(runner, model, weather, spaces)
    living_zone = spaces[HPXML::LocationLivingSpace].thermalZone.get

    HVAC.get_hpxml_hvac_systems(@hpxml).each do |hvac_system|
      next if hvac_system[:cooling].nil?
      next unless hvac_system[:cooling].is_a? HPXML::HeatPump

      heat_pump = hvac_system[:cooling]

      check_distribution_system(heat_pump.distribution_system, heat_pump.heat_pump_type)

      # Calculate heating sequential load fractions
      sequential_heat_load_fracs = HVAC.calc_sequential_load_fractions(heat_pump.fraction_heat_load_served, @remaining_heat_load_frac, @heating_days)
      @remaining_heat_load_frac -= heat_pump.fraction_heat_load_served

      # Calculate cooling sequential load fractions
      sequential_cool_load_fracs = HVAC.calc_sequential_load_fractions(heat_pump.fraction_cool_load_served, @remaining_cool_load_frac, @cooling_days)
      @remaining_cool_load_frac -= heat_pump.fraction_cool_load_served

      if [HPXML::HVACTypeHeatPumpWaterLoopToAir].include? heat_pump.heat_pump_type

        HVAC.apply_water_loop_to_air_heat_pump(model, runner, heat_pump,
                                               sequential_heat_load_fracs, sequential_cool_load_fracs,
                                               living_zone, @hvac_map)

      elsif [HPXML::HVACTypeHeatPumpAirToAir].include? heat_pump.heat_pump_type

        HVAC.apply_central_air_to_air_heat_pump(model, runner, heat_pump,
                                                sequential_heat_load_fracs, sequential_cool_load_fracs,
                                                living_zone, @hvac_map)

      elsif [HPXML::HVACTypeHeatPumpMiniSplit].include? heat_pump.heat_pump_type

        HVAC.apply_mini_split_heat_pump(model, runner, heat_pump,
                                        sequential_heat_load_fracs, sequential_cool_load_fracs,
                                        living_zone, @hvac_map)

      elsif [HPXML::HVACTypeHeatPumpGroundToAir].include? heat_pump.heat_pump_type

        HVAC.apply_ground_to_air_heat_pump(model, runner, weather, heat_pump,
                                           sequential_heat_load_fracs, sequential_cool_load_fracs,
                                           living_zone, @hvac_map)

      end
    end
  end

  def self.add_ideal_system(runner, model, spaces, epw_path)
    # Adds an ideal air system as needed to meet the load under certain circumstances:
    # 1. the sum of fractions load served is less than 1, or
    # 2. there are non-year-round HVAC seasons, or
    # 3. we're using an ideal air system for e.g. ASHRAE 140 loads calculation.
    # The energy transferred by this ideal air system is not counted towards unmet loads.
    living_zone = spaces[HPXML::LocationLivingSpace].thermalZone.get
    obj_name = Constants.ObjectNameIdealAirSystem

    if @apply_ashrae140_assumptions && (@hpxml.total_fraction_heat_load_served + @hpxml.total_fraction_heat_load_served == 0.0)
      cooling_load_frac = 1.0
      heating_load_frac = 1.0
      if @apply_ashrae140_assumptions
        if epw_path.end_with? 'USA_CO_Colorado.Springs-Peterson.Field.724660_TMY3.epw'
          cooling_load_frac = 0.0
        elsif epw_path.end_with? 'USA_NV_Las.Vegas-McCarran.Intl.AP.723860_TMY3.epw'
          heating_load_frac = 0.0
        else
          fail 'Unexpected weather file for ASHRAE 140 run.'
        end
      end
      HVAC.apply_ideal_air_loads(model, runner, obj_name, [cooling_load_frac], [heating_load_frac],
                                 living_zone)
      return
    end

    if (@hpxml.total_fraction_heat_load_served < 1.0) && (@hpxml.total_fraction_heat_load_served > 0.0)
      sequential_heat_load_frac = @remaining_heat_load_frac - @hpxml.total_fraction_heat_load_served
      @remaining_heat_load_frac -= sequential_heat_load_frac
    else
      sequential_heat_load_frac = 0.0
    end

    if (@hpxml.total_fraction_cool_load_served < 1.0) && (@hpxml.total_fraction_cool_load_served > 0.0)
      sequential_cool_load_frac = @remaining_cool_load_frac - @hpxml.total_fraction_cool_load_served
      @remaining_cool_load_frac -= sequential_cool_load_frac
    else
      sequential_cool_load_frac = 0.0
    end

    return if @heating_days.nil?

    # For periods of the year outside the HVAC season, operate this ideal air system to meet
    # 100% of the load; for all other periods, operate to meet the fraction of the load not
    # met by the HVAC system(s).
    sequential_heat_load_fracs = @heating_days.map { |d| d == 0 ? 1.0 : sequential_heat_load_frac }
    sequential_cool_load_fracs = @cooling_days.map { |d| d == 0 ? 1.0 : sequential_cool_load_frac }

    if (sequential_heat_load_fracs.sum > 0.0) || (sequential_cool_load_fracs.sum > 0.0)
      HVAC.apply_ideal_air_loads(model, runner, obj_name, sequential_cool_load_fracs, sequential_heat_load_fracs,
                                 living_zone)
    end
  end

  def self.add_residual_ideal_system(runner, model, spaces)
    # Adds a residual ideal air system to meet loads not met by all preceding HVAC systems (i.e., because
    # the HVAC systems are undersized to meet the load). This allows us to correctly calculate total
    # heating/cooling loads without having to run an additional EnergyPlus simulation solely for that purpose,
    # as well as allows us to report the unmet load (i.e., the energy transferred by this ideal air system).

    living_zone = spaces[HPXML::LocationLivingSpace].thermalZone.get
    obj_name = Constants.ObjectNameIdealAirSystemResidual

    if @remaining_cool_load_frac < 1.0
      sequential_cool_load_frac = 1.0
    else
      sequential_cool_load_frac = 0.0 # no cooling system, don't add ideal air for cooling either
    end

    if @remaining_heat_load_frac < 1.0
      sequential_heat_load_frac = 1.0
    else
      sequential_heat_load_frac = 0.0 # no heating system, don't add ideal air for heating either
    end

    if (sequential_heat_load_frac > 0.0) || (sequential_cool_load_frac > 0.0)
      # Note: Residual ideal air system is configured to run year-round; it should not depend
      # on the HVAC system availability.
      HVAC.apply_ideal_air_loads(model, runner, obj_name, [sequential_cool_load_frac], [sequential_heat_load_frac],
                                 living_zone)
    end
  end

  def self.add_setpoints(runner, model, weather, spaces)
    return if @hpxml.hvac_controls.size == 0

    hvac_control = @hpxml.hvac_controls[0]
    living_zone = spaces[HPXML::LocationLivingSpace].thermalZone.get
    has_ceiling_fan = (@hpxml.ceiling_fans.size > 0)

    HVAC.apply_setpoints(model, runner, weather, hvac_control, living_zone, has_ceiling_fan, @heating_days, @cooling_days)
  end

  def self.add_ceiling_fans(runner, model, weather, spaces)
    return if @hpxml.ceiling_fans.size == 0

    ceiling_fan = @hpxml.ceiling_fans[0]
    HVAC.apply_ceiling_fans(model, runner, weather, ceiling_fan, spaces[HPXML::LocationLivingSpace], @schedules_file)
  end

  def self.add_dehumidifiers(runner, model, spaces)
    return if @hpxml.dehumidifiers.size == 0

    HVAC.apply_dehumidifiers(model, runner, @hpxml.dehumidifiers, spaces[HPXML::LocationLivingSpace], @hvac_map)
  end

  def self.check_distribution_system(hvac_distribution, system_type)
    return if hvac_distribution.nil?

    hvac_distribution_type_map = { HPXML::HVACTypeFurnace => [HPXML::HVACDistributionTypeAir, HPXML::HVACDistributionTypeDSE],
                                   HPXML::HVACTypeBoiler => [HPXML::HVACDistributionTypeHydronic, HPXML::HVACDistributionTypeAir, HPXML::HVACDistributionTypeDSE],
                                   HPXML::HVACTypeCentralAirConditioner => [HPXML::HVACDistributionTypeAir, HPXML::HVACDistributionTypeDSE],
                                   HPXML::HVACTypeEvaporativeCooler => [HPXML::HVACDistributionTypeAir, HPXML::HVACDistributionTypeDSE],
                                   HPXML::HVACTypeMiniSplitAirConditioner => [HPXML::HVACDistributionTypeAir, HPXML::HVACDistributionTypeDSE],
                                   HPXML::HVACTypeHeatPumpAirToAir => [HPXML::HVACDistributionTypeAir, HPXML::HVACDistributionTypeDSE],
                                   HPXML::HVACTypeHeatPumpMiniSplit => [HPXML::HVACDistributionTypeAir, HPXML::HVACDistributionTypeDSE],
                                   HPXML::HVACTypeHeatPumpGroundToAir => [HPXML::HVACDistributionTypeAir, HPXML::HVACDistributionTypeDSE],
                                   HPXML::HVACTypeHeatPumpWaterLoopToAir => [HPXML::HVACDistributionTypeAir, HPXML::HVACDistributionTypeDSE] }

    if not hvac_distribution_type_map[system_type].include? hvac_distribution.distribution_system_type
      # validator.rb only checks that a HVAC distribution system of the correct type (for the given HVAC system) exists
      # in the HPXML file, not that it is attached to this HVAC system. So here we perform the more rigorous check.
      fail "Incorrect HVAC distribution system type for HVAC type: '#{system_type}'. Should be one of: #{hvac_distribution_type_map[system_type]}"
    end
  end

  def self.add_mels(runner, model, spaces)
    # Misc
    @hpxml.plug_loads.each do |plug_load|
      if plug_load.plug_load_type == HPXML::PlugLoadTypeOther
        obj_name = Constants.ObjectNameMiscPlugLoads
      elsif plug_load.plug_load_type == HPXML::PlugLoadTypeTelevision
        obj_name = Constants.ObjectNameMiscTelevision
      elsif plug_load.plug_load_type == HPXML::PlugLoadTypeElectricVehicleCharging
        obj_name = Constants.ObjectNameMiscElectricVehicleCharging
      elsif plug_load.plug_load_type == HPXML::PlugLoadTypeWellPump
        obj_name = Constants.ObjectNameMiscWellPump
      end
      if obj_name.nil?
        runner.registerWarning("Unexpected plug load type '#{plug_load.plug_load_type}'. The plug load will not be modeled.")
        next
      end

      MiscLoads.apply_plug(model, plug_load, obj_name, spaces[HPXML::LocationLivingSpace], @apply_ashrae140_assumptions, @schedules_file)
    end
  end

  def self.add_mfls(runner, model, spaces)
    # Misc
    @hpxml.fuel_loads.each do |fuel_load|
      if fuel_load.fuel_load_type == HPXML::FuelLoadTypeGrill
        obj_name = Constants.ObjectNameMiscGrill
      elsif fuel_load.fuel_load_type == HPXML::FuelLoadTypeLighting
        obj_name = Constants.ObjectNameMiscLighting
      elsif fuel_load.fuel_load_type == HPXML::FuelLoadTypeFireplace
        obj_name = Constants.ObjectNameMiscFireplace
      end
      if obj_name.nil?
        runner.registerWarning("Unexpected fuel load type '#{fuel_load.fuel_load_type}'. The fuel load will not be modeled.")
        next
      end

      MiscLoads.apply_fuel(model, fuel_load, obj_name, spaces[HPXML::LocationLivingSpace], @schedules_file)
    end
  end

  def self.add_lighting(runner, model, epw_file, spaces)
    Lighting.apply(runner, model, epw_file, spaces, @hpxml.lighting_groups,
                   @hpxml.lighting, @eri_version, @schedules_file)
  end

  def self.add_pools_and_hot_tubs(runner, model, spaces)
    @hpxml.pools.each do |pool|
      next if pool.type == HPXML::TypeNone

      MiscLoads.apply_pool_or_hot_tub_heater(model, pool, Constants.ObjectNameMiscPoolHeater, spaces[HPXML::LocationLivingSpace], @schedules_file)
      MiscLoads.apply_pool_or_hot_tub_pump(model, pool, Constants.ObjectNameMiscPoolPump, spaces[HPXML::LocationLivingSpace], @schedules_file)
    end

    @hpxml.hot_tubs.each do |hot_tub|
      next if hot_tub.type == HPXML::TypeNone

      MiscLoads.apply_pool_or_hot_tub_heater(model, hot_tub, Constants.ObjectNameMiscHotTubHeater, spaces[HPXML::LocationLivingSpace], @schedules_file)
      MiscLoads.apply_pool_or_hot_tub_pump(model, hot_tub, Constants.ObjectNameMiscHotTubPump, spaces[HPXML::LocationLivingSpace], @schedules_file)
    end
  end

  def self.add_airflow(runner, model, weather, spaces)
    # Ducts
    duct_systems = {}
    @hpxml.hvac_distributions.each do |hvac_distribution|
      next unless hvac_distribution.distribution_system_type == HPXML::HVACDistributionTypeAir

      air_ducts = create_ducts(runner, model, hvac_distribution, spaces)
      next if air_ducts.empty?

      # Connect AirLoopHVACs to ducts
      added_ducts = false
      hvac_distribution.hvac_systems.each do |hvac_system|
        @hvac_map[hvac_system.id].each do |object|
          next unless object.is_a?(OpenStudio::Model::AirLoopHVAC) || object.is_a?(OpenStudio::Model::ZoneHVACFourPipeFanCoil)

          if duct_systems[air_ducts].nil?
            duct_systems[air_ducts] = object
            added_ducts = true
          elsif duct_systems[air_ducts] != object
            # Multiple air loops associated with this duct system, treat
            # as separate duct systems.
            air_ducts2 = create_ducts(runner, model, hvac_distribution, spaces)
            duct_systems[air_ducts2] = object
            added_ducts = true
          end
        end
      end
      if not added_ducts
        fail 'Unexpected error adding ducts to model.'
      end
    end

    Airflow.apply(model, runner, weather, spaces, @hpxml, @cfa, @nbeds,
                  @ncfl_ag, duct_systems, @clg_ssn_sensor, @hvac_map, @eri_version,
                  @frac_windows_operable, @apply_ashrae140_assumptions, @schedules_file)
  end

  def self.create_ducts(runner, model, hvac_distribution, spaces)
    air_ducts = []

    # Duct leakage (supply/return => [value, units])
    leakage_to_outside = { HPXML::DuctTypeSupply => [0.0, nil],
                           HPXML::DuctTypeReturn => [0.0, nil] }
    hvac_distribution.duct_leakage_measurements.each do |duct_leakage_measurement|
      next unless [HPXML::UnitsCFM25, HPXML::UnitsPercent].include?(duct_leakage_measurement.duct_leakage_units) && (duct_leakage_measurement.duct_leakage_total_or_to_outside == 'to outside')
      next if duct_leakage_measurement.duct_type.nil?

      leakage_to_outside[duct_leakage_measurement.duct_type] = [duct_leakage_measurement.duct_leakage_value, duct_leakage_measurement.duct_leakage_units]
    end

    # Duct location, R-value, Area
    total_unconditioned_duct_area = { HPXML::DuctTypeSupply => 0.0,
                                      HPXML::DuctTypeReturn => 0.0 }
    hvac_distribution.ducts.each do |ducts|
      next if [HPXML::LocationLivingSpace, HPXML::LocationBasementConditioned].include? ducts.duct_location
      next if ducts.duct_type.nil?

      # Calculate total duct area in unconditioned spaces
      total_unconditioned_duct_area[ducts.duct_type] += ducts.duct_surface_area
    end

    # Create duct objects
    hvac_distribution.ducts.each do |ducts|
      next if [HPXML::LocationLivingSpace, HPXML::LocationBasementConditioned].include? ducts.duct_location
      next if ducts.duct_type.nil?
      next if total_unconditioned_duct_area[ducts.duct_type] <= 0

      duct_loc_space, duct_loc_schedule = get_space_or_schedule_from_location(ducts.duct_location, 'Duct', model, spaces)

      # Apportion leakage to individual ducts by surface area
      duct_leakage_value = leakage_to_outside[ducts.duct_type][0] * ducts.duct_surface_area / total_unconditioned_duct_area[ducts.duct_type]
      duct_leakage_units = leakage_to_outside[ducts.duct_type][1]

      duct_leakage_cfm = nil
      duct_leakage_frac = nil
      if duct_leakage_units == HPXML::UnitsCFM25
        duct_leakage_cfm = duct_leakage_value
      elsif duct_leakage_units == HPXML::UnitsPercent
        duct_leakage_frac = duct_leakage_value
      else
        fail "#{ducts.duct_type.capitalize} ducts exist but leakage was not specified for distribution system '#{hvac_distribution.id}'."
      end

      air_ducts << Duct.new(ducts.duct_type, duct_loc_space, duct_loc_schedule, duct_leakage_frac, duct_leakage_cfm, ducts.duct_surface_area, ducts.duct_insulation_r_value)
    end

    # If all ducts are in conditioned space, model leakage as going to outside
    [HPXML::DuctTypeSupply, HPXML::DuctTypeReturn].each do |duct_side|
      next unless (leakage_to_outside[duct_side][0] > 0) && (total_unconditioned_duct_area[duct_side] == 0)

      duct_area = 0.0
      duct_rvalue = 0.0
      duct_loc_space = nil # outside
      duct_loc_schedule = nil # outside
      duct_leakage_value = leakage_to_outside[duct_side][0]
      duct_leakage_units = leakage_to_outside[duct_side][1]

      duct_leakage_cfm = nil
      duct_leakage_frac = nil
      if duct_leakage_units == HPXML::UnitsCFM25
        duct_leakage_cfm = duct_leakage_value
      elsif duct_leakage_units == HPXML::UnitsPercent
        duct_leakage_frac = duct_leakage_value
      else
        fail "#{duct_side.capitalize} ducts exist but leakage was not specified for distribution system '#{hvac_distribution.id}'."
      end

      air_ducts << Duct.new(duct_side, duct_loc_space, duct_loc_schedule, duct_leakage_frac, duct_leakage_cfm, duct_area, duct_rvalue)
    end

    return air_ducts
  end

  def self.add_photovoltaics(runner, model)
    @hpxml.pv_systems.each do |pv_system|
      PV.apply(model, @nbeds, pv_system)
    end
  end

  def self.add_generators(runner, model)
    @hpxml.generators.each do |generator|
      Generator.apply(model, @nbeds, generator)
    end
  end

  def self.add_additional_properties(runner, model, hpxml_path, building_id)
    # Store some data for use in reporting measure
    additionalProperties = model.getBuilding.additionalProperties
    additionalProperties.setFeature('hpxml_path', hpxml_path)
    additionalProperties.setFeature('building_id', building_id.to_s)
    additionalProperties.setFeature('hvac_map', map_to_string(@hvac_map))
    additionalProperties.setFeature('dhw_map', map_to_string(@dhw_map))
  end

  def self.map_to_string(map)
    map_str = {}
    map.each do |sys_id, objects|
      object_name_list = []
      objects.uniq.each do |object|
        object_name_list << object.name.to_s
      end
      map_str[sys_id] = object_name_list if object_name_list.size > 0
    end
    return map_str.to_s
  end

  def self.add_loads_output(runner, model, spaces, add_component_loads)
    living_zone = spaces[HPXML::LocationLivingSpace].thermalZone.get

    liv_load_sensors, intgain_dehumidifier = add_total_loads_output(runner, model, living_zone)
    return unless add_component_loads

    add_component_loads_output(runner, model, living_zone, liv_load_sensors, intgain_dehumidifier)
  end

  def self.add_total_loads_output(runner, model, living_zone)
    liv_load_sensors = {}
    liv_load_sensors[:htg] = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Heating:EnergyTransfer:Zone:#{living_zone.name.to_s.upcase}")
    liv_load_sensors[:htg].setName('htg_load_liv')
    liv_load_sensors[:clg] = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Cooling:EnergyTransfer:Zone:#{living_zone.name.to_s.upcase}")
    liv_load_sensors[:clg].setName('clg_load_liv')

    tot_load_sensors = {}
    tot_load_sensors[:htg] = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Heating:EnergyTransfer')
    tot_load_sensors[:htg].setName('htg_load_tot')
    tot_load_sensors[:clg] = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Cooling:EnergyTransfer')
    tot_load_sensors[:clg].setName('clg_load_tot')

    # Need to adjusted E+ EnergyTransfer meters for dehumidifiers
    intgain_dehumidifier = nil
    model.getZoneHVACDehumidifierDXs.each do |e|
      next unless e.thermalZone.get.name.to_s == living_zone.name.to_s

      { 'Zone Dehumidifier Sensible Heating Energy' => 'ig_dehumidifier' }.each do |var, name|
        intgain_dehumidifier = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
        intgain_dehumidifier.setName(name)
        intgain_dehumidifier.setKeyName(e.name.to_s)
      end
    end

    # EMS program
    program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    program.setName(Constants.ObjectNameTotalLoadsProgram)
    program.addLine('Set loads_htg_tot = 0')
    program.addLine('Set loads_clg_tot = 0')
    program.addLine("If #{liv_load_sensors[:htg].name} > 0")
    s = "  Set loads_htg_tot = #{tot_load_sensors[:htg].name} - #{tot_load_sensors[:clg].name}"
    if not intgain_dehumidifier.nil?
      s += " - #{intgain_dehumidifier.name}"
    end
    program.addLine(s)
    program.addLine("ElseIf #{liv_load_sensors[:clg].name} > 0")
    s = "  Set loads_clg_tot = #{tot_load_sensors[:clg].name} - #{tot_load_sensors[:htg].name}"
    if not intgain_dehumidifier.nil?
      s += " + #{intgain_dehumidifier.name}"
    end
    program.addLine(s)
    program.addLine('EndIf')

    # EMS calling manager
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName("#{program.name} calling manager")
    program_calling_manager.setCallingPoint('EndOfZoneTimestepAfterZoneReporting')
    program_calling_manager.addProgram(program)

    return liv_load_sensors, intgain_dehumidifier
  end

  def self.add_component_loads_output(runner, model, living_zone, liv_load_sensors, intgain_dehumidifier)
    # Prevent certain objects (e.g., OtherEquipment) from being counted towards both, e.g., ducts and internal gains
    objects_already_processed = []

    # EMS Sensors: Surfaces, SubSurfaces, InternalMass

    surfaces_sensors = { walls: [],
                         rim_joists: [],
                         foundation_walls: [],
                         floors: [],
                         slabs: [],
                         ceilings: [],
                         roofs: [],
                         windows: [],
                         doors: [],
                         skylights: [],
                         internal_mass: [] }

    # Output diagnostics needed for some output variables used below
    output_diagnostics = model.getOutputDiagnostics
    output_diagnostics.addKey('DisplayAdvancedReportVariables')

    area_tolerance = UnitConversions.convert(1.0, 'ft^2', 'm^2')

    model.getSurfaces.sort.each_with_index do |s, idx|
      next unless s.space.get.thermalZone.get.name.to_s == living_zone.name.to_s

      surface_type = s.additionalProperties.getFeatureAsString('SurfaceType')
      if not surface_type.is_initialized
        fail "Could not identify surface type for surface: '#{s.name}'."
      end

      surface_type = surface_type.get

      s.subSurfaces.each do |ss|
        key = { 'Window' => :windows,
                'Door' => :doors,
                'Skylight' => :skylights }[surface_type]
        fail "Unexpected subsurface for component loads: '#{ss.name}'." if key.nil?

        if (surface_type == 'Window') || (surface_type == 'Skylight')
          vars = { 'Surface Window Transmitted Solar Radiation Energy' => 'ss_trans_in',
                   'Surface Window Shortwave from Zone Back Out Window Heat Transfer Rate' => 'ss_back_out',
                   'Surface Window Total Glazing Layers Absorbed Shortwave Radiation Rate' => 'ss_sw_abs',
                   'Surface Window Total Glazing Layers Absorbed Solar Radiation Energy' => 'ss_sol_abs',
                   'Surface Inside Face Initial Transmitted Diffuse Transmitted Out Window Solar Radiation Rate' => 'ss_trans_out',
                   'Surface Inside Face Convection Heat Gain Energy' => 'ss_conv',
                   'Surface Inside Face Internal Gains Radiation Heat Gain Energy' => 'ss_ig',
                   'Surface Inside Face Net Surface Thermal Radiation Heat Gain Energy' => 'ss_surf' }
        else
          vars = { 'Surface Inside Face Solar Radiation Heat Gain Energy' => 'ss_sol',
                   'Surface Inside Face Lights Radiation Heat Gain Energy' => 'ss_lgt',
                   'Surface Inside Face Convection Heat Gain Energy' => 'ss_conv',
                   'Surface Inside Face Internal Gains Radiation Heat Gain Energy' => 'ss_ig',
                   'Surface Inside Face Net Surface Thermal Radiation Heat Gain Energy' => 'ss_surf' }
        end

        surfaces_sensors[key] << []
        vars.each do |var, name|
          sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
          sensor.setName(name)
          sensor.setKeyName(ss.name.to_s)
          surfaces_sensors[key][-1] << sensor
        end
      end

      next if s.netArea < area_tolerance # Skip parent surfaces (of subsurfaces) that have near zero net area

      key = { 'FoundationWall' => :foundation_walls,
              'RimJoist' => :rim_joists,
              'Wall' => :walls,
              'Slab' => :slabs,
              'Floor' => :floors,
              'Ceiling' => :ceilings,
              'Roof' => :roofs,
              'InferredCeiling' => :internal_mass,
              'InferredFloor' => :internal_mass }[surface_type]
      fail "Unexpected surface for component loads: '#{s.name}'." if key.nil?

      surfaces_sensors[key] << []
      { 'Surface Inside Face Convection Heat Gain Energy' => 's_conv',
        'Surface Inside Face Internal Gains Radiation Heat Gain Energy' => 's_ig',
        'Surface Inside Face Solar Radiation Heat Gain Energy' => 's_sol',
        'Surface Inside Face Lights Radiation Heat Gain Energy' => 's_lgt',
        'Surface Inside Face Net Surface Thermal Radiation Heat Gain Energy' => 's_surf' }.each do |var, name|
        sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
        sensor.setName(name)
        sensor.setKeyName(s.name.to_s)
        surfaces_sensors[key][-1] << sensor
      end
    end

    model.getInternalMasss.sort.each do |m|
      next unless m.space.get.thermalZone.get.name.to_s == living_zone.name.to_s

      surfaces_sensors[:internal_mass] << []
      { 'Surface Inside Face Convection Heat Gain Energy' => 'im_conv',
        'Surface Inside Face Internal Gains Radiation Heat Gain Energy' => 'im_ig',
        'Surface Inside Face Solar Radiation Heat Gain Energy' => 'im_sol',
        'Surface Inside Face Lights Radiation Heat Gain Energy' => 'im_lgt',
        'Surface Inside Face Net Surface Thermal Radiation Heat Gain Energy' => 'im_surf' }.each do |var, name|
        sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
        sensor.setName(name)
        sensor.setKeyName(m.name.to_s)
        surfaces_sensors[:internal_mass][-1] << sensor
      end
    end

    # EMS Sensors: Infiltration, Mechanical Ventilation, Natural Ventilation, Whole House Fan

    air_gain_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Infiltration Sensible Heat Gain Energy')
    air_gain_sensor.setName('airflow_gain')
    air_gain_sensor.setKeyName(living_zone.name.to_s)

    air_loss_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Infiltration Sensible Heat Loss Energy')
    air_loss_sensor.setName('airflow_loss')
    air_loss_sensor.setKeyName(living_zone.name.to_s)

    mechvent_sensors = []
    model.getElectricEquipments.sort.each do |o|
      next unless o.name.to_s.start_with? Constants.ObjectNameMechanicalVentilation

      { 'Electric Equipment Convective Heating Energy' => 'mv_conv',
        'Electric Equipment Radiant Heating Energy' => 'mv_rad' }.each do |var, name|
        mechvent_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
        mechvent_sensor.setName(name)
        mechvent_sensor.setKeyName(o.name.to_s)
        mechvent_sensors << mechvent_sensor
        objects_already_processed << o
      end
    end
    model.getOtherEquipments.sort.each do |o|
      next unless o.name.to_s.start_with? Constants.ObjectNameMechanicalVentilationHouseFan

      { 'Other Equipment Convective Heating Energy' => 'mv_conv',
        'Other Equipment Radiant Heating Energy' => 'mv_rad' }.each do |var, name|
        mechvent_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
        mechvent_sensor.setName(name)
        mechvent_sensor.setKeyName(o.name.to_s)
        mechvent_sensors << mechvent_sensor
        objects_already_processed << o
      end
    end

    infil_flow_actuators = []
    natvent_flow_actuators = []
    whf_flow_actuators = []

    model.getEnergyManagementSystemActuators.each do |actuator|
      next unless (actuator.actuatedComponentType == 'Zone Infiltration') && (actuator.actuatedComponentControlType == 'Air Exchange Flow Rate')

      if actuator.name.to_s.start_with? Constants.ObjectNameInfiltration.gsub(' ', '_')
        infil_flow_actuators << actuator
      elsif actuator.name.to_s.start_with? Constants.ObjectNameNaturalVentilation.gsub(' ', '_')
        natvent_flow_actuators << actuator
      elsif actuator.name.to_s.start_with? Constants.ObjectNameWholeHouseFan.gsub(' ', '_')
        whf_flow_actuators << actuator
      end
    end
    if (infil_flow_actuators.size != 1) || (natvent_flow_actuators.size != 1) || (whf_flow_actuators.size != 1)
      fail 'Could not find actuator for component loads.'
    end

    infil_flow_actuator = infil_flow_actuators[0]
    natvent_flow_actuator = natvent_flow_actuators[0]
    whf_flow_actuator = whf_flow_actuators[0]

    # EMS Sensors: Ducts

    ducts_sensors = []
    ducts_mix_gain_sensor = nil
    ducts_mix_loss_sensor = nil

    has_duct_zone_mixing = false
    living_zone.airLoopHVACs.sort.each do |airloop|
      living_zone.zoneMixing.each do |zone_mix|
        next unless zone_mix.name.to_s.start_with? airloop.name.to_s.gsub(' ', '_')

        has_duct_zone_mixing = true
      end
    end

    if has_duct_zone_mixing
      ducts_mix_gain_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Mixing Sensible Heat Gain Energy')
      ducts_mix_gain_sensor.setName('duct_mix_gain')
      ducts_mix_gain_sensor.setKeyName(living_zone.name.to_s)

      ducts_mix_loss_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Mixing Sensible Heat Loss Energy')
      ducts_mix_loss_sensor.setName('duct_mix_loss')
      ducts_mix_loss_sensor.setKeyName(living_zone.name.to_s)
    end

    # Duct losses
    model.getOtherEquipments.sort.each do |o|
      next if objects_already_processed.include? o

      is_duct_load = o.additionalProperties.getFeatureAsBoolean(Constants.IsDuctLoadForReport)
      next unless is_duct_load.is_initialized

      objects_already_processed << o
      next unless is_duct_load.get

      ducts_sensors << []
      { 'Other Equipment Convective Heating Energy' => 'ducts_conv',
        'Other Equipment Radiant Heating Energy' => 'ducts_rad' }.each do |var, name|
        ducts_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
        ducts_sensor.setName(name)
        ducts_sensor.setKeyName(o.name.to_s)
        ducts_sensors[-1] << ducts_sensor
      end
    end

    # EMS Sensors: Internal Gains

    intgains_sensors = []

    model.getElectricEquipments.sort.each do |o|
      next unless o.space.get.thermalZone.get.name.to_s == living_zone.name.to_s
      next if objects_already_processed.include? o

      intgains_sensors << []
      { 'Electric Equipment Convective Heating Energy' => 'ig_ee_conv',
        'Electric Equipment Radiant Heating Energy' => 'ig_ee_rad' }.each do |var, name|
        intgains_elec_equip_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
        intgains_elec_equip_sensor.setName(name)
        intgains_elec_equip_sensor.setKeyName(o.name.to_s)
        intgains_sensors[-1] << intgains_elec_equip_sensor
      end
    end

    model.getOtherEquipments.sort.each do |o|
      next unless o.space.get.thermalZone.get.name.to_s == living_zone.name.to_s
      next if objects_already_processed.include? o

      intgains_sensors << []
      { 'Other Equipment Convective Heating Energy' => 'ig_oe_conv',
        'Other Equipment Radiant Heating Energy' => 'ig_oe_rad' }.each do |var, name|
        intgains_other_equip_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
        intgains_other_equip_sensor.setName(name)
        intgains_other_equip_sensor.setKeyName(o.name.to_s)
        intgains_sensors[-1] << intgains_other_equip_sensor
      end
    end

    model.getLightss.sort.each do |e|
      next unless e.space.get.thermalZone.get.name.to_s == living_zone.name.to_s

      intgains_sensors << []
      { 'Lights Convective Heating Energy' => 'ig_lgt_conv',
        'Lights Radiant Heating Energy' => 'ig_lgt_rad',
        'Lights Visible Radiation Heating Energy' => 'ig_lgt_vis' }.each do |var, name|
        intgains_lights_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
        intgains_lights_sensor.setName(name)
        intgains_lights_sensor.setKeyName(e.name.to_s)
        intgains_sensors[-1] << intgains_lights_sensor
      end
    end

    model.getPeoples.sort.each do |e|
      next unless e.space.get.thermalZone.get.name.to_s == living_zone.name.to_s

      intgains_sensors << []
      { 'People Convective Heating Energy' => 'ig_ppl_conv',
        'People Radiant Heating Energy' => 'ig_ppl_rad' }.each do |var, name|
        intgains_people = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var)
        intgains_people.setName(name)
        intgains_people.setKeyName(e.name.to_s)
        intgains_sensors[-1] << intgains_people
      end
    end

    if not intgain_dehumidifier.nil?
      intgains_sensors[-1] << intgain_dehumidifier
    end

    intgains_dhw_sensors = {}

    (model.getWaterHeaterMixeds + model.getWaterHeaterStratifieds).sort.each do |wh|
      next unless wh.ambientTemperatureThermalZone.is_initialized
      next unless wh.ambientTemperatureThermalZone.get.name.to_s == living_zone.name.to_s

      dhw_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Water Heater Heat Loss Energy')
      dhw_sensor.setName('dhw_loss')
      dhw_sensor.setKeyName(wh.name.to_s)

      if wh.is_a? OpenStudio::Model::WaterHeaterMixed
        oncycle_loss = wh.onCycleLossFractiontoThermalZone
        offcycle_loss = wh.offCycleLossFractiontoThermalZone
      else
        oncycle_loss = wh.skinLossFractiontoZone
        offcycle_loss = wh.offCycleFlueLossFractiontoZone
      end

      dhw_rtf_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Water Heater Runtime Fraction')
      dhw_rtf_sensor.setName('dhw_rtf')
      dhw_rtf_sensor.setKeyName(wh.name.to_s)

      intgains_dhw_sensors[dhw_sensor] = [offcycle_loss, oncycle_loss, dhw_rtf_sensor]
    end

    nonsurf_names = ['intgains', 'infil', 'mechvent', 'natvent', 'whf', 'ducts']

    # EMS program
    program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    program.setName(Constants.ObjectNameComponentLoadsProgram)

    # EMS program: Surfaces
    surfaces_sensors.each do |k, surface_sensors|
      program.addLine("Set hr_#{k} = 0")
      surface_sensors.each do |sensors|
        s = "Set hr_#{k} = hr_#{k}"
        sensors.each do |sensor|
          # remove ss_net if switch
          if sensor.name.to_s.start_with?('ss_net', 'ss_sol_abs', 'ss_trans_in')
            s += " - #{sensor.name}"
          elsif sensor.name.to_s.start_with?('ss_sw_abs', 'ss_trans_out', 'ss_back_out')
            s += " + #{sensor.name} * ZoneTimestep * 3600"
          else
            s += " + #{sensor.name}"
          end
        end
        program.addLine(s) if sensors.size > 0
      end
    end

    # EMS program: Internal gains
    program.addLine('Set hr_intgains = 0')
    intgains_sensors.each do |intgain_sensors|
      s = 'Set hr_intgains = hr_intgains'
      intgain_sensors.each do |sensor|
        s += " - #{sensor.name}"
      end
      program.addLine(s) if intgain_sensors.size > 0
    end
    intgains_dhw_sensors.each do |sensor, vals|
      off_loss, on_loss, rtf_sensor = vals
      program.addLine("Set hr_intgains = hr_intgains + #{sensor.name} * (#{off_loss}*(1-#{rtf_sensor.name}) + #{on_loss}*#{rtf_sensor.name})") # Water heater tank losses to zone
    end

    # EMS program: Infiltration, Natural Ventilation, Mechanical Ventilation, Ducts
    program.addLine("Set hr_airflow_rate = #{infil_flow_actuator.name} + #{natvent_flow_actuator.name} + #{whf_flow_actuator.name}")
    program.addLine('If hr_airflow_rate > 0')
    program.addLine("  Set hr_infil = (#{air_loss_sensor.name} - #{air_gain_sensor.name}) * #{infil_flow_actuator.name} / hr_airflow_rate") # Airflow heat attributed to infiltration
    program.addLine("  Set hr_natvent = (#{air_loss_sensor.name} - #{air_gain_sensor.name}) * #{natvent_flow_actuator.name} / hr_airflow_rate") # Airflow heat attributed to natural ventilation
    program.addLine("  Set hr_whf = (#{air_loss_sensor.name} - #{air_gain_sensor.name}) * #{whf_flow_actuator.name} / hr_airflow_rate") # Airflow heat attributed to whole house fan
    program.addLine('Else')
    program.addLine('  Set hr_infil = 0')
    program.addLine('  Set hr_natvent = 0')
    program.addLine('  Set hr_whf = 0')
    program.addLine('  Set hr_mechvent = 0')
    program.addLine('EndIf')
    program.addLine('Set hr_mechvent = 0')
    mechvent_sensors.each do |sensor|
      program.addLine("Set hr_mechvent = hr_mechvent - #{sensor.name}")
    end
    program.addLine('Set hr_ducts = 0')
    ducts_sensors.each do |duct_sensors|
      s = 'Set hr_ducts = hr_ducts'
      duct_sensors.each do |sensor|
        s += " - #{sensor.name}"
      end
      program.addLine(s) if duct_sensors.size > 0
    end
    if (not ducts_mix_loss_sensor.nil?) && (not ducts_mix_gain_sensor.nil?)
      program.addLine("Set hr_ducts = hr_ducts + (#{ducts_mix_loss_sensor.name} - #{ducts_mix_gain_sensor.name})")
    end

    # EMS program: Heating vs Cooling logic
    program.addLine('Set htg_mode = 0')
    program.addLine('Set clg_mode = 0')
    program.addLine("If (#{liv_load_sensors[:htg].name} > 0)") # Assign hour to heating if heating load
    program.addLine('  Set htg_mode = 1')
    program.addLine("ElseIf (#{liv_load_sensors[:clg].name} > 0)") # Assign hour to cooling if cooling load
    program.addLine('  Set clg_mode = 1')
    program.addLine("ElseIf (#{@clg_ssn_sensor.name} > 0)") # No load, assign hour to cooling if in cooling season definition (Note: natural ventilation & whole house fan only operate during the cooling season)
    program.addLine('  Set clg_mode = 1')
    program.addLine('Else') # No load, assign hour to heating if not in cooling season definition
    program.addLine('  Set htg_mode = 1')
    program.addLine('EndIf')

    [:htg, :clg].each do |mode|
      if mode == :htg
        sign = ''
      else
        sign = '-'
      end
      surfaces_sensors.keys.each do |k|
        program.addLine("Set loads_#{mode}_#{k} = #{sign}hr_#{k} * #{mode}_mode")
      end
      nonsurf_names.each do |nonsurf_name|
        program.addLine("Set loads_#{mode}_#{nonsurf_name} = #{sign}hr_#{nonsurf_name} * #{mode}_mode")
      end
    end

    # EMS calling manager
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName("#{program.name} calling manager")
    program_calling_manager.setCallingPoint('EndOfZoneTimestepAfterZoneReporting')
    program_calling_manager.addProgram(program)
  end

  def self.add_output_control_files(runner, model)
    return if @debug

    # Disable various output files
    ocf = model.getOutputControlFiles
    ocf.setOutputAUDIT(false)
    ocf.setOutputBND(false)
    ocf.setOutputEIO(false)
    ocf.setOutputESO(false)
    ocf.setOutputMDD(false)
    ocf.setOutputMTD(false)
    ocf.setOutputMTR(false)
    ocf.setOutputRDD(false)
    ocf.setOutputSHD(false)
    ocf.setOutputTabular(false)
  end

  def self.add_ems_debug_output(runner, model)
    oems = model.getOutputEnergyManagementSystem
    oems.setActuatorAvailabilityDictionaryReporting('Verbose')
    oems.setInternalVariableAvailabilityDictionaryReporting('Verbose')
    oems.setEMSRuntimeLanguageDebugOutputLevel('Verbose')
  end

  def self.set_surface_interior(model, spaces, surface, hpxml_surface)
    interior_adjacent_to = hpxml_surface.interior_adjacent_to
    if [HPXML::LocationBasementConditioned].include? interior_adjacent_to
      surface.setSpace(create_or_get_space(model, spaces, HPXML::LocationLivingSpace))
      @cond_bsmnt_surfaces << surface
    else
      surface.setSpace(create_or_get_space(model, spaces, interior_adjacent_to))
    end
  end

  def self.set_surface_exterior(model, spaces, surface, hpxml_surface)
    exterior_adjacent_to = hpxml_surface.exterior_adjacent_to
    interior_adjacent_to = hpxml_surface.interior_adjacent_to
    is_adiabatic = hpxml_surface.is_adiabatic
    if exterior_adjacent_to == HPXML::LocationOutside
      surface.setOutsideBoundaryCondition('Outdoors')
    elsif exterior_adjacent_to == HPXML::LocationGround
      surface.setOutsideBoundaryCondition('Foundation')
    elsif is_adiabatic
      surface.setOutsideBoundaryCondition('Adiabatic')
    elsif [HPXML::LocationOtherHeatedSpace, HPXML::LocationOtherMultifamilyBufferSpace,
           HPXML::LocationOtherNonFreezingSpace, HPXML::LocationOtherHousingUnit].include? exterior_adjacent_to
      set_surface_otherside_coefficients(surface, exterior_adjacent_to, model, spaces)
    elsif exterior_adjacent_to == HPXML::LocationBasementConditioned
      surface.createAdjacentSurface(create_or_get_space(model, spaces, HPXML::LocationLivingSpace))
      @cond_bsmnt_surfaces << surface.adjacentSurface.get
    else
      surface.createAdjacentSurface(create_or_get_space(model, spaces, exterior_adjacent_to))
    end
  end

  def self.set_surface_otherside_coefficients(surface, exterior_adjacent_to, model, spaces)
    if spaces[exterior_adjacent_to].nil?
      # Create E+ other side coefficient object
      otherside_object = OpenStudio::Model::SurfacePropertyOtherSideCoefficients.new(model)
      otherside_object.setName(exterior_adjacent_to)
      otherside_object.setCombinedConvectiveRadiativeFilmCoefficient(UnitConversions.convert(1.0 / Material.AirFilmVertical.rvalue, 'Btu/(hr*ft^2*F)', 'W/(m^2*K)'))
      # Schedule of space temperature, can be shared with water heater/ducts
      sch = get_space_temperature_schedule(model, exterior_adjacent_to, spaces)
      otherside_object.setConstantTemperatureSchedule(sch)
      surface.setSurfacePropertyOtherSideCoefficients(otherside_object)
      spaces[exterior_adjacent_to] = otherside_object
    else
      surface.setSurfacePropertyOtherSideCoefficients(spaces[exterior_adjacent_to])
    end
    surface.setSunExposure('NoSun')
    surface.setWindExposure('NoWind')
  end

  def self.get_space_temperature_schedule(model, location, spaces)
    # Create outside boundary schedules to be actuated by EMS,
    # can be shared by any surface, duct adjacent to / located in those spaces

    # return if already exists
    model.getScheduleConstants.each do |sch|
      next unless sch.name.to_s == location

      return sch
    end

    sch = OpenStudio::Model::ScheduleConstant.new(model)
    sch.setName(location)

    space_values = Geometry.get_temperature_scheduled_space_values(location)

    if location == HPXML::LocationOtherHeatedSpace
      # Create a sensor to get dynamic heating setpoint
      htg_sch = spaces[HPXML::LocationLivingSpace].thermalZone.get.thermostatSetpointDualSetpoint.get.heatingSetpointTemperatureSchedule.get
      sensor_htg_spt = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
      sensor_htg_spt.setName('htg_spt')
      sensor_htg_spt.setKeyName(htg_sch.name.to_s)
      space_values[:temp_min] = sensor_htg_spt.name.to_s
    end

    # Schedule type limits compatible
    schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
    schedule_type_limits.setUnitType('Temperature')
    sch.setScheduleTypeLimits(schedule_type_limits)

    # Sensors
    if space_values[:indoor_weight] > 0
      sensor_ia = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Air Temperature')
      sensor_ia.setName('cond_zone_temp')
      sensor_ia.setKeyName(spaces[HPXML::LocationLivingSpace].name.to_s)
    end

    if space_values[:outdoor_weight] > 0
      sensor_oa = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Drybulb Temperature')
      sensor_oa.setName('oa_temp')
    end

    if space_values[:ground_weight] > 0
      sensor_gnd = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Surface Ground Temperature')
      sensor_gnd.setName('ground_temp')
    end

    actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(sch, *EPlus::EMSActuatorScheduleConstantValue)
    actuator.setName("#{location.gsub(' ', '_').gsub('-', '_')}_temp_sch")

    # EMS to actuate schedule
    program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    program.setName("#{location.gsub('-', '_')} Temperature Program")
    program.addLine("Set #{actuator.name} = 0.0")
    if not sensor_ia.nil?
      program.addLine("Set #{actuator.name} = #{actuator.name} + (#{sensor_ia.name} * #{space_values[:indoor_weight]})")
    end
    if not sensor_oa.nil?
      program.addLine("Set #{actuator.name} = #{actuator.name} + (#{sensor_oa.name} * #{space_values[:outdoor_weight]})")
    end
    if not sensor_gnd.nil?
      program.addLine("Set #{actuator.name} = #{actuator.name} + (#{sensor_gnd.name} * #{space_values[:ground_weight]})")
    end
    if not space_values[:temp_min].nil?
      if space_values[:temp_min].is_a? String
        min_temp_c = space_values[:temp_min]
      else
        min_temp_c = UnitConversions.convert(space_values[:temp_min], 'F', 'C')
      end
      program.addLine("If #{actuator.name} < #{min_temp_c}")
      program.addLine("Set #{actuator.name} = #{min_temp_c}")
      program.addLine('EndIf')
    end

    program_cm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_cm.setName("#{program.name} calling manager")
    program_cm.setCallingPoint('EndOfSystemTimestepAfterHVACReporting')
    program_cm.addProgram(program)

    return sch
  end

  # Returns an OS:Space, or temperature OS:Schedule for a MF space, or nil if outside
  # Should be called when the object's energy use is sensitive to ambient temperature
  # (e.g., water heaters and ducts).
  def self.get_space_or_schedule_from_location(location, object_name, model, spaces)
    return if [HPXML::LocationOtherExterior, HPXML::LocationOutside, HPXML::LocationRoofDeck].include? location

    sch = nil
    space = nil
    if [HPXML::LocationOtherHeatedSpace, HPXML::LocationOtherHousingUnit, HPXML::LocationOtherMultifamilyBufferSpace,
        HPXML::LocationOtherNonFreezingSpace, HPXML::LocationExteriorWall, HPXML::LocationUnderSlab].include? location
      # if located in spaces where we don't model a thermal zone, create and return temperature schedule
      sch = get_space_temperature_schedule(model, location, spaces)
    else
      space = get_space_from_location(location, object_name, model, spaces)
    end

    return space, sch
  end

  # Returns an OS:Space, or nil if a MF space
  # Should be called when the object's energy use is NOT sensitive to ambient temperature
  # (e.g., appliances).
  def self.get_space_from_location(location, object_name, model, spaces)
    return if [HPXML::LocationOtherHeatedSpace,
               HPXML::LocationOtherHousingUnit,
               HPXML::LocationOtherMultifamilyBufferSpace,
               HPXML::LocationOtherNonFreezingSpace].include? location

    num_orig_spaces = spaces.size

    if location == HPXML::LocationBasementConditioned
      space = create_or_get_space(model, spaces, HPXML::LocationLivingSpace)
    else
      space = create_or_get_space(model, spaces, location)
    end

    fail if spaces.size != num_orig_spaces # EPvalidator.xml should prevent this

    return space
  end

  def self.set_subsurface_exterior(surface, spaces, model, hpxml_surface)
    # Set its parent surface outside boundary condition, which will be also applied to subsurfaces through OS
    # The parent surface is entirely comprised of the subsurface.

    # Subsurface on foundation wall, set it to be adjacent to outdoors
    if hpxml_surface.exterior_adjacent_to == HPXML::LocationGround
      surface.setOutsideBoundaryCondition('Outdoors')
    else
      set_surface_exterior(model, spaces, surface, hpxml_surface)
    end
  end

  def self.get_kiva_instances(fnd_walls, slabs)
    # Identify unique Kiva foundations that are required.
    kiva_fnd_walls = []
    fnd_walls.each do |foundation_wall|
      next unless foundation_wall.is_exterior

      kiva_fnd_walls << foundation_wall
    end
    if kiva_fnd_walls.empty? # Handle slab foundation type
      kiva_fnd_walls << nil
    end

    kiva_slabs = slabs

    return kiva_fnd_walls.product(kiva_slabs)
  end

  def self.set_foundation_and_walls_top()
    @foundation_top = 0
    @hpxml.foundation_walls.each do |foundation_wall|
      top = -1 * foundation_wall.depth_below_grade + foundation_wall.height
      @foundation_top = top if top > @foundation_top
    end
    @walls_top = @foundation_top + 8.0 * @ncfl_ag
  end

  def self.set_heating_and_cooling_seasons(model)
    return if @hpxml.hvac_controls.size == 0

    hvac_control = @hpxml.hvac_controls[0]

    htg_start_month = hvac_control.seasons_heating_begin_month
    htg_start_day = hvac_control.seasons_heating_begin_day
    htg_end_month = hvac_control.seasons_heating_end_month
    htg_end_day = hvac_control.seasons_heating_end_day
    clg_start_month = hvac_control.seasons_cooling_begin_month
    clg_start_day = hvac_control.seasons_cooling_begin_day
    clg_end_month = hvac_control.seasons_cooling_end_month
    clg_end_day = hvac_control.seasons_cooling_end_day

    @heating_days = Schedule.get_daily_season(model, htg_start_month, htg_start_day, htg_end_month, htg_end_day)
    @cooling_days = Schedule.get_daily_season(model, clg_start_month, clg_start_day, clg_end_month, clg_end_day)
  end
end

# register the measure to be used by the application
HPXMLtoOpenStudio.new.registerWithApplication
