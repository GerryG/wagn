#require 'cgi'
require_dependency 'chunks/chunk'
require_dependency 'chunk_manager'

class ObjectContent < Object

  include ChunkManager
  attr_reader :revision, :not_rendered, :pre_rendered, :renderer, :card

  def initialize(card, content, renderer)
    @not_rendered = @pre_rendered = nil
    @renderer = renderer
    @card = card or raise "No Card in Content!!"
    @obj = content
    super()
    split_content
    #raise "error @obj is Content type" if ObjectContent===@obj
    @not_rendered = String.new(content)
  end

  def pre_render!
    unless @pre_rendered
      @pre_rendered = @obj.clone
    end
    @pre_rendered
  end

  #def crange(call) call[0..((i=call.index{|x|x=~/gerry/}).nil? ? 4 : i>50 ? 50 : i+5)] << " N: #{i} " end # limited caller for debugging

  def to_s() String===@obj ? @obj : @obj.to_s end
  def inspect() @obj.inspect end
  def as_json(options={}) @obj.as_json end

  def each_chunk(&block)
    case @obj
    when Hash;   @obj.each { |k,v| yield v if Chunk::Abstract===v }
    when Array;  @obj.each { |e|   yield e if Chunk::Abstract===e }
    when String; return # strings are all parsed in @obj, so no chunks in a String
    else raise "error @obj is unrecognized type #{@obj.class}" # probably a warning when this is stable
    end
  end

  def render!( revert = false, &block)
    pre_render!
    each_chunk { |chnk| chnk.unmask_text(&block) }
    self
  end

  def unrender!
    render!( revert = true )
  end

  protected
  def object() @obj end
end
