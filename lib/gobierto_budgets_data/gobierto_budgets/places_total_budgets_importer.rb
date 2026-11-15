# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    # Indexes the total budget of each place: the sum of its first level budget
    # lines, functional ones for expenses (economic when there are none) and
    # economic ones for income.
    class PlacesTotalBudgetsImporter
      ORGANIZATIONS_PER_REQUEST = 10_000

      def initialize(client:, index:, year:, places:)
        @client = client
        @index = index
        @year = year
        @places = places
      end

      def import
        BulkIndexer.open(client: @client, index: @index) do |indexer|
          ALL_KINDS.each { |kind| import_kind(indexer, kind) }
        end
      end

      private

      def import_kind(indexer, kind)
        totals = sums(kind, kind == EXPENSE ? FUNCTIONAL_BUDGET_TYPE : ECONOMIC_BUDGET_TYPE)
        economic_totals = sums(kind, ECONOMIC_BUDGET_TYPE) if kind == EXPENSE

        @places.each do |place|
          amount, amount_per_inhabitant = totals.fetch(place.id.to_s, [0.0, 0.0])
          if amount == 0.0 && kind == EXPENSE
            amount, amount_per_inhabitant = economic_totals.fetch(place.id.to_s, [0.0, 0.0])
          end

          data = {
            ine_code: place.attributes["place_id"],
            province_id: place.attributes["province_id"],
            autonomy_id: place.attributes["autonomous_region_id"],
            organization_id: place.id.to_s,
            year: @year,
            kind:,
            amount:,
            amount_per_inhabitant:,
            type: TOTAL_BUDGET_TYPE
          }

          indexer.add([place.id, @year, kind, TOTAL_BUDGET_TYPE].join("/"), data)
        end
      end

      # [amount, amount per inhabitant] of the first level budget lines of each organization
      def sums(kind, type)
        totals = {}
        after = nil

        loop do
          aggregation = @client.search(index: @index, body: sums_query(kind, type, after))["aggregations"]["organizations"]
          aggregation["buckets"].each do |bucket|
            totals[bucket["key"]["organization_id"]] = [bucket["amount"]["value"].round(2), bucket["amount_per_inhabitant"]["value"].round(2)]
          end
          after = aggregation["after_key"]
          break if after.nil? || aggregation["buckets"].empty?
        end

        totals
      end

      def sums_query(kind, type, after)
        {
          size: 0,
          query: {
            bool: {
              filter: [
                { term: { type: } },
                { term: { level: 1 } },
                { term: { kind: } },
                { term: { year: @year } },
                { terms: { organization_id: @places.map { |place| place.id.to_s } } }
              ],
              must_not: [
                { exists: { field: "functional_code" } },
                { exists: { field: "custom_code" } }
              ]
            }
          },
          aggs: {
            organizations: {
              composite: {
                size: ORGANIZATIONS_PER_REQUEST,
                sources: [{ organization_id: { terms: { field: "organization_id" } } }],
                after:
              }.compact,
              aggs: {
                amount: { sum: { field: "amount" } },
                amount_per_inhabitant: { sum: { field: "amount_per_inhabitant" } }
              }
            }
          }
        }
      end
    end
  end
end
