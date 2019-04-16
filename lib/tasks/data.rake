require_relative "../gobierto_data"
require "date"

def check_response!(response)
  return if response.is_a?(Array)

  raise(StandardError, response["error"]) if response["error"]
end

namespace :gobierto_data do
  namespace :data do
    def create_debt_mapping(index, type)
      m = GobiertoData::GobiertoBudgets::SearchEngine.client.indices.get_mapping index: index, type: type
      return unless m.empty?

      # Document identifier: <ine_code>/<year>
      #
      # Example: 28079/2015
      # Example: 28079/2015
      GobiertoData::GobiertoBudgets::SearchEngineWriting.client.indices.put_mapping index: index, type: type, body: {
        type.to_sym => {
          properties: {
            ine_code:              { type: 'integer', index: 'not_analyzed' },
            organization_id:       { type: 'string',  index: 'not_analyzed' },
            province_id:           { type: 'integer', index: 'not_analyzed' },
            autonomy_id:           { type: 'integer', index: 'not_analyzed' },
            year:                  { type: 'integer', index: 'not_analyzed' },
            value:                 { type: 'double', index: 'not_analyzed'  }
          }
        }
      }
    end

    def create_population_mapping(index, type)
      m = GobiertoData::GobiertoBudgets::SearchEngine.client.indices.get_mapping index: index, type: type
      return unless m.empty?

      # Document identifier: <ine_code>/<year>
      #
      # Example: 28079/2015
      # Example: 28079/2015
      GobiertoData::GobiertoBudgets::SearchEngineWriting.client.indices.put_mapping index: index, type: type, body: {
        type.to_sym => {
          properties: {
            ine_code:              { type: 'integer', index: 'not_analyzed' },
            organization_id:       { type: 'string',  index: 'not_analyzed' },
            province_id:           { type: 'integer', index: 'not_analyzed' },
            autonomy_id:           { type: 'integer', index: 'not_analyzed' },
            year:                  { type: 'integer', index: 'not_analyzed' },
            value:                 { type: 'double', index: 'not_analyzed'  }
          }
        }
      }
    end

    desc 'Reset ElasticSearch data index'
    task :reset => :environment do
      if GobiertoData::GobiertoBudgets::SearchEngine.client.indices.exists? index: GobiertoData::GobiertoBudgets::ES_INDEX_DATA
        puts "- Deleting #{ES_INDEX_DATA} index"
        GobiertoData::GobiertoBudgets::SearchEngineWriting.client.indices.delete index: GobiertoData::GobiertoBudgets::ES_INDEX_DATA
      end
    end

    desc 'Create mappings for data index'
    task :create => :environment do
      unless GobiertoData::GobiertoBudgets::SearchEngine.client.indices.exists? index: GobiertoData::GobiertoBudgets::ES_INDEX_DATA
        puts "- Creating index #{ES_INDEX_DATA}"
        GobiertoData::GobiertoBudgets::SearchEngineWriting.client.indices.create index: GobiertoData::GobiertoBudgets::ES_INDEX_DATA, body: {
          settings: { index: { max_result_window: 100_000 } }
        }
      end

      puts "- Creating #{GobiertoData::GobiertoBudgets::ES_INDEX_DATA} > #{GobiertoData::GobiertoBudgets::DEBT_TYPE}"
      create_debt_mapping(GobiertoData::GobiertoBudgets::ES_INDEX_DATA, GobiertoData::GobiertoBudgets::DEBT_TYPE)

      puts "- Creating #{GobiertoData::GobiertoBudgets::ES_INDEX_DATA} > #{GobiertoData::GobiertoBudgets::POPULATION_TYPE}"
      create_population_mapping(GobiertoData::GobiertoBudgets::ES_INDEX_DATA, GobiertoData::GobiertoBudgets::POPULATION_TYPE)
    end

    desc "Load debt data from Populate Data"
    task :load_debt do
      api_endpoint = ENV.fetch("POPULATE_DATA_URL")
      api_token = ENV.fetch("POPULATE_DATA_TOKEN")
      origin = ENV.fetch("POPULATE_DATA_ORIGIN")

      (2010..(Date.today.year - 1)).each do |year|
        request_uri = api_endpoint + "/datasets/ds-deuda-municipal.json?filter_by_year=#{year}"

        client = PopulateData::Client.new(request_uri: request_uri, origin: origin, api_token: api_token)
        response = client.fetch

        check_response!(response)

        data = response.map do |item|
          id = item.delete("_id").split('-')[0]
          item["organization_id"] = item.delete("location_id").to_s
          item["ine_code"] = item["organization_id"].to_i
          item["year"] = item.delete("date").to_i
          {
            index: {
              _index: GobiertoData::GobiertoBudgets::ES_INDEX_DATA,
              _type: GobiertoData::GobiertoBudgets::DEBT_TYPE,
              _id: id,
              data: item
            }
          }
        end

        if data.any?
          GobiertoData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: data)
        end
      end
    end

    desc "Load population data from Populate Data"
    task :load_population do
      api_endpoint = ENV.fetch("POPULATE_DATA_URL")
      api_token = ENV.fetch("POPULATE_DATA_TOKEN")
      origin = ENV.fetch("POPULATE_DATA_ORIGIN")

      (2010..(Date.today.year - 1)).each do |year|
        request_uri = api_endpoint + "/datasets/ds-poblacion-municipal.json?filter_by_year=#{year}"

        client = PopulateData::Client.new(request_uri: request_uri, origin: origin, api_token: api_token)
        response = client.fetch

        check_response!(response)

        data = response.map do |item|
          id = item.delete("_id").split('-')[0]
          item["organization_id"] = item.delete("location_id").to_s
          item["ine_code"] = item["organization_id"].to_i
          item["year"] = item.delete("date").to_i
          {
            index: {
              _index: GobiertoData::GobiertoBudgets::ES_INDEX_DATA,
              _type: GobiertoData::GobiertoBudgets::POPULATION_TYPE,
              _id: id,
              data: item
            }
          }
        end

        if data.any?
          GobiertoData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: data)
        end
      end
    end
  end
end
