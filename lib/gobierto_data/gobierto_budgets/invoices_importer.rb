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
        nitems = 0
        data.each do |attributes|
          nitems += 1
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

          if nitems%300 == 0
            GobiertoData::GobiertoBudgets::SearchEngine.client.bulk(body: invoices)
            invoices = []
          end
        end

        return nitems
      end
    end
  end
end
