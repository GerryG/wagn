# -*- encoding : utf-8 -*-
require 'digest/sha1'

class User < ActiveRecord::Base
  #FIXME: THIS WHOLE MODEL SHOULD BE CALLED ACCOUNT
  # The codename and constant Account, :account, etc. is used for +*account
  # This model is used by Account as a provider and will
  # be externalized next as a Warden provider
  # maybe WagnAccount ?

  # Virtual attribute for the unencrypted password
  attr_accessor :password, :name

  validates_presence_of     :email, :if => :email_required?
  validates_format_of       :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i  , :if => :email_required?
  validates_length_of       :email, :within => 3..100,   :if => :email_required?
  validates_uniqueness_of   :email, :scope=>:login,      :if => :email_required?
  validates_presence_of     :password,                   :if => :password_required?
  validates_presence_of     :password_confirmation,      :if => :password_required?
  validates_length_of       :password, :within => 5..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?

  before_validation :downcase_email!
  before_save :encrypt_password

  class << self
    def from_email(email) User.where(:email=>email.strip.downcase).first           end
    def from_login(login) User.where(:login=>login).first                          end
    def from_id(card_id)  User.where(:account_id=>card_id).first                   end

    # Encrypts some data with the salt.
    def encrypt(password, salt)
      r= Digest::SHA1.hexdigest("#{salt}--#{password}--")
      Rails.logger.warn "encrypt #{salt}, #{password}, #{r}"; r
    end

  end

#~~~~~~~ Instance

  def save_card args, email_args={}
    #Rails.logger.info  "create with(#{inspect}, #{args.inspect})"
    @card = Card===args ?  args : Card.fetch_or_new(args[:name], args)
    #warn "card: #{@card.inspect}"

    #Rails.logger.debug "save_card saving #{inspect}, #{args.inspect}, #{Account.session.inspect}"
    active() if status.blank?
    generate_password if password.blank?

    Account.as_bot do
      begin
        #warn "save with card #{@card.inspect}, #{inspect}"
        User.transaction do
          @card = @card.refresh
          @card.type_id = Card::UserID unless @card.type_id == Card::UserID ||
                                      @card.type_id == Card::AccountRequestID
          newcard = @card.new_card?
          @card.save
          #warn "save with_card #{inspect}, cd:#{@card.inspect}"
          @card.errors.each { |key,err| errors.add key,err }
          if (cn=@card.cardname).simple? || Codename[cn.right] == Card::AccountID
            @account = @card.fetch_or_new_trait :account
            newcard ||= @account.new_card?
            @account.save
            @account.errors.each { |key,err| errors.add key,err }
          end

          self.card_id = @card.id
          self.account_id = @account.id
          #warn "save user #{inspect}"
          if newcard && errors.any? || !(sv=save)
            self.account_id=nil; save
            Rails.logger.warn "RB #{sv}, #{inspect} #{caller*"\n"}"
            Rails.logger.warn "RB #{errors.inspect}"
            raise ActiveRecord::Rollback # ROLLBACK should undo any changes made
          end
          #Rails.logger.debug "save with_card error? #{inspect}, card:#{@card.inspect}"
          #Rails.logger.debug "save with_card error #{errors.to_a.inspect}, card:#{@card.inspect}" if errors.any?
          true
        end
      rescue Exception => e
        Rails.logger.info "save with card failed. #{e.inspect},  #{@card.inspect} Bt:#{e.backtrace*"\n"}"
        warn "save with card failed. #{e.inspect},  #{@card.inspect} Bt:#{e.backtrace*"\n"}"
      end

      self.send_account_info(email_args) if errors.empty? && !email_args.empty?
    end
    @card
  end

  def accept card, email_args
    Account.as_bot do #what permissions does approver lack?  Should we check for them?
      card = card.trunk and card.type_id = Card::UserID # Invite Request -> User
      active
      generate_password
      save_card(card)
    end
    send_account_info(email_args) if self.errors.empty?
  end

  def send_account_info args
    #return if args[:no_email]
    [:subject, :message].each {|r| args[r] or raise Wagn::Oops, "#{r} is requires" }
    begin
      message = Mailer.account_info self, args
      message.deliver
    rescue Exception=>e
      Rails.logger.info "ACCOUNT INFO DELIVERY FAILED: \n #{args.inspect}\n   #{e.message}, #{e.backtrace*"\n"}"
    end
  end

  def active?()         status=='active'  end
  def blocked?()        status=='blocked' end
  def built_in?()       status=='system'  end
  def pending?()        status=='pending' end
  def default_status?() status=='request' end

  def active()     self.status='active'   end
  def pending()    self.status='pending'  end
  def block()      self.status='blocked'  end
  def block!()          block; save       end

  def blocked=(arg) arg != '0' && block || !built_in? && active end

  PW_CHARS = ('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a

  def generate_password
    self.password_confirmation = self.password =
      9.times.map() do PW_CHARS[rand*61] end *''
  end

  def to_s()            "#<#{self.class.name}:#{login}<#{email}>>"                        end
  def mocha_inspect()   to_s                                                              end
  def downcase_email!() (em = self.email) =~ /[A-Z]/ and em=em.downcase and self.email=em end

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def authenticated? params
    r=(
    password = params[:password].strip and crypted_password == encrypt(password) and active?
    ) ; Rails.logger.warn "auth? #{params[:password]}, #{crypted_password} #{active?} R:#{r}"; r
  end

 protected
  def encrypt(password) self.class.encrypt(password, salt)                             end

  def encrypt_password
    Rails.logger.warn "epw #{password.blank?}"
    return true if password.blank?
    self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
    self.crypted_password = encrypt(password)
    Rails.logger.warn "epw #{crypted_password.blank?}"
    true
  end

  def email_required?() !built_in?  end

  def password_required?()
     !built_in? && !pending?  &&
      #not_openid? &&
     (crypted_password.blank? or not password.blank?)
  end

end

