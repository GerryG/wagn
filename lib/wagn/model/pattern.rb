module Wagn::Model
  module Pattern
    mattr_accessor :subclasses
    @@subclasses = []

    def self.register_class(klass) @@subclasses.unshift klass end
    def self.method_key(opts)
      @@subclasses.each do |pclass|
        if !pclass.opt_keys.map(&opts.method(:has_key?)).member? false;
          return pclass.method_key_from_opts(opts)
        end
      end
    end

    def reset_patterns_if_rule()
      return if name.blank?
      if !simple? and !new_card? and setting=right and setting.type_id==Card::SettingID and set=left and set.type_id==Card::SetID
        set.include_set_modules
        self.read_rule_updates( set.item_cards :limit=>0 ) if setting.id == Card::ReadID
        set.reset_patterns
        set.reset_set_patterns
      end
    end

    def reset_patterns
      @rule_cards={}
      @set_mods_loaded = @patterns = @set_modules = @method_keys = @set_names = @template = nil
      true
    end

    def patterns kind=nil
      kind=:default if kind.nil?
      @patterns ||= {}
      r=@patterns[kind] ||= @@subclasses.map { |sub| sub.new(self, kind) }.compact
      #warn "pats K:#{kind.inspect}, N:#{name} R:#{r}"; r
    end
    def patterns_with_new kind=nil
      #warn "pw/new K:#{kind} N:#{name}"
      new_card? ? patterns_without_new(kind)[1..-1] : patterns_without_new(kind)
    end
    alias_method_chain :patterns, :new

    def real_set_names kind=nil
      set_names(kind).find_all &Card.method(:exists?)                              end
    def safe_keys()      patterns.map(&:safe_key).reverse*" "                                   end
    def set_modules()    @set_modules ||= patterns_without_new.reverse.map(&:set_const).compact end
    def set_names kind=nil
      kind=:default if kind.nil?
      @set_names ||= {}
      #warn "sn K:#{kind.inspect}"
      if @set_names[kind].nil?
        Card.set_members(@set_names[kind] = patterns(kind).map {|p| p.set_name(kind)}, key)
      end
      @set_names[kind]
    end
    def method_keys()    @method_keys ||= patterns.map(&:get_method_key).compact                end
  end

  module Patterns
    class BasePattern

      @@ruby19 = !!(RUBY_VERSION =~ /^1\.9/)
      BASE_MODULE = Wagn::Set
      MODULES={}

      class << self

        attr_accessor :key, :key_id, :opt_keys, :junction_only, :method_key, :kinds

        def find_module mod
          #Rails.logger.warn "find_mod #{mod}"
          return if mod.nil?
          (mod.split('/') << 'model').inject(BASE_MODULE) do |base, part|
            return if base.nil?
            part = part.camelize; key = base.to_s + '::' + part
            MODULES.has_key?(key) ? MODULES[key] : MODULES[key] = if @@ruby19
                  base.const_defined?(part, false) ? base.const_get(part, false) : nil
                else
                  base.const_defined?(part)        ? base.const_get(part)        : nil
                end
          end
        #rescue Exception => e
          #warn "lookup error #{mod} #{e.inspect}"
        rescue NameError
          nil
        end

        def trunk_name(card)  ''                     end
        def junction_only?()  !!junction_only        end
        def trunkless?()      !!method_key           end # method key determined by class only when no trunk involved
        def new(card, kind=nil)
          #warn "new #{card.name}, #{kind.nil?} || #{kind==:default} || #{!kinds.nil? && kinds[kind]}"
          super(card) if kind.nil? || kind==:default || !kinds.nil? && kinds[kind] and pattern_applies?(card)
        end
        def key_name()
          @key_name ||= (code=Wagn::Codename[self.key] and card=Card[code] and card.name)
        end

        def register key, opt_keys, opts={}
          Wagn::Model::Pattern.register_class self
          self.key = key
          #self.key_id = (key == 'self') ? 0 : Wagn::Codename[key]
          self.key_id = Wagn::Codename[key]
          self.opt_keys = Array===opt_keys ? opt_keys : [opt_keys]
          if kinds_opt = opts.delete(:kinds)
            self.kinds = (self.kinds || {:default=>true}).
              merge Array==kinds_opt ? kinds_opt.inject({}) { |h,k| h[k]=true } : {kinds_opt=>true}
          end
          opts.each { |key, val| send "#{key}=", val }
          #warn "reg K:#{self}[#{key}] OK:[#{opt_keys.inspect}] jo:#{junction_only.inspect}, mk:#{method_key.inspect}"
        end

        def method_key_from_opts opts
          method_key || ((opt_keys.map do |opt_key|
              opts[opt_key].to_s.gsub('+', '-')
            end << key) * '_')
        end

        def pattern_applies?(card)
          junction_only? ? card.cardname.junction? : true
        end
      end

      def initialize(card)
        #warn "init pat #{self.class}, #{card.name}"
        @trunk_name = self.class.trunk_name(card).to_cardname
        self
      end

      def set_module
        case
        when  self.class.trunkless?    ; self.class.key
        when  opt_vals.member?( nil )  ; nil
        else  "#{self.class.key}/#{opt_vals * '_'}"
        end
      end

      def set_const
        self.class.find_module set_module
      end

      def get_method_key()
        tkls_key = self.class.method_key
        return tkls_key if tkls_key
        return self.class.method_key if self.class.trunkless?
        opts = {}
        self.class.opt_keys.each_with_index do |key, index|
          return nil unless opt_vals[index]
          opts[key] = opt_vals[index]
        end
        self.class.method_key_from_opts opts
      end

      def inspect()       "<#{self.class} #{to_s.to_cardname.inspect}>" end

      def opt_vals
        if @opt_vals.nil?
          @opt_vals = self.class.trunkless? ? [] :
            @trunk_name.parts.map do |part|
              card=Card.fetch(part, :skip_virtual=>true, :skip_modules=>true) and Wagn::Codename[card.id.to_i]
            end
        end
        @opt_vals
      end

      def set_name(kind=nil)
        #warn "set_name #{kind}, #{self.class} #{@trunk_name.inspect}" unless kind.nil? || kind==:default || !(SelfPattern===self)
        kind.nil? || kind==:default || !(SelfPattern===self) ? to_s : @trunk_name.to_s
      end

      def to_s()
        if self.class.key_id == 0
          @trunk_name
        else
          kn = self.class.key_name
          self.class.trunkless? ? kn : "#{@trunk_name}+#{kn}"
        end
      end

      def safe_key()
        caps_part = self.class.key.gsub(' ','_').upcase
        self.class.trunkless? ? caps_part : "#{caps_part}-#{@trunk_name.safe_key}"
      end

    end

    # kinds of pattern:
    #   The :default is the full set of patterns, and the standard *self pattern
    #   :trait is the first type B, which is the special (no +*self) self pattern
    #   plus an optional default (*all rule), but these will be simple enough to
    #   do if needed:
    #
    #     :type_trait  Special self, plus a default (Type+*type rule).  We would
    #                  have put the rules on the right types in som other way.
    #     :no_default  Like :trait, but not defualt (*all) (or :trait_only
    #

    class AllPattern < BasePattern
      register 'all', [], :method_key=>'', :kinds=>:trait
      def self.label(name)              'All cards'                end
      def self.prototype_args(base)     {}                         end
    end

    class AllPlusPattern < BasePattern
      register 'all_plus', :all_plus, :method_key=>'all_plus', :junction_only=>true
      def self.label(name)              'All "+" cards'            end
      def self.prototype_args(base)     {:name=>'+'}               end
    end

    class TypePattern < BasePattern
      register 'type', :type #, :kinds=>:type_trait
      def self.label(name)              %{All "#{name}" cards}     end
      def self.prototype_args(base)     {:type=>base}              end
      def self.pattern_applies?(card)
        return false if card.type_id.nil?
        raise "bogus type id" if card.type_id < 1
        true       end
      def self.trunk_name(card)         card.type_name              end
    end

    class StarPattern < BasePattern
      register 'star', :star, :method_key=>'star'
      def self.label(name)              'All "*" cards'            end
      def self.prototype_args(base)     {:name=>'*dummy'}          end
      def self.pattern_applies?(card)   card.cardname.star?        end
    end

    class RstarPattern < BasePattern
      register 'rstar', :rstar, :method_key=>'rstar', :junction_only=>true
      def self.label(name)              'All "+*" cards'           end
      def self.prototype_args(base)     { :name=>'*dummy+*dummy'}  end
      def self.pattern_applies?(card)   card.cardname.rstar?       end
    end

    class RightPattern < BasePattern
      register 'right', :right, :junction_only=>true
      def self.label(name)              %{All "+#{name}" cards}    end
      def self.prototype_args(base)     {:name=>"*dummy+#{base}"}  end
      def self.trunk_name(card)         card.cardname.tag     end
    end

    class LeftTypeRightNamePattern < BasePattern
      register 'type_plus_right', [:ltype, :right], :junction_only=>true
      class << self
        def label name
          %{All "+#{name.to_cardname.tag}" cards on "#{name.to_cardname.left_name}" cards}
        end
        def prototype_args base
          { :name=>"*dummy+#{base.tag}",
            :loaded_trunk=> Card.new( :name=>'*dummy', :type=>base.trunk_name )
          }
        end
        def trunk_name card
          lft = card.loaded_trunk || card.left
          type_name = (lft && lft.type_name) || Card[ Card::DefaultTypeID ].name
          "#{type_name}+#{card.cardname.tag}"
        end
      end
    end

    class SelfPattern < BasePattern
      register 'self', :name, :kinds=>:trait # [:trait, :type_trait, :trait_only]
      def self.label(name)              %{The card "#{name}"}      end
      def self.prototype_args(base)     { :name=>base }            end
      def self.trunk_name(card)         card.name                  end
    end

    class BasePattern
      include Wagn::Sets::AllSets
    end
  end
end
