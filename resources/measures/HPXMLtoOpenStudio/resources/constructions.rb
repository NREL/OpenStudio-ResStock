# frozen_string_literal: true

require_relative 'constants'
require_relative 'unit_conversions'
require_relative 'materials'
require_relative 'geometry'

class WallConstructions
  # Container class for above-grade wall constructions

  def self.apply_wood_stud(runner, model, surfaces, constr_name,
                           cavity_r, install_grade, cavity_depth_in, cavity_filled,
                           framing_factor, drywall_thick_in, osb_thick_in,
                           rigid_r, mat_ext_finish)

    return true if surfaces.empty?

    # Validate inputs
    if cavity_r < 0.0
      runner.registerError('Cavity Insulation Installed R-value must be greater than or equal to 0.')
      return false
    end
    if cavity_depth_in <= 0.0
      runner.registerError('Cavity Depth must be greater than 0.')
      return false
    end
    if (framing_factor < 0.0) || (framing_factor >= 1.0)
      runner.registerError('Framing Factor must be greater than or equal to 0 and less than 1.')
      return false
    end

    # Define materials
    if cavity_r > 0
      if cavity_filled
        # Insulation
        mat_cavity = Material.new(name = nil, thick_in = cavity_depth_in, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = cavity_depth_in / cavity_r)
      else
        # Insulation plus air gap when insulation thickness < cavity depth
        mat_cavity = Material.new(name = nil, thick_in = cavity_depth_in, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = cavity_depth_in / (cavity_r + Gas.AirGapRvalue))
      end
    else
      # Empty cavity
      mat_cavity = Material.AirCavityClosed(cavity_depth_in)
    end
    mat_framing = Material.new(name = nil, thick_in = cavity_depth_in, mat_base = BaseMaterial.Wood)
    mat_gap = Material.AirCavityClosed(cavity_depth_in)
    mat_osb = nil
    if osb_thick_in > 0
      mat_osb = Material.new(name = 'WallSheathing', thick_in = osb_thick_in, mat_base = BaseMaterial.Wood)
    end
    mat_rigid = nil
    if rigid_r > 0
      rigid_thick_in = rigid_r * BaseMaterial.InsulationRigid.k_in
      mat_rigid = Material.new(name = 'WallRigidIns', thick_in = rigid_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = rigid_thick_in / rigid_r)
    end

    # Set paths
    gapFactor = get_gap_factor(install_grade, framing_factor, cavity_r)
    path_fracs = [framing_factor, 1 - framing_factor - gapFactor, gapFactor]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    if not mat_ext_finish.nil?
      constr.add_layer(Material.AirFilmOutside)
      constr.add_layer(mat_ext_finish)
    else # interior wall
      constr.add_layer(Material.AirFilmVertical)
    end
    if not mat_rigid.nil?
      constr.add_layer(mat_rigid)
    end
    if not mat_osb.nil?
      constr.add_layer(mat_osb)
    end
    constr.add_layer([mat_framing, mat_cavity, mat_gap], 'WallStudAndCavity')
    if drywall_thick_in > 0
      constr.add_layer(Material.GypsumWall(drywall_thick_in))
    end
    constr.add_layer(Material.AirFilmVertical)

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    # Store info for HVAC Sizing measure
    surfaces.each do |surface|
      surface.additionalProperties.setFeature(Constants.SizingInfoWallType, 'WoodStud')
      surface.additionalProperties.setFeature(Constants.SizingInfoStudWallCavityRvalue, cavity_r)
    end

    return true
  end

  def self.apply_double_stud(runner, model, surfaces, constr_name,
                             cavity_r, install_grade, stud_depth_in, gap_depth_in,
                             framing_factor, framing_spacing, is_staggered,
                             drywall_thick_in, osb_thick_in, rigid_r,
                             mat_ext_finish)

    return true if surfaces.empty?

    # Validate inputs
    if cavity_r <= 0.0
      runner.registerError('Cavity Insulation Nominal R-value must be greater than 0.')
      return false
    end
    if stud_depth_in <= 0.0
      runner.registerError('Stud Depth must be greater than 0.')
      return false
    end
    if gap_depth_in < 0.0
      runner.registerError('Gap Depth must be greater than or equal to 0.')
      return false
    end
    if (framing_factor < 0.0) || (framing_factor >= 1.0)
      runner.registerError('Framing Factor must be greater than or equal to 0 and less than 1.')
      return false
    end
    if framing_spacing <= 0.0
      runner.registerError('Framing Spacing must be greater than 0.')
      return false
    end

    # Define materials
    cavity_depth_in = 2.0 * stud_depth_in + gap_depth_in
    mat_ins_inner_outer = Material.new(name = nil, thick_in = stud_depth_in, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = cavity_depth_in / cavity_r)
    mat_ins_middle = Material.new(name = nil, thick_in = gap_depth_in, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = cavity_depth_in / cavity_r)
    mat_framing_inner_outer = Material.new(name = nil, thick_in = stud_depth_in, mat_base = BaseMaterial.Wood)
    mat_framing_middle = Material.new(name = nil, thick_in = gap_depth_in, mat_base = BaseMaterial.Wood)
    mat_stud = Material.new(name = nil, thick_in = stud_depth_in, mat_base = BaseMaterial.Wood)
    mat_gap_total = Material.AirCavityClosed(cavity_depth_in)
    mat_gap_inner_outer = Material.new(name = nil, thick_in = stud_depth_in, mat_base = nil, k_in = stud_depth_in / (mat_gap_total.rvalue * stud_depth_in / cavity_depth_in), rho = Gas.Air.rho, cp = Gas.Air.cp)
    mat_gap_middle = Material.new(name = nil, thick_in = gap_depth_in, mat_base = nil, k_in = gap_depth_in / (mat_gap_total.rvalue * gap_depth_in / cavity_depth_in), rho = Gas.Air.rho, cp = Gas.Air.cp)
    mat_osb = nil
    if osb_thick_in > 0
      mat_osb = Material.new(name = 'WallSheathing', thick_in = osb_thick_in, mat_base = BaseMaterial.Wood)
    end
    mat_rigid = nil
    if rigid_r > 0
      rigid_thick_in = rigid_r * BaseMaterial.InsulationRigid.k_in
      mat_rigid = Material.new(name = 'WallRigidIns', thick_in = rigid_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = rigid_thick_in / rigid_r)
    end

    # Set paths
    stud_frac = 1.5 / framing_spacing
    misc_framing_factor = framing_factor - stud_frac
    if misc_framing_factor < 0
      runner.registerError("Framing Factor (#{framing_factor}) is less than the framing solely provided by the studs (#{stud_frac}).")
      return false
    end
    dsGapFactor = get_gap_factor(install_grade, framing_factor, cavity_r)
    path_fracs = [misc_framing_factor, stud_frac, stud_frac, dsGapFactor, (1.0 - (2 * stud_frac + misc_framing_factor + dsGapFactor))]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    if not mat_ext_finish.nil?
      constr.add_layer(Material.AirFilmOutside)
      constr.add_layer(mat_ext_finish)
    else # interior wall
      constr.add_layer(Material.AirFilmVertical)
    end
    if not mat_rigid.nil?
      constr.add_layer(mat_rigid)
    end
    if not mat_osb.nil?
      constr.add_layer(mat_osb)
    end
    if is_staggered
      constr.add_layer([mat_framing_inner_outer, mat_ins_inner_outer, mat_stud, mat_gap_inner_outer, mat_ins_inner_outer], 'WallStudandCavityOuter')
    else
      constr.add_layer([mat_framing_inner_outer, mat_stud, mat_ins_inner_outer, mat_gap_inner_outer, mat_ins_inner_outer], 'WallStudandCavityOuter')
    end
    if gap_depth_in > 0
      constr.add_layer([mat_framing_middle, mat_ins_middle, mat_ins_middle, mat_gap_middle, mat_ins_middle], 'WallCavity')
    end
    constr.add_layer([mat_framing_inner_outer, mat_stud, mat_ins_inner_outer, mat_gap_inner_outer, mat_ins_inner_outer], 'WallStudandCavityInner')
    if drywall_thick_in > 0
      constr.add_layer(Material.GypsumWall(drywall_thick_in))
    end
    constr.add_layer(Material.AirFilmVertical)

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    # Store info for HVAC Sizing measure
    surfaces.each do |surface|
      surface.additionalProperties.setFeature(Constants.SizingInfoWallType, 'DoubleWoodStud')
    end

    return true
  end

  def self.apply_cmu(runner, model, surfaces, constr_name,
                     thick_in, conductivity, density, framing_factor,
                     furring_r, furring_cavity_depth, furring_spacing,
                     drywall_thick_in, osb_thick_in, rigid_r,
                     mat_ext_finish)

    return true if surfaces.empty?

    # Validate inputs
    if thick_in <= 0.0
      runner.registerError('CMU Block Thickness must be greater than 0.')
      return false
    end
    if conductivity <= 0.0
      runner.registerError('CMU Conductivity must be greater than 0.')
      return false
    end
    if density <= 0.0
      runner.registerError('CMU Density must be greater than 0.')
      return false
    end
    if (framing_factor < 0.0) || (framing_factor >= 1.0)
      runner.registerError('Framing Factor must be greater than or equal to 0 and less than 1.')
      return false
    end
    if furring_r < 0.0
      runner.registerError('Furring Insulation R-value must be greater than or equal to 0.')
      return false
    end
    if furring_cavity_depth < 0.0
      runner.registerError('Furring Cavity Depth must be greater than or equal to 0.')
      return false
    end
    if furring_spacing < 0.0
      runner.registerError('Furring Stud Spacing must be greater than or equal to 0.')
      return false
    end

    # Define materials
    mat_cmu = Material.new(name = 'WallCMU', thick_in = thick_in, mat_base = BaseMaterial.Concrete, k_in = conductivity, rho = density)

    # If no exterior finish, use exterior finish absorptance values for CMU/Brick
    if (not mat_ext_finish.nil?) && mat_ext_finish.name.include?('None')
      mat_cmu.tAbs, mat_cmu.sAbs, mat_cmu.vAbs = mat_ext_finish.tAbs, mat_ext_finish.sAbs, mat_ext_finish.vAbs
    end

    mat_framing = Material.new(name = nil, thick_in = thick_in, mat_base = BaseMaterial.Wood, k_in = nil, rho = nil, cp = nil, tAbs = nil, sAbs = nil, vAbs = nil)

    mat_furring = nil
    mat_furring_cavity = nil
    if furring_cavity_depth != 0
      mat_furring = Material.new(name = nil, thick_in = furring_cavity_depth, mat_base = BaseMaterial.Wood)
      if furring_r == 0
        mat_furring_cavity = Material.AirCavityClosed(furring_cavity_depth)
      else
        mat_furring_cavity = Material.new(name = nil, thick_in = furring_cavity_depth, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = furring_cavity_depth / furring_r)
      end
    end
    mat_osb = nil
    if osb_thick_in > 0
      mat_osb = Material.new(name = 'WallSheathing', thick_in = osb_thick_in, mat_base = BaseMaterial.Wood)
    end
    mat_rigid = nil
    if rigid_r > 0
      rigid_thick_in = rigid_r * BaseMaterial.InsulationRigid.k_in
      mat_rigid = Material.new(name = 'WallRigidIns', thick_in = rigid_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = rigid_thick_in / rigid_r)
    end

    # Set paths
    if not mat_furring.nil?
      stud_frac = 1.5 / furring_spacing
      cavity_frac = 1.0 - (stud_frac + framing_factor)
      path_fracs = [framing_factor, stud_frac, cavity_frac]
    else # No furring:
      path_fracs = [framing_factor, 1.0 - framing_factor]
    end

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    if not mat_ext_finish.nil?
      constr.add_layer(Material.AirFilmOutside)
      if not mat_ext_finish.name.include? 'None'
        constr.add_layer(mat_ext_finish)
      end
    else # interior wall
      constr.add_layer(Material.AirFilmVertical)
    end
    if not mat_rigid.nil?
      constr.add_layer(mat_rigid)
    end
    if not mat_osb.nil?
      constr.add_layer(mat_osb)
    end
    if not mat_furring.nil?
      constr.add_layer([mat_framing, mat_cmu, mat_cmu], 'WallCMU')
      constr.add_layer([mat_furring, mat_furring, mat_furring_cavity], 'WallFurring')
    else
      constr.add_layer([mat_framing, mat_cmu], 'WallCMU')
    end
    if drywall_thick_in > 0
      constr.add_layer(Material.GypsumWall(drywall_thick_in))
    end
    constr.add_layer(Material.AirFilmVertical)

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    # Store info for HVAC Sizing measure
    surfaces.each do |surface|
      surface.additionalProperties.setFeature(Constants.SizingInfoWallType, 'CMU')
      surface.additionalProperties.setFeature(Constants.SizingInfoCMUWallFurringInsRvalue, furring_r)
    end

    return true
  end

  def self.apply_icf(runner, model, surfaces, constr_name,
                     icf_r, ins_thick_in, concrete_thick_in, framing_factor,
                     drywall_thick_in, osb_thick_in, rigid_r,
                     mat_ext_finish)

    return true if surfaces.empty?

    # Validate inputs
    if icf_r <= 0.0
      runner.registerError('Nominal Insulation R-value must be greater than 0.')
      return false
    end
    if ins_thick_in <= 0.0
      runner.registerError('Insulation Thickness must be greater than 0.')
      return false
    end
    if concrete_thick_in <= 0.0
      runner.registerError('Concrete Thickness must be greater than 0.')
      return false
    end
    if (framing_factor < 0.0) || (framing_factor >= 1.0)
      runner.registerError('Framing Factor must be greater than or equal to 0 and less than 1.')
      return false
    end

    # Define materials
    mat_ins = Material.new(name = nil, thick_in = ins_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = ins_thick_in / icf_r)
    mat_conc = Material.new(name = nil, thick_in = concrete_thick_in, mat_base = BaseMaterial.Concrete)
    mat_framing_inner_outer = Material.new(name = nil, thick_in = ins_thick_in, mat_base = BaseMaterial.Wood)
    mat_framing_middle = Material.new(name = nil, thick_in = concrete_thick_in, mat_base = BaseMaterial.Wood)
    mat_osb = nil
    if osb_thick_in > 0
      mat_osb = Material.new(name = 'WallSheathing', thick_in = osb_thick_in, mat_base = BaseMaterial.Wood)
    end
    mat_rigid = nil
    if rigid_r > 0
      rigid_thick_in = rigid_r * BaseMaterial.InsulationRigid.k_in
      mat_rigid = Material.new(name = 'WallRigidIns', thick_in = rigid_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = rigid_thick_in / rigid_r)
    end

    # Set paths
    path_fracs = [framing_factor, 1.0 - framing_factor]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    if not mat_ext_finish.nil?
      constr.add_layer(Material.AirFilmOutside)
      constr.add_layer(mat_ext_finish)
    else # interior wall
      constr.add_layer(Material.AirFilmVertical)
    end
    if not mat_rigid.nil?
      constr.add_layer(mat_rigid)
    end
    if not mat_osb.nil?
      constr.add_layer(mat_osb)
    end
    constr.add_layer([mat_framing_inner_outer, mat_ins], 'WallICFInsFormOuter')
    constr.add_layer([mat_framing_middle, mat_conc], 'WallICFConcrete')
    constr.add_layer([mat_framing_inner_outer, mat_ins], 'WallICFInsFormInner')
    if drywall_thick_in > 0
      constr.add_layer(Material.GypsumWall(drywall_thick_in))
    end
    constr.add_layer(Material.AirFilmVertical)

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    # Store info for HVAC Sizing measure
    surfaces.each do |surface|
      surface.additionalProperties.setFeature(Constants.SizingInfoWallType, 'ICF')
    end

    return true
  end

  def self.apply_sip(runner, model, surfaces, constr_name,
                     sip_r, sip_thick_in, framing_factor,
                     sheathing_type, sheathing_thick_in,
                     drywall_thick_in, osb_thick_in, rigid_r,
                     mat_ext_finish)

    return true if surfaces.empty?

    # Validate inputs
    if sip_r <= 0.0
      runner.registerError('Nominal Insulation R-value must be greater than 0.')
      return false
    end
    if sip_thick_in <= 0.0
      runner.registerError('Insulation Thickness must be greater than 0.')
      return false
    end
    if (framing_factor < 0.0) || (framing_factor >= 1.0)
      runner.registerError('Framing Factor must be greater than or equal to 0 and less than 1.')
      return false
    end
    if sheathing_thick_in <= 0.0
      runner.registerError('Interior Sheathing Thickness must be greater than 0.')
      return false
    end

    # Define materials
    spline_thick_in = 0.5
    ins_thick_in = sip_thick_in - (2.0 * spline_thick_in) # in
    if sheathing_type == Constants.MaterialOSB
      mat_int_sheath = Material.new(name = 'WallIntSheathing', thick_in = sheathing_thick_in, mat_base = BaseMaterial.Wood)
    elsif sheathing_type == Constants.MaterialGypsum
      mat_int_sheath = Material.new(name = 'WallIntSheathing', thick_in = sheathing_thick_in, mat_base = BaseMaterial.Gypsum)
    elsif sheathing_type == Constants.MaterialGypcrete
      mat_int_sheath = Material.new(name = 'WallIntSheathing', thick_in = sheathing_thick_in, mat_base = BaseMaterial.Gypcrete)
    end
    mat_framing_inner_outer = Material.new(name = nil, thick_in = spline_thick_in, mat_base = BaseMaterial.Wood)
    mat_framing_middle = Material.new(name = nil, thick_in = ins_thick_in, mat_base = BaseMaterial.Wood)
    mat_spline = Material.new(name = nil, thick_in = spline_thick_in, mat_base = BaseMaterial.Wood)
    mat_ins_inner_outer = Material.new(name = nil, thick_in = spline_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = sip_thick_in / sip_r)
    mat_ins_middle = Material.new(name = nil, thick_in = ins_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = sip_thick_in / sip_r)
    mat_osb = nil
    if osb_thick_in > 0
      mat_osb = Material.new(name = 'WallSheathing', thick_in = osb_thick_in, mat_base = BaseMaterial.Wood)
    end
    mat_rigid = nil
    if rigid_r > 0
      rigid_thick_in = rigid_r * BaseMaterial.InsulationRigid.k_in
      mat_rigid = Material.new(name = 'WallRigidIns', thick_in = rigid_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = rigid_thick_in / rigid_r)
    end

    # Set paths
    spline_frac = 4.0 / 48.0 # One 4" spline for every 48" wide panel
    cavity_frac = 1.0 - (spline_frac + framing_factor)
    path_fracs = [framing_factor, spline_frac, cavity_frac]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    if not mat_ext_finish.nil?
      constr.add_layer(Material.AirFilmOutside)
      constr.add_layer(mat_ext_finish)
    else # interior wall
      constr.add_layer(Material.AirFilmVertical)
    end
    if not mat_rigid.nil?
      constr.add_layer(mat_rigid)
    end
    if not mat_osb.nil?
      constr.add_layer(mat_osb)
    end
    constr.add_layer([mat_framing_inner_outer, mat_spline, mat_ins_inner_outer], 'WallSplineLayerOuter')
    constr.add_layer([mat_framing_middle, mat_ins_middle, mat_ins_middle], 'WallIns')
    constr.add_layer([mat_framing_inner_outer, mat_spline, mat_ins_inner_outer], 'WallSplineLayerInner')
    constr.add_layer(mat_int_sheath)
    if drywall_thick_in > 0
      constr.add_layer(Material.GypsumWall(drywall_thick_in))
    end
    constr.add_layer(Material.AirFilmVertical)

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    # Store info for HVAC Sizing measure
    surfaces.each do |surface|
      surface.additionalProperties.setFeature(Constants.SizingInfoWallType, 'SIP')
      surface.additionalProperties.setFeature(Constants.SizingInfoSIPWallInsThickness, sip_thick_in)
    end

    return true
  end

  def self.apply_steel_stud(runner, model, surfaces, constr_name,
                            cavity_r, install_grade, cavity_depth,
                            cavity_filled, framing_factor, correction_factor,
                            drywall_thick_in, osb_thick_in, rigid_r,
                            mat_ext_finish)

    return true if surfaces.empty?

    # Validate inputs
    if cavity_r < 0.0
      runner.registerError('Cavity Insulation Nominal R-value must be greater than or equal to 0.')
      return false
    end
    if cavity_depth <= 0.0
      runner.registerError('Cavity Depth must be greater than 0.')
      return false
    end
    if (framing_factor < 0.0) || (framing_factor >= 1.0)
      runner.registerError('Framing Factor must be greater than or equal to 0 and less than 1.')
      return false
    end
    if (correction_factor < 0.0) || (correction_factor > 1.0)
      runner.registerError('Correction Factor must be greater than or equal to 0 and less than or equal to 1.')
      return false
    end

    # Define materials
    eR = cavity_r * correction_factor # The effective R-value of the cavity insulation with steel stud framing
    if eR > 0
      if cavity_filled
        # Insulation
        mat_cavity = Material.new(name = nil, thick_in = cavity_depth, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = cavity_depth / eR)
      else
        # Insulation plus air gap when insulation thickness < cavity depth
        mat_cavity = Material.new(name = nil, thick_in = cavity_depth, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = cavity_depth / (eR + Gas.AirGapRvalue))
      end
    else
      # Empty cavity
      mat_cavity = Material.AirCavityClosed(cavity_depth)
    end
    mat_gap = Material.AirCavityClosed(cavity_depth)
    mat_osb = nil
    if osb_thick_in > 0
      mat_osb = Material.new(name = 'WallSheathing', thick_in = osb_thick_in, mat_base = BaseMaterial.Wood)
    end
    mat_rigid = nil
    if rigid_r > 0
      rigid_thick_in = rigid_r * BaseMaterial.InsulationRigid.k_in
      mat_rigid = Material.new(name = 'WallRigidIns', thick_in = rigid_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = rigid_thick_in / rigid_r)
    end

    # Set paths
    gapFactor = get_gap_factor(install_grade, framing_factor, cavity_r)
    path_fracs = [1 - gapFactor, gapFactor]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    if not mat_ext_finish.nil?
      constr.add_layer(Material.AirFilmOutside)
      constr.add_layer(mat_ext_finish)
    else # interior wall
      constr.add_layer(Material.AirFilmVertical)
    end
    if not mat_rigid.nil?
      constr.add_layer(mat_rigid)
    end
    if not mat_osb.nil?
      constr.add_layer(mat_osb)
    end
    constr.add_layer([mat_cavity, mat_gap], 'WallStudAndCavity')
    if drywall_thick_in > 0
      constr.add_layer(Material.GypsumWall(drywall_thick_in))
    end
    constr.add_layer(Material.AirFilmVertical)

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    # Store info for HVAC Sizing measure
    surfaces.each do |surface|
      surface.additionalProperties.setFeature(Constants.SizingInfoWallType, 'SteelStud')
      surface.additionalProperties.setFeature(Constants.SizingInfoStudWallCavityRvalue, cavity_r)
    end

    return true
  end

  def self.apply_generic(runner, model, surfaces, constr_name,
                         thick_ins, conds, denss, specheats,
                         drywall_thick_in, osb_thick_in, rigid_r,
                         mat_ext_finish)

    return true if surfaces.empty?

    # Validate inputs
    for idx in 0..4
      if (thick_ins[idx].nil? != conds[idx].nil?) || (thick_ins[idx].nil? != denss[idx].nil?) || (thick_ins[idx].nil? != specheats[idx].nil?)
        runner.registerError("Layer #{idx + 1} does not have all four properties (thickness, conductivity, density, specific heat) entered.")
        return false
      end
    end
    thick_ins.each_with_index do |thick_in, idx|
      if (not thick_in.nil?) && (thick_in <= 0.0)
        runner.registerError("Thickness #{idx + 1} must be greater than 0.")
        return false
      end
    end
    conds.each_with_index do |cond, idx|
      if (not cond.nil?) && (cond <= 0.0)
        runner.registerError("Conductivity #{idx + 1} must be greater than 0.")
        return false
      end
    end
    denss.each_with_index do |dens, idx|
      if (not dens.nil?) && (dens <= 0.0)
        runner.registerError("Density #{idx + 1} must be greater than 0.")
        return false
      end
    end
    specheats.each_with_index do |specheat, idx|
      if (not specheat.nil?) && (specheat <= 0.0)
        runner.registerError("Specific Heat #{idx + 1} must be greater than 0.")
        return false
      end
    end

    # Define materials
    mats = []
    mats << Material.new(name = 'WallLayer1', thick_in = thick_ins[0], mat_base = nil, k_in = conds[0], rho = denss[0], cp = specheats[0])
    if not thick_ins[1].nil?
      mats << Material.new(name = 'WallLayer2', thick_in = thick_ins[1], mat_base = nil, k_in = conds[1], rho = denss[1], cp = specheats[1])
    end
    if not thick_ins[2].nil?
      mats << Material.new(name = 'WallLayer3', thick_in = thick_ins[2], mat_base = nil, k_in = conds[2], rho = denss[2], cp = specheats[2])
    end
    if not thick_ins[3].nil?
      mats << Material.new(name = 'WallLayer4', thick_in = thick_ins[3], mat_base = nil, k_in = conds[3], rho = denss[3], cp = specheats[3])
    end
    if not thick_ins[4].nil?
      mats << Material.new(name = 'WallLayer5', thick_in = thick_ins[4], mat_base = nil, k_in = conds[4], rho = denss[4], cp = specheats[4])
    end
    mat_osb = nil
    if osb_thick_in > 0
      mat_osb = Material.new(name = 'WallSheathing', thick_in = osb_thick_in, mat_base = BaseMaterial.Wood)
    end
    mat_rigid = nil
    if rigid_r > 0
      rigid_thick_in = rigid_r * BaseMaterial.InsulationRigid.k_in
      mat_rigid = Material.new(name = 'WallRigidIns', thick_in = rigid_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = rigid_thick_in / rigid_r)
    end

    # Set paths
    path_fracs = [1]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    if not mat_ext_finish.nil?
      constr.add_layer(Material.AirFilmOutside)
      constr.add_layer(mat_ext_finish)
    else # interior wall
      constr.add_layer(Material.AirFilmVertical)
    end
    if not mat_rigid.nil?
      constr.add_layer(mat_rigid)
    end
    if not mat_osb.nil?
      constr.add_layer(mat_osb)
    end
    mats.each do |mat|
      constr.add_layer(mat)
    end
    if drywall_thick_in > 0
      constr.add_layer(Material.GypsumWall(drywall_thick_in))
    end
    constr.add_layer(Material.AirFilmVertical)

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    # Store info for HVAC Sizing measure
    surfaces.each do |surface|
      surface.additionalProperties.setFeature(Constants.SizingInfoWallType, 'Generic')
    end

    return true
  end

  def self.apply_uninsulated(runner, model, walls_by_type,
                             osb_thick_in, drywall_thick_in, mat_ext_finish)

    framing_factor = Constants.DefaultFramingFactorInterior
    cavity_r = 0
    install_grade = 1
    cavity_depth_in = 3.5
    cavity_filled = false
    rigid_r = 0

    if not apply_wood_stud(runner, model,
                           walls_by_type[Constants.SurfaceTypeWallExtUninsUnfin],
                           Constants.SurfaceTypeWallExtUninsUnfin,
                           cavity_r, install_grade, cavity_depth_in,
                           cavity_filled, framing_factor,
                           0, osb_thick_in, rigid_r, mat_ext_finish)
      return false
    end

    if not apply_wood_stud(runner, model,
                           walls_by_type[Constants.SurfaceTypeWallIntFinUninsFin],
                           Constants.SurfaceTypeWallIntFinUninsFin,
                           cavity_r, install_grade, cavity_depth_in,
                           cavity_filled, framing_factor,
                           drywall_thick_in, 0, rigid_r, mat_ext_finish)
      return false
    end

    if not apply_wood_stud(runner, model,
                           walls_by_type[Constants.SurfaceTypeWallIntUnfinUninsUnfin],
                           Constants.SurfaceTypeWallIntUnfinUninsUnfin,
                           cavity_r, install_grade, cavity_depth_in,
                           cavity_filled, framing_factor,
                           0, 0, rigid_r, mat_ext_finish)
      return false
    end

    return true
  end

  def self.apply_adiabatic(runner, model, shared_building_facades)
    mat = OpenStudio::Model::MasslessOpaqueMaterial.new(model)
    mat.setName(Constants.SurfaceTypeAdiabatic)
    mat.setRoughness('Rough')
    mat.setThermalResistance(UnitConversions.convert(1000.0, 'hr*ft^2*F/Btu', 'm^2*K/W'))
    constr = OpenStudio::Model::Construction.new(model)
    constr.setName(Constants.SurfaceTypeAdiabatic)
    constr.setLayers([mat])
    shared_building_facades = shared_building_facades.split(', ')
    shared_building_facades.each do |shared_building_facade|
      model.getSurfaces.each do |surface|
        next unless surface.surfaceType.downcase == 'wall'
        next unless ['outdoors', 'foundation'].include? surface.outsideBoundaryCondition.downcase
        next if surface.adjacentSurface.is_initialized
        next unless Geometry.get_facade_for_surface(surface) == shared_building_facade

        surface.setConstruction(constr)
        surface.setOutsideBoundaryCondition('Adiabatic')
        runner.registerInfo("Surface '#{surface.name}' on #{shared_building_facade} facade is now a shared wall.")
      end
    end
  end

  def self.apply_rim_joist(runner, model, surfaces, constr_name,
                           cavity_r, install_grade, framing_factor,
                           drywall_thick_in, osb_thick_in,
                           rigid_r, mat_ext_finish)

    return true if surfaces.empty?

    # Validate inputs
    if cavity_r < 0.0
      runner.registerError('Cavity Insulation Installed R-value must be greater than or equal to 0.')
      return false
    end
    if (framing_factor < 0.0) || (framing_factor >= 1.0)
      runner.registerError('Framing Factor must be greater than or equal to 0 and less than 1.')
      return false
    end

    # Define materials
    rim_joist_thick_in = 1.5
    sill_plate_thick_in = 3.5
    framing_thick_in = sill_plate_thick_in - rim_joist_thick_in # Extra non-continuous wood beyond rim joist thickness
    if cavity_r > 0
      # Insulation
      mat_cavity = Material.new(name = nil, thick_in = framing_thick_in, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = framing_thick_in / cavity_r)
    else
      # Empty cavity
      mat_cavity = Material.AirCavityOpen(framing_thick_in)
    end
    mat_framing = Material.new(name = nil, thick_in = framing_thick_in, mat_base = BaseMaterial.Wood)
    mat_gap = Material.AirCavityClosed(framing_thick_in)
    mat_osb = nil
    if osb_thick_in > 0
      mat_osb = Material.new(name = 'RimJoistSheathing', thick_in = osb_thick_in, mat_base = BaseMaterial.Wood)
    end
    mat_rigid = nil
    if rigid_r > 0
      rigid_thick_in = rigid_r * BaseMaterial.InsulationRigid.k_in
      mat_rigid = Material.new(name = 'RimJoistRigidIns', thick_in = rigid_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = rigid_thick_in / rigid_r)
    end

    # Set paths
    gapFactor = get_gap_factor(install_grade, framing_factor, cavity_r)
    path_fracs = [framing_factor, 1 - framing_factor - gapFactor, gapFactor]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    if not mat_ext_finish.nil?
      constr.add_layer(Material.AirFilmOutside)
      constr.add_layer(mat_ext_finish)
    else # interior wall
      constr.add_layer(Material.AirFilmVertical)
    end
    if not mat_rigid.nil?
      constr.add_layer(mat_rigid)
    end
    if not mat_osb.nil?
      constr.add_layer(mat_osb)
    end
    constr.add_layer([mat_framing, mat_cavity, mat_gap], 'RimJoistStudAndCavity')
    if drywall_thick_in > 0
      constr.add_layer(Material.GypsumWall(drywall_thick_in))
    end
    constr.add_layer(Material.AirFilmVertical)

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    # Store info for HVAC Sizing measure
    surfaces.each do |surface|
      surface.additionalProperties.setFeature(Constants.SizingInfoWallType, 'WoodStud')
      surface.additionalProperties.setFeature(Constants.SizingInfoStudWallCavityRvalue, cavity_r)
    end

    return true
  end

  def self.get_exterior_finish_materials
    mats = []
    mats << Material.ExtFinishStuccoMedDark
    mats << Material.ExtFinishStuccoMedLight
    mats << Material.ExtFinishBrickLight
    mats << Material.ExtFinishBrickMedDark
    mats << Material.ExtFinishWoodLight
    mats << Material.ExtFinishWoodMedDark
    mats << Material.ExtFinishAluminumLight
    mats << Material.ExtFinishAluminumMedDark
    mats << Material.ExtFinishVinylLight
    mats << Material.ExtFinishVinylMedDark
    mats << Material.ExtFinishFiberCementLight
    mats << Material.ExtFinishFiberCementMedDark
    mats << Material.ExtFinishShingleAsbestos
    mats << Material.ExtFinishShingleComposition
    mats << Material.ExtFinishConcrete
    mats << Material.ExtFinishNoneCMU
    mats << Material.ExtFinishNoneBrick
    return mats
  end

  def self.get_exterior_finish_material(name)
    get_exterior_finish_materials.each do |mat|
      next if mat.name != name

      return mat
    end
    return
  end

  def self.get_default_frame_wall_ufactor(iecc_zone_2006)
    # Table 4.2.2(2) - Component Heat Transfer Characteristics for Reference Home
    # Frame Wall U-Factor
    if ['1A', '1B', '1C', '2A', '2B', '2C', '3A', '3B', '3C', '4A', '4B'].include? iecc_zone_2006
      return 0.082
    elsif ['4C', '5A', '5B', '5C', '6A', '6B', '6C'].include? iecc_zone_2006
      return 0.060
    elsif ['7', '8'].include? iecc_zone_2006
      return 0.057
    else
      return
    end
  end
end

class RoofConstructions
  # Container class for roof constructions

  def self.apply_unfinished_attic(runner, model, surfaces, constr_name,
                                  cavity_r, install_grade, cavity_ins_thick_in,
                                  framing_factor, framing_thick_in,
                                  osb_thick_in, rigid_r,
                                  mat_roofing, has_radiant_barrier)

    return true if surfaces.empty?

    # Validate Inputs
    if cavity_r < 0.0
      runner.registerError('Roof Cavity Insulation Nominal R-value must be greater than or equal to 0.')
      return false
    end
    if cavity_ins_thick_in < 0.0
      runner.registerError('Roof Cavity Insulation Thickness must be greater than or equal to 0.')
      return false
    end
    if (framing_factor < 0.0) || (framing_factor >= 1.0)
      runner.registerError('Roof Framing Factor must be greater than or equal to 0 and less than 1.')
      return false
    end
    if framing_thick_in < 0.0
      runner.registerError('Roof Framing Thickness must be greater than 0.')
      return false
    end

    # Define materials
    roof_ins_thickness_in = [cavity_ins_thick_in, framing_thick_in].max
    if cavity_r == 0
      mat_cavity = Material.AirCavityOpen(roof_ins_thickness_in)
    else
      cavity_k = cavity_ins_thick_in / cavity_r
      if cavity_ins_thick_in < framing_thick_in
        cavity_k = cavity_k * framing_thick_in / cavity_ins_thick_in
      end
      mat_cavity = Material.new(name = nil, thick_in = roof_ins_thickness_in, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = cavity_k)
    end
    if (cavity_ins_thick_in > framing_thick_in) && (framing_thick_in > 0)
      wood_k = BaseMaterial.Wood.k_in * cavity_ins_thick_in / framing_thick_in
    else
      wood_k = BaseMaterial.Wood.k_in
    end
    mat_framing = Material.new(name = nil, thick_in = roof_ins_thickness_in, mat_base = BaseMaterial.Wood, k_in = wood_k)
    mat_gap = Material.AirCavityOpen(roof_ins_thickness_in)
    mat_osb = nil
    if osb_thick_in > 0
      mat_osb = Material.new(name = 'RoofSheathing', thick_in = osb_thick_in, mat_base = BaseMaterial.Wood)
    end
    mat_rigid = nil
    if rigid_r > 0
      rigid_thick_in = rigid_r * BaseMaterial.InsulationRigid.k_in
      mat_rigid = Material.new(name = 'RoofRigidIns', thick_in = rigid_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = rigid_thick_in / rigid_r)
    end
    mat_rb = nil
    if has_radiant_barrier
      mat_rb = Material.RadiantBarrier
    end

    # Set paths
    gapFactor = get_gap_factor(install_grade, framing_factor, cavity_r)
    path_fracs = [framing_factor, 1 - framing_factor - gapFactor, gapFactor]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    constr.add_layer(Material.AirFilmOutside)
    if not mat_roofing.nil?
      constr.add_layer(mat_roofing)
    end
    if not mat_rigid.nil?
      constr.add_layer(mat_rigid)
    end
    if not mat_osb.nil?
      constr.add_layer(mat_osb)
    end
    if framing_thick_in > 0
      constr.add_layer([mat_framing, mat_cavity, mat_gap], 'RoofUARoofIns')
    end
    if not mat_rb.nil?
      constr.add_layer(mat_rb)
    end
    constr.add_layer(Material.AirFilmRoof(Geometry.get_roof_pitch(surfaces)))

    # Create and assign construction to roof surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    # Store info for HVAC Sizing measure
    surfaces.each do |surface|
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofColor, get_roofing_material_manual_j_color(mat_roofing.name))
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofMaterial, get_roofing_material_manual_j_material(mat_roofing.name))
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofRigidInsRvalue, rigid_r)
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofHasRadiantBarrier, !mat_rb.nil?)
    end

    return true
  end

  def self.apply_finished_roof(runner, model, surfaces, constr_name,
                               cavity_r, install_grade, cavity_depth,
                               filled_cavity, framing_factor, drywall_thick_in,
                               osb_thick_in, rigid_r, mat_roofing)

    return true if surfaces.empty?

    # Validate Inputs
    if cavity_r < 0.0
      runner.registerError('Cavity Insulation Installed R-value must be greater than or equal to 0.')
      return false
    end
    if cavity_depth <= 0.0
      runner.registerError('Cavity Depth must be greater than 0.')
      return false
    end
    if (framing_factor < 0.0) || (framing_factor >= 1.0)
      runner.registerError('Framing Factor must be greater than or equal to 0 and less than 1.')
      return false
    end

    # Define materials
    if cavity_r > 0
      if filled_cavity
        # Insulation
        mat_cavity = Material.new(name = nil, thick_in = cavity_depth, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = cavity_depth / cavity_r)
      else
        # Insulation plus air gap when insulation thickness < cavity depth
        mat_cavity = Material.new(name = nil, thick_in = cavity_depth, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = cavity_depth / (cavity_r + Gas.AirGapRvalue))
      end
    else
      # Empty cavity
      mat_cavity = Material.AirCavityClosed(cavity_depth)
    end
    mat_framing = Material.new(name = nil, thick_in = cavity_depth, mat_base = BaseMaterial.Wood)
    mat_gap = Material.AirCavityClosed(cavity_depth)
    mat_osb = nil
    if osb_thick_in > 0
      mat_osb = Material.new(name = 'RoofSheathing', thick_in = osb_thick_in, mat_base = BaseMaterial.Wood)
    end
    mat_rigid = nil
    if rigid_r > 0
      rigid_thick_in = rigid_r * BaseMaterial.InsulationRigid.k_in
      mat_rigid = Material.new(name = 'RoofRigidIns', thick_in = rigid_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = rigid_thick_in / rigid_r)
    end

    # Set paths
    gapFactor = get_gap_factor(install_grade, framing_factor, cavity_r)
    path_fracs = [framing_factor, 1 - framing_factor - gapFactor, gapFactor]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    constr.add_layer(Material.AirFilmOutside)
    if not mat_roofing.nil?
      constr.add_layer(mat_roofing)
    end
    if not mat_rigid.nil?
      constr.add_layer(mat_rigid)
    end
    if not mat_osb.nil?
      constr.add_layer(mat_osb)
    end
    constr.add_layer([mat_framing, mat_cavity, mat_gap], 'RoofIns')
    if drywall_thick_in > 0
      constr.add_layer(Material.GypsumWall(drywall_thick_in))
    end
    constr.add_layer(Material.AirFilmRoof(Geometry.get_roof_pitch(surfaces)))

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    # Store info for HVAC Sizing measure
    surfaces.each do |surface|
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofColor, get_roofing_material_manual_j_color(mat_roofing.name))
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofMaterial, get_roofing_material_manual_j_material(mat_roofing.name))
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofRigidInsRvalue, rigid_r)
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofHasRadiantBarrier, false)
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofCavityRvalue, cavity_r)
    end

    return true
  end

  def self.apply_uninsulated_roofs(runner, model, surfaces, constr_name,
                                   framing_thick_in, framing_factor,
                                   osb_thick_in, mat_roofing)

    return true if surfaces.empty?

    # Define materials
    mat_cavity = Material.AirCavityOpen(framing_thick_in)
    mat_framing = Material.new(name = nil, thick_in = framing_thick_in, mat_base = BaseMaterial.Wood)
    mat_osb = nil
    if osb_thick_in > 0
      mat_osb = Material.new(name = 'RoofSheathing', thick_in = osb_thick_in, mat_base = BaseMaterial.Wood)
    end

    # Set paths
    path_fracs = [framing_factor, 1 - framing_factor]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    constr.add_layer(Material.AirFilmOutside)
    if not mat_roofing.nil?
      constr.add_layer(mat_roofing)
    end
    constr.add_layer(mat_osb)
    constr.add_layer([mat_framing, mat_cavity], 'RoofStudAndAirRoof')
    constr.add_layer(Material.AirFilmRoof(Geometry.get_roof_pitch(surfaces)))

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    # Store info for HVAC Sizing measure
    surfaces.each do |surface|
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofColor, get_roofing_material_manual_j_color(mat_roofing.name))
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofMaterial, get_roofing_material_manual_j_material(mat_roofing.name))
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofRigidInsRvalue, 0.0)
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofHasRadiantBarrier, false)
      surface.additionalProperties.setFeature(Constants.SizingInfoRoofCavityRvalue, 0.0)
    end

    return true
  end

  def self.get_roofing_materials
    mats = []
    mats << Material.RoofingAsphaltShinglesDark
    mats << Material.RoofingAsphaltShinglesMed
    mats << Material.RoofingAsphaltShinglesLight
    mats << Material.RoofingAsphaltShinglesWhiteCool
    mats << Material.RoofingTileDark
    mats << Material.RoofingTileMed
    mats << Material.RoofingTileLight
    mats << Material.RoofingTileWhite
    mats << Material.RoofingMetalDark
    mats << Material.RoofingMetalCool
    mats << Material.RoofingMetalMed
    mats << Material.RoofingMetalLight
    mats << Material.RoofingMetalWhite
    mats << Material.RoofingGalvanizedSteel
    mats << Material.RoofingTileClayorCeramic
    mats << Material.RoofingTileClayorCeramicWhiteCool
    mats << Material.RoofingWoodShingles
    mats << Material.RoofingCompositionShingles
    mats << Material.RoofingCompositionShinglesWhiteCool
    mats << Material.RoofingTileConcrete
    mats << Material.RoofingTileConcreteWhiteCool
    mats << Material.RoofingSlate
    return mats
  end

  def self.get_roofing_material(name)
    get_roofing_materials.each do |mat|
      next if mat.name != name

      return mat
    end
    return
  end

  private

  def self.get_roofing_material_manual_j_color(name)
    if name == Material.RoofingAsphaltShinglesDark.name
      return Constants.ColorDark
    elsif name == Material.RoofingAsphaltShinglesMed.name
      return Constants.ColorMedium
    elsif name == Material.RoofingAsphaltShinglesLight.name
      return Constants.ColorLight
    elsif name == Material.RoofingAsphaltShinglesWhiteCool.name
      return Constants.ColorWhite
    elsif name == Material.RoofingTileDark.name
      return Constants.ColorDark
    elsif name == Material.RoofingTileMed.name
      return Constants.ColorMedium
    elsif name == Material.RoofingTileLight.name
      return Constants.ColorLight
    elsif name == Material.RoofingTileWhite.name
      return Constants.ColorWhite
    elsif name == Material.RoofingMetalDark.name
      return Constants.ColorDark
    elsif name == Material.RoofingMetalCool.name
      return Constants.ColorWhite
    elsif name == Material.RoofingMetalMed.name
      return Constants.ColorMedium
    elsif name == Material.RoofingMetalLight.name
      return Constants.ColorLight
    elsif name == Material.RoofingMetalWhite.name
      return Constants.ColorWhite
    elsif name == Material.RoofingGalvanizedSteel.name
      return Constants.ColorLight
    elsif name == Material.RoofingTileClayorCeramic.name
      return Constants.ColorMedium
    elsif name == Material.RoofingTileClayorCeramicWhiteCool.name
      return Constants.ColorWhite
    elsif name == Material.RoofingWoodShingles.name
      return Constants.ColorMedium
    elsif name == Material.RoofingCompositionShingles.name
      return Constants.ColorMedium
    elsif name == Material.RoofingCompositionShinglesWhiteCool.name
      return Constants.ColorWhite
    elsif name == Material.RoofingTileConcrete.name
      return Constants.ColorMedium
    elsif name == Material.RoofingTileConcreteWhiteCool.name
      return Constants.ColorWhite
    elsif name == Material.RoofingSlate.name
      return Constants.ColorMedium
    end

    return
  end

  def self.get_roofing_material_manual_j_material(name)
    if name == Material.RoofingAsphaltShinglesDark.name
      return Constants.RoofMaterialAsphaltShingles
    elsif name == Material.RoofingAsphaltShinglesMed.name
      return Constants.RoofMaterialAsphaltShingles
    elsif name == Material.RoofingAsphaltShinglesLight.name
      return Constants.RoofMaterialAsphaltShingles
    elsif name == Material.RoofingAsphaltShinglesWhiteCool.name
      return Constants.RoofMaterialAsphaltShingles
    elsif name == Material.RoofingTileDark.name
      return Constants.RoofMaterialTile
    elsif name == Material.RoofingTileMed.name
      return Constants.RoofMaterialTile
    elsif name == Material.RoofingTileLight.name
      return Constants.RoofMaterialTile
    elsif name == Material.RoofingTileWhite.name
      return Constants.RoofMaterialTile
    elsif name == Material.RoofingMetalDark.name
      return Constants.RoofMaterialMetal
    elsif name == Material.RoofingMetalCool.name
      return Constants.RoofMaterialMetal
    elsif name == Material.RoofingMetalMed.name
      return Constants.RoofMaterialMetal
    elsif name == Material.RoofingMetalLight.name
      return Constants.RoofMaterialMetal
    elsif name == Material.RoofingMetalWhite.name
      return Constants.RoofMaterialMetal
    elsif name == Material.RoofingGalvanizedSteel.name
      return Constants.RoofMaterialMetal
    elsif name == Material.RoofingTileClayorCeramic.name
      return Constants.RoofMaterialTile
    elsif name == Material.RoofingTileClayorCeramicWhiteCool.name
      return Constants.RoofMaterialTile
    elsif name == Material.RoofingWoodShingles.name
      return Constants.RoofMaterialWoodShakes
    elsif name == Material.RoofingCompositionShingles.name
      return Constants.RoofMaterialAsphaltShingles
    elsif name == Material.RoofingCompositionShinglesWhiteCool.name
      return Constants.RoofMaterialAsphaltShingles
    elsif name == Material.RoofingTileConcrete.name
      return Constants.RoofMaterialTile
    elsif name == Material.RoofingTileConcreteWhiteCool.name
      return Constants.RoofMaterialTile
    elsif name == Material.RoofingSlate.name
      return Constants.RoofMaterialTile
    end

    return
  end
end

class FloorConstructions
  # Container class for above-grade floor constructions

  # Unfinished attic floor
  def self.apply_unfinished_attic(runner, model, surfaces, constr_name,
                                  cavity_r, install_grade, ins_thick_in,
                                  framing_factor, joist_height_in,
                                  drywall_thick_in)

    return true if surfaces.empty?

    # Validate Inputs
    if cavity_r < 0.0
      runner.registerError('Ceiling Insulation Nominal R-value must be greater than or equal to 0.')
      return false
    end
    if ins_thick_in < 0.0
      runner.registerError('Ceiling Insulation Thickness must be greater than or equal to 0.')
      return false
    end
    if (framing_factor < 0.0) || (framing_factor >= 1.0)
      runner.registerError('Ceiling Framing Factor must be greater than or equal to 0 and less than 1.')
      return false
    end
    if joist_height_in <= 0.0
      runner.registerError('Ceiling Joist Height must be greater than 0.')
      return false
    end

    # TODO: Attic perimeter derate is currently disabled
    # <- implementation goes here ->

    # Define materials
    mat_addtl_ins = nil
    if ins_thick_in >= joist_height_in
      # If the ceiling insulation thickness is greater than the joist thickness
      cavity_k = ins_thick_in / cavity_r
      if ins_thick_in > joist_height_in
        # If there is additional insulation beyond the rafter height,
        # these inputs are used for defining an additional layer
        mat_addtl_ins = Material.new(name = 'FloorUAAdditionalCeilingIns', thick_in = (ins_thick_in - joist_height_in), mat_base = BaseMaterial.InsulationGenericLoosefill, k_in = cavity_k)
      end
      mat_cavity = Material.new(name = nil, thick_in = joist_height_in, mat_base = BaseMaterial.InsulationGenericLoosefill, k_in = cavity_k)
    else
      # Else the joist thickness is greater than the ceiling insulation thickness
      if cavity_r == 0
        mat_cavity = Material.AirCavityOpen(joist_height_in)
      else
        mat_cavity = Material.new(name = nil, thick_in = joist_height_in, mat_base = BaseMaterial.InsulationGenericLoosefill, k_in = joist_height_in / cavity_r)
      end
    end
    mat_framing = Material.new(name = nil, thick_in = joist_height_in, mat_base = BaseMaterial.Wood)
    mat_gap = Material.AirCavityOpen(joist_height_in)

    # Set paths
    gapFactor = get_gap_factor(install_grade, framing_factor, cavity_r)
    path_fracs = [framing_factor, 1 - framing_factor - gapFactor, gapFactor]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    constr.add_layer(Material.AirFilmFloorAverage)
    if drywall_thick_in > 0
      constr.add_layer(Material.GypsumWall(drywall_thick_in))
    end
    constr.add_layer([mat_framing, mat_cavity, mat_gap], 'FloorUATrussandIns')
    if not mat_addtl_ins.nil?
      constr.add_layer(mat_addtl_ins)
    end
    constr.add_layer(Material.AirFilmFloorAverage)

    # Create and assign construction to ceiling surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    return true
  end

  # Basement/crawlspace ceiling
  def self.apply_foundation_ceiling(runner, model, surfaces, constr_name,
                                    cavity_r, install_grade,
                                    framing_factor, joist_height_in,
                                    plywood_thick_in, mat_floor_covering,
                                    mat_carpet)

    return true if surfaces.empty?

    # Validate Inputs
    if cavity_r < 0.0
      runner.registerError('Ceiling Cavity Insulation Nominal R-value must be greater than or equal to 0.')
      return false
    end
    if (framing_factor < 0.0) || (framing_factor >= 1.0)
      runner.registerError('Ceiling Framing Factor must be greater than or equal to 0 and less than 1.')
      return false
    end
    if joist_height_in <= 0.0
      runner.registerError('Ceiling Joist Height must be greater than 0.')
      return false
    end

    # Define materials
    mat_2x = Material.Stud2x(joist_height_in)
    if cavity_r == 0
      mat_cavity = Material.AirCavityOpen(mat_2x.thick_in)
    else
      mat_cavity = Material.new(name = nil, thick_in = mat_2x.thick_in, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = mat_2x.thick_in / cavity_r)
    end
    mat_framing = Material.new(name = nil, thick_in = mat_2x.thick_in, mat_base = BaseMaterial.Wood)
    mat_gap = Material.AirCavityOpen(joist_height_in)

    # Set paths
    gapFactor = get_gap_factor(install_grade, framing_factor, cavity_r)
    path_fracs = [framing_factor, 1 - framing_factor - gapFactor, gapFactor]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    constr.add_layer(Material.AirFilmFloorReduced)
    constr.add_layer([mat_framing, mat_cavity, mat_gap], 'FloorIns')
    if plywood_thick_in > 0
      constr.add_layer(Material.Plywood(plywood_thick_in))
    end
    if not mat_floor_covering.nil?
      constr.add_layer(mat_floor_covering)
    end
    if not mat_carpet.nil?
      constr.add_layer(mat_carpet)
    end
    constr.add_layer(Material.AirFilmFloorReduced)

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    return true
  end

  def self.apply_uninsulated(runner, model, surfaces, constr_name,
                             plywood_thick_in, drywall_thick_in,
                             mat_floor_covering, mat_carpet)

    return true if surfaces.empty?

    # Define materials
    mat_cavity = Material.AirCavityClosed(Material.Stud2x6.thick_in)
    mat_framing = Material.new(name = nil, thick_in = Material.Stud2x6.thick_in, mat_base = BaseMaterial.Wood)

    # Set paths
    path_fracs = [Constants.DefaultFramingFactorFloor, 1 - Constants.DefaultFramingFactorFloor]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    constr.add_layer(Material.AirFilmFloorAverage)
    if drywall_thick_in > 0
      constr.add_layer(Material.GypsumWall(drywall_thick_in))
    end
    constr.add_layer([mat_framing, mat_cavity], 'FloorFinStudAndAirFloor')
    if plywood_thick_in > 0
      constr.add_layer(Material.Plywood(plywood_thick_in))
    end
    if not mat_floor_covering.nil?
      constr.add_layer(mat_floor_covering)
    end
    if not mat_carpet.nil?
      constr.add_layer(mat_carpet)
    end
    constr.add_layer(Material.AirFilmFloorAverage)

    # Create and apply construction to surfaces
    if not constr.create_and_assign_constructions(surfaces, runner, model)
      return false
    end

    return true
  end

  def self.get_default_floor_ufactor(iecc_zone_2006)
    # Table 4.2.2(2) - Component Heat Transfer Characteristics for Reference Home
    # Floor Over Unconditioned Space U-Factor
    if ['1A', '1B', '1C', '2A', '2B', '2C'].include? iecc_zone_2006
      return 0.064
    elsif ['3A', '3B', '3C', '4A', '4B'].include? iecc_zone_2006
      return 0.047
    elsif ['4C', '5A', '5B', '5C', '6A', '6B', '6C', '7', '8'].include? iecc_zone_2006
      return 0.033
    else
      return
    end
  end

  def self.get_default_ceiling_ufactor(iecc_zone_2006)
    # Table 4.2.2(2) - Component Heat Transfer Characteristics for Reference Home
    # Ceiling U-Factor
    if ['1A', '1B', '1C', '2A', '2B', '2C', '3A', '3B', '3C'].include? iecc_zone_2006
      return 0.035
    elsif ['4A', '4B', '4C', '5A', '5B', '5C'].include? iecc_zone_2006
      return 0.030
    elsif ['6A', '6B', '6C', '7', '8'].include? iecc_zone_2006
      return 0.026
    else
      return
    end
  end
end

class FoundationConstructions
  # Container class for below-grade wall/floor constructions
  # Note: Each slab surface (w/ connected walls) must have its own foundation object.

  # Basement/crawlspace
  def self.apply_walls_and_slab(runner, model, wall_surfaces, walls_constr_name,
                                walls_ins_height, walls_cavity_r, walls_install_grade,
                                walls_cavity_depth_in, walls_filled_cavity, walls_framing_factor,
                                walls_rigid_r, walls_drywall_thick_in, walls_concrete_thick_in,
                                space_height, slab_surface, slab_constr_name,
                                slab_whole_r, slab_concrete_thick_in, exposed_perimeter = nil)

    return true if slab_surface.nil?

    if wall_surfaces.empty?
      runner.registerError('No wall surfaces found adjacent to floor surface.')
      return false
    end

    # Validate inputs
    if walls_ins_height < 0.0
      runner.registerError('Wall Insulation Height must be greater than or equal to 0.')
      return false
    end
    if walls_cavity_r < 0.0
      runner.registerError('Wall Cavity Insulation Installed R-value must be greater than or equal to 0.')
      return false
    end
    if walls_cavity_depth_in < 0.0
      runner.registerError('Wall Cavity Depth must be greater than or equal to 0.')
      return false
    end
    if (walls_framing_factor < 0.0) || (walls_framing_factor >= 1.0)
      runner.registerError('Wall Framing Factor must be greater than or equal to 0 and less than 1.')
      return false
    end
    if walls_rigid_r < 0.0
      runner.registerError('Wall Continuous Insulation Nominal R-value must be greater than or equal to 0.')
      return false
    end

    # Calculate interior wall R-value
    int_wall_Rvalue = calc_interior_wall_r_value(runner, walls_cavity_depth_in, walls_cavity_r,
                                                 walls_filled_cavity, walls_framing_factor,
                                                 walls_install_grade, walls_rigid_r,
                                                 walls_drywall_thick_in)
    if int_wall_Rvalue.nil?
      return false
    end

    # Create Kiva foundation
    foundation = create_kiva_crawl_or_basement_foundation(model, int_wall_Rvalue, space_height,
                                                          walls_rigid_r, walls_ins_height)

    # Define materials
    mat_concrete = Material.Concrete(walls_concrete_thick_in)

    # Define construction
    constr = Construction.new(walls_constr_name, [1])
    constr.add_layer(mat_concrete)
    if walls_drywall_thick_in > 0
      constr.add_layer(Material.GypsumWall(walls_drywall_thick_in))
    end

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions(wall_surfaces, runner, model)
      return false
    end

    # Assign surfaces to Kiva foundation
    wall_surfaces.each do |wall_surface|
      if wall_surface.outsideBoundaryCondition != 'Adiabatic'
        wall_surface.setAdjacentFoundation(foundation)
      end
    end

    if not apply_slab(runner, model, slab_surface, slab_constr_name,
                      0, 0, 0, 0, 0, slab_whole_r, slab_concrete_thick_in,
                      nil, true, exposed_perimeter, foundation)
      return false
    end

    return true
  end

  # Slabs
  def self.apply_slab(runner, model, surface, constr_name,
                      perimeter_r, perimeter_width,
                      gap_r, exterior_r, exterior_depth,
                      whole_r, concrete_thick_in, mat_carpet = nil,
                      has_fnd_walls = false, exposed_perimeter = nil,
                      foundation = nil)

    return true if surface.nil?

    # Validate inputs
    if perimeter_r < 0.0
      runner.registerError('Perimeter Insulation Nominal R-value must be greater than or equal to 0.')
      return false
    end
    if perimeter_width < 0.0
      runner.registerError('Perimeter Insulation Width must be greater than or equal to 0.')
      return false
    end
    if gap_r < 0.0
      runner.registerError('Gap Insulation Nominal R-value must be greater than or equal to 0.')
      return false
    end
    if exterior_r < 0.0
      runner.registerError('Exterior Insulation Nominal R-value must be greater than or equal to 0.')
      return false
    end
    if exterior_depth < 0.0
      runner.registerError('Exterior Insulation Depth must be greater than or equal to 0.')
      return false
    end
    if whole_r < 0.0
      runner.registerError('Whole Slab Insulation Nominal R-value must be greater than or equal to 0.')
      return false
    end

    if foundation.nil?
      # Create Kiva foundation
      thick = UnitConversions.convert(concrete_thick_in, 'in', 'ft')
      foundation = create_kiva_slab_foundation(model, perimeter_r, perimeter_width,
                                               gap_r, thick, exterior_r, exterior_depth)
    end

    # Define materials
    mat_concrete = nil
    mat_soil = nil
    if concrete_thick_in > 0
      mat_concrete = Material.Concrete(concrete_thick_in)
    else
      # Use 0.5 - 1.0 inches of soil, per Neal Kruis recommendation
      mat_soil = Material.Soil(0.5)
    end
    mat_rigid = nil
    if whole_r > 0
      rigid_thick_in = whole_r * BaseMaterial.InsulationRigid.k_in
      mat_rigid = Material.new(name = 'SlabRigidIns', thick_in = rigid_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = rigid_thick_in / whole_r)
    end

    # Define construction
    constr = Construction.new(constr_name, [1.0])
    if not mat_rigid.nil?
      constr.add_layer(mat_rigid)
    end
    if not mat_concrete.nil?
      constr.add_layer(mat_concrete)
    end
    if not mat_soil.nil?
      constr.add_layer(mat_soil)
    end
    if not mat_carpet.nil?
      constr.add_layer(mat_carpet)
    end

    # Create and assign construction to surfaces
    if not constr.create_and_assign_constructions([surface], runner, model)
      return false
    end

    # Exposed perimeter
    if exposed_perimeter.nil?
      exposed_perimeter = Geometry.calculate_exposed_perimeter(model, [surface], has_fnd_walls)
    end
    if surface.outsideBoundaryCondition.downcase == 'foundation'
      if exposed_perimeter <= 0
        runner.registerError("Calculated an exposed perimeter <= 0 for slab '#{surface.name}'.")
        return false
      end
      # Assign surface to Kiva foundation
      surface.setAdjacentFoundation(foundation)
      surface.createSurfacePropertyExposedFoundationPerimeter('TotalExposedPerimeter', UnitConversions.convert(exposed_perimeter, 'ft', 'm'))
    end

    return true
  end

  def self.get_default_basement_wall_ufactor(iecc_zone_2006)
    # Table 4.2.2(2) - Component Heat Transfer Characteristics for Reference Home
    # Basement Wall U-Factor
    if ['1A', '1B', '1C', '2A', '2B', '2C', '3A', '3B', '3C'].include? iecc_zone_2006
      return 0.360
    elsif ['4A', '4B', '4C', '5A', '5B', '5C', '6A', '6B', '6C', '7', '8'].include? iecc_zone_2006
      return 0.059
    else
      return
    end
  end

  def self.get_default_slab_perimeter_rvalue_depth(iecc_zone_2006)
    # Table 4.2.2(2) - Component Heat Transfer Characteristics for Reference Home
    # Slab-on-Grade R-Value & Depth (ft)
    if ['1A', '1B', '1C', '2A', '2B', '2C', '3A', '3B', '3C'].include? iecc_zone_2006
      return 0.0, 0.0
    elsif ['4A', '4B', '4C', '5A', '5B', '5C'].include? iecc_zone_2006
      return 10.0, 2.0
    elsif ['6A', '6B', '6C', '7', '8'].include? iecc_zone_2006
      return 10.0, 4.0
    else
      return
    end
  end

  def self.get_default_slab_under_rvalue_width()
    return 0.0, 0.0
  end

  private

  def self.calc_interior_wall_r_value(runner, cavity_depth_in, cavity_r, filled_cavity,
                                      framing_factor, install_grade, rigid_r, drywall_thick_in)

    # Define materials
    mat_framing = nil
    mat_cavity = nil
    mat_gap = nil
    if cavity_depth_in > 0
      if cavity_r > 0
        if filled_cavity
          # Insulation
          mat_cavity = Material.new(name = nil, thick_in = cavity_depth_in, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = cavity_depth_in / cavity_r)
        else
          # Insulation plus air gap when insulation thickness < cavity depth
          mat_cavity = Material.new(name = nil, thick_in = cavity_depth_in, mat_base = BaseMaterial.InsulationGenericDensepack, k_in = cavity_depth_in / (cavity_r + Gas.AirGapRvalue))
        end
      else
        # Empty cavity
        mat_cavity = Material.AirCavityClosed(cavity_depth_in)
      end
      mat_framing = Material.new(name = nil, thick_in = cavity_depth_in, mat_base = BaseMaterial.Wood)
      mat_gap = Material.AirCavityClosed(cavity_depth_in)
    end
    mat_drywall = nil
    drywall_r = 0
    if drywall_thick_in > 0
      mat_drywall = Material.GypsumWall(drywall_thick_in)
      drywall_r = mat_drywall.rvalue
    end
    mat_rigid = nil
    if rigid_r > 0
      rigid_thick_in = rigid_r * BaseMaterial.InsulationRigid.k_in
      mat_rigid = Material.new(name = nil, thick_in = rigid_thick_in, mat_base = BaseMaterial.InsulationRigid, k_in = rigid_thick_in / rigid_r)
    end

    # Set paths
    gapFactor = get_gap_factor(install_grade, framing_factor, cavity_r)
    path_fracs = [framing_factor, 1 - framing_factor - gapFactor, gapFactor]

    # Define construction (only used to calculate assembly R-value)
    constr = Construction.new(nil, path_fracs)
    if not mat_drywall.nil?
      constr.add_layer(mat_drywall)
    end
    if (not mat_framing.nil?) && (not mat_cavity.nil?) && (not mat_gap.nil?)
      constr.add_layer(Material.AirFilmVertical)
      constr.add_layer([mat_framing, mat_cavity, mat_gap])
    end
    if not mat_rigid.nil?
      constr.add_layer(mat_rigid)
    end

    return constr.assembly_rvalue(runner) - rigid_r - drywall_r
  end

  def self.create_kiva_slab_foundation(model, int_horiz_r, int_horiz_width, int_vert_r,
                                       int_vert_depth, ext_vert_r, ext_vert_depth)

    # Create the Foundation:Kiva object for slab foundations
    foundation = OpenStudio::Model::FoundationKiva.new(model)

    # Interior horizontal insulation
    if (int_horiz_r > 0) && (int_horiz_width > 0)
      int_horiz_mat = create_insulation_material(model, 'FoundationIntHorizIns', int_horiz_r)
      foundation.setInteriorHorizontalInsulationMaterial(int_horiz_mat)
      foundation.setInteriorHorizontalInsulationDepth(0)
      foundation.setInteriorHorizontalInsulationWidth(UnitConversions.convert(int_horiz_width, 'ft', 'm'))
    end

    # Interior vertical insulation
    if int_vert_r > 0
      int_vert_mat = create_insulation_material(model, 'FoundationIntVertIns', int_vert_r)
      foundation.setInteriorVerticalInsulationMaterial(int_vert_mat)
      foundation.setInteriorVerticalInsulationDepth(UnitConversions.convert(int_vert_depth, 'ft', 'm'))
    end

    # Exterior vertical insulation
    if (ext_vert_r > 0) && (ext_vert_depth > 0)
      ext_vert_mat = create_insulation_material(model, 'FoundationExtVertIns', ext_vert_r)
      foundation.setExteriorVerticalInsulationMaterial(ext_vert_mat)
      foundation.setExteriorVerticalInsulationDepth(UnitConversions.convert(ext_vert_depth, 'ft', 'm'))
    end

    foundation.setWallHeightAboveGrade(UnitConversions.convert(8.0, 'in', 'm'))
    foundation.setWallDepthBelowSlab(UnitConversions.convert(8.0, 'in', 'm'))

    # Footing wall construction
    footing_mat = create_footing_material(model, 'FootingMaterial')
    footing_constr = OpenStudio::Model::Construction.new([footing_mat])
    footing_constr.setName('FootingConstruction')
    foundation.setFootingWallConstruction(footing_constr)

    apply_kiva_settings(model)

    return foundation
  end

  def self.create_kiva_crawl_or_basement_foundation(model, int_vert_r, int_vert_depth,
                                                    ext_vert_r, ext_vert_depth)

    # Create the Foundation:Kiva object for crawl/basement foundations
    foundation = OpenStudio::Model::FoundationKiva.new(model)

    # Interior vertical insulation
    if (int_vert_r > 0) && (int_vert_depth > 0)
      int_vert_mat = create_insulation_material(model, 'FoundationIntVertIns', int_vert_r)
      foundation.setInteriorVerticalInsulationMaterial(int_vert_mat)
      foundation.setInteriorVerticalInsulationDepth(UnitConversions.convert(int_vert_depth, 'ft', 'm'))
    end

    # Exterior vertical insulation
    if (ext_vert_r > 0) && (ext_vert_depth > 0)
      ext_vert_mat = create_insulation_material(model, 'FoundationExtVertIns', ext_vert_r)
      foundation.setExteriorVerticalInsulationMaterial(ext_vert_mat)
      foundation.setExteriorVerticalInsulationDepth(UnitConversions.convert(ext_vert_depth, 'ft', 'm'))
    end

    foundation.setWallHeightAboveGrade(UnitConversions.convert(8.0, 'in', 'm'))
    foundation.setWallDepthBelowSlab(UnitConversions.convert(8.0, 'in', 'm'))

    apply_kiva_settings(model)

    return foundation
  end

  def self.apply_kiva_settings(model)
    # Set the Foundation:Kiva:Settings object
    soil_mat = BaseMaterial.Soil
    settings = model.getFoundationKivaSettings
    settings.setSoilConductivity(UnitConversions.convert(soil_mat.k_in, 'Btu*in/(hr*ft^2*R)', 'W/(m*K)'))
    settings.setSoilDensity(UnitConversions.convert(soil_mat.rho, 'lbm/ft^3', 'kg/m^3'))
    settings.setSoilSpecificHeat(UnitConversions.convert(soil_mat.cp, 'Btu/(lbm*R)', 'J/(kg*K)'))
    settings.setGroundSolarAbsorptivity(0.9)
    settings.setGroundThermalAbsorptivity(0.9)
    settings.setGroundSurfaceRoughness(0.03)
    settings.setFarFieldWidth(40) # TODO: Set based on neighbor distances
    settings.setDeepGroundBoundaryCondition('ZeroFlux')
    settings.setDeepGroundDepth(40)
    settings.setMinimumCellDimension(0.02)
    settings.setMaximumCellGrowthCoefficient(1.5)
    settings.setSimulationTimestep('Hourly')
  end

  def self.create_insulation_material(model, name, rvalue)
    rigid_mat = BaseMaterial.InsulationRigid
    mat = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    mat.setName(name)
    mat.setRoughness('Rough')
    mat.setThickness(UnitConversions.convert(rvalue * rigid_mat.k_in, 'in', 'm'))
    mat.setConductivity(UnitConversions.convert(rigid_mat.k_in, 'Btu*in/(hr*ft^2*R)', 'W/(m*K)'))
    mat.setDensity(UnitConversions.convert(rigid_mat.rho, 'lbm/ft^3', 'kg/m^3'))
    mat.setSpecificHeat(UnitConversions.convert(rigid_mat.cp, 'Btu/(lbm*R)', 'J/(kg*K)'))
    return mat
  end

  def self.create_footing_material(model, name)
    footing_mat = Material.Concrete(8.0)
    mat = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    mat.setName(name)
    mat.setRoughness('Rough')
    mat.setThickness(UnitConversions.convert(footing_mat.thick_in, 'in', 'm'))
    mat.setConductivity(UnitConversions.convert(footing_mat.k_in, 'Btu*in/(hr*ft^2*R)', 'W/(m*K)'))
    mat.setDensity(UnitConversions.convert(footing_mat.rho, 'lbm/ft^3', 'kg/m^3'))
    mat.setSpecificHeat(UnitConversions.convert(footing_mat.cp, 'Btu/(lbm*R)', 'J/(kg*K)'))
    mat.setThermalAbsorptance(footing_mat.tAbs)
    return mat
  end
end

class SubsurfaceConstructions
  # Container class for door/window constructions

  def self.apply_door(runner, model, subsurfaces, constr_name, ufactor)
    return true if subsurfaces.empty?

    # Validate Inputs
    if ufactor <= 0.0
      runner.registerError('Door U-Factor must be greater than 0.')
      return false
    end

    # Define materials
    door_Rvalue = 1.0 / ufactor - Material.AirFilmOutside.rvalue - Material.AirFilmVertical.rvalue
    door_thickness = 1.75 # in
    fin_door_mat = Material.new(name = 'DoorMaterial', thick_in = door_thickness, mat_base = BaseMaterial.Wood, k_in = 1.0 / door_Rvalue * door_thickness)

    # Set paths
    path_fracs = [1]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    constr.add_layer(fin_door_mat)

    # Create and assign construction to subsurfaces
    if not constr.create_and_assign_constructions(subsurfaces, runner, model)
      return false
    end

    return true
  end

  def self.apply_window(runner, model, subsurfaces, constr_name, weather,
                        cooling_season, ufactor, shgc, heat_shade_mult, cool_shade_mult)

    success = apply_window_skylight(runner, model, 'Window', subsurfaces, constr_name, weather,
                                    cooling_season, ufactor, shgc, heat_shade_mult, cool_shade_mult)
    return false if not success

    return true
  end

  def self.apply_skylight(runner, model, subsurfaces, constr_name, weather,
                          cooling_season, ufactor, shgc, heat_shade_mult, cool_shade_mult)

    success = apply_window_skylight(runner, model, 'Skylight', subsurfaces, constr_name, weather,
                                    cooling_season, ufactor, shgc, heat_shade_mult, cool_shade_mult)
    return false if not success

    return true
  end

  def self.apply_window_skylight(runner, model, type, subsurfaces, constr_name, weather,
                                 cooling_season, ufactor, shgc, heat_shade_mult, cool_shade_mult)

    return true if subsurfaces.empty?

    # Validate Inputs
    if ufactor <= 0
      runner.registerError("#{type} U-factor must be greater than zero.")
      return false
    end
    if shgc <= 0
      runner.registerError("#{type} SHGC must be greater than zero.")
      return false
    end
    if (heat_shade_mult < 0) || (heat_shade_mult > 1)
      runner.registerError('Heating Shade Multiplier must be greater than or equal to zero and less than or equal to one.')
      return false
    end
    if (cool_shade_mult < 0) || (cool_shade_mult > 1)
      runner.registerError('Cooling Shade Multiplier must be greater than or equal to zero and less than or equal to one.')
      return false
    end

    # Define shade and schedule
    sc = nil
    if (cool_shade_mult < 1) || (heat_shade_mult < 1)
      # EnergyPlus doesn't like shades that absorb no heat, transmit no heat or reflect no heat.
      if cool_shade_mult == 1
        cool_shade_mult = 0.999
      end
      if heat_shade_mult == 1
        heat_shade_mult = 0.999
      end

      total_shade_trans = cool_shade_mult / heat_shade_mult * 0.999
      total_shade_abs = 0.00001
      total_shade_ref = 1 - total_shade_trans - total_shade_abs

      # Interior Shading Schedule
      sch = MonthWeekdayWeekendSchedule.new(model, runner, "#{type} shading schedule", Array.new(24, 1), Array.new(24, 1), cooling_season, mult_weekday = 1.0, mult_weekend = 1.0, normalized_values = true, create_sch_object = true, winter_design_day_sch = nil, summer_design_day_sch = nil, schedule_type_limits_name = Constants.ScheduleTypeLimitsFraction)
      if not sch.validated?
        return false
      end

      # CoolingShade
      sm = OpenStudio::Model::Shade.new(model)
      sm.setName('CoolingShade')
      sm.setSolarTransmittance(total_shade_trans)
      sm.setSolarReflectance(total_shade_ref)
      sm.setVisibleTransmittance(total_shade_trans)
      sm.setVisibleReflectance(total_shade_ref)
      sm.setThermalHemisphericalEmissivity(total_shade_abs)
      sm.setThermalTransmittance(total_shade_trans)
      sm.setThickness(0.0001)
      sm.setConductivity(10000)
      sm.setShadetoGlassDistance(0.001)
      sm.setTopOpeningMultiplier(0)
      sm.setBottomOpeningMultiplier(0)
      sm.setLeftSideOpeningMultiplier(0)
      sm.setRightSideOpeningMultiplier(0)
      sm.setAirflowPermeability(0)

      # ShadingControl
      sc = OpenStudio::Model::ShadingControl.new(sm)
      sc.setName("#{type}ShadingControl")
      sc.setShadingType('InteriorShade')
      sc.setShadingControlType('OnIfScheduleAllows')
      sc.setSchedule(sch.schedule)
    end

    # Define materials
    glaz_mat = GlazingMaterial.new(name = "#{type}Material", ufactor = ufactor, shgc *= heat_shade_mult)

    # Set paths
    path_fracs = [1]

    # Define construction
    constr = Construction.new(constr_name, path_fracs)
    constr.add_layer(glaz_mat)

    # Create and assign construction to subsurfaces
    if not constr.create_and_assign_constructions(subsurfaces, runner, model)
      return false
    end

    sc_msg = ''
    if sc.nil?
      # Remove any existing shading controls
      objects_to_remove = []
      subsurfaces.each do |subsurface|
        next if not subsurface.shadingControl.is_initialized

        shade_control = subsurface.shadingControl.get
        if shade_control.shadingMaterial.is_initialized
          objects_to_remove << shade_control.shadingMaterial.get
        end
        if shade_control.schedule.is_initialized
          objects_to_remove << shade_control.schedule.get
        end
        objects_to_remove << shade_control
        subsurface.resetShadingControl
      end
      objects_to_remove.uniq.each do |object|
        begin
          object.remove
        rescue
          # no op
        end
      end
    else
      # Add shading controls
      sc_msg = ' and interior shades'
      subsurfaces.each do |subsurface|
        subsurface.setShadingControl(sc)
      end
    end

    runner.registerInfo("Construction#{sc_msg} added to #{subsurfaces.size} #{constr_name.gsub('Construction', '').downcase}(s).")

    return true
  end

  def self.get_default_interior_shading_factors()
    summer = 0.70
    winter = 0.85
    return summer, winter
  end

  def self.get_default_ufactor_shgc(iecc_zone_2006)
    # Table 4.2.2(2) - Component Heat Transfer Characteristics for Reference Home
    # Fenestration and Opaque Door U-Factor
    # Glazed Fenestration Assembly SHGC
    if ['1A', '1B', '1C'].include? iecc_zone_2006
      return 1.2, 0.40
    elsif ['2A', '2B', '2C'].include? iecc_zone_2006
      return 0.75, 0.40
    elsif ['3A', '3B', '3C'].include? iecc_zone_2006
      return 0.65, 0.40
    elsif ['4A', '4B'].include? iecc_zone_2006
      return 0.40, 0.40
    elsif ['4C', '5A', '5B', '5C', '6A', '6B', '6C', '7', '8'].include? iecc_zone_2006
      return 0.35, 0.40
    else
      return
    end
  end

  def self.get_default_door_area()
    # Table 4.2.2(1) Specifications for the Reference and Rated Homes - Doors
    return 40.0
  end

  def self.get_default_door_azimuth()
    # Table 4.2.2(1) Specifications for the Reference and Rated Homes - Doors
    return 0 # North
  end
end

class ThermalMassConstructions
  # Container class for additional thermal mass (partition/furniture) constructions

  def self.apply(runner, model, walls_by_type, drywall_thick_in,
                 partition_wall_frac_of_ffa = 1.0, furniture_frac_of_ffa = 0.4)

    if not apply_partition_walls(runner, model,
                                 walls_by_type[Constants.SurfaceTypeWallIntFinUninsFin],
                                 Constants.SurfaceTypeWallIntFinUninsFin,
                                 drywall_thick_in, partition_wall_frac_of_ffa)
      return false
    end

    if not apply_furniture(runner, model, furniture_frac_of_ffa)
      return false
    end

    return true
  end

  private

  # Potentially adds more thermal mass if not enough
  # partition walls already exist.
  def self.apply_partition_walls(runner, model, surfaces, constr_name,
                                 drywall_thick_in, frac_of_ffa)

    spaces = Geometry.get_finished_spaces(model.getSpaces)

    return true if spaces.empty?

    # Validate Inputs
    if frac_of_ffa < 0
      runner.registerError('Fraction of Floor Area must be greater than or equal to 0.')
      return false
    end

    imdefs = []
    spaces.each do |space|
      # Determine partition wall area (frac_of_ffa = 1 includes both sides of partition wall)
      part_surface_area = frac_of_ffa * space.floorArea

      # Remove any existing internal mass
      space.internalMass.each do |im|
        runner.registerInfo("Removing internal mass object '#{im.name}' from space '#{space.name}'")
        imdef = im.internalMassDefinition
        im.remove
        imdef.resetConstruction
        imdef.remove
      end

      # Add partition walls within spaces (those without geometric representation)
      # as internal mass object.
      imdef = OpenStudio::Model::InternalMassDefinition.new(model)
      imdef.setName("#{space.name} Partition")
      imdef.setSurfaceArea(part_surface_area)
      imdefs << imdef

      im = OpenStudio::Model::InternalMass.new(imdef)
      im.setName("#{space.name} Partition")
      im.setSpace(space)
      runner.registerInfo("Added internal mass object '#{im.name}' to space '#{space.name}'")
    end

    if not WallConstructions.apply_wood_stud(runner, model,
                                             imdefs,
                                             constr_name,
                                             0, 1, 3.5, false,
                                             Constants.DefaultFramingFactorInterior,
                                             drywall_thick_in, 0, 0, nil)
      return false
    end

    return true
  end

  def self.apply_furniture(runner, model, frac_of_ffa, mass_lb_per_sqft = 8.0,
                           density_lb_per_cuft = 40.0, mat = BaseMaterial.Wood)

    # Remove any existing furniture mass.
    furniture_removed = false
    model.getInternalMasss.each do |im|
      next if not im.name.get.include?(Constants.ObjectNameFurniture)

      md = im.internalMassDefinition
      im.remove
      md.remove
      furniture_removed = true
    end
    if furniture_removed
      runner.registerInfo('Removed existing furniture mass.')
    end

    model_spaces = model.getSpaces

    finished_spaces = Geometry.get_finished_spaces(model_spaces)
    unfinished_basement_spaces = Geometry.get_unfinished_basement_spaces(model_spaces)
    garage_spaces = Geometry.get_garage_spaces(model_spaces)

    # Add user-specified furniture mass
    model_spaces.each do |space|
      furnAreaFraction = nil
      furnConductivity = mat.k_in
      furnSolarAbsorptance = 0.6
      furnSpecHeat = mat.cp
      furnDensity = density_lb_per_cuft
      if finished_spaces.include?(space) || unfinished_basement_spaces.include?(space)
        furnAreaFraction = frac_of_ffa
        furnMass = mass_lb_per_sqft
      elsif garage_spaces.include?(space)
        furnAreaFraction = 0.1
        furnMass = 2.0
      end

      next if furnAreaFraction.nil?
      next if furnAreaFraction <= 0
      next if space.floorArea <= 0

      mat_obj_name_space = "#{Constants.ObjectNameFurniture} material #{space.name}"
      constr_obj_name_space = "#{Constants.ObjectNameFurniture} construction #{space.name}"
      mass_obj_name_space = "#{Constants.ObjectNameFurniture} mass #{space.name}"

      furnThickness = UnitConversions.convert(furnMass / (furnDensity * furnAreaFraction), 'ft', 'in')

      # Define materials
      mat_fm = Material.new(name = mat_obj_name_space, thick_in = furnThickness, mat_base = nil, k_in = furnConductivity, rho = furnDensity, cp = furnSpecHeat, tAbs = 0.9, sAbs = furnSolarAbsorptance, vAbs = 0.1)

      # Set paths
      path_fracs = [1]

      # Define construction
      constr = Construction.new(constr_obj_name_space, path_fracs)
      constr.add_layer(mat_fm)

      imdef = OpenStudio::Model::InternalMassDefinition.new(model)
      imdef.setName(mass_obj_name_space)
      imdef.setSurfaceArea(furnAreaFraction * space.floorArea)

      im = OpenStudio::Model::InternalMass.new(imdef)
      im.setName(mass_obj_name_space)
      im.setSpace(space)

      # Create and assign construction to surfaces
      if not constr.create_and_assign_constructions([imdef], runner, model)
        return false
      end

      runner.registerInfo("Assigned internal mass object '#{mass_obj_name_space}' to space '#{space.name}'.")
    end

    return true
  end
end

class Construction
  # Facilitates creating and assigning an OpenStudio construction (with accompanying
  # OpenStudio Materials) from Material objects. Handles parallel path calculations.

  def initialize(name, path_widths)
    @name = name
    @path_widths = path_widths
    @path_fracs = []
    @sum_path_fracs = @path_widths.inject(:+)
    path_widths.each do |path_width|
      @path_fracs << path_width / path_widths.inject { |sum, n| sum + n }
    end
    @layers_names = []
    @layers_materials = []
  end

  def add_layer(materials, name = nil)
    # materials: Either a Material object or a list of Material objects
    # include_in_construction: false if the layer that should not be included in the
    #                          resulting construction but is used to calculate the
    #                          effective R-value.
    # name: Name of the layer; required if multiple materials are provided. Otherwise the
    #       Material.name will be used.
    if not materials.kind_of?(Array)
      @layers_materials << [materials]
      if not name.nil?
        @layers_names << name
      else
        @layers_names << materials.name
      end
    else
      @layers_materials << materials
      if not name.nil?
        @layers_names << name
      else
        @layers_names << 'ParallelMaterial'
      end
    end
  end

  def assembly_rvalue(runner)
    # Calculate overall R-value for assembly
    if not validated?(runner)
      return
    end

    u_overall = 0
    @path_fracs.each_with_index do |path_frac, path_num|
      # For each parallel path, sum series:
      r_path = 0
      @layers_materials.each do |layer_materials|
        if layer_materials.size == 1
          # One material for this layer
          r_path += layer_materials[0].rvalue
        else
          # Multiple parallel materials for this layer, use appropriate one
          r_path += layer_materials[path_num].rvalue
        end
      end
      u_overall += 1.0 / r_path * path_frac
    end
    r_overall = 1.0 / u_overall
    return r_overall
  end

  def assembly_absorptance(runner)
    # Calculate absorptance values for assembly
    if not validated?(runner)
      return
    end

    tAbs, sAbs, vAbs = [0] * 3
    path_frac_tot = 0
    @path_fracs.each_with_index do |path_frac, path_num|
      # For each parallel path, sum series:
      @layers_materials.each do |layer_materials|
        if layer_materials.size == 1
          # One material for this layer
          next if layer_materials[0].name == Constants.AirFilm

          tAbs += path_frac * layer_materials[0].tAbs if not layer_materials[0].tAbs.nil?
          sAbs += path_frac * layer_materials[0].sAbs if not layer_materials[0].sAbs.nil?
          vAbs += path_frac * layer_materials[0].tAbs if not layer_materials[0].vAbs.nil?
          path_frac_tot += path_frac if not layer_materials[0].tAbs.nil?
          break # only use the exterior material
        else
          tAbs += path_frac * layer_materials[path_num].tAbs if not layer_materials[path_num].tAbs.nil?
          sAbs += path_frac * layer_materials[path_num].sAbs if not layer_materials[path_num].sAbs.nil?
          vAbs += path_frac * layer_materials[path_num].vAbs if not layer_materials[path_num].vAbs.nil?
          path_frac_tot += path_frac if not layer_materials[path_num].tAbs.nil?
          break # only use the exterior material
        end
      end
    end

    if path_frac_tot == 0
      return nil, nil, nil
    else

      return tAbs / path_frac_tot, sAbs / path_frac_tot, vAbs / path_frac_tot
    end
  end

  # Creates constructions as needed and assigns to surfaces.
  # Leave name as nil if the materials (e.g., exterior finish) apply to multiple constructions.
  def create_and_assign_constructions(surfaces, runner, model)
    if not validated?(runner)
      return false
    end

    # Create list of OpenStudio materials
    materials = construct_materials(model, runner)

    # Create OpenStudio construction and assign to surface
    constr = OpenStudio::Model::Construction.new(model)
    constr.setName(@name)
    constr.setLayers(materials)
    revconstr = nil

    printed_constr = false
    printed_revconstr = false

    # Assign constructions to surfaces
    surfaces.each do |surface|
      surface.setConstruction(constr)
      if not printed_constr
        print_construction_creation(runner, surface)
        printed_constr = true
      end
      print_construction_assignment(runner, surface)

      # Assign reverse construction to adjacent surface as needed
      next if surface.is_a?(OpenStudio::Model::SubSurface) || surface.is_a?(OpenStudio::Model::InternalMassDefinition) || (not surface.adjacentSurface.is_initialized)

      if revconstr.nil?
        revconstr = constr.reverseConstruction
      end
      adjacent_surface = surface.adjacentSurface.get
      adjacent_surface.setConstruction(revconstr)
      if not printed_revconstr
        print_construction_creation(runner, adjacent_surface)
        printed_revconstr = true
      end
      print_construction_assignment(runner, adjacent_surface)
    end
    return true
  end

  private

  def get_parallel_material(curr_layer_num, runner, name)
    # Returns a Material object with effective properties for the specified
    # parallel path layer of the construction.

    mat = Material.new(name)
    curr_layer_materials = @layers_materials[curr_layer_num]
    r_overall = assembly_rvalue(runner)
    tAbs, sAbs, vAbs = assembly_absorptance(runner)
    mat.tAbs, mat.sAbs, mat.vAbs = tAbs, sAbs, vAbs

    # Calculate individual R-values for each layer
    sum_r_all_layers = 0
    sum_r_parallel_layers = 0
    layer_rvalues = []
    @layers_materials.each do |layer_materials|
      u_path = 0
      layer_materials.each_with_index do |layer_material, idx|
        if layer_materials.size > 1
          u_path += @path_fracs[idx] / (layer_material.thick / layer_material.k)
        else
          u_path += 1.0 / (layer_material.thick / layer_material.k)
        end
      end
      r_path = 1.0 / u_path
      layer_rvalues << r_path
      sum_r_all_layers += r_path
      if layer_materials.size > 1
        sum_r_parallel_layers += r_path
      end
    end

    # Material R-value
    # Apportion R-value to the current parallel path layer
    mat.rvalue = layer_rvalues[curr_layer_num] + (r_overall - sum_r_all_layers) * layer_rvalues[curr_layer_num] / sum_r_parallel_layers

    # Material thickness and conductivity
    mat.thick_in = curr_layer_materials[0].thick_in # All paths have equal thickness
    mat.thick = curr_layer_materials[0].thick # All paths have equal thickness
    mat.k = mat.thick / mat.rvalue

    # Material density
    mat.rho = 0
    @path_fracs.each_with_index do |path_frac, path_num|
      mat.rho += curr_layer_materials[path_num].rho * path_frac
    end

    # Material specific heat
    mat.cp = 0
    @path_fracs.each_with_index do |path_frac, path_num|
      mat.cp += (curr_layer_materials[path_num].cp * curr_layer_materials[path_num].rho * path_frac) / mat.rho
    end

    return mat
  end

  def construct_materials(model, runner)
    # Create materials
    materials = []
    @layers_materials.each_with_index do |layer_materials, layer_num|
      if layer_materials.size == 1
        next if layer_materials[0].name == Constants.AirFilm # Do not include air films in construction

        mat = Construction.create_os_material(model, runner, layer_materials[0])
      else
        parallel_path_mat = get_parallel_material(layer_num, runner, @layers_names[layer_num])
        mat = Construction.create_os_material(model, runner, parallel_path_mat)
      end
      materials << mat
    end
    return materials
  end

  def validated?(runner)
    # Check that sum of path fracs equal 1
    if (@sum_path_fracs <= 0.999) || (@sum_path_fracs >= 1.001)
      runner.registerError("Invalid construction: Sum of path fractions (#{@sum_path_fracs}) is not 1.")
      return false
    end

    # Check that all path fractions are not negative
    @path_fracs.each do |path_frac|
      if path_frac < 0
        runner.registerError("Invalid construction: Path fraction (#{path_frac}) must be greater than or equal to 0.")
        return false
      end
    end

    # Check if all materials are GlazingMaterial
    all_glazing = true
    @layers_materials.each do |layer_materials|
      layer_materials.each do |mat|
        if not mat.is_a? GlazingMaterial
          all_glazing = false
        end
      end
    end
    if all_glazing
      # Check that no parallel materials
      @layers_materials.each do |layer_materials|
        if layer_materials.size > 1
          runner.registerError('Invalid construction: Cannot have multiple GlazingMaterials in a single layer.')
          return false
        end
      end
      return true
    end

    # Check for valid object types
    @layers_materials.each do |layer_materials|
      layer_materials.each do |mat|
        if (not mat.is_a? SimpleMaterial) && (not mat.is_a? Material)
          runner.registerError('Invalid construction: Materials must be instances of SimpleMaterial or Material classes.')
          return false
        end
      end
    end

    # Check if invalid number of materials in a layer
    @layers_materials.each do |layer_materials|
      if (layer_materials.size > 1) && (layer_materials.size < @path_fracs.size)
        runner.registerError('Invalid construction: Layer must either have one material or same number of materials as paths.')
        return false
      end
    end

    # Check if multiple materials in a given layer have differing thicknesses
    @layers_materials.each do |layer_materials|
      next unless layer_materials.size > 1

      thick_in = nil
      layer_materials.each do |mat|
        if thick_in.nil?
          thick_in = mat.thick_in
        elsif thick_in != mat.thick_in
          runner.registerError('Invalid construction: Materials in a layer have different thicknesses.')
          return false
        end
      end
    end

    # Check if multiple non-contiguous parallel layers
    found_parallel = false
    last_parallel = false
    @layers_materials.each do |layer_materials|
      if layer_materials.size > 1
        if not found_parallel
          found_parallel = true
        elsif not last_parallel
          runner.registerError('Invalid construction: Non-contiguous parallel layers found.')
          return false
        end
      end
      last_parallel = (layer_materials.size > 1)
    end

    # If we got this far, we're good
    return true
  end

  # Creates (or returns an existing) OpenStudio Material from our own Material object
  def self.create_os_material(model, runner, material)
    name = material.name
    tolerance = 0.0001
    if material.is_a? SimpleMaterial
      # Material already exists?
      model.getMasslessOpaqueMaterials.each do |mat|
        next if mat.roughness.downcase.to_s != 'rough'
        next if (mat.thermalResistance - UnitConversions.convert(material.rvalue, 'hr*ft^2*F/Btu', 'm^2*K/W')).abs > tolerance

        return mat
      end
      # New material
      mat = OpenStudio::Model::MasslessOpaqueMaterial.new(model)
      mat.setName(name)
      mat.setRoughness('Rough')
      mat.setThermalResistance(UnitConversions.convert(material.rvalue, 'hr*ft^2*F/Btu', 'm^2*K/W'))
    elsif material.is_a? GlazingMaterial
      # Material already exists?
      model.getSimpleGlazings.each do |mat|
        next if (mat.uFactor - UnitConversions.convert(material.ufactor, 'Btu/(hr*ft^2*F)', 'W/(m^2*K)')).abs > tolerance
        next if (mat.solarHeatGainCoefficient - material.shgc).abs > tolerance

        return mat
      end
      # New material
      mat = OpenStudio::Model::SimpleGlazing.new(model)
      mat.setName(name)
      mat.setUFactor(UnitConversions.convert(material.ufactor, 'Btu/(hr*ft^2*F)', 'W/(m^2*K)'))
      mat.setSolarHeatGainCoefficient(material.shgc)
    else
      # Material already exists?
      model.getStandardOpaqueMaterials.each do |mat|
        next if mat.roughness.downcase.to_s != 'rough'
        next if (mat.thickness - UnitConversions.convert(material.thick_in, 'in', 'm')).abs > tolerance
        next if (mat.conductivity - UnitConversions.convert(material.k, 'Btu/(hr*ft*R)', 'W/(m*K)')).abs > tolerance
        next if (mat.density - UnitConversions.convert(material.rho, 'lbm/ft^3', 'kg/m^3')).abs > tolerance
        next if (mat.specificHeat - UnitConversions.convert(material.cp, 'Btu/(lbm*R)', 'J/(kg*K)')).abs > tolerance
        next if (not material.tAbs.nil?) && ((mat.thermalAbsorptance - material.tAbs).abs > tolerance)
        next if (not material.sAbs.nil?) && ((mat.solarAbsorptance - material.sAbs).abs > tolerance)
        next if (not material.vAbs.nil?) && ((mat.visibleAbsorptance - material.vAbs).abs > tolerance)

        return mat
      end
      # New material
      mat = OpenStudio::Model::StandardOpaqueMaterial.new(model)
      mat.setName(name)
      mat.setRoughness('Rough')
      mat.setThickness(UnitConversions.convert(material.thick_in, 'in', 'm'))
      mat.setConductivity(UnitConversions.convert(material.k, 'Btu/(hr*ft*R)', 'W/(m*K)'))
      mat.setDensity(UnitConversions.convert(material.rho, 'lbm/ft^3', 'kg/m^3'))
      mat.setSpecificHeat(UnitConversions.convert(material.cp, 'Btu/(lbm*R)', 'J/(kg*K)'))
      if not material.tAbs.nil?
        mat.setThermalAbsorptance(material.tAbs)
      end
      if not material.sAbs.nil?
        mat.setSolarAbsorptance(material.sAbs)
      end
      if not material.vAbs.nil?
        mat.setVisibleAbsorptance(material.vAbs)
      end
    end
    runner.registerInfo("Material '#{mat.name}' was created.")
    return mat
  end

  def print_construction_creation(runner, surface)
    s = ''
    num_layers = surface.construction.get.to_LayeredConstruction.get.layers.size
    if num_layers > 1
      s = 's'
    end
    mats_s = ''
    surface.construction.get.to_LayeredConstruction.get.layers.each do |layer|
      mats_s += layer.name.to_s + ' | '
    end
    mats_s.chomp!(' | ')
    runner.registerInfo("Construction '#{surface.construction.get.name}' was created with #{num_layers} material#{s} (#{mats_s}).")
  end

  def print_construction_assignment(runner, surface)
    if surface.is_a? OpenStudio::Model::SubSurface
      type_s = 'SubSurface'
    elsif surface.is_a? OpenStudio::Model::InternalMassDefinition
      type_s = 'InternalMassDefinition'
    else
      type_s = 'Surface'
    end
    runner.registerInfo("#{type_s} '#{surface.name}' has been assigned construction '#{surface.construction.get.name}'.")
  end
end

class SurfaceTypes
  # Container class for identifying types of surfaces

  def self.get_walls(model, runner)
    surfaces = {
      Constants.SurfaceTypeWallExtInsFin => [],
      Constants.SurfaceTypeWallExtInsUnfin => [],
      Constants.SurfaceTypeWallExtUninsUnfin => [],
      Constants.SurfaceTypeWallIntFinUninsFin => [],
      Constants.SurfaceTypeWallIntUnfinUninsUnfin => [],
      Constants.SurfaceTypeWallIntFinInsUnfin => [],
      Constants.SurfaceTypeWallFndGrndFinB => [],
      Constants.SurfaceTypeWallFndGrndUnfinB => [],
      Constants.SurfaceTypeWallFndGrndCS => [],
    }

    model.getSpaces.each do |space|
      is_finished = Geometry.space_is_finished(space)

      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != 'wall'

        obc_is_exterior = (surface.outsideBoundaryCondition.downcase == 'outdoors')
        obc_is_foundation = (surface.outsideBoundaryCondition.downcase == 'foundation')
        obc_is_adiabatic = (surface.outsideBoundaryCondition.downcase == 'adiabatic')

        adjacent_space = nil
        if surface.adjacentSurface.is_initialized && surface.adjacentSurface.get.space.is_initialized
          adjacent_space = surface.adjacentSurface.get.space.get
        end
        obc_is_adjacent = (not adjacent_space.nil?)

        # Exterior insulated finished
        if is_finished && obc_is_exterior
          surfaces[Constants.SurfaceTypeWallExtInsFin] << surface

        # Exterior insulated unfinished
        elsif (not is_finished) && obc_is_exterior && Geometry.is_unfinished_attic(space) && (get_space_r_value(runner, space, 'roofceiling').to_f > 5)
          surfaces[Constants.SurfaceTypeWallExtInsUnfin] << surface

        # Exterior uninsulated unfinished
        elsif (not is_finished) && obc_is_exterior
          surfaces[Constants.SurfaceTypeWallExtUninsUnfin] << surface

        # Interior finished uninsulated finished (shared walls)
        elsif is_finished && obc_is_adjacent && Geometry.space_is_finished(adjacent_space)
          surfaces[Constants.SurfaceTypeWallIntFinUninsFin] << surface

        # Interior unfinished uninsulated unfinished
        elsif (not is_finished) && obc_is_adjacent && Geometry.space_is_unfinished(adjacent_space)
          surfaces[Constants.SurfaceTypeWallIntUnfinUninsUnfin] << surface

        # Interior finished insulated unfinished
        elsif is_finished && obc_is_adjacent && Geometry.space_is_unfinished(adjacent_space)
          surfaces[Constants.SurfaceTypeWallIntFinInsUnfin] << surface

        # Exterior finished basement
        elsif Geometry.is_finished_basement(space) && (obc_is_foundation || obc_is_adiabatic)
          surfaces[Constants.SurfaceTypeWallFndGrndFinB] << surface

        # Exterior unfinished basement
        elsif Geometry.is_unfinished_basement(space) && (obc_is_foundation || obc_is_adiabatic)
          surfaces[Constants.SurfaceTypeWallFndGrndUnfinB] << surface

        # Exterior crawlspace
        elsif Geometry.is_crawl(space) && (obc_is_foundation || obc_is_adiabatic)
          surfaces[Constants.SurfaceTypeWallFndGrndCS] << surface

        # Adiabatic finished
        elsif obc_is_adiabatic && is_finished
          surfaces[Constants.SurfaceTypeWallIntFinUninsFin] << surface

        # Adiabatic unfinished
        elsif obc_is_adiabatic && (not is_finished)
          surfaces[Constants.SurfaceTypeWallIntUnfinUninsUnfin] << surface

        end
      end
    end

    return surfaces
  end

  def self.get_roofs(model, runner)
    surfaces = {
      Constants.SurfaceTypeRoofFinInsExt => [],
      Constants.SurfaceTypeRoofUnfinInsExt => [],
      Constants.SurfaceTypeRoofUnfinUninsExt => [],
      Constants.SurfaceTypeRoofAdiabatic => [],
    }

    model.getSpaces.each do |space|
      is_finished = Geometry.space_is_finished(space)
      above_grade = Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != 'roofceiling'

        obc_is_exterior = (surface.outsideBoundaryCondition.downcase == 'outdoors')
        obc_is_adiabatic = (surface.outsideBoundaryCondition.downcase == 'adiabatic')

        adjacent_space = nil
        if surface.adjacentSurface.is_initialized && surface.adjacentSurface.get.space.is_initialized
          adjacent_space = surface.adjacentSurface.get.space.get
        end
        obc_is_adjacent = (not adjacent_space.nil?)

        # Exterior insulated finished
        if obc_is_exterior && is_finished && above_grade
          surfaces[Constants.SurfaceTypeRoofFinInsExt] << surface

        # Exterior insulated unfinished
        elsif obc_is_exterior && Geometry.is_unfinished_attic(space)
          surfaces[Constants.SurfaceTypeRoofUnfinInsExt] << surface

        # Exterior uninsulated unfinished
        elsif obc_is_exterior
          surfaces[Constants.SurfaceTypeRoofUnfinUninsExt] << surface

        elsif obc_is_adiabatic
          surfaces[Constants.SurfaceTypeRoofAdiabatic] << surface
        end
      end
    end

    return surfaces
  end

  def self.get_floors(model, runner)
    surfaces = {
      Constants.SurfaceTypeFloorFinInsUnfinAttic => [],
      Constants.SurfaceTypeFloorFinInsUnfin => [],
      Constants.SurfaceTypeFloorFinUninsFin => [],
      Constants.SurfaceTypeFloorUnfinUninsUnfin => [],
      Constants.SurfaceTypeFloorFndGrndFinB => [],
      Constants.SurfaceTypeFloorFndGrndUnfinB => [],
      Constants.SurfaceTypeFloorFndGrndCS => [],
      Constants.SurfaceTypeFloorFndGrndFinSlab => [],
      Constants.SurfaceTypeFloorFndGrndUnfinSlab => [],
      Constants.SurfaceTypeFloorUnfinBInsFin => [],
      Constants.SurfaceTypeFloorCSInsFin => [],
      Constants.SurfaceTypeFloorPBInsFin => [],
    }

    # Ceilings
    model.getSpaces.each do |space|
      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != 'roofceiling'

        obc_is_adiabatic = (surface.outsideBoundaryCondition.downcase == 'adiabatic')

        adjacent_space = nil
        if surface.adjacentSurface.is_initialized && surface.adjacentSurface.get.space.is_initialized
          adjacent_space = surface.adjacentSurface.get.space.get
        end
        obc_is_adjacent = (not adjacent_space.nil?)

        # Unfinished basement ceiling
        if Geometry.is_unfinished_basement(space) && (not adjacent_space.nil?) && Geometry.space_is_finished(adjacent_space)
          surfaces[Constants.SurfaceTypeFloorUnfinBInsFin] << surface

        # Crawlspace ceiling
        elsif Geometry.is_crawl(space) && (not adjacent_space.nil?) && Geometry.space_is_finished(adjacent_space)
          surfaces[Constants.SurfaceTypeFloorCSInsFin] << surface

        # Pier beam ceiling
        elsif Geometry.is_pier_beam(space) && (not adjacent_space.nil?) && Geometry.space_is_finished(adjacent_space)
          surfaces[Constants.SurfaceTypeFloorPBInsFin] << surface

        end
      end
    end

    ceiling_surface_names = []
    surfaces.each do |surface_type, surfaces|
      surfaces.each do |surface|
        ceiling_surface_names << surface.name.to_s
      end
    end

    building_type = Geometry.get_building_type(model)
    # Floors
    model.getSpaces.each do |space|
      is_finished = Geometry.space_is_finished(space)
      above_grade = Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != 'floor'

        obc_is_exterior = (surface.outsideBoundaryCondition.downcase == 'outdoors')
        obc_is_foundation = (surface.outsideBoundaryCondition.downcase == 'foundation')
        obc_is_adiabatic = (surface.outsideBoundaryCondition.downcase == 'adiabatic')

        adjacent_space = nil
        if surface.adjacentSurface.is_initialized && surface.adjacentSurface.get.space.is_initialized
          adjacent_space = surface.adjacentSurface.get.space.get
          next if ceiling_surface_names.include? surface.adjacentSurface.get.name.to_s
        end
        obc_is_adjacent = (not adjacent_space.nil?)

        # Unfinished attic floor
        if obc_is_adjacent && Geometry.is_unfinished_attic(space) && Geometry.space_is_finished(adjacent_space)
          surfaces[Constants.SurfaceTypeFloorFinInsUnfinAttic] << surface

        # Floor between finished spaces [SFD/SFA]
        elsif ((building_type == Constants.BuildingTypeSingleFamilyDetached) || (building_type == Constants.BuildingTypeSingleFamilyAttached)) && is_finished && obc_is_adjacent && Geometry.space_is_finished(adjacent_space)
          surfaces[Constants.SurfaceTypeFloorFinUninsFin] << surface

        # Floor between finished spaces [MF]
        elsif is_finished && obc_is_adiabatic
          surfaces[Constants.SurfaceTypeFloorFinUninsFin] << surface

        # Floor between unfinished spaces (eg, corridor floor)
        elsif (not is_finished) && (obc_is_adjacent && (not Geometry.space_is_finished(adjacent_space))) || (obc_is_adiabatic && (not Geometry.is_foundation(space)))
          surfaces[Constants.SurfaceTypeFloorUnfinUninsUnfin] << surface

        # Finished basement floor
        elsif Geometry.is_finished_basement(space) && (obc_is_foundation || obc_is_adiabatic)
          surfaces[Constants.SurfaceTypeFloorFndGrndFinB] << surface

        # Unfinished basement floor
        elsif Geometry.is_unfinished_basement(space) && (obc_is_foundation || obc_is_adiabatic)
          surfaces[Constants.SurfaceTypeFloorFndGrndUnfinB] << surface

        # Crawlspace floor
        elsif Geometry.is_crawl(space) && (obc_is_foundation || obc_is_adiabatic)
          surfaces[Constants.SurfaceTypeFloorFndGrndCS] << surface

        # Finished slab
        elsif above_grade && is_finished && (obc_is_foundation || obc_is_adiabatic)
          surfaces[Constants.SurfaceTypeFloorFndGrndFinSlab] << surface

        # Unfinished slab
        elsif above_grade && (not is_finished) && (obc_is_foundation || obc_is_adiabatic)
          surfaces[Constants.SurfaceTypeFloorFndGrndUnfinSlab] << surface

        # Interzonal floor
        elsif is_finished && (obc_is_exterior || (obc_is_adjacent && (not Geometry.space_is_finished(adjacent_space))))
          surfaces[Constants.SurfaceTypeFloorFinInsUnfin] << surface

        # Adiabatic finished floor
        elsif obc_is_adiabatic && is_finished
          surfaces[Constants.SurfaceTypeFloorFinUninsFin] << surface

        # Adiabatic unfinished floor
        elsif obc_is_adiabatic && (not is_finished)
          surfaces[Constants.SurfaceTypeFloorUnfinUninsUnfin] << surface

        end
      end
    end

    return surfaces
  end
end

private

def get_gap_factor(install_grade, framing_factor, cavity_r)
  if cavity_r <= 0
    return 0 # Gap factor only applies when there is cavity insulation
  elsif install_grade == 1
    return 0
  elsif install_grade == 2
    return 0.02 * (1 - framing_factor)
  elsif install_grade == 3
    return 0.05 * (1 - framing_factor)
  end

  return 0
end

def get_space_r_value(runner, space, surface_type, register_error = false)
  # Get area-weighted space r-value
  sum_surface_ua = 0.0
  total_area = 0.0
  space.surfaces.each do |surface|
    next if surface.surfaceType.downcase != surface_type

    surf_area = UnitConversions.convert(surface.netArea, 'm^2', 'ft^2')
    ufactor = get_surface_ufactor(runner, surface, surface_type, register_error)
    next if ufactor.nil?

    sum_surface_ua += surf_area * ufactor
    total_area += surf_area
  end
  return if sum_surface_ua == 0

  return total_area / sum_surface_ua
end

def get_surface_ufactor(runner, surface, surface_type, register_error = false)
  if surface_type.downcase.include?('window')
    simple_glazing = get_window_simple_glazing(runner, surface, register_error)
    return if simple_glazing.nil?

    return UnitConversions.convert(simple_glazing.uFactor, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
  else
    if not surface.construction.is_initialized
      if register_error
        runner.registerError("Construction not assigned to '#{surface.name}'.")
      end
      return
    end
    ufactor = UnitConversions.convert(surface.uFactor.get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
    if surface.class.method_defined?('adjacentSurface') && surface.adjacentSurface.is_initialized
      # Use average u-factor of adjacent surface, as OpenStudio returns
      # two different values for, e.g., floor vs adjacent roofceiling
      if not surface.adjacentSurface.get.construction.is_initialized
        if register_error
          runner.registerError("Construction not assigned to '#{surface.adjacentSurface.get.name}'.")
        end
        return
      end
      adjacent_ufactor = UnitConversions.convert(surface.adjacentSurface.get.uFactor.get, 'W/(m^2*K)', 'Btu/(hr*ft^2*F)')
      return (ufactor + adjacent_ufactor) / 2.0
    end
    return ufactor
  end
end

def get_window_simple_glazing(runner, surface, register_error = false)
  if not surface.construction.is_initialized
    if register_error
      runner.registerError("Construction not assigned to '#{surface.name}'.")
    end
    return
  end
  construction = surface.construction.get
  if not construction.to_LayeredConstruction.is_initialized
    runner.registerError("Expected LayeredConstruction for '#{surface.name}'.")
    return
  end
  window_layered_construction = construction.to_LayeredConstruction.get
  if not window_layered_construction.getLayer(0).to_SimpleGlazing.is_initialized
    runner.registerError("Expected SimpleGlazing for '#{surface.name}'.")
    return
  end
  simple_glazing = window_layered_construction.getLayer(0).to_SimpleGlazing.get
  return simple_glazing
end
