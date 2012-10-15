module Chunk
  class Transclude < Reference
    attr_reader :stars, :renderer, :options, :base
    unless defined? TRANSCLUDE_PATTERN
      #  {{+name|attr:val;attr:val;attr:val}}
      #  Groups: $1, everything (less {{}}), $2 name, $3 options
      TRANSCLUDE_PATTERN = /\{\{(([^\|]+?)\s*(?:\|([^\}]+?))?)\}\}/
      TRANSCLUDE_GROUPS = 3
    end

    def self.pattern() TRANSCLUDE_PATTERN end
    def self.groups() TRANSCLUDE_GROUPS end

    def initialize match, card_params, params
      super
      self.cardname, @options, @configs = a = self.class.parse(match, params)
      @base = card_params[:card]
      @renderer = card_params[:renderer]
    end

    def self.parse(match, params)
      name = params[1].strip
      case name
      when /^\#\#/; return [nil, {:comment=>''}] # invisible comment
      when /^\#/||nil?||blank?  # visible comment
        return [nil, {:comment=>"<!-- #{CGI.escapeHTML params[0]} -->"}]
      end
      options = {
        :tname   =>name,  # this "t" is for transclusion.  should rename

        :view  => nil,
        :item  => nil,
        :type  => nil,
        :size  => nil,

        :hide  => nil,
        :show  => nil,
        :wild  => nil,

        :unmask => params[0] # is this used? yes, by including this in an attrbute
                            # of an xml card, the xml parser can replace the subelements
                            # with the original transclusion notaion: {{options[:unmask]}}
        # looking at the code, it maybe could be used, but isn't.  The xmlparser looks for
        # a 'transclude' attribute, which should be '{{options[:unmask]}}', but nothing
        # does this yet.  The xmlparser falls back to {{name}} where name is the 'name'
        # attribute value.
      }
      style = {}
      configs = Hash.new_from_semicolon_attr_list params[2]
      configs.each_pair do |key, value|
        if options.key? key.to_sym
          options[key.to_sym] = value
        else
          style[key] = value
        end
      end
      [:hide, :show].each do |disp|
        if options[disp]
          options[disp] = options[disp].split /[\s\,]+/
        end
      end
      options[:style] = style.map{|k,v| CGI.escapeHTML("#{k}:#{v};")}.join
      [name, options, configs]
    end

    def unmask_text(&block)
      return @unmask_text if @unmask_text
      comment = @options[:comment]
      return @unmask_text=comment if comment
      refcardname
      if view = @options[:view]
        view = view.to_sym
      end
      @unmask_render = yield options # this is not necessarily text, sometimes objects for json
      #Rails.logger.warn "unmask txt #{@unmask_render}, #{options.inspect}"; @unmask_render
    end

    def revert
      configs = @configs.to_semicolon_attr_list;
      configs = "|#{configs}" unless configs.blank?
      @text = "{{#{cardname.to_s}#{configs}}}"
      super
    end

    def replace_reference old_name, new_name
      @cardname=@cardname.replace_part old_name, new_name
      revert
    end 
  end
end
