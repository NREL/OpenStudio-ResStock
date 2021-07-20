# frozen_string_literal: true

require_relative '../../test/minitest_helper'
require 'minitest/autorun'
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', '..')
load 'Rakefile'
require 'json'

class TestProjectTesting < MiniTest::Test
  def test_housing_characteristics
    begin
      project_dir_name = File.basename(File.dirname(File.dirname(__FILE__)))
      integrity_check(project_dir_name)
      integrity_check_options_lookup_tsv(project_dir_name)
    rescue Exception => e
      flunk e

      # Need a backtrace? Uncomment below
      # flunk "#{e}\n#{e.backtrace.join('\n')}"
    end
  end
end
