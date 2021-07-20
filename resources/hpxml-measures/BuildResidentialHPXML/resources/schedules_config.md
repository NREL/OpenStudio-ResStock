### Occupancy Types

Occupancy cluster types: Mostly Home, Early Regular Worker, Mostly Away, Regular Worker.
Probabilities are derived from ATUS using the k-modes algorithm.

### Plug Loads

This is the baseline schedule for plugload, lighting and ceiling fan.
It will be modified based on occupancy.

### Lighting

The exterior and garage lighting makes use of the weekday/weekend schedule.
Indoor lighting schedule is generated on the fly. 
Holiday lighting makes use of the holiday_sch.

### Cooking

Monthly energy use multipliers for cooking stove/oven/range from average of multiple end-use submetering datasets (HEMS, RBSAM, ELCAP, Mass Res 1, Pecan St.).
Power draw distribution is based on csv files.

### Clothes Dryer

Monthly energy use multipliers for clothes dryer from average of multiple end-use submetering datasets (HEMS, RBSAM, ELCAP, Mass Res 1, Pecan St., FSEC).
Power draw distribution is based on csv files.

### Clothes Washer

Monthly energy use multipliers for clothes washer and dishwasher from average of multiple end-use submetering datasets (generally HEMS, RBSAM, ELCAP, Mass Res 1, and Pecan St.).
Power draw distribution is based on csv files.

### Dishwasher

Monthly energy use multipliers for clothes washer and dishwasher from average of multiple end-use submetering datasets (generally HEMS, RBSAM, ELCAP, Mass Res 1, Pecan St., and FSEC).
Power draw distribution is based on csv files.

### Water Draw Events

Probabilities for all water draw events are extracted from DHW event generators.
The onset, duration, events_per_cluster_probs, flow rate mean and std could all refer to the DHW event generator excel sheet ('event characteristics' and 'Start Times' sheet).

#### sink
avg_sink_clusters_per_hh -> Average sink cluster per house hold. Set to 6657 for U.S. average of 2.53 occupants per household, based on relationship of 6885 clusters for 25 gpd, from Building America DHW Event Schedule Generator,
