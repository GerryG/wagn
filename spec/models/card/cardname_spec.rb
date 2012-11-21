require File.expand_path('../../spec_helper', File.dirname(__FILE__))
describe Card, "Case Variant" do
  before do
    Account.as 'joe_user'
    @c = Card.create! :name=>'chump'
  end

  it "should be able to change to a capitalization" do
    @c.name = 'Chump'
    @c.save!
    @c.name.should == 'Chump'
  end
end


describe SmartName, "Underscores" do
  it "should be treated like spaces when making keys" do
    'weird_ combo'.to_name.key.should == 'weird  combo'.to_name.key
  end
  it "should not impede pluralization checks" do
    'Mamas_and_Papas'.to_name.key.should == "Mamas and Papas".to_name.key
  end
end

describe SmartName, "changing from plus card to simple" do
  before do
    Account.as 'joe_user'
    c = Card.create! :name=>'four+five'
    c.name = 'nine'
    c.confirm_rename = true
    c.save
  end

  it "should erase left and right ids (tag/trunk in db)" do
    c = Card['nine']
    c.left_id.should be_nil
    c.right_id.should be_nil
  end

end
