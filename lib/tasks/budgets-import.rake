namespace :gobierto_budgets do
  namespace :budgets do
    def create_db_connection(db_name)
      ActiveRecord::Base.establish_connection ActiveRecord::Base.configurations[Rails.env].merge('database' => db_name)
      ActiveRecord::Base.connection
    end

    def population(id, year)
      response = GobiertoBudgets::SearchEngine.client.get index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA, id: "#{id}/#{year}/#{GobiertoBudgetsData::GobiertoBudgets::POPULATION_TYPE}"
      response['_source']['value']
    rescue
      nil
    end

    def check_column_presence(connection, table_name, column_name)
      query = "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='#{table_name}' AND column_name='#{column_name}')"
      connection.execute(query).to_a.map(&:values).flatten.all?
    end

    def import_functional_budgets(db_name, index, year, destination_year, opts = {})
      db = create_db_connection(db_name)

      places_key = opts.fetch(:place_type, :ine)
      places = PlaceDecorator.collection(places_key)

      places.each do |place|
        place.attributes.each do |key, value|
          next if ENV[key].present? && value != ENV[key].to_i
        end

        next if ENV["custom_place_id"].present? && place.custom_place_id != ENV["custom_place_id"]

        pop = if place.population?
                population(place.id, destination_year) || population(place.id, destination_year - 1) || population(place.id, destination_year - 2)
              else
                nil
              end

        if place.population? && pop.nil?
          puts "- Skipping #{place.id} #{place.name} because population data is missing for #{destination_year} and #{destination_year-1}"
          next
        end

        base_data = {
          ine_code: place.attributes["place_id"],
          province_id: place.attributes["province_id"],
          autonomy_id: place.attributes["autonomous_region_id"],
          organization_id: place.id.to_s,
          year: destination_year,
          population: pop
        }

        sql = <<-SQL
SELECT tb_funcional_#{year}.cdfgr as code, sum(tb_funcional_#{year}.importe) as amount
FROM tb_funcional_#{year}
INNER JOIN "tb_inventario_#{year}" ON tb_inventario_#{year}.idente = tb_funcional_#{year}.idente AND tb_inventario_#{year}.codente = '#{place.code}'
GROUP BY tb_funcional_#{year}.cdfgr
SQL

        index_request_body = []
        db.execute(sql).each do |row|
          code = row['code']
          level = row['code'].length
          parent_code = row['code'][0..-2]
          if code.include?('.')
            code = code.tr('.','-')
            level = 4
            parent_code = code.split('-').first
          end
          data = base_data.merge({
            amount: row['amount'].to_f.round(2), code: code,
            level: level, kind: 'G',
            amount_per_inhabitant: pop.presence && (row['amount'].to_f / pop).round(2),
            parent_code: parent_code,
            type: GobiertoBudgetsData::GobiertoBudgets::FUNCTIONAL_BUDGET_TYPE
          })

          id = [place.id,destination_year,code,'G'].join("/")
          index_request_body << {index: {_id: id, data: data}}
        end
        next if index_request_body.empty?

        GobiertoBudgets::SearchEngine.client.bulk index: index, body: index_request_body

        # Import economic sublevels
        sql = <<-SQL
SELECT tb_funcional_#{year}.cdcta as code, tb_funcional_#{year}.cdfgr as functional_code, tb_funcional_#{year}.importe as amount
FROM tb_funcional_#{year}
INNER JOIN "tb_inventario_#{year}" ON tb_inventario_#{year}.idente = tb_funcional_#{year}.idente AND tb_inventario_#{year}.codente = '#{place.code}'
SQL

        index_request_body = []
        db.execute(sql).each do |row|
          code = row['code']
          functional_code = row['functional_code']
          if functional_code.include?('.')
            functional_code = functional_code.tr('.','-')
          end
          data = base_data.merge({
            amount: row['amount'].to_f.round(2), code: code,
            functional_code: functional_code, kind: 'G',
            amount_per_inhabitant:  pop.presence && (row['amount'].to_f / pop).round(2),
            type: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_BUDGET_TYPE
          })

          id = [place.id,destination_year,"#{code}-#{functional_code}",'G'].join("/")
          index_request_body << {index: {_id: id, data: data}}
        end
        next if index_request_body.empty?

        GobiertoBudgets::SearchEngine.client.bulk index: index, body: index_request_body
      end
    end

    def import_economic_budgets(db_name, index, year, destination_year, opts = {})
      db = create_db_connection(db_name)

      places_key = opts.fetch(:place_type, :ine)
      places = PlaceDecorator.collection(places_key)

      places.each do |place|
        place.attributes.each do |key, value|
          next if ENV[key].present? && value != ENV[key].to_i
        end

        next if ENV["custom_place_id"].present? && place.custom_place_id != ENV["custom_place_id"]

        pop = if place.population?
                population(place.id, destination_year) || population(place.id, destination_year - 1) || population(place.id, destination_year - 2)
              else
                nil
              end

        if place.population? && pop.nil?
          puts "- Skipping #{place.id} #{place.name} because population data is missing for #{destination_year} and #{destination_year-1}"
          next
        end

        base_data = {
          ine_code: place.attributes["place_id"],
          province_id: place.attributes["province_id"],
          autonomy_id: place.attributes["autonomous_region_id"],
          organization_id: place.id.to_s,
          year: destination_year,
          population: pop,
          type: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_BUDGET_TYPE
        }

        amount_expression = if check_column_presence(db, "tb_economica_#{year}", "importe")
                              "tb_economica_#{year}.importe"
                            else
                              "COALESCE(NULLIF(tb_economica_#{year}.importer, 0), tb_economica_#{year}.imported)"
                            end

        sql = <<-SQL
SELECT tb_economica_#{year}.cdcta as code, tb_economica_#{year}.tipreig AS kind, #{amount_expression} as amount
FROM tb_economica_#{year}
INNER JOIN "tb_inventario_#{year}" ON tb_inventario_#{year}.idente = tb_economica_#{year}.idente AND tb_inventario_#{year}.codente = '#{place.code}'
SQL

        index_request_body = []
        db.execute(sql).each do |row|
          code = row['code']
          level = row['code'].length
          parent_code = row['code'][0..-2]
          if code.include?('.')
            code = code.tr('.','-')
            level = 4
            parent_code = code.split('-').first
          end

          data = base_data.merge({
            amount: row['amount'].to_f.round(2), code: code,
            level: level, kind: row['kind'],
            amount_per_inhabitant:  pop.presence && (row['amount'].to_f / pop).round(2),
            parent_code: parent_code
          })

          id = [place.id,destination_year,code,row['kind']].join("/")
          index_request_body << {index: {_id: id, data: data}}
        end
        next if index_request_body.empty?

        GobiertoBudgets::SearchEngine.client.bulk index: index, body: index_request_body
      end
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

      opts = args.to_h.slice(:place_type)

      self.send("import_#{type}_budgets", db_name, index, year, destination_year, **opts)
    end
  end
end
