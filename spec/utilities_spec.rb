require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

class Dummy
  include Tanker

  tankit 'dummy index' do
    indexes :name
  end

end


describe Tanker::Utilities do

  it "should get the models where Tanker module was included" do
    (Tanker::Utilities.get_model_classes - [Dummy, Person, Dog, Cat]).should == []
  end

  it "should get the available indexes" do
    Tanker::Utilities.get_available_indexes.should == ["people", "animals", "dummy index"]
  end

end
