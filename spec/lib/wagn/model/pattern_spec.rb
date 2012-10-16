require File.expand_path('../../../spec_helper', File.dirname(__FILE__))
require File.expand_path('../../../pattern_spec_helper', File.dirname(__FILE__))

describe Wagn::Model::Pattern do
  it "module exists and autoloads" do
    Wagn::Model::Pattern.should be_true
  end


  describe :set_names do
    it "returns self, type, all for simple cards" do
      Session.as_bot do
        card = Card.new( :name => "AnewCard" )
        card.set_names.should == [ "Basic+*type","*all"]
        card.save!
        card = Card.fetch("AnewCard")
        card.set_names.should == [ "AnewCard+*self","Basic+*type","*all"]
      end
    end

    it "returns set names for simple star cards" do
      Session.as_bot do
        Card.fetch('*update').set_names.should == [
          "*update+*self","*star","Setting+*type","*all"
        ]
      end
    end

    it "returns set names for junction cards" do
      Session.as_bot do
        Card.new( :name=>"Iliad+author" ).set_names.should == [
          "Book+author+*type plus right","author+*right","Basic+*type","*all plus","*all"
        ]
      end
    end

    it "returns set names for compound star cards" do
      Session.as_bot do
        Card.new( :name=>"Iliad+*to" ).set_names.should == [
          "Book+*to+*type plus right","*to+*right","*rstar","Phrase+*type","*all plus","*all"
        ]
      end
    end
  end

  describe :junction_only? do
    it "should identify sets that only apply to plus cards" do
      Card.fetch("*all").junction_only?.should be_false
      Card.fetch("*all plus").junction_only?.should be_true
      Card.fetch("Book+*type").junction_only?.should be_false
      Card.fetch("*to+*right").junction_only?.should be_true
      Card.fetch("Book+*to+*type plus right").junction_only?.should be_true
    end
  end

  describe :inheritable? do
    it "should identify sets that can inherit rules" do
      Card.fetch("A+*self").inheritable?.should be_false
      Card.fetch("A+B+*self").inheritable?.should be_true
      Card.fetch("Book+*to+*type plus right").inheritable?.should be_true
      Card.fetch("Book+*type").inheritable?.should be_false
      Card.fetch("*to+*right").inheritable?.should be_true
      Card.fetch("*all plus").inheritable?.should be_true
      Card.fetch("*all").inheritable?.should be_false
    end
  end


  describe :method_keys do
    it "returns correct set names for simple cards" do
      card = Card.new( :name => "AnewCard" )
      card.method_keys.should == [ "basic_type", ""]
      card.save!
      card = Card.fetch("AnewCard")
      card.method_keys.should == [ "basic_type",""]
    end

  end

  describe :css_names do
    it "returns css names for simple star cards" do
      Session.as_bot do
        card = Card.new( :name => "*AnewCard")
        card.css_names.should == "ALL TYPE-basic STAR"
        card.save!
        card = Card.fetch("*AnewCard")
        card.css_names.should == "ALL TYPE-basic STAR SELF-Xanew_card"
      end
    end

    it "returns set names for junction cards" do
      card=Card.new( :name=>"Iliad+author" )
      card.css_names.should == "ALL ALL_PLUS TYPE-basic RIGHT-author TYPE_PLUS_RIGHT-book-author"
      card.save!
      card = Card.fetch("Iliad+author")
      card.css_names.should == "ALL ALL_PLUS TYPE-basic RIGHT-author TYPE_PLUS_RIGHT-book-author SELF-iliad-author"
    end
  end

  describe :label do
    it "returns label for name" do
      Card.new(:name=>'address+*right').label.should== %{All "+address" cards}
    end
  end
end

describe Wagn::Model::RightPattern do
  it_generates :name => "author+*right", :from => Card.new( :name => "Iliad+author" )
  it_generates :name => "author+*right", :from => Card.new( :name => "+author" )
end

describe Wagn::Model::TypePattern do
  it_generates :name => "Book+*type", :from => Card.new( :type => "Book" )
end

describe Wagn::Model::AllPlusPattern do
  it_generates :name => "*all plus", :from => Card.new( :name => "Book+author" )
end


describe Wagn::Model::AllPattern do
  it_generates :name => "*all", :from => Card.new( :type => "Book" )
end

describe Wagn::Model::LeftTypeRightNamePattern do
  it_generates :name => "Book+author+*type plus right", :from => Card.new( :name=>"Iliad+author" )
end
