require File.expand_path('../../test_helper', File.dirname(__FILE__))
class Card::SearchTest < ActiveSupport::TestCase

  # FIXME: move these cases to specs, exactly what do they have to do with search cards anyway?
  def test_autocard_should_not_respond_to_tform
    assert_nil Card.fetch("u1+*type+*content")
  end

  def test_autocard_should_not_respond_to_not_templated_or_ampersanded_card
    assert_nil Card.fetch("u1+email")
  end

  def test_should_not_show_card_to_joe_user
    Account.as 'joe_user' do
      assert_equal '', render_card(Card["u1"].fetch(:trait => :email, :new => {})), "Anon can't read Account.email"
      assert_equal '', render_card(Card["u1+*account"].fetch(:trait => :email, :new => {} )), "Anon can't read +*account.email"
    end
  end

  def test_should_not_show_card_to_anonymous
    Account.as :anonymous do
      assert_equal '', render_card(Card["u1"].fetch(:trait => :email, :new => {} )), "Anon can't read Account.email"
      assert_equal '', render_card(Card["u1+*account"].fetch(:trait => :email, :new => {} )), "Anon can't read +*account.email"
    end
  end

  def test_should_show_card_to_admin
    Account.as 'u3' do
      assert_equal 'u1@user.com', render_card(Card["u1"].fetch(:trait => :email, :new => {} )), "Admin can read Account.email"
    end
  end

  def test_should_show_card_to_wagbot
    Account.as :wagn_bot do
      assert_equal 'u1@user.com', render_card(Card["u1"].fetch(:trait => :email, :new => {} )), "WagnBot can read Account.email"
    end
  end

  def test_autocard_should_not_break_if_extension_missing
   assert_match render_card(Card["A"].fetch(:trait => :email, :new => {} )), "Sorry, you don't have permission to", "non-existant should be blank"
  end

  def render_card(card) Wagn::Renderer.new(card).render_raw end
end
