Wagn::Renderer::JsonRenderer

class Wagn::Renderer::JsonRenderer < Wagn::Renderer
  define_view(:layout) do |args|
    if @main_content = args.delete(:main_content)
      @card = Card.fetch_or_new('*placeholder',{},:skip_defaults=>true)
    else
      @main_card = card
    end  

    layout_content = get_layout_content(args)
    
    args[:context] = self.context = "layout_0"
    args[:action]="view"  
    args[:relative_content] = args[:params] = params 
    
    process_content(layout_content, args)
  end

  define_view :core_array do |args|
    content_array _render_raw
  end

  # I was getting a load error from a non-wagn file when this was in its own file (renderer/json.rb).
  define_view :name_complete do |args|
    JSON( card.item_cards( :complete=>params['term'], :limit=>8, :sort=>'name', :return=>'name', :context=>'' ) )
  end
  
  define_view(:content) do |args|
    @state = :view
    wrap(:content, args) { _render_core_array args }
  end

  define_view(:open) do |args|
    @state = :view
    wrap(:open, args) { _render_core_array args }
  end

  define_view(:closed) do |args|
    @state = :line
    wrap(:closed, args) { _render_line args }
  end

  [ :deny_view, :edit_auto, :too_slow, :too_deep, :open_missing, :closed_missing, :setting_missing, :missing ].each do |view|
    define_view(view) do |args|
       %{{{"status":"no card"},{"view":"#{view.to_s.gsub('_',' ')}"},{"card":{"name":"#{card.name}"}}}}
    end
  end
end
