require 'spec_helper'

describe Tanker::Utilities do

  before(:each) do

    @included_in = Tanker.instance_variable_get :@included_in
    Tanker.instance_variable_set :@included_in, []

    class Dummy
      include Tanker

      tankit 'dummy index' do
        indexes :name
      end

    end
  end

  after(:each) do
    Tanker.instance_variable_set :@included_in, @included_in
  end

  it "should get the models where Tanker module was included" do
    (Tanker::Utilities.get_model_classes - [Dummy]).should == []
  end

  it "should get the available indexes" do
    Tanker::Utilities.get_available_indexes.should == ["dummy index"]
  end

end
