module Wagn
  module Set::Right::Account
    module Model
      def before_destroy
        block_account
      end

      def block_account
        acct=account and acct.block!
        Rails.logger.warn "blocking #{inspect} #{acct.inspect}"
        #@account = nil
        Rails.logger.warn "blocking #{inspect} #{acct.inspect}"
      end

      def account
        @account ||= Account[id]
      end
    end
  end
end
