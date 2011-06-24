require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'integration_spec_conf'))

require 'active_record'
require 'sqlite3'
require 'logger'

FileUtils.rm( 'data.sqlite3' ) rescue nil
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.establish_connection(
    'adapter' => 'sqlite3',
    'database' => 'data.sqlite3',
    'pool' => 5,
    'timeout' => 5000
)

ActiveRecord::Schema.define do
  create_table :products do |t|
    t.string :name    
    t.string :href
    t.string :tags
  end
end

class Product < ActiveRecord::Base
  include Tanker

  tankit 'tanker_integration_tests' do
    indexes :name
    indexes :href
  end
end

#class Product
#  include Tanker

#  tankit 'tanker_integration_tests' do
#    indexes :name
#    indexes :href
#    indexes :tags
#  end

#  attr_accessor :name, :href, :tags

#  def initialize(options = {})
#    @name = options[:name]
#    @href = options[:href]
#    @tags = options[:tags]
#  end

#  def id
#    @id ||= self.class.throwaway_id
#  end
#  
#  def id=(val)
#    @id = val
#  end
#   
#  class << self
#    def create(options)
#      self.new(options)
#    end
#
#    def throwaway_id
#      @throwaway_id = (@throwaway_id ? @throwaway_id + 1 : 0)
#    end
#
#    def all
#      ObjectSpace.each_object(self)
#    end
#
#    def find(ids)
#      all.select{|instance| ids.include?(instance.id.to_s) }
#    end
#  end
#end

describe 'Tanker integration tests with IndexTank' do

  before(:all) do 
    Tanker::Utilities.clear_index('tanker_integration_tests')
    
    @catapult = Product.create(:name => 'Acme catapult', :href => "google", )
    @tnt      = Product.create(:name => 'Acme TNT', :href => "groupon", )
    @cat      = Product.create(:name => 'Acme cat', :href => "amazon", )
      
    Product.tanker_reindex
  end

  context 'An imaginary store' do
    describe 'basic searching' do
      it 'should find all Acme products' do
        @results = Product.search_tank('Acme')
        (@results - [@catapult, @tnt, @cat]).should be_empty
        @results[0].id.should_not be_nil
      end
  
      it 'should find all catapults' do
        @results = Product.search_tank('catapult')
        (@results - [@catapult]).should be_empty
      end

      it 'should find all things cat' do
        @results = Product.search_tank('cat')
        (@results - [@catapult, @cat]).should be_empty
      end
    end
    
    describe 'advanced searching' do
      it 'should search multiple words from the same field' do
        @results = Product.search_tank('Acme catapult')
        @results.should include(@catapult)
      end
      
      it "should search across multiple fields" do
        @results = Product.search_tank('catapult google')
        @results.should include(@catapult)
      end
    end
    
    describe 'filtering dogs' do

      before(:all) do
        @doggie_1 = Product.create(:name => 'doggie 1', :tags => ['puppuy', 'pug'] )
        @doggie_2 = Product.create(:name => 'doggie 2', :tags => ['pug'] )
        @doggie_3 = Product.create(:name => 'doggie 3', :tags => ['puppuy', 'yoirkie'] )
        Product.tanker_reindex
      end

      after(:all) do
        @doggie_1.delete_tank_indexes 
        @doggie_2.delete_tank_indexes 
        @doggie_3.delete_tank_indexes 
      end

      it 'should filter by puppy tags' do
        @results = Product.search_tank('doggie', :conditions => {:tags => 'puppy'})
        (@results - [@doggie_1, @doggie_3]).should be_empty
      end

      it 'should not search for doggie_3' do
        @results = Product.search_tank('doggie', :conditions => {:tags => 'puppy', '-name' => 'doggie_3'})
        (@results - [@doggie_1]).should be_empty

        @results = Product.search_tank('doggie', :conditions => {:tags => 'puppy', 'NOT name' => 'doggie_3'})
        (@results - [@doggie_1]).should be_empty

        @results = Product.search_tank('doggie NOT doggie_3', :conditions => {:tags => 'puppy'} )
        (@results - [@doggie_1]).should be_empty
      end
    end

    describe 'snippets and fetching data' do 
      before(:all) do
        @prod_1 = Product.create(:name => 'something small')
        @very_long_sting = 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'
        @prod_2 = Product.create(:name => @very_long_sting, :href => 'http://google.com' )
        @prod_3 = Product.create(:name => 'product with tags', :tags => ['oneword', 'two words'])
        Product.tanker_reindex
      end

      after(:all) do
        @prod_1.delete_tank_indexes 
        @prod_2.delete_tank_indexes 
        @prod_3.delete_tank_indexes 
      end
     
      it 'should fetch attribute requested from Index Tank and create an intstance of the Model without calling the database' do
        @results = Product.search_tank('something', :fetch => [:name])
        @results.count.should == 1
        
        @new_prod_instance = @results[0]
        @new_prod_instance.name.should == 'something small'
      end

      it 'should get a snippet for an attribute requested from Index Tank and create an intstance of the Model without calling the database and with a _snippet attribute reader' do
        @results = Product.search_tank('product', :snippets => [:name])
        @results.count.should == 1
       
        @new_prod_instance = @results[0]
        @new_prod_instance.name_snippet.should =~ /<b>product<\/b>/
      end

      it 'should create a new instance of a model and fetch attributes that where requested and get snippets for the attributes required as snippets' do 
        @results = Product.search_tank('quis exercitation', :snippets => [:name], :fetch => [:href])
        @results.count.should == 1
        
        @new_prod_instance = @results[0]
        @new_prod_instance.name_snippet.should =~ /<b>quis<\/b>/
        @new_prod_instance.href.should == 'http://google.com'
      end
    end   
  end
end

