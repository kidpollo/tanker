require 'rubygems'
Bundler.setup :test

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'tanker'
require 'rspec'

Rspec.configure do |c|
  c.mock_with :rspec
end

Tanker.configuration = {:url => 'http://api.indextank.com'}

class Dummy

end

class Person
  include Tanker

  tankit 'people' do
    indexes :name
    indexes :last_name
  end

  def id
    1
  end

  def name
    'paco'
  end

  def last_name
    'viramontes'
  end
end

class Dog
  include Tanker

  tankit 'animals' do
    indexes :name
  end

end

class Cat
  include Tanker

  tankit 'animals' do
    indexes :name
  end

end


