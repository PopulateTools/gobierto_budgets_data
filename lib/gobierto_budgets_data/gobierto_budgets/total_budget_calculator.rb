# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class TotalBudgetCalculator
      attr_reader :organization_id, :year, :index, :place_attributes

      def initialize(params = {})
        @organization_id = params[:organization_id]
        @year = params[:year].to_i
        @index = params[:index]
      end

      def calculate!
        import_total_budget(year, index, GobiertoBudgetsData::GobiertoBudgets::EXPENSE)
        import_total_budget(year, index, GobiertoBudgetsData::GobiertoBudgets::INCOME)
      end

      def delete!
        delete_total_budget(year, index, GobiertoBudgetsData::GobiertoBudgets::EXPENSE)
        delete_total_budget(year, index, GobiertoBudgetsData::GobiertoBudgets::INCOME)
      end

      private

      def ine_code
        place&.id.try(:to_i)
      end

      def province_id
        place&.province&.id.try(:to_i)
      end

      def autonomy_id
        place&.province&.autonomous_region&.id.try(:to_i)
      end

      def place_attributes
        { ine_code: ine_code, province_id: province_id, autonomy_id: autonomy_id }
      end

      def place
        # prevent matches of "8187-gencat-123456", since "8187-gencat-123456".to_i => 8187, and incorrect place gets returned
        ::INE::Places::Place.find(organization_id) if organization_id =~ /^\d+$/
      end

      def import_total_budget(year, index, kind)
        puts "Importing total budget for organization_id: #{organization_id}, year: #{year}, index: #{index}, kind: #{kind}"

        total_budget, total_budget_per_inhabitant = get_data(index, organization_id, year, kind)

        if total_budget == 0.0 && kind == GobiertoBudgetsData::GobiertoBudgets::EXPENSE
          total_budget, total_budget_per_inhabitant = get_data(index, organization_id, year, kind, GobiertoBudgetsData::GobiertoBudgets::FUNCTIONAL_AREA_NAME)
        end

        data = place_attributes.merge(
          organization_id: organization_id,
          year: year,
          kind: kind,
          amount: total_budget.to_f,
          amount_per_inhabitant: total_budget_per_inhabitant.to_f
        )

        id = [organization_id, year, kind, GobiertoBudgetsData::GobiertoBudgets::TOTAL_BUDGET_TYPE ].join("/")

        GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.index(
          index: index,
          id: id,
          body: data
        )
      end

      def get_data(index, organization_id, year, kind, type = nil)
        query = {
          query: {
            bool: {
              must: [
                { term: { organization_id: organization_id } },
                { term: { level: 1 } },
                { term: { kind: kind } },
                { term: { year: year } },
                { term: { type: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME } }
              ],
              must_not: [
                { exists: { field: "functional_code" } },
                { exists: { field: "custom_code" } }
              ]
            }
          },
          aggs: {
            total_budget: { sum: { field: "amount" } },
            total_budget_per_inhabitant: { sum: { field: "amount_per_inhabitant" } }
          },
          size: 10_000
        }

        result = GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client.search(
          index: index,
          body: query
        )

        [
          result['hits']['hits'].sum{ |h| h['_source']['total_budget'].to_f.round(2) },
          result['hits']['hits'].sum{ |h| h['_source']['total_budget_per_inhabitant'].to_f.round(2) }
        ]
      end

      def delete_total_budget(year, index, kind)
        puts "Deleting total budget for organization_id: #{organization_id}, year: #{year}, index: #{index}, kind: #{kind}"

        body = {
          query: {
            match: {
              organization_id: organization_id,
              type: GobiertoBudgetsData::GobiertoBudgets::TOTAL_BUDGET_TYPE
            }
          },
          size: 100_000
        }

        puts "Searching for first bulk..."

        response = GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client.search(index: index, body: body)

        bulk_operations = response["hits"]["hits"].map do |hit|
          { delete: { _index: index, _id: hit["_id"] } }
        end

        while bulk_operations.any? do
          GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: bulk_operations, refresh: true)

          response = GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client.search(index: index, body: body)

          bulk_operations = response["hits"]["hits"].map do |hit|
            { delete: { _index: index, _id: hit["_id"] } }
          end
        end

        puts "Deletion finished"
      end
    end
  end
end
