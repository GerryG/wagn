module Wagn::Model::TrackedAttributes

  def set_tracked_attributes
    @was_new_card = self.new_card?
    updates.each_pair do |attrib, value|
      #Rails.logger.debug "updates #{attrib} = #{value}"
      if send("set_#{attrib}", value )
        updates.clear attrib
      end
      @changed ||={}; @changed[attrib.to_sym]=true
    end
    #Rails.logger.debug "Card(#{name})#set_tracked_attributes end"
  end



  protected
  def set_name newname
    Rails.logger.info "set_name #{newname}"
    @old_name = self.name_without_tracking
    return if @old_name == newname.to_s
    #Rails.logger.warn "rename . #{inspect}, N:#{newname}, O:#{@old_name}"

    @cardname, name_without_tracking = if SmartName===newname
      [ newname, newname.to_s]
    else
      [ newname.to_name, newname]
    end
    write_attribute :key, k=cardname.key
    write_attribute :name, name_without_tracking # what does this do?  Not sure, maybe comment it out and see

    reset_patterns_if_rule # reset the new name

    Card.expire cardname

    if @cardname.junction?
      [:trunk, :tag].each do |side|
        sidename = @cardname.send "#{side}_name"
        #Rails.logger.warn "sidename #{newname}, #{@old_name}, #{sidename}"
        sidecard = Card[sidename]
        old_name_in_way = (sidecard && sidecard.id==self.id) # eg, renaming A to A+B
        suspend_name(sidename) if old_name_in_way
        self.send "#{side}_id=", begin
          if !sidecard || old_name_in_way
            Card.create! :name=>sidename
          else
            sidecard
          end.id
        end
      end
    else
      #self.trunk_id = self.tag_id = id
      #self.left_id = self.right_id = nil
      # FIXME: technically it should be one of the above, but the names are wrong
      # either way we need a migration and to extend/fix wql
      # for now, tag_id and trunk_id methods fix it internally so wql is ok
      self.trunk_id = self.tag_id = nil
    end

    return if new_card?
    if existing_card = Card.find_by_key(@cardname.key) and existing_card != self
      if existing_card.trash
        existing_card.name = tr_name = existing_card.name+'*trash'
        existing_card.instance_variable_set :@cardname, tr_name.to_name
        existing_card.set_tracked_attributes
        Rails.logger.debug "trash renamed collision: #{tr_name}, #{existing_card.name}, #{existing_card.cardname.key}"
        existing_card.save!
      #else note -- else case happens when changing to a name variant.  any special handling needed?
      end
    end

    Card.expire @old_name
    @name_changed = true
    @name_or_content_changed=true
  end


  def suspend_name(name)
    # move the current card out of the way, in case the new name will require
    # re-creating a card with the current name, ie.  A -> A+B
    Card.expire name
    tmp_name = "tmp:" + UUID.new.generate
    Card.where(:id=>self.id).update_all(:name=>tmp_name, :key=>tmp_name)
  end

  def set_type_id(new_type_id)
    #Rails.logger.debug "set_typecde No type code for #{name}, #{type_id}" unless new_type_id
    #warn "set_type_id(#{new_type_id}) #{self.type_id_without_tracking}"
    self.type_id_without_tracking= new_type_id
    return true if new_card?
    on_type_change # FIXME this should be a callback
    if is_hard_template? && !type_template?
      hard_templatee_names.each do |templatee_name|
        tee = Card[templatee_name]
        tee.allow_type_change = true  #FIXME? this is a hacky way around the standard validation
        tee.type_id = new_type_id
        tee.save!
      end
    end

    # do we need to "undo" and loaded modules?  Maybe reload defaults?
    reset_patterns
    include_set_modules
    true
  end

  def set_content(new_content)
    Rails.logger.warn "set_content #{inspect}, #{self.content}, w/o:#{self.content_without_tracking}, N:#{new_content}"
    return false unless self.id
    new_content ||= (tmpl = template).nil? ? '' : tmpl.content
    new_content = CleanHtml.clean!(new_content) if clean_html?
    clear_drafts if current_revision_id
    Rails.logger.warn "set_content #{inspect} CurC:#{content_without_tracking}, N:#{new_content}, #{Account.session}"
    new_rev = Card::Revision.create :card_id=>self.id, :content=>new_content, :creator_id =>Account.authorized.id
    self.current_revision_id = new_rev.id
    reset_patterns_if_rule unless new_card?
    Rails.logger.warn "finish cont #{new_content}, #{inspect}"
    @name_or_content_changed = true
  end

  def set_comment(new_comment)
    set_content( content + new_comment )
    true
  end

  def set_initial_content
    #warn "Card(#{inspect})#set_initial_content start #{content_without_tracking}"
    # set_content bails out if we call it on a new record because it needs the
    # card id to create the revision.  call it again now that we have the id.

    Rails.logger.warn "si cont #{content} #{updates.map(&:inspect)*', '} #{template.inspect}"
    set_content updates.for?(:content) ? updates[:content] : template.send_if(:content)
    #set_content updates[:content] if updates.for?(:content)
    updates.clear :content

    # normally the save would happen after set_content. in this case, update manually:
    Rails.logger.warn "set_initial_content #{content}, #{current_revision_id} #{inspect}"
    Card.update(id, :current_revision_id => current_revision_id)
  end

  def cascade_name_changes
    return true unless @name_changed
    ActiveRecord::Base.logger.debug "----------------------- CASCADE #{self.name}  -------------------------------------"

    deps = self.dependents

    deps.each do |dep|
      # here we specifically want NOT to invoke recursive cascades on these cards, have to go this low level to avoid callbacks.
      ActiveRecord::Base.logger.debug "---------------------- DEP #{dep.name}  -------------------------------------"
      newname = dep.cardname.replace_part @old_name, name
      cxn = connection
      Card.update_all "name=#{cxn.quote newname.s}, #{cxn.quote_column_name 'key'}=#{cxn.quote newname.key}", "id = #{dep.id}"
      Card.expire dep.name #expire old name
      Card.expire newname
    end

    if !update_referencers || update_referencers == 'false'  # FIXME doing the string check because the radio button is sending an actual "false" string
      #warn "no updating.."
      ([self]+deps).each do |dep|
        ActiveRecord::Base.logger.debug "--------------- NOUPDATE REFERER #{dep.name}  ---------------------------"
        Card::Reference.update_on_destroy dep, @old_name
      end
    else
      Account.as_bot do
        [self.name_referencers(@old_name)+(deps.map &:referencers)].flatten.uniq.each do |card|
          # FIXME  using "name_referencers" instead of plain "referencers" for self because there are cases where trunk and tag
          # have already been saved via association by this point and therefore referencers misses things
          # eg.  X includes Y, and Y is renamed to X+Z.  When X+Z is saved, X is first updated as a trunk before X+Z gets to this point.
          # so at this time X is still including Y, which does not exist.  therefore #referencers doesn't find it, but name_referencers(old_name) does.
          # some even more complicated scenario probably breaks on the dependents, so this probably needs a more thoughtful refactor
          # aligning the dependent saving with the name cascading

          ActiveRecord::Base.logger.debug "------------------ UPDATE REFERER #{card.name}  ------------------------"
          next if card.hard_template
          card.content = card.replace_references( @old_name, name )
          card.save! unless card==self
        end
      end
    end

    Card::Reference.update_on_create( self )
    @name_changed = false
    true
  end

  def self.included(base)
    super
    #base.after_create :set_initial_content call from update..._on_create
    base.after_save :cascade_name_changes
  end

end
