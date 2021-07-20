# frozen_string_literal: true

require_relative '../resources/hpxml-measures/HPXMLtoOpenStudio/resources/minitest_helper'
require_relative 'integrity_checks'

class TestResStockErrors < MiniTest::Test
  def before_setup
    @project_dir_name = File.basename(File.dirname(__FILE__))
    @lookup_file = File.join(File.dirname(__FILE__), '..', 'resources', 'test_options_lookup.tsv')
  end

  def test_housing_characteristics_float_precision
    begin
      housing_characteristics_dir = 'housing_characteristics_float_precision'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert_equal("ERROR: Incorrect float precision found in 'Location', line '2'.", e.message)
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_newline_character
    begin
      housing_characteristics_dir = 'housing_characteristics_newline_character'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert_equal("ERROR: Incorrect newline character found in 'Location', line '1'.", e.message)
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_scientific_notation
    begin
      housing_characteristics_dir = 'housing_characteristics_scientific_notation'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert_equal("ERROR: Scientific notation found in 'Location', line '2'.", e.message)
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_non_float
    begin
      housing_characteristics_dir = 'housing_characteristics_non_float'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert_equal("ERROR: Incorrect non float found in 'Location', line '2'.", e.message)
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_sum_not_one
    begin
      housing_characteristics_dir = 'housing_characteristics_sum_not_one'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert_equal('ERROR: Values in Vintage.tsv incorrectly sum to 1.09.', e.message)
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_duplicate_rows
    begin
      housing_characteristics_dir = 'housing_characteristics_duplicate_rows'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert_equal('ERROR: Multiple rows found in Vintage.tsv with dependencies: Location=AL_Huntsville.Intl.AP-Jones.Field.723230.', e.message)
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_missing_row
    begin
      housing_characteristics_dir = 'housing_characteristics_missing_row'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert_equal('ERROR: Could not determine appropriate option in Vintage.tsv for sample value 1.0 with dependencies: Location=AL_Huntsville.Intl.AP-Jones.Field.723230.', e.message)
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_bad_value
    begin
      housing_characteristics_dir = 'housing_characteristics_bad_value'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert_equal("ERROR: Field 'hello' in Vintage.tsv must be numeric.", e.message)
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_missing_parent
    begin
      housing_characteristics_dir = 'housing_characteristics_missing_parent'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert_equal("ERROR: Unable to process these parameters: Vintage.\nPerhaps one of these dependency files is missing? Location.", e.message)
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_unused_tsv
    begin
      housing_characteristics_dir = 'housing_characteristics_unused_tsv'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert_equal("ERROR: TSV file test/housing_characteristics_unused_tsv/Parameter.tsv not used in options_lookup.tsv.\n", e.message)
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_measure_missing_argument
    begin
      housing_characteristics_dir = 'housing_characteristics_measure_missing_argument'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert(e.message.include? "ERROR: Required argument 'ext_surf_cat' not provided in")
      assert(e.message.include? "test_options_lookup.tsv for measure 'SetSpaceInfiltrationPerExteriorArea'.")
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_measure_extra_argument
    begin
      housing_characteristics_dir = 'housing_characteristics_measure_extra_argument'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert(e.message.include? "ERROR: Extra argument 'extra_arg' specified in")
      assert(e.message.include? "test_options_lookup.tsv for measure 'SetSpaceInfiltrationPerExteriorArea'.")
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_measure_bad_argument_value
    begin
      housing_characteristics_dir = 'housing_characteristics_measure_bad_argument_value'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert_equal("ERROR: Value of 'foo' for argument 'ext_surf_cat' and measure 'SetSpaceInfiltrationPerExteriorArea' must be one of: [\"ExteriorArea\", \"ExteriorWallArea\"].", e.message)
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_measure_missing
    begin
      housing_characteristics_dir = 'housing_characteristics_measure_missing'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert(e.message.include? 'ERROR: Cannot find file')
      assert(e.message.include? 'ResidentialMissingMeasure/measure.rb')
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_housing_characteristics_nonexistent_dependency_option
    begin
      housing_characteristics_dir = 'housing_characteristics_nonexistent_dependency_option'
      integrity_check(@project_dir_name, housing_characteristics_dir, @lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, @lookup_file)
    rescue Exception => e
      assert(e.message.include? "ERROR: Location=AL_Mobile-Rgnl.AP.722230 not a valid dependency option for Vintage.\n")
    else
      flunk "Should have caused an error but didn't."
    end
  end

  def test_options_lookup_multiple_measure_argument_assignments
    begin
      housing_characteristics_dir = 'housing_characteristics_cooling_setpoint'
      lookup_file = File.join(File.dirname(__FILE__), '..', 'resources', 'test_options_lookup.tsv')
      integrity_check(@project_dir_name, housing_characteristics_dir, lookup_file)
      integrity_check_options_lookup_tsv(@project_dir_name, housing_characteristics_dir, lookup_file)
    rescue Exception => e
      assert(e.message.include? 'ERROR: Duplicate measure argument assignment(s) across ["Cooling Setpoint", "Cooling Setpoint Offset Magnitude"] parameters. ResidentialHVACCoolingSetpoints => "weekday_offset_magnitude" already assigned.')
      assert(e.message.include? 'ERROR: Duplicate measure argument assignment(s) across ["Cooling Setpoint", "Cooling Setpoint Offset Magnitude"] parameters. ResidentialHVACCoolingSetpoints => "weekend_offset_magnitude" already assigned.')
    else
      flunk "Should have caused an error but didn't."
    end
  end
end
