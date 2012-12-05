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
      Rails.logger.warn "nil class for cache #{caller*"\n"}" if @klass.nil?
      @store = opts[:store]
      @local = {}

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
      @system_prefix = ( system_prefix[-1] == '/' ? system_prefix : (system_prefix + '/') )
      @prefix = if @store.nil?
          Rails.logger.warn "see if we can remove this case? #{caller*"\n"}"
          @system_prefix + self.class.generate_cache_id + "/"

        else
          @cache_id = @store.read( "#{@system_prefix}cache_id" ) ||
                     write_global( "#{@system_prefix}cache_id", self.class.generate_cache_id )
          #warn "write cache id #{x1}, #{x2}, #{@cache_id}, #{@system_prefix}"

          @system_prefix + @cache_id + "/"
        end
    end

    def read key
      return @local[key] unless @store
      if @local.has_key?(key)
        @local[key]
      elsif Integer===key
        #Rails.logger.warn "by id miss: #{key} #{caller[0..12]*"\n"}"
        nil
      else
        obj = @store.read @prefix + key
        #warn "rd #{obj.class}, #{obj}, #{@prefix + key} #{@store.nil?}, #{@prefix}"
        obj.reset_mods if obj.respond_to?(:reset_mods)
        obj
      end
    end

    def read_local key
      @local[key]
    end

    def write key, value
      @store.write @prefix + key, value if @store

      @local[value.id.to_i] = value if Card===value and !value.id.nil?

      @local[key] = value
    end

    def write_global key, value
      @store or raise "no store"
      @store.write key, value
      value
    end

    def delete key
      obj = @local.delete key
      @local.delete obj.id if Card===obj and !obj.id.nil?
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
          @store.write @system_prefix + "cache_id", @cache_id
        end
      end
      @prefix = @system_prefix + @cache_id + "/"
    end

  end
end

