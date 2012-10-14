require 'cgi'
require_dependency 'chunks/chunk'
require_dependency 'chunk_manager'

class MissingChunk < StandardError; end

class WikiContent < String
  include ChunkManager
  attr_reader :revision, :not_rendered, :pre_rendered, :renderer, :card

  def initialize content, card_options
    @not_rendered = @pre_rendered = nil
    @renderer = card_options[:renderer]
    @card = card_options[:card] or raise "No Card in Content!!"
    super(content)
    init_chunk_manager()
    ACTIVE_CHUNKS.each do |chunk_type|
      chunk_type.apply_to(self)
    end
    @not_rendered = String.new(self)
  end

  def pre_render!
    unless @pre_rendered
      @pre_rendered = String.new(self)
    end
    @pre_rendered
  end

  def render!( revert = false, &block)
    pre_render!
    while (gsub!(MASK_RE[ACTIVE_CHUNKS]) do
          chunk = @chunks_by_id[$~[1].to_i]
          r=
          (chunk.nil? ? $~[0] : ( revert ? chunk.revert : (r1=chunk.unmask_text(&block)) ))
          Rails.logger.warn "r! #{chunk.class}, #{chunk}, r1:#{r1}, r:#{r}";r
    end) do ; end
    self
  end

  def unrender!
    render!( revert = true )
  end

  def each_chunk() @chunks.enum_for(:each) end
end


