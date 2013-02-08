# -*- encoding : utf-8 -*-
class Card::Revision < ActiveRecord::Base
  before_save :set_stamper

  def self.cache
    Wagn::Cache[Card::Revision]
  end

  def set_stamper
    warn "set stam #{Account.current.inspect}"
    self.creator_id = Account.current_id
  end

  def creator
    warn "cretor #{Card[ creator_id ].inspect}"
    Card[ creator_id ]
  end

  def card
    Card[ card_id ]
  end

  def title #ENGLISH
    current_rev_id = card.current_revision_id
    if id == current_rev_id
      'Current Revision'
    elsif id > current_rev_id
      'AutoSave'
    else
      card.revisions.each_with_index do |rev, index|
        return "Revision ##{index + 1}" if rev.id == id
      end
      '[Revisions Missing]'
    end
  end

end
