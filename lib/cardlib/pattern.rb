module Cardlib
  module Pattern
    mattr_accessor :subclasses
    @@subclasses = []

    def self.register_class klass
      @@subclasses.unshift klass
    end

    def self.method_key opts
      @@subclasses.each do |pclass|
        if !pclass.opt_keys.map(&opts.method(:has_key?)).member? false;
          return pclass.method_key_from_opts(opts)
        end
      end
    end

    def reset_patterns_if_rule saving=false
      if is_rule?
        set = left
        set.reset_patterns
        set.include_set_modules
        
        if saving
          self.read_rule_updates( set.item_cards :limit=>0 ) if right.id == Card::ReadID
        end
      end
    end

    def reset_patterns
      @set_mods_loaded = @patterns = @set_modules = @junction_only = @method_keys = @set_names = @template = @rule_set_keys = nil
      true
    end

    def patterns
      @patterns ||= @@subclasses.map { |sub| sub.new(self) }.compact
    end

    def patterns_with_new
      new_card? ? patterns_without_new[1..-1] : patterns_without_new
    end
    alias_method_chain :patterns, :new
    
    def safe_keys
      patterns.map(&:safe_key).reverse*" "
    end

    def set_modules
      @set_modules ||= patterns_without_new.reverse.map(&:set_const).compact
    end

    def set_names
      Card.set_members(@set_names = patterns.map(&:to_s), key) if @set_names.nil?
      @set_names
    end
    
    def rule_set_keys
      set_names #this triggers set_members cache.  need better solution!
      @rule_set_keys ||= patterns.map( &:rule_set_key ).compact
    end
    
    def method_keys
      @method_keys ||= patterns.map(&:get_method_key).compact
    end
  end

  module Patterns
    class BasePattern

      RUBY19 = !!(RUBY_VERSION =~ /^1\.9/)
      MODULES={}

      class << self

        attr_accessor :key, :key_id, :opt_keys, :junction_only, :method_key

        def find_module mod
          module_name_parts = mod.split('/') << 'model'
          module_name_parts.inject Wagn::Set do |base, part|
            return if base.nil?
            #Rails.logger.warn "find m #{base}, #{part}"
            part = part.camelize
            key = "#{base}::#{part}"
            if MODULES.has_key?(key)
              MODULES[key]
            else
              args = RUBY19 ? [part, false] : [part]
              MODULES[key] = base.const_defined?(*args) ? base.const_get(*args) : nil
            end
          end
        rescue Exception => e
        #rescue NameError => e
          Rails.logger.warn "find_module error #{mod}: #{e.inspect}"
          return nil if NameError ===e
        end

        def junction_only?()  !!junction_only  end
        def anchorless?()     !!method_key     end # method key determined by class only when no trunk involved
        def anchor_name(card) ''               end
          
        def new card
          super if pattern_applies? card
        end

        def key_name
          @key_name ||= (code=Wagn::Codename[self.key] and card=Card[code] and card.name)
        end

        def register key, opt_keys, opts={}
          Cardlib::Pattern.register_class self
          self.key = key
          self.key_id = Wagn::Codename[key]
          self.opt_keys = Array===opt_keys ? opt_keys : [opt_keys]
          opts.each { |key, val| send "#{key}=", val }
        end

        def method_key_from_opts opts
          method_key || ((opt_keys.map do |opt_key|
              opts[opt_key].to_s.gsub('+', '-')
            end << key) * '_')
        end

        def pattern_applies? card
          junction_only? ? card.cardname.junction? : true
        end
      end

      def initialize(card)
        @card = card
        @anchor_name = self.class.anchor_name(card).to_name
        @anchor_id = if self.class.respond_to? :anchor_id
          self.class.anchor_id card
        else
          anchor_card = Card.fetch @anchor_name, :skip_virtual=>true, :skip_modules=>true
          anchor_card && anchor_card.id
        end
        self
      end
      

      def set_module
        case
        when  self.class.anchorless?    ; self.class.key
        when  opt_vals.member?( nil )   ; nil
        else  "#{self.class.key}/#{opt_vals * '_'}"
        end

      rescue Exception => e; warn "exception set_const #{e.inspect}," #{e.backtrace*"\n"}"
      end

      def get_method_key
        tkls_key = self.class.method_key
        return tkls_key if tkls_key
        return self.class.method_key if self.class.anchorless?
        opts = {}
        self.class.opt_keys.each_with_index do |key, index|
          return nil unless opt_vals[index]
          opts[key] = opt_vals[index]
        end
        self.class.method_key_from_opts opts
      end

      def opt_vals
        if @opt_vals.nil?
          @opt_vals = self.class.anchorless? ? [] :
            @anchor_name.parts.map do |part|
              card=Card.fetch(part, :skip_virtual=>true, :skip_modules=>true) and Wagn::Codename[card.id.to_i]
            end
        end
        @opt_vals
      end

      def inspect
        "<#{self.class} #{to_s.to_name.inspect}>"
      end

      def to_s()
        if self.class.key_id == 0
          @anchor_name
        else
          kn = self.class.key_name
          self.class.anchorless? ? kn : "#{@anchor_name}+#{kn}"
        end
      end

      def safe_key()
        caps_part = self.class.key.gsub(' ','_').upcase
        self.class.anchorless? ? caps_part : "#{caps_part}-#{@anchor_name.safe_key}"
      end
      
      def rule_set_key
        if self.class.anchorless?
          self.class.key
        elsif @anchor_id
          [ @anchor_id, self.class.key ].map( &:to_s ) * '+'
        end
      end
    end

    class AllPattern < BasePattern
      register 'all', [], :method_key=>''
      def self.label(name)              'All cards'                end
      def self.prototype_args(base)     {}                         end
    end

    class AllPlusPattern < BasePattern
      register 'all_plus', :all_plus, :method_key=>'all_plus', :junction_only=>true
      def self.label(name)              'All "+" cards'            end
      def self.prototype_args(base)     {:name=>'+'}               end
    end

    class TypePattern < BasePattern
      register 'type', :type
      def self.label(name)              %{All "#{name}" cards}     end
      def self.prototype_args(base)     {:type=>base}              end
      def self.pattern_applies?(card)   !!card.type_id             end
      def self.anchor_name(card)        card.type_name             end
      def self.anchor_id(card)          card.type_id               end
        
    end

    class StarPattern < BasePattern
      register 'star', :star, :method_key=>'star'
      def self.label            name;   'All "*" cards'            end
      def self.prototype_args   base;   {:name=>'*dummy'}          end
      def self.pattern_applies? card;   card.cardname.star?        end
    end

    class RstarPattern < BasePattern
      register 'rstar', :rstar, :method_key=>'rstar', :junction_only=>true
      def self.label            name;   'All "+*" cards'           end
      def self.prototype_args   base;   { :name=>'*dummy+*dummy'}  end
      def self.pattern_applies? card;   card.cardname.rstar?       end
    end

    class RightPattern < BasePattern
      register 'right', :right, :junction_only=>true
      def self.label(name)              %{All "+#{name}" cards}    end
      def self.prototype_args(base)     {:name=>"*dummy+#{base}"}  end
      def self.anchor_name(card)        card.cardname.tag          end
    end

    class LeftTypeRightNamePattern < BasePattern
      register 'type_plus_right', [:ltype, :right], :junction_only=>true
      class << self
        def label name
          %{All "+#{name.to_name.tag}" cards on "#{name.to_name.left_name}" cards}
        end
        def prototype_args base
          { :name=>"*dummy+#{base.tag}",
            :loaded_left=> Card.new( :name=>'*dummy', :type=>base.trunk_name )
          }
        end
        def anchor_name card
          left = card.loaded_left || card.left
          type_name = (left && left.type_name) || Card[ Card::DefaultTypeID ].name
          "#{type_name}+#{card.cardname.tag}"
        end
      end
    end

    class SelfPattern < BasePattern
      register 'self', :name
      def self.label(name)              %{The card "#{name}"}      end
      def self.prototype_args(base)     { :name=>base }            end
      def self.anchor_name(card)        card.name                  end
      def self.anchor_id(card)          card.id                    end
    end
  end
end
