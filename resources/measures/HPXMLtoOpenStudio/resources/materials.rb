# frozen_string_literal: true

require_relative 'constants'
require_relative 'unit_conversions'

class Material
  # thick_in - Thickness [in]
  # mat_base - Material object that defines k, rho, and cp. Can be overridden with values for those arguments.
  # k_in - Conductivity [Btu-in/h-ft^2-F]
  # rho - Density [lb/ft^3]
  # cp - Specific heat [Btu/lb*F]
  # rvalue - R-value [h-ft^2-F/Btu]
  def initialize(name = nil, thick_in = nil, mat_base = nil, k_in = nil, rho = nil, cp = nil, tAbs = nil, sAbs = nil, vAbs = nil, rvalue = nil)
    @name = name

    if not thick_in.nil?
      @thick_in = thick_in # in
      @thick = UnitConversions.convert(thick_in, 'in', 'ft') # ft
    end

    if not mat_base.nil?
      @k_in = mat_base.k_in # Btu-in/h-ft^2-F
      if not mat_base.k_in.nil?
        @k = UnitConversions.convert(mat_base.k_in, 'in', 'ft') # Btu/h-ft-F
      else
        @k = nil
      end
      @rho = mat_base.rho
      @cp = mat_base.cp
      @tAbs = mat_base.tAbs
      @sAbs = mat_base.sAbs
      @vAbs = mat_base.vAbs
    else
      @k_in = nil
      @k = nil
      @rho = nil
      @cp = nil
      @tAbs = nil
      @sAbs = nil
      @vAbs = nil
    end

    # Override the base material if both are included
    if not k_in.nil?
      @k_in = k_in # Btu-in/h-ft^2-F
      @k = UnitConversions.convert(k_in, 'in', 'ft') # Btu/h-ft-F
    end
    if not rho.nil?
      @rho = rho # lb/ft^3
    end
    if not cp.nil?
      @cp = cp # Btu/lb*F
    end

    if not tAbs.nil?
      @tAbs = tAbs
    end
    if not sAbs.nil?
      @sAbs = sAbs
    end
    if not vAbs.nil?
      @vAbs = vAbs
    end

    # Calculate R-value
    if not rvalue.nil?
      @rvalue = rvalue # h-ft^2-F/Btu
    elsif (not @thick_in.nil?) && (not @k_in.nil?)
      if @k_in > 0
        @rvalue = @thick_in / @k_in # h-ft^2-F/Btu
      else
        @rvalue = @thick_in / 10000000.0 # h-ft^2-F/Btu
      end
    end
  end

  attr_accessor :name, :thick, :thick_in, :k, :k_in, :rho, :cp, :rvalue, :tAbs, :sAbs, :vAbs

  def self.AirCavityClosed(thick_in)
    rvalue = Gas.AirGapRvalue
    return new(name = nil, thick_in = thick_in, mat_base = nil, k_in = thick_in / rvalue, rho = Gas.Air.rho, cp = Gas.Air.cp)
  end

  def self.AirCavityOpen(thick_in)
    return new(name = nil, thick_in = thick_in, mat_base = nil, k_in = 10000000.0, rho = Gas.Air.rho, cp = Gas.Air.cp)
  end

  def self.AirFilmOutside
    rvalue = 0.197 # hr-ft-F/Btu
    return new(name = Constants.AirFilm, thick_in = 1.0, mat_base = nil, k_in = 1.0 / rvalue)
  end

  def self.AirFilmVertical
    rvalue = 0.68 # hr-ft-F/Btu (ASHRAE 2005, F25.2, Table 1)
    return new(name = Constants.AirFilm, thick_in = 1.0, mat_base = nil, k_in = 1.0 / rvalue)
  end

  def self.AirFilmFlatEnhanced
    rvalue = 0.61 # hr-ft-F/Btu (ASHRAE 2005, F25.2, Table 1)
    return new(name = Constants.AirFilm, thick_in = 1.0, mat_base = nil, k_in = 1.0 / rvalue)
  end

  def self.AirFilmFlatReduced
    rvalue = 0.92 # hr-ft-F/Btu (ASHRAE 2005, F25.2, Table 1)
    return new(name = Constants.AirFilm, thick_in = 1.0, mat_base = nil, k_in = 1.0 / rvalue)
  end

  def self.AirFilmFloorAverage
    # For floors between conditioned spaces where heat does not flow across
    # the floor; heat transfer is only important with regards to the thermal
    rvalue = (self.AirFilmFlatReduced.rvalue + self.AirFilmFlatEnhanced.rvalue) / 2.0 # hr-ft-F/Btu
    return new(name = Constants.AirFilm, thick_in = 1.0, mat_base = nil, k_in = 1.0 / rvalue)
  end

  def self.AirFilmFloorReduced
    # For floors above unconditioned basement spaces, where heat will
    # always flow down through the floor.
    rvalue = self.AirFilmFlatReduced.rvalue # hr-ft-F/Btu
    return new(name = Constants.AirFilm, thick_in = 1.0, mat_base = nil, k_in = 1.0 / rvalue)
  end

  def self.AirFilmSlopeEnhanced(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for non-reflective materials of
    # emissivity = 0.90.
    rvalue = 0.002 * Math::exp(0.0398 * roof_pitch) + 0.608 # hr-ft-F/Btu (evaluates to film_flat_enhanced at 0 degrees, 0.62 at 45 degrees, and film_vertical at 90 degrees)
    return new(name = Constants.AirFilm, thick_in = 1.0, mat_base = nil, k_in = 1.0 / rvalue)
  end

  def self.AirFilmSlopeReduced(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for non-reflective materials of
    # emissivity = 0.90.
    rvalue = 0.32 * Math::exp(-0.0154 * roof_pitch) + 0.6 # hr-ft-F/Btu (evaluates to film_flat_reduced at 0 degrees, 0.76 at 45 degrees, and film_vertical at 90 degrees)
    return new(name = Constants.AirFilm, thick_in = 1.0, mat_base = nil, k_in = 1.0 / rvalue)
  end

  def self.AirFilmSlopeEnhancedReflective(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for reflective materials of
    # emissivity = 0.05.
    rvalue = 0.00893 * Math::exp(0.0419 * roof_pitch) + 1.311 # hr-ft-F/Btu (evaluates to 1.32 at 0 degrees, 1.37 at 45 degrees, and 1.70 at 90 degrees)
    return new(name = Constants.AirFilm, thick_in = 1.0, mat_base = nil, k_in = 1.0 / rvalue)
  end

  def self.AirFilmSlopeReducedReflective(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for reflective materials of
    # emissivity = 0.05.
    rvalue = 2.999 * Math::exp(-0.0333 * roof_pitch) + 1.551 # hr-ft-F/Btu (evaluates to 4.55 at 0 degrees, 2.22 at 45 degrees, and 1.70 at 90 degrees)
    return new(name = Constants.AirFilm, thick_in = 1.0, mat_base = nil, k_in = 1.0 / rvalue)
  end

  def self.AirFilmRoof(roof_pitch)
    # Use weighted average between enhanced and reduced convection based on degree days.
    # hdd_frac = hdd65f / (hdd65f + cdd65f)
    # cdd_frac = cdd65f / (hdd65f + cdd65f)
    # return self.AirFilmSlopeEnhanced(roof_pitch).rvalue * hdd_frac + self.AirFilmSlopeReduced(roof_pitch).rvalue * cdd_frac # hr-ft-F/Btu
    # Simplification to not depend on weather
    rvalue = (self.AirFilmSlopeEnhanced(roof_pitch).rvalue + self.AirFilmSlopeReduced(roof_pitch).rvalue) / 2.0 # hr-ft-F/Btu
    return new(name = Constants.AirFilm, thick_in = 1.0, mat_base = nil, k_in = 1.0 / rvalue)
  end

  def self.AirFilmRoofRadiantBarrier(roof_pitch)
    # Use weighted average between enhanced and reduced convection based on degree days.
    # hdd_frac = hdd65f / (hdd65f + cdd65f)
    # cdd_frac = cdd65f / (hdd65f + cdd65f)
    # return self.AirFilmSlopeEnhancedReflective(roof_pitch).rvalue * hdd_frac + self.AirFilmSlopeReducedReflective(roof_pitch).rvalue * cdd_frac # hr-ft-F/Btu
    # Simplification to not depend on weather
    rvalue = (self.AirFilmSlopeEnhancedReflective(roof_pitch).rvalue + self.AirFilmSlopeReducedReflective(roof_pitch).rvalue) / 2.0 # hr-ft-F/Btu
    return new(name = Constants.AirFilm, thick_in = 1.0, mat_base = nil, k_in = 1.0 / rvalue)
  end

  def self.CoveringBare(floorFraction = 0.8, rvalue = 2.08)
    # Combined layer of, e.g., carpet and bare floor
    thickness = 0.5 # in
    return new(name = 'Floor Covering', thick_in = thickness, mat_base = nil, k_in = thickness / (rvalue * floorFraction), rho = 3.4, cp = 0.32, tAbs = 0.9, sAbs = 0.9)
  end

  def self.Concrete(thick_in)
    return new(name = "Concrete #{thick_in} in.", thick_in = thick_in, mat_base = BaseMaterial.Concrete, k_in = nil, rho = nil, cp = nil, tAbs = 0.9)
  end

  def self.ExtFinishStuccoMedDark
    return new(name = 'Stucco, Medium/Dark', thick_in = 1.0, mat_base = BaseMaterial.Stucco, k_in = nil, rho = nil, cp = nil, tAbs = 0.9, sAbs = 0.75, vAbs = 0.75)
  end

  def self.ExtFinishStuccoMedLight
    return new(name = 'Stucco, Medium/Light', thick_in = 1.0, mat_base = BaseMaterial.Stucco, k_in = nil, rho = nil, cp = nil, tAbs = 0.45, sAbs = 0.75, vAbs = 0.75)
  end

  def self.ExtFinishBrickLight
    return new(name = 'Brick, Light', thick_in = 4.0, mat_base = BaseMaterial.Brick, k_in = nil, rho = nil, cp = nil, tAbs = 0.93, sAbs = 0.55, vAbs = 0.55)
  end

  def self.ExtFinishBrickMedDark
    return new(name = 'Brick, Medium/Dark', thick_in = 4.0, mat_base = BaseMaterial.Brick, k_in = nil, rho = nil, cp = nil, tAbs = 0.96, sAbs = 0.88, vAbs = 0.88)
  end

  def self.ExtFinishWoodLight
    return new(name = 'Wood, Light', thick_in = 1.0, mat_base = nil, k_in = 0.71, rho = 34.0, cp = 0.28, tAbs = 0.82, sAbs = 0.3, vAbs = 0.3)
  end

  def self.ExtFinishWoodMedDark
    return new(name = 'Wood, Medium/Dark', thick_in = 1.0, mat_base = nil, k_in = 0.71, rho = 34.0, cp = 0.28, tAbs = 0.92, sAbs = 0.75, vAbs = 0.75)
  end

  def self.ExtFinishAluminumLight
    return new(name = 'Aluminum, Light', thick_in = 0.375, mat_base = BaseMaterial.Aluminum, k_in = nil, rho = nil, cp = nil, tAbs = 0.9, sAbs = 0.3, vAbs = 0.3)
  end

  def self.ExtFinishAluminumMedDark
    return new(name = 'Aluminum, Medium/Dark', thick_in = 0.375, mat_base = BaseMaterial.Aluminum, k_in = nil, rho = nil, cp = nil, tAbs = 0.94, sAbs = 0.75, vAbs = 0.75)
  end

  def self.ExtFinishVinylLight
    return new(name = 'Vinyl, Light', thick_in = 0.375, mat_base = BaseMaterial.Vinyl, k_in = nil, rho = nil, cp = nil, tAbs = 0.9, sAbs = 0.3, vAbs = 0.3)
  end

  def self.ExtFinishVinylMedDark
    return new(name = 'Vinyl, Medium/Dark', thick_in = 0.375, mat_base = BaseMaterial.Vinyl, k_in = nil, rho = nil, cp = nil, tAbs = 0.9, sAbs = 0.75, vAbs = 0.75)
  end

  def self.ExtFinishFiberCementLight
    return new(name = 'Fiber-Cement, Light', thick_in = 0.375, mat_base = nil, k_in = 1.79, rho = 21.7, cp = 0.24, tAbs = 0.9, sAbs = 0.3, vAbs = 0.3)
  end

  def self.ExtFinishFiberCementMedDark
    return new(name = 'Fiber-Cement, Medium/Dark', thick_in = 0.375, mat_base = nil, k_in = 1.79, rho = 21.7, cp = 0.24, tAbs = 0.9, sAbs = 0.75, vAbs = 0.75)
  end

  def self.ExtFinishConcrete
    cement_mat = self.ExtFinishFiberCementMedDark
    return new(name = 'Concrete', thick_in = 0.375, mat_base = BaseMaterial.Concrete, k_in = nil, rho = nil, cp = nil, tAbs = cement_mat.tAbs, sAbs = cement_mat.sAbs, vAbs = cement_mat.vAbs)
  end

  def self.ExtFinishShingleAsbestos
    shingle_mat = self.RoofingCompositionShingles
    return self.RoofMaterial('Asbestos Shingles', shingle_mat.tAbs, shingle_mat.sAbs)
  end

  def self.ExtFinishShingleComposition
    shingle_mat = self.RoofingCompositionShingles
    return self.RoofMaterial('Composition Shingles', shingle_mat.tAbs, shingle_mat.sAbs)
  end

  def self.ExtFinishNoneCMU
    cement_mat = self.ExtFinishFiberCementMedDark
    return new(name = 'None, CMU', thick_in = nil, mat_base = nil, k_in = nil, rho = nil, cp = nil, tAbs = cement_mat.tAbs, sAbs = cement_mat.sAbs, vAbs = cement_mat.vAbs)
  end

  def self.ExtFinishNoneBrick
    brick_mat = self.ExtFinishBrickMedDark
    return new(name = 'None, Brick', thick_in = nil, mat_base = nil, k_in = nil, rho = nil, cp = nil, tAbs = brick_mat.tAbs, sAbs = brick_mat.sAbs, vAbs = brick_mat.vAbs)
  end

  def self.FloorWood
    return Material.new(name = 'Wood Floor', thick_in = 0.625, mat_base = nil, k_in = 0.8004, rho = 34.0, cp = 0.29)
  end

  def self.GypsumWall(thick_in)
    return new(name = "Drywall #{thick_in} in.", thick_in = thick_in, mat_base = BaseMaterial.Gypsum, k_in = nil, rho = nil, cp = nil, tAbs = 0.9, sAbs = 0.5, vAbs = 0.1)
  end

  def self.GypsumCeiling(thick_in)
    return new(name = "Drywall #{thick_in} in.", thick_in = thick_in, mat_base = BaseMaterial.Gypsum, k_in = nil, rho = nil, cp = nil, tAbs = 0.9, sAbs = 0.3, vAbs = 0.1)
  end

  def self.RoofingAsphaltShinglesDark
    return self.RoofMaterial('Asphalt Shingles, Dark', 0.91, 0.92)
  end

  def self.RoofingAsphaltShinglesMed
    return self.RoofMaterial('Asphalt Shingles, Medium', 0.91, 0.85)
  end

  def self.RoofingAsphaltShinglesLight
    return self.RoofMaterial('Asphalt Shingles, Light', 0.91, 0.8)
  end

  def self.RoofingAsphaltShinglesWhiteCool
    return self.RoofMaterial('Asphalt Shingles, White or Cool Colors', 0.91, 0.75)
  end

  def self.RoofingTileDark
    return self.RoofMaterial('Tile, Dark', 0.94, 0.9)
  end

  def self.RoofingTileMed
    return self.RoofMaterial('Tile, Medium', 0.94, 0.75)
  end

  def self.RoofingTileLight
    return self.RoofMaterial('Tile, Light', 0.93, 0.6)
  end

  def self.RoofingTileWhite
    return self.RoofMaterial('Tile, White', 0.93, 0.3)
  end

  def self.RoofingMetalDark
    return self.RoofMaterial('Metal, Dark', 0.9, 0.9)
  end

  def self.RoofingMetalCool
    return self.RoofMaterial('Metal, Cool Colors', 0.85, 0.35)
  end

  def self.RoofingMetalMed
    return self.RoofMaterial('Metal, Medium', 0.9, 0.75)
  end

  def self.RoofingMetalLight
    return self.RoofMaterial('Metal, Light', 0.88, 0.6)
  end

  def self.RoofingMetalWhite
    return self.RoofMaterial('Metal, White', 0.88, 0.3)
  end

  def self.RoofingGalvanizedSteel
    return self.RoofMaterial('Galvanized Steel', 0.88, 0.7)
  end

  def self.RoofingTileClayorCeramic
    return self.RoofMaterial('Tile, Clay or Ceramic', 0.88, 0.8)
  end

  def self.RoofingTileClayorCeramicWhiteCool
    return self.RoofMaterial('Tile, Clay or Ceramic, White or Cool Colors', 0.88, 0.3)
  end

  def self.RoofingWoodShingles
    return self.RoofMaterial('Wood Shingles', 0.9, 0.78)
  end

  def self.RoofingCompositionShingles
    return self.RoofMaterial('Composition Shingles', 0.91, 0.85)
  end

  def self.RoofingCompositionShinglesWhiteCool
    return self.RoofMaterial('Composition Shingles, White or Cool Colors', 0.91, 0.75)
  end

  def self.RoofingTileConcrete
    return self.RoofMaterial('Tile, Concrete', 0.88, 0.89)
  end

  def self.RoofingTileConcreteWhiteCool
    return self.RoofMaterial('Tile, Concrete, White or Cool Colors', 0.88, 0.3)
  end

  def self.RoofingSlate
    return self.RoofMaterial('Slate', 0.75, 0.87)
  end

  def self.Soil(thick_in)
    return new(name = "Soil #{thick_in} in.", thick_in = thick_in, mat_base = BaseMaterial.Soil)
  end

  def self.Stud2x(thick_in)
    return new(name = "Stud 2x #{thick_in} in.", thick_in = thick_in, mat_base = BaseMaterial.Wood)
  end

  def self.Stud2x4
    return new(name = 'Stud 2x4', thick_in = 3.5, mat_base = BaseMaterial.Wood)
  end

  def self.Stud2x6
    return new(name = 'Stud 2x6', thick_in = 5.5, mat_base = BaseMaterial.Wood)
  end

  def self.Stud2x8
    return new(name = 'Stud 2x8', thick_in = 7.25, mat_base = BaseMaterial.Wood)
  end

  def self.Plywood(thick_in)
    return new(name = "Plywood #{thick_in} in.", thick_in = thick_in, mat_base = BaseMaterial.Wood)
  end

  def self.RadiantBarrier
    return new(name = 'Radiant Barrier', thick_in = 0.0084, mat_base = nil, k_in = 1629.6, rho = 168.6, cp = 0.22, tAbs = 0.05, sAbs = 0.05, vAbs = 0.05)
  end

  def self.RoofMaterial(name, emissivity, absorptivity)
    return new(name = name, thick_in = 0.375, mat_base = nil, k_in = 1.128, rho = 70, cp = 0.35, tAbs = emissivity, sAbs = absorptivity, vAbs = absorptivity)
  end
end

class BaseMaterial
  def initialize(rho, cp, k_in, tAbs = nil, sAbs = nil, vAbs = nil)
    @rho = rho
    @cp = cp
    @k_in = k_in
    @tAbs = tAbs
    @sAbs = sAbs
    @vAbs = vAbs
  end

  attr_accessor :rho, :cp, :k_in, :tAbs, :sAbs, :vAbs

  def self.Gypsum
    return new(rho = 50.0, cp = 0.2, k_in = 1.1112)
  end

  def self.Wood
    return new(rho = 32.0, cp = 0.29, k_in = 0.8004, tAbs = 0.82, sAbs = 0.3, vAbs = 0.3)
  end

  def self.Concrete
    return new(rho = 140.0, cp = 0.2, k_in = 12.5)
  end

  def self.Gypcrete
    # http://www.maxxon.com/gyp-crete/data
    return new(rho = 100.0, cp = 0.223, k_in = 4.7424)
  end

  def self.InsulationRigid
    return new(rho = 2.0, cp = 0.29, k_in = 0.204)
  end

  def self.InsulationCelluloseDensepack
    return new(rho = 3.5, cp = 0.25, k_in = nil)
  end

  def self.InsulationCelluloseLoosefill
    return new(rho = 1.5, cp = 0.25, k_in = nil)
  end

  def self.InsulationFiberglassDensepack
    return new(rho = 2.2, cp = 0.25, k_in = nil)
  end

  def self.InsulationFiberglassLoosefill
    return new(rho = 0.5, cp = 0.25, k_in = nil)
  end

  def self.InsulationGenericDensepack
    return new(rho = (self.InsulationFiberglassDensepack.rho + self.InsulationCelluloseDensepack.rho) / 2.0, cp = 0.25, k_in = nil)
  end

  def self.InsulationGenericLoosefill
    return new(rho = (self.InsulationFiberglassLoosefill.rho + self.InsulationCelluloseLoosefill.rho) / 2.0, cp = 0.25, k_in = nil)
  end

  def self.Soil
    return new(rho = 115.0, cp = 0.1, k_in = 12.0)
  end

  def self.Brick
    return new(rho = 110.0, cp = 0.19, k_in = 5.5)
  end

  def self.Vinyl
    return new(rho = 11.1, cp = 0.25, k_in = 0.62)
  end

  def self.Aluminum
    return new(rho = 10.9, cp = 0.29, k_in = 0.61)
  end

  def self.Stucco
    return new(rho = 80.0, cp = 0.21, k_in = 4.5)
  end

  def self.Stone
    return new(rho = 140.0, cp = 0.2, k_in = 12.5)
  end

  def self.StrawBale
    return new(rho = 11.1652, cp = 0.2991, k_in = 0.4164)
  end
end

class SimpleMaterial
  def initialize(name = nil, rvalue = nil)
    @name = name
    @rvalue = rvalue
  end

  attr_accessor :name, :rvalue

  def self.Adiabatic
    return new(name = 'Adiabatic', rvalue = 1000)
  end
end

class GlazingMaterial
  def initialize(name = nil, ufactor = nil, shgc = nil)
    @name = name
    @ufactor = ufactor
    @shgc = shgc
  end

  attr_accessor :name, :ufactor, :shgc
end

class Liquid
  def initialize(rho, cp, k, mu, h_fg, t_frz, t_boil, t_crit)
    @rho = rho # Density (lb/ft3)
    @cp     = cp        # Specific Heat (Btu/lbm-R)
    @k      = k         # Thermal Conductivity (Btu/h-ft-R)
    @mu     = mu        # Dynamic Viscosity (lbm/ft-h)
    @h_fg   = h_fg      # Latent Heat of Vaporization (Btu/lbm)
    @t_frz  = t_frz     # Freezing Temperature (degF)
    @t_boil = t_boil    # Boiling Temperature (degF)
    @t_crit = t_crit    # Critical Temperature (degF)
  end

  attr_accessor :rho, :cp, :k, :mu, :h_fg, :t_frz, :t_boil, :t_crit

  def self.H2O_l
    # From EES at STP
    return new(62.32, 0.9991, 0.3386, 2.424, 1055, 32.0, 212.0, nil)
  end

  def self.R22_l
    # Converted from EnthDR22 f77 in ResAC (Brandemuehl)
    return new(nil, 0.2732, nil, nil, 100.5, nil, -41.35, 204.9)
  end
end

class Gas
  def initialize(rho, cp, k, mu, m)
    @rho = rho # Density (lb/ft3)
    @cp     = cp            # Specific Heat (Btu/lbm-R)
    @k      = k             # Thermal Conductivity (Btu/h-ft-R)
    @mu     = mu            # Dynamic Viscosity (lbm/ft-h)
    @m      = m             # Molecular Weight (lbm/lbmol)
    if @m
      gas_constant = 1.9858 # Gas Constant (Btu/lbmol-R)
      @r = gas_constant / m # Gas Constant (Btu/lbm-R)
    else
      @r = nil
    end
  end

  attr_accessor :rho, :cp, :k, :mu, :m, :r

  def self.Air
    # From EES at STP
    return new(0.07518, 0.2399, 0.01452, 0.04415, 28.97)
  end

  def self.AirGapRvalue
    return 1.0 # hr*ft*F/Btu (Assume for all air gap configurations since there is no correction for direction of heat flow in the simulation tools)
  end

  def self.H2O_v
    # From EES at STP
    return new(nil, 0.4495, nil, nil, 18.02)
  end

  def self.R22_v
    # Converted from EnthDR22 f77 in ResAC (Brandemuehl)
    return new(nil, 0.1697, nil, nil, nil)
  end

  def self.PsychMassRat
    return self.H2O_v.m / self.Air.m
  end
end

class AirFilms
  def self.OutsideR
    return 0.197 # hr-ft-F/Btu
  end

  def self.VerticalR
    return 0.68 # hr-ft-F/Btu (ASHRAE 2005, F25.2, Table 1)
  end

  def self.FlatEnhancedR
    return 0.61 # hr-ft-F/Btu (ASHRAE 2005, F25.2, Table 1)
  end

  def self.FlatReducedR
    return 0.92 # hr-ft-F/Btu (ASHRAE 2005, F25.2, Table 1)
  end

  def self.FloorAverageR
    # For floors between conditioned spaces where heat does not flow across
    # the floor; heat transfer is only important with regards to the thermal
    return (self.FlatReducedR + self.FlatEnhancedR) / 2.0 # hr-ft-F/Btu
  end

  def self.FloorReducedR
    # For floors above unconditioned basement spaces, where heat will
    # always flow down through the floor.
    return self.FlatReducedR # hr-ft-F/Btu
  end

  def self.SlopeEnhancedR(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for non-reflective materials of
    # emissivity = 0.90.
    return 0.002 * Math::exp(0.0398 * roof_pitch) + 0.608 # hr-ft-F/Btu (evaluates to film_flat_enhanced at 0 degrees, 0.62 at 45 degrees, and film_vertical at 90 degrees)
  end

  def self.SlopeReducedR(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for non-reflective materials of
    # emissivity = 0.90.
    return 0.32 * Math::exp(-0.0154 * roof_pitch) + 0.6 # hr-ft-F/Btu (evaluates to film_flat_reduced at 0 degrees, 0.76 at 45 degrees, and film_vertical at 90 degrees)
  end

  def self.SlopeEnhancedReflectiveR(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for reflective materials of
    # emissivity = 0.05.
    return 0.00893 * Math::exp(0.0419 * roof_pitch) + 1.311 # hr-ft-F/Btu (evaluates to 1.32 at 0 degrees, 1.37 at 45 degrees, and 1.70 at 90 degrees)
  end

  def self.SlopeReducedReflectiveR(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for reflective materials of
    # emissivity = 0.05.
    return 2.999 * Math::exp(-0.0333 * roof_pitch) + 1.551 # hr-ft-F/Btu (evaluates to 4.55 at 0 degrees, 2.22 at 45 degrees, and 1.70 at 90 degrees)
  end

  def self.RoofR(roof_pitch)
    # Use weighted average between enhanced and reduced convection based on degree days.
    # hdd_frac = hdd65f / (hdd65f + cdd65f)
    # cdd_frac = cdd65f / (hdd65f + cdd65f)
    # return self.SlopeEnhancedR(roof_pitch) * hdd_frac + self.SlopeReducedR(roof_pitch) * cdd_frac # hr-ft-F/Btu
    # Simplification to not depend on weather
    return (self.SlopeEnhancedR(roof_pitch) + self.SlopeReducedR(roof_pitch)) / 2.0 # hr-ft-F/Btu
  end

  def self.RoofRadiantBarrierR(roof_pitch)
    # Use weighted average between enhanced and reduced convection based on degree days.
    # hdd_frac = hdd65f / (hdd65f + cdd65f)
    # cdd_frac = cdd65f / (hdd65f + cdd65f)
    # return self.SlopeEnhancedReflectiveR(roof_pitch) * hdd_frac + self.SlopeReducedReflectiveR(roof_pitch) * cdd_frac # hr-ft-F/Btu
    # Simplification to not depend on weather
    return (self.SlopeEnhancedReflectiveR(roof_pitch) + self.SlopeReducedReflectiveR(roof_pitch)) / 2.0 # hr-ft-F/Btu
  end
end
