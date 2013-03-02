# -*- encoding : utf-8 -*-
require 'digest'

class User < ActiveRecord::Base

  # Virtual attribute for the unencrypted password
  attr_accessor :password, :name

  validates_presence_of     :card_id
  validates_uniqueness_of   :card_id
  validates_presence_of     :account_id
  validates_uniqueness_of   :account_id
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
    def find_by_email email
      super email.strip.downcase
    end

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
  def block! ;      block;  save    ; self  end
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
  def authenticate card_with_acct, params
    return unless card_with_acct

    if password = params[:password]
      password = password.strip
      card_with_acct.errors.add :account, "Authentication failed." unless crypted_password == encrypt(password)
      card_with_acct.errors.add :account, "Account is blocked." unless active?
    else
      card_with_acct.errors.add :account, "No password."
    end
    card_with_acct.id
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
    !built_in? &&
    !pending?  &&
    #not_openid? &&
    (crypted_password.blank? or not password.blank?)
  end

end

