module Wagn::Model::Templating

  def template?()       cardname.trait_name? :content, :default              end
  def hard_template?()
    right_id == Card::ContentID                        end
  def type_template?()  template? && cardname.trunk_name.trait_name?(:type)  end

  def template
    # currently applicable templating card.
    # note that a *default template is never returned for an existing card.
    if @template.nil?
      @virtual = false
      if new_card?
        @template = rule_card :content, :fallback=>:default, :skip_modules=>true

        dup_card = self.dup
#        dup_card.type_id_without_tracking = @template.type_id
        dup_card.type_id_without_tracking = @template ? @template.type_id : Card::DefaultTypeID


        #warn "tt #{to_s}, #{@template}, D:#{dup_card}" if name == 'Jim+birthday'
        if content_card = dup_card.content_rule_card
          @virtual = true
          @template=content_card
        end
        #warn "tx #{inspect}, T:#{@template}, Tcont:#{@template.content}" if name == 'Jim+birthday'
      else
        @template=content_rule_card
      end
      #warn "template #{inspect}, #{@template.inspect} #{@virtual}" if name == 'Jim+birthday'
    end
    @template
  end

  def hard_template
    t=template and t.hard_template? and t
  end

  def virtual?
    return false unless new_card?
    if @virtual.nil?
      cardname.simple? ? @virtual=false : template
    end
    @virtual
  end

  def content_rule_card
    raise "deep" if caller.length > 500
    card = @template || rule_card(:content, :fallback=>:default, :skip_modules=>true)
    #warn "template crc #{inspect}, #{card.inspect}" if name == 'Jim+birthday'
    c=(card && !card.hard_template? || card.content.strip == '_self' ? nil : card)
    #warn "crc #{to_s} R:#{c.inspect}" if name == 'Jim+birthday'; c
  end

  def hard_templatee_names
    if wql = hard_templatee_spec
      #warn "ht_names_wql #{wql.inspect}" if name == 'Jim+birthday'
      Account.as_bot do
        wql == true ? [name] : Wql.new(wql.merge :return=>:name).run
      end
    else [] end
  end

  # FIXME: content settings -- do we really need the reference expiration system?
  #
  # I kind of think so.  otherwise how do we handled patterned references in hard-templated cards?
  # I'll leave the FIXME here until the need is well documented.  -efm
  #
  # ps.  I think this code should be wiki references.
  def expire_templatee_references
    if wql = hard_templatee_spec
      wql = {:name => name} if wql == true

      condition = Account.as_bot { Wql::CardSpec.build(wql.merge(:return => :condition)).to_sql }
      #warn "expire_t_refs #{name}, #{condition.inspect}" if name == 'Jim+birthday'
      card_ids_to_update = connection.select_rows("select id from cards t where #{condition}").map(&:first)
      card_ids_to_update.each_slice(100) do |id_batch|
        connection.execute "update cards set references_expired=1 where id in (#{id_batch.join(',')})" #FIXME:not ARec
      end
    end
  end



  private

  def hard_templatee_spec
    #warn "htwql #{name} #{hard_template?}, #{cardname.trunk_name}, #{Card.fetch(cardname.trunk_name)}" if name == 'Jim+birthday'
    if hard_template? and tk=trunk and tk.type_id == Card::SetID
      tk.get_spec(:spec=>tk.content)
    end
  end

end
