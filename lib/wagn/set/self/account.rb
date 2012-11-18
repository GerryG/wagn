module Wagn
  module Set::Self::Account
    # This is where we link in the User model as a card, and soon we will support
    # Warden account modules or similar

    #include Sets

    #format :html

    module Model
      def config key=nil
        @configs||={
          :trait=>true,
        }
        key.nil? ? @configs : @configs[key.to_sym]
      end
    end
  end
end
