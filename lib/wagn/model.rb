Wagn.send :include, Wagn::Exceptions

module Wagn::Model
  def self.included(base)
    super
    Wagn::Sets.load

    Rails.logger.warn "model constants: #{Wagn::Model.constants.map(&:to_s)*", "}"
    Wagn::Model.constants.each do |const|
      base.send :include, Wagn::Model.const_get(const)
    end
  end

  # this is designed to throw an error on load,
  # make sure they can't delete it!
  #@@all_defaut_rule = Card[:all].fetch(:trait => :default).id
  #def self.all_default_rule; @@all_default_rule end
end
