# -*- encoding : utf-8 -*-
require 'xmlscan/processor'

class CardController < ApplicationController
  Card
  helper :wagn

  before_filter :index_preload, :only=> [ :index ]
  before_filter :read_file_preload, :only=> [ :read_file ]

  before_filter :load_card
  before_filter :refresh_card, :only=> [ :create, :update, :delete, :comment, :rollback ]
  before_filter :read_ok,      :only=> [ :read_file ]

  # rest XML put/post
  def read_xml(io)
    pairs = XMLScan::XMLProcessor.process(io, {:key=>:name, :element=>:card,
                      :substitute=>":transclude|{{:name}}", :extras=>[:type]})
    return if pairs.empty?

    main = pairs.shift
    #warn "main#{main.inspect}, #{pairs.empty?}"
    main, content, type = main[0], main[1][0]*'', main[1][2]

    data = { :name=>main }
    data[:cards] = pairs.inject({}) { |hash,p| k,v = p
         h = {:content => v[0]*''}
         h[:type] = v[2] if v[2]
         hash[k.to_cardname.to_absolute(v[1])] = h
         hash } unless pairs.empty?
    data[:content] = content unless content.blank?
    data[:type] = type if type
    data
  end

  def dump_pairs(pairs)
    warn "Result
#{    pairs.map do |p| n,o,c,t = p
      "#{c&&c.size>0&&"#{c}::"||''}#{n}#{t&&"[#{t}]"}=>#{o*''}"
    end * "\n"}
Done"
  end
  # Need to split off envelope code somehome

  def render_errors(options={})
    warn "rest rnder errors #{options.inspect}, #{@card&&@card.errors.map{|k,v| "#{k}::#{v}"}*''}, #{response}"
    render :text=>"<card status=#{response.status}>Error in card</card>"
  end
  def render_success
    warn "rest rnder suc #{@card&&@card.errors}, #{response}"
    render :text=>'<card status=200>Good card</card>'
  end

  def create
    Rails.logger.warn "create card #{params.inspect}"
    if request.parameters['format'] == 'xml'
      Rails.logger.warn (Rails.logger.debug "POST(rest)[#{params.inspect}] #{request.format}")
      #return render(:action=>"missing", :format=>:xml)  unless params[:card]
      if card_create = read_xml(request.body)
        begin
          @card = Card.new card_create
        #warn "POST creates are  #{card_create.inspect}"
        rescue Exception => e
          Rails.logger.warn "except #{e.inspect}, #{e.backtrace*"\n"}"
        end
      end

      Rails.logger.warn "create card #{request.body.inspect}"
    end

    if @card.save
      success
    else
      errors
    end
  end

  def read
    if @card.errors.any?
      errors
    else
      save_location # should be an event!
      show
    end
  end

  def update
    Rails.logger.warn "update card #{params.inspect}"
    if request.parameters['format'] == 'xml'
      Rails.logger.warn (Rails.logger.debug "POST(rest)[#{params.inspect}] #{request.format}")
      #return render(:action=>"missing", :format=>:xml)  unless params[:card]
      if main_card = read_xml(request.body)
        begin
          @card = Card.new card_create
        #warn "POST creates are  #{card_create.inspect}"
        rescue Exception => e
          Rails.logger.warn "except #{e.inspect}, #{e.backtrace*"\n"}"
        end
      end

      Rails.logger.warn "create card #{request.body.inspect}"
    end
    @card = @card.refresh if @card.frozen? # put in model
    case
    when @card.new_card?                          ;  create
    when @card.update_attributes( params[:card] ) ;  success
    else                                             errors
    end
  end

  def delete
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
      errors
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
      errors
    end
  end

  def rollback
    revision = @card.revisions[params[:rev].to_i - 1]
    @card.update_attributes! :content=>revision.content
    @card.attachment_link revision.id
    show
  end


  def watch
    watchers = @card.fetch_or_new_trait(:watchers )
    watchers = watchers.refresh
    myname = Account.authorized.name
    #warn "watch (#{myname}) #{watchers.inspect}, #{watchers.item_names.inspect}"
    watchers.send((params[:toggle]=='on' ? :add_item : :drop_item), myname)
    ajax? ? show(:watch) : read
  end






  #-------- ( ACCOUNT METHODS )

  def update_account
    if account_args = params[:account] and
        acct_cd = @card.fetch_trait(:account) and
        acct = acct_cd.account

      Account.authorized.id == acct_cd.id and !account_args[:blocked] and
        @card.ok! :update

      if params[:save_roles] and
          @card.trait_ok! :roles, :update and
        roll_card = @card.fetch_or_new_trait(:roles)
        role_hash = params[:user_roles] || {}
        role_card = role_card.refresh
        role_card.items= role_hash.keys.map &:to_i
      end

      acct.update_attributes account_args

      if acct.errors.any?
        acct.errors.each {|f,e| @card.errors.add f, e }
        errors
      else
        success
      end
    end
  end

  # FIXME: make this part of create
  def create_account
    @card.trait_ok! :account, :create
    email_args = { :subject => "Your new #{Card.setting :title} account.",   #ENGLISH
                   :message => "Welcome!  You now have an account on #{Card.setting :title}." } #ENGLISH
    Rails.logger.info "create_account #{params[:user].inspect}, #{email_args.inspect}"
    @user = Account.new params[:user]
    @user.active
    @card = @user.save_card(@card, email_args)
    raise ActiveRecord::RecordInvalid.new(@user) if !@user.errors.empty?
#    flash[:notice] ||= "Done.  A password has been sent to that email." #ENGLISH
    params[:attribute] = :account
    show :options
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
    # do content type processing, if it is an object, json or xml, parse that now and
    # params[:object] = parsed_object
    # looking into json parsing (apparently it is deep in rails: params_parser.rb)
    @card = case params[:id]
      when '*previous'   ; return wagn_redirect( previous_location )
      when /^\~(\d+)$/   ; Card.fetch $1.to_i
      when /^\:(\w+)$/   ; Card.fetch $1.to_sym
      else
        opts = params[:card] ? params[:card].clone : (obj = params[:object]) ? obj : {}
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

    case
    when  redirect        ; wagn_redirect ( Card===target ? url_for_page(target.cardname, new_params) : target )
    when  String===target ; render :text => target
    else
      @card = target
      show new_params[:view]
    end
  end

end

