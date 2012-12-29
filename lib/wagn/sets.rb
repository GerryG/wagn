

module Wagn

  module Sets
    @@dirs = []

    module SharedMethods
      private
      def get_set_key selection_key, opts
        unless pkey = Cardlib::Pattern.method_key(opts)
          raise "bad method_key opts: #{pkey.inspect} #{opts.inspect}"
        end
        key = pkey.blank? ? selection_key : "#{pkey}_#{selection_key}"
        #warn "gvkey #{selection_key}, #{opts.inspect} R:#{key}"
        key.to_sym
      end
    end

    class << self

      def load_cardlib
        Rails.logger.warn "load cardlib #{caller[0,8]*', '}"
        load_dir File.expand_path( "#{Rails.root}/lib/cardlib/*.rb", __FILE__ )
      end

      def load_sets
        Rails.logger.warn "load sets #{caller[0,8]*', '}"
        [ "#{Rails.root}/lib/wagn/set/", Wagn::Conf[:pack_dirs].split( /,\s*/ ) ].flatten.each do |dirname|
          load_dir File.expand_path( "#{dirname}/**/*.rb", __FILE__ )
        end
      end

      def load_renderers
        Rails.logger.warn "load renderers #{caller[0,8]*', '}"
        load_dir File.expand_path( "#{Rails.root}/lib/wagn/renderer/*.rb", __FILE__ )
      end

      def all_constants base
        base.constants.map {|c| c=base.const_get(c) and all_constants(c) }
      end


      def dir newdir
        @@dirs << newdir
      end

      def load_dir dir
        Dir[dir].each do |file|
          begin
            Rails.logger.warn "load file #{file}"
            require_dependency file
          rescue Exception=>e
            Rails.logger.warn "Error loading file #{file}: #{e.message}\n#{e.backtrace*"\n"}"
            raise e
          end
        end
      end

      def load_dirs
        @@dirs.each do |dir| load_dir dir end
      end
    end

    module AllSets
      Wagn::Sets.all_constants(Wagn::Set)
    end

  end
end

require_dependency 'wagn/renderer'

module Wagn
  module Sets

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

    module ClassMethods

      include SharedMethods

      def format fmt=nil
        Renderer.renderer = if fmt.nil? || fmt == :base then Renderer else Renderer.get_renderer fmt end
      end

      def define_view view, opts={}, &final
        Renderer.perms[view]       = opts.delete(:perms)      if opts[:perms]
        Renderer.error_codes[view] = opts.delete(:error_code) if opts[:error_code]
        Renderer.denial_views[view]= opts.delete(:denial)     if opts[:denial]
        if opts[:tags]
          [opts[:tags]].flatten.each do |tag|
            Renderer.view_tags[view] ||= {}
            Renderer.view_tags[view][tag] = true
          end
        end

        view_key = get_set_key view, opts
        Renderer.renderer.class_eval { define_method "_final_#{view_key}", &final }
        #warn "defining view method[#{Renderer.renderer.inspect}] _final_#{view_key}"
        Renderer.subset_views[view] = true if !opts.empty?

        if !method_defined? "render_#{view}"
          #warn "defining view method[#{Renderer.renderer}] _render_#{view}"
          Renderer.renderer.class_eval do
            define_method( "_render_#{view}" ) do |*a|
              a = [{}] if a.empty?
              if final_method = view_method(view)
                with_inclusion_mode view do
                  send final_method, *a
                end
              else
                raise "<strong>unsupported view: <em>#{view}</em></strong>"
              end
            end
          end

          Rails.logger.warn "define_method render_#{view}"
          Renderer.renderer.class_eval do
            define_method( "render_#{view}" ) do |*a|
              begin
                send( "_render_#{ ok_view view, *a }", *a )
              rescue Exception=>e
                controller.send :notify_airbrake, e if Airbrake.configuration.api_key
                warn "Render Error: #{e.class} : #{e.message}"
                Rails.logger.info "\nRender Error: #{e.class} : #{e.message}"
                Rails.logger.debug "  #{e.backtrace*"\n  "}"
                rendering_error e, (card && card.name.present? ? card.name : 'unknown card')
              end
            end
          end
        end
      end

      def alias_view view, opts={}, *aliases
        view_key = get_set_key view, opts
        Renderer.subset_views[view] = true if !opts.empty?
        aliases.each do |alias_view|
          alias_view_key = case alias_view
            when String; alias_view
            when Symbol; (view_key==view ? alias_view.to_sym : view_key.to_s.sub(/_#{view}$/, "_#{alias_view}").to_sym)
            when Hash;   get_set_key alias_view[:view] || view, alias_view
            else; raise "Bad view #{alias_view.inspect}"
            end

            Rails.logger.warn "def view final_alias #{alias_view_key}, #{view_key}"
            Renderer.renderer.class_eval { define_method( "_final_#{alias_view_key}".to_sym ) do |*a|
            send "_final_#{view_key}", *a
          end }
        end
      end
    end

    def self.included base

      #base.extend CardControllerMethods
      base.extend SharedMethods
      base.extend ClassMethods

      super

    end
  end
end


