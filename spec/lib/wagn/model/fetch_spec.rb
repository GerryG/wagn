require File.expand_path('../../../spec_helper', File.dirname(__FILE__))

describe Card do
  describe ".fetch" do
    it "returns and caches existing cards" do
      Card.fetch("A").should be_instance_of(Card)
      Card.cache.read("a").should be_instance_of(Card)
      mock.dont_allow(Card).find_by_key
      Card.fetch("A").should be_instance_of(Card)
    end

    it "returns nil and caches missing cards" do
      Card.fetch("Zork").should be_nil
      Card.cache.read("zork").new_card?.should be_true
      Card.fetch("Zork").should be_nil
    end

    it "returns nil and caches trash cards" do
      Session.as_bot do
        Card.fetch("A").destroy!
        Card.fetch("A").should be_nil
        mock.dont_allow(Card).find_by_key
        Card.fetch("A").should be_nil
      end
    end

    it "returns and caches builtin cards" do
      Card.fetch("*head").should be_instance_of(Card)
      Card.cache.read("*head").should_not be_nil
    end

    it "returns virtual cards and caches them as missing" do
      Session.as_bot do
        card = Card.fetch("Joe User+*email")
        card.should be_instance_of(Card)
        card.name.should == "Joe User+*email"
        Wagn::Renderer.new(card).render_raw.should == 'joe@user.com'
      end
      #card.raw_content.should == 'joe@user.com'
      #cached_card = Card.cache.read("joe_user+*email")
      #cached_card.missing?.should be_true
      #cached_card.virtual?.should be_true
    end

    it "fetches virtual cards after skipping them" do
      Card['A+*self'].should be_nil
      Card.fetch( 'A+*self' ).should_not be_nil
    end

    it "fetches newly virtual cards" do
      pending "needs new cache clearing"
      Card.fetch( 'A+virtual').should be_nil
      Session.as_bot { Card.create :name=>'virtual+*right+*content' }
      Card.fetch( 'A+virtual').should_not be_nil
    end

    it "does not recurse infinitely on template templates" do
      Card.fetch("*content+*right+*content").should be_nil
    end

    it "expires card and dependencies on save" do
      #Card.cache.dump # should be empty
      Card.cache.reset_local
      Card.cache.local.keys.should == []

      Session.as_bot do

        a = Card.fetch("A")
        a.should be_instance_of(Card)

        # expires the saved card
        mock(Card.cache).delete('a')
        mock(Card.cache).delete(/~\d+/).at_least(12)

        # expires plus cards
        mock(Card.cache).delete('c+a')
        mock(Card.cache).delete('d+a')
        mock(Card.cache).delete('f+a')
        mock(Card.cache).delete('a+b')
        mock(Card.cache).delete('a+c')
        mock(Card.cache).delete('a+d')
        mock(Card.cache).delete('a+e')
        mock(Card.cache).delete('a+b+c')

        # expired including? cards
        mock(Card.cache).delete('x').times(2)
        mock(Card.cache).delete('y').times(2)
        a.save!
      end
    end

    describe "preferences" do
      before do
        Session.as(Card::WagnBotID) # FIXME: as without a block is deprecated
      end

      it "prefers db cards to pattern virtual cards" do
        c1=Card.create!(:name => "y+*right+*content", :content => "Formatted Content")
        c2=Card.create!(:name => "a+y", :content => "DB Content")
        card = Card.fetch("a+y")
        card.virtual?.should be_false
        card.rule(:content).should == "Formatted Content"
        card.content.should == "DB Content"
      end

      it "prefers a pattern virtual card to trash cards" do
        Card.create!(:name => "y+*right+*content", :content => "Formatted Content")
        Card.create!(:name => "a+y", :content => "DB Content")
        Card.fetch("a+y").destroy!

        card = Card.fetch("a+y")
        card.virtual?.should be_true
        card.content.should == "Formatted Content"
      end

      it "should recognize pattern overrides" do
        tc=Card.create!(:name => "y+*right+*content", :content => "Right Content")
        card = Card.fetch("a+y")
        card.virtual?.should be_true
        card.content.should == "Right Content"
        tpr = Card.create!(:name => "Basic+y+*type plus right+*content", :content => "Type Plus Right Content")
        card.reset_patterns
        card = Card.fetch("a+y")
        card.reset_patterns
        card.virtual?.should be_true
        card.content.should == "Type Plus Right Content"
        tpr.destroy!
        card.reset_patterns
        card = Card.fetch("a+y")
        card.virtual?.should be_true
        card.content.should == "Right Content"

      end

      it "should not hit the database for every fetch_virtual lookup" do
        Card.create!(:name => "y+*right+*content", :content => "Formatted Content")
        Card.fetch("a+y")
        mock.dont_allow(Card).find_by_key
        Card.fetch("a+y")
      end

      it "should not be a new_record after being saved" do
        Card.create!(:name=>'growing up')
        card = Card.fetch('growing up')
        card.new_record?.should be_false
      end
    end
  end

  describe "#fetch_or_new" do
    it "returns a new card if it doesn't find one" do
      new_card = Card.fetch_or_new("Never Seen Me Before")
      new_card.should be_instance_of(Card)
      new_card.new_record?.should be_true
    end

    it "returns a card if it finds one" do
      new_card = Card.fetch_or_new("A+B")
      new_card.should be_instance_of(Card)
      new_card.new_record?.should be_false
    end

    it "takes a second hash of options as new card options" do
      new_card = Card.fetch_or_new("Never Before", :type => "Image")
      new_card.should be_instance_of(Card)
      new_card.typecode.should == :image
      new_card.new_record?.should be_true
    end
  end

  describe "#fetch_virtual" do
    before { Session.as :joe_user }

    it "should find cards with *right+*content specified" do
      Session.as_bot do
        Card.create! :name=>"testsearch+*right+*content", :content=>'{"plus":"_self"}', :type => 'Search'
      end
      c = Card.fetch("A+testsearch".to_cardname)
      assert c.virtual?
      c.typecode.should == :search_type
      c.content.should ==  "{\"plus\":\"_self\"}"
    end
  end

  describe "#exists?" do
    it "is true for cards that are there" do
      Card.exists?("A").should == true
    end

    it "is false for cards that arent'" do
      Card.exists?("Mumblefunk is gone").should == false
    end
  end
end
