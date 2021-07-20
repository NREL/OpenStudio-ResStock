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

module OsLib_SqlFile
  # Gets a timeseries as a standard Ruby array (instead of OpenStudio::Timeseries).
  # Performs error checking on query before execution.
  # @return [Array] an array containing the values from the OpenStudio::Timeseries.
  #   returns an array of zeros with a size of num_timesteps for invalid queries.
  def self.get_timeseries_array(runner, sql, env_period, timestep, variable_name, key_value, num_timesteps, expected_units = nil)
    time_series_array = []
    key_value = key_value.upcase  # upper cases the key_value b/c it is always uppercased in the sql file.
    time_series = sql.timeSeries(env_period, timestep, variable_name, key_value)
    if time_series.is_initialized # checks to see if time_series exists
      time_series = time_series.get
      # Check the units
      unless expected_units.nil?
        unless time_series.units == expected_units
          runner.registerError("Expected units of #{expected_units} but got #{time_series.units} for #{variable_name}")
        end
      end

      time_series = time_series.values
      for i in 0..(time_series.size - 1)
        time_series_array << time_series[i]
      end
    else
      # Query is not valid.
      time_series_array = Array.new(num_timesteps, 0.0)
      runner.registerWarning("Timeseries query: '#{variable_name}' for '#{key_value}' at '#{timestep}' not found, returning array of zeros")
    end

    return time_series_array
  end

  def self.get_key_values(runner, sql, env_period, timestep, variable_name)
    key_values = sql.availableKeyValues(env_period, timestep, variable_name)

    return key_values
  end
end
