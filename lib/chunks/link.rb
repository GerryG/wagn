module Chunk
  class Link < Reference
    attr_accessor :link_text, :link_type

    word = /\s*([^\]\|]+)\s*/
    # Groups: $1, [$2]: [[$1]] or [[$1|$2]] or $3, $4: [$3][$4] 
    WIKI_LINK = /\[\[#{word}(?:\|#{word})?\]\]|\[#{word}\]\[#{word}\]/

    def self.pattern() WIKI_LINK end

    def initialize match, card_params, params
      super
      link_type = :show
      if name=params[0]
        self.cardname = name.to_cardname
        @link_text = params[1] || name
      else
        @link_text = params[2]; self.cardname = params[3].to_cardname #.gsub(/_/,' ')
      end
      self
    end

    def unmask_text
      @unmask_text ||= render_link
    end

    def revert
      @text = cardname == link_text ? "[[#{cardname.to_s}]]" : "[[#{cardname.to_s}|#{link_text}]]"
      super
    end

  end
end
