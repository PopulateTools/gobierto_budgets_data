# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    module Utils
      class SicalwinBudgetLineProcessor
        def initialize(raw_rows)
          @raw_rows = raw_rows
          @budget_lines_imported = []
        end

        def process
          population = GobiertoBudgetsData::GobiertoBudgets::Population.get(@raw_rows.first.organization_id.to_i, @raw_rows.first.year.to_i)
          rows_repository = {}

          GobiertoBudgetsData::GobiertoBudgets::ALL_AREAS_NAMES.each do |area_name|
            rows_repository[area_name] ||= {}

            @raw_rows.each do |row|
              GobiertoBudgetsData::GobiertoBudgets::ALL_INDEXES.each do |index|
                rows_repository[area_name][index] ||= {}
                code = row.area_code(area_name)
                amount = row.amount(index)

                # Cumulative last level budget lines
                rows_repository[area_name][index][code] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                  organization_id: row.organization_id,
                  population: population,
                  year: row.year,
                  code: code,
                  kind: row.kind,
                  index: index,
                  area_name: area_name,
                  amount: 0
                )
                rows_repository[area_name][index][code].amount += amount

                # Cumulative parent budget lines
                rows_repository[area_name][index][code].code_object.parent_codes.each do |parent_code|
                  rows_repository[area_name][index][parent_code.code] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                    organization_id: row.organization_id,
                    population: population,
                    year: row.year,
                    code: parent_code.code,
                    kind: row.kind,
                    index: index,
                    area_name: area_name,
                    amount: 0
                  )
                  rows_repository[area_name][index][parent_code.code].amount += amount
                end

                if area_name == GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME
                end
              end
            end
          end

          rows_repository.each do |_, rows_by_area|
            rows_by_area.each do |_, rows_by_area_and_index|
              rows_by_area_and_index.each do |_, budget_line|
                @budget_lines_imported << budget_line
              end
            end
          end

          return @budget_lines_imported
        end
      end
    end
  end
end
