require File.expand_path('../db/migrate/20120327090000_codename_table', File.dirname(__FILE__))
require 'timecop'

Dir["#{Rails.root}/app/models/card/*.rb"].sort.each do |cardtype|
  require_dependency cardtype
end

class SharedData
  FUTURE = Time.local(2020,1,1,0,0,0)

  def self.add_test_data
    #Card.current_id = Card::WagnBotID
    CodenameTable.load_bootcodes unless !Wagn::Codename[:wagn_bot].nil?

    Account.as(Card::WagnBotID)
    Wagn::Cache.reset_global

    joe_card = Card.create! :typecode=>'user', :name=>"Joe User", :content => "I'm number two"
    joe_user = User.create! :login=>"joe_user",:email=>'joe@user.com', :status => 'active', :password=>'joe_pass', :password_confirmation=>'joe_pass', :card_id=>joe_card.id

    ja_card = Card.create! :typecode=>'user', :name=>"Joe Admin", :content => "I'm number one"
    joe_admin = User.create! :login=>"joe_admin",:email=>'joe@admin.com', :status => 'active', :password=>'joe_pass', :password_confirmation=>'joe_pass', :card_id=>ja_card.id
    roles_card = ja_card.fetch(:trait=>:roles)
    #warn "roles card for #{ja_card.name} is #{roles_card.inspect}"
    roles_card << Card::AdminID

    jc_card = Card.create! :typecode=>'user', :name=>"Joe Camel", :content => "Mr. Buttz"
    joe_camel = User.create! :login=>"joe_camel",:email=>'joe@camel.com', :status => 'active', :password=>'joe_pass', :password_confirmation=>'joe_pass', :card_id=>jc_card.id

    #bt = Card.find_by_name 'Basic+*type+*default'

    # check for missing codenames:
    CodenameTable::CODENAMES.each do |code| CodenameTable.add_codename code end

    # generic, shared attribute card
    color = Card.create! :name=>"color"
    basic = Card.create! :name=>"Basic Card"

    # data for testing users and account requests

    ron_request = Card.create! :typecode=>'account_request', :name=>"Ron Request"  #, :email=>"ron@request.com"

    User.create(:email=>'ron@request.com', :password=>'ron_pass', :password_confirmation=>'ron_pass', :card_id=> ron_request.id)
    no_count = Card.create! :typecode=>'user', :name=>"No Count", :content=>"I got no account"

    # CREATE A CARD OF EACH TYPE
    user_card = Card.create! :typecode=>'user', :name=>"Sample User"
    user_user = User.create! :login=>"sample_user",:email=>'sample@user.com', :status => 'active', :password=>'sample_pass', :password_confirmation=>'sample_pass', :card_id=>user_card.id

    request_card = Card.create! :typecode=>'account_request', :name=>"Sample AccountRequest" #, :email=>"invitation@request.com"

    Account.createable_types.each do |type|
      next if ['User', 'Account Request', 'Set'].include? type
      Card.create! :type=>type, :name=>"Sample #{type}"
    end

    # data for role_test.rb
    u1 = Card.create! :typecode=>'user', :name=>"u1"
    u2 = Card.create! :typecode=>'user', :name=>"u2"
    u3 = Card.create! :typecode=>'user', :name=>"u3"

    User.create! :login=>"u1",:email=>'u1@user.com', :status => 'active', :password=>'u1_pass', :password_confirmation=>'u1_pass', :card_id=>u1.id
    User.create! :login=>"u2",:email=>'u2@user.com', :status => 'active', :password=>'u2_pass', :password_confirmation=>'u2_pass', :card_id=>u2.id
    User.create! :login=>"u3",:email=>'u3@user.com', :status => 'active', :password=>'u3_pass', :password_confirmation=>'u3_pass', :card_id=>u3.id


    r1 = Card.create!( :typecode=>'role', :name=>'r1' )
    r2 = Card.create!( :typecode=>'role', :name=>'r2' )
    r3 = Card.create!( :typecode=>'role', :name=>'r3' )
    r4 = Card.create!( :typecode=>'role', :name=>'r4' )

    u1.fetch(:trait=>:roles) << r1 << r2 << r3
    u2.fetch(:trait=>:roles) << r1 << r2 << r4
    u3_star = u3.fetch(:trait=>:roles) << r1 << r4

    u3_star << Card::AdminID

    c1 = Card.create! :name=>'c1'
    c2 = Card.create! :name=>'c2'
    c3 = Card.create! :name=>'c3'

    # cards for rename_test
    # FIXME: could probably refactor these..
    z = Card.create! :name=>"Z", :content=>"I'm here to be referenced to"
    a = Card.create! :name=>"A", :content=>"Alpha [[Z]]"
    b = Card.create! :name=>"B", :content=>"Beta {{Z}}"
    t = Card.create! :name=>"T", :content=>"Theta"
    x = Card.create! :name=>"X", :content=>"[[A]] [[A+B]] [[T]]"
    y = Card.create! :name=>"Y", :content=>"{{B}} {{A+B}} {{A}} {{T}}"
    ab = Card.create! :name => "A+B", :content => "AlphaBeta"

    Card.create! :name=>"One+Two+Three"
    Card.create! :name=>"Four+One+Five"

    # for wql & permissions
    %w{ A+C A+D A+E C+A D+A F+A A+B+C }.each do |name| Card.create!(:name=>name)  end
    c=Card.create! :typecode=>'cardtype', :name=>"Cardtype A", :codename=>"cardtype_a"
    c=Card.create! :typecode=>'cardtype', :name=>"Cardtype B", :codename=>"cardtype_b"
    c=Card.create! :typecode=>'cardtype', :name=>"Cardtype C", :codename=>"cardtype_c"
    c=Card.create! :typecode=>'cardtype', :name=>"Cardtype D", :codename=>"cardtype_d"
    c=Card.create! :typecode=>'cardtype', :name=>"Cardtype E", :codename=>"cardtype_e"
    c=Card.create! :typecode=>'cardtype', :name=>"Cardtype F", :codename=>"cardtype_f"

    Card.create! :name=>'basicname', :content=>'basiccontent'
    Card.create! :typecode=>'cardtype_a', :name=>"type-a-card", :content=>"type_a_content"
    Card.create! :typecode=>'cardtype_b', :name=>"type-b-card", :content=>"type_b_content"
    Card.create! :typecode=>'cardtype_c', :name=>"type-c-card", :content=>"type_c_content"
    Card.create! :typecode=>'cardtype_d', :name=>"type-d-card", :content=>"type_d_content"
    Card.create! :typecode=>'cardtype_e', :name=>"type-e-card", :content=>"type_e_content"
    Card.create! :typecode=>'cardtype_f', :name=>"type-f-card", :content=>"type_f_content"

    #warn "current user #{User.session_account.inspect}.  always ok?  #{Account.always_ok?}"
    c = Card.create! :name=>'revtest', :content=>'first'
    c.update_attributes! :content=>'second'
    c.update_attributes! :content=>'third'
    #Card.create! :typecode=>'cardtype', :name=>'*priority'

    # for template stuff
    Card.create! :type_id=>Card::CardtypeID, :name=> "UserForm"
    Card.create! :name=>"UserForm+*type+*content", :content=>"{{+name}} {{+age}} {{+description}}"

    Account.session = 'joe_user'
    Card.create!( :name=>"JoeLater", :content=>"test")
    Card.create!( :name=>"JoeNow", :content=>"test")

    Account.session = :wagn_bot
    Card.create!(:name=>"AdminNow", :content=>"test")

    Card.create :name=>'Cardtype B+*type+*create', :type=>'Pointer', :content=>'[[r1]]'

    Card.create! :type=>"Cardtype", :name=>"Book"
    Card.create! :name=>"Book+*type+*content", :content=>"by {{+author}}, design by {{+illustrator}}"
    Card.create! :name => "Iliad", :type=>"Book"


    ### -------- Notification data ------------
    Timecop.freeze(FUTURE - 1.day) do
      # fwiw Timecop is apparently limited by ruby Time object, which goes only to 2037 and back to 1900 or so.
      #  whereas DateTime can represent all dates.

      john_card = Card.create! :name=>"John", :type=> "User"
      User.create! :login=>"john",:email=>'john@user.com', :status => 'active', :password=>'john_pass', :password_confirmation=>'john_pass', :card_id=>john_card.id

      sara_card = Card.create! :name=>"Sara", :type=> "User"
      User.create! :login=>"sara",:email=>'sara@user.com', :status => 'active', :password=>'sara_pass', :password_confirmation=>'sara_pass', :card_id=>sara_card.id


      Card.create! :name => "Sara Watching+*watchers",  :content => "[[Sara]]"
      Card.create! :name => "All Eyes On Me+*watchers", :content => "[[Sara]]\n[[John]]"
      Card.create! :name => "John Watching", :content => "{{+her}}"
      Card.create! :name => "John Watching+*watchers",  :content => "[[John]]"
      Card.create! :name => "John Watching+her"
      Card.create! :name => "No One Sees Me"

      Card.create! :name => "Optic", :type => "Cardtype"
      Card.create! :name => "Optic+*watchers", :content => "[[Sara]]"
      Card.create! :name => "Sunglasses", :type=>"Optic", :content=>"{{+tint}}"
      Card.create! :name => "Sunglasses+tint"

      # TODO: I would like to setup these card definitions with something like Cucumbers table feature.
    end


    ## --------- create templated permissions -------------
    ctt = Card.create! :name=> 'Cardtype E+*type+*default'


    ## --------- Fruit: creatable by anon but not readable ---
    f = Card.create! :type=>"Cardtype", :name=>"Fruit"
    Card.create :name=>'Fruit+*type+*create', :type=>'Pointer', :content=>'[[Anyone]]'
    Card.create :name=>'Fruit+*type+*read', :type=>'Pointer', :content=>'[[Administrator]]'

    # -------- For toc testing: ------------

    Card.create :name=>"OnneHeading", :content => "<h1>This is one heading</h1>\r\n<p>and some text</p>"
    Card.create :name=>'TwwoHeading', :content => "<h1>One Heading</h1>\r\n<p>and some text</p>\r\n<h2>And a Subheading</h2>\r\n<p>and more text</p>"
    Card.create :name=>'ThreeHeading', :content =>"<h1>A Heading</h1>\r\n<p>and text</p>\r\n<h2>And Subhead</h2>\r\n<p>text</p>\r\n<h1>And another top Heading</h1>"

    c=Card[:basic].fetch(:trait=>[:right, :table_of_contents], :new=>{})
    c.content='2'
    c.save

  end
end
