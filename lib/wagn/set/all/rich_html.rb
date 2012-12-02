module Wagn
  module Set::All::RichHtml
    include Sets

    format :html

    define_view :show do |args|
      @main_view = args[:view] || params[:home_view]

      if ajax_call?
        self.render( @main_view || :open )
      else
        self.render_layout args
      end
    end

    define_view :layout, :perms=>:none do |args|
      if @main_content = args.delete( :main_content )
        @card = Card.fetch_or_new '*placeholder'
      end

      layout_content = get_layout_content args

      args[:params] = params # this is to pass params to inclusions.  let's find a cleaner way!
      process_content layout_content, args
    end

    define_view :content do |args|
      wrap :content, args do
        wrap_content( :content ) { _render_core args }
      end
    end

    define_view :titled do |args|
      hidden = { :menu_link=>true, :closed_link=>true }
#      hidden = { :menu_link=>true, :type=>true, :closed_link=>true }
      wrap :titled, args do
        _render_header( args.merge :default_hidden => hidden ) +
        wrap_content( :titled ) do
          _render_core args
        end
      end
    end

    define_view :title do |args|
      t = content_tag :h1, fancy_title, :class=>'card-title', :name_context=>"#{ @context_names.map(&:key)*',' }"
      add_name_context
      t
    end

    define_view :title do |args|
       t = content_tag :h1, fancy_title, :class=>'card-title', :name_context=>"#{ @context_names.map(&:key)*',' }"
       add_name_context
       t
    end

    define_view :open do |args|
      wrap :open, args.merge(:frame=>true) do
        %{
           #{ _render_header args }
           #{ wrap_content( :open, :body=>true ) { _render_open_content args } }
           #{ render_comment_box }
           #{ notice }
        }
      end
    end

    define_view :header do |args|
      hidden = args.delete(:default_hidden) || {}
      %{
      <div class="card-header">
        #{ _optional_render :menu_link, args, hidden[:menu_link] }
        #{ _optional_render :closed_link, args, hidden[:closed_link] }
        #{ _render_title }
      </div>
      }

      #{ _optional_render :type, args, hidden[:type] }
    end

    define_view :closed_link do |args|
      link_to raw('&otimes;'), path(:read, :view=>:closed), :title => "close #{card.name}", :class => "toggler slotter", :remote => true
    end

    define_view :menu_link do |args|
      %{<div class="card-menu-link">#{ _render_menu }&equiv;</div>}
    end

    define_view :menu do |args|

      admin_items = if card && card.update_account_ok? #sigh.  very inefficient to do this with every header!!
        [ link_to_action( 'rules', :options, :class=>'slotter' ),
          link_to_action( 'account', :option_account, :class=>'slotter')
        ]
      else
        []
      end

      option_html = %{
        <ul class="card-menu">
          <li>#{ link_to_action 'edit', :edit, :class=>'slotter' }
            <ul>
                <li>#{ link_to_action 'content', :edit, :class=>'slotter' }</li>
                <li>#{ link_to_action 'name', :edit_name, :class=>'slotter' }</li>
                <li>#{ link_to_action 'type', :edit_type, :class=>'slotter' }</li>
                <li>#{ link_to_action 'history', :changes, :class=>'slotter' }</li>
            </ul>
          </li>
          <li>#{ link_to_action 'view', :read, :class=>'slotter' }
            <ul>
              <li>#{ link_to_action 'refresh', :read, :class=>'slotter' }</li>
              <li>#{ link_to 'as main', path(:read) }</li>
              <li>#{ link_to_page "type: #{card.type_name}", card.type_name }</li>
            </ul>
          </li>
          <li>#{ link_to_action 'admin', :options, :class=>'slotter' }
            #{
            if !admin_items.empty?
              %{<ul>#{ admin_items.map do |i| "<li>#{i}</li>" end.join } </ul>}
            end
            }
          </li>
          #{ if Account.logged_in? && !card.new_card?
              "<li>#{ render_watch }</li>"
             end }
        </ul>
      }
      #fixme - many of these (including watch) need permission checks for activation
    end

    define_view :closed do |args|
      wrap :closed, args do
        %{
          <div class="card-header">
            #{ link_to raw('&oplus;'), path(:read, :view=>:open), :title => "open #{card.name}", :class => "toggler slotter", :remote => true }
            #{ _render_title }
          </div>
          #{ wrap_content( :closed ) { _render_closed_content } }
        }
      end
    end

    define_view :type do |args|
      klasses = ['cardtype']
      klasses << 'default-type' if card.type_id==Card::DefaultTypeID ? " default-type" : ''
      link_to_page card.type_name, nil, :class=>klasses
    end


    define_view( :comment_box, :denial=>:blank, :perms=>lambda { |r| r.card.ok? :comment } ) do |args|
      %{<div class="comment-box nodblclick"> #{
        card_form :comment do |f|
          %{#{f.text_area :comment, :rows=>3 }<br/> #{
          unless Account.logged_in?
            card.comment_author= (session[:comment_author] || params[:comment_author] || "Anonymous") #ENGLISH
            %{<label>My Name is:</label> #{ f.text_field :comment_author }}
          end}
          <input type="submit" value="Comment"/>}
        end}
      </div>}
    end



    define_view :new, :perms=>:create, :tags=>:unknown_ok do |args|
      name_ready = !card.cardname.blank? && !Card.exists?( card.cardname )

      cancel = if ajax_call?
        { :class=>'slotter',    :href=>path(:read, :view=>:missing)    }
      else
        { :class=>'redirecter', :href=>Card.path_setting('/*previous') }
      end

      if !ajax_call?
        header_text = card.type_id == Card::DefaultTypeID ? 'Card' : card.type_name
        %{ <h1 class="page-header">New #{header_text}</h1>}
      else '' end +


      (wrap :new, args.merge(:frame=>true) do
        card_form :create, 'card-form card-new-form', 'main-success'=>'REDIRECT' do |form|
          @form = form
          %{
            <div class="card-header">
              #{ hidden_field_tag :success, card.rule(:thanks) || '_self' }
              #{ help_text :add_help, :fallback=>:edit_help }
              #{
              case
              when name_ready                  ; _render_header + hidden_field_tag( 'card[name]', card.name )
              when card.rule_card( :autoname ) ; ''
              else                             ; _render_name_editor
              end
              }
              #{ params[:type] ? form.hidden_field( :type_id ) : _render_type_editor }
            </div>
            <div class="card-body">
              <div class="card-editor editor">#{ edit_slot args }</div>
              <fieldset>
                <div class="button-area">
                  #{ submit_tag 'Submit', :class=>'create-submit-button' }
                  #{ button_tag 'Cancel', :type=>'button', :class=>"create-cancel-button #{cancel[:class]}", :href=>cancel[:href] }
                </div>
              </fieldset>
            </div>
            #{ notice }
          }
        end
      end)
    end

    define_view :editor do |args|
      form.text_area :content, :rows=>3, :class=>'tinymce-textarea card-content', :id=>unique_id
    end

    define_view :missing do |args|
      return '' unless card.ok? :create  #this should be moved into ok_view
      new_args = { 'card[name]'=>card.name }
      new_args['card[type]'] = args[:type] if args[:type]

      wrap :missing, args do
        link_to raw("Add <strong>#{ showname }</strong>"), path(:new, new_args),
          :class=>'slotter', :remote=>true
      end
    end

  ###---(  EDIT VIEWS )
    define_view :edit, :perms=>:update, :tags=>:unknown_ok do |args|
      confirm_delete = "Are you sure you want to delete #{card.name}?"
      if dependents = card.dependents and dependents.any?
        confirm_delete +=  %{ \n\nThat would mean removing #{dependents.size} related pieces of information. }
      end

      wrap :edit, args.merge(:frame=>true) do
        %{
        #{_render_header }
        #{ help_text :edit_help }
        #{ wrap_content :edit, :body=>true, :class=>'card-editor' do
           card_form :update, 'card-form card-edit-form autosave' do |f|
            @form= f
            %{
            <div>#{ edit_slot args }</div>
            <fieldset>
              <div class="button-area">
                #{ submit_tag 'Submit', :class=>'submit-button' }
                #{ button_tag 'Cancel', :class=>'cancel-button slotter', :href=>path(:read), :type=>'button'}
                #{
                if !card.new_card?
                  button_tag "Delete", :href=>path(:delete), :type=>'button',
                    :class=>'delete-button slotter standard-delete', :'data-confirm'=>confirm_delete
                end
                }
              </div>
            </fieldset>
            }
          end
        end }
        #{ notice }
        }
      end
    end

    define_view :name_editor do |args|
      fieldset 'name', (editor_wrap :name do
         raw( name_field form )
      end)
    end



    define_view :edit_name, :perms=>:update do |args|
      card.update_referencers = false
      referers = card.extended_referencers
      dependents = card.dependents

      wrap :edit_name, args.merge(:frame=>true) do
        _render_header +
        wrap_content( :edit_name, :body=>true, :class=>'card-editor' ) do
          card_form( path(:update, :id=>card.id), 'card-name-form', 'main-success'=>'REDIRECT' ) do |f|
            @form = f
            %{
              #{ _render_name_editor}

              #{ f.hidden_field :update_referencers, :class=>'update_referencers'   }
              #{ hidden_field_tag :success, '_self'  }
              #{ hidden_field_tag :old_name, card.name }
              #{ hidden_field_tag :confirmed, 'false'  }
              #{ hidden_field_tag :referers, referers.size }
              <div class="confirm-rename hidden">
                <h1>Are you sure you want to rename <em>#{card.name}</em>?</h1>
                #{ %{ <h2>This change will...</h2> } if referers.any? || dependents.any? }
                <ul>
                  #{ %{<li>automatically alter #{ dependents.size } related name(s). } if dependents.any? }
                  #{ %{<li>break at least #{referers.size} reference(s) to this name.} if referers.any? }
                </ul>
                #{ %{<p>You may choose to <em>ignore or fix</em> the references. Fixing will update references to use the new name.</p>} if referers.any? }
              </div>
              <fieldset>
                <div class="button-area">
                  #{ submit_tag 'Rename', :class=>'edit-name-submit-button' }
                  #{ button_tag 'Cancel', :class=>'edit-name-cancel-button slotter', :type=>'button', :href=>path(:edit, :id=>card.id)}
                </div>
              </fieldset>
            }
          end
        end
      end
    end

    define_view :type_editor do |args|
      fieldset 'type', (editor_wrap :type do
        if args[:variety] == :edit
          type_field :class=>'type-field edit-type-field'
        else
          type_field :class=>"type-field live-type-field", :href=>path(:new), 'data-remote'=>true
        end
      end)
    end

    define_view :related do |args|
      sources = [card.type_name,nil]
      # FIXME codename *account
      #sources.unshift '*account' if [Card::WagnBotID, Card::AnonID].member?(card.id) || card.type_id==Card::UserID
      items = sources.map do |source|
        c = Card.fetch(source ? source.to_name.trait_name(:related) : Card::RelatedID)
        c && c.item_names
      end.flatten.compact

      current = params[:attribute] || items.first.to_name.key

      wrap :related, args do
        %{#{ _render_header }
          <div class="submenu"> #{
            items.map do |item|
              key = item.to_name.key
              text = item.gsub('*','').gsub('subtab','').strip
              link_to text, path(:related, :attrib=>key), :remote=>true,
                :class=>"slotter #{key==current ? 'current-subtab' : ''}"
            end * "\n"}
           </div> #{
           notice }

          <div class="open-content related"> #{
            raw subrenderer(Card.fetch_or_new "#{card.name}+#{current}").render_content }
          </div>}
      end
    end

    define_view :options, :perms=>:none do |args|
      attribute = params[:attribute]

      end
      label = link_to_page fancy_title, link_target
      fieldset label, content, :help=>help_settings, :attribs=>attribs
    end

    define_view :option_account, :perms=> lambda { |r|
        Account.as_card.id==r.card.id or r.card.ok?(:update, :trait=>:account)
      } do |args|

      locals = {:slot=>self, :card=>card, :account=>card.account }
      wrap :options, args.merge(:frame=>true) do
        %{ #{ _render_header }
          <div class="options-body">
            #{ card_form :update_account, '', 'notify-success'=>'account details updated' do |form|
              %{
              #{ hidden_field_tag 'success[id]', '_self' }
              #{ hidden_field_tag 'success[view]', 'options' }
              <table class="fieldset">
                #{ option_header 'Account Details' }
                #{ template.render :partial=>'account/edit',  :locals=>locals }

                #{ _render_option_roles }
                #{ if options_need_save
                    %{<tr><td colspan="3">#{ submit_tag 'Save Changes' }</td></tr>}
                   end
                }
              </table>}
            end }
          </div>
          #{ notice }
        }
      end
    end

    define_view :options do |args|
      related_sets = card.related_sets
      current_set = params[:current_set] || related_sets[card.type_id==Card::CardtypeID ? 1 : 0]  #FIXME - explicit cardtype reference
      set_options = related_sets.map do |set_name|
        set_card = Card.fetch set_name
        selected = set_card.key == current_set.to_name.key ? 'selected="selected"' : ''
        %{<option value="#{ set_card.key }" #{ selected }>#{ set_card.label }</option>}
      end.join

      wrap :options, args.merge(:frame=>true) do
        %{ #{ _render_header }
            <div class="options-body">
              <div class="settings-tab">
                #{ if !related_sets.empty?
                  %{ <div class="set-selection">
                    #{ form_tag path(:options, :attrib=>:settings), :method=>'get', :remote=>true, :class=>'slotter' }
                        <label>Set:</label>
                        <select name="current_set" class="set-select">#{ set_options }</select>
                    </form>
                  </div>}
                end }

                <div class="current-set">
                  #{ raw subrenderer( Card.fetch current_set).render_content }
                </div>

                #{ my_card = card && card.id == Account.authorized.id
                   if Card.toggle(card.rule(:accountable)) && (my_card || card.ok?(:create, :trait=>:account, :new=>{}))

                    %{<div class="new-account-link">
                    #{ link_to %{Add a sign-in account for "#{card.name}"},
                        path(:options, :attrib=>:new_account),
                      :class=>'slotter new-account-link', :remote=>true }
                    </div>}
                   end
                }
              </div>
            </div>
            #{ notice }
          }
       end
    end

    define_view :option_roles do |args|
      roles = Card.search( :type=>Card::RoleID, :limit=>0 ).reject do |x|
        [Card::AnyoneID, Card::AuthID].member? x.id.to_i
      end

      traitc = card.fetch :trait => :roles, :new=>{}
      user_roles = traitc.item_cards :limit=>0

      option_content = if traitc.ok? :update
          user_role_ids = user_roles.map &:id
          hidden_field_tag(:save_roles, true) +
          (roles.map do |rolecard|
            #warn Rails.logger.info("option_roles: #{rolecard.inspect}")
            if rolecard && !rolecard.trash
             %{<div style="white-space: nowrap">
               #{ check_box_tag "user_roles[%s]" % rolecard.id, 1, user_role_ids.member?(rolecard.id) ? true : false }
               #{ link_to_page rolecard.name }
             </div>}
            end
          end.compact * "\n").html_safe
        elsif user_roles.any?
          (user_roles.map do |rolecard|
            %{ <div>#{ link_to_page rolecard.name }</div>}
          end * "\n").html_safe
        end
      end

      %{#{ raw option_header( 'User Roles' ) }#{
         option(option_content, :name=>"roles",
        :help=>%{ <span class="small">"#{ link_to_page 'Roles' }" are used to set user permissions</span>}, #ENGLISH
        :label=>"#{card.name}'s Roles",
        :editable=>card.ok?(:update, :trait=>:roles, :new=>{})
      )}}
    end

    define_view :account_email do |args|
      %{<tr>
         <td class="label"><label for="email">Email</label></td>
         <td class="field">#{ text_field :account, :email }</td>
         <td class="help"><strong>To verify account</strong><br/></td>
       </tr>} #ENGLISH%>
    end

    define_view :option_new_account do |args|
      %{#{
        card_form :create_account do |form|
          #ENGLISH
          %{<table class="fieldset">
          #{ # render :partial=>'account/email'  this isn't really workable anymore
            _render_account_email # this view doesn't work  yet, though
          }
             <tr><td colspan="3" style><p>
         A password for a new sign-in account will be sent to the above address.
             #{ submit_tag 'Create Account' }
             </p></td></tr>
          </table>}
       end}}
    end

    define_view :changes do |args|
      load_revisions
      if @revision
        wrap :changes, args.merge(:frame=>true) do
          %{#{ _render_header }
            <div class="revision-header">
              <span class="revision-title">#{ @revision.title }</span>
              posted by #{ link_to_page @revision.creator.name }
              on #{ format_date(@revision.created_at) } #{
              if !card.drafts.empty?
                %{<div class="autosave-alert">
                  This card has an #{ autosave_revision }
                </div>}
              end}#{
              if @show_diff and @revision_number > 1  #ENGLISH
                %{<div class="revision-diff-header">
                  <small>
                    Showing changes from revision ##{ @revision_number - 1 }:
                    <ins class="diffins">Added</ins> | <del class="diffmod">Deleted</del>
                  </small>
                </div>}
              end}
            </div>
            <div class="revision-navigation">#{ revision_menu }</div>
            #{ wrap_content( :revision, :body=>true ) { _render_diff } }
          }
        end
      end
    end

    define_view :diff do |args|
      if @show_diff and @previous_revision
        diff @previous_revision.content, @revision.content
      else
        @revision.content
      end
    end

    define_view :conflict, :error_code=>409 do |args|
      load_revisions
      wrap :errors do |args|
        %{<strong>Conflict!</strong><span class="new-current-revision-id">#{@revision.id}</span>
          <div>#{ link_to_page @revision.creator.card.name } has also been making changes.</div>
          <div>Please examine below, resolve above, and re-submit.</div>
          #{wrap(:conflict) { |args| _render_diff } } }
      end
    end

    define_view :change do |args|
      wrap :change, args do
        %{#{link_to_page card.name, nil, :class=>'change-card'} #{
         if rev = card.current_revision and !rev.new_record?
           # this check should be unnecessary once we fix search result bug
           %{<span class="last-update"> #{

             case card.updated_at.to_s
               when card.created_at.to_s; 'added'
               when rev.created_at.to_s;  link_to('edited', path(:changes), :class=>'last-edited')
               else; 'updated'
             end} #{

              time_ago_in_words card.updated_at } ago by #{ #ENGLISH
              link_to_page card.updater.name, nil, :class=>'last-editor'}
            </span>}
         end }
         <br style="clear:both"/>}
      end
    end

    define_view :errors, :perms=>:none do |args|
      wrap :errors, args do
        %{ <h2>Problems #{%{ with <em>#{card.name}</em>} unless card.name.blank?}</h2> } +
        card.errors.map { |attrib, msg| "<div>#{attrib.upcase}: #{msg}</div>" } * ''
      end
    end

    define_view :not_found do |args| #ug.  bad name.
      sign_in_or_up_links = if Account.logged_in?
        %{<div>
          #{link_to "Sign In", :controller=>'account', :action=>'signin'} or
          #{link_to 'Sign Up', :controller=>'account', :action=>'signup'} to create it.
         </div>}

      %{ <h1 class="page-header">Missing Card</h1> } +
      wrap( :not_found, args.merge(:frame=>true) ) do # ENGLISH
        %{<div class="content instruction">
            <div>There's no card named <strong>#{card.name}</strong>.</div>
            #{sign_in_or_up_links}
          </div>}
      end
    end

    define_view :denial do |args|
      task = args[:denied_task] || params[:action]
      to_task = %{to #{task} this card#{ ": <strong>#{card.name}</strong>" if card.name && !card.name.blank? }.}
      if !focal?
        %{<span class="denied"><!-- Sorry, you don't have permission #{to_task} --></span>}
      else
        wrap :denial, args.merge(:frame=>true) do #ENGLISH below
          %{
          #{ _render_header }
          <div id="denied" class="instruction card-body">
            <h1>Ooo.  Sorry, but...</h1>
            #{
            if task != :read && Wagn::Conf[:read_only]
              "<div>We are currently in read-only mode.  Please try again later.</div>"
            else
              if Account.logged_in?
                %{<div>You need permission #{to_task}</div> }
              else
                %{<div>You have to #{ link_to "sign in", wagn_url("/account/signin") } #{to_task}</div>
                #{
                if Card.new(:type_id=>Card::AccountRequestID).ok? :create
                  %{<div>#{ link_to 'Sign up for a new account', wagn_url("/account/signup") }.</div>}
                end
                }}
              end
            end}
          </div>}
        end
      end
    end


    define_view :server_error do |args|
      %{
      <body>
        <div class="dialog">
          <h1>Wagn Hitch :(</h1>
          <p>Server Error. Yuck, sorry about that.</p>
          <p><a href="http://www.wagn.org/new/Support_Ticket">Add a support ticket</a>
              to tell us more and follow the fix.</p>
        </div>
      </body>
      }
    end

    define_view :watch, :tags=>:unknown_ok, :denial=>:blank,
      :perms=> lambda { |r| Account.logged_in? && !r.card.new_card? } do |args|

      wrap :watch do
        if card.watching_type?
          watching_type_cards
        else
          link_args = if card.watching?
            ["following", :off, "stop sending emails about changes to #{card.cardname}", { :hover_content=> 'unfollow' } ]
          else
            ["follow", :on, "send emails about changes to #{card.cardname}" ]
          end
          watch_link *link_args
        end
      end
    end

  end
end

class Wagn::Renderer::Html
  def watching_type_cards
    %{<div class="faint">(following)</div>} #yuck
  end

  def watch_link text, toggle, title, extra={}
    link_to "#{text}", path(:watch, :toggle=>toggle),
      {:class=>"watch-toggle watch-toggle-#{toggle} slotter", :title=>title, :remote=>true, :method=>'post'}.merge(extra)
  end
end

