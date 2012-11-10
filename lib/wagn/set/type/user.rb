module Wagn
  module Set::Type::User
    #include Sets

    module Model
      def email perm=false
        user = perm || Session.authorized.id == trunk_id || trait_card(:email).ok?(:read)
        Rails.logger.info "Type::User#email cd#{user.inspect}, #{inspect} P#{perm}"
        user && (user = Session.from_id((cd=trait_card :account) && cd.id)) && user.email || ''
      end
    end
  end
end
