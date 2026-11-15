# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    # Loads into Elasticsearch the budgets of a collection of places from a
    # Ministerio de Hacienda database (tables tb_inventario_<year>,
    # tb_economica_<year> and tb_funcional_<year>). Each query reads the rows
    # of PLACES_PER_QUERY places, matched to them by codente.
    class PlacesBudgetsImporter
      PLACES_PER_QUERY = 1_000
      POPULATION_IDS_PER_REQUEST = 3_000

      def initialize(db:, client:, index:, year:, destination_year:, places:, population_index: ES_INDEX_DATA)
        @db = db
        @client = client
        @index = index
        @year = year
        @destination_year = destination_year
        @places = places
        @population_index = population_index
      end

      def import(type)
        BulkIndexer.open(client: @client, index: @index) do |indexer|
          case type
          when ECONOMIC_BUDGET_TYPE then import_economic(indexer)
          when FUNCTIONAL_BUDGET_TYPE then import_functional(indexer)
          else raise ArgumentError, "Budgets of type #{type} can't be imported from the database"
          end
        end
      end

      private

      def import_economic(indexer)
        each_rows_slice(economic_sql) do |row, attributes, population|
          code, level, parent_code = code_with_level(row["code"])
          data = attributes.merge(
            type: ECONOMIC_BUDGET_TYPE,
            amount: row["amount"].to_f.round(2), code:,
            level:, kind: row["kind"],
            amount_per_inhabitant: amount_per_inhabitant(row["amount"], population),
            parent_code:
          )

          indexer.add([attributes[:organization_id], @destination_year, code, row["kind"], ECONOMIC_BUDGET_TYPE].join("/"), data)
        end
      end

      def import_functional(indexer)
        each_rows_slice(functional_sql) do |row, attributes, population|
          code, level, parent_code = code_with_level(row["code"])
          data = attributes.merge(
            amount: row["amount"].to_f.round(2), code:,
            level:, kind: EXPENSE,
            amount_per_inhabitant: amount_per_inhabitant(row["amount"], population),
            parent_code:,
            type: FUNCTIONAL_BUDGET_TYPE
          )

          indexer.add([attributes[:organization_id], @destination_year, code, EXPENSE, FUNCTIONAL_BUDGET_TYPE].join("/"), data)
        end

        each_rows_slice(economic_functional_sql) do |row, attributes, population|
          functional_code = row["functional_code"].tr(".", "-")
          data = attributes.merge(
            amount: row["amount"].to_f.round(2), code: row["code"],
            functional_code:, kind: EXPENSE,
            amount_per_inhabitant: amount_per_inhabitant(row["amount"], population),
            type: ECONOMIC_BUDGET_TYPE
          )

          indexer.add([attributes[:organization_id], @destination_year, "#{row["code"]}-#{functional_code}", EXPENSE, ECONOMIC_BUDGET_TYPE].join("/"), data)
        end
      end

      def economic_sql
        <<~SQL
          SELECT tb_inventario_#{@year}.codente, tb_economica_#{@year}.cdcta AS code, tb_economica_#{@year}.tipreig AS kind, #{economic_amount_expression} AS amount
          FROM tb_economica_#{@year}
          INNER JOIN tb_inventario_#{@year} ON tb_inventario_#{@year}.idente = tb_economica_#{@year}.idente
          WHERE tb_inventario_#{@year}.codente IN (%{codes})
        SQL
      end

      def functional_sql
        <<~SQL
          SELECT tb_inventario_#{@year}.codente, tb_funcional_#{@year}.cdfgr AS code, SUM(tb_funcional_#{@year}.importe) AS amount
          FROM tb_funcional_#{@year}
          INNER JOIN tb_inventario_#{@year} ON tb_inventario_#{@year}.idente = tb_funcional_#{@year}.idente
          WHERE tb_inventario_#{@year}.codente IN (%{codes})
          GROUP BY tb_inventario_#{@year}.codente, tb_funcional_#{@year}.cdfgr
        SQL
      end

      def economic_functional_sql
        <<~SQL
          SELECT tb_inventario_#{@year}.codente, tb_funcional_#{@year}.cdcta AS code, tb_funcional_#{@year}.cdfgr AS functional_code, tb_funcional_#{@year}.importe AS amount
          FROM tb_funcional_#{@year}
          INNER JOIN tb_inventario_#{@year} ON tb_inventario_#{@year}.idente = tb_funcional_#{@year}.idente
          WHERE tb_inventario_#{@year}.codente IN (%{codes})
        SQL
      end

      # Older years store the amount in importer (recognized) and imported (forecast)
      def economic_amount_expression
        if column?("tb_economica_#{@year}", "importe")
          "tb_economica_#{@year}.importe"
        else
          "COALESCE(NULLIF(tb_economica_#{@year}.importer, 0), tb_economica_#{@year}.imported)"
        end
      end

      def column?(table_name, column_name)
        @db.select_value(<<~SQL)
          SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = #{@db.quote(table_name)} AND column_name = #{@db.quote(column_name)})
        SQL
      end

      def each_rows_slice(sql)
        places_by_code.each_slice(PLACES_PER_QUERY) do |slice|
          places = slice.to_h
          codes = places.keys.map { |code| @db.quote(code) }.join(", ")

          @db.execute(format(sql, codes:)).each do |row|
            yield row, *places.fetch(row["codente"])
          end
        end
      end

      # Places with their document attributes and population, by codente.
      # Places that need a population and don't have one are skipped.
      def places_by_code
        @places_by_code ||= @places.each_with_object({}) do |place, places|
          population = populations[place]

          if place.population? && population.nil?
            puts "- Skipping #{place.population_organization_id} #{place.name} because population data is missing for #{@destination_year} and #{@destination_year - 1}"
            next
          end

          places[place.code] = [place_attributes(place, population), population]
        end
      end

      def place_attributes(place, population)
        {
          ine_code: place.attributes["place_id"],
          province_id: place.attributes["province_id"],
          autonomy_id: place.attributes["autonomous_region_id"],
          organization_id: place.id.to_s,
          year: @destination_year,
          population:
        }
      end

      # Population of each place in the destination year or, when missing, in
      # one of the two previous years.
      def populations
        @populations ||= begin
          places = @places.select(&:population?)
          values = population_values(places.flat_map { |place| population_years.map { |year| population_id(place, year) } })

          places.to_h do |place|
            [place, population_years.lazy.map { |year| values[population_id(place, year)] }.find(&:itself)]
          end
        end
      end

      def population_values(ids)
        ids.each_slice(POPULATION_IDS_PER_REQUEST).each_with_object({}) do |slice, values|
          @client.mget(index: @population_index, body: { ids: slice })["docs"].each do |document|
            values[document["_id"]] = document["_source"]["value"] if document["found"]
          end
        end
      end

      def population_years
        [@destination_year, @destination_year - 1, @destination_year - 2]
      end

      def population_id(place, year)
        [place.population_organization_id, year, place.population_type].join("/")
      end

      def amount_per_inhabitant(amount, population)
        population.presence && (amount.to_f / population).round(2)
      end

      # Codes with a dot are a fourth level subdivision: 222.01 is 222-01, child of 222
      def code_with_level(code)
        return [code.tr(".", "-"), 4, code.split(".").first] if code.include?(".")

        [code, code.length, code[0..-2]]
      end
    end
  end
end
