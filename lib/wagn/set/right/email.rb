module Wagn
  module Set::Right::Email
    include Sets

    format :base

    define_view  :raw, :right=>:email, :denial=>:blank, :perms => :read do |args|
      Rails.logger.info "email raw #{card.inspect}"
      trunk = card.trunk
      trunk.respond_to?(:email) ? trunk.email : ''
    end
    alias_view :raw, {:right=>:email}, :core
  end
end
