require_relative "../gobierto_budgets_data"
require "date"

def check_response!(response)
  return if response.is_a?(Array)

  raise(StandardError, response["error"]) if response["error"]
end

namespace :gobierto_budgets_data do
  namespace :data do
    def create_data_mapping(index)
      m = GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client.indices.get_mapping index: index
      return unless m[index]["mappings"].blank?

      # Document identifier: <ine_code>/<year>/<type>
      #
      # Example: 28079/2015/population
      # Example: 28079/2015/debt
      GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.indices.put_mapping index: index, body: {
        properties: {
          ine_code:              { type: 'keyword' },
          organization_id:       { type: 'keyword' },
          province_id:           { type: 'integer' },
          autonomy_id:           { type: 'integer' },
          year:                  { type: 'integer' },
          value:                 { type: 'double' },
          type:                  { type: 'keyword' }
        }
      }
    end

    desc 'Reset ElasticSearch data index'
    task :reset => :environment do
      if GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client.indices.exists? index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA
        puts "- Deleting #{GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA} index"
        GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.indices.delete index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA
      end

      if GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client.indices.exists? index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA
        puts "- Deleting #{GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA} index"
        GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.indices.delete index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA
      end
    end

    desc 'Create mappings for data index'
    task :create => :environment do
      unless GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client.indices.exists? index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA
        puts "- Creating index #{GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA}"
        GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.indices.create index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA, body: {
          settings: { index: { max_result_window: 100_000 } }
        }
      end

      unless GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client.indices.exists? index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA
        puts "- Creating index #{GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA}"
        GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.indices.create index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA, body: {
          settings: { index: { max_result_window: 100_000 } }
        }
      end

      puts "- Creating #{GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA}"
      create_data_mapping(GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA)
    end

    desc "Import CSV with extra data"
    task :import_extra_data, [:csv_path] => [:environment] do |_t, args|
      csv_path = args[:csv_path]
      unless File.file?(csv_path)
        puts "[ERROR] No CSV file found: #{csv_path}"
        exit -1
      end

      # This file can be generated with the following SQL in datos.gobierto.es
      #
      #
      #
      # SELECT 2021 AS year,
      # d.place_id,
      # d.value AS Deuda,
      # SUM(p.total) AS Habitantes
      # FROM deuda_municipal d
      # INNER JOIN poblacion_edad_sexo p ON p.place_id = d.place_id AND p.sex = 'Total' AND p.year = 2021
      # GROUP BY d.place_id, d.value

      population_cache = []

      CSV.read(csv_path, headers: true).each do |row|
        year = row["year"].to_s
        population = row["habitantes"].to_i

        place_id = row["place_id"].to_i
        id = [place_id, year, GobiertoBudgetsData::GobiertoBudgets::DEBT_TYPE].join('/')
        place = INE::Places::Place.find(place_id)
        next if place.blank?

        province_id = place.province.id.to_i
        autonomous_region_id = place.province.autonomous_region.id.to_i

        if row.headers.include?("deuda")
          debt = row["deuda"].to_f.round(2)
          item = {
            "organization_id" => place_id,
            "ine_code" => place_id,
            "year" => year,
            "value" => debt,
            "province_id" => province_id,
            "autonomy_id" => autonomous_region_id,
            "type" => GobiertoBudgetsData::GobiertoBudgets::DEBT_TYPE,
          }

          debt_data = [
            {
              index: {
                _index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA,
                _id: id,
                data: item
              }
            }
          ]

          GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: debt_data)
          puts "[SUCCESS] Debt #{debt} for #{year} and place #{place.name}"
        end

        id = [place_id, year, GobiertoBudgetsData::GobiertoBudgets::POPULATION_TYPE].join('/')
        item = {
          "organization_id" => place_id,
          "ine_code" => place_id,
          "year" => year,
          "value" => population,
          "province_id" => province_id,
          "autonomy_id" => autonomous_region_id,
          "type" => GobiertoBudgetsData::GobiertoBudgets::POPULATION_TYPE,
        }

        population_data = [
          {
            index: {
              _index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA,
              _id: id,
              data: item
            }
          }
        ]
        population_cache += population_data
        GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: population_data)

        puts "[SUCCESS] Population #{population} for #{year} and place #{place.name}"
      end
      province_groups = population_cache.group_by { |data| [data[:index][:data]["year"], data[:index][:data]["province_id"]] }
      autonomy_groups = population_cache.group_by { |data| [data[:index][:data]["year"], data[:index][:data]["autonomy_id"]]}.uniq

      province_groups.each do |(year, province_id), province_data|
        province = INE::Places::Province.find(province_id)
        sum_value = province_data.sum { |data| data[:index][:data]["value"].to_i }

        place_id = "province-#{province_id}"
        id = [place_id, year, GobiertoBudgetsData::GobiertoBudgets::POPULATION_PROVINCE_TYPE].join('/')

        item = {
          "organization_id" => place_id,
          "ine_code" => nil,
          "year" => year,
          "value" => sum_value,
          "province_id" => province_id,
          "autonomy_id" => province_data.map { |data| data[:index][:data]["autonomy_id"] }.uniq.compact.first,
          "type" => GobiertoBudgetsData::GobiertoBudgets::POPULATION_PROVINCE_TYPE,
        }
        population_data = [
          {
            index: {
              _index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA,
              _id: id,
              data: item
            }
          }
        ]
        GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: population_data)

        puts "[SUCCESS] Population #{sum_value} for #{year} and province #{province.name}"
      end

      autonomy_groups.each do |(year, autonomy_id), autonomy_data|
        autonomous_region = INE::Places::AutonomousRegion.find(autonomy_id)
        sum_value = autonomy_data.sum { |data| data[:index][:data]["value"].to_i }

        place_id = "autonomy-#{autonomy_id}"
        id = [place_id, year, GobiertoBudgetsData::GobiertoBudgets::POPULATION_AUTONOMY_TYPE].join('/')

        item = {
          "organization_id" => place_id,
          "ine_code" => nil,
          "year" => year,
          "value" => sum_value,
          "province_id" => nil,
          "autonomy_id" => autonomy_id,
          "type" => GobiertoBudgetsData::GobiertoBudgets::POPULATION_AUTONOMY_TYPE,
        }
        population_data = [
          {
            index: {
              _index: GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA,
              _id: id,
              data: item
            }
          }
        ]
        GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: population_data)

        puts "[SUCCESS] Population #{sum_value} for #{year} and autonomous region #{autonomous_region.name}"
      end
    end
  end
end
