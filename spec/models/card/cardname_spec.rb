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


describe Wagn::Cardname, "Underscores" do
  it "should be treated like spaces when making keys" do
    'weird_ combo'.to_cardname.key.should == 'weird  combo'.to_cardname.key
  end
  it "should not impede pluralization checks" do
    'Mamas_and_Papas'.to_cardname.key.should == "Mamas and Papas".to_cardname.key
  end
end

describe Wagn::Cardname, "changing from plus card to simple" do
  before do
    Account.as 'joe_user'
    c = Card.create! :name=>'four+five'
    c.name = 'nine'
    c.confirm_rename = true
    c.save
  end

  it "should erase trunk and tag ids" do
    c = Card['nine']
    c.trunk_id.should== c.id
    c.tag_id.should== c.id
  end

end
