# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    module Utils
      class SicalwinBudgetLineProcessor
        def initialize(raw_rows)
          @raw_rows = raw_rows
          @budget_lines_imported = []
          @errors = 0
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
          site = Site.find_by(organization_id: organization_id)

          kind = @raw_rows.first.kind

          # This hash is used to accumulate amounts for each budget line
          rows_repository = {}

          GobiertoBudgetsData::GobiertoBudgets::ALL_AREAS_NAMES.each do |area_name|
            # Skip functional and custom area when the file is income
            next if kind == GobiertoBudgetsData::GobiertoBudgets::INCOME && area_name != GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME

            rows_repository[area_name] ||= {}

            @raw_rows.each do |row|
              # Skip remanentes rows when the file is expense
              if kind == GobiertoBudgetsData::GobiertoBudgets::EXPENSE
                if row.row["Remanentes Incorporados"].present? && row.row["Remanentes Incorporados"].to_f > 0 &&
                    row.row["Créditos Iniciales"].present? && row.row["Créditos Iniciales"].to_f == 0
                  next
                end
              end

              code = row.area_code(area_name)

              # Import the custom category description using the three parts organic + program + economic
              if area_name == GobiertoBudgetsData::GobiertoBudgets::CUSTOM_AREA_NAME
                GobiertoBudgetsData::GobiertoBudgets::ALL_KINDS.each do |kind|
                  category_attrs = { site: site, area_name: GobiertoBudgetsData::GobiertoBudgets::CUSTOM_AREA_NAME, kind: kind, code: code }

                  unless ::GobiertoBudgets::Category.exists?(category_attrs)
                    ::GobiertoBudgets::Category.create!(category_attrs.merge({
                      custom_name_translations: {site.configuration.default_locale => row.description}
                    }))
                  end
                end
              end

              GobiertoBudgetsData::GobiertoBudgets::ALL_INDEXES.each do |index|
                rows_repository[area_name][index] ||= {}
                amount = row.amount(index)
                economic_code = row.area_code(GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME)
                economic_code_object = GobiertoBudgetsData::GobiertoBudgets::BudgetLineCode.new(economic_code)

                # Create the economic, functional and custom budget lines
                rows_repository[area_name][index][code] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                  common_budget_line_attributes(row).merge({
                    code: code, kind: kind,
                    index: index, area_name: area_name,
                  })
                )
                if rows_repository[area_name][index][code].valid?
                  rows_repository[area_name][index][code].amount += amount
                else
                  @errors += 1
                end

                # Economic-functional budget lines
                if area_name == GobiertoBudgetsData::GobiertoBudgets::FUNCTIONAL_AREA_NAME
                  key = "#{code}-#{economic_code}"
                  rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                    common_budget_line_attributes(row).merge({
                      code: economic_code, functional_code: code,
                      kind: kind, index: index,
                      area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_FUNCTIONAL_AREA_NAME,
                    })
                  )
                  if rows_repository[area_name][index][key].valid?
                    rows_repository[area_name][index][key].amount += amount
                  else
                    @errors += 1
                  end

                  # Parent economic-functional budget lines
                  parent_code = economic_code_object.ancestor_code
                  key = "#{code}-#{parent_code.code}"
                  rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                    common_budget_line_attributes(row).merge({
                      code: parent_code.code, functional_code: code,
                      kind: kind, index: index,
                      area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_FUNCTIONAL_AREA_NAME,
                    })
                  )

                  if rows_repository[area_name][index][key].valid?
                    rows_repository[area_name][index][key].amount += amount
                  else
                    @errors += 1
                  end
                end

                # Economic-custom budget lines
                if area_name == GobiertoBudgetsData::GobiertoBudgets::CUSTOM_AREA_NAME
                  key = "#{code}-#{economic_code}"
                  rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                    common_budget_line_attributes(row).merge({
                      code: economic_code, custom_code: code,
                      kind: kind, index: index,
                      area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_CUSTOM_AREA_NAME,
                    })
                  )

                  if rows_repository[area_name][index][key].valid?
                    rows_repository[area_name][index][key].amount += amount
                  else
                    @errors += 1
                  end

                  # Parent economic-functional budget lines
                  parent_code = economic_code_object.ancestor_code
                  key = "#{code}-#{parent_code.code}"
                  rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                    common_budget_line_attributes(row).merge({
                      code: parent_code.code, custom_code: code,
                      kind: kind, index: index,
                      area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_CUSTOM_AREA_NAME,
                    })
                  )
                  if rows_repository[area_name][index][key].valid?
                    rows_repository[area_name][index][key].amount += amount
                  else
                    @errors += 1
                  end
                end

                # Cumulative parent budget lines
                rows_repository[area_name][index][code].code_object.parent_codes.each do |parent_code|
                  rows_repository[area_name][index][parent_code.code] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                    common_budget_line_attributes(row).merge({
                      code: parent_code.code, kind: kind,
                      index: index, area_name: area_name,
                    })
                  )
                  if rows_repository[area_name][index][parent_code.code].valid?
                    rows_repository[area_name][index][parent_code.code].amount += amount
                  else
                    @errors += 1
                  end


                  # Economic-functional budget lines of parent budget lines
                  if area_name == GobiertoBudgetsData::GobiertoBudgets::FUNCTIONAL_AREA_NAME
                    key = "#{parent_code.code}-#{economic_code}"
                    rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                      common_budget_line_attributes(row).merge({
                        code: economic_code, functional_code: parent_code.code,
                        kind: kind, index: index,
                        area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_FUNCTIONAL_AREA_NAME,
                      })
                    )
                    if rows_repository[area_name][index][key].valid?
                      rows_repository[area_name][index][key].amount += amount
                    else
                      @errors += 1
                    end

                    # Parent economic-functional budget lines of parent budget lines
                    economic_parent_code = economic_code_object.ancestor_code
                    key = "#{parent_code.code}-#{economic_parent_code.code}"
                    rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                      common_budget_line_attributes(row).merge({
                        code: economic_parent_code.code, functional_code: parent_code.code,
                        kind: kind, index: index,
                        area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_FUNCTIONAL_AREA_NAME,
                      })
                    )
                    rows_repository[area_name][index][key].amount += amount if rows_repository[area_name][index][key].valid?
                    if rows_repository[area_name][index][key].valid?
                      rows_repository[area_name][index][key].amount += amount
                    else
                      @errors += 1
                    end
                  end

                  # Economic-custom budget lines of parent budget lines
                  if area_name == GobiertoBudgetsData::GobiertoBudgets::CUSTOM_AREA_NAME
                    key = "#{parent_code.code}-#{economic_code}"
                    rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                      common_budget_line_attributes(row).merge({
                        code: economic_code, custom_code: parent_code.code,
                        kind: kind, index: index,
                        area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_CUSTOM_AREA_NAME,
                      })
                    )
                    if rows_repository[area_name][index][key].valid?
                      rows_repository[area_name][index][key].amount += amount
                    else
                      @errors += 1
                    end

                    # Parent economic-custom budget lines of parent budget lines
                    economic_parent_code = economic_code_object.ancestor_code
                    key = "#{parent_code.code}-#{economic_parent_code.code}"
                    rows_repository[area_name][index][key] ||= GobiertoBudgetsData::GobiertoBudgets::BudgetLine.new(
                      common_budget_line_attributes(row).merge({
                        code: economic_parent_code.code, custom_code: parent_code.code,
                        kind: kind, index: index,
                        area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_CUSTOM_AREA_NAME,
                      })
                    )
                    if rows_repository[area_name][index][key].valid?
                      rows_repository[area_name][index][key].amount += amount
                    else
                      @errors += 1
                    end
                  end
                end
              end
            end
          end

          puts "Number of errors: #{@errors}"

          return [] unless @errors.zero?

          rows_repository.each do |_, rows_by_area|
            rows_by_area.each do |_, rows_by_area_and_index|
              rows_by_area_and_index.each do |_, budget_line|
                @budget_lines_imported << budget_line if budget_line.amount > 0
              end
            end
          end

          return @budget_lines_imported
        end

        private

        def common_budget_line_attributes(row)
          {
            organization_id: row.organization_id,
            population: population,
            year: row.year,
            amount: 0
          }
        end

        def population
          @population ||= GobiertoBudgetsData::GobiertoBudgets::Population.get(organization_id, @raw_rows.first.year.to_i)
        end

        def organization_id
          @organization_id ||= @raw_rows.first.organization_id.to_i
        end
      end
    end
  end
end
