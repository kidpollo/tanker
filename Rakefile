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
    gem.authors = ["@kidpollo", "Jack Danger Canty"]
    #gem.add_development_dependency "rspec", ">= 2.0.0.beta.22"
    #gem.add_dependency 'will_paginate', '>= 2.3.15'
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'spec'
  test.pattern = 'spec/*_spec.rb'
  test.verbose = true
end
task :spec => :test

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

#task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "tanker #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
