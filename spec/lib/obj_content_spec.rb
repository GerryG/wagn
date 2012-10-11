require File.expand_path('../spec_helper', File.dirname(__FILE__))
require 'object_content'

CONTENT = {
  :one => %(Some Literals: \\[{I'm not| a link]}, and \\{{This Card|Is not Transcluded}}, but {{this is}}),
  :two => %(Some Links and transcludes: [[the card|the text]], and {{This Card|Is Transcluded}}{{this too}}
         more formats for links and transcludes: [the card][the text],
         and [[http://external.wagn.org/path|link text]][This Card][Is linked]{{Transcluded|open}}),
  :three => %(Some Links and transcludes: [[the card|the text]], and {{This Card|Is Transcluded}}{{this too}}
         more formats for links and transcludes: [the card][the text],
         and [[http://external.wagn.org/path|link text]][This Card][Is linked]{{Transcluded|open}})
}

CLASSES = {
   :one => [String, Literal::Escape, String, Literal::Escape, String, Chunk::Transclude ],
   :two => [String, Chunk::Link, String, Chunk::Transclude, Chunk::Transclude, String, Chunk::Link, String, Chunk::Link, Chunk::Link, Chunk::Transclude ],
   :three => [String, LocalURIChunk, String, LocalURIChunk, String, LocalURIChunk, String, LocalURIChunk, String, LocalURIChunk, Chunk::Transclude ]
}

describe ObjectContent do
  before do
    Session.user= :joe_user
    assert card = Card["One"]
    @card_opts = {
      :card => card,
      :renderer => Wagn::Renderer.new(card)
    }
    @check_classes = Proc.new do |m, v|
      if Array===m
        v.should be_instance_of m[0]
        m[0] != v.class ? false : m.size == 1 ? true : m[1..-1]
      else false end
    end
  end


  describe 'parse' do
    it "should find all the chunks and strings" do
      # note the mixed [} that are considered matching, needs some cleanup ...
      cobj = ObjectContent.new CONTENT[:one], @card_opts
      cobj.delegate_class.should == Array
      cobj.inject(CLASSES[:one], &@check_classes).should == true
    end

    it "should give just the chunks" do
      cobj = ObjectContent.new CONTENT[:one], @card_opts
      clist = CLASSES[:one].find_all {|c| String != c }
      cobj.each_chunk do |chk|
        chk.should be_instance_of clist.shift
      end
      clist.should be_empty
    end

    it "should find all the chunks links and trasclusions" do
      cobj = ObjectContent.new CONTENT[:two], @card_opts
      cobj.delegate_class.should == Array
      cobj.inject(CLASSES[:two], &@check_classes).should == true
    end

    it "should find uri chunks " do
      # tried some tougher cases that failed, don't know the spec, so hard to form better tests for URIs here
      cobj = ObjectContent.new %(Some Literals: http://a.url.com
        More urls: http://wagn.com/a/path/to.html
        [ http://gerry.wagn.com/a/path ]
        { https://another.wagn.org/more?args }
        http://myhome.com/path?cgi=foo&bar=baz  {{extra|size:medium;view:open}}), @card_opts
      cobj.delegate_class.should == Array
      cobj.inject(CLASSES[:three], &@check_classes).should == true
      clist = CLASSES[:three].find_all {|c| String != c }
      cobj.each_chunk do |chk|
        chk.should be_instance_of clist.shift
      end
      clist.should be_empty
    end
  end

  describe "render" do
    it "should render objects" do
      pending "no test yet"
    end
  end

end

