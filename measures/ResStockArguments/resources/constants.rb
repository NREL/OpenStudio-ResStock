# frozen_string_literal: true

class Constants
  def self.excludes
    # don't make these BuildResidentialHPXML arguments into ResStockArguments arguments
    return ['hpxml_path',
            'software_program_used',
            'software_program_version',
            'setpoint_heating_weekday',
            'setpoint_heating_weekend',
            'setpoint_cooling_weekday',
            'setpoint_cooling_weekend',
            'geometry_has_flue_or_chimney',
            'heating_system_airflow_defect_ratio',
            'cooling_system_airflow_defect_ratio',
            'cooling_system_charge_defect_ratio',
            'heat_pump_airflow_defect_ratio',
            'heat_pump_charge_defect_ratio',
            'plug_loads_television_annual_kwh',
            'plug_loads_television_usage_multiplier']
  end
end
