module Wagn
  module Set::Type::User
    #include Sets

    module Model
      def email perm=false
        user = perm || Account.authorized.id == trunk_id || (tk=fetch_trait(:email) and tk.ok?(:read))
        Rails.logger.info "Type::User#email cd#{user.inspect}, #{inspect} P#{perm}"
        user && (user = Account.from_id((cd=fetch_trait :account) && cd.id)) && user.email || ''
      end
    end
  end
end
