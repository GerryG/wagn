module Wagn
  module Set::Right::Account
    module Model
      def email
        perm = Session.account.id == id || trunk.trait_card(:email).ok?(:read)
        Rails.logger.warn "rt acct email #{perm}, CN:#{name}"
        r=(perm and user = User.from_id(id) and user.email or '')
        Rails.logger.warn "rt acct email for#{name}, r:#{r}"; r
      end

      def before_destroy
        block_user
      end

      def block_user
        Rails.logger.info "block_user #{inspect}, u:#{User.from_id id }"
        if account = User.from_id(id)
          st=account.block!
          Rails.logger.info "block_user #{inspect}, Acct:#{account.inspect}, #{a=User.from_id(account.card_id) and a.status}, st:#{st and account.errors.map(&:to_s)*", "}\nST:#{st}"; st
        end
      end
    end
  end
end
