
module Wagn::Set::Type::Set
  class Wagn::Views
    format :base

    # make these into traits of Setting cards:
    # *content+*group => [[:code]]
    # where below are the codenames and the cardnames (in Wagn seed DB)
    #@@setting_group_title = {
    #  :perms   => 'Permission',
    #  :look    => 'Look and Feel',
    #  :com     => 'Communication',
    #  :other   => 'Other',
    #  :pointer => 'Pointer'
    #}
    # should construct this from a search:
    # to  model/settings: Card class method
    def setting_groups
      [:perms, :look, :com, :pointer, :other]
    end

    define_view :core , :type=>:set do |args|
      body = card.setting_names_by_group.map do |group, data|
        next if data.nil?
        content_tag(:tr, :class=>"rule-group") do
          (["#{Card[group].name} Settings"]+%w{Content Type}).map do |heading|
            content_tag(:th, :class=>'rule-heading') { heading }
          end * "\n"
        end +
        raw( data.map do |setting_code|
          setting_name = (setting_card=Card[setting_code]).nil? ? "no setting ?" : setting_card.name
          rule_card = card.trait_card(setting_code)
          process_inclusion(rule_card, :view=>:closed_rule)
        end * "\n" )
      end.compact * ''

      content_tag('table', :class=>'set-rules') { body }
    end


    define_view :editor, :type=>'set' do |args|
      'Cannot currently edit Sets' #ENGLISH
    end

    alias_view(:closed_content , {:type=>:search_type}, {:type=>:set})

  end

  module Model
    include Wagn::Set::Type::SearchType::Model

    def inheritable?
      return true if junction_only?
      cardname.tag==Wagn::Model::Patterns::SelfPattern.key_name and cardname.trunk_name.junction?
    end

    def subclass_for_set
      #FIXME - use codename??
      Wagn::Model::Pattern.subclasses.find do |sub|
        cardname.tag==sub.key_name
      end
    end

    def junction_only?()
      !@junction_only.nil? ? @junction_only :
         @junction_only = subclass_for_set.junction_only
    end

    def reset_set_patterns
      Card.members( key ).each do |mem|
        Card.expire mem
      end
    end

    def label
      if klass = subclass_for_set
        klass.label cardname.left
      else
        ''
      end
    end

    def set_group
      Card::PointerID == ( templt = existing_trait_card(:content) || existing_trait_card(:default) and
          templt.type_id or tag.id == Card::TypeID ? trunk.id : trunk.type_id ) and :pointer or nil
    end

    def prototype
      opts = subclass_for_set.prototype_args(self.cardname.trunk_name)
      Card.fetch_or_new opts[:name], opts
    end

  end
end
