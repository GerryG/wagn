class AccountTrait < ActiveRecord::Migration
  def up
    Account.as_bot do
      User.all.each do |user|
        #next if user.card_id == Card::WagnBotID || user.card_id == Card::AnonID
        card = Card.find user.card_id
        account = card.trait_card(:account)
        if account
          account.save! # this creates it when it doesn't exist
          user.account_id = account.id
          user.save
        end
        Rails.logger.warn "update card_id #{card.inspect}, #{account.inspect}, #{user.card_id}"
      end
    end
  end

  def down
    Account.as_bot do
      Card.search(:right=>Card::AccountID).items { |c| c.delete; }
    end
  end
end
