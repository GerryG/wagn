
require_dependency 'chunks/chunk'
require_dependency 'chunk_manager'

class ObjectContent < SimpleDelegator

  include ChunkManager

  attr_reader :revision, :card_options
  def card() @card_options[:card] end
  def renderer() @card_options[:renderer] end

  def initialize content, card_options
    @card_options = card_options
    @card_options[:card] or raise "No Card in Content!!"
    super ChunkManager.split_content(card_options, content)
  end

  #def crange(call) call[0..((i=call.index{|x|x=~/gerry/}).nil? ? 4 : i>50 ? 50 : i+5)] << " N: #{i} " end # limited caller for debugging

  def each_chunk
    return enum_for(:each_chunk) unless block_given?
    case __getobj__
      when Hash;   each { |k,v| yield v if Chunk::Abstract===v }
      when Array;  each { |e|   yield e if Chunk::Abstract===e }
      when String, NilClass; # strings are all parsed in self, so no chunks in a String
      else
        Rails.logger.warn "error self is unrecognized type #{self.class} #{self.__getobj__.class}"
    end
  end

  def to_s
    case __getobj__
    when Array;    map(&:to_s)*''
    when String;   __getobj__
    when NilClass; raise "Nil ObjContent"
    else           __getobj__.to_s
    end
  end

  def render!( revert = false, &block)
    each_chunk { |chunk| chunk.unmask_text(&block) }
    self
  end

  def unrender!() ; end
end
