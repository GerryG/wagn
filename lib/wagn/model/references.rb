module Wagn::Model::References
  include ReferenceTypes

  def name_referencers(rname = key)
    Card.find_by_sql(
      "SELECT DISTINCT c.* FROM cards c JOIN card_references r ON c.id = r.card_id "+
      "WHERE (r.referenced_name = #{ActiveRecord::Base.connection.quote(rname.to_cardname.key)})"
    )
  end

  def extended_referencers
    (dependents + [self]).plot(:referencers).flatten.uniq
  end

  def replace_references old_name, new_name
    #Rails.logger.warn "replacing references...card name: #{name}, old name: #{old_name}, new_name: #{new_name}"
    obj_content = ObjectContent.new(content, {:card=>self} )

    obj_content.find_chunks(Chunk::Link).select do |chunk|
      #Rails.logger.warn "rr... #{chunk}, old name: #{old_name}, new_name: #{new_name}"
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
      reference_type =
        case chunk
          when Chunk::Link;       chunk.reference_card ? LINK : WANTED_LINK
          when Chunk::Transclude; chunk.reference_card ? TRANSCLUSION : WANTED_TRANSCLUSION
          else raise "Unknown chunk reference class #{chunk.class}"
        end

      Card::Reference.create!( :card_id=>id, :referenced_name=> chunk.reference_name,
        :referenced_card_id=> chunk.reference_id, :link_type=>reference_type )
    end
  end

  def self.included(base)
    super
    base.class_eval do

      has_many :in_references,:class_name=>'Card::Reference', :foreign_key=>'referenced_card_id'
      has_many :out_references,:class_name=>'Card::Reference', :foreign_key=>'card_id', :dependent=>:destroy

      has_many :in_transclusions, :class_name=>'Card::Reference', :foreign_key=>'referenced_card_id',:conditions=>["link_type in (?,?)",Card::Reference::TRANSCLUSION, Card::Reference::WANTED_TRANSCLUSION]
      has_many :out_transclusions,:class_name=>'Card::Reference', :foreign_key=>'card_id',           :conditions=>["link_type in (?,?)",Card::Reference::TRANSCLUSION, Card::Reference::WANTED_TRANSCLUSION]

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
    Session.as_bot do
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
