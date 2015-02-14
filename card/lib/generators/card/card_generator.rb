# -*- encoding : utf-8 -*-

class Card
  module Generators
    class CardGenerator < NamedBase
      include Rails::Generators::Migration
      extend ActiveRecord::Generators::Migration

      source_root File.expand_path('../templates', __FILE__)

      argument :mount_point, :required=>false
      argument :prefix, :required=>false

      def self.namespace
        'card'
      end

      def create_files
        name_prefix = name == 'base' ? '' : name+'_'
        template 'config/routes.erb', "config/#{name_prefix}routes.rb"

        mig_name = 'create_cards_tables'
        dirname = 'db/migrations'
        if destination = self.class.migration_exists?(dirname, mig_name) and options.force?
          remove_file(destination)
        elsif destination
          raise "Another migration is already named #{mig_name}: #{destination}"
        end
        template 'create_cards_tables.erb', "#{dirname}/#{self.class.next_migration_number(dirname)}_#{mig_name}.rb"
      end
    end
  end
end
