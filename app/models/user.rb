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

  before_validation :downcase_email!, :generate_if
  before_save :encrypt_password

  class << self
    def from_email(email)
      User.where(:email=>email.strip.downcase).first
    end

    def from_login(login)       User.where(:login=>login).first                  end
    def from_id(cid)            User.where({:account_id=>cid}).first             end
    def from_user_id(card_id)   User.where(:card_id=>card_id).first              end

    def encrypt(password, salt) Digest::SHA1.hexdigest("#{salt}--#{password}--") end
    def password_required?;     true                                             end
  end

#~~~~~~~ Instance

  def active?()         status=='active'    end
  def blocked?()        status=='blocked'   end
  def built_in?()       status=='system'    end
  def pending?()        status=='pending'   end
  def default_status?() status=='request'   end

  def active ; self.status='active' ; self  end
  def pending; self.status='pending'; self  end
  def block  ; self.status='blocked'; self  end
  def block!
    Rails.logger.warn "block! #{inspect}" ;      block;  save    ; self  end
  def save   ;      super end

  def blocked= arg
    arg != '0' && block || !built_in? && active?
  end

  PW_CHARS = ('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a

  def generate_password
    self.password_confirmation = self.password =
      9.times.map() do PW_CHARS[rand*61] end *''
    #warn "g pw #{self}, #{self.password}"
  end

  def inspect() "<#User##{object_id}:#{password or 'no-pass'}:#{to_s}" end
  def to_s
    "#<#{self.class.name}:#{login}<#{email}>#{status[0,1]}:#{password_required? ? 'R' : ''}#{password.blank? ? 'b' : ''}>"
  end
  def mocha_inspect()   to_s                                                              end
  def downcase_email!()
    #warn "dc email #{self.email}"
    (em = self.email) =~ /[A-Z]/ and em=em.downcase and self.email=em end

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def authenticated? params
    password = params[:password] and password = password.strip and
      crypted_password == encrypt(password) and active?
  end

 protected

  def generate_if
    #warn "gen #{self} if #{password.blank?} && #{password_required?}"
    generate_password if password.blank? && password_required?
  end

  def encrypt password
    self.class.encrypt(password, salt)
  end

  def encrypt_password
    return true if password.blank?
    self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{name}--") if new_record?
    self.crypted_password = encrypt(password)
  end

  def email_required?
    !built_in?
  end

  def password_required?
     !built_in? and !active? and self.class.password_required? and
       (crypted_password.blank? or not password.blank?)
  end

end

