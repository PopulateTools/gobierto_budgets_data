# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    module Utils
      class SicalwinBudgetLineProcessor
        def initialize(raw_rows)
          @raw_rows = raw_rows
          @budget_lines_imported = []
        end

        # This method processes the Sicalwin rows and creates the different budget lines from each row
        #
        # There's a big number of budget lines to be created:
        #   - economic budget line
        #   - functional budget line
        #   - custom budget line
        #   - parent economic budget lines, from the current level to level one. So if the current code is 310, it creates 31 and 3
        #   - parent functional budget lines, from the current level to level one. So if the current code is 310, it creates 31 and 3
        #   - parent custom budget lines, from the current level to level one. So if the current code is 310, it creates 31 and 3
        #
        # And, for each of these budget lines created, it creates also the aggregation economic-custom and economic-functional,
        # which describes which economic budget lines are composing the current budget line. And for each of these budget lines
        # there's also a loop that creates the parent economic-custom and parent economic-functional budget lines.
        def process
          population = GobiertoBudgetsData::GobiertoBudgets::Population.get(@raw_rows.first.organization_id.to_i, @raw_rows.first.year.to_i)
          kind = @raw_rows.first.kind

          # This hash is used to accumulate amounts for each budget line
          rows_repository = {}

          GobiertoBudgetsData::GobiertoBudgets::ALL_AREAS_NAMES.each do |area_name|
            # Skip functional and custom area when the file is income
            next if kind == GobiertoBudgetsData::GobiertoBudgets::INCOME && area_name != GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME

            rows_repository[area_name] ||= {}

            @raw_rows.each do |row|
              GobiertoBudgetsData::GobiertoBudgets::ALL_INDEXES.each do |index|
                rows_repository[area_name][index] ||= {}
                code = row.area_code(area_name)
                amount = row.amount(index)
                economic_code = row.area_code(GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME)
                economic_code_object = GobiertoBudgetsData::GobiertoBudgets::BudgetLineCode.new(economic_code)

                # Create the economic, functional and custom budget lines
                rows_repository[area_name][index][code] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                  organization_id: row.organization_id,
                  population: population,
                  year: row.year,
                  code: code,
                  kind: kind,
                  index: index,
                  area_name: area_name,
                  amount: 0
                )
                rows_repository[area_name][index][code].amount += amount

                # Economic-functional budget lines
                if area_name == GobiertoBudgetsData::GobiertoBudgets::FUNCTIONAL_AREA_NAME
                  key = "#{code}-#{economic_code}"
                  rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                    organization_id: row.organization_id,
                    population: population,
                    year: row.year,
                    code: economic_code,
                    functional_code: code,
                    kind: kind,
                    index: index,
                    area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_FUNCTIONAL_AREA_NAME,
                    amount: 0
                  )
                  rows_repository[area_name][index][key].amount += amount

                  # Parent economic-functional budget lines
                  economic_code_object.parent_codes.each do |parent_code|
                    key = "#{code}-#{parent_code.code}"
                    rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                      organization_id: row.organization_id,
                      population: population,
                      year: row.year,
                      code: parent_code.code,
                      functional_code: code,
                      kind: kind,
                      index: index,
                      area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_FUNCTIONAL_AREA_NAME,
                      amount: 0
                    )
                    rows_repository[area_name][index][key].amount += amount
                  end
                end

                # Economic-custom budget lines
                if area_name == GobiertoBudgetsData::GobiertoBudgets::CUSTOM_AREA_NAME
                  key = "#{code}-#{economic_code}"
                  rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                    organization_id: row.organization_id,
                    population: population,
                    year: row.year,
                    code: economic_code,
                    custom_code: code,
                    kind: kind,
                    index: index,
                    area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_CUSTOM_AREA_NAME,
                    amount: 0
                  )
                  rows_repository[area_name][index][key].amount += amount

                  # Parent economic-functional budget lines
                  economic_code_object.parent_codes.each do |parent_code|
                    key = "#{code}-#{parent_code.code}"
                    rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                      organization_id: row.organization_id,
                      population: population,
                      year: row.year,
                      code: parent_code.code,
                      custom_code: code,
                      kind: kind,
                      index: index,
                      area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_CUSTOM_AREA_NAME,
                      amount: 0
                    )
                    rows_repository[area_name][index][key].amount += amount
                  end
                end

                # Cumulative parent budget lines
                rows_repository[area_name][index][code].code_object.parent_codes.each do |parent_code|
                  rows_repository[area_name][index][parent_code.code] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                    organization_id: row.organization_id,
                    population: population,
                    year: row.year,
                    code: parent_code.code,
                    kind: kind,
                    index: index,
                    area_name: area_name,
                    amount: 0
                  )
                  rows_repository[area_name][index][parent_code.code].amount += amount

                  # Economic-functional budget lines of parent budget lines
                  if area_name == GobiertoBudgetsData::GobiertoBudgets::FUNCTIONAL_AREA_NAME
                    key = "#{parent_code.code}-#{economic_code}"
                    rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                      organization_id: row.organization_id,
                      population: population,
                      year: row.year,
                      code: economic_code,
                      functional_code: parent_code.code,
                      kind: kind,
                      index: index,
                      area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_FUNCTIONAL_AREA_NAME,
                      amount: 0
                    )
                    rows_repository[area_name][index][key].amount += amount

                    # Parent economic-functional budget lines of parent budget lines
                    economic_code_object.parent_codes.each do |economic_parent_code|
                      key = "#{parent_code.code}-#{economic_parent_code.code}"
                      rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                        organization_id: row.organization_id,
                        population: population,
                        year: row.year,
                        code: economic_parent_code.code,
                        functional_code: parent_code.code,
                        kind: kind,
                        index: index,
                        area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_FUNCTIONAL_AREA_NAME,
                        amount: 0
                      )
                      rows_repository[area_name][index][key].amount += amount
                    end
                  end

                  # Economic-custom budget lines of parent budget lines
                  if area_name == GobiertoBudgetsData::GobiertoBudgets::CUSTOM_AREA_NAME
                    key = "#{parent_code.code}-#{economic_code}"
                    rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                      organization_id: row.organization_id,
                      population: population,
                      year: row.year,
                      code: economic_code,
                      custom_code: parent_code.code,
                      kind: kind,
                      index: index,
                      area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_CUSTOM_AREA_NAME,
                      amount: 0
                    )
                    rows_repository[area_name][index][key].amount += amount

                    # Parent economic-custom budget lines of parent budget lines
                    economic_code_object.parent_codes.each do |economic_parent_code|
                      key = "#{parent_code.code}-#{economic_parent_code.code}"
                      rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                        organization_id: row.organization_id,
                        population: population,
                        year: row.year,
                        code: economic_parent_code.code,
                        custom_code: parent_code.code,
                        kind: kind,
                        index: index,
                        area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_CUSTOM_AREA_NAME,
                        amount: 0
                      )
                      rows_repository[area_name][index][key].amount += amount
                    end
                  end
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
