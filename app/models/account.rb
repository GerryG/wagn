# -*- encoding : utf-8 -*-
class Account
  # This will probably have a hash of possible account classes and a value for the class
  @@as_card = @@as_id = @@current = nil
  @@current_id        = Card::AnonID  # this should never be nil, even when session[:user] is nil
  @@account_class        = User

  # not used by us (yet), but for the API:
  # Account.account_class = MyUserClass
  cattr_accessor :account_class
  cattr_reader :current_id

  class << self
    # can these just be delegations:

    def [] id
      @@account_class.find_by_card_id id or
        @@account_class.find_by_account_id id
    end

    def new *args            ; @@account_class.new(*args)            end
    def find_by_email email  ; @@account_class.find_by_email(email)  end
    #def find_by_login login  ; @@account_class.find_by_login(login)  end
    def find_by_account_id id; @@account_class.find_by_account_id id end
    def find_by_card_id id   ; @@account_class.find_by_card_id id    end

    # return the account card
    def authenticate params
      #Rails.logger.warn "A.auth? #{params.inspect}"
      acct = lookup(params) and acct.authenticate(  card_with_acct = Card[ acct.card_id ], params )
      card_with_acct
    end

    def lookup params
      if email = params[:email]
        email = email.strip.downcase
        find_by_email email
      end
    end

    def get_user_id acct
      case acct
      when NilClass, Integer; acct
      when @@account_class     ; acct.card_id
      when Card             ; acct.id
      else                    Card[acct].send_if :id
      end
    end

    def as_card
      if @@as_card.nil? || (!@@as_id.nil? && @@as_card.id != @@as_id)
        @@as_card = Card[@@as_id]
      else @@as_card
      end
      r=@@as_card || current
      #warn "acard #{@@as_id}, #{current_id} R:#{r.inspect}"; r
    end

    def current
      if @@current.nil? || @@current.id != current_id
        @@current = Card[current_id]
      else
      #Rails.logger.warn "current #{current_id}, #{@@as_id}, #{@@current.inspect}"
        @@current
      end
    end

    def reset              ; current_id = Card::AnonID; @@as_id = nil end
    def current_id= card_id; @@current_id = card_id || Card::AnonID    end
    def as_id              ; @@as_id || current_id                    end
    def as_bot &block      ; as Card::WagnBotID, &block               end

    def among? authzed     ; as_card.among? authzed                   end
    def logged_in?         ; current_id != Card::AnonID               end
    def admin?             ; as_id == Card::WagnBotID                 end

    def as given_account
      save_as_id, save_card = @@as_id, @@as_card
      @@as_id = get_user_id(given_account) || Card::AnonID
      @@as_card = nil
      #Rails.logger.info "set ac #{current.inspect}"

      if block_given?
        value = yield
        @@as_id, @@as_card = save_as_id, save_card
        return value
      #else fail "BLOCK REQUIRED with Card#as"
      end
    end
 
    def create_ok?
      base  = Card.new :name=>'dummy*', :type_id=>Card::UserID
      trait = Card.new :name=>"dummy*+#{Card[:account].name}"
      base.ok?(:create) && trait.ok?(:create)
    end

    def first_login!
      Card.cache.delete 'no_logins'
    end

    def first_login?
      cache = Card.cache
      !( if cval=cache.read('no_logins')
           cval
         else
           cache.write( 'no_logins', Card.search({:right=>Card::AccountID, :left=>{:type=>Card::UserID }}).count == 0 )
         end )
    end

    def always_ok?
      return true if admin? #cannot disable
      card_id = Account.as_id
 
      always = Card.cache.read('ALWAYS') || {}
      if always[card_id].nil?
        always = always.dup if always.frozen?
        always[card_id] = !!Card[card_id].all_roles.detect{|r|r==Card::AdminID}
        Card.cache.write 'ALWAYS', always
       end
     #warn "always #{card_id}, #{always[card_id].inspect}"
     always[card_id]
    end

  protected
    # PERMISSIONS

    # FIXME stick this in session? cache it somehow??
    def ok_hash
      card_id = Account.as_id
      ok_hash = Card.cache.read('OK') || {}
      if ok_hash[card_id].nil?
        ok_hash = ok_hash.dup if ok_hash.frozen?
        ok_hash[card_id] = begin
            Card[card_id].all_roles.inject({:role_ids => {}}) do |ok,role_id|
              ok[:role_ids][role_id] = true
              ok
            end
          end || false
        Card.cache.write 'OK', ok_hash
        warn "write okh #{card_id}, #{ok_hash[card_id].inspect}"
      end
      #warn "okh #{card_id}, #{ok_hash[card_id].inspect}"
      ok_hash[card_id]
    end

  public

    # FIXME: Shouldn't this be someplace else?  Card? a Model module?
    NON_CREATEABLE_TYPES = %w{ account_request setting set }

    def createable_types
      as_bot { Card.search :type=>Card::CardtypeID, :return=>:name,
                 :not => { :codename => ['in'] + NON_CREATEABLE_TYPES } }.
        reject { |name| !Card.new( :type=>name ).ok? :create }.sort
    end
  end

end

