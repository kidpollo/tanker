# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tanker/version'

Gem::Specification.new do |spec|
  spec.name          = "tanker"
  spec.version       = Tanker::VERSION
  spec.authors       = ['Francisco Viramontes', 'Jack Danger Canty']
  spec.email         = ['kidpollo@gmail.com']
  spec.summary       = %q{IndexTank integration to your favorite ORM}
  spec.description   = %q{IndexTank is a great search indexing service, this gem tries to make any ORM keep in sync with indextank with ease}
  spec.homepage      = "http://github.com/kidpollo/tanker"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'json', '>= 1.5.1'

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
end
