
class Account
  # This will probably have a hash of possible account classes and a value for the class
  @@as_card = @@as_id = @@current = nil
  @@current_id        = Card::AnonID  # this should never be nil, even when session[:user] is nil
  @@user_class        = User

  # not used by us (yet), but for the API:
  # Account.user_class = MyUserClass
  cattr_accessor :user_class

  class << self
    # can these just be delegations:

    def [] id
      @@user_class.find_by_card_id id or
        @@user_class.find_by_account_id id
    end

    def new *args            ; @@user_class.new(*args)            end
    def find_by_email email  ; @@user_class.find_by_email(email)  end
    #def find_by_login login  ; @@user_class.find_by_login(login)  end
    def find_by_account_id id; @@user_class.find_by_account_id id end
    def find_by_card_id id   ; @@user_class.find_by_card_id id    end

    # return the account card
    def authenticate params
      Rails.logger.warn "A.auth? #{params.inspect}"
      acct = lookup(params) and acct.authenticate(  card_with_acct = Card[ acct.card_id ], params )
      Rails.logger.warn "auth? #{params.inspect}, #{card_with_acct.inspect} #{acct}"
      card_with_acct
    end

    def lookup params
      if email = params[:email]
        email = email.strip.downcase
        find_by_email email
      end
    end

    def get_user_id session
      case session
      when NilClass, Integer; session
      when @@user_class     ; session.card_id
      when Card             ; session.id
      else                    Card[session].send_if :id
      end
    end
    def admin?()
      as_id == Card::WagnBotID
    end

    def as_card
      if @@as_card.nil? || @@as_card.id != @@as_id
        @@as_card = Card[@@as_id]
      else @@as_card
      end
    end

    def current
      as_card || if @@current.nil? || @@current.id != @@current_id
        @@current = Card[@@current_id]
      else
 raise "???? #{@@current.inspect} .. #{@@curent_id} >#{current_id}" if @@current.id != @@current_id
      Rails.logger.warn "current #{@@current_id}, #{@@as_id}, #{@@current.inspect}"
        @@current
      end
    end

    def current_id            ; @@as_id || @@current_id                    end
    def reset                 ; @@current_id = Card::AnonID; @@as_id = nil end
    def session               ; Card[@@current_id]                         end
    def current_id= card_id; @@current_id = card_id || Card::AnonID     end
    def as_id                 ; @@as_id || @@current_id                    end
    def as_bot &block         ; as Card::WagnBotID, &block                    end

    def among? authzed        ; current.among? authzed                     end
    def logged_in?            ; @@current_id != Card::AnonID               end

    def as given_account
      save_as_id = @@as_id
      @@as_id = get_user_id(given_account) || Card::AnonID
      #Rails.logger.info "set ac #{current.inspect}"

      if block_given?
        value = yield
        @@as_id = save_as_id
        return value
      #else fail "BLOCK REQUIRED with Card#as"
      end
    end
 
    def no_logins?
      cache = Card.cache
      !!(rd=cache.read('no_logins')) ? rd : cache.write( 'no_logins',
               (Card.search({:right=>Card::AccountID, :left=>{:type=>Card::UserID }}).count == 0 ))
    end

    def first_login?()
       Card.cache.first_login? || 
         Card.cache.first_login= @@user_class.where(:status => 'active').count > 2
    end

    def always_ok?
      return true if admin? #cannot disable
      as_id = current_id
 
      always = Card.cache.read('ALWAYS') || {}
      if always[as_id].nil?
        always = always.dup if always.frozen?
        always[as_id] = !!Card[as_id].all_roles.detect{|r|r==Card::AdminID}
        Card.cache.write 'ALWAYS', always
       end
     always[as_id]
    end

  protected
    # PERMISSIONS

    # FIXME stick this in session? cache it somehow??
    def ok_hash
      as_id = current_id
      ok_hash = Card.cache.read('OK') || {}
      if ok_hash[as_id].nil?
        ok_hash = ok_hash.dup if ok_hash.frozen?
        ok_hash[as_id] = begin
            Card[as_id].all_roles.inject({:role_ids => {}}) do |ok,role_id|
              ok[:role_ids][role_id] = true
              ok
            end
          end || false
        Card.cache.write 'OK', ok_hash
      end
      ok_hash[as_id]
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

