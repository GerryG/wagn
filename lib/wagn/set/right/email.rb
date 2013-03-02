module Wagn
  module Set::Right::Email
    include Sets

    format :base

    define_view  :raw, :right=>'email'  do |args|
      acct=card.trunk.account and acct.email
    end
    alias_view :raw, {:right=>:email}, :core
  end
end
