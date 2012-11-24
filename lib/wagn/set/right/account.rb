module Wagn
  module Set::Right::Account
    module Model
      def before_destroy
        block_account
      end

      def block_account
        acct=account
        warn "block_acct #{acct=account}, bk!#{acct and acct.block!}"
        acct and acct.block!
      end

      def account
        @account ||= Account[id]
      end
    end
  end
end
