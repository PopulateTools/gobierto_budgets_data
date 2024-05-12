require_relative "../gobierto_budgets_data"
require "date"

def check_response!(response)
  return if response.is_a?(Array)

  raise(StandardError, response["error"]) if response["error"]
end

namespace :gobierto_budgets_data do
  namespace :data do
    def create_debt_mapping(index)
      m = GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client.indices.get_mapping index: index
      return unless m.empty?

      # Document identifier: <ine_code>/<year>
      #
      # Example: 28079/2015
      # Example: 28079/2015
      GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.indices.put_mapping index: index, body: {
        type.to_sym => {
          properties: {
            ine_code:              { type: 'integer' },
            organization_id:       { type: 'keyword' },
            province_id:           { type: 'integer' },
            autonomy_id:           { type: 'integer' },
            year:                  { type: 'integer' },
            value:                 { type: 'double' }
          }
        }
      }
    end

    def create_population_mapping(index)
      m = GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client.indices.get_mapping index: index
      return unless m.empty?

      # Document identifier: <ine_code>/<year>
      #
      # Example: 28079/2015
      # Example: 28079/2015
      GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.indices.put_mapping index: index, body: {
        type.to_sym => {
          properties: {
            ine_code:              { type: 'integer' },
            organization_id:       { type: 'keyword' },
            province_id:           { type: 'integer' },
            autonomy_id:           { type: 'integer' },
            year:                  { type: 'integer' },
            value:                 { type: 'double' }
          }
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
      create_debt_mapping(GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA)

      puts "- Creating #{GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA}"
      create_population_mapping(GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA)
    end
  end
end
