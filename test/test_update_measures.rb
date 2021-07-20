# frozen_string_literal: true

require_relative 'minitest_helper'
require 'minitest/autorun'
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..')
load 'Rakefile'

class TestUpdateMeasures < MiniTest::Test
  def test_update_measures
    begin
      update_measures
    rescue Exception => e
      flunk e

      # Need a backtrace? Uncomment below
      # flunk "#{e}\n#{e.backtrace.join('\n')}"
    end
  end
end
