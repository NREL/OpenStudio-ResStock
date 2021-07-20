# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

require_relative('os_lib_sql_file')
require 'matrix'

module OsLib_HeatTransfer
  def self.internal_gain_outputs
    return [
      'Zone Electric Equipment Convective Heating Energy',
      'Zone Gas Equipment Convective Heating Energy',
      'Zone Lights Convective Heating Energy',
      'Zone People Convective Heating Energy',
      'Zone Other Equipment Convective Heating Energy'
    ]
  end

  def self.wh_internal_gain_outputs
    return [
      'Water Heater Heat Loss Energy'
    ]
  end

  def self.infiltration_gain_outputs
    return [
      'Zone Infiltration Sensible Heat Gain Energy'
    ]
  end

  def self.infiltration_loss_outputs
    return [
      'Zone Infiltration Sensible Heat Loss Energy'
    ]
  end

  def self.ventilation_gain_outputs
    return [
      'Zone Mechanical Ventilation Cooling Load Increase Energy',
      'Zone Mechanical Ventilation Heating Load Decrease Energy'
    ]
  end

  def self.ventilation_loss_outputs
    return [
      'Zone Mechanical Ventilation Heating Load Increase Energy',
      'Zone Mechanical Ventilation Cooling Load Decrease Energy'
    ]
  end

  def self.air_transfer_outputs
    return [
      # 'Zone Air Heat Balance Interzone Air Transfer Rate'
      # TODO might need to include these in other models
      # Zone Exfiltration Sensible Heat Transfer Rate
      # Zone Exhaust Air Sensible Heat Transfer Rate
    ]
  end

  def self.surface_convection_outputs
    return [
      'Surface Inside Face Convection Heat Gain Energy'
    ]
  end

  def self.window_gain_loss_outputs
    return [
      'Zone Windows Total Heat Gain Energy',
      'Zone Windows Total Transmitted Solar Radiation Energy',
      'Zone Windows Total Heat Loss Energy'
    ]
  end

  def self.zone_air_heat_balance_outputs
    return [
      'Zone Air Heat Balance Internal Convective Heat Gain Rate',
      'Zone Air Heat Balance Surface Convection Rate',
      'Zone Air Heat Balance Interzone Air Transfer Rate',
      'Zone Air Heat Balance Outdoor Air Transfer Rate',
      'Zone Air Heat Balance Air Energy Storage Rate',
      'Zone Air Heat Balance System Air Transfer Rate',
      'Zone Air Heat Balance System Convective Heat Gain Rate'
    ]
  end

  def self.zone_air_temperature_outputs
    return [
      'Zone Air Temperature',
      'Zone Mean Air Temperature'
    ]
  end

  def self.surface_outputs
    return [
      'Surface Inside Face Temperature',
      'Surface Inside Face Convection Heat Transfer Coefficient'
    ]
  end

  def self.heat_transfer_outputs
    outputs = []

    # internal gain outputs
    outputs += internal_gain_outputs

    # other internal gain outputs
    outputs += wh_internal_gain_outputs

    # infiltration gain outputs
    outputs += infiltration_gain_outputs

    # infiltration loss outputs
    outputs += infiltration_loss_outputs

    # ventilation gain outputs
    outputs += ventilation_gain_outputs

    # ventilation loss outputs
    outputs += ventilation_loss_outputs

    # air transfer gain outputs
    outputs += air_transfer_outputs

    # surface convection outputs
    outputs += surface_convection_outputs

    # window gain and loss outputs
    outputs += window_gain_loss_outputs

    # zone air heat balance outputs
    outputs += zone_air_heat_balance_outputs

    # zone air temperature outputs
    outputs += zone_air_temperature_outputs

    outputs += surface_outputs

    return outputs
  end

  # Calculates the error between two vectors for each elements
  # @return Vector where the values are errors as decimals (0.6 = 60% error)
  def self.ts_error_between_vectors(approx_vector, exact_vector, decimals = 2)
    error_vals = []
    approx_vector.to_a.zip(exact_vector.to_a) do |approx, exact|
      err = (approx - exact) / exact
      error_vals << err.round(decimals)
    end

    return Vector.elements(error_vals)
  end

  # Calculates the annual total error between the positive values in two vectors as a single number
  # @return Double where the value is errors as decimal (0.6 = 60% error)
  def self.annual_heat_gain_error_between_vectors(approx_vector, exact_vector, decimals = 2)
    approx_pos_sum = 0.01
    approx_vector.to_a.each do |val|
      approx_pos_sum += val if val > 0
    end

    exact_pos_sum = 0.01
    exact_vector.to_a.each do |val|
      exact_pos_sum += val if val > 0
    end

    err = (approx_pos_sum - exact_pos_sum) / exact_pos_sum

    return err.round(decimals)
  end

  # Calculates the annual total error between the negative values in two vectors as a single number
  # @return Double where the value is errors as decimal (0.6 = 60% error)
  def self.annual_heat_loss_error_between_vectors(approx_vector, exact_vector, decimals = 2)
    approx_pos_sum = -0.01
    approx_vector.to_a.each do |val|
      approx_pos_sum += val if val < 0
    end

    exact_pos_sum = -0.01
    exact_vector.to_a.each do |val|
      exact_pos_sum += val if val < 0
    end

    err = (approx_pos_sum - exact_pos_sum) / exact_pos_sum

    return err.round(decimals)
  end

  # Calculates
  def self.thermal_zone_heat_transfer_vectors(runner, zone, sql, freq)
    # Define variables
    joules = 'J'
    watts = 'W'
    celsius = 'C'

    # Get the zone name
    zone_name = zone.name.get

    # Get the annual run period
    ann_env_pd = nil
    sql.availableEnvPeriods.each do |env_pd|
      env_type = sql.environmentType(env_pd)
      next unless env_type.is_initialized

      if env_type.get == OpenStudio::EnvironmentType.new('WeatherRunPeriod')
        ann_env_pd = env_pd
      end
    end

    unless ann_env_pd
      runner.registerError('An annual simulation was not run. Cannot get annual timeseries data')
    end

    # Get the timestep length
    steps_per_hour = if zone.model.getSimulationControl.timestep.is_initialized
                       zone.model.getSimulationControl.timestep.get.numberOfTimestepsPerHour
                     else
                       6 # default OpenStudio timestep if none specified
                     end
    sec_per_step = (3600 / steps_per_hour).to_f

    # Get the annual hours simulated
    hrs_sim = 0
    if sql.hoursSimulated.is_initialized
      hrs_sim = sql.hoursSimulated.get
    else
      runner.registerError('An annual simulation was not run. Cannot summarize annual heat transfer for Scout.')
    end

    # Determine the number of timesteps
    num_ts = hrs_sim * steps_per_hour

    # Hashes of vectors
    heat_transfer_vectors = {}

    # Empty vectors for subtotals
    total_internal_gains = Vector.elements(Array.new(num_ts, 0.0))
    total_infiltration_gains = Vector.elements(Array.new(num_ts, 0.0))
    total_ventilation_gains = Vector.elements(Array.new(num_ts, 0.0))
    total_surface_convection = Vector.elements(Array.new(num_ts, 0.0))
    total_window_radiation = Vector.elements(Array.new(num_ts, 0.0))
    heat_transfer_vectors['Water Heater Heat Loss Energy'] = Vector.elements(Array.new(num_ts, 0.0))

    # Internal gains
    internal_gain_outputs.each do |output|
      vals = OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, output, zone_name, num_ts, joules)
      vect = Vector.elements(vals)
      heat_transfer_vectors[output] = vect
      total_internal_gains += vect
    end

    # WH internal gains
    wh_internal_gain_outputs.each do |output|
      heat_transfer_vectors[output] = Vector.elements(Array.new(num_ts, 0.0))
      zone.model.getWaterHeaterMixeds.each do |wh|
        next if wh.ambientTemperatureThermalZone.get != zone

        wh_name = wh.name.to_s.upcase
        vals = OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, output, wh_name, num_ts, joules)
        vect = -1.0 * Vector.elements(vals) # reverse vector sign for loss variables before summing
        factor = 1.0
        if wh.heaterFuelType != 'Electricity'
          factor = 0.64
        end
        vect *= factor # TODO: https://github.com/NREL/OpenStudio-HPXML/blob/d47ce825d58a87295b66fa4580f944230d0d6295/resources/waterheater.rb#L1067
        heat_transfer_vectors[output] += vect
        total_internal_gains += vect
      end
    end

    # Report out combined electric and gas equipment
    heat_transfer_vectors['Zone Equipment Internal Gains'] = heat_transfer_vectors['Zone Electric Equipment Convective Heating Energy']
    heat_transfer_vectors['Zone Equipment Internal Gains'] += heat_transfer_vectors['Zone Gas Equipment Convective Heating Energy']
    heat_transfer_vectors['Zone Equipment Internal Gains'] += heat_transfer_vectors['Water Heater Heat Loss Energy']

    # Includes duct losses, water fixture heat gains, and electric loads for NG dryers
    heat_transfer_vectors['Zone Equipment Other Internal Gains'] = heat_transfer_vectors['Zone Other Equipment Convective Heating Energy']

    # Compare Internal gains to EnergyPlus zone air heat balance
    true_total_internal_gains = sec_per_step * Vector.elements(OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, 'Zone Air Heat Balance Internal Convective Heat Gain Rate', zone_name, num_ts, watts))
    heat_transfer_vectors['Calc Internal Gains'] = total_internal_gains
    heat_transfer_vectors['True Internal Gains'] = true_total_internal_gains
    heat_transfer_vectors['Diff Internal Gains'] = true_total_internal_gains - total_internal_gains
    heat_transfer_vectors['Error in Internal Gains'] = ts_error_between_vectors(total_internal_gains, true_total_internal_gains, 2)
    heat_transfer_vectors["#{zone_name}: Annual Gain Error in Internal Gains"] = annual_heat_gain_error_between_vectors(total_internal_gains, true_total_internal_gains, 2)
    heat_transfer_vectors["#{zone_name}: Annual Loss Error in Internal Gains"] = annual_heat_loss_error_between_vectors(total_internal_gains, true_total_internal_gains, 2)

    # Infiltration gains
    infiltration_gain_outputs.each do |output|
      vals = OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, output, zone_name, num_ts, joules)
      vect = Vector.elements(vals)
      heat_transfer_vectors[output] = vect
      total_infiltration_gains += vect
    end

    # Infiltration losses
    infiltration_loss_outputs.each do |output|
      vals = OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, output, zone_name, num_ts, joules)
      vect = -1.0 * Vector.elements(vals) # reverse vector sign for loss variables before summing
      heat_transfer_vectors[output] = vect
      total_infiltration_gains += vect
    end

    # Report infiltration
    heat_transfer_vectors['Zone Infiltration Gains'] = total_infiltration_gains

    # Ventilation gains
    ventilation_gain_outputs.each do |output|
      vals = OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, output, zone_name, num_ts, joules)
      vect = Vector.elements(vals)
      heat_transfer_vectors[output] = vect
      total_ventilation_gains += vect
    end

    # Ventilation losses
    ventilation_loss_outputs.each do |output|
      vals = OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, output, zone_name, num_ts, joules)
      vect = -1.0 * Vector.elements(vals) # reverse vector sign for loss variables before summing
      heat_transfer_vectors[output] = vect
      total_ventilation_gains += vect
    end

    # Air transfer gains
    # Included in ventilation because typically interzone transfer air is makeup ventilation for exhaust
    air_transfer_outputs.each do |output|
      vals = OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, output, zone_name, num_ts, watts)
      vect = -1.0 * sec_per_step * Vector.elements(vals) # reverse vector sign because of variable convention
      heat_transfer_vectors[output] = vect
      total_ventilation_gains += vect
    end

    # Report ventilation
    heat_transfer_vectors['Zone Ventilation Gains'] = total_ventilation_gains

    # Compare Infiltration plus Ventilation gains to EnergyPlus zone air heat balance
    # Subtract off interzone heat transfer because EnergyPlus accounts for this in an independent category
    total_outdoor_air_gains = total_infiltration_gains + total_ventilation_gains
    true_interzone = sec_per_step * Vector.elements(OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, 'Zone Air Heat Balance Interzone Air Transfer Rate', zone_name, num_ts, watts))
    true_total_outdoor_air_gains = sec_per_step * Vector.elements(OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, 'Zone Air Heat Balance Outdoor Air Transfer Rate', zone_name, num_ts, watts))
    heat_transfer_vectors['Calc Outdoor Air Gains'] = total_outdoor_air_gains
    heat_transfer_vectors['True Outdoor Air Gains'] = true_total_outdoor_air_gains - true_interzone
    heat_transfer_vectors['Diff Outdoor Air Gains'] = (true_total_outdoor_air_gains + true_interzone) - total_outdoor_air_gains
    heat_transfer_vectors['Error in Outdoor Air Gains'] = ts_error_between_vectors(total_outdoor_air_gains - true_interzone, true_total_outdoor_air_gains, 2)
    heat_transfer_vectors["#{zone_name}: Annual Gain Error in Outdoor Air Gains"] = annual_heat_gain_error_between_vectors(total_outdoor_air_gains - true_interzone, true_total_outdoor_air_gains, 2)
    heat_transfer_vectors["#{zone_name}: Annual Loss Error in Outdoor Air Gains"] = annual_heat_loss_error_between_vectors(total_outdoor_air_gains - true_interzone, true_total_outdoor_air_gains, 2)

    # Suface and SubSurface heat gains or losses, depending on sign
    heat_transfer_vectors['Zone Wall Convection Heat Transfer Energy'] = Vector.elements(Array.new(num_ts, 0.0))
    heat_transfer_vectors['Zone Foundation Wall Convection Heat Transfer Energy'] = Vector.elements(Array.new(num_ts, 0.0))
    heat_transfer_vectors['Zone Roof Convection Heat Transfer Energy'] = Vector.elements(Array.new(num_ts, 0.0))
    heat_transfer_vectors['Zone Floor Convection Heat Transfer Energy'] = Vector.elements(Array.new(num_ts, 0.0))
    heat_transfer_vectors['Zone Ground Convection Heat Transfer Energy'] = Vector.elements(Array.new(num_ts, 0.0))
    heat_transfer_vectors['Zone Ceiling Convection Heat Transfer Energy'] = Vector.elements(Array.new(num_ts, 0.0))
    heat_transfer_vectors['Zone Floor Convection Heat Transfer Energy'] = Vector.elements(Array.new(num_ts, 0.0))
    heat_transfer_vectors['Zone Window Convection Heat Transfer Energy'] = Vector.elements(Array.new(num_ts, 0.0))
    heat_transfer_vectors['Zone Door Convection Heat Transfer Energy'] = Vector.elements(Array.new(num_ts, 0.0))
    heat_transfer_vectors['Zone Other Convection Heat Transfer Energy'] = Vector.elements(Array.new(num_ts, 0.0))

    # Sign convention for this variable:
    # + = heat flowing into surface (loss to zone)
    # - = heat flowing out of surface (gain to zone)
    # Vector must be reversed to match sign convention used for all other gains above
    surfaces_adjacent_in_same_zone = []
    surfaces_adjacent_to_other_zones = Hash.new(0.0)
    surface_inside_convection_output = 'Surface Inside Face Convection Heat Gain Energy'
    zone.spaces.sort.each do |space|
      space.surfaces.each do |surface|
        surface_name = surface.name.get
        ht_transfer_vals = OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, surface_inside_convection_output, surface_name, num_ts, joules)

        # Determine the surface type
        surface_type = if (surface.outsideBoundaryCondition == 'Outdoors' || surface.outsideBoundaryCondition == 'Adiabatic') && surface.surfaceType == 'Wall'
                         'Wall'
                       elsif (surface.outsideBoundaryCondition == 'Ground' || surface.outsideBoundaryCondition == 'Foundation' || surface.outsideBoundaryCondition == 'Adiabatic') && surface.surfaceType == 'Wall'
                         'Foundation Wall'
                       elsif (surface.outsideBoundaryCondition == 'Outdoors' || surface.outsideBoundaryCondition == 'Adiabatic') && surface.surfaceType == 'RoofCeiling'
                         'Roof'
                       elsif (surface.outsideBoundaryCondition == 'Outdoors' || surface.outsideBoundaryCondition == 'Adiabatic') && surface.surfaceType == 'Floor'
                         'Floor'
                       elsif (surface.outsideBoundaryCondition == 'Ground' || surface.outsideBoundaryCondition == 'Foundation' || surface.outsideBoundaryCondition == 'Adiabatic') && surface.surfaceType == 'Floor'
                         'Ground'
                       else # assume others are surfaces that are interior to the building and face other zones
                         'Interzone'
                       end

        if surface.adjacentSurface.is_initialized && (surface.surfaceType == 'RoofCeiling' || surface.surfaceType == 'Floor' || surface.surfaceType == 'Wall')
          adjacent_surface = surface.adjacentSurface.get
          if adjacent_surface.space.get.thermalZone.get != space.thermalZone.get # only consider interzonal adjacent surfaces
            adjacent_zone = adjacent_surface.space.get.thermalZone.get
            adjacent_zone_name = adjacent_zone.name.get
            unless surfaces_adjacent_to_other_zones.keys.include? adjacent_zone_name
              surfaces_adjacent_to_other_zones[adjacent_zone_name] = []
            end
            surfaces_adjacent_to_other_zones[adjacent_zone_name] << surface
          else # adjacent surfaces within the same zone
            surfaces_adjacent_in_same_zone << surface
          end
        end
        next if surface_type == 'Interzone'

        # Add to total for this surface type
        vect = -1.0 * Vector.elements(ht_transfer_vals) # reverse sign of vector
        heat_transfer_vectors["Zone #{surface_type} Convection Heat Transfer Energy"] += vect
        total_surface_convection += vect

        # SubSurfaces
        surface.subSurfaces.each do |sub_surface|
          sub_surface_name = sub_surface.name.get
          ht_transfer_vals = OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, surface_inside_convection_output, sub_surface_name, num_ts, joules)

          # Determine the subsurface type
          surface_type = if sub_surface.subSurfaceType.downcase.include? 'window'
                           'Window'
                         elsif sub_surface.subSurfaceType.downcase.include? 'door'
                           'Door'
                         else # assume others are subsurfaces that are interior to the building and face other zones
                           'Interzone'
                         end
          next if surface_type == 'Interzone'

          # Add to total for this surface type
          vect = -1.0 * Vector.elements(ht_transfer_vals) # reverse sign of vector
          heat_transfer_vectors["Zone #{surface_type} Convection Heat Transfer Energy"] += vect
          total_surface_convection += vect
        end
      end

      # Internal masses with SurfaceArea specified have surface convection
      space.internalMass.each do |int_mass|
        int_mass_name = int_mass.name.get
        ht_transfer_vals = OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, surface_inside_convection_output, int_mass_name, num_ts, joules)

        # Add to total for this internal mass
        vect = -1.0 * Vector.elements(ht_transfer_vals) # reverse sign of vector
        heat_transfer_vectors['Zone Other Convection Heat Transfer Energy'] += vect
        total_surface_convection += vect
      end
    end

    # Adjacent surfaces in the same zone become internal masses in E+
    surfaces_adjacent_in_same_zone.each do |surface_1|
      surfaces_adjacent_in_same_zone.each do |surface_2|
        next if surface_1 == surface_2

        int_mass_name = "MERGED #{surface_1.name.to_s.upcase} - #{surface_2.name.to_s.upcase}"
        ht_transfer_vals = OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, surface_inside_convection_output, int_mass_name, num_ts, joules)

        # Add to total for this internal mass
        vect = -1.0 * Vector.elements(ht_transfer_vals) # reverse sign of vector
        heat_transfer_vectors['Zone Other Convection Heat Transfer Energy'] += vect
        total_surface_convection += vect
      end
    end

    true_total_surface_convection = sec_per_step * Vector.elements(OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, 'Zone Air Heat Balance Surface Convection Rate', zone_name, num_ts, watts))
    true_air_energy_storage = sec_per_step * Vector.elements(OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, 'Zone Air Heat Balance Air Energy Storage Rate', zone_name, num_ts, watts)) # Reverse sign
    interzone_surface_convection = ((true_total_surface_convection - true_air_energy_storage) - total_surface_convection)

    est_interzone_conv = Vector.elements(Array.new(num_ts, 0.0))
    interzone_convection_dict = {}
    # Adjacent surfaces in different zones
    surfaces_adjacent_to_other_zones.each do |adjacent_zone_name, surfaces|
      total_surface_area = 0.0
      surfaces.each do |surface| # you can have multiple surfaces adjacent to another zone
        total_surface_area += surface.netArea
      end
      surfaces.each do |surface|
        surface_type = if surface.surfaceType == 'Wall'
                         'Wall'
                       elsif surface.surfaceType == 'Floor'
                         'Floor'
                       elsif surface.surfaceType == 'RoofCeiling'
                         'Ceiling'
                       end

        surface_temp = Vector.elements(OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, 'Surface Inside Face Temperature', surface.name.get, num_ts, celsius))
        conv_coeff = Vector.elements(OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, 'Surface Inside Face Convection Heat Transfer Coefficient', surface.name.get, num_ts, 'W/m2-K'))
        zone_temp = Vector.elements(OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, 'Zone Mean Air Temperature', zone_name, num_ts, celsius))

        deltaT = surface_temp - zone_temp
        est_conv = Vector.elements(conv_coeff.zip(deltaT).map { |h, t| surface.netArea * sec_per_step * h * t })
        est_interzone_conv += est_conv

        if (interzone_convection_dict[surface_type]).nil?
          interzone_convection_dict[surface_type] = est_conv
        else
          interzone_convection_dict[surface_type] += est_conv
        end

        # surface_fraction = (surface.netArea / total_surface_area) / surfaces_adjacent_to_other_zones.keys.length # most of the time this value should be 1 (one surface adjacent to zone)
        # vals = interzone_surface_convection.map{|x| x * surface_fraction}
        # vect = Vector.elements(vals)
        # heat_transfer_vectors["Zone #{surface_type} Convection Heat Transfer Energy"] += vect
        # total_surface_convection += vect
      end
    end

    interzone_convection_dict.each do |surface, surface_vect|
      surface_fractions = surface_vect.zip(est_interzone_conv).map { |surf, tot| surf / tot }
      new_vect = Vector.elements(interzone_surface_convection.zip(surface_fractions).map { |cv, frac| cv * frac })
      heat_transfer_vectors["Zone #{surface} Convection Heat Transfer Energy"] += new_vect
    end

    # The two interzone convection energies align well when supply != 0, but are very different with no supply
    # heat_transfer_vectors["Interzone Surface Convection"] = interzone_surface_convection
    # heat_transfer_vectors["Interzone Surface Convection (Calculated)"] = est_interzone_conv
    # Compare Surface Convection to EnergyPlus zone air heat balance
    heat_transfer_vectors['Calc Surface Convection'] = total_surface_convection
    heat_transfer_vectors['True Surface Convection'] = true_total_surface_convection - true_air_energy_storage
    heat_transfer_vectors['Diff Surface Convection'] = true_total_surface_convection - true_air_energy_storage - total_surface_convection
    heat_transfer_vectors['Error in Surface Convection'] = ts_error_between_vectors(total_surface_convection, true_total_surface_convection - true_air_energy_storage, 2)
    heat_transfer_vectors["#{zone_name}: Annual Gain Error in Surface Convection"] = annual_heat_gain_error_between_vectors(total_surface_convection, true_total_surface_convection - true_air_energy_storage, 2)
    heat_transfer_vectors["#{zone_name}: Annual Loss Error in Surface Convection"] = annual_heat_loss_error_between_vectors(total_surface_convection, true_total_surface_convection - true_air_energy_storage, 2)

    # Window radiation energy
    #
    # Per the EnergyPlus Engineering Reference for Solar Distribution type = 'FullExterior` (E+ IDD default value):
    #
    #   All beam solar radiation entering the zone is assumed to fall on the floor, where it is absorbed according to the floor’s solar absorptance.
    #   Any reflected by the floor is added to the transmitted diffuse radiation, which is assumed to be uniformly distributed on all interior surfaces.
    #   If no floor is present in the zone, the incident beam solar radiation is absorbed on all interior surfaces according to their absorptances.
    #   The zone heat balance is then applied at each surface and on the zone’s air with the absorbed radiation being treated as a flux on the surface.
    #
    # This means that temperature of the ground/floor (which results in convection) is caused by a combination of previously absorbed
    # solar radiation and current timestep conduction from the temperature difference between the ground/floor and the soil/zone below.
    #
    # For Scout, it is necessary to split window solar radiation out separately
    # Use the Radiant Time Series (RTS) method to estimate past solar radiation contribution to the current timestep
    # RTS values = amount of earlier solar radiation heat gain that becomes convective heat gain during the current hour (0 = current hr)
    #   ASHRAE HOF 2013 Chapter 18 Table 20: Representative Solar RTS Values for Light to Heavy Construction
    #   Medium Construction, 50% glass, with carpet
    # hrs = [0,    1,    2,    3,    4,    5,    6,    7,    8,    9,    10,   11,   12,   13,   14,   15,   16,   17,   18,   19,  20,  21,  22,  23]
    rts = [0.54, 0.16, 0.08, 0.04, 0.03, 0.02, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.0, 0.0, 0.0, 0.0, 0.0]

    # Solar radiation gain (always positive)
    wind_solar_rad_vals = Vector.elements(OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, 'Zone Windows Total Transmitted Solar Radiation Energy', zone_name, num_ts, joules))
    # heat_transfer_vectors['Zone Windows Transmitted Radiation Energy'] = wind_solar_rad_vals

    # RTS solar radiation energy per timestep for past 24 hrs
    rts_solar_rad_ary = []
    num_ts_24hr = 24 * steps_per_hour
    wind_solar_rad_vals.each_with_index do |val, i|
      # Get the values from the current hr to 23hrs in the past
      prev_24hr_vals = []
      (0...num_ts_24hr).each do |ts|
        prev_24hr_vals << wind_solar_rad_vals.to_a.fetch(i - ts)
      end

      # Calculate the RTS solar value for the current timestep
      solar_rad_rts = 0.0
      hr_i = 0
      prev_24hr_vals.each_slice(steps_per_hour) do |vals_in_hr|
        avg_per_ts_in_hr = vals_in_hr.to_a.inject(:+).to_f / vals_in_hr.size
        hrly_solar_rad_rts = avg_per_ts_in_hr * rts[hr_i]
        solar_rad_rts += hrly_solar_rad_rts
        hr_i += 1
      end
      rts_solar_rad_ary << solar_rad_rts
    end
    wind_rts_solar_rad_vals = Vector.elements(rts_solar_rad_ary)

    # Check that the annual sum of RTS solar matches the annual sum of the instantaneous solar radiation
    # to ensure that calculation was done correctly
    ann_solar_rad = wind_solar_rad_vals.to_a.inject(:+).to_f
    ann_rts_solar_rad = wind_rts_solar_rad_vals.to_a.inject(:+).to_f
    if ((ann_rts_solar_rad - ann_solar_rad) / ann_solar_rad).abs > 0.01
      runner.registerError("Solar radiation RTS calculations had an error: annual instantaneous solar = #{ann_solar_rad}, but annual RTS solar = #{ann_rts_solar_rad}; they should be identical")
    end

    # Subtract window RTS heat transfer off of ground or floor (whichever is larger) to keep heat balance correct
    floor_vals = heat_transfer_vectors['Zone Floor Convection Heat Transfer Energy']
    ground_vals = heat_transfer_vectors['Zone Ground Convection Heat Transfer Energy']
    sum_floor = (floor_vals.inject(:+).to_f / floor_vals.size).abs
    sum_ground = (ground_vals.inject(:+).to_f / ground_vals.size).abs
    if sum_floor.zero? && sum_ground.zero?
      runner.registerWarning("Zone #{zone_name} does not have a floor or ground surface, cannot split out window radiation.")
      heat_transfer_vectors['Zone Window Radiation Heat Transfer Energy'] = Vector.elements(Array.new(num_ts, 0.0))
      heat_transfer_vectors['Zone Floor Convection Heat Transfer Energy'] = Vector.elements(Array.new(num_ts, 0.0))
    elsif sum_floor >= sum_ground
      runner.registerInfo("For zone #{zone_name}, removing solar radiation from floor convection.")
      heat_transfer_vectors['Zone Window Radiation Heat Transfer Energy'] = wind_rts_solar_rad_vals
      total_window_radiation = wind_rts_solar_rad_vals
      heat_transfer_vectors['Zone Floor Convection Heat Transfer Energy'] -= wind_rts_solar_rad_vals
      total_surface_convection -= wind_rts_solar_rad_vals
    else # sum_ground > sum_floor
      runner.registerInfo("For zone #{zone_name}, removing solar radiation from ground convection.")
      heat_transfer_vectors['Zone Window Radiation Heat Transfer Energy'] = wind_rts_solar_rad_vals
      total_window_radiation = wind_rts_solar_rad_vals
      heat_transfer_vectors['Zone Ground Convection Heat Transfer Energy'] -= wind_rts_solar_rad_vals
      total_surface_convection -= wind_rts_solar_rad_vals
    end

    # Sum all demand and compare to total EnergyPlus supply zone air heat balance
    # Demand = heat gain/loss that must be compensated for by HVAC to maintain setpoint
    # Supply = heat added/removed by HVAC to maintain setpoint
    total_energy_balance = total_internal_gains + total_infiltration_gains + total_ventilation_gains + total_surface_convection + total_window_radiation
    true_airloop = sec_per_step * Vector.elements(OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, 'Zone Air Heat Balance System Air Transfer Rate', zone_name, num_ts, watts))
    true_zone_equip = sec_per_step * Vector.elements(OsLib_SqlFile.get_timeseries_array(runner, sql, ann_env_pd, freq, 'Zone Air Heat Balance System Convective Heat Gain Rate', zone_name, num_ts, watts))
    true_total_energy_balance = true_airloop + true_zone_equip + (2.0 * true_air_energy_storage) # Storage is included on both sides of equation: embedded inside convection on demand side, added with opposite sign on supply side
    heat_transfer_vectors['Calc Energy Balance'] = total_energy_balance
    heat_transfer_vectors['True Energy Balance'] = -1 * true_total_energy_balance
    heat_transfer_vectors['Diff Energy Balance'] = -1 * true_total_energy_balance - total_energy_balance
    heat_transfer_vectors['Error in Energy Balance'] = ts_error_between_vectors(total_energy_balance, -1 * true_total_energy_balance, 2) # Reverse sign of one before comparing
    heat_transfer_vectors["#{zone_name}: Annual Gain Error in Total Energy Balance"] = annual_heat_gain_error_between_vectors(total_energy_balance, -1 * true_total_energy_balance, 2) # Reverse sign of one before comparing
    heat_transfer_vectors["#{zone_name}: Annual Loss Error in Total Energy Balance"] = annual_heat_loss_error_between_vectors(total_energy_balance, -1 * true_total_energy_balance, 2) # Reverse sign of one before comparing

    # Record heating and cooling from airloop and zone equipment
    heat_transfer_vectors['Airloop HVAC Heat Transfer Energy'] = true_airloop # Ducted heat add/remove
    heat_transfer_vectors['Non-Airloop HVAC Heat Transfer Energy'] = true_zone_equip # Non-ducted (eg baseboard)
    heat_transfer_vectors['All HVAC Heat Transfer Energy'] = true_airloop + true_zone_equip

    return heat_transfer_vectors
  end
end
