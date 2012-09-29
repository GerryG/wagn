require 'cgi'
require_dependency 'chunks/chunk'
require_dependency 'chunk_manager'

class MissingChunk < StandardError; end

class WikiContent < String
  class << self
  ## FIXME:  this is still not quite the right place for clean_html!
  ##  but it's better than the general string extension library where it was before.

  ## Dictionary describing allowable HTML
  ## tags and attributes.
    BASIC_TAGS = {
      'a' => ['href' ],
      'img' => ['src', 'alt', 'title'],
      'br' => [],
      'i'  => [],
      'b'  => [],
      'pre'=> [],
      'code' => ['lang'],
      'cite'=> [],
      'strong'=> [],
      'em'  => [],
      'ins' => [],
      'sup' => [],
      'sub' => [],
      'del' => [],
      'ol' => [],
      'hr' => [],
      'ul' => [],
      'li' => [],
      'p'  => [],
      'div'=> [],
      'h1' => [],
      'h2' => [],
      'h3' => [],
      'h4' => [],
      'h5' => [],
      'h6' => [],
      'blockquote' => ['cite'],
      'span'=>[],
      'table'=>[],
      'tr'=>[],
      'td'=>[],
      'th'=>[],
      'tbody'=>[],
      'thead'=>[],
      'tfoot'=>[]
    }

    BASIC_TAGS.each_key {|k| BASIC_TAGS[k] << 'class' }

      ## Method which cleans the String of HTML tags
      ## and attributes outside of the allowed list.

      # this has been hacked for wagn to allow classes in spans if
      # the class begins with "w-"
    def clean_html!( string, tags = BASIC_TAGS )
      string.gsub!( /<(\/*)(\w+)([^>]*)>/ ) do
        raw = $~
        tag = raw[2].downcase
        if tags.has_key? tag
          pcs = [tag]
          tags[tag].each do |prop|
            ['"', "'", ''].each do |q|
              q2 = ( q != '' ? q : '\s' )
              if prop=='class'
                if raw[3] =~ /#{prop}\s*=\s*#{q}(w-[^#{q2}]+)#{q}/i
                  pcs << "#{prop}=\"#{$1.gsub('"', '\\"')}\""
                  break
                end
              elsif raw[3] =~ /#{prop}\s*=\s*#{q}([^#{q2}]+)#{q}/i
                pcs << "#{prop}=\"#{$1.gsub('"', '\\"')}\""
                break
              end
            end
          end if tags[tag]
          "<#{raw[1]}#{pcs.join " "}>"
        else
          " "
        end
      end
      string.gsub!(/<\!--.*?-->/, '')
      string
    end
  end

  include ChunkManager
  attr_reader :revision, :not_rendered, :pre_rendered, :renderer, :card

  def initialize(card, content, renderer)
    @not_rendered = @pre_rendered = nil
    @renderer = renderer
    @card = card or raise "No Card in Content!!"
    super(content)
    init_chunk_manager()
    ACTIVE_CHUNKS.each{|chunk_type| chunk_type.apply_to(self)}
#Rails.logger.debug "wiki content init #{card.name}, C:#{content}" #\nTrace #{Kernel.caller.slice(0,6).join("\n")}"
    @not_rendered = String.new(self)
  end

  def pre_render!
    unless @pre_rendered
      @pre_rendered = String.new(self)
    end
    @pre_rendered
  end

  def render_array(&block)
    raise "need black? " if block.nil?
    pre_render!
    array = split(MASK_RE[ACTIVE_CHUNKS])
    c=nil
    r=(array.inject([[], false]) do |i, next_chunk| out, is_ch = i
      nexti = (is_ch ?  [out, false] : (next_chunk =~ /\D/ ?  [out << next_chunk, false] :
        [(out << (c=@chunks_by_id[next_chunk.to_i].as_json_unmask(&block))), true]))
        #[out << JSON.parse!(@chunks_by_id[next_chunk.to_i].unmask_text(&block)), true]
      Rails.logger.warn "ra Sk:#{is_ch}, #{next_chunk.class}, #{(next_chunk !~ /\D/) && @chunks_by_id[next_chunk.to_i].class.mask_string}, C:#{c.class}, #{c.inspect} l:#{out.length} next:#{nexti[0].length}, #{nexti[1]}"; nexti
    end)
    Rails.logger.warn "rend arr #{r.inspect}, 0>> #{r[0].inspect}"
    r[0]
  end

  def render!( revert = false, &block)
    pre_render!
    while (gsub!(MASK_RE[ACTIVE_CHUNKS]) do
       chunk = @chunks_by_id[$~[1].to_i]
       chunk.nil? ? $~[0] : ( revert ? chunk.revert : chunk.unmask_text(&block) )
      end)
    end
    self
  end

  def unrender!
    render!( revert = true )
  end

end


