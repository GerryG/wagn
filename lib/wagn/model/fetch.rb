# = Card#fetch
#
# A multipurpose retrieval operator that incorporates caching, "virtual" card retrieval


module Wagn::Model::Fetch
  mattr_accessor :cache

  module ClassMethods

    # === fetch
    #
    # looks for cards in
    #   - cache
    #   - database
    #   - virtual cards

    def fetch mark, opts = {}
      # "mark" here means a generic identifier -- can be a numeric id, a name, a string name, etc.
#      ActiveSupport::Notifications.instrument 'wagn.fetch', :message=>"fetch #{cardname}" do
      return nil if mark.nil?
      #warn "fetch #{mark.inspect}, #{opts.inspect}"
      # Symbol (codename) handling
      if Symbol===mark
        mark = Wagn::Codename[mark] || raise("Missing codename for #{mark.inspect}")
      end


      cache_key, method, val = if Integer===mark
        [ "~#{mark}", :find, mark ]
      else
        key = mark.to_name.key
        [ key, :find_by_key, key ]
      end

      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      # lookup card

      #Cache lookup
      result = Card.cache.read cache_key if Card.cache
      card = (result && Integer===mark) ? Card.cache.read(result) : result

      #warn "fetch 1 #{cache_key}, #{method}, #{val} #{card}" # if val=='a'
      unless card
        # DB lookup
        needs_caching = true
        card = Card.send method, val
      end
      #warn "fetch 2 #{card.class}"

      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      opts[:skip_virtual] = true if opts[:loaded_left]

      if not Integer===mark
        return nil if card && opts[:skip_virtual] && card.new_card?
      elsif card.nil?
        raise "fetch of missing card_id #{mark}"
      end
      #warn "fetch 3 #{card.inspect}" if val=='a'

        # NEW card -- (either virtual or missing)
      if card.nil? or card.trash or ( !opts[:skip_virtual] && card.type_id==-1 )
        # The -1 type_id allows us to skip all the type lookup and flag the need for
        # reinitialization later.  *** It should NEVER be seen elsewhere ***
        needs_caching = true
        new_args = { :name=>mark.to_s, :skip_modules=>true }
        new_args[:type_id] = -1 if opts[:skip_virtual]
        card = new new_args
      end
      #warn "fetch 4 #{card.inspect}" if val=='a'

      if needs_caching
        Card.cache.write card.key, card
        if not card.nil? and cid=card.id
          unless card.trash; Card.cache.write "~#{cid}", card.key
          else               Card.cache.delete "~#{cid}"  end
        end
      end

      if card.new_card?
        if card.trash
          card.trash=false
        elsif opts[:skip_virtual] || !card.virtual?
          return nil
        end
      end
      #return nil if card.new_card? and ( card.trash || opts[:skip_virtual] || !card.virtual? )

      #warn "fetch returning #{cache_key} #{card.inspect}"
      card.include_set_modules unless opts[:skip_modules]
      card
#      end
    end

    def fetch_or_new name, opts={}
      fetch( name, opts ) || new( opts.merge(:name=>name) )
    end

    def fetch_or_create name, opts={}
      opts[:skip_virtual] ||= true
      fetch( name, opts ) || create( opts.merge(:name=>name) )
    end

    def fetch_id mark #should optimize this.  what if mark is int?  or codename?
      card = fetch mark, :skip_virtual=>true, :skip_modules=>true
      card and card.id
    end

    def [](name)
      c=fetch name, :skip_virtual=>true
    end

    def exists? name
      card = fetch name, :skip_virtual=>true, :skip_modules=>true
      card.present?
    end

    def expire name
      if card = Card.cache.read( name.to_name.key )
        card.expire
      end
    end

    # set_names reverse map (cached)
    def members(key)
      (v=Card.cache.read "$#{key}").nil? ? [] : v.keys
    end

    def set_members set_names, key
      set_names.compact.map(&:to_name).map(&:key).map do |set_key|
        skey = "$#{set_key}" # dollar sign avoids conflict with card keys
        h = Card.cache.read skey
        if h.nil?
          h = {}
        elsif h[key]
          next
        end
        h = h.dup if h.frozen?
        h[key] = true
        Card.cache.write skey, h
      end
    end

  end


  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # TRAIT METHODS

  def fetch_trait tagcode
    Card.fetch cardname.trait_name(tagcode)
  end

  def fetch_or_new_trait tagcode
    Card.fetch_or_new cardname.trait_name(tagcode), :skip_virtual=>true
  end

  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # CACHE FRESHNESS

  def expire_pieces
    cardname.pieces.each do |piece|
      Card.expire piece
    end
  end

  def expire_related
    self.expire

    if self.hard_template?
      self.hard_templatee_names.each do |name|
        Card.expire name
      end
    end
    # FIXME really shouldn't be instantiating all the following bastards.  Just need the key.
    self.dependents.each           { |c| c.expire }
    self.referencers.each          { |c| c.expire }
    self.name_referencers.each     { |c| c.expire }
    # FIXME: this will need review when we do the new defaults/templating system
    #if card.changed?(:content)
  end

  def expire
    Card.cache.delete key
    Card.cache.delete "~#{id}" if id
  end

  def refresh
    if frozen?()
      fresh_card = self.class.find id()
      fresh_card.include_set_modules
      fresh_card
    else self end
  end

  def self.included(base)
    super
    base.extend Wagn::Model::Fetch::ClassMethods
  end
end



