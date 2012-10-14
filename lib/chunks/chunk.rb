require 'uri/common'

# A chunk is a pattern of text that can be protected
# and interrogated by a renderer. Each Chunk class has a
# +pattern+ that states what sort of text it matches.
# Chunks are initalized by passing in the result of a
# match by its pattern.

module Chunk
  class Abstract
    # the class name part of the mask strings
    def self.mask_string
      self.to_s.delete(':').downcase
    end

    # a regexp that matches all chunk_types masks
    def Abstract::mask_re chunk_types
      chunk_classes = chunk_types.map(&:mask_string)*"|"
      /chunk(-?\d+)(#{chunk_classes})chunk/
    end

    def Abstract::re_class(index)
      @@paren_range.each do |chunk_class, range|
        if range.cover? index
          return chunk_class, range
        end
      end
      raise "not found #{index}, #{@@paren_range.inspect}"
    end

    def Abstract::unmask_re(chunk_types)
      @@paren_range = {}
      pindex = 0
      chunk_pattern = chunk_types.map do |ch_class|
        pend = pindex + ch_class.groups
        @@paren_range[ch_class] = pindex..pend-1
        pindex = pend
        ch_class.pattern
      end * '|'
      /(.*?)(#{chunk_pattern})/m
    end

    attr_reader :text, :unmask_text

    def initialize match_string, card_params, params
      #Rails.logger.warn "chunk init M:#{match_string}, C:#{card_params.inspect}, P:#{params.inspect}"
      @text = match_string
      @unmask_render = nil
      @card_params = card_params
    end
    def renderer() @card_params[:renderer] end
    def card() @card_params[:card] end

    def to_s
      @unmask_text || @unmask_render|| @text
    end

    # Find all the chunks of the given type in content
    # Each time the pattern is matched, create a new
    # chunk for it, and replace the occurance of the chunk
    # in this content with its mask.
    def self.apply_to content
      content.gsub!( self.pattern ) do |match|
        chk_params = $~.to_a; mch = chk_params.shift
        new_chunk = self.new(mch, {:card=>content.card, :renderer=>content.renderer}, chk_params)
        content.add_chunk new_chunk
        new_chunk.mask
      end
    end

    # should contain only [a-z0-9]
    def mask
      @mask ||= "chunk#{self.object_id}#{self.class.mask_string}chunk"
    end

    def as_json(options={})
      @unmask_text || @unmask_render|| "not rendered #{self.class}, #{card and card.name}"
    end

    def revert
      @text
    end
  end

end

