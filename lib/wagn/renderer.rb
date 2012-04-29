module Wagn
  class Renderer
    include ReferenceTypes
    include LocationHelper

    DEPRECATED_VIEWS = { :view=>:open, :card=>:open, :line=>:closed, :bare=>:core, :naked=>:core }
    UNDENIABLE_VIEWS = [ :deny_view, :denial, :errors, :edit_virtual,
      :too_slow, :too_deep, :missing, :not_found, :closed_missing, :name,
      :link, :linkname, :url, :show, :layout, :bad_address, :server_error ]
    INCLUSION_MODES  = { :main=>:main, :closed=>:closed, :closed_content=>:closed, :edit=>:edit,
      :layout=>:layout, :new=>:edit }
    DEFAULT_ITEM_VIEW = :link
  
    RENDERERS = {
      :html => :Html,
      :css  => :Text,
      :txt  => :Text
    }
    
    cattr_accessor :current_slot, :ajax_call

    @@max_char_count = 200
    @@max_depth = 10
    @@subset_views = {}

    class << self
      def new card, opts={}
        if self==Renderer
          fmt = (opts[:format] ? opts[:format].to_sym : :html)
          renderer = (RENDERERS.has_key?(fmt) ? RENDERERS[fmt] : fmt.to_s.camelize).to_sym
          if Renderer.const_defined?(renderer)
            return Renderer.const_get(renderer).new(card, opts) 
          end
        end
        new_renderer = self.allocate
        new_renderer.send :initialize, card, opts
        new_renderer
      end
  
    # View definitions
    #
    #   When you declare:
    #     define_view :view_name, "<set>" do |args|
    #
    #   Methods are defined on the renderer
    #
    #   The external api with checks:
    #     render(:viewname, args)
    #
    #   Roughly equivalent to:
    #     render_viewname(args)
    #
    #   The internal call that skips the checks:
    #     _render_viewname(args)
    # 
    #   Each of the above ultimately calls:
    #     _final(_set_key)_viewname(args)


      def define_view view, opts={}, &final
        view_key = get_view_key(view, opts)
        define_method( "_final_#{view_key}", &final )
        #warn "defining method _final_#{view_key}"
        @@subset_views[view] = true if !opts.empty?

        if !method_defined? "render_#{view}"
          define_method( "_render_#{view}" ) do |*a|
            a = [{}] if a.empty?
            if final_method = view_method(view)
              with_inclusion_mode(view) { send(final_method, *a) }
            else
              "<strong>unsupported view: <em>#{view}</em></strong>"
            end
          end

          define_method( "render_#{view}" ) do |*a|
            begin
              denial=deny_render(view.to_sym, *a) and return denial
#              msg = "render #{view} #{ card && card.name.present? ? "called for #{card.name}" : '' }"
#              ActiveSupport::Notifications.instrument 'wagn.render', :message=>msg do
                send( "_render_#{view}", *a)
#              end
            rescue Exception=>e
              Rails.logger.info "\nRender Error: #{e.message}"
              Rails.logger.debug "  #{e.backtrace*"\n  "}"
              rendering_error e, (card && card.name.present? ? card.name : 'unknown card')
            end
          end
        end
      end

      def alias_view view, opts={}, *aliases
        view_key = get_view_key(view, opts)
        aliases.each do |aview|
          aview_key = case aview
            when String; aview
            when Symbol; (view_key==view ? aview.to_sym : view_key.to_s.sub(/_#{view}$/, "_#{aview}").to_sym)
            when Hash;   get_view_key( aview[:view] || view, aview)
            else; raise "Bad view #{aview.inspect}"
            end

          define_method( "_final_#{aview_key}".to_sym ) do |*a|
            send("_final_#{view_key}", *a)
          end
        end
      end
      
      private
      
      def get_view_key view, opts
        unless pkey = Wagn::Model::Pattern.method_key(opts) 
          raise "bad method_key opts: #{pkey.inspect} #{opts.inspect}"
        end
        key = pkey.blank? ? view : "#{pkey}_#{view}"
        key.to_sym
      end
      
    end


    attr_reader :card, :root, :showname #should be able to factor out showname
    attr_accessor :form, :main_content

    def render view = :view, args={}
      method = "render_#{canonicalize_view view}"
      if respond_to? method
        send method, args
      else
        "<strong>unknown view: <em>#{view}</em></strong>"
      end
    end

    #should also be a #optional_render that checks perms
    def _optional_render view, args, default_hidden=false
      test = default_hidden ? :show : :hide
      override = args[test] && args[test].member?(view.to_s)
      return nil if default_hidden ? !override : override
      send "_render_#{ view }", args
    end

    def rendering_error exception, cardname
      "Error rendering: #{cardname}"
    end
  
    def initialize card, opts={}
      Renderer.current_slot ||= self unless(opts[:not_current])
      @card = card
      opts.each { |key, value| instance_variable_set "@#{key}", value }
  
      @format ||= :html
      @char_count = @depth = 0
      @root = self
      
      if card && card.collection? && params[:item] && !params[:item].blank?
        @item_view = params[:item]
      end
    end

    def params()       @params     ||= controller.params                          end
    def flash()        @flash      ||= controller.request ? controller.flash : {} end
    def controller()   @controller ||= StubCardController.new                     end
    def session()      CardController===controller ? controller.session : {}      end
    def ajax_call?()   @@ajax_call                                                end

    def main?
      if ajax_call?
        @depth == 0 && params[:is_main]
      else
        @depth == 1 && @mode == :main
      end                            
    end
      
    def template
      @template ||= begin
        c = controller
        t = ActionView::Base.new c.class.view_paths, {:_routes=>c._routes}, c
        t.extend c.class._helpers
        t
      end
    end

    def method_missing method_id, *args, &proc
      proc = proc {|*a| raw yield *a } if proc
      response = template.send method_id, *args, &proc
      String===response ? template.raw( response ) : response
    end
  
    def subrenderer(subcard, opts={})
      subcard = Card.fetch_or_new(subcard) if String===subcard
      sub = self.clone
      sub.initialize_subrenderer(subcard, opts)
    end
    
    def initialize_subrenderer subcard, opts
      @card = subcard
      @char_count = 0
      @depth += 1
      @item_view = @main_content = @showname = nil
      opts.each { |key, value| instance_variable_set "@#{key}", value }
      self
    end
    
    
    def process_content content=nil, opts={}
      return content unless card
      content = card.content if content.blank?
  
      wiki_content = WikiContent.new(card, content, self)
      update_references( wiki_content, true ) if card.references_expired
  
      wiki_content.render! do |opts|
        expand_inclusion(opts) { yield }
      end
    end
    alias expand_inclusions process_content
  
  
    def deny_render action, args={}
      return false if UNDENIABLE_VIEWS.member?(action)
      ch_action = case
        when @depth >= @@max_depth ; :too_deep
        when !card                 ; false
        when action == :watch
          :blank if !Card.logged_in? || card.virtual?
        when [:new, :edit, :edit_in_form].member?(action)
          allowed = card.ok?(card.new_card? ? :create : :update)
          !allowed && :deny_view #should be deny_create or deny_update...
        else
          !card.ok?(:read) and :deny_view #should be deny_read
      end
      ch_action and render(ch_action, args)
    end
    
    def canonicalize_view view
      (v=!view.blank? && DEPRECATED_VIEWS[view.to_sym]) ? v : view
    end
  
    def view_method view
      return "_final_#{view}" if !card || !@@subset_views[view]
      #warn "vmeth #{card}, #{view}, #{card.method_keys.inspect}"
      card.method_keys.each do |method_key|
        meth = "_final_"+(method_key.blank? ? "#{view}" : "#{method_key}_#{view}")
        #warn "view meth is #{meth.inspect}, #{view.inspect} #{method_key.inspect} #{respond_to?(meth.to_sym)}"
        return meth if respond_to?(meth.to_sym)
      end
      nil
    end
  
    def with_inclusion_mode mode
      if switch_mode = INCLUSION_MODES[ mode ]
        old_mode, @mode = @mode, switch_mode
      end
      result = yield
      @mode = old_mode if switch_mode
      result
    end
  
    def expand_inclusion opts
      return opts[:comment] if opts.has_key?(:comment)
      # Don't bother processing inclusion if we're already out of view
      return '' if @mode == :closed && @char_count > @@max_char_count
      #warn "exp_inc #{opts.inspect}, #{card.inspect}"
      return expand_main(opts) if opts[:tname]=='_main' && !ajax_call? && @depth==0
      
      opts[:view] = canonicalize_view opts[:view]
      opts[:view] ||= ( @mode == :layout ? :core : :content )
      
      tcardname = opts[:tname].to_cardname
      fullname = tcardname.to_absolute(card.cardname, params)
      opts[:showname] = tcardname.to_show(card.cardname).to_s
      
      included_card = Card.fetch_or_new fullname, ( @mode==:edit ? new_inclusion_card_args(opts) : {} )
  
      result = process_inclusion included_card, opts
      @char_count += (result ? result.length : 0)
      result
    rescue Card::PermissionDenied
      ''
    end
  
    def expand_main opts
      return wrap_main( @main_content ) if @main_content
      [:item, :view, :size].each do |key|
        if val=params[key] and val.to_s.present?
          opts[key] = val.to_sym
        end
      end
      opts[:view] = @main_view || opts[:view] || :open
      opts[:showname] = root.card.name
      with_inclusion_mode :main do
        wrap_main process_inclusion( root.card, opts )
      end
    end
  
    def wrap_main content
      content  #no wrapping in base renderer
    end
  
    def process_inclusion tcard, options
      sub = subrenderer( tcard, 
        :item_view =>options[:item], 
        :type      =>options[:type],
#        :size      =>options[:size],
        :showname  =>(options[:showname] || tcard.name)
      )
      oldrenderer, Renderer.current_slot = Renderer.current_slot, sub  #don't like depending on this global var switch
  
      new_card = tcard.new_card? && !tcard.virtual?
  
      requested_view = (options[:view] || :content).to_sym
      options[:home_view] = [:closed, :edit].member?(requested_view) ? :open : requested_view
      approved_view = case

        when (UNDENIABLE_VIEWS + [ :new, :closed_rule, :open_rule ]).member?(requested_view)  ; requested_view
        when @mode == :edit
         tcard.virtual? ? :edit_virtual : :edit_in_form 
         # FIXME should be concerned about templateness, not virtualness per se
         # needs to handle real cards that are hard templated much better
        when new_card
          case
          when requested_view == :raw ; :blank
          when @mode == :closed       ; :closed_missing
          else                        ; :missing
          end
        when @mode==:closed     ; :closed_content
        else                    ; requested_view
        end
      #warn "rendering #{approved_view} for #{card.name}"
      result = raw( sub.render(approved_view, options) )
      Renderer.current_slot = oldrenderer
      result
    end
  
    def get_inclusion_content cardname
      content = params[cardname.to_s.gsub(/\+/,'_')]
  
      # CLEANME This is a hack to get it so plus cards re-populate on failed signups
      if p = params['cards'] and card_params = p[cardname.pre_cgi]
        content = card_params['content']
      end
      content if content.present?  #not sure I get why this is necessary - efm
    end
  
    def new_inclusion_card_args options
      args = { :type =>options[:type] }
      args[:loaded_trunk]=card if options[:tname] =~ /^\+/
      if content=get_inclusion_content(options[:tname])
        args[:content]=content
      end
      args
    end
    
    def path action, opts={}
      pcard = opts.delete(:card) || card
      base = wagn_path "/card/#{action}"
      if pcard && ![:new, :create, :create_or_update].member?( action )
        base += '/' + (opts[:id] ? "~#{opts.delete(:id)}" : pcard.cardname.to_url_key)
      end
      if attrib = opts.delete( :attrib )
        base += "/#{attrib}"
      end
      query =''
      if !opts.empty?
        query = '?' + (opts.map{ |k,v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&') )
      end
      base + query
    end

    def search_params
      @search_params ||= begin
        p = self.respond_to?(:paging_params) ? paging_params : {}
        p[:vars] = {}
        if self == @root
          params.each do |key,val|
            case key.to_s
            when '_wql'      ;  p.merge! val
            when /^\_(\w+)$/ ;  p[:vars][$1.to_sym] = val
            end
          end
        end
        p
      end
    end
      
    def build_link href, text, known_card = nil
      #Rails.logger.warn "bl #{href.inspect}, #{text.inspect}, #{known_card.inspect}"
      klass = case href.to_s
        when /^https?:/; 'external-link'
        when /^mailto:/; 'email-link'
        when /^\//
          href = full_uri href.to_s
          'internal-link'
        else
          known_card = !!Card.fetch(href, :skip_modules=>true) if known_card.nil?
          if card
            text = text.to_cardname.to_show card.name
          end
          
          #href+= "?type=#{type.to_url_key}" if type && card && card.new_card?  WANT THIS; NEED TEST
          cardname = Cardname===href ? href : href.to_cardname
          href = known_card ? cardname.to_url_key : CGI.escape(cardname.escape)
          href = full_uri href.to_s
          known_card ? 'known-card' : 'wanted-card'
          
      end
      %{<a class="#{klass}" href="#{href}">#{text.to_s}</a>}
    end
    
    def unique_id() "#{card.key}-#{Time.now.to_i}-#{rand(3)}" end

    def full_uri relative_uri
      wagn_path relative_uri
    end
  
  
    # moved in from wagn_helper
    

    def formal_title card
      card.cardname.parts.join " <span class=\"wiki-joint\">+</span> "
    end

    def fancy_title card
      cardname = (Card===card ? card.cardname : card.to_cardname)
      return cardname if cardname.simple?
      raw( card_title_span(cardname.left_name) + %{<span class="joint">+</span>} + card_title_span(cardname.tag_name))
    end

    def format_date date, include_time = true
      # Must use DateTime because Time doesn't support %e on at least some platforms
      if include_time
        DateTime.new(date.year, date.mon, date.day, date.hour, date.min, date.sec).strftime("%B %e, %Y %H:%M:%S")
      else
        DateTime.new(date.year, date.mon, date.day).strftime("%B %e, %Y")
      end
    end

    ## ----- for Linkers ------------------
    def typecode_options
      Card.createable_types.map do |type_id|
        type=Card[type_id] and type=type.name and [type, type]
      end.compact
    end

    def typecode_options_for_select selected=Card.default_typecode_key
      options_from_collection_for_select(typecode_options, :first, :last, selected)
    end

    def card_title_span title
      %{<span class="namepart-#{title.to_cardname.css_name}">#{title}</span>}
    end

    def page_icon cardname
      link_to_page '&nbsp;'.html_safe, cardname, {:class=>'page-icon', :title=>"Go to: #{cardname.to_s}"}
    end
  

     ### FIXME -- this should not be here!   probably in Card::Reference model?
    def replace_references old_name, new_name
      #warn "replacing references...card name: #{card.name}, old name: #{old_name}, new_name: #{new_name}"
      wiki_content = WikiContent.new(card, card.content, self)
    
      wiki_content.find_chunks(Chunk::Link).each do |chunk|
        if chunk.cardname
          link_bound = chunk.cardname == chunk.link_text
          chunk.cardname = chunk.cardname.replace_part(old_name, new_name)
          chunk.link_text=chunk.cardname.to_s if link_bound
          #Rails.logger.info "repl ref: #{chunk.cardname.to_s}, #{link_bound}, #{chunk.link_text}"
        end
      end
    
      wiki_content.find_chunks(Chunk::Transclude).each do |chunk|
        chunk.cardname =
          chunk.cardname.replace_part(old_name, new_name) if chunk.cardname
      end
    
      String.new wiki_content.unrender!
    end

    #FIXME -- should not be here.
    def update_references rendering_result = nil, refresh = false
      return unless card && card.id
      Card::Reference.delete_all ['card_id = ?', card.id]
      card.connection.execute("update cards set references_expired=NULL where id=#{card.id}")
      card.clear_cache if refresh
      rendering_result ||= WikiContent.new(card, _render_refs, self)
      rendering_result.find_chunks(Chunk::Reference).each do |chunk|
        reference_type =
          case chunk
            when Chunk::Link;       chunk.refcard ? LINK : WANTED_LINK
            when Chunk::Transclude; chunk.refcard ? TRANSCLUSION : WANTED_TRANSCLUSION
            else raise "Unknown chunk reference class #{chunk.class}"
          end

       #ref_name=> (rc=chunk.refcardname()) && rc.to_key() || '',
        #raise "No name to ref? #{card.name}, #{chunk.inspect}" unless chunk.refcardname()
        Card::Reference.create!( :card_id=>card.id,
          :referenced_name=> (rc=chunk.refcardname()) && rc.to_key() || '',
          :referenced_card_id=> chunk.refcard ? chunk.refcard.id : nil,
          :link_type=>reference_type
         )
      end
    end
  end

  # I was getting a load error from a non-wagn file when this was in its own file (renderer/json.rb).
  class Renderer::Json < Renderer
    define_view :name_complete do |args|
      JSON( card.item_cards( :complete=>params['term'], :limit=>8, :sort=>'name', :return=>'name', :context=>'' ) )
    end
  end
  
  # automate
  Wagn::Renderer::EmailHtml
  Wagn::Renderer::Html
  Wagn::Renderer::Kml
  Wagn::Renderer::Rss
  Wagn::Renderer::Text
  
  pack_dirs = Rails.env =~ /^cucumber|test$/ ? "#{Rails.root}/lib/packs" : Wagn::Conf[:pack_dirs]
  #pack_dirs += "#{Rails.root}/lib/wagn/set/type"
  pack_dirs.split(/,\s*/).each do |dir|
    Wagn::Pack.dir File.expand_path( "#{dir}/**/*_pack.rb",__FILE__)
  end
  #Wagn::Pack.dir File.expand_path( "#{Rails.root}/lib/wagn/set/*/*.rb", __FILE__ )
  Wagn::Pack.load_all
  
end
