module Wagn
  module Set::Right::Account
    module Model
      def before_destroy
        block_user
      end

      def block_user
        user and user.block!
      end

      def user
        @user ||= User.from_id id
      end
    end
  end
end
