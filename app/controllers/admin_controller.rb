# -*- encoding : utf-8 -*-

require_dependency 'card'

class AdminController < CardController
  layout 'application'

  def setup
    raise(Wagn::Oops, "Already setup") if Account.first_login?
    Wagn::Conf[:recaptcha_on] = false
    if request.post?
      Account.as_bot do
        @card = Card.new params[:card].merge(:type=>Card::UserID)
        aparams = params[:account]
        aparams[:name] = @card.name
        acct = Account.new( aparams ).active
        @account = card.account = Account.new( aparams ).active
        Rails.logger.warn "acct setup #{acct.inspect}, #{card.inspect}, #{@card.account}"
        set_default_request_recipient

        card.save

        Rails.logger.warn "ext id = #{@account.inspect}"

        if @card.errors.empty?
          roles_card = card.fetch :trait=>:roles, :new=>{}
          roles_card.content = "[[#{Card[Card::AdminID].name}]]"
          roles_card.save
          self.current_account_id = @card.id
          Account.current_id = card.id
          Account.first_login!
          flash[:notice] = "You're good to go!"
          redirect_to Card.path_setting('/')
        else
        Rails.logger.warn "setup error #{@card.errors.map {|e| e.to_s}*', '}"
          flash[:notice] = "Durn, setup went awry..."
        end
      end
    else
      @card = Card.new params[:card] #should prolly skip defaults
      aparams = params[:account] || {}
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
    to_card = Card.fetch '*request+*to', :new=>{}
    to_card.content=params[:account][:email]
    to_card.save
  end

end
