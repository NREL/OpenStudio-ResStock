#import packages
import pandas as pd
import numpy as np
import os

#set working directory
default_dir = "C:/Users/epresent/Documents/Mini Projects/Facades/ResStock Results/infiltration_check_run500No3"

#load utility bill costs
df_elec_costs = pd.read_csv("Fuel Price Input Files/Variable Elec Cost by State from EIA State Data.csv")
df_ng_costs = pd.read_csv('Fuel Price Input Files/NG costs by state.csv')
df_fo_costs = pd.read_csv('Fuel Price Input Files/Fuel Oil Prices Averaged by State.csv')
df_lp_costs = pd.read_csv('Fuel Price Input Files/Propane costs by state.csv')

#define constants
btu_propane_in_one_gallon = 91452 #source: https://www.eia.gov/energyexplained/units-and-calculators/
gallons_to_barrels = 42 #source: https://www.eia.gov/energyexplained/units-and-calculators/
btu_fueloil_in_one_barrel = 6287000 #source: https://www.eia.gov/energyexplained/units-and-calculators/


##define functions

#choose results columns to work with
selected_cols = [
    'building_id', 
    'simulation_output_report.total_site_electricity_kwh', 
    'simulation_output_report.total_site_natural_gas_therm',
    'simulation_output_report.total_site_fuel_oil_mbtu',
    'simulation_output_report.total_site_propane_mbtu',
    'simulation_output_report.total_site_energy_mbtu',
    'simulation_output_report.upgrade_cost_usd']
def downselect_cols(df):
	df = df[selected_cols]
	return df

#calculate total energy difference for each upgrade, for each home, add to the mini dataframes
def calc_delta_elec(df_baseline, df_upgrade):
	return (df_baseline['simulation_output_report.total_site_electricity_kwh']-df_upgrade['simulation_output_report.total_site_electricity_kwh'])
def calc_delta_ng(df_baseline, df_upgrade):
	return (df_baseline['simulation_output_report.total_site_natural_gas_therm']-df_upgrade['simulation_output_report.total_site_natural_gas_therm'])
def calc_delta_fo(df_baseline, df_upgrade):
	return (df_baseline['simulation_output_report.total_site_fuel_oil_mbtu']-df_upgrade['simulation_output_report.total_site_fuel_oil_mbtu'])
def calc_delta_lp(df_baseline, df_upgrade):
	return (df_baseline['simulation_output_report.total_site_propane_mbtu']-df_upgrade['simulation_output_report.total_site_propane_mbtu'])
def calc_delta_energy(df_baseline, df_upgrade):
    return(df_baseline['simulation_output_report.total_site_energy_mbtu']-df_upgrade['simulation_output_report.total_site_energy_mbtu'])

#calculate year1 utility bill savings
def calc_year1_bill_savings(var_util_costs, delta_energy):
	return (var_util_costs*delta_energy)
def calc_year1_fo_bill_savings(var_util_costs, delta_energy):
	return (delta_energy *
            var_util_costs*
            gallons_to_barrels*
            (1/btu_fueloil_in_one_barrel)*
            1000000)
def calc_year1_lp_bill_savings(var_util_costs, delta_energy):
    return(delta_energy *
           var_util_costs*
           (1/btu_propane_in_one_gallon)*
           1000000)

#calculate simple payback period
def calc_spp(upfront_cost, year1_savings):
	return(upfront_cost/year1_savings)

#calculate npv
analysis_period = 30
discount_rate = 0.034
def calc_npv(upfront_cost, year1_savings): #note: assuming 30 year lifetime for everything, which is not a general solution to this situation
	npv_list = []
	for cost, savings in zip(upfront_cost, year1_savings): #this loops through all the rows in the results_csv (ie each dwelling unit)
		cost_array = [0]*(analysis_period+1)
		cost_array[0] = cost
		savings_array = [savings] * (analysis_period+1)
        savings_array[0] = 0
		cash_flows = list(np.array(savings_array)-np.array(cost_array))
		npv = 0
		for year in range(0,analysis_period + 1):
			npv += (1/((1 + discount_rate) ** year)) * cash_flows[year]
		npv_list.append(npv)
	return npv_list

##Set up and run things!
#number of upgrade packages
num_ups = 4

#load baseline results
results_b = pd.read_parquet(os.path.join(default_dir, "results_up00.parquet"), engine = "auto")

#add utility bill cost unformation to the baseline results
results_b = pd.merge(results_b, df_elec_costs[['State', 'Variable Elec Cost $/kWh']], left_on = "build_existing_model.state", right_on = 'State', how = 'left')
results_b = results_b.drop(['State'], 1)
results_b = pd.merge(results_b, df_ng_costs[['State', 'NG Cost without Meter Charge [$/therm]']], left_on = "build_existing_model.state", right_on = 'State', how = 'left')
results_b = results_b.drop(['State'], 1)
results_b = pd.merge(results_b, df_fo_costs[['State', 'Average FO Price [$/gal]']], left_on = "build_existing_model.state", right_on = 'State', how = 'left')
results_b = results_b.drop(['State'], 1)
results_b = pd.merge(results_b, df_lp_costs[['State', 'Average Weekly Cost [$/gal]']], left_on = "build_existing_model.state", right_on = 'State', how = 'left')
results_b = results_b.drop(['State'], 1)
results_b.rename(columns={
    'Variable Elec Cost $/kWh': 'Elec Variable Cost [$/kWh]',
    'NG Cost without Meter Charge [$/therm]': 'NG Variable Cost [$/therm]', 
    'Average FO Price [$/gal]': 'FO Average Cost [$/gal]',
    'Average Weekly Cost [$/gal]': 'LP Average Price [$/gal]'},
    inplace=True)


#define string parts for upgrades
file_start = "results_up"
file_end = ".parquet"
up_start = "up"

#do economic calculations for each upgrade package
for i in range(1, num_ups+1):
    if i<10:
        upnum = "0" + str(i)
    else:
        upnum = str(i)
    filename = file_start + upnum + file_end
    upgrade = up_start + upnum
    results_up = pd.read_parquet(os.path.join(default_dir, filename), engine = "auto")
    df = downselect_cols(results_up)
    #calculate changes in energy use for each fuel
    delta_elec = calc_delta_elec(results_b, df)
    results_b[upgrade + "_delta_elec_kWh"] = delta_elec
    delta_ng = calc_delta_ng(results_b, df)
    results_b[upgrade + "_delta_ng_therms"] = delta_ng
    delta_fo = calc_delta_fo(results_b, df)
    results_b[upgrade + "_delta_fo_mmbtu"] = delta_fo
    delta_lp = calc_delta_lp(results_b, df)
    results_b[upgrade + "_delta_lp_mmbtu"] = delta_lp
    delta_energy = calc_delta_elec(results_b, df)
    results_b[upgrade + "_delta_allfuels_mmbtu"] = delta_energy
    #calculate year1 savings for each fuel, and total
    year1_savings_elec = calc_year1_bill_savings(results_b['Elec Variable Cost [$/kWh]'], delta_elec)
    results_b[upgrade + "_annualbillsavings_elec_$"] = year1_savings_elec
    year1_savings_ng = calc_year1_bill_savings(results_b['NG Variable Cost [$/therm]'], delta_ng)
    results_b[upgrade + "_annualbillsavings_ng_$"] = year1_savings_ng
    year1_savings_fo = calc_year1_fo_bill_savings(results_b['FO Average Cost [$/gal]'], delta_fo)
    results_b[upgrade + "_annualbillsavings_fo_$"] = year1_savings_fo
    year1_savings_lp = calc_year1_fo_bill_savings(results_b['LP Average Price [$/gal]'], delta_lp)
    results_b[upgrade + "_annualbillsavings_lp_$"] = year1_savings_lp
    year1_savings_allfuels = year1_savings_elec + year1_savings_ng + year1_savings_fo + year1_savings_lp
    results_b[upgrade + "_annualbillsavings_allfuels_$"] = year1_savings_allfuels
    #calculate simple payback period considering all fuels
    simple_payback_period = calc_spp(df['simulation_output_report.upgrade_cost_usd'], year1_savings_allfuels)
    results_b[upgrade + "_spp_allfuels_yrs"] = simple_payback_period
    #calculate npv considering all fuels
    npv = calc_npv(df['simulation_output_report.upgrade_cost_usd'], year1_savings_allfuels)
    results_b[upgrade + "_npv_allfuels_$"] = npv

#save results
results_b.to_csv('results_with_economics_allfuels.csv')


#visualizations