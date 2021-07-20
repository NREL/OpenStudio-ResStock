# frozen_string_literal: true

class UnitConversions
  # As there is a performance penalty to using OpenStudio's built-in unit convert()
  # method, we use, our own methods here.

  def self.convert(x, from, to, fuel_type = nil, is_leap_year = false, steps_per_hour = 6)
    from = from.downcase
    to = to.downcase

    return x if from == to

    # Energy
    if (from == 'btu') && (to == 'j')
      return x * 1055.05585262
    elsif (from == 'btu') && (to == 'kwh')
      return x / 3412.141633127942
    elsif (from == 'btu') && (to == 'wh')
      return x / 3.412141633127942
    elsif (from == 'j') && (to == 'btu')
      return x * 3412.141633127942 / 1000.0 / 3600.0
    elsif (from == 'j') && (to == 'kbtu')
      return x * 3412.141633127942 / 1000.0 / 3600.0 / 1000.0
    elsif (from == 'j') && (to == 'kwh')
      return x / 3600000.0
    elsif (from == 'kbtu') && (to == 'therm')
      return x / 100.0
    elsif (from == 'j') && (to == 'therm')
      return x * 3412.141633127942 / 1000.0 / 3600.0 / 1000.0 / 100.0
    elsif (from == 'kj') && (to == 'btu')
      return x * 0.9478171203133172
    elsif (from == 'gj') && (to == 'mbtu')
      return x * 0.9478171203133172
    elsif (from == 'j') && (to == 'mbtu')
      return x * 0.9478171203133172 / 1000000000.0
    elsif (from == 'gj') && (to == 'kwh')
      return x * 277.778
    elsif (from == 'gj') && (to == 'therm')
      return x * 9.48043
    elsif (from == 'kwh') && (to == 'btu')
      return x * 3412.141633127942
    elsif (from == 'kwh') && (to == 'mbtu')
      return x * 0.003412141633127942
    elsif (from == 'kwh') && (to == 'j')
      return x * 3600000.0
    elsif (from == 'wh') && (to == 'gj')
      return x * 0.0000036
    elsif (from == 'kwh') && (to == 'therm')
      return x / 29.307107017222222
    elsif (from == 'kwh') && (to == 'wh')
      return x * 1000.0
    elsif (from == 'mbtu') && (to == 'wh')
      return x * 293071.0701722222
    elsif (from == 'therm') && (to == 'btu')
      return x * 100000.0
    elsif (from == 'therm') && (to == 'mbtu')
      return x / 10.0
    elsif (from == 'therm') && (to == 'kbtu')
      return x * 100.0
    elsif (from == 'therm') && (to == 'kwh')
      return x * 29.307107017222222
    elsif (from == 'therm') && (to == 'wh')
      return x * 29307.10701722222
    elsif (from == 'wh') && (to == 'btu')
      return x * 3.412141633127942
    elsif (from == 'wh') && (to == 'kwh')
      return x / 1000.0
    elsif (from == 'wh') && (to == 'therm')
      return x / 29307.10701722222
    elsif (from == 'wh') && (to == 'mbtu')
      return x / 293071.0701722222
    elsif (from == 'kbtu') && (to == 'btu')
      return x * 1000.0
    elsif (from == 'btu') && (to == 'gal')
      if fuel_type == Constants.FuelTypePropane
        return x / 91600.0
      elsif fuel_type == Constants.FuelTypeOil
        return x / 139000.0
      end

      fail "Unhandled unit conversion from #{from} to #{to} for #{fuel_type}."
    elsif (from == 'gal') && (to == 'btu')
      if fuel_type == Constants.FuelTypePropane
        return x * 91600.0
      elsif fuel_type == Constants.FuelTypeOil
        return x * 139000.0
      end

      fail "Unhandled unit conversion from #{from} to #{to} for #{fuel_type}."
    elsif (from == 'j') && (to == 'gal')
      if fuel_type == Constants.FuelTypePropane
        return x * 3412.141633127942 / 1000.0 / 3600.0 / 91600.0
      elsif fuel_type == Constants.FuelTypeOil
        return x * 3412.141633127942 / 1000.0 / 3600.0 / 139000.0
      end

      fail "Unhandled unit conversion from #{from} to #{to} for #{fuel_type}."

    # Power
    elsif (from == 'btu/hr') && (to == 'ton')
      return x / 12000.0
    elsif (from == 'btu/hr') && (to == 'w')
      return x * 0.2930710701722222
    elsif (from == 'kbtu/hr') && (to == 'btu/hr')
      return x * 1000.0
    elsif (from == 'btu/hr') && (to == 'kbtu/hr')
      return x / 1000.0
    elsif (from == 'kbtu/hr') && (to == 'w')
      return x * 293.0710701722222
    elsif (from == 'kw') && (to == 'w')
      return x * 1000.0
    elsif (from == 'ton') && (to == 'btu/hr')
      return x * 12000.0
    elsif (from == 'ton') && (to == 'kbtu/hr')
      return x * 12.0
    elsif (from == 'ton') && (to == 'w')
      return x * 3516.85284207
    elsif (from == 'w') && (to == 'btu/hr')
      return x * 3.412141633127942
    elsif (from == 'w') && (to == 'kbtu/hr')
      return x / 293.0710701722222
    elsif (from == 'w') && (to == 'kw')
      return x / 1000.0
    elsif (from == 'w') && (to == 'ton')
      return x / 3516.85284207
    elsif (from == 'kw') && (to == 'kbtu/hr')
      return x / 0.2930710701722222
    elsif (from == 'kbtu/hr') && (to == 'kw')
      return x * 0.2930710701722222

    # Energy to Power
    elsif (from == 'j') && (to == 'w')
      return x / (3600.0 / steps_per_hour)
    elsif (from == 'j') && (to == 'kw')
      return x / (1000.0 * (3600.0 / steps_per_hour))
    elsif (from == 'gj') && (to == 'kw')
      return x * 1000000000.0 / (1000.0 * (3600.0 / steps_per_hour))

    # Power to Energy
    elsif (from == 'w') && (to == 'j')
      return x * 3600.0 / steps_per_hour
    elsif (from == 'kw') && (to == 'j')
      return x * 1000.0 * (3600.0 / steps_per_hour)
    elsif (from == 'kw') && (to == 'gj')
      return x * 1000.0 * (3600.0 / steps_per_hour) / 1000000000.0

    # Power Flux
    elsif (from == 'w/m^2') && (to == 'btu/(hr*ft^2)')
      return x * 0.3169983306281505

    # Temperature
    elsif (from == 'c') && (to == 'f')
      return 1.8 * x + 32.0
    elsif (from == 'c') && (to == 'k')
      return x + 273.15
    elsif (from == 'f') && (to == 'c')
      return (x - 32.0) / 1.8
    elsif (from == 'f') && (to == 'r')
      return x + 459.67
    elsif (from == 'k') && (to == 'c')
      return x - 273.15
    elsif (from == 'k') && (to == 'r')
      return x * 1.8
    elsif (from == 'r') && (to == 'f')
      return x - 459.67
    elsif (from == 'r') && (to == 'k')
      return x / 1.8

    # Specific Heat
    elsif (from == 'btu/(lbm*r)') && (to == 'j/(kg*k)') # by mass
      return x * 4187.0
    elsif (from == 'btu/(ft^3*f)') && (to == 'j/(m^3*k)') # by volume
      return x * 67100.0
    elsif (from == 'btu/(lbm*r)') && (to == 'wh/(kg*k)')
      return x * 1.1632

    # Length
    elsif (from == 'ft') && (to == 'in')
      return x * 12.0
    elsif (from == 'ft') && (to == 'm')
      return x * 0.3048
    elsif (from == 'in') && (to == 'ft')
      return x / 12.0
    elsif (from == 'in') && (to == 'm')
      return x * 0.0254
    elsif (from == 'm') && (to == 'ft')
      return x / 0.3048
    elsif (from == 'm') && (to == 'in')
      return x / 0.0254
    elsif (from == 'mm') && (to == 'm')
      return x / 1000.0

    # Area
    elsif (from == 'cm^2') && (to == 'ft^2')
      return x / 929.0304
    elsif (from == 'ft^2') && (to == 'cm^2')
      return x * 929.0304
    elsif (from == 'ft^2') && (to == 'in^2')
      return x * 144.0
    elsif (from == 'ft^2') && (to == 'm^2')
      return x * 0.09290304
    elsif (from == 'm^2') && (to == 'ft^2')
      return x / 0.09290304

    # Volume
    elsif (from == 'ft^3') && (to == 'gal')
      return x * 7.480519480579059
    elsif (from == 'ft^3') && (to == 'l')
      return x * 28.316846591999997
    elsif (from == 'ft^3') && (to == 'm^3')
      return x * 0.028316846592000004
    elsif (from == 'gal') && (to == 'ft^3')
      return x / 7.480519480579059
    elsif (from == 'gal') && (to == 'in^3')
      return x * 231.0
    elsif (from == 'gal') && (to == 'm^3')
      return x * 0.0037854117839698515
    elsif (from == 'in^3') && (to == 'gal')
      return x / 231.0
    elsif (from == 'l') && (to == 'pint')
      return x * 2.1133764
    elsif (from == 'l') && (to == 'ft^3')
      return x / 28.316846591999997
    elsif (from == 'm^3') && (to == 'ft^3')
      return x / 0.028316846592000004
    elsif (from == 'm^3') && (to == 'gal')
      return x / 0.0037854117839698515
    elsif (from == 'pint') && (to == 'l')
      return x * 0.47317647

    # Mass
    elsif (from == 'lbm') && (to == 'kg')
      return x * 0.45359237
    elsif (from == 'kg') && (to == 'lbm')
      return x / 0.45359237

    # Volume Flow Rate
    elsif (from == 'cfm') && (to == 'm^3/s')
      return x / 2118.880003289315
    elsif (from == 'ft^3/min') && (to == 'm^3/s')
      return x / 2118.880003289315
    elsif (from == 'gal/min') && (to == 'm^3/s')
      return x / 15850.323141615143
    elsif (from == 'm^3/s') && (to == 'gal/min')
      return x * 15850.323141615143
    elsif (from == 'm^3/s') && (to == 'cfm')
      return x * 2118.880003289315
    elsif (from == 'm^3/s') && (to == 'ft^3/min')
      return x * 2118.880003289315

    # Mass Flow Rate
    elsif (from == 'lbm/min') && (to == 'kg/hr')
      return x * 27.2155422
    elsif (from == 'lbm/min') && (to == 'kg/s')
      return x * 27.2155422 / 3600.0

    # Time
    elsif (from == 'day') && (to == 'hr')
      return x * 24.0
    elsif (from == 'day') && (to == 'yr')
      return x / Constants.NumDaysInYear(is_leap_year)
    elsif (from == 'hr') && (to == 'min')
      return x * 60.0
    elsif (from == 'hr') && (to == 's')
      return x * 3600.0
    elsif (from == 'hr') && (to == 'yr')
      return x / Constants.NumHoursInYear(is_leap_year)
    elsif (from == 'min') && (to == 'hr')
      return x / 60.0
    elsif (from == 'min') && (to == 's')
      return x * 60.0
    elsif (from == 'yr') && (to == 'day')
      return x * Constants.NumDaysInYear(is_leap_year)
    elsif (from == 'yr') && (to == 'hr')
      return x * Constants.NumHoursInYear(is_leap_year)

    # Velocity
    elsif (from == 'knots') && (to == 'm/s')
      return x * 0.51444444
    elsif (from == 'mph') && (to == 'm/s')
      return x * 0.44704
    elsif (from == 'm/s') && (to == 'knots')
      return x * 1.9438445
    elsif (from == 'm/s') && (to == 'mph')
      return x * 2.2369363

    # Pressure & Density
    elsif (from == 'atm') && (to == 'btu/ft^3')
      return x * 2.719
    elsif (from == 'atm') && (to == 'kpa')
      return x * 101.325
    elsif (from == 'atm') && (to == 'psi')
      return x * 14.692
    elsif (from == 'inh2o') && (to == 'pa')
      return x * 249.1
    elsif (from == 'kg/m^3') && (to == 'lbm/ft^3')
      return x / 16.02
    elsif (from == 'kpa') && (to == 'psi')
      return x / 6.89475729
    elsif (from == 'lbm/(ft*s^2)') && (to == 'inh2o')
      return x * 0.005974
    elsif (from == 'lbm/ft^3') && (to == 'inh2o/mph^2')
      return x * 0.01285
    elsif (from == 'lbm/ft^3') && (to == 'kg/m^3')
      return x * 16.02
    elsif (from == 'psi') && (to == 'btu/ft^3')
      return x * 0.185
    elsif (from == 'psi') && (to == 'kpa')
      return x * 6.89475729
    elsif (from == 'psi') && (to == 'pa')
      return x * 6.89475729 * 1000.0
    elsif (from == 'pa') && (to == 'psi')
      return x / 6895.0

    # Angles
    elsif (from == 'deg') && (to == 'rad')
      return x / 57.29578
    elsif (from == 'rad') && (to == 'deg')
      return x * 57.29578

    # R-Value
    elsif (from == 'hr*ft^2*f/btu') && (to == 'm^2*k/w')
      return x * 0.1761
    elsif (from == 'm^2*k/w') && (to == 'hr*ft^2*f/btu')
      return x / 0.1761

    # U-Factor
    elsif (from == 'btu/(hr*ft^2*f)') && (to == 'w/(m^2*k)')
      return x * 5.678
    elsif (from == 'w/(m^2*k)') && (to == 'btu/(hr*ft^2*f)')
      return x / 5.678

    # UA
    elsif (from == 'btu/(hr*f)') && (to == 'w/k')
      return x * 0.5275
    elsif (from == 'w/k') && (to == 'btu/(hr*f)')
      return x / 0.5275

    # Thermal Conductivity
    elsif (from == 'w/(m*k)') && (to == 'btu/(hr*ft*r)')
      return x / 1.731
    elsif (from == 'btu/(hr*ft*r)') && (to == 'w/(m*k)')
      return x * 1.731
    elsif (from == 'btu*in/(hr*ft^2*r)') && (to == 'w/(m*k)')
      return x * 0.14425

    # Infiltration
    elsif (from == 'ft^2/(s^2*r)') && (to == 'l^2/(s^2*cm^4*k)')
      return x * 0.001672
    elsif (from == 'inh2o/mph^2') && (to == 'pa*s^2/m^2')
      return x * 1246.0
    elsif (from == 'inh2o/r') && (to == 'pa/k')
      return x * 448.4

    # Humidity
    elsif (from == 'lbm/lbm') && (to == 'grains')
      return x * 7000.0
    end

    fail "Unhandled unit conversion from #{from} to #{to}."
  end

  def self.get_scalar_unit_conversion(var_name, old_units, fuel_type)
    if old_units == 'm3'
      old_units = 'm^3'
    end

    new_units = nil
    if ['J', 'm^3', 'm3'].include? old_units
      if var_name.downcase.include? 'electricity'
        new_units = 'kWh'
      elsif var_name.downcase.include? 'gas'
        new_units = 'therm'
      else
        new_units = 'gal'
      end
      return new_units, convert(1.0, old_units, new_units, fuel_type)
    else
      return nil, nil
    end
  end
end
