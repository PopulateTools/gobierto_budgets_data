# frozen_string_literal: true

module GobiertoData
  module GobiertoBudgets
    class BudgetLinesImporter
      def initialize(options)
        @index = options.fetch(:index)
        @year = options.fetch(:year)
        @data = options.fetch(:data)
      end

      attr_reader :index, :year, :data

      def import!
        budget_lines = []
        data.each do |budget_line|
          id = [budget_line["organization_id"], year, budget_line["code"], budget_line["kind"]].join("/")
          area_name = budget_line.delete("type")
          if area_name == "economic-custom"
            area_name = GobiertoData::GobiertoBudgets::ECONOMIC_AREA_NAME
            id = [budget_line["organization_id"], year, [budget_line["custom_code"], budget_line["code"], "c"].join("/"), budget_line["kind"]].join("/")
          elsif area_name == "economic-functional"
            area_name = GobiertoData::GobiertoBudgets::ECONOMIC_AREA_NAME
            id = [budget_line["organization_id"], year, [budget_line["functional_code"], budget_line["code"], "f"].join("/"), budget_line["kind"]].join("/")
          end

          budget_lines.push({
            index: {
              _index: index,
              _id: id,
              _type: area_name,
              data: budget_line
            }
          })
        end

        response = GobiertoData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: budget_lines)

        return budget_lines.length
      end
    end
  end
end
