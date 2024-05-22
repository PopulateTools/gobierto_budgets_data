# frozen_string_literal: true

module GobiertoBudgetsData
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
          area_name = budget_line.delete("type")
          id = [budget_line["organization_id"], year, budget_line["code"], budget_line["kind"], area_name].join("/")
          if area_name == "economic-custom"
            area_name = GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME
            id = [budget_line["organization_id"], year, [budget_line["custom_code"], budget_line["code"], "c"].join("/"), budget_line["kind"], area_name].join("/")
          elsif area_name == "economic-functional"
            area_name = GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME
            id = [budget_line["organization_id"], year, [budget_line["functional_code"], budget_line["code"], "f"].join("/"), budget_line["kind"], area_name].join("/")
          end

          budget_lines.push({
            index: {
              _index: index,
              _id: id,
              data: budget_line.merge(type: area_name)
            }
          })
        end

        if budget_lines.present?
          GobiertoBudgetsData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: budget_lines)
        end

        budget_lines.length
      end
    end
  end
end
