module Wagn
  module Set::Right::Account
    module Model
      def email perm=false
        Rails.logger.info "Right::Account#email perm:#{perm}, #{name}"
        perm = perm || Session.account.id == id || trunk.trait_card(:email).ok?(:read)
        Rails.logger.info "Right::Account#email perm:#{perm}, #{inspect}"
        perm && (user = Session.from_id(id)) && user.email || ''
      end

      def before_destroy
        block_user
      end

      def block_user
        account = Session.from_id(id) and account.block!  
      end
    end
  end
end
