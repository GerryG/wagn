require File.expand_path('../test_helper', File.dirname(__FILE__))

require 'card_controller'

class CardController 
  def rescue_action(e) raise e end 
end


class CardActionTest < ActionController::IntegrationTest
   
  include LocationHelper
  
  def setup
    super
    setup_default_user
    integration_login_as :joe_user
  end    

  # Has Test
  # ---------                                                                                   
  # card/remove
  # card/create
  # connection/create
  # card/comment 
  # 
  # FIXME: Needs Test
  # -----------
  # card/rollback
  # card/save_draft
  # connection/remove ??

  def test_comment      
    Card.as(Card::WagbotID)  do
      Card.create :name=>'A+*self+*comment', :type=>'Pointer', :content=>'[[Anyone]]'
    end
    post "card/comment/A", :card => { :comment=>"how come" }
    assert_response :success
  end

  def test_create_role_card   
    integration_login_as :joe_admin
    post( 'card/create', :card=>{:content=>"test", :type=>'Role', :name=>"Editor"})
    assert_response 302

    assert Card['Editor'].type_id == Card::RoleID
  end

  def test_create_cardtype_card
    Card.as(Card::WagbotID) {
      post( 'card/create','card'=>{"content"=>"test", :type=>'Cardtype', :name=>"Editor2"} )}
    assert_response 302
    assert Card.find_by_name('Editor2').typecode == 'cardtype'
  end

  def test_create                   
    Card.as(Card::WagbotID) {
     post 'card/create', :card=>{
      :type=>'Basic', 
      :name=>"Editor",
      :content=>"testcontent2"
    }}
    assert_response 302
    assert_equal "testcontent2", Card["Editor"].content
  end

  def test_newcard_shows_edit_instructions
    given_cards( 
      {"Cardtype:YFoo" => ""},
      {"YFoo+*type+*edit help"  => "instruct-me"}
    )
    get 'card/new', :card => {:type=>'YFoo'}
    assert_tag :tag=>'div', :attributes=>{ :class=>"instruction" },  :content=>/instruct-me/ 
  end

  def test_newcard_works_with_fuzzy_renamed_cardtype
    given_cards "Cardtype:ZFoo" => ""
    Card.as(:joe_user) do
      Card["ZFoo"].update_attributes! :name=>"ZFooRenamed", :update_referencers=>true
    end
    
    get 'card/new', :card => { :type=>'z_foo_renamed' }       
    assert_response :success
  end                                        
  
  def test_newcard_gives_reasonable_error_for_invalid_cardtype
    get 'card/new', :card => { :type=>'bananamorph' }       
    assert_response :success
    assert_tag :tag=>'div', :attributes=>{:class=>'error', :id=>'no-cardtype-error'}
  end

  # FIXME: this should probably be files in the spot for a remove test
  def test_removal_and_return_to_previous_undeleted_card_after_deletion
    t1 = t2 = nil
    Card.as(Card::WagbotID) do 
      t1 = Card.create! :name => "Testable1", :content => "hello"
      t2 = Card.create! :name => "Testable1+bandana", :content => "world"
    end

    get url_for_page( t1.name )
    get url_for_page( t2.name )
    
    post 'card/remove/~' + t2.id.to_s
    assert_redirected_to url_for_page( t1.name )   
    assert_nil Card.find_by_name( t2.name )
    
    post 'card/remove/~' + t1.id.to_s
    assert_redirected_to '/'
    assert_nil Card.find_by_name( t1.name )
  end


  def test_should_create_account_from_scratch
    assert_difference ActionMailer::Base.deliveries, :size do 
      post '/card/create_account/', :id=>'a', :user=>{:email=>'foo@bar.com'}
      assert_response 200
    end
    email = ActionMailer::Base.deliveries[-1]
    # emails should be 'from' inviting user
    #assert_equal Card.user.email, email.from[0]  
    #assert_equal 'active', User.find_by_email('new@user.com').status
    #assert_equal 'active', User.find_by_email('new@user.com').status
  end

  def test_update_user_account_blocked_status
    assert !User.where(:card_id=>Card['joe_user'].id).first.blocked?
    post '/card/update_account', :id=>"Joe User".to_cardname.to_key, :account => { :blocked => '1' }
    assert User.where(:card_id=>Card['joe_user'].id).first.blocked?
    post '/card/update_account', :id=>"Joe User".to_cardname.to_key, :account => { :blocked => '0' }
    assert !User.where(:card_id=>Card['joe_user'].id).first.blocked?
  end
end
