# -*- encoding : utf-8 -*-


class CardController < ApplicationController
  Card
  helper :wagn

  before_filter :index_preload, :only=> [ :index ]
  before_filter :read_file_preload, :only=> [ :read_file ]

  before_filter :load_card
  before_filter :refresh_card, :only=> [ :create, :update, :delete, :comment, :rollback ]
  before_filter :read_ok,      :only=> [ :read_file ]


  def create
    if @card.save
      success
    else
      errors!
    end
  end

  def read
    save_location # should be an event!
    show
  end

  def update
    case
    when @card.new_card?                          ;  create
    when @card.update_attributes( params[:card] ) ;  success
    else                                             errors!
    end
  end

  def delete
    @card.confirm_destroy = params[:confirm_destroy]
    @card.destroy

    return show(:delete) if @card.errors[:confirmation_required].any?

    discard_locations_for(@card)
    success 'REDIRECT: *previous'
  end


  alias index read
  def read_file() show_file end



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

    # FIXME: need this loaded like an inflector, this can't be the only place that would use this
    # or maybe wrap it with the split, map, join too, and why not strip it in any case?
    to_html = lambda {|line| "<p>#{line.strip.empty? ? '&nbsp;' : line}</p>"}

    # this previously failed unless request.post?, but it is now (properly) a PUT.
    # if we enforce RESTful http methods, we should do it consistently,
    # and error should be 405 Method Not Allowed
    author = Account.logged_in? ? "[[#{Account.authorized.name}]]" :
              "#{session[:comment_author] = params[:card][:comment_author]} (Not signed in)"
    comment = params[:card][:comment].split(/\n/).map(&to_html) * "\n"

    @card.comment = %{<hr>#{ comment }<p><em>&nbsp;&nbsp;--#{ author }.....#{Time.now}</em></p>}

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
    myname = Account.authorized.name
    #warn "watch (#{myname}) #{watchers.inspect}, #{watchers.item_names.inspect}"
    watchers.send((params[:toggle]=='on' ? :add_item : :drop_item), myname)
    ajax? ? show(:watch) : read
  end






  #-------- ( ACCOUNT METHODS )

  def update_account
    #Rails.logger.warn "updating account #{params[:account].inspect}, #{@card.fetch(:trait => :account).account}"
    if account_args = params[:account] and
        acct_cd = @card.fetch(:trait=>:account) and
        acct = acct_cd.account

      my_card = Account.authorized.id == acct_cd.id
      my_card and !account_args[:blocked] and
      Account.authorized.id == acct_cd.id and !account_args[:blocked] and
        @card.ok! :update

      if params[:save_roles] and my_card || roles_card = @card.fetch(:trait=>:roles, :new=>{}) and roles_card.ok?(:create)
        roles = (params[:user_roles]||{}).keys.map(&:to_i)
        roles_card = roles_card.refresh
        roles_card.items= roles
        roles_card.save
        roles_card.errors.each {|f,e| @card.errors.add f, e } if roles_card.errors.any?
      end

      acct.update_attributes account_args if request.put? or request.post?

      if acct.errors.any?
        acct.errors.each {|f,e| @card.errors.add f, e }
        errors!
      else
        success
      end
    end
  end

  # FIXME: make this part of create
  def create_account
    @card.ok!(:create, :new=>{}, :trait=>:account)
    email_args = { :subject => "Your new #{Card.setting :title} account.",   #ENGLISH
                   :message => "Welcome!  You now have an account on #{Card.setting :title}." } #ENGLISH
    Rails.logger.info "create_account #{params.inspect}, #{email_args.inspect}"
    @account = Account.new params[:account]
    @account.active
    @card = @account.save_card(@card, email_args)
    Rails.logger.warn "create_account error: #{@account.errors.map{|k,v|"#{k} -> #{v}"}*', '}" if @account.errors.any?
    # FIXME: don't raise, handle it
    raise ActiveRecord::RecordInvalid.new(@account) if @account.errors.any?
#    flash[:notice] ||= "Done.  A password has been sent to that email." #ENGLISH
    params[:attribute] = :account
    # FIXME: this is broken, create acount doesn't process errors or return
    show
  end




  private

  #-------( FILTERS )

  def read_file_preload
    #warn "show preload #{params.inspect}"
    params[:id] = params[:id].sub(/(-(#{Card::STYLES*'|'}))?(-\d+)?(\.[^\.]*)?$/) do
      @style = $1.nil? ? 'original' : $2
      @rev_id = $3 && $3[1..-1]
      params[:format] = $4[1..-1] if $4
      ''
    end
  end

  def index_preload
    Account.no_logins? ?
      redirect_to( Card.path_setting '/admin/setup' ) :
      params[:id] = (Card.setting(:home) || 'Home').to_name.url_key
  end

  def load_card
    @card = case params[:id]
      when '*previous'   ; return wagn_redirect( previous_location )
      when /^\~(\d+)$/   ; Card.fetch $1.to_i
      when /^\:(\w+)$/   ; Card.fetch $1.to_sym
      else
        opts = params[:card] ? params[:card].clone : {}
        opts[:type] ||= params[:type] # for /new/:type shortcut.  we should fix and deprecate this.
        name = params[:id] ? SmartName.unescape( params[:id] ) : opts[:name]
        
        if @action == 'create'
          # FIXME we currently need a "new" card to catch duplicates (otherwise #save will just act like a normal update)
          # I think we may need to create a "#create" instance method that handles this checking.
          # that would let us get rid of this...
          opts[:name] ||= name
          Card.new opts
        else
          Card.fetch_or_new name, opts
        end
      end

    Wagn::Conf[:main_name] = params[:main] || (@card && @card.name) || ''
    true
  end

  def refresh_card
    @card = @card.refresh
  end

  #-------( REDIRECTION )

  def success default_target='_self'
    target = params[:success] || default_target
    redirect = !ajax?
    new_params = {}
    
    if Hash === target
      new_params = target
      target = new_params.delete :id # should be some error handling here
      redirect ||= !!(new_params.delete :redirect)
    end
      
    if target =~ /^REDIRECT:\s*(.+)/
      redirect, target = true, $1
    end

    target = case target
      when '*previous'     ;  previous_location #could do as *previous
      when '_self  '       ;  @card #could do as _self
      when /^(http|\/)/    ;  target
      when /^TEXT:\s*(.+)/ ;  $1
      else                 ;  Card.fetch_or_new target.to_name.to_absolute(@card.cardname)
      end

    #Rails.logger.info "redirect = #{redirect}, target = #{target}, new_params = #{new_params}"
    case
    when  redirect        ; wagn_redirect ( Card===target ? url_for_page(target.cardname, new_params) : target )
    when  String===target ; render :text => target
    else
      @card = target
      show new_params[:view]
    end
  end

end

