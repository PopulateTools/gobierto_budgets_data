# frozen_string_literal: true

module GobiertoData
  module GobiertoBudgets
    class InvoicesImporter
      def initialize(options)
        @index = GobiertoData::GobiertoBudgets::ES_INDEX_INVOICES
        @type = GobiertoData::GobiertoBudgets::INVOICE_TYPE
        @data = options.fetch(:data)
      end

      attr_reader :index, :data, :type

      def import!
        invoices = []
        data.each do |attributes|
          date = Date.parse(attributes["date"])
          id = [attributes[:location_id], date.year, attributes[:invoice_id]].join('/')

          invoices.push({
            index: {
              _index: index,
              _id: id,
              _type: type,
              data: attributes,
            }
          })
        end

        GobiertoData::GobiertoBudgets::SearchEngine.client.bulk(body: invoices)

        return invoices.length
      end
    end
  end
end
