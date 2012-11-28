class SettingGroupCards < ActiveRecord::Migration
  def up
<<<<<<< HEAD
    Account.as :wagn_bot do
=======
    Session.as_bot do
>>>>>>> account_migration
      Card.create! :name=>"Permission", :codename=>:perms, :type_id=>Card::SettingID
      Card.create! :name=>"Look and Feel", :codename=>:look, :type_id=>Card::SettingID
      Card.create! :name=>"Communication", :codename=>:com, :type_id=>Card::SettingID
      Card.create! :name=>"Other", :codename=>:other, :type_id=>Card::SettingID
      Card.create! :name=>"Item Selection", :codename=>:pointer_group, :type_id=>Card::SettingID
    end
  end

  def down
<<<<<<< HEAD
    Account.as :wagn_bot do
=======
    Session.as_bot do
>>>>>>> account_migration
      [:perms, :look, :com, :other, :pointer_group].each do |code|
        begin
        c=Card[code]
        c.codename=nil
        c.save!
        c.destroy
        rescue
        end
      end
    end
  end
end
