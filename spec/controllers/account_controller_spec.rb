require File.expand_path('../spec_helper', File.dirname(__FILE__))
include AuthenticatedTestHelper
require 'rr'

describe AccountController do

  describe "#invite" do
    before do
      @msgs=[]
      mock.proxy(Mailer).account_info.with_any_args.times(any_times) { |m|
        @msgs << m
        mock(m).deliver }

      login_as 'joe_admin'

      @email_args = {:subject=>'Hey Joe!', :message=>'Come on in.'}
      post :invite, :account=>{:email=>'joe@new.com'}, :card=>{:name=>'Joe New'},
        :email=> @email_args

      @user_card = Card['Joe New']
      @user_card.should be
      @account_card = @user_card.fetch :trait => :account, :new=>{}

    end

    it 'should create a user' do
      @account_card.should be
      @account_card.new_card?.should be_false
      @user_card.type_id.should == Card::UserID
      @account_card.type_id.should == Card::BasicID
      @new_account=Account.find_by_email('joe@new.com')
      #warn "... #{@account_card.inspect}, #{@user_card.inspect} #{@new_account.inspect}"
      @new_account.should be
      @new_account.account_id.should == @account_card.id
    end

    it 'should send email' do
      @msgs.size.should == 1
      @msgs[0].should be_a Mail::Message
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

    it 'should create a user' do
      post :signup, :account=>{:email=>'joe@new.com'}, :card=>{:name=>'Joe New'}
      new_account = Account.lookup(:email=>'joe@new.com')
      user_card = Card['Joe New']
      new_account.should be
      new_account.card_id.should == user_card.id
      user_card.type_id.should == Card::AccountRequestID
    end

    it 'should send email' do
      # a user requests an account
      post :signup, :account=>{:email=>'joe@new.com'}, :card=>{:name=>'Joe New'}

      @card = Card['Joe New']
      @card.should be
      @card.account.should be

      @msgs.size.should == 1
      @msgs[0].should be_a Mail::Message
    end

    it 'should send email' do
      # a user requests an account
      post :signup, :account=>{:email=>'joe@new.com'}, :card=>{:name=>'Joe New'}

      @msgs.size.should == 1
      # and the admin accepts
      login_as 'joe_admin'
      post :accept, :card=>{:key=>'joe_new'}, :email=>{:subject=>'Hey Joe!', :message=>'Come on in?'}

      @msgs.size.should == 2
      @msgs[0].should be_a Mail::Message
      #warn "msg looks like #{@msgs[0].inspect}"
    end
    
    it 'should detect duplicates' do
      post :signup, :account=>{:email=>'joe@user.com'}, :card=>{:name=>'Joe Scope'}
      #warn "first #{Card['joe scope'].inspect}"

      post :signup, :account=>{:email=>'joe@user.com'}, :card=>{:name=>'Joe Duplicate'}
      
      c=Card['Joe Duplicate']
      #warn "second #{c.inspect}"
      c.should be_nil
    end
  end

  describe "#signin" do
  end

  describe "#signout" do
  end

  describe "#forgot_password" do
    before do
      @msgs = []
      mock.proxy(Mailer).account_info.with_any_args.times(any_times) do |mck|
        @msgs << mck
        mock(mck).deliver
      end

      post :forgot_password, :email=>'joe@user.com'
      assert_response :found
    end

    it 'should send an email to user' do
      @msgs.size.should == 1
      @msgs[0].should be_a Mail::Message
    end


    it "can't login with original pw" do
      post :signin, :email=>'joe@user.com', :password=>'joe_pass'
      assert_response :forbidden
    end
  end
end
