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
        raw_rows = load_raw_rows
        if raw_rows.empty?
          raise "No rows imported from CSV. Review the file to check if cells are empty"
        end

        budget_lines = GobiertoBudgetsData::GobiertoBudgets::Utils::SicalwinBudgetLineProcessor.new(raw_rows).process

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
          if row.field("Org.").present? && row.field("Eco.").present?
            BudgetLineSicalwinRow.new(row, year: @year, organization_id: @organization_id)
          end
        end.compact
      end
    end
  end
end
