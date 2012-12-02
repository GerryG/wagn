require File.expand_path('../spec_helper', File.dirname(__FILE__))
include AuthenticatedTestHelper
include EmailSpec::Helpers
include EmailSpec::Matchers

describe Mailer do
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "utf-8"
  #include ActionMailer::Quoting

  before do
    #FIXME: from addresses are really Account.session, not Account.as based, but
    # these tests are pretty much all using the Account.as, not logging in.
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  #
  ## see notifier test for data used in these tests
  # FIXME: the cache is not cleared properly between tests.  if the order changes
  #  (ie try renamed change notice below to change_notice) then *notify+*from gets stuck on.
  context "account info, new password" do # forgot password
    before do
      c=Card['sara']
      Account.session = c.fetch :trait => :account
      @user = c.account
      @user.generate_password
      @email = Mailer.account_info c, {:to=>@user.email, :password=>@user.password,
        :subject=>"New password subject", :message=>"Forgot my password"}
    end

    context "new password message" do
      it "is addressed to users email" do
        @email.should deliver_to(@user.email)
      end

      it "is from Wag bot email" do  # I think logged in user is right here, so anon ...
        Account.session = Card[Account.ANONCARD_ID]
        @email.should deliver_from("Wagn Bot <no-reply@wagn.org>")
      end

      it "has subject" do
        @email.should have_subject /^New password subject$/
      end

      it "sends the right email" do
        #@email.should have_body_text /Account Details\b.*\bPassword: *[0-9A-Za-z]{9}$/m
        @email.should have_body_text /Account Details.*\bPassword: *[0-9A-Za-z]{9}$/m
      end
    end
  end

  describe "flexmail" do
    # FIXME: at least two tests should be here, with & w/o attachment.
  end

  private
    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/user_notifier/#{action}")
    end

    def encode(subject)
      quoted_printable(subject, CHARSET)
    end

end
