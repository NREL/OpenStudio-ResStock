# frozen_string_literal: true

class EPlus
  # Constants
  EMSActuatorElectricEquipmentPower = 'ElectricEquipment', 'Electricity Rate'
  EMSActuatorOtherEquipmentPower = 'OtherEquipment', 'Power Level'
  EMSActuatorPumpMassFlowRate = 'Pump', 'Pump Mass Flow Rate'
  EMSActuatorPumpPressureRise = 'Pump', 'Pump Pressure Rise'
  EMSActuatorScheduleConstantValue = 'Schedule:Constant', 'Schedule Value'
  EMSActuatorSurfaceViewFactorToGround = 'Surface', 'View Factor To Ground'
  EMSActuatorZoneInfiltrationFlowRate = 'Zone Infiltration', 'Air Exchange Flow Rate'
  EMSActuatorZoneMixingFlowRate = 'ZoneMixing', 'Air Exchange Flow Rate'
  EMSIntVarFanMFR = 'Fan Maximum Mass Flow Rate'
  EMSIntVarPumpMFR = 'Pump Maximum Mass Flow Rate'
  FuelTypeElectricity = 'Electricity'
  FuelTypeNaturalGas = 'NaturalGas'
  FuelTypeOil = 'FuelOilNo2'
  FuelTypePropane = 'Propane'
  FuelTypeWoodCord = 'OtherFuel1'
  FuelTypeWoodPellets = 'OtherFuel2'
  FuelTypeCoal = 'Coal'

  def self.fuel_type(hpxml_fuel)
    # Name of fuel used as inputs to E+ objects
    if [HPXML::FuelTypeElectricity].include? hpxml_fuel
      return FuelTypeElectricity
    elsif [HPXML::FuelTypeNaturalGas].include? hpxml_fuel
      return FuelTypeNaturalGas
    elsif [HPXML::FuelTypeOil,
           HPXML::FuelTypeOil1,
           HPXML::FuelTypeOil2,
           HPXML::FuelTypeOil4,
           HPXML::FuelTypeOil5or6,
           HPXML::FuelTypeDiesel,
           HPXML::FuelTypeKerosene].include? hpxml_fuel
      return FuelTypeOil
    elsif [HPXML::FuelTypePropane].include? hpxml_fuel
      return FuelTypePropane
    elsif [HPXML::FuelTypeWoodCord].include? hpxml_fuel
      return FuelTypeWoodCord
    elsif [HPXML::FuelTypeWoodPellets].include? hpxml_fuel
      return FuelTypeWoodPellets
    elsif [HPXML::FuelTypeCoal,
           HPXML::FuelTypeCoalAnthracite,
           HPXML::FuelTypeCoalBituminous,
           HPXML::FuelTypeCoke].include? hpxml_fuel
      return FuelTypeCoal
    else
      fail "Unexpected HPXML fuel '#{hpxml_fuel}'."
    end
  end
end
