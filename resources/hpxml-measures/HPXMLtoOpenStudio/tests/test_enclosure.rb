# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'
require_relative 'util.rb'

class HPXMLtoOpenStudioEnclosureTest < MiniTest::Test
  def setup
    @root_path = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
    @sample_files_path = File.join(@root_path, 'workflow', 'sample_files')
    @tmp_hpxml_path = File.join(@sample_files_path, 'tmp.xml')
    @tmp_output_path = File.join(@sample_files_path, 'tmp_output')
    FileUtils.mkdir_p(@tmp_output_path)
  end

  def teardown
    File.delete(@tmp_hpxml_path) if File.exist? @tmp_hpxml_path
    FileUtils.rm_rf(@tmp_output_path)
  end

  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def test_roofs
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(@tmp_hpxml_path)

    # Open cavity, asphalt shingles roof
    roofs_values = [{ assembly_r: 0.1, layer_names: ['asphalt or fiberglass shingles'] },
                    { assembly_r: 5.0, layer_names: ['asphalt or fiberglass shingles', 'roof rigid ins', 'osb sheathing'] },
                    { assembly_r: 20.0, layer_names: ['asphalt or fiberglass shingles', 'roof rigid ins', 'osb sheathing'] }]

    hpxml = _create_hpxml('base.xml')
    roofs_values.each do |roof_values|
      hpxml.roofs[0].insulation_assembly_r_value = roof_values[:assembly_r]
      XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
      model, hpxml = _test_measure(args_hash)

      # Check properties
      os_surface = model.getSurfaces.select { |s| s.name.to_s.start_with? "#{hpxml.roofs[0].id}:" }[0]
      _check_surface(hpxml.roofs[0], os_surface, roof_values[:layer_names])
    end

    # Closed cavity, asphalt shingles roof
    roofs_values = [{ assembly_r: 0.1, layer_names: ['asphalt or fiberglass shingles', 'roof stud and cavity', 'gypsum board'] },
                    { assembly_r: 5.0, layer_names: ['asphalt or fiberglass shingles', 'osb sheathing', 'roof stud and cavity', 'gypsum board'] },
                    { assembly_r: 20.0, layer_names: ['asphalt or fiberglass shingles', 'roof rigid ins', 'osb sheathing', 'roof stud and cavity', 'gypsum board'] }]

    hpxml = _create_hpxml('base-atticroof-cathedral.xml')
    roofs_values.each do |roof_values|
      hpxml.roofs[0].insulation_assembly_r_value = roof_values[:assembly_r]
      XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
      model, hpxml = _test_measure(args_hash)

      # Check properties
      os_surface = model.getSurfaces.select { |s| s.name.to_s.start_with? "#{hpxml.roofs[0].id}:" }[0]
      _check_surface(hpxml.roofs[0], os_surface, roof_values[:layer_names])
    end

    # Closed cavity, Miscellaneous
    roofs_values = [
      # Slate or tile
      [{ assembly_r: 0.1, layer_names: ['slate or tile shingles', 'roof stud and cavity', 'gypsum board'] },
       { assembly_r: 5.0, layer_names: ['slate or tile shingles', 'osb sheathing', 'roof stud and cavity', 'gypsum board'] },
       { assembly_r: 20.0, layer_names: ['slate or tile shingles', 'roof rigid ins', 'osb sheathing', 'roof stud and cavity', 'gypsum board'] }],
      # Metal
      [{ assembly_r: 0.1, layer_names: ['metal surfacing', 'roof stud and cavity', 'plaster'] },
       { assembly_r: 5.0, layer_names: ['metal surfacing', 'osb sheathing', 'roof stud and cavity', 'plaster'] },
       { assembly_r: 20.0, layer_names: ['metal surfacing', 'roof rigid ins', 'osb sheathing', 'roof stud and cavity', 'plaster'] }],
      # Wood shingles
      [{ assembly_r: 0.1, layer_names: ['wood shingles or shakes', 'roof stud and cavity', 'wood'] },
       { assembly_r: 5.0, layer_names: ['wood shingles or shakes', 'osb sheathing', 'roof stud and cavity', 'wood'] },
       { assembly_r: 20.0, layer_names: ['wood shingles or shakes', 'roof rigid ins', 'osb sheathing', 'roof stud and cavity', 'wood'] }],
      # Shingles
      [{ assembly_r: 0.1, layer_names: ['shingles', 'roof stud and cavity', 'gypsum board'] },
       { assembly_r: 5.0, layer_names: ['shingles', 'osb sheathing', 'roof stud and cavity', 'gypsum board'] },
       { assembly_r: 20.0, layer_names: ['shingles', 'roof rigid ins', 'osb sheathing', 'roof stud and cavity', 'gypsum board'] }],
      # Plastic/rubber
      [{ assembly_r: 0.1, layer_names: ['plastic/rubber/synthetic sheeting', 'roof stud and cavity', 'plaster'] },
       { assembly_r: 5.0, layer_names: ['plastic/rubber/synthetic sheeting', 'osb sheathing', 'roof stud and cavity', 'plaster'] },
       { assembly_r: 20.0, layer_names: ['plastic/rubber/synthetic sheeting', 'roof rigid ins', 'osb sheathing', 'roof stud and cavity', 'plaster'] }],
      # EPS
      [{ assembly_r: 0.1, layer_names: ['expanded polystyrene sheathing', 'roof stud and cavity', 'wood'] },
       { assembly_r: 5.0, layer_names: ['expanded polystyrene sheathing', 'roof stud and cavity', 'wood'] },
       { assembly_r: 20.0, layer_names: ['expanded polystyrene sheathing', 'roof rigid ins', 'osb sheathing', 'roof stud and cavity', 'wood'] }],
      # Concrete
      [{ assembly_r: 0.1, layer_names: ['concrete', 'roof stud and cavity', 'gypsum board'] },
       { assembly_r: 5.0, layer_names: ['concrete', 'osb sheathing', 'roof stud and cavity', 'gypsum board'] },
       { assembly_r: 20.0, layer_names: ['concrete', 'roof rigid ins', 'osb sheathing', 'roof stud and cavity', 'gypsum board'] }],
      # Cool
      [{ assembly_r: 0.1, layer_names: ['cool roof', 'roof stud and cavity', 'plaster'] },
       { assembly_r: 5.0, layer_names: ['cool roof', 'osb sheathing', 'roof stud and cavity', 'plaster'] },
       { assembly_r: 20.0, layer_names: ['cool roof', 'roof rigid ins', 'osb sheathing', 'roof stud and cavity', 'plaster'] }],

    ]

    hpxml = _create_hpxml('base-enclosure-rooftypes.xml')
    for i in 0..hpxml.roofs.size - 1
      roofs_values[i].each do |roof_values|
        hpxml.roofs[i].insulation_assembly_r_value = roof_values[:assembly_r]
        XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
        model, hpxml = _test_measure(args_hash)

        # Check properties
        os_surface = model.getSurfaces.select { |s| s.name.to_s.start_with? "#{hpxml.roofs[i].id}:" }[0]
        _check_surface(hpxml.roofs[i], os_surface, roof_values[:layer_names])
      end
    end

    # Radiant Barrier
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(@tmp_hpxml_path)

    # Open cavity, asphalt shingles roof
    roofs_values = [{ assembly_r: 0.1, layer_names: ['asphalt or fiberglass shingles', 'radiant barrier'] },
                    { assembly_r: 5.0, layer_names: ['asphalt or fiberglass shingles', 'roof rigid ins', 'osb sheathing', 'radiant barrier'] },
                    { assembly_r: 20.0, layer_names: ['asphalt or fiberglass shingles', 'roof rigid ins', 'osb sheathing', 'radiant barrier'] }]

    hpxml = _create_hpxml('base-atticroof-radiant-barrier.xml')
    roofs_values.each do |roof_values|
      hpxml.roofs[0].insulation_assembly_r_value = roof_values[:assembly_r]
      XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
      model, hpxml = _test_measure(args_hash)

      # Check properties
      os_surface = model.getSurfaces.select { |s| s.name.to_s.start_with? "#{hpxml.roofs[0].id}:" }[0]
      _check_surface(hpxml.roofs[0], os_surface, roof_values[:layer_names])
    end
  end

  def test_rim_joists
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(@tmp_hpxml_path)

    # Wood siding
    rimjs_values = [{ assembly_r: 0.1, layer_names: ['wood siding', 'rim joist stud and cavity'] },
                    { assembly_r: 5.0, layer_names: ['wood siding', 'rim joist stud and cavity'] },
                    { assembly_r: 20.0, layer_names: ['wood siding', 'rim joist rigid ins', 'osb sheathing', 'rim joist stud and cavity'] }]

    hpxml = _create_hpxml('base.xml')
    rimjs_values.each do |rimj_values|
      hpxml.rim_joists[0].insulation_assembly_r_value = rimj_values[:assembly_r]
      XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
      model, hpxml = _test_measure(args_hash)

      # Check properties
      os_surface = model.getSurfaces.select { |s| s.name.to_s.start_with? "#{hpxml.rim_joists[0].id}:" }[0]
      _check_surface(hpxml.rim_joists[0], os_surface, rimj_values[:layer_names])
    end

    # Miscellaneous
    rimjs_values = [
      # Aluminum
      [{ assembly_r: 0.1, layer_names: ['aluminum siding', 'rim joist stud and cavity'] },
       { assembly_r: 5.0, layer_names: ['aluminum siding', 'osb sheathing', 'rim joist stud and cavity'] },
       { assembly_r: 20.0, layer_names: ['aluminum siding', 'rim joist rigid ins', 'osb sheathing', 'rim joist stud and cavity'] }],
      # Asbestos
      [{ assembly_r: 0.1, layer_names: ['asbestos siding', 'rim joist stud and cavity'] },
       { assembly_r: 5.0, layer_names: ['asbestos siding', 'osb sheathing', 'rim joist stud and cavity'] },
       { assembly_r: 20.0, layer_names: ['asbestos siding', 'rim joist rigid ins', 'osb sheathing', 'rim joist stud and cavity'] }],
      # Brick veneer
      [{ assembly_r: 0.1, layer_names: ['brick veneer', 'rim joist stud and cavity'] },
       { assembly_r: 5.0, layer_names: ['brick veneer', 'osb sheathing', 'rim joist stud and cavity'] },
       { assembly_r: 20.0, layer_names: ['brick veneer', 'rim joist rigid ins', 'osb sheathing', 'rim joist stud and cavity'] }],
      # Composite shingle
      [{ assembly_r: 0.1, layer_names: ['composite shingle siding', 'rim joist stud and cavity'] },
       { assembly_r: 5.0, layer_names: ['composite shingle siding', 'osb sheathing', 'rim joist stud and cavity'] },
       { assembly_r: 20.0, layer_names: ['composite shingle siding', 'rim joist rigid ins', 'osb sheathing', 'rim joist stud and cavity'] }],
      # Fiber cement
      [{ assembly_r: 0.1, layer_names: ['fiber cement siding', 'rim joist stud and cavity'] },
       { assembly_r: 5.0, layer_names: ['fiber cement siding', 'osb sheathing', 'rim joist stud and cavity'] },
       { assembly_r: 20.0, layer_names: ['fiber cement siding', 'rim joist rigid ins', 'osb sheathing', 'rim joist stud and cavity'] }],
      # Masonite
      [{ assembly_r: 0.1, layer_names: ['masonite siding', 'rim joist stud and cavity'] },
       { assembly_r: 5.0, layer_names: ['masonite siding', 'osb sheathing', 'rim joist stud and cavity'] },
       { assembly_r: 20.0, layer_names: ['masonite siding', 'rim joist rigid ins', 'osb sheathing', 'rim joist stud and cavity'] }],
      # Stucco
      [{ assembly_r: 0.1, layer_names: ['stucco', 'rim joist stud and cavity'] },
       { assembly_r: 5.0, layer_names: ['stucco', 'osb sheathing', 'rim joist stud and cavity'] },
       { assembly_r: 20.0, layer_names: ['stucco', 'rim joist rigid ins', 'osb sheathing', 'rim joist stud and cavity'] }],
      # Synthetic stucco
      [{ assembly_r: 0.1, layer_names: ['synthetic stucco', 'rim joist stud and cavity'] },
       { assembly_r: 5.0, layer_names: ['synthetic stucco', 'rim joist stud and cavity'] },
       { assembly_r: 20.0, layer_names: ['synthetic stucco', 'rim joist rigid ins', 'osb sheathing', 'rim joist stud and cavity'] }],
      # Vinyl
      [{ assembly_r: 0.1, layer_names: ['vinyl siding', 'rim joist stud and cavity'] },
       { assembly_r: 5.0, layer_names: ['vinyl siding', 'osb sheathing', 'rim joist stud and cavity'] },
       { assembly_r: 20.0, layer_names: ['vinyl siding', 'rim joist rigid ins', 'osb sheathing', 'rim joist stud and cavity'] }],
      # None
      [{ assembly_r: 0.1, layer_names: ['rim joist stud and cavity', 'rim joist stud and cavity'] }, # Note: Below grade material doubled in update_solar_absorptances()
       { assembly_r: 5.0, layer_names: ['osb sheathing', 'rim joist stud and cavity'] },
       { assembly_r: 20.0, layer_names: ['rim joist rigid ins', 'osb sheathing', 'rim joist stud and cavity'] }],
    ]

    hpxml = _create_hpxml('base-enclosure-walltypes.xml')
    for i in 0..hpxml.rim_joists.size - 1
      rimjs_values[i].each do |rimj_values|
        hpxml.rim_joists[i].insulation_assembly_r_value = rimj_values[:assembly_r]
        XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
        model, hpxml = _test_measure(args_hash)

        # Check properties
        os_surface = model.getSurfaces.select { |s| s.name.to_s.start_with? "#{hpxml.rim_joists[i].id}:" }[0]
        _check_surface(hpxml.rim_joists[i], os_surface, rimj_values[:layer_names])
      end
    end
  end

  def test_walls
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(@tmp_hpxml_path)

    # Wood Stud wall
    walls_values = [{ assembly_r: 0.1, layer_names: ['wood siding', 'wall stud and cavity', 'gypsum board'] },
                    { assembly_r: 5.0, layer_names: ['wood siding', 'osb sheathing', 'wall stud and cavity', 'gypsum board'] },
                    { assembly_r: 20.0, layer_names: ['wood siding', 'wall rigid ins', 'osb sheathing', 'wall stud and cavity', 'gypsum board'] }]

    hpxml = _create_hpxml('base.xml')
    walls_values.each do |wall_values|
      hpxml.walls[0].insulation_assembly_r_value = wall_values[:assembly_r]
      XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
      model, hpxml = _test_measure(args_hash)

      # Check properties
      os_surface = model.getSurfaces.select { |s| s.name.to_s.start_with? "#{hpxml.walls[0].id}:" }[0]
      _check_surface(hpxml.walls[0], os_surface, wall_values[:layer_names])
    end

    # Miscellaneous
    walls_values = [
      # CMU wall
      [{ assembly_r: 0.1, layer_names: ['aluminum siding', 'concrete block', 'gypsum board'] },
       { assembly_r: 5.0, layer_names: ['aluminum siding', 'wall rigid ins', 'concrete block', 'gypsum board'] },
       { assembly_r: 20.0, layer_names: ['aluminum siding', 'wall rigid ins', 'osb sheathing', 'concrete block', 'gypsum board'] }],
      # Double Stud wall
      [{ assembly_r: 0.1, layer_names: ['asbestos siding', 'wall stud and cavity', 'wall cavity', 'wall stud and cavity', 'gypsum board'] },
       { assembly_r: 5.0, layer_names: ['asbestos siding', 'osb sheathing', 'wall stud and cavity', 'wall cavity', 'wall stud and cavity', 'gypsum board'] },
       { assembly_r: 20.0, layer_names: ['asbestos siding', 'osb sheathing', 'wall stud and cavity', 'wall cavity', 'wall stud and cavity', 'gypsum board'] }],
      # ICF wall
      [{ assembly_r: 0.1, layer_names: ['brick veneer', 'wall ins form', 'wall concrete', 'wall ins form', 'gypsum composite board'] },
       { assembly_r: 5.0, layer_names: ['brick veneer', 'osb sheathing', 'wall ins form', 'wall concrete', 'wall ins form', 'gypsum composite board'] },
       { assembly_r: 20.0, layer_names: ['brick veneer', 'osb sheathing', 'wall ins form', 'wall concrete', 'wall ins form', 'gypsum composite board'] }],
      # Log wall
      [{ assembly_r: 0.1, layer_names: ['composite shingle siding', 'wall layer', 'plaster'] },
       { assembly_r: 5.0, layer_names: ['composite shingle siding', 'osb sheathing', 'wall layer', 'plaster'] },
       { assembly_r: 20.0, layer_names: ['composite shingle siding', 'wall rigid ins', 'osb sheathing', 'wall layer', 'plaster'] }],
      # SIP wall
      [{ assembly_r: 0.1, layer_names: ['fiber cement siding', 'wall spline layer', 'wall ins layer', 'wall spline layer', 'osb sheathing', 'wood'] },
       { assembly_r: 5.0, layer_names: ['fiber cement siding', 'osb sheathing', 'wall spline layer', 'wall ins layer', 'wall spline layer', 'osb sheathing', 'wood'] },
       { assembly_r: 20.0, layer_names: ['fiber cement siding', 'osb sheathing', 'wall spline layer', 'wall ins layer', 'wall spline layer', 'osb sheathing', 'wood'] }],
      # Solid Concrete wall
      [{ assembly_r: 0.1, layer_names: ['masonite siding', 'wall layer'] },
       { assembly_r: 5.0, layer_names: ['masonite siding', 'osb sheathing', 'wall layer'] },
       { assembly_r: 20.0, layer_names: ['masonite siding', 'wall rigid ins', 'osb sheathing', 'wall layer'] }],
      # Steel frame wall
      [{ assembly_r: 0.1, layer_names: ['stucco', 'wall stud and cavity', 'gypsum board'] },
       { assembly_r: 5.0, layer_names: ['stucco', 'osb sheathing', 'wall stud and cavity', 'gypsum board'] },
       { assembly_r: 20.0, layer_names: ['stucco', 'wall rigid ins', 'osb sheathing', 'wall stud and cavity', 'gypsum board'] }],
      # Stone wall
      [{ assembly_r: 0.1, layer_names: ['synthetic stucco', 'wall layer', 'gypsum board'] },
       { assembly_r: 5.0, layer_names: ['synthetic stucco', 'wall layer', 'gypsum board'] },
       { assembly_r: 20.0, layer_names: ['synthetic stucco', 'wall rigid ins', 'osb sheathing', 'wall layer', 'gypsum board'] }],
      # Straw Bale wall
      [{ assembly_r: 0.1, layer_names: ['vinyl siding', 'wall layer', 'gypsum composite board'] },
       { assembly_r: 5.0, layer_names: ['vinyl siding', 'osb sheathing', 'wall layer', 'gypsum composite board'] },
       { assembly_r: 20.0, layer_names: ['vinyl siding', 'wall rigid ins', 'osb sheathing', 'wall layer', 'gypsum composite board'] }],
      # Structural Brick wall
      [{ assembly_r: 0.1, layer_names: ['wall layer', 'plaster'] },
       { assembly_r: 5.0, layer_names: ['osb sheathing', 'wall layer', 'plaster'] },
       { assembly_r: 20.0, layer_names: ['wall rigid ins', 'osb sheathing', 'wall layer', 'plaster'] }],
      # Adobe wall
      [{ assembly_r: 0.1, layer_names: ['aluminum siding', 'wall layer', 'wood'] },
       { assembly_r: 5.0, layer_names: ['aluminum siding', 'osb sheathing', 'wall layer', 'wood'] },
       { assembly_r: 20.0, layer_names: ['aluminum siding', 'wall rigid ins', 'osb sheathing', 'wall layer', 'wood'] }],
    ]

    hpxml = _create_hpxml('base-enclosure-walltypes.xml')
    for i in 0..hpxml.walls.size - 2
      walls_values[i].each do |wall_values|
        hpxml.walls[i].insulation_assembly_r_value = wall_values[:assembly_r]
        XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
        model, hpxml = _test_measure(args_hash)

        # Check properties
        os_surface = model.getSurfaces.select { |s| s.name.to_s.start_with? "#{hpxml.walls[i].id}:" }[0]
        _check_surface(hpxml.walls[i], os_surface, wall_values[:layer_names])
      end
    end
  end

  def test_foundation_walls
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(@tmp_hpxml_path)

    # Foundation wall w/ Assembly R-values
    walls_values = [{ assembly_r: 0.1, layer_names: ['concrete'] },
                    { assembly_r: 5.0, layer_names: ['concrete', 'exterior vertical ins'] },
                    { assembly_r: 20.0, layer_names: ['concrete', 'exterior vertical ins'] }]

    hpxml = _create_hpxml('base-foundation-unconditioned-basement-assembly-r.xml')
    walls_values.each do |wall_values|
      hpxml.foundation_walls[0].insulation_assembly_r_value = wall_values[:assembly_r]
      XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
      model, hpxml = _test_measure(args_hash)

      # Check properties
      os_surface = model.getSurfaces.select { |s| s.name.to_s == hpxml.foundation_walls[0].id }[0]
      _check_surface(hpxml.foundation_walls[0], os_surface, wall_values[:layer_names])
    end

    # Foundation wall w/ Insulation Layers
    walls_values = [{ interior_r: 0.0, exterior_r: 0.0, layer_names: ['concrete'] },
                    { interior_r: 5.0, exterior_r: 0.0, layer_names: ['concrete', 'interior vertical ins'] },
                    { interior_r: 20.0, exterior_r: 0.0, layer_names: ['concrete', 'interior vertical ins'] },
                    { interior_r: 0.0, exterior_r: 5.0, layer_names: ['concrete', 'exterior vertical ins'] },
                    { interior_r: 0.0, exterior_r: 20.0, layer_names: ['concrete', 'exterior vertical ins'] },
                    { interior_r: 5.0, exterior_r: 5.0, layer_names: ['concrete', 'interior vertical ins', 'exterior vertical ins'] },
                    { interior_r: 20.0, exterior_r: 20.0, layer_names: ['concrete', 'interior vertical ins', 'exterior vertical ins'] }]

    hpxml = _create_hpxml('base-foundation-unconditioned-basement-wall-insulation.xml')
    walls_values.each do |wall_values|
      hpxml.foundation_walls[0].insulation_interior_r_value = wall_values[:interior_r]
      hpxml.foundation_walls[0].insulation_interior_distance_to_top = 0.0
      hpxml.foundation_walls[0].insulation_interior_distance_to_bottom = 8.0
      hpxml.foundation_walls[0].insulation_exterior_r_value = wall_values[:exterior_r]
      hpxml.foundation_walls[0].insulation_exterior_distance_to_top = 0.0
      hpxml.foundation_walls[0].insulation_exterior_distance_to_bottom = 8.0
      XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
      model, hpxml = _test_measure(args_hash)

      # Check properties
      os_surface = model.getSurfaces.select { |s| s.name.to_s == hpxml.foundation_walls[0].id }[0]
      _check_surface(hpxml.foundation_walls[0], os_surface, wall_values[:layer_names])
    end
  end

  def test_frame_floors
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(@tmp_hpxml_path)

    # Ceilings
    ceilings_values = [{ assembly_r: 0.1, layer_names: ['ceiling stud and cavity', 'gypsum board'] },
                       { assembly_r: 5.0, layer_names: ['ceiling stud and cavity', 'gypsum board'] },
                       { assembly_r: 20.0, layer_names: ['ceiling loosefill ins', 'ceiling stud and cavity', 'gypsum board'] }]

    hpxml = _create_hpxml('base-foundation-vented-crawlspace.xml')
    ceilings_values.each do |ceiling_values|
      hpxml.frame_floors[0].insulation_assembly_r_value = ceiling_values[:assembly_r]
      XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
      model, hpxml = _test_measure(args_hash)

      # Check properties
      os_surface = model.getSurfaces.select { |s| s.name.to_s == hpxml.frame_floors[0].id }[0]
      _check_surface(hpxml.frame_floors[0], os_surface, ceiling_values[:layer_names])
    end

    # Floors
    floors_values = [{ assembly_r: 0.1, layer_names: ['floor stud and cavity', 'floor covering'] },
                     { assembly_r: 5.0, layer_names: ['floor stud and cavity', 'osb sheathing', 'floor covering'] },
                     { assembly_r: 20.0, layer_names: ['floor stud and cavity', 'floor rigid ins', 'osb sheathing', 'floor covering'] }]

    hpxml = _create_hpxml('base-foundation-vented-crawlspace.xml')
    floors_values.each do |floor_values|
      hpxml.frame_floors[1].insulation_assembly_r_value = floor_values[:assembly_r]
      XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
      model, hpxml = _test_measure(args_hash)

      # Check properties
      os_surface = model.getSurfaces.select { |s| s.name.to_s == hpxml.frame_floors[1].id }[0]
      _check_surface(hpxml.frame_floors[1], os_surface, floor_values[:layer_names])
    end
  end

  def test_slabs
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(@tmp_hpxml_path)

    # Slab
    slabs_values = [{ perimeter_r: 0.0, under_r: 0.0, under_span: false, layer_names: ['concrete', 'floor covering'] },
                    { perimeter_r: 5.0, under_r: 0.0, under_span: false, layer_names: ['concrete', 'floor covering', 'exterior vertical ins'] },
                    { perimeter_r: 20.0, under_r: 0.0, under_span: false, layer_names: ['concrete', 'floor covering', 'exterior vertical ins'] },
                    { perimeter_r: 0.0, under_r: 5.0, under_span: false, layer_names: ['concrete', 'floor covering', 'interior horizontal ins', 'interior vertical ins'] },
                    { perimeter_r: 0.0, under_r: 20.0, under_span: false, layer_names: ['concrete', 'floor covering', 'interior horizontal ins', 'interior vertical ins'] },
                    { perimeter_r: 0.0, under_r: 5.0, under_span: true, layer_names: ['slab rigid ins', 'concrete', 'floor covering', 'interior vertical ins'] },
                    { perimeter_r: 0.0, under_r: 20.0, under_span: true, layer_names: ['slab rigid ins', 'concrete', 'floor covering', 'interior vertical ins'] },
                    { perimeter_r: 5.0, under_r: 5.0, under_span: false, layer_names: ['concrete', 'floor covering', 'interior horizontal ins', 'interior vertical ins', 'exterior vertical ins'] },
                    { perimeter_r: 20.0, under_r: 20.0, under_span: false, layer_names: ['concrete', 'floor covering', 'interior horizontal ins', 'interior vertical ins', 'exterior vertical ins'] }]

    hpxml = _create_hpxml('base-foundation-slab.xml')
    slabs_values.each do |slab_values|
      hpxml.slabs[0].perimeter_insulation_r_value = slab_values[:perimeter_r]
      hpxml.slabs[0].perimeter_insulation_depth = 2.0
      hpxml.slabs[0].under_slab_insulation_r_value = slab_values[:under_r]
      if slab_values[:under_span]
        hpxml.slabs[0].under_slab_insulation_spans_entire_slab = true
        hpxml.slabs[0].under_slab_insulation_width = nil
      else
        hpxml.slabs[0].under_slab_insulation_width = 2.0
        hpxml.slabs[0].under_slab_insulation_spans_entire_slab = nil
      end

      XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
      model, hpxml = _test_measure(args_hash)

      # Check properties
      os_surface = model.getSurfaces.select { |s| s.name.to_s == hpxml.slabs[0].id }[0]
      _check_surface(hpxml.slabs[0], os_surface, slab_values[:layer_names])
    end
  end

  def test_windows
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check window properties
    hpxml.windows.each do |window|
      os_window = model.getSubSurfaces.select { |w| w.name.to_s == window.id }[0]
      os_simple_glazing = os_window.construction.get.to_LayeredConstruction.get.getLayer(0).to_SimpleGlazing.get

      assert_equal(window.shgc, os_simple_glazing.solarHeatGainCoefficient)
      assert_in_epsilon(window.ufactor, UnitConversions.convert(os_simple_glazing.uFactor, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)'), 0.001)
    end

    # Check window shading
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-enclosure-windows-shading.xml'))
    model, hpxml = _test_measure(args_hash)

    summer_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('June'), 1, model.yearDescription.get.assumedYear)
    winter_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, model.yearDescription.get.assumedYear)

    hpxml.windows.each do |window|
      sf_summer = window.interior_shading_factor_summer
      sf_winter = window.interior_shading_factor_winter
      sf_summer *= window.exterior_shading_factor_summer unless window.exterior_shading_factor_summer.nil?
      sf_winter *= window.exterior_shading_factor_winter unless window.exterior_shading_factor_winter.nil?

      # Check shading transmittance for sky beam and sky diffuse
      os_shading_surface = model.getShadingSurfaces.select { |ss| ss.name.to_s.start_with? window.id }[0]
      if (sf_summer == 1) && (sf_winter == 1)
        assert_nil(os_shading_surface) # No shading
      else
        refute_nil(os_shading_surface) # Shading
        summer_transmittance = os_shading_surface.transmittanceSchedule.get.to_ScheduleRuleset.get.getDaySchedules(summer_date, summer_date).map { |ds| ds.values.sum }.sum
        winter_transmittance = os_shading_surface.transmittanceSchedule.get.to_ScheduleRuleset.get.getDaySchedules(winter_date, winter_date).map { |ds| ds.values.sum }.sum
        assert_equal(sf_summer, summer_transmittance)
        assert_equal(sf_winter, winter_transmittance)
      end

      # Check subsurface view factor to ground
      subsurface_view_factor = 0.5
      window_actuator = model.getEnergyManagementSystemActuators.select { |w| w.actuatedComponent.get.name.to_s == window.id }[0]
      program_values = get_ems_values(model.getEnergyManagementSystemPrograms, 'fixedwindow view factor to ground program')
      assert_equal(subsurface_view_factor, program_values["#{window_actuator.name}"][0])
    end
  end

  def test_skylights
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-enclosure-skylights.xml'))
    model, hpxml = _test_measure(args_hash)

    # Check skylight properties
    hpxml.skylights.each do |skylight|
      os_skylight = model.getSubSurfaces.select { |w| w.name.to_s == skylight.id }[0]
      os_simple_glazing = os_skylight.construction.get.to_LayeredConstruction.get.getLayer(0).to_SimpleGlazing.get

      assert_equal(skylight.shgc, os_simple_glazing.solarHeatGainCoefficient)
      assert_in_epsilon(skylight.ufactor / 1.2, UnitConversions.convert(os_simple_glazing.uFactor, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)'), 0.001)
    end

    # Check skylight shading
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-enclosure-skylights-shading.xml'))
    model, hpxml = _test_measure(args_hash)

    summer_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('June'), 1, model.yearDescription.get.assumedYear)
    winter_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, model.yearDescription.get.assumedYear)

    hpxml.skylights.each do |skylight|
      sf_summer = skylight.interior_shading_factor_summer
      sf_winter = skylight.interior_shading_factor_winter
      sf_summer *= skylight.exterior_shading_factor_summer unless skylight.exterior_shading_factor_summer.nil?
      sf_winter *= skylight.exterior_shading_factor_winter unless skylight.exterior_shading_factor_winter.nil?

      # Check shading transmittance for sky beam and sky diffuse
      os_shading_surface = model.getShadingSurfaces.select { |ss| ss.name.to_s.start_with? skylight.id }[0]
      if (sf_summer == 1) && (sf_winter == 1)
        assert_nil(os_shading_surface) # No shading
      else
        refute_nil(os_shading_surface) # Shading
        summer_transmittance = os_shading_surface.transmittanceSchedule.get.to_ScheduleRuleset.get.getDaySchedules(summer_date, summer_date).map { |ds| ds.values.sum }.sum
        winter_transmittance = os_shading_surface.transmittanceSchedule.get.to_ScheduleRuleset.get.getDaySchedules(winter_date, winter_date).map { |ds| ds.values.sum }.sum
        assert_equal(sf_summer, summer_transmittance)
        assert_equal(sf_winter, winter_transmittance)
      end

      # Check subsurface view factor to ground
      subsurface_view_factor = 0.05 # 6:12 pitch
      skylight_actuator = model.getEnergyManagementSystemActuators.select { |w| w.actuatedComponent.get.name.to_s == skylight.id }[0]
      program_values = get_ems_values(model.getEnergyManagementSystemPrograms, 'skylight view factor to ground program')
      assert_equal(subsurface_view_factor, program_values["#{skylight_actuator.name}"][0])
    end
  end

  def test_doors
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(@tmp_hpxml_path)

    # Door
    doors_values = [{ assembly_r: 0.1, layer_names: ['door material'] },
                    { assembly_r: 5.0, layer_names: ['door material'] },
                    { assembly_r: 20.0, layer_names: ['door material'] }]

    hpxml = _create_hpxml('base.xml')
    doors_values.each do |door_values|
      hpxml.doors[0].r_value = door_values[:assembly_r]
      XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
      model, hpxml = _test_measure(args_hash)

      # Check properties
      os_surface = model.getSubSurfaces.select { |s| s.name.to_s == hpxml.doors[0].id }[0]
      _check_surface(hpxml.doors[0], os_surface, door_values[:layer_names])
    end
  end

  def _check_surface(hpxml_surface, os_surface, expected_layer_names)
    os_construction = os_surface.construction.get.to_LayeredConstruction.get

    # Check exterior solar absorptance and emittance
    exterior_layer = os_construction.getLayer(0).to_OpaqueMaterial.get
    if hpxml_surface.respond_to? :solar_absorptance
      assert_equal(hpxml_surface.solar_absorptance, exterior_layer.solarAbsorptance)
    end
    if hpxml_surface.respond_to? :emittance
      assert_equal(hpxml_surface.emittance, exterior_layer.thermalAbsorptance)
    end

    # Check interior finish solar absorptance and emittance
    if hpxml_surface.respond_to?(:interior_finish_type) && hpxml_surface.interior_finish_type != HPXML::InteriorFinishNone
      interior_layer = os_construction.getLayer(os_construction.numLayers - 1).to_OpaqueMaterial.get
      assert_equal(0.6, interior_layer.solarAbsorptance)
      assert_equal(0.9, interior_layer.thermalAbsorptance)
    end

    # Check for appropriate construction layers (including Kiva insulation/custom blocks)

    num_layers = os_construction.numLayers
    if os_surface.is_a?(OpenStudio::Model::Surface) && os_surface.adjacentFoundation.is_initialized
      adjacent_foundation = os_surface.adjacentFoundation.get
      if adjacent_foundation.interiorHorizontalInsulationMaterial.is_initialized
        num_layers += 1
      end
      if adjacent_foundation.exteriorHorizontalInsulationMaterial.is_initialized
        num_layers += 1
      end
      if adjacent_foundation.interiorVerticalInsulationMaterial.is_initialized
        num_layers += 1
      end
      if adjacent_foundation.exteriorVerticalInsulationMaterial.is_initialized
        num_layers += 1
      end
      num_layers += adjacent_foundation.numberofCustomBlocks
    end
    assert_equal(expected_layer_names.size, num_layers)

    # Construction layers
    for i in 0..os_construction.numLayers - 1
      layer_name = os_construction.getLayer(i).name.to_s
      expected_layer_name = expected_layer_names[i]
      if not layer_name.start_with? expected_layer_name
        puts "'#{layer_name}' does not start with '#{expected_layer_name}'"
      end
      assert(layer_name.start_with? expected_layer_name)
    end
    curr_layer_num = os_construction.numLayers

    if not adjacent_foundation.nil?
      # Kiva - Interior Horizontal Insulation
      if adjacent_foundation.interiorHorizontalInsulationMaterial.is_initialized
        layer_name = adjacent_foundation.interiorHorizontalInsulationMaterial.get.name.to_s
        expected_layer_name = expected_layer_names[curr_layer_num]
        curr_layer_num += 1
        if not layer_name.start_with? expected_layer_name
          puts "'#{layer_name}' does not start with '#{expected_layer_name}'"
        end
        assert(layer_name.start_with? expected_layer_name)
      end

      # Kiva - Exterior Horizontal Insulation
      if adjacent_foundation.exteriorHorizontalInsulationMaterial.is_initialized
        layer_name = adjacent_foundation.exteriorHorizontalInsulationMaterial.get.name.to_s
        expected_layer_name = expected_layer_names[curr_layer_num]
        curr_layer_num += 1
        if not layer_name.start_with? expected_layer_name
          puts "'#{layer_name}' does not start with '#{expected_layer_name}'"
        end
        assert(layer_name.start_with? expected_layer_name)
      end

      # Kiva - Interior Vertical Insulation
      if adjacent_foundation.interiorVerticalInsulationMaterial.is_initialized
        layer_name = adjacent_foundation.interiorVerticalInsulationMaterial.get.name.to_s
        expected_layer_name = expected_layer_names[curr_layer_num]
        curr_layer_num += 1
        if not layer_name.start_with? expected_layer_name
          puts "'#{layer_name}' does not start with '#{expected_layer_name}'"
        end
        assert(layer_name.start_with? expected_layer_name)
      end

      # Kiva - Exterior Vertical Insulation
      if adjacent_foundation.exteriorVerticalInsulationMaterial.is_initialized
        layer_name = adjacent_foundation.exteriorVerticalInsulationMaterial.get.name.to_s
        expected_layer_name = expected_layer_names[curr_layer_num]
        curr_layer_num += 1
        if not layer_name.start_with? expected_layer_name
          puts "'#{layer_name}' does not start with '#{expected_layer_name}'"
        end
        assert(layer_name.start_with? expected_layer_name)
      end

      # Kiva - Custom insulation blocks
      for i in 0..adjacent_foundation.numberofCustomBlocks - 1
        layer_name = adjacent_foundation.customBlocks[i].material.name.to_s
        expected_layer_name = expected_layer_names[curr_layer_num]
        curr_layer_num += 1
        if not layer_name.start_with? expected_layer_name
          puts "'#{layer_name}' does not start with '#{expected_layer_name}'"
        end
        assert(layer_name.start_with? expected_layer_name)
      end
    end
  end

  def _test_measure(args_hash)
    # create an instance of the measure
    measure = HPXMLtoOpenStudio.new

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    model = OpenStudio::Model::Model.new

    # get arguments
    args_hash['output_dir'] = 'tests'
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)

    hpxml = HPXML.new(hpxml_path: File.join(File.dirname(__FILE__), 'in.xml'))

    File.delete(File.join(File.dirname(__FILE__), 'in.xml'))

    return model, hpxml
  end

  def _create_hpxml(hpxml_name)
    return HPXML.new(hpxml_path: File.join(@sample_files_path, hpxml_name))
  end
end
