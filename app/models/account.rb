class Account
  # FIXME: check for this in boot and don't start if newcard?
  # these might be newcard?, but only in migrations
  ANONCARD = Card[Card::AnonID].fetch_trait :account
  BOTCARD  = Card[Card::WagnBotID].fetch_trait :account

  # This will probably have a hash of possible account classes and a value for the class
  @@session_class = User
  # FIXME: Probably should use nil as the 'account' for Anonymous (Card/codename)
  # but tests depend on this being same class (User) as other accounts
  # It shouldn't be a Card, and if User can be replaced, does each plugin need an Anonymous or
  # we just use nil for that function.  There is a similar issue for WagnBot, it depends on
  # User if it has an account, but if it doesn't we will need a dummy class for this
  # For now find it by account_id in User
  ANONUSER = User.from_id ANONCARD.id

  cattr_accessor :account_class

  @@as_card = nil
  @@session = ANONCARD

  class << self
    def from_params params
      if login = params[:login]
        login = login.strip.downcase
        (from_email login) #|| (from_login login) # by cardname or email
      end
    end
    # can these just be delegations:
    # delegate @@acount_class, :new, :from_email, :from_login, :from_id, :save_card
    def new(args)              @@session_class.new(args)                                    end
    def save_card(card, email) @@session_class.save_card(card, email)                       end
    def from_email(email)      @@session_class.from_email(email)                            end
    def from_login(login)      @@session_class.from_login(login)                            end
    def from_id(card_id)       @@session_class.from_id(card_id) || ANONUSER                 end

    def admin?()
      acid = (ac=as_card).new_card? ? ac.left_id : ac.id
      acid==BOTCARD.id || acid == Card::WagnBotID
    end

    def reset()                @@session = ANONCARD; @@as_card = nil                        end
    def session()              @@session || ANONCARD                                        end
    def authorized_name()      authorized.name                                              end
    def session=(account)      @@session = Account[account]                                 end
    def as_card()              @@as_card || session                                         end
    # We only need to test for the tag presence for migrations, we are going to  make sure it
    # exists and is indestructable (add tests for that)
    def authorized()          as_card.trunk                                                 end
    #def authorized()           (ac=as_card).right_id == Card::AccountID ? ac.trunk : ac     end
    def as_bot(&block)         as Card::WagnBotID, &block                                   end
    def among?(authzed)        authorized.among? authzed                                    end
    def logged_in?()           session.id != ANONCARD.id                                    end

    def as given_account
      save_as = @@as_card
      @@as_card = Account[given_account]
      #Rails.logger.info "set ac #{@@as_card.inspect}"

      if block_given?
        value = yield
        @@as_card = save_as
        return value
      else #fail "BLOCK REQUIRED with Card#as"
      end
    end
 
    def no_logins?
      cache = Card.cache
     #r=(
      !!(rd=cache.read('no_logins')) ? rd : cache.write( 'no_logins',
               (Card.search({:right=>Card::AccountID, :left=>{:type=>Card::UserID }}).count == 0 ))
     #); Rails.logger.warn "Logins? #{r}"; r
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

    def [] account
      if @@session_class===account
        Card[account.account_id]
      else
        account = acct = Card===account ? account : Card[account]
        # if this isn't a Right::Account yet, fetch it
        if acct.right_id == Card::AccountID; acct
        else # no WagnBot account, accept WagnBot card for migrations to work
          acct = acct.fetch_trait(:account) and acct or
            (account.id == Card::WagnBotID ? account : Account::ANONCARD)
        end
      end
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

    # Shouldn't this be someplace else?  Card? a Model module?
    NON_CREATEABLE_TYPES = %w{ account_request setting set }

    def createable_types
      as_bot { Card.search :type=>Card::CardtypeID, :return=>:name,
                 :not => { :codename => ['in'] + NON_CREATEABLE_TYPES } }.
        reject { |name| !Card.new( :type=>name ).ok? :create }.sort
    end
  end

end

