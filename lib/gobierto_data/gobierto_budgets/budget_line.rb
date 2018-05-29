# frozen_string_literal: true

module GobiertoData
  module GobiertoBudgets
    class BudgetLine
      def self.all(options)
        organization_id = options.fetch(:organization_id)
        area_name       = options.fetch(:area_name)
        kind            = options.fetch(:kind)
        level           = options.fetch(:level)

        terms = [
          {term:    { kind: kind }},
          {term:    { organization_id: organization_id }},
          {term:    { level: level }},
          {missing: { field: "functional_code"}},
          {missing: { field: "custom_code"}}
        ]

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

        response = SearchEngine.client.search(index: GobiertoData::GobiertoBudgets::ES_INDEX_FORECAST, type: area_name, body: query)

        response["hits"]["hits"].map{ |h| h["_source"] }.map do |row|
          BudgetLinePresenter.new(row.merge(
            kind: kind,
            area_name: area_name,
            total: response["aggregations"]["total_budget"]["value"],
            total_budget_per_inhabitant: response["aggregations"]["total_budget_per_inhabitant"]["value"]
          ))
        end
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        return []
      end
    end
  end
end
