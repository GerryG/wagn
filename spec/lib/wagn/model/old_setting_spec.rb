require File.expand_path('../../../spec_helper', File.dirname(__FILE__))

describe Card do
  before do
    Account.as(Card::WagnBotID) # FIXME: as without a block is deprecated
  end

  describe "setting data setup" do
    it "should make Set of +*type" do
      Card.create! :name=>"SpeciForm", :type=>'Cardtype'
      Card.create!( :name=>"SpeciForm+*type" ).typecode.should == :set
    end
  end

  describe "#settings" do
    it "retrieves Set based value" do
      Card.create :name => "Book+*type+*add help", :content => "authorize"
      Card.new( :type => "Book" ).rule(:add_help, :fallback=>:edit_help).should == "authorize"
    end

    it "retrieves default values" do
      #Card.create :name => "all Basic cards", :type => "Set", :content => "{\"type\": \"Basic\"}"  #defaults should work when other Sets are present
      assert c=Card.create(:name => "*all+*add help", :content => "lobotomize")
      Card.default_rule(:add_help, :fallback=>:edit_help).should == "lobotomize"
      Card.new( :type => "Basic" ).rule(:add_help, :fallback=>:edit_help).should == "lobotomize"
    end

    it "retrieves single values" do
      Card.create! :name => "banana+*self+*edit help", :content => "pebbles"
      Card["banana"].rule(:edit_help).should == "pebbles"
    end
  end


  context "cascading settings" do
    before do
      Card.create :name => "*all+*edit help", :content => "edit any kind of card"
    end

    it "retrieves default setting" do
      Card.new( :type => "Book" ).rule(:add_help, :fallback=>:edit_help).should == "edit any kind of card"
    end

    it "retrieves primary setting" do
      Card.create :name => "*all+*add help", :content => "add any kind of card"
      Card.new( :type => "Book" ).rule(:add_help, :fallback=>:edit_help).should == "add any kind of card"
    end

    it "retrieves more specific default setting" do
      Card.create :name => "*all+*add help", :content => "add any kind of card"
      Card.create :name => "*Book+*type+*edit help", :content => "edit a Book"
      Card.new( :type => "Book" ).rule(:add_help, :fallback=>:edit_help).should == "add any kind of card"
    end
  end

  describe "#setting_names" do
    before do
      @pointer_settings = ['*options','*options label','*input']
    end
    it "returns universal setting names for non-pointer set" do
      pending "Different api, we should just put the tests in a new spec for that"
      snbg = Card.fetch('*star').setting_names_by_group
      snbg.keys.length.should == 4
      snbg.keys.first.should be_a Symbol
      snbg.keys.member?( :pointer ).should_not be_true
    end

    it "returns pointer-specific setting names for pointer card (*type)" do
      pending "Different api, we should just put the tests in a new spec for that"
      # was this test wrong before?  What made Fruit a pointer without this?
      Account.as_bot do
        c1=Card.create! :name=>'Fruit+*type+*default', :type=>'Pointer'
        Card.create! :name=>'Pointer+*type'
      end
      c2 = Card.fetch('Fruit+*type')
      snbg = c2.setting_names_by_group
      snbg[:pointer].map(&:to_s).should == @pointer_settings
      c3 = Card.fetch('Pointer+*type')
      snbg = c3.setting_names_by_group
      snbg[:pointer].map(&:to_s).should == @pointer_settings
    end

    it "returns pointer-specific setting names for pointer card (*self)" do
      c = Card.fetch_or_new('*account+*related+*self')
      c.save if c.new_card?
      c = Card.fetch_or_new('*account+*related+*self')
      c.set_group.should == :pointer_group
    end

  end

  describe "#item_names" do
    it "returns item for each line of basic content" do
      Card.new( :name=>"foo", :content => "X\nY" ).item_names.should == ["X","Y"]
    end

    it "returns list of card names for search" do
      Card.new( :name=>"foo", :type=>"Search", :content => %[{"name":"Z"}]).item_names.should == ["Z"]
    end

    it "handles searches relative to context card" do
      # note: A refers to 'Z'
      Card.new(:name=>"foo", :type=>"Search", :content => %[{"referred_to_by":"_self"}]).item_names( :context=>'A' ).should == ["Z"]
    end
  end

  describe "#extended_list" do
    it "returns item's content for pointer setting" do
      c = Card.new(:name=>"foo", :type=>"Pointer", :content => "[[Z]]")
      c.extended_list.should == ["I'm here to be referenced to"]
    end
  end

  describe "#contextual_content" do
    it "returns content for basic setting" do
      Card.new(:name=>"foo", :content => "X").contextual_content.should == "X"
    end

    it "processes inclusions relative to context card" do
      context_card = Card["A"] # refers to 'Z'
      c = Card.new(:name=>"foo", :content => "{{_self+B|core}}")
      c.contextual_content( context_card ).should == "AlphaBeta"
    end

    it "returns content even when context card is hard templated" do
      context_card = Card["A"] # refers to 'Z'
      c1=Card.create! :name => "A+*self+*content", :content => "Banana"
      c = Card.new( :name => "foo", :content => "{{_self+B|core}}" )
      c.contextual_content( context_card ).should == "AlphaBeta"
    end
  end
end
