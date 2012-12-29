module Cardlib::References

  def name_referencers link_name=nil
    link_name = link_name.nil? ? key : link_name.to_name.key
    
    Card.all :joins => :out_references, :conditions => { :card_references => { :referee_key => link_name } }
  end

  def extended_referencers
    # FIXME .. we really just need a number here.
    (dependents + [self]).map(&:referencers).flatten.uniq
  end

  # ---------- Referenced cards --------------

  def referencers
    return [] unless refs = references
    refs.map(&:referer_id).map( &Card.method(:fetch) )
  end

  def includers
    return [] unless refs = inclusions
    refs.map(&:referer_id).map( &Card.method(:fetch) )
  end

=begin
  def existing_referencers
    return [] unless refs = references
    refs.map(&:referee_key).map( &Card.method(:fetch) ).compact
  end

  def existing_includers
    return [] unless refs = inclusions
    refs.map(&:referee_key).map( &Card.method(:fetch) ).compact
  end
=end

  # ---------- Referencing cards --------------

  def referencees
    return [] unless refs = out_references
    refs. map { |ref| Card.fetch ref.referee_key, :new=>{} }
  end

  def includees
    return [] unless refs = out_inclusions
    refs.map { |ref| Card.fetch ref.referee_key, :new=>{} }
  end

  protected

  def update_references_on_create
    Card::Reference.update_on_create self

    # FIXME: bogus blank default content is set on hard_templated cards...
    Account.as_bot do
      Wagn::Renderer.new(self, :not_current=>true).update_references
    end
    expire_templatee_references
  end

  def update_references_on_update
    Wagn::Renderer.new(self, :not_current=>true).update_references
    expire_templatee_references
  end

  def update_references_on_destroy
    Card::Reference.update_on_destroy(self)
    expire_templatee_references
  end



  def self.included(base)
    super
    base.class_eval do

<<<<<<< HEAD
      # ---------- Reference associations -----------
      has_many :references,  :class_name => :Reference, :foreign_key => :referee_id
      has_many :inclusions, :class_name => :Reference, :foreign_key => :referee_id,
        :conditions => { :link_type => INCLUDE }

      has_many :out_references,  :class_name => :Reference, :foreign_key => :referer_id
      has_many :out_inclusions, :class_name => :Reference, :foreign_key => :referer_id, :conditions => { :link_type => INCLUDE }
=======
      has_many :in_references,:class_name=>'Card::Reference', :foreign_key=>'referenced_card_id'
      has_many :out_references,:class_name=>'Card::Reference', :foreign_key=>'card_id', :dependent=>:destroy

      has_many :in_transclusions, :class_name=>'Card::Reference', :foreign_key=>'referenced_card_id',:conditions=>["link_type in (?,?)",Card::Reference::TRANSCLUSION, Card::Reference::WANTED_TRANSCLUSION]
      has_many :out_transclusions,:class_name=>'Card::Reference', :foreign_key=>'card_id',           :conditions=>["link_type in (?,?)",Card::Reference::TRANSCLUSION, Card::Reference::WANTED_TRANSCLUSION]

      has_many :referencers, :through=>:in_references
      has_many :transcluders, :through=>:in_transclusions, :source=>:referencer
>>>>>>> load_cardlib

      has_many :referencees, :through=>:out_references
      has_many :transcludees, :through=>:out_transclusions, :source=>:referencee # used in tests only

      after_create :update_references_on_create
      after_destroy :update_references_on_destroy
      after_update :update_references_on_update

    end

  end
end
