require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "tanker"
    gem.summary = %Q{IndexTank integration to your favorite orm}
    gem.description = %Q{IndexTank is a great search indexing service, this gem tries to make any orm keep in sync with indextank with ease}
    gem.email = "kidpollo@gmail.com"
    gem.homepage = "http://github.com/kidpollo/tanker"
    gem.authors = ["Francisco Viramontes", "Jack Danger Canty"]
    gem.files.exclude 'spec/integration_spec.rb'
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require "rspec/core/rake_task"
# RSpec 2.0
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/{tanker,utilities}_spec.rb'
  spec.rspec_opts = ['--backtrace']
end
task :default => :spec

desc "Generate code coverage"
RSpec::Core::RakeTask.new(:coverage) do |t|
  t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
  t.rcov = true
  t.rcov_opts = ['--exclude', 'spec']
end

desc "Run Integration Specs"
RSpec::Core::RakeTask.new(:integration) do |t|
  t.pattern = "spec/integration_spec.rb" # don't need this, it's default.
  t.rcov = true
  t.rcov_opts = ['--exclude', 'spec']
end

begin
  require 'rake/rdoctask'
rescue
  require 'rdoc/task'
end
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "tanker #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
