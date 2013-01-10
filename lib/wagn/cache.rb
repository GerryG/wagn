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

  class NilCache
    def initialize                  ; self end
    def method_missing method, *args; nil  end
    def delete *a;  nil end
    def read *a;  nil end
    def write *a;  nil end
    def clear *a;  nil end
  end

  class Cache
    def inspect
      "#{@local.map{|k,v| "#{k}  -> #{v.inspect}"}*"\n"}\nStore:#{ store.to_s }"
    end

    @@prefix_root       = Wagn::Application.config.database_configuration[Rails.env]['database']
    @@frozen            = {}
    @@cache_by_class    = {}

    cattr_reader :frozen, :prefix_root

    class << self
      #def prepopulating? ; Rails.env == 'cucumber' end
      def use_rails_cache?; !%w{ cucumber test }.member? Rails.env end
      def prepopulating?  ; !use_rails_cache? end

      def [] klass
        if @@cache_by_class[klass].nil?
          self.new klass
        end
        @@cache_by_class[klass]
      end

      def renew
        reset_local unless self.prepopulating?
      end

      def system_prefix klass
        klass.system_prefix
      end

      def restore klass=Card
        reset_local
        Cache[klass].prepopulate
      end

      def generate_cache_id
        ((Time.now.to_f * 100).to_i).to_s + ('a'..'z').to_a[rand(26)] + ('a'..'z').to_a[rand(26)]
      end

      def reset_global
        @@cache_by_class.keys do |klass, cache|
          Rails.logger.warn "reset global #{klass}, #{cache}"
          cache.reset hard=true
        end
        Wagn::Codename.reset_cache
      end

      private

      def reset_local
        @@cache_by_class.each do |cc, cache|
          if Wagn::Cache===cache
            cache.reset_local
          end
        end
      end

    end

    attr_reader :local

    def initialize opts={}
      #warn "new cache #{opts.inspect}"
      @klass = opts[:class]
      @store = opts[:store]
      @local = Hash.new
      self.system_prefix = opts[:prefix] || self.class.system_prefix(opts[:class])
      cache_by_class[klass] = self
      prepopulate klass if prepopulating[klass]
    end

    def init_frozen klass
      %w{ *all *all plus basic+*type html+*type *cardtype+*type *sidebar+*self }.each do |base|
        klass[ base ]
        %w{ +*content +*default +*read }.each { |plus| klass[ base + plus ] }
      end
      %w{ anonymous+*account wagn_bot+*account }.each { |k| klass[k] }

      cache = Cache[klass]
      #warn "dump:\n#{cache.inspect}"
      frozen[klass] = Marshal.dump cache
    end

    def system_prefix= system_prefix
      @system_prefix = system_prefix
      if @store.nil?
        @store = @use_rails_cache || Cache.use_rails_cache? ? Rails.cache : NilCache.new
      end
      @store
    end

    def cache_id_key
        @id_key ||= system_prefix + '/cache_id'
    end

    def cache_id
      if @cache_id.nil?
        @cache_id = self.class.generate_cache_id
        store.write cache_id_key, @cache_id
      end
      @cache_id
    end

    def system_prefix
      "#{ Cache.prefix_root }/#{ @klass.to_s }"
    end

    def prefix
      "#{ system_prefix }/#{ cache_id }/"
    end

    FIRST_KEY = 'first_login'

    def first_login= status=false
      @first_login = write_global FIRST_KEY, status
    end

    def first_login?
      if @first_login.nil?
        first_login = store.read "#{ prefix }#{ FIRST_KEY }"
      end
      @first_login
    end

    # ---------------- STATISTICS ----------------------

    INTERVAL = 10000

    def stat key, t
      @stats[key] ||= 0
      @times[key] ||= 0
      @stats[key] += 1
      @times[key] += (Time.now - t)
      if (@stat_count += 1) % INTERVAL == 0
        Rails.logger.warn %{stats[#{@stat_count}] Local size: #{@local.length} ----------------------
#{        @stats.keys.map do |key| %{#{
            ( key.to_s + ' '*16 )[0,20]
            } -> n: #{
            ( ' '*4 + @stats[key].to_s )[-5,5]
            } avg: #{
            (@times[key]/@stats[key]).to_s.gsub( /^([^\.]*\.\d{3})\d*(e?.*)$/, "#{$1}#{$2.nil? ? '' : ' ' + $2}" )
          } } end * "\n" }


}
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

      obj = store.read prefix + key
      obj.reset_mods if obj.respond_to? :reset_mods
      stat (obj.nil? ? :global_miss : :global_hit), start

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
        id = obj.id.to_i
        id != 0 and @local[ id ] = obj
        stat (id == 0 ? :noid_local : :wr_local_id), start
      end

      @local[key] = write_global key, obj
      stat :write, start
      obj
    end

    def write_global key, obj
      start = Time.now
      store.write "#{ prefix }#{ key }", obj
      stat :write_global, start
      obj
    end

    def delete key
      obj = @local.delete key
      if Card===obj && obj.id
        @local.delete obj.id
      end
      #Rails.logger.warn "delete #{store}, #{prefix.inspect}, #{key.inspect}"
      store.delete( prefix + key )
    end

    def dump
      Rails.logger.warn "dumping local...."
      @local.each do |k, v|
        Rails.logger.warn "#{k} --> #{v.inspect[0..30]}"
      end
    end

    def prepopulate
      if self.class.prepopulating? and @klass == Card
        cache = @@cache_by_class[@class] = Marshal.load frozen[@klass]
        #warn "loaded:\n#{cache.inspect}"
      end
    end

    def reset_local
      Rails.logger.warn "---------- reset local instance #{store}"
      @reset_last ||= Time.now
      stat :reset_local, @reset_last
      @reset_last = Time.now
      @local = {}
    end

    def reset hard=false
      Rails.logger.warn "------------ reset hard? #{hard} #{caller*"\n"}"

      reset_local # unless self.class.prepopulating?
      @cache_id = nil
      if hard
        store.clear
      else
        cache_id # accessing it will generate and write the new id
      end
      prepopulate
    end

  end
end

