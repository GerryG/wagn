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
    ACTIVE_CHUNKS =
      [ Literal::Escape, Chunk::Transclude, Chunk::Link, URIChunk, LocalURIChunk ]

    MASK_RE = {
      ACTIVE_CHUNKS => Chunk::Abstract.mask_re(ACTIVE_CHUNKS)
    }

    SCAN_RE = {
      ACTIVE_CHUNKS => Chunk::Abstract.unmask_re(ACTIVE_CHUNKS)
    }
  end

  def init_chunk_manager
    @chunks_by_type = Hash.new
    ACTIVE_CHUNKS.each{|chunk_type|
      @chunks_by_type[chunk_type] = Array.new
    }
    @chunks_by_id = Hash.new
    @chunks = []
    @chunk_id = 0
  end

  # for objet_content, it uses this instead of the apply_to by chunk type
  def self.split_content card_params, content
    if String===content and !(arr = content.to_s.scan SCAN_RE[ACTIVE_CHUNKS]).empty?
      remainder = $'
      content = arr.map do |match_arr|
          pre_chunk = match_arr.shift; match = match_arr.shift
          match_index = match_arr.index {|x| !x.nil? }
          chunk_class, range = Chunk::Abstract.re_class(match_index)
          chunk_params = match_arr[range]
          newck = chunk_class.new match, card_params, chunk_params
          pre_chunk.nil? || pre_chunk=='' ? newck : [pre_chunk, newck]
        end.flatten.compact
      content << remainder if remainder.to_s != ''
    end
    content
  end

  def add_chunk chunk
    @chunks_by_type[chunk.class] << chunk
    @chunks_by_id[chunk.object_id] = chunk
    @chunks << chunk
    @chunk_id += 1
  end

  def delete_chunk chunk
    @chunks_by_type[chunk.class].delete chunk
    @chunks_by_id.delete chunk.object_id
    @chunks.delete chunk
  end

  def merge_chunks other
    other.chunks.each{|chunk| add_chunk(chunk)}
  end

  def scan_chunkid text
    text.scan(MASK_RE[ACTIVE_CHUNKS]){|a| yield a[0] }
  end

  def find_chunks chunk_type
    each_chunk.select { |chunk| chunk.kind_of?(chunk_type) }
  end
end
