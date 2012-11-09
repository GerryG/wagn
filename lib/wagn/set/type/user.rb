module Wagn
  module Set::Type::User
    #include Sets

    module Model
      def email
        perm = trait_card(:email).ok?(:read)
        account = (perm) ? trait_card(:account) : nil
        Rails.logger.warn "user type email #{inspect} As:#{Session.as_card.inspect}, Act:#{Session.account.inspect}, P#{perm}, #{account}, E:#{account &&account.email}"
        r=(account and !account.new_card? and User.from_id(account.id).email or '')
        #Rails.logger.warn "user type email #{inspect} As:#{Session.as_card.inspect}, Act:#{Session.account.inspect}, R:#{r} TC:#{trait_card(:email).inspect}, P#{perm}, #{account}, E:#{account &&account.email}"; r
      end
    end
  end
end
