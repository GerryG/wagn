module Wagn::Model::Settings
  def rule setting_name, options={}
    options[:skip_modules] = true
    card = rule_card setting_name, options
    card && card.content
  end

  def rule_card setting_name, options={}
    fallback = options.delete( :fallback )
    fetch_args = {:skip_virtual=>true}.merge options
    #warn "setting_kind = #{scard = Card[setting_name]} #{scard and scard.type_id == Card::SettingID} #{scard and scard.setting_kind}"
    setting_kind = (scard = Card[setting_name] and scard.type_id == Card::SettingID and scard.setting_kind)
    #warn "rule_card[#{name}] #{setting_name}, #{options.inspect} K:#{setting_kind}, RSN:#{real_set_names(setting_kind).inspect}" if setting_name == :autoname
    real_set_names(setting_kind).each do |set_name|
      #warn "rule_card search #{set_name.inspect}" if setting_name == :autoname
      set_name=set_name.to_cardname
      card = Card.fetch(set_name.trait_name( setting_name ), fetch_args)
      card ||= fallback && Card.fetch(set_name.trait_name(fallback), fetch_args)
      #warn "rule #{name} [#{set_name}] rc:#{card.inspect}" if setting_name == :autoname
      return card if card
    end
    #warn (Rails.logger.warn "rc nothing #{setting_name}, #{name}") if setting_name == :autoname
    nil
  end
  def rule_card_with_cache setting_name, options={}
    setting_name = (sc=Card[setting_name] and (sc.codename || sc.name).to_sym) unless Symbol===setting_name
    @rule_cards ||= {}  # FIXME: initialize this when creating card
    rcwc = (@rule_cards[setting_name] ||=
      rule_card_without_cache setting_name, options)
    #warn (Rails.logger.warn "rcwc #{rcwc.inspect}"); rcwc #if setting_name == :read; rcwc
  end
  alias_method_chain :rule_card, :cache

  def related_sets
    # refers to sets that users may configure from the current card - NOT to sets to which the current card belongs
    sets = ["#{name}+*self"]
    sets << "#{name}+*type" if type_id==Card::CardtypeID
    if cardname.simple?
      sets<< "#{name}+*right"
      Card.search(:type=>'Set',:left=>{:right=>name},:right=>'*type plus right',:return=>'name').each do |set_name|
        sets<< set_name
      end
    end
    sets
  end

  def set_group() nil end

  module ClassMethods
    def default_rule setting_name, fallback=nil
      card = default_rule_card setting_name, fallback
      return card && card.content
    end

    def default_rule_card setting_name, fallback=nil
      Card["*all".to_cardname.trait_name(setting_name)] or
        fallback ? default_rule_card(fallback) : nil
    end

    def universal_setting_names_by_group
      @@universal_setting_names_by_group ||= begin
        Session.as_bot do
          Card.search(:type=>Card::SettingID, :limit=>'0').inject({}) do |grouped,setting_card|
            next unless group = setting_card.setting_group(set_group)
            grouped[ group ] ||= []
            grouped[ group ] << setting_card
            grouped
          end.map do |group, card_list|
            card_list.sort!{ |x,y| x.setting_seq <=> y.setting_seq}.map(&:name)
          end
        end
      end
    end
  end

  def self.included(base)
    super
    base.extend(ClassMethods)
  end

end
