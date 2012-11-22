module Wagn
  module Set::Right::Account
    module Model
      def email perm=false
        Rails.logger.info "Right::Account#email perm:#{perm}, #{name}"
        perm = perm || Account.session.id == id || (trunk.trait_ok?(:email, :read))
        Rails.logger.info "Right::Account#email perm:#{perm}, #{inspect}"
        perm && (user = Account.from_id(id)) && user.email || ''
      end

      def before_destroy
        block_user
      end

      def block_user
        account = Account.from_id(id) and account.block!
      end

      #has_one :account, :class_name => 'User'  Instead of this association, override .user here
      def user
        Account.from_id account_id
      end
    end
  end
end
