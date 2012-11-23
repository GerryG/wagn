module Wagn
  module Set::Right::Account
    module Model
      def before_destroy
        block_account
      end

<<<<<<< HEAD
      def block_user
        user and user.block!
=======
      def block_account
        user and user.block!  
>>>>>>> traits_and_forms
      end

      def user
        @user ||= User.from_id id
      end
    end
  end
end
