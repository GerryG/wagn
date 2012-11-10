require File.expand_path('../../test_helper', File.dirname(__FILE__))
class Card::SearchTest < ActiveSupport::TestCase

  def test_autocard_should_not_respond_to_tform
    assert_nil Card.fetch("u1+*type+*content")
  end

  def test_autocard_should_not_respond_to_not_templated_or_ampersanded_card
    assert_nil Card.fetch("u1+email")
  end

  def test_should_not_show_card_to_joe_user
    Session.as 'joe_user' do
      assert_equal '', Card["u1"].email, "Anon can't read Session.email"
      assert_equal '', Card["u1+*account"].email, "Anon can't read +*account.email"
    end
  end

  def test_should_not_show_card_to_anonymous
    Session.as :anonymous do
      assert_equal '', Card["u1"].email, "Anon can't read Session.email"
      assert_equal '', Card["u1+*account"].email, "Anon can't read +*account.email"
    end
  end

  def test_should_show_card_to_admin
    Session.as 'u3' do
      assert_equal 'u1@user.com', Card["u1"].email, "Admin can read Session.email"
      assert_equal 'u1@user.com', Card["u1+*account"].email, "Admin can read +*account.email"
    end
  end

  def test_should_show_card_to_wagbot
    Session.as :wagn_bot do
      assert_equal 'u1@user.com', Card["u1"].email, "WagnBot can read Session.email"
      assert_equal 'u1@user.com', Card["u1+*account"].email, "WagnBot can read +*account.email"
    end
  end

  def test_autocard_should_not_break_if_extension_missing
   assert_match Wagn::Renderer.new(Card.fetch("A+*email")).render_raw, "Sorry, you don't have permission to", "non-existant should be blank"
  end
end
