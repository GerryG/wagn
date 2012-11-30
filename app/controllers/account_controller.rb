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

    acct_params = params[:account] || {}
    acct_params[:name] = @card.name
    @account = Account.new(acct_params).pending
    #warn "acct? #{params.inspect}, #{acct_params.inspect}, #{@account}"

    #warn "signup #{request.put?} #{params.inspect}, #{@account.inspect}, #{@card.inspect}"
    if request.post?
      @card.account= @account
    #warn "signup post #{params.inspect}, #{@card.account.inspect}, #{@card.inspect}"

      redirect_id = SIGNUP_ID 
      if @card.ok?(:create, :trait=>:account) 
        @account.active
        @card.save

        Rails.logger.warn "errors? #{@card.inspect} .errors.full_messages*", "}" if @card.errors.any?
        if errors!
          return true
        else
          #Rails.logger.warn "invite: #{@card.inspect} #{@account.inspect}"
          @card.send_account_info( { :password=>@account.password, :to => @account.email,
                :message => Card.setting('*signup+*message') || "Thanks for signing up to #{Card.setting('*title')}!",
                :subject => Card.setting('*signup+*subject') || "Account info for #{Card.setting('*title')}!" } )
        end

      else

        @account.pending
        Account.as_bot { @card.save }

        if errors!
          #warn "errors #{@account.errors.full_messages*", "}"
          return true
        else
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
    #FIXME - don't raise; handle it!
    raise(Wagn::Oops, "I don't understand whom to accept") unless params[:card]

    card_key=params[:card][:key]
    @card = Card[card_key] or raise(Wagn::NotFound, "Can't find this Account Request")

    #Rails.logger.warn "accept #{@card.inspect}"
    #FIXME - don't raise; handle it!
    @card.account or raise(Wagn::Oops, "This card doesn't have an account to approve")
    #FIXME - don't raise; handle it!
    @card.ok?(:create) or raise(Wagn::PermissionDenied, "You need permission to create accounts")

    if request.post?
      @account = @card.account
      @account.active.generate_password
      @card.type_id = Card::UserID if @card.type_id == Card::AccountRequestID

      if @card.save
        eparams = params[:email] || {}
        @card.send_account_info eparams.merge( :password => @account.password, :to => @account.email )

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
      acct_params[:name] = @card.name
      @account = @card.account = ( Account.new( acct_params ) )

      @account.active.generate_password
      #warn "User should be: #{@card.inspect}"
      if @card.save
        # and @account.valid? should not need this now @card.save should do it

        eparams = params[:email]
        @card.send_account_info eparams.merge( :password => @account.password, :to => @account.email )

        redirect_to target( INVITE_ID )

      else
        Rails.logger.warn "errs #{@card.errors.map{|k,v| "#{k} -> #{v}"}*"\n"}"
      end
    else

      @account = Account.new; @card = Card.new
    end
  end


  def signin
    if request.post?
      #Rails.logger.warn "signin #{params.inspect}"

      auth_args = { :email=>params[:login], :password=>params[:password] }
      Rails.logger.warn "signin #{auth_args.inspect}"
      unless failed_login acct_card=Account.authenticate( auth_args )

        self.session_account = acct_card.id

        flash[:notice] = "Successfully signed in"

        redirect_to previous_location
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
    @account = Account.find_by_email(email)
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

      @card.send_account_info({ :password => @account.password, :to => @account.email,
             :subject=> "Password Reset",
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
    ); Rails.logger.warn "target( #{target_id} ) #{card.inspect} is #{r}"; r
  end

  def failed_login(account)
    if account.nil?
      message = "Email not recognized." 
    elsif account.errors.any?
      message = "Login failed: #{account.errors.full_messages*', '}"
    else
      return
    end

    flash[:notice] = "Oops: #{message}"
    render :action=>'signin', :status=>403
  end

end
