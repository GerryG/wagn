require_dependency 'chunks/chunk'
require_dependency 'chunks/uri'
require_dependency 'chunks/literal'
require_dependency 'chunks/reference'
require_dependency 'chunks/link'
require_dependency 'chunks/transclude'


module ChunkManager
  attr_reader :chunks_by_type, :chunks_by_id, :chunks, :chunk_id
  unless defined? ACTIVE_CHUNKS
    # value is number of paren groups in the SCAN_RE
    ACTIVE_CHUNKS = {
      Literal::Escape => 2,
      Chunk::Transclude => 3,
      Chunk::Link => 4,
      URIChunk => 8,
      LocalURIChunk  => 8
    }

    MASK_RE = {
      ACTIVE_CHUNKS => Chunk::Abstract.mask_re(ACTIVE_CHUNKS.keys)
    }

    SCAN_RE = {
       ACTIVE_CHUNKS => Chunk::Abstract.unmask_re(ACTIVE_CHUNKS)
    }
  end

  def init_chunk_manager
    @chunks_by_type = Hash.new
    ACTIVE_CHUNKS.keys.each{|chunk_type|
      @chunks_by_type[chunk_type] = Array.new
    }
    @chunks_by_id = Hash.new
    @chunks = []
    @chunk_id = 0
  end

  # for objet_content, it uses this instead of the apply_to by chunk type
  def self.split_content card_params, content
    if String===content
      return if (arr = content.to_s.scan SCAN_RE[ACTIVE_CHUNKS]).empty?
      #Rails.logger.warn "scan arr: #{arr.size}, #{arr.map(&:size)*', '}, AR:#{arr.inspect}"
      content = arr.map do |match_arr|
          pre_chunk = match_arr.shift; match = match_arr.shift
          match_index = match_arr.index {|x| !x.nil? }
          chunk_class, range = Chunk::Abstract.re_class(match_index)
          chunk_params = match_arr[range]
          Rails.logger.warn "scan map #{match_index.inspect}, #{chunk_class}, #{chunk_params.inspect}"
          newck = chunk_class.new match, card_params, chunk_params
          pre_chunk.nil? || pre_chunk.blank? ? newck : [pre_chunk, newck]
        end.flatten.compact
    else content end
    #Rails.logger.info "split_content R:#{@obj.class} #{@obj.to_s[0..60]}"; @obj
  end

  def add_chunk(c)
    @chunks_by_type[c.class] << c
    @chunks_by_id[c.object_id] = c
    @chunks << c
    @chunk_id += 1
  end

  def delete_chunk(c)
    @chunks_by_type[c.class].delete(c)
    @chunks_by_id.delete(c.object_id)
    @chunks.delete(c)
  end

  def merge_chunks(other)
    other.chunks.each{|c| add_chunk(c)}
  end

  def scan_chunkid(text)
    text.scan(MASK_RE[ACTIVE_CHUNKS]){|a| yield a[0] }
  end

  def find_chunks(chunk_type)
    @chunks.select { |chunk| chunk.kind_of?(chunk_type) and chunk.rendered? }
  end

end
