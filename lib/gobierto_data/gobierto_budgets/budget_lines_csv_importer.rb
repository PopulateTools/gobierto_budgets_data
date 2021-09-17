# frozen_string_literal: true

module GobiertoData
  module GobiertoBudgets
    class BudgetLinesCsvImporter
      attr_accessor :csv, :output

      def initialize(csv)
        @csv = csv
        @output = []
      end

      def import!
        parse_data
        return 0 if output.blank?

        GobiertoData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: output)

        return output.length
      end

      private

      def parse_data
        csv.each do |row|
          @output.concat(BudgetLineCsvRow.new(row).data)
        end
      end
    end
  end
end
