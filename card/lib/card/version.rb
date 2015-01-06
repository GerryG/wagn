# -*- encoding : utf-8 -*-

module Card::Version
  class << self
    
    def release
      @@version ||= File.read( File.expand_path '../../../VERSION', __FILE__ ).strip
    end
  
    def schema type=nil
      File.read( schema_stamp_path type ).strip
    end

    def schema_stamp_path type
      root_dir = ( type == :deck_cards ? Cardio.root : Cardio.gem_root )
      stamp_dir = ENV['SCHEMA_STAMP_PATH'] || File.join( root_dir, 'db' )
      
      File.join stamp_dir, "version#{ schema_suffix(type) }.txt"  
    end
    
    def schema_suffix type
      Cardio.schema_suffix type
    end
    
  end
end
