# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', File.dirname(__FILE__))

class UserTest < ActiveSupport::TestCase
  # Be sure to include AuthenticatedTestHelper in test/test_helper.rb instead.
  # Then, you can remove it from this and the functional test.
  include AuthenticatedTestHelper
  #fixtures :users



  def test_should_reset_password
    Account.lookup(:email=>'joe@user.com').update_attributes(:password => 'new password', :password_confirmation => 'new password')
    assert_auth 'joe@user.com', 'new password'
  end

  def test_should_create_account
    assert_difference User, :count do
      assert create_account.valid?
    end
  end

  def test_should_require_password
    assert_no_difference User, :count do
      u = create_account(:password => '')
      Rails.logger.warn "require pw #{u}, #{u.errors.map{|k,v| "#{k} -> #{v}"}*", "}"
      assert u.errors[:password]
    end
  end

  def test_should_require_password_confirmation
    assert_no_difference User, :count do
      u = create_account(:password_confirmation => nil)
      assert u.errors[:password_confirmation]
    end
  end

  def test_should_require_email
    assert_no_difference User, :count do
      u = create_account(:email => nil)
      assert u.errors[:email]
    end
  end

  def test_should_downcase_email
    u=create_account(:email=>'QuIrE@example.com')
    assert_equal 'quire@example.com', u.email
  end

  def test_should_not_rehash_password
    Account.lookup(:email=>'joe@user.com').update_attributes!(:email => 'joe2@user.com')
    assert_auth 'joe2@user.com', 'joe_pass'
  end

  def test_should_authenticate_account
    assert_auth 'joe@user.com', 'joe_pass'
  end

  def test_should_authenticate_account_with_whitespace
    assert_auth ' joe@user.com ', ' joe_pass '
  end

  def test_should_authenticate_account_with_weird_email_capitalization
    assert_auth 'JOE@user.com', 'joe_pass'
  end

  protected
  def create_account(options = {})
    acct=Account.new({ :login => 'quire', :email => 'quire@example.com',  # login isn't really used now
      :password => 'quire', :password_confirmation => 'quire', :card_id=>0, :account_id=>0
    }.merge(options))
    #Rails.logger.warn "create_account #{acct.inspect}"
    acct.save
    acct
  end
end
