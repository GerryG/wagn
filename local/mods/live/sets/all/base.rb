# -*- encoding : utf-8 -*-

view :live_titled do |args|
  "#{ _render_live_title args }\n\n#{ _render_live args.merge(:div_tag=>true)}"
end

view :live_title do |args|
  %{<div class="live-title">
      <span class="left-live-title-function live-title-function">
        <a class="ui-icon ui-icon-gear"></a></span>
      <span class="live-title">#{card.name}</span>
      <span class="right-live-title-function live-title-function">
        <a class="ui-icon ui-icon-gear"> </a>
        #{_render_live_type}
        <a class="ui-icon ui-icon-cancel"> </a>
        <a class="ui-icon ui-icon-close"> </a>
        <a class="ui-icon ui-icon-pencil"> </a>
        <a class="ui-icon ui-icon-person"> </a>
      </span>
    </div><span class="clearfix"></span>}
end

view :live_type do |args|
  no_type_change = (card.type_id == Card::CardtypeID and Card.search(:type_id=>card.id).present?) ? ' no-edit' : nil
  %{<span class="live-type">
     <span class="live-type-display">#{card.type_name}</span>
     <span class="live-type-selection#{no_type_change}" style="display:none">#{
        no_type_change ? "No type edit for #{card.name}: " : type_field(:class=>'type-field live-type-field')}</span>
  </span>}
end

view :live do |args|
  tag = args.has_key?(:div_tag) && args.delete(:div_tag) ? 'div' : 'span'
  %{<#{tag} class="live-content">#{live_divisions process_content_object(_render_raw args), args}</#{tag}>}
end

class Card::Format
  def live_divisions content, args
    Rails.logger.warn "live divs #{content.class}, #{content.length}"
    r=(content.respond_to?(:each) ? content : [content]).map do |chunk|
      Rails.logger.warn "live chunks #{chunk.class}, #{chunk}"
      case chunk
        when String; %{<span class="live-sentence live-edit">#{chunk}</span>}
        when Card::Chunk::Include; %{<span class="live-include live-edit" data-json='#{chunk.as_json.to_json}'>#{chunk}</span>}
        when Card::Chunk::Link; %{<span class="live-link live-edit" data-json="#{chunk.as_json.to_json}">#{chunk}</span>}
        else %{<span class="live-other live-edit">#{chunk}</span>}
      end
    end * ''
Rails.logger.warn %{data a:#{args.inspect}, R:#{r}}; r
  end
end
