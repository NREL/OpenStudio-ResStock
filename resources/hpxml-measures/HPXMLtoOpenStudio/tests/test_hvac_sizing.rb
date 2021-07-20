# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'

class HPXMLtoOpenStudioHVACSizingTest < MiniTest::Test
  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def test_slab_f_factor
    def get_unins_slab()
      slab = HPXML::Slab.new(nil)
      slab.thickness = 4.0 # in
      slab.perimeter_insulation_depth = 0
      slab.perimeter_insulation_r_value = 0
      slab.under_slab_insulation_width = 0
      slab.under_slab_insulation_spans_entire_slab = false
      slab.under_slab_insulation_r_value = 0
      return slab
    end

    # Uninsulated slab
    slab = get_unins_slab()
    f_factor = HVACSizing.calc_slab_f_value(slab)
    assert_in_epsilon(1.41, f_factor, 0.01)

    # R-10, 4ft under slab insulation
    slab = get_unins_slab()
    slab.under_slab_insulation_width = 4
    slab.under_slab_insulation_r_value = 10
    f_factor = HVACSizing.calc_slab_f_value(slab)
    assert_in_epsilon(1.27, f_factor, 0.01)

    # R-20, 4ft perimeter insulation
    slab = get_unins_slab()
    slab.perimeter_insulation_depth = 4
    slab.perimeter_insulation_r_value = 20
    f_factor = HVACSizing.calc_slab_f_value(slab)
    assert_in_epsilon(0.39, f_factor, 0.01)

    # R-40, whole slab insulation
    slab = get_unins_slab()
    slab.under_slab_insulation_spans_entire_slab = true
    slab.under_slab_insulation_r_value = 40
    f_factor = HVACSizing.calc_slab_f_value(slab)
    assert_in_epsilon(1.04, f_factor, 0.01)
  end
end
