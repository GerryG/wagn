# -*- encoding : utf-8 -*-
class InvitationError < StandardError; end

class AccountController < ApplicationController
  before_filter :login_required, :only => [ :invite, :update ]
  helper :wagn

  INVITE_ID = Card[Card::InviteID].fetch_trait(:thanks).id
  REQUEST_ID = Card[Card::RequestID].fetch_trait(:thanks).id
  SIGNUP_ID  = Card[Card::SignupID].fetch_trait(:thanks).id

  #ENGLISH many messages throughout this file
  def signup
    #FIXME - don't raise; handle it!
    raise(Wagn::Oops, "You have to sign out before signing up for a new Account") if logged_in?

    card_params = (params[:card]||{}).merge :type_id=>Card::AccountRequestID

    @card = Card.new card_params
    #FIXME - don't raise; handle it!
    raise(Wagn::PermissionDenied, "Sorry, no Signup allowed") unless @card.ok? :create

    @account = Account.new params[:account]
    @account.pending

    if request.post?

      redirect_id=nil
      if @card.trait_ok?(:account, :create) 
          @card.account= @account
          @account.active #.generate_password
          @card.save
          Rails.logger.warn "signup no approv #{@card.inspect}"

          if @card.errors.empty?
            Rails.logger.warn "invite: #{@card.inspect} #{@account.inspect}"
            @card.send_account_info( @account,
                { :message => Card.setting('*signup+*message') || "Thanks for signing up to #{Card.setting('*title')}!",
                  :subject => Card.setting('*signup+*subject') || "Account info for #{Card.setting('*title')}!" } )
          else
            Rails.logger.warn "errors #{@card.errors.map{|k,v| "#{k} -> #{v}"}*", "}"
          end

          redirect_id = SIGNUP_ID 
        else
          Account.as_bot do
            @card.account = @account.pending

            if @card.save
          Rails.logger.warn "signup approv #{@card.inspect}"
              Account.as_bot do
                Mailer.signup_alert(@card).deliver if Card.setting '*request+*to'
              end

              redirect_id = REQUEST_ID
            end
          end
        end

      tgt = target( redirect_id ) and redirect_to tgt
    end
  end

  def accept
    card_key=params[:card][:key]
    #FIXME - don't raise; handle it!
    raise(Wagn::Oops, "I don't understand whom to accept") unless params[:card]
    @card = Card[card_key] or raise(Wagn::NotFound, "Can't find this Account Request")
    Rails.logger.warn "accept #{@card.inspect}"
    @card.account or raise(Wagn::Oops, "This card doesn't have an account to approve")
    @card.ok?(:create) or raise(Wagn::PermissionDenied, "You need permission to create accounts")

    if request.post? and
      @account = @card.account
      @account.active.generate_password
      Rails.logger.warn "accept ok #{@card.inspect} #{@account}"
      @card.type_id = Card::UserID if @card.type_id == Card::AccountRequestID
      if @card.save
        @card.send_account_info @account, params[:email]
        redirect_to target(INVITE_ID);
      end
    else
      render :action=>'invite'
    end
  end

  def invite
    #FIXME - don't raise; handle it!
    cok=Card.new(:name=>'dummy+*account').ok?(:create) or raise(Wagn::PermissionDenied, "You need permission to create")
    if request.post?
      @card = Card.new params[:card]
      acct_params = (params[:account] || {})
      @account = @card.account = ( Account.new( acct_params ) )
      Rails.logger.warn "invite #{@card.inspect}, #{@account.inspect}, #{acct_params.inspect} #{params[:card]}"
      @account.active.generate_password
      #warn "User should be: #{@card.inspect}"
      if @card.save
        @card.send_account_info @account, params[:email]
        redirect_to target( INVITE_ID )
      else
        warn "errs #{@card.errors.map{|k,v| "#{k} -> #{v}"}*"\n"}"
      end
    else
      @account = Account.new; @card = Card.new
    end
  end


  def signin
    if request.post?
      Rails.logger.warn "signin #{params.inspect}"
      if account=Account.authenticated(:email=>params[:login], :password=>params[:password])
        self.session_account = account.account_id
        flash[:notice] = "Successfully signed in"
        redirect_to previous_location
      else
        failed_login "Failed login." #case
      #     when !account         ; "Unrecognized email."
      #     when account.blocked? ; "Sorry, that account is blocked."
      #     else                  ; "Wrong password"
      #   end
      end
    end
  end

  def signout
    self.session_account = nil
    flash[:notice] = "Successfully signed out"
    redirect_to Card.path_setting('/')  # previous_location here can cause infinite loop.  ##  Really?  Shouldn't.  -efm
  end

  def forgot_password
    return unless request.post? and email = params[:email].downcase
    @account = Account.from_email(email)
    if @account.nil?
      flash[:notice] = "Unrecognized email."
      render :action=>'signin', :status=>404
    elsif !@account.active?
      flash[:notice] = "That account is not active."
      render :action=>'signin', :status=>403
    else
      @card=Card[@account.card_id]
      @account.generate_password
      Account.as_bot { @card.save! }

      @card.send_account_info(@account, { :subject=> "Password Reset",
             :message=> "You have been given a new temporary password.  " +
                        "Please update your password once you've signed in. " } )

      flash[:notice] = "Check your email for your new temporary password"
      redirect_to previous_location
    end
  end

  protected

  def target target_id
    r=(
    card = Card[target_id] and Card.path_setting( Card.setting card.name )
    ); Rails.logger.warn "target( #{target_id} } is #{r}"; r
  end

  def failed_login(message)
    flash[:notice] = "Oops: #{message}"
    render :action=>'signin', :status=>403
  end

end
