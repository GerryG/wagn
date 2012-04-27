class Wagn::Renderer::Html

  define_view :closed_rule do |args|
    rule_card = card.new_card? ? find_current_rule_card[0] : card

    cells = [
      ["rule-setting",
        link_to( card.cardname.tag_name, path(:view, :view=>:open_rule),
          :class => 'edit-rule-link slotter', :remote => true )
      ],
      ["rule-content",
        %{<div class="rule-content-container">
           <span class="closed-content content">#{rule_card ? subrenderer(rule_card).render_closed_content : ''}</span>
         </div> } ],
      ["rule-type", (rule_card ? rule_card.typename : '') ],
    ]

    extra_css_class = rule_card && !rule_card.new_card? ? 'known-rule' : 'missing-rule'

    %{<tr class="card-slot closed-rule">} +
    cells.map do |css_class, content|
      %{<td class="rule-cell #{css_class} #{extra_css_class}">#{content}</td>}
    end.join("\n") +
    '</tr>'
  end



  define_view :open_rule do |args|
    current_rule, prototype = find_current_rule_card
    setting_name = card.cardname.tag_name
    current_rule ||= Card.new :name=> "*all+#{setting_name}"

    if args=params[:card]
      current_rule = current_rule.refresh if current_rule.frozen?
      args[:type_id] = Card.type_id_from_name(args.delete(:type)) if args[:type]
      current_rule.assign_attributes args
      current_rule.reset_mods
      current_rule.include_set_modules
    end

    params.delete(:success) if params[:type_reload] # otherwise updating the editor looks like a successful post
    # should this be in "if" above?

    opts = {
      :fallback_set    => false,
      :open_rule       => card,
      :edit_mode       => (card.ok?(card.new_card? ? :create : :update) && !params[:success]),
      :setting_name    => setting_name,
      :current_set_key => (current_rule.new_card? ? nil : current_rule.cardname.trunk_name.key)
    }

    if !opts[:read_only]
      set_options = prototype.set_names.reverse
      first = (csk=opts[:current_set_key]) ? set_options.index{|s| s.to_cardname.key == csk} : 0
      if first > 0
        set_options[0..(first-1)].reverse.each do |set_name|
          opts[:fallback_set] = set_name if Card.exists?("#{set_name}+#{opts[:setting_name]}")
        end
      end
      last = set_options.index{|s| s.to_cardname.key == card.cardname.trunk_name.key} or raise("set for #{card.name} not found in prototype set names")
      opts[:set_options] = set_options[first..last]

      # The above is about creating the options for the sets to which the user can apply the rule.
      # The broadest set should always be the currently applied rule
      # (for anything more general, they must explicitly choose to "DELETE" the current one)
      # the narrowest rule should be the one attached to the set being viewed.  So, eg, if you're looking at the "*all plus" set, you shouldn't
      # have the option to create rules based on arbitrary narrower sets, though narrower sets will always apply to whatever prototype we create
    end


    %{
      <tr class="card-slot open-rule">
        <td class="rule-cell" colspan="3">
          #{subrenderer( current_rule )._render_edit_rule opts }
        </td>
      </tr>
    }

  end

  # THIS SHOULD NOT BE A VIEW
  define_view :edit_rule do |args|
    edit_mode       = args[:edit_mode]
    setting_name    = args[:setting_name]
    current_set_key = args[:current_set_key]
    open_rule       = args[:open_rule]
    @item_view ||= :link

    form_for card, :url=>path(:create_or_update), :remote=>true, :html=>
        {:class=>"card-form card-rule-form #{edit_mode && 'slotter'}" } do |form|

      %{
        #{ hidden_field_tag( :success, open_rule.name ) }
        #{ hidden_field_tag( :view, 'open_rule' ) }
      <div class="card-editor">
        <div class="rule-column-1">
          <div class="rule-setting">
            #{ link_to( setting_name, path(:view, :card=>open_rule, :view=>:closed_rule),
                :remote => true, :class => 'close-rule-link slotter') }
          </div>
          <ul class="set-editor">
      } +


      if edit_mode
#        '<label>apply to:</label> ' +
        raw( args[:set_options].map do |set_name|
          set_label =Card.fetch(set_name).label

          '<li>' +
            raw( form.radio_button( :name, "#{set_name}+#{setting_name}", :checked=>(current_set_key && args[:set_options].length==1) ) ) +
            if set_name.to_cardname.to_key == current_set_key
              %{<span class="set-label current-set-label">#{ set_label } <em>(current)</em></span>}
            else
              %{<span class="set-label">#{ set_label }</span>}
            end.html_safe +
          '</li>'
        end.join)
      else
        %{
        <label>applies to:</label>
        <span class="set-label current-set-label">
          #{current_set_key ? Card.fetch(current_set_key).label : 'No Current Rule' }
        </span>
        }.html_safe
      end +


      %{  </ul>
        </div>

        <div class="rule-column-2">
          <div class="instruction rule-instruction">
            #{ raw process_content( "{{#{setting_name}+*right+*edit help}}" ).html_safe  }
          </div>
          <div class="type-editor"> }+

      if edit_mode
        %{<label>type:</label>}+ 
        raw(typecode_field( :class =>'type-field rule-type-field live-type-field', 'data-remote'=>true,
          :href => path(:view, :card=>open_rule, :view=>:open_rule, :type_reload=>true) ) )
      elsif current_set_key
        '<label>type:</label>'+
        %{<span class="rule-type">#{ current_set_key ? card.typename : '' }</span>}
      else; ''; end.html_safe +


          %{</div>
          <div class="rule-content">#{ edit_mode ? content_field(form, :skip_rev_id=>true) : (current_set_key ? render_core : '') }</div> 
        </div>
       </div> }.html_safe +

       if edit_mode || params[:success]
         ('<div class="edit-button-area">' +
           if params[:success]
             (button_tag( 'Edit', :class=>'rule-edit-button slotter', :type=>'button',
               :href => path(:view, :card=>open_rule, :view=>:open_rule), :remote=>true ) +
             button_tag( 'Close', :class=>'rule-cancel-button', :type=>'button' )).html_safe
           else
             (if !card.new_card?
               b_args = { :remote=>true, :class=>'rule-delete-button slotter', :type=>'button' }
               b_args[:href] = path :remove, :view=>:open_rule, :success=>open_rule.cardname.to_url_key
               if fset = args[:fallback_set]
                 b_args['data-confirm']="Deleting will revert to #{setting_name} rule for #{Card.fetch(fset).label }"
               end
               %{<span class="rule-delete-section">#{ button_tag 'Delete', b_args }</span>}
             else; ''; end +
             submit_tag( 'Submit', :class=>'rule-submit-button') +
             button_tag( 'Cancel', :class=>'rule-cancel-button', :type=>'button' )).html_safe
           end +
         '</div>').html_safe
       else ''; end +
       notice.html_safe

    end.html_safe
  end



  private

  def find_current_rule_card
    # self.card is a POTENTIAL rule; it quacks like a rule but may or may not exist.
    # This generates a prototypical member of the POTENTIAL rule's set
    # and returns that member's ACTUAL rule for the POTENTIAL rule's setting
    set_prototype = Card.fetch( card.cardname.trunk_name ).prototype
    rule_card = card.new_card? ? Card.fetch_or_new(set_prototype.name + card.cardname.tag_name) : card
    [ rule_card, set_prototype ]
  end

end
