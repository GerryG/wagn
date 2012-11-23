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

    Account.as_bot do
      Card.create(:name=>'Account Request+*type+*captcha', :content=>'0')
    end

    login_as 'joe_admin'
  end

  def test_should_redirect_to_account_request_landing_card
    Account.session =Card['joe_admin+*account']
    Rails.logger.info "testing #{@jaymail.inspect}"
    post :create_account, :user=>{:email=>@jaymail}, :card=>{
      :type=>"Account Request",
      :name=>"Word Third",
      :content=>"Let me in!"
    }
    assert_instance_of User, @user = Account.from_email(@jaymail)
    assert_equal (@card = Card[@user.card_id]).type_id, Card::AccountRequestID
    Rails.logger.info "testing user email #{@card.inspect}, #{@user.inspect}"
    #assert_response 302   # should this redirect?  what is the spec?
    #assert_redirected_to @controller.url_for_page(::Setting.find_by_codename('account_request_landing').card.name)
  end

  def test_should_create_account_request
    post :create_account, :user=>{:email=>@jaymail}, :card=>{
      :type=>"Account Request",
      :name=>"Word Third",
      :content=>"Let me in!"
    }
    Rails.logger.warn "testing created account #{Card['word third'].inspect}"

    assert (@card = Card["Word Third"]), "should be created"
    assert (@acard =  @card.fetch_trait(:account)), "with +*account card"
    @user = Account.from_email(@jaymail)
    assert @user, "User is created"

    assert_equal @card.typecode, :account_request

    # this now happens only when created via account controller

    assert_instance_of User, @user
    #assert @user.default_status?, "#{@user} has default status" # is this correct?  if so FIXME
    assert_equal 'jamaster@jay.net', @acard.user.email, "#{@acard} card has email method"
    assert_equal 'jamaster@jay.net', @card.user.email, "#{@card} card has email method"

  end

  def test_should_destroy_and_block_user
    # FIXME: should test agains mocks here, instead of re-testing the model...
    post :delete, :id=>"~#{Card['Ron Request'].id}", :confirm_destroy=>true
    assert_equal nil, Card['Ron Request']
    assert_equal 'blocked', Account.from_email('ron@request.com').status
  end

end
