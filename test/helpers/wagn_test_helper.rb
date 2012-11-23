require "#{Rails.root}/lib/util/card_builder.rb"
#require 'renderer'

module WagnTestHelper

  include CardBuilderMethods

  def setup_default_user
    Account.reset

    Account.session = 'joe_user'
    Rails.logger.warn "setup du #{Account.session}, #{Account.authorized}, #{Account.as_card}"
    nil
  end

  def get_renderer()
    Wagn::Renderer.new(Card.new(:name=>'dummy'))
  end

  def given_card( *card_args )
    Account.as_bot do
      Card.create *card_args
    end
  end


  def render_test_card( card )
    r = Wagn::Renderer.new(card)
    r.add_name_context card.name
    r.process_content_s
  end

  def assert_difference(object, method = nil, difference = 1, name=nil)
    initial_value = object.send(method)
    yield
    assert_equal initial_value+difference, object.send(method), "#{name || object}##{method}"
  end

  def assert_no_difference(object, method, &block)
    assert_difference object, method, 0, &block
  end

  USERS = {
    'joe@user.com' => 'joe_pass',
    'joe@admin.com' => 'joe_pass',
    'u3@user.com' => 'u3_pass'
  }

  def integration_login_as(user_login, functional=nil)

    raise "Don't know email & password for #{user_login}, #{Card[user_login].inspect}" unless user_card=Card[user_login] and
        usr=user_card.user and login = usr.email and pass = USERS[login]

    if functional
      Rails.logger.warn "functional login #{login}, #{pass}"
      post :signin, :login=>login, :password=>pass, :controller=>:account
    else
      post 'account/signin', :login=>login, :password=>pass, :controller=>:account
    end
    assert_response :redirect, "integration login broken"

    if block_given?
      yield
      post 'account/signout',:controller=>'account'
    end
  end

  def post_invite(options = {})
    action = options[:action] || :invite
    post action,
      :user => { :email => 'new@user.com' }.merge(options[:user]||{}),
      :card => { :name => "New User" }.merge(options[:card]||{}),
      :email => { :subject => "mailit",  :message => "baby"  }
  end

#  def test_render(url)
#    get url
#    assert_response :success, "#{url} should render successfully"
#  end

#  def test_action(url, args={})
#    post( url, *args )
#    assert_response :success
#  end

  def assert_rjs_redirected_to(url)
    assert @response.body.match(/window\.location\.href = \"([^\"]+)\";/)
    assert_equal $~[1], url
  end
end

module Test
  module Unit
    module Assertions
      def assert_success(bypass_content_parsing = false)
        assert_response :success
        unless bypass_content_parsing
          assert_nothing_raised(@response.content) { REXML::Document.new(@response.content) }
        end
      end
    end
  end
end
