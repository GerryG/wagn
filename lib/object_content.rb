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

  def crange(call) call[0..((i=call.index{|x|x=~/gerry/}).nil? ? 4 : i>50 ? 50 : i+5)] << " N: #{i} " end

  def to_s() @obj.to_s end
  def inspect() @obj.inspect end
  def as_json(options={}) @obj.as_json end

  def each_chunk(&block)
    case @obj
    when Hash
      @obj.each { |k,v| yield v if Chunk::Abstract===v }
    when Array
      @obj.each { |e| yield e if Chunk::Abstract===e }
    when   Chunk::Abstract
      yield @obj
    end
  end

  def render!( revert = false, &block)
    pre_render!
    each_chunk do |chnk| chnk.unmask_text(&block) end
  end

  def unrender!
    render!( revert = true )
  end

end


