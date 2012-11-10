class Account
  # in migrations
  ANONCARD = Card[Card::AnonID].trait_card(:account)
  # This will probably have a hash of possible account classes and a value for the class
  @@account_class = User
  # FIXME: Probably should use nil as the 'account' for Anonymous (Card/codename)
  # but tests depend on this being same class (User) as other accounts
  # It shouldn't be a Card, and if User can be replaced, does each plugin need an Anonymous or
  # we just use nil for that function.  There is a similar issue for WagnBot, it depends on
  # User if it has an account, but if it doesn't we will need a dummy class for this
  # For now find it by card_id in User
  ANONUSER = User.from_id ANONCARD.id

  cattr_accessor :account_class

  @@as_card = nil
  @@account = ANONCARD

  class << self
    def from_params params
      if login = params[:login]
        login = login.strip.downcase
        (from_email login) #|| (from_login login) # by cardname or email
      end
    end
    # can these just be delegations:
    # delegate @@acount_class, :new, :cache, :from_email, :from_login, :from_id, :save_card
    def new(args)              @@account_class.new(args)                                    end
    def save_card(card, email) @@account_class.save_card(card, email)                       end
    def cache()                @@account_class.cache()                                      end
    def from_email(email)      @@account_class.from_email(email)                            end
    def from_login(login)      @@account_class.from_login(login)                            end
    def from_id(card_id)       @@account_class.from_id(card_id) || ANONUSER                 end

    def admin?() ((ac=as_card).tag_id==Card::AccountID ? ac.trunk_id : ac.id)==Card::WagnBotID end

    def reset()                @@account = ANONCARD; @@as_card = nil                        end
    def account()              @@account || ANONCARD                                        end
    def account_name()         account.cardname.left                                        end
    def account=(account)      @@account = get_account account
    raise "bad id #{account.inspect}" if @@account.nil?; @@account end
    def as_card()              @@as_card || account                                         end
    def authorized()        (ac=as_card).tag_id == Card::AccountID ? Card[ac.trunk_id] : ac end
    def as_bot(&block)         as Card::WagnBotID, &block                                   end
    def among?(authzed)        authorized.among? authzed                                    end
    def logged_in?()           authorized.id != Card::AnonID                                end
    alias session account ; alias session= account=  # until I remove .account usage fully

    def as given_account
      save_as = @@as_card
      @@as_card = get_account given_account
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
     !!rd=cache.read('no_logins') ? rd : cache.write( 'no_logins',
               (Card.search({:right=>Card::AccountID, :left=>{:type=>Card::UserID }}).count < 0 ))
                 #:not => { :left => ['in', Card::WagnBotID, Card::AnonID]  }}).count < 0 ))
    end
 
    def always_ok?
      as_id = authorized.id
      return true if as_id == Card::WagnBotID #cannot disable
      #warn "aok? bot" if as_id == Card::WagnBotID
 
      always = Card.cache.read('ALWAYS') || {}
      if always[as_id].nil?
        always = always.dup if always.frozen?
        always[as_id] = !!Card[as_id].all_roles.detect{|r|r==Card::AdminID}
        Card.cache.write 'ALWAYS', always
       end
     #Rails.logger.warn "aok? #{Card[as_id].name}, #{always.inspect}" if always[as_id]
     always[as_id]
    end

    def get_account account
      Rails.logger.debug "account lookup: #{account.inspect}"
      return Card[account.card_id] if @@account_class===account
      account = acct = Card===account ? account : Card[account]
      acct = acct.trait_card(:account) unless acct.id == ANONCARD.id || acct.tag_id==Card::AccountID
      acct = account.id == Card::WagnBotID ? account : Account::ANONCARD if acct.new_card? 
      #Rails.logger.info "account lookup: acct:#{acct.inspect} cd:#{account.inspect}"
      acct
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

