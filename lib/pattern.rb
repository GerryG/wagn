class Pattern
  @@subclasses = []
  @@registry = {}
  class << self

    
    def create( spec )
      matching_classes = @@subclasses.select {|pattern_class| pattern_class.recognize( spec ) }
      raise("invalid pattern") if matching_classes.length < 1
      raise("pattern conflict") if matching_classes.length > 1
      matching_classes.first.new( spec )
    end 

    def register_class( klass )
      @@subclasses << klass
    end
    # 
    # def register( pattern )      
    #   @@registry[ pattern.key ] ||= []
    #   @@registry[ pattern.key ] << pattern
    # end            
    # 
    # def patterns_for(card)
    #   card.pattern_keys ||= keys_for(card)
    #   card.pattern_keys.map { |key| @@registry[ key ] }.flatten.order_by(&:priority)
    # end                                                          
    # 
    # def cards_for(pattern)
    #   Card.search( pattern.spec )
    # end
    # 
    # 
    # private
    # def keys_for(card)
    #   @@subclasses.map { |pattern_class| pattern_class.key_for(card) }.compact
    # end

  end  
   
  attr_reader :spec
  
  def initialize spec
    @spec = spec
  end
end                                                                     



class TypePattern < Pattern
  class << self
    def key_for_card card
      "Type:#{card.type}"
    end 

    def recognize spec
      spec[:type] && spec[:type].is_a?(String) && spec.keys.length == 1
    end

    def key_for_spec spec
      "Type:#{spec[:type]}"                        
    end    
  end
  register_class self
end



class RightNamePattern < Pattern 
  class << self
    def key_for_card card
      return nil unless card.junction?
      "RightName:#{card.name.tag_name}"
    end
  
    def recognize spec
      spec[:right] && spec[:right].is_a?(String) && spec.keys.length == 1
    end
  
    def key_for_spec spec
      "RightName:#{spec[:right]}"
    end
  end
  register_class self
end



class LeftTypeRightNamePattern < Pattern                     
  class << self
    def key_for_card card
      return nil unless card.junction?      
      "LeftTypeRightName:#{card.left.type}:#{card.name.tag_name}"
    end
  
    def recognize spec
      !!(spec[:right] && spec[:right].is_a?(String) &&
            spec[:left] && spec[:left].is_a?(Hash) && spec[:left][:type])
    end                                
  
    def key_for_spec spec
      "LeftTypeRightName:#{spec[:left][:type]}:#{spec[:right]}"
    end
  end
  register_class self
end      

