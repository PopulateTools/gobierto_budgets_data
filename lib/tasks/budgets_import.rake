namespace :gobierto_budgets_data do
  namespace :budgets do
    def create_db_connection(db_name)
      db_params = ActiveRecord::Base.configurations.find_db_config(Rails.env).configuration_hash.merge('database': db_name)

      ActiveRecord::Base.establish_connection(db_params)
      ActiveRecord::Base.connection
    end

    desc "Import budgets from database into ElasticSearch. Example bin/rails gobierto_budgets:budgets:import['budgets-dbname','budgets-execution','economic',2015] place_id=28079 province_id=3 autonomous_region_id=5"
    task :import, [:db_name, :index, :type, :year, :destination_year, :place_type] => :environment do |t, args|
      db_name = args[:db_name]
      index = args[:index] if GobiertoBudgetsData::GobiertoBudgets::ALL_INDEXES.include?(args[:index])
      raise "Invalid index #{args[:index]}" if index.blank?
      type = args[:type] if GobiertoBudgetsData::GobiertoBudgets::ALL_TYPES.include?(args[:type])
      raise "Invalid type #{args[:type]}" if type.blank?
      if m = args[:year].match(/\A\d{4}\z/)
        year = m[0].to_i
      end
      raise "Invalid year #{args[:year]}" if year.blank?

      if args[:destination_year].present? && m = args[:destination_year].match(/\A\d{4}\z/)
        destination_year = m[0].to_i
      else
        destination_year = year
      end

      places = GobiertoBudgetsData::GobiertoBudgets::PlaceDecorator.collection(args[:place_type].presence || :ine, ENV)

      GobiertoBudgetsData::GobiertoBudgets::PlacesBudgetsImporter.new(
        db: create_db_connection(db_name),
        client: GobiertoBudgets::SearchEngine.client,
        index:,
        year:,
        destination_year:,
        places:
      ).import(type)
    end
  end
end
