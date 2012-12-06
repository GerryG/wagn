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

    FIRST_KEY = 'first_login'

    def first_login
      @first_login.nil? and @first_login = @store.send_if( :read, @prefix + FIRST_KEY )
      @first_login
    end

    def first_login= status=false
      write_global FIRST_KEY, @first_login = status
      @first_login
    end

    def write_global key, obj
      stat :write_global
      #@store or raise "no store"
      @store.send_if :write, "#{ @prefix }#{ key }", obj
      obj
    end

    @@prepopulating     = (Rails.env == 'cucumber') ? { Card => true } : {}
    @@using_rails_cache = Rails.env =~ /^cucumber|test$/
    @@prefix_root       = Wagn::Application.config.database_configuration[Rails.env]['database']
    @@frozen            = {}
    @@cache_by_class    = {}

    cattr_reader :cache_by_class, :prepopulating, :frozen, :prefix_root

    class << self
      def [] klass
        raise "nil klass" if klass.nil?
        cache_by_class[klass] ||= new :class=>klass, :store=>(@@using_rails_cache ? nil : Rails.cache)
      end

      def renew
        cache_by_class.keys do |klass|
          if klass.cache
            cache_by_class[klass].system_prefix = system_prefix(klass)
          else
            raise "renewing nil cache: #{klass}"
          end
        end
        reset_local if prepopulating.empty?
      end

      def system_prefix klass
        "#{ prefix_root }/#{ klass }"
      end

      def restore klass=nil
        klass=Card if klass.nil?
        raise "no klass" if klass.nil?
        reset_local
        cache_by_class[klass] = Marshal.load(frozen[klass]) if cache_by_class[klass] and prepopulating[klass]
      end

      def generate_cache_id
        ((Time.now.to_f * 100).to_i).to_s + ('a'..'z').to_a[rand(26)] + ('a'..'z').to_a[rand(26)]
      end

      def reset_global
        cache_by_class.keys.each do |klass|
          next unless cache = klass.cache
          cache.reset hard=true
        end
        Wagn::Codename.reset_cache
      end

      private


      def reset_local
        #warn "reset local #{cache_by_class.map{|k,v|k.to_s+' '+v.to_s}*", "}"
        cache_by_class.each{ |cc, cache|
          if Wagn::Cache===cache
            cache.reset_local
          else warn "reset class #{cc}, #{cache.class} #{caller[0..8]*"\n"} ???" end
        }
      end

    end

    attr_reader :prefix, :local, :store

    def initialize(opts={})
      @klass = opts[:class]
      #Rails.logger.warn "nil class for cache #{caller*"\n"}" if @klass.nil?
      @store = opts[:store]
      @local = {}
      @stats = {}
      @stat_count = 0

      self.system_prefix = opts[:prefix] || self.class.system_prefix(opts[:class])

      cache_by_class[@klass] = self
      prepopulate @klass if prepopulating[@klass]
    end

    def prepopulate klass
      ['*all','*all plus','basic+*type','html+*type','*cardtype+*type','*sidebar+*self'].each do |k|
        [k,"#{k}+*content", "#{k}+*default", "#{k}+*read" ].each { |k| klass[k] }
      end
      frozen[klass] = Marshal.dump Cache[klass]
    end

    def system_prefix=(system_prefix)
      @system_prefix = ( system_prefix[-1,1] == '/' ? system_prefix : (system_prefix + '/') )
      @prefix = if @store.nil?
          Rails.logger.warn "see if we can remove this case? #{caller[0..12]*", "}"
          @system_prefix + self.class.generate_cache_id + "/"

        else
          @cache_id = @store.read( "#{@system_prefix}cache_id" ) ||
                     write_global( "#{@system_prefix}cache_id", self.class.generate_cache_id )
          #warn "write cache id #{x1}, #{x2}, #{@cache_id}, #{@system_prefix}"

          @system_prefix + @cache_id + "/"
        end
    end

    INTERVAL = 10000

    def stat key
      @stats[key] ||= 0
      @stats[key] += 1
      Rails.logger.warn "stats[#{@stat_count}, #{@local.keys.length}] #{@stats.inspect}" if (@stat_count += 1) % INTERVAL == 0
    end

    def read key
      stat :read
      if @store.nil? || @local.has_key?(key)
        l = @local[key]
        stat l.nil? ? :local_miss : :local_hit
        return l
      end
      stat :id_miss if Integer===key
      return if Integer===key

      obj = @store.read @prefix + key
      stat :reset_mods if obj.respond_to? :reset_mods
      obj.reset_mods if obj.respond_to? :reset_mods
      stat obj.nil? ? :global_miss : :global_hit
      #Rails.logger.warn "c read: #{key}, #{obj.inspect}, #{Card===obj and obj.sets_loaded? and i=obj.id.to_i and "r:#{@local[i].inspect}"}, pk:#{@prefix + key} st:#{@store.nil?}, p:#{@prefix}"

      #raise "not loaded? #{obj.inspect}" if Card===obj and  !obj.sets_loaded?
      Card===obj and  i=obj.id.to_i and @local[i] = obj and
        stat :id_read_store
      obj
    end

    def read_local key
      stat :read_local
      @local[key]
    end

    def write key, obj
      stat :write
      if Card===obj
        #Rails.logger.warn "c write #{obj.inspect}"
        #obj.init_sets unless obj.sets_loaded?
        id = obj.id.to_i
        id != 0 and @local[ id ] = obj
        stat id == 0 ? :local_0 : :local_st
      end
      #Rails.logger.warn "c write st:#{!@store.nil?} l:#{@local.class}, gk:#{@prefix + key}, v:#{obj.inspect}"

      write_global key, obj
      @local[key] = obj
    end

    def delete key
      obj = @local.delete key
      #Rails.logger.warn "c delete #{obj.inspect}, k:#{key}"
      @local.delete obj.id if Card===obj
      @store.delete @prefix + key  if @store
    end

    def dump
      p "dumping local...."
      @local.each do |k, v|
        p "#{k} --> #{v.inspect[0..30]}"
      end
    end

    def reset_local
      @local = {}
    end

    def reset hard=false
      reset_local
      @cache_id = self.class.generate_cache_id
      if @store
        if hard
          @store.clear
        else
          write_global :cache_id, @cache_id
        end
      end
      @prefix = @system_prefix + @cache_id + "/"
    end

  end
end

