
require_dependency 'chunks/chunk'
require_dependency 'chunk_manager'

class ObjectContent < SimpleDelegator

  include ChunkManager
  attr_reader :revision, :not_rendered, :pre_rendered, :card_options

  def initialize content, card_options
    @card_options = card_options
    @card_options[:card] or raise "No Card in Content!!"
    @not_rendered = @pre_rendered = nil
    raise "type #{content.class}" if ObjectContent===content
    super ChunkManager.split_content(card_options, content)
    @not_rendered = String.new(content)
  end
  def card() @card_options[:card] end
  def renderer() @card_options[:renderer] end

  def pre_render!
    unless @pre_rendered
      @pre_rendered = self.clone
    end
    @pre_rendered
  end

  #def crange(call) call[0..((i=call.index{|x|x=~/gerry/}).nil? ? 4 : i>50 ? 50 : i+5)] << " N: #{i} " end # limited caller for debugging

  #def to_s() String===self ? self : self.to_s end
  #def inspect() self.inspect end
  #def as_json(options={}) self.as_json end

  def each_chunk(&block)
    case __getobj__
    when Hash;   each { |k,v| yield v if Chunk::Abstract===v }
    when Array;  each { |e|   yield e if Chunk::Abstract===e }
    when String; return # strings are all parsed in self, so no chunks in a String
    else raise "error self is unrecognized type #{self.class} #{self.delegate_class}" # probably a warning when this is stable
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

  def delegate_class() __getobj__.class end
end
