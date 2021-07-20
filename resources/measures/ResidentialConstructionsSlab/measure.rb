# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'util')
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'constructions')

# start the measure
class ProcessConstructionsSlab < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Slab Construction'
  end

  def description
    return "This measure assigns a construction to slabs.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Calculates and assigns material layer properties of slab constructions of finished spaces. Any existing constructions for these surfaces will be removed.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a double argument for slab perimeter insulation R-value
    perimeter_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('perimeter_r', true)
    perimeter_r.setDisplayName('Perimeter Insulation Nominal R-value')
    perimeter_r.setUnits('hr-ft^2-R/Btu')
    perimeter_r.setDescription('Perimeter insulation is placed horizontally below the perimeter of the slab.')
    perimeter_r.setDefaultValue(0.0)
    args << perimeter_r

    # make a double argument for slab perimeter insulation width
    perimeter_width = OpenStudio::Measure::OSArgument::makeDoubleArgument('perimeter_width', true)
    perimeter_width.setDisplayName('Perimeter Insulation Width')
    perimeter_width.setUnits('ft')
    perimeter_width.setDescription('The distance from the perimeter of the house where the perimeter insulation ends.')
    perimeter_width.setDefaultValue(0.0)
    args << perimeter_width

    # make a double argument for whole slab insulation R-value
    whole_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('whole_r', true)
    whole_r.setDisplayName('Whole Slab Insulation Nominal R-value')
    whole_r.setUnits('hr-ft^2-R/Btu')
    whole_r.setDescription('Whole slab insulation is placed horizontally below the entire slab.')
    whole_r.setDefaultValue(0.0)
    args << whole_r

    # make a double argument for slab gap R-value
    gap_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('gap_r', true)
    gap_r.setDisplayName('Gap Insulation Nominal R-value')
    gap_r.setUnits('hr-ft^2-R/Btu')
    gap_r.setDescription('Gap insulation is placed vertically between the edge of the slab and the foundation wall.')
    gap_r.setDefaultValue(0.0)
    args << gap_r

    # make a double argument for slab exterior insulation R-value
    exterior_r = OpenStudio::Measure::OSArgument::makeDoubleArgument('exterior_r', true)
    exterior_r.setDisplayName('Exterior Insulation Nominal R-value')
    exterior_r.setUnits('hr-ft^2-R/Btu')
    exterior_r.setDescription('Exterior insulation is placed vertically on the exterior of the foundation wall.')
    exterior_r.setDefaultValue(0.0)
    args << exterior_r

    # make a double argument for slab exterior insulation depth
    exterior_depth = OpenStudio::Measure::OSArgument::makeDoubleArgument('exterior_depth', true)
    exterior_depth.setDisplayName('Exterior Insulation Depth')
    exterior_depth.setUnits('ft')
    exterior_depth.setDescription('The depth of the exterior foundation insulation.')
    exterior_depth.setDefaultValue(0.0)
    args << exterior_depth

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    floors_by_type = SurfaceTypes.get_floors(model, runner)

    # Get Inputs
    perimeter_r = runner.getDoubleArgumentValue('perimeter_r', user_arguments)
    perimeter_width = runner.getDoubleArgumentValue('perimeter_width', user_arguments)
    whole_r = runner.getDoubleArgumentValue('whole_r', user_arguments)
    gap_r = runner.getDoubleArgumentValue('gap_r', user_arguments)
    exterior_r = runner.getDoubleArgumentValue('exterior_r', user_arguments)
    exterior_depth = runner.getDoubleArgumentValue('exterior_depth', user_arguments)

    # Apply constructions
    floors_by_type[Constants.SurfaceTypeFloorFndGrndFinSlab].each do |floor_surface|
      if not FoundationConstructions.apply_slab(runner, model,
                                                floor_surface,
                                                Constants.SurfaceTypeFloorFndGrndFinSlab,
                                                perimeter_r, perimeter_width, gap_r,
                                                exterior_r, exterior_depth, whole_r, 4.0,
                                                Material.CoveringBare, false, nil, nil)
        return false
      end
    end

    floors_by_type[Constants.SurfaceTypeFloorFndGrndUnfinSlab].each do |surface|
      if not FoundationConstructions.apply_slab(runner, model,
                                                surface,
                                                Constants.SurfaceTypeFloorFndGrndUnfinSlab,
                                                0, 0, 0, 0, 0, 0, 4.0, nil, false, nil, nil)
        return false
      end
    end

    # FIXME: Remove soon
    # Store info for HVAC Sizing measure
    # ==================================

    # Get geometry values
    surfaces = floors_by_type[Constants.SurfaceTypeFloorFndGrndFinSlab]
    space_surfaces = []
    living_space = nil
    surfaces.each do |surface|
      next if not Geometry.is_living(surface.space.get)

      living_space = surface.space.get
      break
    end

    surfaces.each do |surface|
      if surface.space.get == living_space
        space_surfaces << surface
      end
    end

    # Calculate slab area based on one unit
    slabArea = Geometry.calculate_total_area_from_surfaces(space_surfaces)

    # Define materials
    slabCarpetPerimeterConduction, slabBarePerimeterConduction = SlabPerimeterConductancesByType(perimeter_r, gap_r, perimeter_width, exterior_r, whole_r, exterior_depth)
    carpetFloorFraction = Material.CoveringBare.rvalue / Material.CoveringBare(floorFraction = 1.0).rvalue
    slab_perimeter_conduction = slabCarpetPerimeterConduction * carpetFloorFraction + slabBarePerimeterConduction * (1 - carpetFloorFraction)

    surfaces.each do |surface|
      slabExtPerimeter = Geometry.calculate_exposed_perimeter(model, [surface], false)
      if slabExtPerimeter > 0
        effective_slab_Rvalue = slabArea / (slabExtPerimeter * slab_perimeter_conduction)
      else
        effective_slab_Rvalue = 1000.0 # hr*ft^2*F/Btu
      end

      surface.additionalProperties.setFeature(Constants.SizingInfoSlabRvalue, effective_slab_Rvalue)
    end

    # ==================================

    # Remove any constructions/materials that aren't used
    HelperMethods.remove_unused_constructions_and_materials(model, runner)

    return true
  end # end the run method

  def SlabPerimeterConductancesByType(perimeter_r, gap_r, perimeter_width, exterior_r, whole_r, exterior_depth)
    slabWidth = 28 # Width (shorter dimension) of slab, feet, to match Winkelmann analysis.
    slabLength = 55 # Longer dimension of slab, feet, to match Winkelmann analysis.
    soilConductivity = 1
    if perimeter_r > 0
      slabCarpetPerimeterConduction = PerimeterSlabInsulation(perimeter_r, gap_r, perimeter_width, slabWidth, slabLength, 1, soilConductivity)
      slabBarePerimeterConduction = PerimeterSlabInsulation(perimeter_r, gap_r, perimeter_width, slabWidth, slabLength, 0, soilConductivity)
    elsif exterior_r > 0
      slabCarpetPerimeterConduction = ExteriorSlabInsulation(exterior_depth, exterior_r, 1)
      slabBarePerimeterConduction = ExteriorSlabInsulation(exterior_depth, exterior_r, 0)
    elsif whole_r > 0
      slabCarpetPerimeterConduction = FullSlabInsulation(whole_r, gap_r, slabWidth, slabLength, 1, soilConductivity)
      slabBarePerimeterConduction = FullSlabInsulation(whole_r, gap_r, slabWidth, slabLength, 0, soilConductivity)
    else
      slabCarpetPerimeterConduction = FullSlabInsulation(0, 0, slabWidth, slabLength, 1, soilConductivity)
      slabBarePerimeterConduction = FullSlabInsulation(0, 0, slabWidth, slabLength, 0, soilConductivity)
    end

    return slabCarpetPerimeterConduction, slabBarePerimeterConduction
  end

  def PerimeterSlabInsulation(rperim, rgap, wperim, slabWidth, slabLength, carpet, k)
    # Coded by Dennis Barley, April 2013.
    # This routine calculates the perimeter conductance for a slab with insulation
    #   under the slab perimeter as well as gap insulation around the edge.
    #   The algorithm is based on a correlation to a set of related, fully insulated
    #   and uninsulated slab (sections), using the FullSlabInsulation function above.
    # Parameters:
    #   Rperim     = R-factor of insulation placed horizontally under the slab perimeter, h*ft2*F/Btu
    #   Rgap       = R-factor of insulation placed vertically between edge of slab & foundation wall, h*ft2*F/Btu
    #   Wperim     = Width of the perimeter insulation, ft.  Must be > 0.
    #   SlabWidth  = width (shorter dimension) of the slab, ft
    #   SlabLength = longer dimension of the slab, ft
    #   Carpet     = 1 if carpeted, 0 if not carpeted
    #   k          = thermal conductivity of the soil, Btu/h*ft*F
    # Constants:
    k2 = 0.329201  # 1st curve fit coefficient
    p = -0.327734  # 2nd curve fit coefficient
    q = 1.158418  # 3rd curve fit coefficient
    r = 0.144171  # 4th curve fit coefficient
    # Per Dennis email on 1/30/2015, a width = 0 appears to be some sort of singular point in the algorithm,
    # which is based on subtracting whole-slab models and curve-fitting the interactions to match Winkelmann
    # results.... So a recommended simple fix would be to set a minimum value of 1 foot (or maybe 2 feet)
    # for the width of perimeter insulation.
    wperimeter = [wperim, 1].max
    # Related, fully insulated slabs:
    b = FullSlabInsulation(rperim, rgap, 2 * wperimeter, slabLength, carpet, k)
    c = FullSlabInsulation(0, 0, slabWidth, slabLength, carpet, k)
    d = FullSlabInsulation(0, 0, 2 * wperimeter, slabLength, carpet, k)
    # Trap zeros or small negatives before exponents are applied:
    dB = [d - b, 0.0000001].max
    cD = [c - d, 0.0000001].max
    wp = [wperimeter, 0.0000001].max
    # Result:
    perimeterConductance = b + c - d + k2 * (2 * wp / slabWidth)**p * dB**q * cD**r
    return perimeterConductance
  end

  def FullSlabInsulation(rbottom, rgap, w, l, carpet, k)
    # Coded by Dennis Barley, March 2013.
    # This routine calculates the perimeter conductance for a slab with insulation
    #   under the entire slab as well as gap insulation around the edge.
    # Parameters:
    #   Rbottom = R-factor of insulation placed horizontally under the entire slab, h*ft2*F/Btu
    #   Rgap    = R-factor of insulation placed vertically between edge of slab & foundation wall, h*ft2*F/Btu
    #   W       = width (shorter dimension) of the slab, ft.  Set to 28 to match Winkelmann analysis.
    #   L       = longer dimension of the slab, ft.  Set to 55 to match Winkelmann analysis.
    #   Carpet  = 1 if carpeted, 0 if not carpeted
    #   k       = thermal conductivity of the soil, Btu/h*ft*F.  Set to 1 to match Winkelmann analysis.
    # Constants:
    zf = 0 # Depth of slab bottom, ft
    r0 = 1.47    # Thermal resistance of concrete slab and inside air film, h*ft2*F/Btu
    rca = 0      # R-value of carpet, if absent,  h*ft2*F/Btu
    rcp = 2.0      # R-value of carpet, if present, h*ft2*F/Btu
    rsea = 0.8860  # Effective resistance of slab edge if carpet is absent,  h*ft2*F/Btu
    rsep = 1.5260  # Effective resistance of slab edge if carpet is present, h*ft2*F/Btu
    t = 4.0 / 12.0 # Thickness of slab: Assumed value if 4 inches; not a variable in the analysis, ft
    # Carpet factors:
    if carpet == 0
      rc  = rca
      rse = rsea
    elsif carpet == 1
      rc  = rcp
      rse = rsep
    end

    rother = rc + r0 + rbottom # Thermal resistance other than the soil (from inside air to soil)
    # Ubottom:
    term1 = 2.0 * k / (Math::PI * w)
    term3 = zf / 2.0 + k * rother / Math::PI
    term2 = term3 + w / 2.0
    ubottom = term1 * Math::log(term2 / term3)
    pbottom = ubottom * (l * w) / (2.0 * (l + w))
    # Uedge:
    uedge = 1.0 / (rse + rgap)
    pedge = t * uedge
    # Result:
    perimeterConductance = pbottom + pedge
    return perimeterConductance
  end

  def ExteriorSlabInsulation(depth, rvalue, carpet)
    # Coded by Dennis Barley, April 2013.
    # This routine calculates the perimeter conductance for a slab with insulation
    #   placed vertically outside the foundation.
    #   This is a correlation to Winkelmann results.
    # Parameters:
    #   Depth     = Depth to which insulation extends into the ground, ft
    #   Rvalue    = R-factor of insulation, h*ft2*F/Btu
    #   Carpet    = 1 if carpeted, 0 if not carpeted
    # Carpet factors:
    if carpet == 0
      a = 9.02928
      b  = 8.20902
      e1 = 0.54383
      e2 = 0.74266
    elsif carpet == 1
      a = 8.53957
      b  = 11.09168
      e1 =  0.57937
      e2 =  0.80699
    end
    perimeterConductance = a / (b + rvalue**e1 * depth**e2)
    return perimeterConductance
  end
end # end the measure

# this allows the measure to be use by the application
ProcessConstructionsSlab.new.registerWithApplication
