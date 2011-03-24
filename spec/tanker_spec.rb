require 'spec_helper'

describe Tanker do

  it 'sets configuration' do
    conf =  {:url => 'http://api.indextank.com'}
    Tanker.configuration = conf

    Tanker.configuration.should == conf
  end

  it 'checks for configuration when the module is included' do
    Tanker.configuration = nil

    lambda {
      Dummy.send(:include, Tanker)
    }.should raise_error(Tanker::NotConfigured)
  end

  it 'should requiquire a block when seting up tanker model' do
    Tanker.configuration = {:url => 'http://api.indextank.com'}
    Dummy.send(:include, Tanker)
    lambda {
      Dummy.send(:tankit, 'dummy index')
    }.should raise_error(Tanker::NoBlockGiven)
  end

  it 'should set indexable fields' do
    Tanker.configuration = {:url => 'http://api.indextank.com'}
    Dummy.send(:include, Tanker)
    Dummy.send(:tankit, 'dummy index') do
      indexes :field
    end

    dummy_instance = Dummy.new
    dummy_instance.tanker_indexes.include?(:field).should == true
  end

  it 'should allow blocks for indexable field data' do
    Tanker.configuration = {:url => 'http://api.indextank.com'}
    Dummy.send(:include, Tanker)
    Dummy.send(:tankit, 'dummy index') do
      indexes :class_name do |dummy|
        dummy.class.name
      end
    end

    dummy_instance = Dummy.new
    dummy_instance.tanker_indexes.include?(:class_name).should == true
  end

  describe 'tanker instance' do
    it 'should create an api instance' do
      Tanker.api.class.should == IndexTank::ApiClient
    end

    it 'should create a connexion to index tank' do
      Person.index.class.should == IndexTank::IndexClient
    end

    it 'should be able to perform a seach query' do
      Person.index.should_receive(:search).and_return(
        {
          "matches" => 1,
          "results" => [{
            "docid" => Person.new.it_doc_id,
            "name"  => 'pedro'
          }],
          "search_time" => 1
        }
      )

      Person.should_receive(:find).and_return(
      [Person.new]
      )

      collection = Person.search_tank('hey!')
      collection.class.should == WillPaginate::Collection
      collection.total_entries.should == 1
      collection.total_pages.should == 1
      collection.per_page.should == 10
      collection.current_page.should == 1
    end

    it 'should be able to update the index' do
      person = Person.new

      Person.index.should_receive(:add_document)

      person.update_tank_indexes
    end

    it 'should be able to delete de document from the index' do
      person = Person.new

      Person.index.should_receive(:delete_document)

      person.delete_tank_indexes
    end

  end
end
