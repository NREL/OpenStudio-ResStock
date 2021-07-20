# frozen_string_literal: true

class SimControls
  def self.apply(model, hpxml)
    sim = model.getSimulationControl
    sim.setRunSimulationforSizingPeriods(false)

    tstep = model.getTimestep
    tstep.setNumberOfTimestepsPerHour(60 / hpxml.header.timestep)

    shad = model.getShadowCalculation
    shad.setMaximumFiguresInShadowOverlapCalculations(200)
    # Use EnergyPlus default of 20 days for update frequency; it is a reasonable balance
    # between speed and accuracy (e.g., sun position, picking up any change in window
    # interior shading transmittance, etc.).
    shad.setShadingCalculationUpdateFrequency(20)

    has_windows_varying_transmittance = false
    hpxml.windows.each do |window|
      sf_summer = window.interior_shading_factor_summer * window.exterior_shading_factor_summer
      sf_winter = window.interior_shading_factor_winter * window.exterior_shading_factor_winter
      next if sf_summer == sf_winter

      has_windows_varying_transmittance = true
    end
    if has_windows_varying_transmittance
      # Detailed diffuse algorithm is required for window interior shading with varying
      # transmittance schedules
      shad.setSkyDiffuseModelingAlgorithm('DetailedSkyDiffuseModeling')
    end

    outsurf = model.getOutsideSurfaceConvectionAlgorithm
    outsurf.setAlgorithm('DOE-2')

    insurf = model.getInsideSurfaceConvectionAlgorithm
    insurf.setAlgorithm('TARP')

    zonecap = model.getZoneCapacitanceMultiplierResearchSpecial
    zonecap.setHumidityCapacityMultiplier(15)

    convlim = model.getConvergenceLimits
    convlim.setMinimumSystemTimestep(0)

    run_period = model.getRunPeriod
    run_period.setBeginMonth(hpxml.header.sim_begin_month)
    run_period.setBeginDayOfMonth(hpxml.header.sim_begin_day)
    run_period.setEndMonth(hpxml.header.sim_end_month)
    run_period.setEndDayOfMonth(hpxml.header.sim_end_day)
  end
end
