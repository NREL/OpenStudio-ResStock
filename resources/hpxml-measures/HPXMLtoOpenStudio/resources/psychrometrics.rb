# frozen_string_literal: true

class Psychrometrics
  def self.H_fg_fT(t)
    '''
    Description:
    ------------
        Calculate the latent heat of vaporization at a given drybulb
        temperature.

        Valid for temperatures between 0 and 200 degC (32 - 392 degF)

    Source:
    -------
        Based on correlation from steam tables - "Introduction to
        Thermodynamics, Classical and Statistical" by Sonntag and Wylen

        H_fg = 2518600 - 2757.1*T (J/kg with T in degC)
             = 2581600 - 2757.1*(T - 32)*5/9 (J/kg with T in degF)
             = 2581600 - 1531.72*T + 49015.1 (J/kg with T in degF)
             = 1083 - 0.6585*T + 21.07 (Btu/lbm with T in degF)

    Inputs:
    -------
        T       float      temperature         (degF)

    Outputs:
    --------
        H_fg    float      latent heat of vaporization (Btu/lbm)
    '''
    h_fg = 1083 - 0.6585 * t + 21.07

    return h_fg
  end

  def self.Psat_fT(tdb)
    '''
    Description:
    ------------
        Calculate the saturation pressure of water vapor at a given temperature

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        Tdb     float      drybulb temperature      (degF)

    Outputs:
    --------
        Psat    float      saturated vapor pressure (psia)
    '''
    c1 = -1.0214165e4
    c2 = -4.8932428
    c3 = -5.3765794e-3
    c4 = 1.9202377e-7
    c5 = 3.5575832e-10
    c6 = -9.0344688e-14
    c7 = 4.1635019
    c8 = -1.0440397e4
    c9 = -1.1294650e1
    c10 = -2.7022355e-2
    c11 = 1.2890360e-5
    c12 = -2.4780681e-9
    c13 = 6.5459673

    t_abs = UnitConversions.convert(tdb, 'F', 'R')
    t_frz_abs = UnitConversions.convert(Liquid.H2O_l.t_frz, 'F', 'R')

    if t_abs < t_frz_abs
      # If below freezing, calculate saturation pressure over ice
      psat = Math.exp(c1 / t_abs + c2 + t_abs * (c3 + t_abs * (c4 + t_abs * (c5 + c6 * t_abs))) + c7 * Math.log(t_abs))
    else
      # If above freezing, calculate saturation pressure over liquid water
      psat = Math.exp(c8 / t_abs + c9 + t_abs * (c10 + t_abs * (c11 + c12 * t_abs)) + c13 * Math.log(t_abs))
    end
    return psat
  end

  def self.Tsat_fP(p)
    '''
    Description:
    ------------
        Calculate the saturation temperature of water vapor at a given pressure

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        P       float      pressure                    (psia)

    Outputs:
    --------
        Tsat    float      saturated vapor temperature (degF)
    '''
    # Initialize
    tsat = 212.0 # (degF)
    tsat1 = tsat # (degF)
    tsat2 = tsat # (degF)

    error = p - self.Psat_fT(tsat) # (psia)
    error1 = error # (psia)
    error2 = error # (psia)

    itmax = 50 # maximum iterations
    cvg = false

    for i in 1..itmax

      error = p - self.Psat_fT(tsat) # (psia)

      tsat, cvg, tsat1, error1, tsat2, error2 = MathTools.Iterate(tsat, error, tsat1, error1, tsat2, error2, i, cvg)

      if cvg
        break
      end

    end

    if not cvg
      puts 'Warning: Tsat_fP failed to converge'
    end

    return tsat
  end

  def self.Tsat_fh_P(h, p)
    '''
    Description:
    ------------
        Calculate the drybulb temperature at saturation a given enthalpy and
        pressure.

    Source:
    -------
        Based on TAIRSAT f77 code in ResAC (Brandemuehl)

    Inputs:
    -------
        h       float      enathalpy           (Btu/lbm)
        P       float      pressure            (psia)

    Outputs:
    --------
        Tdb     float      drybulb temperature (degF)
    '''
    # Initialize
    tdb = 50
    tdb1 = tdb # (degF)
    tdb2 = tdb # (degF)

    error = h - hsat_fT_P(tdb, p) # (Btu/lbm)
    error1 = error
    error2 = error

    itmax = 50 # maximum iterations
    cvg = false

    for i in 1..itmax

      error = h - hsat_fT_P(tdb, p) # (Btu/lbm)

      tdb, cvg, tdb1, error1, tdb2, error2 = MathTools.Iterate(tdb, error, tdb1, error1, tdb2, error2, i, cvg)

      if cvg
        break
      end

    end

    if not cvg
      puts 'Warning: Tsat_fh_P failed to converge'
    end

    return tdb
  end

  def self.rhoD_fT_w_P(tdb, w, p)
    '''
    Description:
    ------------
        Calculate the density of dry air at a given drybulb temperature,
        humidity ratio and pressure.

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        Tdb     float      drybulb temperature   (degF)
        w       float      humidity ratio        (lbm/lbm)
        P       float      pressure              (psia)

    Outputs:
    --------
        rhoD    float      density of dry air    (lbm/ft3)
    '''
    pair = Gas.PsychMassRat * p / (Gas.PsychMassRat + w) # (psia)
    rhoD = UnitConversions.convert(pair, 'psi', 'Btu/ft^3') / Gas.Air.r / UnitConversions.convert(tdb, 'F', 'R') # (lbm/ft3)

    return rhoD
  end

  def self.h_fT_w_SI(tdb, w)
    '''
    Description:
    ------------
        Calculate the enthalpy at a given drybulb temperature
        and humidity ratio.

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        Tdb     float      drybulb temperature   (degC)
        w       float      humidity ratio        (kg/kg)

    Outputs:
    --------
        h       float      enthalpy              (J/kg)
    '''
    h = 1000.0 * (1.006 * tdb + w * (2501.0 + 1.86 * tdb))
    return h
  end

  def self.w_fT_h_SI(tdb, h)
    '''
    Description:
    ------------
        Calculate the humidity ratio at a given drybulb temperature
        and enthalpy.

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        Tdb     float      drybulb temperature  (degC)
        h       float      enthalpy              (J/kg)

    Outputs:
    --------
        w       float      humidity ratio        (kg/kg)
    '''
    w = (h / 1000.0 - 1.006 * tdb) / (2501.0 + 1.86 * tdb)
    return w
  end

  def self.Pstd_fZ(z)
    '''
    Description:
    ------------
        Calculate standard pressure of air at a given altitude

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        Z        float        altitude     (feet)

    Outputs:
    --------
        Pstd    float        barometric pressure (psia)
    '''

    pstd = 14.696 * ((1 - 6.8754e-6 * z)**5.2559)
    return pstd
  end

  def self.Twb_fT_w_P(tdb, w, p)
    '''
    Description:
    ------------
        Calculate the wetbulb temperature at a given drybulb temperature,
        humidity ratio, and pressure.

    Source:
    -------
        Based on WETBULB f77 code in ResAC (Brandemuehl)

        Converted into IP units

    Inputs:
    -------
        Tdb     float      drybulb temperature (degF)
        w       float      humidity ratio      (lbm/lbm)
        P       float      pressure            (psia)

    Outputs:
    --------
        Twb     float      wetbulb temperature (degF)
    '''
    # Initialize
    tboil = self.Tsat_fP(p) # (degF)
    twb = [[tdb, tboil - 0.1].min, 0.0].max # (degF)

    twb1 = twb # (degF)
    twb2 = twb # (degF)

    psat_star = self.Psat_fT(twb) # (psia)
    w_star = w_fP(p, psat_star) # (lbm/lbm)
    w_new = ((Liquid.H2O_l.h_fg - (Liquid.H2O_l.cp - Gas.H2O_v.cp) * twb) * w_star - Gas.Air.cp * (tdb - twb)) / (Liquid.H2O_l.h_fg + Gas.H2O_v.cp * tdb - Liquid.H2O_l.cp * twb) # (lbm/lbm)

    error = w - w_new
    error1 = error
    error2 = error

    itmax = 50 # maximum iterations
    cvg = false

    for i in 1..itmax

      psat_star = self.Psat_fT(twb) # (psia)
      w_star = w_fP(p, psat_star) # (lbm/lbm)
      w_new = ((Liquid.H2O_l.h_fg - (Liquid.H2O_l.cp - Gas.H2O_v.cp) * twb) * w_star - Gas.Air.cp * (tdb - twb)) / (Liquid.H2O_l.h_fg + Gas.H2O_v.cp * tdb - Liquid.H2O_l.cp * twb) # (lbm/lbm)

      error = w - w_new

      twb, cvg, twb1, error1, twb2, error2 = MathTools.Iterate(twb, error, twb1, error1, twb2, error2, i, cvg)

      if cvg
        break
      end
    end

    if not cvg
      puts 'Warning: Twb_fT_w_P failed to converge'
    end

    if twb > tdb
      twb = tdb # (degF)
    end

    return twb
  end

  def self.w_fP(p, pw)
    '''
    Description:
    ------------
        Calculate the humidity ratio at a given pressure and partial pressure.

    Source:
    -------
        Based on HUMRATIO f77 code in ResAC (Brandemuehl)

    Inputs:
    -------
        P       float      pressure              (psia)
        Pw      float      partial pressure      (psia)

    Outputs:
    --------
        w       float      humidity ratio        (lbm/lbm)
    '''
    w = Gas.PsychMassRat * pw / (p - pw)
    return w
  end

  def self.CoilAoFactor(dBin, wBin, p, qdot, cfm, shr)
    '''
    Description:
    ------------
        Find the coil Ao factor at the given incoming air state (entering drybubl and wetbulb) and CFM,
        total capacity and SHR


    Source:
    -------
        EnergyPlus source code

    Inputs:
    -------
        Tdb    float    Entering Dry Bulb (degF)
        Twb    float    Entering Wet Bulb (degF)
        P      float    Barometric pressure (psi)
        Qdot   float    Total capacity of unit (kBtu/h)
        cfm    float    Volumetric flow rate of unit (CFM)
        shr    float    Sensible heat ratio
    Outputs:
    --------
        Ao    float    Coil Ao Factor
    '''

    bf = self.CoilBypassFactor(dBin, wBin, p, qdot, cfm, shr)
    mfr = UnitConversions.convert(self.CalculateMassflowRate(dBin, wBin, p, cfm), 'lbm/min', 'kg/s')

    ntu = -1.0 * Math.log(bf)
    ao = ntu * mfr
    return ao
  end

  def self.CoilBypassFactor(dBin, wBin, p, qdot, cfm, shr)
    '''
    Description:
    ------------
        Find the coil bypass factor at the given incoming air state (entering drybubl and wetbulb) and CFM,
        total capacity and SHR


    Source:
    -------
        EnergyPlus source code

    Inputs:
    -------
        Tdb    float    Entering Dry Bulb (degF)
        Twb    float    Entering Wet Bulb (degF)
        P      float    Barometric pressure (psi)
        Qdot   float    Total capacity of unit (kBtu/h)
        cfm    float    Volumetric flow rate of unit (CFM)
        shr    float    Sensible heat ratio
    Outputs:
    --------
        CBF    float    Coil Bypass Factor
    '''

    mfr = UnitConversions.convert(self.CalculateMassflowRate(dBin, wBin, p, cfm), 'lbm/min', 'kg/s')

    tin = UnitConversions.convert(dBin, 'F', 'C')
    win = w_fT_Twb_P(dBin, wBin, p)
    p = UnitConversions.convert(p, 'psi', 'kPa')

    dH = UnitConversions.convert(qdot, 'kBtu/hr', 'W') / mfr
    hin = h_fT_w_SI(tin, win)
    h_Tin_Wout = hin - (1 - shr) * dH
    wout = w_fT_h_SI(tin, h_Tin_Wout)
    dW = win - wout
    hout = hin - dH
    tout = self.T_fw_h_SI(wout, hout)
    rH_out = self.R_fT_w_P_SI(tout, wout, p)

    if rH_out > 1
      puts 'Error: Conditions passed to CoilBypassFactor result in outlet RH > 100%'
    end

    dT = tin - tout
    m_c = dW / dT

    t_ADP = self.Tdp_fP_w_SI(p, wout) # Initial guess for iteration

    if shr == 1
      w_ADP = w_fT_Twb_P_SI(t_ADP, t_ADP, p)
      h_ADP = h_fT_w_SI(t_ADP, w_ADP)
      bF = (hout - h_ADP) / (hin - h_ADP)
      return [bF, 0.01].max
    end

    cnt = 0
    tol = 1.0
    errorLast = 100
    d_T_ADP = 5.0

    while (cnt < 100) && (tol > 0.001)
      # for i in range(1,itmax+1):

      if cnt > 0
        t_ADP += d_T_ADP
      end

      w_ADP = w_fT_Twb_P_SI(t_ADP, t_ADP, p)

      m = (win - w_ADP) / (tin - t_ADP)
      error = (m - m_c) / m_c

      if (error > 0) && (errorLast < 0)
        d_T_ADP = -1.0 * d_T_ADP / 2.0
      end

      if (error < 0) && (errorLast > 0)
        d_T_ADP = -1.0 * d_T_ADP / 2.0
      end

      errorLast = error
      tol = error.abs.to_f
      cnt += 1
    end

    h_ADP = h_fT_w_SI(t_ADP, w_ADP)

    bF = (hout - h_ADP) / (hin - h_ADP)
    return [bF, 0.01].max
  end

  def self.CalculateMassflowRate(dBin, wBin, p, cfm)
    '''
    Description:
    ------------
        Calculate the mass flow rate at the given incoming air state (entering drybubl and wetbulb) and CFM

    Source:
    -------


    Inputs:
    -------
        Tdb    float    Entering Dry Bulb (degF)
        Twb    float    Entering Wet Bulb (degF)
        P      float    Barometric pressure (psi)
        cfm    float    Volumetric flow rate of unit (CFM)
    Outputs:
    --------
        mfr    float    mass flow rate (lbm/min)
    '''
    win = w_fT_Twb_P(dBin, wBin, p)
    rho_in = rhoD_fT_w_P(dBin, win, p)
    mfr = cfm * rho_in
    return mfr
  end

  def self.T_fw_h_SI(w, h)
    '''
    Description:
    ------------
        Calculate the drybulb temperature at a given humidity ratio
        and enthalpy.

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        w       float      humidity ratio        (kg/kg)
        h       float      enthalpy              (J/kg)

    Outputs:
    --------
        T       float      drybulb temperature  (degC)
    '''

    t = (h / 1000 - w * 2501) / (1.006 + w * 1.86)
    return t
  end

  def self.R_fT_w_P_SI(tdb, w, p)
    '''
    Description:
    ------------
        Calculate the relative humidity at a given drybulb temperature,
        humidity ratio and pressure.

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        Tdb     float      drybulb temperature   (degC)
        w       float      humidity ratio        (g/g)
        P       float      pressure              (kPa)

    Outputs:
    --------
        R       float      relative humidity     (1/1)
    '''
    return self.R_fT_w_P(UnitConversions.convert(tdb, 'C', 'F'), w, UnitConversions.convert(p, 'kPa', 'psi'))
  end

  def self.Tdp_fP_w_SI(p, w)
    '''
    Description:
    ------------
        Calculate the dewpoint temperature at a given pressure
        and humidity ratio.

        There are two available methods:

        CalcMethod == 1: Uses the correlation method from ASHRAE Handbook
        CalcMethod <> 1: Uses the saturation temperature at the partial
                         pressure

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        P       float      pressure              (kPa)
        w       float      humidity ratio        (g/g)

    Outputs:
    --------
        Tdp     float      dewpoint temperature  (degC)
    '''
    return UnitConversions.convert(self.Tdp_fP_w(UnitConversions.convert(p, 'kPa', 'psi'), w), 'F', 'C')
  end

  def self.w_fT_Twb_P_SI(tdb, twb, p)
    '''
    Description:
    ------------
        Calculate the humidity ratio at a given drybulb temperature,
        wetbulb temperature and pressure.

    Source:
    -------
        ASHRAE Handbook 2009

    Inputs:
    -------
        Tdb     float      drybulb temperature   (degC)
        Twb     float      wetbulb temperature   (degC)
        P       float      pressure              (kPa)

    Outputs:
    --------
        w       float      humidity ratio        (g/g)
    '''

    return w_fT_Twb_P(UnitConversions.convert(tdb, 'C', 'F'), UnitConversions.convert(twb, 'C', 'F'), UnitConversions.convert(p, 'kPa', 'psi'))
  end

  def self.w_fT_Twb_P(tdb, twb, p)
    '''
    Description:
    ------------
        Calculate the humidity ratio at a given drybulb temperature,
        wetbulb temperature and pressure.

    Source:
    -------
        ASHRAE Handbook 2009

    Inputs:
    -------
        Tdb     float      drybulb temperature   (degF)
        Twb     float      wetbulb temperature   (degF)
        P       float      pressure              (psia)

    Outputs:
    --------
        w       float      humidity ratio        (lbm/lbm)
    '''
    w_star = w_fP(p, self.Psat_fT(twb))

    w = ((Liquid.H2O_l.h_fg - (Liquid.H2O_l.cp - Gas.H2O_v.cp) * twb) * w_star - Gas.Air.cp * (tdb - twb)) / (Liquid.H2O_l.h_fg + Gas.H2O_v.cp * tdb - Liquid.H2O_l.cp * twb) # (lbm/lbm)

    return w
  end

  def self.R_fT_w_P(tdb, w, p)
    '''
    Description:
    ------------
        Calculate the relative humidity at a given drybulb temperature,
        humidity ratio and pressure.

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        Tdb     float      drybulb temperature   (degF)
        w       float      humidity ratio        (lbm/lbm)
        P       float      pressure              (psia)

    Outputs:
    --------
        R       float      relative humidity     (1/1)
    '''
    pw = self.Pw_fP_w(p, w)
    r = pw / self.Psat_fT(tdb)
    return r
  end

  def self.Pw_fP_w(p, w)
    '''
    Description:
    ------------
        Calculate the partial vapor pressure at a given pressure and
        humidity ratio.

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        P       float      pressure              (psia)
        w       float      humidity ratio        (lbm/lbm)

    Outputs:
    --------
        Pw      float      partial pressure      (psia)
    '''

    pw = p * w / (Gas.PsychMassRat + w)
    return pw
  end

  def self.Tdp_fP_w(p, w)
    '''
    Description:
    ------------
        Calculate the dewpoint temperature at a given pressure
        and humidity ratio.

        There are two available methods:

        CalcMethod == 1: Uses the correlation method from ASHRAE Handbook
        CalcMethod <> 1: Uses the saturation temperature at the partial
                         pressure

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        P       float      pressure              (psia)
        w       float      humidity ratio        (lbm/lbm)

    Outputs:
    --------
        Tdp     float      dewpoint temperature  (degF)
    '''

    calcMethod = 1

    if calcMethod == 1

      c14 = 100.45
      c15 = 33.193
      c16 = 2.319
      c17 = 0.17074
      c18 = 1.2063

      pw = self.Pw_fP_w(p, w) # (psia)
      alpha = Math.log(pw)
      tdp1 = c14 + c15 * alpha + c16 * alpha**2 + c17 * alpha**3 + c18 * pw**0.1984
      tdp2 = 90.12 + 26.142 * alpha + 0.8927 * alpha**2
      if tdp1 >= Liquid.H2O_l.t_frz
        tdp = tdp1
      else
        tdp = tdp2
      end

    else

      # based on DEWPOINT f77 code in ResAC (Brandemuehl)
      if w < Constants.small
        tdp = -999.0
      else
        pw = self.Pw_fP_w(p, w)
        tdp = self.Tsat_fP(pw)
      end

    end
    return tdp
  end

  def self.CalculateSHR(dBin, wBin, p, q, cfm, ao)
    '''
    Description:
    ------------
        Calculate the coil SHR at the given incoming air state, CFM, total capacity, and coil
        Ao factor

    Source:
    -------
        EnergyPlus source code

    Inputs:
    -------
        Tdb    float    Entering Dry Bulb (degF)
        Twb    float    Entering Wet Bulb (degF)
        P      float    Barometric pressure (psi)
        Q      float    Total capacity of unit (kBtu/h)
        cfm    float    Volumetric flow rate of unit (CFM)
        Ao     float    Coil Ao factor (=UA/Cp - IN SI UNITS)
    Outputs:
    --------
        SHR    float    Sensible Heat Ratio
    '''

    mfr = UnitConversions.convert(self.CalculateMassflowRate(dBin, wBin, p, cfm), 'lbm/min', 'kg/s')
    bf = Math.exp(-1.0 * ao / mfr)

    win = w_fT_Twb_P(dBin, wBin, p)
    p = UnitConversions.convert(p, 'psi', 'kPa')
    tin = UnitConversions.convert(dBin, 'F', 'C')
    hin = h_fT_w_SI(tin, win)
    dH = UnitConversions.convert(q, 'kBtu/hr', 'W') / mfr
    h_ADP = hin - dH / (1 - bf)

    # T_ADP = self.Tsat_fh_P_SI(H_ADP, P)
    # W_ADP = self.w_fT_h_SI(T_ADP, H_ADP)

    # Initialize
    t_ADP = self.Tdp_fP_w_SI(p, win)
    t_ADP_1 = t_ADP # (degC)
    t_ADP_2 = t_ADP # (degC)
    w_ADP = w_fT_R_P_SI(t_ADP, 1.0, p)
    error = h_ADP - h_fT_w_SI(t_ADP, w_ADP)
    error1 = error
    error2 = error

    itmax = 50 # maximum iterations
    cvg = false

    (1...itmax + 1).each do |i|
      w_ADP = w_fT_R_P_SI(t_ADP, 1.0, p)
      error = h_ADP - h_fT_w_SI(t_ADP, w_ADP)

      t_ADP, cvg, t_ADP_1, error1, t_ADP_2, error2 = MathTools.Iterate(t_ADP, error, t_ADP_1, error1, t_ADP_2, error2, i, cvg)

      if cvg
        break
      end
    end

    if not cvg
      puts 'Warning: Tsat_fh_P failed to converge'
    end

    h_Tin_Wadp = h_fT_w_SI(tin, w_ADP)

    if (hin - h_ADP != 0)
      shr = [(h_Tin_Wadp - h_ADP) / (hin - h_ADP), 1.0].min
    else
      shr = 1
    end
    return shr
  end

  def self.w_fT_R_P(tdb, r, p)
    '''
    Description:
    ------------
        Calculate the humidity ratio at a given drybulb temperature,
        relative humidity and pressure.

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        Tdb     float      drybulb temperature   (degF)
        R       float      relative humidity     (1/1)
        P       float      pressure              (psia)

    Outputs:
    --------
        w       float      humidity ratio        (lbm/lbm)
    '''
    pws = self.Psat_fT(tdb)
    pw = r * pws
    w = 0.62198 * pw / (p - pw)

    return w
  end

  def self.w_fT_R_P_SI(tdb, r, p)
    '''
    Description:
    ------------
        Calculate the humidity ratio at a given drybulb temperature,
        relative humidity and pressure.

    Source:
    -------
        2009 ASHRAE Handbook

    Inputs:
    -------
        Tdb     float      drybulb temperature   (degC)
        R       float      relative humidity     (1/1)
        P       float      pressure              (kPa)

    Outputs:
    --------
        w       float      humidity ratio        (g/g)
    '''
    pws = UnitConversions.convert(self.Psat_fT(UnitConversions.convert(tdb, 'C', 'F')), 'psi', 'kPa')
    pw = r * pws
    w = 0.62198 * pw / (p - pw)
    return w
  end

  def self.Twb_fT_R_P(tdb, r, p)
    '''
    Description:
    ------------
        Calculate the wetbulb temperature at a given drybulb temperature,
        relative humidity, and pressure.

    Source:
    -------
        None (calls other pyschrometric functions)

    Inputs:
    -------
        Tdb    float    drybulb temperature    (degF)
        R      float    relative humidity      (1/1)
        P      float    pressure               (psia)

    Output:
    ------
        Twb    float    wetbulb temperautre    (degF)
    '''

    w = w_fT_R_P(tdb, r, p)
    twb = self.Twb_fT_w_P(tdb, w, p)
    return twb
  end
end
