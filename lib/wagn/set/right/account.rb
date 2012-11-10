module Wagn
  module Set::Right::Account
    module Model
      def email perm=false
        Rails.logger.info "Right::Account#email perm:#{perm}, #{name}"
        perm = perm || Account.account.id == id || trunk.trait_card(:email).ok?(:read)
        Rails.logger.info "Right::Account#email perm:#{perm}, #{inspect}"
        perm && (user = Account.from_id(id)) && user.email || ''
      end

      def before_destroy
        block_user
      end

      def block_user
        account = Account.from_id(id) and account.block!  
      end
    end
  end
end
