Set Up the Analysis Project
===========================

At the top level of the ResStock repository you just downloaded, you will see two analysis project folders:

 - project_national
 - project_testing
 
OpenStudio Measures
-------------------

.. _simulation-controls:

Simulation Controls
^^^^^^^^^^^^^^^^^^^

Using this measure you can set the simulation timesteps per hour, the run period begin month/day and end month/day, and the calendar year (for start day of week). By default the simulations use a 10-min timestep (i.e., the number of timesteps per hour is 6), start on January 1, end on December 31, and run with a calendar year of 2007 (start day of week is Monday). If you are running simulations using AMY weather files, the value entered for calendar year will not be used; it will be overridden by the actual year found in the AMY weather file.

.. _build-existing-model:

Build Existing Model
^^^^^^^^^^^^^^^^^^^^

This measure creates the baseline scenario. It incrementally applies OpenStudio measures (located in the ``resources`` directory, which should be at the same level as your project directory) to create residential building models. Set the following inputs:

**Building ID -- Max**
  This sets the number of simulations to run in the baseline and each upgrade case. For this tutorial I am going to set this to 1000. Most analyses will require more, but we're going to keep the total number small for simulation time and cost.

**Number of Buildings Represented**
  The total number of buildings this sampling is meant to represent. This sets the weighting factors. For the U.S. single-family detached housing stock, this is 80 million homes. 
  
**Sample Weight of Simulation**
  The number of buildings each simulation represents. Total number of buildings / Number of simulations. This argument is optional (it is only needed for running simulations on NREL HPC), so you can leave it blank.
  
**Downselect Logic**
  Logic that specifies the subset of the building stock to be considered in the analysis. Specify one or more ``parameter|option`` as found in the ``resources/options_lookup.tsv``. (This uses the same syntax as the :ref:`tutorial-apply-upgrade` measure.) For example, if you wanted to only simulate California homes you could enter ``Location Region|CR11`` in this field (CR refers to "Custom Region", which is based on RECS 2009 reportable domains aggregated into groups with similar climates; see the entire `custom region map`_). Datapoints that are excluded from the downselect logic will result in "completed invalid workflow". Note that the **Building ID - Max** input refers to the number of datapoints *before* downselection, not after. This means that the number of datapoints remaining after downselection would be somewhere between zero (i.e., no datapoints matched the downselect logic) and **Building ID - Max** (i.e., all datapoints matched the downselect logic).

**Measures to Ignore**
  **INTENDED FOR ADVANCED USERS/WORKFLOW DEVELOPERS ONLY.** Measures to exclude from the OpenStudio Workflow specified by listing one or more measure directories separated by '|'. Core ResStock measures cannot be ignored (the Build Existing Model measure will fail).

.. _custom region map: https://github.com/NREL/resstock/wiki/Custom-Region-(CR)-Map

.. note::
   
   **Manual Sampling**: To run the sampling script yourself, from the command line execute, e.g. ``ruby resources/run_sampling.rb -p project_national -n 10000 -o buildstock.csv``, and a file ``buildstock.csv`` will be created in the ``resources`` directory. 
   
   If a custom ``buildstock.csv`` file is located in a project's ``housing_characteristics`` directory when you run the project, it will automatically be used to generate simulations. If it’s not found, the ``run_sampling.rb`` script will be run automatically on OpenStudio-Server to create one. You’ll also want to make sure that the number of buildings in the sampling csv file matches the max value for the Building ID argument in the Build Existing Model, as that tells OpenStudio how many datapoints to run. (For each datapoint, the measure will then look up its building description from the sampling csv.) 
   
   You can use this manual sampling process to downselect which simulations you want to run. For example, you can use the command above to generate a ``buildstock.csv`` for the entire U.S. and then open up this file in Excel and delete all of the rows that you don't want to simulate (e.g., all rows that aren't in New York). Keep in mind that if you do this, you will need to re-enumerate the "Building" column as "1" through the number of rows.
  
.. _tutorial-apply-upgrade:

Apply Upgrade
^^^^^^^^^^^^^

Each "Apply Upgrade" measure defines an upgrade scenario. An upgrade scenario is a collection of options exercised with some logic and costs applied. In the simplest case, we apply the new option to all houses. The available upgrade options are in ``resources/options_lookup.tsv`` in your git repository. 

For this example, we will upgrade all windows by applying the ``Windows|Triple, Low-E, Non-metal, Air, L-Gain`` option to all houses across the country. We do this by entering that in the **Option 1** box on the Apply Upgrade measure. Also, we'll give the upgrade scenario a name: "Triple-Pane Windows" and a cost of $40/ft\ :superscript:`2` of window area by entering the number in **Option 1 Cost Value** and selecting "Window Area (ft^2)" for **Option 1 Cost Multiplier**. 

Like the **downselect logic**, excluded datapoints (i.e., datapoints for which the upgrade does not apply) will result in "completed invalid workflow". For a full explanation of how to set up the options and logic surrounding them, see :doc:`../upgrade_scenario_config`.

Reporting Measures
------------------

Scroll down to the bottom on the Measures Selection tab, and you will see the **Reporting Measures** section. This section is where you can request timeseries data and utility bills for the analysis. In general, reporting measures process data after the simulation has finished and produced results. As a note, make sure that the **Timeseries CSV Export** and **Utility Bill Calculations** measures are placed before the **Server Directory Cleanup** measure.

.. _simulation-output-report:

Simulation Output Report
^^^^^^^^^^^^^^^^^^^^^^^^

Leave this alone if you do not want to report annual totals for end use subcategories. Select **Include End Use Subcategories** if you want to report them. See below for a listing of available end use subcategories.

.. _timeseries-csv-export:

Timeseries CSV Export
^^^^^^^^^^^^^^^^^^^^^

If you do not need the timeseries data for your simulations, you can skip this measure to save disk space. Otherwise, one csv file per datapoint will be written containing end use timeseries data for their model.

End uses include:

  * total site energy [MBtu]
  * net site energy [MBtu]
  * total site [electric/gas/oil/propane/wood] [kWh/therm/MBtu/MBtu/MBtu]
  * net site [electric] [kWh]
  * heating [electric/gas/oil/propane/wood] [kWh/therm/MBtu/MBtu/MBtu]
  * cooling [kWh]
  * central system heating [electric/gas/oil/propane] [kWh/therm/MBtu/MBtu]
  * central system cooling [electric] [kWh]
  * interior lighting [kWh]
  * exterior lighting [kWh]
  * exterior holiday lighting [kWh]
  * garage lighting [kWh]
  * interior equipment [electric/gas/propane] [kWh/therm/MBtu/MBtu]
  * fans heating [kWh]
  * fans cooling [kWh]
  * pumps heating [kWh]
  * pumps cooling [kWh]
  * central system pumps heating [electric] [kWh]
  * central system pumps cooling [electric] [kWh]
  * water heating [electric/gas/oil/propane] [kWh/therm/MBtu/MBtu]
  * pv [kWh]

**Reporting Frequency**
  The timeseries data will be reported at hourly intervals unless otherwise specified. Alternative reporting frequencies include:

  * Timestep
  * Daily
  * Monthly
  * Runperiod
  
  Setting the reporting frequency to 'Timestep' will give you interval output equal to the zone timestep set by the :ref:`simulation-controls` measure. Thus, this measure will produce 10-min interval output when you select 'Timestep' and leave the :ref:`simulation-controls` measure at its default settings.

**Include End Use Subcategories**
  Select this to include end use subcategories. The default is to not include end use subcategories. End use subcategories include:
  
  * refrigerator [kWh]
  * clothes washer [kWh]
  * clothes dryer [electric/gas/propane] [kWh/therm/MBtu]
  * cooking range [electric/gas/propane] [kWh/therm/MBtu]
  * dishwasher [kWh]
  * plug loads [kWh]
  * house fan [kWh]
  * range fan [kWh]
  * bath fan [kWh]
  * ceiling fan [kWh]
  * extra refrigerator [kWh]
  * freezer [kWh]
  * pool heater [electric/gas] [kWh/therm]
  * pool pump [kWh]
  * hot tub heater [electric/gas] [kWh/therm]
  * hot tub pump [kWh]
  * gas grill [therm]
  * gas lighting [therm]
  * gas fireplace [therm]
  * well pump [kWh]  
  * hot water recirculation pump [kWh]
  * vehicle [kWh]
  
**Output Variables**
  If you choose to report any output variables (e.g., "Zone Air Temperature" or "Site Outdoor Air Humidity Ratio"), enter a comma-separated list of output variable names. A list of available output variables can be viewed in EnergyPlus's ``.rdd`` file.

.. _utility-bill-calculations:

Utility Bill Calculations
^^^^^^^^^^^^^^^^^^^^^^^^^

This measure is currently under construction.
