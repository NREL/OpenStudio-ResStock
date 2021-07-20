# frozen_string_literal: true

class Simulation
  def self.apply(model, runner, timesteps_per_hr = 1, min_system_timestep_mins = nil, begin_month = 1, begin_day_of_month = 1, end_month = 12, end_day_of_month = 31, calendar_year = 2007)
    sim = model.getSimulationControl
    sim.setRunSimulationforSizingPeriods(false)

    tstep = model.getTimestep
    tstep.setNumberOfTimestepsPerHour(timesteps_per_hr) # Timesteps/hour

    shad = model.getShadowCalculation
    shad.setMaximumFiguresInShadowOverlapCalculations(200)
    # Detailed diffuse algorithm is required for window interior shading with varying
    # transmittance schedules
    shad.setSkyDiffuseModelingAlgorithm('DetailedSkyDiffuseModeling')
    # Use EnergyPlus default of 20 days for update frequency; it is a reasonable balance
    # between speed and accuracy (e.g., sun position, picking up any change in window
    # interior shading transmittance, etc.).
    shad.setShadingCalculationUpdateFrequency(20)

    outsurf = model.getOutsideSurfaceConvectionAlgorithm
    outsurf.setAlgorithm('DOE-2')

    insurf = model.getInsideSurfaceConvectionAlgorithm
    insurf.setAlgorithm('TARP')

    zonecap = model.getZoneCapacitanceMultiplierResearchSpecial
    zonecap.setHumidityCapacityMultiplier(15)

    if not min_system_timestep_mins.nil?
      convlim = model.getConvergenceLimits
      convlim.setMinimumSystemTimestep(min_system_timestep_mins) # Minutes
    end

    run_period = model.getRunPeriod
    run_period.setBeginMonth(begin_month)
    run_period.setBeginDayOfMonth(begin_day_of_month)
    run_period.setEndMonth(end_month)
    run_period.setEndDayOfMonth(end_day_of_month)

    year_description = model.getYearDescription
    year_description.setCalendarYear(calendar_year)

    return true
  end
end
