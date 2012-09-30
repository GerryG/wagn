require 'cgi'
require_dependency 'chunks/chunk'
require_dependency 'chunk_manager'

class MissingChunk < StandardError; end

class ObjectContent < Object

  include ChunkManager
  attr_reader :revision, :not_rendered, :pre_rendered, :renderer, :card

  def initialize(card, content, renderer)
    @not_rendered = @pre_rendered = nil
    @renderer = renderer
    @card = card or raise "No Card in Content!!"
    @obj = content
    super()
    init_chunk_manager()
    ACTIVE_CHUNKS.each{ |chunk_type| chunk_type.apply_to(self) }
#Rails.logger.debug "wiki content init #{card.name}, C:#{content}" #\nTrace #{Kernel.caller.slice(0,6).join("\n")}"
    @not_rendered = String.new(content)
  end

  def pre_render!
    unless @pre_rendered
      @pre_rendered = @obj.clone
    end
    @pre_rendered
  end

  def each_str(&block)
    Rails.logger.warn "each str #{@obj.class}, #{@obj}"
    case @obj
    when Hash
      @obj.each { |k,v| yield v } # add yield k if you want links/trasclusions on hash keys too
    when Array
      @obj.each { |e|   yield e }
    when String
      yield @obj
    else Rails.logger.warn "other type? #{@obj.class}"
    end
  end

  def render!( revert = false, &block)
    pre_render!
    each_str do |str|
      while (str.gsub!(MASK_RE[ACTIVE_CHUNKS]) do
          chunk = @chunks_by_id[$~[1].to_i]
          chunk.nil? ? $~[0] : ( revert ? chunk.revert : chunk.unmask_text(&block) )
      end) do ; end
      @obj
    end
    self
  end

  def unrender!
    render!( revert = true )
  end

end


