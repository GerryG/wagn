class Session

  @@as_card = @@account = nil

  ANONCARD = Card[Card::AnonID]

  class << self
    def reset()           @@account = @@as_card = nil     end
    def account()         @@account || ANONCARD           end
    def account=(account) @@account = get_account account end
    def as_card()         @@as_card || account            end
    def authorized() (ac=as_card).simple? ? ac : ac.trunk end #warn "authzd #{@@as_card} || #{@@account}"
    #def authorized()      account.trunk                   end
    def as_bot(&block) as Card::WagnBotID, &block end
    def among?(authzed) authorized.among? authzed end
    def logged_in?() authorized.id != Card::AnonID end

    def as given_account
      save_as = @@as_card
      @@as_card = get_account given_account
      Rails.logger.info "set ac #{@@as_card.inspect}"

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
    # PERMISSIONS

  private

    def get_account account
      case account
      when NilClass; nil
      when Card;     account
      when User;     Card[account.card_id]
      else
        account=Card[account]
        acct = account.trait_card :account
        #Rails.logger.info "account lookup: #{acct.inspect}, #{account.inspect}"
        if acct.new_card?
          # this helps the migration to do as_bot before the trait is real
          if account.id == Card::WagnBotID
            account
          else raise "no account #{account.name}" end # return nil, but for debug ...
        else acct end
      end
    end

  protected
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

