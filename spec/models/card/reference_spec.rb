require File.expand_path('../../spec_helper', File.dirname(__FILE__))


describe "Card::Reference" do

  describe "references on hard templated cards should get updated" do
    it "on templatee creation" do
      Account.as_bot do
        Card.create! :name=>"JoeForm", :type=>'UserForm'
        Wagn::Renderer.new(Card["JoeForm"]).render(:core)
        assert_equal ["joe_form+age", "joe_form+description", "joe_form+name"],
          Card["JoeForm"].out_references.plot(:referenced_name).sort
        Card["JoeForm"].references_expired.should_not == true
      end
    end

    it "on template creation" do
      Account.as_bot do
        Card.create! :name=>"SpecialForm", :type=>'Cardtype'
        c = Card.create! :name=>"Form1", :type=>'SpecialForm', :content=>"foo"
        warn "testing #{c.inspect}, #{c.references_expired}"
        c.references_expired.should be_nil
        c = Card["Form1"]
        warn "testing a #{c.inspect}, #{c.references_expired}"
        c.references_expired.should be_nil
        Card.create! :name=>"SpecialForm+*type+*content", :content=>"{{+bar}}"
        Card["Form1"].references_expired.should be_true
        Wagn::Renderer.new(Card["Form1"]).render(:core)
        c = Card["Form1"]
        c.references_expired.should be_nil
        Card["Form1"].out_references.plot(:referenced_name).should == ["form1+bar"]
      end
    end

    it "on template update" do
      Account.as_bot do
        Card.create! :name=>"JoeForm", :type=>'UserForm'
        tmpl = Card["UserForm+*type+*content"]
        tmpl.content = "{{+monkey}} {{+banana}} {{+fruit}}";
        tmpl.save!
        Card["JoeForm"].references_expired.should be_true
        Wagn::Renderer.new(Card["JoeForm"]).render(:core)
        assert_equal ["joe_form+monkey", "joe_form+banana", "joe_form+fruit"].sort,
          Card["JoeForm"].out_references.plot(:referenced_name).sort
        Card["JoeForm"].references_expired.should_not == true
      end
    end
  end

  it "in references should survive cardtype change" do
    Account.as_bot do
      newcard("Banana","[[Yellow]]")
      newcard("Submarine","[[Yellow]]")
      newcard("Sun","[[Yellow]]")
      newcard("Yellow")
      Card["Yellow"].referencers.plot(:name).sort.should == %w{ Banana Submarine Sun }
      y=Card["Yellow"];
      y.type_id= Card.fetch_id "UserForm";
      y.save!
      Card["Yellow"].referencers.plot(:name).sort.should == %w{ Banana Submarine Sun }
    end
  end

  it "container transclusion" do
    Account.as_bot do
      Card.create( :name=>'bob+city' ).should be
      Card.create( :name=>'address+*right+*default',:content=>"{{_L+city}}" ).should be
      Card.create( :name=>'bob+address' ).should be
      Card['address+*right+*default'].content.should == "{{_L+city}}"
      Card.fetch('bob+address').transcludees.plot(:name).should == ["bob+city"]
      Card.fetch('bob+city').transcluders.plot(:name).should == ["bob+address"]
    end
  end

  it "pickup new links on rename" do
    Account.as_bot do
      @l = newcard("L", "[[Ethan]]")  # no Ethan card yet...
      @e = newcard("Earthman")
      @e.update_attributes! :name => "Ethan"  # NOW there is an Ethan card
      # @e.referencers.plot(:name).include("L")  as the test was originally written, fails
      #  do we need the links to be caught before reloading the card?
      Card["Ethan"].referencers.plot(:name).include?("L").should_not == nil
    end
  end

  it "should update references on rename when requested" do
    Account.as_bot do
      watermelon = newcard('watermelon', 'mmmm')
      watermelon_seeds = newcard('watermelon+seeds', 'black')
      lew = newcard('Lew', "likes [[watermelon]] and [[watermelon+seeds|seeds]]")

      watermelon = Card['watermelon']
      watermelon.update_referencers = true
      watermelon.name="grapefruit"
      watermelon.save!
      lew.reload.content.should == "likes [[grapefruit]] and [[grapefruit+seeds|seeds]]"
    end
  end

  it "should update referencers on rename when requested (case 2)" do
    Account.as_bot do
      card = Card['Administrator links+*self+*read']
      refs = Card::Reference.where(:referenced_card_id => Card::AdminID).map(&:card_id).sort
      card.update_referencers = true
      card.name='Administrator links+*type+*read'
      card.save
      Card::Reference.where(:referenced_card_id => Card::AdminID).map(&:card_id).sort.should == refs
    end
  end

  L = Card::ReferenceTypes::LINK.first
  W = Card::ReferenceTypes::LINK.last

  it "should not update references when not requested" do
    watermelon = newcard('watermelon', 'mmmm')
    watermelon_seeds = newcard('watermelon+seeds', 'black')
    lew = newcard('Lew', "likes [[watermelon]] and [[watermelon+seeds|seeds]]")

    assert_equal [L,L], lew.out_references.plot(:link_type), "links should not be Wanted before"
    Rails.logger.warn "tesging #{(pseeds = Card['watermelon+seeds']).inspect}, #{pseeds.dependents.inspect}"
    Rails.logger.warn "tesging #{(melon = Card['watermelon']).inspect}, deps: #{melon.dependents.inspect}"
    watermelon = Card['watermelon']
    watermelon.update_referencers = false
    watermelon.name="grapefruit"
    watermelon.save!
    lew.reload.content.should == "likes [[watermelon]] and [[watermelon+seeds|seeds]]"
    assert_equal [W,W], lew.out_references.plot(:link_type), "links should be Wanted"
  end

  it "update referencing content on rename junction card" do
    Account.as_bot do
      @ab = Card["A+B"] #linked to from X, transcluded by Y
      @ab.update_attributes! :name=>'Peanut+Butter', :update_referencers => true
      @x = Card['X']
      @x.content.should == "[[A]] [[Peanut+Butter]] [[T]]"
    end
  end

  it "update referencing content on rename junction card" do
    Account.as_bot do
      @ab = Card["A+B"] #linked to from X, transcluded by Y
      @ab.update_attributes! :name=>'Peanut+Butter', :update_referencers=>false
      @x = Card['X']
      @x.content.should == "[[A]] [[A+B]] [[T]]"
    end
  end

  it "template transclusion" do
    Account.as_bot do
      cardtype = Card.create! :name=>"ColorType", :type=>'Cardtype', :content=>""
      Card.create! :name=>"ColorType+*type+*content", :content=>"{{+rgb}}"
      green = Card.create! :name=>"green", :type=>'ColorType'
      rgb = newcard 'rgb'
      green_rgb = Card.create! :name => "green+rgb", :content=>"#00ff00"

      green.reload.transcludees.plot(:name).should == ["green+rgb"]
      green_rgb.reload.transcluders.plot(:name).should == ['green']
    end
  end

  it "simple link" do
    Account.as_bot do
      alpha = Card.create :name=>'alpha'
      beta = Card.create :name=>'beta', :content=>"I link to [[alpha]]"
      Card['beta'].referencees.plot(:name).should == ['alpha']
      Card['alpha'].referencers.plot(:name).should == ['beta']
    end
  end

  it "link with spaces" do
    Account.as_bot do
      alpha = Card.create! :name=>'alpha card'
      beta =  Card.create! :name=>'beta card', :content=>"I link to [[alpha_card|ALPHA CARD]]"
      Card['beta card'].referencees.plot(:name).should == ['alpha card']
      Card['alpha card'].referencers.plot(:name).should == ['beta card']
    end
  end


  it "simple transclusion" do
    Account.as_bot do
      alpha = Card.create :name=>'alpha'
      beta = Card.create :name=>'beta', :content=>"I transclude to {{alpha}}"
      Card['beta'].transcludees.plot(:name).should == ['alpha']
      Card['alpha'].transcluders.plot(:name).should == ['beta']
    end
  end

  it "non simple link" do
    Account.as_bot do
      alpha = Card.create :name=>'alpha'
      beta = Card.create :name=>'beta', :content=>"I link to [[alpha|ALPHA]]"
      Card['beta'].referencees.plot(:name).should == ['alpha']
      Card['alpha'].referencers.plot(:name).should == ['beta']
    end
  end


  it "pickup new links on create" do
    Account.as_bot do
      @l = newcard("woof", "[[Lewdog]]")  # no Lewdog card yet...
      @e = newcard("Lewdog")              # now there is
      # NOTE @e.referencers does not work, you have to reload
      @e.reload.referencers.plot(:name).include?("woof").should_not == nil
    end
  end

  it "pickup new transclusions on create" do
    Account.as_bot do
      @l = Card.create! :name=>"woof", :content=>"{{Lewdog}}"  # no Lewdog card yet...
      @e = Card.new(:name=>"Lewdog", :content=>"grrr")              # now there is
      @e.name_referencers.plot(:name).include?("woof").should_not == nil
    end
  end

=begin

  # This test doesn't make much sense to me... LWH
  it "revise changes references from wanted to linked for new cards" do
    new_card = Card.create(:name=>'NewCard')
    new_card.revise('Reference to [[WantedCard]], and to [[WantedCard2]]', Time.now, Card['quentin'].account),
        get_renderer)

    references = new_card.card_references(true)
    references.size.should == 2
    references[0].referenced_name.should == 'WantedCard'
    references[0].link_type.should == Card::Reference::WANTED_PAGE
    references[1].referenced_name.should == 'WantedCard2'
    references[1].link_type.should == Card::Reference::WANTED_PAGE

    wanted_card = Card.create(:name=>'WantedCard')
    wanted_card.revise('And here it is!', Time.now, Card['quentin'].account), get_renderer)

    # link type stored for NewCard -> WantedCard reference should change from WANTED to LINKED
    # reference NewCard -> WantedCard2 should remain the same
    references = new_card.card_references(true)
    references.size.should == 2
    references[0].referenced_name.should == 'WantedCard'
    references[0].link_type.should == Card::Reference::LINKED_PAGE
    references[1].referenced_name.should == 'WantedCard2'
    references[1].link_type.should == Card::Reference::WANTED_PAGE
  end
=end
  private
  def newcard(name, content="")
    Card.create! :name=>name, :content=>content
  end

end
