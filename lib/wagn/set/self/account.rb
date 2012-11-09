module Wagn
  module Set::Right::Account
    # This is where we link in the User model as a card, and soon we will support
    # Warden account modules or similar

    include Sets

    format :html

    module Model
      def setting_kind(e=nil) :trait end
      def setting_seq() 15 end
    end
  end
end
