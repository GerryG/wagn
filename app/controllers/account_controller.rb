# -*- encoding : utf-8 -*-
class InvitationError < StandardError; end

class AccountController < ApplicationController
  before_filter :login_required, :only => [ :invite, :update ]
  helper :wagn

  INVITE_ID = Card[Card::InviteID].fetch(:trait => :thanks).id
  REQUEST_ID = Card[Card::RequestID].fetch(:trait => :thanks).id
  SIGNUP_ID  = Card[Card::SignupID].fetch(:trait => :thanks).id

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

      if @card.ok?(:create, :trait=>:account) 
        @account.active
        @account.save_card @card

        if !errors
          email_args = { :message => Card.setting('*signup+*message') || "Thanks for signing up to #{Card.setting('*title')}!",
                         :subject => Card.setting('*signup+*subject') || "Account info for #{Card.setting('*title')}!" }
          @account.accept(@card, email_args)

          redirect_id = SIGNUP_ID 
        end
      else
        @account.pending
        @account.save_card @card

        if !errors
          Account.as_bot do
            Mailer.signup_alert(@card).deliver if Card.setting '*request+*to'
          end

          redirect_id = REQUEST_ID
        end
      end

      redirect_to target( redirect_id )

    end
  end

  def accept
    card_key=params[:card][:key]
    #FIXME - don't raise; handle it!
    raise(Wagn::Oops, "I don't understand whom to accept") unless params[:card]
    @card = Card[card_key] or raise(Wagn::NotFound, "Can't find this Account Request")
    @account = @card.account or raise(Wagn::Oops, "This card doesn't have an account to approve")
    #warn "accept #{@account.inspect}"
    @card.ok?(:create) or raise(Wagn::PermissionDenied, "You need permission to create accounts")

    if request.post? and
      @account.accept(@card, params[:email]).errors.empty? #SUCCESS
      tgt = target(INVITE_ID); redirect_to tgt
    else
      render :action=>'invite'
    end
  end

  def invite
    #FIXME - don't raise; handle it!
    cok=Card.new(:name=>'dummy+*account').ok?(:create) or raise(Wagn::PermissionDenied, "You need permission to create")
    if request.post?
      @account = Account.new params[:account]
      @account.active
      @card = @account.save_card params[:card]
      if @account.errors.empty?
        @account.send_account_info(params[:email])
        tgt = target( INVITE_ID ) and redirect_to tgt
      end
    elsif request.put?
      raise "put for invite?"
    else
      @account = Account.new; @card = Card.new
    end
  end


  def signin
    if account=Account.from_params(params) and account.authenticated?(params)
      self.session_account = account.account_id
      flash[:notice] = "Successfully signed in"
      redirect_to previous_location
    else
      failed_login( case
          when account.nil?     ; "Unrecognized email."
          when account.blocked? ; "Sorry, that account is blocked."
          else               ; "Wrong password"
        end )
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
      @account.generate_password
      @account.save!

      @account.send_account_info(:subject=> "Password Reset",
             :message=> "You have been given a new temporary password.  " +
                        "Please update your password once you've signed in. " )

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
