# frozen_string_literal: true

namespace :gobierto_budgets do
  namespace :elastic_search_schemas do
    def indexes
      GobiertoBudgetsData::GobiertoBudgets::SearchEngineConfiguration::BudgetLine.all_indices +
        GobiertoBudgetsData::GobiertoBudgets::SearchEngineConfiguration::Invoice.all_indices
    end

    def create_invoices_mapping(index)
      m = GobiertoBudgets::SearchEngine.client.indices.get_mapping index: index
      return unless m.empty?

      puts "  - Creating #{index}"
      GobiertoBudgets::SearchEngine.client.indices.put_mapping index: index, body: {
        type.to_sym => {
          properties: {
            value:                       { "type": "float" },
            location_id:                 { "type": "keyword" },
            date:                        { "type": "date" },
            province_id:                 { "type": "integer" },
            autonomous_region_id:        { "type": "integer" },
            invoice_id:                  { "type": "keyword" },
            provider_id:                 { "type": "keyword" },
            provider_name:               { "type": "keyword" },
            payment_date:                { "type": "date" },
            paid:                        { "type": "boolean" },
            subject:                     { "type": "keyword" },
            freelance:                   { "type": "boolean" },
            economic_budget_line_code:   { "type": "keyword" },
            functional_budget_line_code: { "type": "keyword" }
          }
        }
      }
    end

    def create_budgets_mapping(index)
      m = GobiertoBudgets::SearchEngine.client.indices.get_mapping index: index
      return unless m.empty?

      puts "  - Creating #{index}"
      # BUDGETS_INDEX: budgets-forecast // budgets-execution
      # BUDGETS_TYPE: economic // functional // custom
      #
      # Document identifier: <ine_code>/<year>/<code>/<kind>
      #
      # Example: 28079/2015/210.00/0
      # Example: 28079/2015/210.00/1
      GobiertoBudgets::SearchEngine.client.indices.put_mapping index: index, body: {
        type.to_sym => {
          properties: {
            _type:                 { type: 'keyword' },
            ine_code:              { type: 'integer' },
            organization_id:       { type: 'keyword' },
            year:                  { type: 'integer' },
            amount:                { type: 'double' },
            code:                  { type: 'keyword' },
            parent_code:           { type: 'keyword' },
            functional_code:       { type: 'keyword' },
            custom_code:           { type: 'keyword' },
            level:                 { type: 'integer' },
            kind:                  { type: 'keyword' }, # income I / expense G
            province_id:           { type: 'integer' },
            autonomy_id:           { type: 'integer' },
            amount_per_inhabitant: { type: 'double'  }
          }
        }
      }
    end

    desc 'Reset ElasticSearch'
    task :reset => :environment do
      indexes.each do |index|
        if GobiertoBudgets::SearchEngine.client.indices.exists? index: index
          puts "- Deleting #{index}..."
          GobiertoBudgets::SearchEngine.client.indices.delete index: index
        end
      end
    end

    desc 'Create mappings'
    task :create => :environment do
      indexes.each do |index|
        unless GobiertoBudgets::SearchEngine.client.indices.exists? index: index
          puts "- Creating index #{index}"
          GobiertoBudgets::SearchEngine.client.indices.create index: index, body: {
            settings: {
              # Allow 100_000 results per query
              index: { max_result_window: 100_000 }
            }
          }
          if index == GobiertoBudgetsData::GobiertoBudgets::SearchEngineConfiguration::Invoice.index
            create_invoices_mapping(index)
          else
            create_budgets_mapping(index)
          end
        end
      end
    end
  end
end
