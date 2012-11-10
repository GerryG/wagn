module AuthenticatedTestHelper
  # Sets the current user in the session from the user fixtures.
  def login_as user
    Session.reset
    Session.account = @request.session[:user] = (uc=Card[user.to_s] and uc.id)
    Rails.logger.info "(ath)login_as #{uc.inspect}, #{Session.account.inspect}, #{Session.as_card}, #{@request.session[:user]}"
  end

  def signout
    Session.reset
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
    assert user = Session.from_params(:login=>email), "#{email} should locate a user"
    assert user.authenticated?(:password => password), "#{email} should authenticate"
  end

  def assert_new_account(&block)
    assert_difference User, :count, 1, 'Users' do
      assert_difference Card.where(:type_id=>Card::UserID), :count, 1, 'User Cards', &block
    end
  end

  def assert_no_new_account(&block)
    assert_no_difference(User, :count) do
      assert_no_difference Card.where(:type_id=>Card::UserID), :count, &block
    end
  end

  def assert_status(email, status)
    Rails.logger.warn "assert stat #{status} #{Session.from_params(:login=>email).inspect}"
    assert_equal status, Session.from_params(:login=>email).status
  end
end
