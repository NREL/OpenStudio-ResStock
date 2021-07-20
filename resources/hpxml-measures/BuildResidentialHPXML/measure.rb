# frozen_string_literal: true

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'openstudio'
require 'oga'
require 'csv'

require_relative 'resources/constants'
require_relative 'resources/geometry'
require_relative 'resources/schedules'

require_relative '../HPXMLtoOpenStudio/resources/constants'
require_relative '../HPXMLtoOpenStudio/resources/constructions'
require_relative '../HPXMLtoOpenStudio/resources/geometry'
require_relative '../HPXMLtoOpenStudio/resources/hpxml'
require_relative '../HPXMLtoOpenStudio/resources/hvac'
require_relative '../HPXMLtoOpenStudio/resources/lighting'
require_relative '../HPXMLtoOpenStudio/resources/location'
require_relative '../HPXMLtoOpenStudio/resources/materials'
require_relative '../HPXMLtoOpenStudio/resources/meta_measure'
require_relative '../HPXMLtoOpenStudio/resources/psychrometrics'
require_relative '../HPXMLtoOpenStudio/resources/schedules'
require_relative '../HPXMLtoOpenStudio/resources/unit_conversions'
require_relative '../HPXMLtoOpenStudio/resources/validator'
require_relative '../HPXMLtoOpenStudio/resources/version'
require_relative '../HPXMLtoOpenStudio/resources/xmlhelper'

# start the measure
class BuildResidentialHPXML < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'HPXML Builder'
  end

  # human readable description
  def description
    return 'Builds a residential HPXML file.'
  end

  # human readable description of modeling approach
  def modeler_description
    return ''
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('hpxml_path', true)
    arg.setDisplayName('HPXML File Path')
    arg.setDescription('Absolute/relative path of the HPXML file.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('software_program_used', false)
    arg.setDisplayName('Software Program Used')
    arg.setDescription('The name of the software program used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('software_program_version', false)
    arg.setDisplayName('Software Program Version')
    arg.setDescription('The version of the software program used.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('simulation_control_timestep', false)
    arg.setDisplayName('Simulation Control: Timestep')
    arg.setUnits('min')
    arg.setDescription('Value must be a divisor of 60.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('simulation_control_run_period_begin_month', false)
    arg.setDisplayName('Simulation Control: Run Period Begin Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the starting month number (1 = January, 2 = February, etc.) for the annual run period desired.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('simulation_control_run_period_begin_day_of_month', false)
    arg.setDisplayName('Simulation Control: Run Period Begin Day of Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the starting day of the starting month (must be valid for month) for the annual run period desired.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('simulation_control_run_period_end_month', false)
    arg.setDisplayName('Simulation Control: Run Period End Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the end month number (1 = January, 2 = February, etc.) for the annual run period desired.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('simulation_control_run_period_end_day_of_month', false)
    arg.setDisplayName('Simulation Control: Run Period End Day of Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the ending day of the ending month (must be valid for month) for the annual run period desired.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('simulation_control_run_period_calendar_year', false)
    arg.setDisplayName('Simulation Control: Run Period Calendar Year')
    arg.setUnits('year')
    arg.setDescription('This numeric field should contain the calendar year that determines the start day of week. If you are running simulations using AMY weather files, the value entered for calendar year will not be used; it will be overridden by the actual year found in the AMY weather file.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('simulation_control_daylight_saving_enabled', false)
    arg.setDisplayName('Simulation Control: Daylight Saving Enabled')
    arg.setDescription('Whether to use daylight saving.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('simulation_control_daylight_saving_begin_month', false)
    arg.setDisplayName('Simulation Control: Daylight Saving Begin Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the starting month number (1 = January, 2 = February, etc.) for the annual daylight saving period desired.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('simulation_control_daylight_saving_begin_day_of_month', false)
    arg.setDisplayName('Simulation Control: Daylight Saving Begin Day of Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the starting day of the starting month (must be valid for month) for the daylight saving period desired.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('simulation_control_daylight_saving_end_month', false)
    arg.setDisplayName('Simulation Control: Daylight Saving End Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the end month number (1 = January, 2 = February, etc.) for the daylight saving period desired.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('simulation_control_daylight_saving_end_day_of_month', false)
    arg.setDisplayName('Simulation Control: Daylight Saving End Day of Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the ending day of the ending month (must be valid for month) for the daylight saving period desired.')
    args << arg

    schedules_type_choices = OpenStudio::StringVector.new
    schedules_type_choices << 'default'
    schedules_type_choices << 'stochastic'
    schedules_type_choices << 'user-specified'

    arg = OpenStudio::Measure::OSArgument.makeChoiceArgument('schedules_type', schedules_type_choices, true)
    arg.setDisplayName('Schedules: Type')
    arg.setDescription("The type of occupant-related schedules to use. Schedules corresponding to 'default' are average (e.g., Building America). Schedules corresponding to 'stochastic' are generated using time-inhomogeneous Markov chains derived from American Time Use Survey data, and supplemented with sampling duration and power level from NEEA RBSA data as well as DHW draw duration and flow rate from Aquacraft/AWWA data.")
    arg.setDefaultValue('default')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('schedules_path', false)
    arg.setDisplayName('Schedules: Path')
    arg.setDescription('Absolute (or relative) path of the csv file containing user-specified occupancy schedules.')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('schedules_vacancy_begin_month', false)
    arg.setDisplayName('Schedules: Vacancy Start Begin Month')
    arg.setUnits('#')
    arg.setDescription("This numeric field should contain the starting month number (1 = January, 2 = February, etc.) for the vacancy period desired. Only applies if the schedules type is 'stochastic'.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('schedules_vacancy_begin_day_of_month', false)
    arg.setDisplayName('Schedules: Vacancy Begin Day of Month')
    arg.setUnits('#')
    arg.setDescription("This numeric field should contain the starting day of the starting month (must be valid for month) for the vacancy period desired. Only applies if the schedules type is 'stochastic'.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('schedules_vacancy_end_month', false)
    arg.setDisplayName('Schedules: Vacancy Start End Month')
    arg.setUnits('#')
    arg.setDescription("This numeric field should contain the end month number (1 = January, 2 = February, etc.) for the vacancy period desired. Only applies if the schedules type is 'stochastic'.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('schedules_vacancy_end_day_of_month', false)
    arg.setDisplayName('Schedules: Vacancy End Day of Month')
    arg.setUnits('#')
    arg.setDescription("This numeric field should contain the ending day of the ending month (must be valid for month) for the vacancy period desired. Only applies if the schedules type is 'stochastic'.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('schedules_random_seed', false)
    arg.setDisplayName('Schedules: Random Seed')
    arg.setUnits('#')
    arg.setDescription("This numeric field is the seed for the random number generator. Only applies if the schedules type is 'stochastic'.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('weather_station_epw_filepath', true)
    arg.setDisplayName('EnergyPlus Weather (EPW) Filepath')
    arg.setDescription('Path of the EPW file.')
    arg.setDefaultValue('USA_CO_Denver.Intl.AP.725650_TMY3.epw')
    args << arg

    site_type_choices = OpenStudio::StringVector.new
    site_type_choices << HPXML::SiteTypeSuburban
    site_type_choices << HPXML::SiteTypeUrban
    site_type_choices << HPXML::SiteTypeRural

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('site_type', site_type_choices, false)
    arg.setDisplayName('Site: Type')
    arg.setDescription('The type of site.')
    args << arg

    unit_type_choices = OpenStudio::StringVector.new
    unit_type_choices << HPXML::ResidentialTypeSFD
    unit_type_choices << HPXML::ResidentialTypeSFA
    unit_type_choices << HPXML::ResidentialTypeApartment

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_unit_type', unit_type_choices, true)
    arg.setDisplayName('Geometry: Unit Type')
    arg.setDescription('The type of unit.')
    arg.setDefaultValue(HPXML::ResidentialTypeSFD)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_cfa', true)
    arg.setDisplayName('Geometry: Conditioned Floor Area')
    arg.setUnits('ft^2')
    arg.setDescription('The total floor area of the conditioned space (including any conditioned basement floor area).')
    arg.setDefaultValue(2000.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('geometry_num_floors_above_grade', true)
    arg.setDisplayName('Geometry: Number of Floors')
    arg.setUnits('#')
    arg.setDescription("The number of floors above grade (in the unit if #{HPXML::ResidentialTypeSFD} or #{HPXML::ResidentialTypeSFA}, and in the building if #{HPXML::ResidentialTypeApartment}). Conditioned attics are included.")
    arg.setDefaultValue(2)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_wall_height', true)
    arg.setDisplayName('Geometry: Average Wall Height')
    arg.setUnits('ft')
    arg.setDescription('The average height of the walls.')
    arg.setDefaultValue(8.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_orientation', true)
    arg.setDisplayName('Geometry: Orientation')
    arg.setUnits('degrees')
    arg.setDescription("The unit's orientation is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).")
    arg.setDefaultValue(180.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_aspect_ratio', true)
    arg.setDisplayName('Geometry: Aspect Ratio')
    arg.setUnits('FB/LR')
    arg.setDescription('The ratio of the front/back wall length to the left/right wall length, excluding any protruding garage wall area.')
    arg.setDefaultValue(2.0)
    args << arg

    corridor_position_choices = OpenStudio::StringVector.new
    corridor_position_choices << 'Double-Loaded Interior'
    corridor_position_choices << 'Single Exterior (Front)'
    corridor_position_choices << 'Double Exterior'
    corridor_position_choices << 'None'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_corridor_position', corridor_position_choices, true)
    arg.setDisplayName('Geometry: Corridor Position')
    arg.setDescription("The position of the corridor. Only applies to #{HPXML::ResidentialTypeSFA} and #{HPXML::ResidentialTypeApartment} units. Exterior corridors are shaded, but not enclosed. Interior corridors are enclosed and conditioned.")
    arg.setDefaultValue('Double-Loaded Interior')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_corridor_width', true)
    arg.setDisplayName('Geometry: Corridor Width')
    arg.setUnits('ft')
    arg.setDescription("The width of the corridor. Only applies to #{HPXML::ResidentialTypeApartment} units.")
    arg.setDefaultValue(10.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_inset_width', true)
    arg.setDisplayName('Geometry: Inset Width')
    arg.setUnits('ft')
    arg.setDescription("The width of the inset. Only applies to #{HPXML::ResidentialTypeApartment} units.")
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_inset_depth', true)
    arg.setDisplayName('Geometry: Inset Depth')
    arg.setUnits('ft')
    arg.setDescription("The depth of the inset. Only applies to #{HPXML::ResidentialTypeApartment} units.")
    arg.setDefaultValue(0.0)
    args << arg

    inset_position_choices = OpenStudio::StringVector.new
    inset_position_choices << 'Right'
    inset_position_choices << 'Left'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_inset_position', inset_position_choices, true)
    arg.setDisplayName('Geometry: Inset Position')
    arg.setDescription("The position of the inset. Only applies to #{HPXML::ResidentialTypeApartment} units.")
    arg.setDefaultValue('Right')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_balcony_depth', true)
    arg.setDisplayName('Geometry: Balcony Depth')
    arg.setUnits('ft')
    arg.setDescription("The depth of the balcony. Only applies to #{HPXML::ResidentialTypeApartment} units.")
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_garage_width', true)
    arg.setDisplayName('Geometry: Garage Width')
    arg.setUnits('ft')
    arg.setDescription("The width of the garage. Enter zero for no garage. Only applies to #{HPXML::ResidentialTypeSFD} units.")
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_garage_depth', true)
    arg.setDisplayName('Geometry: Garage Depth')
    arg.setUnits('ft')
    arg.setDescription("The depth of the garage. Only applies to #{HPXML::ResidentialTypeSFD} units.")
    arg.setDefaultValue(20.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_garage_protrusion', true)
    arg.setDisplayName('Geometry: Garage Protrusion')
    arg.setUnits('frac')
    arg.setDescription("The fraction of the garage that is protruding from the living space. Only applies to #{HPXML::ResidentialTypeSFD} units.")
    arg.setDefaultValue(0.0)
    args << arg

    garage_position_choices = OpenStudio::StringVector.new
    garage_position_choices << 'Right'
    garage_position_choices << 'Left'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_garage_position', garage_position_choices, true)
    arg.setDisplayName('Geometry: Garage Position')
    arg.setDescription("The position of the garage. Only applies to #{HPXML::ResidentialTypeSFD} units.")
    arg.setDefaultValue('Right')
    args << arg

    foundation_type_choices = OpenStudio::StringVector.new
    foundation_type_choices << HPXML::FoundationTypeSlab
    foundation_type_choices << HPXML::FoundationTypeCrawlspaceVented
    foundation_type_choices << HPXML::FoundationTypeCrawlspaceUnvented
    foundation_type_choices << HPXML::FoundationTypeBasementUnconditioned
    foundation_type_choices << HPXML::FoundationTypeBasementConditioned
    foundation_type_choices << HPXML::FoundationTypeAmbient

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_foundation_type', foundation_type_choices, true)
    arg.setDisplayName('Geometry: Foundation Type')
    arg.setDescription('The foundation type of the building.')
    arg.setDefaultValue(HPXML::FoundationTypeSlab)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_foundation_height', true)
    arg.setDisplayName('Geometry: Foundation Height')
    arg.setUnits('ft')
    arg.setDescription('The height of the foundation (e.g., 3ft for crawlspace, 8ft for basement). Only applies to basements/crawlspaces.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_foundation_height_above_grade', true)
    arg.setDisplayName('Geometry: Foundation Height Above Grade')
    arg.setUnits('ft')
    arg.setDescription('The depth above grade of the foundation wall. Only applies to basements/crawlspaces.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_rim_joist_height', true)
    arg.setDisplayName('Geometry: Rim Joist Height')
    arg.setUnits('in')
    arg.setDescription('The height of the rim joists. Only applies to basements/crawlspaces.')
    arg.setDefaultValue(9.25)
    args << arg

    roof_type_choices = OpenStudio::StringVector.new
    roof_type_choices << 'gable'
    roof_type_choices << 'hip'
    roof_type_choices << 'flat'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_roof_type', roof_type_choices, true)
    arg.setDisplayName('Geometry: Roof Type')
    arg.setDescription("The roof type of the building. Assumed flat for #{HPXML::ResidentialTypeApartment} units.")
    arg.setDefaultValue('gable')
    args << arg

    roof_pitch_choices = OpenStudio::StringVector.new
    roof_pitch_choices << '1:12'
    roof_pitch_choices << '2:12'
    roof_pitch_choices << '3:12'
    roof_pitch_choices << '4:12'
    roof_pitch_choices << '5:12'
    roof_pitch_choices << '6:12'
    roof_pitch_choices << '7:12'
    roof_pitch_choices << '8:12'
    roof_pitch_choices << '9:12'
    roof_pitch_choices << '10:12'
    roof_pitch_choices << '11:12'
    roof_pitch_choices << '12:12'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_roof_pitch', roof_pitch_choices, true)
    arg.setDisplayName('Geometry: Roof Pitch')
    arg.setDescription('The roof pitch of the attic. Ignored if the building has a flat roof.')
    arg.setDefaultValue('6:12')
    args << arg

    attic_type_choices = OpenStudio::StringVector.new
    attic_type_choices << HPXML::AtticTypeVented
    attic_type_choices << HPXML::AtticTypeUnvented
    attic_type_choices << HPXML::AtticTypeConditioned

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_attic_type', attic_type_choices, true)
    arg.setDisplayName('Geometry: Attic Type')
    arg.setDescription('The attic type of the building. Ignored if the building has a flat roof.')
    arg.setDefaultValue(HPXML::AtticTypeVented)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('geometry_eaves_depth', true)
    arg.setDisplayName('Geometry: Eaves Depth')
    arg.setUnits('ft')
    arg.setDescription('The eaves depth of the roof.')
    arg.setDefaultValue(2.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('geometry_num_bedrooms', true)
    arg.setDisplayName('Geometry: Number of Bedrooms')
    arg.setUnits('#')
    arg.setDescription('Specify the number of bedrooms. Used to determine the energy usage of appliances and plug loads, hot water usage, etc.')
    arg.setDefaultValue(3)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('geometry_num_bathrooms', true)
    arg.setDisplayName('Geometry: Number of Bathrooms')
    arg.setUnits('#')
    arg.setDescription('Specify the number of bathrooms.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('geometry_num_occupants', true)
    arg.setDisplayName('Geometry: Number of Occupants')
    arg.setUnits('#')
    arg.setDescription("Specify the number of occupants. A value of '#{Constants.Auto}' will calculate the average number of occupants from the number of bedrooms. Used to specify the internal gains from people only.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('geometry_has_flue_or_chimney', true)
    arg.setDisplayName('Geometry: Has Flue or Chimney')
    arg.setDescription('Whether there is a flue or chimney.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    level_choices = OpenStudio::StringVector.new
    level_choices << 'Bottom'
    level_choices << 'Middle'
    level_choices << 'Top'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_level', level_choices, false)
    arg.setDisplayName('Geometry: Level')
    arg.setDescription("The level of the #{HPXML::ResidentialTypeApartment} unit.")
    args << arg

    horizontal_location_choices = OpenStudio::StringVector.new
    horizontal_location_choices << 'None'
    horizontal_location_choices << 'Left'
    horizontal_location_choices << 'Middle'
    horizontal_location_choices << 'Right'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('geometry_horizontal_location', horizontal_location_choices, false)
    arg.setDisplayName('Geometry: Horizontal Location')
    arg.setDescription("The horizontal location of the #{HPXML::ResidentialTypeSFA} or #{HPXML::ResidentialTypeApartment} unit when viewing the front of the building.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('geometry_building_num_units', false)
    arg.setDisplayName('Geometry: Building Number of Units')
    arg.setUnits('#')
    arg.setDescription("The number of units in the building. This is required for #{HPXML::ResidentialTypeSFA} and #{HPXML::ResidentialTypeApartment} units.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('geometry_building_num_bedrooms', false)
    arg.setDisplayName('Geometry: Building Number of Bedrooms')
    arg.setUnits('#')
    arg.setDescription("The number of bedrooms in the building. This is required for #{HPXML::ResidentialTypeSFA} and #{HPXML::ResidentialTypeApartment} units with shared PV systems.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('floor_assembly_r', true)
    arg.setDisplayName('Floor: Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value for the floor (foundation ceiling). Ignored if the building has a slab foundation.')
    arg.setDefaultValue(30)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('foundation_wall_insulation_r', true)
    arg.setDisplayName('Foundation: Wall Insulation Nominal R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Nominal R-value for the foundation wall insulation. Only applies to basements/crawlspaces.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('foundation_wall_insulation_distance_to_top', true)
    arg.setDisplayName('Foundation: Wall Insulation Distance To Top')
    arg.setUnits('ft')
    arg.setDescription('The distance from the top of the foundation wall to the top of the foundation wall insulation. Only applies to basements/crawlspaces.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('foundation_wall_insulation_distance_to_bottom', true)
    arg.setDisplayName('Foundation: Wall Insulation Distance To Bottom')
    arg.setUnits('ft')
    arg.setDescription("The distance from the top of the foundation wall to the bottom of the foundation wall insulation. Only applies to basements/crawlspaces. A value of '#{Constants.Auto}' will use the same height as the foundation.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('foundation_wall_assembly_r', false)
    arg.setDisplayName('Foundation: Wall Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value for the foundation walls. Only applies to basements/crawlspaces. If provided, overrides the previous foundation wall insulation inputs.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('foundation_wall_thickness', true)
    arg.setDisplayName('Foundation: Wall Thickness')
    arg.setDescription('The thickness of the foundation wall.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('rim_joist_assembly_r', true)
    arg.setDisplayName('Rim Joist: Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value for the rim joists. Only applies to basements/crawlspaces.')
    arg.setDefaultValue(23)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('slab_perimeter_insulation_r', true)
    arg.setDisplayName('Slab: Perimeter Insulation Nominal R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Nominal R-value of the vertical slab perimeter insulation. Applies to slab-on-grade foundations and basement/crawlspace floors.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('slab_perimeter_depth', true)
    arg.setDisplayName('Slab: Perimeter Insulation Depth')
    arg.setUnits('ft')
    arg.setDescription('Depth from grade to bottom of vertical slab perimeter insulation. Applies to slab-on-grade foundations and basement/crawlspace floors.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('slab_under_insulation_r', true)
    arg.setDisplayName('Slab: Under Slab Insulation Nominal R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Nominal R-value of the horizontal under slab insulation. Applies to slab-on-grade foundations and basement/crawlspace floors.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('slab_under_width', true)
    arg.setDisplayName('Slab: Under Slab Insulation Width')
    arg.setUnits('ft')
    arg.setDescription('Width from slab edge inward of horizontal under-slab insulation. Enter 999 to specify that the under slab insulation spans the entire slab. Applies to slab-on-grade foundations and basement/crawlspace floors.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('slab_thickness', true)
    arg.setDisplayName('Slab: Thickness')
    arg.setDescription('The thickness of the slab.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('slab_carpet_fraction', true)
    arg.setDisplayName('Slab: Carpet Fraction')
    arg.setUnits('Frac')
    arg.setDescription('Fraction of the slab floor area that is carpeted.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('slab_carpet_r', true)
    arg.setDisplayName('Slab: Carpet R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('R-value of the slab carpet.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_assembly_r', true)
    arg.setDisplayName('Ceiling: Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value for the ceiling (attic floor).')
    arg.setDefaultValue(30)
    args << arg

    roof_material_type_choices = OpenStudio::StringVector.new
    roof_material_type_choices << HPXML::RoofTypeAsphaltShingles
    roof_material_type_choices << HPXML::RoofTypeConcrete
    roof_material_type_choices << HPXML::RoofTypeCool
    roof_material_type_choices << HPXML::RoofTypeClayTile
    roof_material_type_choices << HPXML::RoofTypeEPS
    roof_material_type_choices << HPXML::RoofTypeMetal
    roof_material_type_choices << HPXML::RoofTypePlasticRubber
    roof_material_type_choices << HPXML::RoofTypeShingles
    roof_material_type_choices << HPXML::RoofTypeWoodShingles

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('roof_material_type', roof_material_type_choices, false)
    arg.setDisplayName('Roof: Material Type')
    arg.setDescription('The material type of the roof.')
    args << arg

    color_choices = OpenStudio::StringVector.new
    color_choices << HPXML::ColorDark
    color_choices << HPXML::ColorLight
    color_choices << HPXML::ColorMedium
    color_choices << HPXML::ColorMediumDark
    color_choices << HPXML::ColorReflective

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('roof_color', color_choices, true)
    arg.setDisplayName('Roof: Color')
    arg.setDescription('The color of the roof.')
    arg.setDefaultValue(HPXML::ColorMedium)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('roof_assembly_r', true)
    arg.setDisplayName('Roof: Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value of the roof.')
    arg.setDefaultValue(2.3)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('roof_radiant_barrier', true)
    arg.setDisplayName('Roof: Has Radiant Barrier')
    arg.setDescription('Specifies whether the attic has a radiant barrier.')
    arg.setDefaultValue(false)
    args << arg

    roof_radiant_barrier_grade_choices = OpenStudio::StringVector.new
    roof_radiant_barrier_grade_choices << '1'
    roof_radiant_barrier_grade_choices << '2'
    roof_radiant_barrier_grade_choices << '3'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('roof_radiant_barrier_grade', roof_radiant_barrier_grade_choices, true)
    arg.setDisplayName('Roof: Radiant Barrier Grade')
    arg.setDescription('The grade of the radiant barrier, if it exists.')
    arg.setDefaultValue('1')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_front_distance', true)
    arg.setDisplayName('Neighbor: Front Distance')
    arg.setUnits('ft')
    arg.setDescription('The minimum distance between the simulated unit and the neighboring building to the front (not including eaves). A value of zero indicates no neighbors.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_back_distance', true)
    arg.setDisplayName('Neighbor: Back Distance')
    arg.setUnits('ft')
    arg.setDescription('The minimum distance between the simulated unit and the neighboring building to the back (not including eaves). A value of zero indicates no neighbors.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_left_distance', true)
    arg.setDisplayName('Neighbor: Left Distance')
    arg.setUnits('ft')
    arg.setDescription('The minimum distance between the simulated unit and the neighboring building to the left (not including eaves). A value of zero indicates no neighbors.')
    arg.setDefaultValue(10.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('neighbor_right_distance', true)
    arg.setDisplayName('Neighbor: Right Distance')
    arg.setUnits('ft')
    arg.setDescription('The minimum distance between the simulated unit and the neighboring building to the right (not including eaves). A value of zero indicates no neighbors.')
    arg.setDefaultValue(10.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('neighbor_front_height', true)
    arg.setDisplayName('Neighbor: Front Height')
    arg.setUnits('ft')
    arg.setDescription("The height of the neighboring building to the front. A value of '#{Constants.Auto}' will use the same height as this building.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('neighbor_back_height', true)
    arg.setDisplayName('Neighbor: Back Height')
    arg.setUnits('ft')
    arg.setDescription("The height of the neighboring building to the back. A value of '#{Constants.Auto}' will use the same height as this building.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('neighbor_left_height', true)
    arg.setDisplayName('Neighbor: Left Height')
    arg.setUnits('ft')
    arg.setDescription("The height of the neighboring building to the left. A value of '#{Constants.Auto}' will use the same height as this building.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('neighbor_right_height', true)
    arg.setDisplayName('Neighbor: Right Height')
    arg.setUnits('ft')
    arg.setDescription("The height of the neighboring building to the right. A value of '#{Constants.Auto}' will use the same height as this building.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    wall_type_choices = OpenStudio::StringVector.new
    wall_type_choices << HPXML::WallTypeWoodStud
    wall_type_choices << HPXML::WallTypeCMU
    wall_type_choices << HPXML::WallTypeDoubleWoodStud
    wall_type_choices << HPXML::WallTypeICF
    wall_type_choices << HPXML::WallTypeLog
    wall_type_choices << HPXML::WallTypeSIP
    wall_type_choices << HPXML::WallTypeConcrete
    wall_type_choices << HPXML::WallTypeSteelStud
    wall_type_choices << HPXML::WallTypeStone
    wall_type_choices << HPXML::WallTypeStrawBale
    wall_type_choices << HPXML::WallTypeBrick

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('wall_type', wall_type_choices, true)
    arg.setDisplayName('Walls: Type')
    arg.setDescription('The type of exterior walls.')
    arg.setDefaultValue(HPXML::WallTypeWoodStud)
    args << arg

    wall_siding_type_choices = OpenStudio::StringVector.new
    wall_siding_type_choices << HPXML::SidingTypeAluminum
    wall_siding_type_choices << HPXML::SidingTypeAsbestos
    wall_siding_type_choices << HPXML::SidingTypeBrick
    wall_siding_type_choices << HPXML::SidingTypeCompositeShingle
    wall_siding_type_choices << HPXML::SidingTypeFiberCement
    wall_siding_type_choices << HPXML::SidingTypeMasonite
    wall_siding_type_choices << HPXML::SidingTypeNone
    wall_siding_type_choices << HPXML::SidingTypeStucco
    wall_siding_type_choices << HPXML::SidingTypeSyntheticStucco
    wall_siding_type_choices << HPXML::SidingTypeVinyl
    wall_siding_type_choices << HPXML::SidingTypeWood

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('wall_siding_type', wall_siding_type_choices, false)
    arg.setDisplayName('Wall: Siding Type')
    arg.setDescription('The siding type of the exterior walls. Also applies to rim joists.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('wall_color', color_choices, true)
    arg.setDisplayName('Wall: Color')
    arg.setDescription('The color of the exterior walls. Also applies to rim joists.')
    arg.setDefaultValue(HPXML::ColorMedium)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('wall_assembly_r', true)
    arg.setDisplayName('Walls: Assembly R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Assembly R-value of the exterior walls.')
    arg.setDefaultValue(13)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_front_wwr', true)
    arg.setDisplayName('Windows: Front Window-to-Wall Ratio')
    arg.setDescription("The ratio of window area to wall area for the unit's front facade. Enter 0 if specifying Front Window Area instead.")
    arg.setDefaultValue(0.18)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_back_wwr', true)
    arg.setDisplayName('Windows: Back Window-to-Wall Ratio')
    arg.setDescription("The ratio of window area to wall area for the unit's back facade. Enter 0 if specifying Back Window Area instead.")
    arg.setDefaultValue(0.18)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_left_wwr', true)
    arg.setDisplayName('Windows: Left Window-to-Wall Ratio')
    arg.setDescription("The ratio of window area to wall area for the unit's left facade (when viewed from the front). Enter 0 if specifying Left Window Area instead.")
    arg.setDefaultValue(0.18)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_right_wwr', true)
    arg.setDisplayName('Windows: Right Window-to-Wall Ratio')
    arg.setDescription("The ratio of window area to wall area for the unit's right facade (when viewed from the front). Enter 0 if specifying Right Window Area instead.")
    arg.setDefaultValue(0.18)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_area_front', true)
    arg.setDisplayName('Windows: Front Window Area')
    arg.setDescription("The amount of window area on the unit's front facade. Enter 0 if specifying Front Window-to-Wall Ratio instead.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_area_back', true)
    arg.setDisplayName('Windows: Back Window Area')
    arg.setDescription("The amount of window area on the unit's back facade. Enter 0 if specifying Back Window-to-Wall Ratio instead.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_area_left', true)
    arg.setDisplayName('Windows: Left Window Area')
    arg.setDescription("The amount of window area on the unit's left facade (when viewed from the front). Enter 0 if specifying Left Window-to-Wall Ratio instead.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_area_right', true)
    arg.setDisplayName('Windows: Right Window Area')
    arg.setDescription("The amount of window area on the unit's right facade (when viewed from the front). Enter 0 if specifying Right Window-to-Wall Ratio instead.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_aspect_ratio', true)
    arg.setDisplayName('Windows: Aspect Ratio')
    arg.setDescription('Ratio of window height to width.')
    arg.setDefaultValue(1.333)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_fraction_operable', false)
    arg.setDisplayName('Windows: Fraction Operable')
    arg.setDescription('Fraction of windows that are operable.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_ufactor', true)
    arg.setDisplayName('Windows: U-Factor')
    arg.setUnits('Btu/hr-ft^2-R')
    arg.setDescription('The heat transfer coefficient of the windows.')
    arg.setDefaultValue(0.37)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_shgc', true)
    arg.setDisplayName('Windows: SHGC')
    arg.setDescription('The ratio of solar heat gain through a glazing system compared to that of an unobstructed opening, for windows.')
    arg.setDefaultValue(0.3)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_interior_shading_winter', false)
    arg.setDisplayName('Windows: Winter Interior Shading')
    arg.setDescription('Interior shading multiplier for the heating season. 1.0 indicates no reduction in solar gain, 0.85 indicates 15% reduction, etc.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_interior_shading_summer', false)
    arg.setDisplayName('Windows: Summer Interior Shading')
    arg.setDescription('Interior shading multiplier for the cooling season. 1.0 indicates no reduction in solar gain, 0.85 indicates 15% reduction, etc.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_exterior_shading_winter', false)
    arg.setDisplayName('Windows: Winter Exterior Shading')
    arg.setDescription('Exterior shading multiplier for the heating season. 1.0 indicates no reduction in solar gain, 0.85 indicates 15% reduction, etc.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('window_exterior_shading_summer', false)
    arg.setDisplayName('Windows: Summer Exterior Shading')
    arg.setDescription('Exterior shading multiplier for the cooling season. 1.0 indicates no reduction in solar gain, 0.85 indicates 15% reduction, etc.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_front_depth', true)
    arg.setDisplayName('Overhangs: Front Facade Depth')
    arg.setDescription('Specifies the depth of overhangs for windows on the front facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_front_distance_to_top_of_window', true)
    arg.setDisplayName('Overhangs: Front Facade Distance to Top of Window')
    arg.setDescription('Specifies the distance to the top of window of overhangs for windows on the front facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_back_depth', true)
    arg.setDisplayName('Overhangs: Back Facade Depth')
    arg.setDescription('Specifies the depth of overhangs for windows on the back facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_back_distance_to_top_of_window', true)
    arg.setDisplayName('Overhangs: Back Facade Distance to Top of Window')
    arg.setDescription('Specifies the distance to the top of window of overhangs for windows on the back facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_left_depth', true)
    arg.setDisplayName('Overhangs: Left Facade Depth')
    arg.setDescription('Specifies the depth of overhangs for windows on the left facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_left_distance_to_top_of_window', true)
    arg.setDisplayName('Overhangs: Left Facade Distance to Top of Window')
    arg.setDescription('Specifies the distance to the top of window of overhangs for windows on the left facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_right_depth', true)
    arg.setDisplayName('Overhangs: Right Facade Depth')
    arg.setDescription('Specifies the depth of overhangs for windows on the right facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('overhangs_right_distance_to_top_of_window', true)
    arg.setDisplayName('Overhangs: Right Facade Distance to Top of Window')
    arg.setDescription('Specifies the distance to the top of window of overhangs for windows on the right facade.')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_area_front', true)
    arg.setDisplayName('Skylights: Front Roof Area')
    arg.setDescription("The amount of skylight area on the unit's front conditioned roof facade.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_area_back', true)
    arg.setDisplayName('Skylights: Back Roof Area')
    arg.setDescription("The amount of skylight area on the unit's back conditioned roof facade.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_area_left', true)
    arg.setDisplayName('Skylights: Left Roof Area')
    arg.setDescription("The amount of skylight area on the unit's left conditioned roof facade (when viewed from the front).")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_area_right', true)
    arg.setDisplayName('Skylights: Right Roof Area')
    arg.setDescription("The amount of skylight area on the unit's right conditioned roof facade (when viewed from the front).")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_ufactor', true)
    arg.setDisplayName('Skylights: U-Factor')
    arg.setUnits('Btu/hr-ft^2-R')
    arg.setDescription('The heat transfer coefficient of the skylights.')
    arg.setDefaultValue(0.33)
    args << arg

    skylight_shgc = OpenStudio::Measure::OSArgument::makeDoubleArgument('skylight_shgc', true)
    skylight_shgc.setDisplayName('Skylights: SHGC')
    skylight_shgc.setDescription('The ratio of solar heat gain through a glazing system compared to that of an unobstructed opening, for skylights.')
    skylight_shgc.setDefaultValue(0.45)
    args << skylight_shgc

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('door_area', true)
    arg.setDisplayName('Doors: Area')
    arg.setUnits('ft^2')
    arg.setDescription('The area of the opaque door(s).')
    arg.setDefaultValue(20.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('door_rvalue', true)
    arg.setDisplayName('Doors: R-value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('R-value of the doors.')
    arg.setDefaultValue(5.0)
    args << arg

    air_leakage_units_choices = OpenStudio::StringVector.new
    air_leakage_units_choices << HPXML::UnitsACH
    air_leakage_units_choices << HPXML::UnitsCFM
    air_leakage_units_choices << HPXML::UnitsACHNatural

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('air_leakage_units', air_leakage_units_choices, true)
    arg.setDisplayName('Air Leakage: Units')
    arg.setDescription('The unit of measure for the above-grade living air leakage.')
    arg.setDefaultValue(HPXML::UnitsACH)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('air_leakage_house_pressure', true)
    arg.setDisplayName('Air Leakage: House Pressure')
    arg.setUnits('Pa')
    arg.setDescription("The pressure of the house for the above-grade living air leakage when the air leakage units are #{HPXML::UnitsACH} or #{HPXML::UnitsCFM}.")
    arg.setDefaultValue(50)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('air_leakage_value', true)
    arg.setDisplayName('Air Leakage: Value')
    arg.setDescription('Air exchange rate, in ACH or CFM at the specified house pressure.')
    arg.setDefaultValue(3)
    args << arg

    air_leakage_shielding_of_home_choices = OpenStudio::StringVector.new
    air_leakage_shielding_of_home_choices << Constants.Auto
    air_leakage_shielding_of_home_choices << HPXML::ShieldingExposed
    air_leakage_shielding_of_home_choices << HPXML::ShieldingNormal
    air_leakage_shielding_of_home_choices << HPXML::ShieldingWellShielded

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('air_leakage_shielding_of_home', air_leakage_shielding_of_home_choices, true)
    arg.setDisplayName('Air Leakage: Shielding of Home')
    arg.setDescription('Presence of nearby buildings, trees, obstructions for infiltration model.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    heating_system_type_choices = OpenStudio::StringVector.new
    heating_system_type_choices << 'none'
    heating_system_type_choices << HPXML::HVACTypeFurnace
    heating_system_type_choices << HPXML::HVACTypeWallFurnace
    heating_system_type_choices << HPXML::HVACTypeFloorFurnace
    heating_system_type_choices << HPXML::HVACTypeBoiler
    heating_system_type_choices << HPXML::HVACTypeElectricResistance
    heating_system_type_choices << HPXML::HVACTypeStove
    heating_system_type_choices << HPXML::HVACTypePortableHeater
    heating_system_type_choices << HPXML::HVACTypeFireplace
    heating_system_type_choices << HPXML::HVACTypeFixedHeater
    heating_system_type_choices << "Shared #{HPXML::HVACTypeBoiler} w/ Baseboard"
    heating_system_type_choices << "Shared #{HPXML::HVACTypeBoiler} w/ Ductless Fan Coil"

    heating_system_fuel_choices = OpenStudio::StringVector.new
    heating_system_fuel_choices << HPXML::FuelTypeElectricity
    heating_system_fuel_choices << HPXML::FuelTypeNaturalGas
    heating_system_fuel_choices << HPXML::FuelTypeOil
    heating_system_fuel_choices << HPXML::FuelTypePropane
    heating_system_fuel_choices << HPXML::FuelTypeWoodCord
    heating_system_fuel_choices << HPXML::FuelTypeWoodPellets
    heating_system_fuel_choices << HPXML::FuelTypeCoal

    cooling_system_type_choices = OpenStudio::StringVector.new
    cooling_system_type_choices << 'none'
    cooling_system_type_choices << HPXML::HVACTypeCentralAirConditioner
    cooling_system_type_choices << HPXML::HVACTypeRoomAirConditioner
    cooling_system_type_choices << HPXML::HVACTypeEvaporativeCooler
    cooling_system_type_choices << HPXML::HVACTypeMiniSplitAirConditioner

    cooling_efficiency_type_choices = OpenStudio::StringVector.new
    cooling_efficiency_type_choices << HPXML::UnitsSEER
    cooling_efficiency_type_choices << HPXML::UnitsEER

    compressor_type_choices = OpenStudio::StringVector.new
    compressor_type_choices << HPXML::HVACCompressorTypeSingleStage
    compressor_type_choices << HPXML::HVACCompressorTypeTwoStage
    compressor_type_choices << HPXML::HVACCompressorTypeVariableSpeed

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heating_system_type', heating_system_type_choices, true)
    arg.setDisplayName('Heating System: Type')
    arg.setDescription("The type of heating system. Use 'none' if there is no heating system.")
    arg.setDefaultValue(HPXML::HVACTypeFurnace)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heating_system_fuel', heating_system_fuel_choices, true)
    arg.setDisplayName('Heating System: Fuel Type')
    arg.setDescription("The fuel type of the heating system. Ignored for #{HPXML::HVACTypeElectricResistance}.")
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_heating_efficiency', true)
    arg.setDisplayName('Heating System: Rated AFUE or Percent')
    arg.setUnits('Frac')
    arg.setDescription('The rated heating efficiency value of the heating system.')
    arg.setDefaultValue(0.78)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('heating_system_heating_capacity', true)
    arg.setDisplayName('Heating System: Heating Capacity')
    arg.setDescription("The output heating capacity of the heating system. If using '#{Constants.Auto}', the autosizing algorithm will use ACCA Manual J/S to set the capacity to meet its load served.")
    arg.setUnits('Btu/hr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_fraction_heat_load_served', true)
    arg.setDisplayName('Heating System: Fraction Heat Load Served')
    arg.setDescription('The heating load served by the heating system.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_airflow_defect_ratio', false)
    arg.setDisplayName('Heating System: Airflow Defect Ratio')
    arg.setDescription("The airflow defect ratio, defined as (InstalledAirflow - DesignAirflow) / DesignAirflow, of the heating system per ANSI/RESNET/ACCA Standard 310. A value of zero means no airflow defect. Applies only to #{HPXML::HVACTypeFurnace}.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('cooling_system_type', cooling_system_type_choices, true)
    arg.setDisplayName('Cooling System: Type')
    arg.setDescription("The type of cooling system. Use 'none' if there is no cooling system.")
    arg.setDefaultValue(HPXML::HVACTypeCentralAirConditioner)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('cooling_system_cooling_efficiency_type', cooling_efficiency_type_choices, true)
    arg.setDisplayName('Cooling System: Efficiency Type')
    arg.setDescription("The efficiency type of the cooling system. System types #{HPXML::HVACTypeCentralAirConditioner} and #{HPXML::HVACTypeMiniSplitAirConditioner} use #{HPXML::UnitsSEER}. System type #{HPXML::HVACTypeRoomAirConditioner} uses #{HPXML::UnitsEER}. Ignored for system type #{HPXML::HVACTypeEvaporativeCooler}.")
    arg.setDefaultValue(HPXML::UnitsSEER)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_cooling_efficiency', true)
    arg.setDisplayName('Cooling System: Efficiency')
    arg.setUnits("#{HPXML::UnitsSEER} or #{HPXML::UnitsEER}")
    arg.setDescription("The rated efficiency value of the cooling system. Ignored for #{HPXML::HVACTypeEvaporativeCooler}.")
    arg.setDefaultValue(13.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('cooling_system_cooling_compressor_type', compressor_type_choices, false)
    arg.setDisplayName('Cooling System: Cooling Compressor Type')
    arg.setDescription('The compressor type of the cooling system. Only applies to central air conditioner.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_cooling_sensible_heat_fraction', false)
    arg.setDisplayName('Cooling System: Cooling Sensible Heat Fraction')
    arg.setDescription("The sensible heat fraction of the cooling system. Ignored for #{HPXML::HVACTypeEvaporativeCooler}.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('cooling_system_cooling_capacity', true)
    arg.setDisplayName('Cooling System: Cooling Capacity')
    arg.setDescription("The output cooling capacity of the cooling system. If using '#{Constants.Auto}', the autosizing algorithm will use ACCA Manual J/S to set the capacity to meet its load served.")
    arg.setUnits('tons')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_fraction_cool_load_served', true)
    arg.setDisplayName('Cooling System: Fraction Cool Load Served')
    arg.setDescription('The cooling load served by the cooling system.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('cooling_system_is_ducted', true)
    arg.setDisplayName('Cooling System: Is Ducted')
    arg.setDescription("Whether the cooling system is ducted or not. Only used for #{HPXML::HVACTypeMiniSplitAirConditioner} and #{HPXML::HVACTypeEvaporativeCooler}.")
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_airflow_defect_ratio', false)
    arg.setDisplayName('Cooling System: Airflow Defect Ratio')
    arg.setDescription("The airflow defect ratio, defined as (InstalledAirflow - DesignAirflow) / DesignAirflow, of the cooling system per ANSI/RESNET/ACCA Standard 310. A value of zero means no airflow defect. Applies only to #{HPXML::HVACTypeCentralAirConditioner} and ducted #{HPXML::HVACTypeMiniSplitAirConditioner}.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooling_system_charge_defect_ratio', false)
    arg.setDisplayName('Cooling System: Charge Defect Ratio')
    arg.setDescription("The refrigerant charge defect ratio, defined as (InstalledCharge - DesignCharge) / DesignCharge, of the cooling system per ANSI/RESNET/ACCA Standard 310. A value of zero means no refrigerant charge defect. Applies only to #{HPXML::HVACTypeCentralAirConditioner} and #{HPXML::HVACTypeMiniSplitAirConditioner}.")
    arg.setUnits('Frac')
    args << arg

    heat_pump_type_choices = OpenStudio::StringVector.new
    heat_pump_type_choices << 'none'
    heat_pump_type_choices << HPXML::HVACTypeHeatPumpAirToAir
    heat_pump_type_choices << HPXML::HVACTypeHeatPumpMiniSplit
    heat_pump_type_choices << HPXML::HVACTypeHeatPumpGroundToAir

    heat_pump_heating_efficiency_type_choices = OpenStudio::StringVector.new
    heat_pump_heating_efficiency_type_choices << HPXML::UnitsHSPF
    heat_pump_heating_efficiency_type_choices << HPXML::UnitsCOP

    heat_pump_fuel_choices = OpenStudio::StringVector.new
    heat_pump_fuel_choices << HPXML::FuelTypeElectricity

    heat_pump_backup_fuel_choices = OpenStudio::StringVector.new
    heat_pump_backup_fuel_choices << 'none'
    heat_pump_backup_fuel_choices << HPXML::FuelTypeElectricity
    heat_pump_backup_fuel_choices << HPXML::FuelTypeNaturalGas
    heat_pump_backup_fuel_choices << HPXML::FuelTypeOil
    heat_pump_backup_fuel_choices << HPXML::FuelTypePropane

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heat_pump_type', heat_pump_type_choices, true)
    arg.setDisplayName('Heat Pump: Type')
    arg.setDescription("The type of heat pump. Use 'none' if there is no heat pump.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heat_pump_heating_efficiency_type', heat_pump_heating_efficiency_type_choices, true)
    arg.setDisplayName('Heat Pump: Heating Efficiency Type')
    arg.setDescription("The heating efficiency type of heat pump. System types #{HPXML::HVACTypeHeatPumpAirToAir} and #{HPXML::HVACTypeHeatPumpMiniSplit} use #{HPXML::UnitsHSPF}. System type #{HPXML::HVACTypeHeatPumpGroundToAir} uses #{HPXML::UnitsCOP}.")
    arg.setDefaultValue(HPXML::UnitsHSPF)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_heating_efficiency', true)
    arg.setDisplayName('Heat Pump: Heating Efficiency')
    arg.setUnits("#{HPXML::UnitsHSPF} or #{HPXML::UnitsCOP}")
    arg.setDescription('The rated heating efficiency value of the heat pump.')
    arg.setDefaultValue(7.7)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heat_pump_cooling_efficiency_type', cooling_efficiency_type_choices, true)
    arg.setDisplayName('Heat Pump: Cooling Efficiency Type')
    arg.setDescription("The cooling efficiency type of heat pump. System types #{HPXML::HVACTypeHeatPumpAirToAir} and #{HPXML::HVACTypeHeatPumpMiniSplit} use #{HPXML::UnitsSEER}. System type #{HPXML::HVACTypeHeatPumpGroundToAir} uses #{HPXML::UnitsEER}.")
    arg.setDefaultValue(HPXML::UnitsSEER)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_cooling_efficiency', true)
    arg.setDisplayName('Heat Pump: Cooling Efficiency')
    arg.setUnits("#{HPXML::UnitsSEER} or #{HPXML::UnitsEER}")
    arg.setDescription('The rated cooling efficiency value of the heat pump.')
    arg.setDefaultValue(13.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heat_pump_cooling_compressor_type', compressor_type_choices, false)
    arg.setDisplayName('Heat Pump: Cooling Compressor Type')
    arg.setDescription('The compressor type of the heat pump. Only applies to air-to-air and mini-split.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_cooling_sensible_heat_fraction', false)
    arg.setDisplayName('Heat Pump: Cooling Sensible Heat Fraction')
    arg.setDescription('The sensible heat fraction of the heat pump.')
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('heat_pump_heating_capacity', true)
    arg.setDisplayName('Heat Pump: Heating Capacity')
    arg.setDescription("The output heating capacity of the heat pump. If using '#{Constants.Auto}', the autosizing algorithm will use ACCA Manual J/S to set the capacity to meet its load served.")
    arg.setUnits('Btu/hr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('heat_pump_heating_capacity_17_f', true)
    arg.setDisplayName('Heat Pump: Heating Capacity 17F')
    arg.setDescription("The output heating capacity of the heat pump at 17F. Only applies to #{HPXML::HVACTypeHeatPumpAirToAir} and #{HPXML::HVACTypeHeatPumpMiniSplit}.")
    arg.setUnits('Btu/hr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('heat_pump_cooling_capacity', true)
    arg.setDisplayName('Heat Pump: Cooling Capacity')
    arg.setDescription("The output cooling capacity of the heat pump. If using '#{Constants.Auto}', the autosizing algorithm will use ACCA Manual J/S to set the capacity to meet its load served.")
    arg.setUnits('Btu/hr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_fraction_heat_load_served', true)
    arg.setDisplayName('Heat Pump: Fraction Heat Load Served')
    arg.setDescription('The heating load served by the heat pump.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_fraction_cool_load_served', true)
    arg.setDisplayName('Heat Pump: Fraction Cool Load Served')
    arg.setDescription('The cooling load served by the heat pump.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heat_pump_backup_fuel', heat_pump_backup_fuel_choices, true)
    arg.setDisplayName('Heat Pump: Backup Fuel Type')
    arg.setDescription("The backup fuel type of the heat pump. Use 'none' if there is no backup heating.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_backup_heating_efficiency', true)
    arg.setDisplayName('Heat Pump: Backup Rated Efficiency')
    arg.setDescription('The backup rated efficiency value of the heat pump. Percent for electricity fuel type. AFUE otherwise.')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('heat_pump_backup_heating_capacity', true)
    arg.setDisplayName('Heat Pump: Backup Heating Capacity')
    arg.setDescription("The backup output heating capacity of the heat pump. If using '#{Constants.Auto}', the autosizing algorithm will use ACCA Manual J/S to set the capacity to meet its load served.")
    arg.setUnits('Btu/hr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_backup_heating_switchover_temp', false)
    arg.setDisplayName('Heat Pump: Backup Heating Switchover Temperature')
    arg.setDescription('The temperature at which the heat pump stops operating and the backup heating system starts running. Only applies to air-to-air and mini-split. If not provided, backup heating will operate as needed when heat pump capacity is insufficient.')
    arg.setUnits('deg-F')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('heat_pump_is_ducted', false)
    arg.setDisplayName('Heat Pump: Is Ducted')
    arg.setDescription("Whether the heat pump is ducted or not. Only used for #{HPXML::HVACTypeHeatPumpMiniSplit}.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_airflow_defect_ratio', false)
    arg.setDisplayName('Heat Pump: Airflow Defect Ratio')
    arg.setDescription("The airflow defect ratio, defined as (InstalledAirflow - DesignAirflow) / DesignAirflow, of the heat pump per ANSI/RESNET/ACCA Standard 310. A value of zero means no airflow defect. Applies only to #{HPXML::HVACTypeHeatPumpAirToAir}, ducted #{HPXML::HVACTypeHeatPumpMiniSplit}, and #{HPXML::HVACTypeHeatPumpGroundToAir}.")
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heat_pump_charge_defect_ratio', false)
    arg.setDisplayName('Heat Pump: Charge Defect Ratio')
    arg.setDescription('The refrigerant charge defect ratio, defined as (InstalledCharge - DesignCharge) / DesignCharge, of the heat pump per ANSI/RESNET/ACCA Standard 310. A value of zero means no refrigerant charge defect. Applies to all heat pump types.')
    arg.setUnits('Frac')
    args << arg

    heating_system_type_2_choices = OpenStudio::StringVector.new
    heating_system_type_2_choices << 'none'
    heating_system_type_2_choices << HPXML::HVACTypeWallFurnace
    heating_system_type_2_choices << HPXML::HVACTypeFloorFurnace
    heating_system_type_2_choices << HPXML::HVACTypeBoiler
    heating_system_type_2_choices << HPXML::HVACTypeElectricResistance
    heating_system_type_2_choices << HPXML::HVACTypeStove
    heating_system_type_2_choices << HPXML::HVACTypePortableHeater
    heating_system_type_2_choices << HPXML::HVACTypeFireplace

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heating_system_type_2', heating_system_type_2_choices, true)
    arg.setDisplayName('Heating System 2: Type')
    arg.setDescription('The type of the second heating system.')
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('heating_system_fuel_2', heating_system_fuel_choices, true)
    arg.setDisplayName('Heating System 2: Fuel Type')
    arg.setDescription("The fuel type of the second heating system. Ignored for #{HPXML::HVACTypeElectricResistance}.")
    arg.setDefaultValue(HPXML::FuelTypeElectricity)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_heating_efficiency_2', true)
    arg.setDisplayName('Heating System 2: Rated AFUE or Percent')
    arg.setUnits('Frac')
    arg.setDescription('For Furnace/WallFurnace/FloorFurnace/Boiler second heating system, the rated AFUE value. For ElectricResistance/Stove/PortableHeater/Fireplace, the rated Percent value.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('heating_system_heating_capacity_2', true)
    arg.setDisplayName('Heating System 2: Heating Capacity')
    arg.setDescription("The output heating capacity of the second heating system. If using '#{Constants.Auto}', the autosizing algorithm will use ACCA Manual J/S to set the capacity to meet its load served.")
    arg.setUnits('Btu/hr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('heating_system_fraction_heat_load_served_2', true)
    arg.setDisplayName('Heating System 2: Fraction Heat Load Served')
    arg.setDescription('The heat load served fraction of the second heating system.')
    arg.setUnits('Frac')
    arg.setDefaultValue(0.25)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('setpoint_heating_weekday', true)
    arg.setDisplayName('Heating Setpoint: Weekday Schedule')
    arg.setDescription('Specify the constant or 24-hour comma-separated weekday heating schedule.')
    arg.setUnits('deg-F')
    arg.setDefaultValue('71')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('setpoint_heating_weekend', true)
    arg.setDisplayName('Heating Setpoint: Weekend Schedule')
    arg.setDescription('Specify the constant or 24-hour comma-separated weekend heating schedule.')
    arg.setUnits('deg-F')
    arg.setDefaultValue('71')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('setpoint_cooling_weekday', true)
    arg.setDisplayName('Cooling Setpoint: Weekday Schedule')
    arg.setDescription('Specify the constant or 24-hour comma-separated weekday cooling schedule.')
    arg.setUnits('deg-F')
    arg.setDefaultValue('76')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('setpoint_cooling_weekend', true)
    arg.setDisplayName('Cooling Setpoint: Weekend Schedule')
    arg.setDescription('Specify the constant or 24-hour comma-separated weekend cooling schedule.')
    arg.setUnits('deg-F')
    arg.setDefaultValue('76')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('season_heating_begin_month', false)
    arg.setDisplayName('Heating Season: Begin Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the starting month number (1 = January, 2 = February, etc.) for the heating season.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('season_heating_begin_day_of_month', false)
    arg.setDisplayName('Heating Season: Begin Day of Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the starting day of the starting month (must be valid for month) for the heating season.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('season_heating_end_month', false)
    arg.setDisplayName('Heating Season: End Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the end month number (1 = January, 2 = February, etc.) for the heating season.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('season_heating_end_day_of_month', false)
    arg.setDisplayName('Heating Season: End Day of Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the ending day of the ending month (must be valid for month) for the heating season.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('season_cooling_begin_month', false)
    arg.setDisplayName('Cooling Season: Begin Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the starting month number (1 = January, 2 = February, etc.) for the cooling season.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('season_cooling_begin_day_of_month', false)
    arg.setDisplayName('Cooling Season: Begin Day of Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the starting day of the starting month (must be valid for month) for the cooling season.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('season_cooling_end_month', false)
    arg.setDisplayName('Cooling Season: End Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the end month number (1 = January, 2 = February, etc.) for the cooling season.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('season_cooling_end_day_of_month', false)
    arg.setDisplayName('Cooling Season: End Day of Month')
    arg.setUnits('#')
    arg.setDescription('This numeric field should contain the ending day of the ending month (must be valid for month) for the cooling season.')
    args << arg

    duct_leakage_units_choices = OpenStudio::StringVector.new
    duct_leakage_units_choices << HPXML::UnitsCFM25
    duct_leakage_units_choices << HPXML::UnitsPercent

    duct_location_choices = OpenStudio::StringVector.new
    duct_location_choices << Constants.Auto
    duct_location_choices << HPXML::LocationLivingSpace
    duct_location_choices << HPXML::LocationBasementConditioned
    duct_location_choices << HPXML::LocationBasementUnconditioned
    duct_location_choices << HPXML::LocationCrawlspaceVented
    duct_location_choices << HPXML::LocationCrawlspaceUnvented
    duct_location_choices << HPXML::LocationAtticVented
    duct_location_choices << HPXML::LocationAtticUnvented
    duct_location_choices << HPXML::LocationGarage
    duct_location_choices << HPXML::LocationExteriorWall
    duct_location_choices << HPXML::LocationUnderSlab
    duct_location_choices << HPXML::LocationRoofDeck
    duct_location_choices << HPXML::LocationOutside
    duct_location_choices << HPXML::LocationOtherHousingUnit
    duct_location_choices << HPXML::LocationOtherHeatedSpace
    duct_location_choices << HPXML::LocationOtherMultifamilyBufferSpace
    duct_location_choices << HPXML::LocationOtherNonFreezingSpace

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('ducts_supply_leakage_units', duct_leakage_units_choices, true)
    arg.setDisplayName('Ducts: Supply Leakage Units')
    arg.setDescription('The leakage units of the supply ducts.')
    arg.setDefaultValue(HPXML::UnitsCFM25)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('ducts_return_leakage_units', duct_leakage_units_choices, true)
    arg.setDisplayName('Ducts: Return Leakage Units')
    arg.setDescription('The leakage units of the return ducts.')
    arg.setDefaultValue(HPXML::UnitsCFM25)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ducts_supply_leakage_value', true)
    arg.setDisplayName('Ducts: Supply Leakage Value')
    arg.setDescription('The leakage value to outside of the supply ducts.')
    arg.setDefaultValue(75)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ducts_return_leakage_value', true)
    arg.setDisplayName('Ducts: Return Leakage Value')
    arg.setDescription('The leakage value to outside of the return ducts.')
    arg.setDefaultValue(25)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ducts_supply_insulation_r', true)
    arg.setDisplayName('Ducts: Supply Insulation R-Value')
    arg.setDescription('The insulation r-value of the supply ducts.')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ducts_return_insulation_r', true)
    arg.setDisplayName('Ducts: Return Insulation R-Value')
    arg.setDescription('The insulation r-value of the return ducts.')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('ducts_supply_location', duct_location_choices, true)
    arg.setDisplayName('Ducts: Supply Location')
    arg.setDescription('The location of the supply ducts.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('ducts_return_location', duct_location_choices, true)
    arg.setDisplayName('Ducts: Return Location')
    arg.setDescription('The location of the return ducts.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('ducts_supply_surface_area', true)
    arg.setDisplayName('Ducts: Supply Surface Area')
    arg.setDescription('The surface area of the supply ducts.')
    arg.setUnits('ft^2')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('ducts_return_surface_area', true)
    arg.setDisplayName('Ducts: Return Surface Area')
    arg.setDescription('The surface area of the return ducts.')
    arg.setUnits('ft^2')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('ducts_number_of_return_registers', true)
    arg.setDisplayName('Ducts: Number of Return Registers')
    arg.setDescription("The number of return registers of the ducts. Ignored for ducted #{HPXML::HVACTypeEvaporativeCooler}.")
    arg.setUnits('#')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    mech_vent_fan_type_choices = OpenStudio::StringVector.new
    mech_vent_fan_type_choices << 'none'
    mech_vent_fan_type_choices << HPXML::MechVentTypeExhaust
    mech_vent_fan_type_choices << HPXML::MechVentTypeSupply
    mech_vent_fan_type_choices << HPXML::MechVentTypeERV
    mech_vent_fan_type_choices << HPXML::MechVentTypeHRV
    mech_vent_fan_type_choices << HPXML::MechVentTypeBalanced
    mech_vent_fan_type_choices << HPXML::MechVentTypeCFIS

    mech_vent_recovery_efficiency_type_choices = OpenStudio::StringVector.new
    mech_vent_recovery_efficiency_type_choices << 'Unadjusted'
    mech_vent_recovery_efficiency_type_choices << 'Adjusted'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('mech_vent_fan_type', mech_vent_fan_type_choices, true)
    arg.setDisplayName('Mechanical Ventilation: Fan Type')
    arg.setDescription("The type of the mechanical ventilation. Use 'none' if there is no mechanical ventilation system.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_flow_rate', true)
    arg.setDisplayName('Mechanical Ventilation: Flow Rate')
    arg.setDescription('The flow rate of the mechanical ventilation.')
    arg.setUnits('CFM')
    arg.setDefaultValue(110)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('mech_vent_hours_in_operation', true)
    arg.setDisplayName('Mechanical Ventilation: Hours In Operation')
    arg.setDescription('The hours in operation of the mechanical ventilation.')
    arg.setUnits('hrs/day')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('mech_vent_recovery_efficiency_type', mech_vent_recovery_efficiency_type_choices, true)
    arg.setDisplayName('Mechanical Ventilation: Total Recovery Efficiency Type')
    arg.setDescription('The total recovery efficiency type of the mechanical ventilation.')
    arg.setDefaultValue('Unadjusted')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_total_recovery_efficiency', true)
    arg.setDisplayName('Mechanical Ventilation: Total Recovery Efficiency')
    arg.setDescription("The Unadjusted or Adjusted total recovery efficiency of the mechanical ventilation. Applies to #{HPXML::MechVentTypeERV}.")
    arg.setUnits('Frac')
    arg.setDefaultValue(0.48)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_sensible_recovery_efficiency', true)
    arg.setDisplayName('Mechanical Ventilation: Sensible Recovery Efficiency')
    arg.setDescription("The Unadjusted or Adjusted sensible recovery efficiency of the mechanical ventilation. Applies to #{HPXML::MechVentTypeERV} and #{HPXML::MechVentTypeHRV}.")
    arg.setUnits('Frac')
    arg.setDefaultValue(0.72)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('mech_vent_fan_power', true)
    arg.setDisplayName('Mechanical Ventilation: Fan Power')
    arg.setDescription('The fan power of the mechanical ventilation.')
    arg.setUnits('W')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('mech_vent_num_units_served', true)
    arg.setDisplayName('Mechanical Ventilation: Number of Units Served')
    arg.setDescription("Number of dwelling units served by the mechanical ventilation system. Must be 1 if #{HPXML::ResidentialTypeSFD}. Used to apportion flow rate and fan power to the unit.")
    arg.setUnits('#')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('shared_mech_vent_frac_recirculation', false)
    arg.setDisplayName('Shared Mechanical Ventilation: Fraction Recirculation')
    arg.setDescription('Fraction of the total supply air that is recirculated, with the remainder assumed to be outdoor air. The value must be 0 for exhaust only systems. This is required for a shared mechanical ventilation system.')
    arg.setUnits('Frac')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('shared_mech_vent_preheating_fuel', heating_system_fuel_choices, false)
    arg.setDisplayName('Shared Mechanical Ventilation: Preheating Fuel')
    arg.setDescription('Fuel type of the preconditioning heating equipment. Only used for a shared mechanical ventilation system.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('shared_mech_vent_preheating_efficiency', false)
    arg.setDisplayName('Shared Mechanical Ventilation: Preheating Efficiency')
    arg.setDescription('Efficiency of the preconditioning heating equipment. Only used for a shared mechanical ventilation system.')
    arg.setUnits('COP')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('shared_mech_vent_preheating_fraction_heat_load_served', false)
    arg.setDisplayName('Shared Mechanical Ventilation: Preheating Fraction Ventilation Heat Load Served')
    arg.setDescription('Fraction of heating load introduced by the shared ventilation system that is met by the preconditioning heating equipment.')
    arg.setUnits('Frac')
    args << arg

    cooling_system_fuel_choices = OpenStudio::StringVector.new
    cooling_system_fuel_choices << HPXML::FuelTypeElectricity

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('shared_mech_vent_precooling_fuel', cooling_system_fuel_choices, false)
    arg.setDisplayName('Shared Mechanical Ventilation: Precooling Fuel')
    arg.setDescription('Fuel type of the preconditioning cooling equipment. Only used for a shared mechanical ventilation system.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('shared_mech_vent_precooling_efficiency', false)
    arg.setDisplayName('Shared Mechanical Ventilation: Precooling Efficiency')
    arg.setDescription('Efficiency of the preconditioning cooling equipment. Only used for a shared mechanical ventilation system.')
    arg.setUnits('COP')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('shared_mech_vent_precooling_fraction_cool_load_served', false)
    arg.setDisplayName('Shared Mechanical Ventilation: Precooling Fraction Ventilation Cool Load Served')
    arg.setDescription('Fraction of cooling load introduced by the shared ventilation system that is met by the preconditioning cooling equipment.')
    arg.setUnits('Frac')
    args << arg

    mech_vent_fan_type_2_choices = OpenStudio::StringVector.new
    mech_vent_fan_type_2_choices << 'none'
    mech_vent_fan_type_2_choices << HPXML::MechVentTypeExhaust
    mech_vent_fan_type_2_choices << HPXML::MechVentTypeSupply
    mech_vent_fan_type_2_choices << HPXML::MechVentTypeERV
    mech_vent_fan_type_2_choices << HPXML::MechVentTypeHRV
    mech_vent_fan_type_2_choices << HPXML::MechVentTypeBalanced

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('mech_vent_fan_type_2', mech_vent_fan_type_2_choices, true)
    arg.setDisplayName('Mechanical Ventilation 2: Fan Type')
    arg.setDescription("The type of the second mechanical ventilation. Use 'none' if there is no second mechanical ventilation system.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_flow_rate_2', true)
    arg.setDisplayName('Mechanical Ventilation 2: Flow Rate')
    arg.setDescription('The flow rate of the second mechanical ventilation.')
    arg.setUnits('CFM')
    arg.setDefaultValue(110)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_hours_in_operation_2', true)
    arg.setDisplayName('Mechanical Ventilation 2: Hours In Operation')
    arg.setDescription('The hours in operation of the second mechanical ventilation.')
    arg.setUnits('hrs/day')
    arg.setDefaultValue(24)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('mech_vent_recovery_efficiency_type_2', mech_vent_recovery_efficiency_type_choices, true)
    arg.setDisplayName('Mechanical Ventilation 2: Total Recovery Efficiency Type')
    arg.setDescription('The total recovery efficiency type of the second mechanical ventilation.')
    arg.setDefaultValue('Unadjusted')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_total_recovery_efficiency_2', true)
    arg.setDisplayName('Mechanical Ventilation 2: Total Recovery Efficiency')
    arg.setDescription("The Unadjusted or Adjusted total recovery efficiency of the second mechanical ventilation. Applies to #{HPXML::MechVentTypeERV}.")
    arg.setUnits('Frac')
    arg.setDefaultValue(0.48)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_sensible_recovery_efficiency_2', true)
    arg.setDisplayName('Mechanical Ventilation 2: Sensible Recovery Efficiency')
    arg.setDescription("The Unadjusted or Adjusted sensible recovery efficiency of the second mechanical ventilation. Applies to #{HPXML::MechVentTypeERV} and #{HPXML::MechVentTypeHRV}.")
    arg.setUnits('Frac')
    arg.setDefaultValue(0.72)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('mech_vent_fan_power_2', true)
    arg.setDisplayName('Mechanical Ventilation 2: Fan Power')
    arg.setDescription('The fan power of the second mechanical ventilation.')
    arg.setUnits('W')
    arg.setDefaultValue(30)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('kitchen_fans_quantity', true)
    arg.setDisplayName('Kitchen Fans: Quantity')
    arg.setDescription('The quantity of the kitchen fans.')
    arg.setUnits('#')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('kitchen_fans_flow_rate', false)
    arg.setDisplayName('Kitchen Fans: Flow Rate')
    arg.setDescription('The flow rate of the kitchen fan.')
    arg.setUnits('CFM')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('kitchen_fans_hours_in_operation', false)
    arg.setDisplayName('Kitchen Fans: Hours In Operation')
    arg.setDescription('The hours in operation of the kitchen fan.')
    arg.setUnits('hrs/day')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('kitchen_fans_power', false)
    arg.setDisplayName('Kitchen Fans: Fan Power')
    arg.setDescription('The fan power of the kitchen fan.')
    arg.setUnits('W')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('kitchen_fans_start_hour', false)
    arg.setDisplayName('Kitchen Fans: Start Hour')
    arg.setDescription('The start hour of the kitchen fan.')
    arg.setUnits('hr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('bathroom_fans_quantity', true)
    arg.setDisplayName('Bathroom Fans: Quantity')
    arg.setDescription('The quantity of the bathroom fans.')
    arg.setUnits('#')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('bathroom_fans_flow_rate', false)
    arg.setDisplayName('Bathroom Fans: Flow Rate')
    arg.setDescription('The flow rate of the bathroom fans.')
    arg.setUnits('CFM')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('bathroom_fans_hours_in_operation', false)
    arg.setDisplayName('Bathroom Fans: Hours In Operation')
    arg.setDescription('The hours in operation of the bathroom fans.')
    arg.setUnits('hrs/day')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('bathroom_fans_power', false)
    arg.setDisplayName('Bathroom Fans: Fan Power')
    arg.setDescription('The fan power of the bathroom fans.')
    arg.setUnits('W')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('bathroom_fans_start_hour', false)
    arg.setDisplayName('Bathroom Fans: Start Hour')
    arg.setDescription('The start hour of the bathroom fans.')
    arg.setUnits('hr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('whole_house_fan_present', true)
    arg.setDisplayName('Whole House Fan: Present')
    arg.setDescription('Whether there is a whole house fan.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('whole_house_fan_flow_rate', true)
    arg.setDisplayName('Whole House Fan: Flow Rate')
    arg.setDescription('The flow rate of the whole house fan.')
    arg.setUnits('CFM')
    arg.setDefaultValue(4500)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('whole_house_fan_power', true)
    arg.setDisplayName('Whole House Fan: Fan Power')
    arg.setDescription('The fan power of the whole house fan.')
    arg.setUnits('W')
    arg.setDefaultValue(300)
    args << arg

    water_heater_type_choices = OpenStudio::StringVector.new
    water_heater_type_choices << 'none'
    water_heater_type_choices << HPXML::WaterHeaterTypeStorage
    water_heater_type_choices << HPXML::WaterHeaterTypeTankless
    water_heater_type_choices << HPXML::WaterHeaterTypeHeatPump
    water_heater_type_choices << HPXML::WaterHeaterTypeCombiStorage
    water_heater_type_choices << HPXML::WaterHeaterTypeCombiTankless

    water_heater_fuel_choices = OpenStudio::StringVector.new
    water_heater_fuel_choices << HPXML::FuelTypeElectricity
    water_heater_fuel_choices << HPXML::FuelTypeNaturalGas
    water_heater_fuel_choices << HPXML::FuelTypeOil
    water_heater_fuel_choices << HPXML::FuelTypePropane
    water_heater_fuel_choices << HPXML::FuelTypeWoodCord
    water_heater_fuel_choices << HPXML::FuelTypeCoal

    water_heater_location_choices = OpenStudio::StringVector.new
    water_heater_location_choices << Constants.Auto
    water_heater_location_choices << HPXML::LocationLivingSpace
    water_heater_location_choices << HPXML::LocationBasementConditioned
    water_heater_location_choices << HPXML::LocationBasementUnconditioned
    water_heater_location_choices << HPXML::LocationGarage
    water_heater_location_choices << HPXML::LocationAtticVented
    water_heater_location_choices << HPXML::LocationAtticUnvented
    water_heater_location_choices << HPXML::LocationCrawlspaceVented
    water_heater_location_choices << HPXML::LocationCrawlspaceUnvented
    water_heater_location_choices << HPXML::LocationOtherExterior
    water_heater_location_choices << HPXML::LocationOtherHousingUnit
    water_heater_location_choices << HPXML::LocationOtherHeatedSpace
    water_heater_location_choices << HPXML::LocationOtherMultifamilyBufferSpace
    water_heater_location_choices << HPXML::LocationOtherNonFreezingSpace

    water_heater_efficiency_type_choices = OpenStudio::StringVector.new
    water_heater_efficiency_type_choices << 'EnergyFactor'
    water_heater_efficiency_type_choices << 'UniformEnergyFactor'

    water_heater_usage_bin_choices = OpenStudio::StringVector.new
    water_heater_usage_bin_choices << HPXML::WaterHeaterUsageBinVerySmall
    water_heater_usage_bin_choices << HPXML::WaterHeaterUsageBinLow
    water_heater_usage_bin_choices << HPXML::WaterHeaterUsageBinMedium
    water_heater_usage_bin_choices << HPXML::WaterHeaterUsageBinHigh

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('water_heater_type', water_heater_type_choices, true)
    arg.setDisplayName('Water Heater: Type')
    arg.setDescription("The type of water heater. Use 'none' if there is no water heater.")
    arg.setDefaultValue(HPXML::WaterHeaterTypeStorage)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('water_heater_fuel_type', water_heater_fuel_choices, true)
    arg.setDisplayName('Water Heater: Fuel Type')
    arg.setDescription("The fuel type of water heater. Ignored for #{HPXML::WaterHeaterTypeHeatPump}.")
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('water_heater_location', water_heater_location_choices, true)
    arg.setDisplayName('Water Heater: Location')
    arg.setDescription('The location of water heater.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('water_heater_tank_volume', true)
    arg.setDisplayName('Water Heater: Tank Volume')
    arg.setDescription("Nominal volume of water heater tank. Set to '#{Constants.Auto}' to have volume autosized. Only applies to #{HPXML::WaterHeaterTypeStorage}, #{HPXML::WaterHeaterTypeHeatPump}, and #{HPXML::WaterHeaterTypeCombiStorage}.")
    arg.setUnits('gal')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('water_heater_efficiency_type', water_heater_efficiency_type_choices, true)
    arg.setDisplayName('Water Heater: Efficiency Type')
    arg.setDescription('The efficiency type of water heater. Does not apply to space-heating boilers.')
    arg.setDefaultValue('EnergyFactor')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('water_heater_efficiency', true)
    arg.setDisplayName('Water Heater: Efficiency')
    arg.setDescription('Rated Energy Factor or Uniform Energy Factor. Does not apply to space-heating boilers.')
    arg.setDefaultValue(0.67)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('water_heater_usage_bin', water_heater_usage_bin_choices, false)
    arg.setDisplayName('Water Heater: Usage Bin')
    arg.setDescription("The usage of the water heater. Required if Efficiency Type is UniformEnergyFactor and Type is not #{HPXML::WaterHeaterTypeTankless}. Does not apply to space-heating boilers.")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('water_heater_recovery_efficiency', true)
    arg.setDisplayName('Water Heater: Recovery Efficiency')
    arg.setDescription('Ratio of energy delivered to water heater to the energy content of the fuel consumed by the water heater. Only used for non-electric storage water heaters.')
    arg.setUnits('Frac')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('water_heater_standby_loss', false)
    arg.setDisplayName('Water Heater: Standby Loss')
    arg.setDescription('The standby loss of water heater. Only applies to space-heating boilers.')
    arg.setUnits('deg-F/hr')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('water_heater_jacket_rvalue', false)
    arg.setDisplayName('Water Heater: Jacket R-value')
    arg.setDescription("The jacket R-value of water heater. Doesn't apply to #{HPXML::WaterHeaterTypeTankless} or #{HPXML::WaterHeaterTypeCombiTankless}.")
    arg.setUnits('h-ft^2-R/Btu')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('water_heater_setpoint_temperature', true)
    arg.setDisplayName('Water Heater: Setpoint Temperature')
    arg.setDescription('The setpoint temperature of water heater.')
    arg.setUnits('deg-F')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('water_heater_num_units_served', true)
    arg.setDisplayName('Water Heater: Number of Units Served')
    arg.setDescription("Number of dwelling units served (directly or indirectly) by the water heater. Must be 1 if #{HPXML::ResidentialTypeSFD}. Used to apportion water heater tank losses to the unit.")
    arg.setUnits('#')
    arg.setDefaultValue(1)
    args << arg

    dhw_distribution_system_type_choices = OpenStudio::StringVector.new
    dhw_distribution_system_type_choices << HPXML::DHWDistTypeStandard
    dhw_distribution_system_type_choices << HPXML::DHWDistTypeRecirc

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('dhw_distribution_system_type', dhw_distribution_system_type_choices, true)
    arg.setDisplayName('Hot Water Distribution: System Type')
    arg.setDescription('The type of the hot water distribution system.')
    arg.setDefaultValue(HPXML::DHWDistTypeStandard)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('dhw_distribution_standard_piping_length', true)
    arg.setDisplayName('Hot Water Distribution: Standard Piping Length')
    arg.setUnits('ft')
    arg.setDescription("If the distribution system is #{HPXML::DHWDistTypeStandard}, the length of the piping. A value of '#{Constants.Auto}' will use a default.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    recirculation_control_type_choices = OpenStudio::StringVector.new
    recirculation_control_type_choices << HPXML::DHWRecirControlTypeNone
    recirculation_control_type_choices << HPXML::DHWRecirControlTypeTimer
    recirculation_control_type_choices << HPXML::DHWRecirControlTypeTemperature
    recirculation_control_type_choices << HPXML::DHWRecirControlTypeSensor
    recirculation_control_type_choices << HPXML::DHWRecirControlTypeManual

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('dhw_distribution_recirc_control_type', recirculation_control_type_choices, true)
    arg.setDisplayName('Hot Water Distribution: Recirculation Control Type')
    arg.setDescription("If the distribution system is #{HPXML::DHWDistTypeRecirc}, the type of hot water recirculation control, if any.")
    arg.setDefaultValue(HPXML::DHWRecirControlTypeNone)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('dhw_distribution_recirc_piping_length', true)
    arg.setDisplayName('Hot Water Distribution: Recirculation Piping Length')
    arg.setUnits('ft')
    arg.setDescription("If the distribution system is #{HPXML::DHWDistTypeRecirc}, the length of the recirculation piping.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('dhw_distribution_recirc_branch_piping_length', true)
    arg.setDisplayName('Hot Water Distribution: Recirculation Branch Piping Length')
    arg.setUnits('ft')
    arg.setDescription("If the distribution system is #{HPXML::DHWDistTypeRecirc}, the length of the recirculation branch piping.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('dhw_distribution_recirc_pump_power', true)
    arg.setDisplayName('Hot Water Distribution: Recirculation Pump Power')
    arg.setUnits('W')
    arg.setDescription("If the distribution system is #{HPXML::DHWDistTypeRecirc}, the recirculation pump power.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('dhw_distribution_pipe_r', true)
    arg.setDisplayName('Hot Water Distribution: Pipe Insulation Nominal R-Value')
    arg.setUnits('h-ft^2-R/Btu')
    arg.setDescription('Nominal R-value of the pipe insulation.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    dwhr_facilities_connected_choices = OpenStudio::StringVector.new
    dwhr_facilities_connected_choices << 'none'
    dwhr_facilities_connected_choices << HPXML::DWHRFacilitiesConnectedOne
    dwhr_facilities_connected_choices << HPXML::DWHRFacilitiesConnectedAll

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('dwhr_facilities_connected', dwhr_facilities_connected_choices, true)
    arg.setDisplayName('Drain Water Heat Recovery: Facilities Connected')
    arg.setDescription("Which facilities are connected for the drain water heat recovery. Use 'none' if there is no drain water heat recovery system.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('dwhr_equal_flow', true)
    arg.setDisplayName('Drain Water Heat Recovery: Equal Flow')
    arg.setDescription('Whether the drain water heat recovery has equal flow.')
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dwhr_efficiency', true)
    arg.setDisplayName('Drain Water Heat Recovery: Efficiency')
    arg.setUnits('Frac')
    arg.setDescription('The efficiency of the drain water heat recovery.')
    arg.setDefaultValue(0.55)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('water_fixtures_shower_low_flow', true)
    arg.setDisplayName('Hot Water Fixtures: Is Shower Low Flow')
    arg.setDescription('Whether the shower fixture is low flow.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('water_fixtures_sink_low_flow', true)
    arg.setDisplayName('Hot Water Fixtures: Is Sink Low Flow')
    arg.setDescription('Whether the sink fixture is low flow.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('water_fixtures_usage_multiplier', true)
    arg.setDisplayName('Hot Water Fixtures: Usage Multiplier')
    arg.setDescription('Multiplier on the hot water usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    solar_thermal_system_type_choices = OpenStudio::StringVector.new
    solar_thermal_system_type_choices << 'none'
    solar_thermal_system_type_choices << 'hot water'

    solar_thermal_collector_loop_type_choices = OpenStudio::StringVector.new
    solar_thermal_collector_loop_type_choices << HPXML::SolarThermalLoopTypeDirect
    solar_thermal_collector_loop_type_choices << HPXML::SolarThermalLoopTypeIndirect
    solar_thermal_collector_loop_type_choices << HPXML::SolarThermalLoopTypeThermosyphon

    solar_thermal_collector_type_choices = OpenStudio::StringVector.new
    solar_thermal_collector_type_choices << HPXML::SolarThermalTypeEvacuatedTube
    solar_thermal_collector_type_choices << HPXML::SolarThermalTypeSingleGlazing
    solar_thermal_collector_type_choices << HPXML::SolarThermalTypeDoubleGlazing
    solar_thermal_collector_type_choices << HPXML::SolarThermalTypeICS

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('solar_thermal_system_type', solar_thermal_system_type_choices, true)
    arg.setDisplayName('Solar Thermal: System Type')
    arg.setDescription("The type of solar thermal system. Use 'none' if there is no solar thermal system.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('solar_thermal_collector_area', true)
    arg.setDisplayName('Solar Thermal: Collector Area')
    arg.setUnits('ft^2')
    arg.setDescription('The collector area of the solar thermal system.')
    arg.setDefaultValue(40.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('solar_thermal_collector_loop_type', solar_thermal_collector_loop_type_choices, true)
    arg.setDisplayName('Solar Thermal: Collector Loop Type')
    arg.setDescription('The collector loop type of the solar thermal system.')
    arg.setDefaultValue(HPXML::SolarThermalLoopTypeDirect)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('solar_thermal_collector_type', solar_thermal_collector_type_choices, true)
    arg.setDisplayName('Solar Thermal: Collector Type')
    arg.setDescription('The collector type of the solar thermal system.')
    arg.setDefaultValue(HPXML::SolarThermalTypeEvacuatedTube)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('solar_thermal_collector_azimuth', true)
    arg.setDisplayName('Solar Thermal: Collector Azimuth')
    arg.setUnits('degrees')
    arg.setDescription('The collector azimuth of the solar thermal system. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).')
    arg.setDefaultValue(180)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('solar_thermal_collector_tilt', true)
    arg.setDisplayName('Solar Thermal: Collector Tilt')
    arg.setUnits('degrees')
    arg.setDescription('The collector tilt of the solar thermal system. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.')
    arg.setDefaultValue('RoofPitch')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('solar_thermal_collector_rated_optical_efficiency', true)
    arg.setDisplayName('Solar Thermal: Collector Rated Optical Efficiency')
    arg.setUnits('Frac')
    arg.setDescription('The collector rated optical efficiency of the solar thermal system.')
    arg.setDefaultValue(0.5)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('solar_thermal_collector_rated_thermal_losses', true)
    arg.setDisplayName('Solar Thermal: Collector Rated Thermal Losses')
    arg.setUnits('Frac')
    arg.setDescription('The collector rated thermal losses of the solar thermal system.')
    arg.setDefaultValue(0.2799)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('solar_thermal_storage_volume', true)
    arg.setDisplayName('Solar Thermal: Storage Volume')
    arg.setUnits('Frac')
    arg.setDescription('The storage volume of the solar thermal system.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('solar_thermal_solar_fraction', true)
    arg.setDisplayName('Solar Thermal: Solar Fraction')
    arg.setUnits('Frac')
    arg.setDescription('The solar fraction of the solar thermal system. If provided, overrides all other solar thermal inputs.')
    arg.setDefaultValue(0)
    args << arg

    pv_system_module_type_choices = OpenStudio::StringVector.new
    pv_system_module_type_choices << 'none'
    pv_system_module_type_choices << Constants.Auto
    pv_system_module_type_choices << HPXML::PVModuleTypeStandard
    pv_system_module_type_choices << HPXML::PVModuleTypePremium
    pv_system_module_type_choices << HPXML::PVModuleTypeThinFilm

    pv_system_location_choices = OpenStudio::StringVector.new
    pv_system_location_choices << Constants.Auto
    pv_system_location_choices << HPXML::LocationRoof
    pv_system_location_choices << HPXML::LocationGround

    pv_system_tracking_choices = OpenStudio::StringVector.new
    pv_system_tracking_choices << Constants.Auto
    pv_system_tracking_choices << HPXML::PVTrackingTypeFixed
    pv_system_tracking_choices << HPXML::PVTrackingType1Axis
    pv_system_tracking_choices << HPXML::PVTrackingType1AxisBacktracked
    pv_system_tracking_choices << HPXML::PVTrackingType2Axis

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_system_module_type_1', pv_system_module_type_choices, true)
    arg.setDisplayName('Photovoltaics 1: Module Type')
    arg.setDescription("Module type of the PV system 1. Use 'none' if there is no PV system 1.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_system_location_1', pv_system_location_choices, true)
    arg.setDisplayName('Photovoltaics 1: Location')
    arg.setDescription('Location of the PV system 1.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_system_tracking_1', pv_system_tracking_choices, true)
    arg.setDisplayName('Photovoltaics 1: Tracking')
    arg.setDescription('Tracking of the PV system 1.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_array_azimuth_1', true)
    arg.setDisplayName('Photovoltaics 1: Array Azimuth')
    arg.setUnits('degrees')
    arg.setDescription('Array azimuth of the PV system 1. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).')
    arg.setDefaultValue(180)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('pv_system_array_tilt_1', true)
    arg.setDisplayName('Photovoltaics 1: Array Tilt')
    arg.setUnits('degrees')
    arg.setDescription('Array tilt of the PV system 1. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.')
    arg.setDefaultValue('RoofPitch')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_max_power_output_1', true)
    arg.setDisplayName('Photovoltaics 1: Maximum Power Output')
    arg.setUnits('W')
    arg.setDescription('Maximum power output of the PV system 1. For a shared system, this is the total building maximum power output.')
    arg.setDefaultValue(4000)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_inverter_efficiency_1', false)
    arg.setDisplayName('Photovoltaics 1: Inverter Efficiency')
    arg.setUnits('Frac')
    arg.setDescription('Inverter efficiency of the PV system 1.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_system_losses_fraction_1', false)
    arg.setDisplayName('Photovoltaics 1: System Losses Fraction')
    arg.setUnits('Frac')
    arg.setDescription('System losses fraction of the PV system 1.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('pv_system_num_units_served_1', true)
    arg.setDisplayName('Photovoltaics 1: Number of Units Served')
    arg.setDescription("Number of dwelling units served by PV system 1. Must be 1 if #{HPXML::ResidentialTypeSFD}. Used to apportion PV generation to the unit.")
    arg.setUnits('#')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_system_module_type_2', pv_system_module_type_choices, true)
    arg.setDisplayName('Photovoltaics 2: Module Type')
    arg.setDescription("Module type of the PV system 2. Use 'none' if there is no PV system 2.")
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_system_location_2', pv_system_location_choices, true)
    arg.setDisplayName('Photovoltaics 2: Location')
    arg.setDescription('Location of the PV system 2.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pv_system_tracking_2', pv_system_tracking_choices, true)
    arg.setDisplayName('Photovoltaics 2: Tracking')
    arg.setDescription('Tracking of the PV system 2.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_array_azimuth_2', true)
    arg.setDisplayName('Photovoltaics 2: Array Azimuth')
    arg.setUnits('degrees')
    arg.setDescription('Array azimuth of the PV system 2. Azimuth is measured clockwise from north (e.g., North=0, East=90, South=180, West=270).')
    arg.setDefaultValue(180)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('pv_system_array_tilt_2', true)
    arg.setDisplayName('Photovoltaics 2: Array Tilt')
    arg.setUnits('degrees')
    arg.setDescription('Array tilt of the PV system 2. Can also enter, e.g., RoofPitch, RoofPitch+20, Latitude, Latitude-15, etc.')
    arg.setDefaultValue('RoofPitch')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_max_power_output_2', true)
    arg.setDisplayName('Photovoltaics 2: Maximum Power Output')
    arg.setUnits('W')
    arg.setDescription('Maximum power output of the PV system 2. For a shared system, this is the total building maximum power output.')
    arg.setDefaultValue(4000)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_inverter_efficiency_2', false)
    arg.setDisplayName('Photovoltaics 2: Inverter Efficiency')
    arg.setUnits('Frac')
    arg.setDescription('Inverter efficiency of the PV system 2.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pv_system_system_losses_fraction_2', false)
    arg.setDisplayName('Photovoltaics 2: System Losses Fraction')
    arg.setUnits('Frac')
    arg.setDescription('System losses fraction of the PV system 2.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument('pv_system_num_units_served_2', true)
    arg.setDisplayName('Photovoltaics 2: Number of Units Served')
    arg.setDescription("Number of dwelling units served by PV system 2. Must be 1 if #{HPXML::ResidentialTypeSFD}. Used to apportion PV generation to the unit.")
    arg.setUnits('#')
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_fraction_cfl_interior', true)
    arg.setDisplayName('Lighting: Fraction CFL Interior')
    arg.setDescription('Fraction of all lamps (interior) that are compact fluorescent. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.4)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_fraction_lfl_interior', true)
    arg.setDisplayName('Lighting: Fraction LFL Interior')
    arg.setDescription('Fraction of all lamps (interior) that are linear fluorescent. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_fraction_led_interior', true)
    arg.setDisplayName('Lighting: Fraction LED Interior')
    arg.setDescription('Fraction of all lamps (interior) that are light emitting diodes. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.25)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_usage_multiplier_interior', true)
    arg.setDisplayName('Lighting: Usage Multiplier Interior')
    arg.setDescription('Multiplier on the lighting energy usage (interior) that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_fraction_cfl_exterior', true)
    arg.setDisplayName('Lighting: Fraction CFL Exterior')
    arg.setDescription('Fraction of all lamps (exterior) that are compact fluorescent. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.4)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_fraction_lfl_exterior', true)
    arg.setDisplayName('Lighting: Fraction LFL Exterior')
    arg.setDescription('Fraction of all lamps (exterior) that are linear fluorescent. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_fraction_led_exterior', true)
    arg.setDisplayName('Lighting: Fraction LED Exterior')
    arg.setDescription('Fraction of all lamps (exterior) that are light emitting diodes. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.25)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_usage_multiplier_exterior', true)
    arg.setDisplayName('Lighting: Usage Multiplier Exterior')
    arg.setDescription('Multiplier on the lighting energy usage (exterior) that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_fraction_cfl_garage', true)
    arg.setDisplayName('Lighting: Fraction CFL Garage')
    arg.setDescription('Fraction of all lamps (garage) that are compact fluorescent. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.4)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_fraction_lfl_garage', true)
    arg.setDisplayName('Lighting: Fraction LFL Garage')
    arg.setDescription('Fraction of all lamps (garage) that are linear fluorescent. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_fraction_led_garage', true)
    arg.setDisplayName('Lighting: Fraction LED Garage')
    arg.setDescription('Fraction of all lamps (garage) that are light emitting diodes. Lighting not specified as CFL, LFL, or LED is assumed to be incandescent.')
    arg.setDefaultValue(0.25)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('lighting_usage_multiplier_garage', true)
    arg.setDisplayName('Lighting: Usage Multiplier Garage')
    arg.setDescription('Multiplier on the lighting energy usage (garage) that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('holiday_lighting_present', true)
    arg.setDisplayName('Holiday Lighting: Present')
    arg.setDescription('Whether there is holiday lighting.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('holiday_lighting_daily_kwh', true)
    arg.setDisplayName('Holiday Lighting: Daily Consumption')
    arg.setUnits('kWh/day')
    arg.setDescription('The daily energy consumption for holiday lighting (exterior).')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('holiday_lighting_period_begin_month', true)
    arg.setDisplayName('Holiday Lighting: Period Begin Month')
    arg.setUnits('month')
    arg.setDescription('This numeric field should contain the starting month number (1 = January, 2 = February, etc.) for the holiday lighting period desired.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('holiday_lighting_period_begin_day_of_month', true)
    arg.setDisplayName('Holiday Lighting: Period Begin Day of Month')
    arg.setUnits('day')
    arg.setDescription('This numeric field should contain the starting day of the starting month (must be valid for month) for the holiday lighting period desired.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('holiday_lighting_period_end_month', true)
    arg.setDisplayName('Holiday Lighting: Period End Month')
    arg.setUnits('month')
    arg.setDescription('This numeric field should contain the end month number (1 = January, 2 = February, etc.) for the holiday lighting period desired.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('holiday_lighting_period_end_day_of_month', true)
    arg.setDisplayName('Holiday Lighting: Period End Day of Month')
    arg.setUnits('day')
    arg.setDescription('This numeric field should contain the ending day of the ending month (must be valid for month) for the holiday lighting period desired.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    dehumidifier_type_choices = OpenStudio::StringVector.new
    dehumidifier_type_choices << 'none'
    dehumidifier_type_choices << HPXML::DehumidifierTypePortable
    dehumidifier_type_choices << HPXML::DehumidifierTypeWholeHome

    dehumidifier_efficiency_type_choices = OpenStudio::StringVector.new
    dehumidifier_efficiency_type_choices << 'EnergyFactor'
    dehumidifier_efficiency_type_choices << 'IntegratedEnergyFactor'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('dehumidifier_type', dehumidifier_type_choices, true)
    arg.setDisplayName('Dehumidifier: Type')
    arg.setDescription('The type of dehumidifier.')
    arg.setDefaultValue('none')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('dehumidifier_efficiency_type', dehumidifier_efficiency_type_choices, true)
    arg.setDisplayName('Dehumidifier: Efficiency Type')
    arg.setDescription('The efficiency type of dehumidifier.')
    arg.setDefaultValue('IntegratedEnergyFactor')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dehumidifier_efficiency', true)
    arg.setDisplayName('Dehumidifier: Efficiency')
    arg.setUnits('liters/kWh')
    arg.setDescription('The efficiency of the dehumidifier.')
    arg.setDefaultValue(1.5)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dehumidifier_capacity', true)
    arg.setDisplayName('Dehumidifier: Capacity')
    arg.setDescription('The capacity (water removal rate) of the dehumidifier.')
    arg.setUnits('pint/day')
    arg.setDefaultValue(40)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dehumidifier_rh_setpoint', true)
    arg.setDisplayName('Dehumidifier: Relative Humidity Setpoint')
    arg.setDescription('The relative humidity setpoint of the dehumidifier.')
    arg.setUnits('Frac')
    arg.setDefaultValue(0.5)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dehumidifier_fraction_dehumidification_load_served', true)
    arg.setDisplayName('Dehumidifier: Fraction Dehumidification Load Served')
    arg.setDescription('The dehumidification load served fraction of the dehumidifier.')
    arg.setUnits('Frac')
    arg.setDefaultValue(1)
    args << arg

    appliance_location_choices = OpenStudio::StringVector.new
    appliance_location_choices << Constants.Auto
    appliance_location_choices << 'none'
    appliance_location_choices << HPXML::LocationLivingSpace
    appliance_location_choices << HPXML::LocationBasementConditioned
    appliance_location_choices << HPXML::LocationBasementUnconditioned
    appliance_location_choices << HPXML::LocationGarage
    appliance_location_choices << HPXML::LocationOtherHousingUnit
    appliance_location_choices << HPXML::LocationOtherHeatedSpace
    appliance_location_choices << HPXML::LocationOtherMultifamilyBufferSpace
    appliance_location_choices << HPXML::LocationOtherNonFreezingSpace

    clothes_washer_efficiency_type_choices = OpenStudio::StringVector.new
    clothes_washer_efficiency_type_choices << 'ModifiedEnergyFactor'
    clothes_washer_efficiency_type_choices << 'IntegratedModifiedEnergyFactor'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('clothes_washer_location', appliance_location_choices, true)
    arg.setDisplayName('Clothes Washer: Location')
    arg.setDescription('The space type for the clothes washer location.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('clothes_washer_efficiency_type', clothes_washer_efficiency_type_choices, true)
    arg.setDisplayName('Clothes Washer: Efficiency Type')
    arg.setDescription('The efficiency type of the clothes washer.')
    arg.setDefaultValue('IntegratedModifiedEnergyFactor')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('clothes_washer_efficiency', true)
    arg.setDisplayName('Clothes Washer: Efficiency')
    arg.setUnits('ft^3/kWh-cyc')
    arg.setDescription('The efficiency of the clothes washer.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('clothes_washer_rated_annual_kwh', true)
    arg.setDisplayName('Clothes Washer: Rated Annual Consumption')
    arg.setUnits('kWh/yr')
    arg.setDescription('The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('clothes_washer_label_electric_rate', true)
    arg.setDisplayName('Clothes Washer: Label Electric Rate')
    arg.setUnits('$/kWh')
    arg.setDescription('The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('clothes_washer_label_gas_rate', true)
    arg.setDisplayName('Clothes Washer: Label Gas Rate')
    arg.setUnits('$/therm')
    arg.setDescription('The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('clothes_washer_label_annual_gas_cost', true)
    arg.setDisplayName('Clothes Washer: Label Annual Cost with Gas DHW')
    arg.setUnits('$')
    arg.setDescription('The annual cost of using the system under test conditions. Input is obtained from the EnergyGuide label.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('clothes_washer_label_usage', true)
    arg.setDisplayName('Clothes Washer: Label Usage')
    arg.setUnits('cyc/wk')
    arg.setDescription('The clothes washer loads per week.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('clothes_washer_capacity', true)
    arg.setDisplayName('Clothes Washer: Drum Volume')
    arg.setUnits('ft^3')
    arg.setDescription("Volume of the washer drum. Obtained from the EnergyStar website or the manufacturer's literature.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_washer_usage_multiplier', true)
    arg.setDisplayName('Clothes Washer: Usage Multiplier')
    arg.setDescription('Multiplier on the clothes washer energy and hot water usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('clothes_dryer_location', appliance_location_choices, true)
    arg.setDisplayName('Clothes Dryer: Location')
    arg.setDescription('The space type for the clothes dryer location.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    clothes_dryer_fuel_choices = OpenStudio::StringVector.new
    clothes_dryer_fuel_choices << HPXML::FuelTypeElectricity
    clothes_dryer_fuel_choices << HPXML::FuelTypeNaturalGas
    clothes_dryer_fuel_choices << HPXML::FuelTypeOil
    clothes_dryer_fuel_choices << HPXML::FuelTypePropane
    clothes_dryer_fuel_choices << HPXML::FuelTypeWoodCord
    clothes_dryer_fuel_choices << HPXML::FuelTypeCoal

    clothes_dryer_efficiency_type_choices = OpenStudio::StringVector.new
    clothes_dryer_efficiency_type_choices << 'EnergyFactor'
    clothes_dryer_efficiency_type_choices << 'CombinedEnergyFactor'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('clothes_dryer_fuel_type', clothes_dryer_fuel_choices, true)
    arg.setDisplayName('Clothes Dryer: Fuel Type')
    arg.setDescription('Type of fuel used by the clothes dryer.')
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('clothes_dryer_efficiency_type', clothes_dryer_efficiency_type_choices, true)
    arg.setDisplayName('Clothes Dryer: Efficiency Type')
    arg.setDescription('The efficiency type of the clothes dryer.')
    arg.setDefaultValue('CombinedEnergyFactor')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('clothes_dryer_efficiency', true)
    arg.setDisplayName('Clothes Dryer: Efficiency')
    arg.setUnits('lb/kWh')
    arg.setDescription('The efficiency of the clothes dryer.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('clothes_dryer_vented_flow_rate', true)
    arg.setDisplayName('Clothes Dryer: Vented Flow Rate')
    arg.setDescription('The exhaust flow rate of the vented clothes dryer.')
    arg.setUnits('CFM')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('clothes_dryer_usage_multiplier', true)
    arg.setDisplayName('Clothes Dryer: Usage Multiplier')
    arg.setDescription('Multiplier on the clothes dryer energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('dishwasher_location', appliance_location_choices, true)
    arg.setDisplayName('Dishwasher: Location')
    arg.setDescription('The space type for the dishwasher location.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    dishwasher_efficiency_type_choices = OpenStudio::StringVector.new
    dishwasher_efficiency_type_choices << 'RatedAnnualkWh'
    dishwasher_efficiency_type_choices << 'EnergyFactor'

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('dishwasher_efficiency_type', dishwasher_efficiency_type_choices, true)
    arg.setDisplayName('Dishwasher: Efficiency Type')
    arg.setDescription('The efficiency type of dishwasher.')
    arg.setDefaultValue('RatedAnnualkWh')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('dishwasher_efficiency', true)
    arg.setDisplayName('Dishwasher: Efficiency')
    arg.setUnits('RatedAnnualkWh or EnergyFactor')
    arg.setDescription('The efficiency of the dishwasher.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('dishwasher_label_electric_rate', true)
    arg.setDisplayName('Dishwasher: Label Electric Rate')
    arg.setUnits('$/kWh')
    arg.setDescription('The label electric rate of the dishwasher.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('dishwasher_label_gas_rate', true)
    arg.setDisplayName('Dishwasher: Label Gas Rate')
    arg.setUnits('$/therm')
    arg.setDescription('The label gas rate of the dishwasher.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('dishwasher_label_annual_gas_cost', true)
    arg.setDisplayName('Dishwasher: Label Annual Gas Cost')
    arg.setUnits('$')
    arg.setDescription('The label annual gas cost of the dishwasher.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('dishwasher_label_usage', true)
    arg.setDisplayName('Dishwasher: Label Usage')
    arg.setUnits('cyc/wk')
    arg.setDescription('The dishwasher loads per week.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('dishwasher_place_setting_capacity', true)
    arg.setDisplayName('Dishwasher: Number of Place Settings')
    arg.setUnits('#')
    arg.setDescription("The number of place settings for the unit. Data obtained from manufacturer's literature.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('dishwasher_usage_multiplier', true)
    arg.setDisplayName('Dishwasher: Usage Multiplier')
    arg.setDescription('Multiplier on the dishwasher energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('refrigerator_location', appliance_location_choices, true)
    arg.setDisplayName('Refrigerator: Location')
    arg.setDescription('The space type for the refrigerator location.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('refrigerator_rated_annual_kwh', true)
    arg.setDisplayName('Refrigerator: Rated Annual Consumption')
    arg.setUnits('kWh/yr')
    arg.setDescription('The EnergyGuide rated annual energy consumption for a refrigerator.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('refrigerator_usage_multiplier', true)
    arg.setDisplayName('Refrigerator: Usage Multiplier')
    arg.setDescription('Multiplier on the refrigerator energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('extra_refrigerator_location', appliance_location_choices, true)
    arg.setDisplayName('Extra Refrigerator: Location')
    arg.setDescription('The space type for the extra refrigerator location.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('extra_refrigerator_rated_annual_kwh', true)
    arg.setDisplayName('Extra Refrigerator: Rated Annual Consumption')
    arg.setUnits('kWh/yr')
    arg.setDescription('The EnergyGuide rated annual energy consumption for an extra rrefrigerator.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('extra_refrigerator_usage_multiplier', true)
    arg.setDisplayName('Extra Refrigerator: Usage Multiplier')
    arg.setDescription('Multiplier on the extra refrigerator energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('freezer_location', appliance_location_choices, true)
    arg.setDisplayName('Freezer: Location')
    arg.setDescription('The space type for the freezer location.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('freezer_rated_annual_kwh', true)
    arg.setDisplayName('Freezer: Rated Annual Consumption')
    arg.setUnits('kWh/yr')
    arg.setDescription('The EnergyGuide rated annual energy consumption for a freezer.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('freezer_usage_multiplier', true)
    arg.setDisplayName('Freezer: Usage Multiplier')
    arg.setDescription('Multiplier on the freezer energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    cooking_range_oven_fuel_choices = OpenStudio::StringVector.new
    cooking_range_oven_fuel_choices << HPXML::FuelTypeElectricity
    cooking_range_oven_fuel_choices << HPXML::FuelTypeNaturalGas
    cooking_range_oven_fuel_choices << HPXML::FuelTypeOil
    cooking_range_oven_fuel_choices << HPXML::FuelTypePropane
    cooking_range_oven_fuel_choices << HPXML::FuelTypeWoodCord
    cooking_range_oven_fuel_choices << HPXML::FuelTypeCoal

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('cooking_range_oven_location', appliance_location_choices, true)
    arg.setDisplayName('Cooking Range/Oven: Location')
    arg.setDescription('The space type for the cooking range/oven location.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('cooking_range_oven_fuel_type', cooking_range_oven_fuel_choices, true)
    arg.setDisplayName('Cooking Range/Oven: Fuel Type')
    arg.setDescription('Type of fuel used by the cooking range/oven.')
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('cooking_range_oven_is_induction', false)
    arg.setDisplayName('Cooking Range/Oven: Is Induction')
    arg.setDescription('Whether the cooking range is induction.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('cooking_range_oven_is_convection', false)
    arg.setDisplayName('Cooking Range/Oven: Is Convection')
    arg.setDescription('Whether the oven is convection.')
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('cooking_range_oven_usage_multiplier', true)
    arg.setDisplayName('Cooking Range/Oven: Usage Multiplier')
    arg.setDescription('Multiplier on the cooking range/oven energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('ceiling_fan_present', true)
    arg.setDisplayName('Ceiling Fan: Present')
    arg.setDescription('Whether there is are any ceiling fans.')
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('ceiling_fan_efficiency', true)
    arg.setDisplayName('Ceiling Fan: Efficiency')
    arg.setUnits('CFM/W')
    arg.setDescription('The efficiency rating of the ceiling fan(s) at medium speed.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('ceiling_fan_quantity', true)
    arg.setDisplayName('Ceiling Fan: Quantity')
    arg.setUnits('#')
    arg.setDescription('Total number of ceiling fans.')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('ceiling_fan_cooling_setpoint_temp_offset', true)
    arg.setDisplayName('Ceiling Fan: Cooling Setpoint Temperature Offset')
    arg.setUnits('deg-F')
    arg.setDescription('The setpoint temperature offset during cooling season for the ceiling fan(s). Only applies if ceiling fan quantity is greater than zero.')
    arg.setDefaultValue(0.5)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('plug_loads_television_annual_kwh', true)
    arg.setDisplayName('Plug Loads: Television Annual kWh')
    arg.setDescription('The annual energy consumption of the television plug loads.')
    arg.setUnits('kWh/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('plug_loads_television_usage_multiplier', true)
    arg.setDisplayName('Plug Loads: Television Usage Multiplier')
    arg.setDescription('Multiplier on the television energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('plug_loads_other_annual_kwh', true)
    arg.setDisplayName('Plug Loads: Other Annual kWh')
    arg.setDescription('The annual energy consumption of the other residual plug loads.')
    arg.setUnits('kWh/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('plug_loads_other_frac_sensible', true)
    arg.setDisplayName('Plug Loads: Other Sensible Fraction')
    arg.setDescription("Fraction of other residual plug loads' internal gains that are sensible.")
    arg.setUnits('Frac')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('plug_loads_other_frac_latent', true)
    arg.setDisplayName('Plug Loads: Other Latent Fraction')
    arg.setDescription("Fraction of other residual plug loads' internal gains that are latent.")
    arg.setUnits('Frac')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('plug_loads_other_usage_multiplier', true)
    arg.setDisplayName('Plug Loads: Other Usage Multiplier')
    arg.setDescription('Multiplier on the other energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('plug_loads_well_pump_present', true)
    arg.setDisplayName('Plug Loads: Well Pump Present')
    arg.setDescription('Whether there is a well pump.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('plug_loads_well_pump_annual_kwh', true)
    arg.setDisplayName('Plug Loads: Well Pump Annual kWh')
    arg.setDescription('The annual energy consumption of the well pump plug loads.')
    arg.setUnits('kWh/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('plug_loads_well_pump_usage_multiplier', true)
    arg.setDisplayName('Plug Loads: Well Pump Usage Multiplier')
    arg.setDescription('Multiplier on the well pump energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('plug_loads_vehicle_present', true)
    arg.setDisplayName('Plug Loads: Vehicle Present')
    arg.setDescription('Whether there is an electric vehicle.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('plug_loads_vehicle_annual_kwh', true)
    arg.setDisplayName('Plug Loads: Vehicle Annual kWh')
    arg.setDescription('The annual energy consumption of the electric vehicle plug loads.')
    arg.setUnits('kWh/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('plug_loads_vehicle_usage_multiplier', true)
    arg.setDisplayName('Plug Loads: Vehicle Usage Multiplier')
    arg.setDescription('Multiplier on the electric vehicle energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    fuel_loads_fuel_choices = OpenStudio::StringVector.new
    fuel_loads_fuel_choices << HPXML::FuelTypeNaturalGas
    fuel_loads_fuel_choices << HPXML::FuelTypeOil
    fuel_loads_fuel_choices << HPXML::FuelTypePropane
    fuel_loads_fuel_choices << HPXML::FuelTypeWoodCord
    fuel_loads_fuel_choices << HPXML::FuelTypeWoodPellets

    fuel_loads_location_choices = OpenStudio::StringVector.new
    fuel_loads_location_choices << Constants.Auto
    fuel_loads_location_choices << HPXML::LocationInterior
    fuel_loads_location_choices << HPXML::LocationExterior

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('fuel_loads_grill_present', true)
    arg.setDisplayName('Fuel Loads: Grill Present')
    arg.setDescription('Whether there is a fuel loads grill.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('fuel_loads_grill_fuel_type', fuel_loads_fuel_choices, true)
    arg.setDisplayName('Fuel Loads: Grill Fuel Type')
    arg.setDescription('The fuel type of the fuel loads grill.')
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('fuel_loads_grill_annual_therm', true)
    arg.setDisplayName('Fuel Loads: Grill Annual therm')
    arg.setDescription('The annual energy consumption of the fuel loads grill.')
    arg.setUnits('therm/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('fuel_loads_grill_usage_multiplier', true)
    arg.setDisplayName('Fuel Loads: Grill Usage Multiplier')
    arg.setDescription('Multiplier on the fuel loads grill energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('fuel_loads_lighting_present', true)
    arg.setDisplayName('Fuel Loads: Lighting Present')
    arg.setDescription('Whether there is fuel loads lighting.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('fuel_loads_lighting_fuel_type', fuel_loads_fuel_choices, true)
    arg.setDisplayName('Fuel Loads: Lighting Fuel Type')
    arg.setDescription('The fuel type of the fuel loads lighting.')
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('fuel_loads_lighting_annual_therm', true)
    arg.setDisplayName('Fuel Loads: Lighting Annual therm')
    arg.setDescription('The annual energy consumption of the fuel loads lighting.')
    arg.setUnits('therm/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('fuel_loads_lighting_usage_multiplier', true)
    arg.setDisplayName('Fuel Loads: Lighting Usage Multiplier')
    arg.setDescription('Multiplier on the fuel loads lighting energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('fuel_loads_fireplace_present', true)
    arg.setDisplayName('Fuel Loads: Fireplace Present')
    arg.setDescription('Whether there is fuel loads fireplace.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('fuel_loads_fireplace_fuel_type', fuel_loads_fuel_choices, true)
    arg.setDisplayName('Fuel Loads: Fireplace Fuel Type')
    arg.setDescription('The fuel type of the fuel loads fireplace.')
    arg.setDefaultValue(HPXML::FuelTypeNaturalGas)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('fuel_loads_fireplace_annual_therm', true)
    arg.setDisplayName('Fuel Loads: Fireplace Annual therm')
    arg.setDescription('The annual energy consumption of the fuel loads fireplace.')
    arg.setUnits('therm/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('fuel_loads_fireplace_frac_sensible', true)
    arg.setDisplayName('Fuel Loads: Fireplace Sensible Fraction')
    arg.setDescription("Fraction of fireplace residual fuel loads' internal gains that are sensible.")
    arg.setUnits('Frac')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('fuel_loads_fireplace_frac_latent', true)
    arg.setDisplayName('Fuel Loads: Fireplace Latent Fraction')
    arg.setDescription("Fraction of fireplace residual fuel loads' internal gains that are latent.")
    arg.setUnits('Frac')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('fuel_loads_fireplace_usage_multiplier', true)
    arg.setDisplayName('Fuel Loads: Fireplace Usage Multiplier')
    arg.setDescription('Multiplier on the fuel loads fireplace energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(0.0)
    args << arg

    heater_type_choices = OpenStudio::StringVector.new
    heater_type_choices << HPXML::TypeNone
    heater_type_choices << HPXML::HeaterTypeElectricResistance
    heater_type_choices << HPXML::HeaterTypeGas
    heater_type_choices << HPXML::HeaterTypeHeatPump

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('pool_present', true)
    arg.setDisplayName('Pool: Present')
    arg.setDescription('Whether there is a pool.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('pool_pump_annual_kwh', true)
    arg.setDisplayName('Pool: Pump Annual kWh')
    arg.setDescription('The annual energy consumption of the pool pump.')
    arg.setUnits('kWh/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_pump_usage_multiplier', true)
    arg.setDisplayName('Pool: Pump Usage Multiplier')
    arg.setDescription('Multiplier on the pool pump energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('pool_heater_type', heater_type_choices, true)
    arg.setDisplayName('Pool: Heater Type')
    arg.setDescription("The type of pool heater. Use 'none' if there is no pool heater.")
    arg.setDefaultValue(HPXML::TypeNone)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('pool_heater_annual_kwh', true)
    arg.setDisplayName('Pool: Heater Annual kWh')
    arg.setDescription("The annual energy consumption of the #{HPXML::HeaterTypeElectricResistance} pool heater.")
    arg.setUnits('kWh/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('pool_heater_annual_therm', true)
    arg.setDisplayName('Pool: Heater Annual therm')
    arg.setDescription("The annual energy consumption of the #{HPXML::HeaterTypeGas} pool heater.")
    arg.setUnits('therm/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('pool_heater_usage_multiplier', true)
    arg.setDisplayName('Pool: Heater Usage Multiplier')
    arg.setDescription('Multiplier on the pool heater energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument('hot_tub_present', true)
    arg.setDisplayName('Hot Tub: Present')
    arg.setDescription('Whether there is a hot tub.')
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('hot_tub_pump_annual_kwh', true)
    arg.setDisplayName('Hot Tub: Pump Annual kWh')
    arg.setDescription('The annual energy consumption of the hot tub pump.')
    arg.setUnits('kWh/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_pump_usage_multiplier', true)
    arg.setDisplayName('Hot Tub: Pump Usage Multiplier')
    arg.setDescription('Multiplier on the hot tub pump energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument('hot_tub_heater_type', heater_type_choices, true)
    arg.setDisplayName('Hot Tub: Heater Type')
    arg.setDescription("The type of hot tub heater. Use 'none' if there is no hot tub heater.")
    arg.setDefaultValue(HPXML::TypeNone)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('hot_tub_heater_annual_kwh', true)
    arg.setDisplayName('Hot Tub: Heater Annual kWh')
    arg.setDescription("The annual energy consumption of the #{HPXML::HeaterTypeElectricResistance} hot tub heater.")
    arg.setUnits('kWh/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument('hot_tub_heater_annual_therm', true)
    arg.setDisplayName('Hot Tub: Heater Annual therm')
    arg.setDescription("The annual energy consumption of the #{HPXML::HeaterTypeGas} hot tub heater.")
    arg.setUnits('therm/yr')
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument('hot_tub_heater_usage_multiplier', true)
    arg.setDisplayName('Hot Tub: Heater Usage Multiplier')
    arg.setDescription('Multiplier on the hot tub heater energy usage that can reflect, e.g., high/low usage occupants.')
    arg.setDefaultValue(1.0)
    args << arg

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    Geometry.tear_down_model(model, runner)

    Version.check_openstudio_version()

    # assign the user inputs to variables
    args = get_argument_values(runner, arguments(model), user_arguments)
    args = Hash[args.collect { |k, v| [k.to_sym, v] }]
    args[:geometry_rim_joist_height] /= 12.0
    args[:geometry_roof_pitch] = { '1:12' => 1.0 / 12.0, '2:12' => 2.0 / 12.0, '3:12' => 3.0 / 12.0, '4:12' => 4.0 / 12.0, '5:12' => 5.0 / 12.0, '6:12' => 6.0 / 12.0, '7:12' => 7.0 / 12.0, '8:12' => 8.0 / 12.0, '9:12' => 9.0 / 12.0, '10:12' => 10.0 / 12.0, '11:12' => 11.0 / 12.0, '12:12' => 12.0 / 12.0 }[args[:geometry_roof_pitch]]

    # Argument error checks
    warnings, errors = validate_arguments(args)
    unless warnings.empty?
      warnings.each do |warning|
        runner.registerWarning(warning)
      end
    end
    unless errors.empty?
      errors.each do |error|
        runner.registerError(error)
      end
      return false
    end

    # Create EpwFile object
    epw_path = args[:weather_station_epw_filepath]
    if not File.exist? epw_path
      epw_path = File.join(File.expand_path(File.join(File.dirname(__FILE__), '..', 'weather')), epw_path) # a filename was entered for weather_station_epw_filepath
    end
    if not File.exist? epw_path
      runner.registerError("Could not find EPW file at '#{epw_path}'.")
      return false
    end
    epw_file = OpenStudio::EpwFile.new(epw_path)

    # Create HPXML file
    hpxml_doc = HPXMLFile.create(runner, model, args, epw_file)
    if not hpxml_doc
      runner.registerError('Unsuccessful creation of HPXML file.')
      return false
    end

    hpxml_path = args[:hpxml_path]
    unless (Pathname.new hpxml_path).absolute?
      hpxml_path = File.expand_path(File.join(File.dirname(__FILE__), hpxml_path))
    end

    # Check for invalid HPXML file
    skip_validation = false
    if not skip_validation
      if not validate_hpxml(runner, hpxml_path, hpxml_doc)
        return false
      end
    end

    XMLHelper.write_file(hpxml_doc, hpxml_path)
    runner.registerInfo("Wrote file: #{hpxml_path}")
  end

  def validate_arguments(args)
    warnings = []
    errors = []

    # heat pump water heater with natural gas fuel type
    warning = ([HPXML::WaterHeaterTypeHeatPump].include?(args[:water_heater_type]) && (args[:water_heater_fuel_type] != HPXML::FuelTypeElectricity))
    warnings << "water_heater_type=#{args[:water_heater_type]} and water_heater_fuel_type=#{args[:water_heater_fuel_type]}" if warning

    # heating system and heat pump
    error = (args[:heating_system_type] != 'none') && (args[:heat_pump_type] != 'none') && (args[:heating_system_fraction_heat_load_served] > 0) && (args[:heat_pump_fraction_heat_load_served] > 0)
    errors << "heating_system_type=#{args[:heating_system_type]} and heat_pump_type=#{args[:heat_pump_type]}" if error

    # cooling system and heat pump
    error = (args[:cooling_system_type] != 'none') && (args[:heat_pump_type] != 'none') && (args[:cooling_system_fraction_cool_load_served] > 0) && (args[:heat_pump_fraction_cool_load_served] > 0)
    errors << "cooling_system_type=#{args[:cooling_system_type]} and heat_pump_type=#{args[:heat_pump_type]}" if error

    # non integer number of bathrooms
    if args[:geometry_num_bathrooms] != Constants.Auto
      error = (Float(args[:geometry_num_bathrooms]) % 1 != 0)
      errors << "geometry_num_bathrooms=#{args[:geometry_num_bathrooms]}" if error
    end

    # non integer ceiling fan quantity
    if args[:ceiling_fan_quantity] != Constants.Auto
      error = (Float(args[:ceiling_fan_quantity]) % 1 != 0)
      errors << "ceiling_fan_quantity=#{args[:ceiling_fan_quantity]}" if error
    end

    # single-family, slab, foundation height > 0
    warning = [HPXML::ResidentialTypeSFD, HPXML::ResidentialTypeSFA].include?(args[:geometry_unit_type]) && (args[:geometry_foundation_type] == HPXML::FoundationTypeSlab) && (args[:geometry_foundation_height] > 0)
    warnings << "geometry_unit_type=#{args[:geometry_unit_type]} and geometry_foundation_type=#{args[:geometry_foundation_type]} and geometry_foundation_height=#{args[:geometry_foundation_height]}" if warning

    # single-family, non slab, foundation height = 0
    error = [HPXML::ResidentialTypeSFD, HPXML::ResidentialTypeSFA].include?(args[:geometry_unit_type]) && (args[:geometry_foundation_type] != HPXML::FoundationTypeSlab) && (args[:geometry_foundation_height] == 0)
    errors << "geometry_unit_type=#{args[:geometry_unit_type]} and geometry_foundation_type=#{args[:geometry_foundation_type]} and geometry_foundation_height=#{args[:geometry_foundation_height]}" if error

    # single-family attached, multifamily and ambient foundation
    error = [HPXML::ResidentialTypeSFA, HPXML::ResidentialTypeApartment].include?(args[:geometry_unit_type]) && (args[:geometry_foundation_type] == HPXML::FoundationTypeAmbient)
    errors << "geometry_unit_type=#{args[:geometry_unit_type]} and geometry_foundation_type=#{args[:geometry_foundation_type]}" if error

    # multifamily, bottom, slab, foundation height > 0
    if args[:geometry_level].is_initialized
      warning = (args[:geometry_unit_type] == HPXML::ResidentialTypeApartment) && (args[:geometry_level].get == 'Bottom') && (args[:geometry_foundation_type] == HPXML::FoundationTypeSlab) && (args[:geometry_foundation_height] > 0)
      warnings << "geometry_unit_type=#{args[:geometry_unit_type]} and geometry_level=#{args[:geometry_level].get} and geometry_foundation_type=#{args[:geometry_foundation_type]} and geometry_foundation_height=#{args[:geometry_foundation_height]}" if warning
    end

    # multifamily, bottom, non slab, foundation height = 0
    if args[:geometry_level].is_initialized
      error = (args[:geometry_unit_type] == HPXML::ResidentialTypeApartment) && (args[:geometry_level].get == 'Bottom') && (args[:geometry_foundation_type] != HPXML::FoundationTypeSlab) && (args[:geometry_foundation_height] == 0)
      errors << "geometry_unit_type=#{args[:geometry_unit_type]} and geometry_level=#{args[:geometry_level].get} and geometry_foundation_type=#{args[:geometry_foundation_type]} and geometry_foundation_height=#{args[:geometry_foundation_height]}" if error
    end

    # multifamily and finished basement
    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeApartment) && (args[:geometry_foundation_type] == HPXML::FoundationTypeBasementConditioned)
    errors << "geometry_unit_type=#{args[:geometry_unit_type]} and geometry_foundation_type=#{args[:geometry_foundation_type]}" if error

    # slab and foundation height above grade > 0
    warning = (args[:geometry_foundation_type] == HPXML::FoundationTypeSlab) && (args[:geometry_foundation_height_above_grade] > 0)
    warnings << "geometry_foundation_type=#{args[:geometry_foundation_type]} and geometry_foundation_height_above_grade=#{args[:geometry_foundation_height_above_grade]}" if warning

    # duct location and surface area not both auto or not both specified
    error = ((args[:ducts_supply_location] == Constants.Auto) && (args[:ducts_supply_surface_area] != Constants.Auto)) || ((args[:ducts_supply_location] != Constants.Auto) && (args[:ducts_supply_surface_area] == Constants.Auto)) || ((args[:ducts_return_location] == Constants.Auto) && (args[:ducts_return_surface_area] != Constants.Auto)) || ((args[:ducts_return_location] != Constants.Auto) && (args[:ducts_return_surface_area] == Constants.Auto))
    errors << "ducts_supply_location=#{args[:ducts_supply_location]} and ducts_supply_surface_area=#{args[:ducts_supply_surface_area]} and ducts_return_location=#{args[:ducts_return_location]} and ducts_return_surface_area=#{args[:ducts_return_surface_area]}" if error

    # second heating system fraction heat load served non less than 50%
    warning = (args[:heating_system_type_2] != 'none') && (args[:heating_system_fraction_heat_load_served_2] >= 0.5) && (args[:heating_system_fraction_heat_load_served_2] < 1.0)
    warnings << "heating_system_type_2=#{args[:heating_system_type_2]} and heating_system_fraction_heat_load_served_2=#{args[:heating_system_fraction_heat_load_served_2]}" if warning

    # second heating system fraction heat load served is 100%
    error = (args[:heating_system_type_2] != 'none') && (args[:heating_system_fraction_heat_load_served_2] == 1.0)
    errors << "heating_system_type_2=#{args[:heating_system_type_2]} and heating_system_fraction_heat_load_served_2=#{args[:heating_system_fraction_heat_load_served_2]}" if error

    # second heating system but no primary heating system
    error = (args[:heating_system_type] == 'none') && (args[:heat_pump_type] == 'none') && (args[:heating_system_type_2] != 'none')
    errors << "heating_system_type=#{args[:heating_system_type]} and heat_pump_type=#{args[:heat_pump_type]} and heating_system_type_2=#{args[:heating_system_type_2]}" if error

    # single-family attached and num units, horizontal location not specified
    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeSFA) && (!args[:geometry_building_num_units].is_initialized || !args[:geometry_horizontal_location].is_initialized)
    errors << "geometry_unit_type=#{args[:geometry_unit_type]} and geometry_building_num_units=#{args[:geometry_building_num_units].is_initialized} and geometry_horizontal_location=#{args[:geometry_horizontal_location].is_initialized}" if error

    # apartment unit and num units, level, horizontal location not specified
    error = (args[:geometry_unit_type] == HPXML::ResidentialTypeApartment) && (!args[:geometry_building_num_units].is_initialized || !args[:geometry_level].is_initialized || !args[:geometry_horizontal_location].is_initialized)
    errors << "geometry_unit_type=#{args[:geometry_unit_type]} and geometry_building_num_units=#{args[:geometry_building_num_units].is_initialized} and geometry_level=#{args[:geometry_level].is_initialized} and geometry_horizontal_location=#{args[:geometry_horizontal_location].is_initialized}" if error

    # crawlspace or unconditioned basement with foundation wall and ceiling insulation
    warning = [HPXML::FoundationTypeCrawlspaceVented, HPXML::FoundationTypeCrawlspaceUnvented, HPXML::FoundationTypeBasementUnconditioned].include?(args[:geometry_foundation_type]) && ((args[:foundation_wall_insulation_r] > 0) || (args[:foundation_wall_assembly_r].is_initialized && (args[:foundation_wall_assembly_r].get > 0))) && (args[:floor_assembly_r] > 2.1)
    warnings << "geometry_foundation_type=#{args[:geometry_foundation_type]} and foundation_wall_insulation_r=#{args[:foundation_wall_insulation_r]} and foundation_wall_assembly_r=#{args[:foundation_wall_assembly_r].is_initialized} and floor_assembly_r=#{args[:floor_assembly_r]}" if warning

    # vented/unvented attic with floor and roof insulation
    warning = [HPXML::AtticTypeVented, HPXML::AtticTypeUnvented].include?(args[:geometry_attic_type]) && (args[:geometry_roof_type] != 'flat') && (args[:ceiling_assembly_r] > 2.1) && (args[:roof_assembly_r] > 2.3)
    warnings << "geometry_attic_type=#{args[:geometry_attic_type]} and ceiling_assembly_r=#{args[:ceiling_assembly_r]} and roof_assembly_r=#{args[:roof_assembly_r]}" if warning

    # conditioned basement with ceiling insulation
    warning = (args[:geometry_foundation_type] == HPXML::FoundationTypeBasementConditioned) && (args[:floor_assembly_r] > 2.1)
    warnings << "geometry_foundation_type=#{args[:geometry_foundation_type]} and floor_assembly_r=#{args[:floor_assembly_r]}" if warning

    # conditioned attic with floor insulation
    warning = (args[:geometry_attic_type] == HPXML::AtticTypeConditioned) && (args[:geometry_roof_type] != 'flat') && (args[:ceiling_assembly_r] > 2.1)
    warnings << "geometry_attic_type=#{args[:geometry_attic_type]} and ceiling_assembly_r=#{args[:ceiling_assembly_r]}" if warning

    # conditioned attic but only one above-grade floor
    error = (args[:geometry_num_floors_above_grade] == 1 && args[:geometry_attic_type] == HPXML::AtticTypeConditioned)
    errors << "geometry_num_floors_above_grade=#{args[:geometry_num_floors_above_grade]} and geometry_attic_type=#{args[:geometry_attic_type]}" if error

    # dhw indirect but no boiler
    error = ((args[:water_heater_type] == HPXML::WaterHeaterTypeCombiStorage) || (args[:water_heater_type] == HPXML::WaterHeaterTypeCombiTankless)) && (args[:heating_system_type] != HPXML::HVACTypeBoiler)
    errors << "water_heater_type=#{args[:water_heater_type]} and heating_system_type=#{args[:heating_system_type]}" if error

    # no tv plug loads but specifying usage multipliers
    if args[:plug_loads_television_annual_kwh] != Constants.Auto
      warning = (args[:plug_loads_television_annual_kwh].to_f == 0.0 && args[:plug_loads_television_usage_multiplier] != 0.0)
      warnings << "plug_loads_television_annual_kwh=#{args[:plug_loads_television_annual_kwh]} and plug_loads_television_usage_multiplier=#{args[:plug_loads_television_usage_multiplier]}" if warning
    end

    # no other plug loads but specifying usage multipliers
    if args[:plug_loads_other_annual_kwh] != Constants.Auto
      warning = (args[:plug_loads_other_annual_kwh].to_f == 0.0 && args[:plug_loads_other_usage_multiplier] != 0.0)
      warnings << "plug_loads_other_annual_kwh=#{args[:plug_loads_other_annual_kwh]} and plug_loads_other_usage_multiplier=#{args[:plug_loads_other_usage_multiplier]}" if warning
    end

    # no well pump plug loads but specifying usage multipliers
    if args[:plug_loads_well_pump_annual_kwh] != Constants.Auto
      warning = (args[:plug_loads_well_pump_annual_kwh].to_f == 0.0 && args[:plug_loads_well_pump_usage_multiplier] != 0.0)
      warnings << "plug_loads_well_pump_annual_kwh=#{args[:plug_loads_well_pump_annual_kwh]} and plug_loads_well_pump_usage_multiplier=#{args[:plug_loads_well_pump_usage_multiplier]}" if warning
    end

    # no vehicle plug loads but specifying usage multipliers
    if args[:plug_loads_vehicle_annual_kwh] != Constants.Auto
      warning = (args[:plug_loads_vehicle_annual_kwh].to_f && args[:plug_loads_vehicle_usage_multiplier] != 0.0)
      warnings << "plug_loads_vehicle_annual_kwh=#{args[:plug_loads_vehicle_annual_kwh]} and plug_loads_vehicle_usage_multiplier=#{args[:plug_loads_vehicle_usage_multiplier]}" if warning
    end

    # no fuel loads but specifying usage multipliers
    warning = (!args[:fuel_loads_grill_present] && args[:fuel_loads_grill_usage_multiplier] != 0.0) || (!args[:fuel_loads_lighting_present] && args[:fuel_loads_lighting_usage_multiplier] != 0.0) || (!args[:fuel_loads_fireplace_present] && args[:fuel_loads_fireplace_usage_multiplier] != 0.0)
    warnings << "fuel_loads_grill_present=#{args[:fuel_loads_grill_present]} and fuel_loads_grill_usage_multiplier=#{args[:fuel_loads_grill_usage_multiplier]} and fuel_loads_lighting_present=#{args[:fuel_loads_lighting_present]} and fuel_loads_lighting_usage_multiplier=#{args[:fuel_loads_lighting_usage_multiplier]} and fuel_loads_fireplace_present=#{args[:fuel_loads_fireplace_present]} and fuel_loads_fireplace_usage_multiplier=#{args[:fuel_loads_fireplace_usage_multiplier]}" if warning

    # foundation wall insulation distance to bottom is greater than foundation wall height
    if args[:foundation_wall_insulation_distance_to_bottom] != Constants.Auto
      error = (args[:foundation_wall_insulation_distance_to_bottom].to_f > args[:geometry_foundation_height])
      errors << "foundation_wall_insulation_distance_to_bottom=#{args[:foundation_wall_insulation_distance_to_bottom]} and geometry_foundation_height=#{args[:geometry_foundation_height]}" if error
    end

    # number of bedrooms not greater than zero
    error = (args[:geometry_num_bedrooms] <= 0)
    errors << "geometry_num_bedrooms=#{args[:geometry_num_bedrooms]}" if error

    # single-family detached with shared system
    error = [HPXML::ResidentialTypeSFD].include?(args[:geometry_unit_type]) && args[:heating_system_type].include?('Shared')
    errors << "geometry_unit_type=#{args[:geometry_unit_type]} and heating_system_type=#{args[:heating_system_type]}" if error

    # heating season incomplete
    error = [args[:season_heating_begin_month].is_initialized, args[:season_heating_begin_day_of_month].is_initialized, args[:season_heating_end_month].is_initialized, args[:season_heating_end_day_of_month].is_initialized].uniq.size == 2
    errors << "season_heating_begin_month=#{args[:season_heating_begin_month].is_initialized} and season_heating_begin_day_of_month=#{args[:season_heating_begin_day_of_month].is_initialized} and season_heating_end_month=#{args[:season_heating_end_month].is_initialized} and seasons_heating_end_day_of_month=#{args[:season_heating_end_day_of_month].is_initialized}" if error

    # cooling season incomplete
    error = [args[:season_cooling_begin_month].is_initialized, args[:season_cooling_begin_day_of_month].is_initialized, args[:season_cooling_end_month].is_initialized, args[:season_cooling_end_day_of_month].is_initialized].uniq.size == 2
    errors << "season_cooling_begin_month=#{args[:season_cooling_begin_month].is_initialized} and season_cooling_begin_day_of_month=#{args[:season_cooling_begin_day_of_month].is_initialized} and season_cooling_end_month=#{args[:season_cooling_end_month].is_initialized} and season_cooling_end_day_of_month=#{args[:season_cooling_end_day_of_month].is_initialized}" if error

    # vacancy period incomplete
    error = [args[:schedules_vacancy_begin_month].is_initialized, args[:schedules_vacancy_begin_day_of_month].is_initialized, args[:schedules_vacancy_end_month].is_initialized, args[:schedules_vacancy_end_day_of_month].is_initialized].uniq.size == 2
    errors << "schedules_vacancy_begin_month=#{args[:schedules_vacancy_begin_month].is_initialized} and schedules_vacancy_begin_day_of_month=#{args[:schedules_vacancy_begin_day_of_month].is_initialized} and schedules_vacancy_end_month=#{args[:schedules_vacancy_end_month].is_initialized} and schedules_vacancy_end_day_of_month=#{args[:schedules_vacancy_end_day_of_month].is_initialized}" if error

    # vacancy period invalid
    if args[:schedules_vacancy_begin_month].is_initialized && args[:schedules_vacancy_begin_day_of_month].is_initialized && args[:schedules_vacancy_end_month].is_initialized && args[:schedules_vacancy_end_day_of_month].is_initialized
      HPXML::check_dates('Vacancy Period', args[:schedules_vacancy_begin_month].get, args[:schedules_vacancy_begin_day_of_month].get, args[:schedules_vacancy_end_month].get, args[:schedules_vacancy_end_day_of_month].get).each do |error|
        errors << error
      end
    end

    return warnings, errors
  end

  def validate_hpxml(runner, hpxml_path, hpxml_doc)
    schemas_dir = File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources')

    is_valid = true

    # Validate input HPXML against schema
    XMLHelper.validate(hpxml_doc.to_xml, File.join(schemas_dir, 'HPXML.xsd'), runner).each do |error|
      runner.registerError("#{hpxml_path}: #{error}")
      is_valid = false
    end

    # Validate input HPXML against schematron docs
    stron_paths = [File.join(schemas_dir, 'HPXMLvalidator.xml'),
                   File.join(schemas_dir, 'EPvalidator.xml')]
    errors, warnings = Validator.run_validators(hpxml_doc, stron_paths)
    errors.each do |error|
      runner.registerError("#{hpxml_path}: #{error}")
      is_valid = false
    end
    warnings.each do |warning|
      runner.registerWarning("#{warning}")
    end

    return is_valid
  end
end

class HPXMLFile
  def self.create(runner, model, args, epw_file)
    success = create_geometry_envelope(runner, model, args)
    return false if not success

    success = create_schedules(runner, model, epw_file, args)
    return false if not success

    hpxml = HPXML.new

    set_header(hpxml, runner, args, epw_file)
    set_site(hpxml, runner, args)
    set_neighbor_buildings(hpxml, runner, args)
    set_building_occupancy(hpxml, runner, args)
    set_building_construction(hpxml, runner, args)
    set_climate_and_risk_zones(hpxml, runner, args, epw_file)
    set_air_infiltration_measurements(hpxml, runner, args)

    set_attics(hpxml, runner, model, args)
    set_foundations(hpxml, runner, model, args)
    set_roofs(hpxml, runner, model, args)
    set_rim_joists(hpxml, runner, model, args)
    set_walls(hpxml, runner, model, args)
    set_foundation_walls(hpxml, runner, model, args)
    set_frame_floors(hpxml, runner, model, args)
    set_slabs(hpxml, runner, model, args)
    set_windows(hpxml, runner, model, args)
    set_skylights(hpxml, runner, model, args)
    set_doors(hpxml, runner, model, args)

    set_heating_systems(hpxml, runner, args)
    set_cooling_systems(hpxml, runner, args)
    set_heat_pumps(hpxml, runner, args)
    set_secondary_heating_systems(hpxml, runner, args)
    set_hvac_distribution(hpxml, runner, args)
    set_hvac_control(hpxml, runner, args)
    set_ventilation_fans(hpxml, runner, args)
    set_water_heating_systems(hpxml, runner, args)
    set_hot_water_distribution(hpxml, runner, args)
    set_water_fixtures(hpxml, runner, args)
    set_solar_thermal(hpxml, runner, args, epw_file)
    set_pv_systems(hpxml, runner, args, epw_file)
    set_lighting(hpxml, runner, args)
    set_dehumidifier(hpxml, runner, args)
    set_clothes_washer(hpxml, runner, args)
    set_clothes_dryer(hpxml, runner, args)
    set_dishwasher(hpxml, runner, args)
    set_refrigerator(hpxml, runner, args)
    set_extra_refrigerator(hpxml, runner, args)
    set_freezer(hpxml, runner, args)
    set_cooking_range_oven(hpxml, runner, args)
    set_ceiling_fans(hpxml, runner, args)
    set_plug_loads_television(hpxml, runner, args)
    set_plug_loads_other(hpxml, runner, args)
    set_plug_loads_well_pump(hpxml, runner, args)
    set_plug_loads_vehicle(hpxml, runner, args)
    set_fuel_loads_grill(hpxml, runner, args)
    set_fuel_loads_lighting(hpxml, runner, args)
    set_fuel_loads_fireplace(hpxml, runner, args)
    set_pool(hpxml, runner, args)
    set_hot_tub(hpxml, runner, args)

    # Check for errors in the HPXML object
    errors = hpxml.check_for_errors()
    if errors.size > 0
      fail "ERROR: Invalid HPXML object produced.\n#{errors}"
    end

    hpxml_doc = hpxml.to_oga()

    return hpxml_doc
  end

  def self.create_geometry_envelope(runner, model, args)
    if args[:geometry_foundation_type] == HPXML::FoundationTypeSlab
      args[:geometry_foundation_height] = 0.0
      args[:geometry_foundation_height_above_grade] = 0.0
      args[:geometry_rim_joist_height] = 0.0
    elsif args[:geometry_foundation_type] == HPXML::FoundationTypeAmbient
      args[:geometry_rim_joist_height] = 0.0
    end

    if args[:geometry_unit_type] == HPXML::ResidentialTypeSFD
      success = Geometry.create_single_family_detached(runner: runner, model: model, **args)
    elsif args[:geometry_unit_type] == HPXML::ResidentialTypeSFA
      success = Geometry.create_single_family_attached(runner: runner, model: model, **args)
    elsif args[:geometry_unit_type] == HPXML::ResidentialTypeApartment
      args[:geometry_roof_type] = 'flat'
      args[:geometry_attic_type] = HPXML::AtticTypeVented
      success = Geometry.create_multifamily(runner: runner, model: model, **args)
    end
    return false if not success

    success = Geometry.create_doors(runner: runner, model: model, **args)
    return false if not success

    success = Geometry.create_windows_and_skylights(runner: runner, model: model, **args)
    return false if not success

    return true
  end

  def self.create_schedules(runner, model, epw_file, args)
    if ['default', 'user-specified'].include? args[:schedules_type]
      if args[:schedules_type] == 'user-specified'
        args[:schedules_path] = args[:schedules_path].get
      else
        args[:schedules_path] = nil
      end
      return true
    end

    info_msgs = []

    # set the calendar year
    year_description = model.getYearDescription
    year_description.setCalendarYear(2007) # default to TMY
    if args[:simulation_control_run_period_calendar_year].is_initialized
      year_description.setCalendarYear(args[:simulation_control_run_period_calendar_year].get)
    end
    if epw_file.startDateActualYear.is_initialized # AMY
      year_description.setCalendarYear(epw_file.startDateActualYear.get)
    end
    info_msgs << "CalendarYear=#{year_description.calendarYear}"

    # set the timestep
    timestep = model.getTimestep
    timestep.setNumberOfTimestepsPerHour(1)
    if args[:simulation_control_timestep].is_initialized
      timestep.setNumberOfTimestepsPerHour(60 / args[:simulation_control_timestep].get)
    end
    info_msgs << "NumberOfTimestepsPerHour=#{timestep.numberOfTimestepsPerHour}"

    # get the seed
    random_seed = args[:schedules_random_seed].get if args[:schedules_random_seed].is_initialized

    # instantiate the generator
    schedule_generator = ScheduleGenerator.new(runner: runner, model: model, epw_file: epw_file, random_seed: random_seed)

    # create the schedule
    if args[:geometry_num_occupants] == Constants.Auto
      args[:geometry_num_occupants] = Geometry.get_occupancy_default_num(args[:geometry_num_bedrooms])
    else
      args[:geometry_num_occupants] = Integer(args[:geometry_num_occupants])
    end
    args[:resources_path] = File.join(File.dirname(__FILE__), 'resources')
    success = schedule_generator.create(args: args)
    return false if not success

    # export the schedule
    args[:schedules_path] = "../#{File.basename(args[:hpxml_path], '.xml')}_schedules.csv"
    success = schedule_generator.export(schedules_path: File.expand_path(args[:schedules_path]))
    return false if not success

    runner.registerInfo("Created schedule with #{info_msgs.join(', ')}")

    return true
  end

  def self.set_header(hpxml, runner, args, epw_file)
    hpxml.header.xml_type = 'HPXML'
    hpxml.header.xml_generated_by = 'BuildResidentialHPXML'
    hpxml.header.transaction = 'create'

    if args[:software_program_used].is_initialized
      hpxml.header.software_program_used = args[:software_program_used].get
    end

    if args[:software_program_version].is_initialized
      hpxml.header.software_program_version = args[:software_program_version].get
    end

    if args[:simulation_control_timestep].is_initialized
      hpxml.header.timestep = args[:simulation_control_timestep].get
    end

    if args[:simulation_control_run_period_begin_month].is_initialized
      hpxml.header.sim_begin_month = args[:simulation_control_run_period_begin_month].get
    end
    if args[:simulation_control_run_period_begin_day_of_month].is_initialized
      hpxml.header.sim_begin_day = args[:simulation_control_run_period_begin_day_of_month].get
    end
    if args[:simulation_control_run_period_end_month].is_initialized
      hpxml.header.sim_end_month = args[:simulation_control_run_period_end_month].get
    end
    if args[:simulation_control_run_period_end_day_of_month].is_initialized
      hpxml.header.sim_end_day = args[:simulation_control_run_period_end_day_of_month].get
    end
    if args[:simulation_control_run_period_calendar_year].is_initialized
      hpxml.header.sim_calendar_year = args[:simulation_control_run_period_calendar_year].get
    end

    if args[:simulation_control_daylight_saving_enabled].is_initialized
      hpxml.header.dst_enabled = args[:simulation_control_daylight_saving_enabled].get
    end
    if args[:simulation_control_daylight_saving_begin_month].is_initialized
      hpxml.header.dst_begin_month = args[:simulation_control_daylight_saving_begin_month].get
    end
    if args[:simulation_control_daylight_saving_begin_day_of_month].is_initialized
      hpxml.header.dst_begin_day = args[:simulation_control_daylight_saving_begin_day_of_month].get
    end
    if args[:simulation_control_daylight_saving_end_month].is_initialized
      hpxml.header.dst_end_month = args[:simulation_control_daylight_saving_end_month].get
    end
    if args[:simulation_control_daylight_saving_end_day_of_month].is_initialized
      hpxml.header.dst_end_day = args[:simulation_control_daylight_saving_end_day_of_month].get
    end

    hpxml.header.building_id = 'MyBuilding'
    hpxml.header.state_code = epw_file.stateProvinceRegion
    hpxml.header.event_type = 'proposed workscope'
    hpxml.header.schedules_path = args[:schedules_path]
  end

  def self.set_site(hpxml, runner, args)
    if args[:air_leakage_shielding_of_home] != Constants.Auto
      shielding_of_home = args[:air_leakage_shielding_of_home]
    end

    if args[:site_type].is_initialized
      hpxml.site.site_type = args[:site_type].get
    end

    hpxml.site.shielding_of_home = shielding_of_home
  end

  def self.set_neighbor_buildings(hpxml, runner, args)
    nbr_map = { Constants.FacadeFront => [args[:neighbor_front_distance], args[:neighbor_front_height]],
                Constants.FacadeBack => [args[:neighbor_back_distance], args[:neighbor_back_height]],
                Constants.FacadeLeft => [args[:neighbor_left_distance], args[:neighbor_left_height]],
                Constants.FacadeRight => [args[:neighbor_right_distance], args[:neighbor_right_height]] }

    nbr_map.each do |facade, data|
      distance, neighbor_height = data
      next if distance == 0

      azimuth = get_azimuth_from_facade(facade, args)

      if (distance > 0) && (neighbor_height != Constants.Auto)
        height = Float(neighbor_height)
      end

      hpxml.neighbor_buildings.add(azimuth: azimuth,
                                   distance: distance,
                                   height: height)
    end
  end

  def self.set_building_occupancy(hpxml, runner, args)
    if args[:geometry_num_occupants] != Constants.Auto
      hpxml.building_occupancy.number_of_residents = args[:geometry_num_occupants]
    end
  end

  def self.set_building_construction(hpxml, runner, args)
    if args[:geometry_unit_type] == HPXML::ResidentialTypeApartment
      number_of_conditioned_floors_above_grade = 1
      number_of_conditioned_floors = 1
    else
      number_of_conditioned_floors_above_grade = args[:geometry_num_floors_above_grade]
      number_of_conditioned_floors = number_of_conditioned_floors_above_grade
      if args[:geometry_foundation_type] == HPXML::FoundationTypeBasementConditioned
        number_of_conditioned_floors += 1
      end
    end

    if args[:geometry_num_bathrooms] != Constants.Auto
      number_of_bathrooms = args[:geometry_num_bathrooms]
    end

    conditioned_building_volume = args[:geometry_cfa] * args[:geometry_wall_height]

    hpxml.building_construction.number_of_conditioned_floors = number_of_conditioned_floors
    hpxml.building_construction.number_of_conditioned_floors_above_grade = number_of_conditioned_floors_above_grade
    hpxml.building_construction.number_of_bedrooms = args[:geometry_num_bedrooms]
    hpxml.building_construction.number_of_bathrooms = number_of_bathrooms
    hpxml.building_construction.conditioned_floor_area = args[:geometry_cfa]
    hpxml.building_construction.conditioned_building_volume = conditioned_building_volume
    hpxml.building_construction.average_ceiling_height = args[:geometry_wall_height]
    hpxml.building_construction.residential_facility_type = args[:geometry_unit_type]
    if args[:geometry_has_flue_or_chimney] != Constants.Auto
      has_flue_or_chimney = args[:geometry_has_flue_or_chimney]
      hpxml.building_construction.has_flue_or_chimney = has_flue_or_chimney
    end
  end

  def self.set_climate_and_risk_zones(hpxml, runner, args, epw_file)
    hpxml.climate_and_risk_zones.weather_station_id = 'WeatherStation'
    iecc_zone = Location.get_climate_zone_iecc(epw_file.wmoNumber)

    unless iecc_zone.nil?
      hpxml.climate_and_risk_zones.iecc_year = 2006
      hpxml.climate_and_risk_zones.iecc_zone = iecc_zone
    end
    weather_station_name = File.basename(args[:weather_station_epw_filepath]).gsub('.epw', '')
    hpxml.climate_and_risk_zones.weather_station_name = weather_station_name
    hpxml.climate_and_risk_zones.weather_station_epw_filepath = args[:weather_station_epw_filepath]
  end

  def self.set_air_infiltration_measurements(hpxml, runner, args)
    if args[:air_leakage_units] == HPXML::UnitsACH
      house_pressure = args[:air_leakage_house_pressure]
      unit_of_measure = HPXML::UnitsACH
    elsif args[:air_leakage_units] == HPXML::UnitsCFM
      house_pressure = args[:air_leakage_house_pressure]
      unit_of_measure = HPXML::UnitsCFM
    elsif args[:air_leakage_units] == HPXML::UnitsACHNatural
      house_pressure = nil
      unit_of_measure = HPXML::UnitsACHNatural
    end
    infiltration_volume = args[:geometry_cfa] * args[:geometry_wall_height]

    hpxml.air_infiltration_measurements.add(id: 'InfiltrationMeasurement',
                                            house_pressure: house_pressure,
                                            unit_of_measure: unit_of_measure,
                                            air_leakage: args[:air_leakage_value],
                                            infiltration_volume: infiltration_volume)
  end

  def self.set_attics(hpxml, runner, model, args)
    return if args[:geometry_unit_type] == HPXML::ResidentialTypeApartment

    if args[:geometry_roof_type] == 'flat'
      hpxml.attics.add(id: HPXML::AtticTypeFlatRoof,
                       attic_type: HPXML::AtticTypeFlatRoof)
    else
      hpxml.attics.add(id: args[:geometry_attic_type],
                       attic_type: args[:geometry_attic_type])
    end
  end

  def self.set_foundations(hpxml, runner, model, args)
    return if args[:geometry_unit_type] == HPXML::ResidentialTypeApartment

    hpxml.foundations.add(id: args[:geometry_foundation_type],
                          foundation_type: args[:geometry_foundation_type])
  end

  def self.set_roofs(hpxml, runner, model, args)
    args[:geometry_roof_pitch] *= 12.0
    if args[:geometry_roof_type] == 'flat'
      args[:geometry_roof_pitch] = 0.0
    end

    model.getSurfaces.sort.each do |surface|
      next unless ['Outdoors'].include? surface.outsideBoundaryCondition
      next if surface.surfaceType != 'RoofCeiling'

      interior_adjacent_to = get_adjacent_to(surface)
      next if [HPXML::LocationOtherHousingUnit].include? interior_adjacent_to

      if args[:roof_material_type].is_initialized
        roof_type = args[:roof_material_type].get
      end

      if args[:roof_color] != Constants.Auto
        roof_color = args[:roof_color]
      end

      radiant_barrier = args[:roof_radiant_barrier]
      if args[:roof_radiant_barrier]
        radiant_barrier_grade = args[:roof_radiant_barrier_grade]
      end

      if args[:geometry_roof_type] == 'flat'
        azimuth = nil
      else
        azimuth = get_surface_azimuth(surface, args)
      end

      hpxml.roofs.add(id: valid_attr(surface.name),
                      interior_adjacent_to: get_adjacent_to(surface),
                      azimuth: azimuth,
                      area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2').round(1),
                      roof_type: roof_type,
                      roof_color: roof_color,
                      pitch: args[:geometry_roof_pitch],
                      radiant_barrier: radiant_barrier,
                      radiant_barrier_grade: radiant_barrier_grade,
                      insulation_assembly_r_value: args[:roof_assembly_r])
    end
  end

  def self.set_rim_joists(hpxml, runner, model, args)
    model.getSurfaces.sort.each do |surface|
      next if surface.surfaceType != 'Wall'
      next unless ['Outdoors', 'Adiabatic'].include? surface.outsideBoundaryCondition
      next unless Geometry.surface_is_rim_joist(surface, args[:geometry_rim_joist_height])

      interior_adjacent_to = get_adjacent_to(surface)
      next unless [HPXML::LocationBasementConditioned, HPXML::LocationBasementUnconditioned, HPXML::LocationCrawlspaceUnvented, HPXML::LocationCrawlspaceVented].include? interior_adjacent_to

      exterior_adjacent_to = HPXML::LocationOutside
      if surface.outsideBoundaryCondition == 'Adiabatic' # can be adjacent to foundation space
        adjacent_surface = get_adiabatic_adjacent_surface(model, surface)
        if adjacent_surface.nil? # adjacent to a space that is not explicitly in the model
          unless [HPXML::ResidentialTypeSFD].include?(args[:geometry_unit_type])
            exterior_adjacent_to = interior_adjacent_to
            if exterior_adjacent_to == HPXML::LocationLivingSpace # living adjacent to living
              exterior_adjacent_to = HPXML::LocationOtherHousingUnit
            end
          end
        else # adjacent to a space that is explicitly in the model, e.g., corridor
          exterior_adjacent_to = get_adjacent_to(adjacent_surface)
        end
      end

      if exterior_adjacent_to == HPXML::LocationOutside && args[:wall_siding_type].is_initialized
        siding = args[:wall_siding_type].get
      end

      if args[:wall_color] != Constants.Auto
        color = args[:wall_color]
      end

      if interior_adjacent_to == exterior_adjacent_to
        insulation_assembly_r_value = 4.0 # Uninsulated
      else
        insulation_assembly_r_value = args[:rim_joist_assembly_r]
      end

      hpxml.rim_joists.add(id: valid_attr(surface.name),
                           exterior_adjacent_to: exterior_adjacent_to,
                           interior_adjacent_to: interior_adjacent_to,
                           area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2').round(1),
                           siding: siding,
                           color: color,
                           insulation_assembly_r_value: insulation_assembly_r_value)
    end
  end

  def self.get_unexposed_garage_perimeter(hpxml, args)
    # this is perimeter adjacent to a 100% protruding garage that is not exposed
    # we need this because it's difficult to set this surface to Adiabatic using our geometry methods
    if (args[:geometry_garage_protrusion] == 1.0) && (args[:geometry_garage_width] * args[:geometry_garage_depth] > 0)
      return args[:geometry_garage_width]
    end

    return 0
  end

  def self.get_adiabatic_adjacent_surface(model, surface)
    return if surface.outsideBoundaryCondition != 'Adiabatic'

    adjacentSurfaceType = 'Wall'
    if surface.surfaceType == 'RoofCeiling'
      adjacentSurfaceType = 'Floor'
    elsif surface.surfaceType == 'Floor'
      adjacentSurfaceType = 'RoofCeiling'
    end

    model.getSurfaces.sort.each do |adjacent_surface|
      next if surface == adjacent_surface
      next if adjacent_surface.surfaceType != adjacentSurfaceType
      next if adjacent_surface.outsideBoundaryCondition != 'Adiabatic'
      next if Geometry.getSurfaceXValues([surface]).sort != Geometry.getSurfaceXValues([adjacent_surface]).sort
      next if Geometry.getSurfaceYValues([surface]).sort != Geometry.getSurfaceYValues([adjacent_surface]).sort
      next if Geometry.getSurfaceZValues([surface]).sort != Geometry.getSurfaceZValues([adjacent_surface]).sort

      return adjacent_surface
    end
    return
  end

  def self.set_walls(hpxml, runner, model, args)
    model.getSurfaces.sort.each do |surface|
      next if surface.surfaceType != 'Wall'
      next if Geometry.surface_is_rim_joist(surface, args[:geometry_rim_joist_height])

      interior_adjacent_to = get_adjacent_to(surface)
      next unless [HPXML::LocationLivingSpace, HPXML::LocationAtticUnvented, HPXML::LocationAtticVented, HPXML::LocationGarage].include? interior_adjacent_to

      exterior_adjacent_to = HPXML::LocationOutside
      if surface.adjacentSurface.is_initialized
        exterior_adjacent_to = get_adjacent_to(surface.adjacentSurface.get)
      elsif surface.outsideBoundaryCondition == 'Adiabatic' # can be adjacent to living space, attic, corridor
        adjacent_surface = get_adiabatic_adjacent_surface(model, surface)
        if adjacent_surface.nil? # adjacent to a space that is not explicitly in the model
          exterior_adjacent_to = interior_adjacent_to
          if exterior_adjacent_to == HPXML::LocationLivingSpace # living adjacent to living
            exterior_adjacent_to = HPXML::LocationOtherHousingUnit
          end
        else # adjacent to a space that is explicitly in the model, e.g., corridor
          exterior_adjacent_to = get_adjacent_to(adjacent_surface)
        end
      end

      next if exterior_adjacent_to == HPXML::LocationLivingSpace # already captured these surfaces

      wall_type = args[:wall_type]
      if [HPXML::LocationAtticUnvented, HPXML::LocationAtticVented].include? interior_adjacent_to
        wall_type = HPXML::WallTypeWoodStud
      end

      if exterior_adjacent_to == HPXML::LocationOutside && args[:wall_siding_type].is_initialized
        siding = args[:wall_siding_type].get
      end

      if args[:wall_color] == Constants.Auto && args[:wall_solar_absorptance] == Constants.Auto
        solar_absorptance = 0.7
      end

      if args[:wall_color] != Constants.Auto
        color = args[:wall_color]
      end

      if args[:wall_solar_absorptance] != Constants.Auto
        solar_absorptance = args[:wall_solar_absorptance]
      end

      if args[:wall_emittance] != Constants.Auto
        emittance = args[:wall_emittance]
      end

      azimuth = get_surface_azimuth(surface, args)

      hpxml.walls.add(id: valid_attr(surface.name),
                      exterior_adjacent_to: exterior_adjacent_to,
                      interior_adjacent_to: interior_adjacent_to,
                      azimuth: azimuth,
                      wall_type: wall_type,
                      siding: siding,
                      color: color,
                      solar_absorptance: solar_absorptance,
                      area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2').round(1),
                      emittance: emittance)

      is_uncond_attic_roof_insulated = false
      if [HPXML::LocationAtticUnvented, HPXML::LocationAtticVented].include? interior_adjacent_to
        hpxml.roofs.each do |roof|
          next unless (roof.interior_adjacent_to == interior_adjacent_to) && (roof.insulation_assembly_r_value > 4.0)

          is_uncond_attic_roof_insulated = true
        end
      end

      if hpxml.walls[-1].is_thermal_boundary || is_uncond_attic_roof_insulated # Assume wall is insulated if roof is insulated
        hpxml.walls[-1].insulation_assembly_r_value = args[:wall_assembly_r]
      else
        hpxml.walls[-1].insulation_assembly_r_value = 4.0 # Uninsulated
      end
    end
  end

  def self.set_foundation_walls(hpxml, runner, model, args)
    model.getSurfaces.sort.each do |surface|
      next if surface.surfaceType != 'Wall'
      next unless ['Foundation', 'Adiabatic'].include? surface.outsideBoundaryCondition
      next if Geometry.surface_is_rim_joist(surface, args[:geometry_rim_joist_height])

      interior_adjacent_to = get_adjacent_to(surface)
      next unless [HPXML::LocationBasementConditioned, HPXML::LocationBasementUnconditioned, HPXML::LocationCrawlspaceUnvented, HPXML::LocationCrawlspaceVented].include? interior_adjacent_to

      exterior_adjacent_to = HPXML::LocationGround
      if surface.outsideBoundaryCondition == 'Adiabatic' # can be adjacent to foundation space
        adjacent_surface = get_adiabatic_adjacent_surface(model, surface)
        if adjacent_surface.nil? # adjacent to a space that is not explicitly in the model
          unless [HPXML::ResidentialTypeSFD].include?(args[:geometry_unit_type])
            exterior_adjacent_to = interior_adjacent_to
            if exterior_adjacent_to == HPXML::LocationLivingSpace # living adjacent to living
              exterior_adjacent_to = HPXML::LocationOtherHousingUnit
            end
          end
        else # adjacent to a space that is explicitly in the model, e.g., corridor
          exterior_adjacent_to = get_adjacent_to(adjacent_surface)
        end
      end

      if args[:foundation_wall_assembly_r].is_initialized && (args[:foundation_wall_assembly_r].get > 0)
        insulation_assembly_r_value = args[:foundation_wall_assembly_r]
      else
        if interior_adjacent_to == exterior_adjacent_to # E.g., don't insulate wall between basement and neighbor basement
          insulation_exterior_r_value = 0
          insulation_exterior_distance_to_top = 0
          insulation_exterior_distance_to_bottom = 0
        else
          insulation_exterior_r_value = args[:foundation_wall_insulation_r]
          if args[:foundation_wall_insulation_distance_to_top] != Constants.Auto
            insulation_exterior_distance_to_top = args[:foundation_wall_insulation_distance_to_top]
          end
          if args[:foundation_wall_insulation_distance_to_bottom] != Constants.Auto
            insulation_exterior_distance_to_bottom = args[:foundation_wall_insulation_distance_to_bottom]
          end
        end
        insulation_interior_r_value = 0
      end

      if args[:foundation_wall_thickness] != Constants.Auto
        thickness = args[:foundation_wall_thickness]
      end

      hpxml.foundation_walls.add(id: valid_attr(surface.name),
                                 exterior_adjacent_to: exterior_adjacent_to,
                                 interior_adjacent_to: interior_adjacent_to,
                                 height: args[:geometry_foundation_height],
                                 area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2').round(1),
                                 thickness: thickness,
                                 depth_below_grade: args[:geometry_foundation_height] - args[:geometry_foundation_height_above_grade],
                                 insulation_assembly_r_value: insulation_assembly_r_value,
                                 insulation_interior_r_value: insulation_interior_r_value,
                                 insulation_exterior_r_value: insulation_exterior_r_value,
                                 insulation_exterior_distance_to_top: insulation_exterior_distance_to_top,
                                 insulation_exterior_distance_to_bottom: insulation_exterior_distance_to_bottom)
    end
  end

  def self.set_frame_floors(hpxml, runner, model, args)
    if [HPXML::FoundationTypeBasementConditioned].include?(args[:geometry_foundation_type]) && (args[:floor_assembly_r] > 2.1)
      args[:floor_assembly_r] = 2.1 # Uninsulated
    end

    if [HPXML::AtticTypeConditioned].include?(args[:geometry_attic_type]) && (args[:geometry_roof_type] != 'flat') && (args[:ceiling_assembly_r] > 2.1)
      args[:ceiling_assembly_r] = 2.1 # Uninsulated
    end

    model.getSurfaces.sort.each do |surface|
      next if surface.outsideBoundaryCondition == 'Foundation'
      next unless ['Floor', 'RoofCeiling'].include? surface.surfaceType

      interior_adjacent_to = get_adjacent_to(surface)
      next unless [HPXML::LocationLivingSpace, HPXML::LocationGarage].include? interior_adjacent_to

      exterior_adjacent_to = HPXML::LocationOutside
      if surface.adjacentSurface.is_initialized
        exterior_adjacent_to = get_adjacent_to(surface.adjacentSurface.get)
      elsif surface.outsideBoundaryCondition == 'Adiabatic'
        exterior_adjacent_to = HPXML::LocationOtherHousingUnit
        if surface.surfaceType == 'Floor'
          other_space_above_or_below = HPXML::FrameFloorOtherSpaceBelow
        elsif surface.surfaceType == 'RoofCeiling'
          other_space_above_or_below = HPXML::FrameFloorOtherSpaceAbove
        end
      end

      next if interior_adjacent_to == exterior_adjacent_to
      next if (surface.surfaceType == 'RoofCeiling') && (exterior_adjacent_to == HPXML::LocationOutside)
      next if [HPXML::LocationLivingSpace, HPXML::LocationBasementConditioned].include? exterior_adjacent_to

      hpxml.frame_floors.add(id: valid_attr(surface.name),
                             exterior_adjacent_to: exterior_adjacent_to,
                             interior_adjacent_to: interior_adjacent_to,
                             area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2').round(1),
                             other_space_above_or_below: other_space_above_or_below)

      if hpxml.frame_floors[-1].is_thermal_boundary
        if [HPXML::LocationAtticUnvented, HPXML::LocationAtticVented, HPXML::LocationGarage].include? exterior_adjacent_to
          hpxml.frame_floors[-1].insulation_assembly_r_value = args[:ceiling_assembly_r]
        else
          hpxml.frame_floors[-1].insulation_assembly_r_value = args[:floor_assembly_r]
        end
      else
        hpxml.frame_floors[-1].insulation_assembly_r_value = 2.1 # Uninsulated
      end
    end
  end

  def self.set_slabs(hpxml, runner, model, args)
    model.getSurfaces.sort.each do |surface|
      next unless ['Foundation'].include? surface.outsideBoundaryCondition
      next if surface.surfaceType != 'Floor'

      interior_adjacent_to = get_adjacent_to(surface)
      next if [HPXML::LocationOutside, HPXML::LocationOtherHousingUnit].include? interior_adjacent_to

      has_foundation_walls = false
      if [HPXML::LocationCrawlspaceVented, HPXML::LocationCrawlspaceUnvented, HPXML::LocationBasementUnconditioned, HPXML::LocationBasementConditioned].include? interior_adjacent_to
        has_foundation_walls = true
      end
      exposed_perimeter = Geometry.calculate_exposed_perimeter(model, [surface], has_foundation_walls).round(1)
      next if exposed_perimeter == 0 # this could be, e.g., the foundation floor of an interior corridor

      if [HPXML::LocationCrawlspaceVented, HPXML::LocationCrawlspaceUnvented, HPXML::LocationBasementUnconditioned, HPXML::LocationBasementConditioned].include? interior_adjacent_to
        exposed_perimeter -= get_unexposed_garage_perimeter(hpxml, args)
      end

      if [HPXML::LocationLivingSpace, HPXML::LocationGarage].include? interior_adjacent_to
        depth_below_grade = 0
      end

      if args[:slab_under_width] == 999
        under_slab_insulation_spans_entire_slab = true
      else
        under_slab_insulation_width = args[:slab_under_width]
      end

      if args[:slab_thickness] != Constants.Auto
        thickness = args[:slab_thickness]
      end

      if interior_adjacent_to.include? 'crawlspace'
        thickness = 0.0 # Assume soil
      end

      if args[:slab_carpet_fraction] != Constants.Auto
        carpet_fraction = args[:slab_carpet_fraction]
      end

      if args[:slab_carpet_r] != Constants.Auto
        carpet_r_value = args[:slab_carpet_r]
      end

      hpxml.slabs.add(id: valid_attr(surface.name),
                      interior_adjacent_to: interior_adjacent_to,
                      area: UnitConversions.convert(surface.grossArea, 'm^2', 'ft^2').round(1),
                      thickness: thickness,
                      exposed_perimeter: exposed_perimeter,
                      perimeter_insulation_depth: args[:slab_perimeter_depth],
                      under_slab_insulation_width: under_slab_insulation_width,
                      perimeter_insulation_r_value: args[:slab_perimeter_insulation_r],
                      under_slab_insulation_r_value: args[:slab_under_insulation_r],
                      under_slab_insulation_spans_entire_slab: under_slab_insulation_spans_entire_slab,
                      depth_below_grade: depth_below_grade,
                      carpet_fraction: carpet_fraction,
                      carpet_r_value: carpet_r_value)
    end
  end

  def self.set_windows(hpxml, runner, model, args)
    model.getSurfaces.sort.each do |surface|
      surface.subSurfaces.sort.each do |sub_surface|
        next if sub_surface.subSurfaceType != 'FixedWindow'

        sub_surface_height = Geometry.get_surface_height(sub_surface)
        sub_surface_facade = Geometry.get_facade_for_surface(sub_surface)

        if (sub_surface_facade == Constants.FacadeFront) && ((args[:overhangs_front_depth] > 0) || args[:overhangs_front_distance_to_top_of_window] > 0)
          overhangs_depth = args[:overhangs_front_depth]
          overhangs_distance_to_top_of_window = args[:overhangs_front_distance_to_top_of_window]
          overhangs_distance_to_bottom_of_window = (overhangs_distance_to_top_of_window + sub_surface_height).round(1)
        elsif (sub_surface_facade == Constants.FacadeBack) && ((args[:overhangs_back_depth] > 0) || args[:overhangs_back_distance_to_top_of_window] > 0)
          overhangs_depth = args[:overhangs_back_depth]
          overhangs_distance_to_top_of_window = args[:overhangs_back_distance_to_top_of_window]
          overhangs_distance_to_bottom_of_window = (overhangs_distance_to_top_of_window + sub_surface_height).round(1)
        elsif (sub_surface_facade == Constants.FacadeLeft) && ((args[:overhangs_left_depth] > 0) || args[:overhangs_left_distance_to_top_of_window] > 0)
          overhangs_depth = args[:overhangs_left_depth]
          overhangs_distance_to_top_of_window = args[:overhangs_left_distance_to_top_of_window]
          overhangs_distance_to_bottom_of_window = (overhangs_distance_to_top_of_window + sub_surface_height).round(1)
        elsif (sub_surface_facade == Constants.FacadeRight) && ((args[:overhangs_right_depth] > 0) || args[:overhangs_right_distance_to_top_of_window] > 0)
          overhangs_depth = args[:overhangs_right_depth]
          overhangs_distance_to_top_of_window = args[:overhangs_right_distance_to_top_of_window]
          overhangs_distance_to_bottom_of_window = (overhangs_distance_to_top_of_window + sub_surface_height).round(1)
        elsif args[:geometry_eaves_depth] > 0
          # Get max z coordinate of eaves
          eaves_z = args[:geometry_wall_height] * args[:geometry_num_floors_above_grade] + args[:geometry_rim_joist_height]
          if args[:geometry_attic_type] == HPXML::AtticTypeConditioned
            eaves_z += Geometry.get_conditioned_attic_height(model.getSpaces)
          end
          if args[:geometry_foundation_type] == HPXML::FoundationTypeAmbient
            eaves_z += args[:geometry_foundation_height]
          end

          # Get max z coordinate of this window
          sub_surface_z = Geometry.getSurfaceZValues([sub_surface]).max + UnitConversions.convert(sub_surface.space.get.zOrigin, 'm', 'ft')

          overhangs_depth = args[:geometry_eaves_depth]
          overhangs_distance_to_top_of_window = eaves_z - sub_surface_z # difference between max z coordinates of eaves and this window
          overhangs_distance_to_bottom_of_window = (overhangs_distance_to_top_of_window + sub_surface_height).round(1)
        end

        azimuth = get_azimuth_from_facade(sub_surface_facade, args)

        if args[:window_interior_shading_winter].is_initialized
          interior_shading_factor_winter = args[:window_interior_shading_winter].get
        end

        if args[:window_interior_shading_summer].is_initialized
          interior_shading_factor_summer = args[:window_interior_shading_summer].get
        end

        if args[:window_exterior_shading_winter].is_initialized
          exterior_shading_factor_winter = args[:window_exterior_shading_winter].get
        end

        if args[:window_exterior_shading_summer].is_initialized
          exterior_shading_factor_summer = args[:window_exterior_shading_summer].get
        end

        if args[:window_fraction_operable].is_initialized
          fraction_operable = args[:window_fraction_operable].get
        end

        hpxml.windows.add(id: "#{valid_attr(sub_surface.name)}_#{sub_surface_facade}",
                          area: UnitConversions.convert(sub_surface.grossArea, 'm^2', 'ft^2').round(1),
                          azimuth: azimuth,
                          ufactor: args[:window_ufactor],
                          shgc: args[:window_shgc],
                          overhangs_depth: overhangs_depth,
                          overhangs_distance_to_top_of_window: overhangs_distance_to_top_of_window,
                          overhangs_distance_to_bottom_of_window: overhangs_distance_to_bottom_of_window,
                          interior_shading_factor_winter: interior_shading_factor_winter,
                          interior_shading_factor_summer: interior_shading_factor_summer,
                          exterior_shading_factor_winter: exterior_shading_factor_winter,
                          exterior_shading_factor_summer: exterior_shading_factor_summer,
                          fraction_operable: fraction_operable,
                          wall_idref: valid_attr(surface.name))
      end # sub_surfaces
    end # surfaces
  end

  def self.set_skylights(hpxml, runner, model, args)
    model.getSurfaces.sort.each do |surface|
      surface.subSurfaces.sort.each do |sub_surface|
        next if sub_surface.subSurfaceType != 'Skylight'

        sub_surface_facade = Geometry.get_facade_for_surface(sub_surface)

        hpxml.skylights.add(id: "#{valid_attr(sub_surface.name)}_#{sub_surface_facade}",
                            area: UnitConversions.convert(sub_surface.grossArea, 'm^2', 'ft^2').round,
                            azimuth: UnitConversions.convert(sub_surface.azimuth, 'rad', 'deg').round,
                            ufactor: args[:skylight_ufactor],
                            shgc: args[:skylight_shgc],
                            roof_idref: valid_attr(surface.name))
      end
    end
  end

  def self.set_doors(hpxml, runner, model, args)
    model.getSurfaces.sort.each do |surface|
      interior_adjacent_to = get_adjacent_to(surface)

      adjacent_surface = surface
      if [HPXML::LocationOtherHousingUnit].include?(interior_adjacent_to)
        adjacent_surface = get_adiabatic_adjacent_surface(model, surface)
        next if adjacent_surface.nil?
      end

      surface.subSurfaces.sort.each do |sub_surface|
        next if sub_surface.subSurfaceType != 'Door'

        sub_surface_facade = Geometry.get_facade_for_surface(sub_surface)

        hpxml.doors.add(id: "#{valid_attr(sub_surface.name)}_#{sub_surface_facade}",
                        wall_idref: valid_attr(adjacent_surface.name),
                        area: UnitConversions.convert(sub_surface.grossArea, 'm^2', 'ft^2').round,
                        azimuth: args[:geometry_orientation],
                        r_value: args[:door_rvalue])
      end
    end
  end

  def self.set_heating_systems(hpxml, runner, args)
    heating_system_type = args[:heating_system_type]

    return if heating_system_type == 'none'

    if args[:heating_system_heating_capacity] != Constants.Auto
      heating_capacity = args[:heating_system_heating_capacity]
    end

    if heating_system_type == HPXML::HVACTypeElectricResistance
      heating_system_fuel = HPXML::FuelTypeElectricity
    else
      heating_system_fuel = args[:heating_system_fuel]
    end

    if [HPXML::HVACTypeFurnace, HPXML::HVACTypeWallFurnace, HPXML::HVACTypeFloorFurnace].include?(heating_system_type) || heating_system_type.include?(HPXML::HVACTypeBoiler)
      heating_efficiency_afue = args[:heating_system_heating_efficiency]
    elsif [HPXML::HVACTypeElectricResistance, HPXML::HVACTypeStove, HPXML::HVACTypePortableHeater, HPXML::HVACTypeFireplace, HPXML::HVACTypeFixedHeater].include?(heating_system_type)
      heating_efficiency_percent = args[:heating_system_heating_efficiency]
    end

    if args[:heating_system_airflow_defect_ratio].is_initialized
      if [HPXML::HVACTypeFurnace].include? heating_system_type
        airflow_defect_ratio = args[:heating_system_airflow_defect_ratio].get
      end
    end

    fraction_heat_load_served = args[:heating_system_fraction_heat_load_served]
    if args[:heating_system_type_2] != 'none' && fraction_heat_load_served + args[:heating_system_fraction_heat_load_served_2] > 1.0
      fraction_heat_load_served = 1.0 - args[:heating_system_fraction_heat_load_served_2]
    end

    if heating_system_type.include?('Shared')
      is_shared_system = true
      number_of_units_served = args[:geometry_building_num_units].get
      heating_capacity = nil
    end

    if heating_system_type.include?(HPXML::HVACTypeBoiler)
      heating_system_type = HPXML::HVACTypeBoiler
    end

    hpxml.heating_systems.add(id: 'HeatingSystem',
                              heating_system_type: heating_system_type,
                              heating_system_fuel: heating_system_fuel,
                              heating_capacity: heating_capacity,
                              fraction_heat_load_served: fraction_heat_load_served,
                              heating_efficiency_afue: heating_efficiency_afue,
                              heating_efficiency_percent: heating_efficiency_percent,
                              airflow_defect_ratio: airflow_defect_ratio,
                              is_shared_system: is_shared_system,
                              number_of_units_served: number_of_units_served)
  end

  def self.set_cooling_systems(hpxml, runner, args)
    cooling_system_type = args[:cooling_system_type]

    return if cooling_system_type == 'none'

    if args[:cooling_system_cooling_capacity] != Constants.Auto
      cooling_capacity = args[:cooling_system_cooling_capacity]
    end

    if args[:cooling_system_cooling_compressor_type].is_initialized
      if cooling_system_type == HPXML::HVACTypeCentralAirConditioner
        compressor_type = args[:cooling_system_cooling_compressor_type].get
      end
    end

    if args[:cooling_system_cooling_sensible_heat_fraction].is_initialized
      if cooling_system_type != HPXML::HVACTypeEvaporativeCooler
        cooling_shr = args[:cooling_system_cooling_sensible_heat_fraction].get
      end
    end

    if args[:cooling_system_cooling_efficiency_type] == HPXML::UnitsSEER
      cooling_efficiency_seer = args[:cooling_system_cooling_efficiency]
    elsif args[:cooling_system_cooling_efficiency_type] == HPXML::UnitsEER
      cooling_efficiency_eer = args[:cooling_system_cooling_efficiency]
    end

    if args[:cooling_system_airflow_defect_ratio].is_initialized
      if [HPXML::HVACTypeCentralAirConditioner].include?(cooling_system_type) || ([HPXML::HVACTypeMiniSplitAirConditioner].include?(cooling_system_type) && (args[:cooling_system_is_ducted]))
        airflow_defect_ratio = args[:cooling_system_airflow_defect_ratio].get
      end
    end

    if args[:cooling_system_charge_defect_ratio].is_initialized
      if [HPXML::HVACTypeCentralAirConditioner, HPXML::HVACTypeMiniSplitAirConditioner].include?(cooling_system_type)
        charge_defect_ratio = args[:cooling_system_charge_defect_ratio].get
      end
    end

    hpxml.cooling_systems.add(id: 'CoolingSystem',
                              cooling_system_type: cooling_system_type,
                              cooling_system_fuel: HPXML::FuelTypeElectricity,
                              cooling_capacity: cooling_capacity,
                              fraction_cool_load_served: args[:cooling_system_fraction_cool_load_served],
                              compressor_type: compressor_type,
                              cooling_shr: cooling_shr,
                              cooling_efficiency_seer: cooling_efficiency_seer,
                              cooling_efficiency_eer: cooling_efficiency_eer,
                              airflow_defect_ratio: airflow_defect_ratio,
                              charge_defect_ratio: charge_defect_ratio)
  end

  def self.set_heat_pumps(hpxml, runner, args)
    heat_pump_type = args[:heat_pump_type]

    return if heat_pump_type == 'none'

    if args[:heat_pump_heating_capacity] != Constants.Auto
      heating_capacity = args[:heat_pump_heating_capacity]
    end

    if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpMiniSplit].include? heat_pump_type
      if args[:heat_pump_heating_capacity_17_f] != Constants.Auto
        heating_capacity_17F = args[:heat_pump_heating_capacity_17_f]
      end
    end

    if args[:heat_pump_backup_fuel] != 'none'
      backup_heating_fuel = args[:heat_pump_backup_fuel]

      if args[:heat_pump_backup_heating_capacity] != Constants.Auto
        backup_heating_capacity = args[:heat_pump_backup_heating_capacity]
      end

      if backup_heating_fuel == HPXML::FuelTypeElectricity
        backup_heating_efficiency_percent = args[:heat_pump_backup_heating_efficiency]
      else
        backup_heating_efficiency_afue = args[:heat_pump_backup_heating_efficiency]
      end
      if args[:heat_pump_backup_heating_switchover_temp].is_initialized
        if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpMiniSplit].include? heat_pump_type
          backup_heating_switchover_temp = args[:heat_pump_backup_heating_switchover_temp].get
        end
      end
    end

    if args[:heat_pump_cooling_capacity] != Constants.Auto
      cooling_capacity = args[:heat_pump_cooling_capacity]
    end

    if args[:heat_pump_cooling_compressor_type].is_initialized
      if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpMiniSplit].include? heat_pump_type
        compressor_type = args[:heat_pump_cooling_compressor_type].get
      end
    end

    if args[:heat_pump_cooling_sensible_heat_fraction].is_initialized
      cooling_shr = args[:heat_pump_cooling_sensible_heat_fraction].get
    end

    if args[:heat_pump_heating_efficiency_type] == HPXML::UnitsHSPF
      heating_efficiency_hspf = args[:heat_pump_heating_efficiency]
    elsif args[:heat_pump_heating_efficiency_type] == HPXML::UnitsCOP
      heating_efficiency_cop = args[:heat_pump_heating_efficiency]
    end

    if args[:heat_pump_cooling_efficiency_type] == HPXML::UnitsSEER
      cooling_efficiency_seer = args[:heat_pump_cooling_efficiency]
    elsif args[:heat_pump_cooling_efficiency_type] == HPXML::UnitsEER
      cooling_efficiency_eer = args[:heat_pump_cooling_efficiency]
    end

    if args[:heat_pump_airflow_defect_ratio].is_initialized
      if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpGroundToAir].include?(heat_pump_type) || ([HPXML::HVACTypeHeatPumpMiniSplit].include?(heat_pump_type) && (args[:heat_pump_is_ducted]))
        airflow_defect_ratio = args[:heat_pump_airflow_defect_ratio].get
      end
    end

    if args[:heat_pump_charge_defect_ratio].is_initialized
      charge_defect_ratio = args[:heat_pump_charge_defect_ratio].get
    end

    fraction_heat_load_served = args[:heat_pump_fraction_heat_load_served]
    if args[:heating_system_type_2] != 'none' && fraction_heat_load_served + args[:heating_system_fraction_heat_load_served_2] > 1.0
      fraction_heat_load_served = 1.0 - args[:heating_system_fraction_heat_load_served_2]
    end

    hpxml.heat_pumps.add(id: 'HeatPump',
                         heat_pump_type: heat_pump_type,
                         heat_pump_fuel: HPXML::FuelTypeElectricity,
                         heating_capacity: heating_capacity,
                         heating_capacity_17F: heating_capacity_17F,
                         compressor_type: compressor_type,
                         cooling_shr: cooling_shr,
                         cooling_capacity: cooling_capacity,
                         fraction_heat_load_served: fraction_heat_load_served,
                         fraction_cool_load_served: args[:heat_pump_fraction_cool_load_served],
                         backup_heating_fuel: backup_heating_fuel,
                         backup_heating_capacity: backup_heating_capacity,
                         backup_heating_efficiency_afue: backup_heating_efficiency_afue,
                         backup_heating_efficiency_percent: backup_heating_efficiency_percent,
                         backup_heating_switchover_temp: backup_heating_switchover_temp,
                         heating_efficiency_hspf: heating_efficiency_hspf,
                         cooling_efficiency_seer: cooling_efficiency_seer,
                         heating_efficiency_cop: heating_efficiency_cop,
                         cooling_efficiency_eer: cooling_efficiency_eer,
                         airflow_defect_ratio: airflow_defect_ratio,
                         charge_defect_ratio: charge_defect_ratio)
  end

  def self.set_secondary_heating_systems(hpxml, runner, args)
    heating_system_type = args[:heating_system_type_2]

    return if heating_system_type == 'none'

    if args[:heating_system_heating_capacity_2] != Constants.Auto
      heating_capacity = args[:heating_system_heating_capacity_2]
    end

    if args[:heating_system_fuel_2] == HPXML::HVACTypeElectricResistance
      heating_system_fuel = HPXML::FuelTypeElectricity
    else
      heating_system_fuel = args[:heating_system_fuel_2]
    end

    if [HPXML::HVACTypeFurnace, HPXML::HVACTypeWallFurnace, HPXML::HVACTypeFloorFurnace].include?(heating_system_type) || heating_system_type.include?(HPXML::HVACTypeBoiler)
      heating_efficiency_afue = args[:heating_system_heating_efficiency_2]
    elsif [HPXML::HVACTypeElectricResistance, HPXML::HVACTypeStove, HPXML::HVACTypePortableHeater, HPXML::HVACTypeFireplace].include?(heating_system_type)
      heating_efficiency_percent = args[:heating_system_heating_efficiency_2]
    end

    if heating_system_type.include?(HPXML::HVACTypeBoiler)
      heating_system_type = HPXML::HVACTypeBoiler
    end

    hpxml.heating_systems.add(id: 'SecondHeatingSystem',
                              heating_system_type: heating_system_type,
                              heating_system_fuel: heating_system_fuel,
                              heating_capacity: heating_capacity,
                              fraction_heat_load_served: args[:heating_system_fraction_heat_load_served_2],
                              heating_efficiency_afue: heating_efficiency_afue,
                              heating_efficiency_percent: heating_efficiency_percent)
  end

  def self.set_hvac_distribution(hpxml, runner, args)
    # HydronicDistribution?
    hydr_idx = 0
    hpxml.heating_systems.each do |heating_system|
      next unless [heating_system.heating_system_type].include?(HPXML::HVACTypeBoiler)
      next if args[:heating_system_type].include?('Fan Coil')

      hydr_idx += 1
      hpxml.hvac_distributions.add(id: "HydronicDistribution#{hydr_idx}",
                                   distribution_system_type: HPXML::HVACDistributionTypeHydronic,
                                   hydronic_type: HPXML::HydronicTypeBaseboard)
      heating_system.distribution_system_idref = hpxml.hvac_distributions[-1].id
    end

    # AirDistribution?
    air_distribution_systems = []
    hpxml.heating_systems.each do |heating_system|
      if [HPXML::HVACTypeFurnace].include?(heating_system.heating_system_type)
        air_distribution_systems << heating_system
      end
    end
    hpxml.cooling_systems.each do |cooling_system|
      if [HPXML::HVACTypeCentralAirConditioner].include?(cooling_system.cooling_system_type)
        air_distribution_systems << cooling_system
      elsif [HPXML::HVACTypeEvaporativeCooler, HPXML::HVACTypeMiniSplitAirConditioner].include?(cooling_system.cooling_system_type) && args[:cooling_system_is_ducted]
        air_distribution_systems << cooling_system
      end
    end
    hpxml.heat_pumps.each do |heat_pump|
      if [HPXML::HVACTypeHeatPumpAirToAir, HPXML::HVACTypeHeatPumpGroundToAir].include? heat_pump.heat_pump_type
        air_distribution_systems << heat_pump
      elsif [HPXML::HVACTypeHeatPumpMiniSplit].include?(heat_pump.heat_pump_type)
        if args[:heat_pump_is_ducted].is_initialized
          air_distribution_systems << heat_pump if to_boolean(args[:heat_pump_is_ducted].get)
        end
      end
    end

    # FanCoil?
    fan_coil_distribution_systems = []
    hpxml.heating_systems.each do |heating_system|
      if args[:heating_system_type].include?('Fan Coil')
        fan_coil_distribution_systems << heating_system
      end
    end

    return if air_distribution_systems.size == 0 && fan_coil_distribution_systems.size == 0

    if args[:ducts_number_of_return_registers] != Constants.Auto
      number_of_return_registers = args[:ducts_number_of_return_registers]
    end

    if [HPXML::HVACTypeEvaporativeCooler].include?(args[:cooling_system_type]) && hpxml.heating_systems.size == 0 && hpxml.heat_pumps.size == 0
      number_of_return_registers = nil
      if args[:cooling_system_is_ducted]
        number_of_return_registers = 0
      end
    end

    if air_distribution_systems.size > 0
      hpxml.hvac_distributions.add(id: 'AirDistribution',
                                   distribution_system_type: HPXML::HVACDistributionTypeAir,
                                   conditioned_floor_area_served: args[:geometry_cfa],
                                   air_type: HPXML::AirTypeRegularVelocity,
                                   number_of_return_registers: number_of_return_registers)
      air_distribution_systems.each do |hvac_system|
        hvac_system.distribution_system_idref = hpxml.hvac_distributions[-1].id
      end
      set_duct_leakages(args, hpxml.hvac_distributions[-1])
      set_ducts(args, hpxml.hvac_distributions[-1])
    end

    if fan_coil_distribution_systems.size > 0
      hpxml.hvac_distributions.add(id: 'FanCoilDistribution',
                                   distribution_system_type: HPXML::HVACDistributionTypeAir,
                                   air_type: HPXML::AirTypeFanCoil)
      fan_coil_distribution_systems.each do |hvac_system|
        hvac_system.distribution_system_idref = hpxml.hvac_distributions[-1].id
      end
    end
  end

  def self.set_duct_leakages(args, hvac_distribution)
    hvac_distribution.duct_leakage_measurements.add(duct_type: HPXML::DuctTypeSupply,
                                                    duct_leakage_units: args[:ducts_supply_leakage_units],
                                                    duct_leakage_value: args[:ducts_supply_leakage_value],
                                                    duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)

    hvac_distribution.duct_leakage_measurements.add(duct_type: HPXML::DuctTypeReturn,
                                                    duct_leakage_units: args[:ducts_return_leakage_units],
                                                    duct_leakage_value: args[:ducts_return_leakage_value],
                                                    duct_leakage_total_or_to_outside: HPXML::DuctLeakageToOutside)
  end

  def self.set_ducts(args, hvac_distribution)
    if args[:ducts_supply_location] != Constants.Auto
      ducts_supply_location = args[:ducts_supply_location]
    end

    if args[:ducts_return_location] != Constants.Auto
      ducts_return_location = args[:ducts_return_location]
    end

    if args[:ducts_supply_surface_area] != Constants.Auto
      ducts_supply_surface_area = args[:ducts_supply_surface_area]
    end

    if args[:ducts_return_surface_area] != Constants.Auto
      ducts_return_surface_area = args[:ducts_return_surface_area]
    end

    hvac_distribution.ducts.add(duct_type: HPXML::DuctTypeSupply,
                                duct_insulation_r_value: args[:ducts_supply_insulation_r],
                                duct_location: ducts_supply_location,
                                duct_surface_area: ducts_supply_surface_area)

    if not ([HPXML::HVACTypeEvaporativeCooler].include?(args[:cooling_system_type]) && args[:cooling_system_is_ducted])
      hvac_distribution.ducts.add(duct_type: HPXML::DuctTypeReturn,
                                  duct_insulation_r_value: args[:ducts_return_insulation_r],
                                  duct_location: ducts_return_location,
                                  duct_surface_area: ducts_return_surface_area)
    end
  end

  def self.set_hvac_control(hpxml, runner, args)
    return if (args[:heating_system_type] == 'none') && (args[:cooling_system_type] == 'none') && (args[:heat_pump_type] == 'none')

    if args[:setpoint_heating_weekday] == args[:setpoint_heating_weekend] && !args[:setpoint_heating_weekday].include?(',')
      heating_setpoint_temp = args[:setpoint_heating_weekday]
    else
      weekday_heating_setpoints = args[:setpoint_heating_weekday]
      weekend_heating_setpoints = args[:setpoint_heating_weekend]
    end

    if args[:setpoint_cooling_weekday] == args[:setpoint_cooling_weekend] && !args[:setpoint_cooling_weekday].include?(',')
      cooling_setpoint_temp = args[:setpoint_cooling_weekday]
    else
      weekday_cooling_setpoints = args[:setpoint_cooling_weekday]
      weekend_cooling_setpoints = args[:setpoint_cooling_weekend]
    end

    ceiling_fan_quantity = nil
    if args[:ceiling_fan_quantity] != Constants.Auto
      ceiling_fan_quantity = Float(args[:ceiling_fan_quantity])
    end

    if (args[:ceiling_fan_cooling_setpoint_temp_offset] > 0) && (ceiling_fan_quantity.nil? || ceiling_fan_quantity > 0)
      ceiling_fan_cooling_setpoint_temp_offset = args[:ceiling_fan_cooling_setpoint_temp_offset]
    end

    hpxml.hvac_controls.add(id: 'HVACControl',
                            heating_setpoint_temp: heating_setpoint_temp,
                            cooling_setpoint_temp: cooling_setpoint_temp,
                            weekday_heating_setpoints: weekday_heating_setpoints,
                            weekend_heating_setpoints: weekend_heating_setpoints,
                            weekday_cooling_setpoints: weekday_cooling_setpoints,
                            weekend_cooling_setpoints: weekend_cooling_setpoints,
                            ceiling_fan_cooling_setpoint_temp_offset: ceiling_fan_cooling_setpoint_temp_offset)

    if args[:season_heating_begin_month].is_initialized
      hpxml.hvac_controls[0].seasons_heating_begin_month = args[:season_heating_begin_month].get
    end
    if args[:season_heating_begin_day_of_month].is_initialized
      hpxml.hvac_controls[0].seasons_heating_begin_day = args[:season_heating_begin_day_of_month].get
    end
    if args[:season_heating_end_month].is_initialized
      hpxml.hvac_controls[0].seasons_heating_end_month = args[:season_heating_end_month].get
    end
    if args[:season_heating_end_day_of_month].is_initialized
      hpxml.hvac_controls[0].seasons_heating_end_day = args[:season_heating_end_day_of_month].get
    end

    if args[:season_cooling_begin_month].is_initialized
      hpxml.hvac_controls[0].seasons_cooling_begin_month = args[:season_cooling_begin_month].get
    end
    if args[:season_cooling_begin_day_of_month].is_initialized
      hpxml.hvac_controls[0].seasons_cooling_begin_day = args[:season_cooling_begin_day_of_month].get
    end
    if args[:season_cooling_end_month].is_initialized
      hpxml.hvac_controls[0].seasons_cooling_end_month = args[:season_cooling_end_month].get
    end
    if args[:season_cooling_end_day_of_month].is_initialized
      hpxml.hvac_controls[0].seasons_cooling_end_day = args[:season_cooling_end_day_of_month].get
    end
  end

  def self.set_ventilation_fans(hpxml, runner, args)
    if args[:mech_vent_fan_type] != 'none'

      if [HPXML::MechVentTypeERV].include?(args[:mech_vent_fan_type])
        if args[:mech_vent_recovery_efficiency_type] == 'Unadjusted'
          total_recovery_efficiency = args[:mech_vent_total_recovery_efficiency]
          sensible_recovery_efficiency = args[:mech_vent_sensible_recovery_efficiency]
        elsif args[:mech_vent_recovery_efficiency_type] == 'Adjusted'
          total_recovery_efficiency_adjusted = args[:mech_vent_total_recovery_efficiency]
          sensible_recovery_efficiency_adjusted = args[:mech_vent_sensible_recovery_efficiency]
        end
      elsif [HPXML::MechVentTypeHRV].include?(args[:mech_vent_fan_type])
        if args[:mech_vent_recovery_efficiency_type] == 'Unadjusted'
          sensible_recovery_efficiency = args[:mech_vent_sensible_recovery_efficiency]
        elsif args[:mech_vent_recovery_efficiency_type] == 'Adjusted'
          sensible_recovery_efficiency_adjusted = args[:mech_vent_sensible_recovery_efficiency]
        end
      end

      distribution_system_idref = nil
      if args[:mech_vent_fan_type] == HPXML::MechVentTypeCFIS
        hpxml.hvac_distributions.each do |hvac_distribution|
          next unless hvac_distribution.distribution_system_type == HPXML::HVACDistributionTypeAir
          next if hvac_distribution.air_type != HPXML::AirTypeRegularVelocity

          distribution_system_idref = hvac_distribution.id
        end
      end

      if args[:mech_vent_num_units_served] > 1
        is_shared_system = true
        in_unit_flow_rate = args[:mech_vent_flow_rate] / args[:mech_vent_num_units_served].to_f
        fraction_recirculation = args[:shared_mech_vent_frac_recirculation].get
        if args[:shared_mech_vent_preheating_fuel].is_initialized && args[:shared_mech_vent_preheating_efficiency].is_initialized && args[:shared_mech_vent_preheating_fraction_heat_load_served].is_initialized
          preheating_fuel = args[:shared_mech_vent_preheating_fuel].get
          preheating_efficiency_cop = args[:shared_mech_vent_preheating_efficiency].get
          preheating_fraction_load_served = args[:shared_mech_vent_preheating_fraction_heat_load_served].get
        end
        if args[:shared_mech_vent_precooling_fuel].is_initialized && args[:shared_mech_vent_precooling_efficiency].is_initialized && args[:shared_mech_vent_precooling_fraction_cool_load_served].is_initialized
          precooling_fuel = args[:shared_mech_vent_precooling_fuel].get
          precooling_efficiency_cop = args[:shared_mech_vent_precooling_efficiency].get
          precooling_fraction_load_served = args[:shared_mech_vent_precooling_fraction_cool_load_served].get
        end
      end

      if args[:mech_vent_hours_in_operation] != Constants.Auto
        hours_in_operation = args[:mech_vent_hours_in_operation]
      end

      if args[:mech_vent_fan_power] != Constants.Auto
        fan_power = args[:mech_vent_fan_power]
      end

      hpxml.ventilation_fans.add(id: 'MechanicalVentilation',
                                 fan_type: args[:mech_vent_fan_type],
                                 rated_flow_rate: args[:mech_vent_flow_rate],
                                 hours_in_operation: hours_in_operation,
                                 used_for_whole_building_ventilation: true,
                                 total_recovery_efficiency: total_recovery_efficiency,
                                 total_recovery_efficiency_adjusted: total_recovery_efficiency_adjusted,
                                 sensible_recovery_efficiency: sensible_recovery_efficiency,
                                 sensible_recovery_efficiency_adjusted: sensible_recovery_efficiency_adjusted,
                                 fan_power: fan_power,
                                 distribution_system_idref: distribution_system_idref,
                                 is_shared_system: is_shared_system,
                                 in_unit_flow_rate: in_unit_flow_rate,
                                 fraction_recirculation: fraction_recirculation,
                                 preheating_fuel: preheating_fuel,
                                 preheating_efficiency_cop: preheating_efficiency_cop,
                                 preheating_fraction_load_served: preheating_fraction_load_served,
                                 precooling_fuel: precooling_fuel,
                                 precooling_efficiency_cop: precooling_efficiency_cop,
                                 precooling_fraction_load_served: precooling_fraction_load_served)
    end

    if args[:mech_vent_fan_type_2] != 'none'

      if [HPXML::MechVentTypeERV].include?(args[:mech_vent_fan_type_2])

        if args[:mech_vent_recovery_efficiency_type_2] == 'Unadjusted'
          total_recovery_efficiency = args[:mech_vent_total_recovery_efficiency_2]
          sensible_recovery_efficiency = args[:mech_vent_sensible_recovery_efficiency_2]
        elsif args[:mech_vent_recovery_efficiency_type_2] == 'Adjusted'
          total_recovery_efficiency_adjusted = args[:mech_vent_total_recovery_efficiency_2]
          sensible_recovery_efficiency_adjusted = args[:mech_vent_sensible_recovery_efficiency_2]
        end
      elsif [HPXML::MechVentTypeHRV].include?(args[:mech_vent_fan_type_2])
        if args[:mech_vent_recovery_efficiency_type_2] == 'Unadjusted'
          sensible_recovery_efficiency = args[:mech_vent_sensible_recovery_efficiency_2]
        elsif args[:mech_vent_recovery_efficiency_type_2] == 'Adjusted'
          sensible_recovery_efficiency_adjusted = args[:mech_vent_sensible_recovery_efficiency_2]
        end
      end

      if args[:mech_vent_hours_in_operation_2] != Constants.Auto
        hours_in_operation = args[:mech_vent_hours_in_operation_2]
      end

      if args[:mech_vent_fan_power_2] != Constants.Auto
        fan_power = args[:mech_vent_fan_power_2]
      end

      hpxml.ventilation_fans.add(id: 'SecondMechanicalVentilation',
                                 fan_type: args[:mech_vent_fan_type_2],
                                 rated_flow_rate: args[:mech_vent_flow_rate_2],
                                 hours_in_operation: hours_in_operation,
                                 used_for_whole_building_ventilation: true,
                                 total_recovery_efficiency: total_recovery_efficiency,
                                 total_recovery_efficiency_adjusted: total_recovery_efficiency_adjusted,
                                 sensible_recovery_efficiency: sensible_recovery_efficiency,
                                 sensible_recovery_efficiency_adjusted: sensible_recovery_efficiency_adjusted,
                                 fan_power: fan_power)
    end

    if (args[:kitchen_fans_quantity] == Constants.Auto) || (args[:kitchen_fans_quantity].to_i > 0)
      if args[:kitchen_fans_flow_rate].is_initialized
        if args[:kitchen_fans_flow_rate].get != Constants.Auto
          rated_flow_rate = args[:kitchen_fans_flow_rate].get.to_f
        end
      end

      if args[:kitchen_fans_power].is_initialized
        if args[:kitchen_fans_power].get != Constants.Auto
          fan_power = args[:kitchen_fans_power].get.to_f
        end
      end

      if args[:kitchen_fans_hours_in_operation].is_initialized
        if args[:kitchen_fans_hours_in_operation].get != Constants.Auto
          hours_in_operation = args[:kitchen_fans_hours_in_operation].get.to_f
        end
      end

      if args[:kitchen_fans_start_hour].is_initialized
        if args[:kitchen_fans_start_hour].get != Constants.Auto
          start_hour = args[:kitchen_fans_start_hour].get.to_i
        end
      end

      if args[:kitchen_fans_quantity] != Constants.Auto
        quantity = args[:kitchen_fans_quantity].to_i
      end

      hpxml.ventilation_fans.add(id: 'KitchenRangeFan',
                                 rated_flow_rate: rated_flow_rate,
                                 used_for_local_ventilation: true,
                                 hours_in_operation: hours_in_operation,
                                 fan_location: 'kitchen',
                                 fan_power: fan_power,
                                 start_hour: start_hour,
                                 quantity: quantity)
    end

    if (args[:bathroom_fans_quantity] == Constants.Auto) || (args[:bathroom_fans_quantity].to_i > 0)
      if args[:bathroom_fans_flow_rate].is_initialized
        if args[:bathroom_fans_flow_rate].get != Constants.Auto
          rated_flow_rate = args[:bathroom_fans_flow_rate].get.to_f
        end
      end

      if args[:bathroom_fans_power].is_initialized
        if args[:bathroom_fans_power].get != Constants.Auto
          fan_power = args[:bathroom_fans_power].get.to_f
        end
      end

      if args[:bathroom_fans_hours_in_operation].is_initialized
        if args[:bathroom_fans_hours_in_operation].get != Constants.Auto
          hours_in_operation = args[:bathroom_fans_hours_in_operation].get.to_f
        end
      end

      if args[:bathroom_fans_start_hour].is_initialized
        if args[:bathroom_fans_start_hour].get != Constants.Auto
          start_hour = args[:bathroom_fans_start_hour].get.to_i
        end
      end

      if args[:bathroom_fans_quantity] != Constants.Auto
        quantity = args[:bathroom_fans_quantity].to_i
      end

      hpxml.ventilation_fans.add(id: 'BathFans',
                                 rated_flow_rate: rated_flow_rate,
                                 used_for_local_ventilation: true,
                                 hours_in_operation: hours_in_operation,
                                 fan_location: 'bath',
                                 fan_power: fan_power,
                                 start_hour: start_hour,
                                 quantity: quantity)
    end

    if args[:whole_house_fan_present]
      hpxml.ventilation_fans.add(id: 'WholeHouseFan',
                                 rated_flow_rate: args[:whole_house_fan_flow_rate],
                                 used_for_seasonal_cooling_load_reduction: true,
                                 fan_power: args[:whole_house_fan_power])
    end
  end

  def self.set_water_heating_systems(hpxml, runner, args)
    water_heater_type = args[:water_heater_type]
    return if water_heater_type == 'none'

    if water_heater_type != HPXML::WaterHeaterTypeHeatPump
      fuel_type = args[:water_heater_fuel_type]
    else
      fuel_type = HPXML::FuelTypeElectricity
    end

    if args[:water_heater_location] != Constants.Auto
      location = args[:water_heater_location]
    end

    if args[:geometry_num_bathrooms] != Constants.Auto
      num_bathrooms = args[:geometry_num_bathrooms]
    end

    if args[:water_heater_tank_volume] != Constants.Auto
      tank_volume = args[:water_heater_tank_volume]
    end

    if args[:water_heater_setpoint_temperature] != Constants.Auto
      temperature = args[:water_heater_setpoint_temperature]
    end

    if not [HPXML::WaterHeaterTypeCombiStorage, HPXML::WaterHeaterTypeCombiTankless].include? water_heater_type
      if args[:water_heater_efficiency_type] == 'EnergyFactor'
        energy_factor = args[:water_heater_efficiency]
      elsif args[:water_heater_efficiency_type] == 'UniformEnergyFactor'
        uniform_energy_factor = args[:water_heater_efficiency]
        if water_heater_type != HPXML::WaterHeaterTypeTankless
          usage_bin = args[:water_heater_usage_bin].get if args[:water_heater_usage_bin].is_initialized
        end
      end
    end

    if (fuel_type != HPXML::FuelTypeElectricity) && (water_heater_type == HPXML::WaterHeaterTypeStorage)
      if args[:water_heater_recovery_efficiency] != Constants.Auto
        recovery_efficiency = args[:water_heater_recovery_efficiency]
      end
    end

    if [HPXML::WaterHeaterTypeTankless, HPXML::WaterHeaterTypeCombiTankless].include? water_heater_type
      tank_volume = nil
    end

    if [HPXML::WaterHeaterTypeTankless].include? water_heater_type
      heating_capacity = nil
      recovery_efficiency = nil
    elsif [HPXML::WaterHeaterTypeCombiTankless, HPXML::WaterHeaterTypeCombiStorage].include? water_heater_type
      fuel_type = nil
      heating_capacity = nil
      energy_factor = nil

      if hpxml.heating_systems.size == 0
        fail 'Combi boiler water heater specified but no heating system found.'
      end

      related_hvac_idref = hpxml.heating_systems[0].id
    end

    if [HPXML::WaterHeaterTypeCombiTankless, HPXML::WaterHeaterTypeCombiStorage].include? water_heater_type
      if args[:water_heater_standby_loss].is_initialized
        if args[:water_heater_standby_loss].get > 0
          standby_loss = args[:water_heater_standby_loss].get
        end
      end
    end

    if not [HPXML::WaterHeaterTypeTankless, HPXML::WaterHeaterTypeCombiTankless].include? water_heater_type
      if args[:water_heater_jacket_rvalue].is_initialized
        if args[:water_heater_jacket_rvalue].get > 0
          jacket_r_value = args[:water_heater_jacket_rvalue].get
        end
      end
    end

    if args[:water_heater_num_units_served] > 1
      is_shared_system = true
      number_of_units_served = args[:water_heater_num_units_served]
    end

    hpxml.water_heating_systems.add(id: 'WaterHeater',
                                    water_heater_type: water_heater_type,
                                    fuel_type: fuel_type,
                                    location: location,
                                    tank_volume: tank_volume,
                                    fraction_dhw_load_served: 1.0,
                                    energy_factor: energy_factor,
                                    uniform_energy_factor: uniform_energy_factor,
                                    usage_bin: usage_bin,
                                    recovery_efficiency: recovery_efficiency,
                                    related_hvac_idref: related_hvac_idref,
                                    standby_loss: standby_loss,
                                    jacket_r_value: jacket_r_value,
                                    temperature: temperature,
                                    is_shared_system: is_shared_system,
                                    number_of_units_served: number_of_units_served)
  end

  def self.set_hot_water_distribution(hpxml, runner, args)
    return if args[:water_heater_type] == 'none'

    if args[:dwhr_facilities_connected] != 'none'
      dwhr_facilities_connected = args[:dwhr_facilities_connected]
      dwhr_equal_flow = args[:dwhr_equal_flow]
      dwhr_efficiency = args[:dwhr_efficiency]
    end

    if args[:dhw_distribution_system_type] == HPXML::DHWDistTypeStandard
      if args[:dhw_distribution_standard_piping_length] != Constants.Auto
        standard_piping_length = args[:dhw_distribution_standard_piping_length]
      end
    else
      recirculation_control_type = args[:dhw_distribution_recirc_control_type]

      if args[:dhw_distribution_recirc_piping_length] != Constants.Auto
        recirculation_piping_length = args[:dhw_distribution_recirc_piping_length]
      end

      if args[:dhw_distribution_recirc_branch_piping_length] != Constants.Auto
        recirculation_branch_piping_length = args[:dhw_distribution_recirc_branch_piping_length]
      end

      if args[:dhw_distribution_recirc_pump_power] != Constants.Auto
        recirculation_pump_power = args[:dhw_distribution_recirc_pump_power]
      end
    end

    if args[:dhw_distribution_pipe_r] != Constants.Auto
      pipe_r_value = args[:dhw_distribution_pipe_r]
    end

    hpxml.hot_water_distributions.add(id: 'HotWaterDistribution',
                                      system_type: args[:dhw_distribution_system_type],
                                      standard_piping_length: standard_piping_length,
                                      recirculation_control_type: recirculation_control_type,
                                      recirculation_piping_length: recirculation_piping_length,
                                      recirculation_branch_piping_length: recirculation_branch_piping_length,
                                      recirculation_pump_power: recirculation_pump_power,
                                      pipe_r_value: pipe_r_value,
                                      dwhr_facilities_connected: dwhr_facilities_connected,
                                      dwhr_equal_flow: dwhr_equal_flow,
                                      dwhr_efficiency: dwhr_efficiency)
  end

  def self.set_water_fixtures(hpxml, runer, args)
    return if args[:water_heater_type] == 'none'

    hpxml.water_fixtures.add(id: 'ShowerFixture',
                             water_fixture_type: HPXML::WaterFixtureTypeShowerhead,
                             low_flow: args[:water_fixtures_shower_low_flow])

    hpxml.water_fixtures.add(id: 'SinkFixture',
                             water_fixture_type: HPXML::WaterFixtureTypeFaucet,
                             low_flow: args[:water_fixtures_sink_low_flow])

    if args[:water_fixtures_usage_multiplier] != 1.0
      hpxml.water_heating.water_fixtures_usage_multiplier = args[:water_fixtures_usage_multiplier]
    end
  end

  def self.get_absolute_tilt(tilt_str, roof_pitch, epw_file)
    tilt_str = tilt_str.downcase
    if tilt_str.start_with? 'roofpitch'
      roof_angle = Math.atan(roof_pitch / 12.0) * 180.0 / Math::PI
      return Float(eval(tilt_str.gsub('roofpitch', roof_angle.to_s)))
    elsif tilt_str.start_with? 'latitude'
      return Float(eval(tilt_str.gsub('latitude', epw_file.latitude.to_s)))
    else
      return Float(tilt_str)
    end
  end

  def self.set_solar_thermal(hpxml, runner, args, epw_file)
    return if args[:solar_thermal_system_type] == 'none'

    if args[:solar_thermal_solar_fraction] > 0
      solar_fraction = args[:solar_thermal_solar_fraction]
    else
      collector_area = args[:solar_thermal_collector_area]
      collector_loop_type = args[:solar_thermal_collector_loop_type]
      collector_type = args[:solar_thermal_collector_type]
      collector_azimuth = args[:solar_thermal_collector_azimuth]
      collector_tilt = get_absolute_tilt(args[:solar_thermal_collector_tilt], args[:geometry_roof_pitch], epw_file)
      collector_frta = args[:solar_thermal_collector_rated_optical_efficiency]
      collector_frul = args[:solar_thermal_collector_rated_thermal_losses]

      if args[:solar_thermal_storage_volume] != Constants.Auto
        storage_volume = args[:solar_thermal_storage_volume]
      end
    end

    if hpxml.water_heating_systems.size == 0
      fail 'Solar thermal system specified but no water heater found.'
    end

    hpxml.solar_thermal_systems.add(id: 'SolarThermalSystem',
                                    system_type: args[:solar_thermal_system_type],
                                    collector_area: collector_area,
                                    collector_loop_type: collector_loop_type,
                                    collector_type: collector_type,
                                    collector_azimuth: collector_azimuth,
                                    collector_tilt: collector_tilt,
                                    collector_frta: collector_frta,
                                    collector_frul: collector_frul,
                                    storage_volume: storage_volume,
                                    water_heating_system_idref: hpxml.water_heating_systems[0].id,
                                    solar_fraction: solar_fraction)
  end

  def self.set_pv_systems(hpxml, runner, args, epw_file)
    [args[:pv_system_module_type_1], args[:pv_system_module_type_2]].each_with_index do |pv_system_module_type, i|
      next if pv_system_module_type == 'none'

      if [args[:pv_system_module_type_1], args[:pv_system_module_type_2]][i] != Constants.Auto
        module_type = [args[:pv_system_module_type_1], args[:pv_system_module_type_2]][i]
      end

      if [args[:pv_system_location_1], args[:pv_system_location_2]][i] != Constants.Auto
        location = [args[:pv_system_location_1], args[:pv_system_location_2]][i]
      end

      if [args[:pv_system_tracking_1], args[:pv_system_tracking_2]][i] != Constants.Auto
        tracking = [args[:pv_system_tracking_1], args[:pv_system_tracking_2]][i]
      end

      max_power_output = [args[:pv_system_max_power_output_1], args[:pv_system_max_power_output_2]][i]

      if [args[:pv_system_inverter_efficiency_1], args[:pv_system_inverter_efficiency_2]][i].is_initialized
        inverter_efficiency = [args[:pv_system_inverter_efficiency_1], args[:pv_system_inverter_efficiency_2]][i].get
      end

      if [args[:pv_system_system_losses_fraction_1], args[:pv_system_system_losses_fraction_2]][i].is_initialized
        system_losses_fraction = [args[:pv_system_system_losses_fraction_1], args[:pv_system_system_losses_fraction_2]][i].get
      end

      num_units_served = [args[:pv_system_num_units_served_1], args[:pv_system_num_units_served_2]][i]
      if num_units_served > 1
        is_shared_system = true
        number_of_bedrooms_served = (args[:geometry_building_num_bedrooms].get * num_units_served / args[:geometry_building_num_units].get).to_i
      end

      hpxml.pv_systems.add(id: "PVSystem#{i + 1}",
                           location: location,
                           module_type: module_type,
                           tracking: tracking,
                           array_azimuth: [args[:pv_system_array_azimuth_1], args[:pv_system_array_azimuth_2]][i],
                           array_tilt: get_absolute_tilt([args[:pv_system_array_tilt_1], args[:pv_system_array_tilt_2]][i], args[:geometry_roof_pitch], epw_file),
                           max_power_output: max_power_output,
                           inverter_efficiency: inverter_efficiency,
                           system_losses_fraction: system_losses_fraction,
                           is_shared_system: is_shared_system,
                           number_of_bedrooms_served: number_of_bedrooms_served)
    end
  end

  def self.set_lighting(hpxml, runner, args)
    hpxml.lighting_groups.add(id: 'Lighting_CFL_Interior',
                              location: HPXML::LocationInterior,
                              fraction_of_units_in_location: args[:lighting_fraction_cfl_interior],
                              lighting_type: HPXML::LightingTypeCFL)
    hpxml.lighting_groups.add(id: 'Lighting_CFL_Exterior',
                              location: HPXML::LocationExterior,
                              fraction_of_units_in_location: args[:lighting_fraction_cfl_exterior],
                              lighting_type: HPXML::LightingTypeCFL)
    hpxml.lighting_groups.add(id: 'Lighting_CFL_Garage',
                              location: HPXML::LocationGarage,
                              fraction_of_units_in_location: args[:lighting_fraction_cfl_garage],
                              lighting_type: HPXML::LightingTypeCFL)
    hpxml.lighting_groups.add(id: 'Lighting_LFL_Interior',
                              location: HPXML::LocationInterior,
                              fraction_of_units_in_location: args[:lighting_fraction_lfl_interior],
                              lighting_type: HPXML::LightingTypeLFL)
    hpxml.lighting_groups.add(id: 'Lighting_LFL_Exterior',
                              location: HPXML::LocationExterior,
                              fraction_of_units_in_location: args[:lighting_fraction_lfl_exterior],
                              lighting_type: HPXML::LightingTypeLFL)
    hpxml.lighting_groups.add(id: 'Lighting_LFL_Garage',
                              location: HPXML::LocationGarage,
                              fraction_of_units_in_location: args[:lighting_fraction_lfl_garage],
                              lighting_type: HPXML::LightingTypeLFL)
    hpxml.lighting_groups.add(id: 'Lighting_LED_Interior',
                              location: HPXML::LocationInterior,
                              fraction_of_units_in_location: args[:lighting_fraction_led_interior],
                              lighting_type: HPXML::LightingTypeLED)
    hpxml.lighting_groups.add(id: 'Lighting_LED_Exterior',
                              location: HPXML::LocationExterior,
                              fraction_of_units_in_location: args[:lighting_fraction_led_exterior],
                              lighting_type: HPXML::LightingTypeLED)
    hpxml.lighting_groups.add(id: 'Lighting_LED_Garage',
                              location: HPXML::LocationGarage,
                              fraction_of_units_in_location: args[:lighting_fraction_led_garage],
                              lighting_type: HPXML::LightingTypeLED)

    if args[:lighting_usage_multiplier_interior] != 1.0
      hpxml.lighting.interior_usage_multiplier = args[:lighting_usage_multiplier_interior]
    end

    if args[:lighting_usage_multiplier_exterior] != 1.0
      hpxml.lighting.exterior_usage_multiplier = args[:lighting_usage_multiplier_exterior]
    end

    if args[:lighting_usage_multiplier_garage] != 1.0
      hpxml.lighting.garage_usage_multiplier = args[:lighting_usage_multiplier_garage]
    end

    return unless args[:holiday_lighting_present]

    hpxml.lighting.holiday_exists = true

    if args[:holiday_lighting_daily_kwh] != Constants.Auto
      hpxml.lighting.holiday_kwh_per_day = args[:holiday_lighting_daily_kwh]
    end

    if args[:holiday_lighting_period_begin_month] != Constants.Auto
      hpxml.lighting.holiday_period_begin_month = args[:holiday_lighting_period_begin_month]
    end

    if args[:holiday_lighting_period_begin_day_of_month] != Constants.Auto
      hpxml.lighting.holiday_period_begin_day = args[:holiday_lighting_period_begin_day_of_month]
    end

    if args[:holiday_lighting_period_end_month] != Constants.Auto
      hpxml.lighting.holiday_period_end_month = args[:holiday_lighting_period_end_month]
    end

    if args[:holiday_lighting_period_end_day_of_month] != Constants.Auto
      hpxml.lighting.holiday_period_end_day = args[:holiday_lighting_period_end_day_of_month]
    end
  end

  def self.set_dehumidifier(hpxml, runner, args)
    return if args[:dehumidifier_type] == 'none'

    if args[:dehumidifier_efficiency_type] == 'EnergyFactor'
      energy_factor = args[:dehumidifier_efficiency]
    elsif args[:dehumidifier_efficiency_type] == 'IntegratedEnergyFactor'
      integrated_energy_factor = args[:dehumidifier_efficiency]
    end

    hpxml.dehumidifiers.add(id: 'Dehumidifier',
                            type: args[:dehumidifier_type],
                            capacity: args[:dehumidifier_capacity],
                            energy_factor: energy_factor,
                            integrated_energy_factor: integrated_energy_factor,
                            rh_setpoint: args[:dehumidifier_rh_setpoint],
                            fraction_served: args[:dehumidifier_fraction_dehumidification_load_served],
                            location: HPXML::LocationLivingSpace)
  end

  def self.set_clothes_washer(hpxml, runner, args)
    if args[:water_heater_type] == 'none'
      args[:clothes_washer_location] = 'none'
    end

    return if args[:clothes_washer_location] == 'none'

    if args[:clothes_washer_rated_annual_kwh] != Constants.Auto
      rated_annual_kwh = args[:clothes_washer_rated_annual_kwh]
      return if Float(rated_annual_kwh) == 0
    end

    if args[:clothes_washer_location] != Constants.Auto
      location = args[:clothes_washer_location]
    end

    if args[:clothes_washer_efficiency] != Constants.Auto
      if args[:clothes_washer_efficiency_type] == 'ModifiedEnergyFactor'
        modified_energy_factor = args[:clothes_washer_efficiency].to_f
      elsif args[:clothes_washer_efficiency_type] == 'IntegratedModifiedEnergyFactor'
        integrated_modified_energy_factor = args[:clothes_washer_efficiency].to_f
      end
    end

    if args[:clothes_washer_label_electric_rate] != Constants.Auto
      label_electric_rate = args[:clothes_washer_label_electric_rate]
    end

    if args[:clothes_washer_label_gas_rate] != Constants.Auto
      label_gas_rate = args[:clothes_washer_label_gas_rate]
    end

    if args[:clothes_washer_label_annual_gas_cost] != Constants.Auto
      label_annual_gas_cost = args[:clothes_washer_label_annual_gas_cost]
    end

    if args[:clothes_washer_label_usage] != Constants.Auto
      label_usage = args[:clothes_washer_label_usage]
    end

    if args[:clothes_washer_capacity] != Constants.Auto
      capacity = args[:clothes_washer_capacity]
    end

    if args[:clothes_washer_usage_multiplier] != 1.0
      usage_multiplier = args[:clothes_washer_usage_multiplier]
    end

    hpxml.clothes_washers.add(id: 'ClothesWasher',
                              location: location,
                              modified_energy_factor: modified_energy_factor,
                              integrated_modified_energy_factor: integrated_modified_energy_factor,
                              rated_annual_kwh: rated_annual_kwh,
                              label_electric_rate: label_electric_rate,
                              label_gas_rate: label_gas_rate,
                              label_annual_gas_cost: label_annual_gas_cost,
                              label_usage: label_usage,
                              capacity: capacity,
                              usage_multiplier: usage_multiplier)
  end

  def self.set_clothes_dryer(hpxml, runner, args)
    return if args[:clothes_washer_location] == 'none'
    return if args[:clothes_dryer_location] == 'none'

    if args[:clothes_dryer_efficiency] != Constants.Auto
      if args[:clothes_dryer_efficiency_type] == 'EnergyFactor'
        energy_factor = args[:clothes_dryer_efficiency].to_f
      elsif args[:clothes_dryer_efficiency_type] == 'CombinedEnergyFactor'
        combined_energy_factor = args[:clothes_dryer_efficiency].to_f
      end
    end

    if args[:clothes_dryer_location] != Constants.Auto
      location = args[:clothes_dryer_location]
    end

    if args[:clothes_dryer_vented_flow_rate] != Constants.Auto
      is_vented = false
      if Float(args[:clothes_dryer_vented_flow_rate]) > 0
        is_vented = true
        vented_flow_rate = args[:clothes_dryer_vented_flow_rate]
      end
    end

    if args[:clothes_dryer_usage_multiplier] != 1.0
      usage_multiplier = args[:clothes_dryer_usage_multiplier]
    end

    hpxml.clothes_dryers.add(id: 'ClothesDryer',
                             location: location,
                             fuel_type: args[:clothes_dryer_fuel_type],
                             energy_factor: energy_factor,
                             combined_energy_factor: combined_energy_factor,
                             is_vented: is_vented,
                             vented_flow_rate: vented_flow_rate,
                             usage_multiplier: usage_multiplier)
  end

  def self.set_dishwasher(hpxml, runner, args)
    return if args[:dishwasher_location] == 'none'

    if args[:dishwasher_location] != Constants.Auto
      location = args[:dishwasher_location]
    end

    if args[:dishwasher_efficiency_type] == 'RatedAnnualkWh'
      if args[:dishwasher_efficiency] != Constants.Auto
        rated_annual_kwh = args[:dishwasher_efficiency]
        return if Float(rated_annual_kwh) == 0
      end
    elsif args[:dishwasher_efficiency_type] == 'EnergyFactor'
      energy_factor = args[:dishwasher_efficiency]
    end

    if args[:dishwasher_label_electric_rate] != Constants.Auto
      label_electric_rate = args[:dishwasher_label_electric_rate]
    end

    if args[:dishwasher_label_gas_rate] != Constants.Auto
      label_gas_rate = args[:dishwasher_label_gas_rate]
    end

    if args[:dishwasher_label_annual_gas_cost] != Constants.Auto
      label_annual_gas_cost = args[:dishwasher_label_annual_gas_cost]
    end

    if args[:dishwasher_label_usage] != Constants.Auto
      label_usage = args[:dishwasher_label_usage]
    end

    if args[:dishwasher_place_setting_capacity] != Constants.Auto
      place_setting_capacity = args[:dishwasher_place_setting_capacity]
    end

    if args[:dishwasher_usage_multiplier] != 1.0
      usage_multiplier = args[:dishwasher_usage_multiplier]
    end

    hpxml.dishwashers.add(id: 'Dishwasher',
                          location: location,
                          rated_annual_kwh: rated_annual_kwh,
                          energy_factor: energy_factor,
                          label_electric_rate: label_electric_rate,
                          label_gas_rate: label_gas_rate,
                          label_annual_gas_cost: label_annual_gas_cost,
                          label_usage: label_usage,
                          place_setting_capacity: place_setting_capacity,
                          usage_multiplier: usage_multiplier)
  end

  def self.set_refrigerator(hpxml, runner, args)
    return if args[:refrigerator_location] == 'none'

    if args[:refrigerator_rated_annual_kwh] != Constants.Auto
      rated_annual_kwh = args[:refrigerator_rated_annual_kwh]
      return if Float(rated_annual_kwh) == 0
    end

    if args[:refrigerator_location] != Constants.Auto
      location = args[:refrigerator_location]
    end

    if args[:refrigerator_usage_multiplier] != 1.0
      usage_multiplier = args[:refrigerator_usage_multiplier]
    end

    if args[:extra_refrigerator_location] != 'none'
      primary_indicator = true
    end

    hpxml.refrigerators.add(id: 'Refrigerator',
                            location: location,
                            rated_annual_kwh: rated_annual_kwh,
                            primary_indicator: primary_indicator,
                            usage_multiplier: usage_multiplier)
  end

  def self.set_extra_refrigerator(hpxml, runner, args)
    return if args[:extra_refrigerator_location] == 'none'

    if args[:extra_refrigerator_rated_annual_kwh] != Constants.Auto
      rated_annual_kwh = args[:extra_refrigerator_rated_annual_kwh]
      return if Float(rated_annual_kwh) == 0
    end

    if args[:extra_refrigerator_location] != Constants.Auto
      location = args[:extra_refrigerator_location]
    end

    if args[:extra_refrigerator_usage_multiplier] != 1.0
      usage_multiplier = args[:extra_refrigerator_usage_multiplier]
    end

    hpxml.refrigerators.add(id: 'ExtraRefrigerator',
                            location: location,
                            rated_annual_kwh: rated_annual_kwh,
                            primary_indicator: false,
                            usage_multiplier: usage_multiplier)
  end

  def self.set_freezer(hpxml, runner, args)
    return if args[:freezer_location] == 'none'

    if args[:freezer_rated_annual_kwh] != Constants.Auto
      rated_annual_kwh = args[:freezer_rated_annual_kwh]
      return if Float(rated_annual_kwh) == 0
    end

    if args[:freezer_location] != Constants.Auto
      location = args[:freezer_location]
    end

    if args[:freezer_usage_multiplier] != 1.0
      usage_multiplier = args[:freezer_usage_multiplier]
    end

    hpxml.freezers.add(id: 'Freezer',
                       location: location,
                       rated_annual_kwh: rated_annual_kwh,
                       usage_multiplier: usage_multiplier)
  end

  def self.set_cooking_range_oven(hpxml, runner, args)
    return if args[:cooking_range_oven_location] == 'none'

    if args[:cooking_range_oven_location] != Constants.Auto
      location = args[:cooking_range_oven_location]
    end

    if args[:cooking_range_oven_is_induction].is_initialized
      is_induction = args[:cooking_range_oven_is_induction].get
    end

    if args[:cooking_range_oven_usage_multiplier] != 1.0
      usage_multiplier = args[:cooking_range_oven_usage_multiplier]
    end

    hpxml.cooking_ranges.add(id: 'CookingRange',
                             location: location,
                             fuel_type: args[:cooking_range_oven_fuel_type],
                             is_induction: is_induction,
                             usage_multiplier: usage_multiplier)

    if args[:cooking_range_oven_is_convection].is_initialized
      is_convection = args[:cooking_range_oven_is_convection].get
    end

    hpxml.ovens.add(id: 'Oven',
                    is_convection: is_convection)
  end

  def self.set_ceiling_fans(hpxml, runner, args)
    return unless args[:ceiling_fan_present]

    if args[:ceiling_fan_efficiency] != Constants.Auto
      efficiency = args[:ceiling_fan_efficiency]
    end

    if args[:ceiling_fan_quantity] != Constants.Auto
      quantity = args[:ceiling_fan_quantity]
    end

    hpxml.ceiling_fans.add(id: 'CeilingFan',
                           efficiency: efficiency,
                           quantity: quantity)
  end

  def self.set_plug_loads_television(hpxml, runner, args)
    if args[:plug_loads_television_annual_kwh] != Constants.Auto
      kWh_per_year = args[:plug_loads_television_annual_kwh]
    end

    usage_multiplier = args[:plug_loads_television_usage_multiplier]
    if usage_multiplier == 1.0
      usage_multiplier = nil
    end

    hpxml.plug_loads.add(id: 'PlugLoadsTelevision',
                         plug_load_type: HPXML::PlugLoadTypeTelevision,
                         kWh_per_year: kWh_per_year,
                         usage_multiplier: usage_multiplier)
  end

  def self.set_plug_loads_other(hpxml, runner, args)
    if args[:plug_loads_other_annual_kwh] != Constants.Auto
      kWh_per_year = args[:plug_loads_other_annual_kwh]
    end

    if args[:plug_loads_other_frac_sensible] != Constants.Auto
      frac_sensible = args[:plug_loads_other_frac_sensible]
    end

    if args[:plug_loads_other_frac_latent] != Constants.Auto
      frac_latent = args[:plug_loads_other_frac_latent]
    end

    usage_multiplier = args[:plug_loads_other_usage_multiplier]
    if usage_multiplier == 1.0
      usage_multiplier = nil
    end

    hpxml.plug_loads.add(id: 'PlugLoadsOther',
                         plug_load_type: HPXML::PlugLoadTypeOther,
                         kWh_per_year: kWh_per_year,
                         frac_sensible: frac_sensible,
                         frac_latent: frac_latent,
                         usage_multiplier: usage_multiplier)
  end

  def self.set_plug_loads_well_pump(hpxml, runner, args)
    return unless args[:plug_loads_well_pump_present]

    if args[:plug_loads_well_pump_annual_kwh] != Constants.Auto
      kWh_per_year = args[:plug_loads_well_pump_annual_kwh]
    end

    usage_multiplier = args[:plug_loads_well_pump_usage_multiplier]
    if usage_multiplier == 1.0
      usage_multiplier = nil
    end

    hpxml.plug_loads.add(id: 'PlugLoadsWellPump',
                         plug_load_type: HPXML::PlugLoadTypeWellPump,
                         kWh_per_year: kWh_per_year,
                         usage_multiplier: usage_multiplier)
  end

  def self.set_plug_loads_vehicle(hpxml, runner, args)
    return unless args[:plug_loads_vehicle_present]

    if args[:plug_loads_vehicle_annual_kwh] != Constants.Auto
      kWh_per_year = args[:plug_loads_vehicle_annual_kwh]
    end

    usage_multiplier = args[:plug_loads_vehicle_usage_multiplier]
    if usage_multiplier == 1.0
      usage_multiplier = nil
    end

    hpxml.plug_loads.add(id: 'PlugLoadsVehicle',
                         plug_load_type: HPXML::PlugLoadTypeElectricVehicleCharging,
                         kWh_per_year: kWh_per_year,
                         usage_multiplier: usage_multiplier)
  end

  def self.set_fuel_loads_grill(hpxml, runner, args)
    if args[:fuel_loads_grill_present]
      if args[:fuel_loads_grill_annual_therm] != Constants.Auto
        therm_per_year = args[:fuel_loads_grill_annual_therm]
      end

      if args[:fuel_loads_grill_usage_multiplier] != 1.0
        usage_multiplier = args[:fuel_loads_grill_usage_multiplier]
      end

      hpxml.fuel_loads.add(id: 'FuelLoadsGrill',
                           fuel_load_type: HPXML::FuelLoadTypeGrill,
                           fuel_type: args[:fuel_loads_grill_fuel_type],
                           therm_per_year: therm_per_year,
                           usage_multiplier: usage_multiplier)
    end
  end

  def self.set_fuel_loads_lighting(hpxml, runner, args)
    if args[:fuel_loads_lighting_present]
      if args[:fuel_loads_lighting_annual_therm] != Constants.Auto
        therm_per_year = args[:fuel_loads_lighting_annual_therm]
      end

      if args[:fuel_loads_lighting_usage_multiplier] != 1.0
        usage_multiplier = args[:fuel_loads_lighting_usage_multiplier]
      end

      hpxml.fuel_loads.add(id: 'FuelLoadsLighting',
                           fuel_load_type: HPXML::FuelLoadTypeLighting,
                           fuel_type: args[:fuel_loads_lighting_fuel_type],
                           therm_per_year: therm_per_year,
                           usage_multiplier: usage_multiplier)
    end
  end

  def self.set_fuel_loads_fireplace(hpxml, runner, args)
    if args[:fuel_loads_fireplace_present]
      if args[:fuel_loads_fireplace_annual_therm] != Constants.Auto
        therm_per_year = args[:fuel_loads_fireplace_annual_therm]
      end

      if args[:fuel_loads_fireplace_frac_sensible] != Constants.Auto
        frac_sensible = args[:fuel_loads_fireplace_frac_sensible]
      end

      if args[:fuel_loads_fireplace_frac_latent] != Constants.Auto
        frac_latent = args[:fuel_loads_fireplace_frac_latent]
      end

      if args[:fuel_loads_fireplace_usage_multiplier] != 1.0
        usage_multiplier = args[:fuel_loads_fireplace_usage_multiplier]
      end

      hpxml.fuel_loads.add(id: 'FuelLoadsFireplace',
                           fuel_load_type: HPXML::FuelLoadTypeFireplace,
                           fuel_type: args[:fuel_loads_fireplace_fuel_type],
                           therm_per_year: therm_per_year,
                           frac_sensible: frac_sensible,
                           frac_latent: frac_latent,
                           usage_multiplier: usage_multiplier)
    end
  end

  def self.set_pool(hpxml, runner, args)
    return unless args[:pool_present]

    if args[:pool_pump_annual_kwh] != Constants.Auto
      pump_kwh_per_year = args[:pool_pump_annual_kwh]
    end

    if args[:pool_pump_usage_multiplier] != 1.0
      pump_usage_multiplier = args[:pool_pump_usage_multiplier]
    end

    pool_heater_type = args[:pool_heater_type]

    if [HPXML::HeaterTypeElectricResistance, HPXML::HeaterTypeHeatPump].include?(pool_heater_type)
      if args[:pool_heater_annual_kwh] != Constants.Auto
        heater_load_units = 'kWh/year'
        heater_load_value = args[:pool_heater_annual_kwh]
      end
    end

    if [HPXML::HeaterTypeGas].include?(pool_heater_type)
      if args[:pool_heater_annual_therm] != Constants.Auto
        heater_load_units = 'therm/year'
        heater_load_value = args[:pool_heater_annual_therm]
      end
    end

    if args[:pool_heater_usage_multiplier] != 1.0
      heater_usage_multiplier = args[:pool_heater_usage_multiplier]
    end

    hpxml.pools.add(id: 'Pool',
                    type: HPXML::TypeUnknown,
                    pump_type: HPXML::TypeUnknown,
                    pump_kwh_per_year: pump_kwh_per_year,
                    pump_usage_multiplier: pump_usage_multiplier,
                    heater_type: pool_heater_type,
                    heater_load_units: heater_load_units,
                    heater_load_value: heater_load_value,
                    heater_usage_multiplier: heater_usage_multiplier)
  end

  def self.set_hot_tub(hpxml, runner, args)
    return unless args[:hot_tub_present]

    if args[:hot_tub_pump_annual_kwh] != Constants.Auto
      pump_kwh_per_year = args[:hot_tub_pump_annual_kwh]
    end

    if args[:hot_tub_pump_usage_multiplier] != 1.0
      pump_usage_multiplier = args[:hot_tub_pump_usage_multiplier]
    end

    hot_tub_heater_type = args[:hot_tub_heater_type]

    if [HPXML::HeaterTypeElectricResistance, HPXML::HeaterTypeHeatPump].include?(hot_tub_heater_type)
      if args[:hot_tub_heater_annual_kwh] != Constants.Auto
        heater_load_units = 'kWh/year'
        heater_load_value = args[:hot_tub_heater_annual_kwh]
      end
    end

    if [HPXML::HeaterTypeGas].include?(hot_tub_heater_type)
      if args[:hot_tub_heater_annual_therm] != Constants.Auto
        heater_load_units = 'therm/year'
        heater_load_value = args[:hot_tub_heater_annual_therm]
      end
    end

    if args[:hot_tub_heater_usage_multiplier] != 1.0
      heater_usage_multiplier = args[:hot_tub_heater_usage_multiplier]
    end

    hpxml.hot_tubs.add(id: 'HotTub',
                       type: HPXML::TypeUnknown,
                       pump_type: HPXML::TypeUnknown,
                       pump_kwh_per_year: pump_kwh_per_year,
                       pump_usage_multiplier: pump_usage_multiplier,
                       heater_type: hot_tub_heater_type,
                       heater_load_units: heater_load_units,
                       heater_load_value: heater_load_value,
                       heater_usage_multiplier: heater_usage_multiplier)
  end

  def self.valid_attr(attr)
    attr = attr.to_s
    attr = attr.gsub(' ', '_')
    attr = attr.gsub('|', '_')
    return attr
  end

  def self.get_adjacent_to(surface)
    space = surface.space.get
    st = space.spaceType.get
    space_type = st.standardsSpaceType.get

    return space_type
  end

  def self.get_surface_azimuth(surface, args)
    facade = Geometry.get_facade_for_surface(surface)
    return get_azimuth_from_facade(facade, args)
  end

  def self.get_azimuth_from_facade(facade, args)
    if facade == Constants.FacadeFront
      azimuth = Geometry.get_abs_azimuth(Constants.CoordRelative, 0, args[:geometry_orientation], 0)
    elsif facade == Constants.FacadeBack
      azimuth = Geometry.get_abs_azimuth(Constants.CoordRelative, 180, args[:geometry_orientation], 0)
    elsif facade == Constants.FacadeLeft
      azimuth = Geometry.get_abs_azimuth(Constants.CoordRelative, 90, args[:geometry_orientation], 0)
    elsif facade == Constants.FacadeRight
      azimuth = Geometry.get_abs_azimuth(Constants.CoordRelative, 270, args[:geometry_orientation], 0)
    else
      fail 'Unexpected facade.'
    end
  end
end

# register the measure to be used by the application
BuildResidentialHPXML.new.registerWithApplication
