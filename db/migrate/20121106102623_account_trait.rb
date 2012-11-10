class AccountTrait < ActiveRecord::Migration
  def up
    Session.as_bot do
      User.all.each do |user|
        #next if user.card_id == Card::WagnBotID || user.card_id == Card::AnonID
        card = Card.find user.card_id
        account = card.trait_card(:account)
        if account
          account.save!
          user.card_id = account.id
          user.login = card.key
          user.save
        end
        warn "update card_id #{card.inspect}, #{account.inspect}, #{user.card_id}"
      end
    end
  end

  def down
  end
end
