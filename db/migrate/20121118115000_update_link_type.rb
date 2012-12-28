require_dependency 'chunks/chunk'
require_dependency 'chunk_manager'

class UpdateLinkType < ActiveRecord::Migration
  include Card::ReferenceTypes

  LINK_TYPES    = [ 'L', 'W' ]
  INCLUDE_TYPES = [ 'I', 'T', 'M' ]

  MISSING    = [ LINK_TYPES.last,  INCLUDE.last  ]
  PRESENT    = [ LINK_TYPES.first, INCLUDE.first ]

  def up
    Card::Reference.update_all(:present=>1)
    Card::Reference.where(:link_type=>LINK_TYPES.last).   update_all(:present=>0, :link_type=>LINK_TYPES.first)
    Card::Reference.where(:link_type=>INCLUDE_TYPES.last).update_all(:present=>0, :link_type=>INCLUDE_TYPES.first)
  end

  def down
    Card::Reference.where(:present=>0, :link_type=>LINK_TYPES.first).   update_all(:link_type=>LINK_TYPES.last)
    Card::Reference.where(:present=>0, :link_type=>INCLUDE_TYPES.first).update_all(:link_type=>INCLUDE_TYPES.last)
  end
end
