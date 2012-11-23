module Wagn
  module Set::Right::Account
    module Model
      def before_destroy
        block_account
      end

      def block_user
        account and account.block!  
      end
      
      def user
        @user ||= User.from_id id
      end
    end
  end
end
