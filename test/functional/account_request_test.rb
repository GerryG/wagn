require File.expand_path('../test_helper', File.dirname(__FILE__))
require 'card_controller'

# Re-raise errors caught by the controller.
class CardController; def rescue_action(e) raise e end; end
class Wagn::Set::Type::AccountRequestTest < ActionController::TestCase

  include AuthenticatedTestHelper

  def setup
    super
    get_renderer
    @controller = CardController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @jaymail = "jamaster@jay.net"

    Session.as_bot do
      Card.create(:name=>'Account Request+*type+*captcha', :content=>'0')
    end

    login_as 'joe_admin'
  end

  def test_should_redirect_to_account_request_landing_card
    Session.account=Card['joe_admin+*account']
    post :create_account, :user=>{:email=>@jaymail}, :card=>{
      :type=>"Account Request",
      :name=>"Word Third",
      :content=>"Let me in!"
    }
    @user = Session.from_email @jaymail
    @card = Card[@user.id]
    Rails.logger.info "testing user email #{@card.inspect}, #{@user.inspect}"
    assert_response 302
    assert_redirected_to @controller.url_for_page(::Setting.find_by_codename('account_request_landing').card.name)
  end

  def test_should_create_account_request
    post :create_account, :user=>{:email=>@jaymail}, :card=>{
      :type=>"Account Request",
      :name=>"Word Third",
      :content=>"Let me in!"
    }

    assert (@card = Card["Word Third"]), "should be created"
    assert (@acard =  @card.trait_card(:account)), "with +*account card"
    @user = Session.from_email(@jaymail)
    assert @user, "User is created"

    @card.typecode.should == :account_request

    # this now happens only when created via account controller

    assert_instance_of User, @user
    assert @user.default_status?, "#{@user} has default status"
    assert_equal 'jamaster@jay.net', @acard.email(true), "#{@acard} card has email method"
    assert_equal 'jamaster@jay.net', @card.email(true), "#{@card} card has email method"

  end

  def test_should_destroy_and_block_user
    # FIXME: should test agains mocks here, instead of re-testing the model...
    post :delete, :id=>"~#{Card['Ron Request'].id}", :confirm_destroy=>true
    assert_equal nil, Card['Ron Request']
    assert_equal 'blocked', Session.from_email('ron@request.com').status
  end

end
