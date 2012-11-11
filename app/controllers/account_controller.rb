# -*- encoding : utf-8 -*-
class InvitationError < StandardError; end

class AccountController < ApplicationController
  before_filter :login_required, :only => [ :invite, :update ]
  helper :wagn

  #ENGLISH many messages throughout this file
  def signup
    raise(Wagn::Oops, "You have to sign out before signing up for a new Account") if logged_in?
    c=Card.new(:type_id=>Card::AccountRequestID)
    #warn Rails.logger.warn("signup ok? #{c.inspect}, #{c.ok? :create}")
    raise(Wagn::PermissionDenied, "Sorry, no Signup allowed") unless c.ok? :create

    #does not validate password
    user_args = (user_args = params[:user]) && user_args.symbolize_keys || {}
    @user = Account.new user_args
    @user.pending
    card_args = (params[:card]||{}).merge(:type_id=>Card::AccountRequestID)

    unless request.post?
      @card = Card.new( card_args )
      return
    end

    return render_user_errors if @user.errors.any?
    #Rails.logger.warn "signup UA:#{user_args.inspect}, CA:#{card_args.inspect}"
    @card = @user.save_card( card_args )
    #Rails.logger.warn "signup UA:#{@user.inspect}, CA:#{@card.inspect}"
    return render_user_errors if @user.errors.any?

    tr_card = @card.trait_card :account
    #warn "check for account #{@card.name} #{tr_card.inspect}"
    if tr_card.ok?(:create)       #complete the signup now
      email_args = { :message => Card.setting('*signup+*message') || "Thanks for signing up to #{Card.setting('*title')}!",
                     :subject => Card.setting('*signup+*subject') || "Account info for #{Card.setting('*title')}!" }
      @user.accept(@card, email_args)
      return wagn_redirect Card.path_setting(Card.setting('*signup+*thanks'))
    else
      Account.as_bot do
        Mailer.signup_alert(@card).deliver if Card.setting('*request+*to')
      end
      return wagn_redirect Card.path_setting(Card.setting('*request+*thanks'))
    end
  end

  def render_user_errors
    @card.errors += @user.errors
    errors
  end



  def accept
    card_key=params[:card][:key]
    Rails.logger.info "accept #{card_key.inspect}, #{Card[card_key]}, #{params.inspect}"
    raise(Wagn::Oops, "I don't understand whom to accept") unless params[:card]
    @card = Card[card_key] or raise(Wagn::NotFound, "Can't find this Account Request")
    Rails.logger.debug "accept #{Account.account.inspect}, #{@card.inspect}"
    @card=@card.trait_card(:account) and !@card.new_card? and @user = Account.from_id(@card.id) or
      raise(Wagn::Oops, "This card doesn't have an account to approve")
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
    warn "invite: ok? #{Card.new(:name=>'dummy+*account').ok?(:create)}"
    cok=Card.new(:name=>'dummy+*account').ok?(:create) or raise(Wagn::PermissionDenied, "You need permission to create")
    if request.post?
      @user = Account.new params[:user]
      @user.active
      @card = @user.save_card params[:card]
    else
      @user = Account.new; @card = Card.new
    end
    Rails.logger.debug "invite U:#{@user.inspect} C:#{@card.inspect}"
    if request.post? and @user.errors.empty?
      @user.send_account_info(params[:email])
      redirect_to Card.path_setting(Card.setting '*invite+*thanks')
    end
    #warn "invite errors #{@user.errors} C:#{@card.errors}"
    #unless @user.errors.empty?
    #  @user.errors.each do |k,e| warn "user error #{k}, #{e}" end
    #end
  end


  def signin
    Rails.logger.info "signin #{params[:login]}"
    if user=Account.from_params(params) and user.authenticated?(params)
      self.session_user = user.card_id
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

  def render_user_errors
    @user.errors.each do |field, err|
      @card.errors.add field, err unless @card.errors[field]
      # needed to prevent duplicates because User adds them in the other direction in user.rb
    end
    errors
  end

  def failed_login(message)
    flash[:notice] = "Oops: #{message}"
    render :action=>'signin', :status=>403
  end

end
