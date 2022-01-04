# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class BudgetLinesSicalwinImporter
      def initialize(csv, year, organization_id)
        @csv = csv
        @year = year
        @organization_id = organization_id
      end

      def import!
        budget_lines = GobiertoBudgetsData::GobiertoBudgets::Utils::SicalwinBudgetLineProcessor.new(load_raw_rows).process

        import_data = budget_lines.map(&:data)

        if import_data.any?
          GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: import_data)
        end

        # TODO: create a report
        return import_data.length
      end

      private

      def load_raw_rows
        @csv.map do |row|
          if row.to_h.values.all?(&:present?)
            BudgetLineSicalwinRow.new(row, year: @year, organization_id: @organization_id)
          end
        end.compact
      end
    end
  end
end
