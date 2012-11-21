# -*- encoding : utf-8 -*-
class InvitationError < StandardError; end

class AccountController < ApplicationController
  before_filter :login_required, :only => [ :invite, :update ]
  helper :wagn

  REQUEST_NAME = Card[Card::RequestID].cardname.trait(:thanks)
  SIGNUP_NAME = Card[Card::SignupID].cardname.trait(:thanks)

  #ENGLISH many messages throughout this file
  def signup
    #FIXME - don't raise; handle it!
    raise(Wagn::Oops, "You have to sign out before signing up for a new Account") if logged_in?

    card_params = (params[:card]||{}).merge :type_id=>Card::AccountRequestID
    @card = Card.new card_params
    #FIXME - don't raise; handle it!
    raise(Wagn::PermissionDenied, "Sorry, no Signup allowed") unless @card.ok? :create

    @user = Account.new params[:user]
    @user.pending

    if request.post?

      @user.save_card @card
      return if errors

      redirect_name = if @card.trait_ok?(:account, :create)

          email_args = { :message => Card.setting('*signup+*message') || "Thanks for signing up to #{Card.setting('*title')}!",
                         :subject => Card.setting('*signup+*subject') || "Account info for #{Card.setting('*title')}!" }
          @user.accept(@card, email_args)

          SIGNUP_NAME
        else

          Account.as_bot do
            Mailer.signup_alert(@card).deliver if Card.setting '*request+*to'
          end

          REQUEST_NAME
        end
      Rails.logger.warn "redir to #{redirect_name}"
      return wagn_redirect '/'+redirect_name
    end
  end

  def accept
    card_key=params[:card][:key]
    raise(Wagn::Oops, "I don't understand whom to accept") unless params[:card]
    @card = Card[card_key] or raise(Wagn::NotFound, "Can't find this Account Request")
    #warn "accept #{Account.from_id(@card.id).inspect}, #{@card.inspect}"
    @user = @card.user or raise(Wagn::Oops, "This card doesn't have an account to approve")
    #warn "accept #{@user.inspect}"
    @card.ok?(:create) or raise(Wagn::PermissionDenied, "You need permission to create accounts")

    if request.post?
      #warn "accept #{@card.inspect}, #{@user.inspect}"
      @user.accept(@card, params[:email])
      if @user.errors.empty? #SUCCESS
        redirect_to Card.path_setting(Card.setting('*invite+*thanks'))
        return
      end
    end
    render :action=>'invite'
  end

  def invite
    cok=Card.new(:name=>'dummy+*account').ok?(:create) or raise(Wagn::PermissionDenied, "You need permission to create")
    if request.post?
      @user = Account.new params[:user]
      @user.active
      @card = @user.save_card params[:card]
    else
      @user = Account.new; @card = Card.new
    end
    if request.post? and @user.errors.empty?
      @user.send_account_info(params[:email])
      redirect_to Card.path_setting(Card.setting '*invite+*thanks')
    end
  end


  def signin
    if user=Account.from_params(params) and user.authenticated?(params)
      self.session_user = user.account_id
      flash[:notice] = "Successfully signed in"
      redirect_to previous_location
    else
      failed_login( case
          when user.nil?     ; "Unrecognized email."
          when user.blocked? ; "Sorry, that account is blocked."
          else               ; "Wrong password"
        end )
    end
  end

  def signout
    self.session_user = nil
    flash[:notice] = "Successfully signed out"
    redirect_to Card.path_setting('/')  # previous_location here can cause infinite loop.  ##  Really?  Shouldn't.  -efm
  end

  def forgot_password
    return unless request.post? and email = params[:email].downcase
    @user = Account.from_email(email)
    if @user.nil?
      flash[:notice] = "Unrecognized email."
      render :action=>'signin', :status=>404
    elsif !@user.active?
      flash[:notice] = "That account is not active."
      render :action=>'signin', :status=>403
    else
      @user.generate_password
      @user.save!

      @user.send_account_info(:subject=> "Password Reset",
           :message=> "You have been given a new temporary password.  " +
                      "Please update your password once you've signed in. " )

      flash[:notice] = "Check your email for your new temporary password"
      redirect_to previous_location
    end
  end

  protected

  def failed_login(message)
    flash[:notice] = "Oops: #{message}"
    render :action=>'signin', :status=>403
  end

end
