require File.expand_path('../spec_helper', File.dirname(__FILE__))
include AuthenticatedTestHelper
require 'rr'

describe CardController, "account functions" do
  before(:each) do
    login_as 'joe_user'
    #@user_card = Account.authorized
    @user_card = Account.user_card
    warn "auth is #{@user_card.inspect}"
  end

  it "should signin" do
    post :create, :id=>'Session', :account => {:email => 'joe@user.org', :password => 'joe_pass' }
  end

  it "should signout" do
    delete :delete, :id=>'Session'
    Card[:session].should be
  end

  describe "invite: POST *account" do
    before do
      @msgs=[]
      mock.proxy(Mailer).account_info.with_any_args.times(any_times) { |m|
        @msgs << m
        mock(m).deliver }

      login_as 'joe_admin'

      @email_args = {:subject=>'Hey Joe!', :message=>'Come on in.'}
      post :create, :id=>'*account', :account=>{:email=>'joe@new.com'}, :card=>{:name=>'Joe New'}, :email=> @email_args

      @user_card = Card['Joe New']
      @new_user = User.where(:email=>'joe@new.com').first

    end

    it "should invite" do
      @user_card.should be
    end

  end

  describe "signup, send mail and accept" do
    before do
      @msgs=[]
      mock.proxy(Mailer).account_info.with_any_args.times(any_times) do |m|
        @msgs << m
        mock(m).deliver
      end

      delete :delete, :id=>'Session'

      Account.user_id.should == Card::AnonID
      post :create, :id=>'*account', :card => {:name => "Joe New"}, :account=>{:email=>"joe_new@user.org", :password=>'new_pass', :password_confirmation=>'new_pass'}
    end

    it 'should send email' do
      @msgs.size.should == 1
      @msgs[0].should be_a Mail::Message
      # should be from
    end

    it "should create an account request" do
      c = Carc['Joe New'].should be
      c.type_id.should == Card::AccountRequestID
      c.to_user.blocked?.should be_true
    end

    it "should accept" do
      put :update, :id=>"Joe New", :account=>{:status=>'active'}

      @user_card = Card['Joe New'].should be
      @new_user = @user_user.to_user.should be
      @new_user.card_id.should == @user_card.id
      @user_card.type_id.should == Card::UserID
      @msgs.size.should == 2
    end
  end

  describe "#forgot_password" do
    before do
      @msgs=[]
      mock.proxy(Mailer).account_info.with_any_args.times(any_times) do |m|
        @msgs << m
        mock(@mail = m).deliver 
      end

      @email='joe@user.com'
      @juser=User.where(:email=>@email).first
      put :update, :id=>'*account', :email=>@email
    end

    it 'should send an email to user' do
      @msgs.size.should == 1
      @msgs[0].should be_a Mail::Message
    end


    it "can't login now" do
      post :create, :id=>'Session', :email=>'joe@user.com', :password=>'joe_pass'
    end
  end
end
