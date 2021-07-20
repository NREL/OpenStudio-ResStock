import os
import sys
import argparse
import numpy as np
import pandas as pd
import csv
import plotly
import plotly.graph_objects as go
from plotly.subplots import make_subplots
sys.path.pop(0)
sys.path.insert(0, os.path.abspath(os.path.join(os.path.abspath(__file__), '../../resources/hpxml-measures/workflow/tests')))

from compare import BaseCompare

enum_maps = {'build_existing_model.geometry_building_type_recs': {'Single-Family Detached': 'SFD',
                                                                  'Single-Family Attached': 'SFA',
                                                                  'Multi-Family with 2 - 4 Units': 'MF',
                                                                  'Multi-Family with 5+ Units': 'MF'} }

class MoreCompare(BaseCompare):
  def __init__(self, base_folder, feature_folder, export_folder, export_file, map_results):
    self.base_folder = base_folder
    self.feature_folder = feature_folder
    self.export_folder = export_folder
    self.export_file = export_file

    if map_results:
      self.map_columns(map_results)


  def samples(self):

    def value_counts(df, file):
      value_counts = []
      with open(file, 'w', newline='') as f:

        for col in sorted(df.columns):
          if col == 'Building':
            continue

          value_count = df[col].value_counts(normalize=True)
          value_count = value_count.round(2)
          keys_to_values = dict(zip(value_count.index.values, value_count.values))
          keys_to_values = dict(sorted(keys_to_values.items(), key=lambda x: (x[1], x[0]), reverse=True))
          value_counts.append([value_count.name])
          value_counts.append(keys_to_values.keys())
          value_counts.append(keys_to_values.values())
          value_counts.append('')

        w = csv.writer(f)
        w.writerows(value_counts)

    df = pd.read_csv(os.path.join(self.base_folder, 'buildstock.csv'))
    file = os.path.join(self.export_folder, 'base_samples.csv')
    value_counts(df, file)

    df = pd.read_csv(os.path.join(self.feature_folder, 'buildstock.csv'))
    file = os.path.join(self.export_folder, 'feature_samples.csv')
    value_counts(df, file)

  def convert_units(self, df):
    for col in df.columns:
      units = col.split('_')[-1]
      if units == 'kwh':
        if col == 'simulation_output_report.electricity_heating_supplemental_kwh':
            df[col] *= 3412.14/1000 # to kbtu
        else:
            df[col] *= 3412.14/1000000  # to mbtu
      elif units == 'therm':
          df[col] *= 0.1  # to mbtu

    return

  def map_columns(self, map_results):
    # Read in files
    ## Characteristics
    base_df_char = pd.read_csv(os.path.join(self.base_folder, 'results_characteristics.csv'), index_col=0)
    feature_df_char = pd.read_csv(os.path.join(self.feature_folder, 'results_characteristics.csv'), index_col=0)

    ## Outputs
    base_df = pd.read_csv(os.path.join(self.base_folder, 'results_output.csv'), index_col=0)
    feature_df = pd.read_csv(os.path.join(self.feature_folder, 'results_output.csv'), index_col=0)

    ## Mapping
    cwd = os.path.dirname(os.path.realpath(__file__))
    map_df = pd.read_csv(os.path.join(cwd, 'column_mapping.csv'), usecols=['restructure_cols','develop_cols'])
    map_df = map_df.dropna(axis=0)
    map_dict = {k:v for k,v in zip(map_df['develop_cols'], map_df['restructure_cols'])}

    # Set new base and feature folders
    self.base_folder = os.path.join(self.base_folder, 'map')
    self.feature_folder = os.path.join(self.feature_folder, 'map')
    if not os.path.exists(self.base_folder):
      os.makedirs(self.base_folder)
    if not os.path.exists(self.feature_folder):
      os.makedirs(self.feature_folder)

    # Align results_charactersitics columns
    base_cols = ['build_existing_model.' + col if  'build_existing_model' not in col else col for col in base_df_char.columns]
    feature_cols = ['build_existing_model.' + col if  'build_existing_model' not in col else col for col in feature_df_char.columns]

    base_df_char.columns = base_cols
    feature_df_char.columns = feature_cols

    common_cols = np.intersect1d(base_df_char.columns, feature_df_char.columns)
    base_df_char = base_df_char[common_cols]
    feature_df_char = feature_df_char[common_cols]

    base_df_char.to_csv(os.path.join(self.base_folder, 'results_characteristics.csv'))
    feature_df_char.to_csv(os.path.join(self.feature_folder, 'results_characteristics.csv'))

    # Map results_output columns
    if map_results == 'base':
      df_to_keep = base_df
      df_to_map = feature_df
    elif map_results == 'feature':
      df_to_keep  = feature_df
      df_to_map = base_df

    # Aggregate variables w/ multiple cols
    for cols, map_to in map_dict.items():
      map_to_s = map_to.split(',')
      if len(map_to_s) > 1: # Sum columns and use first parameter as col name
        map_to = map_to_s[0]
        try:
          df_to_keep[map_to] = df_to_keep[map_to_s].sum(axis=1)
        except:
          for col in map_to_s:
            if col in df_to_keep.columns:
              df_to_keep[map_to] = df_to_keep[col]
        map_dict[cols] = map_to

      cols_s = cols.split(',')
      if len(cols_s)>1:
        cols_s = [col.split('.')[1] for col in cols_s]
        try:
          df_to_map[cols] = df_to_map[cols_s].sum(axis=1)
        except:
          for col in cols_s:
            if col in df_to_map.columns:
              df_to_map[map_to] = df_to_map[col]

    # Convert units
    self.convert_units(df_to_map)
    self.convert_units(df_to_keep)
   
    # Map column headers
    map_dict = {k.split('.')[1] if ',' not in k else k:v for k,v in map_dict.items()}
    df_to_map.rename(columns=map_dict, inplace=True)

    # Filter out aggregated and non-overlapping columns   
    mapped_cols = list(set(map_dict.values()).intersection(list(df_to_map.columns)))
    df_to_map = df_to_map[mapped_cols]
    missing_cols = list(set(df_to_keep.columns) - set(df_to_map.columns))
    df_to_map[missing_cols] = np.nan

    # Re-order columns for comparison
    df_to_keep = df_to_keep.reindex(sorted(df_to_keep.columns), axis=1)
    df_to_map = df_to_map.reindex(sorted(df_to_map.columns), axis=1)

    # Store new mapped csvs
    if map_results == 'base':
      df_to_keep.to_csv(os.path.join(self.base_folder, 'results_output.csv'))
      df_to_map.to_csv(os.path.join(self.feature_folder, 'results_output.csv'))
    elif map_results == 'feature':
      df_to_keep.to_csv(os.path.join(self.feature_folder, 'results_output.csv'))
      df_to_map.to_csv(os.path.join(self.base_folder, 'results_output.csv'))

    return

if __name__ == '__main__':

  default_base_folder = 'test/test_samples_osw/base'
  default_feature_folder = 'test/test_samples_osw/results'
  default_export_folder = 'test/test_samples_osw/comparisons'
  actions = [method for method in dir(MoreCompare) if method.startswith('__') is False]
  aggregate_columns = ['build_existing_model.geometry_building_type_recs',
                       'build_existing_model.county']
  aggregate_functions = ['sum', 'mean']
  display_columns = ['build_existing_model.geometry_building_type_recs',
                     'build_existing_model.county']
  map_result_choices = ['base', 'feature']

  parser = argparse.ArgumentParser()
  parser.add_argument('-b', '--base_folder', default=default_base_folder, help='The path of the base folder.')
  parser.add_argument('-f', '--feature_folder', default=default_feature_folder, help='The path of the feature folder.')
  parser.add_argument('-e', '--export_folder', default=default_export_folder, help='The path of the export folder.')
  parser.add_argument('-x', '--export_file', help='The path of the export file.')
  parser.add_argument('-a', '--actions', action='append', choices=actions, help='The method to call.')
  parser.add_argument('-ac', '--aggregate_column', choices=aggregate_columns, help='On which column to aggregate data.')
  parser.add_argument('-af', '--aggregate_function', choices=aggregate_functions, help='Function to use for aggregating data.')
  parser.add_argument('-dc', '--display_column', choices=display_columns, help='How to organize the subplots.')
  parser.add_argument('-m', '--map_results', choices=map_result_choices, help="Which file's columns to map to")
  args = parser.parse_args()

  if not os.path.exists(args.export_folder):
    os.makedirs(args.export_folder)
    
  compare = MoreCompare(args.base_folder, args.feature_folder, args.export_folder, args.export_file, args.map_results)

  if args.actions == None:
    args.actions = [] 

  for action in args.actions:
    if action == 'samples':
      compare.samples()
    elif action == 'results':
      excludes = ['buildstock.csv']
      compare.results(args.aggregate_column, args.aggregate_function, excludes, enum_maps)
    elif action == 'visualize':
      excludes = ['buildstock.csv', 'results_characteristics.csv']
      compare.visualize(args.aggregate_column, args.aggregate_function, args.display_column, excludes, enum_maps)
