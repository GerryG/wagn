module Chunk
  class Link < Reference
    word = /\s*([^\]\|]+)\s*/
    # Groups: $1, [$2]: [[$1]] or [[$1|$2]] or $3, $4: [$3][$4]
    WIKI_LINK = /\[\[#{word}(?:\|#{word})?\]\]|\[#{word}\]\[#{word}\]/
    WIKI_LINK_GROUPS = 4

    def self.pattern() WIKI_LINK end
    def self.groups() WIKI_LINK_GROUPS end

    attr_accessor :link_text

    def initialize match, card_params, params
      super
      if name=params[0]
        self.cardname = name.to_cardname
        ltext=params[1]
        self.link_text= ltext.nil? ? name :
          ltext =~ /(^|[^\\]){{/ ? ObjectContent.new(ltext, @card_params) : ltext
      else
        self.link_text= params[2]; self.cardname = params[3].to_cardname #.gsub(/_/,' ')
      end
      self
    end

    def unmask_text
      @unmask_text ||= render_link
    end

    def revert
      @text = self.link_text.nil? || cardname == self.link_text ? "[[#{cardname.to_s}]]" : "[[#{cardname.to_s}|#{self.link_text}]]"
      #Rails.logger.warn "revert link #{@text} #{cardname.to_s}, #{self.link_text}"
      super
    end

    def replace_reference old_name, new_name
      @cardname=@cardname.replace_part old_name, new_name if @cardname
      if ObjectContent===self.link_text
        self.link_text.find_chunks(Chunk::Reference).each {|chunk| chunk.replace_reference old_name, new_name}
      else
        self.link_text = new_name if old_name == self.link_text
      end
      revert
    end
  end
end
