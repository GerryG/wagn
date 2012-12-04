
module Wagn
 module Model::References
  include Card::ReferenceTypes

  def name_referencers(rname = key)
    Card.find_by_sql(
      "SELECT DISTINCT c.* FROM cards c JOIN card_references r ON c.id = r.card_id "+
      "WHERE (r.referenced_name = #{ActiveRecord::Base.connection.quote(rname.to_name.key)})"
    )
  end

  def extended_referencers
    #fixme .. we really just need a number here.
    (dependents + [self]).plot(:referencers).flatten.uniq
  end

  def replace_references old_name, new_name
    obj_content = ObjectContent.new(content, {:card=>self} )
    obj_content.find_chunks(Chunk::Reference).select do |chunk|
      chunk.replace_reference old_name, new_name
    end

    obj_content.to_s
  end

  def update_references rendering_result = nil, refresh = false
    return unless id
    Card::Reference.delete_all ['card_id = ?', id]
    connection.execute("update cards set references_expired=NULL where id=#{id}")
    expire if refresh
    content = respond_to?('references_expired') ? raw_content : ''
    rendering_result ||= ObjectContent.new(content, {:card=>self} )
    rendering_result.find_chunks(Chunk::Reference).each do |chunk|
      # validate class?  find_chunks should be working, right?
      #raise "Unknown chunk reference class #{chunk.class}"

      Card::Reference.create!(
        :card_id            =>id,
        :referenced_name    => chunk.reference_name,
        :referenced_card_id => chunk.reference_id,
        :present            => chunk.reference_card.nil? ? 0 : 1,
        :link_type          => Chunk::Link===chunk ? LINK : TRANSCLUDE
      )
    end
  end

  def self.included(base)
    super
    base.class_eval do

      has_many :in_references,:class_name=>'Card::Reference', :foreign_key=>'referenced_card_id'
      has_many :out_references,:class_name=>'Card::Reference', :foreign_key=>'card_id', :dependent=>:destroy

      has_many :in_transclusions, :class_name=>'Card::Reference', :foreign_key=>'referenced_card_id',
               :conditions=>{ :link_type => TRANSCLUDE }
      has_many :out_transclusions,:class_name=>'Card::Reference', :foreign_key=>'card_id',
               :conditions=>{ :link_type => TRANSCLUDE }

      has_many :referencers, :through=>:in_references
      has_many :transcluders, :through=>:in_transclusions, :source=>:referencer

      has_many :referencees, :through=>:out_references
      has_many :transcludees, :through=>:out_transclusions, :source=>:referencee # used in tests only

      after_create :update_references_on_create
      after_destroy :update_references_on_destroy
      after_update :update_references_on_update

    end
  end

  protected

  def update_references_on_create
    Card::Reference.update_on_create(self)

    # FIXME: bogus blank default content is set on hard_templated cards...
    Account.as_bot do
      self.update_references
    end
    expire_templatee_references
  end

  def update_references_on_update
    self.update_references
    expire_templatee_references
  end

  def update_references_on_destroy
    Card::Reference.update_on_destroy(self)
    expire_templatee_references
  end

 end
end
