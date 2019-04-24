# frozen_string_literal: true

module GobiertoData
  module GobiertoBudgets
    class BudgetLine

      def self.all(options)
        area_name = options[:area_name]
        updated_forecast = options.delete(:updated_forecast) || false

        terms = [
          { missing: { field: "functional_code"} },
          { missing: { field: "custom_code"} }
        ]

        permitted_terms.each do |term_key|
          terms << build_term(term_key, options[term_key]) if options[term_key]
        end

        query = {
          query: {
            filtered: {
              filter: {
                bool: {
                  must: terms
                }
              }
            }
          },
          aggs: {
            total_budget: { sum: { field: "amount" } },
            total_budget_per_inhabitant: { sum: { field: "amount_per_inhabitant" } },
          },
          size: 10_000
        }

        index = if updated_forecast
                  GobiertoData::GobiertoBudgets::ES_INDEX_FORECAST_UPDATED
                else
                  default_index
                end

        response = SearchEngine.client.search(index: index, type: area_name, body: query)

        if updated_forecast && response["hits"]["hits"].empty?
          response = SearchEngine.client.search(index: default_index, type: area_name, body: query)
        end

        response["hits"]["hits"].map{ |h| h["_source"] }.map do |row|
          BudgetLinePresenter.new(row.merge(
            area_name: area_name,
            total: response["aggregations"]["total_budget"]["value"],
            total_budget_per_inhabitant: response["aggregations"]["total_budget_per_inhabitant"]["value"]
          ))
        end
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        []
      end

      def self.build_term(term_key, term_value)
        { term: { term_key => term_value } }
      end

      def self.permitted_terms
        %i[kind organization_id level]
      end

      def self.default_index
        GobiertoData::GobiertoBudgets::ES_INDEX_FORECAST
      end

    end
  end
end
