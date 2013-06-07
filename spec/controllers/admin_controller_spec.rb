require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe AdminController, "admin functions" do
  before do
    Account.as_bot do
      Card.search(:type => Card::UserID).each do |card|
        card.destroy
      end
    end
  end

  it "should setup be ready to setup" do
    post :setup, :account => {:email=>'admin@joe'}
  end

  it "should clear cache" do
    Account.as 'joe_user' do
      get :clear_cache
    end
    # FIXME: doesn't test that the cache gets cleared, and it probably shouldn't since joe_user was deleted in the before
  end

  it "should show cache" do
    Account.as 'joe_user' do
      get :show_cache, :id=>"A"
    end
    # FIXME: doesn't test that the cache gets fetched from cache, and it probably shouldn't since joe_user was deleted in the before
  end
end
