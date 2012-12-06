module Wagn

  ActiveSupport::Cache::FileStore.class_eval do
    # escape special symbols \*"<>| additionaly to :?.
    # All of them not allowed to use in ms windows file system
    def real_file_path(name)
      name = name.gsub('%','%25').gsub('?','%3F').gsub(':','%3A')
      name = name.gsub('\\','%5C').gsub('*','%2A').gsub('"','%22')
      name = name.gsub('<','%3C').gsub('>','%3E').gsub('|','%7C')
      '%s/%s.cache' % [@cache_path, name ]
    end
  end

  class Cache

    # FIXME: move the initial login test to Account
    FIRST_KEY = 'first_login'

    def first_login
      @first_login.nil? and @first_login = store.read( prefix + FIRST_KEY )
      @first_login
    end

    def first_login= status=false
      write_global FIRST_KEY, @first_login = status
      @first_login
    end

    @@prepopulating     = nil
    @@using_rails_cache = nil
    @@prefix_root       = Wagn::Application.config.database_configuration[Rails.env]['database']
    @@frozen            = {}
    @@cache_by_class    = {}

    cattr_reader :frozen, :prefix_root

    class << self
      def [] klass
        if @@cache_by_class[klass].nil?
          new :class=>klass
        end
        @@cache_by_class[klass]
      end

      def renew
        reset_local unless self.prepopulating
      end

      def system_prefix klass
        klass.system_prefix
      end

      def restore klass=Card
        raise "no klass" if klass.nil?

        reset_local
        @@cache_by_class[klass] = Marshal.load(frozen[klass]) if @@cache_by_class[klass] and self.prepopulating and klass==Card
      end

      def generate_cache_id
        id=((Time.now.to_f * 100).to_i).to_s + ('a'..'z').to_a[rand(26)] + ('a'..'z').to_a[rand(26)]
        warn "gen cid #{id}"; id
      end

      def reset_global
        @@cache_by_class.keys.each do |klass|
          next unless cache = klass.cache
          cache.reset hard=true
        end
        Wagn::Codename.reset_cache
      end

      def reset
        @@prepopulating = @@using_rails_cache = nil
      end

      def prepopulating
        @@prepopulating = Rails.env == 'cucumber' if @@prepopulating.nil?
        warn "prepop #{@@prepopulating}, #{Rails.env == 'cucumber'}"
        @@prepopulating
      end

      def using_rails_cache
        @@using_rails_cache = !(Rails.env =~ /^cucumber|test$/) if @@using_rails_cache.nil?
        warn "urc #{@@using_rails_cache}, #{!Rails.env =~ /^cucumber|test$/}"
        @@using_rails_cache
      end

      private

      def reset_local
        warn "reset local (class) #{@@cache_by_class.map{|k,v|k.to_s+' '+v.to_s}*", "}"
        @@cache_by_class.each{ |cc, cache|
          if Wagn::Cache===cache
            cache.reset_local
          else warn "reset class #{cc}, #{cache.class} #{caller[0..8]*"\n"} ???" end
        }
      end

    end

    attr_reader :local

    def initialize(opts={})
      @klass ||= opts[:class]
      #Rails.logger.warn "nil class for cache #{caller*"\n"}" if @klass.nil?
      @local = {}
      @stats = {}
      @times = {}
      @stat_count = 0

      self.cache_id  # cause it to write the prefix related vars

      self.class.prepopulating and @klass == Card and prepopulate @klass 

      @@cache_by_class[@klass] = self
    end

    def prepopulate klass
      ['*all','*all plus','basic+*type','html+*type','*cardtype+*type','*sidebar+*self'].each do |k|
        [k,"#{k}+*content", "#{k}+*default", "#{k}+*read" ].each { |k| klass[k] }
      end
      frozen[klass] = Marshal.dump Cache[klass]
    end

    def store
      @store ||= Cache.using_rails_cache ? Rails.cache : ActiveSupport::Cache::MemoryStore.new
      #warn "store is #{@store}"; @store
    end

    def cache_id_key
        @id_key ||= system_prefix + '/cache_id'
    end

    def cache_id
      raise "cache_id #{@cache_id}" if caller.length > 200
      warn "cache_id r k:#{cache_id_key}, cid:#{@cache_id}"
      if @cache_id.nil?
        @cache_id = self.class.generate_cache_id
        store.write cache_id_key, @cache_id
      warn "cache_id w k:#{cache_id_key}, cid:#{@cache_id}"
      end
      raise("no id? #{ system_prefix + '/cache_id' }") if @cache_id.nil?
      warn "cache_id e k:#{cache_id_key}, cid:#{@cache_id}"
      @cache_id
    end

    def system_prefix
      Cache.prefix_root + '/' + @klass.to_s
    end

    def prefix
      r=
      system_prefix + '/' + @cache_id + '/'
      #warn "prefix is #{r}"; r
    end

    # ---------------- STATISTICS ----------------------

    INTERVAL = 10000

    def stat key, t
      @stats[key] ||= 0
      @times[key] ||= 0
      @stats[key] += 1
      @times[key] += (Time.now - t)
      if (@stat_count += 1) % INTERVAL == 0
        Rails.logger.warn "stats[#{@stat_count}] ----------------------
#{        @stats.keys.map do |key| %{#{
            ( key.to_s + ' '*16 )[0,20]
            } -> n: #{
            ( ' '*4 + @stats[key].to_s )[-5,5]
            } avg: #{
            (@times[key]/@stats[key]).to_s.gsub( /^([^\.]*\.\d{3})\d*(e?.*)$/, "#{$1}#{$2.nil? ? '' : ' ' + $2}" )
          } } end * "\n" }

Local: #{ dump }"
      end
    end

    #def stat *a; end  # to disable stat collections

    def read key
      start = Time.now
      if @local.has_key?(key)
        l = @local[key]
        stat (Integer===key ? (l.nil? ? :id_nil : :id_hit ) : (l.nil? ? :key_nil : :key_hit )), start
        return l
      end
      stat :id_miss, start if Integer===key
      return if Integer===key

      warn "read global: #{prefix} K:#{key} #{prefix+key}"
      obj = store.read prefix + key
      obj.reset_mods if obj.respond_to? :reset_mods
      stat (obj.nil? ? :global_miss : :global_hit), start
      #Rails.logger.warn "c read: #{key}, #{obj.inspect}, #{Card===obj and obj.sets_loaded? and i=obj.id.to_i and "r:#{@local[i].inspect}"}, pk:#{prefix + key} p:#{prefix}"

      astart = Time.now
      Card===obj and  i=obj.id.to_i and @local[i] = obj and
        stat :id_read_store, astart
      obj
    end

    def read_local key
      start = Time.now
      l=@local[key]
      stat :read_local, start
      l
    end

    def write key, obj
      start = Time.now
      if Card===obj
        #Rails.logger.warn "c write #{obj.inspect}"
        #obj.init_sets unless obj.sets_loaded?
        id = obj.id.to_i
        id != 0 and @local[ id ] = obj
        stat (id == 0 ? :noid_local : :wr_local_id), start
      end
      #Rails.logger.warn "c write l:#{@local.class}, gk:#{prefix + key}, v:#{obj.inspect}"

      write_global key, obj
      stat :write, start
      @local[key] = obj
    end

    def write_global key, obj
      start = Time.now
      store.write "#{ prefix }#{ key }", obj
      stat :write_global, start
      obj
    end

    def delete key
      obj = @local.delete key
      #Rails.logger.warn "c delete #{obj.inspect}, k:#{key}"
      @local.delete obj.id if Card===obj
      store.delete prefix + key
    end

    def dump
      p "dumping local...."
      @local.each do |k, v|
        p "#{k} --> #{v.inspect[0..30]}"
      end
    end

    def reset_local
      warn "reset local i #{caller[0..6]*', '}"
      @reset_last ||= Time.now
      stat :reset_local, @reset_last
      @reset_last = Time.now
      #@local = {}
    end

    def reset hard=false
      warn "reset #{hard} #{@cache_id}"
      reset_local
      warn "reset 1 #{@cache_id}"
      @cache_id = nil
      warn "reset 2 #{@cache_id}"
      initialize
      warn "reset 3 #{@cache_id}"
      if hard
        warn "reset 4 #{@cache_id}"
        store.clear
      end
    end

  end
end

