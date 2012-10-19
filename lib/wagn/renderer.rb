module Wagn
  class Renderer
    include LocationHelper

    DEPRECATED_VIEWS = { :view=>:open, :card=>:open, :line=>:closed, :bare=>:core, :naked=>:core }
    INCLUSION_MODES  = { :main=>:main, :closed=>:closed, :closed_content=>:closed, :edit=>:edit,
      :layout=>:layout, :new=>:edit, :normal=>:normal, :template=>:template } #should be set in views
    DEFAULT_ITEM_VIEW = :link  # should be set in card?

    RENDERERS = { #should be defined in renderer
      :html => :Html,
      :json => :JsonRenderer,
      :xml  => :Xml,
      :css  => :Text,
      :txt  => :Text
    }

    cattr_accessor :current_slot, :ajax_call

    @@max_char_count = 200 #should come from Wagn::Conf
    @@max_depth      = 10 # ditto
    @@perms          = {}
    @@subset_views   = {}
    @@error_codes    = {}
    @@view_tags      = {}

    class << self
      def new card, opts={}
        if self==Renderer
          fmt = opts[:format] = (opts[:format] ? opts[:format].to_sym : :html)
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
        @@perms[view]       = opts.delete(:perms)      if opts[:perms]
        @@error_codes[view] = opts.delete(:error_code) if opts[:error_code]
        if opts[:tags]
          [opts[:tags]].flatten.each do |tag|
            @@view_tags[view] ||= {}
            @@view_tags[view][tag] = true
          end
        end

        view_key = get_view_key(view, opts)
        define_method "_final_#{view_key}", &final
        #warn "defining method _final_#{view_key}"
        @@subset_views[view] = true if !opts.empty?

        if !method_defined? "render_#{view}"
          define_method( "_render_#{view}" ) do |*a|
            a = [{}] if a.empty?
            if final_method = view_method(view)
              with_inclusion_mode view do
                send final_method, *a
              end
            else
              "<strong>unsupported view: <em>#{view}</em></strong>"
            end
          end

          define_method( "render_#{view}" ) do |*a|
            begin
              send( "_render_#{ ok_view view, *a }", *a )
            rescue Exception=>e
              controller.send :notify_airbrake, e if Airbrake.configuration.api_key
              Rails.logger.info "\nRender Error: #{e.class} : #{e.message}"
              Rails.logger.debug "  #{e.backtrace*"\n  "}"
              rendering_error e, (card && card.name.present? ? card.name : 'unknown card')
            end
          end
        end
      end

      def alias_view view, opts={}, *aliases
        view_key = get_view_key(view, opts)
        @@subset_views[view] = true if !opts.empty?
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


    attr_reader :format, :card, :root, :parent
    attr_accessor :form, :main_content, :error_status

    def render view = :view, args={}
      prefix = args[:allowed] ? '_' : ''
      method = "#{prefix}render_#{canonicalize_view view}"
      if respond_to? method
        send method, args
      else
        #Rails.logger.warn "bad view #{view.inspect}, #{self.class}"
        "<strong>unknown view: <em>#{view}</em></strong>"
      end
    end

    def _render view, args={}
      args[:allowed] = true
      render view, args
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

      @context_names = []
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
    def showname()     @showname   ||= card.name                                  end

    def main?
      if ajax_call?
        @depth == 0 && params[:is_main]
      else
        @depth == 1 && @mode == :main
      end
    end

    def focal? # meaning the current card is the requested card
      if ajax_call?
        @depth == 0
      else
        main?
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

    def subrenderer subcard, opts={}
      subcard = Card.fetch_or_new(subcard) if String===subcard
      sub = self.clone
      sub.initialize_subrenderer subcard, self, opts
    end


    def initialize_subrenderer subcard, parent, opts
      @parent=parent
      @card = subcard
      @char_count = 0
      @depth += 1
      @item_view = @main_content = @showname = nil
      opts.each { |key, value| instance_variable_set "@#{key}", value }
      #Rails.logger.warn "subrenderer inited #{card && card.name} #{opts.inspect}, iv:#{@item_view}, #{@item}, #{@view}"
      self
    end

    def process_content_s content=nil, opts={}
      process_content(content, opts).to_s
    end

    def process_content content=nil, opts={}
      return content unless card
      content = card.content if content.blank?

      obj_content = ObjectContent===content ? content : ObjectContent.new(content, {:card=>card, :renderer=>self})
      card.update_references( obj_content, true ) if card.references_expired # I thik we need this genralized

      obj_content.process_content do |opts|
        expand_inclusion(opts) { yield }
      end
    end


    def tagged view, tag
      @@view_tags[view] && @@view_tags[view][tag]
    end

    def ok_view view, args={}
      original_view = view

      view = case
        when @depth >= @@max_depth   ; :too_deep
        # prevent recursion.  @depth tracks subrenderers (view within views)
        when @@perms[view] == :none  ; view
        # This may currently be overloaded.  always allowed = skip moodes = never modified.  not sure that's right.
        when !card                   ; :no_card
        # This should disappear when we get rid of admin and account controllers and all renderers always have cards

        # HANDLE UNKNOWN CARDS ~~~~~~~~~~~~
        when !card.known? && !tagged( view, :unknown_ok )
          if focal?
            if @format==:html && card.ok?(:create) ;  :new
            else                                   ;  :not_found
            end
          else                                     ;  :missing
          end

        # CHECK PERMISSIONS  ~~~~~~~~~~~~~~~~
        else
          perms_required = @@perms[view] || :read
          if Proc === perms_required
            perms_required.call self
          else
            args[:denied_task] = [perms_required].flatten.find do |task|
              task = :create if task == :update && card.new_card?
              !card.ok? task
            end
            args[:denied_task] ? :denial : view
          end
        end


      if view != original_view
        args[:denied_view] = original_view

        if focal? && error_code = @@error_codes[view]
          root.error_status = error_code
        end
      end
      view
    end

    def canonicalize_view view
      unless view.blank?
        DEPRECATED_VIEWS[view.to_sym] || view.to_sym
      end
    end

    def view_method view
      return "_final_#{view}" if !card || !@@subset_views[view]
      card.method_keys.each do |method_key|
        meth = "_final_"+(method_key.blank? ? "#{view}" : "#{method_key}_#{view}")
        #Rails.logger.info "looking up #{meth} for #{card.name}"
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
      case
      when opts.has_key?( :comment )                            ; opts[:comment]     # as in commented code
      when @mode == :closed && @char_count > @@max_char_count   ; ''                 # already out of view
      when opts[:tname]=='_main' && !ajax_call? && @depth==0    ; expand_main opts
      else
        fullname = opts[:tname].to_cardname.to_absolute card.cardname, :params=>params
        included_card = Card.fetch_or_new fullname, ( @mode==:edit ? new_inclusion_card_args(opts) : {} )

        result = process_inclusion included_card, opts
        @char_count += result.length if result
        result
      end
    end

    def expand_main opts
      return wrap_main( @main_content ) if @main_content
      [:item, :view, :size].each do |key|
        if val=params[key] and val.to_s.present?
          opts[key] = val.to_sym   #to sym??  why??
        end
      end
      opts[:view] = @main_view || opts[:view] || :open #FIXME configure elsewhere
      opts[:tname] = root.card.name
      with_inclusion_mode :main do
        wrap_main process_inclusion( root.card, opts )
      end
    end

    def wrap_main content
      content  #no wrapping in base renderer
    end

    def process_inclusion tcard, opts
      opts[:showname] = if opts[:tname]
        opts[:tname].to_cardname.to_show card.cardname, :ignore=>@context_names, :params=>params
      else
        tcard.name
      end

      sub_opts = { :item_view =>opts[:item] }
      [:type, :size, :showname ].each { |key| sub_opts[key] = opts[key] }
      sub = subrenderer tcard, sub_opts

      oldrenderer, Renderer.current_slot = Renderer.current_slot, sub
      # don't like depending on this global var switch
      # I think we can get rid of it as soon as we get rid of the remaining rails views?


      view = canonicalize_view opts.delete :view
      view ||= ( @mode == :layout ? :core : :content )  #set defaults elsewhere!!

      opts[:home_view] = [:closed, :edit].member?(view) ? :open : view
      # FIXME: special views should be represented in view definitions

      unless @@perms[view] == :none
        view = case @mode

          when :closed   ;  !tcard.known?  ? :closed_missing : :closed_content
          when :edit     ;  tcard.virtual? ? :edit_virtual   : :edit_in_form
          when :template ;  :template_rule
          # FIXME should be concerned about templateness, not virtualness per se
          # needs to handle real cards that are hard templated much better
          else           ;  view
          end
      end

      result = sub.render(view, opts)
      Renderer.current_slot = oldrenderer
      result
    end

    def get_inclusion_content cardname
      content = params[cardname.to_s.gsub(/\+/,'_')]

      # CLEANME This is a hack to get it so plus cards re-populate on failed signups
      if p = params['cards'] and card_params = p[cardname.pre_cgi]
        content = card_params['content']
      end
      content if content.present?  # why is this necessary? - efm
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
      base = action==:read ? '' : "/card/#{action}"

      if pcard && !pcard.name.empty? && !opts.delete(:no_id) && action != :create #might be some issues with new?
        base += '/' + ( opts[:id] ? "~#{ opts.delete :id }" : pcard.cardname.url_key )
      end
      if attrib = opts.delete( :attrib )
        base += "/#{attrib}"
      end
      query =''
      if !opts.empty?
        query = '?' + ( opts.map{ |k,v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&') )
      end
      wagn_path( base + query )
    end

    def search_params
      @search_params ||= begin
        p = self.respond_to?(:paging_params) ? paging_params : { :default_limit=> 100 }
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
      # Rails.logger.info( "~~~~~~~~~~~~~~~ bl #{href.inspect}, #{text.inspect}, #{known_card.inspect}" )
      klass = case href.to_s
        when /^https?:/; 'external-link'
        when /^mailto:/; 'email-link'
        when /^\//
          href = full_uri href.to_s
          'internal-link'
        else
          known_card = !!Card.fetch(href, :skip_modules=>true) if known_card.nil?
          if card
            text = text.to_cardname.to_show card.name, :ignore=>@context_names
          end

          href = full_uri href.to_cardname.url_key
          #href+= "?type=#{type.url_key}" if type && card && card.new_card?  WANT THIS; NEED TEST
          known_card ? 'known-card' : 'wanted-card'

      end
      %{<a class="#{klass}" href="#{href}">#{text.to_s}</a>}
    end

    def unique_id() "#{card.key}-#{Time.now.to_i}-#{rand(3)}" end

    def full_uri relative_uri
      wagn_path relative_uri
    end

    def format_date date, include_time = true
      # Must use DateTime because Time doesn't support %e on at least some platforms
      if include_time
        DateTime.new(date.year, date.mon, date.day, date.hour, date.min, date.sec).strftime("%B %e, %Y %H:%M:%S")
      else
        DateTime.new(date.year, date.mon, date.day).strftime("%B %e, %Y")
      end
    end

    def add_name_context name=nil
      name ||= card.name
      @context_names += name.to_cardname.parts
      @context_names.uniq!
    end
  end

  class Renderer::Csv < Renderer::Text
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
