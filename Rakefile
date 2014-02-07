require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rspec'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/{tanker,utilities}_spec.rb'
  spec.rspec_opts = ['--backtrace']
end
task :default => :spec

desc 'Run Integration Specs'
RSpec::Core::RakeTask.new(:integration) do |t|
  t.pattern = 'spec/integration_spec.rb' # don't need this, it's default.
end
