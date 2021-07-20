The Stochastic Occupancy Modeling introduces major change to most occupant-related schedules.
Occupant activities are now generated on-the-fly and saved to .csv files used by Schedule:File objects.
Schedules are generated using time-inhomogenous Markov chains derived from American Time Use Survey data, supplemented with sampling duration and power level from NEEA RBSA data, as well as DHW draw duration and flow rate data from Aquacraft/AWWA data.

It outputs a schedule.csv file (which will be available inside generated_files folder of each building simulation output).
The schedule.csv file contains the following columns: occupants, cooking_range, plug_loads, lighting_interior, lighting_exterior, lighting_garage, lighting_exterior_holiday, clothes_washer, clothes_dryer, dishwasher, baths, showers, sinks, ceiling_fan, clothes_dryer_exhaust, clothes_washer_power, dishwasher_power, sleep, vacancy.

Each of the columns, except the occupants, sleep, and vacancy represent schedule values (kW for power schedules, and gallons per minute for water schedules) normalized using universal maximum values found in constants.rb.

The occupants column represents the fractional percent of occupants present out of the total number of occupants assigned to the unit.
The sleep column represents the fractional percent of the total number of occupants who are sleeping.
And the vacancy column will either be 0 or 1 depending upon if the vacancy period is in effect.

There are the same number of rows as the total simulation time-step (e.g., 35040 if 15-min, 8760 if hourly (8784, if leap year)).

The ScheduleGenerator class uses Markov chain based simulation to generate the schedule.csv. To support that, several pre-generated set of files are used:

`weekday`
`weekend`

These two folders contain the Markov chain initial probability, Markov chain transition and also appliance duration probabilities csv files.
The appliance duration probabilities here are used during the Markov chain simulation to determine duration of various appliances.
The files are divided into four clusters (cluster0 to cluster3), for 4 types of occupant behavior types.

`<enduse>_power_consumption_dist.csv`

These files contain the 15-min power consumption kWh samples for the given end use, obtained from RBSA (average 15-min end use kWh for each submetered home; N=number of homes with that end use).
The schedule generator randomly picks one of these values to determine the power level of the appliance schedule.

`<enduse>_power_duration_dist.csv`

These files contain the samples of runtime duration of different end uses, in 15-min increments, generated from the RBSA dataset.
So, a value of 3 means, 45 minutes.
Each row is for one household, and each column is the duration of one instance of the appliance running.

`<enduse>_cluster_size_probability.csv`

These files contain the probability distribution of the event cluster size for different domestic hot water end uses, obtained from the HotWaterEventScheduleGenerator Excel file.
The first row is the probability of a cluster size of 1 event, second row for probability of cluster size of 2 events and so on.

`schedule_config.yml`

This yaml file contains various miscellaneous configurations for the schedule generator, and their meanings and sources are defined within the file.

The new methods for generating and reading stochastic schedules adds some extra I/O. We expect a 10%-15% increase in runtime due to this new capability.
