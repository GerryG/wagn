require File.expand_path('../../../spec_helper', File.dirname(__FILE__))
require File.expand_path('../../../permission_spec_helper', File.dirname(__FILE__))
require File.expand_path('../../../packs/pack_spec_helper', File.dirname(__FILE__))

describe "reader rules" do
  before do
    @perm_card =  Card.new(:name=>'Home+*self+*read', :type=>'Pointer', :content=>'[[Anyone Signed In]]')
  end
  
  it "should be *all+*read by default" do
    card = Card.fetch('Home')
    card.read_rule_id.should == Card.fetch('*all+*read').id
    card.who_can(:read).should ==  [Card::AnyoneID]
    Card.as(:anonymous){ card.ok?(:read).should be_true }
  end
  
  it "should update to role ('Anyone Signed In')" do

    Card.as(Card::WagbotID) { @perm_card.save! }
    card = Card.fetch('Home')
    card.read_rule_id.should == @perm_card.id
    card.who_can(:read).should == [Card::AuthID]
    Card.as(:anonymous){ card.ok?(:read).should be_false }
  end
  
  it "should update to user ('Joe Admin')" do
    Card.as(Card::WagbotID) do
      card = Card.fetch('Home')
      @perm_card.content = '[[Joe Admin]]'
      Card.as(Card::WagbotID) { @perm_card.save! }
      card.read_rule_id.should == @perm_card.id
      card.who_can(:read).should == [Card['joe_admin'].id]
      Card.as(:anonymous)      { card.ok?(:read).should be_false }
      Card.as(:joe_user)  { card.ok?(:read).should be_false }
      Card.as(:joe_admin) { card.ok?(:read).should be_true }
      Card.as(Card::WagbotID)    { card.ok?(:read).should be_true }
    end
  end
  
  it "should revert to more general rule when more specific (self) rule is deleted" do
    Card.as(Card::WagbotID) do 
      @perm_card.save!
      @perm_card.destroy!
    end
    card = Card.fetch('Home')
    card.read_rule_id.should == Card.fetch('*all+*read').id
  end

  it "should revert to more general rule when more specific (right) rule is deleted" do
    pc = Card.as(Card::WagbotID) do
      Card.create(:name=>'B+*right+*read', :type=>'Pointer', :content=>'[[Anyone Signed In]]')
    end
    card = Card.fetch('A+B')
    card.read_rule_id.should == pc.id
    pc = Card.fetch(pc.name) #important to re-fetch to catch issues with detecting change in trash status.
    Card.as(Card::WagbotID) { pc.destroy }
    card = Card.fetch('A+B')
    card.read_rule_id.should == Card.fetch('*all+*read').id
  end

  it "should revert to more general rule when more specific rule is renamed" do
    Card.as(Card::WagbotID) do
      @perm_card.save!
      @perm_card.name = 'Something else+*self+*read'
      @perm_card.confirm_rename = true
      @perm_card.save!
    end
    
    card = Card.fetch('Home')
    card.read_rule_id.should == Card.fetch('*all+*read').id
  end

  it "should not be overruled by a more general rule added later" do
    Card.as(Card::WagbotID) do
      @perm_card.save!
      c= Card.fetch('Home')
      c.type_id = Card::PhraseID
      c.save!
      Card.create(:name=>'Phrase+*type+*read', :type=>'Pointer', :content=>'[[Joe User]]')      
    end
    
    card = Card.fetch('Home')
    card.read_rule_id.should == @perm_card.id  
  end
  
  it "should get updated when trunk type change makes type-plus-right apply / unapply" do
    @perm_card.name = "Phrase+B+*type plus right+*read"
    Card.as(Card::WagbotID) { @perm_card.save! }
    Card.fetch('A+B').read_rule_id.should == Card.fetch('*all+*read').id
    c = Card.fetch('A')
    c.type_id = Card::PhraseID
    c.save!
    Card.fetch('A+B').read_rule_id.should == @perm_card.id
  end
  
  it "should work with relative settings" do
    Card.as(Card::WagbotID) { @perm_card.save! }
    all_plus = Card.fetch_or_create('*all plus+*read', :content=>'_left')
    c = Card.new(:name=>'Home+Heart')
    c.who_can(:read).should == [Card::AuthID]
    c.permission_rule_card(:read).first.id.should == @perm_card.id
    c.save
    c.read_rule_id.should == @perm_card.id
  end
  
  it "should get updated when relative settings change" do
    all_plus = Card.fetch_or_create('*all plus+*read', :content=>'_left')
    c = Card.new(:name=>'Home+Heart')
    c.who_can(:read).should == [Card::AnyoneID]
    c.permission_rule_card(:read).first.id.should == Card.fetch('*all+*read').id
    c.save
    c.read_rule_id.should == Card.fetch('*all+*read').id
    Card.as(Card::WagbotID) { @perm_card.save! }
    c2 = Card.fetch('Home+Heart')
    c2.who_can(:read).should == [Card::AuthID]
    c2.read_rule_id.should == @perm_card.id
    Card.fetch('Home+Heart').read_rule_id.should == @perm_card.id
    Card.as(Card::WagbotID){ @perm_card.destroy }
    Card.fetch('Home').read_rule_id.should == Card.fetch('*all+*read').id
    Card.fetch('Home+Heart').read_rule_id.should == Card.fetch('*all+*read').id
  end
  
  it "should insure that class overrides work with relative settings" do
    Card.as(Card::WagbotID) do
      all_plus = Card.fetch_or_create('*all plus+*read', :content=>'_left')
      Card.as(Card::WagbotID) { @perm_card.save! }
      c = Card.create(:name=>'Home+Heart')
      c.read_rule_id.should == @perm_card.id
      r = Card.create(:name=>'Heart+*right+*read', :type=>'Pointer', :content=>'[[Administrator]]')
      Card.fetch('Home+Heart').read_rule_id.should == r.id
    end
  end
  
  it "should work on virtual+virtual cards" do
    c = Card.fetch('Number+*type+by name')
    c.ok?(:read).should be_true
  end
  
end



describe "Permission", ActiveSupport::TestCase do
  before do
    Card.as(Card::WagbotID)
    User.cache.reset
    @u1, @u2, @u3, @r1, @r2, @r3, @c1, @c2, @c3 =
      %w( u1 u2 u3 r1 r2 r3 c1 c2 c3 ).map do |x| Card[x] end
  end      


  it "checking ok read should not add to errors" do
    Card.as(Card::WagbotID) do
      Card.always_ok?.should == true
    end
    Card.as(:joe_user) do
      Card.always_ok?.should == false
    end
    Card.as(:joe_admin) do
      Card.always_ok?.should == true
      Card.create! :name=>"Hidden"
      Card.create(:name=>'Hidden+*self+*read', :type=>'Pointer', :content=>'[[Anyone Signed In]]')
    end
  
    Card.as(:anonymous) do
      h = Card.fetch('Hidden')
      h.ok?(:read).should == false
      h.errors.empty?.should_not == nil
    end
  end   

  it "reader setting" do
    Card.find(:all).each do |c|
      c.permission_rule_card(:read).first.id.should == c.read_rule_id
    end
  end


  it "write user permissions" do
    rc=@u1.trait_card(:roles)
    rc.content = ''; rc << @r1 << @r2
    rc.save
    rc=@u2.trait_card(:roles)
    rc.content = ''; rc << @r1 << @r3
    rc.save
    rc=@u3.trait_card(:roles)
    rc.content = ''; rc << @r1 << @r2 << @r3
    rc.save

    Card.as(Card::WagbotID) {
      cards=[1,2,3].map do |num|
        Card.create(:name=>"c#{num}+*self+*update", :type=>'Pointer', :content=>"[[u#{num}]]")
      end 
      Rails.logger.info "testing point 0 #{cards.inspect}"
    }
 
    @c1 = Card['c1']
    assert_not_locked_from( @u1, @c1 )
    Rails.logger.info "testing point 1 #{@u2.inspect}, #{@c1.inspect}"
    assert_locked_from( @u2, @c1 )    
    assert_locked_from( @u3, @c1 )    
    
    @c2 = Card['c2']
    Rails.logger.info "testing point 2 #{@u1.inspect}, #{@c2.inspect}"
    assert_locked_from( @u1, @c2 )
    assert_not_locked_from( @u2, @c2 )    
    assert_locked_from( @u3, @c2 )    
  end
 
  it "read group permissions" do
    rc=@u1.trait_card(:roles)
    rc.content = ''; rc << @r1 << @r2
    rc.save
    rc=@u2.trait_card(:roles)
    rc.content = ''; rc << @r1 << @r3
    rc.save
    
    Card.as(Card::WagbotID) do
      [1,2,3].each do |num|
        Card.create(:name=>"c#{num}+*self+*read", :type=>'Pointer', :content=>"[[r#{num}]]")
      end
    end
    
    assert_not_hidden_from( @u1, @c1 )
    assert_not_hidden_from( @u1, @c2 )
    assert_hidden_from( @u1, @c3 )    
    
    assert_not_hidden_from( @u2, @c1 )
    assert_hidden_from( @u2, @c2 )    
    assert_not_hidden_from( @u2, @c3 )    
  end

  it "write group permissions" do
    [1,2,3].each do |num|
      Card.create(:name=>"c#{num}+*self+*update", :type=>'Pointer', :content=>"[[r#{num}]]")
    end
    
    (rc=@u3.trait_card(:roles)).content =  ''
    rc << @r1

    %{        u1 u2 u3
      c1(r1)  T  T  T
      c2(r2)  T  T  F
      c3(r3)  T  F  F
    }

    assert_equal true,  @c1.writeable_by(@u1), "c1 writeable by u1"
    assert_equal true,  @c1.writeable_by(@u2), "c1 writeable by u2" 
    assert_equal true,  @c1.writeable_by(@u3), "c1 writeable by u3" 
    assert_equal true,  @c2.writeable_by(@u1), "c2 writeable by u1" 
    assert_equal true,  @c2.writeable_by(@u2), "c2 writeable by u2" 
    assert_equal false, @c2.writeable_by(@u3), "c2 writeable by u3" 
    assert_equal true,  @c3.writeable_by(@u1), "c3 writeable by u1" 
    assert_equal false, @c3.writeable_by(@u2), "c3 writeable by u2" 
    assert_equal false, @c3.writeable_by(@u3), "c3 writeable by u3" 
  end

  it "read user permissions" do
    (rc=@u1.trait_card(:roles)).content = ''
    rc << @r1 << @r2
    (rc=@u2.trait_card(:roles)).content = ''
    rc << @r1 << @r3
    (rc=@u3.trait_card(:roles)).content = ''
    rc << @r1 << @r2 << @r3

    Card.as(Card::WagbotID) {
      [1,2,3].each do |num|
        Card.create(:name=>"c#{num}+*self+*read", :type=>'Pointer', :content=>"[[u#{num}]]")
      end
    }


    # NOTE: retrieving private cards is known not to work now.      
    # assert_not_hidden_from( @u1, @c1 )
    # assert_not_hidden_from( @u2, @c2 )    
    
    assert_hidden_from( @u2, @c1 )    
    assert_hidden_from( @u3, @c1 )    
    assert_hidden_from( @u1, @c2 )
    assert_hidden_from( @u3, @c2 )    
  end
  

  it "private wql" do
    # set up cards of type TestType, 2 with nil reader, 1 with role1 reader 
     Card.as(Card::WagbotID) do 
       [@c1,@c2,@c3].each do |c| 
         c.update_attribute(:content, 'WeirdWord')
       end
       Card.create(:name=>"c1+*self+*read", :type=>'Pointer', :content=>"[[u1]]")
     end
  
     Card.as(@u1) do
       Card.search(:content=>'WeirdWord').plot(:name).sort.should == %w( c1 c2 c3 )
     end
     Card.as(@u2) do
       Card.search(:content=>'WeirdWord').plot(:name).sort.should == %w( c2 c3 )
     end
  end

  it "role wql" do
    #warn "u1 roles #{Card[ @u1.id ].trait_card(:roles).item_names.inspect}"

    # set up cards of type TestType, 2 with nil reader, 1 with role1 reader 
    Card.as(Card::WagbotID) do 
      [@c1,@c2,@c3].each do |c| 
        c.update_attribute(:content, 'WeirdWord')
      end
      Card.create(:name=>"c1+*self+*read", :type=>'Pointer', :content=>"[[r3]]")
    end

    Card.as(@u1) do
      Card.search(:content=>'WeirdWord').plot(:name).sort.should == %w( c1 c2 c3 )
    end
    Card.user=nil # for Card.as to be effective, you can't have a logged in user
    Card.as(@u2) do
      Card.search(:content=>'WeirdWord').plot(:name).sort.should == %w( c2 c3 )
    end
  end  

  def permission_matrix
    # TODO
    # generate this graph three ways:
    # given a card with editor in group X, can Y edit it?
    # given a card with reader in group X, can Y view it?
    # given c card with group anon, can Y change the reader/writer to X    
    
    # X,Y in Anon, auth Member, auth Nonmember, admin       
    
    %{
  A V C J G
A * * * * *
V * * . * .
C * * * . .
J * * . . .
G * . . . .
}   
    
  end

end



    
describe Card, "new permissions" do
  Card.as :joe_user
  
  it "should let joe view new cards" do
    @c = Card.new
    @c.ok?(:read).should be_true
  end

  it "should let joe render content of new cards" do
    @c = Card.new
    assert_view_select Wagn::Renderer.new(@c).render, 'span[class="open-content content"]'
  end

end


describe Card, "default permissions" do
  before do
    Card.as :joe_user do
      @c = Card.create! :name=>"sky blue"
    end
  end
  
  it "should let anonymous users view basic cards" do
    Card.as :anonymous do
      @c.ok?(:read).should be_true
    end
  end
  
  it "should let joe view basic cards" do
    Card.as :joe_user do
      @c.ok?(:read).should be_true
    end
  end
  
end



describe Card, "settings based permissions" do
  before do
    Card.as(Card::WagbotID)
    @delete_rule_card = Card.fetch_or_new '*all+*delete'
    @delete_rule_card.type_id = Card::PointerID
    @delete_rule_card.content = '[[Joe_User]]'
    @delete_rule_card.save!
  end
  
  it "should handle delete as a setting" do
    c = Card.new :name=>'whatever'
    c.who_can(:delete).should == [Card['joe_user'].id]
    Card.as :joe_user
    c.ok?(:delete).should == true
    Card.as :u1
    c.ok?(:delete).should == false
    Card.as :anonymous
    c.ok?(:delete).should == false
    Card.as(Card::WagbotID)
    c.ok?(:delete).should == true #because administrator
  end
end



# FIXME-perm

# need test for
# changing cardtypes gives you correct permissions (changing cardtype in general...)
