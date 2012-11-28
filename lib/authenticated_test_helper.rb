module AuthenticatedTestHelper
  # Sets the current user in the session from the user fixtures.
  def login_as user
    Account.reset
    user_card = Card[user.to_s] and user_card.id
    Account.session = user_card.fetch(:trait=>:account)
    @request.session[:user] = Account.session.id
    #warn "(ath)login_as #{user_card.inspect}, #{Account.session.inspect}, #{Account.as_card}, #{@request.session[:user]}"
  end

  def signout
    Account.reset
    @request.session[:user] = nil
  end


  # Assert the block redirects to the login
  #
  #   assert_requires_login(:bob) { get :edit, :id => 1 }
  #
  def assert_requires_login(user = nil, &block)
    login_as(user) if user
    block.call
    assert_redirected_to :controller => 'account', :action => 'login'
  end

  # Assert the block accepts the login
  #
  #   assert_accepts_login(:bob) { get :edit, :id => 1 }
  #
  # Accepts anonymous logins:
  #
  #   assert_accepts_login { get :list }
  #
  def assert_accepts_login(user = nil, &block)
    login_as(user) if user
    block.call
    assert_response :success
  end

  def assert_auth email, password
    user = Account.authenticated(:email=>email, :password=>password)
    assert user, "#{email} should authenticate"
    #assert User === user, "#{email} should locate a user"
  end

  def assert_new_account(&block)
    assert_difference User, :count, 1, 'Users' do
      assert_difference Card, :count, 2, 'User Cards', &block
    end
  end

  def assert_no_new_account(&block)
    assert_no_difference(User, :count) do
      assert_no_difference Card, :count, &block
    end
  end

  def assert_status(email, status, msg='')
    Rails.logger.warn "assert stat em:#{email}, S:#{status} afe:#{Account.from_email(email).inspect}"
    assert_equal status, Account.from_email(email).status, msg
  end
end
