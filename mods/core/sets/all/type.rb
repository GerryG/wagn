
event :validate_type, :before=>:approve do
  # validate on update
  if updates.for?(:type_id) and !new_card?
    if !validate_type_change
      errors.add :type, "of #{ name } can't be changed; errors changing from #{ type_name }"
    end
    if c = dup and c.type_id_without_tracking = type_id and c.id = nil and !c.valid?
      errors.add :type, "of #{ name } can't be changed; errors creating new #{ type_id }: #{ c.errors.full_messages * ', ' }"
    end
  end

  # validate on update and create
  if updates.for?(:type_id) or new_record?
    # invalid to change type when type is hard_templated
    if rt = hard_template and rt.assigns_type? and type_id!=rt.type_id
      errors.add :type, "can't be changed because #{name} is hard templated to #{rt.type_name}"
    end
  end
end


module ClassMethods
  def default_type_id
    @@default_type_id ||= Card[:all].fetch( :trait=>:default ).type_id
  end
end

def get_type_id args={}
  return if args[:type_id] # type_id was set explicitly.  no need to set again.

  type_id = case
    when args[:type_code]
      if code=args[:type_code]
        Card::Codename[code] || ( c=Card[code] and c.id)
      end
    when args[:type]
      Card.fetch_id args[:type]
    else :noop
    end

  case type_id
  when :noop
  when false, nil
    errors.add :type, "#{args[:type] || args[:type_code]} is not a known type."
  else
    return type_id
  end

  if name && t=template
    reset_patterns #still necessary even with new template handling?
    t.type_id
  end
end

def type_card
  Card[ type_id.to_i ]
end

def type_code
  Card::Codename[ type_id.to_i ]
end

def type_name
  return if type_id.nil?
  type_card = Card.fetch type_id.to_i, :skip_modules=>true, :skip_virtual=>true
  type_card and type_card.name
end

def type= type_name
  self.type_id = Card.fetch_id type_name
end
