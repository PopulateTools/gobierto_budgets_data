# frozen_string_literal: true

require "digest"

module GobiertoData
  module GobiertoBudgets
    class InvoicesImporter
      def initialize(options)
        @index = GobiertoData::GobiertoBudgets::ES_INDEX_INVOICES
        @type = GobiertoData::GobiertoBudgets::INVOICE_TYPE
        @data = options.fetch(:data)
      end

      attr_reader :index, :data, :type

      DNI_REGEX = /^(\d{8})([A-Z])$/i.freeze
      NIE_REGEX = /^[XYZ]\d{7,8}[A-Z]$/i.freeze

      def import!
        invoices = []
        nitems = 0
        data.each do |attributes|
          nitems += 1
          date = Date.parse(attributes["date"])
          id = [attributes["location_id"], date.year, Digest::MD5.hexdigest(attributes["invoice_id"])].join('/')

          original_provider_id = attributes["provider_id"]

          if original_provider_id.match?(DNI_REGEX) || original_provider_id.match?(NIE_REGEX)
            attributes["provider_id"] = Digest::SHA256.hexdigest(original_provider_id)
          end

          invoices.push(
            index: {
              _index: index,
              _id: id,
              _type: type,
              data: attributes,
            }
          )

          if (nitems % 300).zero?
            GobiertoData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: invoices)
            invoices = []
          end
        end
        GobiertoData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: invoices)

        nitems
      end
    end
  end
end
