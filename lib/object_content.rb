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
    @obj = ChunkManager.split_content(self)
    @not_rendered = String.new(content)
  end

  def pre_render!
    unless @pre_rendered
      @pre_rendered = @obj.clone
    end
    @pre_rendered
  end

  def to_s() @obj.to_s end
  def inspect() @obj.inspect end
  #def to_a() @obj.to_a end

  def each_str(&block)
    case @obj
    when Hash
      @obj.each { |k,v| yield v } # add yield k if you want links/trasclusions on hash keys too
    when Array
      @obj.each { |e|   yield e }
    when Object
      yield @obj
    else raise "unknown type? #{@obj.class}" # this is impossible, right?
    end
  end

  def render!( revert = false, &block)
    pre_render!
    each_str do |str|
      next if str.nil?
=begin
      while (str.gsub!(MASK_RE[ACTIVE_CHUNKS]) do
          chunk = @chunks_by_id[$~[1].to_i]
          chunk.nil? ? $~[0] : ( revert ? chunk.revert : chunk.unmask_text(&block) )
      end) do ; end
      @obj
=end
      Rails.logger.warn "rd str:#{str.class} #{str.inspect}"
      str
    end
    self
  end

  def unrender!
    render!( revert = true )
  end

end


