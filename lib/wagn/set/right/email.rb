module Wagn
  module Set::Right::Email
    include Sets

    format :base

    define_view  :raw, :right=>:email, :denial=>:blank, :perms => :read do |args|
      user=card.trunk.user and user.email
    end
    alias_view :raw, {:right=>:email}, :core
  end
end
