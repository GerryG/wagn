class AccountTrait < ActiveRecord::Migration
  def up
<<<<<<< HEAD
    Account.as :wagn_bot do
      User.all.each do |user|
        #next if user.card_id == Card::WagnBotID || user.card_id == Card::AnonID
        card = Card.find user.card_id
        account = card.fetch_or_new_trait(:account)
        if account
          account.save! # this creates it when it doesn't exist
=======
    Session.as_bot do
      User.all.each do |user|
        #next if user.card_id == Card::WagnBotID || user.card_id == Card::AnonID
        card = Card.find user.card_id
        if account = card.fetch!(:trait=>:account, :new=>{})
>>>>>>> account_migration
          user.account_id = account.id
          user.save!
        end
        Rails.logger.warn "update card_id #{card.inspect}, #{account.inspect}, #{user.card_id}"
      end
    end
  end

  def down
<<<<<<< HEAD
    Account.as :wagn_bot do
=======
    Session.as_bot do
>>>>>>> account_migration
      Card.search(:right=>Card::AccountID).items { |c| c.delete; }
    end
  end
end
