require 'json'
class Wagn::Renderer
  define_view :core, :type=>'setting' do |args|
    _render_closed_content(args) +
    
    Wagn::Model::Pattern.pattern_subclasses.reverse.map do |set_class|
      wql = { :left  => {:type =>"Set"},
              :right => card.name,
              :sort  => 'name',
              :limit => 100
            }
      wql[:left][ (set_class.trunkless ? :name : :right )] = set_class.key

      search_card = Card.new :type =>'Search', :content=>wql.to_json
      next if search_card.count == 0

      content_tag( :h2, 
        raw( (set_class.trunkless ? '' : '+') + set_class.key), 
        :class=>'values-for-setting') + 
      raw( subrenderer(search_card).render_content )
    end.compact * "\n"
  
  end

  define_view :closed_content, :type=>'setting' do |args|
   %{<div class="instruction">#{process_content "{{+*right+*edit help}}"}</div>}
  end
end
