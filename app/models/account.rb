
class Account
  # This will probably have a hash of possible account classes and a value for the class
  @@session_class = User

  class << self
    # can these just be delegations:

    def [] id
      @@session_class.find_by_card_id id or
        @@session_class.find_by_account_id id
    end

    def new *args            ; @@session_class.new(*args)            end
    def find_by_email email  ; @@session_class.find_by_email(email)  end
    #def find_by_login login  ; @@session_class.find_by_login(login)  end
    def find_by_account_id id; @@session_class.find_by_account_id id end
    def find_by_card_id id   ; @@session_class.find_by_card_id id    end

    # return the account card
    def authenticate params
      Rails.logger.warn "A.auth? #{params.inspect}"
      acct = lookup(params) and card_with_acct_id = acct.authenticate(  Card[ acct.card_id ], params )
      Rails.logger.warn "auth? #{params.inspect}, #{card_with_acct_id.inspect} #{acct}"
      card_with_acct_id
    end

    def lookup params
      if email = params[:email]
        email = email.strip.downcase
        find_by_email email
      end
    end

    def get_session_id session
      case session
      when NilClass, Integer; session
      when @@session_class;   session.card_id
      when Card;              session.id
      else               Card[session].send_if :id
      end
    end
  end

  cattr_accessor :account_class

  @@as_card_id = nil
  @@session_id = Card::AnonID

  class << self
    def admin?()
      as_card_id == Card::WagnBotID
    end

    def reset()            @@session_id = Card::AnonID; @@as_card_id = nil               end
    def session()          Card[@@session_id]                               end
    def authorized_email() authorized.account.email                                  end
    def session_id=(account)  @@session_id = get_session_id(account) || Card::AnonID       end
    def as_card_id()          @@as_card_id || @@session_id                                         end
    # We only need to test for the tag presence for migrations, we are going to  make sure it
    # exists and is indestructable (add tests for that)
    def authorized()       Card[as_card_id]                                                end
    def as_bot(&block)     as Card::WagnBotID, &block                                   end
    def among?(authzed)    authorized.among? authzed                                    end
    def logged_in?()       @@session_id != Card::AnonID                                    end

    def as given_account
      save_as_id = @@as_card_id
      @@as_card_id = get_session_id(given_account) || Card::AnonID
      #Rails.logger.info "set ac #{authorized.inspect}"

      if block_given?
        value = yield
        @@as_card_id = save_as_id
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
         Card.cache.first_login= @@session_class.where(:status => 'active').count > 2
    end

    def always_ok?
      return true if admin? #cannot disable
      as_id = authorized.id
 
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
      as_id = authorized.id
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

