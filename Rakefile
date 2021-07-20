# frozen_string_literal: true

# This file is only used to run all tests and collect results on the CI.
# All rake tasks have been moved to tasks.rb.

require 'rake'
require 'rake/testtask'

desc 'Perform tasks related to unit tests'
namespace :unit_tests do
  desc 'Run integrity checks for all projects'
  Rake::TestTask.new('project_integrity_checks') do |t|
    t.libs << 'test'
    t.test_files = Dir['project_*/tests/*.rb']
    t.warning = false
    t.verbose = true
  end

  desc 'Run all integrity check unit tests'
  Rake::TestTask.new('integrity_check_tests') do |t|
    t.libs << 'test'
    t.test_files = Dir['test/test_integrity_checks.rb']
    t.warning = false
    t.verbose = true
  end

  desc 'Run all measure tests'
  Rake::TestTask.new('measure_tests') do |t|
    t.libs << 'test'
    t.test_files = Dir['measures/*/tests/*.rb']
    t.warning = false
    t.verbose = true
  end
end

desc 'Perform tasks related to integration tests'
namespace :integration do
  desc 'Run integration tests for sampled datapoints'
  Rake::TestTask.new('workflow_tests') do |t|
    t.libs << 'test'
    t.test_files = Dir['test/test_samples.rb']
    t.warning = false
    t.verbose = true
  end
end

desc 'Perform tasks related to regression tests'
namespace :regression do
  desc 'Run regression tests for all example osws'
  Rake::TestTask.new('workflow_tests') do |t|
    t.libs << 'test'
    t.test_files = Dir['workflows/tests/*.rb']
    t.warning = false
    t.verbose = true
  end
end
