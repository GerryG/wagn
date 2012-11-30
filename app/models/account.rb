
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
      acct = lookup(params) and acct_cd = acct.authenticate(  Card[ acct.account_id ], params )
      Rails.logger.warn "auth? #{params.inspect}, #{acct_cd.inspect} #{acct}"
      acct_cd
    end

    def lookup params
      if email = params[:email]
        email = email.strip.downcase
        find_by_email email
      end
    end

    def get_account account
      if @@session_class===account
        Card[account.account_id]
      else
        acct = ((Card===account) ? account : Card[account])
        # if this isn't a Right::Account yet, fetch it
        unless Card===acct && acct.id == Card::WagnBotID or
           acct and ( acct.right_id == Card::AccountID or
           acct = acct.fetch(:trait=>:account) )
          Rails.logger.warn "no account #{account.inspect} #{acct}" #{caller*"\n"}"
          nil
        else
          acct
        end
      end
    end
  end

  # FIXME: check for this in boot and don't start if newcard?
  # these might be newcard?, but only in migrations
  ANONCARD_ID = Card[Card::AnonID].fetch(:trait=>:account).id
  BOTCARD_ID  = Card[Card::WagnBotID].fetch(:trait=>:account).id

  cattr_accessor :account_class

  @@as_card = nil
  @@session = Card[ANONCARD_ID]

  class << self
    def admin?()
      acid = (ac=as_card).new_card? ? ac.left_id : ac.id
      acid==BOTCARD_ID || acid == Card::WagnBotID
    end

    def reset()            @@session = Card[ANONCARD_ID]; @@as_card = nil               end
    def session()          @@session || Card[ANONCARD_ID]                               end
    def authorized_email() as_card.trunk.account.email                                  end
    def session=(account)  @@session = get_account(account) || Card[ANONCARD_ID]       end
    def as_card()          @@as_card || session                                         end
    # We only need to test for the tag presence for migrations, we are going to  make sure it
    # exists and is indestructable (add tests for that)
    def authorized()       as_card.trunk                                                end
    def as_bot(&block)     as Card::WagnBotID, &block                                   end
    def among?(authzed)    authorized.among? authzed                                    end
    def logged_in?()       session.id != ANONCARD_ID                                    end

    def as given_account
      save_as = @@as_card
      @@as_card = get_account(given_account) || Card[ANONCARD_ID]
      #Rails.logger.info "set ac #{@@as_card.inspect}"

      if block_given?
        value = yield
        @@as_card = save_as
        return value
      #else fail "BLOCK REQUIRED with Card#as"
      end
    end
 
    def no_logins?
      cache = Card.cache
      !!(rd=cache.read('no_logins')) ? rd : cache.write( 'no_logins',
               (Card.search({:right=>Card::AccountID, :left=>{:type=>Card::UserID }}).count == 0 ))
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

