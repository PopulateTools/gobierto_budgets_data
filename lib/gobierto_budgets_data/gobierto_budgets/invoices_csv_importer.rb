# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class InvoicesCsvImporter
      attr_reader :csv, :output

      def initialize(csv, opts = {})
        @csv = csv
        @output = []
        @rows_opts = opts.slice(:organization_id)
      end

      def import!
        parse_data

        return 0 if output.blank?

        GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: output)

        output.length
      end

      def rows
        @rows ||= csv.map { |row| InvoiceCsvRow.new(row, **@rows_opts) }
      end

      private

      def parse_data
        rows.each do |row|
          unless row.valid?
            raise row.errors.map { |attribute, message| "#{attribute}: #{message}" }.join("\n")
          end

          @output.append(row.data)
        end
      end
    end
  end
end
