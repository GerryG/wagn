require 'csv'

class Wagn::Renderer::Csv
  define_view :show do |args|
    if !card.collection?
      "CSV format only works on collections (searches, pointers, etc)"
    else
      @item_view = :csvrow
      super args
    end
  end

  define_view :csvrow do |args|
    _render_raw.scan( /{{[^}]*}}/ ).map do |inc|
      process_content_s( inc ).strip
    end.to_csv.chop
    #chop is because search already joins with newlines
  end

  define_view :missing do |args|
    ''
  end

end
