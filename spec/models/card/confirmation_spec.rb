require File.expand_path('../../spec_helper', File.dirname(__FILE__))


describe Card, "destroy without dependents" do
  before do Account.as('joe_user'); @c = Card["Basic Card"] end

  it "should succeed" do
    @c.destroy.should be_true
  end
end

describe Card, "destroy with dependents" do
  before do Account.as('joe_user'); @c = Card["A"] end
    
  it "should succeed" do
    #should test for destruction of dependents!
    @c.destroy.should be_true
  end
end

describe Card, "rename without dependents" do
  before do Account.as('joe_user'); @c = Card["Basic Card"] end

  it "should succeed" do
    @c.name = "Brand New Name"
    @c.save.should be_true
  end
end

