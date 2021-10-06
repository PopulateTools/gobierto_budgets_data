# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class InvoiceCsvRow
      DNI_REGEX = /\A\d{8}[A-Z]/i
      NIE_REGEX = /\A[A-Z]\d{7}[A-Z]/i

      attr_reader :row, :errors

      def initialize(row)
        @row = row
        @errors = {}
      end

      def invoice_id
        row.field("invoice_id").to_s.strip
      end

      def provider_id
        @provider_id ||= row.field("provider_id").to_s.strip
      end

      def provider_name
        row.field("provider_name").to_s.strip
      end

      def value
        row.field("value").tr(".", "").tr(",", ".").to_f
      end

      def subject
        row.field("subject").to_s.strip
      end

      def freelance
        if row.field("freelance").present?
          /true/i.match?(row.field("freelance"))
        else
          DNI_REGEX.match?(provider_id) || NIE_REGEX.match?(provider_id)
        end
      end

      def date
        Date.strptime(row.field("date"), "%d/%m/%Y").strftime("%Y-%m-%d")
      end

      def payment_date
        Date.strptime(row.field("payment_date"), "%d/%m/%Y").strftime("%Y-%m-%d")
      end

      def paid
        /true/i.match?(row.field("paid"))
      end

      def economic_budget_line_code
        row.field("economic_budget_line_code").to_s.strip
      end

      def functional_budget_line_code
        row.field("functional_budget_line_code").to_s.strip
      end

      def data
        {
          value: value,
          date: date,
          invoice_id: invoice_id,
          provider_id: provider_id,
          provider_name: provider_name,
          subject: subject,
          freelance: freelance,
          payment_date: payment_date,
          paid: paid,
          economic_budget_line_code: economic_budget_line_code,
          functional_budget_line_code: functional_budget_line_code
        }
      end

      def valid?
        true
      end
    end
  end
end
