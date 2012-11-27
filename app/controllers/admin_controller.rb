# -*- encoding : utf-8 -*-
class AdminController < ApplicationController
  layout 'application'

  def setup
    raise(Wagn::Oops, "Already setup") unless Account.no_logins? # && !User[:first]
    Wagn::Conf[:recaptcha_on] = false
    if request.post?
      #Card::User  # wtf - trigger loading of Card::User, otherwise it tries to use U
      Account.as_bot do
        @card.account = Card.new params[:card]
        aparams = params[:account]
        aparams[:name] = @card.name
        @account = @card.account = Account.new( aparams ).active
        set_default_request_recipient

        if @card.save
          roles_card = Card.fetch_or_new(@card.cardname.trait_name(:roles))
          roles_card.content = "[[#{Card[Card::AdminID].name}]]"
          roles_card.save
          self.session_account = @card.id
          Card.cache.delete 'no_logins'
          flash[:notice] = "You're good to go!"
          redirect_to Card.path_setting('/')
        else
          flash[:notice] = "Durn, setup went awry..."
        end
      end
    else
      @card = Card.new params[:card] #should prolly skip defaults
      aparams = aparams[:user] || {}
      aparams[:name] = @card.name
      @account = Account.new aparams
    end
  end

  def show_cache
    key = params[:id].to_name.key
    @cache_card = Card.fetch key
    @db_card = Card.find_by_key key
  end

  def clear_cache
    response =
      if Account.always_ok?
        Wagn::Cache.reset_global
        'Cache cleared'
      else
        "You don't have permission to clear the cache"
      end
    render :text =>response, :layout=> true
  end

  def tasks
    response = %{
      <h1>Global Permissions - REMOVED</h1>
      <p>&nbsp;</p>
      <p>After moving so much configuration power into cards, the old, weaker global system is no longer needed.</p>
      <p>&nbsp;</p>
      <p>Account permissions are now controlled through +*account cards and role permissions through +*role cards.</p>
    }
    render :text =>response, :layout=> true

  end

  private

  def set_default_request_recipient
    to_card = Card.fetch_or_new('*request+*to')
    to_card.content=params[:account][:email]
    to_card.save
  end

end
