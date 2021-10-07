# frozen_string_literal: true

require "digest"

module GobiertoBudgetsData
  module GobiertoBudgets
    class InvoiceCsvRow
      DNI_REGEX = /\A\d{8}[A-Z]/i
      NIE_REGEX = /\A[A-Z]\d{7}[A-Z]/i

      attr_reader :row, :errors

      def initialize(row, opts = {})
        @row = row
        @organization_id = opts[:organization_id]
        @errors = {}
      end

      def invoice_id
        @invoice_id ||= row.field("invoice_id").to_s.strip
      end

      def value
        @value ||= row.field("value").to_f
      end

      def subject
        @subject ||= row.field("subject").to_s.strip
      end

      def date
        @date ||= Date.parse(row.field("date"))
      rescue Date::Error
        @errors.merge!(date: "Invalid date #{row.field("date")}")
      end

      def date_string(date)
        return unless date.present?

        date.strftime("%Y-%m-%d")
      end

      def raw_provider_id
        @raw_provider_id ||= row.field("provider_id").to_s.strip
      end

      def individual_provider?
        DNI_REGEX.match?(raw_provider_id) || NIE_REGEX.match?(raw_provider_id)
      end

      def provider_id
        @provider_id ||= if individual_provider?
                           Digest::SHA256.hexdigest(raw_provider_id)
                         else
                           raw_provider_id
                         end
      end

      def provider_name
        @provider_name ||= row.field("provider_name").to_s.strip
      end

      def payment_date
        return unless row.field("payment_date").present?

        Date.parse(row.field("payment_date"))
      rescue Date::Error
        @errors.merge!(payment_date: "Invalid date #{row.field("payment_date")}")
      end

      def paid
        /true/i.match?(row.field("paid"))
      end

      def freelance
        if row.field("freelance").present?
          /true/i.match?(row.field("freelance"))
        else
          individual_provider?
        end
      end

      def economic_budget_line_code
        row.field("economic_budget_line_code").to_s.strip
      end

      def functional_budget_line_code
        row.field("functional_budget_line_code").to_s.strip
      end

      def place
        @place ||= INE::Places::Place.find(organization_id)
      end

      def organization_id
        @organization_id ||= row.field("organization_id")
      end

      def location_attributes
        {
          location_id: place&.id,
          province_id: place&.province.id,
          autonomous_region_id: place&.province.autonomous_region.id
        }
      end

      def id
        [organization_id, date.year, Digest::MD5.hexdigest(invoice_id)].join('/')
      end

      def attributes
        {
          value: value,
          date: date_string(date),
          invoice_id: invoice_id,
          provider_id: provider_id,
          provider_name: provider_name,
          subject: subject,
          freelance: freelance,
          payment_date: date_string(payment_date),
          paid: paid,
          economic_budget_line_code: economic_budget_line_code,
          functional_budget_line_code: functional_budget_line_code
        }
      end

      def data
        {
          index: {
            _index: ES_INDEX_INVOICES,
            _id: id,
            _type: INVOICE_TYPE,
            data: attributes
          }
        }
      end

      def valid?
        [:invoice_id, :value, :subject, :date, :provider_id, :provider_name].each do |attr|
          @errors.merge!(attr => "Can't be blank") if attr.blank?
        end
        payment_date

        if organization_id.blank?
          @errors.merge!(
            organization_id: "Can't be blank. Must be provided either with an organization_id column or as an option initializing the class"
          )
        end

        @errors.blank?
      end
    end
  end
end
