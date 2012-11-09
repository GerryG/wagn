require File.expand_path('../../spec_helper', File.dirname(__FILE__))
require File.expand_path('../../packs/pack_spec_helper', File.dirname(__FILE__))



describe Wagn::Renderer, "" do
  before do
    Session.account= 'joe_user'
    Wagn::Renderer.current_slot = nil
    Wagn::Renderer.ajax_call = false
  end

#~~~~~~~~~~~~ special syntax ~~~~~~~~~~~#

  context "special syntax handling should render" do
    it "simple card links" do
      render_content("[[A]]").should=="<a class=\"known-card\" href=\"/A\">A</a>"
    end

    it "invisible comment inclusions as blank" do
      render_content("{{## now you see nothing}}").should==''
    end

    it "visible comment inclusions as html comments" do
      render_content("{{# now you see me}}").should == '<!-- # now you see me -->'
      render_content("{{# -->}}").should == '<!-- # --&gt; -->'
    end

    it "css in inclusion syntax in wrapper" do
      c = Card.new :name => 'Afloatright', :content => "{{A|float:right}}"
      assert_view_select Wagn::Renderer.new(c)._render( :core ), 'div[style="float:right;"]'
    end

    it "HTML in inclusion syntax as escaped" do
      c =Card.new :name => 'Afloat', :type => 'Html', :content => '{{A|float:<object class="subject">}}'
      result = Wagn::Renderer.new(c)._render( :core )
      assert_view_select result, 'div[style="float:&amp;lt;object class=&amp;quot;subject&amp;quot;&amp;gt;;"]'
    end

    context "CGI variables" do
      it "substituted when present" do
        c = Card.new :name => 'cardcore', :content => "{{_card+B|core}}"
        result = Wagn::Renderer.new(c, :params=>{'_card' => "A"})._render_core
        result.should == "AlphaBeta"
      end
    end
  end

#~~~~~~~~~~~~ Error handling ~~~~~~~~~~~~~~~~~~#

  context "Error handling" do

    it "prevents infinite loops" do
      Card.create! :name => "n+a", :content=>"{{n+a|array}}"
      c = Card.new :name => 'naArray', :content => "{{n+a|array}}"
      Wagn::Renderer.new(c)._render( :core ).should =~ /too deep/
    end

    it "missing relative inclusion is relative" do
      c = Card.new :name => 'bad_include', :content => "{{+bad name missing}}"
      rr=(r=Wagn::Renderer.new(c))._render(:titled)
      rr.match(Regexp.escape(%{Add <strong>+bad name missing</strong>})).should_not be_nil
    end

    it "renders deny for unpermitted cards" do
      Session.as_bot do
        Card.create(:name=>'Joe no see me', :type=>'Html', :content=>'secret')
        Card.create(:name=>'Joe no see me+*self+*read', :type=>'Pointer', :content=>'[[Administrator]]')
      end
      Session.as 'joe_user' do
        assert_view_select Wagn::Renderer.new(Card.fetch('Joe no see me')).render(:core), 'span[class="denied"]'
      end
    end
  end

#~~~~~~~~~~~~~ Standard views ~~~~~~~~~~~~~~~~#
# (*all sets)


  context "handles view" do

    it("name"    ) { render_card(:name).should      == 'Tempo Rary' }
    it("key"     ) { render_card(:key).should       == 'tempo_rary' }
    it("linkname") { render_card(:linkname).should  == 'Tempo_Rary' }

    it "url" do
      Wagn::Conf[:base_url] = 'http://eric.skippy.com'
      render_card(:url).should == 'http://eric.skippy.com/Tempo_Rary'
    end

    it "core" do
      render_card(:core, :name=>'A+B').should == "AlphaBeta"
    end

    it "content" do
      result = render_card(:content, :name=>'A+B')
      assert_view_select result, 'div[class="card-slot content-view ALL ALL_PLUS TYPE-basic RIGHT-b TYPE_PLUS_RIGHT-basic-b SELF-a-b"]' do
        assert_select 'span[class~="content-content content"]'
      end
    end

    describe "inclusions" do
      it "multi edit" do
        c = Card.new :name => 'ABook', :type => 'Book'
        rendered =  Wagn::Renderer.new(c).render( :edit )
        #warn "rendered = #{rendered}"
        assert_view_select rendered, 'div[class="field-in-multi"]' do
          assert_select 'textarea[name=?][class="tinymce-textarea card-content"]', 'card[cards][~plus~illustrator][content]'
        end
      end
    end

    it "titled" do
      result = render_card(:titled, :name=>'A+B')
      assert_view_select result, 'div[class~="titled-view"]' do
        assert_select 'h1' do
          assert_select 'span'
        end
        assert_select 'span[class~="titled-content"]', 'AlphaBeta'
      end
    end

    context "full wrapping" do
      before do
        @ocslot = Wagn::Renderer.new(Card['A'])
      end

      it "should have the appropriate attributes on open" do
        assert_view_select @ocslot.render(:open), 'div[class="card-slot open-view ALL TYPE-basic SELF-a"]' do
          assert_select 'div[class="card-header"]' do
            assert_select 'div[class="title-menu"]'
          end
          assert_select 'span[class~="open-content content"]'
        end
      end

      it "should have the appropriate attributes on closed" do
        v = @ocslot.render(:closed)
        assert_view_select v, 'div[class="card-slot closed-view ALL TYPE-basic SELF-a"]' do
          assert_select 'div[class="card-header"]' do
            assert_select 'div[class="title-menu"]'
          end
          assert_select 'span[class~="closed-content content"]'
        end
      end
    end

    context "Simple page with Default Layout" do
      before do
        Session.as_bot do
          card = Card['A+B']
          @simple_page = Wagn::Renderer::Html.new(card).render(:layout)
          #warn "render sp: #{card.inspect} :: #{@simple_page}"
        end
      end


      it "renders top menu" do
        assert_view_select @simple_page, 'div[id="menu"]' do
          assert_select 'a[class="internal-link"][href="/"]', 'Home'
          assert_select 'a[class="internal-link"][href="/recent"]', 'Recent'
          assert_select 'form.navbox-form[action="/:search"]' do
            assert_select 'input[name="_keyword"]'
          end
        end
      end

      it "renders card header" do
        assert_view_select @simple_page, 'a[href="/A+B"][class="page-icon"][title="Go to: A+B"]'
      end

      it "renders card content" do
        #warn "simple page = #{@simple_page}"
        assert_view_select @simple_page, 'span[class="open-content content"]', 'AlphaBeta'
      end

      it "renders notice info" do
        assert_view_select @simple_page, 'div[class="card-notice"]'
      end

      it "renders card footer" do
        assert_view_select @simple_page, 'div[class="card-footer"]' do
          assert_select 'span[class="watch-link"]' do
            assert_select 'a[title="send emails about changes to A+B"]', "watch"
          end
        end
      end

      it "renders card credit" do
        assert_view_select @simple_page, 'div[id="credit"]', /Wheeled by/ do
          assert_select 'a', 'Wagn'
        end
      end
    end

    context "layout" do
      before do
        Session.as_bot do
          @layout_card = Card.create(:name=>'tmp layout', :type=>'Layout')
          #warn "layout #{@layout_card.inspect}"
        end
        c = Card['*all+*layout'] and c.content = '[[tmp layout]]'
        @main_card = Card.fetch('Joe User')
        #warn "lay #{@layout_card.inspect}, #{@main_card.inspect}"
      end

      it "should default to core view for non-main inclusions when context is layout_0" do
        @layout_card.content = "Hi {{A}}"
        Session.as_bot { @layout_card.save }

        Wagn::Renderer.new(@main_card).render(:layout).should match('Hi Alpha')
      end

      it "should default to open view for main card" do
        @layout_card.content='Open up {{_main}}'
        Session.as_bot { @layout_card.save }

        result = Wagn::Renderer.new(@main_card).render_layout
        result.should match(/Open up/)
        result.should match(/card-header/)
        result.should match(/Joe User/)
      end

      it "should render custom view of main" do
        @layout_card.content='Hey {{_main|name}}'
        Session.as_bot { @layout_card.save }

        result = Wagn::Renderer.new(@main_card).render_layout
        result.should match(/Hey.*div.*Joe User/)
        result.should_not match(/card-header/)
      end

      it "shouldn't recurse" do
        @layout_card.content="Mainly {{_main|core}}"
        Session.as_bot { @layout_card.save }

        Wagn::Renderer.new(@layout_card).render(:layout).should == %{Mainly <div id="main">Mainly {{_main|core}}</div>}
      end

      it "should handle non-card content" do
        @layout_card.content='Hello {{_main}}'
        Session.as_bot { @layout_card.save }

        result = Wagn::Renderer.new(nil).render(:layout, :main_content=>'and Goodbye')
        result.should match(/Hello.*and Goodbye/)
      end

    end

    it "raw content" do
      @a = Card.new(:name=>'t', :content=>"{{A}}")
      Wagn::Renderer.new(@a)._render(:raw).should == "{{A}}"
    end

    it "array (basic card)" do
      render_card(:array, :content=>'yoing').should==%{["yoing"]}
    end
  end

  describe "cgi params" do
    it "renders params in card inclusions" do
      c = Card.new :name => 'cardcore', :content => "{{_card+B|core}}"
      result = Wagn::Renderer.new(c, :params=>{'_card' => "A"})._render_core
      result.should == "AlphaBeta"
    end

    it "should not change name if variable isn't present" do
      c = Card.new :name => 'cardBname', :content => "{{_card+B|name}}"
      Wagn::Renderer.new(c)._render( :core ).should == "_card+B"
    end

    it "array (search card)" do
      Card.create! :name => "n+a", :type=>"Number", :content=>"10"
      Card.create! :name => "n+b", :type=>"Phrase", :content=>"say:\"what\""
      Card.create! :name => "n+c", :type=>"Number", :content=>"30"
      c = Card.new :name => 'nplusarray', :content => "{{n+*plus cards+by create|array}}"
      Wagn::Renderer.new(c)._render( :core ).should == %{["10", "say:\\"what\\"", "30"]}
    end

    it "array (pointer card)" do
      Card.create! :name => "n+a", :type=>"Number", :content=>"10"
      Card.create! :name => "n+b", :type=>"Number", :content=>"20"
      Card.create! :name => "n+c", :type=>"Number", :content=>"30"
      Card.create! :name => "npoint", :type=>"Pointer", :content => "[[n+a]]\n[[n+b]]\n[[n+c]]"
      c = Card.new :name => 'npointArray', :content => "{{npoint|array}}"
      Wagn::Renderer.new(c)._render( :core ).should == %q{["10", "20", "30"]}
    end
  end

#~~~~~~~~~~~~~  content views
# includes some *right stuff


  context "Content rule" do
    it "is rendered as raw" do
      template = Card.new(:name=>'A+*right+*content', :content=>'[[link]] {{inclusion}}')
      Wagn::Renderer.new(template)._render(:core).should == '[[link]] {{inclusion}}'
    end

    it "is used in new card forms when soft" do
      Session.as 'joe_admin' do
        content_card = Card["Cardtype E+*type+*default"]
        content_card.content= "{{+Yoruba}}"
        content_card.save!

        help_card    = Card.create!(:name=>"Cardtype E+*type+*add help", :content=>"Help me dude" )
        card = Card.new(:type=>'Cardtype E')

        assert_view_select Wagn::Renderer::Html.new(card).render_new, 'div[class="content-editor"]' do
          assert_select 'textarea[class="tinymce-textarea card-content"]', :text => '{{+Yoruba}}'
        end
      end
    end

    it "is used in new card forms when hard" do
      Session.as 'joe_admin' do
        content_card = Card.create!(:name=>"Cardtype E+*type+*content",  :content=>"{{+Yoruba}}" )
        help_card    = Card.create!(:name=>"Cardtype E+*type+*add help", :content=>"Help me dude" )
        card = Card.new(:type=>'Cardtype E')

        mock(card).rule_card(:thanks, {:skip_modules=>true}).returns(nil)
        mock(card).rule_card(:autoname).returns(nil)
        mock(card).rule_card(:default,  {:skip_modules=>true}   ).returns(Card['*all+*default'])
        mock(card).rule_card(:add_help, {:fallback=>:edit_help} ).returns(help_card)
        rendered = Wagn::Renderer::Html.new(card).render_new
        #warn "rendered = #{rendered}"
        assert_view_select rendered, 'div[class="field-in-multi"]' do
          assert_select 'textarea[name=?][class="tinymce-textarea card-content"]', "card[cards][~plus~Yoruba][content]"
        end
      end
    end




    it "should be used in edit forms" do
      Session.as_bot do
        config_card = Card.create!(:name=>"templated+*self+*content", :content=>"{{+alpha}}" )
      end
      @card = Card.fetch('templated')# :name=>"templated", :content => "Bar" )
      @card.content = 'Bar'
      result = Wagn::Renderer.new(@card).render(:edit)
      assert_view_select result, 'div[class="field-in-multi"]' do
        assert_select 'textarea[name=?][class="tinymce-textarea card-content"]', 'card[cards][templated~plus~alpha][content]'
      end
    end

    it "work on type-plus-right sets edit calls" do
      Session.as_bot do
        Card.create(:name=>'Book+author+*type plus right+*default', :type=>'Phrase', :content=>'Zamma Flamma')
      end
      c = Card.new :name=>'Yo Buddddy', :type=>'Book'
      result = Wagn::Renderer::Html.new(c).render( :edit )
      assert_view_select result, 'div[class="field-in-multi"]' do
        assert_select 'input[name=?][type="text"][value="Zamma Flamma"]', 'card[cards][~plus~author][content]'
        assert_select %{input[name=?][type="hidden"][value="#{Card::PhraseID}"]},     'card[cards][~plus~author][type_id]'
      end
    end
  end

#~~~~~~~~~~~~~~~ Cardtype Views ~~~~~~~~~~~~~~~~~#
# (type sets)

  context "cards of type" do
    context "Date" do
      it "should have special editor" do
        assert_view_select render_editor('Date'), 'input[class="date-editor"]'
      end
    end

    context "File and Image" do
      #image calls the file partial, so in a way this tests both
      it "should have special editor" do
#        pending "getting html_document error.  paperclip integration issue?"

        assert_view_select render_editor('Image'), 'div[class="choose-file"]' do
          assert_select 'input[class="file-upload slotter"]'
        end
      end
    end

    context "Image" do
      it "should handle size argument in inclusion syntax" do
        image_card = Card.create! :name => "TestImage", :type=>"Image", :content => %{TestImage.jpg\nimage/jpeg\n12345}
        including_card = Card.new :name => 'Image1', :content => "{{TestImage | core; size:small }}"
        rendered = Wagn::Renderer.new(including_card)._render :core
        assert_view_select rendered, 'img[src=?]', "/files/TestImage-small-#{image_card.current_revision_id}.jpg"
      end
    end

    context "HTML" do
      before do
        Session.account= Card::WagnBotID
      end

      it "should have special editor" do
        assert_view_select render_editor('Html'), 'textarea[rows="30"]'
      end

      it "should not render any content in closed view" do
        render_card(:closed_content, :type=>'Html', :content=>"<strong>Lions and Tigers</strong>").should == ''
      end
    end

    context "Account Request" do
      it "should have a special section for approving requests" do
        #pending
        #I can't get this working.  I keep getting this url_for error -- from a line that doesn't call url_for
        card = Card.create!(:name=>'Big Bad Wolf', :type=>'Account Request')
        assert_view_select Wagn::Renderer.new(card).render(:core), 'div[class="invite-links help instruction"]'
      end
    end

    context "Number" do
      it "should have special editor" do
        assert_view_select render_editor('Number'), 'input[type="text"]'
      end
    end

    context "Phrase" do
      it "should have special editor" do
        assert_view_select render_editor('Phrase'), 'input[type="text"][class="phrasebox card-content"]'
      end
    end

    context "Plain Text" do
      it "should have special editor" do
        assert_view_select render_editor('Plain Text'), 'textarea[rows="3"]'
      end

      it "should have special content that escapes HTML" do
        render_card(:core, :type=>'Plain Text', :content=>"<b></b>").should == '&lt;b&gt;&lt;/b&gt;'
      end
    end

    context "Search" do
      it "should wrap search items with correct view class" do
        Card.create :type=>'Search', :name=>'Asearch', :content=>%{{"type":"User"}}
        c=render_content("{{Asearch|core;item:name}}")
        c.should match('search-result-item item-name')
        render_content("{{Asearch|core;item:open}}").should match('search-result-item item-open')
        render_content("{{Asearch|core}}").should match('search-result-item item-closed')
      end

      it "should handle returning 'count'" do
        render_card(:core, :type=>'Search', :content=>%{{ "type":"User", "return":"count"}}).should == '10'
      end
    end

    context "Toggle" do
      it "should have special editor" do
        assert_view_select render_editor('Toggle'), 'input[type="checkbox"]'
      end

      it "should have yes/no as processed content" do
        render_card(:core, :type=>'Toggle', :content=>"0").should == 'no'
        render_card(:closed_content, :type=>'Toggle', :content=>"1").should == 'yes'
      end
    end
  end


  # ~~~~~~~~~~~~~~~~~ Builtins Views ~~~~~~~~~~~~~~~~~~~
  # ( *self sets )


  context "builtin card" do
    context "*now" do
      it "should have a date" do
        render_card(:raw, :name=>'*now').match(/\w+day, \w+ \d+, \d{4}/ ).should_not be_nil
      end
    end

    context "*version" do
      it "should have an X.X.X version" do
        (render_card(:raw, :name=>'*version') =~ (/\d\.\d\.\w+/ )).should be_true
      end
    end

    context "*head" do
      it "should have a javascript tag" do
        assert_view_select render_card(:raw, :name=>'*head'), 'script[type="text/javascript"]'
      end
    end

    context "*navbox" do
      it "should have a form" do
        assert_view_select render_card(:raw, :name=>'*navbox'), 'form.navbox-form'
      end
    end

    context "*account link" do
      it "should have a 'my card' link" do
        Session.as 'joe_user' do
          assert_view_select render_card(:raw, :name=>'*account links'), 'span[id="logging"]' do
            assert_select 'a[id="my-card-link"]', :text => 'Joe User'
          end
        end
      end
    end

    # also need one for *alerts
  end


#~~~~~~~~~ special views

  context "missing" do
    it "should prompt to add" do
      render_content('{{+cardipoo|open}}').match(/Add \<strong\>/ ).should_not be_nil
    end
  end


  context "replace refs" do
    before do
      Session.account= Card::WagnBotID
    end

    it "replace references should work on inclusions inside links" do
      card = Card.create!(:name=>"test", :content=>"[[test{{test}}]]"  )
      assert_equal "[[test{{best}}]]", Wagn::Renderer.new(card).replace_references("test", "best" )
    end
  end

end
