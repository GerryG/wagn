module Wagn::Set::Self::Content
  module Model
    def config key=nil
      @configs||={
        :group=>:look,
        :seq=>7
      }
      key.nil? ? @configs : @configs[key.to_sym]
    end
  end
end