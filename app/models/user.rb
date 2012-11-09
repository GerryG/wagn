# -*- encoding : utf-8 -*-
require 'digest/sha1'

class User < ActiveRecord::Base
  #FIXME: THIS WHOLE MODEL SHOULD BE CALLED ACCOUNT
  # actually, most of this is elsewhere already, what remains is the AR model part for storing
  # local auth information.  We will just replace this with other plugins (auth suppliers)
  # and this one get's a better name if we still use it (WagnAccount maybe)

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
#  validates_uniqueness_of   :salt, :allow_nil => true

  before_validation :downcase_email!
  before_save :encrypt_password
  after_save :reset_cache

  class << self
    def from_email(email) User.where(:email=>email).first                          end
    def from_login(login) User.where(:login=>login).first                          end
    def from_id(card_id)  User.where(:card_id=>card_id).first or Session::ANONCARD end
    def cache()           Wagn::Cache[User]                                        end

    # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
    def authenticate email, password
      (user = User.from_email(email.strip.downcase) and user.authenticated?(password.strip)) ? user : nil
    end

    # Encrypts some data with the salt.
    def encrypt(password, salt)
      Digest::SHA1.hexdigest("#{salt}--#{password}--")
    end

    # User caching, needs work
    def [] key
      #Rails.logger.info "Looking up USER[ #{key}]"

      key = 3 if key == :first
      @card = Card===key ? key : Card[key]
      key = case key
        when Integer; "##{key}"
        when Card   ; key.key
        when Symbol ; key.to_s
        when String ; key
        else raise "bad class for user key #{key.class}"
        end

      usr = self.cache.read(key)
      return usr if usr

      # cache it (on codename too if there is one)
      card_id ||= @card && @card.id
      self.cache.write(key, usr)
      code = Wagn::Codename[card_id].to_s and code != key and self.cache.write(code.to_s, usr)
      usr
    end
  end

#~~~~~~~ Instance

  def create_card card_args, email_args={}
    card_args[:type_id] ||= Card::UserID
    Rails.logger.warn  "create with(#{inspect}, #{card_args.inspect}, #{email_args.inspect})"
    @card = Card.fetch_or_new(card_args[:name], card_args)
    login ||= @card.name
    Rails.logger.warn "create with >>#{Session.account.name}"
    Session.as_bot do
      Rails.logger.warn "cwa #{inspect}, #{inspect}, #{card_args.inspect}, #{Session.account.inspect}"
      active if default?
      Rails.logger.warn "user is #{inspect}" unless email
      generate_password if password.blank?
      save_with_card(@card)
      send_account_info(email_args) if errors.empty? && !email_args.empty?
    end
    @card
  end

  def reset_cache
    self.class.cache.reset
    Rails.logger.warn "ricache"
    true
  end

  def save_with_card card
    Rails.logger.warn "save with card #{card.inspect}, #{self.inspect}"
    User.transaction do
      card = card.refresh if card.frozen?
      newcard = card.new_card?
      card.save
      Rails.logger.warn "save with_card #{User.count}, #{card.id}, #{card.inspect}"
      card.errors.each do |key,err|
        self.errors.add key,err
      end
      acard = card.trait_card :account
      newcard ||= acard.new_card?
      acard.save
      acard.errors.each do |key,err|
        self.errors.add key,err
      end

      Rails.logger.warn "saving #{inspect}"
      self.card_id = acard.id
      save
      Rails.logger.warn "saved? pwr[#{password.blank?}]:pwrq#{password_required?}, Emrq:#{email_required?}, errs:#{self.errors.size}, NC:#{newcard}, u:#{inspect}"
      if newcard && self.errors.any?
        card.delete #won't the rollback take care of this?  if not, should Wagn Bot do it?
        self.card_id=nil
        save
        Rails.logger.warn "swc rb #{self}, #{acard.inspect}"
        raise ActiveRecord::Rollback
      end
      Rails.logger.warn "swc true #{card_id}, #{acard.inspect}"
      true
    end
  rescue Exception => e
    Rails.logger.info "save with card failed. #{e.inspect},  #{card.inspect} Bt:#{e.backtrace*"\n"}"
    warn "save with card failed. #{e.inspect},  #{card.inspect} Bt:#{e.backtrace*"\n"}"
  end

  def accept card, email_args
    Session.as_bot do #what permissions does approver lack?  Should we check for them?
      card = card.trunk and card.type_id = Card::UserID # Invite Request -> User
      active
      generate_password
      save_with_card(card)
    end
    #card.save #hack to make it so last editor is current user.
    self.send_account_info(email_args) if self.errors.empty?
  end

  def send_account_info args
    #return if args[:no_email]
    raise(Wagn::Oops, "subject is required") unless (args[:subject])
    raise(Wagn::Oops, "message is required") unless (args[:message])
    begin
      message = Mailer.account_info(self, args[:subject], args[:message])
      message.deliver
    rescue Exception=>e
      Rails.logger.info "ACCOUNT INFO DELIVERY FAILED: \n #{args.inspect}\n   #{e.message}, #{e.backtrace*"\n"}"
    end
  end

  def active?()   status=='active'  end
  def blocked?()  status=='blocked' end
  def built_in?() status=='system'  end
  def pending?()  status=='pending' end
  def default?()  status=='request' end

  def active()  self.status='active'  end
  def pending() self.status='pending' end
  def block()   self.status='blocked' end
  def block!()  block; save           end

  def blocked=(arg) arg != '0' && block || !built_in? && active end

  def authenticated? password
    crypted_password == encrypt(password) and active?
  end

  PW_CHARS = ('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a

  def generate_password
    self.password_confirmation = self.password =
      9.times.map() do PW_CHARS[rand*61] end *''
  end

  def to_s()            "#<#{self.class.name}:#{login}<#{email}>>"                      end
  def mocha_inspect()   to_s                                                           end
  def downcase_email!()
    (em = self.email) =~ /[A-Z]/ and em=em.downcase and self.email=em
    Rails.logger.warn "dwnc #{em}"
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
    Rails.logger.warn "pw? #{built_in?}, #{pending?}, #{crypted_password.blank?} or not #{password.blank?}"
     !built_in? && !pending?  &&
      #not_openid? &&
     (crypted_password.blank? or not password.blank?)
  end

end

