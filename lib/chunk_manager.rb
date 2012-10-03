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
#      Literal::Pre,
      Literal::Escape => 1,
      Chunk::Transclude => 3,
      Chunk::Link => 4,
      URIChunk => 1,
      LocalURIChunk  => 1,
    }

    # will we maybe need this again or should we simplify this now?
#    HIDE_CHUNKS = [ Literal::Pre, Literal::Tags ]

    MASK_RE = {
#      HIDE_CHUNKS => Chunk::Abstract.mask_re(HIDE_CHUNKS),
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
  def self.split_content(content)
    #Rails.logger.info "split_content S: #{SCAN_RE[ACTIVE_CHUNKS].inspect}, #{content.class} #{content.to_s[0..20]}" #unless String===content
    #SCAN_RE[ACTIVE_CHUNKS].match(content) do |m|
    arr = content.to_s.scan SCAN_RE[ACTIVE_CHUNKS]
    arr = arr.map do |match_arr|
      pre_chunk = match_arr.shift; match = match_arr.shift
      match_index = match_arr.index {|x| !x.nil? }
      chunk_class, range = Chunk::Abstract.re_class(match_index)
      chunk_params = match_arr[range]
      [pre_chunk, chunk_class.new(match, content, chunk_params) ]
    end.flatten.compact
    #Rails.logger.info "split_content R:#{arr.class} #{arr.to_s[0..20]}"; arr
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
