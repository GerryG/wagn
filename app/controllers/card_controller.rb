# -*- encoding : utf-8 -*-


class CardController < ApplicationController
  # This is often needed for the controllers to work right
  # FIXME: figure out when/why this is needed and why the tests don't fail
  Card

  helper :wagn

  before_filter :read_file_preload, :only=> [ :read_file ]

  before_filter :load_card
  before_filter :refresh_card, :only=> [ :create, :update, :delete, :comment, :rollback ]
  before_filter :read_ok,      :only=> [ :read_file ]

  METHODS = {
    'POST'   => :create,  # C
    'GET'    => :read,    # R
    'PUT'    => :update,  # U
    'DELETE' => :delete,  # D
    'INDEX'  => :index
  }

  def action
    @action = METHODS[request.method]
    Rails.logger.warn "action_handler #{request.method}, #{@action} #{params.inspect}"
    warn "action_handler #{request.method}, #{@action} #{params.inspect}"
    if send "_handle_#{@action}"
    else
      errors!
    end
  end

  cattr_reader :subset_handlers

  @@subset_handlers   = {}

  def handler_method event
    return "_final_#{event}" unless @card && @@subset_handlers[event]
    @card.method_keys.each do |method_key|
      meth = "_final_"+(method_key.blank? ? "#{event}" : "#{method_key}_#{event}")
      #warn "looking up #{method_key}, M:#{meth} for #{@card.name}"
      return meth if respond_to?(meth.to_sym)
    end
    nil
  end



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

  #before_filter :index_preload, :only=> [ :index ]
  action :before => :index do
    if Account.first_login?
      home_name = Card.setting(:home) || 'Home'
      params[:id] = home_name.to_name.url_key
    else
      redirect_to Card.path_setting '/admin/setup'
    end
  end


  def load_card
    @card = case params[:id]
      when '*previous'   ; return wagn_redirect( previous_location )
      when /^\~(\d+)$/   ; Card.fetch $1.to_i
      when /^\:(\w+)$/   ; Card.fetch $1.to_sym
      else
        opts = params[:card] ? params[:card].clone : {}
        opts[:type] ||= params[:type] # for /new/:type shortcut.  we should fix and deprecate this.
        name = params[:id] || opts[:name]
        
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

    case
    when  redirect        ; wagn_redirect ( Card===target ? url_for_page(target.cardname, new_params) : target )
    when  String===target ; render :text => target
    else
      @card = target
      show new_params[:view]
    end
  end


  def password_authentication(login, password)
    if self.session_user = User.authenticate( params[:login], params[:password] )
      flash[:notice] = "Successfully signed in"
      #warn Rails.logger.info("to prev #{previous_location}")
      redirect_to previous_location
    else
      usr=User.where(:email=>params[:login].strip.downcase).first
      failed_login(
        case
        when usr.nil?     ; "Unrecognized email."
        when usr.blocked? ; "Sorry, that account is blocked."
        else              ; "Wrong password"
        end
      )
    end
  end

  def failed_login(message)
    flash[:notice] = "Oops: #{message}"
    render :action=>'signin', :status=>403
  end

end

