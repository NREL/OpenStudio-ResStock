Introduction
============

The OpenStudio-HPXML repository consists of a simple residential EnergyPlus-based workflow build on top of `OpenStudio measures <http://nrel.github.io/OpenStudio-user-documentation/getting_started/about_measures/>`_.
The workflow operates using `HPXML building description files <https://hpxml.nrel.gov>`_.

The three OpenStudio measures used by the workflow are:

#. ``BuildResidentialHPXML``: A measure that translates a set of building unit argument values to an HPXML file.
#. ``HPXMLtoOpenStudio``: A measure that translates an HPXML file to an OpenStudio model.
#. ``SimulationOutputReport``: A reporting measure that generates a variety of annual/timeseries outputs for a residential HPXML-based model.

Scope (Dwelling Units)
----------------------

The OpenStudio-HPXML workflow is intended to be used to model individual residential dwelling units -- either a single-family detached (SFD) building, or a single unit of a single-family attached (SFA) or multifamily (MF) building.
This approach was taken because:

- It is required/desired for certain projects.
- It improves runtime speed by being able to simulate individual units in parallel (as opposed to simulating the entire building).
- It doesn't necessarily preclude the possibility of running a single integrated EnergyPlus simulation.

To model units of SFA/MF buildings, current capabilities include:

- Defining surfaces adjacent to generic SFA/MF spaces (e.g., "other housing unit" or "other multifamily buffer space").
- Locating various building components (e.g., ducts, water heaters, appliances) in these SFA/MF spaces.
- Defining shared systems (HVAC, water heating, mechanical ventilation, etc.) by approximating the energy use attributed to the unit.

Note that only the energy use attributed to each dwelling unit is calculated.
Other OpenStudio capabilities should be used to supplement this workflow if the energy use of non-residential dwelling spaces (e.g., gyms, elevators, corridors, etc.) are of interest.

For situations where more complex, integrated modeling is required, it is possible to merge multiple OpenStudio models together into a single model, such that one could merge all residential OSMs together and potentially combine it with a commercial OSM.
That capability is outside the scope of this project.

Accuracy vs Speed
-----------------

The EnergyPlus simulation engine is like a Swiss army knife.
There are often multiple models available for the same building technology with varying trade-offs between accuracy and speed.
This workflow standardizes the use of EnergyPlus (e.g., the choice of models appropriate for residential buildings) to provide a fast and easy to use solution.

The workflow is continuously being evaluated for ways to reduce runtime without significant impact on accuracy.
End-to-end simulations typically run in 3-10 seconds, depending on complexity, computer platform and speed, etc.

There are additional ways that software developers using this workflow can reduce runtime:

- Run on Linux/Mac platform, which is significantly faster than Windows.
- Run on computing environments with 1) fast CPUs, 2) sufficient memory, and 3) enough processors to allow all simulations to run in parallel.
- Limit requests for timeseries output (e.g., ``--hourly``, ``--daily``, ``--timestep`` arguments) and limit the number of output variables requested.
- Avoid using the ``--add-component-loads`` argument if heating/cooling component loads are not of interest.
- Use the ``--skip-validation`` argument if the HPXML input file has already been validated against the Schema & Schematron documents.

License
-------

This project is available under a BSD-3-like license, which is a free, open-source, and permissive license. For more information, check out the `license file <https://github.com/NREL/OpenStudio-HPXML/blob/master/LICENSE.md>`_.
