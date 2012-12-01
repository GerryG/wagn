module Chunk
  class Reference < Abstract
    attr_accessor :cardname

    def cardname=(name)
      return @cardname=nil unless name
      @cardname = name.to_name
    end

    def refcardname()
      raise inspect if self.cardname.to_s == 'true'
      self.cardname && self.cardname = self.cardname.to_absolute(card.cardname).to_name
      Rails.logger.warn "refcardname: #{card.inspect}, cn:#{cardname} #{inspect}"; self.cardname
    end

    def refcard()
      @refcard ||= refcardname && Card.fetch(refcardname)
      Rails.logger.warn "refcard #{refcardname.inspect}, #{@refcard.inspect}"; @refcard
    end

    def link_text()
      refcardname.to_s
    end

    def render_link()
      @content.renderer.build_link(refcardname, self.link_text)
    end

  end
end



