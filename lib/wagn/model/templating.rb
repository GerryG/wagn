module Wagn::Model::Templating

  def template?()       cardname.trait_name? :content, :default              end
  def hard_template?()
    #warn "ht? #{name}, #{cardname.trait_name? :content}"
    cardname.trait_name? :content                        end
  def type_template?()  template? && cardname.trunk_name.trait_name?(:type)  end

  def template
    # currently applicable templating card.
    # note that a *default template is never returned for an existing card.
    @template ||= begin
      @virtual = false
      if new_card?
        default_card = rule_card :default, :skip_modules=>true

        dup_card = self.dup
#        dup_card.type_id_without_tracking = default_card.type_id
        dup_card.type_id_without_tracking = default_card ? default_card.type_id : Card::DefaultTypeID


        if content_card = dup_card.content_rule_card
          @virtual = true
          content_card
        else
          default_card
        end
      else
        content_rule_card
      end
    end
  end

  def hard_template
    template if template && template.hard_template?
  end

  def virtual?
    return false unless new_card?
    if @virtual.nil?
      cardname.simple? ? @virtual=false : template
    end
    @virtual
  end

  def content_rule_card
    card = rule_card :content, :skip_modules=>true
    card && card.content.strip == '_self' ? nil : card
  end

  def hard_templatee_names
    if wql = hard_templatee_spec
      #warn "ht_names_wql #{wql.inspect}"
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
      #warn "expire_t_refs #{name}, #{condition.inspect}"
      card_ids_to_update = connection.select_rows("select id from cards t where #{condition}").map(&:first)
      card_ids_to_update.each_slice(100) do |id_batch|
        connection.execute "update cards set references_expired=1 where id in (#{id_batch.join(',')})" #FIXME:not ARec
      end
    end
  end



  private

  def hard_templatee_spec
    #warn "htwql #{name} #{hard_template?}, #{cardname.trunk_name}, #{Card.fetch(cardname.trunk_name)}"
    if hard_template? and tk=trunk and tk.type_id == Card::SetID
      Rails.logger.warn "htspec #{inspect}, tk:#{tk.inspect} ht?#{hard_template?} Cont:#{tk.content}"
      tk.get_spec(:spec=>tk.raw_content)
    end
  end

end
