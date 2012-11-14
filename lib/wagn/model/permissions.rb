class Card::PermissionDenied < Wagn::PermissionDenied
  attr_reader :card
  def initialize card
    @card = card
    super build_message
  end

  def build_message
    "for card #{@card.name}: #{@card.errors[:permission_denied]}"
  end
end



module Wagn::Model::Permissions

  def ydhpt
    "#{Account.authorized.name}, You don't have permission to"
  end

  def approved?
    @operation_approved = true
    @permission_errors = []

    if trash
      ok? :delete
    else
      unless updates.keys == ['comment'] # if only updating comment, next section will handle
        new_card? ? ok?(:create) : ok?(:update)
      end
      updates.each_pair do |attr,value|
        send "approve_#{attr}"
      end
    end

    @permission_errors.each do |err|
      errors.add :permission_denied, err
    end
    @operation_approved
  end

  # ok? and ok! are public facing methods to approve one operation at a time
  def ok? operation
    #warn "ok? #{operation}"
    #Rails.logger.info "ok? #{Account.authorized.inspect}, #{Account.as_card.inspect}, #{operation} #{inspect}" if operation == :read
    @operation_approved = true
    @permission_errors = []

    send "approve_#{operation}"
    # approve_* methods set errors on the card.
    # that's what we want when doing approve? on save and checking each attribute
    # but we don't want just checking ok? to set errors.
    # so we hack around the errors added in approve_* by clearing them here.
    # self.errors.clear

    
    #Rails.logger.info "ok? #{Account.session.inspect}, #{Account.as_card.inspect}, #{operation} #{inspect} R:#{@operation_approved}" if operation == :create
    @operation_approved
  end

  def ok! operation
    #Rails.logger.info "ok! #{operation} #{inspect}" unless operation == :read
    if ok? operation
      true
    else
      raise Card::PermissionDenied.new self
    end
  end

  def trait_ok? tagcode, operation
    trait = fetch_trait(tagcode) and trait.ok?(operation)
  end

  def who_can(operation)
    #Rails.logger.info "who_can[#{name}] #{(prc=permission_rule_card(operation)).inspect}, #{prc.first.item_cards.map(&:name)}" #if operation == :delete
    permission_rule_card(operation).first.item_cards.map(&:id)
  end

  def permission_rule_card operation
    #raise "prc[#{name}]#{operation} #{caller*"\n"}" if caller.size > 500  # stack lossage finder
    opcard = rule_card operation
    #Rails.logger.warn "prc[#{name}]#{operation} #{opcard.inspect}" if operation==:create and name=='Yorba+Torga'
    unless opcard
      errors.add :permission_denied, "No #{operation} setting card for #{name}"
      raise Card::PermissionDenied.new(self)
    end

    rcard = begin
      Account.as_bot do
        if opcard.content == '_left' && self.junction?
          lcard = (loaded_left ||
             Card.fetch_or_new(trunk_name, :skip_virtual=>true, :skip_modules=>true)).permission_rule_card(operation).first 
          # lcard ?   : opcard
        else
          opcard
        end
      end
    end
    #Rails.logger.warn "permission_rule_card[#{name}] #{rcard&&rcard.name}, #{opcard.rule_name.inspect}, #{opcard.inspect}" #if opcard.name == '*logo+*self+*read'
    return rcard, opcard.rule_name
  end

  def rule_name
    trunk.type_id == Card::SetID ? cardname.trunk_name.tag : nil
  end

  protected
  def you_cant(what)
    "#{ydhpt} #{what}"
  end

  def deny_because why
    [why].flatten.each {|err| @permission_errors << err }
    @operation_approved = false
  end

  def lets_user operation
    #warn "creating *account ??? #{caller[0..25]*"\n"}" if name == '*account' && operation==:create
    #Rails.logger.warn "lets_user[#{operation}]#{inspect}" #if name=='Buffalo'
    return false if operation != :read    and Wagn::Conf[:read_only]
    return true  if operation != :comment and Account.always_ok?

    permitted_ids = who_can operation

    r=
    if operation == :comment && Account.always_ok?
      # admin can comment if anyone can
      !permitted_ids.empty?
    else
      Account.among? permitted_ids
    end
    #warn "lets_user[#{operation}]#{name} #{Account.as_card.name}, #{permitted_ids.map {|id|Card[id].name}*', '} R:#{r}" if id == Card::WagnBotID || trunk_id== Card::WagnBotID; r
  end

  def approve_task operation, verb=nil
    deny_because "Currently in read-only mode" if operation != :read && Wagn::Conf[:read_only]
    verb ||= operation.to_s
    #Rails.logger.info "approve_task[#{inspect}](#{operation}, #{verb})" if operation == :delete
    deny_because you_cant("#{verb} this card") unless self.lets_user( operation )
  end

  def approve_create
    approve_task :create
  end

  def approve_read
    #Rails.logger.warn "AR #{inspect} #{Account.always_ok?}"
    return true if Account.always_ok?
    @read_rule_id ||= (rr=permission_rule_card(:read).first).id.to_i
    #Rails.logger.warn "AR #{name} #{@read_rule_id}, #{Account.session.inspect} #{rr&&rr.name}, RR:#{Account.as_card.read_rules.map{|i|c=Card[i] and c.name}*", "}"
    unless Account.as_card.read_rules.member?(@read_rule_id.to_i)
      deny_because you_cant("read this card")
    end
  end

  def approve_update
    approve_task :update
    approve_read if @operation_approved
  end

  def approve_delete
    approve_task :delete
  end

  def approve_comment
    approve_task :comment, 'comment on'
    if @operation_approved
      deny_because "No comments allowed on template cards" if template?
      deny_because "No comments allowed on hard templated cards" if hard_template
    end
  end

  def approve_type_id
    case
    when !type_name
      deny_because("No such type")
    when !new_card? && reset_patterns && !lets_user(:create)
      deny_because you_cant("change to this type (need create permission)"  )
    end
    #NOTE: we used to check for delete permissions on previous type, but this would really need to happen before the name gets changes
    #(hence before the tracked_attributes stuff is run)
  end

  def approve_name
  end

  def approve_content
    if !new_card? && hard_template
      deny_because you_cant("change the content of this card -- it is hard templated by #{template.name}")
    end
  end


  public

  def set_read_rule
    if trash == true
      self.read_rule_id = self.read_rule_class = nil
    else
      # avoid doing this on simple content saves?
      rcard, rclass = permission_rule_card(:read)
      self.read_rule_id = rcard.id
      self.read_rule_class = rclass
      #find all cards with me as trunk and update their read_rule (because of *type plus right)
      # skip if name is updated because will already be resaved

      if !new_card? && updates.for(:type_id)
        Account.as_bot do
          Card.search(:left=>self.name).each do |plus_card|
            plus_card = plus_card.refresh
            plus_card.update_read_rule
          end
        end
      end
    end
  end

  def update_read_rule
    Card.record_timestamps = false

    reset_patterns # why is this needed?
    rcard, rclass = permission_rule_card :read
    self.read_rule_id = rcard.id #these two are just to make sure vals are correct on current object
    #Rails.logger.debug "updating read rule for #{name} to #{rcard.inspect}, #{rcard.name}, #{rclass}"

    self.read_rule_class = rclass
    Card.where(:id=>self.id).update_all(:read_rule_id=>rcard.id, :read_rule_class=>rclass)
    expire

    # currently doing a brute force search for every card that may be impacted.  may want to optimize(?)
    Account.as_bot do
      Card.search(:left=>self.name).each do |plus_card|
        if plus_card.rule(:read) == '_left'
          plus_card.update_read_rule
        end
      end
    end

  ensure
    Card.record_timestamps = true
  end

  # fifo of cards that need read rules updated
  def update_read_rule_list() @update_read_rule_list ||= [] end
  def read_rule_updates updates
    #Rails.logger.info "read_rule_updates #{updates.inspect}"
    #warn "rrups #{updates.inspect}"
    @update_read_rule_list = update_read_rule_list.concat updates
    # to short circuite the queue mechanism, just each the new list here and update
  end

  def update_queue
    #warn (Rails.logger.warn "update queue[#{inspect}] Q[#{self.update_read_rule_list.inspect}]")

    self.update_read_rule_list.each { |card| card.update_read_rule }
    self.update_read_rule_list = []
  end

 protected

  def update_ruled_cards
    # FIXME: codename
    if junction? && tag_id==Card::ReadID && (@name_or_content_changed || @trash_changed)
      # These instance vars are messy.  should use tracked attributes' @changed variable
      # and get rid of @name_changed, @name_or_content_changed, and @trash_changed.
      # Above should look like [:name, :content, :trash].member?( @changed.keys ).
      # To implement that, we need to make sure @changed actually tracks trash
      # (though maybe not as a tracked_attribute for performance reasons?)
      # AND need to make sure @changed gets wiped after save (probably last in the sequence)

      Card.cache.reset # maybe be more surgical, just Account.session related
      expire #probably shouldn't be necessary,
      # but was sometimes getting cached version when card should be in the trash.
      # could be related to other bugs?
      in_set = {}
      read_rule_ids=rule_class_index=nil
      if !(self.trash)
        if class_id = (set=left and set_class=set.tag and set_class.id)
          rule_class_ids = Wagn::Model::Pattern.subclasses.map &:key_id
          #Rails.logger.warn "rule_class_id #{class_id}, #{rule_class_ids.inspect}"

          #first update all cards in set that aren't governed by narrower rule
           Account.as_bot do
             cur_index = rule_class_ids.index Card[read_rule_class].id
             if rule_class_index = rule_class_ids.index( class_id )
                # Why isn't this just 'trunk', do we need the fetch?
                Card.fetch(cardname.trunk_name).item_cards(:limit=>0).each do |item_card|
                  in_set[item_card.key] = true
                  next if cur_index > rule_class_index
                  item_card.update_read_rule
                end
             elsif rule_class_index = rule_class_ids.index( 0 )
               in_set[trunk.key] = true
               #Rails.logger.warn "self rule update: #{trunk.inspect}, #{rule_class_index}, #{cur_index}"
               trunk.update_read_rule if cur_index > rule_class_index
             else warn "No current rule index #{class_id}, #{rule_class_ids.inspect}"
             end
          end

        end
      end
      #Rails.logger.debug "rule_class_ids[#{rule_class_index}] #{rule_class_ids.inspect} This:#{read_rule_class.inspect} idx:#{rule_class_ids.index(read_rule_class)}" if rule_class_ids

      #then find all cards with me as read_rule_id that were not just updated and regenerate their read_rules
      if !new_record?
        Card.where( :read_rule_id=>self.id, :trash=>false ).reject do |w|
          in_set[ w.key ]
        end.each &:update_read_rule
      end
    end
  end

end
