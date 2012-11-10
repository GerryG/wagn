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

  before_validation :downcase_email!
  before_save :encrypt_password
  after_save :reset_cache

  class << self
    def from_email(email) User.where(:email=>email.strip.downcase).first           end
    def from_login(login) User.where(:login=>login).first                          end
    def from_id(card_id)  User.where(:card_id=>card_id).first                      end
    def cache()           Wagn::Cache[User]                                        end

    # Encrypts some data with the salt.
    def encrypt(password, salt)
      r= Digest::SHA1.hexdigest("#{salt}--#{password}--")
      Rails.logger.warn "encrypt #{salt}, #{password}, #{r}"; r
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
      self.cache.write key, usr
      code = Wagn::Codename[card_id].to_s and code != key and self.cache.write(code.to_s, usr)
      usr
    end
  end

#~~~~~~~ Instance

  def save_card args, email_args={}
    raise "anon creates?" if self.card_id == 709
    #Rails.logger.info  "create with(#{inspect}, #{args.inspect})"
    @card = if Card===args
        args.type_id = Card::UserID unless args.type_id == Card::UserID ||
                                    args.type_id == Card::AccountRequestID
        args
      else
        Card.fetch_or_new args[:name], args
      end

    #self.login ||= @card.key # We can keep the login, but better is the card_id of the User (card with account)
    # it would just be a copy of Card[card_id].trunk_id
    # then login isn't used anymore
    Account.as_bot do
      #Rails.logger.debug "save_card saving #{inspect}, #{args.inspect}, #{Account.account.inspect}"
      active() if self.status.blank?
      generate_password if password.blank?

      begin
        #Rails.logger.info "save with card #{@card.inspect}, #{self.inspect}"
        User.transaction do
          @card = @card.refresh if @card.frozen?
          newcard = @card.new_card?
          @card.save
          Rails.logger.debug "save with_card #{inspect}, cd:#{@card.inspect}"
          @card.errors.each { |key,err| self.errors.add key,err }
          if (cn=@card.cardname).simple? || Codename[cn.right] == Card::AccountID
            @card = @card.trait_card :account
            newcard ||= @card.new_card?
            @card.save
            @card.errors.each { |key,err| self.errors.add key,err }
          end

          self.card_id = @card.id
          Rails.logger.info "save user #{inspect}"
          if newcard && self.errors.any? || !(sv=save)
            self.card_id=nil; save
            Rails.logger.warn "RB #{sv}, #{inspect} #{caller*"\n"}"
            Rails.logger.warn "RB #{self.errors.inspect}"
            raise ActiveRecord::Rollback # ROLLBACK should undo any changes made
          end
          #Rails.logger.debug "save with_card error? #{inspect}, card:#{@card.inspect}"
          #Rails.logger.debug "save with_card error #{self.errors.to_a.inspect}, card:#{@card.inspect}" if self.errors.any?
          true
        end
      rescue Exception => e
        Rails.logger.info "save with card failed. #{e.inspect},  #{@card.inspect} Bt:#{e.backtrace*"\n"}"
        warn "save with card failed. #{e.inspect},  #{@card.inspect} Bt:#{e.backtrace*"\n"}"
      end

      self.send_account_info(email_args) if self.errors.empty? && !email_args.empty?
    end
    @card
  end

  def reset_cache
    self.class.cache.reset
    #Rails.logger.debug "User reset cache"
    true
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

