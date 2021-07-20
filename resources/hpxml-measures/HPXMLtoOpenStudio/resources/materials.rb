# frozen_string_literal: true

class Material
  # name - Material name
  # thick_in - Thickness [in]
  # mat_base - Material object that defines k, rho, and cp. Can be overridden with values for those arguments.
  # k_in - Conductivity [Btu-in/h-ft^2-F]
  # rho - Density [lb/ft^3]
  # cp - Specific heat [Btu/lb*F]
  # tAbs - thermal absorptance (emittance); 0.9 is EnergyPlus default
  # sAbs - solar absorptance; 0.7 is EnergyPlus default
  def initialize(name: nil, thick_in: nil, mat_base: nil, k_in: nil, rho: nil, cp: nil, tAbs: 0.9, sAbs: 0.7)
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
    else
      @k_in = nil
      @k = nil
      @rho = nil
      @cp = nil
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

    @tAbs = tAbs
    @sAbs = sAbs

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

  attr_accessor :name, :thick, :thick_in, :k, :k_in, :rho, :cp, :rvalue, :tAbs, :sAbs

  def self.AirCavityClosed(thick_in)
    rvalue = 1.0 # hr*ft*F/Btu (Assume for all air gap configurations since there is no correction for direction of heat flow in the simulation tools)
    return new(thick_in: thick_in, k_in: thick_in / rvalue, rho: Gas.Air.rho, cp: Gas.Air.cp)
  end

  def self.AirCavityOpen(thick_in)
    return new(thick_in: thick_in, k_in: 10000000.0, rho: Gas.Air.rho, cp: Gas.Air.cp)
  end

  def self.AirFilm(rvalue)
    return new(name: Constants.AirFilm, thick_in: 1.0, k_in: 1.0 / rvalue)
  end

  def self.AirFilmOutside
    rvalue = 0.197 # hr-ft-F/Btu
    return self.AirFilm(rvalue)
  end

  def self.AirFilmOutsideASHRAE140
    return self.AirFilm(0.174)
  end

  def self.AirFilmVertical
    rvalue = 0.68 # hr-ft-F/Btu (ASHRAE 2005, F25.2, Table 1)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmVerticalASHRAE140
    return self.AirFilm(0.685)
  end

  def self.AirFilmFlatEnhanced
    rvalue = 0.61 # hr-ft-F/Btu (ASHRAE 2005, F25.2, Table 1)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmFlatReduced
    rvalue = 0.92 # hr-ft-F/Btu (ASHRAE 2005, F25.2, Table 1)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmFloorAverage
    # For floors between conditioned spaces where heat does not flow across
    # the floor; heat transfer is only important with regards to the thermal
    rvalue = (self.AirFilmFlatReduced.rvalue + self.AirFilmFlatEnhanced.rvalue) / 2.0 # hr-ft-F/Btu
    return self.AirFilm(rvalue)
  end

  def self.AirFilmFloorReduced
    # For floors above unconditioned basement spaces, where heat will
    # always flow down through the floor.
    rvalue = self.AirFilmFlatReduced.rvalue # hr-ft-F/Btu
    return self.AirFilm(rvalue)
  end

  def self.AirFilmFloorASHRAE140
    return self.AirFilm(0.765)
  end

  def self.AirFilmFloorZeroWindASHRAE140
    return self.AirFilm(0.455)
  end

  def self.AirFilmSlopeEnhanced(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for non-reflective materials of
    # emissivity = 0.90.
    rvalue = 0.002 * Math::exp(0.0398 * roof_pitch) + 0.608 # hr-ft-F/Btu (evaluates to film_flat_enhanced at 0 degrees, 0.62 at 45 degrees, and film_vertical at 90 degrees)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmSlopeReduced(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for non-reflective materials of
    # emissivity = 0.90.
    rvalue = 0.32 * Math::exp(-0.0154 * roof_pitch) + 0.6 # hr-ft-F/Btu (evaluates to film_flat_reduced at 0 degrees, 0.76 at 45 degrees, and film_vertical at 90 degrees)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmSlopeEnhancedReflective(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for reflective materials of
    # emissivity = 0.05.
    rvalue = 0.00893 * Math::exp(0.0419 * roof_pitch) + 1.311 # hr-ft-F/Btu (evaluates to 1.32 at 0 degrees, 1.37 at 45 degrees, and 1.70 at 90 degrees)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmSlopeReducedReflective(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for reflective materials of
    # emissivity = 0.05.
    rvalue = 2.999 * Math::exp(-0.0333 * roof_pitch) + 1.551 # hr-ft-F/Btu (evaluates to 4.55 at 0 degrees, 2.22 at 45 degrees, and 1.70 at 90 degrees)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmRoof(roof_pitch)
    # Use weighted average between enhanced and reduced convection based on degree days.
    # hdd_frac = hdd65f / (hdd65f + cdd65f)
    # cdd_frac = cdd65f / (hdd65f + cdd65f)
    # return self.AirFilmSlopeEnhanced(roof_pitch).rvalue * hdd_frac + self.AirFilmSlopeReduced(roof_pitch).rvalue * cdd_frac # hr-ft-F/Btu
    # Simplification to not depend on weather
    rvalue = (self.AirFilmSlopeEnhanced(roof_pitch).rvalue + self.AirFilmSlopeReduced(roof_pitch).rvalue) / 2.0 # hr-ft-F/Btu
    return self.AirFilm(rvalue)
  end

  def self.AirFilmRoofRadiantBarrier(roof_pitch)
    # Use weighted average between enhanced and reduced convection based on degree days.
    # hdd_frac = hdd65f / (hdd65f + cdd65f)
    # cdd_frac = cdd65f / (hdd65f + cdd65f)
    # return self.AirFilmSlopeEnhancedReflective(roof_pitch).rvalue * hdd_frac + self.AirFilmSlopeReducedReflective(roof_pitch).rvalue * cdd_frac # hr-ft-F/Btu
    # Simplification to not depend on weather
    rvalue = (self.AirFilmSlopeEnhancedReflective(roof_pitch).rvalue + self.AirFilmSlopeReducedReflective(roof_pitch).rvalue) / 2.0 # hr-ft-F/Btu
    return self.AirFilm(rvalue)
  end

  def self.AirFilmRoofASHRAE140
    return self.AirFilm(0.752)
  end

  def self.CoveringBare(floorFraction = 0.8, rvalue = 2.08)
    # Combined layer of, e.g., carpet and bare floor
    thick_in = 0.5 # in
    return new(name: 'floor covering', thick_in: thick_in, k_in: thick_in / (rvalue * floorFraction), rho: 3.4, cp: 0.32, tAbs: 0.9, sAbs: 0.9)
  end

  def self.Concrete(thick_in)
    return new(name: "concrete #{thick_in} in.", thick_in: thick_in, mat_base: BaseMaterial.Concrete, tAbs: 0.9)
  end

  def self.ExteriorFinishMaterial(type, thick_in = nil)
    if (type == HPXML::SidingTypeNone) || (!thick_in.nil? && thick_in <= 0)
      return
    elsif [HPXML::SidingTypeAsbestos].include? type
      thick_in = 0.25 if thick_in.nil?
      return new(name: type, thick_in: thick_in, k_in: 4.20, rho: 118.6, cp: 0.24)
    elsif [HPXML::SidingTypeBrick].include? type
      thick_in = 4.0 if thick_in.nil?
      return new(name: type, thick_in: thick_in, mat_base: BaseMaterial.Brick)
    elsif [HPXML::SidingTypeCompositeShingle].include? type
      thick_in = 0.25 if thick_in.nil?
      return new(name: type, thick_in: thick_in, k_in: 1.128, rho: 70.0, cp: 0.35)
    elsif [HPXML::SidingTypeFiberCement].include? type
      thick_in = 0.375 if thick_in.nil?
      return new(name: type, thick_in: thick_in, k_in: 1.79, rho: 21.7, cp: 0.24)
    elsif [HPXML::SidingTypeMasonite].include? type # Masonite hardboard
      thick_in = 0.5 if thick_in.nil?
      return new(name: type, thick_in: thick_in, k_in: 0.69, rho: 46.8, cp: 0.39)
    elsif [HPXML::SidingTypeStucco].include? type
      thick_in = 1.0 if thick_in.nil?
      return new(name: type, thick_in: thick_in, mat_base: BaseMaterial.Stucco)
    elsif [HPXML::SidingTypeSyntheticStucco].include? type # EIFS
      thick_in = 1.0 if thick_in.nil?
      return new(name: type, thick_in: thick_in, mat_base: BaseMaterial.InsulationRigid)
    elsif [HPXML::SidingTypeVinyl, HPXML::SidingTypeAluminum].include? type
      thick_in = 0.375 if thick_in.nil?
      return new(name: type, thick_in: thick_in, mat_base: BaseMaterial.Vinyl)
    elsif [HPXML::SidingTypeWood].include? type
      thick_in = 1.0 if thick_in.nil?
      return new(name: type, thick_in: thick_in, k_in: 0.71, rho: 34.0, cp: 0.28)
    end

    fail "Unexpected type: #{type}."
  end

  def self.InteriorFinishMaterial(type, thick_in = nil)
    if (type == HPXML::InteriorFinishNone) || (!thick_in.nil? && thick_in <= 0)
      return
    else
      thick_in = 0.5 if thick_in.nil?
      if [HPXML::InteriorFinishGypsumBoard,
          HPXML::InteriorFinishGypsumCompositeBoard,
          HPXML::InteriorFinishPlaster].include? type
        return new(name: type, thick_in: thick_in, mat_base: BaseMaterial.Gypsum)
      elsif [HPXML::InteriorFinishWood].include? type
        return new(name: type, thick_in: thick_in, mat_base: BaseMaterial.Wood)
      end
    end

    fail "Unexpected type: #{type}."
  end

  def self.Soil(thick_in)
    return new(name: "soil #{thick_in} in.", thick_in: thick_in, mat_base: BaseMaterial.Soil)
  end

  def self.Stud2x(thick_in)
    return new(name: "stud 2x #{thick_in} in.", thick_in: thick_in, mat_base: BaseMaterial.Wood)
  end

  def self.Stud2x4
    return new(name: 'stud 2x4', thick_in: 3.5, mat_base: BaseMaterial.Wood)
  end

  def self.Stud2x6
    return new(name: 'stud 2x6', thick_in: 5.5, mat_base: BaseMaterial.Wood)
  end

  def self.Stud2x8
    return new(name: 'stud 2x8', thick_in: 7.25, mat_base: BaseMaterial.Wood)
  end

  def self.OSBSheathing(thick_in)
    return new(name: "osb sheathing #{thick_in} in.", thick_in: thick_in, mat_base: BaseMaterial.Wood)
  end

  def self.RadiantBarrier(grade)
    # FUTURE: Merge w/ Constructions.get_gap_factor
    if grade == 1
      gap_frac = 0.0
    elsif grade == 2
      gap_frac = 0.02
    elsif grade == 3
      gap_frac = 0.05
    end
    rb_emittance = 0.05
    non_rb_emittance = 0.90
    emittance = rb_emittance * (1.0 - gap_frac) + non_rb_emittance * gap_frac
    return new(name: 'radiant barrier', thick_in: 0.0084, k_in: 1629.6, rho: 168.6, cp: 0.22, tAbs: emittance, sAbs: 0.05)
  end

  def self.RoofMaterial(type, thick_in = nil)
    if [HPXML::RoofTypeMetal].include? type
      thick_in = 0.02 if thick_in.nil?
      return new(name: type, thick_in: thick_in, k_in: 346.9, rho: 487.0, cp: 0.11)
    elsif [HPXML::RoofTypeAsphaltShingles, HPXML::RoofTypeWoodShingles, HPXML::RoofTypeShingles, HPXML::RoofTypeCool].include? type
      thick_in = 0.25 if thick_in.nil?
      return new(name: type, thick_in: thick_in, k_in: 1.128, rho: 70.0, cp: 0.35)
    elsif [HPXML::RoofTypeConcrete].include? type
      thick_in = 0.75 if thick_in.nil?
      return new(name: type, thick_in: thick_in, k_in: 7.63, rho: 131.1, cp: 0.199)
    elsif [HPXML::RoofTypeClayTile].include? type
      thick_in = 0.75 if thick_in.nil?
      return new(name: type, thick_in: thick_in, k_in: 5.83, rho: 118.6, cp: 0.191)
    elsif [HPXML::RoofTypeEPS].include? type
      thick_in = 1.0 if thick_in.nil?
      return new(name: type, thick_in: thick_in, mat_base: BaseMaterial.InsulationRigid)
    elsif [HPXML::RoofTypePlasticRubber].include? type
      thick_in = 0.25 if thick_in.nil?
      return new(name: type, thick_in: thick_in, k_in: 2.78, rho: 110.8, cp: 0.36)
    end

    fail "Unexpected type: #{type}."
  end
end

class BaseMaterial
  def initialize(rho:, cp:, k_in: nil)
    @rho = rho
    @cp = cp
    @k_in = k_in
  end

  attr_accessor :rho, :cp, :k_in

  def self.Gypsum
    return new(rho: 50.0, cp: 0.2, k_in: 1.1112)
  end

  def self.Wood
    return new(rho: 32.0, cp: 0.29, k_in: 0.8004)
  end

  def self.Concrete
    return new(rho: 140.0, cp: 0.2, k_in: 12.5)
  end

  def self.Gypcrete
    # http://www.maxxon.com/gyp-crete/data
    return new(rho: 100.0, cp: 0.223, k_in: 4.7424)
  end

  def self.InsulationRigid
    return new(rho: 2.0, cp: 0.29, k_in: 0.204)
  end

  def self.InsulationCelluloseDensepack
    return new(rho: 3.5, cp: 0.25)
  end

  def self.InsulationCelluloseLoosefill
    return new(rho: 1.5, cp: 0.25)
  end

  def self.InsulationFiberglassDensepack
    return new(rho: 2.2, cp: 0.25)
  end

  def self.InsulationFiberglassLoosefill
    return new(rho: 0.5, cp: 0.25)
  end

  def self.InsulationGenericDensepack
    return new(rho: (self.InsulationFiberglassDensepack.rho + self.InsulationCelluloseDensepack.rho) / 2.0, cp: 0.25)
  end

  def self.InsulationGenericLoosefill
    return new(rho: (self.InsulationFiberglassLoosefill.rho + self.InsulationCelluloseLoosefill.rho) / 2.0, cp: 0.25)
  end

  def self.Soil
    return new(rho: 115.0, cp: 0.1, k_in: 12.0)
  end

  def self.Brick
    return new(rho: 110.0, cp: 0.19, k_in: 5.5)
  end

  def self.Vinyl
    return new(rho: 11.1, cp: 0.25, k_in: 0.62)
  end

  def self.Stucco
    return new(rho: 80.0, cp: 0.21, k_in: 4.5)
  end

  def self.Stone
    return new(rho: 140.0, cp: 0.2, k_in: 12.5)
  end

  def self.StrawBale
    return new(rho: 11.1652, cp: 0.2991, k_in: 0.4164)
  end
end

class GlazingMaterial
  def initialize(name:, ufactor:, shgc:)
    @name = name
    @ufactor = ufactor
    @shgc = shgc
  end

  attr_accessor :name, :ufactor, :shgc
end

class Liquid
  def initialize(rho: nil, cp: nil, k: nil, h_fg: nil, t_frz: nil)
    @rho = rho          # Density (lb/ft3)
    @cp = cp            # Specific Heat (Btu/lbm-R)
    @k = k              # Thermal Conductivity (Btu/h-ft-R)
    @h_fg = h_fg        # Latent Heat of Vaporization (Btu/lbm)
    @t_frz = t_frz      # Freezing Temperature (degF)
  end

  attr_accessor :rho, :cp, :k, :mu, :h_fg, :t_frz

  def self.H2O_l
    # From EES at STP
    return new(rho: 62.32, cp: 0.9991, k: 0.3386, h_fg: 1055, t_frz: 32.0)
  end

  def self.R22_l
    # Converted from EnthDR22 f77 in ResAC (Brandemuehl)
    return new(cp: 0.2732, h_fg: 100.5)
  end
end

class Gas
  def initialize(rho: nil, cp: nil, k: nil, m: nil)
    @rho = rho # Density (lb/ft3)
    @cp = cp   # Specific Heat (Btu/lbm-R)
    @k = k     # Thermal Conductivity (Btu/h-ft-R)
    @m = m     # Molecular Weight (lbm/lbmol)
    if @m
      gas_constant = 1.9858 # Gas Constant (Btu/lbmol-R)
      @r = gas_constant / m # Gas Constant (Btu/lbm-R)
    else
      @r = nil
    end
  end

  attr_accessor :rho, :cp, :k, :m, :r

  def self.Air
    # From EES at STP
    return new(rho: 0.07518, cp: 0.2399, k: 0.01452, m: 28.97)
  end

  def self.H2O_v
    # From EES at STP
    return new(cp: 0.4495, m: 18.02)
  end

  def self.R22_v
    # Converted from EnthDR22 f77 in ResAC (Brandemuehl)
    return new(cp: 0.1697)
  end

  def self.PsychMassRat
    return self.H2O_v.m / self.Air.m
  end
end
