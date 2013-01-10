require File.expand_path(File.dirname(__FILE__) + '/../util/card_builder.rb')
#how is this used?



def set_database( db )
  y = YAML.load_file("#{Rails.root.to_s}/config/database.yml")
  y["development"]["database"] = db
  y["production"]["database"] = db
  File.open( "#{Rails.root.to_s}/config/database.yml", 'w' ) do |out|
    YAML.dump( y, out )
  end
end

# desc 'Check for pending migrations and load the test schema'
# task :prepare => 'db:abort_if_pending_migrations' do
#   if defined?(ActiveRecord) && !ActiveRecord::Base.configurations.blank?
#     Rake::Task[{ :sql  => "db:test:clone_structure", :ruby => "db:test:load" }[ActiveRecord::Base.schema_format]].invoke
#   end
# end

namespace :db do
  namespace :fixtures do
    desc "Load fixtures into the current environment's database.  Load specific fixtures using FIXTURES=x,y"
    task :load => :environment do
      require 'active_record/fixtures'
      ActiveRecord::Base.establish_connection(::Rails.env.to_sym)
      (ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/) : Dir.glob(File.join(Rails.root.to_s, 'test', 'fixtures', '*.{yml,csv}'))).each do |fixture_file|
        ActiveRecord::Fixtures.create_fixtures('test/fixtures', File.basename(fixture_file, '.*'))
      end
    end
  end
end

namespace :test do
  ## FIXME: this generates an "Adminstrator links" card with the wrong reader_id, I have been
  ##  setting it by hand after fixture generation.
  desc "recreate test fixtures from fresh db"
  task :generate_fixtures => :environment do
    Rake::Task['cache:clear']
    # env gets auto-set to 'test' somehow.
    # but we need development to get the right schema dumped.
    ENV['RAILS_ENV'] = 'development'

    abcs = ActiveRecord::Base.configurations
    config = ENV['RAILS_ENV'] || 'development'
    olddb = abcs[config]["database"]
    abcs[config]["database"] = "wagn_test_template"

  #=begin
    begin
      # assume we have a good database, ie. just migrated dev db.
      puts "setting database to wagn_test_template"
      set_database 'wagn_test_template'
      Rake::Task['wagn:create'].invoke

      # I spent waay to long trying to do this in a less hacky way--
      # Basically initial database setup/migration breaks your models and you really
      # need to start rails over to get things going again I tried ActiveRecord::Base.reset_subclasses etc. to no avail. -LWH
      puts ">>populating test data"
      puts `rake test:populate_template_database --trace`
      puts ">>extracting to fixtures"
      puts `rake test:extract_fixtures --trace`
    ensure
      set_database olddb
    end
    # go ahead and load the fixtures into the test database
    puts ">> preparing test database"
    puts `env RELOAD_TEST_DATA=true rake db:test:prepare --trace`
  end


  desc "dump current db to test fixtures"
  task :extract_fixtures => :environment do
     YAML::ENGINE.yamler = 'syck'
      # use old engine while we're supporting ruby 1.8.7 because it can't support Psych,
      # which dumps with slashes that syck can't understand (also !!null stuff)

    sql = "SELECT * FROM %s"
    skip_tables = ["schema_info","schema_migrations","sessions"]
    ActiveRecord::Base.establish_connection
    (ActiveRecord::Base.connection.tables - skip_tables).each do |table_name|
      i = "000"
      File.open("#{Rails.root.to_s}/test/fixtures/#{table_name}.yml", 'w') do |file|
        data = ActiveRecord::Base.connection.select_all(sql % table_name)
        file.write data.inject({}) { |hash, record|
          hash["#{table_name}_#{i.succ!}"] = record
          hash
        }.to_yaml
      end
    end
  end

  desc "create sample data for testing"
  task :populate_template_database => :environment do
    load 'test/seed.rb'
    SharedData.add_test_data
  end

end
