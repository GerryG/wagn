
module Wagn
  module Set::All::Base
    include Sets

    ### --- Core actions -----

    action :create do |*a|
      #card.errors.add(:name, "must be unique; '#{card.name}' already exists.") unless card.new_card?
      card.save
      re=render_errors
      re || success
    end

    action :read do |*a|
      #warn "read action #{@card.inspect}, #{@card.errors.map(&:to_s)*', '}"
      render_errors || begin
    #warn "save and show #{@card.inspect}"
        save_location # should be an event!
        show
      end
    end

    action :update do |*a|
      if card.new_card?; perform_create
      elsif card.update_attributes params[:card]
        #warn "update #{card.inspect}, #{params[:card].inspect}"
        #card.save
        render_errors || success

      elsif render_errors
      else  success
      end
    end

    action :delete do |*a|
      card.destroy
      discard_locations_for card #should be an event
      success 'REDIRECT: *previous'
    end

    alias_action :read,     {}, :index
    alias_action :show_file, {}, :read_file



    # ------- Views ------------

    format :base

    ### ---- Core renders --- Keep these on top for dependencies

    define_view :show, :perms=>:none  do |args|
      render( args[:view] || :core )
    end

    define_view :raw      do |args|  card ? card.raw_content : _render_blank                          end
    define_view :core     do |args|  process_content _render_raw                                    end
    define_view :content  do |args|  _render_core                                                     end
      # this should be done as an alias, but you can't make an alias with an unknown view,
      # and base renderer doesn't know "content" at this point
    define_view :titled   do |args|  card.name + "\n\n" + _render_core                                end

    define_view :name,     :perms=>:none  do |args|  card.name                                        end
    define_view :key,      :perms=>:none  do |args|  card.key                                         end
    define_view :id,       :perms=>:none  do |args|  card.id                                          end
    define_view :linkname, :perms=>:none  do |args|  card.cardname.url_key                         end
    define_view :url,      :perms=>:none  do |args|  wagn_url _render_linkname                        end

    define_view :link, :perms=>:none  do |args|
      name = card.name
      build_link name, name, card.known?
    end

    define_view :open_content do |args|
      pre_render = _render_core(args) { yield args }
      card ? card.post_render(pre_render) : pre_render
    end

    define_view :closed_content do |args|
      truncatewords_with_closing_tags _render_core(args) { yield }
    end

###----------------( SPECIAL )
    define_view :array do |args|
      if card.collection?
        card.item_cards(:limit=>0).map do |item_card|
          subrenderer(item_card)._render_core
        end
      else
        [ _render_core(args) { yield } ]
      end.inspect
    end

    define_view :blank, :perms=>:none do |args| "" end

    define_view :not_found, :perms=>:none, :error_code=>404 do |args|
      %{ Could not find #{card.name.present? ? %{"#{card.name}"} : 'the card requested'}. }
    end

    define_view :server_error, :perms=>:none do |args|
      %{ Wagn Hitch!  Server Error. Yuck, sorry about that.\n}+
      %{ To tell us more and follow the fix, add a support ticket at http://wagn.org/new/Support_Ticket }
    end

    define_view :denial, :perms=>:none, :error_code=>403 do |args|
      focal? ? 'Permission Denied' : ''
    end

    define_view :bad_address, :perms=>:none, :error_code=>404 do |args|
      %{ Bad Address }
    end

    define_view :no_card, :perms=>:none, :error_code=>404 do |args|
      %{ No Card! }
    end

    define_view :too_deep, :perms=>:none do |args|
      %{ Man, you're too deep.  (Too many levels of inclusions at a time) }
    end

    # The below have HTML!?  should not be any html in the base renderer


    define_view :closed_missing, :perms=>:none do |args|
      %{<span class="faint"> #{ showname } </span>}
    end

    define_view :missing, :perms=>:none do |args|
      %{<span class="faint"> #{ showname } </span>}
    end

    define_view :too_slow, :perms=>:none do |args|
      %{<span class="too-slow">Timed out! #{ showname } took too long to load.</span>}
    end
  end

end

=begin
  ## the following methods need to be merged into #update

  def save_draft
    if @card.save_draft params[:card][:content]
      render :nothing=>true
    else
      errors!
    end
  end

  def comment
    raise Wagn::BadAddress, "comment without card" unless params[:card]
    # this previously failed unless request.post?, but it is now (properly) a PUT.
    # if we enforce RESTful http methods, we should do it consistently,
    # and error should be 405 Method Not Allowed

    author = Account.user_id == Card::AnonID ?
        "#{session[:comment_author] = params[:card][:comment_author]} (Not signed in)" : "[[#{Account.user.card.name}]]"
    comment = params[:card][:comment].split(/\n/).map{|c| "<p>#{c.strip.empty? ? '&nbsp;' : c}</p>"} * "\n"
    @card.comment = "<hr>#{comment}<p><em>&nbsp;&nbsp;--#{author}.....#{Time.now}</em></p>"

    if @card.save
      show
    else
      errors!
    end
  end

  def rollback
    revision = @card.revisions[params[:rev].to_i - 1]
    @card.update_attributes! :content=>revision.content
    @card.attachment_link revision.id
    show
  end


  def watch
    watchers = @card.fetch :trait=>:watchers, :new=>{}
    watchers = watchers.refresh
    myname = Card[Account.user_id].name
    watchers.send((params[:toggle]=='on' ? :add_item : :drop_item), myname)
    ajax? ? show(:watch) : read
  end





=begin

  #-------- ( ACCOUNT METHODS ) (Card)

  def update_account

    if params[:save_roles]
      role_card = @card.fetch :trait=>:roles, :new=>{}
      role_card.ok! :update

      role_hash = params[:user_roles] || {}
      role_card = role_card.refresh
      role_card.items= role_hash.keys.map &:to_i
    end

    account = @card.to_user
    if account and account_args = params[:account]
      unless Account.as_id == @card.id and !account_args[:blocked]
        @card.fetch(:trait=>:account).ok! :update
      end
      account.update_attributes account_args
    end

    if account && account.errors.any?
      account.errors.each do |field, err|
        @card.errors.add field, err
      end
      errors!
    else
      success
    end
  end

  def create_account
    @card.ok!(:create, :new=>{}, :trait=>:account)
    email_args = { :subject => "Your new #{Card.setting :title} account.",   #ENGLISH
                   :message => "Welcome!  You now have an account on #{Card.setting :title}." } #ENGLISH
    @user, @card = User.create_with_card(params[:user],@card, email_args)
    raise ActiveRecord::RecordInvalid.new(@user) if !@user.errors.empty?
    #@account = User.new(:email=>@user.email)
#    flash[:notice] ||= "Done.  A password has been sent to that email." #ENGLISH
    params[:attribute] = :account

    wagn_redirect( previous_location )
  end




  private

  #-------( FILTERS )



  #-------- ( ACCOUNT METHODS ) (Account)

  def accept
    card_key=params[:card][:key]
    #warn "accept #{card_key.inspect}, #{Card[card_key]}, #{params.inspect}"
    raise(Wagn::Oops, "I don't understand whom to accept") unless params[:card]
    @card = Card[card_key] or raise(Wagn::NotFound, "Can't find this Account Request")
    #warn "accept #{Account.user_id}, #{@card.inspect}"
    @user = @card.to_user or raise(Wagn::Oops, "This card doesn't have an account to approve")
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
    #warn "invite: ok? #{Card.new(:name=>'dummy+*account').ok?(:create)}"
    cok=Card.new(:name=>'dummy+*account').ok?(:create) or raise(Wagn::PermissionDenied, "You need permission to create")
    #warn "post invite #{cok}, #{request.post?}, #{params.inspect}"
    @user, @card = request.post? ?
      User.create_with_card( params[:user], params[:card] ) :
      [User.new, Card.new()]
    #warn "invite U:#{@user.inspect} C:#{@card.inspect}"
    if request.post? and @user.errors.empty?
      @user.send_account_info(params[:email])
      redirect_to Card.path_setting(Card.setting('*invite+*thanks'))
    end
  end

  def forgot_password
    return unless request.post? and email = params[:email].downcase
    @user = User.find_by_email(email)
    if @user.nil?
      flash[:notice] = "Unrecognized email."
      render :action=>'signin', :status=>404
    elsif !@user.active?
      flash[:notice] = "That account is not active."
      render :action=>'signin', :status=>403
    else
      @user.generate_password
      @user.save!
      subject = "Password Reset"
      message = "You have been given a new temporary password.  " +
         "Please update your password once you've signed in. "
      Mailer.account_info(@user, subject, message).deliver
      flash[:notice] = "Check your email for your new temporary password"
      redirect_to previous_location
    end
  end

  protected

  def user_errors
    @user.errors.each do |field, err|
      @card.errors.add field, err unless @card.errors[field].any?
      # needed to prevent duplicates because User adds them in the other direction in user.rb
    end
    errors!
  end

  # ----------------- ( ADMIN )
  #

  def setup
    raise(Wagn::Oops, "Already setup") if Account.first_login?
    Wagn::Conf[:recaptcha_on] = false
    if request.post?
      #Card::User  # wtf - trigger loading of Card::User, otherwise it tries to use U
      Account.as_bot do
        @account, @card = User.create_with_card( params[:account].merge({:login=>'first'}), params[:card] )

        # set default request recipient
        to_card = Card.fetch_or_new('*request+*to')
        to_card.content=params[:account][:email]
        to_card.save

        #warn "ext id = #{@account.id}"

        if @account.errors.empty?
          roles_card = Card.fetch_or_new(@card.cardname.trait_name(:roles))
          roles_card.content = "[[#{Card[Card::AdminID].name}]]"
          roles_card.save
          self.session_user = @card
          Card.cache.first_login= true
          flash[:notice] = "You're good to go!"
          redirect_to Card.path_setting('/')
        else
          flash[:notice] = "Durn, setup went awry..."
        end
      end
    else
      @card = Card.new( params[:card] || {} ) #should prolly skip defaults
      @account = User.new( params[:user] || {} )
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

=end
