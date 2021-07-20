# frozen_string_literal: true

# This file is only used to run all tests and collect results on the CI.
# All rake tasks have been moved to tasks.rb.

require 'rake'
require 'rake/testtask'

desc 'Run all tests'
Rake::TestTask.new('test_all') do |t|
  t.test_files = Dir['*/tests/*.rb'] - Dir['workflow/tests/compare.rb']
  t.warning = false
  t.verbose = true
end
