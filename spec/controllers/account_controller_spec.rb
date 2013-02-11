require File.expand_path('../spec_helper', File.dirname(__FILE__))
include AuthenticatedTestHelper
require 'rr'

describe AccountController, "account functions" do
  it "should signin" do
    #post :create, :id=>'Session', :account => {:email => 'joe@user.org', :password => 'joe_pass' }
    post :signin, :account => {:email => 'joe@user.org', :password => 'joe_pass' }
  end

  it "should signout" do
    login_as 'joe_user'
    Account.current.account.card_id.should == Card['joe user'].id
    
    #signout
    post :signout
    Account.current_id.should == Card::AnonID

  end
  
  describe "#invite" do
    before do
      @msgs=[]
      mock.proxy(Mailer).account_info.with_any_args.times(any_times) { |m|
        @msgs << m
        mock(m).deliver }

      login_as 'joe_admin'
      @jadmin = Card['joe admin']
      @ja_email = @jadmin.account.email

      @email_args = {:subject=>'Hey Joe!', :message=>'Come on in.'}
      post :invite, :account=>{:email=>'joe@new.com'}, :card=>{:name=>'Joe New'},
        :email=> @email_args

      @cd_with_acct = Card['Joe New']
      @new_account = User.where(:email=>'joe@new.com').first
      @auth_card = Card['Joe new']
    end

    it 'should create a user' do
      @new_account.should be_instance_of User
      #warn "ne user #{@auth_card.inspect}, #{@new_account.inspect}"
      #@auth_card.type_id.should == Card::UserID
      @new_account=Account.find_by_email('joe@new.com')
      #warn "... #{acct_card.inspect}, #{@auth_card.inspect} #{@new_account.inspect}"
      @new_account.should be
      @new_account.card_id.should == @auth_card.id
    end

    it "should invite" do
      @auth_card.should be
      @auth_card.id.should be
    end

    it 'should send email' do
      @msgs.size.should == 1
      @msgs[0].should be_a Mail::Message
      # FIXME: test may need updating, but we want cases that test the parsing
      #@msgs[0].from.should == "#{@jadmin.name} <#{@ja_email}>"
      @msgs[0].from.should == [ @ja_email ]
    end
  end

  describe "#signup" do
    before do
      # to make it send signup mail, and mock the mailer methods
      Account.as_bot { Card.create! :name=>'*request+*to', :content=>'joe@user.com' }
      @msgs=[]
      mock.proxy(Mailer).signup_alert.with_any_args.times(any_times) do |mck|
        @msgs << mck
        mock(mck).deliver
      end
      mock.proxy(Mailer).account_info.with_any_args.times(any_times) do |mck|
        @msgs << mck
        mock(mck).deliver
      end

    end

    it 'should signout' do
      post :signout
      Account.current_id.should == Card::AnonID
    end
    
    it 'should create a user' do
      #warn "who #{Account.current.inspect}"
      post :signup, :account=>{:email=>'joe@new.com'}, :card=>{:name=>'Joe New'}
      new_user = User.where(:email=>'joe@new.com').first
      @cd_with_acct = Card['Joe New']
      new_user.should be
      new_user.card_id.should == @cd_with_acct.id
      new_user.pending?.should be_true
      @cd_with_acct.type_id.should == Card::AccountRequestID
    end

    it 'should send email' do
      post :signup, :account=>{:email=>'joe@new.com'}, :card=>{:name=>'Joe New'}
      login_as 'joe admin'

      post :accept, :card=>{:key=>'joe_new'}, :email=>{:subject=>'Hey Joe!', :message=>'Can I Come on in?'}

      @msgs.size.should == 1
      # and the admin accepts
      login_as 'joe_admin'
      post :accept, :card=>{:key=>'joe_new'}, :email=>{:subject=>'Hey Joe!', :message=>'Come on in?'}

      @msgs.size.should == 2
      @msgs[0].should be_a Mail::Message
      #warn "msg looks like #{@msgs[0].inspect}"
    end

    it "should create an account request" do
      c = Card['Joe New'].should be
      c.type_id.should == Card::AccountRequestID
      c.to_user.blocked?.should be_true
    end

    it 'should detect duplicates' do
      post :signup, :account=>{:email=>'joe@user.com'}, :card=>{:name=>'Joe Scope'}
      post :signup, :account=>{:email=>'joe@user.com'}, :card=>{:name=>'Joe Duplicate'}
      
      c=Card['Joe Duplicate']
      #warn "second #{c.inspect}"
      c.should be_nil
    end

    it "should accept" do
      #put :update, :id=>"Joe New", :account=>{:status=>'active'}
      put :accept, :card=>{:key => "joe_new"}, :account=>{:status=>'active'}

      (@auth_card = Card['Joe New']).should be
      (@new_account = @auth_card.account).should be
      @new_account.card_id.should == @auth_card.id
      @auth_card.type_id.should == Card::UserID
      @msgs.size.should == 2
    end
  end

  describe "#signin" do
  end

  describe "#signout" do
  end

  describe "#forgot_password" do
    before do
      @msgs=[]
      mock.proxy(Mailer).account_info.with_any_args.times(any_times) { |m|
        @msgs << m
        mock(@mail = m).deliver }

      @email='joe@user.com'
      @juser=User.where(:email=>@email).first
      post :forgot_password, :email=>@email
    end

    it 'should send an email to user' do
      @msgs.size.should == 1
      @msgs[0].should be_a Mail::Message
      # FIXME: shouldn't it be simpler? @msgs[0].from.should == "Anonymous"
      @msgs[0].from.should == "Anonymous <>"
    end


    it "can't login now" do
      post :signin, :email=>'joe@user.com', :password=>'joe_pass'
    end
  end
end
