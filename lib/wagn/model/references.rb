
module Wagn
 module Model::References
  include Card::ReferenceTypes

  def name_referencers ref_name=nil
    ref_name = ref_name.nil? ? key : ref_name.to_name.key
    
    #warn "name refs for #{ref_name.inspect}"
    r=Card.all( :joins => :out_references, :conditions => { :card_references => { :referee_key => ref_name } } )
    #warn "name refs #{inspect} ::  #{r.map(&:inspect)*', '}"; r
  end

  def extended_referencers
    # FIXME .. we really just need a number here.
    (dependents + [self]).map(&:referencers).flatten.uniq
  end

  def replace_references old_name, new_name
    obj_content = ObjectContent.new(content, {:card=>self} )
    obj_content.find_chunks(Chunk::Reference).select do |chunk|
      chunk.replace_reference old_name, new_name
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
    end

    hash = rendering_result.find_chunks(Chunk::Reference).inject({}) do |h, chunk|

      if id == ( referer_id = chunk.refcard.send_if :id ); h

      else
        ref_name = chunk.refcardname.send_if :key
        h.merge (referer_id || ref_name) => { :referer_id => referer_id, :name => ref_name,
            :link_type => Chunk::Link===chunk ? LINK : TRANSCLUDE,
            :present => chunk.refcard.nil?  ?   0  :   1
          }
      end
    end
 
    #Rails.logger.warn "update refs hash #{hash.inspect}"
    hash.each do |referer_kid, v|
      #warn "card ref #{v.inspect}"
      #Rails.logger.warn "card ref #{v.inspect}"
      Card::Reference.create! :card_id => id,
        :referenced_card_id => v[:referer_id], :referenced_name => v[:name],
        :link_type => v[:link_type], :present => v[:present]
    end
  end

  # ---------- Referenced cards --------------

  def referencers
    #warn "ncers #{inspect} :: #{references.inspect}"
    return [] unless refs = references
    #warn "ncers 2 #{inspect} :: #{refs.inspect}"
    refs.map(&:referer_id).map( &Card.method(:fetch) )
  end

  def includers
    return [] unless refs = includes
    #warn "clders #{inspect} :: #{refs.inspect}"
    refs.map(&:referer_id).map( &Card.method(:fetch) )
  end

=begin
  def existing_referencers
    return [] unless refs = references
    #warn "e ncers #{inspect} :: #{refs.inspect}"
    refs.map(&:referee_key).map( &Card.method(:fetch) ).compact
  end

  def existing_includers
    return [] unless refs = includes
    #warn "e clders #{inspect} :: #{refs.inspect}"
    refs.map(&:referee_key).map( &Card.method(:fetch) ).compact
  end
=end

  # ---------- Referencing cards --------------

  def referencees
    return [] unless refs = out_references
    #warn "cees #{inspect} :: #{refs.inspect}"
    refs. map { |ref| Card.fetch ref.referee_key, :new=>{} }
  end

  def includees
    return [] unless refs = out_includes
    #warn "cldees #{inspect} :: #{refs.inspect}"
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
