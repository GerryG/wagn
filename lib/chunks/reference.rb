module Chunk
  class Reference < Abstract
    attr_accessor :cardname

    def cardname=(name)
      return @cardname=nil unless name
      @cardname = name.to_name
    end

    def refcardname()
      #warn "rercardname #{inspect}, #{cardname.to_absolute(card.cardname)}"
      cardname && self.cardname = cardname.to_absolute(card.cardname).to_name
    end

    def refcard()
      @refcard ||= refcardname && Card.fetch(refcardname)
      Rails.logger.warn "refcard #{refcardname.inspect}, #{@refcard.inspect}"; @refcard
    end

    def ref_text()
      refcardname.to_s
    end

    def render_link()
      @content.renderer.build_link(refcardname, self.ref_text)
    end

  end
end



