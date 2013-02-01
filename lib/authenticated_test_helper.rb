module AuthenticatedTestHelper
  # Sets the current user in the session from the user fixtures.
  def login_as user
    Account.authorized_id = @request.session[:user] = (uc=Card[user.to_s] and uc.id)
    #warn "(ath)login_as #{user.inspect}, #{Account.authorized_id}, #{@request.session[:user]}"
    Account.authorized_id
  end

  def signout
    Account.authorized_id = @request.session[:user] = nil
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
    user = Account.authenticate(:email=>email, :password=>password)
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
    Rails.logger.warn "assert stat em:#{email}, S:#{status} afe:#{Account.find_by_email(email).inspect}"
    assert_equal status, Account.find_by_email(email).status, msg
  end
end
