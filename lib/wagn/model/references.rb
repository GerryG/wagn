
module Wagn
 module Model::References
  include Card::ReferenceTypes

  def name_referencers link_name=nil
    link_name = link_name.nil? ? key : link_name.to_name.key
    
    Card.all :joins => :out_references, :conditions => { :card_references => { :referee_key => link_name } }
  end

  def extended_referencers
    # FIXME .. we really just need a number here.
    (dependents + [self]).map(&:referencers).flatten.uniq
  end

  def replace_references old_name, new_name
    obj_content = ObjectContent.new(content, {:card=>self} )
    obj_content.find_chunks(Chunk::Reference).select do |chunk|
     if was_name = chunk.cardname and new_cardname = was_name.replace_part(old_name, new_name) and
          was_name != new_cardname

      Chunk::Link===chunk and link_bound = chunk.cardname == chunk.link_text

      chunk.cardname = chunk.replace_reference old_name, new_name
      Card::Reference.where(:referee_key => was_name.key).update_all( :referee_key => new_cardname.key )

      chunk.link_text=chunk.cardname.to_s if link_bound
    end
    obj_content.to_s
  end

        
  def update_references rendering_result = nil, refresh = false

    #warn "update references...card name: #{card.name}, rr: #{rendering_result}, refresh: #{refresh}"
    return if id.nil?

    Rails.logger.info "update refs #{inspect}"
    #raise "???" if caller.length > 500

    Card::Reference.delete_all :card_id => id

    # FIXME: why not like this: references_expired = nil # do we have to make sure this is saved?
    #Card.update( id, :references_expired=>nil )
    #  or just this and save it elsewhere?
    #references_expired=nil
    connection.execute("update cards set references_expired=NULL where id=#{id}")
    expire if frozen?

    if rendering_result.nil?
       rendering_result = WikiContent.new(self, _render_refs, renderer).render! do |opts|
           expand_inclusion(opts) { yield }
       end

      if referer_id != ( referee_id = chunk.refcard.send_if :id ) &&
         !hash.has_key?( referee_key = referee_id || chunk.refcardname.key )

        hash[ referee_key ] = {
          :referee_id  => referee_id,
          :referee_key => chunk.refcardname.send_if( :key ),
          :link_type   => Chunk::Link===chunk ? LINK : INCLUDE,
          :present     => chunk.refcard.nil?  ?   0  :   1
        }
      end

      hash
    end.each_value { |update| Card::Reference.create! update.merge( :referer_id => referer_id ) }

  end

  # ---------- Referenced cards --------------

  def referencers
    return [] unless refs = references
    refs.map(&:referer_id).map( &Card.method(:fetch) )
  end

  def includers
    return [] unless refs = includes
    refs.map(&:referer_id).map( &Card.method(:fetch) )
  end

=begin
  def existing_referencers
    return [] unless refs = references
    refs.map(&:referee_key).map( &Card.method(:fetch) ).compact
  end

  def existing_includers
    return [] unless refs = includes
    refs.map(&:referee_key).map( &Card.method(:fetch) ).compact
  end
=end

  # ---------- Referencing cards --------------

  def referencees
    return [] unless refs = out_references
    refs. map { |ref| Card.fetch ref.referee_key, :new=>{} }
  end

  def includees
    return [] unless refs = out_includes
    refs.map { |ref| Card.fetch ref.referee_key, :new=>{} }
  end

  protected

  def update_references_on_create
    set_initial_content unless current_revision_id

    Card::Reference.update_on_create self

    # FIXME: bogus blank default content is set on hard_templated cards...
    Account.as_bot do
      Renderer.new(self, :not_current=>true).update_references
    end

    obj_content.to_s
  end

  def self.included(base)

    super

    base.class_eval do

      # ---------- Reference associations -----------
      has_many :references,  :class_name => :Reference, :foreign_key => :referee_id
      has_many :includes, :class_name => :Reference, :foreign_key => :referee_id,
        :conditions => { :link_type => INCLUDE }

      has_many :out_references,  :class_name => :Reference, :foreign_key => :referer_id
      has_many :out_includes, :class_name => :Reference, :foreign_key => :referer_id, :conditions => { :link_type => INCLUDE }

      after_create  :update_references_on_create
      after_destroy :update_references_on_destroy
      after_update  :update_references_on_update
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
