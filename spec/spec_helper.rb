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

$frozen_moment = Time.now

class Person

  attr_accessor :name, :last_name

  def initialize(attrs = {})
    attrs.each {|k,v| self.send "#{k}=", v }
    self.name ||= 'paco'
    self.last_name ||= 'viramontes'
  end

  include Tanker

  tankit 'people' do
    indexes :name
    indexes :last_name
    index_variables do
      {0 => 1.0,
       1 => 20.0,
       2 => 300.0}
    end
  end

  def created_at
    $frozen_moment
  end

  def id
    1
  end
end

class Dog
  attr_accessor :name, :id
  def initialize(attrs = {})
    attrs.each {|k,v| self.send "#{k}=", v }
  end

  include Tanker

  tankit 'animals' do
    indexes :name
  end

end

class Cat
  attr_accessor :name, :id
  def initialize(attrs = {})
    attrs.each {|k,v| self.send "#{k}=", v }
  end

  include Tanker

  tankit 'animals' do
    indexes :name
  end

end


