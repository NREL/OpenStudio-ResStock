Getting Started
===============

Setup
-----

To get started:

#. Download `OpenStudio 3.2.1 <https://github.com/NREL/OpenStudio/releases/tag/v3.2.1>`_ and install the Command Line Interface/EnergyPlus components, or use the `nrel/openstudio docker image <https://hub.docker.com/r/nrel/openstudio>`_.
#. Download the `latest release <https://github.com/NREL/OpenStudio-HPXML/releases>`_.

Running
-------

To programatically run simulations, it's recommended to use the OpenStudio `Command Line Interface <http://nrel.github.io/OpenStudio-user-documentation/reference/command_line_interface/>`_.
Two general approaches (basic and advanced) for running via the CLI are described below.
The OpenStudio measures can also be run from user interfaces (e.g., the OpenStudio Application or OpenStudio Parametric Analysis Tool (PAT)).

.. note:: 

  If the ``openstudio`` command is not found, it's because the executable is not in your PATH. Either add the executable to your PATH or point directly to the executable found in the openstudio-X.X.X/bin directory.

Basic Run
~~~~~~~~~

The simplest and fastest method is to call the OpenStudio CLI with the provided ``workflow/run_simulation.rb`` script.

For example:
``openstudio workflow/run_simulation.rb -x workflow/sample_files/base.xml``

This will create a "run" directory with all input/output files.
By default it will be found at the same location as the input HPXML file.

Run ``openstudio workflow/run_simulation.rb -h`` to see all available commands/arguments.

Advanced Run
~~~~~~~~~~~~
 
If additional flexibility is desired (e.g., specifying individual measure arguments, including additional OpenStudio measures to run alongside this measure in a workflow, etc.), create an `OpenStudio Workflow (OSW) <https://nrel.github.io/OpenStudio-user-documentation/reference/command_line_interface/#osw-structure>`_ file.
The OSW is a JSON file that will specify all the OpenStudio measures (and their arguments) to be run sequentially.
A template OSW that simply runs the HPXMLtoOpenStudio and SimulationOutputReport measures on the ``workflow/sample_files/base.xml`` file can be found at ``workflow/template.osw``.

For example:
``openstudio run -w workflow/template.osw``

This will create a "run" directory with all input/output files.
By default it will be found at the same location as the OSW file.

Outputs
~~~~~~~

In addition to the standard EnergyPlus outputs found in the run directory, a variety of high-level annual outputs are conveniently reported in the resulting ``run/results_annual.csv`` (or ``run/results_annual.json``) file.

Timeseries outputs can also be requested using either the Basic or Advanced approaches.
When requested, timeseries outputs will be found in the ``run/results_timeseries.csv`` (or ``run/results_timeseries.json``) file.

See :ref:`workflow_outputs` for a description of all available outputs available.
