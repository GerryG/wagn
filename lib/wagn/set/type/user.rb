module Wagn
  module Set::Type::User
    #include Sets

    module Model
      def email perm=false
        user = perm || Account.authorized.id == left_id || (trait_ok? :email, :read)
        Rails.logger.info "Type::User#email cd#{user.inspect}, #{inspect} P#{perm}"
        user && (user = Account.from_id((cd=fetch_trait :account) && cd.id)) && user.email || ''
      end
    end
  end
end
