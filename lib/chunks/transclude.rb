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
      self.cardname = parse match, params
      @base = card_params[:card]
      @renderer = card_params[:renderer]
    end

    def parse(match, params)
      name = params[1].strip
      case name
      when /^\#\#/; @unmask_text=''; nil # invisible comment
      when /^\#/||nil?||blank?; @unmask_text = "<!-- #{CGI.escapeHTML params[0]} -->"; nil
      else
        @options = {
          :tname   =>name,  # this "t" is for transclusion.  should rename
          # it is sort of transclude, this is the name for the transclusion, should still rename
          :view  => nil, :item  => nil, :type  => nil, :size  => nil,
          :hide  => nil, :show  => nil, :wild  => nil, 
          :transclude => params[0] # is this used? yes, by including this in an attrbute
                              # of an xml card, the xml parser can replace the subelements
                              # with the original transclusion notation: {{options[:transclude]}}
        }
        @configs = Hash.new_from_semicolon_attr_list params[2]
        @options[:style] = @configs.inject({}) do |s, p|; key, value = p
          @options.key?(key.to_sym) ? @options[key.to_sym] = value : s[key] = value
          s
        end.map{|k,v| CGI.escapeHTML("#{k}:#{v};")} * ''
        [:hide, :show].each do |disp|
          @options[disp] = @options[disp].split /[\s\,]+/ if @options[disp]
        end
        name
      end
    end

    def unmask_text(&block)
      return @unmask_text if @unmask_text
      refcardname
      if view = @options[:view]
        view = view.to_sym
      end
      @unmask_render = yield options # this is not necessarily text, sometimes objects for json
      #Rails.logger.warn "unmask txt #{@unmask_render}, #{options.inspect}"; @unmask_render
    end

    def replace_reference old_name, new_name
      @cardname=@cardname.replace_part old_name, new_name
      configs = @configs.to_semicolon_attr_list;
      configs = "|#{configs}" unless configs.blank?
      @text = "{{#{cardname.to_s}#{configs}}}"
    end

  end
end
