module Wagn::Model::Templating

  def template?()       cardname.trait_name? :content, :default              end
  def is_hard_template?()  cardname.trait_name? :content                        end
  def type_template?()  template? && cardname.trunk_name.trait_name?(:type)  end

  def template
    # currently applicable templating card.
    # note that a *default template is never returned for an existing card.
    if @template.nil?
      @virtual = false
      if new_card?
        default_card = rule_card :default, :skip_modules=>true

        dup_card = self.dup
#        dup_card.type_id_without_tracking = default_card.type_id
        dup_card.type_id_without_tracking = default_card ? default_card.type_id : Card::DefaultTypeID


        if content_card = dup_card.content_rule_card
          @virtual = true
          @template = content_card
        else
          @template = default_card
        end
      else
        @template = content_rule_card
      end
    end
    #warn "template #{inspect} => #{@template.inspect}"
    @template
  end

  def hard_template
    template if template && template.is_hard_template?
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
      card_ids_to_update = connection.select_rows("select id from cards t where #{condition}").map(&:first)
      card_ids_to_update.each_slice(100) do |id_batch|
        connection.execute "update cards set references_expired=1 where id in (#{id_batch.join(',')})" #FIXME:not ARec
      end
    end
  end



  private

  def hard_templatee_spec
    if is_hard_template?
      if !trash && tk = trunk and tk.type_id == Card::SetID
        tk.get_spec :spec=>tk.content
      else
        true
      end
    end
  end

end
