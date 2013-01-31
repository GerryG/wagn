require File.expand_path('../../spec_helper', File.dirname(__FILE__))

describe Card, "admin functions" do
  before do
    Account.as_bot do
      Card.search(:type => :user).each do |card|
        card.destroy
      end
    end

    it "should setup" do
      Account.as 'joe_user'
        post '/:setup', :account => {:email=>'admin@joe'}
      end
    end
  end

  it "should clear cache" do
  end

  it "should show cache" do
    Account.as 'joe_user'
      get '/A/view=show_cache'
    end
  end
end
