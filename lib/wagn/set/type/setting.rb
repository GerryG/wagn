require_dependency 'json'

module Wagn
  module Set::Type::Setting
    include Sets

    POINTER_KEY = "Pointer"

    SETTING_GROUPS = {
      "Permission"    => [ :create, :read, :update, :delete, :comment ],
      "Look and Feel" => [ :default, :content, :layout, :table_of_contents ],
      "Communication" => [ :add_help, :edit_help, :send, :thanks ],
      POINTER_KEY     => [ :options, :options_label, :input ],
      "Other"         => [ :autoname, :accountable, :captcha ]
    }

    format :base

    define_view :core, :type=>'setting' do |args|
      _render_closed_content(args) +

      Cardlib::Pattern.subclasses.reverse.map do |set_class|
        wql = { :left  => {:type =>Card::SetID},
                :right => card.id,
                :sort  => 'name',
                :limit => 100
              }
        wql[:left][ (set_class.anchorless? ? :name : :right )] = set_class.key_name

        search_card = Card.new :type =>Card::SearchTypeID, :content=>wql.to_json
        next if search_card.count == 0

        raw( content_tag( :h2, (set_class.anchorless? ? '' : '+') + set_class.key_name, :class=>'values-for-setting') ) +
        subrenderer(search_card)._render_content
      end.compact * "\n"

    end

    define_view :closed_content, :type=>'setting' do |args|
      %{<div class="instruction">#{process_content_object "{{+*right+*edit help}}"}</div>}
    end

  end
end
