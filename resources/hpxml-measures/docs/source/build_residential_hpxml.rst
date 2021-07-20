BuildResidentialHPXML
=====================

The BuildResidentialHPXML measure builds a residential HPXML file.
The HPXML file that it produces is intended to be the input for the HPXMLtoOpenStudio measure.

Capabilities
------------

The following arguments are used to populate fields of the HPXML file:

- Paths

  - HPXML File
  - Weather Directory

- Software Program

  - Name
  - Version

- Simulation Control

  - Timestep
  - Begin Month/Day
  - End Month/Day
  - Daylight Saving Begin Month/Day
  - Daylight Saving End Month/Day

- Schedules

  - Type (Average, Stochastic, User-Specified)
  - Path
  - Vacancy Begin Month/Day
  - Vacancy End Month/Day

- Weather

  - Station EPW Filename

- Geometry

  - Unit Type (manufactured home, single-family detached, single-family attached, apartment unit)
  - Building Orientation (Number of Units, Horizontal/Vertical Level)

- Enclosure

  - Attics (Vented, Unvented, Conditioned)
  - Foundations (Slab, Unconditioned Basement, Conditioned Basement, Vented Crawlspace, Unvented Crawlspace, Ambient)
  - Garages
  - Windows & Overhangs
  - Skylights
  - Doors
  
- HVAC

  - Heating Systems (Electric Resistance, Furnaces, Wall/Floor Furnaces, Stoves, Boilers, Portable Heaters, Fireplaces)
  - Cooling Systems (Central Air Conditioners, Room Air Conditioners, Evaporative Coolers)
  - Heat Pumps (Air Source, Mini Split, Ground Source, Dual-Fuel)
  - Dehumidifier
  - Setpoints
  - Ducts
  
- Water Heating

  - Water Heaters (Storage, Tankless, Heat Pump, Indirect, Tankless Coil)
  - Solar Hot Water
  - Hot Water Distribution (Standard, Recirculation)
  - Drain Water Heat Recovery
  - Hot Water Fixtures
  
- Ventilation

  - Mechanical Ventilation (Exhaust, Supply, Balanced, ERV, HRV, CFIS)
  - Kitchen Fan
  - Bathroom Fans
  - Whole House Fan

- Photovoltaics
- Appliances (Clothes Washer/Dryer, Dishwasher, Refrigerator, Extra Refrigerator, Freezer, Cooking Range/Oven)
- Lighting (Interior, Exterior, Garage, Holiday)
- Ceiling Fans
- Plug Loads (Other, TV, Well Pump, Vehicle)
- Fuel Loads (Grill, Lighting, Fireplace)
- Pool (Pump, Heater)
- Hot Tub (Pump, Heater)

Software Tools
--------------

The following are software tools that currently use the OpenStudio-HPXML workflow for simulating residential buildings.

ResStock™
~~~~~~~~~

ResStock uses a subset of all the capabilities of OpenStudio-HPXML:

#. At most, one heating system and one cooling system can be simulated. This means that both a heating system and heat pump, or cooling system and heat pump, cannot be simulated.
#. At most, one water heater can be simulated.
#. Not supporting skylights adjacent to unconditioned space.
#. Not supporting walkout basements.
#. Not supporting DSE.
#. Not supporting constant ACH infiltration.

URBANopt
~~~~~~~~

URBANopt uses the same subset of capabilities as ResStock. However, there is more mapping/defaulting of argument values in URBANopt:

#. TODO