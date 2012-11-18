module Wagn::Set::Self::Autoname
  module Model
    def config key=nil
      @configs||={
        :group=>:other,
        :seq=>14
      }
      key.nil? ? @configs : @configs[key.to_sym]
    end
  end
end
