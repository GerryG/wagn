# -*- encoding : utf-8 -*-

class BootstrapThemes < Card::CoreMigration
  def up
    Card.create! :name=>'raw bootstrap skin', :type_code=>:skin, :content=> "[[style: bootstrap]]\n[[style: jquery-ui-smoothness]]\n[[style: functional]]\n[[style: standard]]\n[[style: right sidebar]]\n[[style: bootstrap common]]\n[[style: bootstrap cards]]"
    %w{amelia simpex cerulean lumen darkly flatly journal paper readable sandstone slate holo superhero yeti cosmo cyborg spacelab united}.each do |theme|
      Card.create! :name=>"theme: #{theme}", :type_code=>:css, :codename=>"theme_#{theme}"
      Card.create! :name=>"#{theme} skin", :type_code=>:skin, :content=>"[[raw bootstrap skin]]\n[[theme: #{theme}]]"
    end
  end
end
