require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

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
    dummy_instance.tanker_config.indexes.any? {|field, block| field == :field }.should == true
  end

  it 'should allow blocks for indexable field data' do
    Tanker.configuration = {:url => 'http://api.indextank.com'}
    Dummy.send(:include, Tanker)
    Dummy.send(:tankit, 'dummy index') do
      indexes :class_name do
        dummy.class.name
      end
    end

    dummy_instance = Dummy.new
    dummy_instance.tanker_config.indexes.any? {|field, block| field == :class_name }.should == true
  end

  describe 'tanker instance' do
    it 'should create an api instance' do
      Tanker.api.class.should == IndexTank::ApiClient
    end

    it 'should create a connexion to index tank' do
      Person.tanker_index.class.should == IndexTank::IndexClient
    end

    it 'should be able to perform a seach query directly on the model' do
      Person.tanker_index.should_receive(:search).and_return(
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

    it 'should be able to use multi-value query phrases' do
      Person.tanker_index.should_receive(:search).with(
        "__any:(hey! location_id:(1) location_id:(2)) __type:(Person)",
        {:start => 0, :len => 10}
      ).and_return({'results' => [], 'matches' => 0})

      collection = Person.search_tank('hey!', :conditions => {:location_id => [1,2]})
    end

    it 'should be able to perform a seach query over several models' do
      index = Tanker.api.get_index('animals')
      Dog.should_receive(:tanker_index).and_return(index)
      index.should_receive(:search).and_return(
        {
          "matches" => 2,
          "results" => [{
            "docid" => 'Dog 7',
            "name"  => 'fido'
          },
          {
            "docid" => 'Cat 9',
            "name"  => 'fluffy'
          }],
          "search_time" => 1
        }
      )

      Dog.should_receive(:find).and_return(
        [Dog.new(:name => 'fido', :id => 7)]
      )
      Cat.should_receive(:find).and_return(
        [Cat.new(:name => 'fluffy', :id => 9)]
      )

      collection = Tanker.search([Dog, Cat], 'hey!')
      collection.class.should == WillPaginate::Collection
      collection.total_entries.should == 2
      collection.total_pages.should == 1
      collection.per_page.should == 10
      collection.current_page.should == 1
    end

    it 'should be able to update the index' do
      person = Person.new(:name => 'Name', :last_name => 'Last Name')

      Person.tanker_index.should_receive(:add_document).with(
        Person.new.it_doc_id,
        {
          :__any     => "Last Name . #{$frozen_moment.to_i} . Name",
          :__type    => 'Person',
          :name      => 'Name',
          :last_name => 'Last Name',
          :timestamp => $frozen_moment.to_i
        },
        {
          :variables => {
            0 => 1.0,
            1 => 20.0,
            2 => 300.0
          }
        }
      )

      person.update_tank_indexes
    end

    it 'should be able to batch update the index' do
      person = Person.new(:name => 'Name', :last_name => 'Last Name')

      Person.tanker_index.should_receive(:add_documents).with(
        [ {
            :docid => Person.new.it_doc_id,
            :fields => {
              :__any     => "Last Name . #{$frozen_moment.to_i} . Name",
              :__type    => 'Person',
              :name      => 'Name',
              :last_name => 'Last Name',
              :timestamp => $frozen_moment.to_i
            },
            :variables => {
              0 => 1.0,
              1 => 20.0,
              2 => 300.0
            }
        } ]
      )

      Tanker.batch_update([person])
    end

    it 'should be able to delete the document from the index' do
      person = Person.new

      Person.tanker_index.should_receive(:delete_document)

      person.delete_tank_indexes
    end

  end
end
